#!/bin/bash

# DreamScape Environment Setup Script
# Usage: ./scripts/setup-env.sh <environment>
# Environments: dev, staging, prod

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'. Use: dev, staging, or prod${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Setting up DreamScape CI/CD environment: $ENVIRONMENT${NC}"

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}📋 Checking prerequisites...${NC}"
    
    local missing_tools=()
    
    command -v docker >/dev/null 2>&1 || missing_tools+=("docker")
    command -v kubectl >/dev/null 2>&1 || missing_tools+=("kubectl")
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    command -v helm >/dev/null 2>&1 || missing_tools+=("helm")
    command -v kustomize >/dev/null 2>&1 || missing_tools+=("kustomize")
    command -v oci >/dev/null 2>&1 || missing_tools+=("oci-cli")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo -e "${RED}❌ Missing required tools: ${missing_tools[*]}${NC}"
        echo -e "${YELLOW}Please install the missing tools and try again.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites satisfied${NC}"
}

# Setup OCI CLI configuration
setup_oci_config() {
    echo -e "${YELLOW}🔧 Configuring OCI CLI...${NC}"
    
    if [[ ! -f ~/.oci/config ]]; then
        echo -e "${YELLOW}OCI config not found. Please run 'oci setup config' first.${NC}"
        return 1
    fi
    
    # Verify OCI connection
    if oci iam region list >/dev/null 2>&1; then
        echo -e "${GREEN}✅ OCI CLI configured successfully${NC}"
    else
        echo -e "${RED}❌ OCI CLI configuration failed${NC}"
        return 1
    fi
}

# Initialize Terraform
init_terraform() {
    echo -e "${YELLOW}🏗️ Initializing Terraform for $ENVIRONMENT...${NC}"
    
    local terraform_dir="$ROOT_DIR/terraform/environments/$ENVIRONMENT"
    
    if [[ ! -d "$terraform_dir" ]]; then
        echo -e "${RED}❌ Terraform directory not found: $terraform_dir${NC}"
        return 1
    fi
    
    cd "$terraform_dir"
    
    # Initialize Terraform
    terraform init
    
    # Validate configuration
    terraform validate
    
    echo -e "${GREEN}✅ Terraform initialized successfully${NC}"
}

# Setup kubectl context
setup_kubectl() {
    echo -e "${YELLOW}⚙️ Setting up kubectl for $ENVIRONMENT...${NC}"
    
    # Check if kubeconfig exists
    local kubeconfig_file="$HOME/.kube/config-$ENVIRONMENT"
    
    if [[ -f "$kubeconfig_file" ]]; then
        export KUBECONFIG="$kubeconfig_file"
        
        # Test connection
        if kubectl cluster-info >/dev/null 2>&1; then
            echo -e "${GREEN}✅ kubectl configured for $ENVIRONMENT${NC}"
        else
            echo -e "${YELLOW}⚠️ kubectl config found but cluster is not accessible${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ kubectl config not found for $ENVIRONMENT${NC}"
        echo -e "${YELLOW}Please ensure your K3s cluster is deployed and kubeconfig is available${NC}"
    fi
}

# Setup Helm repositories
setup_helm() {
    echo -e "${YELLOW}📦 Setting up Helm repositories...${NC}"
    
    # Add required Helm repositories
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo add cert-manager https://charts.jetstack.io
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo add elastic https://helm.elastic.co
    
    # Update repositories
    helm repo update
    
    echo -e "${GREEN}✅ Helm repositories configured${NC}"
}

# Create environment-specific configuration
create_env_config() {
    echo -e "${YELLOW}📝 Creating environment configuration for $ENVIRONMENT...${NC}"
    
    local config_dir="$ROOT_DIR/config/$ENVIRONMENT"
    mkdir -p "$config_dir"
    
    # Create environment-specific variables file
    cat > "$config_dir/environment.env" <<EOF
# DreamScape Environment Configuration - $ENVIRONMENT
ENVIRONMENT=$ENVIRONMENT
LOG_LEVEL=$([ "$ENVIRONMENT" = "prod" ] && echo "warn" || echo "info")
ENABLE_METRICS=true
ENABLE_TRACING=$([ "$ENVIRONMENT" = "prod" ] && echo "false" || echo "true")

# Service URLs
API_BASE_URL=https://$([ "$ENVIRONMENT" = "prod" ] && echo "api" || echo "$ENVIRONMENT-api").dreamscape.com
WEB_BASE_URL=https://$([ "$ENVIRONMENT" = "prod" ] && echo "app" || echo "$ENVIRONMENT-app").dreamscape.com

# Database Configuration
POSTGRES_DB=dreamscape_$ENVIRONMENT
MONGODB_DB=dreamscape_voyage_$ENVIRONMENT
REDIS_DB=0

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=$([ "$ENVIRONMENT" = "prod" ] && echo "1000" || echo "100")

# Feature Flags
ENABLE_AI_FEATURES=true
ENABLE_360_CONTENT=true
ENABLE_ANALYTICS=true
EOF
    
    echo -e "${GREEN}✅ Environment configuration created${NC}"
}

# Setup monitoring namespace
setup_monitoring() {
    echo -e "${YELLOW}📊 Setting up monitoring namespace...${NC}"
    
    if kubectl get namespace monitoring >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Monitoring namespace already exists${NC}"
    else
        kubectl create namespace monitoring
        kubectl label namespace monitoring name=monitoring
        echo -e "${GREEN}✅ Monitoring namespace created${NC}"
    fi
}

# Create secrets template
create_secrets_template() {
    echo -e "${YELLOW}🔐 Creating secrets template for $ENVIRONMENT...${NC}"
    
    local secrets_dir="$ROOT_DIR/secrets/$ENVIRONMENT"
    mkdir -p "$secrets_dir"
    
    cat > "$secrets_dir/secrets.template.yaml" <<EOF
# DreamScape Secrets Template - $ENVIRONMENT
# Copy this file to secrets.yaml and fill in the actual values
# DO NOT commit secrets.yaml to version control

apiVersion: v1
kind: Secret
metadata:
  name: dreamscape-secrets
  namespace: dreamscape-$ENVIRONMENT
type: Opaque
stringData:
  # Database connections
  postgres-url: "postgresql://user:password@postgres-host:5432/dreamscape_$ENVIRONMENT"
  mongodb-url: "mongodb://user:password@mongodb-host:27017/dreamscape_voyage_$ENVIRONMENT"
  redis-url: "redis://redis-host:6379/0"
  
  # JWT secrets
  jwt-secret: "change-me-to-a-secure-random-string"
  refresh-token-secret: "change-me-to-a-secure-random-string"
  
  # OAuth credentials
  google-client-id: "your-google-oauth-client-id"
  google-client-secret: "your-google-oauth-client-secret"
  
  # API keys
  openai-api-key: "your-openai-api-key"
  
  # Monitoring
  grafana-admin-password: "change-me-admin-password"
  
  # Email service
  smtp-host: "smtp.example.com"
  smtp-user: "no-reply@dreamscape.com"
  smtp-password: "your-smtp-password"
EOF
    
    echo -e "${GREEN}✅ Secrets template created at $secrets_dir/secrets.template.yaml${NC}"
    echo -e "${YELLOW}⚠️ Remember to copy this template to secrets.yaml and fill in actual values${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🎯 Starting DreamScape CI/CD setup for $ENVIRONMENT environment${NC}"
    
    check_prerequisites
    setup_oci_config
    init_terraform
    setup_kubectl
    setup_helm
    create_env_config
    setup_monitoring
    create_secrets_template
    
    echo -e "${GREEN}🎉 Environment setup complete for $ENVIRONMENT!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "${YELLOW}1. Fill in the secrets template: secrets/$ENVIRONMENT/secrets.template.yaml${NC}"
    echo -e "${YELLOW}2. Deploy infrastructure: terraform apply (in terraform/environments/$ENVIRONMENT)${NC}"
    echo -e "${YELLOW}3. Deploy applications: ./scripts/deploy.sh $ENVIRONMENT${NC}"
    echo -e "${YELLOW}4. Set up monitoring: ./scripts/setup-monitoring.sh $ENVIRONMENT${NC}"
}

# Run main function
main "$@"