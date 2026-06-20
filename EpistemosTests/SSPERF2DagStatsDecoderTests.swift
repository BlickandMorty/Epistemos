import Testing
import Foundation

@testable import Epistemos

// SS-PERF2 #8 (owner 2026-06-20 deep-research): RustCognitiveDagClient.stats() — polled by
// SubstrateHealthClock — no longer allocates a fresh JSONDecoder() per call; it reuses one
// shared default-configured decoder. Source-guarded (stats() needs the agent_coreFFI
// import + a live FFI). No behaviour change.
@Suite("SS-PERF2 DAG stats decoder hoist")
struct SSPERF2DagStatsDecoderTests {

    @Test("RustCognitiveDagClient reuses a shared stats decoder")
    func statsDecoderHoisted() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/RustCognitiveDagClient.swift")
        #expect(src.contains("static let statsDecoder = JSONDecoder()"))
        #expect(src.contains("return try Self.statsDecoder.decode("))
    }

    @Test("stats() no longer allocates a JSONDecoder per call")
    func noPerCallDecoderAlloc() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Engine/RustCognitiveDagClient.swift")
        #expect(!src.contains("return try JSONDecoder().decode("))
    }
}
