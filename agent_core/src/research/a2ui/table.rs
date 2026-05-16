//! Wave I Table component.

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
}
