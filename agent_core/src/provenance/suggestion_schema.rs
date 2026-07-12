// HARDENING ENFORCEMENT: production paths in this module MUST remain
// unwrap/expect/panic-free. The suggestion provenance stream is replayed
// at editor startup and through FFI audit surfaces, so every fallible path
// returns a typed `SuggestionLedgerError`. Tests may unwrap.
#![cfg_attr(
    not(test),
    deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)
)]

//! LUMENLENS suggestion provenance.
//!
//! `ClaimLedger` is intentionally in-memory in Phase 1, but it already
//! establishes the local ledger idiom: `events: Vec<_>`, a monotonic
//! sequence, `events_since()` cursor reads, and BLAKE3-backed replay
//! bundles. This module adds the editor-suggestion stream as a parallel
//! in-memory ledger. Durable storage remains the editor-domain GRDB table
//! described by `docs/plans/lumenlens/spine/EditorProvenanceStore.swift`.

use std::collections::HashMap;

use serde::{Deserialize, Serialize};
use thiserror::Error;

pub const SUGGESTION_REPLAY_BUNDLE_SCHEMA_VERSION: u32 = 1;
pub const DEFAULT_SUGGESTION_EVENT_RETENTION: usize = 1_024;

/// A change range recorded in both pre-edit (A) and post-edit (B)
/// coordinates so the diff can be rendered and remapped as the user keeps
/// typing.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Range {
    pub from_a: u32,
    pub to_a: u32,
    pub from_b: u32,
    pub to_b: u32,
}

/// A tabular target range. `dataset_id` is the vault artifact reference; an
/// optional sheet id keeps XLSX/ICALC workbooks addressable without creating a
/// second data room.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct TabularRange {
    pub dataset_id: String,
    pub sheet_id: Option<String>,
    pub a1_range: String,
}

#[derive(Clone, Copy, Debug, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ObjectType {
    #[default]
    NoteMarkdown,
    ProseMirrorDocument,
    DatasetTable,
    DatasetWorkbook,
}

/// Prompt 4 requires one suggestion/provenance schema for prose spans and
/// tabular ranges. The legacy `ranges` field remains for current editor
/// consumers; this payload is the canonical cross-object target shape.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum RangePayload {
    MarkdownOffsets { ranges: Vec<Range> },
    ProseMirrorSpans { ranges: Vec<Range> },
    TabularA1 { ranges: Vec<TabularRange> },
}

impl Default for RangePayload {
    fn default() -> Self {
        Self::MarkdownOffsets { ranges: Vec::new() }
    }
}

impl RangePayload {
    pub fn is_tabular(&self) -> bool {
        matches!(self, Self::TabularA1 { .. })
    }
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AcceptState {
    Pending,
    Accepted,
    Rejected,
}

/// Who authored a change. `Companion` carries the id so revert-by-companion
/// can filter exactly one assistant surface.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Author {
    User,
    June,
    Companion { id: String },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct Suggestion {
    /// Equal to the ProseMirror mark's suggestion id.
    pub id: String,
    /// Legacy prose note id retained for existing LUMENLENS callers.
    pub note_id: String,
    /// Canonical target object id. For prose this matches `note_id`; for
    /// RECKONER it is the dataset artifact reference.
    #[serde(default)]
    pub object_id: String,
    #[serde(default)]
    pub object_type: ObjectType,
    pub author: Author,
    /// Links to the agent or editor turn that produced the span.
    pub turn_id: String,
    #[serde(default)]
    pub range_payload: RangePayload,
    pub ranges: Vec<Range>,
    pub before_text: String,
    pub after_text: String,
    pub rationale: Option<String>,
    pub source_citation: Option<String>,
    pub accept_state: AcceptState,
    pub created_at_ms: u64,
    pub updated_at_ms: u64,
}

impl Suggestion {
    pub fn is_tabular(&self) -> bool {
        matches!(
            self.object_type,
            ObjectType::DatasetTable | ObjectType::DatasetWorkbook
        ) || self.range_payload.is_tabular()
    }

    pub fn requires_approval(&self) -> bool {
        self.accept_state == AcceptState::Pending
    }

    /// True if this suggestion belongs to a given companion turn. This is
    /// the filter used by "revert everything this companion did this turn".
    pub fn is_companion_turn(&self, companion_id: &str, turn_id: &str) -> bool {
        matches!(&self.author, Author::Companion { id } if id == companion_id)
            && self.turn_id == turn_id
    }

    pub fn is_resolved(&self) -> bool {
        matches!(
            self.accept_state,
            AcceptState::Accepted | AcceptState::Rejected
        )
    }
}

#[derive(Debug, Error)]
pub enum SuggestionLedgerError {
    #[error("duplicate suggestion id: {0}")]
    DuplicateSuggestion(String),
    #[error("suggestion {0} not found in ledger")]
    SuggestionNotFound(String),
    #[error("new suggestion {0} must start pending before approval")]
    SuggestionMustStartPending(String),
    #[error("accept/reject decision cannot set suggestion {0} to pending")]
    InvalidPendingDecision(String),
    #[error("non-monotonic suggestion event sequence: previous {previous}, next {next}")]
    NonMonotonicSequence { previous: u64, next: u64 },
    #[error("suggestion replay hash mismatch (stored {stored}, computed {computed})")]
    IntegrityMismatch { stored: String, computed: String },
    #[error("serde_json error: {0}")]
    Serde(#[from] serde_json::Error),
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct SuggestionInsertedEvent {
    pub sequence: u64,
    pub suggestion: Suggestion,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct SuggestionAcceptStateChangedEvent {
    pub sequence: u64,
    pub suggestion_id: String,
    pub previous_state: AcceptState,
    pub accept_state: AcceptState,
    pub updated_at_ms: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct SuggestionRevertOperation {
    pub suggestion_id: String,
    pub note_id: String,
    #[serde(default)]
    pub object_id: String,
    #[serde(default)]
    pub object_type: ObjectType,
    #[serde(default)]
    pub range_payload: RangePayload,
    pub ranges: Vec<Range>,
    pub before_text: String,
    pub after_text: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct SuggestionTurnRevertedEvent {
    pub sequence: u64,
    pub companion_id: String,
    pub turn_id: String,
    pub reverted: Vec<SuggestionRevertOperation>,
    pub updated_at_ms: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct SuggestionCompactedEvent {
    pub sequence: u64,
    pub compacted_through_sequence: u64,
    pub retained_tail_events: usize,
    pub suggestions: Vec<Suggestion>,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum SuggestionLedgerEvent {
    Inserted(SuggestionInsertedEvent),
    AcceptStateChanged(SuggestionAcceptStateChangedEvent),
    TurnReverted(SuggestionTurnRevertedEvent),
    Compacted(SuggestionCompactedEvent),
}

impl SuggestionLedgerEvent {
    pub fn sequence(&self) -> u64 {
        match self {
            Self::Inserted(event) => event.sequence,
            Self::AcceptStateChanged(event) => event.sequence,
            Self::TurnReverted(event) => event.sequence,
            Self::Compacted(event) => event.sequence,
        }
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct SuggestionAcceptStateHistoryEntry {
    pub sequence: u64,
    pub suggestion_id: String,
    pub accept_state: AcceptState,
    pub updated_at_ms: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct SuggestionLedgerSnapshot {
    pub suggestions: Vec<Suggestion>,
    pub event_cursor: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct SuggestionReplayBundle {
    pub schema_version: u32,
    pub generated_at_ms: i64,
    pub snapshot: SuggestionLedgerSnapshot,
    pub events: Vec<SuggestionLedgerEvent>,
    pub integrity_hash: String,
}

impl SuggestionReplayBundle {
    pub fn build(
        generated_at_ms: i64,
        ledger: &SuggestionLedger,
    ) -> Result<Self, SuggestionLedgerError> {
        let mut bundle = Self {
            schema_version: SUGGESTION_REPLAY_BUNDLE_SCHEMA_VERSION,
            generated_at_ms,
            snapshot: ledger.snapshot_state(),
            events: ledger.events_since(0),
            integrity_hash: String::new(),
        };
        bundle.integrity_hash = bundle.compute_integrity_hash()?;
        Ok(bundle)
    }

    pub fn compute_integrity_hash(&self) -> Result<String, SuggestionLedgerError> {
        let mut hashable = self.clone();
        hashable.integrity_hash = String::new();
        let bytes = serde_json::to_vec(&hashable)?;
        Ok(blake3::hash(&bytes).to_hex().to_string())
    }

    pub fn verify_integrity(&self) -> Result<(), SuggestionLedgerError> {
        let computed = self.compute_integrity_hash()?;
        if computed == self.integrity_hash {
            Ok(())
        } else {
            Err(SuggestionLedgerError::IntegrityMismatch {
                stored: self.integrity_hash.clone(),
                computed,
            })
        }
    }

    pub fn replay(&self) -> Result<SuggestionLedger, SuggestionLedgerError> {
        self.verify_integrity()?;
        SuggestionLedger::replay(&self.events)
    }

    pub fn to_replay_bytes(&self) -> Result<Vec<u8>, SuggestionLedgerError> {
        Ok(serde_json::to_vec(self)?)
    }

    pub fn from_replay_bytes(bytes: &[u8]) -> Result<Self, SuggestionLedgerError> {
        Ok(serde_json::from_slice(bytes)?)
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SuggestionCompactionReport {
    pub compacted_through_sequence: u64,
    pub events_before: usize,
    pub events_after: usize,
    pub suggestions_checkpointed: usize,
}

#[derive(Debug, Default, Clone)]
pub struct SuggestionLedger {
    suggestions: HashMap<String, Suggestion>,
    events: Vec<SuggestionLedgerEvent>,
    next_event_sequence: u64,
}

impl SuggestionLedger {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn replay(events: &[SuggestionLedgerEvent]) -> Result<Self, SuggestionLedgerError> {
        let mut ledger = Self::new();
        let mut previous_sequence = 0u64;

        for event in events {
            let sequence = event.sequence();
            if sequence <= previous_sequence {
                return Err(SuggestionLedgerError::NonMonotonicSequence {
                    previous: previous_sequence,
                    next: sequence,
                });
            }
            ledger.apply_replayed_event(event)?;
            ledger.events.push(event.clone());
            previous_sequence = sequence;
            ledger.next_event_sequence = sequence;
        }

        Ok(ledger)
    }

    pub fn suggestion(&self, id: &str) -> Option<&Suggestion> {
        self.suggestions.get(id)
    }

    pub fn suggestion_count(&self) -> usize {
        self.suggestions.len()
    }

    pub fn event_count(&self) -> usize {
        self.events.len()
    }

    pub fn suggestions(&self) -> Vec<Suggestion> {
        let mut rows: Vec<Suggestion> = self.suggestions.values().cloned().collect();
        rows.sort_by(|a, b| a.note_id.cmp(&b.note_id).then_with(|| a.id.cmp(&b.id)));
        rows
    }

    pub fn events_since(&self, after_sequence: u64) -> Vec<SuggestionLedgerEvent> {
        self.events
            .iter()
            .filter(|event| event.sequence() > after_sequence)
            .cloned()
            .collect()
    }

    pub fn snapshot(
        &self,
        generated_at_ms: i64,
    ) -> Result<SuggestionReplayBundle, SuggestionLedgerError> {
        SuggestionReplayBundle::build(generated_at_ms, self)
    }

    pub fn snapshot_state(&self) -> SuggestionLedgerSnapshot {
        SuggestionLedgerSnapshot {
            suggestions: self.suggestions(),
            event_cursor: self.next_event_sequence,
        }
    }

    pub fn insert_suggestion(
        &mut self,
        suggestion: Suggestion,
    ) -> Result<(), SuggestionLedgerError> {
        Self::ensure_staged_suggestion(&suggestion)?;
        if self.suggestions.contains_key(&suggestion.id) {
            return Err(SuggestionLedgerError::DuplicateSuggestion(suggestion.id));
        }

        let sequence = self.next_sequence();
        self.suggestions
            .insert(suggestion.id.clone(), suggestion.clone());
        self.events
            .push(SuggestionLedgerEvent::Inserted(SuggestionInsertedEvent {
                sequence,
                suggestion,
            }));
        Ok(())
    }

    pub fn decide_suggestion(
        &mut self,
        suggestion_id: &str,
        accept_state: AcceptState,
        updated_at_ms: u64,
    ) -> Result<(), SuggestionLedgerError> {
        if accept_state == AcceptState::Pending {
            return Err(SuggestionLedgerError::InvalidPendingDecision(
                suggestion_id.to_string(),
            ));
        }

        let previous_state = self
            .suggestions
            .get(suggestion_id)
            .map(|suggestion| suggestion.accept_state)
            .ok_or_else(|| SuggestionLedgerError::SuggestionNotFound(suggestion_id.to_string()))?;

        let sequence = self.next_sequence();
        if let Some(suggestion) = self.suggestions.get_mut(suggestion_id) {
            suggestion.accept_state = accept_state;
            suggestion.updated_at_ms = updated_at_ms;
        }
        self.events.push(SuggestionLedgerEvent::AcceptStateChanged(
            SuggestionAcceptStateChangedEvent {
                sequence,
                suggestion_id: suggestion_id.to_string(),
                previous_state,
                accept_state,
                updated_at_ms,
            },
        ));
        Ok(())
    }

    pub fn accept_suggestion(
        &mut self,
        suggestion_id: &str,
        updated_at_ms: u64,
    ) -> Result<(), SuggestionLedgerError> {
        self.decide_suggestion(suggestion_id, AcceptState::Accepted, updated_at_ms)
    }

    pub fn reject_suggestion(
        &mut self,
        suggestion_id: &str,
        updated_at_ms: u64,
    ) -> Result<(), SuggestionLedgerError> {
        self.decide_suggestion(suggestion_id, AcceptState::Rejected, updated_at_ms)
    }

    pub fn revert_turn(
        &mut self,
        companion_id: &str,
        turn_id: &str,
        updated_at_ms: u64,
    ) -> Result<Vec<SuggestionRevertOperation>, SuggestionLedgerError> {
        let mut rows: Vec<Suggestion> = self
            .suggestions
            .values()
            .filter(|suggestion| {
                suggestion.is_companion_turn(companion_id, turn_id)
                    && suggestion.accept_state != AcceptState::Rejected
            })
            .cloned()
            .collect();
        rows.sort_by(|a, b| {
            a.created_at_ms
                .cmp(&b.created_at_ms)
                .then_with(|| a.id.cmp(&b.id))
        });

        let mut reverted: Vec<SuggestionRevertOperation> = rows
            .into_iter()
            .rev()
            .map(|suggestion| SuggestionRevertOperation {
                suggestion_id: suggestion.id,
                note_id: suggestion.note_id,
                object_id: suggestion.object_id,
                object_type: suggestion.object_type,
                range_payload: suggestion.range_payload,
                ranges: suggestion.ranges,
                before_text: suggestion.before_text,
                after_text: suggestion.after_text,
            })
            .collect();

        if reverted.is_empty() {
            return Ok(reverted);
        }

        let sequence = self.next_sequence();
        for operation in &reverted {
            if let Some(suggestion) = self.suggestions.get_mut(&operation.suggestion_id) {
                suggestion.accept_state = AcceptState::Rejected;
                suggestion.updated_at_ms = updated_at_ms;
            }
        }
        self.events.push(SuggestionLedgerEvent::TurnReverted(
            SuggestionTurnRevertedEvent {
                sequence,
                companion_id: companion_id.to_string(),
                turn_id: turn_id.to_string(),
                reverted: std::mem::take(&mut reverted),
                updated_at_ms,
            },
        ));

        match self.events.last() {
            Some(SuggestionLedgerEvent::TurnReverted(event)) => Ok(event.reverted.clone()),
            _ => Ok(Vec::new()),
        }
    }

    pub fn accept_state_history(
        &self,
        suggestion_id: &str,
    ) -> Vec<SuggestionAcceptStateHistoryEntry> {
        let mut history = Vec::new();
        for event in &self.events {
            match event {
                SuggestionLedgerEvent::Inserted(inserted)
                    if inserted.suggestion.id == suggestion_id =>
                {
                    history.push(SuggestionAcceptStateHistoryEntry {
                        sequence: inserted.sequence,
                        suggestion_id: suggestion_id.to_string(),
                        accept_state: inserted.suggestion.accept_state,
                        updated_at_ms: inserted.suggestion.updated_at_ms,
                    });
                }
                SuggestionLedgerEvent::AcceptStateChanged(decision)
                    if decision.suggestion_id == suggestion_id =>
                {
                    history.push(SuggestionAcceptStateHistoryEntry {
                        sequence: decision.sequence,
                        suggestion_id: suggestion_id.to_string(),
                        accept_state: decision.accept_state,
                        updated_at_ms: decision.updated_at_ms,
                    });
                }
                SuggestionLedgerEvent::TurnReverted(reverted)
                    if reverted
                        .reverted
                        .iter()
                        .any(|operation| operation.suggestion_id == suggestion_id) =>
                {
                    history.push(SuggestionAcceptStateHistoryEntry {
                        sequence: reverted.sequence,
                        suggestion_id: suggestion_id.to_string(),
                        accept_state: AcceptState::Rejected,
                        updated_at_ms: reverted.updated_at_ms,
                    });
                }
                SuggestionLedgerEvent::Compacted(compacted) => {
                    if let Some(suggestion) = compacted
                        .suggestions
                        .iter()
                        .find(|suggestion| suggestion.id == suggestion_id)
                    {
                        history.push(SuggestionAcceptStateHistoryEntry {
                            sequence: compacted.sequence,
                            suggestion_id: suggestion_id.to_string(),
                            accept_state: suggestion.accept_state,
                            updated_at_ms: suggestion.updated_at_ms,
                        });
                    }
                }
                _ => {}
            }
        }
        history
    }

    /// Compact an old event prefix into one checkpoint while retaining the
    /// newest `keep_recent_events` event tail. Replay remains exact for
    /// current accept-state and revert operations because the checkpoint
    /// carries full suggestion rows, not just aggregate counts.
    pub fn compact(
        &mut self,
        keep_recent_events: usize,
    ) -> Result<SuggestionCompactionReport, SuggestionLedgerError> {
        let events_before = self.events.len();
        if events_before <= keep_recent_events {
            return Ok(SuggestionCompactionReport {
                compacted_through_sequence: 0,
                events_before,
                events_after: events_before,
                suggestions_checkpointed: 0,
            });
        }

        let split_at = events_before.saturating_sub(keep_recent_events);
        let prefix_events = self.events[..split_at].to_vec();
        let tail_events = self.events[split_at..].to_vec();
        let prefix_ledger = Self::replay(&prefix_events)?;
        let compacted_through_sequence = prefix_events
            .last()
            .map(SuggestionLedgerEvent::sequence)
            .unwrap_or(0);
        let suggestions = prefix_ledger.suggestions();
        let suggestions_checkpointed = suggestions.len();
        let compacted = SuggestionLedgerEvent::Compacted(SuggestionCompactedEvent {
            sequence: compacted_through_sequence,
            compacted_through_sequence,
            retained_tail_events: keep_recent_events,
            suggestions,
        });

        let mut compacted_events = Vec::with_capacity(1usize.saturating_add(tail_events.len()));
        compacted_events.push(compacted);
        compacted_events.extend(tail_events);
        self.events = compacted_events;

        Ok(SuggestionCompactionReport {
            compacted_through_sequence,
            events_before,
            events_after: self.events.len(),
            suggestions_checkpointed,
        })
    }

    fn next_sequence(&mut self) -> u64 {
        let sequence = self.next_event_sequence.saturating_add(1);
        self.next_event_sequence = sequence;
        sequence
    }

    fn ensure_staged_suggestion(suggestion: &Suggestion) -> Result<(), SuggestionLedgerError> {
        if suggestion.accept_state == AcceptState::Pending {
            Ok(())
        } else {
            Err(SuggestionLedgerError::SuggestionMustStartPending(
                suggestion.id.clone(),
            ))
        }
    }

    fn apply_replayed_event(
        &mut self,
        event: &SuggestionLedgerEvent,
    ) -> Result<(), SuggestionLedgerError> {
        match event {
            SuggestionLedgerEvent::Inserted(inserted) => {
                Self::ensure_staged_suggestion(&inserted.suggestion)?;
                if self.suggestions.contains_key(&inserted.suggestion.id) {
                    return Err(SuggestionLedgerError::DuplicateSuggestion(
                        inserted.suggestion.id.clone(),
                    ));
                }
                self.suggestions
                    .insert(inserted.suggestion.id.clone(), inserted.suggestion.clone());
            }
            SuggestionLedgerEvent::AcceptStateChanged(decision) => {
                let suggestion = self
                    .suggestions
                    .get_mut(&decision.suggestion_id)
                    .ok_or_else(|| {
                        SuggestionLedgerError::SuggestionNotFound(decision.suggestion_id.clone())
                    })?;
                suggestion.accept_state = decision.accept_state;
                suggestion.updated_at_ms = decision.updated_at_ms;
            }
            SuggestionLedgerEvent::TurnReverted(reverted) => {
                for operation in &reverted.reverted {
                    let suggestion = self
                        .suggestions
                        .get_mut(&operation.suggestion_id)
                        .ok_or_else(|| {
                            SuggestionLedgerError::SuggestionNotFound(
                                operation.suggestion_id.clone(),
                            )
                        })?;
                    suggestion.accept_state = AcceptState::Rejected;
                    suggestion.updated_at_ms = reverted.updated_at_ms;
                }
            }
            SuggestionLedgerEvent::Compacted(compacted) => {
                self.suggestions.clear();
                for suggestion in &compacted.suggestions {
                    if self.suggestions.contains_key(&suggestion.id) {
                        return Err(SuggestionLedgerError::DuplicateSuggestion(
                            suggestion.id.clone(),
                        ));
                    }
                    self.suggestions
                        .insert(suggestion.id.clone(), suggestion.clone());
                }
            }
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn range(seed: u32) -> Range {
        Range {
            from_a: seed,
            to_a: seed + 1,
            from_b: seed + 2,
            to_b: seed + 3,
        }
    }

    fn suggestion(
        id: &str,
        note_id: &str,
        turn_id: &str,
        author: Author,
        created_at_ms: u64,
    ) -> Suggestion {
        let ranges = vec![range((created_at_ms % 100) as u32)];
        Suggestion {
            id: id.to_string(),
            note_id: note_id.to_string(),
            object_id: note_id.to_string(),
            object_type: ObjectType::NoteMarkdown,
            author,
            turn_id: turn_id.to_string(),
            range_payload: RangePayload::MarkdownOffsets {
                ranges: ranges.clone(),
            },
            ranges,
            before_text: format!("before-{id}"),
            after_text: format!("after-{id}"),
            rationale: Some(format!("why-{id}")),
            source_citation: Some("claim:test".to_string()),
            accept_state: AcceptState::Pending,
            created_at_ms,
            updated_at_ms: created_at_ms,
        }
    }

    #[test]
    fn append_accept_reject_and_replay_reconstructs_accept_state_history() {
        let mut ledger = SuggestionLedger::new();
        ledger
            .insert_suggestion(suggestion(
                "s1",
                "note-a",
                "turn-a",
                Author::Companion {
                    id: "companion-a".to_string(),
                },
                1,
            ))
            .unwrap();
        ledger.accept_suggestion("s1", 2).unwrap();
        ledger
            .insert_suggestion(suggestion("s2", "note-a", "turn-b", Author::June, 3))
            .unwrap();
        ledger.reject_suggestion("s2", 4).unwrap();

        let bytes = serde_json::to_vec(&ledger.events_since(0)).unwrap();
        let events: Vec<SuggestionLedgerEvent> = serde_json::from_slice(&bytes).unwrap();
        let restarted = SuggestionLedger::replay(&events).unwrap();

        assert_eq!(
            restarted.suggestion("s1").unwrap().accept_state,
            AcceptState::Accepted
        );
        assert_eq!(
            restarted.suggestion("s2").unwrap().accept_state,
            AcceptState::Rejected
        );
        let history = restarted.accept_state_history("s1");
        assert_eq!(history.len(), 2);
        assert_eq!(history[0].accept_state, AcceptState::Pending);
        assert_eq!(history[1].accept_state, AcceptState::Accepted);
        assert_eq!(restarted.events_since(1).len(), 3);
    }

    #[test]
    fn revert_turn_removes_exact_companion_turn_ranges_in_reverse_order() {
        let mut ledger = SuggestionLedger::new();
        let companion = Author::Companion {
            id: "companion-a".to_string(),
        };
        ledger
            .insert_suggestion(suggestion("s1", "note-a", "turn-a", companion.clone(), 1))
            .unwrap();
        ledger
            .insert_suggestion(suggestion("s2", "note-a", "turn-a", companion.clone(), 2))
            .unwrap();
        ledger
            .insert_suggestion(suggestion("s3", "note-a", "turn-b", companion, 3))
            .unwrap();
        ledger
            .insert_suggestion(suggestion("s4", "note-a", "turn-a", Author::User, 4))
            .unwrap();
        ledger.accept_suggestion("s1", 5).unwrap();

        let reverted = ledger.revert_turn("companion-a", "turn-a", 6).unwrap();

        let reverted_ids: Vec<String> = reverted
            .iter()
            .map(|operation| operation.suggestion_id.clone())
            .collect();
        assert_eq!(reverted_ids, vec!["s2".to_string(), "s1".to_string()]);
        assert_eq!(
            ledger.suggestion("s1").unwrap().accept_state,
            AcceptState::Rejected
        );
        assert_eq!(
            ledger.suggestion("s2").unwrap().accept_state,
            AcceptState::Rejected
        );
        assert_eq!(
            ledger.suggestion("s3").unwrap().accept_state,
            AcceptState::Pending
        );
        assert_eq!(
            ledger.suggestion("s4").unwrap().accept_state,
            AcceptState::Pending
        );

        let restarted = SuggestionLedger::replay(&ledger.events_since(0)).unwrap();
        assert_eq!(
            restarted.suggestion("s1").unwrap().accept_state,
            AcceptState::Rejected
        );
        assert_eq!(
            restarted.suggestion("s3").unwrap().accept_state,
            AcceptState::Pending
        );
    }

    #[test]
    fn tabular_suggestion_stages_a1_payload_and_accepts_only_by_event() {
        let mut ledger = SuggestionLedger::new();
        let tabular_range = TabularRange {
            dataset_id: "dataset:metrics.dataset.md".to_string(),
            sheet_id: Some("Sheet1".to_string()),
            a1_range: "A1:B3".to_string(),
        };
        let tabular = Suggestion {
            id: "tabular-1".to_string(),
            note_id: "note-a".to_string(),
            object_id: "dataset:metrics.dataset.md".to_string(),
            object_type: ObjectType::DatasetWorkbook,
            author: Author::June,
            turn_id: "turn-data".to_string(),
            range_payload: RangePayload::TabularA1 {
                ranges: vec![tabular_range.clone()],
            },
            ranges: Vec::new(),
            before_text: "A1:B3 before".to_string(),
            after_text: "A1:B3 after".to_string(),
            rationale: Some("Normalize metric labels".to_string()),
            source_citation: Some("claim:metrics-source".to_string()),
            accept_state: AcceptState::Pending,
            created_at_ms: 1,
            updated_at_ms: 1,
        };

        assert!(tabular.is_tabular());
        assert!(tabular.requires_approval());
        ledger.insert_suggestion(tabular).unwrap();

        let restarted = SuggestionLedger::replay(&ledger.events_since(0)).unwrap();
        let stored = restarted.suggestion("tabular-1").unwrap();
        assert_eq!(stored.accept_state, AcceptState::Pending);
        assert_eq!(stored.object_type, ObjectType::DatasetWorkbook);
        assert_eq!(stored.object_id, "dataset:metrics.dataset.md");
        assert!(stored.is_tabular());
        match &stored.range_payload {
            RangePayload::TabularA1 { ranges } => assert_eq!(ranges, &vec![tabular_range]),
            other => panic!("expected tabular A1 payload, got {other:?}"),
        }

        let mut eager = stored.clone();
        eager.id = "tabular-eager".to_string();
        eager.accept_state = AcceptState::Accepted;
        assert!(matches!(
            ledger.insert_suggestion(eager),
            Err(SuggestionLedgerError::SuggestionMustStartPending(id)) if id == "tabular-eager"
        ));

        let mut approved = restarted;
        approved.accept_suggestion("tabular-1", 2).unwrap();
        let history = approved.accept_state_history("tabular-1");
        assert_eq!(history.len(), 2);
        assert_eq!(history[0].accept_state, AcceptState::Pending);
        assert_eq!(history[1].accept_state, AcceptState::Accepted);
    }

    #[test]
    fn replay_bundle_is_hash_verified_and_replays_after_restart() {
        let mut ledger = SuggestionLedger::new();
        ledger
            .insert_suggestion(suggestion("s1", "note-a", "turn-a", Author::June, 1))
            .unwrap();
        ledger.accept_suggestion("s1", 2).unwrap();

        let bundle = ledger.snapshot(1_783_440_000_000).unwrap();
        let bytes = bundle.to_replay_bytes().unwrap();
        let decoded = SuggestionReplayBundle::from_replay_bytes(&bytes).unwrap();
        decoded.verify_integrity().unwrap();
        let restarted = decoded.replay().unwrap();

        assert_eq!(
            decoded.schema_version,
            SUGGESTION_REPLAY_BUNDLE_SCHEMA_VERSION
        );
        assert_eq!(decoded.snapshot.event_cursor, 2);
        assert_eq!(
            restarted.suggestion("s1").unwrap().accept_state,
            AcceptState::Accepted
        );
    }

    #[test]
    fn compaction_checkpoints_old_prefix_and_keeps_replay_exact() {
        let mut ledger = SuggestionLedger::new();
        for index in 0..5 {
            let id = format!("s{index}");
            ledger
                .insert_suggestion(suggestion(&id, "note-a", "turn-a", Author::June, index))
                .unwrap();
            if index < 4 {
                ledger.accept_suggestion(&id, 100 + index).unwrap();
            }
        }

        let report = ledger.compact(2).unwrap();
        let restarted = SuggestionLedger::replay(&ledger.events_since(0)).unwrap();

        assert_eq!(report.events_before, 9);
        assert_eq!(report.events_after, 3);
        assert!(report.suggestions_checkpointed >= 4);
        assert_eq!(restarted.suggestion_count(), 5);
        assert_eq!(
            restarted.suggestion("s0").unwrap().accept_state,
            AcceptState::Accepted
        );
        assert_eq!(
            restarted.suggestion("s4").unwrap().accept_state,
            AcceptState::Pending
        );
    }

    #[test]
    fn stress_10_000_suggestions_replay_and_compact() {
        let mut ledger = SuggestionLedger::new();
        for index in 0..10_000 {
            let id = format!("s-{index:05}");
            ledger
                .insert_suggestion(suggestion(
                    &id,
                    "note-stress",
                    "turn-stress",
                    Author::Companion {
                        id: "companion-stress".to_string(),
                    },
                    index,
                ))
                .unwrap();
            if index % 2 == 0 {
                ledger.accept_suggestion(&id, 20_000 + index).unwrap();
            } else if index % 3 == 0 {
                ledger.reject_suggestion(&id, 30_000 + index).unwrap();
            }
        }

        let bundle = ledger.snapshot(1_783_440_000_000).unwrap();
        let restarted = bundle.replay().unwrap();
        assert_eq!(restarted.suggestion_count(), 10_000);
        assert_eq!(
            restarted.suggestion("s-00000").unwrap().accept_state,
            AcceptState::Accepted
        );
        assert_eq!(
            restarted.suggestion("s-00003").unwrap().accept_state,
            AcceptState::Rejected
        );
        assert_eq!(
            restarted.suggestion("s-00005").unwrap().accept_state,
            AcceptState::Pending
        );

        let report = ledger.compact(256).unwrap();
        assert!(report.events_after <= 257);
        let compacted_restart = SuggestionLedger::replay(&ledger.events_since(0)).unwrap();
        assert_eq!(compacted_restart.suggestion_count(), 10_000);
        assert_eq!(
            compacted_restart
                .suggestion("s-09998")
                .unwrap()
                .accept_state,
            AcceptState::Accepted
        );
    }
}
