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
        guard let parsed = HermesCommandDispatcher.parseCore(rawCommand) else {
            return [
                XPCEnvelopeKeys.status: "unknown",
                XPCEnvelopeKeys.rawCommand: rawCommand,
            ]
        }

        return [
            XPCEnvelopeKeys.status: "parsed",
            XPCEnvelopeKeys.rawCommand: rawCommand,
            XPCEnvelopeKeys.command: commandName(for: parsed),
            XPCEnvelopeKeys.requiresApproval: parsed.requiresApproval,
        ]
    }

    static func commandName(for parsed: HermesParsedCommand) -> String {
        switch parsed {
        case .ask: return "/ask"
        case .append: return "/append"
        case .calc: return "/calc"
        case .clear: return "/clear"
        case .colors: return "/colors"
        case .compact: return "/compact"
        case .configShow: return "/config show"
        case .cost: return "/cost"
        case .export: return "/export"
        case .font: return "/font"
        case .fontsize: return "/fontsize"
        case .grep: return "/grep"
        case .help: return "/help"
        case .load: return "/load"
        case .ls: return "/ls"
        case .memory: return "/memory"
        case .mode: return "/mode"
        case .model: return "/model"
        case .newSession: return "/new"
        case .notebook: return "/notebook"
        case .parameter: return "/parameter"
        case .persona: return "/persona"
        case .read: return "/read"
        case .save: return "/save"
        case .search: return "/search"
        case .status: return "/status"
        case .summary: return "/summary"
        case .systemPrompt: return "/system"
        case .theme: return "/theme"
        case .think: return "/think"
        case .todo: return "/todo"
        case .tokens: return "/tokens"
        case .toolsToggle: return "/tools"
        case .uiToggle: return "/ui"
        case .width: return "/width"
        case .write: return "/write"
        }
    }
}

nonisolated enum ProviderXPCSurfaceEnvelope {
    static func response(for surfaceName: String) -> NSDictionary {
        guard let surface = HermesGatewaySurface.xpcSurface(named: surfaceName) else {
            return [
                XPCEnvelopeKeys.status: "unknown",
                "surface": surfaceName,
            ]
        }

        let decision = HermesGatewayPolicy.decision(for: surface)
        return [
            XPCEnvelopeKeys.status: "classified",
            "surface": surfaceName,
            XPCEnvelopeKeys.tier: decision.tier.rawValue,
            XPCEnvelopeKeys.route: decision.route.rawValue,
            XPCEnvelopeKeys.requiresNetwork: decision.requiresNetwork,
            XPCEnvelopeKeys.requiresSubprocess: decision.requiresSubprocess,
            XPCEnvelopeKeys.evidenceReturn: decision.evidenceReturn.rawValue,
            XPCEnvelopeKeys.reason: decision.reason,
        ]
    }
}

extension HermesGatewaySurface {
    nonisolated static func xpcSurface(named name: String) -> Self? {
        switch name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "deterministiclocalsubstrate", "deterministic-local-substrate", "local-substrate":
            return .deterministicLocalSubstrate
        case "localpromptformatting", "local-prompt-formatting", "local-prompt":
            return .localPromptFormatting
        case "cloudprovider", "cloud-provider", "cloud":
            return .cloudProvider
        case "openaiprovider", "openai-provider", "openai":
            return .openAIProvider
        case "anthropicprovider", "anthropic-provider", "anthropic", "claude":
            return .anthropicProvider
        case "googleprovider", "google-provider", "google", "gemini":
            return .googleProvider
        case "openaicompatibleprovider", "openai-compatible-provider", "openai-compatible":
            return .openAICompatibleProvider
        case "codexaccountprovider", "codex-account-provider", "codex":
            return .codexAccountProvider
        case "clidelegation", "cli-delegation", "cli", "multi-cli":
            return .cliDelegation
        case "mcpwebtool", "mcp-web-tool", "mcp", "web":
            return .mcpWebTool
        case "hermessubprocess", "hermes-subprocess":
            return .hermesSubprocess
        case "browsercomputeruse", "browser-computer-use", "browser", "computer-use":
            return .browserComputerUse
        case "dockerdevcontainer", "docker-devcontainer", "docker", "devcontainer":
            return .dockerDevcontainer
        case "explicitexternalsideeffect", "explicit-external-side-effect", "external-side-effect":
            return .explicitExternalSideEffect
        default:
            return nil
        }
    }
}
