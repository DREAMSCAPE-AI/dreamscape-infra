#!/bin/bash
set -euo pipefail

# DreamScape Big Pods Development - Startup Script
# DR-328: One-command setup for local development
# Architecture Hybride: 6-repos → 3-Big-Pods

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
ENV_FILE="$INFRA_DIR/.env.bigpods.local"
ENV_EXAMPLE="$INFRA_DIR/.env.bigpods.example"

echo -e "${BLUE}🚀 Starting DreamScape Big Pods Development Environment${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# ===============================================
# Prerequisites Check
# ===============================================
echo -e "\n${YELLOW}📋 Checking prerequisites...${NC}"

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo "Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed${NC}"
    echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

# Detect docker compose command (v1 vs v2)
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

echo -e "${GREEN}✓ Docker installed$(docker --version)${NC}"
echo -e "${GREEN}✓ Docker Compose installed${NC}"

# Check if Docker daemon is running
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker daemon is not running${NC}"
    echo "Please start Docker Desktop or the Docker daemon"
    exit 1
fi

echo -e "${GREEN}✓ Docker daemon running${NC}"

# ===============================================
# Environment Setup
# ===============================================
echo -e "\n${YELLOW}⚙️  Setting up environment...${NC}"

if [ ! -f "$ENV_FILE" ]; then
    if [ -f "$ENV_EXAMPLE" ]; then
        echo -e "${YELLOW}Creating .env.bigpods.local from example...${NC}"
        cp "$ENV_EXAMPLE" "$ENV_FILE"
        echo -e "${GREEN}✓ Environment file created${NC}"
    else
        echo -e "${YELLOW}⚠️  No .env.bigpods.example found, creating minimal config${NC}"
        cat > "$ENV_FILE" <<EOF
# DreamScape Big Pods Development Environment

# API Keys (Test Mode)
AMADEUS_TEST_KEY=your_amadeus_test_key
AMADEUS_TEST_SECRET=your_amadeus_test_secret
STRIPE_TEST_KEY=sk_test_your_stripe_test_key
OPENAI_API_KEY=sk-your_openai_api_key

# Database
DB_NAME=dreamscape_dev
DB_USER=dev
DB_PASSWORD=dev123

# Redis
REDIS_PASSWORD=

# JWT
JWT_SECRET=dev-jwt-secret-change-in-production

# Environment
NODE_ENV=development
LOG_LEVEL=debug
EOF
        echo -e "${GREEN}✓ Minimal environment file created${NC}"
    fi
else
    echo -e "${GREEN}✓ Environment file exists${NC}"
fi

# Source environment
set -a
source "$ENV_FILE"
set +a

# ===============================================
# Repository Structure Check
# ===============================================
echo -e "\n${YELLOW}📁 Checking repository structure...${NC}"

REQUIRED_REPOS=(
    "dreamscape-services"
    "dreamscape-frontend"
    "dreamscape-infra"
)

WORKSPACE_ROOT="$(cd "$INFRA_DIR/.." && pwd)"
MISSING_REPOS=()

for repo in "${REQUIRED_REPOS[@]}"; do
    if [ -d "$WORKSPACE_ROOT/$repo" ]; then
        echo -e "${GREEN}✓ $repo found${NC}"
    else
        echo -e "${YELLOW}⚠️  $repo not found${NC}"
        MISSING_REPOS+=("$repo")
    fi
done

if [ ${#MISSING_REPOS[@]} -ne 0 ]; then
    echo -e "\n${YELLOW}⚠️  Some repositories are missing:${NC}"
    for repo in "${MISSING_REPOS[@]}"; do
        echo -e "   - $repo"
    done
    echo -e "\n${YELLOW}Continuing anyway - services will use placeholder code${NC}"
    read -p "Press Enter to continue or Ctrl+C to abort..."
fi

# ===============================================
# Docker Compose Setup
# ===============================================
echo -e "\n${YELLOW}🐳 Starting Docker Compose Big Pods...${NC}"

cd "$INFRA_DIR/docker"

# Check if services are already running
if $DOCKER_COMPOSE -f docker-compose.bigpods.dev.yml ps | grep -q "Up"; then
    echo -e "${YELLOW}Some services are already running${NC}"
    read -p "Restart all services? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Stopping existing services...${NC}"
        $DOCKER_COMPOSE -f docker-compose.bigpods.dev.yml down
    fi
fi

# Build and start services
echo -e "${BLUE}Building and starting Big Pods...${NC}"
$DOCKER_COMPOSE -f docker-compose.bigpods.dev.yml up --build -d

# ===============================================
# Wait for Services
# ===============================================
echo -e "\n${YELLOW}⏳ Waiting for services to be ready...${NC}"
echo -e "${BLUE}This may take 2-3 minutes for first-time setup${NC}"

# Function to check service health
check_service() {
    local service=$1
    local url=$2
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if curl -f -s "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ $service is ready${NC}"
            return 0
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    echo -e "${RED}✗ $service failed to start${NC}"
    return 1
}

# Initial wait for containers to start
sleep 10

# Check infrastructure services
echo -n "Checking PostgreSQL... "
check_service "PostgreSQL" "http://localhost:5432" || true

echo -n "Checking Redis... "
check_service "Redis" "http://localhost:6379" || true

echo -n "Checking MinIO... "
check_service "MinIO" "http://localhost:9000/minio/health/live" || true

# Additional wait for application pods
sleep 20

# Check Big Pods
echo -n "Checking Core Pod... "
check_service "Core Pod" "http://localhost/health" || true

echo -n "Checking Business Pod... "
check_service "Business Pod" "http://localhost:3003/health" || true

echo -n "Checking Experience Pod... "
check_service "Experience Pod" "http://localhost:3000/health" || true

# ===============================================
# Service Status Summary
# ===============================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ DreamScape Big Pods Development Environment Ready!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${YELLOW}🌐 Service URLs:${NC}"
echo -e "  ${GREEN}Web Application:${NC}      http://localhost:3000"
echo -e "  ${GREEN}API Gateway (Core):${NC}   http://localhost/api/v1"
echo -e "  ${GREEN}Business Services:${NC}    http://localhost:3003"
echo -e "  ${GREEN}Panorama VR:${NC}          http://localhost:3006"

echo -e "\n${YELLOW}🔧 Infrastructure:${NC}"
echo -e "  ${GREEN}PostgreSQL:${NC}           localhost:5432 (user: dev, password: dev123)"
echo -e "  ${GREEN}Redis:${NC}                localhost:6379"
echo -e "  ${GREEN}Kafka:${NC}                localhost:9092"
echo -e "  ${GREEN}MinIO Console:${NC}        http://localhost:9001 (user: dreamscape-dev)"

echo -e "\n${YELLOW}📊 Monitoring:${NC}"
echo -e "  ${GREEN}View Logs:${NC}            ${DOCKER_COMPOSE} -f docker-compose.bigpods.dev.yml logs -f"
echo -e "  ${GREEN}Core Pod Logs:${NC}        ${DOCKER_COMPOSE} -f docker-compose.bigpods.dev.yml logs -f core-pod"
echo -e "  ${GREEN}Business Pod Logs:${NC}    ${DOCKER_COMPOSE} -f docker-compose.bigpods.dev.yml logs -f business-pod"
echo -e "  ${GREEN}Experience Pod Logs:${NC}  ${DOCKER_COMPOSE} -f docker-compose.bigpods.dev.yml logs -f experience-pod"

echo -e "\n${YELLOW}🛠️  Development Commands:${NC}"
echo -e "  ${GREEN}Stop Services:${NC}        ${DOCKER_COMPOSE} -f docker-compose.bigpods.dev.yml down"
echo -e "  ${GREEN}Restart:${NC}              ${DOCKER_COMPOSE} -f docker-compose.bigpods.dev.yml restart"
echo -e "  ${GREEN}Reset Database:${NC}       $SCRIPT_DIR/reset-bigpods.sh"

echo -e "\n${YELLOW}📖 Test Accounts:${NC}"
echo -e "  ${GREEN}Admin:${NC}                dev@dreamscape.ai / password123"
echo -e "  ${GREEN}User:${NC}                 john@example.com / password123"

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Happy coding! 🎉${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
