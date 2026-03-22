import Foundation
import Testing
@testable import Epistemos

@Suite("Vault Import File Copier")
struct VaultImportFileCopierTests {
    @Test("copy imports selected files into the vault directory")
    func copyImportsFiles() async throws {
        let sourceDirectory = try temporaryDirectory(named: "vault-import-source")
        let destinationDirectory = try temporaryDirectory(named: "vault-import-destination")
        defer {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: destinationDirectory)
        }

        let first = sourceDirectory.appendingPathComponent("first.md")
        let second = sourceDirectory.appendingPathComponent("second.md")
        try "# First".write(to: first, atomically: true, encoding: .utf8)
        try "# Second".write(to: second, atomically: true, encoding: .utf8)

        let count = await VaultImportFileCopier.copy(urls: [first, second], to: destinationDirectory)

        #expect(count == 2)
        #expect(FileManager.default.fileExists(atPath: destinationDirectory.appendingPathComponent("first.md").path))
        #expect(FileManager.default.fileExists(atPath: destinationDirectory.appendingPathComponent("second.md").path))
    }

    @Test("copy skips conflicting filenames and continues")
    func copySkipsConflicts() async throws {
        let sourceDirectory = try temporaryDirectory(named: "vault-import-conflict-source")
        let destinationDirectory = try temporaryDirectory(named: "vault-import-conflict-destination")
        defer {
            try? FileManager.default.removeItem(at: sourceDirectory)
            try? FileManager.default.removeItem(at: destinationDirectory)
        }

        let duplicate = sourceDirectory.appendingPathComponent("duplicate.md")
        let fresh = sourceDirectory.appendingPathComponent("fresh.md")
        try "# Duplicate".write(to: duplicate, atomically: true, encoding: .utf8)
        try "# Fresh".write(to: fresh, atomically: true, encoding: .utf8)
        try "# Existing".write(
            to: destinationDirectory.appendingPathComponent("duplicate.md"),
            atomically: true,
            encoding: .utf8
        )

        let count = await VaultImportFileCopier.copy(urls: [duplicate, fresh], to: destinationDirectory)

        #expect(count == 1)
        #expect(FileManager.default.fileExists(atPath: destinationDirectory.appendingPathComponent("fresh.md").path))
        let existing = try String(
            contentsOf: destinationDirectory.appendingPathComponent("duplicate.md"),
            encoding: .utf8
        )
        #expect(existing == "# Existing")
    }

    private func temporaryDirectory(named prefix: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "\(prefix)-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
