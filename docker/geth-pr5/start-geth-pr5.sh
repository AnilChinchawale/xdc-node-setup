#!/bin/bash
set -e

#==============================================================================
# XDC Geth PR5 Start Script
# Feature branch: feature/xdpos-consensus
#==============================================================================

# Config files
CONFIG_FILE="/etc/xdc-node/config.toml"
GENESIS_FILE="/work/genesis.json"
BOOTNODES_FILE="/work/bootnodes.list"
PWD_FILE="/work/.pwd"
DATADIR="/work/xdcchain"

echo "Starting XDC Geth PR5 node..."
echo "Datadir: $DATADIR"
echo "Config: $CONFIG_FILE"

# ============================================================
# Load config.toml - section-aware TOML parser
# ============================================================
load_config() {
    local config_file="$1"
    [[ ! -f "$config_file" ]] && return
    
    local section=""
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        
        # Track section headers
        if [[ "$line" =~ ^[[:space:]]*\[([^]]+)\] ]]; then
            section="${BASH_REMATCH[1]}"
            section="${section##*.}"
            continue
        fi
        
        # Parse key = "value"
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            [[ "$value" == "["* ]] && continue
            value="${value%\"}"
            value="${value#\"}"
            value="${value%%#*}"
            value="${value% }"
            local ukey="${key^^}"
            local usection="${section^^}"
            [[ -n "$section" ]] && export "${usection}_${ukey}=$value"
            export "${ukey}=$value"
        fi
    done < "$config_file"
    echo "Loaded config from $config_file"
}

if [[ -f "$CONFIG_FILE" ]]; then
    load_config "$CONFIG_FILE"
fi

# ============================================================
# Defaults
# ============================================================
SYNC_MODE="${SYNC_MODE:-full}"
GC_MODE="${GC_MODE:-full}"
LOG_LEVEL="${LEVEL:-2}"
INSTANCE_NAME="${INSTANCE_NAME:-XDC_Geth_PR5}"
RPC_ADDR="${HTTP_ADDR:-${ADDR:-0.0.0.0}}"
RPC_PORT="${HTTP_PORT:-${PORT:-8545}}"
RPC_API="${HTTP_API:-${API:-admin,eth,net,web3,XDPoS}}"
RPC_CORS_DOMAIN="${HTTP_CORS_DOMAIN:-${CORS_DOMAIN:-*}}"
RPC_VHOSTS="${HTTP_VHOSTS:-${VHOSTS:-*}}"
WS_ADDR="${WS_ADDR:-0.0.0.0}"
WS_PORT="${WS_PORT:-8546}"
WS_API="${WS_API:-eth,net,web3,XDPoS}"
WS_ORIGINS="${WS_ORIGINS:-*}"

echo "Config: sync=$SYNC_MODE gc=$GC_MODE log=$LOG_LEVEL"

# ============================================================
# Init or recover wallet
# ============================================================
if [ ! -d "$DATADIR/XDC/chaindata" ]; then
    wallet=$(XDC account new --password "$PWD_FILE" --datadir "$DATADIR" 2>/dev/null | awk -F '[{}]' '{print $2}')
    echo "Initializing Genesis Block"
    echo "$wallet" > "$DATADIR/coinbase.txt"
    XDC init --datadir "$DATADIR" "$GENESIS_FILE"
else
    wallet=$(XDC account list --datadir "$DATADIR" 2>/dev/null | head -n 1 | awk -F '[{}]' '{print $2}')
fi
echo "Wallet: $wallet"

# ============================================================
# Bootnodes
# ============================================================
bootnodes=""
if [ -f "$BOOTNODES_FILE" ]; then
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        [ -z "$bootnodes" ] && bootnodes="$line" || bootnodes="${bootnodes},$line"
    done < "$BOOTNODES_FILE"
    echo "Loaded bootnodes: $bootnodes"
fi

# ============================================================
# Ethstats
# ============================================================
INSTANCE_IP=$(wget -qO- https://checkip.amazonaws.com 2>/dev/null || echo "unknown")
netstats="${INSTANCE_NAME}:xinfin_xdpos_hybrid_network_stats@stats.xinfin.network:3000"

# ============================================================
# Build args
# ============================================================
LOG_FILE="$DATADIR/xdc-geth-pr5-$(date +%Y%m%d-%H%M%S).log"

args=(
    --datadir "$DATADIR"
    --networkid 50
    --port 30303
    --syncmode "$SYNC_MODE"
    --gcmode "$GC_MODE"
    --verbosity "$LOG_LEVEL"
    --password "$PWD_FILE"
    --mine
    --gasprice 1
    --targetgaslimit 420000000
    --ipcpath /tmp/XDC.ipc
)

# Add wallet unlock if available
[ -n "$wallet" ] && args+=(--unlock "$wallet")

# Add bootnodes if available
[ -n "$bootnodes" ] && args+=(--bootnodes "$bootnodes")

# Add ethstats
args+=(--ethstats "$netstats")

# XDCx data dir
args+=(--XDCx.datadir "$DATADIR/XDCx")

# ============================================================
# HTTP/RPC flags - PR5 uses new-style --http.* flags
# ============================================================
args+=(
    --http
    --http.addr "$RPC_ADDR"
    --http.port "$RPC_PORT"
    --http.api "$RPC_API"
    --http.corsdomain "$RPC_CORS_DOMAIN"
    --http.vhosts "$RPC_VHOSTS"
    --ws
    --ws.addr "$WS_ADDR"
    --ws.port "$WS_PORT"
    --ws.api "$WS_API"
    --ws.origins "$WS_ORIGINS"
    --store-reward
)

# Add any extra args from docker command
args+=("$@")

echo "Starting XDC Geth PR5..."
echo "Args: ${args[*]}"
exec XDC "${args[@]}" 2>&1 | tee -a "$LOG_FILE"
