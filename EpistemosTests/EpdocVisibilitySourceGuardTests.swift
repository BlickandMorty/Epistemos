import Foundation
import Testing

@Suite("Epdoc visibility source guards")
nonisolated struct EpdocVisibilitySourceGuardTests {
    @Test("File menu uses one Markdown note creation that defaults to Epdoc")
    func fileMenuUsesOneMarkdownNoteCreationThatDefaultsToEpdoc() throws {
        let appSource = try Self.loadSourceText("Epistemos/App/EpistemosApp.swift")
        let coordinatorSource = try Self.loadSourceText("Epistemos/Views/Notes/NoteCreationCoordinator.swift")

        #expect(appSource.contains("Button(\"New Note\")"),
                "File > New should expose one note command instead of separate prose/document storage commands.")
        #expect(appSource.contains("NoteCreationCoordinator.createAndOpen(vaultSync: vaultSync)"),
                "The File menu should route through the shared note creation coordinator.")
        #expect(!appSource.contains("Button(\"New Document\")"),
                "Document is now the default Markdown surface, not a second File > New item.")
        // Owner 2026-07-05: notes always open in Epdoc (Document) by default. The per-create
        // Prose/Document modal was removed — the four Markdown lenses are switchable from the
        // editor toggles, so there is no reason to prompt on every new note.
        #expect(coordinatorSource.contains("open(pageId, .document)"),
                "Note creation must open directly in Epdoc (Document) mode — Epdoc is the default note surface.")
        #expect(!coordinatorSource.contains("NSAlert"),
                "Note creation must not prompt a per-create Prose/Document modal.")
        #expect(!coordinatorSource.contains("chooseSurface()"),
                "The per-create surface chooser was removed in favor of an always-Epdoc default.")
    }

    @Test("Landing exposes one visible Markdown create shortcut")
    func landingExposesOneVisibleMarkdownCreateShortcut() throws {
        let source = try Self.loadSourceText("Epistemos/Views/Landing/LandingView.swift")

        #expect(source.contains("title: \"new note\""),
                "Landing should keep one obvious note creation entry point.")
        #expect(source.contains("NoteCreationCoordinator.createAndOpen("),
                "Landing creation should use the shared Prose/Document chooser.")
        #expect(!source.contains("title: \"new doc\""),
                "Landing must not advertise Document as a separate storage object.")
        #expect(!source.contains("createAndOpenDocument()"),
                "The old standalone .epdoc creation shortcut should not remain on the landing page.")
    }

    @Test("Home commands trigger expressive haptics")
    func landingCommandsTriggerHaptics() throws {
        let landing = try Self.loadSourceText("Epistemos/Views/Landing/LandingView.swift")
        let pixels = try Self.loadSourceText("Epistemos/Views/Landing/PixelSurfaceComponents.swift")
        let haptics = try Self.loadSourceText("Epistemos/Views/Shared/TypewriterMarkdown.swift")

        #expect(pixels.contains("let haptic: HomeCommandHapticStyle"))
        #expect(pixels.contains("HapticHelper.homeCommand(haptic)"),
                "Home command presses should pulse through the shared haptic helper, not each tile inventing its own AppKit feedback.")
        #expect(landing.contains("haptic: .capture"))
        #expect(landing.contains("haptic: .newNote"))
        #expect(haptics.contains("enum HomeCommandHapticStyle"))
    }

    @Test("Notes sidebar exposes one create action while saved epdocs remain visible")
    func notesSidebarExposesOneCreateActionWhileSavedEpdocsRemainVisible() throws {
        let source = try Self.loadSourceText("Epistemos/Views/Notes/NotesSidebar.swift")

        #expect(source.contains("let onNewPage: () -> Void"),
                "EditorActionsBar should keep one note creation callback.")
        #expect(source.contains("NoteCreationCoordinator.createAndOpen("),
                "Sidebar creation should use the shared Prose/Document chooser.")
        #expect(!source.contains("let onNewDocument: () -> Void"),
                "The sidebar should not carry a second document creation callback.")
        #expect(!source.contains("\"New Document (.epdoc)\""),
                "Document is an opening surface for Markdown notes, not a separate bottom-bar button.")
        #expect(source.contains("cachedDocumentItems"),
                "Saved .epdoc packages must be visible from the sidebar, not only creatable.")
        #expect(source.contains("DocumentsSection("),
                "Sidebar needs a first-class Documents section for saved .epdoc packages.")
    }

    @Test("Note windows expose Document as a Markdown-backed peer mode")
    func noteWindowsExposeDocumentAsMarkdownBackedPeerMode() throws {
        let workspace = try Self.loadSourceText("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let surface = try Self.loadSourceText("Epistemos/Views/Notes/MarkdownDocumentSurface.swift")

        #expect(workspace.contains("case document"),
                "Document should be a note workspace mode beside Prose/Preview/Source.")
        #expect(workspace.contains("MarkdownDocumentSurface("),
                "Document mode should mount the rich Epdoc surface over the note body.")
        #expect(workspace.contains("saveMarkdownDocumentSurfaceContent(page: page, markdown: markdown)"),
                "Document edits must write back through the Markdown note pipeline.")
        #expect(surface.contains("EpdocEditorChromeView(")
                && surface.contains("controller: coordinator.controller"),
                "The Markdown Document surface should reuse the existing Epdoc editor chrome.")
        #expect(surface.contains("markdownSource: markdown"),
                "The Document surface must seed from the current Markdown body, not empty package JSON.")
        #expect(surface.contains(".onChange(of: markdown)"),
                "The default Document surface must reload when the real note body arrives after first render.")
        #expect(surface.contains("latestMarkdown == lastFlushedMarkdown")
                && surface.contains("!controller.toolbarModel.isDirty"),
                "Late body reloads must be clean-only so a dirty open note is never silently clobbered.")
    }

    @Test("Epdoc chrome exposes projection info in the toolbar")
    func epdocChromeExposesProjectionInfoInToolbar() throws {
        let source = try Self.loadSourceText("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let surface = try Self.loadSourceText("Epistemos/Views/Notes/MarkdownDocumentSurface.swift")

        #expect(source.contains("onShowProjectionInfo"),
                "The shared Epdoc chrome should expose a host-overridable projection info action.")
        #expect(source.contains("Label(\"Projection Info\", systemImage: \"info.circle\")"),
                "The toolbar needs an explicit info affordance for how the projection works.")
        #expect(surface.contains("MarkdownDocumentProjectionInfoPresenter.present()"),
                "Markdown-backed note mode should explain that Document is another .md surface.")
    }

    @Test("Markdown Document mode keeps the note surface switcher visible")
    func markdownDocumentModeKeepsSurfaceSwitcherVisible() throws {
        let workspace = try Self.loadSourceText("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let surface = try Self.loadSourceText("Epistemos/Views/Notes/MarkdownDocumentSurface.swift")
        let chrome = try Self.loadSourceText("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")

        #expect(surface.contains("let surfaceToolbarAccessory: AnyView?"),
                "Markdown-backed Document mode should accept a compact note-surface switcher accessory.")
        #expect(surface.contains("surfaceToolbarAccessory: surfaceToolbarAccessory"),
                "The Markdown Document surface must pass the note-surface switcher into Epdoc chrome.")
        #expect(chrome.contains("surfaceToolbarAccessory"),
                "Epdoc chrome needs a host-provided surface slot so Document mode can keep the surface switcher visible.")
        #expect(chrome.contains(".overlay(alignment: .topTrailing)"),
                "The Document-mode switcher must not depend on macOS toolbar overflow layout.")
        #expect(workspace.contains("markdownDocumentSurfaceToolbarAccessory(for: page)"),
                "The note workspace should inject the same compact Prose/Document/Preview/Source buttons into Document mode.")
        #expect(workspace.contains("!isMarkdownDocumentSurfaceModeActive"),
                "The parent note toolbar should not duplicate the switcher while Document mode owns the visible copy.")
    }

    @Test("Epdoc windows reuse the native prose-note tab group")
    func epdocWindowUsesNativeNoteTabGroup() throws {
        // Guards against future refactor that would silently restore the
        // boxy two-tier "tauri-shaped" window chrome the user explicitly
        // rejected 2026-05-05. Epdoc should not carry a parallel hand-rolled
        // chrome path; it should reuse the same native helper as note windows.
        let source = try Self.loadSourceText("Epistemos/Engine/EpdocDocument.swift")

        #expect(source.contains("NoteWindowChrome.apply(to: window, toolbarIdentifier: \"EpdocDocument\")"),
                "Epdoc windows MUST reuse NoteWindowChrome so .epdoc and Prose note windows share the same transparent/full-size/unified native titlebar.")
        #expect(source.contains("hostingController.sceneBridgingOptions = [.all]"),
                "Epdoc's SwiftUI toolbar must bridge through the native backdrop wrapper; otherwise the formatting toolbar can disappear when themed.")
        #expect(source.contains(".fullSizeContentView"),
                "Epdoc window MUST extend its content view into the titlebar area via .fullSizeContentView styleMask.")
        #expect(source.contains("window.tabbingMode = .preferred"),
                "Epdoc windows should join native macOS tabbing, matching prose note windows.")
        #expect(source.contains("window.tabbingIdentifier = NoteWindowManager.noteTabbingIdentifier"),
                "Epdoc windows should share the prose note tab group instead of opening as a separate app-like surface.")
        #expect(source.contains("attachToExistingNoteTabGroup(window)"),
                "New Epdoc windows should attach to the current note/doc tab group when one exists.")
        #expect(source.contains("NoteWindowManager.firstAvailableNoteTabGroupWindow("),
                "Epdoc windows should use the shared note/doc tab-group locator so routing stays reciprocal with prose/code notes.")
        #expect(source.contains("window.minSize = NSSize(width: 400, height: 300)"),
                "Epdoc windows should stay freely resizable instead of force-expanding the entire native tab group.")
        #expect(!source.contains("ensureEpdocToolbarFits(in: existingWindow)"),
                "Epdoc tab attachment must not silently resize an existing note/doc window just to fit toolbar overflow.")
        #expect(source.contains("chromeController.loadInitialContent("),
                "EpdocDocument must push package.contentJSON into the WKWebView when the editor reports ready; otherwise opened docs can look blank.")
    }

    @Test("Epdoc chrome view uses the native prose-style toolbar instead of a second in-content UI")
    func epdocChromeViewUsesNativeToolbar() throws {
        let source = try Self.loadSourceText("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let toolbar = try Self.loadSourceText("Epistemos/Views/Epdoc/EpdocEditorToolbar.swift")

        #expect(source.contains("ToolbarItem(placement: .principal)"),
                "Epdoc formatting controls should live in the native toolbar like the Prose editor, not in a huge document body panel.")
        #expect(toolbar.contains(".padding(.horizontal, 10)"),
                "The native toolbar needs horizontal breathing room so the edge buttons are not clipped or offset.")
        #expect(source.contains("epdocFooter"),
                "Epdoc status should live as a quiet footer bubble, matching the Prose editor's word-count surface.")
        #expect(source.contains("if !controller.attachedRunIDs.isEmpty"),
                "Epdoc thought status must stay hidden until real run provenance exists.")
        #expect(!source.contains(".padding(.top, 28)"),
                "Epdoc must not reintroduce the oversized in-content toolbar top gutter.")
        #expect(!source.contains("RoundedRectangle(cornerRadius: 24, style: .continuous)"),
                "Epdoc must not render a second giant floating toolbar capsule inside the document.")
    }

    @Test("Epdoc editor canvas shows the native window theme instead of an OLED WebView plate")
    func epdocEditorCanvasUsesNativeThemeBacking() throws {
        let source = try Self.loadSourceText("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let document = try Self.loadSourceText("Epistemos/Engine/EpdocDocument.swift")
        let utilityWindows = try Self.loadSourceText("Epistemos/App/UtilityWindowManager.swift")
        let css = try Self.loadSourceText("js-editor/src/editor.css")

        #expect(source.contains("@Environment(UIState.self) private var ui: UIState?"),
                "Epdoc chrome should read the same native UIState theme as the rest of the app when environment injection is available.")
        #expect(source.contains("EpdocTiptapWebView(controller: controller, theme: theme)"),
                "The hosted WKWebView must receive the resolved app theme, not only WebKit's light/dark media query.")
        #expect(source.contains("EpdocEditorThemeStyle.applyScript(for: theme)"),
                "Epdoc must push semantic theme tokens into CSS variables for custom theme pairs.")
        #expect(source.contains("NoteWorkspaceSurfaceStyle.canvasBackground(for: theme).ignoresSafeArea()"),
                "Epdoc's native SwiftUI canvas should reuse the same note workspace theme surface.")
        #expect(document.contains("EpdocEditorDocumentRoot(controller: chromeController)"),
                "Epdoc document windows should mount through an environment root instead of an isolated SwiftUI island.")
        #expect(document.contains(".withAppEnvironment(bootstrap)"),
                "Epdoc document windows must use the same app environment injection path as note windows.")
        #expect(document.contains("NoteWindowThemeStyler.themedContentController"),
                "Epdoc windows should reuse the native note-window backdrop renderer for theme surfaces.")
        #expect(utilityWindows.contains("EpdocDocument.syncOpenDocumentThemes(uiState: uiState)"),
                "Theme changes should resync already-open .epdoc native window backdrops.")
        #expect(source.contains("view.setValue(false, forKey: \"drawsBackground\")"),
                "The macOS WKWebView must stop drawing its browser background so the native theme can show through.")
        #expect(source.contains("view.wantsLayer = true"),
                "The WKWebView should own a transparent backing layer rather than relying on an implicit black WebKit layer.")
        #expect(source.contains("view.layer?.backgroundColor = NSColor.clear.cgColor"),
                "The WKWebView layer must not paint a second OLED/browser background.")
        #expect(css.contains("--epdoc-bg: transparent;"),
                "The embedded editor CSS should let the native theme surface show through.")
        #expect(!css.contains("--epdoc-bg: #000000"),
                "Dark .epdoc mode must not force a pure OLED plate over the app theme.")
    }

    @Test("Epdoc WebView strips unsafe browser reload/navigation from the right-click menu")
    func epdocWebViewSuppressesReloadContextMenu() throws {
        let source = try Self.loadSourceText("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")

        #expect(source.contains("EpdocEditorWebView"),
                "Epdoc should use its own WKWebView subclass so unsafe browser context-menu actions can be filtered.")
        #expect(source.contains("EpdocContextMenuSanitizer.removeUnsafeBrowserCommands"),
                "Right-click menus must remove browser reload/back/forward; reload can drop unsaved live editor content.")
        #expect(source.contains("allowsBackForwardNavigationGestures = false"),
                "Epdoc packages are documents, not browser pages; navigation gestures should not mutate the live editor.")
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

    @Test("Epdoc toolbar commands are backed by live Tiptap actions and stats bridge")
    func epdocToolbarCommandsAreWired() throws {
        let inbound = try Self.loadSourceText("js-editor/src/bridge/inbound.ts")
        let slash = try Self.loadSourceText("js-editor/src/extensions/slash-menu.ts")
        let outbound = try Self.loadSourceText("js-editor/src/bridge/outbound.ts")
        let index = try Self.loadSourceText("js-editor/src/index.ts")
        let css = try Self.loadSourceText("js-editor/src/editor.css")
        let toolbar = try Self.loadSourceText("Epistemos/Views/Epdoc/EpdocEditorToolbar.swift")
        let chrome = try Self.loadSourceText("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let document = try Self.loadSourceText("Epistemos/Engine/EpdocDocument.swift")
        let bridge = try Self.loadSourceText("Epistemos/Engine/EpdocEditorBridge.swift")
        let bubbleMenu = try Self.loadSourceText("Epistemos/Views/Epdoc/EpdocBubbleMenuView.swift")
        let package = try Self.loadSourceText("js-editor/package.json")
        let chart = try Self.loadSourceText("js-editor/src/extensions/chart-node.ts")
        let codeBlock = try Self.loadSourceText("js-editor/src/extensions/code-block-node.ts")
        let imageAssetBridge = try Self.loadSourceText("js-editor/src/extensions/image-asset-bridge.ts")
        let imageNode = try Self.loadSourceText("js-editor/src/extensions/image-node.ts")
        let markdownInputRules = try Self.loadSourceText("js-editor/src/extensions/markdown-input-rules.ts")
        let blockInsert = try Self.loadSourceText("js-editor/src/extensions/block-insert.ts")
        let pasteBridge = try Self.loadSourceText("js-editor/src/extensions/paste-classifier-bridge.ts")
        let markdownPaste = try Self.loadSourceText("js-editor/src/markdown/markdown-paste.ts")

        #expect(inbound.contains("applySlashChoice(editor, blockType)"),
                "Swift toolbar insert buttons must execute the same concrete Tiptap actions as slash choices.")
        #expect(inbound.contains("postDocumentSnapshot(editor)"),
                "Toolbar-driven commands must push a fresh ProseMirror snapshot immediately so complexity/markdown projection do not lag behind word counts.")
        #expect(inbound.contains("editor.commands.setContent(parsed, { emitUpdate: false });\n        markHostDocumentLoaded();\n        postDocumentStats(editor);\n        requestAnimationFrame(() => postDocumentStats(editor));"),
                "Initial setContent is a loader, not an edit: it may refresh stats but must not emit contentDidChange/autosave and overwrite the package on open.")
        #expect(inbound.contains("markHostDocumentLoaded()"),
                "The inbound loader must mark the host package as loaded only after setContent succeeds.")
        #expect(index.contains("hasHostDocumentLoaded()")
                && index.contains("scheduleContentDidChange(ed)")
                && index.contains("postBridge({ type: 'contentDidChange', json: JSON.stringify(editor.getJSON()) });"),
                "Tiptap boot-placeholder updates must not emit contentDidChange until Swift has pushed the real package content.")
        #expect(inbound.contains("linkHrefFromArgs(args)") && inbound.contains("editor.chain().focus()"),
                "Toolbar commands must focus the editor and accept native Swift-provided link args instead of relying on JS prompt from evaluateJavaScript.")
        #expect(!inbound.contains("setMeta('slashMenuChoice'"),
                "Toolbar commands must not dispatch inert ProseMirror metadata with no plugin listener.")
        #expect(toolbar.contains("promptAndDispatchLink()") && toolbar.contains("promptAndDispatchImage()"),
                "Toolbar Link/Image buttons must use native AppKit affordances; WebKit suppresses JS prompt when invoked through evaluateJavaScript.")
        #expect(toolbar.contains(#"name: "insertEpdocImage""#) && toolbar.contains(#"name: "setLink""#),
                "Native toolbar affordances must dispatch concrete JS commands with args after the user picks/enters content.")
        #expect(toolbar.contains("NSOpenPanel()") && toolbar.contains("panel.allowedContentTypes = [.image]"),
                "The Image button must show a native image/file picker, not ask the user to type a URL.")
        #expect(toolbar.contains("resolvePickedImageSource") && toolbar.contains("data:\\(mimeType);base64,"),
                "The toolbar must preserve a data-URL fallback for previews/unsaved hosts while allowing real .epdoc documents to install a package-local asset writer.")
        #expect(document.contains("storeImageAsset") && document.contains(#""\(EpdocPackageEntry.assets)/\(filename)""#),
                "Saved .epdoc documents must store picked media in the package assets folder and insert a package-local image reference.")
        #expect(index.contains("imageAssetBridge()") && outbound.contains("type: 'storeImageAsset'"),
                "Pasted/dropped images must use the same native package-asset bridge as toolbar-picked images, not fall back to data URLs.")
        #expect(pasteBridge.contains("parseMarkdownPaste(plainText)")
                && pasteBridge.contains("postBridge({ type: 'contentDidChange', json: JSON.stringify(editor.getJSON()) })")
                && markdownPaste.contains("export function parseMarkdownPaste")
                && markdownPaste.contains("type: 'heading'")
                && markdownPaste.contains("type: 'codeBlock'")
                && markdownPaste.contains("type: 'epdocChart'")
                && markdownPaste.contains("type: 'epdocImage'")
                && markdownPaste.contains("type: 'table'")
                && markdownPaste.contains("type: 'taskList'")
                && markdownPaste.contains("type: 'inlineMath'")
                && markdownPaste.contains("type: 'highlight'")
                && markdownPaste.contains("epistemos-doc:wiki/"),
                "Epdoc must convert pasted markdown syntax (# headings, fenced code, charts, images, tables, tasks, inline marks, math, and wikilinks) into real Tiptap nodes immediately instead of waiting for a backspace/retype input rule.")
        #expect(index.contains("epdocMarkdownInputRules()")
                && markdownInputRules.contains("new InputRule")
                && markdownInputRules.contains("tableMarkdownInputFinder")
                && markdownInputRules.contains("parseMarkdownPaste(markdown)")
                && markdownInputRules.contains("node.type === 'table'")
                && markdownInputRules.contains("replaceInputWithBlockAndTrailingParagraph(state, range, tableNode)"),
                "Epdoc must turn typed Markdown table rows into real Tiptap tables when the divider row is completed.")
        #expect(markdownInputRules.contains("markdownLinkInputFinder")
                && markdownInputRules.contains("wikiLinkInputFinder")
                && markdownInputRules.contains("replaceInputWithInlineLink")
                && markdownInputRules.contains("epistemos-doc:wiki/${encodeURIComponent(target)}")
                && package.contains("\"check:markdown-input-rules\""),
                "Epdoc must turn typed markdown links and wikilinks into real Link marks, not leave them as inert bracket syntax.")
        #expect(imageNode.contains("addInputRules()")
                && imageNode.contains("parseMarkdownImageLine(match[0])")
                && imageNode.contains("epdocImage")
                && imageNode.contains("isSafeImageSrc(src)")
                && imageNode.contains("blocked unsafe image source")
                && imageNode.contains("data-epdoc-image-blocked")
                && imageNode.contains("replaceInputWithBlockAndTrailingParagraph(state, range, imageNode)")
                && blockInsert.contains("Math.min(range.from + blockNode.nodeSize + 1, tr.doc.content.size)"),
                "Epdoc must turn safe typed Markdown image syntax and pasted image URLs into real image nodes, while rejecting unsafe image sources from prompts/HTML/JSON render paths.")
        #expect(imageAssetBridge.contains("handlePaste")
                && imageAssetBridge.contains("handleDOMEvents")
                && imageAssetBridge.contains("drop")
                && imageAssetBridge.contains("completeImageAssetRequest")
                && imageAssetBridge.contains("MAX_IMAGE_BYTES = 20 * 1024 * 1024"),
                "Image paste/drop handling must capture real file bytes, preserve a pending insertion position, and complete with a native-stored asset reference.")
        #expect(chrome.contains("onStoreDocumentAsset") && chrome.contains(#""completeImageAssetRequest""#),
                "Swift must store JS-originated pasted/dropped images in the document package before telling JS to insert the returned src.")
        #expect(chrome.contains("onResolveDocumentAsset") && chrome.contains("EpdocEditorURLSchemeHandler(documentAssetResolver:"),
                "The WebView URL scheme handler must be wired to serve package-local .epdoc assets.")
        #expect(bridge.contains("documentAssetName(relativePath:")
                && bridge.contains("EpdocEditorDocumentAsset")
                && bridge.contains("Content-Type"),
                "The editor bridge must resolve epistemos-doc:///assets/... through the document package, not through bundle assets or network.")
        #expect(toolbar.contains(#"name: "toggleCodeBlock""#) && toolbar.contains("tip: \"Code block\""),
                "The toolbar must expose a real block-level code command; inline code alone only styles one selection/line and recreates the user's bug.")
        #expect(bubbleMenu.contains(#"name: "toggleCodeBlock""#),
                "The selection bubble must offer block-level code conversion for selected multi-line snippets.")
        #expect(inbound.contains("function toggleEpdocCodeBlock(editor: Editor): boolean")
                && inbound.contains("state.doc.textBetween(from, to, '\\n')")
                && inbound.contains("const codeBlockType = schema.nodes.codeBlock")
                && inbound.contains("$from.blockRange($to)")
                && inbound.contains("state.tr.replaceWith(replaceFrom, replaceTo, codeBlock)")
                && inbound.contains("TextSelection.near")
                && inbound.contains("{ language: 'swift' }"),
                "The visible Code block action must convert selected multi-line text into one real codeBlock node by replacing the selected block range; raw toggleCodeBlock/replaceRangeWith can recreate the one-card-per-line bug.")
        #expect(package.contains(#""@tiptap/extension-code-block-lowlight": "3.24.0""#) && package.contains(#""lowlight": "3.3.0""#),
                "Epdoc code blocks should use Tiptap's lowlight node rather than a bespoke highlighter or a heavy CodeMirror island for the V1.5 doc editor.")
        #expect(index.contains("StarterKit.configure") && index.contains("codeBlock: false") && index.contains("EpdocCodeBlock"),
                "The base StarterKit codeBlock must be replaced by the syntax-highlighted EpdocCodeBlock extension.")
        #expect(codeBlock.contains("CodeBlockLowlight") && codeBlock.contains("createLowlight(common)") && codeBlock.contains("highlight.js/lib/languages/swift") && codeBlock.contains("lowlight.register('swift', swift)") && codeBlock.contains("defaultLanguage: 'swift'") && codeBlock.contains("data-epdoc-code-block"),
                "The code-block extension must use lowlight, explicitly register Swift, default authored blocks to Swift highlighting, and tag the rendered pre for stable CSS/runtime smoke tests.")
        #expect(css.contains("pre[data-epdoc-code-block]") && css.contains(".hljs-keyword") && css.contains(".hljs-string"),
                "Epdoc code blocks must render as multi-line blocks with syntax colors, not only inline-code styling.")
        #expect(css.contains("--epdoc-card-radius: 18px")
                && css.contains("--epdoc-card-bg")
                && css.contains("--epdoc-card-header-bg: transparent")
                && css.contains("--epdoc-card-label-fg")
                && css.contains("border: 1px solid var(--epdoc-card-border)")
                && css.contains("box-shadow: none")
                && css.contains("font: 650 0.86em/1.2 \"SF Pro Text\"")
                && !css.contains("radial-gradient(circle at")
                && !css.contains("drop-shadow("),
                "Code, diagram, chart, and image boxes should follow a quiet native Apple card style with plain labels, transparent headers, modest borders, and no fake cinematic/glowy JS depth.")
        #expect(slash.contains("id: 'image'"),
                "The visible Image toolbar button must have a real .epdoc image action.")
        #expect(css.contains("img[data-epdoc-image]") && css.contains("max-width: 100%"),
                "Epdoc images must render as actual scaled document images, not a tiny broken-image/icon affordance.")
        #expect(slash.contains("type: 'blockMath'") && slash.contains("{ type: 'paragraph' }"),
                "The visible Math toolbar button must insert a valid Tiptap math node and a trailing paragraph so typing does not get trapped on the atom.")
        #expect(slash.contains("id: 'html-workspace'") && slash.contains("requestHTMLWorkspace"),
                "New visual/DOM creation must route to a first-class HTML Workspace, not an in-document Mermaid node.")
        #expect(!slash.contains("type: 'mermaid'") && !slash.contains("mermaid-flowchart") && !slash.contains("RESEARCH_DIAGRAM_TEMPLATES"),
                "The slash menu must not expose new Mermaid creation paths.")
        #expect(toolbar.contains("tip: \"HTML Workspace\"") && toolbar.contains("openHTMLWorkspace"),
                "The visible toolbar visual action must open a dedicated HTML Workspace.")
        #expect(!toolbar.contains(#"name: "insertEpdocGraphFromDocument""#),
                "The toolbar must not create Mermaid diagrams after the HTML Workspace replacement.")
        #expect(toolbar.contains("Label(tip, systemImage: symbol)") && toolbar.contains(".accessibilityLabel(Text(tip))"),
                "Icon-only toolbar buttons must carry the semantic action label for accessibility and Computer Use smoke tests.")
        #expect(inbound.contains("name === 'requestHTMLWorkspace'") && !inbound.contains("insertEpdocGraphFromDocument"),
                "The JS bridge must request the native HTML Workspace surface instead of deriving Mermaid source.")
        #expect(slash.contains("RESEARCH_CHART_TEMPLATES")
                && slash.contains("chart-scatter")
                && slash.contains("chart-bar")
                && slash.contains("chart-line"),
                "Epdoc needs true study-chart primitives for scatter/bar/line charts instead of pretending every chart is a Mermaid diagram.")
        #expect(index.contains("EpdocChartNode"),
                "The advertised chart slash entries must have a real Tiptap node registered.")
        #expect(chart.contains("insertEpdocChart")
                && chart.contains("value === 'scatter'")
                && chart.contains("value === 'bar'")
                && chart.contains("value === 'line'")
                && chart.contains("renderPointChart")
                && chart.contains("renderBarChart")
                && chart.contains("data-epdoc-chart"),
                "Epdoc charts must render real first-party scatter/bar/line charts from structured JSON, not inert placeholder text.")
        #expect(css.contains(".epdoc-chart")
                && css.contains(".epdoc-chart-point")
                && css.contains(".epdoc-chart-bar")
                && css.contains(".epdoc-chart-line")
                && css.contains(".epdoc-chart-source-wrap"),
                "Epdoc charts need polished research-card styling with real SVG marks and source-on-demand.")
        #expect(index.contains("CalloutNode"),
                "Advertised callout slash-menu commands must have a real Tiptap node registered.")
        #expect(css.contains(".ProseMirror table") && css.contains("border-collapse: collapse"),
                "The Table toolbar action must produce a visible grid, not an invisible empty structure.")
        #expect(Self.sourceCount(in: slash, needle: "apply: (e)") == 18
                && slash.contains("apply: requestHTMLWorkspace"),
                "Every advertised JS slash item should carry a concrete command implementation.")
        #expect(outbound.contains("type: 'documentStatsChanged'"))
        #expect(index.contains("postDocumentStats(ed)"),
                "Word/character counts must be pushed from the live CharacterCount extension.")
    }

    nonisolated private static func loadSourceText(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }

    nonisolated private static func sourceCount(in source: String, needle: String) -> Int {
        source.components(separatedBy: needle).count - 1
    }
}
