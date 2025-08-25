#!/bin/bash

# DreamScape Deployment Script
# Usage: ./scripts/deploy.sh <service|all> <environment> [options]
# Services: auth, gateway, user, voyage, all
# Environments: dev, staging, prod

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE=${1:-all}
ENVIRONMENT=${2:-dev}
DRY_RUN=${DRY_RUN:-false}
FORCE=${FORCE:-false}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Parse command line arguments
while [[ $# -gt 2 ]]; do
    case $3 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $3${NC}"
            exit 1
            ;;
    esac
done

# Validate inputs
if [[ ! "$SERVICE" =~ ^(auth|gateway|user|voyage|all)$ ]]; then
    echo -e "${RED}Error: Invalid service '$SERVICE'. Use: auth, gateway, user, voyage, or all${NC}"
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'. Use: dev, staging, or prod${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Deploying DreamScape $SERVICE service(s) to $ENVIRONMENT${NC}"

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}📋 Checking deployment prerequisites...${NC}"
    
    command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required${NC}"; exit 1; }
    command -v kustomize >/dev/null 2>&1 || { echo -e "${RED}kustomize is required${NC}"; exit 1; }
    
    # Check kubectl context
    local current_context=$(kubectl config current-context 2>/dev/null || echo "none")
    if [[ "$current_context" != *"$ENVIRONMENT"* ]] && [[ "$FORCE" != "true" ]]; then
        echo -e "${YELLOW}⚠️ Current kubectl context '$current_context' doesn't match environment '$ENVIRONMENT'${NC}"
        echo -e "${YELLOW}Use --force to override or switch to the correct context${NC}"
        exit 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "dreamscape-$ENVIRONMENT" >/dev/null 2>&1; then
        echo -e "${YELLOW}Creating namespace dreamscape-$ENVIRONMENT...${NC}"
        kubectl create namespace "dreamscape-$ENVIRONMENT"
        kubectl label namespace "dreamscape-$ENVIRONMENT" environment="$ENVIRONMENT"
    fi
    
    echo -e "${GREEN}✅ Prerequisites satisfied${NC}"
}

# Pre-deployment checks
pre_deployment_checks() {
    echo -e "${YELLOW}🔍 Running pre-deployment checks...${NC}"
    
    # Check if secrets exist
    if ! kubectl get secret dreamscape-secrets -n "dreamscape-$ENVIRONMENT" >/dev/null 2>&1; then
        echo -e "${RED}❌ Required secrets not found in namespace dreamscape-$ENVIRONMENT${NC}"
        echo -e "${YELLOW}Please create the secrets using the template in secrets/$ENVIRONMENT/secrets.template.yaml${NC}"
        exit 1
    fi
    
    # Check resource quotas (production only)
    if [[ "$ENVIRONMENT" == "prod" ]]; then
        local cpu_usage=$(kubectl top nodes 2>/dev/null | awk 'NR>1 {sum+=$3} END {print sum}' || echo 0)
        local memory_usage=$(kubectl top nodes 2>/dev/null | awk 'NR>1 {sum+=$5} END {print sum}' || echo 0)
        
        echo -e "${BLUE}📊 Current cluster resource usage:${NC}"
        echo -e "${BLUE}   CPU: ${cpu_usage}m, Memory: ${memory_usage}Mi${NC}"
    fi
    
    echo -e "${GREEN}✅ Pre-deployment checks passed${NC}"
}

# Deploy a single service
deploy_service() {
    local service_name=$1
    echo -e "${YELLOW}🔄 Deploying $service_name service to $ENVIRONMENT...${NC}"
    
    local kustomize_dir="$ROOT_DIR/k8s/overlays/$ENVIRONMENT"
    
    if [[ ! -d "$kustomize_dir" ]]; then
        echo -e "${RED}❌ Kustomize directory not found: $kustomize_dir${NC}"
        return 1
    fi
    
    # Build kustomized manifests
    cd "$kustomize_dir"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${BLUE}🔍 Dry run - showing manifests that would be applied:${NC}"
        kustomize build . | grep -A 5 -B 5 "$service_name" || true
        return 0
    fi
    
    # Apply manifests
    if [[ "$service_name" == "all" ]]; then
        echo -e "${YELLOW}Applying all services...${NC}"
        kustomize build . | kubectl apply -f -
    else
        echo -e "${YELLOW}Applying $service_name service...${NC}"
        kustomize build . | kubectl apply -f - -l "app=$service_name-service"
    fi
    
    # Wait for deployment rollout
    wait_for_deployment "$service_name"
    
    echo -e "${GREEN}✅ $service_name deployment completed${NC}"
}

# Wait for deployment to be ready
wait_for_deployment() {
    local service_name=$1
    local timeout=300
    
    if [[ "$service_name" == "all" ]]; then
        local services=("auth" "gateway" "user" "voyage")
    else
        local services=("$service_name")
    fi
    
    for service in "${services[@]}"; do
        echo -e "${YELLOW}⏳ Waiting for $service-service deployment to be ready...${NC}"
        
        if kubectl rollout status deployment/"$service-service" -n "dreamscape-$ENVIRONMENT" --timeout="${timeout}s"; then
            echo -e "${GREEN}✅ $service-service is ready${NC}"
        else
            echo -e "${RED}❌ $service-service deployment failed or timed out${NC}"
            kubectl get pods -n "dreamscape-$ENVIRONMENT" -l "app=$service-service"
            return 1
        fi
    done
}

# Post-deployment verification
post_deployment_verification() {
    echo -e "${YELLOW}🔍 Running post-deployment verification...${NC}"
    
    # Check pod status
    echo -e "${BLUE}📊 Pod status:${NC}"
    kubectl get pods -n "dreamscape-$ENVIRONMENT" -l "part-of=dreamscape" -o wide
    
    # Check service endpoints
    echo -e "${BLUE}🌐 Service endpoints:${NC}"
    kubectl get services -n "dreamscape-$ENVIRONMENT" -l "part-of=dreamscape"
    
    # Check ingress status
    if kubectl get ingress -n "dreamscape-$ENVIRONMENT" >/dev/null 2>&1; then
        echo -e "${BLUE}🌍 Ingress status:${NC}"
        kubectl get ingress -n "dreamscape-$ENVIRONMENT"
    fi
    
    # Health checks
    run_health_checks
    
    echo -e "${GREEN}✅ Post-deployment verification completed${NC}"
}

# Run health checks
run_health_checks() {
    echo -e "${YELLOW}🏥 Running health checks...${NC}"
    
    local gateway_url
    case $ENVIRONMENT in
        prod)
            gateway_url="https://api.dreamscape.com"
            ;;
        staging)
            gateway_url="https://staging-api.dreamscape.com"
            ;;
        dev)
            gateway_url="https://dev-api.dreamscape.com"
            ;;
    esac
    
    # Wait a bit for services to stabilize
    sleep 30
    
    # Check if gateway is accessible (only if external access is configured)
    if command -v curl >/dev/null 2>&1; then
        if curl -f -s "$gateway_url/health" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Gateway health check passed${NC}"
        else
            echo -e "${YELLOW}⚠️ Gateway health check failed (this is expected if external access isn't configured yet)${NC}"
        fi
    fi
    
    # Internal health checks via kubectl
    local services=("auth" "gateway" "user" "voyage")
    if [[ "$SERVICE" != "all" ]]; then
        services=("$SERVICE")
    fi
    
    for service in "${services[@]}"; do
        if kubectl get pods -n "dreamscape-$ENVIRONMENT" -l "app=$service-service" | grep -q Running; then
            echo -e "${GREEN}✅ $service service is running${NC}"
        else
            echo -e "${RED}❌ $service service is not running${NC}"
        fi
    done
}

# Rollback function
rollback_deployment() {
    echo -e "${YELLOW}🔄 Rolling back deployment...${NC}"
    
    local services=()
    if [[ "$SERVICE" == "all" ]]; then
        services=("auth" "gateway" "user" "voyage")
    else
        services=("$SERVICE")
    fi
    
    for service in "${services[@]}"; do
        echo -e "${YELLOW}Rolling back $service-service...${NC}"
        kubectl rollout undo deployment/"$service-service" -n "dreamscape-$ENVIRONMENT"
        kubectl rollout status deployment/"$service-service" -n "dreamscape-$ENVIRONMENT"
    done
    
    echo -e "${GREEN}✅ Rollback completed${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🎯 Starting deployment of $SERVICE to $ENVIRONMENT environment${NC}"
    
    # Set up error handling
    trap 'echo -e "${RED}❌ Deployment failed. Check the logs above for details.${NC}"; exit 1' ERR
    
    check_prerequisites
    pre_deployment_checks
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${BLUE}🔍 DRY RUN MODE - No actual deployment will be performed${NC}"
    fi
    
    deploy_service "$SERVICE"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        post_deployment_verification
        
        echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
        echo ""
        echo -e "${BLUE}📋 Deployment Summary:${NC}"
        echo -e "${BLUE}   Service(s): $SERVICE${NC}"
        echo -e "${BLUE}   Environment: $ENVIRONMENT${NC}"
        echo -e "${BLUE}   Namespace: dreamscape-$ENVIRONMENT${NC}"
        echo ""
        echo -e "${BLUE}🔗 Useful commands:${NC}"
        echo -e "${YELLOW}   kubectl get pods -n dreamscape-$ENVIRONMENT${NC}"
        echo -e "${YELLOW}   kubectl logs -f deployment/gateway-service -n dreamscape-$ENVIRONMENT${NC}"
        echo -e "${YELLOW}   ./scripts/rollback.sh $SERVICE $ENVIRONMENT${NC}"
    fi
}

# Handle script interruption
trap 'echo -e "${YELLOW}⚠️ Deployment interrupted by user${NC}"; exit 130' INT TERM

# Run main function
main "$@"