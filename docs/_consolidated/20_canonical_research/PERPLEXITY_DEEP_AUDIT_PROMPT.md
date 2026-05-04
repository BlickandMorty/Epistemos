# Deep Architecture Audit: Epistemos Canonical Pattern Integrity

> **Index status**: CANONICAL-RESEARCH — Forensic 7-dimension architecture audit prompt (OTP + circuit breakers + FFI safety + inference lifecycle + resource guards + storage + thermal).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/`.



## Context

Epistemos is a macOS-native personal knowledge management app built on Swift 6.0 + Rust (UniFFI FFI) + Metal compute shaders. It runs a hybrid AI agent system: local on-device inference via MLX-Swift (Qwen3.5, Hermes-3), Apple Intelligence via FoundationModels framework, and cloud inference via Claude/Perplexity/OpenAI. A Python subprocess (Hermes) handles cloud orchestration. The Rust `agent_core` crate owns the agentic loop, HTTP streaming, tool execution, session persistence, memory search, security, prompt caching, and context compaction. Swift owns UI, MLX inference, macOS APIs (AXUIElement, ScreenCaptureKit, CGEvent), and MCP server hosting.

The codebase is 137K lines Swift, 94K lines Rust, 370 Swift files, 99 Rust files. It targets macOS 26.0 with Swift 6 strict concurrency (`SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`). The Rust crate uses UniFFI 0.28 for FFI bindings with `panic = "abort"` in release profile.

I am attaching 30 files from the codebase. I need you to perform a forensic-level audit of every architectural pattern, every safety mechanism, and every resilience layer to determine whether my implementations are canonical, production-grade, and genuinely best-in-class — or whether they are simplified approximations that compromise the ontological integrity of the system.

## The Core Question

**Are my implementations of OTP supervision, degradation state machines, circuit breakers, FFI safety boundaries, thermal guards, and inference lifecycle management truly canonical — matching or exceeding what Erlang/OTP, Netflix Hystrix, Google SRE, Apple's own FoundationModels guidance, and the Rust Nomicon prescribe? Or have corners been cut that create false confidence while leaving real failure modes unaddressed?**

## Audit Dimensions

For each of the following seven areas, I need you to:
1. Define the **canonical pattern** from its origin discipline (Erlang, distributed systems, Rust safety, Apple frameworks)
2. Examine my implementation against that canonical pattern
3. Identify every **deviation, simplification, or omission** — no matter how small
4. Rate severity: **structural** (the pattern is fundamentally wrong), **gap** (missing a critical sub-component), or **cosmetic** (works but isn't idiomatic)
5. Provide the **canonical fix** with code-level specificity
6. Identify any **emergent risks** from the interaction of multiple simplified components

---

### 1. OTP-Style Supervision Tree (`AppSupervisor.swift`)

**Canonical reference**: Erlang/OTP supervisor behavior, Elixir Supervisor module, Akka supervision strategies.

Audit against these specific requirements:
- Does the supervisor implement true `ChildSpec` with `RestartPolicy` (permanent/transient/temporary)?
- Does it track restart intensity with a sliding time window (not just a counter)?
- Does it implement exponential backoff with jitter (Akka pattern) to prevent thundering herd on shared resource recovery?
- Does restart intensity exhaustion trigger escalation to a parent supervisor (bubble-up failure)?
- Are the three canonical strategies (`one_for_one`, `one_for_all`, `rest_for_one`) implemented with correct semantics — specifically, does `rest_for_one` restart children in their original start order?
- Is each supervised "child" a proper Swift actor with a `run() async throws` lifecycle, or is it a procedural health check?
- Does the supervisor distinguish between normal termination, abnormal termination, and shutdown signals?

**What would make this world-class**: A supervision tree where the supervisor itself is supervised, with configurable max restart intensity per window, where child actors are first-class structured concurrency participants with proper cancellation propagation, and where the health loop is event-driven (reacting to failures) rather than polling-driven (checking on a timer).

---

### 2. Degradation State Machine (`EpistemosMode` / `EpistemosHealthMode`)

**Canonical reference**: Facebook's Defcon framework, Netflix's graceful degradation patterns, finite state machine theory (Mealy/Moore machines), Rust typestate pattern.

Audit against:
- Does the state machine enforce **valid transitions at the type level** — can invalid transitions be represented?
- Does each mode carry a `DegradationReason` (associated value) that preserves the causal chain?
- Is transition validation bidirectional — both degradation (forward) and recovery (backward) with step-at-a-time constraints?
- Does the machine expose an `AsyncStream<EpistemosMode>` for reactive UI observation?
- Is there a `forceDegrade` escape hatch for supervisor escalations that bypasses step validation?
- Does the machine log every transition with before/after state for post-mortem analysis?
- Is the machine actor-isolated to prevent concurrent transition races?
- Does the UI actually consume these modes to show/hide features, or are they dead state?

**What would make this world-class**: A typestate-encoded machine where invalid transitions are compile-time errors (not runtime silent ignores), with an event-sourced transition log that enables time-travel debugging, and where every UI surface reads from a single `AsyncStream` rather than polling properties.

---

### 3. Circuit Breaker (`AgentCircuitBreaker`)

**Canonical reference**: Michael Nygard's "Release It!", Netflix Hystrix, Polly (.NET), resilience4j.

Audit against:
- Does it implement the three canonical states: Closed, Open, Half-Open?
- Does the failure counter use a **rolling time window** (not a simple counter that never resets)?
- In Half-Open state, does it require **multiple consecutive successes** before transitioning to Closed (not just one)?
- Does it expose a generic `execute<T>(_ work: () async throws -> T) async throws -> T` that wraps any operation?
- Does the Open state return a typed error with `retryAfter` duration so callers can schedule retry?
- Is it wired bidirectionally to the degradation state machine — opening triggers degradation, closing triggers recovery?
- Does it handle the edge case where the probe request in Half-Open state times out (not just errors)?
- Is there a separate circuit breaker instance per failure domain (inference, network, vault) or a single shared one?

**What would make this world-class**: Per-domain breakers with independent thresholds, a rolling failure window using ring buffer (not array filter), Half-Open with configurable success threshold, automatic EpistemosMode transitions on state changes, and metrics emission for observability (trip count, mean time to recovery).

---

### 4. Rust FFI Safety Boundary (`bridge.rs`)

**Canonical reference**: The Rust Nomicon (Chapter: FFI), RFC 2945 (`extern "C"` abort-on-panic), `catch_unwind` documentation.

Audit against:
- Is `catch_unwind` applied to **every** `#[uniffi::export]` entry point, or only some?
- Does the panic handler extract the panic message safely using `downcast_ref::<&str>()` / `downcast_ref::<String>()`?
- Does it use `std::mem::forget` on the panic payload to prevent re-panic from Drop implementations?
- Given `panic = "abort"` in `[profile.release]`, does `catch_unwind` actually provide protection in production? (Answer: no — it only works with `panic = "unwind"`. Is this a false safety net?)
- Is there a `ffi_guard!` macro that standardizes the pattern across all entry points, or is each function hand-wrapped (error-prone)?
- For async FFI functions (`async_runtime = "tokio"`), is the panic boundary at the correct level — wrapping the entire tokio task, not just inner synchronous blocks?
- Are pointer arguments validated for null before any unsafe dereferencing?
- Is there a sentinel return type (`FfiResult` enum) that distinguishes Ok/Error/Panic on the Swift side?

**Critical question**: The `Cargo.toml` sets `panic = "abort"` in release. This means `catch_unwind` is a **compile-time no-op** in production builds. The app gets zero panic recovery in release. Is this intentional? Should the FFI crate use `panic = "unwind"` while other crates use `panic = "abort"`? Research the correct Cargo workspace configuration for mixed panic strategies.

---

### 5. Foundation Models Session Lifecycle (`AppleIntelligenceService.swift`)

**Canonical reference**: Apple FoundationModels framework documentation (WWDC25/26), `LanguageModelSession` API, iOS 26.4 `contextSize`/`tokenCount(for:)` APIs.

Audit against:
- Is there a 10-minute timer-based session recycle?
- Is there a **token budget guard** that triggers recycle at 75-80% utilization before hitting the hard 4096-token context limit?
- Before recycling, does it **summarize the existing transcript** into a compressed context that gets injected into the new session?
- Does it catch `LanguageModelError.contextWindowExceeded` and retry with a fresh session?
- Is the session cache invalidated when the system prompt changes?
- Is session creation happening on `@MainActor` or on a background actor? (FoundationModels sessions should be created on the actor that will use them)
- Does it use the iOS 26.4 `contextSize` API for dynamic budget calculation, or a hardcoded 4096?
- Is there a separate summarization session (to avoid recursive context growth) or does it summarize within the existing session?

**What would make this world-class**: Dynamic token budget using `tokenCount(for:)` API, opportunistic summarization at 78% threshold, a dedicated summarization session that doesn't pollute the main session's context, `contextWindowExceeded` catch-and-retry, and session metrics (recycles/hour, average utilization at recycle time).

---

### 6. ThermalGuard Integration

**Canonical reference**: `ProcessInfo.thermalState` API, `ProcessInfo.thermalStateDidChangeNotification`, Apple's Energy Efficiency Guide.

Audit against:
- Is there a dedicated `ThermalGuard` actor, or are thermal checks scattered as ad-hoc `if` statements across multiple files?
- Does it use `CheckedContinuation` to **park** inference callers when thermal state is `.serious`/`.critical`, resuming them when temperature drops?
- Does `.critical` cancel all parked continuations with a typed `ThermalError` (not just silently drop them)?
- Does it transition EpistemosMode to `.degradedAI` on `.serious` and `.localOnly` on `.critical`?
- Is thermal state observation done via `AsyncStream` wrapping `NSNotification`, or via synchronous polling?
- Does it handle the `@unknown default` case for future thermal states?
- Are the thermal checks in MLXInferenceService, NightBrainService, and AgentHeartbeatService using the same ThermalGuard actor, or independently reading `ProcessInfo.processInfo.thermalState` (duplicated logic, no central authority)?

**What would make this world-class**: A single ThermalGuard actor that is the sole authority on thermal state, with a continuation-based suspension API that lets inference callers await thermal recovery rather than failing, centralized EpistemosMode transitions, and thermal event logging for post-mortem analysis.

---

### 7. Cross-Cutting Concerns

These are emergent risks that arise from the interaction of the above components:

- **Timeout + Circuit Breaker interaction**: If `withTimeout` fires during a circuit breaker's Half-Open probe, does this count as a failure (re-opening the breaker) or is it treated differently?
- **Supervisor + Mode Machine interaction**: When the supervisor restarts a child, does it re-evaluate and potentially recover EpistemosMode, or does the mode stay degraded?
- **Thermal + Circuit Breaker interaction**: If ThermalGuard suspends inference, do suspended calls eventually time out and trip the circuit breaker (cascading false failure)?
- **Session recycle + active inference**: If the Foundation Models session is recycled while an inference call is in-flight, does the in-flight call fail gracefully or crash?
- **FFI panic + supervisor**: If a Rust panic aborts the process (due to `panic = "abort"`), the supervisor never gets a chance to restart anything. Is there a launchd/XPC watchdog to restart the entire app?

---

## What I Need Back

For each of the 7 areas:

1. **Canonical Pattern Definition** — the gold standard from the origin discipline, with specific references
2. **Current Implementation Rating** — Canonical / Near-Canonical / Simplified / Compromised / Missing
3. **Gap Analysis** — every deviation, with severity rating
4. **Interaction Risk Matrix** — how gaps in one area create emergent failures in others
5. **Canonical Fix Specification** — exact code-level changes needed, with before/after
6. **Priority** — which fixes prevent real production failures vs. which are theoretical

## Files Attached

The following 30 files represent the complete surface area of the hardening work:

### Core Hardening:
1. `Epistemos/State/AppSupervisor.swift`
2. `Epistemos/State/TimeoutUtility.swift`
3. `Epistemos/Engine/AppleIntelligenceService.swift`
4. `agent_core/src/bridge.rs`

### Inference & Agent Pipeline:
5. `Epistemos/Engine/MLXInferenceService.swift`
6. `Epistemos/State/InferenceState.swift`
7. `Epistemos/ViewModels/AgentViewModel.swift`
8. `Epistemos/Bridge/StreamingDelegate.swift`
9. `Epistemos/Engine/LocalModelInfrastructure.swift`

### App Lifecycle:
10. `Epistemos/App/AppBootstrap.swift`
11. `Epistemos/App/EpistemosApp.swift`
12. `Epistemos/State/EpistemosConfig.swift`

### Subprocess & IPC:
13. `Epistemos/Agent/HermesSubprocessManager.swift`
14. `Epistemos/Bridge/ChunkedMCPFraming.swift`
15. `Epistemos/Bridge/CoTStreamInterceptor.swift`
16. `Epistemos/State/OrphanSubprocessCleanup.swift`

### Rust Agent Core:
17. `agent_core/src/agent_loop.rs`
18. `agent_core/src/lib.rs`
19. `agent_core/src/pty.rs`
20. `agent_core/src/providers/claude.rs`
21. `agent_core/src/security.rs`
22. `agent_core/src/prompt_caching.rs`
23. `agent_core/src/compaction.rs`
24. `agent_core/src/tools/registry.rs`

### Health & Monitoring:
25. `Epistemos/State/MainThreadWatchdog.swift`
26. `Epistemos/State/AgentHeartbeatService.swift`
27. `Epistemos/State/NightBrainService.swift`
28. `Epistemos/Omega/Safety/CostTracker.swift`

### Computer Use & Vision:
29. `Epistemos/Omega/Vision/TCCPermissionState.swift`
30. `Epistemos/Omega/Vision/AXTreePruner.swift`

## Engineering Philosophy

I engineer like a robust auditor and sophisticated systems architect. My philosophy:
- **Zero-copy, most-optimized** — no unnecessary allocations, no redundant work
- **No cut corners** — every pattern implemented to its canonical specification or not at all
- **Truth over convenience** — if a safety mechanism is a no-op in production (like `catch_unwind` with `panic = "abort"`), call it out as false confidence
- **Ontological integrity** — the app's architecture should be a faithful representation of the distributed systems principles it claims to implement, not a cargo-culted approximation
- **Emergent failure analysis** — individual components may look correct in isolation but create cascading failures when composed

I want this audit to be brutal. If something is simplified, say so. If something is cargo-culted, say so. If something creates false confidence, say so. I would rather know I have 3 truly canonical implementations than believe I have 7 that are actually compromised.
