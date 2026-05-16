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
}
