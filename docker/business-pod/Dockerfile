FROM node:20-alpine AS services-builder

# Build tous les services métier
WORKDIR /build
COPY --from=dreamscape-services /voyage/ ./voyage/
COPY --from=dreamscape-services /ai/ ./ai/
COPY --from=dreamscape-services /payment/ ./payment/

# Build optimisé avec cache
RUN cd voyage && npm ci && npm run build
RUN cd ai && npm ci && npm run build  
RUN cd payment && npm ci && npm run build

# Runtime environment with Supervisor
FROM node:20-alpine AS runtime
RUN apk add --no-cache bash supervisor

COPY --from=services-builder /build/ /app/
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY start-business-pod.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start-business-pod.sh

EXPOSE 3003 3004 3005
CMD ["/usr/local/bin/start-business-pod.sh"]