# Why

- **Three users.**
  - `admin` installs and updates.
  - `dev` is where the agents run. It is a standard user that can't use sudo.
  - `stats` only shows the dashboard.

  Home folders are private, so `dev` can't read the other users' files.
- **FileVault.** The disk is encrypted, so a stolen Mac mini is a brick. After a power cut, someone must unlock it at the Mac. Use `admin` or `stats` for that, never `dev`, so the agents never get a session at the screen.
- **No Remote Login, firewall blocks everything.** The only way in is Tailscale SSH. Your Tailscale login decides who gets in, and nothing else listens.
- **Tailscale from Homebrew, not the App Store app.** The app needs a logged-in user. This version runs as a system service, so it is up before anyone logs in. It is pinned so a `brew upgrade` can't cut you off. Update it at the Mac mini.
- **Tags.** Tagged Macs don't expire, and they aren't tied to your account. The policy lets only you, from a Mac, log in as `dev` (or as `admin` after a fresh check). `mini-1` may log in only as `stats`.
- **`stats` on mini-2 and mini-3.** Its shell is `mini-stats`, so logging in prints four numbers and exits.
- **Dashboard screen.** It only gets HDMI. Its USB power comes from the power strip, so it can't act as a keyboard. Unplug the keyboard after setup.
- **GitHub as Owen.** The agents push with Owen's GitHub login, which has no permission to change workflows. Branch rules make every change go through a pull request that someone else approves. Secrets only reach `main`, so a pull request from an agent can't read them.
- **`ssh -a`.** It keeps your laptop's SSH keys out of the Mac minis.
- **`umask 077`.** Files the agents create are readable only by `dev`.
- **No backups.** The code lives on GitHub.
