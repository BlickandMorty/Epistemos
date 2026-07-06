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
// (4) Box<dyn Fn> cannot cross UniFFI — companion streaming rides AgentEventDelegate frames;
// presence emission needs an explicit mechanism (caller-supplied callback wired 1Code-side, or a
// cargo feature) or R5's zero-symbols bar is unenforceable.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// F2 tool implementations — ONE schema, TWO callers: June (MAS, in-process, no
// subprocess) and the KINDRED companion (1Code, streamed with presence). NO tool
// writes cells directly: every proposed change becomes a TabularSuggestion that
// crosses the ApprovalGate when destructive, stages as chips, and commits through
// the normal calc path only on accept.
// (Dependencies / hand-off seam: ApprovalGate + bound-vs-gated authority are
// owned by EPI-RP-05-KINDRED; RECKONER routes through it, never around it.)

use super::calc_facade::CalcEngine;
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

pub trait ToolDispatch {
    /// June path: run to completion in-process, return staged suggestions.
    fn run_in_process(&self, tool: DatasetTool, engine: &dyn CalcEngine)
        -> Result<Vec<TabularSuggestion>, String>;
    /// Companion path: stream suggestions turn-wise; presence emitted per op
    /// ("cleaning column C") — 1Code only, same tool semantics.
    fn run_streamed(&self, tool: DatasetTool, engine: &dyn CalcEngine,
        on_suggestion: Box<dyn Fn(TabularSuggestion) + Send>)
        -> Result<(), String>;
}
