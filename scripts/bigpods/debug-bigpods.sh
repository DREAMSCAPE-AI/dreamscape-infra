#!/bin/bash
# DreamScape Big Pods - Debug Script
# Debugging sophistiqué par Big Pod avec logs agrégés et tests connectivité

# Import common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Script-specific variables
DEBUG_POD=""
DEBUG_MODE="interactive"
LOG_TAIL_LINES=50
FOLLOW_LOGS=false
AGGREGATE_LOGS=false
TEST_CONNECTIVITY=false
TRACE_REQUESTS=false
EXPORT_DEBUG_INFO=false
DEBUG_OUTPUT_DIR=""

# Usage function
show_usage() {
    echo -e "${BLUE}${MAGNIFY_ICON} DreamScape Big Pods - Debug Script${NC}"
    echo ""
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [OPTIONS] [POD]"
    echo ""
    echo -e "${WHITE}OPTIONS:${NC}"
    echo "  -p, --pod POD          Debug specific pod (core, business, experience)"
    echo "  -m, --mode MODE        Debug mode (interactive, logs, connectivity, trace)"
    echo "  -f, --follow           Follow logs in real-time"
    echo "  -n, --lines N          Number of log lines to show (default: 50)"
    echo "  -a, --aggregate        Aggregate logs from all services in pod"
    echo "  -c, --connectivity     Test inter-pod connectivity"
    echo "  -t, --trace            Trace HTTP requests"
    echo "  -e, --export           Export debug information to file"
    echo "  -o, --output DIR       Output directory for debug exports"
    echo "  --verbose              Verbose output"
    echo "  --debug                Debug output"
    echo "  -h, --help             Show this help"
    echo ""
    echo -e "${WHITE}DEBUG MODES:${NC}"
    echo "  interactive            Interactive debugging session"
    echo "  logs                   Show and analyze logs"
    echo "  connectivity           Test network connectivity"
    echo "  trace                  HTTP request tracing"
    echo "  health                 Comprehensive health check"
    echo "  performance            Performance analysis"
    echo ""
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo "  $0 core                # Interactive debug Core Pod"
    echo "  $0 --mode logs -f      # Follow all pod logs"
    echo "  $0 -p business -c      # Test Business Pod connectivity"
    echo "  $0 --trace --export    # Trace requests and export results"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--pod)
                if validate_pod_name "$2"; then
                    DEBUG_POD="$2"
                fi
                shift 2
                ;;
            -m|--mode)
                DEBUG_MODE="$2"
                shift 2
                ;;
            -f|--follow)
                FOLLOW_LOGS=true
                shift
                ;;
            -n|--lines)
                LOG_TAIL_LINES="$2"
                shift 2
                ;;
            -a|--aggregate)
                AGGREGATE_LOGS=true
                shift
                ;;
            -c|--connectivity)
                TEST_CONNECTIVITY=true
                shift
                ;;
            -t|--trace)
                TRACE_REQUESTS=true
                shift
                ;;
            -e|--export)
                EXPORT_DEBUG_INFO=true
                shift
                ;;
            -o|--output)
                DEBUG_OUTPUT_DIR="$2"
                shift 2
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
                    DEBUG_POD="$1"
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

    # Set default output directory
    if [[ "$EXPORT_DEBUG_INFO" == "true" ]] && [[ -z "$DEBUG_OUTPUT_DIR" ]]; then
        DEBUG_OUTPUT_DIR="$PROJECT_ROOT/debug-exports/$(date +%Y%m%d_%H%M%S)"
    fi

    log_debug "Debug pod: $DEBUG_POD"
    log_debug "Debug mode: $DEBUG_MODE"
}

# Get pod containers
get_pod_containers() {
    local pod_name="$1"
    local containers=()

    case "$pod_name" in
        "core")
            containers=("core-pod" "mongodb" "redis")
            ;;
        "business")
            containers=("business-pod" "postgresql" "redis")
            ;;
        "experience")
            containers=("experience-pod" "nginx")
            ;;
        *)
            log_error "Invalid pod name: $pod_name"
            return 1
            ;;
    esac

    echo "${containers[@]}"
}

# Get pod services
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

# Show pod status
show_pod_status() {
    local pod_name="$1"

    log_info "Pod Status: $pod_name"
    echo ""

    # Get Docker Compose command
    local compose_cmd
    compose_cmd=$(check_docker_compose)

    # Get compose file
    local compose_file
    compose_file=$(get_pod_docker_compose "$pod_name")

    if [[ ! -f "docker/$compose_file" ]]; then
        log_error "Docker Compose file not found: docker/$compose_file"
        return 1
    fi

    cd docker

    # Show container status
    echo -e "${YELLOW}Container Status:${NC}"
    $compose_cmd -f "$compose_file" ps

    echo ""

    # Show resource usage
    echo -e "${YELLOW}Resource Usage:${NC}"
    local containers
    containers=$(get_pod_containers "$pod_name")

    for container in $containers; do
        if docker ps --format "table {{.Names}}" | grep -q "$container"; then
            echo -e "${CYAN}$container:${NC}"
            docker stats --no-stream --format "  CPU: {{.CPUPerc}}, Memory: {{.MemUsage}}, Network: {{.NetIO}}" "$container" 2>/dev/null || echo "  Stats unavailable"
        fi
    done

    cd ..
}

# Aggregate logs from pod services
show_aggregate_logs() {
    local pod_name="$1"

    log_info "Aggregated Logs: $pod_name Pod"
    echo ""

    # Get Docker Compose command
    local compose_cmd
    compose_cmd=$(check_docker_compose)

    # Get compose file
    local compose_file
    compose_file=$(get_pod_docker_compose "$pod_name")

    cd docker

    if [[ "$FOLLOW_LOGS" == "true" ]]; then
        log_info "Following logs (Ctrl+C to stop)..."
        $compose_cmd -f "$compose_file" logs -f --tail="$LOG_TAIL_LINES"
    else
        $compose_cmd -f "$compose_file" logs --tail="$LOG_TAIL_LINES"
    fi

    cd ..
}

# Show logs for specific service
show_service_logs() {
    local pod_name="$1"
    local service_name="$2"

    log_info "Service Logs: $service_name ($pod_name Pod)"
    echo ""

    # Get Docker Compose command
    local compose_cmd
    compose_cmd=$(check_docker_compose)

    # Get compose file
    local compose_file
    compose_file=$(get_pod_docker_compose "$pod_name")

    cd docker

    if [[ "$FOLLOW_LOGS" == "true" ]]; then
        log_info "Following logs (Ctrl+C to stop)..."
        $compose_cmd -f "$compose_file" logs -f --tail="$LOG_TAIL_LINES" "$service_name"
    else
        $compose_cmd -f "$compose_file" logs --tail="$LOG_TAIL_LINES" "$service_name"
    fi

    cd ..
}

# Test pod connectivity
test_pod_connectivity() {
    local pod_name="$1"

    log_info "Testing $pod_name Pod Connectivity"
    echo ""

    # Test internal service connectivity
    echo -e "${YELLOW}Internal Service Connectivity:${NC}"

    local services
    services=$(get_pod_services_detailed "$pod_name")

    for service_info in $services; do
        local service_name="${service_info%:*}"
        local service_port="${service_info#*:}"

        echo -ne "${CYAN}$service_name:${NC} "

        if check_service_health "http://localhost:$service_port/health" 5 1; then
            echo -e "${GREEN}✓ Healthy${NC}"
        else
            echo -e "${RED}✗ Unhealthy${NC}"

            # Test basic connectivity
            if check_port_available "$service_port"; then
                echo -e "  ${YELLOW}⚠ Port $service_port not listening${NC}"
            else
                echo -e "  ${GREEN}✓ Port $service_port is listening${NC}"
            fi
        fi
    done

    echo ""

    # Test inter-pod connectivity
    if [[ "$pod_name" != "all" ]]; then
        echo -e "${YELLOW}Inter-Pod Connectivity:${NC}"
        test_inter_pod_connectivity "$pod_name"
    fi

    echo ""

    # Test database connectivity
    echo -e "${YELLOW}Database Connectivity:${NC}"
    test_database_connectivity "$pod_name"
}

# Test inter-pod connectivity
test_inter_pod_connectivity() {
    local source_pod="$1"
    local target_pods=()

    case "$source_pod" in
        "core")
            target_pods=("business" "experience")
            ;;
        "business")
            target_pods=("core" "experience")
            ;;
        "experience")
            target_pods=("core" "business")
            ;;
    esac

    for target_pod in "${target_pods[@]}"; do
        echo -ne "${CYAN}$source_pod → $target_pod:${NC} "

        local target_services
        target_services=$(get_pod_services_detailed "$target_pod")

        local connectivity_success=true

        for service_info in $target_services; do
            local service_port="${service_info#*:}"

            if ! curl -f -s --max-time 5 "http://localhost:$service_port/health" >/dev/null 2>&1; then
                connectivity_success=false
                break
            fi
        done

        if [[ "$connectivity_success" == "true" ]]; then
            echo -e "${GREEN}✓ Connected${NC}"
        else
            echo -e "${RED}✗ Connection Failed${NC}"
        fi
    done
}

# Test database connectivity
test_database_connectivity() {
    local pod_name="$1"

    # Test MongoDB (used by core and business pods)
    if [[ "$pod_name" == "core" ]] || [[ "$pod_name" == "business" ]]; then
        echo -ne "${CYAN}MongoDB:${NC} "
        if command -v mongosh >/dev/null 2>&1; then
            if mongosh --quiet --eval "db.adminCommand('ping')" mongodb://localhost:27017 >/dev/null 2>&1; then
                echo -e "${GREEN}✓ Connected${NC}"
            else
                echo -e "${RED}✗ Connection Failed${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ mongosh not available${NC}"
        fi
    fi

    # Test Redis (used by all pods)
    echo -ne "${CYAN}Redis:${NC} "
    if command -v redis-cli >/dev/null 2>&1; then
        if redis-cli -h localhost -p 6379 ping >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Connected${NC}"
        else
            echo -e "${RED}✗ Connection Failed${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ redis-cli not available${NC}"
    fi

    # Test PostgreSQL (used by business pod)
    if [[ "$pod_name" == "business" ]]; then
        echo -ne "${CYAN}PostgreSQL:${NC} "
        if command -v psql >/dev/null 2>&1; then
            if PGPASSWORD=password123 psql -h localhost -p 5432 -U postgres -d dreamscape -c "SELECT 1;" >/dev/null 2>&1; then
                echo -e "${GREEN}✓ Connected${NC}"
            else
                echo -e "${RED}✗ Connection Failed${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ psql not available${NC}"
        fi
    fi
}

# Trace HTTP requests
trace_http_requests() {
    local pod_name="$1"

    log_info "Tracing HTTP Requests: $pod_name Pod"
    echo ""

    if ! command -v tcpdump >/dev/null 2>&1; then
        log_warning "tcpdump not available. Using alternative method..."
        trace_with_curl "$pod_name"
        return
    fi

    log_info "Starting HTTP traffic capture (Ctrl+C to stop)..."

    # Get pod service ports
    local services
    services=$(get_pod_services_detailed "$pod_name")

    local ports=()
    for service_info in $services; do
        local service_port="${service_info#*:}"
        ports+=("port $service_port")
    done

    local port_filter
    port_filter=$(IFS=" or "; echo "${ports[*]}")

    # Capture HTTP traffic
    sudo tcpdump -i lo -A -s 0 "tcp and ($port_filter)" 2>/dev/null || {
        log_warning "tcpdump failed. Trying without sudo..."
        tcpdump -i lo -A -s 0 "tcp and ($port_filter)" 2>/dev/null || {
            log_error "Traffic capture failed"
            return 1
        }
    }
}

# Alternative request tracing with curl
trace_with_curl() {
    local pod_name="$1"

    log_info "Testing HTTP endpoints with detailed tracing..."

    local services
    services=$(get_pod_services_detailed "$pod_name")

    for service_info in $services; do
        local service_name="${service_info%:*}"
        local service_port="${service_info#*:}"

        echo ""
        echo -e "${CYAN}=== $service_name Service ===${NC}"

        # Test health endpoint
        log_verbose "Testing health endpoint..."
        curl -v -s "http://localhost:$service_port/health" 2>&1 | head -20

        # Test basic endpoints if available
        case "$service_name" in
            "auth")
                echo ""
                log_verbose "Testing auth status..."
                curl -v -s "http://localhost:$service_port/api/v1/auth/status" 2>&1 | head -10
                ;;
            "user")
                echo ""
                log_verbose "Testing user status..."
                curl -v -s "http://localhost:$service_port/api/v1/users/status" 2>&1 | head -10
                ;;
        esac
    done
}

# Comprehensive health check
comprehensive_health_check() {
    local pod_name="$1"

    log_info "Comprehensive Health Check: $pod_name Pod"
    echo ""

    # Container health
    echo -e "${YELLOW}1. Container Health${NC}"
    show_pod_status "$pod_name"

    echo ""

    # Service health
    echo -e "${YELLOW}2. Service Health${NC}"
    test_pod_connectivity "$pod_name"

    echo ""

    # Configuration check
    echo -e "${YELLOW}3. Configuration Check${NC}"
    check_pod_configuration "$pod_name"

    echo ""

    # Performance metrics
    echo -e "${YELLOW}4. Performance Metrics${NC}"
    show_performance_metrics "$pod_name"
}

# Check pod configuration
check_pod_configuration() {
    local pod_name="$1"

    # Check environment variables
    echo -e "${CYAN}Environment Variables:${NC}"

    local compose_cmd
    compose_cmd=$(check_docker_compose)
    local compose_file
    compose_file=$(get_pod_docker_compose "$pod_name")

    cd docker

    # Get container name
    local container_name="${pod_name}-pod"

    if docker ps --format "{{.Names}}" | grep -q "$container_name"; then
        # Check critical environment variables
        local env_vars=("NODE_ENV" "DATABASE_URL" "REDIS_URL" "JWT_SECRET")

        for var in "${env_vars[@]}"; do
            local value
            value=$(docker exec "$container_name" printenv "$var" 2>/dev/null || echo "NOT_SET")

            if [[ "$value" == "NOT_SET" ]]; then
                echo -e "  ${RED}✗ $var: Not set${NC}"
            else
                # Mask sensitive values
                local masked_value="$value"
                if [[ "$var" == *"SECRET"* ]] || [[ "$var" == *"PASSWORD"* ]]; then
                    masked_value="***masked***"
                fi
                echo -e "  ${GREEN}✓ $var: $masked_value${NC}"
            fi
        done
    else
        log_warning "Container $container_name not running"
    fi

    cd ..

    echo ""

    # Check file permissions
    echo -e "${CYAN}File Permissions:${NC}"
    check_file_permissions "$pod_name"
}

# Check file permissions
check_file_permissions() {
    local pod_name="$1"

    local important_files=(
        "/app/package.json"
        "/app/dist"
        "/app/logs"
        "/tmp"
    )

    local container_name="${pod_name}-pod"

    if docker ps --format "{{.Names}}" | grep -q "$container_name"; then
        for file in "${important_files[@]}"; do
            if docker exec "$container_name" test -e "$file" 2>/dev/null; then
                local perms
                perms=$(docker exec "$container_name" stat -c "%a %n" "$file" 2>/dev/null)
                echo -e "  ${GREEN}✓ $perms${NC}"
            else
                echo -e "  ${YELLOW}⚠ $file: Not found${NC}"
            fi
        done
    fi
}

# Show performance metrics
show_performance_metrics() {
    local pod_name="$1"

    local containers
    containers=$(get_pod_containers "$pod_name")

    for container in $containers; do
        if docker ps --format "{{.Names}}" | grep -q "$container"; then
            echo -e "${CYAN}$container:${NC}"

            # CPU and Memory usage
            local stats
            stats=$(docker stats --no-stream --format "{{.CPUPerc}} {{.MemUsage}}" "$container" 2>/dev/null)

            if [[ -n "$stats" ]]; then
                local cpu_usage="${stats%% *}"
                local mem_usage="${stats#* }"

                echo -e "  CPU Usage: $cpu_usage"
                echo -e "  Memory Usage: $mem_usage"

                # Check for high resource usage
                local cpu_num="${cpu_usage%.*}"
                if [[ "$cpu_num" -gt 80 ]]; then
                    echo -e "  ${RED}⚠ High CPU usage${NC}"
                fi
            else
                echo -e "  ${YELLOW}Stats unavailable${NC}"
            fi

            # Network metrics
            local network_stats
            network_stats=$(docker stats --no-stream --format "{{.NetIO}}" "$container" 2>/dev/null)
            if [[ -n "$network_stats" ]]; then
                echo -e "  Network I/O: $network_stats"
            fi

            echo ""
        fi
    done
}

# Export debug information
export_debug_info() {
    local pod_name="$1"

    if [[ -z "$DEBUG_OUTPUT_DIR" ]]; then
        log_error "No output directory specified"
        return 1
    fi

    log_info "Exporting debug information to: $DEBUG_OUTPUT_DIR"

    ensure_directory "$DEBUG_OUTPUT_DIR"

    # Export logs
    log_info "Exporting logs..."
    mkdir -p "$DEBUG_OUTPUT_DIR/logs"

    local compose_cmd
    compose_cmd=$(check_docker_compose)
    local compose_file
    compose_file=$(get_pod_docker_compose "$pod_name")

    cd docker
    $compose_cmd -f "$compose_file" logs > "$DEBUG_OUTPUT_DIR/logs/${pod_name}-pod.log" 2>&1
    cd ..

    # Export container information
    log_info "Exporting container information..."
    mkdir -p "$DEBUG_OUTPUT_DIR/containers"

    local containers
    containers=$(get_pod_containers "$pod_name")

    for container in $containers; do
        if docker ps --format "{{.Names}}" | grep -q "$container"; then
            docker inspect "$container" > "$DEBUG_OUTPUT_DIR/containers/${container}.json" 2>/dev/null
            docker stats --no-stream "$container" > "$DEBUG_OUTPUT_DIR/containers/${container}-stats.txt" 2>/dev/null
        fi
    done

    # Export system information
    log_info "Exporting system information..."
    {
        echo "=== System Information ==="
        uname -a
        echo ""
        echo "=== Docker Version ==="
        docker version
        echo ""
        echo "=== Docker Compose Version ==="
        docker-compose version 2>/dev/null || docker compose version
        echo ""
        echo "=== Disk Usage ==="
        df -h
        echo ""
        echo "=== Memory Usage ==="
        free -h 2>/dev/null || vm_stat
        echo ""
        echo "=== Network Configuration ==="
        netstat -tuln 2>/dev/null || ss -tuln
    } > "$DEBUG_OUTPUT_DIR/system-info.txt"

    # Export configuration
    log_info "Exporting configuration..."
    cp "$CONFIG_FILE" "$DEBUG_OUTPUT_DIR/dreamscape-config.yml" 2>/dev/null || true

    # Create summary
    {
        echo "DreamScape Big Pods Debug Export"
        echo "================================"
        echo "Pod: $pod_name"
        echo "Timestamp: $(date)"
        echo "Export Directory: $DEBUG_OUTPUT_DIR"
        echo ""
        echo "Contents:"
        echo "- logs/${pod_name}-pod.log"
        echo "- containers/*.json (container inspect)"
        echo "- containers/*-stats.txt (container stats)"
        echo "- system-info.txt"
        echo "- dreamscape-config.yml"
    } > "$DEBUG_OUTPUT_DIR/README.txt"

    log_success "Debug information exported successfully"
    log_info "Archive location: $DEBUG_OUTPUT_DIR"
}

# Interactive debugging session
interactive_debug() {
    local pod_name="$1"

    log_info "Starting interactive debugging session for $pod_name Pod"
    echo ""

    while true; do
        echo -e "${BLUE}=== Debug Menu ===${NC}"
        echo "1. Show pod status"
        echo "2. Show aggregated logs"
        echo "3. Show service logs"
        echo "4. Test connectivity"
        echo "5. Trace HTTP requests"
        echo "6. Health check"
        echo "7. Performance metrics"
        echo "8. Connect to container"
        echo "9. Export debug info"
        echo "0. Exit"
        echo ""

        read -p "Select option [0-9]: " choice

        case $choice in
            1)
                show_pod_status "$pod_name"
                ;;
            2)
                show_aggregate_logs "$pod_name"
                ;;
            3)
                echo "Available services:"
                local services
                services=$(get_pod_services_detailed "$pod_name")
                for service_info in $services; do
                    local service_name="${service_info%:*}"
                    echo "  - $service_name"
                done
                read -p "Enter service name: " service_name
                show_service_logs "$pod_name" "$service_name"
                ;;
            4)
                test_pod_connectivity "$pod_name"
                ;;
            5)
                trace_http_requests "$pod_name"
                ;;
            6)
                comprehensive_health_check "$pod_name"
                ;;
            7)
                show_performance_metrics "$pod_name"
                ;;
            8)
                local container_name="${pod_name}-pod"
                log_info "Connecting to $container_name..."
                docker exec -it "$container_name" /bin/bash 2>/dev/null || docker exec -it "$container_name" /bin/sh
                ;;
            9)
                export_debug_info "$pod_name"
                ;;
            0)
                log_info "Exiting debug session"
                break
                ;;
            *)
                log_warning "Invalid option: $choice"
                ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
        echo ""
    done
}

# Main function
main() {
    # Initialize
    init_common

    echo -e "${BLUE}${MAGNIFY_ICON} DreamScape Big Pods - Debug Script${NC}"
    echo -e "${BLUE}Sophisticated debugging for Big Pods architecture${NC}"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Check prerequisites
    check_docker

    # If no pod specified, show all pods
    if [[ -z "$DEBUG_POD" ]]; then
        log_info "No specific pod selected. Showing all pods status:"
        echo ""

        for pod in "core" "business" "experience"; do
            echo -e "${YELLOW}=== $pod Pod ===${NC}"
            show_pod_status "$pod"
            echo ""
        done

        if [[ "$DEBUG_MODE" == "interactive" ]]; then
            echo "Select pod for detailed debugging:"
            echo "1. Core Pod"
            echo "2. Business Pod"
            echo "3. Experience Pod"
            read -p "Select [1-3]: " pod_choice

            case $pod_choice in
                1) DEBUG_POD="core" ;;
                2) DEBUG_POD="business" ;;
                3) DEBUG_POD="experience" ;;
                *) log_error "Invalid choice"; exit 1 ;;
            esac
        else
            exit 0
        fi
    fi

    # Execute debug mode
    case "$DEBUG_MODE" in
        "interactive")
            interactive_debug "$DEBUG_POD"
            ;;
        "logs")
            if [[ "$AGGREGATE_LOGS" == "true" ]]; then
                show_aggregate_logs "$DEBUG_POD"
            else
                show_aggregate_logs "$DEBUG_POD"
            fi
            ;;
        "connectivity")
            test_pod_connectivity "$DEBUG_POD"
            ;;
        "trace")
            trace_http_requests "$DEBUG_POD"
            ;;
        "health")
            comprehensive_health_check "$DEBUG_POD"
            ;;
        "performance")
            show_performance_metrics "$DEBUG_POD"
            ;;
        *)
            log_error "Unknown debug mode: $DEBUG_MODE"
            show_usage
            exit 1
            ;;
    esac

    # Export debug info if requested
    if [[ "$EXPORT_DEBUG_INFO" == "true" ]]; then
        export_debug_info "$DEBUG_POD"
    fi
}

# Execute main function
main "$@"