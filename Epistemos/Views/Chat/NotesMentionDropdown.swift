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
}

@MainActor @Observable
final class ComposerReferenceSearchState {
    var indexedNoteIDs: [String] = []
    var indexedNoteSnippetsByPageID: [String: String] = [:]

    @ObservationIgnored
    private var searchTask: Task<Void, Never>?

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

        let manifestPageIDs = Set(manifest.entries.map(\.pageId))
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
    let vaultLabel: String
    let onChatWithNote: () -> Void
    let onChatWithVault: () -> Void

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 8) {
            actionButton(
                title: noteLabel,
                icon: "doc.text.magnifyingglass",
                action: onChatWithNote
            )
            actionButton(
                title: vaultLabel,
                icon: "books.vertical",
                action: onChatWithVault
            )
            Spacer(minLength: 0)
        }
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

struct ComposerReferencePopover: View {
    let results: ChatCoordinator.ReferenceSearchResults
    let onSelect: (ComposerReferenceChoice) -> Void
    let idealWidth: CGFloat
    let maxHeight: CGFloat
    @Binding private var query: String
    private let autofocusSearchField: Bool

    @FocusState private var isSearchFocused: Bool

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    init(
        results: ChatCoordinator.ReferenceSearchResults,
        query: Binding<String>,
        idealWidth: CGFloat = 428,
        maxHeight: CGFloat = 360,
        autofocusSearchField: Bool = false,
        onSelect: @escaping (ComposerReferenceChoice) -> Void
    ) {
        self.results = results
        _query = query
        self.onSelect = onSelect
        self.idealWidth = idealWidth
        self.maxHeight = maxHeight
        self.autofocusSearchField = autofocusSearchField
    }

    var body: some View {
        GeometryReader { proxy in
            let anchorFrame = proxy.frame(in: .global)
            let screenFrame = screenFrame(containing: anchorFrame) ?? CGRect(
                x: 0,
                y: 0,
                width: max(idealWidth + (ComposerReferencePopoverLayout.screenInset * 2), proxy.size.width),
                height: 900
            )
            let width = ComposerReferencePopoverLayout.resolvedWidth(
                idealWidth: idealWidth,
                anchorFrame: anchorFrame,
                screenFrame: screenFrame
            )
            let horizontalOffset = ComposerReferencePopoverLayout.horizontalOffset(
                width: width,
                anchorFrame: anchorFrame,
                screenFrame: screenFrame
            )

            VStack(alignment: .leading, spacing: 0) {
                popoverHeader
                popoverSearchField
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                Divider()
                    .overlay(theme.glassBorder.opacity(theme.isDark ? 0.45 : 0.28))

                ScrollView(.vertical, showsIndicators: false) {
                    NotesMentionDropdown(
                        results: results,
                        onSelect: onSelect
                    )
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: maxHeight - 62, alignment: .topLeading)

                if results.vaultNoteCount > 0 {
                    Divider()
                        .overlay(theme.glassBorder.opacity(theme.isDark ? 0.4 : 0.24))
                    footerHint
                }
            }
            .frame(width: width, alignment: .topLeading)
            .frame(maxHeight: maxHeight, alignment: .topLeading)
            .assistantPopoverChrome(theme: theme)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(theme.isDark ? 0.04 : 0.18))
                    .frame(height: 1)
                    .padding(.horizontal, 18)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .offset(x: horizontalOffset, y: 8)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .task(id: autofocusSearchField) {
                guard autofocusSearchField else { return }
                try? await Task.sleep(for: .milliseconds(60))
                isSearchFocused = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: maxHeight + 12, alignment: .topLeading)
    }

    private var popoverHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: results.query.isEmpty ? "books.vertical.fill" : "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.accent.opacity(0.92))
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(theme.accent.opacity(theme.isDark ? 0.18 : 0.10))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(results.query.isEmpty ? "Browse Note Context" : "Search Notes and Chats")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(theme.foreground)
                Text(popoverSubtitle)
                    .font(.system(size: 10.5, weight: .medium))
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
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var popoverSubtitle: String {
        if results.query.isEmpty {
            return "Attach a note, search your vault, or bring the whole index into this turn."
        }
        return "Searching titles, folders, tags, and body excerpts for “\(results.query)”."
    }

    private var popoverSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            TextField(
                "Search notes, chats, tags, folders, and snippets",
                text: $query
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12.5, weight: .medium, design: .rounded))
            .foregroundStyle(theme.foreground)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .assistantInsetChrome(
            theme: theme,
            cornerRadius: 16,
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

    private var resultCount: Int {
        results.notes.count + results.chats.count
    }

    private func screenFrame(containing anchorFrame: CGRect) -> CGRect? {
        NSScreen.screens.first(where: { $0.visibleFrame.intersects(anchorFrame) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
    }
}

// MARK: - Notes Mention Dropdown
// Floating dropdown triggered by @ in ChatInputBar during Notes Mode.
// Shows filtered note titles from the in-memory VaultManifest.

struct NotesMentionDropdown: View {
    let results: ChatCoordinator.ReferenceSearchResults
    let onSelect: (ComposerReferenceChoice) -> Void

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        if results.notes.isEmpty && results.chats.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if results.vaultNoteCount > 0 {
                    vaultSummaryHeader
                }

                if !results.notes.isEmpty {
                    sectionHeader("Notes")
                    ForEach(results.notes) { choice in
                        Button { onSelect(.note(choice)) } label: {
                            noteRow(choice)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !results.chats.isEmpty {
                    if !results.notes.isEmpty {
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
            Label("No matching notes or chats", systemImage: "sparkle.magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.foreground)
            Text(results.vaultNoteCount > 0
                 ? "Search checks note titles, folders, tags, and snippets across your vault."
                 : "Attach a vault to browse notes here, or keep typing to search chats.")
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var vaultSummaryHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.accent.opacity(0.9))
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(theme.accent.opacity(theme.isDark ? 0.18 : 0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(results.vaultTitle ?? "Vault")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.foreground)
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
                    .background(Capsule().fill(theme.foreground.opacity(0.06)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
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
                        .foregroundStyle(theme.accent.opacity(0.9))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(theme.accent.opacity(theme.isDark ? 0.18 : 0.12)))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("All Notes")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                            .lineLimit(1)
                        Text("Use the full vault index for this message.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(theme.textTertiary)
                        if results.vaultNoteCount > 0 {
                            Text("\(results.vaultNoteCount) notes")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(theme.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(theme.foreground.opacity(0.06)))
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
                            ? theme.accent.opacity(0.95)
                            : theme.textSecondary
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(entry.title)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(theme.foreground)
                                .lineLimit(1)
                            if results.indexedMatchedNoteIDs.contains(entry.pageId) {
                                Text("Body Match")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundStyle(theme.accent.opacity(0.95))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(theme.accent.opacity(theme.isDark ? 0.16 : 0.10)))
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
                                        .background(Capsule().fill(theme.foreground.opacity(0.06)))
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
                        .foregroundStyle(theme.foreground)
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
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 24, height: 24)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.foreground.opacity(theme.isDark ? 0.08 : 0.045))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(theme.glassBorder.opacity(theme.isDark ? 0.32 : 0.20), lineWidth: 0.75)
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(theme.isDark ? 0.04 : 0.16))
                            .frame(height: 1)
                            .padding(.horizontal, 12)
                            .padding(.top, 1)
                    }
            )
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
