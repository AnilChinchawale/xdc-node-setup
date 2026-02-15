#!/usr/bin/env bash
#==============================================================================
# E2E Test Runner
# Runs all E2E tests with TAP output support
#==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
TAP_MODE="${TAP_MODE:-false}"
VERBOSE="${TEST_VERBOSE:-false}"
FAIL_FAST="${FAIL_FAST:-false}"
FILTER="${1:-}"

# Colors
if [[ -t 1 ]] && [[ "${NO_COLOR:-}" != "true" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
fi

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --tap)      TAP_MODE=true ;;
        --verbose)  VERBOSE=true ;;
        --fail-fast) FAIL_FAST=true ;;
        --no-color) NO_COLOR=true ;;
        --help|-h)
            cat << EOF
Usage: $(basename "$0") [OPTIONS] [FILTER]

Run E2E tests for XDC Node Setup.

OPTIONS:
    --tap         Output in TAP format (for CI)
    --verbose     Show detailed output
    --fail-fast   Stop on first failure
    --no-color    Disable colored output
    -h, --help    Show this help

FILTER:
    Optional test name filter (e.g., "install" to run only test-install.sh)

EXAMPLES:
    ./run-all.sh                    # Run all tests
    ./run-all.sh --tap              # Run with TAP output
    ./run-all.sh install            # Run only install tests
    ./run-all.sh --verbose status   # Run status tests with verbose output

ENVIRONMENT VARIABLES:
    TEST_NETWORK      Network to test (default: testnet)
    TEST_TIMEOUT      Timeout in seconds (default: 300)
    TEST_SKIP_CLEANUP Don't clean up after tests (default: false)
    TEST_VERBOSE      Verbose output (default: false)
    TAP_MODE          TAP output format (default: false)
EOF
            exit 0
            ;;
        --*)
            echo "Unknown option: $arg" >&2
            exit 1
            ;;
        *)
            FILTER="$arg"
            ;;
    esac
done

# Export for child scripts
export TAP_MODE VERBOSE NO_COLOR
export TEST_VERBOSE="$VERBOSE"

# Test files to run (in order)
TEST_FILES=(
    "test-install.sh"
    "test-setup.sh"
    "test-cli-commands.sh"
    "test-status.sh"
    "test-start-stop.sh"
    "test-multi-client.sh"
    "test-macos-specific.sh"
)

# Filter tests if specified
if [[ -n "$FILTER" ]]; then
    FILTERED=()
    for test in "${TEST_FILES[@]}"; do
        if [[ "$test" == *"$FILTER"* ]]; then
            FILTERED+=("$test")
        fi
    done
    TEST_FILES=("${FILTERED[@]}")
fi

# Counters
total_tests=0
passed_tests=0
failed_tests=0
skipped_tests=0

# Results storage
declare -A test_results

#------------------------------------------------------------------------------
# Output Functions
#------------------------------------------------------------------------------

print_header() {
    if [[ "$TAP_MODE" != "true" ]]; then
        echo ""
        echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${CYAN}║        XDC Node Setup - E2E Test Suite                       ║${NC}"
        echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${DIM}Project: $PROJECT_ROOT${NC}"
        echo -e "${DIM}Tests:   ${#TEST_FILES[@]} test files${NC}"
        echo ""
    else
        echo "TAP version 14"
        echo "# XDC Node Setup - E2E Test Suite"
    fi
}

print_test_start() {
    local test_name="$1"
    if [[ "$TAP_MODE" != "true" ]]; then
        echo -e "${BLUE}▶${NC} Running: ${BOLD}$test_name${NC}"
    else
        echo "# Running: $test_name"
    fi
}

print_test_result() {
    local test_name="$1"
    local result="$2"
    local duration="$3"
    
    if [[ "$TAP_MODE" != "true" ]]; then
        case "$result" in
            pass)
                echo -e "  ${GREEN}✓${NC} ${test_name} ${DIM}(${duration}s)${NC}"
                ;;
            fail)
                echo -e "  ${RED}✗${NC} ${test_name} ${DIM}(${duration}s)${NC}"
                ;;
            skip)
                echo -e "  ${YELLOW}○${NC} ${test_name} ${DIM}(skipped)${NC}"
                ;;
        esac
    fi
}

print_summary() {
    if [[ "$TAP_MODE" != "true" ]]; then
        echo ""
        echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}Summary${NC}"
        echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "  Test Files:  ${#TEST_FILES[@]}"
        echo -e "  ${GREEN}Passed:${NC}      $passed_tests"
        if [[ $failed_tests -gt 0 ]]; then
            echo -e "  ${RED}Failed:${NC}      $failed_tests"
        fi
        if [[ $skipped_tests -gt 0 ]]; then
            echo -e "  ${YELLOW}Skipped:${NC}     $skipped_tests"
        fi
        echo ""
        
        # Show failed tests
        if [[ $failed_tests -gt 0 ]]; then
            echo -e "${RED}Failed Tests:${NC}"
            for test in "${!test_results[@]}"; do
                if [[ "${test_results[$test]}" == "fail" ]]; then
                    echo -e "  ${RED}✗${NC} $test"
                fi
            done
            echo ""
        fi
        
        # Final status
        if [[ $failed_tests -eq 0 ]]; then
            echo -e "${GREEN}${BOLD}All tests passed!${NC} 🎉"
        else
            echo -e "${RED}${BOLD}Some tests failed.${NC}"
        fi
        echo ""
    else
        echo "1..$total_tests"
        echo "# Passed: $passed_tests"
        echo "# Failed: $failed_tests"
        echo "# Skipped: $skipped_tests"
    fi
}

#------------------------------------------------------------------------------
# Test Execution
#------------------------------------------------------------------------------

run_test() {
    local test_file="$1"
    local test_path="$SCRIPT_DIR/$test_file"
    
    if [[ ! -f "$test_path" ]]; then
        if [[ "$TAP_MODE" == "true" ]]; then
            echo "not ok - $test_file # SKIP file not found"
        else
            echo -e "  ${YELLOW}○${NC} $test_file ${DIM}(file not found)${NC}"
        fi
        ((skipped_tests++))
        test_results["$test_file"]="skip"
        return 0
    fi
    
    if [[ ! -x "$test_path" ]]; then
        chmod +x "$test_path"
    fi
    
    print_test_start "$test_file"
    
    local start_time=$(date +%s)
    local output
    local exit_code=0
    
    # Run the test
    if [[ "$TAP_MODE" == "true" ]]; then
        output=$("$test_path" --tap 2>&1) || exit_code=$?
    else
        output=$("$test_path" 2>&1) || exit_code=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Parse results from output
    local test_passed=$(echo "$output" | grep -c "^ok " || echo "0")
    local test_failed=$(echo "$output" | grep -c "^not ok " || echo "0")
    
    # Update counters
    passed_tests=$((passed_tests + test_passed))
    failed_tests=$((failed_tests + test_failed))
    total_tests=$((total_tests + test_passed + test_failed))
    
    # Determine overall result
    if [[ $exit_code -eq 0 ]] && [[ $test_failed -eq 0 ]]; then
        test_results["$test_file"]="pass"
        print_test_result "$test_file" "pass" "$duration"
    else
        test_results["$test_file"]="fail"
        print_test_result "$test_file" "fail" "$duration"
        
        # Show output on failure
        if [[ "$VERBOSE" == "true" ]] || [[ "$TAP_MODE" == "true" ]]; then
            echo "$output"
        fi
        
        if [[ "$FAIL_FAST" == "true" ]]; then
            echo -e "${RED}Stopping on first failure (--fail-fast)${NC}"
            return 1
        fi
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    print_header
    
    # Check test directory
    if [[ ! -d "$SCRIPT_DIR" ]]; then
        echo "Error: Test directory not found: $SCRIPT_DIR" >&2
        exit 1
    fi
    
    # Create lib directory if needed
    mkdir -p "$SCRIPT_DIR/lib"
    
    # Ensure framework exists
    if [[ ! -f "$SCRIPT_DIR/lib/framework.sh" ]]; then
        echo "Error: Test framework not found. Run setup first." >&2
        exit 1
    fi
    
    # Run tests
    for test_file in "${TEST_FILES[@]}"; do
        run_test "$test_file" || true
    done
    
    print_summary
    
    # Exit with failure if any tests failed
    [[ $failed_tests -eq 0 ]]
}

main "$@"
