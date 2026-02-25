import SwiftUI

// MARK: - Library View
// Research Library — matches brainiac-2.0 library page.
// 5 tabs: Papers, Thinkers & Authors, Citations, Reading List, Research Tools
// Stats bar, search, DOI import.

struct LibraryView: View {
    @Environment(UIState.self) private var ui
    @Environment(ChatState.self) private var chat
    @Environment(ResearchState.self) private var research
    @Environment(ResearchService.self) private var researchService
    @Environment(InferenceState.self) private var inference

    @State private var activeTab: LibraryTab = .papers
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
        case papers = "Papers"
        case thinkers = "Thinkers & Authors"
        case citations = "Citations"
        case readingList = "Reading List"
        case tools = "Research Tools"

        var icon: String {
            switch self {
            case .papers: "doc.text"
            case .thinkers: "person.2"
            case .citations: "quote.opening"
            case .readingList: "lightbulb"
            case .tools: "flask"
            }
        }
    }

    // MARK: - Derived Data

    private var extractedAuthors: [ExtractedAuthor] {
        var map: [String: ExtractedAuthor] = [:]
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
        return map.values.sorted { $0.paperCount > $1.paperCount }
    }

    private var readingSuggestions: [ReadingSuggestion] {
        var suggestions: [ReadingSuggestion] = []
        var seen = Set<String>()

        let journalCounts = Dictionary(
            grouping: research.researchPapers.compactMap(\.journal), by: { $0 }
        )
        .mapValues(\.count)
        .sorted { $0.value > $1.value }
        .prefix(3)

        for (journal, count) in journalCounts {
            let key = journal.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            suggestions.append(
                ReadingSuggestion(
                    title: "Deep dive into \(journal)",
                    reason:
                        "You have \(count) paper\(count > 1 ? "s" : "") from this journal — consider reading foundational texts",
                    domain: journal
                ))
        }

        if research.researchPapers.count > 3 && !seen.contains("methodology") {
            suggestions.append(
                ReadingSuggestion(
                    title: "Research Methods & Methodology",
                    reason:
                        "With \(research.researchPapers.count) papers in your library, understanding meta-analytical methods would help synthesize findings",
                    domain: "methodology"
                ))
        }
        return Array(suggestions.prefix(8))
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
            subtitle: "Your research brain — papers, thinkers, citations & reading suggestions"
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
                case .papers: papersTab
                case .thinkers: thinkersTab
                case .citations: citationsTab
                case .readingList: readingListTab
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
                icon: "doc.text", label: "Papers", value: "\(research.researchPapers.count)",
                color: Color(hex: 0x8B7CF6))
            StatPill(
                icon: "person.2", label: "Authors", value: "\(extractedAuthors.count)",
                color: Color(hex: 0x22D3EE))
            StatPill(
                icon: "quote.opening", label: "Citations",
                value: "\(research.currentCitations.count)", color: Color(hex: 0xF59E0B))
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

            if activeTab == .papers {
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
        case .papers: "Search papers, authors, tags..."
        case .thinkers: "Search authors..."
        case .citations: "Search citations..."
        case .readingList: "Search suggestions..."
        case .tools: "Search tools..."
        }
    }

    // MARK: - Papers Tab

    private var filteredSavedPapers: [SavedPaper] {
        guard !searchQuery.isEmpty else { return research.savedPapers }
        let q = searchQuery.lowercased()
        return research.savedPapers.filter {
            $0.title.lowercased().contains(q) || $0.authors.lowercased().contains(q)
                || ($0.journal?.lowercased().contains(q) ?? false)
        }
    }

    private var papersTab: some View {
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

            // Extracted papers from search results
            if filteredPapers.isEmpty && filteredSavedPapers.isEmpty {
                LibraryEmptyState(
                    icon: "book.pages",
                    title: research.researchPapers.isEmpty && research.savedPapers.isEmpty
                        ? "No papers yet" : "No matching papers",
                    subtitle: research.researchPapers.isEmpty && research.savedPapers.isEmpty
                        ? "Papers will appear here as you search, save, and discuss research in chat. Use the Research tools to search Semantic Scholar."
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

    // MARK: - Citations Tab

    private var citationsTab: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if research.currentCitations.isEmpty {
                LibraryEmptyState(
                    icon: "quote.opening",
                    title: "No citations collected",
                    subtitle:
                        "Use the Citation Search tool in Research Hub to extract citations from your text. They'll appear here for reference."
                )
            } else {
                LazyVStack(spacing: Spacing.sm) {
                    ForEach(research.currentCitations) { citation in
                        CitationCard(citation: citation)
                    }
                }
            }
        }
    }

    // MARK: - Reading List Tab

    private var readingListTab: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if readingSuggestions.isEmpty {
                LibraryEmptyState(
                    icon: "lightbulb",
                    title: "No suggestions yet",
                    subtitle:
                        "Start researching topics and saving papers — personalized reading suggestions will appear based on your interests."
                )
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("Based on your \(research.researchPapers.count) papers")
                        .font(.system(size: 11))
                }
                .foregroundStyle(theme.textTertiary)

                LazyVStack(spacing: Spacing.sm) {
                    ForEach(readingSuggestions) { suggestion in
                        SuggestionCard(suggestion: suggestion)
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

private struct LibraryPaperCard: View {
    let paper: ResearchPaper

    @Environment(UIState.self) private var ui
    @State private var isExpanded = false
    @State private var isHovered = false
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Title row
            HStack(alignment: .top) {
                Button {
                    withAnimation(Motion.quick) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(paper.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                            .lineLimit(isExpanded ? nil : 2)
                            .multilineTextAlignment(.leading)
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                if let url = paper.url {
                    Link(
                        destination: URL(string: url) ?? URL(string: "https://scholar.google.com")!
                    ) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
            }

            // Author · Year · Journal
            HStack(spacing: 6) {
                if !paper.authors.isEmpty {
                    let authorStr =
                        paper.authors.prefix(3).joined(separator: ", ")
                        + (paper.authors.count > 3 ? " +\(paper.authors.count - 3)" : "")
                    Text(authorStr)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.mutedForeground)
                        .lineLimit(1)
                }
                if let year = paper.year, year > 0 {
                    Text("·").foregroundStyle(theme.textTertiary.opacity(0.3))
                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                            .font(.system(size: 9))
                        Text("\(year)")
                    }
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

            // Abstract (expanded)
            if isExpanded, let abstract = paper.abstract, !abstract.isEmpty {
                Text(abstract)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.mutedForeground)
                    .lineSpacing(3)
                    .padding(.top, 4)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hoverGlass(flatBackground: theme.card, cornerRadius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.accent.opacity(isHovered ? 0.06 : 0))
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Saved Paper Card

private struct SavedPaperCard: View {
    let paper: SavedPaper

    @Environment(UIState.self) private var ui
    @Environment(ResearchState.self) private var research
    @State private var isExpanded = false
    @State private var isHovered = false
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                Button {
                    withAnimation(Motion.quick) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(paper.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.foreground)
                            .lineLimit(isExpanded ? nil : 2)
                            .multilineTextAlignment(.leading)
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()

                // Favorite toggle
                Button {
                    research.togglePaperFavorite(paper.id)
                } label: {
                    Image(systemName: paper.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundStyle(paper.isFavorite ? .yellow : theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help(paper.isFavorite ? "Unfavorite" : "Favorite")
                .accessibilityLabel(paper.isFavorite ? "Unfavorite" : "Favorite")

                // Remove
                Button {
                    withAnimation(Motion.quick) { research.removeSavedPaper(paper.id) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textTertiary)
                }
                .buttonStyle(.plain)
                .help("Remove")
                .accessibilityLabel("Remove")
            }

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

            if isExpanded, let abstract = paper.abstract, !abstract.isEmpty {
                Text(abstract)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.mutedForeground)
                    .lineSpacing(3)
                    .padding(.top, 4)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hoverGlass(flatBackground: theme.card, cornerRadius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.accent.opacity(isHovered ? 0.06 : 0))
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Author Card

private struct AuthorCard: View {
    let author: ExtractedAuthor

    @Environment(UIState.self) private var ui
    @State private var isHovered = false
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
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.accent.opacity(isHovered ? 0.06 : 0))
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Citation Card

private struct CitationCard: View {
    let citation: Citation

    @Environment(UIState.self) private var ui
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(citation.text)
                .font(.system(size: 13))
                .foregroundStyle(theme.foreground)
                .lineSpacing(2)

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
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hoverGlass(flatBackground: theme.card, cornerRadius: 10)
    }
}

// MARK: - Suggestion Card

private struct SuggestionCard: View {
    let suggestion: ReadingSuggestion

    @Environment(UIState.self) private var ui
    @State private var isHovered = false
    private var theme: EpistemosTheme { ui.theme }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: 0xF59E0B).opacity(0.1))
                    .frame(width: 32, height: 32)
                Image(systemName: "book.pages")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: 0xF59E0B))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.foreground)
                Text(suggestion.reason)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.mutedForeground)
                    .lineSpacing(2)
                Text(suggestion.domain)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(theme.glassBg, in: Capsule())
                    .overlay(Capsule().strokeBorder(theme.glassBorder, lineWidth: 0.5))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.top, 2)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hoverGlass(flatBackground: theme.card, cornerRadius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.accent.opacity(isHovered ? 0.06 : 0))
        )
        .onHover { isHovered = $0 }
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

private struct ReadingSuggestion: Identifiable {
    let id = UUID()
    var title: String
    var reason: String
    var domain: String
}


