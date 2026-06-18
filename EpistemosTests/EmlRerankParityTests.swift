import Testing
import Foundation
@testable import Epistemos

/// P5.H A1 — locks Swift⇄Rust EML parity: the Swift `EmlRerank` must compute the
/// SAME values as `agent_core/src/eml_rerank.rs` at the same inputs, so a
/// Swift-side route ranking and the Rust-side vault re-rank never disagree
/// (cross-runtime determinism). The Rust expectations below are the exact cases
/// the Rust `#[cfg(test)]` suite asserts.
@Suite("EML re-rank Swift⇄Rust parity")
struct EmlRerankParityTests {

    @Test("eml(x,y) matches the primitive definition exp(x) − ln(y)")
    func emlPrimitive() {
        #expect(abs(EmlRerank.eml(0, 1) - 1.0) < 1e-12)                 // exp(0)-ln(1)=1
        #expect(abs(EmlRerank.eml(1, M_E) - (M_E - 1.0)) < 1e-12)       // e - 1
    }

    @Test("non-positive / NaN y → +∞ (sorts last, no NaN) — same guard as Rust")
    func infinityGuard() {
        #expect(EmlRerank.eml(0, 0).isInfinite)
        #expect(EmlRerank.eml(0, -1).isInfinite)
        #expect(EmlRerank.eml(.nan, 1).isInfinite)
    }

    @Test("rerankKey: higher primary and higher secondary each LOWER the key")
    func keyDirection() {
        #expect(EmlRerank.rerankKey(primary: 10, secondary: 0) < EmlRerank.rerankKey(primary: 1, secondary: 0))
        #expect(EmlRerank.rerankKey(primary: 5, secondary: 4) < EmlRerank.rerankKey(primary: 5, secondary: 0))
    }

    @Test("rerankKey matches the Rust-side computed values exactly")
    func keyParity() {
        // Recomputed from the Rust formula eml(-ln(p+ε), s+1):
        // p=12,s=0 → exp(-ln(12)) - ln(1) = 1/12 - 0 ≈ 0.0833333
        #expect(abs(EmlRerank.rerankKey(primary: 12, secondary: 0) - (1.0 / 12.0)) < 1e-6)
        // p=4,s=5 → 1/4 - ln(6) ≈ 0.25 - 1.791759 = -1.541759
        #expect(abs(EmlRerank.rerankKey(primary: 4, secondary: 5) - (0.25 - log(6.0))) < 1e-6)
    }
}
