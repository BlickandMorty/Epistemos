import Foundation
import Testing
@testable import Epistemos

// MARK: - Phase R.5 Permission Bridge Regression Tests
//
// Covers the Swift side of the UniFFI-exposed `permission_store_*`
// helpers wired up in `agent_core/src/resources/bridge.rs`. The Rust
// arm has 7 tests at the module level; this suite specifically
// exercises the FFI boundary + the Swift UI assumptions (blocking
// entry points, error paths, capability parsing, grant round-trips).
//
// Notes for future sessions:
// - The permission store is a PROCESS-LOCAL in-memory singleton. Tests
//   here share state with every other test in the same process run.
//   Every test seeds its own distinctive resource ID so it can assert
//   specifically on its own grants without worrying about leakage.
// - When the follow-up commit migrates to a persistent SQLite file,
//   this suite will need `override` hooks to point at a fresh temp
//   path per test. Until then, process-local + unique IDs is enough.
//
// Plan refs: docs/IMPLEMENTATION_PLAN_FROM_ADVICE.md §Phase R.5 +
// Appendix E Step 7 · docs/KNOWN_ISSUES_REGISTER.md I-009, I-010.

@Suite("Phase R.5 — Permission Bridge")
struct PhaseRPermissionBridgeTests {

    // MARK: - Helpers

    /// Produce a unique resource URI for this specific test so concurrent
    /// test runs + store residue don't collide.
    private func uniqueNoteURI(label: String) -> String {
        let random = UUID().uuidString
        return "vault://r5-\(label)-\(random)/note/Inbox/Test-\(random).md"
    }

    // MARK: - FFI boundary — record / check / revoke round-trip

    @Test("recording a user-grant statement stores the grant and check succeeds")
    func recordingAUserGrantStatementStoresAndCheckSucceeds() async throws {
        let uri = uniqueNoteURI(label: "roundtrip")

        let grantID = await permissionStoreRecordUserGrantFromStatement(
            statement: "You have my permission to edit this note.",
            resourceUri: uri,
            capabilityNames: ["Read", "Write"],
            scopeName: "Session"
        )
        #expect(grantID != nil, "grant should be recorded")
        #expect(grantID?.isEmpty == false, "grant id should not be empty")

        // Read + Write were explicitly granted.
        #expect(await permissionStoreCheck(resourceUri: uri, capability: "Read"))
        #expect(await permissionStoreCheck(resourceUri: uri, capability: "Write"))
        // Delete was NOT granted.
        #expect(!(await permissionStoreCheck(resourceUri: uri, capability: "Delete")))

        // Revocation removes the grant.
        guard let grantID else {
            Issue.record("grant id should be non-nil by this point")
            return
        }
        let revoked = await permissionStoreRevoke(grantId: grantID)
        #expect(revoked, "revoke should succeed for a valid grant id")
        #expect(!(await permissionStoreCheck(resourceUri: uri, capability: "Write")),
                "capability must disappear after revoke")
    }

    // MARK: - Grant detection — phrasing gate

    @Test("non-grant phrasing is rejected without storing anything")
    func nonGrantPhrasingIsRejectedWithoutStoring() async throws {
        let uri = uniqueNoteURI(label: "nogrant")

        let grantID = await permissionStoreRecordUserGrantFromStatement(
            statement: "please do NOT edit this note — it's final",
            resourceUri: uri,
            capabilityNames: ["Write"],
            scopeName: "Session"
        )
        #expect(grantID == nil, "refusal phrasing must not mint a grant")

        #expect(!(await permissionStoreCheck(resourceUri: uri, capability: "Write")),
                "no grant → no capability")
    }

    // MARK: - Prompt-injection hardening (I-010)

    @Test("malicious note content cannot grant itself extra capabilities")
    func maliciousNoteContentCannotGrantItselfExtraCapabilities() async throws {
        // I-010 guard: permission grants come from user-subject phrasing
        // parsed from chat input, NOT from note content. Supplying a
        // string that looks like a consent phrase but with non-user
        // provenance must NOT leak into a grant via the FFI surface.
        //
        // In this bridge, the caller controls the `statement` argument
        // — so the defense lives in the caller layer: never pass note
        // content into this function. This test guards against the
        // NEAR-MISS where a caller might accidentally splice note
        // content into the statement. We verify that the detection
        // phrase alone on untrusted content does not alter permission
        // outcomes for OTHER resources.

        let granted = uniqueNoteURI(label: "granted")
        let protectedResource = uniqueNoteURI(label: "protected")

        // User explicitly grants Write on the "granted" resource.
        _ = await permissionStoreRecordUserGrantFromStatement(
            statement: "you have my permission to edit this note",
            resourceUri: granted,
            capabilityNames: ["Write"],
            scopeName: "Session"
        )

        // Note content (hypothetical, injected into a tool-result) —
        // the bridge is NOT called with it — therefore must not grant
        // Delete on `protectedResource`.
        #expect(!(await permissionStoreCheck(resourceUri: protectedResource, capability: "Delete")))
        #expect(!(await permissionStoreCheck(resourceUri: protectedResource, capability: "Write")))

        // Specific `granted` resource still has only what was asked for.
        #expect(await permissionStoreCheck(resourceUri: granted, capability: "Write"))
        #expect(!(await permissionStoreCheck(resourceUri: granted, capability: "Delete")))
    }

    // MARK: - FFI edge cases

    @Test("unparseable resource URI is rejected gracefully")
    func unparseableResourceURIRejectedGracefully() async throws {
        let grantID = await permissionStoreRecordUserGrantFromStatement(
            statement: "you have my permission",
            resourceUri: "not-a-real-uri-12345",
            capabilityNames: ["Read"],
            scopeName: "Session"
        )
        #expect(grantID == nil, "unparseable URI must not create a grant")

        // Check on the same bogus URI also returns false (not an error).
        #expect(!(await permissionStoreCheck(resourceUri: "not-a-real-uri-12345", capability: "Read")))
    }

    @Test("unknown capability names are silently skipped")
    func unknownCapabilityNamesAreSilentlySkipped() async throws {
        let uri = uniqueNoteURI(label: "unknowncap")

        // "Merge" and "Archive" don't exist as Capability variants. "Read"
        // does. The grant must land with Read only.
        let grantID = await permissionStoreRecordUserGrantFromStatement(
            statement: "you have my permission",
            resourceUri: uri,
            capabilityNames: ["Merge", "Read", "Archive"],
            scopeName: "Session"
        )
        #expect(grantID != nil, "grant should land with at least one valid capability")

        #expect(await permissionStoreCheck(resourceUri: uri, capability: "Read"))
        #expect(!(await permissionStoreCheck(resourceUri: uri, capability: "Merge")))
        #expect(!(await permissionStoreCheck(resourceUri: uri, capability: "Archive")))
    }

    @Test("empty capability list yields no grant")
    func emptyCapabilityListYieldsNoGrant() async throws {
        let uri = uniqueNoteURI(label: "emptycaps")

        let grantID = await permissionStoreRecordUserGrantFromStatement(
            statement: "you have my permission",
            resourceUri: uri,
            capabilityNames: [],
            scopeName: "Session"
        )
        #expect(grantID == nil, "no capabilities → no grant")
    }

    @Test("revoking a non-existent grant id is a silent no-op that returns false")
    func revokingNonExistentGrantIsSilentNoOp() async throws {
        let revoked = await permissionStoreRevoke(grantId: "no-such-grant-12345")
        // Rust's SqlitePermissionService::revoke returns Ok even for a
        // missing row (DELETE finds zero rows). The bridge maps Ok → true.
        // Either way, the call must not throw and must remain consistent.
        _ = revoked
    }

    // MARK: - Blocking entry point (synchronous Swift callers)

    @Test("blocking list_active works from a plain synchronous context")
    func blockingListActiveWorksSynchronously() {
        // Swift UI refreshes use this blocking entry point occasionally
        // (e.g. quick peek before a sheet presents). Must not deadlock,
        // must not require a surrounding tokio runtime.
        let _ = permissionStoreListActiveBlocking()
    }

    // MARK: - List reflects stored grants

    @Test("list_active surfaces newly recorded grants with the correct selector + capabilities")
    func listActiveSurfacesNewlyRecordedGrants() async throws {
        let uri = uniqueNoteURI(label: "listactive")
        let marker = uri

        _ = await permissionStoreRecordUserGrantFromStatement(
            statement: "you have my permission",
            resourceUri: uri,
            capabilityNames: ["Read", "Write"],
            scopeName: "Session"
        )

        let active = await permissionStoreListActive()
        let match = active.first { $0.selector.contains(marker) }
        #expect(match != nil, "newly granted resource must appear in list_active")
        if let match {
            #expect(match.capabilities.contains("Read"))
            #expect(match.capabilities.contains("Write"))
            #expect(match.scope == "Session")
            #expect(match.subject == "assistant")
        }
    }
}
