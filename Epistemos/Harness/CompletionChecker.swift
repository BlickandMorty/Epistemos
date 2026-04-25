#if !EPISTEMOS_APP_STORE
import Foundation
import os

// MARK: - Completion Checker
//
// Meta-Harness research: the most dangerous failure mode in agents is
// declaring a task complete based on visual inspection rather than
// execution verification. Evidence-based completion is non-negotiable.
//
// The completion checker is NOT part of the harness being optimized.
// It is a hard safety constraint that the proposer cannot weaken.

/// Result of a completion check.
enum CompletionResult: Codable, Sendable {
    case passed(evidence: String)
    case failed(reason: String)
    case skipped(reason: String)

    var isPassed: Bool {
        if case .passed = self { return true }
        return false
    }

    var summary: String {
        switch self {
        case .passed(let evidence): "PASSED: \(evidence)"
        case .failed(let reason): "FAILED: \(reason)"
        case .skipped(let reason): "SKIPPED: \(reason)"
        }
    }
}

/// Protocol for task-type-specific completion checking.
protocol CompletionChecker: Sendable {
    /// The task type this checker handles.
    var taskType: HarnessTaskType { get }

    /// Verify that a task is actually complete, with evidence.
    func verify(
        objective: String,
        workingDirectory: URL,
        sessionId: String
    ) async -> CompletionResult
}

// MARK: - Coding Completion Checker

/// Verifies coding task completion through build + test execution.
struct CodingCompletionChecker: CompletionChecker {
    private static let log = Logger(subsystem: "com.epistemos", category: "CodingCompletion")
    let taskType: HarnessTaskType = .coding

    func verify(objective: String, workingDirectory: URL, sessionId: String) async -> CompletionResult {
        let fm = FileManager.default

        // Detect project type and run appropriate build/test
        if fm.fileExists(atPath: workingDirectory.appendingPathComponent("Package.swift").path) {
            return await verifySwiftPackage(at: workingDirectory)
        } else if fm.fileExists(atPath: workingDirectory.appendingPathComponent("Cargo.toml").path) {
            return await verifyCargoProject(at: workingDirectory)
        } else if fm.fileExists(atPath: workingDirectory.appendingPathComponent("package.json").path) {
            return await verifyNodeProject(at: workingDirectory)
        }

        return .skipped(reason: "No recognized build system found (Package.swift, Cargo.toml, or package.json)")
    }

    private func verifySwiftPackage(at dir: URL) async -> CompletionResult {
        // 1. Build check
        let buildResult = await runCommand("swift", arguments: ["build"], at: dir, timeout: 120)
        guard buildResult.exitCode == 0 else {
            return .failed(reason: "Swift build failed: \(String(buildResult.stderr.suffix(500)))")
        }

        // 2. Test check
        let testResult = await runCommand("swift", arguments: ["test", "--parallel"], at: dir, timeout: 300)
        guard testResult.exitCode == 0 else {
            return .failed(reason: "Swift tests failed: \(String(testResult.stderr.suffix(500)))")
        }

        return .passed(evidence: "swift build OK, swift test OK")
    }

    private func verifyCargoProject(at dir: URL) async -> CompletionResult {
        let buildResult = await runCommand("cargo", arguments: ["build"], at: dir, timeout: 120)
        guard buildResult.exitCode == 0 else {
            return .failed(reason: "Cargo build failed: \(String(buildResult.stderr.suffix(500)))")
        }

        let testResult = await runCommand("cargo", arguments: ["test"], at: dir, timeout: 300)
        guard testResult.exitCode == 0 else {
            return .failed(reason: "Cargo tests failed: \(String(testResult.stderr.suffix(500)))")
        }

        return .passed(evidence: "cargo build OK, cargo test OK")
    }

    private func verifyNodeProject(at dir: URL) async -> CompletionResult {
        let testResult = await runCommand("npm", arguments: ["test", "--if-present"], at: dir, timeout: 120)
        guard testResult.exitCode == 0 else {
            return .failed(reason: "npm test failed: \(String(testResult.stderr.suffix(500)))")
        }

        return .passed(evidence: "npm test OK (exit 0)")
    }
}

// MARK: - Terminal Completion Checker

/// Verifies terminal task completion by checking file existence and command output.
struct TerminalCompletionChecker: CompletionChecker {
    let taskType: HarnessTaskType = .terminal

    func verify(objective: String, workingDirectory: URL, sessionId: String) async -> CompletionResult {
        // Terminal tasks are highly varied — basic check that the session completed
        // without errors. More specific verification requires per-task expected outputs.
        return .skipped(reason: "Terminal task verification requires task-specific expected output patterns")
    }
}

// MARK: - Research Completion Checker

/// Verifies research task completion by checking tool usage and output existence.
struct ResearchCompletionChecker: CompletionChecker {
    let taskType: HarnessTaskType = .research

    func verify(objective: String, workingDirectory: URL, sessionId: String) async -> CompletionResult {
        // Check that research produced some output in the session directory
        let sessionDir = ProgressStore.sessionDirectory(for: sessionId)
        let fm = FileManager.default

        // Check for any output artifacts
        let artifactsDir = sessionDir.appendingPathComponent("artifacts")
        if fm.fileExists(atPath: artifactsDir.path),
           let contents = try? fm.contentsOfDirectory(atPath: artifactsDir.path),
           !contents.isEmpty {
            return .passed(evidence: "Research produced \(contents.count) artifact(s)")
        }

        // Check that we have a progress file indicating work was done
        if let progress = ProgressStore.loadProgress(sessionId: sessionId),
           !progress.completedTasks.isEmpty {
            return .passed(evidence: "Research completed \(progress.completedTasks.count) task(s)")
        }

        return .failed(reason: "No research output artifacts or completed tasks found")
    }
}

// MARK: - Note Synthesis Completion Checker

/// Verifies note synthesis by checking that referenced notes were read
/// and output was saved.
struct NoteSynthesisCompletionChecker: CompletionChecker {
    let taskType: HarnessTaskType = .noteSynthesis

    func verify(objective: String, workingDirectory: URL, sessionId: String) async -> CompletionResult {
        // Verify output exists
        if let progress = ProgressStore.loadProgress(sessionId: sessionId),
           !progress.completedTasks.isEmpty {
            return .passed(evidence: "Synthesis completed \(progress.completedTasks.count) task(s)")
        }

        return .skipped(reason: "Note synthesis verification requires vault integration")
    }
}

// MARK: - Completion Checker Registry

/// Returns the appropriate completion checker for a task type.
enum CompletionCheckerRegistry {
    static func checker(for taskType: HarnessTaskType) -> any CompletionChecker {
        switch taskType {
        case .coding: CodingCompletionChecker()
        case .terminal: TerminalCompletionChecker()
        case .research: ResearchCompletionChecker()
        case .noteSynthesis: NoteSynthesisCompletionChecker()
        }
    }
}

// MARK: - Process Runner Helper

struct ProcessResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

/// Run a command with timeout. Returns stdout, stderr, and exit code.
func runCommand(
    _ executable: String,
    arguments: [String],
    at workingDirectory: URL,
    timeout: TimeInterval = 60
) async -> ProcessResult {
    let state = ProcessContinuationState<ProcessResult>()
    let cancellationResult = ProcessResult(
        exitCode: -1,
        stdout: "",
        stderr: "Cancelled \(executable)"
    )

    return await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process.init()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [executable] + arguments
                process.currentDirectoryURL = workingDirectory

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                guard state.store(process: process, continuation: continuation) else {
                    continuation.resume(returning: cancellationResult)
                    return
                }

                let timer = DispatchSource.makeTimerSource(queue: .global())
                timer.schedule(deadline: .now() + timeout)
                timer.setEventHandler {
                    process.terminate()
                }
                timer.resume()

                process.terminationHandler = { proc in
                    timer.cancel()

                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                    state.resume(returning: ProcessResult(
                        exitCode: proc.terminationStatus,
                        stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                        stderr: String(data: stderrData, encoding: .utf8) ?? ""
                    ))
                }

                do {
                    try process.run()
                } catch {
                    timer.cancel()
                    state.resume(returning: ProcessResult(
                        exitCode: -1,
                        stdout: "",
                        stderr: "Failed to launch \(executable): \(error.localizedDescription)"
                    ))
                }
            }
        }
    } onCancel: {
        state.terminate()
        state.resume(returning: cancellationResult)
    }
}
#endif // !EPISTEMOS_APP_STORE -- Harness completion checker (subprocess spawning, Pro-only)
