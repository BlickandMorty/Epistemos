import Combine
import AppKit
import OSLog
import QuartzCore
import SwiftUI
@preconcurrency import WebKit

// MARK: - EpdocEditorChromeView
//
// Wave 7.17 stitch-up — the top-level SwiftUI shell that hosts the
// W7.17.a SwiftUI toolbar, the Tiptap WKWebView document area, and
// the 10 W7.17.b floating panels (slash menu, bubble menu, KaTeX
// preview, complexity meter, thought-attached badge, insert link
// picker, block context menu, gutter menu — all wired through the
// EpdocBridgeMessage stream).
//
// The view is composable: `EpdocEditorChromeView(controller:)` takes
// a controller that owns the canonical document state + the
// dispatch closures the panels fire commands through. Tests +
// Previews can construct a controller against an in-memory document
// without spinning up a WKWebView host.
//
// Per the W7.17.a hybrid render decision: SwiftUI for the chrome,
// Tiptap WKWebView for the caret-glued tools. This file owns the
// SwiftUI layout; the inner `EpdocTiptapWebView` (NSViewRepresentable)
// adapts to the WKWebView.

// MARK: - Shared WebKit lifecycle state
//
// `WKProcessPool` is deprecated on current macOS SDKs because multiple
// process pools no longer have an effect. The useful shared state here
// is therefore just the live WebView count: memory-pressure handling
// can report whether document WebViews are currently open, while each
// WebView keeps using a non-persistent data store and explicit teardown.
@MainActor
enum EpdocWebViewShared {
    private static var liveWebViewCount: Int = 0

    static var isIdleForMemoryPressure: Bool {
        liveWebViewCount == 0
    }

    static func notifyWebViewCreated() {
        liveWebViewCount += 1
    }

    static func notifyWebViewDismantled() {
        liveWebViewCount = max(0, liveWebViewCount - 1)
    }
}

@MainActor
private final class EpdocEditorWebView: WKWebView {
    override func menu(for event: NSEvent) -> NSMenu? {
        guard let menu = super.menu(for: event) else { return nil }
        EpdocContextMenuSanitizer.removeUnsafeBrowserCommands(from: menu)
        return menu.items.isEmpty ? nil : menu
    }
}

@MainActor
private enum EpdocContextMenuSanitizer {
    static func removeUnsafeBrowserCommands(from menu: NSMenu) {
        for item in menu.items {
            if let submenu = item.submenu {
                removeUnsafeBrowserCommands(from: submenu)
            }
        }
        for item in menu.items.reversed() where isUnsafeBrowserCommand(item) {
            menu.removeItem(item)
        }
    }

    private static func isUnsafeBrowserCommand(_ item: NSMenuItem) -> Bool {
        if item.isSeparatorItem { return false }
        let title = item.title.lowercased()
        let action = item.action.map { NSStringFromSelector($0).lowercased() } ?? ""
        return title.contains("reload")
            || title.contains("back")
            || title.contains("forward")
            || action.contains("reload")
            || action.contains("goback")
            || action.contains("goforward")
    }
}

// MARK: - Controller (Observable view-state)

/// The view-state + command-dispatch surface the chrome view binds
/// to. Exposes the live word/char counts, complexity scalar, and
/// the floating-panel show/hide state.
@MainActor
@Observable
public final class EpdocEditorChromeController {

    // MARK: - Live document state
    public var documentTitle: String = "Untitled"
    public var attachedRunIDs: [String] = []          // W7.15 surfacing
    public var complexity: Double = 0.0                // W7.12 surfacing
    public var complexityBreakdown: DocComplexityBreakdown?

    // MARK: - Toolbar model (W7.17.a)
    public var toolbarModel: EpdocEditorToolbarModel
    var theme: EpistemosTheme = .nativeDefault

    // MARK: - Floating panel state
    public var slashMenuQuery: String? = nil           // non-nil → panel visible
    public var slashMenuAnchor: EpdocBridgeRect? = nil
    public var bubbleMenuSelection: EpdocBridgeSelection? = nil
    public var bubbleMenuAnchor: EpdocBridgeRect? = nil
    public var bubbleMenuSelectedText: String = ""
    public var katexPreviewFormula: String? = nil
    public var katexDisplayMode: EpdocKaTeXPreview.DisplayMode = .display
    public var katexPreviewAnchor: EpdocBridgeRect? = nil
    private var initialContentJSON: Data?
    private var editorIsReady = false
    private var bridgeDispatchInstalled = false
    private var didPushInitialContent = false

    // MARK: - Dispatch + persistence wiring
    /// Fire a Swift → JS command. The chrome installs this on every
    /// floating panel; the host wires it to evaluateJavaScript on the
    /// active WKWebView.
    public var dispatch: @Sendable @MainActor (EpdocEditorCommand) -> Void
    /// Save trigger - host runs the NSDocument save coordinator.
    /// Fires when the user explicitly hits the toolbar Save button
    /// (vs `onContentChanged` below which fires on every keystroke).
    public var onSave: @Sendable @MainActor () -> Void
    /// Audit gap F4 (T+4_T+5_DEEP_AUDIT) close-out - every Tiptap
    /// `contentDidChange` bridge message lands here with the freshly
    /// emitted ProseMirror JSON. Hosts can:
    ///   - hand the bytes to `EpdocEditorSavePipeline` for debounced
    ///     persistence (`attachAutosavePipeline(save:)` does this for
    ///     you), and/or
    ///   - hand them to `ReadableBlocksIndex` for FTS reindex, and/or
    ///   - mutate `EpdocDocument.package.contentJSON` so the next
    ///     NSDocument autosave picks them up.
    /// Default is a no-op so unit tests + previews don't have to care.
    public var onContentChanged: @Sendable @MainActor (Data) -> Void
    /// Open the agent inspector with the selected text.
    public var onAskAgent: @Sendable @MainActor (String) -> Void
    /// Capture as RawThought (Wave 3.1).
    public var onCaptureAsRawThought: @Sendable @MainActor (String) -> Void
    /// Halo backend search closure for the Insert link picker (W8.4).
    public var onSearchLinks: @Sendable @MainActor (String) async -> [EpdocLinkSuggestion]
    /// Open the agent inspector for a specific RawThought run id.
    public var onPickRun: @Sendable @MainActor (String) -> Void
    /// Resolve package-local assets for the `epistemos-doc:///assets/...`
    /// URL-scheme path. The owning `EpdocDocument` installs this so the
    /// WebView can render media stored in the `.epdoc` package.
    public var onResolveDocumentAsset: @MainActor (String) -> EpdocEditorDocumentAsset?
    /// Store a pasted/dropped image in the owning `.epdoc` package and
    /// return the image node src. Previews keep a data-URL fallback.
    public var onStoreDocumentAsset: @MainActor (String, String, Data) -> String?

    /// Internal autosave debouncer. Created lazily by
    /// `attachAutosavePipeline(save:)`; otherwise nil and the
    /// controller is purely event-fanout (host owns persistence).
    private var autosavePipeline: EpdocEditorSavePipeline?

    public init() {
        self.toolbarModel = EpdocEditorToolbarModel()
        self.dispatch = { _ in }
        self.onSave = { }
        self.onContentChanged = { _ in }
        self.onAskAgent = { _ in }
        self.onCaptureAsRawThought = { _ in }
        self.onSearchLinks = { _ in [] }
        self.onPickRun = { _ in }
        self.onResolveDocumentAsset = { _ in nil }
        self.onStoreDocumentAsset = { filename, mimeType, data in
            "data:\(mimeType);base64,\(data.base64EncodedString())"
        }
        // Wire the toolbar model's dispatch through to the chrome's
        // dispatch so toolbar buttons trigger the same path floating
        // panels do.
        self.toolbarModel.dispatch = { [weak self] cmd in
            self?.dispatch(cmd)
        }
    }

    public func loadInitialContent(_ json: Data, title: String) {
        initialContentJSON = json
        documentTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled"
            : title
        refreshDerivedStatus(from: json)
        didPushInitialContent = false
        flushInitialContentIfPossible()
    }

    public func installEditorDispatch(
        _ dispatch: @escaping @Sendable @MainActor (EpdocEditorCommand) -> Void
    ) {
        self.dispatch = dispatch
        bridgeDispatchInstalled = true
        flushInitialContentIfPossible()
    }

    public func detachEditorDispatch() {
        bridgeDispatchInstalled = false
        dispatch = { _ in }
    }

    private func flushInitialContentIfPossible() {
        guard editorIsReady,
              bridgeDispatchInstalled,
              !didPushInitialContent,
              let initialContentJSON else {
            return
        }
        didPushInitialContent = true
        dispatch(.setContent(json: initialContentJSON))
        dispatch(.focusStart)
        scheduleInitialStatusRefresh(for: initialContentJSON)
    }

    private func scheduleInitialStatusRefresh(for json: Data) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self,
                  !self.toolbarModel.isDirty,
                  self.initialContentJSON == json else {
                return
            }
            self.refreshDerivedStatus(from: json)
        }
    }

    /// Audit gap F5 close-out - opt-in autosave wiring. Constructs an
    /// `EpdocEditorSavePipeline` with the host's save closure and
    /// installs an `onContentChanged` handler that funnels every
    /// keystroke's JSON through the debouncer. Idempotent: a second
    /// call replaces the pipeline (use `detachAutosavePipeline` to
    /// fully remove).
    ///
    /// `save` runs after the pipeline's 300 ms quiet window. The host
    /// is responsible for the actual write - typically copying the
    /// bytes onto `EpdocDocument.package.contentJSON` and calling
    /// `NSDocument.autosave(...)` so iCloud/Versions tracks the
    /// revision.
    public func attachAutosavePipeline(
        debounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(300),
        save: @escaping @Sendable @MainActor (Data) -> Void
    ) {
        let pipeline = EpdocEditorSavePipeline(debounce: debounce, save: save)
        self.autosavePipeline = pipeline
        self.onContentChanged = { [weak pipeline] json in
            pipeline?.enqueue(json: json)
        }
    }

    /// Tear down the autosave pipeline; reverts `onContentChanged` to
    /// the no-op default. Hosts call this before releasing the
    /// controller so the Combine subscription's retained closure
    /// chain doesn't outlive the document.
    public func detachAutosavePipeline() {
        self.autosavePipeline = nil
        self.onContentChanged = { _ in }
    }

    // MARK: - Bridge message intake

    /// Consume a bridge message from the WKWebView. The chrome
    /// updates its view-state (toolbar counts, panel visibility,
    /// complexity meter) accordingly.
    public func handleBridgeMessage(_ message: EpdocBridgeMessage) {
        switch message {
        case .editorReady:
            editorIsReady = true
            flushInitialContentIfPossible()
        case let .contentDidChange(json):
            // Audit gap F4 close-out (T+4_T+5_DEEP_AUDIT_2026-04-27.md).
            // Every Tiptap onUpdate emits the fresh ProseMirror JSON
            // through this path. Forward to the host's content-changed
            // sink so save + FTS update + projection regeneration can
            // happen. Counts (separately emitted via the JS-side
            // CharacterCount extension) still flow through their own
            // bridge case.
            onContentChanged(json)
            toolbarModel.isDirty = true
            refreshDerivedStatus(from: json)
        case let .documentStatsChanged(wordCount, characterCount):
            toolbarModel.wordCount = wordCount
            toolbarModel.characterCount = characterCount
        case .error:
            break  // host logs; chrome just keeps rendering
        case let .caretChanged(_, selection):
            // Update mark-active state via a side channel (the JS
            // side currently doesn't emit per-mark activity per
            // caret; W7.17.b runtime adds that). For now we only
            // toggle the toolbar's "selection collapsed" state.
            if selection.isEmpty {
                bubbleMenuSelection = nil
                bubbleMenuAnchor = nil
            }
        case let .requestSlashMenu(query, anchor):
            // Empty query + zero anchor = "dismiss" sentinel from
            // the JS side (see js-editor/src/extensions/slash-menu.ts).
            if query.isEmpty && anchor.x == 0 && anchor.y == 0 {
                slashMenuQuery = nil
                slashMenuAnchor = nil
            } else {
                slashMenuQuery = query
                slashMenuAnchor = anchor
            }
        case let .requestBubbleMenu(selection, anchor):
            bubbleMenuSelection = selection
            bubbleMenuAnchor = anchor
        case let .storeImageAsset(requestID, filename, mimeType, data):
            guard let src = onStoreDocumentAsset(filename, mimeType, data),
                  let argsJSON = Self.imageAssetCompletionArgsJSON(requestID: requestID, src: src) else {
                return
            }
            dispatch(.runCommand(name: "completeImageAssetRequest", argsJSON: argsJSON))
        }
    }

    private static func imageAssetCompletionArgsJSON(requestID: String, src: String) -> Data? {
        let payload: [[String: String]] = [
            ["requestID": requestID, "src": src],
        ]
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    private func refreshDerivedStatus(from json: Data) {
        guard let doc = try? JSONDecoder().decode(ProseMirrorNode.self, from: json) else {
            return
        }
        let nextBreakdown = EpdocComplexityCalculator.breakdown(for: doc)
        complexity = nextBreakdown.complexity
        complexityBreakdown = nextBreakdown
        toolbarModel.wordCount = nextBreakdown.wordCount
        toolbarModel.characterCount = Self.characterCount(in: doc)
    }

    private static func characterCount(in node: ProseMirrorNode) -> Int {
        let childCount = node.content?.reduce(0) { partial, child in
            partial + characterCount(in: child)
        } ?? 0
        return (node.text?.count ?? 0) + childCount
    }

    // MARK: - Floating-panel dismissals

    public func dismissSlashMenu() {
        slashMenuQuery = nil
        slashMenuAnchor = nil
        dispatch(.dismissSlashMenu)
    }

    public func dismissBubbleMenu() {
        bubbleMenuSelection = nil
        bubbleMenuAnchor = nil
        dispatch(.dismissBubbleMenu)
    }

    public func pickSlashChoice(_ item: EpdocSlashMenuItem) {
        dispatch(.insertSlashChoice(blockType: item.id))
        dismissSlashMenu()
    }

    public func resolveDocumentAsset(named name: String) -> EpdocEditorDocumentAsset? {
        onResolveDocumentAsset(name)
    }
}

// MARK: - Chrome view

@MainActor
public struct EpdocEditorChromeView: View {

    @Bindable public var controller: EpdocEditorChromeController
    @Environment(UIState.self) private var ui: UIState?

    private var theme: EpistemosTheme {
        ui?.theme ?? controller.theme
    }

    public init(controller: EpdocEditorChromeController) {
        self.controller = controller
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            EpdocTiptapWebView(controller: controller, theme: theme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Slash menu (W7.17.b)
            if let query = controller.slashMenuQuery,
               let anchor = controller.slashMenuAnchor {
                EpdocSlashMenuView(
                    query: query,
                    onPick: { controller.pickSlashChoice($0) },
                    onDismiss: { controller.dismissSlashMenu() }
                )
                .position(x: anchor.x + 140, y: anchor.y + 200)
                .transition(.opacity)
            }

            // Bubble menu (W7.17.b)
            if let selection = controller.bubbleMenuSelection,
               let anchor = controller.bubbleMenuAnchor,
               !selection.isEmpty {
                EpdocBubbleMenuView(
                    selectedText: controller.bubbleMenuSelectedText,
                    onCommand: controller.dispatch,
                    onAskAgent: controller.onAskAgent,
                    onCaptureAsRawThought: controller.onCaptureAsRawThought
                )
                .position(x: anchor.x, y: max(0, anchor.y - 30))
                .transition(.opacity)
            }

            // KaTeX live preview popover (W7.17.b)
            if let formula = controller.katexPreviewFormula,
               let anchor = controller.katexPreviewAnchor {
                EpdocKaTeXPreview(
                    formula: formula,
                    displayMode: controller.katexDisplayMode
                )
                .position(x: anchor.x + 180, y: max(0, anchor.y - 80))
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottomLeading) {
            epdocFooter
                .padding(.leading, 24)
                .padding(.bottom, 18)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomTrailing) {
            EpdocCopilotDockView(
                wordCount: controller.toolbarModel.wordCount,
                complexity: controller.complexity,
                dispatch: controller.dispatch,
                onAskAgent: controller.onAskAgent
            )
            .padding(.trailing, 24)
            .padding(.bottom, 18)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                EpdocEditorToolbar(model: controller.toolbarModel, onSave: controller.onSave)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                EpdocComplexityMeter(
                    complexity: controller.complexity,
                    breakdown: controller.complexityBreakdown,
                    label: controller.documentTitle
                )
                if !controller.attachedRunIDs.isEmpty {
                    EpdocThoughtAttachedBadge(
                        attachedRunIDs: controller.attachedRunIDs,
                        onPickRun: controller.onPickRun
                    )
                }
                epdocSaveButton
            }
        }
        .background {
            Button("") {
                controller.onSave()
            }
            .keyboardShortcut("s", modifiers: .command)
            .hidden()
        }
        .background {
            NoteWorkspaceSurfaceStyle.canvasBackground(for: theme).ignoresSafeArea()
        }
    }

    private var epdocFooter: some View {
        HStack(spacing: 8) {
            Text("\(controller.toolbarModel.wordCount) words")
                .monospacedDigit()
            Text("\(controller.toolbarModel.characterCount) chars")
                .monospacedDigit()
            if !controller.attachedRunIDs.isEmpty {
                Label("\(controller.attachedRunIDs.count) thoughts", systemImage: "bolt.fill")
            }
        }
        .font(.system(size: 13, weight: .regular))
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .help("Document status")
    }

    private var epdocSaveButton: some View {
        Button {
            controller.onSave()
            controller.toolbarModel.isDirty = false
        } label: {
            if controller.toolbarModel.isSaving {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 14, height: 14)
            } else {
                Label("Save", systemImage: "tray.and.arrow.down")
            }
        }
        .keyboardShortcut("s", modifiers: .command)
        .help(controller.toolbarModel.isDirty ? "Save (Command-S)" : "All changes saved")
        .disabled(controller.toolbarModel.isSaving)
    }
}

@MainActor
private enum EpdocEditorThemeStyle {
    static func appearance(for theme: EpistemosTheme) -> NSAppearance? {
        NSAppearance(named: theme.isDark ? .darkAqua : .aqua)
    }

    static func applyScript(for theme: EpistemosTheme) -> String {
        let assignments = cssVariables(for: theme)
            .map { name, value in
                "root.style.setProperty(\(jsStringLiteral(name)), \(jsStringLiteral(value)));"
            }
            .joined()
        return """
        (function(){
          const root = document.documentElement;
          if (!root) return;
          root.dataset.epdocTheme = \(jsStringLiteral(theme.rawValue));
          root.dataset.epdocThemeDark = \(theme.isDark ? "true" : "false");
          \(assignments)
        })();
        """
    }

    private static func cssVariables(for theme: EpistemosTheme) -> [(String, String)] {
        let resolved = theme.resolved
        var variables: [(String, String)] = [
            ("--epdoc-bg", "transparent"),
            ("--epdoc-display-font", theme.epdocDisplayFontFamily),
            ("--epdoc-text-color", cssColor(resolved.foreground.nsColor)),
            ("--epdoc-muted", cssColor(resolved.mutedForeground.nsColor)),
            ("--epdoc-accent", cssColor(resolved.accent.nsColor)),
            ("--epdoc-code-bg", cssColor(resolved.card.nsColor)),
            ("--epdoc-code-border", cssColor(resolved.border.nsColor)),
            ("--epdoc-code-fg", cssColor(resolved.foreground.nsColor)),
            ("--epdoc-card-bg", cssColor(resolved.card.nsColor)),
            ("--epdoc-card-border", cssColor(resolved.border.nsColor)),
            ("--epdoc-card-label-fg", cssColor(resolved.foreground.nsColor)),
            ("--epdoc-syntax-title", cssColor(resolved.headingAccent.nsColor)),
            ("--epdoc-syntax-keyword", cssColor(resolved.codeType.nsColor)),
            ("--epdoc-syntax-built-in", cssColor(resolved.accent.nsColor)),
            ("--epdoc-chart-blue", cssColor(resolved.accent.nsColor)),
            ("--epdoc-chart-violet", cssColor(resolved.headingAccent.nsColor)),
        ]
        // Per-theme H1-H3 size shrink (2026-05-19): Classic + Platinum
        // render visibly larger than Ember at the same point size, so
        // override the editor.css defaults (59 / 31 / 19 px) with the
        // 0.85× values. Ember keeps the defaults — its sizes are the
        // canonical target.
        let multiplier = theme.headingSizeMultiplier
        if multiplier < 1.0 {
            let h1 = Int((59 * multiplier).rounded())
            let h2 = Int((31 * multiplier).rounded())
            let h3 = Int((19 * multiplier).rounded())
            variables.append(("--epdoc-h1-size", "\(h1)px"))
            variables.append(("--epdoc-h2-size", "\(h2)px"))
            variables.append(("--epdoc-h3-size", "\(h3)px"))
        }
        return variables
    }

    private static func cssColor(_ color: NSColor) -> String {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        let red = min(max(Int((rgb.redComponent * 255).rounded()), 0), 255)
        let green = min(max(Int((rgb.greenComponent * 255).rounded()), 0), 255)
        let blue = min(max(Int((rgb.blueComponent * 255).rounded()), 0), 255)
        let alpha = rgb.alphaComponent
        if alpha >= 0.999 {
            return String(format: "#%02X%02X%02X", red, green, blue)
        }
        return String(format: "rgba(%d, %d, %d, %.3f)", red, green, blue, alpha)
    }
}

// MARK: - Tiptap WKWebView wrapper

@MainActor
private struct EpdocTiptapWebView: NSViewRepresentable {

    let controller: EpdocEditorChromeController
    let theme: EpistemosTheme

    func makeNSView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "epdoc")
        userContentController.addUserScript(
            WKUserScript(
                source: EpdocEditorThemeStyle.applyScript(for: theme),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )

        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        // Editor content is markdown round-tripped through Tiptap —
        // there's no IndexedDB, no LocalStorage, no Service Worker the
        // editor reads. The default *persistent* `WKWebsiteDataStore`
        // brings ~30–50 MB of disk-cache + service-worker scaffolding
        // per WKWebView for nothing. Switching to a non-persistent
        // store keeps the runtime in-RAM only and frees with the view.
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        config.setURLSchemeHandler(
            EpdocEditorURLSchemeHandler(documentAssetResolver: { [weak controller] name in
                controller?.resolveDocumentAsset(named: name)
            }),
            forURLScheme: epdocEditorURLScheme
        )

        let view = EpdocEditorWebView(frame: .zero, configuration: config)
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = false
        view.appearance = EpdocEditorThemeStyle.appearance(for: theme)
        view.setValue(false, forKey: "drawsBackground")
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        if let url = URL(string: "\(epdocEditorURLScheme):///editor.html") {
            view.load(URLRequest(url: url))
        }
        EpdocWebViewShared.notifyWebViewCreated()
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        // The chrome controller's `dispatch` closure is the canonical
        // command surface; we install a closure here that routes
        // commands into evaluateJavaScript so panel buttons reach the
        // editor.
        context.coordinator.webView = view
        context.coordinator.installDispatch(into: controller)
        context.coordinator.controller = controller
        context.coordinator.applyTheme(theme, to: view)
    }

    /// Released when SwiftUI tears down the representable (document
    /// closed, tab destroyed, parent view removed). Without this,
    /// the WKWebView keeps:
    ///
    /// - The `WKScriptMessageHandler` retained by
    ///   `WKUserContentController` (a strong cycle)
    /// - The autosave pipeline closure chain (debounced timer +
    ///   Combine subscriptions)
    /// - The Tiptap JS heap (~50-80 MB)
    ///
    /// Each of those leaks ~40-60 MB. Calling `stopLoading` + removing
    /// every named script-message handler + detaching the autosave
    /// pipeline lets ARC reclaim the lot.
    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.uiDelegate = nil
        let userContent = view.configuration.userContentController
        userContent.removeScriptMessageHandler(forName: "epdoc")
        userContent.removeAllUserScripts()
        coordinator.shutdown()
        EpdocWebViewShared.notifyWebViewDismantled()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, WKUIDelegate {
        weak var webView: WKWebView?
        weak var controller: EpdocEditorChromeController?
        private var lastAppliedTheme: EpistemosTheme?

        // AP1 — outbound coalescing (Wave 13 §"Phase 4 perf — AP1
        // WKWebView bridge batching"). Every `evaluate(_:)` call
        // round-trips into the WKWebView's JS engine; on a paste burst
        // (panel button + slash dismiss + bubble dismiss + setContent)
        // the per-paste cost was 100-150 ms. Coalescing 3-5 commands
        // into ONE evaluateJavaScript wrapped in an IIFE drops it to
        // ~30-40 ms. We flush on the next display-link tick (~16 ms)
        // so the user-visible state still updates within one frame.
        //
        // macOS 14+ uses `NSView.displayLink(target:selector:)`, which
        // returns a `CADisplayLink`. We mirror the LandingWaveMetalView
        // pattern (Epistemos/Views/Landing/Wave/LandingWaveMetalView.swift)
        // for the lifecycle. On older macOS the queue still flushes —
        // we fall back to `DispatchQueue.main.async` so behaviour is
        // identical, just without the display-aligned cadence.
        private var outboundQueue: [EpdocEditorCommand] = []
        private var outboundDisplayLink: CADisplayLink?
        private var outboundFlushScheduled: Bool = false

        private static let log = Logger(
            subsystem: "com.epistemos",
            category: "EpdocBridge"
        )

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping @MainActor @Sendable (String?) -> Void
        ) {
            let alert = NSAlert()
            alert.messageText = prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Epdoc input"
                : prompt
            alert.informativeText = "This value will be inserted into the current document."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Insert")
            alert.addButton(withTitle: "Cancel")

            let input = NSTextField(string: defaultText ?? "")
            input.frame = NSRect(x: 0, y: 0, width: 360, height: 24)
            alert.accessoryView = input

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                completionHandler(input.stringValue)
            } else {
                completionHandler(nil)
            }
        }

        func installDispatch(into controller: EpdocEditorChromeController) {
            self.controller = controller
            controller.installEditorDispatch { [weak self] cmd in
                self?.enqueueOutbound(cmd)
            }
        }

        func applyTheme(_ theme: EpistemosTheme, to webView: WKWebView) {
            guard lastAppliedTheme != theme else { return }
            lastAppliedTheme = theme
            webView.appearance = EpdocEditorThemeStyle.appearance(for: theme)
            webView.evaluateJavaScript(
                EpdocEditorThemeStyle.applyScript(for: theme),
                completionHandler: nil
            )
        }

        /// Tear-down counterpart called from `dismantleNSView` when the
        /// representable is removed from the SwiftUI hierarchy. Drops:
        ///
        /// - the controller's `dispatch` closure (releases the strong
        ///   ref this Coordinator otherwise pins via `installDispatch`)
        /// - the autosave pipeline (debounce timer + Combine chain)
        /// - the AP1 outbound display link (CADisplayLink retains its
        ///   target; without invalidating, the link stays alive past
        ///   coordinator dealloc)
        /// - any pending outbound commands so they don't fire against
        ///   a now-detached web view
        func shutdown() {
            // Cancel the AP1 display-aligned flush.
            outboundDisplayLink?.invalidate()
            outboundDisplayLink = nil
            outboundFlushScheduled = false
            outboundQueue.removeAll(keepingCapacity: false)
            // Detach the autosave pipeline + replace the dispatch
            // closure with a no-op so any panel that still holds a
            // reference to `controller.dispatch` after dismantle
            // doesn't crash trying to reach the freed coordinator.
            controller?.detachAutosavePipeline()
            controller?.detachEditorDispatch()
            controller = nil
            webView = nil
        }

        nonisolated func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            // WebKit delivers WKScriptMessage callbacks on the main thread.
            // assumeIsolated propagates that contract to Swift 6 so we can
            // read message.body (now @MainActor in the macOS 26 SDK) without
            // an async Task hop - synchronous, no retain cycle.
            MainActor.assumeIsolated {
                handleInbound(body: message.body)
            }
        }

        // MARK: - Inbound (AP1 batch decode + AR5 classifyPaste)

        /// Decode a single inbound payload, transparently unpacking the
        /// `{ type: 'batch', messages: [...] }` envelope the JS-side
        /// outbound batcher (`js-editor/src/bridge/outbound.ts`) emits
        /// once per animation frame, and intercepting the `classifyPaste`
        /// message (AR5) before falling through to EpdocBridgeMessage.
        private func handleInbound(body: Any) {
            // AP1 — batch envelope.
            if let dict = body as? [String: Any],
               (dict["type"] as? String) == "batch",
               let messages = dict["messages"] as? [Any] {
                for entry in messages {
                    handleInbound(body: entry)
                }
                return
            }
            // AR5 — IntakeValve paste classification (out-of-band; the
            // Tiptap side already inserted the paste into the editor).
            if let dict = body as? [String: Any],
               (dict["type"] as? String) == "classifyPaste",
               let text = dict["text"] as? String {
                routeClassifyPaste(text: text)
                return
            }
            // Standard EpdocBridgeMessage path.
            guard let bridgeMessage = EpdocBridgeMessage.decode(messageBody: body) else {
                return
            }
            self.controller?.handleBridgeMessage(bridgeMessage)
        }

        /// AR5 — fire-and-forget hand-off to the IntakeValve. The
        /// classifier runs on the MainActor (as IntakeValve is
        /// MainActor-isolated) and side-effects into QuarantineArchive
        /// when it routes to `.ambient`; we don't block the JS bridge
        /// on its result. Errors are logged but not surfaced — the
        /// paste still landed in the editor either way.
        private func routeClassifyPaste(text: String) {
            // The paste originated inside an .epdoc note; we don't yet
            // have a stable per-note id to use as the QuarantineAnchor
            // contextId, so we leave the anchor `nil` and let
            // QuarantineArchive store it un-anchored. When the chrome
            // controller carries a documentId in a later wave, plumb
            // it through here.
            Task { @MainActor in
                do {
                    _ = try await IntakeValve.shared.classifyAndRoute(
                        text,
                        anchor: nil
                    )
                } catch {
                    Self.log.debug(
                        "IntakeValve.classifyAndRoute skipped: \(String(describing: error), privacy: .public)"
                    )
                }
            }
        }

        // MARK: - Outbound (AP1 display-link batcher)

        /// Enqueue a Swift → JS command for the next display-link tick.
        /// The flush coalesces all queued commands into a single
        /// `evaluateJavaScript` call wrapping them in an IIFE so the
        /// WKWebView IPC fires once per tick instead of once per
        /// command.
        private func enqueueOutbound(_ command: EpdocEditorCommand) {
            outboundQueue.append(command)
            scheduleOutboundFlush()
        }

        private func scheduleOutboundFlush() {
            if outboundFlushScheduled { return }
            outboundFlushScheduled = true
            if #available(macOS 14.0, *), let view = webView, outboundDisplayLink == nil {
                let link = view.displayLink(
                    target: self,
                    selector: #selector(handleOutboundDisplayLinkTick(_:))
                )
                link.add(to: .main, forMode: .common)
                outboundDisplayLink = link
            } else {
                // Pre-macOS 14 fallback: hop to the next runloop tick.
                // The user-visible state still updates inside one
                // display refresh; we just don't get display-aligned
                // pacing.
                DispatchQueue.main.async { [weak self] in
                    self?.flushOutboundQueue()
                }
            }
        }

        @objc private func handleOutboundDisplayLinkTick(_ link: CADisplayLink) {
            flushOutboundQueue()
        }

        private func flushOutboundQueue() {
            outboundFlushScheduled = false
            // Tear down the display link until the next enqueue —
            // a quiescent editor shouldn't keep the runloop hot.
            if let link = outboundDisplayLink {
                link.invalidate()
                outboundDisplayLink = nil
            }
            guard let webView, !outboundQueue.isEmpty else {
                outboundQueue.removeAll(keepingCapacity: true)
                return
            }
            let batch = outboundQueue
            outboundQueue.removeAll(keepingCapacity: true)
            // Common case — only one command queued during the tick.
            // Skip the IIFE wrapping so the JS engine doesn't pay for
            // the extra parse.
            if batch.count == 1 {
                webView.evaluateJavaScript(batch[0].javaScriptExpression(), completionHandler: nil)
                return
            }
            // Wrap the batched expressions in a single IIFE so one
            // evaluateJavaScript IPC executes them all in order.
            // Each expression already returns a no-op value from the
            // window.epistemos.* surface; we discard the final value.
            var script = "(function(){"
            script.reserveCapacity(64 * batch.count)
            for cmd in batch {
                script.append(cmd.javaScriptExpression())
                script.append(";")
            }
            script.append("})();")
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        // No explicit deinit: `flushOutboundQueue()` invalidates the
        // display link after every flush, so a quiescent Coordinator
        // holds no link reference. While a flush is pending the link
        // strongly retains `self` (CADisplayLink target semantics),
        // which means deinit can't run until the next tick fires + we
        // tear the link down ourselves.
    }
}

#if DEBUG
#Preview("EpdocEditorChromeView — empty") {
    let controller = EpdocEditorChromeController()
    controller.documentTitle = "My Notes"
    controller.complexity = 0.25
    return EpdocEditorChromeView(controller: controller)
        .frame(width: 1100, height: 700)
}

#Preview("EpdocEditorChromeView — slash menu showing") {
    let controller = EpdocEditorChromeController()
    controller.documentTitle = "Quarterly Review"
    controller.complexity = 0.65
    controller.attachedRunIDs = ["run-01HMV5K2K9XJ4N0ABCDE"]
    controller.slashMenuQuery = "head"
    controller.slashMenuAnchor = EpdocBridgeRect(x: 200, y: 250, width: 1, height: 18)
    return EpdocEditorChromeView(controller: controller)
        .frame(width: 1100, height: 700)
}
#endif
