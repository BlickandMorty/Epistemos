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
//! Naming: each component lives in its own file. Iter 64 ships the
//! first 6 (Table → CapabilityChip); subsequent iters add the
//! remaining 18 (one or several per iter).
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
pub mod key_value_grid;
pub mod markdown;
pub mod progress_bar;
pub mod table;

pub use capability_chip::{CapabilityChipProps, CapabilityChipError};
pub use chart::{ChartProps, ChartError, ChartKind};
pub use key_value_grid::{KeyValueGridProps, KeyValueGridError};
pub use markdown::{MarkdownProps, MarkdownError};
pub use progress_bar::{ProgressBarProps, ProgressBarError};
pub use table::{TableProps, TableError, TableCell};

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
}

impl WaveIComponentKind {
    pub const ALL: [WaveIComponentKind; 6] = [
        WaveIComponentKind::Table,
        WaveIComponentKind::Markdown,
        WaveIComponentKind::Chart,
        WaveIComponentKind::ProgressBar,
        WaveIComponentKind::KeyValueGrid,
        WaveIComponentKind::CapabilityChip,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            WaveIComponentKind::Table => "table",
            WaveIComponentKind::Markdown => "markdown",
            WaveIComponentKind::Chart => "chart",
            WaveIComponentKind::ProgressBar => "progress_bar",
            WaveIComponentKind::KeyValueGrid => "key_value_grid",
            WaveIComponentKind::CapabilityChip => "capability_chip",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn six_distinct_components_iter_64() {
        let s: std::collections::HashSet<_> = WaveIComponentKind::ALL.iter().copied().collect();
        assert_eq!(s.len(), 6);
    }

    #[test]
    fn component_codes_stable() {
        assert_eq!(WaveIComponentKind::Table.code(), "table");
        assert_eq!(WaveIComponentKind::Markdown.code(), "markdown");
        assert_eq!(WaveIComponentKind::Chart.code(), "chart");
        assert_eq!(WaveIComponentKind::ProgressBar.code(), "progress_bar");
        assert_eq!(WaveIComponentKind::KeyValueGrid.code(), "key_value_grid");
        assert_eq!(WaveIComponentKind::CapabilityChip.code(), "capability_chip");
    }
}
