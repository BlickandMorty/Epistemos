// ═══ AUDIT AMENDMENT (2026-07-06, 5-auditor repo+npm juxtaposition — BINDING; overrides body where they conflict) ═══
// THE "FIELD-FOR-FIELD" CLAIM IS FALSE — unify with the LOCKED LUMENLENS shape
// (suggestion_schema.rs): typed Author{User,June,Companion{id}} not String; AcceptState
// {Pending,Accepted,Rejected} (Proposed is a rename; Superseded is NEW — negotiate it into the
// locked schema explicitly or drop it); restore updated_at_ms; keep ranges_a1 as the grid's
// payload-agnostic range form (defensible) but note the B-coordinate remap loss. AND follow the
// append-only ledger idiom (events Vec + monotonic sequence + events_since + snapshot — the
// LUMENLENS binding amendment): accept_state mutate-in-place leaves no event trail; add
// SuggestionStaged/SuggestionResolved events.
// ════════════════════════════════════════════════════════════════════════════════════════════════
// ID: EPI-RP-09-RECKONER · Codename: RECKONER
// The tabular suggestion record. It follows the locked LUMENLENS provenance
// shape — author / turn / ranges / before-after / rationale / source /
// accept-state — with ranges expressed as A1. No parallel schema; the
// contradiction sweep depends on this staying unified.
// (Dependencies / hand-off seam: the ledger + replay + retention (checkpoint+tail)
// are owned by EPI-RP-02-LUMENLENS provenance; RECKONER appends and reads.)

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum Author {
    User { id: String },
    June,
    Companion { id: String },
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum AcceptState { Pending, Accepted, Rejected }

#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum TabularSuggestionEvent {
    SuggestionStaged { sequence: u64, at_ms: u64 },
    SuggestionResolved { sequence: u64, at_ms: u64, state: AcceptState },
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TabularSuggestion {
    pub id: String,                      // ULID; FK the grid layer stages by
    pub dataset_id: String,
    pub author: Author,
    pub turn_id: String,
    pub ranges_a1: Vec<String>,          // e.g. "C2:C4801"
    pub before: Vec<(String, String)>,   // addr → value (bounded; large ops chunk)
    pub after: Vec<(String, String)>,
    pub rationale: Option<String>,
    pub source_citation: Option<String>,
    pub accept_state: AcceptState,
    pub created_at_ms: u64,
    pub updated_at_ms: u64,
    pub events: Vec<TabularSuggestionEvent>,
}
// Retention: tabular volume >> prose volume — the checkpoint+tail model applies
// with tabular-tuned caps (checkpoint accepted dataset state; keep recent op
// tail in full; compact older ops to summaries). TODO: caps after Phase-7 bench.
