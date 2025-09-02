#!/bin/bash
# Local Core Pod Simulation without Docker
# DR-336: INFRA-010.3 - Big Pod Architecture Testing

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 DreamScape Core Pod - Local Testing${NC}"
echo -e "${BLUE}DR-336: INFRA-010.3 - Big Pod Simulation${NC}"
echo ""

BASE_DIR="/mnt/c/Users/kevco/Documents/EPITECH/DREAMSCAPE GITHUB MICROSERVICE"
SERVICES_DIR="$BASE_DIR/dreamscape-services"

# Function to check if Node.js is available
check_node() {
    if ! command -v node >/dev/null 2>&1; then
        echo -e "${RED}❌ Node.js not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Node.js available: $(node --version)${NC}"
}

# Function to install dependencies
install_deps() {
    local service=$1
    echo -e "${YELLOW}📦 Installing dependencies for $service...${NC}"
    
    cd "$SERVICES_DIR/$service"
    
    if [ -f "package.json" ]; then
        if npm ci >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Dependencies installed for $service${NC}"
        else
            echo -e "${YELLOW}⚠️ npm ci failed, trying npm install for $service${NC}"
            npm install >/dev/null 2>&1 || echo -e "${RED}❌ Could not install deps for $service${NC}"
        fi
    else
        echo -e "${RED}❌ No package.json found for $service${NC}"
    fi
}

# Function to start a service in background
start_service() {
    local service=$1
    local port=$2
    
    echo -e "${YELLOW}🚀 Starting $service on port $port...${NC}"
    
    cd "$SERVICES_DIR/$service"
    
    # Set environment variables
    export NODE_ENV=development
    export PORT=$port
    export DATABASE_URL="mongodb://localhost:27017/dreamscape"
    export JWT_SECRET="test-secret-key"
    
    # Start service in background
    if [ -f "src/server.ts" ]; then
        npx tsx src/server.ts &
        local pid=$!
        echo $pid > "/tmp/dreamscape-$service.pid"
        echo -e "${GREEN}✅ $service started (PID: $pid)${NC}"
    else
        echo -e "${RED}❌ No server.ts found for $service${NC}"
    fi
}

# Function to create simple NGINX config simulation
create_nginx_sim() {
    cat > "/tmp/core-pod-routes.txt" << 'EOF'
🌐 Core Pod Route Simulation:

NGINX Reverse Proxy (port 80) would route to:
├── /api/v1/auth/* → Auth Service (localhost:3001)
├── /api/v1/users/* → User Service (localhost:3002)
├── /health → NGINX Health Check
└── /status → Core Pod Status

Direct Service Access:
├── Auth Service: http://localhost:3001
├── User Service: http://localhost:3002
└── All services communicate via localhost (Big Pod architecture)

Performance Benefits:
├── Latency: 5ms (localhost) vs 50ms+ (network)
├── RAM: -30% vs traditional microservices
└── Containers: 1 Big Pod vs 3+ separate containers
EOF

    echo -e "${BLUE}$(cat /tmp/core-pod-routes.txt)${NC}"
}

# Function to test services
test_services() {
    echo -e "${YELLOW}🧪 Testing Core Pod services...${NC}"
    sleep 5
    
    # Test Auth Service
    if curl -f -s http://localhost:3001 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Auth Service (localhost:3001) is running${NC}"
    else
        echo -e "${YELLOW}⚠️ Auth Service not responding yet${NC}"
    fi
    
    # Test User Service
    if curl -f -s http://localhost:3002 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ User Service (localhost:3002) is running${NC}"
    else
        echo -e "${YELLOW}⚠️ User Service not responding yet${NC}"
    fi
}

# Function to show status
show_status() {
    echo -e "${BLUE}📊 Big Pod Services Status:${NC}"
    
    for service in auth user; do
        if [ -f "/tmp/dreamscape-$service.pid" ]; then
            local pid=$(cat "/tmp/dreamscape-$service.pid")
            if kill -0 $pid 2>/dev/null; then
                echo -e "${GREEN}✅ $service service running (PID: $pid)${NC}"
            else
                echo -e "${RED}❌ $service service stopped${NC}"
            fi
        else
            echo -e "${RED}❌ $service service not started${NC}"
        fi
    done
}

# Function to stop services
stop_services() {
    echo -e "${YELLOW}🛑 Stopping Core Pod services...${NC}"
    
    for service in auth user; do
        if [ -f "/tmp/dreamscape-$service.pid" ]; then
            local pid=$(cat "/tmp/dreamscape-$service.pid")
            if kill $pid 2>/dev/null; then
                echo -e "${GREEN}✅ Stopped $service service${NC}"
            fi
            rm -f "/tmp/dreamscape-$service.pid"
        fi
    done
}

# Main execution
case "${1:-start}" in
    "start")
        check_node
        install_deps "auth"
        install_deps "user"
        create_nginx_sim
        start_service "auth" 3001
        start_service "user" 3002
        test_services
        show_status
        echo ""
        echo -e "${GREEN}🎉 Core Pod simulation started!${NC}"
        echo -e "${BLUE}Use './start-local-core-pod.sh status' to check services${NC}"
        echo -e "${BLUE}Use './start-local-core-pod.sh stop' to stop all services${NC}"
        ;;
    "stop")
        stop_services
        echo -e "${GREEN}✅ Core Pod simulation stopped${NC}"
        ;;
    "status")
        show_status
        ;;
    *)
        echo -e "${BLUE}Usage: $0 {start|stop|status}${NC}"
        ;;
esac