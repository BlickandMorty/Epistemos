import Darwin
import Foundation
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Lane R removal tests must compile in the Free V1 App Store target.")
#endif

@Suite("Free V1 removal boundaries", .serialized)
@MainActor
struct FreeV1RemovalBoundaryTests {
    @Test("Contextual Shadows and every graph-query entry point exclude stored paid records")
    func contextualShadowsAndGraphQueriesFailClosedForPaidRecords() throws {
        let noteHit = ContextualShadowsState.RecallHit(
            id: "note-recall",
            title: "Allowed note",
            snippet: "A deterministic note recall result.",
            kind: .note,
            similarity: 0.91
        )
        let chatHit = ContextualShadowsState.RecallHit(
            id: "paid-chat-recall",
            title: "Archived paid chat",
            snippet: "This chat must not be presented in Free V1.",
            kind: .chat,
            similarity: 0.99
        )

        #expect(
            ContextualShadowsState.freeV1VisibleRecallHits([noteHit, chatHit]).map(\.id)
                == ["note-recall"]
        )
        for unavailableCollection in ["all chats", "show chats", "list chats"] {
            #expect(QueryParser.parseToAST(unavailableCollection) == nil)
        }
        #expect(StructuredQueryParser.parse("?type=chat") == nil)

        let store = GraphStore()
        store.addNode(makeNode(id: "note", type: .note, label: "Allowed note"))
        store.addNode(makeNode(id: "chat", type: .chat, label: "Archived paid chat"))
        store.addEdge(
            GraphEdgeRecord(
                id: "note-chat",
                sourceNodeId: "note",
                targetNodeId: "chat",
                type: .reference,
                weight: 1,
                createdAt: Date(timeIntervalSince1970: 1)
            )
        )

        let runtime = QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: try makeSearchIndex()
        )

        let allNodes = runtime.execute(
            QueryPlan(
                steps: [.graphStoreFilter(NodeFilter(limit: 10))],
                combiner: .single
            )
        )
        #expect(allNodes.nodes.map(\.id) == ["note"])
        #expect(allNodes.nodes.allSatisfy { ProductCapabilityPolicy.allowsGraphProjection(of: $0.type) })

        let directHiddenTypePlan = QueryCompiler.compile(.typeFilter(types: [.chat]))
        #expect(runtime.execute(directHiddenTypePlan).nodes.isEmpty)

        let neighborResult = runtime.execute(
            QueryPlan(
                steps: [.graphStoreNeighbors(of: .id("note"), edgeTypes: nil, depth: 1)],
                combiner: .single
            )
        )
        #expect(neighborResult.nodes.isEmpty)

        let edgeResult = runtime.execute(
            QueryPlan(
                steps: [.graphStoreEdgeFilter(EdgeFilter(limit: 10))],
                combiner: .single
            )
        )
        #expect(edgeResult.edges.isEmpty)
    }

    @Test("typed paid graph provenance cannot affect Free projection, ranking, or traversal")
    func graphProjectionRejectsPaidProvenanceBeforeProjection() throws {
        var paidMetadata = GraphNodeMetadata()
        paidMetadata.originChatId = "archived-paid-chat"

        let note = makeNode(
            id: "note",
            type: .note,
            label: "Allowed note",
            createdAt: 1
        )
        let userIdea = makeNode(
            id: "user-idea",
            type: .idea,
            label: "User idea about chat model provider",
            createdAt: 2
        )
        let left = makeNode(
            id: "left",
            type: .note,
            label: "Allowed left endpoint",
            createdAt: 3
        )
        let right = makeNode(
            id: "right",
            type: .note,
            label: "Allowed right endpoint",
            createdAt: 4
        )
        let paidIdea = makeNode(
            id: "paid-idea",
            type: .idea,
            label: "Archived paid analysis",
            metadata: paidMetadata,
            createdAt: 5
        )

        let store = GraphStore()
        [note, userIdea, left, right, paidIdea].forEach(store.addNode)
        [
            makeEdge(id: "note-user", source: "note", target: "user-idea", createdAt: 1),
            makeEdge(id: "note-chat", source: "note", target: "paid-idea", createdAt: 6),
            makeEdge(id: "left-paid", source: "left", target: "paid-idea", createdAt: 7),
            makeEdge(id: "paid-right", source: "paid-idea", target: "right", createdAt: 8),
        ].forEach(store.addEdge)

        #expect(ProductCapabilityPolicy.allowsGraphProjection(of: .idea))
        #expect(ProductCapabilityPolicy.allowsGraphProjection(of: userIdea))
        #expect(!ProductCapabilityPolicy.allowsGraphProjection(of: paidIdea))

        let filter = FilterEngine()
        #expect(filter.isNodeVisible(userIdea))
        #expect(!filter.isNodeVisible(paidIdea))
        let snapshot = filter.snapshot()
        #expect(snapshot.isNodeVisible(userIdea))
        #expect(!snapshot.isNodeVisible(paidIdea))

        let runtime = QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: try makeSearchIndex()
        )

        let singleIdea = runtime.execute(
            QueryPlan(
                steps: [.graphStoreFilter(NodeFilter(types: [.idea], limit: 1))],
                combiner: .single
            )
        )
        #expect(singleIdea.nodes.map(\.id) == ["user-idea"])

        let visibleNodes = runtime.execute(
            QueryPlan(
                steps: [.graphStoreFilter(NodeFilter(limit: 10))],
                combiner: .single
            )
        )
        #expect(Set(visibleNodes.nodes.map(\.id)) == ["note", "user-idea", "left", "right"])
        #expect(visibleNodes.nodes.first(where: { $0.id == "note" })?.connectionCount == 1)
        #expect(visibleNodes.nodes.first(where: { $0.id == "left" })?.connectionCount == 0)
        #expect(visibleNodes.nodes.first(where: { $0.id == "right" })?.connectionCount == 0)

        let ordinaryTextResult = runtime.execute(
            QueryPlan(
                steps: [.graphStoreFilter(NodeFilter(labelContains: "chat model provider", limit: 10))],
                combiner: .single
            )
        )
        #expect(ordinaryTextResult.nodes.map(\.id) == ["user-idea"])

        let hiddenIDNeighbors = runtime.execute(
            QueryPlan(
                steps: [.graphStoreNeighbors(of: .id("paid-idea"), edgeTypes: nil, depth: 1)],
                combiner: .single
            )
        )
        #expect(hiddenIDNeighbors.nodes.isEmpty)

        let hiddenLabelNeighbors = runtime.execute(
            QueryPlan(
                steps: [.graphStoreNeighbors(of: .label("Archived paid analysis"), edgeTypes: nil, depth: 1)],
                combiner: .single
            )
        )
        #expect(hiddenLabelNeighbors.nodes.isEmpty)

        let hiddenBridgePath = runtime.execute(
            QueryPlan(
                steps: [.graphStorePath(from: .id("left"), to: .id("right"), maxHops: 2)],
                combiner: .single
            )
        )
        #expect(hiddenBridgePath.nodes.isEmpty)

        let allowedPath = runtime.execute(
            QueryPlan(
                steps: [.graphStorePath(from: .id("note"), to: .id("user-idea"), maxHops: 1)],
                combiner: .single
            )
        )
        #expect(allowedPath.nodes.map(\.id) == ["note", "user-idea"])

        let edgeResult = runtime.execute(
            QueryPlan(
                steps: [.graphStoreEdgeFilter(EdgeFilter(limit: 1))],
                combiner: .single
            )
        )
        #expect(edgeResult.edges.map(\.id) == ["note-user"])
    }

    @Test("label resolution excludes paid provenance before ranking, limits, and cache reuse")
    func labelResolutionUsesOnlyAllowedCandidateUniverse() throws {
        var paidMetadata = GraphNodeMetadata()
        paidMetadata.originChatId = "archived-paid-chat"

        let store = GraphStore()
        for index in 0..<51 {
            store.addNode(
                makeNode(
                    id: "paid-ranked-\(index)",
                    type: .idea,
                    label: "needle",
                    metadata: paidMetadata,
                    createdAt: TimeInterval(100 + index)
                )
            )
        }

        let visibleMatch = makeNode(
            id: "visible-ranked-after-paid",
            type: .note,
            label: "needle visible",
            createdAt: 1
        )
        let visibleNeighbor = makeNode(
            id: "visible-neighbor",
            type: .note,
            label: "Safe adjacent note",
            createdAt: 2
        )
        store.addNode(visibleMatch)
        store.addNode(visibleNeighbor)
        store.addEdge(
            makeEdge(
                id: "visible-only-edge",
                source: visibleMatch.id,
                target: visibleNeighbor.id,
                createdAt: 3
            )
        )

        let runtime = QueryRuntime(
            graphStore: store,
            graphState: GraphState(),
            searchIndex: try makeSearchIndex()
        )
        let plan = QueryPlan(
            steps: [.graphStoreNeighbors(of: .label("needle"), edgeTypes: nil, depth: 1)],
            combiner: .single
        )

        let first = runtime.execute(plan)
        let second = runtime.execute(plan)
        #expect(first.nodes.map(\.id) == ["visible-neighbor"])
        #expect(second.nodes.map(\.id) == ["visible-neighbor"])
        #expect(second.nodes.allSatisfy { $0.label != "needle" })
    }

    @Test("First-run legacy metadata is preservation-only and failed scaffolds stay retryable")
    func firstRunMetadataCompatibilityIsInertAndPartialScaffoldsArePreserved() throws {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let vault = temporaryDirectory
            .appendingPathComponent("free-v1-first-run-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: vault) }

        let metadataDirectory = vault.appendingPathComponent(".epistemos", isDirectory: true)
        try fileManager.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
        let metadataURL = vault.appendingPathComponent(FirstRunBootstrap.metadataRelativePath)
        let preservedBytes = Data(
            """
            {"schema_version":1,"created_at":"2026-07-15T00:00:00Z","embedding_model_pin":"historical-embedding-pin","router_model_pin":"historical-router-pin"}
            """.utf8
        )
        try preservedBytes.write(to: metadataURL)

        let receipt = try FirstRunBootstrap.bootstrap(at: vault)
        #expect(!receipt.wasFresh)
        #expect(receipt.metadata.schemaVersion == FirstRunBootstrap.schemaVersion)
        #expect(receipt.metadata.createdAt == Date(timeIntervalSince1970: 1_784_073_600))
        #expect(try Data(contentsOf: metadataURL) == preservedBytes)
        #expect(
            !Mirror(reflecting: receipt.metadata).children.contains {
                $0.label == "embeddingModelPin" || $0.label == "routerModelPin"
            }
        )

        let oversizedVault = temporaryDirectory
            .appendingPathComponent("free-v1-first-run-oversized-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: oversizedVault) }
        let oversizedMetadataDirectory = oversizedVault.appendingPathComponent(".epistemos", isDirectory: true)
        try fileManager.createDirectory(at: oversizedMetadataDirectory, withIntermediateDirectories: true)
        let oversizedMetadataURL = oversizedVault.appendingPathComponent(FirstRunBootstrap.metadataRelativePath)
        let oversizedBytes = Data(
            """
            {"schema_version":1,"created_at":"2026-07-15T00:00:00Z","embedding_model_pin":"\(String(repeating: "x", count: 513))"}
            """.utf8
        )
        try oversizedBytes.write(to: oversizedMetadataURL)

        #expect(throws: Error.self) {
            try FirstRunBootstrap.bootstrap(at: oversizedVault)
        }
        #expect(try Data(contentsOf: oversizedMetadataURL) == oversizedBytes)
        #expect(!fileManager.fileExists(atPath: oversizedVault.appendingPathComponent("notes").path))

        let partialVault = temporaryDirectory
            .appendingPathComponent("free-v1-first-run-partial-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: partialVault) }
        try fileManager.createDirectory(
            at: partialVault.appendingPathComponent("notes", isDirectory: true),
            withIntermediateDirectories: true
        )
        let partialReceipt = try FirstRunBootstrap.bootstrap(at: partialVault)
        #expect(partialReceipt.wasFresh)
        #expect(fileManager.fileExists(atPath: partialVault.appendingPathComponent("notes").path))

        let bootstrapSource = try sourceText("Epistemos/Vault/FirstRunBootstrap.swift")
        for forbiddenPublicPinSurface in [
            "public var embeddingModelPin",
            "public var routerModelPin",
            "public let embeddingModelPin",
            "public let routerModelPin",
            "rollbackEmptyDirectories"
        ] {
            #expect(!bootstrapSource.contains(forbiddenPublicPinSurface))
        }
    }

    @Test("First-run metadata admission rejects symlink and special-leaf escapes before publication")
    func firstRunMetadataAdmissionRejectsUnsafeLeavesAndRetainsRetryableScaffolds() throws {
        let fileManager = FileManager.default
        let temporaryDirectory = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
        let fixtureRoot = temporaryDirectory
            .appendingPathComponent("free-v1-first-run-admission-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: fixtureRoot) }

        let redirectedOutside = fixtureRoot.appendingPathComponent("redirected-outside", isDirectory: true)
        try fileManager.createDirectory(at: redirectedOutside, withIntermediateDirectories: false)
        let redirectedCanary = redirectedOutside.appendingPathComponent("canary.txt")
        let redirectedCanaryBytes = Data("redirected-canary".utf8)
        try redirectedCanaryBytes.write(to: redirectedCanary)
        let redirect = fixtureRoot.appendingPathComponent("redirect", isDirectory: true)
        try fileManager.createSymbolicLink(at: redirect, withDestinationURL: redirectedOutside)

        let redirectedVault = redirect.appendingPathComponent("Epistemos", isDirectory: true)
        #expect(capturedBootstrapError {
            try FirstRunBootstrap.bootstrap(at: redirectedVault)
        } == .unsafeFilesystemObject)
        #expect(!fileManager.fileExists(atPath: redirectedOutside.appendingPathComponent("Epistemos").path))
        #expect(try Data(contentsOf: redirectedCanary) == redirectedCanaryBytes)

        let metadataDirectoryVault = fixtureRoot.appendingPathComponent("metadata-directory-vault", isDirectory: true)
        let metadataDirectoryOutside = fixtureRoot.appendingPathComponent("metadata-directory-outside", isDirectory: true)
        try fileManager.createDirectory(at: metadataDirectoryVault, withIntermediateDirectories: false)
        try fileManager.createDirectory(at: metadataDirectoryOutside, withIntermediateDirectories: false)
        let metadataDirectoryCanary = metadataDirectoryOutside.appendingPathComponent("canary.txt")
        let metadataDirectoryCanaryBytes = Data("metadata-directory-canary".utf8)
        try metadataDirectoryCanaryBytes.write(to: metadataDirectoryCanary)
        try fileManager.createSymbolicLink(
            at: metadataDirectoryVault.appendingPathComponent(".epistemos", isDirectory: true),
            withDestinationURL: metadataDirectoryOutside
        )

        #expect(capturedBootstrapError {
            try FirstRunBootstrap.bootstrap(at: metadataDirectoryVault)
        } == .unsafeFilesystemObject)
        #expect(!fileManager.fileExists(atPath: metadataDirectoryVault.appendingPathComponent("notes").path))
        #expect(!fileManager.fileExists(atPath: metadataDirectoryOutside.appendingPathComponent("vault.json").path))
        #expect(try Data(contentsOf: metadataDirectoryCanary) == metadataDirectoryCanaryBytes)

        let metadataLeafVault = fixtureRoot.appendingPathComponent("metadata-leaf-vault", isDirectory: true)
        let metadataLeafOutside = fixtureRoot.appendingPathComponent("metadata-leaf-outside", isDirectory: true)
        try fileManager.createDirectory(
            at: metadataLeafVault.appendingPathComponent(".epistemos", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(at: metadataLeafOutside, withIntermediateDirectories: false)
        let metadataLeafCanary = metadataLeafOutside.appendingPathComponent("canary.txt")
        let metadataLeafCanaryBytes = Data("metadata-leaf-canary".utf8)
        try metadataLeafCanaryBytes.write(to: metadataLeafCanary)
        try fileManager.createSymbolicLink(
            at: metadataLeafVault.appendingPathComponent(FirstRunBootstrap.metadataRelativePath),
            withDestinationURL: metadataLeafCanary
        )

        #expect(capturedBootstrapError {
            try FirstRunBootstrap.bootstrap(at: metadataLeafVault)
        } == .unsafeFilesystemObject)
        #expect(!fileManager.fileExists(atPath: metadataLeafVault.appendingPathComponent("notes").path))
        #expect(try Data(contentsOf: metadataLeafCanary) == metadataLeafCanaryBytes)

        let specialLeafCanary = fixtureRoot.appendingPathComponent("special-leaf-canary.txt")
        let specialLeafCanaryBytes = Data("special-leaf-canary".utf8)
        try specialLeafCanaryBytes.write(to: specialLeafCanary)

        let fifoVault = fixtureRoot.appendingPathComponent("fifo-leaf-vault", isDirectory: true)
        let fifoDirectory = fifoVault.appendingPathComponent(".epistemos", isDirectory: true)
        try fileManager.createDirectory(at: fifoDirectory, withIntermediateDirectories: true)
        let fifoURL = fifoDirectory.appendingPathComponent("vault.json")
        guard fifoURL.path.withCString({ mkfifo($0, mode_t(0o600)) }) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        let fifoStart = ContinuousClock.now
        #expect(capturedBootstrapError {
            try FirstRunBootstrap.bootstrap(at: fifoVault)
        } == .unsafeFilesystemObject)
        #expect(fifoStart.duration(to: .now) < .seconds(2))
        #expect(!fileManager.fileExists(atPath: fifoVault.appendingPathComponent("notes").path))
        #expect(try Data(contentsOf: specialLeafCanary) == specialLeafCanaryBytes)

        let directoryLeafVault = fixtureRoot.appendingPathComponent("directory-leaf-vault", isDirectory: true)
        let directoryLeaf = directoryLeafVault
            .appendingPathComponent(".epistemos/vault.json", isDirectory: true)
        try fileManager.createDirectory(at: directoryLeaf, withIntermediateDirectories: true)

        #expect(capturedBootstrapError {
            try FirstRunBootstrap.bootstrap(at: directoryLeafVault)
        } == .unsafeFilesystemObject)
        #expect(!fileManager.fileExists(atPath: directoryLeafVault.appendingPathComponent("notes").path))
        #expect(try Data(contentsOf: specialLeafCanary) == specialLeafCanaryBytes)

        let replacementVault = fixtureRoot.appendingPathComponent("post-admission-vault", isDirectory: true)
        let replacementOutside = fixtureRoot.appendingPathComponent("post-admission-outside", isDirectory: true)
        try fileManager.createDirectory(at: replacementOutside, withIntermediateDirectories: false)
        let replacementCanary = replacementOutside.appendingPathComponent("canary.txt")
        let replacementCanaryBytes = Data("post-admission-canary".utf8)
        try replacementCanaryBytes.write(to: replacementCanary)
        let replacementMetadataDirectory = replacementVault.appendingPathComponent(".epistemos", isDirectory: true)
        nonisolated final class ReplacementHookProbe: @unchecked Sendable {
            private let lock = NSLock()
            private var didReachPublication = false

            func markReached() {
                lock.withLock { didReachPublication = true }
            }

            func wasReached() -> Bool {
                lock.withLock { didReachPublication }
            }
        }
        let replacementProbe = ReplacementHookProbe()

        #expect(capturedBootstrapError {
            try FirstRunBootstrap.withFreshMetadataPublicationHook({
                replacementProbe.markReached()
                try FileManager.default.removeItem(at: replacementMetadataDirectory)
                try FileManager.default.createSymbolicLink(
                    at: replacementMetadataDirectory,
                    withDestinationURL: replacementOutside
                )
            }, operation: {
                _ = try FirstRunBootstrap.bootstrap(at: replacementVault)
            })
        } == .unsafeFilesystemObject)
        #expect(replacementProbe.wasReached())
        #expect(!fileManager.fileExists(atPath: replacementOutside.appendingPathComponent("vault.json").path))
        #expect(try Data(contentsOf: replacementCanary) == replacementCanaryBytes)

    }

    @Test("First-run receipt failure stays typed, retains its scaffold, and retries")
    func firstRunMetadataPublicationFailureIsTypedRetryableAndCanRetry() throws {
        let fileManager = FileManager.default
        let temporaryDirectory = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
        let fixtureRoot = temporaryDirectory
            .appendingPathComponent("free-v1-first-run-publication-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: false)
        defer { try? fileManager.removeItem(at: fixtureRoot) }

        let failureVault = fixtureRoot.appendingPathComponent("publication-failure-vault", isDirectory: true)
        let failureOutside = fixtureRoot.appendingPathComponent("publication-failure-outside", isDirectory: true)
        try fileManager.createDirectory(at: failureOutside, withIntermediateDirectories: false)
        let failureCanary = failureOutside.appendingPathComponent("canary.txt")
        let failureCanaryBytes = Data("publication-failure-canary".utf8)
        try failureCanaryBytes.write(to: failureCanary)

        let failure = capturedBootstrapError {
            try FirstRunBootstrap.withFreshMetadataPublicationFailure(operation: {
                _ = try FirstRunBootstrap.bootstrap(at: failureVault)
            })
        }
        #expect(failure == .metadataPublicationFailed)
        #expect(fileManager.fileExists(atPath: failureVault.path))
        for relativePath in ["_inbox", "daily", "notes", ".epistemos"] {
            #expect(fileManager.fileExists(atPath: failureVault.appendingPathComponent(relativePath).path))
        }
        #expect(!fileManager.fileExists(atPath: failureVault.appendingPathComponent(FirstRunBootstrap.metadataRelativePath).path))
        #expect(try Data(contentsOf: failureCanary) == failureCanaryBytes)
        var retry: FirstRunBootstrap.Receipt?
        let retryFailure = capturedBootstrapError {
            retry = try FirstRunBootstrap.bootstrap(at: failureVault)
        }
        #expect(retryFailure == nil)
        let retryMetadataURL = failureVault.appendingPathComponent(FirstRunBootstrap.metadataRelativePath)
        #expect(fileManager.fileExists(atPath: retryMetadataURL.path))
        #expect(retry?.wasFresh == true)
        if let retry {
            #expect(try FirstRunBootstrap.readMetadata(at: retry.metadataURL) == retry.metadata)
        }
        #expect(try Data(contentsOf: failureCanary) == failureCanaryBytes)
    }

    @Test("Free Shadow bootstrap is notes-only and its build closure is lexical-only")
    func freeShadowBootstrapAndBuildClosureFailClosed() async throws {
        let vault = FileManager.default.temporaryDirectory
            .appendingPathComponent("free-shadow-removal-\(UUID().uuidString)", isDirectory: true)
        let notesDirectory = vault.appendingPathComponent("notes", isDirectory: true)
        let chatsDirectory = vault.appendingPathComponent("chats", isDirectory: true)
        try FileManager.default.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: chatsDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vault) }

        try "Allowed lexical note".write(
            to: notesDirectory.appendingPathComponent("allowed.md"),
            atomically: true,
            encoding: .utf8
        )
        let chatURL = chatsDirectory.appendingPathComponent("large-archived-chat.json")
        let originalChatBytes = Data(
            "{\"title\":\"Archived\",\"messages\":[{\"role\":\"user\",\"content\":\"chat-only-needle \(String(repeating: "x", count: 300_000))\"}]}".utf8
        )
        try originalChatBytes.write(to: chatURL)

        let client = InMemoryShadowFFIClient()
        let indexer = ShadowIndexingService(client: client)
        let bootstrapper = ShadowVaultBootstrapper(vaultRoot: vault, indexer: indexer)
        await bootstrapper.bootstrap()
        await indexer.flushNow()

        #expect(try client.search(query: "allowed lexical", limit: 10).count == 1)
        #expect(try client.search(query: "chat-only-needle", limit: 10).isEmpty)
        #expect(try client.stats().chatCount == 0)
        #expect(try Data(contentsOf: chatURL) == originalChatBytes)

        let bootstrapperSource = try sourceText("Epistemos/Engine/ShadowVaultBootstrapper.swift")
        let bootstrapSource = try sourceText("Epistemos/App/AppBootstrap.swift")
        let shadowClientSource = try sourceText("Epistemos/Engine/RustShadowFFIClient.swift")
        let shadowCargo = try sourceText("epistemos-shadow/Cargo.toml")
        let shadowBuild = try sourceText("build-epistemos-shadow.sh")
        let shadowBackend = try sourceText("epistemos-shadow/src/backend/free_backend.rs")

        #expect(!bootstrapperSource.contains("crawl(domain: .chats)"))
        #expect(!bootstrapperSource.contains("ShadowVaultChatPayload"))
        #expect(!bootstrapperSource.contains("Data(contentsOf: url)"))
        #expect(!bootstrapSource.contains("client.warm()"))
        #expect(!shadowClientSource.contains("shadow_warm"))
        #expect(shadowCargo.contains("free-lexical"))
        #expect(shadowCargo.contains("semantic = ["))
        #expect(shadowCargo.contains("model2vec-rs = {"))
        #expect(shadowCargo.contains("optional = true"))
        #expect(shadowBuild.contains("--no-default-features --features free-lexical"))
        #expect(shadowBackend.contains("purge_non_note_derived_state"))
    }

    @Test("legacy notebook metadata remains byte-compatible but cannot restore a Free V1 surface")
    func legacyNotebookMetadataIsCompatibilityOnly() {
        let sheetID = "11111111-1111-1111-1111-111111111111"
        let chatID = "22222222-2222-2222-2222-222222222222"
        let markdown = """
        # Durable note body

        ```epistemos-notebook
        version: 1
        tab: id=\(sheetID) type=sheet version=1 title="Stored sheet" ref="dataset:budget"
        tab: id=\(chatID) type=chat version=1 title="Stored chat" ref="session:archive"
        ```

        {{epistemos-ref kind=sheet id=\(sheetID) title="Stored sheet"}}
        """

        let manifest = EpdocNotebookManifest.parse(in: markdown)
        #expect(manifest.tabs.map(\.id) == [sheetID, chatID])
        #expect(
            EpdocNotebookManifest.normalizedFreeV1SelectedTabID(chatID)
                == EpdocNotebookManifest.bodyTabID
        )
        #expect(TOCParser.parse(markdown).map(\.title) == ["Durable note body"])
        #expect(LensFidelityDisclosure.items(in: markdown, lens: .document).isEmpty)
    }

    @Test("Reckoner records remain quarantined without Free capability or event routing")
    func reckonerCapabilityAndDatasetRoutingFailClosed() throws {
        let companion = URL(fileURLWithPath: "/tmp/Archived.dataset.md")
        let csv = URL(fileURLWithPath: "/tmp/Archived.csv")
        let workbook = URL(fileURLWithPath: "/tmp/Archived.xlsx")

        #expect(!ProductCapabilityPolicy.isAvailable(.reckoner))
        #expect(!ProductCapabilityPolicy.freeCapabilities.contains(.reckoner))
        #expect(ProductCapabilityPolicy.paidCapabilities.contains(.reckoner))
        #expect(VaultIndexActor.vaultArtifactKind(for: companion) == .datasetCompanion)
        #expect(VaultIndexActor.vaultArtifactKind(for: csv) == .datasetTable)
        #expect(VaultIndexActor.vaultArtifactKind(for: workbook) == .datasetWorkbook)
        #expect(!VaultIndexActor.isImportableNoteFile(companion))
        #expect(!VaultIndexActor.isImportableNoteFile(csv))
        #expect(!VaultIndexActor.isImportableNoteFile(workbook))

        let indexer = try sourceText("Epistemos/Sync/VaultIndexActor.swift")
        let sync = try sourceText("Epistemos/Sync/VaultSyncService.swift")
        #expect(!indexer.contains("routeDatasetArtifacts"))
        #expect(!indexer.contains("RECKONER"))
        #expect(!indexer.contains("isRoutableVaultFile"))
        #expect(!sync.contains("VaultIndexActor.isRoutableVaultFile"))
        #expect(sync.contains("VaultIndexActor.isImportableNoteFile(fileURL)"))
    }

    @Test("the Free editor source graph excludes paid AI review and suggestion machinery")
    func freeEditorSourceGraphExcludesPaidReviewAndSuggestionMachinery() throws {
        let editorEntryPoint = try sourceText("js-editor/src/index.ts")
        let inboundBridge = try sourceText("js-editor/src/bridge/inbound.ts")
        let outboundBridge = try sourceText("js-editor/src/bridge/outbound.ts")
        let packageManifest = try sourceText("js-editor/package.json")
        let packageLock = try sourceText("js-editor/package-lock.json")

        #expect(!editorEntryPoint.contains("extensions/ai-diff"))
        #expect(!editorEntryPoint.contains("suggestions/SuggestionAdapter"))
        #expect(!editorEntryPoint.contains("EpdocSuggestionDocument"))
        #expect(editorEntryPoint.contains("MarkdownWritebackTracker"))
        #expect(editorEntryPoint.contains("LoadStateExtension"))

        #expect(!inboundBridge.contains("suggestChangesKey"))
        #expect(!inboundBridge.contains("suggestionAdapter"))
        #expect(!inboundBridge.contains("applySuggestion"))
        #expect(!inboundBridge.contains("acceptSuggestion"))
        #expect(!inboundBridge.contains("rejectSuggestion"))
        #expect(!inboundBridge.contains("epdocAIDiff"))
        #expect(inboundBridge.contains("beginLoad"))
        #expect(inboundBridge.contains("postDocumentSnapshot"))

        #expect(!outboundBridge.contains("SuggestionAppliedMessage"))
        #expect(!outboundBridge.contains("SuggestionResolvedMessage"))
        #expect(!packageManifest.contains("@handlewithcare/prosemirror-suggest-changes"))
        #expect(!packageManifest.contains("check:ai-diff"))
        #expect(!packageManifest.contains("check:suggestions"))
        #expect(!packageLock.contains("@handlewithcare/prosemirror-suggest-changes"))
    }

    @Test("the Free composition root does not inject or present canceled generation services")
    func freeCompositionRootExcludesCanceledGenerationServices() throws {
        let bootstrap = try sourceText("Epistemos/App/AppBootstrap.swift")
        let environment = try sourceText("Epistemos/App/AppEnvironment.swift")
        let app = try sourceText("Epistemos/App/EpistemosApp.swift")

        #expect(!bootstrap.contains("let llmService: LLMService"))
        #expect(!bootstrap.contains("let cloudLLMClient: CloudLLMClient"))
        #expect(!bootstrap.contains("let triageService: TriageService"))
        #expect(
            bootstrap.contains(
                "#if !EPISTEMOS_FREE_V1\n    let vaultChatMutator: VaultChatMutator"
            )
        )
        #expect(bootstrap.contains("#if !EPISTEMOS_FREE_V1"))

        #expect(!environment.contains(".environment(bootstrap.llmService)"))
        #expect(!environment.contains(".environment(bootstrap.triageService)"))
        #expect(!environment.contains(".environment(bootstrap.vaultChatMutator)"))
        #expect(!environment.contains(".environment(bootstrap.chatApprovalQueue)"))

        #expect(!app.contains("bootstrap.vaultChatMutator.stagedDiff"))
        #expect(!app.contains("bootstrap.chatApprovalQueue.pendingApproval"))
        #expect(!app.contains("DiffApprovalSheet("))
        #expect(!app.contains("ApprovalModalView("))
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

    private func capturedBootstrapError(
        _ operation: () throws -> Void
    ) -> FirstRunBootstrap.BootstrapError? {
        do {
            try operation()
            return nil
        } catch let error as FirstRunBootstrap.BootstrapError {
            return error
        } catch {
            return nil
        }
    }

    private func makeSearchIndex() throws -> SearchIndexService {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("free-v1-removal-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("search.sqlite")
        return try SearchIndexService(databaseURL: databaseURL)
    }

    private func makeNode(
        id: String,
        type: GraphNodeType,
        label: String,
        metadata: GraphNodeMetadata = GraphNodeMetadata(),
        createdAt: TimeInterval = 1
    ) -> GraphNodeRecord {
        GraphNodeRecord(
            id: id,
            type: type,
            label: label,
            sourceId: nil,
            metadata: metadata,
            weight: 1,
            createdAt: Date(timeIntervalSince1970: createdAt)
        )
    }

    private func makeEdge(
        id: String,
        source: String,
        target: String,
        createdAt: TimeInterval
    ) -> GraphEdgeRecord {
        GraphEdgeRecord(
            id: id,
            sourceNodeId: source,
            targetNodeId: target,
            type: .reference,
            weight: 1,
            createdAt: Date(timeIntervalSince1970: createdAt)
        )
    }
}
