import AppKit
import SwiftData
import SwiftUI

struct NotesWorkspaceView: View {
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(UIState.self) private var ui

    @Query(SDPage.activePagesDescriptor) private var allPages: [SDPage]
    @Query(sort: \SDFolder.sortOrder) private var allFolders: [SDFolder]

    @State private var navigationStates: [String: NoteNavigationState] = [:]
    @State private var showVaultConnection = false

    private var activeWorkspaceTab: NotesUIState.WorkspaceTab? {
        notesUI.workspaceTabs.first(where: { $0.id == notesUI.workspaceActiveTabId })
    }

    private var activeNavigationState: NoteNavigationState? {
        guard let activeWorkspaceTab else { return nil }
        return navigationStates[activeWorkspaceTab.id]
    }

    private var pageById: [String: SDPage] {
        Dictionary(uniqueKeysWithValues: allPages.map { ($0.id, $0) })
    }

    private var currentWorkspacePageId: String? {
        activeNavigationState?.currentPageId ?? activeWorkspaceTab?.pageId
    }

    private var workspaceTabItems: [NotesWorkspaceTabBar.TabItem] {
        notesUI.workspaceTabs.map { tab in
            let currentPageId = navigationStates[tab.id]?.currentPageId ?? tab.pageId
            guard let currentPageId,
                let page = pageById[currentPageId]
            else {
                return NotesWorkspaceTabBar.TabItem(
                    id: tab.id,
                    pageId: nil,
                    title: "Landing",
                    icon: "house",
                    isActive: tab.id == notesUI.workspaceActiveTabId,
                    isPinned: tab.isPinned,
                    isLanding: true
                )
            }
            return NotesWorkspaceTabBar.TabItem(
                id: tab.id,
                pageId: currentPageId,
                title: page.title.isEmpty ? "Untitled" : page.title,
                icon: page.isJournal ? "calendar" : "doc.text",
                isActive: tab.id == notesUI.workspaceActiveTabId,
                isPinned: tab.isPinned,
                isLanding: false
            )
        }
    }

    var body: some View {
        NavigationSplitView {
            NotesSidebar(
                allPages: allPages,
                allFolders: allFolders,
                onSelectPage: selectWorkspacePage,
                selectedPageId: currentWorkspacePageId,
                onClearSelection: clearWorkspaceSelection
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 420)
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            syncActiveTabNavigation()
        }
        .onChange(of: notesUI.workspaceActiveTabId) { _, _ in
            syncActiveTabNavigation()
        }
        .onChange(of: notesUI.workspaceTabs) { _, _ in
            syncActiveTabNavigation()
        }
        .sheet(isPresented: $showVaultConnection) {
            WorkspaceVaultConnectionSheet()
                .preferredColorScheme(ui.theme.colorScheme)
                .presentationDetents([.medium, .large])
                .presentationBackground(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        Group {
            if let activeNavigationState {
                NoteDetailWorkspaceView(
                    pageId: activeNavigationState.currentPageId,
                    chrome: .embedded
                )
                .id("\(notesUI.workspaceActiveTabId):\(activeNavigationState.currentPageId)")
                .environment(activeNavigationState)
                .onAppear {
                    notesUI.setWorkspaceCurrentPage(activeNavigationState.currentPageId)
                }
                .onChange(of: activeNavigationState.currentPageId) { _, newPageId in
                    notesUI.setWorkspaceCurrentPage(newPageId)
                }
            } else {
                NotesWorkspaceLandingView(
                    allPages: allPages,
                    allFolders: allFolders,
                    onOpenPage: selectWorkspacePage,
                    onCreatePage: createWorkspacePage,
                    onOpenMostRecent: openMostRecentPage,
                    onManageVault: { showVaultConnection = true }
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            NotesWorkspaceTabBar(
                tabs: workspaceTabItems,
                onSelectTab: { tabId in
                    notesUI.activateWorkspaceTab(tabId)
                    syncActiveTabNavigation()
                },
                onTogglePinned: notesUI.toggleWorkspaceTabPinned,
                onCloseTab: closeWorkspaceTab,
                onOpenInNewTab: moveWorkspaceTabToNoteWindow,
                onShowLanding: showWorkspaceLanding,
                onAddTab: notesUI.addWorkspaceTab
            )
        }
    }

    private func selectWorkspacePage(_ pageId: String) {
        notesUI.openWorkspacePage(pageId)
        syncActiveTabNavigation(forceReset: true, explicitPageId: pageId)
    }

    private func clearWorkspaceSelection() {
        navigationStates.removeValue(forKey: notesUI.workspaceActiveTabId)
        notesUI.closeWorkspacePage()
    }

    private func showWorkspaceLanding() {
        notesUI.showWorkspaceLanding()
        syncActiveTabNavigation()
    }

    private func closeWorkspaceTab(_ tabId: String) {
        navigationStates.removeValue(forKey: tabId)
        notesUI.closeWorkspaceTab(tabId)
        syncActiveTabNavigation()
    }

    private func moveWorkspaceTabToNoteWindow(_ tabId: String) {
        guard let pageId = workspaceTabItems.first(where: { $0.id == tabId })?.pageId else { return }
        navigationStates.removeValue(forKey: tabId)
        notesUI.closeWorkspaceTab(tabId, allowPinned: true)
        syncActiveTabNavigation()
        NoteWindowManager.shared.open(pageId: pageId)
    }

    private func syncActiveTabNavigation(forceReset: Bool = false, explicitPageId: String? = nil) {
        guard let activeWorkspaceTab else { return }
        let pageId = explicitPageId ?? activeWorkspaceTab.pageId

        guard let pageId else {
            navigationStates.removeValue(forKey: activeWorkspaceTab.id)
            return
        }

        let shouldReset = forceReset || navigationStates[activeWorkspaceTab.id] == nil

        if shouldReset {
            navigationStates[activeWorkspaceTab.id] = NoteNavigationState(
                rootPageId: pageId,
                rootTitle: title(for: pageId)
            )
        }
    }

    private func title(for pageId: String) -> String {
        let title = pageById[pageId]?.title ?? ""
        return title.isEmpty ? "Untitled" : title
    }

    private func createWorkspacePage() {
        Task {
            if let pageId = await vaultSync.createPage(title: "Untitled") {
                await MainActor.run {
                    selectWorkspacePage(pageId)
                }
            }
        }
    }

    private func openMostRecentPage() {
        guard let pageId = allPages.first?.id else { return }
        selectWorkspacePage(pageId)
    }
}

private struct NotesWorkspaceLandingView: View {
    let allPages: [SDPage]
    let allFolders: [SDFolder]
    let onOpenPage: (String) -> Void
    let onCreatePage: () -> Void
    let onOpenMostRecent: () -> Void
    let onManageVault: () -> Void

    @Environment(UIState.self) private var ui

    private var theme: EpistemosTheme { ui.theme }
    private var recentPages: [SDPage] { Array(allPages.prefix(6)) }
    private var totalPages: Int { allPages.count }
    private var totalFolders: Int { allFolders.count }
    private var journalCount: Int { allPages.filter(\.isJournal).count }
    private var hasRecentPage: Bool { !allPages.isEmpty }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                ZStack {
                    Circle()
                        .fill(theme.accent.opacity(0.06))
                        .frame(width: 80, height: 80)
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 36, weight: .thin))
                        .foregroundStyle(theme.accent.opacity(0.8))
                }

                Spacer().frame(height: Spacing.lg)

                Text("Notes")
                    .font(.custom("RetroGaming", size: 32))
                    .foregroundStyle(theme.foreground)

                Spacer().frame(height: Spacing.xs)

                Text("Your second brain, locally stored")
                    .font(.epCaption)
                    .foregroundStyle(theme.textTertiary)

                Spacer().frame(height: Spacing.xl)

                HStack(spacing: Spacing.sm) {
                    NotesLandingStatPill(icon: "doc.text", value: totalPages, label: "Pages")
                    NotesLandingStatPill(icon: "folder", value: totalFolders, label: "Folders")
                    NotesLandingStatPill(icon: "calendar", value: journalCount, label: "Journals")
                }

                Spacer().frame(height: Spacing.xxl)

                HStack(spacing: Spacing.sm) {
                    NotesLandingGlassPill(
                        icon: "plus",
                        label: "New Page",
                        color: theme.success,
                        action: onCreatePage
                    )

                    NotesLandingGlassPill(
                        icon: "clock",
                        label: "Most Recent",
                        color: theme.accent,
                        action: onOpenMostRecent
                    )
                    .disabled(!hasRecentPage)
                    .opacity(hasRecentPage ? 1 : 0.45)

                    NotesLandingGlassPill(
                        icon: "folder.badge.gearshape",
                        label: "Vault",
                        color: .purple,
                        action: onManageVault
                    )
                }
                .frame(maxWidth: 480)

                if !recentPages.isEmpty {
                    Spacer().frame(height: Spacing.xxxl)

                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(theme.textTertiary)
                            Text("RECENT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(theme.textTertiary)
                                .tracking(0.8)
                        }
                        .padding(.horizontal, 4)

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: Spacing.sm),
                                GridItem(.flexible(), spacing: Spacing.sm),
                            ],
                            spacing: Spacing.sm
                        ) {
                            ForEach(recentPages, id: \.id) { page in
                                NotesWorkspaceRecentPageCard(page: page) {
                                    onOpenPage(page.id)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 480)
                }

                Spacer().frame(height: 120)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.xxl)
        }
    }
}

private struct NotesLandingStatPill: View {
    let icon: String
    let value: Int
    let label: String

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(theme.accent.opacity(0.7))
            Text("\(value)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.foreground)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: Capsule())
    }
}

private struct NotesLandingGlassPill: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @Environment(UIState.self) private var ui
    @State private var isHovered = false

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(color.opacity(isHovered ? 0.14 : 0.08))
            )
            .glassEffect(.regular, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Motion.quick) { isHovered = hovering }
        }
    }
}

private struct NotesWorkspaceRecentPageCard: View {
    let page: SDPage
    let action: () -> Void

    @Environment(UIState.self) private var ui
    @State private var isHovered = false

    private var theme: EpistemosTheme { ui.theme }

    private var displayTitle: String {
        page.title.isEmpty ? "Untitled" : page.title
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: page.updatedAt, relativeTo: .now)
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    if page.emoji.isEmpty {
                        Image(systemName: page.isJournal ? "calendar" : "doc.text")
                            .font(.system(size: 12))
                            .foregroundStyle(page.isJournal ? theme.success : theme.accent)
                            .frame(width: 16)
                    } else {
                        Text(page.emoji)
                            .frame(width: 16)
                    }

                    Text(displayTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if page.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.yellow)
                    }
                    Text(relativeDate)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                    Spacer()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isHovered ? theme.glassHover : theme.glassBg.opacity(0.4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(theme.glassBorder, lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Motion.quick) { isHovered = hovering }
        }
    }
}

private struct NotesWorkspaceTabBar: View {
    struct TabItem: Identifiable {
        let id: String
        let pageId: String?
        let title: String
        let icon: String
        let isActive: Bool
        let isPinned: Bool
        let isLanding: Bool
    }

    let tabs: [TabItem]
    let onSelectTab: (String) -> Void
    let onTogglePinned: (String) -> Void
    let onCloseTab: (String) -> Void
    let onOpenInNewTab: (String) -> Void
    let onShowLanding: () -> Void
    let onAddTab: () -> Void

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onShowLanding) {
                Image(systemName: "house")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Notes Landing")

            Rectangle()
                .fill(theme.glassBorder)
                .frame(width: 0.5, height: 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tabs) { tab in
                        HStack(spacing: 6) {
                            Button {
                                onSelectTab(tab.id)
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 10))
                                        .foregroundStyle(tab.isActive ? theme.accent : theme.textTertiary)

                                    Text(tab.title)
                                        .font(.system(size: 12, weight: tab.isActive ? .semibold : .regular))
                                        .foregroundStyle(tab.isActive ? theme.foreground : theme.textSecondary)
                                        .lineLimit(1)
                                        .frame(maxWidth: 120)
                                }
                            }
                            .buttonStyle(.plain)

                            if !tab.isLanding {
                                Button {
                                    onTogglePinned(tab.id)
                                } label: {
                                    Image(systemName: tab.isPinned ? "pin.fill" : "pin")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(tab.isPinned ? theme.accent : theme.textTertiary)
                                        .frame(width: 16, height: 16)
                                }
                                .buttonStyle(.plain)
                                .help(tab.isPinned ? "Unpin Tab" : "Pin Tab")
                            }

                            if !tab.isPinned {
                                Button {
                                    onCloseTab(tab.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(theme.textTertiary)
                                        .frame(width: 16, height: 16)
                                }
                                .buttonStyle(.plain)
                                .help("Close Tab")
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(tab.isActive ? theme.accent.opacity(0.12) : .clear)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    tab.isActive ? theme.accent.opacity(0.25) : .clear,
                                    lineWidth: 0.5
                                )
                        )
                        .contextMenu {
                            if !tab.isLanding, tab.pageId != nil {
                                Button("Open in New Tab") {
                                    onOpenInNewTab(tab.id)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Rectangle()
                .fill(theme.glassBorder)
                .frame(width: 0.5, height: 20)

            Button(action: onAddTab) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("New Tab")
        }
        .frame(height: 44)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, 8)
    }
}

private struct WorkspaceVaultConnectionSheet: View {
    @Environment(UIState.self) private var ui
    @Environment(NotesUIState.self) private var notesUI
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(\.dismiss) private var dismiss

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        Form {
            Section("Connection") {
                if let url = vaultSync.vaultURL {
                    LabeledContent("Path") {
                        Text(url.path)
                            .font(.system(size: 12, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    LabeledContent("Status") {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(vaultSync.isWatching ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(vaultSync.isWatching ? "Connected" : "Disconnected")
                                .font(.system(size: 12))
                        }
                    }
                    HStack(spacing: Spacing.md) {
                        Button("Change Vault") { selectVaultFolder() }
                        Button("Sync from Vault") {
                            Task { _ = await vaultSync.syncFromVault() }
                        }
                        Button("Disconnect", role: .destructive) { disconnectVault() }
                    }
                } else {
                    Text("No vault connected. Select a folder to sync your markdown notes.")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                    Button("Select Vault Folder") { selectVaultFolder() }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.accent)
                }
            }

            if vaultSync.vaultURL != nil {
                Section("Search Index") {
                    Button("Rebuild Index") {
                        vaultSync.rebuildIndex()
                    }
                    .disabled(vaultSync.isIndexing)

                    Text("Use this to reattach or clear the current vault from Notes.")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(width: 520, height: 360)
    }

    private func selectVaultFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder for your Epistemos vault"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        if let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(bookmark, forKey: "epistemos.vaultBookmark")
        }

        notesUI.resetForVaultSwitch()
        vaultSync.startWatching(vaultURL: url)
        dismiss()
    }

    private func disconnectVault() {
        notesUI.resetForVaultSwitch()
        vaultSync.stopWatching()
        UserDefaults.standard.removeObject(forKey: "epistemos.vaultBookmark")
        AppBootstrap.shared?.ambientManifest = nil
        dismiss()
    }
}
