import Testing
import Foundation

/// DeerFlow slice 5b (visible surface) — locks that the deep-research surface
/// reads the SAME env flag the in-process Rust run (deep_research::
/// deep_research_enabled) reads, with the SAME opt-in truth table, so the
/// SubstrateHealthPanel row never claims a capability the runtime isn't offering.
@Suite("Deep research gate status")
struct DeepResearchGateStatusTests {

    @Test("flag name matches the Rust runtime flag")
    func flagNameMatchesRuntime() {
        #expect(DeepResearchGateStatus.flagName == "EPISTEMOS_DEEP_RESEARCH_V0")
    }

    @Test("opt-in truth table mirrors Rust deep_research_flag_value")
    func optInTruthTable() {
        for on in ["1", "true", "TRUE", "Yes", "on", " on ", "  1  "] {
            #expect(DeepResearchGateStatus.isEnabled(on), "\(on) should enable")
        }
        for off in ["0", "false", "no", "off", "", "2", "enable", nil] {
            #expect(!DeepResearchGateStatus.isEnabled(off), "\(off ?? "nil") should be off")
        }
    }

    @Test("status reflects the flag honestly + is Pro-scoped")
    func statusReflectsFlag() {
        let on = DeepResearchGateStatus.status(environment: ["EPISTEMOS_DEEP_RESEARCH_V0": "1"])
        #expect(on.isActive)
        #expect(on.headline.contains("ON"))
        #expect(on.detail.contains("parallel"))

        let off = DeepResearchGateStatus.status(environment: [:])
        #expect(!off.isActive)
        #expect(off.detail.contains("EPISTEMOS_DEEP_RESEARCH_V0"))
    }
}
