import AppKit
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

    @Test("Agent approval decisions map to Sovereign Gate requirements")
    func agentApprovalDecisionsMapToSovereignGateRequirements() {
        #expect(
            ChatApprovalSovereignGate.requirement(
                for: .approveOnce,
                toolName: "shell.execute"
            ) == .biometric(category: SovereignGateCategory(rawValue: "agent-tool-shell.execute"))
        )
        #expect(
            ChatApprovalSovereignGate.requirement(
                for: .applyLessInterruptions,
                toolName: "shell.execute"
            ) == .deviceOwnerAuthentication
        )
        #expect(
            ChatApprovalSovereignGate.requirement(
                for: .approveAlways,
                toolName: "shell.execute"
            ) == .deviceOwnerAuthentication
        )
        #expect(ChatApprovalSovereignGate.requirement(for: .deny, toolName: "shell.execute") == .none)
        #expect(ChatApprovalSovereignGate.requirement(for: .timedOut, toolName: "shell.execute") == .none)
        #expect(
            ChatApprovalSovereignGate.reason(
                for: .approveAlways,
                toolName: "shell.execute"
            ).contains("shell.execute")
        )
    }

    @Test("Notes sidebar permanent deletes map to destructive Sovereign Gate requirements")
    func notesSidebarDeletesMapToSovereignGateRequirements() {
        #expect(
            NotesSidebarDeletionSovereignGate.requirement(for: .page(title: "Research Notes"))
                == .deviceOwnerAuthentication
        )
        #expect(
            NotesSidebarDeletionSovereignGate.requirement(for: .folder(name: "Archive"))
                == .deviceOwnerAuthentication
        )

        let pageReason = NotesSidebarDeletionSovereignGate.reason(for: .page(title: "Research Notes"))
        let folderReason = NotesSidebarDeletionSovereignGate.reason(for: .folder(name: "Archive"))

        #expect(pageReason.contains("Research Notes"))
        #expect(folderReason.contains("Archive"))
        #expect(pageReason.localizedCaseInsensitiveContains("permanently delete"))
        #expect(folderReason.localizedCaseInsensitiveContains("permanently delete"))
    }

    @Test("Chat sidebar deletes map to destructive Sovereign Gate requirements")
    func chatSidebarDeletesMapToSovereignGateRequirements() {
        #expect(
            ChatSidebarDeletionSovereignGate.requirement(for: .chat(title: "Planning Thread"))
                == .deviceOwnerAuthentication
        )

        let reason = ChatSidebarDeletionSovereignGate.reason(for: .chat(title: "Planning Thread"))

        #expect(reason.contains("Planning Thread"))
        #expect(reason.localizedCaseInsensitiveContains("permanently delete"))
    }

    @Test("Diff sheet version deletes map to destructive Sovereign Gate requirements")
    func diffSheetVersionDeletesMapToSovereignGateRequirements() {
        #expect(
            DiffSheetVersionDeletionSovereignGate.requirement(for: .version(label: "May 2, 2026 at 12:00 PM"))
                == .deviceOwnerAuthentication
        )

        let reason = DiffSheetVersionDeletionSovereignGate.reason(for: .version(label: "May 2, 2026 at 12:00 PM"))

        #expect(reason.contains("May 2, 2026 at 12:00 PM"))
        #expect(reason.localizedCaseInsensitiveContains("permanently delete"))
    }

    @Test("Diff sheet version delete menu routes through captured Sovereign Gate target")
    func diffSheetVersionDeleteMenuRoutesThroughCapturedSovereignGateTarget() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Views/Notes/DiffSheetView.swift")

        func section(from startMarker: String, to endMarker: String) throws -> String {
            let start = try #require(source.range(of: startMarker))
            let end = try #require(
                source.range(of: endMarker, range: start.lowerBound..<source.endIndex)
            )
            return String(source[start.lowerBound..<end.lowerBound])
        }

        let menuAction = try section(
            from: "Button(role: .destructive) {",
            to: "Label(\"Delete This Version\", systemImage: \"trash\")"
        )
        #expect(menuAction.contains("requestSelectedVersionDeleteAuthorization()"))
        #expect(!menuAction.contains("deleteSelectedVersion()"))

        let request = try section(
            from: "private func requestSelectedVersionDeleteAuthorization()",
            to: "private func deleteSelectedVersion()"
        )
        #expect(request.contains("guard let version = selectedVersion else { return }"))
        #expect(request.contains("AppBootstrap.shared?.sovereignGate.confirm("))
        #expect(request.contains("guard outcome == .allowed else { return }"))
        #expect(request.contains("deleteSelectedVersion(version)"))

        let capture = try #require(request.range(of: "guard let version = selectedVersion else { return }"))
        let confirm = try #require(request.range(of: "AppBootstrap.shared?.sovereignGate.confirm("))
        let allowed = try #require(request.range(of: "guard outcome == .allowed else { return }"))
        let delete = try #require(request.range(of: "deleteSelectedVersion(version)"))
        #expect(capture.lowerBound < confirm.lowerBound)
        #expect(confirm.lowerBound < allowed.lowerBound)
        #expect(allowed.lowerBound < delete.lowerBound)
    }

    @Test("Lifecycle observer clears sensitive grace on app and system boundaries")
    func lifecycleObserverClearsSensitiveGraceOnBoundaries() async throws {
        let authenticator = FakeAuthenticator(results: [true, true, true])
        let gate = SovereignGate(authenticator: authenticator)
        let observer = SovereignGateLifecycleObserver()
        let applicationCenter = NotificationCenter()
        let workspaceCenter = NotificationCenter()
        let category = SovereignGateCategory(rawValue: "vault-export")
        let start = Date(timeIntervalSince1970: 7_000)

        observer.start(
            gate: gate,
            applicationCenter: applicationCenter,
            workspaceCenter: workspaceCenter
        )

        #expect(await gate.confirm(.biometric(category: category), reason: "Export vault", now: start) == .allowed)
        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Export within grace",
                now: start.addingTimeInterval(10)
            ) == .allowed
        )
        #expect(authenticator.requests.count == 1)

        applicationCenter.post(name: NSApplication.didResignActiveNotification, object: nil)
        try await Task.sleep(for: .milliseconds(10))
        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Export after app resign",
                now: start.addingTimeInterval(20)
            ) == .allowed
        )
        #expect(authenticator.requests.count == 2)

        workspaceCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        try await Task.sleep(for: .milliseconds(10))
        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Export after sleep",
                now: start.addingTimeInterval(30)
            ) == .allowed
        )
        #expect(authenticator.requests.count == 3)
    }

    @Test("Lifecycle observer stop removes security boundary notifications")
    func lifecycleObserverStopRemovesNotifications() async throws {
        let authenticator = FakeAuthenticator(results: [true])
        let gate = SovereignGate(authenticator: authenticator)
        let observer = SovereignGateLifecycleObserver()
        let applicationCenter = NotificationCenter()
        let workspaceCenter = NotificationCenter()
        let category = SovereignGateCategory(rawValue: "oauth")
        let start = Date(timeIntervalSince1970: 8_000)

        observer.start(
            gate: gate,
            applicationCenter: applicationCenter,
            workspaceCenter: workspaceCenter
        )
        #expect(await gate.confirm(.biometric(category: category), reason: "Grant OAuth", now: start) == .allowed)

        observer.stop()
        applicationCenter.post(name: NSApplication.didResignActiveNotification, object: nil)
        workspaceCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        try await Task.sleep(for: .milliseconds(10))

        #expect(
            await gate.confirm(
                .biometric(category: category),
                reason: "Grant OAuth within uncleared grace",
                now: start.addingTimeInterval(10)
            ) == .allowed
        )
        #expect(authenticator.requests.count == 1)
    }

    @Test("App bootstrap owns the shared Sovereign Gate lifecycle")
    func appBootstrapOwnsSharedSovereignGateLifecycle() throws {
        let bootstrap = try #require(AppBootstrap.shared)

        #expect(bootstrap.isSovereignGateLifecycleObserverStarted)
    }
}
