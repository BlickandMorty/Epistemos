#!/bin/bash
# Run crash recovery and stability tests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║              STABILITY & CRASH TEST RUNNER                         ║"
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
echo "🛡️  Running Crash Recovery & Stability Tests..."
echo ""

# Run stability test suites
TEST_SUITES=(
    "CrashDetectionTests"
    "WatchdogTerminationTests"
    "AppHangDetectionTests"
    "GracefulDegradationTests"
    "SoftFailureHandlingTests"
    "RecoveryMechanismTests"
    "StateRestorationTests"
    "SignalHandlingTests"
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
echo "✅ Stability tests complete"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
