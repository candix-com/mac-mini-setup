#!/bin/bash
# Every 5 seconds, writes the mini-stats output of every Mac mini (tag:mini) to data.js, which dashboard.html loads.
# Runs mini-stats on this Mac and, over Tailscale SSH as stats, on the others.
set -uo pipefail

output=$HOME/.dashboard/data.js
self=$(tailscale status --json | jq -r '.Self.DNSName | split(".")[0]')
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"' EXIT

while :; do
  # Host names go into ssh and a file path, so only letters, digits and hyphens get through
  machines=($(tailscale status --json | jq -r '[.Self, (.Peer // {})[]][]
    | select(.Tags | index("tag:mini")) | .DNSName | split(".")[0]' | grep -E '^[a-z0-9-]+$' | sort -V))
  # A Mac mini that never answers can't hold up the others
  for machine in "${machines[@]}"; do
    if [[ $machine == "$self" ]]; then
      timeout 4 mini-stats >"$temporary/$machine" 2>/dev/null &   # a Mac can't reach its own Tailscale SSH
    else
      timeout 4 ssh -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new "$machine" >"$temporary/$machine" 2>/dev/null &
    fi
  done
  wait

  # Only the first value counts, and only if it is an object: an older mini-stats line, null or no answer shows as
  # down. name and up are merged last, so a Mac mini can't set its own.
  for machine in "${machines[@]}"; do
    jq -nc --arg name "$machine" 'try (input | objects + {name: $name, up: true}) // {name: $name, up: false}' \
      "$temporary/$machine"
  done | jq -sr '"window.FLEET = \({machines: ., timeSeconds: (now | floor)});"' >"$output.tmp" &&
    mv "$output.tmp" "$output"   # moved into place, so the page never loads half a file
  sleep 5
done
