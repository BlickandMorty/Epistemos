import Testing
import Foundation
@testable import Epistemos

/// P5.H (visible determinism) — locks that the EML re-rank surface reads the
/// SAME env flag the in-process Rust re-rank (vault.rs `eml_rerank_enabled`)
/// reads, with the SAME opt-in truth table, so the SubstrateHealthPanel row
/// never claims a re-rank the runtime isn't doing.
@Suite("EML re-rank gate status")
struct EmlRerankGateStatusTests {

    @Test("flag name matches the Rust runtime flag")
    func flagNameMatchesRuntime() {
        #expect(EmlRerankGateStatus.flagName == "EPISTEMOS_EML_RERANK_V1")
    }

    @Test("opt-in truth table mirrors Rust eml_rerank_enabled")
    func optInTruthTable() {
        // Enabled spellings (Rust: "1"/"true"/"yes"/"on", case/space-insensitive).
        for on in ["1", "true", "TRUE", "Yes", "on", " on ", "  1  "] {
            #expect(EmlRerankGateStatus.isEnabled(on), "\(on) should enable")
        }
        // Everything else is off.
        for off in ["0", "false", "no", "off", "", "2", "enable", nil] {
            #expect(!EmlRerankGateStatus.isEnabled(off), "\(off ?? "nil") should be off")
        }
    }

    @Test("status reflects the flag honestly")
    func statusReflectsFlag() {
        let on = EmlRerankGateStatus.status(environment: ["EPISTEMOS_EML_RERANK_V1": "1"])
        #expect(on.isActive)
        #expect(on.headline.contains("ON"))

        let off = EmlRerankGateStatus.status(environment: [:])
        #expect(!off.isActive)
        #expect(off.detail.contains("EPISTEMOS_EML_RERANK_V1"))
    }
}
