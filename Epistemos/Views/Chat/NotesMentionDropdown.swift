import AppKit
import Observation
import SwiftUI

enum NoteMentionChoice: Identifiable {
    case allNotes
    case entry(VaultManifest.ManifestEntry)

    var id: String {
        switch self {
        case .allNotes: "all-notes"
        case .entry(let entry): entry.pageId
        }
    }
}

enum ComposerReferenceHelpers {
    private static func isMentionTriggerBoundary(_ character: Character) -> Bool {
        !(character.isLetter || character.isNumber || character == "_" || character == "." || character == "-")
    }

    private static func activeMentionRange(in text: String) -> Range<String.Index>? {
        guard let atIndex = text.lastIndex(of: "@") else { return nil }
        if atIndex > text.startIndex {
            let previous = text[text.index(before: atIndex)]
            guard isMentionTriggerBoundary(previous) else { return nil }
        }

        let suffixStart = text.index(after: atIndex)
        let suffix = text[suffixStart...]
        guard !suffix.contains("]"),
              !suffix.contains("\n"),
              !suffix.contains("\r") else { return nil }
        return atIndex..<text.endIndex
    }

    static func mentionFilter(in text: String) -> String? {
        guard let range = activeMentionRange(in: text) else { return nil }
        return String(text[range].dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func removingTrailingMention(from text: String) -> String {
        guard let range = activeMentionRange(in: text) else { return text }
        return String(text[..<range.lowerBound])
    }

    static var allNotesAttachment: ContextAttachment {
        ContextAttachment(
            kind: .allNotes,
            targetId: ChatCoordinator.allNotesMentionToken,
            title: "All Notes",
            subtitle: "Vault"
        )
    }

    static func contextAttachment(for choice: ComposerReferenceChoice) -> ContextAttachment {
        switch choice {
        case .note(let noteChoice):
            switch noteChoice {
            case .allNotes:
                allNotesAttachment
            case .entry(let entry):
                ContextAttachment(
                    kind: .note,
                    targetId: entry.pageId,
                    title: entry.title,
                    subtitle: entry.folderName
                )
            }
        case .chat(let result):
            result.attachment
        }
    }

    static func noteAttachment(pageID: String, title: String, subtitle: String? = nil) -> ContextAttachment {
        ContextAttachment(
            kind: .note,
            targetId: pageID,
            title: title.isEmpty ? "Untitled" : title,
            subtitle: subtitle
        )
    }
}

enum ComposerReferenceChoice: Identifiable {
    case note(NoteMentionChoice)
    case chat(ChatCoordinator.ChatReferenceResult)

    var id: String {
        switch self {
        case .note(let note):
            "note:\(note.id)"
        case .chat(let chat):
            "chat:\(chat.id)"
        }
    }
}

enum ComposerReferencePopoverLayout {
    static let screenInset: CGFloat = 24
    static let minimumWidth: CGFloat = 420

    static func resolvedWidth(
        idealWidth: CGFloat,
        anchorFrame: CGRect,
        screenFrame: CGRect
    ) -> CGFloat {
        let maxScreenWidth = max(320, screenFrame.width - (screenInset * 2))
        let clampedIdeal = min(idealWidth, maxScreenWidth)
        let trailingSpace = max(0, screenFrame.maxX - anchorFrame.minX - screenInset)
        let leadingSpace = max(0, anchorFrame.maxX - screenFrame.minX - screenInset)
        let available = max(trailingSpace, leadingSpace)
        guard available > 0 else { return clampedIdeal }
        let floor = min(minimumWidth, available)
        return max(floor, min(clampedIdeal, available))
    }

    static func horizontalOffset(
        width: CGFloat,
        anchorFrame: CGRect,
        screenFrame: CGRect
    ) -> CGFloat {
        let maxAllowedX = screenFrame.maxX - screenInset
        let minAllowedX = screenFrame.minX + screenInset
        let proposedMinX = anchorFrame.minX
        let proposedMaxX = proposedMinX + width
        if proposedMaxX > maxAllowedX {
            return maxAllowedX - proposedMaxX
        }
        if proposedMinX < minAllowedX {
            return minAllowedX - proposedMinX
        }
        return 0
    }

    static func prefersAboveAnchor(
        popoverHeight: CGFloat,
        anchorFrame: CGRect,
        screenFrame: CGRect,
        preferredAbove: Bool
    ) -> Bool {
        let availableBelow = screenFrame.maxY - anchorFrame.minY - screenInset
        let availableAbove = anchorFrame.maxY - screenFrame.minY - screenInset

        if preferredAbove {
            if availableAbove >= popoverHeight { return true }
            if availableBelow >= popoverHeight { return false }
            return availableAbove >= availableBelow
        }

        if availableBelow >= popoverHeight { return false }
        if availableAbove >= popoverHeight { return true }
        return availableAbove > availableBelow
    }
}

@MainActor @Observable
final class ComposerReferenceSearchState {
    var indexedNoteIDs: [String] = []
    var indexedNoteSnippetsByPageID: [String: String] = [:]

    @ObservationIgnored
    private var searchTask: Task<Void, Never>?
    @ObservationIgnored
    private var cachedManifestGeneratedAt: Date?
    @ObservationIgnored
    private var cachedManifestEntryCount = 0
    @ObservationIgnored
    private var cachedManifestPageIDs = Set<String>()

    func update(
        filter: String,
        manifest: VaultManifest?,
        vaultSync: VaultSyncService
    ) {
        let trimmedFilter = filter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFilter.isEmpty, let manifest else {
            reset()
            return
        }

        let manifestPageIDs = pageIDs(in: manifest)
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            let hits = await vaultSync.searchFullAsync(query: trimmedFilter, limit: 12)
            let matchedHits = hits.filter { manifestPageIDs.contains($0.pageId) }
            let matchedIDs = Self.uniquePreservingOrder(matchedHits.map(\.pageId))
            let snippets = Self.snippetsByPageID(for: matchedHits)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.indexedNoteIDs = matchedIDs
                self?.indexedNoteSnippetsByPageID = snippets
            }
        }
    }

    func reset() {
        searchTask?.cancel()
        searchTask = nil
        indexedNoteIDs = []
        indexedNoteSnippetsByPageID = [:]
    }

    deinit {
        searchTask?.cancel()
    }

    private static func uniquePreservingOrder(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        var results: [String] = []
        results.reserveCapacity(ids.count)
        for id in ids where seen.insert(id).inserted {
            results.append(id)
        }
        return results
    }

    private func pageIDs(in manifest: VaultManifest) -> Set<String> {
        if cachedManifestGeneratedAt == manifest.generatedAt,
           cachedManifestEntryCount == manifest.entries.count {
            return cachedManifestPageIDs
        }

        let pageIDs = Set(manifest.entries.lazy.map(\.pageId))
        cachedManifestGeneratedAt = manifest.generatedAt
        cachedManifestEntryCount = manifest.entries.count
        cachedManifestPageIDs = pageIDs
        return pageIDs
    }

    private static func snippetsByPageID(for hits: [SearchResult]) -> [String: String] {
        var snippets: [String: String] = [:]
        for hit in hits where snippets[hit.pageId] == nil {
            let snippet = normalizedSnippet(hit.snippet)
            guard !snippet.isEmpty else { continue }
            snippets[hit.pageId] = snippet
        }
        return snippets
    }

    private static func normalizedSnippet(_ snippet: String) -> String {
        snippet
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ComposerContextShortcutBar: View {
    let noteLabel: String
    var chatLabel: String = "Chat with Chat"
    let onChatWithNote: () -> Void
    var onChatWithChat: (() -> Void)? = nil

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 8) {
            actionButton(
                title: noteLabel,
                icon: "doc.text.magnifyingglass",
                action: onChatWithNote
            )
            if let onChatWithChat {
                actionButton(
                    title: chatLabel,
                    icon: "bubble.left.and.bubble.right",
                    action: onChatWithChat
                )
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func actionButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .assistantInsetChrome(theme: theme, cornerRadius: 15)
    }
}

enum ComposerReferencePopoverStyle {
    case mention
    case notePicker
    case chatPicker

    var idealWidth: CGFloat {
        switch self {
        case .mention: 560
        case .notePicker: 760
        case .chatPicker: 560
        }
    }

    var maxHeight: CGFloat {
        switch self {
        case .mention: 420
        case .notePicker: 560
        case .chatPicker: 460
        }
    }

    var searchSectionHeight: CGFloat {
        switch self {
        case .mention: 62
        case .notePicker: 96
        case .chatPicker: 62
        }
    }

    var preferredEdge: NSRectEdge {
        switch self {
        case .mention: .maxY
        case .notePicker, .chatPicker: .minY
        }
    }
}

@MainActor @Observable
final class ComposerReferencePopoverBridge {
    var results: ChatCoordinator.ReferenceSearchResults
    var query: String
    var width: CGFloat
    var maxHeight: CGFloat
    var style: ComposerReferencePopoverStyle
    var autofocusSearchField: Bool
    @ObservationIgnored var selectAction: ((ComposerReferenceChoice) -> Void)?
    @ObservationIgnored var queryChangeAction: ((String) -> Void)?

    init(
        results: ChatCoordinator.ReferenceSearchResults,
        query: String,
        width: CGFloat,
        maxHeight: CGFloat,
        style: ComposerReferencePopoverStyle,
        autofocusSearchField: Bool
    ) {
        self.results = results
        self.query = query
        self.width = width
        self.maxHeight = maxHeight
        self.style = style
        self.autofocusSearchField = autofocusSearchField
    }
}

private struct ComposerReferencePopoverBridgeRoot: View {
    let bridge: ComposerReferencePopoverBridge

    var body: some View {
        ComposerReferencePopoverContent(
            results: bridge.results,
            query: Binding(
                get: { bridge.query },
                set: { newValue in
                    bridge.query = newValue
                    bridge.queryChangeAction?(newValue)
                }
            ),
            width: bridge.width,
            maxHeight: bridge.maxHeight,
            style: bridge.style,
            autofocusSearchField: bridge.autofocusSearchField,
            onSelect: { choice in
                bridge.selectAction?(choice)
            }
        )
    }
}

final class ComposerReferencePopoverCoordinator: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private var host: NSHostingController<ComposerReferencePopoverBridgeRoot>?
    private var bridge: ComposerReferencePopoverBridge?
    private var onDismiss: (() -> Void)?
    private var showTask: Task<Void, Never>?
    private var suppressNextDismissCallback = false

    override init() {
        super.init()
        popover.behavior = .semitransient
        popover.animates = true
        popover.delegate = self
    }

    func present(from anchorView: NSView, configuration: ComposerReferencePopover) {
        onDismiss = configuration.onDismiss

        let anchorFrame = anchorView.window?.convertToScreen(anchorView.bounds) ?? .zero
        let screenFrame = anchorView.window?.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: configuration.idealWidth, height: configuration.maxHeight)
        let width = ComposerReferencePopoverLayout.resolvedWidth(
            idealWidth: configuration.idealWidth,
            anchorFrame: anchorFrame,
            screenFrame: screenFrame
        )

        let queryBinding = configuration.$query
        if let bridge {
            bridge.results = configuration.results
            if bridge.query != configuration.query { bridge.query = configuration.query }
            if bridge.width != width { bridge.width = width }
            if bridge.maxHeight != configuration.maxHeight { bridge.maxHeight = configuration.maxHeight }
            if bridge.style != configuration.style { bridge.style = configuration.style }
            if bridge.autofocusSearchField != configuration.autofocusSearchField { bridge.autofocusSearchField = configuration.autofocusSearchField }
            bridge.selectAction = configuration.onSelect
            bridge.queryChangeAction = { queryBinding.wrappedValue = $0 }
        } else {
            let newBridge = ComposerReferencePopoverBridge(
                results: configuration.results,
                query: configuration.query,
                width: width,
                maxHeight: configuration.maxHeight,
                style: configuration.style,
                autofocusSearchField: configuration.autofocusSearchField
            )
            newBridge.selectAction = configuration.onSelect
            newBridge.queryChangeAction = { queryBinding.wrappedValue = $0 }
            self.bridge = newBridge

            let rootView = ComposerReferencePopoverBridgeRoot(bridge: newBridge)
            let hostingController = NSHostingController(rootView: rootView)
            host = hostingController
            popover.contentViewController = hostingController
        }

        let newSize = NSSize(width: width, height: configuration.maxHeight)
        if popover.contentSize != newSize {
            popover.contentSize = newSize
        }

        guard !popover.isShown else { return }
        showTask?.cancel()
        showTask = Task { @MainActor [weak self, weak anchorView] in
            await Task.yield()
            guard let self, let anchorView, anchorView.window != nil else { return }
            let anchorRect = NSRect(
                x: 0,
                y: 0,
                width: max(anchorView.bounds.width, 1),
                height: max(anchorView.bounds.height, 1)
            )
            self.popover.show(
                relativeTo: anchorRect,
                of: anchorView,
                preferredEdge: configuration.style.preferredEdge
            )
        }
    }

    func dismiss() {
        showTask?.cancel()
        showTask = nil
        guard popover.isShown else { return }
        suppressNextDismissCallback = true
        popover.close()
    }

    func popoverDidClose(_ notification: Notification) {
        if suppressNextDismissCallback {
            suppressNextDismissCallback = false
            return
        }
        onDismiss?()
    }

    deinit {
        showTask?.cancel()
    }
}

private final class ComposerReferencePopoverAnchorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct ComposerReferencePopover: NSViewRepresentable {
    @Binding var isPresented: Bool
    let results: ChatCoordinator.ReferenceSearchResults
    let onSelect: (ComposerReferenceChoice) -> Void
    let idealWidth: CGFloat
    let maxHeight: CGFloat
    let style: ComposerReferencePopoverStyle
    @Binding var query: String
    let autofocusSearchField: Bool
    let onDismiss: () -> Void

    init(
        isPresented: Binding<Bool>,
        results: ChatCoordinator.ReferenceSearchResults,
        query: Binding<String>,
        idealWidth: CGFloat = 428,
        maxHeight: CGFloat = 360,
        style: ComposerReferencePopoverStyle = .mention,
        autofocusSearchField: Bool = false,
        onDismiss: @escaping () -> Void = {},
        onSelect: @escaping (ComposerReferenceChoice) -> Void
    ) {
        _isPresented = isPresented
        self.results = results
        _query = query
        self.onSelect = onSelect
        self.idealWidth = idealWidth
        self.maxHeight = maxHeight
        self.style = style
        self.autofocusSearchField = autofocusSearchField
        self.onDismiss = onDismiss
    }

    func makeCoordinator() -> ComposerReferencePopoverCoordinator {
        ComposerReferencePopoverCoordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = ComposerReferencePopoverAnchorView(frame: .zero)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if isPresented {
            context.coordinator.present(from: nsView, configuration: self)
        } else {
            context.coordinator.dismiss()
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ComposerReferencePopoverCoordinator) {
        coordinator.dismiss()
    }
}

private struct ComposerReferencePopoverContent: View {
    let results: ChatCoordinator.ReferenceSearchResults
    let onSelect: (ComposerReferenceChoice) -> Void
    let width: CGFloat
    let maxHeight: CGFloat
    let style: ComposerReferencePopoverStyle
    @Binding private var query: String
    private let autofocusSearchField: Bool

    @FocusState private var isSearchFocused: Bool

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    init(
        results: ChatCoordinator.ReferenceSearchResults,
        query: Binding<String>,
        width: CGFloat,
        maxHeight: CGFloat,
        style: ComposerReferencePopoverStyle,
        autofocusSearchField: Bool,
        onSelect: @escaping (ComposerReferenceChoice) -> Void
    ) {
        self.results = results
        _query = query
        self.width = width
        self.maxHeight = maxHeight
        self.style = style
        self.autofocusSearchField = autofocusSearchField
        self.onSelect = onSelect
    }

    private var usesReducedOverdrawChrome: Bool {
        style == .notePicker || style == .chatPicker
    }

    var body: some View {
        Group {
            if usesReducedOverdrawChrome {
                framedPopoverContent
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(theme.resolved.background.color.opacity(theme.isDark ? 0.985 : 0.995))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(theme.glassBg.opacity(theme.isDark ? 0.20 : 0.28))
                            }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                theme.glassBorder.opacity(theme.isDark ? 0.48 : 0.34),
                                lineWidth: 0.65
                            )
                    }
                    .compositingGroup()
                    .shadow(
                        color: .black.opacity(theme.isDark ? 0.18 : 0.08),
                        radius: 14,
                        y: 8
                    )
            } else {
                framedPopoverContent
                    .assistantPopoverChrome(theme: theme)
            }
        }
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(theme.isDark ? 0.04 : 0.18))
                .frame(height: 1)
                .padding(.horizontal, 18)
                .padding(.top, 1)
        }
        .task(id: autofocusSearchField) {
            guard autofocusSearchField else { return }
            try? await Task.sleep(for: .milliseconds(60))
            isSearchFocused = true
        }
    }

    private var framedPopoverContent: some View {
        popoverContent
            .frame(width: width, alignment: .topLeading)
            .frame(maxHeight: maxHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private var popoverContent: some View {
        if style == .chatPicker {
            VStack(alignment: .leading, spacing: 0) {
                popoverHeader
                popoverSearchField
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                Divider()
                    .overlay(theme.glassBorder.opacity(theme.isDark ? 0.45 : 0.28))
                resultsScrollContent
            }
        } else if style == .notePicker {
            HStack(spacing: 0) {
                notePickerSidebar
                    .frame(width: min(220, width * 0.3), alignment: .topLeading)
                Divider()
                    .overlay(theme.glassBorder.opacity(theme.isDark ? 0.45 : 0.28))
                VStack(alignment: .leading, spacing: 0) {
                    popoverHeader
                    popoverSearchField
                        .padding(.horizontal, 18)
                        .padding(.bottom, 14)
                    Divider()
                        .overlay(theme.glassBorder.opacity(theme.isDark ? 0.45 : 0.28))
                    resultsScrollContent
                    Divider()
                        .overlay(theme.glassBorder.opacity(theme.isDark ? 0.4 : 0.24))
                    footerHint
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                popoverHeader
                popoverSearchField
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                Divider()
                    .overlay(theme.glassBorder.opacity(theme.isDark ? 0.45 : 0.28))
                resultsScrollContent
                if results.vaultNoteCount > 0 {
                    Divider()
                        .overlay(theme.glassBorder.opacity(theme.isDark ? 0.4 : 0.24))
                    footerHint
                }
            }
        }
    }

    private var resultsScrollContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            NotesMentionDropdown(
                results: results,
                style: style,
                onSelect: onSelect
            )
            .padding(.vertical, 8)
        }
        .frame(maxHeight: maxHeight - style.searchSectionHeight, alignment: .topLeading)
        .clipped()
    }

    private var notePickerSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Context", systemImage: "sidebar.left")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)

                Text("Attach exactly what this turn should know.")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.resolved.foreground.color)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Pick one note, search your vault, or attach the full vault retrieval index for this message.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 10) {
                notePickerSidebarButton(
                    title: "All Notes",
                    subtitle: results.vaultNoteCount > 0
                        ? "Attach \(results.vaultNoteCount) indexed notes through retrieval."
                        : "Attach the vault retrieval index for this turn.",
                    systemName: "books.vertical.fill"
                ) {
                    onSelect(.note(.allNotes))
                }

                if let firstNote = firstConcreteNoteChoice {
                    notePickerSidebarButton(
                        title: "Top Match",
                        subtitle: firstNote.title,
                        systemName: "doc.text.magnifyingglass"
                    ) {
                        onSelect(.note(.entry(firstNote)))
                    }
                }
            }
            .padding(.horizontal, 14)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                Text("Searches titles, folders, tags, and indexed body snippets.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if resultCount > 0 {
                    Text("\(resultCount) contextual results ready")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(theme.glassBg.opacity(theme.isDark ? 0.28 : 0.4))
    }

    private var popoverHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: headerIcon)
                .font(.system(size: style == .notePicker ? 13 : 12, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color.opacity(0.92))
                .frame(width: style == .notePicker ? 30 : 26, height: style == .notePicker ? 30 : 26)
                .background(
                    Circle()
                        .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.10))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(headerTitle)
                    .font(.system(size: style == .notePicker ? 13.5 : 12.5, weight: .semibold))
                    .foregroundStyle(theme.resolved.foreground.color)
                Text(popoverSubtitle)
                    .font(.system(size: style == .notePicker ? 11.5 : 10.5, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if resultCount > 0 {
                Text("\(resultCount)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .assistantInsetChrome(theme: theme, cornerRadius: 12)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, style == .notePicker ? 16 : 12)
        .padding(.bottom, style == .notePicker ? 12 : 10)
    }

    private var popoverSubtitle: String {
        if style == .chatPicker {
            return results.query.isEmpty
                ? "Search your past conversations to reference or ask about them."
                : "Search your past conversations to reference or ask about them."
        }
        if style == .notePicker {
            return results.query.isEmpty
                ? "Search your notes and chats, then attach the exact context you want in this turn."
                : "Search your notes and chats, then attach the exact context you want in this turn."
        }
        if results.query.isEmpty {
            return "Attach a note, search your vault, or bring the whole index into this turn."
        }
        return "Searching titles, folders, tags, and body excerpts for “\(results.query)”."
    }

    private var headerTitle: String {
        if style == .chatPicker {
            return results.query.isEmpty ? "Browse Conversations" : "Search Chats"
        }
        if style == .notePicker {
            return results.query.isEmpty ? "Find Note Context" : "Search Results"
        }
        return results.query.isEmpty ? "Browse Note Context" : "Search Notes and Chats"
    }

    private var headerIcon: String {
        if style == .chatPicker {
            return results.query.isEmpty ? "bubble.left.and.bubble.right.fill" : "magnifyingglass"
        }
        if style == .notePicker {
            return "magnifyingglass"
        }
        return results.query.isEmpty ? "books.vertical.fill" : "magnifyingglass"
    }

    private var popoverSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: style == .notePicker ? 13 : 12, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            TextField(
                "Search notes, chats, tags, folders, and snippets",
                text: $query
            )
            .textFieldStyle(.plain)
            .font(.system(size: style == .notePicker ? 13.5 : 12.5, weight: .medium, design: .rounded))
            .foregroundStyle(theme.resolved.foreground.color)
            .focused($isSearchFocused)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, style == .notePicker ? 14 : 12)
        .padding(.vertical, style == .notePicker ? 12 : 10)
        .assistantInsetChrome(
            theme: theme,
            cornerRadius: style == .notePicker ? 18 : 16,
            isEmphasized: isSearchFocused || !query.isEmpty
        )
    }

    private var footerHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
            Text(results.indexedMatchedNoteIDs.isEmpty
                 ? "Rich matches come from your vault inventory and recent note excerpts."
                 : "Body matches are boosted from the live vault index and labeled below.")
                .font(.system(size: 10.5))
                .foregroundStyle(theme.textTertiary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var firstConcreteNoteChoice: VaultManifest.ManifestEntry? {
        for note in results.notes {
            if case .entry(let entry) = note {
                return entry
            }
        }
        return nil
    }

    private var resultCount: Int {
        results.notes.count + results.chats.count
    }

    private func notePickerSidebarButton(
        title: String,
        subtitle: String,
        systemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color.opacity(0.92))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.10))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(theme.resolved.foreground.color)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .assistantInsetChrome(theme: theme, cornerRadius: 16, isEmphasized: false)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notes Mention Dropdown
// Floating dropdown triggered by @ in ChatInputBar during Notes Mode.
// Shows filtered note titles from the in-memory VaultManifest.

struct NotesMentionDropdown: View {
    let results: ChatCoordinator.ReferenceSearchResults
    let style: ComposerReferencePopoverStyle
    let onSelect: (ComposerReferenceChoice) -> Void

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var showNotes: Bool { style != .chatPicker }
    private var showChats: Bool { true }

    private var hasResults: Bool {
        (showNotes && !results.notes.isEmpty) || (showChats && !results.chats.isEmpty)
    }

    var body: some View {
        if !hasResults {
            emptyState
        } else {
            LazyVStack(alignment: .leading, spacing: 0) {
                if showNotes && results.vaultNoteCount > 0 {
                    vaultSummaryHeader
                }

                if showNotes && !results.notes.isEmpty {
                    sectionHeader("Notes")
                    ForEach(results.notes) { choice in
                        Button { onSelect(.note(choice)) } label: {
                            noteRow(choice)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if showChats && !results.chats.isEmpty {
                    if showNotes && !results.notes.isEmpty {
                        Divider()
                            .padding(.vertical, 4)
                    }
                    sectionHeader("Chats")
                    ForEach(results.chats) { result in
                        Button { onSelect(.chat(result)) } label: {
                            chatRow(result)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(style == .chatPicker ? "No matching conversations" : "No matching notes or chats", systemImage: "sparkle.magnifyingglass")
                .font(.system(size: style == .notePicker ? 13 : 12, weight: .semibold))
                .foregroundStyle(theme.resolved.foreground.color)
            Text(style == .chatPicker
                 ? "Search your past conversations by topic, question, or content."
                 : (results.vaultNoteCount > 0
                    ? "Search checks note titles, folders, tags, and snippets across your vault."
                    : "Attach a vault to browse notes here, or keep typing to search chats."))
                .font(.system(size: style == .notePicker ? 11.5 : 11))
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, style == .notePicker ? 16 : 12)
        .padding(.vertical, style == .notePicker ? 16 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var vaultSummaryHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.resolved.accent.color.opacity(0.9))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(results.vaultTitle ?? "Vault")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.resolved.foreground.color)
                Text(vaultSummaryText)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if !results.isInventoryComplete {
                Text("Partial")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.resolved.foreground.color.opacity(0.06)))
            }
        }
            .padding(.horizontal, style == .notePicker ? 16 : 12)
            .padding(.top, style == .notePicker ? 12 : 10)
            .padding(.bottom, 6)
    }

    private var vaultSummaryText: String {
        if results.query.isEmpty {
            return "Browse \(results.vaultNoteCount) notes or attach the whole vault as context."
        }
        if !results.indexedMatchedNoteIDs.isEmpty {
            return "Matching titles, tags, and \(results.indexedMatchedNoteIDs.count) deep body hits in \(results.vaultNoteCount) notes."
        }
        return "Matching across titles, folders, tags, and snippets in \(results.vaultNoteCount) notes."
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(theme.textTertiary.opacity(0.75))
            .tracking(0.5)
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func noteRow(_ choice: NoteMentionChoice) -> some View {
        switch choice {
        case .allNotes:
            rowChrome {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.resolved.accent.color.opacity(0.9))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.12)))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("All Notes")
                            .font(.system(size: style == .notePicker ? 13 : 12, weight: .semibold))
                            .foregroundStyle(theme.resolved.foreground.color)
                            .lineLimit(1)
                        Text("Use the full vault index for this message.")
                            .font(.system(size: style == .notePicker ? 11.5 : 10.5))
                            .foregroundStyle(theme.textTertiary)
                        if results.vaultNoteCount > 0 {
                            Text("\(results.vaultNoteCount) notes")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(theme.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(theme.resolved.foreground.color.opacity(0.06)))
                        }
                    }
                }
            }

        case .entry(let entry):
            rowChrome {
                HStack(alignment: .top, spacing: 10) {
                    rowIcon(
                        systemName: results.indexedMatchedNoteIDs.contains(entry.pageId)
                            ? "doc.text.magnifyingglass"
                            : "doc.text.fill",
                        tint: results.indexedMatchedNoteIDs.contains(entry.pageId)
                            ? theme.resolved.accent.color.opacity(0.95)
                            : theme.textSecondary
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(entry.title)
                                .font(.system(size: style == .notePicker ? 13.5 : 12.5, weight: .semibold))
                                .foregroundStyle(theme.resolved.foreground.color)
                                .lineLimit(1)
                            if results.indexedMatchedNoteIDs.contains(entry.pageId) {
                                Text("Body Match")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(theme.resolved.accent.color.opacity(0.95))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.16 : 0.10)))
                            }
                        }

                        HStack(spacing: 4) {
                            if let folder = entry.folderName, !folder.isEmpty {
                                Label(folder, systemImage: "folder")
                                    .labelStyle(.titleAndIcon)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(1)
                            }
                            Text(entry.updatedAt.formatted(.relative(presentation: .named)))
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary.opacity(0.7))
                        }

                        if !entry.tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(Array(entry.tags.prefix(3)), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 9.5, weight: .semibold))
                                        .foregroundStyle(theme.textSecondary)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(theme.resolved.foreground.color.opacity(0.06)))
                                }
                            }
                        }

                        if let snippet = displaySnippet(for: entry) {
                            Text(snippet)
                                .font(.system(size: 10.5))
                                .foregroundStyle(theme.textTertiary.opacity(0.88))
                                .lineLimit(results.query.isEmpty ? 1 : 3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func chatRow(_ result: ChatCoordinator.ChatReferenceResult) -> some View {
        rowChrome {
            HStack(alignment: .top, spacing: 10) {
                rowIcon(systemName: "bubble.left.and.bubble.right.fill", tint: theme.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.attachment.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.resolved.foreground.color)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if let subtitle = result.attachment.subtitle {
                            Text(subtitle)
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary)
                        }
                        if let preview = result.preview, !preview.isEmpty {
                            Text(preview)
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private func rowIcon(systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: style == .notePicker ? 13 : 12, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: style == .notePicker ? 28 : 24, height: style == .notePicker ? 28 : 24)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(theme.isDark ? 0.12 : 0.08))
            )
    }

    private func displaySnippet(for entry: VaultManifest.ManifestEntry) -> String? {
        let indexedSnippet = results.indexedNoteSnippetsByPageID[entry.pageId]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if let indexedSnippet, !indexedSnippet.isEmpty {
            return indexedSnippet
        }

        let manifestSnippet = entry.snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        return manifestSnippet.isEmpty ? nil : manifestSnippet
    }

    private func rowChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, style == .notePicker ? 16 : 14)
            .padding(.vertical, style == .notePicker ? 14 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        theme.isDark
                            ? theme.resolved.background.color.opacity(0.94)
                            : Color.white.opacity(0.94)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.glassBorder.opacity(theme.isDark ? 0.20 : 0.12), lineWidth: 0.6)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
