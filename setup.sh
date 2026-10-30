#!/bin/bash
# Sets up one Mac mini: users, settings, Tailscale, tools, GitHub and the dashboard.
# Run it at the Mac mini, as admin, in Terminal (README.md, step 3). A second run skips what is already done.
set -euo pipefail

fetch() { curl -fsSL "https://raw.githubusercontent.com/candix-com/mac-mini-setup/main/$1" -o "$2"; }
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }

fdesetup isactive >/dev/null || { echo "Turn on FileVault first: System Settings > Privacy & Security > FileVault."; exit 1; }
read -rp "Which Mac mini is this? Type its number (1 is the one with the screen): " number </dev/tty
[[ $number =~ ^[1-9][0-9]*$ ]] || { echo "Type just a number, like 1."; exit 1; }
name="mini-$number"
tags="tag:mini"; [[ $number == 1 ]] && tags="tag:mini,tag:dashboard"
cd /   # admin's home becomes private below, and dev's commands must not start in it

step "Setting up $name. Type admin's password:"
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
temporary=$(mktemp -d)

step "1/6 Name"
for key in ComputerName HostName LocalHostName; do sudo scutil --set "$key" "$name"; done

step "2/6 Users"
# dev runs the agents and only logs in over Tailscale SSH. Its password is random and never shown,
# and it gets no secure token, so it can neither log in at the screen nor unlock FileVault.
id dev >/dev/null 2>&1 || sudo sysadminctl -addUser dev -fullName dev -password "$(openssl rand -base64 30)"
if [[ $number == 1 ]]; then
  # On mini-1, stats logs in at the screen to show the dashboard, and unlocks FileVault after a power cut
  if ! id stats >/dev/null 2>&1; then
    echo "User stats: type a new password for it (save it in your password manager), then admin's password."
    sudo sysadminctl -addUser stats -fullName stats -password - -adminUser "$USER" -adminPassword - </dev/tty
  fi
  if ! sudo fdesetup list | grep -q '^stats,'; then
    echo "FileVault for stats: if it asks for a user name, type admin. Then type the passwords it asks for."
    sudo fdesetup add -usertoadd stats </dev/tty
  fi
else
  id stats >/dev/null 2>&1 || sudo sysadminctl -addUser stats -fullName stats -password "$(openssl rand -base64 30)"
fi
# macOS lets users read each other's home folders by default
sudo chmod 700 "/Users/$USER" /Users/dev /Users/stats

step "3/6 Settings"
sudo pmset -a sleep 0 displaysleep 0 autorestart 1
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >/dev/null
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on >/dev/null
# macOS updates restart the Mac, so you install them yourself (README.md, Daily use)
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false

step "4/6 Homebrew, tools and Tailscale"
if [[ ! -x /opt/homebrew/bin/brew ]]; then
  # Downloaded to a file first, so a failed download stops the script
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$temporary/homebrew-install.sh"
  NONINTERACTIVE=1 /bin/bash "$temporary/homebrew-install.sh"
fi
grep -qs 'brew shellenv' ~/.zprofile || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install tailscale tmux gh uv node pnpm
brew pin tailscale   # update it at the Mac mini, so a bad update can't cut you off
sudo brew services start tailscale
if ! tailscale status >/dev/null 2>&1; then
  echo "A Tailscale tab opens. Log in with your account, then click Connect."
  sudo tailscale up --ssh --hostname="$name" --advertise-tags="$tags" 2>&1 | while IFS= read -r line; do
    echo "$line"
    [[ $line =~ (https://login\.tailscale\.com/[^[:space:]]+) ]] && open "${BASH_REMATCH[1]}" || true
  done
fi

step "5/6 Dashboard"
fetch mini-stats "$temporary/mini-stats"
sudo mkdir -p /usr/local/bin
sudo install -o root -g wheel -m 755 "$temporary/mini-stats" /usr/local/bin/mini-stats
# dev saves its Claude usage here for mini-stats. Made as dev, so root never writes through a path dev controls.
sudo -u dev mkdir -p -m 755 /Users/Shared/claude-usage
if [[ $number == 1 ]]; then
  fetch machines-dashboard.sh "$temporary/dashboard"
  sudo install -o root -g wheel -m 755 "$temporary/dashboard" /usr/local/bin/machines-dashboard
  # Opens the dashboard in Terminal when stats logs in
  sudo -u stats -H mkdir -p /Users/stats/Library/LaunchAgents
  sudo -u stats -H tee /Users/stats/Library/LaunchAgents/com.candix.dashboard.plist >/dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.candix.dashboard</string>
  <key>ProgramArguments</key>
  <array><string>/usr/bin/open</string><string>-a</string><string>Terminal</string><string>/usr/local/bin/machines-dashboard</string></array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
  sudo -u stats -H defaults -currentHost write com.apple.screensaver idleTime -int 0
else
  # On the other Mac minis, a login as stats can only print the numbers
  sudo dscl . -create /Users/stats UserShell /usr/local/bin/mini-stats
fi

step "6/6 dev: shell, Claude Code and GitHub"
sudo -u dev -H /bin/bash -s <<'EOF'
set -euo pipefail
cd ~
grep -qs 'brew shellenv' ~/.zprofile || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
[[ -d ~/.oh-my-zsh ]] ||
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
[[ -d ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting ]] ||
  git clone -q https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
sed -i '' 's/^plugins=(.*)/plugins=(git zsh-syntax-highlighting)/' ~/.zshrc
printf 'set -g mouse on\nset -g history-limit 50000\nset -g renumber-windows on\n' > ~/.tmux.conf
mkdir -p ~/code
# Files the agents create are readable only by dev
grep -qs 'umask 077' ~/.zshenv || echo 'umask 077' >> ~/.zshenv
[[ -x ~/.local/bin/claude ]] || curl -fsSL https://claude.ai/install.sh | bash
grep -qs '.local/bin' ~/.zshrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
mkdir -p ~/.claude
curl -fsSL https://raw.githubusercontent.com/candix-com/mac-mini-setup/main/claude-usage-statusline.sh -o ~/.claude/claude-usage-statusline.sh
chmod 755 ~/.claude/claude-usage-statusline.sh
[[ -f ~/.claude/settings.json ]] ||
  printf '{\n  "statusLine": {"type": "command", "command": "~/.claude/claude-usage-statusline.sh"}\n}\n' > ~/.claude/settings.json
EOF

if ! sudo -u dev -H /opt/homebrew/bin/gh auth status >/dev/null 2>&1; then
  echo "GitHub login, with Owen's account (owreed)."
  # The token goes in a file: dev's Keychain is locked over SSH
  sudo -u dev -H /opt/homebrew/bin/gh auth login -h github.com -p https -w -s admin:ssh_signing_key,user:email --insecure-storage </dev/tty
  sudo -u dev -H /opt/homebrew/bin/gh auth setup-git
fi
sudo -u dev -H /bin/bash -s <<'EOF'
set -euo pipefail
gh=/opt/homebrew/bin/gh
email=$($gh api user/emails -q 'map(select(.primary and .verified))[0].email')
git config --global user.name "$($gh api user -q '.name // .login')"
git config --global user.email "$email"
# Every commit is signed with this Mac mini's own key, so GitHub shows it Verified
if [[ ! -f ~/.ssh/id_ed25519 ]]; then
  ssh-keygen -q -t ed25519 -N "" -C "$email" -f ~/.ssh/id_ed25519
  $gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "$(scutil --get ComputerName)"
fi
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
EOF

rm -rf "$temporary"
step "Done."
if [[ $number == 1 ]]; then
  echo "Next: Apple menu > Log Out admin, then step 4 of the guide."
else
  echo "Next: Apple menu > Log Out admin, unplug the screen, keyboard and mouse, then step 5 of the guide."
fi
