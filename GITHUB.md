# GitHub

Do this in every repo the agents work on, and in this one (candix-com/mac-mini-setup), since the Mac minis and your laptop run its scripts.

1. **Settings** → **Rules** → **Rulesets** → **New ruleset** → **New branch ruleset**:
   - Ruleset name: `main`
   - Enforcement status: **Active**
   - Target branches → **Add target** → **Include default branch**
   - Tick **Restrict deletions** and **Block force pushes**.
   - Tick **Require a pull request before merging**, set **Required approvals** to 1, and tick **Require approval of the most recent reviewable push**.
   - Click **Create**.
2. **Settings** → **Environments** → **New environment** → name `production` → **Configure environment**:
   - **Deployment branches and tags** → **Selected branches and tags** → **Add deployment branch or tag rule** → `main`.
   - Add every secret under **Environment secrets**.
3. **Settings** → **Secrets and variables** → **Actions**: delete everything under **Repository secrets**.
4. In `.github/workflows`, add `environment: production` to every job that uses a secret.
5. **Settings** → **Actions** → **General** → **Workflow permissions**: pick **Read repository contents and packages permissions**, untick **Allow GitHub Actions to create and approve pull requests**, click **Save**.
6. If a workflow runs on tags: **Rulesets** → **New ruleset** → **New tag ruleset** → target **Include all tags**, tick **Restrict creations**, **Restrict updates** and **Restrict deletions**, add a team Owen is not in to the bypass list, click **Create**.
7. If a workflow uses `pull_request_target` or `workflow_run`, ask Claude whether a pull request can make it run code that sees the secrets.
