import Foundation
import os

// MARK: - Unified Logging
// Wraps os.Logger for structured, privacy-aware logging.
// Zero-cost when not observed — messages are compiled out at runtime
// unlike print() which always evaluates and writes to stdout.
//
// The enum is nonisolated so loggers can be accessed from @Sendable closures,
// nonisolated methods, and actors. Logger is Sendable so this is safe.
// The subsystem uses a fixed string to avoid MainActor-isolated Bundle access.

nonisolated enum Log {
    private static let subsystem = "com.epistemos"

    /// General app lifecycle events
    static let app = Logger(subsystem: subsystem, category: "app")

    /// Database / SwiftData operations
    static let db = Logger(subsystem: subsystem, category: "database")

    /// Chat & LLM pipeline
    static let pipeline = Logger(subsystem: subsystem, category: "pipeline")

    /// Notes & vault file operations
    static let notes = Logger(subsystem: subsystem, category: "notes")

    /// Vault file system access
    static let vault = Logger(subsystem: subsystem, category: "vault")

    /// Learning protocol & scheduler
    static let learning = Logger(subsystem: subsystem, category: "learning")

    /// Research service (Semantic Scholar, etc.)
    static let research = Logger(subsystem: subsystem, category: "research")

    /// Security & keychain operations
    static let security = Logger(subsystem: subsystem, category: "security")

    /// Engine services (triage, SOAR, signals)
    static let engine = Logger(subsystem: subsystem, category: "engine")
}
