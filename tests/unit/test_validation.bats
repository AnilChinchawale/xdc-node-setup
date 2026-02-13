#!/usr/bin/env bats
#==============================================================================
# Unit Tests for XDC Node Setup Scripts
# Requires: bats-core, bats-assert, bats-support
# Run: bats tests/
#==============================================================================

setup() {
    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)/../scripts"
    LIB_DIR="$SCRIPT_DIR/lib"
    
    # Source the library
    source "$LIB_DIR/validation.sh"
    source "$LIB_DIR/logging.sh"
    
    # Create temp directory for tests
    TEST_TEMP_DIR=$(mktemp -d)
}

teardown() {
    # Cleanup temp directory
    rm -rf "$TEST_TEMP_DIR"
}

#==============================================================================
# Validation Tests
#==============================================================================

@test "validate_safe_string accepts valid strings" {
    run validate_safe_string "hello_world" "test"
    [ "$status" -eq 0 ]
    
    run validate_safe_string "/path/to/file" "path"
    [ "$status" -eq 0 ]
    
    run validate_safe_string "node-123_456" "id"
    [ "$status" -eq 0 ]
}

@test "validate_safe_string rejects empty strings" {
    run validate_safe_string "" "test"
    [ "$status" -eq 100 ]
}

@test "validate_safe_string rejects strings with special characters" {
    run validate_safe_string "hello;world" "test"
    [ "$status" -eq 103 ]
    
    run validate_safe_string "hello|world" "test"
    [ "$status" -eq 103 ]
    
    run validate_safe_string "hello\`world" "test"
    [ "$status" -eq 103 ]
}

@test "validate_directory_path accepts valid absolute paths" {
    run validate_directory_path "/opt/xdc-node/data"
    [ "$status" -eq 0 ]
    
    run validate_directory_path "/var/lib/xdc"
    [ "$status" -eq 0 ]
}

@test "validate_directory_path rejects relative paths" {
    run validate_directory_path "./data"
    [ "$status" -eq 100 ]
    
    run validate_directory_path "xdcchain"
    [ "$status" -eq 100 ]
}

@test "validate_directory_path rejects paths with parent directory traversal" {
    run validate_directory_path "/opt/../etc/passwd"
    [ "$status" -eq 100 ]
    
    run validate_directory_path "/var/lib/.."
    [ "$status" -eq 100 ]
}

@test "validate_directory_path rejects system directories" {
    run validate_directory_path "/"
    [ "$status" -eq 100 ]
    
    run validate_directory_path "/etc"
    [ "$status" -eq 100 ]
    
    run validate_directory_path "/bin"
    [ "$status" -eq 100 ]
}

@test "validate_port accepts valid ports" {
    run validate_port "8545"
    [ "$status" -eq 0 ]
    
    run validate_port "30303"
    [ "$status" -eq 0 ]
    
    run validate_port "1"
    [ "$status" -eq 0 ]
    
    run validate_port "65535"
    [ "$status" -eq 0 ]
}

@test "validate_port rejects invalid ports" {
    run validate_port "0"
    [ "$status" -eq 102 ]
    
    run validate_port "65536"
    [ "$status" -eq 102 ]
    
    run validate_port "abc"
    [ "$status" -eq 100 ]
    
    run validate_port ""
    [ "$status" -eq 100 ]
}

@test "validate_port warns on privileged ports" {
    run validate_port "22"
    [ "$status" -eq 0 ]
    [[ "$output" == *"privileged port"* ]]
}

@test "validate_ip_address accepts valid IPv4" {
    run validate_ip_address "192.168.1.1"
    [ "$status" -eq 0 ]
    
    run validate_ip_address "10.0.0.1"
    [ "$status" -eq 0 ]
    
    run validate_ip_address "0.0.0.0"
    [ "$status" -eq 0 ]
    
    run validate_ip_address "255.255.255.255"
    [ "$status" -eq 0 ]
}

@test "validate_ip_address rejects invalid IPv4" {
    run validate_ip_address "256.1.1.1"
    [ "$status" -eq 100 ]
    
    run validate_ip_address "192.168.1"
    [ "$status" -eq 100 ]
    
    run validate_ip_address "192.168.1.1.1"
    [ "$status" -eq 100 ]
}

@test "validate_hostname accepts valid hostnames" {
    run validate_hostname "localhost"
    [ "$status" -eq 0 ]
    
    run validate_hostname "xdc-node-01"
    [ "$status" -eq 0 ]
    
    run validate_hostname "rpc.xdc.network"
    [ "$status" -eq 0 ]
    
    run validate_hostname "node.example.com"
    [ "$status" -eq 0 ]
}

@test "validate_hostname rejects invalid hostnames" {
    run validate_hostname ""
    [ "$status" -eq 100 ]
    
    run validate_hostname "-invalid"
    [ "$status" -eq 100 ]
    
    run validate_hostname "invalid-"
    [ "$status" -eq 100 ]
}

@test "validate_percentage accepts valid percentages" {
    run validate_percentage "0"
    [ "$status" -eq 0 ]
    
    run validate_percentage "50"
    [ "$status" -eq 0 ]
    
    run validate_percentage "100"
    [ "$status" -eq 0 ]
}

@test "validate_percentage rejects invalid percentages" {
    run validate_percentage "-1"
    [ "$status" -eq 102 ]
    
    run validate_percentage "101"
    [ "$status" -eq 102 ]
    
    run validate_percentage "abc"
    [ "$status" -eq 100 ]
}

@test "validate_no_shell_metachars rejects dangerous input" {
    run validate_no_shell_metachars "hello; rm -rf /"
    [ "$status" -eq 100 ]
    
    run validate_no_shell_metachars 'hello | cat /etc/passwd'
    [ "$status" -eq 100 ]
    
    run validate_no_shell_metachars 'hello`whoami`'
    [ "$status" -eq 100 ]
    
    run validate_no_shell_metachars 'hello$(id)'
    [ "$status" -eq 100 ]
}

#==============================================================================
# Sanitization Tests
#==============================================================================

@test "sanitize_filename removes dangerous characters" {
    result=$(sanitize_filename "file;name.txt")
    [ "$result" = "filename.txt" ]
    
    result=$(sanitize_filename "file name.txt")
    [ "$result" = "file_name.txt" ]
    
    result=$(sanitize_filename '../../etc/passwd')
    [ "$result" = "etcpasswd" ]
}

@test "sanitize_sql_identifier removes non-alphanumeric" {
    result=$(sanitize_sql_identifier "table; DROP users--")
    [ "$result" = "tableDROPyusers" ]
}

#==============================================================================
# Logging Tests
#==============================================================================

@test "build_context creates valid JSON" {
    result=$(build_context 'key1="value1"' 'key2=123')
    [ "$result" = '{"key1":"value1","key2":123}' ]
}

@test "logging functions respect LOG_LEVEL" {
    LOG_LEVEL="ERROR"
    
    # Debug and info should not output
    run log_debug "debug message"
    [ -z "$output" ]
    
    # Error should output
    run log_error "error message"
    [[ "$output" == *"error message"* ]]
}

#==============================================================================
# Integration Tests
#==============================================================================

@test "validate_config.sh exists and is executable" {
    [ -x "$SCRIPT_DIR/validate-config.sh" ]
}

@test "validate_config.sh generates valid sample config" {
    run "$SCRIPT_DIR/validate-config.sh" sample
    [ "$status" -eq 0 ]
    
    # Should be valid JSON
    echo "$output" | jq empty
}

@test "config schema exists and is valid JSON" {
    [ -f "$(dirname "$SCRIPT_DIR")/configs/schema.json" ]
    jq empty "$(dirname "$SCRIPT_DIR")/configs/schema.json"
}
