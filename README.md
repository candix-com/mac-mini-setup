# Mac mini setup

Why things are set up this way: [NOTES.md](NOTES.md).

## Once

1. **Tailscale:** paste [policy.json](policy.json) into the admin console, under Access controls. Merge it with what is already there, and replace `you@candix.com` with your email.
2. **GitHub token for each Mac mini:** Owen creates a fine-grained token at github.com/settings/personal-access-tokens:
   - resource owner `candix-com`, only the repos the agents work on
   - Contents and Pull requests: Read and write. No Workflows.
   - an expiry date
3. **GitHub repo settings:** in every repo the agents work on:
   - a branch ruleset on `main`:
     - require a pull request with 1 approval, and approval of the most recent push
     - block force pushes and deletions
     - no bypass for Owen
   - put every secret in an environment that only `main` can use
   - Actions: read-only token, and untick "Allow GitHub Actions to create and approve pull requests"
   - if a workflow runs on tags: a tag ruleset, with bypass only for a team Owen is not in

## Each Mac mini

Wi-Fi is fine. Plug in the Ethernet cable later; nothing else changes.

1. On the first setup screens:
   - join Wi-Fi
   - create the account: full name `admin`, account name `admin`
   - skip Apple Account, Location and Siri
2. Open Terminal and run:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/candix-com/mac-mini-setup/main/setup.sh)"
   ```
   It asks for the machine number, the passwords and Owen's token.
3. Do what it lists at the end.

## Your laptop

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/candix-com/mac-mini-setup/main/laptop.sh)"
```

Then type `mini-1`, `mini-2` or `mini-3`.

## Updates

- **Monthly, from your laptop:** `ssh admin@mini-<n>`, then `brew upgrade`.
- **macOS:**
  1. `softwareupdate -l`
  2. `sudo softwareupdate -i '<label>' -R --user admin`
- **Tailscale, at the Mac mini, after a security bulletin:**
  1. `brew unpin tailscale && brew upgrade tailscale`
  2. `sudo brew services restart tailscale && brew pin tailscale`
- **Restart:** `sudo fdesetup authrestart`, so it comes back without anyone typing a password.
- **After a power cut:** unlock at the Mac mini as `admin` or `stats`, never `dev`.
