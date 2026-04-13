#!/bin/bash
# Run memory leak detection tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_DIR/test_results"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-$RESULTS_DIR/memory_tests_derived_data}"
XCODEBUILD_WRAPPER="$PROJECT_DIR/scripts/xcodebuild_epistemos.sh"

mkdir -p "$RESULTS_DIR"
rm -rf "$DERIVED_DATA_DIR"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                MEMORY LEAK TEST RUNNER                             ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

cd "$PROJECT_DIR"

echo "🔨 Building with memory diagnostics..."
"$XCODEBUILD_WRAPPER" build-for-testing \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet

echo ""
echo "🔍 Running Memory Leak Detection Tests..."
echo ""

# Run only memory-related test suites
TEST_SUITES=(
    "BasicMemoryLeakTests"
    "RetainCycleDetectionTests"
    "ClosureMemoryLeakTests"
    "AsyncMemoryLeakTests"
    "SingletonMemoryTests"
    "CircularReferenceTests"
    "DeallocationVerificationTests"
    "MemoryGraphValidationTests"
)

for suite in "${TEST_SUITES[@]}"; do
    echo "→ Running $suite..."
    if "$XCODEBUILD_WRAPPER" test-without-building \
        -project Epistemos.xcodeproj \
        -scheme Epistemos \
        -destination 'platform=macOS' \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        CODE_SIGNING_ALLOWED=NO \
        -only-testing:"EpistemosTests/$suite" \
        -quiet 2>&1; then
        echo "   ✅ $suite passed"
    else
        echo "   ❌ $suite failed"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Memory leak detection complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 Tip: For deeper analysis, use Xcode's Memory Graph Debugger:"
echo "   1. Run app in Xcode"
echo "   2. Click 'Debug Memory Graph' button"
echo "   3. Look for unexpected strong references"
