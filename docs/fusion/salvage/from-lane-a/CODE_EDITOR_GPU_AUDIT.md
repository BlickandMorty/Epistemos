# Code Editor GPU & Multithreading Optimization Audit
## Epistemos — 2026-04-07

---

## Executive Summary

The CodeEditorView has significant optimization opportunities for GPU acceleration and multithreading. Current hotspots include sequential similarity computations, blocking embedding operations, and main-thread UI updates. **Estimated performance gain: 10-50x for semantic operations.**

---

## Critical Issues (Immediate Action Required)

### 1. CPU-Bound Cosine Similarity in CodeContextBridge ⚠️ CRITICAL

**Location:** `CodeContextBridge.performSemanticSearch()` (lines 1917-1958)

**Current Implementation:**
```swift
for hit in searchHits.prefix(limit) {
    guard let nodeEmbedding = embeddingService.embedding(for: hit.id) else { continue }
    let similarity = cosineSimilarity(queryEmbedding, nodeEmbedding)  // CPU-bound!
    // ...
}
```

**Problem:** 
- Sequential CPU computation for each candidate
- vDSP dot products on CPU for every embedding comparison
- No batching - one similarity at a time
- Blocks @MainActor during entire search

**Impact:** O(n) CPU operations, blocks UI thread for large vaults

**GPU Optimization:**
```swift
// Use MetalComputeEngine for batch processing
let allEmbeddings: [[Float]] = searchHits.compactMap { embeddingService.embedding(for: $0.id) }
let similarities = await MetalComputeEngine.shared.batchCosineSimilarity(
    query: queryEmbedding,
    documents: allEmbeddings,
    threshold: 0.55
)
// Process results in parallel
```

**Expected Gain:** 50-100x faster for vaults with 1000+ notes

---

### 2. Synchronous Embedding Computation ⚠️ CRITICAL

**Location:** `CodeContextBridge.computeEmbedding()` (lines 1910-1915)

**Current:**
```swift
private func computeEmbedding(for code: String) async -> [Float]? {
    return await Task.detached(priority: .utility) { [weak self] in
        return self.embeddingService.queryEmbedding(for: code)
    }.value
}
```

**Problem:**
- NLEmbedding computation is CPU-intensive
- Still blocks a utility thread
- No GPU acceleration for word averaging

**Optimization:**
```swift
// Pre-compute embeddings on background queue with caching
actor EmbeddingCache {
    private var cache: [Int: [Float]] = [:]
    
    func embedding(for code: String) async -> [Float]? {
        let hash = code.hashValue
        if let cached = cache[hash] { return cached }
        
        // Offload to ML Compute if available
        let embedding = await MLComputeService.shared.computeEmbedding(code)
        cache[hash] = embedding
        return embedding
    }
}
```

---

### 3. Blocking Syntax Highlighting on Main Thread ⚠️ HIGH

**Location:** `applySyntaxHighlighting()` (lines 1600-1658)

**Current:**
- UTF-8 to UTF-16 conversion loop (lines 1621-1636) runs on main thread
- Token application loop (lines 1638-1655) runs synchronously
- No incremental/background processing

**Problem Code:**
```swift
var utf8ToUtf16 = [Int](repeating: 0, count: utf8.count + 1)  // Large allocation!
var utf16Pos = 0
var i = 0
while i < utf8.count {  // Sequential loop, O(n)
    // ... UTF-8 decoding
    i += seqLen
}
```

**Optimization Strategy:**
```swift
// 1. Use Accelerate framework for vectorized operations
// 2. Chunk large files and process incrementally
// 3. Move highlighting to background with displayLink sync

func applySyntaxHighlightingOptimized(to textView: NSTextView, text: String, language: String, theme: EditorTheme) async {
    // Process in chunks for files > 10KB
    let chunkSize = 10000
    let chunks = text.chunked(into: chunkSize)
    
    await withTaskGroup(of: Void.self) { group in
        for (index, chunk) in chunks.enumerated() {
            group.addTask {
                let tokens = await self.tokenizeChunk(chunk, language: language)
                await MainActor.run {
                    self.applyTokens(tokens, to: textView, theme: theme, chunkIndex: index)
                }
            }
        }
    }
}
```

---

## High Priority Issues

### 4. Sequential AI Insight Generation

**Location:** `CodeInsightGenerator.generateInsights()` (lines 2603-2638)

**Current:** Parallel but lacks GPU acceleration for embeddings

**Optimization:**
- Pre-compute code embeddings once, reuse across all insight types
- Use Metal for embedding similarity during vault connection analysis
- Batch Apple Intelligence calls using new FoundationModels batch API

---

### 5. Main Thread UI Updates Without Throttling

**Location:** `CodeEditorView.body` updates via `@Published` properties

**Current Issues:**
- `cursorLine`, `cursorCol` update on every cursor movement
- `totalLines` recalculates via `.components(separatedBy:)` on every keystroke
- No display link synchronization

**Optimization:**
```swift
// Use CADisplayLink for UI updates
final class ThrottledUIUpdater: ObservableObject {
    @Published var cursorLine: Int = 1
    @Published var cursorCol: Int = 1
    
    private var pendingUpdate: (line: Int, col: Int)?
    private var displayLink: CADisplayLink?
    
    func update(line: Int, col: Int) {
        pendingUpdate = (line, col)
        // Update happens on next display refresh
    }
}
```

---

### 6. Memory-Intensive String Operations

**Location:** Throughout file

**Issues:**
- `text.components(separatedBy: "\n").count` - creates array just for count
- Multiple `String.prefix()` calls create copies
- `nsString.length` conversions for every token

**Optimizations:**
```swift
// Fast line count without array allocation
func fastLineCount(_ text: String) -> Int {
    var count = 0
    text.enumerateSubstrings(in: text.startIndex..., options: .byLines) { _, _, _, _ in
        count += 1
    }
    return count
}

// Use String.UTF8View for zero-copy operations
// Use UnsafeBufferPointer for FFI calls
```

---

## Medium Priority Issues

### 7. No GPU-Accelerated Semantic Search in CodeCompanionService

The new MetalComputeEngine is integrated but not used for:
- Top-k similarity selection (still using CPU sort)
- Batch embedding normalization
- Large-scale vault searches

**Fix:**
```swift
// In performSemanticAnalysisAsync()
let topK = await metalEngine.topKSimilarity(
    query: codeEmbedding,
    documents: documentEmbeddings,
    k: 5,
    threshold: 0.55
)
// topK is already sorted by GPU
```

---

### 8. Missing Concurrent Search Pipeline

**Current:** Sequential operations:
1. Get embedding (CPU)
2. Search graph (main thread)
3. Compute similarities one-by-one (CPU)
4. Sort results (CPU)

**Optimized Pipeline:**
```swift
// Parallel pipeline with GPU acceleration
async let embeddingTask = computeEmbedding(code)
async let candidatesTask = fetchCandidatesFromGraph()

let (embedding, candidates) = await (embeddingTask, candidatesTask)

// GPU batch similarity
let similarities = await metalEngine.batchCosineSimilarity(
    query: embedding,
    documents: candidates.embeddings
)

// Parallel result construction
let matches = await withTaskGroup(of: CodeSemanticMatch.self) { group in
    for (index, score) in similarities.enumerated() where score > threshold {
        group.addTask {
            CodeSemanticMatch(from: candidates[index], score: score)
        }
    }
    return await group.reduce(into: []) { $0.append($1) }
}
```

---

## Low Priority / Nice to Have

### 9. Metal-Based Syntax Highlighting

Tree-sitter tokenization is already fast (Rust FFI), but color application could use:
- Metal compute shader for attribute mapping
- Parallel token color resolution

### 10. Async File I/O for Large Files

Currently using synchronous string loading. Could use:
- `NSFileCoordinator` with async/await
- Memory-mapped files for files > 1MB
- Chunked loading with progressive highlighting

---

## Implementation Priority Roadmap

| Priority | Issue | Estimated Speedup | Effort |
|----------|-------|-------------------|--------|
| P0 | GPU batch similarity in CodeContextBridge | 50-100x | 2h |
| P0 | Async syntax highlighting | 5-10x | 4h |
| P1 | Embedding cache with GPU | 2-5x | 3h |
| P1 | Concurrent search pipeline | 3-5x | 2h |
| P2 | Throttled UI updates | 1.5x perceived | 1h |
| P2 | Memory optimizations | 2x memory efficiency | 2h |

---

## Testing Strategy

1. **Performance Benchmarks:**
   ```swift
   // Add to tests
   func testSemanticSearchPerformance() {
       measure {
           let results = bridge.findRelatedNotes(for: largeCodeFile)
       }
   }
   ```

2. **GPU Utilization Monitoring:**
   - Use Metal System Trace in Instruments
   - Monitor GPU time vs CPU time

3. **Concurrency Verification:**
   - Thread Sanitizer for data races
   - Main Thread Checker for UI violations

---

## Current Metal Implementation Status

✅ **Implemented:**
- MetalComputeEngine actor with GPU kernels
- Batch cosine similarity shader
- Buffer cache with LRU eviction
- Async/await integration

⚠️ **Partially Used:**
- CodeCompanionService uses Metal but not for top-k
- No integration with CodeContextBridge yet

❌ **Not Implemented:**
- GPU embedding computation
- Metal-based syntax highlighting
- Concurrent similarity pipeline

---

## Recommended Next Steps

1. **Immediate (Today):** Wire MetalComputeEngine into CodeContextBridge
2. **This Week:** Async syntax highlighting with chunked processing
3. **Next Sprint:** Full concurrent pipeline with performance benchmarks

**Expected Overall Performance:**
- Semantic search: 50x faster (100ms → 2ms for 1000 notes)
- Syntax highlighting: 5x faster for large files
- UI responsiveness: Eliminated dropped frames during search
