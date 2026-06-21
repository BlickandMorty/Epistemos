import Testing
import Foundation
import CoreSpotlight

@testable import Epistemos

// SpotlightIndexer.makeItem is what makes a note searchable in macOS Spotlight. These pin its behavior
// (constructing a CSSearchableItem needs no entitlement, so it runs headlessly): the identifier
// round-trips, the title is set, the body is trimmed to 280 chars — the documented corespotlightd
// memory invariant (a regression to a larger prefix silently regresses 30-50 MB on a 5K-note vault) —
// and tags drive keywords + contentDescription.
@Suite("SpotlightIndexer.makeItem")
struct SpotlightIndexerMakeItemTests {

    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("a long body is trimmed to 280 chars (the corespotlightd memory invariant)")
    func bodyTrimmedTo280() {
        let longBody = String(repeating: "x", count: 500)
        let item = SpotlightIndexer.makeItem(
            pageId: "page-1", title: "My Note", tags: ["alpha", "beta"], tagsJoined: "alpha, beta",
            createdAt: epoch, updatedAt: epoch, body: longBody
        )
        #expect(item.attributeSet.textContent?.count == 280)
        #expect(item.attributeSet.textContent == String(longBody.prefix(280)))
    }

    @Test("identifier + title + keywords round-trip; tags drive contentDescription")
    func attributesMapped() {
        let item = SpotlightIndexer.makeItem(
            pageId: "page-42", title: "Essay", tags: ["research", "vault"], tagsJoined: "research, vault",
            createdAt: epoch, updatedAt: epoch, body: "short"
        )
        #expect(item.uniqueIdentifier == "page-42")
        #expect(item.attributeSet.title == "Essay")
        #expect(item.attributeSet.keywords == ["research", "vault"])
        #expect(item.attributeSet.contentDescription == "Tags: research, vault")
        #expect(item.attributeSet.textContent == "short")  // a short body is untouched (no trim)
    }

    @Test("with no tags, contentDescription falls back to the title and keywords are empty")
    func noTagsContentDescriptionIsTitle() {
        let item = SpotlightIndexer.makeItem(
            pageId: "p", title: "Untagged", tags: [], tagsJoined: "",
            createdAt: epoch, updatedAt: epoch, body: "body"
        )
        #expect(item.attributeSet.contentDescription == "Untagged")
        #expect(item.attributeSet.keywords?.isEmpty ?? true)
    }
}
