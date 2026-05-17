//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `Quote`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::Quote`].
//!
//! # Wave I — Quote component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct QuoteProps {
    pub body: String,
    pub attribution: Option<String>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum QuoteError {
    EmptyBody,
}

impl QuoteError {
    pub const fn cause(&self) -> &'static str {
        match self {
            QuoteError::EmptyBody => "empty_body",
        }
    }
}

impl QuoteProps {
    pub fn validate(&self) -> Result<(), QuoteError> {
        if self.body.trim().is_empty() {
            return Err(QuoteError::EmptyBody);
        }
        Ok(())
    }

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// UTF-8 byte length of the raw quote body (whitespace included).
    pub fn body_byte_len(&self) -> usize {
        self.body.len()
    }

    /// UTF-8 byte length of the body after trimming surrounding
    /// whitespace. Cross-surface invariant: `trimmed_body_byte_len <=
    /// body_byte_len` always.
    pub fn trimmed_body_byte_len(&self) -> usize {
        self.body.trim().len()
    }

    /// Predicate: an `attribution` field is present (non-`None`).
    /// Cross-surface invariant: `has_attribution == attribution.is_some()`.
    pub fn has_attribution(&self) -> bool {
        self.attribution.is_some()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_body_rejected() {
        let q = QuoteProps { body: "   ".into(), attribution: None };
        assert_eq!(q.validate().unwrap_err(), QuoteError::EmptyBody);
    }

    #[test]
    fn valid_passes() {
        let q = QuoteProps {
            body: "I think therefore I am".into(),
            attribution: Some("Descartes".into()),
        };
        assert!(q.validate().is_ok());
    }

    #[test]
    fn attribution_optional() {
        let q = QuoteProps { body: "anon quote".into(), attribution: None };
        assert!(q.validate().is_ok());
    }

    #[test]
    fn empty_string_rejected() {
        let q = QuoteProps { body: String::new(), attribution: None };
        assert_eq!(q.validate().unwrap_err(), QuoteError::EmptyBody);
    }

    #[test]
    fn serde_json_roundtrip() {
        let q = QuoteProps { body: "x".into(), attribution: Some("y".into()) };
        let json = serde_json::to_string(&q).unwrap();
        let back: QuoteProps = serde_json::from_str(&json).unwrap();
        assert_eq!(q, back);
    }

    // ── diagnostic surface (iter 209) ────────────────────────────────────────

    #[test]
    fn error_cause_stable() {
        assert_eq!(QuoteError::EmptyBody.cause(), "empty_body");
    }

    #[test]
    fn trimmed_body_byte_len_at_most_body_byte_len() {
        // Cross-surface invariant: trim() never grows the string.
        let cases = [
            QuoteProps { body: "hello".into(), attribution: None },
            QuoteProps { body: "  padded  ".into(), attribution: None },
            QuoteProps { body: "\n\tmixed\n\t".into(), attribution: None },
            QuoteProps { body: "".into(), attribution: None },
        ];
        for q in cases {
            assert!(q.trimmed_body_byte_len() <= q.body_byte_len());
        }
    }

    #[test]
    fn has_attribution_matches_option_is_some() {
        // Cross-surface invariant: has_attribution == attribution.is_some().
        let with = QuoteProps { body: "x".into(), attribution: Some("y".into()) };
        let without = QuoteProps { body: "x".into(), attribution: None };
        assert_eq!(with.has_attribution(), with.attribution.is_some());
        assert_eq!(without.has_attribution(), without.attribution.is_some());
        assert!(with.has_attribution());
        assert!(!without.has_attribution());
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = QuoteProps { body: "hello".into(), attribution: None };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
        let bad = QuoteProps { body: "   ".into(), attribution: None };
        assert_eq!(bad.is_valid(), bad.validate().is_ok());
        assert!(!bad.is_valid());
    }
}
