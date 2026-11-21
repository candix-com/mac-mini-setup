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
  # Host names go into ssh and a file path, so only letters, digits and hyphens get through
  machines=($(tailscale_status | /usr/bin/jq -r '[.Self, (.Peer // {})[]][]
    | select(.Tags | index("tag:mini")) | .DNSName | split(".")[0]' | grep -E '^[a-z0-9-]+$' | sort -V))
  for machine in "${machines[@]}"; do
    if [[ $machine == "$self" ]]; then
      /usr/local/bin/mini-stats >"$temporary/$machine" 2>/dev/null &   # a Mac can't reach its own Tailscale SSH
    else
      ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new "$machine" >"$temporary/$machine" 2>/dev/null &
    fi
  done
  # A Mac mini that never answers can't hold up the others
  sleep 4
  kill $(jobs -p) 2>/dev/null
  wait

  # Only the first value counts, and only if it is an object: an older mini-stats line, null or no answer shows as
  # down. name and up are merged last, so a Mac mini can't set its own.
  for machine in "${machines[@]}"; do
    /usr/bin/jq -nc --arg name "$machine" 'try (input | objects + {name: $name, up: true}) // {name: $name, up: false}' \
      "$temporary/$machine"
  done | /usr/bin/jq -sr '"window.FLEET = \({machines: ., timeSeconds: (now | floor)});"' >"$output.tmp" &&
    mv "$output.tmp" "$output"   # moved into place, so the page never loads half a file
  sleep 1
done
