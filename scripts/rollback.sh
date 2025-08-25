#!/bin/bash

# DreamScape Rollback Script
# Usage: ./scripts/rollback.sh <service|all> <environment> [revision]
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
SERVICE=${1:-}
ENVIRONMENT=${2:-}
REVISION=${3:-}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Show usage
show_usage() {
    echo "Usage: $0 <service|all> <environment> [revision]"
    echo ""
    echo "Services: auth, gateway, user, voyage, all"
    echo "Environments: dev, staging, prod"
    echo "Revision: specific revision number (optional)"
    echo ""
    echo "Examples:"
    echo "  $0 gateway prod              # Rollback gateway to previous version"
    echo "  $0 all staging               # Rollback all services to previous version"
    echo "  $0 auth dev 5                # Rollback auth to revision 5"
    exit 1
}

# Validate inputs
if [[ -z "$SERVICE" || -z "$ENVIRONMENT" ]]; then
    show_usage
fi

if [[ ! "$SERVICE" =~ ^(auth|gateway|user|voyage|all)$ ]]; then
    echo -e "${RED}Error: Invalid service '$SERVICE'. Use: auth, gateway, user, voyage, or all${NC}"
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'. Use: dev, staging, or prod${NC}"
    exit 1
fi

echo -e "${BLUE}🔄 Rolling back DreamScape $SERVICE service(s) in $ENVIRONMENT${NC}"

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}📋 Checking prerequisites...${NC}"
    
    command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required${NC}"; exit 1; }
    
    # Check kubectl context
    if ! kubectl get namespace "dreamscape-$ENVIRONMENT" >/dev/null 2>&1; then
        echo -e "${RED}❌ Namespace dreamscape-$ENVIRONMENT not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites satisfied${NC}"
}

# Show rollout history
show_rollout_history() {
    local service_name=$1
    echo -e "${BLUE}📜 Rollout history for $service_name:${NC}"
    kubectl rollout history deployment/"$service_name-service" -n "dreamscape-$ENVIRONMENT"
}

# Confirm rollback
confirm_rollback() {
    local service_name=$1
    local revision_text=""
    
    if [[ -n "$REVISION" ]]; then
        revision_text=" to revision $REVISION"
    else
        revision_text=" to previous revision"
    fi
    
    echo -e "${YELLOW}⚠️ This will rollback $service_name-service$revision_text in $ENVIRONMENT environment.${NC}"
    
    # Skip confirmation in non-interactive environments
    if [[ "${CI:-false}" == "true" ]]; then
        echo -e "${YELLOW}Running in CI environment, skipping confirmation...${NC}"
        return 0
    fi
    
    read -p "Are you sure you want to continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Rollback cancelled${NC}"
        exit 0
    fi
}

# Rollback single service
rollback_service() {
    local service_name=$1
    echo -e "${YELLOW}🔄 Rolling back $service_name service...${NC}"
    
    # Show current status
    echo -e "${BLUE}Current deployment status:${NC}"
    kubectl get deployment "$service_name-service" -n "dreamscape-$ENVIRONMENT" -o wide
    
    # Show rollout history
    show_rollout_history "$service_name"
    
    # Confirm rollback
    confirm_rollback "$service_name"
    
    # Perform rollback
    if [[ -n "$REVISION" ]]; then
        echo -e "${YELLOW}Rolling back to revision $REVISION...${NC}"
        kubectl rollout undo deployment/"$service_name-service" -n "dreamscape-$ENVIRONMENT" --to-revision="$REVISION"
    else
        echo -e "${YELLOW}Rolling back to previous revision...${NC}"
        kubectl rollout undo deployment/"$service_name-service" -n "dreamscape-$ENVIRONMENT"
    fi
    
    # Wait for rollback to complete
    echo -e "${YELLOW}⏳ Waiting for rollback to complete...${NC}"
    kubectl rollout status deployment/"$service_name-service" -n "dreamscape-$ENVIRONMENT" --timeout=300s
    
    # Verify rollback
    verify_rollback "$service_name"
    
    echo -e "${GREEN}✅ $service_name rollback completed successfully${NC}"
}

# Verify rollback
verify_rollback() {
    local service_name=$1
    echo -e "${YELLOW}🔍 Verifying $service_name rollback...${NC}"
    
    # Check pod status
    local ready_pods=$(kubectl get pods -n "dreamscape-$ENVIRONMENT" -l "app=$service_name-service" --field-selector=status.phase=Running --no-headers | wc -l)
    local total_pods=$(kubectl get pods -n "dreamscape-$ENVIRONMENT" -l "app=$service_name-service" --no-headers | wc -l)
    
    echo -e "${BLUE}Pod status: $ready_pods/$total_pods pods running${NC}"
    
    if [[ "$ready_pods" -gt 0 ]]; then
        echo -e "${GREEN}✅ $service_name pods are running${NC}"
        
        # Show pod details
        kubectl get pods -n "dreamscape-$ENVIRONMENT" -l "app=$service_name-service" -o wide
        
        # Quick health check
        sleep 10
        local healthy_pods=$(kubectl get pods -n "dreamscape-$ENVIRONMENT" -l "app=$service_name-service" -o jsonpath='{.items[?(@.status.containerStatuses[0].ready==true)].metadata.name}' | wc -w)
        
        if [[ "$healthy_pods" -gt 0 ]]; then
            echo -e "${GREEN}✅ $service_name health check passed${NC}"
        else
            echo -e "${YELLOW}⚠️ $service_name health check inconclusive${NC}"
        fi
    else
        echo -e "${RED}❌ No $service_name pods are running${NC}"
        kubectl describe pods -n "dreamscape-$ENVIRONMENT" -l "app=$service_name-service"
        return 1
    fi
}

# Emergency rollback (skip confirmations)
emergency_rollback() {
    echo -e "${RED}🚨 EMERGENCY ROLLBACK MODE${NC}"
    echo -e "${YELLOW}Rolling back all services immediately...${NC}"
    
    local services=("gateway" "auth" "user" "voyage")
    
    for service in "${services[@]}"; do
        echo -e "${YELLOW}Emergency rollback: $service${NC}"
        kubectl rollout undo deployment/"$service-service" -n "dreamscape-$ENVIRONMENT" || true
    done
    
    echo -e "${YELLOW}⏳ Waiting for all rollbacks to complete...${NC}"
    for service in "${services[@]}"; do
        kubectl rollout status deployment/"$service-service" -n "dreamscape-$ENVIRONMENT" --timeout=60s || true
    done
    
    echo -e "${GREEN}🚨 Emergency rollback completed${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}🎯 Starting rollback of $SERVICE in $ENVIRONMENT environment${NC}"
    
    # Check for emergency rollback flag
    if [[ "${EMERGENCY:-false}" == "true" ]]; then
        emergency_rollback
        exit 0
    fi
    
    check_prerequisites
    
    if [[ "$SERVICE" == "all" ]]; then
        local services=("gateway" "auth" "user" "voyage")
        
        echo -e "${YELLOW}⚠️ Rolling back ALL services in $ENVIRONMENT environment${NC}"
        
        for service in "${services[@]}"; do
            rollback_service "$service"
            echo ""
        done
    else
        rollback_service "$SERVICE"
    fi
    
    echo -e "${GREEN}🎉 Rollback completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}📋 Rollback Summary:${NC}"
    echo -e "${BLUE}   Service(s): $SERVICE${NC}"
    echo -e "${BLUE}   Environment: $ENVIRONMENT${NC}"
    echo -e "${BLUE}   Namespace: dreamscape-$ENVIRONMENT${NC}"
    
    if [[ -n "$REVISION" ]]; then
        echo -e "${BLUE}   Target Revision: $REVISION${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🔗 Useful commands:${NC}"
    echo -e "${YELLOW}   kubectl get pods -n dreamscape-$ENVIRONMENT${NC}"
    echo -e "${YELLOW}   kubectl rollout history deployment/$SERVICE-service -n dreamscape-$ENVIRONMENT${NC}"
    echo -e "${YELLOW}   kubectl logs -f deployment/$SERVICE-service -n dreamscape-$ENVIRONMENT${NC}"
}

# Handle script interruption
trap 'echo -e "${YELLOW}⚠️ Rollback interrupted by user${NC}"; exit 130' INT TERM

# Run main function
main "$@"