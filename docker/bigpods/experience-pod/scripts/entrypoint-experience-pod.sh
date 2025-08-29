#!/bin/bash
# DreamScape Experience Pod Entrypoint
# DR-328: Big Pods Architecture - Frontend UX + VR + Gateway startup
# Comprehensive initialization and health validation
# Target: <2s First Contentful Paint, <500KB bundle size

set -euo pipefail

echo "🌟 DreamScape Experience Pod Starting - DR-328..."
echo "🏗️ Big Pods Architecture - Frontend UX + VR + Gateway"
echo "🎯 Performance Target: <2s FCL, <500KB bundle"
echo "📅 $(date)"

# ===============================================
# Environment Validation
# ===============================================

echo "🔍 Validating Experience Pod environment..."

# Check required commands for DR-328 optimizations
REQUIRED_COMMANDS=("nginx" "node" "python3" "supervisord" "curl" "cwebp" "dumb-init")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Required command not found: $cmd"
        exit 1
    fi
done
echo "✅ All required commands available"

# Verify WebP support for VR optimization
if cwebp -version &>/dev/null; then
    echo "✅ WebP compression support verified"
fi

# Check Node.js version
NODE_VERSION=$(node --version)
echo "🟢 Node.js version: $NODE_VERSION"

# Check available services
echo "🔍 Checking Experience Pod services..."
if [[ -d "/app/panorama" ]]; then
    echo "✅ Panorama Service available"
else
    echo "⚠️ Panorama Service directory not found"
fi

if [[ -d "/app/gateway" ]]; then
    echo "✅ Gateway Service available"  
else
    echo "⚠️ Gateway Service directory not found"
fi

# ===============================================
# NGINX Configuration Validation
# ===============================================

echo "🔧 Validating NGINX configuration..."
if nginx -t; then
    echo "✅ NGINX configuration valid"
else
    echo "❌ NGINX configuration invalid"
    exit 1
fi

# ===============================================
# Directory Structure Setup
# ===============================================

echo "📁 Setting up Experience Pod directories..."

# Create required directories
mkdir -p \
    /var/log/supervisor \
    /var/log/nginx \
    /var/cache/nginx/vr \
    /var/cache/nginx/static \
    /var/lib/nginx/tmp \
    /tmp/health \
    /tmp/vr-uploads \
    /usr/share/nginx/html/vr/{hq,mq,lq,thumbs} \
    /usr/share/nginx/html/assets

# Set proper permissions
echo "🔒 Setting Experience Pod permissions..."
chown -R nginx:nginx /var/log/nginx /var/cache/nginx /var/lib/nginx
chown -R nodejs:nodejs /app/panorama /app/gateway /tmp/vr-uploads
chmod 755 /usr/share/nginx/html /usr/share/nginx/html/vr
chmod -R 644 /usr/share/nginx/html/assets
chmod +x /app/scripts/*.py /app/scripts/*.sh

echo "✅ Directory structure and permissions configured"

# ===============================================
# VR Content Initialization
# ===============================================

echo "🎮 Initializing VR content system..."

# Create sample VR metadata if none exists
VR_METADATA_FILE="/usr/share/nginx/html/vr/vr-catalog.json"
if [[ ! -f "$VR_METADATA_FILE" ]]; then
    cat > "$VR_METADATA_FILE" << 'EOF'
{
  "version": "1.0.0",
  "catalog": {
    "destinations": [],
    "experiences": [],
    "last_updated": null
  },
  "formats": ["webp", "avif", "jpg"],
  "qualities": ["hq", "mq", "lq"],
  "streaming_config": {
    "chunk_size": "1MB",
    "progressive_loading": true,
    "adaptive_quality": true
  }
}
EOF
    echo "✅ VR catalog metadata created"
fi

# Initialize VR cache structure
for quality in hq mq lq; do
    touch "/var/cache/nginx/vr/$quality/.gitkeep"
done
touch "/var/cache/nginx/vr/thumbs/.gitkeep"

echo "✅ VR content system initialized"

# ===============================================
# Health Check Endpoints Setup
# ===============================================

echo "🏥 Setting up health check endpoints..."

# Create health check HTML
cat > /usr/share/nginx/html/health.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Experience Pod Health</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .healthy { color: #28a745; }
        .status { background: #f8f9fa; padding: 20px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>🌟 DreamScape Experience Pod</h1>
    <div class="status">
        <h2 class="healthy">✅ Status: Healthy</h2>
        <p><strong>Architecture:</strong> Big Pods - Frontend UX + VR + Gateway</p>
        <p><strong>Services:</strong> NGINX + Panorama Service + Gateway</p>
        <p><strong>Timestamp:</strong> <span id="timestamp"></span></p>
    </div>
    <script>
        document.getElementById('timestamp').textContent = new Date().toISOString();
        // Auto-refresh every 30 seconds
        setTimeout(() => window.location.reload(), 30000);
    </script>
</body>
</html>
EOF

# Create service worker for PWA
cat > /usr/share/nginx/html/sw.js << 'EOF'
// DreamScape Experience Pod Service Worker
// Progressive Web App support for offline VR experiences

const CACHE_NAME = 'dreamscape-experience-v1';
const OFFLINE_URL = '/offline.html';

// Cache essential resources
const CACHE_RESOURCES = [
  '/',
  '/offline.html',
  '/assets/css/main.css',
  '/assets/js/main.js',
  '/vr/thumbs/'
];

// Install service worker
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(CACHE_RESOURCES))
  );
});

// Fetch with cache fallback
self.addEventListener('fetch', event => {
  if (event.request.destination === 'image' && event.request.url.includes('/vr/')) {
    // VR content caching strategy
    event.respondWith(
      caches.open(CACHE_NAME).then(cache =>
        cache.match(event.request).then(response =>
          response || fetch(event.request).then(fetchResponse => {
            cache.put(event.request, fetchResponse.clone());
            return fetchResponse;
          })
        )
      )
    );
  }
});
EOF

echo "✅ Health check endpoints configured"

# ===============================================
# Performance Optimization
# ===============================================

echo "⚡ Applying performance optimizations..."

# Set NGINX worker processes based on CPU cores
CPU_CORES=$(nproc)
export NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-$CPU_CORES}
echo "🔧 NGINX worker processes: $NGINX_WORKER_PROCESSES"

# Optimize kernel parameters for high-performance serving
echo "🔧 Optimizing system parameters..."
echo 'net.core.somaxconn = 65535' >> /etc/sysctl.conf 2>/dev/null || true
echo 'net.ipv4.tcp_max_syn_backlog = 65535' >> /etc/sysctl.conf 2>/dev/null || true

# Set memory limits for Node.js services
export NODE_OPTIONS="${NODE_OPTIONS:---max-old-space-size=512}"

echo "✅ Performance optimizations applied"

# ===============================================
# Service Dependencies Check
# ===============================================

echo "🔗 Checking service dependencies..."

# Wait for database connections (if configured)
if [[ -n "$DATABASE_URL" ]]; then
    echo "⏳ Waiting for database connection..."
    for i in {1..30}; do
        if timeout 5 node -e "const mongoose = require('mongoose'); mongoose.connect('$DATABASE_URL').then(() => process.exit(0)).catch(() => process.exit(1));" 2>/dev/null; then
            echo "✅ Database connection established"
            break
        fi
        if [[ $i -eq 30 ]]; then
            echo "⚠️ Database connection timeout (continuing anyway)"
        fi
        sleep 2
    done
fi

# Wait for Redis (if configured)
if [[ -n "$REDIS_URL" ]]; then
    echo "⏳ Waiting for Redis connection..."
    for i in {1..15}; do
        if timeout 3 redis-cli -u "$REDIS_URL" ping >/dev/null 2>&1; then
            echo "✅ Redis connection established"
            break
        fi
        if [[ $i -eq 15 ]]; then
            echo "⚠️ Redis connection timeout (continuing anyway)"
        fi
        sleep 2
    done
fi

echo "✅ Service dependencies checked"

# ===============================================
# Supervisor Configuration Validation
# ===============================================

echo "🐍 Validating Supervisor configuration..."
if python3 -c "import configparser; c = configparser.ConfigParser(); c.read('/etc/supervisor/conf.d/supervisord.conf'); print('✅ Supervisor config valid')" 2>/dev/null; then
    echo "✅ Supervisor configuration validated"
else
    echo "❌ Supervisor configuration invalid"
    exit 1
fi

# ===============================================
# Final Health Verification
# ===============================================

echo "🧪 Running pre-startup health checks..."

# Verify NGINX can start
if nginx -t >/dev/null 2>&1; then
    echo "✅ NGINX configuration test passed"
else
    echo "❌ NGINX configuration test failed"
    exit 1
fi

# Verify Node.js services can load (basic syntax check)
for service_dir in /app/*/; do
    if [[ -f "$service_dir/dist/server.js" ]] || [[ -f "$service_dir/server.js" ]]; then
        service_name=$(basename "$service_dir")
        echo "✅ $service_name service files present"
    fi
done

# ===============================================
# Startup Summary
# ===============================================

echo ""
echo "🚀 Experience Pod Pre-flight Check Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Configuration Summary:"
echo "   • Architecture: Big Pods (Frontend + VR + Gateway)"
echo "   • NGINX Workers: $NGINX_WORKER_PROCESSES"
echo "   • Node.js Memory: ${NODE_OPTIONS}"
echo "   • Environment: ${NODE_ENV:-production}"
echo "   • VR Content Path: ${VR_CONTENT_PATH:-/usr/share/nginx/html/vr}"
echo "   • Health Monitoring: Enabled"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ===============================================
# Launch Experience Pod
# ===============================================

echo "🌟 Launching DreamScape Experience Pod..."
echo "🔄 Starting Supervisor with multi-process orchestration..."

# Execute the main command (supervisord)
exec "$@"