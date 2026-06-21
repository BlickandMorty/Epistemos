import Testing
import Foundation
@testable import Epistemos

// SS-THX regression (owner 2026-06-20): after the theme-resolve cache (28402960d) fixed the
// switch HANG, a CUSTOM-COLOR edit took ~3 toggles before TK2 (the Prose editor) matched the tabs.
// Root: TK2 (ProseEditorRepresentable2) re-applies its theme only when `parent.theme` VALUE
// changes, but a custom-color edit keeps the same `.appCustom` enum case → the value-blind guard
// skipped applyTheme, while the tabs (reading the resolved palette via @Observable) DID update →
// they diverged until ~3 toggles forced a re-apply. Fix: thread the canonical appearance sync key
// (themeMode:pair:isDark:typographyRevision) into TK2 and re-apply when IT changes — that key
// bumps on every custom-color edit (the color tile calls refreshTypographySettings). One edit →
// all surfaces match at once.
@Suite("SS-THX — custom-color edits re-apply the TK2 theme (no 3-toggle convergence)")
struct SSTHXCustomThemeReapplyTests {

    @MainActor
    @Test("a custom-color edit (refreshTypographySettings) changes the appearance sync key TK2 observes")
    func customEditBumpsAppearanceSyncKey() {
        let ui = UIState()
        let before = ui.appearanceSyncKey
        // The custom-theme color tile calls `refreshTypographySettings()` after AppCustomTheme.setHex
        // — the SAME bump TK2's `themeSyncKey` now observes. The enum case is unchanged, but the key
        // (which folds in typographySettingsRevision) must change so TK2 re-applies.
        ui.refreshTypographySettings()
        #expect(ui.appearanceSyncKey != before)
    }

    @Test("TK2's theme guard observes themeSyncKey and re-applies on a key change (value-blind guard fixed)")
    func tk2GuardObservesThemeSyncKey() throws {
        let rep = try loadMirroredSourceTextFile("Epistemos/Views/Notes/ProseEditorRepresentable2.swift")
        // The guard fires on EITHER the theme value OR the appearance sync key (the custom-color case
        // the value-only guard used to skip).
        #expect(rep.contains("if parent.theme != lastTheme || parent.themeSyncKey != lastThemeSyncKey {"))
        #expect(rep.contains("let themeSyncKey: String"))
        // And the re-apply keeps the last key in sync so there's no spurious re-apply.
        #expect(rep.contains("lastThemeSyncKey = parent.themeSyncKey"))
    }

    @Test("the Prose editor passes the canonical appearance key into TK2")
    func proseViewPassesAppearanceKey() throws {
        let view = try loadMirroredSourceTextFile("Epistemos/Views/Notes/ProseEditorView.swift")
        #expect(view.contains("themeSyncKey: ui.appearanceSyncKey"))
    }
}
