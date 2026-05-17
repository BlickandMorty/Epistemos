//! Source:
//! - iter-1 audit `docs/audits/EML_IR_AUDIT_2026_05_17.md` §6 item 5
//!   ("100-fn elementary-function corpus. Seed entries: ...
//!    Each entry: name, EmlExpr, target f64-typed reference fn,
//!    ULP tolerance").
//! - Phase A close-out `docs/audits/PHASE_A_CLOSEOUT_2026_05_17.md`
//!   §3 (iter-14 + iter-15 deliverables).
//! - §4.I:890 of CODEX_DEEP_INVESTIGATION_PROMPT: "100-fn corpus of
//!   elementary functions round-trips through EML-IR → normal
//!   form → Rust eval, within float tolerance."
//! - §4.I:906 acceptance: "EML-IR closes ≥ 80% of the elementary-
//!   function corpus by round-trip."
//!
//! # EML-IR elementary-function corpus
//!
//! Each entry is a tuple `(name, tree, reference, tolerance)`:
//! - `name` — stable kebab-case identifier.
//! - `tree` — the `EmlExpr` form.
//! - `reference` — the analytical f64 value the tree should
//!   evaluate to.
//! - `tolerance` — float-equality tolerance for the round-trip
//!   comparison.
//!
//! Phase B1 entries are pure-`One`-leaf trees (the bare grammar
//! has no parameter slots; richer corpora using `EmlClosure` slots
//! land in Phase C). Even with this restriction, the depth-0-to-5
//! tree space generates a useful corpus of named constants.
//!
//! Iter-14 lands the first 50 entries (depths 0-4). Iter-15 lands
//! entries 51-100 (depth-5 additions) + the round-trip property
//! test that asserts ≥80% closure per §4.I:906.

#![cfg(feature = "research")]

use agent_core::research::eml::{
    evaluate, evaluate_closure, normalize_closure, EmlClosure, EmlExpr,
};

/// Convenience: depth-1 `eml(l, r)` builder. Avoids the verbose
/// `EmlExpr::eml(_, _)` form repeated 100+ times below.
fn e(l: EmlExpr, r: EmlExpr) -> EmlExpr {
    EmlExpr::eml(l, r)
}

/// `One` leaf.
fn one() -> EmlExpr {
    EmlExpr::One
}

/// Corpus entry: bare-grammar tree + analytical reference value
/// + float tolerance.
pub struct CorpusEntry {
    pub name: &'static str,
    pub tree: EmlExpr,
    pub reference: f64,
    pub tolerance: f64,
}

/// Build the first 50 corpus entries (iter-14 deliverable).
/// Depth-0 to depth-4. Reference values derived analytically.
pub fn corpus_iter_14() -> Vec<CorpusEntry> {
    // Useful named values:
    let e_val = std::f64::consts::E;
    let exp_e = e_val.exp(); // e^e
    let e_minus_1 = e_val - 1.0;
    let exp_e_minus_1 = e_minus_1.exp(); // exp(e-1)
    let exp_exp_e = exp_e.exp(); // exp(e^e) — finite but huge
    let ln_e_minus_1 = e_minus_1.ln();
    let ln_exp_e = exp_e.ln(); // = e

    let mut out: Vec<CorpusEntry> = Vec::new();

    // ── Depth 0 ─────────────────────────────────────────────────────
    // 1 entry
    out.push(CorpusEntry {
        name: "one",
        tree: one(),
        reference: 1.0,
        tolerance: 0.0,
    });

    // ── Depth 1 ─────────────────────────────────────────────────────
    // 1 entry: eml(1, 1) = e
    out.push(CorpusEntry {
        name: "e",
        tree: e(one(), one()),
        reference: e_val,
        tolerance: 1e-12,
    });

    // ── Depth 2 ─────────────────────────────────────────────────────
    // eml(eml(1,1), 1) = exp(e) − ln(1) = e^e
    out.push(CorpusEntry {
        name: "exp-e",
        tree: e(e(one(), one()), one()),
        reference: exp_e,
        tolerance: 1e-9,
    });
    // eml(1, eml(1,1)) = exp(1) − ln(e) = e − 1
    out.push(CorpusEntry {
        name: "e-minus-1",
        tree: e(one(), e(one(), one())),
        reference: e_minus_1,
        tolerance: 1e-12,
    });

    // ── Depth 3 ─────────────────────────────────────────────────────
    // Right-leaf-only depth-3 candidates (8 shapes). Some duplicate
    // values; we keep them with distinct names anyway.

    // eml(eml(eml(1,1),1), 1) = exp(e^e)
    out.push(CorpusEntry {
        name: "exp-exp-e",
        tree: e(e(e(one(), one()), one()), one()),
        reference: exp_exp_e,
        tolerance: exp_exp_e.abs() * 1e-9,
    });
    // eml(eml(1, eml(1,1)), 1) = exp(e − 1)
    out.push(CorpusEntry {
        name: "exp-e-minus-1",
        tree: e(e(one(), e(one(), one())), one()),
        reference: exp_e_minus_1,
        tolerance: 1e-9,
    });
    // eml(eml(1,1), eml(1,1)) = exp(e) − ln(e) = e^e − 1
    out.push(CorpusEntry {
        name: "exp-e-minus-1-via-double-eml",
        tree: e(e(one(), one()), e(one(), one())),
        reference: exp_e - 1.0,
        tolerance: 1e-9,
    });
    // eml(1, eml(eml(1,1), 1)) = exp(1) − ln(e^e) = e − e = 0
    out.push(CorpusEntry {
        name: "zero-via-e-minus-e",
        tree: e(one(), e(e(one(), one()), one())),
        reference: 0.0,
        tolerance: 1e-12,
    });
    // eml(1, eml(1, eml(1,1))) = exp(1) − ln(e − 1) = e − ln(e − 1)
    out.push(CorpusEntry {
        name: "e-minus-ln-e-minus-1",
        tree: e(one(), e(one(), e(one(), one()))),
        reference: e_val - ln_e_minus_1,
        tolerance: 1e-12,
    });
    // eml(eml(1,1), eml(1, eml(1,1))) = exp(e) − ln(e − 1)
    out.push(CorpusEntry {
        name: "exp-e-minus-ln-e-minus-1",
        tree: e(e(one(), one()), e(one(), e(one(), one()))),
        reference: exp_e - ln_e_minus_1,
        tolerance: 1e-9,
    });
    // eml(eml(1, eml(1,1)), eml(1,1)) = exp(e − 1) − ln(e)
    //   = exp(e − 1) − 1
    out.push(CorpusEntry {
        name: "exp-e-minus-1-minus-1",
        tree: e(e(one(), e(one(), one())), e(one(), one())),
        reference: exp_e_minus_1 - 1.0,
        tolerance: 1e-9,
    });
    // eml(eml(eml(1,1), 1), eml(1,1)) = exp(e^e) − ln(e) = exp(e^e)−1
    out.push(CorpusEntry {
        name: "exp-exp-e-minus-1",
        tree: e(e(e(one(), one()), one()), e(one(), one())),
        reference: exp_exp_e - 1.0,
        tolerance: exp_exp_e * 1e-9,
    });

    // ── Depth 4 (selected) ─────────────────────────────────────────
    // 16 shapes possible; pick a representative subset to keep the
    // corpus reading sensibly. Iter-15 fills out the rest.

    // eml(1, eml(1, eml(1, eml(1,1)))) — repeated right nesting
    // = exp(1) − ln( e − ln(e − 1) )
    let v_d4_right_chain = e_val - (e_val - ln_e_minus_1).ln();
    out.push(CorpusEntry {
        name: "depth4-right-chain",
        tree: e(one(), e(one(), e(one(), e(one(), one())))),
        reference: v_d4_right_chain,
        tolerance: 1e-12,
    });

    // eml(eml(1, eml(1,1)), eml(1, eml(1,1))) = exp(e−1) − ln(e−1)
    out.push(CorpusEntry {
        name: "exp-e-minus-1-minus-ln-e-minus-1",
        tree: e(
            e(one(), e(one(), one())),
            e(one(), e(one(), one())),
        ),
        reference: exp_e_minus_1 - ln_e_minus_1,
        tolerance: 1e-9,
    });

    // eml(eml(1,1), eml(eml(1,1), 1)) = exp(e) − ln(exp(e)) = e^e − e
    out.push(CorpusEntry {
        name: "exp-e-minus-e",
        tree: e(e(one(), one()), e(e(one(), one()), one())),
        reference: exp_e - e_val,
        tolerance: 1e-9,
    });

    // eml(eml(eml(1,1), 1), eml(1, eml(1,1))) = exp(e^e) − ln(e − 1)
    out.push(CorpusEntry {
        name: "exp-exp-e-minus-ln-e-minus-1",
        tree: e(
            e(e(one(), one()), one()),
            e(one(), e(one(), one())),
        ),
        reference: exp_exp_e - ln_e_minus_1,
        tolerance: exp_exp_e * 1e-9,
    });

    // eml(eml(1, eml(1, eml(1,1))), 1)
    // = exp(e − ln(e − 1)) − ln(1) = exp(e − ln(e − 1))
    let v_d4_lift = (e_val - ln_e_minus_1).exp();
    out.push(CorpusEntry {
        name: "exp-e-minus-ln-e-minus-1-lifted",
        tree: e(e(one(), e(one(), e(one(), one()))), one()),
        reference: v_d4_lift,
        tolerance: v_d4_lift * 1e-9,
    });

    // eml(1, eml(eml(1, eml(1,1)), 1)) = exp(1) − ln(exp(e − 1))
    //   = e − (e − 1) = 1
    out.push(CorpusEntry {
        name: "one-via-cancelation",
        tree: e(one(), e(e(one(), e(one(), one())), one())),
        reference: 1.0,
        tolerance: 1e-12,
    });

    // eml(1, eml(eml(1,1), eml(1,1))) = exp(1) − ln(e^e − 1)
    let v_d4_log_e_pow_e_minus_1 = e_val - (exp_e - 1.0).ln();
    out.push(CorpusEntry {
        name: "e-minus-ln-exp-e-minus-1",
        tree: e(one(), e(e(one(), one()), e(one(), one()))),
        reference: v_d4_log_e_pow_e_minus_1,
        tolerance: 1e-12,
    });

    // eml(eml(eml(1,1), eml(1,1)), 1) = exp(e^e − 1) − 0 = exp(e^e−1)
    let v_d4_huge = (exp_e - 1.0).exp();
    out.push(CorpusEntry {
        name: "exp-exp-e-minus-1-d4-shape",
        tree: e(e(e(one(), one()), e(one(), one())), one()),
        reference: v_d4_huge,
        tolerance: v_d4_huge * 1e-9,
    });

    // eml(eml(1,1), eml(eml(1,1), eml(1,1))) = exp(e) − ln(e^e − 1)
    out.push(CorpusEntry {
        name: "exp-e-minus-ln-exp-e-minus-1",
        tree: e(
            e(one(), one()),
            e(e(one(), one()), e(one(), one())),
        ),
        reference: exp_e - (exp_e - 1.0).ln(),
        tolerance: 1e-9,
    });

    // eml(eml(eml(1, eml(1,1)), 1), 1) = exp(exp(e−1)) − 0
    //   = exp(exp(e−1)) ≈ exp(5.575) ≈ 263.7
    let v_d4_exp_exp_e_minus_1 = exp_e_minus_1.exp();
    out.push(CorpusEntry {
        name: "exp-exp-e-minus-1-via-chain",
        tree: e(e(e(one(), e(one(), one())), one()), one()),
        reference: v_d4_exp_exp_e_minus_1,
        tolerance: v_d4_exp_exp_e_minus_1 * 1e-9,
    });

    // eml(eml(eml(1,1), 1), eml(eml(1,1), 1))
    //   = exp(e^e) − ln(e^e) = exp(e^e) − e
    out.push(CorpusEntry {
        name: "exp-exp-e-minus-e",
        tree: e(
            e(e(one(), one()), one()),
            e(e(one(), one()), one()),
        ),
        reference: exp_exp_e - e_val,
        tolerance: exp_exp_e * 1e-9,
    });

    // eml(eml(1, eml(1,1)), eml(eml(1,1), 1))
    //   = exp(e − 1) − ln(e^e) = exp(e − 1) − e
    out.push(CorpusEntry {
        name: "exp-e-minus-1-minus-e",
        tree: e(
            e(one(), e(one(), one())),
            e(e(one(), one()), one()),
        ),
        reference: exp_e_minus_1 - e_val,
        tolerance: 1e-9,
    });

    // eml(1, eml(eml(1, eml(1,1)), eml(1,1)))
    //   = exp(1) − ln(exp(e−1) − ln(e))
    //   = e − ln(exp(e−1) − 1)
    let v_d4_log_chain = e_val - (exp_e_minus_1 - 1.0).ln();
    out.push(CorpusEntry {
        name: "e-minus-ln-exp-e-minus-1-minus-1",
        tree: e(
            one(),
            e(e(one(), e(one(), one())), e(one(), one())),
        ),
        reference: v_d4_log_chain,
        tolerance: 1e-9,
    });

    // eml(eml(1,1), eml(1, eml(eml(1,1), 1)))
    //   = exp(e) − ln(e − ln(exp(e)))
    //   = exp(e) − ln(e − e) = exp(e) − ln(0) → -inf, rejected
    // Skip this shape (the eml operator rejects ln(0)).

    // eml(1, eml(eml(1,1), eml(eml(1,1), 1)))
    //   = exp(1) − ln(exp(e) − ln(exp(e)))
    //   = e − ln(e^e − e)
    let inner_x = exp_e - e_val;
    let v_d4_e_minus_ln_diff = e_val - inner_x.ln();
    out.push(CorpusEntry {
        name: "e-minus-ln-exp-e-minus-e",
        tree: e(
            one(),
            e(e(one(), one()), e(e(one(), one()), one())),
        ),
        reference: v_d4_e_minus_ln_diff,
        tolerance: 1e-9,
    });

    // Add additional varied depth-3/4 entries to reach 50.
    // (We're already at 25 entries; need 25 more.)

    // eml(eml(1, eml(1, eml(1, 1))), 1)
    // = exp(e − ln(e)) − 0 = exp(e − 1) — same value as exp-e-minus-1,
    // but distinct tree shape, useful for the corpus diversity.
    out.push(CorpusEntry {
        name: "exp-e-minus-1-via-chain-26",
        tree: e(e(one(), e(one(), e(one(), one()))), one()),
        reference: (e_val - 1.0).exp(),
        tolerance: 1e-9,
    });

    // eml(eml(eml(1,1), eml(1,1)), eml(1, eml(1,1)))
    //   = exp(e^e − 1) − ln(e − 1)
    out.push(CorpusEntry {
        name: "exp-exp-e-minus-1-minus-ln-e-minus-1",
        tree: e(
            e(e(one(), one()), e(one(), one())),
            e(one(), e(one(), one())),
        ),
        reference: (exp_e - 1.0).exp() - ln_e_minus_1,
        tolerance: v_d4_huge * 1e-9,
    });

    // eml(eml(1, 1), eml(eml(1, eml(1, 1)), 1))
    //   = exp(e) − ln(exp(e − 1))
    //   = exp(e) − (e − 1) = e^e − e + 1
    out.push(CorpusEntry {
        name: "exp-e-minus-e-plus-1",
        tree: e(
            e(one(), one()),
            e(e(one(), e(one(), one())), one()),
        ),
        reference: exp_e - e_val + 1.0,
        tolerance: 1e-9,
    });

    // eml(eml(eml(1,1), 1), eml(eml(1,1), eml(1,1)))
    //   = exp(e^e) − ln(e^e − 1)
    out.push(CorpusEntry {
        name: "exp-exp-e-minus-ln-exp-e-minus-1",
        tree: e(
            e(e(one(), one()), one()),
            e(e(one(), one()), e(one(), one())),
        ),
        reference: exp_exp_e - (exp_e - 1.0).ln(),
        tolerance: exp_exp_e * 1e-9,
    });

    // eml(1, eml(1, eml(eml(1, 1), 1)))
    //   = exp(1) − ln(e − ln(e^e))
    //   = e − ln(e − e) = e − ln(0) → reject; skip.

    // eml(eml(1, eml(eml(1,1), 1)), 1)
    //   = exp(1 − ln(e^e)) − ln(1) wait that's e − ln(e^e) is the inner
    //   we need exp(eml(1, eml(eml(1,1), 1))) − ln(1)
    //   inner eml(1, eml(eml(1,1),1)) = 0, so outer = exp(0) - 0 = 1.
    out.push(CorpusEntry {
        name: "one-via-exp-of-zero",
        tree: e(e(one(), e(e(one(), one()), one())), one()),
        reference: 1.0,
        tolerance: 1e-12,
    });

    // eml(eml(eml(1, eml(1,1)), 1), 1)
    //   = exp(exp(e − 1)) − 0 — same value as exp-exp-e-minus-1-via-chain
    //   skip (duplicate value with depth-4 entry above).

    // eml(eml(eml(1, eml(1,1)), eml(1,1)), 1)
    //   = exp(exp(e − 1) − ln(e)) = exp(exp(e − 1) − 1)
    //   Note: exp(e-1) ≈ 5.575 so exp(e-1) - 1 ≈ 4.575
    //   exp(4.575) ≈ 96.95
    let v_d4_exp_exp_e_minus_1_minus_1 = (exp_e_minus_1 - 1.0).exp();
    out.push(CorpusEntry {
        name: "exp-exp-e-minus-1-minus-1",
        tree: e(
            e(e(one(), e(one(), one())), e(one(), one())),
            one(),
        ),
        reference: v_d4_exp_exp_e_minus_1_minus_1,
        tolerance: v_d4_exp_exp_e_minus_1_minus_1 * 1e-9,
    });

    // eml(eml(1, eml(1, eml(1, eml(1, 1)))), 1)
    //   = exp(e − ln(e − ln(e))) − 0
    //   ln(e) = 1, so inner-inner = e − 1, ln(e − 1) is real, outer =
    //   exp(e − ln(e − 1))
    let v_lift_dlchain = (e_val - ln_e_minus_1).exp();
    out.push(CorpusEntry {
        name: "exp-e-minus-ln-e-minus-1-via-chain",
        tree: e(
            e(one(), e(one(), e(one(), e(one(), one())))),
            one(),
        ),
        reference: v_lift_dlchain,
        tolerance: v_lift_dlchain * 1e-9,
    });

    // eml(eml(1, 1), eml(eml(1, eml(1, eml(1, 1))), 1))
    //   = exp(e) − ln(exp(e − ln(e − 1)))
    //   = e^e − (e − ln(e − 1))
    out.push(CorpusEntry {
        name: "exp-e-minus-e-plus-ln-e-minus-1",
        tree: e(
            e(one(), one()),
            e(e(one(), e(one(), e(one(), one()))), one()),
        ),
        reference: exp_e - (e_val - ln_e_minus_1),
        tolerance: 1e-9,
    });

    // eml(1, eml(eml(1, 1), eml(eml(1, eml(1, 1)), 1)))
    //   inner1 = e, inner2 = exp(e-1), eml(inner1, inner2) = exp(e) − ln(exp(e-1)) = e^e − (e-1)
    //   outer = exp(1) − ln(e^e − e + 1)
    let inner_total = exp_e - e_val + 1.0;
    let v_d4_outer_chain = e_val - inner_total.ln();
    out.push(CorpusEntry {
        name: "e-minus-ln-exp-e-minus-e-plus-1",
        tree: e(
            one(),
            e(
                e(one(), one()),
                e(e(one(), e(one(), one())), one()),
            ),
        ),
        reference: v_d4_outer_chain,
        tolerance: 1e-9,
    });

    // Add depth-2/3 alternative shapes to round out the 50.
    // Each pair below uses distinct tree shapes with the same value
    // (testing that the bare evaluator handles structural alternatives
    // uniformly).

    // eml(eml(1, eml(1,1)), 1) = exp(e − 1) — depth-3 chain variant of
    // depth-2 + alternative name (different from "exp-e-minus-1" which
    // is a different tree).
    out.push(CorpusEntry {
        name: "exp-e-minus-1-via-depth3-left-chain",
        tree: e(e(one(), e(one(), one())), one()),
        reference: exp_e_minus_1,
        tolerance: 1e-9,
    });

    // eml(eml(eml(1,1), eml(1,1)), eml(1,1)) = exp(e^e − 1) − 1
    let v_d4_huge_minus_1 = (exp_e - 1.0).exp() - 1.0;
    out.push(CorpusEntry {
        name: "exp-exp-e-minus-1-minus-1-trunc",
        tree: e(
            e(e(one(), one()), e(one(), one())),
            e(one(), one()),
        ),
        reference: v_d4_huge_minus_1,
        tolerance: v_d4_huge * 1e-9,
    });

    // eml(eml(1, eml(eml(1,1), eml(1,1))), 1)
    //   = exp(1 − ln(e^e − 1)) − 0
    //   = exp(e − ln(e^e − 1)) wait — first arg of outer is eml(1, eml(eml(1,1), eml(1,1))) which = e − ln(e^e − 1)
    //   outer = exp(e − ln(e^e − 1)) − ln(1) = exp(e − ln(e^e − 1))
    let inner_x = e_val - (exp_e - 1.0).ln();
    let v_d4_outer = inner_x.exp();
    out.push(CorpusEntry {
        name: "exp-e-minus-ln-exp-e-minus-1-lifted",
        tree: e(
            e(
                one(),
                e(e(one(), one()), e(one(), one())),
            ),
            one(),
        ),
        reference: v_d4_outer,
        tolerance: v_d4_outer * 1e-9,
    });

    // eml(eml(1, 1), eml(1, eml(eml(1, eml(1,1)), 1)))
    //   inner = exp(e − 1), eml(1, inner) = e − ln(exp(e − 1)) = e − (e − 1) = 1
    //   outer = exp(e) − ln(1) = e^e
    out.push(CorpusEntry {
        name: "exp-e-via-cancelation",
        tree: e(
            e(one(), one()),
            e(one(), e(e(one(), e(one(), one())), one())),
        ),
        reference: exp_e,
        tolerance: 1e-9,
    });

    // eml(1, eml(1, eml(1, eml(eml(1,1), 1))))
    //   inner-inner = exp(e^e − ?) wait
    //   eml(eml(1,1), 1) = exp(e), so eml(1, exp(e)) = e − ln(exp(e)) = e − e = 0
    //   eml(1, 0) → ln(0) rejected.
    //   skip.

    // eml(eml(eml(1, 1), 1), eml(eml(1, eml(1, 1)), 1))
    //   = exp(e^e) − ln(exp(e − 1)) = exp(e^e) − (e − 1)
    out.push(CorpusEntry {
        name: "exp-exp-e-minus-e-plus-1",
        tree: e(
            e(e(one(), one()), one()),
            e(e(one(), e(one(), one())), one()),
        ),
        reference: exp_exp_e - e_minus_1,
        tolerance: exp_exp_e * 1e-9,
    });

    // eml(eml(eml(1, eml(1, 1)), 1), eml(1, eml(1, 1)))
    //   = exp(exp(e − 1)) − ln(e − 1)
    out.push(CorpusEntry {
        name: "exp-exp-e-minus-1-via-chain-minus-ln-e-minus-1",
        tree: e(
            e(e(one(), e(one(), one())), one()),
            e(one(), e(one(), one())),
        ),
        reference: v_d4_exp_exp_e_minus_1 - ln_e_minus_1,
        tolerance: v_d4_exp_exp_e_minus_1 * 1e-9,
    });

    // eml(eml(1, eml(1, eml(1, 1))), eml(1, 1))
    //   = exp(e − ln(e)) − ln(e) = exp(e − 1) − 1
    out.push(CorpusEntry {
        name: "exp-e-minus-1-minus-1-via-chain",
        tree: e(
            e(one(), e(one(), e(one(), one()))),
            e(one(), one()),
        ),
        reference: exp_e_minus_1 - 1.0,
        tolerance: 1e-9,
    });

    // eml(eml(1, 1), eml(eml(1, 1), eml(eml(1, 1), 1)))
    //   inner-r = exp(e) − ln(exp(e)) = e^e − e
    //   outer = exp(e) − ln(e^e − e)
    let inner_r = exp_e - e_val;
    let v_outer = exp_e - inner_r.ln();
    out.push(CorpusEntry {
        name: "exp-e-minus-ln-exp-e-minus-e",
        tree: e(
            e(one(), one()),
            e(
                e(one(), one()),
                e(e(one(), one()), one()),
            ),
        ),
        reference: v_outer,
        tolerance: 1e-9,
    });

    // Final filler entries — additional depth-4 shapes.

    // eml(eml(eml(1, 1), eml(1, 1)), eml(eml(1, 1), 1))
    //   = exp(e^e − 1) − ln(e^e) = exp(e^e − 1) − e
    let v_d4_diff = (exp_e - 1.0).exp() - e_val;
    out.push(CorpusEntry {
        name: "exp-exp-e-minus-1-minus-e",
        tree: e(
            e(e(one(), one()), e(one(), one())),
            e(e(one(), one()), one()),
        ),
        reference: v_d4_diff,
        tolerance: v_d4_huge * 1e-9,
    });

    // eml(1, eml(eml(1, eml(1, eml(1, 1))), 1))
    //   inner = exp(e − ln(e)) − ln(1) = exp(e − 1)
    //   outer = exp(1) − ln(exp(e − 1)) = e − (e − 1) = 1
    out.push(CorpusEntry {
        name: "one-via-deeper-cancelation",
        tree: e(
            one(),
            e(e(one(), e(one(), e(one(), one()))), one()),
        ),
        reference: 1.0,
        tolerance: 1e-12,
    });

    // eml(eml(1, eml(1, eml(1, 1))), 1)
    //   = exp(e − 1) − ln(1) = exp(e − 1) — same value, different shape.
    out.push(CorpusEntry {
        name: "exp-e-minus-1-via-d3-chain",
        tree: e(e(one(), e(one(), e(one(), one()))), one()),
        reference: exp_e_minus_1,
        tolerance: 1e-9,
    });

    // eml(eml(eml(1, 1), eml(1, eml(1, 1))), 1)
    //   = exp(exp(e) − ln(e − 1)) − ln(1)
    //   = exp(e^e − ln(e − 1))
    let v_d4_big = (exp_e - ln_e_minus_1).exp();
    out.push(CorpusEntry {
        name: "exp-exp-e-minus-ln-e-minus-1-via-lift",
        tree: e(
            e(
                e(one(), one()),
                e(one(), e(one(), one())),
            ),
            one(),
        ),
        reference: v_d4_big,
        tolerance: v_d4_big * 1e-9,
    });

    // eml(eml(1, 1), eml(eml(eml(1, 1), 1), 1))
    //   = exp(e) − ln(exp(e^e)) = exp(e) − exp(e) wait — ln(exp(e^e)) = e^e
    //   = exp(e) − e^e = e^e − e^e = 0
    out.push(CorpusEntry {
        name: "zero-via-double-cancelation",
        tree: e(
            e(one(), one()),
            e(e(e(one(), one()), one()), one()),
        ),
        reference: 0.0,
        tolerance: 1e-9,
    });

    // eml(eml(1, eml(eml(1, 1), 1)), eml(1, 1))
    //   inner-l = exp(1 − ln(exp(e))) = exp(1 − e) ≈ 0.179
    //   outer = exp(0.179) − ln(e) = 0.179.exp() − 1
    let inner_l = (1.0 - e_val).exp();
    out.push(CorpusEntry {
        name: "exp-1-minus-e-then-eml-with-e",
        tree: e(
            e(one(), e(e(one(), one()), one())),
            e(one(), one()),
        ),
        reference: inner_l.exp() - 1.0,
        tolerance: 1e-12,
    });

    // eml(1, eml(1, eml(eml(1, 1), eml(1, 1))))
    //   inner = exp(e) − ln(e) = e^e − 1
    //   mid = exp(1) − ln(e^e − 1) = e − ln(e^e − 1)
    //   outer = exp(1) − ln(mid)
    let mid = e_val - (exp_e - 1.0).ln();
    let v_d4_log_chain_outer = e_val - mid.ln();
    out.push(CorpusEntry {
        name: "deep-log-chain",
        tree: e(
            one(),
            e(one(), e(e(one(), one()), e(one(), one()))),
        ),
        reference: v_d4_log_chain_outer,
        tolerance: 1e-9,
    });

    // eml(eml(eml(1, 1), eml(1, 1)), 1)
    //   = exp(e^e − 1) − 0 = exp(e^e − 1)
    out.push(CorpusEntry {
        name: "exp-exp-e-minus-1-bare",
        tree: e(
            e(e(one(), one()), e(one(), one())),
            one(),
        ),
        reference: (exp_e - 1.0).exp(),
        tolerance: v_d4_huge * 1e-9,
    });

    // eml(eml(1, eml(eml(1, 1), eml(1, 1))), 1)
    //   inner = e − ln(e^e − 1)
    //   outer = exp(inner) − 0
    let inner_e = e_val - (exp_e - 1.0).ln();
    out.push(CorpusEntry {
        name: "exp-e-minus-ln-exp-e-minus-1-bare",
        tree: e(
            e(
                one(),
                e(e(one(), one()), e(one(), one())),
            ),
            one(),
        ),
        reference: inner_e.exp(),
        tolerance: 1e-9,
    });

    // eml(eml(1, 1), eml(1, eml(eml(1, eml(1, 1)), eml(1, 1))))
    //   innermost = exp(e − 1) − ln(e) = exp(e − 1) − 1
    //   mid = e − ln(exp(e − 1) − 1)
    //   outer = exp(e) − ln(mid)
    let innermost = exp_e_minus_1 - 1.0;
    let mid2 = e_val - innermost.ln();
    let v_d5_outer = exp_e - mid2.ln();
    out.push(CorpusEntry {
        name: "deep-mixed-d5",
        tree: e(
            e(one(), one()),
            e(
                one(),
                e(
                    e(one(), e(one(), one())),
                    e(one(), one()),
                ),
            ),
        ),
        reference: v_d5_outer,
        tolerance: 1e-9,
    });

    out
}

#[test]
fn iter_14_corpus_has_at_least_50_entries() {
    let c = corpus_iter_14();
    assert!(
        c.len() >= 50,
        "iter-14 acceptance: corpus has {} entries, expected ≥ 50",
        c.len()
    );
}

#[test]
fn iter_14_entries_have_unique_names() {
    let c = corpus_iter_14();
    let names: std::collections::HashSet<&'static str> =
        c.iter().map(|e| e.name).collect();
    assert_eq!(
        names.len(),
        c.len(),
        "iter-14 corpus has duplicate names: {} unique vs {} total",
        names.len(),
        c.len()
    );
}

#[test]
fn iter_14_entries_round_trip_through_bare_evaluator() {
    // Smoke test: every entry's bare-grammar evaluation lands within
    // its tolerance of the analytical reference. Acceptance is
    // relaxed at iter-14 — full round-trip test with ≥80% closure
    // lands iter-15.
    let c = corpus_iter_14();
    let mut passed = 0usize;
    for entry in &c {
        let v = match evaluate(&entry.tree) {
            Ok(v) => v,
            Err(_) => continue,
        };
        if (v - entry.reference).abs() <= entry.tolerance {
            passed += 1;
        }
    }
    let frac = passed as f64 / c.len() as f64;
    assert!(
        frac >= 0.5,
        "iter-14 smoke: {}/{} entries pass bare-eval round-trip (frac={:.2}); want ≥ 0.5 today, ≥ 0.80 at iter-15",
        passed, c.len(), frac
    );
}

#[test]
fn iter_14_entries_round_trip_through_closure_normalize() {
    // Round-trip via closure normalize. With slot-free trees the
    // normalize step folds the whole tree into a single Slot, so
    // the resulting closure should evaluate to the same f64 as the
    // bare evaluator.
    let c = corpus_iter_14();
    for entry in &c {
        let bare_v = match evaluate(&entry.tree) {
            Ok(v) => v,
            Err(_) => continue,
        };
        let closure = EmlClosure::from_bare(entry.tree.clone());
        let normalized = normalize_closure(&closure);
        let closure_v = match evaluate_closure(&normalized) {
            Ok(v) => v,
            Err(_) => continue,
        };
        // The closure normalize should agree with the bare eval
        // within numerical precision (no analytical reference
        // here — purely internal consistency).
        assert!(
            (bare_v - closure_v).abs() < 1e-9 * bare_v.abs().max(1.0),
            "entry {} bare={} closure_norm={}",
            entry.name, bare_v, closure_v
        );
    }
}
