# INFRA-013.2 - Monitoring de Disponibilité

**Date**: 2025-11-28
**Ticket**: INFRA-013.2
**Story Points**: 2
**Status**: ✅ Complete

---

## 📋 Résumé

Implementation complète du monitoring de disponibilité pour tous les services DreamScape avec calcul SLA, dashboard Grafana, et alertes d'indisponibilité.

---

## 🎯 Acceptance Criteria

| Critère | Status | Implémentation |
|---------|--------|----------------|
| **Monitoring uptime de tous les services** | ✅ | health-probes.yaml + recording-rules-sla.yaml |
| **Calcul SLA** | ✅ | Recording rules (uptime 1h/24h/7d/30d, MTTR, MTBF) |
| **Dashboard disponibilité** | ✅ | dashboard-availability.json |
| **Alertes sur indisponibilité** | ✅ | alerts-availability.yaml |

---

## 📂 Fichiers Créés/Modifiés

### Nouveaux Fichiers

1. **`monitoring/prometheus/health-probes.yaml`** (165 lignes)
   - Configuration Prometheus pour scraper les endpoints /health
   - Jobs pour auth, user, gateway, voyage, AI
   - Liveness probes (intervalle 5s)
   - Readiness probes (intervalle 10s)

2. **`monitoring/prometheus/recording-rules-sla.yaml`** (220 lignes)
   - Recording rules pour calcul SLA
   - Métriques d'uptime (1h, 24h, 7d, 30d)
   - MTTR (Mean Time To Recovery)
   - MTBF (Mean Time Between Failures)
   - Downtime incidents counting
   - Composite SLA score

3. **`monitoring/prometheus/alerts-availability.yaml`** (290 lignes)
   - Alertes basées sur health checks
   - Alertes SLA breach (99.9%, 99.5%)
   - Alertes MTTR élevé
   - Alertes dépendances (DB, cache)
   - Alertes capacité

4. **`monitoring/grafana/dashboard-availability.json`** (810 lignes)
   - Dashboard Grafana complet
   - Panels: Platform Health, Service Uptime, SLA Table
   - MTTR/MTBF gauges
   - Dependency health status
   - Variables: service, environment

### Fichiers Modifiés

5. **`monitoring/prometheus/values.yaml`**
   - Ajout du service AI dans les scrape configs (lignes 114-130)

---

## 🚀 Déploiement

### Prérequis

- Kubernetes cluster avec Prometheus Operator
- Grafana configuré
- Services DreamScape avec endpoints /health (INFRA-013.1)

### Étapes de Déploiement

#### 1. Déployer les Recording Rules

```bash
kubectl apply -f monitoring/prometheus/recording-rules-sla.yaml
```

**Vérification** :
```bash
# Vérifier que les rules sont créées
kubectl get prometheusrules -n monitoring dreamscape-sla-recording-rules

# Vérifier dans Prometheus UI (http://localhost:9090)
# Aller dans Status > Rules
# Chercher "dreamscape.sla"
```

#### 2. Déployer les Alertes d'Availability

```bash
kubectl apply -f monitoring/prometheus/alerts-availability.yaml
```

**Vérification** :
```bash
# Vérifier les alert rules
kubectl get prometheusrules -n monitoring dreamscape-availability-alerts

# Dans Prometheus UI
# Aller dans Alerts
# Chercher "ServiceUnhealthy", "SLABreachWarning"
```

#### 3. Mettre à Jour Prometheus Config

```bash
# Mettre à jour le Helm release avec les nouvelles valeurs
helm upgrade dreamscape-prometheus prometheus-community/kube-prometheus-stack \
  -f monitoring/prometheus/values.yaml \
  -f monitoring/prometheus/health-probes.yaml \
  -n monitoring
```

**Vérification** :
```bash
# Vérifier les targets Prometheus
# Dans Prometheus UI > Status > Targets
# Chercher :
# - dreamscape-health-auth
# - dreamscape-health-user
# - dreamscape-health-gateway
# - dreamscape-health-voyage
# - dreamscape-health-ai
# - dreamscape-liveness
# - dreamscape-readiness
```

#### 4. Importer le Dashboard Grafana

**Option A - Via UI** :
1. Ouvrir Grafana (http://localhost:3000)
2. Aller dans Dashboards > Import
3. Copier le contenu de `dashboard-availability.json`
4. Click "Load" puis "Import"

**Option B - Via ConfigMap** :
```bash
kubectl create configmap grafana-dashboard-availability \
  --from-file=monitoring/grafana/dashboard-availability.json \
  -n monitoring

kubectl label configmap grafana-dashboard-availability \
  grafana_dashboard=1 \
  -n monitoring
```

**Vérification** :
- Ouvrir Grafana > Dashboards
- Chercher "DreamScape - Service Availability & SLA"
- Vérifier que les panels affichent des données

---

## 📊 Dashboard Grafana

### Panels Disponibles

1. **Overall Service Availability** (Row 1)
   - Platform Health (gauge) - % de services healthy
   - Service Uptime - Last 24h (timeseries)
   - Service Health Status (bargauge)

2. **SLA Metrics** (Row 2)
   - SLA Overview Table (table avec uptime 1h/24h/7d/30d, downtime, incidents)
   - 30-Day SLA (bargauge avec target 99.9%)
   - Downtime Over Time (timeseries)

3. **MTTR & MTBF** (Row 3)
   - MTTR - Auth/User (gauges)
   - MTBF - 7 Days (gauge)
   - Downtime Incidents (timeseries)

4. **Dependencies Health** (Row 4)
   - PostgreSQL Status (stat)
   - MongoDB Status (stat)
   - Redis Status (stat)
   - Overall Dependency Health Score (gauge)

### Variables

- **service**: Auth, User, Gateway, Voyage, AI
- **environment**: dev, staging, prod

### Accès

```
URL: https://grafana.dreamscape.com/d/dreamscape-availability-sla
Refresh: 30s
Time range: Last 24h (modifiable)
```

---

## 🔔 Alertes Configurées

### Availability Alerts

| Alert | Severity | Seuil | Description |
|-------|----------|-------|-------------|
| **ServiceUnhealthy** | Critical | health_status == 0 for 2m | Service échoue health check |
| **ServiceDegraded** | Warning | P95 response > 1s for 10m | Service lent (dégradé) |
| **LivenessProbeFailure** | Critical | Liveness fail for 1m | Pod va redémarrer |
| **ReadinessProbeFailure** | Warning | Readiness fail for 5m | Service hors load balancer |
| **MultipleServicesDown** | Critical | >= 2 services down for 1m | Problème platform-wide |

### SLA Alerts

| Alert | Severity | Seuil | Description |
|-------|----------|-------|-------------|
| **SLABreachWarning** | Warning | Uptime 30d < 99.9% for 30m | Approche du breach SLA |
| **SLABreachCritical** | Critical | Uptime 30d < 99.5% for 15m | Breach SLA critique |
| **FrequentDowntimeIncidents** | Warning | > 5 incidents in 24h | Service instable |
| **HighMTTR** | Warning | MTTR > 10min for 30m | Recovery trop lent |

### Dependency Alerts

| Alert | Severity | Seuil | Description |
|-------|----------|-------|-------------|
| **DatabaseUnavailabilityImpact** | Critical | DB down + services unhealthy | DB down affecte services |
| **CacheUnavailability** | Warning | Redis down for 5m | Cache indisponible |
| **DependencyHealthDegraded** | Warning | Health score < 80% for 10m | Plusieurs dépendances KO |

### Destinations

**Slack** :
- `#alerts` - Warnings
- `#critical-alerts` - Critical alerts
- `#ai-services` - AI-specific alerts

**Email** :
- `oncall@dreamscape.com` - Critical alerts only

---

## 📈 Métriques SLA

### Recording Rules Créées

#### Availability

```promql
# Service disponible (1 = up, 0 = down)
dreamscape:service:available

# Par service
dreamscape:service:available:by_service

# Uptime percentage
dreamscape:service:uptime_1h    # Last hour
dreamscape:service:uptime_24h   # Last day
dreamscape:service:uptime_7d    # Last week
dreamscape:service:uptime_30d   # Last month (SLA target)
```

#### Downtime

```promql
# Downtime en secondes
dreamscape:service:downtime_seconds_24h
dreamscape:service:downtime_seconds_30d

# Nombre d'incidents
dreamscape:service:downtime_incidents_24h
dreamscape:service:downtime_incidents_7d
```

#### MTTR & MTBF

```promql
# Mean Time To Recovery (secondes)
dreamscape:service:mttr_seconds_24h
dreamscape:service:mttr_seconds_7d

# Mean Time Between Failures (heures)
dreamscape:service:mtbf_hours_7d
dreamscape:service:mtbf_hours_30d
```

#### Composite SLA Score

```promql
# Score SLA composite (uptime + success rate)
dreamscape:service:sla_score_24h
dreamscape:service:sla_score_30d

# Indicateur de breach
dreamscape:service:sla_breach_999  # < 99.9%
dreamscape:service:sla_breach_995  # < 99.5%
```

### Exemples de Requêtes

**Voir l'uptime de tous les services** :
```promql
dreamscape:service:uptime_30d
```

**Services avec SLA < 99.9%** :
```promql
dreamscape:service:uptime_30d < 99.9
```

**MTTR moyen sur 24h** :
```promql
avg(dreamscape:service:mttr_seconds_24h)
```

**Incidents de downtime par service** :
```promql
dreamscape:service:downtime_incidents_7d
```

---

## 🧪 Tests

### Test 1: Vérifier Scraping Health Checks

```bash
# Dans Prometheus UI (http://localhost:9090)
# Exécuter la query :
up{job=~"dreamscape-health-.*"}

# Résultat attendu : 1 pour chaque service (auth, user, gateway, voyage, ai)
```

### Test 2: Vérifier Recording Rules

```promql
# Query dans Prometheus
dreamscape:service:uptime_24h

# Résultat attendu : Valeurs entre 99-100% pour chaque service
```

### Test 3: Simuler Downtime

```bash
# Arrêter un service
kubectl scale deployment auth-service --replicas=0 -n dreamscape-dev

# Attendre 2-3 minutes

# Vérifier dans Prometheus
dreamscape:service:health_status{service="auth"}
# Devrait être 0

# Vérifier l'alerte
# Prometheus > Alerts > ServiceUnhealthy
# Devrait être FIRING pour auth

# Restaurer
kubectl scale deployment auth-service --replicas=2 -n dreamscape-dev
```

### Test 4: Dashboard Grafana

1. Ouvrir dashboard Availability
2. Sélectionner service = "auth"
3. Vérifier :
   - ✅ Platform Health affiche une valeur
   - ✅ Service Uptime montre une courbe
   - ✅ SLA Table affiche des données
   - ✅ MTTR/MTBF ont des valeurs
   - ✅ Dependencies sont UP/DOWN

### Test 5: Alertes Slack/Email

```bash
# Vérifier AlertManager config
kubectl get configmap alertmanager-dreamscape-prometheus -n monitoring -o yaml

# Tester webhook Slack
curl -X POST <SLACK_WEBHOOK_URL> \
  -H 'Content-Type: application/json' \
  -d '{"text":"Test alert from DreamScape monitoring"}'
```

---

## 📚 Documentation Complémentaire

### Calcul SLA

**Formule Uptime** :
```
Uptime % = (Total Time - Downtime) / Total Time × 100
```

**SLA Targets** :
- 🟢 **99.9%** (Three Nines) = 43.2 min downtime/month
- 🟡 **99.5%** (Two Nines Five) = 3.6 hours downtime/month
- 🔴 **99.0%** (Two Nines) = 7.2 hours downtime/month

**Composite SLA Score** :
```
SLA Score = (0.7 × Uptime %) + (0.3 × Request Success Rate %)
```

### MTTR vs MTBF

**MTTR (Mean Time To Recovery)** :
- Temps moyen pour récupérer d'un incident
- **Formule** : Total Downtime / Number of Incidents
- **Target** : < 10 minutes

**MTBF (Mean Time Between Failures)** :
- Temps moyen entre deux pannes
- **Formule** : Uptime / Number of Incidents
- **Target** : > 168 hours (1 week)

---

## 🔧 Troubleshooting

### Problème : Pas de données dans dashboard

**Cause** : Prometheus ne scrape pas les /health endpoints

**Solution** :
```bash
# Vérifier targets Prometheus
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.job | contains("health"))'

# Si vide, vérifier que services exposent /health
curl http://auth-service:3001/health
curl http://user-service:3002/health

# Recharger Prometheus config
kubectl rollout restart deployment dreamscape-prometheus -n monitoring
```

### Problème : Recording rules pas calculées

**Cause** : Rules mal formatées ou Prometheus pas rechargé

**Solution** :
```bash
# Vérifier règles dans Prometheus
curl http://localhost:9090/api/v1/rules | jq '.data.groups[] | select(.name | contains("sla"))'

# Recharger rules
kubectl delete prometheusrules dreamscape-sla-recording-rules -n monitoring
kubectl apply -f monitoring/prometheus/recording-rules-sla.yaml
```

### Problème : Alertes pas envoyées

**Cause** : AlertManager config Slack/Email incorrecte

**Solution** :
```bash
# Vérifier config AlertManager
kubectl get secret alertmanager-dreamscape-prometheus -n monitoring -o yaml

# Vérifier logs AlertManager
kubectl logs -n monitoring deployment/alertmanager-dreamscape-prometheus

# Tester alerte manuellement
curl -X POST http://localhost:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"TestAlert","severity":"warning"},"annotations":{"summary":"Test"}}]'
```

---

## ✅ Validation Finale

### Checklist Déploiement

```
☐ Recording rules déployées (kubectl get prometheusrules)
☐ Alertes availability déployées
☐ Prometheus scrape health endpoints (vérifier targets)
☐ Dashboard Grafana importé et fonctionnel
☐ Alertes Slack configurées et testées
☐ Alertes Email configurées
☐ Recording rules calculées (vérifier métriques dreamscape:service:uptime_*)
☐ Test downtime simulé (scale to 0 puis restaurer)
☐ MTTR < 10 min pour récupération
☐ SLA > 99.9% sur tous les services
```

### Métriques à Monitorer

1. **Uptime** : `dreamscape:service:uptime_30d` > 99.9%
2. **MTTR** : `dreamscape:service:mttr_seconds_24h` < 600s
3. **MTBF** : `dreamscape:service:mtbf_hours_7d` > 168h
4. **Incidents** : `dreamscape:service:downtime_incidents_7d` < 5

---

## 📞 Support

**Équipe** : Platform / SRE
**Runbooks** : https://docs.dreamscape.com/runbooks/
**Grafana** : https://grafana.dreamscape.com
**Prometheus** : https://prometheus.dreamscape.com

---

## 🎯 Next Steps (INFRA-013.3+)

- [ ] Monitoring des coûts cloud
- [ ] Alertes prédictives (ML-based)
- [ ] Auto-scaling basé sur SLA
- [ ] Incident post-mortems automatiques
- [ ] SLA reporting mensuel automatique

---

**Document Version**: 1.0
**Last Updated**: 2025-11-28
**Status**: ✅ Production Ready
