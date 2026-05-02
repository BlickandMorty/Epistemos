import Foundation

nonisolated enum HermesGatewayTier: String, Equatable, Sendable {
    case core
    case proResearch
}

nonisolated enum HermesGatewayRoute: String, Equatable, Sendable {
    case directSubstrate
    case inProcessLocalPrompt
    case hermesGateway
}

nonisolated enum HermesGatewaySurface: CaseIterable, Sendable {
    case deterministicLocalSubstrate
    case localPromptFormatting
    case cloudProvider
    case cliDelegation
    case mcpWebTool
    case hermesSubprocess
    case browserComputerUse
    case dockerDevcontainer
    case explicitExternalSideEffect

    static let externalGatewaySurfaces: [Self] = [
        .cloudProvider,
        .cliDelegation,
        .mcpWebTool,
        .hermesSubprocess,
        .browserComputerUse,
        .dockerDevcontainer,
        .explicitExternalSideEffect,
    ]
}

nonisolated struct HermesGatewayDecision: Equatable, Sendable {
    let tier: HermesGatewayTier
    let route: HermesGatewayRoute
    let requiresNetwork: Bool
    let requiresSubprocess: Bool
    let preservesDirectSubstratePath: Bool
    let reason: String
}

nonisolated enum HermesGatewayPolicy {
    typealias Surface = HermesGatewaySurface
    typealias Tier = HermesGatewayTier
    typealias Route = HermesGatewayRoute
    typealias Decision = HermesGatewayDecision

    static let externalTierBoundaryLine =
        "Cloud/provider/CLI/MCP/Hermes subprocess orchestration is Pro/Research only."
    static let localCoreBoundaryLine =
        "Local Hermes-family prompt formatting may stay Core-safe only when it runs in-process over local context."

    static func isAllowedInCoreAppStoreBuild(_ surface: Surface) -> Bool {
        let decision = decision(for: surface)
        return decision.tier == .core
            && !decision.requiresNetwork
            && !decision.requiresSubprocess
            && decision.preservesDirectSubstratePath
    }

    static func route(for surface: Surface) -> Route {
        decision(for: surface).route
    }

    static func usesHermesGateway(_ surface: Surface) -> Bool {
        route(for: surface) == .hermesGateway
    }

    static func decision(for surface: Surface) -> Decision {
        switch surface {
        case .deterministicLocalSubstrate:
            Decision(
                tier: .core,
                route: .directSubstrate,
                requiresNetwork: false,
                requiresSubprocess: false,
                preservesDirectSubstratePath: true,
                reason: "Already-local deterministic substrate answers stay on the direct path."
            )
        case .localPromptFormatting:
            Decision(
                tier: .core,
                route: .inProcessLocalPrompt,
                requiresNetwork: false,
                requiresSubprocess: false,
                preservesDirectSubstratePath: true,
                reason: "Hermes-family prompt grammar is Core-safe only when it stays in-process over local context."
            )
        case .cloudProvider:
            Decision(
                tier: .proResearch,
                route: .hermesGateway,
                requiresNetwork: true,
                requiresSubprocess: false,
                preservesDirectSubstratePath: false,
                reason: "Cloud providers are external intelligence and must stay behind the Pro/Research gateway."
            )
        case .cliDelegation:
            Decision(
                tier: .proResearch,
                route: .hermesGateway,
                requiresNetwork: false,
                requiresSubprocess: true,
                preservesDirectSubstratePath: false,
                reason: "CLI delegation may run offline, but it is still external subprocess orchestration."
            )
        case .mcpWebTool:
            Decision(
                tier: .proResearch,
                route: .hermesGateway,
                requiresNetwork: true,
                requiresSubprocess: true,
                preservesDirectSubstratePath: false,
                reason: "MCP and web tools cross the local substrate boundary and return evidence, not authority."
            )
        case .hermesSubprocess:
            Decision(
                tier: .proResearch,
                route: .hermesGateway,
                requiresNetwork: false,
                requiresSubprocess: true,
                preservesDirectSubstratePath: false,
                reason: "A Hermes subprocess is orchestration, not the Core in-process prompt path."
            )
        case .browserComputerUse:
            Decision(
                tier: .proResearch,
                route: .hermesGateway,
                requiresNetwork: true,
                requiresSubprocess: true,
                preservesDirectSubstratePath: false,
                reason: "Browser and computer-use actions are external side-effect surfaces."
            )
        case .dockerDevcontainer:
            Decision(
                tier: .proResearch,
                route: .hermesGateway,
                requiresNetwork: false,
                requiresSubprocess: true,
                preservesDirectSubstratePath: false,
                reason: "Docker and devcontainer work is external runtime orchestration."
            )
        case .explicitExternalSideEffect:
            Decision(
                tier: .proResearch,
                route: .hermesGateway,
                requiresNetwork: false,
                requiresSubprocess: true,
                preservesDirectSubstratePath: false,
                reason: "Explicit external side effects must be gated outside the deterministic substrate."
            )
        }
    }
}
