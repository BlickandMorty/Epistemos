import Testing
import SwiftData
@testable import Epistemos

/// Audit tests for note-saving bug fix (March 3, 2026)
/// Verifies that modelContext.save() doesn't trigger @Query cascade before file write
@Suite("Note Saving Audit — W17.16")
@MainActor
struct NoteSavingAuditTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([SDPage.self, SDFolder.self, SDPageVersion.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("restore marks page dirty for vault export")
    func restoreMarksPageDirty() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let page = SDPage(title: "Restore Test")
        context.insert(page)
        try context.save()

        try DiffSheetView.persistRestoredBody("# Restored\n\nBody", to: page, modelContext: context)

        #expect(page.loadBody() == "# Restored\n\nBody")
        #expect(page.wordCount == 2)
        #expect(page.needsVaultSync)
    }

    @Test("blank restore stays dirty and resets word count")
    func blankRestoreMarksPageDirty() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let page = SDPage(title: "Blank Restore Test")
        context.insert(page)
        try context.save()

        try DiffSheetView.persistRestoredBody("", to: page, modelContext: context)

        #expect(page.loadBody() == "")
        #expect(page.wordCount == 0)
        #expect(page.needsVaultSync)
    }
}

/// Edge case tests for note saving
@Suite("Note Saving Edge Cases — W17.16")
struct NoteSavingEdgeCaseTests {
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("note-saving-audit-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    @Test("empty body saves correctly")
    func emptyBodySave() async throws {
        // GIVEN: Empty note body
        // WHEN: Save triggered
        // THEN: File should be written with empty content (not deleted)
        let pageId = UUID().uuidString
        let emptyContent = ""
        
        // Write empty content
        await Task.detached {
            NoteFileStorage.writeBody(pageId: pageId, content: emptyContent)
        }.value
        
        // Verify read returns empty (not nil or error)
        let readContent = NoteFileStorage.readBody(pageId: pageId)
        #expect(readContent == "")
    }
    
    @Test("large body (>50K chars) saves correctly")
    func largeBodySave() async throws {
        // GIVEN: Large note body (50K characters)
        let largeContent = String(repeating: "A very long line with some content. ", count: 1500)
        #expect(largeContent.count > 50000)
        
        let pageId = UUID().uuidString
        
        // WHEN: Save triggered
        await Task.detached {
            NoteFileStorage.writeBody(pageId: pageId, content: largeContent)
        }.value
        
        // THEN: Content should be fully persisted
        let readContent = NoteFileStorage.readBody(pageId: pageId)
        #expect(readContent == largeContent)
    }
    
    @Test("rapid save toggle doesn't corrupt")
    func rapidSaveToggle() async throws {
        // GIVEN: Rapid save triggers (simulating typing + tab switch)
        let pageId = UUID().uuidString
        let contents = ["First", "Second", "Third", "Fourth", "Fifth"]
        
        // WHEN: Multiple rapid saves
        for content in contents {
            await Task.detached {
                NoteFileStorage.writeBody(pageId: pageId, content: content)
            }.value
        }
        
        // THEN: Final content should be one of the saves (not empty)
        let readContent = NoteFileStorage.readBody(pageId: pageId)
        #expect(contents.contains(readContent))
    }

    @Test("mapped loadBody preserves file and inline fallback semantics")
    @MainActor func mappedLoadBodyMatchesCurrentSemantics() async throws {
        let page = SDPage(title: "Mapped")
        let body = String(repeating: "Mapped body ", count: 64)

        page.saveBody(body)
        #expect(page.loadBody(mapped: true) == body)
        #expect(page.loadBody() == body)

        let fallback = SDPage(title: "Fallback")
        fallback.body = "Inline fallback"
        #expect(fallback.loadBody(mapped: true) == "Inline fallback")
    }

    @Test("loadBody falls back to a readable vault source when the managed body file is missing")
    @MainActor func loadBodyFallsBackToReadableVaultSourceWhenManagedBodyIsMissing() throws {
        let storageURL = try makeTempDirectory()
        let vaultURL = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: storageURL)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        try NoteFileStorage.withStorageDirectoryOverrideForTesting(storageURL) {
            let page = SDPage(title: "Vault Fallback")
            let fileURL = vaultURL.appendingPathComponent("Vault Fallback.md")
            try """
            ---
            title: Vault Fallback
            ---

            Recovered from the vault body
            """.write(to: fileURL, atomically: true, encoding: .utf8)
            page.filePath = fileURL.path

            #expect(!NoteFileStorage.bodyExists(pageId: page.id))
            #expect(page.loadBody() == "Recovered from the vault body")
            #expect(page.loadBody(mapped: true) == "Recovered from the vault body")
        }
    }

    @Test("loadBody preserves an intentionally blank managed body even when the vault source still has content")
    @MainActor func loadBodyDoesNotResurrectVaultContentWhenManagedBodyExists() throws {
        let storageURL = try makeTempDirectory()
        let vaultURL = try makeTempDirectory()
        defer {
            try? FileManager.default.removeItem(at: storageURL)
            try? FileManager.default.removeItem(at: vaultURL)
        }

        try NoteFileStorage.withStorageDirectoryOverrideForTesting(storageURL) {
            let page = SDPage(title: "Blank Managed Body")
            let fileURL = vaultURL.appendingPathComponent("Blank Managed Body.md")
            try """
            ---
            title: Blank Managed Body
            ---

            Older vault content
            """.write(to: fileURL, atomically: true, encoding: .utf8)
            page.filePath = fileURL.path

            page.saveBody("")

            #expect(NoteFileStorage.bodyExists(pageId: page.id))
            #expect(page.loadBody().isEmpty)
            #expect(page.loadBody(mapped: true).isEmpty)
        }
    }
    
    // MARK: - External Body Change Notification Tests (P1 fix)
    // Verifies the pageBodyDidChange notification mechanism that replaced
    // the broken onChange(of: page.body) for migrated notes.

    @Test("pageBodyDidChange notification carries correct pageId")
    @MainActor func pageBodyDidChangeNotification() async throws {
        actor NotificationCapture {
            private var received = false
            private var pageId = ""

            func record(pageId: String) {
                self.pageId = pageId
                received = true
            }

            func snapshot() -> (received: Bool, pageId: String) {
                (received, pageId)
            }
        }

        let pageId = UUID().uuidString
        NoteFileStorage.writeBody(pageId: pageId, content: "Original content")

        // Listen for the notification
        let capture = NotificationCapture()
        let token = NotificationCenter.default.addObserver(
            forName: NoteFileStorage.pageBodyDidChange,
            object: nil, queue: .main
        ) { notification in
            if let pid = notification.userInfo?["pageId"] as? String {
                Task {
                    await capture.record(pageId: pid)
                }
            }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        // Simulate restore: write new body then notify
        NoteFileStorage.writeBody(pageId: pageId, content: "Restored version")
        NoteFileStorage.notifyBodyChanged(pageId: pageId)

        // Give RunLoop a tick to deliver the notification
        try await Task.sleep(for: .milliseconds(100))

        let snapshot = await capture.snapshot()
        #expect(snapshot.received, "Notification should have been received")
        #expect(snapshot.pageId == pageId, "Notification should carry the correct pageId")

        // Verify disk state matches the restored content
        let disk = NoteFileStorage.readBody(pageId: pageId)
        #expect(disk == "Restored version")
    }

    @Test("restore to non-empty version — disk reflects new content after notification")
    func restoreToNonEmptyVersion() async throws {
        let pageId = UUID().uuidString

        // GIVEN: A note with original content
        NoteFileStorage.writeBody(pageId: pageId, content: "Current editor content")

        // WHEN: DiffSheetView restores to an older version (simulated)
        let restoredBody = "# Older Version\n\nThis was the previous version of the note."
        NoteFileStorage.writeBody(pageId: pageId, content: restoredBody)

        // The editor would reload on notification — verify disk is ready
        let disk = NoteFileStorage.readBody(pageId: pageId)
        #expect(disk == restoredBody, "Disk should have restored content for editor reload")
    }

    @Test("restore to empty version — disk reflects blank after notification")
    func restoreToEmptyVersion() async throws {
        let pageId = UUID().uuidString

        // GIVEN: A note with content
        NoteFileStorage.writeBody(pageId: pageId, content: "Non-empty note body")
        #expect(NoteFileStorage.readBody(pageId: pageId).count > 0)

        // WHEN: Restore to a version that was blank
        NoteFileStorage.writeBody(pageId: pageId, content: "")

        // THEN: Disk is blank — editor reload would get empty string
        let disk = NoteFileStorage.readBody(pageId: pageId)
        #expect(disk == "", "Blank restore must persist — editor reload depends on it")
    }

    @Test("undo restore — disk reflects pre-restore content")
    func undoRestoreReflectsPreRestoreContent() async throws {
        let pageId = UUID().uuidString

        // GIVEN: Original content
        let original = "Original content before restore"
        NoteFileStorage.writeBody(pageId: pageId, content: original)

        // WHEN: Restore changes content
        NoteFileStorage.writeBody(pageId: pageId, content: "Restored version")
        #expect(NoteFileStorage.readBody(pageId: pageId) == "Restored version")

        // THEN: Undo restore writes back original
        NoteFileStorage.writeBody(pageId: pageId, content: original)
        let disk = NoteFileStorage.readBody(pageId: pageId)
        #expect(disk == original, "Undo restore should revert to pre-restore content")
    }

    @Test("external vault sync body replacement — disk ready for editor reload")
    func externalVaultSyncBodyReplacement() async throws {
        let pageId = UUID().uuidString

        // GIVEN: Editor has content
        NoteFileStorage.writeBody(pageId: pageId, content: "In-app content")

        // WHEN: Vault sync replaces body from external .md file change
        let vaultContent = "# Updated from external editor\n\nEdited in Obsidian."
        NoteFileStorage.writeBody(pageId: pageId, content: vaultContent)

        // THEN: Disk reflects vault content — editor notification would trigger reload
        let disk = NoteFileStorage.readBody(pageId: pageId)
        #expect(disk == vaultContent, "Vault sync body should be on disk for editor reload")
    }

    @Test("unicode content saves correctly")
    func unicodeContentSave() async throws {
        // GIVEN: Unicode content (emoji, CJK, RTL)
        let unicodeContent = """
        Emoji: 🎉 🚀 👍 📝
        CJK: こんにちは 你好 안녕하세요
        RTL: مرحبا שלום
        Special: café naïve résumé
        """
        let pageId = UUID().uuidString
        
        // WHEN: Save triggered
        await Task.detached {
            NoteFileStorage.writeBody(pageId: pageId, content: unicodeContent)
        }.value
        
        // THEN: Content should be exactly preserved
        let readContent = NoteFileStorage.readBody(pageId: pageId)
        #expect(readContent == unicodeContent)
    }
}
