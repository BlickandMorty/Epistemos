//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog component `Pagination`.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//! - Companion to [`super::WaveIComponentKind::Pagination`].
//!
//! # Wave I — Pagination component
//!
//! Typed props struct + `validate()` returning a structural error for
//! malformed envelopes. Substrate floor only; Swift A2UI dispatcher
//! owns the renderer.

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

impl PaginationError {
    pub const fn cause(&self) -> &'static str {
        match self {
            PaginationError::PageSizeZero => "page_size_zero",
            PaginationError::PageOutOfRange { .. } => "page_out_of_range",
        }
    }
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

    /// Predicate alias for `validate().is_ok()`.
    pub fn is_valid(&self) -> bool {
        self.validate().is_ok()
    }

    /// Predicate: `total_items == 0`. Cross-surface invariant:
    /// `is_empty_dataset iff page_count() == 0`.
    pub const fn is_empty_dataset(&self) -> bool {
        self.total_items == 0
    }

    /// Predicate: caller is currently on the first page (page == 0).
    pub const fn is_first_page(&self) -> bool {
        self.page == 0
    }

    /// Predicate: caller is currently on the last page (page ==
    /// page_count - 1). Returns false on empty dataset (no pages).
    pub fn is_last_page(&self) -> bool {
        let count = self.page_count();
        count > 0 && self.page == count - 1
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

    // ── diagnostic surface (iter 202) ────────────────────────────────────────

    #[test]
    fn error_cause_distinct() {
        assert_ne!(
            PaginationError::PageSizeZero.cause(),
            PaginationError::PageOutOfRange { page: 1, page_count: 1 }.cause(),
        );
    }

    #[test]
    fn is_empty_dataset_iff_page_count_zero() {
        // Cross-surface invariant.
        let empty = PaginationProps { page: 0, page_size: 10, total_items: 0 };
        assert!(empty.is_empty_dataset());
        assert_eq!(empty.page_count(), 0);

        let full = PaginationProps { page: 0, page_size: 10, total_items: 100 };
        assert!(!full.is_empty_dataset());
        assert!(full.page_count() > 0);
    }

    #[test]
    fn is_first_page_when_page_zero() {
        let p = PaginationProps { page: 0, page_size: 10, total_items: 100 };
        assert!(p.is_first_page());
        let p = PaginationProps { page: 1, page_size: 10, total_items: 100 };
        assert!(!p.is_first_page());
    }

    #[test]
    fn is_last_page_at_final_index() {
        let p = PaginationProps { page: 9, page_size: 10, total_items: 100 };
        assert!(p.is_last_page());
        let p = PaginationProps { page: 8, page_size: 10, total_items: 100 };
        assert!(!p.is_last_page());
    }

    #[test]
    fn is_last_page_false_on_empty_dataset() {
        let p = PaginationProps { page: 0, page_size: 10, total_items: 0 };
        assert!(!p.is_last_page());
    }

    #[test]
    fn is_valid_matches_validate_ok() {
        let good = PaginationProps { page: 0, page_size: 10, total_items: 100 };
        assert_eq!(good.is_valid(), good.validate().is_ok());
        assert!(good.is_valid());
    }
}
