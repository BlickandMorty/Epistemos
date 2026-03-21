import Foundation
import Testing
@testable import Epistemos

@Suite("LocalModelInfrastructure")
struct LocalModelInfrastructureTests {
    @Test("catalog pins immutable upstream revisions")
    func catalogUsesPinnedRevisions() {
        let revisions = LocalModelCatalog.allDescriptors.map(\.revision)

        #expect(!revisions.isEmpty)
        #expect(revisions.allSatisfy { $0 != "main" })
        #expect(revisions.allSatisfy { $0.range(of: "^[0-9a-f]{40}$", options: .regularExpression) != nil })
    }

    @Test("catalog exposes only qwen3.5 text models")
    func catalogIsQwen35Only() {
        let descriptors = LocalModelCatalog.allDescriptors

        #expect(!descriptors.isEmpty)
        #expect(descriptors.allSatisfy { $0.kind == .text })
        #expect(descriptors.allSatisfy { $0.id.contains("Qwen3.5") })
        #expect(descriptors.allSatisfy { !$0.familyName.localizedCaseInsensitiveContains("Gemma") })
    }

    @Test("18GB hardware recommends 4B default with 2B constrained fallback")
    func eighteenGBHardwareUsesSmallerConstrainedFallback() {
        let snapshot = LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: 18_000_000_000,
            roundedMemoryGB: 18,
            maxRecommendedLocalContentLength: 8_000
        )

        #expect(snapshot.recommendedLocalTextModelID == .qwen35_4B4Bit)
        #expect(snapshot.recommendedConstrainedLocalTextModelID == .qwen35_2B4Bit)
    }

    @MainActor
    @Test("install writes manifest and syncs inference state")
    func installPersistsManifest() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.rootDirectory) }

        let inference = InferenceState()
        let manager = LocalModelManager(
            inference: inference,
            paths: root,
            installer: FakeLocalModelInstaller()
        )

        try await manager.install(modelID: LocalTextModelID.qwen35_4B4Bit.rawValue)

        #expect(inference.installedLocalTextModelIDs.contains(LocalTextModelID.qwen35_4B4Bit.rawValue))
        #expect(FileManager.default.fileExists(atPath: root.manifestURL.path))

        let manifestData = try Data(contentsOf: root.manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(LocalModelInstallManifest.self, from: manifestData)
        #expect(manifest.records.count == 1)
        #expect(manifest.records.first?.modelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
    }

    @MainActor
    @Test("install adopts the first usable local tier when no exact selection is available")
    func installAdoptsFirstUsableTier() async throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.rootDirectory) }

        let inference = InferenceState()
        inference.setPreferredLocalTextModelID(LocalTextModelID.qwen35_4B4Bit.rawValue)

        let manager = LocalModelManager(
            inference: inference,
            paths: root,
            installer: FakeLocalModelInstaller()
        )

        try await manager.install(modelID: LocalTextModelID.qwen35_2B4Bit.rawValue)

        #expect(inference.preferredLocalTextModelID == LocalTextModelID.qwen35_2B4Bit.rawValue)
        #expect(inference.effectiveLocalTextModelID == LocalTextModelID.qwen35_2B4Bit.rawValue)
    }

    @MainActor
    @Test("refresh restores persisted install records")
    func refreshRestoresManifest() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.rootDirectory) }

        let installedURL = root.activeDirectory(
            for: try #require(LocalModelCatalog.descriptor(for: LocalTextModelID.qwen35_4B4Bit.rawValue))
        )
        try FileManager.default.createDirectory(at: installedURL, withIntermediateDirectories: true)

        let record = LocalModelInstallRecord(
            modelID: LocalTextModelID.qwen35_4B4Bit.rawValue,
            kind: .text,
            activeDirectoryPath: installedURL.path,
            revision: "1234567890abcdef1234567890abcdef12345678",
            installedAt: Date(timeIntervalSince1970: 1_234),
            sizeBytes: 123
        )
        try root.ensureBaseDirectories()
        let manifest = LocalModelInstallManifest(records: [record])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: root.manifestURL, options: .atomic)

        let inference = InferenceState()
        let manager = LocalModelManager(
            inference: inference,
            paths: root,
            installer: FakeLocalModelInstaller()
        )

        manager.refreshFromDisk()

        #expect(manager.installRecords[LocalTextModelID.qwen35_4B4Bit.rawValue] == record)
        #expect(inference.installedLocalTextModelIDs.contains(LocalTextModelID.qwen35_4B4Bit.rawValue))
        #expect(inference.effectiveLocalTextModelID == LocalTextModelID.qwen35_4B4Bit.rawValue)
    }

    @MainActor
    @Test("refresh drops legacy gemma and voice installs from disk and manifest")
    func refreshPurgesLegacyNonQwenInstalls() throws {
        let root = makeTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root.rootDirectory) }

        try root.ensureBaseDirectories()
        let legacyVoiceDirectory = root.rootDirectory
            .appendingPathComponent("voice", isDirectory: true)
            .appendingPathComponent("active", isDirectory: true)
            .appendingPathComponent("mlx-community--chatterbox-turbo-4bit", isDirectory: true)
        let legacyGemmaDirectory = root.modelDirectory(for: .text)
            .appendingPathComponent("active", isDirectory: true)
            .appendingPathComponent("mlx-community--gemma-2-9b-it-4bit", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyVoiceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacyGemmaDirectory, withIntermediateDirectories: true)

        let data = Data(
            """
            {
              "version": 1,
              "records": [
                {
                  "modelID": "mlx-community/chatterbox-turbo-4bit",
                  "kind": "voice",
                  "activeDirectoryPath": "\(legacyVoiceDirectory.path)",
                  "revision": "1234567890abcdef1234567890abcdef12345678",
                  "installedAt": "1970-01-01T00:20:34Z",
                  "sizeBytes": 123
                },
                {
                  "modelID": "mlx-community/gemma-2-9b-it-4bit",
                  "kind": "text",
                  "activeDirectoryPath": "\(legacyGemmaDirectory.path)",
                  "revision": "1234567890abcdef1234567890abcdef12345678",
                  "installedAt": "1970-01-01T00:20:34Z",
                  "sizeBytes": 123
                }
              ]
            }
            """.utf8
        )
        try data.write(to: root.manifestURL, options: .atomic)

        let inference = InferenceState()
        let manager = LocalModelManager(
            inference: inference,
            paths: root,
            installer: FakeLocalModelInstaller()
        )

        #expect(manager.installRecords.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: legacyVoiceDirectory.path))
        #expect(!FileManager.default.fileExists(atPath: legacyGemmaDirectory.path))
        #expect(inference.installedLocalTextModelIDs.isEmpty)
    }

    @MainActor
    @Test("live install smoke verifies qwen3.5 4B active files and manifest state")
    func liveInstallSmokeVerifiesQwen354B() async throws {
        guard FileManager.default.fileExists(atPath: "/tmp/epi-live-qwen35-install-smoke") else { return }

        let bootstrap = AppBootstrap()
        try await verifyLiveInstall(modelID: LocalTextModelID.qwen35_4B4Bit.rawValue, bootstrap: bootstrap)
    }

    @MainActor
    @Test("live install smoke verifies qwen3.5 2B constrained fallback files and manifest state")
    func liveInstallSmokeVerifiesQwen352B() async throws {
        guard FileManager.default.fileExists(atPath: "/tmp/epi-live-qwen35-2b-install-smoke") else { return }

        let bootstrap = AppBootstrap()
        try await verifyLiveInstall(modelID: LocalTextModelID.qwen35_2B4Bit.rawValue, bootstrap: bootstrap)
    }

    private func makeTemporaryRoot() -> LocalModelPaths {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return LocalModelPaths(rootDirectory: root)
    }

    @MainActor
    private func verifyLiveInstall(modelID: String, bootstrap: AppBootstrap) async throws {
        if bootstrap.localModelManager.installRecords[modelID] == nil {
            print("LOCAL_QWEN35_INSTALL_SMOKE install \(modelID)")
            try await bootstrap.localModelManager.install(modelID: modelID)
        } else {
            print("LOCAL_QWEN35_INSTALL_SMOKE already-installed \(modelID)")
        }

        bootstrap.localModelManager.refreshFromDisk()

        let descriptor = try #require(LocalModelCatalog.descriptor(for: modelID))
        let record = try #require(bootstrap.localModelManager.installRecords[modelID])
        let activeDirectory = bootstrap.localModelManager.paths.activeDirectory(for: descriptor)

        #expect(record.activeDirectoryURL == activeDirectory)
        #expect(FileManager.default.fileExists(atPath: activeDirectory.path))
        #expect(FileManager.default.fileExists(atPath: activeDirectory.appendingPathComponent("config.json").path))
        #expect(FileManager.default.fileExists(atPath: activeDirectory.appendingPathComponent("tokenizer.json").path))

        let safetensorFiles = try FileManager.default.contentsOfDirectory(at: activeDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "safetensors" }
        #expect(!safetensorFiles.isEmpty)
        #expect(bootstrap.inferenceState.installedLocalTextModelIDs.contains(modelID))

        let manifestData = try Data(contentsOf: bootstrap.localModelManager.paths.manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(LocalModelInstallManifest.self, from: manifestData)
        #expect(manifest.records.contains { $0.modelID == modelID })

        let connection = await bootstrap.localLLMClient.testConnection()
        #expect(connection.success)
        print(
            "LOCAL_QWEN35_INSTALL_SMOKE ready model=\(modelID) size=\(record.sizeBytes) files=\(safetensorFiles.count)"
        )
    }

    @Test("prepared retrieval assets stay pending until a semantic index exists")
    func preparedRetrievalAssetsStayPendingUntilIndexExists() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        let rerankerPath = tempRoot.appendingPathComponent("reranker", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rerankerPath, withIntermediateDirectories: true)

        let configuration = PreparedRetrievalRuntimeConfiguration(
            retriever: PreparedModelDescriptor(
                key: "retriever_primary",
                role: .retriever,
                displayName: "BGE-M3",
                artifactID: nil,
                modelID: "BAAI/bge-m3",
                servedModelID: "BAAI/bge-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: retrieverPath.path,
                status: "downloaded",
                trustRemoteCode: false
            ),
            reranker: PreparedModelDescriptor(
                key: "reranker_primary",
                role: .reranker,
                displayName: "BGE Reranker",
                artifactID: nil,
                modelID: "BAAI/bge-reranker-v2-m3",
                servedModelID: "BAAI/bge-reranker-v2-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: rerankerPath.path,
                status: "downloaded",
                trustRemoteCode: false
            )
        )

        #expect(
            configuration.preparedRetrievalExecutionMode
                == .preparedAssetsPendingIndex(
                    retrieverModelID: "BAAI/bge-m3",
                    rerankerModelID: "BAAI/bge-reranker-v2-m3"
                )
        )
    }

    @Test("prepared retrieval execution mode exposes shared fallback and readiness helpers")
    func preparedRetrievalExecutionModeHelpers() {
        #expect(PreparedRetrievalExecutionMode.appleEmbeddingFallback.usesSwiftEmbeddingFallback)
        #expect(!PreparedRetrievalExecutionMode.appleEmbeddingFallback.hasPreparedAssetsConfigured)
        #expect(!PreparedRetrievalExecutionMode.appleEmbeddingFallback.requiresPreparedIndexBuild)
        #expect(!PreparedRetrievalExecutionMode.appleEmbeddingFallback.hasPreparedIndexRuntime)

        let pendingIndex = PreparedRetrievalExecutionMode.preparedAssetsPendingIndex(
            retrieverModelID: "BAAI/bge-m3",
            rerankerModelID: nil
        )
        #expect(!pendingIndex.usesSwiftEmbeddingFallback)
        #expect(pendingIndex.hasPreparedAssetsConfigured)
        #expect(pendingIndex.requiresPreparedIndexBuild)
        #expect(!pendingIndex.hasPreparedIndexRuntime)

        let ready = PreparedRetrievalExecutionMode.preparedIndexReady(
            retrieverModelID: "BAAI/bge-m3",
            rerankerModelID: "BAAI/bge-reranker-v2-m3"
        )
        #expect(!ready.usesSwiftEmbeddingFallback)
        #expect(ready.hasPreparedAssetsConfigured)
        #expect(!ready.requiresPreparedIndexBuild)
        #expect(ready.hasPreparedIndexRuntime)
    }

    @Test("prepared retrieval runtime reports ready once a valid built index exists")
    func preparedRetrievalRuntimeReportsReadyOnceBuilt() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        let rerankerPath = tempRoot.appendingPathComponent("reranker", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rerankerPath, withIntermediateDirectories: true)

        let configuration = PreparedRetrievalRuntimeConfiguration(
            retriever: PreparedModelDescriptor(
                key: "retriever_primary",
                role: .retriever,
                displayName: "BGE-M3",
                artifactID: nil,
                modelID: "BAAI/bge-m3",
                servedModelID: "BAAI/bge-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: retrieverPath.path,
                status: "downloaded",
                trustRemoteCode: false
            ),
            reranker: PreparedModelDescriptor(
                key: "reranker_primary",
                role: .reranker,
                displayName: "BGE Reranker",
                artifactID: nil,
                modelID: "BAAI/bge-reranker-v2-m3",
                servedModelID: "BAAI/bge-reranker-v2-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: rerankerPath.path,
                status: "downloaded",
                trustRemoteCode: false
            )
        )

        let layout = try #require(configuration.assetLayout)
        try FileManager.default.createDirectory(atPath: layout.indexRoot, withIntermediateDirectories: true)
        let sourceDatabaseURL = try makeSourceDatabase(
            root: tempRoot,
            modifiedAt: Date(timeIntervalSince1970: 10)
        )
        let manifest = PreparedRetrievalIndexManifest(
            retrieverModelID: "BAAI/bge-m3",
            rerankerModelID: "BAAI/bge-reranker-v2-m3",
            embeddingFormat: "row-major-f32-v1",
            embeddingDimension: 2,
            documentCount: 1,
            embeddingsFile: "block-embeddings.f32",
            documentsFile: "documents.jsonl",
            builtAt: 10,
            sourceDatabasePath: sourceDatabaseURL.path,
            sourceDatabaseModifiedAt: 10,
            sourceDatabaseWALModifiedAt: nil
        )
        try JSONEncoder().encode(manifest).write(to: URL(fileURLWithPath: layout.indexManifestPath), options: .atomic)
        try Data(count: 8).write(to: URL(fileURLWithPath: layout.embeddingsPath), options: .atomic)
        try Data("{\"block_id\":\"block-1\",\"page_id\":\"page-1\",\"content\":\"hello\"}\n".utf8)
            .write(to: URL(fileURLWithPath: layout.documentsPath), options: .atomic)

        #expect(layout.readinessState == .ready)
        #expect(
            configuration.preparedRetrievalExecutionMode
                == .preparedIndexReady(
                    retrieverModelID: "BAAI/bge-m3",
                    rerankerModelID: "BAAI/bge-reranker-v2-m3"
                )
        )
    }

    @Test("prepared retrieval runtime rejects mismatched index manifests")
    func preparedRetrievalRuntimeRejectsMismatchedIndexManifest() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        let rerankerPath = tempRoot.appendingPathComponent("reranker", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rerankerPath, withIntermediateDirectories: true)

        let configuration = PreparedRetrievalRuntimeConfiguration(
            retriever: PreparedModelDescriptor(
                key: "retriever_primary",
                role: .retriever,
                displayName: "BGE-M3",
                artifactID: nil,
                modelID: "BAAI/bge-m3",
                servedModelID: "BAAI/bge-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: retrieverPath.path,
                status: "downloaded",
                trustRemoteCode: false
            ),
            reranker: PreparedModelDescriptor(
                key: "reranker_primary",
                role: .reranker,
                displayName: "BGE Reranker",
                artifactID: nil,
                modelID: "BAAI/bge-reranker-v2-m3",
                servedModelID: "BAAI/bge-reranker-v2-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: rerankerPath.path,
                status: "downloaded",
                trustRemoteCode: false
            )
        )

        let layout = try #require(configuration.assetLayout)
        try FileManager.default.createDirectory(atPath: layout.indexRoot, withIntermediateDirectories: true)
        let manifest = PreparedRetrievalIndexManifest(
            retrieverModelID: "BAAI/not-bge-m3",
            rerankerModelID: "BAAI/bge-reranker-v2-m3",
            embeddingFormat: "row-major-f32-v1",
            embeddingDimension: 2,
            documentCount: 1,
            embeddingsFile: "block-embeddings.f32",
            documentsFile: "documents.jsonl"
        )
        try JSONEncoder().encode(manifest).write(to: URL(fileURLWithPath: layout.indexManifestPath), options: .atomic)
        try Data(count: 8).write(to: URL(fileURLWithPath: layout.embeddingsPath), options: .atomic)
        try Data("{\"block_id\":\"block-1\",\"page_id\":\"page-1\",\"content\":\"hello\"}\n".utf8)
            .write(to: URL(fileURLWithPath: layout.documentsPath), options: .atomic)

        #expect(layout.readinessState == .invalidManifest)
        #expect(
            configuration.preparedRetrievalExecutionMode
                == .preparedAssetsPendingIndex(
                    retrieverModelID: "BAAI/bge-m3",
                    rerankerModelID: "BAAI/bge-reranker-v2-m3"
                )
        )
    }

    @Test("prepared retrieval runtime rejects mismatched embedding matrix shape")
    func preparedRetrievalRuntimeRejectsMismatchedEmbeddingMatrixShape() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        let rerankerPath = tempRoot.appendingPathComponent("reranker", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rerankerPath, withIntermediateDirectories: true)

        let configuration = PreparedRetrievalRuntimeConfiguration(
            retriever: PreparedModelDescriptor(
                key: "retriever_primary",
                role: .retriever,
                displayName: "BGE-M3",
                artifactID: nil,
                modelID: "BAAI/bge-m3",
                servedModelID: "BAAI/bge-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: retrieverPath.path,
                status: "downloaded",
                trustRemoteCode: false
            ),
            reranker: PreparedModelDescriptor(
                key: "reranker_primary",
                role: .reranker,
                displayName: "BGE Reranker",
                artifactID: nil,
                modelID: "BAAI/bge-reranker-v2-m3",
                servedModelID: "BAAI/bge-reranker-v2-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: rerankerPath.path,
                status: "downloaded",
                trustRemoteCode: false
            )
        )

        let layout = try #require(configuration.assetLayout)
        try FileManager.default.createDirectory(atPath: layout.indexRoot, withIntermediateDirectories: true)
        let manifest = PreparedRetrievalIndexManifest(
            retrieverModelID: "BAAI/bge-m3",
            rerankerModelID: "BAAI/bge-reranker-v2-m3",
            embeddingFormat: "row-major-f32-v1",
            embeddingDimension: 2,
            documentCount: 2,
            embeddingsFile: "block-embeddings.f32",
            documentsFile: "documents.jsonl"
        )
        try JSONEncoder().encode(manifest).write(to: URL(fileURLWithPath: layout.indexManifestPath), options: .atomic)
        try Data(count: 8).write(to: URL(fileURLWithPath: layout.embeddingsPath), options: .atomic)
        try Data("""
        {"block_id":"block-1","page_id":"page-1","content":"hello"}
        {"block_id":"block-2","page_id":"page-2","content":"world"}
        """.utf8).write(to: URL(fileURLWithPath: layout.documentsPath), options: .atomic)

        #expect(layout.readinessState == .invalidEmbeddings)
        #expect(
            configuration.preparedRetrievalExecutionMode
                == .preparedAssetsPendingIndex(
                    retrieverModelID: "BAAI/bge-m3",
                    rerankerModelID: "BAAI/bge-reranker-v2-m3"
                )
        )
    }

    @Test("prepared retrieval runtime rejects stale source database snapshots")
    func preparedRetrievalRuntimeRejectsStaleSourceDatabaseSnapshot() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let retrieverPath = tempRoot.appendingPathComponent("retriever", isDirectory: true)
        let rerankerPath = tempRoot.appendingPathComponent("reranker", isDirectory: true)
        try FileManager.default.createDirectory(at: retrieverPath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rerankerPath, withIntermediateDirectories: true)

        let configuration = PreparedRetrievalRuntimeConfiguration(
            retriever: PreparedModelDescriptor(
                key: "retriever_primary",
                role: .retriever,
                displayName: "BGE-M3",
                artifactID: nil,
                modelID: "BAAI/bge-m3",
                servedModelID: "BAAI/bge-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: retrieverPath.path,
                status: "downloaded",
                trustRemoteCode: false
            ),
            reranker: PreparedModelDescriptor(
                key: "reranker_primary",
                role: .reranker,
                displayName: "BGE Reranker",
                artifactID: nil,
                modelID: "BAAI/bge-reranker-v2-m3",
                servedModelID: "BAAI/bge-reranker-v2-m3",
                adapterPath: nil,
                expectedAdapterBaseModelID: nil,
                baseModelID: nil,
                baseSnapshotPath: nil,
                mergeOutputPath: nil,
                mlxOutputPath: nil,
                downloadPath: rerankerPath.path,
                status: "downloaded",
                trustRemoteCode: false
            )
        )

        let layout = try #require(configuration.assetLayout)
        try FileManager.default.createDirectory(atPath: layout.indexRoot, withIntermediateDirectories: true)
        let sourceDatabaseURL = try makeSourceDatabase(
            root: tempRoot,
            modifiedAt: Date(timeIntervalSince1970: 10)
        )
        let manifest = PreparedRetrievalIndexManifest(
            retrieverModelID: "BAAI/bge-m3",
            rerankerModelID: "BAAI/bge-reranker-v2-m3",
            embeddingFormat: "row-major-f32-v1",
            embeddingDimension: 2,
            documentCount: 1,
            embeddingsFile: "block-embeddings.f32",
            documentsFile: "documents.jsonl",
            builtAt: 10,
            sourceDatabasePath: sourceDatabaseURL.path,
            sourceDatabaseModifiedAt: 10,
            sourceDatabaseWALModifiedAt: nil
        )
        try JSONEncoder().encode(manifest).write(to: URL(fileURLWithPath: layout.indexManifestPath), options: .atomic)
        try Data(count: 8).write(to: URL(fileURLWithPath: layout.embeddingsPath), options: .atomic)
        try Data("{\"block_id\":\"block-1\",\"page_id\":\"page-1\",\"content\":\"hello\"}\n".utf8)
            .write(to: URL(fileURLWithPath: layout.documentsPath), options: .atomic)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 20)],
            ofItemAtPath: sourceDatabaseURL.path
        )

        #expect(layout.readinessState == .staleSourceSnapshot)
        #expect(
            configuration.preparedRetrievalExecutionMode
                == .preparedAssetsPendingIndex(
                    retrieverModelID: "BAAI/bge-m3",
                    rerankerModelID: "BAAI/bge-reranker-v2-m3"
                )
        )
    }
}

private actor FakeLocalModelInstaller: LocalModelArtifactInstalling {
    func install(
        descriptor: LocalModelDescriptor,
        paths: LocalModelPaths,
        progressHandler: (@MainActor @Sendable (Progress) -> Void)?
    ) async throws -> LocalModelInstallRecord {
        try paths.ensureBaseDirectories()
        let activeDirectory = paths.activeDirectory(for: descriptor)
        try FileManager.default.createDirectory(at: activeDirectory, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: activeDirectory.appendingPathComponent("config.json"))
        try Data("tokenizer".utf8).write(to: activeDirectory.appendingPathComponent("tokenizer.json"))
        try Data([1, 2, 3]).write(to: activeDirectory.appendingPathComponent("weights.safetensors"))

        let progress = Progress(totalUnitCount: 1)
        progress.completedUnitCount = 1
        await progressHandler?(progress)

        return LocalModelInstallRecord(
            modelID: descriptor.id,
            kind: descriptor.kind,
            activeDirectoryPath: activeDirectory.path,
            revision: descriptor.revision,
            installedAt: Date(timeIntervalSince1970: 42),
            sizeBytes: 3
        )
    }
}

private func makeSourceDatabase(root: URL, modifiedAt: Date) throws -> URL {
    let sourceDatabaseURL = root.appendingPathComponent("search.sqlite", isDirectory: false)
    FileManager.default.createFile(atPath: sourceDatabaseURL.path, contents: Data("db".utf8))
    try FileManager.default.setAttributes([.modificationDate: modifiedAt], ofItemAtPath: sourceDatabaseURL.path)
    return sourceDatabaseURL
}
