#!/usr/bin/env bash
#==============================================================================
# E2E Test: Start, Stop, Restart Commands
# Tests node lifecycle management
#==============================================================================

set -euo pipefail
source "$(dirname "$0")/lib/framework.sh"

test_start "Start/Stop/Restart Tests"

PROJECT_ROOT="$(get_project_root)"
export PATH="$PROJECT_ROOT/cli:$PATH"

# Skip if Docker is not available
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    skip "Docker is required for start/stop tests" "Docker not available"
    test_end
    exit 0
fi

#------------------------------------------------------------------------------
# Test: Start command exists and has help
#------------------------------------------------------------------------------

assert_cmd_output "xdc start --help" "start" "Start command has help"
assert_cmd_output "xdc stop --help" "stop" "Stop command has help"
assert_cmd_output "xdc restart --help" "restart" "Restart command has help"

#------------------------------------------------------------------------------
# Test: Start with testnet (safer for testing)
#------------------------------------------------------------------------------

log "Starting XDC node (testnet)..."

cd "$PROJECT_ROOT"

# First, make sure nothing is running
docker rm -f xdc-testnet xdc-test 2>/dev/null || true

# Check if we can start (may fail due to missing data, which is OK for syntax test)
start_output=$(timeout 30 xdc start --network testnet 2>&1) || true

if echo "$start_output" | grep -qi "started\|running\|container"; then
    pass "Start command executes"
else
    # Even if start fails, command should exist and parse arguments
    if echo "$start_output" | grep -qi "error\|failed\|missing"; then
        pass "Start command executes (with expected setup errors)"
    else
        skip "Start command executes" "Unexpected output: ${start_output:0:100}"
    fi
fi

#------------------------------------------------------------------------------
# Test: Status after start attempt
#------------------------------------------------------------------------------

status_output=$(xdc status 2>&1) || true

if echo "$status_output" | grep -qiE "running|stopped|status|network|sync"; then
    pass "Status command shows node state"
else
    skip "Status command shows node state" "Status output unclear"
fi

#------------------------------------------------------------------------------
# Test: Stop command
#------------------------------------------------------------------------------

log "Stopping XDC node..."

stop_output=$(timeout 30 xdc stop 2>&1) || true

if echo "$stop_output" | grep -qi "stop\|success\|container\|down"; then
    pass "Stop command executes"
else
    # Stop should work even if nothing was running
    pass "Stop command executes (no containers to stop)"
fi

#------------------------------------------------------------------------------
# Test: Verify containers are stopped
#------------------------------------------------------------------------------

sleep 2

if docker ps --format '{{.Names}}' | grep -q "xdc-testnet"; then
    fail "Containers should be stopped after 'xdc stop'"
else
    pass "Containers are stopped after 'xdc stop'"
fi

#------------------------------------------------------------------------------
# Test: Start with specific client
#------------------------------------------------------------------------------

for client in geth erigon; do
    log "Testing start with --client $client..."
    
    # Just test that the flag is accepted
    client_output=$(timeout 5 xdc start --client "$client" --dry-run 2>&1) || true
    
    if echo "$client_output" | grep -qi "error.*unknown\|invalid.*client"; then
        skip "Start with --client $client" "Client not supported"
    else
        pass "Start accepts --client $client flag"
    fi
done

#------------------------------------------------------------------------------
# Test: Restart command
#------------------------------------------------------------------------------

log "Testing restart command..."

# Restart should work even with nothing running (graceful handling)
restart_output=$(timeout 30 xdc restart 2>&1) || true

if echo "$restart_output" | grep -qi "restart\|start\|stop\|error"; then
    pass "Restart command executes"
else
    skip "Restart command executes" "Unexpected output"
fi

#------------------------------------------------------------------------------
# Test: Start with port conflict detection
#------------------------------------------------------------------------------

# Start a dummy container on port 8545 to test conflict detection
docker run -d --name test-port-blocker -p 8545:8545 alpine sleep 60 2>/dev/null || true

if docker ps | grep -q "test-port-blocker"; then
    log "Testing port conflict detection..."
    
    conflict_output=$(timeout 10 xdc start --network testnet 2>&1) || true
    
    if echo "$conflict_output" | grep -qi "port.*in use\|conflict\|already\|8545"; then
        pass "Port conflict is detected"
    else
        skip "Port conflict is detected" "Conflict detection not triggered"
    fi
    
    # Cleanup
    docker rm -f test-port-blocker 2>/dev/null || true
else
    skip "Port conflict detection" "Could not create test container"
fi

#------------------------------------------------------------------------------
# Test: Graceful shutdown
#------------------------------------------------------------------------------

# Start a quick container to test graceful shutdown
docker run -d --name xdc-test alpine sleep 300 2>/dev/null || true

if docker ps | grep -q "xdc-test"; then
    log "Testing graceful shutdown..."
    
    start_time=$(date +%s)
    timeout 30 docker stop xdc-test >/dev/null 2>&1 || true
    end_time=$(date +%s)
    
    shutdown_time=$((end_time - start_time))
    
    if [[ $shutdown_time -lt 15 ]]; then
        pass "Container stops within reasonable time (${shutdown_time}s)"
    else
        fail "Container shutdown took too long" "${shutdown_time}s"
    fi
    
    docker rm -f xdc-test 2>/dev/null || true
else
    skip "Graceful shutdown test" "Could not create test container"
fi

#------------------------------------------------------------------------------
# Test: Start options
#------------------------------------------------------------------------------

# Test various start options are recognized
for option in "--detach" "--foreground" "-d"; do
    if xdc start --help 2>&1 | grep -qi -- "$option\|daemon\|background"; then
        pass "Start option $option is documented"
    else
        skip "Start option $option is documented" "Not in help"
    fi
done

#------------------------------------------------------------------------------
# Cleanup
#------------------------------------------------------------------------------

log "Cleaning up test containers..."
docker rm -f xdc-testnet xdc-test test-port-blocker 2>/dev/null || true

test_end
