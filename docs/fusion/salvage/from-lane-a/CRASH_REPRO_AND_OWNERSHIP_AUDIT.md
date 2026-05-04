# FFI Crash Audit: graph_engine_recompute_semantic_neighbors

**Date:** 2026-04-05  
**Issue:** Allocator abort `___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED`  
**Location:** `EmbeddingService.swift:215` → `graph_engine_recompute_semantic_neighbors`

---

## 1. Current Call Chain (Swift → Rust)

### Swift Side: EmbeddingService.swift

```swift
// Line 207-220
computeTask = Task.detached(priority: .utility) { [weak self] in
    // ... embedding computation ...
    
    let engineHandle: SendableEngineHandle? = await MainActor.run { [weak self] in
        guard let self, !Task.isCancelled else { return nil }
        self.dimension = dim
        self.replaceEmbeddingCache(with: completedEmbeddings)
        guard let engine = self.graphState?.engineHandle else { return nil }
        return SendableEngineHandle(raw: engine)
    }

    guard !Task.isCancelled,
          let engineHandle,
          !payload.isEmpty,
          Self.prepareEngineEmbeddingStore(engineHandle.raw, dimension: dim) else {
        return
    }

    Self.sendEmbeddingBatch(payload, to: engineHandle.raw)
    graph_engine_recompute_semantic_neighbors(engineHandle.raw, 8, 0.3)  // CRASH HERE
}
```

### Rust Side: lib.rs

```rust
// Line 1712-1723
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_recompute_semantic_neighbors(
    engine: *mut Engine,
    k: u32,
    threshold: f32,
) {
    ffi_catch_unwind!("graph_engine_recompute_semantic_neighbors", {
        ffi_engine!(engine);
        engine.semantic_neighbors = engine.embedding_store.all_knn_pairs(k as usize, threshold);
        engine.reheat();
    });
}
```

---

## 2. Root Cause Analysis

### Issue: Race Condition Between Swift and Rust

**The Problem:**
1. Swift captures `engineHandle` from `graphState?.engineHandle` on MainActor
2. Task is detached and continues on background thread
3. Between the MainActor capture and the FFI call, the engine can be destroyed:
   - User closes graph overlay
   - App goes to background
   - Graph rebuild triggers engine teardown
4. Swift calls `graph_engine_recompute_semantic_neighbors` with dangling pointer

**Why This Happens:**
- `engineHandleState` in `GraphState` uses a lock but doesn't prevent the engine from being destroyed
- The `EngineHandleState` only protects against concurrent access, not lifetime
- `MetalGraphNSView.deinit` calls `graph_engine_destroy` which frees the Engine
- No reference counting or explicit lifetime management between Swift and Rust

---

## 3. Ownership Audit

### Who Allocates What

| Resource | Allocator | Owner | Deallocator |
|----------|-----------|-------|-------------|
| `Engine` (Rust) | `Box::new` in `graph_engine_create` | Rust | `drop(Box::from_raw)` in `graph_engine_destroy` |
| `embedding_store` (Rust) | `EmbeddingStore::new` | Rust (Engine member) | Dropped with Engine |
| `embeddings` dict (Rust) | `FxHashMap::default` | Rust | Dropped with EmbeddingStore |
| `vector` in EmbeddingEntry | `Vec::to_vec` | Rust | Dropped with EmbeddingEntry |
| `EngineHandle` pointer (Swift) | `graph_engine_create` return | Swift (opaque) | Passed to `graph_engine_destroy` |
| `SendableEngineHandle` (Swift) | Swift struct wrapping pointer | Swift (task-local) | Dropped at task end |

### The Ownership Gap

**Problem:** Swift holds a raw pointer (`OpaquePointer`) to the Rust Engine. There's no way for Swift to know if the Engine has been destroyed.

**Current State:**
- Swift: `graphState?.engineHandle` → `OpaquePointer?`
- Rust: `engine: *mut Engine` → dereferenced without lifetime check

**The Gap:** No explicit "is this pointer still valid" check between capture and use.

---

## 4. The Fix

### Strategy: Defensive Programming + Explicit Lifetime

**Option A: Add Engine Version/Liveness Token (Recommended)**
- Add an atomic generation counter to the Engine
- Swift captures (pointer, generation) pair
- Before FFI call, verify generation matches

**Option B: Wrap Engine in Arc<RwLock<>>**
- Requires significant Rust refactor
- May impact performance

**Option C: Add explicit "is_valid" FFI call**
- Swift calls `graph_engine_is_valid(engine)` before use
- Race condition still possible between check and use

### Selected Fix: Option A + Cancellation Coordination

1. **Add Engine Generation Token:**
   - Atomic u64 in Engine
   - Incremented on creation, set to 0 on destruction
   - Swift captures (ptr, gen) and validates before FFI

2. **Add Cancellation Guard in Swift:**
   - Check `Task.isCancelled` immediately before FFI
   - Check engineHandle hasn't changed since capture
   - Use shorter critical section

3. **Add Null Check in Rust:**
   - Extra safety: verify pointer is not null in all FFI functions
   - Already present via `ffi_engine!` macro

---

## 5. Implementation

### Rust Changes (graph-engine/src/lib.rs)

```rust
// Add to Engine struct (engine.rs)
pub struct Engine {
    // ... existing fields ...
    pub generation: std::sync::atomic::AtomicU64,
}

// New FFI function
#[unsafe(no_mangle)]
pub extern "C" fn graph_engine_generation(engine: *mut Engine) -> u64 {
    ffi_catch_unwind_or!("graph_engine_generation", 0, {
        if engine.is_null() { return 0; }
        let engine = unsafe { &*engine };
        engine.generation.load(std::sync::atomic::Ordering::SeqCst)
    })
}
```

### Swift Changes (EmbeddingService.swift)

```swift
// Capture both pointer and generation
let engineCapture: (ptr: OpaquePointer, gen: UInt64)? = await MainActor.run { [weak self] in
    guard let self, !Task.isCancelled else { return nil }
    guard let engine = self.graphState?.engineHandle else { return nil }
    let gen = graph_engine_generation(engine)
    return (engine, gen)
}

// Validate before use
guard !Task.isCancelled,
      let engineCapture,
      graph_engine_generation(engineCapture.ptr) == engineCapture.gen else {
    return
}

graph_engine_recompute_semantic_neighbors(engineCapture.ptr, 8, 0.3)
```

---

## 6. Additional Safety Measures

### For This Specific Crash:
1. Shorter window between engine capture and FFI call
2. Generation token validation
3. Task cancellation check immediately before FFI

### For General FFI Safety:
1. All FFI calls should have nil/null checks (✓ already present)
2. Consider adding `ptr::eq` checks for pointer stability
3. Document ownership contract in header file
4. Add sanitizer builds to CI

---

## 7. Verification

### Test Scenarios:
1. **Rapid open/close graph overlay** while embeddings compute
2. **Background the app** during embedding computation
3. **Switch workspaces** during embedding computation
4. **Stress test:** 100 rapid graph rebuilds

### Expected Result:
- No allocator aborts
- Graceful cancellation when engine is destroyed
- No memory leaks (check with Instruments)

---

## 8. Follow-up

- [ ] Implement generation token in Rust
- [ ] Update Swift EmbeddingService with validation
- [ ] Add stress tests
- [ ] Document ownership contract
- [ ] Consider adding TSan/ASan CI builds
