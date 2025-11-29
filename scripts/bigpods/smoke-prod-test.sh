#!/bin/bash
# filepath: /home/nico/Documents/DREAMSCAPE-PROJECT/dreamscape-infra/docker/scripts/smoke-test-bigpods.sh
set -euo pipefail

# DreamScape Big Pods - Smoke Test Script for Docker Swarm
# Validates that all services are running and healthy in production mode
# Exit code 0 = all tests passed, 1 = one or more tests failed

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$DOCKER_DIR/docker-compose.bigpods.prod.yml"
STACK_NAME="bigpods"

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  DreamScape Big Pods - Smoke Test Suite (Swarm)     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}\n"

# ===============================================
# Helper Functions
# ===============================================

# Test HTTP endpoint
test_http_endpoint() {
    local name=$1
    local url=$2
    local expected_status=${3:-200}
    local timeout=${4:-10}

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Testing $name... "

    local response
    local http_code

    # Make HTTP request with timeout
    response=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>&1)
    http_code=$?

    if [ $http_code -eq 0 ]; then
        if [ "$response" == "$expected_status" ] || [ "$response" -ge 200 -a "$response" -lt 400 ]; then
            echo -e "${GREEN}✓ PASSED${NC} (HTTP $response)"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${RED}✗ FAILED${NC} (HTTP $response, expected $expected_status)"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    else
        echo -e "${RED}✗ FAILED${NC} (Connection failed or timeout)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Test TCP port
test_tcp_port() {
    local name=$1
    local host=$2
    local port=$3
    local timeout=${4:-5}

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Testing $name ($host:$port)... "

    if timeout "$timeout" bash -c "echo > /dev/tcp/$host/$port" 2>/dev/null; then
        echo -e "${GREEN}✓ PASSED${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Test Docker Swarm service health
test_service_health() {
    local name=$1
    local service=$2

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Testing $name service health... "

    # Check if service exists
    if ! docker service ls --filter "name=${STACK_NAME}_${service}" --format "{{.Name}}" | grep -q "${STACK_NAME}_${service}"; then
        echo -e "${RED}✗ FAILED${NC} (service not found)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    # Get replicas status
    local replicas
    replicas=$(docker service ls --filter "name=${STACK_NAME}_${service}" --format "{{.Replicas}}")

    if echo "$replicas" | grep -q "/"; then
        local current=$(echo "$replicas" | cut -d'/' -f1)
        local desired=$(echo "$replicas" | cut -d'/' -f2)

        if [ "$current" = "$desired" ] && [ "$current" != "0" ]; then
            echo -e "${GREEN}✓ PASSED${NC} ($replicas replicas)"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${RED}✗ FAILED${NC} ($replicas - not all replicas running)"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    else
        echo -e "${RED}✗ FAILED${NC} (invalid replica status)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Test Docker container health (for a specific container in swarm)
test_container_health() {
    local name=$1
    local service_name="${STACK_NAME}_${2}"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Testing $name container health... "

    # Get one container ID from the service
    local container_id
    container_id=$(docker ps -q --filter "name=${service_name}" | head -1)

    if [ -z "$container_id" ]; then
        echo -e "${RED}✗ FAILED${NC} (no container found)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi

    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null || echo "none")

    if [ "$health_status" == "healthy" ]; then
        echo -e "${GREEN}✓ PASSED${NC} (healthy)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    elif [ "$health_status" == "none" ]; then
        # No health check defined, check if container is running
        local running
        running=$(docker inspect --format='{{.State.Running}}' "$container_id" 2>/dev/null || echo "false")
        if [ "$running" == "true" ]; then
            echo -e "${GREEN}✓ PASSED${NC} (running, no healthcheck)"
            PASSED_TESTS=$((PASSED_TESTS + 1))
            return 0
        else
            echo -e "${RED}✗ FAILED${NC} (not running)"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            return 1
        fi
    else
        echo -e "${RED}✗ FAILED${NC} (status: $health_status)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Execute command in service container
exec_in_service() {
    local service_name="${STACK_NAME}_${1}"
    shift
    local cmd="$@"

    # Get one container ID from the service
    local container_id
    container_id=$(docker ps -q --filter "name=${service_name}" | head -1)

    if [ -z "$container_id" ]; then
        return 1
    fi

    docker exec "$container_id" $cmd
}

# ===============================================
# Pre-flight Checks
# ===============================================

echo -e "${YELLOW}📋 Pre-flight Checks${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}✗ Docker daemon is not running${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker daemon is running${NC}"

# Check if Docker Swarm is active
if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
    echo -e "${RED}✗ Docker Swarm is not active${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker Swarm is active${NC}"

# Check if stack is deployed
if ! docker stack ls | grep -q "$STACK_NAME"; then
    echo -e "${RED}✗ Stack '$STACK_NAME' is not deployed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Stack '$STACK_NAME' is deployed${NC}"

# Check if docker-compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${YELLOW}⚠ Docker Compose file not found: $COMPOSE_FILE${NC}"
else
    echo -e "${GREEN}✓ Docker Compose file exists${NC}"
fi

echo ""

# ===============================================
# Swarm Stack Health
# ===============================================

echo -e "${YELLOW}🐝 Swarm Stack Health${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Show stack services summary
echo -e "${CYAN}Stack Services:${NC}"
docker stack services "$STACK_NAME" --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}"
echo ""

# ===============================================
# Infrastructure Services Tests
# ===============================================

echo -e "${YELLOW}🔧 Infrastructure Services${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# PostgreSQL
test_service_health "PostgreSQL" "postgres"
test_container_health "PostgreSQL" "postgres"
test_tcp_port "PostgreSQL" "localhost" "5432"

# Test PostgreSQL connection
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Testing PostgreSQL query... "
if exec_in_service "postgres" pg_isready -U prod &> /dev/null; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Redis
test_service_health "Redis" "redis"
test_container_health "Redis" "redis"
test_tcp_port "Redis" "localhost" "6379"

# Test Redis PING
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Testing Redis PING... "
if exec_in_service "redis" redis-cli ping 2>/dev/null | grep -q "PONG"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Kafka
test_service_health "Kafka" "kafka"
test_container_health "Kafka" "kafka"
test_tcp_port "Kafka" "localhost" "9092"

# Test Kafka topics
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Testing Kafka topics... "
if exec_in_service "kafka" kafka-topics --bootstrap-server localhost:9092 --list &> /dev/null; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# MinIO
test_service_health "MinIO" "minio"
test_container_health "MinIO" "minio"
test_http_endpoint "MinIO Health" "http://localhost:9000/minio/health/live"
test_http_endpoint "MinIO Console" "http://localhost:9001"

echo ""

# ===============================================
# Traefik Load Balancer Tests
# ===============================================

echo -e "${YELLOW}⚖️  Traefik Load Balancer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

test_service_health "Traefik" "traefik"
test_http_endpoint "Traefik Dashboard" "http://localhost:8080/api/rawdata"
test_tcp_port "Traefik HTTP" "localhost" "80"
test_tcp_port "Traefik HTTPS" "localhost" "443"

echo ""

# ===============================================
# Core Pod Tests
# ===============================================

echo -e "${YELLOW}🎯 Core Pod Services${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

test_service_health "Core Pod" "core-pod"

# Test through Traefik routing
test_http_endpoint "Auth Service (via Traefik)" "http://api.localhost/auth/health"
test_http_endpoint "User Service (via Traefik)" "http://api.localhost/users/health"
test_http_endpoint "Gateway NGINX (via Traefik)" "http://api.localhost/health"

# Test frontend through Traefik
test_http_endpoint "Frontend Root" "http://localhost/"

echo ""

# ===============================================
# Business Pod Tests
# ===============================================

echo -e "${YELLOW}💼 Business Pod Services${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

test_service_health "Business Pod" "business-pod"

# Test through Traefik routing
test_http_endpoint "Voyage Service (via Traefik)" "http://api.localhost/voyage/health"
test_http_endpoint "AI Service (via Traefik)" "http://api.localhost/ai/health"
test_http_endpoint "Payment Service (via Traefik)" "http://api.localhost/payment/health"

echo ""

# ===============================================
# Experience Pod Tests
# ===============================================

echo -e "${YELLOW}🎮 Experience Pod Services${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

test_service_health "Experience Pod" "experience-pod"

# Test through Traefik routing
test_http_endpoint "Web Client (via Traefik)" "http://localhost/"
test_http_endpoint "Panorama Service (via Traefik)" "http://api.localhost/panorama/health"
test_http_endpoint "Gateway Service (via Traefik)" "http://api.localhost/gateway/health"

echo ""

# ===============================================
# Load Balancing Tests
# ===============================================

echo -e "${YELLOW}⚖️  Load Balancing & Scaling${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Test multiple requests to verify load balancing
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Testing load balancing (10 requests to business-pod)... "

request_count=0
success_count=0

for i in {1..10}; do
    if curl -sf "http://api.localhost/voyage/health" >/dev/null 2>&1; then
        ((success_count++))
    fi
    ((request_count++))
done

if [ $success_count -ge 8 ]; then
    echo -e "${GREEN}✓ PASSED${NC} ($success_count/$request_count successful)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC} ($success_count/$request_count successful)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Check replica count
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Checking business-pod replica count... "
replicas=$(docker service ls --filter "name=${STACK_NAME}_business-pod" --format "{{.Replicas}}")
current=$(echo "$replicas" | cut -d'/' -f1)
desired=$(echo "$replicas" | cut -d'/' -f2)

if [ "$desired" -ge 3 ]; then
    echo -e "${GREEN}✓ PASSED${NC} ($desired replicas configured)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ WARNING${NC} (only $desired replicas, recommend 3+)"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
fi

echo ""

# ===============================================
# API Integration Tests
# ===============================================

echo -e "${YELLOW}🔌 API Integration Tests${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Test CORS headers
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Testing CORS headers... "
cors_header=$(curl -s -H "Origin: http://localhost" -I "http://api.localhost/auth/health" 2>&1 | grep -i "access-control-allow-origin" || echo "")
if [ -n "$cors_header" ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ WARNING${NC} (CORS headers not found - may be expected)"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
fi

# Test Traefik routing rules
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Testing Traefik routing rules... "
routes=$(curl -s http://localhost:8080/api/http/routers | jq -r '.[] | .rule' 2>/dev/null || echo "")
if echo "$routes" | grep -q "Host"; then
    echo -e "${GREEN}✓ PASSED${NC} (routing rules configured)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC} (no routing rules found)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

echo ""

# ===============================================
# Volume & Data Persistence Tests
# ===============================================

echo -e "${YELLOW}💾 Volume & Data Persistence${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check if volumes exist
for volume in postgres-data redis-data kafka-data minio-data core-logs business-logs experience-logs; do
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "Checking volume: ${STACK_NAME}_$volume... "
    if docker volume inspect "${STACK_NAME}_$volume" &> /dev/null; then
        echo -e "${GREEN}✓ PASSED${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAILED${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
done

echo ""

# ===============================================
# Network Tests
# ===============================================

echo -e "${YELLOW}🌐 Network Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check overlay network
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Checking overlay network... "
if docker network inspect "${STACK_NAME}_bigpods-network" &> /dev/null; then
    driver=$(docker network inspect "${STACK_NAME}_bigpods-network" --format '{{.Driver}}')
    if [ "$driver" = "overlay" ]; then
        echo -e "${GREEN}✓ PASSED${NC} (overlay driver)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAILED${NC} (wrong driver: $driver)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
else
    echo -e "${RED}✗ FAILED${NC} (network not found)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Check network connectivity between services
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Testing inter-service connectivity (core-pod -> postgres)... "
if exec_in_service "core-pod" ping -c 1 -W 2 postgres &> /dev/null; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

echo ""

# ===============================================
# Security & Configuration Tests
# ===============================================

echo -e "${YELLOW}🔒 Security & Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check if secrets are being used (optional)
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Checking Docker secrets... "
secret_count=$(docker secret ls | grep -c "${STACK_NAME}" || echo "0")
if [ "$secret_count" -gt 0 ]; then
    echo -e "${GREEN}✓ PASSED${NC} ($secret_count secrets found)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ INFO${NC} (no secrets configured - using environment variables)"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
fi

# Check resource limits
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Checking resource limits... "
limits=$(docker service inspect ${STACK_NAME}_business-pod --format '{{.Spec.TaskTemplate.Resources.Limits}}' 2>/dev/null || echo "")
if [ -n "$limits" ] && [ "$limits" != "<nil>" ]; then
    echo -e "${GREEN}✓ PASSED${NC} (limits configured)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ WARNING${NC} (no resource limits)"
    SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
fi

echo ""

# ===============================================
# Performance & Responsiveness
# ===============================================

echo -e "${YELLOW}⚡ Performance & Responsiveness${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Test response time
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Testing API response time... "
response_time=$(curl -o /dev/null -s -w '%{time_total}\n' "http://api.localhost/auth/health")
response_ms=$(echo "$response_time * 1000" | bc | cut -d'.' -f1)

if [ "$response_ms" -lt 1000 ]; then
    echo -e "${GREEN}✓ PASSED${NC} (${response_ms}ms)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
elif [ "$response_ms" -lt 3000 ]; then
    echo -e "${YELLOW}⚠ SLOW${NC} (${response_ms}ms)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC} (${response_ms}ms - too slow)"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

echo ""

# ===============================================
# Summary
# ===============================================

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test Results Summary                                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}\n"

echo -e "Total Tests:   ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Passed:        ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:        ${RED}$FAILED_TESTS${NC}"
echo -e "Skipped:       ${YELLOW}$SKIPPED_TESTS${NC}"

SUCCESS_RATE=$(( PASSED_TESTS * 100 / TOTAL_TESTS ))
echo -e "Success Rate:  ${BLUE}${SUCCESS_RATE}%${NC}\n"

# Service-wise summary
echo -e "${CYAN}Service Health Summary:${NC}"
docker stack services "$STACK_NAME" --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ ALL TESTS PASSED!                                 ║${NC}"
    echo -e "${GREEN}║  DreamScape Big Pods are ready for production        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${CYAN}Access Points:${NC}"
    echo "  • Frontend:          http://localhost"
    echo "  • API:               http://api.localhost"
    echo "  • Traefik Dashboard: http://localhost:8080"
    echo "  • MinIO Console:     http://localhost:9001"
    echo ""
    
    exit 0
else
    echo -e "${RED}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ✗ SOME TESTS FAILED                                 ║${NC}"
    echo -e "${RED}║  Please check the logs and fix the failing services  ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo -e "  1. Check service logs:"
    echo -e "     ${BLUE}docker service logs ${STACK_NAME}_<service-name>${NC}"
    echo -e "  2. View all services status:"
    echo -e "     ${BLUE}docker stack services ${STACK_NAME}${NC}"
    echo -e "  3. View service tasks:"
    echo -e "     ${BLUE}docker stack ps ${STACK_NAME} --no-trunc${NC}"
    echo -e "  4. Check service details:"
    echo -e "     ${BLUE}docker service inspect ${STACK_NAME}_<service-name>${NC}"
    echo -e "  5. Restart failed service:"
    echo -e "     ${BLUE}docker service update --force ${STACK_NAME}_<service-name>${NC}\n"

    # Show failed tasks
    echo -e "${YELLOW}Failed Tasks:${NC}"
    docker stack ps "$STACK_NAME" --no-trunc --filter "desired-state=running" | grep -E "Failed|Rejected" || echo "No failed tasks"
    echo ""

    exit 1
fi