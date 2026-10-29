#!/bin/bash
# Run once on your laptop: makes mini-1, mini-2… open that Mac mini's terminal tabs as dev.
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/candix-com/mac-mini-setup/main/laptop.sh)"
set -euo pipefail

read -rp "How many Mac minis? " count </dev/tty
[[ $count =~ ^[1-9][0-9]*$ ]] || { echo "Type just a number, like 3."; exit 1; }

mkdir -p ~/.ssh
grep -qs '^Host mini-\*' ~/.ssh/config || printf '\nHost mini-*\n  User dev\n  ForwardAgent no\n' >> ~/.ssh/config
for ((n = 1; n <= count; n++)); do
  # -a keeps your laptop's SSH keys away from the agents
  line="alias mini-$n='ssh -a -t mini-$n /opt/homebrew/bin/tmux new -A -s main'"
  grep -qxF "$line" ~/.zshrc || echo "$line" >> ~/.zshrc
done
echo "Done. Open a new terminal and type mini-1."
