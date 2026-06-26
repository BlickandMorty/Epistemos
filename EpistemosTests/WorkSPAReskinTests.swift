import Foundation
import Testing
@testable import Epistemos

@Suite("Work SPA reskin — CSS-variable injection (no SPA rebuild)")
struct WorkSPAReskinTests {
    @Test("cssColor emits lowercase #rrggbb for opaque colors")
    func cssColorHex() {
        #expect(WorkSPAReskin.cssColor(.hex(0xFF0000)) == "#ff0000")
        #expect(WorkSPAReskin.cssColor(.hex(0x00FF00)) == "#00ff00")
        #expect(WorkSPAReskin.cssColor(.hex(0x1C2024)) == "#1c2024")
    }

    @Test("cssColor emits rgba() for translucent colors")
    func cssColorAlpha() {
        let css = WorkSPAReskin.cssColor(.hex(0x102030, opacity: 0.5))
        #expect(css.hasPrefix("rgba(") && css.contains("0.5"))
    }

    @Test("styleBlock overrides both selectors + the high-impact tokens with !important")
    func styleBlock() {
        let css = WorkSPAReskin.styleBlock(theme: EpistemosTheme.nativeDefault.resolved)
        #expect(css.hasPrefix("<style id=\"epistemos-reskin\">"))
        #expect(css.contains(":root,[data-theme=\"dark\"]{"))
        for token in ["--dls-app-bg:", "--dls-text-primary:", "--dls-accent:",
                      "--background:", "--foreground:", "--primary:", "--border:"] {
            #expect(css.contains(token))
        }
        #expect(css.contains("!important;"))
        #expect(css.hasSuffix("</style>"))
    }

    @Test("DUI rules: monospace everywhere, flat/boxy (radius 0 + no shadow), block caret")
    func duiRules() {
        let css = WorkSPAReskin.styleBlock(theme: EpistemosTheme.nativeDefault.resolved)
        // monospace forced on non-SVG elements
        #expect(css.contains("font-family:ui-monospace") && css.contains(":not(svg)"))
        // flat + boxy
        #expect(css.contains("border-radius:0!important") && css.contains("box-shadow:none!important"))
        #expect(css.contains("[class*=\"bg-gradient-\"]") && css.contains("background-image:none!important"))
        #expect(css.contains("--radius:0px!important") || css.contains("--dls-radius:0px!important"))
        // block caret
        #expect(css.contains("caret-shape:block"))
        // the helper is also directly testable
        #expect(WorkSPAReskin.duiRules(accent: "#abcdef").contains("#abcdef"))
    }

    @Test("fallback WebView copy is Epistemos-branded without stale OpenCode fallback label")
    func fallbackWebViewCopyIsEpistemosBranded() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Work/WorkWebSurfaceView.swift")
        #expect(src.contains(#""Epistemos Work fallback""#))
        #expect(src.contains("Local engine bridge over loopback"))
        #expect(!src.contains(#""OpenCode loopback fallback""#))
        #expect(!src.contains("OpenCode engine over local loopback"))
    }

    @Test("native Work chrome keeps square settings and rail surfaces")
    func nativeWorkChromeKeepsSquareSurfaces() throws {
        let settings = try loadMirroredSourceTextFile("Epistemos/Views/Settings/WorkCloneSettingsView.swift")
        let rail = try loadMirroredSourceTextFile("Epistemos/Work/WorkSessionRailView.swift")

        #expect(settings.contains(".clipShape(Rectangle())"))
        #expect(rail.contains(".clipShape(Rectangle())"))
        #expect(rail.contains("Hidden when nil so Work never exposes no-op detach chrome."))
        #expect(rail.contains("if session.presentation == .attached, let onDetach"))
        #expect(rail.contains("else if session.presentation == .detached, let onReattach"))
        #expect(!settings.contains("RoundedRectangle(cornerRadius: 8"))
        #expect(!rail.contains("RoundedRectangle(cornerRadius: 6"))
    }
}
