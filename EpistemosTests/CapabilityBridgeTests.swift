import Foundation
import Testing

@testable import Epistemos

@Suite("Capability Bridge")
struct CapabilityBridgeTests {
    private let signingKey = Data("capability-bridge-test-key-32-bytes".utf8)

    @Test("Core App Store distribution denies external Hermes gateway surfaces")
    func coreDistributionDeniesExternalGatewaySurfaces() async throws {
        let bridge = CapabilityBridge(signingKey: signingKey)
        for surface in HermesGatewaySurface.externalGatewaySurfaces {
            let result = await bridge.issueGrant(
                subject: .providerXPC,
                kind: .other(name: "external"),
                surface: surface,
                ttlSecs: 60,
                distribution: .coreAppStore,
                reason: "Core should not grant external gateway capabilities",
                now: Self.fixedNow
            )

            guard case .failure(.coreDistributionDenied(let deniedSurface)) = result else {
                Issue.record("Expected Core distribution denial for \(surface)")
                continue
            }
            #expect(deniedSurface == surface)
        }
    }

    @Test("Biometric session grants use donor shape and call the authorizer")
    func biometricSessionGrantUsesDonorShapeAndAuthorizer() async throws {
        let counter = CapabilityBridgeAuthorizerCounter()
        let bridge = CapabilityBridge(signingKey: signingKey) { requirement, reason in
            await counter.record(requirement: requirement, reason: reason)
            return .allowed
        }

        let grant = try await #require(bridge.issueGrant(
            subject: .agentXPC,
            kind: .biometricSession(ttlSecs: 120),
            surface: .localPromptFormatting,
            ttlSecs: 120,
            distribution: .proResearch,
            reason: "Approve local prompt capability",
            now: Self.fixedNow
        ).success)

        let snapshot = await counter.snapshot()
        #expect(snapshot.calls == 1)
        #expect(snapshot.reason == "Approve local prompt capability")
        #expect(snapshot.wasBiometric)
        #expect(snapshot.graceDuration == 120)
        #expect(grant.metadata["capability_donor_shape"] == "Capability::BiometricSession { ttl_secs }")
        #expect(grant.metadata["ttl_secs"] == "120")
        #expect(bridge.verifyGrant(
            grant,
            expectedSubject: .agentXPC,
            expectedSurface: .localPromptFormatting,
            expectedKind: .biometricSession(ttlSecs: 120),
            now: Self.fixedNow.addingTimeInterval(10)
        ))
    }

    @Test("Failed Sovereign authorization denies biometric session issuance")
    func failedSovereignAuthorizationDeniesIssue() async throws {
        let bridge = CapabilityBridge(signingKey: signingKey) { _, _ in
            .denied(.authenticationFailed)
        }

        let result = await bridge.issueGrant(
            subject: .agentXPC,
            kind: .biometricSession(ttlSecs: 90),
            surface: .localPromptFormatting,
            ttlSecs: 90,
            distribution: .proResearch,
            reason: "Approval denied",
            now: Self.fixedNow
        )

        guard case .failure(.sovereignDenied(let reason)) = result else {
            Issue.record("Expected Sovereign denial")
            return
        }
        #expect(String(describing: reason) == "authenticationFailed")
    }

    @Test("Expired grants and tampered signatures fail verification")
    func expiredAndTamperedGrantsFailVerification() async throws {
        let bridge = CapabilityBridge(signingKey: signingKey)
        let grant = try await #require(bridge.issueGrant(
            subject: .providerXPC,
            kind: .networkHost(host: "api.example.com"),
            surface: .openAIProvider,
            ttlSecs: 30,
            distribution: .proResearch,
            reason: "Provider gateway test",
            metadata: ["provider": "openai"],
            now: Self.fixedNow
        ).success)

        #expect(bridge.verifyGrant(grant, expectedSubject: .providerXPC, now: Self.fixedNow.addingTimeInterval(10)))
        #expect(!bridge.verifyGrant(grant, expectedSubject: .providerXPC, now: Self.fixedNow.addingTimeInterval(31)))

        let tampered = CapabilityGrant(
            id: grant.id,
            subject: grant.subject,
            kind: .networkHost(host: "api.evil.example"),
            issuedAtUnix: grant.issuedAtUnix,
            expiresAtUnix: grant.expiresAtUnix,
            surface: grant.surface,
            tier: grant.tier,
            route: grant.route,
            metadata: grant.metadata,
            signatureHex: grant.signatureHex
        )
        #expect(!bridge.verifyGrant(tampered, expectedSubject: .providerXPC, now: Self.fixedNow.addingTimeInterval(10)))
    }

    @Test("Subject surface boundaries preserve AgentXPC and ProviderXPC split")
    func subjectSurfaceBoundariesPreserveXPCSplit() {
        #expect(CapabilityBridge.subject(.agentXPC, allows: .deterministicLocalSubstrate))
        #expect(CapabilityBridge.subject(.agentXPC, allows: .localPromptFormatting))
        #expect(!CapabilityBridge.subject(.agentXPC, allows: .cloudProvider))
        #expect(!CapabilityBridge.subject(.agentXPC, allows: .cliDelegation))

        #expect(!CapabilityBridge.subject(.providerXPC, allows: .localPromptFormatting))
        #expect(CapabilityBridge.subject(.providerXPC, allows: .openAIProvider))
        #expect(CapabilityBridge.subject(.providerXPC, allows: .cliDelegation))
    }

    @Test("CapabilityBridge source stays policy-only and delegates authentication")
    func capabilityBridgeSourceGuard() throws {
        let source = try loadRepoSourceTextFile("Epistemos/Security/CapabilityBridge.swift")

        for forbidden in [
            "LAContext",
            "canEvaluatePolicy",
            "evaluatePolicy",
            "Process()",
            "Subprocess(",
            "URLSession",
            "NSWorkspace",
        ] {
            #expect(!source.contains(forbidden), "CapabilityBridge.swift must not contain \(forbidden)")
        }

        #expect(source.contains("SovereignGateRequirement"))
        #expect(source.contains("HermesGatewayPolicy.decision"))
        #expect(source.contains("ToolSurfacePolicy.resolvedDistribution"))
        #expect(source.contains("Capability::BiometricSession { ttl_secs }"))
        #expect(source.contains("HMAC<SHA256>"))
    }

    private static let fixedNow = Date(timeIntervalSince1970: 1_775_000_000)

    private func loadRepoSourceTextFile(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}

private extension Result where Failure == CapabilityBridgeDenial {
    var success: Success? {
        if case .success(let value) = self {
            value
        } else {
            nil
        }
    }
}

private actor CapabilityBridgeAuthorizerCounter {
    private var calls = 0
    private var reason: String?
    private var wasBiometric = false
    private var graceDuration: TimeInterval?

    func record(requirement: SovereignGateRequirement, reason: String) {
        calls += 1
        self.reason = reason
        if case .biometric(_, let graceDuration) = requirement {
            wasBiometric = true
            self.graceDuration = graceDuration
        }
    }

    func snapshot() -> (calls: Int, reason: String?, wasBiometric: Bool, graceDuration: TimeInterval?) {
        (calls, reason, wasBiometric, graceDuration)
    }
}
