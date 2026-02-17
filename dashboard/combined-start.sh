#!/bin/bash
set -e

# Load SkyNet config
SKYNET_CONF="${SKYNET_CONF:-/etc/xdc-node/skynet.conf}"
if [ -f "$SKYNET_CONF" ]; then
  set -a
  source "$SKYNET_CONF"
  set +a
  echo "[SkyNet] Loaded config from $SKYNET_CONF"
  echo "[SkyNet] Node ID: ${SKYNET_NODE_ID:-not set}"
  echo "[SkyNet] API URL: ${SKYNET_API_URL:-not set}"
fi

# Load persisted node ID
if [ -z "$SKYNET_NODE_ID" ] && [ -f /tmp/skynet-node-id ]; then
  source /tmp/skynet-node-id
  echo "[SkyNet] Loaded node ID from /tmp/skynet-node-id"
fi

# Master API key for auto-registration (fallback)
MASTER_API_KEY="${SKYNET_MASTER_KEY:-xdc-netown-key-2026-prod}"

# Auto-register function
auto_register() {
  local rpc_url="$1"
  local chain_id="$2"
  local network_name="$3"
  local client_type="$4"
  local client_version="$5"
  local api_url="${SKYNET_API_URL:-https://net.xdc.network/api/v1}"
  
  # Get host IP
  HOST_IP=$(curl -s -m 5 https://api.ipify.org 2>/dev/null || echo "unknown")
  
  # Detect node name from env or generate
  NODE_NAME="${SKYNET_NODE_NAME:-xdc-${client_type:-node}-$(hostname | cut -d. -f1)}"
  
  echo "[SkyNet] Auto-registering node: $NODE_NAME (client: $client_type, network: $network_name)"
  
  # Try to register with master key (keyless registration)
  local register_payload
  register_payload=$(cat <<EOF
{
  "name": "$NODE_NAME",
  "role": "fullnode",
  "network": "$network_name",
  "client": "$client_type",
  "rpcUrl": "http://$HOST_IP:${NODE_RPC_PORT:-8545}",
  "p2pPort": 30303,
  "host": "$HOST_IP"
}
EOF
)
  
  local response
  response=$(curl -s -m 15 -X POST "${api_url}/nodes/register" \
    -H "Content-Type: application/json" \
    -d "$register_payload" 2>/dev/null)
  
  if echo "$response" | jq -e '.success' >/dev/null 2>&1; then
    SKYNET_NODE_ID=$(echo "$response" | jq -r '.data.nodeId')
    SKYNET_API_KEY=$(echo "$response" | jq -r '.data.apiKey')
    
    # Save to persist across restarts
    mkdir -p /tmp
    cat > /tmp/skynet-node-id <<EOF
SKYNET_NODE_ID=$SKYNET_NODE_ID
SKYNET_API_KEY=$SKYNET_API_KEY
EOF
    
    echo "[SkyNet] ✅ Auto-registered! nodeId=$SKYNET_NODE_ID"
    return 0
  else
    echo "[SkyNet] ❌ Auto-registration failed: $(echo "$response" | jq -r '.error // .message // "unknown error"')"
    return 1
  fi
}

# Start SkyNet heartbeat in background
(
  sleep 10
  echo "[SkyNet] Starting heartbeat loop..."
  
  # Attempt auto-registration if credentials missing
  if [ -z "$SKYNET_NODE_ID" ] || [ -z "$SKYNET_API_KEY" ]; then
    echo "[SkyNet] No credentials found, attempting auto-registration..."
    
    # Get initial client info for registration
    RPC_URL="${RPC_URL:-http://xdc-node:8545}"
    CLIENT_VERSION=$(curl -s -m 5 -X POST "$RPC_URL" -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
    CHAIN_ID=$(curl -s -m 5 -X POST "$RPC_URL" -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
    
    CLIENT_TYPE="unknown"
    case "$CLIENT_VERSION" in
      *[Nn]ethermind*) CLIENT_TYPE="nethermind" ;;
      *[Ee]rigon*) CLIENT_TYPE="erigon" ;;
      *XDC*|*[Gg]eth*) CLIENT_TYPE="geth" ;;
    esac
    
    NETWORK_NAME="mainnet"
    case "$CHAIN_ID" in
      50) NETWORK_NAME="mainnet" ;;
      51) NETWORK_NAME="apothem" ;;
      551) NETWORK_NAME="devnet" ;;
    esac
    
    auto_register "$RPC_URL" "$CHAIN_ID" "$NETWORK_NAME" "$CLIENT_TYPE" "$CLIENT_VERSION" || true
  fi
  
  while true; do
    RPC_URL="${RPC_URL:-http://xdc-node:8545}"
    
    # Get metrics from node
    BLOCK_HEX=$(curl -s -m 5 -X POST "$RPC_URL" -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
    PEER_HEX=$(curl -s -m 5 -X POST "$RPC_URL" -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
    CHAIN_ID=$(curl -s -m 5 -X POST "$RPC_URL" -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
    SYNC_JSON=$(curl -s -m 5 -X POST "$RPC_URL" -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
    
    BLOCK_NUM=0
    [ -n "$BLOCK_HEX" ] && [ "$BLOCK_HEX" != "null" ] && BLOCK_NUM=$(printf "%d" "$BLOCK_HEX" 2>/dev/null || echo "0")
    
    PEER_COUNT=0
    [ -n "$PEER_HEX" ] && [ "$PEER_HEX" != "null" ] && PEER_COUNT=$(printf "%d" "$PEER_HEX" 2>/dev/null || echo "0")
    
    NETWORK_NAME="mainnet"
    case "$CHAIN_ID" in
      50) NETWORK_NAME="mainnet" ;;
      51) NETWORK_NAME="apothem" ;;
      551) NETWORK_NAME="devnet" ;;
      *) NETWORK_NAME="mainnet" ;;
    esac
    
    IS_SYNCING=false
    [ "$SYNC_JSON" != "false" ] && [ "$SYNC_JSON" != "null" ] && IS_SYNCING=true
    
    # Detect client type from version string
    CLIENT_VERSION=$(curl -s -m 5 -X POST "$RPC_URL" -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"web3_clientVersion","params":[],"id":1}' 2>/dev/null | jq -r .result 2>/dev/null)
    CLIENT_TYPE="unknown"
    case "$CLIENT_VERSION" in
      *[Nn]ethermind*) CLIENT_TYPE="nethermind" ;;
      *[Ee]rigon*) CLIENT_TYPE="erigon" ;;
      *XDC*|*[Gg]eth*) CLIENT_TYPE="geth" ;;
    esac
    
    if [ -n "$SKYNET_API_URL" ] && [ -n "$SKYNET_NODE_ID" ] && [ -n "$SKYNET_API_KEY" ]; then
      echo "[SkyNet] Sending heartbeat: block=$BLOCK_NUM peers=$PEER_COUNT network=$NETWORK_NAME chainId=$CHAIN_ID syncing=$IS_SYNCING client=$CLIENT_TYPE"
      RESPONSE=$(curl -s -m 15 -X POST "${SKYNET_API_URL}/nodes/${SKYNET_NODE_ID}/heartbeat" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${SKYNET_API_KEY}" \
        -d "{\"blockHeight\":$BLOCK_NUM,\"peerCount\":$PEER_COUNT,\"isSyncing\":$IS_SYNCING,\"clientType\":\"$CLIENT_TYPE\",\"version\":\"$CLIENT_VERSION\",\"network\":\"$NETWORK_NAME\",\"chainId\":$CHAIN_ID}" 2>&1)
      
      if echo "$RESPONSE" | jq -e .error >/dev/null 2>&1; then
        echo "[SkyNet] ❌ Heartbeat failed: $(echo "$RESPONSE" | jq -r .error)"
        # Try to re-register if auth failed
        if echo "$RESPONSE" | grep -qi "unauthorized\|invalid\|not found"; then
          echo "[SkyNet] Attempting re-registration..."
          auto_register "$RPC_URL" "$CHAIN_ID" "$NETWORK_NAME" "$CLIENT_TYPE" "$CLIENT_VERSION" || true
        fi
      elif echo "$RESPONSE" | jq -e .success >/dev/null 2>&1; then
        echo "[SkyNet] ✅ Heartbeat OK"
      else
        echo "[SkyNet] ⚠️  Unexpected response: $RESPONSE"
      fi
    else
      echo "[SkyNet] ⚠️  Skipping heartbeat (missing credentials)"
    fi
    
    sleep 60
  done
) &

# Start Next.js dashboard
echo "Starting Next.js dashboard on port 3000..."
cd /app
exec node_modules/.bin/next start
