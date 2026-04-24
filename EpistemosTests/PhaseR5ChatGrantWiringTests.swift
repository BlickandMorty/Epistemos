import Foundation
import Testing
@testable import Epistemos

// MARK: - Phase R.5 Chat Grant-Wiring Regression Tests
//
// Covers the Swift side of the R.5 parser hook added to
// `ChatCoordinator.handleQuery(_:pipeline:chatState:operatingMode:)`.
// The hook walks the current turn's `pendingContextAttachments`,
// filters to the ones carrying a Phase R.4 `resourceURI`, and fires
// `permissionStoreRecordUserGrantFromStatement` (fire-and-forget) per
// resource so consent phrasing lands as a real grant in the Rust
// permission store instead of evaporating as chat text (I-009).
//
// This suite tests the Swift side of the Live-attachment grant path:
// the URI filter that decides which attachments are grant-eligible,
// a smoke test that the FFI contract matches caller assumptions, and
// the Swift -> Rust bridge path where a Live attachment grant allows
// `vault_write` while a Snapshot attachment stays denied.
//
// Scope:
//   - `ChatCoordinator.r5ResourceURIsForGrant(from:)` — pure filter
//   - smoke: FFI accepts a URI from a ContextAttachment built the
//     same way the dropdown builder does in production
//
// Plan refs: docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md §Phase R.5 ·
// docs/KNOWN_ISSUES_REGISTER.md I-009.

@Suite("Phase R.5 — Chat Grant Wiring")
struct PhaseR5ChatGrantWiringTests {

    // MARK: - Helpers

    private func makeTempVault(id vaultID: String) throws -> URL {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("r5-attached-write-\(UUID().uuidString)", isDirectory: true)
        let vaultURL = parent.appendingPathComponent(vaultID, isDirectory: true)
        try FileManager.default.createDirectory(at: vaultURL, withIntermediateDirectories: true)
        return vaultURL
    }

    private func vaultWriteInput(path: String, content: String) throws -> String {
        let payload: [String: Any] = [
            "path": path,
            "content": content,
            "skip_contradiction_check": true,
        ]
        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        )
        return try #require(String(data: data, encoding: .utf8))
    }

    private func jsonObject(_ value: String) throws -> [String: Any] {
        let data = try #require(value.data(using: .utf8))
        return try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    // MARK: - URI filter

    @Test("attachments without resourceURI are dropped by the grant filter")
    func legacyAttachmentsAreDropped() async throws {
        let legacy = ContextAttachment(
            kind: .note,
            targetId: "page-legacy",
            title: "Legacy Note"
        )
        let extracted = ChatCoordinator.r5ResourceURIsForGrant(from: [legacy])
        #expect(extracted.isEmpty)
    }

    @Test("attachments with empty or whitespace resourceURI are dropped")
    func emptyURIsAreDropped() async throws {
        let empty = ContextAttachment(
            kind: .note,
            targetId: "page-empty",
            title: "Empty URI",
            resourceURI: ""
        )
        let whitespace = ContextAttachment(
            kind: .note,
            targetId: "page-ws",
            title: "Whitespace URI",
            resourceURI: "   \n  "
        )
        let extracted = ChatCoordinator.r5ResourceURIsForGrant(
            from: [empty, whitespace]
        )
        #expect(extracted.isEmpty)
    }

    @Test("attachments with real resourceURI are returned in input order")
    func resourceURIsAreReturnedInOrder() async throws {
        let first = ContextAttachment(
            kind: .note,
            targetId: "page-first",
            title: "First",
            resourceURI: "vault://r5-wire/note/Inbox/First.md"
        )
        let second = ContextAttachment(
            kind: .note,
            targetId: "page-second",
            title: "Second",
            resourceURI: "file:///tmp/r5-wire-second.md"
        )
        let extracted = ChatCoordinator.r5ResourceURIsForGrant(
            from: [first, second]
        )
        #expect(extracted == [
            "vault://r5-wire/note/Inbox/First.md",
            "file:///tmp/r5-wire-second.md",
        ])
    }

    @Test("mixed batch keeps only the resource-bearing attachments in order")
    func mixedBatchFiltersInOrder() async throws {
        let legacy = ContextAttachment(
            kind: .note,
            targetId: "page-legacy",
            title: "Legacy"
        )
        let withURI = ContextAttachment(
            kind: .note,
            targetId: "page-withuri",
            title: "With URI",
            resourceURI: "vault://r5-mixed/note/Inbox/Middle.md"
        )
        let emptyURI = ContextAttachment(
            kind: .note,
            targetId: "page-emptyuri",
            title: "Empty URI",
            resourceURI: ""
        )
        let extracted = ChatCoordinator.r5ResourceURIsForGrant(
            from: [legacy, withURI, emptyURI]
        )
        #expect(extracted == ["vault://r5-mixed/note/Inbox/Middle.md"])
    }

    // MARK: - Capability/scope constants match the Rust bridge

    @Test("candidate capabilities cover the full Capability enum")
    func candidateCapabilitiesCoverTheFullEnum() async throws {
        // Keep this in lock-step with `agent_core::resources::attachments::Capability`
        // — if a new variant lands on the Rust side, it must be added
        // here too or user grants for it will silently never fire.
        let candidates = Set(ChatCoordinator.r5GrantCandidateCapabilities)
        #expect(candidates == ["Read", "Write", "Create", "Delete", "Search"])
    }

    @Test("grant scope uses the Session label the Rust parser recognizes")
    func grantScopeIsSession() async throws {
        #expect(ChatCoordinator.r5GrantScope == "Session")
    }

    // MARK: - Live attachment default grants

    @Test("live attachment grant candidates skip snapshots and legacy attachments")
    func liveAttachmentGrantCandidatesSkipSnapshotsAndLegacy() async throws {
        let live = ContextAttachment(
            kind: .note,
            targetId: "page-live",
            title: "Live",
            resourceURI: "vault://r5-live-candidate/note/Inbox/Live.md",
            resourceMode: .live,
            resourceCapabilities: ["Read", "Write"]
        )
        let snapshot = ContextAttachment(
            kind: .file,
            targetId: "paste-snapshot",
            title: "Snapshot",
            subtitle: "Frozen text",
            resourceURI: "attachment://paste/id/snapshot",
            resourceMode: .snapshot,
            resourceCapabilities: ["Read"]
        )
        let legacy = ContextAttachment(
            kind: .note,
            targetId: "page-legacy",
            title: "Legacy"
        )

        let candidates = ChatCoordinator.r4LiveAttachmentWriteGrantCandidates(
            from: [snapshot, legacy, live]
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.resourceURI == "vault://r5-live-candidate/note/Inbox/Live.md")
        #expect(candidates.first?.capabilities == ["Read", "Write"])
    }

    @Test("default live attachment grant authorizes write but not delete")
    func defaultLiveAttachmentGrantAuthorizesWriteButNotDelete() async throws {
        let uniqueURI = "vault://r5-live-default-\(UUID().uuidString)/note/Inbox/Live.md"
        let attachment = ContextAttachment(
            kind: .note,
            targetId: "page-live-default",
            title: "Live Default",
            resourceURI: uniqueURI,
            resourceMode: .live,
            resourceCapabilities: ["Read", "Write"]
        )

        let candidates = ChatCoordinator.r4LiveAttachmentWriteGrantCandidates(from: [attachment])
        let candidate = try #require(candidates.first)
        let grantID = await permissionStoreRecordUserGrantFromStatement(
            statement: ChatCoordinator.r4LiveAttachmentDefaultGrantStatement,
            resourceUri: candidate.resourceURI,
            capabilityNames: candidate.capabilities,
            scopeName: ChatCoordinator.r5GrantScope
        )

        #expect(grantID != nil)
        #expect(await permissionStoreCheck(resourceUri: uniqueURI, capability: "Write"))
        let canDelete = await permissionStoreCheck(resourceUri: uniqueURI, capability: "Delete")
        #expect(!canDelete)
        if let grantID {
            _ = await permissionStoreRevoke(grantId: grantID)
        }
    }

    // MARK: - Smoke: FFI accepts the same URI shape the filter produces

    @Test("URI produced by the filter round-trips through the Rust grant parser")
    func uriFromFilterIsAcceptedByBridge() async throws {
        // End-to-end wire check: take a ContextAttachment populated like
        // production (dropdown → Phase R.4 manifest), extract its URI via
        // the pure filter, and hand that URI to the grant FFI. If the
        // contract is intact we get a non-nil grant_id for a grant-shaped
        // statement.
        let uniqueURI = "vault://r5-wire-smoke-\(UUID().uuidString)/note/Inbox/WireSmoke.md"
        let attachment = ContextAttachment(
            kind: .note,
            targetId: "page-wire-smoke",
            title: "Wire Smoke",
            subtitle: nil,
            resourceURI: uniqueURI,
            resourceMode: .live,
            resourceCapabilities: ["Read", "Write"]
        )
        let extracted = ChatCoordinator.r5ResourceURIsForGrant(from: [attachment])
        #expect(extracted == [uniqueURI])

        let grantID = await permissionStoreRecordUserGrantFromStatement(
            statement: "You have my permission to edit this note.",
            resourceUri: uniqueURI,
            capabilityNames: ChatCoordinator.r5GrantCandidateCapabilities,
            scopeName: ChatCoordinator.r5GrantScope
        )
        #expect(grantID != nil, "grant-shaped statement + valid URI should mint a grant")
        #expect(grantID?.isEmpty == false)
        // Clean up so we don't pollute the shared process-local store
        // (other suites enumerate grants).
        if let grantID {
            _ = await permissionStoreRevoke(grantId: grantID)
        }
    }

    // MARK: - Bridge execution: attachment grant -> tool write

    @Test("Live attachment default grant allows vault_write through the Swift bridge")
    func liveAttachmentGrantAllowsVaultWriteThroughSwiftBridge() async throws {
        let vaultID = "r5-live-write-\(UUID().uuidString)"
        let vaultURL = try makeTempVault(id: vaultID)
        defer { try? FileManager.default.removeItem(at: vaultURL.deletingLastPathComponent()) }

        let relativePath = "Inbox/Granted-\(UUID().uuidString).md"
        let content = "# Granted write\n\nThis came through the Live attachment grant."
        let attachment = ContextAttachment(
            kind: .note,
            targetId: "page-live-write",
            title: "Live Write",
            subtitle: nil,
            resourceURI: "vault://\(vaultID)/note/\(relativePath)",
            resourceMode: .live,
            resourceCapabilities: ["Read", "Write"]
        )

        let candidate = try #require(
            ChatCoordinator.r4LiveAttachmentWriteGrantCandidates(from: [attachment]).first
        )
        let grantID = await permissionStoreRecordUserGrantFromStatement(
            statement: ChatCoordinator.r4LiveAttachmentDefaultGrantStatement,
            resourceUri: candidate.resourceURI,
            capabilityNames: candidate.capabilities,
            scopeName: ChatCoordinator.r5GrantScope
        )
        #expect(grantID != nil)

        let inputJson = try vaultWriteInput(path: relativePath, content: content)
        let result = try await executeToolCallFiltered(
            vaultPath: vaultURL.path,
            tier: ChatToolTier.agent.rawValue,
            toolName: "vault_write",
            inputJson: inputJson,
            allowedToolNames: ["vault_write"]
        )

        #expect(result.success)
        let payload = try jsonObject(result.outputJson)
        #expect(payload["verified"] as? Bool == true)
        let written = try String(
            contentsOf: vaultURL.appendingPathComponent(relativePath),
            encoding: .utf8
        )
        #expect(written == content)

        if let grantID {
            _ = await permissionStoreRevoke(grantId: grantID)
        }
    }

    @Test("Snapshot attachment does not grant vault_write through the Swift bridge")
    func snapshotAttachmentDoesNotGrantVaultWriteThroughSwiftBridge() async throws {
        let vaultID = "r5-snapshot-deny-\(UUID().uuidString)"
        let vaultURL = try makeTempVault(id: vaultID)
        defer { try? FileManager.default.removeItem(at: vaultURL.deletingLastPathComponent()) }

        let relativePath = "Inbox/Snapshot-\(UUID().uuidString).md"
        let snapshotAttachment = ContextAttachment(
            kind: .note,
            targetId: "page-snapshot",
            title: "Snapshot",
            subtitle: nil,
            resourceURI: "vault://\(vaultID)/note/\(relativePath)",
            resourceMode: .snapshot,
            resourceCapabilities: ["Read"]
        )
        #expect(ChatCoordinator.r4LiveAttachmentWriteGrantCandidates(
            from: [snapshotAttachment]
        ).isEmpty)

        let unrelatedURI = "vault://\(vaultID)/note/Inbox/Unrelated-\(UUID().uuidString).md"
        let unrelatedGrantID = await permissionStoreRecordUserGrantFromStatement(
            statement: "You have my permission to edit this note.",
            resourceUri: unrelatedURI,
            capabilityNames: ["Write"],
            scopeName: ChatCoordinator.r5GrantScope
        )
        #expect(unrelatedGrantID != nil)

        let inputJson = try vaultWriteInput(
            path: relativePath,
            content: "# This should not be written"
        )
        let result = try await executeToolCallFiltered(
            vaultPath: vaultURL.path,
            tier: ChatToolTier.agent.rawValue,
            toolName: "vault_write",
            inputJson: inputJson,
            allowedToolNames: ["vault_write"]
        )

        #expect(!result.success)
        #expect((result.error ?? "").localizedCaseInsensitiveContains("permission"))
        #expect(!FileManager.default.fileExists(
            atPath: vaultURL.appendingPathComponent(relativePath).path
        ))

        if let unrelatedGrantID {
            _ = await permissionStoreRevoke(grantId: unrelatedGrantID)
        }
    }
}
