🏗️ DreamScape Infrastructure

> **Infrastructure Platform** - DevOps, déploiement et orchestration complète

## 📁 Structure Infrastructure

- **docker/** - Configurations Docker & compose files
- **k8s/** - Manifests Kubernetes & orchestration
- **terraform/** - Infrastructure as Code (IaC)
- **monitoring/** - Prometheus, Grafana, observabilité
- **scripts/** - Scripts déploiement & automation
- **cicd/** - Pipelines CI/CD & workflows GitHub Actions

## 🛠️ Stack DevOps

### **Containerisation**
- **Docker** - Containerisation applications
- **Docker Compose** - Orchestration locale
- **Multi-stage Builds** - Images optimisées
- **Registry** - GitHub Container Registry

### **Orchestration**
- **Kubernetes (K8s)** - Orchestration production
- **Helm Charts** - Package management K8s
- **Ingress Controllers** - Traffic routing
- **Service Mesh** - Communication sécurisée

### **Infrastructure as Code**
- **Terraform** - Provisioning infrastructure
- **Cloud Provider** - AWS/GCP/Azure support
- **State Management** - Remote state S3
- **Modules** - Infrastructure réutilisable

### **Monitoring & Observabilité**
- **Prometheus** - Métriques collection
- **Grafana** - Dashboards & visualisation
- **Alertmanager** - Alerting intelligent
- **Sentry** - Error tracking
- **ELK Stack** - Logs centralisés

## 🚀 Quick Start

### Développement Local
```bash
# Setup environnement local
cd docker && docker-compose up -d

# Vérification services
docker-compose ps
docker-compose logs -f [service]

# Arrêt environnement
docker-compose down
```

### Déploiement Kubernetes
```bash
# Déploiement K8s
cd k8s && kubectl apply -f .

# Vérification pods
kubectl get pods -n dreamscape

# Port forwarding
kubectl port-forward service/gateway 3000:3000
```

### Infrastructure Terraform
```bash
# Initialisation Terraform
cd terraform && terraform init

# Planification changements
terraform plan

# Application infrastructure
terraform apply

# Destruction (attention!)
terraform destroy
```

## 🐳 Architecture Docker

### **Services Structure**
```
docker-compose.yml
├── 🌐 gateway (3000)         # API Gateway
├── 🔐 auth-service (3001)    # Authentication
├── 👤 user-service (3002)    # User Management
├── ✈️ voyage-service (3003)   # Travel & Booking
├── 💳 payment-service (3004)  # Payment Processing
├── 🤖 ai-service (3005)      # AI Recommendations
├── 🌅 panorama-service (3006) # VR/Panorama
├── 🗄️ mongodb (27017)        # Primary Database
├── 📊 redis (6379)           # Cache & Sessions
├── 🔍 prometheus (9090)      # Metrics Collection
└── 📈 grafana (3001)         # Monitoring Dashboard
```

### **Network Architecture**
```
┌─────────────────────────────────────────────────────────┐
│                    Docker Network                        │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   Gateway   │────│   Services  │────│ Databases   │  │
│  │    (3000)   │    │ (3001-3006) │    │ (MongoDB)   │  │
│  └─────────────┘    └─────────────┘    └─────────────┘  │
│         │                   │                   │        │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │ Monitoring  │    │    Cache    │    │   Logs      │  │
│  │(Prometheus) │    │   (Redis)   │    │   (ELK)     │  │
│  └─────────────┘    └─────────────┘    └─────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## ☸️ Kubernetes Deployment

### **Namespace Organization**
```bash
# Namespaces
kubectl create namespace dreamscape-dev
kubectl create namespace dreamscape-staging  
kubectl create namespace dreamscape-prod
```

### **Resource Structure**
```
k8s/
├── base/                    # Base configurations
│   ├── auth/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── hpa.yaml        # Horizontal Pod Autoscaler
│   ├── common/
│   │   ├── cert-issuer.yaml
│   │   └── networkpolicy.yaml
│   └── [other-services]/
├── overlays/               # Environment-specific
│   ├── dev/
│   │   └── kustomization.yaml
│   ├── staging/
│   │   └── kustomization.yaml
│   └── prod/
│       └── kustomization.yaml
└── monitoring/
    ├── prometheus/
    └── grafana/
```

### **Deployment Commands**
```bash
# Deploy specific environment
kubectl apply -k k8s/overlays/dev
kubectl apply -k k8s/overlays/staging
kubectl apply -k k8s/overlays/prod

# Rolling updates
kubectl rollout restart deployment/auth-service -n dreamscape

# Scaling
kubectl scale deployment auth-service --replicas=3 -n dreamscape
```

## 🏗️ Terraform Infrastructure

### **Module Structure**
```
terraform/
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── modules/
│   ├── databases/
│   │   ├── main.tf
│   │   └── mongodb-init.sh
│   ├── k3s/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── networking/
│   └── security/
└── shared/
    └── variables.tf
```

### **Resource Provisioning**
```bash
# Variables d'environnement
export TF_VAR_environment="dev"
export TF_VAR_region="us-east-1"

# Workspace management
terraform workspace new dev
terraform workspace select dev

# Infrastructure deployment
terraform plan -var-file="environments/dev/terraform.tfvars"
terraform apply -var-file="environments/dev/terraform.tfvars"
```

## 📊 Monitoring Stack

### **Prometheus Configuration**
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'dreamscape-services'
    static_configs:
      - targets: 
        - 'auth-service:3001'
        - 'user-service:3002'
        - 'voyage-service:3003'
        - 'payment-service:3004'
        - 'ai-service:3005'
        - 'panorama-service:3006'
```

### **Grafana Dashboards**
- **Services Overview** - Performance globale
- **Database Metrics** - MongoDB & Redis stats
- **API Gateway** - Traffic & latency
- **Error Tracking** - Taux d'erreurs
- **Business Metrics** - KPIs métier

### **Alerting Rules**
```yaml
groups:
  - name: dreamscape-alerts
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
```

## 🚀 CI/CD Pipeline

### **GitHub Actions Workflow**
```yaml
# .github/workflows/deploy.yml
name: Deploy DreamScape
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: npm run test
      
  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - name: Build images
        run: docker build -t dreamscape:${{ github.sha }} .
        
  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to K8s
        run: kubectl apply -k k8s/overlays/prod
```

### **Deployment Strategies**
- **Blue-Green** - Zero downtime deployments
- **Canary** - Gradual rollout
- **Rolling Updates** - Progressive updates
- **Rollback** - Automatic rollback on failure

## 🔐 Security & Compliance

### **Security Measures**
- **Network Policies** - Segmentation réseau K8s
- **RBAC** - Role-based access control
- **Secrets Management** - Sealed secrets / Vault
- **Image Scanning** - Vulnerability detection
- **TLS/HTTPS** - Encryption in transit

### **Compliance Tools**
```bash
# Security scanning
docker scan dreamscape:latest

# K8s security audit
kubectl-bench run

# Infrastructure compliance
terraform-compliance -f compliance/ -p terraform/
```

## 📈 Performance Optimization

### **Resource Allocation**
```yaml
# Resource limits example
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi
```

### **Horizontal Pod Autoscaler**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: auth-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: auth-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## 🛠️ Scripts d'Automation

### **Deployment Scripts**
```bash
# scripts/deploy-services.sh
#!/bin/bash
set -e

echo "🚀 Deploying DreamScape services..."

# Build images
docker-compose build

# Deploy to K8s
kubectl apply -k k8s/overlays/${ENVIRONMENT:-dev}

# Wait for rollout
kubectl rollout status deployment/gateway -n dreamscape

echo "✅ Deployment completed!"
```

### **Health Check Scripts**
```bash
# scripts/health-check.sh
#!/bin/bash
services=("gateway:3000" "auth:3001" "user:3002")

for service in "${services[@]}"; do
  echo "Checking $service..."
  curl -f http://localhost:${service#*:}/health || exit 1
done

echo "✅ All services healthy!"
```

## 🤝 Contributing

### **Infrastructure Changes**
1. **Branch**: `infra/description`
2. **Terraform Plan**: Validate changes
3. **Testing**: Verify in dev environment
4. **Documentation**: Update README & docs
5. **Code Review**: Infrastructure team approval

### **Best Practices**
- **Infrastructure as Code** - Tout en version control
- **Environment Parity** - Dev/staging/prod identiques
- **Monitoring First** - Observabilité intégrée
- **Security by Default** - Sécurité dès conception
- **Documentation** - Architecture & runbooks

## 📄 License

Propriétaire et confidentiel © DreamScape 2025

