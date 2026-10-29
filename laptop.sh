#!/bin/bash
# Run on your laptop after setup.sh on a Mac mini: adds the mini-<n> command and logs that Mac mini in to Claude.
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/candix-com/mac-mini-setup/main/laptop.sh)"
set -euo pipefail

read -rp "Which Mac mini? Type its number: " number </dev/tty
[[ $number =~ ^[1-9][0-9]*$ ]] || { echo "Type just a number, like 1."; exit 1; }

mkdir -p ~/.ssh
grep -qs '^Host mini-\*' ~/.ssh/config ||
  printf '\nHost mini-*\n  User dev\n  StrictHostKeyChecking accept-new\n' >> ~/.ssh/config
# -a keeps your laptop's SSH keys away from the agents
line="alias mini-$number='ssh -a -t mini-$number /opt/homebrew/bin/tmux new -A -s main'"
grep -qxF "$line" ~/.zshrc || echo "$line" >> ~/.zshrc

echo "Last step: log in to Claude. Click the link it shows, approve, paste the code back."
echo "Once you see Claude's prompt, type /exit."
read -rp "Press Enter to continue..." </dev/tty
ssh -a -t "mini-$number" '~/.local/bin/claude' </dev/tty || true
echo "Done. Open a new terminal and type mini-$number."
