# Mac mini setup

Step 1 once. Steps 2 to 5 on each Mac mini, mini-1 first. Then [GITHUB.md](GITHUB.md) once per repo the agents work on. Why it's set up this way: [NOTES.md](NOTES.md).

## 1. Tailscale policy

On your laptop:

1. Open https://login.tailscale.com/admin/acls/file.
2. If you never changed your policy, replace all of it with [policy.json](policy.json). Otherwise, ask Claude to add the `groups`, `tagOwners`, `postures`, `grants` and `ssh` entries of policy.json to your policy without removing any of yours, and paste the result.
3. In `group:owner`, replace `you@candix.com` with the email you log in to Tailscale with.
4. Click **Save**.

## 2. macOS

1. Plug in the Ethernet cable, a screen, a keyboard and a mouse, then the power.
2. On the setup screens:
   - Create the account with full name `admin` and account name `admin`. Save its password in your password manager.
   - Turn FileVault on, with a recovery key. Save the key in your password manager.
   - Skip everything else.

## 3. Run the script

1. Open Terminal: press Cmd-Space, type `Terminal`, press Enter.
2. Paste this and press Enter:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/candix-com/mac-mini-setup/main/setup.sh)"
   ```
3. Along the way:
   1. Type the Mac mini's number: `1` for the one with the screen, then `2`, `3`, and so on.
   2. Type admin's password.
   3. mini-1 only: type a new password for `stats`, then admin's password. Save stats' password in your password manager. If FileVault then asks for a user name, type `admin`, then the passwords it asks for.
   4. A Tailscale tab opens: log in with your account, click **Connect**.
   5. GitHub: answer **GitHub.com**, **HTTPS**, **Yes**, **Login with a web browser**. Copy the code it shows, press Enter, log in to GitHub as Owen (`owreed`), paste the code, click **Authorize**. If no browser opens, open https://github.com/login/device.
4. When it says **Done**: Apple menu → **Log Out admin**. On every Mac mini but mini-1, unplug the screen, keyboard and mouse.

## 4. Dashboard (mini-1 only)

1. Log in as `stats`. The dashboard opens in Terminal.
2. **Terminal** menu → **Settings** → **Profiles** → **Text** → **Font: Change** → size 24. Close the windows.
3. Plug the screen's USB cable into the power strip, not into the Mac mini.
4. Unplug the keyboard and mouse.

## 5. Your laptop

1. Turn on the Tailscale app, logged in with your account.
2. In Terminal:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/candix-com/mac-mini-setup/main/laptop.sh)"
   ```
3. Type the Mac mini's number.
4. Claude opens to log in: click the link, approve it in the browser, paste the code back, then type `/exit`.

Next Mac mini: step 2.

## Daily use

| Do this                                               | How                                                                                                                                                                         |
| ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Open a Mac mini's terminal (all tabs still there)     | `mini-<n>`                                                                                                                                                                  |
| Start Claude                                          | `claude`                                                                                                                                                                    |
| New tab                                               | `Ctrl-b` then `c`                                                                                                                                                           |
| Next / previous tab                                   | `Ctrl-b` then `n` / `p`                                                                                                                                                     |
| List all tabs, jump to one                            | `Ctrl-b` then `w`                                                                                                                                                           |
| Close a tab                                           | `exit`                                                                                                                                                                      |
| Leave, keeping everything running                     | close the window                                                                                                                                                            |
| Copy text                                             | `Cmd-R`, select, `Cmd-C`, then `Cmd-R` again to get scrolling back                                                                                                          |
| Update the tools, monthly, on each Mac mini           | `ssh admin@mini-<n>`, then `brew upgrade`                                                                                                                                   |
| Update macOS on a Mac mini                            | `ssh admin@mini-<n>`, `softwareupdate -l`, then `sudo softwareupdate -i 'LABEL' -R --user admin` with the label it showed                                                   |
| Restart a Mac mini                                    | `ssh admin@mini-<n>`, then `sudo fdesetup authrestart`                                                                                                                      |
| After a power cut                                     | Each Mac mini waits for a FileVault password. mini-1: log in as `stats`. The others: plug in a screen and keyboard, log in as `admin`, then Apple menu → **Log Out admin**. |
| Update Tailscale, after a Tailscale security bulletin | At the Mac mini, logged in as `admin`, in Terminal: `brew unpin tailscale && brew upgrade tailscale && sudo brew services restart tailscale && brew pin tailscale`          |

If `ssh admin@…` shows a Tailscale link, open it and log in.
