#!/bin/bash
#===============================================================================
# XDC Node Setup - Shared Logging Library
# Centralizes logging functions to avoid duplication across scripts
#===============================================================================

# Prevent multiple sourcing
[[ -n "${XDC_LOGGING_SOURCED:-}" ]] && return 0
XDC_LOGGING_SOURCED=1

# Default log level
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FILE="${LOG_FILE:-}"
LOG_COLORS="${LOG_COLORS:-true}"

# Log levels (numeric values for comparison)
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3
readonly LOG_LEVEL_FATAL=4

# Get numeric value for log level
_get_log_level_value() {
    case "${1^^}" in
        DEBUG) echo 0 ;;
        INFO)  echo 1 ;;
        WARN)  echo 2 ;;
        ERROR) echo 3 ;;
        FATAL) echo 4 ;;
        *)     echo 1 ;; # Default to INFO
    esac
}

# ANSI color codes
readonly COLOR_RESET='\033[0m'
readonly COLOR_DEBUG='\033[36m'   # Cyan
readonly COLOR_INFO='\033[32m'    # Green
readonly COLOR_WARN='\033[33m'    # Yellow
readonly COLOR_ERROR='\033[31m'   # Red
readonly COLOR_FATAL='\033[35m'   # Magenta

# Internal log function
_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check if we should log this level
    local level_value
    local current_level_value
    level_value=$(_get_log_level_value "$level")
    current_level_value=$(_get_log_level_value "$LOG_LEVEL")
    
    if [[ $level_value -lt $current_level_value ]]; then
        return 0
    fi
    
    # Format output
    local color=""
    local reset=""
    if [[ "$LOG_COLORS" == "true" && -t 2 ]]; then
        case "$level" in
            DEBUG) color="$COLOR_DEBUG" ;;
            INFO)  color="" ;; # No color for INFO
            WARN)  color="$COLOR_WARN" ;;
            ERROR) color="$COLOR_ERROR" ;;
            FATAL) color="$COLOR_FATAL" ;;
        esac
        reset="$COLOR_RESET"
    fi
    
    local formatted="[${timestamp}] [${level}] ${message}"
    
    # Output to stderr for WARN/ERROR/FATAL, stdout for INFO/DEBUG
    if [[ $level_value -ge $LOG_LEVEL_WARN ]]; then
        echo -e "${color}${formatted}${reset}" >&2
    else
        echo -e "${color}${formatted}${reset}"
    fi
    
    # Also log to file if specified
    if [[ -n "$LOG_FILE" ]]; then
        echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    fi
}

# Public logging functions
log_debug() { _log "DEBUG" "$*"; }
log_info()  { _log "INFO"  "$*"; }
log_warn()  { _log "WARN"  "$*"; }
log_error() { _log "ERROR" "$*"; }
log_fatal() { _log "FATAL" "$*"; }

# Short aliases (for backward compatibility)
log()    { log_info "$*"; }
info()   { log_info "$*"; }
warn()   { log_warn "$*"; }
error()  { log_error "$*"; }
die()    { log_fatal "$*"; exit 1; }

# Print banner
print_banner() {
    local title="$1"
    local width="${2:-60}"
    local char="${3:-=}"
    
    local padding=$(( (width - ${#title}) / 2 ))
    
    printf '%*s\n' "$width" '' | tr ' ' "$char"
    printf '%*s%s%*s\n' "$padding" '' "$title" "$padding" ''
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

# Print section header
print_section() {
    echo ""
    echo "=== $* ==="
    echo ""
}

# Show progress spinner
# Usage: spinner & SPINNER_PID=$!; ... ; kill $SPINNER_PID
spinner() {
    local delay=0.1
    local spinstr='|/-\\'
    while true; do
        for (( i=0; i<${#spinstr}; i++ )); do
            printf ' [%s]  ' "${spinstr:$i:1}"
            sleep "$delay"
            printf '\b\b\b\b\b\b'
        done
    done
}

# Show progress bar
# Usage: progress_bar current total [width]
progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-40}"
    
    local percentage=$(( current * 100 / total ))
    local filled=$(( width * current / total ))
    local empty=$(( width - filled ))
    
    printf '\r['
    printf '%*s' "$filled" '' | tr ' ' '#'
    printf '%*s' "$empty" '' | tr ' ' '-'
    printf '] %3d%% (%d/%d)' "$percentage" "$current" "$total"
}
