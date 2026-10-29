#!/usr/bin/env bash
# Live dashboard of your machines, one line each: CPU, memory and Claude usage limits.
#
#   ./machines-dashboard.sh                    the machines listed below
#   ./machines-dashboard.sh mini-1 mini-2      or the machines you name
#
# Runs mini-stats on this Mac and, over Tailscale SSH as `stats`, on the others, whose
# `stats` login shell is mini-stats. Claude's limits appear once a machine uses
# claude-usage-statusline.sh.
set -uo pipefail

if (( $# )); then MACHINES=("$@"); else MACHINES=(mini-1 mini-2 mini-3); fi
REFRESH="${REFRESH:-5}"   # seconds between updates


bar() {   # bar 42  ->  ████░░░░░░   (bar -  ->  empty bar)
  local filled=0 out="" i
  [[ $1 == - ]] || filled=$(( ($1 + 5) / 10 ))
  for (( i = 0; i < 10; i++ )); do (( i < filled )) && out+="█" || out+="░"; done
  printf '%s' "$out"
}
pct() { [[ $1 == - ]] && printf '  -' || printf '%3d%%' "$1"; }

self=$(scutil --get ComputerName 2>/dev/null)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"; tput cnorm 2>/dev/null' EXIT
tput civis 2>/dev/null
printf '\e[H\e[2J'

while :; do
  for m in "${MACHINES[@]}"; do
    if [[ $m == "$self" ]]; then
      /usr/local/bin/mini-stats >"$tmp/$m" 2>/dev/null &   # a Mac can't reach its own Tailscale SSH
    else
      ssh -T -o BatchMode=yes -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new "$m" </dev/null >"$tmp/$m" 2>/dev/null &
    fi
  done
  wait

  printf '\e[H'
  for m in "${MACHINES[@]}"; do
    idle="" free="" five="-" week="-"
    read -r idle free five week <"$tmp/$m"
    # Only trust plain numbers from the other machines: bash would run anything else in $(( ))
    [[ $idle =~ ^[0-9]+(\.[0-9]+)?$ ]] || idle=""
    [[ $free =~ ^[0-9]+$ ]] || free=""
    [[ $five =~ ^[0-9]+$ ]] || five=-
    [[ $week =~ ^[0-9]+$ ]] || week=-
    if [[ -z $idle || -z $free ]]; then
      printf '%-8s  unreachable\e[K\n' "$m"
      continue
    fi
    cpu=$(awk -v i="$idle" 'BEGIN {printf "%d", 100 - i + 0.5}')
    mem=$(( 100 - free ))
    printf '%-8s  CPU %s %3d%%   MEM %s %3d%%   CLAUDE NOW %s %s   WEEK %s %s\e[K\n' \
      "$m" "$(bar "$cpu")" "$cpu" "$(bar "$mem")" "$mem" \
      "$(bar "$five")" "$(pct "$five")" "$(bar "$week")" "$(pct "$week")"
  done
  printf '\e[J'
  sleep "$REFRESH"
done
