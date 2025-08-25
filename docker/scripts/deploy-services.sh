#!/bin/bash
# Deployment Script for DreamScape Core Services
# DR-334: INFRA-010.2 - Deploy auth and user services with multi-stage Docker

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose.core-services.yml"
SERVICES=("auth-service" "user-service" "gateway")
ENVIRONMENT=${ENVIRONMENT:-"development"}

echo -e "${BLUE}🚀 DreamScape Core Services Deployment${NC}"
echo -e "${BLUE}DR-334: INFRA-010.2 - Multi-stage Docker Services${NC}"
echo -e "${YELLOW}Environment: $ENVIRONMENT${NC}"
echo ""

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running. Please start Docker and try again.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker is running${NC}"
}

# Function to check if docker-compose file exists
check_compose_file() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo -e "${RED}❌ Docker compose file $COMPOSE_FILE not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker compose file found${NC}"
}

# Function to build services
build_services() {
    echo -e "${YELLOW}🔨 Building services...${NC}"
    
    for service in "${SERVICES[@]}"; do
        echo -e "${BLUE}Building $service...${NC}"
        if docker-compose -f "$COMPOSE_FILE" build "$service"; then
            echo -e "${GREEN}✅ $service built successfully${NC}"
        else
            echo -e "${RED}❌ Failed to build $service${NC}"
            exit 1
        fi
    done
}

# Function to start services
start_services() {
    echo -e "${YELLOW}🚀 Starting services...${NC}"
    
    # Start infrastructure services first
    echo -e "${BLUE}Starting infrastructure services (MongoDB, Redis)...${NC}"
    docker-compose -f "$COMPOSE_FILE" up -d mongodb redis
    
    # Wait for infrastructure to be ready
    echo -e "${BLUE}Waiting for infrastructure services to be ready...${NC}"
    sleep 30
    
    # Start application services
    echo -e "${BLUE}Starting application services...${NC}"
    docker-compose -f "$COMPOSE_FILE" up -d auth-service user-service gateway
    
    echo -e "${GREEN}✅ All services started${NC}"
}

# Function to check service health
check_health() {
    echo -e "${YELLOW}🏥 Checking service health...${NC}"
    
    local max_attempts=12
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo -e "${BLUE}Health check attempt $attempt/$max_attempts${NC}"
        
        local all_healthy=true
        
        # Check Auth Service
        if curl -f -s http://localhost:3001/health >/dev/null; then
            echo -e "${GREEN}✅ Auth Service: Healthy${NC}"
        else
            echo -e "${RED}❌ Auth Service: Unhealthy${NC}"
            all_healthy=false
        fi
        
        # Check User Service
        if curl -f -s http://localhost:3002/health >/dev/null; then
            echo -e "${GREEN}✅ User Service: Healthy${NC}"
        else
            echo -e "${RED}❌ User Service: Unhealthy${NC}"
            all_healthy=false
        fi
        
        # Check Gateway
        if curl -f -s http://localhost:3000/health >/dev/null; then
            echo -e "${GREEN}✅ Gateway: Healthy${NC}"
        else
            echo -e "${RED}❌ Gateway: Unhealthy${NC}"
            all_healthy=false
        fi
        
        if $all_healthy; then
            echo -e "${GREEN}🎉 All services are healthy!${NC}"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo -e "${YELLOW}⏳ Waiting 15 seconds before next check...${NC}"
            sleep 15
        fi
        
        ((attempt++))
    done
    
    echo -e "${RED}❌ Some services failed health checks after $max_attempts attempts${NC}"
    return 1
}

# Function to show service status
show_status() {
    echo -e "${YELLOW}📊 Service Status${NC}"
    echo "========================================"
    docker-compose -f "$COMPOSE_FILE" ps
    echo ""
    
    echo -e "${YELLOW}📈 Service Resources${NC}"
    echo "========================================"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" \
        $(docker-compose -f "$COMPOSE_FILE" ps -q)
    echo ""
}

# Function to show service logs
show_logs() {
    local service=${1:-""}
    
    if [ -n "$service" ]; then
        echo -e "${YELLOW}📜 Logs for $service${NC}"
        echo "========================================"
        docker-compose -f "$COMPOSE_FILE" logs --tail=50 "$service"
    else
        echo -e "${YELLOW}📜 All Service Logs${NC}"
        echo "========================================"
        docker-compose -f "$COMPOSE_FILE" logs --tail=20
    fi
}

# Function to test API endpoints
test_endpoints() {
    echo -e "${YELLOW}🧪 Testing API endpoints...${NC}"
    
    # Test Gateway
    echo -e "${BLUE}Testing Gateway endpoints:${NC}"
    curl -s http://localhost:3000/docs | jq . || echo "Gateway docs endpoint accessible"
    
    # Test Auth Service through Gateway
    echo -e "${BLUE}Testing Auth Service through Gateway:${NC}"
    curl -s http://localhost:3000/api/v1/auth/health || echo "Auth service endpoint accessible"
    
    # Test User Service through Gateway
    echo -e "${BLUE}Testing User Service through Gateway:${NC}"
    curl -s http://localhost:3000/api/v1/users/health || echo "User service endpoint accessible"
    
    echo -e "${GREEN}✅ Endpoint tests completed${NC}"
}

# Function to stop services
stop_services() {
    echo -e "${YELLOW}🛑 Stopping services...${NC}"
    docker-compose -f "$COMPOSE_FILE" down
    echo -e "${GREEN}✅ All services stopped${NC}"
}

# Function to cleanup
cleanup() {
    echo -e "${YELLOW}🧹 Cleaning up...${NC}"
    docker-compose -f "$COMPOSE_FILE" down -v --remove-orphans
    docker system prune -f
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Main script logic
case "${1:-deploy}" in
    "deploy")
        check_docker
        check_compose_file
        build_services
        start_services
        check_health
        show_status
        test_endpoints
        echo ""
        echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
        echo -e "${BLUE}Access points:${NC}"
        echo "  - Gateway: http://localhost:3000"
        echo "  - Auth Service: http://localhost:3001"
        echo "  - User Service: http://localhost:3002"
        echo "  - API Documentation: http://localhost:3000/docs"
        ;;
    "build")
        check_docker
        check_compose_file
        build_services
        ;;
    "start")
        check_docker
        check_compose_file
        start_services
        check_health
        ;;
    "status")
        show_status
        ;;
    "health")
        check_health
        ;;
    "logs")
        show_logs "$2"
        ;;
    "test")
        test_endpoints
        ;;
    "stop")
        stop_services
        ;;
    "cleanup")
        cleanup
        ;;
    "help"|"-h"|"--help")
        echo -e "${BLUE}DreamScape Services Deployment Script${NC}"
        echo ""
        echo -e "${YELLOW}Usage:${NC} $0 [command] [options]"
        echo ""
        echo -e "${YELLOW}Commands:${NC}"
        echo "  deploy   - Full deployment (build + start + health check)"
        echo "  build    - Build all services"
        echo "  start    - Start all services"
        echo "  status   - Show service status and resource usage"
        echo "  health   - Check service health"
        echo "  logs     - Show service logs (optional: specify service name)"
        echo "  test     - Test API endpoints"
        echo "  stop     - Stop all services"
        echo "  cleanup  - Stop services and remove volumes"
        echo "  help     - Show this help message"
        echo ""
        echo -e "${YELLOW}Examples:${NC}"
        echo "  $0 deploy              # Full deployment"
        echo "  $0 logs auth-service   # Show auth service logs"
        echo "  $0 status              # Show current status"
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        echo -e "${YELLOW}Use '$0 help' for available commands${NC}"
        exit 1
        ;;
esac