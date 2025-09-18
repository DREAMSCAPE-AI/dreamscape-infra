#!/bin/bash
# DreamScape Big Pods - Monitoring Script
# Monitoring temps réel Big Pods avec métriques et alertes

# Import common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Script-specific variables
MONITORING_MODE="dashboard"
REFRESH_INTERVAL=5
METRICS_DURATION=300  # 5 minutes
ALERT_THRESHOLD_CPU=80
ALERT_THRESHOLD_MEMORY=85
ALERT_THRESHOLD_DISK=90
EXPORT_METRICS=false
METRICS_FORMAT="prometheus"
WEBHOOK_URL=""
CONTINUOUS_MODE=false

# Monitoring configuration
METRICS_HISTORY_SIZE=100
DASHBOARD_ROWS=25
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000

# Usage function
show_usage() {
    echo -e "${BLUE}📊 DreamScape Big Pods - Monitoring Script${NC}"
    echo ""
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [OPTIONS] [POD]"
    echo ""
    echo -e "${WHITE}OPTIONS:${NC}"
    echo "  -m, --mode MODE        Monitoring mode (dashboard, metrics, alerts, health)"
    echo "  -i, --interval N       Refresh interval in seconds (default: 5)"
    echo "  -d, --duration N       Metrics collection duration in seconds (default: 300)"
    echo "  -p, --pod POD          Monitor specific pod only"
    echo "  --cpu-threshold N      CPU alert threshold % (default: 80)"
    echo "  --memory-threshold N   Memory alert threshold % (default: 85)"
    echo "  --disk-threshold N     Disk alert threshold % (default: 90)"
    echo "  --export FORMAT        Export metrics (prometheus, json, csv)"
    echo "  --webhook URL          Webhook URL for alerts"
    echo "  --continuous           Run continuously until stopped"
    echo "  --prometheus-port N    Prometheus port (default: 9090)"
    echo "  --grafana-port N       Grafana port (default: 3000)"
    echo "  --verbose              Verbose output"
    echo "  --debug                Debug output"
    echo "  -h, --help             Show this help"
    echo ""
    echo -e "${WHITE}MONITORING MODES:${NC}"
    echo "  dashboard              Real-time monitoring dashboard"
    echo "  metrics                Collect and display metrics"
    echo "  alerts                 Check and display alerts"
    echo "  health                 Health check dashboard"
    echo "  performance            Performance analysis"
    echo "  network                Network monitoring"
    echo ""
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo "  $0                            # Start monitoring dashboard"
    echo "  $0 --mode metrics core        # Collect metrics for Core Pod"
    echo "  $0 --mode alerts --continuous # Continuous alerting"
    echo "  $0 --export prometheus        # Export metrics to Prometheus format"
}

# Parse command line arguments
parse_args() {
    local pods_to_monitor=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                MONITORING_MODE="$2"
                shift 2
                ;;
            -i|--interval)
                REFRESH_INTERVAL="$2"
                shift 2
                ;;
            -d|--duration)
                METRICS_DURATION="$2"
                shift 2
                ;;
            -p|--pod)
                if validate_pod_name "$2"; then
                    pods_to_monitor+=("$2")
                fi
                shift 2
                ;;
            --cpu-threshold)
                ALERT_THRESHOLD_CPU="$2"
                shift 2
                ;;
            --memory-threshold)
                ALERT_THRESHOLD_MEMORY="$2"
                shift 2
                ;;
            --disk-threshold)
                ALERT_THRESHOLD_DISK="$2"
                shift 2
                ;;
            --export)
                EXPORT_METRICS=true
                METRICS_FORMAT="$2"
                shift 2
                ;;
            --webhook)
                WEBHOOK_URL="$2"
                shift 2
                ;;
            --continuous)
                CONTINUOUS_MODE=true
                shift
                ;;
            --prometheus-port)
                PROMETHEUS_PORT="$2"
                shift 2
                ;;
            --grafana-port)
                GRAFANA_PORT="$2"
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
                    pods_to_monitor+=("$1")
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

    # Set pods to monitor
    if [[ ${#pods_to_monitor[@]} -gt 0 ]]; then
        PODS_TO_MONITOR=("${pods_to_monitor[@]}")
    else
        PODS_TO_MONITOR=("core" "business" "experience")
    fi

    log_debug "Monitoring mode: $MONITORING_MODE"
    log_debug "Pods to monitor: ${PODS_TO_MONITOR[*]}"
}

# Get system metrics
get_system_metrics() {
    local metrics=""

    # CPU usage
    local cpu_usage
    if command -v top >/dev/null 2>&1; then
        cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' || echo "0")
    elif command -v vmstat >/dev/null 2>&1; then
        cpu_usage=$(vmstat 1 2 | tail -1 | awk '{print 100-$15}' || echo "0")
    else
        cpu_usage="N/A"
    fi

    # Memory usage
    local memory_usage
    if command -v free >/dev/null 2>&1; then
        memory_usage=$(free | grep Mem | awk '{printf("%.1f", $3/$2 * 100.0)}')
    else
        memory_usage="N/A"
    fi

    # Disk usage
    local disk_usage
    if command -v df >/dev/null 2>&1; then
        disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    else
        disk_usage="N/A"
    fi

    # Load average
    local load_avg
    if command -v uptime >/dev/null 2>&1; then
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ *//')
    else
        load_avg="N/A"
    fi

    echo "cpu:$cpu_usage,memory:$memory_usage,disk:$disk_usage,load:$load_avg"
}

# Get container metrics
get_container_metrics() {
    local container_name="$1"

    if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        echo "status:stopped"
        return
    fi

    # Get container stats
    local stats
    stats=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}}" "$container_name" 2>/dev/null)

    if [[ -n "$stats" ]]; then
        IFS=',' read -r cpu_perc mem_usage mem_perc net_io block_io <<< "$stats"

        # Clean up values
        cpu_perc="${cpu_perc%.*}"  # Remove decimal part
        mem_perc="${mem_perc%.*}"

        echo "status:running,cpu:${cpu_perc%\%},memory:${mem_perc%\%},net_io:$net_io,block_io:$block_io"
    else
        echo "status:unknown"
    fi
}

# Get pod health status
get_pod_health() {
    local pod_name="$1"

    local services
    case "$pod_name" in
        "core")
            services="auth:3001 user:3002"
            ;;
        "business")
            services="voyage:3003 payment:3004 ai:3005"
            ;;
        "experience")
            services="panorama:3006 web-client:5173 gateway:3000"
            ;;
    esac

    local healthy_services=0
    local total_services=0

    for service_info in $services; do
        local service_name="${service_info%:*}"
        local service_port="${service_info#*:}"
        local health_url="http://localhost:$service_port/health"

        total_services=$((total_services + 1))

        if check_service_health "$health_url" 3 1; then
            healthy_services=$((healthy_services + 1))
        fi
    done

    local health_percentage=0
    if [[ $total_services -gt 0 ]]; then
        health_percentage=$((healthy_services * 100 / total_services))
    fi

    echo "healthy:$healthy_services,total:$total_services,percentage:$health_percentage"
}

# Display monitoring dashboard
show_monitoring_dashboard() {
    while true; do
        # Clear screen and show header
        clear
        echo -e "${BLUE}📊 DreamScape Big Pods - Live Monitoring Dashboard${NC}"
        echo -e "${BLUE}Refresh: ${REFRESH_INTERVAL}s | $(date)${NC}"
        echo "=================================================================="

        # System overview
        echo ""
        echo -e "${YELLOW}🖥️ System Overview${NC}"
        echo "-------------------"

        local system_metrics
        system_metrics=$(get_system_metrics)

        IFS=',' read -r cpu_metric memory_metric disk_metric load_metric <<< "$system_metrics"

        local cpu_value="${cpu_metric#*:}"
        local memory_value="${memory_metric#*:}"
        local disk_value="${disk_metric#*:}"
        local load_value="${load_metric#*:}"

        printf "%-15s %s\n" "CPU Usage:" "${cpu_value}%"
        printf "%-15s %s\n" "Memory Usage:" "${memory_value}%"
        printf "%-15s %s\n" "Disk Usage:" "${disk_value}%"
        printf "%-15s %s\n" "Load Average:" "$load_value"

        # Pod monitoring
        for pod_name in "${PODS_TO_MONITOR[@]}"; do
            echo ""
            echo -e "${CYAN}🏗️ $pod_name Pod${NC}"
            echo "$(printf '%.0s-' {1..20})"

            # Container metrics
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
                local container_metrics
                container_metrics=$(get_container_metrics "$container")

                IFS=',' read -r status_metric cpu_metric memory_metric net_metric block_metric <<< "$container_metrics"

                local status="${status_metric#*:}"
                local cpu="${cpu_metric#*:}"
                local memory="${memory_metric#*:}"

                printf "%-15s " "$container:"

                case "$status" in
                    "running")
                        echo -e "${GREEN}●${NC} Running | CPU: ${cpu}% | Mem: ${memory}%"
                        ;;
                    "stopped")
                        echo -e "${RED}●${NC} Stopped"
                        ;;
                    *)
                        echo -e "${YELLOW}●${NC} Unknown"
                        ;;
                esac
            done

            # Health status
            local health_metrics
            health_metrics=$(get_pod_health "$pod_name")

            IFS=',' read -r healthy_metric total_metric percentage_metric <<< "$health_metrics"

            local healthy="${healthy_metric#*:}"
            local total="${total_metric#*:}"
            local percentage="${percentage_metric#*:}"

            printf "%-15s " "Health:"
            if [[ $percentage -eq 100 ]]; then
                echo -e "${GREEN}●${NC} All services healthy ($healthy/$total)"
            elif [[ $percentage -ge 50 ]]; then
                echo -e "${YELLOW}●${NC} Partially healthy ($healthy/$total)"
            else
                echo -e "${RED}●${NC} Unhealthy ($healthy/$total)"
            fi
        done

        # Alerts section
        echo ""
        echo -e "${YELLOW}⚠️ Active Alerts${NC}"
        echo "----------------"

        local alerts_found=false

        # Check CPU alerts
        if [[ "$cpu_value" != "N/A" ]] && [[ "${cpu_value%.*}" -gt $ALERT_THRESHOLD_CPU ]]; then
            echo -e "${RED}🚨 High CPU usage: ${cpu_value}%${NC}"
            alerts_found=true
        fi

        # Check memory alerts
        if [[ "$memory_value" != "N/A" ]] && [[ "${memory_value%.*}" -gt $ALERT_THRESHOLD_MEMORY ]]; then
            echo -e "${RED}🚨 High memory usage: ${memory_value}%${NC}"
            alerts_found=true
        fi

        # Check disk alerts
        if [[ "$disk_value" != "N/A" ]] && [[ "$disk_value" -gt $ALERT_THRESHOLD_DISK ]]; then
            echo -e "${RED}🚨 High disk usage: ${disk_value}%${NC}"
            alerts_found=true
        fi

        # Check for unhealthy pods
        for pod_name in "${PODS_TO_MONITOR[@]}"; do
            local health_metrics
            health_metrics=$(get_pod_health "$pod_name")
            local percentage="${health_metrics##*:}"

            if [[ $percentage -lt 100 ]]; then
                echo -e "${YELLOW}⚠️ $pod_name pod partially healthy: ${percentage}%${NC}"
                alerts_found=true
            fi
        done

        if [[ "$alerts_found" == "false" ]]; then
            echo -e "${GREEN}✅ No active alerts${NC}"
        fi

        # Footer
        echo ""
        echo "=================================================================="
        echo -e "${BLUE}Press Ctrl+C to stop monitoring${NC}"

        # Break if not continuous mode
        if [[ "$CONTINUOUS_MODE" != "true" ]]; then
            break
        fi

        # Wait for refresh interval
        sleep "$REFRESH_INTERVAL"
    done
}

# Collect detailed metrics
collect_metrics() {
    log_info "Collecting metrics for ${METRICS_DURATION}s..."

    local metrics_file="/tmp/dreamscape_metrics_$(date +%Y%m%d_%H%M%S).json"
    local start_time
    start_time=$(date +%s)

    {
        echo "{"
        echo "  \"collection_start\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"duration_seconds\": $METRICS_DURATION,"
        echo "  \"interval_seconds\": $REFRESH_INTERVAL,"
        echo "  \"pods\": ["

        local first_pod=true
        for pod_name in "${PODS_TO_MONITOR[@]}"; do
            if [[ "$first_pod" == "false" ]]; then
                echo "    ,"
            fi
            first_pod=false

            echo "    {"
            echo "      \"name\": \"$pod_name\","
            echo "      \"metrics\": ["

            local first_metric=true
            local iteration=0
            while [[ $(($(date +%s) - start_time)) -lt $METRICS_DURATION ]]; do
                if [[ "$first_metric" == "false" ]]; then
                    echo "        ,"
                fi
                first_metric=false

                echo "        {"
                echo "          \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","

                # System metrics
                local system_metrics
                system_metrics=$(get_system_metrics)
                echo "          \"system\": {"
                IFS=',' read -r cpu_metric memory_metric disk_metric load_metric <<< "$system_metrics"
                echo "            \"cpu_percent\": \"${cpu_metric#*:}\","
                echo "            \"memory_percent\": \"${memory_metric#*:}\","
                echo "            \"disk_percent\": \"${disk_metric#*:}\","
                echo "            \"load_average\": \"${load_metric#*:}\""
                echo "          },"

                # Container metrics
                echo "          \"containers\": {"
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

                local first_container=true
                for container in "${containers[@]}"; do
                    if [[ "$first_container" == "false" ]]; then
                        echo "            ,"
                    fi
                    first_container=false

                    local container_metrics
                    container_metrics=$(get_container_metrics "$container")

                    echo "            \"$container\": {"
                    IFS=',' read -r status_metric cpu_metric memory_metric net_metric block_metric <<< "$container_metrics"
                    echo "              \"status\": \"${status_metric#*:}\","
                    echo "              \"cpu_percent\": \"${cpu_metric#*:}\","
                    echo "              \"memory_percent\": \"${memory_metric#*:}\","
                    echo "              \"network_io\": \"${net_metric#*:}\","
                    echo "              \"block_io\": \"${block_metric#*:}\""
                    echo "            }"
                done

                echo "          },"

                # Health metrics
                local health_metrics
                health_metrics=$(get_pod_health "$pod_name")
                echo "          \"health\": {"
                IFS=',' read -r healthy_metric total_metric percentage_metric <<< "$health_metrics"
                echo "            \"healthy_services\": \"${healthy_metric#*:}\","
                echo "            \"total_services\": \"${total_metric#*:}\","
                echo "            \"health_percentage\": \"${percentage_metric#*:}\""
                echo "          }"

                echo "        }"

                iteration=$((iteration + 1))
                echo -ne "\rCollecting metrics... ${iteration} samples"

                sleep "$REFRESH_INTERVAL"
            done

            echo ""
            echo "      ]"
            echo "    }"
        done

        echo "  ],"
        echo "  \"collection_end\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
        echo "}"
    } > "$metrics_file"

    echo ""
    log_success "Metrics collected: $metrics_file"

    # Export if requested
    if [[ "$EXPORT_METRICS" == "true" ]]; then
        export_metrics_format "$metrics_file"
    fi
}

# Export metrics to different formats
export_metrics_format() {
    local input_file="$1"

    case "$METRICS_FORMAT" in
        "prometheus")
            convert_to_prometheus "$input_file"
            ;;
        "csv")
            convert_to_csv "$input_file"
            ;;
        "json")
            log_info "Metrics already in JSON format: $input_file"
            ;;
        *)
            log_error "Unsupported metrics format: $METRICS_FORMAT"
            ;;
    esac
}

# Convert metrics to Prometheus format
convert_to_prometheus() {
    local input_file="$1"
    local output_file="${input_file%.json}.prom"

    log_info "Converting to Prometheus format..."

    {
        echo "# HELP dreamscape_pod_cpu_percent CPU usage percentage for DreamScape pods"
        echo "# TYPE dreamscape_pod_cpu_percent gauge"
        echo "# HELP dreamscape_pod_memory_percent Memory usage percentage for DreamScape pods"
        echo "# TYPE dreamscape_pod_memory_percent gauge"
        echo "# HELP dreamscape_pod_health_percentage Health percentage for DreamScape pods"
        echo "# TYPE dreamscape_pod_health_percentage gauge"

        # Parse JSON and convert (simplified conversion)
        # In a real implementation, you'd use jq or a proper JSON parser
        grep -o '"cpu_percent": "[^"]*"' "$input_file" | head -10 | while read -r line; do
            local value
            value=$(echo "$line" | sed 's/.*": "//; s/".*//')
            if [[ "$value" != "N/A" ]]; then
                echo "dreamscape_system_cpu_percent $value"
            fi
        done

    } > "$output_file"

    log_success "Prometheus metrics exported: $output_file"
}

# Convert metrics to CSV format
convert_to_csv() {
    local input_file="$1"
    local output_file="${input_file%.json}.csv"

    log_info "Converting to CSV format..."

    {
        echo "timestamp,pod,metric_type,metric_name,value"

        # Simplified CSV conversion
        # In a real implementation, you'd use jq for proper JSON parsing
        echo "# CSV conversion not fully implemented - placeholder"

    } > "$output_file"

    log_success "CSV metrics exported: $output_file"
}

# Check and display alerts
check_alerts() {
    log_info "Checking for alerts..."

    local alerts_found=false
    local alert_messages=()

    # System alerts
    local system_metrics
    system_metrics=$(get_system_metrics)

    IFS=',' read -r cpu_metric memory_metric disk_metric load_metric <<< "$system_metrics"

    local cpu_value="${cpu_metric#*:}"
    local memory_value="${memory_metric#*:}"
    local disk_value="${disk_metric#*:}"

    # CPU alert
    if [[ "$cpu_value" != "N/A" ]] && [[ "${cpu_value%.*}" -gt $ALERT_THRESHOLD_CPU ]]; then
        alert_messages+=("CRITICAL: High CPU usage: ${cpu_value}%")
        alerts_found=true
    fi

    # Memory alert
    if [[ "$memory_value" != "N/A" ]] && [[ "${memory_value%.*}" -gt $ALERT_THRESHOLD_MEMORY ]]; then
        alert_messages+=("CRITICAL: High memory usage: ${memory_value}%")
        alerts_found=true
    fi

    # Disk alert
    if [[ "$disk_value" != "N/A" ]] && [[ "$disk_value" -gt $ALERT_THRESHOLD_DISK ]]; then
        alert_messages+=("CRITICAL: High disk usage: ${disk_value}%")
        alerts_found=true
    fi

    # Pod health alerts
    for pod_name in "${PODS_TO_MONITOR[@]}"; do
        local health_metrics
        health_metrics=$(get_pod_health "$pod_name")
        local percentage="${health_metrics##*:}"

        if [[ $percentage -lt 100 ]]; then
            alert_messages+=("WARNING: $pod_name pod unhealthy: ${percentage}%")
            alerts_found=true
        fi
    done

    # Display alerts
    if [[ "$alerts_found" == "true" ]]; then
        echo -e "${RED}🚨 Active Alerts:${NC}"
        for alert in "${alert_messages[@]}"; do
            echo "  • $alert"
        done

        # Send webhook notification if configured
        if [[ -n "$WEBHOOK_URL" ]]; then
            send_webhook_alert "${alert_messages[@]}"
        fi
    else
        echo -e "${GREEN}✅ No alerts detected${NC}"
    fi

    # Run continuously if requested
    if [[ "$CONTINUOUS_MODE" == "true" ]]; then
        sleep "$REFRESH_INTERVAL"
        check_alerts
    fi
}

# Send webhook alert
send_webhook_alert() {
    local alerts=("$@")

    log_debug "Sending webhook alert to: $WEBHOOK_URL"

    local alert_text=""
    for alert in "${alerts[@]}"; do
        alert_text="${alert_text}${alert}\n"
    done

    local payload=$(cat <<EOF
{
    "text": "DreamScape Big Pods Alert",
    "attachments": [
        {
            "color": "danger",
            "title": "Big Pods Monitoring Alert",
            "text": "$alert_text",
            "timestamp": $(date +%s)
        }
    ]
}
EOF
    )

    curl -X POST \
         -H 'Content-type: application/json' \
         --data "$payload" \
         "$WEBHOOK_URL" >/dev/null 2>&1 || log_debug "Webhook notification failed"
}

# Show health check dashboard
show_health_dashboard() {
    log_info "Health Check Dashboard"
    echo ""

    for pod_name in "${PODS_TO_MONITOR[@]}"; do
        echo -e "${CYAN}🏗️ $pod_name Pod Health${NC}"
        echo "$(printf '%.0s-' {1..30})"

        # Service health
        local services
        case "$pod_name" in
            "core")
                services="auth:3001 user:3002"
                ;;
            "business")
                services="voyage:3003 payment:3004 ai:3005"
                ;;
            "experience")
                services="panorama:3006 web-client:5173 gateway:3000"
                ;;
        esac

        for service_info in $services; do
            local service_name="${service_info%:*}"
            local service_port="${service_info#*:}"
            local health_url="http://localhost:$service_port/health"

            printf "%-15s " "$service_name:"

            if check_service_health "$health_url" 5 1; then
                echo -e "${GREEN}✅ Healthy${NC}"
            else
                echo -e "${RED}❌ Unhealthy${NC}"
            fi
        done

        # Container health
        echo ""
        echo "Containers:"

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
            printf "%-15s " "$container:"

            if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
                echo -e "${GREEN}✅ Running${NC}"
            else
                echo -e "${RED}❌ Stopped${NC}"
            fi
        done

        echo ""
    done
}

# Main function
main() {
    # Initialize
    init_common

    echo -e "${BLUE}📊 DreamScape Big Pods - Monitoring${NC}"
    echo -e "${BLUE}Real-time monitoring for Big Pods architecture${NC}"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Check Docker
    check_docker

    # Execute based on mode
    case "$MONITORING_MODE" in
        "dashboard")
            show_monitoring_dashboard
            ;;
        "metrics")
            collect_metrics
            ;;
        "alerts")
            check_alerts
            ;;
        "health")
            show_health_dashboard
            ;;
        "performance")
            log_info "Performance analysis mode not yet implemented"
            ;;
        "network")
            log_info "Network monitoring mode not yet implemented"
            ;;
        *)
            log_error "Unknown monitoring mode: $MONITORING_MODE"
            show_usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"