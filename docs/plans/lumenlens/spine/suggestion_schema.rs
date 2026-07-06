// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// PLACEMENT AMENDMENT: ClaimLedger is IN-MEMORY Phase 1 (ledger.rs:23-24) — but it ALREADY has the
// exact idiom to copy: append-only `events: Vec<LedgerEvent>` + monotonic sequence (ledger.rs:443-
// 456), cursor accessor events_since() (:512), snapshot() → ReplayBundle with BLAKE3 + FFI export
// (replay.rs; bridge.rs:4070). Add Suggestion as a parallel event stream using THAT pattern. The
// DURABLE side persists in GRDB via the editor-domain table (spine/EditorProvenanceStore.swift)
// with claim_id linkage — do not invent a new Rust persistence layer.
// ════════════════════════════════════════════════════════════════════════════════════════════════
//! suggestion_schema.rs — EPI-RP-02-LUMENLENS · Fork A + F5 provenance (BINDING).
//!
//! The attributed suggestion schema. The JS side keys a suggestion mark on a bare id;
//! THIS is the rich, durable record it points to, living on the agent_core provenance
//! ledger (ledger.rs) with replay-based revert (replay.rs). It survives editor reloads
//! and drives "press mascot -> see edits" and "revert-all-by-companion".

use serde::{Deserialize, Serialize};

/// A change range recorded in both pre-edit (A) and post-edit (B) coordinates so the
/// diff can be rendered and remapped as the user keeps typing.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Range {
    pub from_a: u32,
    pub to_a: u32,
    pub from_b: u32,
    pub to_b: u32,
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum AcceptState {
    Pending,
    Accepted,
    Rejected,
}

/// Who authored a change. `Companion` carries the id so revert-by-companion can filter.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum Author {
    User,
    June,
    Companion { id: String },
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Suggestion {
    pub id: String,                    // == the PM mark's suggestionId
    pub note_id: String,
    pub author: Author,
    pub turn_id: String,               // links to the agent turn
    pub ranges: Vec<Range>,
    pub before_text: String,
    pub after_text: String,
    pub rationale: Option<String>,     // surfaced as a hover tooltip
    pub source_citation: Option<String>,
    pub accept_state: AcceptState,
    pub created_at_ms: u64,
    pub updated_at_ms: u64,
}

impl Suggestion {
    /// True if this suggestion belongs to a given companion turn — the filter used by
    /// "revert everything this companion did this turn".
    pub fn is_companion_turn(&self, companion_id: &str, turn_id: &str) -> bool {
        matches!(&self.author, Author::Companion { id } if id == companion_id)
            && self.turn_id == turn_id
    }
}

// TODO (ledger.rs): append-only insert of Suggestion rows keyed by (note_id, turn_id).
// TODO (replay.rs): reconstruct accept-state history; revert_turn() replays inverse steps
//                   in reverse order through the current mapping.
