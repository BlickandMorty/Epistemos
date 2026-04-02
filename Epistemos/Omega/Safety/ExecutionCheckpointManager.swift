import Foundation
import os

private let checkpointLog = Logger(subsystem: "com.epistemos", category: "ExecutionCheckpoint")

// MARK: - Execution Checkpoint Manager
// Atomically persists agent step execution state to disk so complex
// research tasks can resume after crashes, memory-pressure evictions,
// or app quits. Uses atomic temp-file + rename for crash safety.
//
// Checkpoint file: ~/Library/Application Support/Epistemos/checkpoints/<planID>.json
//
// On app relaunch, the orchestrator checks for incomplete checkpoints
// and offers to resume them.

@MainActor
final class ExecutionCheckpointManager {

    // MARK: - Types

    enum StepStatus: String, Codable, Sendable {
        case pending
        case running
        case completed
        case failed
        case skipped
    }

    struct StepCheckpoint: Codable, Sendable {
        let stepId: String
        let description: String
        let toolName: String
        var status: StepStatus
        var outputJson: String?
        var error: String?
        var startedAt: Date?
        var completedAt: Date?
    }

    struct PlanCheckpoint: Codable, Sendable {
        let planId: String
        let objective: String
        let createdAt: Date
        var lastUpdated: Date
        var steps: [StepCheckpoint]
        var currentStepIndex: Int
        var totalTokensUsed: Int
        var isComplete: Bool
    }

    // MARK: - State

    private let checkpointDir: URL
    private var activeCheckpoint: PlanCheckpoint?

    init() {
        let appSupport = FoundationSafety.userApplicationSupportDirectory()
        checkpointDir = appSupport
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("checkpoints", isDirectory: true)
        ensureCheckpointDirectory()
    }

    // MARK: - Lifecycle

    /// Start a new checkpoint for a plan.
    func begin(planId: String, objective: String, steps: [(id: String, description: String, toolName: String)]) {
        let checkpoint = PlanCheckpoint(
            planId: planId,
            objective: objective,
            createdAt: Date(),
            lastUpdated: Date(),
            steps: steps.map { step in
                StepCheckpoint(
                    stepId: step.id,
                    description: step.description,
                    toolName: step.toolName,
                    status: .pending
                )
            },
            currentStepIndex: 0,
            totalTokensUsed: 0,
            isComplete: false
        )
        activeCheckpoint = checkpoint
        persist(checkpoint)
    }

    /// Mark a step as running.
    func markRunning(stepId: String) {
        guard var cp = activeCheckpoint,
              let idx = cp.steps.firstIndex(where: { $0.stepId == stepId }) else { return }
        cp.steps[idx].status = .running
        cp.steps[idx].startedAt = Date()
        cp.currentStepIndex = idx
        cp.lastUpdated = Date()
        activeCheckpoint = cp
        persist(cp)
    }

    /// Mark a step as completed with output.
    func markCompleted(stepId: String, outputJson: String, tokensUsed: Int) {
        guard var cp = activeCheckpoint,
              let idx = cp.steps.firstIndex(where: { $0.stepId == stepId }) else { return }
        cp.steps[idx].status = .completed
        cp.steps[idx].outputJson = outputJson
        cp.steps[idx].completedAt = Date()
        cp.totalTokensUsed += tokensUsed
        cp.lastUpdated = Date()

        // Check if all steps are done
        let allDone = cp.steps.allSatisfy { $0.status == .completed || $0.status == .skipped }
        cp.isComplete = allDone

        activeCheckpoint = cp
        persist(cp)
    }

    /// Mark a step as failed.
    func markFailed(stepId: String, error: String) {
        guard var cp = activeCheckpoint,
              let idx = cp.steps.firstIndex(where: { $0.stepId == stepId }) else { return }
        cp.steps[idx].status = .failed
        cp.steps[idx].error = error
        cp.steps[idx].completedAt = Date()
        cp.lastUpdated = Date()
        activeCheckpoint = cp
        persist(cp)
    }

    /// Finalize and remove checkpoint file on successful completion.
    func finalize() {
        guard let cp = activeCheckpoint else { return }
        let fileURL = checkpointDir.appendingPathComponent("\(cp.planId).json")
        removeCheckpointFile(at: fileURL, label: "finalized checkpoint")
        activeCheckpoint = nil
        checkpointLog.info("Checkpoint finalized and removed: \(cp.planId)")
    }

    // MARK: - Recovery

    /// Find all incomplete checkpoints from prior sessions.
    func findIncompleteCheckpoints() -> [PlanCheckpoint] {
        let files = checkpointFiles()

        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> PlanCheckpoint? in
                guard let cp = loadCheckpoint(at: url, removeMalformed: true) else { return nil }
                return cp.isComplete ? nil : cp
            }
            .sorted { $0.lastUpdated > $1.lastUpdated }
    }

    /// Resume from a checkpoint — returns steps that still need execution.
    func resume(planId: String) -> PlanCheckpoint? {
        let fileURL = checkpointDir.appendingPathComponent("\(planId).json")
        guard let cp = loadCheckpoint(at: fileURL, removeMalformed: true) else { return nil }
        activeCheckpoint = cp
        checkpointLog.info("Resuming checkpoint: \(planId), \(cp.steps.filter { $0.status == .pending || $0.status == .failed }.count) steps remaining")
        return cp
    }

    /// Clean up checkpoints older than the given interval.
    func pruneOld(olderThan interval: TimeInterval = 7 * 24 * 3600) {
        let files = checkpointFiles()
        let cutoff = Date().addingTimeInterval(-interval)
        for url in files {
            guard let modified = checkpointModificationDate(for: url),
                  modified < cutoff else { continue }
            removeCheckpointFile(at: url, label: "expired checkpoint")
            checkpointLog.debug("Pruned old checkpoint: \(url.lastPathComponent)")
        }
    }

    // MARK: - Atomic Persistence

    private func persist(_ checkpoint: PlanCheckpoint) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data: Data
        do {
            data = try encoder.encode(checkpoint)
        } catch {
            checkpointLog.error(
                "ExecutionCheckpoint: failed to encode checkpoint \(checkpoint.planId, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return
        }

        let fileURL = checkpointDir.appendingPathComponent("\(checkpoint.planId).json")
        let tmpURL = fileURL.appendingPathExtension("tmp")

        do {
            try data.write(to: tmpURL, options: .atomic)
            // Atomic rename
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.moveItem(at: tmpURL, to: fileURL)
        } catch {
            checkpointLog.error("Failed to persist checkpoint: \(error.localizedDescription)")
            removeCheckpointFile(at: tmpURL, label: "checkpoint temp file")
        }
    }

    private func ensureCheckpointDirectory() {
        do {
            try FileManager.default.createDirectory(
                at: checkpointDir,
                withIntermediateDirectories: true
            )
        } catch {
            checkpointLog.error(
                "ExecutionCheckpoint: failed to create checkpoint directory: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func checkpointFiles() -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(
                at: checkpointDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )
        } catch {
            checkpointLog.error(
                "ExecutionCheckpoint: failed to list checkpoint directory: \(error.localizedDescription, privacy: .public)"
            )
            return []
        }
    }

    private func loadCheckpoint(at fileURL: URL, removeMalformed: Bool) -> PlanCheckpoint? {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(PlanCheckpoint.self, from: data)
        } catch {
            checkpointLog.error(
                "ExecutionCheckpoint: failed to decode checkpoint \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            if removeMalformed {
                removeCheckpointFile(at: fileURL, label: "malformed checkpoint")
            }
            return nil
        }
    }

    private func checkpointModificationDate(for url: URL) -> Date? {
        do {
            return try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        } catch {
            checkpointLog.error(
                "ExecutionCheckpoint: failed to inspect checkpoint modification date for \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }

    private func removeCheckpointFile(at url: URL, label: String) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            checkpointLog.error(
                "ExecutionCheckpoint: failed to remove \(label, privacy: .public): \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
