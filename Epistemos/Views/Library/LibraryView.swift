import AppKit
import SwiftData
import SwiftUI

// MARK: - Library View
// Research Library.
// 3 tabs: Sources (papers + citations), Thinkers & Authors, Research Tools
// Stats bar, search, DOI import.

struct LibraryView: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(ResearchState.self) private var research
    @Environment(ResearchService.self) private var researchService
    @Environment(InferenceState.self) private var inference

    @State private var activeTab: LibraryTab = .sources
    @State private var searchQuery = ""
    @State private var showDOIImport = false
    @State private var selectedResearchTool: ResearchToolTab = .search

    /// Research tool sub-tabs — mirrors the old Research Hub tabs
    enum ResearchToolTab: String, CaseIterable, Hashable {
        case search = "Paper Search"
        case novelty = "Novelty Check"
        case review = "Paper Review"
        case citations = "Citations"
        case ideas = "Idea Generator"

        var icon: String {
            switch self {
            case .search: "magnifyingglass"
            case .novelty: "sparkles"
            case .review: "doc.text.magnifyingglass"
            case .citations: "book.fill"
            case .ideas: "lightbulb.fill"
            }
        }
    }

    private var theme: EpistemosTheme { ui.theme }

    enum LibraryTab: String, CaseIterable, Hashable {
        case sources = "Sources"
        case thinkers = "Thinkers & Authors"
        case tools = "Research Tools"

        var icon: String {
            switch self {
            case .sources: "doc.text"
            case .thinkers: "person.2"
            case .tools: "flask"
            }
        }
    }

    // MARK: - Derived Data

    private var extractedAuthors: [ExtractedAuthor] {
        var map: [String: ExtractedAuthor] = [:]

        // Extract from search result papers
        for paper in research.researchPapers {
            for author in paper.authors {
                let key = author.lowercased().trimmingCharacters(in: .whitespaces)
                guard key.count >= 2 else { continue }
                if var existing = map[key] {
                    existing.paperCount += 1
                    if let yr = paper.year, !existing.years.contains(yr) {
                        existing.years.append(yr)
                    }
                    map[key] = existing
                } else {
                    map[key] = ExtractedAuthor(
                        name: author.trimmingCharacters(in: .whitespaces),
                        paperCount: 1,
                        years: paper.year.map { [$0] } ?? []
                    )
                }
            }
        }

        // Also extract from saved papers (auto-extracted citations)
        for saved in research.savedPapers {
            guard !saved.authors.isEmpty else { continue }
            // SavedPaper.authors is a single string — split on common separators
            let authorNames = saved.authors
                .components(separatedBy: CharacterSet(charactersIn: ",;&"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count >= 2 }
            for author in authorNames {
                let key = author.lowercased()
                let yearInt = saved.year.flatMap { Int($0) }
                if var existing = map[key] {
                    existing.paperCount += 1
                    if let yr = yearInt, !existing.years.contains(yr) {
                        existing.years.append(yr)
                    }
                    map[key] = existing
                } else {
                    map[key] = ExtractedAuthor(
                        name: author,
                        paperCount: 1,
                        years: yearInt.map { [$0] } ?? []
                    )
                }
            }
        }

        return map.values.sorted { $0.paperCount > $1.paperCount }
    }

    /// Total source count — saved papers + search papers + citations (deduplicated display).
    private var totalSourceCount: Int {
        research.savedPapers.count + research.researchPapers.count + research.currentCitations.count
    }

    private var filteredPapers: [ResearchPaper] {
        guard !searchQuery.isEmpty else { return research.researchPapers }
        let q = searchQuery.lowercased()
        return research.researchPapers.filter {
            $0.title.lowercased().contains(q) || $0.authors.contains { $0.lowercased().contains(q) }
                || ($0.journal?.lowercased().contains(q) ?? false)
        }
    }

    private var filteredAuthors: [ExtractedAuthor] {
        guard !searchQuery.isEmpty else { return extractedAuthors }
        let q = searchQuery.lowercased()
        return extractedAuthors.filter { $0.name.lowercased().contains(q) }
    }

    // MARK: - Body

    var body: some View {
        PageShell(
            icon: "books.vertical", title: "Research Library",
            subtitle: "Your research brain — sources, thinkers & research tools"
        ) {
            // Stats pills
            statsRow

            // Tab bar
            HStack(spacing: Spacing.sm) {
                ResearchTabBar(tabs: LibraryTab.allCases, active: $activeTab) {
                    $0.icon
                } label: {
                    $0.rawValue
                }
                Spacer()
            }
            .padding(.bottom, Spacing.xs)

            // Search bar
            searchBar

            // Tab content
            Group {
                switch activeTab {
                case .sources: sourcesTab
                case .thinkers: thinkersTab
                case .tools: researchToolsTab
                }
            }
            .animation(Motion.page, value: activeTab)
        }
        .sheet(isPresented: $showDOIImport) {
            DOIImportSheet()
                .preferredColorScheme(ui.theme.colorScheme)
        }
        .onAppear {
            research.restoreSavedPapers()
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: Spacing.sm) {
            Spacer()
            StatPill(
                icon: "doc.text", label: "Sources", value: "\(totalSourceCount)",
                color: Color(hex: 0x8B7CF6))
            StatPill(
                icon: "person.2", label: "Authors", value: "\(extractedAuthors.count)",
                color: Color(hex: 0x22D3EE))
            StatPill(
                icon: "bookmark.fill", label: "Saved",
                value: "\(research.savedPapers.count)", color: Color(hex: 0xF59E0B))
            StatPill(
                icon: "tag", label: "Topics",
                value: "\(Set(research.researchPapers.compactMap(\.journal)).count)",
                color: Color(hex: 0x34D399))
            Spacer()
        }
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(theme.mutedForeground.opacity(0.4))
            TextField(searchPlaceholder, text: $searchQuery)
                .font(.system(size: 13))
                .textFieldStyle(.plain)

            if activeTab == .sources {
                Button {
                    showDOIImport = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 10))
                        Text("Import DOI")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .hoverGlassCapsule(flatBackground: theme.card)
                    .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .hoverGlass(flatBackground: theme.card, cornerRadius: 10)
        .padding(.bottom, Spacing.md)
    }

    private var searchPlaceholder: String {
        switch activeTab {
        case .sources: "Search sources, authors, tags..."
        case .thinkers: "Search authors..."
        case .tools: "Search tools..."
        }
    }

    // MARK: - Sources Tab (Papers + Citations combined)

    private var filteredSavedPapers: [SavedPaper] {
        guard !searchQuery.isEmpty else { return research.savedPapers }
        let q = searchQuery.lowercased()
        return research.savedPapers.filter {
            $0.title.lowercased().contains(q) || $0.authors.lowercased().contains(q)
                || ($0.journal?.lowercased().contains(q) ?? false)
        }
    }

    private var filteredCitations: [Citation] {
        guard !searchQuery.isEmpty else { return research.currentCitations }
        let q = searchQuery.lowercased()
        return research.currentCitations.filter {
            $0.text.lowercased().contains(q) || $0.authors.contains { $0.lowercased().contains(q) }
                || ($0.source?.lowercased().contains(q) ?? false)
        }
    }

    private var sourcesTab: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Saved Papers section
            if !filteredSavedPapers.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: 6) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 10))
                        Text("Saved · \(filteredSavedPapers.count)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(theme.accent)

                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(filteredSavedPapers) { paper in
                            SavedPaperCard(paper: paper)
                        }
                    }
                }
                .padding(.bottom, Spacing.lg)
            }

            // Citations section
            if !filteredCitations.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: 6) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 10))
                        Text("Citations · \(filteredCitations.count)")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: 0x22D3EE))

                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(filteredCitations) { citation in
                            CitationCard(citation: citation)
                        }
                    }
                }
                .padding(.bottom, Spacing.lg)
            }

            // Search result papers
            if filteredPapers.isEmpty && filteredSavedPapers.isEmpty && filteredCitations.isEmpty {
                LibraryEmptyState(
                    icon: "book.pages",
                    title: research.researchPapers.isEmpty && research.savedPapers.isEmpty
                        && research.currentCitations.isEmpty
                        ? "No sources yet" : "No matching sources",
                    subtitle: research.researchPapers.isEmpty && research.savedPapers.isEmpty
                        && research.currentCitations.isEmpty
                        ? "Sources will appear here as you search, save, and discuss research in chat. Use the Research tools to search Semantic Scholar."
                        : "Try adjusting your search"
                )
            } else if !filteredPapers.isEmpty {
                let years = filteredPapers.compactMap(\.year).filter { $0 > 0 }
                if let minY = years.min(), let maxY = years.max() {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 10))
                        Text(
                            "Search Results · \(minY)–\(maxY) · \(filteredPapers.count) paper\(filteredPapers.count > 1 ? "s" : "")"
                        )
                        .font(.system(size: 11))
                    }
                    .foregroundStyle(theme.textTertiary)
                }

                LazyVStack(spacing: Spacing.sm) {
                    ForEach(filteredPapers) { paper in
                        LibraryPaperCard(paper: paper)
                    }
                }
            }
        }
    }

    // MARK: - Thinkers Tab

    private var thinkersTab: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if filteredAuthors.isEmpty {
                LibraryEmptyState(
                    icon: "person.2",
                    title: "No thinkers tracked yet",
                    subtitle:
                        "Authors and researchers are extracted from your saved papers. Save papers via Research tools to populate this section."
                )
            } else {
                Text(
                    "\(filteredAuthors.count) researcher\(filteredAuthors.count > 1 ? "s" : "") across your library"
                )
                .font(.system(size: 11))
                .foregroundStyle(theme.textTertiary)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Spacing.sm),
                        GridItem(.flexible(), spacing: Spacing.sm),
                    ], spacing: Spacing.sm
                ) {
                    ForEach(filteredAuthors) { author in
                        AuthorCard(author: author)
                    }
                }
            }
        }
    }

    // MARK: - Research Tools Tab

    private var researchToolsTab: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Sub-tab picker for the 5 research tools
            ResearchTabBar(tabs: ResearchToolTab.allCases, active: $selectedResearchTool) {
                $0.icon
            } label: {
                $0.rawValue
            }
            .padding(.bottom, Spacing.xs)

            // Provider capability banner
            if let note = inference.capabilities.contextNote {
                ProviderCapabilityBanner(note: note)
            }

            // Active research tool view
            Group {
                switch selectedResearchTool {
                case .search: PaperSearchTab()
                case .novelty: NoveltyCheckTab()
                case .review: PaperReviewTab()
                case .citations: CitationSearchTab()
                case .ideas: IdeaGeneratorTab()
                }
            }
            .animation(Motion.page, value: selectedResearchTool)
        }
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color.opacity(0.6))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color.opacity(0.8))
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.mutedForeground.opacity(0.5))
        }
    }
}

// MARK: - Library Paper Card
// Native macOS row with context menu for actions.

private struct LibraryPaperCard: View {
    let paper: ResearchPaper

    @Environment(UIState.self) private var ui
    @State private var isExpanded = false
    @State private var showCopied = false
    private var theme: EpistemosTheme { ui.theme }

    private var formattedCitation: String {
        var parts: [String] = []
        if !paper.authors.isEmpty { parts.append(paper.authors.prefix(3).joined(separator: ", ")) }
        parts.append("\"\(paper.title).\"")
        if let journal = paper.journal { parts.append("*\(journal)*") }
        if let year = paper.year, year > 0 { parts.append("(\(year))") }
        if let doi = paper.doi { parts.append("DOI: \(doi)") }
        else if let url = paper.url { parts.append(url) }
        return parts.joined(separator: " ")
    }

    private func copyCitation() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedCitation, forType: .string)
        withAnimation(Motion.quick) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(Motion.quick) { showCopied = false }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title + expand
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(paper.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(isExpanded ? nil : 2)
                        .multilineTextAlignment(.leading)

                    // Author · Year · Journal
                    HStack(spacing: 6) {
                        if !paper.authors.isEmpty {
                            Text(paper.authors.prefix(3).joined(separator: ", ")
                                 + (paper.authors.count > 3 ? " +\(paper.authors.count - 3)" : ""))
                                .font(.system(size: 11))
                                .foregroundStyle(theme.mutedForeground)
                                .lineLimit(1)
                        }
                        if let year = paper.year, year > 0 {
                            Text("·").foregroundStyle(theme.textTertiary.opacity(0.3))
                            Text("\(year)")
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary)
                        }
                        if let journal = paper.journal {
                            Text("·").foregroundStyle(theme.textTertiary.opacity(0.3))
                            Text(journal)
                                .font(.system(size: 10))
                                .italic()
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Action buttons
                HStack(spacing: 2) {
                    Button(action: copyCitation) {
                        Image(systemName: showCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundStyle(showCopied ? .green : theme.textTertiary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Copy citation")

                    if let url = paper.url, let destination = URL(string: url) {
                        Link(destination: destination) {
                            Image(systemName: "safari")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.textTertiary)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .help("Open in browser")
                    }
                }
            }

            // Abstract (expanded)
            if isExpanded, let abstract = paper.abstract, !abstract.isEmpty {
                Text(abstract)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.mutedForeground)
                    .lineSpacing(3)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hoverGlass(flatBackground: theme.card, cornerRadius: 10)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture { withAnimation(Motion.quick) { isExpanded.toggle() } }
        .contextMenu {
            Button("Copy Citation") { copyCitation() }
            if let url = paper.url, let destination = URL(string: url) {
                Link("Open in Browser", destination: destination)
            }
            if let doi = paper.doi {
                Button("Copy DOI") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(doi, forType: .string)
                }
            }
        }
    }
}

// MARK: - Saved Paper Card
// Native macOS row with context menu and provenance navigation.

private struct SavedPaperCard: View {
    let paper: SavedPaper

    @Environment(UIState.self) private var ui
    @Environment(ResearchState.self) private var research
    @State private var isExpanded = false
    @State private var showCopied = false
    private var theme: EpistemosTheme { ui.theme }

    private var formattedCitation: String {
        var parts: [String] = []
        if !paper.authors.isEmpty { parts.append(paper.authors) }
        parts.append("\"\(paper.title).\"")
        if let journal = paper.journal { parts.append("*\(journal)*") }
        if let year = paper.year { parts.append("(\(year))") }
        if let doi = paper.doi { parts.append("DOI: \(doi)") }
        else if let url = paper.url { parts.append(url) }
        return parts.joined(separator: " ")
    }

    private var provenanceLabel: String? {
        if let noteTitle = paper.originNoteTitle {
            return "Note: \(noteTitle)"
        }
        switch paper.source {
        case "chat", "research": return paper.originChatId != nil ? "Chat conversation" : "Chat"
        case "minichat": return "Mini chat"
        case "note-scan": return "Note scan"
        default: return paper.source
        }
    }

    private var canNavigate: Bool {
        paper.originChatId != nil || paper.originNoteTitle != nil
    }

    private func copyCitation() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedCitation, forType: .string)
        withAnimation(Motion.quick) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(Motion.quick) { showCopied = false }
        }
    }

    private func navigateToSource() {
        if let noteTitle = paper.originNoteTitle {
            guard let bootstrap = AppBootstrap.shared else { return }
            let descriptor = FetchDescriptor<SDPage>(
                predicate: #Predicate<SDPage> { $0.title == noteTitle }
            )
            if let page = try? bootstrap.modelContainer.mainContext.fetch(descriptor).first {
                NoteWindowManager.shared.open(pageId: page.id)
            }
        } else if let chatId = paper.originChatId {
            guard let bootstrap = AppBootstrap.shared else { return }
            bootstrap.loadChat(chatId: chatId)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title + actions
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(paper.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.foreground)
                        .lineLimit(isExpanded ? nil : 2)
                        .multilineTextAlignment(.leading)

                    // Author · Year · Journal
                    HStack(spacing: 6) {
                        if !paper.authors.isEmpty {
                            Text(paper.authors)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.mutedForeground)
                                .lineLimit(1)
                        }
                        if let year = paper.year {
                            Text("·").foregroundStyle(theme.textTertiary.opacity(0.3))
                            Text(year)
                                .font(.system(size: 10))
                                .foregroundStyle(theme.textTertiary)
                        }
                        if let journal = paper.journal {
                            Text("·").foregroundStyle(theme.textTertiary.opacity(0.3))
                            Text(journal)
                                .font(.system(size: 10))
                                .italic()
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Action buttons — visible inline
                HStack(spacing: 2) {
                    Button(action: copyCitation) {
                        Image(systemName: showCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundStyle(showCopied ? .green : theme.textTertiary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Copy citation")

                    Button { research.togglePaperFavorite(paper.id) } label: {
                        Image(systemName: paper.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundStyle(paper.isFavorite ? .yellow : theme.textTertiary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(paper.isFavorite ? "Unfavorite" : "Favorite")

                    Button { withAnimation(Motion.quick) { research.removeSavedPaper(paper.id) } } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.textTertiary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Remove")
                }
            }

            // Provenance tag — clickable to navigate to source
            if let label = provenanceLabel {
                Button(action: navigateToSource) {
                    HStack(spacing: 4) {
                        Image(systemName: paper.originNoteTitle != nil ? "doc.text" : "bubble.left")
                            .font(.system(size: 9))
                        Text(label)
                            .font(.system(size: 10, weight: .medium))
                        if canNavigate {
                            Image(systemName: "arrow.forward")
                                .font(.system(size: 8, weight: .semibold))
                        }
                    }
                    .foregroundStyle(canNavigate ? theme.accent : theme.textTertiary.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        canNavigate ? theme.accent.opacity(0.1) : theme.glassBg,
                        in: RoundedRectangle(cornerRadius: 6)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(!canNavigate)
                .help(canNavigate ? "Navigate to source" : "Source: \(label)")
            }

            // Abstract (expanded)
            if isExpanded, let abstract = paper.abstract, !abstract.isEmpty {
                Text(abstract)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.mutedForeground)
                    .lineSpacing(3)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hoverGlass(flatBackground: theme.card, cornerRadius: 10)
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture { withAnimation(Motion.quick) { isExpanded.toggle() } }
        .contextMenu {
            Button("Copy Citation") { copyCitation() }
            Button(paper.isFavorite ? "Unfavorite" : "Favorite") {
                research.togglePaperFavorite(paper.id)
            }
            if canNavigate {
                Button("Go to Source") { navigateToSource() }
            }
            if let url = paper.url, let destination = URL(string: url) {
                Link("Open in Browser", destination: destination)
            }
            Divider()
            Button("Remove", role: .destructive) {
                withAnimation(Motion.quick) { research.removeSavedPaper(paper.id) }
            }
        }
    }
}

// MARK: - Author Card

private struct AuthorCard: View {
    let author: ExtractedAuthor

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    private var yearRange: String {
        guard let mn = author.years.min(), let mx = author.years.max() else { return "" }
        return mn == mx ? "\(mn)" : "\(mn)–\(mx)"
    }

    private var initials: String {
        author.name.split(separator: " ")
            .compactMap(\.first)
            .prefix(2)
            .map { String($0) }
            .joined()
            .uppercased()
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: 0x8B7CF6).opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(initials)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: 0x8B7CF6))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(author.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.foreground)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("\(author.paperCount) paper\(author.paperCount > 1 ? "s" : "")")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.mutedForeground)
                    if !yearRange.isEmpty {
                        Text("·").foregroundStyle(theme.textTertiary.opacity(0.3))
                        Text(yearRange)
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(Spacing.md)
        .hoverGlass(flatBackground: theme.card, cornerRadius: 10)
        .contextMenu {
            Button("Copy Name") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(author.name, forType: .string)
            }
        }
    }
}

// MARK: - Citation Card

private struct CitationCard: View {
    let citation: Citation

    @Environment(UIState.self) private var ui
    @State private var showCopied = false
    private var theme: EpistemosTheme { ui.theme }

    private var formattedCitation: String {
        var parts: [String] = ["\"\(citation.text)\""]
        if !citation.authors.isEmpty {
            parts.append("— \(citation.authors.joined(separator: ", "))")
        }
        if let year = citation.year { parts.append("(\(year))") }
        if let source = citation.source { parts.append(source) }
        return parts.joined(separator: " ")
    }

    private func copyCitation() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedCitation, forType: .string)
        withAnimation(Motion.quick) { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(Motion.quick) { showCopied = false }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textTertiary.opacity(0.5))
                    .padding(.top, 3)

                Text(citation.text)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.foreground)
                    .lineSpacing(2)

                Spacer()

                Button(action: copyCitation) {
                    Image(systemName: showCopied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(showCopied ? .green : theme.textTertiary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Copy citation")
            }

            HStack(spacing: 6) {
                if let source = citation.source {
                    Text(source)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(theme.mutedForeground)
                }
                if let year = citation.year {
                    Text("·").foregroundStyle(theme.textTertiary.opacity(0.3))
                    Text("\(year)")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }
                if !citation.authors.isEmpty {
                    Text("·").foregroundStyle(theme.textTertiary.opacity(0.3))
                    Text(citation.authors.prefix(2).joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }
            }
            .padding(.leading, 20) // align with text after quote icon
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hoverGlass(flatBackground: theme.card, cornerRadius: 10)
        .contextMenu {
            Button("Copy Citation") { copyCitation() }
            Button("Copy Text Only") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(citation.text, forType: .string)
            }
        }
    }
}

// MARK: - Library Empty State

private struct LibraryEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(theme.mutedForeground.opacity(0.2))
                .symbolEffect(.pulse, isActive: true)
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.mutedForeground.opacity(0.5))
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(theme.mutedForeground.opacity(0.3))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxxl * 2)
    }
}

// MARK: - DOI Import Sheet

private struct DOIImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UIState.self) private var ui
    @Environment(ResearchService.self) private var researchService

    @State private var doiInput = ""
    @State private var isImporting = false
    @State private var errorMessage: String?

    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Text("Import Paper by DOI")
                .font(.epHeading)
                .foregroundStyle(theme.foreground)

            TextField("Enter DOI (e.g., 10.1000/xyz123)", text: $doiInput)
                .font(.epBody)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 400)
                .disabled(isImporting)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.error)
            }

            HStack(spacing: Spacing.md) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isImporting)

                Button {
                    importDOI()
                } label: {
                    if isImporting {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.7)
                            Text("Importing...")
                        }
                    } else {
                        Text("Import")
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    doiInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImporting)
            }
        }
        .padding(Spacing.xxl)
        .frame(minWidth: 450)
    }

    private func importDOI() {
        isImporting = true
        errorMessage = nil
        Task {
            do {
                _ = try await researchService.importDOI(doiInput)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isImporting = false
            }
        }
    }
}

// MARK: - Data Types

private struct ExtractedAuthor: Identifiable {
    let id = UUID()
    var name: String
    var paperCount: Int
    var years: [Int]
}



