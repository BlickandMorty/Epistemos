#!/bin/bash
# Run only Swift tests

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
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-$RESULTS_DIR/swift_derived_data}"
SOURCE_PACKAGES_DIR="${SOURCE_PACKAGES_DIR:-}"
PACKAGE_ARGS=()

mkdir -p "$RESULTS_DIR"
rm -rf "$DERIVED_DATA_DIR"

if [ -n "$SOURCE_PACKAGES_DIR" ]; then
    mkdir -p "$SOURCE_PACKAGES_DIR"
    PACKAGE_ARGS=(-clonedSourcePackagesDirPath "$SOURCE_PACKAGES_DIR")
fi

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                   SWIFT TEST RUNNER                                ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "DerivedData: $DERIVED_DATA_DIR"
echo "SourcePackages: ${SOURCE_PACKAGES_DIR:-<xcode-managed default>}"
echo "xcodebuild wrapper: $PROJECT_DIR/scripts/xcodebuild_epistemos.sh"
echo ""

cd "$PROJECT_DIR"

echo "🔨 Building Swift test target..."
"$PROJECT_DIR/scripts/xcodebuild_epistemos.sh" build-for-testing \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    "${PACKAGE_ARGS[@]}" \
    2>&1 | tee "$RESULTS_DIR/swift_build_$TIMESTAMP.log"

echo ""
echo "🧪 Running Swift tests..."
echo "   (This may take several minutes for 10,000+ tests)"
echo ""

# Run tests
if "$PROJECT_DIR/scripts/xcodebuild_epistemos.sh" test-without-building \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    "${PACKAGE_ARGS[@]}" \
    -resultBundlePath "$RESULTS_DIR/swift_tests_$TIMESTAMP.xcresult" \
    2>&1 | tee "$RESULTS_DIR/swift_tests_$TIMESTAMP.log"; then
    
    echo ""
    echo "✅ Swift tests completed"
else
    echo ""
    echo "⚠️  Swift tests completed with failures"
fi

# Parse results
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 TEST SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Count passed/failed
SUMMARY_LINE="$(grep -E 'Test run with [0-9]+ tests in [0-9]+ suites (passed|failed) after' "$RESULTS_DIR/swift_tests_$TIMESTAMP.log" | tail -1 || true)"
EXEC_SUCCEEDED="$(grep -c '\*\* TEST EXECUTE SUCCEEDED \*\*' "$RESULTS_DIR/swift_tests_$TIMESTAMP.log" || true)"
PASSED_XCTEST="$(grep -c 'Test Case.*passed' "$RESULTS_DIR/swift_tests_$TIMESTAMP.log" || true)"
FAILED_XCTEST="$(grep -c 'Test Case.*failed' "$RESULTS_DIR/swift_tests_$TIMESTAMP.log" || true)"
FAILED_SWIFTTESTING="$(grep -c '^✘ Test ' "$RESULTS_DIR/swift_tests_$TIMESTAMP.log" || true)"

if [ -n "$SUMMARY_LINE" ]; then
    TOTAL="$(extract_first_number "$SUMMARY_LINE")"
    if [ "$(extract_first_number "$EXEC_SUCCEEDED")" -gt 0 ]; then
        PASSED="$TOTAL"
        FAILED=0
    else
        FAILED="$(extract_first_number "$FAILED_SWIFTTESTING")"
        PASSED=$((TOTAL - FAILED))
        if [ "$PASSED" -lt 0 ]; then
            PASSED=0
        fi
    fi
else
    PASSED="$(extract_first_number "$PASSED_XCTEST")"
    FAILED="$(extract_first_number "$FAILED_XCTEST")"
fi

echo "Test Cases:"
echo "  ✅ Passed: $PASSED"
echo "  ❌ Failed: $FAILED"
echo ""
echo "📁 Full results: $RESULTS_DIR/swift_tests_$TIMESTAMP.xcresult"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo "🎉 All Swift tests passed!"
    exit 0
else
    echo "❌ Some Swift tests failed"
    echo ""
    echo "🔍 To view detailed results:"
    echo "   open $RESULTS_DIR/swift_tests_$TIMESTAMP.xcresult"
    exit 1
fi
