#!/bin/bash
# Quick test - runs a subset of tests for rapid feedback
# Use this during development for fast validation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    QUICK TEST RUNNER                               ║"
echo "║          (Fast subset for development feedback)                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

cd "$PROJECT_DIR"

echo "🔨 Building..."
if ! xcodebuild build-for-testing \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -quiet 2>&1; then
    echo "❌ Build failed - fix before running tests"
    exit 1
fi

echo ""
echo "🧪 Running quick test subset..."
echo ""

# Run just a few key test files for quick feedback
QUICK_TESTS=(
    "GraphTypesTests"
    "GraphModelTests"
    "FilterEngineTests"
    "CollectionRegistryTests"
)

FAILED=0
for test in "${QUICK_TESTS[@]}"; do
    echo "→ Running $test..."
    if xcodebuild test \
        -project Epistemos.xcodeproj \
        -scheme Epistemos \
        -destination 'platform=macOS' \
        -only-testing:"EpistemosTests/$test" \
        -quiet 2>&1; then
        echo "   ✅ Passed"
    else
        echo "   ❌ Failed"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
if [ $FAILED -eq 0 ]; then
    echo "✅ Quick tests passed!"
    echo ""
    echo "💡 Run full suite with: ./scripts/run_all_tests.sh"
    exit 0
else
    echo "❌ $FAILED quick test(s) failed"
    exit 1
fi
