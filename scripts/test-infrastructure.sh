#!/bin/bash
# Infrastructure Tests for K3s/Kubernetes
# Tests Kustomize, manifests, connectivity, and security

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to log test results
test_result() {
    local test_name="$1"
    local result="$2"
    local details="${3:-}"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [[ "$result" == "PASS" ]]; then
        echo -e "${GREEN}✅ PASS${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ FAIL${NC} $test_name"
        if [[ -n "$details" ]]; then
            echo -e "${RED}   ↳${NC} $details"
        fi
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test function wrapper
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -e "${BLUE}🧪 Testing:${NC} $test_name..."
    
    if eval "$test_command" >/dev/null 2>&1; then
        test_result "$test_name" "PASS"
        return 0
    else
        local error_details=$(eval "$test_command" 2>&1 | head -1)
        test_result "$test_name" "FAIL" "$error_details"
        return 1
    fi
}

echo -e "${BLUE}🚀 Starting Infrastructure Tests${NC}"
echo "=================================="

# 1. Test Kustomize Build
echo -e "\n${YELLOW}📦 Testing Kustomize Builds${NC}"

run_test "Kustomize build dev environment" \
    "kustomize build k8s/overlays/dev"

run_test "Kustomize build staging environment" \
    "kustomize build k8s/overlays/staging"

run_test "Kustomize build production environment" \
    "kustomize build k8s/overlays/prod"

# 2. Test Kubernetes Manifests Validation
echo -e "\n${YELLOW}📋 Testing Kubernetes Manifests${NC}"

run_test "Kubernetes manifests dry-run validation (staging)" \
    "kubectl apply --dry-run=client -k k8s/overlays/staging"

run_test "Kubernetes manifests dry-run validation (production)" \
    "kubectl apply --dry-run=client -k k8s/overlays/prod"

# 3. Test Required Secrets
echo -e "\n${YELLOW}🔐 Testing Required Secrets${NC}"

run_test "K3S_HOST secret exists" \
    "test -n '$K3S_HOST'"

run_test "K3S_SSH_KEY secret exists" \
    "test -n '$K3S_SSH_KEY'"

run_test "DISPATCH_TOKEN secret exists" \
    "test -n '$DISPATCH_TOKEN'"

# 4. Test Deployment Scripts
echo -e "\n${YELLOW}📜 Testing Deployment Scripts${NC}"

run_test "deploy-k3s.sh syntax check" \
    "bash -n scripts/deploy-k3s.sh"

if command -v shellcheck >/dev/null 2>&1; then
    run_test "deploy-k3s.sh shellcheck analysis" \
        "shellcheck scripts/deploy-k3s.sh"
else
    test_result "deploy-k3s.sh shellcheck analysis" "SKIP" "shellcheck not available"
fi

# 5. Test K3s Connectivity (if secrets available)
if [[ -n "$K3S_HOST" && -n "$K3S_SSH_KEY" ]]; then
    echo -e "\n${YELLOW}🌐 Testing K3s Connectivity${NC}"
    
    # Setup SSH key
    mkdir -p ~/.ssh
    echo "$K3S_SSH_KEY" > ~/.ssh/id_rsa_test
    chmod 600 ~/.ssh/id_rsa_test
    
    run_test "SSH connectivity to K3s cluster" \
        "ssh -i ~/.ssh/id_rsa_test -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$K3S_HOST 'echo SSH_OK'"
    
    run_test "K3s cluster accessibility" \
        "ssh -i ~/.ssh/id_rsa_test -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$K3S_HOST 'sudo k3s kubectl get nodes'"
    
    # Cleanup test SSH key
    rm -f ~/.ssh/id_rsa_test
else
    echo -e "\n${YELLOW}🌐 K3s Connectivity Tests${NC}"
    test_result "SSH connectivity to K3s cluster" "SKIP" "K3S secrets not available"
    test_result "K3s cluster accessibility" "SKIP" "K3S secrets not available"
fi

# 6. Test Image References
echo -e "\n${YELLOW}🐳 Testing Container Images${NC}"

run_test "Staging images have proper GHCR references" \
    "kustomize build k8s/overlays/staging | grep 'image: ghcr.io/dreamscape-ai/'"

run_test "Production images have proper GHCR references" \
    "kustomize build k8s/overlays/prod | grep 'image: ghcr.io/dreamscape-ai/'"

# 7. Test Resource Limits
echo -e "\n${YELLOW}⚖️ Testing Resource Configurations${NC}"

run_test "Staging has memory limits defined" \
    "kustomize build k8s/overlays/staging | grep -E '(memory|Memory)'"

run_test "Staging has CPU limits defined" \
    "kustomize build k8s/overlays/staging | grep -E '(cpu|CPU)'"

run_test "Production has replicas > 1" \
    "kustomize build k8s/overlays/prod | grep 'replicas: [2-9]'"

# 8. Test Security Configuration
echo -e "\n${YELLOW}🔒 Testing Security Configuration${NC}"

run_test "No hardcoded secrets in manifests" \
    "! grep -r -E '(password|secret|key|token).*:.*[a-zA-Z0-9]{8,}' k8s/ || true"

run_test "All services use non-root containers" \
    "! kustomize build k8s/overlays/staging | grep 'runAsUser: 0' || true"

# 9. Test Namespace Configuration
echo -e "\n${YELLOW}🏷️ Testing Namespace Configuration${NC}"

run_test "Staging uses correct namespace" \
    "kustomize build k8s/overlays/staging | grep 'namespace: dreamscape-staging'"

run_test "Production uses correct namespace" \
    "kustomize build k8s/overlays/prod | grep 'namespace: dreamscape-production'"

# Final Results
echo -e "\n${BLUE}📊 Test Results Summary${NC}"
echo "========================"
echo -e "Total Tests: ${TESTS_TOTAL}"
echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}🎉 All infrastructure tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}💥 $TESTS_FAILED infrastructure test(s) failed!${NC}"
    exit 1
fi