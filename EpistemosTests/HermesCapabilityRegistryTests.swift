import Foundation
import Testing
@testable import Epistemos

@Suite("Hermes Capability Registry")
struct HermesCapabilityRegistryTests {
    @Test("registry covers every command row in the Hermes parity target")
    func registryCoversEveryCommandRowInHermesParityTarget() throws {
        let source = try loadMirroredSourceTextFile(
            "docs/fusion/fleet/hermes-capability-pass-through/HERMES_CAPABILITY_PARITY_TARGET_2026_05_03.md"
        )
        let documented = Self.documentedCommandPatterns(in: source)
        let registered = HermesCapabilityRegistry.commandPatterns
        let missing = documented.subtracting(registered).sorted()

        #expect(!documented.isEmpty)
        #expect(
            missing.isEmpty,
            "Missing Hermes capability registry rows: \(missing.joined(separator: ", "))"
        )
    }

    @Test("Core App Store distribution exposes only native Core-owned rows")
    func coreAppStoreDistributionExposesOnlyNativeCoreRows() {
        let coreCapabilities = HermesCapabilityRegistry.capabilities(for: .coreAppStore)

        #expect(!coreCapabilities.isEmpty)
        for capability in coreCapabilities {
            #expect(capability.tier == .core)
            #expect(capability.owner == .nativeCore)
            #expect(!capability.requiresNetwork)
            #expect(!capability.requiresSubprocess)
            #expect(!capability.structuredEvidence)
        }
    }

    @Test("Pro Research distribution keeps gateway rows visible")
    func proResearchDistributionKeepsGatewayRowsVisible() {
        let proPatterns = Set(
            HermesCapabilityRegistry.capabilities(for: .proResearch).map(\.commandPattern)
        )

        for command in [
            "/run <command>",
            "/shell",
            "/mcp connect <url>",
            "/web search <query>",
            "/reply",
            "browser",
            "code_execution",
        ] {
            #expect(proPatterns.contains(command), "\(command) must remain visible to Pro/Research Hermes gateway")
        }
    }

    @Test("Core deterministic commands stay direct and approval-light")
    func coreDeterministicCommandsStayDirectAndApprovalLight() throws {
        let calc = try #require(HermesCapabilityRegistry.capability(commandPattern: "/calc <expression>"))
        let help = try #require(HermesCapabilityRegistry.capability(commandPattern: "/help"))
        let status = try #require(HermesCapabilityRegistry.capability(commandPattern: "/status"))

        for capability in [calc, help, status] {
            #expect(capability.tier == .core)
            #expect(capability.owner == .nativeCore)
            #expect(!capability.requiresNetwork)
            #expect(!capability.requiresSubprocess)
            #expect(!capability.requiresApproval)
            #expect(!capability.structuredEvidence)
        }
    }

    @Test("external side-effect commands require gateway evidence and approval where destructive")
    func externalSideEffectCommandsRequireGatewayEvidenceAndApprovalWhereDestructive() throws {
        let run = try #require(HermesCapabilityRegistry.capability(commandPattern: "/run <command>"))
        let shell = try #require(HermesCapabilityRegistry.capability(commandPattern: "/shell"))
        let kill = try #require(HermesCapabilityRegistry.capability(commandPattern: "/kill <pid>"))
        let mcpConnect = try #require(HermesCapabilityRegistry.capability(commandPattern: "/mcp connect <url>"))

        for capability in [run, shell, kill, mcpConnect] {
            #expect(capability.owner == .hermesGateway)
            #expect(capability.tier == .pro)
            #expect(capability.requiresApproval)
            #expect(capability.structuredEvidence)
            #expect(capability.hermesPassthrough)
        }
    }

    @Test("destructive native state commands still require approval")
    func destructiveNativeStateCommandsStillRequireApproval() throws {
        for command in [
            "/todo clear",
            "/memory clear",
            "/notebook clear",
            "/persona delete <name>",
            "/persona reset",
            "/config edit",
        ] {
            let capability = try #require(HermesCapabilityRegistry.capability(commandPattern: command))
            #expect(capability.tier == .core)
            #expect(capability.owner == .nativeCore)
            #expect(capability.requiresApproval)
        }
    }

    @Test("registry keeps Hermes as gateway not substrate authority")
    func registryKeepsHermesAsGatewayNotSubstrateAuthority() {
        for capability in HermesCapabilityRegistry.all where capability.owner == .hermesGateway {
            #expect(capability.structuredEvidence)
            #expect(capability.hermesPassthrough)
            #expect(capability.tier == .pro)
        }
    }

    private static func documentedCommandPatterns(in source: String) -> Set<String> {
        let pattern = #"^\| `([^`]+)` \|"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return []
        }
        let range = NSRange(source.startIndex..., in: source)
        let matches = regex.matches(in: source, options: [], range: range)

        return Set(matches.compactMap { match in
            guard let commandRange = Range(match.range(at: 1), in: source) else {
                return nil
            }
            return String(source[commandRange])
        })
    }
}
