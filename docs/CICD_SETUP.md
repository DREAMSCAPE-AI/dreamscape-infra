# CI/CD Setup Guide - GitHub Deployments & Jira Integration

## Overview

This guide explains how to set up the unified CI/CD pipeline with GitHub Deployments and Jira integration for the DreamScape multi-repository architecture.

## Architecture

```
┌─────────────────────┐
│ dreamscape-services │──┐
│  (Local CI/Lint)    │  │
└─────────────────────┘  │
                         │  repository_dispatch
┌─────────────────────┐  │  → unified-cicd.yml
│ dreamscape-frontend │──┼─────────────────────────┐
│  (Local CI/Lint)    │  │                         │
└─────────────────────┘  │                         ↓
                         │              ┌──────────────────────┐
┌─────────────────────┐  │              │  dreamscape-infra    │
│  dreamscape-tests   │──┤              │                      │
└─────────────────────┘  │              │  1. Create Deployment│
                         │              │  2. Run Tests        │
┌─────────────────────┐  │              │  3. Build Images     │
│  dreamscape-docs    │──┘              │  4. Deploy to K3s    │
└─────────────────────┘                 │  5. Update Status    │
                                        └──────────┬───────────┘
                                                   │
                                                   ↓
                                        GitHub Deployments API
                                                   │
                                                   ↓
                                              deployment_status
                                                   │
                                                   ↓
                                             Jira Software
```

## GitHub Deployments Flow

### 1. Create Deployment

When a push occurs to `main`, `develop`, or other tracked branches:

```yaml
# In unified-cicd.yml
- name: Create GitHub Deployment
  uses: actions/github-script@v7
  with:
    github-token: ${{ secrets.DISPATCH_TOKEN }}
    script: |
      const deployment = await github.rest.repos.createDeployment({
        owner: owner,
        repo: repo,
        ref: ref,
        environment: 'production', // or 'staging', 'dev'
        description: 'Deploy to production',
        auto_merge: false,
        required_contexts: []
      });
```

This creates a **GitHub Deployment** object that Jira can track.

### 2. Update Deployment Status

Throughout the pipeline, update the deployment status:

```yaml
# Set to in_progress when deployment starts
await github.rest.repos.createDeploymentStatus({
  deployment_id: deploymentId,
  state: 'in_progress',
  log_url: 'https://github.com/.../actions/runs/...',
  description: 'Deployment pipeline running'
});

# Set to success when deployment completes
await github.rest.repos.createDeploymentStatus({
  deployment_id: deploymentId,
  state: 'success',
  environment_url: 'https://production.dreamscape.ai'
});

# Set to failure if deployment fails
await github.rest.repos.createDeploymentStatus({
  deployment_id: deploymentId,
  state: 'failure',
  description: 'Tests failed'
});
```

### 3. Jira Receives `deployment_status` Webhook

When `createDeploymentStatus` is called, GitHub sends a `deployment_status` webhook event to Jira (if configured).

## Jira Integration Setup

### Step 1: Install GitHub for Jira

1. Go to your Jira workspace
2. Navigate to **Apps** → **Find new apps**
3. Search for **GitHub for Jira**
4. Click **Install**

### Step 2: Connect GitHub Organization

1. In Jira, go to **Apps** → **Manage apps**
2. Find **GitHub for Jira** and click **Configure**
3. Click **Add organization**
4. Select your GitHub organization: `DREAMSCAPE-AI`
5. Authorize the connection

### Step 3: Select Repositories

1. In the GitHub for Jira configuration
2. Select which repositories to sync:
   - `dreamscape-services`
   - `dreamscape-frontend`
   - `dreamscape-tests`
   - `dreamscape-docs`
   - `dreamscape-infra`
3. Enable **Deployments** feature

### Step 4: Configure Deployment Environments

In GitHub, create environments for each repository:

```bash
# For each repository (services, frontend, etc.)
# Go to: Settings → Environments → New environment
```

Create these environments:
- **dev** - Development environment
- **staging** - Staging environment (requires 1 reviewer)
- **production** - Production environment (requires 2 reviewers)

#### Environment Configuration

For **production**:
- **Required reviewers**: Add 2 team members
- **Wait timer**: 5 minutes
- **Deployment branches**: Only `main`

For **staging**:
- **Required reviewers**: Add 1 team member
- **Deployment branches**: `main`, `develop`

For **dev**:
- **No restrictions**

### Step 5: Configure Environment Secrets

For each environment, add these secrets:

```
# In GitHub: Settings → Secrets and variables → Actions → Environments
```

**Production Environment:**
- `K3S_HOST` - Production K3s server IP
- `K3S_SSH_KEY` - Production SSH key
- `DATABASE_URL` - Production database URL

**Staging Environment:**
- `K3S_HOST` - Staging K3s server IP
- `K3S_SSH_KEY` - Staging SSH key
- `DATABASE_URL` - Staging database URL

**Dev Environment:**
- `K3S_HOST` - Dev K3s server IP
- `K3S_SSH_KEY` - Dev SSH key
- `DATABASE_URL` - Dev database URL

### Step 6: Configure Repository Secrets

Add these secrets to **ALL repositories**:

```
# In each repo: Settings → Secrets and variables → Actions → Repository secrets
```

- `DISPATCH_TOKEN` - Personal Access Token with `repo` and `workflow` scopes
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions

#### Creating DISPATCH_TOKEN

1. Go to GitHub → **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **Generate new token (classic)**
3. Give it a name: `DreamScape CI/CD Dispatch Token`
4. Select scopes:
   - `repo` (full repository access)
   - `workflow` (update workflows)
5. Click **Generate token**
6. Copy the token and add it to each repository as `DISPATCH_TOKEN`

## Workflow Configuration

### Repository-Specific Workflows

Each repository (`dreamscape-services`, `dreamscape-frontend`, etc.) has a trigger workflow:

**Location**: `.github/workflows/ci-trigger.yml`

**Triggers**:
- Push to `main`, `develop`, `dev`, `feature/**`, `bugfix/**`
- Pull requests to `main`, `develop`, `dev`

**Actions**:
1. Run local CI (lint, typecheck)
2. Detect changed components
3. Trigger central pipeline via `repository_dispatch`

### Central Orchestration Workflow

**Location**: `dreamscape-infra/.github/workflows/unified-cicd.yml`

**Receives**: `repository_dispatch` events from all repos

**Actions**:
1. **Create GitHub Deployment** for the source repository
2. **Run tests** from `dreamscape-tests` repository
3. **Build Docker images** for changed components
4. **Deploy to K3s** cluster
5. **Update deployment status** (success/failure)
6. **Send `deployment_status`** to Jira automatically

## Jira Issue Linking

### Automatic Linking via Commit Messages

Include Jira issue keys in commit messages:

```bash
git commit -m "DR-123: Add user authentication"
```

GitHub for Jira will automatically:
- Link the commit to Jira issue `DR-123`
- Show deployment status in Jira
- Track which issues are in which environment

### Deployment Information in Jira

When deployment succeeds, Jira shows:
- **Environment**: production, staging, or dev
- **Deployment time**: When it was deployed
- **Deployment URL**: Link to the environment
- **Pipeline URL**: Link to GitHub Actions run
- **Status**: Success or Failure

### Viewing Deployments in Jira

1. Open a Jira issue (e.g., `DR-123`)
2. Scroll to **Deployments** section
3. See all environments where this issue is deployed
4. Click on deployment to see details

## Branch → Environment Mapping

```
main       → production
develop    → staging
dev        → dev
feature/** → dev (on manual trigger)
```

## Testing the Pipeline

### Test 1: Push to Services Repository

```bash
cd dreamscape-services/auth
git checkout -b feature/test-pipeline
echo "// test" >> src/server.ts
git add .
git commit -m "DR-123: Test CI/CD pipeline"
git push origin feature/test-pipeline
```

**Expected**:
1. `dreamscape-services` runs local CI
2. Triggers `dreamscape-infra/unified-cicd.yml`
3. Creates deployment for `dev` environment
4. Runs tests
5. Builds Docker image for `auth` service
6. Updates deployment status
7. Jira issue `DR-123` shows deployment to `dev`

### Test 2: Merge to Main (Production)

```bash
# Create PR from feature branch to main
# Merge PR via GitHub UI
```

**Expected**:
1. Triggers production deployment workflow
2. **Requires approval** from 2 reviewers (if configured)
3. Creates deployment for `production` environment
4. Runs full test suite
5. Builds and deploys all services
6. Updates Jira with production deployment

## Monitoring Deployments

### GitHub UI

View deployments:
- Repository → **Environments**
- See deployment history for each environment
- Click on deployment to see workflow run

### Jira UI

View deployments:
- Open any issue
- Scroll to **Deployments** section
- See all environments and deployment times

### GitHub Actions

View pipeline runs:
- `dreamscape-infra` repository → **Actions**
- Filter by workflow: `Unified CI/CD Pipeline`
- See all deployment runs and statuses

## Troubleshooting

### Issue: Deployment not showing in Jira

**Solution**:
1. Check GitHub for Jira app is installed
2. Verify repositories are connected in Jira
3. Ensure commit messages include Jira issue keys
4. Check webhook delivery in GitHub Settings → Webhooks

### Issue: Deployment status stuck on "in_progress"

**Solution**:
1. Check workflow run in GitHub Actions
2. Look for errors in deployment jobs
3. Manually update deployment status if needed:
   ```bash
   gh api repos/DREAMSCAPE-AI/dreamscape-services/deployments/{id}/statuses \
     -f state=failure \
     -f description="Manual fix"
   ```

### Issue: Environment approval not required

**Solution**:
1. Go to repository → **Settings** → **Environments**
2. Click on environment (e.g., `production`)
3. Add **Required reviewers**
4. Save changes

### Issue: DISPATCH_TOKEN not working

**Solution**:
1. Regenerate token with correct scopes (`repo`, `workflow`)
2. Update secret in all repositories
3. Ensure token is from an account with admin access

## Best Practices

### 1. Always use Jira issue keys in commits

```bash
git commit -m "DR-123: Add feature"  # ✅ Good
git commit -m "Add feature"           # ❌ Bad - no tracking
```

### 2. Use semantic commit messages

```bash
git commit -m "DR-123: feat(auth): add OAuth2 support"
git commit -m "DR-124: fix(voyage): resolve booking conflict"
```

### 3. Test in dev before staging/production

```bash
# Always deploy to dev first
git push origin feature/my-feature

# Then merge to develop for staging
git checkout develop
git merge feature/my-feature

# Finally merge to main for production
git checkout main
git merge develop
```

### 4. Monitor deployment status

- Check GitHub Actions for pipeline status
- Check Jira for deployment tracking
- Set up Slack notifications for failures

## Next Steps

1. **Configure all repositories** with the new workflows
2. **Set up GitHub environments** with protection rules
3. **Add DISPATCH_TOKEN** to all repositories
4. **Connect Jira** to GitHub organization
5. **Test the pipeline** with a sample commit
6. **Configure notifications** for deployment failures

## Additional Resources

- [GitHub Deployments API](https://docs.github.com/en/rest/deployments/deployments)
- [GitHub for Jira Documentation](https://github.com/integrations/jira)
- [GitHub Actions Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments)
