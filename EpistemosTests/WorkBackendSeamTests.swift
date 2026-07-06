import Testing
import Foundation
@testable import Epistemos

/// Work backend seam guard. Locks the isolated Work-backend seam: the MAS/Pro
/// boundary, the honest INERT posture (no fake capability, no silent fallback),
/// and the Chat/Act isolation boundary.
@Suite("Work backend seam — isolated, Pro-gated")
struct WorkBackendSeamTests {

    @Test("gate flag is honest + off by default")
    func gateHonest() {
        #expect(WorkBackendGateStatus.flagName == "EPISTEMOS_WORK_BACKEND_V0")
        #expect(WorkBackendGateStatus.isEnabled("1"))
        #expect(WorkBackendGateStatus.isEnabled(" On "))
        #expect(!WorkBackendGateStatus.isEnabled(nil))
        #expect(!WorkBackendGateStatus.isEnabled("0"))
        let off = WorkBackendGateStatus.status(environment: [:])
        #expect(!off.isActive)
        #expect(off.detail.contains("EPISTEMOS_WORK_BACKEND_V0") || off.headline.contains("Pro only"))
    }

    @Test("MAS/Pro boundary: the Work backend is Pro-gated; the gate + row are always-compiled")
    func boundaryIntact() throws {
        let backend = try loadMirroredSourceTextFile("Epistemos/Work/WorkBackend.swift")
        #expect(backend.contains("#if !EPISTEMOS_APP_STORE"))
        #expect(backend.contains("protocol WorkBackend"))
        #expect(backend.contains("throw WorkBackendError.engineNotWired"))   // honest refusal
        let gate = try loadMirroredSourceTextFile("Epistemos/Work/WorkBackendGateStatus.swift")
        #expect(gate.contains("nonisolated enum WorkBackendGateStatus"))
        // The gate enum is NOT wrapped in the Pro-only boundary (MAS shows the honest state).
        #expect(!gate.contains("#if !EPISTEMOS_APP_STORE\nnonisolated enum WorkBackendGateStatus"))
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        #expect(panel.contains("WorkBackendHealthRow()"))
    }

    @Test("the Work seam is isolated from chat and act")
    func guardrailChatActUnchanged() throws {
        let mode = try loadMirroredSourceTextFile("Epistemos/Engine/CoworkChatMode.swift")
        // No `.work` case was added to the Chat/Act depth model — Work is a SEPARATE,
        // isolated backend seam, so Chat/Act stay exactly as they were.
        #expect(mode.contains("case chat"))
        #expect(mode.contains("case act"))
        #expect(!mode.contains("case work"))
        // The Work seam doesn't reach into the Chat/Act dispatch.
        let backend = try loadMirroredSourceTextFile("Epistemos/Work/WorkBackend.swift")
        #expect(!backend.contains("CoworkChatMode"))
        #expect(!backend.contains("ChatCoordinator"))
    }

    @Test("Work backend source stays OpenCode-era and does not reintroduce Goose")
    func workBackendSourceDoesNotReintroduceGoose() throws {
        let backend = try loadMirroredSourceTextFile("Epistemos/Work/WorkBackend.swift")
        let gate = try loadMirroredSourceTextFile("Epistemos/Work/WorkBackendGateStatus.swift")
        let engines = try loadMirroredSourceTextFile("Epistemos/Work/WorkEnginesPanelView.swift")
        #expect(!backend.lowercased().contains("goose"))
        #expect(!gate.lowercased().contains("goose"))
        #expect(!engines.lowercased().contains("goose"))
    }

    #if !EPISTEMOS_APP_STORE
    @Test("the INERT Work backend is honest — not live, no capabilities, refuses to run")
    func inertHonest() async {
        let inert = InertWorkBackend()
        #expect(!inert.isLive)
        #expect(inert.capabilities.isEmpty)
        do {
            _ = try await inert.runWorkSession(objective: "x", workspace: URL(fileURLWithPath: "/tmp"))
            Issue.record("expected engineNotWired — Work must never silently fall back")
        } catch let error as WorkBackendError {
            #expect(error == .engineNotWired)
        } catch {
            Issue.record("wrong error type: \(error)")
        }
    }
    #endif
}
