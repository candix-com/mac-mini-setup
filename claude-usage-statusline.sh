#!/bin/bash
# The status line of claude-work and claude-personal (setup.sh installs it). It also saves the setup's usage limits
# for mini-stats.
input=$(cat)
profile=${CLAUDE_CONFIG_DIR##*/.claude-}
[[ $profile =~ ^(work|personal)$ ]] || profile=""

# Claude Code sends the limits (Pro and Max plans) after the session's first reply
limits=$(jq -c '.rate_limits // empty' <<<"$input")
if [[ -n $limits && -n $profile ]] && temporary=$(mktemp /Users/Shared/claude-usage/latest.XXXXXX 2>/dev/null); then
  printf '%s\n' "$limits" >"$temporary" && chmod 644 "$temporary" && mv "$temporary" "/Users/Shared/claude-usage/latest-$profile.json"
fi

# The status line itself: setup, model and context used
jq -r --arg profile "$profile" '(if $profile == "" then "" else "\($profile) · " end) + "[\(.model.display_name)] \(.context_window.used_percentage // 0 | floor)% context"' <<<"$input"
