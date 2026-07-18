import Foundation
import Testing
@testable import Epistemos

@Suite("Vault Verified File Writer")
struct VaultVerifiedFileWriterTests {
    @Test("approved vault mutation file writes verify readback before reporting success")
    func approvedVaultMutationFileWritesVerifyReadback() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-verified-writer-\(UUID().uuidString).md")

        try VaultVerifiedFileWriter.writeUTF8("Verified body", to: fileURL)

        let readback = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(readback == "Verified body")
    }

    @Test("approved vault mutation file writes reject mismatched readback")
    func approvedVaultMutationFileWritesRejectMismatchedReadback() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-verified-writer-mismatch-\(UUID().uuidString).md")

        do {
            try VaultVerifiedFileWriter.writeUTF8(
                "Expected body",
                to: fileURL,
                readBack: { _ in "Different body" }
            )
            Issue.record("Expected verified writer to reject mismatched readback")
        } catch let error as VaultChatMutatorError {
            #expect(error.errorDescription?.contains("did not match") == true)
        }
    }

    @Test("approved vault mutation file writes reject linked targets")
    func approvedVaultMutationFileWritesRejectLinkedTargets() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-verified-writer-linked-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let outside = root.appendingPathComponent("outside.md", isDirectory: false)
        let symlink = root.appendingPathComponent("linked.md", isDirectory: false)
        let hardlink = root.appendingPathComponent("hardlinked.md", isDirectory: false)
        try "outside original".write(to: outside, atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: outside)

        do {
            try VaultVerifiedFileWriter.writeUTF8("new body", to: symlink)
            Issue.record("Expected verified writer to reject symlinked targets")
        } catch let error as VaultChatMutatorError {
            #expect(error.errorDescription?.contains("regular single-link file") == true)
        }
        #expect(try String(contentsOf: outside, encoding: .utf8) == "outside original")

        guard (try? FileManager.default.linkItem(at: outside, to: hardlink)) != nil else {
            return
        }
        do {
            try VaultVerifiedFileWriter.writeUTF8("new body", to: hardlink)
            Issue.record("Expected verified writer to reject hardlinked targets")
        } catch let error as VaultChatMutatorError {
            #expect(error.errorDescription?.contains("regular single-link file") == true)
        }
        #expect(try String(contentsOf: outside, encoding: .utf8) == "outside original")
    }
}
