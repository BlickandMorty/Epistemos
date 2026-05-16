//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.5 — Wave I A2UI catalog (24 components):
//!   Table · Markdown · Chart · ProgressBar · KeyValueGrid ·
//!   CapabilityChip · ProvenanceTrace · ToolCallTrace ·
//!   ConfidenceBadge · CitationBlock · Diff · CodeBlock · Quote ·
//!   TableOfContents · Tabs · Accordion · Carousel · Pagination ·
//!   Toast · Alert · Modal · Tooltip · Breadcrumbs · NavigationRail.
//! - `MASTER_FUSION §6 Wave I` — canonical component list.
//!
//! # Wave I — A2UI catalog (research-tier schema substrate)
//!
//! Each of the 24 components gets a schemars-derivable Rust struct
//! capturing its props (rendered surface) + a typed validator. The
//! existing `agent_core::a2ui` module owns NoteCard + the component-
//! kind enum; this research-tier module adds the 24 catalog
//! components without touching the production a2ui/ surface (per
//! §2 file-ownership — a2ui/ is not B-owned).
//!
//! Naming: each component lives in its own file. Iter 64 shipped the
//! first 6 (Table → CapabilityChip); iter 65 the next 6
//! (ProvenanceTrace → CodeBlock); iter 66 the next 6
//! (Quote → Pagination); iter 67 the final 6
//! (Toast → NavigationRail). Catalog is now feature-complete: 24/24.
//!
//! ## Validator contract
//!
//! Every component impls a `validate(&self) -> Result<(), A2UIError>`
//! method that catches the structural mistakes a malformed envelope
//! would otherwise propagate to the renderer. Production wire-in
//! lives in the Swift A2UI dispatcher; substrate floor here owns
//! the schema + the per-component validator.

pub mod accordion;
pub mod alert;
pub mod breadcrumbs;
pub mod capability_chip;
pub mod carousel;
pub mod chart;
pub mod citation_block;
pub mod code_block;
pub mod confidence_badge;
pub mod diff;
pub mod key_value_grid;
pub mod markdown;
pub mod modal;
pub mod navigation_rail;
pub mod pagination;
pub mod progress_bar;
pub mod provenance_trace;
pub mod quote;
pub mod table;
pub mod table_of_contents;
pub mod tabs;
pub mod tool_call_trace;
pub mod toast;
pub mod tooltip;

pub use accordion::{AccordionError, AccordionItem, AccordionProps};
pub use alert::{AlertAction, AlertError, AlertProps, AlertSeverity};
pub use breadcrumbs::{BreadcrumbItem, BreadcrumbsError, BreadcrumbsProps};
pub use capability_chip::{CapabilityChipError, CapabilityChipProps};
pub use carousel::{CarouselError, CarouselProps, CarouselSlide};
pub use chart::{ChartError, ChartKind, ChartProps};
pub use citation_block::{Citation, CitationBlockError, CitationBlockProps};
pub use code_block::{CodeBlockError, CodeBlockProps};
pub use confidence_badge::{ConfidenceBadgeError, ConfidenceBadgeProps, ConfidenceTier};
pub use diff::{DiffError, DiffLine, DiffLineKind, DiffProps};
pub use key_value_grid::{KeyValueGridError, KeyValueGridProps};
pub use markdown::{MarkdownError, MarkdownProps};
pub use modal::{ModalError, ModalProps, ModalSize};
pub use navigation_rail::{NavigationRailError, NavigationRailItem, NavigationRailProps};
pub use pagination::{PaginationError, PaginationProps};
pub use progress_bar::{ProgressBarError, ProgressBarProps};
pub use provenance_trace::{ProvenanceTraceError, ProvenanceTraceProps, ProvenanceTraceStep};
pub use quote::{QuoteError, QuoteProps};
pub use table::{TableCell, TableError, TableProps};
pub use table_of_contents::{TableOfContentsError, TableOfContentsProps, TocEntry};
pub use tabs::{TabPane, TabsError, TabsProps};
pub use toast::{ToastError, ToastProps, ToastSeverity};
pub use tool_call_trace::{ToolCallTraceEntry, ToolCallTraceError, ToolCallTraceProps};
pub use tooltip::{TooltipError, TooltipPlacement, TooltipProps};

/// Catalog of every Wave I component name. Each variant matches a
/// per-file struct above. ::ALL is alphabetized to match the driver
/// §5 listing order.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub enum WaveIComponentKind {
    Table,
    Markdown,
    Chart,
    ProgressBar,
    KeyValueGrid,
    CapabilityChip,
    ProvenanceTrace,
    ToolCallTrace,
    ConfidenceBadge,
    CitationBlock,
    Diff,
    CodeBlock,
    Quote,
    TableOfContents,
    Tabs,
    Accordion,
    Carousel,
    Pagination,
    Toast,
    Alert,
    Modal,
    Tooltip,
    Breadcrumbs,
    NavigationRail,
}

impl WaveIComponentKind {
    pub const ALL: [WaveIComponentKind; 24] = [
        WaveIComponentKind::Table,
        WaveIComponentKind::Markdown,
        WaveIComponentKind::Chart,
        WaveIComponentKind::ProgressBar,
        WaveIComponentKind::KeyValueGrid,
        WaveIComponentKind::CapabilityChip,
        WaveIComponentKind::ProvenanceTrace,
        WaveIComponentKind::ToolCallTrace,
        WaveIComponentKind::ConfidenceBadge,
        WaveIComponentKind::CitationBlock,
        WaveIComponentKind::Diff,
        WaveIComponentKind::CodeBlock,
        WaveIComponentKind::Quote,
        WaveIComponentKind::TableOfContents,
        WaveIComponentKind::Tabs,
        WaveIComponentKind::Accordion,
        WaveIComponentKind::Carousel,
        WaveIComponentKind::Pagination,
        WaveIComponentKind::Toast,
        WaveIComponentKind::Alert,
        WaveIComponentKind::Modal,
        WaveIComponentKind::Tooltip,
        WaveIComponentKind::Breadcrumbs,
        WaveIComponentKind::NavigationRail,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            WaveIComponentKind::Table => "table",
            WaveIComponentKind::Markdown => "markdown",
            WaveIComponentKind::Chart => "chart",
            WaveIComponentKind::ProgressBar => "progress_bar",
            WaveIComponentKind::KeyValueGrid => "key_value_grid",
            WaveIComponentKind::CapabilityChip => "capability_chip",
            WaveIComponentKind::ProvenanceTrace => "provenance_trace",
            WaveIComponentKind::ToolCallTrace => "tool_call_trace",
            WaveIComponentKind::ConfidenceBadge => "confidence_badge",
            WaveIComponentKind::CitationBlock => "citation_block",
            WaveIComponentKind::Diff => "diff",
            WaveIComponentKind::CodeBlock => "code_block",
            WaveIComponentKind::Quote => "quote",
            WaveIComponentKind::TableOfContents => "table_of_contents",
            WaveIComponentKind::Tabs => "tabs",
            WaveIComponentKind::Accordion => "accordion",
            WaveIComponentKind::Carousel => "carousel",
            WaveIComponentKind::Pagination => "pagination",
            WaveIComponentKind::Toast => "toast",
            WaveIComponentKind::Alert => "alert",
            WaveIComponentKind::Modal => "modal",
            WaveIComponentKind::Tooltip => "tooltip",
            WaveIComponentKind::Breadcrumbs => "breadcrumbs",
            WaveIComponentKind::NavigationRail => "navigation_rail",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn twenty_four_distinct_components_complete() {
        let s: std::collections::HashSet<_> = WaveIComponentKind::ALL.iter().copied().collect();
        assert_eq!(s.len(), 24);
    }

    #[test]
    fn component_codes_stable() {
        for v in WaveIComponentKind::ALL.iter() {
            assert!(!v.code().is_empty());
        }
        assert_eq!(WaveIComponentKind::Toast.code(), "toast");
        assert_eq!(WaveIComponentKind::Alert.code(), "alert");
        assert_eq!(WaveIComponentKind::Modal.code(), "modal");
        assert_eq!(WaveIComponentKind::Tooltip.code(), "tooltip");
        assert_eq!(WaveIComponentKind::Breadcrumbs.code(), "breadcrumbs");
        assert_eq!(WaveIComponentKind::NavigationRail.code(), "navigation_rail");
    }

    #[test]
    fn all_codes_unique() {
        let mut s = std::collections::HashSet::new();
        for v in WaveIComponentKind::ALL.iter() {
            assert!(s.insert(v.code()), "duplicate code: {}", v.code());
        }
    }

    #[test]
    fn codes_are_snake_case() {
        for v in WaveIComponentKind::ALL.iter() {
            let c = v.code();
            assert!(
                c.chars().all(|ch| ch.is_ascii_lowercase() || ch == '_'),
                "non-snake_case code: {c}"
            );
        }
    }
}
