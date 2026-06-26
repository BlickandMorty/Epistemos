import Foundation
import Testing
@testable import Epistemos

@Suite("Composer Reference Helpers")
struct ComposerReferenceHelpersTests {
    @Test("mention filter extracts the active @ query")
    func mentionFilterExtractsActiveQuery() {
        #expect(ComposerReferenceHelpers.mentionFilter(in: "Ask @alp") == "alp")
        #expect(ComposerReferenceHelpers.mentionFilter(in: "@") == "")
        #expect(ComposerReferenceHelpers.mentionFilter(in: "Ask @my mind map") == "my mind map")
    }

    @Test("mention filter ignores closed mentions and inline emails")
    func mentionFilterIgnoresClosedMentionsAndEmails() {
        #expect(ComposerReferenceHelpers.mentionFilter(in: "Ask @[Alpha]") == nil)
        #expect(ComposerReferenceHelpers.mentionFilter(in: "mail me at alpha@example.com") == nil)
        #expect(ComposerReferenceHelpers.mentionFilter(in: "Ask alpha") == nil)
    }

    @Test("removing trailing mention trims the full active multi-word query")
    func removingTrailingMentionTrimsFullActiveMention() {
        #expect(ComposerReferenceHelpers.removingTrailingMention(from: "Ask @my mind map") == "Ask ")
        #expect(ComposerReferenceHelpers.removingTrailingMention(from: "mail me at alpha@example.com") == "mail me at alpha@example.com")
        #expect(ComposerReferenceHelpers.removingTrailingMention(from: "Ask @[Alpha]") == "Ask @[Alpha]")
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

    @Test("popover layout keeps a generous width when there is room")
    func popoverLayoutKeepsGenerousWidthWhenThereIsRoom() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let anchor = CGRect(x: 420, y: 320, width: 820, height: 120)

        let width = ComposerReferencePopoverLayout.resolvedWidth(
            idealWidth: 560,
            anchorFrame: anchor,
            screenFrame: screen
        )

        #expect(width >= 520)
        #expect(width <= 560)
    }

    @Test("popover layout shifts left when the anchor is near the trailing edge")
    func popoverLayoutShiftsLeftNearTrailingEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1200, height: 900)
        let anchor = CGRect(x: 980, y: 320, width: 220, height: 120)
        let width = ComposerReferencePopoverLayout.resolvedWidth(
            idealWidth: 520,
            anchorFrame: anchor,
            screenFrame: screen
        )

        let offset = ComposerReferencePopoverLayout.horizontalOffset(
            width: width,
            anchorFrame: anchor,
            screenFrame: screen
        )

        #expect(offset < 0)
    }

}
