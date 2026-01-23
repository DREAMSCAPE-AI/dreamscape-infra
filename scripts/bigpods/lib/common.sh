#!/bin/bash
# DreamScape Big Pods - Common Library Functions
# Shared utilities for Big Pods automation scripts

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Icons
SUCCESS_ICON="✅"
ERROR_ICON="❌"
WARNING_ICON="⚠️"
INFO_ICON="ℹ️"
ROCKET_ICON="🚀"
GEAR_ICON="⚙️"
MAGNIFY_ICON="🔍"
CLOCK_ICON="⏰"

# Script metadata
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/.dreamscape.config.yml"

# Global variables
VERBOSE=false
DEBUG=false
DRY_RUN=false
FORCE=false

# Logging functions
log_info() {
    echo -e "${BLUE}${INFO_ICON} $1${NC}"
}

log_success() {
    echo -e "${GREEN}${SUCCESS_ICON} $1${NC}"
}

log_error() {
    echo -e "${RED}${ERROR_ICON} $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}${WARNING_ICON} $1${NC}"
}

log_debug() {
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG] $1${NC}" >&2
    fi
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}[VERBOSE] $1${NC}"
    fi
}

# Progress indicator
show_progress() {
    local message="$1"
    local delay="${2:-0.1}"

    echo -ne "${YELLOW}${CLOCK_ICON} $message"
    for i in {1..3}; do
        echo -ne "."
        sleep "$delay"
    done
    echo -e "${NC}"
}

# Error handling
handle_error() {
    local exit_code=$?
    local line_number=$1
    log_error "Script failed at line $line_number with exit code $exit_code"
    cleanup_on_exit
    exit $exit_code
}

# Cleanup function
cleanup_on_exit() {
    log_debug "Performing cleanup operations..."
}

# Error handling setup (opt-in)
enable_common_error_handling() {
    set -eE
    trap 'handle_error $LINENO' ERR
    trap 'cleanup_on_exit' EXIT
}

# Configuration functions
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    log_debug "Loading configuration from $CONFIG_FILE"

    # Check if yq is available
    if ! command -v yq >/dev/null 2>&1; then
        log_warning "yq not found. Using grep/awk for basic config parsing."
        return 1
    fi

    return 0
}

get_config_value() {
    local key="$1"
    local default="${2:-}"

    if command -v yq >/dev/null 2>&1; then
        yq eval ".$key" "$CONFIG_FILE" 2>/dev/null || echo "$default"
    else
        # Fallback parsing for basic values
        grep -E "^[[:space:]]*${key}:" "$CONFIG_FILE" | sed 's/.*: *"\?\([^"]*\)"\?.*/\1/' || echo "$default"
    fi
}

# Pod configuration functions
get_pod_services() {
    local pod_name="$1"
    get_config_value "bigpods.${pod_name}.services" | sed 's/- //g' | tr '\n' ' '
}

get_pod_ports() {
    local pod_name="$1"
    get_config_value "bigpods.${pod_name}.ports"
}

get_pod_docker_compose() {
    local pod_name="$1"
    if [[ -n "${BIGPODS_COMPOSE_FILE:-}" ]]; then
        echo "$BIGPODS_COMPOSE_FILE"
        return 0
    fi

    get_config_value "bigpods.${pod_name}.docker_compose"
}

# Docker functions
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker is not running or not accessible"
        log_info "Please start Docker Desktop or Docker daemon"
        exit 1
    fi
    log_success "Docker is running"
}

check_docker_compose() {
    local compose_cmd=""

    if command -v docker-compose >/dev/null 2>&1; then
        compose_cmd="docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        compose_cmd="docker compose"
    else
        log_error "Neither docker-compose nor docker compose available"
        exit 1
    fi

    echo "$compose_cmd"
}

# Repository functions
get_repository_path() {
    local repo_name="$1"
    get_config_value "repositories.${repo_name}.path" "../${repo_name}"
}

check_repository_exists() {
    local repo_name="$1"
    local repo_path
    repo_path=$(get_repository_path "$repo_name")

    if [[ ! -d "$repo_path" ]]; then
        log_error "Repository not found: $repo_path"
        return 1
    fi

    return 0
}

detect_repository_changes() {
    local repo_name="$1"
    local repo_path
    repo_path=$(get_repository_path "$repo_name")
    local current_dir
    current_dir="$(pwd)"

    if [[ ! -d "$repo_path/.git" ]]; then
        log_warning "Not a git repository: $repo_path"
        return 1
    fi

    if ! cd "$repo_path"; then
        log_error "Failed to enter repository: $repo_path"
        return 1
    fi

    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        log_info "Uncommitted changes detected in $repo_name"
        cd "$current_dir"
        return 0
    fi

    # Check for commits ahead of origin
    local ahead_count
    ahead_count=$(git rev-list --count HEAD ^origin/main 2>/dev/null || echo "0")

    if [[ "$ahead_count" -gt 0 ]]; then
        log_info "$ahead_count new commits in $repo_name"
        cd "$current_dir"
        return 0
    fi

    cd "$current_dir"
    return 1
}

# # Service health functions
# check_service_health() {
#     local service_url="$1"
#     local timeout="${2:-30}"
#     local max_attempts="${3:-10}"

#     log_verbose "Checking health of $service_url"

#     for ((i=1; i<=max_attempts; i++)); do
#         if curl -f -s --max-time "$timeout" "$service_url" >/dev/null 2>&1; then
#             log_success "Service healthy: $service_url"
#             return 0
#         fi

#         log_debug "Health check attempt $i/$max_attempts failed for $service_url"
#         sleep 2
#     done

#     log_error "Service health check failed: $service_url"
#     return 1
# }

wait_for_service() {
    local service_name="$1"
    local health_url="$2"
    local timeout="${3:-120}"

    log_info "Waiting for $service_name to be ready..."

    local start_time
    start_time=$(date +%s)

    while true; do
        if check_service_health "$health_url" 5 1; then
            log_success "$service_name is ready"
            return 0
        fi

        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [[ $elapsed -gt $timeout ]]; then
            log_error "Timeout waiting for $service_name"
            return 1
        fi

        echo -ne "\r${YELLOW}⏳ Waiting for $service_name... ${elapsed}s/${timeout}s${NC}"
        sleep 3
    done
}

# Validation functions
validate_pod_name() {
    local pod_name="$1"
    local valid_pods=("core" "business" "experience")

    for valid_pod in "${valid_pods[@]}"; do
        if [[ "$pod_name" == "$valid_pod" ]]; then
            return 0
        fi
    done

    log_error "Invalid pod name: $pod_name"
    log_info "Valid pods: ${valid_pods[*]}"
    return 1
}

validate_environment() {
    local env="$1"
    local valid_envs=("local" "staging" "production")

    for valid_env in "${valid_envs[@]}"; do
        if [[ "$env" == "$valid_env" ]]; then
            return 0
        fi
    done

    log_error "Invalid environment: $env"
    log_info "Valid environments: ${valid_envs[*]}"
    return 1
}

# File system functions
ensure_directory() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        log_debug "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

backup_file() {
    local file="$1"
    local backup_dir="${2:-$HOME/.dreamscape/backups}"

    if [[ -f "$file" ]]; then
        ensure_directory "$backup_dir"
        local backup_name
        backup_name="$(basename "$file").$(date +%Y%m%d_%H%M%S).bak"
        cp "$file" "$backup_dir/$backup_name"
        log_debug "Backed up $file to $backup_dir/$backup_name"
    fi
}

# Network functions
check_port_available() {
    local port="$1"

    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            return 1
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            return 1
        fi
    else
        # Fallback: try to connect
        if timeout 1 bash -c "</dev/tcp/localhost/$port" 2>/dev/null; then
            return 1
        fi
    fi

    return 0
}

get_available_port() {
    local start_port="${1:-3000}"
    local max_attempts="${2:-100}"

    for ((i=0; i<max_attempts; i++)); do
        local port=$((start_port + i))
        if check_port_available "$port"; then
            echo "$port"
            return 0
        fi
    done

    log_error "No available port found starting from $start_port"
    return 1
}

# Utility functions
confirm_action() {
    local message="$1"
    local default="${2:-n}"

    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi

    local prompt="$message [y/N]: "
    if [[ "$default" == "y" ]]; then
        prompt="$message [Y/n]: "
    fi

    read -p "$(echo -e "${YELLOW}$prompt${NC}")" -r response

    if [[ -z "$response" ]]; then
        response="$default"
    fi

    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Initialize common library
init_common() {
    log_debug "Initializing DreamScape Big Pods common library"

    # Load configuration
    if ! load_config; then
        log_warning "Configuration loading failed, some features may not work"
    fi

    # Set script directory context
    cd "$PROJECT_ROOT"

    log_debug "Project root: $PROJECT_ROOT"
    log_debug "Script directory: $SCRIPT_DIR"
    log_debug "Configuration file: $CONFIG_FILE"
}

# Export functions for use in other scripts
export -f log_info log_success log_error log_warning log_debug log_verbose
export -f show_progress handle_error cleanup_on_exit
export -f load_config get_config_value
export -f get_pod_services get_pod_ports get_pod_docker_compose
export -f check_docker check_docker_compose
export -f get_repository_path check_repository_exists detect_repository_changes
export -f check_service_health wait_for_service
export -f validate_pod_name validate_environment
export -f ensure_directory backup_file
export -f check_port_available get_available_port
export -f confirm_action init_common
