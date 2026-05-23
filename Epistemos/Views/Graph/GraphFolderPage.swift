import SwiftUI
import SwiftData

// MARK: - Graph Folder Page (Phase 7 Step 5)
//
// Graph-native folder surface: resolves an `SDFolder` by the id carried in a
// `GraphWorkspaceRoute.folder(id:)` and renders its direct children + pages
// as a clickable list. Clicking a subfolder calls `graphState.openFolder`
// which pushes a new `.folder` route onto the existing Finder-style back
// stack, so nested folder navigation is automatic.
//
// Minimum-viable Step 5 scope:
//   - list view only (no thumbnail toggle yet)
//   - no lazy body loads (pages are rendered by title only)
//   - no explicit Table of Contents pane (the full list IS the TOC)
//
// Thumbnail grid, TOC sidebar, and folder metadata/emoji chrome are tracked
// for later refinement. Nested navigation works today via the back stack.

struct GraphFolderPage: View {
    let folderId: String
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }

    @Query private var folders: [SDFolder]

    @MainActor
    init(folderId: String) {
        self.folderId = folderId
        _folders = Query(filter: #Predicate<SDFolder> { $0.id == folderId })
    }

    var body: some View {
        if let folder = folders.first {
            folderListing(folder)
        } else {
            notFoundFallback
        }
    }

    private func folderListing(_ folder: SDFolder) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(folder)

                if let children = folder.children, !children.isEmpty {
                    section(title: "Subfolders") {
                        ForEach(children.sorted { $0.name < $1.name }) { child in
                            subfolderRow(child)
                        }
                    }
                }

                if let pages = folder.pages?.filter({ !$0.isArchived }),
                   !pages.isEmpty {
                    section(title: "Notes") {
                        ForEach(pages.sorted { $0.title < $1.title }) { page in
                            pageRow(page)
                        }
                    }
                }

                if (folder.children?.isEmpty ?? true)
                    && (folder.pages?.filter({ !$0.isArchived }).isEmpty ?? true) {
                    Text("This folder is empty.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.smallCaps())
                .foregroundStyle(.secondary)
            VStack(spacing: 2) {
                content()
            }
        }
    }

    private func header(_ folder: SDFolder) -> some View {
        HStack(spacing: 10) {
            if !folder.emoji.isEmpty {
                Text(folder.emoji)
                    .font(.system(size: 28))
            } else {
                Image(systemName: "folder")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.name.isEmpty ? "Untitled Folder" : folder.name)
                    .font(.title2.weight(.semibold))
                let path = folder.relativePath
                if path.contains("/") {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func subfolderRow(_ child: SDFolder) -> some View {
        Button {
            graphState.openFolder(child.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.tint)
                    .frame(width: 18)
                Text(child.name.isEmpty ? "Untitled" : child.name)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\((child.pages ?? []).count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .unifiedFrostedGlass(theme: theme, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func pageRow(_ page: SDPage) -> some View {
        Button {
            graphState.openNote(page.id)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                Text(page.title.isEmpty ? "Untitled Note" : page.title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .unifiedFrostedGlass(theme: theme, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var notFoundFallback: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("Folder Not Found")
                .font(.headline)
            Text("No SDFolder exists for \(folderId)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
