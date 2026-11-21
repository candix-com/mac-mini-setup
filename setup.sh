#!/bin/bash
# Sets up one Mac mini: users, settings, Tailscale, tools, Docker, GitHub and the dashboard.
# Run it at the Mac mini, as admin, in Terminal (README.md, step 3). A second run skips what is already done.
set -euo pipefail

fetch() { curl -fsSL "https://raw.githubusercontent.com/candix-com/mac-mini-setup/main/$1" -o "$2"; }
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }
# Writes the LaunchDaemon $1, which runs as dev, from the plist keys on stdin as JSON members, and reloads it when its
# plist changed. It logs outside dev's home, where dev can't plant a symlink for launchd to follow. bootout returns
# before the job is gone.
daemon() {
  plutil -convert xml1 -o "$temporary/$1.plist" - <<EOF
{"Label": "$1", "StandardErrorPath": "/Library/Logs/$1.log", "StandardOutPath": "/Library/Logs/$1.log", "UserName": "dev", $(cat)}
EOF
  cmp -s "$temporary/$1.plist" "/Library/LaunchDaemons/$1.plist" && sudo launchctl print "system/$1" >/dev/null 2>&1 && return
  sudo install -m 644 "$temporary/$1.plist" "/Library/LaunchDaemons/$1.plist"
  sudo launchctl bootout "system/$1" 2>/dev/null || true
  while sudo launchctl print "system/$1" >/dev/null 2>&1; do sleep 1; done
  sudo launchctl bootstrap system "/Library/LaunchDaemons/$1.plist"
}

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

step "1/7 Name"
for key in ComputerName HostName LocalHostName; do sudo scutil --set "$key" "$name"; done

step "2/7 Users"
# dev runs the agents and only logs in over Tailscale SSH. Its password is random and never shown,
# and it gets no secure token, so it can neither log in at the screen nor unlock FileVault.
id dev >/dev/null 2>&1 || sudo sysadminctl -addUser dev -fullName Dev -password "$(openssl rand -base64 30)"
if [[ $number == 1 ]]; then
  # On mini-1, stats logs in at the screen to show the dashboard, and unlocks FileVault after a power cut
  if ! id stats >/dev/null 2>&1; then
    echo "User stats: type a new password for it (save it in your password manager), then admin's password."
    sudo sysadminctl -addUser stats -fullName Stats -password - -adminUser "$USER" -adminPassword - </dev/tty
  fi
  if ! sudo fdesetup list | grep -q '^stats,'; then
    echo "FileVault for stats: if it asks for a user name, type admin. Then type the passwords it asks for."
    sudo fdesetup add -usertoadd stats </dev/tty
  fi
else
  id stats >/dev/null 2>&1 || sudo sysadminctl -addUser stats -fullName Stats -password "$(openssl rand -base64 30)"
fi
# macOS lets users read each other's home folders by default
sudo chmod 700 "/Users/$USER" /Users/dev /Users/stats

step "3/7 Homebrew, tools and Tailscale"
if [[ ! -x /opt/homebrew/bin/brew ]]; then
  # Downloaded to a file first, so a failed download stops the script
  curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$temporary/homebrew-install.sh"
  NONINTERACTIVE=1 /bin/bash "$temporary/homebrew-install.sh"
fi
grep -qs 'brew shellenv' ~/.zprofile || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
# A rerun doesn't upgrade the tools already installed (README.md, Daily use).
# Installing a missing one can still upgrade what it depends on.
HOMEBREW_NO_INSTALL_UPGRADE=1 brew install tailscale tmux gh uv node pnpm colima docker docker-compose
HOMEBREW_NO_INSTALL_UPGRADE=1 brew install --cask google-chrome
brew pin tailscale   # update it at the Mac mini, so a bad update can't cut you off
sudo brew services start tailscale
if ! tailscale status >/dev/null 2>&1; then
  echo "A Tailscale tab opens. Log in with your account, then click Connect."
  sudo tailscale up --ssh --hostname="$name" --advertise-tags="$tags" 2>&1 | while IFS= read -r line; do
    echo "$line"
    [[ $line =~ (https://login\.tailscale\.com/[^[:space:]]+) ]] && open "${BASH_REMATCH[1]}" || true
  done
fi
# Screen Sharing over Tailscale, since the firewall blocks it (NOTES.md)
sudo tailscale serve --bg --tcp 5900 tcp://localhost:5900 >/dev/null

step "4/7 Docker"
# Colima runs Docker in a Linux VM, as dev, from boot, with nobody logged in (NOTES.md)
# The job runs colima, and Colima runs limactl and docker, from the PATH, which launchd sets without /opt/homebrew/bin.
# Each launch force-stops the VM first. A VM left running by a failed start would otherwise
# make colima start exit at once.
daemon com.candix.colima <<'EOF'
"EnvironmentVariables": {"PATH": "/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"}, "KeepAlive": true,
"ProgramArguments": ["/bin/sh", "-c", "colima stop --force; exec colima start --foreground"]
EOF
# The first start downloads the VM, so it can take a few minutes
for _ in {1..300}; do sudo -u dev -H docker info >/dev/null 2>&1 && break; sleep 1; done
sudo -u dev -H docker info >/dev/null 2>&1 || { echo "Docker didn't start. Colima's log: sudo cat /Library/Logs/com.candix.colima.log"; exit 1; }

step "5/7 Dashboard"
fetch mini-stats "$temporary/mini-stats"
sudo mkdir -p /usr/local/bin
sudo install -o root -g wheel -m 755 "$temporary/mini-stats" /usr/local/bin/mini-stats
# dev saves its Claude usage here for mini-stats. Made as dev, so root never writes through a path dev controls.
sudo -u dev mkdir -p -m 755 /Users/Shared/claude-usage
if [[ $number == 1 ]]; then
  # The quarantine makes Chrome's first start ask a question, with no keyboard at the dashboard to answer it.
  # Removing it skips Gatekeeper, so this runs Gatekeeper's check first and checks that the app is Google's.
  spctl --assess --type execute "/Applications/Google Chrome.app"
  codesign --verify -R='anchor apple generic and certificate leaf[subject.OU] = "EQHXZ8M8AV"' "/Applications/Google Chrome.app"
  sudo xattr -rd com.apple.quarantine "/Applications/Google Chrome.app"
  fetch dashboard.html "$temporary/dashboard.html"
  sudo -u stats -H mkdir -p /Users/stats/.dashboard /Users/stats/Library/LaunchAgents
  sudo install -o stats -m 644 "$temporary/dashboard.html" /Users/stats/.dashboard/dashboard.html
  # At stats' login: dashboard-data collects the numbers, dashboard shows them in Chrome
  for job in dashboard dashboard-data; do
    fetch "$job.sh" "$temporary/$job"
    sudo install -o root -g wheel -m 755 "$temporary/$job" "/usr/local/bin/$job"
    # launchd's PATH leaves out /opt/homebrew/bin and /usr/local/bin, where tailscale and mini-stats are
    sudo -u stats -H plutil -convert xml1 -o "/Users/stats/Library/LaunchAgents/com.candix.$job.plist" - <<EOF
{"EnvironmentVariables": {"PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"}, "KeepAlive": true,
 "Label": "com.candix.$job", "ProgramArguments": ["/usr/local/bin/$job"]}
EOF
  done
  sudo -u stats -H defaults -currentHost write com.apple.screensaver idleTime -int 0
else
  # On the other Mac minis, a login as stats can only print the numbers
  sudo dscl . -create /Users/stats UserShell /usr/local/bin/mini-stats
fi

step "6/7 dev: shell, Claude Code and GitHub"
fetch claude-usage-statusline.sh "$temporary/statusline"
sudo install -o root -g wheel -m 755 "$temporary/statusline" /usr/local/bin/claude-usage-statusline
# Both Claude setups read managed-settings.json, and dev can't change it (NOTES.md). Attribution is off, so PRs get
# no "Generated with Claude Code" line and commits no Co-authored-by trailer. Auto memory is off because lessons go
# in the shared skills. Only the agent runs maintainer and the two plugins it calls, so this machine enables them,
# not a repository.
sudo mkdir -p "/Library/Application Support/ClaudeCode"
sudo tee "/Library/Application Support/ClaudeCode/managed-settings.json" >/dev/null <<'EOF'
{
  "attribution": false,
  "autoMemoryEnabled": false,
  "enabledPlugins": {"engineering@candix": true, "maintainer@candix": true, "reviewers@candix": true},
  "env": {"DISABLE_ERROR_REPORTING": "1", "DISABLE_TELEMETRY": "1"},
  "extraKnownMarketplaces": {"candix": {"source": {"path": "/Users/dev/.candix-skills", "source": "directory"}}},
  "statusLine": {"command": "/usr/local/bin/claude-usage-statusline", "type": "command"}
}
EOF
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
# Match the whole line: oh-my-zsh's .zshrc already mentions .local/bin in a comment
grep -qsxF 'export PATH="$HOME/.local/bin:$PATH"' ~/.zshrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
# Lets dev run docker compose: the docker CLI looks for its plugins in ~/.docker/cli-plugins
mkdir -p ~/.docker/cli-plugins
ln -sf /opt/homebrew/lib/docker/cli-plugins/docker-compose ~/.docker/cli-plugins/docker-compose
# Testcontainers for Node ignores Docker contexts, so DOCKER_HOST gives it Colima's socket. Its
# reaper container bind-mounts the Docker socket, and Docker looks that path up inside Colima's VM,
# so TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE names the VM's socket, /var/run/docker.sock
# (https://node.testcontainers.org/supported-container-runtimes/#colima).
grep -qsxF 'export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"' ~/.zshenv ||
  echo 'export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"' >> ~/.zshenv
grep -qsxF 'export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock' ~/.zshenv ||
  echo 'export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock' >> ~/.zshenv
for setup in work personal; do
  printf '#!/bin/bash\nexport CLAUDE_CONFIG_DIR="$HOME/.claude-%s"\nexec "$HOME/.local/bin/claude" "$@"\n' "$setup" > ~/.local/bin/claude-$setup
  chmod 755 ~/.local/bin/claude-$setup
done
# Plain claude would start a third, unlabeled setup, so it prints the two commands instead. In a shell that a
# claude-work or claude-personal session starts, CLAUDE_CONFIG_DIR is set, so it runs claude.
printf '%s\n' 'claude() { [[ -n $CLAUDE_CONFIG_DIR ]] && { command claude "$@"; return; }; echo "Type claude-work or claude-personal." >&2; return 1; }' > ~/.oh-my-zsh/custom/claude.zsh
EOF

if ! sudo -u dev -H /opt/homebrew/bin/gh auth status >/dev/null 2>&1; then
  echo "GitHub login, with Owen's account (owreed)."
  # The token goes in a file: dev's Keychain is locked over SSH
  sudo -u dev -H /opt/homebrew/bin/gh auth login -h github.com -p https -w -s admin:ssh_signing_key,user:email,workflow --insecure-storage </dev/tty
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
# Both setups load the candix plugins in place from this clone (managed-settings.json). It is private, so it is
# cloned after the GitHub login.
[[ -d ~/.candix-skills ]] || $gh repo clone candix-com/skills ~/.candix-skills -- -q
EOF

# Every 5 minutes, as dev and with nobody logged in, this job resets the candix skills clone to GitHub's main.
# Each new session then loads the latest skills, and an edit or branch left in the clone doesn't last.
daemon com.candix.skills <<'EOF'
"ProgramArguments": ["/bin/sh", "-c", "cd /Users/dev/.candix-skills && /usr/bin/git fetch -q https://github.com/candix-com/skills.git main && /usr/bin/git checkout -q --force --detach FETCH_HEAD && /usr/bin/git clean -qffdx"],
"StartInterval": 300
EOF

# Last, because turning on the firewall cuts the internet for a few seconds
step "7/7 Settings"
sudo pmset -a sleep 0 displaysleep 0 autorestart 1
# Ethernet only. Given the port name Wi-Fi, -setairportpower falls back to the only airport interface it finds, so this passes the device, such as en1.
sudo networksetup -setairportpower "$(networksetup -listallhardwareports | awk '/^Hardware Port: Wi-Fi$/ { getline; print $2 }')" off
# macOS updates restart the Mac, so you install them yourself (README.md, Daily use)
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates -bool false
# System Settings can't turn on Screen Sharing while the firewall blocks all incoming connections (NOTES.md)
until sudo launchctl print system/com.apple.screensharing >/dev/null 2>&1; do
  sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off >/dev/null
  echo "Turn on Screen Sharing in the Sharing settings that open."
  open "x-apple.systempreferences:com.apple.Sharing-Settings.extension"
  read -rp "Then press Enter. " </dev/tty
done
# Screen Sharing lets in only this group's members, the admins. On mini-1, stats too, to reach the dashboard.
if [[ $number == 1 ]]; then
  sudo dseditgroup -o edit -a stats -t user com.apple.access_screensharing ||
    echo "Couldn't let stats in over Screen Sharing: System Settings > General > Sharing > Screen Sharing (i) > add Stats."
fi
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on >/dev/null
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on >/dev/null

rm -rf "$temporary"
step "Done."
if [[ $number == 1 ]]; then
  echo "Next: Apple menu > Log Out admin, then step 4 of the guide."
else
  echo "Next: Apple menu > Log Out admin, unplug the screen, keyboard and mouse, then step 5 of the guide."
fi
