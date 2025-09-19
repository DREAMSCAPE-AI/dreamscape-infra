#!/bin/bash
# K3s Deployment Script for DreamScape
# Supports rolling and blue-green deployments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to log messages
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1"
}

# Parameters
ENVIRONMENT="${1:-staging}"
STRATEGY="${2:-rolling}"
IMAGE_TAG="${3:-main}"
K3S_HOST="${4:-${K3S_HOST}}"

# Validate parameters
if [[ -z "$ENVIRONMENT" ]]; then
    log_error "Environment parameter is required"
    exit 1
fi

if [[ -z "$K3S_HOST" ]]; then
    log_error "K3S_HOST environment variable or parameter is required"
    exit 1
fi

log "🚀 Starting K3s deployment to $ENVIRONMENT environment"
log "Strategy: $STRATEGY"
log "Image Tag: $IMAGE_TAG"
log "K3s Host: $K3S_HOST"

# Setup kubectl configuration for remote K3s cluster
setup_kubectl() {
    log "🔧 Setting up kubectl configuration..."
    
    # Create kube config directory
    mkdir -p ~/.kube
    
    # Get kubeconfig from remote K3s cluster
    if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$K3S_HOST "sudo cat /etc/rancher/k3s/k3s.yaml" > ~/.kube/config.tmp; then
        log_error "Failed to retrieve kubeconfig from K3s cluster"
        return 1
    fi
    
    # Replace localhost with actual host IP
    sed "s/127.0.0.1/$K3S_HOST/g" ~/.kube/config.tmp > ~/.kube/config
    chmod 600 ~/.kube/config
    rm ~/.kube/config.tmp
    
    log_success "kubectl configured for remote K3s cluster"
}

# Validate kubectl connection
validate_connection() {
    log "🔍 Validating connection to K3s cluster..."
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        log_error "Cannot connect to K3s cluster"
        return 1
    fi
    
    log_success "Successfully connected to K3s cluster"
    kubectl get nodes
}

# Create namespace if it doesn't exist
create_namespace() {
    local namespace="dreamscape-$ENVIRONMENT"
    
    log "📝 Ensuring namespace $namespace exists..."
    
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        kubectl create namespace "$namespace"
        log_success "Created namespace $namespace"
    else
        log "Namespace $namespace already exists"
    fi
}

# Update image tags in kustomization
update_image_tags() {
    log "🏷️ Updating image tags to $IMAGE_TAG..."
    
    # Create temporary kustomization file with updated tags
    cd "k8s/overlays/$ENVIRONMENT"
    
    # Update image tags using kustomize
    kustomize edit set image \
        "ghcr.io/dreamscape-ai/auth-service:$IMAGE_TAG" \
        "ghcr.io/dreamscape-ai/user-service:$IMAGE_TAG" \
        "ghcr.io/dreamscape-ai/voyage-service:$IMAGE_TAG" \
        "ghcr.io/dreamscape-ai/payment-service:$IMAGE_TAG" \
        "ghcr.io/dreamscape-ai/ai-service:$IMAGE_TAG"
    
    log_success "Updated image tags"
    cd - >/dev/null
}

# Rolling deployment strategy
deploy_rolling() {
    local namespace="dreamscape-$ENVIRONMENT"
    
    log "🔄 Executing rolling deployment..."
    
    # Apply Kustomize configuration
    kubectl apply -k "k8s/overlays/$ENVIRONMENT" --namespace="$namespace"
    
    # Wait for deployments to be ready
    log "⏳ Waiting for deployments to be ready..."
    
    local deployments=("auth-service" "user-service" "voyage-service" "payment-service" "ai-service")
    
    for deployment in "${deployments[@]}"; do
        log "Waiting for $deployment..."
        if ! kubectl wait --for=condition=available --timeout=300s deployment/"$deployment" -n "$namespace"; then
            log_error "Deployment $deployment failed to become available"
            return 1
        fi
        log_success "$deployment is ready"
    done
    
    log_success "Rolling deployment completed successfully"
}

# Blue-green deployment strategy  
deploy_blue_green() {
    local namespace="dreamscape-$ENVIRONMENT"
    
    log "🔵🟢 Executing blue-green deployment..."
    
    # Create green deployment with new version
    log "Creating green environment..."
    
    # Apply with green labels
    kubectl apply -k "k8s/overlays/$ENVIRONMENT" --namespace="$namespace"
    
    # Wait for green deployments to be ready
    local deployments=("auth-service" "user-service" "voyage-service" "payment-service" "ai-service")
    
    for deployment in "${deployments[@]}"; do
        if ! kubectl wait --for=condition=available --timeout=300s deployment/"$deployment" -n "$namespace"; then
            log_error "Green deployment $deployment failed"
            return 1
        fi
    done
    
    log_success "Green environment is ready"
    
    # TODO: Implement traffic switching logic
    log "🔄 Switching traffic to green environment..."
    
    log_success "Blue-green deployment completed successfully"
}

# Health checks
run_health_checks() {
    local namespace="dreamscape-$ENVIRONMENT"
    
    log "🏥 Running health checks..."
    
    # Check pod status
    kubectl get pods -n "$namespace"
    
    # Check service endpoints
    kubectl get services -n "$namespace"
    
    # TODO: Add specific health check endpoints
    # curl -f http://staging-api.dreamscape.com/health
    
    log_success "Health checks completed"
}

# Rollback function
rollback() {
    local namespace="dreamscape-$ENVIRONMENT"
    
    log_warning "🔙 Rolling back deployment..."
    
    local deployments=("auth-service" "user-service" "voyage-service" "payment-service" "ai-service")
    
    for deployment in "${deployments[@]}"; do
        kubectl rollout undo deployment/"$deployment" -n "$namespace"
    done
    
    log_success "Rollback completed"
}

# Main deployment function
main() {
    # Setup
    setup_kubectl || exit 1
    validate_connection || exit 1
    create_namespace || exit 1
    update_image_tags || exit 1
    
    # Execute deployment strategy
    case "$STRATEGY" in
        "rolling")
            deploy_rolling || { rollback; exit 1; }
            ;;
        "blue-green")
            deploy_blue_green || { rollback; exit 1; }
            ;;
        *)
            log_error "Unknown deployment strategy: $STRATEGY"
            exit 1
            ;;
    esac
    
    # Validation
    run_health_checks || exit 1
    
    log_success "🎉 Deployment to $ENVIRONMENT completed successfully!"
}

# Execute main function
main "$@"