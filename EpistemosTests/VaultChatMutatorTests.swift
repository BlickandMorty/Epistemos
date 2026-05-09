import Foundation
import Testing
@testable import Epistemos

@Suite("Vault Chat Mutator")
struct VaultChatMutatorTests {
    @Test("mutate stages an add diff without writing before approval")
    @MainActor
    func mutateStagesAddDiffWithoutWritingBeforeApproval() async throws {
        let vaultRoot = temporaryRoot()
        let mutator = VaultChatMutator(
            vaultResolver: { _ in vaultRoot },
            autoCommitInAgentMode: false
        )

        let diff = try await mutator.mutate(
            message: "Remember that the launch checklist is frozen for release week.",
            targetVault: .personal
        )

        let targetFile = vaultRoot.appendingPathComponent("MEMORY.md", isDirectory: false)
        #expect(diff.operation == .add)
        #expect(mutator.stagedDiff == diff)
        #expect(FileManager.default.fileExists(atPath: targetFile.path) == false)
        #expect(diff.unifiedDiff.contains("launch checklist"))
    }

    @Test("approving a staged diff writes the file and records a git commit")
    @MainActor
    func approvingStagedDiffWritesFileAndRecordsGitCommit() async throws {
        let vaultRoot = temporaryRoot()
        let mutator = VaultChatMutator(
            vaultResolver: { _ in vaultRoot },
            autoCommitInAgentMode: false
        )

        _ = try await mutator.mutate(
            message: "Remember that evidence scoring favors primary sources.",
            targetVault: .personal
        )

        let commitReference = try await mutator.approvePendingDiff()
        let targetFile = vaultRoot.appendingPathComponent("MEMORY.md", isDirectory: false)
        let body = try String(contentsOf: targetFile, encoding: .utf8)
        let lastCommit = try gitOutput(arguments: ["-C", vaultRoot.path, "log", "-1", "--pretty=%B"])

        #expect(commitReference.isEmpty == false)
        #expect(body.contains("evidence scoring favors primary sources"))
        #expect(lastCommit.contains("[MEMORY:ADD]"))
    }

    @Test("git subprocess uses direct binary, minimal env, no hooks, and honest MAS reference")
    func gitSubprocessIsHardened() throws {
        let source = try loadMirroredSourceTextFile("Epistemos/Vault/VaultChatMutator.swift")

        #expect(source.contains("URL(fileURLWithPath: \"/usr/bin/git\")"))
        #expect(!source.contains("URL(fileURLWithPath: \"/usr/bin/env\")"))
        #expect(source.contains("\"--no-verify\""))
        #expect(source.contains("process.environment = Self.gitEnvironment()"))
        #expect(!source.contains("ProcessInfo.processInfo.environment"))
        #expect(source.contains("\"GIT_TERMINAL_PROMPT\": \"0\""))
        #expect(source.contains("\"GIT_CONFIG_GLOBAL\": \"/dev/null\""))
        #expect(source.contains("mas-file-only-"))
        #expect(!source.contains("placeholder reference"))
    }

    private func temporaryRoot() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-vault-chat-mutator-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: nil)
        return root
    }

    private func gitOutput(arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let text = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw TestGitError.commandFailed(text)
        }
        return text
    }
}

private enum TestGitError: Error {
    case commandFailed(String)
}
