import Foundation
import Observation

// App-owned local generation models were removed. These small compatibility
// types keep graph/search prepared-retrieval code buildable while every chat /
// agent local-model catalog path fails closed.

nonisolated enum LocalModelKind: String, Codable, Sendable, CaseIterable {
    case text
}

nonisolated enum ModelCapabilityRole: String, Codable, Hashable, Sendable, CaseIterable {
    case generalist

    var displayName: String { "Generalist" }
    var shortSummary: String { "App-owned local generation models are removed." }
}

nonisolated struct LocalModelDescriptor: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let kind: LocalModelKind
    let displayName: String
    let familyName: String
    let summary: String
    let approximateDownloadBytes: Int64
    let minimumRecommendedMemoryGB: Int
    let revision: String
    let matchingGlobs: [String]
    let capabilityRole: ModelCapabilityRole?

    init(
        id: String,
        kind: LocalModelKind = .text,
        displayName: String,
        familyName: String = "Removed",
        summary: String = "App-owned local generation models are removed.",
        approximateDownloadBytes: Int64 = 0,
        minimumRecommendedMemoryGB: Int = Int.max,
        revision: String = "removed",
        matchingGlobs: [String] = [],
        capabilityRole: ModelCapabilityRole? = nil
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.familyName = familyName
        self.summary = summary
        self.approximateDownloadBytes = approximateDownloadBytes
        self.minimumRecommendedMemoryGB = minimumRecommendedMemoryGB
        self.revision = revision
        self.matchingGlobs = matchingGlobs
        self.capabilityRole = capabilityRole
    }

    var slug: String { id.replacingOccurrences(of: "/", with: "--") }
    var approximateDownloadLabel: String { "0 KB" }
    var runtimeKind: BackendRuntimeKind { .remote }
}

nonisolated enum GemmaQATRuntimeStage: String, Codable, Sendable, CaseIterable {
    case removed

    var displayName: String { "Removed" }
    var epistemosTier: EpistemosModelTier { .fast }
}

nonisolated struct GemmaQATRuntimeCandidate: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let displayName: String
    let sourceRepo: String
    let sourceURL: String
    let sourceRevision: String
    let expectedFilename: String
    let expectedFileBytes: Int64
    let expectedSHA256: String
    let blobID: String
    let runtimeLane: String
    let stage: GemmaQATRuntimeStage
    let localExecutionProofArtifactRef: String?
    let runtimeRouterAdmissionArtifactRef: String?
    let systemGDryRunArtifactRef: String?
    let routeAnswerPacketVisibilityArtifactRef: String?
    let settingsDiagnosticsWRVArtifactRef: String?
    let releaseGateRef: String

    var isReleaseSelectableForInteractiveChat: Bool { false }
    var allowsDefaultRouteMutation: Bool { false }
    var expectedByteCountLabel: String { "0 KB" }
    var proofStatusLabel: String { "removed" }
    var hasCompleteRouteEvidencePacketChain: Bool { false }
    var isProductRouteIntegrationCandidate: Bool { false }
    var routeIntegrationStatusLabel: String { "removed" }
    var acquisitionLaneArgument: String { "removed" }
    var minimumRecommendedMemoryGB: Int { Int.max }
    var catalogSummary: String { "App-owned local generation models are removed." }
    var familyName: String { "Removed" }
    var stackSource: ModelStackSource {
        ModelStackSource(
            id: id,
            displayName: displayName,
            summary: catalogSummary,
            approximateDownloadBytes: expectedFileBytes,
            minimumRecommendedMemoryGB: minimumRecommendedMemoryGB
        )
    }
    var localModelDescriptor: LocalModelDescriptor {
        LocalModelDescriptor(id: id, displayName: displayName)
    }
}

nonisolated enum GemmaQATRuntimeLadder {
    static let productRouteIntegrationCursor = "removed"
    static let candidates: [GemmaQATRuntimeCandidate] = []
    static func candidate(forID id: String) -> GemmaQATRuntimeCandidate? { nil }
}

enum LocalModelCatalog {
    nonisolated static let curatedBaselineModelIDs: [String] = []
    nonisolated static let optionalBaselineModelIDs: [String] = []
    nonisolated static let experimentalModelIDs: [String] = []
    nonisolated static let advancedModelIDs: [String] = []
    nonisolated static let fallbackPrimaryAgentModel: LocalTextModelID? = nil
    nonisolated static let optInPrimaryAgentModel: LocalTextModelID? = nil
    nonisolated static var defaultPrimaryAgentModel: LocalTextModelID? { nil }
    nonisolated static var textDescriptors: [LocalModelDescriptor] { [] }
    nonisolated static var allDescriptors: [LocalModelDescriptor] { [] }
    nonisolated static var curatedBaselineDescriptors: [LocalModelDescriptor] { [] }
    nonisolated static var optionalBaselineDescriptors: [LocalModelDescriptor] { [] }
    nonisolated static var experimentalDescriptors: [LocalModelDescriptor] { [] }
    nonisolated static var advancedDescriptors: [LocalModelDescriptor] { [] }
    nonisolated static var gemmaQATGGUFDescriptors: [LocalModelDescriptor] { [] }
    nonisolated static func descriptors(forRole role: ModelCapabilityRole) -> [LocalModelDescriptor] { [] }
    nonisolated static func preferredDescriptor(forRole role: ModelCapabilityRole) -> LocalModelDescriptor? { nil }
    nonisolated static func descriptor(for modelID: String) -> LocalModelDescriptor? { nil }
}

extension LocalHardwareCapabilitySnapshot {
    nonisolated func supports(descriptor: LocalModelDescriptor) -> Bool { false }
}

nonisolated enum PreparedModelRole: String, Codable, Sendable, CaseIterable {
    case retriever
    case generator
    case draftGenerator = "draft_generator"
}

nonisolated struct PreparedModelDescriptor: Hashable, Sendable {
    let key: String
    let role: PreparedModelRole
    let displayName: String
    let declaredRuntimeKind: BackendRuntimeKind?
    let artifactID: String?
    let modelID: String?
    let servedModelID: String
    let adapterPath: String?
    let expectedAdapterBaseModelID: String?
    let baseModelID: String?
    let baseSnapshotPath: String?
    let mergeOutputPath: String?
    let mlxOutputPath: String?
    let downloadPath: String?
    let status: String?
    let trustRemoteCode: Bool

    init(
        key: String,
        role: PreparedModelRole,
        displayName: String,
        declaredRuntimeKind: BackendRuntimeKind? = nil,
        artifactID: String? = nil,
        modelID: String? = nil,
        servedModelID: String,
        adapterPath: String? = nil,
        expectedAdapterBaseModelID: String? = nil,
        baseModelID: String? = nil,
        baseSnapshotPath: String? = nil,
        mergeOutputPath: String? = nil,
        mlxOutputPath: String? = nil,
        downloadPath: String? = nil,
        status: String? = nil,
        trustRemoteCode: Bool = false
    ) {
        self.key = key
        self.role = role
        self.displayName = displayName
        self.declaredRuntimeKind = declaredRuntimeKind
        self.artifactID = artifactID
        self.modelID = modelID
        self.servedModelID = servedModelID
        self.adapterPath = adapterPath
        self.expectedAdapterBaseModelID = expectedAdapterBaseModelID
        self.baseModelID = baseModelID
        self.baseSnapshotPath = baseSnapshotPath
        self.mergeOutputPath = mergeOutputPath
        self.mlxOutputPath = mlxOutputPath
        self.downloadPath = downloadPath
        self.status = status
        self.trustRemoteCode = trustRemoteCode
    }

    var runtimeKind: BackendRuntimeKind {
        if let declaredRuntimeKind {
            return declaredRuntimeKind
        }
        if let servedModel = LocalTextModelID(rawValue: servedModelID) {
            return servedModel.runtimeKind
        }
        if let modelID, let model = LocalTextModelID(rawValue: modelID) {
            return model.runtimeKind
        }
        if let artifactID, artifactID.localizedCaseInsensitiveContains("gguf") {
            return .gguf
        }
        if let downloadPath, downloadPath.localizedCaseInsensitiveContains(".gguf") {
            return .gguf
        }
        return .mlx
    }

    var resolvedAdapterPath: String? {
        Self.expandPath(adapterPath)
    }

    var resolvedDownloadPath: String? {
        Self.expandPath(downloadPath)
    }

    var resolvedMLXOutputPath: String? {
        Self.expandPath(mlxOutputPath)
    }

    func matchesSidecarModelID(_ modelID: String) -> Bool {
        if servedModelID == modelID {
            return true
        }

        guard let resolvedMLXOutputPath else { return false }
        let lhs = URL(fileURLWithPath: resolvedMLXOutputPath).standardizedFileURL.path
        let rhs = URL(fileURLWithPath: modelID).standardizedFileURL.path
        return lhs == rhs
    }

    private static func expandPath(_ rawPath: String?) -> String? {
        guard let rawPath, !rawPath.isEmpty else { return nil }
        return NSString(string: rawPath).expandingTildeInPath
    }
}

nonisolated struct PreparedModelRegistrySnapshot: Sendable, Equatable {
    let manifestURL: URL
    let entriesByKey: [String: PreparedModelDescriptor]

    func entry(named key: String) -> PreparedModelDescriptor? {
        entriesByKey[key]
    }

    var primaryRetriever: PreparedModelDescriptor? {
        entry(named: "retriever_primary")
    }

    var primaryGenerator: PreparedModelDescriptor? {
        entry(named: "generator_primary")
    }

    var speculativeDraftGenerator: PreparedModelDescriptor? {
        entry(named: "generator_speculative_draft")
    }

    var retrievalRuntimeConfiguration: PreparedRetrievalRuntimeConfiguration? {
        guard let primaryRetriever else { return nil }
        return PreparedRetrievalRuntimeConfiguration(
            retriever: primaryRetriever
        )
    }

    var generationRuntimeConfiguration: PreparedGenerationRuntimeConfiguration? {
        guard let primaryGenerator else { return nil }
        return PreparedGenerationRuntimeConfiguration(
            primaryGenerator: primaryGenerator,
            speculativeDraftGenerator: speculativeDraftGenerator
        )
    }
}

nonisolated struct PreparedRetrievalRuntimeConfiguration: Sendable, Equatable {
    let retriever: PreparedModelDescriptor

    var assetLayout: PreparedRetrievalAssetLayout? {
        guard let retrieverSourceRoot = retriever.resolvedDownloadPath else { return nil }
        return PreparedRetrievalAssetLayout(
            retrieverModelID: retriever.servedModelID,
            retrieverSourceRoot: retrieverSourceRoot
        )
    }

    var preparedRetrievalExecutionMode: PreparedRetrievalExecutionMode {
        guard Self.assetExists(at: retriever.resolvedDownloadPath) else {
            return .appleEmbeddingFallback
        }

        guard assetLayout?.isBuilt == true else {
            return .preparedAssetsPendingIndex(
                retrieverModelID: retriever.servedModelID
            )
        }
        return .preparedIndexReady(
            retrieverModelID: retriever.servedModelID
        )
    }

    private static func assetExists(at path: String?) -> Bool {
        guard let path, !path.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: path)
    }
}

nonisolated struct PreparedGenerationRuntimeConfiguration: Sendable, Equatable {
    let primaryGenerator: PreparedModelDescriptor
    let speculativeDraftGenerator: PreparedModelDescriptor?

    var primaryResolvedModelDirectory: URL? {
        resolvedModelDirectory(for: primaryGenerator)
    }

    var speculativeDraftResolvedModelDirectory: URL? {
        guard let speculativeDraftGenerator else { return nil }
        return resolvedModelDirectory(for: speculativeDraftGenerator)
    }

    func resolvedModelDirectory(for modelID: String) -> URL? {
        if primaryGenerator.matchesSidecarModelID(modelID) {
            return primaryResolvedModelDirectory
        }
        if let speculativeDraftGenerator,
           speculativeDraftGenerator.matchesSidecarModelID(modelID) {
            return speculativeDraftResolvedModelDirectory
        }
        return nil
    }

    func resolvedArtifactID(for modelID: String) -> String? {
        if primaryGenerator.matchesSidecarModelID(modelID) {
            return primaryGenerator.artifactID
        }
        if let speculativeDraftGenerator,
           speculativeDraftGenerator.matchesSidecarModelID(modelID) {
            return speculativeDraftGenerator.artifactID
        }
        return nil
    }

    func resolvedRuntimeKind(for modelID: String) -> BackendRuntimeKind? {
        if primaryGenerator.matchesSidecarModelID(modelID) {
            return primaryGenerator.runtimeKind
        }
        if let speculativeDraftGenerator,
           speculativeDraftGenerator.matchesSidecarModelID(modelID) {
            return speculativeDraftGenerator.runtimeKind
        }
        return nil
    }

    func hasUsablePreparedRuntime(
        for modelID: String,
        fileManager: FileManager = .default
    ) -> Bool {
        guard resolvedRuntimeKind(for: modelID) != nil,
              let resolvedDirectory = resolvedModelDirectory(for: modelID) else {
            return false
        }
        return fileManager.fileExists(atPath: resolvedDirectory.path)
    }

    func interactiveLocalTextModelIDs(
        availableRuntimeKinds: Set<BackendRuntimeKind> = [.mlx, .gguf],
        fileManager: FileManager = .default
    ) -> Set<String> {
        if primaryGenerator.runtimeKind == .gguf {
            guard availableRuntimeKinds.contains(.gguf) else {
                return []
            }
            guard primaryGenerator.artifactID?.isEmpty == false || !primaryGenerator.servedModelID.isEmpty else {
                return []
            }
            return [primaryGenerator.servedModelID]
        }

        guard let primaryResolvedModelDirectory,
              availableRuntimeKinds.contains(primaryGenerator.runtimeKind),
              fileManager.fileExists(atPath: primaryResolvedModelDirectory.path) else {
            return []
        }
        return [primaryGenerator.servedModelID]
    }

    private func resolvedModelDirectory(for descriptor: PreparedModelDescriptor) -> URL? {
        if let outputPath = descriptor.resolvedMLXOutputPath {
            return URL(fileURLWithPath: outputPath).standardizedFileURL
        }
        if let downloadPath = descriptor.resolvedDownloadPath {
            return URL(fileURLWithPath: downloadPath).standardizedFileURL
        }
        return nil
    }
}

nonisolated enum PreparedRetrievalExecutionMode: Equatable, Sendable {
    case appleEmbeddingFallback
    case preparedAssetsPendingIndex(retrieverModelID: String)
    case preparedIndexReady(retrieverModelID: String)

    var usesSwiftEmbeddingFallback: Bool {
        if case .appleEmbeddingFallback = self {
            return true
        }
        return false
    }

    var hasPreparedAssetsConfigured: Bool {
        !usesSwiftEmbeddingFallback
    }

    var requiresPreparedIndexBuild: Bool {
        if case .preparedAssetsPendingIndex = self {
            return true
        }
        return false
    }

    var hasPreparedIndexRuntime: Bool {
        if case .preparedIndexReady = self {
            return true
        }
        return false
    }
}

nonisolated struct PreparedRetrievalIndexManifest: Codable, Equatable, Sendable {
    let version: Int
    let retrieverModelID: String
    let embeddingFormat: String
    let embeddingDimension: Int
    let documentCount: Int
    let embeddingsFile: String
    let documentsFile: String
    let builtAt: TimeInterval?
    let sourceDatabasePath: String?
    let sourceDatabaseModifiedAt: TimeInterval?
    let sourceDatabaseWALModifiedAt: TimeInterval?

    init(
        version: Int = 1,
        retrieverModelID: String,
        embeddingFormat: String,
        embeddingDimension: Int,
        documentCount: Int,
        embeddingsFile: String,
        documentsFile: String,
        builtAt: TimeInterval? = nil,
        sourceDatabasePath: String? = nil,
        sourceDatabaseModifiedAt: TimeInterval? = nil,
        sourceDatabaseWALModifiedAt: TimeInterval? = nil
    ) {
        self.version = version
        self.retrieverModelID = retrieverModelID
        self.embeddingFormat = embeddingFormat
        self.embeddingDimension = embeddingDimension
        self.documentCount = documentCount
        self.embeddingsFile = embeddingsFile
        self.documentsFile = documentsFile
        self.builtAt = builtAt
        self.sourceDatabasePath = sourceDatabasePath
        self.sourceDatabaseModifiedAt = sourceDatabaseModifiedAt
        self.sourceDatabaseWALModifiedAt = sourceDatabaseWALModifiedAt
    }
}

nonisolated struct PreparedRetrievalAssetLayout: Equatable, Sendable {
    let retrieverModelID: String
    let retrieverSourceRoot: String
    let indexRoot: String
    let indexManifestPath: String
    let embeddingsPath: String
    let documentsPath: String

    init(
        retrieverModelID: String,
        retrieverSourceRoot: String
    ) {
        self.retrieverModelID = retrieverModelID
        self.retrieverSourceRoot = retrieverSourceRoot

        let sourceURL = URL(fileURLWithPath: retrieverSourceRoot, isDirectory: true)
        let indexRootURL = sourceURL.deletingLastPathComponent().appendingPathComponent("index", isDirectory: true)
        indexRoot = indexRootURL.path
        indexManifestPath = indexRootURL.appendingPathComponent("manifest.json", isDirectory: false).path
        embeddingsPath = indexRootURL.appendingPathComponent("block-embeddings.f32", isDirectory: false).path
        documentsPath = indexRootURL.appendingPathComponent("documents.jsonl", isDirectory: false).path
    }

    var readinessState: PreparedRetrievalReadinessState {
        guard let manifest = indexManifest else { return .missingManifest }
        guard manifestMatchesExpectedLayout(manifest) else { return .invalidManifest }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: embeddingsPath) else { return .missingEmbeddings }
        guard fileManager.fileExists(atPath: documentsPath) else { return .missingDocuments }
        guard hasValidEmbeddingMatrixSize(manifest: manifest) else { return .invalidEmbeddings }
        guard hasValidDocumentCount(manifest: manifest) else { return .invalidDocuments }
        guard hasFreshSourceDatabaseSnapshot(manifest: manifest) else { return .staleSourceSnapshot }
        return .ready
    }

    var isBuilt: Bool {
        readinessState == .ready
    }

    var indexManifest: PreparedRetrievalIndexManifest? {
        guard FileManager.default.fileExists(atPath: indexManifestPath) else { return nil }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: indexManifestPath))
            return try JSONDecoder().decode(PreparedRetrievalIndexManifest.self, from: data)
        } catch {
            Log.engine.error(
                "PreparedRetrievalAssetLayout: failed to load manifest at \(indexManifestPath, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    var expectedIndexManifest: PreparedRetrievalIndexManifest {
        PreparedRetrievalIndexManifest(
            retrieverModelID: retrieverModelID,
            embeddingFormat: "row-major-f32-v1",
            embeddingDimension: 0,
            documentCount: 0,
            embeddingsFile: URL(fileURLWithPath: embeddingsPath).lastPathComponent,
            documentsFile: URL(fileURLWithPath: documentsPath).lastPathComponent,
            builtAt: nil,
            sourceDatabasePath: nil,
            sourceDatabaseModifiedAt: nil,
            sourceDatabaseWALModifiedAt: nil
        )
    }

    private func manifestMatchesExpectedLayout(_ manifest: PreparedRetrievalIndexManifest) -> Bool {
        manifest.retrieverModelID == expectedIndexManifest.retrieverModelID
            && manifest.embeddingFormat == expectedIndexManifest.embeddingFormat
            && manifest.embeddingsFile == expectedIndexManifest.embeddingsFile
            && manifest.documentsFile == expectedIndexManifest.documentsFile
            && manifest.embeddingDimension > 0
            && manifest.documentCount > 0
    }

    private func hasValidEmbeddingMatrixSize(manifest: PreparedRetrievalIndexManifest) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: embeddingsPath),
              let size = attributes[.size] as? NSNumber else {
            return false
        }

        let expectedBytes = Int64(manifest.embeddingDimension)
            * Int64(manifest.documentCount)
            * Int64(MemoryLayout<Float>.size)
        guard expectedBytes > 0 else { return false }
        return size.int64Value == expectedBytes
    }

    private func hasValidDocumentCount(manifest: PreparedRetrievalIndexManifest) -> Bool {
        guard let handle = FileHandle(forReadingAtPath: documentsPath) else { return false }
        defer { try? handle.close() }

        var lineCount = 0
        var chunkRemainder = Data()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 64 * 1024)
            guard !chunk.isEmpty else { return false }
            chunkRemainder.append(chunk)
            let newlineCount = chunkRemainder.reduce(into: 0) { partialResult, byte in
                if byte == 0x0A { partialResult += 1 }
            }
            lineCount += newlineCount
            if let lastNewline = chunkRemainder.lastIndex(of: 0x0A) {
                chunkRemainder.removeSubrange(...lastNewline)
            }
            return true
        }) {}

        if !chunkRemainder.isEmpty {
            lineCount += 1
        }

        return lineCount == manifest.documentCount
    }

    private func hasFreshSourceDatabaseSnapshot(manifest: PreparedRetrievalIndexManifest) -> Bool {
        guard let sourceDatabasePath = manifest.sourceDatabasePath,
              let recordedDatabaseModifiedAt = manifest.sourceDatabaseModifiedAt else {
            return false
        }

        let sourceDatabaseURL = URL(fileURLWithPath: sourceDatabasePath)
        guard let currentDatabaseModifiedAt = fileModificationTime(sourceDatabaseURL) else {
            return false
        }

        let sourceDatabaseWALURL = URL(fileURLWithPath: sourceDatabasePath + "-wal")
        let currentWALModifiedAt = fileModificationTime(sourceDatabaseWALURL) ?? 0
        let recordedWALModifiedAt = manifest.sourceDatabaseWALModifiedAt ?? 0

        let recordedMostRecentSourceUpdate = max(recordedDatabaseModifiedAt, recordedWALModifiedAt)
        let currentMostRecentSourceUpdate = max(currentDatabaseModifiedAt, currentWALModifiedAt)
        return currentMostRecentSourceUpdate <= recordedMostRecentSourceUpdate + 0.001
    }

    private func fileModificationTime(_ url: URL) -> TimeInterval? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let date = values.contentModificationDate else {
            return nil
        }
        return date.timeIntervalSince1970
    }
}

nonisolated enum PreparedRetrievalReadinessState: Equatable, Sendable {
    case missingManifest
    case invalidManifest
    case missingEmbeddings
    case missingDocuments
    case invalidEmbeddings
    case invalidDocuments
    case staleSourceSnapshot
    case ready

    var requiresRebuild: Bool {
        self != .ready
    }
}

nonisolated enum PreparedModelRegistryError: LocalizedError, Equatable, Sendable {
    case manifestNotFound
    case invalidManifestVersion(Int)

    var errorDescription: String? {
        switch self {
        case .manifestNotFound:
            return "Prepared model manifest not found."
        case .invalidManifestVersion(let version):
            return "Unsupported prepared model manifest version: \(version)"
        }
    }
}

@MainActor @Observable
final class PreparedModelRegistryState {
    private(set) var manifestURL: URL?
    private(set) var entriesByKey: [String: PreparedModelDescriptor] = [:]
    private(set) var lastErrorMessage: String?

    func apply(_ snapshot: PreparedModelRegistrySnapshot) {
        manifestURL = snapshot.manifestURL
        entriesByKey = snapshot.entriesByKey
        lastErrorMessage = nil
    }

    func apply(error: Error) {
        entriesByKey = [:]
        lastErrorMessage = error.localizedDescription
    }

    func entry(named key: String) -> PreparedModelDescriptor? {
        entriesByKey[key]
    }

    var primaryRetriever: PreparedModelDescriptor? {
        entry(named: "retriever_primary")
    }

    var primaryGenerator: PreparedModelDescriptor? {
        entry(named: "generator_primary")
    }

    var speculativeDraftGenerator: PreparedModelDescriptor? {
        entry(named: "generator_speculative_draft")
    }

    var retrievalRuntimeConfiguration: PreparedRetrievalRuntimeConfiguration? {
        guard let primaryRetriever else { return nil }
        return PreparedRetrievalRuntimeConfiguration(
            retriever: primaryRetriever
        )
    }

    var generationRuntimeConfiguration: PreparedGenerationRuntimeConfiguration? {
        guard let primaryGenerator else { return nil }
        return PreparedGenerationRuntimeConfiguration(
            primaryGenerator: primaryGenerator,
            speculativeDraftGenerator: speculativeDraftGenerator
        )
    }
}

final class PreparedModelRegistry {
    private struct Manifest: Decodable {
        let version: Int
        let models: [String: Entry]
    }

    private struct Entry: Decodable {
        let role: PreparedModelRole
        let displayName: String
        let runtimeKind: BackendRuntimeKind?
        let artifactID: String?
        let modelID: String?
        let servedModelID: String?
        let adapterPath: String?
        let expectedAdapterBaseModelID: String?
        let baseModelID: String?
        let baseSnapshotPath: String?
        let mergeOutputPath: String?
        let mlxOutputPath: String?
        let downloadPath: String?
        let status: String?
        let trustRemoteCode: Bool?

        enum CodingKeys: String, CodingKey {
            case role
            case displayName = "display_name"
            case runtimeKind = "runtime_kind"
            case artifactID = "artifact_id"
            case modelID = "model_id"
            case servedModelID = "served_model_id"
            case adapterPath = "adapter_path"
            case expectedAdapterBaseModelID = "expected_adapter_base_model_id"
            case baseModelID = "base_model_id"
            case baseSnapshotPath = "base_snapshot_path"
            case mergeOutputPath = "merge_output_path"
            case mlxOutputPath = "mlx_output_path"
            case downloadPath = "download_path"
            case status
            case trustRemoteCode = "trust_remote_code"
        }
    }

    private let bundle: Bundle
    private let fileManager: FileManager
    private let overrideManifestURL: URL?

    init(
        bundle: Bundle = .main,
        fileManager: FileManager = .default,
        overrideManifestURL: URL? = nil
    ) {
        self.bundle = bundle
        self.fileManager = fileManager
        self.overrideManifestURL = overrideManifestURL
    }

    func load() throws -> PreparedModelRegistrySnapshot {
        let manifestURL = try resolvedManifestURL()
        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        guard manifest.version == 1 else {
            throw PreparedModelRegistryError.invalidManifestVersion(manifest.version)
        }

        let entriesByKey = Dictionary(uniqueKeysWithValues: manifest.models.map { key, entry in
            let servedModelID = entry.servedModelID
                ?? entry.artifactID
                ?? entry.modelID
                ?? key
            return (
                key,
                PreparedModelDescriptor(
                    key: key,
                    role: entry.role,
                    displayName: entry.displayName,
                    declaredRuntimeKind: entry.runtimeKind,
                    artifactID: entry.artifactID,
                    modelID: entry.modelID,
                    servedModelID: servedModelID,
                    adapterPath: entry.adapterPath,
                    expectedAdapterBaseModelID: entry.expectedAdapterBaseModelID,
                    baseModelID: entry.baseModelID,
                    baseSnapshotPath: entry.baseSnapshotPath,
                    mergeOutputPath: entry.mergeOutputPath,
                    mlxOutputPath: entry.mlxOutputPath,
                    downloadPath: entry.downloadPath,
                    status: entry.status,
                    trustRemoteCode: entry.trustRemoteCode ?? false
                )
            )
        })

        return PreparedModelRegistrySnapshot(
            manifestURL: manifestURL,
            entriesByKey: entriesByKey
        )
    }

    private func resolvedManifestURL() throws -> URL {
        if let overrideManifestURL {
            return overrideManifestURL
        }

        if let overriddenPath = ProcessInfo.processInfo.environment["EPISTEMOS_MODEL_MANIFEST_PATH"],
           !overriddenPath.isEmpty {
            return URL(fileURLWithPath: NSString(string: overriddenPath).expandingTildeInPath)
        }

        if let bundled = bundle.url(forResource: "model_manifest", withExtension: "json") {
            return bundled
        }

        let repoURL = Self.repoManifestURL
        if fileManager.fileExists(atPath: repoURL.path) {
            return repoURL
        }

        throw PreparedModelRegistryError.manifestNotFound
    }

    private static var repoManifestURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("config", isDirectory: true)
            .appendingPathComponent("model_manifest.json", isDirectory: false)
    }
}
