#!/bin/bash
# XDC Node Watchdog - Ensures node stays running and syncing
# Run via cron: */5 * * * * /path/to/xdc-watchdog.sh

set -e

LOG_FILE="${LOG_FILE:-/var/log/xdc-watchdog.log}"
MAX_RESTARTS="${MAX_RESTARTS:-3}"
RESTART_COUNT_FILE="/tmp/xdc-restart-count"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Get restart count
RESTART_COUNT=$(cat "$RESTART_COUNT_FILE" 2>/dev/null || echo "0")

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q '^xdc-node'; then
    log "ERROR: xdc-node container not running"
    
    if [ "$RESTART_COUNT" -ge "$MAX_RESTARTS" ]; then
        log "CRITICAL: Max restart attempts ($MAX_RESTARTS) reached. Manual intervention required."
        # Send alert (telegram/email if configured)
        exit 1
    fi
    
    log "Attempting restart (attempt $((RESTART_COUNT + 1))/$MAX_RESTARTS)..."
    docker compose -f /root/xdc-node-setup/docker/docker-compose.yml restart xdc-node
    echo "$((RESTART_COUNT + 1))" > "$RESTART_COUNT_FILE"
    exit 0
fi

# Check RPC health
RPC_URL="${RPC_URL:-http://localhost:8545}"
BLOCK_NUMBER=$(curl -s -m 10 -X POST "$RPC_URL" \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ -z "$BLOCK_NUMBER" ] || [ "$BLOCK_NUMBER" = "null" ]; then
    log "WARNING: RPC not responding or returned null"
    
    # Check container logs for errors
    RECENT_ERRORS=$(docker logs xdc-node --tail 50 2>&1 | grep -i "error\|fatal\|panic" | wc -l)
    
    if [ "$RECENT_ERRORS" -gt 5 ]; then
        log "ERROR: Found $RECENT_ERRORS recent errors in logs. Restarting..."
        docker compose -f /root/xdc-node-setup/docker/docker-compose.yml restart xdc-node
        echo "$((RESTART_COUNT + 1))" > "$RESTART_COUNT_FILE"
    else
        log "Node may be starting up or temporarily unresponsive. Will check again next cycle."
    fi
    exit 0
fi

# Convert hex to decimal
CURRENT_BLOCK=$((16#${BLOCK_NUMBER#0x}))
log "Node healthy: Block $CURRENT_BLOCK"

# Check if sync is progressing
LAST_BLOCK_FILE="/tmp/xdc-last-block"
LAST_BLOCK=$(cat "$LAST_BLOCK_FILE" 2>/dev/null || echo "0")

if [ "$CURRENT_BLOCK" -le "$LAST_BLOCK" ]; then
    log "WARNING: Node not syncing (stuck at block $CURRENT_BLOCK for >5 minutes)"
    
    # Check peer count
    PEER_COUNT=$(curl -s -m 10 -X POST "$RPC_URL" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
        | grep -o '"result":"[^"]*"' | cut -d'"' -f4)
    
    PEERS=$((16#${PEER_COUNT#0x}))
    
    if [ "$PEERS" -lt 2 ]; then
        log "ERROR: Only $PEERS peer(s). Restarting to find new peers..."
        docker compose -f /root/xdc-node-setup/docker/docker-compose.yml restart xdc-node
        echo "$((RESTART_COUNT + 1))" > "$RESTART_COUNT_FILE"
        exit 0
    else
        log "Have $PEERS peers but not syncing. May be waiting for valid blocks."
    fi
else
    # Node is healthy and syncing - reset restart counter
    echo "0" > "$RESTART_COUNT_FILE"
    echo "$CURRENT_BLOCK" > "$LAST_BLOCK_FILE"
fi

log "Watchdog check complete. Node is healthy."
