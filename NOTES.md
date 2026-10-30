# Why

- There are three users. `admin` installs and updates. `dev` runs the agents: a standard user, so it can't use sudo. `stats` only shows the dashboard. Home folders are private, so `dev` can't read the other users' files.
- `dev` only logs in over Tailscale SSH. Its password is random and nobody knows it, and it has no secure token, so the agents can never get a session at a screen or unlock FileVault. The same goes for `stats` on every Mac mini but mini-1.
- FileVault encrypts the disk, so no one can read the data on a stolen Mac mini. After a power cut, someone unlocks it at the Mac mini: `stats` on mini-1, so the dashboard comes back, `admin` on the others.
- Remote Login stays off (the macOS default) and the firewall blocks all incoming connections. Tailscale SSH is the only way in, and your Tailscale login decides who gets in.
- Tailscale comes from Homebrew, not the App Store. The App Store app needs a logged-in user. The Homebrew one runs as a system service, so it is up before anyone logs in. It is pinned so that `brew upgrade` can't cut you off. Update it at the Mac mini.
- The Mac minis are tagged in Tailscale. Tagged devices have no key expiry and don't belong to your account. The policy lets only you, from a Mac, log in as `dev`, or as `admin` after you log in to Tailscale again in the browser. mini-1 may log in to the others only as `stats`.
- On every Mac mini but mini-1, the shell of `stats` is `mini-stats`, so logging in as `stats` prints four numbers and exits.
- The dashboard lists every device tagged `tag:mini`, so a new Mac mini shows up on its own.
- The dashboard screen connects to mini-1 by HDMI only and takes USB power from the power strip, so it can't act as a keyboard.
- macOS updates restart the Mac, so you install them yourself, with `-R` or `fdesetup authrestart`, which unlock FileVault once on the way back up.
- The agents push with a `gh` token for Owen's GitHub account. It has the `repo`, `read:org`, `gist`, `admin:ssh_signing_key` and `user:email` scopes, but not `workflow`, so it can't change workflow files. Each Mac mini signs its commits with its own key, so GitHub shows them Verified. The org-wide ruleset ([GITHUB.md](GITHUB.md)) makes every change from Owen go through a pull request that you approve, and secrets reach only jobs on the default branch.
- `ssh -a` keeps your laptop's SSH keys out of the Mac minis.
- `umask 077` makes the files the agents create readable only by `dev`.
- There are no backups. The code lives on GitHub.
