#!/bin/bash
# List all available test categories

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                   AVAILABLE TEST CATEGORIES                        ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

#######################################
# RUST TESTS
#######################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 RUST TESTS (graph-engine)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
cd "$PROJECT_DIR/graph-engine"
cargo test --list 2>/dev/null | head -20 || echo "   (Run 'cargo test --list' to see all)"
echo ""

#######################################
# SWIFT TESTS
#######################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 SWIFT TEST CATEGORIES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROJECT_DIR"

# Count tests by category
echo "📊 Test Count by Category:"
echo ""

# Performance Benchmarks
count=$(find EpistemosTests/Generated -name "*PerformanceBenchmarkTests.swift" -exec grep -c "@Test" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
printf "  Performance Benchmarks:  %5d tests\n" "${count:-0}"

# Memory Leak
count=$(find EpistemosTests/Generated -name "*MemoryLeak*.swift" -o -name "*MemoryTests.swift" -o -name "CircularReferenceTests.swift" -o -name "DeallocationVerificationTests.swift" -o -name "MemoryGraphValidationTests.swift" 2>/dev/null | xargs grep -c "@Test" 2>/dev/null | awk '{sum+=$1} END {print sum}')
printf "  Memory Leak Detection:   %5d tests\n" "${count:-0}"

# Crash/Stability
count=$(find EpistemosTests/Generated \( -name "Crash*.swift" -o -name "Watchdog*.swift" -o -name "*Hang*.swift" -o -name "Graceful*.swift" -o -name "Soft*.swift" -o -name "Recovery*.swift" -o -name "State*.swift" -o -name "Signal*.swift" \) 2>/dev/null | xargs grep -c "@Test" 2>/dev/null | awk '{sum+=$1} END {print sum}')
printf "  Crash & Stability:       %5d tests\n" "${count:-0}"

# Chaos
count=$(find EpistemosTests/Generated -name "*ChaosTests.swift" -exec grep -c "@Test" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
printf "  Chaos Engineering:       %5d tests\n" "${count:-0}"

# Property-Based
count=$(find EpistemosTests/Generated -name "*PropertyTests.swift" -exec grep -c "@Test" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
printf "  Property-Based:          %5d tests\n" "${count:-0}"

# Generated Basic
count=$(find EpistemosTests/Generated -name "*GeneratedTests*.swift" ! -name "*Performance*" ! -name "*Memory*" ! -name "*Leak*" ! -name "*Chaos*" ! -name "*Property*" ! -name "Circular*" ! -name "Deallocation*" ! -name "MemoryGraph*" -exec grep -c "@Test" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
printf "  Generated (Basic):       %5d tests\n" "${count:-0}"

# Edge Cases
count=$(find EpistemosTests/Generated \( -name "BoundaryConditionTests.swift" -o -name "UnicodeEdgeCaseTests.swift" -o -name "FuzzTests.swift" -o -name "StressTests.swift" -o -name "ConcurrencyEdgeTests.swift" \) -exec grep -c "@Test" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
printf "  Edge Cases:              %5d tests\n" "${count:-0}"

# Hand-written
count=$(find EpistemosTests -name "*.swift" ! -path "*/Generated/*" -exec grep -c "@Test" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
printf "  Hand-written:            %5d tests\n" "${count:-0}"

#######################################
# TOTAL
#######################################
echo "  ─────────────────────────────────────"
TOTAL=$(find EpistemosTests -name "*.swift" -exec grep -c "@Test" {} + 2>/dev/null | awk '{sum+=$1} END {print sum}')
printf "  TOTAL SWIFT TESTS:       %5d tests\n" "$TOTAL"
echo ""

#######################################
# RUNNER SCRIPTS
#######################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 AVAILABLE RUNNER SCRIPTS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$SCRIPT_DIR"

for script in run_*.sh; do
    if [ -f "$script" ]; then
        desc=$(head -3 "$script" | grep -v "^#" | head -1 || echo "Run tests")
        echo "  ./scripts/$script"
        echo "      └─ ${desc:-Run tests}"
        echo ""
    fi
done

#######################################
# USAGE
#######################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📖 USAGE EXAMPLES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  # Run all tests (Rust + Swift)"
echo "  ./scripts/run_all_tests.sh"
echo ""
echo "  # Run only Rust tests"
echo "  ./scripts/run_rust_tests.sh"
echo ""
echo "  # Run only Swift tests"
echo "  ./scripts/run_swift_tests.sh"
echo ""
echo "  # Run specific category"
echo "  ./scripts/run_performance_tests.sh"
echo "  ./scripts/run_memory_leak_tests.sh"
echo "  ./scripts/run_stability_tests.sh"
echo "  ./scripts/run_chaos_tests.sh"
echo ""
echo "  # Run specific test suite"
echo "  xcodebuild test -only-testing:EpistemosTests/NotePerformanceBenchmarkTests"
echo ""
