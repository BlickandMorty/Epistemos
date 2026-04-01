import Foundation
import os

// MARK: - Orphan Subprocess Cleanup
//
// Registers termination handlers for all child processes spawned by Epistemos:
//   - Hermes Python subprocess
//   - Rust PTY pool sessions
//   - Token Savior MCP server
//   - Any active Paperclip Node.js instances
//
// When the app terminates (gracefully or via crash), all child processes
// receive SIGTERM within 500ms. This prevents zombie processes from
// accumulating across restarts.

nonisolated(unsafe) private let cleanupLog = Logger(subsystem: "com.epistemos.state", category: "SubprocessCleanup")

@MainActor
final class OrphanSubprocessCleanup {

    /// Tracked child process PIDs.
    private var trackedPIDs: Set<pid_t> = []

    /// Process objects we can terminate directly.
    private var trackedProcesses: [Process] = []

    /// Whether cleanup has already run (prevent double-cleanup).
    private var didCleanup = false

    init() {
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

        cleanupLog.info("Cleaning up \(self.trackedPIDs.count) tracked subprocesses")

        // Phase 1: Send SIGTERM to all tracked PIDs
        for pid in trackedPIDs {
            kill(pid, SIGTERM)
        }

        // Phase 2: Terminate Process objects directly
        for process in trackedProcesses where process.isRunning {
            process.terminate()
        }

        // Phase 3: Give 500ms for graceful shutdown, then SIGKILL stragglers
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) { [trackedPIDs] in
            for pid in trackedPIDs {
                // Check if still alive
                if kill(pid, 0) == 0 {
                    cleanupLog.warning("Force-killing straggler PID \(pid)")
                    kill(pid, SIGKILL)
                }
            }
        }

        trackedProcesses.removeAll()
        trackedPIDs.removeAll()
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

    // Hold strong references to dispatch sources
    private var _sigTermSource: DispatchSourceSignal?
    private var _sigIntSource: DispatchSourceSignal?
}
