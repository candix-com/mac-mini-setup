#!/bin/bash
# Live dashboard of the Mac minis (every Tailscale device tagged tag:mini), one line each:
# CPU, memory and Claude usage limits. setup.sh installs it on mini-1, where it opens when stats logs in.
# Runs mini-stats on this Mac and, over Tailscale SSH as stats, on the others.
set -uo pipefail

bar() {   # bar 42  ->  ████░░░░░░   (bar -  ->  empty bar)
  local filled=0 out="" idx
  [[ $1 == - ]] || filled=$(( ($1 + 5) / 10 ))
  for (( idx = 0; idx < 10; idx++ )); do (( idx < filled )) && out+="█" || out+="░"; done
  printf '%s' "$out"
}
percent() { [[ $1 == - ]] && printf '  -' || printf '%3d%%' "$1"; }
tailscale_status() { /opt/homebrew/bin/tailscale status --json; }

self=$(tailscale_status | /usr/bin/jq -r '.Self.DNSName | split(".")[0]')
temporary=$(mktemp -d)
trap 'rm -rf "$temporary"; tput cnorm 2>/dev/null' EXIT
tput civis 2>/dev/null
printf '\e[H\e[2J'

while :; do
  machines=($(tailscale_status | /usr/bin/jq -r '[.Self, (.Peer // {})[]][]
    | select((.Tags // []) | index("tag:mini")) | .DNSName | split(".")[0]' | sort -V))
  for machine in "${machines[@]}"; do
    if [[ $machine == "$self" ]]; then
      /usr/local/bin/mini-stats >"$temporary/$machine" 2>/dev/null &   # a Mac can't reach its own Tailscale SSH
    else
      ssh -T -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new "$machine" </dev/null >"$temporary/$machine" 2>/dev/null &
    fi
  done
  wait

  printf '\e[H'
  for machine in "${machines[@]}"; do
    idle="" free="" five="-" week="-"
    read -r idle free five week <"$temporary/$machine"
    # Only trust plain numbers from the other machines: bash would run anything else in $(( ))
    [[ $idle =~ ^[0-9]+(\.[0-9]+)?$ ]] || idle=""
    [[ $free =~ ^[0-9]+$ ]] || free=""
    [[ $five =~ ^[0-9]+$ ]] || five=-
    [[ $week =~ ^[0-9]+$ ]] || week=-
    if [[ -z $idle || -z $free ]]; then
      printf '%-8s  unreachable\e[K\n' "$machine"
      continue
    fi
    cpu=$(awk -v i="$idle" 'BEGIN {printf "%d", 100 - i + 0.5}')
    memory=$(( 100 - free ))
    printf '%-8s  CPU %s %3d%%   MEM %s %3d%%   CLAUDE NOW %s %s   WEEK %s %s\e[K\n' \
      "$machine" "$(bar "$cpu")" "$cpu" "$(bar "$memory")" "$memory" \
      "$(bar "$five")" "$(percent "$five")" "$(bar "$week")" "$(percent "$week")"
  done
  printf '\e[J'
  sleep 5
done
