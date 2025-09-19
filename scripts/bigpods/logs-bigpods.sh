#!/bin/bash
# DreamScape Big Pods - Logs Management Script
# Gestion logs centralisée par Big Pod avec filtering et recherche

# Import common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Script-specific variables
LOG_MODE="tail"
POD_FILTER=""
SERVICE_FILTER=""
FOLLOW_LOGS=false
LOG_LINES=100
SEARCH_PATTERN=""
TIME_FILTER=""
LOG_LEVEL_FILTER=""
EXPORT_FORMAT="text"
EXPORT_FILE=""
AGGREGATE_LOGS=false
COLORIZE_OUTPUT=true

# Usage function
show_usage() {
    echo -e "${BLUE}📋 DreamScape Big Pods - Logs Management Script${NC}"
    echo ""
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [OPTIONS] [POD] [SERVICE]"
    echo ""
    echo -e "${WHITE}OPTIONS:${NC}"
    echo "  -m, --mode MODE        Log mode (tail, search, export, stats)"
    echo "  -p, --pod POD          Filter by pod (core, business, experience)"
    echo "  -s, --service SERVICE  Filter by service name"
    echo "  -f, --follow           Follow logs in real-time"
    echo "  -n, --lines N          Number of lines to show (default: 100)"
    echo "  --search PATTERN       Search for pattern in logs"
    echo "  --since TIME           Show logs since time (1h, 30m, 2006-01-02T15:04:05)"
    echo "  --until TIME           Show logs until time"
    echo "  --level LEVEL          Filter by log level (debug, info, warn, error)"
    echo "  -a, --aggregate        Aggregate logs from all services"
    echo "  --export FORMAT        Export format (text, json, csv)"
    echo "  -o, --output FILE      Export to file"
    echo "  --no-color             Disable colorized output"
    echo "  --timestamps           Show timestamps"
    echo "  --verbose              Verbose output"
    echo "  --debug                Debug output"
    echo "  -h, --help             Show this help"
    echo ""
    echo -e "${WHITE}LOG MODES:${NC}"
    echo "  tail                   Show recent logs (default)"
    echo "  search                 Search through historical logs"
    echo "  export                 Export logs to file"
    echo "  stats                  Show log statistics"
    echo "  monitor                Real-time monitoring dashboard"
    echo ""
    echo -e "${WHITE}TIME FORMATS:${NC}"
    echo "  Relative: 1h, 30m, 24h, 7d"
    echo "  Absolute: 2023-12-01T10:00:00, 2023-12-01 10:00:00"
    echo ""
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo "  $0 --follow core                    # Follow Core Pod logs"
    echo "  $0 --search \"error\" --since 1h     # Search errors in last hour"
    echo "  $0 --pod business --level error     # Show business pod errors"
    echo "  $0 --export json -o /tmp/logs.json  # Export all logs to JSON"
    echo "  $0 --mode stats --since 24h         # Log statistics for last 24h"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                LOG_MODE="$2"
                shift 2
                ;;
            -p|--pod)
                if validate_pod_name "$2"; then
                    POD_FILTER="$2"
                fi
                shift 2
                ;;
            -s|--service)
                SERVICE_FILTER="$2"
                shift 2
                ;;
            -f|--follow)
                FOLLOW_LOGS=true
                shift
                ;;
            -n|--lines)
                LOG_LINES="$2"
                shift 2
                ;;
            --search)
                SEARCH_PATTERN="$2"
                LOG_MODE="search"
                shift 2
                ;;
            --since)
                TIME_FILTER="--since $2"
                shift 2
                ;;
            --until)
                TIME_FILTER="$TIME_FILTER --until $2"
                shift 2
                ;;
            --level)
                LOG_LEVEL_FILTER="$2"
                shift 2
                ;;
            -a|--aggregate)
                AGGREGATE_LOGS=true
                shift
                ;;
            --export)
                EXPORT_FORMAT="$2"
                LOG_MODE="export"
                shift 2
                ;;
            -o|--output)
                EXPORT_FILE="$2"
                shift 2
                ;;
            --no-color)
                COLORIZE_OUTPUT=false
                shift
                ;;
            --timestamps)
                SHOW_TIMESTAMPS=true
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
                    POD_FILTER="$1"
                fi
                shift
                ;;
            *)
                # Assume it's a service name if not recognized
                if [[ -z "$SERVICE_FILTER" ]]; then
                    SERVICE_FILTER="$1"
                else
                    log_error "Unknown option: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done

    log_debug "Log mode: $LOG_MODE"
    log_debug "Pod filter: ${POD_FILTER:-all}"
    log_debug "Service filter: ${SERVICE_FILTER:-all}"
}

# Get containers for filtering
get_containers_for_pod() {
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
            # Get all DreamScape containers
            containers=($(docker ps --format "{{.Names}}" | grep -E "(dreamscape|core-pod|business-pod|experience-pod|mongodb|redis|postgresql|nginx)" || echo ""))
            ;;
    esac

    echo "${containers[@]}"
}

# Get services for filtering
get_services_for_pod() {
    local pod_name="$1"

    case "$pod_name" in
        "core")
            echo "auth user"
            ;;
        "business")
            echo "voyage payment ai"
            ;;
        "experience")
            echo "panorama web-client gateway"
            ;;
        *)
            echo "auth user voyage payment ai panorama web-client gateway"
            ;;
    esac
}

# Colorize log output
colorize_log_line() {
    local line="$1"

    if [[ "$COLORIZE_OUTPUT" != "true" ]]; then
        echo "$line"
        return
    fi

    # Color by log level
    if echo "$line" | grep -qi "error"; then
        echo -e "${RED}$line${NC}"
    elif echo "$line" | grep -qi "warn"; then
        echo -e "${YELLOW}$line${NC}"
    elif echo "$line" | grep -qi "info"; then
        echo -e "${BLUE}$line${NC}"
    elif echo "$line" | grep -qi "debug"; then
        echo -e "${PURPLE}$line${NC}"
    elif echo "$line" | grep -qi "success"; then
        echo -e "${GREEN}$line${NC}"
    else
        echo "$line"
    fi
}

# Filter logs by level
filter_by_log_level() {
    local level="$1"

    case "$level" in
        "error")
            grep -i "error\|fatal\|critical"
            ;;
        "warn")
            grep -i "warn\|warning"
            ;;
        "info")
            grep -i "info"
            ;;
        "debug")
            grep -i "debug\|trace"
            ;;
        *)
            cat
            ;;
    esac
}

# Show pod logs in tail mode
show_pod_logs_tail() {
    local pod_name="${POD_FILTER:-all}"

    log_info "Showing logs for $pod_name pod (last $LOG_LINES lines)"

    if [[ "$AGGREGATE_LOGS" == "true" ]]; then
        show_aggregated_logs "$pod_name"
    else
        show_individual_logs "$pod_name"
    fi
}

# Show aggregated logs
show_aggregated_logs() {
    local pod_name="$1"

    local containers
    containers=($(get_containers_for_pod "$pod_name"))

    if [[ ${#containers[@]} -eq 0 ]]; then
        log_error "No containers found for pod: $pod_name"
        return 1
    fi

    log_verbose "Aggregating logs from containers: ${containers[*]}"

    # Get Docker Compose command
    local compose_cmd
    compose_cmd=$(check_docker_compose)

    # Determine compose file
    local compose_file=""
    case "$pod_name" in
        "core")
            compose_file="docker-compose.core-pod.yml"
            ;;
        "business")
            compose_file="docker-compose.business-pod.yml"
            ;;
        "experience")
            compose_file="docker-compose.experience-pod.yml"
            ;;
    esac

    if [[ -n "$compose_file" ]] && [[ -f "docker/$compose_file" ]]; then
        cd docker

        local compose_options="--tail=$LOG_LINES"
        if [[ "$FOLLOW_LOGS" == "true" ]]; then
            compose_options="$compose_options -f"
        fi

        if [[ -n "$TIME_FILTER" ]]; then
            compose_options="$compose_options $TIME_FILTER"
        fi

        log_verbose "Docker Compose command: $compose_cmd -f $compose_file logs $compose_options"

        $compose_cmd -f "$compose_file" logs $compose_options 2>/dev/null | \
        while IFS= read -r line; do
            # Apply service filter if specified
            if [[ -n "$SERVICE_FILTER" ]] && ! echo "$line" | grep -q "$SERVICE_FILTER"; then
                continue
            fi

            # Apply log level filter if specified
            if [[ -n "$LOG_LEVEL_FILTER" ]]; then
                if ! echo "$line" | filter_by_log_level "$LOG_LEVEL_FILTER" >/dev/null; then
                    continue
                fi
            fi

            colorize_log_line "$line"
        done

        cd ..
    else
        # Fallback to individual container logs
        show_individual_logs "$pod_name"
    fi
}

# Show individual container logs
show_individual_logs() {
    local pod_name="$1"

    local containers
    containers=($(get_containers_for_pod "$pod_name"))

    if [[ ${#containers[@]} -eq 0 ]]; then
        log_error "No containers found for pod: $pod_name"
        return 1
    fi

    for container in "${containers[@]}"; do
        if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            log_warning "Container not running: $container"
            continue
        fi

        echo -e "${CYAN}=== $container ===${NC}"

        local docker_options="--tail $LOG_LINES"
        if [[ "$FOLLOW_LOGS" == "true" ]]; then
            docker_options="$docker_options -f"
        fi

        if [[ -n "$TIME_FILTER" ]]; then
            docker_options="$docker_options $TIME_FILTER"
        fi

        docker logs $docker_options "$container" 2>&1 | \
        while IFS= read -r line; do
            # Apply service filter if specified
            if [[ -n "$SERVICE_FILTER" ]] && ! echo "$line" | grep -q "$SERVICE_FILTER"; then
                continue
            fi

            # Apply log level filter if specified
            if [[ -n "$LOG_LEVEL_FILTER" ]]; then
                if ! echo "$line" | filter_by_log_level "$LOG_LEVEL_FILTER" >/dev/null; then
                    continue
                fi
            fi

            colorize_log_line "$line"
        done

        echo ""
    done
}

# Search through logs
search_logs() {
    if [[ -z "$SEARCH_PATTERN" ]]; then
        log_error "Search pattern is required"
        return 1
    fi

    log_info "Searching for pattern: '$SEARCH_PATTERN'"

    local pod_name="${POD_FILTER:-all}"
    local containers
    containers=($(get_containers_for_pod "$pod_name"))

    local search_results=()

    for container in "${containers[@]}"; do
        if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            continue
        fi

        log_verbose "Searching in container: $container"

        local docker_options=""
        if [[ -n "$TIME_FILTER" ]]; then
            docker_options="$TIME_FILTER"
        fi

        local results
        results=$(docker logs $docker_options "$container" 2>&1 | \
                 grep -i "$SEARCH_PATTERN" | \
                 head -100)  # Limit results per container

        if [[ -n "$results" ]]; then
            echo -e "${CYAN}=== $container ===${NC}"
            while IFS= read -r line; do
                # Highlight search pattern
                if [[ "$COLORIZE_OUTPUT" == "true" ]]; then
                    highlighted_line=$(echo "$line" | sed "s/$SEARCH_PATTERN/${YELLOW}&${NC}/gi")
                    colorize_log_line "$highlighted_line"
                else
                    echo "$line"
                fi
            done <<< "$results"
            echo ""

            search_results+=("$container")
        fi
    done

    if [[ ${#search_results[@]} -eq 0 ]]; then
        log_info "No matches found for pattern: '$SEARCH_PATTERN'"
    else
        log_success "Pattern found in ${#search_results[@]} container(s): ${search_results[*]}"
    fi
}

# Export logs
export_logs() {
    log_info "Exporting logs in $EXPORT_FORMAT format..."

    local pod_name="${POD_FILTER:-all}"
    local containers
    containers=($(get_containers_for_pod "$pod_name"))

    local output_file="${EXPORT_FILE:-/tmp/dreamscape-logs-$(date +%Y%m%d_%H%M%S).$EXPORT_FORMAT}"

    case "$EXPORT_FORMAT" in
        "json")
            export_logs_json "$output_file" "${containers[@]}"
            ;;
        "csv")
            export_logs_csv "$output_file" "${containers[@]}"
            ;;
        "text")
            export_logs_text "$output_file" "${containers[@]}"
            ;;
        *)
            log_error "Unsupported export format: $EXPORT_FORMAT"
            return 1
            ;;
    esac

    log_success "Logs exported to: $output_file"
}

# Export logs as JSON
export_logs_json() {
    local output_file="$1"
    shift
    local containers=("$@")

    {
        echo "{"
        echo "  \"export_timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"pod_filter\": \"${POD_FILTER:-all}\","
        echo "  \"service_filter\": \"${SERVICE_FILTER:-all}\","
        echo "  \"containers\": ["

        local first_container=true
        for container in "${containers[@]}"; do
            if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
                continue
            fi

            if [[ "$first_container" == "false" ]]; then
                echo "    ,"
            fi
            first_container=false

            echo "    {"
            echo "      \"name\": \"$container\","
            echo "      \"logs\": ["

            local docker_options="--tail $LOG_LINES"
            if [[ -n "$TIME_FILTER" ]]; then
                docker_options="$docker_options $TIME_FILTER"
            fi

            local first_log=true
            docker logs $docker_options "$container" 2>&1 | \
            while IFS= read -r line; do
                # Apply filters
                if [[ -n "$SERVICE_FILTER" ]] && ! echo "$line" | grep -q "$SERVICE_FILTER"; then
                    continue
                fi

                if [[ -n "$LOG_LEVEL_FILTER" ]]; then
                    if ! echo "$line" | filter_by_log_level "$LOG_LEVEL_FILTER" >/dev/null; then
                        continue
                    fi
                fi

                if [[ "$first_log" == "false" ]]; then
                    echo "        ,"
                fi
                first_log=false

                # Escape JSON
                local escaped_line
                escaped_line=$(echo "$line" | sed 's/\\/\\\\/g; s/"/\\"/g')
                echo "        \"$escaped_line\""
            done

            echo "      ]"
            echo "    }"
        done

        echo "  ]"
        echo "}"
    } > "$output_file"
}

# Export logs as CSV
export_logs_csv() {
    local output_file="$1"
    shift
    local containers=("$@")

    {
        echo "timestamp,container,level,message"

        for container in "${containers[@]}"; do
            if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
                continue
            fi

            local docker_options="--tail $LOG_LINES --timestamps"
            if [[ -n "$TIME_FILTER" ]]; then
                docker_options="$docker_options $TIME_FILTER"
            fi

            docker logs $docker_options "$container" 2>&1 | \
            while IFS= read -r line; do
                # Apply filters
                if [[ -n "$SERVICE_FILTER" ]] && ! echo "$line" | grep -q "$SERVICE_FILTER"; then
                    continue
                fi

                if [[ -n "$LOG_LEVEL_FILTER" ]]; then
                    if ! echo "$line" | filter_by_log_level "$LOG_LEVEL_FILTER" >/dev/null; then
                        continue
                    fi
                fi

                # Extract timestamp and message
                local timestamp=""
                local message="$line"

                if [[ "$line" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+Z)\ (.*)$ ]]; then
                    timestamp="${BASH_REMATCH[1]}"
                    message="${BASH_REMATCH[2]}"
                fi

                # Detect log level
                local level="info"
                if echo "$message" | grep -qi "error"; then
                    level="error"
                elif echo "$message" | grep -qi "warn"; then
                    level="warn"
                elif echo "$message" | grep -qi "debug"; then
                    level="debug"
                fi

                # Escape CSV
                message=$(echo "$message" | sed 's/"/""/g')

                echo "\"$timestamp\",\"$container\",\"$level\",\"$message\""
            done
        done
    } > "$output_file"
}

# Export logs as text
export_logs_text() {
    local output_file="$1"
    shift
    local containers=("$@")

    {
        echo "DreamScape Big Pods Logs Export"
        echo "==============================="
        echo "Export Time: $(date)"
        echo "Pod Filter: ${POD_FILTER:-all}"
        echo "Service Filter: ${SERVICE_FILTER:-all}"
        echo "Log Level Filter: ${LOG_LEVEL_FILTER:-all}"
        echo ""

        for container in "${containers[@]}"; do
            if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
                continue
            fi

            echo "=== $container ==="

            local docker_options="--tail $LOG_LINES"
            if [[ -n "$TIME_FILTER" ]]; then
                docker_options="$docker_options $TIME_FILTER"
            fi

            docker logs $docker_options "$container" 2>&1 | \
            while IFS= read -r line; do
                # Apply filters
                if [[ -n "$SERVICE_FILTER" ]] && ! echo "$line" | grep -q "$SERVICE_FILTER"; then
                    continue
                fi

                if [[ -n "$LOG_LEVEL_FILTER" ]]; then
                    if ! echo "$line" | filter_by_log_level "$LOG_LEVEL_FILTER" >/dev/null; then
                        continue
                    fi
                fi

                echo "$line"
            done

            echo ""
        done
    } > "$output_file"
}

# Show log statistics
show_log_stats() {
    log_info "Generating log statistics..."

    local pod_name="${POD_FILTER:-all}"
    local containers
    containers=($(get_containers_for_pod "$pod_name"))

    local total_lines=0
    local error_count=0
    local warn_count=0
    local info_count=0
    local debug_count=0

    echo -e "${YELLOW}Log Statistics${NC}"
    echo "=============="
    echo ""

    for container in "${containers[@]}"; do
        if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
            continue
        fi

        local docker_options="--tail $LOG_LINES"
        if [[ -n "$TIME_FILTER" ]]; then
            docker_options="$docker_options $TIME_FILTER"
        fi

        local container_logs
        container_logs=$(docker logs $docker_options "$container" 2>&1)

        local container_lines
        container_lines=$(echo "$container_logs" | wc -l)

        local container_errors
        container_errors=$(echo "$container_logs" | grep -ci "error\|fatal\|critical" || echo "0")

        local container_warns
        container_warns=$(echo "$container_logs" | grep -ci "warn\|warning" || echo "0")

        local container_infos
        container_infos=$(echo "$container_logs" | grep -ci "info" || echo "0")

        local container_debugs
        container_debugs=$(echo "$container_logs" | grep -ci "debug\|trace" || echo "0")

        echo -e "${CYAN}$container:${NC}"
        echo "  Total lines: $container_lines"
        echo "  Errors: $container_errors"
        echo "  Warnings: $container_warns"
        echo "  Info: $container_infos"
        echo "  Debug: $container_debugs"
        echo ""

        total_lines=$((total_lines + container_lines))
        error_count=$((error_count + container_errors))
        warn_count=$((warn_count + container_warns))
        info_count=$((info_count + container_infos))
        debug_count=$((debug_count + container_debugs))
    done

    echo -e "${WHITE}Total Summary:${NC}"
    echo "  Total lines: $total_lines"
    echo "  Errors: $error_count"
    echo "  Warnings: $warn_count"
    echo "  Info: $info_count"
    echo "  Debug: $debug_count"

    # Calculate percentages
    if [[ $total_lines -gt 0 ]]; then
        local error_pct=$((error_count * 100 / total_lines))
        local warn_pct=$((warn_count * 100 / total_lines))

        echo ""
        echo -e "${WHITE}Analysis:${NC}"

        if [[ $error_pct -gt 5 ]]; then
            echo -e "  ${RED}⚠️ High error rate: ${error_pct}%${NC}"
        elif [[ $error_pct -gt 1 ]]; then
            echo -e "  ${YELLOW}⚠️ Moderate error rate: ${error_pct}%${NC}"
        else
            echo -e "  ${GREEN}✅ Low error rate: ${error_pct}%${NC}"
        fi

        if [[ $warn_pct -gt 10 ]]; then
            echo -e "  ${YELLOW}⚠️ High warning rate: ${warn_pct}%${NC}"
        else
            echo -e "  ${GREEN}✅ Normal warning rate: ${warn_pct}%${NC}"
        fi
    fi
}

# Real-time monitoring dashboard
monitor_logs() {
    log_info "Starting real-time log monitoring (Ctrl+C to stop)..."

    local pod_name="${POD_FILTER:-all}"

    # Clear screen and show header
    clear
    echo -e "${BLUE}🖥️ DreamScape Big Pods - Live Log Monitor${NC}"
    echo -e "${BLUE}Pod: $pod_name | Service: ${SERVICE_FILTER:-all} | Level: ${LOG_LEVEL_FILTER:-all}${NC}"
    echo "$(date)"
    echo "================================================"
    echo ""

    # Start following logs with continuous updates
    FOLLOW_LOGS=true
    LOG_LINES=50

    show_aggregated_logs "$pod_name"
}

# Main function
main() {
    # Initialize
    init_common

    echo -e "${BLUE}📋 DreamScape Big Pods - Logs Management${NC}"
    echo -e "${BLUE}Centralized logging for Big Pods architecture${NC}"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Check Docker
    check_docker

    # Execute based on mode
    case "$LOG_MODE" in
        "tail")
            show_pod_logs_tail
            ;;
        "search")
            search_logs
            ;;
        "export")
            export_logs
            ;;
        "stats")
            show_log_stats
            ;;
        "monitor")
            monitor_logs
            ;;
        *)
            log_error "Unknown log mode: $LOG_MODE"
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"