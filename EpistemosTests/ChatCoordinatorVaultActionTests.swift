import Testing
@testable import Epistemos

@Suite("Chat Coordinator Vault Actions")
struct ChatCoordinatorVaultActionTests {
    @Test("vault action directives are converted into blocked approval notices")
    func vaultActionDirectivesBecomeBlockedApprovalNotices() {
        let response = """
        Done.
        [ACTION:TAG swift, rust]
        [ACTION:MOVE Research]
        [ACTION:CREATE Serial Pipeline Notes]
        """

        let sanitized = ChatCoordinator.sanitizeVaultActionMarkers(in: response)

        #expect(sanitized.cleaned.contains("Done."))
        #expect(!sanitized.cleaned.contains("[ACTION:"))
        #expect(sanitized.blockedActions == [
            "Approval required before adding tags [swift, rust].",
            "Approval required before moving this note to Research.",
            "Approval required before creating note: Serial Pipeline Notes.",
        ])
    }

    @Test("responses without vault action directives pass through unchanged")
    func responsesWithoutVaultActionDirectivesPassThrough() {
        let response = "Nothing to change here."

        let sanitized = ChatCoordinator.sanitizeVaultActionMarkers(in: response)

        #expect(sanitized.cleaned == response)
        #expect(sanitized.blockedActions.isEmpty)
    }
}
