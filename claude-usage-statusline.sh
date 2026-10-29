#!/usr/bin/env bash
# Claude Code status line that also saves your usage limits for machines-dashboard.sh,
# in /Users/Shared/claude-usage, a folder admin creates for dev that `stats` can read but not write.
#
# Install on each machine:
#   cp claude-usage-statusline.sh ~/.claude/ && chmod +x ~/.claude/claude-usage-statusline.sh
# then add this to ~/.claude/settings.json:
#   "statusLine": {"type": "command", "command": "~/.claude/claude-usage-statusline.sh"}
input=$(cat)

# Claude Code sends the limits (Pro and Max plans) after the session's first reply
limits=$(jq -c '.rate_limits // empty' <<<"$input")
if [[ -n $limits ]] && tmp=$(mktemp /Users/Shared/claude-usage/latest.XXXXXX 2>/dev/null); then
  printf '%s\n' "$limits" >"$tmp" && chmod 644 "$tmp" && mv "$tmp" /Users/Shared/claude-usage/latest.json
fi

# The status line itself: model and context used
jq -r '"[\(.model.display_name)] \(.context_window.used_percentage // 0 | floor)% context"' <<<"$input"
