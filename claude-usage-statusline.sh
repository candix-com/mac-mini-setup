#!/bin/bash
# dev's Claude Code status line (setup.sh installs it). It also saves the usage limits to
# /Users/Shared/claude-usage/latest.json, which mini-stats reads.
input=$(cat)

# Claude Code sends the limits (Pro and Max plans) after the session's first reply
limits=$(jq -c '.rate_limits // empty' <<<"$input")
if [[ -n $limits ]] && temporary=$(mktemp /Users/Shared/claude-usage/latest.XXXXXX 2>/dev/null); then
  printf '%s\n' "$limits" >"$temporary" && chmod 644 "$temporary" && mv "$temporary" /Users/Shared/claude-usage/latest.json
fi

# The status line itself: model and context used
jq -r '"[\(.model.display_name)] \(.context_window.used_percentage // 0 | floor)% context"' <<<"$input"
