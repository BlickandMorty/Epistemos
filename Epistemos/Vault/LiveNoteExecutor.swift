import Foundation
import os
import SwiftData

// MARK: - LiveNoteExecutor
// Executes due live note tasks by spawning constrained agent sessions.
// Based on Rowboat inline_tasks.ts execution pattern.
//
// The executor:
// 1. Reads the live note content
// 2. Spawns an agent session with the task instruction
// 3. Replaces content between <!--task-target:id--> markers
// 4. Updates lastRunAt in the task JSON block
// 5. Commits via VaultGit

private let log = Logger(subsystem: "com.epistemos", category: "LiveNotes")

@MainActor
final class LiveNoteExecutor {

    private let llmService: (any LLMClientProtocol)?
    private let approvalMutator: VaultChatMutator?

    init(
        llmService: (any LLMClientProtocol)? = nil,
        approvalMutator: VaultChatMutator? = nil
    ) {
        self.llmService = llmService
        self.approvalMutator = approvalMutator
    }

    var hasPendingApproval: Bool {
        approvalMutator?.stagedDiff != nil
    }

    /// Execute a single live note task.
    /// Returns true if the note change was successfully queued for approval.
    func execute(task: LiveNoteTask, context: ModelContext, vaultRoot: URL) async -> Bool {
        log.info("LiveNoteExecutor: executing task '\(task.targetId)' for \(task.notePath)")

        guard let llm = llmService else {
            log.warning("LiveNoteExecutor: no LLM service available, skipping task")
            return false
        }
        guard let approvalMutator else {
            log.warning("LiveNoteExecutor: no approval mutator available, skipping task")
            return false
        }
        guard approvalMutator.stagedDiff == nil else {
            log.info("LiveNoteExecutor: pending approval exists, skipping '\(task.targetId)'")
            return false
        }

        // 1. Run the agent with constrained instruction
        let prompt = """
        You are a background research assistant updating a live note.
        Your task: \(task.instruction)

        Rules:
        - Be concise: 2-3 sentences per finding.
        - Include dates when relevant.
        - Maximum 3 new items.
        - If nothing new found, respond with exactly: "No new updates."
        - Do NOT repeat information that may already be in the note.
        """

        let agentResult: String
        do {
            agentResult = try await llm.generate(prompt: prompt, maxTokens: 1000)
        } catch {
            log.error("LiveNoteExecutor: LLM error — \(error.localizedDescription, privacy: .public)")
            return false
        }

        // 2. Load the note and replace target region
        guard let page = fetchPage(id: task.noteId, context: context) else {
            log.error("LiveNoteExecutor: page unavailable: \(task.noteId, privacy: .public)")
            return false
        }

        let originalBody = page.loadBody(mapped: true)
        let originalFilePath = page.filePath
        let originalWordCount = page.wordCount
        let originalUpdatedAt = page.updatedAt
        let originalLastSyncedBodyHash = page.lastSyncedBodyHash
        let originalLastSyncedAt = page.lastSyncedAt
        let originalNeedsVaultSync = page.needsVaultSync
        guard let fileURL = resolvedVaultNoteURL(notePath: task.notePath, vaultRoot: vaultRoot) else {
            log.error("LiveNoteExecutor: rejected escaped note path '\(task.notePath, privacy: .public)'")
            return false
        }

        let trimmed = agentResult.trimmingCharacters(in: .whitespacesAndNewlines)
        let proposedBody: String
        do {
            proposedBody = try updatedBody(
                for: task,
                originalBody: originalBody,
                agentResult: trimmed
            )
        } catch {
            log.error("LiveNoteExecutor: failed to prepare update — \(error.localizedDescription, privacy: .public)")
            return false
        }

        do {
            let title = page.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? task.targetId
                : page.title
            _ = try await approvalMutator.stageFileMutation(
                targetVault: .personal,
                repositoryRootURL: vaultRoot,
                fileURL: fileURL,
                before: originalBody,
                after: proposedBody,
                summary: "Update live note \(title)",
                rationale: "Background live-note polling produced a candidate vault edit and queued it for human approval before any write.",
                source: "live-note"
            ) { diff in
                page.saveBody(diff.after)
                BlockMirror.sync(pageId: page.id, body: diff.after, modelContext: context)
                page.filePath = diff.fileURL.path
                page.wordCount = diff.after.split(separator: " ").count
                page.updatedAt = .now
                page.lastSyncedBodyHash = SDPage.bodyHash(diff.after)
                page.lastSyncedAt = .now
                page.needsVaultSync = false
                do {
                    try context.save()
                } catch {
                    page.saveBody(originalBody)
                    BlockMirror.sync(pageId: page.id, body: originalBody, modelContext: context)
                    page.filePath = originalFilePath
                    page.wordCount = originalWordCount
                    page.updatedAt = originalUpdatedAt
                    page.lastSyncedBodyHash = originalLastSyncedBodyHash
                    page.lastSyncedAt = originalLastSyncedAt
                    page.needsVaultSync = originalNeedsVaultSync
                    throw error
                }
                NoteFileStorage.notifyBodyChanged(pageId: page.id)
                AppBootstrap.shared?.eventBus.emit(.vaultPageChanged(pageId: page.id))
            }
            log.info("LiveNoteExecutor: staged approval for '\(task.targetId)' in \(task.notePath)")
            return true
        } catch {
            log.error("LiveNoteExecutor: failed to stage diff — \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func fetchPage(id: String, context: ModelContext) -> SDPage? {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == id }
        )
        do {
            return try context.fetch(descriptor).first
        } catch {
            log.error(
                "LiveNoteExecutor: failed to fetch page \(id, privacy: .public) — \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func updatedBody(
        for task: LiveNoteTask,
        originalBody: String,
        agentResult: String
    ) throws -> String {
        let date = Date()
        let bodyWithUpdatedTimestamp = updateLastRunAtInBody(
            body: originalBody,
            task: task,
            updatedAt: date
        )

        if agentResult.lowercased().contains("no new updates") {
            return bodyWithUpdatedTimestamp
        }

        let startMarker = "<!--task-target:\(task.targetId)-->"
        let endMarker = "<!--/task-target:\(task.targetId)-->"

        guard let startRange = bodyWithUpdatedTimestamp.range(of: startMarker),
              let endRange = bodyWithUpdatedTimestamp.range(of: endMarker) else {
            throw LiveNoteExecutorError.missingTargetMarkers(task.targetId)
        }

        var updatedBody = bodyWithUpdatedTimestamp
        let dateStr = ISO8601DateFormatter().string(from: date)
        let newContent = "\n*Updated \(dateStr)*\n\n\(agentResult)\n"
        let replaceRange = startRange.upperBound..<endRange.lowerBound
        updatedBody.replaceSubrange(replaceRange, with: newContent)
        return updatedBody
    }

    private func updateLastRunAtInBody(
        body: String,
        task: LiveNoteTask,
        updatedAt: Date
    ) -> String {
        let pattern = "```task\\s*\\n([\\s\\S]*?)\\n```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return body
        }

        let nsRange = NSRange(body.startIndex..<body.endIndex, in: body)
        for match in regex.matches(in: body, range: nsRange) {
            guard match.numberOfRanges >= 2,
                  let jsonRange = Range(match.range(at: 1), in: body) else {
                continue
            }

            let taskBlock = String(body[jsonRange])
            guard taskBlock.contains("\"targetId\""),
                  taskBlock.contains("\"\(task.targetId)\"") else {
                continue
            }

            let updatedTaskBlock = replacingLastRunAt(
                in: taskBlock,
                with: ISO8601DateFormatter().string(from: updatedAt)
            )
            guard updatedTaskBlock != taskBlock else {
                return body
            }

            var updatedBody = body
            updatedBody.replaceSubrange(jsonRange, with: updatedTaskBlock)
            return updatedBody
        }

        return body
    }

    private func replacingLastRunAt(
        in taskBlock: String,
        with dateString: String
    ) -> String {
        let replacement = "\"lastRunAt\": \"\(dateString)\""
        let patterns = [
            "\"lastRunAt\"\\s*:\\s*null",
            "\"lastRunAt\"\\s*:\\s*\"[^\"]*\"",
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            let nsRange = NSRange(taskBlock.startIndex..<taskBlock.endIndex, in: taskBlock)
            guard let match = regex.firstMatch(in: taskBlock, range: nsRange) else {
                continue
            }
            let mutable = NSMutableString(string: taskBlock)
            mutable.replaceCharacters(in: match.range, with: replacement)
            return String(mutable)
        }

        return taskBlock
    }

    private func resolvedVaultNoteURL(notePath: String, vaultRoot: URL) -> URL? {
        let rootURL = vaultRoot.standardizedFileURL
        let candidateURL = rootURL
            .appendingPathComponent(notePath, isDirectory: false)
            .standardizedFileURL
        let rootPath = rootURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

        guard candidateURL.path.hasPrefix(prefix) else {
            return nil
        }

        return candidateURL
    }
}

private enum LiveNoteExecutorError: LocalizedError {
    case missingTargetMarkers(String)

    var errorDescription: String? {
        switch self {
        case .missingTargetMarkers(let targetID):
            return "Live note target markers are missing for \(targetID)."
        }
    }
}

// MARK: - LiveNoteSchedulerService
// Background timer that polls for due live notes every 15 seconds.
// Uses DispatchSourceTimer (NOT NSBackgroundActivityScheduler) because
// live notes should run during active use, not just on idle.

@MainActor
final class LiveNoteSchedulerService {

    /// Fast cadence when live notes are actively firing.
    private static let activeInterval: DispatchTimeInterval = .seconds(15)
    /// Slow cadence when no live notes have been observed in this session.
    /// Keeps idle CPU/energy low on vaults that don't use live notes (the
    /// common case — most users have zero live tasks, so the scanner was
    /// hammering the page graph every 15s for no reason).
    private static let idleInterval: DispatchTimeInterval = .seconds(120)

    private var timer: DispatchSourceTimer?
    private let scanner = LiveNoteScanner()
    private var executor: LiveNoteExecutor?
    private weak var modelContainer: ModelContainer?
    private var vaultRoot: URL?
    private var activeVaultRootPath: String?
    private var isRunning = false
    private var currentInterval: DispatchTimeInterval = LiveNoteSchedulerService.idleInterval

    func start(
        llmService: (any LLMClientProtocol)?,
        modelContainer: ModelContainer,
        vaultRoot: URL,
        approvalMutator: VaultChatMutator
    ) {
        let standardizedRootPath = vaultRoot.standardizedFileURL.path
        if timer != nil, activeVaultRootPath == standardizedRootPath {
            self.executor = LiveNoteExecutor(
                llmService: llmService,
                approvalMutator: approvalMutator
            )
            self.modelContainer = modelContainer
            self.vaultRoot = vaultRoot
            return
        }

        stop()
        self.executor = LiveNoteExecutor(
            llmService: llmService,
            approvalMutator: approvalMutator
        )
        self.modelContainer = modelContainer
        self.vaultRoot = vaultRoot
        self.activeVaultRootPath = standardizedRootPath

        scheduleTimer(interval: Self.idleInterval)
        log.info("LiveNoteSchedulerService: started (adaptive poll — idle 120s, active 15s)")
    }

    private func scheduleTimer(interval: DispatchTimeInterval) {
        timer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                await self?.tick()
            }
        }
        timer.resume()
        self.timer = timer
        self.currentInterval = interval
    }

    func stop() {
        timer?.cancel()
        timer = nil
        activeVaultRootPath = nil
        log.info("LiveNoteSchedulerService: stopped")
    }

    /// Manual trigger — execute all due tasks immediately.
    func runNow() async {
        await tick()
    }

    private func tick() async {
        guard !isRunning else { return }  // prevent overlapping runs
        guard let container = modelContainer, let vaultRoot, let executor else { return }
        guard !executor.hasPendingApproval else { return }

        isRunning = true
        defer { isRunning = false }

        let context = ModelContext(container)
        let tasks = await scanner.scanForLiveNotes(modelContainer: container)
        let dueTasks = tasks.filter { scanner.isDue($0) }

        // Adaptive cadence: if the vault has no live notes at all, fall back
        // to the slow idle interval. Only switch to fast cadence when live
        // tasks actually exist.
        if tasks.isEmpty {
            if currentInterval != Self.idleInterval {
                scheduleTimer(interval: Self.idleInterval)
            }
        } else if currentInterval != Self.activeInterval {
            scheduleTimer(interval: Self.activeInterval)
        }

        guard !dueTasks.isEmpty else { return }

        log.info("LiveNoteSchedulerService: \(dueTasks.count) tasks due")

        for task in dueTasks {
            let success = await executor.execute(task: task, context: context, vaultRoot: vaultRoot)
            if success {
                log.info("LiveNoteSchedulerService: completed '\(task.targetId)'")
            }
            if executor.hasPendingApproval {
                break
            }
        }
    }
}
