import Testing
import Foundation

@testable import Epistemos

// SS-PERF2 follow-up (owner 2026-06-20):
//  • the SDMessage shared coders drop a redundant `nonisolated(unsafe)` — JSONDecoder /
//    JSONEncoder are Sendable in this SDK, so plain `nonisolated` is concurrency-safe and
//    warning-free.
// Source-guarded because the coders are type-private.
@Suite("SS-PERF2 coder annotation cleanup")
struct SSPERF2HoistsTests {

    @Test("the SDMessage shared coders use plain nonisolated (no redundant unsafe)")
    func sdMessageCodersPlainNonisolated() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Models/SDMessage.swift")
        #expect(src.contains("nonisolated static let sharedDecoder = JSONDecoder()"))
        #expect(src.contains("nonisolated static let sharedEncoder = JSONEncoder()"))
        #expect(!src.contains("nonisolated(unsafe) static let sharedDecoder"))
    }
}
