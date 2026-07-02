import Foundation
import Testing

@testable import Epistemos

/// Wave 7.17.b source-guard for the SwiftUI slash menu picker.
/// Pins the catalogue contract + the prefix-filter behaviour
/// without spinning up an XCUITest harness.
@Suite("EpdocSlashMenuView (Wave 7.17.b)")
@MainActor
struct EpdocSlashMenuViewTests {

    @Test("Default catalogue mirrors the JS DEFAULT_SLASH_ITEMS list (19 entries)")
    func defaultCatalogueSize() {
        // The JS-side catalogue at js-editor/src/extensions/slash-menu.ts
        // ships 19 entries; the Swift side MUST mirror that count so
        // an entry added on one side is added on the other.
        #expect(EpdocSlashMenuItem.defaultCatalogue.count == 19,
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
            "math-display", "html-workspace",
            "chart-scatter", "chart-bar", "chart-line",
            "callout-tip", "callout-warning", "callout-danger",
            "table-3x3", "image", "divider",
        ]
        let actualIDs = Set(EpdocSlashMenuItem.defaultCatalogue.map(\.id))
        #expect(actualIDs == expectedIDs,
                "Swift slash-menu ids MUST match the JS DEFAULT_SLASH_ITEMS ids exactly; got: \(actualIDs.symmetricDifference(expectedIDs))")
    }

    @Test("HTML Workspace replaces new Mermaid diagram creation in the slash menu")
    func htmlWorkspaceReplacesMermaidCreation() {
        let item = EpdocSlashMenuItem.defaultCatalogue.first { $0.id == "html-workspace" }
        let ids = EpdocSlashMenuItem.defaultCatalogue.map(\.id)
        #expect(item?.label == "HTML Workspace")
        #expect(!ids.contains("mermaid"))
        #expect(!ids.contains { $0.hasPrefix("mermaid-") })
    }

    @Test("Slash image insertion defaults to package-local assets")
    func slashImageInsertionUsesPackageLocalAssetBridge() throws {
        let item = EpdocSlashMenuItem.defaultCatalogue.first { $0.id == "image" }
        #expect(item?.label == "Local image")

        let slashMenuSource = try loadMirroredSourceTextFile("js-editor/src/extensions/slash-menu.ts")
        let assetBridgeSource = try loadMirroredSourceTextFile("js-editor/src/extensions/image-asset-bridge.ts")

        #expect(slashMenuSource.contains("requestPackageImageAssetFromPicker"))
        #expect(assetBridgeSource.contains("export function requestPackageImageAssetFromPicker"))
        #expect(!slashMenuSource.contains("window.prompt('Image URL')"))
        #expect(!slashMenuSource.contains("insertEpdocImage({ src, alt: '' })"))
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

@Suite("EpdocAgentTokenCounter")
nonisolated struct EpdocAgentTokenCounterTests {

    @Test("token estimate prefers the live Markdown snapshot")
    @MainActor
    func tokenEstimatePrefersLiveMarkdownSnapshot() {
        let estimate = EpdocAgentTokenEstimate.estimate(
            markdown: "123456789",
            fallbackWordCount: 100,
            fallbackCharacterCount: 600
        )
        #expect(estimate.tokens == 3)
        #expect(estimate.source == .markdown)
        #expect(estimate.compactCountText == "3")
    }

    @Test("token estimate falls back to document stats")
    @MainActor
    func tokenEstimateFallsBackToDocumentStats() {
        let estimate = EpdocAgentTokenEstimate.estimate(
            markdown: "   ",
            fallbackWordCount: 1200,
            fallbackCharacterCount: 0
        )
        #expect(estimate.tokens == 1500)
        #expect(estimate.source == .documentStats)
        #expect(estimate.compactCountText == "1.5k")
    }

    @Test("Epdoc toolbar uses token counter instead of complexity meter")
    func toolbarUsesTokenCounterInsteadOfComplexityMeter() throws {
        let chrome = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocEditorChromeView.swift")
        let meter = try loadMirroredSourceTextFile("Epistemos/Views/Epdoc/EpdocComplexityMeter.swift")

        #expect(chrome.contains("EpdocAgentTokenCounter("))
        #expect(chrome.contains("latestMarkdownSnapshot"))
        #expect(!chrome.contains("EpdocComplexityMeter("))
        #expect(meter.contains("public struct EpdocAgentTokenCounter"))
        #expect(meter.contains("public struct EpdocAgentTokenEstimate"))
        #expect(!meter.contains("public struct EpdocComplexityMeter"))
    }
}
