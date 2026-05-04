//! AgentEvent v1.6 forward variants — additive to the existing event system.
//!
//! These six event kinds represent higher-level cognitive operations that flow
//! through the same provenance pipeline (OpLog + EventStore) as legacy events:
//!
//! | Variant | Purpose |
//! |---------|---------|
//! | [`SteerRequested`](AgentEventV16::SteerRequested) | User steering intent |
//! | [`SummaryStarted`](AgentEventV16::SummaryStarted) | Summary generation begins |
//! | [`SummaryDelta`](AgentEventV16::SummaryDelta) | Streaming summary chunk |
//! | [`SummaryCompleted`](AgentEventV16::SummaryCompleted) | Summary finalization |
//! | [`VaultCreated`](AgentEventV16::VaultCreated) | New memory vault |
//! | [`VaultArchived`](AgentEventV16::VaultArchived) | Vault soft-delete |
//!
//! All variants carry a `prev_hash: [u8; 32]` field, enabling BLAKE3 chain
//! linking through [`EventSerializer`]. The [`UnifiedAgentEvent`] envelope
//! allows mixing legacy and v1.6 events in a single stream.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use tracing::{debug, error};

// ---------------------------------------------------------------------------
// Direction / reason enums
// ---------------------------------------------------------------------------

/// Direction of a steering request.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum SteerDirection {
    /// Steer cognition *toward* the target topic.
    Toward,
    /// Steer cognition *away* from the target topic.
    Away,
    /// Hold current focus — no change.
    Hold,
}

/// Reason a vault was archived (soft-delete).
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum ArchiveReason {
    /// Archive was explicitly requested by the user.
    UserRequest,
    /// Archive triggered by automatic retention policy.
    AutoPurge,
    /// Companion/agent initiated deletion.
    CompanionDelete,
}

// ---------------------------------------------------------------------------
// AgentEvent v1.6
// ---------------------------------------------------------------------------

/// AgentEvent v1.6 forward kinds — additive to the existing `AgentEvent` enum.
///
/// Every variant contains:
/// - A domain-specific payload (`session_id`, `vault_id`, etc.).
/// - A `timestamp: DateTime<Utc>` for wall-clock ordering.
/// - A `prev_hash: [u8; 32]` that links this event into the BLAKE3 chain.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub enum AgentEventV16 {
    /// User requested a steering operation (e.g., "focus on X", "ignore Y").
    SteerRequested {
        session_id: String,
        /// What to steer toward / away from.
        steer_target: String,
        /// Direction of the steering vector.
        steer_direction: SteerDirection,
        timestamp: DateTime<Utc>,
        /// OpLog chain link — hash of the previous event.
        prev_hash: [u8; 32],
    },

    /// Summary generation began.
    SummaryStarted {
        session_id: String,
        /// Vaults whose contents feed the summary.
        source_vault_ids: Vec<String>,
        /// Identifier of the model performing summarization.
        model_id: String,
        timestamp: DateTime<Utc>,
        prev_hash: [u8; 32],
    },

    /// Summary generation produced intermediate output (streaming).
    SummaryDelta {
        session_id: String,
        /// Monotonically increasing chunk index.
        delta_index: usize,
        /// Tokens in this chunk.
        token_count: usize,
        timestamp: DateTime<Utc>,
        prev_hash: [u8; 32],
    },

    /// Summary generation completed.
    SummaryCompleted {
        session_id: String,
        /// Total tokens in the final summary.
        final_token_count: usize,
        /// BLAKE3 hash of the final summary text.
        output_hash: [u8; 32],
        timestamp: DateTime<Utc>,
        prev_hash: [u8; 32],
    },

    /// New vault created.
    VaultCreated {
        vault_id: String,
        vault_name: String,
        /// Companion that owns the vault, if any.
        companion_id: Option<String>,
        timestamp: DateTime<Utc>,
        prev_hash: [u8; 32],
    },

    /// Vault archived (soft delete).
    VaultArchived {
        vault_id: String,
        /// Why the vault was archived.
        archive_reason: ArchiveReason,
        timestamp: DateTime<Utc>,
        prev_hash: [u8; 32],
    },
}

impl AgentEventV16 {
    /// Extract the `prev_hash` field, regardless of variant.
    pub fn prev_hash(&self) -> [u8; 32] {
        match self {
            AgentEventV16::SteerRequested { prev_hash, .. } => *prev_hash,
            AgentEventV16::SummaryStarted { prev_hash, .. } => *prev_hash,
            AgentEventV16::SummaryDelta { prev_hash, .. } => *prev_hash,
            AgentEventV16::SummaryCompleted { prev_hash, .. } => *prev_hash,
            AgentEventV16::VaultCreated { prev_hash, .. } => *prev_hash,
            AgentEventV16::VaultArchived { prev_hash, .. } => *prev_hash,
        }
    }

    /// Extract the `timestamp` field, regardless of variant.
    pub fn timestamp(&self) -> DateTime<Utc> {
        match self {
            AgentEventV16::SteerRequested { timestamp, .. } => *timestamp,
            AgentEventV16::SummaryStarted { timestamp, .. } => *timestamp,
            AgentEventV16::SummaryDelta { timestamp, .. } => *timestamp,
            AgentEventV16::SummaryCompleted { timestamp, .. } => *timestamp,
            AgentEventV16::VaultCreated { timestamp, .. } => *timestamp,
            AgentEventV16::VaultArchived { timestamp, .. } => *timestamp,
        }
    }
}

// ---------------------------------------------------------------------------
// Unified envelope
// ---------------------------------------------------------------------------

/// Unified event envelope — can hold either legacy or v1.6 events in one stream.
///
/// The [`UnifiedAgentEvent::Legacy`] variant stores raw JSON for events whose
/// shape is not yet known to this crate, allowing forward-compatible mixing.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub enum UnifiedAgentEvent {
    /// Existing events — passed through as raw JSON.
    Legacy(serde_json::Value),
    /// New forward variants.
    V16(AgentEventV16),
}

// ---------------------------------------------------------------------------
// Chain error
// ---------------------------------------------------------------------------

/// Errors that can occur during chain verification.
#[derive(thiserror::Error, Debug, Clone, PartialEq, Eq)]
pub enum ChainError {
    /// The chain link at the given index does not hash to the expected value.
    #[error("chain break at index {0}")]
    BreakAt(usize),
    /// Deserialization failed while verifying the chain.
    #[error("deserialization failed at index {0}: {1}")]
    DeserFailed(usize, String),
}

// ---------------------------------------------------------------------------
// EventSerializer — BLAKE3 chain linking
// ---------------------------------------------------------------------------

/// Event serializer with BLAKE3 chain linking.
///
/// Each call to [`serialize`](EventSerializer::serialize):
/// 1. Serializes the event to canonical JSON bytes.
/// 2. Computes `hash(prev_hash || json_bytes)`.
/// 3. Stores the result in `last_hash`, becoming the `prev_hash` for the next
///    event.
///
/// # Example
/// ```
/// use helios_runtime::events_v16::{EventSerializer, AgentEventV16, SteerDirection};
/// use chrono::Utc;
///
/// let mut ser = EventSerializer::new([0u8; 32]);
/// let event = AgentEventV16::SteerRequested {
///     session_id: "sess-1".into(),
///     steer_target: "planning".into(),
///     steer_direction: SteerDirection::Toward,
///     timestamp: Utc::now(),
///     prev_hash: [0u8; 32], // filled by serializer
/// };
/// let _bytes = ser.serialize(&event);
/// ```
#[derive(Clone, Debug)]
pub struct EventSerializer {
    /// Hash of the most recently serialized event. Starts at the genesis hash.
    pub last_hash: [u8; 32],
}

impl EventSerializer {
    /// Create a new serializer anchored at the given genesis hash.
    pub fn new(genesis: [u8; 32]) -> Self {
        debug!(genesis = ?hex::encode(genesis), "EventSerializer created");
        Self { last_hash: genesis }
    }

    /// Serialize an event to canonical JSON bytes and advance the chain hash.
    ///
    /// # Panics
    ///
    /// Panics only if `serde_json` fails to serialize, which should never happen
    /// for this well-defined enum.
    #[tracing::instrument(skip(self, event), fields(variant = ?std::mem::discriminant(event)), level = "debug")]
    pub fn serialize(&mut self, event: &AgentEventV16) -> Vec<u8> {
        let json = serde_json::to_vec(event).expect("AgentEventV16 serializes infallibly");
        let mut hasher = blake3::Hasher::new();
        hasher.update(&self.last_hash);
        hasher.update(&json);
        self.last_hash = *hasher.finalize().as_bytes();
        debug!(new_hash = ?hex::encode(self.last_hash), bytes = json.len(), "event serialized");
        json
    }

    /// Serialize a [`UnifiedAgentEvent`] envelope.
    ///
    /// For [`UnifiedAgentEvent::Legacy`] the inner JSON is re-serialized to
    /// ensure a single canonical byte representation.
    #[tracing::instrument(skip(self, event), level = "debug")]
    pub fn serialize_unified(&mut self, event: &UnifiedAgentEvent) -> Vec<u8> {
        let json = serde_json::to_vec(event).expect("UnifiedAgentEvent serializes infallibly");
        let mut hasher = blake3::Hasher::new();
        hasher.update(&self.last_hash);
        hasher.update(&json);
        self.last_hash = *hasher.finalize().as_bytes();
        debug!(new_hash = ?hex::encode(self.last_hash), bytes = json.len(), "unified event serialized");
        json
    }

    /// Verify an ordered slice of serialized events against a genesis hash.
    ///
    /// Each event is deserialized to extract its embedded `prev_hash`. The
    /// running hash is then computed as `blake3(prev_hash || event_bytes)` and
    /// compared with the next event's `prev_hash`. The first event must link
    /// to `genesis`.
    ///
    /// # Errors
    ///
    /// Returns [`ChainError::BreakAt`] if any link in the chain is broken,
    /// or [`ChainError::DeserFailed`] if an event cannot be deserialized.
    #[tracing::instrument(skip(events), fields(count = events.len()), level = "info")]
    pub fn verify_chain(events: &[Vec<u8>], genesis: [u8; 32]) -> Result<(), ChainError> {
        let mut expected_prev = genesis;

        for (idx, event_bytes) in events.iter().enumerate() {
            // Deserialize to extract the embedded prev_hash.
            let event: AgentEventV16 = serde_json::from_slice(event_bytes).map_err(|e| {
                ChainError::DeserFailed(idx, e.to_string())
            })?;
            let actual_prev = event.prev_hash();

            if actual_prev != expected_prev {
                error!(
                    index = idx,
                    expected = ?hex::encode(expected_prev),
                    actual = ?hex::encode(actual_prev),
                    "chain break detected"
                );
                return Err(ChainError::BreakAt(idx));
            }

            // Advance the running hash for the next link.
            let mut hasher = blake3::Hasher::new();
            hasher.update(&expected_prev);
            hasher.update(event_bytes);
            expected_prev = *hasher.finalize().as_bytes();
        }

        debug!(final_hash = ?hex::encode(expected_prev), "chain verified");
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;

    // -----------------------------------------------------------------------
    // 1. Round-trip serialization of SteerRequested
    // -----------------------------------------------------------------------

    #[test]
    fn test_steer_requested_serializes() {
        let event = AgentEventV16::SteerRequested {
            session_id: "sess-steer-01".into(),
            steer_target: "focus_on_planning".into(),
            steer_direction: SteerDirection::Toward,
            timestamp: Utc::now(),
            prev_hash: [0u8; 32],
        };

        let json = serde_json::to_vec(&event).expect("serialize");
        let back: AgentEventV16 = serde_json::from_slice(&json).expect("deserialize");

        assert_eq!(event, back);
        assert!(json.len() > 0);
    }

    // -----------------------------------------------------------------------
    // 2. 10 summary deltas, verify chain integrity
    // -----------------------------------------------------------------------

    #[test]
    fn test_summary_delta_chain() {
        let genesis = [0u8; 32];
        let mut ser = EventSerializer::new(genesis);
        let session = "sess-summary-42";

        let mut serialized: Vec<Vec<u8>> = Vec::with_capacity(10);
        let mut last_hash = genesis;

        for i in 0..10 {
            // Construct event with the CURRENT last_hash as prev_hash.
            let event = AgentEventV16::SummaryDelta {
                session_id: session.into(),
                delta_index: i,
                token_count: 16 + i * 4,
                timestamp: Utc::now(),
                prev_hash: last_hash,
            };

            let bytes = ser.serialize(&event);
            serialized.push(bytes.clone());
            last_hash = ser.last_hash;

            // Ensure the serializer advanced.
            assert_ne!(last_hash, [0u8; 32], "hash must advance after event {i}");
        }

        // Verify the full chain.
        EventSerializer::verify_chain(&serialized, genesis)
            .expect("chain must verify for 10 deltas");
    }

    // -----------------------------------------------------------------------
    // 3. VaultCreated prev_hash linkage
    // -----------------------------------------------------------------------

    #[test]
    fn test_vault_created_prev_hash_links() {
        let genesis = [42u8; 32];
        let mut ser = EventSerializer::new(genesis);

        let event_a = AgentEventV16::VaultCreated {
            vault_id: "vault-alpha".into(),
            vault_name: "Alpha Vault".into(),
            companion_id: Some("companion-1".into()),
            timestamp: Utc::now(),
            prev_hash: genesis,
        };
        let bytes_a = ser.serialize(&event_a);
        let hash_after_a = ser.last_hash;

        let event_b = AgentEventV16::VaultCreated {
            vault_id: "vault-beta".into(),
            vault_name: "Beta Vault".into(),
            companion_id: None,
            timestamp: Utc::now(),
            prev_hash: hash_after_a,
        };
        let bytes_b = ser.serialize(&event_b);

        // Event B's prev_hash must match the hash after event A.
        assert_eq!(event_b.prev_hash, hash_after_a);

        // Verify the two-event chain.
        EventSerializer::verify_chain(&[bytes_a, bytes_b], genesis)
            .expect("two-event vault chain must verify");
    }

    // -----------------------------------------------------------------------
    // 4. VaultArchived round-trip with all ArchiveReason variants
    // -----------------------------------------------------------------------

    #[test]
    fn test_vault_archived_roundtrip() {
        let genesis = [7u8; 32];
        let reasons = [
            ArchiveReason::UserRequest,
            ArchiveReason::AutoPurge,
            ArchiveReason::CompanionDelete,
        ];

        for reason in &reasons {
            let mut ser = EventSerializer::new(genesis);

            let event = AgentEventV16::VaultArchived {
                vault_id: "vault-archive-test".into(),
                archive_reason: reason.clone(),
                timestamp: Utc::now(),
                prev_hash: genesis,
            };

            let bytes = ser.serialize(&event);
            let back: AgentEventV16 = serde_json::from_slice(&bytes).expect("deserialize");

            assert_eq!(event, back);
            assert_eq!(back.prev_hash(), genesis);

            match back {
                AgentEventV16::VaultArchived { archive_reason, .. } => {
                    assert_eq!(&archive_reason, reason);
                }
                _ => panic!("expected VaultArchived variant"),
            }
        }
    }

    // -----------------------------------------------------------------------
    // 5. Chain break detection
    // -----------------------------------------------------------------------

    #[test]
    fn test_chain_break_detected() {
        let genesis = [1u8; 32];
        let mut ser = EventSerializer::new(genesis);

        let event_ok = AgentEventV16::SummaryDelta {
            session_id: "sess".into(),
            delta_index: 0,
            token_count: 10,
            timestamp: Utc::now(),
            prev_hash: genesis,
        };
        let bytes_ok = ser.serialize(&event_ok);

        // Tamper with the second event's prev_hash.
        let bad_event = AgentEventV16::SummaryDelta {
            session_id: "sess".into(),
            delta_index: 1,
            token_count: 20,
            timestamp: Utc::now(),
            prev_hash: [99u8; 32], // deliberately wrong
        };
        let bytes_bad = serde_json::to_vec(&bad_event).expect("serialize");

        let result = EventSerializer::verify_chain(&[bytes_ok, bytes_bad], genesis);
        assert!(
            matches!(result, Err(ChainError::BreakAt(1))),
            "expected BreakAt(1), got {result:?}"
        );
    }

    // -----------------------------------------------------------------------
    // 6. UnifiedAgentEvent envelope round-trip
    // -----------------------------------------------------------------------

    #[test]
    fn test_unified_event_v16_roundtrip() {
        let event = AgentEventV16::SteerRequested {
            session_id: "sess-unified".into(),
            steer_target: "refactor".into(),
            steer_direction: SteerDirection::Hold,
            timestamp: Utc::now(),
            prev_hash: [0u8; 32],
        };
        let unified = UnifiedAgentEvent::V16(event.clone());

        let json = serde_json::to_vec(&unified).expect("serialize unified");
        let back: UnifiedAgentEvent = serde_json::from_slice(&json).expect("deserialize unified");

        assert_eq!(back, unified);
        match back {
            UnifiedAgentEvent::V16(e) => assert_eq!(e, event),
            _ => panic!("expected V16 variant"),
        }
    }

    #[test]
    fn test_unified_event_legacy_roundtrip() {
        let legacy = serde_json::json!({
            "kind": "legacy_stuff",
            "payload": { "x": 1 }
        });
        let unified = UnifiedAgentEvent::Legacy(legacy);

        let json = serde_json::to_vec(&unified).expect("serialize unified");
        let back: UnifiedAgentEvent = serde_json::from_slice(&json).expect("deserialize unified");

        assert_eq!(back, unified);
    }

    // -----------------------------------------------------------------------
    // 7. EventSerializer new() helper
    // -----------------------------------------------------------------------

    #[test]
    fn test_serializer_new_genesis() {
        let genesis = [0xABu8; 32];
        let ser = EventSerializer::new(genesis);
        assert_eq!(ser.last_hash, genesis);
    }

    // -----------------------------------------------------------------------
    // 8. SteerDirection and ArchiveReason equality
    // -----------------------------------------------------------------------

    #[test]
    fn test_steer_direction_variants_not_equal() {
        assert_ne!(SteerDirection::Toward, SteerDirection::Away);
        assert_ne!(SteerDirection::Away, SteerDirection::Hold);
        assert_ne!(SteerDirection::Hold, SteerDirection::Toward);
    }

    #[test]
    fn test_archive_reason_variants_not_equal() {
        assert_ne!(ArchiveReason::UserRequest, ArchiveReason::AutoPurge);
        assert_ne!(ArchiveReason::AutoPurge, ArchiveReason::CompanionDelete);
        assert_ne!(ArchiveReason::CompanionDelete, ArchiveReason::UserRequest);
    }
}
