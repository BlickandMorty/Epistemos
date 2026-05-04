# Epistemos: Deep Diagnostics, Custom Logging, and Real-Time Self-Healing Architecture

## Executive Summary

The console dump from Epistemos revealed a cascading failure rooted in main-thread blocking, missing entitlements, and a misconfigured screen-capture stack. To go from reactive "paste the log to Claude" debugging to proactive, AI-ready diagnostics, Epistemos needs three integrated systems: (1) a structured, exportable in-app logging infrastructure built on Apple's Unified Logging System; (2) a real-time self-healing runtime that detects hangs, thermal stress, and degradation before the OS kills the process; and (3) targeted code fixes for each specific bug found in the log. This document covers all three in full.

***

## Part I — The Custom Logging Architecture

The goal is a logging system that, after a session, can be exported as a single structured file you can paste directly to Claude for a full analysis. Apple's `OSLog` framework is the foundation — it is more performant than `print()`, supports privacy controls, feeds into Console.app, and is query-able programmatically via `OSLogStore`.[^1][^2]

### 1.1 Logger Taxonomy — Subsystems and Categories

Every `Logger` instance in Epistemos should declare a **subsystem** (always `com.epistemos.app`) and a **category** matching the functional module. This is the Apple-recommended pattern and enables precise filtering in Console.app and in your export pipeline.[^3][^4]

```swift
import OSLog

extension Logger {
    private static let sub = "com.epistemos.app"

    // One static logger per module
    static let ui         = Logger(subsystem: sub, category: "ui")
    static let network    = Logger(subsystem: sub, category: "network")
    static let ai         = Logger(subsystem: sub, category: "ai-model")
    static let screenCap  = Logger(subsystem: sub, category: "screen-capture")
    static let perf       = Logger(subsystem: sub, category: "performance")
    static let entitle    = Logger(subsystem: sub, category: "entitlements")
    static let nightbrain = Logger(subsystem: sub, category: "nightbrain")
    static let heartbeat  = Logger(subsystem: sub, category: "heartbeat")
}
```

Log levels should be used deliberately:

| Level | Use in Epistemos |
|-------|----------------|
| `.debug` | Verbose state transitions (stripped in release builds) |
| `.info` | User actions, feature activations |
| `.notice` | Significant events worth always retaining |
| `.error` | Recoverable failures — permissions denied, network fail |
| `.fault` | Critical failures that indicate bugs — use sparingly |

### 1.2 The LogExporter — Programmatic OSLog Fetch

`OSLogStore` allows fetching your app's log entries programmatically and writing them to a file. The pattern below produces a clean, shareable text file:[^5][^6]

```swift
import OSLog
import Foundation

actor LogExporter {
    static let shared = LogExporter()

    // Export all logs from the past N hours, filtered to this app
    func export(hours: Double = 24) async throws -> URL {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let since = Date.now.addingTimeInterval(-hours * 3600)
        let position = store.position(date: since)
        let subsystem = Bundle.main.bundleIdentifier!

        let entries = try store
            .getEntries(at: position)
            .compactMap { $0 as? OSLogEntryLog }
            .filter { $0.subsystem == subsystem }

        var lines: [String] = [
            "=== EPISTEMOS LOG EXPORT ===",
            "Generated: \(Date.now.formatted())",
            "Period: Last \(Int(hours))h",
            "Entry count: \(entries.count)",
            "==="
        ]

        for entry in entries {
            let level = entry.level.debugDescription // "error", "fault", etc.
            let line = "[\(entry.date.formatted(.iso8601))] [\(entry.category)] [\(level)] \(entry.composedMessage)"
            lines.append(line)
        }

        let text = lines.joined(separator: "\n")
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .appendingPathComponent("epistemos_log_\(Int(Date.now.timeIntervalSince1970)).txt")
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
```

This creates a `.txt` file in the app's Documents folder. From a Settings screen, expose an **"Export Logs"** button that calls `LogExporter.shared.export()` and presents a share sheet. The result is a file you paste directly into Claude for analysis.[^5]

### 1.3 Parallel File Sink (For Persistence Beyond OSLog's Retention)

`OSLogStore` only retains entries for a limited time and may drop older entries. For long-lived diagnostic context, write a parallel lightweight file sink:[^7]

```swift
final class FileSink: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.epistemos.filesink", qos: .utility)
    private lazy var handle: FileHandle? = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .appendingPathComponent("Epistemos")
            .appendingPathComponent("runtime.log")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                  withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        return try? FileHandle(forWritingTo: url)
    }()

    func write(_ message: String, level: String, category: String) {
        queue.async { [weak self] in
            let line = "[\(Date.now.formatted(.iso8601))][\(category)][\(level)] \(message)\n"
            self?.handle?.seekToEndOfFile()
            self?.handle?.write(Data(line.utf8))
        }
    }
}
```

Use this for `fault` and `error` level messages only, to keep file sizes manageable. Rotate the file weekly.

### 1.4 MetricKit — Automatic Hang, Crash, and Performance Reports

MetricKit is Apple's framework for receiving structured diagnostics payloads — including hang stack traces, CPU exception reports, and crash diagnostics. On macOS 12+ and iOS 15+, `MXDiagnosticPayload` is delivered **immediately** after an event (not the next day).[^8][^9][^10]

```swift
import MetricKit

final class AppMetrics: NSObject, MXMetricManagerSubscriber {

    static let shared = AppMetrics()

    func start() {
        MXMetricManager.shared.add(self)
    }

    // Called immediately on hang/crash (macOS 12+)
    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            saveDiagnostic(payload)
        }
    }

    // Called daily with battery, memory, launch time, etc.
    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            saveMetric(payload)
        }
    }

    private func saveDiagnostic(_ payload: MXDiagnosticPayload) {
        guard let json = try? JSONSerialization.data(
            withJSONObject: payload.dictionaryRepresentation(),
            options: .prettyPrinted
        ) else { return }

        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .appendingPathComponent("metrickit_diag_\(Int(Date.now.timeIntervalSince1970)).json")
        try? json.write(to: url)

        // Log the hang callstacks to OSLog for immediate visibility
        payload.hangDiagnostics?.forEach { hang in
            Logger.perf.fault("HANG DETECTED: duration=\(hang.hangDuration) callStack=\(hang.callStackTree.description)")
        }
        payload.cpuExceptionDiagnostics?.forEach { cpu in
            Logger.perf.fault("CPU EXCEPTION: totalTime=\(cpu.totalCPUTime)")
        }
        payload.crashDiagnostics?.forEach { crash in
            Logger.perf.fault("CRASH: exceptionType=\(crash.exceptionType ?? "unknown") signal=\(String(describing: crash.signal))")
        }
    }

    private func saveMetric(_ payload: MXMetricPayload) {
        if let exits = payload.applicationExitMetrics?.backgroundExitData {
            Logger.perf.error("Exit metrics — abnormal: \(exits.cumulativeAbnormalExitCount), CPU: \(exits.cumulativeCPUResourceLimitExitCount), memory: \(exits.cumulativeMemoryResourceLimitExitCount)")
        }
    }
}
```

Register this in `applicationDidFinishLaunching`: `AppMetrics.shared.start()`.[^11]

The JSON files MetricKit writes contain full call stack trees for hangs. This is the single richest source of "why did this hang?" data. Export these to Claude along with the OSLog text dump for a full picture.[^12][^13]

***

## Part II — Real-Time Self-Healing Runtime

This is the "hard-need" system: code that detects degradation **as it happens** and takes corrective action before the user feels it or the OS kills the app.

### 2.1 Main Thread Watchdog (CFRunLoopObserver)

The force-kill (SIGKILL) in the log happened because the main thread was blocked long enough for the OS watchdog to trigger. A custom run-loop watchdog detects this earlier, logs diagnostics, and can preemptively reduce load.[^14][^15]

The mechanism: a `CFRunLoopObserver` timestamps the start of each run-loop iteration. A background thread periodically checks whether the current iteration has exceeded a threshold. If it has, the watchdog fires — logging a stall event with the active view controller, queue depth, and thermal state.[^14]

```swift
import Foundation

final class MainThreadWatchdog {
    static let shared = MainThreadWatchdog()

    private let threshold: TimeInterval = 1.5  // 1.5s stall = warning; 4s = critical
    private let serialQueue = DispatchQueue(label: "com.epistemos.watchdog")
    private var runLoopStartTime: TimeInterval = 0
    private var observer: CFRunLoopObserver?

    func start() {
        let secondsPerMachTime: Double = {
            var info = mach_timebase_info_data_t()
            mach_timebase_info(&info)
            return Double(info.numer) / Double(info.denom) / 1e9
        }()

        observer = CFRunLoopObserverCreateWithHandler(
            nil, CFRunLoopActivity.allActivities.rawValue, true, .min
        ) { [weak self] _, activity in
            guard let self else { return }
            switch activity {
            case .entry, .beforeTimers, .afterWaiting, .beforeSources:
                self.serialQueue.async {
                    if self.runLoopStartTime == 0 {
                        self.runLoopStartTime = Date().timeIntervalSince1970
                    }
                }
            case .beforeWaiting, .exit:
                self.serialQueue.async { self.runLoopStartTime = 0 }
            default: break
            }
        }

        if let obs = observer {
            CFRunLoopAddObserver(CFRunLoopGetMain(), obs, .commonModes)
        }

        enqueueBackgroundCheck(secondsPerMachTime: secondsPerMachTime)
    }

    private func enqueueBackgroundCheck(secondsPerMachTime: Double) {
        serialQueue.asyncAfter(deadline: .now() + threshold) { [weak self] in
            guard let self else { return }
            let start = self.runLoopStartTime
            guard start > 0 else {
                self.enqueueBackgroundCheck(secondsPerMachTime: secondsPerMachTime)
                return
            }
            let stalled = Date().timeIntervalSince1970 - start
            if stalled > self.threshold {
                let thermal = ProcessInfo.processInfo.thermalState
                Logger.perf.fault("⚠️ MAIN THREAD STALL: \(stalled, format: .fixed(precision: 2))s — thermal=\(thermal.rawValue)")
                // Trigger adaptive response
                ThermalGuard.shared.handleEmergencyStall(duration: stalled)
            }
            self.enqueueBackgroundCheck(secondsPerMachTime: secondsPerMachTime)
        }
    }
}
```

This approach is based on `CFRunLoopObserver` at `INT_MIN` priority so it catches even high-priority stalls like UI redrawing and animation layers.[^14]

### 2.2 Thermal State Monitor + Adaptive Load Reduction

The macOS thermal state API via `ProcessInfo.thermalState` and `NSProcessInfoThermalStateDidChangeNotification` allows the app to throttle itself before the system does it forcibly.[^16][^17]

For Epistemos, which runs an on-device LLM (`com.apple.fm.language.instruct3b`), this is critical: ML inference is extremely thermally expensive. The adaptive response should progressively reduce work:

```swift
import Foundation
import Combine

final class ThermalGuard: ObservableObject {
    static let shared = ThermalGuard()

    @Published private(set) var currentState: ProcessInfo.ThermalState = .nominal
    private var cancellable: AnyCancellable?

    func start() {
        // Register for thermal change notifications
        cancellable = NotificationCenter.default
            .publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in
                self?.handleThermalChange()
            }
        handleThermalChange() // Check immediately on startup
    }

    private func handleThermalChange() {
        let state = ProcessInfo.processInfo.thermalState
        currentState = state

        switch state {
        case .nominal:
            Logger.perf.info("Thermal: nominal — full performance")
            restoreFullPerformance()

        case .fair:
            Logger.perf.notice("Thermal: fair — reducing background work")
            deferNightbrainTasks()

        case .serious:
            Logger.perf.error("Thermal: serious — suspending ML inference, dropping frame rate")
            suspendMLInference()
            reduceRenderingQuality()

        case .critical:
            Logger.perf.fault("Thermal: CRITICAL — halting all non-essential work")
            haltAllBackgroundWork()

        @unknown default:
            break
        }
    }

    // Called from the watchdog when a 1.5s+ stall is detected
    func handleEmergencyStall(duration: TimeInterval) {
        Logger.perf.fault("Emergency stall response triggered: \(duration)s")
        suspendMLInference()
        cancelPendingScreenCapture()
    }

    // --- Adaptive Actions ---

    private func restoreFullPerformance() {
        NightbrainScheduler.shared.resume()
        MLInferenceEngine.shared.setMaxConcurrency(4)
    }

    private func deferNightbrainTasks() {
        NightbrainScheduler.shared.pause(reason: "thermal-fair")
    }

    private func suspendMLInference() {
        MLInferenceEngine.shared.suspendAllTasks()
        Logger.ai.error("ML inference suspended due to thermal/stall condition")
    }

    private func reduceRenderingQuality() {
        // e.g., drop from 60fps animation to 30fps, reduce blur effects
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .epistemosReduceRenderQuality, object: nil)
        }
    }

    private func haltAllBackgroundWork() {
        NightbrainScheduler.shared.haltAll()
        MLInferenceEngine.shared.suspendAllTasks()
        HeartbeatScheduler.shared.pause()
    }

    private func cancelPendingScreenCapture() {
        ScreenCaptureController.shared.cancelPendingRequests()
    }
}

extension Notification.Name {
    static let epistemosReduceRenderQuality = Notification.Name("com.epistemos.reduceRenderQuality")
}
```

At `.serious`, the app actively reduces its own CPU/GPU load — fanning down temperature before the OS takes drastic action. At `.critical`, it halts everything non-user-facing. This directly prevents the force-kill scenario seen in the log.[^17][^18]

### 2.3 Permission Preflight Guardian

Rather than discovering permission failures at runtime (when the user is trying to use a feature), a `PermissionGuardian` checks all required permissions on launch and logs their status clearly:

```swift
import AVFoundation
import ScreenCaptureKit
import AppKit

actor PermissionGuardian {
    static let shared = PermissionGuardian()

    func auditAllPermissions() async {
        await checkScreenRecording()
        checkAccessibility()
        Logger.entitle.info("Permission audit complete")
    }

    private func checkScreenRecording() async {
        // SCShareableContent requires Screen Recording permission
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            Logger.entitle.info("Screen Recording: GRANTED ✓")
        } catch {
            Logger.entitle.fault("Screen Recording: DENIED ✗ — error: \(error.localizedDescription, privacy: .public)")
            // Surface to UI: tell user Epistemos needs Screen Recording in Privacy settings
            await MainActor.run {
                PermissionBannerViewModel.shared.showBanner(for: .screenRecording)
            }
        }
    }

    private func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        if trusted {
            Logger.entitle.info("Accessibility: TRUSTED ✓")
        } else {
            Logger.entitle.error("Accessibility: NOT TRUSTED ✗ — prompting user")
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
            AXIsProcessTrustedWithOptions(options)
        }
    }
}
```

Call this in `applicationDidFinishLaunching` on a background task:
```swift
Task { await PermissionGuardian.shared.auditAllPermissions() }
```

This replaces the silent sandbox denies and TCC errors in the log with visible, logged, user-surfaced feedback.[^19][^20]

### 2.4 Thread Performance Checker (Xcode Scheme Setting)

Enable this immediately in Xcode — it requires zero code changes and catches all the main-thread violations shown in the log at development time:[^21][^22]

1. In Xcode, open **Product → Scheme → Edit Scheme**
2. Select **Run → Diagnostics**
3. Enable **Thread Performance Checker**

This alerts on priority inversions and non-UI work on the main thread while debugging, without requiring Instruments to be attached.[^22]

***

## Part III — Targeted Bug Fixes

### 3.1 P0: Move `trustd` / Certificate Validation Off Main Thread

The `fault`-level "Performance Diagnostics" message fires because something triggers a synchronous `trustd` connection on the main thread. This is almost certainly code that validates SSL certificates, checks keychain, or calls security APIs without dispatching to a background thread first.[^23][^14]

**Find it:** Enable Thread Performance Checker (Section 2.4). The stall will be flagged with a call stack pointing to the exact line.

**Fix pattern:**
```swift
// BEFORE (blocking main thread):
let cert = SecTrustEvaluate(trust, &result)  // on @MainActor

// AFTER (background actor):
actor SecurityEvaluator {
    func evaluate(_ trust: SecTrust) async -> SecTrustResultType {
        var result: SecTrustResultType = .invalid
        SecTrustEvaluate(trust, &result)
        return result
    }
}

// Call from any context safely:
let result = await SecurityEvaluator().evaluate(trust)
```

Any actor that is not `@MainActor` is guaranteed by Swift's concurrency model to execute on a background thread pool.[^24][^25]

For `AppKit` or `ScreenCaptureKit` calls that have async variants, prefer `async/await` directly:[^26][^27]

```swift
// Old blocking pattern:
SCShareableContent.getShareableContentExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in ... }

// Modern async pattern (automatically off main thread):
let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
```

### 3.2 P0: Screen Recording — Entitlements + Info.plist + Error Handling

Three required changes, each independently necessary:[^28][^29][^30]

**Step 1 — Info.plist:**
```xml
<key>NSScreenCaptureUsageDescription</key>
<string>Epistemos uses Screen Recording to analyze your open windows and provide context-aware AI assistance.</string>
```

**Step 2 — Entitlements file (`Epistemos.entitlements`):**
```xml
<key>com.apple.security.screen-recording</key>
<true/>
```

**Step 3 — Handle the completion error explicitly:**
```swift
func fetchShareableContent() async {
    do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        Logger.screenCap.info("SCShareableContent fetched: \(content.windows.count) windows, \(content.displays.count) displays")
        // proceed
    } catch let error as SCStreamError {
        switch error.code {
        case .userDeclined:
            Logger.screenCap.error("Screen Recording: user declined")
            showPermissionUI()
        case .entitlements:
            Logger.screenCap.fault("Screen Recording: missing entitlement (-3803)")
        default:
            Logger.screenCap.error("SCShareableContent error: \(error.localizedDescription, privacy: .public)")
        }
    } catch {
        Logger.screenCap.error("Unexpected SCShareableContent error: \(error.localizedDescription, privacy: .public)")
    }
}
```

On macOS 15 Sequoia, `SCShareableContent` (without using the system picker) triggers a monthly re-authorization prompt from `replayd`. This is the source of the 8 sandbox denies in the log. The app should gracefully handle cases where `replayd` denies access.[^31]

### 3.3 P1: Accessibility — Use Public AXIsProcessTrusted API

Never call `TCCAccessRequest` for `kTCCServiceAccessibility` directly — that's the private path that generated the TCC entitlement warning. Use the public API:[^19]

```swift
// Correct public API:
if !AXIsProcessTrusted() {
    // Prompt user by calling with options
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
    AXIsProcessTrustedWithOptions(options)
    Logger.entitle.notice("Accessibility permission not yet granted — showing system prompt")
}
```

This requires no entitlements and is fully sandboxable.[^20]

### 3.4 P2: Greymatter / Apple Intelligence Eligibility — Graceful Fallback

The `AFIsDeviceGreymatterEligible` error occurs because Epistemos queries whether the device supports Apple Intelligence, but the required internal entitlement isn't present in development builds. Since this is a managed capability (Apple must approve it), gate the feature with a graceful fallback:[^32][^33]

```swift
enum AICapability {
    static var isAppleIntelligenceAvailable: Bool {
        // Check model bundle exists and device is eligible
        // Returns false in dev builds — this is expected
        guard #available(macOS 15, *) else { return false }
        // Use public FoundationModels / WritingTools availability API when available
        return false  // fallback until entitlement is granted
    }
}

// In initialization:
if AICapability.isAppleIntelligenceAvailable {
    Logger.ai.info("Apple Intelligence: available — using on-device model")
    // initialize ModelBundle
} else {
    Logger.ai.notice("Apple Intelligence: unavailable — falling back to server-side model")
    // initialize fallback
}
```

The APTicket / EAN / `MGSysConfigPolicy` errors are harmless on Mac developer builds and require no fix — they self-resolve on real devices.[^34]

### 3.5 P2: Cursor Controller Stall — Throttle `scheduleUpdateCursorLocation`

The log shows `scheduleUpdateCursorLocation` firing dozens of times per second and `TUINSCursorUIController` creating and destroying `CursorUIViewService` repeatedly. This is almost always caused by a layout pass, scroll event, or animation loop that triggers cursor updates at every frame. Add a debounce:

```swift
private var cursorUpdateWorkItem: DispatchWorkItem?

func scheduleCursorUpdate() {
    cursorUpdateWorkItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
        self?.performCursorUpdate()
    }
    cursorUpdateWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)  // 50ms debounce
}
```

This collapses dozens of rapid-fire cursor update requests into a single execution per 50ms window, dramatically reducing `ViewBridge` churn.[^14]

***

## Part IV — The AI-Ready Log Export Workflow

The complete workflow for getting a deep analysis from Claude after a session:

### 4.1 What to Export

Collect three categories of data:

| Source | File | Content |
|--------|------|---------|
| `OSLogExporter` | `epistemos_log_*.txt` | Structured timestamped app logs |
| `MetricKit` | `metrickit_diag_*.json` | Hang stacks, crash diagnostics, CPU exceptions |
| `FileSink` | `runtime.log` | Persistent error/fault log since last rotation |

### 4.2 Export Button Implementation

```swift
// In SettingsView or a debug menu:
Button("Export Diagnostic Report") {
    Task {
        async let logFile = LogExporter.shared.export(hours: 24)
        // Collect MetricKit files from Documents directory
        let diagFiles = try FileManager.default.contentsOfDirectory(
            at: documentsURL, includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("metrickit_diag") }

        let allFiles = try await [logFile] + diagFiles
        // Present share sheet
        let picker = NSSharingServicePicker(items: allFiles.map { $0 as Any })
        picker.show(relativeTo: .zero, of: sender, preferredEdge: .minY)
    }
}
```

### 4.3 Prompting Claude for Analysis

When pasting the exported files, include context:

```
Here is a diagnostic export from Epistemos (macOS app, bundle com.epistemos.app).
The export covers the last 24 hours and includes:
- runtime.log (OSLog entries, fault/error level)
- metrickit_diag_*.json (MetricKit hang/crash diagnostics)

Please analyze:
1. Any hangs, stalls, or crashes with call stacks
2. Permission or entitlement failures
3. Patterns suggesting main-thread blocking
4. Thermal state warnings
5. Any repeated errors suggesting a code loop or retry storm
```

The structured format — timestamps, categories, severity levels — makes Claude's analysis significantly more precise and actionable than raw system console output.

### 4.4 In-App "Epistemos Diagnostics" Screen

Build a dedicated diagnostics view accessible from a hidden settings gesture (e.g., long-press the app icon or a debug menu):

```
┌─────────────────────────────────────────────────────┐
│  EPISTEMOS DIAGNOSTICS                              │
├─────────────────────────────────────────────────────┤
│  Thermal State:    🟢 Nominal                        │
│  Main Thread:      🟢 No stalls (last 1h)            │
│  Screen Recording: 🔴 Permission denied              │
│  Accessibility:    🟢 Trusted                        │
│  MetricKit Hangs:  ⚠️  1 hang (last 24h)            │
│  Last Crash:       None                             │
├─────────────────────────────────────────────────────┤
│  [Export Full Report]    [Clear Logs]               │
└─────────────────────────────────────────────────────┘
```

***

## Part V — Structured Action Plan for Claude Code

Present this ordered list to Claude Code for implementation:

### Immediate (Before Next Build)
1. **Enable Thread Performance Checker** in Xcode scheme diagnostics — zero code change, immediate stall detection
2. **Add `NSScreenCaptureUsageDescription`** to Info.plist and `com.apple.security.screen-recording` to entitlements
3. **Wrap `SCShareableContent` call in async/await** and handle `SCStreamError.userDeclined` and `.entitlements` explicitly
4. **Replace TCC direct call** for Accessibility with `AXIsProcessTrusted()` + `AXIsProcessTrustedWithOptions()`
5. **Register `AppMetrics` with `MXMetricManager`** in AppDelegate — immediately starts collecting hang diagnostics

### Short Term (Next Sprint)
6. **Implement `MainThreadWatchdog`** with `CFRunLoopObserver` — threshold 1.5s warning, 4s critical
7. **Implement `ThermalGuard`** subscribing to `NSProcessInfoThermalStateDidChangeNotification` — reduce ML inference at `.serious`, halt at `.critical`
8. **Add Logger taxonomy** (8 categories) throughout codebase, replacing `print()` statements
9. **Add 50ms debounce** to `scheduleUpdateCursorLocation`
10. **Add `PermissionGuardian`** audit on launch

### Medium Term (One Month)
11. **Build `LogExporter`** with `OSLogStore` — export to sharable text file
12. **Build FileSink** for persistent error/fault log
13. **Add `PermissionBannerViewModel`** to surface permission failures in UI
14. **Build Diagnostics Screen** with real-time status indicators
15. **Gate Greymatter/Apple Intelligence** features with availability check and graceful fallback

***

## Architectural Summary

The full system, integrated:

```
┌─────────────────────────────────────────────────────────────┐
│                     EPISTEMOS RUNTIME                        │
├──────────────┬──────────────────┬───────────────────────────┤
│ DETECTION    │  REACTION        │  LOGGING                  │
├──────────────┼──────────────────┼───────────────────────────┤
│ MainThread   │ → Suspend ML     │ OSLog (8 categories)       │
│ Watchdog     │   inference      │ Logger.perf.fault(...)     │
│              │   Cancel screen  │                           │
│              │   capture        │                           │
├──────────────┼──────────────────┼───────────────────────────┤
│ ThermalGuard │ → Reduce concur- │ Logger.perf.error(...)     │
│ (NSProcess-  │   rency          │ Thermal state logged       │
│  Info)       │ → Pause nightbr- │ on every state change      │
│              │   ain/heartbeat  │                           │
├──────────────┼──────────────────┼───────────────────────────┤
│ Permission   │ → Show banner UI │ Logger.entitle.fault(...)  │
│ Guardian     │ → Disable featu- │ Audit logged on launch     │
│              │   res gracefully │                           │
├──────────────┴──────────────────┼───────────────────────────┤
│         MetricKit               │ FileSink (persistent)      │
│  MXDiagnosticPayload immediate  │ → runtime.log              │
│  Hang stacks + crash reports    │ → metrickit_diag_*.json    │
├─────────────────────────────────┴───────────────────────────┤
│                  EXPORT PIPELINE                             │
│  OSLogStore → filtered text → shareable file                │
│  MetricKit JSON → shareable file                            │
│  [Export Report button] → paste to Claude → analysis       │
└─────────────────────────────────────────────────────────────┘
```

Each layer is independently valuable: detection prevents force-kills, reaction preserves user experience, and logging produces the rich diagnostic exports that make AI-assisted debugging of Epistemos both practical and precise.

---

## References

1. [Modern logging with the OSLog framework in Swift - Donny Wals](https://www.donnywals.com/modern-logging-with-the-oslog-framework-in-swift/) - In this post, I'd like to show you how you can set up a Logger from the OSLog framework in your app,...

2. [Generating Log Messages from Your Code - Apple Developer](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code) - In Swift, create a Logger structure and use its methods to generate log messages. · In Objective-C, ...

3. [OSLog and Unified logging as recommended by Apple - SwiftLee](https://www.avanderlee.com/debugging/oslog-unified-logging/) - Create structured logging using OSLog and benefit from Xcode's debugging console using filters and c...

4. [Debug with structured logging - WWDC23 - Videos - Apple Developer](https://developer.apple.com/videos/play/wwdc2023/10226/) - Discover the debug console in Xcode 15 and learn how you can improve your diagnostic experience thro...

5. [Exporting data from Unified Logging System in Swift](https://swiftwithmajid.com/2022/04/19/exporting-data-from-unified-logging-system-in-swift/) - This week we will talk about exporting logs from the user devices by leveraging the power of the Uni...

6. [Fetching OSLog Messages in Swift - Use Your Loaf](https://useyourloaf.com/blog/fetching-oslog-messages-in-swift/) - Use the OSLog framework to access logged messages programmatically. Luckily Peter Steinberger shared...

7. [OSLog in Swift macro doesn't persist original file/line number](https://stackoverflow.com/questions/77174072/oslog-in-swift-macro-doesnt-persist-original-file-line-number) - I need to log to OSLog and into a file in parallel (due to OSLogStore not being able to provide old ...

8. [Optimize your iOS app perfomance using MetricKit - Bugfender](https://bugfender.com/blog/ios-app-perfomance-metrickit/) - MetricKit automatically collects performance metrics for your app, so you will be able to achieve a ...

9. [MetricKit MXDiagnosticPayload Integration · Issue #1661 - GitHub](https://github.com/getsentry/sentry-cocoa/issues/1661) - The system delivers metric reports about the previous 24 hours to a registered app at most once per ...

10. [MetricKit | Sentry for macOS](https://docs.sentry.io/platforms/apple/guides/macos/configuration/metric-kit/) - The MetricKit integration subscribes to MXHangDiagnostic , MXDiskWriteExceptionDiagnostic and MXCPUE...

11. [Monitoring app performance with MetricKit - Swift with Majid](https://swiftwithmajid.com/2025/12/09/monitoring-app-performance-with-metrickit/) - Xcode Organizer provides access to essential performance metrics such as crashes, energy impact, han...

12. [MXDiagnosticPayload | Apple Developer Documentation](https://developer.apple.com/documentation/metrickit/mxdiagnosticpayload) - var hangDiagnostics: [MXHangDiagnostic]?. The diagnostic reports for times when the app was too busy...

13. [hangDiagnostics | Apple Developer Documentation](https://developer.apple.com/documentation/metrickit/mxdiagnosticpayload/hangdiagnostics) - The diagnostic reports for times when the app was too busy to handle input responsively during the r...

14. [Implementing a main thread watchdog on iOS - Jesse Squires](https://www.jessesquires.com/blog/2022/08/11/implementing-a-main-thread-watchdog-on-ios/) - We can write our own main thread watchdog and add custom logging to our apps to help diagnose the ro...

15. [A watchdog timer for iOS to detect when the main run loop is stalled](https://gist.github.com/roostr/ead83858291ce3ce214fcf8ead3cd825) - A watchdog timer for iOS to detect when the main run loop is stalled - Watchdog.swift. ... // I'm go...

16. [Building a macOS app to know when my Mac is thermal throttling](https://stanislas.blog/2025/12/macos-thermal-throttling-app/) - How I built MacThrottle, a menu bar app that tells me when my Mac is thermal throttling, and the jou...

17. [Respond to Thermal State Changes - Apple Developer](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/RespondToThermalStateChanges.html) - An app can query the current thermal state of a device at any time by accessing the thermalState pro...

18. [ProcessInfo.ThermalState.serious | Apple Developer Documentation](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum/serious) - The system takes moderate steps to reduce thermal state, which reduces performance. Fans are running...

19. [Diagnosing Issues with Entitlements | Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/diagnosing-issues-with-entitlements) - If you see errors in your build log related to an entitlement that you added to one of your entitlem...

20. [Can't add app to accessibility permissions - Apple Support Community](https://discussions.apple.com/thread/251754247) - You may need to reinstall the program. It should push its Accessibility plugins upon installation, a...

21. [WWDC22: Track down hangs with Xcode and on-device detection](https://www.youtube.com/watch?v=BAUc15xKw0I) - Learn how you can increase responsiveness and eliminate hangs in your app and make even better exper...

22. [Track down hangs with Xcode and on-device detection - Vidéos](https://developer.apple.com/fr/videos/play/wwdc2022/10082/?time=376) - On-device hang detection provides hang detection without using Xcode or tracing, providing real-time...

23. [How to do lengthy operations without being killed by the watchdog ...](https://stackoverflow.com/questions/8536176/how-to-do-lengthy-operations-without-being-killed-by-the-watchdog-iphone) - The watchdog timer will kill an application that jams up the main thread for an extremely long perio...

24. [Guaranteeing an actor executes off the main thread - Swift Forums](https://forums.swift.org/t/guaranteeing-an-actor-executes-off-the-main-thread/75009) - Every actor which is not the main actor executes on a background thread; this is actually a public g...

25. [Thread dispatching and Actors: understanding execution - SwiftLee](https://www.avanderlee.com/concurrency/thread-dispatching-actor-execution/) - Actors ensure your code is executed on a specific thread, like the main or a background thread. They...

26. [How to Use Async/Await in Swift Concurrency - OneUptime](https://oneuptime.com/blog/post/2026-02-02-swift-async-await-concurrency/view) - Master Swift's modern concurrency model with async/await, tasks, actors, and structured concurrency ...

27. [Meet async/await in Swift - WWDC21 - Videos - Apple Developer](https://developer.apple.com/videos/play/wwdc2021/10132/) - Swift now supports asynchronous functions — a pattern commonly known as async/await. Discover how th...

28. [What's new in ScreenCaptureKit - WWDC23 - Videos](https://developer.apple.com/videos/play/wwdc2023/10136/) - Level up your screen sharing experience with the latest features in ScreenCaptureKit. Explore the bu...

29. [ScreenCaptureKit macOS xcode13.3 beta1 - GitHub](https://github.com/xamarin/xamarin-macios/wiki/ScreenCaptureKit-macOS-xcode13.3-beta1/8446e483b9fef9a18713baa120182992fc533e08) - NET for iOS, Mac Catalyst, macOS, and tvOS provide open-source bindings of the Apple SDKs for use wi...

30. [Meet ScreenCaptureKit - WWDC22 - Videos - Apple Developer](https://developer.apple.com/la/videos/play/wwdc2022/10156/) - Learn how ScreenCaptureKit can deliver high-performance screen capture for your macOS screen sharing...

31. [Disable Sequoia's monthly screen recording permission prompt](https://tinyapps.org/blog/202409180700_disable_sequoia_nag.html) - Rather than logging off, I force-quit replayd via Activity Monitor, and macOS automatically restarte...

32. [Capability Requests - Capabilities - Account - Help - Apple Developer](https://developer.apple.com/help/account/capabilities/capability-requests/) - Managed capabilities are app services that need an entitlement assigned to your account by Apple bef...

33. [Apple Intelligence | Apple Developer Forums](https://developer.apple.com/forums/topics/machine-learning-and-ai/machine-learning-and-ai-topic-apple-intelligence?sortBy=activity&sortOrder=asc&open-dropdown=true) - Apple Intelligence is the personal intelligence system that puts powerful ... app-server AND origina...

34. [Are You Measuring Your App's Performance? You're Probably ...](https://engineering.teknasyon.com/are-you-measuring-your-apps-performance-you-re-probably-doing-it-wrong-introduction-to-metrickit-57eed3dd2350) - Handling MXDiagnosticPayload — Crash & Hang Reports. Diagnostic data (like crashes and app hangs) is...

