import Foundation
import Testing
@testable import Epistemos

@MainActor
@Suite("Sovereign Gate")
struct SovereignGateTests {
    private final class FakeAuthenticator: SovereignGateAuthenticating {
        private var results: [Bool]
        private(set) var requests: [(policy: SovereignGateAuthenticationPolicy, reason: String)] = []

        init(results: [Bool] = [true]) {
            self.results = results
        }

        func authenticate(
            policy: SovereignGateAuthenticationPolicy,
            reason: String
        ) async -> Bool {
            requests.append((policy, reason))
            guard !results.isEmpty else { return true }
            return results.removeFirst()
        }
    }

    @Test("None requirement allows without prompting")
    func noneRequirementAllowsWithoutPrompting() async {
        let authenticator = FakeAuthenticator()
        let gate = SovereignGate(authenticator: authenticator)

        let outcome = await gate.confirm(.none, reason: "", now: Date(timeIntervalSince1970: 1_000))

        #expect(outcome == .allowed)
        #expect(authenticator.requests.isEmpty)
    }

    @Test("Biometric requirement caches only within category and grace")
    func biometricRequirementCachesOnlyWithinCategoryAndGrace() async {
        let authenticator = FakeAuthenticator(results: [true, true, true])
        let gate = SovereignGate(authenticator: authenticator)
        let export = SovereignGateCategory(rawValue: "export")
        let share = SovereignGateCategory(rawValue: "share")
        let start = Date(timeIntervalSince1970: 2_000)

        #expect(await gate.confirm(.biometric(category: export), reason: "Export note", now: start) == .allowed)
        #expect(
            await gate.confirm(
                .biometric(category: export),
                reason: "Export note again",
                now: start.addingTimeInterval(899)
            ) == .allowed
        )
        #expect(
            await gate.confirm(
                .biometric(category: share),
                reason: "Share note",
                now: start.addingTimeInterval(100)
            ) == .allowed
        )
        #expect(
            await gate.confirm(
                .biometric(category: export),
                reason: "Export after grace",
                now: start.addingTimeInterval(901)
            ) == .allowed
        )

        #expect(authenticator.requests.map(\.policy) == [
            .deviceOwnerAuthenticationWithBiometrics,
            .deviceOwnerAuthenticationWithBiometrics,
            .deviceOwnerAuthenticationWithBiometrics,
        ])
        #expect(authenticator.requests.map(\.reason) == [
            "Export note",
            "Share note",
            "Export after grace",
        ])
    }

    @Test("Clearing grace forces the next biometric prompt")
    func clearingGraceForcesNextBiometricPrompt() async {
        let authenticator = FakeAuthenticator(results: [true, true])
        let gate = SovereignGate(authenticator: authenticator)
        let category = SovereignGateCategory(rawValue: "oauth")
        let start = Date(timeIntervalSince1970: 3_000)

        #expect(await gate.confirm(.biometric(category: category), reason: "Grant OAuth", now: start) == .allowed)
        gate.clearGrace()
        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Grant OAuth again",
                now: start.addingTimeInterval(10)
            ) == .allowed
        )

        #expect(authenticator.requests.count == 2)
    }

    @Test("Biometric grace rejects clock rollback and invalid durations")
    func biometricGraceRejectsClockRollbackAndInvalidDurations() async {
        let authenticator = FakeAuthenticator(results: [true, true, true, true])
        let gate = SovereignGate(authenticator: authenticator)
        let category = SovereignGateCategory(rawValue: "vault-export")
        let start = Date(timeIntervalSince1970: 3_500)

        #expect(await gate.confirm(.biometric(category: category), reason: "Export vault", now: start) == .allowed)
        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Export after clock rollback",
                now: start.addingTimeInterval(-1)
            ) == .allowed
        )
        #expect(
            await gate.confirm(
                .biometric(category: category, graceDuration: .infinity),
                reason: "Export with invalid grace",
                now: start.addingTimeInterval(1)
            ) == .allowed
        )
        #expect(
            await gate.confirm(
                .biometric(category: category, graceDuration: 0),
                reason: "Export with zero grace",
                now: start.addingTimeInterval(2)
            ) == .allowed
        )

        #expect(authenticator.requests.count == 4)
    }

    @Test("Device-owner authentication prompts every time")
    func deviceOwnerAuthenticationPromptsEveryTime() async {
        let authenticator = FakeAuthenticator(results: [true, true])
        let gate = SovereignGate(authenticator: authenticator)
        let start = Date(timeIntervalSince1970: 4_000)

        #expect(await gate.confirm(.deviceOwnerAuthentication, reason: "Empty trash", now: start) == .allowed)
        #expect(
            await gate.confirm(
                .deviceOwnerAuthentication,
                reason: "Empty trash again",
                now: start.addingTimeInterval(1)
            ) == .allowed
        )

        #expect(authenticator.requests.map(\.policy) == [
            .deviceOwnerAuthentication,
            .deviceOwnerAuthentication,
        ])
    }

    @Test("Failed biometric authentication denies and does not grant grace")
    func failedBiometricAuthenticationDeniesAndDoesNotGrantGrace() async {
        let authenticator = FakeAuthenticator(results: [false, true])
        let gate = SovereignGate(authenticator: authenticator)
        let category = SovereignGateCategory(rawValue: "delete")
        let start = Date(timeIntervalSince1970: 5_000)

        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Soft delete",
                now: start
            ) == .denied(.authenticationFailed)
        )
        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Soft delete retry",
                now: start.addingTimeInterval(1)
            ) == .allowed
        )

        #expect(authenticator.requests.count == 2)
    }

    @Test("Prompting requirements reject empty reasons before authentication")
    func promptingRequirementsRejectEmptyReasonsBeforeAuthentication() async {
        let authenticator = FakeAuthenticator()
        let gate = SovereignGate(authenticator: authenticator)

        #expect(
            await gate.confirm(
                .biometric(category: SovereignGateCategory(rawValue: "export")),
                reason: "   ",
                now: Date(timeIntervalSince1970: 6_000)
            ) == .denied(.missingReason)
        )
        #expect(
            await gate.confirm(
                .deviceOwnerAuthentication,
                reason: "",
                now: Date(timeIntervalSince1970: 6_001)
            ) == .denied(.missingReason)
        )
        #expect(authenticator.requests.isEmpty)
    }
}
