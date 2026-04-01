import Foundation
import os

// MARK: - Harness Integration
//
// Coordinator that wires BootstrapPacketBuilder, TraceCollector, ProgressStore,
// HarnessPromptBuilder, and CompletionChecker into the agent runtime.
//
// This is the single integration point. The agent flow calls into this
// rather than touching the individual harness pieces directly.

/// Coordinates harness subsystem interaction with the agent runtime.
/// Call methods at the appropriate lifecycle points:
///   - `prepareSession()` at session start (before first turn)
///   - `recordEvent()` during execution (fire-and-forget)
///   - `completeSession()` at session end
@MainActor @Observable
final class HarnessIntegration {
    private static let log = Logger(subsystem: "com.epistemos", category: "HarnessIntegration")

    // MARK: - State

    /// The current harness version (for trace correlation).
    private(set) var harnessVersion: String = "v1.0.0"

    /// The bootstrap packet for the current session.
    private(set) var currentBootstrapPacket: BootstrapPacket?

    /// The current session's trace collector reference.
    private let traceCollector = TraceCollector.shared

    /// Session counter for the current task (increments across recycles).
    private var sessionCounter: Int = 0

    /// The active session ID.
    private(set) var activeSessionId: String?

    /// Active task type for current session.
    private(set) var activeTaskType: HarnessTaskType = .coding

    // MARK: - Session Lifecycle

    /// Prepare a new agent session. Call before the first agent turn.
    /// Returns the augmented system prompt (base + bootstrap + mode instructions).
    func prepareSession(
        sessionId: String,
        objective: String,
        workingDirectory: URL? = nil,
        baseSystemPrompt: String? = nil,
        availableTools: [String] = [],
        activeCapability: String = "cloud",
        activeVault: String? = nil
    ) -> String {
        activeSessionId = sessionId
        let taskType = HarnessTaskType.classify(objective)
        activeTaskType = taskType

        // Check for existing progress (continuation detection)
        let priorProgress = ProgressStore.loadLatestProgress()
        let taskDecomp = priorProgress.flatMap { ProgressStore.loadTaskDecomposition(sessionId: $0.sessionId) }

        // Determine session mode
        let hasProgress = priorProgress != nil
        sessionCounter = hasProgress ? (sessionCounter + 1) : 1
        let mode = HarnessPromptBuilder.determineMode(
            sessionNumber: sessionCounter,
            hasExistingProgress: hasProgress
        )

        // Load harness version
        Task {
            harnessVersion = await HarnessRegistry.shared.productionVersion()
        }

        // Build bootstrap packet
        let packet = BootstrapPacketBuilder.build(
            objective: objective,
            taskType: taskType,
            workingDirectory: workingDirectory,
            sessionNumber: sessionCounter,
            progressSummary: priorProgress?.accomplishedSummary,
            pendingTaskCount: taskDecomp?.pendingCount,
            availableTools: availableTools,
            activeCapability: activeCapability,
            activeVault: activeVault,
            harnessVersion: harnessVersion
        )
        currentBootstrapPacket = packet

        // Archive bootstrap packet
        ProgressStore.saveBootstrapPacket(packet, sessionId: sessionId)

        // Record bootstrap packet in trace
        traceCollector.record(.bootstrapPacketEvent(
            sessionId: sessionId,
            taskId: objective,
            harnessVersion: harnessVersion,
            packet: packet
        ))

        // Record session start
        traceCollector.record(TraceEvent(
            ts: ISO8601DateFormatter().string(from: Date()),
            type: .sessionStart,
            sessionId: sessionId,
            taskId: nil,
            harnessVersion: harnessVersion,
            turn: nil,
            provider: nil, model: nil, tool: nil, toolInput: nil, toolOutput: nil,
            exitCode: nil, durationMs: nil,
            content: "Session \(sessionCounter) started: \(mode.rawValue)",
            tokensUsed: nil, stopReason: nil, inputTokens: nil, outputTokens: nil,
            checkerType: nil, passed: nil, evidence: nil, errorMessage: nil,
            thermalState: nil, domain: nil, progressSnapshot: nil, bootstrapPacket: nil
        ))

        Self.log.info("Session prepared: \(sessionId) mode=\(mode.rawValue) session#=\(self.sessionCounter)")

        // Build the augmented system prompt
        return HarnessPromptBuilder.buildSystemPrompt(
            objective: objective,
            taskType: taskType,
            sessionMode: mode,
            bootstrapPacket: packet,
            priorProgress: priorProgress,
            taskDecomposition: taskDecomp,
            baseSystemPrompt: baseSystemPrompt
        )
    }

    // MARK: - Event Recording (fire-and-forget)

    /// Record a user intent (prompt submission).
    func recordUserIntent(_ prompt: String) {
        guard let sid = activeSessionId else { return }
        traceCollector.record(.userIntentEvent(
            sessionId: sid, taskId: nil,
            harnessVersion: harnessVersion, content: prompt
        ))
    }

    /// Record model output.
    func recordModelOutput(turn: Int, provider: String, model: String?, tokensUsed: Int, content: String) {
        guard let sid = activeSessionId else { return }
        traceCollector.record(.modelOutputEvent(
            sessionId: sid, taskId: nil, harnessVersion: harnessVersion,
            turn: turn, provider: provider, model: model,
            tokensUsed: tokensUsed, content: content
        ))
    }

    /// Record a tool call and its result.
    func recordToolCall(turn: Int, tool: String, input: String, output: String, exitCode: Int? = nil, durationMs: Int? = nil) {
        guard let sid = activeSessionId else { return }
        traceCollector.record(.toolCallEvent(
            sessionId: sid, taskId: nil, harnessVersion: harnessVersion,
            turn: turn, tool: tool, input: input, output: output,
            exitCode: exitCode, durationMs: durationMs
        ))
    }

    /// Record an error event.
    func recordError(_ message: String, domain: String? = nil) {
        guard let sid = activeSessionId else { return }
        traceCollector.record(.errorEvent(
            sessionId: sid, harnessVersion: harnessVersion,
            message: message, domain: domain
        ))
    }

    // MARK: - Session Completion

    /// Complete the current session. Saves progress, runs completion check, closes traces.
    func completeSession(
        stopReason: String,
        inputTokens: Int,
        outputTokens: Int,
        turns: Int,
        accomplishedSummary: String,
        completedTasks: [String] = [],
        failedTasks: [SessionProgress.TaskFailure] = [],
        nextPriority: String? = nil,
        contextNotes: [String] = [],
        changedFiles: [String] = []
    ) {
        guard let sid = activeSessionId else { return }

        // Record session end trace
        traceCollector.record(.sessionEndEvent(
            sessionId: sid, harnessVersion: harnessVersion,
            stopReason: stopReason, inputTokens: inputTokens, outputTokens: outputTokens
        ))

        // Save session progress for future continuation
        let progress = SessionProgress(
            sessionId: sid,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            harnessVersion: harnessVersion,
            accomplishedSummary: accomplishedSummary,
            completedTasks: completedTasks,
            failedTasks: failedTasks,
            nextPriority: nextPriority,
            contextNotes: contextNotes,
            gitState: nil, // Could read from bootstrap packet
            changedFiles: changedFiles,
            totalInputTokens: inputTokens,
            totalOutputTokens: outputTokens,
            totalTurns: turns
        )
        ProgressStore.saveProgress(progress)

        // Close trace file handle
        Task { await traceCollector.closeSession(sid) }

        Self.log.info("Session completed: \(sid) turns=\(turns) tokens=\(inputTokens)+\(outputTokens)")
    }

    /// Run completion verification for the current task.
    func verifyCompletion(
        objective: String,
        workingDirectory: URL
    ) async -> CompletionResult {
        guard let sid = activeSessionId else {
            return .skipped(reason: "No active session")
        }

        let checker = CompletionCheckerRegistry.checker(for: activeTaskType)
        let result = await checker.verify(
            objective: objective,
            workingDirectory: workingDirectory,
            sessionId: sid
        )

        // Record completion check in trace
        traceCollector.record(.completionCheckEvent(
            sessionId: sid, taskId: nil, harnessVersion: harnessVersion,
            checkerType: activeTaskType.rawValue,
            passed: result.isPassed,
            evidence: result.summary
        ))

        return result
    }

    // MARK: - Reset

    /// Reset harness state (for new task, not just new session).
    func resetForNewTask() {
        activeSessionId = nil
        currentBootstrapPacket = nil
        sessionCounter = 0
        activeTaskType = .coding
    }
}
