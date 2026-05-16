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
}
