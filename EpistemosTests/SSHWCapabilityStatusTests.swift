import Testing
import Foundation

@testable import Epistemos

// SS-HW (owner 2026-06-20: "the html workspace does not work as well but idk if its marked as such").
// These pin the HONEST capability ledger: the live entries are the real working ones, the deferred
// seams are marked NOT live (no fake-green), and the summary says works-but-partial rather than
// reading as complete. Verified against code (safeAPI path still no-op, console capture env-gated,
// no Pyodide, source-quad replaceDocument primitive only — no full regenerate UX).
@Suite("SS-HW — honest HTML Workspace capability status")
struct SSHWCapabilityStatusTests {

    @Test("the live capabilities are the real working ones (renderer / editor / agent-patch / data feed)")
    func liveCapabilitiesAreReal() {
        let live = HTMLWorkspaceCapabilityStatus.capabilities.filter(\.isLive).map(\.name)
        #expect(live.contains { $0.contains("editing") })
        #expect(live.contains { $0.contains("preview") })
        #expect(live.contains { $0.contains("patch") })
        #expect(live.contains { $0.contains("data.json") })
    }

    @Test("the deferred seams are honestly marked NOT live (no fake-green)")
    func deferredSeamsAreMarkedNotLive() {
        let deferred = HTMLWorkspaceCapabilityStatus.capabilities.filter { !$0.isLive }.map(\.name)
        #expect(deferred.contains { $0.contains("bridge") })       // app message-bridge is an empty stub
        #expect(deferred.contains { $0.contains("Python") })       // no Python today
        #expect(deferred.contains { $0.contains("DOM") })          // static regex, not live DOM
        #expect(deferred.contains { $0.contains("regenerate") })   // replaceDocument primitive only
    }

    @Test("counts + summary are consistent + honest (works-but-partial, never 'complete')")
    func countsAndSummaryConsistent() {
        let total = HTMLWorkspaceCapabilityStatus.capabilities.count
        #expect(HTMLWorkspaceCapabilityStatus.liveCount + HTMLWorkspaceCapabilityStatus.deferredCount == total)
        #expect(HTMLWorkspaceCapabilityStatus.liveCount > 0)        // it genuinely works as a renderer
        #expect(HTMLWorkspaceCapabilityStatus.deferredCount > 0)    // but it is NOT complete
        #expect(HTMLWorkspaceCapabilityStatus.summary.contains("data.json"))
        #expect(HTMLWorkspaceCapabilityStatus.summary.contains("console capture is wired but env-gated"))
        #expect(HTMLWorkspaceCapabilityStatus.summary.contains("deferred"))
        #expect(HTMLWorkspaceCapabilityStatus.summary.contains("regenerate UX"))
    }
}
