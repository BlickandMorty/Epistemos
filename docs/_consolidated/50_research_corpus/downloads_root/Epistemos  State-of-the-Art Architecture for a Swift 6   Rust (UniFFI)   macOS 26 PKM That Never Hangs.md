# Epistemos: State-of-the-Art Architecture for a Swift 6 / Rust (UniFFI) / macOS 26 PKM That Never Hangs

## Vision and Philosophy

The goal is an app that behaves as though it has no concurrency at all — from the user's perspective. Achieving this requires two reinforcing investments: a **pristine baseline** where correctness is enforced by the compiler rather than by discipline, and a **self-healing layer** that handles the residual failure modes that engineering alone cannot eliminate. Neither is sufficient alone. An app with only a pristine baseline will still fail under unexpected load, model unavailability, or OS interference. An app that relies solely on healing will degrade users before the healing kicks in. The architecture below prioritizes building so robustly that healing is rarely invoked, then makes healing fast and invisible when it is.

Epistemos sits at the intersection of four challenging domains: Swift 6 strict concurrency, native Rust code via UniFFI FFI, Apple's Foundation Models framework (on-device LLM), and an agentic reasoning loop. Each domain has its own failure modes and its own best-practice solutions. The integration of all four requires careful thought about isolation boundaries, error propagation, and recovery semantics.

***

## Part I — Swift 6 / Swift 6.2 Baseline Concurrency Architecture

### 1.1 Project-Level Build Settings (macOS 26 / Swift 6.2)

Start from a correctly configured project — most concurrency bugs are latent in incorrect defaults. For macOS 26 with Swift 6.2, use:[^1][^2]

```swift
// swift-tools-version: 6.2
.swiftSettings([
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("DisableOutwardActorInference"),     // SE-0401
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),   // SE-0461
    .enableUpcomingFeature("InferSendableFromCaptures"),
    .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
    .enableUpcomingFeature("StrictConcurrency"),
])
```

In Xcode 26 build settings:
- **Swift Language Mode**: 6
- **Strict Concurrency Checking**: Complete
- **Approachable Concurrency**: Yes
- **Default Actor Isolation** (UI module): `@MainActor`
- **Default Actor Isolation** (library modules): `nonisolated`

`NonisolatedNonsendingByDefault` (SE-0461, Swift 6.2) is the most important setting. It changes the default behavior of nonisolated async functions to run on the caller's actor rather than always hopping to the global cooperative pool, eliminating most unnecessary thread hops for the common case. `DisableOutwardActorInference` prevents property wrappers from silently infecting an entire class with `@MainActor` isolation — isolation is now always explicit.[^3][^2]

### 1.2 The Actor Domain Map

Epistemos needs exactly five actor domains, and the compiler enforces that no state crosses a boundary without a deliberate `await`:

```
┌──────────────────────────────────────────────────────────────────┐
│                      @MainActor (UI module)                       │
│  All SwiftUI Views, ViewModels, AppState, WindowController        │
│  No long-running work. Ever.                                      │
├──────────────────────┬───────────────────────────────────────────┤
│  actor               │  actor                 │  actor           │
│  KnowledgeStore      │  InferenceOrchestrator │  NetworkGateway  │
│  SQLite/vector DB    │  FoundationModels +    │  Cloud model     │
│  Note graph          │  agentic loop          │  API calls       │
│  Tag resolution      │  Tool dispatch         │  Retry/backoff   │
├──────────────────────┴───────────────────────┴──────────────────┤
│  actor VaultActor                                                  │
│  File I/O, document serialization, attachment blobs               │
├──────────────────────────────────────────────────────────────────┤
│  actor TelemetryActor (from prior report)                         │
│  OSLog export, MetricKit, runtime snapshots                       │
└──────────────────────────────────────────────────────────────────┘
```

WWDC25 provides direct guidance: start with everything on `@MainActor`, then move subsystems to their own actor when the main actor becomes a bottleneck. The five domains above correspond exactly to the five subsystems that can legitimately take CPU time independent of the UI.[^4][^5][^6]

### 1.3 Actor Isolation Rules for Epistemos

These rules must be followed consistently or the compiler won't catch violations:[^7][^8]

- **Never `await` across an actor boundary inside a synchronous state update.** If `KnowledgeStore` updates its index, that update must complete atomically from the actor's perspective before yielding.
- **All `Sendable` crossing of actor boundaries must use value types** (structs, enums) or explicitly `Sendable` reference types. Never pass `NSAttributedString`, `NSImage`, or `NSPasteboardItem` raw across actor boundaries.
- **Reentrancy is enabled by default in Swift actors.** If actor `A` awaits on actor `B` while serving another caller, `A`'s state can change. Design for reentrancy: never assume state is stable across an `await` inside an actor method.
- **Use `nonisolated` for computed properties** that derive from immutable `let` state only. Never mark a mutable state accessor as `nonisolated`.

### 1.4 Custom Executors for Legacy and Low-Level Integration

Some subsystems in Epistemos need to run on specific threads or integrate with pre-Swift-concurrency frameworks. The custom `SerialExecutor` protocol handles this cleanly:[^9][^10][^11]

```swift
// Pattern from Apple's AVCam — the definitive reference implementation
actor ScreenCaptureService {
    private let captureQueue = DispatchSerialQueue(
        label: "com.epistemos.screencapture",
        qos: .userInitiated
    )

    // Pin this actor to a specific dispatch queue
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        captureQueue.asUnownedSerialExecutor()
    }

    // This method now always runs on captureQueue, never on the cooperative pool
    func captureWindow(_ windowID: CGWindowID) async throws -> CGImage { ... }
}
```

With SE-0424, calling `dispatchPrecondition(condition: .onQueue(captureQueue))` inside this actor is now valid and won't crash incorrectly — the custom executor can implement `checkIsolated()` to bridge the GCD and Swift concurrency safety checks. This is the correct path for migrating any GCD-based subsystem to actors incrementally.[^12]

### 1.5 Task Timeout — The Core Responsiveness Primitive

Every operation that takes more than ~50ms must be wrapped in a timeout. The race-two-tasks pattern using `withThrowingTaskGroup` is the standard Swift concurrency approach:[^13][^14][^15]

```swift
func withTimeout<T>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError(after: seconds)
        }
        defer { group.cancelAll() }
        return try await group.next()!
    }
}
```

Usage at every layer of the stack:

```swift
// Wrap ALL model calls, DB queries, file reads with this
let response = try await withTimeout(seconds: 30.0) {
    try await session.respond(to: prompt)
}
```

This guarantees that no single operation can block the structured concurrency tree indefinitely, which prevents the SIGKILL scenario from the original log. The `defer { group.cancelAll() }` ensures the losing task is cancelled immediately after the winner returns.[^13]

***

## Part II — UniFFI Rust Layer: Safety and Cancel Correctness

### 2.1 The FFI Boundary Contract

The Rust/Swift FFI boundary through UniFFI is where the most dangerous failure modes live. Two specific risks must be eliminated architecturally: panic propagation and cancel unsafety.

**Panic containment.** In older Rust, a `panic!` crossing an `extern "C"` boundary was undefined behavior. This is resolved by the `c_unwind` RFC, which is now stable. But the active defense remains wrapping every FFI entry point in `catch_unwind`:[^16][^17][^18][^19]

```rust
// In every Rust function exposed to Swift via UniFFI:
#[uniffi::export]
pub fn process_knowledge_graph(input: KnowledgeInput) -> Result<KnowledgeOutput, EpistemosError> {
    std::panic::catch_unwind(|| {
        // actual implementation
        internal_process_knowledge_graph(input)
    })
    .map_err(|_| EpistemosError::InternalPanic)
    .and_then(|r| r)
}
```

UniFFI generates `catch_unwind` wrapping internally for its scaffolding, but explicit wrapping in application-level Rust code provides defense in depth. Never let a Rust panic propagate to Swift — Swift has no mechanism to handle it.[^16]

**Build configuration.** For production Rust builds, add to `Cargo.toml`:

```toml
[profile.release]
panic = "abort"     # Deterministic: panics abort the process, no unwinding overhead
```

In development builds, keep `panic = "unwind"` so `catch_unwind` can capture panics for logging.

### 2.2 Async Rust Cancel Safety

This is the subtlest and most dangerous failure mode in a Rust + async system. Rust futures can be dropped (cancelled) at any `await` point — this is by design and is one of async Rust's great strengths. But it requires explicit design to be safe.[^20][^21][^22]

The rules for Epistemos's Rust codebase:[^21][^22][^20]

| Operation Type | Cancel Safety | Correct Pattern |
|---------------|---------------|-----------------|
| Read-only DB query | Safe — reads are idempotent | No special handling |
| Write to SQLite | **Unsafe** — partial write possible | Wrap in transaction; use explicit rollback on drop |
| Network call (cloud model) | Unsafe — partial send | Use `reqwest` with retryable request bodies |
| Vector embedding computation | Safe — pure computation | No special handling |
| File write | **Unsafe** — partial file possible | Write to temp file, atomic rename on completion |
| Tokio MPSC send | Partially safe — use `reserve().await` then commit | Split reserve/commit |

The most critical pattern for Epistemos's knowledge store:[^22][^21]

```rust
// WRONG - cancel unsafe: partial write possible
async fn save_note(db: &Pool, note: Note) -> Result<()> {
    sqlx::query!("INSERT INTO notes...").execute(db).await?;
    sqlx::query!("UPDATE index...").execute(db).await?;  // cancelled here = inconsistent state
    Ok(())
}

// CORRECT - cancel safe: transaction wraps entire operation
async fn save_note(db: &Pool, note: Note) -> Result<()> {
    let mut tx = db.begin().await?;
    sqlx::query!("INSERT INTO notes...").execute(&mut *tx).await?;
    sqlx::query!("UPDATE index...").execute(&mut *tx).await?;
    tx.commit().await?;  // atomic: either all committed or all rolled back
    Ok(())
}
```

For operations that must never be cancelled even if the calling Swift `Task` is cancelled — such as writing a dirty note to disk before the user closes the app — use `tokio::spawn` to detach the work from the caller's cancellation scope:[^23][^24]

```rust
pub async fn flush_dirty_notes(dirty: Vec<Note>) -> Result<()> {
    // tokio::spawn creates a task that CANNOT be cancelled by caller dropping
    let handle = tokio::spawn(async move {
        for note in dirty {
            atomic_write_note(&note).await?;
        }
        Ok::<(), Error>(())
    });
    handle.await??
}
```

### 2.3 UniFFI Async — The Full Flow

UniFFI translates Rust `async fn` to Swift `async throws` transparently. The key operational detail: the Swift `Task` cancellation propagates to the Rust `RustFuture` via `rust_future_cancel`, which drops the Rust future at its current await point. The implication: every Rust async function exposed via UniFFI must be cancel-safe by the rules above. The `rust_future_free` call happens in UniFFI's scaffolding — but application code must ensure there are no leaked resources when the future is dropped mid-execution.[^25][^26]

```rust
// UniFFI-exported async function — must be cancel-safe
#[uniffi::export]
pub async fn search_knowledge_graph(
    query: String,
    limit: u32
) -> Result<Vec<SearchResult>, EpistemosError> {
    // This is cancel-safe: pure read, no mutations
    let results = GLOBAL_INDEX
        .search(&query, limit as usize)
        .await
        .map_err(EpistemosError::from)?;
    Ok(results)
}
```

***

## Part III — Foundation Models Framework: Resilient Inference

### 3.1 Session Lifecycle Management

The `LanguageModelSession` from Apple's Foundation Models framework is stateful — it maintains a `Transcript` of the conversation. For Epistemos's agentic loop, this statefulness is a feature, but it requires careful lifecycle management to avoid stale sessions, guardrail errors, and memory growth.[^27][^28]

```swift
actor InferenceOrchestrator {
    private var session: LanguageModelSession?
    private var sessionCreatedAt: Date = .distantPast
    private let sessionMaxAge: TimeInterval = 600  // 10 minutes

    // Lazy session creation with automatic expiry
    private func activeSession() throws -> LanguageModelSession {
        // Check Apple Intelligence availability first
        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw InferenceError.modelUnavailable(reason.debugDescription)
        @unknown default:
            throw InferenceError.modelUnavailable("unknown")
        }

        // Recycle sessions to prevent transcript bloat and model drift
        if session == nil || Date().timeIntervalSince(sessionCreatedAt) > sessionMaxAge {
            session = LanguageModelSession(
                model: .default,
                instructions: Instructions { epistemosCoreInstructions }
            )
            sessionCreatedAt = Date()
            Logger.ai.info("Foundation Models session created/recycled")
        }
        return session!
    }

    func respond(to prompt: String, timeout: Double = 30.0) async throws -> String {
        let sess = try activeSession()
        return try await withTimeout(seconds: timeout) {
            try await sess.respond(to: prompt).content
        }
    }
}
```

The `guardrailViolation` error from Foundation Models can trigger unexpectedly due to locale/Siri language configuration mismatches on macOS 26. Handle it explicitly:[^29][^30]

```swift
do {
    let result = try await orchestrator.respond(to: prompt)
    return result
} catch LanguageModelError.guardrailViolation {
    Logger.ai.error("Foundation Models guardrail violation — retrying with rephrased prompt")
    return try await orchestrator.respond(to: rephrased(prompt), timeout: 30.0)
} catch LanguageModelError.unsupportedLanguage {
    Logger.ai.error("Foundation Models: unsupported language — switching to cloud fallback")
    return try await cloudFallback.respond(to: prompt)
} catch is TimeoutError {
    Logger.perf.fault("Foundation Models timeout after 30s — circuit breaker triggered")
    circuitBreaker.recordFailure()
    throw InferenceError.timeout
}
```

### 3.2 Streaming with Backpressure

For Epistemos's UI (displaying note generation in real time), use streaming snapshots rather than a single response. Foundation Models streams `PartiallyGenerated` snapshots — not raw token deltas — which is more robust for structured output:[^31][^32][^28]

```swift
// Streaming into SwiftUI — snapshots update @Observable state on @MainActor
@MainActor
func streamNoteContent(prompt: String) async throws {
    guard let session = try await InferenceOrchestrator.shared.activeSessionPublic() else { return }

    let stream = session.streamResponse(to: prompt, generating: NoteContent.self)

    for try await snapshot in stream {
        // Each snapshot is a partially-generated NoteContent struct
        // SwiftUI automatically re-renders when these @Observable properties change
        self.currentNote.title = snapshot.title ?? ""
        self.currentNote.body = snapshot.body ?? ""
        Task.checkCancellation()  // Respect parent task cancellation
    }
}
```

The snapshot model means if the stream is cancelled mid-generation (user dismisses the view), the partial result is coherent and displayable, not a fragment of a token.

### 3.3 Cloud Fallback — OpenFoundationModels Compatibility

When Apple Intelligence is unavailable (device not supported, user hasn't enabled it, or macOS < 26), Epistemos should fall back to the cloud model. The `OpenFoundationModels` package provides 100% API compatibility with Apple's Foundation Models design, making the fallback transparent:[^33]

```swift
protocol InferenceBackend {
    func respond(to prompt: String) async throws -> String
}

// Concrete implementations share the same interface
struct AppleIntelligenceBackend: InferenceBackend { ... }
struct CloudBackend: InferenceBackend { ... }  // using OpenFoundationModels or direct API

actor InferenceRouter {
    private var backend: InferenceBackend = {
        switch SystemLanguageModel.default.availability {
        case .available: return AppleIntelligenceBackend()
        default: return CloudBackend()
        }
    }()
}
```

***

## Part IV — The Agentic Loop: Supervision and Fault Tolerance

### 4.1 Inner Loop / Outer Loop Separation

The agentic loop must be split into two structurally distinct layers. Conflating them is the single most common architecture mistake in agentic app development:[^34][^35]

**Inner loop** (lives inside `InferenceOrchestrator`):
- Reasoning: observe → think → act → evaluate → repeat
- Tool dispatch: calling Epistemos's registered tools (search notes, create note, update tag)
- Business logic: what makes Epistemos's agent intelligent

**Outer loop** (lives in `AgentSupervisor`):
- Budget enforcement: max tokens, max steps, max wall-clock time
- Guardrails: input/output content filtering
- Observability: every step logged to `TelemetryActor`
- Circuit breaker: detecting and stopping runaway loops
- Recovery: restarting from checkpoint when inner loop fails

```swift
actor AgentSupervisor {
    private let maxSteps = 25
    private let maxWallClock: TimeInterval = 120  // 2 minutes hard limit
    private let circuitBreaker = AgentCircuitBreaker()
    private var checkpoint: AgentCheckpoint?

    func run(task: AgentTask) async throws -> AgentResult {
        guard !circuitBreaker.isOpen else {
            throw AgentError.circuitBreakerOpen
        }

        return try await withTimeout(seconds: maxWallClock) {
            try await self.executeLoop(task: task)
        }
    }

    private func executeLoop(task: AgentTask) async throws -> AgentResult {
        var steps = 0
        var context = AgentContext(task: task)

        while steps < maxSteps {
            try Task.checkCancellation()
            steps += 1

            // Save checkpoint before each step
            checkpoint = AgentCheckpoint(context: context, step: steps)

            // Execute one reasoning step (inner loop)
            let stepResult = try await executeStep(context: &context)
            Logger.ai.info("Agent step \(steps): \(stepResult.action)")

            if stepResult.isTerminal {
                circuitBreaker.recordSuccess()
                return stepResult.result!
            }
        }

        Logger.ai.error("Agent exceeded max steps (\(maxSteps)) without completion")
        throw AgentError.maxStepsExceeded
    }
}
```

The four failure archetypes from LLM agent research — premature action, over-helpfulness, context pollution, fragile execution — are all mitigated by the outer loop's step limit, content guardrails, and checkpoint system.[^36]

### 4.2 The Circuit Breaker for Model Calls

Apply the circuit breaker pattern from distributed systems to all inference calls. This prevents a temporarily broken model (network partition, model loading failure, repeated guardrail violations) from causing the app to hang on retry storms:[^37][^38]

```swift
actor AgentCircuitBreaker {
    private var state: State = .closed
    private var failureCount = 0
    private let failureThreshold = 3
    private let resetTimeout: TimeInterval = 30.0

    enum State { case closed, open(until: Date), halfOpen }

    var isOpen: Bool {
        if case .open(let until) = state {
            if Date() > until { state = .halfOpen }
            return Date() <= until
        }
        return false
    }

    func recordFailure() {
        failureCount += 1
        if failureCount >= failureThreshold {
            state = .open(until: Date().addingTimeInterval(resetTimeout))
            Logger.ai.fault("Circuit breaker OPEN: \(failureCount) consecutive failures")
        }
    }

    func recordSuccess() {
        failureCount = 0
        state = .closed
    }
}
```

States:
- **Closed**: normal operation, all calls proceed
- **Open**: model calls fail immediately without attempting (prevents cascade failures and UI hangs)
- **Half-Open**: one trial call after `resetTimeout`; if successful, returns to Closed[^37]

### 4.3 Checkpoint and Rollback

For multi-step agentic operations, maintain a `AgentCheckpoint` that captures enough state to either resume or gracefully abandon an interrupted loop:

```swift
struct AgentCheckpoint: Codable {
    let taskId: UUID
    let step: Int
    let stepsSoFar: [AgentStep]
    let partialResult: String?
    let timestamp: Date

    // Persist to disk so recovery survives app restart
    func persist() throws {
        let url = checkpointDirectory.appendingPathComponent("\(taskId).json")
        try JSONEncoder().encode(self).write(to: url)
    }
}
```

On agent failure or timeout, present the user with the partial result if meaningful, or silently retry from the last clean checkpoint rather than starting over.[^39]

***

## Part V — The Self-Healing Supervisor Architecture

The self-healing layer is structured as an **OTP-style supervision tree** adapted for Swift actors. This pattern from Erlang/OTP — where supervisors monitor workers and restart them on failure — maps naturally to Swift's actor model and has been explored directly in the Swift community.[^40][^41][^42]

### 5.1 The AppSupervisor

```swift
@MainActor
final class AppSupervisor: ObservableObject {
    // All major actor subsystems
    private let knowledgeStore = KnowledgeStoreActor()
    private let inference = InferenceOrchestrator()
    private let network = NetworkGateway()
    private let vault = VaultActor()
    private let telemetry = TelemetryActor()
    private let agentSupervisor = AgentSupervisor()

    // Healing systems from prior reports
    private let watchdog = MainThreadWatchdog.shared
    private let thermalGuard = ThermalGuard.shared
    private let permissionGuardian = PermissionGuardian.shared

    func startAll() async {
        // Start telemetry first — it must be up before anything else can fail
        await telemetry.start()
        watchdog.start()
        thermalGuard.start()

        // Permission audit on launch
        await permissionGuardian.auditAllPermissions()

        // Start subsystems in dependency order
        do {
            try await knowledgeStore.initialize()
            await vault.initialize()
            await inference.initialize()
            await network.initialize()
        } catch {
            Logger.perf.fault("Critical subsystem failed to start: \(error)")
            // Show onboarding or recovery UI rather than crashing
        }

        // Begin health monitoring loop
        startHealthLoop()
    }

    private func startHealthLoop() {
        Task.detached(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(30))
                await self?.performHealthCheck()
            }
        }
    }

    private func performHealthCheck() async {
        async let inferenceHealth = inference.healthCheck()
        async let storeHealth = knowledgeStore.healthCheck()
        async let networkHealth = network.healthCheck()

        let (infOK, storeOK, netOK) = await (inferenceHealth, storeHealth, networkHealth)

        if !infOK { await restartInference(reason: "health check failed") }
        if !storeOK { await restartKnowledgeStore(reason: "health check failed") }
        // NetworkGateway failure is non-critical — degraded mode only
    }
}
```

The Erlang OTP supervisor strategies map to Epistemos as follows:[^41]

| OTP Strategy | Epistemos Equivalent | When Used |
|-------------|---------------------|-----------|
| `one_for_one` | Restart only the failed actor | Single actor fails (InferenceOrchestrator crash) |
| `rest_for_one` | Restart failed actor + all that depend on it | KnowledgeStore fails — InferenceOrchestrator (which reads from it) must also restart |
| `one_for_all` | Restart all actors | Corrupt shared state detected — nuclear option |

### 5.2 Actor Health Protocol

Every actor in Epistemos implements the same health interface:

```swift
protocol HealthCheckable: Actor {
    func healthCheck() async -> Bool
    func restart(reason: String) async throws
    var isOperational: Bool { get }
}

extension InferenceOrchestrator: HealthCheckable {
    func healthCheck() async -> Bool {
        // Send a trivial probe to the model and verify it responds within 5s
        do {
            _ = try await withTimeout(seconds: 5.0) {
                try await self.respond(to: "ping", timeout: 5.0)
            }
            return true
        } catch {
            Logger.ai.error("InferenceOrchestrator health check FAILED: \(error)")
            return false
        }
    }

    func restart(reason: String) async throws {
        Logger.ai.notice("InferenceOrchestrator restarting: \(reason)")
        session = nil
        sessionCreatedAt = .distantPast
        circuitBreaker.reset()
        try activeSession()  // eagerly recreate session
    }
}
```

### 5.3 Graceful Degradation Modes

Rather than binary working/broken, Epistemos operates in one of four modes. The `AppSupervisor` transitions between them based on subsystem health:

```swift
enum EpistemosMode {
    case full           // All subsystems operational, all features available
    case degradedAI     // Foundation Models unavailable; basic PKM works, AI features hidden
    case degradedCloud  // Network unavailable; local model only, sync paused
    case localOnly      // Both model backends unavailable; pure note-taking, no AI
    case readOnly       // KnowledgeStore degraded; display only, no writes
}
```

The UI observes this mode via `@Observable` and adjusts feature availability:

```swift
@MainActor
@Observable
final class AppStateModel {
    var mode: EpistemosMode = .full

    var isAIAvailable: Bool { mode == .full || mode == .degradedCloud }
    var isWriteAvailable: Bool { mode != .readOnly }
    var shouldShowAIBusyIndicator: Bool { AgentCircuitBreaker.shared.isOpen }
}
```

This is the user-visible face of healing: features gracefully disappear rather than errors appearing.

### 5.4 The Thermal + Inference Coordination

Extending the `ThermalGuard` from the previous report to coordinate with the agentic layer:

```swift
// In ThermalGuard:
func suspendMLInference() {
    Task {
        await InferenceOrchestrator.shared.suspendNewRequests()
        await AgentSupervisor.shared.pauseActiveLoops(reason: "thermal-serious")
        Logger.perf.error("Inference suspended: thermal state serious")
    }
}

func haltAllBackgroundWork() {
    Task {
        await InferenceOrchestrator.shared.cancelAllPending()
        await AgentSupervisor.shared.cancelAll(reason: "thermal-critical")
        await KnowledgeStoreActor.shared.pauseIndexing()
        Logger.perf.fault("All background work halted: thermal state critical")
    }
}
```

***

## Part VI — The Rust Tokio Runtime Integration

### 6.1 The Single Tokio Runtime

One and only one Tokio runtime should exist in the process. UniFFI's async support requires this. Initialize it once at app startup via the Rust layer:[^24][^23]

```rust
// In your Rust library's init function, exported via UniFFI:
use std::sync::OnceLock;
use tokio::runtime::Runtime;

static RUNTIME: OnceLock<Runtime> = OnceLock::new();

pub fn initialize_runtime() {
    RUNTIME.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .worker_threads(4)          // 4 background threads for Rust async work
            .thread_name("epistemos-rust")
            .enable_all()
            .build()
            .expect("Failed to build Tokio runtime")
    });
}
```

Call this from Swift's `applicationDidFinishLaunching` before any other Rust FFI calls.

### 6.2 Panic Recovery with Tokio Spawn

For operations where a Rust panic is recoverable (non-fatal), use `tokio::spawn` to isolate the work and inspect the `JoinError`:[^43][^23]

```rust
pub async fn safe_embed(text: String) -> Result<Vec<f32>, EpistemosError> {
    let handle = tokio::spawn(async move {
        // If the embedding model panics, it's isolated to this task
        generate_embedding(&text)
    });

    match handle.await {
        Ok(Ok(embedding)) => Ok(embedding),
        Ok(Err(e)) => Err(e),
        Err(join_err) if join_err.is_panic() => {
            log::error!("Embedding task panicked — returning empty vector");
            Err(EpistemosError::EmbeddingFailed)
        }
        Err(_) => Err(EpistemosError::TaskCancelled),
    }
}
```

This is the Rust analog of Swift's structured concurrency error propagation: the panic is contained to a spawn boundary and returns a typed `Result` to Swift.[^43][^23]

***

## Part VII — The Complete Stack View

Every layer is now accounted for, with its specific failure modes and defenses:

```
┌────────────────────────────────────────────────────────────────────┐
│  USER-VISIBLE LAYER (@MainActor)                                    │
│  SwiftUI views, graceful degradation modes, no long work ever       │
├────────────────────────────────────────────────────────────────────┤
│  ORCHESTRATION LAYER (Swift Actors)                                  │
│  InferenceOrchestrator  KnowledgeStoreActor  VaultActor  Network    │
│  Each with: healthCheck(), restart(), graceful degradation          │
│  Timeout wrapping on ALL operations > 50ms                          │
├────────────────────────────────────────────────────────────────────┤
│  AGENTIC LAYER (AgentSupervisor)                                     │
│  Inner loop: reasoning + tool use                                   │
│  Outer loop: budget, steps, checkpoints, circuit breaker            │
├────────────────────────────────────────────────────────────────────┤
│  FOUNDATION MODELS LAYER                                             │
│  Session lifecycle management (recycle every 10min)                 │
│  Streaming snapshots, guardrail handling, Apple/cloud fallback      │
├────────────────────────────────────────────────────────────────────┤
│  FFI BOUNDARY (UniFFI)                                               │
│  catch_unwind on all entry points                                   │
│  Cancel-safe async operations (transactions, atomic writes)         │
│  rust_future_free always called via UniFFI scaffolding              │
├────────────────────────────────────────────────────────────────────┤
│  RUST LAYER (Tokio)                                                  │
│  Single runtime, 4 worker threads                                   │
│  tokio::spawn for panic isolation                                   │
│  JoinError inspection for Rust-side recovery                        │
├────────────────────────────────────────────────────────────────────┤
│  SELF-HEALING LAYER (cross-cutting)                                  │
│  MainThreadWatchdog (CFRunLoopObserver, 1.5s threshold)             │
│  ThermalGuard (nominal → fair → serious → critical response)        │
│  AppSupervisor (health loop, OTP-style restart strategies)          │
│  PermissionGuardian (launch audit, graceful UI surfacing)           │
│  MetricKit (immediate hang/crash diagnostics)                       │
├────────────────────────────────────────────────────────────────────┤
│  TELEMETRY LAYER                                                      │
│  OSLog (8 categories), FileSink, InputTelemetry, MetricKit export   │
│  Diagnostic bundle export for AI-assisted analysis                  │
└────────────────────────────────────────────────────────────────────┘
```

### Failure Mode Coverage Matrix

| Failure Mode | Prevention | Detection | Recovery |
|-------------|-----------|-----------|----------|
| Main thread block | Actor isolation, `withTimeout` everywhere | `CFRunLoopObserver` watchdog | `ThermalGuard.handleEmergencyStall()` |
| Rust panic | `catch_unwind`, `panic=abort` in release | `JoinError.is_panic()` | Return typed `EpistemosError` to Swift |
| Foundation Models hang | 30s `withTimeout`, session recycle | Timeout throws `TimeoutError` | Circuit breaker trips, cloud fallback activates |
| Agentic loop runaway | Max 25 steps, 120s wall clock | `AgentSupervisor` step counter | Checkpoint save, graceful partial result |
| Cancel unsafety (Rust) | SQLite transactions, atomic file writes | Integration tests with `tokio::select!` cancellation | Rollback to last committed transaction |
| Thermal degradation | Proactive load reduction at `.fair` | `ProcessInfo.thermalState` + notification | Suspend ML inference, pause background indexing |
| Permission denial | Launch audit, explicit user prompts | `PermissionGuardian.auditAllPermissions()` | Feature gating, informational banner |
| `CGEventTap` silent disable | Health check loop | `EventTapHealthCheck` (10s interval) | `CGEventTapEnable(tap:, enable: true)` |
| Model unavailability | Apple Intelligence availability check | `SystemLanguageModel.availability` | Cloud fallback, `EpistemosMode.degradedAI` |
| Session transcript bloat | 10-minute session recycle | Session age tracking | New `LanguageModelSession` with same instructions |

***

## Part VIII — Implementation Sequence for Claude Code

Present these in strict order — later tasks depend on earlier ones:

### Phase 1: Baseline (1–2 days)
1. Update package manifest to Swift 6.2 language mode with all recommended settings
2. Enable Thread Performance Checker in Xcode scheme diagnostics
3. Resolve all strict concurrency compiler errors — never use `@unchecked Sendable` as a permanent fix
4. Implement the five-actor domain map with proper `@MainActor` isolation for all SwiftUI code
5. Add `withTimeout(seconds:)` wrapper and apply to every FFI call and Foundation Models call

### Phase 2: Rust Safety (2–3 days)
6. Audit every UniFFI-exported async function for cancel safety using the table in Section 2.2
7. Wrap all DB writes in transactions; all file writes as atomic rename
8. Add `catch_unwind` to all Rust FFI entry points
9. Verify single Tokio runtime initialization at app launch
10. Add `tokio::spawn` isolation to embedding and heavy Rust CPU tasks

### Phase 3: Foundation Models Hardening (1–2 days)
11. Implement `InferenceOrchestrator` with session lifecycle management and 10-minute recycle
12. Implement `AgentCircuitBreaker` with Closed/Open/HalfOpen states
13. Implement `AgentSupervisor` with step limit, wall-clock timeout, checkpoint save
14. Implement cloud fallback via `InferenceBackend` protocol + `InferenceRouter`
15. Handle all `LanguageModelError` cases explicitly

### Phase 4: Self-Healing Layer (2–3 days)
16. Implement `AppSupervisor` with OTP-style restart strategies
17. Implement `HealthCheckable` protocol on all five actor domains
18. Implement `EpistemosMode` state machine and UI adaptation
19. Wire `ThermalGuard` to inference orchestrator and agentic loop suspension
20. Implement 30-second health loop from `AppSupervisor`

The result is an app where the compiler enforces correctness at the language level, the architecture enforces isolation at the domain level, and the healing layer handles the remaining operational failures that engineering alone cannot prevent.

---

## References

1. [What should the Concurrency Settings be for a brand new project?](https://forums.swift.org/t/what-should-the-concurrency-settings-be-for-a-brand-new-project/83109) - November 9, 2025, 11:15pm 2. If you enable Swift 6 language mode, strict ("complete") concurrency ch...

2. [Approachable Concurrency in Swift 6.2: A Clear Guide - SwiftLee](https://www.avanderlee.com/concurrency/approachable-concurrency-in-swift-6-2-a-clear-guide/) - Starting in Swift 6, actor isolation must now be explicitly declared on the type, making isolation c...

3. [Swift 5 → 6 migration stories: strict concurrency, Sendable, actors](https://www.reddit.com/r/swift/comments/1ny2w1g/swift_5_6_migration_stories_strict_concurrency/) - Apps are well in the domain of systems programming, and eliminating race conditions is a worthy goal...

4. [WWDC25: Embracing Swift concurrency | Apple - YouTube](https://www.youtube.com/watch?v=u2rYp8AMuSg) - Join us to learn the core Swift concurrency concepts. Concurrency helps you improve app responsivene...

5. [Embracing Swift concurrency - WWDC25 - Videos - Apple Developer](https://developer.apple.com/videos/play/wwdc2025/268/) - Join us to learn the core Swift concurrency concepts. Concurrency helps you improve app responsivene...

6. [WWDC 2025 Deep Dive: Mastering Swift Concurrency's Evolution ...](https://dev.to/arshtechpro/wwdc-2025-deep-dive-mastering-swift-concurrencys-evolution-path-3mpj) - Swift concurrency provides a structured approach to application performance optimization. The key to...

7. [Demystifying Swift 6 Concurrency: Isolation, Actors, and Sendable](https://www.linkedin.com/pulse/demystifying-swift-6-concurrency-isolation-actors-sendable-jain-s8stf) - Best Practice: Keep most UI and business logic on the main actor; only opt for true concurrency when...

8. [Swift Concurrency in a Nutshell - Bedrock Tech Blog](https://tech.bedrockstreaming.com/2023/11/14/swift-concurrency-in-a-nutshell.html) - This article presents a concise, yet comprehensive overview of Swift's Concurrency, highlighting its...

9. [swift-evolution/proposals/0392-custom-actor-executors.md at main](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md) - We propose to give developers the ability to implement simple serial executors, which then can be us...

10. [Swift Actor and GCD Dispatch Queue Executor - Stack Overflow](https://stackoverflow.com/questions/79319749/swift-actor-and-gcd-dispatch-queue-executor) - This defines an actor that is using a custom executor, namely a GCD serial queue: Copy. actor Captur...

11. [Controlling Actors With Custom Executors - Jack Morris](https://jackmorris.xyz/posts/2023/11/21/controlling-actors-with-custom-executors) - First, you need to define a SerialExecutor responsible for executing jobs. In my case, it just dispa...

12. [Custom isolation checking for SerialExecutor - GitHub](https://github.com/apple/swift-evolution/blob/main/proposals/0424-custom-isolation-checking-for-serialexecutor.md) - This proposal fixes this by allowing custom actor executors to provide their own logic for these saf...

13. [Implementing Task timeout with Swift Concurrency - Donny Wals](https://www.donnywals.com/implementing-task-timeout-with-swift-concurrency/) - At the core of implementing a timeout mechanism is the ability to race two tasks: whichever task com...

14. [Running an async task with a timeout - Swift Forums](https://forums.swift.org/t/running-an-async-task-with-a-timeout/49733) - Its goal is to run an async task with a timeout. If the timeout expires and the work hasn't complete...

15. [Implementing Task Timeout in Swift Concurrency - YouTube](https://www.youtube.com/watch?v=ksph4ehl7lM) - You'll learn a bit about task cancellation, structured concurrency, task groups, and more in order t...

16. [When is a panic on a Rust FFI boundary Undefined Behavior?](https://stackoverflow.com/questions/77876748/when-is-a-panic-on-a-rust-ffi-boundary-undefined-behavior) - With the panic=unwind runtime, panic! will cause an abort if it would otherwise "escape" from a func...

17. [Catching panic at FFI boundary, iff unwinding enabled - help](https://users.rust-lang.org/t/catching-panic-at-ffi-boundary-iff-unwinding-enabled/14909) - I am writing a library involving FFI (with C), which needs to pass to a foreign function a pointer t...

18. [FFI is not prod-safe until `c_unwind` RFC stabilizes and we can use it](https://github.com/delta-io/delta-kernel-rs/issues/113) - Otherwise, exceptions thrown from C++ code, or panic! originating in rust code, have undefined behav...

19. [Catching panic at FFI boundary, iff unwinding enabled](https://users.rust-lang.org/t/catching-panic-at-ffi-boundary-iff-unwinding-enabled/14909/3) - I am writing a library involving FFI (with C), which needs to pass to a foreign function a pointer t...

20. [RFD 400 Dealing with cancel safety in async Rust](https://rfd.shared.oxide.computer/rfd/400) - This document aims to be a practical guide to dealing with cancel safety in Rust, and covers four ma...

21. [Cancelling async Rust - sunshowers](https://sunshowers.io/posts/cancelling-async-rust/) - This is an edited, written version of my RustConf 2025 talk about cancellations in async Rust. Like ...

22. [Rain: "Cancelling Async Rust" | RustConf 2025 | Debasish Ghosh](https://www.linkedin.com/posts/debasishgh_rain-cancelling-async-rust-rustconf-activity-7434922453639970816-BCn8) - • She distinguishes cancel safety (a local property: dropping the ... • While no universal fix exist...

23. [JoinError in tokio::task - Rust - Docs.rs](https://docs.rs/tokio/latest/tokio/task/struct.JoinError.html) - Consumes the join error, returning the object with which the task panicked if the task terminated du...

24. [Tokio's spawn tasks and join handles - help - Rust Users Forum](https://users.rust-lang.org/t/tokios-spawn-tasks-and-join-handles/131438) - A JoinHandle detaches the associated task when it is dropped, which means that there is no longer an...

25. [UniFFI Async FFI details](https://mozilla.github.io/uniffi-rs/latest/internals/async-ffi.html) - This document describes the low-level FFI details of UniFFI async calls. Check out Async overview fo...

26. [Async/Future support - The UniFFI user guide](https://mozilla.github.io/uniffi-rs/0.28/futures.html) - UniFFI supports exposing async Rust functions over the FFI. It can convert a Rust Future / async fn ...

27. [Foundation Models | Apple Developer Documentation](https://developer.apple.com/documentation/FoundationModels) - The Foundation Models framework provides access to Apple's on-device large language model that power...

28. [Exploring the Foundation Models framework - Create with Swift](https://www.createwithswift.com/exploring-the-foundation-models-framework/) - In this article, we'll dive into the new Foundation Models API to use the built-in language models: ...

29. [How to fix guardRailViolationError with Foundation Models on ...](https://joschua.io/posts/2025/08/23/guardrail-error-xcode-26) - I ran into a guardRailViolationError when developing with Foundation Models on Xcode 26.0 beta 6. It...

30. [Safety guardrails were triggered. (FoundationModels) : r/swift - Reddit](https://www.reddit.com/r/swift/comments/1o7ggsh/safety_guardrails_were_triggered_foundationmodels/) - How do I handle or even avoid this? Safety guardrails were triggered. If this is unexpected, please ...

31. [iOS 26: Foundation Model Framework - Code-Along Q&A](https://antongubarenko.substack.com/p/ios-26-foundation-model-framework-f6d) - Why is this tool conforming to @Observable ? Is it mandatory for them? Not mandatory for all tools.

32. [Meet the Foundation Models framework - WWDC25 - Apple Developer](https://developer.apple.com/videos/play/wwdc2025/286/) - That wraps up tool calling. We learned why tool calling is useful and how to implement tools to exte...

33. [Apple-Compatible Foundation Models API with Multi-Provider Support](https://forums.swift.org/t/openfoundationmodels-apple-compatible-foundation-models-api-with-multi-provider-support/82168) - Its primary goal is to provide 100% API compatibility with Apple's design, while removing platform a...

34. [The Two Agentic Loops: How to Design and Scale Agentic Apps](https://planoai.dev/blog/the-two-agentic-loops-how-to-design-and-scale-agentic-apps) - This post introduces the concept of "two agentic loops": the inner loop that handles reasoning and t...

35. [When LLMs Grow Hands and Feet, How to Design our Agentic RL ...](https://amberljc.github.io/blog/2025-09-05-agentic-rl-systems.html) - Managing thousands of concurrent environments introduces difficulties in distributed scheduling, sta...

36. [How Do LLMs Fail In Agentic Scenarios? A Qualitative Analysis of ...](https://arxiv.org/html/2512.07497v2) - Across 900 agentic execution traces, we observe four recurring archetypes that cut across model fami...

37. [CircuitBreaker Pattern in Swift. - GitHub](https://github.com/fe9lix/CircuitBreaker) - reset() : Stops all timeouts and resets the breaker to the default state. Note: Call this method whe...

38. [error-handling-patterns | Skills Mar... · LobeHub](https://lobehub.com/bg/skills/kaakati-rails-enterprise-dev-error-handling-patterns) - It covers recovery strategy selection—retry/backoff, idempotency checks, fallbacks, and circuit-brea...

39. [How do you handle fault tolerance in multi-step AI agent workflows?](https://www.reddit.com/r/AI_Agents/comments/1mcb415/how_do_you_handle_fault_tolerance_in_multistep_ai/) - How do you handle fault tolerance in multi-step AI agent workflows? · Call an external API · Process...

40. [Erlang like fault tolerance with Swift actors - Development](https://forums.swift.org/t/erlang-like-fault-tolerance-with-swift-actors/78232) - Hi all, is it feasible to implement erlang like supervision trees and process registries with actors...

41. [Supervisor Behaviour — Erlang System Documentation v28.4.1](https://www.erlang.org/doc/system/sup_princ.html) - Restart Strategy. The restart strategy is specified by the strategy key in the supervisor flags map ...

42. [otp-interop/swift-erlang-actor-system - GitHub](https://github.com/otp-interop/swift-erlang-actor-system) - Swift Erlang Actor System. This library provides a runtime for Swift Distributed Actors backed by er...

43. [Recovering async panics like Tokio? : r/rust - Reddit](https://www.reddit.com/r/rust/comments/1qavwxx/recovering_async_panics_like_tokio/) - Tokio can recover panics on a spawned task, even with a single threaded executor, the panic doesn't ...

