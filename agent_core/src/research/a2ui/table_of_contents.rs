//! Wave I TableOfContents component.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TocEntry {
    pub anchor: String,
    pub title: String,
    pub depth: u8,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct TableOfContentsProps {
    pub entries: Vec<TocEntry>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum TableOfContentsError {
    Empty,
    EmptyAnchor { index: usize },
    DepthOutOfRange { index: usize, depth: u8 },
}

impl TableOfContentsProps {
    pub fn validate(&self) -> Result<(), TableOfContentsError> {
        if self.entries.is_empty() {
            return Err(TableOfContentsError::Empty);
        }
        for (i, e) in self.entries.iter().enumerate() {
            if e.anchor.is_empty() {
                return Err(TableOfContentsError::EmptyAnchor { index: i });
            }
            if !(1..=6).contains(&e.depth) {
                return Err(TableOfContentsError::DepthOutOfRange { index: i, depth: e.depth });
            }
        }
        Ok(())
    }

    pub fn max_depth(&self) -> u8 {
        self.entries.iter().map(|e| e.depth).max().unwrap_or(0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry(a: &str, t: &str, d: u8) -> TocEntry {
        TocEntry { anchor: a.into(), title: t.into(), depth: d }
    }

    #[test]
    fn empty_rejected() {
        let p = TableOfContentsProps { entries: vec![] };
        assert_eq!(p.validate().unwrap_err(), TableOfContentsError::Empty);
    }

    #[test]
    fn valid_passes() {
        let p = TableOfContentsProps { entries: vec![entry("#intro", "Intro", 1)] };
        assert!(p.validate().is_ok());
    }

    #[test]
    fn empty_anchor_rejected() {
        let p = TableOfContentsProps { entries: vec![entry("", "x", 1)] };
        assert!(matches!(p.validate().unwrap_err(), TableOfContentsError::EmptyAnchor { .. }));
    }

    #[test]
    fn depth_zero_rejected() {
        let p = TableOfContentsProps { entries: vec![entry("#a", "x", 0)] };
        assert!(matches!(p.validate().unwrap_err(), TableOfContentsError::DepthOutOfRange { .. }));
    }

    #[test]
    fn depth_seven_rejected() {
        let p = TableOfContentsProps { entries: vec![entry("#a", "x", 7)] };
        assert!(matches!(p.validate().unwrap_err(), TableOfContentsError::DepthOutOfRange { .. }));
    }

    #[test]
    fn max_depth_correct() {
        let p = TableOfContentsProps {
            entries: vec![entry("#a", "A", 1), entry("#b", "B", 3), entry("#c", "C", 2)],
        };
        assert_eq!(p.max_depth(), 3);
    }

    #[test]
    fn serde_json_roundtrip() {
        let p = TableOfContentsProps { entries: vec![entry("#a", "A", 1)] };
        let json = serde_json::to_string(&p).unwrap();
        let back: TableOfContentsProps = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }
}
