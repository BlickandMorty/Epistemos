import Foundation
import os

enum VaultFileBaseline: Sendable, Equatable {
    case absent
    case contents(Data)
}

enum AtomicVaultWriteError: Error, Sendable {
    case coordination(Error)
    case coordinationCallbackNotInvoked
    case baselineRead(Error)
    case baselineMismatch
    case encodingFailed
    case scratchDirectory(Error)
    case scratchWrite(Error)
    case scratchSync(Error)
    case replace(Error)
    case parentDirectorySync(Error)
}

/// Whole-buffer, coordinated vault-file replacement.
///
/// Vault files are the source of truth. This writer never streams partial content
/// into the target URL: it writes the complete UTF-8 buffer to a same-volume
/// scratch file, durably syncs it, then atomically swaps it into place inside an
/// `NSFileCoordinator` replacement transaction.
actor AtomicVaultWriter {
    static let shared = AtomicVaultWriter()

    private nonisolated static let log = Logger(subsystem: "com.epistemos", category: "AtomicVaultWriter")

    func write(_ content: String, to targetURL: URL) throws {
        try Self.writeSynchronously(content, to: targetURL)
    }

    func write(_ data: Data, to targetURL: URL) throws {
        try Self.writeSynchronously(data, to: targetURL)
    }

    @discardableResult
    func write(
        _ content: String,
        to targetURL: URL,
        ifCurrentMatches expectedBaseline: VaultFileBaseline
    ) throws -> VaultFileBaseline {
        try Self.writeSynchronously(
            content,
            to: targetURL,
            ifCurrentMatches: expectedBaseline
        )
    }

    @discardableResult
    func write(
        _ data: Data,
        to targetURL: URL,
        ifCurrentMatches expectedBaseline: VaultFileBaseline
    ) throws -> VaultFileBaseline {
        try Self.writeSynchronously(
            data,
            to: targetURL,
            ifCurrentMatches: expectedBaseline
        )
    }

    nonisolated static func writeSynchronously(_ content: String, to targetURL: URL) throws {
        guard let data = content.data(using: .utf8) else {
            throw AtomicVaultWriteError.encodingFailed
        }
        try writeSynchronously(data, to: targetURL)
    }

    nonisolated static func writeSynchronously(_ data: Data, to targetURL: URL) throws {
        _ = try writeSynchronously(data, to: targetURL, ifCurrentMatches: nil)
    }

    @discardableResult
    nonisolated static func writeSynchronously(
        _ content: String,
        to targetURL: URL,
        ifCurrentMatches expectedBaseline: VaultFileBaseline
    ) throws -> VaultFileBaseline {
        guard let data = content.data(using: .utf8) else {
            throw AtomicVaultWriteError.encodingFailed
        }
        return try writeSynchronously(
            data,
            to: targetURL,
            ifCurrentMatches: expectedBaseline
        )
    }

    @discardableResult
    nonisolated static func writeSynchronously(
        _ data: Data,
        to targetURL: URL,
        ifCurrentMatches expectedBaseline: VaultFileBaseline
    ) throws -> VaultFileBaseline {
        try writeSynchronously(data, to: targetURL, ifCurrentMatches: expectedBaseline as VaultFileBaseline?)
    }

    @discardableResult
    private nonisolated static func writeSynchronously(
        _ data: Data,
        to targetURL: URL,
        ifCurrentMatches expectedBaseline: VaultFileBaseline?
    ) throws -> VaultFileBaseline {
        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Epistemos atomic vault write"
        )
        defer { ProcessInfo.processInfo.endActivity(activity) }

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var callbackResult: Result<Void, Error>?

        coordinator.coordinate(
            writingItemAt: targetURL,
            options: .forReplacing,
            error: &coordinatorError
        ) { coordinatedURL in
            do {
                try Self.replace(
                    data: data,
                    at: coordinatedURL,
                    ifCurrentMatches: expectedBaseline
                )
                callbackResult = .success(())
            } catch {
                callbackResult = .failure(error)
            }
        }

        if let coordinatorError {
            throw AtomicVaultWriteError.coordination(coordinatorError)
        }
        guard let callbackResult else {
            throw AtomicVaultWriteError.coordinationCallbackNotInvoked
        }
        try callbackResult.get()
        return .contents(data)
    }

    private nonisolated static func replace(
        data: Data,
        at targetURL: URL,
        ifCurrentMatches expectedBaseline: VaultFileBaseline?
    ) throws {
        let fm = FileManager.default
        let scratchDir: URL
        do {
            scratchDir = try fm.url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: targetURL,
                create: true
            )
        } catch {
            throw AtomicVaultWriteError.scratchDirectory(error)
        }
        defer { try? fm.removeItem(at: scratchDir) }

        let scratchURL = scratchDir.appendingPathComponent(
            ".\(targetURL.lastPathComponent).\(UUID().uuidString).tmp"
        )

        do {
            fm.createFile(atPath: scratchURL.path, contents: nil)
            let handle = try FileHandle(forWritingTo: scratchURL)
            do {
                try handle.write(contentsOf: data)
                guard NoteFileStorage.performFullSync(handle.fileDescriptor) else {
                    closeFileHandle(handle)
                    throw AtomicVaultWriteError.scratchSync(
                        CocoaError(.fileWriteUnknown)
                    )
                }
                closeFileHandle(handle)
            } catch let error as AtomicVaultWriteError {
                closeFileHandle(handle)
                throw error
            } catch {
                closeFileHandle(handle)
                throw AtomicVaultWriteError.scratchWrite(error)
            }
        } catch let error as AtomicVaultWriteError {
            throw error
        } catch {
            throw AtomicVaultWriteError.scratchWrite(error)
        }

        do {
            try fm.createDirectory(
                at: targetURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if let expectedBaseline {
                try verify(expectedBaseline, at: targetURL, fileManager: fm)
            }
            if fm.fileExists(atPath: targetURL.path) {
                _ = try fm.replaceItemAt(
                    targetURL,
                    withItemAt: scratchURL,
                    backupItemName: nil,
                    options: []
                )
            } else {
                try fm.moveItem(at: scratchURL, to: targetURL)
            }
        } catch let error as AtomicVaultWriteError {
            throw error
        } catch {
            throw AtomicVaultWriteError.replace(error)
        }

        try synchronizeParentDirectory(of: targetURL)
    }

    private nonisolated static func verify(
        _ expectedBaseline: VaultFileBaseline,
        at targetURL: URL,
        fileManager: FileManager
    ) throws {
        switch expectedBaseline {
        case .absent:
            guard !fileManager.fileExists(atPath: targetURL.path) else {
                throw AtomicVaultWriteError.baselineMismatch
            }
        case .contents(let expectedData):
            guard fileManager.fileExists(atPath: targetURL.path) else {
                throw AtomicVaultWriteError.baselineMismatch
            }
            let currentData: Data
            do {
                currentData = try Data(contentsOf: targetURL)
            } catch {
                throw AtomicVaultWriteError.baselineRead(error)
            }
            guard currentData == expectedData else {
                throw AtomicVaultWriteError.baselineMismatch
            }
        }
    }

    nonisolated static func synchronizeParentDirectory(of targetURL: URL) throws {
        let parent = targetURL.deletingLastPathComponent()
        let fd = open(parent.path, O_RDONLY)
        guard fd >= 0 else {
            throw AtomicVaultWriteError.parentDirectorySync(
                POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            )
        }
        defer { close(fd) }
        guard NoteFileStorage.performFullSync(fd) else {
            throw AtomicVaultWriteError.parentDirectorySync(
                CocoaError(.fileWriteUnknown)
            )
        }
    }

    private nonisolated static func closeFileHandle(_ handle: FileHandle) {
        do {
            try handle.close()
        } catch {
            log.error("Failed to close vault scratch file: \(error.localizedDescription, privacy: .public)")
        }
    }
}
