import Foundation
import LocalAuthentication
import SwiftUI

// ---------------------------------------------------------------------------
// MARK: - SovereignGate
// ---------------------------------------------------------------------------

/// Unified biometric authorization gate for destructive and sensitive actions.
///
/// `SovereignGate` is the single `LAContext` entrypoint for the entire app.
/// It maps action classes to authentication requirements per doctrine §4.2:
///
/// | Action class | Requirement |
/// |--------------|-------------|
/// | Destructive  | `.deviceOwnerAuthentication` (Touch ID + passcode fallback) |
/// | Sensitive    | `.deviceOwnerAuthenticationWithBiometrics` |
/// | Normal       | No gate |
///
/// In production this is backed by the `BiometricAuthenticator` actor and
/// integrates with the App Group security context.
@MainActor
public final class SovereignGate: @unchecked Sendable {
    /// Shared singleton.
    public static let shared = SovereignGate()

    private init() {}

    /// Authorisation requirement levels.
    public enum Requirement {
        /// Touch ID / Face ID only.
        case biometricsOnly
        /// Touch ID / Face ID with device-passcode fallback.
        case deviceOwnerAuthentication
    }

    /// Result of a gate evaluation.
    public enum GateResult: Equatable {
        case granted
        case denied
        case cancelled
        case unavailable
    }

    /// Confirm a destructive action behind biometric authentication.
    ///
    /// - Parameters:
    ///   - requirement: The authentication requirement.
    ///   - reason: The localized string shown in the system dialog.
    /// - Returns: `.granted` if the user authenticated successfully.
    public func confirm(
        requirement: Requirement,
        reason: String = "Authenticate to proceed"
    ) async -> GateResult {
        let context = LAContext()
        var error: NSError?

        let policy: LAPolicy = switch requirement {
        case .biometricsOnly:
            .deviceOwnerAuthenticationWithBiometrics
        case .deviceOwnerAuthentication:
            .deviceOwnerAuthentication
        }

        guard context.canEvaluatePolicy(policy, error: &error) else {
            if let err = error {
                print("[SovereignGate] unavailable: \(err.localizedDescription)")
            }
            return .unavailable
        }

        do {
            let success = try await context.evaluatePolicy(policy, localizedReason: reason)
            return success ? .granted : .denied
        } catch LAError.userCancel {
            return .cancelled
        } catch {
            print("[SovereignGate] evaluation failed: \(error.localizedDescription)")
            return .denied
        }
    }

    /// Gated wrapper: run `operation` only if authentication succeeds.
    ///
    /// Throws `SovereignGateError.denied` on failure or cancellation.
    public func gate(
        requirement: Requirement,
        reason: String = "Authenticate to proceed",
        operation: () async throws -> Void
    ) async throws {
        let result = await confirm(requirement: requirement, reason: reason)
        switch result {
        case .granted:
            try await operation()
        case .cancelled:
            throw SovereignGateError.cancelled
        case .denied, .unavailable:
            throw SovereignGateError.denied
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - SovereignGateError
// ---------------------------------------------------------------------------

public enum SovereignGateError: Error, LocalizedError {
    case denied
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .denied:    return "Sovereign Gate denied the action."
        case .cancelled: return "Sovereign Gate authentication was cancelled."
        }
    }
}
