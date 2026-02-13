#!/bin/bash
#==============================================================================
# Structured JSON Logging Library for XDC Node Setup
# Provides consistent, parseable logging for observability
#==============================================================================

set -euo pipefail

# Default log level
LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_FORMAT="${LOG_FORMAT:-json}"  # json or text
LOG_OUTPUT="${LOG_OUTPUT:-stdout}"  # stdout, file, or both
LOG_FILE="${LOG_FILE:-/var/log/xdc-node/xdc-node.log}"

# Log levels (numeric for comparison)
declare -A LOG_LEVELS=(
    [DEBUG]=10
    [INFO]=20
    [WARNING]=30
    [ERROR]=40
    [FATAL]=50
)

#==============================================================================
# Core Logging Functions
#==============================================================================

# Initialize logging
init_logging() {
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" 2>/dev/null || {
            echo "Warning: Cannot create log directory $log_dir" >&2
            return 1
        }
    fi
    
    # Ensure log file exists and has proper permissions
    touch "$LOG_FILE" 2>/dev/null || {
        echo "Warning: Cannot write to log file $LOG_FILE" >&2
        return 1
    }
    
    chmod 640 "$LOG_FILE" 2>/dev/null || true
    
    log_info "Logging initialized" "{"log_file":"$LOG_FILE","level":"$LOG_LEVEL"}"
}

# Check if we should log at this level
_should_log() {
    local level="$1"
    local current_level="${LOG_LEVELS[$LOG_LEVEL]:-20}"
    local message_level="${LOG_LEVELS[$level]:-20}"
    
    [[ $message_level -ge $current_level ]]
}

# Build JSON log entry
_build_json_log() {
    local level="$1"
    local message="$2"
    local context="${3:-{}}"
    local timestamp
    timestamp=$(date -Iseconds)
    local hostname
    hostname=$(hostname)
    local script="${BASH_SOURCE[2]:-unknown}"
    local func="${FUNCNAME[2]:-main}"
    local line="${BASH_LINENO[1]:-0}"
    
    # Escape special characters in message
    local escaped_message
    escaped_message=$(echo "$message" | sed 's/"/\\"/g' | tr '\n' ' ')
    
    cat <<EOF
{"timestamp":"$timestamp","level":"$level","hostname":"$hostname","script":"$script","function":"$func","line":$line,"message":"$escaped_message","context":$context}
EOF
}

# Build text log entry
_build_text_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local script="$(basename "${BASH_SOURCE[2]:-unknown}")"
    
    echo "[$timestamp] [$level] [$script] $message"
}

# Write log entry
_write_log() {
    local log_entry="$1"
    
    case "$LOG_OUTPUT" in
        stdout)
            echo "$log_entry"
            ;;
        file)
            echo "$log_entry" >> "$LOG_FILE"
            ;;
        both)
            echo "$log_entry"
            echo "$log_entry" >> "$LOG_FILE"
            ;;
    esac
}

#==============================================================================
# Public Logging Interface
#==============================================================================

log_debug() {
    local message="$1"
    local context="${2:-{}}"
    
    if ! _should_log "DEBUG"; then return 0; fi
    
    if [[ "$LOG_FORMAT" == "json" ]]; then
        _write_log "$(_build_json_log "DEBUG" "$message" "$context")"
    else
        _write_log "$(_build_text_log "DEBUG" "$message")"
    fi
}

log_info() {
    local message="$1"
    local context="${2:-{}}"
    
    if ! _should_log "INFO"; then return 0; fi
    
    if [[ "$LOG_FORMAT" == "json" ]]; then
        _write_log "$(_build_json_log "INFO" "$message" "$context")"
    else
        # Add colors for text output
        _write_log "\033[0;32m$(_build_text_log "INFO" "$message")\033[0m"
    fi
}

log_warning() {
    local message="$1"
    local context="${2:-{}}"
    
    if ! _should_log "WARNING"; then return 0; fi
    
    if [[ "$LOG_FORMAT" == "json" ]]; then
        _write_log "$(_build_json_log "WARNING" "$message" "$context")"
    else
        _write_log "\033[1;33m$(_build_text_log "WARNING" "$message")\033[0m"
    fi
}

log_error() {
    local message="$1"
    local context="${2:-{}}"
    
    if ! _should_log "ERROR"; then return 0; fi
    
    if [[ "$LOG_FORMAT" == "json" ]]; then
        _write_log "$(_build_json_log "ERROR" "$message" "$context")" >&2
    else
        _write_log "\033[0;31m$(_build_text_log "ERROR" "$message")\033[0m" >&2
    fi
}

log_fatal() {
    local message="$1"
    local context="${2:-{}}"
    local exit_code="${3:-1}"
    
    if [[ "$LOG_FORMAT" == "json" ]]; then
        _write_log "$(_build_json_log "FATAL" "$message" "$context")" >&2
    else
        _write_log "\033[0;35m$(_build_text_log "FATAL" "$message")\033[0m" >&2
    fi
    
    exit "$exit_code"
}

#==============================================================================
# Context Building Helpers
#==============================================================================

# Build a JSON context string from key=value pairs
# Usage: context=$(build_context "key1=\"value1\"" "key2=123")
build_context() {
    local pairs=("$@")
    local json="{"
    local first=true
    
    for pair in "${pairs[@]}"; do
        if [[ "$pair" =~ ^([^=]+)=(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            if [[ "$first" == true ]]; then
                first=false
            else
                json+=","
            fi
            
            json+="\"$key\":$value"
        fi
    done
    
    json+="}"
    echo "$json"
}

# Log with node context
log_with_node() {
    local level="$1"
    local message="$2"
    local node_id="$3"
    shift 3
    
    local context
    context=$(build_context "node_id=\"$node_id\"" "$@")
    
    case "$level" in
        DEBUG) log_debug "$message" "$context" ;;
        INFO) log_info "$message" "$context" ;;
        WARNING) log_warning "$message" "$context" ;;
        ERROR) log_error "$message" "$context" ;;
        FATAL) log_fatal "$message" "$context" ;;
    esac
}

#==============================================================================
# Metrics Logging
#==============================================================================

# Log a metric event
log_metric() {
    local metric_name="$1"
    local value="$2"
    local unit="${3:-count}"
    local tags="${4:-{}}"
    
    local context
    context=$(build_context "metric_name=\"$metric_name\"" "value=$value" "unit=\"$unit\"" "tags=$tags")
    
    log_info "metric_recorded" "$context"
}

# Log an operation with timing
log_operation() {
    local operation="$1"
    local start_time="$2"
    local status="${3:-success}"
    local extra_context="${4:-{}}"
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    local context
    context=$(build_context "operation=\"$operation\"" "duration_ms=$((duration * 1000))" "status=\"$status\"" "extra=$extra_context")
    
    log_info "operation_completed" "$context"
}

#==============================================================================
# Audit Logging
#==============================================================================

# Log security-relevant events
log_audit() {
    local action="$1"
    local user="${2:-$(whoami)}"
    local resource="$3"
    local result="$4"
    shift 4
    
    local context
    context=$(build_context "action=\"$action\"" "user=\"$user\"" "resource=\"$resource\"" "result=\"$result\"" "$@")
    
    log_info "audit_event" "$context"
}

#==============================================================================
# Export Functions
#==============================================================================

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f init_logging
    export -f log_debug
    export -f log_info
    export -f log_warning
    export -f log_error
    export -f log_fatal
    export -f build_context
    export -f log_with_node
    export -f log_metric
    export -f log_operation
    export -f log_audit
fi
