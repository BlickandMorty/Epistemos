#!/bin/bash
# Run performance benchmark tests only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_DIR/test_results"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-$RESULTS_DIR/performance_tests_derived_data}"
XCODEBUILD_WRAPPER="$PROJECT_DIR/scripts/xcodebuild_epistemos.sh"

mkdir -p "$RESULTS_DIR"
rm -rf "$DERIVED_DATA_DIR"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                PERFORMANCE TEST RUNNER                             ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

cd "$PROJECT_DIR"

echo "🔨 Building..."
"$XCODEBUILD_WRAPPER" build-for-testing \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet

echo ""
echo "🧪 Running Performance Benchmarks..."
echo ""

# Run only performance benchmark tests
TEST_SUITES=(
    "NotePerformanceBenchmarkTests"
    "GraphPerformanceBenchmarkTests"
    "ChatPerformanceBenchmarkTests"
    "StartupPerformanceBenchmarkTests"
    "SyncPerformanceBenchmarkTests"
    "MemoryPressureBenchmarkTests"
    "CPUIntensiveBenchmarkTests"
    "IOPerformanceBenchmarkTests"
)

for suite in "${TEST_SUITES[@]}"; do
    echo "→ Running $suite..."
    "$XCODEBUILD_WRAPPER" test-without-building \
        -project Epistemos.xcodeproj \
        -scheme Epistemos \
        -destination 'platform=macOS' \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        CODE_SIGNING_ALLOWED=NO \
        -only-testing:"EpistemosTests/$suite" \
        -quiet 2>&1 | grep -E "(Test Case|measured|Performance)" || true
    echo ""
done

echo "✅ Performance benchmarks complete"
echo ""
echo "📊 View detailed results in Xcode:"
echo "   Open Report navigator (⌘9) to see performance metrics"
