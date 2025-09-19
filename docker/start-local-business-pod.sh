#!/bin/bash
# Local  Business Simulation without Docker
# DR-327: INFRA-011 - Business Pod Architecture Testing

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}🚀 DreamScape Business Pod - Local Testing${NC}"
echo -e "${BLUE}DR-327: INFRA-011.3 - Big Pod Simulation${NC}"
echo ""

BASE_DIR="/home/nico/Documents/DREAMSCAPE-PROJECT/"
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
    cat > "/tmp/business-pod-routes.txt" << 'EOF'
🌐 Core Pod Route Simulation:
NGINX Reverse Proxy (port 80) would route to:
├── /api/v1/voyage/* → Voyage Service (localhost:3003)
├── /api/v1/ai/* → Ai Service (localhost:3004)
├── /api/v1/payment/* → Payment Service (localhost:3005)

├── /health → NGINX Health Check
└── /status → Business Pod Status
Direct Service Access:
├── Voyage Service: http://localhost:3003
├── Ai Service: http://localhost:3004
├── Payment Service: http://localhost:3005
└── All services communicate via localhost (Big Pod architecture)
Performance Benefits:
├── Latency: 5ms (localhost) vs 50ms+ (network)
├── RAM: -30% vs traditional microservices
└── Containers: 1 Big Pod vs 3+ separate containers
EOF

    echo -e "${BLUE}$(cat /tmp/business-pod-routes.txt)${NC}"
}

# Function to test services
test_services() {
    echo -e "${YELLOW}🧪 Testing Business Pod services...${NC}"
    sleep 5

    # Test Voyage Service
    if curl -f -s http://localhost:3003 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Voyage Service (localhost:3003) is running${NC}"
    else
        echo -e "${YELLOW}⚠️ Voyage Service not responding yet${NC}"
    fi

    # Test Ai Service
    if curl -f -s http://localhost:3004 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Ai Service (localhost:3002) is running${NC}"
    else
        echo -e "${YELLOW}⚠️ Ai Service not responding yet${NC}"
    fi
    # Test Payment Service
    if curl -f -s http://localhost:3005 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Payment Service (localhost:3005) is running${NC}"
    else
        echo -e "${YELLOW}⚠️ Payment Service not responding yet${NC}"
    fi
}

# Function to show status
show_status() {
    echo -e "${BLUE}📊 Big Pod Services Status:${NC}"

    for service in voyage ai payment; do
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
    echo -e "${YELLOW}🛑 Stopping Business Pod services...${NC}"

    for service in voyage ai payment; do
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
        install_deps "voyage"
        install_deps "ai"
        install_deps "payment"
        create_nginx_sim
        start_service "voyage" 3003
        start_service "ai" 3004
        start_service "payment" 3005
        test_services
        show_status
        echo ""
        echo -e "${GREEN}🎉 Business Pod simulation started!${NC}"
        echo -e "${BLUE}Use './start-local-business-pod.sh status' to check services${NC}"
        echo -e "${BLUE}Use './start-local-business-pod.sh stop' to stop all services${NC}"
        ;;
    "stop")
        stop_services
        echo -e "${GREEN}✅ Business Pod simulation stopped${NC}"
        ;;
    "status")
        show_status
        ;;
    *)
        echo -e "${BLUE}Usage: $0 {start|stop|status}${NC}"
        ;;
esac