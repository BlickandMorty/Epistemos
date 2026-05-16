//! Wave I Pagination component.

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct PaginationProps {
    pub page: u32,
    pub page_size: u32,
    pub total_items: u64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum PaginationError {
    PageSizeZero,
    PageOutOfRange { page: u32, page_count: u32 },
}

impl PaginationProps {
    pub fn page_count(&self) -> u32 {
        if self.page_size == 0 || self.total_items == 0 {
            return 0;
        }
        let ps = self.page_size as u64;
        ((self.total_items + ps - 1) / ps).min(u32::MAX as u64) as u32
    }

    pub fn validate(&self) -> Result<(), PaginationError> {
        if self.page_size == 0 {
            return Err(PaginationError::PageSizeZero);
        }
        let count = self.page_count();
        if count == 0 {
            return Ok(());
        }
        if self.page >= count {
            return Err(PaginationError::PageOutOfRange { page: self.page, page_count: count });
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn page_size_zero_rejected() {
        let p = PaginationProps { page: 0, page_size: 0, total_items: 10 };
        assert_eq!(p.validate().unwrap_err(), PaginationError::PageSizeZero);
    }

    #[test]
    fn valid_passes() {
        let p = PaginationProps { page: 1, page_size: 10, total_items: 100 };
        assert!(p.validate().is_ok());
    }

    #[test]
    fn page_count_ceiling() {
        let p = PaginationProps { page: 0, page_size: 10, total_items: 25 };
        assert_eq!(p.page_count(), 3);
    }

    #[test]
    fn page_count_exact() {
        let p = PaginationProps { page: 0, page_size: 10, total_items: 100 };
        assert_eq!(p.page_count(), 10);
    }

    #[test]
    fn page_out_of_range_rejected() {
        let p = PaginationProps { page: 10, page_size: 10, total_items: 100 };
        assert!(matches!(p.validate().unwrap_err(), PaginationError::PageOutOfRange { .. }));
    }

    #[test]
    fn empty_dataset_allows_page_zero() {
        let p = PaginationProps { page: 0, page_size: 10, total_items: 0 };
        assert_eq!(p.page_count(), 0);
        assert!(p.validate().is_ok());
    }

    #[test]
    fn serde_json_roundtrip() {
        let p = PaginationProps { page: 0, page_size: 10, total_items: 100 };
        let json = serde_json::to_string(&p).unwrap();
        let back: PaginationProps = serde_json::from_str(&json).unwrap();
        assert_eq!(p, back);
    }
}
