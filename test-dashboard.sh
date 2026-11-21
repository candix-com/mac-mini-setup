#!/bin/bash
# Runs one round of dashboard-data.sh against stubbed Tailscale, SSH and mini-stats, and checks what reaches
# data.js: only numbers, host names and setup names, one card per Mac mini, an older mini-stats line and an
# unreachable Mac mini as down.
set -euo pipefail
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
mkdir "$dir/bin" "$dir/peer"
cat >"$dir/bin/tailscale" <<'EOF'
#!/bin/bash
echo '{"Self":{"DNSName":"mini-1.t.ts.net.","Tags":["tag:mini"]},"Peer":{
  "a":{"DNSName":"mini-2.t.ts.net.","Tags":["tag:mini"]},
  "b":{"DNSName":"mini-3.t.ts.net.","Tags":["tag:mini"]},
  "c":{"DNSName":"mini-4.t.ts.net.","Tags":["tag:mini"]},
  "d":{"DNSName":"mini-5.t.ts.net.","Tags":["tag:mini"]},
  "e":{"DNSName":"x\"</script>.t.ts.net.","Tags":["tag:mini"]}}}'
EOF
cat >"$dir/bin/ssh" <<'EOF'
#!/bin/bash
cat "$(dirname "$0")/../peer/${@: -1}" 2>/dev/null || exit 255
EOF
printf '#!/bin/bash\necho %s\n' "'{\"cpu\":10,\"memory\":60,\"claude\":{\"work\":{\"five\":23,\"fiveReset\":100,\"week\":41,\"weekReset\":200}}}'" >"$dir/bin/mini-stats"
chmod +x "$dir/bin/"*
printf '%s\n%s\n' '{"cpu":"1);alert(1)//","memory":50,"claude":{"work":{"five":"x","week":1,"x</script>":1},"x</script>":{}}}' \
  '{"cpu":1,"memory":1,"claude":{}}' >"$dir/peer/mini-2"
echo '93.2 45 12 30' >"$dir/peer/mini-3"
echo '{"cpu":5,"memory":6,"claude":{"personal":{"five":"x","week":7,"x</script>":1},"x</script>":{}}}' >"$dir/peer/mini-5"
sed -e "s#/opt/homebrew/bin/tailscale#$dir/bin/tailscale#" -e "s#/usr/local/bin/mini-stats#$dir/bin/mini-stats#" \
  -e "s#/Users/stats/.dashboard/data.js#$dir/data.js#" -e 's#^  sleep 5$#  exit 0#' dashboard-data.sh >"$dir/collector.sh"
PATH=$dir/bin:$PATH bash "$dir/collector.sh"
diff <(sed 's/"time":[0-9]*/"time":0/' "$dir/data.js") - <<'EOF'
window.FLEET = {"time":0,"machines":[{"name":"mini-1","up":true,"cpu":10,"memory":60,"claude":{"work":{"five":23,"fiveReset":100,"week":41,"weekReset":200}}},{"name":"mini-2","up":false},{"name":"mini-3","up":false},{"name":"mini-4","up":false},{"name":"mini-5","up":true,"cpu":5,"memory":6,"claude":{"personal":{"five":null,"fiveReset":null,"week":7,"weekReset":null}}}]};
EOF
echo "test-dashboard: ok"
