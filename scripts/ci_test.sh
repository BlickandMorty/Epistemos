#!/bin/bash
# CI/CD test runner - optimized for continuous integration
# Produces JUnit-compatible output and handles exit codes properly

set -euo pipefail

extract_first_number() {
    local value="${1:-}"
    value="$(printf '%s' "$value" | grep -oE '[0-9]+' | head -1 || true)"
    if [ -z "$value" ]; then
        value=0
    fi
    printf '%s' "$value"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_DIR/test_results"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-$RESULTS_DIR/ci_derived_data}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-$RESULTS_DIR/ci_source_packages}"

mkdir -p "$RESULTS_DIR"
mkdir -p "$SOURCE_PACKAGES_DIR"
rm -rf "$DERIVED_DATA_DIR"

echo "════════════════════════════════════════════════════════════════════"
echo "                    CI TEST RUNNER"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "DerivedData: $DERIVED_DATA_DIR"
echo "SourcePackages: $SOURCE_PACKAGES_DIR"
echo ""

EXIT_CODE=0

#######################################
# RUST TESTS
#######################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 RUST TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROJECT_DIR/graph-engine"

echo "→ Building Rust..."
if cargo build --quiet; then
    echo "✅ Rust build successful"
else
    echo "❌ Rust build failed"
    exit 1
fi

echo ""
echo "→ Running Rust tests..."
if cargo test 2>&1 | tee "$RESULTS_DIR/rust_tests.log"; then
    RUST_SUMMARY_LINE="$(grep '^test result' "$RESULTS_DIR/rust_tests.log" | tail -1 || true)"
    RUST_PASSED="$(extract_first_number "$(printf '%s' "$RUST_SUMMARY_LINE" | grep -oE '[0-9]+ passed' || true)")"
    RUST_FAILED="$(extract_first_number "$(printf '%s' "$RUST_SUMMARY_LINE" | grep -oE '[0-9]+ failed' || true)")"
    echo ""
    echo "✅ Rust tests: $RUST_PASSED passed, $RUST_FAILED failed"
    
    if [ "$RUST_FAILED" -gt 0 ]; then
        EXIT_CODE=1
    fi
else
    echo "❌ Rust tests failed"
    EXIT_CODE=1
fi

#######################################
# SWIFT BUILD
#######################################
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔨 SWIFT BUILD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROJECT_DIR"

if xcodebuild build-for-testing \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
    2>&1 | tee "$RESULTS_DIR/swift_build.log"; then
    
    echo "✅ Swift build successful"
else
    echo "❌ Swift build failed"
    cat "$RESULTS_DIR/swift_build.log"
    exit 1
fi

#######################################
# SWIFT TESTS
#######################################
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 SWIFT TESTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

rm -rf "$RESULTS_DIR/TestResults.xcresult"

if xcodebuild test-without-building \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR" \
    -resultBundlePath "$RESULTS_DIR/TestResults.xcresult" \
    2>&1 | tee "$RESULTS_DIR/swift_tests.log"; then
    
    echo "✅ Swift tests completed"
else
    echo "⚠️  Swift tests completed with failures"
    EXIT_CODE=1
fi

# Parse Swift results
echo ""
SWIFT_SUMMARY_LINE="$(grep -E 'Test run with [0-9]+ tests in [0-9]+ suites (passed|failed) after' "$RESULTS_DIR/swift_tests.log" | tail -1 || true)"
SWIFT_EXEC_SUCCEEDED="$(grep -c '\*\* TEST EXECUTE SUCCEEDED \*\*' "$RESULTS_DIR/swift_tests.log" || true)"
SWIFT_PASSED_XCTEST="$(grep -c 'Test Case.*passed' "$RESULTS_DIR/swift_tests.log" || true)"
SWIFT_FAILED_XCTEST="$(grep -c 'Test Case.*failed' "$RESULTS_DIR/swift_tests.log" || true)"
SWIFT_FAILED_SWIFTTESTING="$(grep -c '^✘ Test ' "$RESULTS_DIR/swift_tests.log" || true)"

if [ -n "$SWIFT_SUMMARY_LINE" ]; then
    SWIFT_TOTAL="$(extract_first_number "$SWIFT_SUMMARY_LINE")"
    if [ "$(extract_first_number "$SWIFT_EXEC_SUCCEEDED")" -gt 0 ]; then
        SWIFT_PASSED="$SWIFT_TOTAL"
        SWIFT_FAILED=0
    else
        SWIFT_FAILED="$(extract_first_number "$SWIFT_FAILED_SWIFTTESTING")"
        SWIFT_PASSED=$((SWIFT_TOTAL - SWIFT_FAILED))
        if [ "$SWIFT_PASSED" -lt 0 ]; then
            SWIFT_PASSED=0
        fi
    fi
else
    SWIFT_PASSED="$(extract_first_number "$SWIFT_PASSED_XCTEST")"
    SWIFT_FAILED="$(extract_first_number "$SWIFT_FAILED_XCTEST")"
fi

echo "Swift tests: $SWIFT_PASSED passed, $SWIFT_FAILED failed"

if [ "$SWIFT_FAILED" -gt 0 ]; then
    EXIT_CODE=1
fi

#######################################
# SUMMARY
#######################################
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "                         TEST SUMMARY"
echo "════════════════════════════════════════════════════════════════════"
echo ""

TOTAL_PASSED=$((RUST_PASSED + SWIFT_PASSED))
TOTAL_FAILED=$((RUST_FAILED + SWIFT_FAILED))

echo "Total Tests:"
echo "  Passed: $TOTAL_PASSED"
echo "  Failed: $TOTAL_FAILED"
echo ""

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ ALL TESTS PASSED"
else
    echo "❌ SOME TESTS FAILED"
fi

echo ""
echo "Results saved to: $RESULTS_DIR"

exit $EXIT_CODE
