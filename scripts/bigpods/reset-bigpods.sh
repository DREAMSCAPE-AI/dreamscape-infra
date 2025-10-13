#!/bin/bash
set -e

# DreamScape Big Pods Development - Reset Script
# DR-328: Clean reset of development environment
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

echo -e "${YELLOW}🔄 DreamScape Big Pods Environment Reset${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Detect docker compose command (v1 vs v2)
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# ===============================================
# Confirmation
# ===============================================
echo -e "\n${RED}⚠️  WARNING: This will:${NC}"
echo -e "   - Stop all Big Pods services"
echo -e "   - Remove all containers"
echo -e "   - Delete all volumes (database data, logs, etc.)"
echo -e "   - Clean up Docker networks"
echo -e "\n${YELLOW}This action cannot be undone!${NC}"
echo -e "\n${BLUE}You will need to run ./dev-bigpods.sh again to restart.${NC}\n"

read -p "Are you sure you want to reset? (yes/no) " -r
echo

if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${GREEN}Reset cancelled${NC}"
    exit 0
fi

# ===============================================
# Reset Process
# ===============================================
cd "$INFRA_DIR/docker"

echo -e "\n${YELLOW}1/5 Stopping all Big Pods services...${NC}"
$DOCKER_COMPOSE -f docker-compose.bigpods.dev.yml down || true
echo -e "${GREEN}✓ Services stopped${NC}"

echo -e "\n${YELLOW}2/5 Removing containers...${NC}"
docker ps -a --filter "name=dreamscape-" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true
echo -e "${GREEN}✓ Containers removed${NC}"

echo -e "\n${YELLOW}3/5 Removing volumes...${NC}"
$DOCKER_COMPOSE -f docker-compose.bigpods.dev.yml down -v || true

# Additional cleanup of named volumes
docker volume ls --filter "name=dreamscape" --format "{{.Name}}" | xargs -r docker volume rm 2>/dev/null || true
docker volume ls --filter "name=docker_" --format "{{.Name}}" | grep -E "(postgres|redis|kafka|minio|core|business|experience)" | xargs -r docker volume rm 2>/dev/null || true

echo -e "${GREEN}✓ Volumes removed${NC}"

echo -e "\n${YELLOW}4/5 Cleaning up networks...${NC}"
docker network ls --filter "name=bigpods" --format "{{.ID}}" | xargs -r docker network rm 2>/dev/null || true
echo -e "${GREEN}✓ Networks cleaned${NC}"

echo -e "\n${YELLOW}5/5 Cleaning up Docker images (optional)...${NC}"
read -p "Remove Big Pods Docker images to force rebuild? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker images --filter "reference=docker-*-pod" --format "{{.ID}}" | xargs -r docker rmi -f 2>/dev/null || true
    docker images --filter "dangling=true" --format "{{.ID}}" | xargs -r docker rmi 2>/dev/null || true
    echo -e "${GREEN}✓ Docker images cleaned${NC}"
else
    echo -e "${YELLOW}⊘ Skipped image cleanup${NC}"
fi

# ===============================================
# Optional: Clean local environment file
# ===============================================
echo -e "\n${YELLOW}Additional cleanup options:${NC}"
read -p "Remove .env.bigpods.local file? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -f "$INFRA_DIR/.env.bigpods.local"
    echo -e "${GREEN}✓ Environment file removed${NC}"
else
    echo -e "${YELLOW}⊘ Environment file kept${NC}"
fi

# ===============================================
# System cleanup
# ===============================================
echo -e "\n${YELLOW}Running Docker system prune...${NC}"
docker system prune -f --volumes 2>/dev/null || true
echo -e "${GREEN}✓ System pruned${NC}"

# ===============================================
# Summary
# ===============================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ DreamScape Big Pods Environment Reset Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "\n${YELLOW}📊 Current Docker Status:${NC}"
echo -e "\n${BLUE}Containers:${NC}"
docker ps -a --filter "name=dreamscape" --format "table {{.Names}}\t{{.Status}}" || echo "No DreamScape containers"

echo -e "\n${BLUE}Volumes:${NC}"
docker volume ls --filter "name=dreamscape" --format "table {{.Name}}\t{{.Size}}" 2>/dev/null || echo "No DreamScape volumes"

echo -e "\n${BLUE}Images:${NC}"
docker images --filter "reference=docker-*-pod" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" || echo "No Big Pods images"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e "  ${GREEN}1.${NC} Run ${BLUE}$SCRIPT_DIR/dev-bigpods.sh${NC} to restart the environment"
echo -e "  ${GREEN}2.${NC} All data will be reinitialized with fresh test data"
echo -e "  ${GREEN}3.${NC} Setup will take 2-3 minutes on first run\n"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
