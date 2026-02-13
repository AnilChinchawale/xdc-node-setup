#!/bin/bash
#==============================================================================
# Validation Library for XDC Node Setup
# Provides input validation, sanitization, and security checks
#==============================================================================

set -euo pipefail

# Validation error codes
readonly E_INVALID_INPUT=100
readonly E_VALIDATION_FAILED=101
readonly E_OUT_OF_RANGE=102
readonly E_PATTERN_MISMATCH=103

#==============================================================================
# String Validation
#==============================================================================

# Validate that a string matches a safe pattern
# Usage: validate_safe_string "$input" "description"
validate_safe_string() {
    local input="$1"
    local description="${2:-input}"
    local pattern='^[a-zA-Z0-9_/.:-]+$'
    
    if [[ -z "$input" ]]; then
        error "${description} cannot be empty"
        return $E_INVALID_INPUT
    fi
    
    if [[ ! "$input" =~ $pattern ]]; then
        error "${description} contains invalid characters. Allowed: alphanumeric, _, /, ., :, -"
        return $E_PATTERN_MISMATCH
    fi
    
    return 0
}

# Validate directory path (absolute, safe)
# Usage: validate_directory_path "$path"
validate_directory_path() {
    local path="$1"
    
    if [[ -z "$path" ]]; then
        error "Directory path cannot be empty"
        return $E_INVALID_INPUT
    fi
    
    # Must be absolute path
    if [[ "${path:0:1}" != "/" ]]; then
        error "Directory path must be absolute (start with /)"
        return $E_INVALID_INPUT
    fi
    
    # No parent directory traversal
    if [[ "$path" == *".."* ]]; then
        error "Directory path cannot contain parent directory references (..)"
        return $E_INVALID_INPUT
    fi
    
    # Safe characters only
    if [[ ! "$path" =~ ^[a-zA-Z0-9_/.-]+$ ]]; then
        error "Directory path contains invalid characters"
        return $E_PATTERN_MISMATCH
    fi
    
    # Check for common dangerous paths
    local dangerous_paths=("/" "/bin" "/sbin" "/usr" "/etc" "/var" "/lib" "/lib64")
    for dangerous in "${dangerous_paths[@]}"; do
        if [[ "$path" == "$dangerous" ]]; then
            error "Directory path '$path' is a system directory and not allowed"
            return $E_INVALID_INPUT
        fi
    done
    
    return 0
}

# Validate port number
# Usage: validate_port "$port"
validate_port() {
    local port="$1"
    
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        error "Port must be a number"
        return $E_INVALID_INPUT
    fi
    
    if [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
        error "Port must be between 1 and 65535"
        return $E_OUT_OF_RANGE
    fi
    
    # Check for well-known ports that require root
    if [[ "$port" -lt 1024 ]]; then
        warn "Port $port is a privileged port (requires root)"
    fi
    
    return 0
}

# Validate IP address (IPv4 or IPv6)
# Usage: validate_ip_address "$ip"
validate_ip_address() {
    local ip="$1"
    
    # IPv4 pattern
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # Validate each octet
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [[ "$octet" -gt 255 ]]; then
                error "Invalid IPv4 address: octet out of range"
                return $E_INVALID_INPUT
            fi
        done
        return 0
    fi
    
    # IPv6 pattern (simplified)
    if [[ "$ip" =~ ^[0-9a-fA-F:]+$ ]] && [[ "$ip" == *":"* ]]; then
        return 0
    fi
    
    error "Invalid IP address format"
    return $E_INVALID_INPUT
}

# Validate hostname/FQDN
# Usage: validate_hostname "$hostname"
validate_hostname() {
    local hostname="$1"
    local pattern='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
    
    if [[ -z "$hostname" ]]; then
        error "Hostname cannot be empty"
        return $E_INVALID_INPUT
    fi
    
    if [[ ${#hostname} -gt 253 ]]; then
        error "Hostname too long (max 253 characters)"
        return $E_INVALID_INPUT
    fi
    
    if [[ ! "$hostname" =~ $pattern ]]; then
        error "Invalid hostname format"
        return $E_PATTERN_MISMATCH
    fi
    
    return 0
}

# Validate email address
# Usage: validate_email "$email"
validate_email() {
    local email="$1"
    local pattern='^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    
    if [[ ! "$email" =~ $pattern ]]; then
        error "Invalid email address format"
        return $E_PATTERN_MISMATCH
    fi
    
    return 0
}

#==============================================================================
# Numeric Validation
#==============================================================================

# Validate integer within range
# Usage: validate_int_range "$value" "$min" "$max" "description"
validate_int_range() {
    local value="$1"
    local min="$2"
    local max="$3"
    local description="${4:-value}"
    
    if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
        error "${description} must be an integer"
        return $E_INVALID_INPUT
    fi
    
    if [[ "$value" -lt "$min" || "$value" -gt "$max" ]]; then
        error "${description} must be between $min and $max"
        return $E_OUT_OF_RANGE
    fi
    
    return 0
}

# Validate percentage (0-100)
# Usage: validate_percentage "$value" "description"
validate_percentage() {
    local value="$1"
    local description="${2:-percentage}"
    validate_int_range "$value" 0 100 "$description"
}

# Validate non-negative integer
# Usage: validate_non_negative_int "$value" "description"
validate_non_negative_int() {
    local value="$1"
    local description="${2:-value}"
    
    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
        error "${description} must be a non-negative integer"
        return $E_INVALID_INPUT
    fi
    
    return 0
}

#==============================================================================
# File/Path Validation
#==============================================================================

# Validate file exists and is readable
# Usage: validate_file_readable "$filepath"
validate_file_readable() {
    local filepath="$1"
    
    if [[ ! -e "$filepath" ]]; then
        error "File does not exist: $filepath"
        return $E_INVALID_INPUT
    fi
    
    if [[ ! -f "$filepath" ]]; then
        error "Path is not a file: $filepath"
        return $E_INVALID_INPUT
    fi
    
    if [[ ! -r "$filepath" ]]; then
        error "File is not readable: $filepath"
        return $E_INVALID_INPUT
    fi
    
    return 0
}

# Validate file exists and is writable
# Usage: validate_file_writable "$filepath"
validate_file_writable() {
    local filepath="$1"
    local dirpath
    dirpath=$(dirname "$filepath")
    
    if [[ -e "$filepath" && ! -w "$filepath" ]]; then
        error "File is not writable: $filepath"
        return $E_INVALID_INPUT
    fi
    
    if [[ ! -d "$dirpath" ]]; then
        error "Directory does not exist: $dirpath"
        return $E_INVALID_INPUT
    fi
    
    if [[ ! -w "$dirpath" ]]; then
        error "Directory is not writable: $dirpath"
        return $E_INVALID_INPUT
    fi
    
    return 0
}

# Validate URL format
# Usage: validate_url "$url"
validate_url() {
    local url="$1"
    local pattern='^https?://[a-zA-Z0-9][-a-zA-Z0-9]*[a-zA-Z0-9](\.[a-zA-Z0-9][-a-zA-Z0-9]*[a-zA-Z0-9])*(:[0-9]+)?(/[-a-zA-Z0-9_./?&=+%~#]*)?$'
    
    if [[ ! "$url" =~ $pattern ]]; then
        error "Invalid URL format"
        return $E_PATTERN_MISMATCH
    fi
    
    return 0
}

#==============================================================================
# Sanitization Functions
#==============================================================================

# Sanitize string for use in filenames
# Usage: sanitized=$(sanitize_filename "$input")
sanitize_filename() {
    local input="$1"
    # Remove or replace dangerous characters
    echo "$input" | tr -cd 'a-zA-Z0-9_.-' | tr ' ' '_'
}

# Sanitize string for use in SQL (basic - use parameterized queries instead)
# Usage: sanitized=$(sanitize_sql_identifier "$input")
sanitize_sql_identifier() {
    local input="$1"
    # Only allow alphanumeric and underscore
    echo "$input" | tr -cd 'a-zA-Z0-9_'
}

# Escape string for use in JSON
# Usage: escaped=$(escape_json "$input")
escape_json() {
    local input="$1"
    printf '%s' "$input" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()), end="")'
}

#==============================================================================
# Security Validation
#==============================================================================

# Validate that input doesn't contain shell metacharacters
# Usage: validate_no_shell_metachars "$input" "description"
validate_no_shell_metachars() {
    local input="$1"
    local description="${2:-input}"
    
    # Check for common shell metacharacters
    if [[ "$input" =~ [\;\&\|\`\$\(\)\<\>\\] ]]; then
        error "${description} contains shell metacharacters"
        return $E_INVALID_INPUT
    fi
    
    return 0
}

# Validate API key format
# Usage: validate_api_key "$key"
validate_api_key() {
    local key="$1"
    
    if [[ -z "$key" ]]; then
        error "API key cannot be empty"
        return $E_INVALID_INPUT
    fi
    
    if [[ ${#key} -lt 32 ]]; then
        error "API key too short (min 32 characters)"
        return $E_INVALID_INPUT
    fi
    
    return 0
}

#==============================================================================
# Interactive Input with Validation
#==============================================================================

# Prompt for input with validation
# Usage: value=$(prompt_validated "Enter port" "validate_port")
prompt_validated() {
    local prompt="$1"
    local validator="$2"
    local default_value="${3:-}"
    local max_attempts="${4:-3}"
    local value
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if [[ -n "$default_value" ]]; then
            read -rp "$prompt [$default_value]: " value
            value="${value:-$default_value}"
        else
            read -rp "$prompt: " value
        fi
        
        if $validator "$value"; then
            echo "$value"
            return 0
        fi
        
        ((attempt++))
        echo "Invalid input. $((max_attempts - attempt)) attempts remaining." >&2
    done
    
    error "Maximum validation attempts exceeded"
    return $E_VALIDATION_FAILED
}

#==============================================================================
# Logging Helpers (to be used with structured logging)
#==============================================================================

error() {
    echo -e "\033[0;31m✗ $1\033[0m" >&2
}

warn() {
    echo -e "\033[1;33m⚠ $1\033[0m" >&2
}

info() {
    echo -e "\033[0;34mℹ $1\033[0m"
}

#==============================================================================
# Export functions if sourced
#==============================================================================

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    export -f validate_safe_string
    export -f validate_directory_path
    export -f validate_port
    export -f validate_ip_address
    export -f validate_hostname
    export -f validate_email
    export -f validate_int_range
    export -f validate_percentage
    export -f validate_non_negative_int
    export -f validate_file_readable
    export -f validate_file_writable
    export -f validate_url
    export -f sanitize_filename
    export -f sanitize_sql_identifier
    export -f escape_json
    export -f validate_no_shell_metachars
    export -f validate_api_key
    export -f prompt_validated
fi
