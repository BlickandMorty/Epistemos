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

impl DiffLineKind {
    pub const ALL: [DiffLineKind; 3] = [
        DiffLineKind::Context,
        DiffLineKind::Added,
        DiffLineKind::Removed,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            DiffLineKind::Context => "context",
            DiffLineKind::Added => "added",
            DiffLineKind::Removed => "removed",
        }
    }

    /// Reverse lookup for [`Self::code`].
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|k| k.code() == code)
    }

    /// Predicate: line represents an unchanged context line (not a
    /// substantive change). Cross-surface invariant:
    /// `is_change XOR (== Context)` partitions all 3 kinds.
    pub const fn is_change(self) -> bool {
        matches!(self, DiffLineKind::Added | DiffLineKind::Removed)
    }
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

impl DiffError {
    pub const fn cause(&self) -> &'static str {
        match self {
            DiffError::EmptyFileA => "empty_file_a",
            DiffError::EmptyFileB => "empty_file_b",
            DiffError::EmptyLines => "empty_lines",
        }
    }

    /// Predicate: error pertains to a missing file path
    /// (EmptyFileA / EmptyFileB).
    pub const fn is_file_metadata_error(&self) -> bool {
        matches!(self, DiffError::EmptyFileA | DiffError::EmptyFileB)
    }

    /// Predicate: error pertains to missing content (EmptyLines).
    /// Cross-surface invariant:
    /// `is_file_metadata_error XOR is_content_error` partitions all variants.
    pub const fn is_content_error(&self) -> bool {
        matches!(self, DiffError::EmptyLines)
    }
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

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Total line count (sum over all kinds).
    pub fn line_count(&self) -> usize {
        self.lines.len()
    }

    /// Predicate: the diff contains at least one Added or Removed line
    /// (i.e., there is at least one substantive change).
    pub fn has_changes(&self) -> bool {
        self.lines.iter().any(|l| l.kind.is_change())
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

    // ── diagnostic surface (iter 209) ────────────────────────────────────────

    #[test]
    fn kind_from_code_roundtrips_all() {
        for k in DiffLineKind::ALL.iter().copied() {
            assert_eq!(DiffLineKind::from_code(k.code()), Some(k));
        }
        assert_eq!(DiffLineKind::from_code("CONTEXT"), None);
    }

    #[test]
    fn kind_is_change_xor_context() {
        // Cross-surface invariant: is_change iff kind != Context.
        for k in DiffLineKind::ALL.iter().copied() {
            assert_eq!(k.is_change(), k != DiffLineKind::Context);
        }
    }

    #[test]
    fn error_cause_distinct_per_variant() {
        let variants = [DiffError::EmptyFileA, DiffError::EmptyFileB, DiffError::EmptyLines];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 3);
    }

    #[test]
    fn error_classifiers_partition() {
        // Cross-surface invariant: is_file_metadata_error XOR is_content_error.
        for e in [DiffError::EmptyFileA, DiffError::EmptyFileB, DiffError::EmptyLines] {
            assert_ne!(e.is_file_metadata_error(), e.is_content_error());
        }
    }

    #[test]
    fn line_count_equals_sum_over_kinds() {
        // Cross-surface invariant: line_count == sum_over_kinds count(kind).
        let d = DiffProps {
            file_a: "a".into(),
            file_b: "b".into(),
            lines: vec![
                line(DiffLineKind::Context, "c"),
                line(DiffLineKind::Added, "a1"),
                line(DiffLineKind::Added, "a2"),
                line(DiffLineKind::Removed, "r"),
            ],
        };
        let total: usize = DiffLineKind::ALL.iter().copied().map(|k| d.count(k)).sum();
        assert_eq!(d.line_count(), total);
        assert_eq!(d.line_count(), 4);
    }

    #[test]
    fn has_changes_iff_any_added_or_removed() {
        let pure_context = DiffProps {
            file_a: "a".into(),
            file_b: "b".into(),
            lines: vec![line(DiffLineKind::Context, "c")],
        };
        assert!(!pure_context.has_changes());

        let with_add = DiffProps {
            file_a: "a".into(),
            file_b: "b".into(),
            lines: vec![line(DiffLineKind::Added, "a")],
        };
        assert!(with_add.has_changes());

        let with_rm = DiffProps {
            file_a: "a".into(),
            file_b: "b".into(),
            lines: vec![line(DiffLineKind::Removed, "r")],
        };
        assert!(with_rm.has_changes());
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = DiffProps {
            file_a: "a".into(),
            file_b: "b".into(),
            lines: vec![line(DiffLineKind::Added, "x")],
        };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
