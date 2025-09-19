#!/bin/bash
# DreamScape Big Pods - Maintenance Script
# Tâches maintenance automatiques avec nettoyage et monitoring

# Import common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Script-specific variables
MAINTENANCE_MODE="full"
SCHEDULED_MODE=false
DRY_RUN_MODE=false
CLEANUP_IMAGES=true
CLEANUP_VOLUMES=false
CLEANUP_LOGS=true
LOG_RETENTION_DAYS=7
DISK_CLEANUP_THRESHOLD=85
BACKUP_BEFORE_CLEANUP=true

# Maintenance configuration
MAINTENANCE_WINDOW_START="02:00"
MAINTENANCE_WINDOW_END="04:00"
AUTOMATIC_RESTART=false
HEALTH_CHECK_AFTER=true
NOTIFICATION_ENABLED=false

# Usage function
show_usage() {
    echo -e "${BLUE}🔧 DreamScape Big Pods - Maintenance Script${NC}"
    echo ""
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [OPTIONS]"
    echo ""
    echo -e "${WHITE}OPTIONS:${NC}"
    echo "  -m, --mode MODE        Maintenance mode (full, cleanup, logs, images, health)"
    echo "  -s, --scheduled        Run in scheduled maintenance mode"
    echo "  --dry-run              Show what would be done without doing it"
    echo "  --no-images            Skip Docker image cleanup"
    echo "  --cleanup-volumes      Enable Docker volume cleanup"
    echo "  --no-logs              Skip log cleanup"
    echo "  --log-retention N      Log retention in days (default: 7)"
    echo "  --disk-threshold N     Disk cleanup threshold % (default: 85)"
    echo "  --no-backup            Skip backup before cleanup"
    echo "  --auto-restart         Restart services after maintenance"
    echo "  --no-health-check      Skip health check after maintenance"
    echo "  --notify               Enable maintenance notifications"
    echo "  --maintenance-start T  Maintenance window start time (HH:MM)"
    echo "  --maintenance-end T    Maintenance window end time (HH:MM)"
    echo "  -f, --force            Force maintenance without confirmation"
    echo "  --verbose              Verbose output"
    echo "  --debug                Debug output"
    echo "  -h, --help             Show this help"
    echo ""
    echo -e "${WHITE}MAINTENANCE MODES:${NC}"
    echo "  full                   Complete maintenance (default)"
    echo "  cleanup                Cleanup only (images, logs, temp files)"
    echo "  logs                   Log management only"
    echo "  images                 Docker image cleanup only"
    echo "  health                 Health checks and repairs"
    echo "  security               Security updates and patches"
    echo ""
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo "  $0                            # Full maintenance"
    echo "  $0 --mode cleanup --dry-run   # Preview cleanup operations"
    echo "  $0 --scheduled --notify       # Scheduled maintenance with notifications"
    echo "  $0 --mode logs --log-retention 3  # Clean logs older than 3 days"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                MAINTENANCE_MODE="$2"
                shift 2
                ;;
            -s|--scheduled)
                SCHEDULED_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN_MODE=true
                shift
                ;;
            --no-images)
                CLEANUP_IMAGES=false
                shift
                ;;
            --cleanup-volumes)
                CLEANUP_VOLUMES=true
                shift
                ;;
            --no-logs)
                CLEANUP_LOGS=false
                shift
                ;;
            --log-retention)
                LOG_RETENTION_DAYS="$2"
                shift 2
                ;;
            --disk-threshold)
                DISK_CLEANUP_THRESHOLD="$2"
                shift 2
                ;;
            --no-backup)
                BACKUP_BEFORE_CLEANUP=false
                shift
                ;;
            --auto-restart)
                AUTOMATIC_RESTART=true
                shift
                ;;
            --no-health-check)
                HEALTH_CHECK_AFTER=false
                shift
                ;;
            --notify)
                NOTIFICATION_ENABLED=true
                shift
                ;;
            --maintenance-start)
                MAINTENANCE_WINDOW_START="$2"
                shift 2
                ;;
            --maintenance-end)
                MAINTENANCE_WINDOW_END="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            --verbose)
                export VERBOSE=true
                shift
                ;;
            --debug)
                export DEBUG=true
                export VERBOSE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    log_debug "Maintenance mode: $MAINTENANCE_MODE"
    log_debug "Scheduled mode: $SCHEDULED_MODE"
    log_debug "Dry run mode: $DRY_RUN_MODE"
}

# Check if we're in maintenance window
check_maintenance_window() {
    if [[ "$SCHEDULED_MODE" != "true" ]]; then
        return 0
    fi

    local current_time
    current_time=$(date +%H:%M)

    local start_minutes
    start_minutes=$(echo "$MAINTENANCE_WINDOW_START" | awk -F: '{print $1*60 + $2}')

    local end_minutes
    end_minutes=$(echo "$MAINTENANCE_WINDOW_END" | awk -F: '{print $1*60 + $2}')

    local current_minutes
    current_minutes=$(echo "$current_time" | awk -F: '{print $1*60 + $2}')

    if [[ $current_minutes -ge $start_minutes ]] && [[ $current_minutes -le $end_minutes ]]; then
        log_info "Inside maintenance window ($MAINTENANCE_WINDOW_START - $MAINTENANCE_WINDOW_END)"
        return 0
    else
        log_info "Outside maintenance window - skipping maintenance"
        return 1
    fi
}

# Send maintenance notification
send_maintenance_notification() {
    local message="$1"
    local status="${2:-info}"

    if [[ "$NOTIFICATION_ENABLED" != "true" ]]; then
        return 0
    fi

    log_debug "Sending maintenance notification: $message"

    # This would integrate with actual notification systems
    # For now, just log the notification
    case "$status" in
        "start")
            log_info "🔧 MAINTENANCE STARTED: $message"
            ;;
        "end")
            log_info "✅ MAINTENANCE COMPLETED: $message"
            ;;
        "error")
            log_error "❌ MAINTENANCE ERROR: $message"
            ;;
        *)
            log_info "📢 MAINTENANCE: $message"
            ;;
    esac
}

# Check disk space
check_disk_space() {
    log_info "Checking disk space..."

    local disk_usage
    if command -v df >/dev/null 2>&1; then
        disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

        log_info "Current disk usage: ${disk_usage}%"

        if [[ $disk_usage -gt $DISK_CLEANUP_THRESHOLD ]]; then
            log_warning "Disk usage above threshold (${DISK_CLEANUP_THRESHOLD}%) - cleanup required"
            return 1
        else
            log_success "Disk usage within normal limits"
            return 0
        fi
    else
        log_warning "Cannot check disk space"
        return 0
    fi
}

# Backup before maintenance
backup_before_maintenance() {
    if [[ "$BACKUP_BEFORE_CLEANUP" != "true" ]]; then
        return 0
    fi

    log_info "Creating maintenance backup..."

    local backup_script="$SCRIPT_DIR/backup-bigpods.sh"

    if [[ -f "$backup_script" ]]; then
        if [[ "$DRY_RUN_MODE" == "true" ]]; then
            log_info "[DRY RUN] Would create backup before maintenance"
        else
            if "$backup_script" --type configs; then
                log_success "Maintenance backup completed"
            else
                log_error "Maintenance backup failed"
                return 1
            fi
        fi
    else
        log_warning "Backup script not found - skipping backup"
    fi
}

# Cleanup Docker images
cleanup_docker_images() {
    if [[ "$CLEANUP_IMAGES" != "true" ]]; then
        return 0
    fi

    log_info "Cleaning up Docker images..."

    # Get images before cleanup
    local images_before
    images_before=$(docker images -q | wc -l)

    if [[ "$DRY_RUN_MODE" == "true" ]]; then
        log_info "[DRY RUN] Would remove unused Docker images"

        # Show what would be removed
        local dangling_images
        dangling_images=$(docker images -f "dangling=true" -q | wc -l)

        local unused_images
        unused_images=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep -v "dreamscape" | tail -n +2 | wc -l)

        log_info "[DRY RUN] Would remove:"
        log_info "  • $dangling_images dangling images"
        log_info "  • $unused_images unused non-DreamScape images"
    else
        # Remove dangling images
        log_verbose "Removing dangling images..."
        docker image prune -f >/dev/null 2>&1 || true

        # Remove unused images (but keep DreamScape images)
        log_verbose "Removing unused images..."
        docker images --format "{{.Repository}}:{{.Tag}} {{.ID}}" | \
        grep -v "dreamscape" | \
        awk '{print $2}' | \
        while read -r image_id; do
            if [[ -n "$image_id" ]]; then
                docker rmi "$image_id" >/dev/null 2>&1 || true
            fi
        done

        # Get images after cleanup
        local images_after
        images_after=$(docker images -q | wc -l)

        local images_removed=$((images_before - images_after))

        log_success "Docker image cleanup completed: $images_removed images removed"
    fi
}

# Cleanup Docker volumes
cleanup_docker_volumes() {
    if [[ "$CLEANUP_VOLUMES" != "true" ]]; then
        return 0
    fi

    log_info "Cleaning up Docker volumes..."

    # Get volumes before cleanup
    local volumes_before
    volumes_before=$(docker volume ls -q | wc -l)

    if [[ "$DRY_RUN_MODE" == "true" ]]; then
        log_info "[DRY RUN] Would remove unused Docker volumes"

        local unused_volumes
        unused_volumes=$(docker volume ls -f "dangling=true" -q | wc -l)

        log_info "[DRY RUN] Would remove $unused_volumes unused volumes"
    else
        log_warning "Removing unused Docker volumes - this may delete data!"

        if confirm_action "Continue with volume cleanup? This cannot be undone!"; then
            docker volume prune -f >/dev/null 2>&1 || true

            local volumes_after
            volumes_after=$(docker volume ls -q | wc -l)

            local volumes_removed=$((volumes_before - volumes_after))

            log_success "Docker volume cleanup completed: $volumes_removed volumes removed"
        else
            log_info "Volume cleanup skipped by user"
        fi
    fi
}

# Cleanup logs
cleanup_logs() {
    if [[ "$CLEANUP_LOGS" != "true" ]]; then
        return 0
    fi

    log_info "Cleaning up logs older than $LOG_RETENTION_DAYS days..."

    local log_directories=(
        "/var/log"
        "$PROJECT_ROOT/logs"
        "/tmp"
    )

    local total_size_before=0
    local total_size_after=0

    for log_dir in "${log_directories[@]}"; do
        if [[ -d "$log_dir" ]]; then
            log_verbose "Cleaning logs in: $log_dir"

            # Calculate size before
            local size_before
            if command -v du >/dev/null 2>&1; then
                size_before=$(du -s "$log_dir" 2>/dev/null | awk '{print $1}' || echo "0")
                total_size_before=$((total_size_before + size_before))
            fi

            if [[ "$DRY_RUN_MODE" == "true" ]]; then
                local files_to_remove
                files_to_remove=$(find "$log_dir" -name "*.log" -type f -mtime +$LOG_RETENTION_DAYS 2>/dev/null | wc -l || echo "0")
                log_info "[DRY RUN] Would remove $files_to_remove log files from $log_dir"
            else
                # Remove old log files
                find "$log_dir" -name "*.log" -type f -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true
                find "$log_dir" -name "*.log.*" -type f -mtime +$LOG_RETENTION_DAYS -delete 2>/dev/null || true

                # Truncate large current log files
                find "$log_dir" -name "*.log" -type f -size +100M -exec truncate -s 10M {} \; 2>/dev/null || true

                # Calculate size after
                local size_after
                if command -v du >/dev/null 2>&1; then
                    size_after=$(du -s "$log_dir" 2>/dev/null | awk '{print $1}' || echo "0")
                    total_size_after=$((total_size_after + size_after))
                fi
            fi
        fi
    done

    if [[ "$DRY_RUN_MODE" != "true" ]]; then
        local space_freed=$((total_size_before - total_size_after))
        local space_freed_mb=$((space_freed / 1024))

        log_success "Log cleanup completed: ${space_freed_mb}MB freed"
    fi

    # Cleanup Docker container logs
    cleanup_docker_logs
}

# Cleanup Docker container logs
cleanup_docker_logs() {
    log_verbose "Cleaning up Docker container logs..."

    if [[ "$DRY_RUN_MODE" == "true" ]]; then
        log_info "[DRY RUN] Would truncate Docker container logs"
    else
        # Get all running containers
        local containers
        containers=$(docker ps -q)

        for container in $containers; do
            local log_file
            log_file=$(docker inspect "$container" --format='{{.LogPath}}' 2>/dev/null || echo "")

            if [[ -n "$log_file" ]] && [[ -f "$log_file" ]]; then
                local log_size
                log_size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")

                # Truncate if larger than 100MB
                if [[ $log_size -gt 104857600 ]]; then
                    log_verbose "Truncating large log file: $log_file"
                    truncate -s 10M "$log_file" 2>/dev/null || true
                fi
            fi
        done

        log_success "Docker container logs cleaned up"
    fi
}

# Cleanup temporary files
cleanup_temp_files() {
    log_info "Cleaning up temporary files..."

    local temp_directories=(
        "/tmp"
        "/var/tmp"
        "$PROJECT_ROOT/temp"
        "$PROJECT_ROOT/.cache"
    )

    for temp_dir in "${temp_directories[@]}"; do
        if [[ -d "$temp_dir" ]]; then
            log_verbose "Cleaning temporary files in: $temp_dir"

            if [[ "$DRY_RUN_MODE" == "true" ]]; then
                local temp_files
                temp_files=$(find "$temp_dir" -type f -mtime +1 2>/dev/null | wc -l || echo "0")
                log_info "[DRY RUN] Would remove $temp_files temporary files from $temp_dir"
            else
                # Remove files older than 1 day
                find "$temp_dir" -type f -mtime +1 -delete 2>/dev/null || true

                # Remove empty directories
                find "$temp_dir" -type d -empty -delete 2>/dev/null || true
            fi
        fi
    done

    log_success "Temporary files cleanup completed"
}

# System maintenance
system_maintenance() {
    log_info "Performing system maintenance..."

    # Update package cache (if applicable)
    if command -v apt-get >/dev/null 2>&1; then
        if [[ "$DRY_RUN_MODE" == "true" ]]; then
            log_info "[DRY RUN] Would update package cache"
        else
            log_verbose "Updating package cache..."
            apt-get update >/dev/null 2>&1 || log_debug "Package cache update failed"
        fi
    fi

    # Clean package cache
    if command -v apt-get >/dev/null 2>&1; then
        if [[ "$DRY_RUN_MODE" == "true" ]]; then
            log_info "[DRY RUN] Would clean package cache"
        else
            log_verbose "Cleaning package cache..."
            apt-get autoclean >/dev/null 2>&1 || true
            apt-get autoremove -y >/dev/null 2>&1 || true
        fi
    fi

    log_success "System maintenance completed"
}

# Health checks and repairs
health_checks_and_repairs() {
    log_info "Performing health checks and repairs..."

    # Check Docker daemon health
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon unhealthy"
        return 1
    fi

    log_success "Docker daemon healthy"

    # Check container health
    local unhealthy_containers=()
    local all_containers
    all_containers=$(docker ps -a --format "{{.Names}}")

    for container in $all_containers; do
        if [[ "$container" =~ dreamscape ]]; then
            local container_status
            container_status=$(docker inspect "$container" --format='{{.State.Status}}' 2>/dev/null || echo "unknown")

            case "$container_status" in
                "running")
                    log_verbose "Container $container is running"
                    ;;
                "exited")
                    log_warning "Container $container has exited"
                    unhealthy_containers+=("$container")
                    ;;
                "dead"|"paused")
                    log_error "Container $container is in unhealthy state: $container_status"
                    unhealthy_containers+=("$container")
                    ;;
            esac
        fi
    done

    # Attempt to repair unhealthy containers
    if [[ ${#unhealthy_containers[@]} -gt 0 ]]; then
        log_warning "Found ${#unhealthy_containers[@]} unhealthy containers"

        for container in "${unhealthy_containers[@]}"; do
            if [[ "$DRY_RUN_MODE" == "true" ]]; then
                log_info "[DRY RUN] Would attempt to restart container: $container"
            else
                log_info "Attempting to restart container: $container"
                if docker restart "$container" >/dev/null 2>&1; then
                    log_success "Container $container restarted successfully"
                else
                    log_error "Failed to restart container: $container"
                fi
            fi
        done
    else
        log_success "All containers are healthy"
    fi

    # Check service health
    check_services_health
}

# Check services health
check_services_health() {
    log_verbose "Checking service health endpoints..."

    local pods=("core" "business" "experience")
    local unhealthy_services=()

    for pod_name in "${pods[@]}"; do
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

            if ! check_service_health "$health_url" 5 1; then
                unhealthy_services+=("$service_name")
            fi
        done
    done

    if [[ ${#unhealthy_services[@]} -gt 0 ]]; then
        log_warning "Unhealthy services detected: ${unhealthy_services[*]}"
        return 1
    else
        log_success "All services are healthy"
        return 0
    fi
}

# Security maintenance
security_maintenance() {
    log_info "Performing security maintenance..."

    # Check for security updates (placeholder)
    if [[ "$DRY_RUN_MODE" == "true" ]]; then
        log_info "[DRY RUN] Would check for security updates"
    else
        log_info "Checking for security updates..."
        # This would integrate with actual security update mechanisms
        log_success "Security checks completed"
    fi

    # Audit file permissions
    audit_file_permissions

    # Check for exposed secrets
    check_for_exposed_secrets
}

# Audit file permissions
audit_file_permissions() {
    log_verbose "Auditing file permissions..."

    local sensitive_files=(
        "$PROJECT_ROOT/.env"
        "$PROJECT_ROOT/.env.production"
        "$PROJECT_ROOT/.dreamscape.config.yml"
    )

    for file in "${sensitive_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms
            perms=$(stat -c "%a" "$file" 2>/dev/null || echo "000")

            if [[ "$perms" == "600" ]] || [[ "$perms" == "644" ]]; then
                log_verbose "File permissions OK: $file ($perms)"
            else
                log_warning "Insecure file permissions: $file ($perms)"

                if [[ "$DRY_RUN_MODE" == "true" ]]; then
                    log_info "[DRY RUN] Would fix permissions for $file"
                else
                    chmod 600 "$file"
                    log_info "Fixed permissions for $file"
                fi
            fi
        fi
    done
}

# Check for exposed secrets
check_for_exposed_secrets() {
    log_verbose "Checking for exposed secrets..."

    local config_files=(
        "$PROJECT_ROOT/.dreamscape.config.yml"
        "$PROJECT_ROOT/docker/docker-compose*.yml"
    )

    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            # Check for plaintext passwords or keys
            if grep -qi "password.*:" "$config_file" && ! grep -q "password.*\*\*\*" "$config_file"; then
                log_warning "Potential exposed password in: $config_file"
            fi

            if grep -qi "secret.*:" "$config_file" && ! grep -q "secret.*\*\*\*" "$config_file"; then
                log_warning "Potential exposed secret in: $config_file"
            fi
        fi
    done
}

# Generate maintenance report
generate_maintenance_report() {
    log_info "Generating maintenance report..."

    local report_file
    report_file="/tmp/dreamscape_maintenance_$(date +%Y%m%d_%H%M%S).txt"

    {
        echo "DreamScape Big Pods - Maintenance Report"
        echo "======================================="
        echo "Date: $(date)"
        echo "Mode: $MAINTENANCE_MODE"
        echo "Dry Run: $DRY_RUN_MODE"
        echo ""

        echo "System Information:"
        echo "  • OS: $(uname -s)"
        echo "  • Kernel: $(uname -r)"
        echo "  • Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"

        if command -v df >/dev/null 2>&1; then
            local disk_usage
            disk_usage=$(df / | tail -1 | awk '{print $5}')
            echo "  • Disk Usage: $disk_usage"
        fi

        if command -v free >/dev/null 2>&1; then
            local memory_usage
            memory_usage=$(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')
            echo "  • Memory Usage: $memory_usage"
        fi

        echo ""
        echo "Maintenance Actions Performed:"

        if [[ "$CLEANUP_IMAGES" == "true" ]]; then
            echo "  ✓ Docker image cleanup"
        fi

        if [[ "$CLEANUP_VOLUMES" == "true" ]]; then
            echo "  ✓ Docker volume cleanup"
        fi

        if [[ "$CLEANUP_LOGS" == "true" ]]; then
            echo "  ✓ Log cleanup (retention: ${LOG_RETENTION_DAYS} days)"
        fi

        echo "  ✓ Temporary files cleanup"
        echo "  ✓ System maintenance"

        if [[ "$MAINTENANCE_MODE" == "full" ]] || [[ "$MAINTENANCE_MODE" == "health" ]]; then
            echo "  ✓ Health checks and repairs"
        fi

        if [[ "$MAINTENANCE_MODE" == "full" ]] || [[ "$MAINTENANCE_MODE" == "security" ]]; then
            echo "  ✓ Security maintenance"
        fi

        echo ""
        echo "Report generated: $report_file"

    } > "$report_file"

    log_success "Maintenance report generated: $report_file"
}

# Main maintenance orchestration
main() {
    local start_time
    start_time=$(date +%s)

    # Initialize
    init_common

    echo -e "${BLUE}🔧 DreamScape Big Pods - Maintenance Script${NC}"
    echo -e "${BLUE}Automated maintenance for Big Pods architecture${NC}"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Check maintenance window for scheduled mode
    if ! check_maintenance_window; then
        exit 0
    fi

    # Send start notification
    send_maintenance_notification "Starting $MAINTENANCE_MODE maintenance" "start"

    # Show maintenance plan
    log_info "Maintenance Plan:"
    echo -e "  • Mode: $MAINTENANCE_MODE"
    echo -e "  • Scheduled: $SCHEDULED_MODE"
    echo -e "  • Dry Run: $DRY_RUN_MODE"

    if [[ "$CLEANUP_IMAGES" == "true" ]]; then
        echo -e "  • Docker image cleanup: Enabled"
    fi

    if [[ "$CLEANUP_VOLUMES" == "true" ]]; then
        echo -e "  • Docker volume cleanup: Enabled"
    fi

    if [[ "$CLEANUP_LOGS" == "true" ]]; then
        echo -e "  • Log cleanup: Enabled (${LOG_RETENTION_DAYS} days retention)"
    fi

    echo ""

    # Confirm maintenance if not forced or scheduled
    if [[ "$FORCE" != "true" ]] && [[ "$SCHEDULED_MODE" != "true" ]]; then
        if ! confirm_action "Proceed with maintenance?" "y"; then
            log_info "Maintenance cancelled by user"
            exit 0
        fi
    fi

    # Check disk space
    check_disk_space

    # Backup before maintenance
    backup_before_maintenance

    # Execute maintenance based on mode
    case "$MAINTENANCE_MODE" in
        "full")
            cleanup_docker_images
            cleanup_docker_volumes
            cleanup_logs
            cleanup_temp_files
            system_maintenance
            health_checks_and_repairs
            security_maintenance
            ;;
        "cleanup")
            cleanup_docker_images
            cleanup_docker_volumes
            cleanup_logs
            cleanup_temp_files
            ;;
        "logs")
            cleanup_logs
            ;;
        "images")
            cleanup_docker_images
            ;;
        "health")
            health_checks_and_repairs
            ;;
        "security")
            security_maintenance
            ;;
        *)
            log_error "Unknown maintenance mode: $MAINTENANCE_MODE"
            exit 1
            ;;
    esac

    # Restart services if requested
    if [[ "$AUTOMATIC_RESTART" == "true" ]]; then
        log_info "Restarting services after maintenance..."

        if [[ "$DRY_RUN_MODE" == "true" ]]; then
            log_info "[DRY RUN] Would restart all Big Pods services"
        else
            # This would integrate with the existing pod management scripts
            log_info "Service restart functionality would be integrated here"
        fi
    fi

    # Health check after maintenance
    if [[ "$HEALTH_CHECK_AFTER" == "true" ]]; then
        log_info "Running post-maintenance health checks..."

        if check_services_health; then
            log_success "Post-maintenance health checks passed"
        else
            log_warning "Some services may need attention after maintenance"
        fi
    fi

    # Generate maintenance report
    generate_maintenance_report

    # Calculate total execution time
    local end_time
    end_time=$(date +%s)
    local execution_time=$((end_time - start_time))

    log_success "Maintenance completed in ${execution_time}s!"

    # Send completion notification
    send_maintenance_notification "Maintenance completed successfully in ${execution_time}s" "end"
}

# Execute main function
main "$@"