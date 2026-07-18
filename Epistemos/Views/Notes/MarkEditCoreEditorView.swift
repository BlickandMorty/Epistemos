import AppKit
import SwiftUI
import WebKit
import MarkEditCore

#if EPISTEMOS_MARKEDIT_FULL_SHELL && canImport(MarkEditKit)
import MarkEditKit
#endif

nonisolated enum MarkEditCoreEditorBridge {
    static let messageHandlerName = "epistemosMarkEditCoreEditor"
    static let nativeMessageHandlerName = "bridge"
    static let chunkScheme = "chunk-loader"
    static let resourceSubpath = "CoreEditor"
    static let baseURL = URL(string: "http://localhost/")
}

struct CoreEditorSelectionRequest: Equatable {
    let id = UUID()
    let range: NSRange
}

struct MarkEditCodeEditorRepresentable: View {
    @Binding var text: String
    @Binding var cursorLine: Int
    @Binding var cursorColumn: Int
    @Binding var totalLines: Int

    var language: String
    var theme: EpistemosTheme
    var fontSize: Double
    var wrapLines: Bool
    var showLineNumbers: Bool
    var showInvisibles: Bool
    var useSpaces: Bool
    var tabWidth: Int
    var isEditable: Bool = true
    var selectionRequest: CoreEditorSelectionRequest?
    var onContentDirty: (@MainActor () -> Void)?
    var liveTextQueryKey: UUID?

    var body: some View {
        MarkEditCoreEditorRepresentable(
            mode: .code(language: language),
            text: $text,
            cursorLine: $cursorLine,
            cursorColumn: $cursorColumn,
            totalLines: $totalLines,
            theme: theme,
            fontSize: fontSize,
            wrapLines: wrapLines,
            showLineNumbers: showLineNumbers,
            showInvisibles: showInvisibles,
            useSpaces: useSpaces,
            tabWidth: tabWidth,
            isEditable: isEditable,
            selectionRequest: selectionRequest,
            onContentDirty: onContentDirty,
            liveTextQueryKey: liveTextQueryKey
        )
    }
}

struct MarkEditMarkdownEditorRepresentable: View {
    @Binding var text: String
    @Binding var cursorLine: Int
    @Binding var cursorColumn: Int
    @Binding var totalLines: Int

    var theme: EpistemosTheme
    var fontSize: Double
    var wrapLines: Bool
    var showLineNumbers: Bool
    var showInvisibles: Bool
    var useSpaces: Bool
    var tabWidth: Int
    var filePath: String?
    var selectionRequest: CoreEditorSelectionRequest?
    var isEditable: Bool = true
    var onContentDirty: (@MainActor () -> Void)?
    var liveTextQueryKey: UUID?
    var contentWidthMode: NoteWidthMode = .normal
    // Security (bridge audit 2026-07-03, latent HIGH): default FALSE. The `true`
    // branch installs MarkEdit's full native file/service/clipboard API on a
    // page-world "bridge" handler (arbitrary file read/write/delete, runService,
    // pasteboard). Defaulting off keeps that capability from being silently exposed
    // by a future caller; the only production caller already passes false.
    var allowsMarkEditWindowToolbar: Bool = false

    var body: some View {
        #if EPISTEMOS_MARKEDIT_FULL_SHELL && canImport(MarkEditKit)
        if allowsMarkEditWindowToolbar {
            MarkEditVerbatimMarkdownChromeRepresentable(
                text: $text,
                cursorLine: $cursorLine,
                cursorColumn: $cursorColumn,
                totalLines: $totalLines,
                theme: theme,
                filePath: filePath
            )
        } else {
            coreEditorRepresentable
        }
        #else
        coreEditorRepresentable
        #endif
    }

    private var coreEditorRepresentable: some View {
        MarkEditCoreEditorRepresentable(
            mode: .markdownChrome,
            text: $text,
            cursorLine: $cursorLine,
            cursorColumn: $cursorColumn,
            totalLines: $totalLines,
            theme: theme,
            fontSize: fontSize,
            wrapLines: wrapLines,
            showLineNumbers: showLineNumbers,
            showInvisibles: showInvisibles,
            useSpaces: useSpaces,
            tabWidth: tabWidth,
            isEditable: isEditable,
            selectionRequest: selectionRequest,
            onContentDirty: onContentDirty,
            liveTextQueryKey: liveTextQueryKey,
            contentWidthMode: contentWidthMode
        )
    }
}

/// Raw-Markdown CodeMirror canvas for the Epdoc surface. The surrounding
/// window, toolbar, title controls, palette, and native overlays remain owned
/// by `EpdocEditorChromeView`; this view replaces only the editing engine.
struct MarkEditEpdocEditorRepresentable: View {
    @Bindable var controller: EpdocEditorChromeController
    var theme: EpistemosTheme

    @State private var cursorLine = 1
    @State private var cursorColumn = 1
    @State private var totalLines = 1
    @State private var liveTextQueryKey = UUID()

    var body: some View {
        MarkEditCoreEditorRepresentable(
            mode: .epdocMarkdown,
            text: Binding(
                get: { controller.latestMarkdownSnapshot ?? "" },
                set: { controller.acceptCodeMirrorMarkdownSnapshot($0) }
            ),
            cursorLine: $cursorLine,
            cursorColumn: $cursorColumn,
            totalLines: $totalLines,
            theme: theme,
            fontSize: 17,
            wrapLines: true,
            showLineNumbers: false,
            showInvisibles: false,
            useSpaces: true,
            tabWidth: 2,
            isEditable: controller.editorIsEditable,
            selectionRequest: nil,
            onContentDirty: {
                controller.markCodeMirrorContentDirty()
            },
            liveTextQueryKey: liveTextQueryKey,
            epdocController: controller
        )
    }
}

#if EPISTEMOS_MARKEDIT_FULL_SHELL && canImport(MarkEditKit)
private struct MarkEditVerbatimMarkdownChromeRepresentable: NSViewControllerRepresentable {
    @Binding var text: String
    @Binding var cursorLine: Int
    @Binding var cursorColumn: Int
    @Binding var totalLines: Int

    var theme: EpistemosTheme
    var filePath: String?

    func makeCoordinator() -> MarkEditVerbatimMarkdownChromeCoordinator {
        MarkEditVerbatimMarkdownChromeCoordinator(
            text: $text,
            cursorLine: $cursorLine,
            cursorColumn: $cursorColumn,
            totalLines: $totalLines,
            theme: theme,
            filePath: filePath
        )
    }

    func makeNSViewController(context: Context) -> EditorViewController {
        let viewController = EditorViewController()
        context.coordinator.attach(to: viewController, initialText: text)
        return viewController
    }

    func updateNSViewController(_ viewController: EditorViewController, context: Context) {
        context.coordinator.text = $text
        context.coordinator.cursorLine = $cursorLine
        context.coordinator.cursorColumn = $cursorColumn
        context.coordinator.totalLines = $totalLines
        context.coordinator.theme = theme
        context.coordinator.filePath = filePath
        context.coordinator.update(viewController: viewController, externalText: text)
    }

    static func dismantleNSViewController(
        _ viewController: EditorViewController,
        coordinator: MarkEditVerbatimMarkdownChromeCoordinator
    ) {
        coordinator.detach()
    }
}

@MainActor
private final class MarkEditVerbatimMarkdownChromeCoordinator {
    var text: Binding<String>
    var cursorLine: Binding<Int>
    var cursorColumn: Binding<Int>
    var totalLines: Binding<Int>
    var theme: EpistemosTheme
    var filePath: String?

    private weak var viewController: EditorViewController?
    private var document: EditorDocument?
    private var lastAppliedText: String?
    private var applyingText: String?
    private var isApplyingFromSwift = false
    private var applyTask: Task<Void, Never>?
    private var applyGeneration = 0
    private var lineCountTask: Task<Void, Never>?
    private var pollingTask: Task<Void, Never>?
    private var chromeTask: Task<Void, Never>?
    private var themeTask: Task<Void, Never>?
    private var lastAppliedTheme: EpistemosTheme?

    init(
        text: Binding<String>,
        cursorLine: Binding<Int>,
        cursorColumn: Binding<Int>,
        totalLines: Binding<Int>,
        theme: EpistemosTheme,
        filePath: String?
    ) {
        self.text = text
        self.cursorLine = cursorLine
        self.cursorColumn = cursorColumn
        self.totalLines = totalLines
        self.theme = theme
        self.filePath = filePath
    }

    func attach(to viewController: EditorViewController, initialText: String) {
        self.viewController = viewController
        EditorPreloader.shared.registerExternalViewController(viewController)
        configureDocument(for: viewController, text: initialText)
        configureChromeWhenWindowReady(for: viewController)
        applyThemeIfNeeded(to: viewController, force: true)
        apply(text: initialText, to: viewController, documentChanged: true)
        startPolling(viewController: viewController)
    }

    func update(viewController: EditorViewController, externalText: String) {
        self.viewController = viewController
        configureDocument(for: viewController, text: externalText)
        configureChromeWhenWindowReady(for: viewController)
        applyThemeIfNeeded(to: viewController)
        guard externalText != lastAppliedText,
              externalText != applyingText else { return }
        apply(text: externalText, to: viewController, documentChanged: false)
    }

    func detach() {
        applyGeneration += 1
        if let viewController {
            flushCurrentTextBeforeDetach(from: viewController)
        }
        applyTask?.cancel()
        applyTask = nil
        lineCountTask?.cancel()
        lineCountTask = nil
        pollingTask?.cancel()
        pollingTask = nil
        chromeTask?.cancel()
        chromeTask = nil
        themeTask?.cancel()
        themeTask = nil
        if let viewController {
            EditorPreloader.shared.unregisterExternalViewController(viewController)
        }
        viewController = nil
        document = nil
        lastAppliedText = nil
        applyingText = nil
        isApplyingFromSwift = false
        lastAppliedTheme = nil
    }

    private func configureDocument(for viewController: EditorViewController, text: String) {
        let editorDocument = document ?? EditorDocument()
        document = editorDocument
        editorDocument.stringValue = text
        if let filePath,
           !filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            editorDocument.fileURL = URL(fileURLWithPath: filePath)
        }
        if viewController.representedObject as? EditorDocument !== editorDocument {
            viewController.representedObject = editorDocument
        }
    }

    private func configureChromeWhenWindowReady(for viewController: EditorViewController) {
        guard chromeTask == nil else { return }
        chromeTask = Task { @MainActor [weak self, weak viewController] in
            for _ in 0..<20 {
                guard let self, let viewController, !Task.isCancelled else { return }
                if viewController.view.window != nil {
                    viewController.configureToolbar()
                    self.chromeTask = nil
                    return
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            self?.chromeTask = nil
        }
    }

    private func applyThemeIfNeeded(to viewController: EditorViewController, force: Bool = false) {
        guard force || lastAppliedTheme != theme else { return }
        lastAppliedTheme = theme
        let nextTheme = AppTheme.epistemosSourceTheme(for: theme)
        let palette = MarkEditCoreEditorThemePalette.current(theme: theme)
        let backgroundColor = MarkdownPreviewSurfaceStyle
            .solidFlatBackgroundNSColor(for: theme)
            .withAlphaComponent(1.0)
        themeTask?.cancel()
        themeTask = Task { @MainActor [weak self, weak viewController] in
            guard let viewController else { return }
            await viewController.waitUntilLoaded()
            guard !Task.isCancelled else { return }
            viewController.webBackgroundColor = backgroundColor
            viewController.setTheme(nextTheme, animated: false)
            if let script = MarkEditCoreEditorThemeOverlay.script(themeName: nil, palette: palette) {
                _ = try? await viewController.webView.evaluateJavaScript(script)
            }
            self?.themeTask = nil
        }
    }

    private func apply(
        text nextText: String,
        to viewController: EditorViewController,
        documentChanged: Bool
    ) {
        applyGeneration += 1
        let generation = applyGeneration
        applyTask?.cancel()
        applyingText = nextText
        scheduleLineCountUpdate(for: nextText)
        document?.stringValue = nextText
        isApplyingFromSwift = true
        applyTask = Task { @MainActor [weak self, weak viewController] in
            guard let self else { return }
            defer {
                if generation == self.applyGeneration {
                    self.isApplyingFromSwift = false
                    self.applyingText = nil
                    self.applyTask = nil
                }
            }

            guard let viewController, !Task.isCancelled else { return }
            await viewController.waitUntilLoaded()
            guard !Task.isCancelled else { return }

            do {
                _ = try await viewController.bridge.core.resetEditor(
                    text: nextText,
                    selectionRange: nil,
                    documentChanged: documentChanged
                )
                guard generation == self.applyGeneration, !Task.isCancelled else { return }
                self.lastAppliedText = nextText
            } catch {
                guard generation == self.applyGeneration else { return }
                self.lastAppliedText = nil
            }
        }
    }

    private func startPolling(viewController: EditorViewController) {
        guard pollingTask == nil else { return }
        pollingTask = Task { @MainActor [weak self, weak viewController] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard let self, let viewController else { continue }
                await self.poll(viewController: viewController)
            }
        }
    }

    private func poll(viewController: EditorViewController) async {
        guard !isApplyingFromSwift,
              let nextText = await viewController.editorText,
              nextText != text.wrappedValue else { return }
        applyObservedText(nextText)
    }

    private func flushCurrentTextBeforeDetach(from viewController: EditorViewController) {
        Task { @MainActor [self, viewController] in
            guard let nextText = await viewController.editorText else { return }
            applyObservedText(nextText)
        }
    }

    private func applyObservedText(_ nextText: String) {
        guard nextText != text.wrappedValue else { return }
        text.wrappedValue = nextText
        document?.stringValue = nextText
        lastAppliedText = nextText
        updateLineCountNow(for: nextText)
    }

    private func scheduleLineCountUpdate(for text: String) {
        lineCountTask?.cancel()
        lineCountTask = Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, !Task.isCancelled else { return }
            self.updateLineCountNow(for: text)
            self.lineCountTask = nil
        }
    }

    private func updateLineCountNow(for text: String) {
        totalLines.wrappedValue = CodeEditorLineMetrics.lineCount(text)
        cursorLine.wrappedValue = min(max(1, cursorLine.wrappedValue), totalLines.wrappedValue)
        cursorColumn.wrappedValue = max(1, cursorColumn.wrappedValue)
    }
}

private extension AppTheme {
    static func epistemosSourceTheme(for theme: EpistemosTheme) -> AppTheme {
        return presetSourceTheme(for: theme)
    }

    static func presetSourceTheme(for theme: EpistemosTheme) -> AppTheme {
        switch theme {
        case .tan, .sunset:
            return .SolarizedLight
        case .ember:
            return .SolarizedDark
        case .nocturne:
            return .NightOwl
        case .oled, .oledSoft, .systemDark, .platinumVioletDark:
            return .XcodeDark
        case .systemLight, .light, .sunny, .platinumViolet:
            return .GitHubLight
        }
    }

}
#endif

enum MarkEditCoreEditorMode: Equatable {
    case code(language: String)
    case markdownChrome
    case epdocMarkdown

    var configMode: String {
        switch self {
        case .code:
            return "code"
        case .markdownChrome:
            return "markdown"
        case .epdocMarkdown:
            return "epdoc"
        }
    }

    var configCodeLanguage: String? {
        switch self {
        case .code(let language):
            return language
        case .markdownChrome, .epdocMarkdown:
            return nil
        }
    }

    var language: String {
        switch self {
        case .code(let language):
            return language
        case .markdownChrome:
            return "markdown"
        case .epdocMarkdown:
            return "markdown"
        }
    }

    var usesMarkdownTypography: Bool {
        switch self {
        case .code:
            return false
        case .markdownChrome, .epdocMarkdown:
            return true
        }
    }
}

private struct MarkEditCoreEditorRepresentable: NSViewRepresentable {
    var mode: MarkEditCoreEditorMode
    @Binding var text: String
    @Binding var cursorLine: Int
    @Binding var cursorColumn: Int
    @Binding var totalLines: Int

    var theme: EpistemosTheme
    var fontSize: Double
    var wrapLines: Bool
    var showLineNumbers: Bool
    var showInvisibles: Bool
    var useSpaces: Bool
    var tabWidth: Int
    var isEditable: Bool
    var selectionRequest: CoreEditorSelectionRequest?
    var onContentDirty: (@MainActor () -> Void)?
    var liveTextQueryKey: UUID?
    var epdocController: EpdocEditorChromeController? = nil
    var contentWidthMode: NoteWidthMode = .wide

    func makeCoordinator() -> MarkEditCoreEditorCoordinator {
        MarkEditCoreEditorCoordinator(
            text: $text,
            cursorLine: $cursorLine,
            cursorColumn: $cursorColumn,
            totalLines: $totalLines,
            onContentDirty: onContentDirty
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        #if EPISTEMOS_FREE_V1
        configuration.writingToolsBehavior = .none
        #endif
        configuration.setURLSchemeHandler(
            MarkEditCoreEditorChunkLoader(),
            forURLScheme: MarkEditCoreEditorBridge.chunkScheme
        )
        configuration.userContentController.add(
            context.coordinator,
            name: MarkEditCoreEditorBridge.messageHandlerName
        )
        configuration.userContentController.addScriptMessageHandler(
            context.coordinator,
            contentWorld: .page,
            name: MarkEditCoreEditorBridge.nativeMessageHandlerName
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.underPageBackgroundColor = .clear
        context.coordinator.webView = webView
        context.coordinator.attachEpdocController(epdocController)
        context.coordinator.updateContentWidth(contentWidthMode, in: webView)
        context.coordinator.loadEditor(into: webView, initialState: state)
        context.coordinator.registerLiveTextQuery(key: liveTextQueryKey, webView: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.cursorLine = $cursorLine
        context.coordinator.cursorColumn = $cursorColumn
        context.coordinator.totalLines = $totalLines
        context.coordinator.onContentDirty = onContentDirty
        context.coordinator.attachEpdocController(epdocController)
        context.coordinator.updateContentWidth(contentWidthMode, in: webView)
        context.coordinator.registerLiveTextQuery(key: liveTextQueryKey, webView: webView)
        context.coordinator.update(
            webView: webView,
            state: state,
            selectionRequest: selectionRequest
        )
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: MarkEditCoreEditorCoordinator) {
        coordinator.detach(from: webView)
    }

    private var state: MarkEditCoreEditorState {
        let sourceDefaults = MarkEditCoreEditorSourceDefaults.current(
            mode: mode,
            theme: theme,
            fallbackFontSize: fontSize
        )
        return MarkEditCoreEditorState(
            text: text,
            mode: mode,
            themeName: sourceDefaults.themeName,
            themePalette: MarkEditCoreEditorThemePalette.current(theme: theme),
            fontFace: sourceDefaults.fontFace,
            fontSize: sourceDefaults.fontSize,
            lineHeight: sourceDefaults.lineHeight,
            wrapLines: wrapLines,
            showLineNumbers: showLineNumbers,
            showInvisibles: showInvisibles,
            useSpaces: useSpaces,
            tabWidth: tabWidth,
            isEditable: isEditable
        )
    }
}

private struct MarkEditCoreEditorSourceDefaults: Equatable {
    let themeName: String
    let fontFace: WebFontFace
    let fontSize: Double
    let lineHeight: Double

    static func current(
        mode: MarkEditCoreEditorMode,
        theme: EpistemosTheme,
        fallbackFontSize: Double
    ) -> MarkEditCoreEditorSourceDefaults {
        MarkEditCoreEditorSourceDefaults(
            themeName: themeName(for: theme),
            fontFace: fontFace(for: mode),
            fontSize: fontSize(for: mode, fallbackFontSize: fallbackFontSize),
            lineHeight: lineHeight
        )
    }

    private static func themeName(for theme: EpistemosTheme) -> String {
        #if EPISTEMOS_MARKEDIT_FULL_SHELL && canImport(MarkEditKit)
        AppTheme.epistemosSourceTheme(for: theme).editorTheme
        #else
        switch theme {
        case .tan, .sunset:
            "solarized-light"
        case .ember:
            "solarized-dark"
        case .nocturne:
            "night-owl"
        case .oled, .oledSoft, .systemDark, .platinumVioletDark:
            "xcode-dark"
        case .systemLight, .light, .sunny, .platinumViolet:
            "github-light"
        }
        #endif
    }

    private static func fontFace(for mode: MarkEditCoreEditorMode) -> WebFontFace {
        #if EPISTEMOS_MARKEDIT_FULL_SHELL && canImport(MarkEditKit)
        if mode.usesMarkdownTypography {
            return AppPreferences.Editor.fontStyle.webFontFace
        }
        #endif
        if mode.usesMarkdownTypography {
            return WebFontFace(family: "ui-monospace", weight: nil, style: nil)
        }
        return WebFontFace(family: "SF Mono", weight: nil, style: nil)
    }

    private static func fontSize(for mode: MarkEditCoreEditorMode, fallbackFontSize: Double) -> Double {
        #if EPISTEMOS_MARKEDIT_FULL_SHELL && canImport(MarkEditKit)
        if mode.usesMarkdownTypography {
            return AppPreferences.Editor.fontSize
        }
        #endif
        switch mode {
        case .markdownChrome:
            return 15
        case .epdocMarkdown, .code:
            return max(8, min(fallbackFontSize, 32))
        }
    }

    private static var lineHeight: Double {
        #if EPISTEMOS_MARKEDIT_FULL_SHELL && canImport(MarkEditKit)
        AppPreferences.Editor.lineHeight.multiplier
        #else
        1.5
        #endif
    }
}
