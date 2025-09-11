#!/bin/bash
# DreamScape Experience Pod Launcher
# Big Pods Architecture - Frontend UX + VR + Gateway Management
# Automation script for Experience Pod lifecycle

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="$SCRIPT_DIR/docker/docker-compose.experience-pod.yml"

echo "🌟 DreamScape Experience Pod Launcher"
echo "🏗️ Big Pods Architecture - Frontend UX + VR + Gateway"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ===============================================
# Helper Functions
# ===============================================

show_usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  start     - Build and start Experience Pod"
    echo "  stop      - Stop Experience Pod services"
    echo "  restart   - Restart Experience Pod"
    echo "  status    - Show Experience Pod status"
    echo "  logs      - Show Experience Pod logs"
    echo "  test      - Test all Experience Pod services"
    echo "  health    - Show detailed health status"
    echo "  clean     - Clean up containers and volumes"
    echo "  build     - Build Experience Pod images"
    echo "  dev       - Start in development mode with hot reload"
    echo "  prod      - Start in production mode with full optimization"
    echo "  vr-stats  - Show VR content statistics"
    echo ""
    echo "Options:"
    echo "  --no-cache    - Build without cache"
    echo "  --verbose     - Verbose output"
    echo "  --help        - Show this help"
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker is required but not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "❌ Docker Compose is required but not installed"
        exit 1
    fi
}

wait_for_health() {
    echo "⏳ Waiting for Experience Pod to become healthy..."
    local max_attempts=60
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f http://localhost:80/health >/dev/null 2>&1 && \
           curl -f http://localhost:3006/health >/dev/null 2>&1 && \
           curl -f http://localhost:3007/health >/dev/null 2>&1; then
            echo "✅ Experience Pod is healthy!"
            return 0
        fi
        
        echo "   Attempt $attempt/$max_attempts - waiting..."
        sleep 5
        ((attempt++))
    done
    
    echo "❌ Experience Pod failed to become healthy within timeout"
    return 1
}

show_service_urls() {
    echo ""
    echo "🔗 Experience Pod Service URLs:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🌐 Frontend Application:    http://localhost:80"
    echo "🎮 VR Content Viewer:       http://localhost:80/vr/"
    echo "🔧 Panorama Service:        http://localhost:3006"
    echo "⚡ Gateway Service:          http://localhost:3007"
    echo "🏥 Health Check:             http://localhost:80/health"
    echo "📊 NGINX Status:             http://localhost:80/nginx-status"
    echo "📈 Metrics (if enabled):    http://localhost:9091"
    echo "📋 Grafana (if enabled):    http://localhost:3001"
    echo ""
}

# ===============================================
# Command Implementations
# ===============================================

cmd_start() {
    echo "🚀 Starting Experience Pod..."
    
    # Build if needed
    if [[ "$1" == "--build" ]] || [[ ! "$(docker images -q docker-experience-pod 2>/dev/null)" ]]; then
        echo "🔨 Building Experience Pod image..."
        docker-compose -f "$COMPOSE_FILE" build ${NO_CACHE:+--no-cache} experience-pod
    fi
    
    # Start services
    echo "🔄 Starting Experience Pod services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Wait for health check
    if wait_for_health; then
        show_service_urls
        echo "✅ Experience Pod started successfully!"
    else
        echo "❌ Experience Pod startup failed - check logs"
        cmd_logs
        return 1
    fi
}

cmd_stop() {
    echo "⏹️ Stopping Experience Pod..."
    docker-compose -f "$COMPOSE_FILE" down
    echo "✅ Experience Pod stopped"
}

cmd_restart() {
    echo "🔄 Restarting Experience Pod..."
    cmd_stop
    sleep 2
    cmd_start
}

cmd_status() {
    echo "📊 Experience Pod Status:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        docker-compose -f "$COMPOSE_FILE" ps
        echo ""
        show_service_urls
        
        # Show resource usage
        echo "💾 Resource Usage:"
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep dreamscape-experience || true
    else
        echo "❌ Experience Pod is not running"
        return 1
    fi
}

cmd_logs() {
    echo "📜 Experience Pod Logs:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [[ -n "$1" ]]; then
        # Show logs for specific service
        docker-compose -f "$COMPOSE_FILE" logs -f "$1"
    else
        # Show logs for all services
        docker-compose -f "$COMPOSE_FILE" logs --tail=100 -f
    fi
}

cmd_test() {
    echo "🧪 Testing Experience Pod Services..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local tests_passed=0
    local tests_total=0
    
    # Test NGINX frontend
    ((tests_total++))
    echo -n "🌐 Testing NGINX Frontend... "
    if curl -f -s http://localhost:80/health >/dev/null; then
        echo "✅ PASS"
        ((tests_passed++))
    else
        echo "❌ FAIL"
    fi
    
    # Test Panorama Service
    ((tests_total++))
    echo -n "🎮 Testing Panorama Service... "
    if curl -f -s http://localhost:3006/health >/dev/null; then
        echo "✅ PASS"
        ((tests_passed++))
    else
        echo "❌ FAIL"
    fi
    
    # Test Gateway Service
    ((tests_total++))
    echo -n "⚡ Testing Gateway Service... "
    if curl -f -s http://localhost:3007/health >/dev/null; then
        echo "✅ PASS"
        ((tests_passed++))
    else
        echo "❌ FAIL"
    fi
    
    # Test VR Content Delivery
    ((tests_total++))
    echo -n "🎮 Testing VR Content Access... "
    if curl -f -s -I http://localhost:80/vr/ >/dev/null; then
        echo "✅ PASS"
        ((tests_passed++))
    else
        echo "❌ FAIL"
    fi
    
    # Test Static Assets
    ((tests_total++))
    echo -n "📁 Testing Static Assets... "
    if curl -f -s -I http://localhost:80/assets/ >/dev/null 2>&1 || curl -f -s -I http://localhost:80/ >/dev/null; then
        echo "✅ PASS"
        ((tests_passed++))
    else
        echo "❌ FAIL"
    fi
    
    # Test PWA Service Worker
    ((tests_total++))
    echo -n "📱 Testing PWA Service Worker... "
    if curl -f -s -I http://localhost:80/sw.js >/dev/null; then
        echo "✅ PASS"
        ((tests_passed++))
    else
        echo "❌ FAIL"
    fi
    
    echo ""
    echo "📊 Test Results: $tests_passed/$tests_total tests passed"
    
    if [[ $tests_passed -eq $tests_total ]]; then
        echo "✅ All Experience Pod tests passed!"
        return 0
    else
        echo "❌ Some Experience Pod tests failed"
        return 1
    fi
}

cmd_health() {
    echo "🏥 Experience Pod Health Status:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Container health
    echo "🐳 Container Health:"
    docker-compose -f "$COMPOSE_FILE" ps
    echo ""
    
    # Service health endpoints
    echo "🔍 Service Health Checks:"
    
    services=(
        "NGINX Frontend:http://localhost:80/health"
        "Panorama Service:http://localhost:3006/health"
        "Gateway Service:http://localhost:3007/health"
        "NGINX Status:http://localhost:80/nginx-status"
    )
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service_name service_url <<< "$service_info"
        echo -n "   $service_name: "
        if curl -f -s "$service_url" >/dev/null; then
            echo "✅ Healthy"
        else
            echo "❌ Unhealthy"
        fi
    done
    
    echo ""
    
    # System resources
    echo "💾 Resource Usage:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | grep dreamscape-experience || true
    
    echo ""
    
    # VR content stats
    cmd_vr_stats
}

cmd_clean() {
    echo "🧹 Cleaning up Experience Pod..."
    
    read -p "⚠️  This will remove all containers and volumes. Continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️ Removing containers and volumes..."
        docker-compose -f "$COMPOSE_FILE" down -v --rmi local
        
        # Clean up any dangling images
        docker image prune -f
        
        echo "✅ Experience Pod cleanup completed"
    else
        echo "❌ Cleanup cancelled"
    fi
}

cmd_build() {
    echo "🔨 Building Experience Pod..."
    docker-compose -f "$COMPOSE_FILE" build ${NO_CACHE:+--no-cache} experience-pod
    echo "✅ Experience Pod build completed"
}

cmd_dev() {
    echo "🛠️ Starting Experience Pod in development mode..."
    
    # Set development environment
    export NODE_ENV=development
    export COMPOSE_PROFILES=monitoring,logging
    
    # Start with hot reload enabled
    docker-compose -f "$COMPOSE_FILE" up -d
    
    if wait_for_health; then
        show_service_urls
        echo ""
        echo "🛠️ Development mode features:"
        echo "   • Hot reload enabled"
        echo "   • Detailed logging"
        echo "   • Development tools available"
        echo "   • Monitoring stack active"
        echo ""
        echo "✅ Experience Pod development environment ready!"
    fi
}

cmd_prod() {
    echo "🚀 Starting Experience Pod in production mode..."
    
    # Set production environment
    export NODE_ENV=production
    export COMPOSE_PROFILES=monitoring
    
    # Build for production
    docker-compose -f "$COMPOSE_FILE" build --no-cache experience-pod
    
    # Start in production mode
    docker-compose -f "$COMPOSE_FILE" up -d
    
    if wait_for_health; then
        show_service_urls
        echo "🚀 Experience Pod production deployment successful!"
    fi
}

cmd_vr_stats() {
    echo "🎮 VR Content Statistics:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if container is running
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "experience-pod.*Up"; then
        echo "❌ Experience Pod is not running"
        return 1
    fi
    
    # Get VR stats from container
    docker exec dreamscape-experience-pod /bin/bash -c "
        echo '📁 VR Content Files:'
        find /usr/share/nginx/html/vr -type f -name '*.jpg' -o -name '*.png' -o -name '*.webp' -o -name '*.avif' 2>/dev/null | wc -l | xargs echo '   Original files:'
        find /var/cache/nginx/vr -type f 2>/dev/null | wc -l | xargs echo '   Cached variants:'
        echo ''
        echo '💾 Storage Usage:'
        du -sh /usr/share/nginx/html/vr 2>/dev/null | cut -f1 | xargs echo '   VR content size:'
        du -sh /var/cache/nginx/vr 2>/dev/null | cut -f1 | xargs echo '   Cache size:'
        echo ''
        echo '📊 Quality Variants:'
        for quality in hq mq lq; do
            count=\$(find /var/cache/nginx/vr/\$quality -type f 2>/dev/null | wc -l)
            echo \"   \$quality: \$count files\"
        done
        echo ''
        echo '🖼️ Thumbnails:'
        find /var/cache/nginx/vr/thumbs -name '*.jpg' 2>/dev/null | wc -l | xargs echo '   Generated:'
    "
}

# ===============================================
# Main Command Processing
# ===============================================

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cache)
            NO_CACHE=1
            shift
            ;;
        --verbose)
            set -x
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Check dependencies
check_docker

# Get command
COMMAND=${1:-start}
shift 2>/dev/null || true

# Execute command
case $COMMAND in
    start)
        cmd_start "$@"
        ;;
    stop)
        cmd_stop "$@"
        ;;
    restart)
        cmd_restart "$@"
        ;;
    status)
        cmd_status "$@"
        ;;
    logs)
        cmd_logs "$@"
        ;;
    test)
        cmd_test "$@"
        ;;
    health)
        cmd_health "$@"
        ;;
    clean)
        cmd_clean "$@"
        ;;
    build)
        cmd_build "$@"
        ;;
    dev)
        cmd_dev "$@"
        ;;
    prod)
        cmd_prod "$@"
        ;;
    vr-stats)
        cmd_vr_stats "$@"
        ;;
    *)
        echo "❌ Unknown command: $COMMAND"
        echo ""
        show_usage
        exit 1
        ;;
esac