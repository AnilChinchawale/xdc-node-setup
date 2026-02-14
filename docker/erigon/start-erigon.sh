#!/bin/bash
set -e

#==============================================================================
# Erigon-XDC Start Script
# Multi-sentry P2P support for XDC network
#==============================================================================

# Config files
CONFIG_FILE="/etc/xdc-node/config.toml"
BOOTNODES_FILE="/bootnodes.list"
DATADIR="/data"

echo "Starting Erigon-XDC node..."
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
        
        # Track section headers like [Node.HTTP]
        if [[ "$line" =~ ^[[:space:]]*\[([^]]+)\] ]]; then
            section="${BASH_REMATCH[1]}"
            section="${section##*.}"  # Node.HTTP → HTTP
            continue
        fi
        
        # Parse key = "value" or key = number
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            # Skip arrays
            [[ "$value" == "["* ]] && continue
            # Remove quotes
            value="${value%\"}"
            value="${value#\"}"
            # Remove trailing comments
            value="${value%%#*}"
            value="${value% }"
            # Export both section-prefixed and plain key
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
LOG_LEVEL="${LEVEL:-3}"
INSTANCE_NAME="${INSTANCE_NAME:-Erigon_XDC_Node}"
RPC_ADDR="${HTTP_ADDR:-${ADDR:-0.0.0.0}}"
RPC_PORT="${HTTP_PORT:-${PORT:-8547}}"
RPC_API="${HTTP_API:-${API:-eth,net,web3,admin,XDPoS}}"
RPC_CORS_DOMAIN="${HTTP_CORS_DOMAIN:-${CORS_DOMAIN:-*}}"
RPC_VHOSTS="${HTTP_VHOSTS:-${VHOSTS:-*}}"
P2P_PORT_63="${P2P_PORT:-30304}"
P2P_PORT_68="${P2P_PORT_68:-30311}"

echo "Config: sync=$SYNC_MODE log=$LOG_LEVEL rpc=$RPC_ADDR:$RPC_PORT"

# ============================================================
# Parse bootnodes
# ============================================================
BOOTNODES=""
if [ -f "$BOOTNODES_FILE" ]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^# ]] && continue
        [[ -z "$line" ]] && continue
        [[ -n "$BOOTNODES" ]] && BOOTNODES="$BOOTNODES,"
        BOOTNODES="$BOOTNODES$line"
    done < "$BOOTNODES_FILE"
    echo "Loaded $(echo "$BOOTNODES" | tr ',' '\n' | wc -l) bootnodes"
fi

# ============================================================
# Detect public IP
# ============================================================
PUBLIC_IP=$(wget -qO- ifconfig.me 2>/dev/null || wget -qO- https://checkip.amazonaws.com 2>/dev/null || echo "")
if [[ -n "$PUBLIC_IP" ]]; then
    echo "Public IP: $PUBLIC_IP"
    NAT_FLAG="--nat=extip:$PUBLIC_IP"
else
    echo "WARN: Could not detect public IP, using NAT auto-detection"
    NAT_FLAG=""
fi

# ============================================================
# Build Erigon command
# ============================================================
ARGS=(
    --chain=xdc
    --datadir="$DATADIR"
    --http
    --http.addr="$RPC_ADDR"
    --http.port="$RPC_PORT"
    --http.api="$RPC_API"
    --http.corsdomain="$RPC_CORS_DOMAIN"
    --http.vhosts="$RPC_VHOSTS"
    --port="$P2P_PORT_68"
    --private.api.addr=0.0.0.0:9092
    --p2p.protocol=63,62
    --discovery.v4
    --discovery.xdc
    --verbosity="$LOG_LEVEL"
)

# Add bootnodes if available
[[ -n "$BOOTNODES" ]] && ARGS+=(--bootnodes="$BOOTNODES")

# Add NAT flag if public IP detected
[[ -n "$NAT_FLAG" ]] && ARGS+=($NAT_FLAG)

# Add any extra args from docker command
ARGS+=("$@")

echo "Starting erigon with args: ${ARGS[*]}"
exec erigon "${ARGS[@]}"
