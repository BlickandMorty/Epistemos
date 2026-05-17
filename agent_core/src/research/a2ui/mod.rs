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

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|k| k.code() == code)
    }

    /// Predicate: this component is an overlay surface (renders on
    /// top of base content). Covers Toast, Alert, Modal, Tooltip.
    /// Used by the Swift dispatcher to apply z-order routing.
    pub const fn is_overlay(self) -> bool {
        matches!(
            self,
            WaveIComponentKind::Toast
                | WaveIComponentKind::Alert
                | WaveIComponentKind::Modal
                | WaveIComponentKind::Tooltip
        )
    }

    /// Predicate: this component is a navigation surface (drives the
    /// user to other content). Covers Breadcrumbs, NavigationRail,
    /// Pagination, TableOfContents, Tabs.
    pub const fn is_navigation(self) -> bool {
        matches!(
            self,
            WaveIComponentKind::Breadcrumbs
                | WaveIComponentKind::NavigationRail
                | WaveIComponentKind::Pagination
                | WaveIComponentKind::TableOfContents
                | WaveIComponentKind::Tabs
        )
    }

    /// Predicate: this component is provenance/agent-trace surface
    /// (shows where data came from or what the agent did). Covers
    /// ProvenanceTrace, ToolCallTrace, CitationBlock, CapabilityChip,
    /// ConfidenceBadge.
    pub const fn is_provenance(self) -> bool {
        matches!(
            self,
            WaveIComponentKind::ProvenanceTrace
                | WaveIComponentKind::ToolCallTrace
                | WaveIComponentKind::CitationBlock
                | WaveIComponentKind::CapabilityChip
                | WaveIComponentKind::ConfidenceBadge
        )
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

    // ── diagnostic surface (iter 196) ────────────────────────────────────────

    #[test]
    fn from_code_roundtrips_all_24() {
        // Cross-surface invariant.
        for k in WaveIComponentKind::ALL.iter().copied() {
            assert_eq!(WaveIComponentKind::from_code(k.code()), Some(k));
        }
    }

    #[test]
    fn from_code_unknown_returns_none() {
        assert_eq!(WaveIComponentKind::from_code("Table"), None); // case-sensitive
        assert_eq!(WaveIComponentKind::from_code(""), None);
        assert_eq!(WaveIComponentKind::from_code("not_a_component"), None);
    }

    #[test]
    fn is_overlay_covers_exactly_4_components() {
        let overlays = [
            WaveIComponentKind::Toast,
            WaveIComponentKind::Alert,
            WaveIComponentKind::Modal,
            WaveIComponentKind::Tooltip,
        ];
        for k in WaveIComponentKind::ALL.iter().copied() {
            assert_eq!(k.is_overlay(), overlays.contains(&k));
        }
        assert_eq!(
            WaveIComponentKind::ALL.iter().filter(|k| k.is_overlay()).count(),
            4,
        );
    }

    #[test]
    fn is_navigation_covers_exactly_5_components() {
        let nav = [
            WaveIComponentKind::Breadcrumbs,
            WaveIComponentKind::NavigationRail,
            WaveIComponentKind::Pagination,
            WaveIComponentKind::TableOfContents,
            WaveIComponentKind::Tabs,
        ];
        for k in WaveIComponentKind::ALL.iter().copied() {
            assert_eq!(k.is_navigation(), nav.contains(&k));
        }
        assert_eq!(
            WaveIComponentKind::ALL.iter().filter(|k| k.is_navigation()).count(),
            5,
        );
    }

    #[test]
    fn is_provenance_covers_exactly_5_components() {
        let prov = [
            WaveIComponentKind::ProvenanceTrace,
            WaveIComponentKind::ToolCallTrace,
            WaveIComponentKind::CitationBlock,
            WaveIComponentKind::CapabilityChip,
            WaveIComponentKind::ConfidenceBadge,
        ];
        for k in WaveIComponentKind::ALL.iter().copied() {
            assert_eq!(k.is_provenance(), prov.contains(&k));
        }
        assert_eq!(
            WaveIComponentKind::ALL.iter().filter(|k| k.is_provenance()).count(),
            5,
        );
    }

    #[test]
    fn category_predicates_mutually_exclusive() {
        // Cross-surface invariant: a single component is in at most one
        // of the 3 categories (overlay/navigation/provenance) — they
        // don't overlap. Some components are in none (Table, Markdown,
        // etc.) but never in multiple.
        for k in WaveIComponentKind::ALL.iter().copied() {
            let trio = [k.is_overlay(), k.is_navigation(), k.is_provenance()];
            assert!(trio.iter().filter(|t| **t).count() <= 1, "{:?} in multiple", k);
        }
    }
}
