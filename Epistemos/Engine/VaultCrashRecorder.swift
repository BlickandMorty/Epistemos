import Foundation
import Darwin

nonisolated enum VaultCrashRecorder {
    private static let stateLock = NSLock()
    private static let maxRetainedExceptionReports = 25
    private static let signalLogFilename = "fatal-signals.log"
    private static let readyMarkerFilename = "crash-recorder-ready.json"

    nonisolated(unsafe) private static var installed = false
    nonisolated(unsafe) private static var signalHandlersInstalled = false
    nonisolated(unsafe) private static var signalLogPathCString: UnsafeMutablePointer<CChar>?

    static func install(vaultURL: URL?, fileManager: FileManager = .default) {
        let shouldInstallSignalHandlers: Bool
        stateLock.lock()
        installed = true
        shouldInstallSignalHandlers = !signalHandlersInstalled
        signalHandlersInstalled = true
        stateLock.unlock()

        updateVaultURL(vaultURL, fileManager: fileManager)

        if shouldInstallSignalHandlers {
            installSignalHandlers()
        }
    }

    static func updateVaultURL(_ vaultURL: URL?, fileManager: FileManager = .default) {
        guard isInstalled else { return }

        do {
            let directory = try prepareDiagnosticsDirectory(vaultURL: vaultURL, fileManager: fileManager)
            setSignalLogPath(directory.appendingPathComponent(signalLogFilename, isDirectory: false).path)
            Log.diagnostics.info(
                "Vault crash recorder armed at \(directory.path, privacy: .public)"
            )
        } catch {
            Log.diagnostics.error(
                "Vault crash recorder failed to prepare diagnostics directory: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    static func diagnosticsDirectory(
        vaultURL: URL?,
        fallbackBaseDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        if let vaultURL {
            return vaultURL
                .appendingPathComponent(".epcache", isDirectory: true)
                .appendingPathComponent("diagnostics", isDirectory: true)
        }
        return try RuntimeDiagnostics.crashReportsDirectoryURL(
            baseDirectory: fallbackBaseDirectory,
            fileManager: fileManager
        )
    }

    @discardableResult
    static func prepareDiagnosticsDirectory(
        vaultURL: URL?,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> URL {
        let directory = try diagnosticsDirectory(vaultURL: vaultURL, fileManager: fileManager)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try writeReadyMarker(
            in: directory,
            vaultURL: vaultURL,
            now: now,
            fileManager: fileManager
        )
        return directory
    }

    static func recordUncaughtException(
        _ exception: NSException,
        vaultURL: URL?,
        now: Date = Date(),
        fileManager: FileManager = .default
    ) {
        guard isInstalled else { return }

        do {
            let directory = try prepareDiagnosticsDirectory(vaultURL: vaultURL, now: now, fileManager: fileManager)
            let formatter = ISO8601DateFormatter()
            let report = ExceptionReport(
                capturedAt: formatter.string(from: now),
                processID: ProcessInfo.processInfo.processIdentifier,
                exceptionName: exception.name.rawValue,
                reason: exception.reason ?? "unknown",
                userInfo: String(describing: exception.userInfo ?? [:]),
                callStack: exception.callStackSymbols
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            let filename = "uncaught-exception-\(Self.fileStamp(for: now))-\(UUID().uuidString).json"
            try data.write(
                to: directory.appendingPathComponent(filename, isDirectory: false),
                options: .atomic
            )
            try pruneExceptionReports(in: directory, fileManager: fileManager)
        } catch {
            Log.diagnostics.error(
                "Vault crash recorder failed to persist uncaught exception: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    fileprivate static func writeFatalSignal(_ signalNumber: Int32) {
        guard let path = signalLogPathCString else { return }
        let fd = open(path, O_WRONLY | O_CREAT | O_APPEND, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
        guard fd >= 0 else { return }
        defer { close(fd) }

        // Async-signal-safe: select a compile-time StaticString per signal (no allocation, no
        // integer formatting, no locks) so the log distinguishes e.g. SIGSEGV from SIGABRT — the
        // previous fixed line made every fatal crash byte-identical and unattributable.
        let message: StaticString
        switch signalNumber {
        case SIGABRT: message = "Epistemos fatal signal: SIGABRT\n"
        case SIGBUS: message = "Epistemos fatal signal: SIGBUS\n"
        case SIGFPE: message = "Epistemos fatal signal: SIGFPE\n"
        case SIGILL: message = "Epistemos fatal signal: SIGILL\n"
        case SIGSEGV: message = "Epistemos fatal signal: SIGSEGV\n"
        case SIGTRAP: message = "Epistemos fatal signal: SIGTRAP\n"
        default: message = "Epistemos fatal signal captured\n"
        }
        message.withUTF8Buffer { buffer in
            if let baseAddress = buffer.baseAddress {
                _ = write(fd, baseAddress, buffer.count)
            }
        }
    }

    private static var isInstalled: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return installed
    }

    private static func installSignalHandlers() {
        signal(SIGABRT, EpistemosVaultCrashSignalHandler)
        signal(SIGBUS, EpistemosVaultCrashSignalHandler)
        signal(SIGFPE, EpistemosVaultCrashSignalHandler)
        signal(SIGILL, EpistemosVaultCrashSignalHandler)
        signal(SIGSEGV, EpistemosVaultCrashSignalHandler)
        signal(SIGTRAP, EpistemosVaultCrashSignalHandler)
    }

    private static func setSignalLogPath(_ path: String) {
        guard let cString = strdup(path) else { return }
        stateLock.lock()
        // Intentionally keep older C strings alive so a racing fatal signal never
        // follows a freed pointer while the vault destination is being swapped.
        signalLogPathCString = cString
        stateLock.unlock()
    }

    private static func writeReadyMarker(
        in directory: URL,
        vaultURL: URL?,
        now: Date,
        fileManager: FileManager
    ) throws {
        let formatter = ISO8601DateFormatter()
        let marker = ReadyMarker(
            installedAt: formatter.string(from: now),
            processID: ProcessInfo.processInfo.processIdentifier,
            signalLog: signalLogFilename,
            vaultPath: vaultURL?.path
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(marker)
        try data.write(
            to: directory.appendingPathComponent(readyMarkerFilename, isDirectory: false),
            options: .atomic
        )
    }

    private static func pruneExceptionReports(in directory: URL, fileManager: FileManager) throws {
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let exceptionReports = try contents
            .filter { $0.lastPathComponent.hasPrefix("uncaught-exception-") }
            .sorted { lhs, rhs in
                let lhsDate = try lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
                let rhsDate = try rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
                return lhsDate > rhsDate
            }
        guard exceptionReports.count > maxRetainedExceptionReports else { return }
        for url in exceptionReports.dropFirst(maxRetainedExceptionReports) {
            try? fileManager.removeItem(at: url)
        }
    }

    private static func fileStamp(for date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")
    }

    private struct ReadyMarker: Codable {
        let installedAt: String
        let processID: Int32
        let signalLog: String
        let vaultPath: String?
    }

    private struct ExceptionReport: Codable {
        let capturedAt: String
        let processID: Int32
        let exceptionName: String
        let reason: String
        let userInfo: String
        let callStack: [String]
    }
}

nonisolated(unsafe) private let EpistemosVaultCrashSignalHandler: @convention(c) (Int32) -> Void = { signalNumber in
    VaultCrashRecorder.writeFatalSignal(signalNumber)
    signal(signalNumber, SIG_DFL)
    raise(signalNumber)
    _exit(128 + signalNumber)
}
