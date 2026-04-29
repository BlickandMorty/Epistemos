//! `AuditOrigin` — the three legitimate animation-trigger classes
//! per DOCTRINE §9.1.

use serde::{Deserialize, Serialize};

use crate::companions::{ActivityState, CompanionId};

/// Sequence number of an event in the persisted JSONL log
/// (`crate::event_log::LogEntry::seq`). Stable for the lifetime
/// of the log; used to link a `FrameDelta` back to the exact
/// event that produced it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct EventId(pub u64);

impl EventId {
    pub const fn new(seq: u64) -> Self {
        Self(seq)
    }

    pub const fn seq(self) -> u64 {
        self.0
    }
}

impl std::fmt::Display for EventId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// The three legitimate animation-trigger classes. Per DOCTRINE
/// §9.2 anything outside these three is a defect.
///
/// Serialised flat (`#[serde(tag = "kind")]`) so the audit row
/// can record the discriminator + variant fields in flat SQLite
/// columns rather than a JSON blob.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum AuditOrigin {
    /// Animation was triggered by a real `AgentEvent` (or graph
    /// event, which is a subset of AgentEvent per DOCTRINE I-4).
    /// `event_kind` carries the discriminator string from
    /// `AgentEvent::kind()` for filterable queries.
    Event {
        event_id: EventId,
        event_kind: String,
    },
    /// Cosmetic idle ambient animation: no events for ≥ N
    /// seconds for `companion_id`, since `since_seq`. Always
    /// labelled per DOCTRINE §9.1; never carries a fake event_id.
    CosmeticIdle {
        companion_id: CompanionId,
        since_seq: EventId,
    },
    /// Activity-state transition (Active → Recent → Dormant →
    /// Parked, etc.) emitted by the activity tracker tick.
    StateTransition {
        companion_id: CompanionId,
        from: ActivityState,
        to: ActivityState,
    },
}

impl AuditOrigin {
    /// Discriminator string. Matches the SQLite `origin_kind`
    /// column. Useful for filter queries that don't need the full
    /// payload.
    pub fn kind(&self) -> AuditOriginKind {
        match self {
            AuditOrigin::Event { .. } => AuditOriginKind::Event,
            AuditOrigin::CosmeticIdle { .. } => AuditOriginKind::CosmeticIdle,
            AuditOrigin::StateTransition { .. } => AuditOriginKind::StateTransition,
        }
    }

    /// The companion id this origin attributes to, if it has one.
    /// `Event` origins may or may not — depends on the underlying
    /// event variant. See `AgentEvent::primary_agent_id`.
    pub fn companion_id(&self) -> Option<CompanionId> {
        match self {
            AuditOrigin::Event { .. } => None,
            AuditOrigin::CosmeticIdle { companion_id, .. } => Some(*companion_id),
            AuditOrigin::StateTransition { companion_id, .. } => Some(*companion_id),
        }
    }
}

/// Discriminator-only enum used for audit-table queries. Maps
/// 1:1 to `AuditOrigin` variants but without payload — cheap to
/// pass to `AuditLedger::query_by_kind`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AuditOriginKind {
    Event,
    CosmeticIdle,
    StateTransition,
}

impl AuditOriginKind {
    pub fn as_str(self) -> &'static str {
        match self {
            AuditOriginKind::Event => "event",
            AuditOriginKind::CosmeticIdle => "cosmetic_idle",
            AuditOriginKind::StateTransition => "state_transition",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "event" => Some(AuditOriginKind::Event),
            "cosmetic_idle" => Some(AuditOriginKind::CosmeticIdle),
            "state_transition" => Some(AuditOriginKind::StateTransition),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cid(label: &str) -> CompanionId {
        use std::hash::{DefaultHasher, Hash, Hasher};
        let mut h = DefaultHasher::new();
        label.hash(&mut h);
        CompanionId(ulid::Ulid::from_parts(0, h.finish() as u128))
    }

    #[test]
    fn audit_origin_kind_round_trips_through_str() {
        for k in [
            AuditOriginKind::Event,
            AuditOriginKind::CosmeticIdle,
            AuditOriginKind::StateTransition,
        ] {
            assert_eq!(AuditOriginKind::parse(k.as_str()), Some(k));
        }
        assert_eq!(AuditOriginKind::parse("nope"), None);
    }

    #[test]
    fn audit_origin_kind_matches_variant() {
        let ev = AuditOrigin::Event {
            event_id: EventId::new(1),
            event_kind: "message_started".to_string(),
        };
        let idle = AuditOrigin::CosmeticIdle {
            companion_id: cid("a"),
            since_seq: EventId::new(0),
        };
        let trans = AuditOrigin::StateTransition {
            companion_id: cid("b"),
            from: ActivityState::Active,
            to: ActivityState::Recent,
        };
        assert_eq!(ev.kind(), AuditOriginKind::Event);
        assert_eq!(idle.kind(), AuditOriginKind::CosmeticIdle);
        assert_eq!(trans.kind(), AuditOriginKind::StateTransition);
    }

    #[test]
    fn companion_id_is_some_for_idle_and_transition_only() {
        let alice = cid("a");
        let ev = AuditOrigin::Event {
            event_id: EventId::new(1),
            event_kind: "session_started".to_string(),
        };
        let idle = AuditOrigin::CosmeticIdle {
            companion_id: alice,
            since_seq: EventId::new(0),
        };
        let trans = AuditOrigin::StateTransition {
            companion_id: alice,
            from: ActivityState::Active,
            to: ActivityState::Recent,
        };
        assert_eq!(ev.companion_id(), None);
        assert_eq!(idle.companion_id(), Some(alice));
        assert_eq!(trans.companion_id(), Some(alice));
    }

    #[test]
    fn audit_origin_serde_round_trip() {
        let origin = AuditOrigin::Event {
            event_id: EventId::new(42),
            event_kind: "tool_call_started".to_string(),
        };
        let json = serde_json::to_string(&origin).unwrap();
        // Tag is `kind` per the serde annotation.
        assert!(json.contains("\"kind\":\"event\""));
        let decoded: AuditOrigin = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded, origin);
    }
}
