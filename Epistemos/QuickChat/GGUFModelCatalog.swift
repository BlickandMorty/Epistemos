import Foundation

// Plan 1-MAS §2.2 model set — corrected by KV-cache math. Apache-2.0/MIT
// licenses only (no HF license-acceptance gating in the downloader). Sizes
// are Q4_K_M GGUF. KV/token = 2 × layers × kv_heads × head_dim × 2 bytes.

nonisolated enum GGUFChatTemplateFamily: String, Sendable, Equatable {
    /// Qwen (ChatML markers).
    case chatML
    /// Microsoft Phi-3/Phi-3.5 instruct markers.
    case phi3
    /// Gemma-style turns (used by user-imported Gemma files).
    case gemma
    /// TinyLlama/Llama-style chat markers with EOS-terminated turns.
    case llamaChat

    func apply(userPrompt: String, instructions: String?) -> String {
        switch self {
        case .chatML:
            var text = ""
            if let instructions, !instructions.isEmpty {
                text += "<|im_start|>system\n\(instructions)<|im_end|>\n"
            }
            text += "<|im_start|>user\n\(userPrompt)<|im_end|>\n<|im_start|>assistant\n"
            return text
        case .phi3:
            var text = ""
            if let instructions, !instructions.isEmpty {
                text += "<|system|>\n\(instructions)<|end|>\n"
            }
            text += "<|user|>\n\(userPrompt)<|end|>\n<|assistant|>\n"
            return text
        case .gemma:
            var text = ""
            if let instructions, !instructions.isEmpty {
                text += "<start_of_turn>user\n\(instructions)\n\n\(userPrompt)<end_of_turn>\n<start_of_turn>model\n"
            } else {
                text += "<start_of_turn>user\n\(userPrompt)<end_of_turn>\n<start_of_turn>model\n"
            }
            return text
        case .llamaChat:
            var text = ""
            if let instructions, !instructions.isEmpty {
                text += "<|system|>\n\(instructions)</s>\n"
            }
            text += "<|user|>\n\(userPrompt)</s>\n<|assistant|>\n"
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
    /// §9.1 MAS catalog: permissive-license, single-file instruct/chat GGUFs
    /// only. Exact file sizes/licenses were checked against the Hugging Face API
    /// on 2026-07-05; Llama 3.x is deliberately excluded because its custom
    /// Llama license is not Apache/MIT/permissive. TinyLlama Chat is the
    /// permissive Llama-family instruct row.
    static let entries: [GGUFCatalogEntry] = [
        GGUFCatalogEntry(
            id: "qwen3-4b-instruct-q4km",
            displayName: "Qwen3 4B Instruct",
            subtitle: "Default — best quality per GB for reading and quick answers",
            // Verified 2026-07-03 against the HF API: the official Qwen org
            // publishes the single-file Q4_K_M here; the "-Instruct-2507-GGUF"
            // variant is community-only and would 404.
            huggingFaceRepo: "Qwen/Qwen3-4B-GGUF",
            fileName: "Qwen3-4B-Q4_K_M.gguf",
            approxDownloadBytes: 2_497_280_256,
            kvBytesPerToken: 147_456,
            minimumPhysicalMemoryGB: 8,
            estimatedWorkingSetGB: 5.2,
            defaultContextTokens: 16_384,
            template: .chatML,
            license: "Apache-2.0",
            isDefaultDownload: true
        ),
        GGUFCatalogEntry(
            id: "qwen3-8b-q4km",
            displayName: "Qwen3 8B Instruct",
            subtitle: "Stronger answers — the 7B-class flagship",
            huggingFaceRepo: "Qwen/Qwen3-8B-GGUF",
            fileName: "Qwen3-8B-Q4_K_M.gguf",
            approxDownloadBytes: 5_027_783_488,
            kvBytesPerToken: 147_456,
            minimumPhysicalMemoryGB: 16,
            estimatedWorkingSetGB: 7.6,
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
            approxDownloadBytes: 4_683_074_240,
            kvBytesPerToken: 57_344,
            minimumPhysicalMemoryGB: 16,
            estimatedWorkingSetGB: 6.8,
            defaultContextTokens: 32_768,
            template: .chatML,
            license: "Apache-2.0",
            isDefaultDownload: false
        ),
        GGUFCatalogEntry(
            id: "phi-3.5-mini-instruct-q4km",
            displayName: "Phi-3.5 Mini Instruct",
            subtitle: "Compact Microsoft instruct model — fast reasoning with higher KV memory",
            huggingFaceRepo: "bartowski/Phi-3.5-mini-instruct-GGUF",
            fileName: "Phi-3.5-mini-instruct-Q4_K_M.gguf",
            approxDownloadBytes: 2_393_232_672,
            kvBytesPerToken: 393_216,
            minimumPhysicalMemoryGB: 16,
            estimatedWorkingSetGB: 6.3,
            defaultContextTokens: 8_192,
            template: .phi3,
            license: "MIT",
            isDefaultDownload: false
        ),
        GGUFCatalogEntry(
            id: "tinyllama-1.1b-chat-q4km",
            displayName: "TinyLlama 1.1B Chat",
            subtitle: "Smallest permissive Llama-family chat model — fastest download",
            huggingFaceRepo: "TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF",
            fileName: "tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf",
            approxDownloadBytes: 668_788_096,
            kvBytesPerToken: 22_528,
            minimumPhysicalMemoryGB: 8,
            estimatedWorkingSetGB: 1.2,
            defaultContextTokens: 2_048,
            template: .llamaChat,
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
    /// On 16 GB Macs, the app, WebKit, SwiftUI, Codex, and the OS need real
    /// breathing room. Keep GGUF residency to roughly one third of physical RAM
    /// on that class of machine; larger machines can use the normal headroom gate.
    static let constrainedMachineGB = 18.0
    static let constrainedWorkingSetFraction = 0.34

    nonisolated static func safelyAvailableGB() -> Double {
        workingSetLimitGB(
            physicalGB: Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        )
    }

    nonisolated static func workingSetLimitGB(physicalGB: Double) -> Double {
        let headroomAdjusted = physicalGB - systemHeadroomGB
        let residencyAdjusted = physicalGB <= constrainedMachineGB
            ? physicalGB * constrainedWorkingSetFraction
            : headroomAdjusted
        return max(0, min(headroomAdjusted, residencyAdjusted))
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

    /// Conservative tokenizer-free estimate for preflight refusal before
    /// loading model bytes. Real llama.cpp tokenization remains authoritative,
    /// but this catches obvious context explosions on constrained machines.
    nonisolated static func estimatedTokens(for text: String) -> Int {
        max(1, Int((Double(text.count) / 3.5).rounded(.up)))
    }
}
