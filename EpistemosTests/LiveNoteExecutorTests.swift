import Foundation
import SwiftData
import Testing
@testable import Epistemos

@Suite("Live Note Executor")
struct LiveNoteExecutorTests {
    @MainActor
    @Test("live note execution stages a diff without mutating note storage before approval")
    func liveNoteExecutionStagesDiffWithoutWritingBeforeApproval() async throws {
        let container = try makeModelContainer()
        let context = ModelContext(container)
        let vaultRoot = temporaryVaultRoot()
        let originalBody = sampleLiveNoteBody(lastRunAt: "null")
        let noteURL = vaultRoot
            .appendingPathComponent("Projects", isDirectory: true)
            .appendingPathComponent("release-brief.md", isDirectory: false)
        try FileManager.default.createDirectory(
            at: noteURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try originalBody.write(to: noteURL, atomically: true, encoding: .utf8)

        let page = SDPage(title: "Release Brief")
        page.filePath = noteURL.path
        page.subfolder = "Projects"
        page.saveBody(originalBody)
        page.lastSyncedBodyHash = SDPage.bodyHash(originalBody)
        page.lastSyncedAt = .now
        page.needsVaultSync = false
        context.insert(page)
        try context.save()

        let task = try #require(LiveNoteScanner().scanForLiveNotes(context: context).first)
        let llm = MockLLMClient()
        llm.generateResponse = "Revenue call moved to April 12, 2026."
        let mutator = VaultChatMutator(
            vaultResolver: { _ in vaultRoot },
            autoCommitInAgentMode: false
        )
        let executor = LiveNoteExecutor(llmService: llm, approvalMutator: mutator)

        let queued = await executor.execute(task: task, context: context, vaultRoot: vaultRoot)

        let storedBody = page.loadBody(mapped: true)
        let vaultBody = try String(contentsOf: noteURL, encoding: .utf8)

        #expect(queued)
        #expect(mutator.stagedDiff?.relativePath == "Projects/release-brief.md")
        #expect(mutator.stagedDiff?.summary == "Update live note Release Brief")
        #expect(mutator.stagedDiff?.commitMessage.contains("[VAULT:UPDATE]") == true)
        #expect(mutator.stagedDiff?.after.contains("Revenue call moved to April 12, 2026.") == true)
        #expect(storedBody == originalBody)
        #expect(vaultBody == originalBody)
        #expect(page.lastSyncedBodyHash == SDPage.bodyHash(originalBody))
        #expect(page.needsVaultSync == false)
    }

    @MainActor
    @Test("approving a staged live note diff updates note storage and commits the vault file")
    func approvingStagedLiveNoteDiffWritesManagedAndVaultBodies() async throws {
        let container = try makeModelContainer()
        let context = ModelContext(container)
        let vaultRoot = temporaryVaultRoot()
        let originalBody = sampleLiveNoteBody(lastRunAt: "null")
        let noteURL = vaultRoot
            .appendingPathComponent("Projects", isDirectory: true)
            .appendingPathComponent("release-brief.md", isDirectory: false)
        try FileManager.default.createDirectory(
            at: noteURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try originalBody.write(to: noteURL, atomically: true, encoding: .utf8)

        let page = SDPage(title: "Release Brief")
        page.filePath = noteURL.path
        page.subfolder = "Projects"
        page.saveBody(originalBody)
        page.lastSyncedBodyHash = SDPage.bodyHash(originalBody)
        page.lastSyncedAt = .now
        page.needsVaultSync = false
        context.insert(page)
        try context.save()
        let originalUpdatedAt = Date(timeIntervalSince1970: 1)
        page.updatedAt = originalUpdatedAt
        try context.save()

        let task = try #require(LiveNoteScanner().scanForLiveNotes(context: context).first)
        let llm = MockLLMClient()
        llm.generateResponse = "Revenue call moved to April 12, 2026."
        let mutator = VaultChatMutator(
            vaultResolver: { _ in vaultRoot },
            autoCommitInAgentMode: false
        )
        let executor = LiveNoteExecutor(llmService: llm, approvalMutator: mutator)

        let queued = await executor.execute(task: task, context: context, vaultRoot: vaultRoot)
        #expect(queued)

        let commitReference = try await mutator.approvePendingDiff()
        let updatedBody = page.loadBody(mapped: true)
        let vaultBody = try String(contentsOf: noteURL, encoding: .utf8)
        let lastCommit = try gitOutput(arguments: ["-C", vaultRoot.path, "log", "-1", "--pretty=%B"])
        let blocks = try fetchBlocks(pageId: page.id, from: context)

        #expect(commitReference.isEmpty == false)
        #expect(updatedBody.contains("Revenue call moved to April 12, 2026."))
        #expect(vaultBody == updatedBody)
        #expect(blocks.contains { $0.content.contains("Revenue call moved to April 12, 2026.") })
        #expect(page.wordCount == updatedBody.split(separator: " ").count)
        #expect(page.lastSyncedBodyHash == SDPage.bodyHash(updatedBody))
        #expect(page.lastSyncedAt != nil)
        #expect(page.needsVaultSync == false)
        #expect(page.updatedAt > originalUpdatedAt)
        #expect(lastCommit.contains("[VAULT:UPDATE]"))
    }

    @MainActor
    @Test("live note execution rejects vault paths that escape the attached vault root")
    func liveNoteExecutionRejectsEscapingVaultPaths() async throws {
        let container = try makeModelContainer()
        let context = ModelContext(container)
        let vaultRoot = temporaryVaultRoot()
        let body = sampleLiveNoteBody(lastRunAt: "null")

        let page = SDPage(title: "Release Brief")
        page.saveBody(body)
        context.insert(page)
        try context.save()

        let scannedTask = try #require(LiveNoteScanner().scanForLiveNotes(context: context).first)
        let escapedTask = LiveNoteTask(
            instruction: scannedTask.instruction,
            schedule: scannedTask.schedule,
            targetId: scannedTask.targetId,
            lastRunAt: scannedTask.lastRunAt,
            notePath: "../outside.md",
            noteId: page.id,
            rawBlockRange: scannedTask.rawBlockRange
        )

        let llm = MockLLMClient()
        llm.generateResponse = "Revenue call moved to April 12, 2026."
        let mutator = VaultChatMutator(
            vaultResolver: { _ in vaultRoot },
            autoCommitInAgentMode: false
        )
        let executor = LiveNoteExecutor(llmService: llm, approvalMutator: mutator)

        let queued = await executor.execute(task: escapedTask, context: context, vaultRoot: vaultRoot)

        #expect(queued == false)
        #expect(mutator.stagedDiff == nil)
        #expect(page.loadBody(mapped: true) == body)
    }

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

    private func makeModelContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(EpistemosSchema.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func fetchBlocks(pageId: String, from context: ModelContext) throws -> [SDBlock] {
        let descriptor = FetchDescriptor<SDBlock>(
            predicate: #Predicate<SDBlock> { $0.pageId == pageId },
            sortBy: [SortDescriptor(\.order)]
        )
        return try context.fetch(descriptor)
    }

    private func temporaryVaultRoot() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("epistemos-live-note-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func sampleLiveNoteBody(lastRunAt: String) -> String {
        """
        ---
        live_note: true
        ---

        ```task
        {
          "instruction": "Find launch updates",
          "schedule": { "type": "cron", "expression": "0 9 * * *" },
          "targetId": "release-watch",
          "lastRunAt": \(lastRunAt)
        }
        ```

        <!--task-target:release-watch-->
        Existing release watch notes.
        <!--/task-target:release-watch-->
        """
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
