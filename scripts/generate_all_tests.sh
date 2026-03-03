#!/bin/bash
# Master script to generate 5,000+ tests for Epistemos

set -e

echo "═══════════════════════════════════════════════════════════════"
echo "  Epistenos Test Generator - 5,000+ Tests"
echo "═══════════════════════════════════════════════════════════════"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="/Users/jojo/Epistemos/EpistemosTests/Generated"

# Clean previous generated tests
echo "🧹 Cleaning previous generated tests..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Run main test generator
echo ""
echo "📦 Running main test generator..."
python3 "$SCRIPT_DIR/generate_tests.py"

# Run edge case generator
echo ""
echo "🔍 Running edge case generator..."
python3 "$SCRIPT_DIR/generate_edge_case_tests.py"

# Count generated tests
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Generation Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""

FILE_COUNT=$(find "$OUTPUT_DIR" -name "*.swift" | wc -l)
TEST_COUNT=$(grep -r "@Test" "$OUTPUT_DIR" --include="*.swift" | wc -l)

echo "📁 Files generated: $FILE_COUNT"
echo "🧪 Tests generated: $TEST_COUNT"
echo "📂 Location: $OUTPUT_DIR"
echo ""

# List all generated files
echo "Generated files:"
ls -la "$OUTPUT_DIR"/*.swift | awk '{printf "  %s (%s bytes)\n", $9, $5}'

# Summary by category
echo ""
echo "Tests by category:"
for category in notes chat library graph sync ui ffi pipeline models security performance; do
    count=$(grep -l "$category" "$OUTPUT_DIR"/*.swift 2>/dev/null | xargs grep "@Test" 2>/dev/null | wc -l)
    if [ "$count" -gt 0 ]; then
        printf "  %-12s: %4d tests\n" "$category" "$count"
    fi
done

# Edge case summary
echo ""
echo "Edge case tests:"
for file in BoundaryConditionTests UnicodeEdgeCaseTests FuzzTests StressTests ConcurrencyEdgeTests; do
    if [ -f "$OUTPUT_DIR/$file.swift" ]; then
        count=$(grep "@Test" "$OUTPUT_DIR/$file.swift" | wc -l)
        printf "  %-25s: %4d tests\n" "$file" "$count"
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Next steps:"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  1. Build tests: xcodebuild build-for-testing -project Epistemos.xcodeproj -scheme Epistemos"
echo "  2. Run tests:   xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS'"
echo ""
