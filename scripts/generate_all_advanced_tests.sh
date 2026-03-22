#!/bin/bash
# Advanced Test Generator for Epistemos
# Generates performance benchmarks, memory leak detection, crash recovery, and stability tests

set -e

echo "═══════════════════════════════════════════════════════════════════"
echo "  Epistemos Advanced Test Generator"
echo "  Performance • Memory Leaks • Crash Recovery • Stability"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="/Users/jojo/Epistemos/EpistemosTests/Generated"

# Clean previous generated tests
echo "🧹 Cleaning previous generated tests..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo ""
echo "📦 Running performance benchmark generator..."
python3 "$SCRIPT_DIR/generate_performance_benchmark_tests.py"

echo ""
echo "🔍 Running memory leak detection generator..."
python3 "$SCRIPT_DIR/generate_memory_leak_tests.py"

echo ""
echo "🛡️  Running crash recovery & stability generator..."
python3 "$SCRIPT_DIR/generate_crash_recovery_tests.py"

# Count generated tests
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  Generation Complete!"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

FILE_COUNT=$(find "$OUTPUT_DIR" -name "*.swift" | wc -l)
TEST_COUNT=$(grep -r "@Test" "$OUTPUT_DIR" --include="*.swift" 2>/dev/null | wc -l)

echo "📁 Files generated: $FILE_COUNT"
echo "🧪 Tests generated: $TEST_COUNT"
echo ""

# Summary by category
echo "Test Categories:"
echo ""
echo "Performance Benchmarks:"
for file in "$OUTPUT_DIR"/*PerformanceBenchmarkTests.swift; do
    if [ -f "$file" ]; then
        count=$(grep -c "@Test" "$file" 2>/dev/null || echo 0)
        name=$(basename "$file" .swift)
        printf "  %-35s: %4d tests\n" "$name" "$count"
    fi
done

echo ""
echo "Memory Leak Detection:"
for file in "$OUTPUT_DIR"/*Memory*.swift "$OUTPUT_DIR"/*Leak*.swift "$OUTPUT_DIR"/CircularReferenceTests.swift "$OUTPUT_DIR"/DeallocationVerificationTests.swift; do
    if [ -f "$file" ]; then
        count=$(grep -c "@Test" "$file" 2>/dev/null || echo 0)
        name=$(basename "$file" .swift)
        printf "  %-35s: %4d tests\n" "$name" "$count"
    fi
done

echo ""
echo "Crash Recovery & Stability:"
for file in "$OUTPUT_DIR"/Crash*.swift "$OUTPUT_DIR"/Watchdog*.swift "$OUTPUT_DIR"/*Hang*.swift "$OUTPUT_DIR"/Graceful*.swift "$OUTPUT_DIR"/Soft*.swift "$OUTPUT_DIR"/Recovery*.swift "$OUTPUT_DIR"/State*.swift "$OUTPUT_DIR"/Signal*.swift; do
    if [ -f "$file" ]; then
        count=$(grep -c "@Test" "$file" 2>/dev/null || echo 0)
        name=$(basename "$file" .swift)
        printf "  %-35s: %4d tests\n" "$name" "$count"
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  Key Testing Features Generated:"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "  ✅ XCTest Performance Metrics:"
echo "     • XCTClockMetric - Wall clock time measurement"
echo "     • XCTCPUMetric - CPU cycles and instructions"
echo "     • XCTMemoryMetric - Physical memory usage"
echo "     • XCTStorageMetric - Disk I/O measurement"
echo "     • XCTApplicationLaunchMetric - Startup time"
echo ""
echo "  ✅ Memory Leak Detection:"
echo "     • Weak reference tracking"
echo "     • Retain cycle detection"
echo "     • Closure capture validation"
echo "     • Async/await leak detection"
echo "     • Singleton cleanup verification"
echo ""
echo "  ✅ Crash & Stability:"
echo "     • Crash detection and reporting"
echo "     • Watchdog termination handling"
echo "     • App hang detection (>2s threshold)"
echo "     • Graceful degradation testing"
echo "     • Soft failure handling"
echo "     • State restoration after crash"
echo "     • Signal handling (SIGILL, SIGSEGV, etc.)"
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "  Next Steps:"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "  1. Build tests:"
echo "     xcodebuild build-for-testing -project Epistemos.xcodeproj -scheme Epistemos"
echo ""
echo "  2. Run performance tests:"
echo "     xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos \\"
echo "       -only-testing:EpistemosTests/NotePerformanceBenchmarkTests"
echo ""
echo "  3. Run memory leak tests:"
echo "     xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos \\"
echo "       -only-testing:EpistemosTests/BasicMemoryLeakTests"
echo ""
echo "  4. Profile with Instruments:"
echo "     - Open Xcode → Product → Profile (Cmd+I)"
echo "     - Select: Time Profiler, Allocations, or Leaks"
echo "     - Record and analyze performance"
echo ""
echo "  5. Enable diagnostic flags in Xcode:"
echo "     - Malloc Stack Logging"
echo "     - Zombie Objects"
echo "     - Address Sanitizer"
echo "     - Thread Sanitizer"
echo ""
