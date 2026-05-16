//! Source: V6.1 integration §1.2. Grammar `S → 1 | eml(S, S)`.
//!
//! Symbolic representation of expressions in the EML term algebra.
//! Substrate floor for the Liouvillian-elementary universality result —
//! every elementary function on the Liouvillian-solvable subdomain
//! decomposes into an EML tree (Odrzywołek arXiv:2603.21852).

use serde::{Deserialize, Serialize};

/// Term in the EML grammar. Leaf is the terminal `1`; internal node is
/// `eml(left, right)` where the arguments are themselves EML terms.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub enum EmlExpr {
    One,
    Eml(Box<EmlExpr>, Box<EmlExpr>),
}

impl EmlExpr {
    pub fn eml(left: EmlExpr, right: EmlExpr) -> Self {
        EmlExpr::Eml(Box::new(left), Box::new(right))
    }

    /// Tree depth: `One = 0`, `Eml(l, r) = 1 + max(depth(l), depth(r))`.
    /// Per V6.1 §1.2: depth ≤ 4 suffices for symbolic regression of
    /// closed forms within the Liouvillian-solvable subdomain.
    pub fn depth(&self) -> usize {
        match self {
            EmlExpr::One => 0,
            EmlExpr::Eml(l, r) => 1 + l.depth().max(r.depth()),
        }
    }

    /// Node count.
    pub fn size(&self) -> usize {
        match self {
            EmlExpr::One => 1,
            EmlExpr::Eml(l, r) => 1 + l.size() + r.size(),
        }
    }

    /// Count of `One` leaves in the tree. Per the binary-tree
    /// identity `leaves = internal_nodes + 1`, this equals
    /// `(size + 1) / 2` for any well-formed EmlExpr.
    pub fn leaf_count(&self) -> usize {
        match self {
            EmlExpr::One => 1,
            EmlExpr::Eml(l, r) => l.leaf_count() + r.leaf_count(),
        }
    }

    /// Count of `Eml(_, _)` internal nodes. For a binary tree:
    /// `internal_nodes = leaves - 1`.
    pub fn internal_node_count(&self) -> usize {
        match self {
            EmlExpr::One => 0,
            EmlExpr::Eml(l, r) => 1 + l.internal_node_count() + r.internal_node_count(),
        }
    }

    /// True iff every internal `Eml` has `depth(left) == depth(right)`.
    /// V6.1 §1.2 production-depth bound is 4; symbolic-regression
    /// search prefers balanced trees to keep the expression's max
    /// depth tight relative to its size. Single-leaf `One` is
    /// vacuously balanced.
    pub fn is_balanced(&self) -> bool {
        match self {
            EmlExpr::One => true,
            EmlExpr::Eml(l, r) => l.depth() == r.depth() && l.is_balanced() && r.is_balanced(),
        }
    }
}

/// Trivial root expression: just the terminal `1`. Useful as a
/// starting point for symbolic-regression search.
pub fn eml_grammar_root() -> EmlExpr {
    EmlExpr::One
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn one_has_depth_zero() {
        assert_eq!(EmlExpr::One.depth(), 0);
    }

    #[test]
    fn one_has_size_one() {
        assert_eq!(EmlExpr::One.size(), 1);
    }

    #[test]
    fn single_eml_has_depth_one() {
        let e = EmlExpr::eml(EmlExpr::One, EmlExpr::One);
        assert_eq!(e.depth(), 1);
    }

    #[test]
    fn single_eml_has_size_three() {
        let e = EmlExpr::eml(EmlExpr::One, EmlExpr::One);
        assert_eq!(e.size(), 3);
    }

    #[test]
    fn nested_eml_depth_takes_max_path() {
        // eml(eml(1, 1), 1) → depth 2 on left, depth 0 on right → 1 + max = 2
        let e = EmlExpr::eml(
            EmlExpr::eml(EmlExpr::One, EmlExpr::One),
            EmlExpr::One,
        );
        assert_eq!(e.depth(), 2);
    }

    #[test]
    fn depth_four_tree_is_constructible() {
        // V6.1 §1.2 bound: depth ≤ 4 suffices.
        let mut e = EmlExpr::One;
        for _ in 0..4 {
            e = EmlExpr::eml(e, EmlExpr::One);
        }
        assert_eq!(e.depth(), 4);
    }

    #[test]
    fn grammar_root_is_one() {
        assert_eq!(eml_grammar_root(), EmlExpr::One);
    }

    #[test]
    fn expr_roundtrips_through_serde_json() {
        let e = EmlExpr::eml(
            EmlExpr::eml(EmlExpr::One, EmlExpr::One),
            EmlExpr::One,
        );
        let json = serde_json::to_string(&e).unwrap();
        let back: EmlExpr = serde_json::from_str(&json).unwrap();
        assert_eq!(e, back);
    }

    #[test]
    fn size_grows_super_linearly_with_depth() {
        let mut e = EmlExpr::One;
        let sizes: Vec<usize> = (0..5)
            .map(|_| {
                let s = e.size();
                e = EmlExpr::eml(e.clone(), e.clone());
                s
            })
            .collect();
        assert_eq!(sizes, vec![1, 3, 7, 15, 31]);
    }

    // ── leaf_count + internal_node_count + is_balanced tests (iter 132) ─────

    #[test]
    fn one_has_leaf_count_one() {
        assert_eq!(EmlExpr::One.leaf_count(), 1);
    }

    #[test]
    fn one_has_zero_internal_nodes() {
        assert_eq!(EmlExpr::One.internal_node_count(), 0);
    }

    #[test]
    fn binary_tree_identity_leaves_equals_internal_plus_one() {
        // For ANY EmlExpr: leaf_count = internal_node_count + 1.
        // Verified across depth-0..4 balanced trees.
        let mut e = EmlExpr::One;
        for _ in 0..5 {
            assert_eq!(e.leaf_count(), e.internal_node_count() + 1);
            e = EmlExpr::eml(e.clone(), e.clone());
        }
    }

    #[test]
    fn size_equals_leaves_plus_internal() {
        let mut e = EmlExpr::One;
        for _ in 0..5 {
            assert_eq!(e.size(), e.leaf_count() + e.internal_node_count());
            e = EmlExpr::eml(e.clone(), e.clone());
        }
    }

    #[test]
    fn one_is_balanced() {
        assert!(EmlExpr::One.is_balanced());
    }

    #[test]
    fn balanced_pair_is_balanced() {
        let e = EmlExpr::eml(EmlExpr::One, EmlExpr::One);
        assert!(e.is_balanced());
    }

    #[test]
    fn left_chain_is_unbalanced() {
        // Eml(Eml(1, 1), 1) → left depth 1, right depth 0.
        let unbalanced = EmlExpr::eml(
            EmlExpr::eml(EmlExpr::One, EmlExpr::One),
            EmlExpr::One,
        );
        assert!(!unbalanced.is_balanced());
    }

    #[test]
    fn fully_balanced_perfect_binary_tree_passes() {
        // Depth-3 perfect binary tree.
        let l1 = EmlExpr::eml(EmlExpr::One, EmlExpr::One);
        let l2 = EmlExpr::eml(l1.clone(), l1.clone());
        let l3 = EmlExpr::eml(l2.clone(), l2.clone());
        assert!(l3.is_balanced());
        assert_eq!(l3.depth(), 3);
        assert_eq!(l3.leaf_count(), 8); // 2^3
    }

    #[test]
    fn leaf_count_matches_pow2_for_perfect_tree() {
        let mut e = EmlExpr::One;
        for d in 0..5 {
            assert_eq!(e.leaf_count(), 1 << d);
            e = EmlExpr::eml(e.clone(), e.clone());
        }
    }
}
