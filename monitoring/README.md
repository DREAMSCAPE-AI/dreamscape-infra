# Monitoring — Observabilité DreamScape

> **Stack d'observabilité** — Prometheus, Grafana, Alertmanager, Loki et Promtail

## Stack

| Outil | Rôle | Port |
|-------|------|------|
| Prometheus | Collecte et stockage des métriques | 9090 |
| Grafana | Dashboards et visualisation | 3000 |
| Alertmanager | Gestion et routage des alertes | 9093 |
| Loki | Agrégation des logs | 3100 |
| Promtail | Agent de collecte de logs | — |
| kafka-jmx | Métriques JMX Kafka | — |

## Structure

```
monitoring/
├── prometheus.yml                    # Config principale Prometheus
├── alertmanager.yml                  # Config Alertmanager (routing, receivers)
├── loki.yml                          # Config Loki (logs)
├── promtail.yml                      # Config Promtail (agent logs)
├── kafka-jmx-config.yml              # Métriques JMX Kafka
├── requirements.txt                  # Dépendances Python (scripts)
├── MONITORING_WORKFLOW_PROCEDURES.md # Procédures opérationnelles
├── database-migration-monitor.py     # Monitoring migrations DB
├── dreamscape-repository-monitor.sh  # Monitoring des repos
├── prometheus/
│   ├── alerts.yaml                   # Règles d'alerte principales
│   ├── alerts-availability.yaml      # Alertes disponibilité
│   ├── health-probes.yaml            # Sondes de santé
│   ├── recording-rules-sla.yaml      # Règles SLA
│   └── values.yaml
├── grafana/
│   ├── datasources.yml               # Sources de données Grafana
│   ├── dashboard-overview.json       # Dashboard vue d'ensemble
│   ├── dashboard-availability.json   # Dashboard disponibilité
│   └── dashboards/
│       └── kafka-monitoring.json     # Dashboard Kafka
├── config/
│   └── monitoring-config.json
└── rules/
    └── kafka-alerts.yaml             # Règles d'alerte Kafka
```

## Cibles Prometheus

Les services DreamScape exposent leurs métriques sur `/metrics` :

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'dreamscape-services'
    static_configs:
      - targets:
        - 'auth-service:3001'
        - 'user-service:3002'
        - 'voyage-service:3003'
        - 'payment-service:3004'
        - 'ai-service:3005'
        - 'gateway:4000'
    metrics_path: /metrics
    scrape_interval: 15s
```

## Dashboards Grafana

| Dashboard | Description |
|-----------|-------------|
| `dashboard-overview.json` | Vue globale : latences, taux d'erreur, throughput |
| `dashboard-availability.json` | Disponibilité et SLA par service |
| `kafka-monitoring.json` | Topics Kafka, lag consommateurs, throughput |

### Importer les dashboards

```bash
# Via l'API Grafana
curl -X POST http://localhost:3000/api/dashboards/import \
  -H "Content-Type: application/json" \
  -d @grafana/dashboard-overview.json
```

## Alertes

### Alertes critiques
| Alerte | Condition | Sévérité |
|--------|-----------|----------|
| `HighErrorRate` | Taux erreur 5xx > 10% sur 5min | critical |
| `ServiceDown` | Service health check KO | critical |
| `DatabaseConnectionFailed` | Connexion DB perdue | critical |
| `KafkaLagHigh` | Lag consommateur > 1000 messages | warning |

### Alertes SLA
| Alerte | Condition |
|--------|-----------|
| `SLABreach` | Disponibilité < 99.9% sur 1h |
| `LatencyP99High` | P99 > 500ms sur 10min |

## Alertmanager

```yaml
# alertmanager.yml — Configuration de routing
route:
  group_by: ['alertname', 'service']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 12h
  receiver: 'team-slack'

receivers:
  - name: 'team-slack'
    slack_configs:
      - channel: '#alerts-dreamscape'
        send_resolved: true
```

## Logs (Loki + Promtail)

Promtail collecte les logs de tous les containers Docker et les envoie à Loki.

```bash
# Requête Loki pour les erreurs auth-service
{app="auth-service"} |= "ERROR"

# Logs payment webhook
{app="payment-service"} |= "webhook" | json
```

## Démarrage local

```bash
# Depuis dreamscape-infra/
docker-compose -f docker/docker-compose.monitoring.yml up -d

# Accès
# Grafana    : http://localhost:3000 (admin/admin)
# Prometheus : http://localhost:9090
# Alertmanager : http://localhost:9093
```

## Procédures opérationnelles

Voir `MONITORING_WORKFLOW_PROCEDURES.md` pour les runbooks détaillés :
- Procédure d'escalade lors d'alertes critiques
- Investigation des pics de latence
- Monitoring des migrations DB
- Gestion des incidents Kafka

---

*Voir `dreamscape-infra/README.md` pour l'architecture globale.*
