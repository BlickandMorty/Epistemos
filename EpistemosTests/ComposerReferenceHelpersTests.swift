import Foundation
import Testing
@testable import Epistemos

@Suite("Composer Reference Helpers")
struct ComposerReferenceHelpersTests {
    @Test("mention filter extracts the active @ query")
    func mentionFilterExtractsActiveQuery() {
        #expect(ComposerReferenceHelpers.mentionFilter(in: "Ask @alp") == "alp")
        #expect(ComposerReferenceHelpers.mentionFilter(in: "@") == "")
    }

    @Test("mention filter ignores closed or whitespace-terminated mentions")
    func mentionFilterIgnoresClosedOrWhitespaceMentions() {
        #expect(ComposerReferenceHelpers.mentionFilter(in: "Ask @[Alpha]") == nil)
        #expect(ComposerReferenceHelpers.mentionFilter(in: "Ask @alpha beta") == nil)
        #expect(ComposerReferenceHelpers.mentionFilter(in: "Ask alpha") == nil)
    }

    @Test("context attachment builder maps note and vault choices")
    func contextAttachmentBuilderMapsNoteAndVaultChoices() {
        let entry = VaultManifest.ManifestEntry(
            pageId: "page-1",
            title: "Alpha",
            tags: [],
            folderName: "Folder",
            wordCount: 42,
            snippet: "Snippet",
            updatedAt: .distantPast,
            createdAt: .distantPast
        )

        let noteAttachment = ComposerReferenceHelpers.contextAttachment(
            for: .note(.entry(entry))
        )
        #expect(noteAttachment.kind == .note)
        #expect(noteAttachment.targetId == "page-1")
        #expect(noteAttachment.title == "Alpha")
        #expect(noteAttachment.subtitle == "Folder")

        let vaultAttachment = ComposerReferenceHelpers.contextAttachment(
            for: .note(.allNotes)
        )
        #expect(vaultAttachment == ComposerReferenceHelpers.allNotesAttachment)
    }
}
