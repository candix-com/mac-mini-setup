#!/bin/bash
# Runs dashboard-data.sh with this repo's mini-stats against stubbed Tailscale, SSH, top and memory_pressure until
# it writes data.js, then checks it. A host name other than lowercase letters, digits and hyphens is dropped. A
# second JSON value adds no entry, and a Mac mini can't rename itself. An older mini-stats line, a null and an
# unreachable Mac mini show as down.
set -euo pipefail
temporary=$(mktemp -d)
trap 'kill "${collector:-}" 2>/dev/null; rm -rf "$temporary"' EXIT
mkdir "$temporary/bin" "$temporary/peer"
cat >"$temporary/bin/tailscale" <<'EOF'
#!/bin/bash
echo '{"Self":{"DNSName":"mini-1.t.ts.net.","Tags":["tag:mini"]},"Peer":{
  "a":{"DNSName":"mini-2.t.ts.net.","Tags":["tag:mini"]},
  "b":{"DNSName":"mini-3.t.ts.net.","Tags":["tag:mini"]},
  "c":{"DNSName":"mini-4.t.ts.net.","Tags":["tag:mini"]},
  "d":{"DNSName":"mini-5.t.ts.net.","Tags":["tag:mini"]},
  "e":{"DNSName":"x\"</script>.t.ts.net.","Tags":["tag:mini"]},
  "f":{"DNSName":"mini-6.t.ts.net.","Tags":["tag:mini"]}}}'
EOF
cat >"$temporary/bin/ssh" <<'EOF'
#!/bin/bash
cat "$(dirname "$0")/../peer/${@: -1}" 2>/dev/null || exit 255
EOF
sed -e "s#/usr/bin/top -l 2 -n 0 -s 1#echo 'CPU usage: 1.0% user, 9.0% sys, 90.0% idle'#" \
  -e "s#/usr/bin/memory_pressure -Q#echo 'System-wide memory free percentage: 40%'#" \
  -e "s#/Users/Shared/claude-usage#$temporary/usage#" mini-stats >"$temporary/bin/mini-stats"
chmod +x "$temporary/bin/"*
printf '%s\n%s\n' '{"claude":{},"cpu":1,"memory":2}' '{"claude":{},"cpu":3,"memory":4}' >"$temporary/peer/mini-2"
echo '93.2 45 12 30' >"$temporary/peer/mini-3"
echo '{"claude":{},"cpu":5,"memory":6,"name":"mini-1","up":false}' >"$temporary/peer/mini-5"
echo null >"$temporary/peer/mini-6"
sed -e "s#/opt/homebrew/bin/tailscale#$temporary/bin/tailscale#" -e "s#/usr/local/bin/mini-stats#$temporary/bin/mini-stats#" \
  -e "s#/Users/stats/.dashboard/data.js#$temporary/data.js#" dashboard-data.sh >"$temporary/collector.sh"
PATH=$temporary/bin:$PATH TMPDIR=$temporary bash "$temporary/collector.sh" &
collector=$!
disown
for _ in {1..100}; do [[ -f $temporary/data.js ]] && break; sleep 0.1; done
diff <(sed 's/"timeSeconds":[0-9]*/"timeSeconds":0/' "$temporary/data.js") - <<'EOF'
window.FLEET = {"machines":[{"claude":{},"cpu":10,"memory":60,"name":"mini-1","up":true},{"claude":{},"cpu":1,"memory":2,"name":"mini-2","up":true},{"name":"mini-3","up":false},{"name":"mini-4","up":false},{"claude":{},"cpu":5,"memory":6,"name":"mini-5","up":true},{"name":"mini-6","up":false}],"timeSeconds":0};
EOF
echo "test-dashboard: ok"
