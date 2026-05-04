import CryptoKit
import Foundation

nonisolated enum CapabilityBridgeSubject: String, CaseIterable, Sendable {
    case agentXPC = "agent_xpc"
    case providerXPC = "provider_xpc"

    var serviceName: String {
        switch self {
        case .agentXPC:
            EpistemosXPCServiceNames.agentService
        case .providerXPC:
            EpistemosXPCServiceNames.providerService
        }
    }
}

nonisolated enum CapabilityGrantKind: Equatable, Sendable {
    case vaultPath(path: String, verb: String)
    case networkHost(host: String)
    case biometricSession(ttlSecs: UInt32)
    case other(name: String)

    var donorShape: String {
        switch self {
        case .vaultPath:
            "Capability::VaultPath { path, verb }"
        case .networkHost:
            "Capability::NetworkHost { host }"
        case .biometricSession:
            "Capability::BiometricSession { ttl_secs }"
        case .other:
            "Capability::Other { name }"
        }
    }

    var requiresSovereignApproval: Bool {
        switch self {
        case .biometricSession:
            true
        case .vaultPath, .networkHost, .other:
            false
        }
    }

    var canonicalPayload: String {
        switch self {
        case .vaultPath(let path, let verb):
            "vault_path:path=\(path);verb=\(verb)"
        case .networkHost(let host):
            "network_host:host=\(host)"
        case .biometricSession(let ttlSecs):
            "biometric_session:ttl_secs=\(ttlSecs)"
        case .other(let name):
            "other:name=\(name)"
        }
    }
}

nonisolated struct CapabilityGrant: Equatable, Sendable {
    let id: String
    let subject: CapabilityBridgeSubject
    let kind: CapabilityGrantKind
    let issuedAtUnix: UInt64
    let expiresAtUnix: UInt64
    let surface: HermesGatewaySurface
    let tier: HermesGatewayTier
    let route: HermesGatewayRoute
    let metadata: [String: String]
    let signatureHex: String

    var isExpired: Bool {
        expiresAtUnix <= CapabilityBridgeClock.nowUnix()
    }
}

nonisolated enum CapabilityBridgeDenial: Error, Sendable {
    case invalidTTL
    case coreDistributionDenied(surface: HermesGatewaySurface)
    case subjectSurfaceMismatch(subject: CapabilityBridgeSubject, surface: HermesGatewaySurface)
    case sovereignDenied(reason: SovereignGateDenialReason)
    case expired
    case signatureMismatch
    case scopeMismatch
}

nonisolated enum CapabilityBridgeClock {
    static func nowUnix(_ date: Date = Date()) -> UInt64 {
        UInt64(max(0, date.timeIntervalSince1970))
    }
}

final class CapabilityBridge {
    typealias Authorizer = @Sendable (SovereignGateRequirement, String) async -> SovereignGateOutcome

    private let signingKey: SymmetricKey
    private let authorizer: Authorizer

    init(
        signingKey: Data,
        authorizer: @escaping Authorizer = { _, _ in .allowed }
    ) {
        self.signingKey = SymmetricKey(data: signingKey)
        self.authorizer = authorizer
    }

    @MainActor
    static func live(
        signingKey: Data,
        sovereignGate: SovereignGate
    ) -> CapabilityBridge {
        CapabilityBridge(signingKey: signingKey) { requirement, reason in
            await sovereignGate.confirm(requirement, reason: reason)
        }
    }

    func issueGrant(
        subject: CapabilityBridgeSubject,
        kind: CapabilityGrantKind,
        surface: HermesGatewaySurface,
        ttlSecs: UInt32,
        distribution: ToolSurfacePolicy.Distribution = .currentBuild,
        reason: String,
        metadata: [String: String] = [:],
        now: Date = Date()
    ) async -> Result<CapabilityGrant, CapabilityBridgeDenial> {
        guard ttlSecs > 0 else {
            return .failure(.invalidTTL)
        }

        if ToolSurfacePolicy.resolvedDistribution(distribution) == .coreAppStore,
           !HermesGatewayPolicy.isAllowedInCoreAppStoreBuild(surface) {
            return .failure(.coreDistributionDenied(surface: surface))
        }

        guard Self.subject(subject, allows: surface) else {
            return .failure(.subjectSurfaceMismatch(subject: subject, surface: surface))
        }

        if kind.requiresSovereignApproval {
            let outcome = await authorizer(
                .biometric(
                    category: SovereignGateCategory(rawValue: "capability.\(subject.rawValue)"),
                    graceDuration: TimeInterval(ttlSecs)
                ),
                reason
            )
            if case .denied(let denialReason) = outcome {
                return .failure(.sovereignDenied(reason: denialReason))
            }
        }

        let issuedAt = CapabilityBridgeClock.nowUnix(now)
        let decision = HermesGatewayPolicy.decision(for: surface)
        var grantMetadata = metadata
        grantMetadata["capability_donor_shape"] = kind.donorShape
        if case .biometricSession(let ttlSecs) = kind {
            grantMetadata["ttl_secs"] = "\(ttlSecs)"
        }

        let unsigned = CapabilityGrant(
            id: UUID().uuidString,
            subject: subject,
            kind: kind,
            issuedAtUnix: issuedAt,
            expiresAtUnix: issuedAt + UInt64(ttlSecs),
            surface: surface,
            tier: decision.tier,
            route: decision.route,
            metadata: grantMetadata,
            signatureHex: ""
        )
        return .success(sign(unsigned))
    }

    func verifyGrant(
        _ grant: CapabilityGrant,
        expectedSubject: CapabilityBridgeSubject? = nil,
        expectedSurface: HermesGatewaySurface? = nil,
        expectedKind: CapabilityGrantKind? = nil,
        now: Date = Date()
    ) -> Bool {
        verifyGrantDetailed(
            grant,
            expectedSubject: expectedSubject,
            expectedSurface: expectedSurface,
            expectedKind: expectedKind,
            now: now
        ) == nil
    }

    func verifyGrantDetailed(
        _ grant: CapabilityGrant,
        expectedSubject: CapabilityBridgeSubject? = nil,
        expectedSurface: HermesGatewaySurface? = nil,
        expectedKind: CapabilityGrantKind? = nil,
        now: Date = Date()
    ) -> CapabilityBridgeDenial? {
        guard grant.expiresAtUnix > CapabilityBridgeClock.nowUnix(now) else {
            return .expired
        }
        guard expectedSubject == nil || grant.subject == expectedSubject,
              expectedSurface == nil || grant.surface == expectedSurface,
              expectedKind == nil || grant.kind == expectedKind,
              Self.subject(grant.subject, allows: grant.surface) else {
            return .scopeMismatch
        }

        let decision = HermesGatewayPolicy.decision(for: grant.surface)
        guard grant.tier == decision.tier, grant.route == decision.route else {
            return .scopeMismatch
        }

        let expectedSignature = sign(grant.withoutSignature()).signatureHex
        guard expectedSignature == grant.signatureHex else {
            return .signatureMismatch
        }
        return nil
    }

    nonisolated static func subject(
        _ subject: CapabilityBridgeSubject,
        allows surface: HermesGatewaySurface
    ) -> Bool {
        switch subject {
        case .agentXPC:
            HermesGatewayPolicy.isAllowedInCoreAppStoreBuild(surface)
        case .providerXPC:
            HermesGatewaySurface.externalGatewaySurfaces.contains(surface)
        }
    }

    private func sign(_ grant: CapabilityGrant) -> CapabilityGrant {
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(canonicalSigningPayload(for: grant).utf8),
            using: signingKey
        )
        return CapabilityGrant(
            id: grant.id,
            subject: grant.subject,
            kind: grant.kind,
            issuedAtUnix: grant.issuedAtUnix,
            expiresAtUnix: grant.expiresAtUnix,
            surface: grant.surface,
            tier: grant.tier,
            route: grant.route,
            metadata: grant.metadata,
            signatureHex: Data(signature).hexEncodedLowercase
        )
    }

    private func canonicalSigningPayload(for grant: CapabilityGrant) -> String {
        let metadataPayload = grant.metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")

        return [
            "id=\(grant.id)",
            "subject=\(grant.subject.rawValue)",
            "kind=\(grant.kind.canonicalPayload)",
            "issued_at_unix=\(grant.issuedAtUnix)",
            "expires_at_unix=\(grant.expiresAtUnix)",
            "surface=\(grant.surface.capabilityBridgeName)",
            "tier=\(grant.tier.rawValue)",
            "route=\(grant.route.rawValue)",
            "metadata=\(metadataPayload)",
        ].joined(separator: "\n")
    }
}

private extension CapabilityGrant {
    func withoutSignature() -> CapabilityGrant {
        CapabilityGrant(
            id: id,
            subject: subject,
            kind: kind,
            issuedAtUnix: issuedAtUnix,
            expiresAtUnix: expiresAtUnix,
            surface: surface,
            tier: tier,
            route: route,
            metadata: metadata,
            signatureHex: ""
        )
    }
}

private extension HermesGatewaySurface {
    var capabilityBridgeName: String {
        switch self {
        case .deterministicLocalSubstrate:
            "deterministic_local_substrate"
        case .localPromptFormatting:
            "local_prompt_formatting"
        case .cloudProvider:
            "cloud_provider"
        case .openAIProvider:
            "openai_provider"
        case .anthropicProvider:
            "anthropic_provider"
        case .googleProvider:
            "google_provider"
        case .openAICompatibleProvider:
            "openai_compatible_provider"
        case .codexAccountProvider:
            "codex_account_provider"
        case .cliDelegation:
            "cli_delegation"
        case .mcpWebTool:
            "mcp_web_tool"
        case .hermesSubprocess:
            "hermes_subprocess"
        case .browserComputerUse:
            "browser_computer_use"
        case .dockerDevcontainer:
            "docker_devcontainer"
        case .explicitExternalSideEffect:
            "explicit_external_side_effect"
        }
    }
}

private extension Data {
    var hexEncodedLowercase: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
