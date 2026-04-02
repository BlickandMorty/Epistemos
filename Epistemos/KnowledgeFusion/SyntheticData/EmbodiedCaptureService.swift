import Foundation
import AppKit

// MARK: - Embodied Capture Service

/// Captures pre/post action AX tree snapshots and screenshots for embodied training data.
/// This is the live data pipeline that turns Omega agent executions into training artifacts
/// with the full schema: accessibility_tree, screenshot, instruction, reasoning_chain, action,
/// result_screenshot, result_accessibility_tree.
///
/// Usage:
///   let capture = EmbodiedCaptureService()
///   let pre = await capture.captureSnapshot(pid: pid)
///   // ... execute action ...
///   try? await Task.sleep(for: .milliseconds(150))
///   let post = await capture.captureSnapshot(pid: pid)
///   let trajectory = capture.buildTrajectoryStep(instruction: "...", reasoning: "...", action: action, pre: pre, post: post)
@MainActor
final class EmbodiedCaptureService {

    // MARK: - Output paths

    private let outputDirectory: URL
    private let screenshotsDirectory: URL

    init() {
        let support = FoundationSafety.userApplicationSupportDirectory()
        outputDirectory = support.appendingPathComponent("Epistemos/embodied-data")
        screenshotsDirectory = outputDirectory.appendingPathComponent("screenshots")
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - AX Tree Capture

    /// Capture a full AX tree snapshot for the given PID using omega-ax.
    /// Returns the JSON string of the AXTreeSnapshot.
    func captureAXTree(pid: Int64) -> AXTreeSnapshotData {
        let json = walkAxTreeJson(pid: pid)
        let timestamp = Date()

        // Parse to extract interactive element count for quality scoring
        var interactiveCount = 0
        var isSparse = true
        if let data = json.data(using: .utf8),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            isSparse = (parsed["is_sparse"] as? Bool) ?? true
            if let elements = parsed["elements"] as? [[String: Any]] {
                interactiveCount = elements.filter { ($0["is_interactive"] as? Bool) == true }.count
            }
        }

        return AXTreeSnapshotData(
            json: json,
            timestamp: timestamp,
            interactiveCount: interactiveCount,
            isSparse: isSparse
        )
    }

    // MARK: - Screenshot Capture

    /// Capture a screenshot of the given window/app via screencapture CLI.
    /// Returns the file path of the saved PNG.
    func captureScreenshot(label: String) async -> String? {
        let filename = "\(label)_\(Int(Date().timeIntervalSince1970 * 1000)).png"
        let path = screenshotsDirectory.appendingPathComponent(filename)

        let succeeded = await captureScreenshotOffMain(at: path)
        return succeeded ? path.path : nil
    }

    // MARK: - Full Snapshot (AX + Screenshot)

    /// Capture both AX tree and screenshot atomically.
    func captureSnapshot(pid: Int64, label: String) async -> EmbodiedSnapshot {
        let axTree = captureAXTree(pid: pid)
        let screenshotPath = await captureScreenshot(label: label)

        return EmbodiedSnapshot(
            axTree: axTree,
            screenshotPath: screenshotPath,
            timestamp: Date()
        )
    }

    // MARK: - Trajectory Step Builder

    /// Build a single embodied trajectory step from pre/post snapshots.
    func buildTrajectoryStep(
        instruction: String,
        reasoning: String,
        action: EmbodiedAction,
        preSnapshot: EmbodiedSnapshot,
        postSnapshot: EmbodiedSnapshot
    ) -> EmbodiedTrajectoryStep {
        // Compute AX diff between pre and post
        let axDiff = computeAXDiff(pre: preSnapshot.axTree.json, post: postSnapshot.axTree.json)

        return EmbodiedTrajectoryStep(
            instruction: instruction,
            accessibilityTree: preSnapshot.axTree.json,
            screenshot: preSnapshot.screenshotPath,
            reasoningChain: reasoning,
            action: action,
            resultAccessibilityTree: postSnapshot.axTree.json,
            resultScreenshot: postSnapshot.screenshotPath,
            axDiff: axDiff,
            preTimestamp: preSnapshot.timestamp,
            postTimestamp: postSnapshot.timestamp,
            quality: preSnapshot.axTree.isSparse ? 0.5 : 1.0
        )
    }

    // MARK: - Multi-Step Trajectory Builder

    /// Build a complete multi-step trajectory from a sequence of steps.
    func buildTrajectory(
        taskDescription: String,
        steps: [EmbodiedTrajectoryStep],
        taskType: String = "general"
    ) -> EmbodiedTrajectory {
        let overallSuccess = steps.allSatisfy { $0.quality >= 0.5 }
        return EmbodiedTrajectory(
            taskDescription: taskDescription,
            steps: steps,
            taskType: taskType,
            success: overallSuccess,
            timestamp: Date()
        )
    }

    // MARK: - Persistence

    /// Append a trajectory to the embodied training JSONL file.
    func persistTrajectory(_ trajectory: EmbodiedTrajectory) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(trajectory)
        guard var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"

        let outputPath = outputDirectory.appendingPathComponent("embodied_trajectories.jsonl")

        if FileManager.default.fileExists(atPath: outputPath.path) {
            guard let lineData = line.data(using: .utf8) else {
                throw CocoaError(.fileWriteInapplicableStringEncoding)
            }
            let handle = try FileHandle(forWritingTo: outputPath)
            handle.seekToEndOfFile()
            handle.write(lineData)
            handle.closeFile()
        } else {
            try line.write(to: outputPath, atomically: true, encoding: .utf8)
        }
    }

    /// Persist a batch of trajectories.
    func persistBatch(_ trajectories: [EmbodiedTrajectory]) throws {
        for trajectory in trajectories {
            try persistTrajectory(trajectory)
        }
    }

    // MARK: - AX Diff

    /// Compute a structural diff between pre and post AX trees.
    /// Returns a JSON string describing added/removed/changed elements.
    private func computeAXDiff(pre: String, post: String) -> String {
        guard let preData = pre.data(using: .utf8),
              let postData = post.data(using: .utf8),
              let preTree = try? JSONSerialization.jsonObject(with: preData) as? [String: Any],
              let postTree = try? JSONSerialization.jsonObject(with: postData) as? [String: Any],
              let preElements = preTree["elements"] as? [[String: Any]],
              let postElements = postTree["elements"] as? [[String: Any]] else {
            return "{}"
        }

        // Build role+title signature sets for diff
        let preSignatures = Set(preElements.map { elementSignature($0) })
        let postSignatures = Set(postElements.map { elementSignature($0) })

        let added = postSignatures.subtracting(preSignatures)
        let removed = preSignatures.subtracting(postSignatures)

        let diff: [String: Any] = [
            "added_count": added.count,
            "removed_count": removed.count,
            "added": Array(added.prefix(20)),
            "removed": Array(removed.prefix(20)),
            "pre_total": preElements.count,
            "post_total": postElements.count,
        ]

        guard let diffData = try? JSONSerialization.data(withJSONObject: diff),
              let diffString = String(data: diffData, encoding: .utf8) else {
            return "{}"
        }
        return diffString
    }

    private func elementSignature(_ element: [String: Any]) -> String {
        let role = element["role"] as? String ?? ""
        let title = element["title"] as? String ?? ""
        let desc = element["description"] as? String ?? ""
        return "\(role)|\(title)|\(desc)"
    }

    private nonisolated func captureScreenshotOffMain(at path: URL) async -> Bool {
        await Task.detached(priority: .utility) {
            let process = Process.init()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-x", "-C", path.path]

            do {
                try process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            } catch {
                return false
            }
        }.value
    }
}

// MARK: - Hook into Omega execution pipeline

extension EmbodiedCaptureService {

    /// Wrap an Omega agent step execution with pre/post AX capture.
    /// Call this instead of raw agent.execute() to generate embodied training data.
    func executeWithCapture(
        agent: any OmegaAgent,
        step: AgentStep,
        pid: Int64,
        taskDescription: String
    ) async throws -> (AgentStepResult, EmbodiedTrajectoryStep?) {
        // Pre-action snapshot
        let preSnapshot = await captureSnapshot(pid: pid, label: "pre_\(step.toolName)")

        // Execute the actual action
        let result = try await agent.execute(step: step)

        // Wait 150ms for UI to settle (per master training guide)
        try? await Task.sleep(for: .milliseconds(150))

        // Post-action snapshot
        let postSnapshot = await captureSnapshot(pid: pid, label: "post_\(step.toolName)")

        guard result.success else {
            return (result, nil)
        }

        let action = EmbodiedAction(
            toolName: step.toolName,
            argumentsJson: step.argumentsJson,
            agentName: step.assignedAgent
        )

        let trajectoryStep = buildTrajectoryStep(
            instruction: taskDescription,
            reasoning: "<think>Selected \(step.assignedAgent) agent. Using \(step.toolName) to \(step.description). Confidence: \(result.confidence).</think>",
            action: action,
            preSnapshot: preSnapshot,
            postSnapshot: postSnapshot
        )

        return (result, trajectoryStep)
    }
}

// MARK: - Data Types

struct AXTreeSnapshotData: Codable, Sendable {
    let json: String
    let timestamp: Date
    let interactiveCount: Int
    let isSparse: Bool
}

struct EmbodiedSnapshot: Sendable {
    let axTree: AXTreeSnapshotData
    let screenshotPath: String?
    let timestamp: Date
}

struct EmbodiedAction: Codable, Sendable {
    let toolName: String
    let argumentsJson: String
    let agentName: String
}

struct EmbodiedTrajectoryStep: Codable, Sendable {
    let instruction: String
    let accessibilityTree: String
    let screenshot: String?
    let reasoningChain: String
    let action: EmbodiedAction
    let resultAccessibilityTree: String
    let resultScreenshot: String?
    let axDiff: String
    let preTimestamp: Date
    let postTimestamp: Date
    let quality: Double
}

struct EmbodiedTrajectory: Codable, Sendable {
    let taskDescription: String
    let steps: [EmbodiedTrajectoryStep]
    let taskType: String
    let success: Bool
    let timestamp: Date
}
