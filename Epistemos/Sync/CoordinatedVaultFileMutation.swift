import Foundation

enum CoordinatedVaultFileMutationError: Error, Sendable {
    case coordination(Error)
    case operation(Error)
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
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var operationError: Error?

        coordinator.coordinate(
            writingItemAt: sourceURL,
            options: .forMoving,
            writingItemAt: destinationURL,
            options: [],
            error: &coordinatorError
        ) { coordinatedSourceURL, coordinatedDestinationURL in
            do {
                try fileManager.createDirectory(
                    at: coordinatedDestinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try fileManager.moveItem(at: coordinatedSourceURL, to: coordinatedDestinationURL)
            } catch {
                operationError = error
            }
        }

        if let coordinatorError {
            throw CoordinatedVaultFileMutationError.coordination(coordinatorError)
        }
        if let operationError {
            throw CoordinatedVaultFileMutationError.operation(operationError)
        }
    }

    nonisolated static func removeItem(
        at targetURL: URL,
        fileManager: FileManager = .default
    ) throws {
        _ = try coordinateDeletion(at: targetURL) { coordinatedURL in
            try fileManager.removeItem(at: coordinatedURL)
            return .removed
        }
    }

    nonisolated static func trashOrRemoveItem(
        at targetURL: URL,
        fileManager: FileManager = .default
    ) throws -> CoordinatedVaultRemovalResult {
        try coordinateDeletion(at: targetURL) { coordinatedURL in
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
        operation: (URL) throws -> CoordinatedVaultRemovalResult
    ) throws -> CoordinatedVaultRemovalResult {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var operationResult: CoordinatedVaultRemovalResult?
        var operationError: Error?

        coordinator.coordinate(
            writingItemAt: targetURL,
            options: .forDeleting,
            error: &coordinatorError
        ) { coordinatedURL in
            do {
                operationResult = try operation(coordinatedURL)
            } catch {
                operationError = error
            }
        }

        if let coordinatorError {
            throw CoordinatedVaultFileMutationError.coordination(coordinatorError)
        }
        if let operationError {
            throw CoordinatedVaultFileMutationError.operation(operationError)
        }
        return operationResult ?? .removed
    }
}
