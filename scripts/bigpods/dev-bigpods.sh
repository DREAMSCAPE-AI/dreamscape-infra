#!/bin/bash
# DreamScape Big Pods - Development Environment Script
# Démarrage simplifié environnement Big Pods avec hot reload

# Import common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Script-specific variables
START_ALL=true
HOT_RELOAD=true
AUTO_RESTART=true
SETUP_REPOS=false
SKIP_HEALTH_CHECKS=false
DEV_MODE="development"
SELECTED_PODS=()

# Development configuration
DEV_PORTS_OFFSET=0
DEV_LOG_LEVEL="debug"
DEV_WATCH_ENABLED=true

# Usage function
show_usage() {
    echo -e "${BLUE}${ROCKET_ICON} DreamScape Big Pods - Development Script${NC}"
    echo ""
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [OPTIONS] [POD...]"
    echo ""
    echo -e "${WHITE}OPTIONS:${NC}"
    echo "  -p, --pod POD          Start specific pod only"
    echo "  --setup-repos          Clone/setup 6 repositories"
    echo "  --no-hot-reload        Disable hot reload"
    echo "  --no-auto-restart      Disable auto restart"
    echo "  --skip-health          Skip health checks"
    echo "  --production-mode      Use production-like settings"
    echo "  --ports-offset N       Offset all ports by N"
    echo "  --log-level LEVEL      Set log level (debug, info, warn, error)"
    echo "  --no-watch             Disable file watching"
    echo "  -d, --detach           Run in background (detached mode)"
    echo "  --verbose              Verbose output"
    echo "  --debug                Debug output"
    echo "  -h, --help             Show this help"
    echo ""
    echo -e "${WHITE}PODS:${NC}"
    echo "  core                   Core Pod (auth, user) + databases"
    echo "  business               Business Pod (voyage, payment, ai)"
    echo "  experience             Experience Pod (panorama, web-client, gateway)"
    echo ""
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo "  $0                     # Start all pods in development mode"
    echo "  $0 --pod core          # Start Core Pod only"
    echo "  $0 --setup-repos       # Setup repositories and start"
    echo "  $0 --no-hot-reload     # Start without hot reload"
    echo "  $0 core business       # Start specific pods"
}

# Parse command line arguments
parse_args() {
    local detach_mode=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--pod)
                if validate_pod_name "$2"; then
                    SELECTED_PODS+=("$2")
                    START_ALL=false
                fi
                shift 2
                ;;
            --setup-repos)
                SETUP_REPOS=true
                shift
                ;;
            --no-hot-reload)
                HOT_RELOAD=false
                shift
                ;;
            --no-auto-restart)
                AUTO_RESTART=false
                shift
                ;;
            --skip-health)
                SKIP_HEALTH_CHECKS=true
                shift
                ;;
            --production-mode)
                DEV_MODE="production"
                HOT_RELOAD=false
                DEV_LOG_LEVEL="info"
                shift
                ;;
            --ports-offset)
                DEV_PORTS_OFFSET="$2"
                shift 2
                ;;
            --log-level)
                DEV_LOG_LEVEL="$2"
                shift 2
                ;;
            --no-watch)
                DEV_WATCH_ENABLED=false
                shift
                ;;
            -d|--detach)
                detach_mode=true
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
                    SELECTED_PODS+=("$1")
                    START_ALL=false
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

    # Set pods to start
    if [[ "$START_ALL" == "true" ]]; then
        SELECTED_PODS=("core" "business" "experience")
    fi

    # Store detach mode
    if [[ "$detach_mode" == "true" ]]; then
        export DETACH_MODE=true
    fi

    log_debug "Pods to start: ${SELECTED_PODS[*]}"
    log_debug "Development mode: $DEV_MODE"
}

# Check development prerequisites
check_dev_prerequisites() {
    log_info "Checking development prerequisites..."

    # Check Node.js and npm
    if ! command -v node >/dev/null 2>&1; then
        log_error "Node.js not found. Please install Node.js 18+"
        exit 1
    fi

    local node_version
    node_version=$(node --version | sed 's/v//')
    local major_version
    major_version=$(echo "$node_version" | cut -d. -f1)

    if [[ $major_version -lt 18 ]]; then
        log_warning "Node.js version $node_version detected. Recommended: 18+"
    else
        log_success "Node.js $node_version"
    fi

    # Check npm
    if ! command -v npm >/dev/null 2>&1; then
        log_error "npm not found"
        exit 1
    fi

    log_success "npm $(npm --version)"

    # Check Docker
    check_docker

    # Check Docker Compose
    local compose_cmd
    compose_cmd=$(check_docker_compose)
    log_success "Docker Compose available: $compose_cmd"

    # Check Git
    if ! command -v git >/dev/null 2>&1; then
        log_error "Git not found"
        exit 1
    fi

    log_success "Git $(git --version | cut -d' ' -f3)"

    # Check available ports
    check_dev_ports
}

# Check development ports availability
check_dev_ports() {
    log_verbose "Checking development ports availability..."

    local required_ports=(80 3000 3001 3002 3003 3004 3005 3006 5173 27017 6379)

    for port in "${required_ports[@]}"; do
        local adjusted_port=$((port + DEV_PORTS_OFFSET))

        if ! check_port_available "$adjusted_port"; then
            log_warning "Port $adjusted_port is already in use"

            if [[ "$port" == "80" ]] && [[ "$adjusted_port" == "80" ]]; then
                log_info "Port 80 conflict - will use alternative nginx port"
            fi
        fi
    done
}

# Setup repositories
setup_repositories() {
    log_info "Setting up DreamScape repositories..."

    local base_dir="$PROJECT_ROOT"
    local repos=(
        "dreamscape-services"
        "dreamscape-frontend"
        "dreamscape-tests"
        "dreamscape-docs"
        "dreamscape-infra"
    )

    for repo in "${repos[@]}"; do
        local repo_path="$base_dir/$repo"

        if [[ ! -d "$repo_path" ]]; then
            log_info "Repository $repo not found locally"

            if confirm_action "Clone $repo repository?"; then
                log_info "Cloning $repo..."

                git clone "https://github.com/dreamscape/$repo.git" "$repo_path"
            fi
        else
            log_success "Repository $repo exists"

            # Update repository
            if confirm_action "Update $repo repository?"; then
                log_info "Updating $repo..."
                cd "$repo_path"
                git pull origin main || log_warning "Failed to update $repo"
                cd "$base_dir"
            fi
        fi

        # Install dependencies if package.json exists
        if [[ -f "$repo_path/package.json" ]]; then
            log_info "Installing dependencies for $repo..."
            cd "$repo_path"
            npm install || log_warning "Failed to install dependencies for $repo"
            cd "$base_dir"
        fi
    done
}

# Setup development environment variables
setup_dev_environment() {
    log_info "Setting up development environment..."

    # Create development .env file
    local env_file="$PROJECT_ROOT/.env.development"

    if [[ ! -f "$env_file" ]]; then
        log_info "Creating development environment file..."

        cat > "$env_file" << EOF
# DreamScape Development Environment
NODE_ENV=$DEV_MODE
LOG_LEVEL=$DEV_LOG_LEVEL

# Database URLs
DATABASE_URL=mongodb://admin:password123@localhost:27017/dreamscape?authSource=admin
REDIS_URL=redis://localhost:6379
POSTGRES_URL=postgresql://postgres:password123@localhost:5432/dreamscape

# JWT Configuration
JWT_SECRET=dev-secret-key-change-in-production
JWT_EXPIRES_IN=24h

# External APIs (development)
AMADEUS_API_KEY=test_key
AMADEUS_API_SECRET=test_secret
STRIPE_SECRET_KEY=sk_test_
STRIPE_PUBLISHABLE_KEY=pk_test_
OPENAI_API_KEY=test_key

# Development Settings
HOT_RELOAD=$HOT_RELOAD
AUTO_RESTART=$AUTO_RESTART
WATCH_ENABLED=$DEV_WATCH_ENABLED

# Port Configuration
PORT_OFFSET=$DEV_PORTS_OFFSET
NGINX_PORT=$((80 + DEV_PORTS_OFFSET))
AUTH_PORT=$((3001 + DEV_PORTS_OFFSET))
USER_PORT=$((3002 + DEV_PORTS_OFFSET))
VOYAGE_PORT=$((3003 + DEV_PORTS_OFFSET))
PAYMENT_PORT=$((3004 + DEV_PORTS_OFFSET))
AI_PORT=$((3005 + DEV_PORTS_OFFSET))
PANORAMA_PORT=$((3006 + DEV_PORTS_OFFSET))
WEB_CLIENT_PORT=$((5173 + DEV_PORTS_OFFSET))
GATEWAY_PORT=$((3000 + DEV_PORTS_OFFSET))
EOF

        log_success "Development environment file created: $env_file"
    else
        log_info "Development environment file exists: $env_file"
    fi

    # Export environment variables
    set -a
    source "$env_file"
    set +a
}

# Start databases
start_databases() {
    log_info "Starting development databases..."

    local compose_cmd
    compose_cmd=$(check_docker_compose)

    cd docker

    # Start MongoDB
    log_info "Starting MongoDB..."
    if $compose_cmd -f docker-compose.core-pod.yml up -d mongodb; then
        wait_for_service "MongoDB" "mongodb://localhost:27017" 60
    else
        log_error "Failed to start MongoDB"
        return 1
    fi

    # Start Redis
    log_info "Starting Redis..."
    if $compose_cmd -f docker-compose.core-pod.yml up -d redis; then
        wait_for_service "Redis" "redis://localhost:6379" 30
    else
        log_error "Failed to start Redis"
        return 1
    fi

    # Start PostgreSQL if needed for business pod
    if [[ " ${SELECTED_PODS[*]} " =~ " business " ]]; then
        log_info "Starting PostgreSQL for business pod..."
        if $compose_cmd -f docker-compose.business-pod.yml up -d postgresql 2>/dev/null; then
            wait_for_service "PostgreSQL" "postgresql://localhost:5432" 60
        else
            log_warning "PostgreSQL not configured or failed to start"
        fi
    fi

    cd ..
    log_success "Databases started"
}

# Start a development pod
start_dev_pod() {
    local pod_name="$1"

    log_info "Starting $pod_name pod in development mode..."

    case "$pod_name" in
        "core")
            start_core_pod_dev
            ;;
        "business")
            start_business_pod_dev
            ;;
        "experience")
            start_experience_pod_dev
            ;;
        *)
            log_error "Unknown pod: $pod_name"
            return 1
            ;;
    esac
}

# Start Core Pod in development mode
start_core_pod_dev() {
    log_info "Starting Core Pod development services..."

    local services_dir="$PROJECT_ROOT/../dreamscape-services"

    if [[ ! -d "$services_dir" ]]; then
        log_error "dreamscape-services directory not found: $services_dir"
        return 1
    fi

    # Start Auth Service
    if [[ "$HOT_RELOAD" == "true" ]]; then
        log_info "Starting Auth Service with hot reload..."
        cd "$services_dir/auth"

        if [[ "${DETACH_MODE:-false}" == "true" ]]; then
            npm run dev > "$PROJECT_ROOT/logs/auth.log" 2>&1 &
            echo $! > "$PROJECT_ROOT/pids/auth.pid"
        else
            npm run dev &
        fi
    fi

    # Start User Service
    if [[ "$HOT_RELOAD" == "true" ]]; then
        log_info "Starting User Service with hot reload..."
        cd "$services_dir/user"

        if [[ "${DETACH_MODE:-false}" == "true" ]]; then
            npm run dev > "$PROJECT_ROOT/logs/user.log" 2>&1 &
            echo $! > "$PROJECT_ROOT/pids/user.pid"
        else
            npm run dev &
        fi
    fi

    # Start NGINX for Core Pod
    start_nginx_dev "core"

    cd "$PROJECT_ROOT"
}

# Start Business Pod in development mode
start_business_pod_dev() {
    log_info "Starting Business Pod development services..."

    local services_dir="$PROJECT_ROOT/../dreamscape-services"

    # Start Voyage Service
    if [[ "$HOT_RELOAD" == "true" ]]; then
        log_info "Starting Voyage Service with hot reload..."
        cd "$services_dir/voyage"

        if [[ "${DETACH_MODE:-false}" == "true" ]]; then
            npm run dev > "$PROJECT_ROOT/logs/voyage.log" 2>&1 &
            echo $! > "$PROJECT_ROOT/pids/voyage.pid"
        else
            npm run dev &
        fi
    fi

    # Start Payment Service
    if [[ "$HOT_RELOAD" == "true" ]]; then
        log_info "Starting Payment Service with hot reload..."
        cd "$services_dir/payment"

        if [[ "${DETACH_MODE:-false}" == "true" ]]; then
            npm run dev > "$PROJECT_ROOT/logs/payment.log" 2>&1 &
            echo $! > "$PROJECT_ROOT/pids/payment.pid"
        else
            npm run dev &
        fi
    fi

    # Start AI Service
    if [[ "$HOT_RELOAD" == "true" ]]; then
        log_info "Starting AI Service with hot reload..."
        cd "$services_dir/ai"

        if [[ "${DETACH_MODE:-false}" == "true" ]]; then
            npm run dev > "$PROJECT_ROOT/logs/ai.log" 2>&1 &
            echo $! > "$PROJECT_ROOT/pids/ai.pid"
        else
            npm run dev &
        fi
    fi

    cd "$PROJECT_ROOT"
}

# Start Experience Pod in development mode
start_experience_pod_dev() {
    log_info "Starting Experience Pod development services..."

    local services_dir="$PROJECT_ROOT/../dreamscape-services"
    local frontend_dir="$PROJECT_ROOT/../dreamscape-frontend"

    # Start Panorama Service
    if [[ "$HOT_RELOAD" == "true" ]]; then
        log_info "Starting Panorama Service with hot reload..."
        cd "$services_dir/panorama"

        if [[ "${DETACH_MODE:-false}" == "true" ]]; then
            npm run dev > "$PROJECT_ROOT/logs/panorama.log" 2>&1 &
            echo $! > "$PROJECT_ROOT/pids/panorama.pid"
        else
            npm run dev &
        fi
    fi

    # Start Web Client
    if [[ -d "$frontend_dir/web-client" ]]; then
        log_info "Starting Web Client with hot reload..."
        cd "$frontend_dir/web-client"

        if [[ "${DETACH_MODE:-false}" == "true" ]]; then
            npm run dev > "$PROJECT_ROOT/logs/web-client.log" 2>&1 &
            echo $! > "$PROJECT_ROOT/pids/web-client.pid"
        else
            npm run dev &
        fi
    fi

    # Start Gateway
    if [[ -d "$frontend_dir/gateway" ]]; then
        log_info "Starting Gateway with hot reload..."
        cd "$frontend_dir/gateway"

        if [[ "${DETACH_MODE:-false}" == "true" ]]; then
            npm run dev > "$PROJECT_ROOT/logs/gateway.log" 2>&1 &
            echo $! > "$PROJECT_ROOT/pids/gateway.pid"
        else
            npm run dev &
        fi
    fi

    cd "$PROJECT_ROOT"
}

# Start NGINX for development
start_nginx_dev() {
    local pod_name="$1"

    log_info "Starting NGINX for $pod_name pod..."

    local compose_cmd
    compose_cmd=$(check_docker_compose)

    cd docker

    # Use development Docker Compose override
    local compose_files="-f docker-compose.${pod_name}-pod.yml"

    if [[ -f "docker-compose.${pod_name}-pod.dev.yml" ]]; then
        compose_files="$compose_files -f docker-compose.${pod_name}-pod.dev.yml"
    fi

    if $compose_cmd $compose_files up -d nginx 2>/dev/null; then
        log_success "NGINX started for $pod_name pod"
    else
        log_warning "Failed to start NGINX for $pod_name pod"
    fi

    cd ..
}

# Health checks for development
run_health_checks() {
    if [[ "$SKIP_HEALTH_CHECKS" == "true" ]]; then
        log_info "Skipping health checks"
        return 0
    fi

    log_info "Running development health checks..."

    local health_urls=()

    for pod_name in "${SELECTED_PODS[@]}"; do
        case "$pod_name" in
            "core")
                health_urls+=("http://localhost:$((3001 + DEV_PORTS_OFFSET))/health")  # Auth
                health_urls+=("http://localhost:$((3002 + DEV_PORTS_OFFSET))/health")  # User
                ;;
            "business")
                health_urls+=("http://localhost:$((3003 + DEV_PORTS_OFFSET))/health")  # Voyage
                health_urls+=("http://localhost:$((3004 + DEV_PORTS_OFFSET))/health")  # Payment
                health_urls+=("http://localhost:$((3005 + DEV_PORTS_OFFSET))/health")  # AI
                ;;
            "experience")
                health_urls+=("http://localhost:$((3006 + DEV_PORTS_OFFSET))/health")  # Panorama
                health_urls+=("http://localhost:$((5173 + DEV_PORTS_OFFSET))")         # Web Client
                health_urls+=("http://localhost:$((3000 + DEV_PORTS_OFFSET))/health")  # Gateway
                ;;
        esac
    done

    local healthy_services=0
    local total_services=${#health_urls[@]}

    for url in "${health_urls[@]}"; do
        if check_service_health "$url" 5 3; then
            healthy_services=$((healthy_services + 1))
        fi
    done

    log_info "Health check results: $healthy_services/$total_services services healthy"

    if [[ $healthy_services -eq $total_services ]]; then
        log_success "All services are healthy!"
    else
        log_warning "Some services may still be starting up"
    fi
}

# Show development information
show_dev_info() {
    echo ""
    log_info "Development Environment Ready!"
    echo ""

    log_info "Service URLs:"
    for pod_name in "${SELECTED_PODS[@]}"; do
        case "$pod_name" in
            "core")
                echo -e "  ${SUCCESS_ICON} Auth Service: http://localhost:$((3001 + DEV_PORTS_OFFSET))"
                echo -e "  ${SUCCESS_ICON} User Service: http://localhost:$((3002 + DEV_PORTS_OFFSET))"
                ;;
            "business")
                echo -e "  ${SUCCESS_ICON} Voyage Service: http://localhost:$((3003 + DEV_PORTS_OFFSET))"
                echo -e "  ${SUCCESS_ICON} Payment Service: http://localhost:$((3004 + DEV_PORTS_OFFSET))"
                echo -e "  ${SUCCESS_ICON} AI Service: http://localhost:$((3005 + DEV_PORTS_OFFSET))"
                ;;
            "experience")
                echo -e "  ${SUCCESS_ICON} Panorama Service: http://localhost:$((3006 + DEV_PORTS_OFFSET))"
                echo -e "  ${SUCCESS_ICON} Web Client: http://localhost:$((5173 + DEV_PORTS_OFFSET))"
                echo -e "  ${SUCCESS_ICON} Gateway: http://localhost:$((3000 + DEV_PORTS_OFFSET))"
                ;;
        esac
    done

    echo ""
    log_info "Development Features:"
    echo -e "  • Hot Reload: $([ "$HOT_RELOAD" == "true" ] && echo "${SUCCESS_ICON} Enabled" || echo "${WARNING_ICON} Disabled")"
    echo -e "  • Auto Restart: $([ "$AUTO_RESTART" == "true" ] && echo "${SUCCESS_ICON} Enabled" || echo "${WARNING_ICON} Disabled")"
    echo -e "  • File Watching: $([ "$DEV_WATCH_ENABLED" == "true" ] && echo "${SUCCESS_ICON} Enabled" || echo "${WARNING_ICON} Disabled")"
    echo -e "  • Log Level: $DEV_LOG_LEVEL"

    echo ""
    log_info "Logs Location: $PROJECT_ROOT/logs/"
    log_info "PIDs Location: $PROJECT_ROOT/pids/"

    if [[ "${DETACH_MODE:-false}" == "false" ]]; then
        echo ""
        log_info "Press Ctrl+C to stop all services"
    fi
}

# Setup log and pid directories
setup_runtime_dirs() {
    ensure_directory "$PROJECT_ROOT/logs"
    ensure_directory "$PROJECT_ROOT/pids"
}

# Cleanup function
cleanup_dev() {
    log_info "Stopping development environment..."

    # Kill background processes if in detached mode
    if [[ "${DETACH_MODE:-false}" == "true" ]]; then
        local pid_files=("$PROJECT_ROOT/pids"/*.pid)

        for pid_file in "${pid_files[@]}"; do
            if [[ -f "$pid_file" ]]; then
                local pid
                pid=$(cat "$pid_file")
                if kill -0 "$pid" 2>/dev/null; then
                    log_debug "Killing process $pid"
                    kill "$pid" 2>/dev/null || true
                fi
                rm -f "$pid_file"
            fi
        done
    fi

    # Stop Docker services
    local compose_cmd
    compose_cmd=$(check_docker_compose)

    cd docker
    $compose_cmd -f docker-compose.core-pod.yml down >/dev/null 2>&1 || true

    if [[ -f docker-compose.business-pod.yml ]]; then
        $compose_cmd -f docker-compose.business-pod.yml down >/dev/null 2>&1 || true
    fi

    if [[ -f docker-compose.experience-pod.yml ]]; then
        $compose_cmd -f docker-compose.experience-pod.yml down >/dev/null 2>&1 || true
    fi

    cd ..

    log_success "Development environment stopped"
}

# Main function
main() {
    # Initialize
    init_common

    echo -e "${BLUE}${ROCKET_ICON} DreamScape Big Pods - Development Environment${NC}"
    echo -e "${BLUE}Hot reload development for 6 repositories → 3 Big Pods${NC}"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Setup runtime directories
    setup_runtime_dirs

    # Check prerequisites
    check_dev_prerequisites

    # Setup repositories if requested
    if [[ "$SETUP_REPOS" == "true" ]]; then
        setup_repositories
    fi

    # Setup development environment
    setup_dev_environment

    # Start databases
    start_databases

    # Start selected pods
    for pod_name in "${SELECTED_PODS[@]}"; do
        start_dev_pod "$pod_name"
        sleep 5  # Allow services to start
    done

    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 10

    # Run health checks
    run_health_checks

    # Show development information
    show_dev_info

    # Wait for interrupt if not in detached mode
    if [[ "${DETACH_MODE:-false}" == "false" ]]; then
        wait
    fi
}

# Set cleanup trap
trap cleanup_dev EXIT

# Execute main function
main "$@"