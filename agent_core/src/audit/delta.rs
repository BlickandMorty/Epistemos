//! `FrameDelta` — the unit of work the reducer emits per event,
//! tagged with its `AuditOrigin` per DOCTRINE I-5 (S3).
//!
//! Each `FrameDelta` represents one observable change in the
//! simulation: a sprite entering, a prop swap, an animation-state
//! transition, an approval gate appearing, etc. The reducer (S4)
//! produces these by pattern-matching on `AgentEvent`; the FFI
//! delta ring (S4 too) packs them into the `PerInstanceData`
//! shape that crosses to Swift; the `AuditLedger` (this slice)
//! records the (delta_id → origin) link so the Audit View can
//! answer "Why is this animation happening?".
//!
//! At S3 the reducer doesn't exist yet — `SimulationState::apply`
//! is still the S2 counter projection. The `FrameDelta::for_event`
//! constructor here is a deterministic stub the property test
//! exercises so the contract "every FrameDelta has an
//! AuditOrigin" holds with the API surface that S4 will inherit.

use serde::{Deserialize, Serialize};
use ulid::Ulid;

use super::origin::{AuditOrigin, EventId};
use crate::events::AgentEvent;

/// Unique handle for one frame delta. Monotonic-ULID-ordered so
/// the audit log naturally sorts by emission time.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct DeltaId(pub Ulid);

impl DeltaId {
    pub fn new() -> Self {
        Self(Ulid::new())
    }

    pub fn parse(s: &str) -> Option<Self> {
        Ulid::from_string(s).ok().map(Self)
    }
}

impl Default for DeltaId {
    fn default() -> Self {
        Self::new()
    }
}

impl std::fmt::Display for DeltaId {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.0)
    }
}

/// What kind of change this delta represents. The reducer uses
/// the variant to dispatch animation-state updates Swift-side at
/// S4. At S3 we declare the canonical V1 set so the API surface
/// is stable; later slices add variants without restructuring.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FrameDeltaKind {
    /// Companion entered a placement (Landing Farm /
    /// Graph Theater).
    AgentEntered,
    /// Companion left a placement.
    AgentLeft,
    /// Animation state changed (idle / walk / think / speak /
    /// tool / spawn / handoff_give / handoff_receive / retrieve /
    /// error / recover / success / sleep / gate, per DOCTRINE
    /// §5.3).
    AgentAnimation,
    /// Held prop changed (wrench / scroll / magnifier / folder /
    /// baton / lantern, DOCTRINE §5.5 Category A).
    AgentProp,
    /// Palette tint changed (cosmetic; logged per §5.5
    /// Category B).
    AgentTint,
    /// Approval gate appeared / dissolved (DOCTRINE §4.4).
    ApprovalGate,
    /// Activity state transition (Active / Recent / Dormant /
    /// Parked, DOCTRINE §3.2).
    ActivityState,
    /// Graph node pulse on memory retrieval (DOCTRINE §4.6).
    GraphPulse,
    /// Subagent spawn / despawn (DOCTRINE §4.5).
    SubagentSpawn,
    SubagentDespawn,
    /// Handoff scroll travel (DOCTRINE §4.3).
    HandoffScroll,
    /// Hermes coiling around accessed nodes (DOCTRINE §8).
    HermesCoil,
}

/// One observable change emitted by the reducer. Per DOCTRINE
/// I-5 the `origin` field is **not optional** — every delta must
/// trace to one of the three legitimate trigger classes. The
/// type system enforces this: `FrameDelta` cannot be constructed
/// without an `AuditOrigin`.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct FrameDelta {
    pub delta_id: DeltaId,
    pub origin: AuditOrigin,
    pub kind: FrameDeltaKind,
}

impl FrameDelta {
    /// Build a delta from an `AgentEvent` reaching the reducer
    /// at log sequence `seq`. The origin is `AuditOrigin::Event`
    /// (the canonical event-driven class per DOCTRINE §9.1).
    ///
    /// At S3 this is the only constructor exercised by tests
    /// (the property test feeds `&[AgentEvent]` and asserts
    /// every emitted delta has a non-null origin). At S4 the
    /// reducer's per-variant logic will pick the right
    /// `FrameDeltaKind` per event type and may emit several
    /// deltas per event (e.g., `SubagentSpawned` produces one
    /// `SubagentSpawn` plus N `AgentEntered` deltas, one per
    /// child).
    pub fn for_event(seq: u64, event: &AgentEvent) -> Self {
        Self {
            delta_id: DeltaId::new(),
            origin: AuditOrigin::Event {
                event_id: EventId::new(seq),
                event_kind: event.kind().to_string(),
            },
            kind: kind_for_event(event),
        }
    }

    /// Build a cosmetic-idle delta. Always labelled per DOCTRINE
    /// §9.1 — never carries a fake event_id.
    pub fn for_cosmetic_idle(
        companion_id: crate::companions::CompanionId,
        since_seq: u64,
        kind: FrameDeltaKind,
    ) -> Self {
        Self {
            delta_id: DeltaId::new(),
            origin: AuditOrigin::CosmeticIdle {
                companion_id,
                since_seq: EventId::new(since_seq),
            },
            kind,
        }
    }

    /// Build a state-transition delta. The reducer emits one of
    /// these whenever the activity tracker reports an
    /// `ActivityTransition` (DOCTRINE §3.2 transitions).
    pub fn for_state_transition(
        companion_id: crate::companions::CompanionId,
        from: crate::companions::ActivityState,
        to: crate::companions::ActivityState,
    ) -> Self {
        Self {
            delta_id: DeltaId::new(),
            origin: AuditOrigin::StateTransition {
                companion_id,
                from,
                to,
            },
            kind: FrameDeltaKind::ActivityState,
        }
    }
}

/// Default mapping from `AgentEvent` variant → reducer-emitted
/// `FrameDeltaKind`. S4 will refine this to emit multiple deltas
/// per event where appropriate (e.g., `SubagentSpawned` →
/// `SubagentSpawn` + N `AgentEntered`).
///
/// This stub is exposed publicly for the property test and for
/// S4 to extend; the per-variant tableau lives close to the
/// FrameDelta type so adding a new `AgentEvent` variant forces
/// the implementer to consciously pick a default kind here.
pub fn kind_for_event(event: &AgentEvent) -> FrameDeltaKind {
    match event {
        AgentEvent::ParticipantJoined { .. } => FrameDeltaKind::AgentEntered,
        AgentEvent::ParticipantLeft { .. } => FrameDeltaKind::AgentLeft,
        AgentEvent::MessageStarted { .. }
        | AgentEvent::MessageDelta { .. }
        | AgentEvent::MessageCompleted { .. }
        | AgentEvent::ThinkingStarted { .. }
        | AgentEvent::ThinkingDelta { .. }
        | AgentEvent::ThinkingCompleted { .. } => FrameDeltaKind::AgentAnimation,
        AgentEvent::ToolCallStarted { .. }
        | AgentEvent::ToolCallDelta { .. }
        | AgentEvent::ToolCallCompleted { .. }
        | AgentEvent::ToolCallFailed { .. } => FrameDeltaKind::AgentProp,
        AgentEvent::MemoryRetrieved { .. }
        | AgentEvent::GraphTraverseStarted { .. }
        | AgentEvent::GraphTraverseCompleted { .. }
        | AgentEvent::GraphNodeAccessed { .. }
        | AgentEvent::GraphNodeCreated { .. }
        | AgentEvent::GraphEdgeCreated { .. } => FrameDeltaKind::GraphPulse,
        AgentEvent::SubagentSpawned { .. } => FrameDeltaKind::SubagentSpawn,
        AgentEvent::SubagentCompleted { .. } => FrameDeltaKind::SubagentDespawn,
        AgentEvent::HandoffStarted { .. } | AgentEvent::HandoffCompleted { .. } => {
            FrameDeltaKind::HandoffScroll
        }
        AgentEvent::AwaitingApproval { .. }
        | AgentEvent::ApprovalGranted { .. }
        | AgentEvent::ApprovalDenied { .. } => FrameDeltaKind::ApprovalGate,
        AgentEvent::CompanionActivityStateChanged { .. } => FrameDeltaKind::ActivityState,
        AgentEvent::CompanionRegistered { .. } => FrameDeltaKind::AgentEntered,
        AgentEvent::CompanionArchived { .. } => FrameDeltaKind::AgentLeft,
        AgentEvent::Error { .. }
        | AgentEvent::RecoveryStarted { .. }
        | AgentEvent::RecoveryCompleted { .. } => FrameDeltaKind::AgentAnimation,
        // Session lifecycle, artifacts, tasks, gift boxes,
        // workspace focus, companion update — animate generically
        // at S3. The S4 reducer refines these per the
        // DOCTRINE §3 / §4 / §6 / §7 sections.
        AgentEvent::SessionStarted { .. }
        | AgentEvent::SessionCompleted { .. }
        | AgentEvent::SessionCommitted { .. }
        | AgentEvent::ArtifactCreated { .. }
        | AgentEvent::TaskCreated { .. }
        | AgentEvent::TaskCompleted { .. }
        | AgentEvent::CompanionUpdated { .. }
        | AgentEvent::GiftBoxReceived { .. }
        | AgentEvent::GiftBoxUnwrapped { .. }
        | AgentEvent::WorkspaceFocused { .. } => FrameDeltaKind::AgentAnimation,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::companions::{ActivityState, CompanionId, ProviderRole};
    use crate::events::{ArtifactRef, ArtifactKind, ArtifactId, MessageId, ToolCallId};

    fn cid() -> CompanionId {
        CompanionId::new_ulid()
    }

    #[test]
    fn for_event_attributes_to_correct_kind() {
        let alice = cid();
        let cases = [
            (
                AgentEvent::ParticipantJoined {
                    agent_id: alice,
                    role: ProviderRole::CodeWorker,
                },
                FrameDeltaKind::AgentEntered,
            ),
            (
                AgentEvent::MessageStarted {
                    message_id: MessageId::new("m"),
                    agent_id: alice,
                },
                FrameDeltaKind::AgentAnimation,
            ),
            (
                AgentEvent::ToolCallStarted {
                    tool_call_id: ToolCallId::new("t"),
                    agent_id: alice,
                    tool_name: "code_edit".to_string(),
                    input_hash: crate::events::Blake3Hash::of(b""),
                },
                FrameDeltaKind::AgentProp,
            ),
            (
                AgentEvent::MemoryRetrieved {
                    agent_id: alice,
                    node_id: crate::events::NodeId::new("n"),
                    score: 0.5,
                },
                FrameDeltaKind::GraphPulse,
            ),
            (
                AgentEvent::SubagentSpawned {
                    parent_id: alice,
                    child_id: cid(),
                    count: 1,
                },
                FrameDeltaKind::SubagentSpawn,
            ),
            (
                AgentEvent::AwaitingApproval {
                    agent_id: alice,
                    action: crate::events::PendingAction {
                        action_id: crate::events::ActionId::new("a"),
                        kind: crate::events::PendingActionKind::ToolCall,
                        description: "x".to_string(),
                        tool_name: None,
                        input: serde_json::Value::Null,
                    },
                    deadline_ms: 1_000,
                },
                FrameDeltaKind::ApprovalGate,
            ),
        ];
        for (event, expected_kind) in cases {
            let delta = FrameDelta::for_event(1, &event);
            assert_eq!(delta.kind, expected_kind, "{:?}", event.kind());
            // Origin is always Event-class for `for_event` constructor.
            assert!(matches!(delta.origin, AuditOrigin::Event { .. }));
        }
    }

    #[test]
    fn for_event_origin_carries_correct_event_id_and_kind_string() {
        let evt = AgentEvent::HandoffStarted {
            from_id: cid(),
            to_id: cid(),
            payload_id: ArtifactRef {
                id: ArtifactId::new("a"),
                kind: ArtifactKind::Document,
            },
        };
        let d = FrameDelta::for_event(7, &evt);
        match d.origin {
            AuditOrigin::Event { event_id, event_kind } => {
                assert_eq!(event_id, EventId::new(7));
                assert_eq!(event_kind, "handoff_started");
            }
            other => panic!("expected Event origin, got {other:?}"),
        }
    }

    #[test]
    fn cosmetic_idle_origin_carries_companion_and_since_seq() {
        let alice = cid();
        let d = FrameDelta::for_cosmetic_idle(alice, 12, FrameDeltaKind::AgentAnimation);
        match d.origin {
            AuditOrigin::CosmeticIdle {
                companion_id,
                since_seq,
            } => {
                assert_eq!(companion_id, alice);
                assert_eq!(since_seq, EventId::new(12));
            }
            other => panic!("expected CosmeticIdle origin, got {other:?}"),
        }
    }

    #[test]
    fn state_transition_origin_carries_from_and_to() {
        let alice = cid();
        let d = FrameDelta::for_state_transition(alice, ActivityState::Active, ActivityState::Recent);
        assert_eq!(d.kind, FrameDeltaKind::ActivityState);
        match d.origin {
            AuditOrigin::StateTransition {
                companion_id,
                from,
                to,
            } => {
                assert_eq!(companion_id, alice);
                assert_eq!(from, ActivityState::Active);
                assert_eq!(to, ActivityState::Recent);
            }
            other => panic!("expected StateTransition origin, got {other:?}"),
        }
    }

    #[test]
    fn delta_id_is_unique_across_constructions() {
        let alice = cid();
        let mut ids = std::collections::HashSet::new();
        for i in 0..50 {
            let d = FrameDelta::for_event(
                i,
                &AgentEvent::MessageStarted {
                    message_id: MessageId::new(format!("m{i}")),
                    agent_id: alice,
                },
            );
            assert!(ids.insert(d.delta_id), "duplicate delta_id at {i}");
        }
    }
}
