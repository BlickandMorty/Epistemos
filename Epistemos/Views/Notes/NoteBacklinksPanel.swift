import SwiftUI
import SwiftData

// MARK: - Backlinks Popover
// Native popover content showing notes that link TO the current note via [[wikilinks]].

struct NoteBacklinksPopover: View {
    private struct BacklinkItem: Identifiable, Sendable, Equatable {
        let id: String
        let title: String
        var filePath: String? = nil
        var inlineBody: String = ""
        var wikilinkReferences: [String] = []
        var edgeType: String? = nil  // semantic edge type (supports, contradicts, etc.)
        var source: BacklinkSource = .wikilink

        enum BacklinkSource: Sendable, Equatable {
            case wikilink       // found via [[pageTitle]] text scan
            case graphEdge      // found via GraphStore semantic edge
        }
    }

    let pageTitle: String
    let pageId: String?
    let onNavigate: (String) -> Void // pageId
    var graphState: GraphState?

    @Environment(\.modelContext) private var modelContext
    @State private var backlinks: [BacklinkItem] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.system(size: 10, weight: .semibold))
                    Text("\(backlinks.count) Backlink\(backlinks.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

                ForEach(backlinks) { link in
                    Button {
                        onNavigate(link.id)
                    } label: {
                        HStack(spacing: 4) {
                            Text(link.title.isEmpty ? "Untitled" : link.title)
                                .font(.system(size: 12, weight: .regular))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(.primary)

                            Spacer()

                            // Show semantic edge type badge for graph-sourced backlinks
                            if let edgeType = link.edgeType {
                                Text(edgeType)
                                    .font(.system(size: 9, weight: .medium))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(edgeBadgeColor(edgeType).opacity(0.15))
                                    .foregroundStyle(edgeBadgeColor(edgeType))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if backlinks.isEmpty {
                    Text("No backlinks found")
                        .font(.system(size: 11))
                        .foregroundStyle(.quaternary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
            }
            .padding(6)
        }
        .frame(width: 260).frame(maxHeight: 400)
        .task { await scanBacklinks() }
    }

    private func edgeBadgeColor(_ type: String) -> Color {
        switch type {
        case "supports":    return .green
        case "contradicts": return .red
        case "expands":     return .blue
        case "questions":   return .orange
        default:            return .secondary
        }
    }

    private func scanBacklinks() async {
        guard !pageTitle.isEmpty else { return }
        let targetKeys = Set(WikilinkResolver.lookupKeys(forDestination: pageTitle))
        let titleToFind = pageTitle

        // Phase 1: Text-based backlinks (existing [[wikilink]] scan)
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.isArchived == false }
        )
        let allPages: [SDPage]
        do {
            allPages = try modelContext.fetch(descriptor)
        } catch {
            Log.notes.error(
                "NoteBacklinksPopover: failed to fetch pages for backlink scan: \(error.localizedDescription, privacy: .public)"
            )
            return
        }

        let candidates = allPages.compactMap { page -> BacklinkItem? in
            guard page.title != titleToFind else { return nil }
            return BacklinkItem(
                id: page.id,
                title: page.title,
                filePath: page.filePath,
                inlineBody: page.body,
                wikilinkReferences: page.wikilinkReferences
            )
        }
        var results = await Self.findBacklinks(candidates: candidates, targetKeys: targetKeys)
        let textBacklinkIds = Set(results.map(\.id))

        // Phase 2: Graph-based semantic edges (supports, contradicts, expands, questions)
        if let graphState, let currentPageId = pageId {
            let graphBacklinks = await graphState.incomingEdges(forPageId: currentPageId)
            for (sourcePageId, sourceTitle, edgeType) in graphBacklinks {
                // Don't duplicate items already found via text scan
                guard !textBacklinkIds.contains(sourcePageId) else { continue }
                results.append(BacklinkItem(
                    id: sourcePageId,
                    title: sourceTitle,
                    edgeType: edgeType,
                    source: .graphEdge
                ))
            }
        }

        if !Task.isCancelled {
            backlinks = results
        }
    }

    private nonisolated static func findBacklinks(
        candidates: [BacklinkItem],
        targetKeys: Set<String>
    ) async -> [BacklinkItem] {
        await Task.detached(priority: .utility) { () async -> [BacklinkItem] in
            var results: [BacklinkItem] = []
            results.reserveCapacity(min(candidates.count, 16))

            for candidate in candidates {
                if Task.isCancelled {
                    return []
                }
                if candidate.wikilinkReferences.contains(where: {
                    WikilinkResolver.destinationMatches($0, targetKeys: targetKeys)
                }) {
                    results.append(candidate)
                    continue
                }
                guard candidate.wikilinkReferences.isEmpty else { continue }

                let body = await SDPage.loadBodyAsyncFromPrimitives(
                    pageId: candidate.id,
                    filePath: candidate.filePath,
                    inlineBody: candidate.inlineBody,
                    mapped: true,
                    fast: true
                )
                let links = WikilinkResolver.extractDestinations(from: body)
                if links.contains(where: { WikilinkResolver.destinationMatches($0, targetKeys: targetKeys) }) {
                    results.append(candidate)
                }
            }

            results.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            return results
        }.value
    }
}
