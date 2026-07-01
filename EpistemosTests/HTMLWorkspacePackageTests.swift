import Foundation
import SwiftData
import Testing

@testable import Epistemos

@Suite("HTML Workspace package and patch model")
nonisolated struct HTMLWorkspacePackageTests {
    private static let createdAt: Int64 = 1_700_000_000_000

    private static func sampleManifest() -> HTMLWorkspaceManifest {
        HTMLWorkspaceManifest(
            id: "html-workspace-test",
            schemaVersion: HTMLWorkspaceManifest.currentSchemaVersion,
            createdAt: createdAt,
            updatedAt: createdAt + 1_000,
            title: "Interactive Doc",
            contentHash: "sha256-fixture",
            sandboxPolicy: .offlineDefault
        )
    }

    private static func samplePackage() -> HTMLWorkspacePackage {
        HTMLWorkspacePackage(
            manifest: sampleManifest(),
            indexHTML: "<main><h1>Interactive Doc</h1><p>DOM workspace</p></main>",
            styleCSS: "main { display: grid; gap: 12px; }",
            scriptJS: "document.body.dataset.ready = 'true';",
            dataJSON: #"{"metrics":[{"label":"Nodes","value":3}]}"#,
            routes: ["about.html": #"<main><h1>About</h1><img src="assets/texture.png" alt=""></main>"#],
            assets: ["texture.png": Data([0x89, 0x50, 0x4e, 0x47])],
            snapshots: ["initial.html": Data("<main>snapshot</main>".utf8)]
        )
    }

    @Test("HTMLWorkspacePackage round-trips index, style, script, data, routes, assets, and manifest")
    func packageRoundTripsThroughFileWrapper() throws {
        let original = Self.samplePackage()

        let wrapper = try original.makeFileWrapper()
        #expect(wrapper.isDirectory)
        #expect(wrapper.fileWrappers?[HTMLWorkspacePackageEntry.manifest] != nil)
        #expect(wrapper.fileWrappers?[HTMLWorkspacePackageEntry.indexHTML] != nil)
        #expect(wrapper.fileWrappers?[HTMLWorkspacePackageEntry.styleCSS] != nil)
        #expect(wrapper.fileWrappers?[HTMLWorkspacePackageEntry.scriptJS] != nil)
        #expect(wrapper.fileWrappers?[HTMLWorkspacePackageEntry.dataJSON] != nil)
        #expect(wrapper.fileWrappers?[HTMLWorkspacePackageEntry.routes] != nil)
        #expect(HTMLWorkspacePackageEntry.scriptJS == "main.js")

        let recovered = try HTMLWorkspacePackage(fileWrapper: wrapper)
        #expect(recovered.manifest == original.manifest)
        #expect(recovered.indexHTML == original.indexHTML)
        #expect(recovered.styleCSS == original.styleCSS)
        #expect(recovered.scriptJS == original.scriptJS)
        #expect(recovered.dataJSON == original.dataJSON)
        #expect(recovered.routes == original.routes)
        #expect(recovered.assets == original.assets)
        #expect(recovered.snapshots == original.snapshots)
    }

    @Test("HTMLWorkspace manifest round-trips explicit vault search data feed")
    func manifestDataFeedRoundTrips() throws {
        var original = Self.samplePackage()
        original.manifest.dataFeed = .vaultSearch(query: "categorical imperative", limit: 99)

        let recovered = try HTMLWorkspacePackage(fileWrapper: try original.makeFileWrapper())

        #expect(recovered.manifest.dataFeed?.source == .vaultSearch)
        #expect(recovered.manifest.dataFeed?.normalizedQuery == "categorical imperative")
        #expect(recovered.manifest.dataFeed?.limit == 99)
        #expect(recovered.manifest.dataFeed?.effectiveLimit == HTMLWorkspaceDataFeed.maxLimit)
    }

    @Test("HTMLWorkspace manifest round-trips generation provenance with snake-case wire keys")
    func manifestGenerationProvenanceRoundTrips() throws {
        var original = Self.samplePackage()
        original.manifest.generationProvenance = HTMLWorkspaceGenerationProvenance(
            producer: .agent,
            operation: .regenerate,
            generatedAt: Self.createdAt + 2_000,
            previousContentHash: "before-hash",
            contentHash: "after-hash",
            reversibleSnapshotName: "pre-replace-before.html",
            generatedByRun: "run-html",
            toolId: HTMLWorkspaceGenerationProvenance.patchToolID
        )

        let data = try JSONEncoder.epdocCanonical.encode(original.manifest)
        let json = String(data: data, encoding: .utf8) ?? ""
        #expect(json.contains(#""generation_provenance""#))
        #expect(json.contains(#""previous_content_hash""#))
        #expect(json.contains(#""reversible_snapshot_name""#))
        #expect(json.contains(#""generated_by_run""#))

        let recovered = try HTMLWorkspacePackage(fileWrapper: try original.makeFileWrapper())
        #expect(recovered.manifest.generationProvenance == original.manifest.generationProvenance)
        let provenance = try #require(recovered.manifest.generationProvenance)
        #expect(provenance.displayText(currentContentHash: "after-hash") == "Agent regenerate / current")
        #expect(provenance.displayText(currentContentHash: "different-hash") == "Agent regenerate / stale")
        #expect(provenance.displayText(currentContentHash: nil) == "Agent regenerate / unverified")
    }

    @Test("HTMLWorkspace vault search feed renders provenance and freshness metadata into data.json")
    func dataFeedRenderIncludesProvenanceMetadata() throws {
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "  substrate provenance  ", limit: 2)
        let rendered = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            results: [
                SearchResult(
                    pageId: "page-1",
                    title: "Research Note",
                    snippet: "substrate provenance witness",
                    rank: 0.87
                )
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(rendered.contains(#""_epistemos""#))
        #expect(rendered.contains(#""source" : "vault_search""#))
        #expect(rendered.contains(#""query" : "substrate provenance""#))
        #expect(rendered.contains(#""provenance" : "VaultSyncService.searchFullAsync""#))
        #expect(rendered.contains(#""stale" : false"#))
        #expect(rendered.contains(#""page_id" : "page-1""#))
        #expect(rendered.contains(#""context_kind" : "vault_record""#))
        #expect(rendered.contains(#""source_label" : "Vault search result""#))
        #expect(rendered.contains(#""context_kinds" : ["#))

        let metadata = try #require(HTMLWorkspaceDataFeedStatus.metadata(from: rendered))
        #expect(metadata.resultCount == 1)
        #expect(metadata.contextKinds == ["vault_record"])
        #expect(metadata.refreshedAtMS == 1_700_000_000_000)
        #expect(metadata.stale == false)
    }

    @Test("HTMLWorkspace data feed clearing removes only generated feed envelopes")
    func dataFeedClearingRemovesOnlyGeneratedFeedEnvelopes() {
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "substrate provenance", limit: 2)
        let feedJSON = HTMLWorkspaceDataFeedRenderer.staleRender(
            feed: feed,
            error: "Feed pending",
            requiredContextKind: "recent_capture"
        )
        let customJSON = #"{"results":[{"title":"user data"}]}"#

        #expect(HTMLWorkspaceDataFeedStatus.clearedDataJSON(from: feedJSON) == "{}")
        #expect(HTMLWorkspaceDataFeedStatus.clearedDataJSON(from: customJSON) == customJSON)
    }

    @Test("HTMLWorkspace data feed status ignores mismatched generated envelopes")
    @MainActor
    func dataFeedStatusIgnoresMismatchedGeneratedEnvelopes() {
        let attachedFeed = HTMLWorkspaceDataFeed.vaultSearch(query: "attached context", limit: 2)
        let staleFeed = HTMLWorkspaceDataFeed.vaultSearch(query: "attached context", limit: 4)
        var package = Self.samplePackage()
        package.manifest.dataFeed = attachedFeed
        package.dataJSON = HTMLWorkspaceDataFeedRenderer.staleRender(
            feed: staleFeed,
            error: "Old feed pending",
            requiredContextKind: "recent_capture"
        )

        #expect(HTMLWorkspaceDataFeedStatus.metadata(from: package.dataJSON, matching: attachedFeed) == nil)
        #expect(HTMLWorkspaceDataFeedStatus.requiredContextKind(for: package) == nil)
        #expect(HTMLWorkspaceDataFeedStatus.compactLine(for: package) == "Feed pending")
        #expect(HTMLWorkspaceDataFeedStatus.detailLine(for: package) == "Vault search: attached context")
    }

    @Test("HTMLWorkspace data feed status exposes explicit context kinds")
    @MainActor
    func dataFeedStatusExposesExplicitContextKinds() throws {
        var package = Self.samplePackage()
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "  substrate provenance  ", limit: 2)
        package.manifest.dataFeed = feed
        package.dataJSON = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            results: [
                SearchResult(
                    pageId: "page-1",
                    title: "Research Note",
                    snippet: "substrate provenance witness",
                    rank: 0.87
                )
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let detail = try #require(HTMLWorkspaceDataFeedStatus.detailLine(for: package))
        let compact = try #require(HTMLWorkspaceDataFeedStatus.compactLine(for: package))
        #expect(compact == "Feed fresh: 1 / vault_record")
        #expect(detail.contains("substrate provenance"))
        #expect(detail.contains("kinds: vault_record"))
        #expect(detail.contains("VaultSyncService.searchFullAsync"))
    }

    @Test("HTMLWorkspace data feed renderer preserves explicit context result metadata")
    func dataFeedRendererPreservesExplicitContextResultMetadata() throws {
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "mixed context", limit: 4)
        let rendered = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            contextResults: [
                HTMLWorkspaceDataFeedResult(
                    pageID: "capture-1",
                    title: "Capture",
                    snippet: "captured text",
                    rank: 0.91,
                    contextKind: "recent_capture",
                    sourceLabel: "Recent capture",
                    provenance: "CaptureStore"
                ),
                HTMLWorkspaceDataFeedResult(
                    pageID: "graph-1",
                    title: "Graph neighbor",
                    snippet: "related note",
                    rank: 0.72,
                    contextKind: "graph_related_note",
                    sourceLabel: "Graph related note",
                    provenance: "GraphState"
                ),
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_003),
            requiredContextKind: "graph_related_note"
        )

        #expect(rendered.contains(#""context_kind" : "recent_capture""#))
        #expect(rendered.contains(#""context_kind" : "graph_related_note""#))
        #expect(rendered.contains(#""source_label" : "Recent capture""#))
        #expect(rendered.contains(#""provenance" : "GraphState""#))
        #expect(rendered.contains(#""required_context_kind" : "graph_related_note""#))
        #expect(rendered.contains(#""required_context_available" : true"#))

        let metadata = try #require(HTMLWorkspaceDataFeedStatus.metadata(from: rendered))
        #expect(metadata.contextKinds == ["graph_related_note", "recent_capture"])
        #expect(metadata.requiredContextKind == "graph_related_note")
        #expect(metadata.requiredContextAvailable == true)
        #expect(metadata.resultCount == 2)
        #expect(!metadata.stale)
    }

    @Test("HTMLWorkspace data feed normalizes context kind metadata")
    func dataFeedNormalizesContextKindMetadata() throws {
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "padded context", limit: 2)
        let rendered = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            contextResults: [
                HTMLWorkspaceDataFeedResult(
                    pageID: "capture-1",
                    title: "Capture",
                    snippet: "captured text",
                    rank: 0.91,
                    contextKind: "  recent_capture  ",
                    sourceLabel: "  Recent capture  ",
                    provenance: "  CaptureStore  "
                ),
                HTMLWorkspaceDataFeedResult(
                    pageID: "generic-1",
                    title: "Generic",
                    snippet: "generic text",
                    rank: 0.42,
                    contextKind: "   ",
                    sourceLabel: "   ",
                    provenance: "   "
                ),
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_006),
            requiredContextKind: "recent_capture"
        )

        #expect(rendered.contains(#""context_kind" : "recent_capture""#))
        #expect(rendered.contains(#""context_kind" : "vault_record""#))
        let metadata = try #require(HTMLWorkspaceDataFeedStatus.metadata(from: rendered))
        #expect(metadata.contextKinds == ["recent_capture", "vault_record"])
        #expect(metadata.requiredContextAvailable == true)

        let envelope = try JSONDecoder().decode(HTMLWorkspaceDataFeedEnvelope.self, from: Data(rendered.utf8))
        #expect(envelope.results.map(\.sourceLabel) == ["Recent capture", "Vault search result"])
        #expect(envelope.results.map(\.provenance) == ["CaptureStore", HTMLWorkspaceDataFeedJSONEnvelope.provenance])
    }

    @Test("HTMLWorkspace data feed records unavailable required context without relabeling results")
    func dataFeedRecordsUnavailableRequiredContextWithoutRelabelingResults() throws {
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "recent captures project", limit: 2)
        let rendered = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            results: [
                SearchResult(
                    pageId: "page-1",
                    title: "Generic note",
                    snippet: "not an explicit capture",
                    rank: 0.5
                )
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_004),
            requiredContextKind: "recent_capture"
        )

        #expect(rendered.contains(#""context_kind" : "vault_record""#))
        #expect(!rendered.contains(#""context_kind" : "recent_capture""#))
        #expect(rendered.contains(#""required_context_kind" : "recent_capture""#))
        #expect(rendered.contains(#""required_context_available" : false"#))

        let metadata = try #require(HTMLWorkspaceDataFeedStatus.metadata(from: rendered))
        #expect(metadata.contextKinds == ["vault_record"])
        #expect(metadata.requiredContextKind == "recent_capture")
        #expect(metadata.requiredContextAvailable == false)
    }

    @Test("HTMLWorkspace data feed records empty required context without synthetic kinds")
    func dataFeedRecordsEmptyRequiredContextWithoutSyntheticKinds() throws {
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "recent captures missing", limit: 2)
        let rendered = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            contextResults: [],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_007),
            requiredContextKind: "recent_capture"
        )

        #expect(rendered.contains(#""context_kinds" : []"#))
        #expect(!rendered.contains(#""context_kind" : "vault_record""#))
        #expect(rendered.contains(#""required_context_kind" : "recent_capture""#))
        #expect(rendered.contains(#""required_context_available" : false"#))

        let metadata = try #require(HTMLWorkspaceDataFeedStatus.metadata(from: rendered))
        #expect(metadata.contextKinds == [])
        #expect(metadata.resultCount == 0)
        #expect(metadata.requiredContextKind == "recent_capture")
        #expect(metadata.requiredContextAvailable == false)
    }

    @Test("HTMLWorkspace data feed metadata decode normalizes context kind labels")
    func dataFeedMetadataDecodeNormalizesContextKindLabels() throws {
        let json = """
        {
          "results": [],
          "_epistemos": {
            "source": " vault_search ",
            "query": " decode context ",
            "limit": 2,
            "result_count": 0,
            "context_kinds": [" graph_related_note ", "", "recent_capture", "graph_related_note"],
            "refreshed_at_ms": 0,
            "provenance": " ",
            "stale": false,
            "status": " ",
            "error": " ",
            "required_context_kind": " recent_capture ",
            "required_context_available": true
          }
        }
        """

        let metadata = try #require(HTMLWorkspaceDataFeedStatus.metadata(from: json))
        #expect(metadata.source == "vault_search")
        #expect(metadata.query == "decode context")
        #expect(metadata.contextKinds == ["graph_related_note", "recent_capture"])
        #expect(metadata.provenance == HTMLWorkspaceDataFeedJSONEnvelope.provenance)
        #expect(metadata.status == "fresh")
        #expect(metadata.error == nil)
        #expect(metadata.requiredContextKind == "recent_capture")
        #expect(metadata.requiredContextAvailable == true)
    }

    @MainActor
    @Test("HTMLWorkspace recent capture context source uses explicit capture front matter")
    func dataFeedRecentCaptureContextSourceUsesExplicitCaptureFrontMatter() throws {
        let schema = Schema([SDPage.self, SDGraphNode.self, SDGraphEdge.self, SDBlock.self])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = ModelContext(container)
        let capture = SDPage(title: "Meeting Alpha")
        capture.body = "alpha transcript body"
        capture.frontMatter = [
            "source": "meeting_stt",
            "source_kind": "audio_transcript",
            "captured_at": "2026-07-01T12:00:00Z",
        ]
        let generic = SDPage(title: "Generic Note")
        generic.body = "generic note body"
        context.insert(generic)
        context.insert(capture)
        try context.save()

        let captureResults = HTMLWorkspaceDataFeedContextSources.recentCaptureResults(
            modelContainer: container,
            limit: 5
        )
        #expect(captureResults.map(\.pageID) == [capture.id])
        #expect(captureResults.first?.contextKind == "recent_capture")
        #expect(captureResults.first?.sourceLabel == "Recent capture transcript")
        #expect(captureResults.first?.provenance.contains("TextCapturePipeline") == true)
        #expect(captureResults.first?.snippet == "alpha transcript body")

        let genericResult = SearchResult(pageId: "note-a", title: "Generic", snippet: "generic", rank: 0.7)
        let requiredCaptureResults = HTMLWorkspaceDataFeedContextSources.results(
            for: "recent_capture",
            searchResults: [genericResult],
            modelContainer: container,
            limit: 5
        )
        #expect(requiredCaptureResults.map(\.pageID) == [capture.id])

        let triggeredCaptureResults = HTMLWorkspaceDataFeedContextSources.results(
            for: nil,
            searchResults: [genericResult],
            modelContainer: container,
            limit: 5,
            query: "captures alpha"
        )
        #expect(triggeredCaptureResults.map(\.pageID) == [capture.id])
        #expect(triggeredCaptureResults.first?.contextKind == "recent_capture")

        let explicitGraphResults = HTMLWorkspaceDataFeedContextSources.results(
            for: "graph_related_note",
            searchResults: [genericResult],
            modelContainer: container,
            limit: 5,
            query: "captures alpha"
        )
        #expect(explicitGraphResults.isEmpty)

        let defaultResults = HTMLWorkspaceDataFeedContextSources.results(
            for: nil,
            searchResults: [genericResult],
            modelContainer: container,
            limit: 5
        )
        #expect(defaultResults.map(\.pageID) == ["note-a"])
        #expect(defaultResults.first?.contextKind == "vault_record")
    }

    @Test("HTMLWorkspace data feed status exposes existing required context kind for refreshes")
    func dataFeedStatusExposesExistingRequiredContextKindForRefreshes() throws {
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "recent captures project", limit: 2)
        var package = Self.samplePackage()
        package.manifest.dataFeed = feed
        package.dataJSON = HTMLWorkspaceDataFeedRenderer.render(
            feed: feed,
            results: [
                SearchResult(
                    pageId: "page-1",
                    title: "Generic note",
                    snippet: "not an explicit capture",
                    rank: 0.5
                )
            ],
            refreshedAt: Date(timeIntervalSince1970: 1_700_000_005),
            requiredContextKind: "recent_capture"
        )

        #expect(HTMLWorkspaceDataFeedStatus.requiredContextKind(for: package) == "recent_capture")
        package.manifest.dataFeed = .vaultSearch(query: "different query", limit: 2)
        #expect(HTMLWorkspaceDataFeedStatus.requiredContextKind(for: package) == nil)
        #expect(HTMLWorkspaceDataFeedStatus.requiredContextKind(for: Self.samplePackage()) == nil)
    }

    @MainActor
    @Test("HTMLWorkspace answer packet emits refresh only provenance claim context feeds")
    func answerPacketEmitsRefreshOnlyProvenanceClaimContextFeeds() {
        var claimPackage = Self.samplePackage()
        claimPackage.manifest.dataFeed = .vaultSearch(query: "claims tool execution", limit: 3)
        #expect(HTMLWorkspaceDataFeedStatus.shouldRefreshForAnswerPacket(for: claimPackage))

        var capturePackage = Self.samplePackage()
        capturePackage.manifest.dataFeed = .vaultSearch(query: "recent captures alpha", limit: 3)
        #expect(!HTMLWorkspaceDataFeedStatus.shouldRefreshForAnswerPacket(for: capturePackage))
        #expect(!HTMLWorkspaceDataFeedStatus.shouldRefreshForAnswerPacket(for: Self.samplePackage()))
    }

    @Test("HTMLWorkspace data feed binder preserves required context kind on refresh renders")
    func dataFeedBinderPreservesRequiredContextKindOnRefreshRenders() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/HTMLWorkspace/HTMLWorkspaceDataFeed.swift")

        #expect(source.contains("let requiredContextKind = HTMLWorkspaceDataFeedStatus.requiredContextKind(for: package)"))
        #expect(source.contains("HTMLWorkspaceDataFeedContextSources.requiredContextKind(forFreeformQuery: feed.normalizedQuery)"))
        #expect(source.contains("AnswerPacketEmitter.didEmitNotification"))
        #expect(source.contains("HTMLWorkspaceDataFeedStatus.shouldRefreshForAnswerPacket(for: package)"))
        #expect(source.contains("requiredContextKind: requiredContextKind"))
        #expect(source.contains("applyStaleRender(feed: feed, error: \"Data feed query is empty\", requiredContextKind: requiredContextKind)"))
        #expect(source.contains("applyStaleRender(feed: feed, error: \"Vault feed unavailable\", requiredContextKind: requiredContextKind)"))
    }

    @Test("HTMLWorkspace stale data feed render does not pretend a failed feed refreshed")
    @MainActor
    func staleDataFeedRenderDoesNotPretendToRefresh() throws {
        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: "substrate provenance", limit: 2)
        let rendered = HTMLWorkspaceDataFeedRenderer.staleRender(
            feed: feed,
            error: "Vault feed unavailable",
            requiredContextKind: "recent_capture"
        )

        let metadata = try #require(HTMLWorkspaceDataFeedStatus.metadata(from: rendered))
        #expect(metadata.stale)
        #expect(metadata.contextKinds == [])
        #expect(metadata.refreshedAtMS == 0)
        #expect(metadata.error == "Vault feed unavailable")
        #expect(metadata.requiredContextKind == "recent_capture")
        #expect(metadata.requiredContextAvailable == false)

        var package = Self.samplePackage()
        package.manifest.dataFeed = feed
        package.dataJSON = rendered
        let compact = try #require(HTMLWorkspaceDataFeedStatus.compactLine(for: package))
        let detail = try #require(HTMLWorkspaceDataFeedStatus.detailLine(for: package))
        #expect(compact == "Feed stale: 0 / none / required: recent_capture unavailable")
        #expect(detail.contains("required: recent_capture unavailable"))
    }

    @Test("HTMLWorkspace offline CSP admits package-local resources without network")
    func offlineCSPAllowsPackageLocalResourcesOnly() {
        let csp = HTMLWorkspaceSandboxPolicy.offlineDefault.contentSecurityPolicy
        let localResource = HTMLWorkspaceLocalResourceScheme.contentSecurityPolicySource

        #expect(csp.contains("default-src 'none'"))
        #expect(csp.contains("img-src data: blob: \(localResource)"))
        #expect(csp.contains("style-src 'unsafe-inline' \(localResource)"))
        #expect(csp.contains("script-src 'unsafe-inline' \(localResource)"))
        #expect(csp.contains("font-src data: \(localResource)"))
        #expect(csp.contains("connect-src \(localResource)"))
        #expect(csp.contains("worker-src 'none'"))
        #expect(csp.contains("child-src 'none'"))
        #expect(csp.contains("media-src data: blob: \(localResource)"))
        #expect(!csp.contains("wasm-unsafe-eval"))
        #expect(!csp.contains("connect-src https:"))
    }

    @Test("HTMLWorkspace Python CSP admits WASM eval and local workers without network")
    func pythonCSPAllowsWASMLocalWorkersOnly() {
        var policy = HTMLWorkspaceSandboxPolicy.offlineDefault
        policy.allowPythonRuntime = true
        let csp = policy.contentSecurityPolicy
        let localResource = HTMLWorkspaceLocalResourceScheme.contentSecurityPolicySource

        #expect(csp.contains("default-src 'none'"))
        #expect(csp.contains("script-src 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' \(localResource)"))
        #expect(csp.contains("connect-src \(localResource)"))
        #expect(csp.contains("worker-src blob: \(localResource)"))
        #expect(csp.contains("child-src blob: \(localResource)"))
        #expect(csp.contains("frame-src 'none'"))
        #expect(!csp.contains("connect-src https:"))
        #expect(!csp.contains("worker-src https:"))
    }

    @Test("HTMLWorkspace preview identity tracks asset bytes but not data-only updates")
    func previewIdentityTracksAssetBytesButNotDataOnlyUpdates() {
        var original = Self.samplePackage()
        original.assets = ["texture.png": Data([1, 2, 3])]
        var dataOnly = original
        dataOnly.dataJSON = #"{"metrics":[]}"#
        var assetUpdate = original
        assetUpdate.assets = ["texture.png": Data([1, 2, 4])]
        var routeUpdate = original
        routeUpdate.routes["about.html"] = "<main><h1>Updated Route</h1></main>"

        #expect(HTMLWorkspacePreviewIdentity.viewIdentity(for: original) == HTMLWorkspacePreviewIdentity.viewIdentity(for: dataOnly))
        #expect(HTMLWorkspacePreviewIdentity.viewIdentity(for: original) != HTMLWorkspacePreviewIdentity.viewIdentity(for: assetUpdate))
        #expect(HTMLWorkspacePreviewIdentity.viewIdentity(for: original) != HTMLWorkspacePreviewIdentity.viewIdentity(for: routeUpdate))
    }

    @MainActor
    @Test("HTMLWorkspace chat context caps all route source to one budget")
    func chatContextCapsRouteSourceAsOneBudget() throws {
        let document = HTMLWorkspaceDocument()
        var package = Self.samplePackage()
        package.routes = [
            "a.html": "abcdefghi",
            "b.html": "second route body",
        ]
        document.package = package

        let snapshot = document.chatContextSnapshot(maxSourceCharacters: 6)

        #expect(snapshot.routes["a.html"] == "abcdef")
        #expect(snapshot.routes["b.html"] == "[omitted: route context budget exhausted]")
    }

    @Test("HTMLWorkspace package resource resolver serves canonical files and path-safe assets")
    func packageResourceResolverServesCanonicalFilesAndAssets() throws {
        let package = Self.samplePackage()

        let css = try #require(HTMLWorkspacePackageResources.resource(for: HTMLWorkspacePackageEntry.styleCSS, in: package))
        #expect(css.mimeType == "text/css")
        #expect(String(data: css.data, encoding: .utf8) == package.styleCSS)

        let index = try #require(HTMLWorkspacePackageResources.resource(for: HTMLWorkspacePackageEntry.indexHTML, in: package))
        let indexHTML = try #require(String(data: index.data, encoding: .utf8))
        #expect(index.mimeType == "text/html")
        #expect(indexHTML.contains("<h1>Interactive Doc</h1>"))
        #expect(indexHTML.contains("workspace-data"))

        let asset = try #require(HTMLWorkspacePackageResources.resource(for: "assets/texture.png", in: package))
        #expect(asset.mimeType == "image/png")
        #expect(asset.data == package.assets["texture.png"])
        #expect(HTMLWorkspacePackageResources.resource(for: "assets/../texture.png", in: package) == nil)

        let rootRoute = try #require(HTMLWorkspacePackageResources.resource(for: "routes/index.html", in: package))
        let rootRouteHTML = try #require(String(data: rootRoute.data, encoding: .utf8))
        #expect(rootRoute.mimeType == "text/html")
        #expect(rootRouteHTML.contains("<h1>Interactive Doc</h1>"))

        let route = try #require(HTMLWorkspacePackageResources.resource(for: "routes/about.html", in: package))
        let routeHTML = try #require(String(data: route.data, encoding: .utf8))
        #expect(route.mimeType == "text/html")
        #expect(routeHTML.contains("<h1>About</h1>"))
        #expect(routeHTML.contains("workspace-data"))
        #expect(HTMLWorkspacePackageResources.resource(for: "routes/missing.html", in: package) == nil)
        #expect(HTMLWorkspacePackageResources.resource(for: "routes/../about.html", in: package) == nil)
    }

    @Test("HTMLWorkspace export render inlines package assets for headless PDF")
    func exportRenderInlinesPackageAssetsForHeadlessPDF() {
        var package = Self.samplePackage()
        package.indexHTML = #"<main><img src="assets/texture.png" alt=""><video poster="./assets/texture.png"></video><source srcset="/assets/texture.png"><p>assets/texture.png-large</p></main>"#
        package.routes["about.html"] = #"<main><img src="../assets/texture.png" alt=""><img src="routes/assets/texture.png" alt=""></main>"#
        package.styleCSS = #".hero { background-image: url("assets/texture.png"); }"#

        let preview = HTMLWorkspacePreviewDocument.render(package: package)
        let exported = HTMLWorkspacePreviewDocument.render(package: package, resourceMode: .inlinePackageAssets)
        let exportedRoute = HTMLWorkspacePreviewDocument.render(
            package: package,
            routeName: "about.html",
            resourceMode: .inlinePackageAssets
        )
        let dataURL = HTMLWorkspacePackageResources.dataURL(
            for: "texture.png",
            data: Data([0x89, 0x50, 0x4e, 0x47])
        )

        #expect(preview.contains(#"src="assets/texture.png""#))
        #expect(exported.contains(#"src="\#(dataURL)""#))
        #expect(exported.contains(#"poster="\#(dataURL)""#))
        #expect(exported.contains(#"srcset="\#(dataURL)""#))
        #expect(exported.contains(#"url("\#(dataURL)")"#))
        #expect(exportedRoute.contains(#"src="\#(dataURL)""#))
        #expect(!exportedRoute.contains(#"../assets/texture.png"#))
        #expect(!exportedRoute.contains(#"routes/assets/texture.png"#))
        #expect(!exported.contains(#"src="assets/texture.png""#))
        #expect(exported.contains("assets/texture.png-large"))
        #expect(exported.contains("default-src 'none'"))
    }

    @Test("HTMLWorkspace site folder export preserves route-relative package assets")
    func siteFolderExportPreservesRouteRelativePackageAssets() throws {
        let package = Self.samplePackage()
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("html-workspace-site-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folderURL) }

        let summary = try HTMLWorkspaceSiteFolderExporter.export(
            package: package,
            theme: .light,
            to: folderURL
        )

        let rootAssetURL = folderURL
            .appendingPathComponent(HTMLWorkspacePackageEntry.assets, isDirectory: true)
            .appendingPathComponent("texture.png")
        let routeAssetURL = folderURL
            .appendingPathComponent(HTMLWorkspacePackageEntry.routes, isDirectory: true)
            .appendingPathComponent(HTMLWorkspacePackageEntry.assets, isDirectory: true)
            .appendingPathComponent("texture.png")
        let routeURL = folderURL
            .appendingPathComponent(HTMLWorkspacePackageEntry.routes, isDirectory: true)
            .appendingPathComponent("about.html")

        #expect(FileManager.default.fileExists(atPath: folderURL.appendingPathComponent(HTMLWorkspacePackageEntry.indexHTML).path))
        #expect(FileManager.default.fileExists(atPath: routeURL.path))
        #expect(try Data(contentsOf: rootAssetURL) == package.assets["texture.png"])
        #expect(try Data(contentsOf: routeAssetURL) == package.assets["texture.png"])
        #expect(summary.routeCount == 1)
        #expect(summary.assetCount == 1)
        #expect(summary.mirroredRouteAssets)
        #expect(summary.statusText.contains("1 route"))
        #expect(summary.statusText.contains("1 route-relative asset mirror"))
    }

    @Test("HTMLWorkspace routes reserve the route-relative assets mirror path")
    func routesReserveRouteRelativeAssetsMirrorPath() {
        var package = Self.samplePackage()
        package.routes[HTMLWorkspacePackageEntry.assets] = "<main>reserved</main>"

        #expect(throws: HTMLWorkspacePackageError.self) {
            try HTMLWorkspacePackage.validateRoutes(package.routes)
        }
    }

    @Test("HTMLWorkspace setDataFeed patch seeds pending data for the new query")
    func setDataFeedPatchSeedsPendingDataForNewQuery() throws {
        var package = Self.samplePackage()
        package.dataJSON = #"{"results":[{"title":"old"}]}"#

        let feed = HTMLWorkspaceDataFeed.vaultSearch(query: " substrate provenance ", limit: 3)
        package = try HTMLWorkspacePatchApplier.apply(.setDataFeed(feed), to: package)

        #expect(package.manifest.dataFeed == feed)
        let metadata = try #require(HTMLWorkspaceDataFeedStatus.metadata(from: package.dataJSON))
        #expect(metadata.query == "substrate provenance")
        #expect(metadata.limit == 3)
        #expect(metadata.refreshedAtMS == 0)
        #expect(metadata.stale)
        #expect(metadata.error == "Feed pending")
    }

    @Test("HTMLWorkspace vault search dashboard template seeds a live data feed shell")
    func vaultSearchDashboardTemplateSeedsLiveDataFeedShell() throws {
        var package = HTMLWorkspacePackage.defaultPackage()

        package.applyVaultSearchDashboardTemplate(query: "  substrate provenance  ", limit: 99)

        #expect(package.manifest.title == "Vault Search: substrate provenance")
        #expect(package.manifest.dataFeed?.source == .vaultSearch)
        #expect(package.manifest.dataFeed?.normalizedQuery == "substrate provenance")
        #expect(package.manifest.dataFeed?.limit == HTMLWorkspaceDataFeed.maxLimit)
        #expect(package.manifest.contentHash == package.currentContentHash)
        #expect(package.indexHTML.contains("data-vault-results"))
        #expect(package.indexHTML.contains("data-result-filter"))
        #expect(package.indexHTML.contains("data-context-picker"))
        #expect(package.indexHTML.contains("data-result-sort"))
        #expect(package.indexHTML.contains("data-pin-context"))
        #expect(package.indexHTML.contains("data-pinned-context"))
        #expect(package.indexHTML.contains("data-context-dropzone"))
        #expect(package.indexHTML.contains("data-filter-count"))
        #expect(package.indexHTML.contains("data-context-requirement"))
        #expect(package.indexHTML.contains("data-context-drop-status"))
        #expect(package.indexHTML.contains("data-context-tabs"))
        #expect(package.indexHTML.contains(#"data-result-chart data-context-dropzone"#))
        #expect(package.indexHTML.contains(#"data-result-detail data-context-dropzone"#))
        #expect(package.indexHTML.contains(#"data-vault-results data-context-dropzone"#))
        #expect(package.indexHTML.contains(#"aria-label="Workspace sections""#))
        #expect(package.indexHTML.contains(##"href="#context-feed""##))
        #expect(package.indexHTML.contains(##"href="#pinned-context""##))
        #expect(package.indexHTML.contains(##"href="#rank-signal""##))
        #expect(package.indexHTML.contains(##"href="#selected-source""##))
        #expect(package.indexHTML.contains(##"href="#vault-results""##))
        #expect(package.indexHTML.contains(#"id="context-feed""#))
        #expect(package.indexHTML.contains(#"id="pinned-context""#))
        #expect(package.indexHTML.contains(#"id="rank-signal""#))
        #expect(package.indexHTML.contains(#"id="selected-source""#))
        #expect(package.indexHTML.contains(#"id="vault-results""#))
        #expect(package.styleCSS.contains(".result-card"))
        #expect(package.styleCSS.contains(".feed-controls input"))
        #expect(package.styleCSS.contains(".feed-controls select"))
        #expect(package.styleCSS.contains(".workspace-nav"))
        #expect(package.styleCSS.contains("scroll-margin-top"))
        #expect(package.styleCSS.contains(".context-tab"))
        #expect(package.styleCSS.contains(".detail-tab"))
        #expect(package.styleCSS.contains(".pinned-context"))
        #expect(package.styleCSS.contains("[data-context-dropzone].is-drop-target"))
        #expect(package.styleCSS.contains(".pinned-card"))
        #expect(package.styleCSS.contains(".feed-chart"))
        #expect(package.styleCSS.contains(".result-detail"))
        #expect(package.scriptJS.contains("renderVaultResults"))
        #expect(package.scriptJS.contains("visibleResults(allResults)"))
        #expect(package.scriptJS.contains("function sortedResults(results)"))
        #expect(package.scriptJS.contains("const sortMode = HTMLWorkspace.q('[data-result-sort]')?.value || 'rank-desc';"))
        #expect(package.scriptJS.contains("sortMode === 'rank-asc'"))
        #expect(package.scriptJS.contains("sortMode === 'source-asc'"))
        #expect(package.scriptJS.contains("sortMode === 'context-asc'"))
        #expect(package.scriptJS.contains("sortedResults(visibleResults(allResults))"))
        #expect(package.scriptJS.contains("function renderContextPicker(results, selected)"))
        #expect(package.scriptJS.contains("const source = result.source_label || 'Vault search result';"))
        #expect(package.scriptJS.contains("'data-context-kind': kind"))
        #expect(package.scriptJS.contains("'data-source-label': source"))
        #expect(package.scriptJS.contains("`${title} / ${source} / ${kind}`"))
        #expect(package.scriptJS.contains("let pinnedContextKeys = [];"))
        #expect(package.scriptJS.contains("let contextDropStatus = '';"))
        #expect(package.scriptJS.contains("let contextDropKey = null;"))
        #expect(package.scriptJS.contains("const pinnedContextLimit = 16;"))
        #expect(package.scriptJS.contains("pinnedContextKeys.splice(0, pinnedContextKeys.length - pinnedContextLimit);"))
        #expect(!package.scriptJS.contains("localStorage"))
        #expect(!package.scriptJS.contains("sessionStorage"))
        #expect(!package.scriptJS.contains("indexedDB"))
        #expect(!package.scriptJS.contains("pinnedContextStorageKey"))
        #expect(!package.scriptJS.contains("loadPinnedContextKeys"))
        #expect(!package.scriptJS.contains("savePinnedContextKeys"))
        #expect(package.scriptJS.contains("const contextDragType = 'application/x-epistemos-context-key';"))
        #expect(package.scriptJS.contains("const nativeContextDragType = 'com.epistemos.workspace-context';"))
        #expect(package.scriptJS.contains("function updatePinButton(selected)"))
        #expect(package.scriptJS.contains("function renderPinnedContext(allResults)"))
        #expect(package.scriptJS.contains("function selectPinnedContext(key)"))
        #expect(package.scriptJS.contains("function pinContextKey(key)"))
        #expect(package.scriptJS.contains("function pinSelectedContext()"))
        #expect(package.scriptJS.contains("function refreshContextDropStatus(allResults)"))
        #expect(package.scriptJS.contains("Dropped context is no longer in the current data.json feed."))
        #expect(package.scriptJS.contains("refreshContextDropStatus(allResults);"))
        #expect(package.scriptJS.contains("function droppedContextPayload(event)"))
        #expect(package.scriptJS.contains("types.includes(contextDragType) || types.includes(nativeContextDragType) || types.includes('text/plain')"))
        #expect(package.scriptJS.contains("event.dataTransfer?.getData(nativeContextDragType)"))
        #expect(package.scriptJS.contains("function droppedPayloadField(payload, fieldName)"))
        #expect(package.scriptJS.contains("function contextKeyFromDroppedPayload(payload, allResults)"))
        #expect(package.scriptJS.contains("droppedPayloadField(raw, 'page_id')"))
        #expect(package.scriptJS.contains("droppedPayloadField(raw, 'context_kind')"))
        #expect(package.scriptJS.contains("droppedPayloadField(raw, 'source_label')"))
        #expect(package.scriptJS.contains("droppedPayloadField(raw, 'Provenance')"))
        #expect(package.scriptJS.contains("return expected.endsWith('...') && actualText.startsWith(expected.slice(0, -3));"))
        #expect(package.scriptJS.contains("function pinDroppedContextKey(key)"))
        #expect(package.scriptJS.contains("function pinDroppedContextPayload(payload)"))
        #expect(package.scriptJS.contains("Dropped context is not in the current data.json feed."))
        #expect(package.scriptJS.contains("Context selected from current data.json feed."))
        #expect(package.scriptJS.contains("function clearContextDropTargets()"))
        #expect(package.scriptJS.contains("function installContextDropzone(dropzone)"))
        #expect(package.scriptJS.contains("document.querySelectorAll('[data-context-dropzone].is-drop-target')"))
        #expect(package.scriptJS.contains("event.relatedTarget && dropzone.contains(event.relatedTarget)"))
        #expect(package.scriptJS.contains("picker.disabled = results.length === 0;"))
        #expect(package.scriptJS.contains("button.textContent = alreadyPinned ? 'Pinned' : 'Pin source';"))
        #expect(package.scriptJS.contains("renderPinnedContext(allResults)"))
        #expect(package.scriptJS.contains("selectedContextKind = 'all';"))
        #expect(package.scriptJS.contains("selectedResultKey = event.currentTarget.value || null;"))
        #expect(package.scriptJS.contains("pinContextKey(selectedResultKey);"))
        #expect(package.scriptJS.contains("draggable: 'true'"))
        #expect(package.scriptJS.contains("event.dataTransfer.setData(contextDragType, key);"))
        #expect(package.scriptJS.contains("addEventListener('drop', (event) => {"))
        #expect(package.scriptJS.contains("pinDroppedContextPayload(payload);"))
        #expect(package.scriptJS.contains("document.querySelectorAll('[data-context-dropzone]').forEach(installContextDropzone);"))
        #expect(package.scriptJS.contains("addEventListener('click', pinSelectedContext)"))
        #expect(package.scriptJS.contains("addEventListener('change', renderVaultResults)"))
        #expect(package.scriptJS.contains("function requiredContextLabel(meta)"))
        #expect(package.scriptJS.contains("meta.required_context_kind"))
        #expect(package.scriptJS.contains("meta.required_context_available"))
        #expect(package.scriptJS.contains("text('[data-context-requirement]', requiredContextLabel(meta));"))
        #expect(package.scriptJS.contains("text('[data-context-drop-status]', contextDropStatus);"))
        #expect(package.scriptJS.contains("renderContextTabs(allResults, meta)"))
        #expect(package.scriptJS.contains("renderResultChart(results)"))
        #expect(package.scriptJS.contains("renderResultDetail(results)"))
        #expect(package.scriptJS.contains("addEventListener('input', renderVaultResults)"))
        #expect(package.scriptJS.contains("htmlworkspace:datachange"))

        let metadata = try #require(HTMLWorkspaceDataFeedStatus.metadata(from: package.dataJSON))
        #expect(metadata.query == "substrate provenance")
        #expect(metadata.limit == HTMLWorkspaceDataFeed.maxLimit)
        #expect(metadata.provenance == "VaultSyncService.searchFullAsync")
        #expect(metadata.stale == true)

        let rendered = HTMLWorkspacePreviewDocument.render(package: package)
        #expect(rendered.contains("data-vault-results"))
        #expect(rendered.contains(#"id="workspace-data""#))
    }

    @Test("legacy script.js packages still load into the main JS source")
    func legacyScriptPackagesStillLoad() throws {
        let manifestData = try JSONEncoder.epdocCanonical.encode(Self.sampleManifest())
        let wrapper = FileWrapper(directoryWithFileWrappers: [
            HTMLWorkspacePackageEntry.manifest: FileWrapper(regularFileWithContents: manifestData),
            HTMLWorkspacePackageEntry.indexHTML: FileWrapper(regularFileWithContents: Data("<main></main>".utf8)),
            HTMLWorkspacePackageEntry.legacyScriptJS: FileWrapper(regularFileWithContents: Data("document.body.dataset.legacy = 'true';".utf8)),
        ])

        let package = try HTMLWorkspacePackage(fileWrapper: wrapper)
        #expect(package.scriptJS.contains("legacy"))
        #expect(package.dataJSON == "{}")
    }

    @Test("manifest validation rejects malformed or newer package schemas")
    func manifestValidationRejectsBadPackages() throws {
        let malformed = FileWrapper(directoryWithFileWrappers: [
            HTMLWorkspacePackageEntry.manifest: FileWrapper(regularFileWithContents: Data("{".utf8)),
            HTMLWorkspacePackageEntry.indexHTML: FileWrapper(regularFileWithContents: Data("<main></main>".utf8)),
        ])
        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try HTMLWorkspacePackage(fileWrapper: malformed)
        }

        var tooNewManifest = Self.sampleManifest()
        tooNewManifest.schemaVersion = HTMLWorkspaceManifest.currentSchemaVersion + 1
        let tooNew = FileWrapper(directoryWithFileWrappers: [
            HTMLWorkspacePackageEntry.manifest: FileWrapper(regularFileWithContents: try JSONEncoder.epdocCanonical.encode(tooNewManifest)),
            HTMLWorkspacePackageEntry.indexHTML: FileWrapper(regularFileWithContents: Data("<main></main>".utf8)),
        ])
        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try HTMLWorkspacePackage(fileWrapper: tooNew)
        }
    }

    @Test("offline preview injects CSP that blocks network and app internals by default")
    func offlinePreviewInjectsCSP() {
        let package = Self.samplePackage()
        let srcdoc = HTMLWorkspacePreviewDocument.render(package: package)
        let darkSrcdoc = HTMLWorkspacePreviewDocument.render(package: package, theme: .dark)
        #expect(package.manifest.sandboxPolicy.allowNetwork == false)
        #expect(package.manifest.sandboxPolicy.allowAppBridge == false)
        #expect(srcdoc.contains("Content-Security-Policy"))
        #expect(srcdoc.contains("default-src 'none'"))
        #expect(srcdoc.contains("connect-src \(HTMLWorkspaceLocalResourceScheme.contentSecurityPolicySource)"))
        #expect(srcdoc.contains(#"id="workspace-data""#))
        #expect(darkSrcdoc.contains(#"data-epistemos-theme="dark""#))
        #expect(darkSrcdoc.contains(#"id="epistemos-font-face""#))
        #expect(darkSrcdoc.contains(#"id="epistemos-theme-host""#))
        #expect(darkSrcdoc.contains("--epistemos-workspace-title-font"))
        #expect(darkSrcdoc.contains("MatrixTypeDisplay"))
        #expect(darkSrcdoc.contains(#"font-family: "MatrixTypeDisplay-Regular";"#))
        #expect(darkSrcdoc.contains(#"font-family: "MatrixTypeDisplay";"#))
        #expect(darkSrcdoc.contains(#"font-family: "ChonkyPixels";"#))
        #expect(darkSrcdoc.contains("data-metric-value"))
        #expect(darkSrcdoc.contains("font-synthesis: none"))
        #expect(srcdoc.contains("window, 'HTMLWorkspace'"))
        #expect(srcdoc.contains("get data()"))
        #expect(srcdoc.contains("app: appBridge"))
        #expect(srcdoc.contains("window, 'HTMLWorkspaceApp'"))
        #expect(srcdoc.contains("enabled: false"))
        #expect(srcdoc.contains("request() { return Promise.reject(new Error('HTML Workspace app bridge is disabled')); }"))
        #expect(srcdoc.contains("__epistemosReplaceWorkspaceData"))
        #expect(srcdoc.contains("htmlworkspace:datachange"))
        #expect(!srcdoc.contains("window.webkit.messageHandlers"),
                "Preview HTML must not expose app bridge handlers unless an explicit safe API is enabled.")
    }

    @Test("app bridge helper is stable but native handler is explicit opt-in")
    func appBridgeHelperRequiresSandboxOptIn() {
        var package = Self.samplePackage()
        package.manifest.sandboxPolicy.allowAppBridge = true
        package.manifest.sandboxPolicy.safeAPIVersion = 7

        let srcdoc = HTMLWorkspacePreviewDocument.render(package: package)

        #expect(srcdoc.contains("app: appBridge"))
        #expect(srcdoc.contains("window, 'HTMLWorkspaceApp'"))
        #expect(srcdoc.contains("enabled: true"))
        #expect(srcdoc.contains("safeAPIVersion: 7"))
        #expect(srcdoc.contains(HTMLWorkspaceSafeAPI.messageHandlerName))
        #expect(srcdoc.contains("HTMLWorkspaceSafeAPI.messageHandlerName") == false)
        #expect(srcdoc.contains("requestId: 'safeapi-' + (++requestCounter)"))
        #expect(srcdoc.contains("const pendingRequests = new Map()"))
        #expect(srcdoc.contains("const boundedAttributes = (value) =>"))
        #expect(srcdoc.contains("const record = (eventName = null, attributes = null) =>"))
        #expect(srcdoc.contains("const request = (command, message = null, options = {}) => new Promise"))
        #expect(srcdoc.contains("window.addEventListener(responseEventName"))
        #expect(srcdoc.contains("const response = Object.freeze({"))
        #expect(srcdoc.contains("if (detail.ok === false)"))
        #expect(srcdoc.contains("entry.reject(bridgeError("))
        #expect(srcdoc.contains("entry.resolve(response);"))
        #expect(srcdoc.contains("request,"))
        #expect(srcdoc.contains("ping(message = null) { return post('ping', message); }"))
        #expect(srcdoc.contains("status() { return post('workspace.status'); }"))
        #expect(srcdoc.contains("status() { return post('workspace.status'); },\n            record"))
    }

    @Test("importing exported HTML preserves user sources without host scaffold")
    func importingExportedHTMLPreservesUserSourcesWithoutHostScaffold() {
        let package = HTMLWorkspacePackage(
            manifest: Self.sampleManifest(),
            indexHTML: #"<main class="user-card"><h1>Imported</h1></main>"#,
            styleCSS: "  :root { --card-gap: 12px; }\n.user-card { display: grid; gap: var(--card-gap); }\n",
            scriptJS: "\ndocument.body.dataset.userScript = 'true';\n",
            dataJSON: #"{"message":"hello","danger":"</script><!--"}"#
        )

        let exported = HTMLWorkspacePreviewDocument.render(package: package, theme: .dark)
        let imported = HTMLWorkspaceHTMLImporter.importSources(from: exported)

        #expect(exported.contains(#"id="epistemos-workspace-runtime""#))
        #expect(exported.contains(#"<\/script><!--"#))
        #expect(imported.html == package.indexHTML)
        #expect(imported.css == package.styleCSS)
        #expect(imported.js == package.scriptJS)
        #expect(imported.dataJSON == package.dataJSON)
        #expect(!imported.css.contains("--epistemos-workspace-title-font"))
        #expect(!imported.css.contains("html[data-epistemos-theme]"))
        #expect(!imported.js.contains("Object.defineProperty(window, 'HTMLWorkspace'"))
    }

    @Test("HTML import keeps only executable user scripts")
    func htmlImportKeepsOnlyExecutableUserScripts() {
        let source = """
        <!doctype html>
        <html>
        <head>
          <style>.card { color: red; }</style>
        </head>
        <body>
          <main>Import</main>
          <script type="application/json; charset=utf-8">{"ignored":true}</script>
          <script type="importmap">{"imports":{"x":"/x.js"}}</script>
          <script type="module">export const moduleValue = 1;</script>
          <script type="text/javascript">window.plainScript = true;</script>
        </body>
        </html>
        """

        let imported = HTMLWorkspaceHTMLImporter.importSources(from: source)

        #expect(imported.css == ".card { color: red; }")
        #expect(imported.js.contains("export const moduleValue = 1;"))
        #expect(imported.js.contains("window.plainScript = true;"))
        #expect(!imported.js.contains(#""ignored":true"#))
        #expect(!imported.js.contains(#""imports""#))
    }

    @Test("default workspace uses display fonts for title and metric numerals")
    func defaultWorkspaceUsesDisplayTypography() {
        let package = HTMLWorkspacePackage.defaultPackage()

        #expect(package.styleCSS.contains("font-family: var(--epistemos-workspace-title-font);"))
        #expect(package.styleCSS.contains("font-family: var(--epistemos-workspace-heading-font);"))
        #expect(package.styleCSS.contains(".metric-card strong"))
        #expect(package.styleCSS.contains("line-height: 0.95"))
        #expect(package.styleCSS.contains(".metric-card {\n              padding: 14px;\n              border: 0;"))
        #expect(package.styleCSS.contains("box-shadow: 0 10px 28px"))
        #expect(package.scriptJS.contains("if (metrics.length === 0)"))
        #expect(package.scriptJS.contains("No local data attached yet."))
        #expect(package.dataJSON.contains(#""metrics": []"#))
        #expect(!package.dataJSON.contains("Nodes"))
        #expect(!package.dataJSON.contains("Signals"))
        #expect(!package.dataJSON.contains("Views"))
    }

    @Test("vault search dashboard uses flat source-aware context cards")
    func vaultSearchDashboardUsesFlatSourceAwareContextCards() {
        let package = HTMLWorkspaceVaultSearchDashboardTemplate.package(query: "context")

        #expect(package.styleCSS.contains("box-shadow: 0 10px 28px"))
        #expect(!package.styleCSS.contains("border: 1px solid var(--epistemos-workspace-border);"))
        #expect(!package.styleCSS.contains("border: 1px"))
        #expect(package.styleCSS.contains("border: 0"))
        #expect(package.scriptJS.contains("resultSearchText(result)"))
        #expect(package.scriptJS.contains("No results match this filter."))
        #expect(package.scriptJS.contains("No matching context records yet."))
        #expect(package.scriptJS.contains("result.source_label || 'Vault search result'"))
        #expect(package.scriptJS.contains("result.context_kind || 'vault_record'"))
        #expect(package.scriptJS.contains("result.provenance"))
        #expect(package.scriptJS.contains("class: 'source-label'"))
    }

    @Test("vault search dashboard chart is bound to real result ranks")
    func vaultSearchDashboardChartIsBoundToRealResultRanks() {
        let package = HTMLWorkspaceVaultSearchDashboardTemplate.package(query: "context")

        #expect(package.indexHTML.contains(#"aria-label="Result rank chart""#))
        #expect(package.scriptJS.contains("function rankDatum(result, index)"))
        #expect(package.scriptJS.contains("const value = Number(result.rank);"))
        #expect(package.scriptJS.contains("!Number.isFinite(value) || value <= 0"))
        #expect(package.scriptJS.contains(".sort((a, b) => b.value - a.value)"))
        #expect(package.scriptJS.contains("No numeric ranks available for charting."))
        #expect(package.scriptJS.contains("No visible results to chart."))
        #expect(package.scriptJS.contains("class: 'chart-bar'"))
        #expect(!package.scriptJS.contains("Math.random"))
    }

    @Test("vault search dashboard tabs are driven by real context kinds")
    func vaultSearchDashboardTabsAreDrivenByRealContextKinds() {
        let package = HTMLWorkspaceVaultSearchDashboardTemplate.package(query: "context")

        #expect(package.indexHTML.contains(#"aria-label="Context kind tabs""#))
        #expect(package.scriptJS.contains("let selectedContextKind = 'all';"))
        #expect(package.scriptJS.contains("function resultContextKind(result)"))
        #expect(package.scriptJS.contains("result.context_kind || 'vault_record'"))
        #expect(package.scriptJS.contains("const metadataKinds = Array.isArray(meta.context_kinds) ? meta.context_kinds : [];"))
        #expect(package.scriptJS.contains("function resultsForSelectedKind(results)"))
        #expect(package.scriptJS.contains("function resultCountLabel(results, allResults, filter)"))
        #expect(package.scriptJS.contains("selectedContextKind !== 'all' || filter"))
        #expect(package.scriptJS.contains("text('[data-filter-count]', resultCountLabel(results, allResults, filter));"))
        #expect(package.scriptJS.contains("selectedContextKind = kind;"))
        #expect(package.scriptJS.contains("'data-context-kind': kind"))
        #expect(package.scriptJS.contains("renderVaultResults();"))
        #expect(!package.scriptJS.contains("fakeContext"))
    }

    @Test("vault search dashboard cards select real result detail")
    func vaultSearchDashboardCardsSelectRealResultDetail() {
        let package = HTMLWorkspaceVaultSearchDashboardTemplate.package(query: "context")

        #expect(package.indexHTML.contains(#"aria-label="Selected result detail""#))
        #expect(package.scriptJS.contains("let selectedResultKey = null;"))
        #expect(package.scriptJS.contains("const selectedDetailViews = ['summary', 'metadata'];"))
        #expect(package.scriptJS.contains("let selectedDetailView = 'summary';"))
        #expect(package.scriptJS.contains("function resultKey(result)"))
        #expect(package.scriptJS.contains("function activeResult(results)"))
        #expect(package.scriptJS.contains("function renderDetailTabs()"))
        #expect(package.scriptJS.contains("function renderResultDetail(results)"))
        #expect(package.scriptJS.contains("function detailRow(label, value)"))
        #expect(package.scriptJS.contains("class: active ? 'detail-tab is-active' : 'detail-tab'"))
        #expect(package.scriptJS.contains("'data-detail-view': view"))
        #expect(package.scriptJS.contains("selectedDetailView = view;"))
        #expect(package.scriptJS.contains("selectedDetailView === 'metadata'"))
        #expect(package.scriptJS.contains("'data-result-key': key"))
        #expect(package.scriptJS.contains("role: 'button'"))
        #expect(package.scriptJS.contains("tabindex: '0'"))
        #expect(package.scriptJS.contains("card.addEventListener('click'"))
        #expect(package.scriptJS.contains("card.addEventListener('keydown'"))
        #expect(package.scriptJS.contains("selected.provenance || 'VaultSyncService.searchFullAsync'"))
        #expect(package.scriptJS.contains("No visible result selected."))
    }

    @Test("starter template detection distinguishes untouched defaults from edited workspaces")
    func starterTemplateDetectionDistinguishesEditedWorkspaces() {
        let starter = HTMLWorkspacePackage.defaultPackage()
        var edited = starter
        edited.indexHTML = "<main><h1>User pasted code</h1></main>"
        var routed = starter
        routed.routes["about.html"] = "<main><h1>About</h1></main>"

        #expect(starter.isStarterTemplateContent)
        #expect(!edited.isStarterTemplateContent)
        #expect(!routed.isStarterTemplateContent)
        #expect(!Self.samplePackage().isStarterTemplateContent)
    }

    @Test("structured patch operations update sources without arbitrary mutation strings")
    func structuredPatchOperationsApply() throws {
        var package = Self.samplePackage()
        let originalUpdatedAt = package.manifest.updatedAt
        package = try HTMLWorkspacePatchApplier.apply(.replaceHTML("<section id=\"root\"></section>"), to: package)
        package = try HTMLWorkspacePatchApplier.apply(.replaceCSS("#root { min-height: 200px; }"), to: package)
        package = try HTMLWorkspacePatchApplier.apply(.replaceJS("document.querySelector('#root')?.setAttribute('data-live', 'true');"), to: package)
        package = try HTMLWorkspacePatchApplier.apply(.replaceDataJSON(#"{"nodes":[1,2,3]}"#), to: package)
        package = try HTMLWorkspacePatchApplier.apply(.insertBlock(HTMLWorkspaceBlockInsertion(
            html: "<button>Run</button>",
            location: .beforeClosingBody
        )), to: package)

        #expect(package.indexHTML.contains("<section id=\"root\"></section>"))
        #expect(package.indexHTML.contains("<button>Run</button>"))
        #expect(package.styleCSS.contains("min-height"))
        #expect(package.scriptJS.contains("data-live"))
        #expect(package.dataJSON.contains("\"nodes\""))
        #expect(package.manifest.updatedAt > originalUpdatedAt)
        #expect(package.manifest.contentHash == HTMLWorkspaceDocument.contentHash(
            indexHTML: package.indexHTML,
            styleCSS: package.styleCSS,
            scriptJS: package.scriptJS,
            dataJSON: package.dataJSON,
            routes: package.routes,
            assets: package.assets
        ))
    }

    @Test("replaceDocument swaps the generated source quad atomically")
    func replaceDocumentPatchOperationAppliesAtomically() throws {
        let original = Self.samplePackage()
        let replacement = HTMLWorkspaceDocumentReplacement(
            title: "Generated Explainer",
            html: "<main><h1>Generated Explainer</h1></main>",
            css: "main { display: grid; }",
            js: "document.body.dataset.generated = 'true';",
            dataJSON: #"{"generated":true}"#
        )

        let updated = try HTMLWorkspacePatchApplier.apply(.replaceDocument(replacement), to: original)

        #expect(updated.manifest.id == original.manifest.id)
        #expect(updated.manifest.sandboxPolicy == original.manifest.sandboxPolicy)
        #expect(updated.manifest.title == "Generated Explainer")
        #expect(updated.indexHTML == replacement.html)
        #expect(updated.styleCSS == replacement.css)
        #expect(updated.scriptJS == replacement.js)
        #expect(updated.dataJSON == replacement.dataJSON)
        #expect(updated.routes == original.routes)
        #expect(updated.assets == original.assets)
        #expect(updated.snapshots["initial.html"] == original.snapshots["initial.html"])
        let preReplaceSnapshot = try #require(updated.snapshots.first {
            $0.key.hasPrefix("pre-replace-") && $0.key.hasSuffix(".html")
        })
        #expect(preReplaceSnapshot.key.hasSuffix(".html"))
        #expect(String(data: preReplaceSnapshot.value, encoding: .utf8)?.contains("Interactive Doc") == true)
        #expect(String(data: preReplaceSnapshot.value, encoding: .utf8)?.contains("workspace-data") == true)
        let sourceSnapshotName = HTMLWorkspaceSourceSnapshot.sourceName(forRenderedSnapshotName: preReplaceSnapshot.key)
        let sourceSnapshotData = try #require(updated.snapshots[sourceSnapshotName])
        let sourceSnapshot = try HTMLWorkspaceSourceSnapshot.decode(from: sourceSnapshotData)
        #expect(sourceSnapshot.indexHTML == original.indexHTML)
        #expect(sourceSnapshot.styleCSS == original.styleCSS)
        #expect(sourceSnapshot.scriptJS == original.scriptJS)
        #expect(sourceSnapshot.dataJSON == original.dataJSON)
        #expect(sourceSnapshot.routes == original.routes)
        #expect(sourceSnapshot.assets == original.assets)
        let provenance = try #require(updated.manifest.generationProvenance)
        #expect(provenance.producer == .agent)
        #expect(provenance.operation == .replaceDocument)
        #expect(provenance.previousContentHash == HTMLWorkspaceDocument.contentHash(
            indexHTML: original.indexHTML,
            styleCSS: original.styleCSS,
            scriptJS: original.scriptJS,
            dataJSON: original.dataJSON,
            routes: original.routes,
            assets: original.assets
        ))
        #expect(provenance.contentHash == HTMLWorkspaceDocument.contentHash(
            indexHTML: replacement.html,
            styleCSS: replacement.css,
            scriptJS: replacement.js,
            dataJSON: replacement.dataJSON,
            routes: original.routes,
            assets: original.assets
        ))
        #expect(provenance.reversibleSnapshotName == preReplaceSnapshot.key)
        #expect(provenance.toolId == HTMLWorkspaceGenerationProvenance.patchToolID)
        #expect(provenance.generatedAt > 0)
        #expect(updated.manifest.updatedAt == provenance.generatedAt)
        #expect(updated.manifest.contentHash == provenance.contentHash)
    }

    @Test("replaceDocument can swap routes and assets as part of the full package")
    func replaceDocumentPatchOperationReplacesPackageMapsWhenExplicit() throws {
        let original = Self.samplePackage()
        let replacementAssets = ["hero.txt": Data("asset proof".utf8)]
        let replacementRoutes = ["landing.html": "<main><h1>Landing Route</h1></main>"]
        let replacement = HTMLWorkspaceDocumentReplacement(
            title: "Generated App",
            html: "<main><h1>Generated App</h1></main>",
            css: "main { min-height: 100vh; }",
            js: "document.body.dataset.generatedApp = 'true';",
            dataJSON: #"{"generatedApp":true}"#,
            routes: replacementRoutes,
            assets: replacementAssets
        )

        let updated = try HTMLWorkspacePatchApplier.apply(.replaceDocument(replacement), to: original)

        #expect(updated.routes == replacementRoutes)
        #expect(updated.assets == replacementAssets)
        #expect(updated.routes["about.html"] == nil)
        #expect(updated.assets["texture.png"] == nil)
        #expect(updated.manifest.generationProvenance?.previousContentHash == HTMLWorkspaceDocument.contentHash(
            indexHTML: original.indexHTML,
            styleCSS: original.styleCSS,
            scriptJS: original.scriptJS,
            dataJSON: original.dataJSON,
            routes: original.routes,
            assets: original.assets
        ))
        #expect(updated.manifest.contentHash == HTMLWorkspaceDocument.contentHash(
            indexHTML: replacement.html,
            styleCSS: replacement.css,
            scriptJS: replacement.js,
            dataJSON: replacement.dataJSON,
            routes: replacementRoutes,
            assets: replacementAssets
        ))
    }

    @Test("restoreSnapshot restores a source snapshot including routes and assets")
    func restoreSnapshotPatchOperationRestoresSourceSnapshotPackage() throws {
        var original = Self.samplePackage()
        original.manifest.dataFeed = .vaultSearch(query: "restore proof", limit: 3)
        let replacement = HTMLWorkspaceDocumentReplacement(
            title: "Generated App",
            html: "<main><h1>Generated App</h1></main>",
            css: "main { min-height: 100vh; }",
            js: "document.body.dataset.generatedApp = 'true';",
            dataJSON: #"{"generatedApp":true}"#,
            routes: ["landing.html": "<main><h1>Landing Route</h1></main>"],
            assets: ["hero.txt": Data("asset proof".utf8)]
        )

        let replaced = try HTMLWorkspacePatchApplier.apply(.replaceDocument(replacement), to: original)
        let snapshotName = try #require(replaced.manifest.generationProvenance?.reversibleSnapshotName)
        let restored = try HTMLWorkspacePatchApplier.apply(.restoreSnapshot(name: snapshotName), to: replaced)

        #expect(restored.manifest.id == original.manifest.id)
        #expect(restored.manifest.title == original.manifest.title)
        #expect(restored.indexHTML == original.indexHTML)
        #expect(restored.styleCSS == original.styleCSS)
        #expect(restored.scriptJS == original.scriptJS)
        #expect(restored.dataJSON == original.dataJSON)
        #expect(restored.routes == original.routes)
        #expect(restored.assets == original.assets)
        #expect(restored.manifest.dataFeed == original.manifest.dataFeed)
        #expect(restored.manifest.generationProvenance?.operation == .restoreSnapshot)
        #expect(restored.manifest.generationProvenance?.previousContentHash == replaced.currentContentHash)
        #expect(restored.manifest.generationProvenance?.contentHash == original.currentContentHash)
        #expect(restored.manifest.generationProvenance?.reversibleSnapshotName?.hasPrefix("pre-replace-") == true)
    }

    @Test("restoreSnapshot falls back to rendered HTML snapshots from older packages")
    func restoreSnapshotPatchOperationFallsBackToRenderedHTML() throws {
        var package = Self.samplePackage()
        package.indexHTML = "<main><h1>Generated</h1></main>"
        package.styleCSS = "main { color: red; }"
        package.scriptJS = "document.body.dataset.generated = 'true';"
        package.dataJSON = #"{"generated":true}"#
        package.snapshots["legacy.html"] = Data("""
        <!doctype html>
        <html>
        <head>
          <style>main { color: green; }</style>
        </head>
        <body>
          <main><h1>Legacy Snapshot</h1></main>
          <script id="workspace-data" type="application/json">{"legacy":true}</script>
          <script>document.body.dataset.legacy = 'true';</script>
        </body>
        </html>
        """.utf8)

        let restored = try HTMLWorkspacePatchApplier.apply(.restoreSnapshot(name: "legacy.html"), to: package)

        #expect(restored.indexHTML.contains("Legacy Snapshot"))
        #expect(restored.styleCSS.contains("color: green"))
        #expect(restored.scriptJS.contains("dataset.legacy"))
        #expect(restored.dataJSON == #"{"legacy":true}"#)
        #expect(restored.routes == package.routes)
        #expect(restored.assets == package.assets)
        #expect(restored.manifest.generationProvenance?.operation == .restoreSnapshot)
    }

    @Test("advanced structured operations are deterministic and path safe")
    func advancedStructuredPatchOperationsApply() throws {
        var package = Self.samplePackage()
        package.styleCSS += "\n.panel { color: red; }"

        package = try HTMLWorkspacePatchApplier.apply(
            .updateStyleRule(HTMLWorkspaceStyleRulePatch(
                selector: ".panel",
                declarations: ["color": "blue", "display": "grid"]
            )),
            to: package
        )
        package = try HTMLWorkspacePatchApplier.apply(
            .addAsset(HTMLWorkspaceAsset(name: "fixture.json", data: Data("{\"ok\":true}".utf8))),
            to: package
        )
        package = try HTMLWorkspacePatchApplier.apply(
            .setRoute(name: "details.html", html: "<main><h1>Details</h1></main>"),
            to: package
        )
        package = try HTMLWorkspacePatchApplier.apply(.removeAsset(name: "texture.png"), to: package)
        package = try HTMLWorkspacePatchApplier.apply(.removeRoute(name: "about.html"), to: package)
        package = try HTMLWorkspacePatchApplier.apply(.captureSnapshot(name: "after-chart.html"), to: package)
        package = try HTMLWorkspacePatchApplier.apply(
            .recordConsoleError(HTMLWorkspaceConsoleError(
                message: "ReferenceError: nope",
                source: "main.js",
                line: 12,
                column: 4,
                timestamp: Self.createdAt + 2_000
            )),
            to: package
        )

        #expect(package.styleCSS.contains(".panel {"))
        #expect(package.styleCSS.contains("color: blue;"))
        #expect(!package.styleCSS.contains("color: red;"))
        #expect(package.assets["fixture.json"] == Data("{\"ok\":true}".utf8))
        #expect(package.assets["texture.png"] == nil)
        #expect(package.routes["details.html"]?.contains("Details") == true)
        #expect(package.routes["about.html"] == nil)
        #expect(package.snapshots["after-chart.html"] != nil)
        #expect(package.consoleErrors.last?.message == "ReferenceError: nope")

        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try HTMLWorkspacePatchApplier.apply(
                .addAsset(HTMLWorkspaceAsset(name: "../secret", data: Data())),
                to: package
            )
        }
        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try HTMLWorkspacePatchApplier.apply(.removeAsset(name: "../secret"), to: package)
        }
        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try HTMLWorkspacePatchApplier.apply(.setRoute(name: "../secret.html", html: "<main></main>"), to: package)
        }
    }

    @Test("style rule values cannot inject additional declarations")
    func styleRuleValuesCannotInjectAdditionalDeclarations() throws {
        let package = Self.samplePackage()

        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try HTMLWorkspacePatchApplier.apply(
                .updateStyleRule(HTMLWorkspaceStyleRulePatch(
                    selector: ".panel",
                    declarations: ["color": "blue; display: grid"]
                )),
                to: package
            )
        }
        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try HTMLWorkspacePatchApplier.apply(
                .updateStyleRule(HTMLWorkspaceStyleRulePatch(
                    selector: ".panel",
                    declarations: ["background-image": "url(javascript:alert(1))"]
                )),
                to: package
            )
        }
        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try HTMLWorkspacePatchApplier.apply(
                .updateStyleRule(HTMLWorkspaceStyleRulePatch(
                    selector: ".panel",
                    declarations: ["width": "expression(alert(1))"]
                )),
                to: package
            )
        }
        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try HTMLWorkspacePatchApplier.apply(
                .updateStyleRule(HTMLWorkspaceStyleRulePatch(
                    selector: ".panel",
                    declarations: ["color": "@import url(evil.css)"]
                )),
                to: package
            )
        }
    }

    @Test("console errors and snapshots remain bounded")
    func consoleErrorsAndSnapshotsRemainBounded() throws {
        var package = Self.samplePackage()

        for index in 0..<80 {
            package = try HTMLWorkspacePatchApplier.apply(
                .recordConsoleError(HTMLWorkspaceConsoleError(
                    message: "error-\(index)",
                    source: "main.js",
                    line: UInt32(index),
                    column: 0,
                    timestamp: Self.createdAt + Int64(index)
                )),
                to: package
            )
        }
        for index in 0..<24 {
            package = try HTMLWorkspacePatchApplier.apply(.captureSnapshot(name: "snap-\(index).html"), to: package)
        }

        #expect(package.consoleErrors.count == HTMLWorkspacePackageLimits.maxConsoleErrors)
        #expect(package.consoleErrors.first?.message == "error-32")
        #expect(package.snapshots.count == HTMLWorkspacePackageLimits.maxSnapshots)
        #expect(package.snapshots["snap-0.html"] == nil)
        #expect(package.snapshots["snap-23.html"] != nil)
    }

    @Test("active reversible snapshot survives manual snapshot churn")
    func activeReversibleSnapshotSurvivesManualSnapshotChurn() throws {
        let replacement = HTMLWorkspaceDocumentReplacement(
            title: "Generated",
            html: "<main><h1>Generated</h1></main>",
            css: "main { display: grid; }",
            js: "document.body.dataset.generated = 'true';",
            dataJSON: #"{"generated":true}"#,
            provenanceOperation: .regenerate
        )
        var package = try HTMLWorkspacePatchApplier.apply(
            .replaceDocument(replacement),
            to: Self.samplePackage()
        )
        let reversibleName = try #require(package.manifest.generationProvenance?.reversibleSnapshotName)
        let sourceName = HTMLWorkspaceSourceSnapshot.sourceName(forRenderedSnapshotName: reversibleName)

        for index in 0..<24 {
            package = try HTMLWorkspacePatchApplier.apply(.captureSnapshot(name: "manual-\(index).html"), to: package)
        }

        #expect(package.snapshots.count == HTMLWorkspacePackageLimits.maxSnapshots)
        #expect(package.snapshots[reversibleName] != nil)
        #expect(package.snapshots[sourceName] != nil)
        #expect(package.manifest.generationProvenance?.reversibleSnapshotName == reversibleName)
        let restored = try HTMLWorkspacePatchApplier.apply(.restoreSnapshot(name: reversibleName), to: package)
        #expect(restored.indexHTML.contains("Interactive Doc"))
        #expect(restored.manifest.generationProvenance?.operation == .restoreSnapshot)
    }

    @Test("console error strings are bounded before package persistence")
    func consoleErrorStringsAreBoundedBeforePackagePersistence() throws {
        let hugeMessage = String(repeating: "m", count: HTMLWorkspacePackageLimits.maxConsoleErrorMessageCharacters + 1_000)
        let hugeSource = String(repeating: "s", count: HTMLWorkspacePackageLimits.maxConsoleErrorSourceCharacters + 1_000)

        let package = try HTMLWorkspacePatchApplier.apply(
            .recordConsoleError(HTMLWorkspaceConsoleError(
                message: hugeMessage,
                source: hugeSource,
                line: 9,
                column: 4,
                timestamp: Self.createdAt
            )),
            to: Self.samplePackage()
        )
        let error = try #require(package.consoleErrors.last)

        #expect(error.message.count == HTMLWorkspacePackageLimits.maxConsoleErrorMessageCharacters)
        #expect(error.message.hasSuffix("... [truncated]"))
        #expect(error.source?.count == HTMLWorkspacePackageLimits.maxConsoleErrorSourceCharacters)
        #expect(error.source?.hasSuffix("... [truncated]") == true)
        #expect(error.line == 9)
        #expect(error.column == 4)
    }

    @Test("legacy console errors decode with error severity")
    func legacyConsoleErrorsDecodeWithDefaultSeverity() throws {
        let data = Data("""
        [
          {
            "message": "ReferenceError: nope",
            "source": "main.js",
            "line": 12,
            "column": 4,
            "timestamp": 123
          }
        ]
        """.utf8)

        let errors = try JSONDecoder().decode([HTMLWorkspaceConsoleError].self, from: data)

        #expect(errors.first?.severity == .error)
    }

    @Test("console errors can be cleared by the local workspace UI operation")
    func consoleErrorsCanBeClearedByLocalWorkspaceUIOperation() throws {
        var package = try HTMLWorkspacePatchApplier.apply(
            .recordConsoleError(HTMLWorkspaceConsoleError(
                message: "ReferenceError: nope",
                source: "main.js",
                line: 12,
                column: 4,
                timestamp: Self.createdAt
            )),
            to: Self.samplePackage()
        )
        #expect(package.consoleErrors.count == 1)

        package = try HTMLWorkspacePatchApplier.apply(.clearConsole, to: package)

        #expect(package.consoleErrors.isEmpty)
    }

    @Test("chart helper inserts a visible local chart block")
    func chartHelperInsertsVisibleLocalChart() throws {
        let chart = HTMLWorkspaceChartSpec(
            id: "evidence-chart",
            title: "Evidence Mix",
            values: [
                HTMLWorkspaceChartDatum(label: "Primary", value: 8),
                HTMLWorkspaceChartDatum(label: "Bench", value: 5),
            ]
        )

        let updated = try HTMLWorkspacePatchApplier.apply(.insertChart(chart), to: Self.samplePackage())
        #expect(updated.indexHTML.contains("data-html-workspace-chart=\"evidence-chart\""))
        #expect(updated.indexHTML.contains("Evidence Mix"))
        #expect(updated.styleCSS.contains(".html-workspace-chart"))
        #expect(updated.styleCSS.contains("border: 0"))
        #expect(updated.styleCSS.contains("box-shadow: 0 10px 28px"))
        #expect(!updated.styleCSS.contains("border: 1px solid color-mix"))
        #expect(updated.scriptJS.contains("data-html-workspace-chart"))
    }

    @Test("hostile source still renders inside the offline CSP envelope")
    func hostileSourceKeepsOfflineEnvelope() {
        let hostile = HTMLWorkspacePackage(
            manifest: Self.sampleManifest(),
            indexHTML: "<a href=\"https://example.com\">escape</a><img src=\"https://example.com/pixel.png\">",
            styleCSS: "body { background: Canvas; }",
            scriptJS: "fetch('https://example.com'); window.webkit.messageHandlers.epdoc.postMessage({});"
        )

        let srcdoc = HTMLWorkspacePreviewDocument.render(package: hostile)
        #expect(srcdoc.contains("default-src 'none'"))
        #expect(srcdoc.contains("connect-src \(HTMLWorkspaceLocalResourceScheme.contentSecurityPolicySource)"))
        #expect(!srcdoc.contains("connect-src https:"))
        #expect(srcdoc.contains("frame-src 'none'"))
        #expect(!srcdoc.contains(HTMLWorkspaceSafeAPI.messageHandlerName))
    }

    @Test("HTML workspace patch command parser accepts structured workspace edits")
    func htmlWorkspacePatchCommandParserAcceptsStructuredEdits() throws {
        let response = """
        I will add the visualization.

        ```epistemos-html-workspace-patch
        {"workspace_id":"html-workspace-test","operations":[{"type":"setDataFeed","data_feed":{"source":"vault_search","query":"substrate provenance","limit":7}},{"type":"replaceDataJSON","json":"{\\"series\\":[1,2,3]}"},{"type":"insertBlock","html":"<section class=\\"viz\\"><h2>Signal</h2></section>","location":"append"},{"type":"updateStyleRule","selector":".viz","declarations":{"display":"grid","gap":"12px"}},{"type":"setRoute","name":"details.html","html":"<main><h1>Details</h1></main>"},{"type":"removeRoute","name":"about.html"},{"type":"removeAsset","name":"texture.png"}]}
        ```
        """

        let result = try HTMLWorkspacePatchCommandParser.parse(response)
        #expect(result.batches.count == 1)
        #expect(result.cleanedText == "I will add the visualization.")
        #expect(result.batches[0].operations.count == 7)

        var package = Self.samplePackage()
        for command in result.batches[0].operations {
            package = try HTMLWorkspacePatchApplier.apply(command.patchOperation(), to: package)
        }
        #expect(package.manifest.dataFeed?.source == .vaultSearch)
        #expect(package.manifest.dataFeed?.normalizedQuery == "substrate provenance")
        #expect(package.manifest.dataFeed?.limit == 7)
        #expect(package.indexHTML.contains("class=\"viz\""))
        #expect(package.dataJSON.contains("series"))
        #expect(package.styleCSS.contains(".viz {"))
        #expect(package.styleCSS.contains("display: grid;"))
        #expect(package.routes["details.html"]?.contains("Details") == true)
        #expect(package.routes["about.html"] == nil)
        #expect(package.assets["texture.png"] == nil)

        let regenerate = """
        ```epistemos-html-workspace-patch
        {"workspace_id":"html-workspace-test","operations":[{"type":"regenerate","title":"Generated Explainer","html":"<main><h1>Generated</h1></main>","css":"main { display: grid; }","js":"document.body.dataset.generated = 'true';","json":"{\\"generated\\":true}"}]}
        ```
        """
        let regenerateResult = try HTMLWorkspacePatchCommandParser.parse(regenerate)
        var regenerated = Self.samplePackage()
        for command in regenerateResult.batches[0].operations {
            regenerated = try HTMLWorkspacePatchApplier.apply(command.patchOperation(), to: regenerated)
        }
        #expect(regenerated.manifest.title == "Generated Explainer")
        #expect(regenerated.indexHTML.contains("<h1>Generated</h1>"))
        #expect(regenerated.styleCSS.contains("display: grid"))
        #expect(regenerated.scriptJS.contains("generated"))
        #expect(regenerated.dataJSON.contains("generated"))
        #expect(regenerated.manifest.generationProvenance?.operation == .regenerate)
    }

    @Test("HTML workspace patch command parser accepts tolerant fence labels")
    func htmlWorkspacePatchCommandParserAcceptsTolerantFenceLabels() throws {
        let response = """
        Done.

        ```EPISTEMOS-HTML-WORKSPACE-PATCH json
        {"operations":[{"type":"replaceDataJSON","json":"{\\"ok\\":true}"}]}
        ```
        """

        #expect(HTMLWorkspacePatchCommandParser.containsPatchBlock(in: response))

        let result = try HTMLWorkspacePatchCommandParser.parse(response)
        #expect(result.cleanedText == "Done.")
        #expect(result.batches.count == 1)
        #expect(result.batches.first?.operations.count == 1)

        let package = try result.batches[0].applyingAtomically(to: Self.samplePackage())
        #expect(package.dataJSON == #"{"ok":true}"#)
    }

    @Test("HTML workspace patch command batches stage atomically")
    func htmlWorkspacePatchCommandBatchStagesAtomically() throws {
        let original = Self.samplePackage()
        let failing = HTMLWorkspacePatchCommandBatch(operations: [
            .replaceHTML("<main><h1>Partial</h1></main>"),
            .updateStyleRule(HTMLWorkspaceStyleRulePatch(selector: "", declarations: ["color": "red"])),
        ])

        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try failing.applyingAtomically(to: original)
        }
        #expect(original.indexHTML.contains("Interactive Doc"))
        #expect(!original.indexHTML.contains("Partial"))

        let successful = HTMLWorkspacePatchCommandBatch(operations: [
            .replaceHTML("<main><h1>Committed</h1></main>"),
            .replaceDataJSON(#"{"committed":true}"#),
        ])
        let updated = try successful.applyingAtomically(to: original)
        #expect(updated.indexHTML.contains("Committed"))
        #expect(updated.dataJSON.contains("committed"))
    }

    @Test("Document surface metadata captures HTML Workspace panes")
    func documentSurfaceMetadataCapturesHTMLWorkspacePanes() {
        let surface = DocumentSurface(
            id: "workspace-1",
            kind: .htmlWorkspace,
            title: "Workspace",
            fileURL: URL(fileURLWithPath: "/tmp/workspace.htmlworkspace"),
            currentSelection: DocumentSourceRange(startLine: 2, startColumn: 1, endLine: 4, endColumn: 12),
            capabilities: [.read, .write, .patch, .exportHTML, .exportPDF, .importContent, .preview],
            contentHash: "abc123"
        )

        #expect(surface.kind == .htmlWorkspace)
        #expect(surface.capabilities.contains(.patch))
        #expect(surface.currentSelection?.startLine == 2)
        #expect(surface.contentHash == "abc123")

        let fullRange = DocumentSourceRange.fullDocumentRange(for: "one\ntwo\n")
        #expect(fullRange.startLine == 1)
        #expect(fullRange.startColumn == 1)
        #expect(fullRange.endLine == 3)
        #expect(fullRange.endColumn == 1)
    }

    @Test("HTML workspace patch command parser rejects unsafe DOM and app bridge attempts")
    func htmlWorkspacePatchCommandParserRejectsUnsafeOperations() {
        let inlineHandler = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"insertBlock","html":"<button onclick=\\"alert(1)\\">Run</button>"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(inlineHandler)
        }

        let spacedInlineHandler = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"insertBlock","html":"<button onclick = \\"alert(1)\\">Run</button>"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(spacedInlineHandler)
        }

        let appBridgeProbe = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceJS","js":"window.webkit.messageHandlers.epdoc.postMessage({})"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(appBridgeProbe)
        }

        let spacedAppBridgeProbe = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceJS","js":"window . webkit ?. messageHandlers.epdoc.postMessage({})"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(spacedAppBridgeProbe)
        }

        let optionalChainingAppBridgeProbe = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceJS","js":"window?.webkit?.messageHandlers.epdoc.postMessage({})"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(optionalChainingAppBridgeProbe)
        }

        let bracketAppBridgeProbe = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceJS","js":"window['webkit'][\\"messageHandlers\\"].epdoc.postMessage({})"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(bracketAppBridgeProbe)
        }

        let concatenatedBracketAppBridgeProbe = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceJS","js":"window['web' + 'kit']['message' + 'Handlers'].epdoc.postMessage({})"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(concatenatedBracketAppBridgeProbe)
        }

        let templateLiteralAppBridgeProbe = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceJS","js":"globalThis[`webkit`]?.[`messageHandlers`].epdoc.postMessage({})"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(templateLiteralAppBridgeProbe)
        }

        let globalAppBridgeProbe = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceJS","js":"webkit.messageHandlers.epdoc.postMessage({})"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(globalAppBridgeProbe)
        }

        let malformedData = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceDataJSON","json":"{"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(malformedData)
        }

        let unsafeWholeDocumentHTML = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceDocument","html":"<main><script>alert(1)</script></main>","css":"","js":"","json":"{}"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(unsafeWholeDocumentHTML)
        }

        let unsafeWholeDocumentJS = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceDocument","html":"<main></main>","css":"","js":"localStorage.setItem('x','y');","json":"{}"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(unsafeWholeDocumentJS)
        }

        let unsafeRouteHTML = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"setRoute","name":"about.html","html":"<main><button onclick=\\"alert(1)\\">Run</button></main>"}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(unsafeRouteHTML)
        }
    }

    @Test("HTML workspace patch command parser accepts restoreSnapshot")
    func htmlWorkspacePatchCommandParserAcceptsRestoreSnapshot() throws {
        let response = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"restoreSnapshot","name":"pre-replace-source.html"}]}
        ```
        """

        let parsed = try HTMLWorkspacePatchCommandParser.parse(response)
        let command = try #require(parsed.batches.first?.operations.first)

        #expect(parsed.batches.first?.operations == [.restoreSnapshot(name: "pre-replace-source.html")])
        #expect(try command.patchOperation() == .restoreSnapshot(name: "pre-replace-source.html"))
    }

    @Test("HTML workspace patch command parser does not expose local clearConsole")
    func htmlWorkspacePatchCommandParserRejectsLocalClearConsoleOperation() {
        let response = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"clearConsole"}]}
        ```
        """

        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(response)
        }
    }

    @Test("HTML workspace patch command parser bounds operation counts and assets")
    func htmlWorkspacePatchCommandParserBoundsPayloads() {
        let operations = Array(repeating: #"{"type":"captureSnapshot","name":"snap.html"}"#, count: HTMLWorkspacePatchCommandLimits.maxOperations + 1)
            .joined(separator: ",")
        let tooMany = """
        ```epistemos-html-workspace-patch
        {"operations":[\(operations)]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(tooMany)
        }

        let traversal = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"addAsset","name":"../secret","base64":"AA=="}]}
        ```
        """
        #expect(throws: HTMLWorkspacePackageError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(traversal)
        }

        let oversizedReplacementAsset = Data(
            repeating: 0,
            count: HTMLWorkspacePatchCommandLimits.maxAssetBytes + 1
        ).base64EncodedString()
        let oversizedReplacement = """
        ```epistemos-html-workspace-patch
        {"operations":[{"type":"replaceDocument","html":"<main></main>","css":"","js":"","json":"{}","assets":{"big.bin":"\(oversizedReplacementAsset)"}}]}
        ```
        """
        #expect(throws: HTMLWorkspacePatchRouterError.self) {
            _ = try HTMLWorkspacePatchCommandParser.parse(oversizedReplacement)
        }
    }

    @Test("HTML workspace patch errors keep useful localized descriptions")
    func htmlWorkspacePatchErrorsKeepLocalizedDescriptions() {
        let routerError = HTMLWorkspacePatchRouterError.unsafeSource(reason: "inline event handler")
        #expect(routerError.localizedDescription.contains("HTML Workspace patch contains unsafe source"))
        #expect(routerError.localizedDescription.contains("inline event handler"))

        let packageError = HTMLWorkspacePackageError.invalidPackagePath(name: "../secret")
        #expect(packageError.localizedDescription.contains("invalid package path"))
        #expect(packageError.localizedDescription.contains("../secret"))
    }
}
