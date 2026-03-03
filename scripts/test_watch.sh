#!/bin/bash
# Watch mode - continuously run tests on file changes
# Requires fswatch: brew install fswatch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    TEST WATCH MODE                                 ║"
echo "║         (Auto-runs tests on file changes)                          ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Check for fswatch
if ! command -v fswatch &> /dev/null; then
    echo "❌ fswatch not found. Install with:"
    echo "   brew install fswatch"
    exit 1
fi

echo "👀 Watching for changes in:"
echo "   - Epistemos/*.swift"
echo "   - graph-engine/src/*.rs"
echo ""
echo "🧪 Will run quick tests on change..."
echo "   (Press Ctrl+C to stop)"
echo ""

# Function to run tests
run_tests() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔄 Change detected at $(date)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    cd "$PROJECT_DIR"
    
    # Build Rust first
    echo "→ Building Rust..."
    if ! cargo build --quiet 2>&1; then
        echo "❌ Rust build failed"
        return
    fi
    
    # Run quick Swift tests
    echo "→ Running quick Swift tests..."
    if ./scripts/run_quick_test.sh 2>&1; then
        echo ""
        echo "✅ All tests passed at $(date)"
    else
        echo ""
        echo "❌ Tests failed at $(date)"
    fi
    
    echo ""
    echo "👀 Watching for next change..."
}

# Run once immediately
run_tests

# Watch for changes
fswatch -o \
    "$PROJECT_DIR/Epistemos" \
    "$PROJECT_DIR/graph-engine/src" \
    "$PROJECT_DIR/EpistemosTests" \
    | while read f; do
        run_tests
    done
