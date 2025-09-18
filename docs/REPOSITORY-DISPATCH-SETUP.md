# 🔄 Repository Dispatch CI/CD Setup Guide

Cette architecture permet de centraliser la CI/CD dans `dreamscape-infra` tout en gardant les repositories séparés.

## 📋 Architecture Overview

```mermaid
graph TD
    A[dreamscape-services] -->|repository_dispatch| E[dreamscape-infra]
    B[dreamscape-frontend] -->|repository_dispatch| E
    C[dreamscape-tests] -->|repository_dispatch| E
    D[dreamscape-docs] -->|repository_dispatch| E
    
    E --> F[Central CI/CD Pipeline]
    F --> G[Build & Test]
    F --> H[Security Scan]
    F --> I[Deploy to Oracle Cloud]
```

## 🏗️ Repositories Structure

- **dreamscape-services** - Backend microservices
- **dreamscape-frontend** - Web clients & interfaces  
- **dreamscape-tests** - Test suites (E2E, integration, unit)
- **dreamscape-docs** - Documentation
- **dreamscape-infra** - Infrastructure & CI/CD central

## 🔧 Setup Instructions

### 1. Configuration des Secrets

Dans le repository `dreamscape-infra`, configurer les secrets suivants :

#### Repository Secrets (Settings → Secrets and variables → Actions)

```bash
# Personal Access Token pour cross-repo communication
DISPATCH_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx

# Oracle Cloud Infrastructure secrets
VM_HOST_DEV=xxx.xxx.xxx.xxx
VM_HOST_STAGING=xxx.xxx.xxx.xxx  
VM_HOST_PRODUCTION=xxx.xxx.xxx.xxx

SSH_PRIVATE_KEY_DEV=-----BEGIN OPENSSH PRIVATE KEY-----...
SSH_PRIVATE_KEY_STAGING=-----BEGIN OPENSSH PRIVATE KEY-----...
SSH_PRIVATE_KEY_PRODUCTION=-----BEGIN OPENSSH PRIVATE KEY-----...
```

#### Création du DISPATCH_TOKEN

1. Aller sur https://github.com/settings/tokens
2. Créer un **Classic Personal Access Token**
3. Permissions requises :
   - `repo` (Full control of private repositories)
   - `workflow` (Update GitHub Action workflows)
   - `admin:repo_hook` (Read and write repository hooks)

### 2. Installation des Triggers dans chaque Repository

Pour chaque repository source, copier le fichier trigger correspondant :

#### dreamscape-services
```bash
cp trigger-workflows/services-trigger.yml dreamscape-services/.github/workflows/trigger-central-cicd.yml
```

#### dreamscape-frontend  
```bash
cp trigger-workflows/frontend-trigger.yml dreamscape-frontend/.github/workflows/trigger-central-cicd.yml
```

#### dreamscape-tests
```bash
cp trigger-workflows/tests-trigger.yml dreamscape-tests/.github/workflows/trigger-central-cicd.yml
```

#### dreamscape-docs
```bash
cp trigger-workflows/docs-trigger.yml dreamscape-docs/.github/workflows/trigger-central-cicd.yml
```

### 3. Configuration du DISPATCH_TOKEN dans chaque Repository

Dans chaque repository source (services, frontend, tests, docs) :

1. Aller dans **Settings → Secrets and variables → Actions**
2. Ajouter le secret : `DISPATCH_TOKEN=<same_token_as_infra>`

## 🚀 Fonctionnement

### Triggers Automatiques

| Repository | Event | Action |
|------------|-------|--------|
| `dreamscape-services` | Push sur main/develop | Trigger build + deploy backend |
| `dreamscape-frontend` | Push sur main/develop | Trigger build + deploy frontend |
| `dreamscape-tests` | Push sur main/develop | Trigger test suite |
| `dreamscape-docs` | Push sur main/develop | Trigger docs update (si impact deploy) |

### Événements Repository Dispatch

#### services-changed
```json
{
  "event_type": "services-changed",
  "client_payload": {
    "source_repo": "DREAMSCAPE-AI/dreamscape-services",
    "ref": "refs/heads/main",
    "sha": "abc123...",
    "component": "auth-service,user-service",
    "environment": "production"
  }
}
```

#### frontend-changed
```json
{
  "event_type": "frontend-changed", 
  "client_payload": {
    "source_repo": "DREAMSCAPE-AI/dreamscape-frontend",
    "ref": "refs/heads/develop",
    "sha": "def456...",
    "component": "web-client,gateway",
    "environment": "staging"
  }
}
```

#### tests-changed
```json
{
  "event_type": "tests-changed",
  "client_payload": {
    "source_repo": "DREAMSCAPE-AI/dreamscape-tests", 
    "ref": "refs/heads/feature/new-tests",
    "sha": "ghi789...",
    "component": "integration,e2e",
    "environment": "dev"
  }
}
```

## 📊 Mapping Environment

| Branch | Environment | Action |
|--------|-------------|---------|
| `main` | `production` | Deploy to production |
| `develop` | `staging` | Deploy to staging |
| `feature/*` | `dev` | Tests only, no deployment |
| `hotfix/*` | `production` | Hotfix deployment |

## 🔍 Monitoring et Debugging

### Vérifier les Triggers

1. **Dans le repository source** : Vérifier que le workflow "Trigger Central CI/CD" s'exécute
2. **Dans dreamscape-infra** : Vérifier que le workflow "Central CI/CD Pipeline" se lance

### Logs et Status

- **Commit Status** : Chaque repository source affiche le status du pipeline central
- **Logs centralisés** : Tous les logs dans `dreamscape-infra/actions`
- **Artifacts** : Build artifacts centralisés dans dreamscape-infra

### Debugging Common Issues

#### ❌ Token Permission Error
```
Error: Resource not accessible by personal access token
```
**Solution** : Vérifier que le DISPATCH_TOKEN a les permissions `repo` et `workflow`

#### ❌ Repository Dispatch Not Triggered
**Vérifier** :
1. Le secret `DISPATCH_TOKEN` est configuré dans le repository source
2. Le workflow trigger est présent dans `.github/workflows/`
3. Les permissions du token incluent le repository cible

#### ❌ Central Pipeline Not Starting
**Vérifier** :
1. Le workflow `central-dispatch.yml` est présent dans dreamscape-infra
2. Les événements `repository_dispatch` sont configurés correctement
3. Les types d'événements correspondent (`services-changed`, etc.)

## 🎯 Avantages de cette Architecture

✅ **Centralization** : Toute la logique CI/CD dans un seul endroit  
✅ **Isolation** : Chaque équipe peut travailler sur son repository  
✅ **Coordination** : Déploiements coordonnés cross-services  
✅ **Monitoring** : Vue d'ensemble centralisée  
✅ **Scaling** : Facile d'ajouter de nouveaux services  
✅ **Security** : Secrets et déploiements centralisés  

## 🧪 Testing

### Test Manuel

Tester un trigger depuis dreamscape-services :
```bash
# 1. Push sur une branch feature
git checkout -b feature/test-dispatch
git commit --allow-empty -m "test dispatch"
git push origin feature/test-dispatch

# 2. Vérifier que le pipeline central se lance
# GitHub → dreamscape-infra → Actions
```

### Test avec curl
```bash
curl -X POST \
  -H "Authorization: token ${DISPATCH_TOKEN}" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/DREAMSCAPE-AI/dreamscape-infra/dispatches \
  -d '{
    "event_type": "services-changed",
    "client_payload": {
      "source_repo": "DREAMSCAPE-AI/dreamscape-services",
      "component": "auth-service",
      "environment": "dev"
    }
  }'
```

## 📚 Next Steps

1. ✅ Setup central pipeline dans dreamscape-infra
2. ⏳ Installer triggers dans chaque repository
3. ⏳ Configurer tous les secrets
4. ⏳ Tester l'architecture complète
5. ⏳ Déployer en production

## 🔗 Links

- [GitHub Repository Dispatch API](https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event)
- [GitHub Actions Workflow Dispatch](https://docs.github.com/en/actions/managing-workflow-runs/manually-running-a-workflow)
- [Oracle Cloud Container Instances](https://docs.oracle.com/en-us/iaas/Content/container-instances/home.htm)