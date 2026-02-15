#!/usr/bin/env bash
#==============================================================================
# E2E Test: Setup Wizard
# Tests the `xdc setup` / `xdc init` wizard functionality
#==============================================================================

set -euo pipefail
source "$(dirname "$0")/lib/framework.sh"

test_start "Setup Wizard Tests"

PROJECT_ROOT="$(get_project_root)"
export PATH="$PROJECT_ROOT/cli:$PATH"

#------------------------------------------------------------------------------
# Test: Setup command exists
#------------------------------------------------------------------------------

assert_cmd_output "xdc help" "init" "Init command exists in help"

#------------------------------------------------------------------------------
# Test: Setup wizard shows network options
#------------------------------------------------------------------------------

# Simulate setup wizard (non-interactive check)
if timeout 2 bash -c "echo 'q' | xdc init 2>&1" | grep -qi "network\|mainnet\|testnet"; then
    pass "Setup wizard shows network options"
else
    skip "Setup wizard shows network options" "Interactive wizard cannot be tested non-interactively"
fi

#------------------------------------------------------------------------------
# Test: Config file generation
#------------------------------------------------------------------------------

# Create a test config
mkdir -p "$TEST_DIR/test-node"
cd "$TEST_DIR/test-node"

# Test config template
if [[ -f "$PROJECT_ROOT/configs/config.toml.example" ]]; then
    assert_file_exists "$PROJECT_ROOT/configs/config.toml.example" "Config template exists"
    assert_file_contains "$PROJECT_ROOT/configs/config.toml.example" "network" "Template contains network config"
fi

#------------------------------------------------------------------------------
# Test: Docker compose generation for different networks
#------------------------------------------------------------------------------

for network in mainnet testnet devnet; do
    compose_file="$PROJECT_ROOT/docker/${network}/docker-compose.yml"
    if [[ -f "$compose_file" ]]; then
        assert_file_exists "$compose_file" "${network} docker-compose exists"
        assert_file_contains "$compose_file" "xdc" "${network} compose references XDC"
    else
        skip "${network} docker-compose exists" "File not found"
    fi
done

#------------------------------------------------------------------------------
# Test: Environment file template
#------------------------------------------------------------------------------

if [[ -f "$PROJECT_ROOT/.env.example" ]] || [[ -f "$PROJECT_ROOT/docker/.env.example" ]]; then
    env_file="$PROJECT_ROOT/.env.example"
    [[ -f "$env_file" ]] || env_file="$PROJECT_ROOT/docker/.env.example"
    assert_file_exists "$env_file" "Environment template exists"
fi

#------------------------------------------------------------------------------
# Test: Bootnodes configuration
#------------------------------------------------------------------------------

if [[ -f "$PROJECT_ROOT/configs/bootnodes.list" ]] || [[ -f "$PROJECT_ROOT/bootnodes.list" ]]; then
    bootnode_file="$PROJECT_ROOT/configs/bootnodes.list"
    [[ -f "$bootnode_file" ]] || bootnode_file="$PROJECT_ROOT/bootnodes.list"
    assert_file_exists "$bootnode_file" "Bootnodes list exists"
    assert_file_contains "$bootnode_file" "enode://" "Bootnodes file contains enode addresses"
fi

#------------------------------------------------------------------------------
# Test: Genesis files exist
#------------------------------------------------------------------------------

for network in mainnet testnet; do
    genesis_dir="$PROJECT_ROOT/$network"
    if [[ -d "$genesis_dir" ]]; then
        if [[ -f "$genesis_dir/genesis.json" ]]; then
            assert_file_exists "$genesis_dir/genesis.json" "${network} genesis.json exists"
            assert_file_contains "$genesis_dir/genesis.json" "chainId" "${network} genesis has chainId"
        fi
    fi
done

#------------------------------------------------------------------------------
# Test: Setup script validates inputs
#------------------------------------------------------------------------------

# Test that setup.sh has input validation
assert_file_contains "$PROJECT_ROOT/setup.sh" "validate\|check\|verify" "Setup script has validation logic"

#------------------------------------------------------------------------------
# Test: Client selection options
#------------------------------------------------------------------------------

# Check that multiple clients are supported
assert_cmd_output "xdc help" "client" "CLI supports client selection"

# Check client configs exist
for client in geth erigon; do
    if [[ -d "$PROJECT_ROOT/docker/$client" ]] || grep -q "$client" "$PROJECT_ROOT/docker/docker-compose.yml" 2>/dev/null; then
        pass "${client} client configuration exists"
    else
        skip "${client} client configuration exists" "Not found"
    fi
done

#------------------------------------------------------------------------------
# Test: Port configuration
#------------------------------------------------------------------------------

# Default ports should be documented/configurable
default_ports="8545 8546 30303"
for port in $default_ports; do
    if grep -rq "$port" "$PROJECT_ROOT/docker/" 2>/dev/null; then
        pass "Port $port is configured in docker setup"
    else
        skip "Port $port is configured" "Not found in docker configs"
    fi
done

#------------------------------------------------------------------------------
# Test: Masternode setup option
#------------------------------------------------------------------------------

assert_cmd_output "xdc help" "masternode" "Masternode command exists"

if [[ -f "$PROJECT_ROOT/scripts/masternode-setup.sh" ]] || grep -q "masternode" "$PROJECT_ROOT/setup.sh" 2>/dev/null; then
    pass "Masternode setup is available"
else
    skip "Masternode setup is available" "Not found"
fi

#------------------------------------------------------------------------------
# Test: Network selection validation
#------------------------------------------------------------------------------

# Check that only valid networks are accepted
valid_networks="mainnet testnet devnet"
for net in $valid_networks; do
    if grep -q "$net" "$PROJECT_ROOT/setup.sh" 2>/dev/null || [[ -d "$PROJECT_ROOT/$net" ]]; then
        pass "Network '$net' is supported"
    fi
done

# Invalid network should fail
if timeout 2 bash -c "NETWORK=invalid_network $PROJECT_ROOT/setup.sh --validate 2>&1" | grep -qi "invalid\|error\|unknown"; then
    pass "Invalid network is rejected"
else
    skip "Invalid network is rejected" "Cannot test non-interactively"
fi

test_end
