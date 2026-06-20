import Testing
import Foundation
@testable import Epistemos

/// SS-F (owner 2026-06-19, settings robustness / "no fake toggles"): the
/// summaryInterval picker default must match the WorkspaceSummaryService truth (no
/// default drift), and the reader-less EPISTEMOS_GRAPH_INDEX_CHATS toggle must be
/// demoted to a disabled row — it has no runtime effect, so it can't masquerade as
/// a working switch.
@Suite("Settings robustness (SS-F)")
struct SettingsRobustnessTests {

    @Test("summaryInterval picker default matches the service truth (5m, no drift)")
    func summaryIntervalDefaultMatchesService() throws {
        // The service truth (WorkspaceSummaryService.summaryInterval) defaults to 5m.
        #expect(WorkspaceSummaryService.SummaryInterval.fiveMinutes.rawValue == "5m")
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        // The Settings @State default now falls back to the SAME value the service
        // uses (5m / .fiveMinutes) — not the old drifting 15m that the service
        // ignored on a fresh install.
        #expect(src.contains("forKey: \"epistemos.summaryInterval\") ?? \"5m\""))
        #expect(src.contains("?? .fiveMinutes"))
    }

    @Test("the reader-less graph-chat-indexing toggle is demoted to disabled (no fake switch)")
    func fakeGraphIndexToggleDisabled() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SettingsView.swift")
        // flagToggle can disable a reader-less flag, and the GRAPH_INDEX_CHATS
        // toggle now uses it instead of presenting a flippable no-op.
        #expect(src.contains(".disabled(disabled)"))
        #expect(src.contains("isOn: $graphIndexChatsEnabled,"))
        #expect(src.contains("disabled: true"))
    }
}
