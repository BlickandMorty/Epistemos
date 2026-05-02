import Testing
@testable import Epistemos

@Suite("Hermes Gateway Policy")
nonisolated struct HermesGatewayPolicyTests {
    @Test("local prompt formatting stays Core-safe and in-process")
    func localPromptFormattingStaysCoreSafeAndInProcess() {
        let decision = HermesGatewayPolicy.decision(for: .localPromptFormatting)

        #expect(decision.tier == .core)
        #expect(!decision.requiresNetwork)
        #expect(!decision.requiresSubprocess)
        #expect(decision.preservesDirectSubstratePath)
    }

    @Test("external gateway surfaces are Pro or Research only")
    func externalGatewaySurfacesAreProOrResearchOnly() {
        for surface in HermesGatewayPolicy.Surface.externalGatewaySurfaces {
            let decision = HermesGatewayPolicy.decision(for: surface)

            #expect(decision.tier == .proResearch)
            #expect(decision.requiresSubprocess || surface == .cloudProvider)
            #expect(!decision.preservesDirectSubstratePath)
        }
    }

    @Test("network need is separate from Pro subprocess policy")
    func networkNeedIsSeparateFromProSubprocessPolicy() {
        let cloud = HermesGatewayPolicy.decision(for: .cloudProvider)
        let cli = HermesGatewayPolicy.decision(for: .cliDelegation)

        #expect(cloud.requiresNetwork)
        #expect(!cloud.requiresSubprocess)
        #expect(!cli.requiresNetwork)
        #expect(cli.requiresSubprocess)
    }

    @Test("prompt boundary lines remain canonical")
    func promptBoundaryLinesRemainCanonical() {
        #expect(
            HermesGatewayPolicy.externalTierBoundaryLine
                == "Cloud/provider/CLI/MCP/Hermes subprocess orchestration is Pro/Research only."
        )
        #expect(
            HermesGatewayPolicy.localCoreBoundaryLine
                == "Local Hermes-family prompt formatting may stay Core-safe only when it runs in-process over local context."
        )
    }
}
