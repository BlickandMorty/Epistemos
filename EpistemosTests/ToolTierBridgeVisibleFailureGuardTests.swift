import Testing
import Foundation
@testable import Epistemos

/// RCA2-P1-016 drift gate — `ToolTierBridge` must surface tool-list
/// failures via NotificationCenter so tool-capable UI surfaces can
/// distinguish "Rust bindings broke" from "tier intentionally
/// disabled."
///
/// Acceptance criterion: "Tool-capable surfaces fail closed with
/// visible diagnostics when tools are unavailable."
///
/// Structural reality (verified 2026-05-13):
///   - The catch branch logs at `.error` level (not `.warning`) so a
///     failure can't be silently buried by log filters.
///   - It posts a `Notification.Name.toolTierBridgeLoadFailed` so
///     subscribed UI (chat composer capability pill, command-center
///     diagnostics row) can show a "tools unavailable" indicator
///     instead of silently running in zero-tools mode.
///   - The empty `[]` return remains for compatibility so the
///     existing call sites don't crash, but the failure is no
///     longer silent.
///
/// This suite pins those invariants so a future refactor that
/// downgrades the log level or removes the notification trips CI
/// before the silent-degradation behavior re-emerges.
@Suite("RCA2-P1-016 ToolTierBridge Visible Failure Guard")
struct ToolTierBridgeVisibleFailureGuardTests {

    @Test("ToolTierBridge error path posts a toolTierBridgeLoadFailed notification")
    func errorPathPostsNotification() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Bridge/ToolTierBridge.swift"
        )
        // The catch branch must post the canonical notification.
        #expect(source.contains(".toolTierBridgeLoadFailed"),
            "ToolTierBridge must post .toolTierBridgeLoadFailed in its catch branch so capability-aware UI can show diagnostics — see RCA2-P1-016")
        // And the notification name must be declared so subscribers
        // can listen for it without string matching.
        #expect(source.contains("static let toolTierBridgeLoadFailed = Notification.Name"),
            "ToolTierBridge must keep the toolTierBridgeLoadFailed Notification.Name declaration — see RCA2-P1-016")
    }

    @Test("ToolTierBridge logs failures at error level, not warning")
    func failureLogIsErrorLevel() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Bridge/ToolTierBridge.swift"
        )
        // Pin "Tool list fetch FAILED" + that it appears inside a
        // logger.error( call. The audit's load-bearing change was
        // bumping the level from .warning to .error so log filters
        // can't hide the failure.
        let failurePhrase = "Tool list fetch FAILED"
        #expect(source.contains(failurePhrase),
            "ToolTierBridge must retain the 'Tool list fetch FAILED' log phrase so log searches surface the failure — see RCA2-P1-016")
        // Find the line containing the failure phrase, look
        // upstream for `logger.error` to prove the level. A simple
        // substring check is sufficient because the phrase is
        // unique.
        let lines = source.components(separatedBy: "\n")
        var foundAtErrorLevel = false
        for (idx, line) in lines.enumerated() where line.contains(failurePhrase) {
            // The logger call begins on the line above the format
            // string when the format spans multiple lines; scan a
            // 3-line window upward.
            for back in max(0, idx - 3)..<idx + 1 {
                if lines[back].contains("logger.error(") {
                    foundAtErrorLevel = true
                    break
                }
            }
            if foundAtErrorLevel { break }
        }
        #expect(foundAtErrorLevel,
            "The 'Tool list fetch FAILED' message must be emitted inside a `logger.error(` call — see RCA2-P1-016 (a downgrade to warning would let log filters silently hide tool-loop failures)")
    }

    @Test("ToolTierBridge fallback path also logs visibly when FFI is unlinked")
    func unlinkedFFIFailsVisibly() throws {
        let source = try loadMirroredSourceTextFile(
            "Epistemos/Bridge/ToolTierBridge.swift"
        )
        // The `#else` branch (when agent_coreFFI isn't linked into
        // this target) must also log at error level so the
        // condition is visible. Specific phrase: "agent_coreFFI not
        // linked".
        #expect(source.contains("agent_coreFFI not linked"),
            "ToolTierBridge must keep the 'agent_coreFFI not linked' diagnostic in its `#else` branch — see RCA2-P1-016")
    }
}
