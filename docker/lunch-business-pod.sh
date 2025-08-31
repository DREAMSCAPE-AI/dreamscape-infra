#!/bin/bash
# Script de lancement du Business Pod DreamScape
# DR-326: INFRA-011.3 - Lancement Big Pod Architecture

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 DreamScape Business Pod Launcher${NC}"
echo -e "${BLUE}DR-336: INFRA-011.3 - Big Pod Architecture${NC}"
echo ""

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running or not accessible${NC}"
        echo -e "${YELLOW}💡 Please start Docker Desktop or Docker daemon${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker is running${NC}"
}

# Function to check if docker-compose is available
check_compose() {
    if ! command -v docker-compose >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠️ docker-compose not found, trying docker compose${NC}"
        if ! docker compose version >/dev/null 2>&1; then
            echo -e "${RED}❌ Neither docker-compose nor docker compose available${NC}"
            exit 1
        else
            COMPOSE_CMD="docker compose"
        fi
    else
        COMPOSE_CMD="docker-compose"
    fi
    echo -e "${GREEN}✅ Docker Compose available: $COMPOSE_CMD${NC}"
}

# Function to build Business Pod
build_core_pod() {
    echo -e "${YELLOW}🔨 Building Business Pod...${NC}"

    cd docker

    # Build the business pod image
    $COMPOSE_CMD -f docker-compose.business-pod.yml build --no-cache business-pod

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Business Pod built successfully${NC}"
    else
        echo -e "${RED}❌ Business Pod build failed${NC}"
        exit 1
    fi
}

# Function to start services
start_services() {
    echo -e "${YELLOW}🚀 Starting Business Pod services...${NC}"

    # Start MongoDB and Redis first
    $COMPOSE_CMD -f docker-compose.business-pod.yml up -d mongodb redis

    # Wait for databases to be ready
    echo -e "${YELLOW}⏳ Waiting for databases to be ready...${NC}"
    sleep 15

    # Start Core Pod
    $COMPOSE_CMD -f docker-compose.business-pod.yml up -d core-pod

    echo -e "${GREEN}✅ Core Pod started${NC}"
}

# Function to show status
show_status() {
    echo -e "${YELLOW}📊 Service Status:${NC}"
    $COMPOSE_CMD -f docker-compose.business-pod.yml ps

    echo ""
    echo -e "${BLUE}🔗 Service URLs:${NC}"
    echo -e "  • NGINX Reverse Proxy: http://localhost:80"
    echo -e "  • Voyage Service (direct): http://localhost:3003"
    echo -e "  • Ai Service (direct): http://localhost:3004"
    echo -e "  • Payment Service (direct): http://localhost:3005"
    echo -e "  • MongoDB: mongodb://localhost:27017"
    echo -e "  • Redis: redis://localhost:6379"

    echo ""
    echo -e "${BLUE}🏥 Health Checks:${NC}"
    echo -e "  • Business Pod Health: http://localhost:80/health"
    echo -e "  • Business Pod Status: http://localhost:80/status"
    echo -e "  • Voyage Health: http://localhost:80/api/v1/voyage/health"
    echo -e "  • Ai Health: http://localhost:80/api/v1/ai/health"
    echo -e "  • Payment Health: http://localhost:80/api/v1/payment/health"
}

# Function to test services
test_services() {
    echo -e "${YELLOW}🧪 Testing Business Pod services...${NC}"

    # Wait a bit for services to fully start
    sleep 10

    # Test NGINX
    if curl -f -s http://localhost:80/health >/dev/null; then
        echo -e "${GREEN}✅ NGINX is healthy${NC}"
    else
        echo -e "${RED}❌ NGINX health check failed${NC}"
    fi

    # Test Auth Service via NGINX
    if curl -f -s http://localhost:80/api/v1/auth/health >/dev/null; then
        echo -e "${GREEN}✅ Auth Service is healthy${NC}"
    else
        echo -e "${YELLOW}⚠️ Auth Service not ready yet (normal during startup)${NC}"
    fi

    # Test User Service via NGINX
    if curl -f -s http://localhost:80/api/v1/users/health >/dev/null; then
        echo -e "${GREEN}✅ User Service is healthy${NC}"
    else
        echo -e "${YELLOW}⚠️ User Service not ready yet (normal during startup)${NC}"
    fi
}

# Function to show logs
show_logs() {
    echo -e "${YELLOW}📋 Business Pod Logs (last 20 lines):${NC}"
    $COMPOSE_CMD -f docker-compose.business-pod.yml logs --tail=20 business-pod
}

# Main execution
main() {
    check_docker
    check_compose

    case "${1:-start}" in
        "build")
            build_business_pod
            ;;
        "start")
            build_business_pod
            start_services
            show_status
            test_services
            ;;
        "stop")
            echo -e "${YELLOW}🛑 Stopping Business Pod...${NC}"
            cd docker
            $COMPOSE_CMD -f docker-compose.business-pod.yml down
            echo -e "${GREEN}✅ Core Pod stopped${NC}"
            ;;
        "restart")
            echo -e "${YELLOW}🔄 Restarting Core Pod...${NC}"
            cd docker
            $COMPOSE_CMD -f docker-compose.business-pod.yml restart core-pod
            show_status
            ;;
        "status")
            cd docker
            show_status
            ;;
        "logs")
            cd docker
            show_logs
            ;;
        "test")
            test_services
            ;;
        "clean")
            echo -e "${YELLOW}🧹 Cleaning up Business Pod...${NC}"
            cd docker
            $COMPOSE_CMD -f docker-compose.business-pod.yml down -v --rmi all
            docker system prune -f
            echo -e "${GREEN}✅ Cleanup completed${NC}"
            ;;
        *)
            echo -e "${BLUE}📖 Usage: $0 {build|start|stop|restart|status|logs|test|clean}${NC}"
            echo ""
            echo -e "${YELLOW}Commands:${NC}"
            echo -e "  build   - Build Business Pod image only"
            echo -e "  start   - Build and start complete Business Pod (default)"
            echo -e "  stop    - Stop all Business Pod services"
            echo -e "  restart - Restart Business Pod container"
            echo -e "  status  - Show service status and URLs"
            echo -e "  logs    - Show Business Pod logs"
            echo -e "  test    - Test service health"
            echo -e "  clean   - Stop and remove all containers, volumes, and images"
            ;;
    esac
}

# Execute main function
main "$@"