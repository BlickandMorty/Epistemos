import Foundation

// Plan 1-MAS §2.2 model set — corrected by KV-cache math. Apache-2.0/MIT
// licenses only (no HF license-acceptance gating in the downloader). Sizes
// are Q4_K_M GGUF. KV/token = 2 × layers × kv_heads × head_dim × 2 bytes.

nonisolated enum GGUFChatTemplateFamily: String, Sendable, Equatable {
    /// Qwen (ChatML markers).
    case chatML
    /// Gemma-style turns (used by user-imported Gemma files).
    case gemma

    func apply(userPrompt: String, instructions: String?) -> String {
        switch self {
        case .chatML:
            var text = ""
            if let instructions, !instructions.isEmpty {
                text += "<|im_start|>system\n\(instructions)<|im_end|>\n"
            }
            text += "<|im_start|>user\n\(userPrompt)<|im_end|>\n<|im_start|>assistant\n"
            return text
        case .gemma:
            var text = ""
            if let instructions, !instructions.isEmpty {
                text += "<start_of_turn>user\n\(instructions)\n\n\(userPrompt)<end_of_turn>\n<start_of_turn>model\n"
            } else {
                text += "<start_of_turn>user\n\(userPrompt)<end_of_turn>\n<start_of_turn>model\n"
            }
            return text
        }
    }
}

nonisolated struct GGUFCatalogEntry: Sendable, Equatable, Identifiable {
    let id: String
    let displayName: String
    let subtitle: String
    /// Hugging Face repo the GGUF is fetched from.
    let huggingFaceRepo: String
    /// Exact filename inside the repo (also the on-disk name).
    let fileName: String
    let approxDownloadBytes: Int64
    /// FP16 KV cache bytes per context token (drives the window math).
    let kvBytesPerToken: Int
    /// Minimum machine RAM to offer this model at all (§2.2 RAM gate).
    let minimumPhysicalMemoryGB: Double
    /// Working-set estimate for the RAM gate: weights + runtime overhead.
    let estimatedWorkingSetGB: Double
    let defaultContextTokens: Int
    let template: GGUFChatTemplateFamily
    let license: String
    let isDefaultDownload: Bool

    var downloadURL: URL {
        URL(string: "https://huggingface.co/\(huggingFaceRepo)/resolve/main/\(fileName)?download=true")!
    }

    /// HF LFS metadata endpoint that carries the file's published sha256
    /// (checksum pinned at download time from the same origin, verified
    /// before install; delete-on-corrupt).
    var metadataURL: URL {
        URL(string: "https://huggingface.co/api/models/\(huggingFaceRepo)/tree/main?recursive=false")!
    }
}

nonisolated enum GGUFModelCatalog {
    /// §9.1 default catalog: Qwen3-4B default · Qwen3-8B stronger · Qwen2.5-7B
    /// long-doc. 14B deferred; Phi dropped (dense-MHA KV trap).
    static let entries: [GGUFCatalogEntry] = [
        GGUFCatalogEntry(
            id: "qwen3-4b-instruct-q4km",
            displayName: "Qwen3 4B",
            subtitle: "Default — best quality per GB for reading and quick answers",
            // Verified 2026-07-03 against the HF API: the official Qwen org
            // publishes the single-file Q4_K_M here; the "-Instruct-2507-GGUF"
            // variant is community-only and would 404.
            huggingFaceRepo: "Qwen/Qwen3-4B-GGUF",
            fileName: "Qwen3-4B-Q4_K_M.gguf",
            approxDownloadBytes: 2_500_000_000,
            kvBytesPerToken: 147_456,
            minimumPhysicalMemoryGB: 8,
            estimatedWorkingSetGB: 3.4,
            defaultContextTokens: 16_384,
            template: .chatML,
            license: "Apache-2.0",
            isDefaultDownload: true
        ),
        GGUFCatalogEntry(
            id: "qwen3-8b-q4km",
            displayName: "Qwen3 8B",
            subtitle: "Stronger answers — the 7B-class flagship",
            huggingFaceRepo: "Qwen/Qwen3-8B-GGUF",
            fileName: "Qwen3-8B-Q4_K_M.gguf",
            approxDownloadBytes: 5_030_000_000,
            kvBytesPerToken: 147_456,
            minimumPhysicalMemoryGB: 16,
            estimatedWorkingSetGB: 6.2,
            defaultContextTokens: 16_384,
            template: .chatML,
            license: "Apache-2.0",
            isDefaultDownload: false
        ),
        GGUFCatalogEntry(
            id: "qwen2.5-7b-instruct-q4km",
            displayName: "Qwen2.5 7B (long documents)",
            subtitle: "Lowest memory per page — reads whole papers comfortably",
            // The official Qwen2.5-7B-Instruct-GGUF ships Q4_K_M SPLIT across
            // two files, which the single-file download manager can't assemble.
            // bartowski publishes a verified single-file Q4_K_M (Apache-2.0
            // weights, MIT quant tooling). Verified 2026-07-03 via HF API.
            huggingFaceRepo: "bartowski/Qwen2.5-7B-Instruct-GGUF",
            fileName: "Qwen2.5-7B-Instruct-Q4_K_M.gguf",
            approxDownloadBytes: 4_680_000_000,
            kvBytesPerToken: 57_344,
            minimumPhysicalMemoryGB: 16,
            estimatedWorkingSetGB: 5.8,
            defaultContextTokens: 32_768,
            template: .chatML,
            license: "Apache-2.0",
            isDefaultDownload: false
        ),
    ]

    static var defaultEntry: GGUFCatalogEntry {
        entries.first(where: \.isDefaultDownload) ?? entries[0]
    }

    static func entry(id: String) -> GGUFCatalogEntry? {
        entries.first { $0.id == id }
    }

    /// Models directory inside the app container (§2.1: self-contained, no
    /// bookmarks needed; never Contents/Frameworks).
    static func modelsDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("QuickChatModels", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func installedURL(for entry: GGUFCatalogEntry) -> URL? {
        guard let directory = try? modelsDirectory() else { return nil }
        let url = directory.appendingPathComponent(entry.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func installedEntries() -> [GGUFCatalogEntry] {
        entries.filter { installedURL(for: $0) != nil }
    }

    // MARK: - RAM gate (§2.2)

    /// Keep ≥4.5 GB headroom for the system; never limp into swap.
    static let systemHeadroomGB = 4.5

    nonisolated static func safelyAvailableGB() -> Double {
        Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824 - systemHeadroomGB
    }

    nonisolated static func ramGate(for entry: GGUFCatalogEntry) -> QuickChatEngineUnavailable? {
        let physicalGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        guard physicalGB >= entry.minimumPhysicalMemoryGB else {
            return .insufficientMemory(
                requiredGB: entry.minimumPhysicalMemoryGB,
                availableGB: physicalGB
            )
        }
        let available = safelyAvailableGB()
        guard entry.estimatedWorkingSetGB <= available else {
            return .insufficientMemory(
                requiredGB: entry.estimatedWorkingSetGB,
                availableGB: max(0, available)
            )
        }
        return nil
    }

    /// Window accounting for the §2.2 refusal rule: given a model + prompt
    /// budget, does the text fit the safe window? "A paper fits; a book needs
    /// chunking."
    nonisolated static func promptFits(
        entry: GGUFCatalogEntry,
        promptTokenEstimate: Int,
        replyBudgetTokens: Int
    ) -> Bool {
        promptTokenEstimate + replyBudgetTokens <= entry.defaultContextTokens
    }
}
