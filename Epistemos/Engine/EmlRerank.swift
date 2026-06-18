import Foundation

/// P5.H A1 (EML-2) foundation — the Swift mirror of `agent_core/src/eml_rerank.rs`.
/// The elementary-math primitive `eml(x, y) = exp(x) − ln(y)` and the re-rank /
/// route key, byte-identical to the Rust core so a Swift-side ranking (the
/// ConfidenceRouter EML scoring) and the Rust-side vault re-rank agree exactly —
/// cross-runtime determinism per the honest-handle-FFI doctrine. Pure +
/// `nonisolated` so the parity is unit-testable.
nonisolated enum EmlRerank {
    /// Small floor so `ln(bm25 + ε)` is finite when the lexical signal is 0 —
    /// matches Rust `eml_rerank::BM25_EPSILON`.
    static let epsilon: Double = 1e-6

    /// `eml(x, y) = exp(x) − ln(y)`. Non-positive / non-finite `y` (or non-finite
    /// `x`) → `+∞` so such a candidate sorts LAST rather than producing a NaN —
    /// identical to the Rust guard.
    static func eml(_ x: Double, _ y: Double) -> Double {
        guard y > 0, y.isFinite, x.isFinite else { return .infinity }
        return exp(x) - log(y)
    }

    /// The re-rank / route key: `eml(-ln(primary + ε), secondary + 1)`. Smaller
    /// is better. `primary` is the dominant "more is better" signal (BM25, or a
    /// route's confidence); `secondary` is the fused "more is better" signal
    /// (excerpt coverage, or inverse-complexity). Mirrors Rust
    /// `eml_rerank::rerank_key`.
    static func rerankKey(primary: Double, secondary: Double) -> Double {
        let primary = max(0, primary)
        let secondary = max(0, secondary)
        return eml(-log(primary + epsilon), secondary + 1.0)
    }
}
