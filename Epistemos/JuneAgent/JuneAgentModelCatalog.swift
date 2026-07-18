#if EPISTEMOS_BASE_JUNE
import Foundation

@MainActor
enum JuneAgentModelCatalog {
    static var modelIDs: [String] {
        JuneCloudModel.allCases.map(\.rawValue)
    }

    static func modelsPayload() -> [[String: Any]] {
        let configuration = JuneCloudConfigurationStore.shared
        return JuneCloudModel.allCases.map { model in
            let configured = configuration.isConfigured(model.provider)
            let consented = configuration.hasConsent(model.provider)
            let status: String
            if !configured {
                status = "Add a \(model.provider.displayName) API key in June Settings."
            } else if !consented {
                status = "Enable \(model.provider.displayName) cloud consent in June Settings."
            } else {
                status = "Ready through June's in-process Goose agent."
            }
            var capabilities = ["supportsFunctionCalling"]
            if model.supportsReasoning {
                capabilities.append("supportsReasoning")
                capabilities.append("supportsReasoningDeltas")
            }
            return [
                "provider": model.provider.rawValue,
                "id": model.rawValue,
                "name": "\(model.provider.displayName) · \(model.displayName)",
                "modelType": "text",
                "description": status,
                "privacy": "provider-cloud",
                "traits": ["cloud", model.provider.rawValue, "goose-in-process"],
                "capabilities": capabilities,
                "contextTokens": model.maxContextTokens,
            ]
        }
    }
}
#endif
