import Foundation

enum CoordinatedVaultFileMutationError: Error, Sendable {
    case coordination(Error)
    case coordinationCallbackNotInvoked
    case operation(Error)
    case sourceBaselineRead(Error)
    case sourceBaselineMismatch
    case invalidSourceBaseline
    case destinationBaselineRead(Error)
    case destinationBaselineMismatch
    case targetBaselineRead(Error)
    case targetBaselineMismatch
    case invalidTargetBaseline
    case crossVolumeMove
    case postMutationDurability(Error)
}

enum CoordinatedVaultRemovalResult: Sendable, Equatable {
    case trashed(URL?)
    case removed
}

/// Coordinates non-content vault mutations with File Provider/iCloud peers.
///
/// `AtomicVaultWriter` owns whole-buffer content replacement. This helper covers
/// the other vault mutations that must also participate in NSFileCoordinator:
/// moves/renames and deletes. FSEvents remains the broad change source.
enum CoordinatedVaultFileMutation {
    nonisolated static func moveItem(
        at sourceURL: URL,
        to destinationURL: URL,
        fileManager: FileManager = .default
    ) throws {
        try moveItem(
            at: sourceURL,
            to: destinationURL,
            ifSourceMatches: nil,
            requireDestinationAbsent: false,
            fileManager: fileManager
        )
    }

    nonisolated static func moveItem(
        at sourceURL: URL,
        to destinationURL: URL,
        ifSourceMatches expectedSourceBaseline: VaultFileBaseline,
        fileManager: FileManager = .default
    ) throws {
        guard case .contents = expectedSourceBaseline else {
            throw CoordinatedVaultFileMutationError.invalidSourceBaseline
        }
        try moveItem(
            at: sourceURL,
            to: destinationURL,
            ifSourceMatches: expectedSourceBaseline,
            requireDestinationAbsent: true,
            fileManager: fileManager
        )
    }

    private nonisolated static func moveItem(
        at sourceURL: URL,
        to destinationURL: URL,
        ifSourceMatches expectedSourceBaseline: VaultFileBaseline?,
        requireDestinationAbsent: Bool,
        fileManager: FileManager
    ) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var callbackResult: Result<Void, Error>?

        coordinator.coordinate(
            writingItemAt: sourceURL,
            options: .forMoving,
            writingItemAt: destinationURL,
            options: .forReplacing,
            error: &coordinatorError
        ) { coordinatedSourceURL, coordinatedDestinationURL in
            do {
                try fileManager.createDirectory(
                    at: coordinatedDestinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if expectedSourceBaseline != nil {
                    try verifySameVolume(
                        sourceURL: coordinatedSourceURL,
                        destinationURL: coordinatedDestinationURL
                    )
                }
                if let expectedSourceBaseline {
                    try verifySource(
                        expectedSourceBaseline,
                        at: coordinatedSourceURL,
                        fileManager: fileManager
                    )
                }
                if requireDestinationAbsent {
                    try verifyDestination(
                        .absent,
                        at: coordinatedDestinationURL,
                        fileManager: fileManager
                    )
                }
                try fileManager.moveItem(at: coordinatedSourceURL, to: coordinatedDestinationURL)
                do {
                    try syncMoveParentDirectories(
                        sourceURL: coordinatedSourceURL,
                        destinationURL: coordinatedDestinationURL
                    )
                } catch {
                    throw CoordinatedVaultFileMutationError.postMutationDurability(error)
                }
                callbackResult = .success(())
            } catch {
                callbackResult = .failure(error)
            }
        }

        if let coordinatorError {
            throw CoordinatedVaultFileMutationError.coordination(coordinatorError)
        }
        guard let callbackResult else {
            throw CoordinatedVaultFileMutationError.coordinationCallbackNotInvoked
        }
        do {
            try callbackResult.get()
        } catch let error as CoordinatedVaultFileMutationError {
            throw error
        } catch {
            throw CoordinatedVaultFileMutationError.operation(error)
        }
    }

    nonisolated static func removeItem(
        at targetURL: URL,
        fileManager: FileManager = .default
    ) throws {
        _ = try coordinateDeletion(at: targetURL, fileManager: fileManager) { coordinatedURL in
            try fileManager.removeItem(at: coordinatedURL)
            return .removed
        }
    }

    nonisolated static func removeItem(
        at targetURL: URL,
        ifCurrentMatches expectedBaseline: VaultFileBaseline,
        fileManager: FileManager = .default
    ) throws {
        guard case .contents = expectedBaseline else {
            throw CoordinatedVaultFileMutationError.invalidTargetBaseline
        }
        _ = try coordinateDeletion(
            at: targetURL,
            expectedBaseline: expectedBaseline,
            fileManager: fileManager
        ) { coordinatedURL in
            try fileManager.removeItem(at: coordinatedURL)
            return .removed
        }
    }

    nonisolated static func trashOrRemoveItem(
        at targetURL: URL,
        fileManager: FileManager = .default
    ) throws -> CoordinatedVaultRemovalResult {
        try coordinateDeletion(
            at: targetURL,
            expectedBaseline: nil,
            fileManager: fileManager
        ) { coordinatedURL in
            var trashedURL: NSURL?
            do {
                try fileManager.trashItem(at: coordinatedURL, resultingItemURL: &trashedURL)
                return .trashed(trashedURL as URL?)
            } catch {
                try fileManager.removeItem(at: coordinatedURL)
                return .removed
            }
        }
    }

    private nonisolated static func coordinateDeletion(
        at targetURL: URL,
        expectedBaseline: VaultFileBaseline? = nil,
        fileManager: FileManager,
        operation: (URL) throws -> CoordinatedVaultRemovalResult
    ) throws -> CoordinatedVaultRemovalResult {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var callbackResult: Result<CoordinatedVaultRemovalResult, Error>?

        coordinator.coordinate(
            writingItemAt: targetURL,
            options: .forDeleting,
            error: &coordinatorError
        ) { coordinatedURL in
            do {
                if let expectedBaseline {
                    try verifyTarget(
                        expectedBaseline,
                        at: coordinatedURL,
                        fileManager: fileManager
                    )
                }
                let operationResult = try operation(coordinatedURL)
                do {
                    try syncDirectory(coordinatedURL.deletingLastPathComponent())
                } catch {
                    throw CoordinatedVaultFileMutationError.postMutationDurability(error)
                }
                callbackResult = .success(operationResult)
            } catch {
                callbackResult = .failure(error)
            }
        }

        if let coordinatorError {
            throw CoordinatedVaultFileMutationError.coordination(coordinatorError)
        }
        guard let callbackResult else {
            throw CoordinatedVaultFileMutationError.coordinationCallbackNotInvoked
        }
        do {
            return try callbackResult.get()
        } catch let error as CoordinatedVaultFileMutationError {
            throw error
        } catch {
            throw CoordinatedVaultFileMutationError.operation(error)
        }
    }

    private nonisolated static func verifySource(
        _ baseline: VaultFileBaseline,
        at url: URL,
        fileManager: FileManager
    ) throws {
        try verify(
            baseline,
            at: url,
            fileManager: fileManager,
            readError: CoordinatedVaultFileMutationError.sourceBaselineRead,
            mismatch: .sourceBaselineMismatch
        )
    }

    private nonisolated static func verifyDestination(
        _ baseline: VaultFileBaseline,
        at url: URL,
        fileManager: FileManager
    ) throws {
        try verify(
            baseline,
            at: url,
            fileManager: fileManager,
            readError: CoordinatedVaultFileMutationError.destinationBaselineRead,
            mismatch: .destinationBaselineMismatch
        )
    }

    private nonisolated static func verifyTarget(
        _ baseline: VaultFileBaseline,
        at url: URL,
        fileManager: FileManager
    ) throws {
        try verify(
            baseline,
            at: url,
            fileManager: fileManager,
            readError: CoordinatedVaultFileMutationError.targetBaselineRead,
            mismatch: .targetBaselineMismatch
        )
    }

    private nonisolated static func verify(
        _ baseline: VaultFileBaseline,
        at url: URL,
        fileManager: FileManager,
        readError: (Error) -> CoordinatedVaultFileMutationError,
        mismatch: CoordinatedVaultFileMutationError
    ) throws {
        switch baseline {
        case .absent:
            guard !fileManager.fileExists(atPath: url.path) else { throw mismatch }
        case .contents(let expectedData):
            guard fileManager.fileExists(atPath: url.path) else { throw mismatch }
            let currentData: Data
            do {
                currentData = try Data(contentsOf: url)
            } catch {
                throw readError(error)
            }
            guard currentData == expectedData else { throw mismatch }
        }
    }

    private nonisolated static func verifySameVolume(
        sourceURL: URL,
        destinationURL: URL
    ) throws {
        let sourceValues = try sourceURL.resourceValues(forKeys: [.volumeURLKey])
        let destinationValues = try destinationURL
            .deletingLastPathComponent()
            .resourceValues(forKeys: [.volumeURLKey])
        let sourceVolume = (sourceValues.allValues[.volumeURLKey] as? URL)?
            .standardizedFileURL
        let destinationVolume = (destinationValues.allValues[.volumeURLKey] as? URL)?
            .standardizedFileURL
        guard let sourceVolume,
              let destinationVolume,
              sourceVolume == destinationVolume
        else {
            throw CoordinatedVaultFileMutationError.crossVolumeMove
        }
    }

    private nonisolated static func syncMoveParentDirectories(
        sourceURL: URL,
        destinationURL: URL
    ) throws {
        let sourceParent = sourceURL.deletingLastPathComponent().standardizedFileURL
        let destinationParent = destinationURL.deletingLastPathComponent().standardizedFileURL
        try syncDirectory(destinationParent)
        if sourceParent != destinationParent {
            try syncDirectory(sourceParent)
        }
    }

    private nonisolated static func syncDirectory(_ directoryURL: URL) throws {
        let fileDescriptor = open(directoryURL.path, O_RDONLY)
        guard fileDescriptor >= 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        defer { close(fileDescriptor) }
        guard NoteFileStorage.performFullSync(fileDescriptor) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
