# Epistemos Testing Guide

**Comprehensive testing strategy for performance, memory, stability, and correctness.**

---

## 📊 Test Suite Overview

| Category | Count | Description |
|----------|-------|-------------|
| **Total Swift Tests** | ~10,000+ | Generated + hand-written |
| **Rust Tests** | 2,143 | Physics engine |
| **Test Files** | 228 | Organized by category |

---

## 🚀 Quick Start

### Run All Tests
```bash
./scripts/xcodebuild_epistemos.sh build-for-testing -project Epistemos.xcodeproj \
  -scheme Epistemos -destination 'platform=macOS'

./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj \
  -scheme Epistemos -destination 'platform=macOS'
```

`./scripts/xcodebuild_epistemos.sh` exports `DISABLE_SWIFTLINT=1` in the real process environment so transitive SwiftLint package plug-ins from the embedded CodeEdit dependencies do not fail the build with the current Xcode 16 `Output` directory bug.

### Run Specific Categories
```bash
# Performance benchmarks only
./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj \
  -only-testing:EpistemosTests/NotePerformanceBenchmarkTests

# Memory leak tests
./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj \
  -only-testing:EpistemosTests/BasicMemoryLeakTests

# Chaos tests
./scripts/xcodebuild_epistemos.sh test -project Epistemos.xcodeproj \
  -only-testing:EpistemosTests/NetworkChaosTests
```

---

## 📋 Test Categories

### 1. Performance Benchmarks

Uses XCTest Metrics for precise measurement:

| Metric | Purpose | Example |
|--------|---------|---------|
| `XCTClockMetric` | Wall clock time | UI responsiveness |
| `XCTCPUMetric` | CPU cycles/instructions | Algorithm efficiency |
| `XCTMemoryMetric` | Physical memory | Memory pressure scenarios |
| `XCTStorageMetric` | Disk I/O | File operations |
| `XCTApplicationLaunchMetric` | Startup time | Cold/warm start |

**Example Test:**
```swift
@Test("Note creation performance")
func testNoteCreationBenchmark() throws {
    let metrics: [XCTMetric] = [XCTClockMetric(), XCTMemoryMetric()]
    let options = XCTMeasureOptions()
    options.iterationCount = 10
    
    measure(metrics: metrics, options: options) {
        let note = Note(title: "Benchmark")
        _ = note.render()
    }
}
```

### 2. Memory Leak Detection

**Techniques Used:**
- Weak reference tracking
- Autoreleasepool validation
- Deallocation verification
- Retain cycle detection
- Closure capture analysis

**Key Patterns:**
```swift
@Test("ViewController memory leak")
func testViewControllerDeallocation() async throws {
    weak var weakRef: ViewController?
    
    autoreleasepool {
        let strongRef = ViewController()
        weakRef = strongRef
        strongRef.loadView()
    }
    
    try await Task.sleep(100_000_000) // 0.1s
    #expect(weakRef == nil, "Memory leak detected")
}
```

### 3. Crash Recovery & Stability

**Coverage Areas:**
- Crash detection (fatalError, precondition failures)
- Watchdog termination (>10s main thread block)
- App hang detection (2s+ threshold)
- Graceful degradation
- Soft failure handling
- Signal handling (SIGILL, SIGSEGV, etc.)

### 4. Chaos Engineering

**Failure Injection:**
- Network: delays, timeouts, packet loss
- Resources: memory pressure, disk exhaustion
- Timing: race conditions, deadlocks
- State: corruption, partial writes
- Dependencies: service unavailability

### 5. Property-Based Testing

**Properties Verified:**
- Round-trip: `decode(encode(x)) == x`
- Idempotency: `f(f(x)) == f(x)`
- Commutativity: `a.merge(b) == b.merge(a)`
- Associativity: `(a+b)+c == a+(b+c)`
- Invariant preservation across random operations

---

## 🛠️ Xcode Diagnostic Tools

### Enable Diagnostics
**Edit Scheme → Run → Diagnostics:**

| Diagnostic | Purpose | When to Use |
|------------|---------|-------------|
| ☑ Malloc Stack Logging | Track allocation sources | Memory leak investigation |
| ☑ Zombie Objects | Detect use-after-free | Crash debugging |
| ☑ Address Sanitizer | Memory error detection | Development/testing |
| ☑ Thread Sanitizer | Race condition detection | Concurrency debugging |
| ☑ Undefined Behavior | UB detection | Code correctness |

### Instruments Templates

**Open:** Xcode → Product → Profile (⌘I)

| Template | Use Case | Key Metrics |
|----------|----------|-------------|
| **Time Profiler** | CPU bottlenecks | % of run time per function |
| **Allocations** | Memory leaks | Live bytes, allocation count |
| **Leaks** | Memory leak detection | Leaked objects, backtraces |
| **VM Tracker** | Virtual memory | Dirty vs clean memory |
| **Game Memory** | Metal/GPU memory | Texture/buffer allocations |
| **File Activity** | Disk I/O | Read/write operations |
| **Network** | Network performance | Latency, throughput |

---

## 📈 Performance Testing Best Practices

### 1. Establish Baselines
```swift
// Set baseline on first run
measure(metrics: [XCTClockMetric()]) {
    performOperation()
}
// Xcode will fail test if performance regresses >10%
```

### 2. Isolate Test Code
```swift
// Good: Specific operation
measure {
    graph.layout(nodes: testNodes)
}

// Bad: Too much setup
measure {
    let graph = createLargeGraph() // Don't measure setup
    graph.layout(nodes: testNodes)
}
```

### 3. Use Appropriate Iterations
```swift
// Fast operations: more iterations
options.iterationCount = 100

// Slow operations: fewer iterations  
options.iterationCount = 5
```

---

## 🔍 Memory Debugging Workflow

### Step 1: Memory Graph Debugger
1. Run app in Xcode
2. Click "Debug Memory Graph" button (debug bar)
3. Visualize object relationships
4. Look for unexpected strong references

### Step 2: Instruments Allocations
1. Product → Profile (⌘I)
2. Select "Allocations"
3. Record while exercising features
4. Look for:
   - Growing "Persistent" bytes
   - Unexpected object counts
   - Allocation backtraces

### Step 3: Leaks Instrument
1. Select "Leaks" template
2. Record for extended period
3. Check for "Leaks" in call tree
4. Examine object retention cycles

---

## 🔄 Test Generation

### Regenerate All Tests
```bash
cd /Users/jojo/Epistemos
./scripts/generate_all_tests_comprehensive.sh
```

### Individual Generators
```bash
# Basic category tests
python3 scripts/generate_tests.py

# Performance benchmarks
python3 scripts/generate_performance_benchmark_tests.py

# Memory leak detection
python3 scripts/generate_memory_leak_tests.py

# Crash recovery
python3 scripts/generate_crash_recovery_tests.py

# Chaos engineering
python3 scripts/generate_chaos_tests.py

# Property-based tests
python3 scripts/generate_property_based_tests.py
```

---

## 📊 Interpreting Results

### Performance Test Output
```
Test Case '-[NotePerformanceBenchmarkTests testNoteCreation]'
  measured [Time, seconds] 0.001234 ± 0.000123 (10 iterations)
  measured [Memory, KB] 45.2 ± 2.1 (10 iterations)
  Baseline: 0.001100 @ 10 iterations
  ⚠️ Performance regression: +12%
```

### Memory Leak Detection
```
Test Case '-[BasicMemoryLeakTests testViewControllerDeallocation]'
  ✓ weakRef == nil (object properly deallocated)
```

### Crash Recovery
```
Test Case '-[GracefulDegradationTests testLowMemoryDegradation]'
  ✓ result.success (operation completed)
  ✓ result.degraded (degradation indicated)
  ✓ manager.isResponsive (UI still responsive)
```

---

## 🎯 CI/CD Integration

### GitHub Actions Example
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build
        run: |
          xcodebuild build-for-testing \
            -project Epistemos.xcodeproj \
            -scheme Epistemos
      
      - name: Test
        run: |
          xcodebuild test \
            -project Epistemos.xcodeproj \
            -scheme Epistemos \
            -resultBundlePath TestResults.xcresult
      
      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: TestResults.xcresult
```

---

## 🔧 Troubleshooting

### Tests Not Running
```bash
# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset simulators
xcrun simctl erase all
```

### Performance Tests Flaky
- Close other applications
- Disable network sync (Dropbox, etc.)
- Run on real device for accurate metrics
- Increase iteration count for stability

### Memory Tests Failing
- Check for singletons/statics
- Verify autoreleasepool usage
- Ensure async operations complete
- Review closure capture lists

---

## 📚 Additional Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Instruments User Guide](https://help.apple.com/instruments/mac/current/)
- [Memory Management Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MemoryMgmt/)
- [Performance Best Practices](https://developer.apple.com/documentation/xcode/addressing-performance-issues)

---

## 🏆 Test Quality Checklist

- [ ] Performance tests have baselines set
- [ ] Memory leak tests use weak references
- [ ] Crash recovery tests verify graceful degradation
- [ ] Chaos tests don't cause actual crashes
- [ ] Property tests cover edge cases
- [ ] Tests run in < 5 minutes total
- [ ] CI passes on clean environment
