#!/bin/bash
# Shows the dashboard on mini-1's screen: Chrome, full screen, on dashboard.html. setup.sh runs it as stats at login,
# and launchd starts it again if Chrome quits.
# The screen is 1280x400 and macOS sends it 1920x1080 (it refuses desktops under about 540 pixels tall),
# which the screen squashes. dashboard.html stretches itself by the same amount, so it comes out right.
# No keyboard at the screen, so nothing may open a dialog: the two Keychain flags stop Chrome asking for
# Keychain access on its first start.
exec "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --kiosk \
  --user-data-dir="$HOME/.dashboard/chrome" --no-first-run --no-default-browser-check \
  --disable-session-crashed-bubble --noerrdialogs --disable-features=Translate \
  --password-store=basic --use-mock-keychain \
  "file://$HOME/.dashboard/index.html"
