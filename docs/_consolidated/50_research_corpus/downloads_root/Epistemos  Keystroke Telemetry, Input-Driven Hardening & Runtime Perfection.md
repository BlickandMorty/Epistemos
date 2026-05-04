# Epistemos: Keystroke Telemetry, Input-Driven Hardening & Runtime Perfection

## The Insight: Your Input Stream Is the World's Best Test Harness

Most apps are tested with scripted UI tests and synthetic benchmarks. Epistemos already records every keystroke, modifier press, paste event, and timing interval during real sessions. That's a continuous, organic, infinitely varied test corpus that reveals edge cases no contrived test suite ever would. The key is to instrument that stream — not to surveil content, but to extract timing, sequencing, and pattern metadata — and then correlate it against the runtime health signals from the previous report (MetricKit, watchdog, thermal state). When you find a combination of input events that reliably precedes a hang, stall, or crash, you've found a genuine edge case. When input stops arriving for an unexpected interval, you've found a freeze. This is what **production input-driven hardening** looks like, and it's one of the most powerful techniques available for a macOS app in this category.

***

## Part I — The Input Event Telemetry Layer

### 1.1 What to Capture (Metadata Only, Never Content)

Epistemos should never log the *content* of keystrokes in its performance telemetry — only the *shape* of input. The distinction:

| Captured (safe, non-PII) | Never Captured |
|--------------------------|---------------|
| Timestamp of keydown/keyup | Which character was pressed |
| Inter-keystroke interval (IKI) in ms | Text content of any field |
| Modifier flags (shift, cmd, ctrl, opt) | Contents of clipboard paste |
| Event source (CGEventTap vs NSEvent) | Passwords (protected by SecureEventInput) |
| Hold duration (keydown → keyup delta) | Any credential-adjacent input |
| Key repeat flag (system auto-repeat) | |
| Paste event occurred (boolean) | |
| Event dropped / tap disabled (boolean) | |

This gives you full behavioral fidelity for performance analysis with zero privacy exposure. The keystroke **timing** is the signal — the content is noise.[^1][^2]

### 1.2 The InputTelemetry Actor

Run this entirely off the main thread. `CGEventTap` callbacks execute on whatever run loop you schedule them on — always use a dedicated background `CFRunLoop`:[^3][^4]

```swift
import CoreGraphics
import Foundation

actor InputTelemetry {
    static let shared = InputTelemetry()

    // Circular buffer — last 500 events in memory
    private var buffer: [InputEvent] = []
    private let maxBuffer = 500

    // Timing state (non-isolated — written from CGEventTap callback thread)
    private var lastKeydownTime: TimeInterval = 0
    private var consecutiveRapidEvents: Int = 0
    private let rapidThreshold: TimeInterval = 0.05  // 50ms = very fast typing or key-repeat storm

    struct InputEvent: Codable {
        let timestamp: TimeInterval      // CACurrentMediaTime()
        let eventType: String            // "keydown", "keyup", "paste", "tapDisabled"
        let modifiers: UInt64            // raw CGEventFlags
        let isRepeat: Bool
        let holdDuration: TimeInterval   // 0 for keydown events
        let ikiMs: Double                // inter-keystroke interval in milliseconds
        let thermalState: Int            // ProcessInfo.thermalState.rawValue
        let mainThreadStallActive: Bool  // set by watchdog
    }

    func record(_ event: InputEvent) {
        buffer.append(event)
        if buffer.count > maxBuffer { buffer.removeFirst() }
        analyzeForAnomalies(event)
    }

    private func analyzeForAnomalies(_ event: InputEvent) {
        // Detect key-repeat storm: rapid consecutive events at >20/sec
        if event.ikiMs < 50 && !event.isRepeat {
            consecutiveRapidEvents += 1
            if consecutiveRapidEvents > 30 {
                Logger.perf.error("Input storm detected: \(consecutiveRapidEvents) rapid events < 50ms IKI")
                ThermalGuard.shared.handleInputStorm()
                consecutiveRapidEvents = 0
            }
        } else {
            consecutiveRapidEvents = 0
        }

        // Detect tap going silent (CGEventTap disabled by macOS)
        if event.eventType == "tapDisabled" {
            Logger.entitle.fault("CGEventTap was disabled by system — re-enabling")
            Task { await EventTapManager.shared.reinstall() }
        }
    }

    // Export last N events as JSON for analysis
    func exportWindow(last count: Int = 200) throws -> Data {
        let window = Array(buffer.suffix(count))
        return try JSONEncoder().encode(window)
    }
}
```

Key design points: the actor serializes all writes, the buffer is capped at 500 events (~seconds of intense typing), and anomaly detection runs inline.[^2][^1]

### 1.3 The CGEventTap Installation (Background Run Loop)

This is the critical architectural point that the existing code in Epistemos likely gets wrong. The `CGEventTap` must run on a **dedicated background thread's run loop**, not on the main run loop. If it's on the main run loop, it contributes to the stall that caused the SIGKILL:[^4][^5][^3]

```swift
final class EventTapManager {
    static let shared = EventTapManager()

    private var tapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let tapThread: Thread

    init() {
        tapThread = Thread {
            // This dedicated thread owns the event tap's run loop
            EventTapManager.shared.installTap()
            CFRunLoopRun()  // blocks this thread indefinitely
        }
        tapThread.name = "com.epistemos.eventtap"
        tapThread.qualityOfService = .userInteractive
        tapThread.start()
    }

    private func installTap() {
        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)   |
            (1 << CGEventType.flagsChanged.rawValue)
        )

        tapPort = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,   // tail = listen only, don't intercept
            options: .listenOnly,          // IMPORTANT: never block input delivery
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: nil
        )

        guard let port = tapPort else {
            Logger.entitle.fault("CGEventTap creation failed — Input Monitoring permission missing")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        Logger.entitle.info("CGEventTap installed on background thread ✓")
    }

    // Called when macOS re-enables the tap after SecureInput ends
    func reinstall() async {
        guard let port = tapPort else { return }
        CGEvent.tapEnable(tap: port, enable: true)
        Logger.entitle.info("CGEventTap re-enabled after SecureInput release")
    }
}

// C-style callback — executes on the tap thread, NOT main thread
private func eventTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let now = CACurrentMediaTime()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        // macOS disabled the tap — log it and schedule re-enable
        Task {
            await InputTelemetry.shared.record(.init(
                timestamp: now, eventType: "tapDisabled",
                modifiers: 0, isRepeat: false,
                holdDuration: 0, ikiMs: 0,
                thermalState: ProcessInfo.processInfo.thermalState.rawValue,
                mainThreadStallActive: false
            ))
        }
        return Unmanaged.passRetained(event)
    }

    // Compute IKI without allocating on the hot path
    let iki = EventTapManager.shared.computeIKI(now: now)

    let inputEvent = InputTelemetry.InputEvent(
        timestamp: now,
        eventType: type == .keyDown ? "keydown" : (type == .keyUp ? "keyup" : "flags"),
        modifiers: event.flags.rawValue,
        isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
        holdDuration: 0,
        ikiMs: iki * 1000,
        thermalState: ProcessInfo.processInfo.thermalState.rawValue,
        mainThreadStallActive: MainThreadWatchdog.shared.isCurrentlyStalled
    )

    Task { await InputTelemetry.shared.record(inputEvent) }

    return Unmanaged.passRetained(event)  // always return — never consume input
}
```

Using `.listenOnly` and `.tailAppendEventTap` ensures Epistemos never interferes with event delivery — it only observes. This is crucial for both security hygiene and system stability.[^6][^7]

***

## Part II — SecureEventInput Awareness

### 2.1 Why the Tap Goes Silent

When any app on macOS calls `EnableSecureEventInput()` — which happens automatically for password fields, terminal SSH sessions, system auth prompts, and password managers — the OS stops delivering events to all `CGEventTap` instances system-wide. This means Epistemos's event tap silently stops receiving keystrokes. If the app isn't handling this, it looks like a bug ("why isn't my feature working?") when it's actually correct OS security behavior.[^8][^9][^10]

The fix is to watch for `tapDisabledByUserInput` events in the callback and log when secure input is active:[^11][^12]

```swift
// Detect if SecureEventInput is the reason the tap went silent
func isSecureInputActive() -> Bool {
    // CGSIsSecureEventInputSet() is a private API — use the published workaround:
    // check if our tap callback has been silent for >2s during expected typing activity
    return IsSecureEventInputEnabled()  // from Carbon.framework, still public
}
```

Log this clearly:

```swift
if isSecureInputActive() {
    Logger.entitle.notice("SecureEventInput active — keystroke monitoring paused (expected, user is in secure field)")
} else {
    Logger.entitle.error("CGEventTap silent without SecureEventInput — possible permission issue")
}
```

This prevents false-positive bug reports from normal password-field behavior.[^10][^12]

### 2.2 Code-Signing Race Condition

There is a known macOS bug where re-signing the app causes the `CGEventTap` to silently stop firing — the tap appears installed but events never arrive. The workaround: on every launch, verify the tap is alive by checking if it receives events within the first 5 seconds of use:[^4]

```swift
actor EventTapHealthCheck {
    private var lastReceivedAt: TimeInterval = 0
    private var tapInstalled = false

    func noteEventReceived() {
        lastReceivedAt = CACurrentMediaTime()
        tapInstalled = true
    }

    func checkHealth() async {
        guard tapInstalled else { return }
        let silence = CACurrentMediaTime() - lastReceivedAt
        if silence > 5.0 && !isSecureInputActive() {
            Logger.entitle.fault("EventTap health check FAILED: \(silence)s of silence — reinstalling")
            await EventTapManager.shared.reinstall()
        }
    }
}
```

Schedule this check every 10 seconds.[^13][^4]

***

## Part III — Input-Driven Edge Case Discovery

This is where the real hardening leverage comes from. Because Epistemos captures real user sessions, the telemetry produces a **ground truth of actual usage patterns** — timing distributions, modifier chord frequencies, paste behaviors, key-repeat patterns — that no synthetic test can replicate.

### 3.1 Inter-Keystroke Interval (IKI) as a Performance Signal

IKI is the time in milliseconds between consecutive keydown events. Normal human typing has a predictable IKI distribution — roughly 80–200ms for fluent typists. Deviations are diagnostically rich:[^14][^1]

| IKI Pattern | What It Means for Epistemos |
|-------------|----------------------------|
| IKI < 30ms (non-repeat) | Paste event disguised as keystrokes, or rapid macro/script input |
| IKI 30–80ms | Very fast human typing — high event rate, stress-test your processing pipeline |
| IKI 80–200ms | Normal typing — baseline performance target |
| IKI > 2000ms | User paused — good time to flush logs, run background work |
| IKI > 30,000ms (5 min) | Idle — app likely backgrounded; trigger HeartbeatScheduler check |
| IKI sudden spike from <100ms to >3000ms | User hit a **hang** — app froze mid-session |

The "sudden IKI spike" pattern is the most valuable signal. When a user is typing at 120ms IKI and it suddenly jumps to 4000ms — and the watchdog isn't reporting a stall — that's a **perceived hang** that the system didn't catch. Log it:[^15][^16]

```swift
private func detectPerceivedHang(_ iki: Double) {
    guard lastBaselineIKI > 0 else { return }
    let ratio = iki / lastBaselineIKI
    if ratio > 20 && lastBaselineIKI < 200 {
        // IKI jumped to 20x normal — user experienced something
        Logger.perf.error("Perceived hang signal: IKI jumped from \(Int(lastBaselineIKI))ms to \(Int(iki))ms (ratio: \(Int(ratio))x)")
        // Snapshot current state for post-mortem
        snapshotRuntimeState(trigger: "perceived-hang")
    }
    // Rolling average update
    lastBaselineIKI = lastBaselineIKI * 0.9 + iki * 0.1
}
```

### 3.2 Modifier Chord Frequency Profiling

Track which modifier combinations are most used — `⌘`, `⌘⇧`, `⌘⌥`, `⌃⌘`, etc. — and log performance metrics broken out by chord. If `⌘⌥` combinations consistently produce longer processing times than `⌘` alone, there's a code path triggered by that chord that's slower than it should be:

```swift
struct ChordProfile {
    var count: Int = 0
    var avgResponseMs: Double = 0
    var p95ResponseMs: Double = 0
    var stallCount: Int = 0
}

// In your key handler:
func handleKeyEvent(_ event: NSEvent) {
    let start = CACurrentMediaTime()
    let chord = event.modifierFlags.intersection([.command, .shift, .option, .control])

    processKeyEvent(event)  // your actual handler

    let duration = (CACurrentMediaTime() - start) * 1000
    updateChordProfile(chord: chord, durationMs: duration)

    if duration > 16.67 {  // > 1 frame at 60fps = visible lag
        Logger.perf.error("Key handler stalled: chord=\(chord.rawValue) duration=\(Int(duration))ms")
    }
}
```

When you export the chord profile to Claude with a log, patterns like "⌘⌥ chords have 3x higher handler time" immediately point to specific code paths to investigate.

### 3.3 Paste Event Hardening

Paste events (`⌘V`) are uniquely dangerous for app stability: they can inject arbitrarily large strings, contain special Unicode (zero-width joiners, RTL characters, emoji with variation selectors), or arrive in rapid succession. Since Epistemos captures keystrokes, you know every time a paste happens. Stress-test the paste path using real paste metadata from telemetry:

```swift
func handlePaste() {
    guard let content = NSPasteboard.general.string(forType: .string) else { return }
    let start = CACurrentMediaTime()

    // Defensive checks before processing
    let length = content.unicodeScalars.count
    let hasRTL = content.unicodeScalars.contains { $0.properties.bidiClass == .rightToLeft }
    let hasZWJ = content.contains("\u{200D}")

    Logger.ui.info("Paste event: length=\(length) hasRTL=\(hasRTL) hasZWJ=\(hasZWJ)")

    // If content is large, process on background thread
    if length > 10_000 {
        Logger.perf.notice("Large paste (\(length) chars) — deferring to background")
        Task.detached(priority: .userInitiated) {
            await self.processLargePaste(content)
        }
        return
    }

    processNormalPaste(content)
    let duration = (CACurrentMediaTime() - start) * 1000
    if duration > 8 { Logger.perf.error("Paste handler stalled: \(Int(duration))ms for \(length) chars") }
}
```

Your telemetry shows real-world paste sizes from actual sessions. Use those distributions to set the threshold (`10_000` above should be calibrated to your P99 paste size from production data).

### 3.4 Key-Repeat Storm Hardening

When a user holds a key, macOS fires repeat events at ~30Hz. If your app's key handler blocks for even 2ms per event, that's 60ms of accumulated blocking per second — perceptible lag. The telemetry records repeat events (`isRepeat: true`). If you see repeat storms in the log (hundreds of rapid repeat events), and they correlate with watchdog stalls, the repeat handler is the culprit:

```swift
// Rate-limit repeat event processing
private var repeatAccumulator: [Character: Int] = [:]
private var lastRepeatFlush: TimeInterval = 0

func handleRepeatEvent(_ char: Character) {
    repeatAccumulator[char, default: 0] += 1

    let now = CACurrentMediaTime()
    if now - lastRepeatFlush > 0.033 {  // 30fps flush rate
        flushRepeatAccumulator()
        lastRepeatFlush = now
    }
    // Don't process every individual repeat — batch them
}
```

### 3.5 Session Segmentation for Edge Case Triage

Divide the input stream into **sessions** based on idle gaps (IKI > 30s = new session). Export sessions individually and label them with outcome: "clean," "stall," "crash," or "thermal event." Over time this produces a labeled dataset. When you feed this to Claude, you can ask it to identify structural differences between clean and degraded sessions:

```swift
struct SessionRecord: Codable {
    let sessionId: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let totalEvents: Int
    let avgIKI: Double
    let maxIKI: Double
    let pasteCount: Int
    let modifierProfile: [String: Int]
    let stalledAt: TimeInterval?       // nil = clean session
    let thermalPeak: Int               // highest thermal state seen
    let metricKitHangDetected: Bool
    let outcome: Outcome

    enum Outcome: String, Codable {
        case clean, stall, crash, thermalThrottle, tapDisabled
    }
}
```

This is the **ground truth corpus** that makes Claude's analysis surgical. Instead of guessing from a raw log, it can pattern-match against your specific historical session outcomes.

***

## Part IV — Runtime Snap Hardening

### 4.1 The Stall Snapshot

When the watchdog fires (main thread blocked > 1.5s), execute a **runtime snapshot** immediately on the background thread — capturing everything about app state at that moment. This is the diagnostic equivalent of a core dump, but structured for Claude analysis:

```swift
struct RuntimeSnapshot: Codable {
    let timestamp: TimeInterval
    let trigger: String                    // "watchdog", "perceived-hang", "thermal-critical"
    let thermalState: Int
    let memoryUsedMB: Int
    let cpuUsagePercent: Double
    let activeQueues: [String]             // DispatchQueue.currentLabel etc.
    let recentInputEvents: [InputTelemetry.InputEvent]  // last 50 events
    let permissionStatus: [String: Bool]   // screen recording, accessibility, etc.
    let uptimeSeconds: Double
    let isSecureInputActive: Bool
    let cgEventTapAlive: Bool
}

func snapshotRuntimeState(trigger: String) {
    let snapshot = RuntimeSnapshot(
        timestamp: CACurrentMediaTime(),
        trigger: trigger,
        thermalState: ProcessInfo.processInfo.thermalState.rawValue,
        memoryUsedMB: currentMemoryUsageMB(),
        cpuUsagePercent: currentCPUUsage(),
        activeQueues: [],  // populate via DispatchQueue introspection
        recentInputEvents: (try? InputTelemetry.shared.lastN(50)) ?? [],
        permissionStatus: [
            "screenRecording": ScreenCapturePermission.isGranted,
            "accessibility": AXIsProcessTrusted(),
            "inputMonitoring": InputMonitoringPermission.isGranted
        ],
        uptimeSeconds: ProcessInfo.processInfo.systemUptime,
        isSecureInputActive: IsSecureEventInputEnabled(),
        cgEventTapAlive: EventTapHealthCheck.shared.isAlive
    )

    if let data = try? JSONEncoder().encode(snapshot) {
        let url = snapshotDirectory.appendingPathComponent("snapshot_\(trigger)_\(Int(Date().timeIntervalSince1970)).json")
        try? data.write(to: url)
    }

    Logger.perf.fault("Runtime snapshot saved: \(trigger)")
}
```

### 4.2 The `ThermalGuard` Extension — Input-Aware Throttling

Extend the `ThermalGuard` from the previous report to be aware of input load. If the user is actively typing at >5 keystrokes/second *and* the thermal state is serious, the ML inference pipeline must yield immediately — even if it's mid-inference:

```swift
// Add to ThermalGuard:
func handleInputStorm() {
    // User is typing fast — the UI pipeline must be clear
    // Immediately suspend all background inference
    MLInferenceEngine.shared.suspendAllTasks()
    Logger.perf.error("Input storm: ML inference preempted to protect UI responsiveness")

    // Resume after input calms down (debounced 500ms of quiet)
    scheduleResumeAfterInputQuiet(delay: 0.5)
}
```

### 4.3 Preemptive Work Cancellation Before Screen Capture

Screen capture via `SCShareableContent` is expensive — it enumerates all windows and can trigger `replayd` sandbox activity. Never start a capture during an active typing burst:

```swift
actor ScreenCaptureController {
    private var pendingCapture: Task<Void, Error>?

    func requestCapture() async throws {
        // Check if user is actively typing (last keystroke < 300ms ago)
        let timeSinceLastKey = CACurrentMediaTime() - InputTelemetry.shared.lastEventTime
        if timeSinceLastKey < 0.3 {
            Logger.screenCap.notice("Deferring screen capture: user is typing (lastKey \(Int(timeSinceLastKey * 1000))ms ago)")
            try await Task.sleep(for: .milliseconds(300))
        }

        // Now proceed with capture
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        Logger.screenCap.info("Capture succeeded: \(content.windows.count) windows")
    }
}
```

This directly prevents the `replayd` sandbox denial storm seen in the original log — which had 8 denies in rapid succession, almost certainly during a typing session.

***

## Part V — The AI Analysis Workflow With Input Telemetry

### 5.1 The "Paste Everything" Diagnostic Bundle

After any problematic session, the full diagnostic export for Claude analysis should include:

```
epistemos_session_<id>.json       — InputTelemetry events (typed structure, no content)
epistemos_snapshots_<id>/         — RuntimeSnapshot JSONs for each stall/hang
metrickit_diag_<ts>.json          — MetricKit hang/crash with call stacks
epistemos_log_<ts>.txt            — OSLog text export
```

All four together give Claude: the input behavioral sequence leading up to any event, the runtime state at the moment of the event, the system-level stack trace, and the structured log. This is essentially a **complete flight recorder** for any session.

### 5.2 Prompting Claude With Input Telemetry

```
Here is a diagnostic bundle from Epistemos session [ID].
The session ended with a perceived hang (IKI spike detected at timestamp 1744.23s).
Files included:
- session_telemetry.json: 342 input events, 280s session duration
- snapshot_perceived-hang.json: runtime state at hang moment
- metrickit_diag.json: MetricKit diagnostics from this launch

Please analyze:
1. What input pattern immediately preceded the perceived hang?
2. Were modifier chords or paste events involved?
3. What was the thermal state and memory usage at the hang moment?
4. What does the MetricKit call stack suggest about which code was executing?
5. Is the hang reproducible — does the same pattern appear in earlier events?
```

The structured JSON format means Claude can reason directly over the sequence of events with precise timestamps, rather than parsing unstructured log text.[^17][^15]

### 5.3 Pattern Library — Building a Known-Bad Catalog

Over multiple sessions, maintain a `KnownBadPatterns.json` that catalogs confirmed edge cases:

```json
[
  {
    "id": "paste-during-ml-inference",
    "description": "Paste of >5000 chars while AI inference is running causes 3s stall",
    "trigger": "paste_length > 5000 AND ml_inference_active == true",
    "observed": 7,
    "firstSeen": "2026-03-15T14:22:00Z",
    "status": "fixed-in-build-204",
    "fix": "Defer paste processing until inference completes or yield inference"
  },
  {
    "id": "cmd-option-rapid-chord",
    "description": "⌘⌥ chord followed by immediate keydown within 15ms causes event tap to skip",
    "trigger": "iki_ms < 15 AND modifiers == cmdOption",
    "observed": 3,
    "status": "investigating"
  }
]
```

Every time you run a Claude analysis on a new diagnostic bundle and discover a pattern, add it here. Over time this becomes a **self-improving test suite** derived from real user behavior — edge cases that no QA engineer would have thought to test.

***

## Part VI — Required Permissions for the Full Stack

The complete hardened system requires these permissions and entitlements:

| Permission | Purpose | How to Request |
|------------|---------|----------------|
| Input Monitoring (`com.apple.developer.device-information.user-assigned-device-name`) | `CGEventTap` global events | System Settings → Privacy → Input Monitoring — user grants manually |
| Accessibility | `AXIsProcessTrusted` path | `AXIsProcessTrustedWithOptions` prompt |
| Screen Recording | `SCShareableContent` | `NSScreenCaptureUsageDescription` in Info.plist |
| `com.apple.security.screen-recording` | Entitlement for `replayd` | `.entitlements` file |

Note: Input Monitoring and Accessibility are **separate permissions** since macOS 10.15. Apps using `CGEventTap` need both. `NSEvent.addGlobalMonitorForEvents` only requires Input Monitoring, not Accessibility — if you can drop the Accessibility dependency for the event tap, do so.[^18][^19][^20]

The `CGEventTap` silent-disable race condition (re-signing causes silent failure) is a known macOS bug tracked by multiple app developers. The `EventTapHealthCheck` in Section 2.2 is the mitigation. There is currently no complete fix at the API level — the health check is the state of the art.[^13][^4]

***

## Part VII — Summary: The Hardening Flywheel

The compounding effect of this system is what makes it so powerful:

```
Real user session
       ↓
InputTelemetry records timing/shape metadata (never content)
       ↓
IKI spike / modifier pattern / paste event detected
       ↓
RuntimeSnapshot captured (thermal, memory, permission status, last 50 events)
       ↓
MetricKit delivers hang diagnostics with call stack
       ↓
Session labeled (clean / stall / crash)
       ↓
Export bundle → paste to Claude → get specific code-path analysis
       ↓
Fix identified → added to KnownBadPatterns.json
       ↓
Next build has regression guard for that specific pattern
       ↓
Real users hit it again → telemetry detects it earlier → ThermalGuard
       preempts before OS kills the app
       ↓
Repeat with higher fidelity every cycle
```

Each cycle tightens the loop between real-world usage and production hardening. The input telemetry is the continuous oracle — it tells you, with sub-millisecond precision, exactly what the user was doing when everything went wrong. Combined with the self-healing systems from the previous report, Epistemos evolves from a reactive "check the logs after the crash" workflow into a genuinely adaptive runtime that knows its own failure modes and acts to prevent them in real time.

---

## References

1. [A Review of Several Keystroke Dynamics Methods - arXiv](https://arxiv.org/html/2502.16177v1) - The timing features of keystrokes are latency and hold time [3] . Latency is the time between consec...

2. [Track keystroke timing for user analysis #1075 - GitHub](https://github.com/charmbracelet/crush/discussions/1075) - Record inter-keystroke timing data; Store timestamps for analysis; Consider privacy implications and...

3. [Stop Intercepting Keyboard Input While App Running - CGEventTap](https://stackoverflow.com/questions/14777259/stop-intercepting-keyboard-input-while-app-running-cgeventtap) - What is the correct way to stop watching keyboard event taps using CGEventTap? I am building a simpl...

4. [CGEvent Taps and Code Signing: The Silent Disable Race](https://danielraffel.me/til/2026/02/19/cgevent-taps-and-code-signing-the-silent-disable-race/) - Input Monitoring is required to listen for global events. Also note: if you use .defaultTap (not .li...

5. [Swift 3 CFRunLoopRun in Thread? - Stack Overflow](https://stackoverflow.com/questions/40706095/swift-3-cfrunlooprun-in-thread) - The main problem is the reference counting: You create a retained reference to the view controller w...

6. [A service class for monitoring global keyboard events in macOS ...](https://gist.github.com/stephancasas/fd27ebcd2a0e36f3e3f00109d70abcdc) - A service class for monitoring global keyboard events in macOS Swift applications. - CGEventSupervis...

7. [An in-depth look at the keylogger malware family - Moonlock](https://moonlock.com/keylogger-malware-family) - Requires Accessibility and Input Monitoring access. A Keylogger using CGEvent will request access to...

8. [Passwords are not protected by secure input entry in macOS #3307](https://github.com/keepassxreboot/keepassxc/issues/3307) - Expected Behavior Password fields that are not visible should be inaccessible to event taps by other...

9. [394380 - CG Event taps can steal email account passwords](https://bugzilla.mozilla.org/show_bug.cgi?id=394380) - Apple realized this could be a major security problem and implemented a way for processes to disallo...

10. [Technical Note TN2150: Using Secure Event Input Fairly](https://leopard-adc.pepas.com/technotes/tn2007/tn2150.html) - To protect against such access, Mac OS X provides the EnableSecureEventInput function for use with c...

11. [Global shortcut fails when focused field is a password field #17](https://github.com/lwouis/alt-tab-macos/issues/17) - It seems the current CGEvent.tapCreate hides keypresses on password fields. However, the OS has othe...

12. [How to get out of secure input, macOS Mojave](https://community.folivora.ai/t/how-to-get-out-of-secure-input-macos-mojave/5129) - Unfortunately there is no way to disable it. You need to figure out which app is enabling it, only t...

13. [sometimes event taps created with `CGEvent.tapCreate` stop ...](https://github.com/feedback-assistant/reports/issues/390) - This is a tricky one. It's been reported by a couple of users of my apps. And it happened to me 3 ti...

14. [Inter-Key Stroke Intervals - Forum](https://forum.cogsci.nl/discussion/7783/inter-key-stroke-intervals) - For an online experiment we are interested in the inter-key stroke intervals of participants, ie how...

15. [[PDF] Telemetry-Driven Predictive Failure Models for High-Scale Financial ...](https://eudoxuspress.com/index.php/pub/article/download/4835/3620/10239) - Telemetry-driven predictive failure modeling changes the raw infrastructure metrics into the early-w...

16. [Smartphone‐derived keystroke dynamics are sensitive to relevant ...](https://pmc.ncbi.nlm.nih.gov/articles/PMC9299491/) - Timing‐related keystroke features had the highest responsiveness to change in arm function and ambul...

17. [Monitoring app performance with MetricKit - Swift with Majid](https://swiftwithmajid.com/2025/12/09/monitoring-app-performance-with-metrickit/) - Xcode Organizer provides access to essential performance metrics such as crashes, energy impact, han...

18. [Control access to input monitoring on Mac - Apple Support](https://support.apple.com/guide/mac-help/control-access-to-input-monitoring-on-mac-mchl4cedafb6/mac) - Choose Apple menu > System Settings, then click Privacy & Security in the sidebar. (You may need to ...

19. [pqrs-org/osx-event-observer-examples - GitHub](https://github.com/pqrs-org/osx-event-observer-examples) - User approval of Accessibility and Input Monitoring is required to use iokit-hid-value-example since...

20. [openwhispr/CHANGELOG.md at main - GitHub](https://github.com/OpenWhispr/openwhispr/blob/main/CHANGELOG.md) - Removed Input Monitoring Requirement (macOS): Replaced CGEvent tap with NSEvent monitor for Globe/Fn...

