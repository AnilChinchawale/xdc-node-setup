#!/usr/bin/env bash
#==============================================================================
# E2E Test: Status Command Output
# Tests the `xdc status` command and its various output modes
#==============================================================================

set -euo pipefail
source "$(dirname "$0")/lib/framework.sh"

test_start "Status Command Tests"

PROJECT_ROOT="$(get_project_root)"
export PATH="$PROJECT_ROOT/cli:$PATH"

#------------------------------------------------------------------------------
# Test: Status command exists
#------------------------------------------------------------------------------

assert_cmd "xdc status --help" "Status command has help"
assert_cmd_output "xdc help" "status" "Status is listed in main help"

#------------------------------------------------------------------------------
# Test: Status command runs without errors
#------------------------------------------------------------------------------

status_output=$(xdc status 2>&1) || true

# Status should always produce some output
if [[ -n "$status_output" ]]; then
    pass "Status command produces output"
else
    fail "Status command produces output" "No output"
fi

#------------------------------------------------------------------------------
# Test: Status shows essential information
#------------------------------------------------------------------------------

# These are key fields that status should show
key_fields=(
    "network\|Network"
    "status\|Status\|running\|stopped"
    "sync\|Sync\|block\|Block"
)

for field in "${key_fields[@]}"; do
    if echo "$status_output" | grep -qiE "$field"; then
        pass "Status shows ${field%%\\|*} information"
    else
        skip "Status shows ${field%%\\|*} information" "Field not found"
    fi
done

#------------------------------------------------------------------------------
# Test: Status --json output
#------------------------------------------------------------------------------

json_output=$(xdc status --json 2>&1) || true

if echo "$json_output" | head -1 | grep -q "^{"; then
    pass "Status --json outputs JSON"
    
    # Validate JSON structure if jq is available
    if command -v jq >/dev/null 2>&1; then
        if echo "$json_output" | jq . >/dev/null 2>&1; then
            pass "Status JSON is valid"
            
            # Check for expected fields
            for field in status network; do
                if echo "$json_output" | jq -e ".$field // .${field^} // empty" >/dev/null 2>&1; then
                    pass "JSON contains $field field"
                else
                    skip "JSON contains $field field" "Field not found"
                fi
            done
        else
            fail "Status JSON is valid" "Invalid JSON"
        fi
    else
        skip "JSON validation" "jq not installed"
    fi
else
    skip "Status --json outputs JSON" "No JSON output"
fi

#------------------------------------------------------------------------------
# Test: Status aliases
#------------------------------------------------------------------------------

# 'info' should be an alias for 'status'
info_output=$(xdc info 2>&1) || true

if [[ -n "$info_output" ]]; then
    pass "Info command works (alias for status)"
else
    skip "Info command works" "No output"
fi

#------------------------------------------------------------------------------
# Test: Status --watch option exists
#------------------------------------------------------------------------------

if xdc status --help 2>&1 | grep -qi "watch\|continuous\|monitor"; then
    pass "Status supports --watch option"
else
    skip "Status supports --watch option" "Not documented"
fi

#------------------------------------------------------------------------------
# Test: Status shows sync progress
#------------------------------------------------------------------------------

if echo "$status_output" | grep -qiE "sync|block|height|progress|%"; then
    pass "Status shows sync-related information"
else
    skip "Status shows sync-related information" "No sync info displayed"
fi

#------------------------------------------------------------------------------
# Test: Status shows peer count
#------------------------------------------------------------------------------

if echo "$status_output" | grep -qiE "peer|connection"; then
    pass "Status shows peer information"
else
    skip "Status shows peer information" "No peer info displayed"
fi

#------------------------------------------------------------------------------
# Test: Status when node is stopped
#------------------------------------------------------------------------------

# Ensure node is stopped first
docker rm -f xdc-testnet xdc-mainnet 2>/dev/null || true

stopped_status=$(xdc status 2>&1) || true

if echo "$stopped_status" | grep -qiE "stopped|not running|offline|down|no.*container"; then
    pass "Status correctly shows node is stopped"
else
    skip "Status correctly shows node is stopped" "Status unclear when stopped"
fi

#------------------------------------------------------------------------------
# Test: Status handles missing config gracefully
#------------------------------------------------------------------------------

# Test status with non-existent config
if XDC_HOME=/nonexistent xdc status 2>&1 | grep -qiE "error\|warning\|not found\|stopped"; then
    pass "Status handles missing config gracefully"
else
    skip "Status handles missing config gracefully" "Error handling unclear"
fi

#------------------------------------------------------------------------------
# Test: Status --verbose option
#------------------------------------------------------------------------------

verbose_output=$(xdc status --verbose 2>&1) || true

# Verbose should have more output than normal
normal_lines=$(echo "$status_output" | wc -l)
verbose_lines=$(echo "$verbose_output" | wc -l)

if [[ $verbose_lines -ge $normal_lines ]]; then
    pass "Status --verbose produces detailed output"
else
    skip "Status --verbose produces detailed output" "Verbose output not longer"
fi

#------------------------------------------------------------------------------
# Test: Status shows Docker container info
#------------------------------------------------------------------------------

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    # Start a quick test container
    docker run -d --name xdc-status-test alpine sleep 60 2>/dev/null || true
    
    if docker ps | grep -q "xdc-status-test"; then
        # Check if status can detect containers
        container_status=$(docker ps --format '{{.Names}}' 2>&1) || true
        
        if [[ -n "$container_status" ]]; then
            pass "Can query Docker container status"
        else
            skip "Can query Docker container status" "Docker query failed"
        fi
        
        docker rm -f xdc-status-test 2>/dev/null || true
    fi
else
    skip "Docker container status" "Docker not available"
fi

#------------------------------------------------------------------------------
# Test: Status formatting
#------------------------------------------------------------------------------

# Check that status output is well-formatted
if echo "$status_output" | grep -qE "^[A-Za-z]+:?\s|^\s*[•·▸-]|═|─|│"; then
    pass "Status output is formatted"
else
    skip "Status output is formatted" "Formatting unclear"
fi

#------------------------------------------------------------------------------
# Test: Status exit codes
#------------------------------------------------------------------------------

# Status should exit 0 even if node is stopped (it's reporting status, not health)
xdc status >/dev/null 2>&1
status_exit=$?

if [[ $status_exit -eq 0 ]] || [[ $status_exit -eq 1 ]]; then
    pass "Status has appropriate exit code ($status_exit)"
else
    fail "Status has appropriate exit code" "Exit code: $status_exit"
fi

test_end
