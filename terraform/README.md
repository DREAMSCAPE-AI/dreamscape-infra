# Terraform — Infrastructure as Code DreamScape

> **IaC** — Provisioning de l'infrastructure cloud pour les environnements DreamScape

## Structure

```
terraform/
├── modules/
│   ├── k3s/                    # Cluster Kubernetes k3s
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── cloud-init-server.yaml   # Config serveur k3s
│   │   └── cloud-init-agent.yaml    # Config agents k3s
│   ├── databases/              # PostgreSQL, Redis
│   │   └── main.tf
│   └── networking/             # VPC, subnets, security groups
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/               # Configurations par environnement
    ├── dev/
    ├── staging/
    └── prod/
```

## Quick Start

```bash
# Prérequis
terraform version   # >= 1.5
aws configure       # ou équivalent selon cloud provider

# Initialisation
cd terraform
terraform init

# Planifier les changements
terraform plan -var-file="environments/dev/terraform.tfvars"

# Appliquer (dev)
terraform apply -var-file="environments/dev/terraform.tfvars"

# Détruire (attention !)
terraform destroy -var-file="environments/dev/terraform.tfvars"
```

## Workspaces par environnement

```bash
# Créer les workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Changer de workspace
terraform workspace select dev
terraform workspace list
```

## Modules

### Module `k3s`
Provisionne un cluster k3s léger pour l'orchestration des containers DreamScape.

**Variables clés** :
```hcl
variable "environment"    { default = "dev" }
variable "region"         { default = "eu-west-1" }
variable "instance_type"  { default = "t3.medium" }
variable "node_count"     { default = 2 }
```

**Outputs** :
- `cluster_endpoint` — URL du cluster k3s
- `kubeconfig` — Fichier kubeconfig généré

### Module `databases`
Provisionne PostgreSQL managé et Redis.

**Ressources créées** :
- Instance PostgreSQL RDS (ou équivalent)
- Cluster Redis ElastiCache (ou équivalent)
- Security groups et subnet groups dédiés

### Module `networking`
VPC, subnets publics/privés, internet gateway, NAT gateway.

**Variables clés** :
```hcl
variable "vpc_cidr"           { default = "10.0.0.0/16" }
variable "availability_zones" { default = ["eu-west-1a", "eu-west-1b"] }
```

## Variables d'environnement Terraform

```bash
export TF_VAR_environment="dev"
export TF_VAR_region="eu-west-1"
export TF_VAR_db_password="your-secure-password"

# Ou via fichier .tfvars (jamais commité)
cat environments/dev/terraform.tfvars
```

## Remote State

Le state Terraform est stocké à distance (S3 + DynamoDB lock) :

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "dreamscape-terraform-state"
    key            = "dreamscape/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "dreamscape-terraform-lock"
    encrypt        = true
  }
}
```

## Workflow CI/CD

Le pipeline `dreamscape-infra/.github/workflows/` intègre Terraform :
1. `terraform fmt -check` — Vérification du format
2. `terraform validate` — Validation de la syntaxe
3. `terraform plan` — Plan sur les PRs
4. `terraform apply` — Application automatique sur merge en `main` (prod)

## Bonnes pratiques

- Ne jamais stocker de secrets dans les fichiers `.tf` — utiliser les variables
- Utiliser `terraform plan` avant chaque `apply`
- Tags obligatoires sur toutes les ressources : `Project`, `Environment`, `ManagedBy=terraform`
- Modules versionnés pour la réutilisabilité

---

*Voir `dreamscape-infra/README.md` pour l'architecture globale.*
