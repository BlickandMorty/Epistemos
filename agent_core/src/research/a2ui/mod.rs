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
//! first 6 (Table → CapabilityChip); iter 65 adds the next 6
//! (ProvenanceTrace → CodeBlock); subsequent iters add the
//! remaining 12 (one or several per iter).
//!
//! ## Validator contract
//!
//! Every component impls a `validate(&self) -> Result<(), A2UIError>`
//! method that catches the structural mistakes a malformed envelope
//! would otherwise propagate to the renderer. Production wire-in
//! lives in the Swift A2UI dispatcher; substrate floor here owns
//! the schema + the per-component validator.

pub mod capability_chip;
pub mod chart;
pub mod citation_block;
pub mod code_block;
pub mod confidence_badge;
pub mod diff;
pub mod key_value_grid;
pub mod markdown;
pub mod progress_bar;
pub mod provenance_trace;
pub mod table;
pub mod tool_call_trace;

pub use capability_chip::{CapabilityChipProps, CapabilityChipError};
pub use chart::{ChartProps, ChartError, ChartKind};
pub use citation_block::{Citation, CitationBlockError, CitationBlockProps};
pub use code_block::{CodeBlockError, CodeBlockProps};
pub use confidence_badge::{ConfidenceBadgeError, ConfidenceBadgeProps, ConfidenceTier};
pub use diff::{DiffError, DiffLine, DiffLineKind, DiffProps};
pub use key_value_grid::{KeyValueGridProps, KeyValueGridError};
pub use markdown::{MarkdownProps, MarkdownError};
pub use progress_bar::{ProgressBarProps, ProgressBarError};
pub use provenance_trace::{ProvenanceTraceError, ProvenanceTraceProps, ProvenanceTraceStep};
pub use table::{TableProps, TableError, TableCell};
pub use tool_call_trace::{ToolCallTraceEntry, ToolCallTraceError, ToolCallTraceProps};

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
}

impl WaveIComponentKind {
    pub const ALL: [WaveIComponentKind; 12] = [
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
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn twelve_distinct_components_iter_65() {
        let s: std::collections::HashSet<_> = WaveIComponentKind::ALL.iter().copied().collect();
        assert_eq!(s.len(), 12);
    }

    #[test]
    fn component_codes_stable() {
        assert_eq!(WaveIComponentKind::Table.code(), "table");
        assert_eq!(WaveIComponentKind::Markdown.code(), "markdown");
        assert_eq!(WaveIComponentKind::Chart.code(), "chart");
        assert_eq!(WaveIComponentKind::ProgressBar.code(), "progress_bar");
        assert_eq!(WaveIComponentKind::KeyValueGrid.code(), "key_value_grid");
        assert_eq!(WaveIComponentKind::CapabilityChip.code(), "capability_chip");
        assert_eq!(WaveIComponentKind::ProvenanceTrace.code(), "provenance_trace");
        assert_eq!(WaveIComponentKind::ToolCallTrace.code(), "tool_call_trace");
        assert_eq!(WaveIComponentKind::ConfidenceBadge.code(), "confidence_badge");
        assert_eq!(WaveIComponentKind::CitationBlock.code(), "citation_block");
        assert_eq!(WaveIComponentKind::Diff.code(), "diff");
        assert_eq!(WaveIComponentKind::CodeBlock.code(), "code_block");
    }
}
