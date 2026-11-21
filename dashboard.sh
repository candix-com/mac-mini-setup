#!/bin/bash
# Shows dashboard.html on mini-1's screen, full screen. No keyboard there: --kiosk shows no restore prompt after a
# power cut, and --use-mock-keychain stops Chrome asking for Keychain access.
exec "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --kiosk --no-first-run --noerrdialogs \
  --use-mock-keychain "file://$HOME/.dashboard/dashboard.html"
