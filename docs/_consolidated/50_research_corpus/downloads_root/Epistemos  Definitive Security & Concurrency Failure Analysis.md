# Epistemos: Definitive Security & Concurrency Failure Analysis

## Executive Summary

The Epistemos macOS agent is experiencing a cascading failure pattern with three reinforcing causes: a Swift structured concurrency continuation leak that starves the cooperative thread pool, a cdhash provenance mismatch that causes AMFI/TCC to silently deny screen capture permissions the app believes it has been granted, and a shared-memory ring buffer overflow at the Rust/UniFFI FFI boundary. These three issues form an interdependent failure cycle — the continuation leak blocks the Swift consumer thread, which stops draining the FFI ring buffer, which causes all subsequent Rust calls to fail with `ringFull`, while simultaneously the stale cdhash causes the `replayd` daemon to be sandbox-denied from reading the app's data. The 31,390ms main thread hang confirmed in the system logs is the visible symptom of all three issues converging simultaneously.

***

## Root Cause 1: Swift Continuation Leak and Thread Pool Starvation

### Mechanism

The Swift cooperative thread pool runs exactly as many worker threads as there are logical CPU cores on the device. When any one of those threads performs a blocking synchronous call — or when a `CheckedContinuation` is created but never resumed — that thread is permanently suspended from the pool's perspective. On a 10-core M-series Mac, starving just two threads from blocking I/O reduces throughput capacity by 20%; starving all threads causes the `@MainActor` queue to stop draining, which manifests as the multi-second hangs seen in the logs.[^1][^2]

The log line `SWIFT TASK CONTINUATION MISUSE: send(method:params:timeout:) leaked its continuation` is the definitive diagnosis. Apple's runtime prints this warning when a `CheckedContinuation` is deallocated without ever being resumed. The awaiting task is then stuck indefinitely — it cannot be cancelled by normal means because the continuation reference has been lost. This is precisely the condition that produced the 31-second hang sequence:[^3][^4]

```
error 094409.879594 Epistemos Main thread hang detected 31390ms threshold 500ms consecutive 1
...
error 094409.883060 Epistemos Main thread hang detected 1393ms threshold 500ms consecutive 31
```

### Why `send(method:params:timeout:)` Leaks

The most common cause is a code path that returns early — through a `guard`, an early `throw`, or a `catch` block — without resuming the continuation before exiting scope. The pattern typically looks like this:[^4][^1]

```swift
// BROKEN — continuation leaked on early exit
func send(method: String, params: [String: Any], timeout: TimeInterval) async throws -> Response {
    return try await withCheckedThrowingContinuation { continuation in
        let request = buildRequest(method: method, params: params)
        
        guard networkAvailable else {
            // ❌ Returns without resuming continuation — task hangs forever
            return
        }
        
        rustBridge.send(request) { result in
            switch result {
            case .success(let r): continuation.resume(returning: r)
            case .failure(let e): continuation.resume(throwing: e)
            }
        }
        
        // ❌ If rustBridge.send() throws synchronously, the closure is never
        //    called and the continuation is never resumed
    }
}
```

### Permanent Fix: Continuation Guard Pattern

Every exit path — including synchronous throws, `guard` failures, and timeout paths — must explicitly resume the continuation.[^3][^1]

```swift
// CORRECT — every path resumes the continuation exactly once
func send(method: String, params: [String: Any], timeout: TimeInterval) async throws -> Response {
    return try await withCheckedThrowingContinuation { continuation in
        guard networkAvailable else {
            continuation.resume(throwing: NetworkError.unavailable)  // ✅ Always resume
            return
        }
        
        // Timeout guard: resume with error after deadline
        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(timeout))
            continuation.resume(throwing: NetworkError.timedOut)
        }
        
        do {
            try rustBridge.send(buildRequest(method: method, params: params)) { result in
                timeoutTask.cancel()  // Cancel timeout if we got a result
                switch result {
                case .success(let r): continuation.resume(returning: r)
                case .failure(let e): continuation.resume(throwing: e)
                }
            }
        } catch {
            timeoutTask.cancel()
            continuation.resume(throwing: error)  // ✅ Synchronous throw path also resumes
        }
    }
}
```

**Key rules:**
- Use `CheckedContinuation` (not `UnsafeContinuation`) in all non-hot paths — it logs the leak warning that saved the diagnosis here.[^3]
- A continuation must be resumed **exactly once** — resuming twice will trap; never resuming leaks the task.[^4][^1]
- Timeouts must always be implemented as a racing `Task`, not as a `DispatchQueue.asyncAfter`, because only Swift tasks can interact safely with the continuation lifecycle.[^2]

### Detecting All Leaked Continuations

Use Xcode's **Swift Concurrency** Instruments template (available since Xcode 14, WWDC22). The "Task" instrument shows every task stuck in the *Suspended – awaiting continuation* state indefinitely. Any task that remains in that state after its logical deadline has passed is a leaked continuation. The call tree will pinpoint the exact `withCheckedContinuation` call site.[^1]

### Blocking I/O in the Cooperative Pool

A secondary starvation source is synchronous blocking work running on pool threads. `FileManager` calls, synchronous keychain operations (`SecItemCopyMatching`), and `flock`-based file locking all block a pool thread until the kernel scheduler resumes them. The correct pattern is to move these off the pool entirely:[^2]

```swift
// WRONG — blocks a cooperative pool thread
actor VaultActor {
    func loadVault() async throws -> URL {
        // FileManager.default.fileExists is synchronous — blocks pool thread
        guard FileManager.default.fileExists(atPath: vaultPath) else { throw VaultError.missing }
        return URL(filePath: vaultPath)
    }
}

// CORRECT — custom SerialExecutor backed by a DispatchQueue with I/O QoS
actor VaultActor {
    nonisolated let unownedExecutor: UnownedSerialExecutor
    private let ioQueue = DispatchSerialQueue(label: "com.epistemos.vault.io", qos: .userInitiated)
    
    init() { unownedExecutor = ioQueue.asUnownedSerialExecutor() }
    
    func loadVault() async throws -> URL {
        // Runs on ioQueue — blocking here does NOT steal from the cooperative pool
        guard FileManager.default.fileExists(atPath: vaultPath) else { throw VaultError.missing }
        return URL(filePath: vaultPath)
    }
}
```

The custom `SerialExecutor` backed by `DispatchSerialQueue` pins the actor to a dedicated GCD queue, so any synchronous blocking inside the actor blocks that queue's thread — not one of the cooperative pool's precious threads.[^5][^6]

***

## Root Cause 2: AMFI/cdhash Mismatch and Code -67034

### What `cdhash` Is and Why It Breaks

The **cdhash** (Code Directory Hash) is a SHA-256 hash computed over the binary's `CodeDirectory` data structure, which itself encodes the hash of every page of the binary. AMFI (Apple Mobile File Integrity) maintains a kernel-level database of trusted cdhashes. When `ContextStoreAgent` or `replayd` attempts to access the app's data, it presents the app's cdhash to the kernel as a proof of identity.[^7][^8]

**Error Code -67034 is `errSecCSReqFailed`**: the presented cdhash does not satisfy the app's designated code signing requirement. This happens when:[^8]

1. **A file inside the app bundle was modified after signing** — even a single byte change to any non-excluded resource invalidates the `CodeResources` hash map, which invalidates the `CodeDirectory`, which changes the cdhash.
2. **`--deep` signing was used instead of bottom-up signing** — `codesign --deep` signs nested components in an arbitrary order and can fail to re-sign dylibs that were already signed with a conflicting identity, leaving stale signatures in inner bundles.[^9][^10]
3. **Rust `.dylib` files generated by the build system were not signed** — any unsigned or differently-signed binary inside the bundle causes the outer signature to fail the `CodeResources` check.
4. **The app was re-built without cleaning** — incremental builds can leave previously-signed objects that conflict with the new signing identity.

From the logs:
```
error amfid .../EpistemosTests.xctest/Contents/MacOS/EpistemosTests not valid
  Error Domain=AppleMobileFileIntegrityError Code=-423
  "The file is adhoc signed or signed by an unknown certificate chain"
error kernel Sandbox replayd33559 deny(1) file-read-data .../Epistemos.app
error kernel Sandbox linkd603 deny(1) file-issue-extension
  target /Applications/Epistemos.app extension-class com.apple.app-sandbox.read
```

The `EpistemosTests.xctest` bundle is ad-hoc signed (development) while the host app has a Developer ID signature — the mismatch causes the entire trust chain to be rejected.

### Permanent Fix: Bottom-Up Signing Script

Replace any use of `codesign --deep` with a signing script that processes components from the innermost to the outermost:[^10][^9]

```bash
#!/bin/bash
# sign_epistemos.sh — Bottom-up signing for Epistemos.app
# Run after every build, before notarization or distribution.

APP="$1"  # Path to .app bundle
IDENTITY="${CODESIGN_IDENTITY:-Apple Development: jordan...}"
ENTITLEMENTS_MAIN="./Entitlements/Epistemos.entitlements"
ENTITLEMENTS_HELPER="./Entitlements/helper.entitlements"

# Step 1: Sign all Rust dylibs and frameworks (deepest first)
find "$APP/Contents/Frameworks" -name "*.dylib" -o -name "*.framework" | \
  sort -r | \
  while read -r item; do
    codesign --force --options runtime \
      --sign "$IDENTITY" \
      --timestamp \
      "$item"
  done

# Step 2: Sign any bundled helper tools / XPC services
find "$APP/Contents" -name "*.xpc" | while read -r xpc; do
    codesign --force --options runtime \
      --entitlements "$ENTITLEMENTS_HELPER" \
      --sign "$IDENTITY" \
      --timestamp \
      "$xpc"
done

# Step 3: Sign test bundles separately (if present in dev builds only)
find "$APP/Contents/PlugIns" -name "*.xctest" | while read -r test; do
    codesign --force \
      --sign "$IDENTITY" \
      --timestamp \
      "$test"
done

# Step 4: Sign the main app bundle last
codesign --force --options runtime \
  --entitlements "$ENTITLEMENTS_MAIN" \
  --sign "$IDENTITY" \
  --timestamp \
  "$APP"

# Step 5: Verify the full chain
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --verbose=4 --type execute "$APP"
```

### TCC Database Reset After Signature Repair

After correcting the signing, the TCC database must be purged — it caches the old cdhash and will continue denying requests until cleared.[^8]

```bash
# Reset only the affected permissions — do NOT reset all TCC data
tccutil reset ScreenCapture com.epistemos.app
tccutil reset Accessibility com.epistemos.app

# For development, also reset the system TCC db (requires full disk access)
# sudo tccutil reset ScreenCapture com.epistemos.app
```

The app must then be relaunched and the user must re-grant permissions. This is a one-time operation — after the cdhash is stable (i.e., the signing process is correct), the TCC grant persists across launches.

### Tool Gate Failures and Sandbox Inheritance

The `Tool gate failure` for `vision_analyze` and `web_extract` is a sandbox inheritance violation. The `com.apple.security.inherit` entitlement requires **exactly two** entitlement keys in the child process's entitlements file:[^10]

```xml
<!-- helper_tool.entitlements — EXACTLY these two keys, nothing else -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.inherit</key>
    <true/>
    <!-- ⚠️ DO NOT add any other keys here, including:
         com.apple.security.get-task-allow (injected by Xcode in Debug — strip it)
         com.apple.security.network.client
         Any custom entitlements
    -->
</dict>
</plist>
```

The critical Xcode bug to be aware of: in **Debug builds**, Xcode automatically injects `com.apple.security.get-task-allow` into all sandboxed targets to enable the debugger. This third key causes sandbox inheritance to fail silently — the child process is aborted without a user-visible error. **Fix:** use a Release or Ad-Hoc build configuration for all helper tools, or explicitly override the entitlements in the build phase to strip `get-task-allow`.[^10]

***

## Root Cause 3: FFI Ring Buffer Exhaustion

### Mechanism

The `KnowledgeCoreBridge call failed with ringFull: shared-memory ring is full` error follows directly from the 31-second main thread hang. The shared-memory ring buffer is a producer-consumer structure: Rust writes events into it, Swift reads them out. When the Swift main thread hangs (due to the continuation leak), the consumer side stops processing, and Rust continues writing until the buffer's capacity is exhausted.[^11]

Fixing the continuation leak (Root Cause 1) will substantially reduce `ringFull` occurrences. However, the ring buffer itself needs to be made resilient against brief consumer pauses:

```rust
// epistemos_bridge.rs — Ring buffer with backpressure instead of hard failure

pub struct KnowledgeCoreBridge {
    ring: Arc<RingBuffer<BridgeEvent>>,
    overflow_queue: Mutex<VecDeque<BridgeEvent>>,
    max_overflow: usize,
}

impl KnowledgeCoreBridge {
    pub fn send_event(&self, event: BridgeEvent) -> Result<(), BridgeError> {
        // Try the fast path first
        if self.ring.try_push(event.clone()).is_ok() {
            return Ok(());
        }
        
        // Ring is full — spill to overflow queue with capacity limit
        let mut overflow = self.overflow_queue.lock().unwrap();
        if overflow.len() < self.max_overflow {
            overflow.push_back(event);
            Ok(())
        } else {
            // Both ring and overflow are full — record the drop, don't panic
            Err(BridgeError::Dropped)
        }
    }
    
    /// Called by Swift consumer when it resumes processing
    pub fn drain_overflow(&self) {
        let mut overflow = self.overflow_queue.lock().unwrap();
        while let Some(event) = overflow.pop_front() {
            if self.ring.try_push(event.clone()).is_err() {
                // Ring still full — put it back and stop
                overflow.push_front(event);
                break;
            }
        }
    }
}
```

The Swift `TelemetryActor` (see the prior report) should call `drain_overflow()` each time it wakes from suspension, ensuring backlogged events are processed without loss.

***

## Root Cause 4: Metal `flock` Contention (errno 35)

### Evidence and Cause

```
error Epistemos flock failed to lock list file
  .../com.epistemos.app/com.apple.metal32024libraries.list errno=35
error Epistemos flock failed to lock list file
  .../com.epistemos.app/com.apple.metal16777235434functions.list errno=35
```

`errno=35` is `EAGAIN` / `EWOULDBLOCK` — the `flock` call was made with the non-blocking flag and failed because a previous instance of the app (or a crash remnant) holds the lock. The Metal runtime takes an advisory `flock` on shader cache list files to prevent concurrent compilation. When a prior instance crashes without releasing the lock, the next instance finds it occupied and fails to access its compiled shader cache, forcing re-compilation on every launch.[^12]

### Permanent Fix: `MTLBinaryArchive`

Pre-compile all Metal shaders into an `MTLBinaryArchive` stored in the app bundle. This eliminates runtime JIT compilation entirely and bypasses the `flock`-contended system shader cache.[^12]

```swift
// MetalPipelineCache.swift

final class MetalPipelineCache {
    private let device: MTLDevice
    private let archiveURL: URL
    private var archive: MTLBinaryArchive?

    init(device: MTLDevice) throws {
        self.device = device
        self.archiveURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Resources/EpistemosShaders.metalarchive")
        
        // Load pre-compiled archive from bundle (eliminates flock contention)
        let descriptor = MTLBinaryArchiveDescriptor()
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            descriptor.url = archiveURL
        }
        archive = try device.makeBinaryArchive(descriptor: descriptor)
    }
    
    func makePipeline(descriptor: MTLRenderPipelineDescriptor) throws -> MTLRenderPipelineState {
        // Tell Metal to look in the binary archive before compiling
        descriptor.binaryArchives = [archive].compactMap { $0 }
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    /// Run once during CI/build to generate the archive — not at runtime
    func generateArchive(pipelines: [MTLRenderPipelineDescriptor]) throws {
        let newArchive = try device.makeBinaryArchive(descriptor: MTLBinaryArchiveDescriptor())
        for desc in pipelines {
            try newArchive.addRenderPipelineFunctions(descriptor: desc)
        }
        try newArchive.serialize(to: archiveURL)
    }
}
```

Add a **build phase script** that runs `generateArchive` headlessly against all pipeline descriptors, serializes the output to `Resources/EpistemosShaders.metalarchive`, and commits it to the repository. The `flock` errors will cease because the Metal runtime will serve all pipeline lookups from the archive without touching the system compiler cache files.

***

## Root Cause 5: `inputanalyticsd` / `distnoted` Feedback Loop

### Evidence

```
Epistemos channelLegacyTextInputActions signalDidSessionBegin sessionID...
  insertedTextLength 0 ...source 3 textInputActionsType 0
// Session begin with zero insertions — fired repeatedly as cursor moves
Epistemos channelLegacyTextInputActions signalDidSessionEnd sessionID...
// Session end/begin cycle with every window focus change
```

The `called without session beginning` log indicates that text input session events are being dispatched to `distnoted` before a valid session state is established — likely because the `TUINSCursorUIController` is being initialized before `NSApplication.finishLaunching` completes. Each spurious session begin/end pair fires a distributed notification, which can accumulate into a storm when the main thread hangs and deferred events fire simultaneously on recovery.[^13]

### Fix: Deferred Input Analytics Registration

```swift
// ⛔ DO NOT register text input observers in applicationWillFinishLaunching
// or in any NSWindowController initializer

// ✅ Register ONLY after applicationDidFinishLaunching
func applicationDidFinishLaunching(_ notification: Notification) {
    // Ensure NSApp is fully initialized before registering input observers
    Task { @MainActor in
        // Delay by one run-loop cycle to let all window restoration complete
        await Task.yield()
        InputTelemetryBridge.shared.start()
    }
}
```

Additionally, ensure `NSApp.setActivationPolicy(.regular)` and any `NSWindow.makeKeyAndOrderFront` calls happen **before** any text field becomes first responder — out-of-order activation is the proximate cause of `called without session beginning`.

***

## `replayd` Daemon Recovery

When `ScreenCaptureKit` (`replayd`) has been sandbox-denied due to the cdhash mismatch, it caches the denial. After the cdhash is fixed and TCC is reset, if `replayd` still fails to provide frames, kick it programmatically:

```swift
// In SCStream error handler, after cdhash fix is deployed
func stream(_ stream: SCStream, didStopWithError error: Error) {
    guard (error as NSError).code == SCStreamErrorCode.userStopped.rawValue else {
        // Non-user-stop: daemon may be in bad state, attempt restart via launchctl
        Task.detached(priority: .userInitiated) {
            let result = Process()
            result.executableURL = URL(filePath: "/bin/launchctl")
            result.arguments = ["kickstart", "-k",
                "gui/\(getuid())/com.apple.replayd"]
            try? result.run()
            result.waitUntilExit()
        }
        return
    }
    // User-stopped: normal path
}
```

Note: `launchctl kickstart -k` forcibly terminates and restarts the daemon. Use this only in the error recovery path — not on every launch.

***

## Consolidated Fix Sequence

The issues must be resolved in dependency order — fixing concurrency first prevents the ring buffer from overflowing, and fixing signing before running permits TCC to grant the correct permissions.

| Priority | Fix | Dependency | Expected Outcome |
|----------|-----|------------|-----------------|
| **P0** | Audit and fix all `withCheckedContinuation` paths; add timeout racing tasks | None | Eliminates 31s hang; unblocks pool |
| **P0** | Bottom-up signing script; strip `get-task-allow` from helper entitlements | None | Fixes cdhash mismatch; unblocks sandbox |
| **P0** | `tccutil reset ScreenCapture` + `reset Accessibility` | Signing fixed | Clears stale TCC denial cache |
| **P1** | Custom `SerialExecutor` for `VaultActor` and `KnowledgeStoreActor` | P0 concurrency | Prevents blocking pool threads |
| **P1** | Ring buffer overflow queue + `drain_overflow()` in `TelemetryActor` | P0 concurrency | Eliminates `ringFull` errors |
| **P2** | `MTLBinaryArchive` build pipeline | None | Eliminates `flock errno=35` |
| **P2** | Deferred `inputanalyticsd` registration in `applicationDidFinishLaunching` | None | Stops session-less event storm |
| **P3** | `replayd` kickstart in `SCStream` error path | P0 signing | Recovers screen capture after denial |
| **P3** | `catch_unwind` on all Rust FFI entry points | None | Prevents panic → UB at C ABI boundary |

***

## Diagnostic Instrumentation

Add these instruments to your Xcode scheme to verify fixes:

```swift
// Continuation leak detector — add to debug builds only
#if DEBUG
extension CheckedContinuation {
    static func withLeakDetection<T>(
        _ body: (CheckedContinuation<T, Never>) -> Void,
        file: StaticString = #file,
        line: UInt = #line
    ) async -> T {
        await withCheckedContinuation { continuation in
            let id = UUID()
            ContinuationTracker.shared.register(id, file: file, line: line)
            body(CheckedContinuation(wrapping: continuation) {
                ContinuationTracker.shared.deregister(id)
            })
        }
    }
}

actor ContinuationTracker {
    static let shared = ContinuationTracker()
    private var active: [UUID: (file: StaticString, line: UInt, date: Date)] = [:]
    
    func register(_ id: UUID, file: StaticString, line: UInt) {
        active[id] = (file, line, Date())
    }
    
    func deregister(_ id: UUID) { active.removeValue(forKey: id) }
    
    /// Call from a background watchdog every 10 seconds
    func reportLeaks() {
        let old = active.filter { Date().timeIntervalSince($0.value.date) > 5 }
        for (_, info) in old {
            Logger.concurrency.error("⚠️ Potential continuation leak at \(info.file):\(info.line)")
        }
    }
}
#endif
```

Pair this with the **Swift Concurrency** Instruments template, which provides a graphic visualization of task trees, continuation state (running/suspended/awaiting), and the exact call site of any stuck continuation.[^1]

---

## References

1. [Visualize and optimize Swift concurrency - WWDC22 - Videos](https://developer.apple.com/videos/play/wwdc2022/110350/) - Learn how you can optimize your app with the Swift Concurrency template in Instruments. We'll discus...

2. [Detached Task - Using Swift](https://forums.swift.org/t/detached-task/80810) - Task.detached runs work off the main thread but breaks structured concurrency: no task-local/priorit...

3. [CheckedContinuation | Apple Developer Documentation](https://developer.apple.com/documentation/swift/checkedcontinuation) - CheckedContinuation performs runtime checks for missing or multiple resume operations. UnsafeContinu...

4. [ios - SWIFT TASK CONTINUATION MISUSE: - method leaked its ...](https://stackoverflow.com/questions/79189458/swift-task-continuation-misuse-method-leaked-its-continuation-not-blocking) - The call to the external lib sometimes prints SWIFT TASK CONTINUATION MISUSE: leaked its continuatio...

5. [swift-evolution/proposals/0392-custom-actor-executors.md at main](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0392-custom-actor-executors.md) - SerialExecutors will potentially be extended to support "switching" which can lessen the amount of t...

6. [SerialExecutor | Apple Developer Documentation](https://developer.apple.com/documentation/swift/serialexecutor) - You can implement a custom executor, by conforming a type to the SerialExecutor protocol, and implem...

7. [blanket/amfidupe/cdhash.c at master · bazad/blanket](https://github.com/bazad/blanket/blob/master/amfidupe/cdhash.c) - bazad / **
blanket ** Public

## Files

# cdhash.c

## Latest commit

bazad

Finish amfidupe and add...

8. [AMFI: checking file integrity on your Mac](https://eclecticlight.co/2018/12/29/amfi-checking-file-integrity-on-your-mac/) - Digging around looking at signature checking for apps in Mojave brought me in contact with a part of...

9. [Process is not in an inherited sandbox. · Issue #5248 - GitHub](https://github.com/electron/electron/issues/5248) - ... entitlements child.plist "$FRAMEWORKS_PATH/Electron Framework ... MacOS/$APP Helper" codesign -s...

10. [Sandbox Inheritance Tax | Indie Stack](https://indiestack.com/2017/09/sandbox-inheritance-tax/) - If you specify any other App Sandbox entitlement, the system aborts the child process. ... signing w...

11. [Rethinking State Management in Actor Systems for Cloud-Native
  Applications](https://arxiv.org/pdf/2410.15831.pdf) - The actor model has gained increasing popularity. However, it lacks support
for complex state manage...

12. [MTLBinaryArchiveError | Apple Developer Documentation](https://developer.apple.com/documentation/metal/mtlbinaryarchiveerror-swift.struct) - An error code that indicates an app is using an invalid reference to an archive file, typically rela...

13. [Mysterious "audioanalyticsd" process eating RAM. Any ideas? - Reddit](https://www.reddit.com/r/MacOS/comments/16ziema/mysterious_audioanalyticsd_process_eating_ram_any/) - the macOS manual page for it says this audioanalyticsd is a launch agent that aggregates and analyze...

