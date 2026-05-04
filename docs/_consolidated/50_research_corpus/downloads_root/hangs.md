# Epistemos Architecture: Deep-Fix Implementation Guide

## Executive Summary

This report covers two parallel bodies of work: (1) immediate, concrete fixes derived from the live system logs showing critical hangs, cdhash mismatches, sandbox violations, and AMFI signature failures; and (2) deep implementation guidance for all nine remaining architecture items. Each section provides root-cause analysis, best-practice implementation patterns, and security hardening specifics drawn from Apple documentation, Swift Evolution proposals, Rust RFC literature, and Erlang/OTP supervisor theory.

***

## Part I: Critical Log Findings & Immediate Fixes

### Finding 1 — Main Thread Hang: 810ms → 31,755ms (Root Cause Confirmed)

The most severe issue in the logs is a **confirmed main thread hang cascade**. The sequence is unmistakable:

```
error  09:07:44.195599  Epistemos  Main thread hang detected: 810ms (threshold: 500ms)
error  09:08:33.227835  Epistemos  Main thread hang detected: 31755ms (consecutive: 2–33)
default 09:08:33.125720  spindump   Epistemos 27004 slow hid response 11.9s
```

The **direct trigger** is the synchronous TCC round-trip for `kTCCServiceAccessibility` followed immediately by the `SCShareableContent` fetch — both happening on the main thread:

```
error  09:07:44.198786  tccd  TCCDProcess...attempted to call TCCAccessRequest 
                               for kTCCServiceAccessibility without the recommended 
                               com.apple.private.tcc.manager.check-by-audit-token entitlement
default 09:07:44.216233  Epistemos  [INFO] +[SCShareableContent 
                               getShareableContentExcludingDesktopWindows:onScreenWindowsOnly:
                               completionHandler:]
```

`SCShareableContent` is known to sometimes block indefinitely when `replayd` is in a bad state. The completion handler is being invoked from the main thread, blocking HID event processing for ~32 seconds.[^1][^2]

**Immediate fix — move SCShareableContent off-main completely:**

```swift
actor ScreenCaptureService {
    func fetchShareableContent() async throws -> SCShareableContent {
        return try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true
        )
    }
}
```

Never call `SCShareableContent` APIs from a `@MainActor`-isolated context. Use a non-isolated actor or a `Task.detached` block to ensure the await suspends off the main executor.[^3][^4]

**Secondary hardening — replayd watchdog:**

The `SCShareableContent` hang correlates with `replayd` being in a broken state. Add a `withTimeout` wrapper and fallback:[^2]

```swift
func fetchWithTimeout() async throws -> SCShareableContent {
    try await withThrowingTaskGroup(of: SCShareableContent.self) { group in
        group.addTask { try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true) }
        group.addTask {
            try await Task.sleep(for: .seconds(5))
            throw CaptureError.timeout
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

If this times out, kick `replayd` via `launchctl kickstart -k gui/$(id -u)/com.apple.replayd`.[^2]

***

### Finding 2 — cdhash Mismatch & TCC Identity Failure

```
error  09:08:32.756063  tccd  cdhash mismatch file:Epistemos.app
                               bytes 0x821cfc44... != 0x96fb1e56...
error  09:08:32.756603  tccd  IDENTITY_ATTRIBUTION: Failed to copy signing info 
                               for 27004 — -67034
```

This occurs because Xcode **rebuilt the binary while the app was still running** — the on-disk code hash changed but the running process retained the old identity. TCC's static code check fails, causing `replayd` to be denied `file-read-data` on the app bundle (`Sandbox: replayd(27000) deny(1) file-read-data Epistemos.app`).[^5]

**Fix:** Always fully quit the running app before rebuilding. In CI/CD pipelines, add a pre-build step:

```bash
osascript -e 'tell app "Epistemos" to quit'
sleep 1
xcodebuild ...
```

For production: ensure `NSUpdateDynamicCodes` is set and that the app uses hardened runtime (`com.apple.security.cs.allow-jit` only if needed).

***

### Finding 3 — AMFI CT Signature Issue: uniffi-bindgen

```
default 09:09:50.667968  kernel  AMFI: ...omega-mcp/target/aarch64-apple-darwin/debug/
                                        uniffi-bindgen has no CMS blob?
default 09:09:50.667975  kernel  AMFI: ...uniffi-bindgen Unrecoverable CT signature issue
```

The `uniffi-bindgen` binary spawned from the Rust FFI layer is **unsigned** and has no CMS signature blob. AMFI (Apple Mobile File Integrity) rejects it, which causes `ASP Unable to apply provenance sandbox` for all worker PIDs 27869–27878. This means every FFI subprocess runs outside the app's sandbox provenance chain.[^5]

**Fix:**

```bash
# Add to cargo build pipeline
codesign --force --sign "Developer ID Application: YOUR_TEAM" \
  --options runtime \
  target/aarch64-apple-darwin/debug/uniffi-bindgen

# Or for development, sign ad-hoc:
codesign --force --sign - target/aarch64-apple-darwin/debug/uniffi-bindgen
```

For CI, add a post-build script that recursively signs all binaries under `omega-mcp/target/`:

```bash
find omega-mcp/target -type f -perm +111 | xargs -I{} codesign --force --sign - {}
```

***

### Finding 4 — Repeated HTTP 404 Heartbeat Requests

```
Epistemos  Task <BDAAA496>.<589> summary: {response_status=404, connection=4, reused=1}
Epistemos  Task <DAEEC09E>.<3>  summary: {response_status=404, connection=1, reused=1}
```

Two separate connections (C1 and C4) are making requests every ~30 seconds that consistently return 404. These are likely heartbeat or model-health poll endpoints that don't exist yet. The 19-byte request body and 57-byte response suggest a simple ping endpoint is expected but not implemented.

**Fix:** Implement the endpoint, or add a circuit breaker that backs off after 3 consecutive 404s with exponential backoff (30s → 60s → 120s → stop).

***

### Finding 5 — NSInputAnalytics didInsertText Without Session

```
error  09:07:51.546570  Epistemos  [NSInputAnalytics didInsertText:] called without session beginning
```

Text is being inserted into a text field before `NSTextInputContext`'s analytics session is properly initialized. This means the text input lifecycle `textInputContextShouldBeginSession:` / `beginSession` is being bypassed.

**Fix:** Ensure `NSTextInputContext` is properly activated before the view accepts first responder, or suppress this by calling `[NSApp _runModalSessionForWindow:]` / ensuring `NSTextField` is properly installed in the responder chain before first keystroke.

***

## Part II: Architecture Implementation — Nine Items

***

### Item 1: Five-Actor Domain Map Refactor

The proposed five-actor domain matches the principle of **single-responsibility actors**, where each actor owns a bounded context and communicates via typed message passing.[^6]

**Architecture:**

```
AppSupervisor
├── KnowledgeStoreActor   — owns vector DB, document chunks, semantic index
├── InferenceOrchestrator — owns Foundation Models sessions, prompt routing
├── VaultActor            — owns SecureEnclave keys, secret material
├── NetworkGateway        — owns all URLSession connections, HTTP retry logic  
└── TelemetryActor        — owns metrics, keystroke timing, crash telemetry
```

**Swift implementation pattern:**

```swift
// Each actor declares its own executor for affinity
actor KnowledgeStoreActor {
    nonisolated let unownedExecutor: UnownedSerialExecutor
    
    init(executor: KnowledgeStoreExecutor) {
        self.unownedExecutor = executor.asUnownedSerialExecutor()
    }
    
    func query(_ embedding: [Float], topK: Int) async throws -> [DocumentChunk] { ... }
    func index(_ document: Document) async throws { ... }
}

actor InferenceOrchestrator {
    private var session: LanguageModelSession?
    private weak var knowledgeStore: KnowledgeStoreActor?
    private weak var vault: VaultActor?
    
    func respond(to prompt: String) async throws -> String {
        guard let session else { throw InferenceError.notReady }
        return try await session.respond(to: prompt).content
    }
}
```

**Inter-actor communication:** Pass immutable value types (structs) between actors. Never share mutable reference types across actor boundaries. Use `AsyncStream` for push-based event propagation from TelemetryActor to AppSupervisor.[^7]

**Distributed actor note:** Xcode 16.3 fixed a compiler crash affecting class-based `DistributedActorSystem` conformances in release mode. If using distributed actors, prefer `struct`-based implementations or mark affected methods `final`.[^7]

***

### Item 2: Custom SerialExecutor for SCStream/AVFoundation

Swift SE-0424 introduced formal `SerialExecutor` protocol support for custom isolation checking. AVFoundation APIs are not `@MainActor`-safe and must run on a dedicated serial queue.[^8][^3]

**Implementation:**

```swift
final class AVFoundationExecutor: SerialExecutor {
    private let queue = DispatchQueue(
        label: "com.epistemos.avfoundation",
        qos: .userInitiated,
        autoreleaseFrequency: .workItem
    )
    
    func enqueue(_ job: consuming ExecutorJob) {
        let unownedJob = UnownedJob(job)
        queue.async { unownedJob.runSynchronously(on: self.asUnownedSerialExecutor()) }
    }
    
    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }
    
    // SE-0424: custom isolation assertion
    func checkIsolated() {
        dispatchPrecondition(condition: .onQueue(queue))
    }
}

actor ScreenCaptureActor {
    nonisolated let unownedExecutor: UnownedSerialExecutor
    private var stream: SCStream?
    private var currentContent: SCShareableContent?
    
    init() {
        let exec = AVFoundationExecutor()
        self.unownedExecutor = exec.asUnownedSerialExecutor()
    }
    
    func startCapture() async throws {
        // Now guaranteed to run on AVFoundationExecutor queue, never main thread
        currentContent = try await SCShareableContent
            .excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let filter = SCContentFilter(/* ... */)
        stream = SCStream(filter: filter, configuration: config, delegate: self)
        try await stream!.startCapture()
    }
}
```

The `sampleHandlerQueue` parameter for `addStreamOutput` should also receive the AVFoundation executor's queue to maintain consistency and prevent cross-queue races.[^9]

***

### Item 3: Vault Import Off Main Thread (2.5s Hang Fix)

The logs already confirm the pattern: `kTCCServiceAccessibility` was being checked synchronously on the main thread. SecItem APIs (`SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`) are **synchronous blocking calls** and must never run on the main thread.[^3]

**VaultActor — fully off-main design:**

```swift
actor VaultActor {
    private let executor: VaultExecutor
    nonisolated let unownedExecutor: UnownedSerialExecutor
    
    init() {
        let exec = VaultExecutor()  // dedicated low-priority background queue
        self.executor = exec
        self.unownedExecutor = exec.asUnownedSerialExecutor()
    }
    
    // All SecItem calls are synchronous — actor isolation keeps them off main
    func importKey(_ data: Data, tag: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw VaultError.importFailed(status)
        }
    }
    
    func retrieveKey(tag: String) async throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            throw VaultError.notFound(status)
        }
        return data
    }
}
```

**SecureEnclave operations** (key generation, signing) are even slower — always use `LocalAuthentication` with `LAContext` and perform all SE operations within the VaultActor's executor. Never `await` on a `@MainActor`-isolated function that calls into SE.[^4]

***

### Item 4: AppSupervisor with OTP-Style Restart Strategies

Erlang/OTP defines three principal restart strategies:[^10][^11]

| Strategy | Behavior | Use Case |
|----------|----------|----------|
| `one_for_one` | Restart only the failed child | Independent actors (NetworkGateway, TelemetryActor) |
| `one_for_all` | Restart all children | Mutually dependent actors (InferenceOrchestrator + KnowledgeStoreActor) |
| `rest_for_one` | Restart failed + all started after it | Ordered dependency chains (Vault → Inference → Network) |

OTP also enforces **restart intensity limits** — if more than `maxRestarts` occur within `maxSeconds`, the supervisor itself terminates and escalates.[^10]

**Swift implementation:**

```swift
enum RestartStrategy {
    case oneForOne
    case oneForAll
    case restForOne
}

struct SupervisionSpec {
    let strategy: RestartStrategy
    let maxRestarts: Int    // default: 3
    let maxSeconds: Double  // default: 5.0
    let backoff: BackoffPolicy
}

enum BackoffPolicy {
    case immediate
    case linear(step: Duration)
    case exponential(base: Duration, maxDelay: Duration)
}

actor AppSupervisor {
    private var children: [ActorID: SupervisedChild] = [:]
    private var restartHistory: [ActorID: [Date]] = [:]
    private let spec: SupervisionSpec
    
    func supervise<A: RestartableActor>(_ factory: @escaping () async -> A, 
                                        id: ActorID) {
        children[id] = SupervisedChild(factory: factory)
        restartHistory[id] = []
    }
    
    func childTerminated(id: ActorID, reason: TerminationReason) async {
        // Prune old restart history outside the window
        let now = Date()
        restartHistory[id] = (restartHistory[id] ?? [])
            .filter { now.timeIntervalSince($0) < spec.maxSeconds }
        
        // Check intensity limit
        guard (restartHistory[id]?.count ?? 0) < spec.maxRestarts else {
            await escalate(id: id)  // give up, notify parent supervisor
            return
        }
        
        restartHistory[id]?.append(now)
        
        switch spec.strategy {
        case .oneForOne:
            await restartChild(id: id)
        case .oneForAll:
            for childId in children.keys { await restartChild(id: childId) }
        case .restForOne:
            let ordered = children.keys.sorted()  // insertion-order dependency
            if let idx = ordered.firstIndex(of: id) {
                for childId in ordered[idx...] { await restartChild(id: childId) }
            }
        }
    }
    
    private func restartChild(id: ActorID) async {
        let delay = spec.backoff.delay(attempt: restartHistory[id]?.count ?? 0)
        if delay > .zero { try? await Task.sleep(for: delay) }
        await children[id]?.restart()
    }
}
```

Apply `rest_for_one` to the dependency chain **Vault → InferenceOrchestrator → NetworkGateway**: if VaultActor crashes, the downstream actors holding vault-derived keys must also restart. Apply `one_for_one` to TelemetryActor and KnowledgeStoreActor since they are independent.[^12]

***

### Item 5: EpistemosMode Degradation State Machine

The logs confirm conditions that should trigger degradation transitions:
- `dasd: CPU Usage Policy … Observed: 95.00` — high CPU, model should throttle
- `replayd sandbox deny` — screen capture unavailable, SCStream features should degrade
- Repeated 404s — network endpoints down, network-dependent features should degrade

**State machine:**

```swift
enum EpistemosMode: Int, Comparable, CaseIterable {
    case offline    = 0  // No inference, no capture, no network
    case minimal    = 1  // Local KV only, no model
    case degraded   = 2  // Local model only, no screen capture
    case standard   = 3  // All features except non-critical
    case full       = 4  // Everything enabled
    
    static func < (lhs: EpistemosMode, rhs: EpistemosMode) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum DegradationTrigger {
    case cpuPressure(percent: Double)
    case modelUnavailable
    case screenCapturePermissionDenied
    case networkEndpointDown(consecutiveFailures: Int)
    case vaultUnlockFailed
    case replaydCrashed
}

actor EpistemosStateMachine {
    private(set) var currentMode: EpistemosMode = .full
    private var degradationReasons: Set<DegradationTrigger> = []
    
    func process(_ trigger: DegradationTrigger) async {
        let requiredMode = requiredModeForTrigger(trigger)
        if requiredMode < currentMode {
            let previous = currentMode
            currentMode = requiredMode
            await notifyModeChange(from: previous, to: currentMode, reason: trigger)
        }
    }
    
    func recover(from trigger: DegradationTrigger) async {
        degradationReasons.remove(trigger)
        let targetMode = degradationReasons.isEmpty ? .full : 
                         degradationReasons.map { requiredModeForTrigger($0) }.min()!
        if targetMode > currentMode {
            let previous = currentMode
            currentMode = targetMode
            await notifyModeChange(from: previous, to: currentMode, reason: nil)
        }
    }
    
    private func requiredModeForTrigger(_ trigger: DegradationTrigger) -> EpistemosMode {
        switch trigger {
        case .cpuPressure(let p) where p > 90: return .degraded
        case .cpuPressure: return .standard
        case .modelUnavailable: return .minimal
        case .screenCapturePermissionDenied: return .degraded
        case .networkEndpointDown(let n) where n > 5: return .minimal
        case .networkEndpointDown: return .degraded
        case .vaultUnlockFailed: return .offline
        case .replaydCrashed: return .degraded
        default: return .standard
        }
    }
}
```

Wire `dasd` CPU observations (exposed via `ProcessInfo.thermalState` and `os_proc_available_memory`) into `EpistemosStateMachine.process(.cpuPressure(percent:))`.[^13]

***

### Item 6: Foundation Models Session 10-Minute Recycle

Apple's `LanguageModelSession` accumulates context in its transcript, which grows toward the 4096-token combined input/output limit. A 10-minute recycle keeps the context window fresh and prevents silent truncation.[^14][^15]

**Implementation:**

```swift
actor InferenceOrchestrator {
    private var session: LanguageModelSession?
    private var sessionCreatedAt: Date = .distantPast
    private var savedTranscript: Transcript?
    private let recycleInterval: TimeInterval = 600  // 10 minutes
    
    private func activeSession() async throws -> LanguageModelSession {
        let now = Date()
        if let s = session, now.timeIntervalSince(sessionCreatedAt) < recycleInterval {
            return s
        }
        return try await recycleSession()
    }
    
    private func recycleSession() async throws -> LanguageModelSession {
        // Capture transcript before closing old session
        if let old = session {
            savedTranscript = old.transcript
        }
        
        let newSession: LanguageModelSession
        if let transcript = savedTranscript {
            // Restore multi-turn history into new session
            newSession = LanguageModelSession(transcript: transcript)
        } else {
            newSession = LanguageModelSession(instructions: systemInstructions)
        }
        
        // Pre-warm for better first-response latency
        _ = try? await newSession.prewarm()
        
        session = newSession
        sessionCreatedAt = Date()
        return newSession
    }
    
    func respond(to prompt: String) async throws -> String {
        let s = try await activeSession()
        return try await s.respond(to: prompt).content
    }
}
```

**Token budget awareness:** Before each request, estimate token usage (`prompt.count / 4` as rough proxy). If remaining budget < 512 tokens, force an early recycle.[^16]

***

### Item 7: catch_unwind on Rust FFI Entry Points (Defense-in-Depth)

Without `catch_unwind`, a Rust `panic!` propagating across an FFI boundary into Swift/ObjC is **undefined behavior**. The AMFI CT signature issue in the logs (`uniffi-bindgen Unrecoverable CT signature issue`) indicates FFI subprocesses are running without protection.[^17][^18][^19]

**Pattern for every `extern "C"` entry point:**

```rust
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::ffi::c_int;

// Error codes passed back over FFI boundary
const EPISTEMOS_OK: c_int = 0;
const EPISTEMOS_ERR_PANIC: c_int = -1;
const EPISTEMOS_ERR_INFERENCE: c_int = -2;

#[no_mangle]
pub extern "C" fn epistemos_run_inference(
    input_ptr: *const u8,
    input_len: usize,
    output_ptr: *mut u8,
    output_len: *mut usize,
) -> c_int {
    let result = catch_unwind(AssertUnwindSafe(|| {
        unsafe {
            let input = std::slice::from_raw_parts(input_ptr, input_len);
            // ... actual inference work ...
            EPISTEMOS_OK
        }
    }));
    
    match result {
        Ok(code) => code,
        Err(panic_payload) => {
            // Log the panic without unwinding into Swift
            eprintln!("[EPISTEMOS FFI] Panic caught at boundary: {:?}", 
                      panic_payload.downcast_ref::<&str>().unwrap_or(&"unknown"));
            EPISTEMOS_ERR_PANIC
        }
    }
}
```

**Cargo.toml settings:**

```toml
[profile.release]
panic = "unwind"        # Required for catch_unwind to work
# Do NOT use panic = "abort" if you want catch_unwind

[profile.debug]
panic = "unwind"
```

**Important caveats from RFC 2945:**[^19]
- Use `"C-unwind"` ABI when calling C code that may itself unwind (e.g., C++ exceptions)
- `catch_unwind` does **not** catch signals (SIGSEGV, SIGBUS) — those still crash
- Null pointer dereferences in unsafe blocks are signals, not panics — add null checks before all `unsafe` pointer operations

**Macro to reduce boilerplate:**

```rust
macro_rules! ffi_guard {
    ($body:expr) => {
        match catch_unwind(AssertUnwindSafe(|| $body)) {
            Ok(result) => result,
            Err(_) => EPISTEMOS_ERR_PANIC,
        }
    }
}

#[no_mangle]
pub extern "C" fn epistemos_tokenize(/* ... */) -> c_int {
    ffi_guard!({
        // ... safe to panic here, it won't cross FFI boundary
        EPISTEMOS_OK
    })
}
```

***

### Item 8: Input Telemetry Actor (Keystroke Timing) — Security-First Design

Keystroke timing is a **sensitive privacy signal**. Research demonstrates that inter-keystroke timings alone can recover passwords from SSH sessions. The macOS logs confirm that `kTCCServiceAccessibility` is being requested without the proper audit-token entitlement — a sign that input monitoring integration needs to be redesigned.[^20][^21]

**TCC entitlement requirements:**

```xml
<!-- Entitlements.plist -->
<key>com.apple.security.input-monitoring</key>
<true/>
```

The app must also explicitly appear in System Settings → Privacy & Security → Input Monitoring.[^22][^23]

**Privacy-hardened TelemetryActor:**

```swift
actor TelemetryActor {
    // Timing data is NEVER stored raw — always bucketed + noised
    private var keystrokeBuffer: [BucketedTiming] = []
    private let noiseGenerator = GaussianNoise(sigma: 25.0)  // ms
    
    struct BucketedTiming {
        // Bucket to nearest 50ms to prevent fine-grained timing attacks
        let bucketedIntervalMs: Int
        let sessionID: UUID  // not linked to user identity
        
        init(rawIntervalMs: Double, session: UUID) {
            // Round to 50ms bucket + add Gaussian noise
            let noised = rawIntervalMs + Double.random(in: -12.5...12.5)
            self.bucketedIntervalMs = (Int(noised) / 50) * 50
            self.sessionID = session
        }
    }
    
    func recordKeystroke(interval rawMs: Double, session: UUID) {
        let bucketed = BucketedTiming(rawIntervalMs: rawMs, session: session)
        keystrokeBuffer.append(bucketed)
        // Never persist timing data longer than the session
        if keystrokeBuffer.count > 1000 { keystrokeBuffer.removeFirst() }
    }
    
    // Aggregate only — never expose raw timings
    func typingRhythmMetrics() -> TypingMetrics {
        let intervals = keystrokeBuffer.map { Double($0.bucketedIntervalMs) }
        return TypingMetrics(
            meanIntervalMs: intervals.average,
            stdDevMs: intervals.standardDeviation,
            sampleCount: intervals.count
        )
    }
}
```

**CGEvent tap — proper entitlement-based installation:**

```swift
// Must be called after TCC permission is granted
func installEventTap() {
    guard AXIsProcessTrustedWithOptions(
        [kAXTrustedCheckOptionPrompt: false] as CFDictionary
    ) else {
        Task { await stateMachine.process(.screenCapturePermissionDenied) }
        return
    }
    
    let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .listenOnly,  // NEVER .defaultTap — never intercept, only observe
        eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
        callback: keystrokeCallback,
        userInfo: nil
    )
    // ...
}
```

Use `.listenOnly` — never `.defaultTap` or `.annotatedSession`. The telemetry actor should only observe, never modify, intercept, or block events.[^24]

***

### Item 9: Durable Execution Engine in Rust

Durable execution means **every step is journaled before execution**, so crashes result in exactly-once replay, not lost work. The Restate project demonstrates this can be built as a self-contained Rust binary achieving 94,286 actions/second at p50 116ms.[^25][^26]

**Core design — journal-first execution:**

```rust
use std::collections::HashMap;
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Clone, Debug)]
enum JournalEntry {
    StepStarted { step_id: StepId, input: serde_json::Value },
    StepCompleted { step_id: StepId, output: serde_json::Value },
    StepFailed { step_id: StepId, error: String, attempt: u32 },
    WorkflowCompleted { workflow_id: WorkflowId, result: serde_json::Value },
}

struct DurableContext {
    journal: Vec<JournalEntry>,
    completed: HashMap<StepId, serde_json::Value>,
    storage: Box<dyn DurableStorage>,
}

impl DurableContext {
    // The key abstraction: run only if not already journaled
    async fn run_step<F, Fut, R>(
        &mut self,
        step_id: StepId,
        f: F,
    ) -> Result<R, ExecutionError>
    where
        F: FnOnce() -> Fut,
        Fut: Future<Output = Result<R, ExecutionError>>,
        R: Serialize + for<'de> Deserialize<'de>,
    {
        // Check journal: if already completed, return cached result
        if let Some(cached) = self.completed.get(&step_id) {
            return Ok(serde_json::from_value(cached.clone())?);
        }
        
        // Journal the start (durably)
        let entry = JournalEntry::StepStarted { 
            step_id: step_id.clone(), 
            input: serde_json::json!(null) 
        };
        self.storage.append(&entry).await?;
        
        // Execute with catch_unwind for FFI safety
        let result = catch_unwind(AssertUnwindSafe(|| {
            tokio::runtime::Handle::current().block_on(f())
        }));
        
        match result {
            Ok(Ok(output)) => {
                let serialized = serde_json::to_value(&output)?;
                self.storage.append(&JournalEntry::StepCompleted {
                    step_id: step_id.clone(),
                    output: serialized.clone(),
                }).await?;
                self.completed.insert(step_id, serialized);
                Ok(output)
            }
            Ok(Err(e)) | Err(_) => {
                self.storage.append(&JournalEntry::StepFailed {
                    step_id,
                    error: format!("{:?}", e),
                    attempt: 1,
                }).await?;
                Err(e.unwrap_or(ExecutionError::Panic))
            }
        }
    }
}
```

**Storage backend selection:**

| Backend | Use Case | Durability |
|---------|----------|------------|
| SQLite (rusqlite) | Single-node, local-first | WAL mode = crash-safe |
| Sled | Embedded KV, async-friendly | ACID with log-structured merge |
| Restate (open source) | Distributed, multi-node | Event-sourced, leader-elected |

For Epistemos's local-first architecture, SQLite with WAL mode is the right default:

```rust
// Enable WAL for crash safety
conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;")?;
```

**Retry policy with exponential backoff:**

```rust
struct RetryPolicy {
    max_attempts: u32,
    base_delay: Duration,
    max_delay: Duration,
    backoff_factor: f64,
}

impl RetryPolicy {
    fn delay_for_attempt(&self, attempt: u32) -> Duration {
        let secs = self.base_delay.as_secs_f64() 
                   * self.backoff_factor.powi(attempt as i32);
        Duration::from_secs_f64(secs.min(self.max_delay.as_secs_f64()))
    }
}
```

***

## Security Hardening Summary

The following cross-cutting security controls address multiple findings simultaneously:

### Hardened Runtime & Entitlements

```xml
<!-- Epistemos.entitlements -->
<key>com.apple.security.app-sandbox</key><true/>
<key>com.apple.security.cs.allow-unsigned-executable-memory</key><false/>
<key>com.apple.security.cs.disable-library-validation</key><false/>
<!-- Only add if MLX requires it: -->
<key>com.apple.security.cs.allow-jit</key><false/>
```

### Rust Binary Signing Pipeline

Every binary produced under `omega-mcp/target/` must be signed before being spawned. AMFI will block unsigned binaries from inheriting the app's sandbox provenance. Add to `build.rs`:[^5]

```rust
// build.rs — post-build code signing for dev builds
#[cfg(target_os = "macos")]
fn main() {
    println!("cargo:rerun-if-changed=src/");
    // Codesign the output binary after build
    let out = std::env::var("OUT_DIR").unwrap();
    let _ = std::process::Command::new("codesign")
        .args(["--force", "--sign", "-", &format!("{}/../../epistemos_ffi", out)])
        .status();
}
```

### TCC Permission Pre-Flight

Check TCC status before blocking calls:

```swift
func preflight() async -> PermissionStatus {
    // Check screen recording without prompting
    let screenOK = CGPreflightScreenCaptureAccess()
    // Check accessibility
    let accessOK = AXIsProcessTrustedWithOptions(
        [kAXTrustedCheckOptionPrompt: false] as CFDictionary
    )
    return PermissionStatus(screenCapture: screenOK, accessibility: accessOK)
}
```

If permissions are not granted, transition to `.degraded` mode immediately rather than attempting a synchronous TCC round-trip on the main thread.

### Actor Isolation Security Boundaries

- **VaultActor** must never send secret material as `Sendable` across actor boundaries — wrap in `SecretBox<T>` that zeroes memory on `deinit`
- **TelemetryActor** must never hold a reference to `VaultActor` — data flows one-way: App → Telemetry, never Telemetry → Vault
- **NetworkGateway** must enforce certificate pinning and not share URLSession instances with VaultActor's background requests

***

## Implementation Priority Order

Given the log evidence, implement in this order:

1. **SCShareableContent off-main** — fixes the 31s hang immediately
2. **AMFI/codesign for uniffi-bindgen** — unblocks FFI sandbox inheritance
3. **VaultActor off-main** — eliminates the 2.5s vault hang
4. **catch_unwind on all FFI entry points** — prevents undefined behavior from panics
5. **AppSupervisor** — provides fault isolation for actors 1–3
6. **EpistemosMode state machine** — responds to the CPU/permission/network conditions already observed in logs
7. **Five-actor domain refactor** — structural foundation enabling items 5–9
8. **Foundation Models session recycle** — prevents context window exhaustion
9. **Input telemetry actor** — privacy-hardened keystroke observations
10. **Durable execution engine** — replaces ad-hoc retry logic in NetworkGateway

---

## References

1. [await SCShareableContent never returns or throws error](https://stackoverflow.com/questions/75826795/await-scshareablecontent-never-returns-or-throws-error) - Doing one of the following helps: restart macOS; log user out and in; kill WindowServer (not recomme...

2. [nonstrict-hq/SCShareableContent-hangs-sample](https://github.com/nonstrict-hq/SCShareableContent-hangs-sample) - Example project that sometimes(?) hangs when accessing SCSharableContent.current. The await simply n...

3. [Calling into AVFoundation on a background thread interferes with ...](https://stackoverflow.com/questions/77763118/calling-into-avfoundation-on-a-background-thread-interferes-with-swiftui-animati) - I have verified that all the AVFoundation calls I make are on a background thread. I'm at a loss for...

4. [Swift Concurrency: Running Async Code on Background Thread](https://www.linkedin.com/posts/hanushkasuren_iosdev-swift-swiftconcurrency-activity-7418659723115368448-N--s) - ... async work runs on the main thread. So leave async code in the background and only hop back to M...

5. [Resolving the Invalid Signature binary rejection - Apple Developer](https://developer.apple.com/library/archive/qa/qa1510/_index.html) - If you are certain your code signing settings are correct, choose "Clean All" in Xcode, delete the "...

6. [Actor Capabilities for Message Ordering (Extended Version)](https://arxiv.org/pdf/2502.07958.pdf) - Actor systems are a flexible model of concurrent and distributed programming,
which are efficiently ...

7. [Swift Distributed Actors - DEV Community](https://dev.to/maxnxi/swift-distributed-actors-4168) - Let's examine the compiler crash affecting class-based implementations of the distributed actor syst...

8. [Custom isolation checking for SerialExecutor - GitHub](https://github.com/apple/swift-evolution/blob/main/proposals/0424-custom-isolation-checking-for-serialexecutor.md) - The Swift concurrency runtime dynamically tracks the current executor of a running task in thread-lo...

9. [ScreenCaptureKit failing to capture the entire Display - Federico Terzi](https://federicoterzi.com/blog/screencapturekit-failing-to-capture-the-entire-display/) - My goal was simple: creating the simplest possible program to capture the entire display and analyse...

10. [Supervisor Behaviour — Erlang System Documentation v28.4.1](https://www.erlang.org/doc/system/sup_princ.html) - A supervisor is responsible for starting, stopping, and monitoring its child processes. The basic id...

11. [OTP Supervisors - Elixir School](https://elixirschool.com/en/lessons/advanced/otp_supervisors) - These supervisors enable us to create fault-tolerant applications by automatically restarting child ...

12. [Guidelines for Supervision trees and setting restart intensity ...](https://elixirforum.com/t/guidelines-for-supervision-trees-and-setting-restart-intensity-parameters/15038) - My personal “best practice” approach is to write applications such that no dependent applications ar...

13. [Graceful Degradation Patterns - PraisonAI](https://docs.praison.ai/docs/best-practices/graceful-degradation) - Graceful Degradation Patterns. Copy page. Design patterns for building resilient multi-agent systems...

14. [Exploring the Foundation Models framework - Create with Swift](https://www.createwithswift.com/exploring-the-foundation-models-framework/) - In this article, we'll dive into the new Foundation Models API to use the built-in language models: ...

15. [Getting Started with Apple's Foundation Models - Artem Novichkov](https://artemnovichkov.com/blog/getting-started-with-apple-foundation-models) - At WWDC 2025, Apple introduced Foundation Models — a new way to integrate AI capabilities directly i...

16. [The Ultimate Guide To The Foundation Models Framework](https://azamsharp.com/2025/06/18/the-ultimate-guide-to-the-foundation-models-framework.html) - In this article, we will walk through how to get started with Apple's Foundation Models framework an...

17. [Catching panic at FFI boundary, iff unwinding enabled - help](https://users.rust-lang.org/t/catching-panic-at-ffi-boundary-iff-unwinding-enabled/14909) - You can use catch_unwind both with the abort and the panicking runtime. It will just never catch and...

18. [Unwinding through FFI after Rust 1.33 - language design](https://internals.rust-lang.org/t/unwinding-through-ffi-after-rust-1-33/9521) - I'm very sad that Rust is unable to use libjpeg and libpng with graceful error handling any more, du...

19. [2945-c-unwind-abi - The Rust RFC Book](https://rust-lang.github.io/rfcs/2945-c-unwind-abi.html) - We introduce a new ABI string, "C-unwind", to enable unwinding from other languages (such as C++) in...

20. [SSH Keystroke Timing Attack Vulnerability | Sam Bent posted on the ...](https://www.linkedin.com/posts/sam-bent_side-channel-attacks-on-ssh-through-keystroke-activity-7411390541030039552-2OmB) - Side-channel attacks on SSH through keystroke timing analysis. "We show that timing data alone can b...

21. [[PDF] Eliminating Software-Based Keystroke Timing Side-Channel Attacks](https://www.ndss-symposium.org/wp-content/uploads/2018/02/ndss2018_04B-1_Schwarz_paper.pdf) - We cover both the general case where an attacker can only obtain a single trace, and the case of pas...

22. [Control access to input monitoring on Mac - Apple Support](https://support.apple.com/guide/mac-help/control-access-to-input-monitoring-on-mac-mchl4cedafb6/mac) - Choose Apple menu > System Settings, then click Privacy & Security in the sidebar. (You may need to ...

23. [Getting Keystroke Running on macOS: Gatekeeper Woes and Fixes](https://dev.to/ammad155/getting-keystroke-running-on-macos-gatekeeper-woes-and-fixes-1646) - I went to System Settings → Privacy & Security → Accessibility, and sure enough, Keystroke wasn't li...

24. [Behavior Analytics & Native Telemetry That Actually Works - YouTube](https://www.youtube.com/watch?v=dGftyuZUOSE) - Your Windows-built security tools are blind to Mac threats. Launch agents that persist after removal...

25. [Building a modern Durable Execution Engine from First Principles](https://restate.dev/blog/building-a-modern-durable-execution-engine-from-first-principles/) - We dive into the architecture details of Restate, a Durable Execution engine we built from the groun...

26. [Why Conductor - Durable Execution for workflows and agents](https://conductor-oss.github.io/conductor/devguide/concepts/conductor.html) - Conductor is an open source workflow engine built for workflow orchestration at scale. It orchestrat...

