#!/bin/bash
# The status line of every Claude setup (setup.sh installs it). It also saves the setup's usage limits for mini-stats.
input=$(cat)
# claude-work and claude-personal set CLAUDE_CONFIG_DIR to ~/.claude-work or ~/.claude-personal
setup=${CLAUDE_CONFIG_DIR##*/.claude-}
[[ $setup =~ ^[a-z]+$ ]] || setup=""

# Claude Code sends the limits (Pro and Max plans) after the session's first reply
limits=$(jq -c '.rate_limits // empty' <<<"$input")
if [[ -n $limits && -n $setup ]] && temporary=$(mktemp /Users/Shared/claude-usage/latest.XXXXXX 2>/dev/null); then
  printf '%s\n' "$limits" >"$temporary" && chmod 644 "$temporary" && mv "$temporary" "/Users/Shared/claude-usage/latest-$setup.json"
fi

# The status line itself: setup, model and context used
jq -r --arg setup "$setup" '(if $setup == "" then "" else "\($setup) · " end) + "[\(.model.display_name)] \(.context_window.used_percentage // 0 | floor)% context"' <<<"$input"
