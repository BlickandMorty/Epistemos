import Foundation

// MARK: - ArenaPathResolver

/// Resolves the canonical path to the mmap arena backing file.
///
/// This struct is the single source of truth for the arena file path across
/// the Swift and Rust boundaries.  It prefers the App Group container and
/// falls back to the legacy Application Support directory if the App Group
/// is unavailable.
public struct ArenaPathResolver {

    /// Resolve the arena file URL, creating parent directories if necessary.
    ///
    /// - Throws: `ArenaPathError` if resolution fails.
    /// - Returns: The file URL of the arena backing file.
    public static func resolve() throws -> URL {
        let container = AppGroupContainer.shared

        // 1. Try the App Group container first.
        if container.containerURL != nil {
            let arena = container.arenaURL
            let parent = arena.deletingLastPathComponent()
            let fm = FileManager.default
            if !fm.fileExists(atPath: parent.path) {
                try fm.createDirectory(
                    at: parent,
                    withIntermediateDirectories: true,
                    attributes: [FileAttributeKey.posixPermissions: 0o700]
                )
            }
            return arena
        }

        // 2. Fallback: legacy Application Support path.
        print("[ArenaPathResolver] App Group unavailable — using legacy fallback.")
        return legacyFallback()
    }

    /// Return the legacy fallback URL without creating directories.
    ///
    /// Use this only when the App Group is known to be unavailable (e.g.
    /// during migration assessment or in pre-MAS diagnostic tooling).
    public static func legacyFallback() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport
            .appendingPathComponent("Epistenos", isDirectory: true)
            .appendingPathComponent("arena", isDirectory: true)
            .appendingPathComponent("epistenos.arena")
    }

    /// Return the path as a NUL-terminated C string for the Rust FFI boundary.
    ///
    /// - Returns: A `Data` blob containing the UTF-8 encoded path plus a trailing
    ///   NUL byte suitable for `std::ffi::CStr`.
    public static func resolveCString() throws -> Data {
        let url = try resolve()
        var bytes = url.path.data(using: .utf8)!
        bytes.append(0)
        return bytes
    }
}

// MARK: - ArenaPathError

public enum ArenaPathError: Error, LocalizedError {
    case noAppGroupAndNoLegacy
    case directoryCreationFailed(Error)
    case invalidPathEncoding

    public var errorDescription: String? {
        switch self {
        case .noAppGroupAndNoLegacy:
            return "Neither App Group nor legacy Application Support directory is available."
        case .directoryCreationFailed(let e):
            return "Could not create arena directory: \(e.localizedDescription)"
        case .invalidPathEncoding:
            return "Arena path could not be encoded as UTF-8."
        }
    }
}
