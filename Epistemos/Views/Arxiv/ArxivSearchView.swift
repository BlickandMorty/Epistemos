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
        let trimmed = bounded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else {
            return trimmed
        }
        return String(trimmed.prefix(limit - 3)) + "..."
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
    @State private var ingestTasks: [String: Task<Void, Never>] = [:]

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
            HStack {
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
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(inputBackground)
                    )
                    .onSubmit {
                        startSearch()
                    }

                ToolbarCapsuleButton(
                    title: nil,
                    systemImage: isSearching ? "hourglass" : "magnifyingglass",
                    role: .primaryAction,
                    isActive: isSearching,
                    chromePolicy: .alwaysSurface,
                    helpText: "Search arXiv",
                    accessibilityLabel: "Search arXiv"
                ) {
                    startSearch()
                }
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(mutedTint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !ArxivPullGateStatus.status().isActive {
                ContentUnavailableView(
                    "arXiv pull disabled",
                    systemImage: "lock",
                    description: Text(ArxivPullGateStatus.status().detail)
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else if papers.isEmpty {
                ContentUnavailableView(
                    "Search arXiv",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Search metadata, then add a paper to the vault after local PDF→Markdown conversion succeeds.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
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
        .frame(minWidth: 680, minHeight: 520)
        .onDisappear {
            cancelActiveTasks()
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
        searchTask = Task {
            await search()
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
        case .imported(_, let title):
            importedIDs.insert(paper.id)
            statusMessage = ArxivSearchPresentation.status("Added \(title).")
        case .rejected(.cancelled):
            statusMessage = nil
        case .rejected(let error):
            statusMessage = ArxivSearchPresentation.status(ArxivSearchDiagnostics.statusMessage(for: error))
        }
    }
}
