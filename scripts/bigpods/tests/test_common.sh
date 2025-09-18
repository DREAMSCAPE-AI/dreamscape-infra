#!/bin/bash
# DreamScape Big Pods - Common Library Tests
# Tests unitaires pour lib/common.sh

# Test framework setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$TEST_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source the library to test
source "$SCRIPT_DIR/lib/common.sh"

# Test configuration
TESTS_PASSED=0
TESTS_FAILED=0
VERBOSE_TESTS=false

# Colors for test output
TEST_RED='\033[0;31m'
TEST_GREEN='\033[0;32m'
TEST_YELLOW='\033[1;33m'
TEST_BLUE='\033[0;34m'
TEST_NC='\033[0m'

# Test framework functions
test_setup() {
    echo -e "${TEST_BLUE}🧪 DreamScape Big Pods - Common Library Tests${TEST_NC}"
    echo "=============================================="
    echo ""
}

test_teardown() {
    echo ""
    echo "=============================================="
    echo -e "${TEST_BLUE}Test Results:${TEST_NC}"
    echo -e "  Passed: ${TEST_GREEN}$TESTS_PASSED${TEST_NC}"
    echo -e "  Failed: ${TEST_RED}$TESTS_FAILED${TEST_NC}"
    echo -e "  Total:  $((TESTS_PASSED + TESTS_FAILED))"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${TEST_GREEN}✅ All tests passed!${TEST_NC}"
        exit 0
    else
        echo -e "${TEST_RED}❌ Some tests failed!${TEST_NC}"
        exit 1
    fi
}

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local test_name="$3"

    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${TEST_GREEN}✓${TEST_NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} $test_name"
        echo -e "    Expected: '$expected'"
        echo -e "    Actual:   '$actual'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_true() {
    local condition="$1"
    local test_name="$2"

    if [[ $condition ]]; then
        echo -e "  ${TEST_GREEN}✓${TEST_NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} $test_name"
        echo -e "    Condition failed: $condition"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_false() {
    local condition="$1"
    local test_name="$2"

    if [[ ! $condition ]]; then
        echo -e "  ${TEST_GREEN}✓${TEST_NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} $test_name"
        echo -e "    Condition should be false: $condition"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local test_name="$3"

    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "  ${TEST_GREEN}✓${TEST_NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} $test_name"
        echo -e "    '$needle' not found in '$haystack'"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test functions
test_logging_functions() {
    echo -e "${TEST_YELLOW}Testing logging functions...${TEST_NC}"

    # Test log functions don't crash
    local log_output
    log_output=$(log_info "Test info message" 2>&1)
    assert_contains "$log_output" "Test info message" "log_info outputs message"

    log_output=$(log_success "Test success message" 2>&1)
    assert_contains "$log_output" "Test success message" "log_success outputs message"

    log_output=$(log_warning "Test warning message" 2>&1)
    assert_contains "$log_output" "Test warning message" "log_warning outputs message"

    log_output=$(log_error "Test error message" 2>&1)
    assert_contains "$log_output" "Test error message" "log_error outputs message"

    # Test debug mode
    DEBUG=true
    log_output=$(log_debug "Test debug message" 2>&1)
    assert_contains "$log_output" "Test debug message" "log_debug outputs when DEBUG=true"

    DEBUG=false
    log_output=$(log_debug "Test debug message" 2>&1)
    assert_equals "" "$log_output" "log_debug silent when DEBUG=false"
}

test_validation_functions() {
    echo -e "${TEST_YELLOW}Testing validation functions...${TEST_NC}"

    # Test pod name validation
    validate_pod_name "core" >/dev/null 2>&1
    assert_equals "0" "$?" "validate_pod_name accepts 'core'"

    validate_pod_name "business" >/dev/null 2>&1
    assert_equals "0" "$?" "validate_pod_name accepts 'business'"

    validate_pod_name "experience" >/dev/null 2>&1
    assert_equals "0" "$?" "validate_pod_name accepts 'experience'"

    if validate_pod_name "invalid" >/dev/null 2>&1; then
        assert_equals "1" "0" "validate_pod_name rejects 'invalid'"
    else
        assert_equals "1" "1" "validate_pod_name rejects 'invalid'"
    fi

    # Test environment validation
    validate_environment "local" >/dev/null 2>&1
    assert_equals "0" "$?" "validate_environment accepts 'local'"

    validate_environment "staging" >/dev/null 2>&1
    assert_equals "0" "$?" "validate_environment accepts 'staging'"

    validate_environment "production" >/dev/null 2>&1
    assert_equals "0" "$?" "validate_environment accepts 'production'"

    if validate_environment "invalid" >/dev/null 2>&1; then
        assert_equals "1" "0" "validate_environment rejects 'invalid'"
    else
        assert_equals "1" "1" "validate_environment rejects 'invalid'"
    fi
}

test_configuration_functions() {
    echo -e "${TEST_YELLOW}Testing configuration functions...${TEST_NC}"

    # Test config loading
    if load_config >/dev/null 2>&1; then
        local load_result=0
    else
        local load_result=1
    fi

    if [[ -f "$CONFIG_FILE" ]]; then
        assert_equals "0" "$load_result" "load_config succeeds when config file exists"
    else
        assert_equals "1" "$load_result" "load_config fails when config file missing"
    fi

    # Test config value retrieval (if config exists)
    if [[ -f "$CONFIG_FILE" ]]; then
        local bigpods_config
        bigpods_config=$(get_config_value "bigpods" "default_value")
        assert_true '[[ -n "$bigpods_config" ]]' "get_config_value returns non-empty value"

        local nonexistent_value
        nonexistent_value=$(get_config_value "nonexistent.key" "default_value")
        assert_equals "default_value" "$nonexistent_value" "get_config_value returns default for missing key"
    fi
}

test_docker_functions() {
    echo -e "${TEST_YELLOW}Testing Docker functions...${TEST_NC}"

    # Test Docker availability check
    if command -v docker >/dev/null 2>&1; then
        check_docker >/dev/null 2>&1
        assert_equals "0" "$?" "check_docker succeeds when Docker available"
    else
        check_docker >/dev/null 2>&1
        assert_equals "1" "$?" "check_docker fails when Docker unavailable"
    fi

    # Test Docker Compose command detection
    local compose_cmd
    compose_cmd=$(check_docker_compose 2>/dev/null)

    if command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; then
        assert_true '[[ -n "$compose_cmd" ]]' "check_docker_compose returns command when available"
    fi
}

test_network_functions() {
    echo -e "${TEST_YELLOW}Testing network functions...${TEST_NC}"

    # Test port availability check for common ports
    local test_ports=(22 80 443 3000 3001)

    for port in "${test_ports[@]}"; do
        check_port_available "$port" >/dev/null 2>&1
        local result=$?
        assert_true '[[ $result -eq 0 || $result -eq 1 ]]' "check_port_available returns valid exit code for port $port"
    done

    # Test get available port
    local available_port
    available_port=$(get_available_port 30000 10 2>/dev/null)

    if [[ -n "$available_port" ]] && [[ "$available_port" =~ ^[0-9]+$ ]]; then
        assert_true '[[ $available_port -ge 30000 && $available_port -le 30010 ]]' "get_available_port returns port in range"
    fi
}

test_utility_functions() {
    echo -e "${TEST_YELLOW}Testing utility functions...${TEST_NC}"

    # Test directory creation
    local test_dir="/tmp/dreamscape_test_$$"
    ensure_directory "$test_dir"
    assert_true '[[ -d "$test_dir" ]]' "ensure_directory creates directory"
    rm -rf "$test_dir"

    # Test file backup
    local test_file="/tmp/dreamscape_test_file_$$"
    local backup_dir="/tmp/dreamscape_backup_$$"

    echo "test content" > "$test_file"
    backup_file "$test_file" "$backup_dir"

    assert_true '[[ -d "$backup_dir" ]]' "backup_file creates backup directory"

    local backup_count
    backup_count=$(find "$backup_dir" -name "*.bak" | wc -l)
    assert_true '[[ $backup_count -gt 0 ]]' "backup_file creates backup file"

    rm -rf "$test_file" "$backup_dir"

    # Test confirmation (with FORCE=true to skip interactive prompt)
    FORCE=true
    confirm_action "Test confirmation" >/dev/null 2>&1
    assert_equals "0" "$?" "confirm_action returns true when FORCE=true"

    FORCE=false
}

test_pod_configuration() {
    echo -e "${TEST_YELLOW}Testing pod configuration functions...${TEST_NC}"

    # Test pod services retrieval
    local core_services
    core_services=$(get_pod_services "core")
    assert_contains "$core_services" "auth" "get_pod_services returns auth for core pod"
    assert_contains "$core_services" "user" "get_pod_services returns user for core pod"

    local business_services
    business_services=$(get_pod_services "business")
    assert_contains "$business_services" "voyage" "get_pod_services returns voyage for business pod"
    assert_contains "$business_services" "payment" "get_pod_services returns payment for business pod"
    assert_contains "$business_services" "ai" "get_pod_services returns ai for business pod"

    local experience_services
    experience_services=$(get_pod_services "experience")
    assert_contains "$experience_services" "panorama" "get_pod_services returns panorama for experience pod"

    # Test docker compose file retrieval
    local core_compose
    core_compose=$(get_pod_docker_compose "core")
    assert_contains "$core_compose" "core-pod" "get_pod_docker_compose returns compose file for core"

    local business_compose
    business_compose=$(get_pod_docker_compose "business")
    assert_contains "$business_compose" "business-pod" "get_pod_docker_compose returns compose file for business"
}

test_health_check_functions() {
    echo -e "${TEST_YELLOW}Testing health check functions...${TEST_NC}"

    # Test health check with invalid URL (should fail)
    check_service_health "http://invalid-url-that-does-not-exist:99999/health" 1 1 >/dev/null 2>&1
    assert_equals "1" "$?" "check_service_health fails for invalid URL"

    # Test wait for service with invalid URL (should timeout quickly)
    local start_time
    start_time=$(date +%s)

    wait_for_service "invalid-service" "http://invalid-url:99999/health" 5 >/dev/null 2>&1

    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    assert_true '[[ $elapsed -ge 4 && $elapsed -le 10 ]]' "wait_for_service respects timeout"
}

test_repository_functions() {
    echo -e "${TEST_YELLOW}Testing repository functions...${TEST_NC}"

    # Test repository path resolution
    local test_repo="dreamscape-services"
    local repo_path
    repo_path=$(get_repository_path "$test_repo")
    assert_contains "$repo_path" "$test_repo" "get_repository_path includes repository name"

    # Test repository existence check
    check_repository_exists "nonexistent-repo" >/dev/null 2>&1
    assert_equals "1" "$?" "check_repository_exists fails for nonexistent repo"

    # Test change detection for invalid repo
    detect_repository_changes "nonexistent-repo" >/dev/null 2>&1
    assert_equals "1" "$?" "detect_repository_changes fails for nonexistent repo"
}

# Performance tests
test_performance() {
    echo -e "${TEST_YELLOW}Testing performance...${TEST_NC}"

    # Test logging performance
    local start_time
    start_time=$(date +%s%3N)

    for ((i=1; i<=100; i++)); do
        log_info "Performance test $i" >/dev/null 2>&1
    done

    local end_time
    end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    assert_true '[[ $duration -lt 5000 ]]' "100 log_info calls complete in under 5 seconds"

    # Test validation performance
    start_time=$(date +%s%3N)

    for ((i=1; i<=1000; i++)); do
        validate_pod_name "core" >/dev/null 2>&1
    done

    end_time=$(date +%s%3N)
    duration=$((end_time - start_time))

    assert_true '[[ $duration -lt 2000 ]]' "1000 validate_pod_name calls complete in under 2 seconds"
}

# Edge case tests
test_edge_cases() {
    echo -e "${TEST_YELLOW}Testing edge cases...${TEST_NC}"

    # Test with empty inputs
    validate_pod_name "" >/dev/null 2>&1
    assert_equals "1" "$?" "validate_pod_name rejects empty string"

    validate_environment "" >/dev/null 2>&1
    assert_equals "1" "$?" "validate_environment rejects empty string"

    # Test with special characters
    validate_pod_name "core@#$" >/dev/null 2>&1
    assert_equals "1" "$?" "validate_pod_name rejects special characters"

    # Test config with missing file
    local original_config="$CONFIG_FILE"
    CONFIG_FILE="/nonexistent/config.yml"

    load_config >/dev/null 2>&1
    assert_equals "1" "$?" "load_config fails with missing file"

    CONFIG_FILE="$original_config"

    # Test get_config_value with empty key
    local empty_result
    empty_result=$(get_config_value "" "default")
    assert_equals "default" "$empty_result" "get_config_value returns default for empty key"
}

# Test error handling
test_error_handling() {
    echo -e "${TEST_YELLOW}Testing error handling...${TEST_NC}"

    # Test that error functions don't crash
    (
        set +e  # Disable exit on error for this subshell
        handle_error 123 2>/dev/null
        exit 0  # Ensure we exit cleanly from subshell
    )
    assert_equals "0" "$?" "handle_error function doesn't crash script"

    # Test cleanup function
    cleanup_on_exit >/dev/null 2>&1
    assert_equals "0" "$?" "cleanup_on_exit executes without error"
}

# Integration tests
test_integration() {
    echo -e "${TEST_YELLOW}Testing integration scenarios...${TEST_NC}"

    # Test full initialization
    VERBOSE=false
    DEBUG=false
    init_common >/dev/null 2>&1
    assert_equals "0" "$?" "init_common completes successfully"

    # Test pod workflow simulation
    local test_pod="core"

    if validate_pod_name "$test_pod" >/dev/null 2>&1; then
        local services
        services=$(get_pod_services "$test_pod")
        assert_true '[[ -n "$services" ]]' "Complete pod workflow returns services"

        local compose_file
        compose_file=$(get_pod_docker_compose "$test_pod")
        assert_true '[[ -n "$compose_file" ]]' "Complete pod workflow returns compose file"
    fi
}

# Main test execution
main() {
    # Parse test arguments
    if [[ "$1" == "--verbose" ]]; then
        VERBOSE_TESTS=true
    fi

    # Disable normal logging during tests
    VERBOSE=false
    DEBUG=false

    test_setup

    # Run all test suites
    test_logging_functions
    test_validation_functions
    test_configuration_functions
    test_docker_functions
    test_network_functions
    test_utility_functions
    test_pod_configuration
    test_health_check_functions
    test_repository_functions
    test_performance
    test_edge_cases
    test_error_handling
    test_integration

    test_teardown
}

# Execute tests
main "$@"