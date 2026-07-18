import Foundation
import Testing

@Suite("Epdoc visibility source guards")
nonisolated struct EpdocVisibilitySourceGuardTests {
    @Test("File menu separates Markdown notes from canonical JSON Epdoc documents")
    func fileMenuSeparatesMarkdownNotesFromJSONEpdocs() throws {
        let appSource = try Self.loadSourceText("Epistemos/App/EpistemosApp.swift")
        let coordinatorSource = try Self.loadSourceText("Epistemos/Views/Notes/NoteCreationCoordinator.swift")

        #expect(appSource.contains("Button(\"New Markdown Document (.md)\")"),
                "File > New must name the Markdown creation command by its real format.")
        #expect(appSource.contains("NoteCreationCoordinator.createAndOpen(vaultSync: vaultSync)"),
                "The File menu should route through the shared note creation coordinator.")
        #expect(appSource.contains("Button(\"New JSON Document (.epdoc)\")"),
                "The independent JSON-native Epdoc type needs an accurate format-explicit command.")
        #expect(appSource.contains("createUntitledEpdocDocument(in: vaultSync.vaultURL)"),
                "New Epdoc must route through the existing NSDocument package controller.")
        #expect(coordinatorSource.contains("open(pageId, .defaultMarkdown)"),
                "Markdown-note creation must open the Markdown family's Prose default.")
        #expect(!coordinatorSource.contains("NSAlert"),
                "Markdown-note creation must not prompt for an unrelated Epdoc document type.")
        #expect(!coordinatorSource.contains("chooseSurface()"),
                "Markdown and Epdoc are separate creation commands, not a per-note lens chooser.")
    }

    @Test("Landing exposes distinct native Markdown and JSON document shortcuts")
    func landingExposesNativeMarkdownAndJSONDocumentShortcuts() throws {
        let source = try Self.loadSourceText("Epistemos/Views/Landing/LandingView.swift")
        let commands = try Self.loadSourceText("Epistemos/Views/Landing/PixelSurfaceComponents.swift")

        #expect(source.contains("title: \"Markdown (.md)\""),
                "Landing should name Markdown creation by its real file format.")
        #expect(source.contains("NoteCreationCoordinator.createAndOpen("),
                "Landing Markdown creation should use the shared Markdown-note coordinator.")
        #expect(source.contains("title: \"JSON Document (.epdoc)\""),
                "Landing should expose standalone canonical JSON Epdoc creation distinctly.")
        #expect(source.contains("action: createAndOpenEpdocDocument"),
                "The JSON document shortcut must invoke the canonical Epdoc package route.")
        #expect(source.contains("createUntitledEpdocDocument(in: vaultSync.vaultURL)"),
                "Landing must create the real .epdoc package, not a loose JSON or Markdown substitute.")
        #expect(source.contains(".accessibilityLabel(\"New JSON Document (.epdoc)\")"),
                "The new format-specific command needs an explicit VoiceOver label.")
        #expect(!source.contains("title: \"new doc\""),
                "The ambiguous retired Document label must not return.")
        #expect(commands.contains(".hoverGlass("),
                "Landing commands must restore the exact native hover-only liquid-glass treatment.")
        #expect(commands.contains("if let shortcut"),
                "Keyboard hints must be visible content, not tooltip-only metadata.")
        #expect(commands.contains("allowDisplayFont: false"),
                "Landing commands must use the old regular system typography rather than a pixel display face.")
        #expect(!commands.contains("PixelCommandTypewriterText("),
                "The pixel/typewriter replacement must not remain in the restored native command component.")
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
        #expect(source.contains("Text(\"Markdown (.md)\")"),
                "The sidebar must name ordinary note files by their real Markdown extension.")
        #expect(source.contains("Text(\"JSON Documents (.epdoc)\")"),
                "The sidebar must explain that rich documents are JSON-backed .epdoc packages.")
        #expect(source.contains("accessibilityLabel(\"JSON Document: \\(item.title)\")"),
                "Saved Epdoc rows need format-explicit VoiceOver labels.")
    }

    @Test("Markdown note windows exclude independent Epdoc while Epdoc stays a real package document")
    func markdownWindowsExcludeIndependentEpdocPackage() throws {
        let workspace = try Self.loadSourceText("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let document = try Self.loadSourceText("Epistemos/Engine/EpdocDocument.swift")
        let package = try Self.loadSourceText("Epistemos/Models/EpdocPackage.swift")

        #expect(workspace.contains("case document"),
                "The legacy enum case remains temporarily for rollback/migration, but is not a Markdown mode.")
        #expect(workspace.contains("hasSourceRoute ? [.edit, .preview, .source] : [.edit, .preview]"),
                "Markdown notes must expose one .md through Prose, Preview, and Source only.")
        #expect(workspace.contains("static let defaultMarkdown: NoteWorkspaceMode = .edit"),
                "New and reopened Markdown notes must default to Prose.")
        #expect(document.contains("public final class EpdocDocument: NSDocument"),
                "Epdoc remains a first-class independent macOS document.")
        #expect(package.contains("public var contentJSON: Data"),
                "The .epdoc package must retain a canonical JSON body distinct from Markdown.")
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
                "Epdoc must push semantic theme tokens into CSS variables for every preset theme pair.")
        #expect(source.contains("MarkdownPreviewSurfaceStyle.solidFlatBackground(for: theme.surfaceVariant(.other))")
                && source.contains(".ignoresSafeArea()"),
                "Epdoc's native SwiftUI canvas should reuse the same explicit solid editor-body surface instead of a browser/OLED plate.")
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
        let documentLoadState = try Self.loadSourceText("js-editor/src/bridge/document-load-state.ts")
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
        #expect(inbound.contains("postDocumentSnapshot(editor, callbacks.postMarkdownSnapshot)"),
                "Toolbar-driven commands may push a fresh ProseMirror snapshot and host-provided Markdown snapshot at explicit command boundaries; ordinary Markdown-surface typing must stay on minimal writeback.")
        #expect(inbound.contains("const loadEpoch = beginLoad(editor.view, undefined, normalizeLoadEpoch(epoch));")
                && inbound.contains(".setMeta(HOST_LOAD_META, true)")
                && inbound.contains(".setMeta(EPOCH_META, loadEpoch)")
                && inbound.contains(".setContent(parsed, { emitUpdate: false })")
                && inbound.contains("postBridge({ type: 'loadSettled', epoch });"),
                "Initial setContent is a loader, not an edit: it must be epoch-stamped and guarded instead of relying on emitUpdate:false.")
        #expect(documentLoadState.contains("export function markHostDocumentLoaded")
                && documentLoadState.contains("loadStatePlugin")
                && documentLoadState.contains("filterTransaction")
                && documentLoadState.contains("Tiptap #1715/#4828"),
                "The inbound loader must layer the LUMENLENS loadEpoch/filterTransaction guard onto the existing host-loaded gate.")
        #expect(index.contains("hasHostDocumentLoaded()")
                && index.contains("scheduleContentDidChange(ed)")
                && index.contains("LoadStateExtension")
                && index.contains("!isDocumentLoadSettling(ed.state)")
                && index.contains("epoch: currentLoadEpoch(editor.state)")
                && index.contains("if (markdownProjectionMode)")
                && index.contains("postBridge({\n      type: 'contentDidChange',"),
                "Tiptap boot-placeholder/load transactions must not emit contentDidChange until Swift has pushed and settled the real package content.")
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
                && pasteBridge.contains("type: 'contentDidChange'")
                && pasteBridge.contains("epoch: currentLoadEpoch(editor.state)")
                && pasteBridge.contains("json: JSON.stringify(editor.getJSON())")
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
                && chart.contains("hasChartProvenance")
                && chart.contains("Chart provenance required before render")
                && chart.contains("renderPointChart")
                && chart.contains("renderBarChart")
                && chart.contains("data-epdoc-chart"),
                "Epdoc charts must render real first-party scatter/bar/line charts from structured JSON only after provenance is present, not inert or unaudited placeholder text.")
        #expect(css.contains(".epdoc-chart")
                && css.contains(".epdoc-chart-point")
                && css.contains(".epdoc-chart-bar")
                && css.contains(".epdoc-chart-line")
                && css.contains(".epdoc-chart-provenance")
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

    @Test("LumenLens suggestions use the handlewithcare adapter spine")
    func lumenLensSuggestionsUseHandleWithCareAdapterSpine() throws {
        let package = try Self.loadSourceText("js-editor/package.json")
        let index = try Self.loadSourceText("js-editor/src/index.ts")
        let inbound = try Self.loadSourceText("js-editor/src/bridge/inbound.ts")
        let payloadGuard = try Self.loadSourceText("js-editor/src/bridge/suggestion-payload.ts")
        let outbound = try Self.loadSourceText("js-editor/src/bridge/outbound.ts")
        let adapter = try Self.loadSourceText("js-editor/src/suggestions/SuggestionAdapter.ts")
        let marks = try Self.loadSourceText("js-editor/src/suggestions/marks.ts")
        let css = try Self.loadSourceText("js-editor/src/editor.css")

        #expect(package.contains(#""@handlewithcare/prosemirror-suggest-changes": "0.1.8""#)
                && package.contains(#""check:suggestions": "node scripts/check-suggestions.mjs""#),
                "LumenLens L1 must carry the real HWC suggest-changes dependency plus a focused JS adapter check.")
        #expect(index.contains("EpdocSuggestionDocument")
                && index.contains("document: false")
                && index.contains("new HwcSuggestionAdapter")
                && index.contains("editor.view.dispatch = suggestionAdapter.decorateDispatch")
                && index.contains("installInboundCommands(editor, {")
                && index.contains("suggestionAdapter,"),
                "The live editor schema/dispatch path must mount the suggestion document, disable StarterKit's duplicate doc node, and wrap dispatch with the HWC adapter.")
        #expect(inbound.contains("suggestChangesKey")
                && inbound.contains(".setMeta(suggestChangesKey, { skip: true })")
                && inbound.contains("name === 'applySuggestion'")
                && inbound.contains("name === 'acceptSuggestion'")
                && inbound.contains("name === 'rejectSuggestion'")
                && inbound.contains("SuggestionPayload")
                && inbound.contains("postSuggestionApplied(editor, payload)")
                && inbound.contains("postSuggestionResolved(editor, id, 'accepted')")
                && outbound.contains("type: 'suggestionApplied'")
                && outbound.contains("type: 'suggestionResolved'"),
                "Host loads must skip suggestion transformation while agent suggestions, applied-span events, and accept/reject commands stay on the typed inbound/outbound bridge.")
        #expect(payloadGuard.contains("export function suggestionPayloadFromArgs")
                && payloadGuard.contains("normalizeNonNegativeInteger")
                && payloadGuard.contains("Number.isInteger(value)")
                && payloadGuard.contains("to < from")
                && payloadGuard.contains("mapVersion === null"),
                "The JS bridge must reject malformed suggestion payloads before applying an edit so native provenance cannot receive float, negative, or inverted ranges.")
        #expect(adapter.contains("withSuggestChanges")
                && adapter.contains("transformToSuggestionTransaction")
                && adapter.contains("applyHwcSuggestion")
                && adapter.contains("revertHwcSuggestion")
                && adapter.contains("export class NoopSuggestionAdapter"),
                "SuggestionAdapter must use the real HWC transaction transformer and keep the no-op adapter compiling for rollout fallbacks.")
        #expect(marks.contains("EpdocSuggestionDocument")
                && marks.contains("marks: 'insertion modification deletion'")
                && marks.contains("name: 'insertion'")
                && marks.contains("name: 'deletion'")
                && marks.contains("name: 'modification'")
                && marks.contains("suggestChanges()"),
                "The ProseMirror schema must expose HWC insertion/deletion/modification marks and install the suggestChanges plugin.")
        #expect(css.contains(".ProseMirror ins[data-id]")
                && css.contains(".ProseMirror del[data-id]")
                && css.contains("[data-type=\"modification\"]"),
                "Tracked changes need visible in-document affordances for inserted, deleted, and modified content.")
    }

    @Test("LumenLens markdown tiers and fidelity disclosure are wired")
    func lumenLensMarkdownTiersAndFidelityDisclosureAreWired() throws {
        let tiers = try Self.loadSourceText("js-editor/src/markdown/tiers.ts")
        let roundtrip = try Self.loadSourceText("js-editor/scripts/check-markdown-roundtrip.mjs")
        let disclosure = try Self.loadSourceText("Epistemos/Views/Notes/LensFidelityDisclosure.swift")
        let workspace = try Self.loadSourceText("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")

        #expect(tiers.contains("export enum SerializerTier")
                && tiers.contains("canonical-lossless")
                && tiers.contains("custom-extension")
                && tiers.contains("byte-preserving-opaque")
                && tiers.contains("export function pickTier")
                && tiers.contains("export function roundTrip")
                && tiers.contains("export function splitFrontmatter")
                && tiers.contains("LENS_FIDELITY_REGISTRY")
                && tiers.contains("opaqueQuarantine"),
                "LumenLens L2 needs an explicit Tier A/B/C registry, selector, round-trip adapter, byte-preserving frontmatter split, and Tier C quarantine path.")
        #expect(roundtrip.contains("const roundTripAdapter")
                && roundtrip.contains("roundTrip(markdown, roundTripAdapter)")
                && roundtrip.contains("desktopCommander440")
                && roundtrip.contains("assert.doesNotMatch")
                && roundtrip.contains("quarantineResult.tier")
                && roundtrip.contains("disclosureItemsForLens")
                && roundtrip.contains("slice(0, 120)")
                && roundtrip.contains("expected at least 100 markdown corpus files"),
                "The executable markdown check must cover #440 frontmatter/table/wikilink escaping, Tier C quarantine, disclosure registry output, and a 100+ file corpus.")
        #expect(disclosure.contains("enum LensFidelityDisclosure")
                && disclosure.contains("static func items(")
                && disclosure.contains("in markdown: String,")
                && disclosure.contains("lens: NoteWorkspaceMode,")
                && disclosure.contains("enum LensFidelityState")
                && disclosure.contains("enum LensFidelityExportKind")
                && disclosure.contains("case image")
                && disclosure.contains("case csv")
                && disclosure.contains("case xlsx")
                && disclosure.contains("protocol LensFidelityDatasetExportProviding")
                && disclosure.contains("struct LensFidelityDatasetReference")
                && disclosure.contains("datasetExportProvider:")
                && disclosure.contains("prioritizedDatasetExports")
                && disclosure.contains("enum LensFidelityPreview")
                && disclosure.contains("case chart(LensFidelityChartPreview)")
                && disclosure.contains("let provenance: String")
                && disclosure.contains("chartProvenanceSummary(from:")
                && disclosure.contains("LensFidelityChartPreviewView")
                && disclosure.contains("referenceCSV(kind:")
                && disclosure.contains("svgImage(for chart:")
                && disclosure.contains("type: \"epdocChart\"")
                && disclosure.contains("type: \"opaqueQuarantine\"")
                && disclosure.contains("LensFidelityDisclosureExporter")
                && disclosure.contains("NSPasteboard.general")
                && disclosure.contains("NSSavePanel()")
                && disclosure.contains("struct LensFidelityDisclosureSection"),
                "The native note surface needs a real per-lens fidelity parser plus copy/export actions and a reusable disclosure section.")
        #expect(workspace.contains("LensFidelityDisclosure.items")
                && workspace.contains("LensFidelityDisclosureSection")
                && workspace.contains("setNoteMode(.document, for: page)")
                && workspace.contains("showInfoPopover = false"),
                "The existing Info popover should host degraded/invisible lens content and let users jump to Document mode.")
    }

    @Test("LumenLens minimal-diff writeback uses changedRange and byte splicing")
    func lumenLensMinimalDiffWritebackUsesChangedRangeAndByteSplicing() throws {
        let package = try Self.loadSourceText("js-editor/package.json")
        let index = try Self.loadSourceText("js-editor/src/index.ts")
        let inbound = try Self.loadSourceText("js-editor/src/bridge/inbound.ts")
        let outbound = try Self.loadSourceText("js-editor/src/bridge/outbound.ts")
        let writeback = try Self.loadSourceText("js-editor/src/markdown/minimal-diff-writeback.ts")
        let tracker = try Self.loadSourceText("js-editor/src/markdown/writeback-tracker.ts")
        let check = try Self.loadSourceText("js-editor/scripts/check-minimal-writeback.mjs")
        let bridge = try Self.loadSourceText("Epistemos/Engine/EpdocEditorBridge.swift")
        let chrome = try Self.loadSourceText("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let surface = try Self.loadSourceText("Epistemos/Views/Notes/MarkdownDocumentSurface.swift")
        let surfaceTests = try Self.loadSourceText("EpistemosTests/EditorProvenanceStoreTests.swift")

        #expect(package.contains(#""check:minimal-writeback": "node scripts/check-minimal-writeback.mjs""#),
                "LumenLens L3 needs a focused executable gate for minimal-diff writeback.")
        #expect(writeback.contains("oldSet.changedRange(input.newSet, input.maps)")
                && writeback.contains("topLevelBlockRange")
                && writeback.contains("docFromTopLevelRange")
                && writeback.contains("indexMarkdownBlocks")
                && writeback.contains("splitFrontmatter")
                && writeback.contains("utf8ByteLength")
                && writeback.contains("applyWritebackRegion")
                && writeback.contains("normalizeReplacementLineEndings"),
                "Minimal writeback must use prosemirror-changeset changedRange, expand to top-level block spans, preserve frontmatter offsets, compute UTF-8 byte ranges, and splice in memory.")
        #expect(tracker.contains("class MarkdownWritebackTracker")
                && tracker.contains("reset(editor: Editor, markdown: string)")
                && tracker.contains("recordTransaction")
                && tracker.contains("consume(editor: Editor, currentMarkdown?: string")
                && tracker.contains("this.reset(editor, currentMarkdown ?? safeMarkdownSnapshot(editor))")
                && tracker.contains("minimalWriteback({")
                && tracker.contains("editor.markdown?.serialize"),
                "The live editor must track a loaded markdown baseline, accumulate StepMaps, serialize only the changed doc range through Tiptap markdown, and avoid full snapshots on successful minimal-writeback edits.")
        #expect(index.contains("new MarkdownWritebackTracker()")
                && index.contains("markdownWritebackTracker.recordTransaction")
                && index.contains("markdownWritebackTracker.consume")
                && index.contains("markdownProjectionMode")
                && index.contains("postMarkdownSnapshot: (ed) => postMarkdownDidChange(ed, { preferWriteback: false })")
                && inbound.contains("resetMarkdownWritebackBaseline")
                && inbound.contains("postMarkdownSnapshot")
                && inbound.contains("setMarkdownProjectionMode")
                && outbound.contains("writeback?: MarkdownWritebackRegionPayload"),
                "Minimal writeback must be wired into live outbound markdown snapshots without breaking the existing full-snapshot path.")
        #expect(bridge.contains("struct EpdocMarkdownWritebackRegion")
                && bridge.contains("case markdownDidChange(markdown: String, writeback: EpdocMarkdownWritebackRegion?)")
                && bridge.contains("decodeEnvelope(messageBody:")
                && bridge.contains("parseWritebackRegion")
                && bridge.contains("blockMarkdown"),
                "The Swift bridge must decode the optional writeback region instead of treating L3 as a JS-only optimization.")
        #expect(chrome.contains("onMarkdownChanged: @Sendable @MainActor (String, EpdocMarkdownWritebackRegion?) -> Void")
                && chrome.contains("case let .markdownDidChange(markdown, writeback)")
                && chrome.contains("onMarkdownChanged(markdown, writeback)"),
                "The chrome controller must preserve the writeback region while retaining the existing full Markdown snapshot path.")
        #expect(surface.contains("scheduleMarkdownSave(_ markdown: String, writeback: EpdocMarkdownWritebackRegion?)")
                && surface.contains("apply(writeback:")
                && surface.contains("samePosition(in: markdown)")
                && surface.contains("byteFrom == writeback.byteFrom")
                && surface.contains("blockMarkdown"),
                "The Markdown Document surface must apply minimal writeback regions safely and fall back to full Markdown when validation fails.")
        #expect(surface.contains("private var markdownSaveWorkerGeneration: UInt64 = 0"))
        #expect(surface.contains("guard saveTask == nil else { return }"))
        #expect(surface.contains("let markdownToSave = self.latestMarkdown"))
        #expect(surface.contains("private func cancelMarkdownSaveWorker()"))
        #expect(check.contains("seedChangeSet(originalDoc)")
                && check.contains("oldSet.addSteps")
                && check.contains("Buffer.byteLength('Alpha\\n\\nBravé')")
                && check.contains("large fixture must be multi-MB")
                && check.contains("large-doc writeback range should cover only one block")
                && check.contains("fallback reset should allow the next edit to use a fresh baseline"),
                "The L3 gate must prove one-block edits, UTF-8 byte offsets, frontmatter preservation, multi-MB one-region behavior, and baseline reset after full-snapshot fallback.")
        #expect(surfaceTests.contains("markdown document surface applies minimal writeback regions before saving")
                && surfaceTests.contains("markdown document surface falls back to full markdown when writeback validation fails")
                && surfaceTests.contains("coordinator.flushPendingMarkdown()"),
                "L3 needs native harness proof that the document surface saves valid writeback splices and falls back to full snapshots when validation fails.")
    }

    @Test("LumenLens L4 session state machine owns note write leases")
    func lumenLensSessionStateMachineOwnsNoteWriteLeases() throws {
        let machine = try Self.loadSourceText("Epistemos/Views/Notes/NoteSessionStateMachine.swift")
        let workspace = try Self.loadSourceText("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let documentSurface = try Self.loadSourceText("Epistemos/Views/Notes/MarkdownDocumentSurface.swift")
        let codeEditor = try Self.loadSourceText("Epistemos/Views/Notes/CodeEditorView.swift")
        let markEditState = try Self.loadSourceText("Epistemos/Views/Notes/MarkEditCoreEditorState.swift")
        let focusedTests = try Self.loadSourceText("EpistemosTests/NoteSessionStateMachineTests.swift")

        #expect(machine.contains("case idle")
                && machine.contains("case loading(epoch: UInt64?)")
                && machine.contains("case clean")
                && machine.contains("case dirty(since: Date)")
                && machine.contains("case autosaving(reason: NoteSessionSaveReason)")
                && machine.contains("case externalChange(pendingReload: Bool)")
                && machine.contains("case conflict(diff3Base: String)"),
                "L4 needs an explicit note-session state machine, not scattered booleans around the workspace.")
        #expect(machine.contains("final class NoteSessionLeaseRegistry")
                && machine.contains("final class NoteSessionGRDBLeaseStore")
                && machine.contains("CREATE TABLE IF NOT EXISTS note_session")
                && machine.contains("NoteSessionLeaseStore")
                && machine.contains("func handoffLease(to nextOwnerID: String) -> Bool")
                && machine.contains("autosaveDebounceMilliseconds = 800")
                && machine.contains("autosaveCeilingMilliseconds = 5_000")
                && machine.contains("documentedV1UndoLossAcrossLensSwitch"),
                "The state machine must encode one write lease, a GRDB note_session row, handoff, autosave cadence, and the documented v1 undo-loss policy.")
        #expect(workspace.contains("@State private var noteSession: NoteSessionStateMachine")
                && workspace.contains("vaultSync.searchService?.databaseWriter()")
                && workspace.contains("noteSession.configureLeaseStore(")
                && workspace.contains("_ = noteSession.open()")
                && workspace.contains("noteSession.close()")
                && workspace.contains("noteSession.externalBodyChanged")
                && workspace.contains("case .conflict")
                && workspace.contains("noteSession.switchLens(to: NoteSessionLens(mode))")
                && workspace.contains("flushCurrentEditor(reason: .lensSwitch)")
                && workspace.contains("beginNoteSessionWrite(reason:"),
                "The note workspace must open/close the session, defer dirty external changes, and route saves through the write lease.")
        #expect(workspace.contains("private var editorSurfacesAcceptInput: Bool")
                && workspace.contains("noteSession.canWrite || noteSession.currentOwnerID == nil")
                && workspace.contains("isEditable: editorSurfacesAcceptInput"),
                "Editor surfaces must accept local input before the async lease check finishes, while saves still route through the write lease.")
        #expect(documentSurface.contains("let isEditable: Bool")
                && documentSurface.contains("guard self?.isEditable == true else"),
                "Document mode must suppress follower saves until the web editor has first-class read-only controls.")
        #expect(codeEditor.contains("let isEditable: Bool")
                && codeEditor.contains("if isEditable {")
                && markEditState.contains("readOnlyMode: !isEditable"),
                "Source mode must thread the lease into the existing MarkEdit/CoreEditor read-only mode and suppress follower debounced writes.")
        #expect(focusedTests.contains("lease ownership persists in the GRDB note_session row")
                && focusedTests.contains("NoteSessionGRDBLeaseStore(databaseWriter:")
                && focusedTests.contains("try store.ownerID(for: \"note-db\") == \"owner\""),
                "L4 needs a focused executable test for the persistent note_session lease row, not only source-shape assertions.")
    }

    @Test("LumenLens L5 suggestion provenance ledger replays and compacts")
    func lumenLensSuggestionProvenanceLedgerReplaysAndCompacts() throws {
        let suggestionSchema = try Self.loadSourceText("agent_core/src/provenance/suggestion_schema.rs")
        let editorStore = try Self.loadSourceText("Epistemos/Views/Notes/EditorProvenanceStore.swift")
        let focusedTests = try Self.loadSourceText("EpistemosTests/EditorProvenanceStoreTests.swift")
        let provenanceMod = try Self.loadSourceText("agent_core/src/provenance/mod.rs")
        let rustBridge = try Self.loadSourceText("agent_core/src/bridge.rs")
        let swiftBridge = try Self.loadSourceText("Epistemos/Engine/EpdocEditorBridge.swift")
        let chrome = try Self.loadSourceText("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let documentSurface = try Self.loadSourceText("Epistemos/Views/Notes/MarkdownDocumentSurface.swift")
        let workspace = try Self.loadSourceText("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let bridgeTests = try Self.loadSourceText("EpistemosTests/EpdocEditorBridgeTests.swift")
        let outboundCheck = try Self.loadSourceText("js-editor/scripts/check-bridge-outbound.mjs")
        let project = try Self.loadSourceText("project.yml")

        #expect(suggestionSchema.contains("pub struct Suggestion")
                && suggestionSchema.contains("pub enum AcceptState")
                && suggestionSchema.contains("pub enum Author")
                && suggestionSchema.contains("pub struct Range")
                && suggestionSchema.contains("pub fn is_companion_turn"),
                "L5 needs the full attributed suggestion schema: author, turn, ranges, before/after, rationale, citation, and accept-state.")
        #expect(suggestionSchema.contains("pub enum ObjectType")
                && suggestionSchema.contains("pub enum RangePayload")
                && suggestionSchema.contains("pub struct TabularRange")
                && suggestionSchema.contains("TabularA1")
                && suggestionSchema.contains("SuggestionMustStartPending")
                && suggestionSchema.contains("tabular_suggestion_stages_a1_payload_and_accepts_only_by_event"),
                "Prompt 4 requires one suggestion schema for prose and RECKONER tabular/A1 changes, with agent-authored changes staged pending before approval.")
        #expect(suggestionSchema.contains("events: Vec<SuggestionLedgerEvent>")
                && suggestionSchema.contains("next_event_sequence")
                && suggestionSchema.contains("pub fn events_since")
                && suggestionSchema.contains("pub fn snapshot")
                && suggestionSchema.contains("pub fn replay(events")
                && suggestionSchema.contains("blake3::hash"),
                "The suggestion ledger must copy the ClaimLedger idiom: append-only events, monotonic sequence, cursor reads, replay, and BLAKE3 snapshot bundles.")
        #expect(suggestionSchema.contains("insert_suggestion")
                && suggestionSchema.contains("accept_suggestion")
                && suggestionSchema.contains("reject_suggestion")
                && suggestionSchema.contains("revert_turn")
                && suggestionSchema.contains("SuggestionRevertOperation")
                && suggestionSchema.contains("accept_state_history"),
                "Accept/reject/revert must be first-class ledger operations, not caller-side mutations.")
        #expect(suggestionSchema.contains("DEFAULT_SUGGESTION_EVENT_RETENTION")
                && suggestionSchema.contains("pub fn compact")
                && suggestionSchema.contains("SuggestionCompactedEvent")
                && suggestionSchema.contains("retained_tail_events"),
                "L5 must include a real retention/compaction checkpoint story instead of an append-forever event list.")
        #expect(suggestionSchema.contains("stress_10_000_suggestions_replay_and_compact")
                && suggestionSchema.contains("10_000")
                && suggestionSchema.contains("SuggestionReplayBundle::from_replay_bytes"),
                "The focused Rust tests must prove replay after restart and a 10k-suggestion compaction stress case.")
        #expect(provenanceMod.contains("pub mod suggestion_schema")
                && provenanceMod.contains("SuggestionLedger")
                && provenanceMod.contains("SuggestionReplayBundle"),
                "The Rust provenance module must export the L5 suggestion ledger as a peer of ClaimLedger.")
        #expect(rustBridge.contains("suggestion_provenance_ledger_snapshot_json")
                && rustBridge.contains("suggestion_provenance_ledger_recent_events_json")
                && rustBridge.contains("suggestion_provenance_ledger_summary_json"),
                "The Phase-1 Rust suggestion ledger should expose read-only FFI audit surfaces without inventing a durable Rust DB.")
        #expect(swiftBridge.contains("struct EpdocSuggestionResolution")
                && swiftBridge.contains("struct EpdocSuggestionSpanPayload")
                && swiftBridge.contains("case suggestionApplied(EpdocSuggestionSpanPayload)")
                && swiftBridge.contains("case suggestionResolved(EpdocSuggestionResolution)")
                && swiftBridge.contains(#"case "suggestionApplied":"#)
                && swiftBridge.contains(#"case "suggestionResolved":"#)
                && swiftBridge.contains("EpdocSuggestionResolutionState(rawValue: stateRaw)"),
                "Swift must decode JS suggestionApplied/suggestionResolved events as typed applied spans and accepted/rejected bridge decisions.")
        #expect(chrome.contains("onSuggestionApplied: @Sendable @MainActor (EpdocSuggestionSpanPayload) -> Void")
                && chrome.contains("onSuggestionResolved: @Sendable @MainActor (EpdocSuggestionResolution) -> Void")
                && chrome.contains("requiresMatchingLoadEpoch")
                && chrome.contains(".contentDidChange,")
                && chrome.contains(".markdownDidChange,")
                && chrome.contains(".documentStatsChanged,")
                && chrome.contains(".loadSettled,")
                && chrome.contains(".suggestionApplied,")
                && chrome.contains(".suggestionResolved:")
                && chrome.contains("case let .suggestionApplied(payload)")
                && chrome.contains("case let .suggestionResolved(resolution)")
                && chrome.contains("onSuggestionApplied(payload)")
                && chrome.contains("onSuggestionResolved(resolution)")
                && chrome.contains("epoch: EpdocBridgeMessage.decodeEpoch(messageBody: body)"),
                "The Epdoc chrome controller must fan suggestion applied/decision events out to the owning note surface through the epoch-filtered WK bridge path.")
        #expect(editorStore.contains("struct SuggestionSpanRecord")
                && editorStore.contains("enum SuggestionState")
                && editorStore.contains("enum EditSource")
                && editorStore.contains("protocol EditorProvenanceStoring")
                && editorStore.contains("struct EditorProvenanceBridgeSink")
                && editorStore.contains("func persistApplied")
                && editorStore.contains("source: .agent")
                && editorStore.contains("SuggestionState(resolution.state)")
                && editorStore.contains("actor EditorProvenanceGRDBStore")
                && editorStore.contains("CREATE TABLE IF NOT EXISTS suggestion_span")
                && editorStore.contains("addColumnIfMissing")
                && editorStore.contains("claim_id TEXT")
                && editorStore.contains("source_citation TEXT")
                && editorStore.contains("CREATE TABLE IF NOT EXISTS suggestion_span_summary")
                && editorStore.contains("func pendingAgentSpans(turnID:")
                && editorStore.contains("func compact(keepResolvedMost recent: Int)")
                && editorStore.contains("mergedClaimIDs")
                && editorStore.contains("compactionSummaries"),
                "L5 durable editor provenance must persist spans in the existing GRDB writer with claim_id linkage and a non-append-forever compaction summary.")
        #expect(documentSurface.contains("let provenanceStore: (any EditorProvenanceStoring)?")
                && documentSurface.contains("let noteRelativePath: String")
                && documentSurface.contains("final class MarkdownDocumentSurfaceCoordinator")
                && documentSurface.contains("EditorProvenanceBridgeSink(store:")
                && documentSurface.contains("controller.onSuggestionApplied")
                && documentSurface.contains("controller.onSuggestionResolved")
                && documentSurface.contains("provenanceWriteTail")
                && documentSurface.contains("await previous?.value")
                && documentSurface.contains("func flushPendingProvenanceWrites() async")
                && documentSurface.contains("func flushPendingSurfaceWrites() async")
                && documentSurface.contains("await coordinator.flushPendingSurfaceWrites()")
                && documentSurface.contains("failed to persist suggestion span")
                && documentSurface.contains("failed to persist suggestion decision")
                && !documentSurface.contains("try? await sink.persistApplied")
                && !documentSurface.contains("try? await sink.persistResolved")
                && workspace.contains("@State private var editorProvenanceStore: EditorProvenanceGRDBStore?")
                && workspace.contains("EditorProvenanceGRDBStore(databaseWriter:")
                && workspace.contains("noteRelativePath: page.vaultRelativeNotePath")
                && workspace.contains("provenanceStore: editorProvenanceStore"),
                "Document mode must wire applied spans and accepted/rejected suggestion decisions into the durable editor provenance store when the database writer exists, and must log persistence failures instead of swallowing them.")
        #expect(project.contains("  Epistemos-AppStore:\n    type: application")
                && project.contains("      - path: Epistemos\n        type: syncedFolder")
                && !project.contains("EditorProvenanceStore.swift")
                && !editorStore.contains("KINDRED_ENABLED")
                && !editorStore.contains("EPISTEMOS_EXPERIMENTAL")
                && !editorStore.contains("ExperimentalAgent")
                && !editorStore.contains("Process("),
                "The durable editor provenance store must remain MAS-safe shared source: included through the App Store synced folder and free of companion/Experimental/subprocess gates.")
        #expect(focusedTests.contains("suggestion spans persist, decide, and query by turn")
                && focusedTests.contains("compaction trims resolved spans into per-turn summary")
                && focusedTests.contains("duplicate span ids fail without overwriting the original row")
                && focusedTests.contains("bridge sink persists applied spans and resolution decisions")
                && focusedTests.contains("spans survive a fresh store and writer reopen")
                && focusedTests.contains("spans survive app search-service writer reopen")
                && focusedTests.contains("markdown document surface teardown flushes markdown and provenance writes")
                && focusedTests.contains("schema install upgrades legacy provenance tables")
                && focusedTests.contains("EditorProvenanceGRDBStore(databaseWriter:")
                && focusedTests.contains("sourceCitation")
                && focusedTests.contains("claim:span-1")
                && focusedTests.contains("claim:resolved-3"),
                "L5 needs executable Swift proof for durable GRDB span persistence, applied-span insertion, duplicate-ID collision safety, decision updates, claim linkage, fresh-writer reopen, repeated compaction, and bridge-resolution persistence.")
        #expect(bridgeTests.contains("suggestionResolved decodes accepted and rejected decisions")
                && bridgeTests.contains("suggestionApplied decodes the original tracked span payload")
                && bridgeTests.contains("batched bridge envelope decodes messages with epochs")
                && bridgeTests.contains("chrome controller forwards suggestion resolution decisions")
                && bridgeTests.contains("chrome controller forwards applied suggestion spans")
                && bridgeTests.contains("chrome controller ignores stale epoch suggestion events"),
                "L5 needs bridge-level executable proof that JS applied-span and decision events reach the native controller handoff without leaking stale host-load epochs.")
        #expect(outboundCheck.contains("postBridge")
                && outboundCheck.contains("postedPayloads[0].type, 'batch'")
                && outboundCheck.contains("markdownDidChange")
                && outboundCheck.contains("writeback")
                && outboundCheck.contains("suggestionResolved")
                && outboundCheck.contains("span-batch"),
                "L5 needs executable JS proof that the outbound WK bridge batches L3 writeback and L5 suggestion decision payloads in the shape Swift decodes.")
    }

    @Test("Free V1 preserves legacy Epdoc bytes without compiling a notebook presentation surface")
    func freeV1EpdocNotebookCompatibilityIsParserOnly() throws {
        let notebook = try Self.loadSourceText("Epistemos/Views/Notes/EpdocNotebookManifest.swift")
        let workspace = try Self.loadSourceText("Epistemos/Views/Notes/NoteDetailWorkspaceView.swift")
        let toc = try Self.loadSourceText("Epistemos/Views/Notes/NoteTableOfContents.swift")
        let disclosure = try Self.loadSourceText("Epistemos/Views/Notes/LensFidelityDisclosure.swift")
        let tests = try Self.loadSourceText("EpistemosTests/EpdocNotebookManifestTests.swift")
        let roundtrip = try Self.loadSourceText("js-editor/scripts/check-markdown-roundtrip.mjs")

        #expect(notebook.contains("struct EpdocNotebookManifest")
                && notebook.contains("fenceInfoString = \"epistemos-notebook\"")
                && notebook.contains("frontmatterKey = \"_epistemos_notebook\"")
                && notebook.contains("upsertingFrontmatterManifest")
                && notebook.contains("blockScalarRange(forKey:")
                && notebook.contains("canonicalReferenceLine")
                && notebook.contains("EpdocNotebookInlineRowDataGuard")
                && notebook.contains("normalizedFreeV1SelectedTabID")
                && !notebook.contains("struct EpdocNotebookTabStrip")
                && !notebook.contains("struct EpdocNotebookLauncherPane")
                && !notebook.contains("struct EpdocNotebookReferencePane"),
                "Free V1 must retain only the bounded legacy parser and byte-safe compatibility helpers, never the notebook tab, launcher, or reference-pane UI.")
        #expect(workspace.contains("@State private var selectedNotebookTabID")
                && workspace.contains("normalizedFreeV1SelectedTabID")
                && workspace.contains("navigateActiveOutline(to item: TOCItem)")
                && !workspace.contains("EpdocNotebookTabStrip(")
                && !workspace.contains("EpdocNotebookLauncherPane")
                && !workspace.contains("EpdocNotebookReferencePane"),
                "Document mode must normalize any stale notebook selection to Body before mounting the single Markdown document surface.")
        #expect(!toc.contains("case notebookTab(tabID: String)")
                && !toc.contains("case embed(referenceID: String, type: String)")
                && !toc.contains("notebookNavigationItems(in markdown: String)"),
                "Legacy notebook metadata must not synthesize outline rows in Free V1.")
        #expect(!disclosure.contains("scanNotebookReferences")
                && !disclosure.contains("notebookSheetTab")
                && !disclosure.contains("notebookChatTab")
                && !disclosure.contains("notebookUnknownTab")
                && !disclosure.contains("chatTabContentAvailable:")
                && disclosure.contains("sanitizedDatasetReferenceSource")
                && disclosure.contains("notebookManifestFence")
                && disclosure.contains("EpdocNotebookReferenceParser.containsEmbed"),
                "Lens scanning must skip legacy manifest and reference bytes instead of restoring tab, transcript, or export disclosures.")
        #expect(tests.contains("frontmatter manifest edits replace only the notebook block")
                && tests.contains("legacy notebook metadata cannot restore shared TOC rows")
                && tests.contains("legacy notebook metadata cannot restore Lens disclosure or export surfaces")
                && tests.contains("free V1 document lens does not restore chat or sheet reference surfaces")
                && tests.contains("manifest parsing is bounded")
                && tests.contains("dataset references expose artifact handles without inline row payloads"),
                "Free V1 needs focused source proof for byte-safe parsing, bounded compatibility, and the absence of legacy notebook presentation routes.")
        #expect(roundtrip.contains("notebookManifest440")
                && roundtrip.contains("epistemos-notebook")
                && roundtrip.contains("epistemos-ref")
                && roundtrip.contains("datasetEmbedsContainNoRowData")
                && roundtrip.contains("dataset embeds must reference dataset artifacts, not inline row data"),
                "The #440 markdown fixture must cover notebook manifests, embedded references, and row-data rejection.")
    }

    nonisolated private static func loadSourceText(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }

    nonisolated private static func sourceCount(in source: String, needle: String) -> Int {
        source.components(separatedBy: needle).count - 1
    }
}
