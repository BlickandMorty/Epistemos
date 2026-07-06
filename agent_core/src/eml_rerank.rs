//! P5.H A2/A3 — EML re-rank policy (always-compiled).
//!
//! The research `eml` IR (`agent_core/src/research/eml/`, `#[cfg(feature=
//! "research")]`) defines the elementary-math primitive `eml(x, y) = exp(x) −
//! ln(y)` and `EmlPotential::from_score`. That whole IR (branched exprs,
//! certificates, grammar, ULP oracle — 500+ tests) is deliberately NOT compiled
//! into the shipping app. But the *retrieval re-rank* only needs the scalar
//! potential, so we promote JUST that here — keeping the MAS binary lean while
//! making the EML re-rank reachable from the live vault path.
//!
//! Re-rank doctrine (`EML_INTEGRATION_DOCTRINE_2026_05_17.md` §123-132): order
//! candidates by `eml(-ln(bm25 + ε), secondary)`, **smaller is better**. This
//! fuses a lexical signal (BM25) with a secondary signal (semantic / recall /
//! title) into one scalar energy, so a result that's strong on BOTH wins over
//! one that's only strong on one — a determinism-friendly, monotone, no-model
//! re-rank. Gated behind `EPISTEMOS_EML_RERANK_V1` at the call site; default is
//! ON and `0`/`false`/`no`/`off` are rollback values while diagnosing.

/// Small floor so `ln(bm25 + ε)` is finite when BM25 is 0.
pub const BM25_EPSILON: f64 = 1e-6;

/// The elementary-math primitive `eml(x, y) = exp(x) − ln(y)` — byte-identical
/// to the research IR's definition. `y` must be > 0 (the caller guarantees it via
/// the re-rank key); a non-positive `y` returns `f64::INFINITY` so such a
/// candidate sorts last rather than producing a `NaN`.
#[inline]
pub fn eml(x: f64, y: f64) -> f64 {
    if y <= 0.0 || !y.is_finite() || !x.is_finite() {
        return f64::INFINITY;
    }
    x.exp() - y.ln()
}

/// The re-rank key for a candidate: `eml(-ln(bm25 + ε), secondary)`. Smaller is
/// better. `secondary` is any positive "the more the better" signal (semantic
/// concept score, title match, recall fraction); it is shifted to `secondary + 1`
/// so a 0 signal is valid (`ln(1) = 0`) and more signal lowers the energy.
pub fn rerank_key(bm25: f64, secondary: f64) -> f64 {
    let bm25 = bm25.max(0.0);
    let secondary = secondary.max(0.0);
    eml(-(bm25 + BM25_EPSILON).ln(), secondary + 1.0)
}

/// Re-rank `items` ascending by their EML key (smaller energy first). Stable, so
/// equal-key items keep their input order. `key_signals` returns `(bm25,
/// secondary)` for each item. Pure — no I/O, deterministic.
pub fn rerank_by_eml<T>(mut items: Vec<T>, key_signals: impl Fn(&T) -> (f64, f64)) -> Vec<T> {
    items.sort_by(|a, b| {
        let (ba, sa) = key_signals(a);
        let (bb, sb) = key_signals(b);
        rerank_key(ba, sa)
            .partial_cmp(&rerank_key(bb, sb))
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    items
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn eml_matches_the_primitive_definition() {
        // eml(x,y) = exp(x) - ln(y).
        assert!((eml(0.0, 1.0) - (1.0 - 0.0)).abs() < 1e-12); // exp(0)-ln(1)=1
        assert!((eml(1.0, std::f64::consts::E) - (std::f64::consts::E - 1.0)).abs() < 1e-12);
    }

    #[test]
    fn eml_non_positive_y_sorts_last_not_nan() {
        assert_eq!(eml(0.0, 0.0), f64::INFINITY);
        assert_eq!(eml(0.0, -1.0), f64::INFINITY);
        assert!(eml(f64::NAN, 1.0).is_infinite());
    }

    #[test]
    fn higher_bm25_lowers_the_key_all_else_equal() {
        // -ln(bm25+ε) shrinks as bm25 grows → exp() term shrinks → smaller key.
        assert!(rerank_key(10.0, 0.0) < rerank_key(1.0, 0.0));
    }

    #[test]
    fn higher_secondary_lowers_the_key_all_else_equal() {
        // larger secondary → larger ln(secondary+1) subtracted → smaller key.
        assert!(rerank_key(5.0, 4.0) < rerank_key(5.0, 0.0));
    }

    #[test]
    fn rerank_fuses_signals_not_pure_bm25() {
        // A has the HIGHEST bm25 but zero secondary — under a pure-BM25 sort it
        // would rank first. The EML fusion must demote it (the secondary signal
        // is part of the energy), so the top-BM25-with-no-secondary result does
        // NOT win. (Here B, modest-bm25 + strong-secondary, wins.)
        let items = vec![("A", 12.0, 0.0), ("B", 4.0, 5.0), ("C", 9.0, 4.0)];
        let ranked = rerank_by_eml(items, |&(_, bm25, sec)| (bm25, sec));
        assert_ne!(
            ranked.first().unwrap().0,
            "A",
            "fusion demotes top-BM25-only"
        );
        assert_eq!(
            ranked.last().unwrap().0,
            "A",
            "no-secondary candidate sinks"
        );
    }

    #[test]
    fn rerank_is_stable_for_equal_keys() {
        let items = vec![("first", 3.0, 1.0), ("second", 3.0, 1.0)];
        let ranked = rerank_by_eml(items, |&(_, bm25, sec)| (bm25, sec));
        assert_eq!(ranked[0].0, "first");
        assert_eq!(ranked[1].0, "second");
    }
}
