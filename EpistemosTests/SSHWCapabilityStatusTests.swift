import Testing
import Foundation

@testable import Epistemos

// SS-HW (owner 2026-06-20: "the html workspace does not work as well but idk if its marked as such").
// These pin the HONEST capability ledger: live means proven in-app, not merely wired in code.
// The formerly deferred HTML Workspace seams were proven on 2026-06-30: Goose regenerate,
// app bridge, console capture, DOM picker/style inspection, and build-vendored Pyodide.
@Suite("SS-HW — honest HTML Workspace capability status")
struct SSHWCapabilityStatusTests {

    @Test("the live capabilities are the real working ones")
    func liveCapabilitiesAreReal() {
        let live = HTMLWorkspaceCapabilityStatus.capabilities.filter(\.isLive).map(\.name)
        #expect(live.contains { $0.contains("editing") })
        #expect(live.contains { $0.contains("preview") })
        #expect(live.contains { $0.contains("patch") })
        #expect(live.contains { $0.contains("routes") })
        #expect(live.contains { $0.contains("data.json") })
        #expect(live.contains { $0.contains("Live-DOM outline") })
        #expect(live.contains { $0.contains("Full-surface regenerate") })
        #expect(live.contains { $0.contains("App message-bridge") })
        #expect(live.contains { $0.contains("JS console") })
        #expect(live.contains { $0.contains("DOM picker") })
        #expect(live.contains { $0.contains("Python") })
    }

    @Test("formerly deferred seams are only live with proof notes")
    func formerlyDeferredSeamsCarryProofNotes() {
        let appBridge = HTMLWorkspaceCapabilityStatus.capabilities.first { $0.name == "App message-bridge" }
        #expect(appBridge?.isLive == true)
        #expect(appBridge?.note.contains("Sandbox-gated") == true)
        let regenerate = HTMLWorkspaceCapabilityStatus.capabilities.first { $0.name == "Full-surface regenerate" }
        #expect(regenerate?.isLive == true)
        #expect(regenerate?.note.contains("Goose-only") == true)
        let python = HTMLWorkspaceCapabilityStatus.capabilities.first { $0.name == "Python (Pyodide / WASM)" }
        #expect(python?.isLive == true)
        #expect(python?.note.contains("Pyodide result: 45") == true)
    }

    @Test("counts + summary are consistent + honest")
    func countsAndSummaryConsistent() {
        let total = HTMLWorkspaceCapabilityStatus.capabilities.count
        #expect(HTMLWorkspaceCapabilityStatus.liveCount + HTMLWorkspaceCapabilityStatus.deferredCount == total)
        #expect(HTMLWorkspaceCapabilityStatus.liveCount == total)
        #expect(HTMLWorkspaceCapabilityStatus.deferredCount == 0)
        #expect(HTMLWorkspaceCapabilityStatus.summary.contains("data.json"))
        #expect(HTMLWorkspaceCapabilityStatus.summary.contains("routes"))
        #expect(HTMLWorkspaceCapabilityStatus.summary.contains("PDF export"))
        #expect(HTMLWorkspaceCapabilityStatus.summary.contains("live DOM outline"))
        #expect(HTMLWorkspaceCapabilityStatus.summary.contains("Goose"))
        #expect(HTMLWorkspaceCapabilityStatus.summary.contains("click-to-inspect"))
        #expect(HTMLWorkspaceCapabilityStatus.summary.contains("Pyodide"))
    }
}
