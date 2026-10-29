#!/bin/bash
# Sets up one Mac mini: users, FileVault, settings, Tailscale, tools, GitHub and the dashboard.
# Run it at the Mac mini, logged in as `admin`, in Terminal:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/candix-com/mac-mini-setup/main/setup.sh)"
# It asks for the machine number and the passwords it needs. Safe to run again.
set -euo pipefail

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/candix-com/mac-mini-setup/main}"
HERE=""
[[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]] && HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

step() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ask() { local a; read -rp "$1 " a </dev/tty; printf '%s' "$a"; }

# Copies one of this repo's files to $2: from next to this script, or from GitHub
fetch() {
  if [[ -n $HERE && -f $HERE/$1 ]]; then cp "$HERE/$1" "$2"
  else curl -fsSL "$REPO_RAW/$1" -o "$2"; fi
}

[[ $(uname) == Darwin ]] || { echo "Run this on the Mac mini."; exit 1; }
[[ $EUID -ne 0 ]] || { echo "Run it as admin, without sudo."; exit 1; }
id -Gn | grep -qw admin || { echo "Run it as the admin user."; exit 1; }
cd /   # admin's home becomes private below, and dev's commands must not start in it

N=$(ask "Which Mac mini is this? Type its number (1 is the one with the screen):")
[[ $N =~ ^[1-9][0-9]*$ ]] || { echo "Type just a number, like 1."; exit 1; }
NAME="mini-$N"
TAGS="tag:mini"; [[ $N == 1 ]] && TAGS="tag:mini,tag:dashboard"

step "Setting up $NAME. Type admin's password:"
sudo -v
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &
tmp=$(mktemp -d)

step "1/7 Name"
sudo scutil --set ComputerName "$NAME"
sudo scutil --set HostName "$NAME"
sudo scutil --set LocalHostName "$NAME"

step "2/7 Users dev and stats"
for u in dev stats; do
  if id "$u" >/dev/null 2>&1; then echo "$u already exists"; continue; fi
  echo "New user $u: type a long random password for it (save it in your password manager), then admin's password."
  sudo sysadminctl -addUser "$u" -fullName "$u" -password - -adminUser "$USER" -adminPassword - </dev/tty
done
sudo createhomedir -c >/dev/null
# macOS lets users read each other's home folders by default
sudo chmod 700 "/Users/$USER" /Users/dev /Users/stats

step "3/7 FileVault"
if fdesetup isactive >/dev/null; then
  echo "Already on."
else
  echo "Save the recovery key it prints in your password manager."
  sudo fdesetup enable -user "$USER" </dev/tty
fi
# stats must be able to unlock mini-1 after a power cut, so the dashboard comes back
sudo fdesetup list | grep -q '^stats,' || sudo fdesetup add -usertoadd stats </dev/tty

step "4/7 Settings"
sudo pmset -a sleep 0 displaysleep 0 autorestart 1
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >/dev/null
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on >/dev/null
# Remote Login off: Tailscale is the only way in
sudo launchctl disable system/com.openssh.sshd
sudo launchctl bootout system/com.openssh.sshd 2>/dev/null || true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate ConfigDataInstall -bool true
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false

step "5/7 Homebrew, tools and Tailscale"
[[ -x /opt/homebrew/bin/brew ]] ||
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
grep -qs 'brew shellenv' ~/.zprofile || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install tailscale tmux gh uv node pnpm
brew pin tailscale   # updated by hand at the tower, so a bad update can't lock you out
sudo brew services start tailscale
if ! tailscale status >/dev/null 2>&1; then
  echo "Approve this Mac in the browser tab that opens."
  sudo tailscale up --ssh --hostname="$NAME" --advertise-tags="$TAGS" 2>&1 | while IFS= read -r line; do
    echo "$line"
    [[ $line =~ (https://login\.tailscale\.com/[^[:space:]]+) ]] && open "${BASH_REMATCH[1]}" || true
  done
fi

step "6/7 Dashboard"
fetch mini-stats "$tmp/mini-stats"
sudo mkdir -p /usr/local/bin
sudo install -o root -g wheel -m 755 "$tmp/mini-stats" /usr/local/bin/mini-stats
sudo install -d -o dev -g staff -m 755 /Users/Shared/claude-usage
if [[ $N == 1 ]]; then
  fetch machines-dashboard.sh "$tmp/dashboard"
  sudo install -o root -g wheel -m 755 "$tmp/dashboard" /usr/local/bin/machines-dashboard
  printf '#!/bin/zsh\n/usr/local/bin/machines-dashboard\n' > "$tmp/dashboard.command"
  sudo install -o stats -g staff -m 755 "$tmp/dashboard.command" /Users/stats/dashboard.command
  sudo -u stats defaults -currentHost write com.apple.screensaver idleTime -int 0
else
  # On the other Mac minis, a login as stats can only print the numbers
  sudo dscl . -create /Users/stats UserShell /usr/local/bin/mini-stats
fi

step "7/7 dev: shell, Claude Code and GitHub"
fetch claude-usage-statusline.sh "$tmp/statusline"
sudo install -d -o dev -g staff -m 700 /Users/dev/.claude
sudo install -o dev -g staff -m 755 "$tmp/statusline" /Users/dev/.claude/claude-usage-statusline.sh
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
[[ -f ~/.claude/settings.json ]] ||
  printf '{\n  "statusLine": {"type": "command", "command": "~/.claude/claude-usage-statusline.sh"}\n}\n' > ~/.claude/settings.json
EOF

if ! sudo -u dev -H /opt/homebrew/bin/gh auth status >/dev/null 2>&1; then
  read -rsp "Paste this Mac mini's GitHub token (Enter to skip): " token </dev/tty; echo
  if [[ -n $token ]]; then
    git_name=$(ask "Name for commits [Owen Reed]:"); git_name=${git_name:-Owen Reed}
    git_email=$(ask "Email for commits [owen@candix.com]:"); git_email=${git_email:-owen@candix.com}
    printf '%s\n' "$token" | sudo -u dev -H /opt/homebrew/bin/gh auth login --with-token --insecure-storage
    sudo -u dev -H /opt/homebrew/bin/gh auth setup-git
    sudo -u dev -H git config --global user.name "$git_name"
    sudo -u dev -H git config --global user.email "$git_email"
  fi
  unset token
fi

rm -rf "$tmp"
step "Done. Left to do:"
echo "- Save the FileVault recovery key and the dev and stats passwords in your password manager."
echo "- From your laptop: mini-$N, then claude to log in to Claude Code."
if [[ $N == 1 ]]; then
  echo "- Log in here as stats, add dashboard.command to General > Login Items & Extensions, and make Terminal's font bigger."
  echo "- Plug the screen's USB cable into the power strip, not the Mac, and unplug the keyboard."
fi
echo "- Log out of admin."
