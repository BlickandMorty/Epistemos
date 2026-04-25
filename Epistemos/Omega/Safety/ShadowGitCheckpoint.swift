#if !EPISTEMOS_APP_STORE
import Foundation
import CryptoKit
import os

/// Creates shadow git checkpoints of vault files before agent mutations.
/// Uses GIT_DIR/GIT_WORK_TREE separation so .git doesn't leak into the user's vault.
/// Checkpoints live in ~/Library/Application Support/Epistemos/checkpoints/{hash}/.
actor ShadowGitCheckpoint {

    private static let logger = Logger(subsystem: "com.epistemos", category: "ShadowGitCheckpoint")

    /// Patterns to exclude from git tracking.
    private static let excludePatterns = [
        ".git/", "node_modules/", ".env", "__pycache__/",
        ".DS_Store", "*.gguf", "*.safetensors", "*.mlx",
    ]

    private let checkpointsRoot: URL

    init() {
        let appSupport = FoundationSafety.userApplicationSupportDirectory()
        checkpointsRoot = appSupport.appendingPathComponent("Epistemos/checkpoints", isDirectory: true)
    }

    // MARK: - Public API

    /// Create a snapshot of a file before the agent mutates it.
    /// - Parameters:
    ///   - filePath: Absolute path to the file about to be modified
    ///   - message: Commit message describing the operation
    func checkpoint(filePath: String, message: String) async {
        let vaultDir = (filePath as NSString).deletingLastPathComponent
        let gitDir = shadowGitDir(for: vaultDir)

        do {
            try ensureShadowRepo(gitDir: gitDir, workTree: vaultDir)
            try await gitAdd(gitDir: gitDir, workTree: vaultDir, file: filePath)
            try await gitCommit(gitDir: gitDir, workTree: vaultDir, message: "[CHECKPOINT] \(message)")
        } catch {
            Self.logger.warning("Shadow git checkpoint failed: \(error.localizedDescription)")
        }
    }

    /// Rollback a file to its state before the last agent mutation.
    /// - Parameter filePath: Absolute path to the file to restore
    /// - Returns: true if rollback succeeded
    func rollback(filePath: String) async -> Bool {
        let vaultDir = (filePath as NSString).deletingLastPathComponent
        let gitDir = shadowGitDir(for: vaultDir)
        let relativePath = (filePath as NSString).lastPathComponent

        do {
            try await runGit(
                args: ["checkout", "HEAD~1", "--", relativePath],
                gitDir: gitDir,
                workTree: vaultDir
            )
            return true
        } catch {
            Self.logger.warning("Shadow git rollback failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Internal

    private func shadowGitDir(for vaultDir: String) -> URL {
        let hash = SHA256.hash(data: Data(vaultDir.utf8))
        let short = hash.prefix(8).map { String(format: "%02x", $0) }.joined()
        return checkpointsRoot.appendingPathComponent(short, isDirectory: true)
    }

    private func ensureShadowRepo(gitDir: URL, workTree: String) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: gitDir.path) {
            try fm.createDirectory(at: gitDir, withIntermediateDirectories: true)
        }

        let headFile = gitDir.appendingPathComponent("HEAD")
        if !fm.fileExists(atPath: headFile.path) {
            // Initialize bare-ish repo
            let process = Process.init()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["init", "--bare", gitDir.path]
            process.environment = ["GIT_DIR": gitDir.path, "GIT_WORK_TREE": workTree]
            try process.run()
            process.waitUntilExit()

            // Write exclude patterns
            let infoDir = gitDir.appendingPathComponent("info")
            try fm.createDirectory(at: infoDir, withIntermediateDirectories: true)
            let excludeFile = infoDir.appendingPathComponent("exclude")
            let excludeContent = Self.excludePatterns.joined(separator: "\n") + "\n"
            try excludeContent.write(to: excludeFile, atomically: true, encoding: .utf8)
        }
    }

    private func gitAdd(gitDir: URL, workTree: String, file: String) async throws {
        let relativePath = file.hasPrefix(workTree)
            ? String(file.dropFirst(workTree.count + 1))
            : (file as NSString).lastPathComponent
        try await runGit(args: ["add", relativePath], gitDir: gitDir, workTree: workTree)
    }

    private func gitCommit(gitDir: URL, workTree: String, message: String) async throws {
        try await runGit(
            args: ["commit", "--allow-empty", "-m", message],
            gitDir: gitDir,
            workTree: workTree
        )
    }

    private func runGit(args: [String], gitDir: URL, workTree: String) async throws {
        let timeoutSeconds = 10.0
        let state = ThrowingProcessContinuationState<Void>()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let process = Process.init()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = args
                process.environment = [
                    "GIT_DIR": gitDir.path,
                    "GIT_WORK_TREE": workTree,
                    "HOME": NSHomeDirectory(),
                    "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
                ]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice

                guard state.store(process: process, continuation: continuation) else {
                    continuation.resume(throwing: CancellationError())
                    return
                }

                let timeoutTask = Task.detached(priority: .utility) {
                    do {
                        try await Task.sleep(for: .seconds(timeoutSeconds))
                    } catch is CancellationError {
                        return
                    } catch {
                        return
                    }
                    state.terminate()
                    state.resume(throwing: TimeoutError(seconds: timeoutSeconds))
                }

                process.terminationHandler = { proc in
                    timeoutTask.cancel()
                    if proc.terminationStatus == 0 {
                        state.resume(returning: ())
                    } else {
                        state.resume(throwing: NSError(
                            domain: "ShadowGit",
                            code: Int(proc.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: "git \(args.first ?? "") failed with status \(proc.terminationStatus)"]
                        ))
                    }
                }

                do {
                    try process.run()
                } catch {
                    timeoutTask.cancel()
                    state.resume(throwing: error)
                }
            }
        } onCancel: {
            state.terminate()
            state.resume(throwing: CancellationError())
        }
    }
}
#endif // !EPISTEMOS_APP_STORE -- ShadowGitCheckpoint spawns /usr/bin/git, not sandbox-safe
