#!/bin/bash
# Runs one round of dashboard-data.sh against stubbed Tailscale, SSH and mini-stats, and checks data.js.
# A host name other than lowercase letters, digits and hyphens is dropped. A second JSON value adds no entry.
# An older mini-stats line and an unreachable Mac mini show as down.
set -euo pipefail
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
mkdir "$temporary/bin" "$temporary/peer"
cat >"$temporary/bin/tailscale" <<'EOF'
#!/bin/bash
echo '{"Self":{"DNSName":"mini-1.t.ts.net.","Tags":["tag:mini"]},"Peer":{
  "a":{"DNSName":"mini-2.t.ts.net.","Tags":["tag:mini"]},
  "b":{"DNSName":"mini-3.t.ts.net.","Tags":["tag:mini"]},
  "c":{"DNSName":"mini-4.t.ts.net.","Tags":["tag:mini"]},
  "e":{"DNSName":"x\"</script>.t.ts.net.","Tags":["tag:mini"]}}}'
EOF
cat >"$temporary/bin/ssh" <<'EOF'
#!/bin/bash
cat "$(dirname "$0")/../peer/${@: -1}" 2>/dev/null || exit 255
EOF
printf '#!/bin/bash\necho %s\n' "'{\"cpu\":10,\"memory\":60,\"claude\":{}}'" >"$temporary/bin/mini-stats"
chmod +x "$temporary/bin/"*
printf '%s\n%s\n' '{"cpu":1,"memory":2,"claude":{}}' '{"cpu":3,"memory":4,"claude":{}}' >"$temporary/peer/mini-2"
echo '93.2 45 12 30' >"$temporary/peer/mini-3"
sed -e "s#/opt/homebrew/bin/tailscale#$temporary/bin/tailscale#" -e "s#/usr/local/bin/mini-stats#$temporary/bin/mini-stats#" \
  -e "s#/Users/stats/.dashboard/data.js#$temporary/data.js#" -e 's#^  sleep 5$#  exit 0#' dashboard-data.sh >"$temporary/collector.sh"
PATH=$temporary/bin:$PATH bash "$temporary/collector.sh"
diff <(sed 's/"time":[0-9]*/"time":0/' "$temporary/data.js") - <<'EOF'
window.FLEET = {"time":0,"machines":[{"cpu":10,"memory":60,"claude":{},"name":"mini-1","up":true},{"cpu":1,"memory":2,"claude":{},"name":"mini-2","up":true},{"name":"mini-3","up":false},{"name":"mini-4","up":false}]};
EOF
echo "test-dashboard: ok"
