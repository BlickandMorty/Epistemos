//! Source:
//! - Belnap, N. D., "A Useful Four-Valued Logic", in Modern Uses of
//!   Multiple-Valued Logic (Reidel, 1977) — canonical FDE
//!   (First Degree Entailment) construction.
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.6.4 — Belnap FDE 4-valued extension beyond K3 +
//!   5 directional operators (Up/Down/Sideways/Inward/OnItself) on
//!   claim graph.
//! - Anderson & Belnap, "Entailment: The Logic of Relevance and
//!   Necessity" Vol. I (Princeton, 1975) — relevance-logic context.
//!
//! # Wave J B.6.4 — Belnap FDE substrate
//!
//! Four truth values arranged in a bilattice:
//!
//! ```text
//!         Both (information lattice top)
//!        /    \
//!     True    False    (truth lattice axis)
//!        \    /
//!         Neither (information lattice bottom)
//! ```
//!
//! Operations:
//! - `NOT(a)` swaps True ↔ False; Both and Neither fixed.
//! - `AND(a, b)` = meet on the truth lattice.
//! - `OR(a, b)` = join on the truth lattice.
//! - `IMPLIES(a, b)` = `NOT(a) OR b` (classical equivalent).
//! - `info_join(a, b)` = join on the **information** lattice (iter 92).
//!   Distinct from `or`: pools evidence from two sources, so
//!   `True ⊔_info False = Both` (not True).
//! - `info_meet(a, b)` = meet on the information lattice (iter 92).
//!   Distinct from `and`: agreement between two sources, so
//!   `True ⊓_info False = Neither` (not False).
//!
//! Five directional operators per driver §5 are sketched as the
//! [`Direction`] enum + the per-direction propagation primitive. Real
//! claim-graph propagation lives in [`super::super::resonance`] and
//! cognitive_dag/; substrate floor here owns just the direction enum
//! + the truth-value composition that those modules consume.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum BelnapValue {
    True,
    False,
    Both,
    Neither,
}

impl BelnapValue {
    pub fn not(self) -> Self {
        match self {
            BelnapValue::True => BelnapValue::False,
            BelnapValue::False => BelnapValue::True,
            BelnapValue::Both => BelnapValue::Both,
            BelnapValue::Neither => BelnapValue::Neither,
        }
    }

    pub fn and(self, other: BelnapValue) -> BelnapValue {
        use BelnapValue::*;
        match (self, other) {
            (False, _) | (_, False) => False,
            (Neither, _) | (_, Neither) => {
                if self == True || other == True { Neither } else if self == Both || other == Both { False } else { Neither }
            }
            (Both, Both) => Both,
            (Both, True) | (True, Both) => Both,
            (True, True) => True,
        }
    }

    pub fn or(self, other: BelnapValue) -> BelnapValue {
        use BelnapValue::*;
        match (self, other) {
            (True, _) | (_, True) => True,
            (Neither, _) | (_, Neither) => {
                if self == False || other == False { Neither } else if self == Both || other == Both { True } else { Neither }
            }
            (Both, Both) => Both,
            (Both, False) | (False, Both) => Both,
            (False, False) => False,
        }
    }

    pub fn implies(self, other: BelnapValue) -> BelnapValue {
        self.not().or(other)
    }

    /// Information-lattice join (pool information from two sources).
    /// Distinct from [`or`]: the truth lattice orders False < T/N/B < True;
    /// the information lattice orders Neither < T/F < Both. Combining
    /// True + False on the info lattice yields Both (we hold both pieces
    /// of evidence), not True (which is the truth-lattice join).
    ///
    /// Per Belnap 1977 §3 — "the four-valued logic with two orderings".
    pub fn info_join(self, other: BelnapValue) -> BelnapValue {
        use BelnapValue::*;
        match (self, other) {
            // Bottom (Neither) is absorbed by the other side.
            (Neither, x) | (x, Neither) => x,
            // Top (Both) absorbs everything.
            (Both, _) | (_, Both) => Both,
            // Same → same.
            (True, True) => True,
            (False, False) => False,
            // Conflict between True and False produces Both
            // (we hold both pieces of evidence).
            (True, False) | (False, True) => Both,
        }
    }

    /// Information-lattice meet (greatest agreement between two sources).
    /// Distinct from [`and`]: with one source saying True and another
    /// saying False, the info-meet is Neither (no common evidence) while
    /// the truth-meet is False.
    ///
    /// Per Belnap 1977 §3.
    pub fn info_meet(self, other: BelnapValue) -> BelnapValue {
        use BelnapValue::*;
        match (self, other) {
            // Top (Both) keeps whatever the other side has.
            (Both, x) | (x, Both) => x,
            // Bottom (Neither) absorbs to bottom.
            (Neither, _) | (_, Neither) => Neither,
            // Same → same.
            (True, True) => True,
            (False, False) => False,
            // Conflict → no agreement → Neither.
            (True, False) | (False, True) => Neither,
        }
    }

    pub const ALL: [BelnapValue; 4] = [
        BelnapValue::True,
        BelnapValue::False,
        BelnapValue::Both,
        BelnapValue::Neither,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            BelnapValue::True => "T",
            BelnapValue::False => "F",
            BelnapValue::Both => "B",
            BelnapValue::Neither => "N",
        }
    }
}

/// Five directional operators per driver §5 Phase B.6.4. Each direction
/// names how a propagation step moves through the claim graph.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum Direction {
    /// Toward broader / more general claims.
    Up,
    /// Toward narrower / more specific claims.
    Down,
    /// Lateral — sibling / co-attribute claims.
    Sideways,
    /// Inward — into the claim's own evidence list.
    Inward,
    /// Self-loop — the claim itself.
    OnItself,
}

impl Direction {
    pub const ALL: [Direction; 5] = [
        Direction::Up,
        Direction::Down,
        Direction::Sideways,
        Direction::Inward,
        Direction::OnItself,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            Direction::Up => "up",
            Direction::Down => "down",
            Direction::Sideways => "sideways",
            Direction::Inward => "inward",
            Direction::OnItself => "on_itself",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn four_distinct_belnap_values() {
        let s: std::collections::HashSet<_> = BelnapValue::ALL.iter().copied().collect();
        assert_eq!(s.len(), 4);
    }

    #[test]
    fn five_distinct_directions() {
        let s: std::collections::HashSet<_> = Direction::ALL.iter().copied().collect();
        assert_eq!(s.len(), 5);
    }

    #[test]
    fn belnap_codes_are_stable() {
        assert_eq!(BelnapValue::True.code(), "T");
        assert_eq!(BelnapValue::False.code(), "F");
        assert_eq!(BelnapValue::Both.code(), "B");
        assert_eq!(BelnapValue::Neither.code(), "N");
    }

    #[test]
    fn direction_codes_are_stable() {
        assert_eq!(Direction::Up.code(), "up");
        assert_eq!(Direction::Down.code(), "down");
        assert_eq!(Direction::Sideways.code(), "sideways");
        assert_eq!(Direction::Inward.code(), "inward");
        assert_eq!(Direction::OnItself.code(), "on_itself");
    }

    #[test]
    fn not_is_involutive() {
        for &v in &BelnapValue::ALL {
            assert_eq!(v.not().not(), v);
        }
    }

    #[test]
    fn not_swaps_true_false() {
        assert_eq!(BelnapValue::True.not(), BelnapValue::False);
        assert_eq!(BelnapValue::False.not(), BelnapValue::True);
    }

    #[test]
    fn not_fixes_both_and_neither() {
        assert_eq!(BelnapValue::Both.not(), BelnapValue::Both);
        assert_eq!(BelnapValue::Neither.not(), BelnapValue::Neither);
    }

    #[test]
    fn and_true_true_is_true() {
        assert_eq!(BelnapValue::True.and(BelnapValue::True), BelnapValue::True);
    }

    #[test]
    fn and_with_false_is_false() {
        for &v in &BelnapValue::ALL {
            assert_eq!(BelnapValue::False.and(v), BelnapValue::False);
            assert_eq!(v.and(BelnapValue::False), BelnapValue::False);
        }
    }

    #[test]
    fn or_with_true_is_true() {
        for &v in &BelnapValue::ALL {
            assert_eq!(BelnapValue::True.or(v), BelnapValue::True);
            assert_eq!(v.or(BelnapValue::True), BelnapValue::True);
        }
    }

    #[test]
    fn or_false_false_is_false() {
        assert_eq!(BelnapValue::False.or(BelnapValue::False), BelnapValue::False);
    }

    #[test]
    fn and_or_are_commutative() {
        for &a in &BelnapValue::ALL {
            for &b in &BelnapValue::ALL {
                assert_eq!(a.and(b), b.and(a), "AND not commutative at {:?}, {:?}", a, b);
                assert_eq!(a.or(b), b.or(a), "OR not commutative at {:?}, {:?}", a, b);
            }
        }
    }

    #[test]
    fn implies_classical_cases() {
        assert_eq!(BelnapValue::True.implies(BelnapValue::True), BelnapValue::True);
        assert_eq!(BelnapValue::True.implies(BelnapValue::False), BelnapValue::False);
        assert_eq!(BelnapValue::False.implies(BelnapValue::True), BelnapValue::True);
        assert_eq!(BelnapValue::False.implies(BelnapValue::False), BelnapValue::True);
    }

    #[test]
    fn both_serializes_through_serde_json() {
        let v = BelnapValue::Both;
        let json = serde_json::to_string(&v).unwrap();
        let back: BelnapValue = serde_json::from_str(&json).unwrap();
        assert_eq!(v, back);
    }

    #[test]
    fn direction_serializes_through_serde_json() {
        let d = Direction::OnItself;
        let json = serde_json::to_string(&d).unwrap();
        let back: Direction = serde_json::from_str(&json).unwrap();
        assert_eq!(d, back);
    }

    #[test]
    fn neither_and_neither_is_neither() {
        assert_eq!(
            BelnapValue::Neither.and(BelnapValue::Neither),
            BelnapValue::Neither
        );
    }

    #[test]
    fn both_and_true_is_both() {
        assert_eq!(BelnapValue::Both.and(BelnapValue::True), BelnapValue::Both);
        assert_eq!(BelnapValue::True.and(BelnapValue::Both), BelnapValue::Both);
    }

    // ── Information-lattice tests (iter 92) ─────────────────────────────────

    #[test]
    fn info_join_neither_is_identity() {
        for v in BelnapValue::ALL.iter() {
            assert_eq!(BelnapValue::Neither.info_join(*v), *v);
            assert_eq!(v.info_join(BelnapValue::Neither), *v);
        }
    }

    #[test]
    fn info_join_both_is_absorbing() {
        for v in BelnapValue::ALL.iter() {
            assert_eq!(BelnapValue::Both.info_join(*v), BelnapValue::Both);
            assert_eq!(v.info_join(BelnapValue::Both), BelnapValue::Both);
        }
    }

    #[test]
    fn info_join_true_false_is_both() {
        assert_eq!(
            BelnapValue::True.info_join(BelnapValue::False),
            BelnapValue::Both
        );
        assert_eq!(
            BelnapValue::False.info_join(BelnapValue::True),
            BelnapValue::Both
        );
    }

    #[test]
    fn info_join_same_value_is_same() {
        for v in BelnapValue::ALL.iter() {
            assert_eq!(v.info_join(*v), *v);
        }
    }

    #[test]
    fn info_meet_both_is_identity() {
        for v in BelnapValue::ALL.iter() {
            assert_eq!(BelnapValue::Both.info_meet(*v), *v);
            assert_eq!(v.info_meet(BelnapValue::Both), *v);
        }
    }

    #[test]
    fn info_meet_neither_is_absorbing() {
        for v in BelnapValue::ALL.iter() {
            assert_eq!(BelnapValue::Neither.info_meet(*v), BelnapValue::Neither);
            assert_eq!(v.info_meet(BelnapValue::Neither), BelnapValue::Neither);
        }
    }

    #[test]
    fn info_meet_true_false_is_neither() {
        assert_eq!(
            BelnapValue::True.info_meet(BelnapValue::False),
            BelnapValue::Neither
        );
        assert_eq!(
            BelnapValue::False.info_meet(BelnapValue::True),
            BelnapValue::Neither
        );
    }

    #[test]
    fn info_meet_same_value_is_same() {
        for v in BelnapValue::ALL.iter() {
            assert_eq!(v.info_meet(*v), *v);
        }
    }

    #[test]
    fn info_ops_distinct_from_truth_ops() {
        // On the truth lattice, True AND False = False.
        // On the info lattice, True ⊓ False = Neither.
        assert_eq!(
            BelnapValue::True.and(BelnapValue::False),
            BelnapValue::False
        );
        assert_eq!(
            BelnapValue::True.info_meet(BelnapValue::False),
            BelnapValue::Neither
        );
        // On the truth lattice, True OR False = True.
        // On the info lattice, True ⊔ False = Both.
        assert_eq!(
            BelnapValue::True.or(BelnapValue::False),
            BelnapValue::True
        );
        assert_eq!(
            BelnapValue::True.info_join(BelnapValue::False),
            BelnapValue::Both
        );
    }

    #[test]
    fn info_meet_and_join_commute() {
        for a in BelnapValue::ALL.iter() {
            for b in BelnapValue::ALL.iter() {
                assert_eq!(a.info_meet(*b), b.info_meet(*a));
                assert_eq!(a.info_join(*b), b.info_join(*a));
            }
        }
    }

    #[test]
    fn info_meet_and_join_idempotent() {
        for v in BelnapValue::ALL.iter() {
            assert_eq!(v.info_meet(*v), *v);
            assert_eq!(v.info_join(*v), *v);
        }
    }
}
