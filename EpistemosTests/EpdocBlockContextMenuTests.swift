import Foundation
import Testing

@testable import Epistemos

/// Wave 7.17.b source-guard for the right-click block context menu.
@Suite("EpdocBlockContextMenu (Wave 7.17.b)")
@MainActor
struct EpdocBlockContextMenuTests {

    @Test("convertCandidates excludes the active block kind so users can't no-op convert")
    func convertCandidatesExcludeActive() {
        let menu = EpdocBlockContextMenu(blockKind: "paragraph")
        let candidateIDs = menu.convertCandidates.map(\.0)
        #expect(!candidateIDs.contains("paragraph"),
                "active block kind 'paragraph' MUST be filtered out; got \(candidateIDs)")
    }

    @Test("convertCandidates surfaces every other block type")
    func convertCandidatesAreComplete() {
        let menu = EpdocBlockContextMenu(blockKind: "paragraph")
        let candidateIDs = Set(menu.convertCandidates.map(\.0))
        let expected: Set<String> = [
            "heading-1", "heading-2", "heading-3",
            "blockquote", "code-block",
            "bullet-list", "numbered-list", "task-list",
            "math-display", "mermaid",
        ]
        #expect(candidateIDs == expected,
                "convert candidates must cover every other block type; got: \(candidateIDs.symmetricDifference(expected))")
    }

    @Test("Each block kind sees a different convert-candidate set")
    func convertCandidatesPerKind() {
        let paraMenu = EpdocBlockContextMenu(blockKind: "paragraph")
        let codeMenu = EpdocBlockContextMenu(blockKind: "code-block")
        let paraIDs = Set(paraMenu.convertCandidates.map(\.0))
        let codeIDs = Set(codeMenu.convertCandidates.map(\.0))
        #expect(paraIDs.contains("code-block"))
        #expect(!paraIDs.contains("paragraph"))
        #expect(codeIDs.contains("paragraph"))
        #expect(!codeIDs.contains("code-block"))
    }
}
