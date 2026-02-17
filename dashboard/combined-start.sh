#!/bin/bash
set -e

# Load SkyNet config
SKYNET_CONF="${SKYNET_CONF:-/etc/xdc-node/skynet.conf}"
if [ -f "$SKYNET_CONF" ]; then
  set -a
  source "$SKYNET_CONF"
  set +a
fi

# Load persisted node ID
if [ -z "$SKYNET_NODE_ID" ] && [ -f /tmp/skynet-node-id ]; then
  source /tmp/skynet-node-id
fi

# Start SkyNet heartbeat in background
(
  sleep 10
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
    
    if [ -n "$SKYNET_API_URL" ] && [ -n "$SKYNET_NODE_ID" ] && [ -n "$SKYNET_API_KEY" ]; then
      curl -s -m 15 -X POST "${SKYNET_API_URL}/nodes/${SKYNET_NODE_ID}/heartbeat" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${SKYNET_API_KEY}" \
        -d "{\"blockHeight\":$BLOCK_NUM,\"peerCount\":$PEER_COUNT,\"isSyncing\":$IS_SYNCING,\"clientType\":\"geth\",\"version\":\"v2.6.8\",\"network\":\"$NETWORK_NAME\",\"chainId\":$CHAIN_ID}" >/dev/null 2>&1
    fi
    
    sleep 60
  done
) &

# Start Next.js dashboard
echo "Starting Next.js dashboard on port 3000..."
cd /app
exec node_modules/.bin/next start
