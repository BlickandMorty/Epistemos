//! Wave I Accordion component.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AccordionItem {
    pub key: String,
    pub title: String,
    pub body: String,
    pub expanded: bool,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AccordionProps {
    pub items: Vec<AccordionItem>,
    pub allow_multi_expand: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum AccordionError {
    Empty,
    EmptyKey { index: usize },
    DuplicateKey,
    MultiExpandViolation,
}

impl AccordionProps {
    pub fn validate(&self) -> Result<(), AccordionError> {
        if self.items.is_empty() {
            return Err(AccordionError::Empty);
        }
        let mut seen: std::collections::HashSet<&str> = std::collections::HashSet::new();
        for (i, it) in self.items.iter().enumerate() {
            if it.key.is_empty() {
                return Err(AccordionError::EmptyKey { index: i });
            }
            if !seen.insert(&it.key) {
                return Err(AccordionError::DuplicateKey);
            }
        }
        if !self.allow_multi_expand {
            let expanded_count = self.items.iter().filter(|i| i.expanded).count();
            if expanded_count > 1 {
                return Err(AccordionError::MultiExpandViolation);
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(k: &str, exp: bool) -> AccordionItem {
        AccordionItem { key: k.into(), title: "t".into(), body: "b".into(), expanded: exp }
    }

    #[test]
    fn empty_rejected() {
        let a = AccordionProps { items: vec![], allow_multi_expand: false };
        assert_eq!(a.validate().unwrap_err(), AccordionError::Empty);
    }

    #[test]
    fn valid_passes() {
        let a = AccordionProps {
            items: vec![item("a", true), item("b", false)],
            allow_multi_expand: false,
        };
        assert!(a.validate().is_ok());
    }

    #[test]
    fn empty_key_rejected() {
        let a = AccordionProps {
            items: vec![item("", false)],
            allow_multi_expand: false,
        };
        assert!(matches!(a.validate().unwrap_err(), AccordionError::EmptyKey { .. }));
    }

    #[test]
    fn duplicate_key_rejected() {
        let a = AccordionProps {
            items: vec![item("k", false), item("k", false)],
            allow_multi_expand: true,
        };
        assert_eq!(a.validate().unwrap_err(), AccordionError::DuplicateKey);
    }

    #[test]
    fn multi_expand_violation_rejected() {
        let a = AccordionProps {
            items: vec![item("a", true), item("b", true)],
            allow_multi_expand: false,
        };
        assert_eq!(a.validate().unwrap_err(), AccordionError::MultiExpandViolation);
    }

    #[test]
    fn multi_expand_allowed_passes() {
        let a = AccordionProps {
            items: vec![item("a", true), item("b", true)],
            allow_multi_expand: true,
        };
        assert!(a.validate().is_ok());
    }

    #[test]
    fn serde_json_roundtrip() {
        let a = AccordionProps {
            items: vec![item("k", false)],
            allow_multi_expand: false,
        };
        let json = serde_json::to_string(&a).unwrap();
        let back: AccordionProps = serde_json::from_str(&json).unwrap();
        assert_eq!(a, back);
    }
}
