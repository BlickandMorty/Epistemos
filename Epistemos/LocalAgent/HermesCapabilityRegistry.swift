import Foundation

nonisolated enum HermesCapabilityTier: String, CaseIterable, Sendable {
    case core
    case pro
    case research
}

nonisolated enum HermesCapabilityOwner: String, CaseIterable, Sendable {
    case nativeCore
    case hermesGateway
    case researchOnly
    case outOfScope
}

nonisolated enum HermesCapabilitySurface: String, CaseIterable, Sendable {
    case agentTask
    case session
    case configuration
    case fileData
    case toolsIntegration
    case uiDisplay
    case persona
    case messaging
    case advanced
    case toolset
}

nonisolated struct HermesCapability: Equatable, Sendable {
    let commandPattern: String
    let surface: HermesCapabilitySurface
    let tier: HermesCapabilityTier
    let owner: HermesCapabilityOwner
    let requiresNetwork: Bool
    let requiresSubprocess: Bool
    let requiresApproval: Bool
    let structuredEvidence: Bool
    let nativeEquivalent: String
    let hermesPassthrough: Bool

    var commandToken: String {
        Self.commandToken(from: commandPattern)
    }

    static func commandToken(from pattern: String) -> String {
        pattern
            .split(separator: " ")
            .prefix { part in
                !part.hasPrefix("<") && !part.hasPrefix("[")
            }
            .joined(separator: " ")
    }
}

nonisolated enum HermesCapabilityRegistry {
    static let all: [HermesCapability] = [
        core("/ask <question>", .agentTask, "Native note-aware chat/query", passthrough: true),
        core("/think <prompt>", .agentTask, "Local reasoning display"),
        core("/plan <task>", .agentTask, "Native workcard and deliberation planner", passthrough: true),
        pro("/execute <task>", .agentTask, "Hermes task execution", network: true, approval: true),
        core("/todo", .agentTask, "Native task substrate", passthrough: true),
        core("/todo add <task>", .agentTask, "Native task substrate", approval: true, passthrough: true),
        core("/todo done <id>", .agentTask, "Native task substrate", passthrough: true),
        core("/todo clear", .agentTask, "Native task substrate", approval: true, passthrough: true),
        pro("/run <command>", .agentTask, "Hermes shell gateway", subprocess: true, approval: true),
        pro("/shell", .agentTask, "Hermes interactive shell gateway", subprocess: true, approval: true),
        pro("/kill <pid>", .agentTask, "Hermes process control gateway", subprocess: true, approval: true),

        core("/new", .session, "Native session reset", passthrough: true),
        core("/clear", .session, "Native UI/session clear", approval: true, passthrough: true),
        core("/status", .session, "Native status panel", passthrough: true),
        core("/compact", .session, "Native context compaction", passthrough: true),
        core("/summary", .session, "Native summary artifact", passthrough: true),
        core("/save", .session, "Native session ledger", passthrough: true),
        core("/load", .session, "Native session browser", passthrough: true),
        core("/export", .session, "User-approved export", approval: true, passthrough: true),
        core("/tokens", .session, "Native token/context dashboard", passthrough: true),
        core("/cost", .session, "Native usage and cost panel", passthrough: true),
        core("/model", .session, "Native model picker", passthrough: true),
        core("/help", .session, "Unified command help", passthrough: true),

        core("/model <name>", .configuration, "Native model routing policy", approval: true, passthrough: true),
        core("/model list", .configuration, "Native provider registry", passthrough: true),
        core("/temperature <0-2>", .configuration, "Native per-session model config", passthrough: true),
        core("/max-tokens <num>", .configuration, "Native per-session model config", passthrough: true),
        core("/top-p <0-1>", .configuration, "Native per-session model config", passthrough: true),
        core("/top-k <num>", .configuration, "Native per-session model config", passthrough: true),
        core("/system <prompt>", .configuration, "Native audited prompt profile", approval: true, passthrough: true),
        core("/persona <name>", .persona, "Native persona switch", passthrough: true),
        core("/persona list", .persona, "Native persona browser", passthrough: true),
        core("/memory on/off", .configuration, "Native memory gate", approval: true, passthrough: true),
        core("/memory clear", .configuration, "Native memory clear", approval: true, passthrough: true),
        core("/tools on/off", .configuration, "Native tier/tool policy toggle", approval: true, passthrough: true),
        core("/config show", .configuration, "Native diagnostics panel", passthrough: true),

        core("/read <file>", .fileData, "Vault/bookmark file read", passthrough: true),
        core("/write <file> <content>", .fileData, "Vault/bookmark file write", approval: true, passthrough: true),
        core("/append <file> <content>", .fileData, "Vault/bookmark file append", approval: true, passthrough: true),
        core("/ls [path]", .fileData, "Vault/bookmark directory list", passthrough: true),
        core("/search <query>", .fileData, "Native search index", passthrough: true),
        core("/grep <pattern>", .fileData, "Native pattern search", passthrough: true),
        core("/notebook", .fileData, "Epistemos notebook/vault surface", passthrough: true),
        core("/notebook list", .fileData, "Notebook browser", passthrough: true),
        core("/notebook clear", .fileData, "Notebook clear", approval: true, passthrough: true),

        core("/tools", .toolsIntegration, "Native tier-aware tool catalog", passthrough: true),
        core("/tool use <name>", .toolsIntegration, "Native policy-gated tool invocation", approval: true, passthrough: true),
        pro("/tool add <name> <cmd>", .toolsIntegration, "Hermes custom-tool gateway", subprocess: true, approval: true),
        pro("/tool remove <name>", .toolsIntegration, "Hermes custom-tool removal", subprocess: true, approval: true),
        pro("/tool edit <name>", .toolsIntegration, "Hermes custom-tool edit", subprocess: true, approval: true),
        pro("/mcp list", .toolsIntegration, "Hermes MCP gateway", network: true, subprocess: true),
        pro("/mcp connect <url>", .toolsIntegration, "Hermes MCP connect", network: true, subprocess: true, approval: true),
        pro("/mcp disconnect <url>", .toolsIntegration, "Hermes MCP disconnect", network: true, subprocess: true, approval: true),
        pro("/mcp info", .toolsIntegration, "Hermes MCP diagnostics", network: true, subprocess: true),
        pro("/web search <query>", .toolsIntegration, "Hermes web search gateway", network: true),
        pro("/web page <url>", .toolsIntegration, "Hermes web fetch gateway", network: true),
        core("/calc <expression>", .toolsIntegration, "Native deterministic calculator"),

        core("/theme <name>", .uiDisplay, "Native theme setting"),
        core("/theme list", .uiDisplay, "Native theme browser"),
        core("/mode <simple|rich>", .uiDisplay, "Native conversation presentation"),
        core("/markdown <on/off>", .uiDisplay, "Native markdown rendering setting"),
        core("/image <on/off>", .uiDisplay, "Native multimodal display setting"),
        core("/pager <on/off>", .uiDisplay, "Native output paging setting"),
        core("/width <num>", .uiDisplay, "Native layout setting"),
        core("/font <name>", .uiDisplay, "Native typography setting"),
        core("/fontsize <size>", .uiDisplay, "Native typography setting"),
        core("/colors", .uiDisplay, "Native theme diagnostics"),

        core("/persona create <name>", .persona, "Native persona profile create", approval: true),
        core("/persona edit <name>", .persona, "Native persona editor", approval: true),
        core("/persona delete <name>", .persona, "Native persona delete", approval: true),
        core("/persona export <name>", .persona, "Native persona export", approval: true),
        core("/persona import <file>", .persona, "Native persona import", approval: true),
        pro("/persona share <name>", .persona, "Hermes outbound persona share", network: true, approval: true),
        core("/persona info <name>", .persona, "Native persona details"),
        core("/persona default <name>", .persona, "Native default persona preference", approval: true),
        core("/persona reset", .persona, "Native persona reset", approval: true),

        pro("/reply", .messaging, "Hermes messaging gateway", network: true, approval: true),
        pro("/forward", .messaging, "Hermes messaging gateway", network: true, approval: true),
        core("/copy", .messaging, "Native clipboard action", approval: true),
        pro("/share", .messaging, "Hermes outbound share gateway", network: true, approval: true),
        core("/pin", .messaging, "Native pinned-message state", passthrough: true),
        core("/unpin", .messaging, "Native pinned-message state", passthrough: true),
        core("/history", .messaging, "Native session history", passthrough: true),
        core("/stats", .messaging, "Native usage statistics", passthrough: true),

        core("/debug on/off", .advanced, "Native diagnostics toggle"),
        core("/verbose <on/off>", .advanced, "Native progress verbosity", passthrough: true),
        core("/trace", .advanced, "Native trace viewer", passthrough: true),
        core("/profile", .advanced, "Native profiling diagnostics"),
        research("/benchmark", .advanced, "Research benchmark harness", approval: true),
        core("/metrics", .advanced, "Native metrics panel"),
        core("/log <level>", .advanced, "Native log setting", approval: true),
        core("/log show", .advanced, "Native log viewer"),
        core("/config edit", .advanced, "Native config UI", approval: true),
        core("/reload", .advanced, "Native reload action", approval: true),
        core("/version", .advanced, "Native about/version panel"),

        core("file_ops", .toolset, "Native vault/bookmark file operations", approval: true, passthrough: true),
        pro("web_fetch", .toolset, "Hermes web fetch toolset", network: true),
        core("memory", .toolset, "Native memory substrate", passthrough: true),
        core("session", .toolset, "Native session ledger", passthrough: true),
        core("todo", .toolset, "Native task substrate", passthrough: true),
        pro("mcp", .toolset, "Hermes MCP gateway", network: true, subprocess: true, approval: true),
        pro("browser", .toolset, "Hermes browser toolset", network: true, subprocess: true, approval: true),
        pro("code_execution", .toolset, "Hermes code execution toolset", subprocess: true, approval: true),
        pro("terminal", .toolset, "Hermes terminal toolset", subprocess: true, approval: true),
        pro("messaging", .toolset, "Hermes messaging gateway", network: true, approval: true),
        research("plugins", .toolset, "Research plugin management", network: true, subprocess: true, approval: true),
        pro("toolsets", .toolset, "Hermes toolset configuration", subprocess: true, approval: true),
    ]

    static var commandPatterns: Set<String> {
        Set(all.map(\.commandPattern))
    }

    static func capability(commandPattern: String) -> HermesCapability? {
        all.first { $0.commandPattern == commandPattern }
    }

    static func capability(commandToken: String) -> HermesCapability? {
        all.first { $0.commandToken == commandToken }
    }

    static func capabilities(for distribution: ToolSurfacePolicy.Distribution) -> [HermesCapability] {
        switch ToolSurfacePolicy.resolvedDistribution(distribution) {
        case .coreAppStore:
            all.filter { $0.tier == .core && $0.owner == .nativeCore }
        case .proResearch, .currentBuild:
            all.filter { $0.owner != .outOfScope }
        }
    }

    static func requiresNativeApproval(commandPattern: String) -> Bool {
        capability(commandPattern: commandPattern)?.requiresApproval ?? false
    }

    private static func core(
        _ commandPattern: String,
        _ surface: HermesCapabilitySurface,
        _ nativeEquivalent: String,
        approval: Bool = false,
        passthrough: Bool = false
    ) -> HermesCapability {
        HermesCapability(
            commandPattern: commandPattern,
            surface: surface,
            tier: .core,
            owner: .nativeCore,
            requiresNetwork: false,
            requiresSubprocess: false,
            requiresApproval: approval,
            structuredEvidence: false,
            nativeEquivalent: nativeEquivalent,
            hermesPassthrough: passthrough
        )
    }

    private static func pro(
        _ commandPattern: String,
        _ surface: HermesCapabilitySurface,
        _ nativeEquivalent: String,
        network: Bool = false,
        subprocess: Bool = false,
        approval: Bool = false
    ) -> HermesCapability {
        HermesCapability(
            commandPattern: commandPattern,
            surface: surface,
            tier: .pro,
            owner: .hermesGateway,
            requiresNetwork: network,
            requiresSubprocess: subprocess,
            requiresApproval: approval,
            structuredEvidence: true,
            nativeEquivalent: nativeEquivalent,
            hermesPassthrough: true
        )
    }

    private static func research(
        _ commandPattern: String,
        _ surface: HermesCapabilitySurface,
        _ nativeEquivalent: String,
        network: Bool = false,
        subprocess: Bool = false,
        approval: Bool
    ) -> HermesCapability {
        HermesCapability(
            commandPattern: commandPattern,
            surface: surface,
            tier: .research,
            owner: .researchOnly,
            requiresNetwork: network,
            requiresSubprocess: subprocess,
            requiresApproval: approval,
            structuredEvidence: true,
            nativeEquivalent: nativeEquivalent,
            hermesPassthrough: false
        )
    }
}
