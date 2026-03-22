#!/bin/bash
# Run only Swift tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_DIR/test_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$RESULTS_DIR"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                   SWIFT TEST RUNNER                                ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

cd "$PROJECT_DIR"

echo "🔨 Building Swift test target..."
xcodebuild build-for-testing \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -quiet

echo ""
echo "🧪 Running Swift tests..."
echo "   (This may take several minutes for 10,000+ tests)"
echo ""

# Run tests
if xcodebuild test \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
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
PASSED=$(grep -c "Test Case.*passed" "$RESULTS_DIR/swift_tests_$TIMESTAMP.log" 2>/dev/null || echo 0)
FAILED=$(grep -c "Test Case.*failed" "$RESULTS_DIR/swift_tests_$TIMESTAMP.log" 2>/dev/null || echo 0)

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
