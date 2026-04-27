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

/// User-facing capability role that groups models by the job they're best at.
/// This is separate from `PreparedModelRole` (retriever/generator/draft) which
/// describes the model's position in the Knowledge Fusion pipeline. A single
/// model may have a capability role AND a prepared-pipeline role independently.
///
/// The app exposes models to the user via this axis rather than as a flat list
/// of 20+ names, so a user can pick "Reasoning Local" without memorizing that
/// DeepSeek R1 7B is the current backing weight for that slot.
nonisolated enum ModelCapabilityRole: String, Codable, Hashable, Sendable, CaseIterable {
    /// Quick everyday chat, routing, and low-latency tool calls.
    case fastLocal = "fast_local"
    /// Chain-of-thought / math / logic oriented local reasoning.
    case reasoningLocal = "reasoning_local"
    /// Code generation, debugging, and local tool-calling.
    case codingLocal = "coding_local"
    /// Function-calling specialist — trained specifically for reliable
    /// tool-use on device. Distinct from codingLocal (code-heavy) and
    /// highEndLocal (generalist). Hermes 4.3 36B is the canonical fit.
    case functionCallingLocal = "function_calling_local"
    /// High-memory local pro/agent model for roomier Macs.
    case highEndLocal = "high_end_local"
    /// Cloud model with agent / computer-use capability (liveAgent tier).
    case cloudAgent = "cloud_agent"
    /// Cloud model with strong reasoning / research but no agentic tooling.
    case cloudReasoning = "cloud_reasoning"
    /// General-purpose model that doesn't cleanly fit the roles above.
    case generalist
}

extension ModelCapabilityRole {
    var displayName: String {
        switch self {
        case .fastLocal: "Fast Local"
        case .reasoningLocal: "Reasoning Local"
        case .codingLocal: "Coding Local"
        case .functionCallingLocal: "Function-Calling Local"
        case .highEndLocal: "High-End Local"
        case .cloudAgent: "Cloud Agent"
        case .cloudReasoning: "Cloud Reasoning"
        case .generalist: "Generalist"
        }
    }

    var shortSummary: String {
        switch self {
        case .fastLocal: "Quick everyday chat and routing."
        case .reasoningLocal: "Chain-of-thought, math, and logic."
        case .codingLocal: "Code generation, debugging, and tool use."
        case .functionCallingLocal: "Reliable on-device tool use and agent loops."
        case .highEndLocal: "Large local model for roomier Macs."
        case .cloudAgent: "Cloud agent with computer-use and long tool runs."
        case .cloudReasoning: "Cloud reasoning and deep research."
        case .generalist: "General-purpose assistant."
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
    /// Optional capability-role tag used by the role-first model picker.
    /// Nil means "fall back to unstructured catalog display" so existing
    /// on-disk install manifests remain backwards-compatible.
    let capabilityRole: ModelCapabilityRole?

    init(
        id: String,
        kind: LocalModelKind,
        displayName: String,
        familyName: String,
        summary: String,
        approximateDownloadBytes: Int64,
        minimumRecommendedMemoryGB: Int,
        revision: String,
        matchingGlobs: [String],
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

    var slug: String {
        id.replacingOccurrences(of: "/", with: "--")
    }

    var approximateDownloadLabel: String {
        ByteCountFormatter.string(fromByteCount: approximateDownloadBytes, countStyle: .file)
    }

    var runtimeKind: BackendRuntimeKind {
        LocalTextModelID(rawValue: id)?.runtimeKind ?? .mlx
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

    func usableHubSnapshotDirectory(
        for descriptor: LocalModelDescriptor,
        fileManager: FileManager = .default
    ) -> URL? {
        let repoDir = hubDirectory(for: descriptor.kind)
            .appendingPathComponent("models--\(descriptor.slug)", isDirectory: true)
        guard fileManager.fileExists(atPath: repoDir.path) else { return nil }

        let snapshotsDir = repoDir.appendingPathComponent("snapshots", isDirectory: true)
        let pinnedSnapshot = snapshotsDir.appendingPathComponent(descriptor.revision, isDirectory: true)
        if Self.directoryHasWeightBlobs(at: pinnedSnapshot, fileManager: fileManager) {
            return pinnedSnapshot
        }

        if let snapshots = try? fileManager.contentsOfDirectory(
            at: snapshotsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            for snapshot in snapshots.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                if Self.directoryHasWeightBlobs(at: snapshot, fileManager: fileManager) {
                    return snapshot
                }
            }
        }

        if Self.directoryHasWeightBlobs(at: repoDir, fileManager: fileManager) {
            return repoDir
        }
        return nil
    }

    static func directoryHasWeightBlobs(
        at directory: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        guard let files = try? fileManager.contentsOfDirectory(atPath: directory.path) else {
            return false
        }
        return files.contains {
            $0.hasSuffix(".safetensors") || $0.hasSuffix(".gguf") || $0.hasSuffix(".npz")
        }
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
        do {
            try backupExcludedRoot.setResourceValues(values)
        } catch {
            Log.engine.error(
                "LocalModelInfrastructure: failed to exclude \(backupExcludedRoot.path, privacy: .public) from backups: \(error.localizedDescription, privacy: .public)"
            )
        }
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
            summary: "High-memory Qwen MoE tier. Hidden on 18GB-class interactive laptops because that runtime was crash-prone there; stays available on higher-memory Macs.",
            approximateDownloadBytes: 20_411_668_782,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen35_35BA3B4Bit.minimumRecommendedMemoryGB,
            revision: "1e20fd8d42056f870933bf98ca6211024744f7ec",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwen36_35BA3B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen36_35BA3B4Bit.displayName,
            familyName: LocalTextModelID.qwen36_35BA3B4Bit.familyName,
            summary: "Legacy plain 4-bit quantization of Qwen 3.6 35B A3B. Existing installs still resolve; new downloads prefer the Unsloth UD or DWQ variants below for better quality at the same size.",
            approximateDownloadBytes: 20_400_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen36_35BA3B4Bit.minimumRecommendedMemoryGB,
            revision: "38740b847e4cb78f352aba30aa41c76e08e6eb46",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .highEndLocal
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwen36_35BA3B_Unsloth4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen36_35BA3B_Unsloth4Bit.displayName,
            familyName: LocalTextModelID.qwen36_35BA3B_Unsloth4Bit.familyName,
            summary: "Flagship local generalist. Unsloth's Dynamic 4-bit quantization preserves more quality than the plain community 4-bit at roughly the same download size. First-class pick for local .pro and .agent work.",
            approximateDownloadBytes: 20_400_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen36_35BA3B_Unsloth4Bit.minimumRecommendedMemoryGB,
            revision: "2cb4f08026a8e152e37d5044b25e47df4b3a9e87",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .highEndLocal
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwen36_35BA3B_DWQ4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen36_35BA3B_DWQ4Bit.displayName,
            familyName: LocalTextModelID.qwen36_35BA3B_DWQ4Bit.familyName,
            summary: "Alternative 4-bit Dynamic Weight Quantization of Qwen 3.6 35B A3B. Ships alongside the Unsloth UD variant so A/B comparisons on your own prompts are possible without downloading from outside the app.",
            approximateDownloadBytes: 20_400_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen36_35BA3B_DWQ4Bit.minimumRecommendedMemoryGB,
            revision: "73c707af4243243b18193444467872d20cff9399",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .highEndLocal
        ),
        // MARK: - Qwen 3 Family (tool-calling native, official MLX)
        LocalModelDescriptor(
            id: LocalTextModelID.qwen3_4B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen3_4B4Bit.displayName,
            familyName: LocalTextModelID.qwen3_4B4Bit.familyName,
            summary: "Fast local default with native tool-calling. Official Qwen MLX build — the clean non-Gemma-4 replacement for the fast tier. Routing, quick chat, and light agentic work all ride this model.",
            approximateDownloadBytes: 2_400_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen3_4B4Bit.minimumRecommendedMemoryGB,
            revision: "52a5ab34fa604bc8af6d3ce0cac0cab10b7eb495",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .fastLocal
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwen3_8B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen3_8B4Bit.displayName,
            familyName: LocalTextModelID.qwen3_8B4Bit.familyName,
            summary: "Best all-round Qwen 3 tier that still fits a 16 GB Mac. One checkpoint covers both quick `/no_think` turns and deeper `/think` reasoning without leaving the local path.",
            approximateDownloadBytes: 4_350_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen3_8B4Bit.minimumRecommendedMemoryGB,
            revision: "383413e909f3bc5303ce195ebbdf0339c5a1a2a3",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .highEndLocal
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwen3_4BThinking25074Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen3_4BThinking25074Bit.displayName,
            familyName: LocalTextModelID.qwen3_4BThinking25074Bit.familyName,
            summary: "Compact reasoning-first Qwen 3 checkpoint tuned for longer chain-of-thought on 16 GB Macs. Best when you want local thinking headroom without paying the 8B cost.",
            approximateDownloadBytes: 2_260_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen3_4BThinking25074Bit.minimumRecommendedMemoryGB,
            revision: "627b019c66f22d4de0a641d289b41497651a55c9",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .reasoningLocal
        ),
        // MARK: - Qwen 3 Coder (tool-calling code specialists)
        LocalModelDescriptor(
            id: LocalTextModelID.qwen3CoderNext4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen3CoderNext4Bit.displayName,
            familyName: LocalTextModelID.qwen3CoderNext4Bit.familyName,
            summary: "Qwen 3 generation coder sized for everyday development. Native tool-calling makes it the first choice for code + vault write workflows without needing the flagship 30B MoE.",
            approximateDownloadBytes: 5_500_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen3CoderNext4Bit.minimumRecommendedMemoryGB,
            revision: "7b9321eabb85ce79625cac3f61ea691e4ea984b5",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .codingLocal
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwen3Coder30BA3B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen3Coder30BA3B4Bit.displayName,
            familyName: LocalTextModelID.qwen3Coder30BA3B4Bit.familyName,
            summary: "Flagship local coder. Qwen 3 Coder 30B A3B is a Mixture-of-Experts model with strong repository-scale code generation and debugging. Preferred for .pro and .agent coding turns on roomier Macs.",
            approximateDownloadBytes: 17_500_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen3Coder30BA3B4Bit.minimumRecommendedMemoryGB,
            revision: "6e302ea604ad9ab206367e2c501d1571023e7b6d",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .codingLocal
        ),
        // MARK: - Hermes 4.3 (function-calling specialist, ByteDance Seed 36B base)
        LocalModelDescriptor(
            id: LocalTextModelID.hermes43_36B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.hermes43_36B4Bit.displayName,
            familyName: LocalTextModelID.hermes43_36B4Bit.familyName,
            summary: "On-device agent specialist. NousResearch Hermes 4.3 36B is built for reliable function calling with dedicated tool-call tokens and a verified reasoning-trace training set. When you want an agent loop without leaving the device, this is it.",
            approximateDownloadBytes: 21_500_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.hermes43_36B4Bit.minimumRecommendedMemoryGB,
            revision: "main",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .functionCallingLocal
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.hermes43_36B3Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.hermes43_36B3Bit.displayName,
            familyName: LocalTextModelID.hermes43_36B3Bit.familyName,
            summary: "3-bit Hermes 4.3 for Macs that can't hold the 4-bit 36B in memory. Same function-calling training, tighter quality budget.",
            approximateDownloadBytes: 15_500_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.hermes43_36B3Bit.minimumRecommendedMemoryGB,
            revision: "main",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .functionCallingLocal
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
            revision: "76b6a5af250fa029339a757deeb93716baa8ead0",
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
            summary: "Gemma 4 E4B preview weights. Keep available for loader bring-up work, but not recommended for the shipping interactive stack until the Swift runtime loader lands.",
            approximateDownloadBytes: 3_010_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.gemma4_4B4Bit.minimumRecommendedMemoryGB,
            revision: "62b0e4e2d06c2f3baeeb0f8b7b18d7308c7786fc",
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
            summary: "Gemma 4 26B preview weights. Keep available for loader bring-up work, but do not surface as a recommended local pro tier until the Swift runtime loader lands.",
            approximateDownloadBytes: 19_327_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.gemma4_27BA4B4Bit.minimumRecommendedMemoryGB,
            revision: "695690b33533b1f8b0395c1d6b4f00dc411353ef",
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
            revision: "83167cb7b232cbaef0bcca832921e95a052860df",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ]
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
            revision: "21848dbf533d2518a1ef895104820d5ee51317ea",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .reasoningLocal
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwqFlagship32B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwqFlagship32B4Bit.displayName,
            familyName: LocalTextModelID.qwqFlagship32B4Bit.familyName,
            summary: "QwQ 32B — Qwen team's flagship on-device reasoner (comparable to DeepSeek R1 at 32B). Reuses the Qwen MLX arch; no new loader required. 24 GB memory class.",
            approximateDownloadBytes: 19_200_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.qwqFlagship32B4Bit.minimumRecommendedMemoryGB,
            // Pinned revision — update with scripts/pin_catalog_revisions.sh
            // when a new QwQ build lands on mlx-community.
            revision: "main",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .reasoningLocal
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.qwen25Coder7B.rawValue,
            kind: .text,
            displayName: LocalTextModelID.qwen25Coder7B.displayName,
            familyName: LocalTextModelID.qwen25Coder7B.familyName,
            summary: "Legacy coder fallback for advanced testing. Requires 24 GB chat memory in practice; prefer Qwen 3 Coder Next for the validated shipping coding stack.",
            approximateDownloadBytes: 4_730_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.qwen25Coder7B.minimumRecommendedMemoryGB,
            revision: "019cc73c45c770444708a6dd8690c66243cc5c80",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .codingLocal
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.bonsai4B2Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.bonsai4B2Bit.displayName,
            familyName: LocalTextModelID.bonsai4B2Bit.familyName,
            summary: "Optional ultra-light fallback. Bonsai 4B is the small, fast local tier for constrained Macs and low-latency chat.",
            approximateDownloadBytes: 1_130_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.bonsai4B2Bit.minimumRecommendedMemoryGB,
            revision: "225499636909174ccc8a216574bfa20575c2023f",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .fastLocal
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.bonsai8B2Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.bonsai8B2Bit.displayName,
            familyName: LocalTextModelID.bonsai8B2Bit.familyName,
            summary: "Optional fast fallback with more headroom than Bonsai 4B. Great when you want a tiny local model that still feels sharper than the smallest tiers.",
            approximateDownloadBytes: 2_300_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.bonsai8B2Bit.minimumRecommendedMemoryGB,
            revision: "9cb0558242b3279d6f31e64020d61a45aa206c3e",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .fastLocal
        ),
        // MARK: - SSM Family
        LocalModelDescriptor(
            id: LocalTextModelID.lfm25_350M.rawValue,
            kind: .text,
            displayName: LocalTextModelID.lfm25_350M.displayName,
            familyName: LocalTextModelID.lfm25_350M.familyName,
            summary: "Tiny Liquid SSM tier for the lightest local routing, quick summarization, and low-memory Macs.",
            approximateDownloadBytes: 226_574_864,
            minimumRecommendedMemoryGB: LocalTextModelID.lfm25_350M.minimumRecommendedMemoryGB,
            revision: "8188cd2d54e7a49544853ec017ae21c17f752fc5",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.lfm25_1BInstruct.rawValue,
            kind: .text,
            displayName: LocalTextModelID.lfm25_1BInstruct.displayName,
            familyName: LocalTextModelID.lfm25_1BInstruct.familyName,
            summary: "Liquid 2.5 instruct tier for fast local chat and tool use on 8GB-class Macs.",
            approximateDownloadBytes: 663_548_128,
            minimumRecommendedMemoryGB: LocalTextModelID.lfm25_1BInstruct.minimumRecommendedMemoryGB,
            revision: "c30e30c5efac705771e1f37df38a32115718dd5d",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.lfm25_1BThinking.rawValue,
            kind: .text,
            displayName: LocalTextModelID.lfm25_1BThinking.displayName,
            familyName: LocalTextModelID.lfm25_1BThinking.familyName,
            summary: "Liquid 2.5 thinking tier for compact chain-of-thought and reasoning-heavy local use.",
            approximateDownloadBytes: 663_409_666,
            minimumRecommendedMemoryGB: LocalTextModelID.lfm25_1BThinking.minimumRecommendedMemoryGB,
            revision: "ae286200be34e3225c32de23fcd60ad1c81c6084",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.lfm25_VL1B.rawValue,
            kind: .text,
            displayName: LocalTextModelID.lfm25_VL1B.displayName,
            familyName: LocalTextModelID.lfm25_VL1B.familyName,
            summary: "Liquid 2.5 vision-language tier for local image grounding without leaving the on-device path.",
            approximateDownloadBytes: 1_496_383_379,
            minimumRecommendedMemoryGB: LocalTextModelID.lfm25_VL1B.minimumRecommendedMemoryGB,
            revision: "2a53fd7871a8f23c9d4427cf7a8d0dbb2e267605",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.lfm2_2B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.lfm2_2B4Bit.displayName,
            familyName: LocalTextModelID.lfm2_2B4Bit.familyName,
            summary: "Mid-size Liquid SSM tier with a larger context budget while staying practical on laptops.",
            approximateDownloadBytes: 1_450_530_492,
            minimumRecommendedMemoryGB: LocalTextModelID.lfm2_2B4Bit.minimumRecommendedMemoryGB,
            revision: "493071ebca3592c63085e19612ded87192a2a0dd",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.lfm2_8BA1B3Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.lfm2_8BA1B3Bit.displayName,
            familyName: LocalTextModelID.lfm2_8BA1B3Bit.familyName,
            summary: "Liquid MoE tier with low active parameter cost for heavier local tool and agent work.",
            approximateDownloadBytes: 4_176_559_875,
            minimumRecommendedMemoryGB: LocalTextModelID.lfm2_8BA1B3Bit.minimumRecommendedMemoryGB,
            revision: "0b05ca1d3fe12b7c9b9b57df674752eb63a46e5f",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.lfm2_24BA2B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.lfm2_24BA2B4Bit.displayName,
            familyName: LocalTextModelID.lfm2_24BA2B4Bit.familyName,
            summary: "Largest Liquid MoE tier for high-memory Macs that want long-context local SSM performance.",
            approximateDownloadBytes: 13_420_025_498,
            minimumRecommendedMemoryGB: LocalTextModelID.lfm2_24BA2B4Bit.minimumRecommendedMemoryGB,
            revision: "fb67c8c23d38cd4d7a9a6415ab80eefe83feecae",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.mamba2_2B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.mamba2_2B4Bit.displayName,
            familyName: LocalTextModelID.mamba2_2B4Bit.familyName,
            summary: "Standalone Mamba2 2.7B with recurrent-state resume on the MLX local path. Apple Silicon builds warm custom Metal helper kernels in this release, but generation still runs through MLX.",
            approximateDownloadBytes: 1_527_138_363,
            minimumRecommendedMemoryGB: LocalTextModelID.mamba2_2B4Bit.minimumRecommendedMemoryGB,
            revision: "f777c6f0377c7087b1e44739a396c42b4125f8ec",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ]
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.jamba3B.rawValue,
            kind: .text,
            displayName: LocalTextModelID.jamba3B.displayName,
            familyName: LocalTextModelID.jamba3B.familyName,
            summary: "AI21 Jamba reasoning tier with hybrid SSM behavior and a roomy local context window.",
            approximateDownloadBytes: 6_067_067_329,
            minimumRecommendedMemoryGB: LocalTextModelID.jamba3B.minimumRecommendedMemoryGB,
            revision: "905cf5a9eba147c5d3dc40c55dcc169394c3e27c",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ],
            capabilityRole: .reasoningLocal
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.falconH1R_7B4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.falconH1R_7B4Bit.displayName,
            familyName: LocalTextModelID.falconH1R_7B4Bit.familyName,
            summary: "Large Falcon H1 reasoning tier for local agent and tool-heavy work on roomier Macs.",
            approximateDownloadBytes: 4_279_703_397,
            minimumRecommendedMemoryGB: LocalTextModelID.falconH1R_7B4Bit.minimumRecommendedMemoryGB,
            revision: "0e3ed6b0e4de5581f22500d2cfdc58e6f37568c6",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "*.jinja",
            ],
            capabilityRole: .reasoningLocal
        ),
        // MARK: - Other Families
        LocalModelDescriptor(
            id: LocalTextModelID.llama32_3BInstruct4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.llama32_3BInstruct4Bit.displayName,
            familyName: LocalTextModelID.llama32_3BInstruct4Bit.familyName,
            summary: "Lean fast-local tier with strong latency on Apple Silicon. Great for routing, short summaries, and low-friction chat when you want to leave maximum unified memory free.",
            approximateDownloadBytes: 1_800_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.llama32_3BInstruct4Bit.minimumRecommendedMemoryGB,
            revision: "7f0dc925e0d0afb0322d96f9255cfddf2ba5636e",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .fastLocal
        ),
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
            ],
            capabilityRole: .codingLocal
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
            ],
            capabilityRole: .highEndLocal
        ),
        LocalModelDescriptor(
            id: LocalTextModelID.gemma3_4BQAT4Bit.rawValue,
            kind: .text,
            displayName: LocalTextModelID.gemma3_4BQAT4Bit.displayName,
            familyName: LocalTextModelID.gemma3_4BQAT4Bit.familyName,
            summary: "Practical Gemma 3 pick for 16 GB Macs. QAT 4-bit keeps the Gemma family available without the 27B memory cliff, with multimodal headroom for future local image-grounded work.",
            approximateDownloadBytes: 3_000_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.gemma3_4BQAT4Bit.minimumRecommendedMemoryGB,
            revision: "3d9ef289111449933c22761961f16a5df237ce2a",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ],
            capabilityRole: .generalist
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
            ],
            capabilityRole: .highEndLocal
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

    /// Returns the subset of catalog entries tagged with the given capability
    /// role. Entries without a role are never returned here — they only appear
    /// in the unstructured catalog list. Callers that need an exhaustive list
    /// should still use `allDescriptors`.
    nonisolated static func descriptors(forRole role: ModelCapabilityRole) -> [LocalModelDescriptor] {
        textDescriptors.filter { $0.capabilityRole == role }
    }

    /// Returns the catalog entry that should back the given capability role by
    /// default. Preference order inside a role: the baseline-curated pick
    /// first, then the lightest optional baseline, then the first catalog
    /// match. Returns nil when no descriptor is tagged with this role yet.
    nonisolated static func preferredDescriptor(forRole role: ModelCapabilityRole) -> LocalModelDescriptor? {
        let roleMatches = descriptors(forRole: role)
        if roleMatches.isEmpty { return nil }
        let curated = Set(curatedBaselineModelIDs)
        if let hit = roleMatches.first(where: { curated.contains($0.id) }) {
            return hit
        }
        let optional = Set(optionalBaselineModelIDs)
        if let hit = roleMatches.first(where: { optional.contains($0.id) }) {
            return hit
        }
        return roleMatches.first
    }

    /// Curated baseline — the three models that define the shipping
    /// experience. Fast tier, reasoning tier, coding tier. Every user
    /// gets these on first run; everything else is optional.
    nonisolated static let curatedBaselineModelIDs: [String] = [
        // Fast local with native tool-calling (Qwen 3 4B official).
        LocalTextModelID.qwen3_4B4Bit.rawValue,
        // Reasoning local (DeepSeek R1 7B; OpenThinker3-7B lands next
        // session once converted to MLX 4-bit).
        LocalTextModelID.deepseekR1Distill7B.rawValue,
        // Coding local (Qwen 3 Coder Next; the 30B A3B flagship is
        // optional because it needs 24GB).
        LocalTextModelID.qwen3CoderNext4Bit.rawValue,
    ]

    /// Optional baseline — models the user may want but that require
    /// more memory or are specialists. Offered during onboarding but
    /// not auto-installed.
    nonisolated static let optionalBaselineModelIDs: [String] = [
        // Ultra-light fallbacks for constrained Macs.
        LocalTextModelID.bonsai4B2Bit.rawValue,
        LocalTextModelID.bonsai8B2Bit.rawValue,
        LocalTextModelID.llama32_3BInstruct4Bit.rawValue,
        LocalTextModelID.gemma3_4BQAT4Bit.rawValue,
        // Flagship coder (30B A3B MoE — 24GB class).
        LocalTextModelID.qwen3Coder30BA3B4Bit.rawValue,
        LocalTextModelID.qwen3_8B4Bit.rawValue,
        LocalTextModelID.qwen3_4BThinking25074Bit.rawValue,
        // Function-calling specialist (Hermes 4.3 36B — both quants).
        LocalTextModelID.hermes43_36B4Bit.rawValue,
        LocalTextModelID.hermes43_36B3Bit.rawValue,
        // Flagship generalist — Qwen 3.6 35B A3B, two upgraded quants
        // so users can A/B compare Unsloth UD vs DWQ.
        LocalTextModelID.qwen36_35BA3B_Unsloth4Bit.rawValue,
        LocalTextModelID.qwen36_35BA3B_DWQ4Bit.rawValue,
        // Flagship reasoner — QwQ 32B, 24GB class.
        LocalTextModelID.qwqFlagship32B4Bit.rawValue,
        // Legacy Qwen 3.6 plain 4-bit (kept for existing installs).
        LocalTextModelID.qwen36_35BA3B4Bit.rawValue,
    ]

    nonisolated static let shippedModelIDs: [String] =
        curatedBaselineModelIDs + optionalBaselineModelIDs

    nonisolated static var curatedBaselineDescriptors: [LocalModelDescriptor] {
        curatedBaselineModelIDs.compactMap(descriptor(for:))
    }

    nonisolated static var optionalBaselineDescriptors: [LocalModelDescriptor] {
        optionalBaselineModelIDs.compactMap(descriptor(for:))
    }

    nonisolated static var experimentalDescriptors: [LocalModelDescriptor] {
        []
    }

    nonisolated static var advancedDescriptors: [LocalModelDescriptor] {
        []
    }

    nonisolated static func descriptor(for modelID: String) -> LocalModelDescriptor? {
        allDescriptors.first { $0.id == modelID }
    }

    // MARK: - D4 Faculty Roster — Primary Agent Model Defaults
    //
    // Per docs/CANONICAL_AUDIT_LOG.md Blocker D4: prior to this fix the
    // function-calling specialist resolver returned Hermes 4.3 36B as the
    // primary local agent. At 4-bit that is ~18 GB resident weights —
    // exceeds the 16 GB Epistemos hardware ceiling per the user's
    // [User Hardware] memory ("16GB unified memory ceiling; realistic
    // budget ~10-11GB for weights+KV; 4-bit 7-8B is the sweet spot").
    // Will OOM on the target hardware.
    //
    // The fix: default the primary local agent to a 7-8B 4-bit model and
    // gate the 36B variant behind ≥32 GB host RAM + an explicit opt-in
    // (UserDefaults `epistemos.localAgent.optInHermes36B`). The Settings →
    // Inference picker is the natural opt-in surface — a user who picks
    // Hermes 4.3 36B explicitly is opting in. Without that pick, the
    // default stays the 7-8B model on every host size, including 32 GB+.

    /// Minimum host unified memory (in whole GB) required before the
    /// large 36B function-calling specialist may serve as the primary
    /// agent model. Hosts below this threshold default to the 7-8B
    /// fallback regardless of any opt-in flag.
    nonisolated static let primaryAgentModelMinHostRAMGB: Int = 32

    /// UserDefaults key for the explicit opt-in to the 36B agent model.
    /// `false` (default) keeps every host on the 7-8B fallback even at
    /// ≥32 GB. The Settings → Inference picker writes this flag when the
    /// user picks Hermes 4.3 36B.
    nonisolated static let primaryAgentModel36BOptInDefaultsKey: String =
        "epistemos.localAgent.optInHermes36B"

    /// The 7-8B 4-bit fallback that is safe for every host, including
    /// the 16 GB Epistemos hardware floor. Qwen 3 8B at 4-bit is ~4.5 GB
    /// resident, leaving the realistic 11 GB budget on a 16 GB Mac with
    /// ample headroom for KV cache + app overhead.
    nonisolated static let fallbackPrimaryAgentModel: LocalTextModelID = .qwen3_8B4Bit

    /// The 36B opt-in target (function-calling specialist). Only served
    /// when host has ≥`primaryAgentModelMinHostRAMGB` GB AND the user
    /// has explicitly opted in via the Settings → Inference picker.
    nonisolated static let optInPrimaryAgentModel: LocalTextModelID = .hermes43_36B4Bit

    /// Resolves the default primary agent model for a given host snapshot
    /// and opt-in flag. Pure function for unit-test seams.
    nonisolated static func defaultPrimaryAgentModel(
        hostMemoryGB: Int,
        hasOptedInTo36B: Bool
    ) -> LocalTextModelID {
        if hostMemoryGB >= primaryAgentModelMinHostRAMGB && hasOptedInTo36B {
            return optInPrimaryAgentModel
        }
        return fallbackPrimaryAgentModel
    }

    /// Convenience accessor that uses the current hardware snapshot and
    /// the persisted opt-in flag from `UserDefaults.standard`. Tests use
    /// the `(hostMemoryGB:hasOptedInTo36B:)` overload above to avoid
    /// touching defaults.
    nonisolated static var defaultPrimaryAgentModel: LocalTextModelID {
        let hostMemoryGB = LocalHardwareCapabilitySnapshot.current.roundedMemoryGB
        let hasOptedIn = UserDefaults.standard.bool(
            forKey: primaryAgentModel36BOptInDefaultsKey
        )
        return defaultPrimaryAgentModel(
            hostMemoryGB: hostMemoryGB,
            hasOptedInTo36B: hasOptedIn
        )
    }
}

extension LocalHardwareCapabilitySnapshot {
    nonisolated func supports(descriptor: LocalModelDescriptor) -> Bool {
        if let model = LocalTextModelID(rawValue: descriptor.id) {
            return roundedMemoryGB >= model.minimumRecommendedInteractiveMemoryGB
        }
        return roundedMemoryGB >= descriptor.minimumRecommendedMemoryGB
    }
}

nonisolated enum LocalModelPresentationState: Equatable, Sendable {
    case installed(LocalModelInstallRecord)
    case prepared
    case installing(progress: Double)
    case blocked(reason: String)
    case available

    var title: String {
        switch self {
        case .installed:
            "Installed"
        case .prepared:
            "Prepared"
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

@MainActor @Observable
final class LocalModelManager {
    private nonisolated static let staleStagingDirectoryGraceInterval: TimeInterval = 30 * 60

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

    var curatedBaselineDescriptors: [LocalModelDescriptor] {
        LocalModelCatalog.curatedBaselineDescriptors
    }

    var optionalBaselineDescriptors: [LocalModelDescriptor] {
        LocalModelCatalog.optionalBaselineDescriptors
    }

    var experimentalDescriptors: [LocalModelDescriptor] {
        LocalModelCatalog.experimentalDescriptors
    }

    var advancedDescriptors: [LocalModelDescriptor] {
        LocalModelCatalog.advancedDescriptors
    }

    var legacyInstalledDescriptors: [LocalModelDescriptor] {
        installRecords.keys
            .sorted()
            .compactMap(LocalModelCatalog.descriptor(for:))
            .filter { descriptor in
                guard let model = LocalTextModelID(rawValue: descriptor.id) else {
                    return false
                }
                return !model.isEpistemosShippedLocalModel
            }
    }

    var hardwareSummary: String {
        "This Mac: \(inference.hardwareCapabilitySnapshot.roundedMemoryGB) GB unified memory"
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
            if let model = LocalTextModelID(rawValue: descriptor.id) {
                return .blocked(reason: "Needs \(model.minimumRecommendedInteractiveMemoryGB) GB for chat")
            }
            return .blocked(reason: "Needs \(descriptor.minimumRecommendedMemoryGB) GB")
        }
        if inference.preparedLocalTextModelIDs.contains(descriptor.id) {
            return .prepared
        }
        return .available
    }

    func refreshFromDisk() {
        do {
            try paths.ensureBaseDirectories(fileManager: fileManager)
            _ = purgeStaleStagingDirectories()
            installRecords = try loadManifest()
            let removedLegacyInstalls = purgeLegacyNonQwenInstalls()
            let removedMissingInstalls = pruneMissingInstalls()
            let removedStaleRevisionInstalls = pruneStaleRevisionInstalls()
            if removedLegacyInstalls || removedMissingInstalls || removedStaleRevisionInstalls {
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
        if activeInstalls.isEmpty {
            _ = purgeStaleStagingDirectories()
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

    func installRecommendedBaselineModels() async throws {
        for descriptor in curatedBaselineDescriptors {
            guard inference.hardwareCapabilitySnapshot.supports(descriptor: descriptor) else {
                continue
            }
            guard installRecords[descriptor.id] == nil else {
                continue
            }
            try await install(modelID: descriptor.id)
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

    private func pruneStaleRevisionInstalls() -> Bool {
        let staleRecords = installRecords.values.filter { record in
            guard let descriptor = LocalModelCatalog.descriptor(for: record.modelID) else {
                return false
            }
            return record.revision != descriptor.revision
        }
        guard !staleRecords.isEmpty else { return false }

        for record in staleRecords {
            do {
                try removeIfPresent(record.activeDirectoryURL)
            } catch {
                Log.engine.error(
                    "LocalModelInfrastructure: failed to remove stale install at \(record.activeDirectoryURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
            installErrors[record.modelID] = nil
        }

        installRecords = installRecords.filter { modelID, _ in
            guard let descriptor = LocalModelCatalog.descriptor(for: modelID) else {
                return false
            }
            return installRecords[modelID]?.revision == descriptor.revision
        }
        return true
    }

    private func purgeLegacyNonQwenInstalls() -> Bool {
        let staleRecords = installRecords.values.filter { LocalModelCatalog.descriptor(for: $0.modelID) == nil }
        let hasLegacyDirectories =
            fileManager.fileExists(atPath: legacyVoiceDirectory.path) ||
            fileManager.fileExists(atPath: legacyVoiceHubDirectory.path)
        guard !staleRecords.isEmpty || hasLegacyDirectories else { return false }

        for record in staleRecords {
            do {
                try removeIfPresent(record.activeDirectoryURL)
            } catch {
                Log.engine.error(
                    "LocalModelInfrastructure: failed to remove legacy install at \(record.activeDirectoryURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        do {
            try removeIfPresent(legacyVoiceDirectory)
        } catch {
            Log.engine.error(
                "LocalModelInfrastructure: failed to remove legacy voice directory at \(self.legacyVoiceDirectory.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        do {
            try removeIfPresent(legacyVoiceHubDirectory)
        } catch {
            Log.engine.error(
                "LocalModelInfrastructure: failed to remove legacy voice hub directory at \(self.legacyVoiceHubDirectory.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
        let filteredRecords = installRecords.filter { LocalModelCatalog.descriptor(for: $0.key) != nil }
        let didChangeRecords = filteredRecords != installRecords
        installRecords = filteredRecords
        return didChangeRecords
    }

    private func purgeStaleStagingDirectories() -> Bool {
        guard self.activeInstalls.isEmpty else { return false }
        guard self.fileManager.fileExists(atPath: self.paths.stagingDirectory.path) else { return false }
        let staleCutoff = Date().addingTimeInterval(-Self.staleStagingDirectoryGraceInterval)

        let kindDirectories: [URL]
        do {
            kindDirectories = try self.fileManager.contentsOfDirectory(
                at: self.paths.stagingDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            Log.engine.error(
                "LocalModelInfrastructure: failed to enumerate staging root \(self.paths.stagingDirectory.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return false
        }

        var removedAny = false
        for kindDirectory in kindDirectories {
            let isDirectory = (try? kindDirectory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            guard isDirectory else { continue }

            let stagedEntries: [URL]
            do {
                stagedEntries = try self.fileManager.contentsOfDirectory(
                    at: kindDirectory,
                    includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
            } catch {
                Log.engine.error(
                    "LocalModelInfrastructure: failed to enumerate staged installs in \(kindDirectory.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                )
                continue
            }

            for stagedEntry in stagedEntries {
                let metadata = try? stagedEntry.resourceValues(
                    forKeys: [.isDirectoryKey, .contentModificationDateKey]
                )
                guard metadata?.isDirectory == true else { continue }
                guard let modificationDate = metadata?.contentModificationDate,
                      modificationDate <= staleCutoff else {
                    continue
                }

                do {
                    try self.removeIfPresent(stagedEntry)
                    removedAny = true
                } catch {
                    Log.engine.error(
                        "LocalModelInfrastructure: failed to remove stale staging entry \(stagedEntry.path, privacy: .public): \(error.localizedDescription, privacy: .public)"
                    )
                }
            }
        }

        return removedAny
    }

    private var legacyVoiceDirectory: URL {
        paths.rootDirectory.appendingPathComponent("voice", isDirectory: true)
    }

    private var legacyVoiceHubDirectory: URL {
        legacyVoiceDirectory.appendingPathComponent("hub", isDirectory: true)
    }

    private func syncInferenceInstalledSets() {
        // Start with the manifest-based set (models this app installed itself).
        var installedIDs = Set(installRecords.values.filter { $0.kind == .text }.map(\.modelID))
        // Also detect hub directories that exist on disk but aren't in the
        // install manifest — e.g. models downloaded directly via
        // `huggingface-cli` or left over from a previous install manifest that
        // got wiped. Without this, the model picker shows "2 installed · 7
        // available" even when 12 real model dirs are present, which is how
        // Claude's 2026-04-22 audit surfaced the gap.
        installedIDs.formUnion(detectedOnDiskHubTextModelIDs())
        inference.setInstalledLocalTextModelIDs(installedIDs)
    }

    /// Return every catalog text-model ID whose expected HuggingFace hub
    /// directory exists on disk AND contains at least one substantive weight
    /// blob (`.safetensors`, `.gguf`, or `.npz`). This complements
    /// `installRecords` so models put on disk outside the app's install
    /// flow still count as installed. Intentionally catalog-driven so a
    /// stray unrelated hub directory does not accidentally surface in the
    /// picker.
    private func detectedOnDiskHubTextModelIDs() -> Set<String> {
        let hubDir = paths.hubDirectory(for: .text)
        guard fileManager.fileExists(atPath: hubDir.path) else { return [] }

        var result: Set<String> = []
        for descriptor in LocalModelCatalog.textDescriptors {
            guard paths.usableHubSnapshotDirectory(for: descriptor, fileManager: fileManager) != nil else {
                continue
            }
            result.insert(descriptor.id)
        }
        return result
    }

    private func adoptInstalledTextModelIfNeeded() {
        guard inference.effectiveLocalTextModelID == nil else { return }
        guard let modelID = inference.releaseSelectableInstalledLocalTextModelIDs.last else {
            return
        }
        inference.setPreferredLocalTextModelID(modelID)
    }

    private func adoptInstalledTextModelIfNeeded(_ modelID: String) {
        guard let model = LocalTextModelID(rawValue: modelID),
              model.isReleaseValidatedForInteractiveChat,
              inference.hardwareCapabilitySnapshot.supports(textModelID: modelID) else {
            adoptInstalledTextModelIfNeeded()
            return
        }
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
