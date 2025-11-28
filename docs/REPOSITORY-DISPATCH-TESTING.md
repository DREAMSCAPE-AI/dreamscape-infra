# 🧪 Repository Dispatch Architecture - Testing Guide

Guide complet pour tester l'architecture Repository Dispatch de DreamScape.

## 🎯 Tests à Effectuer

### 1. Test de Base - Trigger Manuel

#### Via GitHub CLI
```bash
# Test basic dispatch
gh api repos/DREAMSCAPE-AI/dreamscape-infra/dispatches \
  --method POST \
  --field event_type='services-changed' \
  --field client_payload='{"source_repo":"test","component":"all","environment":"dev"}'
```

#### Via curl
```bash
curl -X POST \
  -H "Authorization: token $DISPATCH_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/DREAMSCAPE-AI/dreamscape-infra/dispatches \
  -d '{
    "event_type": "services-changed",
    "client_payload": {
      "source_repo": "DREAMSCAPE-AI/dreamscape-services",
      "ref": "refs/heads/main", 
      "sha": "abc123",
      "component": "auth-service",
      "environment": "dev"
    }
  }'
```

### 2. Test End-to-End par Repository

#### dreamscape-services
```bash
# 1. Clone et setup
git clone https://github.com/DREAMSCAPE-AI/dreamscape-services.git
cd dreamscape-services

# 2. Créer une branch de test
git checkout -b test/dispatch-architecture
echo "console.log('Testing dispatch');" > test-dispatch.js
git add test-dispatch.js
git commit -m "🧪 Test Repository Dispatch architecture"

# 3. Push et observer
git push origin test/dispatch-architecture

# 4. Vérifier que le workflow se lance dans dreamscape-infra
```

#### dreamscape-frontend  
```bash
git clone https://github.com/DREAMSCAPE-AI/dreamscape-frontend.git
cd dreamscape-frontend
git checkout -b test/dispatch-frontend
echo "/* Test dispatch */" > test-dispatch.css
git add test-dispatch.css
git commit -m "🧪 Test Frontend Dispatch"
git push origin test/dispatch-frontend
```

#### dreamscape-tests
```bash
git clone https://github.com/DREAMSCAPE-AI/dreamscape-tests.git
cd dreamscape-tests
git checkout -b test/dispatch-tests
echo "// Test dispatch integration" > test-dispatch.test.js
git add test-dispatch.test.js  
git commit -m "🧪 Test Tests Dispatch"
git push origin test/dispatch-tests
```

### 3. Tests par Scénario

#### Scénario 1: Développement Feature
```bash
# Services: Feature branch → Dev environment
cd dreamscape-services
git checkout -b feature/new-auth-endpoint
# Make changes...
git push origin feature/new-auth-endpoint
# Expected: Central pipeline runs with environment=dev, no deployment
```

#### Scénario 2: Release Staging
```bash
# Services: Develop branch → Staging environment  
cd dreamscape-services
git checkout develop
# Make changes...
git push origin develop
# Expected: Central pipeline runs with environment=staging, deploys to staging
```

#### Scénario 3: Production Deployment
```bash
# Services: Main branch → Production environment
cd dreamscape-services
git checkout main
git merge develop
git push origin main
# Expected: Central pipeline runs with environment=production, deploys to production
```

#### Scénario 4: Hotfix
```bash
# Services: Hotfix branch → Production environment
cd dreamscape-services
git checkout -b hotfix/critical-security-fix
# Make critical changes...
git push origin hotfix/critical-security-fix
# Expected: Central pipeline runs with environment=production
```

## 📊 Validation des Résultats

### 1. Vérifications dans le Repository Source
```bash
# Vérifier que le trigger workflow s'exécute
gh run list --repo DREAMSCAPE-AI/dreamscape-services

# Vérifier le commit status
gh api repos/DREAMSCAPE-AI/dreamscape-services/commits/COMMIT_SHA/status
```

### 2. Vérifications dans dreamscape-infra
```bash
# Vérifier que le central pipeline se lance
gh run list --repo DREAMSCAPE-AI/dreamscape-infra

# Vérifier les logs du pipeline central
gh run view RUN_ID --repo DREAMSCAPE-AI/dreamscape-infra
```

### 3. Vérifications des Artifacts
```bash
# List artifacts créés par le central pipeline
gh api repos/DREAMSCAPE-AI/dreamscape-infra/actions/artifacts

# Download specific artifact
gh run download RUN_ID --repo DREAMSCAPE-AI/dreamscape-infra
```

## 🔍 Monitoring et Debugging

### Logs à Surveiller

#### 1. Repository Source Logs
- ✅ Trigger workflow execution
- ✅ Change detection working  
- ✅ Environment mapping correct
- ✅ Dispatch event sent successfully
- ✅ Commit status updated

#### 2. Central Pipeline Logs  
- ✅ Repository dispatch event received
- ✅ Event parsing successful
- ✅ Source repository cloned
- ✅ Build/test jobs executed
- ✅ Deployment triggered (if applicable)
- ✅ Commit status updated back to source

### Common Issues et Solutions

#### ❌ Dispatch Event Not Received
**Symptom**: Trigger workflow runs but central pipeline doesn't start
**Debug**:
```bash
# Check dispatch events in central repo
gh api repos/DREAMSCAPE-AI/dreamscape-infra/dispatches

# Verify token permissions
curl -H "Authorization: token $DISPATCH_TOKEN" https://api.github.com/user
```

#### ❌ Source Repo Clone Fails
**Symptom**: Central pipeline fails at clone step
**Debug**:
```bash
# Verify DISPATCH_TOKEN can access source repo
gh api repos/DREAMSCAPE-AI/dreamscape-services --header "Authorization: token $DISPATCH_TOKEN"
```

#### ❌ Environment Mapping Wrong
**Symptom**: Wrong environment detected (e.g., dev instead of staging)
**Debug**: Check branch mapping logic in trigger workflow

#### ❌ Build/Test Failures
**Symptom**: Central pipeline fails during build/test phase
**Debug**: 
- Check if source repo structure matches expectations
- Verify package.json and build scripts exist
- Check Docker build context

## 📈 Performance Tests

### 1. Latency Test
Mesurer le délai entre push et start du central pipeline :
```bash
# Push avec timestamp
git commit -m "Test latency $(date +%s)"
git push origin test-branch

# Mesurer délai jusqu'au start du central pipeline
```

### 2. Parallel Processing Test
Tester multiple repos simultanément :
```bash
# Terminal 1: Push to services
cd dreamscape-services && git push origin test-parallel-1

# Terminal 2: Push to frontend  
cd dreamscape-frontend && git push origin test-parallel-2

# Terminal 3: Push to tests
cd dreamscape-tests && git push origin test-parallel-3

# Vérifier que les 3 central pipelines s'exécutent en parallèle
```

### 3. Load Test
Tester multiple pushes rapides :
```bash
for i in {1..5}; do
  git commit --allow-empty -m "Load test $i"
  git push origin test-load
  sleep 2
done
```

## ✅ Test Checklist

### Setup Validation
- [ ] All source repositories have trigger workflows
- [ ] DISPATCH_TOKEN configured in all repositories  
- [ ] Central pipeline workflow exists in dreamscape-infra
- [ ] Oracle Cloud secrets configured

### Functional Tests
- [ ] Services repository triggers central pipeline
- [ ] Frontend repository triggers central pipeline
- [ ] Tests repository triggers central pipeline
- [ ] Docs repository triggers central pipeline (when deployment impact)

### Environment Tests  
- [ ] Feature branches → dev environment
- [ ] Develop branch → staging environment
- [ ] Main branch → production environment
- [ ] Hotfix branches → production environment

### Integration Tests
- [ ] Source repo cloning works
- [ ] Build processes execute correctly
- [ ] Test suites run successfully  
- [ ] Docker images built and pushed
- [ ] Deployment triggers correctly
- [ ] Commit status updates work

### Edge Cases
- [ ] Empty commits handled gracefully
- [ ] Large commits don't break pipeline
- [ ] Network failures handled with retries
- [ ] Permission errors logged clearly
- [ ] Concurrent pushes handled correctly

## 🚀 Automated Testing Script

```bash
#!/bin/bash
# automated-dispatch-test.sh

echo "🧪 Starting Repository Dispatch Architecture Tests..."

# Test 1: Manual dispatch
echo "📡 Test 1: Manual Repository Dispatch"
curl -s -X POST \
  -H "Authorization: token $DISPATCH_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/DREAMSCAPE-AI/dreamscape-infra/dispatches \
  -d '{"event_type":"services-changed","client_payload":{"source_repo":"test","environment":"dev"}}'

if [ $? -eq 0 ]; then
  echo "✅ Manual dispatch successful"
else
  echo "❌ Manual dispatch failed"
  exit 1
fi

# Test 2: Check workflow exists
echo "🔍 Test 2: Verify Central Workflow Exists"
if gh api repos/DREAMSCAPE-AI/dreamscape-infra/contents/.github/workflows/central-dispatch.yml > /dev/null 2>&1; then
  echo "✅ Central workflow exists"
else
  echo "❌ Central workflow not found"
  exit 1
fi

# Test 3: Check recent runs
echo "📊 Test 3: Check Recent Pipeline Runs"
RECENT_RUNS=$(gh run list --repo DREAMSCAPE-AI/dreamscape-infra --limit 5 --json status,conclusion,workflowName)
echo "$RECENT_RUNS"

echo "🎉 All tests completed!"
```

## 📝 Test Reports

Générer un rapport de test :
```bash
# Generate test report
cat > dispatch-test-report.md << EOF
# Repository Dispatch Test Report

**Date**: $(date)
**Tester**: $(git config user.name)

## Test Results

| Test | Status | Notes |
|------|---------|-------|
| Manual Dispatch | ✅/❌ | |
| Services Trigger | ✅/❌ | |
| Frontend Trigger | ✅/❌ | |
| Tests Trigger | ✅/❌ | |
| Environment Mapping | ✅/❌ | |
| Build Process | ✅/❌ | |
| Deployment | ✅/❌ | |

## Issues Found
- [ ] Issue 1: Description
- [ ] Issue 2: Description

## Recommendations
- Recommendation 1
- Recommendation 2
EOF
```

🚀 **L'architecture Repository Dispatch est maintenant prête pour les tests !**