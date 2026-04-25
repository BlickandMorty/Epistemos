#if !EPISTEMOS_APP_STORE
import Foundation
import os

// MARK: - Evaluation Sandbox (Phase 8)
//
// Native macOS isolation primitives for Harness Lab evaluation runs.
// Developer-only — never invoked on the production hot path.
//
// Components:
//   - SanitizedEnvironment: safe baseline env (no API keys, no credentials)
//   - VolatileProjectRoot: temp directory lifecycle for per-task isolation
//   - EvalSandboxProfile: sandbox-exec SBPL profile builder
//   - sandboxedRunCommand(): subprocess runner with env scrub + volatile root + sandbox

// ═══════════════════════════════════════════════════════════════════
// MARK: - Sanitized Environment
// ═══════════════════════════════════════════════════════════════════

/// Builds a safe baseline environment for sandboxed subprocess execution.
/// Strips all sensitive keys (API keys, tokens, credentials) and preserves only
/// the minimal set required for build tools and shell operation.
enum SanitizedEnvironment {

    /// Keys that are always preserved from the parent environment.
    static let allowedKeys: Set<String> = [
        "PATH", "HOME", "USER", "LOGNAME",
        "LANG", "LC_ALL", "LC_CTYPE", "LC_MESSAGES",
        "TERM", "SHELL", "TMPDIR",
        "DEVELOPER_DIR", "SDKROOT",
        "CPATH", "LIBRARY_PATH",
        "MACOSX_DEPLOYMENT_TARGET",
        "SWIFT_DETERMINISTIC_HASHING",
        "CARGO_HOME", "RUSTUP_HOME",
        "NVM_DIR", "NODE_PATH",
    ]

    /// Prefix patterns for keys that are preserved (e.g., XDG_*).
    static let allowedPrefixes: [String] = [
        "XDG_",
        "HOMEBREW_",
        "XCTEST_",
    ]

    /// Known sensitive key patterns that must NEVER pass through,
    /// even if they match an allowed prefix.
    static let deniedPatterns: [String] = [
        "API_KEY", "API_SECRET", "SECRET_KEY", "ACCESS_TOKEN",
        "AUTH_TOKEN", "BEARER_TOKEN", "PRIVATE_KEY",
        "ANTHROPIC_", "OPENAI_", "GOOGLE_AI_", "PERPLEXITY_",
        "TAVILY_", "EXA_", "FIRECRAWL_", "SERPER_",
        "AWS_SECRET", "AWS_SESSION", "GITHUB_TOKEN",
        "HF_TOKEN", "HUGGING_FACE",
    ]

    /// Build a sanitized environment dictionary from the current process environment.
    /// Returns only safe keys — everything else is dropped.
    static func build(extras: [String: String] = [:]) -> [String: String] {
        let source = ProcessInfo.processInfo.environment
        var result: [String: String] = [:]

        for (key, value) in source {
            guard isAllowed(key) else { continue }
            guard !isDenied(key) else { continue }
            result[key] = value
        }

        // Override TMPDIR to point at our volatile root if provided
        for (k, v) in extras {
            result[k] = v
        }

        return result
    }

    private static func isAllowed(_ key: String) -> Bool {
        if allowedKeys.contains(key) { return true }
        for prefix in allowedPrefixes where key.hasPrefix(prefix) { return true }
        return false
    }

    private static func isDenied(_ key: String) -> Bool {
        let upper = key.uppercased()
        for pattern in deniedPatterns where upper.contains(pattern) { return true }
        return false
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Volatile Project Root
// ═══════════════════════════════════════════════════════════════════

/// Manages a temporary, disposable project directory for isolated task evaluation.
/// Creates a fresh temp dir per task, optionally copies initial state into it,
/// and cleans up after evaluation completes.
struct VolatileProjectRoot: Sendable {
    let rootURL: URL
    nonisolated private static let log = Logger(subsystem: "com.epistemos", category: "VolatileRoot")

    /// Create a new volatile root under /tmp.
    /// If `initialStatePath` is provided and exists, its contents are shallow-copied.
    nonisolated static func create(initialStatePath: URL? = nil) throws -> VolatileProjectRoot {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("epistemos_eval_\(UUID().uuidString)")

        let fm = FileManager.default
        try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)

        // Shallow-copy initial state if provided
        if let source = initialStatePath, fm.fileExists(atPath: source.path) {
            let items = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
            for item in items {
                let dest = rootURL.appendingPathComponent(item.lastPathComponent)
                try fm.copyItem(at: item, to: dest)
            }
            log.info("Copied \(items.count) items from \(source.path) into volatile root")
        }

        log.info("Created volatile root: \(rootURL.path)")
        return VolatileProjectRoot(rootURL: rootURL)
    }

    /// Remove the volatile root and all its contents.
    nonisolated func cleanup() {
        do {
            try FileManager.default.removeItem(at: rootURL)
            Self.log.info("Cleaned up volatile root: \(rootURL.path)")
        } catch {
            Self.log.warning("Failed to clean up volatile root \(rootURL.path): \(error.localizedDescription)")
        }
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Sandbox Profile (sandbox-exec SBPL)
// ═══════════════════════════════════════════════════════════════════

/// Builds a Scheme-based sandbox profile string for `sandbox-exec -p`.
/// Restricts file access to the volatile root + system dirs, denies network by default.
enum EvalSandboxProfile {

    /// Generate an SBPL profile string for evaluation subprocess isolation.
    ///
    /// - Parameters:
    ///   - volatileRoot: Path to the volatile project root (read+write allowed)
    ///   - allowNetwork: If true, allows outbound network access (default: false)
    /// - Returns: SBPL profile string suitable for `sandbox-exec -p`
    nonisolated static func build(volatileRoot: String, allowNetwork: Bool = false) -> String {
        let home = NSHomeDirectory()

        // SBPL (Sandbox Profile Language) — Apple's Scheme-based sandbox config.
        // IMPORTANT: No leading whitespace — SBPL parser is whitespace-sensitive.
        var lines = [
            "(version 1)",
            "(deny default)",
            "",
            "(allow process*)",
            "(allow signal)",
            "",
            ";; Read access: system dirs + toolchains",
            "(allow file-read*)",
            "",
            ";; Write access: volatile root + tmp + DerivedData + caches only",
            "(allow file-write* (subpath \"\(volatileRoot)\"))",
            "(allow file-write* (subpath \"/tmp\"))",
            "(allow file-write* (subpath \"/private/tmp\"))",
            "(allow file-write* (subpath \"\(home)/Library/Developer\"))",
            "(allow file-write* (subpath \"\(home)/Library/Caches\"))",
            "",
            "(allow sysctl*)",
            "(allow mach*)",
            "(allow iokit*)",
        ]

        if allowNetwork {
            lines.append("(allow network*)")
        } else {
            lines.append("(deny network*)")
        }

        return lines.joined(separator: "\n")
    }
}

// ═══════════════════════════════════════════════════════════════════
// MARK: - Sandboxed Command Runner
// ═══════════════════════════════════════════════════════════════════

/// Run a command inside a sandboxed subprocess with environment scrubbing
/// and volatile project root isolation.
///
/// Uses `sandbox-exec` when available (macOS). Falls back to environment
/// scrubbing + volatile root only if sandbox-exec is absent.
///
/// - Parameters:
///   - command: Shell command to execute (passed to /bin/sh -c)
///   - volatileRoot: The volatile project root URL (working directory)
///   - allowNetwork: Whether to permit network access (default: false)
///   - timeout: Maximum execution time in seconds
///   - extraEnv: Additional environment variables to inject
/// - Returns: `ProcessResult` with exit code, stdout, stderr
func sandboxedRunCommand(
    _ command: String,
    volatileRoot: URL,
    allowNetwork: Bool = false,
    timeout: TimeInterval = 120,
    extraEnv: [String: String] = [:]
) async -> ProcessResult {
    let sandboxAvailable = FileManager.default.fileExists(atPath: "/usr/bin/sandbox-exec")

    // Build sanitized environment
    var envExtras = extraEnv
    envExtras["TMPDIR"] = volatileRoot.path
    let env = SanitizedEnvironment.build(extras: envExtras)

    let state = ProcessContinuationState<ProcessResult>()
    let cancellationResult = ProcessResult(
        exitCode: -1,
        stdout: "",
        stderr: "Cancelled sandboxed command"
    )

    return await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process.init()

                if sandboxAvailable {
                    // Wrap with sandbox-exec
                    let profile = EvalSandboxProfile.build(
                        volatileRoot: volatileRoot.path,
                        allowNetwork: allowNetwork
                    )
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
                    process.arguments = ["-p", profile, "/bin/sh", "-c", command]
                } else {
                    // Fallback: no sandbox-exec, just env scrub + volatile root
                    process.executableURL = URL(fileURLWithPath: "/bin/sh")
                    process.arguments = ["-c", command]
                }

                process.currentDirectoryURL = volatileRoot
                process.environment = env

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
                        stderr: "Failed to launch sandboxed command: \(error.localizedDescription)"
                    ))
                }
            }
        }
    } onCancel: {
        state.terminate()
        state.resume(returning: cancellationResult)
    }
}
#endif // !EPISTEMOS_APP_STORE -- Harness eval sandbox (subprocess spawning, Pro-only)
