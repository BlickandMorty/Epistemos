import Testing
@testable import Epistemos

/// P8.5 — locks the visible schema-gate status so it can never claim something
/// the Rust gate doesn't enforce. The accepted-flag truth table must stay
/// byte-identical to `registry.rs` `schema_gate_enabled()`.
@Suite("Deterministic schema gate status")
struct DeterministicSchemaGateStatusTests {

    @Test("flag truth table matches the Rust gate (1/true/yes/on → on; else off)")
    func flagTruthTable() {
        for on in ["1", "true", "yes", "on", "  ON ", "True"] {
            #expect(DeterministicSchemaGateStatus.isEnabled(on), "\(on) should enable")
        }
        for off in [nil, "", "0", "false", "no", "off", "2", "enabled"] {
            #expect(!DeterministicSchemaGateStatus.isEnabled(off), "\(off ?? "nil") should NOT enable")
        }
    }

    @Test("status reflects the env flag honestly (active vs opt-in)")
    func statusReflectsFlag() {
        let key = DeterministicSchemaGateStatus.flagName
        let on = DeterministicSchemaGateStatus.status(environment: [key: "1"])
        #expect(on.isActive)
        #expect(on.headline.contains("ON"))
        #expect(on.detail.contains("rejected"))

        let off = DeterministicSchemaGateStatus.status(environment: [:])
        #expect(!off.isActive)
        #expect(off.headline.contains("off"))
        #expect(off.detail.contains(key))   // tells the user how to turn it on
    }
}
