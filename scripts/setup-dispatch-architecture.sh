#!/bin/bash

# DreamScape Repository Dispatch Architecture Setup Script
# This script helps setup the centralized CI/CD architecture

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ORG="DREAMSCAPE-AI"
REPOS=("dreamscape-services" "dreamscape-frontend" "dreamscape-tests" "dreamscape-docs")
INFRA_REPO="dreamscape-infra"

echo -e "${BLUE}🚀 DreamScape Repository Dispatch Architecture Setup${NC}"
echo "=================================================="

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
    echo "Please install it: https://cli.github.com/"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Not authenticated with GitHub CLI${NC}"
    echo "Please run: gh auth login"
    exit 1
fi

echo -e "${GREEN}✅ GitHub CLI is ready${NC}"

# Function to check if repository exists
check_repo() {
    local repo="$1"
    if gh repo view "$ORG/$repo" &> /dev/null; then
        echo -e "${GREEN}✅ Repository $repo exists${NC}"
        return 0
    else
        echo -e "${RED}❌ Repository $repo not found${NC}"
        return 1
    fi
}

# Function to create workflow file in repository
create_workflow() {
    local repo="$1"
    local workflow_file="$2"
    local workflow_name="$3"
    
    echo -e "${YELLOW}📝 Creating workflow in $repo...${NC}"
    
    # Clone repository temporarily
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    if gh repo clone "$ORG/$repo"; then
        cd "$repo"
        
        # Create .github/workflows directory if it doesn't exist
        mkdir -p .github/workflows
        
        # Copy workflow file
        if [ -f "$workflow_file" ]; then
            cp "$workflow_file" .github/workflows/trigger-central-cicd.yml
            
            # Commit and push
            git add .github/workflows/trigger-central-cicd.yml
            git commit -m "🔄 Add central CI/CD trigger workflow

- Triggers dreamscape-infra pipeline on changes
- Supports automatic environment detection
- Includes local validation steps

Part of Repository Dispatch architecture setup"
            
            git push origin main
            
            echo -e "${GREEN}✅ Workflow created in $repo${NC}"
        else
            echo -e "${RED}❌ Workflow file $workflow_file not found${NC}"
        fi
        
        cd ..
    else
        echo -e "${RED}❌ Failed to clone $repo${NC}"
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
}

# Function to setup secrets in repository
setup_repo_secrets() {
    local repo="$1"
    
    echo -e "${YELLOW}🔐 Setting up secrets for $repo...${NC}"
    
    # Check if DISPATCH_TOKEN is set in environment
    if [ -z "$DISPATCH_TOKEN" ]; then
        echo -e "${YELLOW}⚠️ DISPATCH_TOKEN not set in environment${NC}"
        echo "Please set DISPATCH_TOKEN environment variable with your GitHub token"
        echo "export DISPATCH_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxx"
        return 1
    fi
    
    # Set the secret
    echo "$DISPATCH_TOKEN" | gh secret set DISPATCH_TOKEN --repo "$ORG/$repo"
    echo -e "${GREEN}✅ DISPATCH_TOKEN secret set in $repo${NC}"
}

# Main setup function
main() {
    echo -e "${BLUE}🔍 Checking repositories...${NC}"
    
    # Check if all repositories exist
    for repo in "${REPOS[@]}"; do
        if ! check_repo "$repo"; then
            echo -e "${RED}❌ Setup aborted - missing repository: $repo${NC}"
            exit 1
        fi
    done
    
    # Check infra repository
    if ! check_repo "$INFRA_REPO"; then
        echo -e "${RED}❌ Setup aborted - missing infrastructure repository${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All repositories found${NC}"
    echo ""
    
    # Ask for confirmation
    echo -e "${YELLOW}This script will:${NC}"
    echo "1. 📝 Add trigger workflows to each source repository"
    echo "2. 🔐 Setup DISPATCH_TOKEN secrets in each repository"
    echo "3. 🚀 Enable the Repository Dispatch architecture"
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Setup cancelled${NC}"
        exit 0
    fi
    
    echo -e "${BLUE}🚀 Starting setup...${NC}"
    echo ""
    
    # Get the current directory (should be dreamscape-infra root)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    INFRA_ROOT="$(dirname "$SCRIPT_DIR")"
    
    # Setup workflows for each repository
    declare -A WORKFLOW_MAP=(
        ["dreamscape-services"]="$INFRA_ROOT/trigger-workflows/services-trigger.yml"
        ["dreamscape-frontend"]="$INFRA_ROOT/trigger-workflows/frontend-trigger.yml"
        ["dreamscape-tests"]="$INFRA_ROOT/trigger-workflows/tests-trigger.yml"
        ["dreamscape-docs"]="$INFRA_ROOT/trigger-workflows/docs-trigger.yml"
    )
    
    for repo in "${REPOS[@]}"; do
        echo -e "${BLUE}📦 Setting up $repo...${NC}"
        
        # Create workflow
        if [ -f "${WORKFLOW_MAP[$repo]}" ]; then
            create_workflow "$repo" "${WORKFLOW_MAP[$repo]}" "Central CI/CD Trigger"
        else
            echo -e "${RED}❌ Workflow template not found for $repo${NC}"
            continue
        fi
        
        # Setup secrets
        setup_repo_secrets "$repo"
        
        echo -e "${GREEN}✅ $repo setup completed${NC}"
        echo ""
    done
    
    # Setup secrets in infra repository
    echo -e "${BLUE}🏗️ Setting up infrastructure repository secrets...${NC}"
    
    if [ -z "$DISPATCH_TOKEN" ]; then
        echo -e "${YELLOW}⚠️ Please manually add the following secrets to $INFRA_REPO:${NC}"
        echo "- DISPATCH_TOKEN"
        echo "- VM_HOST_DEV, VM_HOST_STAGING, VM_HOST_PRODUCTION"
        echo "- SSH_PRIVATE_KEY_DEV, SSH_PRIVATE_KEY_STAGING, SSH_PRIVATE_KEY_PRODUCTION"
    else
        echo "$DISPATCH_TOKEN" | gh secret set DISPATCH_TOKEN --repo "$ORG/$INFRA_REPO"
        echo -e "${GREEN}✅ DISPATCH_TOKEN set in $INFRA_REPO${NC}"
        echo -e "${YELLOW}⚠️ Please manually add Oracle Cloud secrets:${NC}"
        echo "- VM_HOST_DEV, VM_HOST_STAGING, VM_HOST_PRODUCTION"  
        echo "- SSH_PRIVATE_KEY_DEV, SSH_PRIVATE_KEY_STAGING, SSH_PRIVATE_KEY_PRODUCTION"
    fi
    
    echo ""
    echo -e "${GREEN}🎉 Repository Dispatch Architecture Setup Complete!${NC}"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "1. 🔐 Add Oracle Cloud secrets to dreamscape-infra repository"
    echo "2. 🧪 Test the architecture by pushing to any source repository"
    echo "3. 👀 Monitor workflows in dreamscape-infra/actions"
    echo ""
    echo -e "${BLUE}📖 Documentation:${NC}"
    echo "- Setup Guide: docs/REPOSITORY-DISPATCH-SETUP.md"
    echo "- Central Pipeline: .github/workflows/central-dispatch.yml"
    echo ""
    echo -e "${GREEN}🚀 The centralized CI/CD is now active!${NC}"
}

# Function to test the setup
test_setup() {
    echo -e "${BLUE}🧪 Testing Repository Dispatch Architecture...${NC}"
    
    # Test by triggering a manual dispatch event
    if [ -z "$DISPATCH_TOKEN" ]; then
        echo -e "${RED}❌ DISPATCH_TOKEN not set${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}📡 Sending test dispatch event...${NC}"
    
    curl -X POST \
        -H "Authorization: token $DISPATCH_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$ORG/$INFRA_REPO/dispatches" \
        -d '{
            "event_type": "services-changed",
            "client_payload": {
                "source_repo": "test",
                "component": "all",
                "environment": "dev",
                "trigger_type": "manual_test"
            }
        }'
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Test dispatch event sent successfully${NC}"
        echo -e "${BLUE}👀 Check the workflow run at:${NC}"
        echo "https://github.com/$ORG/$INFRA_REPO/actions"
    else
        echo -e "${RED}❌ Failed to send test dispatch event${NC}"
        return 1
    fi
}

# Handle command line arguments
case "${1:-setup}" in
    "setup")
        main
        ;;
    "test")
        test_setup
        ;;
    "help"|"-h"|"--help")
        echo "DreamScape Repository Dispatch Setup Script"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  setup (default)  - Setup the Repository Dispatch architecture"
        echo "  test            - Test the setup by sending a test dispatch event"
        echo "  help            - Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  DISPATCH_TOKEN  - GitHub Personal Access Token with repo and workflow permissions"
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac