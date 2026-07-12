// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// STRUCTURAL FIXES: (1) &dyn CalcEngine cannot dry-run (set_user_input/evaluate need &mut;
// from_bytes is Sized-only) — take &mut or a scratch-model snapshot seam. (2) The bespoke
// ToolDispatch trait is UNREACHABLE BY JUNE — the real seam is ToolRegistry::register_default_tools
// (registry.rs:942): dot-namespaced tools (dataset.query/.transform/.chart/.clean/.summarize) as
// async ToolHandler impls with REAL JSON schemas (P8.1 gate rejects opaque String params),
// dependencies captured at registration (vault Arc pattern), + MAS mutation allowlist entries
// (mas_allows_bounded_internal_mutation, registry.rs:79) for the mutating ops. June's reach is then
// automatic via run_agent_session. (3) is_destructive polarity is wrong both ways (Clean/Transform
// over-gated vs its own doc; Chart mutates the note un-gated) — gate per the D4 definition.
// (4) Box<dyn Fn> cannot cross UniFFI. The 2026-07-07 MAS-only pivot parks companion streaming;
// active R5 proof is zero Kindred/presence symbols in MAS and MAS-safe status from June state only.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// F2 tool implementations — ONE schema, active caller: June (MAS, in-process, no
// subprocess). Kindred/1Code is parked. NO tool
// writes cells directly: every proposed change becomes a TabularSuggestion that
// crosses the ApprovalGate when destructive, stages as chips, and commits through
// the normal calc path only on accept.
// Approval/dry-run authority is preserved as a product pattern; MAS implementation routes through
// June/agent_core approval surfaces, never around them.

use super::calc_facade::{CalcEngine, CalcError};
use super::tabular_suggestion::TabularSuggestion;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum DatasetTool {
    Query     { dataset_id: String, expr: String },                    // read-only
    Summarize { dataset_id: String, range_a1: Option<String> },        // read-only
    Chart     { dataset_id: String, range_a1: String, spec: String },  // creates block + provenance
    Clean     { dataset_id: String, column: String, op: String },      // suggestion-producing
    Transform { dataset_id: String, params: String },                  // suggestion-producing
}

impl DatasetTool {
    /// Destructive ops (delete column, overwrite range) REQUIRE per-turn approval
    /// before a suggestion can even stage.
    pub fn is_destructive(&self) -> bool {
        matches!(self, DatasetTool::Transform { .. } | DatasetTool::Clean { .. })
        // TODO: refine per-op (a rename is not a delete); err toward gated.
    }
}

/// Design sketch for the real ToolRegistry::register_default_tools integration.
/// Do not implement a parallel dispatcher: register `dataset.query`,
/// `dataset.transform`, `dataset.chart`, `dataset.clean`, and
/// `dataset.summarize` as dot-namespaced async ToolHandlers with JSON schemas
/// and MAS mutation allowlist entries.
pub struct DatasetToolHandler<E: CalcEngine> {
    engine: E,
}

impl<E: CalcEngine> DatasetToolHandler<E> {
    /// June and KINDRED share this semantic path. KINDRED streaming is emitted
    /// through the existing AgentEventDelegate frames, not a boxed callback
    /// across UniFFI.
    pub fn stage(&mut self, tool: DatasetTool) -> Result<Vec<TabularSuggestion>, CalcError> {
        let _scratch = self.engine.scratch_from_bytes()?;
        let _requires_approval = tool.is_destructive();
        // TODO: produce TabularSuggestion events; destructive ops must cross
        // ApprovalGate before staging and all accepted ops commit through calc.
        Ok(Vec::new())
    }
}
