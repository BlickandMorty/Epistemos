import Testing
import Foundation
@testable import Epistemos

/// WORK = OpenCode shell — native terminal view (owner 2026-06-21, Option A). Verifies
/// the real terminal-view layer: the launch-spec→SwiftTerm env mapping, the early
/// de-risk smoke spec, and (source-guard) that the view actually drives SwiftTerm's
/// PTY + themes to the app + stays honest (no fake terminal). The NSViewRepresentable
/// itself can't render in a unit test, so the pure helpers carry the behavioral load.
@Suite("Work = OpenCode shell — native terminal view")
struct WorkTerminalViewTests {
    #if os(macOS)
    @Test("env dict → SwiftTerm ['KEY=VALUE'] array, deterministically ordered")
    func envArrayMapping() {
        let arr = workShellEnvironmentArray(["B": "2", "A": "1"])
        #expect(arr == ["A=1", "B=2"])   // sorted → deterministic for tests + reproducible PTYs
    }

    @Test("empty spec env falls back to the process environment (PTY still needs PATH/HOME)")
    func envFallback() {
        let arr = workShellEnvironmentArray([:])
        #expect(arr.isEmpty == false)
        #expect(arr.contains { $0.hasPrefix("PATH=") || $0.hasPrefix("HOME=") })
    }

    @Test("smoke spec is the login shell rooted at the workspace (early native-render de-risk)")
    func smokeSpec() {
        let ws = URL(fileURLWithPath: "/tmp/work-ws")
        let spec = WorkShellLaunchSpec.smokeLoginShell(workspace: ws)
        #expect(spec.arguments == ["-l"])
        #expect(spec.workingDirectory == ws)
        #expect(spec.executableURL.path.contains("sh") || spec.executableURL.path.contains("zsh"))
    }
    #endif

    @Test("the terminal view drives SwiftTerm's real PTY + themes native + stays honest")
    func nativeTerminalWiring() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Work/WorkTerminalView.swift")
        #expect(src.contains("import SwiftTerm"))
        #expect(src.contains("LocalProcessTerminalView"))     // SwiftTerm's real PTY NSView
        #expect(src.contains("startProcess("))                // actually spawns a PTY process
        #expect(src.contains("nativeBackgroundColor") && src.contains("nativeForegroundColor")) // themed
        // Honest: a placeholder when no real terminal can launch — never a fake terminal.
        #expect(src.contains("WorkTerminalUnavailableView"))
        // Option A discipline: render the REAL terminal, not a web GUI. Guard the
        // actual web-view CODE construct (not prose — the header names Electron/Tauri
        // only to say we DON'T use them).
        #expect(!src.contains("WKWebView("))
        #expect(!src.contains("import WebKit"))
    }

    @Test("launch-spec failures surface as a themed unavailable state instead of a stuck spinner")
    func launchSpecFailuresSurface() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Work/WorkTerminalView.swift")
        #expect(src.contains("@State private var resolveError"))
        #expect(src.contains("WorkTerminalUnavailableView(detail: resolveError, palette: palette)"))
        #expect(src.contains("fallback: \"Couldn't start Epistemos Work terminal\""))
        #expect(src.contains("WorkServerDiagnostics.statusMessage("))
        #expect(!src.contains("error.localizedDescription"))
        #expect(!src.contains("String(describing: error)"))
        #expect(!src.contains("resolvedSpec = (try? await realShellSpec())"))
    }

    @Test("the terminal is FULLY theme-responsive — derives from the live app theme + re-applies live (§162)")
    func terminalIsThemeResponsive() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Work/WorkTerminalView.swift")
        // Palette derives from the app theme (NOT a hardcoded constant for the live path).
        #expect(src.contains("static func from(theme:"))
        #expect(src.contains("theme.resolved.background") && src.contains("theme.resolved.foreground"))
        #expect(src.contains("background: .textBackgroundColor"))
        #expect(src.contains("foreground: .labelColor"))
        #expect(src.contains("cursor: .controlAccentColor"))
        #expect(!src.contains("calibratedRed"))
        #expect(!src.contains("cream/ink"))
        // Reads the LIVE theme via the @Observable UIState → recolors on every theme change (incl. custom).
        #expect(src.contains("@Environment(UIState.self)"))
        #expect(src.contains("ui.theme"))
        // updateNSView re-applies the palette LIVE (recolors the running PTY without relaunching).
        #expect(src.contains("func updateNSView") && src.contains("applyPalette("))
    }
}
