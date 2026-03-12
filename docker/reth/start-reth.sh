#!/bin/bash
set -e

#==============================================================================
# XDC Reth Start Script - Production Hardened
# Handles initialization and startup of Reth XDC client
# Issue #235: P2P stability, state validation, metrics
#==============================================================================

: "${NETWORK:=mainnet}"
: "${SYNC_MODE:=full}"
: "${RPC_PORT:=7073}"
: "${P2P_PORT:=40303}"
: "${DISCOVERY_PORT:=40304}"
: "${AUTHRPC_PORT:=8551}"
: "${INSTANCE_NAME:=Reth_XDC_Node}"
: "${DEBUG_TIP:=}"
: "${BOOTNODES:=}"
: "${ERIGON_ENDPOINT:=http://xdc-erigon:7071}"

# Network configuration
case "$NETWORK" in
    mainnet)
        CHAIN_ID=50
        CHAIN_NAME="xdc-mainnet"
        NETWORK_NAME="XDC Mainnet"
        ;;
    testnet|apothem)
        CHAIN_ID=51
        CHAIN_NAME="xdc-apothem"
        NETWORK_NAME="XDC Apothem Testnet"
        ;;
    devnet)
        CHAIN_ID=551
        CHAIN_NAME="xdc-devnet"
        NETWORK_NAME="XDC Devnet"
        ;;
    *)
        CHAIN_ID=50
        CHAIN_NAME="xdc-mainnet"
        NETWORK_NAME="XDC Mainnet"
        ;;
esac

echo "=== XDC Reth Node (Production Hardened) ==="
echo "Network: $NETWORK_NAME (Chain ID: $CHAIN_ID)"
echo "RPC Port: $RPC_PORT"
echo "P2P Port: $P2P_PORT"
echo "Discovery Port: $DISCOVERY_PORT"
echo "Instance: $INSTANCE_NAME"
echo ""

# Issue #71: Generate deterministic identity on first boot
DATADIR="/work/xdcchain"
if [ ! -f "$DATADIR/.node-identity" ]; then
  echo "[SkyNet] First boot detected - generating node identity..."
  # Generate a deterministic identifier
  IDENTITY_SEED="${HOSTNAME:-reth}-$(date +%Y%m)"
  echo "$IDENTITY_SEED" > "$DATADIR/.node-identity"
  echo "[SkyNet] Generated identity seed (node will generate its own p2p keys)"
fi

# =============================================================================
# Issue #235: P2P Stability - Build peer list with Erigon as mandatory peer
# =============================================================================

# Default bootnodes with increased redundancy
DEFAULT_BOOTNODES=(
    # Erigon nodes (mandatory peers via FCU feeder)
    "enode://e1a69a7d766576e694adc3fc78d801a8a66926cbe8f4fe95b85f3b481444700a5d1b6d440b2715b5bb7cf4824df6a6702740afc8c52b20c72bc8c16f1ccde1f3@149.102.140.32:30305"
    "enode://874589626a2b4fd7c57202533315885815eba51dbc434db88bbbebcec9b22cf2a01eafad2fd61651306fe85321669a30b3f41112eca230137ded24b86e064ba8@5.189.144.192:30305"
    # XDC Mainnet bootnodes
    "enode://e1a69a7d766576e694adc3fc78d801a8a66926cbe8f4fe95b85f3b481444700a5d1b6d440b2715b5bb7cf4824df6a6702740afc8c52b20c72bc8c16f1ccde1f3@149.102.140.32:30303"
    "enode://874589626a2b4fd7c57202533315885815eba51dbc434db88bbbebcec9b22cf2a01eafad2fd61651306fe85321669a30b3f41112eca230137ded24b86e064ba8@5.189.144.192:30303"
    "enode://ccdef92053c8b9622180d02a63edffb3e143e7627737ea812b930eacea6c51f0c93a5da3397f59408c3d3d1a9a381f7e0b07440eae47314685b649a03408cfdd@37.60.243.5:30303"
)

# Build Reth arguments
RETH_ARGS=(
    node
    --chain "$CHAIN_NAME"
    --datadir "$DATADIR"
    --http
    --http.port "${RPC_PORT}"
    --http.addr "0.0.0.0"
    --http.api "eth,net,web3,admin,debug,trace"
    --port "${P2P_PORT}"
    --discovery.port "${DISCOVERY_PORT}"
    --authrpc.port "${AUTHRPC_PORT}"
    # Issue #235: Increase peer connection attempts
    --max-outbound-peers 50
    --max-inbound-peers 30
)

# Add debug.tip if provided (required for sync without CL)
if [[ -n "$DEBUG_TIP" ]]; then
    RETH_ARGS+=(--debug.tip "$DEBUG_TIP")
fi

# Add bootnodes if provided or use defaults
if [[ -n "$BOOTNODES" ]]; then
    # Split by comma and add each as --bootnodes flag
    IFS=',' read -ra NODES <<< "$BOOTNODES"
    for node in "${NODES[@]}"; do
        RETH_ARGS+=(--bootnodes "$node")
    done
else
    # Add default bootnodes
    for node in "${DEFAULT_BOOTNODES[@]}"; do
        RETH_ARGS+=(--bootnodes "$node")
    done
fi

# Issue #235: Add Prometheus metrics endpoint
if [[ "${METRICS_ENABLED:-false}" == "true" ]]; then
    RETH_ARGS+=(--metrics "0.0.0.0:9001")
else
    # Default metrics on port 6073
    RETH_ARGS+=(--metrics "0.0.0.0:6073")
fi

# Set log level
RETH_ARGS+=(--log.stdout.filter "${LOG_LEVEL:-info}")

echo "Starting Reth..."
echo "Command: /reth/bin/xdc-reth ${RETH_ARGS[*]}"
echo ""

# =============================================================================
# Issue #235: P2P Stability Monitoring Functions
# =============================================================================

# Function to check peer count via RPC
check_peers() {
    local response
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        http://localhost:${RPC_PORT} 2>/dev/null || echo "")
    
    if [[ -n "$response" ]]; then
        local peer_hex=$(echo "$response" | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4)
        if [[ -n "$peer_hex" ]]; then
            echo $((16#${peer_hex#0x}))
        else
            echo "0"
        fi
    else
        echo "-1"
    fi
}

# Function to check current block
check_block() {
    local response
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://localhost:${RPC_PORT} 2>/dev/null || echo "")
    
    if [[ -n "$response" ]]; then
        local block_hex=$(echo "$response" | grep -o '"result":"0x[^"]*"' | cut -d'"' -f4)
        if [[ -n "$block_hex" ]]; then
            echo $((16#${block_hex#0x}))
        else
            echo "0"
        fi
    else
        echo "-1"
    fi
}

# Issue #235: State validation - Check state root against reference client
check_state_root() {
    local block_num=$1
    local response
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$(printf '0x%x' $block_num)\",false],\"id\":1}" \
        http://localhost:${RPC_PORT} 2>/dev/null || echo "")
    
    if [[ -n "$response" ]]; then
        echo "$response" | grep -o '"stateRoot":"0x[^"]*"' | cut -d'"' -f4
    else
        echo ""
    fi
}

# Issue #235: Get state root from Erigon reference client
get_erigon_state_root() {
    local block_num=$1
    local response
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$(printf '0x%x' $block_num)\",false],\"id\":1}" \
        "${ERIGON_ENDPOINT}" 2>/dev/null || echo "")
    
    if [[ -n "$response" ]]; then
        echo "$response" | grep -o '"stateRoot":"0x[^"]*"' | cut -d'"' -f4
    else
        echo ""
    fi
}

# Log peer and block status
log_status() {
    local peers=$1
    local block=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] Reth Status - Peers: $peers, Block: $block"
}

# =============================================================================
# Issue #235: Background monitoring for P2P stability and state validation
# =============================================================================
monitor_reth() {
    local start_time=$(date +%s)
    local last_logged_block=0
    local state_check_interval=100  # Check state root every 100 blocks
    local last_state_check=0
    
    echo "[Monitor] Starting Reth P2P stability monitor..."
    echo "[Monitor] Erigon reference endpoint: ${ERIGON_ENDPOINT}"
    
    # Wait for node to start
    sleep 30
    
    while true; do
        sleep 60
        
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local peers=$(check_peers)
        local current_block=$(check_block)
        
        # Log peer count and block progress every 60s
        log_status "$peers" "$current_block"
        
        # Issue #235: State validation check
        if [[ "$current_block" -gt 0 && $((current_block - last_state_check)) -ge $state_check_interval ]]; then
            local reth_state_root=$(check_state_root "$current_block")
            local erigon_state_root=$(get_erigon_state_root "$current_block")
            
            if [[ -n "$reth_state_root" && -n "$erigon_state_root" ]]; then
                if [[ "$reth_state_root" != "$erigon_state_root" ]]; then
                    echo "[Monitor] WARNING: State root divergence detected at block $current_block!"
                    echo "[Monitor]   Reth:  $reth_state_root"
                    echo "[Monitor]   Erigon: $erigon_state_root"
                else
                    echo "[Monitor] State root validated at block $current_block"
                fi
            else
                echo "[Monitor] Could not perform state validation - missing data"
            fi
            last_state_check=$current_block
        fi
        
        # Issue #235: Peer connection monitoring
        if [[ "$peers" == "0" && "$elapsed" -gt 300 ]]; then
            echo "[Monitor] WARNING: No peers connected after ${elapsed}s"
            echo "[Monitor] Reth peers through Erigon bridge may be initializing..."
        fi
        
        last_logged_block=$current_block
    done
}

# Start monitoring in background
monitor_reth &
MONITOR_PID=$!

# Cleanup function
cleanup() {
    echo "[Monitor] Shutting down monitor process..."
    kill $MONITOR_PID 2>/dev/null || true
}
trap cleanup EXIT

# =============================================================================
# Execute Reth
# =============================================================================
if [[ -x /reth/bin/xdc-reth ]]; then
    exec /reth/bin/xdc-reth "${RETH_ARGS[@]}" 2>&1 | tee -a /reth/logs/reth.log
else
    echo "ERROR: xdc-reth binary not found at /reth/bin/xdc-reth"
    ls -la /reth/bin/
    exit 1
fi
