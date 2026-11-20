#!/bin/bash
# Every 5 seconds, writes the mini-stats output of every Mac mini (tag:mini) to data.js, which dashboard.html loads.
# Runs mini-stats on this Mac and, over Tailscale SSH as stats, on the others.
set -uo pipefail

tailscale_status() { /opt/homebrew/bin/tailscale status --json; }
# Chrome runs data.js, so what the other machines send goes in only as plain numbers and host names
number() { [[ $1 =~ ^[0-9]+$ ]] && printf '%s' "$1" || printf 'null'; }

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

  rows=()
  for machine in "${machines[@]}"; do
    idle="" free="" five="" r5="" week="" rw="" pfive="" pr5="" pweek="" prw="" extra=""
    read -r idle free five r5 week rw pfive pr5 pweek prw extra <"$temporary/$machine"
    # A Mac mini not yet updated prints an older, shorter line
    [[ -n $prw && -z $extra ]] || five="" r5="" week="" rw="" pfive="" pr5="" pweek="" prw=""
    if [[ $idle =~ ^[0-9]+(\.[0-9]+)?$ && $free =~ ^[0-9]+$ ]]; then
      cpu=$(awk -v i="$idle" 'BEGIN {printf "%d", 100 - i + 0.5}')
      rows+=("{\"name\":\"$machine\",\"up\":true,\"cpu\":$cpu,\"mem\":$((100 - free)),$(
        printf '"work":{"five":%s,"r5":%s,"week":%s,"rw":%s},"pers":{"five":%s,"r5":%s,"week":%s,"rw":%s}}' \
          "$(number "$five")" "$(number "$r5")" "$(number "$week")" "$(number "$rw")" \
          "$(number "$pfive")" "$(number "$pr5")" "$(number "$pweek")" "$(number "$prw")")")
    else
      rows+=("{\"name\":\"$machine\",\"up\":false}")
    fi
  done
  # Moved into place, so the page never loads half a file
  { printf 'window.FLEET = {"t":%s,"machines":[' "$(date +%s)"; (IFS=,; printf '%s' "${rows[*]}"); printf ']};\n'; } >"$output.tmp" &&
    mv "$output.tmp" "$output"
  sleep 5
done
