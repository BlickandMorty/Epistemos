import Foundation
import os

// MARK: - Harness Prompt Builder
//
// Meta-Harness research finding: the most impactful structural change for
// long-running agents is using DIFFERENT system prompts for:
//   1. Initializer session (session 1): set up structure, create task list, build context
//   2. Continuation session (session N>1): read progress, pick one task, verify, commit
//
// This split prevents the "start from scratch every time" anti-pattern that
// wastes 2-4 turns rediscovering what was already done.

/// Builds the system prompt for an agent session, selecting between
/// initializer and continuation modes based on session state.
enum HarnessPromptBuilder {
    private static let log = Logger(subsystem: "com.epistemos", category: "HarnessPrompt")

    /// The session mode determines which prompt template to use.
    enum SessionMode: String, Sendable {
        case initializer    // First session: set up structure
        case continuation   // Subsequent sessions: resume work
    }

    /// Determine the session mode based on available progress state.
    static func determineMode(
        sessionNumber: Int,
        hasExistingProgress: Bool
    ) -> SessionMode {
        if sessionNumber > 1 && hasExistingProgress {
            return .continuation
        }
        return .initializer
    }

    // MARK: - Prompt Assembly

    /// Build the complete system prompt for an agent session.
    /// Combines: base prompt + mode-specific instructions + bootstrap packet + progress context.
    @MainActor
    static func buildSystemPrompt(
        objective: String,
        taskType: HarnessTaskType,
        sessionMode: SessionMode,
        bootstrapPacket: BootstrapPacket,
        priorProgress: SessionProgress? = nil,
        taskDecomposition: TaskDecomposition? = nil,
        baseSystemPrompt: String? = nil
    ) -> String {
        var sections: [String] = []

        // 1. Base system prompt (from harness config or default)
        if let base = baseSystemPrompt {
            sections.append(base)
        }

        // 2. Environment bootstrap packet
        sections.append(BootstrapPacketBuilder.render(bootstrapPacket))

        // 3. Mode-specific instructions
        switch sessionMode {
        case .initializer:
            sections.append(initializerInstructions(taskType: taskType))
        case .continuation:
            sections.append(continuationInstructions(
                taskType: taskType,
                progress: priorProgress,
                tasks: taskDecomposition
            ))
        }

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Initializer Prompt

    private static func initializerInstructions(taskType: HarnessTaskType) -> String {
        """
        <session_mode>INITIALIZER SESSION</session_mode>

        This is the FIRST session for this task. Your responsibilities:

        1. UNDERSTAND the objective and environment (the bootstrap packet above gives you context — do NOT waste turns running ls or pwd)
        2. DECOMPOSE the task into concrete, verifiable steps
        3. CREATE a structured task list (each item should be independently verifiable)
        4. BEGIN executing the first task item
        5. After completing each task item, VERIFY it works before moving to the next

        Important rules:
        - Start working immediately — the environment context above eliminates the need for exploration
        - Each task item must have a clear done-condition (test passes, file exists, output matches)
        - Do NOT mark a task complete without evidence (build output, test result, file check)
        - If you cannot finish all tasks in this session, that is fine — progress will be saved for the next session
        - Prefer making one task fully correct over partially completing many tasks
        \(taskTypeSpecificInitInstructions(taskType))
        """
    }

    private static func taskTypeSpecificInitInstructions(_ type: HarnessTaskType) -> String {
        switch type {
        case .coding:
            """

            Coding-specific:
            - Run the build before and after changes to catch regressions
            - Run tests after each significant change
            - Commit working checkpoints with descriptive messages
            """
        case .research:
            """

            Research-specific:
            - Search for multiple sources before synthesizing
            - Record source URLs and key findings as you go
            - Verify claims against actual sources, not memory
            """
        case .terminal:
            """

            Terminal-specific:
            - Verify each command's output before proceeding to the next
            - Check exit codes — 0 means success, non-zero means failure
            - Capture output evidence for verification
            """
        case .noteSynthesis:
            """

            Note synthesis-specific:
            - Read all referenced source notes before writing
            - Include citations to source notes in the output
            - Save the output note to the vault
            """
        }
    }

    // MARK: - Continuation Prompt

    private static func continuationInstructions(
        taskType: HarnessTaskType,
        progress: SessionProgress?,
        tasks: TaskDecomposition?
    ) -> String {
        var parts: [String] = []

        parts.append("""
        <session_mode>CONTINUATION SESSION</session_mode>

        This is a CONTINUATION session. Prior work has been done. Your responsibilities:

        1. READ the progress summary below carefully — do NOT redo completed work
        2. IDENTIFY the next incomplete task
        3. VERIFY that previously completed work still holds (run a quick smoke test if coding)
        4. EXECUTE the next task
        5. VERIFY completion with evidence before marking done
        """)

        // Include prior progress
        if let progress {
            parts.append("<prior_progress>")
            parts.append("Accomplished: \(progress.accomplishedSummary)")
            if !progress.completedTasks.isEmpty {
                parts.append("Completed tasks: \(progress.completedTasks.joined(separator: ", "))")
            }
            if !progress.failedTasks.isEmpty {
                let failedDesc = progress.failedTasks.map { "\($0.taskId): \($0.errorSummary)" }
                parts.append("Failed tasks: \(failedDesc.joined(separator: "; "))")
            }
            if let next = progress.nextPriority {
                parts.append("Next priority: \(next)")
            }
            if !progress.contextNotes.isEmpty {
                parts.append("Context notes: \(progress.contextNotes.joined(separator: "; "))")
            }
            if !progress.changedFiles.isEmpty {
                parts.append("Changed files: \(progress.changedFiles.joined(separator: ", "))")
            }
            parts.append("</prior_progress>")
        }

        // Include task decomposition
        if let tasks {
            parts.append("<task_list>")
            for task in tasks.tasks {
                let status = task.status.rawValue.uppercased()
                let evidence = task.evidence.map { " [evidence: \($0)]" } ?? ""
                parts.append("[\(status)] \(task.id): \(task.description)\(evidence)")
            }
            parts.append("Pending: \(tasks.pendingCount) | Completed: \(tasks.completedCount)")
            parts.append("</task_list>")
        }

        parts.append("""

        Important rules:
        - Do NOT repeat work that is already marked completed
        - Pick ONE task and complete it fully with verification
        - If a previously completed task has regressed, fix it first
        - Save progress before ending the session
        """)

        return parts.joined(separator: "\n")
    }
}
