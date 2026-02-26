import SwiftData
import SwiftUI

// MARK: - IdeasPortalView
// Global Ideas Hub — aggregates all ideas and brain dumps from every note.
// Three views: By Note (collapsible sections), By Theme (AI-clustered), All Ideas (flat search).
// Lives in the GraphWindowView sidebar under the "Ideas" tab.

struct IdeasPortalView: View {
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    @Environment(\.modelContext) private var modelContext

    @Query(SDPage.activePagesDescriptor) private var allPages: [SDPage]

    @State private var viewMode: ViewMode = .byNote
    @State private var searchText = ""
    @State private var showCreateSheet = false
    @State private var isLinkMode = false
    @State private var linkSelection: [String] = []

    private var theme: EpistemosTheme { ui.theme }

    enum ViewMode: String, CaseIterable {
        case byNote = "By Note"
        case byTheme = "By Theme"
        case all = "All"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(theme.border).frame(height: 0.5)
            tabContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showCreateSheet) {
            CreateIdeaSheet(pages: pagesWithContent)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Picker("", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    isLinkMode.toggle()
                    linkSelection.removeAll()
                } label: {
                    Image(systemName: "link")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isLinkMode ? theme.background : theme.accent)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isLinkMode ? theme.accent : theme.accent.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .help(isLinkMode ? "Cancel linking" : "Link two ideas")

                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.accent)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(theme.accent.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .help("New Idea")
            }

            if isLinkMode {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.accent)
                    Text(linkSelection.isEmpty
                         ? "Select 2 ideas to link"
                         : "Select 1 more idea (\(linkSelection.count)/2)")
                        .font(.epCaption)
                        .foregroundStyle(theme.accent)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.accent.opacity(0.08))
                )
            }

            if viewMode == .all {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                    TextField("Search ideas...", text: $searchText)
                        .font(.epCaption)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.muted)
                )
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch viewMode {
        case .byNote:
            byNoteView
        case .byTheme:
            byThemeView
        case .all:
            allIdeasView
        }
    }

    // MARK: - By Note View

    private var byNoteView: some View {
        ScrollView {
            if pagesWithIdeas.isEmpty {
                emptyState(
                    icon: "lightbulb",
                    title: "No ideas yet",
                    subtitle: "Add ideas to your notes or tap + to create one"
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(pagesWithIdeas, id: \.id) { page in
                        noteSection(page)
                    }
                }
                .padding(.vertical, Spacing.sm)
            }
        }
    }

    @ViewBuilder
    private func noteSection(_ page: SDPage) -> some View {
        DisclosureGroup {
            ForEach(page.ideas) { idea in
                ideaRow(idea, pageId: page.id)
            }
        } label: {
            HStack(spacing: 6) {
                if !page.emoji.isEmpty {
                    Text(page.emoji)
                        .font(.system(size: 13))
                } else {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.textTertiary)
                }
                Text(page.title)
                    .font(.epCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)

                Spacer()

                Text("\(page.ideas.count)")
                    .font(.epSmall)
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - By Theme View

    private var byThemeView: some View {
        ScrollView {
            let conceptGroups = themeGroups()
            if conceptGroups.isEmpty {
                emptyState(
                    icon: "sparkles",
                    title: "No themes detected",
                    subtitle: "Run a vault scan to cluster ideas by AI-detected themes"
                )
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(conceptGroups, id: \.concept.id) { group in
                        themeSection(group)
                    }
                }
                .padding(.vertical, Spacing.sm)
            }
        }
    }

    @ViewBuilder
    private func themeSection(_ group: ThemeGroup) -> some View {
        DisclosureGroup {
            ForEach(group.ideas, id: \.record.id) { linked in
                themeIdeaRow(linked)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.system(size: 11))
                    .foregroundStyle(.pink)
                Text(group.concept.label)
                    .font(.epCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)

                Spacer()

                Text("\(group.ideas.count)")
                    .font(.epSmall)
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }

    @ViewBuilder
    private func themeIdeaRow(_ linked: LinkedIdea) -> some View {
        HStack(spacing: 6) {
            Image(systemName: linked.record.type == .brainDump ? "brain" : "lightbulb")
                .font(.system(size: 10))
                .foregroundStyle(linked.record.type == .brainDump ? .purple : .yellow)
            Text(linked.record.label)
                .font(.epCaption)
                .foregroundStyle(theme.foreground)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            // Select and focus in graph
            graphState.selectNode(linked.record.id)
            graphState.focusOnNode(linked.record.id)
        }
    }

    // MARK: - All Ideas View

    private var allIdeasView: some View {
        ScrollView {
            let ideas = filteredIdeas
            if ideas.isEmpty {
                if searchText.isEmpty {
                    emptyState(
                        icon: "lightbulb",
                        title: "No ideas yet",
                        subtitle: "Add ideas to your notes or tap + to create one"
                    )
                } else {
                    emptyState(
                        icon: "magnifyingglass",
                        title: "No results",
                        subtitle: "No ideas match \"\(searchText)\""
                    )
                }
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(ideas, id: \.idea.id) { item in
                        ideaRow(item.idea, pageId: item.pageId)
                    }
                }
                .padding(.vertical, Spacing.sm)
            }
        }
    }

    // MARK: - Idea Row

    @ViewBuilder
    private func ideaRow(_ idea: NoteIdea, pageId: String) -> some View {
        let isSelected = linkSelection.contains(idea.id)

        HStack(spacing: Spacing.sm) {
            // Link-mode selection indicator
            if isLinkMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? theme.accent : theme.textTertiary)
                    .frame(width: 20)
            }

            // Type icon
            Image(systemName: idea.type == .brainDump ? "brain" : "lightbulb")
                .font(.system(size: 12))
                .foregroundStyle(idea.type == .brainDump ? .purple : .yellow)
                .frame(width: 20)

            // Title + body preview
            VStack(alignment: .leading, spacing: 2) {
                Text(idea.title)
                    .font(.epCaption)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                if !idea.body.isEmpty {
                    Text(idea.body)
                        .font(.epSmall)
                        .foregroundStyle(theme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if !isLinkMode {
                // Graph focus button
                Button {
                    focusIdeaInGraph(idea)
                } label: {
                    Image(systemName: "scope")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Center in graph")

                // Delete button
                Button {
                    deleteIdea(idea, fromPageId: pageId)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Delete idea")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, 5)
        .background(
            isLinkMode && isSelected
                ? theme.accent.opacity(0.08)
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isLinkMode {
                toggleLinkSelection(idea)
            } else {
                NoteWindowManager.shared.open(pageId: pageId)
            }
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(theme.textTertiary)
            Text(title)
                .font(.epBody)
                .foregroundStyle(theme.textSecondary)
            Text(subtitle)
                .font(.epCaption)
                .foregroundStyle(theme.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Spacing.lg)
    }

    // MARK: - Data

    /// Pages that have at least one idea.
    private var pagesWithIdeas: [SDPage] {
        allPages.filter { !$0.ideas.isEmpty }
    }

    /// Pages with non-empty titles (for the create sheet picker).
    private var pagesWithContent: [SDPage] {
        allPages.filter { !$0.title.isEmpty }
    }

    /// Flattened (idea, pageId) tuples for All view, optionally filtered by search.
    private var filteredIdeas: [IdeaWithPage] {
        var result: [IdeaWithPage] = []
        for page in allPages {
            for idea in page.ideas {
                result.append(IdeaWithPage(idea: idea, pageId: page.id))
            }
        }
        if searchText.isEmpty { return result }
        let query = searchText.lowercased()
        return result.filter {
            $0.idea.title.lowercased().contains(query) ||
            $0.idea.body.lowercased().contains(query)
        }
    }

    // MARK: - Theme Groups

    struct ThemeGroup {
        let concept: GraphNodeRecord
        let ideas: [LinkedIdea]
    }

    struct LinkedIdea {
        let record: GraphNodeRecord
    }

    /// Build theme groups by finding Concept nodes that neighbor Idea/BrainDump nodes.
    private func themeGroups() -> [ThemeGroup] {
        let concepts = graphState.store.nodes(ofType: .concept)
        var groups: [ThemeGroup] = []

        for concept in concepts {
            let neighbors = graphState.store.neighbors(of: concept.id)
            let ideaNeighbors = neighbors.filter { $0.type == .idea || $0.type == .brainDump }
            guard !ideaNeighbors.isEmpty else { continue }
            groups.append(ThemeGroup(
                concept: concept,
                ideas: ideaNeighbors.map { LinkedIdea(record: $0) }
            ))
        }

        return groups.sorted { $0.ideas.count > $1.ideas.count }
    }

    // MARK: - Actions

    private func toggleLinkSelection(_ idea: NoteIdea) {
        if let index = linkSelection.firstIndex(of: idea.id) {
            linkSelection.remove(at: index)
        } else {
            guard linkSelection.count < 2 else { return }
            linkSelection.append(idea.id)
            if linkSelection.count == 2 {
                linkSelectedIdeas()
            }
        }
    }

    private func linkSelectedIdeas() {
        guard linkSelection.count == 2 else { return }

        let idA = linkSelection[0]
        let idB = linkSelection[1]

        // Find graph nodes for both ideas (try .idea first, then .brainDump)
        let nodeA = graphState.store.node(bySourceId: idA, type: .idea)
            ?? graphState.store.node(bySourceId: idA, type: .brainDump)
        let nodeB = graphState.store.node(bySourceId: idB, type: .idea)
            ?? graphState.store.node(bySourceId: idB, type: .brainDump)

        guard let nodeA, let nodeB else {
            // Reset if nodes not found in graph
            linkSelection.removeAll()
            isLinkMode = false
            return
        }

        // Persist the edge via SwiftData
        let sdEdge = SDGraphEdge(
            source: nodeA.id,
            target: nodeB.id,
            type: .ideaLink,
            weight: 1.0
        )
        modelContext.insert(sdEdge)

        // Add to in-memory graph store
        let edgeRecord = GraphEdgeRecord(
            id: sdEdge.id,
            sourceNodeId: nodeA.id,
            targetNodeId: nodeB.id,
            type: .ideaLink,
            weight: 1.0,
            createdAt: sdEdge.createdAt
        )
        graphState.store.addEdge(edgeRecord)

        // Reset link mode
        linkSelection.removeAll()
        isLinkMode = false
    }

    private func focusIdeaInGraph(_ idea: NoteIdea) {
        let nodeType: GraphNodeType = idea.type == .brainDump ? .brainDump : .idea
        if let graphNode = graphState.store.node(bySourceId: idea.id, type: nodeType) {
            graphState.selectNode(graphNode.id)
            graphState.focusOnNode(graphNode.id)
        }
    }

    private func deleteIdea(_ idea: NoteIdea, fromPageId pageId: String) {
        // Find the page and remove the idea from its ideas array
        guard let page = allPages.first(where: { $0.id == pageId }) else { return }
        var ideas = page.ideas
        ideas.removeAll { $0.id == idea.id }
        page.ideas = ideas

        // Remove corresponding graph node
        let nodeType: GraphNodeType = idea.type == .brainDump ? .brainDump : .idea
        if let graphNode = graphState.store.node(bySourceId: idea.id, type: nodeType) {
            graphState.store.removeNode(graphNode.id)

            // Also remove the persisted SDGraphNode
            let nodeId = graphNode.id
            let descriptor = FetchDescriptor<SDGraphNode>(
                predicate: #Predicate { $0.id == nodeId }
            )
            if let sdNode = try? modelContext.fetch(descriptor).first {
                modelContext.delete(sdNode)
            }
        }
    }
}

// MARK: - Supporting Types

private struct IdeaWithPage: Identifiable {
    let idea: NoteIdea
    let pageId: String
    var id: String { idea.id }
}

// MARK: - Create Idea Sheet

private struct CreateIdeaSheet: View {
    @Environment(UIState.self) private var ui
    @Environment(\.dismiss) private var dismiss

    let pages: [SDPage]

    @State private var title = ""
    @State private var ideaBody = ""
    @State private var ideaType: NoteIdea.IdeaType = .idea
    @State private var selectedPageId: String?

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Title
            Text("New Idea")
                .font(.epHeading)
                .foregroundStyle(theme.foreground)

            // Type picker
            Picker("Type", selection: $ideaType) {
                Text("Idea").tag(NoteIdea.IdeaType.idea)
                Text("Brain Dump").tag(NoteIdea.IdeaType.brainDump)
            }
            .pickerStyle(.segmented)

            // Target note picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Target Note")
                    .font(.epCaption)
                    .foregroundStyle(theme.textSecondary)
                Picker("Note", selection: $selectedPageId) {
                    Text("Select a note...").tag(String?.none)
                    ForEach(pages, id: \.id) { page in
                        HStack {
                            if !page.emoji.isEmpty {
                                Text(page.emoji)
                            }
                            Text(page.title)
                        }
                        .tag(Optional(page.id))
                    }
                }
                .labelsHidden()
            }

            // Title field
            VStack(alignment: .leading, spacing: 4) {
                Text("Title")
                    .font(.epCaption)
                    .foregroundStyle(theme.textSecondary)
                TextField("Idea title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .font(.epBody)
            }

            // Body field
            VStack(alignment: .leading, spacing: 4) {
                Text("Description")
                    .font(.epCaption)
                    .foregroundStyle(theme.textSecondary)
                TextEditor(text: $ideaBody)
                    .font(.epBody)
                    .frame(minHeight: 80, maxHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(theme.border, lineWidth: 0.5)
                    )
            }

            // Actions
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)

                Spacer()

                Button("Create") {
                    createIdea()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty || selectedPageId == nil)
            }
        }
        .padding(Spacing.xl)
        .frame(width: 360)
        .background(theme.background)
    }

    private func createIdea() {
        guard let pageId = selectedPageId,
              let page = pages.first(where: { $0.id == pageId }) else { return }

        let newIdea = NoteIdea(
            type: ideaType,
            title: title,
            body: ideaBody
        )

        var ideas = page.ideas
        ideas.append(newIdea)
        page.ideas = ideas
    }
}
