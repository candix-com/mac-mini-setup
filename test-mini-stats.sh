#!/bin/bash
# Runs mini-stats with stubbed top and memory_pressure against usage files with windows still open, a window past
# its reset, a window Claude Code dropped and the older latest.json, and checks its JSON.
set -euo pipefail
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT
now=$(date +%s)
seconds_per_day=86400
seconds_per_hour=3600
printf '{"five_hour":{"used_percentage":23.5,"resets_at":%s},"seven_day":{"used_percentage":41.2,"resets_at":%s}}\n' \
  $((now + seconds_per_hour)) $((now + seconds_per_day)) >"$temporary/latest-work.json"
printf '{"five_hour":{"used_percentage":50,"resets_at":%s}}\n' $((now - 10)) >"$temporary/latest-personal.json"
echo '{"five_hour":{"used_percentage":99,"resets_at":1}}' >"$temporary/latest.json"
sed -e "s#/usr/bin/top -l 2 -n 0 -s 1#echo 'CPU usage: 1.0% user, 2.0% sys, 97.0% idle'#" \
  -e "s#/usr/bin/memory_pressure -Q#echo 'System-wide memory free percentage: 87%'#" \
  -e "s#/Users/Shared/claude-usage#$temporary#" mini-stats >"$temporary/mini-stats"
bash "$temporary/mini-stats" | /usr/bin/jq -e --argjson day "$seconds_per_day" --argjson hour "$seconds_per_hour" --argjson now "$now" '. == {claude: {
  personal: {five: 0, fiveResetSeconds: null, week: 0, weekResetSeconds: null},
  work: {five: 23, fiveResetSeconds: ($now + $hour), week: 41, weekResetSeconds: ($now + $day)}}, cpu: 3, memory: 13}' >/dev/null
echo "test-mini-stats: ok"
