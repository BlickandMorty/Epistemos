#if EPISTEMOS_APP_STORE
import Foundation

@MainActor
enum JuneAgentModelCatalog {
    static let directCloudProviders = CloudModelProvider.juneAgentProviders

    /// VeniceModelDto-shaped rows for `list_venice_models`.
    ///
    /// PROVIDER FIELD — local rows carry `provider: ""` DELIBERATELY (not
    /// "epistemos"). June's own `modelSupportsTools` predicate is the truth
    /// boundary for function-calling; local Apple/GGUF rows therefore expose
    /// an explicit `epistemos-local-chat` trait and an empty capability list.
    /// Cloud rows may advertise tools only when routed through agent_core.
    static func modelsPayload(
        localGGUFAvailable: Bool,
        downloads: QuickChatModelDownloadManager,
        preferredConfiguredCloudModel: CloudTextModelID?,
        cachedConfiguredCloudProviders: Set<CloudModelProvider>
    ) -> [[String: Any]] {
        var rows: [[String: Any]] = []
        if AppleFMQuickChatBackend.unavailability() == nil {
            rows.append([
                "provider": "", "id": JuneModelID.appleFM,
                "name": "Apple Intelligence (on-device)", "modelType": "text",
                "description": "Apple's on-device foundation model. Fast, free, fully private, compact-context chat only — no agent tools.",
                "privacy": "private", "traits": ["on-device", "epistemos-local-chat", "compact-context"], "capabilities": [String](),
                "contextTokens": 4_096,
            ])
        }
        if localGGUFAvailable {
            for entry in GGUFModelCatalog.entries {
                let state = downloads.state(for: entry)
                let ramProblem = GGUFModelCatalog.ramGate(for: entry)
                let detail: String
                switch state {
                case .installed:
                    if let ramProblem {
                        detail = "\(entry.subtitle). Installed, but not runnable on this Mac: \(ramProblem.userCopy)"
                    } else {
                        detail = "\(entry.subtitle). Runs locally, free, fully private. Chat only — no agent tools."
                    }
                case .downloading(let progress):
                    detail = "\(entry.subtitle). Downloading \(Int(progress * 100))%…"
                case .verifying:
                    detail = "\(entry.subtitle). Verifying download…"
                case .failed(let why):
                    detail = "\(entry.subtitle). \(why)"
                case .notInstalled:
                    if let ramProblem {
                        detail = "\(entry.subtitle). Not runnable on this Mac: \(ramProblem.userCopy) No download will start."
                    } else {
                        detail = "\(entry.subtitle). Select to download (~\(sizeText(entry.approxDownloadBytes))), then runs locally & fully private."
                    }
                }
                rows.append([
                    "provider": "", "id": entry.id,
                    "name": "\(entry.displayName) (on-device)", "modelType": "text",
                    "description": detail,
                    "privacy": "private", "traits": ["on-device", "epistemos-local-chat", "compact-context"], "capabilities": [String](),
                    "contextTokens": entry.defaultContextTokens,
                ])
            }
        }
        rows.append([
            "provider": "epistemos", "id": JuneModelID.cloud,
            "name": "Cloud Agent", "modelType": "text",
            "description": "Full agent capability in June through a saved OpenAI or Anthropic API key. Prompts and selected context go directly to the chosen provider only after you enable its consent toggle in Settings.",
            "privacy": "provider-cloud", "traits": ["cloud", "configured-provider-required"],
            "capabilities": genericCloudCapabilities(preferredConfiguredCloudModel),
            "contextTokens": 200_000,
        ])
        for provider in directCloudProviders {
            let configured = cachedConfiguredCloudProviders.contains(provider)
            for model in CloudTextModelID.juneAgentModels(for: provider) {
                rows.append([
                    "provider": provider.rawValue, "id": model.rawValue,
                    "name": "\(provider.displayName) · \(model.displayName)", "modelType": "text",
                    "description": configured
                        ? "\(model.aboutSheetPurposeSummary) \(configuredCredentialDescription(for: provider))"
                        : "\(model.aboutSheetPurposeSummary) Configure \(provider.displayName) in Settings to use this model.",
                    "privacy": "provider-cloud", "traits": ["cloud", provider.rawValue],
                    "capabilities": cloudCapabilities(provider: provider, model: model),
                    "contextTokens": model.maxContextTokens,
                ])
            }
        }
        return rows
    }

    static func cloudCapabilities(
        provider: CloudModelProvider,
        model: CloudTextModelID
    ) -> [String] {
        var capabilities = provider.supportsAgentTier
            ? ["supportsFunctionCalling"]
            : [String]()
        if model.supportedOperatingModes.contains(.thinking) {
            capabilities.append("supportsReasoning")
            capabilities.append("supportsReasoningDeltas")
        }
        if model.supportsNativeReasoningEffortControl {
            capabilities.append("supportsNativeReasoningControls")
        }
        return capabilities
    }

    static func directCloudModelIDs(configuredOnly: Bool) -> [String] {
        let inference = AppBootstrap.shared?.inferenceState
        return directCloudProviders.flatMap { provider in
            if configuredOnly, inference?.hasCachedCloudAccess(for: provider) != true {
                return [String]()
            }
            return CloudTextModelID.juneAgentModels(for: provider).map(\.rawValue)
        }
    }

    private static func genericCloudCapabilities(_ preferredConfiguredCloudModel: CloudTextModelID?) -> [String] {
        guard let model = preferredConfiguredCloudModel else {
            return ["supportsFunctionCalling"]
        }
        return cloudCapabilities(provider: model.provider, model: model)
    }

    private static func configuredCredentialDescription(for provider: CloudModelProvider) -> String {
        switch provider {
        case .openAI:
            return "Uses your saved OpenAI API key."
        case .anthropic:
            return "Uses your saved Anthropic API key."
        case .google, .zai, .kimi, .minimax, .deepseek:
            return "Uses your configured provider credential."
        }
    }

    private static func sizeText(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(bytes) / 1_048_576)
    }
}

#endif
