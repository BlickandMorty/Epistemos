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
        if case .biometricSession = self { return true }
        return false
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
    let surface: String
    let metadata: [String: String]
    let signatureHex: String

    var isExpired: Bool {
        expiresAtUnix <= CapabilityBridgeClock.nowUnix()
    }
}

nonisolated enum CapabilityBridgeDenial: Error, Sendable {
    case invalidTTL
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
        surface: String,
        ttlSecs: UInt32,
        distribution: ToolSurfacePolicy.Distribution = .currentBuild,
        reason: String,
        metadata: [String: String] = [:],
        now: Date = Date()
    ) async -> Result<CapabilityGrant, CapabilityBridgeDenial> {
        _ = distribution
        guard ttlSecs > 0 else {
            return .failure(.invalidTTL)
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
            metadata: grantMetadata,
            signatureHex: ""
        )
        return .success(sign(unsigned))
    }

    func verifyGrant(
        _ grant: CapabilityGrant,
        expectedSubject: CapabilityBridgeSubject? = nil,
        expectedSurface: String? = nil,
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
        expectedSurface: String? = nil,
        expectedKind: CapabilityGrantKind? = nil,
        now: Date = Date()
    ) -> CapabilityBridgeDenial? {
        guard grant.expiresAtUnix > CapabilityBridgeClock.nowUnix(now) else {
            return .expired
        }
        guard expectedSubject == nil || grant.subject == expectedSubject,
              expectedSurface == nil || grant.surface == expectedSurface,
              expectedKind == nil || grant.kind == expectedKind else {
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
        allows surface: String
    ) -> Bool {
        _ = (subject, surface)
        return true
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
            "surface=\(grant.surface)",
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
            metadata: metadata,
            signatureHex: ""
        )
    }
}

private extension Data {
    var hexEncodedLowercase: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
