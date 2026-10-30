# GitHub

## Once, for the whole org

Already done for candix-com. For a new org, as an org admin:

1. **Settings** → **Repository** → **Rulesets** → **New ruleset** → **New branch ruleset**:
   - Ruleset name: `protect-default-branch`
   - Enforcement status: **Active**
   - Bypass list → **Add bypass** → **Organization admin**, set to **For pull requests only**
   - Target repositories → **All repositories**
   - Target branches → **Include default branch**
   - Tick **Restrict deletions** and **Block force pushes**.
   - Tick **Require a pull request before merging**, set **Required approvals** to 1, and tick **Require approval of the most recent reviewable push**.
   - Click **Create**.
2. **Settings** → **Actions** → **General** → **Workflow permissions**: pick **Read repository contents and packages permissions**, untick **Allow GitHub Actions to create and approve pull requests**, click **Save**.

## In each repo that deploys

1. **Settings** → **Environments** → **New environment** → name `production` → **Configure environment**:
   - **Deployment branches and tags** → **Selected branches and tags** → **Add deployment branch or tag rule** → the default branch.
   - Add every secret under **Environment secrets**, never under **Repository secrets**.
2. In `.github/workflows`, add `environment: production` to every job that uses a secret.
3. Don't use `pull_request_target` or `workflow_run`. If a workflow runs on tags, ask Claude to add a tag rule.
