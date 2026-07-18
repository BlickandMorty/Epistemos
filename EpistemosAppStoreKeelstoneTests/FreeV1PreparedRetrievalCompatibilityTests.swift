import Foundation
import Testing
@testable import Epistemos

#if !EPISTEMOS_APP_STORE || !MAS_SANDBOX || !EPISTEMOS_FREE_V1
#error("Free V1 prepared-retrieval compatibility tests must compile in the App Store target.")
#endif

@Suite("Free V1 prepared-retrieval compatibility")
struct FreeV1PreparedRetrievalCompatibilityTests {
    @Test("retained local search defaults to the deterministic embedding fallback")
    func preparedRetrievalWithoutLocalAssetsFallsBackToEmbeddings() {
        let configuration = PreparedRetrievalRuntimeConfiguration(
            retrieverModelID: "retained-local-search",
            retrieverSourceRoot: nil
        )

        #expect(configuration.assetLayout == nil)
        #expect(configuration.preparedRetrievalExecutionMode == .appleEmbeddingFallback)
        #expect(configuration.preparedRetrievalExecutionMode.usesSwiftEmbeddingFallback)
        #expect(!configuration.preparedRetrievalExecutionMode.hasPreparedAssetsConfigured)
    }

    @Test("a malformed local index manifest cannot overflow validation or activate the index")
    func overflowingIndexManifestFailsClosed() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FreeV1PreparedRetrievalCompatibilityTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let retrieverRoot = root.appendingPathComponent("retriever", isDirectory: true)
        let indexRoot = root.appendingPathComponent("index", isDirectory: true)
        let sourceDatabase = root.appendingPathComponent("vault.sqlite", isDirectory: false)
        try FileManager.default.createDirectory(at: retrieverRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: indexRoot, withIntermediateDirectories: true)
        try Data("vault".utf8).write(to: sourceDatabase)

        let manifest = PreparedRetrievalIndexManifest(
            retrieverModelID: "retained-local-search",
            embeddingFormat: "row-major-f32-v1",
            embeddingDimension: Int.max,
            documentCount: 2,
            embeddingsFile: "block-embeddings.f32",
            documentsFile: "documents.jsonl",
            sourceDatabasePath: sourceDatabase.path,
            sourceDatabaseModifiedAt: try sourceDatabase.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate?
                .timeIntervalSince1970,
            sourceDatabaseWALModifiedAt: nil
        )
        try JSONEncoder().encode(manifest).write(
            to: indexRoot.appendingPathComponent("manifest.json", isDirectory: false)
        )
        try Data().write(to: indexRoot.appendingPathComponent("block-embeddings.f32", isDirectory: false))
        try Data("first\nsecond\n".utf8).write(
            to: indexRoot.appendingPathComponent("documents.jsonl", isDirectory: false)
        )

        let configuration = PreparedRetrievalRuntimeConfiguration(
            retrieverModelID: "retained-local-search",
            retrieverSourceRoot: retrieverRoot.path
        )

        #expect(configuration.assetLayout?.readinessState == .invalidEmbeddings)
        #expect(configuration.preparedRetrievalExecutionMode == .preparedAssetsPendingIndex(
            retrieverModelID: "retained-local-search"
        ))
    }

    @Test("the retained retrieval contract has no model-registry or generation surface")
    func preparedRetrievalCompatibilityIsDataOnly() throws {
        let source = try sourceText("Epistemos/Engine/FreeV1PreparedRetrievalCompatibility.swift")

        #expect(source.contains("#if EPISTEMOS_FREE_V1"))
        for forbiddenSurface in [
            "PreparedModelRegistry",
            "PreparedModelDescriptor",
            "FoundationModels",
            "CloudLLM",
            "LLMService",
            "GGUF",
        ] {
            #expect(!source.contains(forbiddenSurface))
        }
    }

    private func sourceText(_ relativePath: String) throws -> String {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
