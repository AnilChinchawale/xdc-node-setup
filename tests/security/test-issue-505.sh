#!/bin/bash
# Test for macOS heartbeat script - Issue #505 fix
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HEARTBEAT_SCRIPT="${SCRIPT_DIR}/../../scripts/macos-heartbeat.sh"

echo "=== Testing Issue #505 Fix: Remove Hardcoded API Keys ==="

# Test 1: Script should fail without environment variables
echo -n "Test 1: Script fails without SKYNET_NODE_ID... "
if ! bash "$HEARTBEAT_SCRIPT" 2>&1 | grep -q "SKYNET_NODE_ID environment variable must be set"; then
    echo "FAILED - Expected error message not found"
    exit 1
fi
echo "PASSED"

# Test 2: Script should fail with NODE_ID but no API_KEY
echo -n "Test 2: Script fails without SKYNET_API_KEY... "
export SKYNET_NODE_ID="755f82db-a541-4224-9447-a385d11321b8"
if ! bash "$HEARTBEAT_SCRIPT" 2>&1 | grep -q "SKYNET_API_KEY environment variable must be set"; then
    echo "FAILED - Expected error message not found"
    exit 1
fi
echo "PASSED"

# Test 3: Validate generated .env file format
echo -n "Test 3: Generated heartbeat script loads from .env... "
if ! grep -q 'source "$HOME/.xdc-node/.env"' "$HEARTBEAT_SCRIPT"; then
    echo "FAILED - .env loading not found"
    exit 1
fi
echo "PASSED"

# Test 4: No hardcoded credentials in script
echo -n "Test 4: No hardcoded UUID in script... "
if grep -qE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' "$HEARTBEAT_SCRIPT"; then
    # Check if it's in an example or documentation
    if ! grep -q 'your-node-id-here' "$HEARTBEAT_SCRIPT"; then
        echo "FAILED - Hardcoded UUID found"
        exit 1
    fi
fi
echo "PASSED"

# Test 5: No hardcoded API key pattern
echo -n "Test 5: No hardcoded API key in script... "
if grep -q 'xdc-netown-key' "$HEARTBEAT_SCRIPT"; then
    echo "FAILED - Hardcoded API key found"
    exit 1
fi
echo "PASSED"

echo ""
echo "=== All tests passed for Issue #505 ==="
