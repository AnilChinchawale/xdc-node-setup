#!/bin/bash
#===============================================================================
# Common Utilities Library for XDC Node Docker Scripts
# Shared functions across mainnet, apothem, testnet, and devnet start scripts
#===============================================================================

# Prevent multiple sourcing
[[ -n "${XDC_COMMON_SOURCED:-}" ]] && return 0
XDC_COMMON_SOURCED=1

#===============================================================================
# Configuration Loading
# Supports: .conf (bash), .toml (TOML), .json (JSON)
#===============================================================================

load_config() {
    local config_file="$1"
    local ext="${config_file##*.}"
    
    case "$ext" in
        conf|sh)
            # shellcheck source=/dev/null
            source "$config_file"
            echo "Loaded bash config from $config_file"
            ;;
        toml)
            # Section-aware TOML parser - prefixes keys with section name
            local section=""
            while IFS= read -r line; do
                # Skip comments and empty lines
                [[ "$line" =~ ^[[:space:]]*# ]] && continue
                [[ -z "${line// /}" ]] && continue
                
                # Track section headers like [Node.HTTP]
                if [[ "$line" =~ ^[[:space:]]*\[([^]]+)\] ]]; then
                    section="${BASH_REMATCH[1]}"
                    # Normalize: Node.HTTP → HTTP, Node.WS → WS, Node.P2P → P2P
                    section="${section##*.}"
                    continue
                fi
                
                # Parse key = "value" or key = number (skip arrays)
                if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
                    local key="${BASH_REMATCH[1]}"
                    local value="${BASH_REMATCH[2]}"
                    # Skip array values
                    [[ "$value" == "["* ]] && continue
                    # Remove quotes if present
                    value="${value%\"}"
                    value="${value#\"}"
                    # Remove trailing comments
                    value="${value%%#*}"
                    # Remove quotes if present
                    value="${value%\"}"
                    value="${value#\"}"
                    # Remove ALL trailing whitespace
                    value="${value%% }"
                    while [[ "$value" =~ [[:space:]]$ ]]; do value="${value%?}"; done
                    # Export both section-prefixed and plain key
                    local ukey="${key^^}"
                    local usection="${section^^}"
                    [[ -n "$section" ]] && export "${usection}_${ukey}=$value"
                    export "${ukey}=$value"
                fi
            done < "$config_file"
            echo "Loaded TOML config from $config_file"
            ;;
        json)
            # Simple JSON parser using jq if available
            if command -v jq &>/dev/null; then
                while IFS='=' read -r key value; do
                    export "$key=$value"
                done < <(jq -r 'to_entries | .[] | "\(.key)=\(.value)"' "$config_file")
                echo "Loaded JSON config from $config_file"
            else
                echo "WARN: jq not available, cannot parse JSON config"
            fi
            ;;
    esac
}

# Try to load config from standard locations
# Usage: load_config_standard [custom_config_path]
load_config_standard() {
    local custom_config="${1:-}"
    local config_loaded=false
    
    for config_file in "$custom_config" "${XDC_CONFIG}" "/etc/xdc-node/config.toml" "/etc/xdc-node/xdc.conf" "/work/config.toml" "/work/xdc.conf"; do
        if [[ -f "$config_file" ]]; then
            load_config "$config_file"
            config_loaded=true
            break
        fi
    done
    
    [[ "$config_loaded" == "true" ]]
}

#===============================================================================
# XDC Binary Detection
#===============================================================================

ensure_xdc_binary() {
    # Ensure XDC binary is available (some images use XDC-mainnet instead of XDC)
    if ! command -v XDC &>/dev/null; then
        for bin in XDC-mainnet XDC-testnet XDC-devnet XDC-local; do
            if command -v "$bin" &>/dev/null; then
                for dest in /run/xdc/XDC /tmp/XDC /var/tmp/XDC /usr/bin/XDC; do 
                    cp "$(which "$bin")" "$dest" 2>/dev/null && chmod +x "$dest" 2>/dev/null && break
                done
                echo "Resolved $bin → XDC"
                break
            fi
        done
    fi
    
    command -v XDC &>/dev/null || { 
        echo "FATAL: No XDC binary found!" &>2
        exit 1
    }
}

#===============================================================================
# RPC Style Detection
# Detects XDC client version to determine flag style
# Old XDPoS (v2.x): uses --rpc, --rpcaddr, --rpcport
# New geth-based: uses --http, --http.addr, --http.port
#===============================================================================

detect_rpc_style() {
    # v2.6.8 supports --http-addr (dash) but NOT --http.addr (dot)
    # Newer geth supports --http.addr (dot)
    # Check for dot-style first (true new geth), then dash-style, then old --rpc
    if XDC --help 2>&1 | grep -q "\-\-http\.addr"; then
        echo "new"       # geth-style --http.addr --http.port
    elif XDC --help 2>&1 | grep -q "\-\-http-addr"; then
        echo "dash"      # v2.6.8 style --http-addr --http-port
    else
        echo "old"       # legacy --rpcaddr --rpcport
    fi
}

#===============================================================================
# Bootnode Loading
#===============================================================================

load_bootnodes() {
    local bootnodes_file="${1:-/work/bootnodes.list}"
    local bootnodes=""
    
    if [ -f "$bootnodes_file" ]; then
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            [ -z "$bootnodes" ] && bootnodes="$line" || bootnodes="${bootnodes},$line"
        done < "$bootnodes_file"
    fi
    
    echo "$bootnodes"
}

#===============================================================================
# Logging Helpers
#===============================================================================

log_info() {
    echo "[INFO] $1"
}

log_warn() {
    echo "[WARN] $1" &>2
}

log_error() {
    echo "[ERROR] $1" &>2
}

#===============================================================================
# Wallet/Account Management
#===============================================================================

get_or_create_wallet() {
    local datadir="${1:-/work/xdcchain}"
    local password_file="${2:-/work/.pwd}"
    local wallet=""
    
    if [ ! -d "$datadir/keystore" ] || [ -z "$(ls -A "$datadir/keystore/" 2>/dev/null)" ]; then
        # Create new account
        wallet=$(XDC account new --password "$password_file" --datadir "$datadir" 2>/dev/null | awk -F '[{}]' '{print $2}')
        if [ -n "$wallet" ]; then
            echo "$wallet" > "$datadir/coinbase.txt"
        fi
    else
        # Get existing account
        wallet=$(XDC account list --datadir "$datadir" 2>/dev/null | head -n 1 | awk -F '[{}]' '{print $2}')
    fi
    
    echo "$wallet"
}

#===============================================================================
# Network Detection
#===============================================================================

get_network_name() {
    local chain_id="$1"
    case "$chain_id" in
        50) echo "mainnet" ;;
        51) echo "apothem" ;;
        551) echo "devnet" ;;
        *) echo "unknown" ;;
    esac
}

# Export functions for use in other scripts
export -f load_config load_config_standard 2>/dev/null || true
export -f ensure_xdc_binary 2>/dev/null || true
export -f detect_rpc_style 2>/dev/null || true
export -f load_bootnodes 2>/dev/null || true
export -f log_info log_warn log_error 2>/dev/null || true
export -f get_or_create_wallet 2>/dev/null || true
export -f get_network_name 2>/dev/null || true
