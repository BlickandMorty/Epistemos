import Foundation
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 search request-bound tests must compile in the App Store target.")
#endif

@Suite("Free V1 shared search request bounds")
struct FreeV1SearchRequestBoundsTests {
    @Test("every mapped search ingress uses the shared checked result limit")
    func mappedSearchIngressesUseSharedCheckedResultLimit() throws {
        let requestBounds = try sourceText("Epistemos/Sync/SearchRequestBounds.swift")
        let searchIndex = try sourceText("Epistemos/Sync/SearchIndexService.swift")
        let queryRuntime = try sourceText("Epistemos/Engine/QueryRuntime.swift")
        let vaultSync = try sourceText("Epistemos/Sync/VaultSyncService.swift")
        let shadowService = try sourceText("Epistemos/Engine/ShadowSearchService.swift")
        let inMemoryShadow = try sourceText("Epistemos/Engine/ShadowFFIClient.swift")
        let rustShadow = try sourceText("Epistemos/Engine/RustShadowFFIClient.swift")

        #expect(requestBounds.contains("nonisolated enum SearchRequestBoundsError: Error, Equatable, Sendable"))
        #expect(requestBounds.contains("nonisolated enum SearchRequestBounds"))
        #expect(requestBounds.contains("static let maximumResultCount = FusionWeights.maximumResultCount"))
        #expect(requestBounds.contains("static func validatedResultLimit(_ limit: Int) throws -> Int"))
        #expect(requestBounds.contains("guard limit >= 1, limit <= maximumResultCount else"))

        for boundary in [
            "let checkedLimit = try SearchRequestBounds.validatedResultLimit(limit)",
            "limit: checkedLimit"
        ] {
            #expect(searchIndex.contains(boundary))
        }
        #expect(queryRuntime.contains("guard let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit) else { return [] }"))
        #expect(vaultSync.contains("guard let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit) else { return [] }"))
        #expect(shadowService.contains("guard let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit) else { return [] }"))
        #expect(shadowService.contains("let checkedLimit = try SearchRequestBounds.validatedResultLimit(limit)"))
        #expect(inMemoryShadow.contains("let checkedLimit = try SearchRequestBounds.validatedResultLimit(limit)"))
        #expect(rustShadow.contains("let checkedLimit = try SearchRequestBounds.validatedResultLimit(limit)"))
        #expect(!rustShadow.contains("max(0, limit)"))
    }

    @Test("shared result policy rejects invalid limits and preserves its valid endpoints")
    func sharedResultPolicyRejectsInvalidLimits() throws {
        #expect(try SearchRequestBounds.validatedResultLimit(1) == 1)
        #expect(try SearchRequestBounds.validatedResultLimit(100) == 100)

        for limit in [0, -1, 101, Int.max] {
            #expect(throws: SearchRequestBoundsError.self) {
                try SearchRequestBounds.validatedResultLimit(limit)
            }
        }

        let inMemoryShadow = InMemoryShadowFFIClient()
        for limit in [0, -1, 101, Int.max] {
            #expect(throws: SearchRequestBoundsError.self) {
                try inMemoryShadow.search(query: "bound", limit: limit)
            }
        }
    }

    @Test("direct SQLite search validates bounded query input before term work")
    func directSQLiteSearchValidatesBoundedQueryInputBeforeTermWork() throws {
        let requestBounds = try sourceText("Epistemos/Sync/SearchRequestBounds.swift")
        let searchIndex = try sourceText("Epistemos/Sync/SearchIndexService.swift")

        for requiredQueryContract in [
            "case invalidQuery",
            "static let maximumQueryUTF8ByteCount = 4_096",
            "static let maximumQueryUnicodeScalarCount = 2_048",
            "static let maximumQueryGraphemeCount = 500",
            "static func validatedQuery(_ query: String) throws -> String?"
        ] {
            #expect(requestBounds.contains(requiredQueryContract))
        }

        let boundaries = [
            (
                start: "nonisolated func search(query: String, limit: Int = 50)",
                end: "func searchAsync(query: String, limit: Int = 50)",
                signpost: "Sig.storage.beginInterval(\"search\""
            ),
            (
                start: "func searchAsync(query: String, limit: Int = 50)",
                end: "// MARK: - Block Search",
                signpost: ""
            ),
            (
                start: "nonisolated func searchBlocks(query: String, limit: Int = 50)",
                end: "func searchBlocksAsync(query: String, limit: Int = 50)",
                signpost: ""
            ),
            (
                start: "func searchBlocksAsync(query: String, limit: Int = 50)",
                end: "// MARK: - RRF Cross-Index Fusion",
                signpost: ""
            ),
            (
                start: "nonisolated public func fusedSearch(",
                end: "/// Async variant offloaded",
                signpost: "Sig.storage.beginInterval(\"fused_search\""
            ),
            (
                start: "public func fusedSearchAsync(",
                end: "private nonisolated static func millisecondsSinceEpoch",
                signpost: ""
            )
        ]

        for boundary in boundaries {
            let body = try sourceSection(
                in: searchIndex,
                startingAt: boundary.start,
                endingBefore: boundary.end
            )
            let validation = try #require(body.range(of: "let checkedQuery = try SearchRequestBounds.validatedQuery(query)"))
            let normalization = try #require(body.range(of: "Self.normalizedSearchTerms(checkedQuery)"))
            #expect(validation.lowerBound < normalization.lowerBound)
            #expect(!body.contains("Self.normalizedSearchTerms(query)"))

            if boundary.start.contains("fusedSearch") {
                let validationPrefix = String(body[validation.lowerBound..<normalization.lowerBound])
                #expect(validationPrefix.contains("Self.recordEmptyFusedSearchMetricsSnapshot()"))
            }

            if !boundary.signpost.isEmpty {
                let signpost = try #require(body.range(of: boundary.signpost))
                #expect(validation.lowerBound < signpost.lowerBound)
            }
        }
    }

    @Test("shared query policy keeps blank input inert and rejects unsafe work budgets")
    func sharedQueryPolicyRejectsUnsafeWorkBudgets() throws {
        #expect(try SearchRequestBounds.validatedQuery("") == nil)
        #expect(try SearchRequestBounds.validatedQuery(" \n\t ") == nil)
        #expect(try SearchRequestBounds.validatedQuery("café 水") == "café 水")

        let scalarBudgetExceeded = String(
            repeating: "\u{0301}",
            count: SearchRequestBounds.maximumQueryUnicodeScalarCount + 1
        )
        let graphemeBudgetExceeded = String(
            repeating: "x",
            count: SearchRequestBounds.maximumQueryGraphemeCount + 1
        )
        let whitespaceOnlyGraphemeBudgetExceeded = String(
            repeating: " ",
            count: SearchRequestBounds.maximumQueryGraphemeCount + 1
        )
        let byteBudgetExceeded = String(repeating: "👨‍👩", count: 400)

        for query in [
            "\0unsafe",
            scalarBudgetExceeded,
            graphemeBudgetExceeded,
            whitespaceOnlyGraphemeBudgetExceeded,
            byteBudgetExceeded
        ] {
            #expect(throws: SearchRequestBoundsError.self) {
                try SearchRequestBounds.validatedQuery(query)
            }
        }
    }

    @Test("non-FFI search wrappers validate query work before dispatch")
    func nonFFISearchWrappersValidateQueryBeforeDispatch() throws {
        let queryRuntime = try sourceText("Epistemos/Engine/QueryRuntime.swift")
        let vaultSync = try sourceText("Epistemos/Sync/VaultSyncService.swift")
        let shadowService = try sourceText("Epistemos/Engine/ShadowSearchService.swift")

        let queryRuntimeBody = try sourceSection(
            in: queryRuntime,
            startingAt: "func fullText(query: String, scope: SearchScope, limit: Int = 50)",
            endingBefore: "private nonisolated static func eidosPacket"
        )
        let queryRuntimeValidation = try #require(
            queryRuntimeBody.range(of: "guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query) else { return [] }")
        )
        let queryRuntimeAllocation = try #require(queryRuntimeBody.range(of: "var seen = Set<String>()"))
        #expect(queryRuntimeValidation.lowerBound < queryRuntimeAllocation.lowerBound)
        for checkedDispatch in [
            "Self.eidosPacket(query: checkedQuery, limit: checkedLimit)",
            "query: checkedQuery,\n                    weights: FusionWeights(maxResults: checkedLimit)",
            "searchIndex.search(query: checkedQuery, limit: checkedLimit)",
            "searchIndex.searchBlocks(query: checkedQuery, limit: checkedLimit)",
            "scoredCandidates(query: checkedQuery, candidates: candidates)"
        ] {
            #expect(queryRuntimeBody.contains(checkedDispatch))
        }

        let vaultBoundaries = [
            (
                start: "func searchIndex(query: String) async -> [String]",
                end: "/// Full-text search with ranked results + snippets."
            ),
            (
                start: "func searchFull(query: String, limit: Int = 20)",
                end: "func searchFullAsync(query: String, limit: Int = 20)"
            ),
            (
                start: "func searchFullAsync(query: String, limit: Int = 20)",
                end: "/// Translate a `FusedResult`"
            ),
            (
                start: "func searchBlocksAsync(query: String, limit: Int = 20)",
                end: "private func canonicalVaultTitle()"
            )
        ]
        for boundary in vaultBoundaries {
            let body = try sourceSection(in: vaultSync, startingAt: boundary.start, endingBefore: boundary.end)
            let validation = try #require(
                body.range(of: "guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query) else { return [] }")
            )
            let service = try #require(body.range(of: "guard let svc = searchService else { return [] }"))
            #expect(validation.lowerBound < service.lowerBound)
            #expect(body.contains("query: checkedQuery"))
            #expect(!body.contains("query: query"))
        }

        let shadowBoundaries = [
            (
                start: "public func search(text: String, limit: Int) async -> [ShadowHit]",
                end: "/// Per RCA13 P5:"
            ),
            (
                start: "public func searchReportingErrors(",
                end: "/// Direct typed search"
            )
        ]
        for boundary in shadowBoundaries {
            let body = try sourceSection(in: shadowService, startingAt: boundary.start, endingBefore: boundary.end)
            let validation = try #require(
                body.range(of: "guard let checkedQuery = try? SearchRequestBounds.validatedQuery(text) else")
            )
            let trim = try #require(
                body.range(of: "let normalizedText = checkedQuery.trimmingCharacters(in: .whitespacesAndNewlines)")
            )
            #expect(validation.lowerBound < trim.lowerBound)
            #expect(body.contains("client.search(query: normalizedText, limit: checkedLimit)"))
        }

        let typedShadow = try sourceSection(
            in: shadowService,
            startingAt: "public func searchOrThrow(text: String, limit: Int) throws -> [ShadowHit]",
            endingBefore: "/// Read-only stats snapshot"
        )
        let typedValidation = try #require(
            typedShadow.range(of: "guard let checkedQuery = try SearchRequestBounds.validatedQuery(text) else { return [] }")
        )
        let typedDiagnostics = try #require(typedShadow.range(of: "let domain: ShadowDomain = .notes"))
        #expect(typedValidation.lowerBound < typedDiagnostics.lowerBound)
        #expect(typedShadow.contains("client.search(query: checkedQuery, limit: checkedLimit)"))
        #expect(!typedShadow.contains("client.search(query: text, limit: checkedLimit)"))
    }

    @Test("direct Shadow clients validate query work before copying or dispatch")
    func directShadowClientsValidateQueryBeforeCopyOrDispatch() throws {
        let inMemorySource = try sourceText("Epistemos/Engine/ShadowFFIClient.swift")
        let rustSource = try sourceText("Epistemos/Engine/RustShadowFFIClient.swift")

        let inMemory = try sourceSection(
            in: inMemorySource,
            startingAt: "public func search(query: String, limit: Int) throws -> [ShadowHit]",
            endingBefore: "public func flush()"
        )
        let inMemoryValidation = try #require(
            inMemory.range(of: "guard let checkedQuery = try SearchRequestBounds.validatedQuery(query) else { return [] }")
        )
        let inMemoryNormalization = try #require(
            inMemory.range(of: "let q = checkedQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)")
        )
        let inMemorySnapshot = try #require(inMemory.range(of: "let snapshot: [ShadowDocumentDTO]"))
        #expect(inMemoryValidation.lowerBound < inMemoryNormalization.lowerBound)
        #expect(inMemoryNormalization.lowerBound < inMemorySnapshot.lowerBound)
        #expect(!inMemory.contains("let q = query.lowercased()"))

        let rust = try sourceSection(
            in: rustSource,
            startingAt: "public func search(query: String, limit: Int) throws -> [ShadowHit]",
            endingBefore: "public func flush()"
        )
        let rustValidation = try #require(
            rust.range(of: "guard let checkedQuery = try SearchRequestBounds.validatedQuery(query) else { return [] }")
        )
        let rustCString = try #require(rust.range(of: "checkedQuery.withCString"))
        #expect(rustValidation.lowerBound < rustCString.lowerBound)
        #expect(!rust.contains("query.withCString"))

        let directShadow = InMemoryShadowFFIClient()
        #expect(try directShadow.search(query: " \n\t ", limit: 1).isEmpty)
        let rejectedQuery = String(
            repeating: "x",
            count: SearchRequestBounds.maximumQueryGraphemeCount + 1
        )
        for query in ["\0unsafe", rejectedQuery] {
            #expect(throws: SearchRequestBoundsError.self) {
                try directShadow.search(query: query, limit: 1)
            }
        }
    }

    @Test("semantic and hybrid retrieval validates work before embedding or FFI")
    func semanticAndHybridIngressesValidateBeforeExpensiveWork() throws {
        let queryRuntime = try sourceText("Epistemos/Engine/QueryRuntime.swift")
        let graphState = try sourceText("Epistemos/Graph/GraphState.swift")
        let codeEditor = try sourceText("Epistemos/Views/Notes/CodeEditorView.swift")

        let runtimeSemantic = try sourceSection(
            in: queryRuntime,
            startingAt: "func semantic(query: String, limit: Int) -> [QueryResultNode]",
            endingBefore: "private func appendNoteResult"
        )
        let runtimeQueryValidation = try #require(
            runtimeSemantic.range(of: "guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query) else { return [] }")
        )
        let runtimeLimitValidation = try #require(
            runtimeSemantic.range(of: "guard let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit) else { return [] }")
        )
        let runtimeGraphSearch = try #require(
            runtimeSemantic.range(of: "graphState.semanticSearch(query: checkedQuery, limit: checkedLimit)")
        )
        #expect(runtimeQueryValidation.lowerBound < runtimeGraphSearch.lowerBound)
        #expect(runtimeLimitValidation.lowerBound < runtimeGraphSearch.lowerBound)
        #expect(runtimeSemantic.contains("scoredCandidates(query: checkedQuery, candidates: candidates)"))

        let graphBoundaries = [
            (
                start: "func rustSearch(query: String, limit: Int = 20) -> [GraphStore.SearchHit]",
                end: "/// Hybrid search: combines text",
                checkedDispatch: "checkedQuery.cString(using: .utf8)"
            ),
            (
                start: "func semanticSearch(query: String, limit: Int = 20) -> [GraphStore.SearchHit]",
                end: "func semanticSearchWithQueryEmbedding",
                checkedDispatch: "semanticSearchWithValidatedQuery(\n            query: checkedQuery,\n            limit: checkedLimit"
            ),
            (
                start: "func hybridSearch(query: String, limit: Int = 20) -> [GraphStore.SearchHit]",
                end: "/// Highlight search matches in the graph",
                checkedDispatch: "rustSearch(query: checkedQuery, limit: checkedLimit)"
            )
        ]

        for boundary in graphBoundaries {
            let body = try sourceSection(in: graphState, startingAt: boundary.start, endingBefore: boundary.end)
            let queryValidation = try #require(
                body.range(of: "guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query) else { return [] }")
            )
            let limitValidation = try #require(
                body.range(of: "guard let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit) else { return [] }")
            )
            let dispatch = try #require(body.range(of: boundary.checkedDispatch))
            #expect(queryValidation.lowerBound < dispatch.lowerBound)
            #expect(limitValidation.lowerBound < dispatch.lowerBound)
        }

        let graphOwnedSearch = try sourceSection(
            in: graphState,
            startingAt: "    func semanticSearchWithQueryEmbedding(",
            endingBefore: "private func semanticSearchWithValidatedQuery"
        )
        let graphOwnedQueryValidation = try #require(
            graphOwnedSearch.range(of: "guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query) else { return nil }")
        )
        let graphOwnedLimitValidation = try #require(
            graphOwnedSearch.range(of: "guard let checkedLimit = try? SearchRequestBounds.validatedResultLimit(limit) else { return nil }")
        )
        let graphOwnedDispatch = try #require(
            graphOwnedSearch.range(of: "semanticSearchWithValidatedQuery(query: checkedQuery, limit: checkedLimit)")
        )
        #expect(graphOwnedQueryValidation.lowerBound < graphOwnedDispatch.lowerBound)
        #expect(graphOwnedLimitValidation.lowerBound < graphOwnedDispatch.lowerBound)

        let graphValidatedSearch = try sourceSection(
            in: graphState,
            startingAt: "private func semanticSearchWithValidatedQuery(",
            endingBefore: "private func preparedSemanticSearchWithQueryEmbedding"
        )
        let graphOwnedPrepared = try #require(
            graphValidatedSearch.range(of: "preparedSemanticSearchWithQueryEmbedding(\n            query: query,\n            limit: limit")
        )
        let graphOwnedFallbackEmbedding = try #require(
            graphValidatedSearch.range(of: "let queryVec = embeddingService.queryEmbedding(")
        )
        #expect(graphOwnedPrepared.lowerBound < graphOwnedFallbackEmbedding.lowerBound)
        #expect(graphValidatedSearch.contains("UInt32(limit)"))
        #expect(!graphValidatedSearch.contains("UInt32(checkedLimit)"))
        #expect(graphValidatedSearch.contains("return SemanticSearchQueryResult("))

        let preparedOwnedSearch = try sourceSection(
            in: graphState,
            startingAt: "    private func preparedSemanticSearchWithQueryEmbedding(",
            endingBefore: "private func collectSemanticHits"
        )
        #expect(preparedOwnedSearch.contains("graph_engine_prepared_retrieval_dimension(engine)"))
        #expect(preparedOwnedSearch.contains("embeddingService.queryEmbedding(for: query, expectedDimension: dimension)"))
        #expect(preparedOwnedSearch.contains("return SemanticSearchQueryResult("))

        let bridge = try sourceSection(
            in: codeEditor,
            startingAt: "final class CodeContextBridge",
            endingBefore: "// MARK: - Code Semantic Sidebar"
        )
        let relatedNotes = try sourceSection(
            in: bridge,
            startingAt: "func findRelatedNotes(for codeContent: String)",
            endingBefore: "private func performSemanticSearch"
        )
        let relatedQueryValidation = try #require(
            relatedNotes.range(of: "guard let checkedCodeContent = try? SearchRequestBounds.validatedQuery(codeContent),")
        )
        let relatedHash = try #require(relatedNotes.range(of: "let codeHash = checkedCodeContent.hashValue"))
        let relatedSearch = try #require(relatedNotes.range(of: "performSemanticSearch(\n                query: checkedCodeContent,"))
        #expect(relatedQueryValidation.lowerBound < relatedHash.lowerBound)
        #expect(relatedQueryValidation.lowerBound < relatedSearch.lowerBound)
        #expect(relatedNotes.contains("limit: checkedLimit"))
        #expect(!bridge.contains("computeEmbedding("))

        let rerank = try sourceSection(
            in: bridge,
            startingAt: "private func performSemanticSearch(",
            endingBefore: "func semanticCodeSearch(query: String) async -> [CodeSemanticMatch]"
        )
        let rerankQueryValidation = try #require(
            rerank.range(of: "guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query),")
        )
        let rerankGraphSearch = try #require(
            rerank.range(of: "graphState.semanticSearchWithQueryEmbedding(")
        )
        let rerankDimensionFilter = try #require(
            rerank.range(of: "guard embedding.count == queryEmbedding.count else { continue }")
        )
        let rerankMetal = try #require(rerank.range(of: "MetalComputeEngine.shared.batchCosineSimilarity("))
        #expect(rerankQueryValidation.lowerBound < rerankGraphSearch.lowerBound)
        #expect(rerankGraphSearch.lowerBound < rerankDimensionFilter.lowerBound)
        #expect(rerankDimensionFilter.lowerBound < rerankMetal.lowerBound)
        #expect(rerank.contains("let queryEmbedding = semanticResult.queryEmbedding"))

        let codeSemantic = try sourceSection(
            in: bridge,
            startingAt: "func semanticCodeSearch(query: String) async -> [CodeSemanticMatch]",
            endingBefore: "func cancelPendingWork()"
        )
        let codeQueryValidation = try #require(
            codeSemantic.range(of: "guard let checkedQuery = try? SearchRequestBounds.validatedQuery(query),")
        )
        let codeSearch = try #require(codeSemantic.range(of: "performSemanticSearch(\n            query: checkedQuery,"))
        #expect(codeQueryValidation.lowerBound < codeSearch.lowerBound)
        #expect(codeSemantic.contains("limit: checkedLimit"))
    }

    @Test("SQLite page and block search reject invalid limits before dispatch")
    func sqliteSearchRejectsInvalidLimitsBeforeDispatch() async throws {
        let searchDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("free-v1-search-bounds-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: searchDirectory) }

        let service = try SearchIndexService(
            databaseURL: searchDirectory.appendingPathComponent("search.sqlite")
        )
        try service.upsert(
            id: "bounded-page",
            title: "bounded title",
            body: "bounded query text",
            tags: "",
            updatedAt: Date()
        )
        try service.upsertBlock(
            blockId: "bounded-block",
            pageId: "bounded-page",
            content: "bounded query text"
        )

        for limit in [0, -1, 101, Int.max] {
            #expect(throws: SearchRequestBoundsError.self) {
                try service.search(query: "bounded", limit: limit)
            }
            #expect(throws: SearchRequestBoundsError.self) {
                try service.searchBlocks(query: "bounded", limit: limit)
            }
            await #expect(throws: SearchRequestBoundsError.self) {
                try await service.searchAsync(query: "bounded", limit: limit)
            }
            await #expect(throws: SearchRequestBoundsError.self) {
                try await service.searchBlocksAsync(query: "bounded", limit: limit)
            }
        }

        let rejectedQuery = String(
            repeating: "x",
            count: SearchRequestBounds.maximumQueryGraphemeCount + 1
        )
        #expect(throws: SearchRequestBoundsError.self) {
            try service.search(query: rejectedQuery, limit: 1)
        }
        #expect(throws: SearchRequestBoundsError.self) {
            try service.searchBlocks(query: rejectedQuery, limit: 1)
        }
        await #expect(throws: SearchRequestBoundsError.self) {
            try await service.searchAsync(query: rejectedQuery, limit: 1)
        }
        await #expect(throws: SearchRequestBoundsError.self) {
            try await service.searchBlocksAsync(query: rejectedQuery, limit: 1)
        }

        #expect(try service.search(query: "bounded", limit: 1).count == 1)
        #expect(try service.searchBlocks(query: "bounded", limit: 1).count == 1)
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func sourceSection(
        in source: String,
        startingAt startMarker: String,
        endingBefore endMarker: String
    ) throws -> String {
        let start = try #require(source.range(of: startMarker))
        let remainder = source[start.upperBound...]
        let end = try #require(remainder.range(of: endMarker))
        return String(source[start.lowerBound..<end.lowerBound])
    }
}
