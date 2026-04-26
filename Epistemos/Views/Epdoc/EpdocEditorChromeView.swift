import Combine
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

    // MARK: - Floating panel state
    public var slashMenuQuery: String? = nil           // non-nil → panel visible
    public var slashMenuAnchor: EpdocBridgeRect? = nil
    public var bubbleMenuSelection: EpdocBridgeSelection? = nil
    public var bubbleMenuAnchor: EpdocBridgeRect? = nil
    public var bubbleMenuSelectedText: String = ""
    public var katexPreviewFormula: String? = nil
    public var katexDisplayMode: EpdocKaTeXPreview.DisplayMode = .display
    public var katexPreviewAnchor: EpdocBridgeRect? = nil

    // MARK: - Dispatch + persistence wiring
    /// Fire a Swift → JS command. The chrome installs this on every
    /// floating panel; the host wires it to evaluateJavaScript on the
    /// active WKWebView.
    public var dispatch: @Sendable @MainActor (EpdocEditorCommand) -> Void
    /// Save trigger — host runs the NSDocument save coordinator.
    public var onSave: @Sendable @MainActor () -> Void
    /// Open the agent inspector with the selected text.
    public var onAskAgent: @Sendable @MainActor (String) -> Void
    /// Capture as RawThought (Wave 3.1).
    public var onCaptureAsRawThought: @Sendable @MainActor (String) -> Void
    /// Halo backend search closure for the Insert link picker (W8.4).
    public var onSearchLinks: @Sendable @MainActor (String) async -> [EpdocLinkSuggestion]
    /// Open the agent inspector for a specific RawThought run id.
    public var onPickRun: @Sendable @MainActor (String) -> Void

    public init() {
        self.toolbarModel = EpdocEditorToolbarModel()
        self.dispatch = { _ in }
        self.onSave = { }
        self.onAskAgent = { _ in }
        self.onCaptureAsRawThought = { _ in }
        self.onSearchLinks = { _ in [] }
        self.onPickRun = { _ in }
        // Wire the toolbar model's dispatch through to the chrome's
        // dispatch so toolbar buttons trigger the same path floating
        // panels do.
        self.toolbarModel.dispatch = { [weak self] cmd in
            self?.dispatch(cmd)
        }
    }

    // MARK: - Bridge message intake

    /// Consume a bridge message from the WKWebView. The chrome
    /// updates its view-state (toolbar counts, panel visibility,
    /// complexity meter) accordingly.
    public func handleBridgeMessage(_ message: EpdocBridgeMessage) {
        switch message {
        case .editorReady:
            break  // host can fire setContent now; nothing for the
                   // chrome to do
        case .contentDidChange:
            // Counts are emitted separately via the JS-side
            // CharacterCount extension; this case is for future
            // diff-tracking instrumentation.
            break
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
        }
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
}

// MARK: - Chrome view

@MainActor
public struct EpdocEditorChromeView: View {

    @Bindable public var controller: EpdocEditorChromeController

    public init(controller: EpdocEditorChromeController) {
        self.controller = controller
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top toolbar (W7.17.a)
            HStack(spacing: 12) {
                EpdocEditorToolbar(model: controller.toolbarModel, onSave: controller.onSave)
                EpdocComplexityMeter(
                    complexity: controller.complexity,
                    breakdown: controller.complexityBreakdown,
                    label: controller.documentTitle
                )
                EpdocThoughtAttachedBadge(
                    attachedRunIDs: controller.attachedRunIDs,
                    onPickRun: controller.onPickRun
                )
                .padding(.trailing, 8)
            }
            // Document area + floating overlays
            ZStack(alignment: .topLeading) {
                EpdocTiptapWebView(controller: controller)
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
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Tiptap WKWebView wrapper

@MainActor
private struct EpdocTiptapWebView: NSViewRepresentable {

    let controller: EpdocEditorChromeController

    func makeNSView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "epdoc")

        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        config.setURLSchemeHandler(EpdocEditorURLSchemeHandler(),
                                   forURLScheme: epdocEditorURLScheme)

        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        if let url = URL(string: "\(epdocEditorURLScheme):///editor.html") {
            view.load(URLRequest(url: url))
        }
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        // The chrome controller's `dispatch` closure is the canonical
        // command surface; we install a closure here that routes
        // commands into evaluateJavaScript so panel buttons reach the
        // editor.
        context.coordinator.webView = view
        context.coordinator.installDispatch(into: controller)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?
        weak var controller: EpdocEditorChromeController?

        func installDispatch(into controller: EpdocEditorChromeController) {
            self.controller = controller
            controller.dispatch = { [weak self] cmd in
                self?.evaluate(cmd)
            }
        }

        nonisolated func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            // WKScriptMessage handler hops to MainActor — bridge
            // decoding + controller dispatch both live there.
            let body = message.body
            Task { @MainActor [weak self] in
                guard let self,
                      let bridgeMessage = EpdocBridgeMessage.decode(messageBody: body) else {
                    return
                }
                self.controller?.handleBridgeMessage(bridgeMessage)
            }
        }

        private func evaluate(_ command: EpdocEditorCommand) {
            guard let webView else { return }
            let js = command.javaScriptExpression()
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
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
