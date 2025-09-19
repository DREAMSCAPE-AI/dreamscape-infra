#!/bin/bash
# DreamScape Big Pods - Test Runner
# Exécute tous les tests pour la suite Big Pods

# Test runner configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$TEST_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Test configuration
VERBOSE_TESTS=false
SKIP_DOCKER_TESTS=false
SKIP_INTEGRATION_TESTS=false
PARALLEL_TESTS=false
GENERATE_REPORT=true
COVERAGE_ANALYSIS=false

# Test results
TOTAL_TESTS_PASSED=0
TOTAL_TESTS_FAILED=0
TEST_SUITES_PASSED=0
TEST_SUITES_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Usage function
show_usage() {
    echo -e "${BLUE}🧪 DreamScape Big Pods - Test Runner${NC}"
    echo ""
    echo -e "${WHITE}USAGE:${NC}"
    echo "  $0 [OPTIONS]"
    echo ""
    echo -e "${WHITE}OPTIONS:${NC}"
    echo "  --verbose              Verbose test output"
    echo "  --skip-docker          Skip Docker-dependent tests"
    echo "  --skip-integration     Skip integration tests"
    echo "  --parallel             Run test suites in parallel"
    echo "  --no-report            Skip test report generation"
    echo "  --coverage             Enable coverage analysis"
    echo "  -h, --help             Show this help"
    echo ""
    echo -e "${WHITE}TEST SUITES:${NC}"
    echo "  • Common Library Tests (test_common.sh)"
    echo "  • Scripts Integration Tests (test_scripts.sh)"
    echo "  • Performance Tests"
    echo "  • Security Tests"
    echo ""
    echo -e "${WHITE}EXAMPLES:${NC}"
    echo "  $0                     # Run all tests"
    echo "  $0 --verbose           # Run with verbose output"
    echo "  $0 --skip-docker       # Skip Docker tests"
    echo "  $0 --parallel          # Run tests in parallel"
}

# Parse command line arguments
parse_args() {
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
            --skip-integration)
                SKIP_INTEGRATION_TESTS=true
                shift
                ;;
            --parallel)
                PARALLEL_TESTS=true
                shift
                ;;
            --no-report)
                GENERATE_REPORT=false
                shift
                ;;
            --coverage)
                COVERAGE_ANALYSIS=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Test environment setup
setup_test_environment() {
    echo -e "${YELLOW}Setting up test environment...${NC}"

    # Create test directories
    mkdir -p "/tmp/dreamscape_tests"
    mkdir -p "/tmp/dreamscape_tests/reports"
    mkdir -p "/tmp/dreamscape_tests/coverage"
    mkdir -p "/tmp/dreamscape_tests/logs"

    # Set test environment variables
    export DREAMSCAPE_TEST_MODE=true
    export DREAMSCAPE_TEST_DIR="/tmp/dreamscape_tests"

    # Check prerequisites
    check_test_prerequisites
}

check_test_prerequisites() {
    echo -e "${CYAN}Checking test prerequisites...${NC}"

    # Check bash version
    local bash_version
    bash_version=$(bash --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
    local major_version
    major_version=$(echo "$bash_version" | cut -d. -f1)

    if [[ $major_version -ge 4 ]]; then
        echo -e "  ${GREEN}✓${NC} Bash $bash_version"
    else
        echo -e "  ${YELLOW}⚠${NC} Bash $bash_version (may have compatibility issues)"
    fi

    # Check Docker if not skipping
    if [[ "$SKIP_DOCKER_TESTS" != "true" ]]; then
        if command -v docker >/dev/null 2>&1; then
            if docker info >/dev/null 2>&1; then
                echo -e "  ${GREEN}✓${NC} Docker $(docker --version | cut -d' ' -f3 | tr -d ',')"
            else
                echo -e "  ${YELLOW}⚠${NC} Docker installed but not running"
                SKIP_DOCKER_TESTS=true
            fi
        else
            echo -e "  ${YELLOW}⚠${NC} Docker not available"
            SKIP_DOCKER_TESTS=true
        fi
    fi

    # Check other utilities
    local utilities=("curl" "grep" "awk" "sed" "jq")
    for util in "${utilities[@]}"; do
        if command -v "$util" >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} $util"
        else
            echo -e "  ${YELLOW}⚠${NC} $util not available (some tests may be skipped)"
        fi
    done

    echo ""
}

# Run a single test suite
run_test_suite() {
    local test_script="$1"
    local test_name="$2"
    local test_args="$3"

    echo -e "${BLUE}Running $test_name...${NC}"
    echo "$(printf '%.0s-' {1..60})"

    local test_start_time
    test_start_time=$(date +%s)

    local test_output_file="/tmp/dreamscape_tests/logs/${test_name// /_}.log"
    local test_result_file="/tmp/dreamscape_tests/results/${test_name// /_}.result"

    mkdir -p "$(dirname "$test_output_file")"
    mkdir -p "$(dirname "$test_result_file")"

    # Run the test
    local test_exit_code
    if [[ "$VERBOSE_TESTS" == "true" ]]; then
        "$test_script" $test_args 2>&1 | tee "$test_output_file"
        test_exit_code=${PIPESTATUS[0]}
    else
        "$test_script" $test_args > "$test_output_file" 2>&1
        test_exit_code=$?
    fi

    local test_end_time
    test_end_time=$(date +%s)
    local test_duration=$((test_end_time - test_start_time))

    # Parse test results
    local tests_passed=0
    local tests_failed=0

    if [[ -f "$test_output_file" ]]; then
        tests_passed=$(grep -c "✓" "$test_output_file" 2>/dev/null || echo "0")
        tests_failed=$(grep -c "✗" "$test_output_file" 2>/dev/null || echo "0")
    fi

    # Store results
    cat > "$test_result_file" << EOF
{
    "test_suite": "$test_name",
    "exit_code": $test_exit_code,
    "duration": $test_duration,
    "tests_passed": $tests_passed,
    "tests_failed": $tests_failed,
    "output_file": "$test_output_file"
}
EOF

    # Update totals
    TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + tests_passed))
    TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + tests_failed))

    # Show results
    if [[ $test_exit_code -eq 0 ]]; then
        echo -e "${GREEN}✅ $test_name PASSED${NC} (${test_duration}s, $tests_passed passed, $tests_failed failed)"
        TEST_SUITES_PASSED=$((TEST_SUITES_PASSED + 1))
    else
        echo -e "${RED}❌ $test_name FAILED${NC} (${test_duration}s, exit code: $test_exit_code)"
        TEST_SUITES_FAILED=$((TEST_SUITES_FAILED + 1))

        # Show last few lines of output for failed tests
        if [[ "$VERBOSE_TESTS" != "true" ]]; then
            echo -e "${YELLOW}Last 10 lines of output:${NC}"
            tail -10 "$test_output_file" | sed 's/^/  /'
        fi
    fi

    echo ""
    return $test_exit_code
}

# Run test suites in parallel
run_tests_parallel() {
    echo -e "${PURPLE}Running test suites in parallel...${NC}"
    echo ""

    local test_pids=()
    local test_names=()

    # Start background test processes
    if [[ -f "$TEST_DIR/test_common.sh" ]]; then
        (
            run_test_suite "$TEST_DIR/test_common.sh" "Common Library Tests" "${VERBOSE_TESTS:+--verbose}"
            echo $? > "/tmp/dreamscape_tests/results/common.exit_code"
        ) &
        test_pids+=($!)
        test_names+=("Common Library Tests")
    fi

    if [[ -f "$TEST_DIR/test_scripts.sh" ]]; then
        local script_args=""
        [[ "$VERBOSE_TESTS" == "true" ]] && script_args="$script_args --verbose"
        [[ "$SKIP_DOCKER_TESTS" == "true" ]] && script_args="$script_args --skip-docker"

        (
            run_test_suite "$TEST_DIR/test_scripts.sh" "Scripts Integration Tests" "$script_args"
            echo $? > "/tmp/dreamscape_tests/results/scripts.exit_code"
        ) &
        test_pids+=($!)
        test_names+=("Scripts Integration Tests")
    fi

    # Wait for all tests to complete
    local all_passed=true
    for i in "${!test_pids[@]}"; do
        local pid=${test_pids[$i]}
        local name=${test_names[$i]}

        echo -e "${CYAN}Waiting for: $name (PID: $pid)${NC}"
        wait "$pid"

        # Check exit code from file
        local exit_code_file="/tmp/dreamscape_tests/results/${name// /_}.exit_code"
        if [[ -f "$exit_code_file" ]]; then
            local exit_code
            exit_code=$(cat "$exit_code_file")
            if [[ $exit_code -ne 0 ]]; then
                all_passed=false
            fi
        else
            all_passed=false
        fi
    done

    return $([ "$all_passed" = true ] && echo 0 || echo 1)
}

# Run test suites sequentially
run_tests_sequential() {
    echo -e "${PURPLE}Running test suites sequentially...${NC}"
    echo ""

    local all_passed=true

    # Run common library tests
    if [[ -f "$TEST_DIR/test_common.sh" ]]; then
        if ! run_test_suite "$TEST_DIR/test_common.sh" "Common Library Tests" "${VERBOSE_TESTS:+--verbose}"; then
            all_passed=false
        fi
    fi

    # Run scripts integration tests
    if [[ -f "$TEST_DIR/test_scripts.sh" ]]; then
        local script_args=""
        [[ "$VERBOSE_TESTS" == "true" ]] && script_args="$script_args --verbose"
        [[ "$SKIP_DOCKER_TESTS" == "true" ]] && script_args="$script_args --skip-docker"

        if ! run_test_suite "$TEST_DIR/test_scripts.sh" "Scripts Integration Tests" "$script_args"; then
            all_passed=false
        fi
    fi

    if [ "$all_passed" = true ]; then
        return 0
    else
        return 1
    fi
}

# Run performance tests
run_performance_tests() {
    if [[ "$SKIP_INTEGRATION_TESTS" == "true" ]]; then
        return 0
    fi

    echo -e "${PURPLE}Running performance tests...${NC}"
    echo "$(printf '%.0s-' {1..60})"

    local perf_start_time
    perf_start_time=$(date +%s)

    # Test script startup time
    echo -e "${CYAN}Testing script startup performance...${NC}"

    local scripts=(
        "build-bigpods.sh"
        "dev-bigpods.sh"
        "debug-bigpods.sh"
        "deploy-bigpods.sh"
        "logs-bigpods.sh"
        "monitoring-bigpods.sh"
        "scale-bigpods.sh"
    )

    local total_startup_time=0
    local successful_tests=0

    for script in "${scripts[@]}"; do
        local script_path="$SCRIPT_DIR/$script"
        if [[ -f "$script_path" ]]; then
            local start_time
            start_time=$(date +%s%3N)

            "$script_path" --help >/dev/null 2>&1

            local end_time
            end_time=$(date +%s%3N)
            local startup_time=$((end_time - start_time))

            total_startup_time=$((total_startup_time + startup_time))
            successful_tests=$((successful_tests + 1))

            if [[ $startup_time -lt 2000 ]]; then  # Under 2 seconds
                echo -e "  ${GREEN}✓${NC} $script: ${startup_time}ms"
                TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + 1))
            else
                echo -e "  ${YELLOW}⚠${NC} $script: ${startup_time}ms (slow)"
                TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + 1))
            fi
        fi
    done

    local avg_startup_time=0
    if [[ $successful_tests -gt 0 ]]; then
        avg_startup_time=$((total_startup_time / successful_tests))
    fi

    local perf_end_time
    perf_end_time=$(date +%s)
    local perf_duration=$((perf_end_time - perf_start_time))

    echo ""
    echo -e "${CYAN}Performance Summary:${NC}"
    echo -e "  • Average startup time: ${avg_startup_time}ms"
    echo -e "  • Total performance test time: ${perf_duration}s"

    if [[ $avg_startup_time -lt 1000 ]]; then
        echo -e "  ${GREEN}✅ Performance tests PASSED${NC}"
        TEST_SUITES_PASSED=$((TEST_SUITES_PASSED + 1))
        return 0
    else
        echo -e "  ${YELLOW}⚠️ Performance tests show room for improvement${NC}"
        TEST_SUITES_FAILED=$((TEST_SUITES_FAILED + 1))
        return 1
    fi
}

# Run security tests
run_security_tests() {
    echo -e "${PURPLE}Running security tests...${NC}"
    echo "$(printf '%.0s-' {1..60})"

    local security_issues=0

    # Check script permissions
    echo -e "${CYAN}Checking script permissions...${NC}"

    local scripts=("$SCRIPT_DIR"/*.sh)
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            local perms
            perms=$(stat -c "%a" "$script" 2>/dev/null || stat -f "%OLp" "$script" 2>/dev/null || echo "000")

            if [[ "$perms" =~ ^[67][57][57]$ ]]; then
                echo -e "  ${GREEN}✓${NC} $(basename "$script"): $perms"
                TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + 1))
            else
                echo -e "  ${RED}✗${NC} $(basename "$script"): $perms (insecure)"
                TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + 1))
                security_issues=$((security_issues + 1))
            fi
        fi
    done

    # Check for hardcoded secrets
    echo -e "${CYAN}Checking for hardcoded secrets...${NC}"

    local secret_patterns=("password.*=" "secret.*=" "key.*=" "token.*=")
    local files_with_secrets=0

    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            for pattern in "${secret_patterns[@]}"; do
                if grep -qi "$pattern" "$script" && ! grep -q "# Test" "$script"; then
                    echo -e "  ${YELLOW}⚠${NC} $(basename "$script"): potential secret pattern '$pattern'"
                    files_with_secrets=$((files_with_secrets + 1))
                    break
                fi
            done
        fi
    done

    if [[ $files_with_secrets -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} No hardcoded secrets detected"
        TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} $files_with_secrets files may contain secrets"
        TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + 1))
    fi

    # Check for shell injection vulnerabilities
    echo -e "${CYAN}Checking for shell injection vulnerabilities...${NC}"

    local vulnerable_patterns=('eval.*\$' 'exec.*\$' '`.*\$' '\$\(.*\$.*\)')
    local vulnerable_files=0

    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            for pattern in "${vulnerable_patterns[@]}"; do
                if grep -qE "$pattern" "$script"; then
                    echo -e "  ${YELLOW}⚠${NC} $(basename "$script"): potential injection pattern '$pattern'"
                    vulnerable_files=$((vulnerable_files + 1))
                    break
                fi
            done
        fi
    done

    if [[ $vulnerable_files -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} No obvious injection vulnerabilities detected"
        TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + 1))
    else
        echo -e "  ${YELLOW}⚠${NC} $vulnerable_files files may have injection risks"
        TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + 1))
    fi

    echo ""
    if [[ $security_issues -eq 0 ]]; then
        echo -e "${GREEN}✅ Security tests PASSED${NC}"
        TEST_SUITES_PASSED=$((TEST_SUITES_PASSED + 1))
        return 0
    else
        echo -e "${YELLOW}⚠️ Security tests found $security_issues issues${NC}"
        TEST_SUITES_FAILED=$((TEST_SUITES_FAILED + 1))
        return 1
    fi
}

# Generate test report
generate_test_report() {
    if [[ "$GENERATE_REPORT" != "true" ]]; then
        return 0
    fi

    echo -e "${CYAN}Generating test report...${NC}"

    local report_file="/tmp/dreamscape_tests/reports/test_report_$(date +%Y%m%d_%H%M%S).html"
    local json_report="/tmp/dreamscape_tests/reports/test_report_$(date +%Y%m%d_%H%M%S).json"

    # Generate JSON report
    cat > "$json_report" << EOF
{
    "test_run": {
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "duration": "$(( $(date +%s) - ${TOTAL_START_TIME:-$(date +%s)} ))",
        "environment": {
            "os": "$(uname -s)",
            "shell": "$BASH_VERSION",
            "docker_available": $([ "$SKIP_DOCKER_TESTS" != "true" ] && echo "true" || echo "false")
        }
    },
    "summary": {
        "total_tests": $((TOTAL_TESTS_PASSED + TOTAL_TESTS_FAILED)),
        "tests_passed": $TOTAL_TESTS_PASSED,
        "tests_failed": $TOTAL_TESTS_FAILED,
        "test_suites_passed": $TEST_SUITES_PASSED,
        "test_suites_failed": $TEST_SUITES_FAILED,
        "success_rate": $(echo "scale=2; $TOTAL_TESTS_PASSED * 100 / ($TOTAL_TESTS_PASSED + $TOTAL_TESTS_FAILED)" | bc -l 2>/dev/null || echo "0")
    },
    "test_suites": []
}
EOF

    # Generate HTML report
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>DreamScape Big Pods - Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #2196F3; color: white; padding: 20px; border-radius: 5px; }
        .summary { background: #f5f5f5; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .passed { color: #4CAF50; }
        .failed { color: #f44336; }
        .warning { color: #FF9800; }
        .test-suite { margin: 10px 0; padding: 10px; border-left: 4px solid #2196F3; }
        .test-details { margin: 10px 0; padding: 10px; background: #f9f9f9; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🧪 DreamScape Big Pods - Test Report</h1>
        <p>Generated: $(date)</p>
    </div>

    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Total Tests:</strong> $((TOTAL_TESTS_PASSED + TOTAL_TESTS_FAILED))</p>
        <p class="passed"><strong>Passed:</strong> $TOTAL_TESTS_PASSED</p>
        <p class="failed"><strong>Failed:</strong> $TOTAL_TESTS_FAILED</p>
        <p><strong>Test Suites Passed:</strong> $TEST_SUITES_PASSED</p>
        <p><strong>Test Suites Failed:</strong> $TEST_SUITES_FAILED</p>
    </div>

    <div class="test-details">
        <h2>Test Results</h2>
        <p>Detailed test results are available in the log files:</p>
        <ul>
EOF

    # Add log file links
    for log_file in /tmp/dreamscape_tests/logs/*.log; do
        if [[ -f "$log_file" ]]; then
            echo "            <li><a href=\"file://$log_file\">$(basename "$log_file")</a></li>" >> "$report_file"
        fi
    done

    cat >> "$report_file" << 'EOF'
        </ul>
    </div>
</body>
</html>
EOF

    echo -e "${GREEN}✓${NC} Test report generated: $report_file"
    echo -e "${GREEN}✓${NC} JSON report generated: $json_report"
}

# Cleanup test environment
cleanup_test_environment() {
    echo -e "${CYAN}Cleaning up test environment...${NC}"

    # Keep reports and logs, clean up temporary files
    rm -rf "/tmp/dreamscape_tests/temp"

    # Unset test environment variables
    unset DREAMSCAPE_TEST_MODE
    unset DREAMSCAPE_TEST_DIR

    echo -e "${GREEN}✓${NC} Test environment cleaned up"
}

# Show final summary
show_final_summary() {
    echo ""
    echo "=================================================================="
    echo -e "${BLUE}🧪 DreamScape Big Pods - Test Suite Summary${NC}"
    echo "=================================================================="
    echo ""

    local total_tests=$((TOTAL_TESTS_PASSED + TOTAL_TESTS_FAILED))
    local total_suites=$((TEST_SUITES_PASSED + TEST_SUITES_FAILED))
    local success_rate=0

    if [[ $total_tests -gt 0 ]]; then
        success_rate=$(echo "scale=1; $TOTAL_TESTS_PASSED * 100 / $total_tests" | bc -l 2>/dev/null || echo "0")
    fi

    echo -e "${WHITE}Test Results:${NC}"
    echo -e "  Total Tests: $total_tests"
    echo -e "  Passed: ${GREEN}$TOTAL_TESTS_PASSED${NC}"
    echo -e "  Failed: ${RED}$TOTAL_TESTS_FAILED${NC}"
    echo -e "  Success Rate: ${success_rate}%"
    echo ""

    echo -e "${WHITE}Test Suites:${NC}"
    echo -e "  Total Suites: $total_suites"
    echo -e "  Passed: ${GREEN}$TEST_SUITES_PASSED${NC}"
    echo -e "  Failed: ${RED}$TEST_SUITES_FAILED${NC}"
    echo ""

    if [[ $TOTAL_TESTS_FAILED -eq 0 ]] && [[ $TEST_SUITES_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
        echo ""
        echo -e "${GREEN}The DreamScape Big Pods automation suite is ready for production!${NC}"
        return 0
    else
        echo -e "${RED}❌ SOME TESTS FAILED${NC}"
        echo ""
        echo -e "${YELLOW}Please review the test results and fix any issues before deployment.${NC}"
        return 1
    fi
}

# Main function
main() {
    local TOTAL_START_TIME
    TOTAL_START_TIME=$(date +%s)

    # Parse arguments
    parse_args "$@"

    echo -e "${BLUE}🧪 DreamScape Big Pods - Test Suite Runner${NC}"
    echo -e "${BLUE}Comprehensive testing for Big Pods automation${NC}"
    echo ""

    # Setup test environment
    setup_test_environment

    # Run main test suites
    local main_tests_passed=true

    if [[ "$PARALLEL_TESTS" == "true" ]]; then
        if ! run_tests_parallel; then
            main_tests_passed=false
        fi
    else
        if ! run_tests_sequential; then
            main_tests_passed=false
        fi
    fi

    # Run additional test suites
    if ! run_performance_tests; then
        main_tests_passed=false
    fi

    if ! run_security_tests; then
        main_tests_passed=false
    fi

    # Generate report
    generate_test_report

    # Cleanup
    cleanup_test_environment

    # Show final summary
    show_final_summary

    local TOTAL_END_TIME
    TOTAL_END_TIME=$(date +%s)
    local TOTAL_DURATION=$((TOTAL_END_TIME - TOTAL_START_TIME))

    echo -e "${CYAN}Total execution time: ${TOTAL_DURATION}s${NC}"

    # Exit with appropriate code
    if [[ "$main_tests_passed" == "true" ]]; then
        exit 0
    else
        exit 1
    fi
}

# Execute test runner
main "$@"