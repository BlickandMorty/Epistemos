//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `Accordion`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::Accordion`].
//!
//! # Wave I — Accordion component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AccordionItem {
    pub key: String,
    pub title: String,
    pub body: String,
    pub expanded: bool,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AccordionProps {
    pub items: Vec<AccordionItem>,
    pub allow_multi_expand: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum AccordionError {
    Empty,
    EmptyKey { index: usize },
    DuplicateKey,
    MultiExpandViolation,
}

impl AccordionError {
    pub const fn cause(&self) -> &'static str {
        match self {
            AccordionError::Empty => "empty",
            AccordionError::EmptyKey { .. } => "empty_key",
            AccordionError::DuplicateKey => "duplicate_key",
            AccordionError::MultiExpandViolation => "multi_expand_violation",
        }
    }

    /// Predicate: error pertains to a key collision or empty-key field
    /// (EmptyKey / DuplicateKey).
    pub const fn is_key_error(&self) -> bool {
        matches!(
            self,
            AccordionError::EmptyKey { .. } | AccordionError::DuplicateKey,
        )
    }

    /// Predicate: error pertains to the size/cardinality contract
    /// (Empty / MultiExpandViolation). Cross-surface invariant:
    /// `is_key_error XOR is_cardinality_error` partitions all variants.
    pub const fn is_cardinality_error(&self) -> bool {
        matches!(
            self,
            AccordionError::Empty | AccordionError::MultiExpandViolation,
        )
    }
}

impl AccordionProps {
    pub fn validate(&self) -> Result<(), AccordionError> {
        if self.items.is_empty() {
            return Err(AccordionError::Empty);
        }
        let mut seen: std::collections::HashSet<&str> = std::collections::HashSet::new();
        for (i, it) in self.items.iter().enumerate() {
            if it.key.is_empty() {
                return Err(AccordionError::EmptyKey { index: i });
            }
            if !seen.insert(&it.key) {
                return Err(AccordionError::DuplicateKey);
            }
        }
        if !self.allow_multi_expand {
            let expanded_count = self.items.iter().filter(|i| i.expanded).count();
            if expanded_count > 1 {
                return Err(AccordionError::MultiExpandViolation);
            }
        }
        Ok(())
    }

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Number of items.
    pub fn item_count(&self) -> usize {
        self.items.len()
    }

    /// Number of items currently expanded.
    pub fn expanded_count(&self) -> usize {
        self.items.iter().filter(|i| i.expanded).count()
    }

    /// Predicate: any item is expanded. Cross-surface invariant:
    /// `has_expanded iff expanded_count() > 0`.
    pub fn has_expanded(&self) -> bool {
        self.expanded_count() > 0
    }

    /// Lookup an item by key. Returns `None` for missing keys.
    pub fn lookup(&self, key: &str) -> Option<&AccordionItem> {
        self.items.iter().find(|i| i.key == key)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(k: &str, exp: bool) -> AccordionItem {
        AccordionItem {
            key: k.into(),
            title: "t".into(),
            body: "b".into(),
            expanded: exp,
        }
    }

    #[test]
    fn empty_rejected() {
        let a = AccordionProps {
            items: vec![],
            allow_multi_expand: false,
        };
        assert_eq!(a.validate().unwrap_err(), AccordionError::Empty);
    }

    #[test]
    fn valid_passes() {
        let a = AccordionProps {
            items: vec![item("a", true), item("b", false)],
            allow_multi_expand: false,
        };
        assert!(a.validate().is_ok());
    }

    #[test]
    fn empty_key_rejected() {
        let a = AccordionProps {
            items: vec![item("", false)],
            allow_multi_expand: false,
        };
        assert!(matches!(
            a.validate().unwrap_err(),
            AccordionError::EmptyKey { .. }
        ));
    }

    #[test]
    fn duplicate_key_rejected() {
        let a = AccordionProps {
            items: vec![item("k", false), item("k", false)],
            allow_multi_expand: true,
        };
        assert_eq!(a.validate().unwrap_err(), AccordionError::DuplicateKey);
    }

    #[test]
    fn multi_expand_violation_rejected() {
        let a = AccordionProps {
            items: vec![item("a", true), item("b", true)],
            allow_multi_expand: false,
        };
        assert_eq!(
            a.validate().unwrap_err(),
            AccordionError::MultiExpandViolation
        );
    }

    #[test]
    fn multi_expand_allowed_passes() {
        let a = AccordionProps {
            items: vec![item("a", true), item("b", true)],
            allow_multi_expand: true,
        };
        assert!(a.validate().is_ok());
    }

    #[test]
    fn serde_json_roundtrip() {
        let a = AccordionProps {
            items: vec![item("k", false)],
            allow_multi_expand: false,
        };
        let json = serde_json::to_string(&a).unwrap();
        let back: AccordionProps = serde_json::from_str(&json).unwrap();
        assert_eq!(a, back);
    }

    // ── diagnostic surface (iter 210) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [
            AccordionError::Empty,
            AccordionError::EmptyKey { index: 0 },
            AccordionError::DuplicateKey,
            AccordionError::MultiExpandViolation,
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 4);
    }

    #[test]
    fn error_classifiers_partition() {
        // Cross-surface invariant: is_key_error XOR is_cardinality_error.
        for e in [
            AccordionError::Empty,
            AccordionError::EmptyKey { index: 0 },
            AccordionError::DuplicateKey,
            AccordionError::MultiExpandViolation,
        ] {
            assert_ne!(e.is_key_error(), e.is_cardinality_error());
        }
    }

    #[test]
    fn item_count_matches_vec_len() {
        let a = AccordionProps {
            items: vec![item("a", false), item("b", false), item("c", true)],
            allow_multi_expand: false,
        };
        assert_eq!(a.item_count(), 3);
    }

    #[test]
    fn expanded_count_and_has_expanded_aligned() {
        // Cross-surface invariant: has_expanded iff expanded_count() > 0.
        let none = AccordionProps {
            items: vec![item("a", false), item("b", false)],
            allow_multi_expand: false,
        };
        assert_eq!(none.expanded_count(), 0);
        assert!(!none.has_expanded());

        let some = AccordionProps {
            items: vec![item("a", false), item("b", true), item("c", true)],
            allow_multi_expand: true,
        };
        assert_eq!(some.expanded_count(), 2);
        assert!(some.has_expanded());
    }

    #[test]
    fn lookup_finds_existing_and_misses_absent() {
        let a = AccordionProps {
            items: vec![item("a", false), item("b", true)],
            allow_multi_expand: true,
        };
        assert_eq!(a.lookup("a").unwrap().key, "a");
        assert!(a.lookup("b").unwrap().expanded);
        assert!(a.lookup("zzz").is_none());
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = AccordionProps {
            items: vec![item("a", false)],
            allow_multi_expand: false,
        };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
