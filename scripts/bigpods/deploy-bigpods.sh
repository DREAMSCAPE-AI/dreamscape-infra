#!/bin/bash
# DreamScape Big Pods - Production Deployment Script
# Déploiement orchestré sur environnements cibles avec rolling updates

# Import common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Script-specific variables
TARGET_ENVIRONMENT=""
DEPLOYMENT_VERSION=""
ROLLING_UPDATE=false
ROLLBACK_ON_FAILURE=true
SKIP_VALIDATION=false
NOTIFICATION_ENABLED=false
BLUE_GREEN_DEPLOYMENT=false
CANARY_DEPLOYMENT=false
CANARY_PERCENTAGE=10

# Deployment configuration
DEPLOYMENT_TIMEOUT=1800  # 30 minutes
HEALTH_CHECK_RETRIES=20
HEALTH_CHECK_INTERVAL=15
PARALLEL_DEPLOYMENT=false

# Resolved namespace for deployments (may differ from configured if resources exist elsewhere)
RESOLVED_NAMESPACE=""

# Build image name helper to stay aligned with build script env vars
get_pod_image_name() {
    local pod_name="$1"
    local version_tag="${2:-${DEPLOYMENT_VERSION:-latest}}"

    local registry_prefix=""
    local namespace="${REGISTRY_NAMESPACE:-dreamscape}"

    if [[ -n "${REGISTRY_URL:-}" ]]; then
        registry_prefix="${REGISTRY_URL}/"
    fi

    echo "${registry_prefix}${namespace}/${pod_name}-pod:${version_tag}"
}

# Notification settings
SLACK_WEBHOOK=""
TEAMS_WEBHOOK=""

# Usage function
show_usage() {
    echo -e "${BLUE}${ROCKET_ICON} DreamScape Big Pods - Deployment Script${NC}"
    echo ""
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [OPTIONS] --env ENVIRONMENT"
    echo ""
    echo -e "${WHITE}OPTIONS:${NC}"
    echo "  -e, --env ENV          Target environment (staging, production)"
    echo "  -v, --version TAG      Deploy specific version tag"
    echo "  -p, --pod POD          Deploy specific pod only"
    echo "  -r, --rolling          Enable rolling update"
    echo "  --blue-green           Use blue-green deployment"
    echo "  --canary               Use canary deployment"
    echo "  --canary-percent N     Canary deployment percentage (default: 10)"
    echo "  --parallel             Deploy pods in parallel"
    echo "  --no-rollback          Disable automatic rollback on failure"
    echo "  --skip-validation      Skip pre-deployment validation"
    echo "  --timeout SECONDS      Deployment timeout (default: 1800)"
    echo "  --notify               Enable deployment notifications"
    echo "  --slack-webhook URL    Slack webhook URL for notifications"
    echo "  --teams-webhook URL    Teams webhook URL for notifications"
    echo "  -f, --force            Force deployment without confirmation"
    echo "  --verbose              Verbose output"
    echo "  --debug                Debug output"
    echo "  -h, --help             Show this help"
    echo ""
    echo -e "${WHITE}ENVIRONMENTS:${NC}"
    echo "  staging                Staging environment"
    echo "  production             Production environment"
    echo ""
    echo -e "${WHITE}DEPLOYMENT STRATEGIES:${NC}"
    echo "  rolling                Rolling update (default)"
    echo "  blue-green             Blue-green deployment"
    echo "  canary                 Canary deployment"
    echo ""
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo "  $0 --env staging                    # Deploy to staging"
    echo "  $0 --env production -v v2.1.0       # Deploy specific version to production"
    echo "  $0 --env production --rolling       # Rolling deployment to production"
    echo "  $0 --env production --blue-green    # Blue-green deployment"
    echo "  $0 --env staging --canary --canary-percent 20  # Canary deployment"
}

# Parse command line arguments
parse_args() {
    local pods_to_deploy=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--env)
                if validate_environment "$2"; then
                    TARGET_ENVIRONMENT="$2"
                fi
                shift 2
                ;;
            -v|--version)
                DEPLOYMENT_VERSION="$2"
                shift 2
                ;;
            -p|--pod)
                if validate_pod_name "$2"; then
                    pods_to_deploy+=("$2")
                fi
                shift 2
                ;;
            -r|--rolling)
                ROLLING_UPDATE=true
                shift
                ;;
            --blue-green)
                BLUE_GREEN_DEPLOYMENT=true
                shift
                ;;
            --canary)
                CANARY_DEPLOYMENT=true
                shift
                ;;
            --canary-percent)
                CANARY_PERCENTAGE="$2"
                shift 2
                ;;
            --parallel)
                PARALLEL_DEPLOYMENT=true
                shift
                ;;
            --no-rollback)
                ROLLBACK_ON_FAILURE=false
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --timeout)
                DEPLOYMENT_TIMEOUT="$2"
                shift 2
                ;;
            --notify)
                NOTIFICATION_ENABLED=true
                shift
                ;;
            --slack-webhook)
                SLACK_WEBHOOK="$2"
                NOTIFICATION_ENABLED=true
                shift 2
                ;;
            --teams-webhook)
                TEAMS_WEBHOOK="$2"
                NOTIFICATION_ENABLED=true
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --debug)
                DEBUG=true
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            core|business|experience)
                if validate_pod_name "$1"; then
                    pods_to_deploy+=("$1")
                fi
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "$TARGET_ENVIRONMENT" ]]; then
        log_error "Target environment is required"
        show_usage
        exit 1
    fi

    # Set pods to deploy
    if [[ ${#pods_to_deploy[@]} -gt 0 ]]; then
        PODS_TO_DEPLOY=("${pods_to_deploy[@]}")
    else
        PODS_TO_DEPLOY=("core" "business" "experience")
    fi

    log_debug "Target environment: $TARGET_ENVIRONMENT"
    log_debug "Deployment version: $DEPLOYMENT_VERSION"
    log_debug "Pods to deploy: ${PODS_TO_DEPLOY[*]}"
}

# Send notification
send_notification() {
    local message="$1"
    local status="${2:-info}"

    if [[ "$NOTIFICATION_ENABLED" != "true" ]]; then
        return 0
    fi

    local color=""
    local icon=""

    case "$status" in
        "success")
            color="#36a64f"
            icon=":white_check_mark:"
            ;;
        "error")
            color="#ff0000"
            icon=":x:"
            ;;
        "warning")
            color="#ffaa00"
            icon=":warning:"
            ;;
        *)
            color="#0099cc"
            icon=":information_source:"
            ;;
    esac

    # Send Slack notification
    if [[ -n "$SLACK_WEBHOOK" ]]; then
        local slack_payload=$(cat <<EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "DreamScape Big Pods Deployment",
            "text": "$icon $message",
            "fields": [
                {
                    "title": "Environment",
                    "value": "$TARGET_ENVIRONMENT",
                    "short": true
                },
                {
                    "title": "Version",
                    "value": "${DEPLOYMENT_VERSION:-latest}",
                    "short": true
                },
                {
                    "title": "Timestamp",
                    "value": "$(date -u +"%Y-%m-%d %H:%M:%S UTC")",
                    "short": false
                }
            ]
        }
    ]
}
EOF
        )

        curl -X POST -H 'Content-type: application/json' \
             --data "$slack_payload" \
             "$SLACK_WEBHOOK" >/dev/null 2>&1 || log_debug "Slack notification failed"
    fi

    # Send Teams notification
    if [[ -n "$TEAMS_WEBHOOK" ]]; then
        local teams_payload=$(cat <<EOF
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "${color#\#}",
    "summary": "DreamScape Big Pods Deployment",
    "sections": [{
        "activityTitle": "DreamScape Big Pods Deployment",
        "activitySubtitle": "$message",
        "facts": [{
            "name": "Environment",
            "value": "$TARGET_ENVIRONMENT"
        }, {
            "name": "Version",
            "value": "${DEPLOYMENT_VERSION:-latest}"
        }, {
            "name": "Timestamp",
            "value": "$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        }],
        "markdown": true
    }]
}
EOF
        )

        curl -X POST -H 'Content-type: application/json' \
             --data "$teams_payload" \
             "$TEAMS_WEBHOOK" >/dev/null 2>&1 || log_debug "Teams notification failed"
    fi
}

# Validate deployment prerequisites
validate_deployment() {
    if [[ "$SKIP_VALIDATION" == "true" ]]; then
        log_info "Skipping deployment validation"
        return 0
    fi

    log_info "Validating deployment prerequisites..."

    # Check Docker and Kubernetes access
    check_docker

    # Check kubectl for Kubernetes deployments
    if [[ "$TARGET_ENVIRONMENT" != "local" ]]; then
        if ! command -v kubectl >/dev/null 2>&1; then
            log_error "kubectl not found. Required for $TARGET_ENVIRONMENT deployments"
            return 1
        fi

        # Test cluster connectivity
        if ! kubectl cluster-info >/dev/null 2>&1; then
            log_error "Cannot connect to Kubernetes cluster"
            return 1
        fi

        log_success "Kubernetes cluster accessible"
    fi

    # Validate version tag if specified
    if [[ -n "$DEPLOYMENT_VERSION" ]]; then
        for pod_name in "${PODS_TO_DEPLOY[@]}"; do
            local image_name
            image_name="$(get_pod_image_name "$pod_name" "$DEPLOYMENT_VERSION")"

            if ! docker manifest inspect "$image_name" >/dev/null 2>&1; then
                log_warning "docker manifest inspect failed for $image_name. Attempting fallback validation with docker pull..."
                if ! docker pull "$image_name" >/dev/null 2>&1; then
                    log_error "Image not found or inaccessible: $image_name. Both docker manifest inspect and docker pull failed. Please check registry type, authentication, and image existence."
                    return 1
                fi
            fi
        done

        log_success "All deployment images validated"
    fi

    # Check secrets and configuration
    validate_secrets

    # Check resource availability
    check_resource_availability

    log_success "Deployment validation completed"
}

# Validate secrets and configuration
validate_secrets() {
    log_verbose "Validating secrets and configuration..."

    # Check environment-specific configuration
    local env_config_file="$PROJECT_ROOT/config/${TARGET_ENVIRONMENT}.env"

    if [[ ! -f "$env_config_file" ]]; then
        log_warning "Environment configuration not found: $env_config_file"
    fi

    # Validate critical secrets for production
    if [[ "$TARGET_ENVIRONMENT" == "production" ]]; then
        local required_secrets=(
            "JWT_SECRET"
            "DATABASE_URL"
            "REDIS_URL"
            "STRIPE_SECRET_KEY"
            "OPENAI_API_KEY"
        )

        for secret in "${required_secrets[@]}"; do
            if [[ -z "${!secret:-}" ]]; then
                log_warning "Production secret not set: $secret"
            fi
        done
    fi
}

# Check resource availability
check_resource_availability() {
    log_verbose "Checking resource availability..."

    if [[ "$TARGET_ENVIRONMENT" != "local" ]]; then
        # Check Kubernetes node resources
        local node_info
        node_info=$(kubectl top nodes 2>/dev/null || echo "Unable to get node metrics")

        log_debug "Node resource info: $node_info"

        # Check namespace
        local namespace
        namespace=$(get_config_value "environments.${TARGET_ENVIRONMENT}.namespace")

        if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
            log_info "Creating namespace: $namespace"
            kubectl create namespace "$namespace" || log_error "Failed to create namespace"
        fi
    fi
}

# Deploy using rolling update strategy
deploy_rolling_update() {
    local pod_name="$1"

    log_info "Deploying $pod_name pod using rolling update strategy..."

    case "$TARGET_ENVIRONMENT" in
        "local")
            deploy_local_rolling "$pod_name"
            ;;
        "staging"|"production")
            deploy_k8s_rolling "$pod_name"
            ;;
    esac
}

# Deploy to local environment with rolling update
deploy_local_rolling() {
    local pod_name="$1"

    log_info "Rolling update for local $pod_name pod..."

    local compose_cmd
    compose_cmd=$(check_docker_compose)

    local compose_file
    compose_file=$(get_pod_docker_compose "$pod_name")

    cd docker

    # Update images
    if [[ -n "$DEPLOYMENT_VERSION" ]]; then
        local image_name
        image_name="$(get_pod_image_name "$pod_name" "$DEPLOYMENT_VERSION")"
        log_info "Pulling image: $image_name"
        docker pull "$image_name"
    fi

    # Rolling restart
    log_info "Performing rolling restart..."
    $compose_cmd -f "$compose_file" up -d --no-deps "${pod_name}-pod"

    # Health checks disabled
    # wait_for_pod_health "$pod_name"

    cd ..
}

# Deploy to Kubernetes with rolling update
deploy_k8s_rolling() {
    local pod_name="$1"

    log_info "Rolling update for Kubernetes $pod_name pod..."

    local deployment_name
    deployment_name=$(resolve_deployment_name "$pod_name") || return 1
    local namespace="${RESOLVED_NAMESPACE:-$(get_config_value "environments.${TARGET_ENVIRONMENT}.namespace")}"

    # Update deployment image
    if [[ -n "$DEPLOYMENT_VERSION" ]]; then
        local image_name
        image_name="$(get_pod_image_name "$pod_name" "$DEPLOYMENT_VERSION")"

        log_info "Updating deployment image: $image_name"
        kubectl set image deployment/"$deployment_name" \
                "*=$image_name" \
                -n "$namespace"
    else
        # Restart deployment
        kubectl rollout restart deployment/"$deployment_name" -n "$namespace"
    fi

    # Wait for rollout to complete
    log_info "Waiting for rollout to complete..."
    if ! kubectl rollout status deployment/"$deployment_name" \
         -n "$namespace" \
         --timeout="${DEPLOYMENT_TIMEOUT}s"; then
        log_error "Rollout failed for $pod_name pod"
        return 1
    fi

    # Health checks disabled
    # wait_for_pod_health "$pod_name"

    log_success "$pod_name pod rolling update completed"
}

# Deploy using blue-green strategy
deploy_blue_green() {
    local pod_name="$1"

    log_info "Deploying $pod_name pod using blue-green strategy..."

    case "$TARGET_ENVIRONMENT" in
        "staging"|"production")
            deploy_k8s_blue_green "$pod_name"
            ;;
        *)
            log_error "Blue-green deployment not supported for $TARGET_ENVIRONMENT"
            return 1
            ;;
    esac
}

# Deploy to Kubernetes with blue-green strategy
deploy_k8s_blue_green() {
    local pod_name="$1"

    log_info "Blue-green deployment for Kubernetes $pod_name pod..."

    local namespace="${RESOLVED_NAMESPACE:-$(get_config_value "environments.${TARGET_ENVIRONMENT}.namespace")}"

    local blue_deployment="dreamscape-${pod_name}-pod-blue"
    local green_deployment="dreamscape-${pod_name}-pod-green"
    local service_name="dreamscape-${pod_name}-pod-service"

    # Determine current active deployment
    local current_deployment
    current_deployment=$(kubectl get service "$service_name" -n "$namespace" \
                        -o jsonpath='{.spec.selector.version}' 2>/dev/null || echo "blue")

    local new_deployment
    if [[ "$current_deployment" == "blue" ]]; then
        new_deployment="green"
    else
        new_deployment="blue"
    fi

    log_info "Current active: $current_deployment, deploying to: $new_deployment"

    # Deploy to inactive environment
    local target_deployment="dreamscape-${pod_name}-pod-${new_deployment}"
    local image_name
    image_name="$(get_pod_image_name "$pod_name")"

    # Update deployment
    kubectl set image deployment/"$target_deployment" \
            "*=$image_name" \
            -n "$namespace"

    # Wait for new deployment to be ready
    if ! kubectl rollout status deployment/"$target_deployment" \
         -n "$namespace" \
         --timeout="${DEPLOYMENT_TIMEOUT}s"; then
        log_error "Blue-green deployment failed for $pod_name pod"
        return 1
    fi

    # Test new deployment health
    if ! test_deployment_health "$pod_name" "$new_deployment"; then
        log_error "Health check failed for new deployment"
        return 1
    fi

    # Switch traffic to new deployment
    log_info "Switching traffic to $new_deployment deployment..."
    kubectl patch service "$service_name" -n "$namespace" \
            -p "{\"spec\":{\"selector\":{\"version\":\"$new_deployment\"}}}"

    # Verify traffic switch
    sleep 10
    if ! test_deployment_health "$pod_name" "$new_deployment"; then
        log_error "Health check failed after traffic switch"
        # Rollback traffic
        kubectl patch service "$service_name" -n "$namespace" \
                -p "{\"spec\":{\"selector\":{\"version\":\"$current_deployment\"}}}"
        return 1
    fi

    log_success "$pod_name pod blue-green deployment completed"
}

# Deploy using canary strategy
deploy_canary() {
    local pod_name="$1"

    log_info "Deploying $pod_name pod using canary strategy (${CANARY_PERCENTAGE}%)..."

    case "$TARGET_ENVIRONMENT" in
        "staging"|"production")
            deploy_k8s_canary "$pod_name"
            ;;
        *)
            log_error "Canary deployment not supported for $TARGET_ENVIRONMENT"
            return 1
            ;;
    esac
}

# Deploy to Kubernetes with canary strategy
deploy_k8s_canary() {
    local pod_name="$1"

    log_info "Canary deployment for Kubernetes $pod_name pod..."

    local namespace="${RESOLVED_NAMESPACE:-$(get_config_value "environments.${TARGET_ENVIRONMENT}.namespace")}"

    local stable_deployment="dreamscape-${pod_name}-pod-stable"
    local canary_deployment="dreamscape-${pod_name}-pod-canary"

    # Deploy canary version
    local image_name
    image_name="$(get_pod_image_name "$pod_name")"

    kubectl set image deployment/"$canary_deployment" \
            "*=$image_name" \
            -n "$namespace"

    # Scale canary deployment
    local canary_replicas
    canary_replicas=$(( ($(kubectl get deployment "$stable_deployment" -n "$namespace" -o jsonpath='{.spec.replicas}') * CANARY_PERCENTAGE) / 100 ))
    canary_replicas=$((canary_replicas > 0 ? canary_replicas : 1))

    kubectl scale deployment/"$canary_deployment" --replicas="$canary_replicas" -n "$namespace"

    # Wait for canary deployment
    if ! kubectl rollout status deployment/"$canary_deployment" \
         -n "$namespace" \
         --timeout="${DEPLOYMENT_TIMEOUT}s"; then
        log_error "Canary deployment failed for $pod_name pod"
        return 1
    fi

    # Monitor canary health
    log_info "Monitoring canary deployment for 5 minutes..."
    local monitor_duration=300  # 5 minutes
    local check_interval=30

    for ((i=0; i<monitor_duration; i+=check_interval)); do
        if ! test_deployment_health "$pod_name" "canary"; then
            log_error "Canary health check failed"
            # Rollback canary
            kubectl scale deployment/"$canary_deployment" --replicas=0 -n "$namespace"
            return 1
        fi

        sleep "$check_interval"
        echo -ne "\rMonitoring canary: $((i + check_interval))/${monitor_duration}s"
    done

    echo ""

    # Promote canary to stable
    log_info "Promoting canary to stable..."
    kubectl set image deployment/"$stable_deployment" \
            "*=$image_name" \
            -n "$namespace"

    # Wait for stable deployment update
    if ! kubectl rollout status deployment/"$stable_deployment" \
         -n "$namespace" \
         --timeout="${DEPLOYMENT_TIMEOUT}s"; then
        log_error "Stable deployment update failed"
        return 1
    fi

    # Scale down canary
    kubectl scale deployment/"$canary_deployment" --replicas=0 -n "$namespace"

    log_success "$pod_name pod canary deployment completed"
}

# Wait for pod health
wait_for_pod_health() {
    local pod_name="$1"

    log_info "Waiting for $pod_name pod to be healthy..."

    local services
    services=$(get_pod_services_detailed "$pod_name")

    for service_info in $services; do
        local service_name="${service_info%:*}"
        local service_port="${service_info#*:}"

        local health_url="http://localhost:$service_port/health"

        if [[ "$TARGET_ENVIRONMENT" != "local" ]]; then
            # For remote environments, use service discovery
            local namespace
            namespace=$(get_config_value "environments.${TARGET_ENVIRONMENT}.namespace")
            health_url="http://dreamscape-${service_name}-service.${namespace}.svc.cluster.local/health"
        fi

        wait_for_service "$service_name" "$health_url" 120
    done
}

# # Test deployment health
# test_deployment_health() {
#     local pod_name="$1"
#     local deployment_variant="${2:-}"

#     log_verbose "Testing deployment health for $pod_name pod..."

#     local services
#     services=$(get_pod_services_detailed "$pod_name")

#     for service_info in $services; do
#         local service_name="${service_info%:*}"
#         local service_port="${service_info#*:}"

#         local health_url="http://localhost:$service_port/health"

#         if [[ "$TARGET_ENVIRONMENT" != "local" ]]; then
#             local namespace
#             namespace=$(get_config_value "environments.${TARGET_ENVIRONMENT}.namespace")

#             if [[ -n "$deployment_variant" ]]; then
#                 health_url="http://dreamscape-${service_name}-service-${deployment_variant}.${namespace}.svc.cluster.local/health"
#             else
#                 health_url="http://dreamscape-${service_name}-service.${namespace}.svc.cluster.local/health"
#             fi
#         fi

#         if ! check_service_health "$health_url" 10 3; then
#             return 1
#         fi
#     done

#     return 0
# }

# Get pod services detailed
get_pod_services_detailed() {
    local pod_name="$1"

    case "$pod_name" in
        "core")
            echo "auth:3001 user:3002"
            ;;
        "business")
            echo "voyage:3003 payment:3004 ai:3005"
            ;;
        "experience")
            echo "panorama:3006 web-client:5173 gateway:3000"
            ;;
    esac
}

# Resolve the actual deployment name in the target namespace for a given pod.
# This tries a small set of known naming patterns to align with already-created resources.
resolve_deployment_name() {
    local pod_name="$1"
    local namespace
    namespace=$(get_config_value "environments.${TARGET_ENVIRONMENT}.namespace")

    RESOLVED_NAMESPACE="$namespace"

    # If the namespace does not exist, note it but continue to search globally.
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_warning "Namespace '$namespace' not found. Searching deployments across namespaces."
        RESOLVED_NAMESPACE="default"
    fi

    local candidates=()
    case "$pod_name" in
        "core")
            candidates=(
                "dreamscape-core-pod"
                "core-pod"
                "core"
                "auth-service"
                "user-service"
                "auth-service"
            )
            ;;
        "business")
            candidates=(
                "dreamscape-business-pod"
                "business-pod"
                "business"
                "voyage-service"
                "payment-service"
                "ai-service"
                "voyage-service"
            )
            ;;
        "experience")
            candidates=(
                "dreamscape-experience-pod"
                "experience-pod"
                "experience"
                "gateway-service"
                "panorama-service"
                "web-client-service"
                "gateway-service"
            )
            ;;
    esac

    for candidate in "${candidates[@]}"; do
        # First try configured (or fallback) namespace
        if kubectl get deployment "$candidate" -n "$RESOLVED_NAMESPACE" >/dev/null 2>&1; then
            echo "$candidate"
            return 0
        fi

        # Then search all namespaces for this deployment name
        local found_ns
        found_ns=$(kubectl get deployment "$candidate" -A -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null || echo "")
        if [[ -n "$found_ns" ]]; then
            RESOLVED_NAMESPACE="$found_ns"
            echo "$candidate"
            return 0
        fi
    done

    log_error "Deployment not found for pod '$pod_name'. Tried: ${candidates[*]} in namespace '$namespace' and cluster-wide."
    return 1
}

# Rollback deployment
rollback_deployment() {
    local pod_name="$1"

    log_warning "Rolling back $pod_name pod deployment..."

    send_notification "Rolling back deployment for $pod_name pod" "warning"

    case "$TARGET_ENVIRONMENT" in
        "local")
            rollback_local "$pod_name"
            ;;
        "staging"|"production")
            rollback_k8s "$pod_name"
            ;;
    esac
}

# Rollback local deployment
rollback_local() {
    local pod_name="$1"

    # Get previous image
    local previous_image
    local image_repo
    image_repo="$(get_pod_image_name "$pod_name" "latest")"
    image_repo="${image_repo%:*}"

    previous_image=$(docker images "$image_repo" --format "table {{.Tag}}" | sed -n 2p)

    if [[ -n "$previous_image" ]] && [[ "$previous_image" != "TAG" ]]; then
        log_info "Rolling back to previous image: $previous_image"

        local compose_cmd
        compose_cmd=$(check_docker_compose)
        local compose_file
        compose_file=$(get_pod_docker_compose "$pod_name")

        cd docker

        # Set previous image
        DEPLOYMENT_VERSION="$previous_image"
        export DEPLOYMENT_VERSION

        $compose_cmd -f "$compose_file" up -d --no-deps "${pod_name}-pod"

        cd ..
    else
        log_error "No previous image found for rollback"
    fi
}

# Rollback Kubernetes deployment
rollback_k8s() {
    local pod_name="$1"

    local deployment_name
    deployment_name=$(resolve_deployment_name "$pod_name") || return 1
    local namespace="${RESOLVED_NAMESPACE:-$(get_config_value "environments.${TARGET_ENVIRONMENT}.namespace")}"

    log_info "Rolling back Kubernetes deployment..."
    kubectl rollout undo deployment/"$deployment_name" -n "$namespace"

    # Wait for rollback to complete
    if ! kubectl rollout status deployment/"$deployment_name" \
         -n "$namespace" \
         --timeout="${DEPLOYMENT_TIMEOUT}s"; then
        log_error "Rollback failed for $pod_name pod"
        return 1
    fi

    log_success "$pod_name pod rollback completed"
}

# # Post-deployment verification
# post_deployment_verification() {
#     log_info "Running post-deployment verification..."

#     # Health checks
#     for pod_name in "${PODS_TO_DEPLOY[@]}"; do
#         if ! test_deployment_health "$pod_name"; then
#             log_error "Post-deployment health check failed for $pod_name pod"

#             if [[ "$ROLLBACK_ON_FAILURE" == "true" ]]; then
#                 rollback_deployment "$pod_name"
#             fi

#             return 1
#         fi
#     done

#     # Integration tests
#     run_integration_tests

#     log_success "Post-deployment verification completed"
# }

# Run integration tests
run_integration_tests() {
    log_info "Running integration tests..."

    local test_results=true

    # Basic API tests
    for pod_name in "${PODS_TO_DEPLOY[@]}"; do
        local services
        services=$(get_pod_services_detailed "$pod_name")

        for service_info in $services; do
            local service_name="${service_info%:*}"
            local service_port="${service_info#*:}"

            local api_url="http://localhost:$service_port/api/v1"

            if [[ "$TARGET_ENVIRONMENT" != "local" ]]; then
                local namespace
                namespace=$(get_config_value "environments.${TARGET_ENVIRONMENT}.namespace")
                api_url="http://dreamscape-${service_name}-service.${namespace}.svc.cluster.local/api/v1"
            fi

            # Test service-specific endpoints
            case "$service_name" in
                "auth")
                    if ! curl -f -s --max-time 10 "${api_url}/auth/status" >/dev/null; then
                        log_error "Auth service test failed"
                        test_results=false
                    fi
                    ;;
                "user")
                    if ! curl -f -s --max-time 10 "${api_url}/users/status" >/dev/null; then
                        log_error "User service test failed"
                        test_results=false
                    fi
                    ;;
            esac
        done
    done

    if [[ "$test_results" == "true" ]]; then
        log_success "Integration tests passed"
    else
        log_error "Integration tests failed"
        return 1
    fi
}

# Main deployment orchestration
deploy_pods() {
    local deployment_start_time
    deployment_start_time=$(date +%s)

    send_notification "Starting deployment to $TARGET_ENVIRONMENT" "info"

    local failed_deployments=0

    if [[ "$PARALLEL_DEPLOYMENT" == "true" ]] && [[ ${#PODS_TO_DEPLOY[@]} -gt 1 ]]; then
        log_info "Deploying pods in parallel..."
        deploy_pods_parallel
        failed_deployments=$?
    else
        log_info "Deploying pods sequentially..."

        for pod_name in "${PODS_TO_DEPLOY[@]}"; do
            if ! deploy_single_pod "$pod_name"; then
                failed_deployments=$((failed_deployments + 1))

                if [[ "$ROLLBACK_ON_FAILURE" == "true" ]]; then
                    rollback_deployment "$pod_name"
                fi

                if ! confirm_action "Continue with remaining deployments?"; then
                    break
                fi
            fi
        done
    fi

    local deployment_end_time
    deployment_end_time=$(date +%s)
    local deployment_duration=$((deployment_end_time - deployment_start_time))

    if [[ $failed_deployments -eq 0 ]]; then
        log_success "All deployments completed successfully in ${deployment_duration}s"
        send_notification "Deployment completed successfully in ${deployment_duration}s" "success"
    else
        log_error "$failed_deployments deployment(s) failed"
        send_notification "$failed_deployments deployment(s) failed" "error"
        return 1
    fi
}

# Deploy pods in parallel
deploy_pods_parallel() {
    local pids=()
    local results=()

    # Start parallel deployments
    for pod_name in "${PODS_TO_DEPLOY[@]}"; do
        (
            deploy_single_pod "$pod_name"
            echo $? > "/tmp/dreamscape_deploy_${pod_name}.result"
        ) &
        pids+=($!)
    done

    # Wait for all deployments
    for i in "${!pids[@]}"; do
        local pid=${pids[$i]}
        local pod_name=${PODS_TO_DEPLOY[$i]}

        if wait "$pid"; then
            local result_code
            result_code=$(cat "/tmp/dreamscape_deploy_${pod_name}.result" 2>/dev/null || echo "1")
            results+=("$result_code")
            rm -f "/tmp/dreamscape_deploy_${pod_name}.result"
        else
            results+=("1")
        fi
    done

    # Count failed deployments
    local failed_count=0
    for result in "${results[@]}"; do
        if [[ $result -ne 0 ]]; then
            failed_count=$((failed_count + 1))
        fi
    done

    return $failed_count
}

# Deploy single pod
deploy_single_pod() {
    local pod_name="$1"

    log_info "Deploying $pod_name pod..."

    # Choose deployment strategy
    if [[ "$BLUE_GREEN_DEPLOYMENT" == "true" ]]; then
        deploy_blue_green "$pod_name"
    elif [[ "$CANARY_DEPLOYMENT" == "true" ]]; then
        deploy_canary "$pod_name"
    else
        deploy_rolling_update "$pod_name"
    fi
}

# Cleanup deployment resources
cleanup_deployment() {
    log_debug "Cleaning up deployment resources..."

    # Remove temporary files
    rm -f /tmp/dreamscape_deploy_*.result

    # Clean up old images if successful deployment
    if [[ "$TARGET_ENVIRONMENT" == "local" ]]; then
        log_info "Cleaning up old Docker images..."
        docker image prune -f >/dev/null 2>&1 || true
    fi
}

# Main function
main() {
    local start_time
    start_time=$(date +%s)

    # Initialize
    init_common

    echo -e "${BLUE}${ROCKET_ICON} DreamScape Big Pods - Deployment Script${NC}"
    echo -e "${BLUE}Production deployment orchestration for Big Pods architecture${NC}"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Validate deployment
    if ! validate_deployment; then
        log_error "Deployment validation failed"
        exit 1
    fi

    # Show deployment plan
    log_info "Deployment Plan:"
    echo -e "  • Environment: $TARGET_ENVIRONMENT"
    echo -e "  • Version: ${DEPLOYMENT_VERSION:-latest}"
    echo -e "  • Pods: ${PODS_TO_DEPLOY[*]}"

    if [[ "$ROLLING_UPDATE" == "true" ]]; then
        echo -e "  • Strategy: Rolling Update"
    elif [[ "$BLUE_GREEN_DEPLOYMENT" == "true" ]]; then
        echo -e "  • Strategy: Blue-Green"
    elif [[ "$CANARY_DEPLOYMENT" == "true" ]]; then
        echo -e "  • Strategy: Canary (${CANARY_PERCENTAGE}%)"
    else
        echo -e "  • Strategy: Standard"
    fi

    echo ""

    # Confirm deployment
    if ! confirm_action "Proceed with deployment?" "y"; then
        log_info "Deployment cancelled by user"
        exit 0
    fi

    # Execute deployment
    if deploy_pods; then
        # Post-deployment verification
        if post_deployment_verification; then
            local end_time
            end_time=$(date +%s)
            local total_time=$((end_time - start_time))

            log_success "Deployment completed successfully in ${total_time}s!"
            send_notification "Deployment completed successfully in ${total_time}s" "success"
        else
            log_error "Post-deployment verification failed"
            exit 1
        fi
    else
        log_error "Deployment failed"
        exit 1
    fi
}

# Set cleanup trap
trap cleanup_deployment EXIT

# Execute main function
main "$@"
