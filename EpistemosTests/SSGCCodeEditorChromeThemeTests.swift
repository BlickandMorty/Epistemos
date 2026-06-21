import Testing
import Foundation

// SS-GC (owner 2026-06-20, REOPENED — "the code editor … has a top portion that is not the theme
// so there is a white bar at the top on the graph"; a "green-but-not-reaching" regression): every
// code-editor CHROME surface must paint the embedded-graph backdrop — not a near-white
// `surfaceVariant(.other)` card — when CodeEditorView receives a themeOverride. The main top bar
// (codeEditorTopBar) already respected the override, but the Live Preview header — the top-most
// chrome on a preview-capable file — still hardcoded the white card, so it popped as a white bar
// over the dark graph. Lock the full-consistency fix: all code-editor chrome resolves its fill
// through `resolvedTopBarBackground(themeOverride:base:)`, and the embedded-graph mount passes the
// override. Source-guard — the pixel render is owner-verified on-device; this guards the wiring so
// it can't silently regress.
@Suite("SS-GC — code-editor chrome respects the embedded-graph theme (no white bar)")
struct SSGCCodeEditorChromeThemeTests {

    @Test("the embedded-graph mount passes a themeOverride to CodeEditorView (mirrors the prose branch)")
    func mountPassesThemeOverride() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        #expect(src.contains("themeOverride: usesEmbeddedHomeGraphSurface ? noteWorkspaceTheme : nil"))
    }

    @Test("no code-editor chrome hardcodes the white card token, ignoring themeOverride")
    func noChromeHardcodesWhiteCard() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        // The white-bar bug: chrome filled with `flatBackground(for: ui.theme.surfaceVariant(.other))`
        // ignores the override and paints a near-white card over the dark graph backdrop.
        #expect(
            !src.contains("flatBackground(for: ui.theme.surfaceVariant(.other))"),
            "code-editor chrome must resolve its fill through resolvedTopBarBackground(themeOverride:), never a hardcoded .other card")
    }

    @Test("the top bar AND the Live Preview header both resolve their fill through themeOverride")
    func chromeResolvesThroughOverride() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Notes/CodeEditorView.swift")
        // resolvedTopBarBackground returns the graph backdrop when an override is present, else the card.
        #expect(src.contains("if let themeOverride {"))
        #expect(src.contains("AppWindowBackdropStyle.background(for: themeOverride)"))
        // Two chrome consumers: the main top bar (codeEditorTopBar) + the Live Preview header
        // (the reopened gap). Both must funnel through the one override-aware helper.
        let needle = ".background(Self.resolvedTopBarBackground(themeOverride: themeOverride, base: ui.theme))"
        let consumers = src.components(separatedBy: needle).count - 1
        #expect(
            consumers >= 2,
            "both codeEditorTopBar and the Live Preview header must use resolvedTopBarBackground (found \(consumers))")
    }
}
