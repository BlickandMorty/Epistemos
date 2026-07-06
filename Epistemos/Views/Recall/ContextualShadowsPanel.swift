import AppKit
import SwiftUI

enum ContextualShadowsPresentation: Equatable {
    case note
    case chat
    case landing

    var compactTitle: String {
        switch self {
        case .note: return "Related"
        case .chat: return "Related Evidence"
        case .landing: return "Instant Recall"
        }
    }

    var compactWidth: CGFloat {
        switch self {
        case .note: return 390
        case .chat: return 520
        case .landing: return 680
        }
    }

    var workspaceWidth: CGFloat {
        switch self {
        case .note: return 690
        case .chat: return 740
        case .landing: return 780
        }
    }

    var maxPanelHeight: CGFloat {
        switch self {
        case .note: return 530
        case .chat: return 610
        case .landing: return 540
        }
    }

    var compactMinHeight: CGFloat {
        switch self {
        case .note: return 200
        case .chat: return 260
        case .landing: return 320
        }
    }

    var compactMaxHeight: CGFloat {
        switch self {
        case .note: return 430
        case .chat: return 500
        case .landing: return 480
        }
    }

    var compactSnippetLineLimit: Int {
        switch self {
        case .note: return 2
        case .chat: return 4
        case .landing: return 5
        }
    }
}

// MARK: - ContextualShadowsPanel
// Ambient recall surface for Halo/Shadow/Eidos-adjacent results. The compact
// panel stays fast while writing; expanded mode becomes a paper workspace that
// loads source bodies on demand and lets the user drag/copy/insert real
// passages without turning recall into a detached Finder-style search.

struct ContextualShadowsPanel: View {
    @Environment(UIState.self) private var ui
    @Environment(ContextualShadowsState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Scope the visible payload to the host surface. Without this, a recall
    /// from landing/chat can bleed into an unrelated note window.
    var scopeKind: RecallContextKind?
    var scopeID: String?
    var presentation: ContextualShadowsPresentation = .note

    /// Caller-provided open routing — the host knows whether to open in the
    /// current window, push a chat thread, etc.
    var onOpen: (ContextualShadowsState.RecallHit) -> Void = { _ in }

    /// Optional editor insertion hook. Note surfaces provide this; chat and
    /// landing can still copy/drag/open without mutating their draft text.
    var onInsert: (String) -> Void = { _ in }

    @State private var selectedTab: RecallContextKind = .note
    @State private var expandedHitID: String?
    @State private var isWorkspaceMode = false
    @State private var selectedPreviewID: String?
    @State private var preview: RecallDocumentPreview?
    @State private var previewTask: Task<Void, Never>?

    private var theme: EpistemosTheme {
        ui.theme
    }

    private var payload: ContextualShadowsState.RecallPayload {
        state.payload(kind: scopeKind, originDocId: scopeID)
    }

    private var noteHits: [ContextualShadowsState.RecallHit] {
        payload.results.filter { $0.kind == .note }
    }

    private var chatHits: [ContextualShadowsState.RecallHit] {
        payload.results.filter { $0.kind == .chat }
    }

    private var effectiveSelectedTab: RecallContextKind {
        if selectedTab == .chat, !chatHits.isEmpty {
            return .chat
        }
        if noteHits.isEmpty, !chatHits.isEmpty {
            return .chat
        }
        return .note
    }

    private var activeHits: [ContextualShadowsState.RecallHit] {
        (effectiveSelectedTab == .note) ? noteHits : chatHits
    }

    var body: some View {
        if state.isEnabled, state.isPanelVisible(kind: scopeKind, originDocId: scopeID) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider().opacity(theme.isDark ? 0.38 : 0.28)
                tabPicker
                Divider().opacity(theme.isDark ? 0.38 : 0.28)
                content
            }
            .frame(width: isWorkspaceMode ? presentation.workspaceWidth : presentation.compactWidth)
            .frame(maxHeight: isWorkspaceMode ? 690 : presentation.maxPanelHeight)
            .recallPanelChrome(theme: theme)
            .shadow(color: .black.opacity(theme.isDark ? 0.30 : 0.14), radius: 18, x: 0, y: 10)
            .transition(reduceMotion ? .identity : .scale(scale: 0.97, anchor: .bottomTrailing).combined(with: .opacity))
            .onDisappear {
                previewTask?.cancel()
                previewTask = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color)
                Text(isWorkspaceMode ? "Recall Workspace" : presentation.compactTitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
                Spacer(minLength: 0)
                Button {
                    toggleWorkspaceMode()
                } label: {
                    Image(systemName: isWorkspaceMode ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isWorkspaceMode ? "Collapse recall workspace" : "Expand recall workspace")
                .accessibilityLabel(isWorkspaceMode ? "Collapse recall workspace" : "Expand recall workspace")

                Button {
                    state.closePanel(kind: scopeKind, originDocId: scopeID)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.textTertiary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close")
                .accessibilityLabel("Close related panel")
            }
            if !payload.queryText.isEmpty {
                Text(payload.queryText)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: - Tabs

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(.note, label: "Notes", count: noteHits.count)
            if !chatHits.isEmpty {
                tabButton(.chat, label: "Chats", count: chatHits.count)
            }
            Spacer(minLength: 0)
            if isWorkspaceMode, let preview {
                Text("\(preview.paragraphs.count) passages")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private func tabButton(_ kind: RecallContextKind, label: String, count: Int) -> some View {
        Button {
            selectedTab = kind
            if isWorkspaceMode {
                selectFirstHitIfNeeded(force: true)
            }
        } label: {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 11.5, weight: effectiveSelectedTab == kind ? .semibold : .regular, design: .rounded))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .foregroundStyle(effectiveSelectedTab == kind ? theme.textPrimary : theme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Rectangle()
                    .fill(effectiveSelectedTab == kind
                          ? theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.12)
                          : Color.clear)
            )
            .overlay {
                Rectangle()
                    .stroke(
                        effectiveSelectedTab == kind
                            ? theme.resolved.accent.color.opacity(theme.isDark ? 0.36 : 0.24)
                            : Color.clear,
                        lineWidth: 1
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) tab, \(count) results")
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let hits = activeHits
        if hits.isEmpty, let error = payload.errorMessage {
            unavailableContent(error)
        } else if hits.isEmpty, payload.isSearching {
            searchingContent
        } else if hits.isEmpty {
            emptyContent
        } else if isWorkspaceMode {
            workspaceContent(hits: hits)
                .onAppear {
                    selectFirstHitIfNeeded(force: false)
                }
        } else {
            compactContent(hits: hits)
        }
    }

    private func compactContent(hits: [ContextualShadowsState.RecallHit]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 5) {
                ForEach(hits) { hit in
                    let hitID = Self.key(for: hit)
                    RecallHitRow(
                        hit: hit,
                        theme: theme,
                        presentation: presentation,
                        isExpanded: expandedHitID == hitID,
                        onToggle: {
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                                expandedHitID = (expandedHitID == hitID) ? nil : hitID
                            }
                        },
                        onPreview: {
                            openWorkspace(for: hit)
                        },
                        onOpen: {
                            onOpen(hit)
                        }
                    )
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 7)
        }
        .frame(minHeight: presentation.compactMinHeight, maxHeight: presentation.compactMaxHeight)
        .onChange(of: payload.queryText) { _, _ in
            expandedHitID = nil
            selectedPreviewID = nil
            preview = nil
        }
    }

    private func workspaceContent(hits: [ContextualShadowsState.RecallHit]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            workspaceHitList(hits: hits)
                .frame(width: 220)
            Divider().opacity(theme.isDark ? 0.38 : 0.28)
            RecallPreviewPane(
                preview: preview,
                isLoading: previewTask != nil && preview == nil,
                theme: theme,
                onOpen: {
                    if let hit = selectedHit(in: hits) {
                        onOpen(hit)
                    }
                },
                onCopy: copyToPasteboard,
                onInsert: onInsert
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 430, maxHeight: 620)
        .onChange(of: payload.queryText) { _, _ in
            selectedPreviewID = nil
            preview = nil
            selectFirstHitIfNeeded(force: true)
        }
    }

    private func workspaceHitList(hits: [ContextualShadowsState.RecallHit]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(hits) { hit in
                    let isSelected = selectedPreviewID == Self.key(for: hit)
                    Button {
                        loadPreview(for: hit)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: hit.kind == .note ? "note.text" : "message")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(theme.resolved.accent.color)
                                Text(hit.title)
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(theme.textPrimary)
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                            }
                            if !hit.snippet.isEmpty {
                                Text(hit.snippet)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(theme.textSecondary)
                                    .lineLimit(2)
                            }
                            HStack(spacing: 5) {
                                Text(hit.source.isEmpty ? "recall" : hit.source)
                                    .lineLimit(1)
                                Text(String(format: "%.0f%%", min(max(hit.similarity, 0), 1) * 100))
                                    .monospacedDigit()
                            }
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(theme.textTertiary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Rectangle()
                                .fill(isSelected
                                      ? theme.resolved.accent.color.opacity(theme.isDark ? 0.18 : 0.12)
                                      : PixelPanelBackground.actionSurface(for: theme).opacity(0.78))
                        )
                        .overlay {
                            Rectangle()
                                .stroke(
                                    isSelected
                                        ? theme.resolved.accent.color.opacity(theme.isDark ? 0.38 : 0.26)
                                        : theme.textPrimary.opacity(theme.isDark ? 0.10 : 0.14),
                                    lineWidth: 1
                                )
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(hit.snippet.isEmpty ? hit.title : hit.snippet)
                }
            }
            .padding(8)
        }
    }

    private func unavailableContent(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
                Text("Shadow backend unavailable")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
            }
            Text(error)
                .font(.system(size: 11))
                .foregroundStyle(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyContent: some View {
        VStack {
            Spacer()
            Text("No matches")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 96)
    }

    private var searchingContent: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Searching current text")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 96)
    }

    // MARK: - Preview Loading

    private func toggleWorkspaceMode() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            isWorkspaceMode.toggle()
        }
        if isWorkspaceMode {
            selectFirstHitIfNeeded(force: false)
        }
    }

    private func openWorkspace(for hit: ContextualShadowsState.RecallHit) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            isWorkspaceMode = true
        }
        loadPreview(for: hit)
    }

    private func selectFirstHitIfNeeded(force: Bool) {
        guard force || selectedPreviewID == nil else { return }
        guard let first = activeHits.first else { return }
        loadPreview(for: first)
    }

    private func selectedHit(in hits: [ContextualShadowsState.RecallHit]) -> ContextualShadowsState.RecallHit? {
        guard let selectedPreviewID else { return nil }
        return hits.first { Self.key(for: $0) == selectedPreviewID }
    }

    private func loadPreview(for hit: ContextualShadowsState.RecallHit) {
        let hitID = Self.key(for: hit)
        selectedPreviewID = hitID
        preview = nil
        previewTask?.cancel()
        previewTask = Task { @MainActor in
            let body: String
            switch hit.kind {
            case .note:
                body = NoteWindowManager.shared.currentBody(for: hit.id, mapped: true)
            case .chat:
                body = hit.snippet
            }
            guard !Task.isCancelled else { return }
            preview = RecallDocumentPreview(hit: hit, hitID: hitID, body: body)
            previewTask = nil
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private static func key(for hit: ContextualShadowsState.RecallHit) -> String {
        "\(hit.kind.rawValue):\(hit.id)"
    }
}

private struct RecallPanelChromeModifier: ViewModifier {
    let theme: EpistemosTheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        content
            .background {
                ZStack(alignment: .top) {
                    shape.fill(.regularMaterial)
                    shape.fill(theme.card.opacity(theme.isDark ? 0.82 : 0.9))
                    LinearGradient(
                        colors: [
                            Color.white.opacity(theme.isDark ? 0.07 : 0.3),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(shape)
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(theme.border.opacity(theme.isDark ? 0.52 : 0.34), lineWidth: 0.8)
            }
    }
}

private extension View {
    func recallPanelChrome(theme: EpistemosTheme) -> some View {
        modifier(RecallPanelChromeModifier(theme: theme))
    }
}

// MARK: - Recall Preview Model

private struct RecallDocumentPreview: Equatable {
    let hitID: String
    let title: String
    let source: String
    let body: String
    let paragraphs: [RecallParagraph]
    let outline: [RecallOutlineItem]

    init(hit: ContextualShadowsState.RecallHit, hitID: String, body: String) {
        let fallbackBody = hit.snippet.isEmpty ? hit.title : hit.snippet
        let normalizedBody = body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? fallbackBody
            : body
        self.hitID = hitID
        title = hit.title
        source = hit.source
        self.body = normalizedBody
        paragraphs = Self.extractParagraphs(from: normalizedBody, hitID: hitID)
        outline = Self.extractOutline(from: normalizedBody, hitID: hitID)
    }

    var outlineClipboardText: String {
        outline
            .map { String(repeating: "#", count: $0.level) + " " + $0.title }
            .joined(separator: "\n")
    }

    var passagesClipboardText: String {
        paragraphs
            .map { $0.text }
            .joined(separator: "\n\n")
    }

    private static func extractParagraphs(from body: String, hitID: String) -> [RecallParagraph] {
        let normalized = body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var blocks: [String] = []
        var current: [String] = []

        func flush() {
            let text = current
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(text)
            }
            current.removeAll(keepingCapacity: true)
        }

        for line in normalized.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                flush()
            } else {
                current.append(line)
            }
        }
        flush()

        if blocks.count <= 1 {
            blocks = normalized
                .components(separatedBy: ". ")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { $0.hasSuffix(".") ? $0 : "\($0)." }
        }

        return blocks
            .filter { block in
                let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.hasPrefix("#") && trimmed.count >= 24
            }
            .prefix(10)
            .enumerated()
            .map { offset, block in
                RecallParagraph(
                    id: "\(hitID):p\(offset)",
                    index: offset + 1,
                    text: block.truncatedForRecall(maxLength: 900)
                )
            }
    }

    private static func extractOutline(from body: String, hitID: String) -> [RecallOutlineItem] {
        body
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .compactMap { line -> (Int, String)? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("#") else { return nil }
                let level = trimmed.prefix { $0 == "#" }.count
                guard (1...3).contains(level) else { return nil }
                let title = trimmed.dropFirst(level)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { return nil }
                return (level, title)
            }
            .prefix(8)
            .enumerated()
            .map { offset, item in
                RecallOutlineItem(
                    id: "\(hitID):h\(offset)",
                    level: item.0,
                    title: item.1
                )
            }
    }
}

private struct RecallParagraph: Identifiable, Equatable {
    let id: String
    let index: Int
    let text: String
}

private struct RecallOutlineItem: Identifiable, Equatable {
    let id: String
    let level: Int
    let title: String
}

private extension String {
    func truncatedForRecall(maxLength: Int) -> String {
        guard count > maxLength else { return self }
        let end = index(startIndex, offsetBy: maxLength)
        return "\(self[..<end].trimmingCharacters(in: .whitespacesAndNewlines))..."
    }
}

// MARK: - RecallHitRow

private struct RecallHitRow: View {
    let hit: ContextualShadowsState.RecallHit
    let theme: EpistemosTheme
    let presentation: ContextualShadowsPresentation
    let isExpanded: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(hit.title)
                            .font(.system(size: presentation == .note ? 12.5 : 13.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(presentation == .note ? 1 : 2)
                        Spacer(minLength: 0)
                        if !hit.source.isEmpty {
                            chip(hit.source, tint: theme.textTertiary)
                        }
                        Text(String(format: "%.0f%%", min(max(hit.similarity, 0), 1) * 100))
                            .font(.system(size: 9.5, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(theme.textTertiary)
                    }
                    if !hit.snippet.isEmpty {
                        Text(hit.snippet)
                            .font(.system(size: presentation == .note ? 11.5 : 12.5))
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(isExpanded ? 7 : presentation.compactSnippetLineLimit)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                HStack(spacing: 8) {
                    Button {
                        onPreview()
                    } label: {
                        Label("Preview", systemImage: "rectangle.split.2x1")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onOpen()
                    } label: {
                        Label(hit.kind == .note ? "Open Note" : "Open Chat", systemImage: "arrow.up.forward.square")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)

                    Spacer(minLength: 0)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, presentation == .note ? 9 : 11)
        .padding(.vertical, presentation == .note ? 7 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Rectangle()
                .fill(PixelPanelBackground.actionSurface(for: theme).opacity(isExpanded ? 0.96 : 0.76))
        )
        .overlay {
            Rectangle()
                .stroke(theme.textPrimary.opacity(theme.isDark ? 0.10 : 0.14), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .help(hit.snippet.isEmpty ? hit.title : hit.snippet)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(hit.title), \(hit.kind.rawValue) result from \(hit.source)")
        .accessibilityHint(isExpanded ? "Preview or open this \(hit.kind.rawValue)" : "Expand this related item")
    }

    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .medium))
            .lineLimit(1)
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Rectangle()
                    .fill(tint.opacity(0.12))
            )
    }
}

// MARK: - RecallPreviewPane

private struct RecallPreviewPane: View {
    let preview: RecallDocumentPreview?
    let isLoading: Bool
    let theme: EpistemosTheme
    let onOpen: () -> Void
    let onCopy: (String) -> Void
    let onInsert: (String) -> Void

    var body: some View {
        Group {
            if let preview {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        previewHeader(preview)
                        if !preview.outline.isEmpty {
                            outlineSection(preview.outline)
                        }
                        paragraphSection(preview.paragraphs)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 10) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(isLoading ? "Loading source..." : "Select a recall item")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func previewHeader(_ preview: RecallDocumentPreview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(preview.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(3)
                    if !preview.source.isEmpty {
                        Text(preview.source)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                Spacer(minLength: 0)
                if !preview.outline.isEmpty {
                    Button {
                        onCopy(preview.outlineClipboardText)
                    } label: {
                        Label("Outline", systemImage: "list.bullet.indent")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .help("Copy outline")
                }
                if !preview.paragraphs.isEmpty {
                    Button {
                        onCopy(preview.passagesClipboardText)
                    } label: {
                        Label("Passages", systemImage: "text.justify.left")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .help("Copy all visible passages")
                }
                Button {
                    onOpen()
                } label: {
                    Label("Open", systemImage: "arrow.up.forward.square")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
            }
            Text("Drag a passage into the note, or use Insert to quote it at the cursor.")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func outlineSection(_ outline: [RecallOutlineItem]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionLabel("Outline")
            FlowLayout(spacing: 6) {
                ForEach(outline) { item in
                    Text(String(repeating: "#", count: item.level) + " " + item.title)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(Rectangle().fill(PixelPanelBackground.actionSurface(for: theme).opacity(0.8)))
                        .overlay {
                            Rectangle()
                                .stroke(theme.textPrimary.opacity(theme.isDark ? 0.10 : 0.14), lineWidth: 1)
                        }
                }
            }
        }
    }

    private func paragraphSection(_ paragraphs: [RecallParagraph]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Passages")
            if paragraphs.isEmpty {
                Text("No paragraph-sized passages available for this result.")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Rectangle().fill(PixelPanelBackground.actionSurface(for: theme).opacity(0.75)))
            } else {
                ForEach(paragraphs) { paragraph in
                    paragraphCard(paragraph)
                }
            }
        }
    }

    private func paragraphCard(_ paragraph: RecallParagraph) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text("P\(paragraph.index)")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.resolved.accent.color)
                Spacer(minLength: 0)
                Button {
                    onCopy(paragraph.text)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .buttonStyle(.bordered)
                Button {
                    onInsert(paragraph.text)
                } label: {
                    Label("Insert", systemImage: "text.insert")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.resolved.accent.color)
            }
            Text(paragraph.text)
                .font(.system(size: 12))
                .foregroundStyle(theme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Rectangle().fill(PixelPanelBackground.actionSurface(for: theme).opacity(0.84)))
        .overlay {
            Rectangle()
                .stroke(theme.textPrimary.opacity(theme.isDark ? 0.10 : 0.14), lineWidth: 1)
        }
        .draggable(paragraph.text)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(theme.textTertiary)
            .tracking(0.8)
    }
}
