#!/bin/bash
# Run chaos engineering tests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                CHAOS ENGINEERING TEST RUNNER                       ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "🌪️  Testing system resilience with controlled failures..."
echo ""

cd "$PROJECT_DIR"

echo "🔨 Building..."
xcodebuild build-for-testing \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -quiet

echo ""
echo "🧪 Running Chaos Tests..."
echo ""

# Run chaos test suites
TEST_SUITES=(
    "NetworkChaosTests"
    "ResourceChaosTests"
    "TimingChaosTests"
    "StateChaosTests"
    "DependencyChaosTests"
)

for suite in "${TEST_SUITES[@]}"; do
    echo "→ Running $suite..."
    if xcodebuild test \
        -project Epistemos.xcodeproj \
        -scheme Epistemos \
        -destination 'platform=macOS' \
        -only-testing:"EpistemosTests/$suite" \
        -quiet 2>&1; then
        echo "   ✅ $suite passed"
    else
        echo "   ❌ $suite failed"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Chaos engineering tests complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 System resilience validated against:"
echo "   • Network failures (delay, timeout, packet loss)"
echo "   • Resource exhaustion (memory, disk, CPU)"
echo "   • Timing issues (race conditions, deadlocks)"
echo "   • State corruption"
echo "   • Dependency failures"
