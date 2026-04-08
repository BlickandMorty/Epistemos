import Foundation
import Observation

nonisolated enum LocalModelKind: String, Codable, Sendable, CaseIterable {
    case text

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = rawValue == Self.text.rawValue ? .text : .text
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        switch self {
        case .text: "Text"
        }
    }
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

    var slug: String {
        id.replacingOccurrences(of: "/", with: "--")
    }

    var approximateDownloadLabel: String {
        ByteCountFormatter.string(fromByteCount: approximateDownloadBytes, countStyle: .file)
    }
}

nonisolated struct LocalModelInstallRecord: Identifiable, Codable, Equatable, Sendable {
    let modelID: String
    let kind: LocalModelKind
    let activeDirectoryPath: String
    let revision: String
    let installedAt: Date
    let sizeBytes: Int64

    var id: String { modelID }
    var activeDirectoryURL: URL { URL(fileURLWithPath: activeDirectoryPath) }
}

struct LocalModelInstallManifest: Codable, Sendable {
    let version: Int
    let records: [LocalModelInstallRecord]

    init(version: Int = 1, records: [LocalModelInstallRecord]) {
        self.version = version
        self.records = records
    }
}

nonisolated enum LocalModelManagerError: LocalizedError, Equatable {
    case unknownModel(String)
    case unsupportedHardware(String)
    case insufficientDiskSpace(requiredBytes: Int64, availableBytes: Int64)
    case installAlreadyRunning(String)
    case notInstalled(String)
    case invalidInstall(String)
    case corruptedManifest

    var errorDescription: String? {
        switch self {
        case .unknownModel(let modelID):
            return "Unknown local model: \(modelID)"
        case .unsupportedHardware(let modelID):
            return "This Mac does not have enough unified memory for \(modelID)."
        case .insufficientDiskSpace(let requiredBytes, let availableBytes):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return "Not enough free disk space. Need \(formatter.string(fromByteCount: requiredBytes)); only \(formatter.string(fromByteCount: availableBytes)) available."
        case .installAlreadyRunning(let modelID):
            return "Installation is already running for \(modelID)."
        case .notInstalled(let modelID):
            return "\(modelID) is not currently installed."
        case .invalidInstall(let modelID):
            return "The local install for \(modelID) is incomplete or corrupted."
        case .corruptedManifest:
            return "The local model manifest is corrupted."
        }
    }
}

protocol LocalModelArtifactInstalling: Sendable {
    func install(
        descriptor: LocalModelDescriptor,
        paths: LocalModelPaths,
        progressHandler: (@MainActor @Sendable (Progress) -> Void)?
    ) async throws -> LocalModelInstallRecord
}

nonisolated struct LocalModelPaths: Sendable, Equatable {
    let rootDirectory: URL

    static func defaultRootDirectory(fileManager: FileManager = .default) -> URL {
        let applicationSupport = FoundationSafety.userApplicationSupportDirectory(fileManager: fileManager)
        return applicationSupport
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("Models", isDirectory: true)
    }

    var manifestsDirectory: URL {
        rootDirectory.appendingPathComponent("manifests", isDirectory: true)
    }

    var manifestURL: URL {
        manifestsDirectory.appendingPathComponent("install-state.json", isDirectory: false)
    }

    var stagingDirectory: URL {
        rootDirectory.appendingPathComponent("staging", isDirectory: true)
    }

    func modelDirectory(for kind: LocalModelKind) -> URL {
        rootDirectory.appendingPathComponent(kind.rawValue, isDirectory: true)
    }

    func hubDirectory(for kind: LocalModelKind) -> URL {
        modelDirectory(for: kind).appendingPathComponent("hub", isDirectory: true)
    }

    func activeDirectory(for descriptor: LocalModelDescriptor) -> URL {
        modelDirectory(for: descriptor.kind)
            .appendingPathComponent("active", isDirectory: true)
            .appendingPathComponent(descriptor.slug, isDirectory: true)
    }

    func uniqueStagingDirectory(for descriptor: LocalModelDescriptor) -> URL {
        stagingDirectory
            .appendingPathComponent(descriptor.kind.rawValue, isDirectory: true)
            .appendingPathComponent("\(descriptor.slug)-\(UUID().uuidString)", isDirectory: true)
    }

    func ensureBaseDirectories(fileManager: FileManager = .default) throws {
        for directory in [
            rootDirectory,
            manifestsDirectory,
            stagingDirectory,
            hubDirectory(for: .text),
            modelDirectory(for: .text).appendingPathComponent("active", isDirectory: true),
        ] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var backupExcludedRoot = rootDirectory
        try? backupExcludedRoot.setResourceValues(values)
    }
}

enum LocalModelCatalog {
    nonisolated static let textDescriptors: [LocalModelDescriptor] = [
        LocalModelDescriptor(
            id: LocalTextModelID.qwen35_0_8B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen35_0_8B4Bit.displayName,
            familyName: LocalTextModelID.qwen35_0_8B4Bit.familyName,
            summary: "Smallest Qwen 3.5 tier. Best for constrained machines, quick checks, and low-memory local use.",
            approximateDownloadBytes: 645_218_830,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen35_0_8B4Bit.minimumRecommendedMemoryGB,
            revision: "da28692b5f139cb0ec58a356b437486b7dac7462",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwen35_2B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen35_2B4Bit.displayName,
            familyName: LocalTextModelID.qwen35_2B4Bit.familyName,
            summary: "Lightweight Qwen 3.5 tier for smaller laptops that still need useful local reasoning.",
            approximateDownloadBytes: 1_742_261_128,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen35_2B4Bit.minimumRecommendedMemoryGB,
            revision: "674aaa7240b91e8012fcad5d791b7dfe5ba90207",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwen35_4B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen35_4B4Bit.displayName,
            familyName: LocalTextModelID.qwen35_4B4Bit.familyName,
            summary: "Recommended local default for 18GB-class Apple Silicon laptops. Best balance of speed, memory headroom, and capability.",
            approximateDownloadBytes: 3_054_290_038,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen35_4B4Bit.minimumRecommendedMemoryGB,
            revision: "0e7ffd5c629ef7719d4cbc04069232580bfa9d9c",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwen35_9B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen35_9B4Bit.displayName,
            familyName: LocalTextModelID.qwen35_9B4Bit.familyName,
            summary: "Stronger Qwen 3.5 tier for machines with more headroom. Better local depth, higher memory cost.",
            approximateDownloadBytes: 5_970_210_415,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen35_9B4Bit.minimumRecommendedMemoryGB,
            revision: "8b2b98c00a6b4d291155e4890773ca8f769aee53",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwen35_27B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen35_27B4Bit.displayName,
            familyName: LocalTextModelID.qwen35_27B4Bit.familyName,
            summary: "Large Qwen 3.5 tier. Exposed honestly for high-memory Macs only.",
            approximateDownloadBytes: 16_074_535_502,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen35_27B4Bit.minimumRecommendedMemoryGB,
            revision: "45797d2985a12c55e6473686e9ea91b95e959553",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwen35_35BA3B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen35_35BA3B4Bit.displayName,
            familyName: LocalTextModelID.qwen35_35BA3B4Bit.familyName,
            summary: "Large MoE Qwen 3.5 tier for very high-memory Macs only.",
            approximateDownloadBytes: 20_411_668_782,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen35_35BA3B4Bit.minimumRecommendedMemoryGB,
            revision: "1e20fd8d42056f870933bf98ca6211024744f7ec",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
        ),
        // MARK: - Gemma 4 Family (2026 frontier, multimodal)
        LocalModelDescriptor(
            id: LocalTextModelID.gemma4_2B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.gemma4_2B4Bit.displayName,
            familyName: LocalTextModelID.gemma4_2B4Bit.familyName,
            summary: "Best 2B model of 2026. Multimodal (text+vision), 128K context. Ideal for routing and quick tasks.",
            approximateDownloadBytes: 1_614_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.gemma4_2B4Bit.minimumRecommendedMemoryGB,
            revision: "main", // TODO: verify revision SHA from mlx-community
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.gemma4_4B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.gemma4_4B4Bit.displayName,
            familyName: LocalTextModelID.gemma4_4B4Bit.familyName,
            summary: "Best 4B model of 2026. Multimodal, 128K context. Replaces Qwen 4B as default light assistant.",
            approximateDownloadBytes: 3_010_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.gemma4_4B4Bit.minimumRecommendedMemoryGB,
            revision: "main", // TODO: verify revision SHA
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.gemma4_12B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.gemma4_12B4Bit.displayName,
            familyName: LocalTextModelID.gemma4_12B4Bit.familyName,
            summary: "Mid-range Gemma 4 with thinking mode and multimodal. 256K context, strong reasoning.",
            approximateDownloadBytes: 8_590_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.gemma4_12B4Bit.minimumRecommendedMemoryGB,
            revision: "main", // TODO: verify revision SHA
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.gemma4_27BA4B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.gemma4_27BA4B4Bit.displayName,
            familyName: LocalTextModelID.gemma4_27BA4B4Bit.familyName,
            summary: "Gemma 4 MoE: 27B total, only 4B active per token. Fits 18GB M2 Pro. 256K context, multimodal, fast.",
            approximateDownloadBytes: 19_327_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.gemma4_27BA4B4Bit.minimumRecommendedMemoryGB,
            revision: "main", // TODO: verify revision SHA
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.gemma4_31BJANG.rawValue,
            kind: .text,
            displayName: LocalTextModelID.gemma4_31BJANG.displayName,
            familyName: LocalTextModelID.gemma4_31BJANG.familyName,
            summary: "Abliterated Gemma 4 31B dense. JANG mixed-precision (5.1-bit avg). Uncensored, 256K context. Requires vMLX 1.3.26+.",
            approximateDownloadBytes: 19_327_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.gemma4_31BJANG.minimumRecommendedMemoryGB,
            revision: "main", // TODO: verify revision SHA
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ]
        ),
        // MARK: - Qwopus (Claude Opus 4.6 distilled — GGUF via Ollama)
        LocalModelDescriptor(
            id: LocalTextModelID.qwopus27Bv3.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwopus27Bv3.displayName,
            familyName: LocalTextModelID.qwopus27Bv3.familyName,
            summary: "Claude Opus 4.6 reasoning distilled. 95.73% HumanEval. Best coding model. GGUF format — served via Ollama.",
            approximateDownloadBytes: 18_253_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.qwopus27Bv3.minimumRecommendedMemoryGB,
            revision: "main", // TODO: verify revision SHA
            matchingGlobs: ["*.gguf"]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwopusMoE35BA3B.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwopusMoE35BA3B.displayName,
            familyName: LocalTextModelID.qwopusMoE35BA3B.familyName,
            summary: "Qwopus MoE: 35B total, 3B active. Fastest reasoning MoE with Opus distillation. GGUF via Ollama.",
            approximateDownloadBytes: 20_972_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.qwopusMoE35BA3B.minimumRecommendedMemoryGB,
            revision: "main", // TODO: verify revision SHA
            matchingGlobs: ["*.gguf"]
        ),
        // MARK: - Specialist Models
        LocalModelDescriptor(
            id: LocalTextModelID.deepseekR1Distill7B.rawValue,
            kind: .text,
            displayName: LocalTextModelID.deepseekR1Distill7B.displayName,
            familyName: LocalTextModelID.deepseekR1Distill7B.familyName,
            summary: "DeepSeek R1 reasoning distilled into 7B. Beats many 14B models on math and logic. Native thinking mode.",
            approximateDownloadBytes: 4_831_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.deepseekR1Distill7B.minimumRecommendedMemoryGB,
            revision: "main", // TODO: verify revision SHA from mlx-community
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwen25Coder7B.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen25Coder7B.displayName,
            familyName: LocalTextModelID.qwen25Coder7B.familyName,
            summary: "Best sub-10B coding model. Optimized for code generation, debugging, and tool calling.",
            approximateDownloadBytes: 4_730_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen25Coder7B.minimumRecommendedMemoryGB,
            revision: "main", // TODO: verify revision SHA from mlx-community
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
        ),
        // MARK: - Other Families
        LocalModelDescriptor(
            id: LocalTextModelID.smolLM3_3B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.smolLM3_3B4Bit.displayName,
            familyName: LocalTextModelID.smolLM3_3B4Bit.familyName,
            summary: "Compact fallback for smaller Macs and secondary devices. Good when you want a lightweight non-Qwen local tier.",
            approximateDownloadBytes: 1_747_380_812,
            minimumRecommendedMemoryGB: LocalTextModelID.smolLM3_3B4Bit.minimumRecommendedMemoryGB,
            revision: "d3a7e0594d6642dbcfb7d149bed8b0bdf49f95ce",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.devstralSmall2505_4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.devstralSmall2505_4Bit.displayName,
            familyName: LocalTextModelID.devstralSmall2505_4Bit.familyName,
            summary: "Mid-size coding-oriented local tier for Macs with more headroom. Best for heavier edit and tool-heavy workflows.",
            approximateDownloadBytes: 13_277_563_657,
            minimumRecommendedMemoryGB: LocalTextModelID.devstralSmall2505_4Bit.minimumRecommendedMemoryGB,
            revision: "91ab74727385430dac575c8b0a27235367870cb6",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.mistralSmall31_24B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.mistralSmall31_24B4Bit.displayName,
            familyName: LocalTextModelID.mistralSmall31_24B4Bit.familyName,
            summary: "Large general-purpose Mistral tier with a roomy local context window for high-memory Macs.",
            approximateDownloadBytes: 14_119_058_051,
            minimumRecommendedMemoryGB: LocalTextModelID.mistralSmall31_24B4Bit.minimumRecommendedMemoryGB,
            revision: "46135ef3c556bfed61013d8789bd26af02e416c4",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.gemma3_27BQAT4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.gemma3_27BQAT4Bit.displayName,
            familyName: LocalTextModelID.gemma3_27BQAT4Bit.familyName,
            summary: "High-capacity Gemma tier for larger Macs that want a strong non-Qwen local model without leaving the MLX path.",
            approximateDownloadBytes: 16_873_390_675,
            minimumRecommendedMemoryGB: LocalTextModelID.gemma3_27BQAT4Bit.minimumRecommendedMemoryGB,
            revision: "fc4e000f32af1b7b6779294e490a7d2a80bac611",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.llama4Scout17B16E4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.llama4Scout17B16E4Bit.displayName,
            familyName: LocalTextModelID.llama4Scout17B16E4Bit.familyName,
            summary: "Very large MoE local tier for Mac Studio and high-memory MacBook Pro configurations only.",
            approximateDownloadBytes: 60_649_882_470,
            minimumRecommendedMemoryGB: LocalTextModelID.llama4Scout17B16E4Bit.minimumRecommendedMemoryGB,
            revision: "d7ee1ac4f3820a99409d987e38cc63349454dfbe",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
        ),
    ]

    nonisolated static var allDescriptors: [LocalModelDescriptor] {
        textDescriptors
    }

    nonisolated static func descriptor(for modelID: String) -> LocalModelDescriptor? {
        allDescriptors.first { $0.id == modelID }
    }
}

extension LocalHardwareCapabilitySnapshot {
    nonisolated func supports(descriptor: LocalModelDescriptor) -> Bool {
        roundedMemoryGB >= descriptor.minimumRecommendedMemoryGB
    }
}

nonisolated enum LocalModelPresentationState: Equatable, Sendable {
    case installed(LocalModelInstallRecord)
    case installing(progress: Double)
    case blocked(reason: String)
    case available

    var title: String {
        switch self {
        case .installed:
            "Installed"
        case .installing:
            "Downloading"
        case .blocked(let reason):
            reason
        case .available:
            "Available"
        }
    }
}

nonisolated enum PreparedModelRole: String, Codable, Sendable, CaseIterable {
    case retriever
}

nonisolated struct PreparedModelDescriptor: Hashable, Sendable {
    let key: String
    let role: PreparedModelRole
    let displayName: String
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

    var retrievalRuntimeConfiguration: PreparedRetrievalRuntimeConfiguration? {
        guard let primaryRetriever else { return nil }
        return PreparedRetrievalRuntimeConfiguration(
            retriever: primaryRetriever
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
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: indexManifestPath)) else { return nil }
        return try? JSONDecoder().decode(PreparedRetrievalIndexManifest.self, from: data)
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

    var retrievalRuntimeConfiguration: PreparedRetrievalRuntimeConfiguration? {
        guard let primaryRetriever else { return nil }
        return PreparedRetrievalRuntimeConfiguration(
            retriever: primaryRetriever
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

@MainActor @Observable
final class LocalModelManager {
    private let inference: InferenceState
    private let installer: any LocalModelArtifactInstalling
    private let fileManager: FileManager

    let paths: LocalModelPaths

    private(set) var installRecords: [String: LocalModelInstallRecord] = [:]
    private(set) var activeInstalls: Set<String> = []
    private(set) var installProgress: [String: Double] = [:]
    private(set) var installErrors: [String: String] = [:]
    private(set) var lastErrorMessage: String?

    init(
        inference: InferenceState,
        paths: LocalModelPaths = LocalModelPaths(rootDirectory: LocalModelPaths.defaultRootDirectory()),
        installer: any LocalModelArtifactInstalling,
        fileManager: FileManager = .default
    ) {
        self.inference = inference
        self.paths = paths
        self.installer = installer
        self.fileManager = fileManager
        refreshFromDisk()
    }

    var textDescriptors: [LocalModelDescriptor] {
        LocalModelCatalog.textDescriptors
    }

    var hardwareSummary: String {
        "\(inference.hardwareCapabilitySnapshot.roundedMemoryGB) GB unified memory"
    }

    var totalInstalledStorageBytes: Int64 {
        installRecords.values.reduce(0) { $0 + $1.sizeBytes }
    }

    var recommendedTextModelID: String {
        inference.hardwareCapabilitySnapshot.recommendedLocalTextModelID.rawValue
    }

    var constrainedFallbackTextModelID: String? {
        guard let fallback = inference.hardwareCapabilitySnapshot.recommendedConstrainedLocalTextModelID,
              inference.hardwareCapabilitySnapshot.supports(textModelID: fallback.rawValue) else {
            return nil
        }
        return fallback.rawValue
    }

    var missingConstrainedFallbackDescriptor: LocalModelDescriptor? {
        guard let modelID = constrainedFallbackTextModelID,
              installRecords[modelID] == nil else {
            return nil
        }
        return LocalModelCatalog.descriptor(for: modelID)
    }

    func presentationState(for descriptor: LocalModelDescriptor) -> LocalModelPresentationState {
        if let record = installRecords[descriptor.id] {
            return .installed(record)
        }
        if let error = installErrors[descriptor.id] {
            return .blocked(reason: error)
        }
        if activeInstalls.contains(descriptor.id) {
            return .installing(progress: installProgress[descriptor.id] ?? 0)
        }
        if !inference.hardwareCapabilitySnapshot.supports(descriptor: descriptor) {
            return .blocked(reason: "Needs \(descriptor.minimumRecommendedMemoryGB) GB")
        }
        return .available
    }

    func refreshFromDisk() {
        do {
            try paths.ensureBaseDirectories(fileManager: fileManager)
            installRecords = try loadManifest()
            let removedLegacyInstalls = purgeLegacyNonQwenInstalls()
            let removedMissingInstalls = pruneMissingInstalls()
            if removedLegacyInstalls || removedMissingInstalls {
                try persistManifest()
            }
            syncInferenceInstalledSets()
            adoptInstalledTextModelIfNeeded()
            lastErrorMessage = nil
        } catch {
            installRecords = [:]
            syncInferenceInstalledSets()
            lastErrorMessage = error.localizedDescription
        }
    }

    func install(modelID: String) async throws {
        guard let descriptor = LocalModelCatalog.descriptor(for: modelID) else {
            let error = LocalModelManagerError.unknownModel(modelID)
            lastErrorMessage = error.localizedDescription
            throw error
        }
        if activeInstalls.contains(modelID) {
            let error = LocalModelManagerError.installAlreadyRunning(modelID)
            lastErrorMessage = error.localizedDescription
            throw error
        }
        guard inference.hardwareCapabilitySnapshot.supports(descriptor: descriptor) else {
            let error = LocalModelManagerError.unsupportedHardware(modelID)
            installErrors[modelID] = error.localizedDescription
            lastErrorMessage = error.localizedDescription
            throw error
        }
        try assertSufficientDiskSpace(for: descriptor)

        activeInstalls.insert(modelID)
        installProgress[modelID] = 0
        installErrors[modelID] = nil

        defer {
            activeInstalls.remove(modelID)
            installProgress[modelID] = nil
        }

        do {
            let record = try await installer.install(
                descriptor: descriptor,
                paths: paths,
                progressHandler: { [weak self] progress in
                    guard let self else { return }
                    self.installProgress[modelID] = progress.fractionCompleted
                }
            )
            installRecords[modelID] = record
            try persistManifest()
            syncInferenceInstalledSets()
            adoptInstalledTextModelIfNeeded(modelID)
            lastErrorMessage = nil
        } catch {
            installErrors[modelID] = error.localizedDescription
            lastErrorMessage = error.localizedDescription
            throw error
        }
    }

    func uninstall(modelID: String) throws {
        guard let record = installRecords.removeValue(forKey: modelID) else {
            let error = LocalModelManagerError.notInstalled(modelID)
            lastErrorMessage = error.localizedDescription
            throw error
        }

        try removeIfPresent(record.activeDirectoryURL)
        if let descriptor = LocalModelCatalog.descriptor(for: modelID) {
            let cacheRoot = paths.hubDirectory(for: descriptor.kind)
            let repoDir = cacheRoot.appendingPathComponent("models--\(descriptor.id.replacingOccurrences(of: "/", with: "--"))")
            try removeIfPresent(repoDir)
        }
        installErrors[modelID] = nil
        try persistManifest()
        syncInferenceInstalledSets()
        adoptInstalledTextModelIfNeeded()
        lastErrorMessage = nil
    }

    private func pruneMissingInstalls() -> Bool {
        let prunedRecords = installRecords.filter { _, record in
            fileManager.fileExists(atPath: record.activeDirectoryPath)
        }
        guard prunedRecords != installRecords else { return false }
        installRecords = prunedRecords
        return true
    }

    private func purgeLegacyNonQwenInstalls() -> Bool {
        let staleRecords = installRecords.values.filter { LocalModelCatalog.descriptor(for: $0.modelID) == nil }
        let hasLegacyDirectories =
            fileManager.fileExists(atPath: legacyVoiceDirectory.path) ||
            fileManager.fileExists(atPath: legacyVoiceHubDirectory.path)
        guard !staleRecords.isEmpty || hasLegacyDirectories else { return false }

        for record in staleRecords {
            try? removeIfPresent(record.activeDirectoryURL)
        }
        try? removeIfPresent(legacyVoiceDirectory)
        try? removeIfPresent(legacyVoiceHubDirectory)
        let filteredRecords = installRecords.filter { LocalModelCatalog.descriptor(for: $0.key) != nil }
        let didChangeRecords = filteredRecords != installRecords
        installRecords = filteredRecords
        return didChangeRecords
    }

    private var legacyVoiceDirectory: URL {
        paths.rootDirectory.appendingPathComponent("voice", isDirectory: true)
    }

    private var legacyVoiceHubDirectory: URL {
        legacyVoiceDirectory.appendingPathComponent("hub", isDirectory: true)
    }

    private func syncInferenceInstalledSets() {
        inference.setInstalledLocalTextModelIDs(
            Set(installRecords.values.filter { $0.kind == .text }.map(\.modelID))
        )
    }

    private func adoptInstalledTextModelIfNeeded() {
        guard inference.effectiveLocalTextModelID == nil else { return }
        guard let modelID = LocalModelCatalog.textDescriptors
            .map(\.id)
            .last(where: { installRecords[$0] != nil && inference.hardwareCapabilitySnapshot.supports(textModelID: $0) }) else {
            return
        }
        inference.setPreferredLocalTextModelID(modelID)
    }

    private func adoptInstalledTextModelIfNeeded(_ modelID: String) {
        guard LocalTextModelID(rawValue: modelID) != nil else { return }
        guard inference.effectiveLocalTextModelID == nil else { return }
        inference.setPreferredLocalTextModelID(modelID)
    }

    private func loadManifest() throws -> [String: LocalModelInstallRecord] {
        guard fileManager.fileExists(atPath: paths.manifestURL.path) else { return [:] }
        let data = try Data(contentsOf: paths.manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(LocalModelInstallManifest.self, from: data)
        guard manifest.version == 1 else { throw LocalModelManagerError.corruptedManifest }
        return Dictionary(uniqueKeysWithValues: manifest.records.map { ($0.modelID, $0) })
    }

    private func persistManifest() throws {
        try paths.ensureBaseDirectories(fileManager: fileManager)
        let manifest = LocalModelInstallManifest(records: installRecords.values.sorted { $0.modelID < $1.modelID })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: paths.manifestURL, options: .atomic)
    }

    private func assertSufficientDiskSpace(for descriptor: LocalModelDescriptor) throws {
        let availableBytes = try availableCapacityBytes()
        let requiredBytes = Int64(Double(descriptor.approximateDownloadBytes) * 1.25)
        guard availableBytes >= requiredBytes else {
            throw LocalModelManagerError.insufficientDiskSpace(
                requiredBytes: requiredBytes,
                availableBytes: availableBytes
            )
        }
    }

    private func availableCapacityBytes() throws -> Int64 {
        let values = try paths.rootDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
    }

    private func removeIfPresent(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }
}
