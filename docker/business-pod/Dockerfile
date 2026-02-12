FROM node:20-alpine AS services-builder

# Build tous les services métier + shared packages
WORKDIR /build

# Copy shared packages first (dependencies)
COPY --from=dreamscape-services /db/ ./db/
COPY --from=dreamscape-services /shared/ ./shared/

# Copy services
COPY --from=dreamscape-services /voyage/ ./voyage/
COPY --from=dreamscape-services /ai/ ./ai/
COPY --from=dreamscape-services /payment/ ./payment/

# Build shared packages first
RUN cd db && npm ci && echo "DB dependencies installed"
RUN cd shared/kafka && npm ci && npm run build && echo "Kafka package built"

# Build services with shared dependencies available
RUN cd voyage && npm ci && npm run build
RUN cd ai && npm ci && npm run build
RUN cd payment && npm ci && npm run build

# Create symlinks for compiled services to access shared packages
RUN cd voyage/dist && ln -sf /app/db/node_modules db/node_modules
RUN cd voyage/dist && ln -sf /app/shared shared

# Runtime environment with Supervisor
FROM node:20-alpine AS runtime
RUN apk add --no-cache bash supervisor

COPY --from=services-builder /build/ /app/
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start-business-pod.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start-business-pod.sh

EXPOSE 3003 3004 3005
CMD ["/usr/local/bin/start-business-pod.sh"]