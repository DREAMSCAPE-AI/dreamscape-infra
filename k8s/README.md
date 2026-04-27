# Kubernetes — Manifests DreamScape

> **Orchestration K8s** — Déploiements, services, HPA et configurations par environnement (k3s)

## Structure

```
k8s/
├── base/                          # Configurations de base (partagées)
│   ├── auth/
│   │   ├── deployment.yaml        # Deployment auth-service
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   ├── hpa.yaml               # Horizontal Pod Autoscaler
│   │   ├── networkpolicy.yaml
│   │   └── poddisruptionbudget.yaml
│   ├── user/
│   ├── voyage/
│   ├── gateway/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   ├── hpa.yaml
│   │   └── networkpolicy.yaml
│   ├── redis/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── pvc.yaml               # PersistentVolumeClaim
│   │   └── configmap.yaml
│   └── common/
│       ├── cert-issuer.yaml       # Let's Encrypt cert-manager
│       └── networkpolicy.yaml
├── overlays/                      # Surcharges par environnement
│   ├── dev/
│   │   └── kustomization.yaml
│   ├── staging/
│   │   └── kustomization.yaml
│   └── prod/
│       └── kustomization.yaml
├── bigpods-production-bootstrap.yaml   # Bootstrap Big Pods prod
└── bigpods-staging-bootstrap.yaml      # Bootstrap Big Pods staging
```

## Déploiement par environnement

```bash
# Développement
kubectl apply -k k8s/overlays/dev

# Staging
kubectl apply -k k8s/overlays/staging

# Production
kubectl apply -k k8s/overlays/prod
```

## Commandes utiles

```bash
# Vérifier les pods
kubectl get pods -n dreamscape

# Logs d'un service
kubectl logs -f deployment/auth-service -n dreamscape

# Rolling update
kubectl rollout restart deployment/auth-service -n dreamscape

# Vérifier le statut du déploiement
kubectl rollout status deployment/auth-service -n dreamscape

# Scaling manuel
kubectl scale deployment/auth-service --replicas=3 -n dreamscape

# Port forwarding (développement)
kubectl port-forward service/gateway 4000:3000 -n dreamscape
kubectl port-forward service/auth-service 3001:3001 -n dreamscape
```

## Namespaces

```bash
kubectl create namespace dreamscape-dev
kubectl create namespace dreamscape-staging
kubectl create namespace dreamscape-prod
```

## Horizontal Pod Autoscaler (HPA)

Les services `auth` et `gateway` ont un HPA configuré :

```yaml
spec:
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

## Kustomize

Les overlays utilisent Kustomize pour surcharger les bases :

```yaml
# overlays/prod/kustomization.yaml
resources:
  - ../../base/auth
  - ../../base/user
  - ../../base/voyage
  - ../../base/gateway
  - ../../base/redis

images:
  - name: ghcr.io/dreamscape-ai/auth-service
    newTag: latest

patches:
  - path: replicas.yaml   # Surcharge du nombre de replicas
```

## Big Pods Bootstrap

Pour les déploiements Big Pods (Core Pod + Business Pod), utiliser les fichiers dédiés :

```bash
# Production
kubectl apply -f k8s/bigpods-production-bootstrap.yaml

# Staging
kubectl apply -f k8s/bigpods-staging-bootstrap.yaml
```

Ces fichiers déploient les containers multi-services avec Supervisor + NGINX.

## Images Docker

Toutes les images sont publiées sur GitHub Container Registry :

```
ghcr.io/dreamscape-ai/auth-service:latest
ghcr.io/dreamscape-ai/user-service:latest
ghcr.io/dreamscape-ai/voyage-service:latest
ghcr.io/dreamscape-ai/payment-service:latest
ghcr.io/dreamscape-ai/ai-service:latest
ghcr.io/dreamscape-ai/gateway:latest
```

## Network Policies

Les `NetworkPolicy` limitent la communication entre pods :
- Seul le Gateway peut contacter les services backend
- Les services peuvent contacter PostgreSQL et Redis
- Les communications cross-namespace sont bloquées

---

*Voir `dreamscape-infra/README.md` pour l'architecture Big Pods complète.*
