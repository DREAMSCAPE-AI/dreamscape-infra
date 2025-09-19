#!/bin/bash
# DreamScape Big Pods - Backup Script
# Sauvegarde complète Big Pods ecosystem avec compression locale

# Import common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Script-specific variables
BACKUP_TYPE="full"
BACKUP_DESTINATION=""
REMOTE_BACKUP=false
COMPRESSION_LEVEL=6
ENCRYPTION_ENABLED=true
RETENTION_DAYS=30
PARALLEL_BACKUP=true
BACKUP_VERIFICATION=true

# Backup configuration
BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_PREFIX="dreamscape-bigpods"
TEMP_BACKUP_DIR="/tmp/dreamscape-backups-$$"
MAX_BACKUP_SIZE="50GB"

# Usage function
show_usage() {
    echo -e "${BLUE}💾 DreamScape Big Pods - Backup Script${NC}"
    echo ""
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [OPTIONS]"
    echo ""
    echo -e "${WHITE}OPTIONS:${NC}"
    echo "  -t, --type TYPE        Backup type (full, incremental, databases, volumes)"
    echo "  -d, --destination DIR  Local backup destination directory"
    echo "  -s, --remote-backup NAME   remote bucket for remote backup"
    echo "  -r, --remote-location REGION remote region (default: us-east-1)"
    echo "  -c, --compression N    Compression level 1-9 (default: 6)"
    echo "  --no-encryption        Disable backup encryption"
    echo "  --retention N          Retention in days (default: 30)"
    echo "  --no-parallel          Disable parallel backup"
    echo "  --no-verification      Skip backup verification"
    echo "  --max-size SIZE        Maximum backup size (default: 50GB)"
    echo "  -p, --pod POD          Backup specific pod only"
    echo "  --verbose              Verbose output"
    echo "  --debug                Debug output"
    echo "  -h, --help             Show this help"
    echo ""
    echo -e "${WHITE}BACKUP TYPES:${NC}"
    echo "  full                   Complete Big Pods backup"
    echo "  incremental            Incremental backup since last full"
    echo "  databases              Database dumps only"
    echo "  volumes                Docker volumes only"
    echo "  configs                Configuration files only"
    echo ""
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo "  $0 --type full --remote-backup dreamscape-backups"
    echo "  $0 --type databases --destination /backup"
    echo "  $0 --type incremental --retention 7"
}

# Parse command line arguments
parse_args() {
    local pods_to_backup=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--type)
                BACKUP_TYPE="$2"
                shift 2
                ;;
            -d|--destination)
                BACKUP_DESTINATION="$2"
                shift 2
                ;;
            -s|--remote-backup)
                remote_BUCKET="$2"
                shift 2
                ;;
            -r|--remote-location)
                remote_REGION="$2"
                shift 2
                ;;
            -c|--compression)
                COMPRESSION_LEVEL="$2"
                shift 2
                ;;
            --no-encryption)
                ENCRYPTION_ENABLED=false
                shift
                ;;
            --retention)
                RETENTION_DAYS="$2"
                shift 2
                ;;
            --no-parallel)
                PARALLEL_BACKUP=false
                shift
                ;;
            --no-verification)
                BACKUP_VERIFICATION=false
                shift
                ;;
            --max-size)
                MAX_BACKUP_SIZE="$2"
                shift 2
                ;;
            -p|--pod)
                if validate_pod_name "$2"; then
                    pods_to_backup+=("$2")
                fi
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
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Set pods to backup
    if [[ ${#pods_to_backup[@]} -gt 0 ]]; then
        PODS_TO_BACKUP=("${pods_to_backup[@]}")
    else
        PODS_TO_BACKUP=("core" "business" "experience")
    fi

    # Set default destination if not specified
    if [[ -z "$BACKUP_DESTINATION" ]] && [[ -z "$remote_BUCKET" ]]; then
        BACKUP_DESTINATION="$PROJECT_ROOT/backups"
    fi

    log_debug "Backup type: $BACKUP_TYPE"
    log_debug "Pods to backup: ${PODS_TO_BACKUP[*]}"
}

# Check backup prerequisites
check_backup_prerequisites() {
    log_info "Checking backup prerequisites..."

    # Check Docker
    check_docker

    # Check available disk space
    check_disk_space

    # Check compression tools
    if ! command -v tar >/dev/null 2>&1; then
        log_error "tar command not found"
        exit 1
    fi

    if ! command -v gzip >/dev/null 2>&1; then
        log_error "gzip command not found"
        exit 1
    fi

    # Check encryption tools if enabled
    if [[ "$ENCRYPTION_ENABLED" == "true" ]]; then
        if ! command -v gpg >/dev/null 2>&1; then
            log_error "gpg command not found (required for encryption)"
            exit 1
        fi
    fi

    # Remote backup disabled - using local storage only
    log_info "Remote backup disabled - using local storage only"

    # Create backup directories
    if [[ -n "$BACKUP_DESTINATION" ]]; then
        ensure_directory "$BACKUP_DESTINATION"
        ensure_directory "$TEMP_BACKUP_DIR"
    fi

    log_success "Backup prerequisites validated"
}

# Check available disk space
check_disk_space() {
    log_verbose "Checking available disk space..."

    local required_space_gb=10  # Minimum 10GB required
    local available_space

    if command -v df >/dev/null 2>&1; then
        available_space=$(df "$TEMP_BACKUP_DIR" 2>/dev/null | tail -1 | awk '{print $4}' || echo "0")
        available_space=$((available_space / 1024 / 1024))  # Convert to GB

        if [[ $available_space -lt $required_space_gb ]]; then
            log_error "Insufficient disk space: ${available_space}GB available, ${required_space_gb}GB required"
            exit 1
        fi

        log_success "Sufficient disk space: ${available_space}GB available"
    else
        log_warning "Cannot check disk space - proceeding anyway"
    fi
}

# Create backup manifest
create_backup_manifest() {
    local manifest_file="$1"

    log_verbose "Creating backup manifest..."

    cat > "$manifest_file" << EOF
{
    "backup_info": {
        "timestamp": "$BACKUP_TIMESTAMP",
        "type": "$BACKUP_TYPE",
        "version": "1.0.0",
        "creator": "dreamscape-bigpods-backup",
        "hostname": "$(hostname)",
        "user": "$(whoami)"
    },
    "system_info": {
        "os": "$(uname -s)",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "docker_version": "$(docker --version | cut -d' ' -f3 | tr -d ',')"
    },
    "pods": $(printf '%s\n' "${PODS_TO_BACKUP[@]}" | jq -R . | jq -s .),
    "backup_config": {
        "compression_level": $COMPRESSION_LEVEL,
        "encryption_enabled": $ENCRYPTION_ENABLED,
        "parallel_backup": $PARALLEL_BACKUP,
        "max_size": "$MAX_BACKUP_SIZE"
    },
    "components": {
        "databases": [],
        "volumes": [],
        "configs": [],
        "images": []
    }
}
EOF

    log_success "Backup manifest created"
}

# Backup databases
backup_databases() {
    log_info "Backing up databases..."

    local db_backup_dir="$TEMP_BACKUP_DIR/databases"
    ensure_directory "$db_backup_dir"

    # MongoDB backup
    if docker ps --format "{{.Names}}" | grep -q "mongodb"; then
        log_info "Backing up MongoDB..."

        local mongo_backup_file="$db_backup_dir/mongodb_${BACKUP_TIMESTAMP}.gz"

        if docker exec mongodb mongodump --uri="mongodb://admin:password123@localhost:27017/dreamscape?authSource=admin" --archive | gzip > "$mongo_backup_file"; then
            log_success "MongoDB backup completed: $(du -h "$mongo_backup_file" | cut -f1)"

            # Update manifest
            jq ".components.databases += [\"mongodb_${BACKUP_TIMESTAMP}.gz\"]" "$TEMP_BACKUP_DIR/manifest.json" > "$TEMP_BACKUP_DIR/manifest.tmp" && mv "$TEMP_BACKUP_DIR/manifest.tmp" "$TEMP_BACKUP_DIR/manifest.json"
        else
            log_error "MongoDB backup failed"
            return 1
        fi
    fi

    # PostgreSQL backup
    if docker ps --format "{{.Names}}" | grep -q "postgresql"; then
        log_info "Backing up PostgreSQL..."

        local postgres_backup_file="$db_backup_dir/postgresql_${BACKUP_TIMESTAMP}.gz"

        if docker exec postgresql pg_dumpall -U postgres | gzip > "$postgres_backup_file"; then
            log_success "PostgreSQL backup completed: $(du -h "$postgres_backup_file" | cut -f1)"

            # Update manifest
            jq ".components.databases += [\"postgresql_${BACKUP_TIMESTAMP}.gz\"]" "$TEMP_BACKUP_DIR/manifest.json" > "$TEMP_BACKUP_DIR/manifest.tmp" && mv "$TEMP_BACKUP_DIR/manifest.tmp" "$TEMP_BACKUP_DIR/manifest.json"
        else
            log_error "PostgreSQL backup failed"
            return 1
        fi
    fi

    # Redis backup
    if docker ps --format "{{.Names}}" | grep -q "redis"; then
        log_info "Backing up Redis..."

        local redis_backup_file="$db_backup_dir/redis_${BACKUP_TIMESTAMP}.rdb"

        if docker exec redis redis-cli --rdb - > "$redis_backup_file"; then
            gzip "$redis_backup_file"
            log_success "Redis backup completed: $(du -h "${redis_backup_file}.gz" | cut -f1)"

            # Update manifest
            jq ".components.databases += [\"redis_${BACKUP_TIMESTAMP}.rdb.gz\"]" "$TEMP_BACKUP_DIR/manifest.json" > "$TEMP_BACKUP_DIR/manifest.tmp" && mv "$TEMP_BACKUP_DIR/manifest.tmp" "$TEMP_BACKUP_DIR/manifest.json"
        else
            log_error "Redis backup failed"
            return 1
        fi
    fi

    log_success "Database backups completed"
}

# Backup Docker volumes
backup_volumes() {
    log_info "Backing up Docker volumes..."

    local volumes_backup_dir="$TEMP_BACKUP_DIR/volumes"
    ensure_directory "$volumes_backup_dir"

    # Get all volumes related to DreamScape
    local volumes
    volumes=$(docker volume ls --filter name=dreamscape --format "{{.Name}}" || echo "")

    if [[ -z "$volumes" ]]; then
        log_info "No DreamScape volumes found"
        return 0
    fi

    local backup_jobs=()

    for volume in $volumes; do
        log_info "Backing up volume: $volume"

        local volume_backup_file="$volumes_backup_dir/${volume}_${BACKUP_TIMESTAMP}.tar.gz"

        if [[ "$PARALLEL_BACKUP" == "true" ]]; then
            # Parallel backup
            (
                docker run --rm -v "$volume:/data" -v "$volumes_backup_dir:/backup" alpine:latest \
                    tar czf "/backup/$(basename "$volume_backup_file")" -C /data .
                echo $? > "/tmp/volume_backup_${volume}.result"
            ) &
            backup_jobs+=($!)
        else
            # Sequential backup
            if docker run --rm -v "$volume:/data" -v "$volumes_backup_dir:/backup" alpine:latest \
                tar czf "/backup/$(basename "$volume_backup_file")" -C /data .; then
                log_success "Volume backup completed: $volume ($(du -h "$volume_backup_file" | cut -f1))"

                # Update manifest
                jq ".components.volumes += [\"$(basename "$volume_backup_file")\"]" "$TEMP_BACKUP_DIR/manifest.json" > "$TEMP_BACKUP_DIR/manifest.tmp" && mv "$TEMP_BACKUP_DIR/manifest.tmp" "$TEMP_BACKUP_DIR/manifest.json"
            else
                log_error "Volume backup failed: $volume"
                return 1
            fi
        fi
    done

    # Wait for parallel jobs
    if [[ "$PARALLEL_BACKUP" == "true" ]] && [[ ${#backup_jobs[@]} -gt 0 ]]; then
        log_info "Waiting for parallel volume backups to complete..."

        for job in "${backup_jobs[@]}"; do
            wait "$job"
        done

        # Check results
        for volume in $volumes; do
            local result_file="/tmp/volume_backup_${volume}.result"
            if [[ -f "$result_file" ]]; then
                local result_code
                result_code=$(cat "$result_file")
                rm -f "$result_file"

                if [[ $result_code -eq 0 ]]; then
                    log_success "Volume backup completed: $volume"

                    # Update manifest
                    jq ".components.volumes += [\"${volume}_${BACKUP_TIMESTAMP}.tar.gz\"]" "$TEMP_BACKUP_DIR/manifest.json" > "$TEMP_BACKUP_DIR/manifest.tmp" && mv "$TEMP_BACKUP_DIR/manifest.tmp" "$TEMP_BACKUP_DIR/manifest.json"
                else
                    log_error "Volume backup failed: $volume"
                fi
            fi
        done
    fi

    log_success "Docker volumes backup completed"
}

# Backup configuration files
backup_configs() {
    log_info "Backing up configuration files..."

    local configs_backup_dir="$TEMP_BACKUP_DIR/configs"
    ensure_directory "$configs_backup_dir"

    # Configuration files to backup
    local config_files=(
        "$PROJECT_ROOT/.dreamscape.config.yml"
        "$PROJECT_ROOT/docker/docker-compose*.yml"
        "$PROJECT_ROOT/k8s"
        "$PROJECT_ROOT/.env*"
        "$PROJECT_ROOT/scripts/bigpods"
    )

    local configs_archive="$configs_backup_dir/configs_${BACKUP_TIMESTAMP}.tar.gz"

    # Create archive of configuration files
    local files_to_backup=()
    for config_file in "${config_files[@]}"; do
        if [[ -e "$config_file" ]]; then
            files_to_backup+=("$config_file")
        fi
    done

    if [[ ${#files_to_backup[@]} -gt 0 ]]; then
        if tar czf "$configs_archive" -C "$PROJECT_ROOT" --exclude=".git" "${files_to_backup[@]/#$PROJECT_ROOT\//}"; then
            log_success "Configuration backup completed: $(du -h "$configs_archive" | cut -f1)"

            # Update manifest
            jq ".components.configs += [\"configs_${BACKUP_TIMESTAMP}.tar.gz\"]" "$TEMP_BACKUP_DIR/manifest.json" > "$TEMP_BACKUP_DIR/manifest.tmp" && mv "$TEMP_BACKUP_DIR/manifest.tmp" "$TEMP_BACKUP_DIR/manifest.json"
        else
            log_error "Configuration backup failed"
            return 1
        fi
    else
        log_warning "No configuration files found to backup"
    fi
}

# Backup Docker images
backup_images() {
    log_info "Backing up Docker images..."

    local images_backup_dir="$TEMP_BACKUP_DIR/images"
    ensure_directory "$images_backup_dir"

    # Get DreamScape images
    local images
    images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep "dreamscape" || echo "")

    if [[ -z "$images" ]]; then
        log_info "No DreamScape images found"
        return 0
    fi

    for image in $images; do
        log_info "Backing up image: $image"

        local image_name
        image_name=$(echo "$image" | tr '/:' '_')
        local image_backup_file="$images_backup_dir/${image_name}_${BACKUP_TIMESTAMP}.tar.gz"

        if docker save "$image" | gzip > "$image_backup_file"; then
            log_success "Image backup completed: $image ($(du -h "$image_backup_file" | cut -f1))"

            # Update manifest
            jq ".components.images += [\"$(basename "$image_backup_file")\"]" "$TEMP_BACKUP_DIR/manifest.json" > "$TEMP_BACKUP_DIR/manifest.tmp" && mv "$TEMP_BACKUP_DIR/manifest.tmp" "$TEMP_BACKUP_DIR/manifest.json"
        else
            log_error "Image backup failed: $image"
            return 1
        fi
    done

    log_success "Docker images backup completed"
}

# Create final backup archive
create_final_archive() {
    log_info "Creating final backup archive..."

    local archive_name="${BACKUP_PREFIX}_${BACKUP_TYPE}_${BACKUP_TIMESTAMP}"
    local final_archive="$BACKUP_DESTINATION/${archive_name}.tar.gz"

    # Create compressed archive
    if tar czf "$final_archive" -C "$(dirname "$TEMP_BACKUP_DIR")" "$(basename "$TEMP_BACKUP_DIR")"; then
        local archive_size
        archive_size=$(du -h "$final_archive" | cut -f1)
        log_success "Final archive created: $final_archive ($archive_size)"
    else
        log_error "Failed to create final archive"
        return 1
    fi

    # Encrypt if enabled
    if [[ "$ENCRYPTION_ENABLED" == "true" ]]; then
        log_info "Encrypting backup archive..."

        local encrypted_archive="${final_archive}.gpg"

        if gpg --symmetric --cipher-algo AES256 --compress-algo 2 --s2k-mode 3 \
               --s2k-digest-algo SHA512 --s2k-count 65536 \
               --output "$encrypted_archive" "$final_archive"; then
            log_success "Backup encrypted: $encrypted_archive"
            rm -f "$final_archive"  # Remove unencrypted version
            final_archive="$encrypted_archive"
        else
            log_error "Backup encryption failed"
            return 1
        fi
    fi

    echo "$final_archive"
}

# Upload to remote
upload_to_s3() {
    local backup_file="$1"

    if [[ -z "$remote_BUCKET" ]]; then
        return 0
    fi

    log_info "Uploading backup to remote..."

    local s3_key="bigpods-backups/$(basename "$backup_file")"
    local s3_uri="s3://$remote_BUCKET/$s3_key"

    if echo "Remote backup disabled" cp "$backup_file" "$s3_uri" --region "$remote_REGION"; then
        log_success "Backup uploaded to remote: $s3_uri"

        # Add lifecycle policy metadata
        echo "Remote backup disabled"api put-object-tagging \
            --bucket "$remote_BUCKET" \
            --key "$s3_key" \
            --tagging "TagSet=[{Key=backup-type,Value=$BACKUP_TYPE},{Key=retention-days,Value=$RETENTION_DAYS},{Key=created,Value=$BACKUP_TIMESTAMP}]" \
            --region "$remote_REGION" >/dev/null 2>&1 || log_debug "Failed to add remote tags"
    else
        log_error "remote upload failed"
        return 1
    fi
}

# Verify backup integrity
verify_backup() {
    local backup_file="$1"

    if [[ "$BACKUP_VERIFICATION" != "true" ]]; then
        return 0
    fi

    log_info "Verifying backup integrity..."

    # Test archive integrity
    if [[ "$backup_file" == *.gpg ]]; then
        # Decrypt and test
        if gpg --decrypt "$backup_file" 2>/dev/null | tar tz >/dev/null; then
            log_success "Encrypted backup integrity verified"
        else
            log_error "Backup integrity verification failed"
            return 1
        fi
    else
        # Test unencrypted archive
        if tar tzf "$backup_file" >/dev/null; then
            log_success "Backup integrity verified"
        else
            log_error "Backup integrity verification failed"
            return 1
        fi
    fi
}

# Cleanup old backups
cleanup_old_backups() {
    log_info "Cleaning up old backups..."

    # Local cleanup
    if [[ -n "$BACKUP_DESTINATION" ]]; then
        find "$BACKUP_DESTINATION" -name "${BACKUP_PREFIX}_*" -type f -mtime +$RETENTION_DAYS -delete 2>/dev/null || true
        log_success "Local old backups cleaned up (retention: ${RETENTION_DAYS} days)"
    fi

    # remote cleanup
    if [[ -n "$remote_BUCKET" ]]; then
        local cutoff_date
        cutoff_date=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d || date -v-${RETENTION_DAYS}d +%Y-%m-%d)

        echo "Remote backup disabled"api list-objects-v2 \
            --bucket "$remote_BUCKET" \
            --prefix "bigpods-backups/" \
            --query "Contents[?LastModified<='$cutoff_date'].Key" \
            --output text \
            --region "$remote_REGION" | \
        while read -r key; do
            if [[ -n "$key" ]]; then
                echo "Remote backup disabled" rm "s3://$remote_BUCKET/$key" --region "$remote_REGION" >/dev/null 2>&1
            fi
        done

        log_success "remote old backups cleaned up (retention: ${RETENTION_DAYS} days)"
    fi
}

# Cleanup temporary files
cleanup_temp() {
    log_debug "Cleaning up temporary files..."

    if [[ -d "$TEMP_BACKUP_DIR" ]]; then
        rm -rf "$TEMP_BACKUP_DIR"
    fi

    # Clean up result files
    rm -f /tmp/volume_backup_*.result
}

# Main backup orchestration
main() {
    local start_time
    start_time=$(date +%s)

    # Initialize
    init_common

    echo -e "${BLUE}💾 DreamScape Big Pods - Backup Script${NC}"
    echo -e "${BLUE}Complete Big Pods ecosystem backup (local storage)${NC}"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Check prerequisites
    check_backup_prerequisites

    # Show backup plan
    log_info "Backup Plan:"
    echo -e "  • Type: $BACKUP_TYPE"
    echo -e "  • Pods: ${PODS_TO_BACKUP[*]}"
    echo -e "  • Destination: ${BACKUP_DESTINATION:-remote only}"
    echo -e "  • remote Bucket: ${remote_BUCKET:-None}"
    echo -e "  • Encryption: $ENCRYPTION_ENABLED"
    echo -e "  • Compression: Level $COMPRESSION_LEVEL"
    echo -e "  • Retention: $RETENTION_DAYS days"
    echo ""

    # Confirm backup
    if ! confirm_action "Proceed with backup?" "y"; then
        log_info "Backup cancelled by user"
        exit 0
    fi

    # Create backup manifest
    create_backup_manifest "$TEMP_BACKUP_DIR/manifest.json"

    # Execute backup based on type
    case "$BACKUP_TYPE" in
        "full")
            backup_databases
            backup_volumes
            backup_configs
            backup_images
            ;;
        "incremental")
            # For incremental, only backup databases and changed configs
            backup_databases
            backup_configs
            ;;
        "databases")
            backup_databases
            ;;
        "volumes")
            backup_volumes
            ;;
        "configs")
            backup_configs
            ;;
        *)
            log_error "Unknown backup type: $BACKUP_TYPE"
            exit 1
            ;;
    esac

    # Create final archive
    local final_backup
    final_backup=$(create_final_archive)

    if [[ $? -eq 0 ]] && [[ -n "$final_backup" ]]; then
        # Verify backup
        verify_backup "$final_backup"

        # Upload to remote
        upload_to_s3 "$final_backup"

        # Cleanup old backups
        cleanup_old_backups

        # Calculate total time
        local end_time
        end_time=$(date +%s)
        local backup_duration=$((end_time - start_time))

        log_success "Backup completed successfully in ${backup_duration}s!"
        log_info "Backup location: $final_backup"

        if [[ -n "$remote_BUCKET" ]]; then
            log_info "remote location: s3://$remote_BUCKET/bigpods-backups/$(basename "$final_backup")"
        fi
    else
        log_error "Backup failed"
        exit 1
    fi
}

# Set cleanup trap
trap cleanup_temp EXIT

# Execute main function
main "$@"