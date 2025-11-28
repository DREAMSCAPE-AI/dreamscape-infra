# DreamScape Infrastructure

## À propos du repository

Bienvenue dans le repository d'infrastructure de DreamScape, la plateforme innovante de voyage combinant intelligence artificielle contextuelle et expériences panoramiques pour offrir une expérience de planification de voyage personnalisée.

Ce repository contient l'ensemble des configurations d'infrastructure, des scripts de déploiement et des templates Infrastructure-as-Code (IaC) nécessaires au fonctionnement de la plateforme DreamScape.

## Objectifs du repository

- Fournir une infrastructure cloud robuste, évolutive et sécurisée pour héberger les services DreamScape
- Automatiser le déploiement et la configuration de l'infrastructure via Terraform et Kubernetes
- Garantir la reproductibilité des environnements (développement, staging, production)
- Documenter les bonnes pratiques et procédures d'exploitation de l'infrastructure
- Soutenir l'approche de développement progressive (2 jours/semaine) avec une infrastructure fiable

## Structure du repository

```
dreamscape-infra/
├── terraform/                     # Configuration Terraform pour OCI
│   ├── modules/                   # Modules Terraform réutilisables
│   ├── environments/              # Configurations spécifiques aux environnements
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── variables/                 # Définitions des variables partagées
├── kubernetes/                    # Configurations Kubernetes (K3s)
│   ├── namespaces/                # Définitions des namespaces
│   ├── services/                  # Services par module (core, voyage, ia, panorama)
│   ├── deployments/               # Déploiements des applications
│   ├── ingress/                   # Configuration Ingress/NGINX
│   └── volumes/                   # Persistent Volume Claims
├── cloudflare/                    # Configuration Cloudflare
│   ├── dns/                       # Configuration DNS
│   ├── pages/                     # Configuration Cloudflare Pages
│   ├── r2/                        # Configuration R2 Storage
│   └── workers/                   # Scripts Cloudflare Workers
├── monitoring/                    # Configuration Prometheus/Grafana
│   ├── prometheus/                # Configuration Prometheus
│   ├── grafana/                   # Dashboards Grafana
│   └── alerts/                    # Définitions des alertes
├── scripts/                       # Scripts utilitaires et d'automation
│   ├── setup/                     # Scripts d'initialisation
│   ├── backup/                    # Scripts de sauvegarde
│   └── ci/                        # Scripts pour le CI/CD
└── docs/                          # Documentation technique
    ├── architecture/              # Diagrammes d'architecture
    ├── operations/                # Procédures opérationnelles
    └── troubleshooting/           # Guide de dépannage
```

## Prérequis

Pour travailler avec ce repository, vous aurez besoin de :

- Terraform v1.5.0 ou supérieur
- kubectl v1.26.0 ou supérieur
- OCI CLI configuré avec les accès appropriés
- Accès à GitHub Packages pour les images Docker
- Accès aux comptes Cloudflare et Stripe
- Python 3.9+ pour les scripts

## Démarrage rapide

1. Clonez ce repository :
   ```bash
   git clone https://github.com/dreamscape/dreamscape-infra.git
   cd dreamscape-infra
   ```

2. Configurez vos identifiants OCI :
   ```bash
   ./scripts/setup/configure-oci-credentials.sh
   ```

3. Initialisez l'infrastructure de développement :
   ```bash
   cd terraform/environments/dev
   terraform init
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

4. Configurer l'accès Kubernetes :
   ```bash
   ./scripts/setup/configure-k3s-access.sh
   ```

5. Déployer les services de base :
   ```bash
   kubectl apply -f kubernetes/namespaces/
   kubectl apply -f kubernetes/services/core/
   ```

## Flux de travail de développement infrastructure

Compte tenu de notre rythme de développement (2 jours/semaine), nous suivons un workflow adapté :

1. **Jour 1 de la semaine** :
   - Revue des tickets d'infrastructure
   - Développement des modifications Terraform/Kubernetes
   - Tests en environnement de développement
   - Peer review des changements

2. **Jour 2 de la semaine** :
   - Correction suite aux retours de revue
   - Déploiement en environnement de staging
   - Tests d'intégration avec les autres services
   - Documentation des changements

3. **Cycle de déploiement en production** :
   - Déploiement en production une fois par mois
   - Fenêtre de maintenance planifiée
   - Procédure de rollback automatisée en cas de problème

## Architecture d'infrastructure

DreamScape utilise une infrastructure hybride combinant :

- **Oracle Cloud Infrastructure (OCI)** : Pour le déploiement des services backend
  - 4 instances ARM Ampere A1 (24 GB RAM au total)
  - Kubernetes (K3s) pour l'orchestration des containers
  - PostgreSQL et MongoDB pour les données structurées et non-structurées
  - Redis pour le caching et les sessions

- **Cloudflare** : Pour la distribution et la sécurité
  - Cloudflare Pages pour l'hébergement frontend
  - Cloudflare R2 pour le stockage des panoramas et médias
  - Cloudflare CDN pour l'optimisation des performances
  - Cloudflare Workers pour le traitement en bordure de réseau

Cette architecture permet de maximiser l'utilisation des ressources gratuites/low-cost tout en maintenant une haute disponibilité et des performances optimales.

## Bonnes pratiques

- **Infrastructure as Code** : Toute modification doit être faite via Terraform
- **Versionnement** : Versionnez toujours les modules Terraform et les configurations K8s
- **Documentation** : Documentez chaque module et configuration avec des commentaires
- **Tests** : Testez toujours les changements en dev/staging avant la production
- **Sécurité** : Suivez le principe du moindre privilège pour les accès
- **Monitoring** : Configurez les alertes appropriées pour chaque nouveau service

## Sauvegarde et reprise après sinistre

- Sauvegardes automatiques quotidiennes des bases de données
- Sauvegardes hebdomadaires de l'état Terraform
- Procédure de restauration documentée dans `docs/operations/disaster-recovery.md`
- Test de restauration mensuel en environnement de staging

## Monitoring et observabilité

- Prometheus pour la collecte de métriques
- Grafana pour la visualisation et les dashboards
- Alertmanager pour les notifications
- Dashboards prédéfinis pour les métriques clés :
  - Performance des services
  - Utilisation des ressources (CPU, mémoire, disque)
  - Latence des APIs
  - Performance des bases de données

## Sécurité

- Configuration TLS pour toutes les communications
- Gestion des secrets via Kubernetes Secrets
- Policies de sécurité OCI restrictives
- WAF Cloudflare pour la protection des endpoints publics
- Scan régulier des vulnérabilités avec rapports automatiques

## Contribuer

Pour contribuer à ce repository, veuillez suivre ces étapes :

1. Créez une branche à partir de `main` avec un nom descriptif :
   ```bash
   git checkout -b feature/nom-descriptif
   ```

2. Faites vos modifications et créez des commits avec des messages clairs :
   ```bash
   git commit -m "Description détaillée des changements"
   ```

3. Poussez votre branche et créez une Pull Request
4. Demandez une revue à au moins un membre de l'équipe infrastructure
5. Après approbation, les changements seront mergés dans `main`

## Support et contact

Pour toute question concernant l'infrastructure, contactez l'équipe DevOps via :
- Channel Slack : #dreamscape-infra
- Email : devops@dreamscape.example.com

## Prochaines étapes

- Mise en place de l'auto-scaling pour les services critiques
- Migration vers OKE (Oracle Kubernetes Engine) pour la phase 2
- Implémentation du multi-région pour la haute disponibilité
- Amélioration des outils de monitoring avec ELK Stack

---

Dernière mise à jour : 20 mai 2025  
Maintenu par : Équipe DevOps DreamScape
