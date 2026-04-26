import Foundation
import Testing

@testable import Epistemos

/// Wave 7.17.b source-guard for the paste-as-block intelligence
/// classifier.
@Suite("EpdocPasteClassifier (Wave 7.17.b)")
nonisolated struct EpdocPasteClassifierTests {

    @Test("Empty / whitespace-only paste classifies as plainText")
    func emptyIsPlainText() {
        #expect(EpdocPasteClassifier.classify("") == .plainText)
        #expect(EpdocPasteClassifier.classify("   \n\t  ") == .plainText)
    }

    // MARK: - YouTube

    @Test("YouTube watch URL extracts the 11-char video id")
    func youtubeWatchURL() {
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        if case let .youtubeEmbed(returned, id) = EpdocPasteClassifier.classify(url) {
            #expect(returned == url)
            #expect(id == "dQw4w9WgXcQ")
        } else {
            #expect(Bool(false), "expected .youtubeEmbed; got \(EpdocPasteClassifier.classify(url))")
        }
    }

    @Test("youtu.be short URL extracts the video id")
    func youtubeShortURL() {
        let url = "https://youtu.be/dQw4w9WgXcQ"
        if case let .youtubeEmbed(_, id) = EpdocPasteClassifier.classify(url) {
            #expect(id == "dQw4w9WgXcQ")
        } else {
            #expect(Bool(false))
        }
    }

    // MARK: - Generic URL

    @Test("Plain HTTPS URL classifies as .url (not embed)")
    func plainURL() {
        let url = "https://example.com/path"
        #expect(EpdocPasteClassifier.classify(url) == .url(url))
    }

    @Test("URL with whitespace embedded falls through to plainText")
    func urlWithWhitespaceFallsThrough() {
        // Multi-line text containing a URL is NOT a single-line URL paste
        let text = "see https://example.com for details"
        #expect(EpdocPasteClassifier.classify(text) == .plainText)
    }

    // MARK: - Code fences

    @Test("Mermaid fence classifies + extracts the diagram body")
    func mermaidFence() {
        let pasted = """
        ```mermaid
        graph TD
        A --> B
        ```
        """
        if case let .mermaidFence(diagram) = EpdocPasteClassifier.classify(pasted) {
            #expect(diagram.contains("graph TD"))
            #expect(diagram.contains("A --> B"))
        } else {
            #expect(Bool(false), "expected .mermaidFence; got \(EpdocPasteClassifier.classify(pasted))")
        }
    }

    @Test("Generic code fence extracts the language hint + body")
    func codeFence() {
        let pasted = """
        ```rust
        fn main() {
            println!("hello");
        }
        ```
        """
        if case let .codeFence(language, body) = EpdocPasteClassifier.classify(pasted) {
            #expect(language == "rust")
            #expect(body.contains("fn main()"))
        } else {
            #expect(Bool(false))
        }
    }

    @Test("Bare code fence (no language) decodes language as nil")
    func codeFenceNoLanguage() {
        let pasted = """
        ```
        plain old code
        ```
        """
        if case let .codeFence(language, _) = EpdocPasteClassifier.classify(pasted) {
            #expect(language == nil)
        } else {
            #expect(Bool(false))
        }
    }

    // MARK: - Markdown shapes

    @Test("Markdown task list with [ ] / [x] classifies correctly")
    func taskList() {
        let pasted = """
        - [ ] First task
        - [x] Second task
        - [X] Third task
        """
        #expect(EpdocPasteClassifier.classify(pasted) == .markdownTaskList)
    }

    @Test("Markdown pipe-table classifies + reports shape")
    func pipeTable() {
        let pasted = """
        | Name | Age | City |
        |------|-----|------|
        | Ana  | 30  | NYC  |
        | Bob  | 25  | LA   |
        """
        if case let .markdownTable(rows, cols) = EpdocPasteClassifier.classify(pasted) {
            #expect(cols == 3)
            #expect(rows >= 2,
                    "rowCount = total lines minus separator; got \(rows)")
        } else {
            #expect(Bool(false), "expected .markdownTable; got \(EpdocPasteClassifier.classify(pasted))")
        }
    }

    // MARK: - Detected code

    @Test("Indented multi-line code with semicolons classifies as detectedCode")
    func detectedCode() {
        let pasted = """
        function greet() {
            const name = "world";
            return name;
        }
        """
        if case let .detectedCode(language, _) = EpdocPasteClassifier.classify(pasted) {
            #expect(language == "javascript",
                    "JS marker `function ` should map to javascript; got \(language)")
        } else {
            #expect(Bool(false), "got \(EpdocPasteClassifier.classify(pasted))")
        }
    }

    @Test("Plain prose with no code markers stays plainText")
    func plainProse() {
        let pasted = "This is just three lines of\nordinary prose with no code\nshape at all."
        #expect(EpdocPasteClassifier.classify(pasted) == .plainText)
    }
}

@Suite("EpdocBlockTemplateStore (Wave 7.17.b)")
nonisolated struct EpdocBlockTemplateStoreTests {

    private static func tempVault() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("epdoc-templates-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test("Empty store on a fresh vault root reloads to empty")
    func emptyVaultReloadsEmpty() async throws {
        let vault = try Self.tempVault()
        defer { try? FileManager.default.removeItem(at: vault) }
        let store = EpdocBlockTemplateStore(vaultRoot: vault)
        try await store.reload()
        await #expect(store.templates.isEmpty)
    }

    @Test("Save then reload round-trips the template through disk")
    func saveAndReloadRoundTrip() async throws {
        let vault = try Self.tempVault()
        defer { try? FileManager.default.removeItem(at: vault) }
        let store = EpdocBlockTemplateStore(vaultRoot: vault)
        let template = EpdocBlockTemplate(
            id: "01HMV5TPL0001",
            name: "Daily standup",
            description: "Three-bullet morning template",
            icon: "list.bullet",
            nodeJSON: #"{"type":"bulletList","content":[{"type":"listItem"}]}"#
        )
        try await store.save(template)

        // Fresh store at the same path → reload picks up the saved template
        let restored = EpdocBlockTemplateStore(vaultRoot: vault)
        try await restored.reload()
        let templates = await restored.templates
        #expect(templates.count == 1)
        #expect(templates.first == template)
    }

    @Test("matching(prefix:) is case-insensitive substring match on name")
    func matchingPrefix() async throws {
        let vault = try Self.tempVault()
        defer { try? FileManager.default.removeItem(at: vault) }
        let store = EpdocBlockTemplateStore(vaultRoot: vault)
        try await store.save(.init(id: "a", name: "Daily standup", nodeJSON: "{}"))
        try await store.save(.init(id: "b", name: "Weekly review",  nodeJSON: "{}"))
        try await store.save(.init(id: "c", name: "Monthly retro",  nodeJSON: "{}"))

        let dailyMatches = await store.matching(prefix: "DAI")
        #expect(dailyMatches.count == 1)
        #expect(dailyMatches.first?.id == "a")

        let allEmpty = await store.matching(prefix: "")
        #expect(allEmpty.count == 3)
    }

    @Test("Remove deletes both the in-memory entry + the disk file")
    func removeAlsoDeletesDiskFile() async throws {
        let vault = try Self.tempVault()
        defer { try? FileManager.default.removeItem(at: vault) }
        let store = EpdocBlockTemplateStore(vaultRoot: vault)
        try await store.save(.init(id: "to-delete", name: "Throwaway", nodeJSON: "{}"))
        try await store.remove(id: "to-delete")
        await #expect(store.templates.isEmpty)

        // Disk file gone
        let fileURL = vault
            .appendingPathComponent(EpdocBlockTemplateStore.templatesSubdir, isDirectory: true)
            .appendingPathComponent("to-delete.json", isDirectory: false)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }
}
