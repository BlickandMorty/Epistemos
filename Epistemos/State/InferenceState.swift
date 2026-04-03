import Foundation
import Observation
import os

nonisolated enum LocalTextModelID: String, Codable, Sendable, CaseIterable {
    case qwen35_0_8B4Bit = "mlx-community/Qwen3.5-0.8B-4bit"
    case qwen35_2B4Bit = "mlx-community/Qwen3.5-2B-4bit"
    case qwen35_4B4Bit = "mlx-community/Qwen3.5-4B-4bit"
    case qwen35_9B4Bit = "mlx-community/Qwen3.5-9B-4bit"
    case qwen35_27B4Bit = "mlx-community/Qwen3.5-27B-4bit"
    case qwen35_35BA3B4Bit = "mlx-community/Qwen3.5-35B-A3B-4bit"
    case smolLM3_3B4Bit = "mlx-community/SmolLM3-3B-4bit"
    case devstralSmall2505_4Bit = "mlx-community/Devstral-Small-2505-4bit"
    case mistralSmall31_24B4Bit = "mlx-community/Mistral-Small-3.1-24B-Instruct-2503-4bit"
    case gemma3_27BQAT4Bit = "mlx-community/gemma-3-27b-it-qat-4bit"
    case llama4Scout17B16E4Bit = "mlx-community/meta-llama-Llama-4-Scout-17B-16E-4bit"

    var displayName: String {
        switch self {
        case .qwen35_0_8B4Bit: "Qwen 3.5 0.8B 4-bit"
        case .qwen35_2B4Bit: "Qwen 3.5 2B 4-bit"
        case .qwen35_4B4Bit: "Qwen 3.5 4B 4-bit"
        case .qwen35_9B4Bit: "Qwen 3.5 9B 4-bit"
        case .qwen35_27B4Bit: "Qwen 3.5 27B 4-bit"
        case .qwen35_35BA3B4Bit: "Qwen 3.5 35B-A3B 4-bit"
        case .smolLM3_3B4Bit: "SmolLM3 3B 4-bit"
        case .devstralSmall2505_4Bit: "Devstral Small 2505 4-bit"
        case .mistralSmall31_24B4Bit: "Mistral Small 3.1 24B 4-bit"
        case .gemma3_27BQAT4Bit: "Gemma 3 27B QAT 4-bit"
        case .llama4Scout17B16E4Bit: "Llama 4 Scout 17B-16E 4-bit"
        }
    }

    var compactDisplayName: String {
        switch self {
        case .qwen35_0_8B4Bit: "Qwen 0.8B"
        case .qwen35_2B4Bit: "Qwen 2B"
        case .qwen35_4B4Bit: "Qwen 4B"
        case .qwen35_9B4Bit: "Qwen 9B"
        case .qwen35_27B4Bit: "Qwen 27B"
        case .qwen35_35BA3B4Bit: "Qwen 35B"
        case .smolLM3_3B4Bit: "SmolLM3"
        case .devstralSmall2505_4Bit: "Devstral"
        case .mistralSmall31_24B4Bit: "Mistral 24B"
        case .gemma3_27BQAT4Bit: "Gemma 27B"
        case .llama4Scout17B16E4Bit: "Llama 4"
        }
    }

    var familyName: String {
        switch self {
        case .qwen35_0_8B4Bit,
             .qwen35_2B4Bit,
             .qwen35_4B4Bit,
             .qwen35_9B4Bit,
             .qwen35_27B4Bit,
             .qwen35_35BA3B4Bit:
            "Qwen 3.5"
        case .smolLM3_3B4Bit:
            "SmolLM3"
        case .devstralSmall2505_4Bit:
            "Devstral"
        case .mistralSmall31_24B4Bit:
            "Mistral"
        case .gemma3_27BQAT4Bit:
            "Gemma 3"
        case .llama4Scout17B16E4Bit:
            "Llama 4"
        }
    }

    var minimumRecommendedMemoryGB: Int {
        switch self {
        case .qwen35_0_8B4Bit: 8
        case .qwen35_2B4Bit: 12
        case .qwen35_4B4Bit: 16
        case .qwen35_9B4Bit: 24
        case .qwen35_27B4Bit: 48
        case .qwen35_35BA3B4Bit: 64
        case .smolLM3_3B4Bit: 8
        case .devstralSmall2505_4Bit: 24
        case .mistralSmall31_24B4Bit: 24
        case .gemma3_27BQAT4Bit: 24
        case .llama4Scout17B16E4Bit: 64
        }
    }

    nonisolated static var ascendingBySize: [LocalTextModelID] {
        allCases.sorted { lhs, rhs in
            if lhs.minimumRecommendedMemoryGB == rhs.minimumRecommendedMemoryGB {
                return lhs.rawValue < rhs.rawValue
            }
            return lhs.minimumRecommendedMemoryGB < rhs.minimumRecommendedMemoryGB
        }
    }

    var supportsThinkingMode: Bool {
        switch self {
        case .qwen35_4B4Bit,
             .qwen35_27B4Bit,
             .qwen35_35BA3B4Bit:
            true
        case .qwen35_0_8B4Bit,
             .qwen35_2B4Bit,
             .qwen35_9B4Bit,
             .smolLM3_3B4Bit,
             .devstralSmall2505_4Bit,
             .mistralSmall31_24B4Bit,
             .gemma3_27BQAT4Bit,
             .llama4Scout17B16E4Bit:
            false
        }
    }

    var canActAsAgent: Bool {
        switch self {
        case .qwen35_4B4Bit,
             .qwen35_27B4Bit,
             .qwen35_35BA3B4Bit,
             .devstralSmall2505_4Bit,
             .mistralSmall31_24B4Bit,
             .gemma3_27BQAT4Bit:
            true
        case .qwen35_0_8B4Bit,
             .qwen35_2B4Bit,
             .qwen35_9B4Bit,
             .smolLM3_3B4Bit,
             .llama4Scout17B16E4Bit:
            false
        }
    }
}

nonisolated enum CloudModelProvider: String, Codable, Sendable, CaseIterable {
    case openAI
    case anthropic
    case google

    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .google: "Google"
        }
    }

    var apiKeyKeychainKey: String {
        switch self {
        case .openAI: "epistemos.openai.apiKey"
        case .anthropic: "epistemos.anthropic.apiKey"
        case .google: "epistemos.google.apiKey"
        }
    }

    var legacyAPIKeyKeychainKeys: [String] {
        switch self {
        case .openAI:
            ["epistemos.apiKey.openai"]
        case .anthropic:
            ["epistemos.apiKey.anthropic"]
        case .google:
            ["epistemos.apiKey.google"]
        }
    }
}

nonisolated enum AIProviderSelection: String, Codable, Sendable, CaseIterable {
    case openAI
    case anthropic
    case google
    case localOnly

    init(cloudProvider: CloudModelProvider) {
        switch cloudProvider {
        case .openAI:
            self = .openAI
        case .anthropic:
            self = .anthropic
        case .google:
            self = .google
        }
    }

    var cloudProvider: CloudModelProvider? {
        switch self {
        case .openAI:
            .openAI
        case .anthropic:
            .anthropic
        case .google:
            .google
        case .localOnly:
            nil
        }
    }

    var displayName: String {
        switch self {
        case .openAI:
            "OpenAI"
        case .anthropic:
            "Anthropic"
        case .google:
            "Google"
        case .localOnly:
            "Local Only"
        }
    }

    var systemImage: String {
        switch self {
        case .openAI:
            "sparkles"
        case .anthropic:
            "brain"
        case .google:
            "globe.americas.fill"
        case .localOnly:
            "memorychip"
        }
    }

    var summary: String {
        switch self {
        case .openAI:
            "Use OpenAI as the single active cloud provider while keeping local models available."
        case .anthropic:
            "Use Anthropic as the single active cloud provider while keeping local models available."
        case .google:
            "Use Google as the single active cloud provider while keeping local models available."
        case .localOnly:
            "Hide cloud models from the picker and stay on-device with Apple Intelligence plus local models."
        }
    }
}

nonisolated enum CloudTextModelID: String, Codable, Sendable, CaseIterable {
    case openAIGPT54 = "openai:gpt-5.4"
    case openAIGPT54Mini = "openai:gpt-5.4-mini"
    case openAIGPT54Nano = "openai:gpt-5.4-nano"
    case openAIGPT52 = "openai:gpt-5.2"
    case openAIGPT41 = "openai:gpt-4.1"
    case openAIGPT41Mini = "openai:gpt-4.1-mini"
    case openAIO3 = "openai:o3"
    case openAIO3Mini = "openai:o3-mini"
    case anthropicClaudeOpus41 = "anthropic:claude-opus-4-1"
    case anthropicClaudeOpus4 = "anthropic:claude-opus-4"
    case anthropicClaudeSonnet4 = "anthropic:claude-sonnet-4"
    case anthropicClaudeSonnet37 = "anthropic:claude-3-7-sonnet"
    case anthropicClaudeHaiku35 = "anthropic:claude-3-5-haiku"
    case googleGemini25Pro = "google:gemini-2.5-pro"
    case googleGemini25Flash = "google:gemini-2.5-flash"
    case googleGemini3FlashPreview = "google:gemini-3-flash-preview"
    case googleGemini3ProPreview = "google:gemini-3-pro-preview"
    case googleGemini31ProPreview = "google:gemini-3.1-pro-preview"

    var provider: CloudModelProvider {
        switch self {
        case .openAIGPT54, .openAIGPT54Mini, .openAIGPT54Nano, .openAIGPT52, .openAIGPT41,
             .openAIGPT41Mini, .openAIO3, .openAIO3Mini:
            .openAI
        case .anthropicClaudeOpus41, .anthropicClaudeOpus4, .anthropicClaudeSonnet4,
             .anthropicClaudeSonnet37, .anthropicClaudeHaiku35:
            .anthropic
        case .googleGemini25Pro, .googleGemini25Flash, .googleGemini3FlashPreview,
             .googleGemini3ProPreview, .googleGemini31ProPreview:
            .google
        }
    }

    var vendorModelID: String {
        switch self {
        case .openAIGPT54: "gpt-5.4"
        case .openAIGPT54Mini: "gpt-5.4-mini"
        case .openAIGPT54Nano: "gpt-5.4-nano"
        case .openAIGPT52: "gpt-5.2"
        case .openAIGPT41: "gpt-4.1"
        case .openAIGPT41Mini: "gpt-4.1-mini"
        case .openAIO3: "o3"
        case .openAIO3Mini: "o3-mini"
        case .anthropicClaudeOpus41: "claude-opus-4-1-20250805"
        case .anthropicClaudeOpus4: "claude-opus-4-20250514"
        case .anthropicClaudeSonnet4: "claude-sonnet-4-20250514"
        case .anthropicClaudeSonnet37: "claude-3-7-sonnet-20250219"
        case .anthropicClaudeHaiku35: "claude-3-5-haiku-latest"
        case .googleGemini25Pro: "gemini-2.5-pro"
        case .googleGemini25Flash: "gemini-2.5-flash"
        case .googleGemini3FlashPreview: "gemini-3-flash-preview"
        case .googleGemini3ProPreview: "gemini-3-pro-preview"
        case .googleGemini31ProPreview: "gemini-3.1-pro-preview"
        }
    }

    var displayName: String {
        switch self {
        case .openAIGPT54: "GPT-5.4"
        case .openAIGPT54Mini: "GPT-5.4 Mini"
        case .openAIGPT54Nano: "GPT-5.4 Nano"
        case .openAIGPT52: "GPT-5.2"
        case .openAIGPT41: "GPT-4.1"
        case .openAIGPT41Mini: "GPT-4.1 Mini"
        case .openAIO3: "o3"
        case .openAIO3Mini: "o3-mini"
        case .anthropicClaudeOpus41: "Claude Opus 4.1 (Latest Opus)"
        case .anthropicClaudeOpus4: "Claude Opus 4"
        case .anthropicClaudeSonnet4: "Claude Sonnet 4 (Latest Sonnet)"
        case .anthropicClaudeSonnet37: "Claude Sonnet 3.7"
        case .anthropicClaudeHaiku35: "Claude Haiku 3.5 (Latest Haiku)"
        case .googleGemini25Pro: "Gemini 2.5 Pro"
        case .googleGemini25Flash: "Gemini 2.5 Flash"
        case .googleGemini3FlashPreview: "Gemini 3 Flash Preview"
        case .googleGemini3ProPreview: "Gemini 3 Pro Preview"
        case .googleGemini31ProPreview: "Gemini 3.1 Pro Preview"
        }
    }

    var compactDisplayName: String {
        switch self {
        case .openAIGPT54: "GPT-5.4"
        case .openAIGPT54Mini: "GPT-5.4 Mini"
        case .openAIGPT54Nano: "GPT-5.4 Nano"
        case .openAIGPT52: "GPT-5.2"
        case .openAIGPT41: "GPT-4.1"
        case .openAIGPT41Mini: "GPT-4.1 Mini"
        case .openAIO3: "o3"
        case .openAIO3Mini: "o3-mini"
        case .anthropicClaudeOpus41: "Opus 4.1"
        case .anthropicClaudeOpus4: "Opus 4"
        case .anthropicClaudeSonnet4: "Sonnet 4"
        case .anthropicClaudeSonnet37: "Sonnet 3.7"
        case .anthropicClaudeHaiku35: "Haiku 3.5"
        case .googleGemini25Pro: "Gemini 2.5 Pro"
        case .googleGemini25Flash: "Gemini 2.5 Flash"
        case .googleGemini3FlashPreview: "Gemini 3 Flash"
        case .googleGemini3ProPreview: "Gemini 3 Pro"
        case .googleGemini31ProPreview: "Gemini 3.1 Pro"
        }
    }

    var providerDisplayName: String {
        provider.displayName
    }

    nonisolated static func models(for provider: CloudModelProvider) -> [CloudTextModelID] {
        allCases.filter { $0.provider == provider }
    }

    nonisolated static func from(rawValueOrVendorID value: String) -> CloudTextModelID? {
        if let direct = CloudTextModelID(rawValue: value) {
            return direct
        }

        if let exactVendorMatch = allCases.first(where: { $0.vendorModelID == value }) {
            return exactVendorMatch
        }

        return legacyMigrationMap[value]
    }

    private nonisolated static let legacyMigrationMap: [String: CloudTextModelID] = [
        "gpt-5.3": .openAIGPT54,
        "gpt-5.2": .openAIGPT52,
        "gpt-5.1": .openAIGPT52,
        "gpt-4.1": .openAIGPT41,
        "gpt-4.1-mini": .openAIGPT41Mini,
        "o1-pro": .openAIO3,
        "o3": .openAIO3,
        "o3-mini": .openAIO3Mini,
        "claude-opus-4-6": .anthropicClaudeOpus41,
        "claude-opus-4-1": .anthropicClaudeOpus41,
        "claude-opus-4-20250514": .anthropicClaudeOpus4,
        "claude-sonnet-4-6": .anthropicClaudeSonnet4,
        "claude-sonnet-4-5": .anthropicClaudeSonnet4,
        "claude-sonnet-4-5-20250929": .anthropicClaudeSonnet4,
        "claude-sonnet-4-20250514": .anthropicClaudeSonnet4,
        "claude-3-7-sonnet-20250219": .anthropicClaudeSonnet37,
        "claude-haiku-4-5-20251001": .anthropicClaudeHaiku35,
        "claude-3-5-haiku-latest": .anthropicClaudeHaiku35,
        "gemini-1.5-pro": .googleGemini25Pro,
        "gemini-1.5-flash": .googleGemini25Flash,
        "gemini-2.0-flash": .googleGemini25Flash,
        "gemini-2.0-flash-lite": .googleGemini25Flash,
        "gemini-2.5-pro": .googleGemini25Pro,
        "gemini-2.5-flash": .googleGemini25Flash,
        "gemini-3-flash-preview": .googleGemini3FlashPreview,
        "gemini-3-pro-preview": .googleGemini3ProPreview,
        "gemini-3.1-pro-preview": .googleGemini31ProPreview,
    ]
}

nonisolated enum CloudProviderValidationState: Sendable, Equatable {
    case missing
    case unchecked
    case checking
    case valid(message: String, checkedAt: Date)
    case invalid(message: String, checkedAt: Date)

    var isChecking: Bool {
        if case .checking = self {
            return true
        }
        return false
    }

    var statusBadge: String {
        switch self {
        case .missing:
            "No Key"
        case .unchecked:
            "Saved"
        case .checking:
            "Checking"
        case .valid:
            "Valid"
        case .invalid:
            "Needs Attention"
        }
    }

    var statusText: String {
        return switch self {
        case .missing:
            "Add a provider key to unlock these cloud models."
        case .unchecked:
            "Key saved. Run a check to confirm provider access."
        case .checking:
            "Checking this provider with a lightweight live request…"
        case .valid(let message, let checkedAt):
            "\(message) • Checked \(checkedAt.formatted(date: .omitted, time: .shortened))"
        case .invalid(let message, let checkedAt):
            "\(message) • Checked \(checkedAt.formatted(date: .omitted, time: .shortened))"
        }
    }

    var systemImage: String {
        switch self {
        case .missing:
            "key.slash"
        case .unchecked:
            "key.fill"
        case .checking:
            "arrow.triangle.2.circlepath"
        case .valid:
            "checkmark.shield.fill"
        case .invalid:
            "exclamationmark.triangle.fill"
        }
    }

    var tintColor: ColorRole {
        switch self {
        case .missing:
            .secondary
        case .unchecked, .checking:
            .accent
        case .valid:
            .success
        case .invalid:
            .warning
        }
    }
}

nonisolated enum ColorRole: Sendable, Equatable {
    case accent
    case secondary
    case success
    case warning
}

extension CloudModelProvider {
    var systemImage: String {
        switch self {
        case .openAI:
            "sparkles"
        case .anthropic:
            "brain"
        case .google:
            "globe.americas.fill"
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .openAI:
            "sk-..."
        case .anthropic:
            "sk-ant-..."
        case .google:
            "AIza..."
        }
    }

    var setupHelpText: String {
        switch self {
        case .openAI:
            "Unlocks GPT-5.4, GPT-5.2, GPT-4.1, and o3. Great default for general cloud chat."
        case .anthropic:
            "Unlocks Claude Sonnet and Opus models. Best fit when you want a strong agentic writing partner."
        case .google:
            "Unlocks Gemini 2.5 and preview Gemini 3 models. Useful for broad long-context work."
        }
    }

    var modelSummary: String {
        switch self {
        case .openAI:
            "GPT-5.4, GPT-5.2, GPT-4.1, o3"
        case .anthropic:
            "Claude Opus 4.1, Opus 4, Sonnet 4"
        case .google:
            "Gemini 2.5 Pro, 2.5 Flash, Gemini 3 previews"
        }
    }

    var validationModel: CloudTextModelID {
        switch self {
        case .openAI:
            .openAIGPT41Mini
        case .anthropic:
            .anthropicClaudeSonnet4
        case .google:
            .googleGemini25Flash
        }
    }

    var defaultChatModel: CloudTextModelID {
        switch self {
        case .openAI:
            .openAIGPT54
        case .anthropic:
            .anthropicClaudeSonnet4
        case .google:
            .googleGemini25Pro
        }
    }
}

nonisolated enum ChatModelSelection: Codable, Sendable, Equatable {
    case appleIntelligence
    case localQwen(String)
    case cloud(CloudTextModelID)

    init?(rawValue: String) {
        if rawValue == "apple-intelligence" {
            self = .appleIntelligence
            return
        }
        if rawValue.hasPrefix("cloud:") {
            let cloudRawValue = String(rawValue.dropFirst("cloud:".count))
            let legacyVendorModelID = cloudRawValue.split(separator: ":", maxSplits: 1).last.map(String.init)
            guard let model = CloudTextModelID.from(rawValueOrVendorID: cloudRawValue)
                ?? legacyVendorModelID.flatMap(CloudTextModelID.from(rawValueOrVendorID:))
            else { return nil }
            self = .cloud(model)
            return
        }
        guard LocalTextModelID(rawValue: rawValue) != nil else { return nil }
        self = .localQwen(rawValue)
    }

    var rawValue: String {
        switch self {
        case .appleIntelligence:
            "apple-intelligence"
        case .localQwen(let modelID):
            modelID
        case .cloud(let model):
            "cloud:\(model.rawValue)"
        }
    }

    var displayName: String {
        switch self {
        case .appleIntelligence:
            "Apple Intelligence"
        case .localQwen(let modelID):
            LocalTextModelID(rawValue: modelID)?.displayName ?? modelID
        case .cloud(let model):
            model.displayName
        }
    }

    var compactDisplayName: String {
        switch self {
        case .appleIntelligence:
            "Apple Intelligence"
        case .localQwen(let modelID):
            LocalTextModelID(rawValue: modelID)?.compactDisplayName ?? modelID
        case .cloud(let model):
            model.compactDisplayName
        }
    }
}

nonisolated enum LocalRoutingMode: String, Codable, Sendable, CaseIterable {
    case auto
    case localOnly

    var displayName: String {
        switch self {
        case .auto: "Auto"
        case .localOnly: "Local Only"
        }
    }

    var summary: String {
        switch self {
        case .auto:
            "Apple Intelligence handles the lightest local work. Installed local models handle deeper tasks."
        case .localOnly:
            "Always use an installed local model. Apple Intelligence is bypassed."
        }
    }
}

nonisolated enum LocalReasoningMode: String, Codable, Sendable, CaseIterable {
    case fast
    case thinking

    var displayName: String {
        switch self {
        case .fast: "Fast"
        case .thinking: "Thinking"
        }
    }
}

nonisolated enum EpistemosOperatingMode: String, Codable, Sendable, CaseIterable {
    case fast
    case thinking
    case agent

    var displayName: String {
        switch self {
        case .fast: "Fast"
        case .thinking: "Thinking"
        case .agent: "Agent"
        }
    }

    var systemImage: String {
        switch self {
        case .fast: "bolt.fill"
        case .thinking: "brain.head.profile"
        case .agent: "cpu.fill"
        }
    }

    var helpText: String {
        switch self {
        case .fast:
            "Quick local replies with the lightest reasoning overhead."
        case .thinking:
            "Spend more local reasoning budget before answering."
        case .agent:
            "Hand off the task to the agent runtime for visible multi-step execution."
        }
    }

    var localReasoningMode: LocalReasoningMode? {
        switch self {
        case .fast: .fast
        case .thinking: .thinking
        case .agent: nil
        }
    }

    var handoffMessage: String? {
        switch self {
        case .agent:
            "Handing this off to the agent runtime for multi-step execution. Follow progress in the Agent Runtime panel."
        case .fast, .thinking:
            nil
        }
    }
}

nonisolated struct OperatingModeCapabilities: Sendable, Equatable {
    let availableModes: [EpistemosOperatingMode]

    var supportsThinking: Bool {
        availableModes.contains(.thinking)
    }
}

nonisolated enum LocalModelInstallStateSummary: String, Codable, Sendable {
    case none
    case installed

    var displayName: String {
        switch self {
        case .none: "None"
        case .installed: "Installed"
        }
    }
}

nonisolated enum LocalRuntimeThermalState: String, Codable, Sendable, Equatable {
    case nominal
    case fair
    case serious
    case critical

    init(_ thermalState: ProcessInfo.ThermalState) {
        switch thermalState {
        case .nominal:
            self = .nominal
        case .fair:
            self = .fair
        case .serious:
            self = .serious
        case .critical:
            self = .critical
        @unknown default:
            self = .serious
        }
    }

    var isSeverelyConstrained: Bool {
        switch self {
        case .serious, .critical:
            true
        case .nominal, .fair:
            false
        }
    }
}

nonisolated struct LocalRuntimeConditions: Sendable, Equatable {
    let lowPowerModeEnabled: Bool
    let appActive: Bool
    let thermalState: LocalRuntimeThermalState

    static func current(appActive: Bool = true) -> LocalRuntimeConditions {
        let systemLPM = ProcessInfo.processInfo.isLowPowerModeEnabled
        let ecoToggle = UserDefaults.standard.bool(forKey: "epistemos.ecoMode")
        return LocalRuntimeConditions(
            lowPowerModeEnabled: systemLPM || ecoToggle,
            appActive: appActive,
            thermalState: LocalRuntimeThermalState(ProcessInfo.processInfo.thermalState)
        )
    }

    var prefersConstrainedLocalModel: Bool {
        lowPowerModeEnabled || !appActive || thermalState != .nominal
    }

    var allowsAutomaticLocalRouting: Bool {
        appActive && thermalState != .critical
    }
}

nonisolated enum LocalModelSelectionSurface: String, Sendable, Equatable {
    case mainChat
    case miniChat
    case noteChat
    case graph
}

nonisolated struct LocalModelSelection: Sendable, Equatable {
    let modelID: String
    let reasoningMode: LocalReasoningMode
    let contentBudget: Int

    var canActAsAgent: Bool {
        guard let model = LocalTextModelID(rawValue: modelID) else {
            return false
        }
        return model.canActAsAgent
    }
}

nonisolated struct LocalHardwareCapabilitySnapshot: Sendable, Equatable {
    let physicalMemoryBytes: UInt64
    let roundedMemoryGB: Int
    let maxRecommendedLocalContentLength: Int

    static var current: LocalHardwareCapabilitySnapshot {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let roundedGB = max(8, Int((physicalMemory + 999_999_999) / 1_000_000_000))
        let maxContentLength: Int
        switch roundedGB {
        case ..<16:
            maxContentLength = 4_000
        case ..<24:
            maxContentLength = 10_000
        case ..<36:
            maxContentLength = 18_000
        default:
            maxContentLength = 28_000
        }
        return LocalHardwareCapabilitySnapshot(
            physicalMemoryBytes: physicalMemory,
            roundedMemoryGB: roundedGB,
            maxRecommendedLocalContentLength: maxContentLength
        )
    }

    nonisolated func supports(textModelID: String) -> Bool {
        guard let model = LocalTextModelID(rawValue: textModelID) else { return false }
        return roundedMemoryGB >= model.minimumRecommendedMemoryGB
    }

    nonisolated var recommendedLocalTextModelID: LocalTextModelID {
        switch roundedMemoryGB {
        case ..<12:
            .qwen35_0_8B4Bit
        case ..<16:
            .qwen35_2B4Bit
        case ..<24:
            .qwen35_4B4Bit
        case ..<48:
            .qwen35_9B4Bit
        case ..<64:
            .qwen35_27B4Bit
        default:
            .qwen35_35BA3B4Bit
        }
    }

    nonisolated func smallerLocalTextModelID(than modelID: LocalTextModelID) -> LocalTextModelID? {
        guard let index = LocalTextModelID.ascendingBySize.firstIndex(of: modelID),
              index > 0 else {
            return nil
        }
        return LocalTextModelID.ascendingBySize[index - 1]
    }

    nonisolated var recommendedConstrainedLocalTextModelID: LocalTextModelID? {
        smallerLocalTextModelID(than: recommendedLocalTextModelID)
    }

    nonisolated var baseLocalRuntimeContentLength: Int {
        switch roundedMemoryGB {
        case ..<12:
            3_200
        case ..<16:
            4_800
        case ..<24:
            8_000
        case ..<36:
            12_000
        default:
            min(maxRecommendedLocalContentLength, 22_000)
        }
    }

    nonisolated func recommendedLocalTextModelID(for conditions: LocalRuntimeConditions) -> LocalTextModelID {
        let baseline = recommendedLocalTextModelID
        guard conditions.prefersConstrainedLocalModel,
              let constrained = smallerLocalTextModelID(than: baseline) else {
            return baseline
        }
        return constrained
    }

    nonisolated func recommendedLocalContentLength(
        for conditions: LocalRuntimeConditions,
        reasoningMode: LocalReasoningMode = .fast
    ) -> Int {
        _ = reasoningMode
        var total = min(maxRecommendedLocalContentLength, baseLocalRuntimeContentLength)
        if conditions.lowPowerModeEnabled {
            total = Int(Double(total) * 0.82)
        }
        if !conditions.appActive {
            total = Int(Double(total) * 0.72)
        }
        switch conditions.thermalState {
        case .nominal:
            break
        case .fair:
            total = Int(Double(total) * 0.92)
        case .serious:
            total = Int(Double(total) * 0.75)
        case .critical:
            total = Int(Double(total) * 0.60)
        }
        return max(1_800, total)
    }
}

// MARK: - Inference State
// Manages chat model availability and selection: Apple Intelligence,
// local models, cloud providers, and runtime conditions.

@MainActor @Observable
final class InferenceState {
    private nonisolated static let legacyRemoteDefaultsKeys = [
        "epistemos.apiProvider",
        "epistemos.kimiModel",
        "epistemos.ollamaBaseUrl",
        "epistemos.ollamaModel",
        "epistemos.preferredVoiceEngineID",
        "epistemos.preferredVoiceID",
        "epistemos.localAutoDownloadEnabled",
        "epistemos.smartRoutingEnabled",
        "epistemos.offlineOnlyEnabled",
        "epistemos.preferredFallbackLocalTextModelID",
    ]
    private nonisolated static let activeAIProviderDefaultsKey = "epistemos.activeAIProvider"

    var inferenceMode: InferenceMode = .api
    var routingMode: LocalRoutingMode = .auto
    var preferredLocalTextModelID: String = LocalHardwareCapabilitySnapshot.current.recommendedLocalTextModelID.rawValue
    var preferredChatModelSelection: ChatModelSelection = .localQwen(
        LocalHardwareCapabilitySnapshot.current.recommendedLocalTextModelID.rawValue
    )
    var activeAIProvider: AIProviderSelection = .openAI
    private let keychainLoad: (String) -> String?
    private let keychainSave: (String, String) -> Bool
    private let keychainDelete: (String) -> Void
    private(set) var cachedCloudAPIKeys: [CloudModelProvider: String] = [:]
    private var missingCloudAPIKeyProviders: Set<CloudModelProvider> = []
    private(set) var cloudProviderValidationStates: [CloudModelProvider: CloudProviderValidationState] = [:]
    private(set) var installedLocalTextModelIDs: Set<String> = []
    private(set) var localRuntimeConditions: LocalRuntimeConditions = .current()
    let hardwareCapabilitySnapshot: LocalHardwareCapabilitySnapshot = .current
    private let policyEngine = InferencePolicyEngine()

    var appleIntelligenceAvailable: Bool = false
    var appleIntelligenceUnavailableReason: String?

    /// Max tokens for user-visible chat responses. 0 = no cap (model default, ~16k).
    var chatOutputTokens: Int = 0

    init(
        keychainLoad: @escaping (String) -> String? = { Keychain.load(for: $0) },
        keychainSave: @escaping (String, String) -> Bool = { value, key in
            Keychain.save(value, for: key)
        },
        keychainDelete: @escaping (String) -> Void = { Keychain.delete(for: $0) }
    ) {
        self.keychainLoad = keychainLoad
        self.keychainSave = keychainSave
        self.keychainDelete = keychainDelete

        let (available, reason) = AppleIntelligenceService.shared.checkAvailability()
        self.appleIntelligenceAvailable = available
        self.appleIntelligenceUnavailableReason = reason
        migrateLegacyCloudAPIKeysIfNeeded()
        refreshCachedCloudAPIKeys()

        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: "epistemos.localRoutingMode"),
           let mode = LocalRoutingMode(rawValue: saved) {
            self.routingMode = mode
        } else if defaults.object(forKey: "epistemos.offlineOnlyEnabled") != nil,
                  defaults.bool(forKey: "epistemos.offlineOnlyEnabled") {
            self.routingMode = .localOnly
        }
        if let saved = defaults.string(forKey: "epistemos.preferredLocalTextModelID"),
           LocalTextModelID(rawValue: saved) != nil {
            self.preferredLocalTextModelID = saved
        }
        if let saved = defaults.string(forKey: "epistemos.preferredChatModelSelection"),
           let selection = ChatModelSelection(rawValue: saved) {
            // If the saved selection is a cloud model but there's no API key for it,
            // fall back to local Qwen to avoid unusable cloud routing.
            if case .cloud(let model) = selection, apiKey(for: model.provider) == nil {
                self.preferredChatModelSelection = .localQwen(preferredLocalTextModelID)
            } else {
                self.preferredChatModelSelection = selection
            }
        } else if let migratedSelection = Self.migrateLegacyCloudSelection(defaults: defaults) {
            self.preferredChatModelSelection = migratedSelection
            defaults.set(
                migratedSelection.rawValue,
                forKey: "epistemos.preferredChatModelSelection"
            )
        } else {
            self.preferredChatModelSelection = .localQwen(preferredLocalTextModelID)
        }
        if let savedProvider = defaults.string(forKey: Self.activeAIProviderDefaultsKey),
           let provider = AIProviderSelection(rawValue: savedProvider) {
            self.activeAIProvider = provider
        } else if case .cloud(let model) = self.preferredChatModelSelection {
            self.activeAIProvider = AIProviderSelection(cloudProvider: model.provider)
        } else {
            self.activeAIProvider = .openAI
        }
        if case .cloud(let model) = self.preferredChatModelSelection {
            persistPreferredCloudModel(model, defaults: defaults)
            if activeAIProvider == .localOnly {
                self.preferredChatModelSelection = .localQwen(preferredLocalTextModelID)
            } else if activeAIProvider.cloudProvider != model.provider {
                self.activeAIProvider = AIProviderSelection(cloudProvider: model.provider)
            }
        }
        self.chatOutputTokens = defaults.integer(forKey: "epistemos.chatOutputTokens")  // 0 if unset

        Self.purgeLegacyRemoteConfiguration(defaults: defaults)
    }

    static func purgeLegacyRemoteConfiguration(defaults: UserDefaults = .standard) {
        for key in legacyRemoteDefaultsKeys {
            defaults.removeObject(forKey: key)
        }
    }

    private func migrateLegacyCloudAPIKeysIfNeeded() {
        for provider in CloudModelProvider.allCases {
            if let existing = apiKey(for: provider)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !existing.isEmpty {
                continue
            }

            for legacyKey in provider.legacyAPIKeyKeychainKeys {
                guard let legacyValue = keychainLoad(legacyKey)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !legacyValue.isEmpty else {
                    continue
                }

                guard setAPIKey(legacyValue, for: provider) else { break }
                keychainDelete(legacyKey)
                break
            }
        }
    }

    private func refreshCachedCloudAPIKeys() {
        missingCloudAPIKeyProviders.removeAll()
        cachedCloudAPIKeys = CloudModelProvider.allCases.reduce(into: [:]) { partialResult, provider in
            guard let key = keychainLoad(provider.apiKeyKeychainKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !key.isEmpty else {
                missingCloudAPIKeyProviders.insert(provider)
                return
            }
            partialResult[provider] = key
        }

        cloudProviderValidationStates = CloudModelProvider.allCases.reduce(into: [:]) { partialResult, provider in
            partialResult[provider] = cachedCloudAPIKeys[provider] == nil ? .missing : .unchecked
        }
    }

    private nonisolated static func migrateLegacyCloudSelection(
        defaults: UserDefaults
    ) -> ChatModelSelection? {
        guard let legacyProvider = defaults.string(forKey: "epistemos.apiProvider")?.lowercased() else {
            return nil
        }

        let modelKey: String
        switch legacyProvider {
        case "openai":
            modelKey = "epistemos.openaiModel"
        case "anthropic":
            modelKey = "epistemos.anthropicModel"
        case "google":
            modelKey = "epistemos.googleModel"
        default:
            return nil
        }

        guard let legacyModel = defaults.string(forKey: modelKey),
              let model = CloudTextModelID.from(rawValueOrVendorID: legacyModel) else {
            return nil
        }
        return .cloud(model)
    }

    private nonisolated static func preferredCloudModelDefaultsKey(
        for provider: CloudModelProvider
    ) -> String {
        "epistemos.preferredCloudModel.\(provider.rawValue)"
    }

    private func loadPreferredCloudModel(for provider: CloudModelProvider) -> CloudTextModelID {
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: Self.preferredCloudModelDefaultsKey(for: provider)),
           let model = CloudTextModelID.from(rawValueOrVendorID: saved),
           model.provider == provider {
            return model
        }
        return provider.defaultChatModel
    }

    private func persistPreferredCloudModel(
        _ model: CloudTextModelID,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(
            model.rawValue,
            forKey: Self.preferredCloudModelDefaultsKey(for: model.provider)
        )
    }

    private func persistActiveAIProvider(
        _ provider: AIProviderSelection,
        defaults: UserDefaults = .standard
    ) {
        activeAIProvider = provider
        defaults.set(provider.rawValue, forKey: Self.activeAIProviderDefaultsKey)
    }

    func setInferenceMode(_ mode: InferenceMode) { inferenceMode = mode }

    var localModelInstallStateSummary: LocalModelInstallStateSummary {
        installedLocalTextModelIDs.isEmpty ? .none : .installed
    }

    var policyContext: InferencePolicyContext {
        InferencePolicyContext(
            routingMode: routingMode,
            appleIntelligenceAvailable: appleIntelligenceAvailable,
            preferredChatModelSelection: preferredChatModelSelection,
            preferredLocalTextModelID: preferredLocalTextModelID,
            installedLocalTextModelIDs: installedLocalTextModelIDs,
            hardwareCapabilitySnapshot: hardwareCapabilitySnapshot,
            runtimeConditions: localRuntimeConditions
        )
    }

    private var supportedInstalledLocalTextModels: [LocalTextModelID] {
        installedLocalTextModelIDs
            .compactMap(LocalTextModelID.init(rawValue:))
            .filter { hardwareCapabilitySnapshot.supports(textModelID: $0.rawValue) }
            .sorted { lhs, rhs in
                if lhs.minimumRecommendedMemoryGB == rhs.minimumRecommendedMemoryGB {
                    return lhs.rawValue < rhs.rawValue
                }
                return lhs.minimumRecommendedMemoryGB < rhs.minimumRecommendedMemoryGB
            }
    }

    var effectiveLocalTextModelID: String? {
        policyEngine.resolvedPreferredLocalSelection(in: policyContext)?.modelID
    }

    var hasUsableLocalTextModel: Bool {
        effectiveLocalTextModelID != nil
    }

    var supportsLocalAgentLoop: Bool {
        guard let modelID = activeLocalTextModelID,
              let model = LocalTextModelID(rawValue: modelID) else {
            return false
        }

        return model.canActAsAgent
    }

    var operatingModeCapabilities: OperatingModeCapabilities {
        switch preferredChatModelSelection {
        case .appleIntelligence:
            // Apple Intelligence has no agent capability — fast only.
            return OperatingModeCapabilities(availableModes: [.fast])
        case .cloud:
            // Cloud models always support Hermes agent mode.
            return OperatingModeCapabilities(availableModes: [.fast, .agent])
        case .localQwen(let modelID):
            let activeModelID = LocalTextModelID(rawValue: modelID) != nil ? modelID : activeLocalTextModelID
            guard let activeModelID,
                  let model = LocalTextModelID(rawValue: activeModelID) else {
                return OperatingModeCapabilities(availableModes: [.fast])
            }
            // Only models explicitly marked canActAsAgent get the agent option.
            var modes: [EpistemosOperatingMode] = [.fast]
            if model.supportsThinkingMode {
                modes.append(.thinking)
            }
            if model.canActAsAgent {
                modes.append(.agent)
            }
            return OperatingModeCapabilities(availableModes: modes)
        }
    }

    var availableOperatingModes: [EpistemosOperatingMode] {
        operatingModeCapabilities.availableModes
    }

    var supportsThinkingOperatingMode: Bool {
        operatingModeCapabilities.supportsThinking
    }

    func sanitizedOperatingMode(_ mode: EpistemosOperatingMode) -> EpistemosOperatingMode {
        guard availableOperatingModes.contains(mode) else {
            return availableOperatingModes.first ?? .fast
        }
        return mode
    }

    var activeLocalTextModelID: String? {
        return effectiveLocalTextModelID
    }

    var activeLocalTextModelDisplayName: String {
        guard let modelID = activeLocalTextModelID else {
            return "Local Model"
        }
        if let model = LocalTextModelID(rawValue: modelID) {
            return model.displayName
        }
        return modelID
    }

    var activeChatModelDisplayName: String {
        preferredChatModelSelection.displayName
    }

    var activeCloudProvider: CloudModelProvider? {
        activeAIProvider.cloudProvider
    }

    var activeCloudModels: [CloudTextModelID] {
        guard let provider = activeCloudProvider else { return [] }
        return CloudTextModelID.models(for: provider)
    }

    var configuredCloudProviders: [CloudModelProvider] {
        CloudModelProvider.allCases.filter { provider in
            guard let key = apiKey(for: provider) else { return false }
            return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var hasConfiguredCloudModels: Bool {
        !configuredCloudProviders.isEmpty
    }

    func apiKey(for provider: CloudModelProvider) -> String? {
        if let cached = cachedCloudAPIKeys[provider] {
            return cached
        }
        guard !missingCloudAPIKeyProviders.contains(provider) else {
            return nil
        }
        guard let key = keychainLoad(provider.apiKeyKeychainKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            missingCloudAPIKeyProviders.insert(provider)
            cloudProviderValidationStates[provider] = .missing
            return nil
        }
        cachedCloudAPIKeys[provider] = key
        if cloudProviderValidationStates[provider] == nil ||
            cloudProviderValidationStates[provider] == .missing {
            cloudProviderValidationStates[provider] = .unchecked
        }
        return key
    }

    func cloudValidationState(for provider: CloudModelProvider) -> CloudProviderValidationState {
        cloudProviderValidationStates[provider] ?? .missing
    }

    private func hasConfiguredAPIKey(for provider: CloudModelProvider) -> Bool {
        guard let value = apiKey(for: provider)?
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !value.isEmpty
    }

    private func persistPreferredChatModelSelection(_ selection: ChatModelSelection) {
        preferredChatModelSelection = selection
        UserDefaults.standard.set(selection.rawValue, forKey: "epistemos.preferredChatModelSelection")
        if case .localQwen(let modelID) = selection {
            preferredLocalTextModelID = modelID
            UserDefaults.standard.set(modelID, forKey: "epistemos.preferredLocalTextModelID")
        } else if case .cloud(let model) = selection {
            persistPreferredCloudModel(model)
            persistActiveAIProvider(AIProviderSelection(cloudProvider: model.provider))
        }
    }

    @discardableResult
    func setAPIKey(_ value: String, for provider: CloudModelProvider) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            keychainDelete(provider.apiKeyKeychainKey)
            cachedCloudAPIKeys.removeValue(forKey: provider)
            missingCloudAPIKeyProviders.insert(provider)
            cloudProviderValidationStates[provider] = .missing
            if case .cloud(let model) = preferredChatModelSelection, model.provider == provider {
                persistPreferredChatModelSelection(.localQwen(preferredLocalTextModelID))
            }
            return true
        }
        let didSave = keychainSave(trimmed, provider.apiKeyKeychainKey)
        if didSave {
            cachedCloudAPIKeys[provider] = trimmed
            missingCloudAPIKeyProviders.remove(provider)
            cloudProviderValidationStates[provider] = .unchecked
        } else {
            cloudProviderValidationStates[provider] = .invalid(
                message: "Couldn't store this key in the Apple Keychain.",
                checkedAt: Date()
            )
        }
        return didSave
    }

    func validateAPIKey(for provider: CloudModelProvider) async -> ConnectionTestResult {
        guard let apiKey = apiKey(for: provider)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty else {
            cloudProviderValidationStates[provider] = .missing
            return ConnectionTestResult(
                success: false,
                message: "No \(provider.displayName) API key saved yet."
            )
        }

        cloudProviderValidationStates[provider] = .checking
        let result = await CloudLLMClient(inference: self).testConnection(
            provider: provider,
            apiKey: apiKey
        )
        let checkedAt = Date()
        cloudProviderValidationStates[provider] = result.success
            ? .valid(message: result.message, checkedAt: checkedAt)
            : .invalid(message: result.message, checkedAt: checkedAt)
        return result
    }

    func routeDecision(for profile: InferenceRequestProfile) -> InferenceRouteDecision {
        policyEngine.decide(profile: profile, context: policyContext)
    }

    func localModelSelection(for profile: InferenceRequestProfile) -> LocalModelSelection? {
        policyEngine.localSelection(for: profile, context: policyContext)
    }

    func canAutomaticallyRouteToLocalMLX(for profile: InferenceRequestProfile) -> Bool {
        guard localRuntimeConditions.allowsAutomaticLocalRouting else { return false }
        guard let selection = localModelSelection(for: profile) else { return false }
        guard hardwareCapabilitySnapshot.supports(textModelID: selection.modelID) else { return false }
        return profile.contentLength <= selection.contentBudget
    }

    func canRouteToLocalMLX(contentLength: Int) -> Bool {
        canAutomaticallyRouteToLocalMLX(
            for: InferenceRequestProfile(
                surface: .mainChat,
                intent: .simpleAsk,
                contentLength: contentLength,
                promptLength: contentLength,
                contextBlockCount: max(1, contentLength / 2_400),
                estimatedTokenLoad: max(1, contentLength / 4),
                baseComplexity: 0.35,
                queryComplexity: 0,
                requestedReasoningMode: .fast,
                explicitThinkingRequested: false,
                explicitFastRequested: false,
                visibleThinkingRequested: false
            )
        )
    }

    func canRouteToLocalAgentLoop(for profile: InferenceRequestProfile) -> Bool {
        guard localRuntimeConditions.allowsAutomaticLocalRouting else { return false }
        guard let selection = localModelSelection(for: profile) else { return false }
        guard selection.canActAsAgent else { return false }
        guard hardwareCapabilitySnapshot.supports(textModelID: selection.modelID) else { return false }
        return profile.contentLength <= selection.contentBudget
    }

    func setChatOutputTokens(_ tokens: Int) {
        chatOutputTokens = max(0, tokens)
        UserDefaults.standard.set(chatOutputTokens, forKey: "epistemos.chatOutputTokens")
    }

    func setRoutingMode(_ mode: LocalRoutingMode) {
        routingMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "epistemos.localRoutingMode")
    }

    func setActiveAIProvider(_ provider: AIProviderSelection) {
        persistActiveAIProvider(provider)

        switch preferredChatModelSelection {
        case .appleIntelligence, .localQwen:
            return
        case .cloud(let currentModel):
            guard let activeCloudProvider = provider.cloudProvider else {
                persistPreferredChatModelSelection(.localQwen(preferredLocalTextModelID))
                return
            }
            guard currentModel.provider != activeCloudProvider else {
                persistPreferredCloudModel(currentModel)
                return
            }
            guard hasConfiguredAPIKey(for: activeCloudProvider) else {
                persistPreferredChatModelSelection(.localQwen(preferredLocalTextModelID))
                return
            }
            persistPreferredChatModelSelection(.cloud(loadPreferredCloudModel(for: activeCloudProvider)))
        }
    }

    func setPreferredLocalTextModelID(_ modelID: String) {
        guard LocalTextModelID(rawValue: modelID) != nil else { return }
        preferredLocalTextModelID = modelID
        UserDefaults.standard.set(modelID, forKey: "epistemos.preferredLocalTextModelID")
        if case .localQwen = preferredChatModelSelection {
            preferredChatModelSelection = .localQwen(modelID)
            UserDefaults.standard.set(
                preferredChatModelSelection.rawValue,
                forKey: "epistemos.preferredChatModelSelection"
            )
        }
    }

    func setPreferredChatModelSelection(_ selection: ChatModelSelection) {
        if case .cloud(let model) = selection, !hasConfiguredAPIKey(for: model.provider) {
            persistPreferredChatModelSelection(.localQwen(preferredLocalTextModelID))
            return
        }
        persistPreferredChatModelSelection(selection)
    }

    func setLocalRuntimeConditions(_ conditions: LocalRuntimeConditions) {
        localRuntimeConditions = conditions
    }

    func setInstalledLocalTextModelIDs(_ ids: Set<String>) {
        installedLocalTextModelIDs = ids
    }
}
