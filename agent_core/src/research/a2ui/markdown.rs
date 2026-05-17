//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `Markdown`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::Markdown`].
//!
//! # Wave I — Markdown component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct MarkdownProps {
    pub body: String,
    pub allow_raw_html: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum MarkdownError {
    EmptyBody,
    RawHtmlPresentWithoutFlag,
}

impl MarkdownError {
    pub const fn cause(&self) -> &'static str {
        match self {
            MarkdownError::EmptyBody => "empty_body",
            MarkdownError::RawHtmlPresentWithoutFlag => "raw_html_present_without_flag",
        }
    }
}

impl MarkdownProps {
    pub fn validate(&self) -> Result<(), MarkdownError> {
        if self.body.is_empty() {
            return Err(MarkdownError::EmptyBody);
        }
        if !self.allow_raw_html && (self.body.contains("<script") || self.body.contains("<iframe")) {
            return Err(MarkdownError::RawHtmlPresentWithoutFlag);
        }
        Ok(())
    }

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Length of the markdown body in bytes (UTF-8 byte count, not
    /// grapheme count). Used for memory accounting.
    pub fn body_byte_len(&self) -> usize {
        self.body.len()
    }

    /// Predicate: the body contains a `<script>` or `<iframe>` tag
    /// substring (which would require `allow_raw_html` to validate).
    /// Useful for callers that want to surface "this body needs HTML
    /// permission" before the validator fires.
    pub fn contains_raw_html_tags(&self) -> bool {
        self.body.contains("<script") || self.body.contains("<iframe")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_body_rejected() {
        let m = MarkdownProps { body: String::new(), allow_raw_html: false };
        assert_eq!(m.validate().unwrap_err(), MarkdownError::EmptyBody);
    }

    #[test]
    fn plain_markdown_validates() {
        let m = MarkdownProps { body: "# hello".into(), allow_raw_html: false };
        assert!(m.validate().is_ok());
    }

    #[test]
    fn script_tag_without_flag_rejected() {
        let m = MarkdownProps { body: "<script>alert(1)</script>".into(), allow_raw_html: false };
        assert_eq!(m.validate().unwrap_err(), MarkdownError::RawHtmlPresentWithoutFlag);
    }

    #[test]
    fn script_tag_with_flag_passes() {
        let m = MarkdownProps { body: "<script>alert(1)</script>".into(), allow_raw_html: true };
        assert!(m.validate().is_ok());
    }

    #[test]
    fn serde_json_roundtrip() {
        let m = MarkdownProps { body: "x".into(), allow_raw_html: true };
        let json = serde_json::to_string(&m).unwrap();
        let back: MarkdownProps = serde_json::from_str(&json).unwrap();
        assert_eq!(m, back);
    }

    // ── diagnostic surface (iter 206) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct() {
        assert_ne!(
            MarkdownError::EmptyBody.cause(),
            MarkdownError::RawHtmlPresentWithoutFlag.cause(),
        );
    }

    #[test]
    fn body_byte_len_matches_string_len() {
        let m = MarkdownProps { body: "hello".into(), allow_raw_html: false };
        assert_eq!(m.body_byte_len(), 5);
        let m = MarkdownProps { body: "héllo".into(), allow_raw_html: false };
        // 'é' is 2 bytes in UTF-8.
        assert_eq!(m.body_byte_len(), 6);
    }

    #[test]
    fn contains_raw_html_tags_detects_script_and_iframe() {
        let m = MarkdownProps { body: "before <script>x</script> after".into(), allow_raw_html: false };
        assert!(m.contains_raw_html_tags());
        let m = MarkdownProps { body: "before <iframe>y</iframe> after".into(), allow_raw_html: false };
        assert!(m.contains_raw_html_tags());
        let m = MarkdownProps { body: "plain markdown".into(), allow_raw_html: false };
        assert!(!m.contains_raw_html_tags());
    }

    #[test]
    fn contains_raw_html_aligned_with_validation_when_flag_off() {
        // Cross-surface invariant: when allow_raw_html=false AND body
        // non-empty, validate() returns RawHtmlPresentWithoutFlag iff
        // contains_raw_html_tags() is true.
        let cases = [
            ("plain", false),
            ("with <script>x</script>", true),
            ("with <iframe>x</iframe>", true),
        ];
        for (body, expected_has_tags) in cases {
            let m = MarkdownProps { body: body.into(), allow_raw_html: false };
            assert_eq!(m.contains_raw_html_tags(), expected_has_tags);
            if expected_has_tags {
                assert_eq!(
                    m.validate().unwrap_err(),
                    MarkdownError::RawHtmlPresentWithoutFlag,
                );
            } else {
                assert!(m.validate().is_ok());
            }
        }
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = MarkdownProps { body: "hello".into(), allow_raw_html: false };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
