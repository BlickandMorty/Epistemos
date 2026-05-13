import SwiftData
import SwiftUI

/// Panel showing pages with unsaved vault changes (dirty pages).
/// Receives pre-filtered dirty pages from EditorActionsBar's @Query.
struct VaultChangesPanel: View {
    private struct DiffPresentationRequest: Identifiable {
        let pageId: String
        let currentTitle: String
        let currentBody: String

        var id: String { pageId }
    }

    let dirtyPages: [SDPage]

    @Environment(UIState.self) private var ui
    @Environment(VaultSyncService.self) private var vaultSync

    @State private var diffRequest: DiffPresentationRequest?

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Unsaved Changes")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if !dirtyPages.isEmpty {
                    Button("Save All") {
                        vaultSync.saveAllDirtyPages()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(theme.resolved.accent.color)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if dirtyPages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.success)
                    Text("All notes saved to vault")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(dirtyPages, id: \.id) { page in
                            DirtyPageRow(page: page)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Phase R.3 async cascade: body read via
                                    // the primitives helper; set the diff
                                    // request once the body is available.
                                    // Live editor body short-circuits when
                                    // the page is open in a window.
                                    let pageId = page.id
                                    let currentTitle = page.title
                                    let filePath = page.filePath
                                    let inline = page.body
                                    Task { @MainActor in
                                        let currentBody: String
                                        if let live = NoteWindowManager.shared.editorBody(for: pageId) {
                                            currentBody = live
                                        } else {
                                            currentBody = await SDPage.loadBodyAsyncFromPrimitives(
                                                pageId: pageId,
                                                filePath: filePath,
                                                inlineBody: inline
                                            )
                                        }
                                        diffRequest = DiffPresentationRequest(
                                            pageId: pageId,
                                            currentTitle: currentTitle,
                                            currentBody: currentBody
                                        )
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { diffRequest != nil },
            set: { if !$0 { diffRequest = nil } }
        )) {
            if let diffRequest {
                DiffSheetView(
                    pageId: diffRequest.pageId,
                    currentTitle: diffRequest.currentTitle,
                    currentBody: diffRequest.currentBody
                )
            }
        }
    }
}

private struct DirtyPageRow: View {
    let page: SDPage

    @Environment(UIState.self) private var ui
    @Environment(VaultSyncService.self) private var vaultSync

    private var theme: EpistemosTheme { ui.theme.surfaceVariant(.other) }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(page.title.isEmpty ? "Untitled" : page.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.resolved.foreground.color)
                    .lineLimit(1)

                if let lastSaved = page.lastSyncedAt {
                    Text("Last saved \(lastSaved, format: .relative(presentation: .named))")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                } else {
                    Text("Never saved to vault")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.warning)
                }
            }

            Spacer()

            Button {
                // Handled by parent onTapGesture
            } label: {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 10))
            }
            .buttonStyle(.plain)
            .help("View changes")
            .accessibilityLabel("View changes")

            Button {
                vaultSync.savePage(pageId: page.id)
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Save to vault")
            .accessibilityLabel("Save to vault")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
