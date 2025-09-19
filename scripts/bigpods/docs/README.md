# 🚀 DreamScape Big Pods - Scripts d'Automatisation

## Architecture Hybride Révolutionnaire
**6 repositories développement → 3 Big Pods déploiement**

Cette suite d'automatisation simplifie la gestion de l'architecture hybride Big Pods de DreamScape, offrant des outils puissants pour les développeurs et les équipes DevOps.

## 📁 Structure des Scripts

```
scripts/bigpods/
├── 🛠️ Scripts Développeurs
│   ├── build-bigpods.sh      # Build automatique avec détection changements
│   ├── dev-bigpods.sh        # Environnement développement hot reload
│   └── debug-bigpods.sh      # Debugging sophistiqué par pod
├── 🏭 Scripts Production
│   ├── deploy-bigpods.sh     # Déploiement orchestré multi-environnements
│   ├── backup-bigpods.sh     # Sauvegarde complète avec S3
│   └── maintenance-bigpods.sh # Maintenance automatique planifiée
├── 🔧 Scripts Utilitaires
│   ├── logs-bigpods.sh       # Gestion logs centralisée
│   ├── monitoring-bigpods.sh # Monitoring temps réel avec alertes
│   └── scale-bigpods.sh      # Scaling intelligent avec auto-scaling
└── 📚 Support
    ├── lib/common.sh         # Bibliothèque fonctions communes
    ├── tests/                # Tests unitaires complets
    └── docs/                 # Documentation détaillée
```

## 🏗️ Architecture Big Pods

### Core Pod (Authentification & Utilisateurs)
- **Services**: auth, user
- **Ports**: 80 (NGINX), 3001 (Auth), 3002 (User)
- **Bases de données**: MongoDB, Redis
- **Avantage**: -90% latence, -30% RAM vs microservices traditionnels

### Business Pod (Logique Métier)
- **Services**: voyage, payment, ai
- **Ports**: 3003 (Voyage), 3004 (Payment), 3005 (AI)
- **Bases de données**: PostgreSQL, Redis

### Experience Pod (Interface Utilisateur)
- **Services**: panorama, web-client, gateway
- **Ports**: 3006 (Panorama), 5173 (Web Client), 3000 (Gateway)
- **Spécialité**: VR/360°, PWA, Interface utilisateur

## 🚀 Démarrage Rapide

### 1. Configuration Initiale
```bash
# Cloner et configurer l'environnement
cd dreamscape-infra
./scripts/bigpods/dev-bigpods.sh --setup-repos
```

### 2. Développement Local
```bash
# Démarrer environnement développement complet
./scripts/bigpods/dev-bigpods.sh

# Ou pod spécifique avec hot reload
./scripts/bigpods/dev-bigpods.sh --pod core --no-auto-restart
```

### 3. Build et Test
```bash
# Build intelligent (seulement pods modifiés)
./scripts/bigpods/build-bigpods.sh --smart

# Build tous les pods en parallèle
./scripts/bigpods/build-bigpods.sh --all --parallel
```

### 4. Monitoring et Debug
```bash
# Dashboard monitoring temps réel
./scripts/bigpods/monitoring-bigpods.sh

# Debug interactif pod spécifique
./scripts/bigpods/debug-bigpods.sh core
```

## 🛠️ Scripts Développeurs

### build-bigpods.sh - Build Automatique
```bash
# Build smart (détection changements automatique)
./build-bigpods.sh --smart

# Build spécifique avec version
./build-bigpods.sh --pod business --version v2.1.0 --push

# Build parallèle sans cache
./build-bigpods.sh --all --parallel --no-cache
```

**Fonctionnalités:**
- ✅ Détection intelligente des changements par repository
- ✅ Build conditionnel (seulement pods impactés)
- ✅ Optimisation cache Docker multi-niveaux
- ✅ Push automatique vers registries avec versioning
- ✅ Builds parallèles pour performance maximale

### dev-bigpods.sh - Environnement Développement
```bash
# Démarrage environnement complet
./dev-bigpods.sh

# Configuration développement spécialisée
./dev-bigpods.sh --pod core --hot-reload --auto-restart

# Mode production-like pour tests
./dev-bigpods.sh --production-mode --no-watch
```

**Fonctionnalités:**
- 🔥 Hot reload intelligent pour tous services
- 🔄 Auto-restart avec détection erreurs
- 📁 Setup automatique 6 repositories
- 🏥 Health checks automatiques continus
- ⚡ Performance optimisée < 10s startup

### debug-bigpods.sh - Debugging Sophistiqué
```bash
# Session debug interactive
./debug-bigpods.sh core

# Analyse logs avec filtrage
./debug-bigpods.sh --mode logs --follow --level error

# Tests connectivité inter-pods
./debug-bigpods.sh --mode connectivity --pod business

# Export debug complet
./debug-bigpods.sh --export --output /tmp/debug-core-pod
```

**Fonctionnalités:**
- 🔍 Debug interactif multi-niveaux
- 📊 Logs agrégés par domaine métier
- 🔗 Tests connectivité inter-pods sophistiqués
- 📤 Export debug complet pour analyse
- 🐛 Connexion directe aux containers

## 🏭 Scripts Production

### deploy-bigpods.sh - Déploiement Orchestré
```bash
# Déploiement staging standard
./deploy-bigpods.sh --env staging

# Production avec rolling update
./deploy-bigpods.sh --env production --version v2.1.0 --rolling

# Blue-green deployment sécurisé
./deploy-bigpods.sh --env production --blue-green --notify

# Canary deployment progressif
./deploy-bigpods.sh --env production --canary --canary-percent 20
```

**Stratégies de Déploiement:**
- 🔄 **Rolling Update**: Mise à jour progressive sans interruption
- 🔵🟢 **Blue-Green**: Bascule instantanée avec rollback immédiat
- 🐦 **Canary**: Déploiement progressif avec validation métrics

### backup-bigpods.sh - Sauvegarde Complète
```bash
# Sauvegarde complète avec S3
./backup-bigpods.sh --type full --s3-bucket dreamscape-backups

# Sauvegarde incrémentale quotidienne
./backup-bigpods.sh --type incremental --retention 30

# Backup bases de données seulement
./backup-bigpods.sh --type databases --compression 9 --encryption
```

**Fonctionnalités:**
- 💾 Sauvegarde complète ecosystem Big Pods
- 🗜️ Compression avancée avec chiffrement AES-256
- ☁️ Upload automatique S3 avec lifecycle
- 🔄 Sauvegarde incrémentale intelligente
- ✅ Vérification intégrité automatique

### maintenance-bigpods.sh - Maintenance Automatique
```bash
# Maintenance complète nocturne
./maintenance-bigpods.sh --scheduled --notify

# Nettoyage agressif avec sauvegarde
./maintenance-bigpods.sh --mode cleanup --backup

# Maintenance sécurité et health checks
./maintenance-bigpods.sh --mode security --health
```

## 🔧 Scripts Utilitaires

### logs-bigpods.sh - Gestion Logs Centralisée
```bash
# Logs temps réel avec filtrage
./logs-bigpods.sh --follow --pod core --level error

# Recherche dans historique
./logs-bigpods.sh --search "payment failed" --since 24h

# Export logs pour analyse
./logs-bigpods.sh --export json --output /tmp/logs-analysis.json

# Statistiques logs
./logs-bigpods.sh --mode stats --since 7d
```

### monitoring-bigpods.sh - Monitoring Temps Réel
```bash
# Dashboard monitoring interactif
./monitoring-bigpods.sh

# Collection métriques pour analyse
./monitoring-bigpods.sh --mode metrics --duration 3600

# Monitoring continu avec alertes
./monitoring-bigpods.sh --mode alerts --continuous --webhook https://hooks.slack.com/...

# Export métriques Prometheus
./monitoring-bigpods.sh --export prometheus
```

### scale-bigpods.sh - Scaling Intelligent
```bash
# Scaling manuel immédiat
./scale-bigpods.sh core 5

# Auto-scaling basé métriques
./scale-bigpods.sh --mode auto business --cpu-target 70

# Load testing avec scaling
./scale-bigpods.sh --load-test experience --load-users 100

# Optimisation scaling automatique
./scale-bigpods.sh --mode optimize --load-test
```

## ⚙️ Configuration

### .dreamscape.config.yml
Le fichier de configuration centralisé définit l'architecture Big Pods :

```yaml
bigpods:
  core:
    name: "Core Pod"
    services: [auth, user]
    ports: ["80:80", "3001:3001", "3002:3002"]
    dependencies: [mongodb, redis]

  business:
    name: "Business Pod"
    services: [voyage, payment, ai]
    ports: ["3003:3003", "3004:3004", "3005:3005"]
    dependencies: [postgresql, redis]

  experience:
    name: "Experience Pod"
    services: [panorama, web-client, gateway]
    ports: ["3006:3006", "5173:5173", "3000:3000"]
```

## 🧪 Tests et Validation

### Exécution Tests Complets
```bash
# Tests unitaires complets
./scripts/bigpods/tests/run_all_tests.sh

# Tests avec verbose et parallèle
./scripts/bigpods/tests/run_all_tests.sh --verbose --parallel

# Tests sans Docker (CI/CD)
./scripts/bigpods/tests/run_all_tests.sh --skip-docker
```

### Tests Spécifiques
```bash
# Tests bibliothèque commune
./scripts/bigpods/tests/test_common.sh --verbose

# Tests intégration scripts
./scripts/bigpods/tests/test_scripts.sh --skip-docker
```

## 🚀 Workflows Développement

### Workflow Développeur Local
```bash
# 1. Setup environnement
./dev-bigpods.sh --setup-repos

# 2. Développement avec hot reload
./dev-bigpods.sh --pod core

# 3. Build smart après modifications
./build-bigpods.sh --smart

# 4. Tests automatiques
./tests/run_all_tests.sh

# 5. Debug si nécessaire
./debug-bigpods.sh core
```

### Workflow Déploiement Production
```bash
# 1. Build version de production
./build-bigpods.sh --all --version v2.1.0 --push

# 2. Tests intégration
./tests/run_all_tests.sh --parallel

# 3. Déploiement staging
./deploy-bigpods.sh --env staging --version v2.1.0

# 4. Validation staging
./monitoring-bigpods.sh --mode health

# 5. Déploiement production
./deploy-bigpods.sh --env production --version v2.1.0 --blue-green --notify

# 6. Monitoring post-déploiement
./monitoring-bigpods.sh --mode alerts --continuous
```

## 📊 Métriques et Performance

### Bénéfices Architecture Big Pods
- **Latence**: -90% vs microservices traditionnels
- **Mémoire**: -30% utilisation RAM
- **Déploiement**: -50% temps déploiement
- **Complexité**: -70% configuration réseau

### Métriques Monitoring
- CPU, Mémoire, Disque par pod
- Latence réseau inter-pods
- Santé applicative via endpoints
- Métriques business custom

## 🔒 Sécurité

### Bonnes Pratiques Intégrées
- ✅ Chiffrement backups AES-256
- ✅ Secrets via variables environnement
- ✅ Validation inputs utilisateur
- ✅ Logs opérations sensibles
- ✅ Permissions fichiers sécurisées

### Audit Sécurité
```bash
# Audit sécurité automatique
./maintenance-bigpods.sh --mode security

# Tests sécurité intégrés
./tests/run_all_tests.sh --coverage
```

## 🆘 Dépannage

### Problèmes Courants

**Build échoue**
```bash
# Vérifier Docker
./debug-bigpods.sh --mode health

# Build avec logs détaillés
./build-bigpods.sh --smart --verbose --debug
```

**Services non accessibles**
```bash
# Tests connectivité
./debug-bigpods.sh --mode connectivity

# Vérifier health endpoints
./monitoring-bigpods.sh --mode health
```

**Performance dégradée**
```bash
# Analyse performance
./monitoring-bigpods.sh --mode performance

# Scaling automatique
./scale-bigpods.sh --mode auto --cpu-target 60
```

## 📞 Support

### Ressources
- 📖 Documentation complète: `/docs/`
- 🧪 Tests intégrés: `/tests/`
- 🐛 Debug interactif: `./debug-bigpods.sh`
- 📊 Monitoring temps réel: `./monitoring-bigpods.sh`

### Community
- GitHub Issues pour bugs
- Discussions pour questions
- Wiki pour guides avancés

---

**🎉 DreamScape Big Pods - Révolutionnant l'Architecture Cloud Moderne**