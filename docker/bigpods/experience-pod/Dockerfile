# DreamScape Experience Pod - Big Pods Architecture
# Frontend UX + Panorama VR + Gateway services intégrés
# Architecture Hybride: 6-repos → 3-Big-Pods
# DR-328: Multi-stage optimized build for performance

# ===============================================
# Stage 1: Frontend Builder (Web Client)
# ===============================================
FROM node:20-alpine AS frontend-builder

# Install build dependencies
RUN apk add --no-cache git python3 make g++ curl

# Set working directory for web client build
WORKDIR /build/web

# Expect dreamscape-frontend repo to be cloned by CI/CD at ../../../dreamscape-frontend
# Copy entire web-client directory
COPY ../../../dreamscape-frontend/web-client/ ./

# Copy .env.staging and rename to .env for Vite to use during build
# This injects the staging URLs (79.72.27.180:30318) into the frontend bundle
COPY .env.staging ./.env

# Install dependencies
RUN npm ci --silent && npm cache clean --force

# Build with production optimizations (Vite will load .env)
RUN npm run build

# ===============================================
# Stage 2: Gateway Builder
# ===============================================
FROM node:20-alpine AS gateway-builder

WORKDIR /build/gateway

# Copy gateway service code (already in this repo)
COPY services/gateway-service/ ./

# Install dependencies
RUN npm ci --only=production --silent && npm cache clean --force

# ===============================================
# Stage 3: Panorama Service Builder
# ===============================================
FROM node:20-alpine AS panorama-builder

WORKDIR /build/panorama

# Install VR content processing tools
RUN apk add --no-cache imagemagick ffmpeg libwebp-tools

# For testing - create dummy panorama package.json
RUN echo '{"name":"panorama","version":"1.0.0","scripts":{"build":"echo Panorama Built"},"dependencies":{"express":"^4.18.0"}}' > package.json
RUN npm ci --only=production --silent && npm cache clean --force || true

# Create dummy panorama build output and VR assets
RUN mkdir -p dist src/assets && echo 'console.log("Panorama Service Starting");' > dist/server.js
RUN echo '{"vr_content": "placeholder"}' > src/assets/vr-content.json
RUN npm run build

# VR optimization placeholder (will be handled by runtime optimizer)
RUN echo "VR optimization ready"

# ===============================================
# Stage 4: Runtime - Experience Pod
# ===============================================
FROM node:20-alpine AS runtime

# Install system dependencies optimized for production
RUN apk add --no-cache \
    nginx \
    supervisor \
    python3 \
    py3-pip \
    py3-psutil \
    curl \
    bash \
    tzdata \
    ca-certificates \
    dumb-init \
    imagemagick \
    ffmpeg \
    libwebp-tools \
    && rm -rf /var/cache/apk/*

# Create application directories with proper structure
WORKDIR /app
RUN mkdir -p \
    /app/gateway \
    /app/panorama \
    /app/scripts \
    /app/logs \
    /usr/share/nginx/html \
    /var/log/supervisor \
    /var/log/nginx \
    /etc/supervisor/conf.d \
    /var/cache/nginx \
    /var/lib/nginx/tmp \
    /run/nginx

# Create users for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -D -H -u 1001 -h /app -s /sbin/nologin -G nodejs -g nodejs nodejs

# ===============================================
# Copy Built Applications - Optimized
# ===============================================

# Static web assets (optimized and pre-compressed)
COPY --from=frontend-builder /build/web/dist /usr/share/nginx/html/
# Copy pre-compressed assets for NGINX gzip_static
COPY --from=frontend-builder /build/web/dist/*.gz /usr/share/nginx/html/

# Gateway service (Node.js - no build needed, direct copy)
COPY --from=gateway-builder /build/gateway/ /app/gateway/

# Install gateway production dependencies
WORKDIR /app/gateway
RUN npm install --only=production --silent && npm cache clean --force || true

# Panorama service with optimized VR content
COPY --from=panorama-builder /build/panorama/dist /app/panorama/dist/
COPY --from=panorama-builder /build/panorama/package.json /app/panorama/
# Copy proper panorama service
COPY services/panorama-service/server.js /app/panorama/dist/server.js
COPY services/panorama-service/package.json /app/panorama/package.json

# Install panorama production dependencies
WORKDIR /app/panorama
RUN npm install --only=production --silent && npm cache clean --force || true

# Back to main working directory
WORKDIR /app

# VR assets optimized for web delivery
COPY --from=panorama-builder /build/panorama/src /usr/share/nginx/html/vr/

# ===============================================
# Experience Pod Configuration
# ===============================================

# NGINX configuration optimized for static assets and VR streaming
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/experience-pod.conf /etc/nginx/conf.d/default.conf
COPY nginx/vr-streaming.conf /etc/nginx/conf.d/vr-streaming.conf

# Supervisor configuration for multi-process orchestration
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Scripts and health monitoring
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.py /app/scripts/*.sh

# Entrypoint script
COPY scripts/entrypoint-experience-pod.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && \
    # Fix line endings for Docker compatibility
    sed -i 's/\r$//' /usr/local/bin/entrypoint.sh

# ===============================================
# Permissions and Security
# ===============================================

# Set proper permissions for security
RUN chown -R nodejs:nodejs /app/gateway /app/panorama /app/logs \
    && chown -R nginx:nginx /var/log/nginx /var/cache/nginx /var/lib/nginx /run/nginx \
    && chown -R nginx:nginx /usr/share/nginx/html \
    && chmod -R 755 /usr/share/nginx/html \
    && chmod -R 750 /app/logs

# ===============================================
# Performance & Production Optimizations
# ===============================================

# Environment variables optimized for production
ENV NODE_ENV=production \
    NODE_OPTIONS="--max-old-space-size=512" \
    NGINX_WORKER_PROCESSES=auto \
    NGINX_WORKER_CONNECTIONS=1024 \
    PANORAMA_PORT=3006 \
    GATEWAY_PORT=3007 \
    TZ=UTC

# ===============================================
# Ports and Health Checks
# ===============================================

# Expose ports
EXPOSE 80 3006

# Enhanced health check for Experience Pod with all services
HEALTHCHECK --interval=15s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost/health && \
        curl -f http://localhost:3006/health && \
        pgrep -f nginx > /dev/null && \
        pgrep -f supervisord > /dev/null || exit 1

# Labels for Docker metadata and monitoring
LABEL \
    com.dreamscape.service="experience-pod" \
    com.dreamscape.version="1.2.0" \
    com.dreamscape.environment="production" \
    com.dreamscape.architecture="big-pods" \
    com.dreamscape.components="web-client,panorama-service,gateway" \
    com.dreamscape.description="Experience Pod - Frontend UX + VR + Gateway" \
    com.dreamscape.ticket="DR-328" \
    com.dreamscape.performance.target="<2s FCL" \
    com.dreamscape.bundle.size="<500KB"

# Start Experience Pod with dumb-init for proper signal handling
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/usr/local/bin/entrypoint.sh", "supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf", "-n"]