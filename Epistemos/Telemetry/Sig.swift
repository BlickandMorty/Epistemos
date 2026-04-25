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
/// Designed to be TSAN-safe: exposes only the 6 `OSSignposter` instances
/// (which are Sendable per Apple) and lets every call site use the
/// `beginInterval`/`endInterval` + `defer` pattern directly. We do not
/// expose closure-wrapping helpers because closure parameters that capture
/// `@MainActor`-isolated or non-`Sendable` state (e.g. `OpaquePointer`
/// engine handles in MetalGraphView) trip Swift 6 strict-concurrency
/// checking under `-enableThreadSanitizer YES`.
///
/// Usage pattern at call sites:
///
///     let id = Sig.render.makeSignpostID()
///     let state = Sig.render.beginInterval("frame", id: id, "nodes=\(count)")
///     defer { Sig.render.endInterval("frame", state) }
///     // ... existing call ...
///
/// `nonisolated` so callers in any actor context can read the static
/// signposter without an actor hop. `OSSignposter` itself is Sendable.
nonisolated public enum Sig {
    public static let render    = OSSignposter(subsystem: "io.epistemos.core", category: "render")
    public static let mcp       = OSSignposter(subsystem: "io.epistemos.core", category: "mcp")
    public static let graph     = OSSignposter(subsystem: "io.epistemos.core", category: "graph")
    public static let ffi       = OSSignposter(subsystem: "io.epistemos.core", category: "ffi")
    public static let storage   = OSSignposter(subsystem: "io.epistemos.core", category: "storage")
    public static let inference = OSSignposter(subsystem: "io.epistemos.core", category: "inference")
}
