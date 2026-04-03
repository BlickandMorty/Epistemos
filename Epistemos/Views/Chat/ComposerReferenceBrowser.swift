import SwiftData
import SwiftUI

enum ComposerAttachmentEntryHints {
    static let notesAndChats = "Type @ for notes or chats"
    static let mainChatPlaceholder = "Ask anything… \(notesAndChats)"
    static let landingPlaceholder = "Ask Epistemos… \(notesAndChats)"
}

struct ComposerReferenceBrowserPageItem: Identifiable {
    let entry: VaultManifest.ManifestEntry
    let emoji: String
    let isJournal: Bool
    let isPinned: Bool
    let folderId: String?
    let subfolder: String?

    var id: String { entry.pageId }
}

struct ComposerReferenceBrowserFolderItem: Identifiable, Equatable {
    let id: String
    let name: String
    let isCollection: Bool
    let sortOrder: Int
    let parentId: String?
    let relativePath: String
    var childFolderIds: [String]
    var childPageIds: [String]
    var descendantPageCount: Int
}

struct ComposerReferenceBrowserInventory {
    var pageById: [String: ComposerReferenceBrowserPageItem] = [:]
    var folderById: [String: ComposerReferenceBrowserFolderItem] = [:]
    var rootFolderIDs: [String] = []
    var childFolderIDsByID: [String: [String]] = [:]
    var pageIDsByFolderID: [String: [String]] = [:]
    var loosePageIDs: [String] = []
    var pinnedPageIDs: [String] = []

    static let empty = ComposerReferenceBrowserInventory()

    var isEmpty: Bool {
        pageById.isEmpty && folderById.isEmpty
    }
}

enum ComposerReferenceBrowserInventoryBuilder {
    static func build(
        manifestEntriesByPageID: [String: VaultManifest.ManifestEntry],
        pages: [SDPage],
        folders: [SDFolder]
    ) -> ComposerReferenceBrowserInventory {
        let uniquePages = uniqueActivePages(from: pages)
        let uniqueFolders = uniqueFoldersById(from: folders)

        var pageItems: [ComposerReferenceBrowserPageItem] = uniquePages.map { page in
            ComposerReferenceBrowserPageItem(
                entry: manifestEntriesByPageID[page.id] ?? synthesizedEntry(for: page),
                emoji: page.emoji,
                isJournal: page.isJournal,
                isPinned: page.isPinned,
                folderId: page.folder?.id,
                subfolder: page.subfolder
            )
        }
        pageItems.sort(by: pageSort)

        var pageById: [String: ComposerReferenceBrowserPageItem] = [:]
        pageById.reserveCapacity(pageItems.count)
        for page in pageItems {
            pageById[page.id] = page
        }

        var folderItems: [ComposerReferenceBrowserFolderItem] = uniqueFolders.map {
            ComposerReferenceBrowserFolderItem(
                id: $0.id,
                name: $0.name,
                isCollection: $0.isCollection,
                sortOrder: $0.sortOrder,
                parentId: $0.parent?.id,
                relativePath: $0.relativePath,
                childFolderIds: [],
                childPageIds: [],
                descendantPageCount: 0
            )
        }
        folderItems.sort { lhs, rhs in
            if lhs.isCollection != rhs.isCollection {
                return lhs.isCollection && !rhs.isCollection
            }
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        var childFolderIDsByID: [String: [String]] = [:]
        var folderByPath: [String: String] = [:]
        folderByPath.reserveCapacity(folderItems.count)
        for folder in uniqueFolders {
            folderByPath[folder.relativePath] = folder.id
        }

        for folder in uniqueFolders {
            let childIDs = (folder.children ?? [])
                .sorted { lhs, rhs in
                    if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                .map(\.id)
            childFolderIDsByID[folder.id] = childIDs
        }

        var pageIDsByFolderID: [String: [String]] = [:]
        for page in pageItems {
            if let folderID = page.folderId {
                pageIDsByFolderID[folderID, default: []].append(page.id)
                continue
            }
            if let subfolder = page.subfolder,
               let folderID = folderByPath[subfolder] {
                pageIDsByFolderID[folderID, default: []].append(page.id)
            }
        }

        for key in pageIDsByFolderID.keys {
            pageIDsByFolderID[key]?.sort { lhs, rhs in
                guard let lhsPage = pageById[lhs], let rhsPage = pageById[rhs] else { return lhs < rhs }
                return pageSort(lhsPage, rhsPage)
            }
        }

        let descendantCounts = NotesSidebarFolderMetrics.descendantPageCounts(
            folderIds: folderItems.map(\.id),
            childFolderIdsById: childFolderIDsByID,
            pageIdsByFolderId: pageIDsByFolderID
        )

        var folderById: [String: ComposerReferenceBrowserFolderItem] = [:]
        folderById.reserveCapacity(folderItems.count)
        for var folder in folderItems {
            folder.childFolderIds = childFolderIDsByID[folder.id] ?? []
            folder.childPageIds = pageIDsByFolderID[folder.id] ?? []
            folder.descendantPageCount = descendantCounts[folder.id] ?? folder.childPageIds.count
            folderById[folder.id] = folder
        }

        let rootFolderIDs = folderItems
            .filter { $0.parentId == nil }
            .map(\.id)

        let attachedPageIDs = Set(pageIDsByFolderID.values.flatMap { $0 })
        let loosePageIDs = pageItems
            .map(\.id)
            .filter { !attachedPageIDs.contains($0) }

        let pinnedPageIDs = pageItems
            .filter(\.isPinned)
            .map(\.id)

        return ComposerReferenceBrowserInventory(
            pageById: pageById,
            folderById: folderById,
            rootFolderIDs: rootFolderIDs,
            childFolderIDsByID: childFolderIDsByID,
            pageIDsByFolderID: pageIDsByFolderID,
            loosePageIDs: loosePageIDs,
            pinnedPageIDs: pinnedPageIDs
        )
    }

    private static func uniqueActivePages(from pages: [SDPage]) -> [SDPage] {
        var pageByID: [String: SDPage] = [:]
        for page in pages where !page.isArchived {
            if let existing = pageByID[page.id] {
                if page.updatedAt > existing.updatedAt {
                    pageByID[page.id] = page
                }
            } else {
                pageByID[page.id] = page
            }
        }
        return Array(pageByID.values)
    }

    private static func uniqueFoldersById(from folders: [SDFolder]) -> [SDFolder] {
        var folderByID: [String: SDFolder] = [:]
        for folder in folders {
            folderByID[folder.id] = folder
        }
        return Array(folderByID.values)
    }

    private static func synthesizedEntry(for page: SDPage) -> VaultManifest.ManifestEntry {
        VaultManifest.ManifestEntry(
            pageId: page.id,
            title: page.title,
            tags: page.tags,
            folderName: page.folder?.name ?? page.subfolder,
            wordCount: page.wordCount,
            snippet: page.summary.isEmpty ? page.title : page.summary,
            updatedAt: page.updatedAt,
            createdAt: page.createdAt
        )
    }

    private static func pageSort(
        _ lhs: ComposerReferenceBrowserPageItem,
        _ rhs: ComposerReferenceBrowserPageItem
    ) -> Bool {
        if lhs.entry.updatedAt != rhs.entry.updatedAt {
            return lhs.entry.updatedAt > rhs.entry.updatedAt
        }
        return lhs.entry.title.localizedCaseInsensitiveCompare(rhs.entry.title) == .orderedAscending
    }
}

struct ComposerReferenceBrowseList: View {
    let inventory: ComposerReferenceBrowserInventory
    let results: ChatCoordinator.ReferenceSearchResults
    let onSelect: (ComposerReferenceChoice) -> Void

    @Environment(UIState.self) private var ui
    @State private var expandedFolderIDs: Set<String> = []

    private var theme: EpistemosTheme { ui.theme }
    private var visibleRows: [NotesSidebarVisibleTreeEntry] {
        NotesSidebarVisibleTreeBuilder.build(
            rootFolderIds: inventory.rootFolderIDs,
            expandedFolderIds: expandedFolderIDs,
            childFolderIdsById: inventory.childFolderIDsByID,
            pageIdsByFolderId: inventory.pageIDsByFolderID
        )
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            allNotesRow

            if !results.chats.isEmpty {
                sectionHeader("Chats")
                ForEach(results.chats) { result in
                    Button { onSelect(.chat(result)) } label: {
                        chatRow(result)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !inventory.pinnedPageIDs.isEmpty {
                sectionHeader("Pinned")
                ForEach(inventory.pinnedPageIDs, id: \.self) { pageID in
                    if let page = inventory.pageById[pageID] {
                        noteRow(page, indent: 0)
                    }
                }
            }

            if !inventory.rootFolderIDs.isEmpty {
                sectionHeader("Files")
                ForEach(visibleRows, id: \.self) { row in
                    browseRow(row)
                }
            }

            if !inventory.loosePageIDs.isEmpty {
                if inventory.rootFolderIDs.isEmpty {
                    sectionHeader("Files")
                } else {
                    sectionHeader("Loose Notes")
                }
                ForEach(inventory.loosePageIDs, id: \.self) { pageID in
                    if let page = inventory.pageById[pageID] {
                        noteRow(page, indent: 0)
                    }
                }
            }

            if inventory.isEmpty && results.chats.isEmpty {
                emptyState
            }
        }
        .onAppear {
            if expandedFolderIDs.isEmpty {
                expandedFolderIDs = Set(inventory.rootFolderIDs)
            }
        }
        .onChange(of: inventory.rootFolderIDs) { _, newValue in
            guard !newValue.isEmpty, expandedFolderIDs.isEmpty else { return }
            expandedFolderIDs = Set(newValue)
        }
    }

    private var allNotesRow: some View {
        Button {
            onSelect(.note(.allNotes))
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.resolved.accent.color.opacity(0.9))
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text("All Notes")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(theme.resolved.foreground.color)
                    Text(
                        results.vaultNoteCount > 0
                            ? "Attach retrieval across \(results.vaultNoteCount) notes."
                            : "Attach the full vault retrieval index."
                    )
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.textTertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.resolved.accent.color.opacity(theme.isDark ? 0.11 : 0.08))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(theme.resolved.accent.color.opacity(0.14), lineWidth: 0.6)
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 4)
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(theme.textTertiary.opacity(0.75))
            .tracking(0.5)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func browseRow(_ row: NotesSidebarVisibleTreeEntry) -> some View {
        switch row {
        case let .folder(id, indent):
            if let folder = inventory.folderById[id] {
                folderRow(folder, indent: indent)
            }
        case let .page(id, indent):
            if let page = inventory.pageById[id] {
                noteRow(page, indent: indent)
            }
        case let .emptyFolder(id, indent):
            if inventory.folderById[id] != nil {
                Text("Empty folder")
                    .font(.system(size: 10.5))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.leading, CGFloat(indent) * 16 + 28)
                    .padding(.vertical, 4)
            }
        }
    }

    private func folderRow(
        _ folder: ComposerReferenceBrowserFolderItem,
        indent: Int
    ) -> some View {
        Button {
            toggle(folderID: folder.id)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
                    .rotationEffect(.degrees(expandedFolderIDs.contains(folder.id) ? 90 : 0))
                    .frame(width: 10)

                Image(systemName: folder.isCollection ? "tray.full.fill" : "folder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.resolved.accent.color.opacity(folder.isCollection ? 0.95 : 0.8))
                    .frame(width: 14)

                Text(folder.name.isEmpty ? "Untitled Folder" : folder.name)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.9))
                    .lineLimit(1)

                Spacer(minLength: 0)

                if folder.descendantPageCount > 0 {
                    Text("\(folder.descendantPageCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.textTertiary)
                        .monospacedDigit()
                }
            }
            .padding(.leading, CGFloat(indent) * 16 + 12)
            .padding(.trailing, 10)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    private func noteRow(
        _ page: ComposerReferenceBrowserPageItem,
        indent: Int
    ) -> some View {
        Button {
            onSelect(.note(.entry(page.entry)))
        } label: {
            HStack(spacing: 6) {
                if !page.emoji.isEmpty {
                    Text(page.emoji)
                        .font(.system(size: 11))
                        .frame(width: 14)
                } else {
                    Image(systemName: page.isJournal ? "calendar" : "doc.text")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.textSecondary.opacity(0.8))
                        .frame(width: 14)
                }

                Text(page.entry.title.isEmpty ? "Untitled" : page.entry.title)
                    .font(.system(size: 12, weight: page.isPinned ? .semibold : .regular))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.86))
                    .lineLimit(1)

                Spacer(minLength: 0)

                if page.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.resolved.accent.color.opacity(0.8))
                }
            }
            .padding(.leading, CGFloat(indent) * 16 + 12)
            .padding(.trailing, 10)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    private func chatRow(_ result: ChatCoordinator.ChatReferenceResult) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.textSecondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.attachment.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(theme.resolved.foreground.color.opacity(0.9))
                    .lineLimit(1)

                if let preview = result.preview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                } else if let subtitle = result.attachment.subtitle {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No notes or chats yet", systemImage: "sparkle.magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.resolved.foreground.color)
            Text("Type @ and search, or attach the full vault when it’s available.")
                .font(.system(size: 10.5))
                .foregroundStyle(theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func toggle(folderID: String) {
        if expandedFolderIDs.contains(folderID) {
            expandedFolderIDs.remove(folderID)
        } else {
            expandedFolderIDs.insert(folderID)
        }
    }
}
