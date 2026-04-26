import Foundation
import Testing

@testable import Epistemos

/// Wave 7.17.b source-guard for the SwiftUI slash menu picker.
/// Pins the catalogue contract + the prefix-filter behaviour
/// without spinning up an XCUITest harness.
@Suite("EpdocSlashMenuView (Wave 7.17.b)")
@MainActor
struct EpdocSlashMenuViewTests {

    @Test("Default catalogue mirrors the JS DEFAULT_SLASH_ITEMS list (15 entries)")
    func defaultCatalogueSize() {
        // The JS-side catalogue at js-editor/src/extensions/slash-menu.ts
        // ships 15 entries; the Swift side MUST mirror that count so
        // an entry added on one side is added on the other.
        #expect(EpdocSlashMenuItem.defaultCatalogue.count == 15,
                "default catalogue MUST stay in sync with the JS DEFAULT_SLASH_ITEMS; got \(EpdocSlashMenuItem.defaultCatalogue.count)")
    }

    @Test("Catalogue ids are unique (no duplicate insertSlashChoice payloads)")
    func catalogueIdsUnique() {
        let ids = EpdocSlashMenuItem.defaultCatalogue.map(\.id)
        #expect(ids.count == Set(ids).count,
                "every slash-menu id MUST be unique — they're the contract for insertSlashChoice")
    }

    @Test("Catalogue ids match the JS-side slash-menu contract verbatim")
    func catalogueIdsMatchJSContract() {
        // Names mirror DEFAULT_SLASH_ITEMS in
        // js-editor/src/extensions/slash-menu.ts. Pin the exact
        // strings — divergence breaks the inbound bridge.
        let expectedIDs: Set<String> = [
            "heading-1", "heading-2", "heading-3",
            "bullet-list", "numbered-list", "task-list",
            "blockquote", "code-block",
            "math-display", "mermaid",
            "callout-tip", "callout-warning", "callout-danger",
            "table-3x3", "divider",
        ]
        let actualIDs = Set(EpdocSlashMenuItem.defaultCatalogue.map(\.id))
        #expect(actualIDs == expectedIDs,
                "Swift slash-menu ids MUST match the JS DEFAULT_SLASH_ITEMS ids exactly; got: \(actualIDs.symmetricDifference(expectedIDs))")
    }

    @Test("Empty prefix returns the full catalogue (degenerate case)")
    func emptyPrefixReturnsAll() {
        let matches = EpdocSlashMenuItem.matching(prefix: "")
        #expect(matches.count == EpdocSlashMenuItem.defaultCatalogue.count)
    }

    @Test("Prefix filter is case-insensitive on label + id")
    func prefixFilterCaseInsensitive() {
        let lowercase = EpdocSlashMenuItem.matching(prefix: "head")
        let uppercase = EpdocSlashMenuItem.matching(prefix: "HEAD")
        #expect(lowercase.map(\.id) == uppercase.map(\.id),
                "case-insensitive filter MUST yield identical results")
        #expect(lowercase.allSatisfy { $0.id.starts(with: "heading") },
                "prefix 'head' MUST surface only heading-1/2/3; got \(lowercase.map(\.id))")
    }

    @Test("Prefix matches against id even when the label differs")
    func prefixMatchesById() {
        // 'callout-tip' matches the id but the label is "Callout — Tip"
        let matches = EpdocSlashMenuItem.matching(prefix: "callout-tip")
        #expect(matches.count == 1)
        #expect(matches.first?.id == "callout-tip")
    }

    @Test("No matches returns empty (not catalogue) for a definitely-bogus prefix")
    func noMatchesEmpty() {
        let matches = EpdocSlashMenuItem.matching(prefix: "definitely-not-a-block-type-xyz")
        #expect(matches.isEmpty)
    }
}

@Suite("EpdocComplexityMeter (Wave 7.17.b)")
nonisolated struct EpdocComplexityMeterTests {

    @Test("shouldNudgeSplit fires when complexity > 0.7")
    @MainActor
    func nudgeSplitThreshold() {
        #expect(EpdocComplexityMeter(complexity: 0.0).shouldNudgeSplit == false)
        #expect(EpdocComplexityMeter(complexity: 0.5).shouldNudgeSplit == false)
        #expect(EpdocComplexityMeter(complexity: 0.7).shouldNudgeSplit == false,
                "exactly 0.7 is the boundary; only > 0.7 nudges")
        #expect(EpdocComplexityMeter(complexity: 0.71).shouldNudgeSplit == true)
        #expect(EpdocComplexityMeter(complexity: 1.0).shouldNudgeSplit == true)
    }

    @Test("Out-of-range complexity values clamp to [0, 1] for the nudge band")
    @MainActor
    func outOfRangeClamp() {
        #expect(EpdocComplexityMeter(complexity: -1.0).shouldNudgeSplit == false)
        #expect(EpdocComplexityMeter(complexity: 5.0).shouldNudgeSplit == true)
    }
}
