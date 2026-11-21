#!/bin/bash
# Runs one round of dashboard-data.sh against stubbed Tailscale, SSH and mini-stats, and checks data.js.
# Only numbers, and host names of lowercase letters, digits and hyphens, get through. A second JSON value adds
# no entry. An older mini-stats line, a non-number CPU or memory and an unreachable Mac mini show as down. A
# non-number usage limit shows as blank.
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
  "d":{"DNSName":"mini-5.t.ts.net.","Tags":["tag:mini"]},
  "f":{"DNSName":"mini-6.t.ts.net.","Tags":["tag:mini"]},
  "e":{"DNSName":"x\"</script>.t.ts.net.","Tags":["tag:mini"]}}}'
EOF
cat >"$temporary/bin/ssh" <<'EOF'
#!/bin/bash
cat "$(dirname "$0")/../peer/${@: -1}" 2>/dev/null || exit 255
EOF
printf '#!/bin/bash\necho %s\n' "'{\"cpu\":10,\"memory\":60,\"claude\":{\"work\":{\"five\":23,\"fiveReset\":100,\"week\":41,\"weekReset\":200}}}'" >"$temporary/bin/mini-stats"
chmod +x "$temporary/bin/"*
printf '%s\n%s\n' '{"cpu":"1);alert(1)//","memory":50,"claude":{"work":{"five":"x","week":1}}}' \
  '{"cpu":1,"memory":1,"claude":{}}' >"$temporary/peer/mini-2"
echo '93.2 45 12 30' >"$temporary/peer/mini-3"
echo '{"cpu":5,"memory":6,"claude":{"personal":{"five":"x","week":7}}}' >"$temporary/peer/mini-5"
echo '{"cpu":1,"memory":"1);alert(1)//","claude":{}}' >"$temporary/peer/mini-6"
sed -e "s#/opt/homebrew/bin/tailscale#$temporary/bin/tailscale#" -e "s#/usr/local/bin/mini-stats#$temporary/bin/mini-stats#" \
  -e "s#/Users/stats/.dashboard/data.js#$temporary/data.js#" -e 's#^  sleep 5$#  exit 0#' dashboard-data.sh >"$temporary/collector.sh"
PATH=$temporary/bin:$PATH bash "$temporary/collector.sh"
diff <(sed 's/"time":[0-9]*/"time":0/' "$temporary/data.js") - <<'EOF'
window.FLEET = {"time":0,"machines":[{"name":"mini-1","up":true,"cpu":10,"memory":60,"claude":{"work":{"five":23,"fiveReset":100,"week":41,"weekReset":200}}},{"name":"mini-2","up":false},{"name":"mini-3","up":false},{"name":"mini-4","up":false},{"name":"mini-5","up":true,"cpu":5,"memory":6,"claude":{"personal":{"five":null,"fiveReset":null,"week":7,"weekReset":null}}},{"name":"mini-6","up":false}]};
EOF
echo "test-dashboard: ok"
