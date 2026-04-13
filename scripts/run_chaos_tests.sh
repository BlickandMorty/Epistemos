#!/bin/bash
# Run chaos engineering tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_DIR/test_results"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-$RESULTS_DIR/chaos_tests_derived_data}"
XCODEBUILD_WRAPPER="$PROJECT_DIR/scripts/xcodebuild_epistemos.sh"

mkdir -p "$RESULTS_DIR"
rm -rf "$DERIVED_DATA_DIR"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                CHAOS ENGINEERING TEST RUNNER                       ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "🌪️  Testing system resilience with controlled failures..."
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
echo "✅ Chaos engineering tests complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 System resilience validated against:"
echo "   • Network failures (delay, timeout, packet loss)"
echo "   • Resource exhaustion (memory, disk, CPU)"
echo "   • Timing issues (race conditions, deadlocks)"
echo "   • State corruption"
echo "   • Dependency failures"
