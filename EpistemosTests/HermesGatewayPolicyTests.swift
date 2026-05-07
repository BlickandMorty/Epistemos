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
            #expect(decision.requiresNetwork || decision.requiresSubprocess)
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
        // Updated 2026-05-05 with the Hermes-agent removal — the
        // .hermesSubprocess surface no longer exists, so the boundary line
        // no longer mentions it. See docs/_archive/hermes-removal-2026-05-05/
        // README.md for the removal record.
        #expect(
            LocalAgentGatewayPolicy.externalTierBoundaryLine
                == "Cloud/provider/CLI/MCP/browser/Docker orchestration is Pro/Research only."
        )
        #expect(
            LocalAgentGatewayPolicy.localCoreBoundaryLine
                == "LocalAgent-family prompt formatting may stay Core-safe only when it runs in-process over local context."
        )
    }

    @Test("Core App Store lane allows only direct local Hermes surfaces")
    func coreAppStoreLaneAllowsOnlyDirectLocalHermesSurfaces() {
        #expect(HermesGatewayPolicy.isAllowedInCoreAppStoreBuild(.deterministicLocalSubstrate))
        #expect(HermesGatewayPolicy.isAllowedInCoreAppStoreBuild(.localPromptFormatting))

        for surface in HermesGatewayPolicy.Surface.externalGatewaySurfaces {
            #expect(!HermesGatewayPolicy.isAllowedInCoreAppStoreBuild(surface))
        }
    }

    @Test("Core App Store allowed surfaces need no external runtime")
    func coreAppStoreAllowedSurfacesNeedNoExternalRuntime() {
        for surface in HermesGatewayPolicy.Surface.allCases {
            let decision = HermesGatewayPolicy.decision(for: surface)

            if HermesGatewayPolicy.isAllowedInCoreAppStoreBuild(surface) {
                #expect(decision.tier == .core)
                #expect(!decision.requiresNetwork)
                #expect(!decision.requiresSubprocess)
                #expect(decision.preservesDirectSubstratePath)
            }
        }
    }

    @Test("gateway route keeps local work direct and external work unified")
    func gatewayRouteKeepsLocalWorkDirectAndExternalWorkUnified() {
        #expect(HermesGatewayPolicy.route(for: .deterministicLocalSubstrate) == .directSubstrate)
        #expect(HermesGatewayPolicy.route(for: .localPromptFormatting) == .inProcessLocalPrompt)
        #expect(!HermesGatewayPolicy.usesHermesGateway(.deterministicLocalSubstrate))
        #expect(!HermesGatewayPolicy.usesHermesGateway(.localPromptFormatting))

        for surface in HermesGatewayPolicy.Surface.externalGatewaySurfaces {
            let decision = HermesGatewayPolicy.decision(for: surface)

            #expect(decision.route == .hermesGateway)
            #expect(HermesGatewayPolicy.usesHermesGateway(surface))
        }
    }

    @Test("Core App Store allowed surfaces never use Hermes gateway route")
    func coreAppStoreAllowedSurfacesNeverUseHermesGatewayRoute() {
        for surface in HermesGatewayPolicy.Surface.allCases where HermesGatewayPolicy.isAllowedInCoreAppStoreBuild(surface) {
            #expect(!HermesGatewayPolicy.usesHermesGateway(surface))
        }
    }

    @Test("local surfaces do not require structured external evidence return")
    func localSurfacesDoNotRequireStructuredExternalEvidenceReturn() {
        #expect(HermesGatewayPolicy.evidenceReturn(for: .deterministicLocalSubstrate) == .none)
        #expect(HermesGatewayPolicy.evidenceReturn(for: .localPromptFormatting) == .inProcessPromptContext)
        #expect(!HermesGatewayPolicy.requiresStructuredEvidenceReturn(.deterministicLocalSubstrate))
        #expect(!HermesGatewayPolicy.requiresStructuredEvidenceReturn(.localPromptFormatting))
    }

    @Test("external gateway surfaces require structured evidence provenance")
    func externalGatewaySurfacesRequireStructuredEvidenceProvenance() {
        for surface in HermesGatewayPolicy.Surface.externalGatewaySurfaces {
            #expect(HermesGatewayPolicy.evidenceReturn(for: surface) == .structuredEvidenceProvenance)
            #expect(HermesGatewayPolicy.requiresStructuredEvidenceReturn(surface))
        }
    }

    @Test("named cloud provider surfaces are gateway only")
    func namedCloudProviderSurfacesAreGatewayOnly() {
        let expected: [HermesGatewayPolicy.Surface] = [
            .cloudProvider,
            .openAIProvider,
            .anthropicProvider,
            .googleProvider,
            .openAICompatibleProvider,
            .codexAccountProvider,
        ]

        #expect(HermesGatewayPolicy.Surface.cloudProviderSurfaces == expected)

        for surface in HermesGatewayPolicy.Surface.cloudProviderSurfaces {
            let decision = HermesGatewayPolicy.decision(for: surface)

            #expect(decision.tier == .proResearch)
            #expect(decision.route == .hermesGateway)
            #expect(decision.requiresNetwork)
            #expect(!decision.requiresSubprocess)
            #expect(!decision.preservesDirectSubstratePath)
            #expect(decision.evidenceReturn == .structuredEvidenceProvenance)
            #expect(!HermesGatewayPolicy.isAllowedInCoreAppStoreBuild(surface))
        }
    }

    @Test("external gateway surfaces compose all cloud provider surfaces")
    func externalGatewaySurfacesComposeAllCloudProviderSurfaces() {
        for surface in HermesGatewayPolicy.Surface.cloudProviderSurfaces {
            #expect(HermesGatewayPolicy.Surface.externalGatewaySurfaces.contains(surface))
        }
    }

    @Test("evidence return follows the gateway route")
    func evidenceReturnFollowsGatewayRoute() {
        for surface in HermesGatewayPolicy.Surface.allCases {
            let route = HermesGatewayPolicy.route(for: surface)
            let requiresStructuredEvidence = HermesGatewayPolicy.requiresStructuredEvidenceReturn(surface)

            switch route {
            case .directSubstrate, .inProcessLocalPrompt:
                #expect(!requiresStructuredEvidence)
            case .localAgentGateway:
                #expect(requiresStructuredEvidence)
                #expect(HermesGatewayPolicy.evidenceReturn(for: surface) == .structuredEvidenceProvenance)
            }
        }
    }
}
