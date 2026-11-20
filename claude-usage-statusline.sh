#!/bin/bash
# dev's Claude Code status line (setup.sh installs it), for both claude-work and claude-personal.
# It shows which one is running, and saves that setup's usage limits to
# /Users/Shared/claude-usage/latest-work.json or latest-personal.json, which mini-stats reads.
input=$(cat)

# Claude Code sends the limits (Pro and Max plans) after the session's first reply
limits=$(jq -c '.rate_limits // empty' <<<"$input")
profile=$(tr '[:upper:]' '[:lower:]' <<<"${CLAUDE_PROFILE:-}")
if [[ -n $limits && $profile =~ ^(work|personal)$ ]] && temporary=$(mktemp /Users/Shared/claude-usage/latest.XXXXXX 2>/dev/null); then
  printf '%s\n' "$limits" >"$temporary" && chmod 644 "$temporary" && mv "$temporary" "/Users/Shared/claude-usage/latest-$profile.json"
fi

# The status line itself: setup, model and context used
jq -r --arg profile "${CLAUDE_PROFILE:-?}" '"\($profile) · [\(.model.display_name)] \(.context_window.used_percentage // 0 | floor)% context"' <<<"$input"
