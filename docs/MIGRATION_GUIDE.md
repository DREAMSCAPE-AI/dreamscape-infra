# Migration Guide - Old CI/CD to Unified Pipeline

## Overview

This guide explains how to migrate from the old fragmented CI/CD workflows to the new unified pipeline with GitHub Deployments and Jira integration.

## What's Changing

### Old Architecture (Problems)

```
❌ Multiple overlapping workflows:
   - central-cicd.yml
   - central-dispatch.yml
   - deploy.yml
   - bigpods-ci.yml, bigpods-cd.yml

❌ No GitHub Deployments API
❌ No deployment_status for Jira
❌ Only commit statuses (not deployment tracking)
❌ No environment protection rules
❌ Fragmented deployment logic
```

### New Architecture (Solutions)

```
✅ Single unified workflow: unified-cicd.yml
✅ GitHub Deployments API integration
✅ Automatic deployment_status for Jira
✅ Environment-based protection rules
✅ Multi-repo coordination
✅ Proper deployment tracking
```

## Migration Steps

### Phase 1: Backup Old Workflows

```bash
cd dreamscape-infra/.github/workflows

# Create backup directory
mkdir -p ../../.github-workflows-backup

# Backup old workflows
cp central-cicd.yml ../../.github-workflows-backup/
cp central-dispatch.yml ../../.github-workflows-backup/
cp deploy.yml ../../.github-workflows-backup/
cp bigpods-*.yml ../../.github-workflows-backup/

# Commit backup
git add ../../.github-workflows-backup/
git commit -m "chore: backup old CI/CD workflows"
```

### Phase 2: Disable Old Workflows

**Option A: Rename (Recommended for testing)**

```bash
# Temporarily disable old workflows by renaming
mv central-cicd.yml central-cicd.yml.disabled
mv central-dispatch.yml central-dispatch.yml.disabled
mv deploy.yml deploy.yml.disabled

git add .
git commit -m "chore: disable old CI/CD workflows for migration"
git push
```

**Option B: Delete (After testing)**

```bash
# Delete old workflows (only after new pipeline is validated)
rm central-cicd.yml central-dispatch.yml deploy.yml

git add .
git commit -m "chore: remove old CI/CD workflows"
git push
```

### Phase 3: Deploy New Unified Workflow

The new workflow is already created at:
```
dreamscape-infra/.github/workflows/unified-cicd.yml
```

**Commit and push**:

```bash
cd dreamscape-infra
git add .github/workflows/unified-cicd.yml
git add docs/CICD_SETUP.md docs/MIGRATION_GUIDE.md
git commit -m "feat: add unified CI/CD pipeline with GitHub Deployments"
git push
```

### Phase 4: Update Repository Triggers

For each repository, replace the old trigger workflow:

#### dreamscape-services

```bash
cd dreamscape-services

# Backup old trigger
mkdir -p .github-workflows-backup
cp .github/workflows/trigger-central-cicd.yml .github-workflows-backup/

# Remove old trigger
rm .github/workflows/trigger-central-cicd.yml

# The new ci-trigger.yml is already created
git add .github/workflows/ci-trigger.yml
git commit -m "feat: update to new unified CI/CD trigger"
git push
```

#### dreamscape-frontend

```bash
cd dreamscape-frontend

# Backup old trigger
mkdir -p .github-workflows-backup
cp .github/workflows/trigger-central-cicd.yml .github-workflows-backup/

# Remove old trigger
rm .github/workflows/trigger-central-cicd.yml

# The new ci-trigger.yml is already created
git add .github/workflows/ci-trigger.yml
git commit -m "feat: update to new unified CI/CD trigger"
git push
```

#### dreamscape-tests

```bash
cd dreamscape-tests

# Create new trigger workflow (if needed)
cat > .github/workflows/ci-trigger.yml << 'EOF'
name: CI/CD Trigger for Tests

on:
  push:
    branches: [main, dev, develop]
  pull_request:
    branches: [main, dev, develop]

permissions:
  contents: read

jobs:
  trigger-central-pipeline:
    name: Trigger Central CI/CD
    runs-on: ubuntu-latest
    if: github.event.pull_request.draft != true
    steps:
      - name: Trigger unified CI/CD pipeline
        uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.DISPATCH_TOKEN }}
          script: |
            await github.rest.repos.createDispatchEvent({
              owner: 'DREAMSCAPE-AI',
              repo: 'dreamscape-infra',
              event_type: 'tests-changed',
              client_payload: {
                source_repo: `${context.repo.owner}/${context.repo.repo}`,
                ref: context.ref,
                sha: context.sha,
                component: 'tests',
                environment: 'dev'
              }
            });
EOF

git add .github/workflows/ci-trigger.yml
git commit -m "feat: add unified CI/CD trigger"
git push
```

### Phase 5: Configure GitHub Environments

For **each repository** (services, frontend, tests, docs):

1. Go to repository → **Settings** → **Environments**
2. Click **New environment**

#### Create `dev` environment

- **Name**: `dev`
- **Protection rules**: None
- **Secrets**:
  - `K3S_HOST`: Dev K3s server IP
  - `K3S_SSH_KEY`: Dev SSH private key

#### Create `staging` environment

- **Name**: `staging`
- **Protection rules**:
  - ☑ **Required reviewers**: Add 1 reviewer
  - ☑ **Deployment branches**: `main`, `develop`
- **Secrets**:
  - `K3S_HOST`: Staging K3s server IP
  - `K3S_SSH_KEY`: Staging SSH private key

#### Create `production` environment

- **Name**: `production`
- **Protection rules**:
  - ☑ **Required reviewers**: Add 2 reviewers
  - ☑ **Wait timer**: 5 minutes
  - ☑ **Deployment branches**: Only `main`
- **Secrets**:
  - `K3S_HOST`: Production K3s server IP
  - `K3S_SSH_KEY`: Production SSH private key

### Phase 6: Configure Repository Secrets

For **each repository**, add `DISPATCH_TOKEN`:

```bash
# Generate a Personal Access Token (PAT)
# Go to: GitHub → Settings → Developer settings → Personal access tokens

# Scopes needed:
# - repo (full control)
# - workflow (update workflows)

# Then add to each repository:
# Settings → Secrets and variables → Actions → New repository secret
# Name: DISPATCH_TOKEN
# Value: <your-PAT>
```

### Phase 7: Setup Jira Integration

#### Install GitHub for Jira

1. Go to your Jira workspace
2. Navigate to **Apps** → **Find new apps**
3. Search for **GitHub for Jira**
4. Click **Install**

#### Connect GitHub Organization

1. In Jira → **Apps** → **Manage apps**
2. Find **GitHub for Jira** → **Configure**
3. Click **Add organization**
4. Select `DREAMSCAPE-AI`
5. Authorize

#### Select Repositories

1. In GitHub for Jira configuration
2. Check all repositories:
   - ☑ dreamscape-services
   - ☑ dreamscape-frontend
   - ☑ dreamscape-tests
   - ☑ dreamscape-docs
   - ☑ dreamscape-infra
3. Enable **Deployments** feature

### Phase 8: Test the New Pipeline

#### Test 1: Dev Deployment

```bash
cd dreamscape-services/auth
git checkout -b feature/test-unified-cicd
echo "// test" >> src/server.ts
git add .
git commit -m "DR-TEST: Test unified CI/CD pipeline"
git push origin feature/test-unified-cicd
```

**Expected behavior**:
1. Local CI runs in `dreamscape-services`
2. Triggers `dreamscape-infra/unified-cicd.yml`
3. Creates GitHub Deployment for `dev` environment
4. Runs tests
5. Builds Docker image for `auth` service
6. Deployment status updated to `success`
7. Jira issue `DR-TEST` shows deployment to `dev`

#### Test 2: Staging Deployment (with approval)

```bash
git checkout develop
git merge feature/test-unified-cicd
git push origin develop
```

**Expected behavior**:
1. Triggers staging deployment
2. **Requires 1 reviewer approval**
3. After approval, deploys to staging
4. Jira shows deployment to `staging`

#### Test 3: Production Deployment (with approval + wait)

```bash
git checkout main
git merge develop
git push origin main
```

**Expected behavior**:
1. Triggers production deployment
2. **Requires 2 reviewers approval**
3. **Waits 5 minutes** after approval
4. Deploys to production
5. Jira shows deployment to `production`

### Phase 9: Verify Jira Integration

1. Open Jira issue `DR-TEST`
2. Scroll to **Deployments** section
3. Verify you see:
   - ✅ dev environment
   - ✅ staging environment (if tested)
   - ✅ production environment (if tested)
4. Click on a deployment to see details
5. Verify link to GitHub Actions run works

## Rollback Plan

If the new pipeline has issues, rollback:

### Quick Rollback

```bash
cd dreamscape-infra/.github/workflows

# Disable new workflow
mv unified-cicd.yml unified-cicd.yml.disabled

# Re-enable old workflows
mv central-cicd.yml.disabled central-cicd.yml
mv central-dispatch.yml.disabled central-dispatch.yml
mv deploy.yml.disabled deploy.yml

git add .
git commit -m "chore: rollback to old CI/CD workflows"
git push
```

### Full Rollback

```bash
# Restore from backup
cp ../../.github-workflows-backup/* .

git add .
git commit -m "chore: restore old CI/CD workflows from backup"
git push
```

## Comparison: Old vs New

### Workflow Complexity

**Old**:
```
- central-cicd.yml (381 lines)
- central-dispatch.yml (484 lines)
- deploy.yml (218 lines)
- bigpods-ci.yml
- bigpods-cd.yml
Total: ~1500+ lines across 5+ files
```

**New**:
```
- unified-cicd.yml (800 lines, all-in-one)
- ci-trigger.yml per repo (150 lines each)
Total: ~1100 lines, cleaner architecture
```

### Features

| Feature | Old | New |
|---------|-----|-----|
| GitHub Deployments | ❌ | ✅ |
| deployment_status | ❌ | ✅ |
| Jira Integration | ❌ | ✅ |
| Environment Protection | ❌ | ✅ |
| Multi-repo Support | ⚠️ Partial | ✅ Full |
| Deployment Tracking | ❌ | ✅ |
| Approval Workflow | ❌ | ✅ |
| Rollback Support | ⚠️ Manual | ✅ Via GitHub |

### Deployment Process

**Old**:
```
Push → Trigger → Build → Deploy (no tracking)
```

**New**:
```
Push → Trigger → Create Deployment → Build → Deploy → Update Status → Jira
                    ↓
              GitHub Deployment Object
                    ↓
              Environment Protection
                    ↓
              Approval (if needed)
```

## Common Issues & Solutions

### Issue: Old and new workflows both running

**Solution**: Ensure old workflows are renamed to `.disabled` extension

```bash
cd dreamscape-infra/.github/workflows
ls -la *.yml
# Should NOT see: central-cicd.yml, central-dispatch.yml, deploy.yml
# Should see: unified-cicd.yml
```

### Issue: DISPATCH_TOKEN not working

**Solution**: Verify token has correct scopes

```bash
# Token needs:
# - repo (full control of private repositories)
# - workflow (update GitHub Action workflows)
```

### Issue: Environment secrets not available

**Solution**: Secrets must be added to environment, not just repository

```bash
# Go to: Settings → Environments → [environment] → Add secret
# NOT: Settings → Secrets and variables → Actions → Repository secrets
```

### Issue: Deployment not showing in Jira

**Solution**: Ensure commit message has Jira issue key

```bash
# ✅ Good
git commit -m "DR-123: Add feature"

# ❌ Bad (won't link to Jira)
git commit -m "Add feature"
```

## Post-Migration Checklist

- [ ] Old workflows backed up
- [ ] Old workflows disabled/removed
- [ ] New unified-cicd.yml deployed to dreamscape-infra
- [ ] ci-trigger.yml updated in all repositories
- [ ] GitHub environments created (dev, staging, production)
- [ ] Environment secrets configured
- [ ] DISPATCH_TOKEN added to all repositories
- [ ] Jira for GitHub app installed
- [ ] Repositories connected to Jira
- [ ] Test deployment to dev successful
- [ ] Test deployment to staging successful (with approval)
- [ ] Test deployment to production successful (with approval)
- [ ] Jira showing deployments correctly
- [ ] Team trained on new workflow
- [ ] Old workflows deleted (after 1 week of successful operation)

## Timeline

**Recommended migration schedule**:

1. **Day 1**: Setup new workflows (Phase 1-3)
2. **Day 2**: Configure environments and secrets (Phase 5-6)
3. **Day 3**: Setup Jira integration (Phase 7)
4. **Day 4**: Test with dev environment (Phase 8, Test 1)
5. **Day 5**: Test with staging environment (Phase 8, Test 2)
6. **Week 2**: Monitor and fix issues
7. **Week 3**: Test production deployment (Phase 8, Test 3)
8. **Week 4**: Full migration, delete old workflows

## Support

If you encounter issues during migration:

1. Check workflow logs in GitHub Actions
2. Review this migration guide
3. Check `docs/CICD_SETUP.md` for configuration details
4. Contact DevOps team
5. If critical issue, use rollback plan

## Next Steps After Migration

1. **Monitor deployments** for 1 week
2. **Train team** on new workflow
3. **Update documentation** with any changes
4. **Delete old workflows** after validation
5. **Setup Slack notifications** for deployment status
6. **Create deployment dashboard** in Jira
