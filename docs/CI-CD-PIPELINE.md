# 🚀 Pipeline CI/CD DreamScape

## 📋 Vue d'ensemble

Le pipeline CI/CD de DreamScape automatise les tests, le build et le déploiement de l'ensemble de l'écosystème sur Oracle Cloud Infrastructure (OCI).

## 🏗️ Architecture du Pipeline

### Workflows GitHub Actions

| Workflow | Déclencheur | Description |
|----------|-------------|-------------|
| **ci.yml** | Push, PR | Tests unitaires, linting, build |
| **deploy.yml** | Push main, Tags | Déploiement vers OCI |
| **core-pod-integration.yml** | Push, PR, Cron | Tests d'intégration Core Pod |
| **test.yml** | Manuel | Test de connexion SSH |

## 🔄 Flux CI/CD

```mermaid
graph LR
    A[Code Push] --> B[CI Pipeline]
    B --> C{Tests OK?}
    C -->|✅| D[Build Images]
    C -->|❌| E[Échec]
    D --> F[Deploy Staging]
    F --> G{Health Check}
    G -->|✅| H[Prêt pour Prod]
    G -->|❌| I[Rollback]
    H --> J[Deploy Production]
```

## 📦 Composants du Système

### Services Backend
- **auth-service** (Port 8001) - Authentification
- **user-service** (Port 8002) - Gestion utilisateurs
- **voyage-service** (Port 8003) - Gestion des voyages
- **payment-service** (Port 8004) - Paiements
- **ai-service** (Port 8005) - Intelligence artificielle

### Frontend
- **web-client** (Port 3000) - Application React
- **gateway** (Port 8080) - API Gateway NGINX
- **panorama** (Port 3001) - Service VR/Panorama

## 🧪 Pipeline CI (ci.yml)

### Étapes du Pipeline CI

1. **Setup & Validation**
   ```yaml
   - Détection des changements (services/frontend/tests/infra)
   - Validation de la structure du workspace
   - Configuration Node.js
   ```

2. **Linting & Code Quality**
   ```yaml
   - ESLint pour la qualité du code
   - Prettier pour le formatage
   - TypeScript type checking
   ```

3. **Tests Unitaires**
   ```yaml
   - Tests par composant (services/frontend/tests)
   - Génération de rapports de couverture
   - Upload des artefacts
   ```

4. **Build des Composants**
   ```yaml
   - Build des services Node.js
   - Build des applications frontend
   - Upload des artefacts de build
   ```

5. **Tests d'Intégration**
   ```yaml
   - MongoDB et Redis via services GitHub
   - Tests d'intégration complets
   - Rapports de test détaillés
   ```

6. **Security Scan**
   ```yaml
   - Trivy vulnerability scanner
   - npm audit pour les dépendances
   - Upload SARIF vers GitHub Security
   ```

### Configuration CI

```yaml
env:
  NODE_VERSION: '20'
  ORG: DREAMSCAPE-AI

permissions:
  contents: read
  pull-requests: write
  checks: write
  security-events: write
```

## 🚀 Pipeline CD (deploy.yml)

### Environnements

| Environnement | Déclencheur | Infrastructure |
|---------------|-------------|----------------|
| **Development** | Feature branches | VM OCI Dev |
| **Staging** | Push main | VM OCI Staging |
| **Production** | Tags v* | VM OCI Production |

### Infrastructure Oracle Cloud

```yaml
# Configuration par environnement
Development:
  VM_HOST: 144.24.196.120
  Resources: Standard (2 vCPU, 4GB RAM)

Staging:
  VM_HOST: 79.72.27.180
  Resources: Enhanced (4 vCPU, 8GB RAM)

Production:
  VM_HOST: 84.235.237.183
  Resources: High Performance (8 vCPU, 16GB RAM)
```

### Stratégie de Déploiement

1. **Blue-Green Deployment**
   - Déploiement parallèle
   - Bascule atomique
   - Rollback instantané

2. **Container Management**
   ```bash
   # Images Docker
   - ghcr.io/dreamscape-ai/auth-service
   - ghcr.io/dreamscape-ai/user-service
   - ghcr.io/dreamscape-ai/voyage-service
   - ghcr.io/dreamscape-ai/payment-service
   - ghcr.io/dreamscape-ai/ai-service
   - ghcr.io/dreamscape-ai/web-client
   - ghcr.io/dreamscape-ai/gateway
   - ghcr.io/dreamscape-ai/panorama
   ```

## 🔒 Secrets et Configuration

### Secrets GitHub Requis

```yaml
# SSH Configuration
SSH_PRIVATE_KEY_DEV: "Private key for dev environment"
SSH_PRIVATE_KEY_STAGING: "Private key for staging environment"
SSH_PRIVATE_KEY_PRODUCTION: "Private key for production environment"

# VM Hosts
VM_HOST_DEV: "144.24.196.120"
VM_HOST_STAGING: "79.72.27.180"
VM_HOST_PRODUCTION: "84.235.237.183"

# Oracle Cloud (pour le futur déploiement OCI Container Instances)
OCI_CLI_USER: "ocid1.user.oc1....."
OCI_CLI_TENANCY: "ocid1.tenancy.oc1....."
OCI_CLI_FINGERPRINT: "xx:xx:xx:..."
OCI_CLI_KEY_CONTENT: "-----BEGIN PRIVATE KEY-----"
OCI_CLI_REGION: "eu-frankfurt-1"
OCI_COMPARTMENT_ID: "ocid1.compartment.oc1....."
OCI_SUBNET_ID: "ocid1.subnet.oc1....."

# Container Registry
GITHUB_TOKEN: "Auto-generated"
```

## 🧪 Tests d'Intégration (core-pod-integration.yml)

### Suites de Tests

1. **Health & Connectivity Tests**
   - Vérification des endpoints de santé
   - Tests de connectivité inter-services
   - Validation de la configuration réseau

2. **User Flow Tests**
   - Parcours utilisateur complets
   - Tests E2E avec authentification
   - Validation des workflows métier

3. **API Integration Tests**
   - Tests des contrats d'API
   - Validation des réponses et erreurs
   - Tests de charge légers

4. **Performance Tests**
   - Tests de latence
   - Tests de throughput
   - Monitoring des ressources

5. **Security Tests**
   - OWASP ZAP scanning
   - Tests d'authentification
   - Validation des autorisations

6. **Resilience Tests**
   - Tests de failover
   - Recovery time testing
   - Circuit breaker validation

### Configuration des Tests

```yaml
services:
  mongodb:
    image: mongo:7
    ports: [27017:27017]
  redis:
    image: redis:7
    ports: [6379:6379]

env:
  CORE_POD_BASE_URL: http://localhost:8080
  AUTH_SERVICE_URL: http://localhost:8001
  USER_SERVICE_URL: http://localhost:8002
  TEST_TIMEOUT: 60000
```

## 📊 Monitoring et Observabilité

### Métriques Collectées

- **Performance**: Temps de build, temps de déploiement
- **Qualité**: Couverture de code, violations de linting
- **Sécurité**: Vulnérabilités détectées, score de sécurité
- **Fiabilité**: Taux de succès des déploiements, MTTR

### Notifications

```yaml
# Canaux de notification
- GitHub PR Comments
- GitHub Actions Status
- Email (via GitHub notifications)
- Slack (configuration future)
```

## 🔧 Scripts de Déploiement

### Structure des Scripts

```
dreamscape-infra/scripts/
├── deploy-frontend.sh    # Déploiement frontend
├── deploy-backend.sh     # Déploiement backend
├── rollback.sh          # Script de rollback
├── health-check.sh      # Vérifications de santé
└── docker-cleanup.sh    # Nettoyage des conteneurs
```

### Exemple de Déploiement

```bash
# Déploiement frontend
./scripts/deploy-frontend.sh staging latest 79.72.27.180

# Déploiement backend
./scripts/deploy-backend.sh staging latest 79.72.27.180

# Rollback en cas de problème
./scripts/rollback.sh staging all 79.72.27.180
```

## 🛡️ Sécurité

### Bonnes Pratiques Implémentées

1. **Secrets Management**
   - Utilisation de GitHub Secrets
   - Rotation régulière des clés SSH
   - Chiffrement des communications

2. **Access Control**
   - Permissions minimales pour les workflows
   - Protection des branches principales
   - Review obligatoire des PRs

3. **Vulnerability Scanning**
   - Trivy pour les conteneurs
   - npm audit pour les dépendances
   - OWASP ZAP pour les applications web

4. **Compliance**
   - Logs d'audit des déploiements
   - Traçabilité des changements
   - Validation des signatures

## 🚨 Gestion des Incidents

### Procédures d'Urgence

1. **Échec de Déploiement**
   ```bash
   # Rollback automatique activé
   # Vérification: ./scripts/rollback.sh
   ```

2. **Problème de Performance**
   ```bash
   # Monitoring: Vérifier les métriques OCI
   # Action: Scale horizontal des services
   ```

3. **Problème de Sécurité**
   ```bash
   # Isolation: Arrêt immédiat des services affectés
   # Investigation: Analyse des logs et traces
   ```

### Contacts d'Urgence

- **DevOps Lead**: GitHub @kevcoutellier
- **Tech Lead**: À définir
- **Security Team**: À définir

## 📈 Métriques et KPIs

### Indicateurs de Performance

| Métrique | Objectif | Mesure Actuelle |
|----------|----------|-----------------|
| Build Time | < 10min | À mesurer |
| Deploy Time | < 5min | À mesurer |
| Test Coverage | > 80% | À mesurer |
| Success Rate | > 95% | À mesurer |

### Dashboards

1. **GitHub Actions Dashboard**
   - Status des workflows
   - Historique des builds
   - Métriques de performance

2. **Oracle Cloud Monitoring**
   - Ressources utilisées
   - Performance des VMs
   - Alertes système

## 🔮 Roadmap

### Améliorations Prévues

1. **Q1 2025**
   - Migration vers OCI Container Instances
   - Mise en place de Kubernetes
   - Monitoring avancé avec Prometheus

2. **Q2 2025**
   - GitOps avec ArgoCD
   - Canary deployments
   - Auto-scaling automatique

3. **Q3 2025**
   - Multi-region deployment
   - Disaster recovery automation
   - Advanced security scanning

## 📚 Documentation Technique

### Références

- [Architecture Overview](./ARCHITECTURE.md)
- [Deployment Scripts](./scripts/README.md)
- [Security Guidelines](./SECURITY.md)
- [Troubleshooting Guide](./TROUBLESHOOTING.md)

### Contacts

- **Repository**: [dreamscape-infra](https://github.com/DREAMSCAPE-AI/dreamscape-infra)
- **Issues**: [GitHub Issues](https://github.com/DREAMSCAPE-AI/dreamscape-infra/issues)
- **Discussions**: [GitHub Discussions](https://github.com/DREAMSCAPE-AI/dreamscape-infra/discussions)

---

*Dernière mise à jour: Septembre 2025*
*Version: 1.0.0*