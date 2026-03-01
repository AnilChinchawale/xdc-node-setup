#!/bin/bash
# Multi-client status checker for XDC nodes
# Supports: Geth, Erigon, Nethermind, Reth

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

# Client RPC ports (default)
GETH_PORT="${GETH_PORT:-8545}"
ERIGON_PORT="${ERIGON_PORT:-8547}"
NETHERMIND_PORT="${NETHERMIND_PORT:-8558}"
RETH_PORT="${RETH_PORT:-8588}"

check_client() {
    local client_name=$1
    local port=$2
    local rpc_url="http://localhost:$port"
    
    info "Checking $client_name on port $port..."
    
    # Check if port is listening
    if ! nc -z localhost "$port" 2>/dev/null; then
        warn "$client_name not running (port $port closed)"
        return 1
    fi
    
    # Get client version
    local version=$(curl -s -X POST "$rpc_url" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}' \
        | jq -r '.result // "Unknown"')
    
    # Get block number
    local block_hex=$(curl -s -X POST "$rpc_url" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        | jq -r '.result // "0x0"')
    local block_num=$((16#${block_hex#0x}))
    
    # Get peer count
    local peer_hex=$(curl -s -X POST "$rpc_url" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        | jq -r '.result // "0x0"')
    local peer_count=$((16#${peer_hex#0x}))
    
    # Get sync status
    local syncing=$(curl -s -X POST "$rpc_url" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
        | jq -r '.result')
    
    local sync_status="Synced ✓"
    if [[ "$syncing" != "false" ]]; then
        sync_status="Syncing..."
    fi
    
    echo "  Version: $version"
    echo "  Block: $block_num"
    echo "  Peers: $peer_count"
    echo "  Status: $sync_status"
    echo ""
}

compare_clients() {
    info "==================================="
    info "Multi-Client Status Comparison"
    info "==================================="
    echo ""
    
    # Array to store block heights
    declare -A blocks
    declare -A statuses
    
    # Check all clients
    for client_info in "Geth:$GETH_PORT" "Erigon:$ERIGON_PORT" "Nethermind:$NETHERMIND_PORT" "Reth:$RETH_PORT"; do
        IFS=':' read -r name port <<< "$client_info"
        
        if nc -z localhost "$port" 2>/dev/null; then
            block_hex=$(curl -s -X POST "http://localhost:$port" \
                -H "Content-Type: application/json" \
                -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
                | jq -r '.result // "0x0"')
            blocks[$name]=$((16#${block_hex#0x}))
            statuses[$name]="✓"
        else
            blocks[$name]=0
            statuses[$name]="✗"
        fi
    done
    
    # Find highest block
    highest=0
    for block in "${blocks[@]}"; do
        ((block > highest)) && highest=$block
    done
    
    # Display comparison
    echo "Client Status Overview:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    printf "%-15s %-15s %-10s %-10s\n" "Client" "Block Height" "Status" "Behind"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    for name in "${!blocks[@]}"; do
        block=${blocks[$name]}
        status=${statuses[$name]}
        behind=$((highest - block))
        
        if [[ $block -eq 0 ]]; then
            printf "%-15s %-15s %-10s %-10s\n" "$name" "N/A" "$status" "N/A"
        else
            printf "%-15s %-15d %-10s %-10d\n" "$name" "$block" "$status" "$behind"
        fi
    done
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Divergence check
    if [[ ${#blocks[@]} -gt 1 ]]; then
        local min_block=$highest
        for block in "${blocks[@]}"; do
            ((block > 0 && block < min_block)) && min_block=$block
        done
        
        local divergence=$((highest - min_block))
        if [[ $divergence -gt 10 ]]; then
            warn "⚠ Block divergence detected: $divergence blocks"
            warn "Clients may be on different forks!"
        else
            info "✓ All clients within acceptable range ($divergence blocks)"
        fi
    fi
}

main() {
    # Check individual clients
    check_client "Geth" "$GETH_PORT" || true
    check_client "Erigon" "$ERIGON_PORT" || true
    check_client "Nethermind" "$NETHERMIND_PORT" || true
    check_client "Reth" "$RETH_PORT" || true
    
    # Compare all clients
    compare_clients
}

main "$@"
