import Foundation
import Testing
@testable import Epistemos

@Suite("iMessage Reply Delegate Approvals")
struct IMessageReplyDelegateTests {
    private struct NoopReplyChannel: DriverChannelReplying {
        let channelID = "test"

        func fetchUnreadMessages(vaultPath: String, limit: Int) async throws -> [DriverChannelMessage] {
            []
        }

        func send(message: String, to recipientID: String, vaultPath: String) async throws {}
    }

    @Test("sensitive local reads are denied in the headless iMessage driver")
    func sensitiveLocalReadsAreDenied() {
        let delegate = IMessageReplyDelegate(
            contactHandle: "+15551234567",
            vaultPath: "/tmp/vault",
            replyChannel: NoopReplyChannel(),
            autoApproveModifications: true
        )

        delegate.onPermissionRequired(
            permissionId: "perm-sensitive-read",
            toolName: "vault_read",
            inputJson: #"{"path":"People/Private.md"}"#,
            riskLevel: "read_only"
        )

        #expect(delegate.waitForPermission(permissionId: "perm-sensitive-read") == false)
    }

    @Test("web search remains allowed for the headless iMessage driver")
    func webSearchRemainsAllowed() {
        let delegate = IMessageReplyDelegate(
            contactHandle: "+15551234567",
            vaultPath: "/tmp/vault",
            replyChannel: NoopReplyChannel(),
            autoApproveModifications: false
        )

        delegate.onPermissionRequired(
            permissionId: "perm-web-search",
            toolName: "web_search",
            inputJson: #"{"query":"current weather in Austin"}"#,
            riskLevel: "read_only"
        )

        #expect(delegate.waitForPermission(permissionId: "perm-web-search") == true)
    }

    @Test("local vault writes are denied even when a contact auto-approves modifications")
    func localVaultWritesAreDenied() {
        let delegate = IMessageReplyDelegate(
            contactHandle: "+15551234567",
            vaultPath: "/tmp/vault",
            replyChannel: NoopReplyChannel(),
            autoApproveModifications: true
        )

        delegate.onPermissionRequired(
            permissionId: "perm-vault-write",
            toolName: "vault_write",
            inputJson: #"{"path":"People/Private.md","content":"secret"}"#,
            riskLevel: "modification"
        )

        #expect(delegate.waitForPermission(permissionId: "perm-vault-write") == false)
    }

    @Test("generic non-local modifications still honor the contact auto-approve flag")
    func genericModificationsHonorContactAutoApproveFlag() {
        let delegate = IMessageReplyDelegate(
            contactHandle: "+15551234567",
            vaultPath: "/tmp/vault",
            replyChannel: NoopReplyChannel(),
            autoApproveModifications: true
        )

        delegate.onPermissionRequired(
            permissionId: "perm-shell",
            toolName: "shell",
            inputJson: #"{"command":"mkdir -p /tmp/epistemos-driver"}"#,
            riskLevel: "modification"
        )

        #expect(delegate.waitForPermission(permissionId: "perm-shell") == true)
    }
}
