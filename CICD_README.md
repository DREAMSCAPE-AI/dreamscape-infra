# CI/CD Pipeline - GitHub Deployments & Jira Integration

## Quick Overview

This is the **unified CI/CD pipeline** for DreamScape's multi-repository architecture with **GitHub Deployments API** and **Jira integration**.

## Key Features

✅ **GitHub Deployments API** - Track deployments natively in GitHub
✅ **Jira Integration** - Automatic deployment tracking in Jira issues
✅ **Multi-Repository Support** - Coordinates services, frontend, tests, docs
✅ **Environment Protection** - Production approvals; staging auto-deploy on `main`
✅ **Single Source of Truth** - One unified workflow instead of 5+ fragmented ones
✅ **Proper Status Tracking** - Both commit status AND deployment status
✅ **Automated Testing** - Integration tests run before deployment
✅ **Docker Build & Push** - Automatic image creation and registry push
✅ **K3s Deployment** - Automated Kubernetes deployments

## Architecture

```
┌──────────────────────┐
│ dreamscape-services  │─┐
│ dreamscape-frontend  │─┤
│ dreamscape-tests     │─┼─► repository_dispatch ─► dreamscape-infra/unified-cicd.yml
│ dreamscape-docs      │─┘                           │
└──────────────────────┘                             │
                                                     ↓
                                          ┌──────────────────────┐
                                          │ 1. Create Deployment │
                                          │ 2. Run Tests         │
                                          │ 3. Build Images      │
                                          │ 4. Deploy to K3s     │
                                          │ 5. Update Status     │
                                          └──────────┬───────────┘
                                                     │
                                                     ↓
                                          deployment_status webhook
                                                     │
                                                     ↓
                                              Jira Software
```

## Files Created

### Main Workflow
- **`dreamscape-infra/.github/workflows/unified-cicd.yml`**
  Central orchestration workflow with GitHub Deployments API

### Repository Triggers
- **`dreamscape-services/.github/workflows/ci-trigger.yml`**
  Triggers central pipeline when services change

- **`dreamscape-frontend/.github/workflows/ci-trigger.yml`**
  Triggers central pipeline when frontend changes

### Documentation
- **`dreamscape-infra/docs/CICD_SETUP.md`**
  Complete setup guide for GitHub Deployments & Jira

- **`dreamscape-infra/docs/MIGRATION_GUIDE.md`**
  Step-by-step migration from old workflows

## Quick Start

### 1. Setup GitHub Environments

For each repository, create 3 environments:

```bash
# In GitHub UI: Settings → Environments → New environment

dev        # No restrictions
staging    # Auto deploy on push to main (no approval gate)
production # Manual promotion only (2 reviewers + 5 min wait)
```

### 2. Add Secrets

**Repository Secrets** (for all repos):
```
DISPATCH_TOKEN  # Personal Access Token with repo + workflow scopes
```

**Environment Secrets** (for each environment):
```
K3S_HOST      # K3s server IP
K3S_SSH_KEY   # SSH private key
```

### 3. Install Jira for GitHub

1. Jira → Apps → Find new apps → "GitHub for Jira"
2. Connect `DREAMSCAPE-AI` organization
3. Select all repositories
4. Enable **Deployments** feature

### 4. Test the Pipeline

```bash
cd dreamscape-services/auth
git checkout -b feature/test-cicd
echo "// test" >> src/server.ts
git commit -m "DR-123: Test CI/CD pipeline"
git push origin feature/test-cicd
```

**What happens**:
1. Local CI runs (lint/typecheck)
2. Triggers `unified-cicd.yml` in dreamscape-infra
3. Creates GitHub Deployment for `dev` environment
4. Runs integration tests
5. Builds Docker image for `auth` service
6. Deploys to K3s dev cluster
7. Updates deployment status to `success`
8. Jira issue `DR-123` shows deployment to `dev`

## Branch → Environment Mapping

| Branch | Environment | Approval Required |
|--------|-------------|-------------------|
| `feature/**`, `dev` | dev | No |
| `develop` | staging | 1 reviewer |
| `main` | staging | No (auto deploy on push) |

## How GitHub Deployments Work

### 1. Create Deployment

```javascript
const deployment = await github.rest.repos.createDeployment({
  owner: 'DREAMSCAPE-AI',
  repo: 'dreamscape-services',
  ref: 'main',
  environment: 'staging',
  description: 'Deploy to staging'
});
```

This creates a **Deployment** object that GitHub and Jira track.

### 2. Update Deployment Status

```javascript
// Set to in_progress
await github.rest.repos.createDeploymentStatus({
  deployment_id: deployment.data.id,
  state: 'in_progress',
  description: 'Deployment running'
});

// Set to success
await github.rest.repos.createDeploymentStatus({
  deployment_id: deployment.data.id,
  state: 'success',
  environment_url: 'https://staging.dreamscape.ai'
});
```

### 3. Jira Receives Webhook

When `createDeploymentStatus` is called, GitHub sends a `deployment_status` webhook to Jira automatically.

## Viewing Deployments

### In GitHub

```
Repository → Environments → [environment] → View deployment history
```

### In Jira

```
Open issue (e.g., DR-123) → Scroll to "Deployments" section
```

You'll see:
- ✅ Which environments the issue is deployed to
- ✅ Deployment time
- ✅ Deployment status (success/failure)
- ✅ Link to GitHub Actions run
- ✅ Link to environment URL

## Workflow Jobs

The unified pipeline has 8 jobs:

1. **parse-and-create-deployment** - Parse event & create GitHub Deployment
2. **clone-source** - Clone the source repository
3. **run-tests** - Run integration tests
4. **build-and-push** - Build & push Docker images
5. **deploy-to-k3s** - Deploy to Kubernetes cluster
6. **deployment-success** - Update status to success
7. **deployment-failure** - Update status to failure (if failed)
8. **summary** - Generate pipeline summary

## Environment Variables

The workflow uses these environment variables:

```yaml
DOCKER_REGISTRY: ghcr.io          # GitHub Container Registry
ORG: dreamscape-ai                # Organization name
```

## Secrets Required

### Repository Secrets (all repos)
- `DISPATCH_TOKEN` - GitHub PAT for triggering workflows

### Environment Secrets (per environment)
- `K3S_HOST` - Kubernetes server IP
- `K3S_SSH_KEY` - SSH private key for K3s access

### Automatic Secrets
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions

## Migration from Old Workflows

If you have old workflows (`central-cicd.yml`, `central-dispatch.yml`, `deploy.yml`):

1. **Read** `docs/MIGRATION_GUIDE.md`
2. **Backup** old workflows
3. **Disable** old workflows (rename to `.disabled`)
4. **Deploy** new unified workflow
5. **Test** with dev environment
6. **Delete** old workflows after validation

## Troubleshooting

### Deployment not showing in Jira

**Fix**: Ensure commit message includes Jira issue key
```bash
git commit -m "DR-123: Add feature"  # ✅ Good
git commit -m "Add feature"           # ❌ Won't link to Jira
```

### DISPATCH_TOKEN error

**Fix**: Create PAT with `repo` and `workflow` scopes
```
GitHub → Settings → Developer settings → Personal access tokens
```

### Environment approval not working

**Fix**: Configure environment protection rules
```
Repository → Settings → Environments → [environment] → Required reviewers
```

## Best Practices

### 1. Always include Jira issue keys

```bash
git commit -m "DR-123: feat(auth): add OAuth2"
```

### 2. Test in dev first

```bash
feature/** → dev → develop → main → staging (auto) → production (manual)
```

### 3. Use semantic commits

```bash
feat(service): description   # New feature
fix(service): description    # Bug fix
chore(service): description  # Maintenance
```

### 4. Monitor deployments

- Check GitHub Actions for pipeline status
- Check Jira for deployment tracking
- Set up Slack notifications

## Documentation

- **[CICD_SETUP.md](docs/CICD_SETUP.md)** - Complete setup guide
- **[MIGRATION_GUIDE.md](docs/MIGRATION_GUIDE.md)** - Migration from old workflows

## Support

For issues or questions:

1. Check workflow logs in GitHub Actions
2. Review documentation in `docs/`
3. Contact DevOps team
4. Create issue in `dreamscape-infra` repository

## What's Different from Old Workflows

| Feature | Old | New |
|---------|-----|-----|
| **GitHub Deployments** | ❌ No | ✅ Yes |
| **Jira Integration** | ❌ No | ✅ Automatic |
| **Environment Protection** | ❌ No | ✅ Yes |
| **Approval Workflow** | ❌ No | ✅ Yes |
| **Deployment Tracking** | ❌ Commit status only | ✅ Full deployment tracking |
| **Number of Workflows** | 5+ fragmented | 1 unified |
| **Lines of Code** | ~1500+ | ~1100 |
| **Jira Updates** | ❌ Manual | ✅ Automatic |

## Next Steps

1. ✅ Read `docs/CICD_SETUP.md`
2. ✅ Configure GitHub environments
3. ✅ Add repository secrets
4. ✅ Setup Jira integration
5. ✅ Test with dev deployment
6. ✅ Test with staging deployment
7. ✅ Test with production deployment
8. ✅ Train team on new workflow
9. ✅ Delete old workflows

---

**Created**: 2025-11-27
**Last Updated**: 2025-11-27
**Version**: 1.0.0
**Status**: Production Ready
