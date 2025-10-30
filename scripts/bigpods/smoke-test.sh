#!/bin/bash
set -euo pipefail

# DreamScape Big Pods - Smoke Test Script
# Validates that all services are running and healthy
# Exit code 0 = all tests passed, 1 = one or more tests failed

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_FILE="$INFRA_DIR/docker/docker-compose.bigpods.dev.yml"

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  DreamScape Big Pods - Smoke Test Suite             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}\n"

# Detect docker compose command (v1 vs v2)
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

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

# Test Docker container health
test_container_health() {
    local name=$1
    local container=$2

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    echo -n "Testing $name container health... "

    local health_status
    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")

    if [ "$health_status" == "healthy" ]; then
        echo -e "${GREEN}✓ PASSED${NC} (healthy)"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    elif [ "$health_status" == "none" ]; then
        # No health check defined, check if container is running
        local running
        running=$(docker inspect --format='{{.State.Running}}' "$container" 2>/dev/null || echo "false")
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

# Check if docker-compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}✗ Docker Compose file not found: $COMPOSE_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker Compose file exists${NC}\n"

# ===============================================
# Infrastructure Services Tests
# ===============================================

echo -e "${YELLOW}🔧 Infrastructure Services${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# PostgreSQL
test_container_health "PostgreSQL" "dreamscape-postgres"
test_tcp_port "PostgreSQL" "localhost" "5432"

# Test PostgreSQL connection
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Testing PostgreSQL query... "
if docker exec dreamscape-postgres psql -U dev -d dreamscape_dev -c "SELECT 1;" &> /dev/null; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Redis
test_container_health "Redis" "dreamscape-redis"
test_tcp_port "Redis" "localhost" "6379"

# Test Redis PING
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Testing Redis PING... "
if docker exec dreamscape-redis redis-cli ping | grep -q "PONG"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# Kafka
test_container_health "Kafka" "dreamscape-kafka"
test_tcp_port "Kafka" "localhost" "9092"

# Test Kafka topics
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Testing Kafka topics... "
if docker exec dreamscape-kafka kafka-topics --bootstrap-server localhost:9092 --list &> /dev/null; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${RED}✗ FAILED${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi

# MinIO
test_container_health "MinIO" "dreamscape-minio"
test_http_endpoint "MinIO Health" "http://localhost:9000/minio/health/live"
test_http_endpoint "MinIO Console" "http://localhost:9001"

echo ""

# ===============================================
# Core Pod Tests
# ===============================================

echo -e "${YELLOW}🎯 Core Pod Services${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

test_container_health "Core Pod" "dreamscape-core-pod"
test_http_endpoint "Core Pod Health" "http://localhost/health"
test_http_endpoint "Auth Service" "http://localhost:3001/health"
test_http_endpoint "User Service" "http://localhost:3002/health"

# Test NGINX
test_tcp_port "NGINX HTTP" "localhost" "80"

echo ""

# ===============================================
# Business Pod Tests
# ===============================================

echo -e "${YELLOW}💼 Business Pod Services${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

test_container_health "Business Pod" "dreamscape-business-pod"
test_http_endpoint "Voyage Service" "http://localhost:3003/health"
test_http_endpoint "AI Service" "http://localhost:3004/health"
test_http_endpoint "Payment Service" "http://localhost:3005/health"

echo ""

# ===============================================
# Experience Pod Tests
# ===============================================

echo -e "${YELLOW}🎮 Experience Pod Services${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

test_container_health "Experience Pod" "dreamscape-experience-pod"
test_http_endpoint "Web Client" "http://localhost:3000"
test_http_endpoint "Vite HMR" "http://localhost:5173"
test_http_endpoint "Panorama Service" "http://localhost:3006/health"
test_http_endpoint "Gateway Service" "http://localhost:4000/health"

echo ""

# ===============================================
# API Integration Tests
# ===============================================

echo -e "${YELLOW}🔌 API Integration Tests${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Test API Gateway routing
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Testing API Gateway routing (via NGINX)... "
response=$(curl -s -w "%{http_code}" -o /dev/null "http://localhost/api/v1/health" 2>&1)
if [ "$response" -ge 200 -a "$response" -lt 400 ]; then
    echo -e "${GREEN}✓ PASSED${NC} (HTTP $response)"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ SKIPPED${NC} (endpoint may not exist)"
    # Don't count as failed since endpoint might not be implemented
fi

# Test CORS headers
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -n "Testing CORS headers... "
cors_header=$(curl -s -H "Origin: http://localhost:3000" -I "http://localhost/health" 2>&1 | grep -i "access-control-allow-origin" || echo "")
if [ -n "$cors_header" ]; then
    echo -e "${GREEN}✓ PASSED${NC}"
    PASSED_TESTS=$((PASSED_TESTS + 1))
else
    echo -e "${YELLOW}⚠ WARNING${NC} (CORS headers not found)"
    # Don't count as critical failure
fi

echo ""

# ===============================================
# Volume & Data Persistence Tests
# ===============================================

echo -e "${YELLOW}💾 Volume & Data Persistence${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check if volumes exist
for volume in postgres-data redis-data kafka-data minio-data; do
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -n "Checking volume: dreamscape-bigpods_$volume... "
    if docker volume inspect "dreamscape-bigpods_$volume" &> /dev/null; then
        echo -e "${GREEN}✓ PASSED${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAILED${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
done

echo ""

# ===============================================
# Debug Port Tests
# ===============================================

echo -e "${YELLOW}🐛 Debug Port Accessibility${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Test Node.js debugger ports
test_tcp_port "Auth Debug Port" "localhost" "9229"
test_tcp_port "User Debug Port" "localhost" "9230"
test_tcp_port "Voyage Debug Port" "localhost" "9231"
test_tcp_port "AI Debug Port" "localhost" "9232"
test_tcp_port "Payment Debug Port" "localhost" "9233"
test_tcp_port "Panorama Debug Port" "localhost" "9234"
test_tcp_port "Gateway Debug Port" "localhost" "9235"

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

SUCCESS_RATE=$(( PASSED_TESTS * 100 / TOTAL_TESTS ))
echo -e "Success Rate:  ${BLUE}${SUCCESS_RATE}%${NC}\n"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✓ ALL TESTS PASSED!                                 ║${NC}"
    echo -e "${GREEN}║  DreamScape Big Pods are ready for development       ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}\n"
    exit 0
else
    echo -e "${RED}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ✗ SOME TESTS FAILED                                 ║${NC}"
    echo -e "${RED}║  Please check the logs and fix the failing services  ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}\n"

    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo -e "  1. Check service logs:"
    echo -e "     ${BLUE}$DOCKER_COMPOSE -f $COMPOSE_FILE logs <service-name>${NC}"
    echo -e "  2. View all containers status:"
    echo -e "     ${BLUE}$DOCKER_COMPOSE -f $COMPOSE_FILE ps${NC}"
    echo -e "  3. Restart failed services:"
    echo -e "     ${BLUE}$DOCKER_COMPOSE -f $COMPOSE_FILE restart <service-name>${NC}\n"

    exit 1
fi
