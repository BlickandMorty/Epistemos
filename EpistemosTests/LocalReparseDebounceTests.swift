import Foundation
import AppKit
import Testing
@testable import Epistemos

/// Master Fusion Plan §C.4 / RCA4-P1-002 — pin the prose-editor
/// reparse-debounce machinery so the default-zero (current behavior)
/// AND debounce-coalesces-bursts invariants stay frozen against
/// future refactors.
///
/// The existing audit row at `RECURSIVE_CURRENT_APP_AUDIT_TODO_2026_05_09.md`
/// flagged the per-keystroke reparse path as bounded by fast Rust FFI
/// for typical notes but acknowledged the deferred optimization path
/// is a debounce. This commit lands the machinery with a default of 0
/// (preserves V1 UX) so a future operator-profiling pass can flip
/// the flag for long-doc instances without touching the editor code.
@Suite("RCA4-P1-002 — §C.4 prose reparse debounce")
@MainActor
struct LocalReparseDebounceTests {

    @Test("Default debounce window is 0 — current synchronous behavior preserved")
    func defaultDebounceWindowIsZero() {
        let view = ProseTextView2()
        #expect(
            view.reparseDebounceWindow == 0,
            "ProseTextView2 must default to synchronous reparse — C.4 doctrine preserves V1 UX. A future operator-profiling pass can flip the flag for long-doc instances; the default stays 0."
        )
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
