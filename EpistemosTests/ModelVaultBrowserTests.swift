import Foundation
import Testing
@testable import Epistemos

@Suite("Model Vault Browser")
struct ModelVaultBrowserTests {

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
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: root.appendingPathComponent("meta.json"))

        let entry = ModelVaultEntry(url: root)
        #expect(entry.id == "gemini-3-flash-preview")
        #expect(entry.displayName == "Gemini 3 Flash")
    }
}
