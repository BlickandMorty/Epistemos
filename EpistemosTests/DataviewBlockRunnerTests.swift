import Foundation
import Testing

@testable import Epistemos

/// #41: proves DataviewBlockRunner.dataviewDQL — the pure block-extraction seam that gates the
/// "Run Dataview Query" context-menu action. This is the part the editor UI can't exercise headless,
/// so it is verified here directly (no SwiftData needed — extraction is pure text).
@MainActor
@Suite("DataviewBlockRunner — DQL block extraction")
struct DataviewBlockRunnerTests {

    /// UTF-16 offset of `needle` in `text` (matches the NSString offsets dataviewDQL uses).
    private func index(of needle: String, in text: String) -> Int {
        (text as NSString).range(of: needle).location
    }

    @Test("extracts the DQL body when the location is inside a ```dataview block")
    func extractsBody() {
        let text = "# Note\n```dataview\nTABLE file.mtime FROM \"Projects\"\n```\nafter\n"
        let idx = index(of: "TABLE", in: text)
        #expect(
            DataviewBlockRunner.dataviewDQL(in: text, at: idx)
                == "TABLE file.mtime FROM \"Projects\"")
    }

    @Test("extracts a multi-line DQL body")
    func extractsMultiline() {
        let text = "```dataview\nLIST\nFROM #tag\n```\n"
        let idx = index(of: "FROM", in: text)
        #expect(DataviewBlockRunner.dataviewDQL(in: text, at: idx) == "LIST\nFROM #tag")
    }

    @Test("info string match is case-insensitive (```DATAVIEW)")
    func caseInsensitive() {
        let text = "```DATAVIEW\nTASK\n```\n"
        let idx = index(of: "TASK", in: text)
        #expect(DataviewBlockRunner.dataviewDQL(in: text, at: idx) == "TASK")
    }

    @Test("returns nil for a non-dataview fenced block (```swift)")
    func ignoresSwiftFence() {
        let text = "```swift\nlet x = 1\n```\n"
        let idx = index(of: "let", in: text)
        #expect(DataviewBlockRunner.dataviewDQL(in: text, at: idx) == nil)
    }

    @Test("returns nil for a plain ``` fenced block")
    func ignoresPlainFence() {
        let text = "```\nplain\n```\n"
        let idx = index(of: "plain", in: text)
        #expect(DataviewBlockRunner.dataviewDQL(in: text, at: idx) == nil)
    }

    @Test("returns nil when the location is outside any fenced block")
    func nilOutsideBlock() {
        let text = "# Note\n```dataview\nTABLE\n```\nafter\n"
        let idx = index(of: "after", in: text)
        #expect(DataviewBlockRunner.dataviewDQL(in: text, at: idx) == nil)
    }

    @Test("selects the correct block when several are present")
    func selectsCorrectBlock() {
        let text = "```swift\ncode\n```\n\n```dataview\nLIST\n```\n"
        #expect(DataviewBlockRunner.dataviewDQL(in: text, at: index(of: "code", in: text)) == nil)
        #expect(DataviewBlockRunner.dataviewDQL(in: text, at: index(of: "LIST", in: text)) == "LIST")
    }

    @Test("returns nil for empty text or out-of-range location")
    func nilEmptyOrOutOfBounds() {
        #expect(DataviewBlockRunner.dataviewDQL(in: "", at: 0) == nil)
        #expect(DataviewBlockRunner.dataviewDQL(in: "```dataview\nX\n```", at: 9999) == nil)
    }
}
