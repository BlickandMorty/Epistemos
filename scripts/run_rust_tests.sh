#!/bin/bash
# Run only Rust/graph-engine tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    RUST TEST RUNNER                                ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

cd "$PROJECT_DIR/graph-engine"

echo "🔧 Building Rust engine..."
cargo build --quiet

echo ""
echo "🧪 Running Rust tests..."
echo ""

# Run tests with output
cargo test -- --nocapture 2>&1 | tee /tmp/rust_test_output.log

# Extract and display summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 TEST SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

grep "^test result" /tmp/rust_test_output.log || echo "Test results not found"

# Count tests
PASSED=$(grep "^test result" /tmp/rust_test_output.log | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || echo 0)
FAILED=$(grep "^test result" /tmp/rust_test_output.log | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' || echo 0)

echo ""
echo "Total: $PASSED passed, $FAILED failed"

if [ "$FAILED" -eq 0 ]; then
    echo ""
    echo "✅ All Rust tests passed!"
    exit 0
else
    echo ""
    echo "❌ Some Rust tests failed"
    exit 1
fi
