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
LAYER 3: META-HARNESS LAB (Phase 7)          ← COMPLETE (7A-7G all done)
LAYER 4: ADVANCED OPTIMIZATION (Phases 8-10) ← Phases 8-9 COMPLETE; 10 deferred
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

## PHASE 7: HARNESS LAB (Developer-Only) ✅ COMPLETE

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

### 7D: EvaluationRunner ✅ COMPLETE

- Sequential task evaluation with per-task timeout (120s default) and failure isolation
- 5 verification types: commandExitZero, filesExist, outputPattern, llmJudge (placeholder), humanReview (placeholder)
- Result persistence: saves `scores_{setName}.json` to candidate directory via HarnessRegistry
- Error isolation: `withThrowingTaskGroup` wraps each task — one failure doesn't abort the run
- Respects `initialStatePath` for per-task working directories
- 5 tests passing: passing command, failing command, filesExist, score persistence, failure isolation

**File:** `Epistemos/Harness/HarnessLab.swift` (EvaluationRunner section)
**Note:** Phase 8 will add real macOS subprocess sandboxing for isolated candidate execution

### 7E: ProposerOrchestrator ✅ COMPLETE

- `ProposerOrchestrator` actor invokes coding agent (Claude Code CLI) as subprocess
- `runProposer()` flow: materialize traces → write skill prompt → spawn agent → capture output → save log
- Skill prompt enforces rules: no held-out modifications, no hardcoded answers, general improvements only
- Agent command resolved from known paths (/usr/local/bin, /opt/homebrew/bin, ~/.local/bin)
- 10-minute timeout, structured output format (diagnosis → proposals → expected impact)
- Proposer logs saved as Markdown under `lab/proposals/proposer_logs/`
- `ProposerResult` type with exit code, stdout/stderr, log file path

**File:** `Epistemos/Harness/HarnessLab.swift` (ProposerOrchestrator section)

### 7F: PromotionPipeline ✅ COMPLETE

- Unified diff generation: `HarnessRegistry.diffCandidate()` compares production vs candidate file trees
- `HarnessDiff` type with added/removed/modified status and per-file content
- Scorecard: pass rate, avg score, avg token cost comparison (baseline vs candidate) as Markdown table
- Per-task results table with pass/fail status
- Regression detection: flags tasks where candidate score dropped >10% from baseline
- Promotion verdict: `readyForReview` or `rejected(reason:)` with threshold enforcement
- `saveProposalArtifact()` persists human-readable Markdown review document
- Human approval required — `executePromotion()` is a separate explicit call
- 3 tests passing: passing proposal, regression detection, artifact persistence

**Files:** `Epistemos/Harness/HarnessLab.swift` (PromotionPipeline section), `Epistemos/Harness/HarnessRegistry.swift` (diff + scores)

### 7G: Trace Materialization Engine ✅ COMPLETE

- `TraceMaterializer` actor extracts indexed traces to temporary filesystem hierarchy
- Layout: `/tmp/epistemos_lab_traces/harness_vX.X.X/session_NNN/events.jsonl`
- Per-version `summary.json` with session count, total events, token costs, outcomes
- `materialize(harnessVersion:)` for single version, `materializeAll()` for full corpus
- `cleanup()` removes all materialized files after proposer run
- `hasMaterializedTraces()` and `materializedDiskUsage()` for lifecycle management
- `TraceStoreIndex.distinctHarnessVersions()` query added for enumeration
- 4 tests passing: materialization, cleanup, distinct versions, disk usage

**File:** `Epistemos/Harness/HarnessLab.swift` (TraceMaterializer section)

---

## PHASE 8: NATIVE macOS ISOLATION + SAFETY ✅ COMPLETE

### 8A: Environment Scrubbing ✅ COMPLETE

- `SanitizedEnvironment` builds safe baseline env for subprocess execution
- Allowlist: PATH, HOME, USER, LANG, TERM, SHELL, TMPDIR, DEVELOPER_DIR, SDKROOT, XDG_*, HOMEBREW_*
- Denylist: API_KEY, SECRET_KEY, ACCESS_TOKEN, ANTHROPIC_*, OPENAI_*, GITHUB_TOKEN, AWS_*, etc.
- 3 tests passing: baseline keys preserved, API keys stripped, prefix keys preserved

### 8B: Volatile Project Roots ✅ COMPLETE

- `VolatileProjectRoot` creates per-task temp directory under `/tmp/epistemos_eval_{UUID}/`
- Shallow-copies `initialStatePath` contents if provided
- `cleanup()` removes entire directory tree after evaluation
- 3 tests passing: create+copy, cleanup removes, nil initialState handled

### 8C: Sandbox Profile (sandbox-exec SBPL) ✅ COMPLETE

- `EvalSandboxProfile` generates Scheme-based sandbox profiles for `sandbox-exec -p`
- Read access: full filesystem (needed for compilers, frameworks)
- Write access: restricted to volatile root, /tmp, ~/Library/Developer, ~/Library/Caches
- Network: denied by default, opt-in via `allowNetwork` flag on `EvalTask`
- Process fork/exec, sysctl, mach, iokit allowed for build tools
- 2 tests passing: default denies network, flag allows network

### 8D: Sandboxed Command Runner ✅ COMPLETE

- `sandboxedRunCommand()` wraps commands with sandbox-exec + sanitized env + volatile root
- Falls back to env-scrub-only if sandbox-exec unavailable
- Timeout watchdog preserved from original `runCommand()`
- Returns same `ProcessResult` type for backward compatibility
- 2 tests passing: sandboxed command succeeds, sanitized env verified

### 8E: Thermal Backpressure + Foreground Yielding ✅ COMPLETE

- `ThermalGuard.shared.acquireClearance()` called before each task evaluation
- `Task.isCancelled` checked between tasks for graceful cancellation
- `Task.yield()` between tasks to let foreground work proceed

### Integration

- `EvaluationRunner.evaluateSingleTask()` now uses `sandboxedRunCommand` instead of `runCommand`
- `EvaluationRunner.evaluateTasks()` loop has thermal + cancellation + yield
- `EvalTask.allowNetwork` field (default false) controls per-task network policy
- Production `runCommand()` in CompletionChecker.swift unchanged

**File:** `Epistemos/Harness/EvalSandbox.swift` (all isolation primitives)
**Modified:** `Epistemos/Harness/HarnessLab.swift` (EvaluationRunner uses sandboxed execution)

---

## PHASE 9: INTEGRATION TESTING + OBSERVABILITY ✅ COMPLETE

**Tests completed (134 passing):**

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

Harness Lab tests (19):
- TaskSuiteTests (4)
- EvalVerificationTests (3)
- TraceStoreIndexTests (4)
- EvaluationRunnerTests (5)
- PromotionPipelineTests (3)

Isolation tests (10):
- SanitizedEnvironmentTests (3)
- VolatileProjectRootTests (3)
- EvalSandboxProfileTests (2)
- SandboxedEvaluationTests (2)

Materialization tests (4):
- TraceMaterializerTests (4)

Fault injection tests (4):
- TraceCollector write to read-only dir (1)
- ProgressStore corrupted JSON (1)
- ProgressStore missing session dir (1)
- TraceCollector close and re-record recovery (1)

Thermal event tracing tests (2):
- Thermal change event serialization (1)
- Breaker tripped event serialization (1)

Harness lifecycle integration tests (4):
- Full prepare → record → complete → verify (1)
- Session continuation detects prior progress (1)
- Events before prepareSession silently dropped (1)
- resetForNewTask allows fresh session (1)

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

### Completed (Prior Sessions)
5. ~~Build TaskSuite scaffold (Phase 7B)~~
6. ~~Build TraceStore with SQLite index (Phase 7C)~~
7. ~~Build EvaluationRunner with verification + persistence (Phase 7D)~~
8. ~~Build PromotionPipeline with diff + scorecard + review gate (Phase 7F)~~
9. ~~Add integration tests for EvaluationRunner + PromotionPipeline~~

### Completed (This Session)
10. ~~Native macOS isolation for evaluation (Phase 8)~~

### Completed (Prior Session)
11. ~~Trace Materialization Engine (Phase 7G)~~
12. ~~ProposerOrchestrator (Phase 7E)~~

### Completed (This Session)
13. ~~Phase 9 integration tests: fault injection, thermal tracing, harness lifecycle~~

### Next Priority
14. Zero-allocation feasibility pass (Phase 10)
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
