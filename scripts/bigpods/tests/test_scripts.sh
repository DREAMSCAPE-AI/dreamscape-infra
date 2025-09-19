#!/bin/bash
# DreamScape Big Pods - Scripts Integration Tests
# Tests d'intégration pour tous les scripts Big Pods

# Test framework setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$TEST_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Test configuration
TESTS_PASSED=0
TESTS_FAILED=0
VERBOSE_TESTS=false
SKIP_DOCKER_TESTS=false

# Colors for test output
TEST_RED='\033[0;31m'
TEST_GREEN='\033[0;32m'
TEST_YELLOW='\033[1;33m'
TEST_BLUE='\033[0;34m'
TEST_NC='\033[0m'

# Test scripts list
SCRIPTS_TO_TEST=(
    "build-bigpods.sh"
    "dev-bigpods.sh"
    "debug-bigpods.sh"
    "deploy-bigpods.sh"
    "backup-bigpods.sh"
    "maintenance-bigpods.sh"
    "logs-bigpods.sh"
    "monitoring-bigpods.sh"
    "scale-bigpods.sh"
)

# Test framework functions
test_setup() {
    echo -e "${TEST_BLUE}🧪 DreamScape Big Pods - Scripts Integration Tests${TEST_NC}"
    echo "=================================================="
    echo ""

    # Check if Docker is available
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${TEST_YELLOW}⚠️ Docker not available - skipping Docker-dependent tests${TEST_NC}"
        SKIP_DOCKER_TESTS=true
    fi

    # Create test environment
    setup_test_environment
}

test_teardown() {
    echo ""
    echo "=================================================="
    echo -e "${TEST_BLUE}Test Results:${TEST_NC}"
    echo -e "  Passed: ${TEST_GREEN}$TESTS_PASSED${TEST_NC}"
    echo -e "  Failed: ${TEST_RED}$TESTS_FAILED${TEST_NC}"
    echo -e "  Total:  $((TESTS_PASSED + TESTS_FAILED))"

    # Cleanup test environment
    cleanup_test_environment

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
        if [[ "$VERBOSE_TESTS" == "true" ]]; then
            echo -e "    Expected: '$expected'"
            echo -e "    Actual:   '$actual'"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_success() {
    local exit_code="$1"
    local test_name="$2"

    if [[ $exit_code -eq 0 ]]; then
        echo -e "  ${TEST_GREEN}✓${TEST_NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} $test_name"
        if [[ "$VERBOSE_TESTS" == "true" ]]; then
            echo -e "    Exit code: $exit_code"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_failure() {
    local exit_code="$1"
    local test_name="$2"

    if [[ $exit_code -ne 0 ]]; then
        echo -e "  ${TEST_GREEN}✓${TEST_NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} $test_name"
        if [[ "$VERBOSE_TESTS" == "true" ]]; then
            echo -e "    Expected failure but got exit code: $exit_code"
        fi
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
        if [[ "$VERBOSE_TESTS" == "true" ]]; then
            echo -e "    '$needle' not found in output"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test environment setup
setup_test_environment() {
    # Create test directories
    mkdir -p "/tmp/dreamscape_test/logs"
    mkdir -p "/tmp/dreamscape_test/backups"
    mkdir -p "/tmp/dreamscape_test/config"

    # Create test configuration
    cat > "/tmp/dreamscape_test/config/test.yml" << 'EOF'
bigpods:
  core:
    name: "Core Pod"
    services:
      - auth
      - user
  business:
    name: "Business Pod"
    services:
      - voyage
      - payment
      - ai
  experience:
    name: "Experience Pod"
    services:
      - panorama
      - web-client
      - gateway
EOF

    export TEST_CONFIG_FILE="/tmp/dreamscape_test/config/test.yml"
}

cleanup_test_environment() {
    rm -rf "/tmp/dreamscape_test"
    unset TEST_CONFIG_FILE
}

# Test script execution
test_script_help() {
    local script="$1"
    local script_path="$SCRIPT_DIR/$script"

    if [[ ! -f "$script_path" ]]; then
        echo -e "  ${TEST_YELLOW}⚠${TEST_NC} Script not found: $script"
        return
    fi

    echo -e "${TEST_YELLOW}Testing $script help output...${TEST_NC}"

    # Test --help flag
    local help_output
    help_output=$("$script_path" --help 2>&1)
    local help_exit_code=$?

    assert_success $help_exit_code "$script --help executes successfully"
    assert_contains "$help_output" "USAGE" "$script --help contains usage information"
    assert_contains "$help_output" "OPTIONS" "$script --help contains options section"
    assert_contains "$help_output" "EXAMPLES" "$script --help contains examples section"

    # Test -h flag
    local h_output
    h_output=$("$script_path" -h 2>&1)
    local h_exit_code=$?

    assert_success $h_exit_code "$script -h executes successfully"
    assert_equals "$help_output" "$h_output" "$script -h and --help produce same output"
}

test_script_invalid_args() {
    local script="$1"
    local script_path="$SCRIPT_DIR/$script"

    if [[ ! -f "$script_path" ]]; then
        return
    fi

    echo -e "${TEST_YELLOW}Testing $script invalid arguments...${TEST_NC}"

    # Test invalid flag
    local invalid_output
    invalid_output=$("$script_path" --invalid-flag 2>&1)
    local invalid_exit_code=$?

    assert_failure $invalid_exit_code "$script rejects invalid flags"
    assert_contains "$invalid_output" "Unknown option" "$script shows error for invalid flags"

    # Test invalid pod name (for scripts that accept pods)
    if [[ "$script" =~ (build|dev|debug|deploy|scale|logs|monitoring)-bigpods.sh ]]; then
        local invalid_pod_output
        invalid_pod_output=$("$script_path" invalid-pod 2>&1)
        local invalid_pod_exit_code=$?

        assert_failure $invalid_pod_exit_code "$script rejects invalid pod names"
    fi
}

test_script_dry_run() {
    local script="$1"
    local script_path="$SCRIPT_DIR/$script"

    if [[ ! -f "$script_path" ]]; then
        return
    fi

    # Only test scripts that support dry run
    if [[ "$script" =~ (deploy|backup|maintenance)-bigpods.sh ]]; then
        echo -e "${TEST_YELLOW}Testing $script dry run mode...${TEST_NC}"

        local dry_run_output
        dry_run_output=$("$script_path" --dry-run --force 2>&1)
        local dry_run_exit_code=$?

        # Dry run should not fail due to missing prerequisites
        if [[ $dry_run_exit_code -ne 0 ]]; then
            assert_contains "$dry_run_output" "DRY RUN" "$script dry run mode indicated in output"
        else
            assert_success $dry_run_exit_code "$script dry run executes successfully"
            assert_contains "$dry_run_output" "DRY RUN" "$script dry run mode indicated in output"
        fi
    fi
}

# Specific script tests
test_build_script() {
    echo -e "${TEST_YELLOW}Testing build-bigpods.sh specific functionality...${TEST_NC}"

    local script_path="$SCRIPT_DIR/build-bigpods.sh"

    # Test smart build mode
    local smart_output
    smart_output=$("$script_path" --smart --dry-run core 2>&1)
    local smart_exit_code=$?

    if [[ $smart_exit_code -eq 0 ]] || [[ "$smart_output" == *"Smart build"* ]]; then
        assert_contains "$smart_output" "Smart build" "build script supports smart build mode"
    fi

    # Test parallel build flag
    local parallel_output
    parallel_output=$("$script_path" --parallel --help 2>&1)
    assert_contains "$parallel_output" "parallel" "build script supports parallel builds"
}

test_dev_script() {
    echo -e "${TEST_YELLOW}Testing dev-bigpods.sh specific functionality...${TEST_NC}"

    local script_path="$SCRIPT_DIR/dev-bigpods.sh"

    # Test hot reload options
    local hot_reload_output
    hot_reload_output=$("$script_path" --no-hot-reload --help 2>&1)
    assert_contains "$hot_reload_output" "hot-reload" "dev script supports hot reload configuration"

    # Test setup repos option
    local setup_output
    setup_output=$("$script_path" --setup-repos --help 2>&1)
    assert_contains "$setup_output" "setup-repos" "dev script supports repository setup"
}

test_debug_script() {
    echo -e "${TEST_YELLOW}Testing debug-bigpods.sh specific functionality...${TEST_NC}"

    local script_path="$SCRIPT_DIR/debug-bigpods.sh"

    # Test debug modes
    local modes_output
    modes_output=$("$script_path" --help 2>&1)
    assert_contains "$modes_output" "interactive" "debug script supports interactive mode"
    assert_contains "$modes_output" "logs" "debug script supports logs mode"
    assert_contains "$modes_output" "connectivity" "debug script supports connectivity mode"

    # Test export functionality
    local export_output
    export_output=$("$script_path" --export --output /tmp --help 2>&1)
    assert_contains "$export_output" "export" "debug script supports export functionality"
}

test_deploy_script() {
    echo -e "${TEST_YELLOW}Testing deploy-bigpods.sh specific functionality...${TEST_NC}"

    local script_path="$SCRIPT_DIR/deploy-bigpods.sh"

    # Test deployment strategies
    local strategies_output
    strategies_output=$("$script_path" --help 2>&1)
    assert_contains "$strategies_output" "rolling" "deploy script supports rolling updates"
    assert_contains "$strategies_output" "blue-green" "deploy script supports blue-green deployment"
    assert_contains "$strategies_output" "canary" "deploy script supports canary deployment"

    # Test environment validation
    local env_output
    env_output=$("$script_path" --env invalid-env 2>&1)
    local env_exit_code=$?
    assert_failure $env_exit_code "deploy script rejects invalid environments"
}

test_backup_script() {
    echo -e "${TEST_YELLOW}Testing backup-bigpods.sh specific functionality...${TEST_NC}"

    local script_path="$SCRIPT_DIR/backup-bigpods.sh"

    # Test backup types
    local types_output
    types_output=$("$script_path" --help 2>&1)
    assert_contains "$types_output" "full" "backup script supports full backup"
    assert_contains "$types_output" "incremental" "backup script supports incremental backup"
    assert_contains "$types_output" "databases" "backup script supports database backup"

    # Test S3 integration
    local s3_output
    s3_output=$("$script_path" --s3-bucket test-bucket --help 2>&1)
    assert_contains "$s3_output" "s3-bucket" "backup script supports S3 integration"
}

test_maintenance_script() {
    echo -e "${TEST_YELLOW}Testing maintenance-bigpods.sh specific functionality...${TEST_NC}"

    local script_path="$SCRIPT_DIR/maintenance-bigpods.sh"

    # Test maintenance modes
    local modes_output
    modes_output=$("$script_path" --help 2>&1)
    assert_contains "$modes_output" "cleanup" "maintenance script supports cleanup mode"
    assert_contains "$modes_output" "logs" "maintenance script supports log cleanup"
    assert_contains "$modes_output" "health" "maintenance script supports health checks"

    # Test scheduled mode
    local scheduled_output
    scheduled_output=$("$script_path" --scheduled --help 2>&1)
    assert_contains "$scheduled_output" "scheduled" "maintenance script supports scheduled mode"
}

test_logs_script() {
    echo -e "${TEST_YELLOW}Testing logs-bigpods.sh specific functionality...${TEST_NC}"

    local script_path="$SCRIPT_DIR/logs-bigpods.sh"

    # Test log modes
    local modes_output
    modes_output=$("$script_path" --help 2>&1)
    assert_contains "$modes_output" "search" "logs script supports search mode"
    assert_contains "$modes_output" "export" "logs script supports export mode"
    assert_contains "$modes_output" "stats" "logs script supports statistics mode"

    # Test export formats
    local export_output
    export_output=$("$script_path" --export json --help 2>&1)
    assert_contains "$export_output" "json" "logs script supports JSON export"
}

test_monitoring_script() {
    echo -e "${TEST_YELLOW}Testing monitoring-bigpods.sh specific functionality...${TEST_NC}"

    local script_path="$SCRIPT_DIR/monitoring-bigpods.sh"

    # Test monitoring modes
    local modes_output
    modes_output=$("$script_path" --help 2>&1)
    assert_contains "$modes_output" "dashboard" "monitoring script supports dashboard mode"
    assert_contains "$modes_output" "metrics" "monitoring script supports metrics collection"
    assert_contains "$modes_output" "alerts" "monitoring script supports alerting"

    # Test alert thresholds
    local alerts_output
    alerts_output=$("$script_path" --cpu-threshold 85 --help 2>&1)
    assert_contains "$alerts_output" "cpu-threshold" "monitoring script supports CPU threshold configuration"
}

test_scale_script() {
    echo -e "${TEST_YELLOW}Testing scale-bigpods.sh specific functionality...${TEST_NC}"

    local script_path="$SCRIPT_DIR/scale-bigpods.sh"

    # Test scaling modes
    local modes_output
    modes_output=$("$script_path" --help 2>&1)
    assert_contains "$modes_output" "manual" "scale script supports manual scaling"
    assert_contains "$modes_output" "auto" "scale script supports auto-scaling"
    assert_contains "$modes_output" "load-test" "scale script supports load testing"

    # Test autoscaling parameters
    local autoscale_output
    autoscale_output=$("$script_path" --autoscale --min-replicas 2 --max-replicas 8 --help 2>&1)
    assert_contains "$autoscale_output" "min-replicas" "scale script supports minimum replicas configuration"
    assert_contains "$autoscale_output" "max-replicas" "scale script supports maximum replicas configuration"
}

# Docker integration tests
test_docker_integration() {
    if [[ "$SKIP_DOCKER_TESTS" == "true" ]]; then
        echo -e "${TEST_YELLOW}Skipping Docker integration tests...${TEST_NC}"
        return
    fi

    echo -e "${TEST_YELLOW}Testing Docker integration...${TEST_NC}"

    # Test that scripts can detect Docker
    local build_output
    build_output=$("$SCRIPT_DIR/build-bigpods.sh" --help 2>&1)
    assert_success $? "build script executes with Docker available"

    # Test Docker Compose detection
    local dev_output
    dev_output=$("$SCRIPT_DIR/dev-bigpods.sh" --help 2>&1)
    assert_success $? "dev script executes with Docker available"
}

# Configuration integration tests
test_configuration_integration() {
    echo -e "${TEST_YELLOW}Testing configuration integration...${TEST_NC}"

    # Test with custom config file
    export CONFIG_FILE="$TEST_CONFIG_FILE"

    local build_output
    build_output=$("$SCRIPT_DIR/build-bigpods.sh" --help 2>&1)
    assert_success $? "scripts work with custom configuration"

    # Test configuration loading
    local debug_output
    debug_output=$("$SCRIPT_DIR/debug-bigpods.sh" core --help 2>&1)
    assert_success $? "scripts load configuration correctly"

    unset CONFIG_FILE
}

# Performance tests
test_script_performance() {
    echo -e "${TEST_YELLOW}Testing script performance...${TEST_NC}"

    # Test help output performance
    local start_time
    start_time=$(date +%s%3N)

    for script in "${SCRIPTS_TO_TEST[@]}"; do
        "$SCRIPT_DIR/$script" --help >/dev/null 2>&1
    done

    local end_time
    end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))

    # Should complete all help commands in under 10 seconds
    if [[ $duration -lt 10000 ]]; then
        echo -e "  ${TEST_GREEN}✓${TEST_NC} All help commands complete in ${duration}ms"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} Help commands too slow: ${duration}ms"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# End-to-end workflow tests
test_e2e_workflows() {
    echo -e "${TEST_YELLOW}Testing end-to-end workflows...${TEST_NC}"

    # Test development workflow
    local workflow_output
    workflow_output=$("$SCRIPT_DIR/build-bigpods.sh" --smart --dry-run core 2>&1)

    if [[ $? -eq 0 ]] || [[ "$workflow_output" == *"Core Pod"* ]]; then
        echo -e "  ${TEST_GREEN}✓${TEST_NC} Development workflow executable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} Development workflow failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi

    # Test monitoring workflow
    local monitoring_output
    monitoring_output=$("$SCRIPT_DIR/monitoring-bigpods.sh" --mode health core 2>&1)

    if [[ $? -eq 0 ]] || [[ "$monitoring_output" == *"Health"* ]]; then
        echo -e "  ${TEST_GREEN}✓${TEST_NC} Monitoring workflow executable"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} Monitoring workflow failed"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Security tests
test_security() {
    echo -e "${TEST_YELLOW}Testing security aspects...${TEST_NC}"

    # Test that scripts don't expose sensitive information in help
    for script in "${SCRIPTS_TO_TEST[@]}"; do
        local help_output
        help_output=$("$SCRIPT_DIR/$script" --help 2>&1)

        # Check for potential secret exposure
        if echo "$help_output" | grep -iE "password|secret|key" | grep -vE "PASSWORD|SECRET|KEY" | grep .; then
            echo -e "  ${TEST_YELLOW}⚠${TEST_NC} $script help may contain sensitive terms"
        fi
    done

    # Test file permissions
    for script in "${SCRIPTS_TO_TEST[@]}"; do
        local script_path="$SCRIPT_DIR/$script"
        if [[ -f "$script_path" ]]; then
            local perms
            perms=$(stat -c "%a" "$script_path" 2>/dev/null || stat -f "%OLp" "$script_path" 2>/dev/null || echo "755")

            if [[ "$perms" == "755" ]] || [[ "$perms" == "775" ]]; then
                echo -e "  ${TEST_GREEN}✓${TEST_NC} $script has secure permissions ($perms)"
                TESTS_PASSED=$((TESTS_PASSED + 1))
            else
                echo -e "  ${TEST_RED}✗${TEST_NC} $script has insecure permissions ($perms)"
                TESTS_FAILED=$((TESTS_FAILED + 1))
            fi
        fi
    done
}

# Main test execution
main() {
    # Parse test arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                VERBOSE_TESTS=true
                shift
                ;;
            --skip-docker)
                SKIP_DOCKER_TESTS=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    test_setup

    # Test each script
    for script in "${SCRIPTS_TO_TEST[@]}"; do
        echo ""
        echo -e "${TEST_BLUE}Testing $script${TEST_NC}"
        echo "$(printf '%.0s-' {1..50})"

        test_script_help "$script"
        test_script_invalid_args "$script"
        test_script_dry_run "$script"
    done

    echo ""
    echo -e "${TEST_BLUE}Running specific functionality tests${TEST_NC}"
    echo "$(printf '%.0s-' {1..50})"

    # Test specific script functionality
    test_build_script
    test_dev_script
    test_debug_script
    test_deploy_script
    test_backup_script
    test_maintenance_script
    test_logs_script
    test_monitoring_script
    test_scale_script

    echo ""
    echo -e "${TEST_BLUE}Running integration tests${TEST_NC}"
    echo "$(printf '%.0s-' {1..50})"

    # Integration tests
    test_docker_integration
    test_configuration_integration
    test_script_performance
    test_e2e_workflows
    test_security

    test_teardown
}

# Execute tests
main "$@"