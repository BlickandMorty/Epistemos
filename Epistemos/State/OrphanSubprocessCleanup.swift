import Foundation
import os

// MARK: - Orphan Subprocess Cleanup
//
// Registers termination handlers for all child processes spawned by Epistemos:
//   - LocalAgent Python subprocess
//   - Rust PTY pool sessions
//   - Token Savior MCP server
//   - Any active Paperclip Node.js instances
//
// When the app terminates (gracefully or via crash), all child processes
// receive SIGTERM within 500ms. This prevents zombie processes from
// accumulating across restarts.

private let cleanupLog = Logger(subsystem: "com.epistemos.state", category: "SubprocessCleanup")

@MainActor
final class OrphanSubprocessCleanup {

    /// Tracked child process PIDs.
    private var trackedPIDs: Set<pid_t> = []

    /// Process objects we can terminate directly.
    private var trackedProcesses: [Process] = []

    /// Whether cleanup has already run (prevent double-cleanup).
    private var didCleanup = false

    init(processInfoEnvironment: [String: String] = ProcessInfo.processInfo.environment) {
        guard processInfoEnvironment["XCTestConfigurationFilePath"] == nil else {
            cleanupLog.info("Skipping subprocess signal handlers under tests")
            return
        }
        registerTerminationHandlers()
    }

    // MARK: - Registration

    /// Track a Process object for cleanup on termination.
    func track(_ process: Process) {
        guard process.isRunning else { return }
        trackedProcesses.append(process)
        trackedPIDs.insert(pid_t(process.processIdentifier))
        cleanupLog.debug("Tracking subprocess PID \(process.processIdentifier)")
    }

    /// Track a raw PID for cleanup (e.g., from PTY fork).
    func trackPID(_ pid: pid_t) {
        trackedPIDs.insert(pid)
        cleanupLog.debug("Tracking PID \(pid)")
    }

    /// Remove a PID from tracking (e.g., process exited normally).
    func untrack(_ pid: pid_t) {
        trackedPIDs.remove(pid)
        trackedProcesses.removeAll { pid_t($0.processIdentifier) == pid }
    }

    /// Number of tracked subprocesses.
    var trackedCount: Int {
        trackedPIDs.count
    }

    // MARK: - Cleanup

    /// Perform immediate cleanup of all tracked subprocesses.
    /// Called automatically on app termination, or manually for testing.
    func cleanupAll() {
        guard !didCleanup else { return }
        didCleanup = true

        let trackedProcessTreePIDs = snapshotTrackedProcessTreePIDs()
        cleanupLog.info("Cleaning up \(trackedProcessTreePIDs.count) tracked subprocesses")

        terminateProcessTree(trackedProcessTreePIDs)

        trackedProcesses.removeAll()
        trackedPIDs.removeAll()
    }

    /// Terminate a process and any descendants that are still attached to it.
    func cleanupProcessTree(rootPID: pid_t) {
        terminateProcessTree(processTreePIDs(rootPID: rootPID))
    }

    // MARK: - Private

    private func registerTerminationHandlers() {
        // NSApplication willTerminate — graceful quit
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.cleanupAll()
            }
        }

        // SIGTERM handler — process being killed
        let sigTermSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigTermSource.setEventHandler { [weak self] in
            self?.cleanupAll()
            exit(0)
        }
        signal(SIGTERM, SIG_IGN) // Let DispatchSource handle it
        sigTermSource.resume()

        // SIGINT handler — Ctrl+C in terminal
        let sigIntSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigIntSource.setEventHandler { [weak self] in
            self?.cleanupAll()
            exit(0)
        }
        signal(SIGINT, SIG_IGN)
        sigIntSource.resume()

        // Store sources to keep them alive
        _sigTermSource = sigTermSource
        _sigIntSource = sigIntSource

        cleanupLog.info("Subprocess cleanup handlers registered")
    }

    private func terminateProcessTree(_ processTreePIDs: Set<pid_t>) {
        for pid in processTreePIDs {
            kill(pid, SIGTERM)
        }

        for process in trackedProcesses where process.isRunning {
            process.terminate()
        }

        let logger = cleanupLog
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) { [processTreePIDs, logger] in
            for pid in processTreePIDs where kill(pid, 0) == 0 {
                logger.warning("Force-killing straggler PID \(pid)")
                kill(pid, SIGKILL)
            }
        }
    }

    private func snapshotTrackedProcessTreePIDs() -> Set<pid_t> {
        trackedPIDs.reduce(into: Set<pid_t>()) { result, pid in
            result.formUnion(processTreePIDs(rootPID: pid))
        }
    }

    private func processTreePIDs(rootPID: pid_t) -> Set<pid_t> {
        guard rootPID > 0 else { return [] }

        var result: Set<pid_t> = []
        var stack: [pid_t] = [rootPID]
        while let pid = stack.popLast() {
            guard pid > 0, result.insert(pid).inserted else { continue }
            stack.append(contentsOf: childPIDs(of: pid))
        }
        return result
    }

    private func childPIDs(of parentPID: pid_t) -> [pid_t] {
        var capacity = 8
        while true {
            var buffer = Array(repeating: pid_t(0), count: capacity)
            let bufferSize = buffer.count * MemoryLayout<pid_t>.stride
            let childCount = Int(proc_listchildpids(parentPID, &buffer, Int32(bufferSize)))
            guard childCount > 0 else { return [] }

            if childCount < capacity {
                return Array(buffer.prefix(childCount))
            }

            capacity *= 2
        }
    }

    // Hold strong references to dispatch sources
    private var _sigTermSource: DispatchSourceSignal?
    private var _sigIntSource: DispatchSourceSignal?
}
