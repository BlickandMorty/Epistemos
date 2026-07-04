import AppKit
import SwiftData
import SwiftUI

nonisolated enum ArxivSearchPresentation {
    static let maxTitleCharacters = 300
    static let maxAuthorsCharacters = 240
    static let maxSummaryCharacters = 1_000
    static let maxMetadataCharacters = 240
    static let maxStatusMessageCharacters = 360

    static func title(_ value: String) -> String {
        capped(value, limit: maxTitleCharacters)
    }

    static func authors(_ values: [String]) -> String {
        capped(values.joined(separator: ", "), limit: maxAuthorsCharacters)
    }

    static func summary(_ value: String) -> String {
        capped(value, limit: maxSummaryCharacters)
    }

    static func metadata(_ value: String) -> String {
        capped(value, limit: maxMetadataCharacters)
    }

    static func status(_ value: String) -> String {
        capped(value, limit: maxStatusMessageCharacters)
    }

    private static func capped(_ value: String, limit: Int) -> String {
        let bounded = String(value.prefix(limit + 32))
        let trimmed = ArxivSearchDiagnostics.normalizedDisplayText(bounded)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else {
            return trimmed
        }
        return (String(trimmed.prefix(limit - 3)) + "...")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct ArxivSearchView: View {
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(GraphState.self) private var graphState
    @Environment(UIState.self) private var ui
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var papers: [ArxivPaper] = []
    @State private var isSearching = false
    @State private var statusMessage: String?
    @State private var ingestingIDs: Set<String> = []
    @State private var importedIDs: Set<String> = []
    @State private var searchTask: Task<Void, Never>?
    @State private var didLoadFeaturedFeed = false
    @State private var featuredFeedFailed = false
    @State private var ingestTasks: [String: Task<Void, Never>] = [:]
    @State private var selectedCategory: String?

    /// Quick-browse arXiv categories (owner 2026-07-03: more arXiv functionality).
    private static let browseCategories: [(label: String, code: String)] = [
        ("AI", "cs.AI"),
        ("ML", "cs.LG"),
        ("NLP", "cs.CL"),
        ("Vision", "cs.CV"),
        ("Robotics", "cs.RO"),
        ("Systems", "cs.DC"),
    ]

    private let client = ArxivClient()

    private var mutedTint: Color {
        ui.theme.resolved.mutedForeground.color
    }

    private var tertiaryTint: Color {
        mutedTint.opacity(0.74)
    }

    private var inputBackground: Color {
        ui.theme.surfaceVariant(.other).resolved.card.color.opacity(ui.theme.isDark ? 0.34 : 0.58)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: "house",
                    role: .secondaryGhost,
                    helpText: "Back to home",
                    accessibilityLabel: "Back to home"
                ) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) {
                        ui.homeContent = .greeting
                    }
                }
                IntegrationBrandMarkView(brand: .arxiv, size: 24)
                    .foregroundStyle(mutedTint)
                Text("arXiv")
                    .font(.title2.weight(.semibold))
                Spacer()
                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: "xmark",
                    role: .secondaryGhost,
                    helpText: "Close",
                    accessibilityLabel: "Close arXiv search"
                ) {
                    dismiss()
                }
            }

            HStack(spacing: 10) {
                TextField("Search papers", text: $query)
                    .textFieldStyle(.plain)
                    .foregroundStyle(ui.theme.resolved.foreground.color)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 38)
                    .background(
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        ui.theme.resolved.foreground.color.opacity(0.10),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .shadow(color: .black.opacity(0.16), radius: 10, y: 3)
                    .onSubmit {
                        startSearch()
                    }

                // #4 (audit 2026-07-03): while a search/category load is in flight the button
                // becomes an enabled Stop that cancels it — previously it was a disabled hourglass,
                // so a slow/stuck search could only be escaped by navigating away.
                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: isSearching ? "xmark" : "magnifyingglass",
                    role: .primaryAction,
                    isActive: isSearching,
                    chromePolicy: .alwaysSurface,
                    helpText: isSearching ? "Stop searching" : "Search arXiv",
                    accessibilityLabel: isSearching ? "Stop searching arXiv" : "Search arXiv"
                ) {
                    if isSearching {
                        cancelSearch()
                    } else {
                        startSearch()
                    }
                }
                .disabled(!isSearching && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            categoryChips

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(mutedTint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !Self.arxivGateActive {
                ContentUnavailableView(
                    "arXiv pull disabled",
                    systemImage: "lock",
                    description: Text(ArxivPullGateStatus.status().detail)
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else if papers.isEmpty {
                if isSearching {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading featured papers…")
                            .font(.callout)
                            .foregroundStyle(mutedTint)
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else if featuredFeedFailed && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // #6 (audit 2026-07-03): a featured-feed load that failed at cold start
                    // (offline on open) previously dead-ended — the one-shot guard is set before
                    // the fetch, so it never retried and offered no Retry. Now it surfaces one.
                    ContentUnavailableView {
                        Label("Couldn't reach arXiv", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("Check your connection, then retry — or search above.")
                    } actions: {
                        Button("Retry") { retryFeaturedFeed() }
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    ContentUnavailableView(
                        "Search arXiv",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Search papers by title, author, or category. Featured AI & ML papers load automatically.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(papers) { paper in
                            paperRow(paper)
                            if paper.id != papers.last?.id {
                                rowGap
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .task {
            startFeaturedFeedLoad()
        }
        .onDisappear {
            cancelActiveTasks()
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.browseCategories, id: \.code) { category in
                    let isSelected = selectedCategory == category.code
                    Button {
                        loadCategory(category.code, label: category.label)
                    } label: {
                        Text(category.label)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                isSelected
                                    ? ui.theme.resolved.background.color
                                    : ui.theme.resolved.foreground.color.opacity(0.82)
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(
                                        isSelected
                                            ? ui.theme.resolved.accent.color
                                            : ui.theme.resolved.card.color.opacity(0.5)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSearching)
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// Browse recent papers in a specific arXiv category (owner request 2026-07-03).
    private func loadCategory(_ code: String, label: String) {
        searchTask?.cancel()
        selectedCategory = code
        query = ""
        searchTask = Task {
            isSearching = true
            defer { isSearching = false; searchTask = nil }
            do {
                let results = try await client.search(query: "cat:\(code)", maxResults: 20)
                guard !Task.isCancelled else { return }
                papers = results
                statusMessage = results.isEmpty
                    ? "No recent \(label) papers found — try a search above."
                    : "Recent \(label) papers. Search above, or pick another category."
            } catch is CancellationError {
                return
            } catch {
                statusMessage = "Couldn't load \(label) papers. Tap again to retry."
            }
        }
    }

    /// On open, show a live feed of recent AI/ML papers instead of an empty
    /// search state (owner request 2026-07-03) — makes arXiv an interesting
    /// research surface immediately. Only runs once, only if the user hasn't
    /// already typed a query, and only when the arXiv pull gate is active.
    private func loadFeaturedFeedIfNeeded() async {
        guard !didLoadFeaturedFeed,
              papers.isEmpty,
              query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              ArxivPullGateStatus.status().isActive
        else { return }
        didLoadFeaturedFeed = true
        isSearching = true
        defer { isSearching = false }
        do {
            // Single-category query (robust: avoids the strict request/response
            // URL-equality check that a multi-category OR query can trip). cs.LG
            // (Machine Learning) covers most current AI research via cross-listing.
            var featured = try await client.search(query: "cat:cs.LG", maxResults: 14)
            if featured.isEmpty {
                featured = try await client.search(query: "all:machine learning", maxResults: 14)
            }
            // Only populate if the user hasn't started their own search meanwhile.
            guard papers.isEmpty,
                  query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return }
            papers = featured
            statusMessage = featured.isEmpty
                ? "Couldn't load featured papers right now — search above to find papers."
                : "Featured — recent Machine Learning papers. Search above for anything else."
        } catch is CancellationError {
            // Navigated away mid-load — normal cancellation, not an error.
            return
        } catch {
            // #6: never fail silently to a blank screen — tell the user AND surface a Retry
            // affordance (the empty state reads `featuredFeedFailed`) instead of dead-ending.
            featuredFeedFailed = true
            statusMessage = "Couldn't reach arXiv (\(ArxivSearchPresentation.status("\(error)"))). Search above to try again."
        }
    }

    private func paperRow(_ paper: ArxivPaper) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(ArxivSearchPresentation.title(paper.title))
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text(ArxivSearchPresentation.authors(paper.authors))
                    .font(.caption)
                    .foregroundStyle(mutedTint)
                    .lineLimit(2)

                Text(ArxivSearchPresentation.summary(paper.summary))
                    .font(.caption)
                    .foregroundStyle(mutedTint)
                    .lineLimit(4)

                HStack(spacing: 8) {
                    Text(ArxivSearchPresentation.metadata(paper.shortID))
                    if !paper.categories.isEmpty {
                        Text(ArxivSearchPresentation.metadata(paper.categories.joined(separator: ", ")))
                    }
                }
                .font(.caption.monospaced())
                .foregroundStyle(tertiaryTint)
            }

            Spacer(minLength: 16)

            ToolbarCapsuleButton(
                title: nil,
                systemImage: "safari",
                role: .toolbarUtility,
                chromePolicy: .alwaysSurface,
                helpText: "View paper in the themed in-app browser",
                accessibilityLabel: "View paper in the in-app browser"
            ) {
                openPaperInBrowser(paper)
            }

            ToolbarCapsuleButton(
                title: nil,
                systemImage: "quote.opening",
                role: .toolbarUtility,
                chromePolicy: .alwaysSurface,
                helpText: "Copy citation",
                accessibilityLabel: "Copy citation"
            ) {
                copyCitation(for: paper)
            }

            ToolbarCapsuleButton(
                title: nil,
                systemImage: ingestActionImage(for: paper),
                role: importedIDs.contains(paper.id) ? .toolbarUtility : .primaryAction,
                isActive: ingestingIDs.contains(paper.id) || importedIDs.contains(paper.id),
                chromePolicy: .alwaysSurface,
                helpText: ingestActionHelp(for: paper),
                accessibilityLabel: ingestActionHelp(for: paper)
            ) {
                startIngest(paper)
            }
            .disabled(ingestingIDs.contains(paper.id) || importedIDs.contains(paper.id))
        }
        .padding(.vertical, 12)
    }

    private var rowGap: some View {
        Color.clear.frame(height: 6)
    }

    // GAP-23 (audit 2026-07-03): copy a plain-text citation for the paper.
    private func citation(for paper: ArxivPaper) -> String {
        let authors = paper.authors.isEmpty ? "" : "\(paper.authors.joined(separator: ", ")). "
        let year = paper.published.map { " (\(Calendar.current.component(.year, from: $0)))" } ?? ""
        return "\(authors)\"\(paper.title)\". arXiv:\(paper.id)\(year)."
    }

    private func copyCitation(for paper: ArxivPaper) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(citation(for: paper), forType: .string)
    }

    private func openPaperInBrowser(_ paper: ArxivPaper) {
        // View the paper in the themed in-app browser tab (owner request
        // 2026-07-03) — arXiv's abs page renders with the Epistemos palette +
        // pixel headings, and can be saved to notes from there.
        let absURL = paper.shortID.isEmpty
            ? paper.id
            : "https://arxiv.org/abs/\(paper.shortID)"
        NoteWindowManager.shared.openBrowserTab(url: absURL)
    }

    private func ingestActionImage(for paper: ArxivPaper) -> String {
        if ingestingIDs.contains(paper.id) {
            return "hourglass"
        }
        if importedIDs.contains(paper.id) {
            return "checkmark.circle.fill"
        }
        return "plus.circle"
    }

    private func ingestActionHelp(for paper: ArxivPaper) -> String {
        if ingestingIDs.contains(paper.id) {
            return "Adding to vault"
        }
        if importedIDs.contains(paper.id) {
            return "Added to vault"
        }
        return "Add to vault"
    }

    private func startSearch() {
        guard !isSearching else { return }
        searchTask?.cancel()
        selectedCategory = nil
        featuredFeedFailed = false
        searchTask = Task {
            await search()
            searchTask = nil
        }
    }

    /// #4: cancel an in-flight search/category load from the Stop button. We only cancel —
    /// the running task's own `defer { isSearching = false }` flips the button back when it
    /// unwinds on CancellationError, which avoids a start-while-cancelling race on searchTask.
    private func cancelSearch() {
        searchTask?.cancel()
    }

    /// #6: retry the featured feed after a cold-start network failure. Resets the one-shot
    /// guard and re-runs the loader; the result (or another failure) updates the empty state.
    private func retryFeaturedFeed() {
        featuredFeedFailed = false
        didLoadFeaturedFeed = false
        searchTask?.cancel()
        searchTask = Task {
            await loadFeaturedFeedIfNeeded()
            searchTask = nil
        }
    }

    /// ARX-CANCEL-1 (audit 2026-07-04): route the INITIAL featured load through searchTask (like
    /// retryFeaturedFeed) so the Stop button + an explicit search can cancel/preempt the cold-start
    /// load. loadFeaturedFeedIfNeeded sets isSearching=true; without an assigned searchTask the Stop
    /// handle was nil (a dead affordance) and startSearch's `guard !isSearching` blocked new searches
    /// for up to the 15s request timeout — re-opening the hole #4 closed. onDisappear→cancelActiveTasks
    /// cancels it, matching the prior `.task`-modifier disappear-cancellation.
    /// ARX-PERF-1 (audit 2026-07-04): the arXiv pull gate reads + copies the full process environment;
    /// env vars are fixed at launch so the result is process-invariant. Cache it once instead of
    /// re-copying the environment on every body re-eval (per keystroke).
    private static let arxivGateActive = ArxivPullGateStatus.status().isActive

    private func startFeaturedFeedLoad() {
        guard searchTask == nil else { return }
        searchTask = Task {
            await loadFeaturedFeedIfNeeded()
            searchTask = nil
        }
    }

    private func startIngest(_ paper: ArxivPaper) {
        guard !ingestingIDs.contains(paper.id), !importedIDs.contains(paper.id) else { return }
        ingestTasks[paper.id]?.cancel()
        ingestTasks[paper.id] = Task {
            await ingest(paper)
            ingestTasks[paper.id] = nil
        }
    }

    private func cancelActiveTasks() {
        searchTask?.cancel()
        searchTask = nil
        for task in ingestTasks.values {
            task.cancel()
        }
        ingestTasks.removeAll()
        isSearching = false
        ingestingIDs.removeAll()
    }

    private func search() async {
        guard ArxivPullGateStatus.status().isActive else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        defer { isSearching = false }

        do {
            papers = try await client.search(query: trimmed, maxResults: 12)
            statusMessage = papers.isEmpty ? "No arXiv papers matched." : "\(papers.count) papers found."
        } catch is CancellationError {
            statusMessage = nil
        } catch {
            papers = []
            statusMessage = ArxivSearchPresentation.status(ArxivSearchDiagnostics.statusMessage(for: error))
        }
    }

    private func ingest(_ paper: ArxivPaper) async {
        guard let vaultURL = vaultSync.vaultURL else {
            statusMessage = "Connect a vault before adding arXiv papers."
            return
        }

        ingestingIDs.insert(paper.id)
        defer { ingestingIDs.remove(paper.id) }

        let outcome = await ArxivIngestService.ingest(
            paper: paper,
            vaultURL: vaultURL,
            modelContext: modelContext,
            graphState: graphState
        )
        switch outcome {
        case .imported(_, let title, let sourcePDFRelativePath):
            importedIDs.insert(paper.id)
            statusMessage = ArxivSearchPresentation.status("Added \(title). Source PDF: \(sourcePDFRelativePath).")
        case .rejected(.cancelled):
            statusMessage = nil
        case .rejected(let error):
            statusMessage = ArxivSearchPresentation.status(ArxivSearchDiagnostics.statusMessage(for: error))
        }
    }
}
