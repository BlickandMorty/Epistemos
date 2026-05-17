//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `CodeBlock`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::CodeBlock`].
//!
//! # Wave I — CodeBlock component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CodeBlockProps {
    pub language: String,
    pub source: String,
    pub line_numbers: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum CodeBlockError {
    EmptyLanguage,
    EmptySource,
}

impl CodeBlockError {
    pub const fn cause(&self) -> &'static str {
        match self {
            CodeBlockError::EmptyLanguage => "empty_language",
            CodeBlockError::EmptySource => "empty_source",
        }
    }

    /// Predicate: error pertains to the `language` field.
    pub const fn is_language_error(&self) -> bool {
        matches!(self, CodeBlockError::EmptyLanguage)
    }

    /// Predicate: error pertains to the `source` field. Cross-surface
    /// invariant: `is_language_error XOR is_source_error` partitions
    /// all variants.
    pub const fn is_source_error(&self) -> bool {
        matches!(self, CodeBlockError::EmptySource)
    }
}

impl CodeBlockProps {
    pub fn validate(&self) -> Result<(), CodeBlockError> {
        if self.language.is_empty() {
            return Err(CodeBlockError::EmptyLanguage);
        }
        if self.source.is_empty() {
            return Err(CodeBlockError::EmptySource);
        }
        Ok(())
    }

    pub fn line_count(&self) -> usize {
        if self.source.is_empty() { 0 } else { self.source.lines().count() }
    }

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// UTF-8 byte length of the source body.
    pub fn source_byte_len(&self) -> usize {
        self.source.len()
    }

    /// Predicate: the source fits on a single line (no newlines).
    /// Cross-surface invariant: in a valid block,
    /// `is_single_line iff line_count() <= 1`.
    pub fn is_single_line(&self) -> bool {
        !self.source.contains('\n')
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn valid_passes() {
        let c = CodeBlockProps {
            language: "rust".into(),
            source: "fn main() {}".into(),
            line_numbers: true,
        };
        assert!(c.validate().is_ok());
    }

    #[test]
    fn empty_language_rejected() {
        let c = CodeBlockProps {
            language: String::new(),
            source: "x".into(),
            line_numbers: false,
        };
        assert_eq!(c.validate().unwrap_err(), CodeBlockError::EmptyLanguage);
    }

    #[test]
    fn empty_source_rejected() {
        let c = CodeBlockProps {
            language: "rust".into(),
            source: String::new(),
            line_numbers: false,
        };
        assert_eq!(c.validate().unwrap_err(), CodeBlockError::EmptySource);
    }

    #[test]
    fn line_count_simple() {
        let c = CodeBlockProps {
            language: "rust".into(),
            source: "a\nb\nc".into(),
            line_numbers: false,
        };
        assert_eq!(c.line_count(), 3);
    }

    #[test]
    fn serde_json_roundtrip() {
        let c = CodeBlockProps {
            language: "rust".into(),
            source: "fn".into(),
            line_numbers: true,
        };
        let json = serde_json::to_string(&c).unwrap();
        let back: CodeBlockProps = serde_json::from_str(&json).unwrap();
        assert_eq!(c, back);
    }

    // ── diagnostic surface (iter 209) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct() {
        assert_ne!(
            CodeBlockError::EmptyLanguage.cause(),
            CodeBlockError::EmptySource.cause(),
        );
    }

    #[test]
    fn error_classifiers_partition() {
        // Cross-surface invariant: is_language_error XOR is_source_error.
        for e in [CodeBlockError::EmptyLanguage, CodeBlockError::EmptySource] {
            assert_ne!(e.is_language_error(), e.is_source_error());
        }
    }

    #[test]
    fn source_byte_len_matches_string_len() {
        let c = CodeBlockProps {
            language: "rust".into(),
            source: "fn main()".into(),
            line_numbers: false,
        };
        assert_eq!(c.source_byte_len(), 9);
    }

    #[test]
    fn is_single_line_iff_line_count_at_most_one() {
        // Cross-surface invariant: for valid blocks,
        // is_single_line() iff line_count() <= 1.
        let one = CodeBlockProps {
            language: "rust".into(),
            source: "fn main() {}".into(),
            line_numbers: false,
        };
        assert!(one.is_valid());
        assert!(one.is_single_line());
        assert!(one.line_count() <= 1);

        let many = CodeBlockProps {
            language: "rust".into(),
            source: "a\nb\nc".into(),
            line_numbers: false,
        };
        assert!(many.is_valid());
        assert!(!many.is_single_line());
        assert!(many.line_count() > 1);
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = CodeBlockProps {
            language: "rust".into(),
            source: "fn".into(),
            line_numbers: false,
        };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
