import Foundation
import SwiftData
import Testing
@testable import Epistemos

@Suite("Model Vault Browser")
struct ModelVaultBrowserTests {

    private func encodeMetadata(_ metadata: ModelVaultMetadata) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(metadata)
    }

    @Test("browser hides internal dotfiles unless requested")
    func browserHidesInternalDotfilesUnlessRequested() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-vault-browser-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "# Instructions".write(
            to: root.appendingPathComponent("instructions.md"),
            atomically: true,
            encoding: .utf8
        )
        try "{}".write(
            to: root.appendingPathComponent("meta.json"),
            atomically: true,
            encoding: .utf8
        )
        try "secret".write(
            to: root.appendingPathComponent(".claude-system.md"),
            atomically: true,
            encoding: .utf8
        )

        let visibleEntries = ModelVaultBrowserStore.loadEntries(rootURL: root, includeHidden: false)
        #expect(visibleEntries.map(\.relativePath) == ["instructions.md", "meta.json"])

        let allEntries = ModelVaultBrowserStore.loadEntries(rootURL: root, includeHidden: true)
        #expect(allEntries.map(\.relativePath).contains(".claude-system.md"))
    }

    @Test("browser keeps curated vault documents at the top of the file list")
    func browserKeepsCuratedVaultDocumentsAtTopOfFileList() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-vault-browser-order-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let files = [
            "notes.md",
            "knowledge_profile.md",
            "concept_index.md",
            "active_context.md",
            "instructions.md",
            "meta.json",
        ]

        for file in files {
            try file.write(
                to: root.appendingPathComponent(file),
                atomically: true,
                encoding: .utf8
            )
        }

        let entries = ModelVaultBrowserStore.loadEntries(rootURL: root)
        #expect(Array(entries.map(\.relativePath).prefix(5)) == [
            "instructions.md",
            "knowledge_profile.md",
            "concept_index.md",
            "active_context.md",
            "meta.json",
        ])
    }

    @Test("browser recognizes text files that can be edited inline")
    func browserRecognizesEditableTextFiles() {
        #expect(ModelVaultBrowserStore.isEditableTextFile(URL(fileURLWithPath: "/tmp/instructions.md")))
        #expect(ModelVaultBrowserStore.isEditableTextFile(URL(fileURLWithPath: "/tmp/meta.json")))
        #expect(ModelVaultBrowserStore.isEditableTextFile(URL(fileURLWithPath: "/tmp/internal.toml")))
        #expect(!ModelVaultBrowserStore.isEditableTextFile(URL(fileURLWithPath: "/tmp/archive.bin")))
    }

    @Test("known models keep their curated display names even when vault metadata is stale")
    func knownModelsKeepCuratedDisplayNamesWhenMetadataIsStale() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-vault-browser-metadata-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let metadata = ModelVaultMetadata(
            modelID: "gemini-3-flash-preview",
            displayName: "Gemini 3 Flash Preview",
            compiledAt: Date(timeIntervalSince1970: 0),
            noteCount: 1,
            conceptCount: 1,
            activeNoteCount: 1,
            tokenEstimate: 256
        )
        let metadataData = try encodeMetadata(metadata)
        try metadataData.write(to: root.appendingPathComponent("meta.json"))

        let entry = ModelVaultEntry(url: root)
        #expect(entry.id == "gemini-3-flash-preview")
        #expect(entry.displayName == "Gemini 3 Flash")
    }

    @Test("cloud vault entries accept both vendor and legacy authored model ids")
    func cloudVaultEntriesAcceptVendorAndLegacyAuthoredModelIDs() {
        let entry = ModelVaultEntry(
            url: URL(fileURLWithPath: "/tmp/gpt-5.4", isDirectory: true)
        )

        #expect(entry.id == "gpt-5.4")
        #expect(entry.acceptedAuthoredModelIDs.contains("gpt-5.4"))
        #expect(entry.acceptedAuthoredModelIDs.contains("openai:gpt-5.4"))
    }

    @Test("cloud metadata raw ids canonicalize to the curated vendor model id")
    func cloudMetadataRawIDsCanonicalizeToVendorModelID() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-vault-browser-cloud-raw-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let metadata = ModelVaultMetadata(
            modelID: "openai:gpt-5.4",
            displayName: "GPT-5.4",
            compiledAt: Date(timeIntervalSince1970: 0),
            noteCount: 2,
            conceptCount: 5,
            activeNoteCount: 1,
            tokenEstimate: 128
        )
        let metadataData = try encodeMetadata(metadata)
        try metadataData.write(to: root.appendingPathComponent("meta.json"))

        let entry = ModelVaultEntry(url: root)
        #expect(entry.id == "gpt-5.4")
        #expect(entry.acceptedAuthoredModelIDs.contains("openai:gpt-5.4"))
    }

    @Test("browser can create and delete model vault text files")
    func browserCanCreateAndDeleteModelVaultTextFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-vault-browser-create-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let created = try #require(
            ModelVaultBrowserStore.createTextFile(
                named: "notes",
                rootURL: root,
                relativeDirectory: "contexts/swift"
            )
        )
        #expect(created.relativePath == "contexts/swift/notes.md")
        #expect(FileManager.default.fileExists(atPath: created.url.path))

        let loaded = try ModelVaultBrowserStore.readText(at: created.url)
        #expect(loaded == "")

        #expect(ModelVaultBrowserStore.deleteItem(at: created.url))
        #expect(!FileManager.default.fileExists(atPath: created.url.path))
    }

    @Test("gpt_5_4_sidebar_shows_full_history")
    @MainActor
    func gpt_5_4_sidebar_shows_full_history() throws {
        let schema = Schema([SDChat.self, SDMessage.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let chat = SDChat(title: "GPT-5.4 Contributions")
        context.insert(chat)

        let currentMessage = SDMessage(role: "assistant", content: "Current vendor id")
        currentMessage.chat = chat
        currentMessage.authoredByProviderID = "openai"
        currentMessage.authoredByModelID = "gpt-5.4"
        currentMessage.createdAt = Date(timeIntervalSince1970: 2)
        context.insert(currentMessage)

        let legacyMessage = SDMessage(role: "assistant", content: "Legacy raw id")
        legacyMessage.chat = chat
        legacyMessage.authoredByProviderID = "openai"
        legacyMessage.authoredByModelID = "openai:gpt-5.4"
        legacyMessage.createdAt = Date(timeIntervalSince1970: 1)
        context.insert(legacyMessage)

        let unrelatedMessage = SDMessage(role: "assistant", content: "Other model")
        unrelatedMessage.chat = chat
        unrelatedMessage.authoredByProviderID = "anthropic"
        unrelatedMessage.authoredByModelID = "claude-opus-4-7"
        unrelatedMessage.createdAt = Date(timeIntervalSince1970: 3)
        context.insert(unrelatedMessage)

        try context.save()

        let contributions = ModelInvolvementContent.loadContributions(
            modelIDs: ModelVaultEntry.acceptedModelIDs(for: "gpt-5.4"),
            in: context
        )

        #expect(contributions.map(\.id) == [currentMessage.id, legacyMessage.id])
    }
}
