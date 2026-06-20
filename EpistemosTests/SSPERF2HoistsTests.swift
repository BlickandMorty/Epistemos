import Testing
import Foundation

@testable import Epistemos

// SS-PERF2 follow-ups (owner 2026-06-20):
//  • #5 hoists the MessageBubble export-filename ISO8601DateFormatter to a shared static
//    (it was allocated on every export tap; DateFormatter creation is the costly part).
//  • the SDMessage shared coders drop a redundant `nonisolated(unsafe)` — JSONDecoder /
//    JSONEncoder are Sendable in this SDK, so plain `nonisolated` is concurrency-safe and
//    warning-free.
// Both source-guarded (the formatter + coders are type-private).
@Suite("SS-PERF2 formatter hoist + coder annotation cleanup")
struct SSPERF2HoistsTests {

    @Test("MessageBubble's export-filename formatter is a shared static")
    func messageBubbleFormatterHoisted() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/Chat/MessageBubble.swift")
        #expect(src.contains("private static let exportDateFormatter = ISO8601DateFormatter()"))
        #expect(src.contains("Self.exportDateFormatter.string(from: message.createdAt)"))
        // The per-tap allocation must be gone.
        #expect(!src.contains("ISO8601DateFormatter().string(from: message.createdAt)"))
    }

    @Test("the SDMessage shared coders use plain nonisolated (no redundant unsafe)")
    func sdMessageCodersPlainNonisolated() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Models/SDMessage.swift")
        #expect(src.contains("nonisolated static let sharedDecoder = JSONDecoder()"))
        #expect(src.contains("nonisolated static let sharedEncoder = JSONEncoder()"))
        #expect(!src.contains("nonisolated(unsafe) static let sharedDecoder"))
    }
}
