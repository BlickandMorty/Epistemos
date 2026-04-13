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
            summary: "Primary 18GB-class MoE tier. Prefers the prepared APEXMini bundle when present and falls back to the installable MLX snapshot otherwise.",
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
            summary: "Best 4B model of 2026. Multimodal, 128K context. Replaces Qwen 4B as default light assistant.",
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
            summary: "Gemma 4 MoE: 27B total, only 4B active per token. Fits 18GB M2 Pro. 256K context, multimodal, fast.",
            approximateDownloadBytes: 19_327_000_000,
            minimumRecommendedMemoryGB: LocalTextModelID.gemma4_27BA4B4Bit.minimumRecommendedMemoryGB,
            revision: "8bcfa0de037c2b1bfa323a1e8d1f0132243b9e87",
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
            revision: "019cc73c45c770444708a6dd8690c66243cc5c80",
            matchingGlobs: [
                "*.json", "*.txt", "*.safetensors", "tokenizer.*",
                "special_tokens_map.json", "merges.txt", "vocab.json", "*.jinja",
            ]
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
            ]
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
        if inference.preparedLocalTextModelIDs.contains(descriptor.id) {
            return .prepared
        }
        return .available
    }

    func refreshFromDisk() {
        do {
            try paths.ensureBaseDirectories(fileManager: fileManager)
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

    private func pruneStaleRevisionInstalls() -> Bool {
        let staleRecords = installRecords.values.filter { record in
            guard let descriptor = LocalModelCatalog.descriptor(for: record.modelID) else {
                return false
            }
            return record.revision != descriptor.revision
        }
        guard !staleRecords.isEmpty else { return false }

        for record in staleRecords {
            try? removeIfPresent(record.activeDirectoryURL)
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
