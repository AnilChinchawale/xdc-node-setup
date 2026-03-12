#!/bin/bash
# Test for epoch monitoring - Issue #522
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR}/../.."

echo "=== Testing Issue #522 Fix: Epoch Boundary Monitoring ==="

# Test 1: Epoch monitor script exists
echo -n "Test 1: epoch-monitor.sh exists... "
if [[ ! -f "${REPO_DIR}/scripts/epoch-monitor.sh" ]]; then
    echo "FAILED - Script not found"
    exit 1
fi
if ! grep -q "set -euo pipefail" "${REPO_DIR}/scripts/epoch-monitor.sh"; then
    echo "FAILED - Missing error handling"
    exit 1
fi
echo "PASSED"

# Test 2: Docker Compose exists
echo -n "Test 2: docker-compose.epoch-monitor.yml exists... "
if [[ ! -f "${REPO_DIR}/docker/docker-compose.epoch-monitor.yml" ]]; then
    echo "FAILED - Compose file not found"
    exit 1
fi
echo "PASSED"

# Test 3: Alert thresholds implemented
echo -n "Test 3: Alert thresholds implemented... "
if ! grep -q "100,50,10" "${REPO_DIR}/scripts/epoch-monitor.sh"; then
    echo "FAILED - Default alert thresholds not found"
    exit 1
fi
if ! grep -q "ALERT_SENT_100" "${REPO_DIR}/scripts/epoch-monitor.sh"; then
    echo "FAILED - 100 block alert not implemented"
    exit 1
fi
echo "PASSED"

# Test 4: Webhook alerting
echo -n "Test 4: Webhook alerting implemented... "
if ! grep -q "send_alert" "${REPO_DIR}/scripts/epoch-monitor.sh"; then
    echo "FAILED - send_alert function not found"
    exit 1
fi
if ! grep -q "ALERT_WEBHOOK" "${REPO_DIR}/scripts/epoch-monitor.sh"; then
    echo "FAILED - Webhook configuration not found"
    exit 1
fi
echo "PASSED"

# Test 5: CLI commands
echo -n "Test 5: CLI commands implemented... "
if ! grep -q "cmd_status()" "${REPO_DIR}/scripts/epoch-monitor.sh"; then
    echo "FAILED - status command not found"
    exit 1
fi
if ! grep -q "cmd_monitor()" "${REPO_DIR}/scripts/epoch-monitor.sh"; then
    echo "FAILED - monitor command not found"
    exit 1
fi
echo "PASSED"

echo ""
echo "=== All tests passed for Issue #522 ==="
