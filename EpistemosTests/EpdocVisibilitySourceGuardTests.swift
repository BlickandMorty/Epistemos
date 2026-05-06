import Foundation
import Testing

@Suite("Epdoc visibility source guards")
nonisolated struct EpdocVisibilitySourceGuardTests {
    @Test("File menu exposes New Document through the native epdoc document controller path")
    func fileMenuExposesNewDocument() throws {
        let appSource = try Self.loadSourceText("Epistemos/App/EpistemosApp.swift")
        let controllerSource = try Self.loadSourceText("Epistemos/App/EpistemosDocumentController.swift")

        #expect(appSource.contains("Button(\"New Document\")"),
                "The replaced File > New group must expose a visible .epdoc creation path.")
        #expect(appSource.contains("createEpdocDocument()"),
                "New Document should route through one dedicated command helper, not duplicate AppKit plumbing inline.")
        #expect(controllerSource.contains("makeUntitledDocument(ofType: \"com.epistemos.epdoc\")"),
                "The command must force the canonical .epdoc UTI instead of relying on AppKit's default type choice.")
        #expect(controllerSource.contains("document.makeWindowControllers()"))
        #expect(controllerSource.contains("document.showWindows()"))
    }

    @Test("Landing exposes a visible New Doc shortcut for epdoc creation")
    func landingExposesNewDocShortcut() throws {
        let source = try Self.loadSourceText("Epistemos/Views/Landing/LandingView.swift")

        #expect(source.contains("label: \"New Doc\""),
                "Landing must project .epdoc creation visibly instead of hiding it only in File > New.")
        #expect(source.contains("createAndOpenDocument()"),
                "Landing New Doc action should route through one command helper.")
        #expect(source.contains(".keyboardShortcut(\"n\", modifiers: [.command, .option])"),
                "Landing should honor the native ⌥⌘N New Document shortcut.")
    }

    @Test("Notes sidebar exposes New Document in the creation action bar")
    func notesSidebarExposesNewDocumentAction() throws {
        let source = try Self.loadSourceText("Epistemos/Views/Notes/NotesSidebar.swift")

        #expect(source.contains("let onNewDocument: () -> Void"),
                "EditorActionsBar needs a dedicated .epdoc creation callback, not a note-only surface.")
        #expect(source.contains("SidebarIconButton(icon: \"doc.badge.plus\", tooltip: \"New Document (.epdoc)\")"),
                "Notes sidebar bottom bar must visibly expose .epdoc creation.")
        #expect(source.contains("NSDocumentController.shared.createUntitledEpdocDocument()"),
                "Notes sidebar should use the shared NSDocumentController epdoc creation path.")
    }

    @Test("Epdoc window chrome uses macOS 26 liquid-glass settings (transparent titlebar + full-size content + unified toolbar)")
    func epdocWindowUsesLiquidGlassChrome() throws {
        // Guards against future refactor that would silently restore
        // the boxy two-tier "tauri-shaped" window chrome the user
        // explicitly rejected 2026-05-05. The combination of
        // titlebarAppearsTransparent + .fullSizeContentView +
        // titleVisibility = .hidden + .unified toolbar style is what
        // produces the curvy macOS 26 native bar that matches Prose's
        // NS-native feel.
        let source = try Self.loadSourceText("Epistemos/Engine/EpdocDocument.swift")

        #expect(source.contains("window.titlebarAppearsTransparent = true"),
                "Epdoc window MUST have a transparent titlebar — the SwiftUI material below shows through at the top to give the liquid-glass look.")
        #expect(source.contains(".fullSizeContentView"),
                "Epdoc window MUST extend its content view into the titlebar area via .fullSizeContentView styleMask.")
        #expect(source.contains("window.titleVisibility = .hidden"),
                "Epdoc window MUST hide the AppKit title text (the EpdocComplexityMeter row carries the doc title visibly already).")
        #expect(source.contains("window.toolbarStyle = .unified"),
                "Epdoc window MUST use .unified toolbar style for the curvy macOS 26 single-surface chrome (vs the prior two-tier boxy look).")
    }

    @Test("Epdoc chrome view applies regularMaterial background to toolbar (liquid-glass)")
    func epdocChromeViewUsesMaterialBackground() throws {
        // Guards the SwiftUI side of the liquid-glass chrome — the
        // toolbar HStack must apply .background(.regularMaterial)
        // so the NSWindow's transparent titlebar shows the
        // translucent surface the user asked for.
        let source = try Self.loadSourceText("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")

        #expect(source.contains(".background(.regularMaterial)"),
                "Epdoc chrome toolbar MUST use .background(.regularMaterial) for the liquid-glass strip that pairs with the transparent NSWindow titlebar.")
    }

    @Test("EpdocEditorURLSchemeHandler decompresses brotli server-side (WKWebView custom scheme does NOT auto-decode)")
    func epdocURLSchemeHandlerDecompressesBrotli() throws {
        // Critical regression guard 2026-05-05: WKWebView's custom-
        // URL-scheme handler path does NOT auto-decompress
        // Content-Encoding: br (only the HTTPS path does). The handler
        // MUST decompress brotli server-side using Compression.framework
        // and serve plain bytes WITHOUT a Content-Encoding header.
        // If a future refactor removes the import or the decompression
        // call, the editor will silently fall back to serving compressed
        // bytes that WKWebView can't render — the editor area will
        // appear blank ("the user reports 'i dont see ant texts' bug").
        let source = try Self.loadSourceText("Epistemos/Engine/EpdocEditorBridge.swift")

        #expect(source.contains("import Compression"),
                "EpdocEditorBridge MUST import Compression for brotli decompression — see WKWebView custom-scheme limitation 2026-05-05.")
        #expect(source.contains("decompressBrotli"),
                "EpdocEditorBridge MUST define a decompressBrotli helper to handle the .br assets the URL scheme handler serves.")
        #expect(source.contains("COMPRESSION_BROTLI"),
                "Brotli decompression MUST use Compression.framework's COMPRESSION_BROTLI algorithm (macOS 11+).")
        #expect(source.contains("if asset.contentEncoding == \"br\""),
                "URL scheme handler MUST branch on contentEncoding == \"br\" before serving — otherwise compressed bytes reach the renderer and the editor silently breaks.")
    }

    nonisolated private static func loadSourceText(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }
}
