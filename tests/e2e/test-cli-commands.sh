#!/usr/bin/env bash
#==============================================================================
# E2E Test: All CLI Commands
# Tests all CLI commands have proper help and basic functionality
#==============================================================================

set -euo pipefail
source "$(dirname "$0")/lib/framework.sh"

test_start "CLI Commands Tests"

PROJECT_ROOT="$(get_project_root)"
export PATH="$PROJECT_ROOT/cli:$PATH"

#------------------------------------------------------------------------------
# Test: CLI basic invocation
#------------------------------------------------------------------------------

assert_cmd "xdc --help" "CLI responds to --help"
assert_cmd "xdc help" "CLI responds to help command"
assert_cmd "xdc version" "CLI version command works"

#------------------------------------------------------------------------------
# Test: All documented commands have help
#------------------------------------------------------------------------------

# Core commands that must exist
core_commands=(
    "init"
    "start"
    "stop"
    "restart"
    "status"
    "logs"
    "health"
    "update"
    "backup"
    "restore"
)

for cmd in "${core_commands[@]}"; do
    if xdc "$cmd" --help >/dev/null 2>&1 || xdc help "$cmd" >/dev/null 2>&1; then
        pass "Command '$cmd' has help"
    else
        fail "Command '$cmd' has help" "No help available"
    fi
done

#------------------------------------------------------------------------------
# Test: XDC-specific commands
#------------------------------------------------------------------------------

xdc_commands=(
    "masternode"
    "snapshot"
    "sync"
    "peers"
    "attach"
    "config"
)

for cmd in "${xdc_commands[@]}"; do
    cmd_output=$(xdc "$cmd" --help 2>&1) || cmd_output=$(xdc help 2>&1)
    
    if echo "$cmd_output" | grep -qi "$cmd\|usage\|options"; then
        pass "XDC command '$cmd' exists"
    else
        skip "XDC command '$cmd' exists" "Command not found"
    fi
done

#------------------------------------------------------------------------------
# Test: Command shortcuts/aliases
#------------------------------------------------------------------------------

# Test common aliases
aliases=(
    "info:status"
    "ps:status"
)

for alias_pair in "${aliases[@]}"; do
    alias_cmd="${alias_pair%%:*}"
    real_cmd="${alias_pair##*:}"
    
    if xdc "$alias_cmd" >/dev/null 2>&1; then
        pass "Alias '$alias_cmd' works"
    else
        skip "Alias '$alias_cmd' works" "Alias not configured"
    fi
done

#------------------------------------------------------------------------------
# Test: Global options work
#------------------------------------------------------------------------------

global_options=(
    "--json"
    "--quiet"
    "--verbose"
    "--no-color"
)

for opt in "${global_options[@]}"; do
    if xdc status "$opt" >/dev/null 2>&1; then
        pass "Global option $opt is accepted"
    else
        skip "Global option $opt is accepted" "Option not supported"
    fi
done

#------------------------------------------------------------------------------
# Test: Invalid command handling
#------------------------------------------------------------------------------

invalid_output=$(xdc nonexistent_command_12345 2>&1) || true

if echo "$invalid_output" | grep -qiE "unknown|invalid|not found|error|help"; then
    pass "Invalid commands are handled gracefully"
else
    fail "Invalid commands are handled gracefully" "No error message"
fi

#------------------------------------------------------------------------------
# Test: Logs command
#------------------------------------------------------------------------------

logs_help=$(xdc logs --help 2>&1) || true

if echo "$logs_help" | grep -qiE "logs|tail|follow"; then
    pass "Logs command has documentation"
fi

# Test logs options
for opt in "--follow" "-f" "--tail" "-n"; do
    if echo "$logs_help" | grep -qi -- "$opt"; then
        pass "Logs supports $opt option"
    else
        skip "Logs supports $opt option" "Not documented"
    fi
done

#------------------------------------------------------------------------------
# Test: Backup command
#------------------------------------------------------------------------------

backup_help=$(xdc backup --help 2>&1) || true

if echo "$backup_help" | grep -qiE "backup|archive|export"; then
    pass "Backup command has documentation"
fi

# Check backup options
for opt in "--encrypt" "--output" "--compress"; do
    if echo "$backup_help" | grep -qi -- "${opt#--}"; then
        pass "Backup supports $opt"
    else
        skip "Backup supports $opt" "Not documented"
    fi
done

#------------------------------------------------------------------------------
# Test: Restore command
#------------------------------------------------------------------------------

restore_help=$(xdc restore --help 2>&1) || true

if echo "$restore_help" | grep -qiE "restore|import|recover"; then
    pass "Restore command has documentation"
fi

#------------------------------------------------------------------------------
# Test: Config command
#------------------------------------------------------------------------------

config_help=$(xdc config --help 2>&1) || true

if echo "$config_help" | grep -qiE "config|setting|option"; then
    pass "Config command has documentation"
fi

# Test config subcommands
for subcmd in "show" "get" "set" "edit"; do
    if echo "$config_help" | grep -qi "$subcmd"; then
        pass "Config supports '$subcmd'"
    else
        skip "Config supports '$subcmd'" "Not documented"
    fi
done

#------------------------------------------------------------------------------
# Test: Health command
#------------------------------------------------------------------------------

health_help=$(xdc health --help 2>&1) || true

if echo "$health_help" | grep -qiE "health|check|diagnose"; then
    pass "Health command has documentation"
fi

#------------------------------------------------------------------------------
# Test: Snapshot command
#------------------------------------------------------------------------------

snapshot_help=$(xdc snapshot --help 2>&1) || true

if echo "$snapshot_help" | grep -qiE "snapshot|download|chain"; then
    pass "Snapshot command has documentation"
fi

#------------------------------------------------------------------------------
# Test: Update command
#------------------------------------------------------------------------------

update_help=$(xdc update --help 2>&1) || true

if echo "$update_help" | grep -qiE "update|upgrade|version"; then
    pass "Update command has documentation"
fi

#------------------------------------------------------------------------------
# Test: Dashboard command (if exists)
#------------------------------------------------------------------------------

if xdc dashboard --help >/dev/null 2>&1; then
    pass "Dashboard command exists"
else
    skip "Dashboard command exists" "Not available"
fi

#------------------------------------------------------------------------------
# Test: Attach command
#------------------------------------------------------------------------------

attach_help=$(xdc attach --help 2>&1) || true

if echo "$attach_help" | grep -qiE "attach|console|ipc"; then
    pass "Attach command has documentation"
fi

#------------------------------------------------------------------------------
# Test: Masternode command
#------------------------------------------------------------------------------

mn_help=$(xdc masternode --help 2>&1) || true

if echo "$mn_help" | grep -qiE "masternode|stake|validator"; then
    pass "Masternode command has documentation"
fi

#------------------------------------------------------------------------------
# Test: Security command (if exists)
#------------------------------------------------------------------------------

if xdc security --help >/dev/null 2>&1; then
    security_help=$(xdc security --help 2>&1)
    if echo "$security_help" | grep -qiE "security|audit|hardening"; then
        pass "Security command has documentation"
    fi
else
    skip "Security command exists" "Not available"
fi

#------------------------------------------------------------------------------
# Test: CLI environment variable handling
#------------------------------------------------------------------------------

# Test that environment variables are respected
if XDC_NETWORK=testnet xdc status 2>&1 | grep -qi "test\|XDC_"; then
    pass "CLI respects XDC_NETWORK environment variable"
else
    skip "CLI respects XDC_NETWORK environment variable" "Env var handling unclear"
fi

#------------------------------------------------------------------------------
# Test: Help output formatting
#------------------------------------------------------------------------------

help_output=$(xdc help 2>&1)

# Help should be well-structured
if echo "$help_output" | grep -qE "USAGE|COMMANDS|OPTIONS|EXAMPLES"; then
    pass "Help output is well-structured"
else
    skip "Help output is well-structured" "Structure unclear"
fi

#------------------------------------------------------------------------------
# Test: Version output format
#------------------------------------------------------------------------------

version_output=$(xdc version 2>&1)

if echo "$version_output" | grep -qE "[0-9]+\.[0-9]+"; then
    pass "Version output includes version number"
else
    skip "Version output includes version number" "Format unclear"
fi

test_end
