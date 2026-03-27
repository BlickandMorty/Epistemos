import Foundation
import os

// MARK: - Friction Monitor Service
// Measures writing friction from editor telemetry without visible editor overhead.
// Consumes events in Swift actor — never sends per-keystroke data through Rust FFI.
// Persists only aggregated FrictionWindow rows, never raw keystroke logs.
//
// Config is read LIVE via @MainActor hop so toggling the setting takes effect immediately.
// Session identity is derived from the note being edited — each note switch starts a new session.

actor FrictionMonitorService {
    nonisolated static let log = Logger(subsystem: "com.epistemos", category: "FrictionMonitor")

    /// Shared instance set by AppBootstrap. Accessed by ProseTextView2 for telemetry hooks.
    nonisolated(unsafe) static var shared: FrictionMonitorService?

    private let config: EpistemosConfig
    private let storeProvider: @Sendable () -> EventStore?
    private static let maxEvents = 200
    private var events: RingBuffer<EditorTelemetryEvent>
    private var currentNoteId: String = ""
    /// Session ID changes on each note switch — represents a contiguous editing session on one note.
    private var currentSessionId: String = UUID().uuidString

    private static let burstThresholdMs: Double = 2000.0
    private static let minimumEventsForFlush = 20
    private static let windowDurationMs: Int64 = 600_000

    init(
        config: EpistemosConfig,
        storeProvider: @escaping @Sendable () -> EventStore? = { EventStore.shared }
    ) {
        self.config = config
        self.storeProvider = storeProvider
        self.events = RingBuffer(capacity: Self.maxEvents)
    }

    // MARK: - Config Read

    private func isEnabled() async -> Bool {
        await MainActor.run { config.frictionEnabled }
    }

    // MARK: - Event Recording

    func record(_ event: EditorTelemetryEvent) async {
        guard await isEnabled() else { return }
        if case .aiStreamEnd = event.kind { return }

        // Note switch: flush old buffer, start a new session
        if event.noteId != currentNoteId && !currentNoteId.isEmpty {
            await flushWindowIfSubstantial()
            events.reset()
            currentSessionId = UUID().uuidString
        }
        currentNoteId = event.noteId

        events.push(event)

        if let first = events.first, let last = events.last,
           last.timestampMs - first.timestampMs >= Self.windowDurationMs {
            await flushWindowIfSubstantial()
            events.reset()
        }
    }

    func noteDidSwitch(oldNoteId: String) async {
        guard await isEnabled() else { return }
        guard oldNoteId == currentNoteId else { return }
        await flushWindowIfSubstantial()
        events.reset()
        currentNoteId = ""
        currentSessionId = UUID().uuidString
    }

    // MARK: - Window Flush

    private func flushWindowIfSubstantial() async {
        let snapshot = events.toArray()
        guard snapshot.count >= Self.minimumEventsForFlush else { return }
        guard let first = snapshot.first, let last = snapshot.last else { return }

        let window = computeFrictionWindow(
            events: snapshot,
            start: Double(first.timestampMs) / 1000.0,
            end: Double(last.timestampMs) / 1000.0
        )
        guard let window else { return }
        storeProvider()?.insertFrictionWindow(window)
    }

    // MARK: - Friction Score Computation

    private func computeFrictionWindow(
        events: [EditorTelemetryEvent],
        start: Double,
        end: Double
    ) -> FrictionWindow? {
        let durationSeconds = end - start
        guard durationSeconds > 30 else { return nil }

        let gaps: [Double] = zip(events, events.dropFirst()).map { a, b in
            Double(b.timestampMs - a.timestampMs)
        }
        let pauseGaps = gaps.filter { $0 >= Self.burstThresholdMs }
        let pauseRate = durationSeconds > 0
            ? Double(pauseGaps.count) / (durationSeconds / 60.0) : 0

        let meanPauseDuration: Double
        if pauseGaps.isEmpty {
            meanPauseDuration = 0
        } else {
            let logMean = pauseGaps.map { Foundation.log($0) }.reduce(0, +) / Double(pauseGaps.count)
            meanPauseDuration = exp(logMean)
        }

        var bursts: [Int] = []
        var currentBurst = 0
        for gap in gaps {
            if gap < Self.burstThresholdMs {
                currentBurst += 1
            } else {
                if currentBurst > 0 { bursts.append(currentBurst) }
                currentBurst = 0
            }
        }
        if currentBurst > 0 { bursts.append(currentBurst) }

        let meanBurst = bursts.isEmpty ? 0.0 : Double(bursts.reduce(0, +)) / Double(bursts.count)
        let burstCV: Double
        if bursts.count < 2 || meanBurst < 1 {
            burstCV = 0
        } else {
            let burstDoubles = bursts.map(Double.init)
            let variance = burstDoubles.map { ($0 - meanBurst) * ($0 - meanBurst) }.reduce(0, +) / Double(bursts.count)
            burstCV = sqrt(variance) / meanBurst
        }

        var insertionCount = 0
        var deletionCount = 0
        for event in events {
            switch event.kind {
            case .insertion(let count): insertionCount += count
            case .deletion(let count): deletionCount += count
            default: break
            }
        }
        let totalEdits = insertionCount + deletionCount
        let deletionDensity = totalEdits > 0 ? Double(deletionCount) / Double(totalEdits) : 0

        var regressionCount = 0
        for event in events {
            if case .cursorMove(let delta) = event.kind, delta < 0 {
                regressionCount += 1
            }
        }
        let produced = max(insertionCount, 1)
        let regressionFreq = Double(regressionCount) / (Double(produced) / 100.0)

        let frictionScore = pauseRate * 0.25
            + meanPauseDuration / 1000.0 * 0.15
            - meanBurst * 0.20
            + burstCV * 0.15
            + deletionDensity * 0.15
            + regressionFreq * 0.10

        return FrictionWindow(
            noteId: currentNoteId,
            sessionId: currentSessionId,
            windowStart: start,
            windowEnd: end,
            pauseRate: pauseRate,
            meanPauseDurationMs: meanPauseDuration,
            meanBurstLengthChars: meanBurst,
            burstLengthCV: burstCV,
            deletionDensity: deletionDensity,
            regressionFrequency: regressionFreq,
            frictionScore: frictionScore
        )
    }
}
