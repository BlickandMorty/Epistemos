import Foundation
import Testing
@testable import Epistemos

@Suite("Agent Permission Request Classification")
struct AgentPermissionRequestTests {
    @Test("vault reads are classified as sensitive local data access")
    func vaultReadsAreSensitive() {
        let request = AgentPermissionRequest(
            id: "perm-vault-read",
            toolName: "vault.read",
            inputJson: #"{"path":"People/Jojo.md"}"#,
            riskLevel: .readOnly,
            description: "Read a vault note."
        )

        #expect(request.permissionCategory == .localDataRead)
        #expect(request.requiresHumanApproval)
        #expect(request.approvalTargetSummary == "People/Jojo.md")
    }

    @Test("web search routes through the native approval gate")
    func webSearchRoutesThroughNativeApprovalGate() {
        let request = AgentPermissionRequest(
            id: "perm-web-search",
            toolName: "web.search",
            inputJson: #"{"query":"latest Apple Silicon memory pressure guidance"}"#,
            riskLevel: .readOnly,
            description: "Search the web."
        )

        #expect(request.permissionCategory == .genericRead)
        #expect(request.requiresHumanApproval)
        #expect(request.authorityCategory(vaultPath: nil) == .networkFetch)
        #expect(request.approvalTargetSummary == "latest Apple Silicon memory pressure guidance")
    }

    @Test("non-network generic read tools stay auto-approved")
    func nonNetworkGenericReadToolsStayAutoApproved() {
        let request = AgentPermissionRequest(
            id: "perm-think",
            toolName: "think",
            inputJson: #"{"thought":"plan next step"}"#,
            riskLevel: .readOnly,
            description: "Internal reasoning tool."
        )

        #expect(request.permissionCategory == .genericRead)
        #expect(!request.requiresHumanApproval)
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

    @Test("relative file reads resolve to vault authority so remembered approvals can persist")
    func relativeFileReadsUseVaultAuthorityCategory() {
        let request = AgentPermissionRequest(
            id: "perm-note-title-read",
            toolName: "read_file",
            inputJson: #"{"path":"All Things Must Go","offset":1,"limit":500}"#,
            riskLevel: .readOnly,
            description: "Read a note by title."
        )

        #expect(request.authorityCategory(vaultPath: "/Users/jojo/Vault") == .vaultRead)
    }

    @Test("absolute file reads outside the vault stay in the out-of-vault authority bucket")
    func absoluteFileReadsOutsideVaultStayScoped() {
        let request = AgentPermissionRequest(
            id: "perm-external-read",
            toolName: "read_file",
            inputJson: #"{"path":"/Users/jojo/Documents/private.txt","offset":1,"limit":500}"#,
            riskLevel: .readOnly,
            description: "Read a private file."
        )

        #expect(request.authorityCategory(vaultPath: "/Users/jojo/Downloads/EpistemosVault") == .outOfVaultFileAccess)
    }
}
