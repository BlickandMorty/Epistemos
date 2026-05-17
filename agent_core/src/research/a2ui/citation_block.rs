//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `CitationBlock`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::CitationBlock`].
//!
//! # Wave I — CitationBlock component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Citation {
    pub source_uri: String,
    pub title: String,
    pub quote: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CitationBlockProps {
    pub citations: Vec<Citation>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum CitationBlockError {
    Empty,
    MissingSourceUri { index: usize },
    EmptyQuote { index: usize },
}

impl CitationBlockError {
    pub const fn cause(&self) -> &'static str {
        match self {
            CitationBlockError::Empty => "empty",
            CitationBlockError::MissingSourceUri { .. } => "missing_source_uri",
            CitationBlockError::EmptyQuote { .. } => "empty_quote",
        }
    }

    pub const fn is_empty(&self) -> bool {
        matches!(self, CitationBlockError::Empty)
    }

    pub const fn is_missing_uri(&self) -> bool {
        matches!(self, CitationBlockError::MissingSourceUri { .. })
    }

    /// Cross-surface invariant: exactly one of `is_empty /
    /// is_missing_uri / is_empty_quote` is true per variant (3-way
    /// partition).
    pub const fn is_empty_quote(&self) -> bool {
        matches!(self, CitationBlockError::EmptyQuote { .. })
    }
}

impl Citation {
    /// Predicate: this citation carries a non-empty title in addition
    /// to the source URI + quote. Pure-URI citations (no title) still
    /// validate but render differently in the Swift dispatcher.
    pub fn has_title(&self) -> bool {
        !self.title.is_empty()
    }
}

impl CitationBlockProps {
    pub fn validate(&self) -> Result<(), CitationBlockError> {
        if self.citations.is_empty() {
            return Err(CitationBlockError::Empty);
        }
        for (i, c) in self.citations.iter().enumerate() {
            if c.source_uri.is_empty() {
                return Err(CitationBlockError::MissingSourceUri { index: i });
            }
            if c.quote.is_empty() {
                return Err(CitationBlockError::EmptyQuote { index: i });
            }
        }
        Ok(())
    }

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Number of citations.
    pub fn citation_count(&self) -> usize {
        self.citations.len()
    }

    /// Number of citations with a non-empty title (informational —
    /// validate() does NOT require titles).
    pub fn titled_count(&self) -> usize {
        self.citations.iter().filter(|c| c.has_title()).count()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cit(uri: &str, q: &str) -> Citation {
        Citation { source_uri: uri.into(), title: "t".into(), quote: q.into() }
    }

    #[test]
    fn empty_rejected() {
        let c = CitationBlockProps { citations: vec![] };
        assert_eq!(c.validate().unwrap_err(), CitationBlockError::Empty);
    }

    #[test]
    fn valid_passes() {
        let c = CitationBlockProps { citations: vec![cit("x://y", "quote")] };
        assert!(c.validate().is_ok());
    }

    #[test]
    fn missing_uri_rejected() {
        let c = CitationBlockProps { citations: vec![cit("", "q")] };
        assert!(matches!(c.validate().unwrap_err(), CitationBlockError::MissingSourceUri { .. }));
    }

    #[test]
    fn empty_quote_rejected() {
        let c = CitationBlockProps { citations: vec![cit("x", "")] };
        assert!(matches!(c.validate().unwrap_err(), CitationBlockError::EmptyQuote { .. }));
    }

    #[test]
    fn serde_json_roundtrip() {
        let c = CitationBlockProps { citations: vec![cit("x", "q")] };
        let json = serde_json::to_string(&c).unwrap();
        let back: CitationBlockProps = serde_json::from_str(&json).unwrap();
        assert_eq!(c, back);
    }

    // ── diagnostic surface (iter 204) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [
            CitationBlockError::Empty,
            CitationBlockError::MissingSourceUri { index: 0 },
            CitationBlockError::EmptyQuote { index: 0 },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 3);
    }

    #[test]
    fn error_3way_classifier_partition() {
        // Cross-surface invariant.
        for e in [
            CitationBlockError::Empty,
            CitationBlockError::MissingSourceUri { index: 0 },
            CitationBlockError::EmptyQuote { index: 0 },
        ] {
            let trio = [e.is_empty(), e.is_missing_uri(), e.is_empty_quote()];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", e);
        }
    }

    #[test]
    fn citation_has_title_aligned_with_field() {
        let titled = cit("x://y", "q"); // helper hardcodes "t" as title
        assert!(titled.has_title());
        let untitled = Citation { source_uri: "x".into(), title: String::new(), quote: "q".into() };
        assert!(!untitled.has_title());
    }

    #[test]
    fn citation_count_matches_citations_len() {
        let c = CitationBlockProps {
            citations: vec![cit("a", "q1"), cit("b", "q2"), cit("c", "q3")],
        };
        assert_eq!(c.citation_count(), 3);
    }

    #[test]
    fn titled_count_filters_to_titled_only() {
        let c = CitationBlockProps {
            citations: vec![
                cit("a", "q1"), // has title "t"
                Citation { source_uri: "b".into(), title: String::new(), quote: "q2".into() },
                cit("c", "q3"), // has title
            ],
        };
        assert_eq!(c.titled_count(), 2);
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = CitationBlockProps { citations: vec![cit("x", "q")] };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
