#!/usr/bin/env bash
#==============================================================================
# E2E Test: macOS-Specific Tests
# Tests macOS-specific functionality including ARM64/Apple Silicon support
#==============================================================================

set -euo pipefail
source "$(dirname "$0")/lib/framework.sh"

test_start "macOS-Specific Tests"

PROJECT_ROOT="$(get_project_root)"
export PATH="$PROJECT_ROOT/cli:$PATH"

OS="$(get_os)"
ARCH="$(get_arch)"

#------------------------------------------------------------------------------
# Skip if not on macOS
#------------------------------------------------------------------------------

if [[ "$OS" != "macos" ]]; then
    log "Not running on macOS - skipping macOS-specific tests"
    skip "macOS platform check" "Running on $OS"
    test_end
    exit 0
fi

pass "Running on macOS"

#------------------------------------------------------------------------------
# Test: macOS version compatibility
#------------------------------------------------------------------------------

macos_version=$(sw_vers -productVersion 2>/dev/null) || macos_version="unknown"
macos_major=$(echo "$macos_version" | cut -d. -f1)

if [[ "$macos_major" -ge 12 ]]; then
    pass "macOS version is compatible ($macos_version)"
else
    fail "macOS version is compatible" "Version $macos_version may have issues"
fi

#------------------------------------------------------------------------------
# Test: Apple Silicon (ARM64) detection
#------------------------------------------------------------------------------

if [[ "$ARCH" == "arm64" ]]; then
    pass "Running on Apple Silicon (ARM64)"
    
    # Check Rosetta 2 installation
    if /usr/bin/pgrep -q oahd 2>/dev/null; then
        pass "Rosetta 2 is installed and running"
    else
        # Rosetta might be installed but not actively running
        if [[ -f "/Library/Apple/usr/share/rosetta/rosetta" ]]; then
            pass "Rosetta 2 is installed"
        else
            skip "Rosetta 2 is installed" "May be needed for x86_64 images"
        fi
    fi
else
    skip "Apple Silicon detection" "Running on Intel ($ARCH)"
fi

#------------------------------------------------------------------------------
# Test: Docker Desktop for Mac
#------------------------------------------------------------------------------

if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        pass "Docker is running"
        
        # Check Docker Desktop version
        docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null) || docker_version="unknown"
        
        if [[ "$docker_version" != "unknown" ]]; then
            pass "Docker version: $docker_version"
        fi
        
        # Check architecture support
        docker_arch=$(docker info --format '{{.Architecture}}' 2>/dev/null) || docker_arch="unknown"
        
        if [[ "$docker_arch" == "aarch64" ]] || [[ "$docker_arch" == "arm64" ]]; then
            pass "Docker runs natively on ARM64"
        elif [[ "$docker_arch" == "x86_64" ]]; then
            pass "Docker runs via Rosetta (x86_64)"
        else
            skip "Docker architecture check" "Architecture: $docker_arch"
        fi
        
        # Check platform emulation
        if docker run --rm --platform linux/arm64 alpine uname -m 2>/dev/null | grep -q "aarch64"; then
            pass "Docker supports linux/arm64 platform"
        else
            skip "Docker supports linux/arm64 platform" "Platform not available"
        fi
        
        if docker run --rm --platform linux/amd64 alpine uname -m 2>/dev/null | grep -q "x86_64"; then
            pass "Docker supports linux/amd64 platform (via Rosetta)"
        else
            skip "Docker supports linux/amd64 platform" "Platform not available"
        fi
    else
        fail "Docker is running" "Docker daemon not responding"
    fi
else
    skip "Docker installation" "Docker not installed"
fi

#------------------------------------------------------------------------------
# Test: XDC images work on ARM64
#------------------------------------------------------------------------------

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    log "Testing XDC Docker image compatibility..."
    
    # Try to pull and run a quick test
    xdc_image="xinfinorg/xdc:latest"
    
    # Just check if the image can be pulled (don't actually run node)
    if timeout 60 docker pull "$xdc_image" >/dev/null 2>&1; then
        pass "XDC image can be pulled"
        
        # Check image architecture
        image_arch=$(docker inspect "$xdc_image" --format '{{.Architecture}}' 2>/dev/null) || image_arch="unknown"
        
        if [[ "$image_arch" == "arm64" ]] || [[ "$image_arch" == "amd64" ]]; then
            pass "XDC image architecture: $image_arch"
        else
            skip "XDC image architecture check" "Unknown: $image_arch"
        fi
    else
        skip "XDC image pull test" "Timeout or network issue"
    fi
fi

#------------------------------------------------------------------------------
# Test: Homebrew availability (common on macOS)
#------------------------------------------------------------------------------

if command -v brew >/dev/null 2>&1; then
    pass "Homebrew is available"
    
    # Check for useful tools
    for tool in jq wget curl; do
        if command -v "$tool" >/dev/null 2>&1; then
            pass "Tool '$tool' is available"
        else
            skip "Tool '$tool' is available" "Not installed"
        fi
    done
else
    skip "Homebrew availability" "Not installed"
fi

#------------------------------------------------------------------------------
# Test: launchd integration (macOS service manager)
#------------------------------------------------------------------------------

if [[ -d "$PROJECT_ROOT/macos" ]] || [[ -f "$PROJECT_ROOT/scripts/launchd-install.sh" ]]; then
    pass "launchd integration files exist"
    
    # Check for plist template
    if find "$PROJECT_ROOT" -name "*.plist" -type f 2>/dev/null | grep -q plist; then
        pass "launchd plist template exists"
    else
        skip "launchd plist template exists" "Not found"
    fi
else
    skip "launchd integration files" "Not found (using Docker instead)"
fi

# Check launchctl availability
if command -v launchctl >/dev/null 2>&1; then
    pass "launchctl is available"
else
    fail "launchctl is available" "Should be available on macOS"
fi

#------------------------------------------------------------------------------
# Test: macOS security/permissions
#------------------------------------------------------------------------------

# Check if running with necessary permissions
if [[ -w "/usr/local" ]] || [[ -w "$HOME" ]]; then
    pass "Write permissions available"
else
    skip "Write permissions" "May need sudo for some operations"
fi

# Check Gatekeeper/codesign (for downloaded binaries)
if command -v codesign >/dev/null 2>&1; then
    pass "Code signing tools available"
fi

#------------------------------------------------------------------------------
# Test: File system case sensitivity
#------------------------------------------------------------------------------

# macOS is typically case-insensitive
test_file="$TEST_DIR/CaseSensitiveTest"
mkdir -p "$TEST_DIR"
touch "$test_file"

if [[ -f "${test_file,,}" ]] 2>/dev/null; then
    pass "File system is case-insensitive (typical macOS)"
else
    skip "File system case sensitivity" "Case-sensitive file system"
fi

rm -f "$test_file" 2>/dev/null || true

#------------------------------------------------------------------------------
# Test: Network configuration
#------------------------------------------------------------------------------

# Check if localhost resolves
if ping -c 1 localhost >/dev/null 2>&1; then
    pass "localhost resolves correctly"
else
    skip "localhost resolution" "May have network issues"
fi

# Check common ports are available
for port in 8545 8546 30303; do
    if ! lsof -i ":$port" >/dev/null 2>&1; then
        pass "Port $port is available"
    else
        skip "Port $port is available" "Port in use"
    fi
done

#------------------------------------------------------------------------------
# Test: macOS documentation exists
#------------------------------------------------------------------------------

if [[ -f "$PROJECT_ROOT/docs/MACOS-SETUP.md" ]]; then
    assert_file_exists "$PROJECT_ROOT/docs/MACOS-SETUP.md" "macOS setup documentation exists"
    assert_file_contains "$PROJECT_ROOT/docs/MACOS-SETUP.md" "macOS\|Mac\|ARM\|Apple" "Documentation mentions macOS"
else
    skip "macOS setup documentation" "File not found"
fi

#------------------------------------------------------------------------------
# Test: Memory and disk requirements
#------------------------------------------------------------------------------

# Check available memory (XDC node needs ~8GB minimum)
if command -v sysctl >/dev/null 2>&1; then
    total_mem_bytes=$(sysctl -n hw.memsize 2>/dev/null) || total_mem_bytes=0
    total_mem_gb=$((total_mem_bytes / 1024 / 1024 / 1024))
    
    if [[ $total_mem_gb -ge 8 ]]; then
        pass "Sufficient memory available (${total_mem_gb}GB)"
    else
        fail "Sufficient memory available" "Only ${total_mem_gb}GB (8GB recommended)"
    fi
fi

# Check available disk space
if command -v df >/dev/null 2>&1; then
    available_gb=$(df -g "$HOME" 2>/dev/null | awk 'NR==2 {print $4}') || available_gb=0
    
    if [[ $available_gb -ge 100 ]]; then
        pass "Sufficient disk space available (${available_gb}GB)"
    elif [[ $available_gb -ge 50 ]]; then
        pass "Minimum disk space available (${available_gb}GB - testnet OK)"
    else
        fail "Sufficient disk space" "Only ${available_gb}GB (100GB+ recommended)"
    fi
fi

#------------------------------------------------------------------------------
# Test: CLI works on macOS
#------------------------------------------------------------------------------

assert_cmd "xdc version" "XDC CLI works on macOS"
assert_cmd "xdc status" "XDC status works on macOS"

test_end
