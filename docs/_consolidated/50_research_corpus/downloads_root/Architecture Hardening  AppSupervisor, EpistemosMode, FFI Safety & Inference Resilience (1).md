# Architecture Hardening: AppSupervisor, EpistemosMode, FFI Safety & Inference Resilience

## Executive Summary

This report provides deeply researched, production-grade implementation guidance for seven focused architecture items in your AI agent application. Each section includes the canonical pattern, security/safety rationale, concrete Swift/Rust code skeletons, and wiring instructions. The items are ordered by dependency: OTP supervision establishes the foundation, EpistemosMode consumes supervision signals, ThermalGuard and CircuitBreaker feed the degradation machine, FFI safety hardens the Rust bridge, and Foundation Models session recycling manages the inference lifecycle.

***

## 1. AppSupervisor with OTP-Style Restart Strategies

### Core Principles from Erlang/OTP

Erlang/OTP defines three canonical supervision strategies, each suited to a distinct dependency topology:[^1][^2][^3]

| Strategy | Trigger | Restart Scope | When to Use |
|---|---|---|---|
| `one_for_one` | One child fails | Only that child | Independent actors (TelemetryActor, NetworkGateway) |
| `one_for_all` | One child fails | All children | Tightly coupled — shared state must be consistent (InferenceOrchestrator + VaultActor) |
| `rest_for_one` | One child fails | Failed + all started after it | Dependency chain: A → B → C where B's restart must re-initialize C |

Key intensity parameters: Erlang defaults to 1 restart per 5 seconds; Elixir uses 3 per 5 seconds. Exceeding restart intensity causes the supervisor itself to propagate the failure up to its own supervisor (bubble-up pattern). Akka.NET's backoff supervisor pattern adds exponential jitter to avoid synchronized stampedes when a shared resource (e.g., a database) recovers.[^4][^5][^6]

### Swift Architecture: `AppSupervisor` Actor

The idiomatic Swift equivalent replaces OTP processes with Swift actors and structured concurrency `Task`s. Each "worker" actor exposes a `run() async throws` method that represents its lifecycle. The supervisor owns unstructured `Task` references, monitors their completion, and re-spawns based on the configured strategy.[^7][^8]

```swift
// MARK: - Child Specification

enum RestartPolicy {
    case permanent          // Always restart (OTP :permanent)
    case transient          // Restart only on abnormal exit (OTP :transient)
    case temporary          // Never restart (OTP :temporary)
}

enum SupervisionStrategy {
    case oneForOne
    case oneForAll
    case restForOne
}

struct ChildSpec {
    let id: String
    let policy: RestartPolicy
    let maxRestarts: Int
    let restartWindow: Duration          // rolling window for restart counting
    let factory: () async throws -> Void // the actor's run() function
}

// MARK: - AppSupervisor

actor AppSupervisor {
    private let strategy: SupervisionStrategy
    private var children: [String: ChildSpec] = [:]
    private var tasks: [String: Task<Void, Never>] = [:]
    private var restartHistory: [String: [ContinuousClock.Instant]] = [:]

    init(strategy: SupervisionStrategy) {
        self.strategy = strategy
    }

    func addChild(_ spec: ChildSpec) async {
        children[spec.id] = spec
        await startChild(spec)
    }

    private func startChild(_ spec: ChildSpec) async {
        let task = Task {
            do {
                try await spec.factory()
            } catch {
                await self.handleFailure(id: spec.id, error: error)
            }
        }
        tasks[spec.id] = task
    }

    private func handleFailure(id: String, error: Error) async {
        guard let spec = children[id] else { return }

        // Respect restart policy
        if spec.policy == .temporary { return }
        if spec.policy == .transient, error is CancellationError { return }

        // Check restart intensity (sliding window)
        let now = ContinuousClock.now
        var history = restartHistory[id] ?? []
        history = history.filter { now - $0 < spec.restartWindow }

        guard history.count < spec.maxRestarts else {
            // Escalate: this supervisor should itself terminate/escalate
            await escalate(childId: id, error: error)
            return
        }
        history.append(now)
        restartHistory[id] = history

        // Exponential backoff with jitter to avoid thundering herd
        let attempt = history.count
        let baseDelay = Duration.milliseconds(100 * (1 << min(attempt, 6)))
        let jitter = Duration.milliseconds(Int.random(in: 0...50))
        try? await Task.sleep(for: baseDelay + jitter)

        switch strategy {
        case .oneForOne:
            await startChild(spec)

        case .oneForAll:
            // Cancel all siblings, then restart everything in original order
            for (siblingId, task) in tasks where siblingId != id {
                task.cancel()
            }
            tasks.removeAll()
            for childSpec in children.values {
                await startChild(childSpec)
            }

        case .restForOne:
            // Cancel all children started AFTER the failed one, then restart
            let orderedIds = Array(children.keys)
            guard let failedIndex = orderedIds.firstIndex(of: id) else { return }
            let tail = orderedIds[failedIndex...]
            for tailId in tail {
                tasks[tailId]?.cancel()
                tasks[tailId] = nil
            }
            for tailId in tail {
                if let tailSpec = children[tailId] {
                    await startChild(tailSpec)
                }
            }
        }
    }

    private func escalate(childId: String, error: Error) async {
        // In a full supervision tree, send signal to parent supervisor
        // or trigger EpistemosMode degradation
        NotificationCenter.default.post(
            name: .supervisorEscalation,
            object: nil,
            userInfo: ["childId": childId, "error": error]
        )
    }
}
```

### Wiring the Five-Actor Domain Map

Map OTP strategies to the actual actor topology:

```
AppSupervisor (.restForOne)
├── VaultActor              [index 0] – permanent; Keychain ops; if it fails, dependents must restart
├── KnowledgeStoreActor     [index 1] – permanent; depends on VaultActor for encryption keys
├── InferenceOrchestrator   [index 2] – permanent; depends on KnowledgeStore + Vault
├── NetworkGateway          [index 3] – transient; network failures are expected
└── TelemetryActor          [index 4] – temporary; loss of telemetry is acceptable
```

`restForOne` is the correct strategy here because VaultActor provides cryptographic material that KnowledgeStoreActor depends on at startup — if VaultActor is restarted, all downstream actors must re-initialize to re-derive keys and re-establish sessions.[^9]

***

## 2. EpistemosMode Degradation State Machine

### Design Principles

The degradation state machine encodes five operating modes as a Swift `enum` with associated values, making invalid states unrepresentable at the type level. The Rust typestate pattern (encode state as a generic type parameter) provides compile-time transition enforcement; the Swift equivalent uses an actor-isolated enum that validates all transitions.[^10][^11][^12]

The five modes match a severity ladder that mirrors real-world distributed system degradation (Facebook's Defcon framework uses the same "knob" approach — progressively disable less-critical features under load):[^13]

```
full ──►──► degradedAI ──►──► degradedCloud ──►──► localOnly ──►──► readOnly
     ◄────────────────────── recovery possible ──────────────────────►
```

### Implementation

```swift
// MARK: - Mode Definition

enum EpistemosMode: Equatable, Sendable {
    case full
    case degradedAI(reason: DegradationReason)      // Foundation Models suspended (thermal/circuit open)
    case degradedCloud(reason: DegradationReason)    // Network/cloud inference unavailable
    case localOnly(reason: DegradationReason)        // Only on-device, no cloud, no full AI
    case readOnly(reason: DegradationReason)         // All writes suspended; reads from cache only

    enum DegradationReason: Sendable {
        case thermalCritical
        case circuitBreakerOpen(component: String)
        case sessionExhausted
        case networkUnavailable
        case supervisorEscalation(childId: String)
        case vaultUnavailable
    }

    // Valid forward transitions only — returns nil for invalid moves
    func degradeTo(_ next: EpistemosMode) -> EpistemosMode? {
        switch (self, next) {
        case (.full, .degradedAI),
             (.full, .degradedCloud),
             (.degradedAI, .degradedCloud),
             (.degradedAI, .localOnly),
             (.degradedCloud, .localOnly),
             (.localOnly, .readOnly):
            return next
        default:
            return nil // Block invalid transitions
        }
    }

    // Recovery: only allow recovery one step at a time
    func recoverTo(_ next: EpistemosMode) -> EpistemosMode? {
        switch (self, next) {
        case (.readOnly, .localOnly),
             (.localOnly, .degradedCloud),
             (.localOnly, .degradedAI),
             (.degradedCloud, .full),
             (.degradedAI, .full):
            return next
        default:
            return nil
        }
    }
}

// MARK: - EpistemosModeMachine Actor

actor EpistemosModeMachine {
    private(set) var current: EpistemosMode = .full
    private var subscribers: [UUID: AsyncStream<EpistemosMode>.Continuation] = [:]

    func transition(to next: EpistemosMode) {
        // Determine if degradation or recovery
        if let validated = current.degradeTo(next) ?? current.recoverTo(next) {
            let previous = current
            current = validated
            notifySubscribers(from: previous, to: validated)
            log(previous: previous, current: validated)
        }
        // Invalid transitions are silently ignored — no bad state possible
    }

    /// Force-set for supervisor escalations (bypass step validation)
    func forceDegrade(to mode: EpistemosMode) {
        let previous = current
        current = mode
        notifySubscribers(from: previous, to: mode)
    }

    func subscribe() -> AsyncStream<EpistemosMode> {
        let id = UUID()
        return AsyncStream { continuation in
            subscribers[id] = continuation
            continuation.yield(current) // Immediately emit current state
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeSubscriber(id) }
            }
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }

    private func notifySubscribers(from: EpistemosMode, to: EpistemosMode) {
        for continuation in subscribers.values {
            continuation.yield(to)
        }
    }

    private func log(previous: EpistemosMode, current: EpistemosMode) {
        // Wire to TelemetryActor
    }
}
```

### Transition Triggers

Wire these external signals to `EpistemosModeMachine.transition(to:)`:

| Trigger Source | Condition | Target Mode |
|---|---|---|
| `ThermalGuard` | `.serious` thermal state | `.degradedAI(.thermalCritical)` |
| `ThermalGuard` | `.critical` thermal state | `.localOnly(.thermalCritical)` |
| `AgentCircuitBreaker` | inference breaker opens | `.degradedAI(.circuitBreakerOpen("inference"))` |
| `AgentCircuitBreaker` | network breaker opens | `.degradedCloud(.circuitBreakerOpen("network"))` |
| `AppSupervisor` | `VaultActor` escalation | `.readOnly(.vaultUnavailable)` |
| `AppleIntelligenceService` | context exhausted + recycle fails | `.degradedAI(.sessionExhausted)` |
| `NetworkGateway` | connectivity loss | `.degradedCloud(.networkUnavailable)` |

***

## 3. Rust FFI `catch_unwind` on `agent_core/src/bridge.rs`

### Why This Is Non-Negotiable

Unwinding a panic across an `extern "C"` FFI boundary is **undefined behavior**. The Rust Nomicon states: *"You must absolutely catch any panics at the FFI boundary. If you fail to do this, at best, your application will crash and burn. At worst, your application won't crash and burn, and will proceed with completely clobbered state."*[^14][^15]

As of RFC 2945, `extern "C"` functions will **abort** if a panic would escape the boundary (rather than UB). This is better than the old UB, but aborting the entire process is still catastrophic for a long-running agent. `catch_unwind` gives you graceful error reporting instead.[^16][^17]

**Critical caveats**:[^18][^19]
1. `catch_unwind` only catches *unwinding* panics — if your `Cargo.toml` sets `panic = "abort"`, it **never catches anything**. Ensure `panic = "unwind"` for the FFI crate, or use a separate crate compiled with `panic = "unwind"`.
2. The `Err` value returned contains the panic payload. Dropping it can **re-panic**. Extract and discard carefully.
3. Captured values must implement `UnwindSafe`. Use `AssertUnwindSafe` as a last resort wrapper.[^18]

### Implementation Pattern

```rust
// agent_core/src/bridge.rs

use std::panic::{self, AssertUnwindSafe};
use std::ffi::c_int;

/// Sentinel error codes returned to Swift on panic.
#[repr(C)]
pub enum FfiResult {
    Ok = 0,
    Panic = -1,
    Error = -2,
}

/// Macro: wrap every FFI entry point body.
/// Usage: ffi_guard!(|| { your_actual_work() })
macro_rules! ffi_guard {
    ($body:expr) => {{
        match panic::catch_unwind(AssertUnwindSafe($body)) {
            Ok(Ok(v)) => v,
            Ok(Err(e)) => {
                // Rust-level error — log and return sentinel
                eprintln!("[bridge] FFI error: {:?}", e);
                return FfiResult::Error as c_int;
            }
            Err(panic_payload) => {
                // Panic caught — extract message without re-dropping
                let msg = panic_payload
                    .downcast_ref::<&str>()
                    .copied()
                    .or_else(|| {
                        panic_payload
                            .downcast_ref::<String>()
                            .map(|s| s.as_str())
                    })
                    .unwrap_or("unknown panic");
                eprintln!("[bridge] PANIC caught at FFI boundary: {}", msg);
                // Do NOT drop panic_payload here if it contains Drop impls
                // that themselves panic. Leak it instead for safety:
                std::mem::forget(panic_payload);
                return FfiResult::Panic as c_int;
            }
        }
    }};
}

// MARK: - Actual FFI entry points

#[no_mangle]
pub extern "C" fn agent_run_inference(
    input_ptr: *const u8,
    input_len: usize,
    output_ptr: *mut u8,
    output_cap: usize,
) -> c_int {
    ffi_guard!(|| {
        // Validate pointers before any unsafe dereferencing
        if input_ptr.is_null() || output_ptr.is_null() {
            return Err(anyhow::anyhow!("null pointer argument"));
        }
        let input = unsafe { std::slice::from_raw_parts(input_ptr, input_len) };
        let result = do_inference(input)?;
        let out = unsafe { std::slice::from_raw_parts_mut(output_ptr, output_cap) };
        let n = result.len().min(output_cap);
        out[..n].copy_from_slice(&result[..n]);
        Ok(FfiResult::Ok as c_int)
    })
}

#[no_mangle]
pub extern "C" fn agent_load_model(model_path: *const std::ffi::c_char) -> c_int {
    ffi_guard!(|| {
        let path = unsafe { std::ffi::CStr::from_ptr(model_path) }
            .to_str()
            .map_err(|e| anyhow::anyhow!("invalid path: {}", e))?;
        load_model_internal(path)?;
        Ok(FfiResult::Ok as c_int)
    })
}
```

### Swift-Side Timeout Wrapper

Every FFI call from Swift must be guarded by a deadline. Use `withThrowingTaskGroup` to race the FFI call against a timeout:[^20][^21]

```swift
// MARK: - FFI Timeout Wrapper

enum FFIError: Error {
    case timeout(Duration)
    case panic(Int32)
    case bridgeError(Int32)
}

func withFFITimeout<T: Sendable>(
    deadline: Duration = .seconds(10),
    operation: @escaping @Sendable () throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // Worker: perform the actual (blocking) FFI call on a non-cooperative thread
        group.addTask {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        let result = try operation()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }

        // Timeout sentinel
        group.addTask {
            try await Task.sleep(for: deadline)
            throw FFIError.timeout(deadline)
        }

        // First to complete wins; cancel the other
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

// Usage at every call site in bridge layer:
func runInference(input: Data) async throws -> Data {
    try await withFFITimeout(deadline: .seconds(8)) {
        var output = Data(count: 4096)
        let result = input.withUnsafeBytes { inputBuf in
            output.withUnsafeMutableBytes { outputBuf in
                agent_run_inference(
                    inputBuf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    inputBuf.count,
                    outputBuf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    outputBuf.count
                )
            }
        }
        guard result == FfiResult.Ok.rawValue else {
            throw FFIError.bridgeError(result)
        }
        return output
    }
}
```

***

## 4. Foundation Models Session 10-Min Recycle in `AppleIntelligenceService`

### Context Window Constraints

Apple confirmed the on-device Foundation Models context window at **4096 tokens**. iOS 26.4 introduced `contextSize` and `tokenCount(for:)` APIs (back-deployed) for dynamic budget tracking. Sessions are tied to instance lifetimes and carry no persistence across sessions.[^22][^23][^24]

The 10-minute recycle timer is a defense-in-depth measure complementing the token-budget trigger: even if token counting has a bug, the timer forces a clean session slate. Best practice is to trigger recycle at **75–80% token utilization** (opportunistic summarization) before the hard 4096 limit causes an irrecoverable error.[^25]

### Implementation

```swift
// MARK: - AppleIntelligenceService with Session Recycling

import FoundationModels
import Foundation

actor AppleIntelligenceService {

    // MARK: - Configuration

    private static let recycleInterval: Duration = .minutes(10)
    private static let tokenBudgetThreshold: Double = 0.78    // 78% of 4096 = ~3195 tokens
    private static let maxTokens: Int = 4096

    // MARK: - Session State

    private var session: LanguageModelSession?
    private var sessionCreatedAt: ContinuousClock.Instant = .now
    private var recycleTask: Task<Void, Never>?
    private var conversationSummary: String?

    // MARK: - Lifecycle

    init() {
        Task { await self.startRecycleTimer() }
    }

    // MARK: - Session Management

    private func currentSession() async throws -> LanguageModelSession {
        if let session {
            // Check time-based recycle
            if ContinuousClock.now - sessionCreatedAt >= Self.recycleInterval {
                await recycleSession(reason: .timerExpired)
            }
        }
        if session == nil {
            try await createFreshSession()
        }
        return session!
    }

    private func createFreshSession() async throws {
        var instructions = buildSystemInstructions()
        if let summary = conversationSummary {
            // Re-inject compressed context into new session
            instructions += "\n\n[Context from prior session]:\n\(summary)"
        }
        session = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: LanguageModelSession.Instructions(instructions)
        )
        sessionCreatedAt = .now
    }

    private func buildSystemInstructions() -> String {
        // Return your system prompt string
        return "You are an AI assistant..."
    }

    // MARK: - Recycle

    enum RecycleReason {
        case timerExpired
        case tokenBudgetExceeded
        case contextError
        case calledExplicitly
    }

    func recycleSession(reason: RecycleReason) async {
        guard let existingSession = session else { return }

        // Summarize existing transcript to preserve context across sessions
        do {
            conversationSummary = try await summarizeTranscript(existingSession)
        } catch {
            // Graceful: if summarization fails, proceed with blank context
            conversationSummary = nil
        }

        session = nil
        recycleTask?.cancel()
        startRecycleTimer()
    }

    private func summarizeTranscript(_ session: LanguageModelSession) async throws -> String {
        // Use a fresh, temporary summarization session to avoid recursive context growth
        let summarySession = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: LanguageModelSession.Instructions(
                "Summarize the following conversation in ≤200 tokens, preserving key decisions and facts."
            )
        )
        let transcript = session.transcript
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")

        let response = try await summarySession.respond(
            to: "Conversation to summarize:\n\(transcript)"
        )
        return response.content
    }

    // MARK: - Token Budget Guard

    private func checkTokenBudget(for prompt: String) async throws {
        guard let session,
              let tokenCount = try? await SystemLanguageModel.default.tokenCount(for: prompt) else {
            return
        }
        // iOS 26.4 contextSize API; fall back to known 4096 if unavailable
        let contextSize = SystemLanguageModel.default.contextSize ?? Self.maxTokens
        let used = session.transcript
            .compactMap { try? SystemLanguageModel.default.tokenCount(for: $0.content) }
            .reduce(0, +)
        let totalProjected = used + tokenCount

        if Double(totalProjected) / Double(contextSize) >= Self.tokenBudgetThreshold {
            await recycleSession(reason: .tokenBudgetExceeded)
        }
    }

    // MARK: - Timer

    private func startRecycleTimer() {
        recycleTask = Task {
            do {
                try await Task.sleep(for: Self.recycleInterval)
                await self.recycleSession(reason: .timerExpired)
            } catch {
                // Task cancelled — normal on explicit recycle
            }
        }
    }

    // MARK: - Public Inference Interface

    func respond(to prompt: String) async throws -> String {
        // Check token budget before committing to a session
        await checkTokenBudget(for: prompt)  // may recycle

        let activeSession = try await currentSession()
        do {
            let response = try await activeSession.respond(to: prompt)
            return response.content
        } catch let error as LanguageModelError
              where error == .contextWindowExceeded {
            // Hard fallback: recycle and retry once
            await recycleSession(reason: .contextError)
            let freshSession = try await currentSession()
            return try await freshSession.respond(to: prompt).content
        }
    }
}
```

***

## 5. `AgentCircuitBreaker` Wired into Inference and Agent Paths

### Circuit Breaker State Machine

The circuit breaker pattern prevents cascading failures by short-circuiting calls to repeatedly failing dependencies. It has three states:[^26][^27]

- **Closed**: Normal operation. Failures are counted in a rolling window.
- **Open**: Failure threshold exceeded. All calls fail immediately without attempting the operation. Recovery timer starts.
- **Half-Open**: Recovery timer elapsed. One probe request is allowed. Success → Closed; Failure → Open (with backoff).[^27][^28]

### Implementation

```swift
// MARK: - AgentCircuitBreaker

actor AgentCircuitBreaker {

    // MARK: - Configuration

    struct Config {
        var failureThreshold: Int = 5
        var rollingWindow: Duration = .seconds(60)
        var recoveryTimeout: Duration = .seconds(30)
        var successThresholdInHalfOpen: Int = 2   // successes needed to fully close
    }

    private let config: Config
    private let name: String

    // MARK: - State

    private enum State {
        case closed
        case open(since: ContinuousClock.Instant)
        case halfOpen(successes: Int)
    }

    private var state: State = .closed
    private var failureTimestamps: [ContinuousClock.Instant] = []

    // EpistemosMode integration
    weak var modeMachine: EpistemosModeMachine?

    init(name: String, config: Config = .init()) {
        self.name = name
        self.config = config
    }

    // MARK: - Public Interface

    /// Execute `work` guarded by the circuit breaker.
    /// Throws `CircuitBreakerError.open` immediately if the circuit is open.
    func execute<T: Sendable>(_ work: () async throws -> T) async throws -> T {
        switch state {
        case .open(let since):
            let elapsed = ContinuousClock.now - since
            if elapsed >= config.recoveryTimeout {
                state = .halfOpen(successes: 0)
                return try await probeRequest(work)
            } else {
                throw CircuitBreakerError.open(name: name, retryAfter: config.recoveryTimeout - elapsed)
            }

        case .halfOpen:
            return try await probeRequest(work)

        case .closed:
            return try await guardedRequest(work)
        }
    }

    // MARK: - Private

    private func guardedRequest<T: Sendable>(_ work: () async throws -> T) async throws -> T {
        do {
            let result = try await work()
            onSuccess()
            return result
        } catch {
            onFailure()
            throw error
        }
    }

    private func probeRequest<T: Sendable>(_ work: () async throws -> T) async throws -> T {
        do {
            let result = try await work()
            if case .halfOpen(let successes) = state {
                let newCount = successes + 1
                if newCount >= config.successThresholdInHalfOpen {
                    closeCircuit()
                } else {
                    state = .halfOpen(successes: newCount)
                }
            }
            return result
        } catch {
            openCircuit()
            throw error
        }
    }

    private func onFailure() {
        let now = ContinuousClock.now
        failureTimestamps.append(now)
        // Prune outside rolling window
        failureTimestamps = failureTimestamps.filter {
            now - $0 < config.rollingWindow
        }
        if failureTimestamps.count >= config.failureThreshold {
            openCircuit()
        }
    }

    private func onSuccess() {
        failureTimestamps.removeAll()
    }

    private func openCircuit() {
        state = .open(since: .now)
        failureTimestamps.removeAll()
        // Signal EpistemosMode
        Task {
            await modeMachine?.transition(
                to: .degradedAI(reason: .circuitBreakerOpen(component: name))
            )
        }
    }

    private func closeCircuit() {
        state = .closed
        failureTimestamps.removeAll()
        // Signal recovery
        Task {
            await modeMachine?.transition(to: .full)
        }
    }
}

enum CircuitBreakerError: Error {
    case open(name: String, retryAfter: Duration)
}
```

### Wiring into `InferenceOrchestrator`

```swift
actor InferenceOrchestrator {
    private let inferenceBreaker = AgentCircuitBreaker(
        name: "inference",
        config: .init(failureThreshold: 3, rollingWindow: .seconds(30))
    )
    private let agentBreaker = AgentCircuitBreaker(
        name: "agent",
        config: .init(failureThreshold: 5, rollingWindow: .seconds(60))
    )
    private let aiService: AppleIntelligenceService

    func runInference(prompt: String) async throws -> String {
        try await inferenceBreaker.execute {
            try await withFFITimeout(deadline: .seconds(10)) {
                try await self.aiService.respond(to: prompt)
            }
        }
    }

    func dispatchAgentTask(_ task: AgentTask) async throws -> AgentResult {
        try await agentBreaker.execute {
            try await withFFITimeout(deadline: .seconds(30)) {
                try await self.executeAgentTask(task)
            }
        }
    }
}
```

***

## 6. `ThermalGuard` Wired to Inference Suspension

### Thermal State API

`ProcessInfo.processInfo.thermalState` returns one of four values:[^29][^30]

| State | Meaning | Action |
|---|---|---|
| `.nominal` | Normal | Full operation |
| `.fair` | System running fans, reducing background services[^31] | Throttle inference queue concurrency |
| `.serious` | Fans at max, significant performance reduction[^32] | Suspend all new inference jobs |
| `.critical` | Emergency — immediate action required | Drain queue, halt all heavy compute, enter `localOnly` mode |

### Implementation

```swift
// MARK: - ThermalGuard Actor

import Foundation

actor ThermalGuard {

    // MARK: - State

    private(set) var currentState: ProcessInfo.ThermalState = .nominal
    private var suspensionContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]
    private var observationTask: Task<Void, Never>?
    weak var modeMachine: EpistemosModeMachine?

    // MARK: - Lifecycle

    func startObserving() {
        observationTask = Task {
            // Convert NSNotification to AsyncStream
            let stream = AsyncStream<ProcessInfo.ThermalState> { continuation in
                let observer = NotificationCenter.default.addObserver(
                    forName: ProcessInfo.thermalStateDidChangeNotification,
                    object: nil,
                    queue: nil
                ) { _ in
                    continuation.yield(ProcessInfo.processInfo.thermalState)
                }
                continuation.onTermination = { _ in
                    NotificationCenter.default.removeObserver(observer)
                }
            }

            for await newState in stream {
                await self.handleThermalChange(to: newState)
            }
        }
    }

    // MARK: - Suspension Interface

    /// Called by InferenceOrchestrator before starting any inference job.
    /// Suspends the caller if thermal state is .serious or .critical.
    func checkAndSuspendIfNeeded() async throws {
        switch currentState {
        case .nominal, .fair:
            return  // Proceed immediately

        case .serious, .critical:
            // Park the caller until thermal state improves
            let id = UUID()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                suspensionContinuations[id] = continuation
            }
        @unknown default:
            return
        }
    }

    // MARK: - Internal State Handling

    private func handleThermalChange(to newState: ProcessInfo.ThermalState) async {
        let previous = currentState
        currentState = newState

        switch newState {
        case .nominal, .fair:
            // Drain suspended continuations — thermal pressure eased
            let parked = suspensionContinuations
            suspensionContinuations.removeAll()
            for (_, continuation) in parked {
                continuation.resume()
            }
            // Recover EpistemosMode if we were in a thermal degradation state
            if previous == .serious || previous == .critical {
                await modeMachine?.transition(to: .degradedAI(reason: .thermalCritical))
                // Allow InferenceOrchestrator to reassess and recover further
            }

        case .serious:
            // Do not drain — new jobs will be parked
            await modeMachine?.transition(
                to: .degradedAI(reason: .thermalCritical)
            )

        case .critical:
            // Cancel all parked continuations with a thermal error
            let parked = suspensionContinuations
            suspensionContinuations.removeAll()
            for (_, continuation) in parked {
                continuation.resume(throwing: ThermalError.critical)
            }
            await modeMachine?.forceDegrade(
                to: .localOnly(reason: .thermalCritical)
            )

        @unknown default:
            break
        }
    }
}

enum ThermalError: Error {
    case critical
    case serious
}
```

### Wiring into `InferenceOrchestrator`

```swift
// In InferenceOrchestrator:

private let thermalGuard = ThermalGuard()

func runInference(prompt: String) async throws -> String {
    // 1. Thermal check — may suspend this task until device cools
    try await thermalGuard.checkAndSuspendIfNeeded()

    // 2. Circuit breaker — fail fast if inference path is unhealthy
    return try await inferenceBreaker.execute {
        // 3. Timeout guard — every FFI call has a hard deadline
        try await withFFITimeout(deadline: .seconds(10)) {
            try await self.aiService.respond(to: prompt)
        }
    }
}
```

***

## 7. Consolidated Wiring & Dependency Graph

The full layered wiring, showing how all six components connect through `InferenceOrchestrator` and `EpistemosModeMachine`:

```
                    ┌─────────────────────┐
                    │    AppSupervisor     │
                    │  (restForOne)        │
                    └──────┬──────────────┘
                           │ escalation signals
              ┌────────────▼────────────┐
              │  EpistemosModeMachine   │◄──── ThermalGuard
              │  full/degraded/readOnly │◄──── AgentCircuitBreaker
              └────────────┬────────────┘◄──── AppleIntelligenceService
                           │ mode stream
              ┌────────────▼────────────┐
              │  InferenceOrchestrator  │
              │  ┌──────────────────┐   │
              │  │ thermalGuard     │   │  ← suspend/resume inference
              │  │ inferenceBreaker │   │  ← fail-fast on repeat failures
              │  │ withFFITimeout   │   │  ← hard deadline every call
              │  └──────────────────┘   │
              └────────────┬────────────┘
                           │
              ┌────────────▼────────────┐
              │  AppleIntelligenceService│
              │  ┌──────────────────┐   │
              │  │ 10-min timer     │   │
              │  │ token budget     │   │  ← recycle at 78% utilization
              │  │ summarize+reset  │   │
              │  └──────────────────┘   │
              └────────────┬────────────┘
                           │ (if localOnly or readOnly)
              ┌────────────▼────────────┐
              │  agent_core/bridge.rs   │
              │  ffi_guard!(catch_unwind│
              │  + AbortUnwindSafe)     │
              └─────────────────────────┘
```

### Implementation Checklist

- [ ] `AppSupervisor`: actor with `children: [String: ChildSpec]`, strategies `oneForOne`/`oneForAll`/`restForOne`, exponential backoff with jitter, escalation fires `EpistemosModeMachine.forceDegrade`
- [ ] `EpistemosModeMachine`: actor-isolated enum, `transition(to:)` validates forward/backward moves, `subscribe()` returns `AsyncStream<EpistemosMode>`, `forceDegrade` for escalations
- [ ] `agent_core/src/bridge.rs`: `ffi_guard!` macro on every `#[no_mangle] extern "C"` function, `std::mem::forget` on panic payload, `FfiResult` sentinel enum
- [ ] `withFFITimeout`: `withThrowingTaskGroup` racing operation vs `Task.sleep`, wire to every Swift-side bridge call site
- [ ] `AppleIntelligenceService`: 10-minute `Task.sleep` recycle timer + 78% token budget trigger, `summarizeTranscript` using separate session, `conversationSummary` re-injected on new session creation
- [ ] `AgentCircuitBreaker`: actor with `closed/open/halfOpen` state, rolling failure window, `modeMachine` reference for EpistemosMode transitions, `execute<T>` generic method
- [ ] `ThermalGuard`: `NSProcessInfoThermalStateDidChangeNotification` via `AsyncStream`, `checkAndSuspendIfNeeded()` parks callers in continuation dictionary, drains on thermal recovery, forces `localOnly` on `.critical`

---

## References

1. [OTP Supervisors - Elixir School](https://elixirschool.com/en/lessons/advanced/otp_supervisors) - These supervisors enable us to create fault-tolerant applications by automatically restarting child ...

2. [Supervisor Behaviour — Erlang System Documentation v28.4.1](https://www.erlang.org/doc/system/sup_princ.html) - A supervisor is responsible for starting, stopping, and monitoring its child processes. The basic id...

3. [Who Supervises The Supervisors? - Learn You Some Erlang](https://learnyousomeerlang.com/supervisors) - You should use one_for_one whenever the processes being supervised are independent and not really re...

4. [Guidelines for Supervision trees and setting restart intensity ...](https://elixirforum.com/t/guidelines-for-supervision-trees-and-setting-restart-intensity-parameters/15038) - My personal “best practice” approach is to write applications such that no dependent applications ar...

5. [Supervision and Monitoring - Akka Documentation](https://doc.akka.io/libraries/akka-core/current/general/supervision.html) - Resume the actor, keeping its accumulated internal state; Restart the actor, clearing out its accumu...

6. [Supervision | Akka.NET Documentation](https://getakka.net/articles/concepts/supervision.html) - The top-level system actors are supervised using a strategy which will restart indefinitely upon all...

7. [How to Use Swift Concurrency with async/await - OneUptime](https://oneuptime.com/blog/post/2026-02-03-swift-async-await/view) - Master Swift's modern concurrency model with async/await, actors, task groups, and structured concur...

8. [swift-evolution/proposals/0304-structured-concurrency.md at main](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0304-structured-concurrency.md) - In this proposal, the way to create child tasks is only within a TaskGroup , however there will be a...

9. [Supervisor and Application - Elixir](http://elixir-br.github.io/getting-started/mix-otp/supervisor-and-application.html) - The two other candidates are :one_for_all and :rest_for_one . A supervisor using the :one_for_all st...

10. [How to Implement State Machines in Rust - OneUptime](https://oneuptime.com/blog/post/2026-02-01-rust-state-machines/view) - A practical guide to implementing type-safe state machines in Rust using enums and the typestate pat...

11. [State Driven Development - The Beauty of Enums in Swift](http://conradstoll.com/blog/state-driven-development) - When we want to get the associated value out of an enum case we can do it with Swift's pattern match...

12. [The Typestate Pattern in Rust - Cliffle](https://cliffle.com/blog/rust-typestate/) - The typestate pattern is an API design pattern that encodes information about an object's run-time s...

13. [[PDF] Defcon: Preventing Overload with Graceful Feature Degradation](https://www.usenix.org/system/files/osdi23-meza.pdf) - Degrading the static content of a website was proposed in [2] and relevant techniques have been exte...

14. [Unwinding - The Rustonomicon](https://doc.rust-lang.org/nomicon/unwinding.html) - You must absolutely catch any panics at the FFI boundary! What you do at that point is up to you, bu...

15. [Drop, Panic and Abort - Rust Training Slides by Ferrous Systems](https://rust-training.ferrous-systems.com/latest/book/drop-panic-abort) - Panicking across FFI-boundaries is undefined behaviour. In these cases, panics must be caught. For c...

16. [2945-c-unwind-abi - The Rust RFC Book](https://rust-lang.github.io/rfcs/2945-c-unwind-abi.html) - We introduce a new ABI string, "C-unwind", to enable unwinding from other languages (such as C++) in...

17. [When is a panic on a Rust FFI boundary Undefined Behavior?](https://stackoverflow.com/questions/77876748/when-is-a-panic-on-a-rust-ffi-boundary-undefined-behavior) - With the panic=unwind runtime, panic! will cause an abort if it would otherwise "escape" from a func...

18. [catch_unwind in std::panic - Rust](https://doc.rust-lang.org/std/panic/fn.catch_unwind.html) - This function might not catch all Rust panics. A Rust panic is not always implemented via unwinding,...

19. [catch_unwind in std::panic - Rust](https://doc.rust-lang.org/beta/std/panic/fn.catch_unwind.html) - This function might not catch all Rust panics. A Rust panic is not always implemented via unwinding,...

20. [Implementing Task timeout with Swift Concurrency - Donny Wals](https://www.donnywals.com/implementing-task-timeout-with-swift-concurrency/) - We can define another function to wrap up our timeout pattern, and we can improve our Task.sleep by ...

21. [Swift: Have a timeout for async/await function - Stack Overflow](https://stackoverflow.com/questions/75019438/swift-have-a-timeout-for-async-await-function) - I would like to have a deadline for the search() async function to provide a result, otherwise it sh...

22. [iOS 26: Foundation Model Framework - Code-Along Q&A](https://antongubarenko.substack.com/p/ios-26-foundation-model-framework-f6d) - Yes, you can run multiple sessions sequentially, passing results from one to the next. Each session ...

23. [FYI: Foundation Models context limit is 4096 tokens : r/swift - Reddit](https://www.reddit.com/r/swift/comments/1lalhae/fyi_foundation_models_context_limit_is_4096_tokens/) - Apple engineers answered a question during yesterday's group lab and confirmed the 4096 context size...

24. [Apple Improves Context Window Management for its Foundation ...](https://www.infoq.com/news/2026/03/apple-foundation-models-context/) - While the current maximum is 4096 tokens, contextSize removes the need to hardcode that limit and to...

25. [Making the most of Apple Foundation Models: Context Window](https://zats.io/blog/making-the-most-of-apple-foundation-models-context-window/) - How to manage Apple's 4096-token limit with sliding windows, summarization, and selective retention.

26. [Circuit breaker pattern implementation for Swift - GitHub](https://github.com/AlexanderNey/CircuitBreaker) - The circuit breaker pattern is meant to enhance application resilience by preventing repeated attemp...

27. [How to Implement the Circuit Breaker Pattern in Microservices](https://oneuptime.com/blog/post/2026-02-20-microservices-circuit-breaker/view) - This guide shows you how to implement circuit breakers from scratch and with popular libraries. The ...

28. [The Circuit Breaker Pattern: A Comprehensive Guide for 2025](https://www.shadecoder.com/topics/the-circuit-breaker-pattern-a-comprehensive-guide-for-2025) - The circuit breaker pattern is a fault-handling design pattern that prevents an application from rep...

29. [Thermal States on iOS - Wesley de Groot](https://wesleydegroot.nl/blog/thermal-states-on-ios) - You can read the thermal state of an iOS device using the ProcessInfo class. The thermalState proper...

30. [ProcessInfo.ThermalState | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum?changes=_5) - These values are used by the ProcessInfo class as return values for thermalState . For information a...

31. [ProcessInfo.ThermalState.fair | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum/fair?changes=_1) - The system takes steps to reduce thermal state, like running fans and stopping background services t...

32. [ProcessInfo.ThermalState.serious | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum/serious?changes=lat_1_5_8_6_8_3) - Discussion. The system takes moderate steps to reduce thermal state, which reduces performance. Fans...

