//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `KeyValueGrid`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::KeyValueGrid`].
//!
//! # Wave I — KeyValueGrid component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct KeyValueGridProps {
    pub entries: Vec<(String, String)>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum KeyValueGridError {
    EmptyKey { index: usize },
    DuplicateKey { key: String },
}

impl KeyValueGridError {
    pub const fn cause(&self) -> &'static str {
        match self {
            KeyValueGridError::EmptyKey { .. } => "empty_key",
            KeyValueGridError::DuplicateKey { .. } => "duplicate_key",
        }
    }

    pub const fn is_empty_key(&self) -> bool {
        matches!(self, KeyValueGridError::EmptyKey { .. })
    }

    /// Cross-surface invariant: `is_empty_key XOR is_duplicate_key`
    /// partitions all variants.
    pub const fn is_duplicate_key(&self) -> bool {
        matches!(self, KeyValueGridError::DuplicateKey { .. })
    }
}

impl KeyValueGridProps {
    pub fn validate(&self) -> Result<(), KeyValueGridError> {
        let mut seen: std::collections::HashSet<&String> = Default::default();
        for (i, (k, _)) in self.entries.iter().enumerate() {
            if k.is_empty() {
                return Err(KeyValueGridError::EmptyKey { index: i });
            }
            if !seen.insert(k) {
                return Err(KeyValueGridError::DuplicateKey { key: k.clone() });
            }
        }
        Ok(())
    }

    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Number of entries.
    pub fn entry_count(&self) -> usize {
        self.entries.len()
    }

    /// Predicate: this grid has zero entries (valid but renders empty).
    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// Lookup a value by key. Returns `None` for missing keys.
    /// Cross-surface invariant: in a valid grid, every key returns a
    /// unique value (no double-counts).
    pub fn lookup(&self, key: &str) -> Option<&str> {
        self.entries.iter().find_map(|(k, v)| {
            if k == key {
                Some(v.as_str())
            } else {
                None
            }
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_grid_validates() {
        let g = KeyValueGridProps { entries: vec![] };
        assert!(g.validate().is_ok());
    }

    #[test]
    fn unique_keys_validate() {
        let g = KeyValueGridProps {
            entries: vec![("a".into(), "1".into()), ("b".into(), "2".into())],
        };
        assert!(g.validate().is_ok());
    }

    #[test]
    fn empty_key_rejected() {
        let g = KeyValueGridProps {
            entries: vec![("".into(), "1".into())],
        };
        assert_eq!(g.validate().unwrap_err(), KeyValueGridError::EmptyKey { index: 0 });
    }

    #[test]
    fn duplicate_key_rejected() {
        let g = KeyValueGridProps {
            entries: vec![("a".into(), "1".into()), ("a".into(), "2".into())],
        };
        assert_eq!(g.validate().unwrap_err(), KeyValueGridError::DuplicateKey { key: "a".into() });
    }

    #[test]
    fn serde_json_roundtrip() {
        let g = KeyValueGridProps {
            entries: vec![("a".into(), "1".into())],
        };
        let json = serde_json::to_string(&g).unwrap();
        let back: KeyValueGridProps = serde_json::from_str(&json).unwrap();
        assert_eq!(g, back);
    }

    // ── diagnostic surface (iter 208) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct() {
        assert_ne!(
            KeyValueGridError::EmptyKey { index: 0 }.cause(),
            KeyValueGridError::DuplicateKey { key: "x".into() }.cause(),
        );
    }

    #[test]
    fn error_classifiers_partition() {
        // Cross-surface invariant: is_empty_key XOR is_duplicate_key.
        for e in [
            KeyValueGridError::EmptyKey { index: 0 },
            KeyValueGridError::DuplicateKey { key: "x".into() },
        ] {
            assert_ne!(e.is_empty_key(), e.is_duplicate_key());
        }
    }

    #[test]
    fn entry_count_and_is_empty_aligned() {
        let g = KeyValueGridProps { entries: vec![] };
        assert!(g.is_empty());
        assert_eq!(g.entry_count(), 0);
        let g = KeyValueGridProps {
            entries: vec![("a".into(), "1".into()), ("b".into(), "2".into())],
        };
        assert!(!g.is_empty());
        assert_eq!(g.entry_count(), 2);
    }

    #[test]
    fn lookup_returns_value_for_existing_key() {
        let g = KeyValueGridProps {
            entries: vec![
                ("name".into(), "alice".into()),
                ("age".into(), "30".into()),
            ],
        };
        assert_eq!(g.lookup("name"), Some("alice"));
        assert_eq!(g.lookup("age"), Some("30"));
    }

    #[test]
    fn lookup_returns_none_for_missing_key() {
        let g = KeyValueGridProps {
            entries: vec![("a".into(), "1".into())],
        };
        assert_eq!(g.lookup("missing"), None);
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = KeyValueGridProps {
            entries: vec![("a".into(), "1".into())],
        };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
