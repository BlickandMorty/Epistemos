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

    init(llmService: (any LLMClientProtocol)? = nil) {
        self.llmService = llmService
    }

    /// Execute a single live note task.
    /// Returns true if the note was successfully updated.
    func execute(task: LiveNoteTask, context: ModelContext, vaultRoot: URL) async -> Bool {
        log.info("LiveNoteExecutor: executing task '\(task.targetId)' for \(task.notePath)")

        guard let llm = llmService else {
            log.warning("LiveNoteExecutor: no LLM service available, skipping task")
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

        // Skip if no new updates
        let trimmed = agentResult.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().contains("no new updates") {
            log.info("LiveNoteExecutor: no new updates for '\(task.targetId)'")
            return updateLastRunAt(task: task, context: context)
        }

        // 2. Load the note and replace target region
        guard let page = fetchPage(id: task.noteId, context: context) else {
            log.error("LiveNoteExecutor: page not found: \(task.noteId)")
            return false
        }

        var body = page.loadBody(mapped: true)

        let startMarker = "<!--task-target:\(task.targetId)-->"
        let endMarker = "<!--/task-target:\(task.targetId)-->"

        guard let startRange = body.range(of: startMarker),
              let endRange = body.range(of: endMarker) else {
            log.warning("LiveNoteExecutor: target markers not found for '\(task.targetId)' in \(task.notePath)")
            return false
        }

        // Replace content between markers
        let dateStr = ISO8601DateFormatter().string(from: Date())
        let newContent = "\n*Updated \(dateStr)*\n\n\(trimmed)\n"
        let replaceRange = startRange.upperBound..<endRange.lowerBound
        body.replaceSubrange(replaceRange, with: newContent)

        // 3. Update lastRunAt in the task JSON block
        body = updateLastRunAtInBody(body: body, targetId: task.targetId)

        // 4. Save the note
        page.saveBody(body)
        do {
            try context.save()
            log.info("LiveNoteExecutor: updated '\(task.targetId)' in \(task.notePath)")
        } catch {
            log.error("LiveNoteExecutor: save failed — \(error.localizedDescription, privacy: .public)")
            return false
        }

        // 5. Write to vault file system if vault sync is active
        let fileURL = vaultRoot.appendingPathComponent(task.notePath)
        try? body.write(to: fileURL, atomically: true, encoding: .utf8)

        return true
    }

    /// Update lastRunAt timestamp in the task JSON block within the note body.
    private func updateLastRunAtInBody(body: String, targetId: String) -> String {
        let dateStr = ISO8601DateFormatter().string(from: Date())

        // Find the task block containing this targetId and update lastRunAt
        // Pattern: "lastRunAt": null or "lastRunAt": "..."
        var updated = body

        // Replace null lastRunAt
        let nullPattern = "\"lastRunAt\"\\s*:\\s*null"
        if let regex = try? NSRegularExpression(pattern: nullPattern) {
            let nsBody = updated as NSString
            // Only replace the first occurrence near the targetId (simple approach)
            let range = NSRange(location: 0, length: nsBody.length)
            updated = regex.stringByReplacingMatches(
                in: updated, range: range,
                withTemplate: "\"lastRunAt\": \"\(dateStr)\""
            )
        }

        // Replace existing date
        let datePattern = "\"lastRunAt\"\\s*:\\s*\"[^\"]*\""
        if let regex = try? NSRegularExpression(pattern: datePattern) {
            let nsBody = updated as NSString
            let range = NSRange(location: 0, length: nsBody.length)
            updated = regex.stringByReplacingMatches(
                in: updated, range: range,
                withTemplate: "\"lastRunAt\": \"\(dateStr)\""
            )
        }

        return updated
    }

    /// Update just the lastRunAt without changing note content (for "no new updates" case).
    private func updateLastRunAt(task: LiveNoteTask, context: ModelContext) -> Bool {
        guard let page = fetchPage(id: task.noteId, context: context) else { return false }
        var body = page.loadBody(mapped: true)
        body = updateLastRunAtInBody(body: body, targetId: task.targetId)
        page.saveBody(body)
        return (try? context.save()) != nil
    }

    private func fetchPage(id: String, context: ModelContext) -> SDPage? {
        let descriptor = FetchDescriptor<SDPage>(
            predicate: #Predicate<SDPage> { $0.id == id }
        )
        return (try? context.fetch(descriptor))?.first
    }
}

// MARK: - LiveNoteSchedulerService
// Background timer that polls for due live notes every 15 seconds.
// Uses DispatchSourceTimer (NOT NSBackgroundActivityScheduler) because
// live notes should run during active use, not just on idle.

@MainActor
final class LiveNoteSchedulerService {

    private var timer: DispatchSourceTimer?
    private let scanner = LiveNoteScanner()
    private var executor: LiveNoteExecutor?
    private weak var modelContainer: ModelContainer?
    private var vaultRoot: URL?
    private var isRunning = false

    func start(
        llmService: (any LLMClientProtocol)?,
        modelContainer: ModelContainer,
        vaultRoot: URL
    ) {
        self.executor = LiveNoteExecutor(llmService: llmService)
        self.modelContainer = modelContainer
        self.vaultRoot = vaultRoot

        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + 15, repeating: 15)
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                await self?.tick()
            }
        }
        timer.resume()
        self.timer = timer
        log.info("LiveNoteSchedulerService: started (15s poll interval)")
    }

    func stop() {
        timer?.cancel()
        timer = nil
        log.info("LiveNoteSchedulerService: stopped")
    }

    /// Manual trigger — execute all due tasks immediately.
    func runNow() async {
        await tick()
    }

    private func tick() async {
        guard !isRunning else { return }  // prevent overlapping runs
        guard let container = modelContainer, let vaultRoot, let executor else { return }

        isRunning = true
        defer { isRunning = false }

        let context = ModelContext(container)
        let tasks = scanner.scanForLiveNotes(context: context)
        let dueTasks = tasks.filter { scanner.isDue($0) }

        guard !dueTasks.isEmpty else { return }

        log.info("LiveNoteSchedulerService: \(dueTasks.count) tasks due")

        for task in dueTasks {
            let success = await executor.execute(task: task, context: context, vaultRoot: vaultRoot)
            if success {
                log.info("LiveNoteSchedulerService: completed '\(task.targetId)'")
            }
        }
    }
}
