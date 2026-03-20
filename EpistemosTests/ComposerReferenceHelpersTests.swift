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

    @Test("reference search ranks title matches ahead of secondary metadata")
    func referenceSearchRanksTitleMatchesAheadOfSecondaryMetadata() {
        let manifest = makeManifest(entries: [
            .init(
                pageId: "title",
                title: "Atlas Project",
                tags: ["research"],
                folderName: "Projects",
                wordCount: 400,
                snippet: "Primary atlas design notes",
                updatedAt: Date(timeIntervalSince1970: 300),
                createdAt: .distantPast
            ),
            .init(
                pageId: "tag",
                title: "Weekly Review",
                tags: ["atlas"],
                folderName: "Journal",
                wordCount: 220,
                snippet: "Retrospective entry",
                updatedAt: Date(timeIntervalSince1970: 200),
                createdAt: .distantPast
            ),
            .init(
                pageId: "snippet",
                title: "Ideas",
                tags: ["brainstorm"],
                folderName: "Inbox",
                wordCount: 180,
                snippet: "Atlas launch checklist and notes",
                updatedAt: Date(timeIntervalSince1970: 100),
                createdAt: .distantPast
            ),
        ])

        let results = ChatCoordinator.searchReferenceResults(
            filter: "atlas",
            manifest: manifest,
            chats: [],
            threads: []
        )

        #expect(notePageIDs(results.notes) == ["title", "tag", "snippet"])
    }

    @Test("reference search matches folder and snippet metadata, not only titles")
    func referenceSearchMatchesFolderAndSnippetMetadata() {
        let manifest = makeManifest(entries: [
            .init(
                pageId: "folder",
                title: "Orbitals",
                tags: ["chemistry"],
                folderName: "Lab Notes",
                wordCount: 320,
                snippet: "Electron shell observations",
                updatedAt: Date(timeIntervalSince1970: 200),
                createdAt: .distantPast
            ),
            .init(
                pageId: "snippet",
                title: "Meeting",
                tags: ["planning"],
                folderName: "Ops",
                wordCount: 210,
                snippet: "Lab calibration schedule and supply list",
                updatedAt: Date(timeIntervalSince1970: 100),
                createdAt: .distantPast
            ),
        ])

        let results = ChatCoordinator.searchReferenceResults(
            filter: "lab",
            manifest: manifest,
            chats: [],
            threads: []
        )

        #expect(notePageIDs(results.notes) == ["folder", "snippet"])
    }

    @Test("reference search includes indexed deep-body matches when manifest metadata misses them")
    func referenceSearchIncludesIndexedDeepBodyMatches() {
        let manifest = makeManifest(entries: [
            .init(
                pageId: "deep",
                title: "Orbitals",
                tags: ["chemistry"],
                folderName: "Research",
                wordCount: 320,
                snippet: "Electron shell observations",
                updatedAt: Date(timeIntervalSince1970: 200),
                createdAt: .distantPast
            ),
            .init(
                pageId: "plain",
                title: "Meeting Notes",
                tags: ["ops"],
                folderName: "Team",
                wordCount: 210,
                snippet: "Weekly staff sync",
                updatedAt: Date(timeIntervalSince1970: 100),
                createdAt: .distantPast
            ),
        ])

        let results = ChatCoordinator.searchReferenceResults(
            filter: "decoherence",
            manifest: manifest,
            chats: [],
            threads: [],
            indexedNoteIDs: ["deep"]
        )

        #expect(notePageIDs(results.notes) == ["deep"])
    }

    @Test("reference search keeps indexed snippet metadata for deep body matches")
    func referenceSearchKeepsIndexedSnippetMetadata() {
        let manifest = makeManifest(entries: [
            .init(
                pageId: "deep",
                title: "Orbitals",
                tags: ["chemistry"],
                folderName: "Research",
                wordCount: 320,
                snippet: "Electron shell observations",
                updatedAt: Date(timeIntervalSince1970: 200),
                createdAt: .distantPast
            ),
        ])

        let results = ChatCoordinator.searchReferenceResults(
            filter: "decoherence",
            manifest: manifest,
            chats: [],
            threads: [],
            indexedNoteIDs: ["deep"],
            indexedNoteSnippets: ["deep": "Field decoherence in trapped ions"]
        )

        #expect(results.indexedMatchedNoteIDs == Set(["deep"]))
        #expect(results.indexedNoteSnippetsByPageID["deep"] == "Field decoherence in trapped ions")
    }

    @Test("empty note search surfaces all notes first and then recent notes")
    func emptyNoteSearchSurfacesAllNotesFirstAndThenRecentNotes() {
        let manifest = makeManifest(entries: [
            .init(
                pageId: "older",
                title: "Older Note",
                tags: [],
                folderName: nil,
                wordCount: 50,
                snippet: "",
                updatedAt: Date(timeIntervalSince1970: 100),
                createdAt: .distantPast
            ),
            .init(
                pageId: "newer",
                title: "Newer Note",
                tags: [],
                folderName: nil,
                wordCount: 75,
                snippet: "",
                updatedAt: Date(timeIntervalSince1970: 200),
                createdAt: .distantPast
            ),
        ])

        let results = ChatCoordinator.searchReferenceResults(
            filter: "",
            manifest: manifest,
            chats: [],
            threads: [],
            limitPerSection: 2
        )

        #expect(noteChoiceIDs(results.notes) == ["all-notes", "newer", "older"])
    }

    @Test("empty note browse hides chat matches until the user searches")
    func emptyNoteBrowseHidesChatsUntilTheUserSearches() {
        let manifest = makeManifest(entries: [
            .init(
                pageId: "newer",
                title: "Newer Note",
                tags: [],
                folderName: nil,
                wordCount: 75,
                snippet: "",
                updatedAt: Date(timeIntervalSince1970: 200),
                createdAt: .distantPast
            ),
        ])

        let chat = SDChat(title: "Atlas planning")
        chat.id = "chat-1"
        chat.createdAt = .distantPast
        chat.updatedAt = .distantPast
        let thread = ChatThread(
            id: "thread-1",
            label: "Palette thread",
            type: "palette",
            messages: [AssistantMessage(role: .user, content: "atlas")],
            createdAt: .distantPast
        )

        let results = ChatCoordinator.searchReferenceResults(
            filter: "",
            manifest: manifest,
            chats: [chat],
            threads: [thread]
        )

        #expect(noteChoiceIDs(results.notes) == ["all-notes", "newer"])
        #expect(results.chats.isEmpty)
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

    private func makeManifest(entries: [VaultManifest.ManifestEntry]) -> VaultManifest {
        VaultManifest(
            vaultTitle: "My Vault",
            totalNoteCount: entries.count,
            isInventoryComplete: true,
            entries: entries,
            recentBodies: [],
            generatedAt: .distantPast
        )
    }

    private func notePageIDs(_ notes: [NoteMentionChoice]) -> [String] {
        notes.compactMap { choice in
            guard case .entry(let entry) = choice else { return nil }
            return entry.pageId
        }
    }

    private func noteChoiceIDs(_ notes: [NoteMentionChoice]) -> [String] {
        notes.map { choice in
            switch choice {
            case .allNotes:
                "all-notes"
            case .entry(let entry):
                entry.pageId
            }
        }
    }
}
