#!/bin/bash
# XDPoS 2.0 Vote/Timeout Race Condition Handler
# Issue #471: Handle Vote/Timeout Race Conditions in Consensus
# Priority: P0 - Critical

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
readonly LOG_DIR="${LOG_DIR:-/var/log/xdc}"
readonly STATE_FILE="${STATE_FILE:-/var/lib/xdc/race-detector.state}"
readonly METRICS_FILE="${METRICS_FILE:-/var/lib/xdc/metrics/race-metrics.prom}"

# Configuration
MAX_VOTE_LATENCY_MS="${MAX_VOTE_LATENCY_MS:-2000}"
MIN_QUORUM_VOTES="${MIN_QUORUM_VOTES:-73}"  # 2/3 of 108 masternodes
RACE_DETECTION_WINDOW="${RACE_DETECTION_WINDOW:-5}"  # blocks
ALERT_THRESHOLD="${ALERT_THRESHOLD:-3}"  # consecutive races before alert

# Logging
log() { echo "[$(date -Iseconds)] $*"; }
info() { log "INFO: $*"; }
warn() { log "WARN: $*" >&2; }
error() { log "ERROR: $*" >&2; }

# Initialize state
init_state() {
    mkdir -p "$(dirname "$STATE_FILE")" "$(dirname "$METRICS_FILE")" "$LOG_DIR" 2>/dev/null || true
    if [[ ! -f "$STATE_FILE" ]]; then
        echo '{"races_detected":0,"last_race_block":0,"consecutive_races":0,"vote_latencies":[]}' > "$STATE_FILE"
    fi
}

# RPC call helper
rpc_call() {
    local method=$1
    local params=${2:-'[]'}
    local rpc_url="${RPC_URL:-http://localhost:8545}"
    
    curl -sf -X POST "$rpc_url" \
        -H "Content-Type: application/json" \
        -d "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":1}" \
        2>/dev/null || echo '{}'
}

# Track vote latency for a specific block
track_vote_latency() {
    local block_number=$1
    local block_time_hex
    block_time_hex=$(rpc_call "eth_getBlockByNumber" "[\"0x$(printf '%x' $block_number)\",false]" | jq -r '.result.timestamp // "0x0"')
    local block_time
    block_time=$(printf '%d' "$block_time_hex" 2>/dev/null || echo 0)
    
    # Get all votes for this block
    local votes_result
    votes_result=$(rpc_call "XDPoS_getVotesByNumber" "[\"0x$(printf '%x' $block_number)\"]")
    
    if [[ -z "$votes_result" ]] || [[ "$votes_result" == "{}" ]]; then
        return 0
    fi
    
    local csv_file="$LOG_DIR/vote-latency.csv"
    if [[ ! -f "$csv_file" ]]; then
        echo "timestamp,block_number,voter,latency_ms" > "$csv_file"
    fi
    
    # Process each vote
    echo "$votes_result" | jq -c '.result[]?' 2>/dev/null | while read -r vote; do
        local voter
        voter=$(echo "$vote" | jq -r '.masternode // empty')
        local vote_time_hex
        vote_time_hex=$(echo "$vote" | jq -r '.timestamp // "0x0"')
        local vote_time
        vote_time=$(printf '%d' "$vote_time_hex" 2>/dev/null || echo 0)
        
        if [[ -n "$voter" ]] && [[ $vote_time -gt 0 ]] && [[ $block_time -gt 0 ]]; then
            local latency_ms=$(( (vote_time - block_time) * 1000 ))
            echo "$(date -Iseconds),$block_number,$voter,$latency_ms" >> "$csv_file"
            
            # Alert if latency is too high
            if [[ $latency_ms -gt $MAX_VOTE_LATENCY_MS ]]; then
                warn "High vote latency from $voter at block $block_number: ${latency_ms}ms"
            fi
            
            echo "$latency_ms"
        fi
    done
}

# Detect race conditions between votes and timeouts
detect_race_condition() {
    local round_info
    round_info=$(rpc_call "XDPoS_getRoundInfo" '["latest"]')
    
    if [[ -z "$round_info" ]] || [[ "$round_info" == "{}" ]]; then
        return 0
    fi
    
    local current_round
    current_round=$(echo "$round_info" | jq -r '.result.round // 0')
    local timeout_count
    timeout_count=$(echo "$round_info" | jq -r '.result.timeoutCount // 0')
    
    # If we have timeouts, check if we also have enough votes for QC
    if [[ "$timeout_count" -gt 0 ]]; then
        local latest_block_hex
        latest_block_hex=$(rpc_call "eth_blockNumber" | jq -r '.result // "0x0"')
        local latest_block
        latest_block=$(printf '%d' "$latest_block_hex" 2>/dev/null || echo 0)
        
        local votes_result
        votes_result=$(rpc_call "XDPoS_getVotesByNumber" "[\"$latest_block_hex\"]")
        local vote_count
        vote_count=$(echo "$votes_result" | jq '.result | length // 0')
        
        # Race condition: votes >= quorum but timeouts > 0
        if [[ "$vote_count" -ge "$MIN_QUORUM_VOTES" ]] && [[ "$timeout_count" -gt 0 ]]; then
            warn "RACE CONDITION DETECTED: $vote_count votes but $timeout_count timeouts at round $current_round"
            
            # Update state
            local state
            state=$(cat "$STATE_FILE")
            local races_detected
            races_detected=$(echo "$state" | jq -r '.races_detected // 0')
            local consecutive_races
            consecutive_races=$(echo "$state" | jq -r '.consecutive_races // 0')
            
            races_detected=$((races_detected + 1))
            consecutive_races=$((consecutive_races + 1))
            
            echo "$state" | jq \
                --arg rb "$latest_block" \
                --arg rd "$races_detected" \
                --arg cr "$consecutive_races" \
                '.races_detected = ($rd | tonumber) | .last_race_block = ($rb | tonumber) | .consecutive_races = ($cr | tonumber)' \
                > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
            
            # Alert if threshold exceeded
            if [[ "$consecutive_races" -ge "$ALERT_THRESHOLD" ]]; then
                error "CRITICAL: $consecutive_races consecutive race conditions detected!"
                # TODO: Send alert to SkyNet
                if command -v skynet-alert >/dev/null 2>&1; then
                    skynet-alert --severity critical --message "Vote/timeout race condition detected" --component consensus
                fi
            fi
            
            return 1
        fi
    fi
    
    # Reset consecutive counter if no race
    local state
    state=$(cat "$STATE_FILE" 2>/dev/null || echo '{}')
    echo "$state" | jq '.consecutive_races = 0' > "$STATE_FILE.tmp" 2>/dev/null && mv "$STATE_FILE.tmp" "$STATE_FILE" 2>/dev/null || true
    
    return 0
}

# Export metrics for Prometheus
export_metrics() {
    local state
    state=$(cat "$STATE_FILE" 2>/dev/null || echo '{}')
    local races_detected
    races_detected=$(echo "$state" | jq -r '.races_detected // 0')
    local consecutive_races
    consecutive_races=$(echo "$state" | jq -r '.consecutive_races // 0')
    
    cat > "$METRICS_FILE" << EOF
# HELP xdpos_race_conditions_total Total number of vote/timeout race conditions detected
# TYPE xdpos_race_conditions_total counter
xdpos_race_conditions_total $races_detected

# HELP xdpos_consecutive_races Current streak of consecutive race conditions
# TYPE xdpos_consecutive_races gauge
xdpos_consecutive_races $consecutive_races

# HELP xdpos_vote_latency_threshold_ms Configured maximum acceptable vote latency
# TYPE xdpos_vote_latency_threshold_ms gauge
xdpos_vote_latency_threshold_ms $MAX_VOTE_LATENCY_MS

# HELP xdpos_min_quorum_votes Minimum votes required for quorum
# TYPE xdpos_min_quorum_votes gauge
xdpos_min_quorum_votes $MIN_QUORUM_VOTES
EOF
}

# Daemon mode - continuous monitoring
run_daemon() {
    info "Starting vote/timeout race condition monitor (daemon mode)"
    info "Configuration: MAX_VOTE_LATENCY_MS=$MAX_VOTE_LATENCY_MS, MIN_QUORUM_VOTES=$MIN_QUORUM_VOTES"
    
    init_state
    
    local poll_interval="${POLL_INTERVAL:-10}"
    local last_block=0
    
    while true; do
        local current_block_hex
        current_block_hex=$(rpc_call "eth_blockNumber" | jq -r '.result // "0x0"')
        local current_block
        current_block=$(printf '%d' "$current_block_hex" 2>/dev/null || echo 0)
        
        # Only process new blocks
        if [[ "$current_block" -gt "$last_block" ]]; then
            track_vote_latency "$current_block" >/dev/null 2>&1 || true
            detect_race_condition || true
            export_metrics
            last_block=$current_block
        fi
        
        sleep "$poll_interval"
    done
}

# One-time check
run_check() {
    local block_number="${1:-latest}"
    
    init_state
    info "Running race condition check for block: $block_number"
    
    if [[ "$block_number" == "latest" ]]; then
        block_number=$(printf '%d' "$(rpc_call "eth_blockNumber" | jq -r '.result // "0x0"')" 2>/dev/null || echo 0)
    fi
    
    info "Checking vote latency for block $block_number..."
    track_vote_latency "$block_number"
    
    info "Detecting race conditions..."
    if detect_race_condition; then
        info "No race conditions detected"
    else
        warn "Race condition detected!"
    fi
    
    export_metrics
    info "Metrics exported to $METRICS_FILE"
}

# Show current status
show_status() {
    init_state
    local state
    state=$(cat "$STATE_FILE")
    
    echo "=== Vote/Timeout Race Condition Monitor Status ==="
    echo "Total races detected: $(echo "$state" | jq -r '.races_detected // 0')"
    echo "Consecutive races: $(echo "$state" | jq -r '.consecutive_races // 0')"
    echo "Last race block: $(echo "$state" | jq -r '.last_race_block // 0')"
    echo ""
    echo "Configuration:"
    echo "  MAX_VOTE_LATENCY_MS: $MAX_VOTE_LATENCY_MS"
    echo "  MIN_QUORUM_VOTES: $MIN_QUORUM_VOTES"
    echo "  ALERT_THRESHOLD: $ALERT_THRESHOLD"
    
    if [[ -f "$LOG_DIR/vote-latency.csv" ]]; then
        echo ""
        echo "Recent vote latencies (last 10):"
        tail -10 "$LOG_DIR/vote-latency.csv" 2>/dev/null || echo "No data"
    fi
}

# CLI interface
case "${1:-}" in
    daemon)
        run_daemon
        ;;
    check)
        run_check "${2:-latest}"
        ;;
    status)
        show_status
        ;;
    metrics)
        init_state
        export_metrics
        cat "$METRICS_FILE"
        ;;
    *)
        echo "XDPoS 2.0 Vote/Timeout Race Condition Handler v$SCRIPT_VERSION"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  daemon           Run continuous monitoring"
        echo "  check [block]    Run one-time check (default: latest)"
        echo "  status           Show current status and statistics"
        echo "  metrics          Export and display Prometheus metrics"
        echo ""
        echo "Environment Variables:"
        echo "  RPC_URL          Node RPC endpoint (default: http://localhost:8545)"
        echo "  MAX_VOTE_LATENCY_MS  Alert threshold for vote latency (default: 2000)"
        echo "  MIN_QUORUM_VOTES     Minimum votes for quorum (default: 73)"
        echo "  ALERT_THRESHOLD      Consecutive races before critical alert (default: 3)"
        echo "  POLL_INTERVAL        Daemon poll interval in seconds (default: 10)"
        exit 1
        ;;
esac
