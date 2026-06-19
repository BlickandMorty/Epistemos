import Testing
import Foundation
@testable import Epistemos

/// Goose=WORK — Seam A guard. Locks the isolated Work-backend seam: a ProvenanceGate-
/// clean start (no Goose code yet), the MAS/Pro boundary, the honest INERT posture
/// (no fake capability, no silent fallback), and the GOOSE GUARDRAIL (Chat/Act
/// untouched).
@Suite("Goose Work backend seam (R-GOOSE) — isolated, Pro-gated")
struct WorkBackendSeamTests {

    @Test("gate flag is honest + off by default")
    func gateHonest() {
        #expect(WorkBackendGateStatus.flagName == "EPISTEMOS_WORK_GOOSE_V0")
        #expect(WorkBackendGateStatus.isEnabled("1"))
        #expect(WorkBackendGateStatus.isEnabled(" On "))
        #expect(!WorkBackendGateStatus.isEnabled(nil))
        #expect(!WorkBackendGateStatus.isEnabled("0"))
        let off = WorkBackendGateStatus.status(environment: [:])
        #expect(!off.isActive)
        #expect(off.detail.contains("EPISTEMOS_WORK_GOOSE_V0") || off.headline.contains("Pro only"))
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

    @Test("GOOSE GUARDRAIL: the Work seam is ISOLATED — Chat (Epistemos) / Act (Osaurus) are untouched")
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

    /// Honest-Handle FFI doctrine — cross-runtime flag parity. The Swift gate and the
    /// Rust Work seam MUST read the exact same env-var name, or Swift arms one flag
    /// while Rust reads another and the seam silently breaks. Read BOTH sources and
    /// prove they agree (so a rename on either side fails CI, not in the field), and
    /// lock the Rust seam's honest INERT posture + Apache-2.0 ProvenanceGate from here.
    @Test("cross-runtime parity: Swift flagName == Rust WORK_GOOSE_FLAG; Rust seam stays inert + Apache-2.0")
    func crossRuntimeFlagParityWithRustSeam() throws {
        let rust = try loadMirroredSourceTextFile("agent_core/src/work.rs")
        // Extract the Rust constant literal: pub const WORK_GOOSE_FLAG: &str = "…";
        guard let opening = rust.range(of: #"WORK_GOOSE_FLAG: &str = ""#),
              let closing = rust.range(of: "\"", range: opening.upperBound..<rust.endIndex) else {
            Issue.record("could not find the WORK_GOOSE_FLAG literal in agent_core/src/work.rs")
            return
        }
        let rustFlag = String(rust[opening.upperBound..<closing.lowerBound])
        #expect(
            rustFlag == WorkBackendGateStatus.flagName,
            "flag drift: Swift '\(WorkBackendGateStatus.flagName)' != Rust '\(rustFlag)'"
        )
        // The Rust seam stays honestly INERT (engine not wired) — no silent Chat/Act fallback.
        #expect(rust.contains("engine_wired"))
        #expect(rust.contains("Err(WorkError::EngineNotWired)"))
        // ProvenanceGate: the vendored block/goose core is Apache-2.0 (direct_import OK).
        #expect(rust.contains("GOOSE_VENDOR_LICENSE: &str = \"Apache-2.0\""))
        #expect(rust.contains("block/goose"))
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
