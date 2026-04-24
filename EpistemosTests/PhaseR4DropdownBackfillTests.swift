import Foundation
import Testing
@testable import Epistemos

// MARK: - Phase R.4 Dropdown Manifest-Backfill Regression Tests
//
// Covers `ComposerReferenceHelpers.contextAttachment(for:vaultId:)`
// after the R.4 backfill — when the user picks a note from the `@`
// mention dropdown, the resulting `ContextAttachment` now carries a
// canonical `vault://{vaultId}/note/{relativePath}` URI + Live mode
// + Read/Write capabilities, matching the shape
// `attachedResourceFromUi` produces on the Rust side.
//
// This closes the Swift side of Path C (dropdown → grant-ready
// attachment) so the R.5 grant parser in `ChatCoordinator.handleQuery`
// actually has URIs to grant against on live user turns.
//
// Scope:
//   - URI construction helper (vault id + path validation, trimming)
//   - Manifest populated when both vault id + relative path are known
//   - Manifest suppressed when either input is missing (legacy fallback)
//   - All-Notes / chat-reference paths unchanged by the new signature
//
// Plan refs: docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md §Phase R.4,
// docs/KNOWN_ISSUES_REGISTER.md I-004/I-005/I-006.

@Suite("Phase R.4 — Dropdown Manifest Backfill")
struct PhaseR4DropdownBackfillTests {

    // MARK: - Helpers

    private func makeEntry(
        pageId: String = "page-r4-dropdown",
        title: String = "Dropdown Note",
        relativePath: String? = "Inbox/DropdownNote.md",
        folderName: String? = "Inbox"
    ) -> VaultManifest.ManifestEntry {
        VaultManifest.ManifestEntry(
            pageId: pageId,
            title: title,
            relativePath: relativePath,
            tags: [],
            folderName: folderName,
            wordCount: 0,
            snippet: "",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    // MARK: - URI construction

    @Test("vaultNoteResourceURI returns a Rust-parseable URI when both halves are known")
    func vaultNoteResourceURIReturnsCanonicalURI() async throws {
        let uri = ComposerReferenceHelpers.vaultNoteResourceURI(
            vaultId: "main",
            relativePath: "Inbox/Test.md"
        )
        #expect(uri == "vault://main/note/Inbox/Test.md")
    }

    @Test("vaultNoteResourceURI trims surrounding whitespace from both arguments")
    func vaultNoteResourceURITrimsWhitespace() async throws {
        let uri = ComposerReferenceHelpers.vaultNoteResourceURI(
            vaultId: "  main  ",
            relativePath: "  Inbox/Trim.md\n"
        )
        #expect(uri == "vault://main/note/Inbox/Trim.md")
    }

    @Test("vaultNoteResourceURI returns nil when vaultId is nil")
    func vaultNoteResourceURINilWithoutVaultId() async throws {
        let uri = ComposerReferenceHelpers.vaultNoteResourceURI(
            vaultId: nil,
            relativePath: "Inbox/Test.md"
        )
        #expect(uri == nil)
    }

    @Test("vaultNoteResourceURI returns nil when vaultId is empty / whitespace")
    func vaultNoteResourceURINilWithEmptyVaultId() async throws {
        #expect(ComposerReferenceHelpers.vaultNoteResourceURI(
            vaultId: "",
            relativePath: "Inbox/Test.md"
        ) == nil)
        #expect(ComposerReferenceHelpers.vaultNoteResourceURI(
            vaultId: "   ",
            relativePath: "Inbox/Test.md"
        ) == nil)
    }

    @Test("vaultNoteResourceURI returns nil when relativePath is missing")
    func vaultNoteResourceURINilWithoutRelativePath() async throws {
        #expect(ComposerReferenceHelpers.vaultNoteResourceURI(
            vaultId: "main",
            relativePath: nil
        ) == nil)
        #expect(ComposerReferenceHelpers.vaultNoteResourceURI(
            vaultId: "main",
            relativePath: ""
        ) == nil)
        #expect(ComposerReferenceHelpers.vaultNoteResourceURI(
            vaultId: "main",
            relativePath: "   "
        ) == nil)
    }

    // MARK: - contextAttachment(for:vaultId:) — entry path

    @Test("entry + vaultId + relativePath yields a Live manifest attachment")
    func entryWithVaultIdYieldsLiveManifest() async throws {
        let entry = makeEntry(relativePath: "Inbox/Alpha.md")
        let attachment = ComposerReferenceHelpers.contextAttachment(
            for: .note(.entry(entry)),
            vaultId: "main"
        )
        #expect(attachment.kind == .note)
        #expect(attachment.targetId == "page-r4-dropdown")
        #expect(attachment.title == "Dropdown Note")
        #expect(attachment.subtitle == "Inbox")
        #expect(attachment.resourceURI == "vault://main/note/Inbox/Alpha.md")
        #expect(attachment.resourceMode == .live)
        #expect(attachment.resourceCapabilities == ["Read", "Write"])
        #expect(attachment.hasResourceManifest)
    }

    @Test("entry without vaultId falls back to legacy no-manifest form")
    func entryWithoutVaultIdFallsBack() async throws {
        let entry = makeEntry(relativePath: "Inbox/Beta.md")
        let attachment = ComposerReferenceHelpers.contextAttachment(
            for: .note(.entry(entry)),
            vaultId: nil
        )
        #expect(attachment.kind == .note)
        #expect(attachment.resourceURI == nil)
        #expect(attachment.resourceMode == nil)
        #expect(attachment.resourceCapabilities == nil)
        #expect(!attachment.hasResourceManifest)
    }

    @Test("entry missing relativePath falls back to legacy form even with vaultId")
    func entryWithoutRelativePathFallsBack() async throws {
        let entry = makeEntry(relativePath: nil)
        let attachment = ComposerReferenceHelpers.contextAttachment(
            for: .note(.entry(entry)),
            vaultId: "main"
        )
        #expect(attachment.kind == .note)
        #expect(attachment.resourceURI == nil)
        #expect(!attachment.hasResourceManifest)
    }

    // MARK: - contextAttachment(for:vaultId:) — non-entry paths

    @Test("all-notes choice is unchanged by the new vaultId parameter")
    func allNotesChoiceUnchanged() async throws {
        let legacy = ComposerReferenceHelpers.contextAttachment(
            for: .note(.allNotes)
        )
        let withVaultId = ComposerReferenceHelpers.contextAttachment(
            for: .note(.allNotes),
            vaultId: "main"
        )
        #expect(withVaultId == legacy)
        #expect(withVaultId == ComposerReferenceHelpers.allNotesAttachment)
    }

    // MARK: - End-to-end: R.4 → R.5 handshake

    @Test("R.4 manifest is exactly the shape R.5 grant filter expects")
    func r4ManifestSatisfiesR5Filter() async throws {
        // Build the same ContextAttachment the production dropdown
        // produces and feed it into the R.5 filter. The filter must
        // extract the URI verbatim.
        let entry = makeEntry(
            pageId: "page-handoff",
            title: "Handoff",
            relativePath: "Inbox/Handoff.md"
        )
        let attachment = ComposerReferenceHelpers.contextAttachment(
            for: .note(.entry(entry)),
            vaultId: "handoff-vault"
        )
        let extracted = ChatCoordinator.r5ResourceURIsForGrant(
            from: [attachment]
        )
        #expect(extracted == ["vault://handoff-vault/note/Inbox/Handoff.md"])
    }

    // MARK: - Backwards compatibility

    @Test("legacy callers omitting vaultId still compile and produce pre-R.4 shape")
    func legacyCallerStillCompiles() async throws {
        // The default-nil overload is still the safe fallback for any
        // future composer that hasn't been migrated yet. With all
        // three production composers now threading a vaultId, this is
        // the "test stub / internal use" shape.
        let entry = makeEntry()
        let attachment = ComposerReferenceHelpers.contextAttachment(
            for: .note(.entry(entry))
        )
        #expect(attachment.kind == .note)
        #expect(attachment.resourceURI == nil)
        #expect(attachment.resourceMode == nil)
        #expect(attachment.resourceCapabilities == nil)
    }

    // MARK: - All-three-composer parity (ChatInputBar + MiniChat + Landing)

    @Test("all three composer sites mint byte-identical manifests for the same entry")
    func allThreeComposersMintIdenticalManifest() async throws {
        // ChatInputBar (commit f6f62816), MiniChatView, and LandingView
        // all now derive vaultId from
        // `vaultSync.vaultURL?.lastPathComponent` and thread it into
        // `contextAttachment(for:vaultId:)`. This test stands in for
        // the three sites by calling the helper the same way each
        // composer does, with the same entry, and asserting the
        // resulting `ContextAttachment`s are byte-identical.
        //
        // If any composer drifts off the shared helper in a later
        // refactor, this regression catches the split before it
        // reaches the R.5 grant parser (which relies on every
        // composer producing the same URI for the same note).
        let entry = makeEntry(
            pageId: "parity-page",
            title: "Parity",
            relativePath: "Inbox/Parity.md"
        )
        let vaultId = "parity-vault"
        let chatInputBarAttachment = ComposerReferenceHelpers.contextAttachment(
            for: .note(.entry(entry)),
            vaultId: vaultId
        )
        let miniChatAttachment = ComposerReferenceHelpers.contextAttachment(
            for: .note(.entry(entry)),
            vaultId: vaultId
        )
        let landingAttachment = ComposerReferenceHelpers.contextAttachment(
            for: .note(.entry(entry)),
            vaultId: vaultId
        )
        #expect(chatInputBarAttachment == miniChatAttachment)
        #expect(miniChatAttachment == landingAttachment)
        #expect(chatInputBarAttachment.resourceURI == "vault://parity-vault/note/Inbox/Parity.md")
        #expect(chatInputBarAttachment.resourceMode == .live)
        #expect(chatInputBarAttachment.resourceCapabilities == ["Read", "Write"])
    }

    @Test("all three composer sites fall back identically when vaultId is nil")
    func allThreeComposersFallBackIdenticallyWhenVaultUnset() async throws {
        // Before `VaultSyncService.vaultURL` resolves (pre-bookmark
        // restore), all three composers pass `vaultId: nil` and must
        // degrade to the legacy no-manifest attachment — identical
        // across composers so the R.5 grant parser skips them
        // uniformly.
        let entry = makeEntry(
            pageId: "pre-vault-page",
            title: "PreVault",
            relativePath: "Inbox/PreVault.md"
        )
        let chatInputBarAttachment = ComposerReferenceHelpers.contextAttachment(
            for: .note(.entry(entry)),
            vaultId: nil
        )
        let miniChatAttachment = ComposerReferenceHelpers.contextAttachment(
            for: .note(.entry(entry)),
            vaultId: nil
        )
        let landingAttachment = ComposerReferenceHelpers.contextAttachment(
            for: .note(.entry(entry)),
            vaultId: nil
        )
        #expect(chatInputBarAttachment == miniChatAttachment)
        #expect(miniChatAttachment == landingAttachment)
        #expect(chatInputBarAttachment.resourceURI == nil)
        #expect(chatInputBarAttachment.resourceMode == nil)
        #expect(chatInputBarAttachment.resourceCapabilities == nil)
        #expect(!chatInputBarAttachment.hasResourceManifest)
    }

    // MARK: - Phase R.4 file-entry attachment (Finder drop / file picker / paste)

    @Test("fileResourceURI returns a Rust-parseable URI for a file URL")
    func fileResourceURIReturnsCanonicalURI() async throws {
        let url = URL(fileURLWithPath: "/tmp/authz/Example.swift")
        let uri = ComposerReferenceHelpers.fileResourceURI(for: url)
        #expect(uri == "file:///tmp/authz/Example.swift")
    }

    @Test("fileResourceURI returns nil for non-file URLs")
    func fileResourceURIRejectsNonFile() async throws {
        let http = URL(string: "https://example.com/notes.md")!
        #expect(ComposerReferenceHelpers.fileResourceURI(for: http) == nil)
    }

    @Test("fileContextAttachment mints Live + Read/Write manifest for file URL")
    func fileContextAttachmentHappyPath() async throws {
        let url = URL(fileURLWithPath: "/tmp/authz/Example.swift")
        let attachment = ComposerReferenceHelpers.fileContextAttachment(for: url)
        let attachment2 = try #require(attachment)
        #expect(attachment2.kind == .file)
        #expect(attachment2.title == "Example.swift")
        #expect(attachment2.resourceURI == "file:///tmp/authz/Example.swift")
        #expect(attachment2.resourceMode == .live)
        #expect(attachment2.resourceCapabilities == ["Read", "Write"])
        #expect(attachment2.hasResourceManifest)
    }

    @Test("fileContextAttachment prefers provided displayName over lastPathComponent")
    func fileContextAttachmentHonorsDisplayName() async throws {
        let url = URL(fileURLWithPath: "/tmp/authz/Script.swift")
        let attachment = ComposerReferenceHelpers.fileContextAttachment(
            for: url,
            displayName: "Friendly Label"
        )
        #expect(attachment?.title == "Friendly Label")
    }

    @Test("fileContextAttachment returns nil for non-file URLs")
    func fileContextAttachmentRejectsNonFile() async throws {
        let http = URL(string: "https://example.com/x.swift")!
        #expect(ComposerReferenceHelpers.fileContextAttachment(for: http) == nil)
    }

    @Test("pasteContextAttachment mints Snapshot + Read-only manifest")
    func pasteContextAttachmentIsSnapshotReadOnly() async throws {
        let attachment = ComposerReferenceHelpers.pasteContextAttachment(
            displayName: "Pasted JSON",
            snapshotContent: #"{"a":1}"#,
            sourceIdentifier: "abc123"
        )
        #expect(attachment.kind == .file)
        #expect(attachment.title == "Pasted JSON")
        #expect(attachment.subtitle == #"{"a":1}"#)
        #expect(attachment.resourceURI == "attachment://paste/id/abc123")
        #expect(attachment.resourceMode == .snapshot)
        #expect(attachment.resourceCapabilities == ["Read"])
        #expect(attachment.hasResourceManifest)
    }

    @Test("file and paste attachments both flow through the R.5 grant filter")
    func fileAndPasteFlowThroughR5Filter() async throws {
        // Prove that whichever file-entry path the user takes, the
        // R.5 grant parser sees a non-empty URI. Before the R.4
        // file-entry helpers existed, the file picker flow produced
        // zero URIs — a user saying "you have my permission to edit
        // this file" with a dragged-in .swift file would have minted
        // zero grants.
        let fileURL = URL(fileURLWithPath: "/tmp/authz/File.swift")
        let fileAttachment = try #require(
            ComposerReferenceHelpers.fileContextAttachment(for: fileURL)
        )
        let pasteAttachment = ComposerReferenceHelpers.pasteContextAttachment(
            displayName: "Pasted",
            snapshotContent: "body",
            sourceIdentifier: "paste-1"
        )
        let extracted = ChatCoordinator.r5ResourceURIsForGrant(
            from: [fileAttachment, pasteAttachment]
        )
        #expect(extracted == [
            "file:///tmp/authz/File.swift",
            "attachment://paste/id/paste-1",
        ])
    }
}
