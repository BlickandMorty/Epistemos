# Epistemos: Zero-Copy, Zero-Latency Implementation Masterclass

> **Audience:** Claude Code executing a one-shot, production-safe implementation of four cognitive substrates.
> **Stack:** Swift + Rust + Metal + GRDB/SQLite WAL + HNSW + NSTextView OpLog + ScreenCaptureKit/AXUIElement + NSBackgroundActivityScheduler on Apple Silicon.
> **Mandate:** Surgically extend existing systems. No new storage layers. No second scheduler. No main-thread heavy work. Every phase ends with passing tests before the next begins.

***

## Executive Architecture Principle

The entire prompt collapses to a single constraint: **zero marginal cost when idle, bounded cost when active, zero duplication of existing subsystems.** Apple Silicon's unified memory architecture makes this achievable — `MTLStorageMode.shared` means the same physical bytes are visible to CPU, GPU, and Neural Engine simultaneously with no copy. The right design never moves data that doesn't have to move. Every phase below is structured around that invariant.[^1][^2]

***

## Phase 0 — Shared Substrate

### GRDB Migration Strategy

The EventStore already owns the SQLite connection; extend it, never fork it. Register a single new migration named `"epistemos_v2_substrates"` inside the existing `DatabaseMigrator` chain. All four new tables go in one migration block — this ensures atomicity: either all four exist or none do, with no partial-state risk on crash.[^3][^4]

```swift
migrator.registerMigration("epistemos_v2_substrates") { db in
    try db.create(table: "captured_artifacts", ifNotExists: true) { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("source_bundle_id", .text).notNull()
        t.column("app_name", .text).notNull()
        t.column("window_title", .text)
        t.column("url", .text)
        t.column("text_content", .text)
        t.column("captured_at", .integer).notNull().indexed()
        t.column("dedupe_hash", .text).notNull().unique()
        t.column("ocr_used", .boolean).notNull().defaults(to: false)
    }
    try db.create(table: "friction_windows", ifNotExists: true) { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("note_id", .text).notNull().indexed()
        t.column("session_id", .text).notNull().indexed()
        t.column("window_start", .integer).notNull().indexed()
        t.column("window_end", .integer).notNull()
        t.column("pause_rate", .double).notNull()
        t.column("mean_pause_duration_ms", .double).notNull()
        t.column("mean_burst_length_chars", .double).notNull()
        t.column("burst_length_cv", .double).notNull()
        t.column("deletion_density", .double).notNull()
        t.column("regression_frequency", .double).notNull()
        t.column("friction_score", .double).notNull()
    }
    try db.create(table: "night_brain_runs", ifNotExists: true) { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("started_at", .integer).notNull().indexed()
        t.column("completed_at", .integer)
        t.column("status", .text).notNull()  // "running","completed","interrupted","deferred"
        t.column("jobs_completed", .text).notNull().defaults(to: "[]")  // JSON array
        t.column("trigger_reason", .text)
    }
    try db.create(table: "night_brain_checkpoints", ifNotExists: true) { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("run_id", .integer).notNull().indexed()
            .references("night_brain_runs", onDelete: .cascade)
        t.column("job_type", .text).notNull()
        t.column("checkpoint_data", .text).notNull()  // JSON payload per job type
        t.column("recorded_at", .integer).notNull()
    }
}
```

WAL mode is already on via `DatabasePool`. Do not touch journal mode or page size — the migration runs inside the existing pool's write connection and WAL guarantees that concurrent readers see the old schema until the migration commits. Indexed `captured_at`, `window_start`, and `started_at` columns ensure timestamp-range scans remain O(log N) rather than O(N) full-table-scans. The `dedupe_hash` UNIQUE index is the zero-cost deduplication fence — SQLite rejects duplicate inserts at the constraint level without application logic.[^5][^6]

**GRDB 7 note:** GRDB 7 (Swift 6.1+) moved all async database accesses to honor Task cancellation and eliminated `DatabasePool.concurrentRead`. If the project is on GRDB 7, use `try await dbPool.read { ... }` and `try await dbPool.write { ... }` throughout — do not call legacy synchronous APIs from Swift 6 concurrency contexts.[^7][^8]

### Domain Types

Define these as plain `Sendable` structs — no class overhead, no reference counting in hot paths, trivially copyable across actor boundaries:

```swift
struct CapturedArtifact: Codable, FetchableRecord, PersistableRecord, Sendable {
    var id: Int64?
    var sourceBundleId: String
    var appName: String
    var windowTitle: String?
    var url: String?
    var textContent: String
    var capturedAt: Int64   // Unix ms
    var dedupeHash: String
    var ocrUsed: Bool
}

struct FrictionWindow: Codable, FetchableRecord, PersistableRecord, Sendable {
    var id: Int64?
    var noteId: String
    var sessionId: String
    var windowStart: Int64
    var windowEnd: Int64
    var pauseRate: Double
    var meanPauseDurationMs: Double
    var meanBurstLengthChars: Double
    var burstLengthCV: Double
    var deletionDensity: Double
    var regressionFrequency: Double
    var frictionScore: Double
}

struct NightBrainRun: Codable, FetchableRecord, PersistableRecord, Sendable {
    var id: Int64?
    var startedAt: Int64
    var completedAt: Int64?
    var status: String
    var jobsCompleted: String   // JSON [String]
    var triggerReason: String?
}

struct NightBrainCheckpoint: Codable, FetchableRecord, PersistableRecord, Sendable {
    var id: Int64?
    var runId: Int64
    var jobType: String
    var checkpointData: String  // JSON
    var recordedAt: Int64
}
```

### EpistemosConfig — Unified Feature Flags

Scatter no toggles. A single `@Observable` config object backed by `UserDefaults` covers every threshold the prompts mention. Wire it to `AppEnvironment` once and inject via SwiftUI's `withAppEnvironment()`. This pattern mirrors what GRDB recommends for single-row config: use `UserDefaults` so adding a new key has zero migration cost.[^9]

```swift
@Observable
final class EpistemosConfig {
    // Cross-app capture
    @ObservationIgnored @AppStorage("capture.enabled") var captureEnabled = false
    @ObservationIgnored @AppStorage("capture.ocrFallback") var ocrFallbackEnabled = true
    @ObservationIgnored @AppStorage("capture.allowlist") var allowlistJSON = "[]"
    @ObservationIgnored @AppStorage("capture.blocklist") var blocklistJSON = "[]"
    // Friction
    @ObservationIgnored @AppStorage("friction.enabled") var frictionEnabled = true
    @ObservationIgnored @AppStorage("friction.windowSeconds") var frictionWindowSeconds = 600.0
    @ObservationIgnored @AppStorage("friction.threshold") var frictionThreshold = 1.5
    // Night Brain
    @ObservationIgnored @AppStorage("nightbrain.enabled") var nightBrainEnabled = true
    @ObservationIgnored @AppStorage("nightbrain.requiresAC") var nightBrainRequiresAC = true
    @ObservationIgnored @AppStorage("nightbrain.minIdleSeconds") var nightBrainMinIdleSeconds = 300.0
    // Graph
    @ObservationIgnored @AppStorage("graph.freezeLayout") var freezeLayout = false
}
```

### AppBootstrap Wiring

Instantiate all new services in `AppBootstrap.setup()` — the single place where services are born. Only expose to `AppEnvironment` if a view needs the service. `AmbientCaptureService` needs a review-UI surface, so it goes in the environment. `FrictionMonitorService` is pure background — it reads from the editor but its output only surfaces in session summaries, so it does not need to be view-visible at init time.[^10]

```swift
// In AppBootstrap
let epistemosConfig = EpistemosConfig()
let ambientCapture = AmbientCaptureService(db: eventStore.dbPool, config: epistemosConfig)
let frictionMonitor = FrictionMonitorService(db: eventStore.dbPool, config: epistemosConfig)
let nightBrain = NightBrainService(db: eventStore.dbPool,
                                    workspaceService: workspaceService,
                                    config: epistemosConfig)
// Wire graph controls into existing GraphState — no new service object needed
```

**Phase 0 tests:**
1. Run migration on an empty DB — assert all four tables exist via `try db.tableExists("captured_artifacts")` etc.
2. Run migration on a DB that already has existing EventStore tables — assert existing tables are untouched.
3. Read existing EventStore queries (events, notes, workspaces) after migration — assert zero result-set changes.
4. Assert `DatabasePool` WAL mode is still active: `try db.execute(sql: "PRAGMA journal_mode")` returns `"wal"`.
5. `AppBootstrap` initializes cleanly in unit test harness — assert no crashes, no leaked threads.

***

## Phase 1 — Ambient Cross-App Capture Substrate

### Architecture: Event-Driven, Never Polling

The research literature is unambiguous: AXObserver at <1 wake/second consumes under 0.3% CPU idle vs. 3–8% for 500ms polling on a complex app. The hybrid architecture is a three-tier funnel:[^11]

```
Tier 0 (zero AX cost):
  NSWorkspace.didActivateApplicationNotification
  → debounce 300ms
  → check allowlist/blocklist
  → schedule async capture (returns immediately to main thread)

Tier 1 (low-cost AX observer for frontmost app):
  kAXFocusedUIElementChangedNotification
  kAXSelectedTextChangedNotification (debounce 300ms)
  → read kAXSelectedTextAttribute on background thread via async dispatch

Tier 2 (OCR fallback, only when AX sparse AND ocrFallbackEnabled):
  SCContentFilter(desktopIndependentWindow:)
  VNRecognizeTextRequest (.fast mode: ~20-50ms on M-series)
  → new VNRecognizeTextRequest per image (not thread-safe, must not share)
```

The critical constraint from the research: AX API calls must originate from the main thread. The recommended architecture has Swift handling all AX interactions on the main thread, then handing the raw text to Rust or a background Swift actor for hashing, redaction, and storage. AX calls return quickly (microseconds for `kAXSelectedTextAttribute`); the work that takes time (OCR, hashing, DB write) happens off-thread.[^11]

### AmbientCaptureService

```swift
actor AmbientCaptureService {
    private let db: DatabasePool
    private let config: EpistemosConfig
    private var lastCaptureHash: [String: String] = [:]  // bundleId → last hash
    private var debounceTask: Task<Void, Never>?
    private static let dedupeWindowMs: Int64 = 30_000  // 30s

    // Called from main thread via NSWorkspace observer
    nonisolated func appDidActivate(pid: pid_t, bundleId: String, appName: String) {
        Task { await self.handleActivation(pid: pid, bundleId: bundleId, appName: appName) }
    }

    private func handleActivation(pid: pid_t, bundleId: String, appName: String) async {
        guard config.captureEnabled else { return }
        guard !isBlocked(bundleId) else { return }
        // Debounce: cancel any in-flight capture for rapid app switches
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms
            guard !Task.isCancelled else { return }
            await performCapture(pid: pid, bundleId: bundleId, appName: appName)
        }
    }

    // AX work MUST hop to main thread; text processing goes back to actor
    private func performCapture(pid: pid_t, bundleId: String, appName: String) async {
        // Hop to main thread for AX
        let axResult = await MainActor.run { readAXText(pid: pid) }
        let text: String
        if let axText = axResult, !axText.isEmpty {
            text = axText
        } else if config.ocrFallbackEnabled {
            guard let screenshot = await captureWindowScreenshot(pid: pid) else { return }
            text = await performOCR(on: screenshot) ?? ""
        } else {
            return
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let redacted = redactSecrets(text)
        let hash = stableHash(bundleId + redacted)
        // Deduplication
        if lastCaptureHash[bundleId] == hash { return }
        lastCaptureHash[bundleId] = hash
        let artifact = CapturedArtifact(
            sourceBundleId: bundleId, appName: appName,
            textContent: redacted, capturedAt: nowMs(),
            dedupeHash: hash, ocrUsed: axResult == nil
        )
        try? await db.write { db in
            // INSERT OR IGNORE respects the UNIQUE constraint on dedupe_hash
            try artifact.insert(db, onConflict: .ignore)
        }
    }
}
```

**AX text reading (main thread only):**

```swift
@MainActor
private func readAXText(pid: pid_t) -> String? {
    let appElement = AXUIElementCreateApplication(pid)
    AXUIElementSetMessagingTimeout(appElement, 0.5)  // Never hang waiting for AX
    var focusedElement: CFTypeRef?
    guard AXUIElementCopyAttributeValue(appElement,
        kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
          let focused = focusedElement else { return nil }
    let axElement = focused as! AXUIElement
    var selectedText: CFTypeRef?
    guard AXUIElementCopyAttributeValue(axElement,
        kAXSelectedTextAttribute as CFString, &selectedText) == .success,
          let text = selectedText as? String, text.count > 20 else { return nil }
    return text
}
```

**Secret redaction (research-validated regex patterns):**

```swift
private func redactSecrets(_ text: String) -> String {
    let patterns = [
        #"(?i)(api[_-]?key|token|password|secret|bearer)\s*[:=]\s*\S+"#,
        #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"#,  // emails
        #"\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b"#,              // card numbers
        #"\b\d{3}-\d{2}-\d{4}\b"#                                   // SSN
    ]
    var result = text
    for pattern in patterns {
        result = result.replacingOccurrences(of: pattern, with: "[REDACTED]",
                                             options: .regularExpression)
    }
    return result
}
```

**OCR — never share VNRecognizeTextRequest across threads:**

Per the Vision framework documentation and community reports, `VNRecognizeTextRequest` is not thread-safe — create one per image. Use `.fast` recognition level (~20–50ms on M-series) for background capture; `.accurate` only on explicit user request.[^11]

```swift
private func performOCR(on image: CGImage) async -> String? {
    return await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .utility).async {
            let request = VNRecognizeTextRequest()  // fresh instance per call
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([request])
            let text = request.results?.compactMap { $0.topCandidates(1).first?.string }
                             .joined(separator: " ")
            continuation.resume(returning: text)
        }
    }
}
```

**Phase 1 tests:**
1. Blocked bundle ID → `AmbientCaptureService.handleActivation` completes without DB write (assert `captured_artifacts` row count unchanged).
2. Same source hash twice within 30s window → second write is ignored (UNIQUE constraint + `onConflict: .ignore`).
3. Sparse AX (return nil from `readAXText`) + `ocrFallbackEnabled=true` → `performOCR` called.
4. Rich AX (return text from `readAXText`) → `performOCR` never called.
5. Secret-pattern string injected → stored artifact has `[REDACTED]` in `text_content`.
6. Main-thread test: `appDidActivate` returns in <1ms (Task is dispatched, not awaited inline).

***

## Phase 2 — Friction Detection Substrate

### Why Not Rust FFI for Per-Event Processing

The research from the cross-cutting architecture section is explicit: do not send every keystroke through Rust FFI. FFI crossings are not free — each call involves marshal/unmarshal overhead and potential thread hops. For editor telemetry arriving at 5–15 events/second during active typing, this cost accumulates. The correct pattern: consume events in Swift with a dedicated actor; produce aggregated `FrictionWindow` rows to GRDB; let Rust consume those rows asynchronously for any downstream analysis.[^11]

### FrictionMonitorService — Ring Buffer Architecture

The research validates a dual-window system: a short event window (N=50 events ≈ 1–2 minutes) for high-frequency signals and a long time window (T=10 minutes) for trend signals. Both must use bounded ring buffers — never unbounded arrays. Below is a `struct`-based ring buffer that avoids per-event heap allocation:[^11]

```swift
struct RingBuffer<T> {
    private var storage: [T?]
    private var writeIndex: Int = 0
    private var count: Int = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.storage = Array(repeating: nil, count: capacity)
    }

    mutating func push(_ value: T) {
        storage[writeIndex % capacity] = value
        writeIndex = (writeIndex + 1) % capacity
        count = min(count + 1, capacity)
    }

    func toArray() -> [T] {
        guard count > 0 else { return [] }
        let start = count < capacity ? 0 : writeIndex
        return (0..unt).compactMap { storage[(start + $0) % capacity] }
    }
}
```

### Editor Hooks — Existing Mutation Seams Only

The prompt is explicit: hook only the existing seams in `ProseEditorRepresentable2`/`ProseTextView2`. The correct hook points are `textDidChange`, selection-change delegate, and AI accept/discard events. Nothing new is added to the render path.[^10]

```swift
// Extension on ProseTextView2 — add to existing textDidChange
extension ProseTextView2 {
    func notifyFrictionMonitor(event: EditorTelemetryEvent) {
        // Nonisolated: safe to call from any context
        // FrictionMonitorService is an actor — hop is scheduled, not blocking
        Task.detached(priority: .utility) {
            await FrictionMonitorService.shared.record(event)
        }
    }
}
```

### EditorTelemetryEvent and FrictionMonitorService

```swift
struct EditorTelemetryEvent: Sendable {
    enum Kind { case insertion(count: Int), deletion(count: Int, isImmediate: Bool),
                     cursorMove(delta: Int), pauseEnd, aiStreamEnd }
    let noteId: String
    let sessionId: String
    let kind: Kind
    let timestampMs: Int64
    let isFrontierPosition: Bool  // cursor at text end vs. regression
}

actor FrictionMonitorService {
    static let shared = FrictionMonitorService()
    private let db: DatabasePool
    private var eventBuffer: RingBuffer<EditorTelemetryEvent> = RingBuffer(capacity: 200)
    private var sessionStart: Int64 = 0
    private var lastEventMs: Int64 = 0
    private var currentNoteId: String = ""
    private var currentSessionId: String = ""
    // Baseline: EWMA over sessions (not computed per-event — only on window flush)
    private var baselineMeanFriction: Double = 0.5
    private var baselineAlpha: Double = 0.1  // ~7-day half-life in session terms

    func record(_ event: EditorTelemetryEvent) {
        // Note switch: flush and reset
        if event.noteId != currentNoteId {
            Task { await flushWindowIfSubstantial() }
            eventBuffer = RingBuffer(capacity: 200)
            currentNoteId = event.noteId
        }
        // AI stream events: do not contaminate metrics
        if case .aiStreamEnd = event.kind { return }
        eventBuffer.push(event)
        lastEventMs = event.timestampMs
        // Flush every ~10 minutes of events
        let events = eventBuffer.toArray()
        if let first = events.first, let last = events.last,
           last.timestampMs - first.timestampMs >= 600_000 {
            Task { await flushWindowIfSubstantial() }
            eventBuffer = RingBuffer(capacity: 200)
        }
    }

    private func flushWindowIfSubstantial() async {
        let events = eventBuffer.toArray()
        guard events.count >= 20 else { return }  // Too sparse to be meaningful
        guard let first = events.first, let last = events.last else { return }
        let window = computeFrictionWindow(events: events,
                                           start: first.timestampMs,
                                           end: last.timestampMs)
        guard let window else { return }
        try? await db.write { db in try window.insert(db) }
    }
}
```

### Friction Score Computation

The research synthesizes the weighted z-score formula:[^12][^11]

\[ F(W) = w_1 \cdot z(\text{pause\_rate}) + w_2 \cdot z(\text{mean\_pause\_duration}) - w_3 \cdot z(\text{burst\_length}) + w_4 \cdot z(\text{CV\_burst}) + w_5 \cdot z(\text{deletion\_density}) + w_6 \cdot z(\text{regression\_freq}) \]

Where each \(z(x)\) is computed relative to the user's per-session rolling baseline. Burst length contributes **negatively** — longer bursts = lower friction. The burst boundary threshold is 2.0 seconds for adult writers (Chenoweth & Hayes 2001 empirical standard).[^12][^11]

```swift
private func computeFrictionWindow(events: [EditorTelemetryEvent],
                                    start: Int64, end: Int64) -> FrictionWindow? {
    let durationSeconds = Double(end - start) / 1000.0
    guard durationSeconds > 30 else { return nil }

    // Inter-event gaps → pause analysis
    let gaps: [Double] = zip(events, events.dropFirst()).map { a, b in
        Double(b.timestampMs - a.timestampMs)
    }
    let burstThresholdMs = 2000.0  // Chenoweth & Hayes canonical 2s threshold
    let pauseGaps = gaps.filter { $0 >= burstThresholdMs }
    let pauseRate = Double(pauseGaps.count) / (durationSeconds / 60.0)
    // Use geometric mean for pause duration (log-normal distribution in writing research)
    let logMeanPause = pauseGaps.isEmpty ? 0 :
        pauseGaps.map { log($0) }.reduce(0, +) / Double(pauseGaps.count)
    let meanPauseDuration = pauseGaps.isEmpty ? 0 : exp(logMeanPause)

    // Burst length analysis
    var bursts: [Int] = []
    var currentBurst = 0
    for gap in gaps {
        if gap < burstThresholdMs { currentBurst += 1 }
        else { if currentBurst > 0 { bursts.append(currentBurst) }; currentBurst = 0 }
    }
    if currentBurst > 0 { bursts.append(currentBurst) }
    let meanBurst = bursts.isEmpty ? 0 : Double(bursts.reduce(0, +)) / Double(bursts.count)
    let burstCV = bursts.isEmpty ? 0 : stdDev(bursts.map(Double.init)) / max(meanBurst, 1)

    // Deletion density
    let insertions = events.filter { if case .insertion = $0.kind { return true }; return false }.count
    let deletions = events.filter { if case .deletion = $0.kind { return true }; return false }.count
    let deletionDensity = insertions > 0 ? Double(deletions) / Double(insertions + deletions) : 0

    // Regressions (cursor moves backward in document)
    let regressions = events.filter {
        if case .cursorMove(let delta) = $0.kind { return delta < 0 }; return false
    }.count
    let produced = max(insertions, 1)
    let regressionFreq = Double(regressions) / (Double(produced) / 100.0)

    // Z-score against session baseline (simplified; full EWMA calibration in session manager)
    let frictionScore = pauseRate * 0.25 + meanPauseDuration * 0.15 -
                        meanBurst * 0.20 + burstCV * 0.15 +
                        deletionDensity * 0.15 + regressionFreq * 0.10

    return FrictionWindow(
        noteId: currentNoteId, sessionId: currentSessionId,
        windowStart: start, windowEnd: end,
        pauseRate: pauseRate, meanPauseDurationMs: meanPauseDuration,
        meanBurstLengthChars: meanBurst, burstLengthCV: burstCV,
        deletionDensity: deletionDensity, regressionFrequency: regressionFreq,
        frictionScore: frictionScore
    )
}
```

**Phase 2 tests:**
1. Simulate 50 smooth insertions with <200ms gaps → friction score below threshold (< 0.3).
2. Simulate alternating insert/delete loop on same position 30 times → deletion density spikes, score exceeds threshold.
3. Inject `aiStreamEnd` events mid-sequence → assert those events are not counted in any metric.
4. Empty session (< 20 events) → `flushWindowIfSubstantial` does not insert a row.
5. Note-ID switch mid-session → old buffer is flushed, new buffer starts fresh (no state leak).

***

## Phase 3 — Spatial Graph Interaction Improvements

### The Core Constraint: Renderer-Friendly Incremental Changes

The existing `MetalGraphView` + Barnes-Hut physics pipeline runs with pre-allocated `MTLBuffer` pools. Any change that triggers a full buffer reallocation in the pan/zoom/render loop is a regression. The principle: **pin/freeze/layout operations mutate a flag in the existing `NodeData` struct** — they do not add buffer overhead.[^13][^11]

The existing Metal struct for node data already has the right layout strategy. Add `pinned: float` (0.0 = free, 1.0 = pinned) to `NodeData` in `spatial.rs` and `renderer.rs`. This flag is checked in the integration shader: if `pinned == 1.0`, zero out accumulated force before integration. Zero allocation, zero structural change to the buffer.

```metal
// In the integration compute shader — modify only the velocity update step
if (node.pinned > 0.5) {
    node.velocity = float2(0.0, 0.0);
    node.force   = float2(0.0, 0.0);
    // position unchanged
} else {
    node.velocity += node.force * dt;
    node.velocity *= damping;
    node.position += node.velocity * dt;
}
node.force = float2(0.0, 0.0);  // reset for next frame — both pinned and free
```

### GraphState Extensions

```swift
// Extend GraphState — no new GraphState subclass or parallel state
extension GraphState {
    struct PinnedNode: Codable, Sendable {
        let nodeId: String
        let position: SIMD2<Float>
        let pinnedAt: Date
    }

    struct CuratedLayout: Codable, Sendable {
        let id: String
        let name: String
        let pinnedNodes: [PinnedNode]
        let frozenAt: Date?
        let createdAt: Date
    }

    // In-memory state — backed by workspace snapshot for persistence
    var pinnedNodeIds: Set<String> = []
    var layoutFrozen: Bool = false
    var curatedLayouts: [CuratedLayout] = []

    mutating func pin(nodeId: String, position: SIMD2<Float>) {
        pinnedNodeIds.insert(nodeId)
        // Update the MTLBuffer pin flag via existing shared-memory pointer
        updateNodePinFlag(nodeId: nodeId, pinned: true)
    }

    mutating func unpin(nodeId: String) {
        pinnedNodeIds.remove(nodeId)
        updateNodePinFlag(nodeId: nodeId, pinned: false)
    }

    mutating func freezeLayout() {
        layoutFrozen = true
        // Pin ALL currently visible nodes at their current positions
        for nodeId in allVisibleNodeIds {
            pin(nodeId: nodeId, position: positionFor(nodeId: nodeId))
        }
    }

    mutating func unfreezeLayout() {
        layoutFrozen = false
        pinnedNodeIds.forEach { unpin(nodeId: $0) }
    }
}
```

**Layout persistence via existing workspace snapshot:** Encode `pinnedNodeIds` + `curatedLayouts` into the workspace snapshot JSON that `WorkspaceSummaryService` already manages. The snapshot is the existing persistence mechanism — no new storage path is needed.[^10]

**Selection and hover overlays:** The research from the spatial graph section is clear — any per-node view tree or separate CALayer overlay creates prohibitive overhead at >1,000 nodes. Overlays must use the existing batched render data. Add a `selected: float` and `hovered: float` field to the `NodeData` struct (both 0.0/1.0 flags) and handle them in the existing fragment shader via color interpolation:[^13]

```metal
fragment float4 nodeFragment(NodeFragIn in [[stage_in]],
                              constant float4& selectedColor [[buffer(3)]]) {
    float4 baseColor = in.color;
    float4 selColor  = mix(baseColor, selectedColor, in.selected * 0.6);
    float4 hovColor  = mix(selColor,  float4(1,1,1,1), in.hovered  * 0.3);
    return hovColor;
}
```

**Selection groups:** A `SelectionGroup` is a `Set<String>` of node IDs stored in `GraphState`. No new render pass, no per-group geometry — groups are visualized by setting `selected = 1.0` for all member nodes in the existing node buffer at group-activation time.

**Phase 3 tests:**
1. Pin a node, save workspace snapshot, reload workspace — node is still pinned at the same position (deserialized from snapshot JSON).
2. Freeze layout → all nodes have `pinned = 1.0` in Metal buffer → physics integration does not move any node (assert positions stable across 100 physics ticks).
3. Pan/zoom benchmark with 5,000-node graph — assert frame time does not exceed pre-phase baseline (capture with `MTLCaptureManager` or `os_signpost`).
4. Select 10 nodes, unpin 5, assert remaining 5 still selected (selection state is independent of pin state).

***

## Phase 4 — Night Brain Infrastructure Shell

### The Canonical Scheduling Architecture

Three layers, defense in depth:

1. **`NSBackgroundActivityScheduler`** (in-process): fires when app is running, system is idle, AC power, within the tolerance window. Interval 86,400s, tolerance 3,600s, QoS `.background`. The scheduler wraps the block in `ProcessInfo.beginActivity` automatically.[^14][^11]

2. **`SMAppService` LaunchAgent** (macOS 13+): fires even when the app is not running. This is the safety net. Register `StartCalendarInterval` for 2 AM local time.[^14]

3. **User-activity abort gate**: poll `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: ...)` every 60 seconds during execution — if user returns (`< 60s` idle), checkpoint and defer immediately.[^14][^11]

### Thermal Gating — Five-Level Granularity

`ProcessInfo.thermalState` conflates "moderate" and "heavy" inside `.fair`. Use the `thermald` notifyd channel for proper five-level granularity:[^14]

```swift
func thermalPressureLevel() -> UInt64 {
    // thermald publishes 0=nominal,1=moderate,2=heavy,3=trapping,4=sleeping
    let name = "com.apple.system.thermalpressurelevel"
    var token: Int32 = 0
    guard name.withCString({ notify_register_check($0, &token) }) == 0 else { return 0 }
    defer { _ = notify_cancel(token) }
    var state: UInt64 = 0
    _ = notify_get_state(token, &state)
    return state
}

func canStartNightBrain(config: EpistemosConfig) -> Bool {
    guard config.nightBrainEnabled else { return false }
    if config.nightBrainRequiresAC && !isOnACPower() { return false }
    guard userIdleSeconds() > config.nightBrainMinIdleSeconds else { return false }
    guard thermalPressureLevel() <= 1 else { return false }  // nominal or moderate only
    return true
}
```

### Job Pipeline — Sequential Phases, Never Concurrent

The research establishes that pipelining GPU + CPU heavy work simultaneously on Apple Silicon pushes the thermal envelope and paradoxically reduces throughput. The Night Brain runs jobs sequentially:[^14][^11]

```swift
actor NightBrainService {
    enum Job: String, CaseIterable, Sendable {
        case eventStoreCheckpointVacuum = "event_store_checkpoint_vacuum"
        case dedupeArtifacts = "dedupe_artifacts"
        case hnswIntegrityCheck = "hnsw_integrity_check"
        case workspaceSnapshotCompaction = "workspace_snapshot_compaction"
        case orphanVaultSanity = "orphan_vault_sanity"
        case maintenanceLog = "maintenance_log"
    }

    private let db: DatabasePool
    private let scheduler: NSBackgroundActivityScheduler
    private var activityToken: NSObjectProtocol?
    private var sleepGuard: SleepGuard?
    private var currentRunId: Int64?

    func start() {
        scheduler.schedule { [weak self] completion in
            guard let self else { completion(.deferred); return }
            Task {
                let started = await self.canStart()
                if started {
                    await self.executePipeline(completion: completion)
                } else {
                    completion(.deferred)
                }
            }
        }
    }

    private func executePipeline(completion: @escaping NSBackgroundActivityCompletionHandler) async {
        // Prevent App Nap during pipeline
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.background, .idleSystemSleepDisabled, .automaticTerminationDisabled],
            reason: "Epistemos Night Brain maintenance"
        )
        defer {
            if let t = activityToken { ProcessInfo.processInfo.endActivity(t) }
            activityToken = nil
        }
        sleepGuard = SleepGuard()
        sleepGuard?.prevent(reason: "Epistemos Night Brain")
        defer { sleepGuard?.allow() }

        // Insert run record
        let runId = try? await db.write { db -> Int64 in
            var run = NightBrainRun(startedAt: nowMs(), status: "running",
                                    jobsCompleted: "[]", triggerReason: "scheduler")
            try run.insert(db)
            return run.id!
        }
        guard let runId else { completion(.deferred); return }
        currentRunId = runId

        var completedJobs: [String] = []
        // Load checkpoint if resuming an interrupted run
        let checkpoint = await loadLatestCheckpoint(runId: runId)
        let pendingJobs = pendingJobs(allJobs: Job.allCases, completedInCheckpoint: checkpoint)

        for job in pendingJobs {
            // Abort gate — check every job boundary
            guard await canContinue() else {
                await updateRunStatus(runId: runId, status: "interrupted",
                                       completedJobs: completedJobs)
                completion(.deferred)
                return
            }
            await executeJob(job, runId: runId)
            completedJobs.append(job.rawValue)
            await saveCheckpoint(runId: runId, job: job, completedJobs: completedJobs)
        }
        await updateRunStatus(runId: runId, status: "completed", completedJobs: completedJobs)
        completion(.finished)
    }

    private func canContinue() async -> Bool {
        let idle = userIdleSeconds()
        let thermal = thermalPressureLevel()
        return idle > 30 && thermal <= 2
    }
}
```

### Job Implementations (Deterministic Only — No Semantic Work)

**EventStore checkpoint/vacuum:**
```swift
case .eventStoreCheckpointVacuum:
    try? await db.writeWithoutTransaction { db in
        // Passive WAL checkpoint — never blocks readers
        try db.execute(sql: "PRAGMA wal_checkpoint(PASSIVE)")
        // Incremental vacuum — never full vacuum on a live DB
        try db.execute(sql: "PRAGMA incremental_vacuum(100)")
    }
```

**Dedupe artifacts:** Delete `captured_artifacts` rows where `dedupe_hash` appears more than once, keeping only the newest `id`. This is idempotent — running twice produces the same result.

**HNSW integrity check:** Call the existing Rust `graph_engine` FFI to run `usearch_index_check()` — a read-only sidecar integrity scan that returns a flag indicating whether a soft rebuild is needed. Log the flag to `night_brain_checkpoints`; do not execute the rebuild inside Night Brain (that's semantic work).

**Workspace snapshot compaction:** Prune workspace snapshots older than 30 days to a single monthly representative, using the existing `WorkspaceSummaryService` compaction path.[^10]

**Morning Briefing view:** Only surface to `AppEnvironment` a `NightBrainDigestService` that reads `night_brain_runs WHERE status = 'completed'` and presents the `jobs_completed` array. Never surface in-progress or interrupted runs in the UI.

**Phase 4 tests:**
1. Simulate interrupted pipeline (abort gate fires after job 2) → checkpoint recorded → re-run resumes from job 3 (assert jobs 1–2 not re-executed).
2. Set `userIdleSeconds() = 10` → `canContinue()` returns false → pipeline defers after current job.
3. Completed `night_brain_runs` only visible in digest — assert in-progress rows are filtered.
4. Run same pipeline twice → assert idempotent: artifact counts, snapshot counts, WAL state unchanged between run 1 completion and run 2 completion.
5. Assert no Night Brain pipeline fires when a note is being actively edited (editor focus churn detection via `ActivityTracker` idle state).

***

## Phase 5 — Settings, Polish, Regression Hardening

### Single Settings Section

All five capability toggles live in one `SettingsView` section — no scattered checkboxes on unrelated screens. Use `AppEnvironment`-injected `EpistemosConfig`:

```swift
struct EpistemosSettingsSection: View {
    @Environment(EpistemosConfig.self) var config

    var body: some View {
        Section("Epistemos Cognitive Features") {
            Toggle("Cross-App Capture", isOn: $config.captureEnabled)
            if config.captureEnabled {
                NavigationLink("App Allow/Block List") { AppCaptureListView() }
                Toggle("OCR Fallback", isOn: $config.ocrFallbackEnabled)
            }
            Toggle("Friction Insights", isOn: $config.frictionEnabled)
            Toggle("Night Brain", isOn: $config.nightBrainEnabled)
            if config.nightBrainEnabled {
                Toggle("Require AC Power", isOn: $config.nightBrainRequiresAC)
            }
        }
    }
}
```

### Runtime Validation Tests

```swift
// Test: all features disabled → no background loops fire
func testDisabledFeaturesNoBackgroundWork() async {
    let config = EpistemosConfig()
    config.captureEnabled = false
    config.frictionEnabled = false
    config.nightBrainEnabled = false
    let capture = AmbientCaptureService(db: testDB, config: config)
    let friction = FrictionMonitorService()
    let nightBrain = NightBrainService(db: testDB, config: config)
    // Simulate app-switch → no artifact written
    await capture.appDidActivate(pid: 12345, bundleId: "com.apple.safari", appName: "Safari")
    let count = try await testDB.read { db in try CapturedArtifact.fetchCount(db) }
    XCTAssertEqual(count, 0)
}

// Test: environment injection — services reachable from SwiftUI hierarchy
func testEnvironmentInjection() {
    let env = AppEnvironment.test()
    XCTAssertNotNil(env.epistemosConfig)
    XCTAssertNotNil(env.ambientCapture)
}
```

***

## Zero-Copy Performance Architecture: Unifying Principles

The following table consolidates every performance-critical decision across all four phases, grounded in the research and Apple Silicon's unified memory model:[^15][^16][^2][^1]

| Boundary | Technique | Why Zero-Copy |
|---|---|---|
| CPU → GPU (node physics) | `MTLStorageMode.shared` buffer | Same physical memory; no blit on Apple Silicon [^1][^15] |
| Editor events → FrictionMonitor | Stack-allocated `EditorTelemetryEvent` struct | Value type, no heap allocation per event [^11] |
| AX text → capture pipeline | `String` passed as `Sendable` across actor boundary | Single owner transfer, ARC is free [^17] |
| GRDB reads → services | `DatabasePool` concurrent reads via WAL | Multiple readers never block each other [^5][^6] |
| Night Brain → main app | GRDB-backed checkpoint | XPC-free for now; crash-safe without process isolation overhead |
| OCR → artifact store | New `VNRecognizeTextRequest` per image | Avoids race on shared request object [^11] |
| Metal physics → Swift selection state | Flag write to shared MTLBuffer byte | One-byte write, no round-trip copy [^1] |
| Friction score → session summary | Aggregated `FrictionWindow` row only | Raw keystrokes never persisted [^12] |

***

## Pre-Merge Command Checklist

Before each phase merge, the following must all pass. These are not optional:

```bash
# 1. Full Swift test suite (includes all new tests from this phase)
xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj \
           -scheme Epistemos \
           -destination 'platform=macOS' test

# 2. Rust graph-engine unit tests
cd /Users/jojo/Downloads/Epistemos/graph-engine && cargo test

# 3. Build with zero new warnings
xcodebuild -project /Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj \
           -scheme Epistemos \
           -destination 'platform=macOS' build 2>&1 | grep -E "error:|warning:" | grep -v "^$"

# 4. No whitespace or merge artifact issues
git diff --check
```

***

## Definition of Done — Exact Verification

| Criterion | Verification |
|---|---|
| No regression in existing Swift suite | `xcodebuild test` exits 0 |
| No regression in Rust suite | `cargo test` exits 0 |
| No duplicate storage layers | `sqlite3 epistemos.db ".tables"` shows exactly 4 new tables, all prefixed by this prompt |
| No main-thread OCR/AX/index work | Instruments → Main Thread Checker shows zero violations during app-switch |
| All four substrates toggleable | All features disabled → XCTest suite `testDisabledFeaturesNoBackgroundWork` passes |
| No per-frame allocations in graph loop | Instruments → Allocations → filter "MetalGraphView" → zero live allocations during pan/zoom |
| Model-dependent work explicitly deferred | Search codebase for `// DEFERRED:` comments covering InstantRecallService unification, Contextual Shadows semantic ranking, temporal embedding drift, and Night Brain autonomous summarization |
| Night Brain read-only on vault | `grep -r "\.delete\|\.update\|\.rename" NightBrainService.swift` returns nothing on note files |

***

## Deferred Work — Explicit Documentation Required

These items must appear as `// DEFERRED(model-stack):` comments in the codebase, not silently omitted:

1. **InstantRecallService + prepared retrieval unification** — canonical recall engine consolidation depends on model-stack decisions not yet made.
2. **Contextual Shadows semantic ranking** — HNSW top-K + temporal re-ranking requires the full embedding pipeline to be stable.
3. **Temporal embedding drift / belief evolution** — the diachronic embedding analysis (Hamilton et al., second-order embedding alignment) requires a stable note corpus of 10K+ tokens per time window.
4. **Night Brain autonomous summarization** — Leiden community detection, orphan scoring with FSRS stability values, and embedding-based digest assembly all depend on the final on-device model choice (MLX, CoreML, or model2vec frozen encoder).

Leaving these as documented stubs rather than half-implementations is itself a correctness property — it prevents future phases from building on an unstable foundation.[^11]

---

## References

1. [MTLStorageMode.shared | Apple Developer Documentation](https://developer.apple.com/documentation/metal/mtlstoragemode/shared) - This is the default storage mode for MTLBuffer instances on integrated GPUs and both MTLBuffer and M...

2. [Fast integrated GPUs like Apple's allow for directly accessing the ...](https://news.ycombinator.com/item?id=34034000) - Fast integrated GPUs like Apple's allow for directly accessing the main memory without copy, making ...

3. [SQLite and iOS: Getting started with GRDB - DEV Community](https://dev.to/elliotekj/sqlite-and-ios-getting-started-with-grdb-5bd2) - This article will cover setting up a local SQLite database for your iOS app, writing migrations, wri...

4. [Question/confusion about table generation · Issue #1769 - GitHub](https://github.com/groue/GRDB.swift/issues/1769) - Here are some Swift structs. 1. Write a matching GRDB migration (take care of primary and foreign ke...

5. [GRDB Reference - Gwendal Roué](http://groue.github.io/GRDB.swift/docs/0.103.0/) - GRDB ships with a low-level SQLite API, and high-level tools that help dealing with databases: Recor...

6. [GRDBCipher on CocoaPods.org](https://cocoapods.org/pods/GRDBCipher) - WAL Mode Support: Extra performance for multi-threaded applications. Migrations: Transform your data...

7. [GRDB.swift/CHANGELOG.md at master · groue/GRDB.swift · GitHub](https://github.com/groue/GRDB.swift/blob/master/CHANGELOG.md) - Documentation Update: The ValueObservation Performance documentation chapter explains how truncating...

8. [Changelog - GRDB.swift - Mintlify](https://www.mintlify.com/groue/GRDB.swift/resources/changelog) - For the complete version history, see the full CHANGELOG on GitHub. ​. Latest Release: GRDB 7.10.0. ...

9. [Recommended way to update a Single-Row Table with migrations](https://github.com/groue/GRDB.swift/discussions/1526) - Each column is mandatory ( .notNull() ) · When you mutate the table to add a new column, you have to...

10. [Cognitive-macOS-Personal-Knowledge-System-3.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/1ff703c9-1589-4d36-85a3-425a10b56cf0/Cognitive-macOS-Personal-Knowledge-System-3.md?AWSAccessKeyId=ASIA2F3EMEYEVS3EF3F2&Signature=02V%2BSyoCydeH1Che00%2B1aDhWgAs%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEAsaCXVzLWVhc3QtMSJGMEQCIAlnEvO57fSoEXbR%2F%2FUwKM03sF2LcSQw%2B0pWnE6HMVUDAiBkkPW%2Fmc0SIkTPftuuFJP%2FmaiTXuH6RYCT6f%2Bbz9MSkSr8BAjU%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAEaDDY5OTc1MzMwOTcwNSIMffS%2F4kV1c6a8%2B70RKtAErjY8MxrsAL4%2F%2BQEhdGOnnvTpU5biM%2FR%2FbyfdyggRBz1ih5gvqiabaMDgXtTQYzX%2Ft91z0v9P1sroj2kmKfHTViSRhpOu3rnlEDW4r%2BpCpdywMuIf49kIh9ilnbIGE5u2Xf8IsdTySiN7SNSx33ZgCfTAeJc9imLzElCieqHfTeteuq2AHSlN2ezPtoyWi4OVAe%2BNOkE%2FyhoToDXvSMI6W%2FVJ4J9lsahoL84Osj2tw2fRzdLiHXeURBk62q5umPjCtF8%2F%2BBmAVSvSHlHAwOM95dMzBs7%2FpvF4hwmLMhdrn4jga23QbQXCUDRvzCl1V044lbCGYEyCpvWz47rjs5LFnvdY7OJZlLRhJcxKc9aUZuYoeap9H%2FT56U87Iu%2BCO0cwiellxa%2BFSaKBb%2FBj%2BjBzLPYI3YexKjzKWA8zaoxaw2wuyGC9biKFBwdVg3L0Nrclcl9uF16mHOwAatUwR6BztcEY4fcF1a4HTAGLM1zQqYZvh8EUiRehrmbymN7JH75V9jWimnI8OeoMSDONqW1z7J6OjLoQcx73mfVaKu0xjDtRPBMSjhqYizhzfvVFP820PyDZ%2FTV5vPa6r3BlDqsoFnVl6tIYPcCoKfT9zgzlNs1gP29CXJk5QMmvClMy8k7%2B%2F%2B%2BEcjrnO%2FGEfRTIkYppBgmo1YFP20I4VJto2hYJBkN1REXtuWNJPvBun4mcEhFDjsVnN36MoRK0o0lJQPfT5o%2BlpcLSLFuy5SjdGHW89i9W%2F9zsKKS5G37sUbAhpS2CIhPcwpMgwAVzAeF7vr39ozCf2pfOBjqZAYtUnQPZ%2FGsafVHmvKAx1dfDWCT46pELueRRdWz8YVotLCXuRHgoVO3vVio%2BAzvqbAvdZ7OYPkAulZNrYFtZ%2FIF9QEGXDbEt8k49QAuYX7QWGK8q7z0QlyupIlDlebGBchkCsICMaXnuF2uvVSfEt1Tk8LeOLG%2BEU5Sr5ALQBUzZyx5drCkW2Osqh7yiy66rwafcyE3lm6foqQ%3D%3D&Expires=1774582514)

11. [cognitive-computing-capabilities.pplx-13.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/a7a1547d-2fbb-453c-9c35-c3ee8f9b4039/cognitive-computing-capabilities.pplx-13.md?AWSAccessKeyId=ASIA2F3EMEYEVS3EF3F2&Signature=pgXeDI27D6Ol265nlbCVYoSa9fg%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEAsaCXVzLWVhc3QtMSJGMEQCIAlnEvO57fSoEXbR%2F%2FUwKM03sF2LcSQw%2B0pWnE6HMVUDAiBkkPW%2Fmc0SIkTPftuuFJP%2FmaiTXuH6RYCT6f%2Bbz9MSkSr8BAjU%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAEaDDY5OTc1MzMwOTcwNSIMffS%2F4kV1c6a8%2B70RKtAErjY8MxrsAL4%2F%2BQEhdGOnnvTpU5biM%2FR%2FbyfdyggRBz1ih5gvqiabaMDgXtTQYzX%2Ft91z0v9P1sroj2kmKfHTViSRhpOu3rnlEDW4r%2BpCpdywMuIf49kIh9ilnbIGE5u2Xf8IsdTySiN7SNSx33ZgCfTAeJc9imLzElCieqHfTeteuq2AHSlN2ezPtoyWi4OVAe%2BNOkE%2FyhoToDXvSMI6W%2FVJ4J9lsahoL84Osj2tw2fRzdLiHXeURBk62q5umPjCtF8%2F%2BBmAVSvSHlHAwOM95dMzBs7%2FpvF4hwmLMhdrn4jga23QbQXCUDRvzCl1V044lbCGYEyCpvWz47rjs5LFnvdY7OJZlLRhJcxKc9aUZuYoeap9H%2FT56U87Iu%2BCO0cwiellxa%2BFSaKBb%2FBj%2BjBzLPYI3YexKjzKWA8zaoxaw2wuyGC9biKFBwdVg3L0Nrclcl9uF16mHOwAatUwR6BztcEY4fcF1a4HTAGLM1zQqYZvh8EUiRehrmbymN7JH75V9jWimnI8OeoMSDONqW1z7J6OjLoQcx73mfVaKu0xjDtRPBMSjhqYizhzfvVFP820PyDZ%2FTV5vPa6r3BlDqsoFnVl6tIYPcCoKfT9zgzlNs1gP29CXJk5QMmvClMy8k7%2B%2F%2B%2BEcjrnO%2FGEfRTIkYppBgmo1YFP20I4VJto2hYJBkN1REXtuWNJPvBun4mcEhFDjsVnN36MoRK0o0lJQPfT5o%2BlpcLSLFuy5SjdGHW89i9W%2F9zsKKS5G37sUbAhpS2CIhPcwpMgwAVzAeF7vr39ozCf2pfOBjqZAYtUnQPZ%2FGsafVHmvKAx1dfDWCT46pELueRRdWz8YVotLCXuRHgoVO3vVio%2BAzvqbAvdZ7OYPkAulZNrYFtZ%2FIF9QEGXDbEt8k49QAuYX7QWGK8q7z0QlyupIlDlebGBchkCsICMaXnuF2uvVSfEt1Tk8LeOLG%2BEU5Sr5ALQBUzZyx5drCkW2Osqh7yiy66rwafcyE3lm6foqQ%3D%3D&Expires=1774582514) - # Cognitive Computing Capabilities for a Local-First Knowledge System

> **System context:** Native ...

12. [cap3_cognitive_friction-8.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/d449dfc8-1190-4933-8072-fe012cbbf5eb/cap3_cognitive_friction-8.md?AWSAccessKeyId=ASIA2F3EMEYEVS3EF3F2&Signature=gfPducPBnNgtJK7%2FLKeuhvpuB6o%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEAsaCXVzLWVhc3QtMSJGMEQCIAlnEvO57fSoEXbR%2F%2FUwKM03sF2LcSQw%2B0pWnE6HMVUDAiBkkPW%2Fmc0SIkTPftuuFJP%2FmaiTXuH6RYCT6f%2Bbz9MSkSr8BAjU%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAEaDDY5OTc1MzMwOTcwNSIMffS%2F4kV1c6a8%2B70RKtAErjY8MxrsAL4%2F%2BQEhdGOnnvTpU5biM%2FR%2FbyfdyggRBz1ih5gvqiabaMDgXtTQYzX%2Ft91z0v9P1sroj2kmKfHTViSRhpOu3rnlEDW4r%2BpCpdywMuIf49kIh9ilnbIGE5u2Xf8IsdTySiN7SNSx33ZgCfTAeJc9imLzElCieqHfTeteuq2AHSlN2ezPtoyWi4OVAe%2BNOkE%2FyhoToDXvSMI6W%2FVJ4J9lsahoL84Osj2tw2fRzdLiHXeURBk62q5umPjCtF8%2F%2BBmAVSvSHlHAwOM95dMzBs7%2FpvF4hwmLMhdrn4jga23QbQXCUDRvzCl1V044lbCGYEyCpvWz47rjs5LFnvdY7OJZlLRhJcxKc9aUZuYoeap9H%2FT56U87Iu%2BCO0cwiellxa%2BFSaKBb%2FBj%2BjBzLPYI3YexKjzKWA8zaoxaw2wuyGC9biKFBwdVg3L0Nrclcl9uF16mHOwAatUwR6BztcEY4fcF1a4HTAGLM1zQqYZvh8EUiRehrmbymN7JH75V9jWimnI8OeoMSDONqW1z7J6OjLoQcx73mfVaKu0xjDtRPBMSjhqYizhzfvVFP820PyDZ%2FTV5vPa6r3BlDqsoFnVl6tIYPcCoKfT9zgzlNs1gP29CXJk5QMmvClMy8k7%2B%2F%2B%2BEcjrnO%2FGEfRTIkYppBgmo1YFP20I4VJto2hYJBkN1REXtuWNJPvBun4mcEhFDjsVnN36MoRK0o0lJQPfT5o%2BlpcLSLFuy5SjdGHW89i9W%2F9zsKKS5G37sUbAhpS2CIhPcwpMgwAVzAeF7vr39ozCf2pfOBjqZAYtUnQPZ%2FGsafVHmvKAx1dfDWCT46pELueRRdWz8YVotLCXuRHgoVO3vVio%2BAzvqbAvdZ7OYPkAulZNrYFtZ%2FIF9QEGXDbEt8k49QAuYX7QWGK8q7z0QlyupIlDlebGBchkCsICMaXnuF2uvVSfEt1Tk8LeOLG%2BEU5Sr5ALQBUzZyx5drCkW2Osqh7yiy66rwafcyE3lm6foqQ%3D%3D&Expires=1774582514) - # Cognitive Friction Detection via Edit Telemetry
## Research Report: Capability 3 — Native macOS Kn...

13. [cap6_spatial_graph-11.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/ce46da69-21c4-4f4a-946d-874eee21fc0d/cap6_spatial_graph-11.md?AWSAccessKeyId=ASIA2F3EMEYEVS3EF3F2&Signature=AeHz74E5a0mK%2FbAhJjGl%2FnmK9LU%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEAsaCXVzLWVhc3QtMSJGMEQCIAlnEvO57fSoEXbR%2F%2FUwKM03sF2LcSQw%2B0pWnE6HMVUDAiBkkPW%2Fmc0SIkTPftuuFJP%2FmaiTXuH6RYCT6f%2Bbz9MSkSr8BAjU%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAEaDDY5OTc1MzMwOTcwNSIMffS%2F4kV1c6a8%2B70RKtAErjY8MxrsAL4%2F%2BQEhdGOnnvTpU5biM%2FR%2FbyfdyggRBz1ih5gvqiabaMDgXtTQYzX%2Ft91z0v9P1sroj2kmKfHTViSRhpOu3rnlEDW4r%2BpCpdywMuIf49kIh9ilnbIGE5u2Xf8IsdTySiN7SNSx33ZgCfTAeJc9imLzElCieqHfTeteuq2AHSlN2ezPtoyWi4OVAe%2BNOkE%2FyhoToDXvSMI6W%2FVJ4J9lsahoL84Osj2tw2fRzdLiHXeURBk62q5umPjCtF8%2F%2BBmAVSvSHlHAwOM95dMzBs7%2FpvF4hwmLMhdrn4jga23QbQXCUDRvzCl1V044lbCGYEyCpvWz47rjs5LFnvdY7OJZlLRhJcxKc9aUZuYoeap9H%2FT56U87Iu%2BCO0cwiellxa%2BFSaKBb%2FBj%2BjBzLPYI3YexKjzKWA8zaoxaw2wuyGC9biKFBwdVg3L0Nrclcl9uF16mHOwAatUwR6BztcEY4fcF1a4HTAGLM1zQqYZvh8EUiRehrmbymN7JH75V9jWimnI8OeoMSDONqW1z7J6OjLoQcx73mfVaKu0xjDtRPBMSjhqYizhzfvVFP820PyDZ%2FTV5vPa6r3BlDqsoFnVl6tIYPcCoKfT9zgzlNs1gP29CXJk5QMmvClMy8k7%2B%2F%2B%2BEcjrnO%2FGEfRTIkYppBgmo1YFP20I4VJto2hYJBkN1REXtuWNJPvBun4mcEhFDjsVnN36MoRK0o0lJQPfT5o%2BlpcLSLFuy5SjdGHW89i9W%2F9zsKKS5G37sUbAhpS2CIhPcwpMgwAVzAeF7vr39ozCf2pfOBjqZAYtUnQPZ%2FGsafVHmvKAx1dfDWCT46pELueRRdWz8YVotLCXuRHgoVO3vVio%2BAzvqbAvdZ7OYPkAulZNrYFtZ%2FIF9QEGXDbEt8k49QAuYX7QWGK8q7z0QlyupIlDlebGBchkCsICMaXnuF2uvVSfEt1Tk8LeOLG%2BEU5Sr5ALQBUzZyx5drCkW2Osqh7yiy66rwafcyE3lm6foqQ%3D%3D&Expires=1774582514) - # Capability 6: Spatial Graph Interaction — Physics-Driven Thinking Canvas

**Audience:** Production...

14. [cap5_night_brain-10.md](https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/20876755/476fcf2c-eb29-4c22-8e75-50909aedcbee/cap5_night_brain-10.md?AWSAccessKeyId=ASIA2F3EMEYEVS3EF3F2&Signature=7wMZNWeBIkytYjCHDlgf5GzgEig%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEAsaCXVzLWVhc3QtMSJGMEQCIAlnEvO57fSoEXbR%2F%2FUwKM03sF2LcSQw%2B0pWnE6HMVUDAiBkkPW%2Fmc0SIkTPftuuFJP%2FmaiTXuH6RYCT6f%2Bbz9MSkSr8BAjU%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F8BEAEaDDY5OTc1MzMwOTcwNSIMffS%2F4kV1c6a8%2B70RKtAErjY8MxrsAL4%2F%2BQEhdGOnnvTpU5biM%2FR%2FbyfdyggRBz1ih5gvqiabaMDgXtTQYzX%2Ft91z0v9P1sroj2kmKfHTViSRhpOu3rnlEDW4r%2BpCpdywMuIf49kIh9ilnbIGE5u2Xf8IsdTySiN7SNSx33ZgCfTAeJc9imLzElCieqHfTeteuq2AHSlN2ezPtoyWi4OVAe%2BNOkE%2FyhoToDXvSMI6W%2FVJ4J9lsahoL84Osj2tw2fRzdLiHXeURBk62q5umPjCtF8%2F%2BBmAVSvSHlHAwOM95dMzBs7%2FpvF4hwmLMhdrn4jga23QbQXCUDRvzCl1V044lbCGYEyCpvWz47rjs5LFnvdY7OJZlLRhJcxKc9aUZuYoeap9H%2FT56U87Iu%2BCO0cwiellxa%2BFSaKBb%2FBj%2BjBzLPYI3YexKjzKWA8zaoxaw2wuyGC9biKFBwdVg3L0Nrclcl9uF16mHOwAatUwR6BztcEY4fcF1a4HTAGLM1zQqYZvh8EUiRehrmbymN7JH75V9jWimnI8OeoMSDONqW1z7J6OjLoQcx73mfVaKu0xjDtRPBMSjhqYizhzfvVFP820PyDZ%2FTV5vPa6r3BlDqsoFnVl6tIYPcCoKfT9zgzlNs1gP29CXJk5QMmvClMy8k7%2B%2F%2B%2BEcjrnO%2FGEfRTIkYppBgmo1YFP20I4VJto2hYJBkN1REXtuWNJPvBun4mcEhFDjsVnN36MoRK0o0lJQPfT5o%2BlpcLSLFuy5SjdGHW89i9W%2F9zsKKS5G37sUbAhpS2CIhPcwpMgwAVzAeF7vr39ozCf2pfOBjqZAYtUnQPZ%2FGsafVHmvKAx1dfDWCT46pELueRRdWz8YVotLCXuRHgoVO3vVio%2BAzvqbAvdZ7OYPkAulZNrYFtZ%2FIF9QEGXDbEt8k49QAuYX7QWGK8q7z0QlyupIlDlebGBchkCsICMaXnuF2uvVSfEt1Tk8LeOLG%2BEU5Sr5ALQBUzZyx5drCkW2Osqh7yiy66rwafcyE3lm6foqQ%3D%3D&Expires=1774582514) - # Night Brain — Autonomous Background Processing
## Research Compendium — Capability 5

*Expert audi...

15. [MTLResourceStorageModeShar...](https://developer.apple.com/documentation/metal/mtlresourceoptions/storagemodeshared?changes=_8&language=objc) - This is the default storage mode for MTLBuffer instances on integrated GPUs and both MTLBuffer and M...

16. [[Apple Metal] Changing MTLStorageMode of MTLTexture ... - Reddit](https://www.reddit.com/r/AskProgramming/comments/17vjck5/apple_metal_changing_mtlstoragemode_of_mtltexture/) - There is no such thing as Shared storage mode for MTLTextures on macOS, even if you are on Apple Sil...

17. [Thread dispatching and Actors: understanding execution - SwiftLee](https://www.avanderlee.com/concurrency/thread-dispatching-actor-execution/) - Actors ensure your code is executed on a specific thread, like the main or a background thread. They...

