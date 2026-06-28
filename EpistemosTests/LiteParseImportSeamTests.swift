import Testing
import Foundation
@testable import Epistemos

/// R-LITEPARSE — Seam A guard. Locks the honest PDF→Markdown import seam: the gate flag,
/// the MAS-safe PDF+OCR scope (no subprocess), the always-compiled visible health row,
/// and cross-runtime flag parity with the Rust seam (agent_core/src/liteparse.rs).
@Suite("LiteParse PDF→Markdown import seam (R-LITEPARSE)")
struct LiteParseImportSeamTests {

    @Test("gate flag is honest + on by default with a kill switch")
    func gateHonest() {
        #expect(LiteParseImportGateStatus.flagName == "EPISTEMOS_LITEPARSE_PDF_V0")
        #expect(LiteParseImportGateStatus.isEnabled("1"))
        #expect(LiteParseImportGateStatus.isEnabled(" On "))
        #expect(LiteParseImportGateStatus.isDisabled("0"))
        #expect(LiteParseImportGateStatus.isDisabled(" off "))
        #expect(!LiteParseImportGateStatus.isEnabled(nil))
        let active = LiteParseImportGateStatus.status(environment: [:])
        #expect(active.isActive)
        #expect(active.headline.localizedCaseInsensitiveContains("ready"))
        let off = LiteParseImportGateStatus.status(environment: ["EPISTEMOS_LITEPARSE_PDF_V0": "0"])
        #expect(!off.isActive)
        #expect(off.headline.localizedCaseInsensitiveContains("disabled"))
    }

    @Test("honest MAS scope: PDF + pure Rust parser stack, no fake markdown")
    func masScopeHonest() {
        let armed = LiteParseImportGateStatus.status(environment: ["EPISTEMOS_LITEPARSE_PDF_V0": "1"])
        #expect(armed.isActive)
        #expect(armed.detail.localizedCaseInsensitiveContains("PDF"))
        #expect(armed.detail.localizedCaseInsensitiveContains("EdgeParse"))
        #expect(armed.detail.localizedCaseInsensitiveContains("unpdf"))
        #expect(
            armed.detail.localizedCaseInsensitiveContains("no sidecar")
                || armed.detail.localizedCaseInsensitiveContains("pure Rust")
        )
    }

    @Test("the gate is always-compiled + the health row is mounted in the Substrate panel")
    func alwaysCompiledAndMounted() throws {
        let gate = try loadMirroredSourceTextFile("Epistemos/LiteParse/LiteParseImportGateStatus.swift")
        #expect(gate.contains("nonisolated enum LiteParseImportGateStatus"))
        #expect(gate.contains("OUT OF SCOPE")) // the Office/image subprocess exclusion is baked in
        let panel = try loadMirroredSourceTextFile("Epistemos/Views/Settings/SubstrateHealthPanel.swift")
        #expect(panel.contains("LiteParseImportHealthRow()"))
    }

    @Test("cross-runtime flag parity: Swift flagName == Rust LITEPARSE_FLAG")
    func crossRuntimeFlagParity() throws {
        let rust = try loadMirroredSourceTextFile("agent_core/src/liteparse.rs")
        guard
            let opening = rust.range(of: #"LITEPARSE_FLAG: &str = ""#),
            let closing = rust.range(of: "\"", range: opening.upperBound..<rust.endIndex)
        else {
            Issue.record("could not find the LITEPARSE_FLAG literal in agent_core/src/liteparse.rs")
            return
        }
        let rustFlag = String(rust[opening.upperBound..<closing.lowerBound])
        #expect(
            rustFlag == LiteParseImportGateStatus.flagName,
            "flag drift: Swift '\(LiteParseImportGateStatus.flagName)' != Rust '\(rustFlag)'"
        )
        // The Rust seam keeps the PDF-only MAS scope + the Apache-2.0/MIT ProvenanceGate.
        #expect(rust.contains("pdf+markdown,no-subprocess"))
        #expect(rust.contains("Apache-2.0"))
        #expect(rust.contains("MIT"))
    }
}
