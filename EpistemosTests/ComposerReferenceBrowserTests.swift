import Foundation
import Testing
@testable import Epistemos

@Suite("Composer Reference Browser")
struct ComposerReferenceBrowserTests {
    @Test("inventory builder produces notes-sidebar-style folder tree and loose pages")
    func inventoryBuilderProducesFolderTreeAndLoosePages() {
        let research = SDFolder(name: "Research")
        research.id = "folder-research"
        research.sortOrder = 1

        let physics = SDFolder(name: "Physics")
        physics.id = "folder-physics"
        physics.sortOrder = 2
        physics.parent = research
        research.children = [physics]

        let rootNote = SDPage(title: "Inbox")
        rootNote.id = "page-root"
        rootNote.updatedAt = Date(timeIntervalSince1970: 100)

        let folderNote = SDPage(title: "Quantum")
        folderNote.id = "page-quantum"
        folderNote.updatedAt = Date(timeIntervalSince1970: 200)
        folderNote.folder = physics
        folderNote.subfolder = "Research/Physics"
        physics.pages = [folderNote]

        let inventory = ComposerReferenceBrowserInventoryBuilder.build(
            manifestEntriesByPageID: [
                "page-root": makeEntry(
                    pageId: "page-root",
                    title: "Inbox",
                    folderName: nil,
                    updatedAt: Date(timeIntervalSince1970: 100)
                ),
                "page-quantum": makeEntry(
                    pageId: "page-quantum",
                    title: "Quantum",
                    folderName: "Physics",
                    updatedAt: Date(timeIntervalSince1970: 200)
                ),
            ],
            pages: [rootNote, folderNote],
            folders: [research, physics]
        )

        #expect(inventory.rootFolderIDs == ["folder-research"])
        #expect(inventory.loosePageIDs == ["page-root"])
        #expect(inventory.childFolderIDsByID["folder-research"] == ["folder-physics"])
        #expect(inventory.pageIDsByFolderID["folder-physics"] == ["page-quantum"])

        let rows = NotesSidebarVisibleTreeBuilder.build(
            rootFolderIds: inventory.rootFolderIDs,
            expandedFolderIds: Set(["folder-research", "folder-physics"]),
            childFolderIdsById: inventory.childFolderIDsByID,
            pageIdsByFolderId: inventory.pageIDsByFolderID
        )

        #expect(rows == [
            .folder(id: "folder-research", indent: 0),
            .folder(id: "folder-physics", indent: 1),
            .page(id: "page-quantum", indent: 2),
        ])
    }

    private func makeEntry(
        pageId: String,
        title: String,
        folderName: String?,
        updatedAt: Date
    ) -> VaultManifest.ManifestEntry {
        VaultManifest.ManifestEntry(
            pageId: pageId,
            title: title,
            tags: [],
            folderName: folderName,
            wordCount: 0,
            snippet: title,
            updatedAt: updatedAt,
            createdAt: .distantPast
        )
    }
}
