#!/bin/bash
# XDC Snapshot Manager with Resume Support
# Issue #489: Automated Snapshot Download with Resume Support

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
readonly CONFIG_FILE="${XDC_CONFIG_DIR:-$HOME/.xdc-node}/snapshot.conf"

# Default configuration
SNAPSHOT_URL="${SNAPSHOT_URL:-https://snapshots.xdc.network}"
SNAPSHOT_DIR="${SNAPSHOT_DIR:-./snapshots}"
DATA_DIR="${DATA_DIR:-./xdcchain}"
CLIENT_TYPE="${CLIENT_TYPE:-geth}"
NETWORK="${NETWORK:-mainnet}"
PARALLEL_DOWNLOADS="${PARALLEL_DOWNLOADS:-4}"
MAX_RETRIES="${MAX_RETRIES:-3}"

# Logging
log() { echo "[$(date -Iseconds)] $*"; }
info() { log "INFO: $*"; }
warn() { log "WARN: $*" &&2; }
error() { log "ERROR: $*" &&2; }

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        info "Loaded configuration from $CONFIG_FILE"
    fi
}

# Get snapshot metadata
get_snapshot_info() {
    local client=$1
    local network=$2
    
    local metadata_url="${SNAPSHOT_URL}/${network}/${client}/latest.json"
    local metadata
    
    metadata=$(curl -sfL --max-time 30 "$metadata_url" 2>/dev/null || echo '{}')
    
    echo "$metadata" | jq -r '{
        url: .url,
        filename: .filename,
        size: .size,
        checksum: .checksum,
        checksum_algo: (.checksum_algo // "sha256"),
        blocks: .blocks,
        created: .created,
        compression: (.compression // "zst")
    } | @json' 2>/dev/null || echo '{}'
}

# Download with resume support
download_with_resume() {
    local url=$1
    local output=$2
    local expected_size=${3:-0}
    
    local temp_file="${output}.part"
    local retry_count=0
    
    # Check for partial download
    local resume_from=0
    if [[ -f "$temp_file" ]]; then
        local partial_size
        partial_size=$(stat -c%s "$temp_file" 2>/dev/null || stat -f%z "$temp_file" 2>/dev/null || echo 0)
        resume_from=$partial_size
        info "Resuming download from byte $resume_from"
    fi
    
    while [[ $retry_count -lt $MAX_RETRIES ]]; do
        info "Downloading: $url (attempt $((retry_count + 1))/$MAX_RETRIES)"
        
        if curl -fL -C - -o "$temp_file" \
            --max-time 3600 \
            --connect-timeout 30 \
            --retry 2 \
            --retry-delay 5 \
            --progress-bar \
            -H "Range: bytes=${resume_from}-" \
            "$url" 2>&1; then
            
            mv "$temp_file" "$output"
            info "Download completed: $output"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        warn "Download failed, retrying in 10 seconds..."
        sleep 10
        
        # Update resume position
        if [[ -f "$temp_file" ]]; then
            resume_from=$(stat -c%s "$temp_file" 2>/dev/null || stat -f%z "$temp_file" 2>/dev/null || echo 0)
        fi
    done
    
    error "Download failed after $MAX_RETRIES attempts"
    return 1
}

# Verify checksum
verify_checksum() {
    local file=$1
    local expected=$2
    local algo=${3:-sha256}
    
    info "Verifying $algo checksum..."
    
    local actual
    case $algo in
        sha256)
            actual=$(sha256sum "$file" | awk '{print $1}')
            ;;
        sha512)
            actual=$(sha512sum "$file" | awk '{print $1}')
            ;;
        md5)
            actual=$(md5sum "$file" | awk '{print $1}')
            ;;
        *)
            error "Unknown checksum algorithm: $algo"
            return 1
            ;;
    esac
    
    if [[ "$actual" == "$expected" ]]; then
        info "Checksum verified ✓"
        return 0
    else
        error "Checksum mismatch!"
        error "  Expected: $expected"
        error "  Actual:   $actual"
        return 1
    fi
}

# Extract snapshot based on compression
extract_snapshot() {
    local archive=$1
    local dest=$2
    local compression=$3
    
    info "Extracting snapshot to $dest..."
    mkdir -p "$dest"
    
    case $compression in
        zst|zstd)
            if command -v zstd >/dev/null 2>&1; then
                zstd -d --stdout "$archive" | tar -xf - -C "$dest"
            else
                error "zstd not installed. Install with: apt install zstd"
                return 1
            fi
            ;;
        gz|gzip)
            tar -xzf "$archive" -C "$dest"
            ;;
        xz)
            tar -xJf "$archive" -C "$dest"
            ;;
        lz4)
            if command -v lz4 >/dev/null 2>&1; then
                lz4 -d "$archive" - | tar -xf - -C "$dest"
            else
                error "lz4 not installed. Install with: apt install lz4"
                return 1
            fi
            ;;
        *)
            error "Unknown compression: $compression"
            return 1
            ;;
    esac
    
    info "Extraction completed"
}

# Main download function
download_snapshot() {
    info "Fetching snapshot info for $CLIENT_TYPE on $NETWORK..."
    
    local snapshot_info
    snapshot_info=$(get_snapshot_info "$CLIENT_TYPE" "$NETWORK")
    
    if [[ "$snapshot_info" == "{}" ]]; then
        error "No snapshot available for $CLIENT_TYPE/$NETWORK"
        return 1
    fi
    
    local url filename size checksum checksum_algo blocks created compression
    url=$(echo "$snapshot_info" | jq -r '.url')
    filename=$(echo "$snapshot_info" | jq -r '.filename')
    size=$(echo "$snapshot_info" | jq -r '.size')
    checksum=$(echo "$snapshot_info" | jq -r '.checksum')
    checksum_algo=$(echo "$snapshot_info" | jq -r '.checksum_algo')
    blocks=$(echo "$snapshot_info" | jq -r '.blocks')
    created=$(echo "$snapshot_info" | jq -r '.created')
    compression=$(echo "$snapshot_info" | jq -r '.compression')
    
    info "Snapshot: $filename"
    info "Size: $(numfmt --to=iec-i "$size" 2>/dev/null || echo "$size bytes")"
    info "Blocks: $blocks"
    info "Created: $created"
    
    local output="$SNAPSHOT_DIR/$filename"
    mkdir -p "$SNAPSHOT_DIR"
    
    # Check if already downloaded
    if [[ -f "$output" ]]; then
        info "File exists, verifying..."
        if verify_checksum "$output" "$checksum" "$checksum_algo"; then
            info "Existing file is valid"
            echo "$output"
            return 0
        else
            warn "Existing file is corrupt, re-downloading..."
            rm -f "$output"
        fi
    fi
    
    # Download with resume
    if ! download_with_resume "$url" "$output" "$size"; then
        return 1
    fi
    
    # Verify checksum
    if ! verify_checksum "$output" "$checksum" "$checksum_algo"; then
        rm -f "$output"
        return 1
    fi
    
    echo "$output"
    return 0
}

# Auto-repair: download and verify with retry
auto_repair_snapshot() {
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        info "Auto-repair attempt $attempt/$max_attempts..."
        
        if download_snapshot; then
            info "✓ Snapshot downloaded and verified successfully"
            return 0
        fi
        
        ((attempt++))
        sleep 10
    done
    
    error "Failed to download valid snapshot after $max_attempts attempts"
    return 1
}

# Show help
show_help() {
    echo "XDC Snapshot Manager v$SCRIPT_VERSION"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  download              Download latest snapshot"
    echo "  extract <archive>    Extract snapshot archive"
    echo "  verify <file> <checksum> [algo]  Verify file checksum"
    echo "  auto-repair           Download with auto-retry"
    echo ""
    echo "Environment Variables:"
    echo "  CLIENT_TYPE          Client type (geth, erigon, nethermind, reth)"
    echo "  NETWORK              Network (mainnet, testnet)"
    echo "  SNAPSHOT_URL         Snapshot server URL"
    echo "  DATA_DIR             Destination for extracted data"
    echo "  SNAPSHOT_DIR         Directory for downloaded snapshots"
}

# CLI interface
case "${1:-}" in
    download)
        load_config
        download_snapshot
        ;;
    extract)
        if [[ -z "${2:-}" ]]; then
            error "Usage: $0 extract <archive>"
            exit 1
        fi
        load_config
        extract_snapshot "$2" "$DATA_DIR" "${3:-zst}"
        ;;
    verify)
        file="${2:-}"
        checksum="${3:-}"
        algo="${4:-sha256}"
        if [[ -z "$file" ]] || [[ -z "$checksum" ]]; then
            error "Usage: $0 verify <file> <checksum> [algorithm]"
            exit 1
        fi
        verify_checksum "$file" "$checksum" "$algo"
        ;;
    auto-repair)
        load_config
        auto_repair_snapshot
        ;;
    *)
        show_help
        exit 1
        ;;
esac
