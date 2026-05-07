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
        #expect(appSource.contains("createUntitledEpdocDocument(in: vaultSync.vaultURL)"),
                "File > New Document should save into the active vault just like the sidebar and landing shortcuts.")
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

    @Test("Notes sidebar exposes New Document and saved epdocs in the creation/action surface")
    func notesSidebarExposesNewDocumentAction() throws {
        let source = try Self.loadSourceText("Epistemos/Views/Notes/NotesSidebar.swift")

        #expect(source.contains("let onNewDocument: () -> Void"),
                "EditorActionsBar needs a dedicated .epdoc creation callback, not a note-only surface.")
        #expect(source.contains("SidebarIconButton(icon: \"doc.badge.plus\", tooltip: \"New Document (.epdoc)\")"),
                "Notes sidebar bottom bar must visibly expose .epdoc creation.")
        #expect(source.contains("NSDocumentController.shared.createUntitledEpdocDocument(in: vaultSync.vaultURL)"),
                "Notes sidebar should create .epdoc files directly in the active vault when one is selected.")
        #expect(source.contains("cachedDocumentItems"),
                "Saved .epdoc packages must be visible from the sidebar, not only creatable.")
        #expect(source.contains("DocumentsSection("),
                "Sidebar needs a first-class Documents section for saved .epdoc packages.")
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
        #expect(source.contains(".fullSizeContentView"),
                "Epdoc window MUST extend its content view into the titlebar area via .fullSizeContentView styleMask.")
        #expect(source.contains("window.tabbingMode = .preferred"),
                "Epdoc windows should join native macOS tabbing, matching prose note windows.")
        #expect(source.contains("window.tabbingIdentifier = \"epistemos-note-tabs\""),
                "Epdoc windows should share the prose note tab group instead of opening as a separate app-like surface.")
        #expect(source.contains("attachToExistingNoteTabGroup(window)"),
                "New Epdoc windows should attach to the current note/doc tab group when one exists.")
        #expect(source.contains("ensureEpdocToolbarFits(in: existingWindow)"),
                "When Epdoc attaches to an existing note tab group, the window must expand enough that the native formatting toolbar does not collapse into overflow.")
        #expect(source.contains("window.minSize = NSSize(width: 1180, height: 620)"),
                "The Epdoc document window needs a minimum width that can actually fit the formatting toolbar plus status/save controls.")
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
        let css = try Self.loadSourceText("js-editor/src/editor.css")

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
        let mermaid = try Self.loadSourceText("js-editor/src/extensions/mermaid-node.ts")
        let chart = try Self.loadSourceText("js-editor/src/extensions/chart-node.ts")
        let documentGraph = try Self.loadSourceText("js-editor/src/graph/document-graph.ts")
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
                && markdownPaste.contains("type: 'mermaid'")
                && markdownPaste.contains("type: 'epdocChart'")
                && markdownPaste.contains("type: 'epdocImage'")
                && markdownPaste.contains("type: 'table'")
                && markdownPaste.contains("type: 'taskList'")
                && markdownPaste.contains("type: 'inlineMath'")
                && markdownPaste.contains("type: 'highlight'")
                && markdownPaste.contains("epistemos-doc:wiki/"),
                "Epdoc must convert pasted markdown syntax (# headings, fenced code, Mermaid, charts, images, tables, tasks, inline marks, math, and wikilinks) into real Tiptap nodes immediately instead of waiting for a backspace/retype input rule.")
        #expect(index.contains("epdocMarkdownInputRules()")
                && markdownInputRules.contains("new InputRule")
                && markdownInputRules.contains("parseMarkdownPaste(match[1])")
                && markdownInputRules.contains("node.type === 'table'")
                && markdownInputRules.contains("replaceInputWithBlockAndTrailingParagraph(state, range, tableNode)"),
                "Epdoc must turn typed Markdown table rows into real Tiptap tables when the divider row is completed.")
        #expect(imageNode.contains("addInputRules()")
                && imageNode.contains("parseMarkdownImageLine(match[0])")
                && imageNode.contains("epdocImage")
                && imageNode.contains("replaceInputWithBlockAndTrailingParagraph(state, range, imageNode)")
                && blockInsert.contains("Math.min(range.from + blockNode.nodeSize + 1, tr.doc.content.size)"),
                "Epdoc must turn typed Markdown image syntax and pasted image URLs into real image nodes, not text placeholders.")
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
        #expect(package.contains(#""@tiptap/extension-code-block-lowlight": "3.22.4""#) && package.contains(#""lowlight": "3.3.0""#),
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
        #expect(slash.contains("type: 'mermaid'"),
                "The visible Mermaid toolbar button must insert the custom Mermaid node, not a missing command name.")
        #expect(toolbar.contains(#"name: "insertEpdocGraphFromDocument""#),
                "The toolbar flowchart button must derive a graph from the current document, not insert the static Idea/Evidence sample.")
        #expect(toolbar.contains("tip: \"Insert document diagram\"") && !toolbar.contains("tip: \"Graph from document\"") && !toolbar.contains("tip: \"Mermaid diagram\""),
                "The toolbar affordance should say what it does now: insert an in-document research diagram, not open the global Knowledge Graph or advertise the old static Mermaid sample.")
        #expect(toolbar.contains("Label(tip, systemImage: symbol)") && toolbar.contains(".accessibilityLabel(Text(tip))"),
                "Icon-only toolbar buttons must carry the semantic action label for accessibility and Computer Use smoke tests.")
        #expect(inbound.contains("buildMermaidGraphFromDocument(editor.getJSON())"),
                "Document graph insertion must read the live ProseMirror tree so long pasted docs create structure-specific Mermaid graphs.")
        #expect(slash.contains("buildMermaidGraphFromDocument(e.getJSON())") && !slash.contains("A[Idea] --> B[Evidence]"),
                "Slash-menu graph insertion must use the same live document graph builder and must never resurrect the static Idea/Evidence sample.")
        #expect(documentGraph.contains("collectGraphEntries") && documentGraph.contains("isGraphContentNode"),
                "The document graph builder must extract real structure from headings, paragraphs, list items, blockquotes, and tables.")
        #expect(documentGraph.contains("classifyText") && documentGraph.contains("appendClassDefs"),
                "Document graphs should render as research diagrams with typed claim/evidence/question/method classes, not generic text-only boxes.")
        let methodClassifierRange = try #require(documentGraph.range(of: #"\b(method|protocol|procedure|experiment|approach|pipeline)\b"#))
        let evidenceClassifierRange = try #require(documentGraph.range(of: #"\b(evidence|source|citation|dataset|observed|measured|study|paper|result)\b"#))
        #expect(methodClassifierRange.lowerBound < evidenceClassifierRange.lowerBound,
                "Document graph classification must prefer explicit Method/Protocol/Procedure language over incidental evidence terms like source guards.")
        #expect(documentGraph.contains("wikilinkLabels") && documentGraph.contains(#"visit({ label, kind: 'link' })"#),
                "The document graph builder must include wikilinks as graph entries so pasted/relinked docs surface more than prose snippets.")
        #expect(!documentGraph.contains("'Document', 'Key Point', 'Evidence'") && !documentGraph.contains("A[Idea] --> B[Evidence]"),
                "No document-graph path may keep the old generic Idea/Evidence sample or fallback.")
        #expect(slash.contains("]).focus('end').run()"),
                "After inserting a Mermaid block, the toolbar must force the caret into the trailing paragraph so the document stays typable.")
        #expect(mermaid.contains("source.contentEditable = 'false'") && !mermaid.contains("contentDOM: source"),
                "Mermaid preview/source UI must not become ProseMirror's editable contentDOM; that traps focus and makes the note feel frozen.")
        #expect(mermaid.contains("researchThemeVariables") && mermaid.contains("securityLevel: 'strict'") && mermaid.contains("sanitizeMermaidSvg") && mermaid.contains("svgCache"),
                "Mermaid rendering must use research-grade theming, strict-mode rendering, SVG sanitization, and render caching rather than the default Mermaid palette.")
        #expect(mermaid.contains("epdoc-mermaid-header") && mermaid.contains("Research diagram") && mermaid.contains("Mermaid source"),
                "Mermaid nodes should present the diagram first with a research-diagram chrome and keep source available on demand.")
        #expect(css.contains(".epdoc-mermaid-header") && css.contains(".epdoc-mermaid-preview svg") && css.contains(".epdoc-mermaid-source-wrap"),
                "Epdoc diagrams need polished research-card styling, not a plain bordered source+preview box.")
        #expect(slash.contains("RESEARCH_DIAGRAM_TEMPLATES")
                && slash.contains("mermaid-flowchart")
                && slash.contains("mermaid-sequence")
                && slash.contains("mermaid-mindmap")
                && slash.contains("mermaid-quadrant")
                && slash.contains("mermaid-sankey")
                && slash.contains("mermaid-pie")
                && slash.contains("mermaid-gantt")
                && slash.contains("mermaid-journey")
                && slash.contains("mermaid-requirement")
                && slash.contains("mermaid-gitgraph")
                && slash.contains("mermaid-c4")
                && slash.contains("mermaid-block"),
                "The slash menu must expose a broad research-diagram palette, not just one document graph action.")
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
        #expect(Self.sourceCount(in: slash, needle: "apply: (e)") == 36,
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
