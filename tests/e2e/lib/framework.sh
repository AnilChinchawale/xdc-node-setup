#!/usr/bin/env bash
#==============================================================================
# E2E Test Framework for XDC Node Setup
# Simple bash test framework with TAP output and colored console output
#==============================================================================

set -euo pipefail

# Test state
declare -g TEST_COUNT=0
declare -g TEST_PASSED=0
declare -g TEST_FAILED=0
declare -g TEST_SKIPPED=0
declare -g TEST_NAME=""
declare -g TEST_START_TIME=0
declare -g TAP_MODE="${TAP_MODE:-false}"
declare -g VERBOSE="${TEST_VERBOSE:-false}"

# Colors
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "true" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
fi

# Test directory
export TEST_DIR="${TEST_DIR:-/tmp/xdc-e2e-test}"
export TEST_NETWORK="${TEST_NETWORK:-testnet}"
export TEST_TIMEOUT="${TEST_TIMEOUT:-300}"
export TEST_SKIP_CLEANUP="${TEST_SKIP_CLEANUP:-false}"

#==============================================================================
# Output Functions
#==============================================================================

log() {
    if [[ "$TAP_MODE" == "true" ]]; then
        echo "# $*"
    else
        echo -e "${DIM}[$TEST_NAME]${NC} $*"
    fi
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        log "$@"
    fi
}

pass() {
    local description="$1"
    ((TEST_COUNT++))
    ((TEST_PASSED++))
    
    if [[ "$TAP_MODE" == "true" ]]; then
        echo "ok $TEST_COUNT - $description"
    else
        echo -e "  ${GREEN}✓${NC} $description"
    fi
}

fail() {
    local description="$1"
    local details="${2:-}"
    ((TEST_COUNT++))
    ((TEST_FAILED++))
    
    if [[ "$TAP_MODE" == "true" ]]; then
        echo "not ok $TEST_COUNT - $description"
        if [[ -n "$details" ]]; then
            echo "  ---"
            echo "  message: '$details'"
            echo "  ..."
        fi
    else
        echo -e "  ${RED}✗${NC} $description"
        if [[ -n "$details" ]]; then
            echo -e "    ${DIM}→ $details${NC}"
        fi
    fi
}

skip() {
    local description="$1"
    local reason="${2:-}"
    ((TEST_COUNT++))
    ((TEST_SKIPPED++))
    
    if [[ "$TAP_MODE" == "true" ]]; then
        echo "ok $TEST_COUNT - $description # SKIP ${reason:-skipped}"
    else
        echo -e "  ${YELLOW}○${NC} $description ${DIM}(skipped: ${reason:-no reason})${NC}"
    fi
}

#==============================================================================
# Test Lifecycle
#==============================================================================

test_start() {
    TEST_NAME="${1:-E2E Tests}"
    TEST_START_TIME=$(date +%s)
    TEST_COUNT=0
    TEST_PASSED=0
    TEST_FAILED=0
    TEST_SKIPPED=0
    
    if [[ "$TAP_MODE" == "true" ]]; then
        echo "TAP version 14"
        echo "# $TEST_NAME"
    else
        echo ""
        echo -e "${BOLD}${CYAN}━━━ $TEST_NAME ━━━${NC}"
        echo ""
    fi
    
    # Create test directory
    mkdir -p "$TEST_DIR"
}

test_end() {
    local elapsed=$(($(date +%s) - TEST_START_TIME))
    
    if [[ "$TAP_MODE" == "true" ]]; then
        echo "1..$TEST_COUNT"
    else
        echo ""
        echo -e "${BOLD}━━━ Results ━━━${NC}"
        echo -e "  Total:   $TEST_COUNT"
        echo -e "  ${GREEN}Passed:  $TEST_PASSED${NC}"
        if [[ $TEST_FAILED -gt 0 ]]; then
            echo -e "  ${RED}Failed:  $TEST_FAILED${NC}"
        fi
        if [[ $TEST_SKIPPED -gt 0 ]]; then
            echo -e "  ${YELLOW}Skipped: $TEST_SKIPPED${NC}"
        fi
        echo -e "  ${DIM}Duration: ${elapsed}s${NC}"
        echo ""
    fi
    
    # Cleanup unless skipped
    if [[ "$TEST_SKIP_CLEANUP" != "true" ]]; then
        cleanup_test_env
    fi
    
    # Exit with failure if any tests failed
    [[ $TEST_FAILED -eq 0 ]]
}

cleanup_test_env() {
    log_verbose "Cleaning up test environment..."
    
    # Stop test containers
    docker rm -f xdc-testnet xdc-devnet xdc-test 2>/dev/null || true
    docker rm -f xdc-erigon-testnet xdc-erigon-devnet 2>/dev/null || true
    
    # Clean test directory (preserve if debugging)
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

#==============================================================================
# Assert Functions
#==============================================================================

# Basic equality
assert_eq() {
    local expected="$1"
    local actual="$2"
    local description="${3:-Values should be equal}"
    
    if [[ "$expected" == "$actual" ]]; then
        pass "$description"
        return 0
    else
        fail "$description" "Expected '$expected', got '$actual'"
        return 1
    fi
}

assert_ne() {
    local not_expected="$1"
    local actual="$2"
    local description="${3:-Values should not be equal}"
    
    if [[ "$not_expected" != "$actual" ]]; then
        pass "$description"
        return 0
    else
        fail "$description" "Did not expect '$not_expected'"
        return 1
    fi
}

# String contains
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local description="${3:-String should contain substring}"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        pass "$description"
        return 0
    else
        fail "$description" "String does not contain '$needle'"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local description="${3:-String should not contain substring}"
    
    if [[ "$haystack" != *"$needle"* ]]; then
        pass "$description"
        return 0
    else
        fail "$description" "String should not contain '$needle'"
        return 1
    fi
}

# Numeric comparisons
assert_gt() {
    local actual="$1"
    local threshold="$2"
    local description="${3:-Value should be greater than threshold}"
    
    if [[ "$actual" -gt "$threshold" ]]; then
        pass "$description"
        return 0
    else
        fail "$description" "$actual is not greater than $threshold"
        return 1
    fi
}

assert_lt() {
    local actual="$1"
    local threshold="$2"
    local description="${3:-Value should be less than threshold}"
    
    if [[ "$actual" -lt "$threshold" ]]; then
        pass "$description"
        return 0
    else
        fail "$description" "$actual is not less than $threshold"
        return 1
    fi
}

# Command assertions
assert_cmd() {
    local cmd="$1"
    local description="${2:-Command should succeed}"
    
    log_verbose "Running: $cmd"
    if eval "$cmd" >/dev/null 2>&1; then
        pass "$description"
        return 0
    else
        fail "$description" "Command failed: $cmd"
        return 1
    fi
}

assert_cmd_fails() {
    local cmd="$1"
    local description="${2:-Command should fail}"
    
    log_verbose "Running (expecting failure): $cmd"
    if ! eval "$cmd" >/dev/null 2>&1; then
        pass "$description"
        return 0
    else
        fail "$description" "Command should have failed: $cmd"
        return 1
    fi
}

assert_cmd_output() {
    local cmd="$1"
    local expected="$2"
    local description="${3:-Command output should match}"
    
    log_verbose "Running: $cmd"
    local output
    output=$(eval "$cmd" 2>&1) || true
    
    if [[ "$output" == *"$expected"* ]]; then
        pass "$description"
        return 0
    else
        fail "$description" "Output doesn't contain '$expected'. Got: ${output:0:100}..."
        return 1
    fi
}

# File assertions
assert_file_exists() {
    local path="$1"
    local description="${2:-File should exist}"
    
    if [[ -f "$path" ]]; then
        pass "$description"
        return 0
    else
        fail "$description" "File not found: $path"
        return 1
    fi
}

assert_file_not_exists() {
    local path="$1"
    local description="${2:-File should not exist}"
    
    if [[ ! -f "$path" ]]; then
        pass "$description"
        return 0
    else
        fail "$description" "File exists but shouldn't: $path"
        return 1
    fi
}

assert_dir_exists() {
    local path="$1"
    local description="${2:-Directory should exist}"
    
    if [[ -d "$path" ]]; then
        pass "$description"
        return 0
    else
        fail "$description" "Directory not found: $path"
        return 1
    fi
}

assert_file_contains() {
    local path="$1"
    local content="$2"
    local description="${3:-File should contain content}"
    
    if [[ -f "$path" ]] && grep -q "$content" "$path" 2>/dev/null; then
        pass "$description"
        return 0
    else
        fail "$description" "File doesn't contain '$content': $path"
        return 1
    fi
}

assert_file_executable() {
    local path="$1"
    local description="${2:-File should be executable}"
    
    if [[ -x "$path" ]]; then
        pass "$description"
        return 0
    else
        fail "$description" "File not executable: $path"
        return 1
    fi
}

# Process/Port assertions
assert_process_running() {
    local process="$1"
    local description="${2:-Process should be running}"
    
    if pgrep -f "$process" >/dev/null 2>&1; then
        pass "$description"
        return 0
    else
        fail "$description" "Process not running: $process"
        return 1
    fi
}

assert_port_open() {
    local port="$1"
    local description="${2:-Port should be open}"
    local host="${3:-localhost}"
    
    if nc -z "$host" "$port" 2>/dev/null || lsof -i :"$port" >/dev/null 2>&1; then
        pass "$description"
        return 0
    else
        fail "$description" "Port $port not open on $host"
        return 1
    fi
}

assert_port_closed() {
    local port="$1"
    local description="${2:-Port should be closed}"
    local host="${3:-localhost}"
    
    if ! nc -z "$host" "$port" 2>/dev/null && ! lsof -i :"$port" >/dev/null 2>&1; then
        pass "$description"
        return 0
    else
        fail "$description" "Port $port is open but should be closed"
        return 1
    fi
}

# Docker assertions
assert_container_running() {
    local container="$1"
    local description="${2:-Container should be running}"
    
    if docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null | grep -q true; then
        pass "$description"
        return 0
    else
        fail "$description" "Container not running: $container"
        return 1
    fi
}

assert_container_stopped() {
    local container="$1"
    local description="${2:-Container should be stopped}"
    
    if ! docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null | grep -q true; then
        pass "$description"
        return 0
    else
        fail "$description" "Container is running but should be stopped: $container"
        return 1
    fi
}

# JSON assertions (requires jq)
assert_json_valid() {
    local json="$1"
    local description="${2:-JSON should be valid}"
    
    if command -v jq >/dev/null && echo "$json" | jq . >/dev/null 2>&1; then
        pass "$description"
        return 0
    else
        fail "$description" "Invalid JSON"
        return 1
    fi
}

assert_json_field() {
    local json="$1"
    local field="$2"
    local expected="$3"
    local description="${4:-JSON field should match}"
    
    if ! command -v jq >/dev/null; then
        skip "$description" "jq not installed"
        return 0
    fi
    
    local actual
    actual=$(echo "$json" | jq -r "$field" 2>/dev/null)
    
    if [[ "$actual" == "$expected" ]]; then
        pass "$description"
        return 0
    else
        fail "$description" "Field $field: expected '$expected', got '$actual'"
        return 1
    fi
}

#==============================================================================
# Helper Functions
#==============================================================================

# Wait for condition with timeout
wait_for() {
    local condition="$1"
    local timeout="${2:-60}"
    local interval="${3:-2}"
    local description="${4:-Waiting for condition}"
    
    log_verbose "$description (timeout: ${timeout}s)"
    
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        if eval "$condition" >/dev/null 2>&1; then
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    
    return 1
}

# Wait for port to be open
wait_for_port() {
    local port="$1"
    local timeout="${2:-60}"
    local host="${3:-localhost}"
    
    wait_for "nc -z $host $port" "$timeout" 2 "Waiting for port $port"
}

# Wait for container to be running
wait_for_container() {
    local container="$1"
    local timeout="${2:-60}"
    
    wait_for "docker inspect -f '{{.State.Running}}' $container 2>/dev/null | grep -q true" "$timeout" 2 "Waiting for container $container"
}

# Wait for RPC to respond
wait_for_rpc() {
    local url="${1:-http://localhost:8545}"
    local timeout="${2:-60}"
    
    wait_for "curl -sf -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_blockNumber\",\"params\":[],\"id\":1}' $url" "$timeout" 2 "Waiting for RPC at $url"
}

# Get current OS
get_os() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)  echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

# Get architecture
get_arch() {
    case "$(uname -m)" in
        x86_64)  echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *)       echo "unknown" ;;
    esac
}

# Check if running on macOS ARM64
is_macos_arm64() {
    [[ "$(get_os)" == "macos" ]] && [[ "$(get_arch)" == "arm64" ]]
}

# Check if Rosetta is installed (macOS only)
is_rosetta_installed() {
    [[ "$(get_os)" == "macos" ]] && /usr/bin/pgrep -q oahd
}

# Get project root
get_project_root() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$(cd "$script_dir/../../.." && pwd)"
}

# Setup test environment
setup_test_env() {
    log_verbose "Setting up test environment..."
    
    export PROJECT_ROOT="$(get_project_root)"
    export PATH="$PROJECT_ROOT/cli:$PATH"
    
    mkdir -p "$TEST_DIR"
    cd "$TEST_DIR"
}

#==============================================================================
# Initialization
#==============================================================================

# Parse common arguments
for arg in "$@"; do
    case "$arg" in
        --tap)     TAP_MODE=true ;;
        --verbose) VERBOSE=true ;;
        --no-color) NO_COLOR=true ;;
    esac
done
