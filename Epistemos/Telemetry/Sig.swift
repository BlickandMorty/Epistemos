import os.signpost
import Foundation

/// Typed OSSignposter facade for Epistemos performance instrumentation.
/// All Sprint 0 (Wave 2) signpost intervals route through this module
/// so Instruments can filter by subsystem `io.epistemos.core`.
///
/// Per docs/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md §1.1 Task 0.1.
/// Per docs/architecture/COGNITIVE_ARTIFACT_IMPLEMENTATION_PLAN.md §13.
///
/// This is additive-only — pre-existing `Log.graphPerf` / `Log.ffiPerf`
/// signposters under subsystem `com.epistemos` continue to work unchanged.
/// `Sig.*` adds a parallel canonical surface for the deterministic perf plan.
///
/// `nonisolated` so callers in any actor context (including `nonisolated`
/// functions and background actors) can wrap intervals without an actor hop.
/// `OSSignposter` is `Sendable`.
nonisolated public enum Sig {
    public static let render    = OSSignposter(subsystem: "io.epistemos.core", category: "render")
    public static let mcp       = OSSignposter(subsystem: "io.epistemos.core", category: "mcp")
    public static let graph     = OSSignposter(subsystem: "io.epistemos.core", category: "graph")
    public static let ffi       = OSSignposter(subsystem: "io.epistemos.core", category: "ffi")
    public static let storage   = OSSignposter(subsystem: "io.epistemos.core", category: "storage")
    public static let inference = OSSignposter(subsystem: "io.epistemos.core", category: "inference")

    @inlinable
    public static func interval<T>(
        _ poster: OSSignposter,
        _ name: StaticString,
        _ message: @autoclosure () -> String = "",
        _ body: () throws -> T
    ) rethrows -> T {
        let id = poster.makeSignpostID()
        let evaluatedMessage = message()
        let state = poster.beginInterval(name, id: id, "\(evaluatedMessage)")
        defer { poster.endInterval(name, state) }
        return try body()
    }

    @inlinable
    public static func intervalAsync<T>(
        _ poster: OSSignposter,
        _ name: StaticString,
        _ message: @autoclosure () -> String = "",
        _ body: () async throws -> T
    ) async rethrows -> T {
        let id = poster.makeSignpostID()
        let evaluatedMessage = message()
        let state = poster.beginInterval(name, id: id, "\(evaluatedMessage)")
        defer { poster.endInterval(name, state) }
        return try await body()
    }
}
