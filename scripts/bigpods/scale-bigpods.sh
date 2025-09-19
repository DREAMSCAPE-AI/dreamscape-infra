#!/bin/bash
# DreamScape Big Pods - Scaling Script
# Scaling intelligent par domaine métier avec auto-scaling et load testing

# Import common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Script-specific variables
SCALE_MODE="manual"
TARGET_REPLICAS=""
POD_TO_SCALE=""
AUTOSCALE_ENABLED=false
CPU_TARGET=70
MEMORY_TARGET=80
MIN_REPLICAS=1
MAX_REPLICAS=10
LOAD_TEST_ENABLED=false
LOAD_TEST_DURATION=300
LOAD_TEST_USERS=50

# Scaling configuration
SCALE_UP_THRESHOLD=80
SCALE_DOWN_THRESHOLD=30
COOLDOWN_PERIOD=300  # 5 minutes
MONITORING_INTERVAL=30

# Usage function
show_usage() {
    echo -e "${BLUE}📈 DreamScape Big Pods - Scaling Script${NC}"
    echo ""
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [OPTIONS] POD [REPLICAS]"
    echo ""
    echo -e "${WHITE}OPTIONS:${NC}"
    echo "  -m, --mode MODE        Scaling mode (manual, auto, load-test)"
    echo "  -r, --replicas N       Target number of replicas"
    echo "  -p, --pod POD          Pod to scale (core, business, experience)"
    echo "  --autoscale            Enable autoscaling"
    echo "  --cpu-target N         CPU target for autoscaling % (default: 70)"
    echo "  --memory-target N      Memory target for autoscaling % (default: 80)"
    echo "  --min-replicas N       Minimum replicas (default: 1)"
    echo "  --max-replicas N       Maximum replicas (default: 10)"
    echo "  --load-test            Run load test after scaling"
    echo "  --load-duration N      Load test duration in seconds (default: 300)"
    echo "  --load-users N         Number of concurrent users (default: 50)"
    echo "  --scale-up-threshold N Scale up threshold % (default: 80)"
    echo "  --scale-down-threshold N Scale down threshold % (default: 30)"
    echo "  --cooldown N           Cooldown period in seconds (default: 300)"
    echo "  --verbose              Verbose output"
    echo "  --debug                Debug output"
    echo "  -h, --help             Show this help"
    echo ""
    echo -e "${WHITE}SCALING MODES:${NC}"
    echo "  manual                 Manual scaling to specific replica count"
    echo "  auto                   Automatic scaling based on metrics"
    echo "  load-test              Load testing with scaling"
    echo "  optimize               Find optimal scaling configuration"
    echo ""
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo "  $0 core 5                    # Scale Core Pod to 5 replicas"
    echo "  $0 --mode auto business      # Enable autoscaling for Business Pod"
    echo "  $0 --load-test experience 3  # Scale and load test Experience Pod"
    echo "  $0 --mode optimize --load-test  # Find optimal scaling with load tests"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                SCALE_MODE="$2"
                shift 2
                ;;
            -r|--replicas)
                TARGET_REPLICAS="$2"
                shift 2
                ;;
            -p|--pod)
                if validate_pod_name "$2"; then
                    POD_TO_SCALE="$2"
                fi
                shift 2
                ;;
            --autoscale)
                AUTOSCALE_ENABLED=true
                SCALE_MODE="auto"
                shift
                ;;
            --cpu-target)
                CPU_TARGET="$2"
                shift 2
                ;;
            --memory-target)
                MEMORY_TARGET="$2"
                shift 2
                ;;
            --min-replicas)
                MIN_REPLICAS="$2"
                shift 2
                ;;
            --max-replicas)
                MAX_REPLICAS="$2"
                shift 2
                ;;
            --load-test)
                LOAD_TEST_ENABLED=true
                shift
                ;;
            --load-duration)
                LOAD_TEST_DURATION="$2"
                shift 2
                ;;
            --load-users)
                LOAD_TEST_USERS="$2"
                shift 2
                ;;
            --scale-up-threshold)
                SCALE_UP_THRESHOLD="$2"
                shift 2
                ;;
            --scale-down-threshold)
                SCALE_DOWN_THRESHOLD="$2"
                shift 2
                ;;
            --cooldown)
                COOLDOWN_PERIOD="$2"
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
                    POD_TO_SCALE="$1"
                fi
                shift
                ;;
            [0-9]*)
                TARGET_REPLICAS="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$POD_TO_SCALE" ]] && [[ "$SCALE_MODE" != "optimize" ]]; then
        log_error "Pod to scale is required"
        show_usage
        exit 1
    fi

    if [[ "$SCALE_MODE" == "manual" ]] && [[ -z "$TARGET_REPLICAS" ]]; then
        log_error "Target replicas required for manual scaling"
        show_usage
        exit 1
    fi

    log_debug "Scaling mode: $SCALE_MODE"
    log_debug "Pod to scale: $POD_TO_SCALE"
    log_debug "Target replicas: $TARGET_REPLICAS"
}

# Check scaling prerequisites
check_scaling_prerequisites() {
    log_info "Checking scaling prerequisites..."

    # Check Docker
    check_docker

    # Check Docker Compose
    local compose_cmd
    compose_cmd=$(check_docker_compose)
    log_success "Docker Compose available: $compose_cmd"

    # Check kubectl for Kubernetes scaling
    if kubectl version --client >/dev/null 2>&1; then
        log_success "kubectl available for Kubernetes scaling"
    else
        log_info "kubectl not available - Docker Compose scaling only"
    fi

    # Check load testing tools if needed
    if [[ "$LOAD_TEST_ENABLED" == "true" ]]; then
        if ! command -v curl >/dev/null 2>&1; then
            log_error "curl required for load testing"
            exit 1
        fi

        if command -v ab >/dev/null 2>&1; then
            log_success "Apache Bench available for load testing"
        elif command -v wrk >/dev/null 2>&1; then
            log_success "wrk available for load testing"
        else
            log_warning "No advanced load testing tools found - using curl"
        fi
    fi

    log_success "Scaling prerequisites validated"
}

# Get current replica count
get_current_replicas() {
    local pod_name="$1"

    # Try Kubernetes first
    if kubectl get deployments >/dev/null 2>&1; then
        local deployment_name="dreamscape-${pod_name}-pod"
        local replicas
        replicas=$(kubectl get deployment "$deployment_name" -o jsonpath='{.status.replicas}' 2>/dev/null || echo "")

        if [[ -n "$replicas" ]]; then
            echo "$replicas"
            return
        fi
    fi

    # Fallback to Docker Compose
    local compose_cmd
    compose_cmd=$(check_docker_compose)

    local compose_file
    compose_file=$(get_pod_docker_compose "$pod_name")

    if [[ -f "docker/$compose_file" ]]; then
        cd docker
        local running_containers
        running_containers=$($compose_cmd -f "$compose_file" ps -q "${pod_name}-pod" | wc -l)
        cd ..
        echo "$running_containers"
    else
        echo "1"  # Default to 1 if unknown
    fi
}

# Scale pod manually
scale_pod_manual() {
    local pod_name="$1"
    local target_replicas="$2"

    log_info "Scaling $pod_name pod to $target_replicas replicas..."

    local current_replicas
    current_replicas=$(get_current_replicas "$pod_name")

    log_info "Current replicas: $current_replicas, Target: $target_replicas"

    if [[ "$current_replicas" -eq "$target_replicas" ]]; then
        log_info "$pod_name pod already at target scale"
        return 0
    fi

    # Try Kubernetes scaling first
    if kubectl get deployments >/dev/null 2>&1; then
        if scale_kubernetes "$pod_name" "$target_replicas"; then
            return 0
        fi
    fi

    # Fallback to Docker Compose scaling
    scale_docker_compose "$pod_name" "$target_replicas"
}

# Scale using Kubernetes
scale_kubernetes() {
    local pod_name="$1"
    local target_replicas="$2"

    local deployment_name="dreamscape-${pod_name}-pod"

    log_verbose "Scaling Kubernetes deployment: $deployment_name"

    if kubectl scale deployment "$deployment_name" --replicas="$target_replicas"; then
        log_info "Waiting for scaling to complete..."

        # Wait for rollout
        if kubectl rollout status deployment/"$deployment_name" --timeout=300s; then
            log_success "$pod_name pod scaled to $target_replicas replicas"
            return 0
        else
            log_error "Scaling timeout for $pod_name pod"
            return 1
        fi
    else
        log_error "Failed to scale $pod_name pod with Kubernetes"
        return 1
    fi
}

# Scale using Docker Compose
scale_docker_compose() {
    local pod_name="$1"
    local target_replicas="$2"

    local compose_cmd
    compose_cmd=$(check_docker_compose)

    local compose_file
    compose_file=$(get_pod_docker_compose "$pod_name")

    if [[ ! -f "docker/$compose_file" ]]; then
        log_error "Docker Compose file not found: docker/$compose_file"
        return 1
    fi

    cd docker

    log_verbose "Scaling Docker Compose service: ${pod_name}-pod"

    if $compose_cmd -f "$compose_file" up -d --scale "${pod_name}-pod=$target_replicas"; then
        # Wait for containers to be ready
        log_info "Waiting for containers to be ready..."
        sleep 10

        # Verify scaling
        local actual_replicas
        actual_replicas=$($compose_cmd -f "$compose_file" ps -q "${pod_name}-pod" | wc -l)

        if [[ "$actual_replicas" -eq "$target_replicas" ]]; then
            log_success "$pod_name pod scaled to $target_replicas replicas"
            cd ..
            return 0
        else
            log_error "Scaling verification failed: expected $target_replicas, got $actual_replicas"
            cd ..
            return 1
        fi
    else
        log_error "Failed to scale $pod_name pod with Docker Compose"
        cd ..
        return 1
    fi
}

# Get pod metrics for autoscaling
get_pod_metrics() {
    local pod_name="$1"

    local cpu_usage=0
    local memory_usage=0
    local container_count=0

    # Get container metrics
    local containers
    case "$pod_name" in
        "core")
            containers=("core-pod" "mongodb" "redis")
            ;;
        "business")
            containers=("business-pod" "postgresql")
            ;;
        "experience")
            containers=("experience-pod" "nginx")
            ;;
    esac

    for container in "${containers[@]}"; do
        if docker ps --format "{{.Names}}" | grep -q "^${container}"; then
            local stats
            stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemPerc}}" "$container" 2>/dev/null || echo "0%,0%")

            local cpu_perc="${stats%,*}"
            local mem_perc="${stats#*,}"

            # Remove % sign and convert to number
            cpu_perc="${cpu_perc%.*}"
            mem_perc="${mem_perc%.*}"

            cpu_usage=$((cpu_usage + ${cpu_perc%\%}))
            memory_usage=$((memory_usage + ${mem_perc%\%}))
            container_count=$((container_count + 1))
        fi
    done

    # Calculate averages
    if [[ $container_count -gt 0 ]]; then
        cpu_usage=$((cpu_usage / container_count))
        memory_usage=$((memory_usage / container_count))
    fi

    echo "cpu:$cpu_usage,memory:$memory_usage"
}

# Autoscaling logic
autoscale_pod() {
    local pod_name="$1"

    log_info "Starting autoscaling for $pod_name pod..."
    log_info "Targets: CPU ${CPU_TARGET}%, Memory ${MEMORY_TARGET}%"
    log_info "Range: ${MIN_REPLICAS}-${MAX_REPLICAS} replicas"

    local last_scale_time=0

    while true; do
        local current_time
        current_time=$(date +%s)

        # Get current metrics
        local metrics
        metrics=$(get_pod_metrics "$pod_name")

        IFS=',' read -r cpu_metric memory_metric <<< "$metrics"
        local cpu_usage="${cpu_metric#*:}"
        local memory_usage="${memory_metric#*:}"

        log_verbose "Current metrics - CPU: ${cpu_usage}%, Memory: ${memory_usage}%"

        # Get current replicas
        local current_replicas
        current_replicas=$(get_current_replicas "$pod_name")

        local should_scale=false
        local target_replicas=$current_replicas

        # Check if we need to scale up
        if [[ $cpu_usage -gt $SCALE_UP_THRESHOLD ]] || [[ $memory_usage -gt $SCALE_UP_THRESHOLD ]]; then
            if [[ $current_replicas -lt $MAX_REPLICAS ]]; then
                target_replicas=$((current_replicas + 1))
                should_scale=true
                log_info "High resource usage detected - scaling up to $target_replicas"
            fi
        # Check if we can scale down
        elif [[ $cpu_usage -lt $SCALE_DOWN_THRESHOLD ]] && [[ $memory_usage -lt $SCALE_DOWN_THRESHOLD ]]; then
            if [[ $current_replicas -gt $MIN_REPLICAS ]]; then
                target_replicas=$((current_replicas - 1))
                should_scale=true
                log_info "Low resource usage detected - scaling down to $target_replicas"
            fi
        fi

        # Apply cooldown period
        if [[ $should_scale == "true" ]]; then
            local time_since_last_scale=$((current_time - last_scale_time))

            if [[ $time_since_last_scale -lt $COOLDOWN_PERIOD ]]; then
                log_verbose "Cooldown period active - skipping scaling"
            else
                if scale_pod_manual "$pod_name" "$target_replicas"; then
                    last_scale_time=$current_time
                    log_success "Autoscaling completed: $current_replicas → $target_replicas replicas"
                else
                    log_error "Autoscaling failed"
                fi
            fi
        fi

        sleep "$MONITORING_INTERVAL"
    done
}

# Run load test
run_load_test() {
    local pod_name="$1"
    local target_url=""

    # Determine service URL for load testing
    case "$pod_name" in
        "core")
            target_url="http://localhost:3001/health"
            ;;
        "business")
            target_url="http://localhost:3003/health"
            ;;
        "experience")
            target_url="http://localhost:3006/health"
            ;;
    esac

    log_info "Running load test on $pod_name pod..."
    log_info "Target URL: $target_url"
    log_info "Duration: ${LOAD_TEST_DURATION}s, Users: $LOAD_TEST_USERS"

    # Use Apache Bench if available
    if command -v ab >/dev/null 2>&1; then
        run_apache_bench_test "$target_url"
    # Use wrk if available
    elif command -v wrk >/dev/null 2>&1; then
        run_wrk_test "$target_url"
    # Fallback to curl-based test
    else
        run_curl_based_test "$target_url"
    fi
}

# Apache Bench load test
run_apache_bench_test() {
    local target_url="$1"

    local total_requests=$((LOAD_TEST_USERS * LOAD_TEST_DURATION / 10))

    log_info "Running Apache Bench test..."

    ab -n "$total_requests" -c "$LOAD_TEST_USERS" -t "$LOAD_TEST_DURATION" "$target_url" > "/tmp/load_test_results.txt" 2>&1

    # Parse results
    local requests_per_second
    requests_per_second=$(grep "Requests per second" "/tmp/load_test_results.txt" | awk '{print $4}' || echo "N/A")

    local avg_response_time
    avg_response_time=$(grep "Time per request.*mean" "/tmp/load_test_results.txt" | head -1 | awk '{print $4}' || echo "N/A")

    local failed_requests
    failed_requests=$(grep "Failed requests" "/tmp/load_test_results.txt" | awk '{print $3}' || echo "N/A")

    log_success "Load test completed!"
    echo "  • Requests per second: $requests_per_second"
    echo "  • Average response time: ${avg_response_time}ms"
    echo "  • Failed requests: $failed_requests"
}

# wrk load test
run_wrk_test() {
    local target_url="$1"

    log_info "Running wrk test..."

    wrk -t"$LOAD_TEST_USERS" -c"$LOAD_TEST_USERS" -d"${LOAD_TEST_DURATION}s" "$target_url" > "/tmp/load_test_results.txt" 2>&1

    # Parse results
    local requests_per_second
    requests_per_second=$(grep "Requests/sec" "/tmp/load_test_results.txt" | awk '{print $2}' || echo "N/A")

    local avg_latency
    avg_latency=$(grep "Latency" "/tmp/load_test_results.txt" | awk '{print $2}' || echo "N/A")

    log_success "Load test completed!"
    echo "  • Requests per second: $requests_per_second"
    echo "  • Average latency: $avg_latency"
}

# Simple curl-based load test
run_curl_based_test() {
    local target_url="$1"

    log_info "Running curl-based load test..."

    local success_count=0
    local total_requests=0
    local total_time=0

    local start_time
    start_time=$(date +%s)

    while [[ $(($(date +%s) - start_time)) -lt $LOAD_TEST_DURATION ]]; do
        for ((i=1; i<=LOAD_TEST_USERS; i++)); do
            total_requests=$((total_requests + 1))

            local request_start
            request_start=$(date +%s%3N)

            if curl -f -s --max-time 5 "$target_url" >/dev/null 2>&1; then
                success_count=$((success_count + 1))
            fi

            local request_end
            request_end=$(date +%s%3N)
            local request_time=$((request_end - request_start))
            total_time=$((total_time + request_time))

            # Brief pause to avoid overwhelming
            sleep 0.1
        done

        sleep 1
    done

    local success_rate=0
    local avg_response_time=0

    if [[ $total_requests -gt 0 ]]; then
        success_rate=$((success_count * 100 / total_requests))
        avg_response_time=$((total_time / total_requests))
    fi

    log_success "Load test completed!"
    echo "  • Total requests: $total_requests"
    echo "  • Success rate: ${success_rate}%"
    echo "  • Average response time: ${avg_response_time}ms"
}

# Optimize scaling configuration
optimize_scaling() {
    log_info "Finding optimal scaling configuration..."

    local pods_to_test=("core" "business" "experience")
    local replica_counts=(1 2 3 5)

    local optimization_results=()

    for pod_name in "${pods_to_test[@]}"; do
        log_info "Optimizing $pod_name pod..."

        for replicas in "${replica_counts[@]}"; do
            log_info "Testing $pod_name pod with $replicas replicas..."

            # Scale to test configuration
            if scale_pod_manual "$pod_name" "$replicas"; then
                # Wait for scaling to stabilize
                sleep 30

                # Run load test
                LOAD_TEST_ENABLED=true
                run_load_test "$pod_name"

                # Collect metrics
                local metrics
                metrics=$(get_pod_metrics "$pod_name")

                IFS=',' read -r cpu_metric memory_metric <<< "$metrics"
                local cpu_usage="${cpu_metric#*:}"
                local memory_usage="${memory_metric#*:}"

                optimization_results+=("$pod_name:$replicas:$cpu_usage:$memory_usage")

                log_info "Results - CPU: ${cpu_usage}%, Memory: ${memory_usage}%"
            else
                log_error "Failed to scale $pod_name to $replicas replicas"
            fi

            # Brief pause between tests
            sleep 10
        done
    done

    # Analyze results and provide recommendations
    log_success "Optimization completed!"
    echo ""
    echo "Recommendations:"

    for result in "${optimization_results[@]}"; do
        IFS=':' read -r pod replicas cpu memory <<< "$result"

        echo "  • $pod pod: $replicas replicas (CPU: ${cpu}%, Memory: ${memory}%)"

        if [[ $cpu -lt 50 ]] && [[ $memory -lt 50 ]]; then
            echo "    → Consider reducing to save resources"
        elif [[ $cpu -gt 80 ]] || [[ $memory -gt 80 ]]; then
            echo "    → Consider increasing for better performance"
        else
            echo "    → Optimal configuration"
        fi
    done
}

# Main function
main() {
    # Initialize
    init_common

    echo -e "${BLUE}📈 DreamScape Big Pods - Scaling Script${NC}"
    echo -e "${BLUE}Intelligent scaling for Big Pods architecture${NC}"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Check prerequisites
    check_scaling_prerequisites

    # Show scaling plan
    case "$SCALE_MODE" in
        "manual")
            log_info "Manual Scaling Plan:"
            echo -e "  • Pod: $POD_TO_SCALE"
            echo -e "  • Target replicas: $TARGET_REPLICAS"
            ;;
        "auto")
            log_info "Autoscaling Plan:"
            echo -e "  • Pod: $POD_TO_SCALE"
            echo -e "  • CPU target: ${CPU_TARGET}%"
            echo -e "  • Memory target: ${MEMORY_TARGET}%"
            echo -e "  • Replica range: ${MIN_REPLICAS}-${MAX_REPLICAS}"
            ;;
        "optimize")
            log_info "Optimization Plan:"
            echo -e "  • Testing all pods with different replica counts"
            echo -e "  • Load testing enabled"
            ;;
    esac

    if [[ "$LOAD_TEST_ENABLED" == "true" ]]; then
        echo -e "  • Load test: ${LOAD_TEST_DURATION}s with ${LOAD_TEST_USERS} users"
    fi

    echo ""

    # Confirm scaling
    if ! confirm_action "Proceed with scaling operation?" "y"; then
        log_info "Scaling cancelled by user"
        exit 0
    fi

    # Execute scaling based on mode
    case "$SCALE_MODE" in
        "manual")
            scale_pod_manual "$POD_TO_SCALE" "$TARGET_REPLICAS"

            if [[ "$LOAD_TEST_ENABLED" == "true" ]]; then
                sleep 30  # Wait for scaling to stabilize
                run_load_test "$POD_TO_SCALE"
            fi
            ;;
        "auto")
            autoscale_pod "$POD_TO_SCALE"
            ;;
        "load-test")
            if [[ -n "$TARGET_REPLICAS" ]]; then
                scale_pod_manual "$POD_TO_SCALE" "$TARGET_REPLICAS"
                sleep 30
            fi
            run_load_test "$POD_TO_SCALE"
            ;;
        "optimize")
            optimize_scaling
            ;;
        *)
            log_error "Unknown scaling mode: $SCALE_MODE"
            exit 1
            ;;
    esac

    log_success "Scaling operation completed!"
}

# Execute main function
main "$@"