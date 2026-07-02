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
}
