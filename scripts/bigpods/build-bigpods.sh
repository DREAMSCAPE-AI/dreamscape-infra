#!/bin/bash
# DreamScape Big Pods - Build Automation Script
# Build automatique des 3 Big Pods avec détection intelligente des changements

# Import common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Script-specific variables
BUILD_ALL=false
SMART_BUILD=true
NO_CACHE=false
PUSH_IMAGES=false
VERSION_TAG=""
PARALLEL_BUILD=false
BUILD_TIMEOUT=1800  # 30 minutes

# Build statistics
BUILD_STATS=""
TOTAL_BUILD_TIME=0
BUILDS_COMPLETED=0
BUILDS_FAILED=0

# Get the full image name for a pod, honoring registry env vars when set.
get_pod_image_name() {
    local pod_name="$1"
    local registry_prefix=""
    local namespace="${REGISTRY_NAMESPACE:-dreamscape}"

    if [[ -n "${REGISTRY_URL:-}" ]]; then
        registry_prefix="${REGISTRY_URL}/"
    fi

    echo "${registry_prefix}${namespace}/${pod_name}-pod"
}

# Usage function
show_usage() {
    echo -e "${BLUE}${ROCKET_ICON} DreamScape Big Pods - Build Script${NC}"
    echo ""
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [OPTIONS] [POD...]"
    echo ""
    echo -e "${WHITE}OPTIONS:${NC}"
    echo "  -a, --all              Build all Big Pods"
    echo "  -s, --smart            Smart build with change detection (default)"
    echo "  --no-smart             Disable smart build"
    echo "  --no-cache             Build without Docker cache"
    echo "  --push                 Push images to registry after build"
    echo "  -v, --version TAG      Tag images with specific version"
    echo "  -p, --parallel         Build pods in parallel"
    echo "  -t, --timeout SECONDS  Build timeout (default: 1800)"
    echo "  --dry-run              Show what would be built without building"
    echo "  -f, --force            Force build without confirmation"
    echo "  --verbose              Verbose output"
    echo "  --debug                Debug output"
    echo "  -h, --help             Show this help"
    echo ""
    echo -e "${WHITE}PODS:${NC}"
    echo "  core                   Core Pod (auth, user)"
    echo "  business               Business Pod (voyage, payment, ai)"
    echo "  experience             Experience Pod (panorama, web-client, gateway)"
    echo ""
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo "  $0                     # Smart build all pods"
    echo "  $0 --smart core        # Smart build Core Pod only"
    echo "  $0 -a --no-cache       # Build all pods without cache"
    echo "  $0 -v v2.1.0 --push    # Build with version tag and push"
    echo "  $0 --parallel business experience  # Build specific pods in parallel"
}

# Parse command line arguments
parse_args() {
    local pods_to_build=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all)
                BUILD_ALL=true
                shift
                ;;
            -s|--smart)
                SMART_BUILD=true
                shift
                ;;
            --no-smart)
                SMART_BUILD=false
                shift
                ;;
            --no-cache)
                NO_CACHE=true
                shift
                ;;
            --push)
                PUSH_IMAGES=true
                shift
                ;;
            -v|--version)
                VERSION_TAG="$2"
                shift 2
                ;;
            -p|--parallel)
                PARALLEL_BUILD=true
                shift
                ;;
            -t|--timeout)
                BUILD_TIMEOUT="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
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
                    pods_to_build+=("$1")
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

    # Set pods to build
    if [[ "$BUILD_ALL" == "true" ]]; then
        PODS_TO_BUILD=("core" "business" "experience")
    elif [[ ${#pods_to_build[@]} -gt 0 ]]; then
        PODS_TO_BUILD=("${pods_to_build[@]}")
    else
        PODS_TO_BUILD=("core" "business" "experience")
    fi

    log_debug "Pods to build: ${PODS_TO_BUILD[*]}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking build prerequisites..."

    # Check Docker
    check_docker

    # Check Docker Compose
    local compose_cmd
    compose_cmd=$(check_docker_compose)
    log_success "Docker Compose available: $compose_cmd"

    # Check disk space (require at least 10GB)
    local available_space
    if command -v df >/dev/null 2>&1; then
        available_space=$(df . | tail -1 | awk '{print $4}')
        if [[ $available_space -lt 10485760 ]]; then  # 10GB in KB
            log_warning "Low disk space: $(($available_space / 1024 / 1024))GB available"
        fi
    fi

    # Check if registries are accessible (if pushing)
    if [[ "$PUSH_IMAGES" == "true" ]]; then
        log_info "Checking registry connectivity..."
        if ! docker login --password-stdin >/dev/null 2>&1 <<< ""; then
            log_warning "Not logged in to Docker registry"
        fi
    fi
}

# Ensure required repositories are present (clones dreamscape-services if missing)
ensure_build_dependencies() {
    local repo_path
    repo_path=$(get_repository_path "dreamscape-services")

    if [[ -d "$repo_path" ]]; then
        log_debug "Dependency repository present: $repo_path"
        return 0
    fi

    log_warning "Missing repository: $repo_path"

    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_error "GITHUB_TOKEN not set. Cannot clone dreamscape-services automatically."
        return 1
    fi

    log_info "Cloning dreamscape-services..."
    if git clone --depth 1 "https://x-access-token:${GITHUB_TOKEN}@github.com/DREAMSCAPE-AI/dreamscape-services.git" "$repo_path"; then
        log_success "Cloned dreamscape-services into $repo_path"
        return 0
    else
        log_error "Failed to clone dreamscape-services into $repo_path"
        return 1
    fi
}

# Detect changes in repositories
detect_changes() {
    local pod_name="$1"
    local changes_detected=false

    log_verbose "Detecting changes for $pod_name pod..."

    case "$pod_name" in
        "core")
            local repos=("dreamscape-services")
            local services=("auth" "user")
            ;;
        "business")
            local repos=("dreamscape-services")
            local services=("voyage" "payment" "ai")
            ;;
        "experience")
            local repos=("dreamscape-services" "dreamscape-frontend")
            local services=("panorama" "web-client" "gateway")
            ;;
    esac

    # Check repository changes
    for repo in "${repos[@]}"; do
        if detect_repository_changes "$repo"; then
            log_verbose "Changes detected in repository: $repo"
            changes_detected=true
        fi
    done

    # Check for Docker-related changes
    local docker_files=(
        "docker/docker-compose.${pod_name}-pod.yml"
        "docker/${pod_name}-pod/Dockerfile"
        "docker/${pod_name}-pod/nginx.conf"
    )

    for file in "${docker_files[@]}"; do
        if [[ -f "$file" ]] && git diff-index --quiet HEAD -- "$file" 2>/dev/null; then
            log_verbose "Changes detected in Docker file: $file"
            changes_detected=true
        fi
    done

    if [[ "$changes_detected" == "true" ]]; then
        log_info "Changes detected for $pod_name pod - build required"
        return 0
    else
        log_success "No changes detected for $pod_name pod - build not required"
        return 1
    fi
}

# Build a single pod
build_pod() {
    local pod_name="$1"
    local start_time
    start_time=$(date +%s)

    log_info "Building $pod_name pod..."

    # Ensure dependent repos exist (e.g., dreamscape-services for shared/kafka and Prisma schema)
    if [[ "$pod_name" == "business" ]]; then
        if ! ensure_build_dependencies; then
            log_error "Dependency preparation failed for $pod_name pod"
            return 1
        fi
    fi

    # Check if build is needed with smart build
    if [[ "$SMART_BUILD" == "true" ]] && ! detect_changes "$pod_name"; then
        if [[ "$PUSH_IMAGES" == "true" ]]; then
            log_info "Push requested - building $pod_name pod despite no changes"
        else
            log_success "$pod_name pod is up to date"
            return 0
        fi
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would build $pod_name pod"
        return 0
    fi

    # Get Docker Compose configuration
    local compose_file
    compose_file=$(get_pod_docker_compose "$pod_name")

    local full_compose_path="../../docker/$compose_file"

    if [[ ! -f "$full_compose_path" ]]; then
        log_error "Docker Compose file not found: $full_compose_path"
        BUILDS_FAILED=$((BUILDS_FAILED + 1))
        BUILD_STATS="${BUILD_STATS}${ERROR_ICON} $pod_name: missing compose file\n"
        return 1
    fi

    # Prepare build command
    local compose_cmd
    compose_cmd=$(check_docker_compose)
    local DOCKER_DIR="../../docker"

    local build_options=""
    if [[ "$NO_CACHE" == "true" ]]; then
        build_options="$build_options --no-cache"
    fi

    if [[ "$PARALLEL_BUILD" == "true" ]]; then
        build_options="$build_options --parallel"
    fi

    local full_build_cmd="cd '$DOCKER_DIR' && $compose_cmd -f '$compose_file' build $build_options ${pod_name}-pod"

    log_verbose "Build command: $full_build_cmd"

    # Execute build with timeout
    if timeout "$BUILD_TIMEOUT" bash -c "$full_build_cmd"; then
        local end_time
        end_time=$(date +%s)
        local build_time=$((end_time - start_time))

        # Tag with version if specified
        if [[ -n "$VERSION_TAG" ]]; then
            local image_name
            image_name=$(get_pod_image_name "$pod_name")
            docker tag "${image_name}:latest" "${image_name}:${VERSION_TAG}"
            log_success "Tagged $pod_name pod with version $VERSION_TAG"
        fi

        # Push images if requested
        if [[ "$PUSH_IMAGES" == "true" ]]; then
            push_pod_images "$pod_name"
        fi

        log_success "$pod_name pod built successfully in ${build_time}s"
        BUILDS_COMPLETED=$((BUILDS_COMPLETED + 1))
        TOTAL_BUILD_TIME=$((TOTAL_BUILD_TIME + build_time))

        # Add to build stats
        BUILD_STATS="${BUILD_STATS}${SUCCESS_ICON} $pod_name: ${build_time}s\n"

        return 0
    else
        log_error "$pod_name pod build failed or timed out"
        BUILDS_FAILED=$((BUILDS_FAILED + 1))
        BUILD_STATS="${BUILD_STATS}${ERROR_ICON} $pod_name: FAILED\n"
        return 1
    fi
}

# Push pod images to registry
push_pod_images() {
    local pod_name="$1"

    log_info "Pushing $pod_name pod images..."

    local image_name
    image_name=$(get_pod_image_name "$pod_name")

    # Push latest tag
    if docker push "${image_name}:latest"; then
        log_success "Pushed ${image_name}:latest"
    else
        log_error "Failed to push ${image_name}:latest"
        return 1
    fi

    # Push version tag if specified
    if [[ -n "$VERSION_TAG" ]]; then
        if docker push "${image_name}:${VERSION_TAG}"; then
            log_success "Pushed ${image_name}:${VERSION_TAG}"
        else
            log_error "Failed to push ${image_name}:${VERSION_TAG}"
            return 1
        fi
    fi
}

# Build pods in parallel
build_pods_parallel() {
    local pids=()
    local results=()

    log_info "Building ${#PODS_TO_BUILD[@]} pods in parallel..."

    # Start background builds
    for pod_name in "${PODS_TO_BUILD[@]}"; do
        log_info "Starting parallel build for $pod_name pod..."
        (
            build_pod "$pod_name"
            echo $? > "/tmp/dreamscape_build_${pod_name}.result"
        ) &
        pids+=($!)
    done

    # Wait for all builds to complete
    for i in "${!pids[@]}"; do
        local pid=${pids[$i]}
        local pod_name=${PODS_TO_BUILD[$i]}

        if wait "$pid"; then
            local result_code
            result_code=$(cat "/tmp/dreamscape_build_${pod_name}.result" 2>/dev/null || echo "1")
            results+=("$result_code")
            rm -f "/tmp/dreamscape_build_${pod_name}.result"
        else
            results+=("1")
            log_error "$pod_name pod build process failed"
        fi
    done

    # Check results
    local failed_builds=0
    for i in "${!results[@]}"; do
        if [[ ${results[$i]} -ne 0 ]]; then
            failed_builds=$((failed_builds + 1))
        fi
    done

    return $failed_builds
}

# Build pods sequentially
build_pods_sequential() {
    local failed_builds=0

    for pod_name in "${PODS_TO_BUILD[@]}"; do
        if ! build_pod "$pod_name"; then
            failed_builds=$((failed_builds + 1))

            if ! confirm_action "Continue building remaining pods?"; then
                break
            fi
        fi
    done

    return $failed_builds
}

# Show build summary
show_build_summary() {
    echo ""
    log_info "Build Summary:"
    echo -e "${BUILD_STATS}"

    echo ""
    log_info "Statistics:"
    echo -e "  • Total builds: ${#PODS_TO_BUILD[@]}"
    echo -e "  • Successful: ${BUILDS_COMPLETED}"
    echo -e "  • Failed: ${BUILDS_FAILED}"
    echo -e "  • Total time: ${TOTAL_BUILD_TIME}s"

    if [[ $BUILDS_FAILED -eq 0 ]]; then
        log_success "All builds completed successfully!"
    else
        log_error "$BUILDS_FAILED build(s) failed"
    fi
}

# Cleanup function
cleanup_build() {
    log_debug "Cleaning up build artifacts..."

    # Remove temporary files
    rm -f /tmp/dreamscape_build_*.result

    # Clean up Docker build cache if requested
    if [[ "$NO_CACHE" == "true" ]]; then
        log_info "Cleaning Docker build cache..."
        docker builder prune -f >/dev/null 2>&1 || true
    fi
}

# Main function
main() {
    local start_time
    start_time=$(date +%s)

    # Initialize
    init_common

    echo -e "${BLUE}${ROCKET_ICON} DreamScape Big Pods - Build Script${NC}"
    echo -e "${BLUE}Building 6 repositories → 3 Big Pods architecture${NC}"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Check prerequisites
    check_prerequisites

    # Show build plan
    log_info "Build Plan:"
    for pod_name in "${PODS_TO_BUILD[@]}"; do
        echo -e "  • $pod_name pod"
    done

    if [[ "$SMART_BUILD" == "true" ]]; then
        log_info "Smart build enabled - only changed pods will be built"
    fi

    echo ""

    # Confirm build if not forced
    if ! confirm_action "Proceed with build?" "y"; then
        log_info "Build cancelled by user"
        exit 0
    fi

    # Execute builds
    local build_result
    if [[ "$PARALLEL_BUILD" == "true" ]] && [[ ${#PODS_TO_BUILD[@]} -gt 1 ]]; then
        build_pods_parallel
        build_result=$?
    else
        build_pods_sequential
        build_result=$?
    fi

    # Show summary
    show_build_summary

    # Calculate total execution time
    local end_time
    end_time=$(date +%s)
    local execution_time=$((end_time - start_time))

    echo ""
    log_info "Total execution time: ${execution_time}s"

    # Cleanup
    cleanup_build

    if [[ $build_result -eq 0 ]]; then
        log_success "Build completed successfully!"
        exit 0
    else
        log_error "Build completed with errors"
        exit 1
    fi
}

# Set cleanup trap
trap cleanup_build EXIT

# Execute main function
main "$@"
