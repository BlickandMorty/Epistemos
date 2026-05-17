//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `Table`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::Table`].
//!
//! # Wave I — Table component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TableCell {
    pub text: String,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TableProps {
    pub headers: Vec<String>,
    pub rows: Vec<Vec<TableCell>>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TableError {
    EmptyHeaders,
    RowWidthMismatch { row_index: usize, header_count: usize, row_count: usize },
}

impl TableError {
    pub const fn cause(&self) -> &'static str {
        match self {
            TableError::EmptyHeaders => "empty_headers",
            TableError::RowWidthMismatch { .. } => "row_width_mismatch",
        }
    }
}

impl TableProps {
    pub fn validate(&self) -> Result<(), TableError> {
        if self.headers.is_empty() {
            return Err(TableError::EmptyHeaders);
        }
        for (i, row) in self.rows.iter().enumerate() {
            if row.len() != self.headers.len() {
                return Err(TableError::RowWidthMismatch {
                    row_index: i,
                    header_count: self.headers.len(),
                    row_count: row.len(),
                });
            }
        }
        Ok(())
    }

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Number of columns (== `headers.len()`).
    pub fn column_count(&self) -> usize {
        self.headers.len()
    }

    /// Number of data rows.
    pub fn row_count(&self) -> usize {
        self.rows.len()
    }

    /// Total cell count `column_count * row_count`. Cross-surface
    /// invariant: in a valid table, every row has exactly
    /// `column_count` cells, so `total_cells = column_count * row_count`.
    pub fn total_cells(&self) -> usize {
        self.column_count() * self.row_count()
    }

    /// Predicate: zero data rows (header-only table).
    pub fn is_header_only(&self) -> bool {
        self.rows.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cell(s: &str) -> TableCell {
        TableCell { text: s.to_string() }
    }

    #[test]
    fn empty_headers_rejected() {
        let t = TableProps { headers: vec![], rows: vec![] };
        assert_eq!(t.validate().unwrap_err(), TableError::EmptyHeaders);
    }

    #[test]
    fn matching_widths_validates() {
        let t = TableProps {
            headers: vec!["a".into(), "b".into()],
            rows: vec![vec![cell("1"), cell("2")], vec![cell("3"), cell("4")]],
        };
        assert!(t.validate().is_ok());
    }

    #[test]
    fn row_width_mismatch_errors() {
        let t = TableProps {
            headers: vec!["a".into(), "b".into()],
            rows: vec![vec![cell("1"), cell("2")], vec![cell("3")]],
        };
        let err = t.validate().unwrap_err();
        assert!(matches!(err, TableError::RowWidthMismatch { row_index: 1, .. }));
    }

    #[test]
    fn zero_rows_validates_with_nonempty_headers() {
        let t = TableProps { headers: vec!["h".into()], rows: vec![] };
        assert!(t.validate().is_ok());
    }

    #[test]
    fn serde_json_roundtrip() {
        let t = TableProps {
            headers: vec!["a".into()],
            rows: vec![vec![cell("1")]],
        };
        let json = serde_json::to_string(&t).unwrap();
        let back: TableProps = serde_json::from_str(&json).unwrap();
        assert_eq!(t, back);
    }

    // ── diagnostic surface (iter 206) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct() {
        assert_ne!(
            TableError::EmptyHeaders.cause(),
            TableError::RowWidthMismatch { row_index: 0, header_count: 1, row_count: 0 }.cause(),
        );
    }

    #[test]
    fn column_and_row_count_match_vectors() {
        let t = TableProps {
            headers: vec!["a".into(), "b".into(), "c".into()],
            rows: vec![
                vec![cell("1"), cell("2"), cell("3")],
                vec![cell("4"), cell("5"), cell("6")],
            ],
        };
        assert_eq!(t.column_count(), 3);
        assert_eq!(t.row_count(), 2);
    }

    #[test]
    fn total_cells_invariant_for_valid_table() {
        // Cross-surface invariant: in a valid table, total_cells = col × row.
        let t = TableProps {
            headers: vec!["a".into(), "b".into()],
            rows: vec![
                vec![cell("1"), cell("2")],
                vec![cell("3"), cell("4")],
                vec![cell("5"), cell("6")],
            ],
        };
        assert!(t.is_valid());
        assert_eq!(t.total_cells(), t.column_count() * t.row_count());
        assert_eq!(t.total_cells(), 6);
    }

    #[test]
    fn is_header_only_true_when_no_rows() {
        let t = TableProps {
            headers: vec!["a".into()],
            rows: vec![],
        };
        assert!(t.is_header_only());
        let t = TableProps {
            headers: vec!["a".into()],
            rows: vec![vec![cell("x")]],
        };
        assert!(!t.is_header_only());
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = TableProps {
            headers: vec!["a".into()],
            rows: vec![vec![cell("1")]],
        };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
