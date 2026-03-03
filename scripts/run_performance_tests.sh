#!/bin/bash
# Run performance benchmark tests only

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                PERFORMANCE TEST RUNNER                             ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

cd "$PROJECT_DIR"

echo "🔨 Building..."
xcodebuild build-for-testing \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
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
    xcodebuild test \
        -project Epistemos.xcodeproj \
        -scheme Epistemos \
        -destination 'platform=macOS' \
        -only-testing:"EpistemosTests/$suite" \
        -quiet 2>&1 | grep -E "(Test Case|measured|Performance)" || true
    echo ""
done

echo "✅ Performance benchmarks complete"
echo ""
echo "📊 View detailed results in Xcode:"
echo "   Open Report navigator (⌘9) to see performance metrics"
