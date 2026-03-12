#!/bin/bash
# XDC Epoch Boundary Monitor
# Monitors XDPoS 2.0 epoch transitions and provides alerts
# Usage: ./epoch-monitor.sh [--alert-webhook URL] [--alert-blocks N]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true

# Configuration
RPC_URL="${XDC_RPC_URL:-http://127.0.0.1:8545}"
ALERT_WEBHOOK="${EPOCH_ALERT_WEBHOOK:-}"
ALERT_BLOCKS_BEFORE="${EPOCH_ALERT_BLOCKS:-100,50,10}"
LOG_FILE="${EPOCH_LOG_FILE:-/var/log/xdc-epoch-monitor.log}"
EPOCH_LENGTH="${XDC_EPOCH_LENGTH:-900}"
CHECK_INTERVAL="${EPOCH_CHECK_INTERVAL:-60}"

# State tracking
LAST_EPOCH=0
ALERT_SENT_100=false
ALERT_SENT_50=false
ALERT_SENT_10=false

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

get_current_block() {
    local block_hex
    block_hex=$(curl -s -m 5 -X POST "$RPC_URL" \
        -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' 2>/dev/null | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('result','0x0'))" 2>/dev/null || echo "0x0")
    echo $((16#${block_hex#0x}))
}

get_epoch_info() {
    local block="${1:-}"
    if [[ -z "$block" ]]; then
        block=$(get_current_block)
    fi
    
    local epoch=$(( (block / EPOCH_LENGTH) + 1 ))
    local epoch_start=$(( (epoch - 1) * EPOCH_LENGTH ))
    local epoch_end=$(( epoch * EPOCH_LENGTH ))
    local blocks_until_epoch_end=$(( epoch_end - block ))
    local progress_pct=$(python3 -c "print(f'{(block - epoch_start) / $EPOCH_LENGTH * 100:.1f}')")
    
    echo "{\"block\":$block,\"epoch\":$epoch,\"epochStart\":$epoch_start,\"epochEnd\":$epoch_end,\"blocksUntilEnd\":$blocks_until_epoch_end,\"progress\":$progress_pct}"
}

send_alert() {
    local level="$1"
    local message="$2"
    local epoch_info="$3"
    
    log "ALERT [$level]: $message"
    
    if [[ -n "$ALERT_WEBHOOK" ]]; then
        local payload
        payload=$(python3 -c "
import json
info = json.loads('$epoch_info')
alert = {
    'level': '$level',
    'message': '$message',
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'epoch': info,
    'node': '${INSTANCE_NAME:-xdc-node}'
}
print(json.dumps(alert))
")
        
        curl -s -m 10 -X POST "$ALERT_WEBHOOK" \
            -H "Content-Type: application/json" \
            -d "$payload" >/dev/null 2>&1 || log "WARNING: Failed to send webhook alert"
    fi
}

# =============================================================================
# Epoch Monitoring
# =============================================================================

check_epoch_alerts() {
    local epoch_info
    epoch_info=$(get_epoch_info)
    
    local blocks_until_epoch_end
    blocks_until_epoch_end=$(echo "$epoch_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['blocksUntilEnd'])")
    
    local epoch
    epoch=$(echo "$epoch_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['epoch'])")
    
    # Reset alert flags on new epoch
    if [[ "$epoch" -ne "$LAST_EPOCH" ]]; then
        log "New epoch detected: $epoch"
        ALERT_SENT_100=false
        ALERT_SENT_50=false
        ALERT_SENT_10=false
        LAST_EPOCH=$epoch
        
        # Send post-epoch validation
        send_alert "INFO" "Epoch $epoch has started" "$epoch_info"
    fi
    
    # Check alert thresholds
    if [[ "$blocks_until_epoch_end" -le 100 ]] && [[ "$ALERT_SENT_100" == "false" ]]; then
        send_alert "INFO" "Epoch ending in ~100 blocks ($blocks_until_epoch_end blocks remaining)" "$epoch_info"
        ALERT_SENT_100=true
    fi
    
    if [[ "$blocks_until_epoch_end" -le 50 ]] && [[ "$ALERT_SENT_50" == "false" ]]; then
        send_alert "WARNING" "Epoch ending in ~50 blocks ($blocks_until_epoch_end blocks remaining)" "$epoch_info"
        ALERT_SENT_50=true
    fi
    
    if [[ "$blocks_until_epoch_end" -le 10 ]] && [[ "$ALERT_SENT_10" == "false" ]]; then
        send_alert "CRITICAL" "Epoch ending in ~10 blocks ($blocks_until_epoch_end blocks remaining) - Prepare for transition" "$epoch_info"
        ALERT_SENT_10=true
    fi
}

validate_epoch_transition() {
    local epoch_info
    epoch_info=$(get_epoch_info)
    
    local block epoch
    block=$(echo "$epoch_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['block'])")
    epoch=$(echo "$epoch_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['epoch'])")
    
    # Check if we're at an epoch boundary
    if [[ "$((block % EPOCH_LENGTH))" -eq 0 ]]; then
        log "Validating epoch transition at block $block"
        
        # Check peer count
        local peers_hex
        peers_hex=$(curl -s -m 5 -X POST "$RPC_URL" \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' 2>/dev/null | \
            python3 -c "import sys,json; print(json.load(sys.stdin).get('result','0x0'))" 2>/dev/null || echo "0x0")
        local peers=$((16#${peers_hex#0x}))
        
        if [[ "$peers" -lt 3 ]]; then
            send_alert "WARNING" "Low peer count ($peers) during epoch transition at block $block" "$epoch_info"
        fi
        
        # Check if block production is continuing
        sleep 30
        local new_block
        new_block=$(get_current_block)
        
        if [[ "$new_block" -le "$block" ]]; then
            send_alert "CRITICAL" "Block production stalled during epoch $epoch transition" "$epoch_info"
        else
            send_alert "INFO" "Epoch $epoch transition successful - block production continuing" "$epoch_info"
        fi
    fi
}

# =============================================================================
# CLI Commands
# =============================================================================

cmd_status() {
    local epoch_info
    epoch_info=$(get_epoch_info)
    
    echo "=== XDC Epoch Status ==="
    echo "Current Block:    $(echo "$epoch_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['block'])")"
    echo "Current Epoch:    $(echo "$epoch_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['epoch'])")"
    echo "Epoch Progress:   $(echo "$epoch_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['progress'])")%"
    echo "Blocks in Epoch:  $EPOCH_LENGTH"
    echo "Blocks Until End: $(echo "$epoch_info" | python3 -c "import sys,json; print(json.load(sys.stdin)['blocksUntilEnd'])")"
    echo ""
    echo "Alert Thresholds: $ALERT_BLOCKS_BEFORE blocks before epoch end"
    echo "Webhook:          ${ALERT_WEBHOOK:-Not configured}"
}

cmd_monitor() {
    log "Starting epoch monitor (interval: ${CHECK_INTERVAL}s)"
    log "Epoch length: $EPOCH_LENGTH blocks"
    log "Alert thresholds: $ALERT_BLOCKS_BEFORE"
    
    # Initialize LAST_EPOCH
    LAST_EPOCH=$(get_epoch_info | python3 -c "import sys,json; print(json.load(sys.stdin)['epoch'])")
    log "Current epoch: $LAST_EPOCH"
    
    while true; do
        check_epoch_alerts
        validate_epoch_transition
        sleep "$CHECK_INTERVAL"
    done
}

# =============================================================================
# Main
# =============================================================================

case "${1:-monitor}" in
    status)
        cmd_status
        ;;
    monitor)
        cmd_monitor
        ;;
    --help|-h)
        cat << 'EOF'
XDC Epoch Boundary Monitor

Usage: $0 [command] [options]

Commands:
  status       Show current epoch status
  monitor      Run continuous monitoring (default)

Environment Variables:
  XDC_RPC_URL          RPC endpoint (default: http://127.0.0.1:8545)
  EPOCH_ALERT_WEBHOOK  Webhook URL for alerts
  EPOCH_ALERT_BLOCKS   Comma-separated alert thresholds (default: 100,50,10)
  XDC_EPOCH_LENGTH     Blocks per epoch (default: 900)
  EPOCH_CHECK_INTERVAL Polling interval in seconds (default: 60)

Examples:
  # Show current epoch status
  $0 status

  # Run monitor with webhook alerts
  EPOCH_ALERT_WEBHOOK=https://hooks.slack.com/... $0 monitor

  # Run with custom thresholds
  EPOCH_ALERT_BLOCKS=200,100,50,25,10 $0 monitor
EOF
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
