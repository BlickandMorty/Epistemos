import Foundation
import Testing

@testable import Epistemos

// MARK: - Sig Tests
//
// Sprint 0 (Wave 2.1) signpost facade tests.
// Per docs/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md §1.1 Task 0.1.
//
// Wave 2.1.1 update: removed closure-wrapper tests (Sig.interval /
// Sig.intervalAsync) because the closure-wrapping API was dropped to
// keep TSAN green — closure params capturing non-Sendable engine
// pointers (e.g. MetalGraphView's OpaquePointer) trip Swift 6 strict-
// concurrency under -enableThreadSanitizer YES. Sig now exposes only
// the 6 OSSignposter instances; call sites use begin/defer-end pattern
// directly.
//
// Covers:
// - Sig defines all 6 canonical OSSignposters (render/mcp/graph/ffi/storage/inference)
// - Sig.swift source file exists at the canonical path with the canonical subsystem

@Suite("Sig signpost facade")
nonisolated struct SigTests {

    // MARK: - Category coverage

    @Test func allSixCategoriesDefined() {
        // The signposters themselves are non-optional `OSSignposter` values
        // and therefore always non-nil; we exercise each property to ensure
        // the static initialization succeeds and the symbols exist.
        _ = Sig.render
        _ = Sig.mcp
        _ = Sig.graph
        _ = Sig.ffi
        _ = Sig.storage
        _ = Sig.inference
        #expect(Bool(true), "All six Sig categories must be reachable")
    }

    // MARK: - begin/end roundtrip (TSAN-safe pattern)

    @Test func beginEndRoundtripWorks() {
        let id = Sig.storage.makeSignpostID()
        let state = Sig.storage.beginInterval("search", id: id)
        // ... body would go here ...
        Sig.storage.endInterval("search", state)
        #expect(Bool(true), "begin/end roundtrip must complete without error")
    }

    // MARK: - Source guard

    @Test func sigSourceFileExistsAndHasCanonicalCategories() throws {
        // Walk up from this test file to the repo root and assert the
        // canonical Sig.swift path exists with all six category names.
        let here = URL(fileURLWithPath: #filePath)
        let repoRoot = here
            .deletingLastPathComponent() // EpistemosTests/
            .deletingLastPathComponent() // repo root
        let sigURL = repoRoot
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("Telemetry", isDirectory: true)
            .appendingPathComponent("Sig.swift", isDirectory: false)
        #expect(FileManager.default.fileExists(atPath: sigURL.path),
                "Sig.swift must exist at Epistemos/Telemetry/Sig.swift")

        let source = try String(contentsOf: sigURL, encoding: .utf8)
        for category in ["render", "mcp", "graph", "ffi", "storage", "inference"] {
            #expect(source.contains("static let \(category)"),
                    "Sig.swift must declare canonical category `\(category)`")
        }
        #expect(source.contains("io.epistemos.core"),
                "Sig.swift must use canonical subsystem `io.epistemos.core`")
    }

    @Test func sigDoesNotExposeClosureWrappers() throws {
        // Wave 2.1.1: the closure-wrapper API (Sig.interval, Sig.intervalAsync)
        // was removed because @Sendable closure constraints conflicted with
        // call sites that capture non-Sendable engine pointers. This guards
        // against accidental re-introduction.
        let here = URL(fileURLWithPath: #filePath)
        let repoRoot = here.deletingLastPathComponent().deletingLastPathComponent()
        let sigURL = repoRoot
            .appendingPathComponent("Epistemos", isDirectory: true)
            .appendingPathComponent("Telemetry", isDirectory: true)
            .appendingPathComponent("Sig.swift", isDirectory: false)
        let source = try String(contentsOf: sigURL, encoding: .utf8)
        #expect(!source.contains("func interval<"),
                "Sig.swift must NOT expose closure-wrapper API (TSAN-incompatible)")
        #expect(!source.contains("func intervalAsync<"),
                "Sig.swift must NOT expose async closure-wrapper API (TSAN-incompatible)")
    }
}
