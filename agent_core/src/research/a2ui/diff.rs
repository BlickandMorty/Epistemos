//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `Diff`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::Diff`].
//!
//! # Wave I — Diff component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum DiffLineKind {
    Context,
    Added,
    Removed,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DiffLine {
    pub kind: DiffLineKind,
    pub text: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DiffProps {
    pub file_a: String,
    pub file_b: String,
    pub lines: Vec<DiffLine>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum DiffError {
    EmptyFileA,
    EmptyFileB,
    EmptyLines,
}

impl DiffProps {
    pub fn validate(&self) -> Result<(), DiffError> {
        if self.file_a.is_empty() {
            return Err(DiffError::EmptyFileA);
        }
        if self.file_b.is_empty() {
            return Err(DiffError::EmptyFileB);
        }
        if self.lines.is_empty() {
            return Err(DiffError::EmptyLines);
        }
        Ok(())
    }

    pub fn count(&self, kind: DiffLineKind) -> usize {
        self.lines.iter().filter(|l| l.kind == kind).count()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn line(kind: DiffLineKind, text: &str) -> DiffLine {
        DiffLine { kind, text: text.into() }
    }

    #[test]
    fn three_distinct_kinds() {
        let s: std::collections::HashSet<_> =
            [DiffLineKind::Context, DiffLineKind::Added, DiffLineKind::Removed].iter().copied().collect();
        assert_eq!(s.len(), 3);
    }

    #[test]
    fn empty_file_a_rejected() {
        let d = DiffProps {
            file_a: String::new(),
            file_b: "b".into(),
            lines: vec![line(DiffLineKind::Context, "x")],
        };
        assert_eq!(d.validate().unwrap_err(), DiffError::EmptyFileA);
    }

    #[test]
    fn empty_file_b_rejected() {
        let d = DiffProps {
            file_a: "a".into(),
            file_b: String::new(),
            lines: vec![line(DiffLineKind::Context, "x")],
        };
        assert_eq!(d.validate().unwrap_err(), DiffError::EmptyFileB);
    }

    #[test]
    fn empty_lines_rejected() {
        let d = DiffProps { file_a: "a".into(), file_b: "b".into(), lines: vec![] };
        assert_eq!(d.validate().unwrap_err(), DiffError::EmptyLines);
    }

    #[test]
    fn count_by_kind() {
        let d = DiffProps {
            file_a: "a".into(),
            file_b: "b".into(),
            lines: vec![
                line(DiffLineKind::Context, "x"),
                line(DiffLineKind::Added, "y"),
                line(DiffLineKind::Added, "z"),
                line(DiffLineKind::Removed, "w"),
            ],
        };
        assert_eq!(d.count(DiffLineKind::Context), 1);
        assert_eq!(d.count(DiffLineKind::Added), 2);
        assert_eq!(d.count(DiffLineKind::Removed), 1);
    }

    #[test]
    fn serde_json_roundtrip() {
        let d = DiffProps {
            file_a: "a".into(),
            file_b: "b".into(),
            lines: vec![line(DiffLineKind::Added, "x")],
        };
        let json = serde_json::to_string(&d).unwrap();
        let back: DiffProps = serde_json::from_str(&json).unwrap();
        assert_eq!(d, back);
    }
}
