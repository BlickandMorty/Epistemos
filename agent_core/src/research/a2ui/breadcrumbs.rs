//! Wave I Breadcrumbs component.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct BreadcrumbItem {
    pub label: String,
    pub href: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct BreadcrumbsProps {
    pub items: Vec<BreadcrumbItem>,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum BreadcrumbsError {
    Empty,
    EmptyLabel { index: usize },
    LastItemMustNotLink,
}

impl BreadcrumbsProps {
    pub fn validate(&self) -> Result<(), BreadcrumbsError> {
        if self.items.is_empty() {
            return Err(BreadcrumbsError::Empty);
        }
        for (i, it) in self.items.iter().enumerate() {
            if it.label.is_empty() {
                return Err(BreadcrumbsError::EmptyLabel { index: i });
            }
        }
        if let Some(last) = self.items.last() {
            if last.href.is_some() {
                return Err(BreadcrumbsError::LastItemMustNotLink);
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(label: &str, href: Option<&str>) -> BreadcrumbItem {
        BreadcrumbItem {
            label: label.into(),
            href: href.map(String::from),
        }
    }

    #[test]
    fn empty_rejected() {
        let b = BreadcrumbsProps { items: vec![] };
        assert_eq!(b.validate().unwrap_err(), BreadcrumbsError::Empty);
    }

    #[test]
    fn valid_passes() {
        let b = BreadcrumbsProps {
            items: vec![item("Home", Some("/")), item("Notes", Some("/notes")), item("Current", None)],
        };
        assert!(b.validate().is_ok());
    }

    #[test]
    fn single_item_no_link_passes() {
        let b = BreadcrumbsProps { items: vec![item("Only", None)] };
        assert!(b.validate().is_ok());
    }

    #[test]
    fn empty_label_rejected() {
        let b = BreadcrumbsProps { items: vec![item("", None)] };
        assert!(matches!(b.validate().unwrap_err(), BreadcrumbsError::EmptyLabel { .. }));
    }

    #[test]
    fn last_item_links_rejected() {
        let b = BreadcrumbsProps {
            items: vec![item("Home", Some("/")), item("Current", Some("/c"))],
        };
        assert_eq!(b.validate().unwrap_err(), BreadcrumbsError::LastItemMustNotLink);
    }

    #[test]
    fn serde_json_roundtrip() {
        let b = BreadcrumbsProps {
            items: vec![item("Home", Some("/")), item("Last", None)],
        };
        let json = serde_json::to_string(&b).unwrap();
        let back: BreadcrumbsProps = serde_json::from_str(&json).unwrap();
        assert_eq!(b, back);
    }
}
