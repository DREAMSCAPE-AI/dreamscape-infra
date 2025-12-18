#!/bin/bash
# Kafka Monitoring Stack Validation Script
# DR-260: Validates all monitoring components are running and collecting metrics
#
# Usage: ./validate-kafka-monitoring.sh

set -e

echo "=================================================="
echo "Kafka Monitoring Stack Validation - DR-260"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Service URLs
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"
GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
KAFKA_EXPORTER_URL="${KAFKA_EXPORTER_URL:-http://localhost:9308}"
KAFKA_JMX_EXPORTER_URL="${KAFKA_JMX_EXPORTER_URL:-http://localhost:5556}"
ALERTMANAGER_URL="${ALERTMANAGER_URL:-http://localhost:9093}"

SUCCESS_COUNT=0
TOTAL_CHECKS=0

# Function to check service health
check_service() {
  local service_name=$1
  local url=$2
  local expected_pattern=$3

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  echo -n "Checking ${service_name}... "

  if response=$(curl -s -f "${url}" 2>&1); then
    if [ -z "${expected_pattern}" ] || echo "${response}" | grep -q "${expected_pattern}"; then
      echo -e "${GREEN}✓ OK${NC}"
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      return 0
    else
      echo -e "${RED}✗ FAIL (unexpected response)${NC}"
      return 1
    fi
  else
    echo -e "${RED}✗ FAIL (not reachable)${NC}"
    return 1
  fi
}

# Function to check Prometheus metric
check_prometheus_metric() {
  local metric_name=$1
  local description=$2

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  echo -n "Checking ${description}... "

  if response=$(curl -s "${PROMETHEUS_URL}/api/v1/query?query=${metric_name}" 2>&1); then
    if echo "${response}" | grep -q '"status":"success"'; then
      echo -e "${GREEN}✓ OK${NC}"
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      return 0
    else
      echo -e "${RED}✗ FAIL (query failed)${NC}"
      return 1
    fi
  else
    echo -e "${RED}✗ FAIL (cannot reach Prometheus)${NC}"
    return 1
  fi
}

# Function to check Prometheus target
check_prometheus_target() {
  local job_name=$1
  local description=$2

  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

  echo -n "Checking ${description}... "

  if response=$(curl -s "${PROMETHEUS_URL}/api/v1/targets" 2>&1); then
    if echo "${response}" | grep -q "\"job\":\"${job_name}\"" && echo "${response}" | grep -q "\"health\":\"up\""; then
      echo -e "${GREEN}✓ OK (target up)${NC}"
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      return 0
    else
      echo -e "${YELLOW}⚠ WARNING (target may be down or not configured)${NC}"
      return 1
    fi
  else
    echo -e "${RED}✗ FAIL (cannot reach Prometheus)${NC}"
    return 1
  fi
}

echo "1. Service Availability Checks"
echo "-------------------------------"
check_service "Prometheus" "${PROMETHEUS_URL}/-/healthy" ""
check_service "Grafana" "${GRAFANA_URL}/api/health" "\"database\":\"ok\""
check_service "Kafka Exporter" "${KAFKA_EXPORTER_URL}/metrics" "kafka_"
check_service "Kafka JMX Exporter" "${KAFKA_JMX_EXPORTER_URL}/metrics" "kafka_server_"
check_service "AlertManager" "${ALERTMANAGER_URL}/-/healthy" ""
echo ""

echo "2. Prometheus Target Health (DR-261)"
echo "-------------------------------------"
check_prometheus_target "kafka-exporter" "Kafka Exporter target"
check_prometheus_target "kafka-jmx" "Kafka JMX Exporter target"
echo ""

echo "3. Kafka Metrics Collection (DR-261)"
echo "-------------------------------------"
check_prometheus_metric "kafka_consumergroup_lag" "Consumer group lag metric"
check_prometheus_metric "kafka_server_brokertopicmetrics_messagesin_total" "Messages in metric"
check_prometheus_metric "kafka_server_replicamanager_underreplicatedpartitions" "Under-replicated partitions"
check_prometheus_metric "kafka_controller_kafkacontroller_offlinepartitionscount" "Offline partitions"
check_prometheus_metric "kafka_network_requestmetrics_requests_total" "Request metrics"
echo ""

echo "4. Alert Rules Configuration (DR-263)"
echo "--------------------------------------"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
echo -n "Checking alert rules... "
if response=$(curl -s "${PROMETHEUS_URL}/api/v1/rules" 2>&1); then
  kafka_alerts=$(echo "${response}" | grep -o "Kafka" | wc -l)
  if [ "${kafka_alerts}" -gt 0 ]; then
    echo -e "${GREEN}✓ OK (${kafka_alerts} Kafka alerts found)${NC}"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo -e "${YELLOW}⚠ WARNING (no Kafka alerts found)${NC}"
  fi
else
  echo -e "${RED}✗ FAIL (cannot reach Prometheus)${NC}"
fi
echo ""

echo "5. Grafana Dashboard (DR-262)"
echo "------------------------------"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
echo -n "Checking Kafka dashboard... "
if response=$(curl -s -u admin:admin "${GRAFANA_URL}/api/dashboards/uid/kafka-monitoring-dreamscape" 2>&1); then
  if echo "${response}" | grep -q "\"title\":\"Kafka Monitoring - DreamScape\""; then
    echo -e "${GREEN}✓ OK (dashboard found)${NC}"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo -e "${YELLOW}⚠ WARNING (dashboard not found or not provisioned)${NC}"
  fi
else
  echo -e "${RED}✗ FAIL (cannot reach Grafana)${NC}"
fi
echo ""

echo "=================================================="
echo "Validation Summary"
echo "=================================================="
echo "Passed: ${SUCCESS_COUNT}/${TOTAL_CHECKS} checks"

if [ "${SUCCESS_COUNT}" -eq "${TOTAL_CHECKS}" ]; then
  echo -e "${GREEN}✓ All checks passed! Kafka monitoring is fully operational.${NC}"
  exit 0
elif [ "${SUCCESS_COUNT}" -gt $((TOTAL_CHECKS / 2)) ]; then
  echo -e "${YELLOW}⚠ Some checks failed. Review the output above.${NC}"
  exit 1
else
  echo -e "${RED}✗ Multiple checks failed. Kafka monitoring may not be working correctly.${NC}"
  exit 1
fi
