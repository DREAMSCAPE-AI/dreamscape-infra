# 📚 Exemples Pratiques - DreamScape Big Pods

Cette documentation présente des exemples concrets d'utilisation des scripts Big Pods pour différents scénarios de développement et de production.

## 📖 Table des Matières

1. [🏃‍♂️ Démarrage Rapide](#démarrage-rapide)
2. [💻 Développement Local](#développement-local)
3. [🏗️ Build et Intégration](#build-et-intégration)
4. [🚀 Déploiement Production](#déploiement-production)
5. [🔍 Debug et Monitoring](#debug-et-monitoring)
6. [📊 Scaling et Performance](#scaling-et-performance)
7. [🛠️ Maintenance et Backup](#maintenance-et-backup)
8. [🧪 Tests et Validation](#tests-et-validation)

---

## 🏃‍♂️ Démarrage Rapide

### Scenario: Nouveau développeur rejoint l'équipe

**Objectif:** Setup complet environnement en moins de 10 minutes

```bash
# 1. Vérification prérequis
./dev-bigpods.sh --check-prerequisites

# 2. Setup automatique tous repositories
./dev-bigpods.sh --setup-repos --verbose

# 3. Démarrage environnement complet
./dev-bigpods.sh --all --hot-reload

# 4. Vérification santé
./monitoring-bigpods.sh --mode health

# 5. Accès aux services
echo "✅ Environnement prêt!"
echo "🌐 Web Client: http://localhost:5173"
echo "🔐 Auth API: http://localhost:3001"
echo "📊 Monitoring: ./monitoring-bigpods.sh"
```

**Résultat attendu:**
- ✅ 6 repositories clonés et configurés
- ✅ Bases de données démarrées (MongoDB, Redis, PostgreSQL)
- ✅ 3 Big Pods opérationnels avec hot reload
- ✅ Health checks passent à 100%

---

## 💻 Développement Local

### Scenario 1: Développement Feature Authentication

**Contexte:** Développer nouvelle fonctionnalité dans le service Auth (Core Pod)

```bash
# 1. Démarrage environnement Core Pod uniquement
./dev-bigpods.sh --pod core --debug --verbose

# 2. Monitoring spécialisé
./monitoring-bigpods.sh --pod core --continuous &

# 3. Logs en temps réel avec filtrage
./logs-bigpods.sh --pod core --follow --level debug

# 4. Tests automatiques pendant développement
watch -n 30 './tests/test_common.sh --verbose'
```

**Développement dans le repository:**
```bash
cd ../../../dreamscape-services/auth

# Modifier le code - hot reload automatique
# Les changements sont détectés instantanément

# Test API en direct
curl -X POST http://localhost:3001/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'
```

### Scenario 2: Développement Feature Full-Stack

**Contexte:** Nouvelle fonctionnalité impactant tous les pods

```bash
# 1. Environnement complet avec configuration optimisée
./dev-bigpods.sh --all --hot-reload --auto-restart

# 2. Build smart pour vérifier intégration
./build-bigpods.sh --smart --parallel

# 3. Tests intégration continue
./tests/run_all_tests.sh --parallel --verbose &

# 4. Monitoring dashboard temps réel
./monitoring-bigpods.sh --mode dashboard
```

**Workflow multi-repositories:**
```bash
# Terminal 1: Backend (Core Pod)
cd ../../../dreamscape-services/auth
# Développement service auth

# Terminal 2: Backend (Business Pod)
cd ../../../dreamscape-services/voyage
# Développement service voyage

# Terminal 3: Frontend
cd ../../../dreamscape-frontend/web-client
# Développement interface

# Terminal 4: Monitoring Big Pods
cd ../../../dreamscape-infra/scripts/bigpods
./monitoring-bigpods.sh --mode dashboard
```

---

## 🏗️ Build et Intégration

### Scenario 1: Build Optimisé Pre-Commit

**Contexte:** Vérification avant commit avec build intelligent

```bash
# 1. Détection changements et build smart
./build-bigpods.sh --smart --verbose

# Output attendu:
# 🔍 Detecting changes...
# ✅ Changes detected in dreamscape-services (auth, user)
# 🔨 Building core pod only
# ✅ Core pod built successfully

# 2. Tests impactés seulement
./tests/test_scripts.sh --pod core

# 3. Vérification santé après build
./debug-bigpods.sh core --mode health
```

### Scenario 2: Build Release Production

**Contexte:** Préparation release v2.1.0

```bash
# 1. Build complet avec version et push
./build-bigpods.sh --all --version v2.1.0 --push --no-cache

# Output détaillé:
# 🔨 Building all Big Pods for release v2.1.0
# 🏗️ core pod: Building...
# ✅ core pod: Built (2m30s)
# 🏗️ business pod: Building...
# ✅ business pod: Built (3m15s)
# 🏗️ experience pod: Building...
# ✅ experience pod: Built (1m45s)
# 📤 Pushing images to registry...
# ✅ All images pushed successfully

# 2. Tests complets
./tests/run_all_tests.sh --parallel --coverage

# 3. Backup avant déploiement
./backup-bigpods.sh --type configs --s3-bucket dreamscape-releases
```

### Scenario 3: Build CI/CD Pipeline

**Contexte:** Intégration continue avec validation automatique

```bash
#!/bin/bash
# Script CI/CD automatisé

# 1. Setup environnement CI
export CI=true
export DOCKER_BUILDKIT=1

# 2. Tests sans Docker (plus rapide en CI)
./tests/run_all_tests.sh --skip-docker --parallel

# 3. Build avec cache CI optimisé
./build-bigpods.sh --smart --parallel --cache-from dreamscape/base:latest

# 4. Tests intégration avec images buildées
./debug-bigpods.sh --mode connectivity

# 5. Déploiement automatique si tests passent
if [ $? -eq 0 ]; then
    ./deploy-bigpods.sh --env staging --version ${CI_COMMIT_SHA}
fi
```

---

## 🚀 Déploiement Production

### Scenario 1: Déploiement Blue-Green Sécurisé

**Contexte:** Mise en production sans interruption de service

```bash
# 1. Préparation déploiement
./deploy-bigpods.sh --env production --version v2.1.0 --blue-green --dry-run

# 2. Déploiement réel avec notifications
./deploy-bigpods.sh --env production --version v2.1.0 --blue-green \
  --slack-webhook https://hooks.slack.com/services/... \
  --notify

# Output déploiement:
# 🔵 Deploying to blue environment...
# ✅ Blue deployment healthy
# 🔄 Switching traffic to blue...
# ✅ Traffic switched successfully
# 🟢 Green environment scaled down
# 📱 Notification sent to Slack

# 3. Validation post-déploiement
./monitoring-bigpods.sh --mode health --env production

# 4. Tests fumée production
curl -f https://api.dreamscape.com/health
```

### Scenario 2: Déploiement Canary Progressif

**Contexte:** Déploiement progressif avec validation métriques

```bash
# 1. Déploiement canary 10%
./deploy-bigpods.sh --env production --version v2.1.0 --canary \
  --canary-percent 10

# 2. Monitoring canary 15 minutes
./monitoring-bigpods.sh --mode alerts --duration 900 \
  --cpu-threshold 70 --memory-threshold 80

# 3. Si métriques OK - expansion 50%
./deploy-bigpods.sh --env production --version v2.1.0 --canary \
  --canary-percent 50

# 4. Promotion finale 100%
./deploy-bigpods.sh --env production --version v2.1.0 --rolling
```

### Scenario 3: Rollback d'Urgence

**Contexte:** Problème critique détecté en production

```bash
# 1. Détection automatique problème
./monitoring-bigpods.sh --mode alerts --env production

# Output alerte:
# 🚨 HIGH ERROR RATE: 15% (threshold: 5%)
# 🚨 HIGH LATENCY: 2.5s (threshold: 1s)

# 2. Rollback immédiat
./deploy-bigpods.sh --env production --rollback --force

# 3. Vérification rollback
./monitoring-bigpods.sh --mode health --env production

# 4. Investigation post-mortem
./logs-bigpods.sh --export json --since 2h --level error \
  --output /tmp/incident-logs.json

./debug-bigpods.sh --export --output /tmp/incident-debug
```

---

## 🔍 Debug et Monitoring

### Scenario 1: Investigation Performance

**Contexte:** Latence élevée détectée sur Business Pod

```bash
# 1. Debug session interactive
./debug-bigpods.sh business

# 2. Métriques détaillées temps réel
./monitoring-bigpods.sh --pod business --mode performance

# 3. Analyse logs avec patterns
./logs-bigpods.sh --pod business --search "timeout\|slow\|error" \
  --since 1h --export json

# 4. Tests connectivité inter-pods
./debug-bigpods.sh --mode connectivity business

# 5. Profiling mémoire/CPU
./monitoring-bigpods.sh --pod business --mode metrics --duration 1800
```

### Scenario 2: Debug Issue Intermittent

**Contexte:** Erreur qui apparaît de façon aléatoire

```bash
# 1. Monitoring continu avec seuils bas
./monitoring-bigpods.sh --mode alerts --continuous \
  --cpu-threshold 60 --memory-threshold 70

# 2. Capture logs étendue
./logs-bigpods.sh --follow --aggregate --export text \
  --output /tmp/debug-session.log &

# 3. Tests charge pour reproduire
./scale-bigpods.sh --load-test experience \
  --load-users 100 --load-duration 1800

# 4. Analyse corrélation métriques/logs
./monitoring-bigpods.sh --export prometheus \
  --output /tmp/metrics.prom

# 5. Debug export complet quand problème détecté
./debug-bigpods.sh --export --output /tmp/issue-debug-$(date +%s)
```

### Scenario 3: Monitoring Production 24/7

**Contexte:** Setup monitoring permanent avec alertes

```bash
# 1. Dashboard monitoring permanent
./monitoring-bigpods.sh --mode dashboard --continuous &

# 2. Alertes avec webhooks
./monitoring-bigpods.sh --mode alerts --continuous \
  --webhook https://hooks.slack.com/services/... &

# 3. Collection métriques historiques
./monitoring-bigpods.sh --mode metrics --duration 86400 \
  --export prometheus --output /var/log/dreamscape/metrics/ &

# 4. Health checks automatiques
watch -n 60 './monitoring-bigpods.sh --mode health'
```

---

## 📊 Scaling et Performance

### Scenario 1: Auto-Scaling Intelligent

**Contexte:** Configuration auto-scaling pour pic de charge

```bash
# 1. Configuration auto-scaling Core Pod
./scale-bigpods.sh --mode auto core \
  --cpu-target 70 \
  --memory-target 80 \
  --min-replicas 2 \
  --max-replicas 10 \
  --cooldown 300

# 2. Monitoring scaling en temps réel
./monitoring-bigpods.sh --pod core --mode dashboard &

# 3. Load testing validation
./scale-bigpods.sh --load-test core \
  --load-users 200 \
  --load-duration 1800

# 4. Analyse résultats
./logs-bigpods.sh --pod core --mode stats --since 30m
```

### Scenario 2: Optimisation Performance

**Contexte:** Amélioration performance suite à load testing

```bash
# 1. Baseline performance actuelle
./scale-bigpods.sh --mode optimize --load-test

# Output analyse:
# 📊 Performance Analysis Results:
# • core pod: 2 replicas (CPU: 45%, Memory: 60%) → Optimal
# • business pod: 3 replicas (CPU: 85%, Memory: 90%) → Increase recommended
# • experience pod: 1 replica (CPU: 30%, Memory: 25%) → Consider reducing

# 2. Application recommandations
./scale-bigpods.sh business 5  # Scaling business pod

# 3. Tests validation
./scale-bigpods.sh --load-test --load-users 300

# 4. Monitoring performance améliorée
./monitoring-bigpods.sh --mode performance --duration 3600
```

### Scenario 3: Scaling Événement Spécial

**Contexte:** Préparation pic de charge pour lancement produit

```bash
# 1. Scaling préventif tous pods
./scale-bigpods.sh core 8
./scale-bigpods.sh business 12
./scale-bigpods.sh experience 6

# 2. Monitoring intensif
./monitoring-bigpods.sh --mode alerts --continuous \
  --cpu-threshold 80 --memory-threshold 85 &

# 3. Load testing capacité maximale
./scale-bigpods.sh --load-test \
  --load-users 1000 \
  --load-duration 3600

# 4. Auto-scaling backup si nécessaire
./scale-bigpods.sh --mode auto --max-replicas 20
```

---

## 🛠️ Maintenance et Backup

### Scenario 1: Maintenance Programmée Nocturne

**Contexte:** Maintenance automatique chaque nuit à 2h

```bash
#!/bin/bash
# Cron job: 0 2 * * * /path/to/maintenance-script.sh

# 1. Backup complet avant maintenance
./backup-bigpods.sh --type full --s3-bucket dreamscape-backups \
  --retention 30

# 2. Maintenance complète programmée
./maintenance-bigpods.sh --scheduled --mode full \
  --maintenance-start "02:00" --maintenance-end "04:00" \
  --notify

# 3. Vérification post-maintenance
./monitoring-bigpods.sh --mode health

# 4. Rapport maintenance
./maintenance-bigpods.sh --generate-report \
  --output /var/log/dreamscape/maintenance/
```

### Scenario 2: Backup Critique Avant Déploiement

**Contexte:** Sauvegarde complète avant mise en production majeure

```bash
# 1. Backup complet avec validation
./backup-bigpods.sh --type full \
  --s3-bucket dreamscape-critical-backups \
  --compression 9 \
  --encryption \
  --verification

# 2. Backup incrémental bases de données
./backup-bigpods.sh --type databases \
  --parallel \
  --s3-bucket dreamscape-db-backups

# 3. Export configuration Big Pods
./backup-bigpods.sh --type configs \
  --destination /tmp/config-backup-$(date +%Y%m%d)

# 4. Vérification intégrité backups
./debug-bigpods.sh --mode health --backup-validation
```

### Scenario 3: Nettoyage Urgente Espace Disque

**Contexte:** Espace disque critique (>90% utilisé)

```bash
# 1. Analyse utilisation espace
./monitoring-bigpods.sh --mode system

# 2. Nettoyage agressif immédiat
./maintenance-bigpods.sh --mode cleanup \
  --cleanup-volumes \
  --log-retention 1 \
  --disk-threshold 85

# 3. Nettoyage Docker approfondi
./maintenance-bigpods.sh --mode images \
  --no-backup  # Urgence - skip backup

# 4. Monitoring espace libéré
df -h
./monitoring-bigpods.sh --mode system
```

---

## 🧪 Tests et Validation

### Scenario 1: Tests Intégration Continue

**Contexte:** Pipeline CI/CD avec tests automatisés

```bash
#!/bin/bash
# Pipeline CI/CD automatisé

# 1. Tests parallèles rapides
./tests/run_all_tests.sh --skip-docker --parallel

# 2. Si tests unitaires OK - tests intégration
if [ $? -eq 0 ]; then
    ./tests/run_all_tests.sh --verbose
fi

# 3. Build et tests avec images
./build-bigpods.sh --smart --parallel
./debug-bigpods.sh --mode connectivity

# 4. Tests performance
./scale-bigpods.sh --load-test --load-users 50

# 5. Rapport final
./tests/run_all_tests.sh --generate-report \
  --output /tmp/ci-report.html
```

### Scenario 2: Tests de Régression

**Contexte:** Validation avant release majeure

```bash
# 1. Tests complets avec couverture
./tests/run_all_tests.sh --parallel --coverage

# 2. Tests charge sur tous pods
for pod in core business experience; do
    ./scale-bigpods.sh --load-test $pod \
      --load-users 100 --load-duration 600 &
done
wait

# 3. Tests de récupération
./deploy-bigpods.sh --env staging --version v2.1.0
./monitoring-bigpods.sh --mode health
./deploy-bigpods.sh --env staging --rollback

# 4. Tests sécurité
./tests/run_all_tests.sh --security
```

### Scenario 3: Tests Avant Mise en Production

**Contexte:** Validation finale environnement staging

```bash
# 1. Tests santé complets
./monitoring-bigpods.sh --mode health --env staging

# 2. Tests charge réaliste
./scale-bigpods.sh --load-test \
  --load-users 500 \
  --load-duration 1800

# 3. Tests APIs critiques
curl -f https://staging.dreamscape.com/api/v1/auth/health
curl -f https://staging.dreamscape.com/api/v1/voyage/health
curl -f https://staging.dreamscape.com/api/v1/payment/health

# 4. Tests de failover
./deploy-bigpods.sh --env staging --blue-green --test-mode

# 5. Validation finale
./tests/run_all_tests.sh --integration --env staging
```

---

## 🎯 Cas d'Usage Avancés

### Monitoring Multi-Environnements

```bash
# Terminal 1: Production
./monitoring-bigpods.sh --env production --mode alerts --continuous

# Terminal 2: Staging
./monitoring-bigpods.sh --env staging --mode dashboard

# Terminal 3: Développement
./monitoring-bigpods.sh --env local --mode performance
```

### Déploiement Multi-Régions

```bash
# Région US-East
./deploy-bigpods.sh --env production --region us-east-1 --version v2.1.0

# Région EU-West
./deploy-bigpods.sh --env production --region eu-west-1 --version v2.1.0

# Validation cross-region
./monitoring-bigpods.sh --multi-region --mode health
```

### Debug Performance Avancé

```bash
# 1. Profiling mémoire en temps réel
./debug-bigpods.sh core --mode profiling --duration 3600

# 2. Analyse réseau inter-pods
./debug-bigpods.sh --mode network --trace-requests

# 3. Export métriques pour Grafana
./monitoring-bigpods.sh --export grafana \
  --output /tmp/grafana-dashboard.json
```

---

**🎉 Ces exemples couvrent 90% des cas d'usage réels de la suite Big Pods !**

Pour des scénarios spécifiques non couverts, consultez la [documentation complète](README.md) ou créez une issue GitHub.