#!/bin/bash
#
# Quick Deploy Commands - CI/CD Unified Pipeline
#
# Ce script contient toutes les commandes nécessaires pour déployer
# le nouveau pipeline CI/CD unifié avec GitHub Deployments et Jira
#

set -e  # Exit on error

echo "========================================"
echo "CI/CD Unified Pipeline - Quick Deploy"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================
# STEP 1: Backup Old Workflows
# ============================================
echo -e "${YELLOW}STEP 1: Backup old workflows${NC}"
echo ""

backup_old_workflows() {
    cd dreamscape-infra

    mkdir -p .github-workflows-backup

    echo "Backing up old workflows..."
    cp .github/workflows/central-cicd.yml .github-workflows-backup/ 2>/dev/null || echo "central-cicd.yml not found"
    cp .github/workflows/central-dispatch.yml .github-workflows-backup/ 2>/dev/null || echo "central-dispatch.yml not found"
    cp .github/workflows/deploy.yml .github-workflows-backup/ 2>/dev/null || echo "deploy.yml not found"
    cp .github/workflows/bigpods-*.yml .github-workflows-backup/ 2>/dev/null || echo "bigpods workflows not found"

    echo -e "${GREEN}✓ Old workflows backed up to .github-workflows-backup/${NC}"

    cd ..
}

# Uncomment to execute
# backup_old_workflows

# ============================================
# STEP 2: Disable Old Workflows
# ============================================
echo -e "${YELLOW}STEP 2: Disable old workflows${NC}"
echo ""

disable_old_workflows() {
    cd dreamscape-infra/.github/workflows

    echo "Disabling old workflows..."
    [ -f central-cicd.yml ] && mv central-cicd.yml central-cicd.yml.disabled
    [ -f central-dispatch.yml ] && mv central-dispatch.yml central-dispatch.yml.disabled
    [ -f deploy.yml ] && mv deploy.yml deploy.yml.disabled
    [ -f bigpods-ci.yml ] && mv bigpods-ci.yml bigpods-ci.yml.disabled
    [ -f bigpods-cd.yml ] && mv bigpods-cd.yml bigpods-cd.yml.disabled

    echo -e "${GREEN}✓ Old workflows disabled (renamed to .disabled)${NC}"

    cd ../../..
}

# Uncomment to execute
# disable_old_workflows

# ============================================
# STEP 3: Commit New Workflows
# ============================================
echo -e "${YELLOW}STEP 3: Commit and push new workflows${NC}"
echo ""

commit_new_workflows() {
    echo "Committing new unified CI/CD workflows..."

    # Infra repo
    cd dreamscape-infra
    git add .github/workflows/unified-cicd.yml
    git add docs/CICD_SETUP.md docs/MIGRATION_GUIDE.md
    git add CICD_README.md
    git commit -m "feat(cicd): add unified CI/CD pipeline with GitHub Deployments and Jira integration

- Add unified-cicd.yml workflow with GitHub Deployments API
- Support multi-repository architecture
- Automatic Jira integration via deployment_status
- Environment-based deployments (dev/staging/production)
- Approval workflows for staging and production
- Complete documentation and migration guide
"
    git push
    echo -e "${GREEN}✓ New workflows committed to dreamscape-infra${NC}"
    cd ..

    # Services repo
    cd dreamscape-services
    git add .github/workflows/ci-trigger.yml
    git commit -m "feat(cicd): update to unified CI/CD trigger workflow"
    git push
    echo -e "${GREEN}✓ CI trigger updated in dreamscape-services${NC}"
    cd ..

    # Frontend repo
    cd dreamscape-frontend
    git add .github/workflows/ci-trigger.yml
    git commit -m "feat(cicd): update to unified CI/CD trigger workflow"
    git push
    echo -e "${GREEN}✓ CI trigger updated in dreamscape-frontend${NC}"
    cd ..
}

# Uncomment to execute
# commit_new_workflows

# ============================================
# STEP 4: Create GitHub Environments
# ============================================
echo -e "${YELLOW}STEP 4: Create GitHub Environments${NC}"
echo ""
echo "This must be done manually in GitHub UI:"
echo ""
echo "For EACH repository (services, frontend, tests, docs, infra):"
echo ""
echo "1. Go to: Settings → Environments → New environment"
echo ""
echo "2. Create 'dev' environment:"
echo "   - No protection rules"
echo ""
echo "3. Create 'staging' environment:"
echo "   - ☑ Required reviewers: 1"
echo "   - ☑ Deployment branches: main, develop"
echo ""
echo "4. Create 'production' environment:"
echo "   - ☑ Required reviewers: 2"
echo "   - ☑ Wait timer: 5 minutes"
echo "   - ☑ Deployment branches: main only"
echo ""
echo "Press Enter when done..."
read -r

# ============================================
# STEP 5: Add Repository Secrets
# ============================================
echo -e "${YELLOW}STEP 5: Add Repository Secrets${NC}"
echo ""
echo "Using GitHub CLI to add DISPATCH_TOKEN to all repos..."
echo ""

add_repository_secrets() {
    echo "Enter your GitHub Personal Access Token (PAT):"
    echo "(Needs 'repo' and 'workflow' scopes)"
    read -r -s DISPATCH_TOKEN
    echo ""

    REPOS=(
        "DREAMSCAPE-AI/dreamscape-services"
        "DREAMSCAPE-AI/dreamscape-frontend"
        "DREAMSCAPE-AI/dreamscape-tests"
        "DREAMSCAPE-AI/dreamscape-docs"
        "DREAMSCAPE-AI/dreamscape-infra"
    )

    for repo in "${REPOS[@]}"; do
        echo "Adding DISPATCH_TOKEN to $repo..."
        gh secret set DISPATCH_TOKEN --repo "$repo" --body "$DISPATCH_TOKEN"
        echo -e "${GREEN}✓ DISPATCH_TOKEN added to $repo${NC}"
    done
}

# Uncomment to execute (requires gh CLI)
# add_repository_secrets

echo ""
echo "Manual alternative:"
echo "For each repository, go to:"
echo "Settings → Secrets and variables → Actions → New repository secret"
echo "Name: DISPATCH_TOKEN"
echo "Value: <your-PAT>"
echo ""

# ============================================
# STEP 6: Add Environment Secrets
# ============================================
echo -e "${YELLOW}STEP 6: Add Environment Secrets${NC}"
echo ""
echo "This must be done manually in GitHub UI:"
echo ""
echo "For EACH repository and EACH environment (dev, staging, production):"
echo ""
echo "1. Go to: Settings → Environments → [environment]"
echo "2. Add secret: K3S_HOST"
echo "   Value: K3s server IP address"
echo "3. Add secret: K3S_SSH_KEY"
echo "   Value: SSH private key for K3s server"
echo ""
echo "Example:"
echo "  dev:"
echo "    K3S_HOST = 123.456.789.10"
echo "    K3S_SSH_KEY = -----BEGIN OPENSSH PRIVATE KEY-----..."
echo ""
echo "  staging:"
echo "    K3S_HOST = 123.456.789.20"
echo "    K3S_SSH_KEY = -----BEGIN OPENSSH PRIVATE KEY-----..."
echo ""
echo "  production:"
echo "    K3S_HOST = 123.456.789.30"
echo "    K3S_SSH_KEY = -----BEGIN OPENSSH PRIVATE KEY-----..."
echo ""
echo "Press Enter when done..."
read -r

# ============================================
# STEP 7: Setup Jira Integration
# ============================================
echo -e "${YELLOW}STEP 7: Setup Jira Integration${NC}"
echo ""
echo "1. Go to your Jira workspace"
echo "2. Navigate to: Apps → Find new apps"
echo "3. Search for: 'GitHub for Jira'"
echo "4. Click: Install"
echo "5. After installation:"
echo "   - Apps → Manage apps → GitHub for Jira → Configure"
echo "   - Click: Add organization"
echo "   - Select: DREAMSCAPE-AI"
echo "   - Authorize the connection"
echo "6. Select repositories:"
echo "   ☑ dreamscape-services"
echo "   ☑ dreamscape-frontend"
echo "   ☑ dreamscape-tests"
echo "   ☑ dreamscape-docs"
echo "   ☑ dreamscape-infra"
echo "7. Enable: Deployments feature"
echo ""
echo "Press Enter when done..."
read -r

# ============================================
# STEP 8: Test Deployment
# ============================================
echo -e "${YELLOW}STEP 8: Test Deployment${NC}"
echo ""

test_deployment() {
    echo "Testing deployment to dev environment..."

    cd dreamscape-services
    git checkout -b feature/test-unified-cicd

    echo "// Test unified CI/CD pipeline" >> auth/src/server.ts

    git add auth/src/server.ts
    git commit -m "DR-TEST: Test unified CI/CD pipeline"
    git push origin feature/test-unified-cicd

    echo -e "${GREEN}✓ Test commit pushed${NC}"
    echo ""
    echo "Expected behavior:"
    echo "1. Local CI runs in dreamscape-services"
    echo "2. Triggers unified-cicd.yml in dreamscape-infra"
    echo "3. Creates GitHub Deployment for 'dev' environment"
    echo "4. Runs integration tests"
    echo "5. Builds Docker image for auth service"
    echo "6. Deploys to K3s dev cluster"
    echo "7. Updates deployment status to 'success'"
    echo "8. Jira issue DR-TEST shows deployment to 'dev'"
    echo ""
    echo "Check workflow progress at:"
    echo "https://github.com/DREAMSCAPE-AI/dreamscape-infra/actions"
    echo ""

    cd ..
}

# Uncomment to execute
# test_deployment

# ============================================
# STEP 9: Verify Jira Integration
# ============================================
echo -e "${YELLOW}STEP 9: Verify Jira Integration${NC}"
echo ""
echo "1. Open Jira issue DR-TEST (or the issue key you used)"
echo "2. Scroll to 'Deployments' section"
echo "3. Verify you see:"
echo "   ✓ dev environment"
echo "   ✓ Deployment time"
echo "   ✓ Deployment status (success/failure)"
echo "   ✓ Link to GitHub Actions run"
echo "   ✓ Environment URL"
echo ""
echo "Press Enter when verified..."
read -r

# ============================================
# STEP 10: Delete Old Workflows (After Validation)
# ============================================
echo -e "${YELLOW}STEP 10: Delete Old Workflows (After 1 Week)${NC}"
echo ""

delete_old_workflows() {
    echo -e "${RED}WARNING: This will permanently delete old workflows${NC}"
    echo "Make sure the new pipeline has been running successfully for at least 1 week."
    echo ""
    echo "Delete old workflows? (yes/no)"
    read -r confirm

    if [ "$confirm" = "yes" ]; then
        cd dreamscape-infra/.github/workflows

        rm -f central-cicd.yml.disabled
        rm -f central-dispatch.yml.disabled
        rm -f deploy.yml.disabled
        rm -f bigpods-ci.yml.disabled
        rm -f bigpods-cd.yml.disabled

        cd ../../..

        git add dreamscape-infra/.github/workflows/
        git commit -m "chore(cicd): remove old CI/CD workflows after successful migration"
        git push

        echo -e "${GREEN}✓ Old workflows deleted${NC}"
    else
        echo "Deletion cancelled"
    fi
}

# Uncomment to execute (ONLY after validation period)
# delete_old_workflows

# ============================================
# Summary
# ============================================
echo ""
echo "========================================"
echo "Deployment Summary"
echo "========================================"
echo ""
echo "Files created:"
echo "  ✓ dreamscape-infra/.github/workflows/unified-cicd.yml"
echo "  ✓ dreamscape-services/.github/workflows/ci-trigger.yml"
echo "  ✓ dreamscape-frontend/.github/workflows/ci-trigger.yml"
echo "  ✓ dreamscape-infra/docs/CICD_SETUP.md"
echo "  ✓ dreamscape-infra/docs/MIGRATION_GUIDE.md"
echo "  ✓ dreamscape-infra/CICD_README.md"
echo "  ✓ CICD_REFACTOR_SUMMARY.md"
echo "  ✓ QUICK_DEPLOY_COMMANDS.sh"
echo ""
echo "Next steps:"
echo "  1. Read CICD_README.md for overview"
echo "  2. Follow docs/CICD_SETUP.md for detailed setup"
echo "  3. Use docs/MIGRATION_GUIDE.md for migration"
echo "  4. Test deployment in dev environment"
echo "  5. Validate in staging with approval workflow"
echo "  6. Deploy to production after team training"
echo ""
echo "For support, refer to the documentation or contact DevOps team."
echo ""
echo -e "${GREEN}✓ CI/CD Unified Pipeline ready for deployment!${NC}"
echo ""
