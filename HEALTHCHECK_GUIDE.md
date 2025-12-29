# Guide Complet des Commandes - DREAMSCAPE-AI

## 🐳 Commandes Docker

### Démarrer tous les services en Docker

```bash
cd dreamscape-infra/docker
docker-compose -f docker-compose.bigpods.dev.yml up -d
```

### Vérifier l'état des conteneurs

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Arrêter tous les services

```bash
cd dreamscape-infra/docker
docker-compose -f docker-compose.bigpods.dev.yml down
```

### Redémarrer un pod spécifique

```bash
cd dreamscape-infra/docker

# Redémarrer le core-pod (Auth + User)
docker-compose -f docker-compose.bigpods.dev.yml restart core-pod

# Redémarrer le business-pod (Voyage + AI + Payment)
docker-compose -f docker-compose.bigpods.dev.yml restart business-pod

# Redémarrer l'experience-pod (Gateway + Web + Panorama)
docker-compose -f docker-compose.bigpods.dev.yml restart experience-pod
```

### Recréer un pod (après modification du docker-compose)

```bash
cd dreamscape-infra/docker

# Recréer l'experience-pod
docker-compose -f docker-compose.bigpods.dev.yml up -d --force-recreate experience-pod

# Recréer tous les pods
docker-compose -f docker-compose.bigpods.dev.yml up -d --force-recreate
```

### Voir les logs

```bash
# Logs d'un conteneur spécifique
docker logs dreamscape-core-pod
docker logs dreamscape-business-pod
docker logs dreamscape-experience-pod

# Suivre les logs en temps réel
docker logs -f dreamscape-core-pod

# Logs des 50 dernières lignes
docker logs --tail 50 dreamscape-business-pod

# Logs avec grep pour filtrer
docker logs dreamscape-business-pod 2>&1 | grep -i error
```

### Exécuter des commandes dans un conteneur

```bash
# Ouvrir un shell dans un conteneur
docker exec -it dreamscape-core-pod sh

# Exécuter une commande directement
docker exec dreamscape-core-pod ps aux
docker exec dreamscape-business-pod env | grep REDIS
docker exec dreamscape-experience-pod curl -s http://localhost:4000/health
```

### Vérifier les logs supervisor (dans un conteneur)

```bash
# Auth service
docker exec dreamscape-core-pod tail -50 /var/log/supervisor/auth-stderr.log

# Voyage service
docker exec dreamscape-business-pod tail -50 /var/log/supervisor/voyage-stderr.log

# Gateway service
docker exec dreamscape-experience-pod tail -50 /var/log/supervisor/gateway-stderr.log
```

---

## 🧪 Tester les Services

### Tester tous les endpoints de santé

```bash
# Auth Service (3001)
curl -s http://localhost:3001/health | jq
curl -s http://localhost:3001/api/health | jq
curl -s http://localhost:3001/health/live | jq
curl -s http://localhost:3001/health/ready | jq
curl -s http://localhost:3001/metrics

# User Service (3002)
curl -s http://localhost:3002/health | jq
curl -s http://localhost:3002/api/health | jq
curl -s http://localhost:3002/health/live | jq
curl -s http://localhost:3002/health/ready | jq
curl -s http://localhost:3002/metrics

# Voyage Service (3003)
curl -s http://localhost:3003/health | jq
curl -s http://localhost:3003/api/health | jq
curl -s http://localhost:3003/health/live | jq
curl -s http://localhost:3003/health/ready | jq
curl -s http://localhost:3003/metrics

# AI Service (3004)
curl -s http://localhost:3004/health | jq
curl -s http://localhost:3004/api/health | jq
curl -s http://localhost:3004/health/live | jq
curl -s http://localhost:3004/health/ready | jq
curl -s http://localhost:3004/metrics

# Gateway Service (3000)
curl -s http://localhost:3000/health | jq
curl -s http://localhost:3000/api/health | jq
curl -s http://localhost:3000/health/live | jq
curl -s http://localhost:3000/health/ready | jq
curl -s http://localhost:3000/metrics
```

### Test rapide de tous les services

```bash
echo "Auth:" && curl -s http://localhost:3001/health | jq -r '.service' && \
echo "User:" && curl -s http://localhost:3002/health | jq -r '.service' && \
echo "Voyage:" && curl -s http://localhost:3003/health | jq -r '.service' && \
echo "AI:" && curl -s http://localhost:3004/health | jq -r '.service' && \
echo "Gateway:" && curl -s http://localhost:3000/health | jq -r '.service'
```

---

## 🧪 Lancer les Tests d'Intégration

### Tests de santé pour tous les services

```bash
cd dreamscape-tests
npx jest --config=jest.config.realdb.js integration/health/all-services-health-real.test.ts
```

### Lancer tous les tests d'intégration

```bash
cd dreamscape-tests
npx jest --config=jest.config.realdb.js
```

### Lancer un test spécifique avec verbose

```bash
cd dreamscape-tests
npx jest --config=jest.config.realdb.js integration/health/all-services-health-real.test.ts --verbose
```

---

## 💻 Développement Local (sans Docker)

### Démarrer seulement l'infrastructure (PostgreSQL + Redis)

```bash
cd dreamscape-infra/docker
docker-compose -f docker-compose.bigpods.dev.yml up -d postgres redis
```

### Démarrer les services localement (5 terminaux)

**Terminal 1 - Auth Service:**
```bash
cd dreamscape-services/auth
npm run dev
```

**Terminal 2 - User Service:**
```bash
cd dreamscape-services/user
npm run dev
```

**Terminal 3 - Voyage Service:**
```bash
cd dreamscape-services/voyage
npm run dev
```

**Terminal 4 - AI Service:**
```bash
cd dreamscape-services/ai
npm run dev
```

**Terminal 5 - Gateway:**
```bash
cd dreamscape-frontend/gateway
npm run dev
```

### Arrêter les services locaux

```bash
# Dans chaque terminal, appuyez sur Ctrl+C

# Ou trouvez et tuez les processus
netstat -ano | findstr ":3001 :3002 :3003 :3004 :3000" | findstr "LISTENING"
# Puis utilisez taskkill avec les PIDs trouvés
```

---

## 🗄️ Commandes Base de Données

### Accéder à PostgreSQL

```bash
# Via Docker
docker exec -it dreamscape-postgres psql -U dev -d dreamscape_dev

# Commandes SQL utiles
\dt                    # Lister les tables
\d table_name          # Décrire une table
SELECT * FROM users;   # Requête
\q                     # Quitter
```

### Migrations

```bash
# Dans un service spécifique (exemple: auth)
cd dreamscape-services/auth
npm run migrate

# Créer une nouvelle migration
npm run migrate:create nom_de_la_migration
```

---

## 🔧 Commandes de Débogage

### Vérifier les ports en écoute

```bash
# Windows
netstat -ano | findstr "LISTENING"

# Linux/Mac
netstat -tuln | grep LISTEN
```

### Vérifier quel processus utilise un port

```bash
# Windows
netstat -ano | findstr ":3001"

# Obtenir le nom du processus
tasklist | findstr "PID_NUMBER"
```

### Tuer un processus sur un port

```bash
# Windows
taskkill /F /PID <PID_NUMBER>

# Linux/Mac
kill -9 <PID_NUMBER>
```

### Vérifier la connectivité réseau Docker

```bash
# Ping entre conteneurs
docker exec dreamscape-experience-pod ping -c 3 core-pod
docker exec dreamscape-experience-pod ping -c 3 business-pod

# Tester la résolution DNS
docker exec dreamscape-experience-pod nslookup redis
```

---

## 🚀 Workflow Complet de Démarrage

### Option A: Tout en Docker (Recommandé)

```bash
# 1. Démarrer tous les services
cd dreamscape-infra/docker
docker-compose -f docker-compose.bigpods.dev.yml up -d

# 2. Attendre 30-45 secondes que tout démarre
sleep 45

# 3. Vérifier que tous les services fonctionnent
echo "Auth:" && curl -s http://localhost:3001/health | jq -r '.service' && \
echo "User:" && curl -s http://localhost:3002/health | jq -r '.service' && \
echo "Voyage:" && curl -s http://localhost:3003/health | jq -r '.service' && \
echo "AI:" && curl -s http://localhost:3004/health | jq -r '.service' && \
echo "Gateway:" && curl -s http://localhost:3000/health | jq -r '.service'

# 4. Lancer les tests
cd ../../dreamscape-tests
npx jest --config=jest.config.realdb.js integration/health/all-services-health-real.test.ts
```

### Option B: Infrastructure Docker + Services Locaux

```bash
# 1. Démarrer seulement l'infrastructure
cd dreamscape-infra/docker
docker-compose -f docker-compose.bigpods.dev.yml up -d postgres redis

# 2. Démarrer les services localement (dans 5 terminaux séparés)
# Voir section "Développement Local" ci-dessus

# 3. Attendre 10 secondes
sleep 10

# 4. Tester
cd dreamscape-tests
npx jest --config=jest.config.realdb.js integration/health/all-services-health-real.test.ts
```

---

## 📊 Monitoring

### Health check de tous les services (une ligne)

```bash
for port in 3001 3002 3003 3004 3000; do echo "Port $port:" && curl -s http://localhost:$port/health | jq -r '.status' 2>/dev/null || echo "Failed"; done
```

### Vérifier les métriques Prometheus

```bash
curl -s http://localhost:3001/metrics | grep -E "^# |http_"
```

### Voir l'utilisation des ressources

```bash
docker stats --no-stream
```

---

## 🧹 Nettoyage

### Arrêter et supprimer tous les conteneurs

```bash
cd dreamscape-infra/docker
docker-compose -f docker-compose.bigpods.dev.yml down
```

### Supprimer les volumes (⚠️ Perte de données!)

```bash
cd dreamscape-infra/docker
docker-compose -f docker-compose.bigpods.dev.yml down -v
```

### Nettoyer Docker complètement

```bash
# Supprimer les conteneurs arrêtés
docker container prune -f

# Supprimer les images non utilisées
docker image prune -a -f

# Supprimer les volumes non utilisés
docker volume prune -f

# Tout nettoyer d'un coup (⚠️ Dangereux!)
docker system prune -a -f --volumes
```

---

## 📝 Résumé des Ports

| Service    | Port | Description                    |
|------------|------|--------------------------------|
| Auth       | 3001 | Service d'authentification     |
| User       | 3002 | Service de gestion utilisateur |
| Voyage     | 3003 | Service de voyages (Amadeus)   |
| AI         | 3004 | Service d'IA                   |
| Gateway    | 3000 | API Gateway principal          |
| PostgreSQL | 5432 | Base de données                |
| Redis      | 6379 | Cache                          |
| MinIO      | 9000 | Stockage S3                    |
| Kafka      | 9092 | Message broker                 |

---

## ✅ Checklist de Vérification

```bash
# 1. Docker tourne-t-il ?
docker ps

# 2. Tous les pods sont-ils healthy ?
docker ps --format "table {{.Names}}\t{{.Status}}"

# 3. Les services répondent-ils ?
curl http://localhost:3001/health
curl http://localhost:3002/health
curl http://localhost:3003/health
curl http://localhost:3004/health
curl http://localhost:3000/health

# 4. PostgreSQL est-il accessible ?
docker exec dreamscape-postgres psql -U dev -d dreamscape_dev -c "SELECT 1;"

# 5. Redis est-il accessible ?
docker exec dreamscape-redis redis-cli ping

# 6. Les tests passent-ils ?
cd dreamscape-tests && npx jest --config=jest.config.realdb.js integration/health/all-services-health-real.test.ts
```
