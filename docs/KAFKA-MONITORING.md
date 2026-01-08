# Kafka Monitoring - DreamScape
**DR-260**: US-INFRA-009 - Monitoring Kafka

## Vue d'ensemble

Ce document décrit l'implémentation complète du monitoring Kafka pour la plateforme DreamScape, incluant la collecte de métriques, la visualisation via Grafana, et les alertes automatiques.

## Architecture de Monitoring

### Composants

1. **Kafka Exporter** (port 9308)
   - Collecte les métriques des consumer groups, lag, topics
   - Image: `danielqsj/kafka-exporter:latest`
   - Scrape interval: 30s

2. **Kafka JMX Exporter** (port 5556)
   - Collecte les métriques JMX des brokers Kafka
   - Throughput, latence, partitions, réplication
   - Image: `bitnami/jmx-exporter:latest`

3. **Prometheus** (port 9090)
   - Collecte et stockage des métriques
   - Évaluation des règles d'alertes
   - Rétention: 15 jours

4. **Grafana** (port 3000)
   - Visualisation des métriques Kafka
   - Dashboards interactifs
   - Default credentials: admin/admin

5. **AlertManager** (port 9093)
   - Gestion et routage des alertes
   - Notifications configurables

## Démarrage

### Prérequis

- Docker et Docker Compose installés
- Kafka démarré sur le réseau `dreamscape-network`
- Ports 9090, 3000, 9093, 9308, 5556 disponibles

### Lancement du Stack Monitoring

```bash
# Depuis le répertoire dreamscape-infra/docker
docker-compose -f docker-compose.monitoring.yml up -d

# Vérifier le statut des conteneurs
docker-compose -f docker-compose.monitoring.yml ps

# Voir les logs
docker-compose -f docker-compose.monitoring.yml logs -f kafka-exporter
docker-compose -f docker-compose.monitoring.yml logs -f kafka-jmx-exporter
```

### Accès aux Services

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/admin)
- **AlertManager**: http://localhost:9093
- **Kafka Exporter Metrics**: http://localhost:9308/metrics
- **Kafka JMX Metrics**: http://localhost:5556/metrics

## Métriques Collectées (DR-261)

### Métriques Consumer Groups

| Métrique | Description | Alerte |
|----------|-------------|--------|
| `kafka_consumergroup_lag` | Lag par consumer group et topic | > 1000 (Warning), > 10000 (Critical) |
| `kafka_consumergroup_current_offset` | Offset actuel du consumer | - |
| `kafka_consumergroup_offset` | Offset du consumer group | - |

### Métriques Broker

| Métrique | Description | Alerte |
|----------|-------------|--------|
| `kafka_server_brokertopicmetrics_messagesin_total` | Messages entrants par broker | < 1 msg/sec pendant 15min (Info) |
| `kafka_server_brokertopicmetrics_bytesi_total` | Bytes entrants | - |
| `kafka_server_brokertopicmetrics_bytesout_total` | Bytes sortants | - |
| `kafka_server_replicamanager_underreplicatedpartitions` | Partitions sous-répliquées | > 0 pendant 5min (Warning) |
| `kafka_controller_kafkacontroller_offlinepartitionscount` | Partitions offline | > 0 pendant 1min (Critical) |

### Métriques Requêtes

| Métrique | Description | Alerte |
|----------|-------------|--------|
| `kafka_network_requestmetrics_requests_total` | Total des requêtes par type | > 1000 req/sec pendant 10min (Warning) |
| `kafka_network_requestmetrics_99percentile` | Latence P99 des requêtes | - |
| `kafka_network_requestmetrics_totaltimems` | Temps total des requêtes | - |

### Métriques Réplication

| Métrique | Description | Alerte |
|----------|-------------|--------|
| `kafka_server_replicamanager_isrshrinks_total` | ISR shrinks | > 0 pendant 5min (Warning) |
| `kafka_server_replicamanager_isrexpands_total` | ISR expands | - |

## Dashboards Grafana (DR-262)

### Dashboard: Kafka Monitoring - DreamScape

**UID**: `kafka-monitoring-dreamscape`
**Fichier**: `monitoring/grafana/dashboards/kafka-monitoring.json`

#### Panneaux

1. **Kafka Broker Status**
   - Type: Stat
   - Affiche si les exporters Kafka sont up
   - Couleur: vert (up) / rouge (down)

2. **Kafka Throughput - Messages In**
   - Type: Time series
   - Messages entrants par seconde par broker
   - Changement d'offset par topic

3. **Consumer Lag by Group and Topic**
   - Type: Table
   - Lag détaillé par consumer group, topic, partition
   - Tri par lag descendant
   - Couleurs: vert (<1000), jaune (1000-10000), rouge (>10000)

4. **Under-Replicated Partitions**
   - Type: Stat
   - Nombre de partitions sous-répliquées
   - Alerte visuelle si > 0

5. **Offline Partitions**
   - Type: Stat
   - Nombre de partitions offline
   - Alerte critique si > 0

6. **Request Rate by Type**
   - Type: Time series
   - Taux de requêtes par type (Produce, Fetch, etc.)
   - Moyenne par type

7. **Request Latency (P99)**
   - Type: Time series
   - Latence P99 pour Produce et Fetch
   - Par broker

### Import du Dashboard

```bash
# Le dashboard est automatiquement provisionné via:
# monitoring/grafana/provisioning/dashboards/dashboards.yml
```

Ou manuellement:
1. Aller sur Grafana (http://localhost:3000)
2. Dashboards > Import
3. Copier le contenu de `kafka-monitoring.json`
4. Cliquer sur "Load"

## Alertes Kafka (DR-263)

**Fichier**: `monitoring/rules/kafka-alerts.yaml`

### Groupes d'Alertes

#### 1. Kafka Availability

| Alerte | Sévérité | Condition | Durée | Action |
|--------|----------|-----------|-------|--------|
| **KafkaBrokerDown** | Critical | `up{job="kafka-exporter"} == 0` | 2min | Vérifier le broker Kafka et le réseau |
| **KafkaJMXExporterDown** | Warning | `up{job="kafka-jmx"} == 0` | 2min | Vérifier JMX exporter, métriques broker indisponibles |

#### 2. Kafka Performance

| Alerte | Sévérité | Condition | Durée | Impact | Action |
|--------|----------|-----------|-------|--------|--------|
| **KafkaConsumerLagHigh** | Warning | `lag > 1000` | 5min | Délais dans le traitement des événements | Vérifier la santé des consumers, scaler si besoin |
| **KafkaConsumerLagCritical** | Critical | `lag > 10000` | 5min | Délais sévères, risque de perte de données | ACTION IMMÉDIATE: Scaler consumers |
| **KafkaUnderReplicatedPartitions** | Warning | `underreplicated > 0` | 5min | Risque de perte de données si broker fail | Vérifier réseau, performances broker |
| **KafkaOfflinePartitions** | Critical | `offline > 0` | 1min | Topics indisponibles, prod/conso bloquée | ACTION IMMÉDIATE: Redémarrer brokers |

#### 3. Kafka Throughput

| Alerte | Sévérité | Condition | Durée | Impact |
|--------|----------|-----------|-------|--------|
| **KafkaHighRequestRate** | Warning | `requests > 1000/sec` | 10min | Charge élevée, latence possible |
| **KafkaLowMessagesInRate** | Info | `messages < 1/sec` | 15min | Problème producteurs ou trafic faible attendu |

#### 4. Kafka Errors

| Alerte | Sévérité | Condition | Durée | Impact |
|--------|----------|-----------|-------|--------|
| **KafkaFailedProduceRequests** | Warning | `failed_requests > 0` | 5min | Messages peuvent échouer à être écrits |
| **KafkaISRShrinks** | Warning | `isr_shrinks > 0` | 5min | Replicas en retard, tolérance aux pannes réduite |

#### 5. Kafka Disk

| Alerte | Sévérité | Condition | Durée | Impact | Action |
|--------|----------|-----------|-------|--------|--------|
| **KafkaDiskUsageHigh** | Warning | `usage > 80%` | 5min | Risque de manquer d'espace disque | Augmenter fréquence cleanup, réduire rétention |
| **KafkaDiskUsageCritical** | Critical | `usage > 95%` | 2min | ÉCHEC IMMINENT: Kafka arrêtera d'accepter messages | ACTION IMMÉDIATE: Libérer espace disque |

### Configuration des Notifications

Modifier `monitoring/alertmanager.yml` pour configurer les destinations:

```yaml
route:
  receiver: 'default-receiver'
  group_by: ['alertname', 'severity', 'component']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h

receivers:
  - name: 'default-receiver'
    email_configs:
      - to: 'ops@dreamscape.ai'
        from: 'alertmanager@dreamscape.ai'
        smarthost: 'smtp.example.com:587'
        auth_username: 'alertmanager'
        auth_password: '${SMTP_PASSWORD}'
    slack_configs:
      - api_url: '${SLACK_WEBHOOK_URL}'
        channel: '#kafka-alerts'
        title: 'Kafka Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

## Maintenance

### Vérification de la Santé

```bash
# Vérifier que Prometheus scrape les métriques Kafka
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | contains("kafka"))'

# Vérifier les métriques Kafka exporter
curl http://localhost:9308/metrics | grep kafka_consumergroup_lag

# Vérifier les métriques JMX
curl http://localhost:5556/metrics | grep kafka_server

# Vérifier les alertes actives
curl http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.labels.component=="kafka")'
```

### Logs

```bash
# Logs Kafka exporter
docker logs -f dreamscape-kafka-exporter

# Logs JMX exporter
docker logs -f dreamscape-kafka-jmx-exporter

# Logs Prometheus
docker logs -f dreamscape-prometheus

# Logs AlertManager
docker logs -f dreamscape-alertmanager
```

### Troubleshooting

#### Kafka Exporter ne collecte pas de métriques

1. Vérifier que Kafka est accessible sur `kafka:9092`
2. Vérifier que le réseau `dreamscape-network` est partagé
3. Vérifier les logs: `docker logs dreamscape-kafka-exporter`

```bash
# Tester la connectivité
docker exec dreamscape-kafka-exporter nc -zv kafka 9092
```

#### JMX Exporter ne retourne pas de métriques

1. Vérifier que Kafka JMX est activé
2. Vérifier la configuration JMX: `monitoring/kafka-jmx-config.yml`
3. Tester l'accès aux métriques: `curl http://localhost:5556/metrics`

#### Prometheus ne scrape pas Kafka

1. Vérifier la config Prometheus: `monitoring/prometheus.yml`
2. Vérifier les targets dans Prometheus UI: http://localhost:9090/targets
3. Chercher "kafka" dans les jobs
4. Vérifier les erreurs de scrape

#### Grafana n'affiche pas de données

1. Vérifier la datasource Prometheus dans Grafana
2. Configuration > Data Sources > Prometheus
3. URL: `http://prometheus:9090`
4. Tester la connexion
5. Vérifier que les requêtes dans le dashboard retournent des données

## Références

- [Kafka Exporter Documentation](https://github.com/danielqsj/kafka_exporter)
- [JMX Exporter Documentation](https://github.com/prometheus/jmx_exporter)
- [Prometheus Kafka Monitoring Best Practices](https://prometheus.io/docs/instrumenting/exporters/)
- [Grafana Kafka Dashboard Examples](https://grafana.com/grafana/dashboards/?search=kafka)

## Tickets Jira

- **DR-260**: US-INFRA-009 - Monitoring Kafka (Epic)
- **DR-261**: INFRA-009.1 - Exposition des métriques Kafka
- **DR-262**: INFRA-009.2 - Dashboards Kafka
- **DR-263**: INFRA-009.3 - Alertes Kafka

---

**Dernière mise à jour**: 2025-12-18
**Version**: 1.0
**Auteur**: DreamScape DevOps Team
