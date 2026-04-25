import Foundation
import Testing

@testable import Epistemos

// MARK: - Sig Tests
//
// Sprint 0 (Wave 2.1) signpost facade tests.
// Per docs/EPISTEMOS_DETERMINISTIC_PERF_PLAN.md §1.1 Task 0.1.
//
// Covers:
// - Sig defines all 6 canonical OSSignposters (render/mcp/graph/ffi/storage/inference)
// - Sig.interval forwards the body's return value
// - Sig.intervalAsync forwards the body's return value with async support
// - Sig.swift source file exists at the canonical path

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

    // MARK: - Interval body forwarding

    @Test func intervalReturnsBodyValue() {
        let result = Sig.interval(Sig.storage, "search") { 42 }
        #expect(result == 42)
    }

    @Test func intervalForwardsThrows() {
        struct E: Error {}
        #expect(throws: E.self) {
            try Sig.interval(Sig.ffi, "poll_event") { () throws -> Int in
                throw E()
            }
        }
    }

    @Test func intervalAsyncReturnsBodyValue() async {
        let result = await Sig.intervalAsync(Sig.inference, "generate") {
            return "ok"
        }
        #expect(result == "ok")
    }

    @Test func intervalAsyncForwardsThrows() async {
        struct E: Error {}
        await #expect(throws: E.self) {
            try await Sig.intervalAsync(Sig.mcp, "agent_session") { () async throws -> Int in
                throw E()
            }
        }
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
}
