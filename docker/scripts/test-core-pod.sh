#!/bin/bash
# Core Pod Testing Script
# DR-336: INFRA-010.3 - Test Supervisor orchestration and process management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="../docker-compose.core-pod.yml"
CORE_POD_CONTAINER="dreamscape-core-pod"
TEST_TIMEOUT=300  # 5 minutes
HEALTH_CHECK_INTERVAL=10

echo -e "${BLUE}🧪 DreamScape Core Pod Testing Suite${NC}"
echo -e "${BLUE}DR-336: INFRA-010.3 - Supervisor Multi-Process Orchestration${NC}"
echo ""

# Function to check if container is running
check_container_running() {
    local container=$1
    if docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        return 0
    else
        return 1
    fi
}

# Function to get container health status
get_container_health() {
    local container=$1
    docker inspect --format="{{.State.Health.Status}}" "$container" 2>/dev/null || echo "unknown"
}

# Function to wait for container health
wait_for_healthy_container() {
    local container=$1
    local timeout=${2:-60}
    local interval=${3:-5}
    
    echo -e "${YELLOW}⏳ Waiting for $container to become healthy...${NC}"
    
    local count=0
    local max_count=$((timeout / interval))
    
    while [ $count -lt $max_count ]; do
        local health=$(get_container_health "$container")
        
        if [ "$health" = "healthy" ]; then
            echo -e "${GREEN}✅ $container is healthy${NC}"
            return 0
        elif [ "$health" = "unhealthy" ]; then
            echo -e "${RED}❌ $container is unhealthy${NC}"
            return 1
        fi
        
        echo -e "${YELLOW}⏳ $container health: $health ($((count + 1))/$max_count)${NC}"
        sleep $interval
        count=$((count + 1))
    done
    
    echo -e "${RED}❌ $container health check timeout${NC}"
    return 1
}

# Function to test HTTP endpoint
test_endpoint() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    
    echo -e "${BLUE}🔗 Testing $name endpoint: $url${NC}"
    
    local response
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" "$url" || echo "HTTPSTATUS:000")
    
    local body=$(echo "$response" | sed -E 's/HTTPSTATUS:[0-9]{3}$//')
    local status=$(echo "$response" | tr -d '\n' | sed -E 's/.*HTTPSTATUS:([0-9]{3})$/\1/')
    
    if [ "$status" = "$expected_status" ]; then
        echo -e "${GREEN}✅ $name: HTTP $status${NC}"
        return 0
    else
        echo -e "${RED}❌ $name: HTTP $status (expected $expected_status)${NC}"
        echo -e "${RED}   Response: $body${NC}"
        return 1
    fi
}

# Function to test Supervisor status
test_supervisor_status() {
    echo -e "${BLUE}🔧 Testing Supervisor status...${NC}"
    
    local supervisor_status
    supervisor_status=$(docker exec "$CORE_POD_CONTAINER" supervisorctl status 2>/dev/null || echo "FAILED")
    
    if [ "$supervisor_status" = "FAILED" ]; then
        echo -e "${RED}❌ Failed to get Supervisor status${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Supervisor status:${NC}"
    echo "$supervisor_status" | while IFS= read -r line; do
        if echo "$line" | grep -q "RUNNING"; then
            echo -e "${GREEN}  ✅ $line${NC}"
        elif echo "$line" | grep -q "STOPPED"; then
            echo -e "${YELLOW}  ⏸️ $line${NC}"
        else
            echo -e "${RED}  ❌ $line${NC}"
        fi
    done
    
    # Check if critical processes are running
    local critical_processes=("auth-service" "user-service" "nginx")
    local failed_processes=()
    
    for process in "${critical_processes[@]}"; do
        if ! echo "$supervisor_status" | grep "$process" | grep -q "RUNNING"; then
            failed_processes+=("$process")
        fi
    done
    
    if [ ${#failed_processes[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ All critical processes are running${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed processes: ${failed_processes[*]}${NC}"
        return 1
    fi
}

# Function to test process restart mechanism
test_process_restart() {
    local process=$1
    
    echo -e "${BLUE}🔄 Testing $process restart mechanism...${NC}"
    
    # Get process PID before restart
    local old_pid
    old_pid=$(docker exec "$CORE_POD_CONTAINER" supervisorctl pid "$process" 2>/dev/null || echo "0")
    
    if [ "$old_pid" = "0" ]; then
        echo -e "${RED}❌ Could not get PID for $process${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}📝 Original $process PID: $old_pid${NC}"
    
    # Restart the process
    echo -e "${YELLOW}🔄 Restarting $process...${NC}"
    docker exec "$CORE_POD_CONTAINER" supervisorctl restart "$process"
    
    # Wait for process to stabilize
    sleep 10
    
    # Get new PID
    local new_pid
    new_pid=$(docker exec "$CORE_POD_CONTAINER" supervisorctl pid "$process" 2>/dev/null || echo "0")
    
    if [ "$new_pid" = "0" ]; then
        echo -e "${RED}❌ Process $process failed to restart${NC}"
        return 1
    fi
    
    if [ "$old_pid" != "$new_pid" ]; then
        echo -e "${GREEN}✅ $process restarted successfully (PID: $old_pid → $new_pid)${NC}"
        return 0
    else
        echo -e "${RED}❌ $process PID unchanged after restart${NC}"
        return 1
    fi
}

# Function to test zombie process prevention
test_zombie_prevention() {
    echo -e "${BLUE}🧟 Testing zombie process prevention...${NC}"
    
    # Check for zombie processes
    local zombie_count
    zombie_count=$(docker exec "$CORE_POD_CONTAINER" ps aux | grep -c "<defunct>" || echo "0")
    
    if [ "$zombie_count" = "0" ]; then
        echo -e "${GREEN}✅ No zombie processes detected${NC}"
    else
        echo -e "${RED}❌ Found $zombie_count zombie processes${NC}"
        docker exec "$CORE_POD_CONTAINER" ps aux | grep "<defunct>" || true
        return 1
    fi
    
    # Check if dumb-init is PID 1
    local pid1_process
    pid1_process=$(docker exec "$CORE_POD_CONTAINER" ps -p 1 -o comm= | tr -d ' ')
    
    if [ "$pid1_process" = "dumb-init" ]; then
        echo -e "${GREEN}✅ dumb-init is PID 1 (proper signal handling)${NC}"
    else
        echo -e "${YELLOW}⚠️ PID 1 is $pid1_process (not dumb-init)${NC}"
    fi
    
    return 0
}

# Function to test graceful shutdown
test_graceful_shutdown() {
    echo -e "${BLUE}🛑 Testing graceful shutdown...${NC}"
    
    # Send SIGTERM to container
    echo -e "${YELLOW}📨 Sending SIGTERM to container...${NC}"
    docker kill --signal=TERM "$CORE_POD_CONTAINER" &
    local kill_pid=$!
    
    # Monitor container status
    local timeout=30
    local count=0
    
    while [ $count -lt $timeout ]; do
        if ! check_container_running "$CORE_POD_CONTAINER"; then
            echo -e "${GREEN}✅ Container stopped gracefully in ${count}s${NC}"
            wait $kill_pid 2>/dev/null || true
            return 0
        fi
        
        sleep 1
        count=$((count + 1))
    done
    
    echo -e "${RED}❌ Container did not stop gracefully within ${timeout}s${NC}"
    docker kill --signal=KILL "$CORE_POD_CONTAINER" 2>/dev/null || true
    wait $kill_pid 2>/dev/null || true
    return 1
}

# Function to test memory monitoring
test_memory_monitoring() {
    echo -e "${BLUE}🧠 Testing memory monitoring...${NC}"
    
    # Check if memory metrics file exists
    if docker exec "$CORE_POD_CONTAINER" test -f /tmp/memory_metrics.json; then
        echo -e "${GREEN}✅ Memory metrics file exists${NC}"
        
        # Get current memory usage
        local memory_info
        memory_info=$(docker exec "$CORE_POD_CONTAINER" cat /tmp/memory_metrics.json | head -20)
        echo -e "${BLUE}📊 Current memory metrics:${NC}"
        echo "$memory_info"
    else
        echo -e "${RED}❌ Memory metrics file not found${NC}"
        return 1
    fi
    
    return 0
}

# Function to run acceptance criteria tests
test_acceptance_criteria() {
    echo -e "${BLUE}🎯 Testing Acceptance Criteria${NC}"
    echo "========================================"
    
    local passed=0
    local total=6
    
    # ✅ Supervisor démarre et gère les 3 services correctement
    echo -e "${YELLOW}1. Supervisor manages 3 services correctly${NC}"
    if test_supervisor_status; then
        ((passed++))
    fi
    echo ""
    
    # ✅ Restart automatique en cas de crash
    echo -e "${YELLOW}2. Automatic restart on crash${NC}"
    if test_process_restart "user-service"; then
        ((passed++))
    fi
    echo ""
    
    # ✅ Arrêt gracieux avec SIGTERM (will restart container after)
    echo -e "${YELLOW}3. Graceful shutdown with SIGTERM${NC}"
    if test_graceful_shutdown; then
        ((passed++))
    fi
    
    # Restart container for remaining tests
    echo -e "${YELLOW}🔄 Restarting container for remaining tests...${NC}"
    docker-compose -f "$COMPOSE_FILE" up -d core-pod
    wait_for_healthy_container "$CORE_POD_CONTAINER" 120
    echo ""
    
    # ✅ Logs agrégés accessibles
    echo -e "${YELLOW}4. Aggregated logs accessible${NC}"
    if docker exec "$CORE_POD_CONTAINER" ls /var/log/supervisor/ | grep -E "(auth-service|user-service|nginx)" >/dev/null; then
        echo -e "${GREEN}✅ Service logs accessible${NC}"
        ((passed++))
    else
        echo -e "${RED}❌ Service logs not accessible${NC}"
    fi
    echo ""
    
    # ✅ Health check global < 5 secondes
    echo -e "${YELLOW}5. Global health check < 5 seconds${NC}"
    local start_time=$(date +%s%N)
    if docker exec "$CORE_POD_CONTAINER" python3 /app/scripts/core_pod_health_check.py >/dev/null 2>&1; then
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))  # Convert to ms
        
        if [ $duration -lt 5000 ]; then
            echo -e "${GREEN}✅ Health check completed in ${duration}ms${NC}"
            ((passed++))
        else
            echo -e "${RED}❌ Health check took ${duration}ms (>5000ms)${NC}"
        fi
    else
        echo -e "${RED}❌ Health check failed${NC}"
    fi
    echo ""
    
    # ✅ Aucun processus zombie détecté
    echo -e "${YELLOW}6. No zombie processes detected${NC}"
    if test_zombie_prevention; then
        ((passed++))
    fi
    echo ""
    
    # Summary
    echo -e "${BLUE}🏆 Acceptance Criteria Results: $passed/$total${NC}"
    
    if [ $passed -eq $total ]; then
        echo -e "${GREEN}🎉 All acceptance criteria passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ $((total - passed)) acceptance criteria failed${NC}"
        return 1
    fi
}

# Main test execution
main() {
    local command=${1:-"all"}
    
    case "$command" in
        "build")
            echo -e "${YELLOW}🔨 Building Core Pod...${NC}"
            docker-compose -f "$COMPOSE_FILE" build core-pod
            ;;
        "start")
            echo -e "${YELLOW}🚀 Starting Core Pod services...${NC}"
            docker-compose -f "$COMPOSE_FILE" up -d
            wait_for_healthy_container "$CORE_POD_CONTAINER" 120
            ;;
        "test-endpoints")
            test_endpoint "NGINX Health" "http://localhost/health"
            test_endpoint "Auth Service" "http://localhost:3001/health"
            test_endpoint "User Service" "http://localhost:3002/health"
            ;;
        "test-supervisor")
            test_supervisor_status
            ;;
        "test-restart")
            test_process_restart "auth-service"
            test_process_restart "user-service"
            ;;
        "test-zombies")
            test_zombie_prevention
            ;;
        "test-memory")
            test_memory_monitoring
            ;;
        "test-shutdown")
            test_graceful_shutdown
            ;;
        "acceptance")
            test_acceptance_criteria
            ;;
        "all")
            echo -e "${YELLOW}🔨 Building and starting services...${NC}"
            docker-compose -f "$COMPOSE_FILE" build core-pod
            docker-compose -f "$COMPOSE_FILE" up -d
            
            echo -e "${YELLOW}⏳ Waiting for services to be ready...${NC}"
            wait_for_healthy_container "$CORE_POD_CONTAINER" 120
            
            echo -e "${YELLOW}🧪 Running comprehensive tests...${NC}"
            test_acceptance_criteria
            ;;
        "stop")
            echo -e "${YELLOW}🛑 Stopping services...${NC}"
            docker-compose -f "$COMPOSE_FILE" down
            ;;
        "logs")
            echo -e "${YELLOW}📜 Core Pod logs:${NC}"
            docker-compose -f "$COMPOSE_FILE" logs core-pod
            ;;
        "status")
            echo -e "${YELLOW}📊 Service status:${NC}"
            docker-compose -f "$COMPOSE_FILE" ps
            echo ""
            if check_container_running "$CORE_POD_CONTAINER"; then
                test_supervisor_status
            fi
            ;;
        *)
            echo -e "${BLUE}DreamScape Core Pod Test Suite${NC}"
            echo ""
            echo -e "${YELLOW}Usage:${NC} $0 [command]"
            echo ""
            echo -e "${YELLOW}Commands:${NC}"
            echo "  build           - Build Core Pod image"
            echo "  start           - Start all services"
            echo "  test-endpoints  - Test HTTP endpoints"
            echo "  test-supervisor - Test Supervisor status"
            echo "  test-restart    - Test process restart mechanisms"
            echo "  test-zombies    - Test zombie process prevention"
            echo "  test-memory     - Test memory monitoring"
            echo "  test-shutdown   - Test graceful shutdown"
            echo "  acceptance      - Run acceptance criteria tests"
            echo "  all             - Build, start, and run all tests"
            echo "  stop            - Stop all services"
            echo "  logs            - Show Core Pod logs"
            echo "  status          - Show service status"
            echo ""
            echo -e "${YELLOW}Examples:${NC}"
            echo "  $0 all              # Full test suite"
            echo "  $0 acceptance       # Acceptance criteria only"
            echo "  $0 test-restart     # Test restart mechanisms"
            ;;
    esac
}

# Execute main function
main "$@"