# Epistemos Advanced Architecture: Typestate Islands & Zero-Allocation Circuit Breakers

**A principal engineering analysis for a Swift 6 + Rust + UniFFI + macOS AI app**

***

## 1. Executive Verdict

**Is full app-wide typestate worth it?**
No. It is architecturally impossible for a SwiftUI app due to hard language constraints, and misapplied it creates more ceremony than safety. *Selective typestate islands* at dangerous lifecycle boundaries are extremely high-ROI. Full app-wide coverage is cargo-cult systems thinking.

**Is a zero-allocation bit-level circuit breaker worth it?**
Yes — but for determinism and fixed footprint, not raw speed. At Epistemos's inference request rates, timestamp pruning is fast enough. The `UInt64` ring buffer wins because it eliminates allocation anxiety on hot paths and simplifies the mental model, not because it's measurably faster.

**What is the real holy grail for Epistemos?**
A three-layer hierarchy: (1) *honest runtime foundations* — event-driven supervision, per-domain breakers with rolling windows, centralized thermal authority, typed degradation reasons; (2) *typestate islands* at FFI handles, subprocess lifecycle, and session ownership; (3) *zero-allocation breaker internals* once the foundations are correct. In that order. Never reversed.

**Critical correction from prior audit (FFI panic strategy):**
Rust's RFC 2282 explicitly states: *"The `panic` key cannot be specified in an override; only in the top level of a profile. Rust does not allow the linking together of crates with different panic settings."* Per-crate panic override is not supported in stable Cargo. The correct solution is either (a) change `profile.release` to `panic = "unwind"` app-wide, enabling `catch_unwind`, or (b) use the `extern "C-unwind"` ABI (stable since Rust 1.73) which gives defined behavior at FFI boundaries under either strategy.[^1][^2][^3]

***

## 2. What These Patterns Actually Mean

### Typestate
Typestate means moving an object's valid state into its type. Instead of runtime guards (`if !isReady { throw }`), the compiler enforces that certain methods simply do not exist on the type unless the precondition is met. An `AgentSession<Uninitialized>` has no `send()` method — calling it is not a runtime error, it is a *compile error*. This is the distinction between a type being *defensively correct* versus *structurally correct*.[^4][^5]

In Swift, this manifests as either phantom-type generic wrappers (`struct Handle<State>`) or, more powerfully, noncopyable types (`~Copyable`) with `consuming` transition methods. The `consuming` keyword transfers ownership of the value — once a handle is "closed," the original variable is gone and cannot be used. In Rust, this is natural: `self` by value consumes the struct, making the post-transition state unreachable by construction.[^6][^7][^8][^9]

### Zero-Allocation Bit-Level Circuit Breaker
A standard circuit breaker tracks failures via an array of timestamps, pruning old entries every time it needs to assess failure rate. This involves allocation growth, garbage collection pressure, and O(n) pruning. A ring bit buffer replaces this with a fixed `[UInt64]` array initialized once. Each slot is one bit: `1` for failure, `0` for success. The ring overwrites old entries as it advances. Failure rate = `popcount(words) / capacity`, executable in a single CPU instruction per word.[^10][^11]

Resilience4j's canonical implementation stores 1024 call results in just 16 `long` (64-bit) values. It maintains a pre-computed cardinality counter updated incrementally on every bit write: `new_cardinality = old_cardinality - old_bit + new_bit`. Query is O(1). Recording is O(1). Memory is fixed at initialization.[^12][^11]

***

## 3. State-of-the-Art Patterns

### Swift 6 / Swift 6.2

**Phantom-type wrappers** remain the most practical typestate technique for production Swift because they work with protocols, `Sendable`, actors, and SwiftUI. They encode state as a generic type parameter with a `fileprivate` or `package` initializer to prevent construction in invalid states:[^4]

```swift
enum Opened {}
enum Closed {}
struct PtyHandle<State> {
    fileprivate let raw: OpaquePointer
}
extension PtyHandle where State == Opened {
    consuming func close() -> PtyHandle<Closed> { ... }
}
```

**Noncopyable types (`~Copyable`)** provide stronger guarantees — the compiler enforces single ownership and `consuming` transitions. However, they carry a set of hard limitations in Swift 6 that constrain their use to *local, synchronous lifecycles*:[^9][^13]

- `~Copyable` types **cannot conform to `Sendable`**. This means they cannot be passed across actor boundaries, stored in `@State`, used in `Task { }` closures, or sent through `AsyncStream`. SE-0503 (January 2026) addresses suppressed conformances on associated types but remains in proposal stage.[^14][^15]
- `~Copyable` types **cannot be used in SwiftUI** `@State`, `@Binding`, `Binding<T>`, `@Observable` properties, or as SwiftUI environment values — all of which require `Copyable`.[^4]
- `~Copyable` types cannot conform to protocols that have `Copyable` in their inheritance chain by default — requiring explicit `~Copyable` on the protocol.[^15]

**Swift 6.2 `approachable concurrency`** (WWDC25) adds `nonisolated(nonsending)` so async functions run on the calling actor's executor by default, reducing annotation fatigue. This improves actor+typestate coordination but does not lift the `~Copyable + Sendable` barrier.[^16]

**OSAllocatedUnfairLock** (synchronous, non-actor) is the best tool for state machines that need synchronous cancellation, consistent with Apple's own `AsyncSequence` implementation guidance. Actors are not FIFO and cannot guarantee cancellation ordering.[^17][^18]

### Rust

Rust typestate is natural because `self` by value consumes the struct:[^5][^19]

```rust
impl PtySession<Opened> {
    pub fn close(self) -> PtySession<Closed> {
        // `self` is consumed — original value unreachable
        PtySession { raw: self.raw, _state: PhantomData }
    }
}
```

The community consensus (Rust Users Forum) is clear: *"typestate and state machines are different things. If you want to transition between states depending on runtime conditions in a loop, it's better not to try to get those state transitions validated by the type system at compile time."* Typestate is for *fixed lifecycle sequences*; runtime state machines are for *dynamic event-driven transitions*.[^19]

**SquirrelFS** (2024 academic paper) demonstrates the highest-stakes real-world Rust typestate: a file system where crash-consistency guarantees are enforced at compile time via typestate ordering of metadata operations. This is the reference benchmark for "is it worth it?" — they used typestate for ordered multi-step protocol enforcement, not for app-level mode management.[^20]

### Mixed Swift/Rust Systems

The natural division: Rust uses typestate for FFI handle ownership (where panics would be fatal and compile-time prevention has the highest ROI), Swift uses phantom-type wrappers or actor state machines for coordination. The boundary itself is the most dangerous surface, which is why the `extern "C-unwind"` ABI correction matters: it gives defined behavior under either panic strategy without requiring per-crate overrides.[^2][^3]

***

## 4. Typestate Implementation Architectures

### The Fundamental Constraint Map

Before choosing architecture, the constraints must be respected:

```
~Copyable ──► cannot conform to Sendable
           ──► cannot cross actor boundary
           ──► cannot be in SwiftUI @State
           ──► cannot be in async Task closure
           └──► ONLY VALID for: local sync lifecycles,
                FFI handles, single-owner resources

Phantom<State> ──► conforms to Sendable ✓
               ──► crosses actor boundary ✓
               ──► can be in SwiftUI if State: Sendable ✓
               └──► VALID for: session wrappers, capability tokens,
                    anything crossing actor or task boundaries
```

### Architecture A — Full App-Wide Typestate (Not Recommended)

Attempting to typestate-encode `AppBootstrap`, `EpistemosHealthMode`, `NightBrainService`, `AgentHeartbeatService`, and all UI state runs immediately into the `~Copyable + Sendable` wall. You end up with phantom-type wrappers everywhere, which compile correctly but produce no meaningful compile-time errors — you can always construct `AppBootstrap<Running>` from `AppBootstrap<Booting>` by accident because phantom types don't restrict construction.

**Failure modes:**
- Generic explosion: every function signature that touches the app state gains type parameters
- SwiftUI views become parameterized: `ContentView<AppBootstrap<Running>>` — non-starter
- Refactoring cost compounds: adding a state requires updating every function signature that touches the wrapper
- Protocol conformances become fragile: actor protocols can't use generic requirements on `Self` easily

### Architecture B — Hybrid Typestate Islands (Recommended for Epistemos)

Apply typestate surgically to exactly the subsystems where invalid sequencing causes memory unsafety, resource leaks, or unrecoverable FFI faults. Leave dynamic runtime coordination to actors.

**Typestate island candidates for Epistemos:**

| Subsystem | Pattern | Value |
|---|---|---|
| PTY handle (`pty.rs`) | Rust typestate, consuming `close()` | Prevents use-after-close across FFI |
| VaultStore handle | Rust typestate, `open → active → closed` | Prevents write-after-close to SQLite |
| Foundation Models session | Swift phantom-type wrapper, `active → recycling` | Enforces token budget check before use |
| AppBootstrap phases | Swift phantom-type wrapper, `Booting → Ready` | Prevents service access before initialization |
| Capability tokens | Swift phantom-type wrapper, `Cloud/Local/ReadOnly` | Compiler-level routing enforcement |

**What stays as actor state machines:**
- `EpistemosModeMachine` — reacts to thermal events, network state, circuit breakers
- `ThermalGuard` — parks/resumes continuations, transitions mode machine
- `AppSupervisor` — event-driven child monitoring
- `AgentCircuitBreaker` (×5 domains) — rolling window, half-open probing

### Concrete Swift Typestate: Foundation Models Session Wrapper

```swift
// Phase markers — uninhabited types, zero runtime cost
enum SessionActive {}
enum SessionRecycling {}
enum SessionClosed {}

// Phantom-type wrapper — Sendable because LanguageModelSession is Sendable
struct AppleIntelligenceHandle<Phase: Sendable>: Sendable {
    fileprivate let session: LanguageModelSession
    fileprivate let systemPrompt: String?
    fileprivate let createdAt: ContinuousClock.Instant
    
    // Construction restricted to factory
    fileprivate init(_ session: LanguageModelSession, systemPrompt: String?) {
        self.session = session
        self.systemPrompt = systemPrompt
        self.createdAt = .now
    }
}

extension AppleIntelligenceHandle where Phase == SessionActive {
    // Token budget gate — only callable on Active sessions
    func checkBudget(for prompt: String) async throws {
        // tokenCount API call
    }
    
    // Inference — only callable on Active sessions
    func respond(to prompt: String) async throws -> String {
        try await session.respond(to: prompt).content
    }
    
    // Recycle — consuming, returns Recycling handle
    consuming func beginRecycle() -> AppleIntelligenceHandle<SessionRecycling> {
        AppleIntelligenceHandle<SessionRecycling>(session, systemPrompt: systemPrompt)
    }
    
    // Timer-based auto-recycle check
    var needsTimeRecycle: Bool {
        ContinuousClock.now - createdAt > .seconds(600)
    }
}

extension AppleIntelligenceHandle where Phase == SessionRecycling {
    // Summarize before creating new session
    func summarizeTranscript() async throws -> String {
        // Use a throwaway summarization session
        let summarySession = LanguageModelSession()
        return try await summarySession.respond(
            to: "Summarize this conversation context in 200 words: \(session.transcript?.description ?? "")"
        ).content
    }
    
    // Complete recycle — returns new Active handle
    consuming func completeRecycle(
        systemPrompt: String?,
        priorContext: String
    ) -> AppleIntelligenceHandle<SessionActive> {
        let instructions = [systemPrompt, "Prior context: \(priorContext)"]
            .compactMap { $0 }.joined(separator: "\n")
        let fresh = LanguageModelSession(instructions: instructions)
        return AppleIntelligenceHandle<SessionActive>(fresh, systemPrompt: systemPrompt)
    }
}

// Usage in actor — handles crossing actor boundaries because Session is Sendable
actor AppleIntelligenceService {
    private var handle: AppleIntelligenceHandle<SessionActive>?
    
    func generate(_ prompt: String) async throws -> String {
        var h = handle ?? makeHandle()
        if h.needsTimeRecycle {
            let summary = try await h.beginRecycle().summarizeTranscript()
            h = AppleIntelligenceHandle<SessionRecycling>(h.session, systemPrompt: h.systemPrompt)
                .completeRecycle(systemPrompt: h.systemPrompt, priorContext: summary)
        }
        try await h.checkBudget(for: prompt)
        let result = try await h.respond(to: prompt)
        handle = h
        return result
    }
}
```

### Concrete Rust Typestate: PTY Handle

```rust
use std::marker::PhantomData;

pub struct Opened;
pub struct Closed;

pub struct PtyHandle<State> {
    raw_id: String,
    _state: PhantomData<State>,
}

impl PtyHandle<Opened> {
    /// Only callable when open — closes the PTY and transitions state
    pub fn close(self) -> PtyHandle<Closed> {
        PtyPool::close(&self.raw_id);
        PtyHandle { raw_id: self.raw_id, _state: PhantomData }
    }
    
    pub async fn execute(&self, command: &str, timeout_ms: u64) 
        -> Result<PtyOutput, PtyError> 
    {
        PtyPool::execute(&self.raw_id, command, 
            Duration::from_millis(timeout_ms)).await
    }
}

// Drop guard: if PtyHandle<Opened> is dropped without calling close(),
// auto-close to prevent zombie PTY sessions
impl Drop for PtyHandle<Opened> {
    fn drop(&mut self) {
        PtyPool::close(&self.raw_id);
    }
}

// PtyHandle<Closed> cannot call execute() — it simply doesn't exist on this type
// Attempting to call raw_id.execute() on a closed handle is a compile error
impl PtyHandle<Closed> {
    pub fn raw_id(&self) -> &str { &self.raw_id }
}
```

### Concrete Swift Capability Tokens

Capability tokens encode what a given agent call *can do* at the type level, preventing routing mistakes without runtime guards:

```swift
// Capability markers
struct CloudCapable: Sendable {}
struct LocalCapable: Sendable {}
struct ReadOnlyCapable: Sendable {}

struct AgentCapability<Cap: Sendable>: Sendable {
    fileprivate init() {}
}

// Only EpistemosModeMachine can mint capabilities
extension EpistemosModeMachine {
    func mintCapability() -> some Sendable {
        switch current {
        case .full:
            return AgentCapability<CloudCapable>()
        case .degradedCloud, .localOnly:
            return AgentCapability<LocalCapable>()
        case .readOnly, .degradedAI:
            return AgentCapability<ReadOnlyCapable>()
        }
    }
}

// Routing function — compile error to call with wrong capability
func routeInference<Cap>(
    _ prompt: String,
    capability: AgentCapability<Cap>
) async throws -> String where Cap == CloudCapable {
    // This function body only accessible for Cloud capability
    return try await cloudLLMClient.generate(prompt)
}
```

***

## 5. Circuit Breaker Implementation Architectures

### Tier 1 — Current (Compromised): Sticky Counter

```swift
// What Epistemos currently has — critical bug:
var failureCount = 0  // Never decrements; 2 failures in Jan + 1 in Mar = breaker opens
func recordFailure() {
    failureCount += 1
    if failureCount >= threshold { state = .open(until: ...) }
}
```

**Problem:** `failureCount` is a lifetime-sticky counter, not a rolling window. Two failures six months ago plus one today opens the breaker. This is incorrect by definition and will fire false positives in production indefinitely.[^10]

### Tier 2 — Rolling Timestamp Window: Correct but Allocating

```swift
actor AgentCircuitBreaker {
    private var failureTimestamps: [ContinuousClock.Instant] = []
    private let rollingWindow: Duration
    private let threshold: Int
    
    private func onFailure() {
        let now = ContinuousClock.now
        failureTimestamps.append(now)
        failureTimestamps = failureTimestamps.filter { now - $0 < rollingWindow }
        if failureTimestamps.count >= threshold { openBreaker() }
    }
}
```

**Assessment:** Correct semantics. Allocates on every `onFailure()` call (array append + filter creates new array). At Epistemos's request rates (<2 req/sec per domain), this is completely acceptable performance-wise. The array never grows beyond `threshold` entries. Good baseline.

### Tier 3 — Fixed Ring Buffer (Bool Array): Zero Allocation on Hot Path

```swift
actor AgentCircuitBreaker {
    private let capacity: Int
    private var results: ContiguousArray<Bool>  // true = failure, false = success
    private var writeIndex: Int = 0
    private var cardinality: Int = 0  // pre-computed failure count
    private var filled: Bool = false  // must be full before tripping
    
    init(capacity: Int = 64, threshold: Double = 0.5) {
        self.capacity = capacity
        self.results = ContiguousArray(repeating: false, count: capacity)
        self.threshold = threshold
    }
    
    private func record(_ isFailure: Bool) {
        let prev = results[writeIndex]
        cardinality += (isFailure ? 1 : 0) - (prev ? 1 : 0)
        results[writeIndex] = isFailure
        writeIndex = (writeIndex + 1) % capacity
        if writeIndex == 0 { filled = true }
    }
    
    private var failureRate: Double {
        guard filled else { return 0.0 }
        return Double(cardinality) / Double(capacity)
    }
}
```

**Assessment:** Zero allocation after initialization. O(1) record and query. Cardinality maintained incrementally (subtract old, add new). Identical semantics to resilience4j's `RingBitBuffer`. The `filled` guard prevents tripping on the first N calls when the buffer is sparse — canonical resilience4j behavior.[^11][^12]

### Tier 4 — UInt64 Bit Ring: True Zero-Allocation, Maximum Compactness

```swift
struct BitRingBuffer: ~Copyable {
    // 128 slots in 2 UInt64 words — stack-allocated, no heap
    private var words: (UInt64, UInt64) = (0, 0)
    private var writeIndex: Int = 0
    private var cardinality: Int = 0
    private var filled: Bool = false
    static let capacity = 128
    
    mutating func record(isFailure: Bool) {
        let wordIndex = writeIndex / 64
        let bitIndex = writeIndex % 64
        let mask: UInt64 = 1 << bitIndex
        
        // Read previous bit value for cardinality delta
        let prev: Bool
        if wordIndex == 0 { prev = (words.0 & mask) != 0 }
        else               { prev = (words.1 & mask) != 0 }
        
        cardinality += (isFailure ? 1 : 0) - (prev ? 1 : 0)
        
        // Set/clear the bit
        if wordIndex == 0 {
            if isFailure { words.0 |= mask } else { words.0 &= ~mask }
        } else {
            if isFailure { words.1 |= mask } else { words.1 &= ~mask }
        }
        
        writeIndex = (writeIndex + 1) % Self.capacity
        if writeIndex == 0 { filled = true }
    }
    
    var failureRate: Double {
        guard filled else { return 0.0 }
        return Double(cardinality) / Double(Self.capacity)
    }
}

// Wrap in actor for Swift concurrency safety
actor AgentCircuitBreaker {
    private var ring = BitRingBuffer()
    private var state: State = .closed
    private var openedAt: ContinuousClock.Instant?
    private var halfOpenSuccesses: Int = 0
    
    let failureThreshold: Double        // e.g., 0.5 = 50% failure rate
    let resetTimeout: Duration          // e.g., .seconds(30)
    let halfOpenRequiredSuccesses: Int  // e.g., 3
    
    func execute<T: Sendable>(_ work: () async throws -> T) async throws -> T {
        switch currentEffectiveState {
        case .open(let retryAt):
            throw CircuitBreakerError.open(retryAt: retryAt)
        case .halfOpen, .closed:
            do {
                let result = try await work()
                ring.record(isFailure: false)
                onSuccess()
                return result
            } catch {
                ring.record(isFailure: true)
                onFailure()
                throw error
            }
        }
    }
    
    private func onSuccess() {
        if case .halfOpen = state {
            halfOpenSuccesses += 1
            if halfOpenSuccesses >= halfOpenRequiredSuccesses {
                state = .closed; halfOpenSuccesses = 0
                Task { await modeMachine.transition(to: .full, reason: .circuitBreakerClosed(domain: domain)) }
            }
        }
    }
    
    private func onFailure() {
        if ring.failureRate >= failureThreshold {
            state = .open; openedAt = .now
            Task { await modeMachine.transition(to: degradedMode, reason: .circuitBreakerOpen(domain: domain)) }
        }
    }
    
    private var currentEffectiveState: State {
        if case .open = state, let at = openedAt, ContinuousClock.now - at >= resetTimeout {
            state = .halfOpen; halfOpenSuccesses = 0
        }
        return state
    }
}
```

### Tier Comparison

| Approach | Alloc/call | Correctness | Complexity | Best for |
|---|---|---|---|---|
| Sticky counter (current) | 0 | ❌ Wrong | Low | Nothing — has a bug |
| Timestamp rolling window | 1 per failure | ✅ Correct | Low | Dev/simple paths |
| Bool ring buffer | 0 | ✅ Correct | Medium | Production default |
| UInt64 bit ring | 0 | ✅ Correct | Medium | Production preferred |
| Hystrix time-bucket | ~5 alloc/sec | ✅ Correct | High | High-volume services |

### Per-Domain Breaker Configuration for Epistemos

Each failure domain has distinct semantics and warrants independent thresholds:

```swift
// cloud inference — slow calls, small failure window
let cloudBreaker = AgentCircuitBreaker(
    capacity: 32,
    failureThreshold: 0.50,
    resetTimeout: .seconds(60),
    halfOpenSuccesses: 2,
    domain: "cloud",
    degradedMode: .degradedCloud
)

// FoundationModels — fast local, but context exhaustion != real failure
let foundationModelsBreaker = AgentCircuitBreaker(
    capacity: 16,
    failureThreshold: 0.75,  // higher tolerance: context errors are expected
    resetTimeout: .seconds(30),
    halfOpenSuccesses: 3,
    domain: "foundationModels",
    degradedMode: .degradedAI,
    ignoredErrors: [LanguageModelError.contextWindowExceeded]  // NOT a trip event
)

// MLX local — thermal pauses look like slowness, not failures
let mlxBreaker = AgentCircuitBreaker(
    capacity: 16,
    failureThreshold: 0.80,
    resetTimeout: .seconds(15),
    halfOpenSuccesses: 2,
    domain: "mlx",
    degradedMode: .degradedAI,
    ignoredErrors: [ThermalError.suspended]  // NOT a trip event
)

// Hermes subprocess — binary: running or dead
let hermesBreaker = AgentCircuitBreaker(
    capacity: 8,
    failureThreshold: 0.50,
    resetTimeout: .seconds(10),
    halfOpenSuccesses: 1,  // If it responded once, it's back
    domain: "hermes",
    degradedMode: .localOnly
)
```

**Critical design rule:** Thermal pauses and timeout-due-to-thermal must NOT count as circuit breaker failures. The breaker should only trip on definitive provider failures — network errors, model errors, subprocess crashes. Wire `ThermalGuard` to suspend callers *before* they reach the breaker.[^21]

***

## 6. Recommended Epistemos Architecture

### What Stays Runtime/Actor-Driven

```
EpistemosModeMachine (actor)
├── receives: CircuitBreakerOpen(domain:)
├── receives: ThermalStateChanged(to:)
├── receives: SupervisorEscalation(childId:)
├── emits: AsyncStream<EpistemosMode> to subscribers
└── enforces: step-at-a-time transition constraints

ThermalGuard (actor)
├── sole authority on ProcessInfo.ThermalState
├── parks: CheckedContinuation<Void, Error> waiters on .serious/.critical
├── drains: parked callers when state recovers to .nominal/.fair
├── transitions: EpistemosModeMachine on state changes
└── cancels: all parked callers with ThermalError on .critical

AppSupervisor (actor)
├── monitors: child actors via structured Task, not polling
├── tracks: restart intensity per child (sliding window)
├── escalates: to EpistemosModeMachine if intensity exhausted
└── no @MainActor isolation — background actor only

AgentCircuitBreaker × 5 domains (actor)
├── execute<T>() generic pattern — callers never touch record* directly
├── UInt64 bit ring buffer — zero allocation
├── N consecutive successes to close from HalfOpen
├── EpistemosModeMachine notification on state change
└── ignoredErrors: [ThermalError, CancellationError]
```

### What Becomes Typestate-Driven

```
PtyHandle<Opened/Closed> (Rust)
├── close() consuming — compiler prevents use-after-close
└── Drop impl auto-closes if not explicitly closed

VaultStore<Open/Closed> (Rust)
├── write() only on Open
└── close() consuming transition

AppleIntelligenceHandle<Active/Recycling/Closed> (Swift phantom)
├── respond() only on Active
├── beginRecycle() consuming Active → Recycling
├── completeRecycle() consuming Recycling → Active
└── checkBudget() only on Active (before respond())

AppBootstrap<Booting/Ready> (Swift phantom, simple)
├── services only accessible on Ready
└── prevents premature access patterns

AgentCapability<Cloud/Local/ReadOnly> (Swift phantom token)
└── minted by EpistemosModeMachine, consumed at routing layer
```

### What Gets Enforced at FFI Boundaries

The `panic = "unwind"` vs. `panic = "abort"` decision is binary for the entire linked binary. The recommended change:

```toml
# agent_core/Cargo.toml — change for the whole binary
[profile.release]
panic = "unwind"  # was "abort"
# Cost: ~5-10% binary size increase for unwind tables
# Benefit: catch_unwind actually works; process no longer aborts on panic
```

Then implement `ffi_guard!` universally:

```rust
macro_rules! ffi_guard {
    ($body:expr) => {{
        match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| $body)) {
            Ok(v) => v,
            Err(payload) => {
                let msg = payload.downcast_ref::<&str>().copied()
                    .or_else(|| payload.downcast_ref::<String>().map(String::as_str))
                    .unwrap_or("unknown panic");
                // Use forget to prevent re-panic from Drop implementations
                std::mem::forget(payload);
                return Err(AgentErrorFFI::AgentError {
                    message: format!("[FFI panic intercepted] {}", msg)
                });
            }
        }
    }};
}

#[uniffi::export(async_runtime = "tokio")]
pub async fn run_agent_session(
    session_id: String,
    objective: String,
    provider_name: String,
    tool_config: ToolConfig,
    agent_config: AgentConfigFFI,
    delegate: Box<dyn AgentEventDelegate>,
) -> Result<AgentResultFFI, AgentErrorFFI> {
    ffi_guard!({
        // Entire body wrapped
        let provider = resolve_provider_for_session(&objective, &provider_name)?;
        let result = run_agent_loop(...).await;
        // ...
        Ok(AgentResultFFI { ... })
    })
}
```

### How Thermal, Breaker, Supervision, and Mode Coordinate

```
ProcessInfo.thermalStateDidChangeNotification
    │
    ▼
ThermalGuard.handleStateChange()
    ├── .serious  → park new inference callers via CheckedContinuation
    │             → EpistemosModeMachine.transition(.degradedAI, .thermalState(.serious))
    ├── .critical → cancel all parked callers with ThermalError
    │             → EpistemosModeMachine.forceDegrade(.localOnly, .thermalState(.critical))
    └── .nominal  → drain parked callers
                  → EpistemosModeMachine.transition(.full, .thermalRecovery)

Inference caller flow:
    Agent request
        │
        ▼
    ThermalGuard.checkAndSuspendIfNeeded()  ← parks here if .serious/.critical
        │
        ▼
    AgentCircuitBreaker.execute {
        try await cloudLLMClient.generate(prompt)  ← only ThermalError-ignored
    }
        │
        ├── success → ring.record(false); onSuccess()
        └── failure → ring.record(true); onFailure()
                        └── if failureRate >= threshold → EpistemosModeMachine.transition(degraded)

AppSupervisor child task fails:
    │
    ▼
    Check restart intensity (sliding window N/T)
        ├── under limit → restart with backoff
        └── over limit  → EpistemosModeMachine.forceDegrade(.readOnly, .supervisorEscalation(childId))
```

***

## 7. Implementation Blueprint

### Phase 1: Foundation Fixes (Do Now, 1–2 Weeks)

These are the only changes that prevent real production failures:

1. **Fix `panic = "unwind"` in `profile.release`** — one-line Cargo.toml change. Enables `catch_unwind` in production.
2. **Add `ffi_guard!` macro to `run_agent_session`** — the highest-priority unprotected FFI entry point.
3. **Fix `AgentCircuitBreaker` sticky counter** — replace with `ContiguousArray<Bool>` ring buffer. No API changes required; drop-in fix.
4. **Fix `checkKnowledgeStore()`** — return `AppBootstrap.shared?.databaseError == nil` instead of `AppBootstrap.shared != nil`.
5. **Wire `ProcessInfo.thermalStateDidChangeNotification` → `EpistemosModeMachine`** — single `NotificationCenter` observer in `RuntimeIssueMonitor` already exists; add the mode transition call.

### Phase 2: Structural Resilience (2–4 Weeks)

6. **Build `ThermalGuard` actor** with `CheckedContinuation` parking. Wire to all inference paths before the circuit breaker.
7. **Split `AgentCircuitBreaker` into 5 per-domain instances** (cloud, foundationModels, mlx, hermes, vault). Add `ignoredErrors` to prevent thermal pauses and context window errors from tripping the cloud breaker.
8. **Upgrade `AgentCircuitBreaker` to `UInt64` bit ring** — zero allocation after this point. Add `halfOpenRequiredSuccesses: Int` parameter. Add `execute<T>()` generic method.
9. **Add `DegradationReason` associated values to `EpistemosHealthMode`** — enables post-mortem causal analysis.
10. **Make `AppSupervisor` event-driven** — migrate from 30-second polling to structured `Task` child monitoring.

### Phase 3: Typestate Islands (4–6 Weeks)

11. **Rust `PtyHandle<Opened/Closed>`** — consuming `close()`, Drop auto-close guard.
12. **Swift `AppleIntelligenceHandle<Active/Recycling>`** — phantom-type wrapper, token budget check before `respond()`, consuming `beginRecycle()`.
13. **Swift `AgentCapability<Cloud/Local/ReadOnly>`** — minted by `EpistemosModeMachine`, consumed at routing layer in `AgentViewModel`.
14. **Swift `AppBootstrap<Booting/Ready>`** — prevent premature service access.

### Phase 4: Advanced Refinements (Prototype Before Committing)

15. **`contextWindowExceeded` catch + recycle** in `AppleIntelligenceService`.
16. **Transcript summarization** before Foundation Models session recycle.
17. **launchd KeepAlive** plist for app restart watchdog (defense against process-level failures).
18. **`ffi_guard!` on all remaining `#[uniffi::export]` entry points** — `decay_memory_nodes`, `gc_memory_nodes`, vault operations.

***

## 8. Code Examples: Complete Patterns

### Swift: Complete `EpistemosModeMachine` with `DegradationReason`

```swift
enum DegradationReason: Sendable, CustomStringConvertible {
    case thermalState(ProcessInfo.ThermalState)
    case circuitBreakerOpen(domain: String)
    case circuitBreakerClosed(domain: String)
    case supervisorEscalation(childId: String)
    case contextWindowExhausted
    case networkUnavailable
    case vaultUnavailable
    case thermalRecovery
    case manual(String)
    
    var description: String { /* ... */ }
}

actor EpistemosModeMachine {
    private(set) var current: EpistemosHealthMode = .full
    private var transitionLog: [(from: EpistemosHealthMode,
                                 to: EpistemosHealthMode,
                                 reason: DegradationReason,
                                 ts: ContinuousClock.Instant)] = []
    private var continuations: [UUID: AsyncStream<EpistemosHealthMode>.Continuation] = [:]
    
    func observe() -> AsyncStream<EpistemosHealthMode> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }
    
    func transition(to next: EpistemosHealthMode, reason: DegradationReason) {
        guard current.isValidStep(to: next) else {
            // Log invalid transition attempt but do not crash
            return
        }
        commitTransition(to: next, reason: reason)
    }
    
    func forceDegrade(to mode: EpistemosHealthMode, reason: DegradationReason) {
        // Bypasses step constraint for supervisor escalations
        commitTransition(to: mode, reason: reason)
    }
    
    private func commitTransition(to next: EpistemosHealthMode, reason: DegradationReason) {
        let prev = current
        current = next
        transitionLog.append((prev, next, reason, .now))
        if transitionLog.count > 200 { transitionLog.removeFirst(50) }
        continuations.values.forEach { $0.yield(next) }
    }
    
    private func removeContinuation(_ id: UUID) { continuations.removeValue(forKey: id) }
}

extension EpistemosHealthMode {
    func isValidStep(to next: EpistemosHealthMode) -> Bool {
        // Degradation: full→degradedAI, full→degradedCloud, full→localOnly,
        //              degradedAI→localOnly, degradedCloud→localOnly, any→readOnly
        // Recovery: step-at-a-time upward
        switch (self, next) {
        case (.full, .degradedAI), (.full, .degradedCloud), (.full, .localOnly),
             (.degradedAI, .localOnly), (.degradedCloud, .localOnly),
             (_, .readOnly):                    return true
        case (.localOnly, .degradedAI), (.localOnly, .degradedCloud),
             (.degradedAI, .full), (.degradedCloud, .full),
             (.readOnly, .localOnly):           return true
        default:                                return self == next  // No-op
        }
    }
}
```

### Rust: Complete `ffi_guard!` Implementation

```rust
/// Standardized FFI panic boundary.
/// In release builds (panic = "unwind"), this catches panics before they
/// unwind past the Swift/UniFFI boundary. In debug builds, same behavior.
/// 
/// NOTE: Requires panic = "unwind" in [profile.release].
/// The abort strategy (panic = "abort") makes this a no-op.
macro_rules! ffi_guard {
    ($body:expr) => {{
        match ::std::panic::catch_unwind(::std::panic::AssertUnwindSafe(|| $body)) {
            Ok(v) => v,
            Err(payload) => {
                let msg = payload
                    .downcast_ref::<&str>()
                    .copied()
                    .or_else(|| payload.downcast_ref::<String>().map(|s| s.as_str()))
                    .unwrap_or("<non-string panic payload>");
                // std::mem::forget prevents the payload's Drop from re-panicking
                ::std::mem::forget(payload);
                eprintln!("[epistemos/ffi] Panic intercepted at FFI boundary: {}", msg);
                return Err(crate::AgentErrorFFI::AgentError {
                    message: format!("[panic intercepted] {}", msg),
                });
            }
        }
    }};
}

/// Async version for #[uniffi::export(async_runtime = "tokio")] functions
/// Wraps the entire async body in a spawn + JoinHandle to catch Tokio task panics
macro_rules! async_ffi_guard {
    ($body:expr) => {{
        match ::tokio::task::spawn(async move { $body }).await {
            Ok(result) => result,
            Err(join_err) if join_err.is_panic() => {
                let payload = join_err.into_panic();
                let msg = payload
                    .downcast_ref::<&str>()
                    .copied()
                    .or_else(|| payload.downcast_ref::<String>().map(|s| s.as_str()))
                    .unwrap_or("<async panic>");
                ::std::mem::forget(payload);
                Err(crate::AgentErrorFFI::AgentError {
                    message: format!("[async panic intercepted] {}", msg),
                })
            }
            Err(join_err) => Err(crate::AgentErrorFFI::AgentError {
                message: format!("[task join error] {}", join_err),
            }),
        }
    }};
}
```

***

## 9. Tradeoff Table

| Approach | Compile-time Safety | Runtime Overhead | SwiftUI Compatible | Cross-Actor | Refactor Cost | Best Use |
|---|---|---|---|---|---|---|
| Full app-wide typestate | Theoretical max | Zero | ❌ Impossible | ❌ ~Copyable limit | Extreme | Nowhere in a SwiftUI app |
| Hybrid typestate islands | High at boundaries | Zero | ✅ (phantom types) | ✅ (phantom types) | Low | FFI handles, session wrappers |
| Actor-only mode machine | Runtime | Actor hop | ✅ | ✅ | Low | All dynamic app state |
| ~Copyable typestate | Maximum local | Zero | ❌ | ❌ | Medium | Local sync FFI lifecycles |
| Simple breaker (current) | None | ~0 | N/A | N/A | Zero | ❌ Has a correctness bug |
| Rolling timestamp breaker | None | O(n) prune | N/A | N/A | Low | Simple paths, <10 req/min |
| Bool ring breaker | None | O(1) | N/A | N/A | Low | Production default |
| UInt64 bit ring breaker | None | O(1) | N/A | N/A | Low | Production preferred |

***

## 10. Red Flags and Anti-Patterns

**Signs of overengineered typestate:**
- Your view models have type parameters: `ContentView<AppBootstrap<Running>>`. Stop immediately.
- You have more than 4 phantom state types on a single wrapper. This signals you're encoding a state machine, not a lifecycle.
- Your typestate types need to conform to `ObservableObject` or `@Observable`. These require `Copyable`. Abandon typestate here.
- You're fighting the compiler to make `~Copyable` types `Sendable`. This is not yet supported and your workarounds are worse than the alternative.

**Signs of misused circuit breakers:**
- One circuit breaker for all inference domains. Context window exhaustion should not trip the cloud breaker. Thermal suspension should not trip the MLX breaker. Per-domain isolation is not optional.
- Using timeout errors to trip the breaker during thermal throttling. Thermal-induced timeouts are not provider failures.
- Opening the breaker for `CancellationError`. User-initiated cancellation is not a failure.
- Closing the circuit on a *single* half-open success. Use 2-3 consecutive successes to prevent re-tripping immediately.

**The false safety trap:**
`catch_unwind` with `panic = "abort"` in `[profile.release]` is not safety — it is documentation of absent safety. The code comments in `bridge.rs` correctly identify this. The fix is not removing `catch_unwind`; the fix is changing `panic = "unwind"`. The comment telling you it's a no-op is better than silence, but shipping it unchanged creates false confidence that panics are "handled".[^22][^23]

**Where people optimize breakers that aren't bottlenecks:**
Bit-level ring buffers have zero performance advantage over bool arrays at <100 req/sec. The advantage is fixed memory footprint and conceptual elegance. If you're spending engineering time on bit manipulation instead of fixing the sticky counter bug, your priorities are inverted.

**Overused typestate — the Rust community's own verdict:**
*"The typestate pattern and state machines are different things and should not be conflated. If you want to transition between states depending on runtime conditions in a loop, it's better not to try to get those state transitions validated by the type system at compile time."* Epistemos's degradation modes are runtime conditions in response to external events. They belong to the mode machine, not the type system.[^19]

***

## 11. Final Recommendation

### Recommended Final Architecture

```
┌─────────────────────────────────────────────────────────┐
│ LAYER A: RUNTIME ACTOR FOUNDATIONS (week 1-2)           │
│                                                          │
│  EpistemosModeMachine actor                              │
│  ThermalGuard actor (CheckedContinuation parking)        │
│  AppSupervisor actor (event-driven, not polling)         │
│  AgentCircuitBreaker × 5 domains                         │
│  (UInt64 ring + execute<T>() + ignoredErrors)            │
│                                                          │
│  ← all dynamic app state lives here                      │
└─────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────┐
│ LAYER B: TYPESTATE ISLANDS (week 3-6)                   │
│                                                          │
│  PtyHandle<Opened/Closed> (Rust, ~Copyable)             │
│  AppleIntelligenceHandle<Active/Recycling> (Swift)       │
│  AppBootstrap<Booting/Ready> (Swift phantom)             │
│  AgentCapability<Cloud/Local/ReadOnly> (Swift phantom)   │
│                                                          │
│  ← static lifecycle correctness at dangerous boundaries  │
└─────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────┐
│ LAYER C: FFI CORRECTNESS (immediate)                    │
│                                                          │
│  panic = "unwind" in [profile.release]                   │
│  ffi_guard! macro on run_agent_session                   │
│  async_ffi_guard! for Tokio-async FFI exports            │
│                                                          │
│  ← process-level safety, without which layers A+B       │
│    can be destroyed by a single Rust panic               │
└─────────────────────────────────────────────────────────┘
```

### Minimum Viable Implementation Plan (1 Sprint)

1. `Cargo.toml`: `panic = "unwind"` in `[profile.release]` ← process abort prevention
2. `bridge.rs`: add `ffi_guard!` macro, wrap `run_agent_session` ← highest-risk entry point
3. `TimeoutUtility.swift`: replace sticky counter with `ContiguousArray<Bool>` ring ← correctness
4. `AppSupervisor.swift`: `checkKnowledgeStore()` returns `databaseError == nil` ← trivial fix
5. Wire `thermalStateDidChangeNotification` → `EpistemosModeMachine.transition()` ← zero new code, uses existing observer

### Elite Version (Later-Stage)

1. Full `ThermalGuard` actor with continuation parking and per-thermal-level behavior
2. `EpistemosModeMachine` with `DegradationReason` associated values and `AsyncStream<EpistemosMode>` subscription
3. Five independent `AgentCircuitBreaker` instances with domain-specific `ignoredErrors`
4. `UInt64` bit ring buffer replacing bool array — identical API, better footprint
5. Rust `PtyHandle<Opened/Closed>` typestate with Drop auto-close
6. Swift `AppleIntelligenceHandle<Active/Recycling>` with token budget gate
7. `AppBootstrap<Booting/Ready>` phantom wrapper preventing premature service access
8. `AgentCapability<Cloud/Local/ReadOnly>` tokens minted by mode machine

### Top 10 Implementation Insights

1. **`~Copyable + Sendable` is unsupported in Swift 6.** Full app-wide typestate is architecturally blocked for any SwiftUI app. Use phantom-type generics for anything that crosses actor boundaries.[^14][^9]
2. **RFC 2282 blocks per-crate panic override.** You cannot set `panic = "unwind"` for `agent_core` alone. Change the entire profile or live with `catch_unwind` being a no-op. The comment in `bridge.rs` is correct about the problem; now fix it.[^1]
3. **`catch_unwind` with `panic = "abort"` is documented UX, not safety.** The code knows it's a no-op. Changing to `panic = "unwind"` costs binary size (~5-10%), not runtime performance.[^23][^22]
4. **Actors are not FIFO.** For state machines requiring ordered cancellation (e.g., `AsyncSequence` state), use `OSAllocatedUnfairLock`, not actors. The mode machine and thermal guard can use actors because they don't require strict ordering — just isolation.[^17]
5. **Thermal pauses must not trip circuit breakers.** Wire `ThermalGuard` to park callers *before* they reach any breaker. A breaker open due to thermal throttling is a false positive that hides real provider health.[^21]
6. **resilience4j's `RingBitBuffer` maintains cardinality incrementally.** `new_cardinality = old_cardinality - old_bit + new_bit`. This eliminates any O(n) scan. Apply the same pattern in Swift with a `cardinality: Int` property updated on every `record()`.[^11]
7. **Half-Open should require N successes, not 1.** Requiring 3 consecutive successes before closing prevents a flapping service from immediately re-opening the breaker after one lucky probe.[^24]
8. **Typestate is for sequences, not dynamic state.** Use typestate where the lifecycle is *fixed* (PTY: open → execute → close) and actors where state responds to *external events* (mode: full → degraded → recovery).[^19]
9. **`execute<T>()` is the canonical circuit breaker API.** Callers should never call `recordFailure()` manually. The `execute<T>()` wrapper owns the guard pattern and prevents the "forgot to record" bug at every call site.[^10]
10. **SquirrelFS is the gold standard for Rust typestate ROI.** They used it for crash-consistency ordering in a file system — multi-step protocol enforcement under failure conditions. If your use case is less critical than crash consistency, evaluate whether the complexity is justified.[^20]

---

## References

1. [2282-profile-dependencies - The Rust RFC Book](https://rust-lang.github.io/rfcs/2282-profile-dependencies.html) - The panic key cannot be specified in an override; only in the top level of a profile. Rust does not ...

2. [Unwinding through FFI after Rust 1.33 - Page 2 - language design](https://internals.rust-lang.org/t/unwinding-through-ffi-after-rust-1-33/9521?page=2) - GCC (like Clang) also provides -fexceptions for ensuring that C++ style unwinding through C (or othe...

3. [FFI is not prod-safe until `c_unwind` RFC stabilizes and we can use it](https://github.com/delta-io/delta-kernel-rs/issues/113) - The c_unwind RFC proposes to address this by allowing exceptions thrown by extern "c-unwind" fn to s...

4. [Typestate - the new Design Pattern in Swift 5.9 - Swiftology](https://swiftology.io/articles/typestate) - Swift 5.9 has introduced Noncopyable types, also known as "move-only" types. A struct or an enum can...

5. [How To Use The Typestate Pattern In Rust | Zero To Mastery](https://zerotomastery.io/blog/rust-typestate-patterns/) - When using the typestate pattern with Rust, the state information gets encoded into the type system....

6. [Consume noncopyable types in Swift - WWDC24 - Videos](https://developer.apple.com/la/videos/play/wwdc2024/10170/) - Discover what copying means in Swift, when you might want to use a noncopyable type, and how value o...

7. [Introduction to Non-Copyable types - Swift with Vincent](https://www.swiftwithvincent.com/blog/introduction-to-non-copyable-types) - Non-Copyable structs and enums is a feature that's been recently added to Swift. It's a very powerfu...

8. [How to Create Type-State Pattern in Rust - OneUptime](https://oneuptime.com/blog/post/2026-01-30-rust-type-state-pattern/view) - Implement the type-state pattern in Rust to encode state transitions in the type system, preventing ...

9. [swift-evolution/proposals/0390-noncopyable-structs-and-enums.md ...](https://github.com/apple/swift-evolution/blob/main/proposals/0390-noncopyable-structs-and-enums.md) - This proposal introduces the concept of noncopyable types (also known as "move-only" types). An inst...

10. [Resilience4j circuit-breaker ring bit buffer size configuration](https://stackoverflow.com/questions/48414306/resilience4j-circuit-breaker-ring-bit-buffer-size-configuration) - Resilience4j provides you with the ability to define a config for each circuit breaker which lets yo...

11. [Circuit Breaker Implementation in Resilience4j - DZone](https://dzone.com/articles/circuit-breaker-implementation-in-resilience4j) - The BitSet uses a long[] array to store the bits. That means that the BitSet only needs an array of ...

12. [resilience4clj-circuitbreaker/README.md at master - GitHub](https://github.com/resilience4clj/resilience4clj-circuitbreaker/blob/master/README.md) - The Ring Bit Buffer has a configurable fixed-size and stores the bits in a long[] array. This saves ...

13. [The Synchronization Framework in Swift 6 - Jacob's Tech Tavern](https://blog.jacobstechtavern.com/p/the-synchronisation-framework) - With Swift 6, noncopyable types now work with generics, allowing Mutex to work with any type. We can...

14. [swift-evolution/proposals/0503-suppressed-associated-types.md at ...](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0503-suppressed-associated-types.md) - This is an expressivity limitation in practice, as it prevents Swift programmers from defining proto...

15. [swift-evolution/proposals/0427-noncopyable-generics.md at main](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0427-noncopyable-generics.md) - The noncopyable types introduced in SE-0390: Noncopyable structs and enums cannot be used with gener...

16. [Swift 6.2 Introduces Approachable Concurrency to Simplify ... - InfoQ](https://www.infoq.com/news/2025/08/swift62-approachable-concurrency/) - This enforces the principle that all functions run on the main actor unless explicitly directed othe...

17. [swift - Why cannot use actor as the type of the state machine in ...](https://stackoverflow.com/questions/78305862/why-cannot-use-actor-as-the-type-of-the-state-machine-in-asyncsequence) - An actor is not well-suited for synchronization of the state machine. When you cancel a sequence, yo...

18. [For future reference but maybe not. - GitHub Gist](https://gist.github.com/bbrk364/6446a522b9aabc50218335d75b1c48c8) - Simplify Your React Component's State With a State Machine ... Discover distributed actors — an exte...

19. [Right way of conditionally transition to a new state - Rust Users Forum](https://users.rust-lang.org/t/right-way-of-conditionally-transition-to-a-new-state/116573) - The main value of typestate is that it statically prevents the calling code from doing a wrong seque...

20. [SquirrelFS: using the Rust compiler to check file-system crash
  consistency](http://arxiv.org/pdf/2406.09649.pdf) - This work introduces a new approach to building crash-safe file systems for
persistent memory. We ex...

21. [Circuit Breaker buffer time interval handling · Issue #547 - GitHub](https://github.com/resilience4j/resilience4j/issues/547) - The sliding time window is implemented with a circular array of N buckets. If the time window size i...

22. [catch_unwind in lets_expect::panic - Rust - Docs.rs](https://docs.rs/lets_expect/latest/lets_expect/panic/fn.catch_unwind.html) - This function only catches unwinding panics, not those that abort the process. If a custom panic hoo...

23. [Catching panic at FFI boundary, iff unwinding enabled - help](https://users.rust-lang.org/t/catching-panic-at-ffi-boundary-iff-unwinding-enabled/14909) - You can use catch_unwind both with the abort and the panicking runtime. It will just never catch and...

24. [How to Use Resilience4j for Circuit Breakers in Spring Boot](https://oneuptime.com/blog/post/2026-02-01-spring-resilience4j-circuit-breaker/view) - A practical guide to implementing circuit breakers, retries, and rate limiters with Resilience4j in ...

