#!/bin/bash
# Runs mini-stats with stubbed top and memory_pressure against usage files with windows still open, a window past
# its reset, a window Claude Code dropped and the older latest.json, and checks its JSON.
set -euo pipefail
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
now=$(date +%s)
printf '{"five_hour":{"used_percentage":23.5,"resets_at":%s},"seven_day":{"used_percentage":41.2,"resets_at":%s}}\n' \
  $((now + 3600)) $((now + 86400)) >"$temporary/latest-work.json"
printf '{"five_hour":{"used_percentage":50,"resets_at":%s}}\n' $((now - 10)) >"$temporary/latest-personal.json"
echo '{"five_hour":{"used_percentage":99,"resets_at":1}}' >"$temporary/latest.json"
sed -e "s#/usr/bin/top -l 2 -n 0 -s 1#echo 'CPU usage: 1.0% user, 2.0% sys, 97.0% idle'#" \
  -e "s#/usr/bin/memory_pressure -Q#echo 'System-wide memory free percentage: 87%'#" \
  -e "s#/Users/Shared/claude-usage#$temporary#" mini-stats >"$temporary/mini-stats"
bash "$temporary/mini-stats" | /usr/bin/jq -e --argjson now "$now" '. == {cpu: 3, memory: 13, claude: {
  work: {five: 23, fiveReset: ($now + 3600), week: 41, weekReset: ($now + 86400)},
  personal: {five: 0, fiveReset: null, week: null, weekReset: null}}}' >/dev/null
echo "test-mini-stats: ok"
