import Foundation
import Testing
@testable import Epistemos

// MARK: - Phase R.5 Chat Grant-Wiring Regression Tests
//
// Covers the Swift side of the R.5 parser hook added to
// `ChatCoordinator.handleQuery(_:pipeline:chatState:operatingMode:)`.
// The hook walks the current turn's `pendingContextAttachments`,
// filters to the ones carrying a Phase R.4 `resourceURI`, and fires
// `permissionStoreRecordUserGrantFromStatement` (fire-and-forget) per
// resource so consent phrasing lands as a real grant in the Rust
// permission store instead of evaporating as chat text (I-009).
//
// This suite tests the READ-SIDE only: the URI filter that decides
// which attachments are grant-eligible, and a smoke test that the FFI
// contract matches the caller's assumptions. The WRITE-SIDE (tool-
// execution gate) is a follow-up commit and tested separately once it
// lands.
//
// Scope:
//   - `ChatCoordinator.r5ResourceURIsForGrant(from:)` — pure filter
//   - smoke: FFI accepts a URI from a ContextAttachment built the
//     same way the dropdown builder does in production
//
// Plan refs: docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md §Phase R.5 ·
// docs/KNOWN_ISSUES_REGISTER.md I-009.

@Suite("Phase R.5 — Chat Grant Wiring")
struct PhaseR5ChatGrantWiringTests {

    // MARK: - URI filter

    @Test("attachments without resourceURI are dropped by the grant filter")
    func legacyAttachmentsAreDropped() async throws {
        let legacy = ContextAttachment(
            kind: .note,
            targetId: "page-legacy",
            title: "Legacy Note"
        )
        let extracted = ChatCoordinator.r5ResourceURIsForGrant(from: [legacy])
        #expect(extracted.isEmpty)
    }

    @Test("attachments with empty or whitespace resourceURI are dropped")
    func emptyURIsAreDropped() async throws {
        let empty = ContextAttachment(
            kind: .note,
            targetId: "page-empty",
            title: "Empty URI",
            resourceURI: ""
        )
        let whitespace = ContextAttachment(
            kind: .note,
            targetId: "page-ws",
            title: "Whitespace URI",
            resourceURI: "   \n  "
        )
        let extracted = ChatCoordinator.r5ResourceURIsForGrant(
            from: [empty, whitespace]
        )
        #expect(extracted.isEmpty)
    }

    @Test("attachments with real resourceURI are returned in input order")
    func resourceURIsAreReturnedInOrder() async throws {
        let first = ContextAttachment(
            kind: .note,
            targetId: "page-first",
            title: "First",
            resourceURI: "vault://r5-wire/note/Inbox/First.md"
        )
        let second = ContextAttachment(
            kind: .note,
            targetId: "page-second",
            title: "Second",
            resourceURI: "file:///tmp/r5-wire-second.md"
        )
        let extracted = ChatCoordinator.r5ResourceURIsForGrant(
            from: [first, second]
        )
        #expect(extracted == [
            "vault://r5-wire/note/Inbox/First.md",
            "file:///tmp/r5-wire-second.md",
        ])
    }

    @Test("mixed batch keeps only the resource-bearing attachments in order")
    func mixedBatchFiltersInOrder() async throws {
        let legacy = ContextAttachment(
            kind: .note,
            targetId: "page-legacy",
            title: "Legacy"
        )
        let withURI = ContextAttachment(
            kind: .note,
            targetId: "page-withuri",
            title: "With URI",
            resourceURI: "vault://r5-mixed/note/Inbox/Middle.md"
        )
        let emptyURI = ContextAttachment(
            kind: .note,
            targetId: "page-emptyuri",
            title: "Empty URI",
            resourceURI: ""
        )
        let extracted = ChatCoordinator.r5ResourceURIsForGrant(
            from: [legacy, withURI, emptyURI]
        )
        #expect(extracted == ["vault://r5-mixed/note/Inbox/Middle.md"])
    }

    // MARK: - Capability/scope constants match the Rust bridge

    @Test("candidate capabilities cover the full Capability enum")
    func candidateCapabilitiesCoverTheFullEnum() async throws {
        // Keep this in lock-step with `agent_core::resources::attachments::Capability`
        // — if a new variant lands on the Rust side, it must be added
        // here too or user grants for it will silently never fire.
        let candidates = Set(ChatCoordinator.r5GrantCandidateCapabilities)
        #expect(candidates == ["Read", "Write", "Create", "Delete", "Search"])
    }

    @Test("grant scope uses the Session label the Rust parser recognizes")
    func grantScopeIsSession() async throws {
        #expect(ChatCoordinator.r5GrantScope == "Session")
    }

    // MARK: - Smoke: FFI accepts the same URI shape the filter produces

    @Test("URI produced by the filter round-trips through the Rust grant parser")
    func uriFromFilterIsAcceptedByBridge() async throws {
        // End-to-end wire check: take a ContextAttachment populated like
        // production (dropdown → Phase R.4 manifest), extract its URI via
        // the pure filter, and hand that URI to the grant FFI. If the
        // contract is intact we get a non-nil grant_id for a grant-shaped
        // statement.
        let uniqueURI = "vault://r5-wire-smoke-\(UUID().uuidString)/note/Inbox/WireSmoke.md"
        let attachment = ContextAttachment(
            kind: .note,
            targetId: "page-wire-smoke",
            title: "Wire Smoke",
            subtitle: nil,
            resourceURI: uniqueURI,
            resourceMode: .live,
            resourceCapabilities: ["Read", "Write"]
        )
        let extracted = ChatCoordinator.r5ResourceURIsForGrant(from: [attachment])
        #expect(extracted == [uniqueURI])

        let grantID = await permissionStoreRecordUserGrantFromStatement(
            statement: "You have my permission to edit this note.",
            resourceUri: uniqueURI,
            capabilityNames: ChatCoordinator.r5GrantCandidateCapabilities,
            scopeName: ChatCoordinator.r5GrantScope
        )
        #expect(grantID != nil, "grant-shaped statement + valid URI should mint a grant")
        #expect(grantID?.isEmpty == false)
        // Clean up so we don't pollute the shared process-local store
        // (other suites enumerate grants).
        if let grantID {
            _ = await permissionStoreRevoke(grantId: grantID)
        }
    }
}
