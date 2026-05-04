# Epistemos Canonical Pattern Integrity Audit

**Codebase:** 137K Swift / 94K Rust | macOS 26.0 | Swift 6 strict concurrency | UniFFI 0.28 | `panic = "abort"` release profile

***

## Executive Summary

This forensic audit examined 30 files representing the full surface area of seven architectural hardening areas. The honest verdict: **two implementations are genuine structural failures in production**, three are simplified approximations that create false confidence, one is near-canonical, and one (ThermalGuard) does not exist as a dedicated component at all.

| Area | Rating | Worst Finding |
|---|---|---|
| AppSupervisor (OTP) | **Simplified** | Polling loop, not event-driven; "restart" resets a counter, not a process |
| EpistemosHealthMode (FSM) | **Simplified** | No causal chain, no step constraint, no AsyncStream subscription |
| AgentCircuitBreaker | **Near-Canonical** ⚠️ | Sticky failure counter (no rolling window) creates false positives |
| Rust FFI `catch_unwind` | **Compromised** 🔴 | `panic = "abort"` in release makes every `catch_unwind` call a documented no-op |
| Foundation Models Session | **Near-Canonical** | No token budget guard; context exhaustion not handled |
| ThermalGuard | **Missing** 🔴 | No dedicated actor; scattered, disconnected from mode machine |
| Cross-Cutting Emergent Risks | **Critical** 🔴 | Timeout → CircuitBreaker false trips; process abort kills supervisor |

***

## 1. AppSupervisor — Simplified

### Canonical Pattern (Erlang/OTP)

OTP supervisors are **event-driven**, not polling-driven. When a child process dies, the VM delivers an exit signal to the supervisor synchronously. The supervisor responds using one of three strategies — `one_for_one`, `one_for_all`, `rest_for_one` — within milliseconds of failure, not within 30 seconds. Each `ChildSpec` carries a restart policy (`permanent`/`transient`/`temporary`) and a **restart intensity** expressed as a sliding time window (e.g., max 3 restarts in any 5-second window). Exhausting that intensity causes the supervisor itself to terminate, propagating failure up the supervision tree.[^1][^2][^3][^4]

### Current Implementation

The actual `AppSupervisor` is `@MainActor @Observable final class` with a `Task.detached` polling loop that runs `performHealthCheck()` every 30 seconds.

**Structural deviations:**

1. **Polling, not event-driven.** Failure detection latency is 0–30 seconds. A Hermes subprocess crash at `t=0` is invisible until `t=30`. OTP detects this in microseconds via VM exit signals.[^3]

2. **"Restart" is not a restart.** `restartSubsystem("inference")` calls `inferenceCircuitBreaker.reset()` and sets a boolean. It does not restart any process. Only `restartSubsystem("hermesSubprocess")` calls `hermes.restart()` — and even this is fire-and-forget with `try?` discarding errors.

3. **No `ChildSpec` or restart policy.** There is no concept of `permanent`/`transient`/`temporary` restart semantics. Every "subsystem" is treated identically regardless of whether it should be restarted on clean exit.

4. **No restart intensity / sliding window.** Nothing limits how many times a subsystem can be restarted per unit time. Infinite restart loops are possible if `checkInference()` oscillates.

5. **No exponential backoff.** Restarts are immediate. If a shared resource (e.g., Keychain) is recovering, simultaneous retries create a thundering herd.[^5]

6. **Children are not actors with lifecycle.** `checkInference()` performs an HTTP HEAD request to `api.anthropic.com` — this is a connectivity test, not a child process health signal. `checkKnowledgeStore()` returns `AppBootstrap.shared != nil`, which is always true after boot.

7. **`@MainActor` is wrong for a supervisor.** All health checks run on the main actor, including the 5-second network timeout HEAD request. This blocks the main thread for up to 5 seconds every 30 seconds.

### Canonical Fix

```swift
// Child actors expose a structured lifecycle:
protocol SupervisedActor: Actor {
    func run() async throws          // returns normally on clean shutdown
    func terminate() async           // graceful shutdown signal
    var restartPolicy: RestartPolicy { get }
}

// Supervisor uses withTaskGroup to observe child task completion:
actor AppSupervisor {
    private func monitorChild(_ spec: ChildSpec) async {
        let task = Task {
            do {
                try await spec.factory()     // run() loop
                // Normal exit — respect transient policy
                if spec.policy == .permanent {
                    await scheduleRestart(spec, reason: .normalExit)
                }
            } catch is CancellationError {
                return  // Supervisor-initiated shutdown; do not restart
            } catch {
                // Abnormal exit — always restart permanent/transient
                await scheduleRestart(spec, reason: .error(error))
            }
        }
        childTasks[spec.id] = task
    }
    
    private func scheduleRestart(_ spec: ChildSpec, reason: ExitReason) async {
        // Check sliding window intensity
        let now = ContinuousClock.now
        var history = restartHistory[spec.id] ?? []
        history = history.filter { now - $0 < spec.restartWindow }
        guard history.count < spec.maxRestarts else {
            await escalate(spec, reason: reason)
            return
        }
        // Exponential backoff with jitter
        let attempt = history.count
        let delay = Duration.milliseconds(100 * (1 << min(attempt, 6)))
            + Duration.milliseconds(Int.random(in: 0...50))
        try? await Task.sleep(for: delay)
        await monitorChild(spec)
    }
}
```

**Priority:** 🔴 High — current 30-second latency means failures are invisible during entire inference sessions.

***

## 2. EpistemosHealthMode — Simplified

### Canonical Pattern (Finite State Machine Theory / Facebook Defcon)

A production degradation FSM must enforce **step-at-a-time constraints** to prevent overly aggressive degradation from transient errors. Each transition must carry a **causal reason** (`DegradationReason`) that preserves the chain of events for post-mortem analysis. Subscribers observe transitions via a reactive stream rather than polling a property. The machine must be actor-isolated to prevent concurrent transition races.[^6][^7][^8][^9]

### Current Implementation

`EpistemosHealthMode` is a plain `String`-backed `enum` owned as a `@Published` property on `@MainActor AppSupervisor`. Transitions are computed by `deriveMode(inferenceOK:networkOK:storeOK:)` — a pure function.

**Structural deviations:**

1. **Leap-frog transitions allowed.** `deriveMode(inferenceOK: false, networkOK: false, storeOK: false)` returns `.readOnly` directly, bypassing `.degradedAI`, `.degradedCloud`, and `.localOnly`. In OTP and Defcon-style frameworks, degradation moves one level at a time unless a supervisor escalation forces a direct jump.[^6]

2. **No `DegradationReason` associated values.** The current enum has no associated values. When the UI shows "degraded AI," there is no machine-readable reason why — thermal state? Circuit breaker? VaultActor crash? — making automated recovery logic impossible.

3. **No `AsyncStream<EpistemosMode>` subscription interface.** UI components observe via `@Observable`, which is polling-based under the hood. A reactive stream would allow components to react to transitions immediately and log the reason.

4. **No `forceDegrade` escape hatch.** Supervisor escalations (e.g., VaultActor exceeded restart intensity) need to bypass step validation and jump directly to `.readOnly`. There is no such mechanism.

5. **Transition logging is cosmetic.** One `log.notice` call with a string interpolation. No structured event record, no timestamp, no reason — making post-mortem analysis impossible.

6. **Recovery path is entirely absent.** The machine moves to `.degradedAI` and stays there until the 30-second polling loop happens to evaluate `deriveMode()` and finds conditions improved. There is no recovery event — the state machine is unidirectional in practice.

### Canonical Fix

```swift
actor EpistemosModeMachine {
    private(set) var current: EpistemosHealthMode = .full
    private var log: [(from: EpistemosHealthMode, to: EpistemosHealthMode,
                       reason: DegradationReason, ts: ContinuousClock.Instant)] = []
    private var subscribers: [UUID: AsyncStream<EpistemosHealthMode>.Continuation] = [:]

    func transition(to next: EpistemosHealthMode, reason: DegradationReason) {
        // Step constraint: only adjacent transitions allowed unless forced
        guard current.isValidStep(to: next) else { return }
        let prev = current
        current = next
        log.append((prev, next, reason, .now))
        subscribers.values.forEach { $0.yield(next) }
    }

    func forceDegrade(to mode: EpistemosHealthMode, reason: DegradationReason) {
        let prev = current
        current = mode
        log.append((prev, mode, reason, .now))
        subscribers.values.forEach { $0.yield(mode) }
    }
}

enum DegradationReason: Sendable {
    case thermalState(ProcessInfo.ThermalState)
    case circuitBreakerOpen(component: String)
    case supervisorEscalation(childId: String)
    case contextExhausted
    case networkUnavailable
    case vaultUnavailable
    case manual
}
```

**Priority:** 🟠 Medium — the five modes exist and function correctly for UI gating; the gaps are in causal traceability and recovery precision.

***

## 3. AgentCircuitBreaker — Near-Canonical With One Critical Structural Bug

### Canonical Pattern (Hystrix / Nygard "Release It!")

The canonical circuit breaker uses a **rolling time window** over a ring buffer of timestamped failure events. A failure 61 seconds ago does not count toward the threshold of the next 60-second window. Half-Open state requires **multiple consecutive successes** before fully closing (Hystrix default: single success is sufficient for simplicity, but Polly/.NET and resilience4j both support configurable `minimumThroughput`). The breaker exposes an `execute<T>()` method that owns the guard/record pattern — callers never call `recordFailure` manually.[^10][^11][^12]

### Current Implementation

The `AgentCircuitBreaker` actor implements the three-state machine correctly with a computed `isOpen` property that auto-transitions to `halfOpen` on timer expiry. However:

**Critical structural bug — sticky failure counter:**

```swift
// Current:
func recordFailure() {
    failureCount += 1              // Never decrements while closed
    if failureCount >= failureThreshold {
        state = .open(until: ...)
    }
}

func recordSuccess() {
    failureCount = 0               // Only resets on success
    state = .closed
}
```

If two failures occurred last month (`failureCount = 2`) and one more occurs today, the breaker opens on 3 total failures across an unbounded time span. This is not a rolling window — it is a sticky counter that creates false positives for any long-running application.[^11][^12]

**Additional gaps:**

1. **No `execute<T>()` method.** `AppleIntelligenceService.generate()` manually checks `isOpen`, runs the inference, then manually calls `recordFailure()` or `recordSuccess()`. This pattern is copied at every call site and will be forgotten by a future developer.

2. **Half-Open closes on a single success.** The current `recordSuccess()` always sets `state = .closed` regardless of whether the breaker was in `halfOpen` or `closed`. One successful probe in Half-Open closes the circuit — acceptable but not configurable.

3. **No EpistemosMode direct wiring.** The breaker opening is observed by the supervisor only on the next 30-second polling cycle.

4. **No typed `retryAfter`.** `isOpen` returns `Bool`, so callers cannot schedule a retry at the precise moment the window expires.

### Canonical Fix

```swift
actor AgentCircuitBreaker {
    // Rolling window via timestamped array
    private var failureTimestamps: [ContinuousClock.Instant] = []
    private let rollingWindow: Duration
    
    func execute<T: Sendable>(_ work: () async throws -> T) async throws -> T {
        switch currentEffectiveState {
        case .open(let retryAt):
            throw CircuitBreakerError.open(retryAt: retryAt)
        case .halfOpen, .closed:
            do {
                let result = try await work()
                onSuccess()
                return result
            } catch {
                onFailure()
                throw error
            }
        }
    }
    
    private func onFailure() {
        let now = ContinuousClock.now
        failureTimestamps.append(now)
        // Prune outside rolling window
        failureTimestamps = failureTimestamps.filter { now - $0 < rollingWindow }
        if failureTimestamps.count >= failureThreshold {
            state = .open(since: now)
        }
    }
}
```

**Priority:** 🟠 Medium-High — the sticky counter will generate false positives in production for a long-running app, but the immediate failure-detection path functions correctly.

***

## 4. Rust FFI `catch_unwind` — Compromised (False Safety Net)

### Canonical Pattern (Rust Nomicon / RFC 2945)

The Nomicon is unambiguous: *"unwinding out of Rust into foreign code results in undefined behavior"*. RFC 2945 changed `extern "C"` to **abort** on panic escape rather than UB, but this is worse for a production app than graceful error reporting. The canonical defense is `catch_unwind` wrapping every FFI entry point, with a `ffi_guard!` macro for consistency — **but only when `panic = "unwind"` is active**. The critical constraint: `catch_unwind` is a **compile-time no-op** when `panic = "abort"` is set in the profile.[^13][^14][^15][^16][^17]

### Current Implementation — The Smoking Gun

`bridge.rs` imports `catch_unwind` and uses it in three places: `pty_spawn`, `pty_execute`, and `classify_vault_memory`. The comments explicitly state:

```rust
// SAFETY: catch_unwind prevents panics in PTY spawn from unwinding across FFI boundary.
// In release builds (panic=abort) this is a no-op.
```

**The developers have documented that their safety mechanism is a no-op in production builds and have not fixed it.**

**Critical findings:**

1. **`run_agent_session` has zero `catch_unwind`.** This is the primary `#[uniffi::export(async_runtime = "tokio")]` entry point for the entire agentic loop. A panic anywhere in `run_agent_loop` — in the tool registry, compaction logic, HTTP streaming, or PTY execution — **aborts the entire macOS process** in release builds. The supervisor never gets a chance to restart anything because the process is dead.

2. **`panic = "abort"` in `[profile.release]`** (confirmed by the comment in bridge.rs) means every `catch_unwind` in the codebase is a no-op in the builds that ship to users.

3. **No `ffi_guard!` macro.** Entry points are hand-wrapped inconsistently — 3 out of N FFI functions have `catch_unwind`, the most critical one (`run_agent_session`) does not.

4. **`decay_memory_nodes` and `gc_memory_nodes` have no `catch_unwind`** despite processing arbitrary `Vec<NodeStrengthFFI>` inputs that could trigger panics on malformed data.

### The Correct Fix

The Cargo workspace must override the panic strategy for the FFI crate in release:

```toml
# In agent_core/Cargo.toml:
[profile.release]
panic = "unwind"   # Override for this crate only

# Or in workspace Cargo.toml:
[profile.release.package.agent_core]
panic = "unwind"
```

Then apply `ffi_guard!` universally:

```rust
macro_rules! ffi_guard {
    ($body:expr) => {
        match std::panic::catch_unwind(std::panic::AssertUnwindSafe($body)) {
            Ok(v) => v,
            Err(panic_payload) => {
                let msg = panic_payload.downcast_ref::<&str>().copied()
                    .or_else(|| panic_payload.downcast_ref::<String>().map(|s| s.as_str()))
                    .unwrap_or("unknown panic");
                eprintln!("[ffi] PANIC at bridge boundary: {}", msg);
                std::mem::forget(panic_payload);  // Prevent re-panic on Drop
                return Err(AgentErrorFFI::AgentError {
                    message: format!("Internal panic: {}", msg)
                });
            }
        }
    }
}

#[uniffi::export(async_runtime = "tokio")]
pub async fn run_agent_session(...) -> Result<AgentResultFFI, AgentErrorFFI> {
    ffi_guard!(|| { ... })  // Wrap the entire async body
}
```

**Note on async `ffi_guard!`:** UniFFI's `async_runtime = "tokio"` spawns a Tokio task for async exports. The panic boundary must wrap the task body, not just the outer function. Consider wrapping `run_agent_loop` inside a `tokio::task::spawn` + `JoinHandle::await` to catch panics from the Tokio executor.

**Priority:** 🔴 Critical — a single panic in `run_agent_session` kills the entire macOS app in production with no recovery possible.

***

## 5. Foundation Models Session Lifecycle — Near-Canonical

### Canonical Pattern (Apple WWDC25/26, FoundationModels Framework)

The canonical lifecycle management for `LanguageModelSession` requires: (a) time-based recycle to prevent KV cache bloat; (b) **token budget guard** at 75–80% utilization using `tokenCount(for:)` before hitting the hard 4096-token limit; (c) **transcript summarization** before recycling to preserve context; (d) catching `LanguageModelError.contextWindowExceeded` for a clean retry.[^18][^19][^20]

### Current Implementation

`AppleIntelligenceService` correctly implements the 10-minute timer recycle (`sessionRecycleInterval = 600`) and wraps inference in `withTimeout(seconds: 30.0)`. System prompt changes force a new session. The `@unknown default` case in availability checking is present.

**Gaps:**

1. **No token budget guard.** There is no `tokenCount(for:)` call before invoking `session.respond(to:)`. The session can silently accumulate context across calls until the hard 4096-token limit fires a `contextWindowExceeded` error. This error is not caught — it propagates to `generate()`, triggers `inferenceCircuitBreaker.recordFailure()`, and eventually opens the circuit breaker.

2. **No transcript summarization before recycle.** When the timer fires, `_cachedSession = LanguageModelSession()` — all prior conversation context is dropped silently. The user's next message receives no memory of prior turns in the session.

3. **Subtle system prompt cache bug.** The recycle check is `!needsRecycle && systemPrompt == nil`. If the cached session was created with a system prompt, but the caller passes `systemPrompt: nil`, the cached (system-prompted) session is reused. The prior system prompt persists invisibly.

4. **`@MainActor` isolation for inference.** `LanguageModelSession` inference holds a `@MainActor` context for the duration of the `respond(to:)` call. For calls triggered by background agents (NightBrainService, AgentHeartbeatService), this forces UI-thread contention during inference.

### Canonical Fix

```swift
// Token budget guard before each call:
private func checkAndRecycleIfNeeded(for prompt: String) async {
    guard #available(macOS 26.0, *) else { return }
    guard let session = _cachedSession else { return }
    // iOS 26.4 API: count tokens in accumulated transcript + new prompt
    let existingTokens = await (session.transcript ?? [])
        .asyncReduce(0) { acc, entry in
            acc + ((try? await SystemLanguageModel.default.tokenCount(for: entry.content)) ?? 0)
        }
    let newTokens = (try? await SystemLanguageModel.default.tokenCount(for: prompt)) ?? 0
    let projected = existingTokens + newTokens
    let limit = SystemLanguageModel.default.contextSize ?? 4096
    if Double(projected) / Double(limit) >= 0.78 {
        await recycleSession()
    }
}

// Catch contextWindowExceeded with retry:
do {
    let response = try await session.respond(to: prompt)
    return response.content
} catch let err as LanguageModelError where err == .contextWindowExceeded {
    await recycleSession()
    let fresh = try freshSession()
    return try await fresh.respond(to: prompt).content
}
```

**Priority:** 🟠 Medium — the 10-minute timer provides a safety valve, but context exhaustion during a long session will trip the circuit breaker rather than gracefully recycling.

***

## 6. ThermalGuard — Missing as a Dedicated Component

### Canonical Pattern (ProcessInfo ThermalState API)

The canonical design is a single actor that is the **sole authority** on thermal state, observing `ProcessInfo.thermalStateDidChangeNotification` via `AsyncStream`, suspending inference callers via `CheckedContinuation` parking during `.serious`/`.critical` states, and resuming them when thermal pressure eases.[^21][^22][^23]

### Current Implementation — Scattered, Disconnected

No `ThermalGuard` actor exists. Thermal logic is distributed across five files with no shared authority:

| File | Mechanism | What it does |
|---|---|---|
| `AppBootstrap.swift` | `NotificationCenter` observer | Calls `syncLocalRuntimeConditions` → `MLXInferenceService.updateRuntimeConditions` |
| `MLXInferenceService.swift` | `updateRuntimeConditions()` | Scales memory/cache limits; unloads model on `.critical` |
| `LocalMLXRuntimeTuning` | Enum computation | Maps thermal state to memory/cache policies |
| `AgentHeartbeatService.swift` | `sysctlbyname("machdep.xcpm.thermal_level")` | Guards scheduled background runs |
| `NightBrainService.swift` | `ProcessInfo.processInfo.thermalState` | Guards scheduled background runs |
| `RuntimeIssueMonitor` (EpistemosApp) | `NotificationCenter` observer | Logs thermal events; does NOT signal supervisor |

**Critical absences:**

1. **No inference caller suspension.** When `thermalState == .serious`, new inference requests proceed. MLX's memory limits are reduced, but no calls are parked or rejected. The canonical `checkAndSuspendIfNeeded()` continuation-parking pattern is entirely absent.[^21]

2. **`AgentHeartbeatService` uses an undocumented `sysctl`.** `sysctlbyname("machdep.xcpm.thermal_level")` is an internal kernel metric. Its mapping to Apple's `ProcessInfo.ThermalState` enum is undocumented and may diverge across Apple Silicon generations.

3. **EpistemosMode is never transitioned by thermal events.** `RuntimeIssueMonitor` observes `thermalStateDidChangeNotification` and logs it, but the mode machine is never signaled. Under critical thermal conditions, the app continues routing inference through Apple Intelligence and the Rust bridge as if in `.full` mode.

4. **No centralized suspension/resume.** Each subsystem independently reads thermal state — there is no guarantee of consistency. An inference request can start between two subsystem checks at different thermal states.

### Canonical Fix

```swift
actor ThermalGuard {
    private(set) var current: ProcessInfo.ThermalState = .nominal
    private var parkedCallers: [UUID: CheckedContinuation<Void, Error>] = [:]
    weak var modeMachine: EpistemosModeMachine?

    func startObserving() {
        Task {
            for await _ in NotificationCenter.default
                    .notifications(named: ProcessInfo.thermalStateDidChangeNotification) {
                await handleStateChange(ProcessInfo.processInfo.thermalState)
            }
        }
    }

    /// Call before every inference dispatch. Parks caller until device cools.
    func checkAndSuspendIfNeeded() async throws {
        guard current == .serious || current == .critical else { return }
        let id = UUID()
        try await withCheckedThrowingContinuation { cont in
            parkedCallers[id] = cont
        }
    }

    private func handleStateChange(_ new: ProcessInfo.ThermalState) async {
        let prev = current
        current = new
        switch new {
        case .nominal, .fair:
            // Drain parked callers — thermal pressure eased
            let parked = parkedCallers; parkedCallers.removeAll()
            parked.values.forEach { $0.resume() }
            if prev == .serious || prev == .critical {
                await modeMachine?.transition(to: .full, reason: .thermal(new))
            }
        case .serious:
            await modeMachine?.transition(to: .degradedAI(reason: .thermalState(.serious)))
        case .critical:
            // Cancel all parked with typed error
            let parked = parkedCallers; parkedCallers.removeAll()
            parked.values.forEach { $0.resume(throwing: ThermalError.critical) }
            await modeMachine?.forceDegrade(to: .localOnly, reason: .thermalState(.critical))
        @unknown default: break
        }
    }
}
```

**Priority:** 🔴 High — under sustained inference load on a hot device, no mechanism prevents inference from continuing to drive the device into critical thermal state.

***

## 7. Cross-Cutting Emergent Risk Matrix

These risks arise from the **composition** of the simplified components above. Each individual component may appear acceptable in isolation; together they create failure modes that are difficult to diagnose.

### Risk 1: Thermal Throttling → False Circuit Breaker Open 🔴

**Mechanism:** Device reaches `.serious` thermal state → MLX memory limits reduce → inference slows → `withTimeout(seconds: 30.0)` fires on a slow response → `TimeoutError` thrown → `recordFailure()` called → after 3 timeouts, circuit opens → `EpistemosHealthMode` transitions to `.degradedAI` on next 30s poll.

**Impact:** Temporary thermal slowness permanently degrades the app until the circuit's 30-second reset window elapses. The user sees "AI unavailable" during what is actually a healthy but throttled session.

**Root cause:** No `ThermalGuard` to suspend callers and prevent timeout cascades; no circuit breaker awareness that `TimeoutError` during thermal throttling should not count as a failure.

### Risk 2: Rust Panic in Release → Unrecoverable Process Abort 🔴

**Mechanism:** Any logic error, unwrap on `None`, out-of-bounds access, or failed assertion in `run_agent_loop` panics → `panic = "abort"` → OS terminates the process → `AppSupervisor` (same process) is dead → no restart, no state preservation, no error logging beyond crash reporter.

**Impact:** User data in unsaved state is lost. No graceful degradation. No user-visible error — just a sudden app termination.

**Root cause:** `panic = "abort"` in release profile + no `catch_unwind` on `run_agent_session` + no out-of-process watchdog (launchd KeepAlive or XPC service).

**Fix:** Set `panic = "unwind"` for `agent_core` in release; wrap `run_agent_session` with `ffi_guard!`; add a `launchd` KeepAlive plist for the subprocess if running as a separate process.

### Risk 3: Session Recycle During Active Inference — Silent Context Drop 🟠

**Mechanism:** 10-minute timer fires while `session.respond(to:)` is in-flight → `_cachedSession = LanguageModelSession()` → next call uses context-free session → user's prior conversation context is silently dropped mid-session.

**Impact:** The in-flight response completes correctly (it holds a local reference to the old session). However, the user's next message receives no conversation history, causing incoherent responses with no error indication.

**Root cause:** No coordination between the recycle timer and the in-flight inference state. The timer task and the inference task are independent `Task`s with no mutual exclusion.

**Fix:** Track in-flight inference count; defer recycle until `activeInferenceCount == 0`, or cancel in-flight inference before recycling.

### Risk 4: Sticky Failure Counter → Long-Tail False Positives 🟠

**Mechanism:** Two inference failures in Month 1 (`failureCount = 2`) → many successes → one failure in Month 3 → `failureCount = 3 >= threshold` → circuit opens.

**Impact:** A healthy system that had early instability opens its circuit breaker on a single subsequent failure indefinitely into the future. `failureCount` never naturally decrements — it only resets on `recordSuccess()` or `reset()`.

**Root cause:** No rolling time window in `AgentCircuitBreaker`. The fix is a `[ContinuousClock.Instant]` timestamp array filtered to the last N seconds on every `onFailure()` call.

### Risk 5: Knowledge Store Health Check Is Always True 🟡

**Mechanism:** `checkKnowledgeStore()` returns `AppBootstrap.shared != nil`. After app launch, this is always `true` even when `AppBootstrap.databaseError` is non-nil (SwiftData fell back to an in-memory container).

**Impact:** A database error that should trigger `.readOnly` mode is never detected by the supervisor. The user attempts to write notes, SwiftData silently discards them (in-memory store is not persisted), and the app reports healthy status.

**Fix:** `checkKnowledgeStore()` should return `AppBootstrap.shared?.databaseError == nil`.

***

## Implementation Priority Matrix

| Fix | Severity | Effort | Impact |
|---|---|---|---|
| Set `panic = "unwind"` for `agent_core` release profile | 🔴 Critical | Low (one line in Cargo.toml) | Prevents process abort on Rust panics |
| Add `ffi_guard!` macro to `run_agent_session` | 🔴 Critical | Medium | Graceful error reporting instead of process death |
| Implement `ThermalGuard` actor with continuation parking | 🔴 High | High | Prevents thermal cascade → circuit trip |
| Wire thermal state → `EpistemosModeMachine` | 🔴 High | Low | Mode machine reflects actual device state |
| Fix `AgentCircuitBreaker` rolling time window | 🟠 Medium-High | Low | Eliminates long-tail false positives |
| Add `execute<T>()` to `AgentCircuitBreaker` | 🟠 Medium | Low | Prevents forgotten `recordFailure` at call sites |
| Add token budget guard to `AppleIntelligenceService` | 🟠 Medium | Medium | Prevents context exhaustion → circuit trip |
| Catch `contextWindowExceeded`, recycle, retry | 🟠 Medium | Low | Graceful handling of the inevitable |
| Add `DegradationReason` to `EpistemosHealthMode` | 🟠 Medium | Medium | Causal chain for post-mortem analysis |
| Make `AppSupervisor` event-driven (not polling) | 🟠 Medium | High | Failure detection in <1s vs. up to 30s |
| Fix `checkKnowledgeStore()` to consult `databaseError` | 🟡 Low | Trivial | Correct `.readOnly` mode on DB failure |
| Add transcript summarization to session recycle | 🟡 Low | Medium | Context preservation across 10-min boundary |

---

## References

1. [Guidelines for Supervision trees and setting restart intensity ...](https://elixirforum.com/t/guidelines-for-supervision-trees-and-setting-restart-intensity-parameters/15038) - My personal “best practice” approach is to write applications such that no dependent applications ar...

2. [Supervision and Monitoring - Akka Documentation](https://doc.akka.io/libraries/akka-core/current/general/supervision.html) - Resume the actor, keeping its accumulated internal state; Restart the actor, clearing out its accumu...

3. [Supervisor Behaviour — Erlang System Documentation v28.4.1](https://www.erlang.org/doc/system/sup_princ.html) - A supervisor is responsible for starting, stopping, and monitoring its child processes. The basic id...

4. [Who Supervises The Supervisors? - Learn You Some Erlang](https://learnyousomeerlang.com/supervisors) - You should use one_for_one whenever the processes being supervised are independent and not really re...

5. [Supervision | Akka.NET Documentation](https://getakka.net/articles/concepts/supervision.html) - The top-level system actors are supervised using a strategy which will restart indefinitely upon all...

6. [[PDF] Defcon: Preventing Overload with Graceful Feature Degradation](https://www.usenix.org/system/files/osdi23-meza.pdf) - Degrading the static content of a website was proposed in [2] and relevant techniques have been exte...

7. [How to Implement State Machines in Rust - OneUptime](https://oneuptime.com/blog/post/2026-02-01-rust-state-machines/view) - A practical guide to implementing type-safe state machines in Rust using enums and the typestate pat...

8. [State Driven Development - The Beauty of Enums in Swift](http://conradstoll.com/blog/state-driven-development) - When we want to get the associated value out of an enum case we can do it with Swift's pattern match...

9. [The Typestate Pattern in Rust - Cliffle](https://cliffle.com/blog/rust-typestate/) - The typestate pattern is an API design pattern that encodes information about an object's run-time s...

10. [Circuit Breakers, Discovery, and API Gateways in Microservices](https://arxiv.org/pdf/1609.05830.pdf) - We review some of the most widely used patterns for the programming of
microservices: circuit breake...

11. [How to Implement the Circuit Breaker Pattern in Microservices](https://oneuptime.com/blog/post/2026-02-20-microservices-circuit-breaker/view) - This guide shows you how to implement circuit breakers from scratch and with popular libraries. The ...

12. [The Circuit Breaker Pattern: A Comprehensive Guide for 2025](https://www.shadecoder.com/topics/the-circuit-breaker-pattern-a-comprehensive-guide-for-2025) - The circuit breaker pattern is a fault-handling design pattern that prevents an application from rep...

13. [2945-c-unwind-abi - The Rust RFC Book](https://rust-lang.github.io/rfcs/2945-c-unwind-abi.html) - We introduce a new ABI string, "C-unwind", to enable unwinding from other languages (such as C++) in...

14. [When is a panic on a Rust FFI boundary Undefined Behavior?](https://stackoverflow.com/questions/77876748/when-is-a-panic-on-a-rust-ffi-boundary-undefined-behavior) - With the panic=unwind runtime, panic! will cause an abort if it would otherwise "escape" from a func...

15. [Unwinding - The Rustonomicon](https://doc.rust-lang.org/nomicon/unwinding.html) - You must absolutely catch any panics at the FFI boundary! What you do at that point is up to you, bu...

16. [catch_unwind in std::panic - Rust](https://doc.rust-lang.org/beta/std/panic/fn.catch_unwind.html) - This function might not catch all Rust panics. A Rust panic is not always implemented via unwinding,...

17. [Drop, Panic and Abort - Rust Training Slides by Ferrous Systems](https://rust-training.ferrous-systems.com/latest/book/drop-panic-abort) - Panicking across FFI-boundaries is undefined behaviour. In these cases, panics must be caught. For c...

18. [FYI: Foundation Models context limit is 4096 tokens : r/swift - Reddit](https://www.reddit.com/r/swift/comments/1lalhae/fyi_foundation_models_context_limit_is_4096_tokens/) - Apple engineers answered a question during yesterday's group lab and confirmed the 4096 context size...

19. [Apple Improves Context Window Management for its Foundation ...](https://www.infoq.com/news/2026/03/apple-foundation-models-context/) - While the current maximum is 4096 tokens, contextSize removes the need to hardcode that limit and to...

20. [Making the most of Apple Foundation Models: Context Window](https://zats.io/blog/making-the-most-of-apple-foundation-models-context-window/) - How to manage Apple's 4096-token limit with sliding windows, summarization, and selective retention.

21. [Thermal States on iOS - Wesley de Groot](https://wesleydegroot.nl/blog/thermal-states-on-ios) - You can read the thermal state of an iOS device using the ProcessInfo class. The thermalState proper...

22. [ProcessInfo.ThermalState | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum?changes=_5) - These values are used by the ProcessInfo class as return values for thermalState . For information a...

23. [ProcessInfo.ThermalState.serious | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum/serious?changes=lat_1_5_8_6_8_3) - Discussion. The system takes moderate steps to reduce thermal state, which reduces performance. Fans...

