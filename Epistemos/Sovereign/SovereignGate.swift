import Foundation
import LocalAuthentication

struct SovereignGateCategory: Hashable, Sendable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

enum SovereignGateRequirement: Equatable, Sendable {
    case none
    case biometric(category: SovereignGateCategory, graceDuration: TimeInterval = 15 * 60)
    case deviceOwnerAuthentication
}

enum SovereignGateAuthenticationPolicy: Equatable, Sendable {
    case deviceOwnerAuthenticationWithBiometrics
    case deviceOwnerAuthentication

    fileprivate var laPolicy: LAPolicy {
        switch self {
        case .deviceOwnerAuthenticationWithBiometrics:
            .deviceOwnerAuthenticationWithBiometrics
        case .deviceOwnerAuthentication:
            .deviceOwnerAuthentication
        }
    }
}

enum SovereignGateDenialReason: Equatable, Sendable {
    case missingReason
    case authenticationFailed
}

enum SovereignGateOutcome: Equatable, Sendable {
    case allowed
    case denied(SovereignGateDenialReason)
}

@MainActor
protocol SovereignGateAuthenticating: AnyObject {
    func authenticate(
        policy: SovereignGateAuthenticationPolicy,
        reason: String
    ) async -> Bool
}

@MainActor
final class SovereignGate {
    private let authenticator: SovereignGateAuthenticating
    private var sensitiveApprovals: [SovereignGateCategory: Date] = [:]

    init(authenticator: SovereignGateAuthenticating = LocalAuthenticationSovereignAuthenticator()) {
        self.authenticator = authenticator
    }

    @discardableResult
    func confirm(
        _ requirement: SovereignGateRequirement,
        reason: String,
        now: Date = Date()
    ) async -> SovereignGateOutcome {
        switch requirement {
        case .none:
            return .allowed
        case let .biometric(category, graceDuration):
            return await confirmBiometric(
                category: category,
                graceDuration: graceDuration,
                reason: reason,
                now: now
            )
        case .deviceOwnerAuthentication:
            return await authenticateEveryTime(
                policy: .deviceOwnerAuthentication,
                reason: reason
            )
        }
    }

    func clearGrace() {
        sensitiveApprovals.removeAll(keepingCapacity: true)
    }

    private func confirmBiometric(
        category: SovereignGateCategory,
        graceDuration: TimeInterval,
        reason: String,
        now: Date
    ) async -> SovereignGateOutcome {
        guard graceDuration.isFinite, graceDuration > 0 else {
            return await authenticateEveryTime(
                policy: .deviceOwnerAuthenticationWithBiometrics,
                reason: reason
            )
        }

        if let approvedAt = sensitiveApprovals[category] {
            let elapsed = now.timeIntervalSince(approvedAt)
            if elapsed >= 0, elapsed < graceDuration {
                return .allowed
            }
        }

        let outcome = await authenticateEveryTime(
            policy: .deviceOwnerAuthenticationWithBiometrics,
            reason: reason
        )
        if outcome == .allowed {
            sensitiveApprovals[category] = now
        }
        return outcome
    }

    private func authenticateEveryTime(
        policy: SovereignGateAuthenticationPolicy,
        reason: String
    ) async -> SovereignGateOutcome {
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .denied(.missingReason)
        }

        let didAuthenticate = await authenticator.authenticate(
            policy: policy,
            reason: reason
        )
        return didAuthenticate ? .allowed : .denied(.authenticationFailed)
    }
}

@MainActor
private final class LocalAuthenticationSovereignAuthenticator: SovereignGateAuthenticating {
    func authenticate(
        policy: SovereignGateAuthenticationPolicy,
        reason: String
    ) async -> Bool {
        let context = LAContext()
        do {
            return try await context.evaluatePolicy(policy.laPolicy, localizedReason: reason)
        } catch {
            return false
        }
    }
}
