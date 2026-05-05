import Foundation
import Testing

@testable import Epistemos

@Suite("Hermes XPC Skeleton")
struct XPCSmokeTests {
    @Test("XPC service names use canonical App Group Mach prefix")
    func xpcServiceNamesUseCanonicalAppGroupPrefix() {
        #expect(EpistemosXPCServiceNames.appGroupIdentifier == "group.com.epistemos.shared")
        #expect(EpistemosXPCServiceNames.agentService == "group.com.epistemos.shared.AgentXPC")
        #expect(EpistemosXPCServiceNames.providerService == "group.com.epistemos.shared.ProviderXPC")
        #expect(!EpistemosXPCServiceNames.agentService.contains("Epistenos"))
        #expect(!EpistemosXPCServiceNames.providerService.contains("epistenos"))
    }

    @Test("AgentXPC envelope delegates slash parsing to HermesCommandDispatcher parseCore")
    func agentEnvelopeDelegatesToHermesCoreParser() {
        let calc = AgentXPCCommandEnvelope.response(for: "/calc 1 + 2")
        let todo = AgentXPCCommandEnvelope.response(for: "/todo add finish XPC skeleton")
        let unknown = AgentXPCCommandEnvelope.response(for: "/not-a-command")

        #expect(calc[XPCEnvelopeKeys.status] as? String == "parsed")
        #expect(calc[XPCEnvelopeKeys.command] as? String == "/calc")
        #expect(calc[XPCEnvelopeKeys.requiresApproval] as? Bool == false)

        #expect(todo[XPCEnvelopeKeys.status] as? String == "parsed")
        #expect(todo[XPCEnvelopeKeys.command] as? String == "/todo")
        #expect(todo[XPCEnvelopeKeys.requiresApproval] as? Bool == false)

        #expect(unknown[XPCEnvelopeKeys.status] as? String == "unknown")
    }

    @Test("ProviderXPC envelope preserves Hermes gateway tier classification")
    func providerEnvelopePreservesGatewayClassification() {
        let openAI = ProviderXPCSurfaceEnvelope.response(for: "openai")
        let localPrompt = ProviderXPCSurfaceEnvelope.response(for: "local-prompt")
        let cli = ProviderXPCSurfaceEnvelope.response(for: "multi-cli")

        #expect(openAI[XPCEnvelopeKeys.status] as? String == "classified")
        #expect(openAI[XPCEnvelopeKeys.tier] as? String == HermesGatewayTier.proResearch.rawValue)
        #expect(openAI[XPCEnvelopeKeys.route] as? String == HermesGatewayRoute.hermesGateway.rawValue)
        #expect(openAI[XPCEnvelopeKeys.requiresNetwork] as? Bool == true)
        #expect(openAI[XPCEnvelopeKeys.requiresSubprocess] as? Bool == false)
        #expect(openAI[XPCEnvelopeKeys.evidenceReturn] as? String == HermesGatewayEvidenceReturn.structuredEvidenceProvenance.rawValue)

        #expect(localPrompt[XPCEnvelopeKeys.tier] as? String == HermesGatewayTier.core.rawValue)
        #expect(localPrompt[XPCEnvelopeKeys.route] as? String == HermesGatewayRoute.inProcessLocalPrompt.rawValue)

        #expect(cli[XPCEnvelopeKeys.tier] as? String == HermesGatewayTier.proResearch.rawValue)
        #expect(cli[XPCEnvelopeKeys.requiresSubprocess] as? Bool == true)
        #expect(cli[XPCEnvelopeKeys.evidenceReturn] as? String == HermesGatewayEvidenceReturn.structuredEvidenceProvenance.rawValue)
    }

    @Test("XPC source skeleton keeps services thin and canonical")
    func xpcSourceSkeletonKeepsServicesThinAndCanonical() throws {
        let files = [
            "Epistemos/XPC/AgentServiceProtocol.swift",
            "Epistemos/XPC/AgentServiceClient.swift",
            "Epistemos/XPC/ProviderServiceClient.swift",
            "XPCServices/AgentXPC/AgentService.swift",
            "XPCServices/AgentXPC/main.swift",
            "XPCServices/ProviderXPC/ProviderService.swift",
            "XPCServices/ProviderXPC/main.swift",
        ]

        for file in files {
            let source = try loadRepoSourceTextFile(file)

            #expect(!source.contains("Epistenos"))
            #expect(!source.contains("group.com.epistenos.shared"))
            #expect(!source.contains("Process()"))
            #expect(!source.contains("Subprocess("))
        }

        let agentService = try loadRepoSourceTextFile("XPCServices/AgentXPC/AgentService.swift")
        let providerService = try loadRepoSourceTextFile("XPCServices/ProviderXPC/ProviderService.swift")

        #expect(agentService.contains("AgentXPCCommandEnvelope.response(for: rawCommand)"))
        #expect(providerService.contains("ProviderXPCSurfaceEnvelope.response(for: surfaceName)"))
    }

    private func loadRepoSourceTextFile(_ relativePath: String) throws -> String {
        try loadMirroredSourceTextFile(relativePath)
    }
}
