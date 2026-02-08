#!/bin/sh
# Entrypoint script for DreamScape Business Pod
# DR-327: INFRA-011.3 Initializes multi-process container with Supervisor

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 DreamScape Business Pod Starting...${NC}"
echo -e "${BLUE}DR-327: INFRA-011 - Supervisor Multi-Process Orchestration${NC}"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
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

# Log directories and nginx runtime
mkdir -p /var/log/supervisor /var/log/nginx /run/nginx
chown -R root:root /var/log/supervisor
chown -R nginx:nginx /var/log/nginx /run/nginx

# Application directories
mkdir -p /app/voyage/logs /app/ai/logs /app/payment/logs
chown nodejs:nodejs /app/voyage/logs /app/ai/logs /app/payment/logs 2>/dev/null || true

# Supervisor socket directory
mkdir -p /var/run/supervisor
chown root:root /var/run/supervisor

# Export environment variables BEFORE supervisor validation
# Supervisor needs these during config validation for %(ENV_*)s expansion
export NODE_ENV="${NODE_ENV:-production}"
export PORT_VOYAGE="${PORT_VOYAGE:-3003}"
export PORT_AI="${PORT_AI:-3004}"
export PORT_PAYMENT="${PORT_PAYMENT:-3005}"
export DATABASE_URL="${DATABASE_URL}"
export REDIS_URL="${REDIS_URL}"
export PAYMENT_SERVICE_URL="${PAYMENT_SERVICE_URL:-http://dreamscape-payment-service:3005}"
export STRIPE_SECRET_KEY="${STRIPE_SECRET_KEY}"
export STRIPE_PUBLISHABLE_KEY="${STRIPE_PUBLISHABLE_KEY}"
export STRIPE_WEBHOOK_SECRET="${STRIPE_WEBHOOK_SECRET}"
export FRONTEND_URL="${FRONTEND_URL}"

# Validate Supervisor configuration
echo -e "${YELLOW}🔧 Validating Supervisor configuration...${NC}"
if supervisord -c /etc/supervisor/conf.d/supervisord.conf -t; then
    echo -e "${GREEN}✅ Supervisor configuration valid${NC}"
else
    echo -e "${RED}❌ Supervisor configuration invalid${NC}"
    exit 1
fi

# Initialize databases (Prisma) - Run migrations and generate client
echo -e "${YELLOW}🗄️ Initializing databases...${NC}"

# Run Prisma migrations from shared db folder
if [ -d "/app/db" ]; then
    cd /app/db
    echo -e "${BLUE}🚀 Running database migrations...${NC}"

    # Wait for database to be ready (with timeout)
    echo -e "${BLUE}⏳ Waiting for database to be ready...${NC}"
    MAX_RETRIES=30
    RETRY_COUNT=0

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if npx prisma db execute --stdin <<< "SELECT 1;" 2>/dev/null; then
            echo -e "${GREEN}✅ Database is ready${NC}"
            break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo -e "${YELLOW}⏳ Waiting for database... (attempt $RETRY_COUNT/$MAX_RETRIES)${NC}"
        sleep 2
    done

    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo -e "${RED}❌ Database not ready after $MAX_RETRIES attempts${NC}"
        echo -e "${YELLOW}⚠️ Continuing without migrations - service may fail if DB schema is not initialized${NC}"
    else
        # Run migrations
        echo -e "${BLUE}📦 Deploying Prisma migrations...${NC}"
        if npx prisma migrate deploy; then
            echo -e "${GREEN}✅ Database migrations completed successfully${NC}"
        else
            echo -e "${RED}❌ Database migrations failed${NC}"
            echo -e "${YELLOW}⚠️ Continuing anyway - service may fail if DB schema is not initialized${NC}"
        fi
    fi
fi

# Generate Prisma client for voyage service if needed
if [ -d "/app/voyage/prisma" ]; then
    cd /app/voyage
    echo -e "${BLUE}📦 Generating Prisma client for voyage service...${NC}"
    npx prisma generate || echo -e "${YELLOW}⚠️ Prisma generation failed for voyage service${NC}"
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
for port in 80 3003 3004 3005; do
    if netstat -ln 2>/dev/null | grep -q ":$port "; then
        echo -e "${RED}❌ Port $port is already in use${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✅ All ports available${NC}"

# Start Supervisor in the background for initialization
echo -e "${YELLOW}🚀 Starting Supervisor...${NC}"

echo -e "${GREEN}✅ Business Pod initialization completed${NC}"
echo ""
echo -e "${BLUE}🎯 Starting services:${NC}"
echo -e "  • Voyage Service (port 3003)"
echo -e "  • AI Service - Stub (port 3004)"
echo -e "  • Payment Service - Stub (port 3005)"
echo -e "  • NGINX Reverse Proxy (port 80)"
echo -e "  • Health Monitor"
echo ""

# Execute the main command (Supervisor)
exec "$@"
