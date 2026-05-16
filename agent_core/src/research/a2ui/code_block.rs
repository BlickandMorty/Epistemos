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
}
