# E2E Test Suite for XDC Node Setup

End-to-end tests for XDC Node Setup, with special focus on macOS ARM64 (Apple Silicon).

## Quick Start

```bash
# Run all tests
./tests/e2e/run-all.sh

# Run specific test
./tests/e2e/test-install.sh

# Run with verbose output
./tests/e2e/run-all.sh --verbose

# Run on CI
./tests/e2e/run-all.sh --tap
```

## Test Files

| Test | Description |
|------|-------------|
| `test-install.sh` | Fresh install on clean system |
| `test-setup.sh` | `xdc setup` wizard functionality |
| `test-start-stop.sh` | `xdc start`, `xdc stop`, `xdc restart` |
| `test-status.sh` | `xdc status` output validation |
| `test-multi-client.sh` | Running geth + erigon simultaneously |
| `test-cli-commands.sh` | All CLI command validation |
| `test-macos-specific.sh` | macOS-specific tests (launchd, Rosetta) |

## Test Framework

Tests use a simple bash framework with TAP output support.

### Assert Functions

```bash
# Basic assertions
assert_eq "expected" "$actual" "Description"
assert_ne "not_expected" "$actual" "Description"
assert_contains "$haystack" "needle" "Description"
assert_not_contains "$haystack" "needle" "Description"

# Command assertions
assert_cmd "command" "Description"           # Command exits 0
assert_cmd_fails "command" "Description"     # Command exits non-0
assert_cmd_output "command" "expected" "Description"

# File assertions
assert_file_exists "/path/to/file" "Description"
assert_dir_exists "/path/to/dir" "Description"
assert_file_contains "/path" "content" "Description"

# Process assertions
assert_process_running "process_name" "Description"
assert_port_open 8545 "Description"
```

### TAP Output

Tests produce [TAP (Test Anything Protocol)](https://testanything.org/) output:

```
TAP version 14
1..7
ok 1 - Install script exists
ok 2 - CLI is executable
ok 3 - Docker is available
not ok 4 - RPC responds within timeout
ok 5 - Status shows sync progress
ok 6 - Stop command succeeds
ok 7 - Containers are stopped
```

## Requirements

### All Platforms
- Bash 4.0+
- Docker 20.10+
- curl
- jq (optional, for JSON validation)

### macOS ARM64 Specific
- macOS 12.0+ (Monterey or later)
- Docker Desktop 4.25+ with Apple Silicon support
- Rosetta 2 (for x86_64 images): `softwareupdate --install-rosetta`

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TEST_NETWORK` | `testnet` | Network to test (mainnet/testnet/devnet) |
| `TEST_TIMEOUT` | `300` | Timeout in seconds for long operations |
| `TEST_SKIP_CLEANUP` | `false` | Keep containers after tests |
| `TEST_VERBOSE` | `false` | Show detailed output |
| `TEST_DIR` | `/tmp/xdc-e2e-test` | Temporary test directory |

## CI Integration

### GitHub Actions

Tests run automatically on:
- Push to `main`
- Pull requests
- Manual dispatch

See `.github/workflows/e2e-macos.yml` for the workflow configuration.

### Running Locally on macOS ARM64

```bash
# Ensure Docker Desktop is running
docker info

# Check for Rosetta 2 (needed for some images)
/usr/bin/pgrep -q oahd && echo "Rosetta is installed"

# Run tests
./tests/e2e/run-all.sh
```

## Writing New Tests

1. Create a new file: `tests/e2e/test-your-feature.sh`
2. Source the test framework:
   ```bash
   #!/usr/bin/env bash
   source "$(dirname "$0")/lib/framework.sh"
   
   test_start "Your Feature Tests"
   
   # Your tests here
   assert_eq "expected" "$actual" "Test description"
   
   test_end
   ```
3. Make it executable: `chmod +x tests/e2e/test-your-feature.sh`
4. Add to `run-all.sh` if needed

## Troubleshooting

### Docker Issues on macOS ARM64

```bash
# Check Docker is running
docker info

# Check platform support
docker run --rm --platform linux/arm64 alpine uname -m  # Should show aarch64
docker run --rm --platform linux/amd64 alpine uname -m  # Should show x86_64 (via Rosetta)

# Reset Docker Desktop if issues persist
killall Docker && open -a Docker
```

### Test Failures

```bash
# Run with verbose output
TEST_VERBOSE=true ./tests/e2e/test-install.sh

# Skip cleanup to inspect state
TEST_SKIP_CLEANUP=true ./tests/e2e/test-start-stop.sh

# Check logs
docker logs xdc-testnet 2>&1 | tail -100
```
