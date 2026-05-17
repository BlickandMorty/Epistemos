//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `Breadcrumbs`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::Breadcrumbs`].
//!
//! # Wave I — Breadcrumbs component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Invariant: last item must not link (current
//! page is not a link). Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct BreadcrumbItem {
    pub label: String,
    pub href: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct BreadcrumbsProps {
    pub items: Vec<BreadcrumbItem>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum BreadcrumbsError {
    Empty,
    EmptyLabel { index: usize },
    LastItemMustNotLink,
}

impl BreadcrumbsError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            BreadcrumbsError::Empty => "empty",
            BreadcrumbsError::EmptyLabel { .. } => "empty_label",
            BreadcrumbsError::LastItemMustNotLink => "last_item_must_not_link",
        }
    }

    pub const fn is_empty(&self) -> bool {
        matches!(self, BreadcrumbsError::Empty)
    }

    pub const fn is_empty_label(&self) -> bool {
        matches!(self, BreadcrumbsError::EmptyLabel { .. })
    }

    /// Cross-surface invariant: exactly one of `is_empty /
    /// is_empty_label / is_last_must_not_link` is true per variant
    /// (3-way partition).
    pub const fn is_last_must_not_link(&self) -> bool {
        matches!(self, BreadcrumbsError::LastItemMustNotLink)
    }
}

impl BreadcrumbItem {
    /// Predicate: the item is the current page (no href). Cross-
    /// surface invariant: in a valid Breadcrumbs, the last item
    /// satisfies `is_current() == true`.
    pub fn is_current(&self) -> bool {
        self.href.is_none()
    }

    /// Predicate: the item links elsewhere (`href.is_some()`).
    pub fn is_link(&self) -> bool {
        self.href.is_some()
    }
}

impl BreadcrumbsProps {
    pub fn validate(&self) -> Result<(), BreadcrumbsError> {
        if self.items.is_empty() {
            return Err(BreadcrumbsError::Empty);
        }
        for (i, it) in self.items.iter().enumerate() {
            if it.label.is_empty() {
                return Err(BreadcrumbsError::EmptyLabel { index: i });
            }
        }
        if let Some(last) = self.items.last() {
            if last.href.is_some() {
                return Err(BreadcrumbsError::LastItemMustNotLink);
            }
        }
        Ok(())
    }

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Number of items in the trail.
    pub fn depth(&self) -> usize {
        self.items.len()
    }

    /// Number of items that have a link (`href.is_some()`).
    /// Cross-surface invariant: in a valid Breadcrumbs,
    /// `link_count == depth - 1` (all but the last item link).
    pub fn link_count(&self) -> usize {
        self.items.iter().filter(|it| it.is_link()).count()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(label: &str, href: Option<&str>) -> BreadcrumbItem {
        BreadcrumbItem {
            label: label.into(),
            href: href.map(String::from),
        }
    }

    #[test]
    fn empty_rejected() {
        let b = BreadcrumbsProps { items: vec![] };
        assert_eq!(b.validate().unwrap_err(), BreadcrumbsError::Empty);
    }

    #[test]
    fn valid_passes() {
        let b = BreadcrumbsProps {
            items: vec![item("Home", Some("/")), item("Notes", Some("/notes")), item("Current", None)],
        };
        assert!(b.validate().is_ok());
    }

    #[test]
    fn single_item_no_link_passes() {
        let b = BreadcrumbsProps { items: vec![item("Only", None)] };
        assert!(b.validate().is_ok());
    }

    #[test]
    fn empty_label_rejected() {
        let b = BreadcrumbsProps { items: vec![item("", None)] };
        assert!(matches!(b.validate().unwrap_err(), BreadcrumbsError::EmptyLabel { .. }));
    }

    #[test]
    fn last_item_links_rejected() {
        let b = BreadcrumbsProps {
            items: vec![item("Home", Some("/")), item("Current", Some("/c"))],
        };
        assert_eq!(b.validate().unwrap_err(), BreadcrumbsError::LastItemMustNotLink);
    }

    #[test]
    fn serde_json_roundtrip() {
        let b = BreadcrumbsProps {
            items: vec![item("Home", Some("/")), item("Last", None)],
        };
        let json = serde_json::to_string(&b).unwrap();
        let back: BreadcrumbsProps = serde_json::from_str(&json).unwrap();
        assert_eq!(b, back);
    }

    // ── diagnostic surface (iter 201) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [
            BreadcrumbsError::Empty,
            BreadcrumbsError::EmptyLabel { index: 0 },
            BreadcrumbsError::LastItemMustNotLink,
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 3);
    }

    #[test]
    fn error_3way_classifier_partition() {
        // Cross-surface invariant.
        for e in [
            BreadcrumbsError::Empty,
            BreadcrumbsError::EmptyLabel { index: 0 },
            BreadcrumbsError::LastItemMustNotLink,
        ] {
            let trio = [e.is_empty(), e.is_empty_label(), e.is_last_must_not_link()];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", e);
        }
    }

    #[test]
    fn item_is_current_iff_no_href() {
        // Cross-surface invariant: is_current XOR is_link.
        let cur = item("X", None);
        let lk = item("X", Some("/x"));
        assert!(cur.is_current());
        assert!(!cur.is_link());
        assert!(!lk.is_current());
        assert!(lk.is_link());
        assert_ne!(cur.is_current(), cur.is_link());
        assert_ne!(lk.is_current(), lk.is_link());
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = BreadcrumbsProps {
            items: vec![item("Home", Some("/")), item("Current", None)],
        };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }

    #[test]
    fn depth_matches_items_len() {
        let b = BreadcrumbsProps {
            items: vec![item("a", Some("/")), item("b", Some("/b")), item("c", None)],
        };
        assert_eq!(b.depth(), 3);
        assert_eq!(b.depth(), b.items.len());
    }

    #[test]
    fn link_count_invariant_for_valid_breadcrumbs() {
        // Cross-surface invariant: link_count == depth - 1 for valid trail.
        let b = BreadcrumbsProps {
            items: vec![
                item("Home", Some("/")),
                item("Notes", Some("/notes")),
                item("Note 1", Some("/notes/1")),
                item("Current", None),
            ],
        };
        assert!(b.is_valid());
        assert_eq!(b.link_count(), b.depth() - 1);
    }
}
