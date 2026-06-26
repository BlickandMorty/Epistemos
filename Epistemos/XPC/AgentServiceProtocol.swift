import Foundation

@objc(EpistemosAgentServiceProtocol)
protocol AgentServiceProtocol {
    func parseCoreCommand(_ rawCommand: String, withReply reply: @escaping (NSDictionary) -> Void)
}

@objc(EpistemosProviderServiceProtocol)
protocol ProviderServiceProtocol {
    func classifySurface(_ surfaceName: String, withReply reply: @escaping (NSDictionary) -> Void)
}

nonisolated enum EpistemosXPCServiceNames {
    static let appGroupIdentifier = AppGroupContainer.canonicalGroupIdentifier
    static let agentService = "\(appGroupIdentifier).AgentXPC"
    static let providerService = "\(appGroupIdentifier).ProviderXPC"
}

nonisolated enum XPCEnvelopeKeys {
    static let status = "status"
    static let rawCommand = "rawCommand"
    static let command = "command"
    static let requiresApproval = "requiresApproval"
    static let tier = "tier"
    static let route = "route"
    static let requiresNetwork = "requiresNetwork"
    static let requiresSubprocess = "requiresSubprocess"
    static let evidenceReturn = "evidenceReturn"
    static let reason = "reason"
}

nonisolated enum AgentXPCCommandEnvelope {
    static func response(for rawCommand: String) -> NSDictionary {
        return [
            XPCEnvelopeKeys.status: "removed",
            XPCEnvelopeKeys.rawCommand: rawCommand,
            XPCEnvelopeKeys.reason: "The app-local agent command parser has been removed.",
        ]
    }
}

nonisolated enum ProviderXPCSurfaceEnvelope {
    static func response(for surfaceName: String) -> NSDictionary {
        return [
            XPCEnvelopeKeys.status: "removed",
            "surface": surfaceName,
            XPCEnvelopeKeys.reason: "The app-local agent gateway policy has been removed.",
        ]
    }
}
