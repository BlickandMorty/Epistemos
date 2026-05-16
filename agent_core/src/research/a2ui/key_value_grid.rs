//! Wave I KeyValueGrid component.

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
}
