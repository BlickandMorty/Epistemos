# Epistemos: Master Hardening + Meta-Harness Plan

**Last updated: 2026-04-01**
**Status: Active implementation in progress**

This document is the single source of truth for the hardening roadmap and Meta-Harness integration. Every deferred item, every completed phase, and the proper succession order is captured here. Come back to this document to know what to build next.

---

## SUCCESSION ORDER (Do Not Skip Ahead)

The phases below must be executed in order. Each phase builds on the prior one. Skipping creates fake safety or broken abstractions.

```
LAYER 1: RUNTIME FOUNDATIONS (Phases 1-5)    ← COMPLETE
LAYER 2: META-HARNESS PRODUCTION (Phase 6)   ← COMPLETE
LAYER 3: META-HARNESS LAB (Phase 7)          ← SCAFFOLDED, IN PROGRESS
LAYER 4: ADVANCED OPTIMIZATION (Phases 8-10) ← DEFERRED
LAYER 5: TYPESTATE + ZERO-ALLOC (Phases 11-13) ← DEFERRED
```

---

## PHASE 1: FFI TRUTH BOUNDARY ✅ COMPLETE

**What was built:**
- `agent_core` uses `panic = "unwind"` in release — `catch_unwind` is real
- `ffi_guard_sync!` / `ffi_guard_value!` macros on ALL `#[uniffi::export]` functions
- Async panic catching via `tokio::task::spawn` + `JoinHandle` on `run_agent_session`, `pty_spawn`, `pty_execute`
- `panic_payload_to_string()` with `std::mem::forget` to prevent re-panic from Drop

**Files changed:**
- `agent_core/src/bridge.rs` — 8 newly guarded exports added

---

## PHASE 2: MODE MACHINE + SUPERVISION ✅ COMPLETE (was already built)

**What exists:**
- `ModeMachine` actor with `DegradationReason`, hysteresis, step-by-step recovery
- `AppSupervisor` with OTP-style child management, sliding-window restart intensity, rest_for_one escalation
- `DegradationReason` expanded with: `.circuitBreakerOpen`, `.circuitBreakerRecovered`, `.thermalRecovery`, `.contextWindowExhausted`

**Files:**
- `Epistemos/State/AppSupervisor.swift`

---

## PHASE 3: CENTRAL THERMAL AUTHORITY ✅ COMPLETE (enhanced)

**What exists:**
- `ThermalGuard` actor with `CheckedContinuation` parking
- Recovery hysteresis: 15s cooldown before resuming parked callers
- `recoveryTask` with cooldown verification prevents flapping
- Worsening thermal state cancels pending recovery

**Files:**
- `Epistemos/State/ThermalGuard.swift`

---

## PHASE 4: PER-DOMAIN CIRCUIT BREAKERS ✅ COMPLETE

**What was built:**
- 5 independent breakers: cloud, foundationModels, mlx, hermes, vault
- `execute<T>()` canonical API — callers never touch `record*` directly
- UInt64 bit ring buffer with incremental cardinality (O(1) record/query)
- `CircuitBreakerIgnorable` protocol for neutral error classification
- Thermal errors, cancellation, context exhaustion classified as neutral
- `BreakerRegistry` singleton providing all domain breakers
- Mode machine notification on breaker state changes

**Files:**
- `Epistemos/State/TimeoutUtility.swift` — complete rewrite

---

## PHASE 5: FOUNDATIONMODELS + SESSION LIFECYCLE ✅ COMPLETE

**What exists:**
- `AppleIntelligenceService` uses `breaker.execute<T>()` pattern
- Token budget guard (78% threshold with proactive session recycle)
- Context exhaustion catch-and-retry
- Thermal clearance runs before breaker
- `AppleIntelligenceError` conforms to `CircuitBreakerIgnorable`

**Files:**
- `Epistemos/Engine/AppleIntelligenceService.swift`

---

## PHASE 6: META-HARNESS PRODUCTION RUNTIME ✅ COMPLETE

### 6A: BootstrapPacketBuilder ✅ COMPLETE

Assembles environment snapshot (800-1200 tokens) before agent's first turn:
- Working directory, file tree (depth 2, max 50 entries)
- Task type classification (coding/research/terminal/note_synthesis)
- Session number, progress summary from prior session
- Available tools, capability level, language runtimes, package managers
- Git state, vault context, thermal level, local model availability
- Harness version for trace correlation

**File:** `Epistemos/Harness/BootstrapPacketBuilder.swift`

### 6B: TraceCollector ✅ COMPLETE

Non-blocking JSONL trace logging:
- Fire-and-forget API via `nonisolated func record()`
- Per-session trace files organized by date
- 13 event types: bootstrap_packet, user_intent, model_output, tool_call, tool_result, completion_check, session_handoff, session_start, session_end, error, thermal_change, breaker_tripped, progress_update
- Manual JSON serialization (avoids Swift 6.2 MainActor Codable inference)

**File:** `Epistemos/Harness/TraceCollector.swift`

### 6C: ProgressStore + Session Handoff ✅ COMPLETE

Structured session continuity:
- `SessionProgress` — accomplished summary, completed/failed tasks, next priority, git state, changed files, token usage
- `TaskDecomposition` — JSON task list with status tracking, evidence requirements
- Save/load per session under `~/Library/Application Support/com.epistemos.app/sessions/`

**File:** `Epistemos/Harness/ProgressStore.swift`

### 6D: CompletionChecker ✅ COMPLETE

Evidence-based completion verification:
- `CodingCompletionChecker` — runs build + test for Swift/Cargo/Node projects
- `ResearchCompletionChecker` — checks output artifacts and completed tasks
- `TerminalCompletionChecker` — placeholder for task-specific verification
- `NoteSynthesisCompletionChecker` — checks vault output
- `CompletionCheckerRegistry` — returns appropriate checker per task type

**File:** `Epistemos/Harness/CompletionChecker.swift`

### 6E: Initializer vs Continuation Prompt Split ✅ COMPLETE

Two-prompt system: `HarnessPromptBuilder` selects initializer (session 1) vs continuation (session N>1) mode.
- `SessionMode.initializer`: task decomposition, verification instructions, task-type-specific guidance
- `SessionMode.continuation`: reads prior `SessionProgress`, shows task list, prevents re-doing completed work
- `buildSystemPrompt()` composes: base prompt + bootstrap packet + mode instructions

**File:** `Epistemos/Harness/HarnessPromptBuilder.swift`

### 6F: Wire Everything into AgentViewModel ✅ COMPLETE

Connected all harness pieces to the agent flow via `HarnessIntegration`:
- `AgentViewModel.harnessIntegration` property wired to lifecycle
- `prepareSession()` called in `send()` — builds bootstrap packet, injects augmented system prompt into Hermes payload
- `recordUserIntent()` fires on prompt submission
- `recordToolCall()` fires on `.toolCompleted` events in consume stream
- `recordError()` fires on `.error` events
- `completeSession()` fires on `.complete` — saves `SessionProgress`, records session end trace, closes file handles
- `resetForNewTask()` called on session surface reset

**Integration points in:** `Epistemos/ViewModels/AgentViewModel.swift`
**Coordinator:** `Epistemos/Harness/HarnessIntegration.swift`

---

## PHASE 7: HARNESS LAB (Developer-Only) 🟡 SCAFFOLDED

### 7A: HarnessRegistry ✅ COMPLETE

- Production harness storage with symlink-based "current" pointer
- Candidate harness creation with ancestry tracking
- Promotion pipeline with human review gate
- Versioned filesystem layout under Application Support

**File:** `Epistemos/Harness/HarnessRegistry.swift`

### 7B: TaskSuite ✅ COMPLETE

- JSON-based task definitions loaded from `search/` and `held_out/` directories
- Manual JSON deserialization (avoids Swift 6.2 MainActor Codable inference)
- `EvalVerification` enum with 5 types: commandExitZero, filesExist, outputPattern, llmJudge, humanReview
- Round-trip persistence: `addSearchTask()` / `addHeldOutTask()` write JSON, `load()` reads back
- `task(withId:)` cross-set lookup
- 4 tests passing: JSON loading, persistence round-trip, held-out separation, ID lookup
- 3 verification parsing tests passing: all types, defaults, round-trip

**File:** `Epistemos/Harness/HarnessLab.swift` (TaskSuite section)

### 7C: TraceStore (indexed) ✅ COMPLETE

- GRDB SQLite index over JSONL trace corpus
- Schema: sessionId, taskId, harnessVersion, eventType, timestamp, filePath, lineOffset, outcome, score, tokenCost, domain
- 5 indexes for fast query: session, task, version, type, timestamp
- `reindex()` scans date-organized directories and inserts events not yet indexed
- Query by session, task+outcome, harness version
- `diskUsageBytes()` and `isOverSoftLimit()` (5GB)
- `rotateOldTraces(olderThanDays:)` with cascading index cleanup
- File-based listing preserved for backward compatibility
- 4 tests passing: schema creation, indexing+query, disk usage, file listing

**File:** `Epistemos/Harness/HarnessLab.swift` (TraceStoreIndex section)

### 7D: EvaluationRunner ❌ TODO

- Isolated subprocess to run candidate harness against task suite
- Results written back to registry
- Safe failure reporting
- Headless Epistemos pipeline execution

### 7E: ProposerOrchestrator ❌ TODO (Later-Stage)

- Invoke Claude Code (or another coding agent) as subprocess
- Point at TraceStore and HarnessRegistry with filesystem access
- Minimal skill prompt: "inspect prior candidates, identify failures, propose harness edits"
- Rules: don't modify held-out tasks, don't hardcode answers
- Capture and log proposer output

### 7F: PromotionPipeline ❌ TODO

- Unified diff of candidate vs production harness
- Diagnostic narrative explaining why change was made
- Scorecard showing performance on search and evaluation sets
- Regression report confirming no existing features broken
- Human approval required — no auto-promote
- Atomic swap of production harness on approval

### 7G: Trace Materialization Engine ❌ TODO (Later-Stage)

- Extract structured DB traces to temporary filesystem hierarchy
- Layout: `/tmp/epistemos_lab_traces/harness_v1.x.x/task_NNN/*.jsonl`
- Enables grep/cat-style access for proposer model
- Temporary — cleaned up after proposer run

---

## PHASE 8: NATIVE macOS ISOLATION + SAFETY ❌ TODO

When evaluation or candidate execution requires isolation:
- Native subprocess/sandbox strategies (sandbox-exec / App Sandbox profiles)
- Volatile/disposable project roots for candidate evaluation
- Scrub sensitive environment variables before evolution loop
- Network restricted unless explicitly justified
- Background Harness Lab work yields to foreground user work
- Thermal policy respected for long-running evaluation

---

## PHASE 9: INTEGRATION TESTING + OBSERVABILITY ✅ PARTIAL

**Tests completed (102 passing):**

Hardening tests (57):
- CircuitBreakerTests (6)
- ModeMachineTests (8)
- PerDomainBreakerTests (9)
- BitRingBufferTests (5)
- BreakerConfigTests (6)
- ModeMachineIntegrationTests (4)
- CircuitBreakerIgnorableTests (4)
- BreakerRegistryTests (3)
- FFIGuardCoverageTests (2)
- ThermalGuardTests (3)
- FFITruthBoundaryTests (2)
- SupervisorTests (4)

Harness tests (35):
- BootstrapPacketTests (9)
- TaskTypeTests (4)
- TraceCollectorTests (3)
- ProgressStoreTests (2)
- CompletionCheckerTests (3)
- HarnessRegistryTests (3)
- HarnessPromptBuilderTests (5)
- HarnessIntegrationTests (3)
- EvalMetricsTests (2)

Harness Lab tests (11):
- TaskSuiteTests (4)
- EvalVerificationTests (3)
- TraceStoreIndexTests (4)

**Still needed:**
- Integration tests for wired-up AgentViewModel flow
- Fault injection: trace write failures, progress corruption
- Thermal event tracing end-to-end
- Completion checker with real project builds

---

## PHASE 10: ZERO-ALLOCATION FEASIBILITY PASS ❌ DEFERRED

Only after Phases 1-9 are stable:

For each candidate hot path, determine:
1. Current measured or reasoned hot-path justification
2. Whether actor-owned compact storage is enough
3. Whether Rust AtomicU64 / bit-packed representation is justified
4. Whether cache-line padding / false-sharing precautions matter
5. Whether Swift-side wrapper or UniFFI-exported Rust component is better boundary

**Candidates:**
- MLX inference breaker
- FFI boundary breaker / resilience fuse
- Hermes IPC breaker

**Rule:** Do NOT apply bit-packed atomic breakers to low-throughput domains (cloud HTTP, store reads) unless profiling justifies it.

---

## PHASE 11: SELECTIVE TYPESTATE ISLANDS ❌ DEFERRED

Only after foundations are correct:

**Candidates:**
- **PTY handle** (`Opened`/`Closed`) — Rust typestate, consuming `close()`, Drop auto-close guard
- **FoundationModels session** (`Active`/`Recycling`/`Closed`) — Swift phantom-type wrapper
- **AppBootstrap phases** (`Booting`/`Ready`) — Swift phantom wrapper
- **AgentCapability tokens** (`Cloud`/`Local`/`ReadOnly`) — minted by ModeMachine
- **Hermes subprocess lifecycle** — typestate prevents IPC with terminated process
- **VaultStore handle** (`Open`/`Active`/`Closed`) — Rust typestate

**Rules:**
- No app-wide typestate
- No typestate directly in SwiftUI view state
- No forcing noncopyable complexity through general app routing
- Typestate islands sit behind actors or safe wrappers

---

## PHASE 12: RUST AtomicU64 HOT-PATH BREAKERS ❌ DEFERRED

If Phase 10 feasibility pass justifies it:

- Rust AtomicU64 bit-packed rolling fuse for MLX/FFI breakers
- Half-open and thermal penalty integration
- `#[repr(align(128))]` padding for Apple Silicon 128-byte L1 cache lines
- Preserve public breaker API and tests
- Do NOT regress maintainability for low-throughput domains

---

## PHASE 13: ARC::INTO_RAW FFI MIGRATION ❌ DEFERRED

If profiling shows HandleMap is a bottleneck:

- Migrate from UniFFI HandleMap to `Arc::into_raw()` for hottest boundaries
- Swift `~Copyable` wrappers with explicit `deinit` calling Rust destructor
- Explicit ownership creation/destruction
- Exact once-only release semantics
- No accidental UI exposure of pointer ownership complexity

**Current assessment:** Not a bottleneck. UniFFI HandleMap is correct and sufficient.

---

## QUICK REFERENCE: What to Build Next

### Completed
1. ~~Create this master plan document~~
2. ~~Build initializer vs continuation prompt split (Phase 6E)~~
3. ~~Wire BootstrapPacket + TraceCollector + ProgressStore into AgentViewModel (Phase 6F)~~
4. ~~Wire CompletionChecker into agent completion flow~~

### Immediate (This Session)
5. Build TaskSuite scaffold (Phase 7B)
6. Build TraceStore with SQLite index (Phase 7C)
7. Build EvaluationRunner scaffold (Phase 7D)
8. Build PromotionPipeline with review gate (Phase 7F)
9. Add integration tests for full flow

### Later Sessions
10. Native macOS isolation for evaluation (Phase 8)
11. ProposerOrchestrator (Phase 7E) — needs trace corpus first
12. Trace Materialization Engine (Phase 7G)
13. Zero-allocation feasibility pass (Phase 10)
14. Typestate islands (Phase 11)
15. Rust AtomicU64 breakers (Phase 12)
16. Arc::into_raw migration (Phase 13) — only if profiling justifies

---

## ARCHITECTURE DECISIONS

### ADR-1: FFI Ownership
**Decision:** Keep current UniFFI handle model, harden it.
**Rationale:** Not a bottleneck. Migration to Arc::into_raw deferred to Phase 13.

### ADR-2: Breaker Architecture
**Decision:** Actor-managed breakers for all domains; mark MLX/FFI for later zero-alloc upgrade.
**Rationale:** <500 req/sec per domain, actor overhead negligible.

### ADR-3: Typestate Islands
**Decision:** Defer to Phase 11. Current actor-based lifecycles are correct.

### ADR-4: Thermal Coordination
**Decision:** ThermalGuard is architecturally correct. Enhanced with recovery hysteresis.

### ADR-5: Meta-Harness Integration
**Decision:** Hybrid architecture. Production runtime gets bootstrap packets, traces, progress, completion checking. Harness Lab is developer-only, offline, review-gated. No autonomous self-modification.

### ADR-6: Trace Storage
**Decision:** Hybrid — JSONL files for raw traces (proposer grep/cat access), SQLite for metadata/index. 5GB soft limit, 90-day rotation.

### ADR-7: Harness Promotion
**Decision:** Human-in-the-loop required. No auto-promote. Unified diff + diagnostic narrative + scorecard + regression report required for every promotion.
