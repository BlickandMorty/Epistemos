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
        // MiniChat + Landing haven't migrated yet; they call without
        // the vaultId argument. The default nil keeps them on the
        // legacy no-manifest code path byte-for-byte identical to
        // pre-R.4 behavior.
        let entry = makeEntry()
        let attachment = ComposerReferenceHelpers.contextAttachment(
            for: .note(.entry(entry))
        )
        #expect(attachment.kind == .note)
        #expect(attachment.resourceURI == nil)
        #expect(attachment.resourceMode == nil)
        #expect(attachment.resourceCapabilities == nil)
    }
}
