//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `TableOfContents`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::TableOfContents`].
//!
//! # Wave I — TableOfContents component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TocEntry {
    pub anchor: String,
    pub title: String,
    pub depth: u8,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TableOfContentsProps {
    pub entries: Vec<TocEntry>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TableOfContentsError {
    Empty,
    EmptyAnchor { index: usize },
    DepthOutOfRange { index: usize, depth: u8 },
}

impl TableOfContentsError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            TableOfContentsError::Empty => "empty",
            TableOfContentsError::EmptyAnchor { .. } => "empty_anchor",
            TableOfContentsError::DepthOutOfRange { .. } => "depth_out_of_range",
        }
    }

    pub const fn is_empty(&self) -> bool {
        matches!(self, TableOfContentsError::Empty)
    }

    pub const fn is_empty_anchor(&self) -> bool {
        matches!(self, TableOfContentsError::EmptyAnchor { .. })
    }

    /// Cross-surface invariant: exactly one of `is_empty /
    /// is_empty_anchor / is_depth_out_of_range` is true per variant
    /// (3-way partition).
    pub const fn is_depth_out_of_range(&self) -> bool {
        matches!(self, TableOfContentsError::DepthOutOfRange { .. })
    }
}

/// HTML heading depth bounds: `h1` (1) through `h6` (6).
pub const TOC_MIN_DEPTH: u8 = 1;
pub const TOC_MAX_DEPTH: u8 = 6;

impl TableOfContentsProps {
    pub fn validate(&self) -> Result<(), TableOfContentsError> {
        if self.entries.is_empty() {
            return Err(TableOfContentsError::Empty);
        }
        for (i, e) in self.entries.iter().enumerate() {
            if e.anchor.is_empty() {
                return Err(TableOfContentsError::EmptyAnchor { index: i });
            }
            if !(TOC_MIN_DEPTH..=TOC_MAX_DEPTH).contains(&e.depth) {
                return Err(TableOfContentsError::DepthOutOfRange { index: i, depth: e.depth });
            }
        }
        Ok(())
    }

    pub fn max_depth(&self) -> u8 {
        self.entries.iter().map(|e| e.depth).max().unwrap_or(0)
    }

    /// Predicate alias for `validate().is_ok()`.
    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Minimum depth across entries, or `None` for empty TOC.
    pub fn min_depth(&self) -> Option<u8> {
        self.entries.iter().map(|e| e.depth).min()
    }

    /// Number of entries.
    pub fn entry_count(&self) -> usize {
        self.entries.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry(a: &str, t: &str, d: u8) -> TocEntry {
        TocEntry { anchor: a.into(), title: t.into(), depth: d }
    }

    #[test]
    fn empty_rejected() {
        let p = TableOfContentsProps { entries: vec![] };
        assert_eq!(p.validate().unwrap_err(), TableOfContentsError::Empty);
    }

    #[test]
    fn valid_passes() {
        let p = TableOfContentsProps { entries: vec![entry("#intro", "Intro", 1)] };
        assert!(p.validate().is_ok());
    }

    #[test]
    fn empty_anchor_rejected() {
        let p = TableOfContentsProps { entries: vec![entry("", "x", 1)] };
        assert!(matches!(p.validate().unwrap_err(), TableOfContentsError::EmptyAnchor { .. }));
    }

    #[test]
    fn depth_zero_rejected() {
        let p = TableOfContentsProps { entries: vec![entry("#a", "x", 0)] };
        assert!(matches!(p.validate().unwrap_err(), TableOfContentsError::DepthOutOfRange { .. }));
    }

    #[test]
    fn depth_seven_rejected() {
        let p = TableOfContentsProps { entries: vec![entry("#a", "x", 7)] };
        assert!(matches!(p.validate().unwrap_err(), TableOfContentsError::DepthOutOfRange { .. }));
    }

    #[test]
    fn max_depth_correct() {
        let p = TableOfContentsProps {
            entries: vec![entry("#a", "A", 1), entry("#b", "B", 3), entry("#c", "C", 2)],
        };
        assert_eq!(p.max_depth(), 3);
    }

    #[test]
    fn serde_json_roundtrip() {
        let p = TableOfContentsProps { entries: vec![entry("#a", "A", 1)] };
        let json = serde_json::to_string(&p).unwrap();
        let back: TableOfContentsProps = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }

    // ── diagnostic surface (iter 203) ────────────────────────────────────────

    #[test]
    fn depth_bounds_pinned_at_h1_h6() {
        assert_eq!(TOC_MIN_DEPTH, 1);
        assert_eq!(TOC_MAX_DEPTH, 6);
    }

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [
            TableOfContentsError::Empty,
            TableOfContentsError::EmptyAnchor { index: 0 },
            TableOfContentsError::DepthOutOfRange { index: 0, depth: 7 },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 3);
    }

    #[test]
    fn error_3way_classifier_partition() {
        for e in [
            TableOfContentsError::Empty,
            TableOfContentsError::EmptyAnchor { index: 0 },
            TableOfContentsError::DepthOutOfRange { index: 0, depth: 7 },
        ] {
            let trio = [e.is_empty(), e.is_empty_anchor(), e.is_depth_out_of_range()];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", e);
        }
    }

    #[test]
    fn min_depth_none_on_empty() {
        let p = TableOfContentsProps { entries: vec![] };
        assert_eq!(p.min_depth(), None);
    }

    #[test]
    fn min_depth_picks_smallest() {
        let p = TableOfContentsProps {
            entries: vec![entry("#a", "A", 3), entry("#b", "B", 1), entry("#c", "C", 5)],
        };
        assert_eq!(p.min_depth(), Some(1));
    }

    #[test]
    fn min_depth_leq_max_depth_invariant() {
        // Cross-surface invariant: min_depth ≤ max_depth for non-empty TOC.
        let p = TableOfContentsProps {
            entries: vec![entry("#a", "A", 2), entry("#b", "B", 4), entry("#c", "C", 1)],
        };
        assert!(p.min_depth().unwrap() <= p.max_depth());
    }

    #[test]
    fn entry_count_matches_entries_len() {
        let p = TableOfContentsProps {
            entries: vec![entry("#a", "A", 1), entry("#b", "B", 2)],
        };
        assert_eq!(p.entry_count(), 2);
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = TableOfContentsProps { entries: vec![entry("#a", "A", 1)] };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
