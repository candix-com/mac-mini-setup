#!/bin/bash
# Runs dashboard-data.sh with this repo's mini-stats, against stubbed Tailscale, SSH, top and memory_pressure, and
# checks the first data.js it writes. It runs twice: once with this Mac's numbers, once with its mini-stats stuck.
# A host name other than lowercase letters, digits and hyphens is dropped. A second JSON value adds no entry, and a
# Mac mini can't rename itself. An older mini-stats line, a null, a Mac mini that never answers and an unreachable
# one show as down.
set -euo pipefail
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
mkdir "$temporary/bin" "$temporary/peer" "$temporary/.dashboard"
cat >"$temporary/bin/tailscale" <<'EOF'
#!/bin/bash
echo '{"Self":{"DNSName":"mini-1.t.ts.net.","Tags":["tag:mini"]},"Peer":{
  "a":{"DNSName":"mini-2.t.ts.net.","Tags":["tag:mini"]},
  "b":{"DNSName":"mini-3.t.ts.net.","Tags":["tag:mini"]},
  "c":{"DNSName":"mini-4.t.ts.net.","Tags":["tag:mini"]},
  "d":{"DNSName":"mini-5.t.ts.net.","Tags":["tag:mini"]},
  "e":{"DNSName":"x\"</script>.t.ts.net.","Tags":["tag:mini"]},
  "f":{"DNSName":"mini-6.t.ts.net.","Tags":["tag:mini"]},
  "g":{"DNSName":"mini-7.t.ts.net.","Tags":["tag:mini"]}}}'
EOF
cat >"$temporary/bin/ssh" <<'EOF'
#!/bin/bash
cat "$(dirname "$0")/../peer/${@: -1}" 2>/dev/null || exit 255
EOF
printf '#!/bin/bash\necho "CPU usage: 1.0%% user, 9.0%% sys, 90.0%% idle"\n' >"$temporary/bin/top"
printf '#!/bin/bash\necho "System-wide memory free percentage: 40%%"\n' >"$temporary/bin/memory_pressure"
chmod +x "$temporary/bin/"*
ln -s "$PWD/mini-stats" "$temporary/bin/mini-stats"
mkdir "$temporary/usage"
printf '%s\n%s\n' '{"claude":{},"cpu":1,"memory":2}' '{"claude":{},"cpu":3,"memory":4}' >"$temporary/peer/mini-2"
echo '93.2 45 12 30' >"$temporary/peer/mini-3"
echo '{"claude":{},"cpu":5,"memory":6,"name":"mini-1","up":false}' >"$temporary/peer/mini-5"
echo null >"$temporary/peer/mini-6"
mkfifo "$temporary/peer/mini-4"   # never answers
# Prints the first data.js one run of the collector writes
collect() {
  rm -f "$temporary/.dashboard/data.js"
  CLAUDE_USAGE_DIRECTORY=$temporary/usage HOME=$temporary PATH=$temporary/bin:$PATH TMPDIR=$temporary bash dashboard-data.sh >/dev/null 2>&1 &
  collector=$!
  disown
  for _ in {1..100}; do [[ -f $temporary/.dashboard/data.js ]] && break; sleep 0.1; done
  kill "$collector"
  sed 's/"timeSeconds":[0-9]*/"timeSeconds":0/' "$temporary/.dashboard/data.js"
}
others='{"claude":{},"cpu":1,"memory":2,"name":"mini-2","up":true},{"name":"mini-3","up":false},{"name":"mini-4","up":false},{"claude":{},"cpu":5,"memory":6,"name":"mini-5","up":true},{"name":"mini-6","up":false},{"name":"mini-7","up":false}'
diff <(collect) - <<EOF
window.FLEET = {"machines":[{"claude":{},"cpu":10,"memory":60,"name":"mini-1","up":true},$others],"timeSeconds":0};
EOF
mkfifo "$temporary/usage/latest-stuck.json"   # this Mac's mini-stats never answers
diff <(collect) - <<EOF
window.FLEET = {"machines":[{"name":"mini-1","up":false},$others],"timeSeconds":0};
EOF
echo "test-dashboard: ok"
