# 🚀 Guide de Démarrage - DreamScape Big Pods

## Démarrage en 5 Minutes

Ce guide vous accompagne dans la configuration et l'utilisation de la suite d'automatisation Big Pods de DreamScape.

## 📋 Prérequis

### Système
- **OS**: Linux/macOS/Windows (WSL2)
- **Bash**: Version 4.0+
- **Docker**: Version 20.0+
- **Docker Compose**: Version 2.0+
- **Node.js**: Version 18+ (pour développement)

### Outils Recommandés
```bash
# Vérifier les prérequis
docker --version          # Docker 20.0+
docker-compose --version  # v2.0+
node --version            # v18+
git --version             # v2.0+
```

### Outils Optionnels (pour fonctionnalités avancées)
```bash
# Pour load testing
sudo apt-get install apache2-utils  # ab (Apache Bench)

# Pour configuration YAML
sudo apt-get install jq              # JSON processing

# Pour AWS S3 (backups)
pip install awscli                   # AWS CLI
```

## 🛠️ Installation

### 1. Structure des Repositories
DreamScape utilise une architecture 6 repositories → 3 Big Pods :

```
DREAMSCAPE-SERVICES/          # Racine du projet
├── dreamscape-services/      # Backend microservices
├── dreamscape-frontend/      # Applications frontend
├── dreamscape-tests/         # Tests centralisés
├── dreamscape-infra/         # Infrastructure & DevOps ← VOUS ÊTES ICI
├── dreamscape-docs/          # Documentation
└── .dreamscape.config.yml    # Configuration Big Pods
```

### 2. Vérification Installation
```bash
cd dreamscape-infra/scripts/bigpods

# Vérifier que tous les scripts sont exécutables
ls -la *.sh

# Test de base
./build-bigpods.sh --help
./dev-bigpods.sh --help
```

### 3. Configuration Initiale
```bash
# Le fichier .dreamscape.config.yml est déjà configuré
# Vous pouvez l'adapter selon vos besoins
cat ../../.dreamscape.config.yml
```

## 🏃‍♂️ Premier Lancement

### Étape 1: Setup Environnement
```bash
# Setup automatique des 6 repositories
./dev-bigpods.sh --setup-repos
```

Cette commande va :
- ✅ Vérifier la présence des repositories
- ✅ Installer les dépendances npm
- ✅ Configurer l'environnement de développement
- ✅ Créer les variables d'environnement

### Étape 2: Démarrage Développement
```bash
# Démarrer l'environnement complet
./dev-bigpods.sh
```

**Ce qui se lance automatiquement :**
- 🗄️ Bases de données (MongoDB, Redis, PostgreSQL)
- 🔐 Core Pod (Auth + User services)
- 💼 Business Pod (Voyage + Payment + AI services)
- 🎨 Experience Pod (Panorama + Web Client + Gateway)
- 🔥 Hot reload pour tous les services

### Étape 3: Vérification
```bash
# Vérifier que tout fonctionne
./monitoring-bigpods.sh --mode health
```

Vous devriez voir :
```
🏗️ core Pod
✅ auth: Healthy
✅ user: Healthy

🏗️ business Pod
✅ voyage: Healthy
✅ payment: Healthy
✅ ai: Healthy

🏗️ experience Pod
✅ panorama: Healthy
✅ web-client: Healthy
✅ gateway: Healthy
```

## 🌐 Accès aux Services

Une fois l'environnement lancé, vous pouvez accéder aux services :

### URLs de Développement
```bash
# Core Pod
http://localhost:3001/health    # Auth Service
http://localhost:3002/health    # User Service

# Business Pod
http://localhost:3003/health    # Voyage Service
http://localhost:3004/health    # Payment Service
http://localhost:3005/health    # AI Service

# Experience Pod
http://localhost:3006/health    # Panorama Service
http://localhost:5173          # Web Client (Vite dev server)
http://localhost:3000/health    # Gateway

# NGINX Reverse Proxy (Core Pod)
http://localhost:80             # Gateway unifié
```

### APIs principales
```bash
# Authentication
curl http://localhost:3001/api/v1/auth/status

# User Management
curl http://localhost:3002/api/v1/users/status

# Booking Services
curl http://localhost:3003/api/v1/voyage/status
```

## 🔧 Flux de Travail Développement

### 1. Développement Local Standard
```bash
# Démarrer environnement complet
./dev-bigpods.sh

# Dans un autre terminal - monitoring
./monitoring-bigpods.sh

# Développer dans les repositories spécialisés
cd ../../../dreamscape-services/auth
# Modifier le code - hot reload automatique
```

### 2. Développement Pod Spécifique
```bash
# Travailler seulement sur Core Pod
./dev-bigpods.sh --pod core

# Avec configuration spéciale
./dev-bigpods.sh --pod business --no-auto-restart --log-level debug
```

### 3. Build et Test
```bash
# Build intelligent (seulement ce qui a changé)
./build-bigpods.sh --smart

# Tests automatiques
./tests/run_all_tests.sh

# Si problèmes - debug interactif
./debug-bigpods.sh core
```

## 🧪 Workflow de Test

### Tests Locaux
```bash
# Tests complets
./tests/run_all_tests.sh --verbose

# Tests sans Docker (plus rapide)
./tests/run_all_tests.sh --skip-docker

# Tests spécifiques
./tests/test_common.sh        # Bibliothèque commune
./tests/test_scripts.sh       # Intégration scripts
```

### Tests de Performance
```bash
# Load testing avec scaling
./scale-bigpods.sh --load-test core --load-users 50 --load-duration 300

# Tests performance startup
./tests/run_all_tests.sh --parallel
```

## 🏭 Préparation Production

### 1. Build Production
```bash
# Build complet avec version
./build-bigpods.sh --all --version v1.0.0 --push

# Vérification build
./debug-bigpods.sh --mode health
```

### 2. Tests Intégration
```bash
# Tests E2E complets
cd ../../../dreamscape-tests
npm run test:e2e

# Retour aux scripts Big Pods
cd ../dreamscape-infra/scripts/bigpods
./tests/run_all_tests.sh --parallel
```

### 3. Déploiement Staging
```bash
# Déploiement staging sécurisé
./deploy-bigpods.sh --env staging --version v1.0.0

# Validation staging
./monitoring-bigpods.sh --mode health
```

## 🚨 Dépannage Rapide

### Problème: Services ne démarrent pas
```bash
# Debug santé système
./debug-bigpods.sh --mode health

# Vérifier Docker
docker ps
docker logs core-pod

# Redémarrage propre
./dev-bigpods.sh --force-restart
```

### Problème: Build échoue
```bash
# Build avec debug complet
./build-bigpods.sh --smart --verbose --debug

# Nettoyage et rebuild
./maintenance-bigpods.sh --mode cleanup
./build-bigpods.sh --all --no-cache
```

### Problème: Performance dégradée
```bash
# Monitoring détaillé
./monitoring-bigpods.sh --mode performance

# Scaling automatique
./scale-bigpods.sh --mode auto core --cpu-target 60

# Nettoyage maintenance
./maintenance-bigpods.sh --mode full
```

### Problème: Logs illisibles
```bash
# Logs filtrés par niveau
./logs-bigpods.sh --level error --pod core

# Recherche dans logs
./logs-bigpods.sh --search "connection refused" --since 1h

# Export pour analyse externe
./logs-bigpods.sh --export json --output /tmp/debug-logs.json
```

## 🎯 Cas d'Usage Fréquents

### Nouveau Développeur sur le Projet
```bash
# Setup complet en une commande
./dev-bigpods.sh --setup-repos

# Vérification environnement
./monitoring-bigpods.sh --mode health

# Documentation interactive
./debug-bigpods.sh --help
```

### Debugging Issue Production
```bash
# Collecte debug complète
./debug-bigpods.sh core --export --output /tmp/prod-debug

# Analyse logs récents
./logs-bigpods.sh --search "error" --since 24h --export json

# Métriques détaillées
./monitoring-bigpods.sh --mode metrics --duration 3600
```

### Mise à Jour Architecture
```bash
# Build smart après modifications
./build-bigpods.sh --smart --parallel

# Tests intégration
./tests/run_all_tests.sh --verbose

# Déploiement progressif
./deploy-bigpods.sh --env staging --rolling
```

### Scaling pour Pic de Charge
```bash
# Auto-scaling préventif
./scale-bigpods.sh --mode auto --cpu-target 70 --max-replicas 10

# Load testing validation
./scale-bigpods.sh --load-test --load-users 200

# Monitoring temps réel
./monitoring-bigpods.sh --mode alerts --continuous
```

## ⚡ Optimisations Performance

### Configuration Développement Optimisée
```bash
# Mode performance pour machine puissante
./dev-bigpods.sh --parallel-startup --no-health-checks

# Mode économe pour machine limitée
./dev-bigpods.sh --pod core --no-auto-restart
```

### Build Optimisé
```bash
# Cache Docker optimisé
./build-bigpods.sh --smart --parallel

# Build sans tests pour vitesse
./build-bigpods.sh --smart --skip-tests
```

## 🔄 Intégration CI/CD

### GitHub Actions
```bash
# Les workflows seront dans .github/workflows/
# Exemple d'intégration :

name: Big Pods CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Big Pods Tests
        run: |
          cd dreamscape-infra/scripts/bigpods
          ./tests/run_all_tests.sh --skip-docker --parallel
```

## 📚 Ressources Supplémentaires

### Documentation Avancée
- 📖 `docs/README.md` - Documentation complète
- 🏗️ `docs/ARCHITECTURE.md` - Architecture Big Pods détaillée
- 🔧 `docs/CONFIGURATION.md` - Configuration avancée
- 🚀 `docs/DEPLOYMENT.md` - Guide déploiement production

### Exemples Pratiques
- 💡 `docs/examples/` - Cas d'usage réels
- 🧪 `tests/` - Tests comme exemples
- 📊 `docs/monitoring/` - Dashboards Grafana

### Support Communauté
- 🐛 Issues GitHub pour bugs
- 💬 Discussions pour questions
- 📝 Wiki pour guides contributeurs

---

**🎉 Félicitations ! Vous êtes prêt à développer avec l'architecture Big Pods de DreamScape !**

**Prochaine étape :** Consultez le [README complet](README.md) pour explorer toutes les fonctionnalités avancées.