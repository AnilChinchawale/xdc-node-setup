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

# XDC Mainnet Bootnodes - used to bootstrap P2P connections
# These are the same bootnodes used by XDC geth nodes
# Users can override by creating /etc/xdc-node/bootnodes.conf
XDC_MAINNET_BOOTNODES=(
    "enode://e1a69a7d766576e694adc3fc78d801a8a66926cbe8f4fe95b85f3b481444700a5d1b6d440b2715b5bb7cf4824df6a6702740afc8c52b20c72bc8c16f1ccde1f3@149.102.140.32:30303"
    "enode://874589626a2b4fd7c57202533315885815eba51dbc434db88bbbebcec9b22cf2a01eafad2fd61651306fe85321669a30b3f41112eca230137ded24b86e064ba8@5.189.144.192:30303"
    "enode://ccdef92053c8b9622180d02a63edffb3e143e7627737ea812b930eacea6c51f0c93a5da3397f59408c3d3d1a9a381f7e0b07440eae47314685b649a03408cfdd@37.60.243.5:30303"
    "enode://12711126475d7924af98d359e178f71c5d9607de32d2c5b4ab1afff4b0bb16b793b4bbda0a42bf41a309e5349b6106d053ae4ae92aa848b5879e3ef3687c6203@89.117.49.48:30303"
    "enode://81edfecc3df6994679daf67858ae34c0ae91aac944a84b09171532b45ad0f5d0c896eb8c023df04eaa2db743f5fccdf18cf7e2d12120d37a2c142a3be0a348cd@38.102.87.174:30303"
    "enode://053ba696174e7f115e38f0e3963d0035ac20dc18e9a5c5873f9e90fe338d777f726d68d053c987416ec0bd97d4d818c59a8a23bc9ea854069ea2310846e27e7d@162.250.189.221:30303"
    "enode://b3ce1f8894af033cc2adbcb0836fe18d283af8574c451e385fd362165a6e5eded1b59b640c4d92048283bad9855721345a28ebaf28f66ace00a7134871d1e2a2@38.143.58.166:30303"
    "enode://938f2e3f409a12573e6da6460b6497c45e2bec393756b989b8874f647911cca39d0ffef8554a45698a8f21a7e870288beb638b3770537a12118e30bd6f9ae806@109.199.104.176:30303"
    "enode://47350ef305fb1406818a621a0f11144a72d560835a860607b331cef46ac82ea79c7df6bb5e5dba4147a489d9c77bc527f2500ce753fece817bc1a890eb05b886@185.252.233.29:30303"
    "enode://2ac0472c39e3e0be89bc021689d4c015c455e9f2fe2101bee80b61bba6224c810d200a6d6d17038d5826d522edbcb73a6bc44e492cd5f06a5377aa6eee03335b@144.126.136.27:30303"
)

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

# Function to build bootnodes string from array
build_bootnodes_from_array() {
    local arr=("$@")
    local result=""
    for node in "${arr[@]}"; do
        [[ -z "$node" ]] && continue
        [[ -n "$result" ]] && result="$result,"
        result="$result$node"
    done
    echo "$result"
}

# 1. Check for user-editable config file
USER_BOOTNODES_FILE="/etc/xdc-node/bootnodes.conf"
if [[ -f "$USER_BOOTNODES_FILE" ]]; then
    echo "Loading bootnodes from user config: $USER_BOOTNODES_FILE"
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ ^enode:// ]]; then
            [[ -n "$BOOTNODES" ]] && BOOTNODES="$BOOTNODES,"
            BOOTNODES="$BOOTNODES$line"
        fi
    done < "$USER_BOOTNODES_FILE"
    echo "Loaded $(echo "$BOOTNODES" | tr ',' '\n' | grep -c 'enode') bootnodes from user config"
fi

# 2. Check for container-mounted bootnodes.list
if [[ -z "$BOOTNODES" && -f "$BOOTNODES_FILE" ]]; then
    echo "Loading bootnodes from $BOOTNODES_FILE"
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        if [[ "$line" =~ ^enode:// ]]; then
            [[ -n "$BOOTNODES" ]] && BOOTNODES="$BOOTNODES,"
            BOOTNODES="$BOOTNODES$line"
        fi
    done < "$BOOTNODES_FILE"
    echo "Loaded $(echo "$BOOTNODES" | tr ',' '\n' | grep -c 'enode') bootnodes from $BOOTNODES_FILE"
fi

# 3. Fallback to built-in XDC mainnet bootnodes
if [[ -z "$BOOTNODES" ]]; then
    echo "Using built-in XDC mainnet bootnodes"
    BOOTNODES=$(build_bootnodes_from_array "${XDC_MAINNET_BOOTNODES[@]}")
    echo "Loaded ${#XDC_MAINNET_BOOTNODES[@]} built-in bootnodes"
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
