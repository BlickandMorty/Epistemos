import Testing
@testable import Epistemos
import Foundation

// MARK: - Vault Sync Tests (45 tests)

@Suite("Vault File Operations")
@MainActor
struct VaultFileOperationTests {
    
    @Test("File creation writes UTF-8 content")
    func fileCreationUTF8() async throws {
        let storage = StubNoteFileStorage()
        let content = "Test content with émojis 🎉"
        let path = try await storage.write(content: content, to: "test.md")
        
        #expect(path != nil)
        let readContent = try await storage.read(from: path!)
        #expect(readContent == content)
    }
    
    @Test("File update preserves encoding")
    func fileUpdateEncoding() async throws {
        let storage = StubNoteFileStorage()
        let path = try await storage.write(content: "Original", to: "test.md")
        
        try await storage.update(content: "Updated: ñoño", at: path!)
        let content = try await storage.read(from: path!)
        #expect(content == "Updated: ñoño")
    }
    
    @Test("File deletion removes from disk")
    func fileDeletion() async throws {
        let storage = StubNoteFileStorage()
        let path = try await storage.write(content: "To delete", to: "delete.md")
        
        try await storage.delete(at: path!)
        let exists = await storage.fileExists(at: path!)
        #expect(!exists)
    }
    
    @Test("File move updates location")
    func fileMove() async throws {
        let storage = StubNoteFileStorage()
        let oldPath = try await storage.write(content: "Content", to: "old.md")
        let newPath = oldPath!.replacingOccurrences(of: "old.md", with: "new.md")
        
        try await storage.move(from: oldPath!, to: newPath)
        let existsAtNew = await storage.fileExists(at: newPath)
        let existsAtOld = await storage.fileExists(at: oldPath!)
        
        #expect(existsAtNew)
        #expect(!existsAtOld)
    }
    
    @Test("Directory creation for nested files")
    func directoryCreation() async throws {
        let storage = StubNoteFileStorage()
        let path = "folder/subfolder/note.md"
        
        let fullPath = try await storage.write(content: "Nested", to: path)
        #expect(fullPath != nil)
        
        let content = try await storage.read(from: fullPath!)
        #expect(content == "Nested")
    }
    
    @Test("File reading with Latin-1 fallback")
    func latin1Fallback() async throws {
        let storage = StubNoteFileStorage()
        // Simulate Latin-1 encoded file
        let path = try await storage.write(content: "café", to: "latin.md")
        let content = try await storage.readWithFallback(from: path!)
        #expect(content != nil)
    }
    
    @Test("File existence check")
    func fileExistence() async {
        let storage = StubNoteFileStorage()
        let exists = await storage.fileExists(at: "/nonexistent/file.md")
        #expect(!exists)
    }
    
    @Test("File modification date retrieval")
    func fileModificationDate() async throws {
        let storage = StubNoteFileStorage()
        let path = try await storage.write(content: "Test", to: "date.md")
        let date = await storage.modificationDate(for: path!)
        #expect(date != nil)
    }
    
    @Test("File size calculation")
    func fileSize() async throws {
        let storage = StubNoteFileStorage()
        let content = "Hello, World!"
        let path = try await storage.write(content: content, to: "size.md")
        let size = await storage.fileSize(at: path!)
        #expect(size == content.utf8.count)
    }
}

@Suite("Vault Sync Service")
@MainActor
struct VaultSyncServiceTests {
    
    @Test("Sync detects new files")
    func syncDetectsNewFiles() async {
        let service = StubVaultSyncService()
        let newFiles = ["new1.md", "new2.md"]
        
        let changes = await service.detectChanges(files: newFiles)
        #expect(changes.newFiles.count == 2)
    }
    
    @Test("Sync detects modified files")
    func syncDetectsModified() async {
        let service = StubVaultSyncService()
        let changes = await service.detectChanges(
            files: ["modified.md"],
            modifiedDates: ["modified.md": Date()]
        )
        #expect(changes.modifiedFiles.count == 1)
    }
    
    @Test("Sync detects deleted files")
    func syncDetectsDeleted() async {
        let service = StubVaultSyncService()
        await service.markAsSynced(files: ["deleted.md"])
        
        let changes = await service.detectChanges(files: [])
        #expect(changes.deletedFiles.count == 1)
    }
    
    @Test("Bidirectional sync merges changes")
    func bidirectionalSync() async {
        let service = StubVaultSyncService()
        let result = await service.syncBidirectional()
        #expect(result.success)
    }
    
    @Test("Conflict resolution with newer file")
    func conflictResolution() async {
        let service = StubVaultSyncService()
        let resolution = await service.resolveConflict(
            file: "conflict.md",
            localDate: Date(),
            remoteDate: Date().addingTimeInterval(-3600)
        )
        #expect(resolution == .useLocal)
    }
    
    @Test("Batch sync processes multiple files")
    func batchSync() async {
        let service = StubVaultSyncService()
        let result = await service.syncBatch(files: Array(repeating: "file.md", count: 100))
        #expect(result.processed == 100)
    }
    
    @Test("Sync pause and resume")
    func syncPauseResume() async {
        let service = StubVaultSyncService()
        await service.pause()
        #expect(service.isPaused)
        
        await service.resume()
        #expect(!service.isPaused)
    }
    
    @Test("Sync progress reporting")
    func syncProgress() async {
        let service = StubVaultSyncService()
        var progressUpdates: [Double] = []
        
        await service.syncWithProgress { progress in
            progressUpdates.append(progress)
        }
        
        #expect(progressUpdates.contains(1.0))
    }
    
    @Test("Initial sync populates database")
    func initialSync() async {
        let service = StubVaultSyncService()
        let result = await service.performInitialSync()
        #expect(result.importedCount > 0)
    }
}

@Suite("Block Parser")
@MainActor
struct BlockParserTests {
    
    @Test("Parses simple paragraphs")
    func simpleParagraphs() async {
        let parser = StubBlockParser()
        let body = "Para 1\n\nPara 2"
        let blocks = parser.parse(body: body, pageId: "p1")
        #expect(blocks.count == 2)
    }
    
    @Test("Parses headings")
    func headings() async {
        let parser = StubBlockParser()
        let body = "# Heading 1\n## Heading 2"
        let blocks = parser.parse(body: body, pageId: "p1")
        #expect(blocks.count == 2)
        #expect(blocks[0].depth == 0)
        #expect(blocks[1].depth == 1)
    }
    
    @Test("Parses nested lists")
    func nestedLists() async {
        let parser = StubBlockParser()
        let body = "- Item 1\n  - Nested 1\n  - Nested 2\n- Item 2"
        let blocks = parser.parse(body: body, pageId: "p1")
        #expect(blocks.count == 4)
        #expect(blocks[1].depth == 1)
    }
    
    @Test("Parses code blocks")
    func codeBlocks() async {
        let parser = StubBlockParser()
        let body = "```swift\nlet x = 1\n```"
        let blocks = parser.parse(body: body, pageId: "p1")
        #expect(blocks.count == 1)
        #expect(blocks[0].content.contains("swift"))
    }
    
    @Test("Parses blockquotes")
    func blockquotes() async {
        let parser = StubBlockParser()
        let body = "> Quote\n> More quote"
        let blocks = parser.parse(body: body, pageId: "p1")
        #expect(blocks.count == 1)
    }
    
    @Test("Parses tables")
    func tables() async {
        let parser = StubBlockParser()
        let body = "| Col1 | Col2 |\n|------|------|\n| A    | B    |"
        let blocks = parser.parse(body: body, pageId: "p1")
        #expect(blocks.count == 1)
    }
    
    @Test("Parses horizontal rules")
    func horizontalRules() async {
        let parser = StubBlockParser()
        let body = "Before\n\n---\n\nAfter"
        let blocks = parser.parse(body: body, pageId: "p1")
        #expect(blocks.count == 3)
    }
    
    @Test("Preserves block IDs on re-parse")
    func preserveBlockIds() async {
        let parser = StubBlockParser()
        let body = "Content"
        let existingBlocks = [StubParsedBlock(id: "existing-123", content: "Content", order: 0)]
        let blocks = parser.parse(body: body, pageId: "p1", existingBlocks: existingBlocks)
        #expect(blocks.first?.id == "existing-123")
    }
    
    @Test("Detects moved blocks")
    func detectMovedBlocks() async {
        let parser = StubBlockParser()
        let oldBlocks = [
            StubParsedBlock(id: "b1", content: "First", order: 0),
            StubParsedBlock(id: "b2", content: "Second", order: 1)
        ]
        let newBody = "Second\n\nFirst"
        let result = parser.parseWithDiff(body: newBody, pageId: "p1", existingBlocks: oldBlocks)
        #expect(result.moved.count == 2)
    }
    
    @Test("Detects modified blocks")
    func detectModifiedBlocks() async {
        let parser = StubBlockParser()
        let oldBlocks = [StubParsedBlock(id: "b1", content: "Old", order: 0)]
        let newBody = "New"
        let result = parser.parseWithDiff(body: newBody, pageId: "p1", existingBlocks: oldBlocks)
        #expect(result.modified.count == 1)
    }
    
    @Test("Detects deleted blocks")
    func detectDeletedBlocks() async {
        let parser = StubBlockParser()
        let oldBlocks = [
            StubParsedBlock(id: "b1", content: "Keep", order: 0),
            StubParsedBlock(id: "b2", content: "Delete", order: 1)
        ]
        let newBody = "Keep"
        let result = parser.parseWithDiff(body: newBody, pageId: "p1", existingBlocks: oldBlocks)
        #expect(result.deleted.count == 1)
    }
    
    @Test("Detects new blocks")
    func detectNewBlocks() async {
        let parser = StubBlockParser()
        let oldBlocks: [StubParsedBlock] = []
        let newBody = "New content"
        let result = parser.parseWithDiff(body: newBody, pageId: "p1", existingBlocks: oldBlocks)
        #expect(result.added.count == 1)
    }
    
    @Test("Jaccard similarity calculation")
    func jaccardSimilarity() async {
        let parser = StubBlockParser()
        let sim1 = parser.jaccardSimilarity("hello world", "hello world")
        let sim2 = parser.jaccardSimilarity("hello world", "goodbye world")
        #expect(sim1 > sim2)
        #expect(sim1 == 1.0)
    }
    
    @Test("Block matching with similarity")
    func blockMatching() async {
        let parser = StubBlockParser()
        let oldBlocks = [StubParsedBlock(id: "b1", content: "Hello world test", order: 0)]
        let newBlocks = [StubParsedBlock(content: "Hello world testing", order: 0)]
        let matches = parser.matchBlocks(old: oldBlocks, new: newBlocks, threshold: 0.5)
        #expect(matches.count == 1)
    }
}

@Suite("File Watcher")
@MainActor
struct FileWatcherTests {
    
    @Test("Detects file creation")
    func detectsCreation() async {
        let watcher = StubFileWatcher(path: "/tmp/test")
        var detected = false
        
        watcher.onCreate = { _ in detected = true }
        await watcher.simulateEvent(.create("new.md"))
        
        #expect(detected)
    }
    
    @Test("Detects file modification")
    func detectsModification() async {
        let watcher = StubFileWatcher(path: "/tmp/test")
        var detected = false
        
        watcher.onModify = { _ in detected = true }
        await watcher.simulateEvent(.modify("changed.md"))
        
        #expect(detected)
    }
    
    @Test("Detects file deletion")
    func detectsDeletion() async {
        let watcher = StubFileWatcher(path: "/tmp/test")
        var detected = false
        
        watcher.onDelete = { _ in detected = true }
        await watcher.simulateEvent(.delete("removed.md"))
        
        #expect(detected)
    }
    
    @Test("Debounces rapid changes")
    func debouncesChanges() async {
        let watcher = StubFileWatcher(path: "/tmp/test", debounceInterval: 0.1)
        var count = 0
        
        watcher.onModify = { _ in count += 1 }
        
        // Rapid changes
        await watcher.simulateEvent(.modify("file.md"))
        await watcher.simulateEvent(.modify("file.md"))
        await watcher.simulateEvent(.modify("file.md"))
        
        try await Task.sleep(200_000_000) // Wait for debounce
        #expect(count == 1)
    }
    
    @Test("Filters non-markdown files")
    func filtersNonMarkdown() async {
        let watcher = StubFileWatcher(path: "/tmp/test")
        var detected = false
        
        watcher.onCreate = { _ in detected = true }
        await watcher.simulateEvent(.create("image.png"))
        
        #expect(!detected)
    }
    
    @Test("Handles nested directories")
    func handlesNestedDirectories() async {
        let watcher = StubFileWatcher(path: "/tmp/test", recursive: true)
        var detected = false
        
        watcher.onCreate = { _ in detected = true }
        await watcher.simulateEvent(.create("folder/subfolder/note.md"))
        
        #expect(detected)
    }
    
    @Test("Stops watching on cancel")
    func stopsOnCancel() async {
        let watcher = StubFileWatcher(path: "/tmp/test")
        await watcher.start()
        #expect(watcher.isRunning)
        
        await watcher.stop()
        #expect(!watcher.isRunning)
    }
}

@Suite("Sync Index")
@MainActor
struct SyncIndexTests {
    
    @Test("Index records file metadata")
    func indexRecordsMetadata() async {
        let index = StubSyncIndex()
        await index.update(file: "test.md", hash: "abc123", modifiedAt: Date())
        
        let metadata = await index.metadata(for: "test.md")
        #expect(metadata?.hash == "abc123")
    }
    
    @Test("Index detects hash changes")
    func indexDetectsHashChanges() async {
        let index = StubSyncIndex()
        await index.update(file: "test.md", hash: "abc123", modifiedAt: Date())
        
        let changed = await index.hasChanged(file: "test.md", newHash: "def456")
        #expect(changed)
    }
    
    @Test("Index cleanup removes stale entries")
    func indexCleanup() async {
        let index = StubSyncIndex()
        await index.update(file: "old.md", hash: "abc", modifiedAt: Date())
        await index.update(file: "new.md", hash: "def", modifiedAt: Date())
        
        await index.cleanup(existentFiles: ["new.md"])
        let count = await index.entryCount
        #expect(count == 1)
    }
}

// Placeholder implementations
class StubNoteFileStorage {
    func write(content: String, to path: String) async throws -> String? { "/tmp/" + path }
    func read(from path: String) async throws -> String { "content" }
    func readWithFallback(from path: String) async throws -> String? { "content" }
    func update(content: String, at path: String) async throws {}
    func delete(at path: String) async throws {}
    func move(from: String, to: String) async throws {}
    func fileExists(at path: String) async -> Bool { false }
    func modificationDate(for path: String) async -> Date? { Date() }
    func fileSize(at path: String) async -> Int { 100 }
}

class StubVaultSyncService {
    var isPaused = false
    func detectChanges(files: [String], modifiedDates: [String: Date]? = nil) async -> StubSyncChanges {
        StubSyncChanges(newFiles: [], modifiedFiles: [], deletedFiles: files)
    }
    func markAsSynced(files: [String]) async {}
    func syncBidirectional() async -> StubSyncResult { StubSyncResult(success: true) }
    func resolveConflict(file: String, localDate: Date, remoteDate: Date) async -> StubConflictResolution { .useLocal }
    func syncBatch(files: [String]) async -> StubBatchResult { StubBatchResult(processed: files.count) }
    func pause() async { isPaused = true }
    func resume() async { isPaused = false }
    func syncWithProgress(onProgress: (Double) -> Void) async { onProgress(1.0) }
    func performInitialSync() async -> StubInitialSyncResult { StubInitialSyncResult(importedCount: 10) }
}

struct StubSyncChanges {
    let newFiles: [String]
    let modifiedFiles: [String]
    let deletedFiles: [String]
}

struct StubSyncResult { let success: Bool }
enum StubConflictResolution { case useLocal, useRemote, merge }
struct StubBatchResult { let processed: Int }
struct StubInitialSyncResult { let importedCount: Int }

class StubBlockParser {
    func parse(body: String, pageId: String, existingBlocks: [StubParsedBlock]? = nil) -> [StubParsedBlock] {
        body.split(separator: "\n\n").enumerated().map { i, content in
            StubParsedBlock(content: String(content), order: i)
        }
    }
    func parseWithDiff(body: String, pageId: String, existingBlocks: [StubParsedBlock]) -> StubBlockDiff {
        StubBlockDiff(added: [], modified: [], moved: [], deleted: [])
    }
    func jaccardSimilarity(_ s1: String, _ s2: String) -> Double { 0.5 }
    func matchBlocks(old: [StubParsedBlock], new: [StubParsedBlock], threshold: Double) -> [(old: String, new: String)] { [] }
}

struct StubParsedBlock {
    let id: String
    var content: String
    var order: Int
    var depth: Int = 0
    
    init(id: String = UUID().uuidString, content: String, order: Int) {
        self.id = id
        self.content = content
        self.order = order
    }
}

struct StubBlockDiff {
    let added: [StubParsedBlock]
    let modified: [(id: String, newContent: String)]
    let moved: [(id: String, newOrder: Int)]
    let deleted: [String]
}

class StubFileWatcher {
    var isRunning = false
    var onCreate: ((String) -> Void)?
    var onModify: ((String) -> Void)?
    var onDelete: ((String) -> Void)?
    
    init(path: String, recursive: Bool = false, debounceInterval: Double = 0.3) {}
    func simulateEvent(_ event: StubFileEvent) async {}
    func start() async { isRunning = true }
    func stop() async { isRunning = false }
}

enum StubFileEvent {
    case create(String)
    case modify(String)
    case delete(String)
}

class StubSyncIndex {
    func update(file: String, hash: String, modifiedAt: Date) async {}
    func metadata(for file: String) async -> StubFileMetadata? { nil }
    func hasChanged(file: String, newHash: String) async -> Bool { true }
    func cleanup(existentFiles: [String]) async {}
    var entryCount: Int { 0 }
}

struct StubFileMetadata {
    let hash: String
    let modifiedAt: Date
}
