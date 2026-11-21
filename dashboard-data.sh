#!/bin/bash
# Every 5 seconds, writes the mini-stats output of every Mac mini (tag:mini) to data.js, which dashboard.html loads.
# Runs mini-stats on this Mac and, over Tailscale SSH as stats, on the others.
set -uo pipefail

tailscale_status() { /opt/homebrew/bin/tailscale status --json; }

output=/Users/stats/.dashboard/data.js
self=$(tailscale_status | /usr/bin/jq -r '.Self.DNSName | split(".")[0]')
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT

while :; do
  machines=($(tailscale_status | /usr/bin/jq -r '[.Self, (.Peer // {})[]][]
    | select((.Tags // []) | index("tag:mini")) | .DNSName | split(".")[0]' | grep -E '^[a-z0-9-]+$' | sort -V))
  for machine in "${machines[@]}"; do
    if [[ $machine == "$self" ]]; then
      /usr/local/bin/mini-stats >"$temporary/$machine" 2>/dev/null &   # a Mac can't reach its own Tailscale SSH
    else
      ssh -T -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new "$machine" </dev/null >"$temporary/$machine" 2>/dev/null &
    fi
  done
  wait

  # Chrome runs data.js, so jq passes on only the numbers and setup names from each machine's output
  for machine in "${machines[@]}"; do
    /usr/bin/jq -nc --arg name "$machine" '(try (input | {name: $name, up: true, cpu: (.cpu | numbers),
      memory: (.memory | numbers), claude: (.claude | objects | with_entries(select(.key | test("^[a-z]+$")))
        | map_values(objects | {five, fiveReset, week, weekReset} | map_values(numbers // null)))})
      catch null) // {name: $name, up: false}' "$temporary/$machine"
  done | /usr/bin/jq -sr --argjson time "$(date +%s)" '"window.FLEET = \({time: $time, machines: .});"' >"$output.tmp" &&
    mv "$output.tmp" "$output"   # moved into place, so the page never loads half a file
  sleep 5
done
