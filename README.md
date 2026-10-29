# Mac mini setup

Steps 2 to 5 for each Mac mini, starting with mini-1. Why it's set up this way: [NOTES.md](NOTES.md).

## 1. Tailscale policy (before the first Mac mini only)

On your laptop:

1. Open https://login.tailscale.com/admin/acls/file.
2. Copy all of [policy.json](policy.json).
3. If you never changed your policy: select everything in the editor, delete it, paste. Otherwise, ask Claude to merge the two.
4. Replace every `you@candix.com` with the email you log in to Tailscale with.
5. Click **Save**.

## 2. macOS

1. Plug in the Ethernet cable (if you have it), a screen, a keyboard and a mouse. Plug in the power last.
2. Answer the setup screens:

| Screen | Do this |
| --- | --- |
| Language, Country or Region, Time Zone | yours |
| Wi-Fi | your network |
| Transfer Your Data, Accessibility | **Not Now** |
| Data & Privacy | **Continue** |
| Sign In with Your Apple Account | **Set Up Later**, then **Skip** |
| Terms and Conditions | **Agree**, then **Agree** |
| Create a Mac Account | Full name `admin`, Account name `admin`, a new password. Save it in your password manager. |
| Location Services | off, then **Don't Use** |
| Analytics, Siri | untick everything |
| Screen Time | **Set Up Later** |
| FileVault | untick it |
| Update Mac Automatically | **Only Download Automatically** |
| anything else | **Not Now**, **Skip** or **Set Up Later** |

## 3. Run the script

1. Open Terminal: press Cmd-Space, type `Terminal`, press Enter.
2. Paste this and press Enter:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/candix-com/mac-mini-setup/main/setup.sh)"
   ```
3. Along the way (about 15 minutes):
   1. Type the Mac mini's number: `1`, `2` or `3`. mini-1 is the one with the screen.
   2. Type admin's password.
   3. User `dev`: type a new password, then admin's password. Save dev's password in your password manager.
   4. User `stats`: same.
   5. FileVault: type admin's password. Save the recovery key it shows in your password manager.
   6. FileVault for `stats`: if it asks for a user name, type `admin`. Then type the password it names.
   7. A Tailscale tab opens: log in with your account, click **Connect**.
   8. GitHub: answer **GitHub.com**, **HTTPS**, **Yes**, **Login with a web browser**. Copy the code it shows, press Enter, log in as Owen, paste the code, click **Authorize**. If no browser opens, open https://github.com/login/device yourself.
4. It ends with **Done** and tells you the next step.

## 4. The dashboard (mini-1 only)

1. Apple menu → **Log Out admin**.
2. Log in as `stats`.
3. **System Settings** → **General** → **Login Items & Extensions** → under **Open at Login**, click **+**.
4. Press Cmd-Shift-H, select `dashboard.command`, click **Open**.
5. Close System Settings. In Finder, press Cmd-Shift-H and double-click `dashboard.command`.
6. **Terminal** menu → **Settings** → **Profiles** → **Text** → **Font: Change** → size 24. Close the windows.
7. Plug the screen's USB cable into the power strip, not into the Mac mini.
8. Unplug the keyboard and mouse.

## 5. Your laptop

1. On the Mac mini (mini-2 and mini-3): Apple menu → **Log Out admin**, then unplug the screen, keyboard and mouse.
2. On your laptop, the Tailscale app must be on and logged in with your account.
3. In Terminal:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/candix-com/mac-mini-setup/main/laptop.sh)"
   ```
4. Type the Mac mini's number.
5. Claude opens to log in: click the link, approve it in the browser, paste the code back, then type `/exit`.

Next Mac mini: back to step 2.

## 6. GitHub (once per repo the agents work on)

In the repo on github.com:

1. **Settings** → **Rules** → **Rulesets** → **New ruleset** → **New branch ruleset**:
   - Ruleset name: `main`
   - Enforcement status: **Active**
   - Target branches → **Add target** → **Include default branch**
   - tick **Restrict deletions** and **Block force pushes**
   - tick **Require a pull request before merging**, set **Required approvals** to 1, tick **Require approval of the most recent reviewable push**
   - click **Create**
2. **Settings** → **Environments** → **New environment** → name `production` → **Configure environment**:
   - **Deployment branches and tags** → **Selected branches and tags** → **Add deployment branch or tag rule** → `main`
   - add every secret under **Environment secrets**
3. **Settings** → **Secrets and variables** → **Actions**: delete everything under **Repository secrets**.
4. In `.github/workflows`, add `environment: production` to every job that uses a secret.
5. **Settings** → **Actions** → **General** → **Workflow permissions**: pick **Read repository contents and packages permissions**, untick **Allow GitHub Actions to create and approve pull requests**, click **Save**.
6. If a workflow runs on tags: **Rulesets** → **New ruleset** → **New tag ruleset** → target **Include all tags**, tick **Restrict creations**, **Restrict updates** and **Restrict deletions**, add a team Owen is not in to the bypass list, click **Create**.
7. If a workflow uses `pull_request_target` or `workflow_run`, ask Claude to check it.

## Daily use

| Do this | How |
| --- | --- |
| Open a Mac mini's terminal (all tabs still there) | `mini-1`, `mini-2` or `mini-3` |
| Start Claude | `claude` |
| New tab | `Ctrl-b` then `c` |
| Next / previous tab | `Ctrl-b` then `n` / `p` |
| List all tabs, jump to one | `Ctrl-b` then `w` |
| Close a tab | `exit` |
| Leave, keeping everything running | close the window |
| Copy text | `Cmd-R`, select, `Cmd-C`, then `Cmd-R` again |
| Update the tools (monthly) | `ssh admin@mini-1`, then `brew upgrade` |
| Update macOS | `ssh admin@mini-1`, `softwareupdate -l`, then `sudo softwareupdate -i 'LABEL' -R --user admin` with the label it showed |
| Restart | `ssh admin@mini-1`, then `sudo fdesetup authrestart` |
| After a power cut | at the Mac mini, plug in a keyboard, log in as `admin` (`stats` on mini-1). Never `dev`. |
| Update Tailscale (after a Tailscale security bulletin) | at the Mac mini, as `admin`: `brew unpin tailscale && brew upgrade tailscale && sudo brew services restart tailscale && brew pin tailscale` |

`ssh admin@…` may show a Tailscale link: open it and log in.
