#!/bin/bash
# Comprehensive Test Generator for Epistemos
# Runs ALL test generators: basic, advanced, chaos, and property-based

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                                                                    ║"
echo "║         EPISTEMOS COMPREHENSIVE TEST GENERATOR                     ║"
echo "║                                                                    ║"
echo "║    Unit Tests • Performance • Memory • Chaos • Properties          ║"
echo "║                                                                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="/Users/jojo/Epistemos/EpistemosTests/Generated"

# Clean and prepare
echo "🧹 Cleaning previous generated tests..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PHASE 1: Basic Category Tests (Notes, Chat, Graph, etc.)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
python3 "$SCRIPT_DIR/generate_tests.py"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PHASE 2: Edge Case Tests (Boundary, Unicode, Fuzz, Stress)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
python3 "$SCRIPT_DIR/generate_edge_case_tests.py"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PHASE 3: Performance Benchmark Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
python3 "$SCRIPT_DIR/generate_performance_benchmark_tests.py"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PHASE 4: Memory Leak Detection Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
python3 "$SCRIPT_DIR/generate_memory_leak_tests.py"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PHASE 5: Crash Recovery & Stability Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
python3 "$SCRIPT_DIR/generate_crash_recovery_tests.py"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PHASE 6: Chaos Engineering Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
python3 "$SCRIPT_DIR/generate_chaos_tests.py"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PHASE 7: Property-Based Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
python3 "$SCRIPT_DIR/generate_property_based_tests.py"

# Final Summary
echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                       GENERATION COMPLETE                          ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

FILE_COUNT=$(find "$OUTPUT_DIR" -name "*.swift" | wc -l)
TEST_COUNT=$(grep -r "@Test" "$OUTPUT_DIR" --include="*.swift" 2>/dev/null | wc -l)

echo "📊 SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📁 Total files generated: $FILE_COUNT"
echo "  🧪 Total tests generated: $TEST_COUNT"
echo ""

# Category breakdown
echo "📋 BREAKDOWN BY CATEGORY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "Basic Category Tests:"
grep -l "Notes\|Chat\|Graph\|Library\|Sync\|UI\|FFI\|Pipeline\|Models\|Security\|Performance" "$OUTPUT_DIR"/*.swift 2>/dev/null | while read file; do
    count=$(grep -c "@Test" "$file" 2>/dev/null || echo 0)
    name=$(basename "$file" .swift | sed 's/GeneratedTests[0-9]*//')
    if [ "$count" -gt 0 ]; then
        printf "  %-25s: %4d tests\n" "$name" "$count"
    fi
done | sort -u

echo ""
echo "Edge Case Tests:"
for file in "$OUTPUT_DIR"/BoundaryConditionTests.swift "$OUTPUT_DIR"/UnicodeEdgeCaseTests.swift "$OUTPUT_DIR"/FuzzTests.swift "$OUTPUT_DIR"/StressTests.swift "$OUTPUT_DIR"/ConcurrencyEdgeTests.swift; do
    if [ -f "$file" ]; then
        count=$(grep -c "@Test" "$file" 2>/dev/null || echo 0)
        name=$(basename "$file" .swift)
        printf "  %-25s: %4d tests\n" "$name" "$count"
    fi
done

echo ""
echo "Performance & Benchmarks:"
for file in "$OUTPUT_DIR"/*BenchmarkTests.swift; do
    if [ -f "$file" ]; then
        count=$(grep -c "@Test" "$file" 2>/dev/null || echo 0)
        name=$(basename "$file" .swift)
        printf "  %-25s: %4d tests\n" "$name" "$count"
    fi
done

echo ""
echo "Memory & Stability:"
for file in "$OUTPUT_DIR"/*Memory*.swift "$OUTPUT_DIR"/*Leak*.swift "$OUTPUT_DIR"/CircularReferenceTests.swift "$OUTPUT_DIR"/DeallocationVerificationTests.swift; do
    if [ -f "$file" ]; then
        count=$(grep -c "@Test" "$file" 2>/dev/null || echo 0)
        name=$(basename "$file" .swift)
        printf "  %-25s: %4d tests\n" "$name" "$count"
    fi
done | sort -u

echo ""
echo "Crash Recovery:"
for file in "$OUTPUT_DIR"/Crash*.swift "$OUTPUT_DIR"/Watchdog*.swift "$OUTPUT_DIR"/*Hang*.swift "$OUTPUT_DIR"/Graceful*.swift "$OUTPUT_DIR"/Soft*.swift "$OUTPUT_DIR"/Recovery*.swift "$OUTPUT_DIR"/State*.swift "$OUTPUT_DIR"/Signal*.swift; do
    if [ -f "$file" ]; then
        count=$(grep -c "@Test" "$file" 2>/dev/null || echo 0)
        name=$(basename "$file" .swift)
        printf "  %-25s: %4d tests\n" "$name" "$count"
    fi
done | sort -u

echo ""
echo "Chaos Engineering:"
for file in "$OUTPUT_DIR"/*Chaos*.swift; do
    if [ -f "$file" ]; then
        count=$(grep -c "@Test" "$file" 2>/dev/null || echo 0)
        name=$(basename "$file" .swift)
        printf "  %-25s: %4d tests\n" "$name" "$count"
    fi
done

echo ""
echo "Property-Based Tests:"
for file in "$OUTPUT_DIR"/*Property*.swift; do
    if [ -f "$file" ]; then
        count=$(grep -c "@Test" "$file" 2>/dev/null || echo 0)
        name=$(basename "$file" .swift)
        printf "  %-25s: %4d tests\n" "$name" "$count"
    fi
done

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    TESTING FEATURES COVERED                        ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  ✅ XCTest Performance Metrics"
echo "     • XCTClockMetric - Wall clock time"
echo "     • XCTCPUMetric - CPU cycles/instructions"
echo "     • XCTMemoryMetric - Physical memory"
echo "     • XCTStorageMetric - Disk I/O"
echo "     • XCTApplicationLaunchMetric - Startup"
echo ""
echo "  ✅ Memory Leak Detection"
echo "     • Weak reference tracking"
echo "     • Retain cycle detection"
echo "     • Closure capture validation"
echo "     • Async/await leak detection"
echo "     • ARC compliance verification"
echo ""
echo "  ✅ Crash & Stability"
echo "     • Crash detection & reporting"
echo "     • Watchdog termination handling"
echo "     • App hang detection (2s+)"
echo "     • Graceful degradation"
echo "     • Soft failure handling"
echo "     • State restoration"
echo "     • Signal handling (SIGILL/SEGV/etc)"
echo ""
echo "  ✅ Chaos Engineering"
echo "     • Network failures (delay, timeout, loss)"
echo "     • Resource exhaustion (memory, disk, CPU)"
echo "     • Timing issues (race, deadlock)"
echo "     • State corruption"
echo "     • Dependency failures"
echo ""
echo "  ✅ Property-Based Testing"
echo "     • Round-trip properties"
echo "     • Idempotency verification"
echo "     • Algebraic properties"
echo "     • Invariant preservation"
echo "     • Fuzz testing"
echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                      NEXT STEPS                                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "  1. Build the test target:"
echo "     xcodebuild build-for-testing -project Epistemos.xcodeproj \\"
echo "       -scheme Epistemos -destination 'platform=macOS'"
echo ""
echo "  2. Run all tests:"
echo "     xcodebuild test -project Epistemos.xcodeproj \\"
echo "       -scheme Epistemos -destination 'platform=macOS'"
echo ""
echo "  3. Run specific test category:"
echo "     xcodebuild test -project Epistemos.xcodeproj \\"
echo "       -only-testing:EpistemosTests/NotePerformanceBenchmarkTests"
echo ""
echo "  4. Profile with Instruments:"
echo "     - Open Xcode → Product → Profile (⌘I)"
echo "     - Select: Time Profiler / Allocations / Leaks / Game Memory"
echo ""
echo "  5. Enable diagnostics in Xcode:"
echo "     Edit Scheme → Run → Diagnostics:"
echo "     ☑ Malloc Stack Logging"
echo "     ☑ Zombie Objects"
echo "     ☑ Address Sanitizer (for memory)"
echo "     ☑ Thread Sanitizer (for races)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Verify total count
EXISTING_TESTS=$(find "/Users/jojo/Epistemos/EpistemosTests" -name "*.swift" -not -path "*/Generated/*" -exec grep -c "@Test" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
RUST_TESTS=$(cd /Users/jojo/Epistemos/graph-engine && cargo test 2>&1 | grep "^test result" | awk '{print $4}' || echo 0)

echo "📊 PROJECT TOTALS ESTIMATE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Hand-written Swift tests: ~$EXISTING_TESTS"
echo "  Generated Swift tests:    ~$TEST_COUNT"
echo "  Rust tests:               ~$RUST_TESTS"
echo "  ─────────────────────────────────────"
echo "  ESTIMATED TOTAL:          ~$(($EXISTING_TESTS + $TEST_COUNT + $RUST_TESTS)) tests"
echo ""
