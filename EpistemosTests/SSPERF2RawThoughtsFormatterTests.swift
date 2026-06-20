import Testing
import Foundation

@testable import Epistemos

// SS-PERF2 #3 (owner 2026-06-20 deep-research): RawThoughtsSection.groupedByDate no longer
// allocates a fresh DateFormatter() on every call (it runs each time `content` re-renders
// while the panel is open during runs). The formatter is hoisted to one shared static —
// DateFormatter creation is the dominant cost; the bucketing loop is cheap. Source-guarded
// (the formatter + grouping are view-private). No behaviour change.
@Suite("SS-PERF2 RawThoughts formatter hoist")
struct SSPERF2RawThoughtsFormatterTests {

    @Test("the day-grouping DateFormatter is hoisted to a shared static")
    func dateFormatterHoisted() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/RawThoughts/RawThoughtsSection.swift")
        #expect(src.contains("private static let dateGroupFormatter: DateFormatter"))
        #expect(src.contains("let formatter = Self.dateGroupFormatter"))
    }

    @Test("groupedByDate no longer allocates a DateFormatter per call")
    func noPerCallFormatterAlloc() throws {
        let src = try loadMirroredSourceTextFile("Epistemos/Views/RawThoughts/RawThoughtsSection.swift")
        // The only DateFormatter() construction left is the static initializer; the inline
        // `let formatter = DateFormatter()` inside groupedByDate must be gone.
        #expect(!src.contains("        let formatter = DateFormatter()"))
    }
}
