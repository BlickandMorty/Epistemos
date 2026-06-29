import SwiftData
import SwiftUI

struct ArxivSearchView: View {
    @Environment(VaultSyncService.self) private var vaultSync
    @Environment(GraphState.self) private var graphState
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                IntegrationBrandMarkView(brand: .arxiv, size: 24)
                    .foregroundStyle(.secondary)
                Text("arXiv")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("Close")
            }

            HStack(spacing: 10) {
                TextField("Search papers", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        startSearch()
                    }

                Button {
                    startSearch()
                } label: {
                    if isSearching {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                .help("Search arXiv")
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                                Divider()
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
                Text(paper.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text(paper.authors.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(paper.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)

                HStack(spacing: 8) {
                    Text(paper.shortID)
                    if !paper.categories.isEmpty {
                        Text(paper.categories.joined(separator: ", "))
                    }
                }
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 16)

            Button {
                startIngest(paper)
            } label: {
                if ingestingIDs.contains(paper.id) {
                    ProgressView().controlSize(.small)
                } else if importedIDs.contains(paper.id) {
                    Image(systemName: "checkmark.circle.fill")
                } else {
                    Image(systemName: "plus.circle")
                }
            }
            .disabled(ingestingIDs.contains(paper.id) || importedIDs.contains(paper.id))
            .help(importedIDs.contains(paper.id) ? "Added to vault" : "Add to vault")
        }
        .padding(.vertical, 12)
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
            statusMessage = error.localizedDescription
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
            statusMessage = "Added \(title)."
        case .rejected(.cancelled):
            statusMessage = nil
        case .rejected(let error):
            statusMessage = error.localizedDescription
        }
    }
}
