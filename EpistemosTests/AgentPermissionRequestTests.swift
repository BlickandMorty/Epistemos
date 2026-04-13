import Foundation
import Testing
@testable import Epistemos

@Suite("Agent Permission Request Classification")
struct AgentPermissionRequestTests {
    @Test("vault reads are classified as sensitive local data access")
    func vaultReadsAreSensitive() {
        let request = AgentPermissionRequest(
            id: "perm-vault-read",
            toolName: "vault_read",
            inputJson: #"{"path":"People/Jojo.md"}"#,
            riskLevel: .readOnly,
            description: "Read a vault note."
        )

        #expect(request.permissionCategory == .localDataRead)
        #expect(request.requiresHumanApproval)
        #expect(request.approvalTargetSummary == "People/Jojo.md")
    }

    @Test("web search remains auto-approved as an external read-only tool")
    func webSearchRemainsAutoApproved() {
        let request = AgentPermissionRequest(
            id: "perm-web-search",
            toolName: "web_search",
            inputJson: #"{"query":"latest Apple Silicon memory pressure guidance"}"#,
            riskLevel: .readOnly,
            description: "Search the web."
        )

        #expect(request.permissionCategory == .genericRead)
        #expect(!request.requiresHumanApproval)
        #expect(request.approvalTargetSummary == "latest Apple Silicon memory pressure guidance")
    }

    @Test("file ops read and patch actions split into sensitive read vs write categories")
    func fileOpsReadAndPatchSplitBySensitivity() {
        let readRequest = AgentPermissionRequest(
            id: "perm-file-read",
            toolName: "file_ops",
            inputJson: #"{"action":"read","path":"Secrets/plan.txt"}"#,
            riskLevel: .readOnly,
            description: "Read a local file."
        )
        let patchRequest = AgentPermissionRequest(
            id: "perm-file-patch",
            toolName: "file_ops",
            inputJson: #"{"action":"patch","path":"Secrets/plan.txt","find":"old","replace":"new"}"#,
            riskLevel: .modification,
            description: "Patch a local file."
        )

        #expect(readRequest.permissionCategory == .localDataRead)
        #expect(readRequest.requiresHumanApproval)
        #expect(patchRequest.permissionCategory == .localDataWrite)
        #expect(patchRequest.requiresHumanApproval)
    }

    @Test("destructive operations stay destructive even without a local path payload")
    func destructiveOperationsStayDestructive() {
        let request = AgentPermissionRequest(
            id: "perm-shell",
            toolName: "shell",
            inputJson: #"{"command":"rm -rf /tmp/demo"}"#,
            riskLevel: .destructive,
            description: "Delete temp files."
        )

        #expect(request.permissionCategory == .destructive)
        #expect(request.requiresHumanApproval)
        #expect(request.approvalTargetSummary == "rm -rf /tmp/demo")
    }
}
