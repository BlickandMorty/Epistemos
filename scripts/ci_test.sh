#!/bin/bash
# CI/CD test runner - optimized for continuous integration
# Produces JUnit-compatible output and handles exit codes properly

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_DIR/test_results"

mkdir -p "$RESULTS_DIR"

echo "════════════════════════════════════════════════════════════════════"
echo "                    CI TEST RUNNER"
echo "════════════════════════════════════════════════════════════════════"
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
    RUST_PASSED=$(grep "^test result" "$RESULTS_DIR/rust_tests.log" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || echo 0)
    RUST_FAILED=$(grep "^test result" "$RESULTS_DIR/rust_tests.log" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' || echo 0)
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
    -quiet 2>&1 | tee "$RESULTS_DIR/swift_build.log"; then
    
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

if xcodebuild test \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -resultBundlePath "$RESULTS_DIR/TestResults.xcresult" \
    2>&1 | tee "$RESULTS_DIR/swift_tests.log"; then
    
    echo "✅ Swift tests completed"
else
    echo "⚠️  Swift tests completed with failures"
    EXIT_CODE=1
fi

# Parse Swift results
SWIFT_PASSED=$(grep -c "Test Case.*passed" "$RESULTS_DIR/swift_tests.log" 2>/dev/null || echo 0)
SWIFT_FAILED=$(grep -c "Test Case.*failed" "$RESULTS_DIR/swift_tests.log" 2>/dev/null || echo 0)

echo ""
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
