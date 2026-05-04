# Codex Handoff: Full Audit + Remaining Work

> **Index status**: CANONICAL-OPERATIONAL — 2026-04-01 status reconciliation: continuation leak fixes + harness lifecycle; defers to MASTER_HARDENING_AND_HARNESS_PLAN.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



**Date:** 2026-04-01
**From:** Claude Opus session (concurrency fixes, PowerGuard, signing, auto-setup)
**To:** Codex agent for comprehensive audit and continuation

---

## STATUS RECONCILIATION — 2026-04-01 FOLLOW-UP

This handoff captured real issues at the time, but several of its "next priority" items were closed in a later follow-up pass and should no longer be treated as open:

- `EmbeddingService` already offloads the embedding push-to-Rust work off the main actor
- `ResearchPause.swift` already matches `ConfirmationGate`'s timeout/cancellation safety pattern
- `AgentViewModel` now completes the missing harness lifecycle hooks: session prep happens before intent recording, final model output is traced, completion verification runs at session end, and live `available_tools` metadata feeds the harness
- `VaultSyncService` now restarts and cancels maintenance timers as `PowerGuard` transitions between `.full` and background-disabled modes
- `DualBrainRouter` now requires a dedicated ANE backend before reporting dual-brain active, so shared-GPU fallback no longer masquerades as ANE-backed routing
- Verified on 2026-04-01 with `build-for-testing` + `test-without-building`: `RuntimeValidationTests`, `VaultSyncServiceAuditTests`, and `DeviceAgentServiceTests` ran 140 tests across 3 suites and passed
- Verified again on 2026-04-01 with the broader automated sweep: hosted Swift `test-without-building` passed 3051 tests across 418 suites; `graph-engine` passed 2448 tests; `agent_core` passed 141 tests after serializing process-global shared-memory tests; `omega-mcp` passed 125 tests; `omega-ax` passed 12 tests; cached `xcodebuild ... build` also succeeded
- `_NSDetectedLayoutRecursion` remains only a historical breadcrumb until it is reproduced live; current production grep no longer shows `layoutSubtreeIfNeeded` call sites

Use `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md` and `docs/AGENT_PROGRESS.md` as the source of truth for what is still actually left.

## WHAT WAS DONE THIS SESSION (Commit `ed2b8b99`)

### 1. Continuation Leak Fixes (3 files)

**ConfirmationGate.swift** — added `withTaskCancellationHandler`, 120s timeout, stale continuation cleanup:
```swift
// Before: continuation leaked if UI dismissed without approve/deny
return await withTaskCancellationHandler {
    await withCheckedContinuation { continuation in
        pendingContinuation = continuation
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: self?.confirmationTimeout ?? .seconds(120))
            guard let self, self.pendingContinuation != nil else { return }
            self.deny()
        }
    }
} onCancel: {
    Task { @MainActor [weak self] in self?.deny() }
}
```

**HermesMCPClient.swift** — timeout now resumes continuation with error:
```swift
// Before: removePending silently discarded continuation on timeout
private nonisolated func removePending(id: Int, resumingWith error: (any Error)? = nil) {
    lock.lock()
    let continuation = pendingRequests.removeValue(forKey: id)
    lock.unlock()
    if let continuation, let error {
        continuation.resume(throwing: error)
    }
}
```
Also: default timeout 30s→10s, listTools timeout 30s→5s.

**ThermalGuard.swift** — added `withTaskCancellationHandler` for parked callers + `cancelParkedCaller(id:)`.

### 2. Code Signing Fixes (4 shell scripts)

**embed-and-sign-rust-dylib.sh** — strips old sig, passes `--entitlements`, adds `--options runtime`.

**build-omega-mcp.sh / build-omega-ax.sh / build-epistemos-core.sh** — stopped ad-hoc re-signing when inside Xcode (was overwriting real signature with ad-hoc, causing cdhash mismatch).

### 3. ScreenCaptureService Fixes

- Added `recoverStream()` — tears down stream, kicks replayd via launchctl, re-establishes capture
- Reuse single `CIContext` across frames (was allocating per-frame ~2ms each)

### 4. Metal Shader Cache Fix

AppBootstrap shader warmup now acquires exclusive file lock before `graph_engine_create` to prevent flock errno 35 contention.

### 5. Ring Buffer Backpressure

KnowledgeCoreBridge polling loop: when full batch drained, skips sleep and burst-drains up to 8 consecutive batches.

### 6. Auto-Setup Flow

- Added OpenRouter + all cloud provider keys to Keychain→env mappings in HermesSubprocessManager
- Detect auth failures (401, missing API key) from Hermes stderr → sets `authFailureMessage`
- Inline setup banner on landing page that opens Settings directly

### 7. PowerGuard (3-tier low-power mode)

**New file: `Epistemos/State/PowerGuard.swift`**

```swift
enum PowerMode: Int, Comparable, Sendable, CaseIterable {
    case full = 0      // everything on
    case eco = 1       // manual toggle — disables background subsystems
    case lowPower = 2  // system LPM — eco + 60fps cap + render throttle
}
```

Integrated into 10 subsystems:
- MetalGraphView: 60fps cap (frame skip), calmer physics (halved charge, 2x velocity decay)
- KnowledgeCoreBridge: 100ms polling in lowPower vs 16ms
- VaultSyncService: version capture + manifest refresh timers skipped
- NightBrainService: canStart() blocked
- AgentHeartbeatService: canStart() blocked
- ScreenCaptureService: startStream() blocked
- HermesSubprocessManager: preWarm() skipped
- MLXInferenceService: eco toggle feeds into LocalRuntimeConditions
- AppSupervisor: health check interval 30s/120s/stopped
- MainThreadWatchdog: install gated on power mode

### 8. UI Fixes

- Landing toolbar: ControlGroup for native grouped pill
- Note toolbar ask bar: vertical padding 2→3pt
- Removed unnecessary `nonisolated(unsafe)` from 4 Logger constants
- Fixed VaultSyncService unused `[weak self]` capture
- Fixed MLXInferenceService `@MainActor` default value issue in nonisolated context

---

## RUNTIME LOG ANALYSIS

From the logs provided:

### Working Correctly
- PowerGuard: transitions Full → Eco → Low Power correctly on user toggle + system LPM
- ThermalGuard: started, nominal state
- Hermes: launched pid=53429
- Vault: 800 files imported, 869 entries
- InstantRecall: 832 notes indexed in 1090ms
- Graph: 1148 nodes, 872 edges
- NightBrain + AgentHeartbeat: registered (heartbeat disabled in config)
- EmbeddingService: pushed 1017 embeddings

### Issues to Investigate

1. **Main thread hangs persist**: 932ms, 2354ms, 1358ms, 3738ms, 2772ms, 1739ms, 739ms
   - The 3738ms hang happens during EmbeddingService push — `pushed 1017 embeddings (dim=300) to Rust`
   - This FFI call may be blocking main thread. Should be offloaded to background actor.

2. **Layout recursion**: `_NSDetectedLayoutRecursion` — still present. Likely an NSHostingView calling `layoutSubtreeIfNeeded` during its own layout pass. Needs `Break on void _NSDetectedLayoutRecursion(void)` to identify the exact view.

3. **`/private/var/db/DetachedSignatures` open failure**: benign on most systems but indicates AMFI is attempting signature verification. The signing fixes should help but verify after clean build.

4. **Memory pressure warning**: `level: warning` logged during embedding push. The 1017-embedding push is likely the trigger.

5. **`Unable to obtain a task name port right for pid 402`**: System-level, likely replayd or another daemon. Not actionable.

6. **ANE: false despite hardware tier ANE: true**: `Device agent backend set: SharedGPU, ANE: false`. Low Power Mode may be disabling ANE. PowerGuard should communicate this to the inference router.

---

## AUDIT CHECKLIST FOR CODEX

### A. Verify All Continuation Paths

Grep for all `withCheckedContinuation` and `withCheckedThrowingContinuation` usage. For each:
- [ ] Every code path resumes the continuation exactly once
- [ ] `withTaskCancellationHandler` wraps any stored continuation
- [ ] No continuation is stored without a timeout or cancellation safety net

Known safe: SearchIndexService (has OffloadedSearchState guard), process termination handlers.
Known fixed this session: ConfirmationGate, HermesMCPClient, ThermalGuard.
**Check ResearchPause.swift** — same pattern as ConfirmationGate, may still be unfixed.

### B. Verify PowerGuard Integration Completeness

- [ ] MetalGraphView: frame skip actually caps to 60fps on ProMotion
- [ ] Physics dampening: verify chargeScale/rangeScale/decay values feel natural
- [ ] Ring buffer polling: verify `await PowerGuard.shared.ringPollInterval` doesn't cause actor hop overhead in tight loop
- [ ] VaultSyncService: timers restart when power mode returns to .full (currently they DON'T — only gated at startWatching time)
- [ ] NightBrain/Heartbeat: verify they re-check on next scheduler invocation (they do — guard is in canStart())
- [ ] Settings UI: verify toggle persists and PowerGuard picks it up on next launch

### C. Verify Code Signing Chain

Build the app with Xcode, then:
```bash
codesign --verify --deep --strict --verbose=4 build/Epistemos.app
# Check each dylib individually:
codesign -dvv build/Epistemos.app/Contents/Frameworks/libomega_mcp.dylib
codesign -dvv build/Epistemos.app/Contents/Frameworks/libomega_ax.dylib
codesign -dvv build/Epistemos.app/Contents/Frameworks/libepistemos_core.dylib
```
- [ ] No cdhash mismatch warnings in Console.app
- [ ] TCC permissions survive app relaunch
- [ ] ScreenCaptureKit works after clean build

### D. Verify MCP Timeout Behavior

- [ ] `listTools()` times out in 5s (not 30s)
- [ ] Default MCP timeout is 10s
- [ ] When Hermes isn't running, MCP calls fail immediately (not after timeout)
- [ ] `cancelAll()` on disconnect resumes all pending continuations with error

### E. Main Thread Hang Investigation

The 3738ms hang during embedding push needs investigation:
```swift
// EmbeddingService: pushed 1017 embeddings (dim=300) to Rust
```
- [ ] Find where EmbeddingService calls Rust FFI
- [ ] Verify it's not on @MainActor
- [ ] If it is, move to Task.detached or a background actor
- [ ] The 932ms hang at startup may be from graph commit or shader warmup — profile with Instruments

### F. Layout Recursion

- [ ] Set breakpoint on `_NSDetectedLayoutRecursion`
- [ ] Identify which NSHostingView triggers it
- [ ] Likely fix: defer layout update with `DispatchQueue.main.async` or use `needsLayout = true` instead of `layoutSubtreeIfNeeded`

### G. Architectural Audit (from arc1-arc7 research)

The research documents identify these remaining structural gaps:

1. **Rust FFI panic strategy**: `agent_core` should use `panic = "unwind"` in release. Verify with:
   ```bash
   grep 'panic' agent_core/Cargo.toml
   ```
   The `ffi_guard_sync!` / `ffi_guard_value!` macros should exist on ALL `#[uniffi::export]` functions.

2. **Circuit breaker rolling window**: `TimeoutUtility.swift` should use UInt64 bit ring buffer (Phase 4 complete). Verify sticky counter bug is fixed.

3. **Apple Intelligence token budget**: `AppleIntelligenceService.swift` should have 78% threshold guard and `contextWindowExceeded` catch-retry.

4. **ModeMachine causal chain**: `DegradationReason` enum should carry thermal, breaker, context reasons. Verify `forceDegrade` exists.

5. **AppSupervisor**: Should be event-driven with ChildSpec, sliding-window restart intensity, exponential backoff with jitter, rest_for_one escalation.

### H. Meta-Harness Production Runtime (Phase 6)

Per `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md`:

- [ ] Phase 6E: Initializer vs continuation prompt split — verify `HarnessPromptBuilder.swift`
- [ ] Phase 6F: Wire BootstrapPacket + TraceCollector + ProgressStore + CompletionChecker into AgentViewModel — **this is the next priority item**

### I. Test Suite

Run the full test suite and verify zero regressions:
```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify
cargo test --manifest-path agent_core/Cargo.toml
```

The `RuntimeValidationTests.swift` test was updated to expect the new patterns. Verify it passes.

---

## FILES CHANGED THIS SESSION

| File | Change |
|------|--------|
| `Epistemos/State/PowerGuard.swift` | **NEW** — 3-tier power mode |
| `Epistemos/State/ThermalGuard.swift` | Cancellation handler for parked callers |
| `Epistemos/State/EpistemosConfig.swift` | Eco mode toggle |
| `Epistemos/State/AppSupervisor.swift` | Dynamic health check interval |
| `Epistemos/State/InferenceState.swift` | Eco toggle in LocalRuntimeConditions |
| `Epistemos/State/NightBrainService.swift` | PowerGuard gate |
| `Epistemos/State/AgentHeartbeatService.swift` | PowerGuard gate |
| `Epistemos/Agent/HermesMCPClient.swift` | Timeout fix, default 10s |
| `Epistemos/Agent/HermesSubprocessManager.swift` | Auth detection, keychain mappings |
| `Epistemos/App/AppBootstrap.swift` | PowerGuard init, shader lock, Hermes gate |
| `Epistemos/App/RootView.swift` | ControlGroup toolbar |
| `Epistemos/Engine/KnowledgeCoreBridge.swift` | Backpressure + power polling |
| `Epistemos/Omega/Orchestrator/ConfirmationGate.swift` | Continuation leak fix |
| `Epistemos/Omega/Vision/ScreenCaptureService.swift` | Recovery, CIContext, power gate |
| `Epistemos/Sync/VaultSyncService.swift` | Timer gating, unused capture fix |
| `Epistemos/Views/Graph/MetalGraphView.swift` | 60fps cap, calmer physics |
| `Epistemos/Views/Landing/LandingView.swift` | Auth banner |
| `Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` | Padding fix |
| `Epistemos/Views/Settings/SettingsView.swift` | Power section |
| `Epistemos/Bridge/ChunkedMCPFraming.swift` | Remove nonisolated(unsafe) |
| `Epistemos/Bridge/CoTStreamInterceptor.swift` | Remove nonisolated(unsafe) |
| `Epistemos/State/OrphanSubprocessCleanup.swift` | Remove nonisolated(unsafe) |
| `Epistemos/State/PaperclipStateStore.swift` | Remove nonisolated(unsafe) |
| `embed-and-sign-rust-dylib.sh` | Entitlements, strip, runtime |
| `build-omega-mcp.sh` | Conditional ad-hoc signing |
| `build-omega-ax.sh` | Conditional ad-hoc signing |
| `build-epistemos-core.sh` | Conditional ad-hoc signing |
| `EpistemosTests/RuntimeValidationTests.swift` | Updated for new patterns |

---

## PRIORITY ORDER FOR NEXT WORK

1. **Do not restart the historical EmbeddingService / Phase 6F / ResearchPause / Vault timer / ANE items above** — those are now closed
2. **Only reopen layout recursion if `_NSDetectedLayoutRecursion` still reproduces with a live breakpoint**
3. **Otherwise continue from `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md` and `docs/AGENT_PROGRESS.md`**
4. **Cloud Knowledge Distillation remains spec-only if a true net-new roadmap item is needed**

---

## RESEARCH FOUNDATION — COMPREHENSIVE CONTEXT

The following consolidates ALL research documents provided by the user. Codex must understand these to make architecturally coherent decisions.

### The Seven Architectural Audit Areas (arc1-arc7)

These audits examined the codebase against canonical distributed systems patterns. Status after this session's work:

| Area | Research Rating | Current Status | Key Files |
|------|----------------|----------------|-----------|
| 1. OTP Supervision | Simplified → **Fixed (Phase 2)** | ChildSpec, sliding-window, backoff+jitter, rest_for_one | `AppSupervisor.swift` |
| 2. Degradation FSM | Simplified → **Fixed (Phase 3)** | ModeMachine with DegradationReason, hysteresis, forceDegrade | `AppSupervisor.swift` |
| 3. Circuit Breaker | Compromised → **Fixed (Phase 4)** | UInt64 bit ring, execute<T>(), 5 domain breakers, CircuitBreakerIgnorable | `TimeoutUtility.swift` |
| 4. Rust FFI Safety | Compromised → **Fixed (Phase 1)** | panic="unwind", ffi_guard_sync!/ffi_guard_value! macros, async JoinHandle | `agent_core/src/bridge.rs` |
| 5. Foundation Models | Near-Canonical → **Fixed (Phase 5)** | Token budget 78%, contextWindowExceeded catch-retry, breaker.execute<T>() | `AppleIntelligenceService.swift` |
| 6. ThermalGuard | Missing → **Fixed (Phase 3)** | Centralized actor, CheckedContinuation parking, 15s recovery hysteresis | `ThermalGuard.swift` |
| 7. Cross-Cutting | Critical → **Partially Fixed** | Thermal pauses exempt from breaker, supervisor wired to mode machine | Multiple files |

**Remaining cross-cutting risks (from arc2, arc4):**
- **Thermal→Breaker false positive**: ThermalGuard parks task → timeout fires → breaker counts as failure. Fixed via `CircuitBreakerIgnorable` protocol — thermal errors classified as neutral. **Verify this actually works end-to-end.**
- **Session recycle during active inference**: 10-min timer can fire while `session.respond(to:)` is in-flight. Current fix: timer checks but doesn't coordinate with in-flight count. **Still a gap.**
- **Process abort kills supervisor**: If Rust double-panics, the entire process dies and AppSupervisor is dead too. **Deferred — needs out-of-process watchdog (launchd KeepAlive or XPC service).**
- **Orphaned Hermes subprocess**: OrphanSubprocessCleanup exists but isn't wired into supervisor crash loop escalation. **Still a gap.**
- **UniFFI + Swift 6.2 deinit isolation**: UniFFI generates wrappers without explicit isolation. SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor forces synchronous C-interop in generated deinit onto UI thread. **Mitigated by patch-uniffi-bindings.py script but verify it runs for all three crates.**

### The Five Engines (from Master Session Prompt)

These are the core research-backed subsystems. Each maps to specific research papers:

**Engine 1: ECS Graph (Rust + Metal)**
- SVG collapses at ~400 nodes. Metal: 400,000 at 50 FPS.
- SoA layout: 5.7-10x speedup. Pipeline: SoA → MTLBuffer storageModeShared → zero-copy GPU physics → Metal rendering.
- Current: `MetalGraphView.swift` + `graph-engine/src/renderer.rs` + `graph-engine/src/simulation.rs`
- PowerGuard integration: 60fps cap + calmer physics in lowPower mode (done this session)

**Engine 2: Zero-Copy IPC (POSIX SHM)**
- Shared memory: ~5M msg/sec vs ~130K UDS = 36x throughput, 1.4us latency.
- Apple Silicon 128-byte cache lines — pad metadata to 128B.
- Current: `ChunkedMCPFraming.swift` + `ShmWriter` + Rust `shared_memory.rs`
- The ring buffer in `graph-engine/src/knowledge_core/ring.rs` uses 128B cache-line padding (verified)

**Engine 3: TurboQuant+ K8V4**
- Walsh-Hadamard → Asymmetric K8V4 (8-bit Keys, 4-bit Values).
- half4 vectorized butterfly on Metal. 4.6x compression, 99.1% perplexity retention.
- Current: `epistemos-core/src/instant_recall/` — Binary HNSW, quantization, segment MVCC
- Research papers: ButterflyQuant, SpinQuant, FlatQuant, TurboQuant, PM-KVQ, KVTuner, ThinKV, Kitty

**Engine 4: NightBrain (Temporal Memory Distillation)**
- CLS theory replay. Ebbinghaus R = e^(-t/S). FSRS scheduling.
- Distillation: 371→38 tokens (11x), 96% retrieval quality.
- Current: `NightBrainService.swift` — NSBackgroundActivityScheduler, idle/AC/thermal checks
- PowerGuard integration: blocked in eco/lowPower mode (done this session)

**Engine 5: Token Savior (AST Intelligence)**
- tree-sitter + PageRank → 1,024 tokens for entire repo (~97% reduction).
- MCP tools: find_symbol, get_function_source, get_change_impact.
- Current: Referenced in research but implementation deferred.

### Meta-Harness Integration (from harn2, harn3)

The Meta-Harness research (Stanford, 2026) shows that providing a proposer model with uncompressed diagnostic history (up to 10M tokens of raw logs) enables 10x optimization efficiency over text optimizers. Key architectural decisions:

**Tripartite Architecture:**
1. **Production Runtime** (immutable, user-facing) — consumes harness artifacts, generates traces
2. **Harness Lab** (developer-only, offline) — analyzes traces, proposes harness edits
3. **Promotion Pipeline** (human-in-the-loop) — review gate, no auto-promote

**Phase 6 (Production Runtime) status:**
- 6A BootstrapPacketBuilder ✅ — 800-1200 token env snapshot
- 6B TraceCollector ✅ — JSONL trace logging, 13 event types
- 6C ProgressStore ✅ — session handoff, task decomposition
- 6D CompletionChecker ✅ — coding/research/terminal/note verification
- 6E HarnessPromptBuilder ✅ — initializer vs continuation 2-prompt split
- **6F AgentViewModel wiring ❌ — THIS IS THE IMMEDIATE NEXT STEP**

**Phase 7 (Harness Lab) status:**
- 7A HarnessRegistry ✅ — versioned storage, promotion pipeline scaffold
- 7B TaskSuite ❌ — search set + held-out test set
- 7C TraceStore ❌ — SQLite index over JSONL traces
- 7D EvaluationRunner ❌ — isolated candidate execution
- 7E ProposerOrchestrator ❌ — deferred (needs trace corpus)
- 7F PromotionPipeline ❌ — diff, scorecard, regression report
- 7G TraceMaterialization ❌ — DB to filesystem for proposer grep/cat

**Key Meta-Harness discoveries to port (from harn2):**
- **Environment Bootstrap Packet**: inject OS version, thermal state, file tree, tool manifest, git state into first turn. Eliminates 2-5 exploratory turns.
- **Multi-Perspective Completion Checklist**: force agent to evaluate from Test Engineer, QA Engineer, and End User perspectives before allowing task_complete.
- **Experience Grounding**: every proposed harness change must cite evidence from a prior trace.

### Stateful Rotor Engine (from stateful-rotor-implementation-reference.md)

The vector database is a living mathematical structure:

**Quantization Pipeline:**
1. Ingestion (<1ms): TurboQuant fallback (random rotation → Beta distribution → Lloyd-Max quantizer)
2. Correlation check: CEV heuristic → if high correlation → ButterflyQuant learned rotation
3. Two-stage: learned rotation + MSE-optimal scalar quantization + QJL residual
4. Progressive downgrade: PM-KVQ right-shift 16→8→4→2 bit

**Concurrency Model:**
- crossbeam-epoch for lock-free rotation swaps
- Segment MVCC: sealed (immutable) + growing (mutable) segments
- Read-temperature scheduling: hot-first re-encoding (Ada-IVF pattern)
- Yield-aware background tasks: `tokio::task::yield_now()` after each chunk

**Mixed-Precision SIMD (Kitty Two-Tensor Decomposition):**
- Decompose mixed-precision vectors into two UNIFORM tensors
- Each tensor dispatches its own dequantization kernel — no branching, no divergence
- Slab-based memory layout: 8-bit (anchors) → 4-bit (active) → 2-bit (peripheral) → growing

**Performance Targets:**
| Operation | Target |
|-----------|--------|
| Single vector search (1M) | <5ms |
| Vector ingestion | <1ms |
| Rotation matrix swap | <1us |
| Background rotation (1K) | <100ms |
| Full re-encoding (1M) | <60s |

**Apple Silicon Notes (from Benazir & Lin profiling):**
- Crossover: dequantization overhead > bandwidth savings at batch_size ~32
- Strategy: prefer FP16/Q8 for prefill (batch), Q4/Q2 for decode (single query)
- Minimize dequantization heterogeneity: use only 2-bit and 4-bit
- AMX: 2 units on M2 Pro, 32x32 grids, via Accelerate BLAS
- MTLResourceOptions::StorageModeShared for zero-copy UMA buffers

### Typestate and Zero-Allocation Patterns (from arc7, deferred)

**Phase 11 — Typestate Islands (deferred until foundations stable):**
- PTY handle (`Opened`/`Closed`) — Rust typestate, consuming close(), Drop auto-close
- FoundationModels session (`Active`/`Recycling`/`Closed`) — Swift phantom-type wrapper
- AppBootstrap phases (`Booting`/`Ready`) — Swift phantom wrapper
- AgentCapability tokens (`Cloud`/`Local`/`ReadOnly`) — minted by ModeMachine
- Hermes subprocess lifecycle — typestate prevents IPC with terminated process
- VaultStore handle (`Open`/`Active`/`Closed`) — Rust typestate

**Phase 12 — Rust AtomicU64 Hot-Path Breakers (deferred):**
- Rust AtomicU64 bit-packed rolling fuse for MLX/FFI breakers
- `#[repr(align(128))]` padding for Apple Silicon 128-byte L1 cache lines
- Only justified if profiling shows actor breaker overhead matters (<500 req/sec, unlikely)

**Phase 13 — Arc::into_raw FFI Migration (deferred):**
- Replace UniFFI HandleMap with `Arc::into_raw()` for hottest boundaries
- Swift `~Copyable` wrappers with explicit `deinit` calling Rust destructor
- Current assessment: NOT a bottleneck. UniFFI HandleMap is correct and sufficient.

### Search Architecture (Five Signals + RRF)

Pipeline must include ALL five stages:
1. **tantivy FTS** — BM25, ~2x Lucene, sub-ms, NEON-accelerated
2. **Vector search** — <4ms at 100K/384d quantized (nomic-embed-text v1.5, Matryoshka 768→384)
3. **Knowledge graph** — NER → SQLite → recursive CTE traversal. GraphRAG: 72-83% comprehensiveness
4. **Cross-encoder reranking** — ms-marco-MiniLM-L-6-v2 (22MB), top-50 → top-10
5. **RRF fusion** — `score(d) = Σ 1/(60 + rank_r(d))`, weighted 0.5 FTS / 0.5 vector. **<50ms total.**

**Contextual Retrieval (index-time):** At index time, call local 4B router with full document context → generate 50-100 token situating prefix → prepend before embedding. Reduces retrieval failures by 67%.

### Local Inference Architecture

- **MLX > llama.cpp by 20-30%.** M2 Pro: Qwen 8B Q4 = 45-58 tok/s.
- **Router:** Qwen 3 4B (3GB, pinned). Outputs intent + reasoning_depth (NOT target_model). mlx-swift-structured for constrained JSON.
- **Embedding:** nomic-embed-text v1.5 (0.3GB, 768→384 Matryoshka).
- **Reasoner:** DeepSeek-R1-8B (5-6GB, cold-loaded, TTL eviction).
- **Rule:** RAG > long context on 16GB. Top-12 chunks in 2-4K context.
- **Rule:** Speculative decoding NOT recommended at this scale.

### Agent System: The "Dumb Chatbot" Root Cause

From MASTER_SESSION_PROMPT_v2.md — this is the HIGHEST PRIORITY item after stability:

The hermes-agent loop works correctly. **Tools don't load.** Every tool has a `check_fn` gate in `hermes-agent/tools/registry.py:123-131`. When `check_fn()` returns False, the tool is silently dropped. The model receives zero tools → produces plain text → loop exits after 1 turn.

**Fix priority:**
1. Add debug logging to `tools/registry.py` when check_fn fails
2. Set `HERMES_ENV_TYPE=local` in subprocess environment (already partially done — verify `TERMINAL_ENV=local` is set)
3. Pass TAVILY_API_KEY or EXA_API_KEY from Keychain (added this session to toolGateKeychainMappings)
4. Ensure `~/.hermes/` directory exists (already done in HermesConfig.resolve())
5. Verify: print tool list to stderr after agent creation

### Distribution Strategy

- **Method:** Developer ID-signed DMG (NOT Mac App Store)
- **Why:** 6 hardened runtime exceptions required (JIT, unsigned memory, dylib loading, AX access, Apple Events, terminal execution)
- **Stack:** Lemon Squeezy payments + Sparkle 2 updates + DMG format
- **Target:** PhD researchers + ML/AI engineers first
- **Price:** Free tier → $79/yr Pro → $199 Lifetime → $39/yr Education

### Key Mathematical Formulations

- **ButterflyQuant:** O(d log d) rotation, (d log d)/2 learnable Givens angles
- **PM-KVQ Right Shift:** `floor((2^{2b} - 2^b + 1)(X_{2b} + 2^{b-1})) >> 3b`
- **RRF:** `score(d) = Σ 1/(60 + rank_r(d))`
- **Ebbinghaus:** `R = e^(-t/S)`, S increments on recall
- **MMR Estimator:** `<y, x̃> = <y, Q⁻¹(Q(x))> + ||r||₂ · <y, QJL(r)>`
- **SpinQuant Cayley SGD:** `R(t+1) = R(t) · exp(η · A)`, A skew-symmetric
- **Meta-Harness Objective:** `J(h) = E_τ~D[R(τ_h)]` balanced against context cost `C(h)`

### Memory Budget (M2 Pro, 16GB)

| Component | Size | Policy |
|-----------|------|--------|
| macOS + App UI | ~4GB | Always |
| Qwen 3 4B Router (4-bit, MLX-Swift) | ~3GB | Pinned hot |
| nomic-embed-text v1.5 (ONNX) | ~0.3GB | Resident |
| KV cache | ~2-3GB | Rotating 4K window |
| DeepSeek-R1-8B Reasoner | ~5-6GB | Cold-loaded, TTL eviction |
| Vector index (1M, 4-bit avg) | ~64MB | Stateful Rotor |
| Meta-memory index (1M, 2-bit) | ~32MB | MMR predictive |

### NON-NEGOTIABLE CONSTRAINTS (from CLAUDE.md)

- NO SIDECAR for inference — all in-process via Rust FFI or MLX-Swift
- REAL APIs ONLY — every cloud endpoint verified against provider docs
- HONEST CAPABILITY GATING — local models get fast/thinking/research, cloud models get agent/liveAgent
- Zero test regressions against the test suite
- PRESERVE THINKING BLOCKS — when stop_reason is "tool_use", pass ENTIRE content array including thinking blocks + signatures
- STREAM EVERYTHING — forward every token immediately, no buffering
- AGENT DECIDES TERMINATION — max_turns is safety rail, not schedule
- API keys in macOS Keychain (SecItemAdd/SecItemCopyMatching), NEVER UserDefaults
- @Observable not ObservableObject
- Swift Testing (@Test, #expect) for new tests
- All inference on background actors — never block @MainActor
- Every unsafe block gets `// SAFETY:` comment
- No try!, no force-unwraps, no print() in production
- DispatchQueue.main.async in UniFFI callbacks, NEVER .sync (deadlock)
- Do NOT edit .xcodeproj directly — use xcodegen

---

## COMPLETE PHASE STATUS (from MASTER_HARDENING_AND_HARNESS_PLAN.md)

```
LAYER 1: RUNTIME FOUNDATIONS (Phases 1-5)    ✅ COMPLETE
LAYER 2: META-HARNESS PRODUCTION (Phase 6)   🔄 6A-6E done, 6F TODO
LAYER 3: META-HARNESS LAB (Phase 7)          🟡 7A scaffolded, 7B-7G TODO
LAYER 4: ADVANCED OPTIMIZATION (Phases 8-10) ❌ DEFERRED
LAYER 5: TYPESTATE + ZERO-ALLOC (Phases 11-13) ❌ DEFERRED
```

### Architecture Decision Records

- ADR-1: Keep UniFFI HandleMap, harden it (no Arc::into_raw yet)
- ADR-2: Actor breakers for all domains, mark MLX/FFI for later zero-alloc
- ADR-3: Typestate deferred — actor lifecycles are correct
- ADR-4: ThermalGuard correct, enhanced with recovery hysteresis
- ADR-5: Meta-Harness as hybrid — production gets bootstrap/traces/progress/completion, Lab is dev-only
- ADR-6: Hybrid trace storage — JSONL files + SQLite index
- ADR-7: Human-in-the-loop promotion — no auto-promote ever

### Operational Documents (MUST READ)

These documents from the user's `~/arc/` directory contain session protocols, verification checklists, and implementation prompts that define HOW work should be done:

| Document | Location | Purpose |
|----------|----------|---------|
| `SESSION_BOOTSTRAP_PROMPT.md` | `~/arc/` | Paste into every new session. Lists all 15 files to read, what's complete, what to build next, Swift 6.2 gotchas, build commands. |
| `HARDENING_VERIFICATION.md` | `~/arc/` | 52-item grep-based verification checklist for all 8 hardening phases. Run after any hardening change. |
| `IMPLEMENTATION_PROMPTS.md` | `~/arc/` | 8 paste-ready implementation prompts (tool gates, auto-discovery, agent loop, skills, iMessage, NightBrain, stream composition, release prep). Work top-to-bottom. |
| `MASTER_SESSION_PROMPT_v2.md` | `~/arc/` | Full context restoration prompt. Architecture map, five engines, anti-drift rules, remaining work tiers. |
| `MASTER_HARDENING_AND_HARNESS_PLAN.md` | `~/arc/` and `docs/` | THE single source of truth. 13 phases, succession order, ADRs, what's done, what's next. |
| `VERIFICATION_PROTOCOL.md` | `~/arc/` | Detailed verification steps for each hardening phase with exact grep commands. |

**Session workflow from IMPLEMENTATION_PROMPTS.md:**
1. Always start with Prompt 0 (context restoration)
2. Pick the next numbered prompt based on what's not done
3. Research online before each phase
4. Read files before editing them
5. Verify after each task
6. Update `docs/AGENT_PROGRESS.md`
7. Commit when a prompt's tasks are complete

**Hardening verification protocol (from HARDENING_VERIFICATION.md):**
Run these after ANY hardening-related change:
```bash
# Phase 1: FFI Truth Boundary
grep 'panic = "unwind"' agent_core/Cargo.toml
grep 'ffi_guard_sync!' agent_core/src/bridge.rs
grep 'std::mem::forget(payload)' agent_core/src/bridge.rs

# Phase 2: Supervision
grep 'struct ChildSpec' Epistemos/State/AppSupervisor.swift
grep 'enum RestartPolicy' Epistemos/State/AppSupervisor.swift
grep 'restartWindow' Epistemos/State/AppSupervisor.swift
grep 'jitter' Epistemos/State/AppSupervisor.swift

# Phase 3: Mode Machine
grep 'enum DegradationReason' Epistemos/State/AppSupervisor.swift
grep 'class ModeMachine' Epistemos/State/AppSupervisor.swift
grep 'func forceDegrade' Epistemos/State/AppSupervisor.swift

# Phase 4: Circuit Breaker
grep 'ringBuffer' Epistemos/State/TimeoutUtility.swift
grep 'failureRate' Epistemos/State/TimeoutUtility.swift
grep 'requiredHalfOpenSuccesses' Epistemos/State/TimeoutUtility.swift

# Phase 5: ThermalGuard
grep 'actor ThermalGuard' Epistemos/State/ThermalGuard.swift
grep 'CheckedContinuation' Epistemos/State/ThermalGuard.swift
grep 'func acquireClearance' Epistemos/State/ThermalGuard.swift

# Phase 6: Token Budget
grep 'tokenCount' Epistemos/Engine/AppleIntelligenceService.swift
grep '0.78' Epistemos/Engine/AppleIntelligenceService.swift
grep 'exceededContextWindowSize' Epistemos/Engine/AppleIntelligenceService.swift

# Phase 7: Cross-Cutting
grep 'recordThermalPause' Epistemos/Engine/AppleIntelligenceService.swift
grep 'acquireClearance' Epistemos/Engine/AppleIntelligenceService.swift
grep 'EventStore.shared' Epistemos/State/AppSupervisor.swift
```

### Remaining Risks / Intentional Deferrals (from HARDENING_VERIFICATION.md)

1. **Per-domain breaker instances**: Only `inferenceCircuitBreaker` fully wired. Cloud and vault breakers need stress-testing.
2. **Typestate pattern**: Mode machine uses runtime validation, not compile-time. True noncopyable typestate deferred to Phase 11.
3. **Hierarchical supervisor tree**: Current supervisor is flat (one level). Nested supervisors with one_for_all deferred.
4. **Process-level watchdog**: No launchd/SMAppService restart on Rust process abort. Deferred to post-ship.
5. **Token budget for streaming tool calls**: Budget guard only works for single-turn. Multi-turn tool sessions need per-turn checks.
6. **Orphaned Hermes subprocess**: OrphanSubprocessCleanup exists but not wired into supervisor crash loop escalation.

### Build Commands

```bash
# Build
xcodebuild -scheme Epistemos -destination 'platform=macOS' build 2>&1 | xcbeautify

# Rust tests
cargo test --manifest-path agent_core/Cargo.toml

# Regenerate Xcode project after adding files
xcodegen generate

# Run hardening + harness tests only
xcodebuild -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests 2>&1 | grep "Test run with"
```
