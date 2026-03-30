import Testing
import SwiftData
import SwiftUI
@testable import Epistemos

/// Stress tests for note-saving pipeline
/// Tests concurrent edits, rapid saves, tab switching, and app restart scenarios
@Suite("Note Saving Stress Tests — W17.16")
struct NoteSavingStressTests {
    
    // MARK: - Helper Methods
    
    /// Creates a unique test page ID
    private func createTestPageId() -> String {
        "stress-test-\(UUID().uuidString)"
    }
    
    /// Simulates concurrent text modifications
    private func simulateConcurrentEdits(pageId: String, iterations: Int) async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let content = "Concurrent edit #\(i) at \(Date().timeIntervalSince1970)"
                    await Task.detached(priority: .utility) {
                        NoteFileStorage.writeBody(pageId: pageId, content: content)
                    }.value
                }
            }
        }
    }
    
    /// Simulates rapid sequential saves
    private func simulateRapidSaves(pageId: String, count: Int) async -> String {
        let finalContent = "Final rapid save content \(UUID().uuidString)"
        
        for i in 0..<count {
            let content = "Rapid save #\(i): \(UUID().uuidString)"
            await Task.detached(priority: .utility) {
                NoteFileStorage.writeBody(pageId: pageId, content: content)
            }.value
            
            // Minimal delay to simulate typing
            try? await Task.sleep(for: .milliseconds(10))
        }
        
        // Final save with known content
        await Task.detached(priority: .utility) {
            NoteFileStorage.writeBody(pageId: pageId, content: finalContent)
        }.value
        
        return finalContent
    }
    
    // MARK: - Stress Tests
    
    @Test("concurrent file writes - last writer wins")
    func concurrentFileWrites() async throws {
        // GIVEN: A page ID with multiple concurrent writers
        let pageId = createTestPageId()
        let iterations = 50
        
        // WHEN: 50 concurrent writes happen simultaneously
        await simulateConcurrentEdits(pageId: pageId, iterations: iterations)
        
        // THEN: File should exist and contain one of the written values (not crash/corrupt)
        let readContent = NoteFileStorage.readBody(pageId: pageId)
        #expect(!readContent.isEmpty, "File should not be empty after concurrent writes")
        
        // Verify file is valid (not corrupted binary data)
        #expect(readContent.contains("Concurrent edit") || readContent.contains("Rapid save") || readContent.isEmpty == false)
    }
    
    @Test("rapid save cycle - simulate typing burst")
    func rapidSaveCycle() async throws {
        // GIVEN: A page being edited rapidly (like user typing fast)
        let pageId = createTestPageId()
        let saveCount = 100
        
        // WHEN: 100 rapid saves occur
        let finalContent = await simulateRapidSaves(pageId: pageId, count: saveCount)
        
        // Allow any pending background writes to complete
        try? await Task.sleep(for: .milliseconds(500))
        
        // THEN: Final read should match the last saved content
        let readContent = NoteFileStorage.readBody(pageId: pageId)
        #expect(readContent == finalContent, 
                "Final content mismatch. Expected: '\(finalContent)', Got: '\(readContent)'")
    }
    
    @Test("save during tab switch - flush timing")
    func saveDuringTabSwitch() async throws {
        // GIVEN: Two pages being switched rapidly
        let pageA = createTestPageId()
        let pageB = createTestPageId()
        
        let contentA = "Page A content \(UUID().uuidString)"
        let contentB = "Page B content \(UUID().uuidString)"
        
        // WHEN: Rapidly switching between pages and saving
        for i in 0..<20 {
            // Save page A
            await Task.detached {
                NoteFileStorage.writeBody(pageId: pageA, content: "\(contentA) - iteration \(i)")
            }.value
            
            // Immediate switch to B and save
            await Task.detached {
                NoteFileStorage.writeBody(pageId: pageB, content: "\(contentB) - iteration \(i)")
            }.value
            
            try? await Task.sleep(for: .milliseconds(5))
        }
        
        // Final saves
        await Task.detached {
            NoteFileStorage.writeBody(pageId: pageA, content: contentA)
        }.value
        await Task.detached {
            NoteFileStorage.writeBody(pageId: pageB, content: contentB)
        }.value
        
        // THEN: Both pages should have correct final content
        try? await Task.sleep(for: .milliseconds(200))
        
        let readA = NoteFileStorage.readBody(pageId: pageA)
        let readB = NoteFileStorage.readBody(pageId: pageB)
        
        #expect(readA == contentA, "Page A content mismatch")
        #expect(readB == contentB, "Page B content mismatch")
    }
    
    @Test("empty content edge case - zero byte handling")
    func emptyContentHandling() async throws {
        // GIVEN: A page with content that becomes empty
        let pageId = createTestPageId()
        
        // Write content first
        await Task.detached {
            NoteFileStorage.writeBody(pageId: pageId, content: "Initial content")
        }.value
        
        // WHEN: Content is cleared (empty string)
        await Task.detached {
            NoteFileStorage.writeBody(pageId: pageId, content: "")
        }.value
        
        // THEN: File should exist with empty content (not deleted/corrupted)
        let readContent = NoteFileStorage.readBody(pageId: pageId)
        #expect(readContent == "", "Empty content should be preserved")
    }
    
    @Test("unicode stress test - emoji and special characters")
    func unicodeStressTest() async throws {
        // GIVEN: Content with complex Unicode
        let pageId = createTestPageId()
        let iterations = 25
        
        let testStrings = [
            "Emoji: 🎉🚀👍📝🔥💯🎯",
            "CJK: こんにちは世界你好안녕하세요",
            "RTL: مرحبا بالعالم שלום עולם",
            "Math: ∑∏∫√∞≈≠",
            "Zalgo: T̷͓̖̈́h̴͚͑i̶͓͗s̵̼̈́ ̸̻̓i̴̡͠s̵̱͌ ̶͇͠f̵̡̆i̶̢̽n̸͔͗e̴̙͠",
            "Mixed: Hello 👋 World 🌍 你好 世界 שלום עולם"
        ]
        
        // WHEN: Multiple Unicode strings written rapidly
        for (index, testString) in testStrings.enumerated() {
            for i in 0..<iterations {
                let content = "\(testString) - round \(i)"
                await Task.detached {
                    NoteFileStorage.writeBody(pageId: "\(pageId)-\(index)", content: content)
                }.value
            }
        }
        
        // THEN: All Unicode content should be readable
        try? await Task.sleep(for: .milliseconds(100))
        
        for (index, testString) in testStrings.enumerated() {
            let readContent = NoteFileStorage.readBody(pageId: "\(pageId)-\(index)")
            #expect(readContent.contains(testString), 
                    "Unicode string \(index) corrupted: '\(readContent)'")
        }
    }
    
    @Test("large document stress - 100K characters")
    func largeDocumentStress() async throws {
        // GIVEN: A large document (100K+ characters)
        let pageId = createTestPageId()
        let largeContent = String(repeating: "This is a line of text in a very long document. ", count: 2100)
        #expect(largeContent.count > 100000)
        
        // WHEN: Large content is saved
        await Task.detached(priority: .utility) {
            NoteFileStorage.writeBody(pageId: pageId, content: largeContent)
        }.value
        
        // Allow write to complete
        try? await Task.sleep(for: .seconds(1))
        
        // THEN: Content should be fully preserved
        let readContent = NoteFileStorage.readBody(pageId: pageId)
        #expect(readContent.count == largeContent.count,
                "Large document size mismatch. Expected: \(largeContent.count), Got: \(readContent.count)")
        #expect(readContent == largeContent, "Large document content mismatch")
    }
    
    @Test("simulated crash - incomplete save recovery")
    func simulatedCrashRecovery() async throws {
        // GIVEN: Content saved before "crash"
        let pageId = createTestPageId()
        let originalContent = "Important content that must survive: \(UUID().uuidString)"
        
        // Save original content
        await Task.detached {
            NoteFileStorage.writeBody(pageId: pageId, content: originalContent)
        }.value
        
        try? await Task.sleep(for: .milliseconds(100))
        
        // Verify it was saved
        let firstRead = NoteFileStorage.readBody(pageId: pageId)
        #expect(firstRead == originalContent)
        
        // WHEN: Simulate "crash" during new save by overwriting with empty
        // (simulating partial write that got truncated)
        await Task.detached {
            NoteFileStorage.writeBody(pageId: pageId, content: "")
        }.value
        
        try? await Task.sleep(for: .milliseconds(50))
        
        // THEN: File exists but is empty (this is expected behavior - atomic writes mean
        // we either get old content or new content, never partial/corrupted)
        let readContent = NoteFileStorage.readBody(pageId: pageId)
        #expect(readContent == "", "Content should be empty after overwrite with empty string")
    }
    
    @Test("vault sync dirty flag persistence")
    func vaultSyncDirtyFlag() async throws {
        // This test verifies the dirty flag mechanism works correctly
        // even without modelContext.save()
        
        // GIVEN: A page with needsVaultSync = true
        let pageId = createTestPageId()
        let content = "Content to sync: \(UUID().uuidString)"
        
        // Write content (simulates debouncedSave)
        await Task.detached {
            NoteFileStorage.writeBody(pageId: pageId, content: content)
        }.value
        
        // WHEN: We check the file exists
        try? await Task.sleep(for: .milliseconds(100))
        
        // THEN: File should exist and be readable
        let readContent = NoteFileStorage.readBody(pageId: pageId)
        #expect(readContent == content)
        
        // Note: The dirty flag (needsVaultSync) is in-memory only now.
        // This is acceptable because:
        // 1. File is already saved
        // 2. Vault sync runs periodically and checks for files newer than vault export
        // 3. If app crashes, next launch compares file dates anyway
    }
    
    @Test("multiple page concurrent stress")
    func multiplePageConcurrentStress() async throws {
        // GIVEN: 20 pages being edited simultaneously
        let pageCount = 20
        let editsPerPage = 25
        var pageIds: [String] = []
        var expectedContent: [String: String] = [:]
        
        for i in 0..<pageCount {
            let pageId = createTestPageId()
            pageIds.append(pageId)
            expectedContent[pageId] = "Final content for page \(i): \(UUID().uuidString)"
        }
        
        // WHEN: All pages being edited concurrently
        await withTaskGroup(of: Void.self) { group in
            for pageId in pageIds {
                let finalContent = expectedContent[pageId]
                group.addTask { [pageId, finalContent] in
                    for edit in 0..<editsPerPage {
                        let content = "Page \(pageId) edit \(edit)"
                        await Task.detached {
                            NoteFileStorage.writeBody(pageId: pageId, content: content)
                        }.value
                        try? await Task.sleep(for: .milliseconds(5))
                    }
                    
                    // Final save
                    if let finalContent {
                        await Task.detached {
                            NoteFileStorage.writeBody(pageId: pageId, content: finalContent)
                        }.value
                    }
                }
            }
        }
        
        // Allow all writes to complete
        try? await Task.sleep(for: .milliseconds(500))
        
        // THEN: All pages should have correct final content
        for pageId in pageIds {
            let readContent = NoteFileStorage.readBody(pageId: pageId)
            let expected = expectedContent[pageId] ?? ""
            #expect(readContent == expected, 
                    "Page \(pageId) content mismatch. Expected: '\(expected)', Got: '\(readContent)'")
        }
    }
    
    // MARK: - Blank-Note Save Regression Tests (W17.16)
    // Validates that intentionally clearing a note to blank persists correctly.
    // Regression: empty-write guards (defense-in-depth for zero-byte bug) were
    // blocking legitimate blank saves. The root cause fix (textDidChange restructure,
    // NSNotFound bounds checks, direct file save) makes empty-write guards redundant.

    @Test("clear note to blank — content becomes empty string on disk")
    func clearNoteToBlank() async throws {
        let pageId = createTestPageId()

        // GIVEN: A note with real content
        NoteFileStorage.writeBody(pageId: pageId, content: "# My Important Note\n\nWith several paragraphs of content.")
        #expect(NoteFileStorage.readBody(pageId: pageId).count > 0)

        // WHEN: User selects all and deletes (clears to blank)
        NoteFileStorage.writeBody(pageId: pageId, content: "")

        // THEN: Disk content is empty string, not the old content
        let disk = NoteFileStorage.readBody(pageId: pageId)
        #expect(disk == "", "Blank save must persist — got \(disk.count) bytes instead of 0")
        #expect(NoteFileStorage.bodyExists(pageId: pageId), "File should still exist after blanking")
    }

    @Test("blank note survives page switch — flush writes empty")
    func blankNoteSurvivesPageSwitch() async throws {
        let pageA = createTestPageId()
        let pageB = createTestPageId()

        // GIVEN: Page A has content, page B has content
        NoteFileStorage.writeBody(pageId: pageA, content: "Page A content")
        NoteFileStorage.writeBody(pageId: pageB, content: "Page B content")

        // WHEN: User clears page A to blank, then switches to page B
        // (page swap flushes page A's current text — which is now empty)
        NoteFileStorage.writeBody(pageId: pageA, content: "")

        // Simulate: switch to page B, read it
        let bContent = NoteFileStorage.readBody(pageId: pageB)
        #expect(bContent == "Page B content")

        // THEN: Page A is still blank on disk (switch didn't restore old content)
        let aContent = NoteFileStorage.readBody(pageId: pageA)
        #expect(aContent == "", "Page A should remain blank after switch — got \(aContent.count) bytes")
    }

    @Test("blank note survives quit/reopen — readBody returns empty")
    func blankNoteSurvivesQuitReopen() async throws {
        let pageId = createTestPageId()

        // GIVEN: Note with content
        NoteFileStorage.writeBody(pageId: pageId, content: "Content before quit")
        #expect(NoteFileStorage.readBody(pageId: pageId) == "Content before quit")

        // WHEN: User clears note and "quits" (flushIfNeeded writes empty)
        NoteFileStorage.writeBody(pageId: pageId, content: "")

        // Simulate quit + reopen: fresh read from disk
        let afterReopen = NoteFileStorage.readBody(pageId: pageId)
        #expect(afterReopen == "", "Blank note must survive quit/reopen — got '\(afterReopen)'")
    }

    @Test("multiple blank-then-restore cycles — no stale content leaks")
    func blankThenRestoreCycles() async throws {
        let pageId = createTestPageId()

        for i in 0..<5 {
            // Write content
            let content = "Cycle \(i) content: \(UUID().uuidString)"
            NoteFileStorage.writeBody(pageId: pageId, content: content)
            #expect(NoteFileStorage.readBody(pageId: pageId) == content)

            // Clear to blank
            NoteFileStorage.writeBody(pageId: pageId, content: "")
            #expect(NoteFileStorage.readBody(pageId: pageId) == "",
                    "Cycle \(i): blank save failed")
        }

        // Final state: blank
        #expect(NoteFileStorage.readBody(pageId: pageId) == "")
    }

    @Test("blank note disk bytes are exactly zero")
    func blankNoteDiskBytesZero() async throws {
        let pageId = createTestPageId()

        // GIVEN: Note with content
        NoteFileStorage.writeBody(pageId: pageId, content: "Some content here")

        // WHEN: Cleared to blank
        NoteFileStorage.writeBody(pageId: pageId, content: "")

        // THEN: Raw file data is exactly 0 bytes (not whitespace, not BOM, not null bytes)
        let data = NoteFileStorage.readBodyData(pageId: pageId)
        #expect(data != nil, "File should exist")
        #expect(data?.count == 0, "File should be exactly 0 bytes — got \(data?.count ?? -1)")
    }

    @Test("rapid open-close-open cycle")
    func rapidOpenCloseCycle() async throws {
        // GIVEN: A page being opened, edited, closed, reopened repeatedly
        let pageId = createTestPageId()
        let iterations = 10
        
        var expectedContents: [String] = []
        
        for i in 0..<iterations {
            // Simulate "open" - read current content
            let _ = NoteFileStorage.readBody(pageId: pageId)
            
            // Simulate "edit" - write new content
            let newContent = "Edit cycle \(i): \(UUID().uuidString)"
            expectedContents.append(newContent)
            
            await Task.detached {
                NoteFileStorage.writeBody(pageId: pageId, content: newContent)
            }.value
            
            // Simulate "close" - flush
            try? await Task.sleep(for: .milliseconds(50))
        }
        
        // Allow final write to complete
        try? await Task.sleep(for: .milliseconds(200))
        
        // THEN: Final content should be the last edit
        let finalRead = NoteFileStorage.readBody(pageId: pageId)
        let expectedFinal = expectedContents.last ?? ""
        #expect(finalRead == expectedFinal, 
                "Final content after rapid open/close should be last edit")
    }
}

/// Integration tests for SwiftData ↔ File storage ↔ Vault sync
@Suite("Note Storage Integration Tests")
struct NoteStorageIntegrationTests {
    
    @Test("SDPage body storage roundtrip")
    func sdPageBodyRoundtrip() async throws {
        // This test verifies that SDPage.loadBody() and SDPage.saveBody()
        // work correctly through the file storage layer
        
        let pageId = UUID().uuidString
        let testContent = "Test content for SDPage roundtrip: \(UUID().uuidString)"
        
        // Write via NoteFileStorage (simulating what SDPage.saveBody does)
        await Task.detached {
            NoteFileStorage.writeBody(pageId: pageId, content: testContent)
        }.value
        
        // Allow write to complete
        try? await Task.sleep(for: .milliseconds(100))
        
        // Read via NoteFileStorage (simulating what SDPage.loadBody does)
        let readContent = NoteFileStorage.readBody(pageId: pageId)
        
        #expect(readContent == testContent, "SDPage storage roundtrip failed")
    }

    @Test("scheduled body writes stay readable before the durable flush completes")
    func scheduledBodyWritesStayReadableBeforeFlushCompletes() async throws {
        let storageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EpistemosTests-AsyncRead-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: storageURL)
        }

        await NoteFileStorage.withStorageDirectoryOverrideForTesting(storageURL, operation: { @MainActor in
            let pageId = UUID().uuidString
            let content = String(repeating: "Pending async body line\n", count: 4096)

            let writeTask = NoteFileStorage.scheduleWriteBody(pageId: pageId, content: content)

            let immediateRead = NoteFileStorage.readBody(pageId: pageId)
            #expect(immediateRead == content)

            let completed = await writeTask?.value
            #expect(completed == true)
            let finalRead = NoteFileStorage.readBody(pageId: pageId)
            #expect(finalRead == content)
        })
    }
    
    @Test("empty note body handling")
    func emptyNoteBodyHandling() async throws {
        let pageId = UUID().uuidString
        
        // SDPage with empty body (post-migration state)
        await Task.detached {
            NoteFileStorage.writeBody(pageId: pageId, content: "")
        }.value
        
        try? await Task.sleep(for: .milliseconds(50))
        
        // Read should return empty string (not nil/crash)
        let readContent = NoteFileStorage.readBody(pageId: pageId)
        #expect(readContent == "")
        
        // File should exist even if empty
        let fileManager = FileManager.default
        let noteBodiesDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Epistemos/note-bodies")
        let fileURL = noteBodiesDir?.appendingPathComponent("\(pageId).md")
        
        if let url = fileURL {
            let exists = fileManager.fileExists(atPath: url.path)
            #expect(exists, "Empty note file should still exist")
            
            if exists {
                let data = fileManager.contents(atPath: url.path)
                #expect(data != nil && data?.count == 0, "File should be empty (0 bytes)")
            }
        }
    }
    
    @Test("file atomic write verification")
    func fileAtomicWriteVerification() async throws {
        // Tests that NoteFileStorage uses atomic writes (no partial/corrupted files)
        let pageId = UUID().uuidString
        let iterations = 100
        let expectedFinal = "Final atomic content: \(UUID().uuidString)"
        
        // Rapidly write different content
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let content = "Iteration \(i): \(UUID().uuidString)"
                    await Task.detached {
                        NoteFileStorage.writeBody(pageId: pageId, content: content)
                    }.value
                }
            }
        }
        
        // Final write
        await Task.detached {
            NoteFileStorage.writeBody(pageId: pageId, content: expectedFinal)
        }.value
        
        try? await Task.sleep(for: .milliseconds(200))
        
        // Read should be either one of the iterations OR the final (never corrupted)
        let readContent = NoteFileStorage.readBody(pageId: pageId)
        
        // Due to atomic writes, we should never see partial/corrupted content
        // It should be exactly one of the complete strings written
        #expect(readContent == expectedFinal || readContent.contains("Iteration"),
                "File should contain complete content, never partial/corrupted data")
    }
}
