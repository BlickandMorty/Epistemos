//! HELIOS V5 — Scientific Calculator Basis (Lane 3 RESEARCH-ONLY).
//!
//! HELIOS-SCB guard
//!
//! Per HELIOS v4 preservation `source_docs/eml_formal_synthesis.md`
//! §1.1 + Odrzywołek arXiv:2603.21852 v2 (Apr 2026):
//!
//! > "The binary operator `eml(x, y) = exp(x) − ln(y)` can
//! >  generate every function in the **scientific calculator
//! >  basis** through finite composition trees of the form
//! >  `S → 1 | eml(S, S)`."
//!
//! The Scientific Calculator Basis (SCB) is a **closed-form
//! repertoire**, not an approximation class. The eml universality
//! theorem proves the basis is *generated*; it does NOT prove
//! universality over all continuous functions (bump functions,
//! Weierstrass functions, `|x|` at `x=0` are explicitly outside
//! the closure).
//!
//! ## §2.5.2 compliance posture
//!
//! Lane 3 RESEARCH-ONLY. Building requires `--features research`.

use serde::{Deserialize, Serialize};

/// One of six categories of the SCB per
/// `eml_formal_synthesis.md` §1.1.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ScbCategory {
    /// Constants: 0, 1, 2, e, π, i
    Constants,
    /// Arithmetic: +, −, *, /
    Arithmetic,
    /// Exponentiation: x^y, sqrt(x)
    Exponentiation,
    /// Transcendental: exp, ln, sin, cos, tan
    Transcendental,
    /// Inverse trigonometric: arcsin, arccos, arctan
    InverseTrigonometric,
    /// Hyperbolic: sinh, cosh, tanh
    Hyperbolic,
}

impl ScbCategory {
    /// Member count of the canonical SCB category.
    pub fn member_count(self) -> usize {
        match self {
            ScbCategory::Constants => 6,            // 0, 1, 2, e, π, i
            ScbCategory::Arithmetic => 4,           // +, −, *, /
            ScbCategory::Exponentiation => 2,       // x^y, sqrt
            ScbCategory::Transcendental => 5,       // exp, ln, sin, cos, tan
            ScbCategory::InverseTrigonometric => 3, // arcsin, arccos, arctan
            ScbCategory::Hyperbolic => 3,           // sinh, cosh, tanh
        }
    }

    /// Canonical member list per category.
    pub fn members(self) -> &'static [&'static str] {
        match self {
            ScbCategory::Constants => &["0", "1", "2", "e", "π", "i"],
            ScbCategory::Arithmetic => &["+", "−", "*", "/"],
            ScbCategory::Exponentiation => &["x^y", "sqrt"],
            ScbCategory::Transcendental => &["exp", "ln", "sin", "cos", "tan"],
            ScbCategory::InverseTrigonometric => &["arcsin", "arccos", "arctan"],
            ScbCategory::Hyperbolic => &["sinh", "cosh", "tanh"],
        }
    }
}

/// All six SCB categories in canonical doctrine order.
pub const SIX_CATEGORIES: [ScbCategory; 6] = [
    ScbCategory::Constants,
    ScbCategory::Arithmetic,
    ScbCategory::Exponentiation,
    ScbCategory::Transcendental,
    ScbCategory::InverseTrigonometric,
    ScbCategory::Hyperbolic,
];

/// Total count of SCB members across all six categories.
pub fn total_scb_size() -> usize {
    SIX_CATEGORIES.iter().map(|c| c.member_count()).sum()
}

/// EML grammar productions per Odrzywołek arXiv:2603.21852 §1.3:
///
/// ```text
/// S → 1 | eml(S, S)
/// ```
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum EmlProduction {
    /// Terminal: the constant 1.
    Terminal,
    /// Binary: eml(S, S) applied to two subtrees.
    BinaryEml,
}

impl EmlProduction {
    /// Returns true when this is the terminal production.
    pub fn is_terminal(self) -> bool {
        matches!(self, EmlProduction::Terminal)
    }
}

/// Both EML grammar productions in canonical order.
pub const TWO_PRODUCTIONS: [EmlProduction; 2] =
    [EmlProduction::Terminal, EmlProduction::BinaryEml];

/// Functions explicitly OUTSIDE the SCB closure per
/// `eml_formal_synthesis.md` §1.2 — non-analytic on at least
/// one point of their domain.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NonAnalyticOutsideClosure {
    /// Bump function (smooth but not analytic).
    BumpFunction,
    /// Weierstrass function (continuous everywhere, differentiable
    /// nowhere).
    WeierstrassFunction,
    /// Absolute value `|x|` at x=0 (non-analytic on the real line).
    AbsoluteValueAtZero,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn six_categories_in_canonical_doctrine_order() {
        assert_eq!(SIX_CATEGORIES.len(), 6);
        assert_eq!(SIX_CATEGORIES[0], ScbCategory::Constants);
        assert_eq!(SIX_CATEGORIES[5], ScbCategory::Hyperbolic);
    }

    #[test]
    fn six_categories_are_distinct() {
        let set: std::collections::HashSet<ScbCategory> = SIX_CATEGORIES.iter().copied().collect();
        assert_eq!(set.len(), 6);
    }

    #[test]
    fn member_count_matches_explicit_list_length() {
        for cat in SIX_CATEGORIES {
            assert_eq!(cat.member_count(), cat.members().len());
        }
    }

    #[test]
    fn total_scb_size_is_23() {
        // 6 + 4 + 2 + 5 + 3 + 3 = 23 canonical SCB members.
        assert_eq!(total_scb_size(), 23);
    }

    #[test]
    fn constants_include_e_pi_i() {
        let constants = ScbCategory::Constants.members();
        assert!(constants.contains(&"e"));
        assert!(constants.contains(&"π"));
        assert!(constants.contains(&"i"));
    }

    #[test]
    fn transcendentals_include_canonical_five() {
        let trans = ScbCategory::Transcendental.members();
        for name in ["exp", "ln", "sin", "cos", "tan"] {
            assert!(trans.contains(&name));
        }
    }

    #[test]
    fn arithmetic_has_four_operators() {
        // +, −, *, / per the canonical doctrine.
        assert_eq!(ScbCategory::Arithmetic.member_count(), 4);
    }

    #[test]
    fn eml_grammar_has_exactly_two_productions() {
        assert_eq!(TWO_PRODUCTIONS.len(), 2);
        assert!(TWO_PRODUCTIONS.contains(&EmlProduction::Terminal));
        assert!(TWO_PRODUCTIONS.contains(&EmlProduction::BinaryEml));
    }

    #[test]
    fn terminal_production_is_distinct_from_binary() {
        assert_ne!(EmlProduction::Terminal, EmlProduction::BinaryEml);
        assert!(EmlProduction::Terminal.is_terminal());
        assert!(!EmlProduction::BinaryEml.is_terminal());
    }

    #[test]
    fn three_non_analytic_functions_are_outside_closure() {
        // Per the doctrine, these are explicit non-members.
        let outside = [
            NonAnalyticOutsideClosure::BumpFunction,
            NonAnalyticOutsideClosure::WeierstrassFunction,
            NonAnalyticOutsideClosure::AbsoluteValueAtZero,
        ];
        let set: std::collections::HashSet<NonAnalyticOutsideClosure> =
            outside.iter().copied().collect();
        assert_eq!(set.len(), 3);
    }

    #[test]
    fn category_serializes_in_snake_case() {
        for (cat, expected) in [
            (ScbCategory::Constants, "\"constants\""),
            (ScbCategory::Arithmetic, "\"arithmetic\""),
            (ScbCategory::Exponentiation, "\"exponentiation\""),
            (ScbCategory::Transcendental, "\"transcendental\""),
            (ScbCategory::InverseTrigonometric, "\"inverse_trigonometric\""),
            (ScbCategory::Hyperbolic, "\"hyperbolic\""),
        ] {
            assert_eq!(serde_json::to_string(&cat).unwrap(), expected);
        }
    }

    #[test]
    fn eml_production_serializes_in_snake_case() {
        assert_eq!(serde_json::to_string(&EmlProduction::Terminal).unwrap(), "\"terminal\"");
        assert_eq!(serde_json::to_string(&EmlProduction::BinaryEml).unwrap(), "\"binary_eml\"");
    }

    #[test]
    fn category_round_trips_through_json() {
        for cat in SIX_CATEGORIES {
            let json = serde_json::to_string(&cat).unwrap();
            let parsed: ScbCategory = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, cat);
        }
    }
}
