#!/bin/bash
# Shows dashboard.html on mini-1's screen, full screen. No keyboard there: the Keychain flags stop Chrome asking for
# Keychain access.
exec "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --kiosk \
  --user-data-dir="$HOME/.dashboard/chrome" --no-first-run --no-default-browser-check \
  --disable-session-crashed-bubble --noerrdialogs --disable-features=Translate \
  --password-store=basic --use-mock-keychain \
  "file://$HOME/.dashboard/index.html"
