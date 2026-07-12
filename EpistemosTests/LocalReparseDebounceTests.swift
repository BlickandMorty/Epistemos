import Foundation
import AppKit
import Testing
@testable import Epistemos

/// Master Fusion Plan §C.4 / RCA4-P1-002 — pin the prose-editor
/// reparse-debounce machinery so the default coalesces typing bursts
/// and the explicit synchronous override stays frozen against
/// future refactors.
///
/// The existing audit row at `RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`
/// flagged the per-keystroke reparse path as bounded by fast Rust FFI
/// for typical notes but acknowledged the deferred optimization path
/// is a debounce. The current app default uses that machinery because
/// synchronous full-document reparses are a user-visible editor jank source.
@Suite("RCA4-P1-002 — §C.4 prose reparse debounce")
@MainActor
struct LocalReparseDebounceTests {

    @Test("Default debounce window coalesces prose reparses")
    func defaultDebounceWindowCoalescesProseReparses() {
        let view = ProseTextView2()
        #expect(
            view.reparseDebounceWindow == NoteEditorPerformancePolicy.proseReparseDebounceWindow,
            "ProseTextView2 must default to the shared prose reparse debounce so rapid typing does not synchronously reparse the whole document on every keystroke."
        )
        #expect(view.reparseDebounceWindow > 0)
    }

    @Test("Large prose documents use a longer effective reparse window")
    func largeDocumentsUseLongerEffectiveReparseWindow() {
        #expect(NoteEditorPerformancePolicy.proseReparseDebounceWindow(characterCount: 4_000) == 0.08)
        #expect(NoteEditorPerformancePolicy.proseReparseDebounceWindow(characterCount: 40_000) == 0.16)
        #expect(NoteEditorPerformancePolicy.proseReparseDebounceWindow(characterCount: 120_000) == 0.28)
    }

    @Test("Setting a positive window does not throw or panic")
    func settingPositiveWindowIsAccepted() {
        let view = ProseTextView2()
        view.reparseDebounceWindow = 0.05  // 50ms
        #expect(view.reparseDebounceWindow == 0.05)
        view.reparseDebounceWindow = 0.15  // 150ms upper-end of the §C.4 window
        #expect(view.reparseDebounceWindow == 0.15)
    }

    @Test("Window can be reset back to 0 (round-trip)")
    func windowResetsToZero() {
        let view = ProseTextView2()
        view.reparseDebounceWindow = 0.10
        view.reparseDebounceWindow = 0
        #expect(view.reparseDebounceWindow == 0)
    }

    @Test("Prose friction telemetry batches input events without dropping them")
    func proseFrictionTelemetryIsBatched() throws {
        let prose = try loadMirroredSourceTextFile(
            "Epistemos/Views/Notes/ProseTextView2.swift"
        )
        let monitor = try loadMirroredSourceTextFile(
            "Epistemos/State/FrictionMonitorService.swift"
        )

        #expect(prose.contains("private var pendingFrictionEvents: [EditorTelemetryEvent] = []"))
        #expect(prose.contains("private var frictionFlushTask: Task<Void, Never>?"))
        #expect(prose.contains("try? await Task.sleep(for: .milliseconds(50))"))
        #expect(prose.contains("await monitor.record(events)"))
        #expect(prose.contains("frictionFlushTask?.cancel()"))
        #expect(!prose.contains("Task.detached(priority: .utility) { await monitor.record(event) }"))
        #expect(monitor.contains("func record(_ batch: [EditorTelemetryEvent]) async"))
        #expect(monitor.contains("for event in batch"))
        #expect(monitor.contains("recordEnabled(event)"))
    }
}
