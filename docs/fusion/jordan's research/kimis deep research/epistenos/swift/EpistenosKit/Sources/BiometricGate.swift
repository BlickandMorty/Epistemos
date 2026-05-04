import Foundation
import SwiftUI
import LocalAuthentication

// ---------------------------------------------------------------------------
// MARK: - BiometricAuthenticator
// ---------------------------------------------------------------------------

/// Thin wrapper around `LocalAuthentication` that exposes an `async` interface.
///
/// Use `BiometricAuthenticator` when you need an imperative authentication
/// flow (e.g. before a file-system write). For declarative UI gating, use
/// the `BiometricWriteGate` ViewModifier.
public actor BiometricAuthenticator {
    /// Authenticate the user with biometrics (Touch ID / Face ID).
    ///
    /// - Parameter reason: The localised string shown in the system dialog.
    /// - Returns: A `BiometricResult` describing success, cancellation, or failure.
    public func authenticate(reason: String) async -> BiometricResult {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Biometrics not available — fall back to device passcode if desired.
            // For Epistenos we treat unavailability as Failure on the write path.
            if let err = error {
                print("[BiometricAuthenticator] biometrics unavailable: \(err.localizedDescription)")
            }
            return .failed
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success ? .success : .failed
        } catch LAError.userCancel {
            return .cancelled
        } catch {
            print("[BiometricAuthenticator] evaluation failed: \(error.localizedDescription)")
            return .failed
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - BiometricWriteGate (imperative)
// ---------------------------------------------------------------------------

/// Gates an async closure behind biometric authentication.
///
/// Example:
/// ```swift
/// let gate = BiometricWriteGate()
/// try await gate.gate(reason: "Save note") {
///     try data.write(to: fileURL)
/// }
/// ```
public struct BiometricWriteGate {
    private let authenticator = BiometricAuthenticator()

    public init() {}

    /// Run `operation` only if biometric authentication succeeds.
    public func gate(
        reason: String = "Authenticate to proceed",
        operation: @escaping () async throws -> Void
    ) async throws {
        let result = await authenticator.authenticate(reason: reason)
        switch result {
        case .success:
            try await operation()
        case .cancelled:
            throw BiometricError.cancelled
        case .failed:
            throw BiometricError.failed
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - BiometricWriteGate (ViewModifier)
// ---------------------------------------------------------------------------

/// A `ViewModifier` that wraps any write operation in a biometric sheet.
///
/// Apply with `.biometricGated(reason: "...")` to any button or toolbar item.
public struct BiometricGatedModifier: ViewModifier {
    let reason: String
    @State private var isPresenting = false
    @State private var pendingAction: (() -> Void)?

    public func body(content: Content) -> some View {
        content
            .environment(\.biometricGatedAction, BiometricGatedAction { action in
                pendingAction = action
                isPresenting = true
            })
            .sheet(isPresented: $isPresenting) {
                BiometricSheet(reason: reason) { result in
                    isPresenting = false
                    if result == .success {
                        pendingAction?()
                    }
                    pendingAction = nil
                }
            }
    }
}

extension View {
    /// Wraps interactive elements in this view hierarchy behind a biometric prompt.
    public func biometricGated(reason: String) -> some View {
        modifier(BiometricGatedModifier(reason: reason))
    }
}

// ---------------------------------------------------------------------------
// MARK: - Environment Key for Biometric Gated Actions
// ---------------------------------------------------------------------------

public struct BiometricGatedAction {
    public let trigger: (@escaping () -> Void) -> Void
}

public struct BiometricGatedActionKey: EnvironmentKey {
    public static let defaultValue: BiometricGatedAction? = nil
}

extension EnvironmentValues {
    public var biometricGatedAction: BiometricGatedAction? {
        get { self[BiometricGatedActionKey.self] }
        set { self[BiometricGatedActionKey.self] = newValue }
    }
}

// ---------------------------------------------------------------------------
// MARK: - BiometricSheet (internal)
// ---------------------------------------------------------------------------

public struct BiometricSheet: View {
    let reason: String
    let onComplete: (BiometricResult) -> Void
    @State private var isEvaluating = false
    @State private var result: BiometricResult?

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "touchid")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(reason)
                .font(.headline)
                .multilineTextAlignment(.center)

            if let result = result {
                statusView(for: result)
            } else if isEvaluating {
                ProgressView()
                    .scaleEffect(1.2)
            } else {
                Button("Authenticate") {
                    evaluate()
                }
                .buttonStyle(.borderedProminent)

                Button("Cancel", role: .cancel) {
                    onComplete(.cancelled)
                }
            }
        }
        .padding(32)
        .frame(minWidth: 300, minHeight: 220)
    }

    private func statusView(for result: BiometricResult) -> some View {
        VStack(spacing: 8) {
            switch result {
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title)
                Text("Authenticated")
                    .foregroundStyle(.green)
            case .cancelled:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.orange)
                    .font(.title)
                Text("Cancelled")
                    .foregroundStyle(.orange)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.title)
                Text("Failed")
                    .foregroundStyle(.red)
            }
        }
    }

    private func evaluate() {
        isEvaluating = true
        Task {
            let auth = BiometricAuthenticator()
            let res = await auth.authenticate(reason: reason)
            await MainActor.run {
                isEvaluating = false
                result = res
                if res == .success {
                    // Brief delay so the user sees the success icon.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        onComplete(res)
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// MARK: - Errors
// ---------------------------------------------------------------------------

public enum BiometricError: Error, LocalizedError {
    case cancelled
    case failed

    public var errorDescription: String? {
        switch self {
        case .cancelled: return "Biometric authentication was cancelled."
        case .failed:    return "Biometric authentication failed."
        }
    }
}
