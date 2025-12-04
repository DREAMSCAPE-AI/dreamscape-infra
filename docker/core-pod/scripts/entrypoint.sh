#!/bin/sh
# Entrypoint script for DreamScape Core Pod
# DR-336: INFRA-010.3 - Initializes multi-process container with Supervisor

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 DreamScape Core Pod Starting...${NC}"
echo -e "${BLUE}DR-336: INFRA-010.3 - Supervisor Multi-Process Orchestration${NC}"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for a service to be ready
wait_for_service() {
    local service_name=$1
    local url=$2
    local timeout=${3:-30}
    local interval=${4:-2}
    
    echo -e "${YELLOW}⏳ Waiting for $service_name to be ready...${NC}"
    
    local count=0
    local max_count=$((timeout / interval))
    
    while [ $count -lt $max_count ]; do
        if curl -f -s "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ $service_name is ready${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}⏳ Waiting for $service_name... ($((count + 1))/$max_count)${NC}"
        sleep $interval
        count=$((count + 1))
    done
    
    echo -e "${RED}❌ $service_name failed to become ready within ${timeout}s${NC}"
    return 1
}

# Validate required environment variables
echo -e "${YELLOW}🔍 Validating environment...${NC}"

# Check if required commands exist
for cmd in supervisord supervisorctl nginx node python3; do
    if ! command_exists "$cmd"; then
        echo -e "${RED}❌ Required command not found: $cmd${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✅ All required commands available${NC}"

# Validate NGINX configuration
echo -e "${YELLOW}🔧 Validating NGINX configuration...${NC}"
if nginx -t; then
    echo -e "${GREEN}✅ NGINX configuration valid${NC}"
else
    echo -e "${RED}❌ NGINX configuration invalid${NC}"
    exit 1
fi

# Create necessary directories and set permissions
echo -e "${YELLOW}📁 Creating directories and setting permissions...${NC}"

# Log directories
mkdir -p /var/log/supervisor /var/log/nginx /run/nginx
chown -R root:root /var/log/supervisor
chown -R nginx:nginx /var/log/nginx /run/nginx

# Application directories
mkdir -p /app/auth/logs /app/user/logs /app/user/uploads
# Note: chown déjà appliqué dans le Dockerfile avec --chown sur les COPY
# chown -R nodejs:nodejs /app/auth /app/user  # Commenté pour performance
chown nodejs:nodejs /app/auth/logs /app/user/logs /app/user/uploads
chmod 755 /app/user/uploads

# Supervisor socket directory
mkdir -p /var/run/supervisor
chown root:root /var/run/supervisor

# Validate Supervisor configuration
echo -e "${YELLOW}🔧 Validating Supervisor configuration...${NC}"
if supervisord -c /etc/supervisor/conf.d/supervisord.conf -t; then
    echo -e "${GREEN}✅ Supervisor configuration valid${NC}"
else
    echo -e "${RED}❌ Supervisor configuration invalid${NC}"
    exit 1
fi

# Initialize databases (Prisma)
echo -e "${YELLOW}🗄️ Initializing databases...${NC}"

# Auth service database
if [ -d "/app/auth/prisma" ]; then
    cd /app/auth
    echo -e "${BLUE}📦 Generating Prisma client for auth service...${NC}"
    npx prisma generate || echo -e "${YELLOW}⚠️ Prisma generation failed for auth service${NC}"
fi

# User service database
if [ -d "/app/user/prisma" ]; then
    cd /app/user
    echo -e "${BLUE}📦 Generating Prisma client for user service...${NC}"
    npx prisma generate || echo -e "${YELLOW}⚠️ Prisma generation failed for user service${NC}"
fi

cd /app

# Set up signal handlers for graceful shutdown
setup_signal_handlers() {
    trap 'handle_signal TERM' TERM
    trap 'handle_signal INT' INT
    trap 'handle_signal QUIT' QUIT
}

handle_signal() {
    local signal=$1
    echo -e "${YELLOW}📨 Received SIG${signal}, initiating graceful shutdown...${NC}"
    
    # Stop all Supervisor programs gracefully
    supervisorctl -c /etc/supervisor/conf.d/supervisord.conf stop all
    
    # Wait for processes to stop
    sleep 5
    
    # Stop Supervisor
    supervisorctl -c /etc/supervisor/conf.d/supervisord.conf shutdown
    
    echo -e "${GREEN}✅ Graceful shutdown completed${NC}"
    exit 0
}

# Setup signal handlers
setup_signal_handlers

# Pre-flight checks
echo -e "${YELLOW}🏥 Running pre-flight health checks...${NC}"

# Check if ports are available
for port in 80 3001 3002; do
    if netstat -ln | grep -q ":$port "; then
        echo -e "${RED}❌ Port $port is already in use${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✅ All ports available${NC}"

# Start Supervisor in the background for initialization
echo -e "${YELLOW}🚀 Starting Supervisor...${NC}"

# Export environment variables for Supervisor programs
export NODE_ENV="${NODE_ENV:-production}"
export PORT_AUTH="${PORT_AUTH:-3001}"
export PORT_USER="${PORT_USER:-3002}"

echo -e "${GREEN}✅ Core Pod initialization completed${NC}"
echo ""
echo -e "${BLUE}🎯 Starting services:${NC}"
echo -e "  • Auth Service (port 3001)"
echo -e "  • User Service (port 3002)" 
echo -e "  • NGINX Reverse Proxy (port 80)"
echo -e "  • Health Monitor"
echo -e "  • Process Monitor"
echo ""

# Execute the main command (Supervisor)
exec "$@"