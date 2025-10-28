# DreamScape Big Pods Development Environment

Complete local development setup for DreamScape's hybrid architecture: **6 repositories → 3 Big Pods**

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    DreamScape Big Pods                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐         │
│  │  Core Pod    │  │ Business Pod │  │ Experience Pod│         │
│  ├──────────────┤  ├──────────────┤  ├───────────────┤         │
│  │ NGINX        │  │ Voyage Svc   │  │ Web Client    │         │
│  │ Auth Service │  │ AI Service   │  │ Panorama      │         │
│  │ User Service │  │ Payment Svc  │  │ Gateway       │         │
│  └──────┬───────┘  └──────┬───────┘  └───────┬───────┘         │
│         │                  │                  │                  │
│         └──────────────────┴──────────────────┘                  │
│                            │                                      │
│         ┌──────────────────┴──────────────────┐                 │
│         │    Infrastructure Services          │                 │
│         ├─────────────────────────────────────┤                 │
│         │ PostgreSQL │ Redis │ Kafka │ MinIO │                 │
│         └─────────────────────────────────────┘                 │
└─────────────────────────────────────────────────────────────────┘
```

### Big Pods Structure

- **Core Pod**: Authentication, user management, NGINX gateway
  - Port 80/443: NGINX Gateway
  - Port 3001: Auth Service
  - Port 3002: User Service

- **Business Pod**: Voyage planning, AI generation, payments
  - Port 3003: Voyage Service
  - Port 3004: AI Service
  - Port 3005: Payment Service

- **Experience Pod**: Frontend, VR panorama, WebSocket gateway
  - Port 3000: Web Client (Vite dev server)
  - Port 5173: Vite HMR
  - Port 3006: Panorama Service
  - Port 4000: Gateway Service

## Quick Start

### Prerequisites

- Docker Desktop (20.10+) or Docker Engine + Docker Compose
- 8GB+ RAM recommended (6GB minimum)
- 20GB+ free disk space
- Node.js 18+ (for local development outside containers)

### 1. Clone Required Repositories

The Big Pods setup expects this directory structure:

```
workspace/
├── dreamscape-infra/          # Infrastructure & deployment (this repo)
├── dreamscape-services/       # Backend microservices
│   ├── auth/
│   ├── user/
│   ├── voyage/
│   ├── ai/
│   └── payment/
└── dreamscape-frontend/       # Frontend applications
    ├── web-client/
    ├── panorama/
    └── gateway/
```

### 2. Configure Environment

```bash
# Copy the example environment file
cp .env.bigpods.example .env.bigpods.local

# Edit the file to add your API keys (optional for basic testing)
# Required for full functionality:
#   - AMADEUS_TEST_KEY / AMADEUS_TEST_SECRET (for voyage search)
#   - STRIPE_TEST_KEY (for payment processing)
#   - OPENAI_API_KEY (for AI features)
```

### 3. Start All Services

```bash
# From the dreamscape-infra directory
./scripts/bigpods/dev-bigpods.sh
```

The script will:
- Verify prerequisites (Docker, repositories)
- Create environment file if needed
- Build all 3 Big Pods
- Start infrastructure services (PostgreSQL, Redis, Kafka, MinIO)
- Wait for services to be healthy
- Display service URLs and credentials

**First-time setup takes 5-10 minutes**. Subsequent starts are much faster.

### 4. Verify Setup

Once started, access:
- **Web Application**: http://localhost:3000
- **API Gateway**: http://localhost/api/v1
- **MinIO Console**: http://localhost:9001 (user: dreamscape-dev, password: dreamscape-dev-secret)

## Service URLs

### Application Services

| Service | URL | Port | Description |
|---------|-----|------|-------------|
| Web Application | http://localhost:3000 | 3000 | Vite-powered React app |
| Vite HMR | http://localhost:5173 | 5173 | Hot Module Replacement |
| NGINX Gateway | http://localhost | 80 | Main API gateway |
| Auth Service | http://localhost:3001 | 3001 | Authentication & JWT |
| User Service | http://localhost:3002 | 3002 | User profiles |
| Voyage Service | http://localhost:3003 | 3003 | Travel planning |
| AI Service | http://localhost:3004 | 3004 | AI generation |
| Payment Service | http://localhost:3005 | 3005 | Stripe integration |
| Panorama Service | http://localhost:3006 | 3006 | VR panorama |
| Gateway Service | http://localhost:4000 | 4000 | WebSocket gateway |

### Infrastructure Services

| Service | URL | Port | Credentials |
|---------|-----|------|-------------|
| PostgreSQL | localhost:5432 | 5432 | user: `dev`, password: `dev123` |
| Redis | localhost:6379 | 6379 | No password |
| Kafka | localhost:9092 | 9092 | No auth |
| MinIO S3 | http://localhost:9000 | 9000 | access: `dreamscape-dev` |
| MinIO Console | http://localhost:9001 | 9001 | user: `dreamscape-dev`, password: `dreamscape-dev-secret` |

## Development Workflow

### Hot Reload

All services support hot reload via volume mounting:

```yaml
# Services automatically reload when you edit:
volumes:
  - ../../dreamscape-services/auth:/app/auth:delegated
  - ../../dreamscape-frontend/web-client:/app/web:delegated
```

**Changes in your local files are immediately reflected in running containers.**

### Viewing Logs

```bash
# All services
docker compose -f docker/docker-compose.bigpods.dev.yml logs -f

# Specific pod
docker compose -f docker/docker-compose.bigpods.dev.yml logs -f core-pod
docker compose -f docker/docker-compose.bigpods.dev.yml logs -f business-pod
docker compose -f docker/docker-compose.bigpods.dev.yml logs -f experience-pod

# Infrastructure service
docker compose -f docker/docker-compose.bigpods.dev.yml logs -f postgres
```

### Debugging Node.js Services

Each Node.js service exposes a debugger port:

| Service | Debug Port |
|---------|-----------|
| Auth | 9229 |
| User | 9230 |
| Voyage | 9231 |
| AI | 9232 |
| Payment | 9233 |
| Panorama | 9234 |
| Gateway | 9235 |

**VS Code Launch Configuration:**

```json
{
  "type": "node",
  "request": "attach",
  "name": "Attach to Auth Service",
  "port": 9229,
  "restart": true,
  "sourceMaps": true
}
```

### Database Operations

```bash
# Connect to PostgreSQL
docker exec -it dreamscape-postgres psql -U dev -d dreamscape_dev

# Run migrations (from within core-pod)
docker exec -it dreamscape-core-pod sh -c "cd /app/auth && npm run migrate"

# Reset database (WARNING: destroys all data)
./scripts/bigpods/reset-bigpods.sh
```

### Managing Services

```bash
# Stop all services
docker compose -f docker/docker-compose.bigpods.dev.yml down

# Stop and remove volumes (full reset)
docker compose -f docker/docker-compose.bigpods.dev.yml down -v

# Restart a specific pod
docker compose -f docker/docker-compose.bigpods.dev.yml restart core-pod

# Rebuild and restart (after Dockerfile changes)
docker compose -f docker/docker-compose.bigpods.dev.yml up --build -d core-pod
```

## Troubleshooting

### Port Conflicts

**Error**: `Bind for 0.0.0.0:3000 failed: port is already allocated`

**Solution**:
```bash
# Find what's using the port
lsof -i :3000        # macOS/Linux
netstat -ano | findstr :3000  # Windows

# Kill the process or change the port in docker-compose.bigpods.dev.yml
```

### Volume Permissions

**Error**: `EACCES: permission denied` or `Cannot create directory`

**Solution**:
```bash
# macOS/Linux: Fix ownership
sudo chown -R $(whoami):$(whoami) ../dreamscape-services ../dreamscape-frontend

# Windows: Ensure Docker Desktop has access to the drives
# Docker Desktop → Settings → Resources → File Sharing
```

### Database Connection Failed

**Error**: `connect ECONNREFUSED postgres:5432`

**Solution**:
```bash
# Check if PostgreSQL is healthy
docker compose -f docker/docker-compose.bigpods.dev.yml ps

# If postgres is unhealthy, check logs
docker compose -f docker/docker-compose.bigpods.dev.yml logs postgres

# Restart PostgreSQL
docker compose -f docker/docker-compose.bigpods.dev.yml restart postgres
```

### Services Not Starting

**Error**: Container exits immediately after start

**Solution**:
```bash
# Check logs for the specific service
docker compose -f docker/docker-compose.bigpods.dev.yml logs <service-name>

# Common issues:
# 1. Missing dependencies: rebuild images
docker compose -f docker/docker-compose.bigpods.dev.yml build --no-cache

# 2. Syntax errors in code: check your recent changes
# 3. Missing environment variables: verify .env.bigpods.local
```

### Kafka Not Ready

**Error**: `KafkaJSConnectionError: Connection timeout`

**Solution**:
```bash
# Kafka can take 60-90 seconds to fully start
# Wait and check health
docker exec dreamscape-kafka kafka-topics --bootstrap-server localhost:9092 --list

# If still failing, restart Kafka
docker compose -f docker/docker-compose.bigpods.dev.yml restart kafka
```

### Out of Memory

**Error**: `JavaScript heap out of memory`

**Solution**:
```bash
# Increase Docker Desktop memory allocation
# Docker Desktop → Settings → Resources → Memory → 8GB+

# Or add resource limits to docker-compose.bigpods.dev.yml
```

### MinIO Buckets Not Created

**Error**: `The specified bucket does not exist`

**Solution**:
```bash
# Check if minio-init ran successfully
docker compose -f docker/docker-compose.bigpods.dev.yml logs minio-init

# Manually create buckets
docker exec dreamscape-minio mc alias set local http://localhost:9000 dreamscape-dev dreamscape-dev-secret
docker exec dreamscape-minio mc mb local/dreamscape-vr-assets --ignore-existing
```

## Testing

### Test Accounts

The development environment comes with pre-seeded test accounts:

| Email | Password | Role |
|-------|----------|------|
| dev@dreamscape.ai | password123 | Admin |
| john@example.com | password123 | User |

### API Testing

```bash
# Health checks
curl http://localhost/health
curl http://localhost:3001/health
curl http://localhost:3003/health

# Login
curl -X POST http://localhost:3001/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"dev@dreamscape.ai","password":"password123"}'

# Get user profile (requires JWT token)
curl http://localhost:3002/api/v1/users/me \
  -H "Authorization: Bearer <your-jwt-token>"
```

## Architecture Details

### Supervisord Multi-Process Management

Each Big Pod runs multiple services using Supervisord:

```ini
[program:auth-service]
command=npm run dev
directory=/app/auth
autostart=true
autorestart=true
```

### NGINX Routing

The Core Pod's NGINX routes requests to appropriate services:

```nginx
location /api/v1/auth {
    proxy_pass http://localhost:3001;
}

location /api/v1/users {
    proxy_pass http://localhost:3002;
}
```

### Inter-Service Communication

- Services communicate via internal Docker network: `bigpods-network`
- Events published to Kafka topics: `user.created`, `payment.processed`, etc.
- Caching layer: Redis for sessions, rate limiting, caching

## Performance Optimization

### Development vs Production

This setup is optimized for **development**:
- Source maps enabled
- Hot reload enabled
- Debug logging
- No asset minification
- No CDN caching

**Do not use this setup in production!** See `k3s/` directory for production deployment.

### Resource Usage

Typical resource consumption:
- **CPU**: 2-4 cores (spikes during builds)
- **RAM**: 4-6 GB
- **Disk**: 10-15 GB (Docker images + volumes)

## Contributing

### Adding a New Service

1. Add service to appropriate Big Pod Dockerfile
2. Configure Supervisord in `supervisord.conf`
3. Add volume mount in `docker-compose.bigpods.dev.yml`
4. Expose debug port if needed
5. Add health check endpoint
6. Update this README

### Modifying NGINX Configuration

1. Edit `docker/bigpods/core-pod/nginx.dev.conf`
2. Reload NGINX: `docker exec dreamscape-core-pod nginx -s reload`
3. Test configuration: `docker exec dreamscape-core-pod nginx -t`

## Additional Resources

- [DreamScape Architecture Documentation](../../docs/architecture/)
- [K3s Production Deployment](../k3s/)
- [API Documentation](../../docs/api/)
- [Environment Variables Reference](../../.env.bigpods.example)

## Support

For issues and questions:
- Check the troubleshooting section above
- Review logs: `docker compose -f docker/docker-compose.bigpods.dev.yml logs`
- Open an issue in the repository
- Contact the DevOps team

---

**Built with** Supervisord, NGINX, Docker Compose, and lots of coffee
