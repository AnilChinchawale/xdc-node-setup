#!/usr/bin/env bash
#==============================================================================
# E2E Test: Fresh Install on Clean System
# Tests the install process on a clean system
#==============================================================================

set -euo pipefail
source "$(dirname "$0")/lib/framework.sh"

test_start "Fresh Install Tests"

PROJECT_ROOT="$(get_project_root)"

#------------------------------------------------------------------------------
# Test: Install script exists and is executable
#------------------------------------------------------------------------------

assert_file_exists "$PROJECT_ROOT/install.sh" "Install script exists"
assert_file_executable "$PROJECT_ROOT/install.sh" "Install script is executable"

#------------------------------------------------------------------------------
# Test: CLI exists and is executable
#------------------------------------------------------------------------------

assert_file_exists "$PROJECT_ROOT/cli/xdc" "CLI binary exists"
assert_file_executable "$PROJECT_ROOT/cli/xdc" "CLI is executable"

#------------------------------------------------------------------------------
# Test: setup.sh exists and is executable
#------------------------------------------------------------------------------

assert_file_exists "$PROJECT_ROOT/setup.sh" "Setup script exists"
assert_file_executable "$PROJECT_ROOT/setup.sh" "Setup script is executable"

#------------------------------------------------------------------------------
# Test: Required directories exist
#------------------------------------------------------------------------------

assert_dir_exists "$PROJECT_ROOT/docker" "Docker directory exists"
assert_dir_exists "$PROJECT_ROOT/configs" "Configs directory exists"
assert_dir_exists "$PROJECT_ROOT/scripts" "Scripts directory exists"

#------------------------------------------------------------------------------
# Test: Docker compose files exist
#------------------------------------------------------------------------------

assert_file_exists "$PROJECT_ROOT/docker/docker-compose.yml" "Main docker-compose exists"
assert_file_exists "$PROJECT_ROOT/docker/mainnet/docker-compose.yml" "Mainnet docker-compose exists"
assert_file_exists "$PROJECT_ROOT/docker/testnet/docker-compose.yml" "Testnet docker-compose exists"

#------------------------------------------------------------------------------
# Test: Docker is available
#------------------------------------------------------------------------------

if command -v docker >/dev/null 2>&1; then
    assert_cmd "docker info" "Docker daemon is running"
    assert_cmd "docker compose version || docker-compose version" "Docker Compose is available"
else
    skip "Docker daemon is running" "Docker not installed"
    skip "Docker Compose is available" "Docker not installed"
fi

#------------------------------------------------------------------------------
# Test: CLI version command works
#------------------------------------------------------------------------------

assert_cmd "$PROJECT_ROOT/cli/xdc version" "CLI version command works"
assert_cmd_output "$PROJECT_ROOT/cli/xdc version" "XDC" "Version output contains XDC"

#------------------------------------------------------------------------------
# Test: CLI help command works
#------------------------------------------------------------------------------

assert_cmd "$PROJECT_ROOT/cli/xdc help" "CLI help command works"
assert_cmd_output "$PROJECT_ROOT/cli/xdc help" "USAGE" "Help shows usage"
assert_cmd_output "$PROJECT_ROOT/cli/xdc help" "start" "Help shows start command"
assert_cmd_output "$PROJECT_ROOT/cli/xdc help" "stop" "Help shows stop command"
assert_cmd_output "$PROJECT_ROOT/cli/xdc help" "status" "Help shows status command"

#------------------------------------------------------------------------------
# Test: Required config files exist
#------------------------------------------------------------------------------

assert_file_exists "$PROJECT_ROOT/configs/versions.json" "versions.json exists"

#------------------------------------------------------------------------------
# Test: Platform-specific files
#------------------------------------------------------------------------------

OS="$(get_os)"
ARCH="$(get_arch)"

if [[ "$OS" == "macos" ]]; then
    # macOS-specific checks
    if [[ -f "$PROJECT_ROOT/scripts/macos-install.sh" ]]; then
        assert_file_executable "$PROJECT_ROOT/scripts/macos-install.sh" "macOS install script is executable"
    fi
    
    if [[ "$ARCH" == "arm64" ]]; then
        log "Running on macOS ARM64 (Apple Silicon)"
        
        # Check Docker Desktop supports ARM64
        if command -v docker >/dev/null 2>&1; then
            docker_arch=$(docker info --format '{{.Architecture}}' 2>/dev/null || echo "unknown")
            if [[ "$docker_arch" == "aarch64" ]] || [[ "$docker_arch" == "arm64" ]]; then
                pass "Docker supports ARM64 natively"
            else
                skip "Docker ARM64 check" "Docker arch: $docker_arch"
            fi
        fi
    fi
elif [[ "$OS" == "linux" ]]; then
    # Linux-specific checks
    if [[ -d "$PROJECT_ROOT/systemd" ]]; then
        assert_dir_exists "$PROJECT_ROOT/systemd" "Systemd directory exists"
    fi
fi

#------------------------------------------------------------------------------
# Test: Install script dry run (if supported)
#------------------------------------------------------------------------------

# We can't actually run install on a clean system in CI, but we can validate syntax
assert_cmd "bash -n $PROJECT_ROOT/install.sh" "Install script has valid bash syntax"
assert_cmd "bash -n $PROJECT_ROOT/setup.sh" "Setup script has valid bash syntax"
assert_cmd "bash -n $PROJECT_ROOT/cli/xdc" "CLI has valid bash syntax"

#------------------------------------------------------------------------------
# Test: Shell completions exist
#------------------------------------------------------------------------------

if [[ -d "$PROJECT_ROOT/completions" ]]; then
    assert_dir_exists "$PROJECT_ROOT/completions" "Completions directory exists"
    assert_file_exists "$PROJECT_ROOT/completions/xdc.bash" "Bash completions exist"
    assert_file_exists "$PROJECT_ROOT/completions/xdc.zsh" "Zsh completions exist"
fi

test_end
