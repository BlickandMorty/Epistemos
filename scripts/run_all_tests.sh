#!/bin/bash
# Run ALL tests - Swift + Rust
# Comprehensive test execution with reporting

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$PROJECT_DIR/test_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

mkdir -p "$RESULTS_DIR"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                    EPISTEMOS TEST RUNNER                           ║"
echo "║                     Running ALL Tests                              ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Project: $PROJECT_DIR"
echo "📊 Results: $RESULTS_DIR"
echo "🕐 Started: $(date)"
echo ""

# Track results
RUST_PASSED=0
RUST_FAILED=0
SWIFT_PASSED=0
SWIFT_FAILED=0
BUILD_SUCCESS=false

#######################################
# RUST TESTS
#######################################
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 PHASE 1: RUST TESTS (graph-engine)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROJECT_DIR/graph-engine"

echo "→ Building Rust engine..."
if cargo build --quiet 2>&1; then
    echo -e "${GREEN}✅ Rust build successful${NC}"
    
    echo ""
    echo "→ Running Rust tests..."
    if cargo test 2>&1 | tee "$RESULTS_DIR/rust_tests_$TIMESTAMP.log"; then
        RUST_RESULT=$(grep "^test result" "$RESULTS_DIR/rust_tests_$TIMESTAMP.log" || echo "test result: unknown")
        echo ""
        echo -e "${GREEN}✅ Rust tests complete${NC}"
        echo "   $RUST_RESULT"
        
        # Parse results
        RUST_PASSED=$(echo "$RUST_RESULT" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || echo 0)
        RUST_FAILED=$(echo "$RUST_RESULT" | grep -oE '[0-9]+ failed' | grep -oE '[0-9]+' || echo 0)
    else
        echo -e "${RED}❌ Rust tests failed${NC}"
        RUST_FAILED=1
    fi
else
    echo -e "${RED}❌ Rust build failed${NC}"
    RUST_FAILED=1
fi

#######################################
# SWIFT BUILD
#######################################
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔨 PHASE 2: SWIFT BUILD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd "$PROJECT_DIR"

echo "→ Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Epistemos-*

echo "→ Building Swift test target..."
if xcodebuild build-for-testing \
    -project Epistemos.xcodeproj \
    -scheme Epistemos \
    -destination 'platform=macOS' \
    -quiet 2>&1 | tee "$RESULTS_DIR/swift_build_$TIMESTAMP.log"; then
    
    echo -e "${GREEN}✅ Swift build successful${NC}"
    BUILD_SUCCESS=true
else
    echo -e "${RED}❌ Swift build failed${NC}"
    echo "   Check logs: $RESULTS_DIR/swift_build_$TIMESTAMP.log"
    BUILD_SUCCESS=false
fi

#######################################
# SWIFT TESTS
#######################################
if [ "$BUILD_SUCCESS" = true ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🧪 PHASE 3: SWIFT TESTS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    echo "→ Running Swift tests (this may take several minutes)..."
    echo ""
    
    if xcodebuild test \
        -project Epistemos.xcodeproj \
        -scheme Epistemos \
        -destination 'platform=macOS' \
        -resultBundlePath "$RESULTS_DIR/swift_tests_$TIMESTAMP.xcresult" \
        2>&1 | tee "$RESULTS_DIR/swift_tests_$TIMESTAMP.log"; then
        
        echo ""
        echo -e "${GREEN}✅ Swift tests complete${NC}"
        
        # Parse test results from log
        if grep -q "Test Suite.*failed" "$RESULTS_DIR/swift_tests_$TIMESTAMP.log"; then
            SWIFT_FAILED=$(grep -c "Test Case.*failed" "$RESULTS_DIR/swift_tests_$TIMESTAMP.log" || echo 0)
        else
            SWIFT_FAILED=0
        fi
        
        SWIFT_PASSED=$(grep -c "Test Case.*passed" "$RESULTS_DIR/swift_tests_$TIMESTAMP.log" || echo 0)
    else
        echo ""
        echo -e "${YELLOW}⚠️  Swift tests completed with failures${NC}"
        SWIFT_FAILED=$(grep -c "Test Case.*failed" "$RESULTS_DIR/swift_tests_$TIMESTAMP.log" || echo 0)
        SWIFT_PASSED=$(grep -c "Test Case.*passed" "$RESULTS_DIR/swift_tests_$TIMESTAMP.log" || echo 0)
    fi
else
    echo ""
    echo -e "${YELLOW}⚠️  Skipping Swift tests (build failed)${NC}"
fi

#######################################
# SUMMARY
#######################################
echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                        TEST SUMMARY                                ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

TOTAL_PASSED=$((RUST_PASSED + SWIFT_PASSED))
TOTAL_FAILED=$((RUST_FAILED + SWIFT_FAILED))

printf "  %-20s: %5s tests\n" "Rust Tests" "$RUST_PASSED"
printf "  %-20s: %5s tests\n" "Swift Tests" "$SWIFT_PASSED"
echo "  ─────────────────────────────────────────"
printf "  %-20s: %5s tests\n" "TOTAL PASSED" "$TOTAL_PASSED"
printf "  %-20s: %5s tests\n" "TOTAL FAILED" "$TOTAL_FAILED"
echo ""

if [ "$TOTAL_FAILED" -eq 0 ] && [ "$BUILD_SUCCESS" = true ]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED!${NC}"
    echo ""
    echo "📊 Test Results:"
    echo "   Rust: $RUST_PASSED passed"
    echo "   Swift: $SWIFT_PASSED passed"
    echo ""
    echo "📁 Logs saved to: $RESULTS_DIR"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo ""
    echo "📊 Test Results:"
    echo "   Rust: $RUST_PASSED passed, $RUST_FAILED failed"
    echo "   Swift: $SWIFT_PASSED passed, $SWIFT_FAILED failed"
    echo ""
    echo "📁 Logs saved to:"
    echo "   $RESULTS_DIR/rust_tests_$TIMESTAMP.log"
    echo "   $RESULTS_DIR/swift_tests_$TIMESTAMP.log"
    echo "   $RESULTS_DIR/swift_tests_$TIMESTAMP.xcresult"
    echo ""
    echo "🔍 To view detailed results:"
    echo "   xcrun xcresulttool view $RESULTS_DIR/swift_tests_$TIMESTAMP.xcresult"
    exit 1
fi
