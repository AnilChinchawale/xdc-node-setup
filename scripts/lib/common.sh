#!/bin/bash
# Common Utility Functions for XDC Node Setup
# Consolidates duplicate functions across scripts
# Part of refactoring effort for code quality

# ============================================
# RPC and Node Communication
# ============================================

check_rpc() {
    local endpoint="${1:-http://localhost:8545}"
    local timeout="${2:-5}"
    
    if ! curl -sf -m "$timeout" "$endpoint" \
         -X POST \
         -H "Content-Type: application/json" \
         --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
         >/dev/null 2>&1; then
        return 1
    fi
    return 0
}

json_rpc() {
    local endpoint="$1"
    local method="$2"
    local params="${3:-[]}"
    
    curl -sf "$endpoint" \
        -X POST \
        -H "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"id\":1}" \
        | jq -r '.result // empty'
}

get_block_number() {
    local endpoint="${1:-http://localhost:8545}"
    local block_hex
    
    block_hex=$(json_rpc "$endpoint" "eth_blockNumber" "[]")
    if [[ -n "$block_hex" ]]; then
        printf "%d" "$block_hex"
    fi
}

get_peer_count() {
    local endpoint="${1:-http://localhost:8545}"
    local peer_hex
    
    peer_hex=$(json_rpc "$endpoint" "net_peerCount" "[]")
    if [[ -n "$peer_hex" ]]; then
        printf "%d" "$peer_hex"
    fi
}

get_client_version() {
    local endpoint="${1:-http://localhost:8545}"
    json_rpc "$endpoint" "web3_clientVersion" "[]"
}

# ============================================
# Network Detection
# ============================================

detect_network() {
    local endpoint="${1:-http://localhost:8545}"
    local chain_id
    
    chain_id=$(json_rpc "$endpoint" "eth_chainId" "[]")
    case "$chain_id" in
        0x32|50)  echo "mainnet" ;;
        0x33|51)  echo "testnet" ;;
        0x227|551) echo "apothem" ;;
        *)        echo "unknown" ;;
    esac
}

get_rpc_endpoint() {
    local client="$1"
    local network="${2:-mainnet}"
    
    case "$client" in
        geth-pr5) echo "http://localhost:8557" ;;
        erigon)   echo "http://localhost:8556" ;;
        nethermind) echo "http://localhost:8558" ;;
        reth)     echo "http://localhost:8588" ;;
        *)        echo "http://localhost:8545" ;;
    esac
}

# ============================================
# Client Detection
# ============================================

check_client() {
    local client="$1"
    local valid_clients=("geth" "geth-pr5" "erigon" "nethermind" "reth")
    
    for valid in "${valid_clients[@]}"; do
        [[ "$client" == "$valid" ]] && return 0
    done
    return 1
}

# ============================================
# Prerequisites and Validation
# ============================================

check_prerequisites() {
    local missing=()
    
    command -v docker >/dev/null 2>&1 || missing+=("docker")
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing prerequisites: ${missing[*]}"
        log_error "Install with: apt-get install -y ${missing[*]}"
        return 1
    fi
    
    return 0
}

# ============================================
# Directory Management
# ============================================

ensure_directories() {
    local dirs=("$@")
    
    for dir in "${dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" || {
                log_error "Failed to create directory: $dir"
                return 1
            }
        fi
    done
    
    return 0
}

# ============================================
# Formatting Utilities
# ============================================

format_duration() {
    local seconds="$1"
    local days=$((seconds / 86400))
    local hours=$(( (seconds % 86400) / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$((seconds % 60))
    
    if [[ $days -gt 0 ]]; then
        printf "%dd %dh %dm %ds" "$days" "$hours" "$minutes" "$secs"
    elif [[ $hours -gt 0 ]]; then
        printf "%dh %dm %ds" "$hours" "$minutes" "$secs"
    elif [[ $minutes -gt 0 ]]; then
        printf "%dm %ds" "$minutes" "$secs"
    else
        printf "%ds" "$secs"
    fi
}

format_xdc() {
    local wei="$1"
    local xdc
    
    # Convert wei to XDC (18 decimals)
    xdc=$(echo "scale=4; $wei / 1000000000000000000" | bc 2>/dev/null || echo "0")
    printf "%.4f XDC" "$xdc"
}

# ============================================
# Logging
# ============================================

log_info() {
    echo "ℹ️  INFO: $*"
}

log_success() {
    echo "✅ SUCCESS: $*"
}

log_warn() {
    echo "⚠️  WARNING: $*"
}

log_error() {
    echo "❌ ERROR: $*" >&2
}

# ============================================
# Report Generation
# ============================================

generate_json_report() {
    local output_file="$1"
    shift
    local -n data=$1
    
    {
        echo "{"
        local first=true
        for key in "${!data[@]}"; do
            if [[ "$first" == true ]]; then
                first=false
            else
                echo ","
            fi
            printf "  \"%s\": \"%s\"" "$key" "${data[$key]}"
        done
        echo ""
        echo "}"
    } > "$output_file"
}

# ============================================
# Load Configuration
# ============================================

load_config() {
    local config_file="${1:-$HOME/.xdc-node/config}"
    
    if [[ ! -f "$config_file" ]]; then
        log_warn "Config file not found: $config_file"
        return 1
    fi
    
    # shellcheck disable=SC1090
    source "$config_file"
}
