import Combine
import Foundation
import SwiftUI

nonisolated struct HTMLWorkspaceDataFeedResult: Codable, Equatable, Sendable {
    let pageID: String
    let title: String
    let snippet: String
    let rank: Double
    let contextKind: String
    let sourceLabel: String
    let provenance: String

    init(
        pageID: String,
        title: String,
        snippet: String,
        rank: Double,
        contextKind: String = "vault_record",
        sourceLabel: String = "Vault search result",
        provenance: String = HTMLWorkspaceDataFeedJSONEnvelope.provenance
    ) {
        self.pageID = pageID
        self.title = title
        self.snippet = snippet
        self.rank = rank
        self.contextKind = contextKind
        self.sourceLabel = sourceLabel
        self.provenance = provenance
    }

    private enum CodingKeys: String, CodingKey {
        case pageID = "page_id"
        case title
        case snippet
        case rank
        case contextKind = "context_kind"
        case sourceLabel = "source_label"
        case provenance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pageID = try container.decode(String.self, forKey: .pageID)
        title = try container.decode(String.self, forKey: .title)
        snippet = try container.decode(String.self, forKey: .snippet)
        rank = try container.decode(Double.self, forKey: .rank)
        contextKind = try container.decodeIfPresent(String.self, forKey: .contextKind) ?? "vault_record"
        sourceLabel = try container.decodeIfPresent(String.self, forKey: .sourceLabel) ?? "Vault search result"
        provenance = try container.decodeIfPresent(String.self, forKey: .provenance)
            ?? HTMLWorkspaceDataFeedJSONEnvelope.provenance
    }
}

nonisolated struct HTMLWorkspaceDataFeedMetadata: Codable, Equatable, Sendable {
    let source: String
    let query: String
    let limit: Int
    let resultCount: Int
    let contextKinds: [String]
    let refreshedAtMS: Int64
    let provenance: String
    let stale: Bool
    let status: String
    let error: String?

    private enum CodingKeys: String, CodingKey {
        case source
        case query
        case limit
        case resultCount = "result_count"
        case contextKinds = "context_kinds"
        case refreshedAtMS = "refreshed_at_ms"
        case provenance
        case stale
        case status
        case error
    }

    init(
        source: String,
        query: String,
        limit: Int,
        resultCount: Int,
        contextKinds: [String],
        refreshedAtMS: Int64,
        provenance: String,
        stale: Bool,
        status: String,
        error: String?
    ) {
        self.source = source
        self.query = query
        self.limit = limit
        self.resultCount = resultCount
        self.contextKinds = contextKinds
        self.refreshedAtMS = refreshedAtMS
        self.provenance = provenance
        self.stale = stale
        self.status = status
        self.error = error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try container.decode(String.self, forKey: .source)
        query = try container.decode(String.self, forKey: .query)
        limit = try container.decode(Int.self, forKey: .limit)
        resultCount = try container.decode(Int.self, forKey: .resultCount)
        contextKinds = try container.decodeIfPresent([String].self, forKey: .contextKinds) ?? []
        refreshedAtMS = try container.decode(Int64.self, forKey: .refreshedAtMS)
        provenance = try container.decode(String.self, forKey: .provenance)
        stale = try container.decode(Bool.self, forKey: .stale)
        status = try container.decode(String.self, forKey: .status)
        error = try container.decodeIfPresent(String.self, forKey: .error)
    }
}

nonisolated struct HTMLWorkspaceDataFeedEnvelope: Codable, Equatable, Sendable {
    let results: [HTMLWorkspaceDataFeedResult]
    let epistemos: HTMLWorkspaceDataFeedMetadata

    private enum CodingKeys: String, CodingKey {
        case results
        case epistemos = "_epistemos"
    }
}

nonisolated enum HTMLWorkspaceDataFeedRenderer {
    static let provenance = HTMLWorkspaceDataFeedJSONEnvelope.provenance

    static func render(
        feed: HTMLWorkspaceDataFeed,
        results: [SearchResult],
        refreshedAt: Date = Date()
    ) -> String {
        render(
            feed: feed,
            results: results.map {
                HTMLWorkspaceDataFeedResult(
                    pageID: $0.pageId,
                    title: $0.title,
                    snippet: $0.snippet,
                    rank: $0.rank
                )
            },
            refreshedAt: refreshedAt,
            stale: false,
            status: "fresh",
            error: nil
        )
    }

    static func staleRender(
        feed: HTMLWorkspaceDataFeed,
        error: String,
        refreshedAt: Date? = nil
    ) -> String {
        HTMLWorkspaceDataFeedJSONEnvelope.staleDataJSON(
            feed: feed,
            error: error,
            refreshedAtMS: refreshedAt.map { Int64($0.timeIntervalSince1970 * 1_000) } ?? 0
        )
    }

    private static func render(
        feed: HTMLWorkspaceDataFeed,
        results: [HTMLWorkspaceDataFeedResult],
        refreshedAt: Date,
        stale: Bool,
        status: String,
        error: String?
    ) -> String {
        render(
            feed: feed,
            results: results,
            refreshedAtMS: Int64(refreshedAt.timeIntervalSince1970 * 1_000),
            stale: stale,
            status: status,
            error: error
        )
    }

    private static func render(
        feed: HTMLWorkspaceDataFeed,
        results: [HTMLWorkspaceDataFeedResult],
        refreshedAtMS: Int64,
        stale: Bool,
        status: String,
        error: String?
    ) -> String {
        let metadata = HTMLWorkspaceDataFeedMetadata(
            source: feed.source.rawValue,
            query: feed.normalizedQuery,
            limit: feed.effectiveLimit,
            resultCount: results.count,
            contextKinds: contextKinds(from: results),
            refreshedAtMS: refreshedAtMS,
            provenance: provenance,
            stale: stale,
            status: status,
            error: error
        )
        let envelope = HTMLWorkspaceDataFeedEnvelope(
            results: results,
            epistemos: metadata
        )
        guard let data = try? JSONEncoder.epdocCanonical.encode(envelope),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"results":[],"_epistemos":{"source":"vault_search","query":"","limit":0,"result_count":0,"context_kinds":["vault_record"],"refreshed_at_ms":0,"provenance":"VaultSyncService.searchFullAsync","stale":true,"status":"stale","error":"data feed encoding failed"}}"#
        }
        return json
    }

    private static func contextKinds(from results: [HTMLWorkspaceDataFeedResult]) -> [String] {
        let kinds = Set(results.map(\.contextKind).filter { !$0.isEmpty })
        return kinds.isEmpty ? ["vault_record"] : kinds.sorted()
    }
}

nonisolated enum HTMLWorkspaceDataFeedStatus {
    static func metadata(from dataJSON: String) -> HTMLWorkspaceDataFeedMetadata? {
        guard let data = dataJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder.epdocCanonical
            .decode(HTMLWorkspaceDataFeedEnvelope.self, from: data)
            .epistemos
    }

    @MainActor
    static func shouldRefresh(for notification: Notification) -> Bool {
        guard let dependencies = QueryDependencyKey.from(notification) else { return true }
        let searchDependencies: Set<QueryDependencyKey> = [.searchPages, .searchBlocks, .searchReadable]
        return !dependencies.isDisjoint(with: searchDependencies)
    }

    @MainActor
    static func compactLine(for package: HTMLWorkspacePackage) -> String? {
        guard package.manifest.dataFeed != nil else { return nil }
        guard let metadata = metadata(from: package.dataJSON) else { return "Feed pending" }
        return metadata.stale
            ? "Feed stale"
            : "Feed fresh: \(metadata.resultCount)"
    }

    @MainActor
    static func detailLine(for package: HTMLWorkspacePackage) -> String? {
        guard let feed = package.manifest.dataFeed else { return nil }
        guard let metadata = metadata(from: package.dataJSON) else {
            return "Vault search: \(feed.normalizedQuery)"
        }
        let age = refreshedAgeText(refreshedAtMS: metadata.refreshedAtMS)
        let kinds = metadata.contextKinds.isEmpty ? "none" : metadata.contextKinds.joined(separator: ", ")
        let errorSuffix = metadata.error.map { " / \($0)" } ?? ""
        return "\(metadata.query) / \(age) / kinds: \(kinds) / \(metadata.provenance)\(errorSuffix)"
    }

    @MainActor
    private static func refreshedAgeText(refreshedAtMS: Int64) -> String {
        guard refreshedAtMS > 0 else { return "never refreshed" }
        let refreshedAt = Date(timeIntervalSince1970: Double(refreshedAtMS) / 1_000)
        let seconds = max(0, Int(Date().timeIntervalSince(refreshedAt)))
        if seconds < 60 { return "refreshed \(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "refreshed \(minutes)m ago" }
        let hours = minutes / 60
        return "refreshed \(hours)h ago"
    }
}

@MainActor
struct HTMLWorkspaceDataFeedBinder: ViewModifier {
    @Binding var package: HTMLWorkspacePackage
    @Binding var statusText: String?
    @State private var refreshTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onAppear {
                scheduleRefresh(reason: "initial")
            }
            .onChange(of: package.manifest.dataFeed) { _, _ in
                scheduleRefresh(reason: "feed changed")
            }
            .onReceive(NotificationCenter.default.publisher(for: .searchIndexDidUpdate)) { notification in
                guard package.manifest.dataFeed != nil,
                      HTMLWorkspaceDataFeedStatus.shouldRefresh(for: notification) else { return }
                scheduleRefresh(reason: "search index updated")
            }
            .onDisappear {
                refreshTask?.cancel()
                refreshTask = nil
            }
    }

    private func scheduleRefresh(reason: String) {
        refreshTask?.cancel()
        guard let feed = package.manifest.dataFeed else {
            refreshTask = nil
            return
        }
        guard feed.isRunnable else {
            applyStaleRender(feed: feed, error: "Data feed query is empty")
            return
        }
        guard let vaultSync = AppBootstrap.shared?.vaultSync else {
            applyStaleRender(feed: feed, error: "Vault feed unavailable")
            return
        }

        refreshTask = Task { @MainActor in
            if reason != "initial" {
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            guard !Task.isCancelled else { return }
            statusText = "Refreshing data feed"
            let results = await vaultSync.searchFullAsync(
                query: feed.normalizedQuery,
                limit: feed.effectiveLimit
            )
            guard !Task.isCancelled else { return }
            let nextJSON = HTMLWorkspaceDataFeedRenderer.render(feed: feed, results: results)
            if package.dataJSON != nextJSON {
                package.dataJSON = nextJSON
            }
            statusText = "Data feed refreshed"
        }
    }

    private func applyStaleRender(feed: HTMLWorkspaceDataFeed, error: String) {
        let nextJSON = HTMLWorkspaceDataFeedRenderer.staleRender(feed: feed, error: error)
        if package.dataJSON != nextJSON {
            package.dataJSON = nextJSON
        }
        statusText = error
    }
}

extension View {
    @MainActor
    func htmlWorkspaceDataFeed(
        package: Binding<HTMLWorkspacePackage>,
        statusText: Binding<String?>
    ) -> some View {
        modifier(HTMLWorkspaceDataFeedBinder(package: package, statusText: statusText))
    }
}

@MainActor
struct HTMLWorkspaceDataFeedStatusStrip: View {
    let package: HTMLWorkspacePackage
    var compact = false

    var body: some View {
        if let summary = HTMLWorkspaceDataFeedStatus.compactLine(for: package) {
            HStack(spacing: 6) {
                Image(systemName: isStale ? "exclamationmark.triangle" : "arrow.triangle.2.circlepath")
                    .foregroundStyle(isStale ? .orange : .secondary)
                Text(summary)
                    .font(.caption2.weight(.semibold))
                if !compact, let detail = HTMLWorkspaceDataFeedStatus.detailLine(for: package) {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .help(HTMLWorkspaceDataFeedStatus.detailLine(for: package) ?? summary)
        }
    }

    private var isStale: Bool {
        HTMLWorkspaceDataFeedStatus.metadata(from: package.dataJSON)?.stale == true
    }
}
