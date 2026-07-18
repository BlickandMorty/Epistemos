import Combine
import Foundation
import SwiftData
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
        self.rank = rank.isFinite ? rank : 0
        self.contextKind = Self.normalizedContextKind(contextKind)
        self.sourceLabel = Self.normalizedNonEmpty(sourceLabel, default: "Vault search result")
        self.provenance = Self.normalizedNonEmpty(provenance, default: HTMLWorkspaceDataFeedJSONEnvelope.provenance)
    }

    init(searchResult: SearchResult) {
        self.init(
            pageID: searchResult.pageId,
            title: searchResult.title,
            snippet: searchResult.snippet,
            rank: searchResult.rank
        )
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
        contextKind = Self.normalizedContextKind(
            try container.decodeIfPresent(String.self, forKey: .contextKind) ?? "vault_record"
        )
        sourceLabel = Self.normalizedNonEmpty(
            try container.decodeIfPresent(String.self, forKey: .sourceLabel),
            default: "Vault search result"
        )
        provenance = Self.normalizedNonEmpty(
            try container.decodeIfPresent(String.self, forKey: .provenance),
            default: HTMLWorkspaceDataFeedJSONEnvelope.provenance
        )
    }

    private static func normalizedContextKind(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "vault_record" : trimmed
    }

    private static func normalizedNonEmpty(_ value: String?, default defaultValue: String) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? defaultValue : trimmed
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
    let requiredContextKind: String?
    let requiredContextAvailable: Bool?

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
        case requiredContextKind = "required_context_kind"
        case requiredContextAvailable = "required_context_available"
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
        error: String?,
        requiredContextKind: String? = nil,
        requiredContextAvailable: Bool? = nil
    ) {
        self.source = Self.normalizedNonEmpty(source, default: HTMLWorkspaceDataFeed.Source.vaultSearch.rawValue)
        self.query = Self.normalizedTrimmed(query)
        self.limit = limit
        self.resultCount = resultCount
        self.contextKinds = Self.normalizedContextKinds(contextKinds)
        self.refreshedAtMS = refreshedAtMS
        self.provenance = Self.normalizedNonEmpty(provenance, default: HTMLWorkspaceDataFeedJSONEnvelope.provenance)
        self.stale = stale
        self.status = Self.normalizedNonEmpty(status, default: stale ? "stale" : "fresh")
        self.error = Self.normalizedOptional(error)
        self.requiredContextKind = Self.normalizedOptional(requiredContextKind)
        self.requiredContextAvailable = requiredContextAvailable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedStale = try container.decode(Bool.self, forKey: .stale)
        source = Self.normalizedNonEmpty(
            try container.decodeIfPresent(String.self, forKey: .source),
            default: HTMLWorkspaceDataFeed.Source.vaultSearch.rawValue
        )
        query = Self.normalizedTrimmed(try container.decodeIfPresent(String.self, forKey: .query) ?? "")
        limit = try container.decode(Int.self, forKey: .limit)
        resultCount = try container.decode(Int.self, forKey: .resultCount)
        contextKinds = Self.normalizedContextKinds(try container.decodeIfPresent([String].self, forKey: .contextKinds) ?? [])
        refreshedAtMS = try container.decode(Int64.self, forKey: .refreshedAtMS)
        provenance = Self.normalizedNonEmpty(
            try container.decodeIfPresent(String.self, forKey: .provenance),
            default: HTMLWorkspaceDataFeedJSONEnvelope.provenance
        )
        stale = decodedStale
        status = Self.normalizedNonEmpty(
            try container.decodeIfPresent(String.self, forKey: .status),
            default: decodedStale ? "stale" : "fresh"
        )
        error = Self.normalizedOptional(try container.decodeIfPresent(String.self, forKey: .error))
        requiredContextKind = Self.normalizedOptional(try container.decodeIfPresent(String.self, forKey: .requiredContextKind))
        requiredContextAvailable = try container.decodeIfPresent(Bool.self, forKey: .requiredContextAvailable)
    }

    static func normalizedContextKinds(_ values: [String]) -> [String] {
        let kinds = Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        return kinds.sorted()
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedTrimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedNonEmpty(_ value: String?, default defaultValue: String) -> String {
        normalizedOptional(value) ?? defaultValue
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

@MainActor
enum HTMLWorkspaceDataFeedContextSources {
    static func results(
        for requiredContextKind: String?,
        searchResults: [SearchResult],
        modelContainer: ModelContainer?,
        limit: Int,
        query: String? = nil
    ) -> [HTMLWorkspaceDataFeedResult] {
        let requiredKind = normalized(requiredContextKind)
        if requiredKind == "recent_capture" || (requiredKind.isEmpty && shouldUseRecentCaptureResults(for: query)) {
            return recentCaptureResults(modelContainer: modelContainer, limit: limit)
        }
        if requiredKind == "note" || (requiredKind.isEmpty && shouldUseNoteResults(for: query)) {
            return noteResults(query: query, searchResults: searchResults, modelContainer: modelContainer, limit: limit)
        }
        if requiredKind == "pdf_note" || (requiredKind.isEmpty && shouldUsePDFNoteResults(for: query)) {
            return pdfNoteResults(query: query, modelContainer: modelContainer, limit: limit)
        }
        if requiredKind == "folder_note" || (requiredKind.isEmpty && shouldUseFolderNoteResults(for: query)) {
            return folderNoteResults(query: query, modelContainer: modelContainer, limit: limit)
        }
        if requiredKind == "meeting_note" || (requiredKind.isEmpty && shouldUseMeetingNoteResults(for: query)) {
            return meetingNoteResults(query: query, modelContainer: modelContainer, limit: limit)
        }
        if requiredKind == "web_clip" || (requiredKind.isEmpty && shouldUseWebClipResults(for: query)) {
            return webClipResults(query: query, modelContainer: modelContainer, limit: limit)
        }
        #if !EPISTEMOS_FREE_V1
        if requiredKind == "recent_chat" || (requiredKind.isEmpty && shouldUseRecentChatResults(for: query)) {
            return recentChatResults(query: query, modelContainer: modelContainer, limit: limit)
        }
        if requiredKind == "provenance_claim" || (requiredKind.isEmpty && shouldUseProvenanceClaimResults(for: query)) {
            return provenanceClaimResults(query: query, limit: limit)
        }
        #endif
        if requiredKind == "graph_related_note" || (requiredKind.isEmpty && shouldUseGraphRelatedNoteResults(for: query)) {
            return graphRelatedNoteResults(
                searchResults: searchResults,
                modelContainer: modelContainer,
                limit: limit
            )
        }
        return searchResults.map(HTMLWorkspaceDataFeedResult.init(searchResult:))
    }

    static func requiredContextKind(forFreeformQuery query: String?) -> String? {
        if shouldUseRecentCaptureResults(for: query) { return "recent_capture" }
        if shouldUseNoteResults(for: query) { return "note" }
        if shouldUsePDFNoteResults(for: query) { return "pdf_note" }
        if shouldUseFolderNoteResults(for: query) { return "folder_note" }
        if shouldUseMeetingNoteResults(for: query) { return "meeting_note" }
        if shouldUseWebClipResults(for: query) { return "web_clip" }
        #if !EPISTEMOS_FREE_V1
        if shouldUseRecentChatResults(for: query),
           ProductCapabilityPolicy.allowsWorkspaceContextPresentation(kind: "recent_chat") {
            return "recent_chat"
        }
        if shouldUseProvenanceClaimResults(for: query) { return "provenance_claim" }
        #endif
        if shouldUseGraphRelatedNoteResults(for: query) { return "graph_related_note" }
        return nil
    }

    static func usesStandaloneContextSource(_ requiredContextKind: String?) -> Bool {
        var standaloneContextKinds: Set<String> = [
            "recent_capture",
            "note",
            "pdf_note",
            "folder_note",
            "meeting_note",
            "web_clip",
        ]
        #if !EPISTEMOS_FREE_V1
        standaloneContextKinds.formUnion(["recent_chat", "provenance_claim"])
        #endif
        return standaloneContextKinds.contains(normalized(requiredContextKind))
            && ProductCapabilityPolicy.allowsWorkspaceContextPresentation(
                kind: normalized(requiredContextKind)
            )
    }

    static func recentCaptureResults(
        modelContainer: ModelContainer?,
        limit: Int
    ) -> [HTMLWorkspaceDataFeedResult] {
        guard let modelContainer else { return [] }
        let context = ModelContext(modelContainer)
        let effectiveLimit = HTMLWorkspaceDataFeed.clampedLimit(limit)
        let fetchLimit = min(effectiveLimit * 4, HTMLWorkspaceDataFeed.maxLimit * 4)
        let pages = (try? context.fetch(SDPage.recentDescriptor(limit: fetchLimit))) ?? []
        return pages
            .compactMap(recentCaptureCandidate(from:))
            .prefix(effectiveLimit)
            .enumerated()
            .map { index, candidate in
                HTMLWorkspaceDataFeedResult(
                    pageID: candidate.pageID,
                    title: candidate.title,
                    snippet: candidate.snippet,
                    rank: max(0.01, 1.0 - (Double(index) * 0.01)),
                    contextKind: "recent_capture",
                    sourceLabel: candidate.sourceLabel,
                    provenance: candidate.provenance
                )
            }
    }

    static func shouldUseRecentCaptureResults(for query: String?) -> Bool {
        let normalizedQuery = normalized(query).lowercased()
        guard !normalizedQuery.isEmpty else { return false }
        if normalizedQuery.hasPrefix("capture:") || normalizedQuery.hasPrefix("captures:") {
            return true
        }
        if normalizedQuery.hasPrefix("capture ") || normalizedQuery.hasPrefix("captures ")
            || normalizedQuery.hasPrefix("recent capture ") || normalizedQuery.hasPrefix("recent captures ") {
            return true
        }
        return [
            "capture",
            "captures",
            "recent capture",
            "recent captures",
            "transcript",
            "transcripts",
        ].contains(normalizedQuery)
    }

    private struct CaptureCandidate {
        var pageID: String
        var title: String
        var snippet: String
        var sourceLabel: String
        var provenance: String
    }

    private static func recentCaptureCandidate(from page: SDPage) -> CaptureCandidate? {
        let frontMatter = page.frontMatter
        let source = normalized(frontMatter["source"])
        let sourceKind = normalized(frontMatter["source_kind"])
        let capturedAt = normalized(frontMatter["captured_at"])
        guard source == "meeting_stt" || sourceKind == "audio_transcript" || !capturedAt.isEmpty else {
            return nil
        }

        let title = normalized(page.title).isEmpty ? "Untitled capture" : page.title
        let bodySnippet = page.normalizedBodySnippet(limit: 360)
        let snippet = normalized(page.summary).isEmpty ? bodySnippet : page.summary
        let label = sourceKind == "audio_transcript" ? "Recent capture transcript" : "Recent capture"
        let provenance = ["TextCapturePipeline", source, sourceKind, capturedAt]
            .map(normalized)
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
        return CaptureCandidate(
            pageID: page.id,
            title: title,
            snippet: normalized(snippet).isEmpty ? "No capture excerpt available." : snippet,
            sourceLabel: label,
            provenance: provenance
        )
    }

    private static func normalized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

nonisolated enum HTMLWorkspaceDataFeedRenderer {
    static let provenance = HTMLWorkspaceDataFeedJSONEnvelope.provenance

    static func render(
        feed: HTMLWorkspaceDataFeed,
        results: [SearchResult],
        refreshedAt: Date = Date(),
        requiredContextKind: String? = nil
    ) -> String {
        render(
            feed: feed,
            results: results.map(HTMLWorkspaceDataFeedResult.init(searchResult:)),
            refreshedAt: refreshedAt,
            stale: false,
            status: "fresh",
            error: nil,
            requiredContextKind: requiredContextKind
        )
    }

    static func render(
        feed: HTMLWorkspaceDataFeed,
        contextResults results: [HTMLWorkspaceDataFeedResult],
        refreshedAt: Date = Date(),
        requiredContextKind: String? = nil
    ) -> String {
        render(
            feed: feed,
            results: results,
            refreshedAt: refreshedAt,
            stale: false,
            status: "fresh",
            error: nil,
            requiredContextKind: requiredContextKind
        )
    }

    static func staleRender(
        feed: HTMLWorkspaceDataFeed,
        error: String,
        refreshedAt: Date? = nil,
        requiredContextKind: String? = nil
    ) -> String {
        HTMLWorkspaceDataFeedJSONEnvelope.staleDataJSON(
            feed: feed,
            error: error,
            refreshedAtMS: refreshedAt.map { Int64($0.timeIntervalSince1970 * 1_000) } ?? 0,
            requiredContextKind: requiredContextKind
        )
    }

    static func presentationDataJSON(from dataJSON: String) -> String {
        guard ProductCapabilityPolicy.currentEdition == .freeV1,
              let data = dataJSON.data(using: .utf8),
              let envelope = try? JSONDecoder.epdocCanonical.decode(HTMLWorkspaceDataFeedEnvelope.self, from: data) else {
            return dataJSON
        }

        let visibleResults = envelope.results.filter {
            ProductCapabilityPolicy.allowsWorkspaceContextPresentation(kind: $0.contextKind)
        }
        let visibleContextKinds = HTMLWorkspaceDataFeedMetadata.normalizedContextKinds(
            envelope.epistemos.contextKinds.filter {
                ProductCapabilityPolicy.allowsWorkspaceContextPresentation(kind: $0)
            }
        )
        let visibleRequiredContextKind = normalizedRequiredContextKind(
            envelope.epistemos.requiredContextKind
        ).flatMap { kind in
            ProductCapabilityPolicy.allowsWorkspaceContextPresentation(kind: kind) ? kind : nil
        }
        let hidesStoredContext = visibleResults.count != envelope.results.count
            || visibleContextKinds != envelope.epistemos.contextKinds
            || visibleRequiredContextKind != envelope.epistemos.requiredContextKind
            || ProductCapabilityPolicy.freeV1HiddenWorkspaceContextKinds.contains { hiddenKind in
                envelope.epistemos.provenance.contains(hiddenKind)
            }
        guard hidesStoredContext else { return dataJSON }

        let metadata = HTMLWorkspaceDataFeedMetadata(
            source: envelope.epistemos.source,
            query: envelope.epistemos.query,
            limit: envelope.epistemos.limit,
            resultCount: visibleResults.count,
            contextKinds: visibleContextKinds,
            refreshedAtMS: envelope.epistemos.refreshedAtMS,
            provenance: metadataProvenance(
                contextKinds: visibleContextKinds,
                requiredContextKind: visibleRequiredContextKind
            ),
            stale: envelope.epistemos.stale,
            status: envelope.epistemos.status,
            error: visibleRequiredContextKind == nil ? nil : envelope.epistemos.error,
            requiredContextKind: visibleRequiredContextKind,
            requiredContextAvailable: visibleRequiredContextKind == nil
                ? nil
                : envelope.epistemos.requiredContextAvailable
        )
        let presentation = HTMLWorkspaceDataFeedEnvelope(results: visibleResults, epistemos: metadata)
        guard let encoded = try? JSONEncoder.epdocCanonical.encode(presentation),
              let json = String(data: encoded, encoding: .utf8) else {
            return dataJSON
        }
        return json
    }

    private static func render(
        feed: HTMLWorkspaceDataFeed,
        results: [HTMLWorkspaceDataFeedResult],
        refreshedAt: Date,
        stale: Bool,
        status: String,
        error: String?,
        requiredContextKind: String?
    ) -> String {
        render(
            feed: feed,
            results: results,
            refreshedAtMS: Int64(refreshedAt.timeIntervalSince1970 * 1_000),
            stale: stale,
            status: status,
            error: error,
            requiredContextKind: requiredContextKind
        )
    }

    private static func render(
        feed: HTMLWorkspaceDataFeed,
        results: [HTMLWorkspaceDataFeedResult],
        refreshedAtMS: Int64,
        stale: Bool,
        status: String,
        error: String?,
        requiredContextKind: String?
    ) -> String {
        let contextKinds = HTMLWorkspaceDataFeedMetadata.normalizedContextKinds(results.map(\.contextKind))
        let normalizedRequiredKind = normalizedRequiredContextKind(requiredContextKind)
        let requiredContextAvailable = normalizedRequiredKind.map { requiredKind in
            results.contains { $0.contextKind == requiredKind }
        }
        let feedMetadataProvenance = metadataProvenance(
            contextKinds: contextKinds,
            requiredContextKind: normalizedRequiredKind
        )
        let metadata = HTMLWorkspaceDataFeedMetadata(
            source: feed.source.rawValue,
            query: feed.normalizedQuery,
            limit: feed.effectiveLimit,
            resultCount: results.count,
            contextKinds: contextKinds,
            refreshedAtMS: refreshedAtMS,
            provenance: feedMetadataProvenance,
            stale: stale,
            status: status,
            error: error,
            requiredContextKind: normalizedRequiredKind,
            requiredContextAvailable: requiredContextAvailable
        )
        let envelope = HTMLWorkspaceDataFeedEnvelope(
            results: results,
            epistemos: metadata
        )
        guard let data = try? JSONEncoder.epdocCanonical.encode(envelope),
              let json = String(data: data, encoding: .utf8) else {
            return #"{"results":[],"_epistemos":{"source":"vault_search","query":"","limit":0,"result_count":0,"context_kinds":[],"refreshed_at_ms":0,"provenance":"VaultSyncService.searchFullAsync","stale":true,"status":"stale","error":"data feed encoding failed"}}"#
        }
        return json
    }

    private static func normalizedRequiredContextKind(_ requiredContextKind: String?) -> String? {
        let trimmed = requiredContextKind?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func metadataProvenance(contextKinds: [String], requiredContextKind: String?) -> String {
        let nonVaultKinds = contextKinds.filter { $0 != "vault_record" }
        if !nonVaultKinds.isEmpty {
            return contextSourceProvenance(for: nonVaultKinds)
        }
        if contextKinds.isEmpty,
           let requiredContextKind,
           requiredContextKind != "vault_record" {
            return contextSourceProvenance(for: [requiredContextKind])
        }
        return provenance
    }

    private static func contextSourceProvenance(for contextKinds: [String]) -> String {
        let suffix = contextKinds.joined(separator: "+")
        return suffix.isEmpty ? provenance : "HTMLWorkspaceDataFeedContextSources.\(suffix)"
    }
}

nonisolated enum HTMLWorkspaceDataFeedStatus {
    static func metadata(from dataJSON: String) -> HTMLWorkspaceDataFeedMetadata? {
        guard let data = dataJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder.epdocCanonical
            .decode(HTMLWorkspaceDataFeedEnvelope.self, from: data)
            .epistemos
    }

    static func metadata(from dataJSON: String, matching feed: HTMLWorkspaceDataFeed) -> HTMLWorkspaceDataFeedMetadata? {
        guard let metadata = metadata(from: dataJSON),
              metadata.source == feed.source.rawValue,
              metadata.query == feed.normalizedQuery,
              metadata.limit == feed.effectiveLimit else {
            return nil
        }
        return metadata
    }

    static func clearedDataJSON(from dataJSON: String) -> String {
        metadata(from: dataJSON) == nil ? dataJSON : "{}"
    }

    static func requiredContextKind(for package: HTMLWorkspacePackage) -> String? {
        guard let feed = package.manifest.dataFeed,
              let metadata = presentationMetadata(for: package, matching: feed) else {
            return nil
        }
        let kind = metadata.requiredContextKind?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return kind.isEmpty ? nil : kind
    }

    @MainActor
    static func shouldRefresh(for notification: Notification) -> Bool {
        guard let dependencies = QueryDependencyKey.from(notification) else { return true }
        let searchDependencies: Set<QueryDependencyKey> = [.searchPages, .searchBlocks, .searchReadable]
        return !dependencies.isDisjoint(with: searchDependencies)
    }

    @MainActor
    static func shouldRefresh(
        for notification: Notification,
        activeSearchService: SearchIndexService?
    ) -> Bool {
        if let source = notification.object as? SearchIndexService,
           let activeSearchService,
           source !== activeSearchService {
            return false
        }
        return shouldRefresh(for: notification)
    }

    @MainActor
    static func compactLine(for package: HTMLWorkspacePackage) -> String? {
        guard let feed = package.manifest.dataFeed else { return nil }
        guard let metadata = presentationMetadata(for: package, matching: feed) else { return "Feed pending" }
        let status = metadata.stale ? "Feed stale" : "Feed fresh"
        let requirementSuffix = contextRequirementText(for: metadata).map { " / \($0)" } ?? ""
        return "\(status): \(metadata.resultCount) / \(contextKindsText(for: metadata))\(requirementSuffix)"
    }

    @MainActor
    static func detailLine(for package: HTMLWorkspacePackage) -> String? {
        guard let feed = package.manifest.dataFeed else { return nil }
        guard let metadata = presentationMetadata(for: package, matching: feed) else {
            return "Vault search: \(feed.normalizedQuery)"
        }
        let age = refreshedAgeText(refreshedAtMS: metadata.refreshedAtMS)
        let errorSuffix = metadata.error.map { " / \($0)" } ?? ""
        let requirementSuffix = contextRequirementText(for: metadata).map { " / \($0)" } ?? ""
        return "\(metadata.query) / \(age) / kinds: \(contextKindsText(for: metadata))\(requirementSuffix) / \(metadata.provenance)\(errorSuffix)"
    }

    private static func presentationMetadata(
        for package: HTMLWorkspacePackage,
        matching feed: HTMLWorkspaceDataFeed
    ) -> HTMLWorkspaceDataFeedMetadata? {
        metadata(
            from: HTMLWorkspaceDataFeedRenderer.presentationDataJSON(from: package.dataJSON),
            matching: feed
        )
    }

    @MainActor
    private static func contextKindsText(for metadata: HTMLWorkspaceDataFeedMetadata) -> String {
        metadata.contextKinds.isEmpty ? "none" : metadata.contextKinds.joined(separator: ", ")
    }

    @MainActor
    private static func contextRequirementText(for metadata: HTMLWorkspaceDataFeedMetadata) -> String? {
        guard let kind = metadata.requiredContextKind, !kind.isEmpty else { return nil }
        return metadata.requiredContextAvailable == true
            ? "required: \(kind) available"
            : "required: \(kind) unavailable"
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
                      HTMLWorkspaceDataFeedStatus.shouldRefresh(
                          for: notification,
                          activeSearchService: AppBootstrap.shared?.vaultSync.searchService
                      ) else { return }
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
        let requiredContextKind = HTMLWorkspaceDataFeedStatus.requiredContextKind(for: package)
            ?? HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: feed.normalizedQuery)
        guard feed.isRunnable else {
            applyStaleRender(feed: feed, error: "Data feed query is empty", requiredContextKind: requiredContextKind)
            return
        }
        if HTMLWorkspaceDataFeedContextSources.usesStandaloneContextSource(requiredContextKind) {
            scheduleStandaloneRefresh(feed: feed, requiredContextKind: requiredContextKind, reason: reason)
            return
        }
        guard let vaultSync = AppBootstrap.shared?.vaultSync else {
            applyStaleRender(feed: feed, error: "Vault feed unavailable", requiredContextKind: requiredContextKind)
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
            let contextResults = HTMLWorkspaceDataFeedContextSources.results(
                for: requiredContextKind,
                searchResults: results,
                modelContainer: AppBootstrap.shared?.modelContainer,
                limit: feed.effectiveLimit,
                query: feed.normalizedQuery
            )
            let nextJSON = HTMLWorkspaceDataFeedRenderer.render(
                feed: feed,
                contextResults: contextResults,
                requiredContextKind: requiredContextKind
            )
            if package.dataJSON != nextJSON {
                package.dataJSON = nextJSON
                stampPackageContentRevision()
            }
            statusText = "Data feed refreshed"
        }
    }

    private func scheduleStandaloneRefresh(
        feed: HTMLWorkspaceDataFeed,
        requiredContextKind: String?,
        reason: String
    ) {
        refreshTask = Task { @MainActor in
            if reason != "initial" {
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
            guard !Task.isCancelled else { return }
            statusText = "Refreshing data feed"
            let contextResults = HTMLWorkspaceDataFeedContextSources.results(
                for: requiredContextKind,
                searchResults: [],
                modelContainer: AppBootstrap.shared?.modelContainer,
                limit: feed.effectiveLimit,
                query: feed.normalizedQuery
            )
            let nextJSON = HTMLWorkspaceDataFeedRenderer.render(
                feed: feed,
                contextResults: contextResults,
                requiredContextKind: requiredContextKind
            )
            if package.dataJSON != nextJSON {
                package.dataJSON = nextJSON
                stampPackageContentRevision()
            }
            statusText = "Data feed refreshed"
        }
    }

    private func applyStaleRender(feed: HTMLWorkspaceDataFeed, error: String, requiredContextKind: String?) {
        let nextJSON = HTMLWorkspaceDataFeedRenderer.staleRender(
            feed: feed,
            error: error,
            requiredContextKind: requiredContextKind
        )
        if package.dataJSON != nextJSON {
            package.dataJSON = nextJSON
            stampPackageContentRevision()
        }
        statusText = error
    }

    private func stampPackageContentRevision() {
        package.manifest.updatedAt = Int64(Date().timeIntervalSince1970 * 1_000)
        package.manifest.contentHash = package.currentContentHash
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
