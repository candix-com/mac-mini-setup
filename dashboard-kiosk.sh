#!/bin/bash
# Shows the dashboard on mini-1's screen: Chrome, full screen, on dashboard.html. setup.sh runs it as stats at login,
# and launchd starts it again if Chrome quits.
# The screen is 1280x400, but its EDID also offers 1920x1080 and macOS picks that, which the screen squashes.
# So this switches it to 1280x400 first.
if ! /opt/homebrew/bin/displayplacer list | grep -q '^Resolution: 1280x400$'; then
  id=$(/opt/homebrew/bin/displayplacer list | awk -F': ' '/^Persistent screen id:/ {print $2; exit}')
  /opt/homebrew/bin/displayplacer "id:$id res:1280x400 hz:60 color_depth:8 scaling:off origin:(0,0) degree:0"
fi
# No keyboard at the screen, so nothing may open a dialog: the two Keychain flags stop Chrome asking for
# Keychain access on its first start.
exec "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --kiosk \
  --user-data-dir="$HOME/.dashboard/chrome" --no-first-run --no-default-browser-check \
  --disable-session-crashed-bubble --noerrdialogs --disable-features=Translate \
  --password-store=basic --use-mock-keychain \
  "file://$HOME/.dashboard/index.html"
