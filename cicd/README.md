# CI/CD — Pipelines DreamScape

> **Pipelines GitHub Actions** — Intégration et déploiement continus en architecture 2 stages

## Architecture en 2 stages

DreamScape utilise un pattern de **repository dispatch** entre deux dépôts :

```
dreamscape-services (Stage 1)        dreamscape-infra (Stage 2)
      │                                       │
      │  push/PR → ci-trigger.yml             │
      │  → détecte services modifiés          │
      │  → émet repository_dispatch ──────────►│
      │                                       │  unified-cicd.yml
      │                                       │  → Clone source repo
      │                                       │  → Tests
      │                                       │  → Build Docker
      │                                       │  → Push GHCR
      │                                       │  → Deploy k3s
```

## Workflows

### Stage 1 — `dreamscape-services` (source)

**Fichier** : `.github/workflows/ci-trigger.yml`

**Déclencheurs** : Push sur `main`, `dev`, `develop`, `feature/**` + Pull Requests

**Actions** :
1. Détecte les services modifiés (auth, user, voyage, payment, ai, panorama)
2. Si `db/` ou `shared/` modifiés → rebuild de **tous** les services
3. Lint les services modifiés
4. Émet un `repository_dispatch` vers `dreamscape-infra` avec :
   ```json
   {
     "event_type": "services-changed",
     "client_payload": {
       "source_repo": "dreamscape-services",
       "ref": "main",
       "sha": "abc123",
       "component": "auth,user"
     }
   }
   ```

### Stage 2 — `dreamscape-infra` (déploiement)

**Fichiers** :
| Workflow | Description |
|----------|-------------|
| `workflows/ci.yml` | Pipeline CI principal |
| `workflows/bigpods-ci.yml` | CI spécifique Big Pods |
| `workflows/bigpods-cd.yml` | CD (déploiement) Big Pods |
| `workflows/bigpods-release.yml` | Release Big Pods |

**Actions** (unified-cicd.yml) :
1. Parse le payload `repository_dispatch`
2. Clone le repo source (`dreamscape-services`)
3. Exécute les tests
4. Build les images Docker (multi-stage)
5. Push vers GHCR (`ghcr.io/dreamscape-ai/<service>:latest`)
6. Déploie sur k3s via `kubectl apply -k k8s/overlays/<env>`
7. Crée un GitHub Deployment avec statut automatique

## Mapping branches → environnements

| Branche | Environnement | Action |
|---------|---------------|--------|
| `main` | production | Deploy prod |
| `develop` | staging | Deploy staging |
| `feature/**`, `bugfix/**`, `hotfix/**` | dev | Deploy dev |
| Pull Requests | dev | Deploy preview |

## Images Docker

Format des tags :
```
ghcr.io/dreamscape-ai/<service>:<sha>
ghcr.io/dreamscape-ai/<service>:latest
ghcr.io/dreamscape-ai/<service>:v1.2.3
```

Registry : GitHub Container Registry (GHCR)

## Big Pods CI/CD

Le workflow Big Pods est distinct car il gère les containers multi-services :

```bash
# bigpods-ci.yml — Tests
# 1. Build Core Pod (auth + user + nginx)
# 2. Test tous les endpoints
# 3. Vérification health checks

# bigpods-cd.yml — Déploiement
# 1. Build et push l'image Core Pod
# 2. kubectl apply bigpods-production-bootstrap.yaml
# 3. Vérification post-déploiement
```

## Secrets requis

| Secret | Description |
|--------|-------------|
| `GHCR_TOKEN` | Token GitHub pour push GHCR |
| `KUBE_CONFIG` | Kubeconfig k3s (base64) |
| `DISPATCH_TOKEN` | Token pour repository_dispatch |
| `SLACK_WEBHOOK` | Notifications Slack (optionnel) |

## Stratégies de déploiement

- **Rolling Update** — Déploiement par défaut (zero-downtime)
- **Blue-Green** — Pour les changements breaking (configuré manuellement)
- **Canary** — Pour les features à risque (10% → 50% → 100%)
- **Rollback automatique** — Si les health checks échouent post-déploiement

## Détection des services modifiés

Le workflow analyse le `git diff` pour détecter les changements :

```yaml
# Logique de détection
if: contains(steps.changes.outputs.files, 'auth/')
  → rebuild auth-service

if: contains(steps.changes.outputs.files, 'db/') || contains(steps.changes.outputs.files, 'shared/')
  → rebuild ALL services (shared dependency)
```

---

*Voir `dreamscape-infra/README.md` pour l'architecture globale.*
