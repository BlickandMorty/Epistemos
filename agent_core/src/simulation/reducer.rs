//! Pure deterministic reducer (S4; DOCTRINE I-13 / IMPLEMENTATION
//! §2.1).
//!
//! Maps each `AgentEvent` onto state transitions in
//! `SimulationState` and emits the corresponding `FrameDelta`s
//! tagged with `AuditOrigin::Event` for the audit ledger
//! (DOCTRINE I-5 / S3 contract). The reducer is **pure**:
//!
//!   - No I/O.
//!   - No `Date::now()` / `Instant::now()` / random sources —
//!     the per-event deterministic origin is the
//!     `(event_seq, event_kind)` pair.
//!   - All allocations are inside the returned `Vec<FrameDelta>`;
//!     the rest is in-place mutation of `SimulationState`.
//!
//! Per-`AgentEvent` mapping follows DOCTRINE §4 (animation
//! mechanics) and §5.3 (14-state rig). The mapping table below
//! is intentionally explicit so adding a new `AgentEvent`
//! variant forces the implementer to consciously choose the
//! visual response.

use crate::audit::{AuditOrigin, EventId, FrameDelta, FrameDeltaKind};
use crate::companions::PropKind;
use crate::events::AgentEvent;
use crate::ffi::StateFlags;

use super::state::{AnimationState, SimulationState};

/// Apply one event to `state` and return the per-companion
/// `FrameDelta`s the renderer should consume. `event_seq` is
/// the persisted `LogEntry::seq` — the audit origin records it
/// so the §9.3 "Why?" query can resolve back to the event log.
pub fn reduce(
    state: &mut SimulationState,
    event: &AgentEvent,
    event_seq: u64,
) -> Vec<FrameDelta> {
    state.event_count += 1;

    // For most events the canonical FrameDelta originates from a
    // single AgentEvent; we tag every delta with the
    // (event_seq, event_kind) AuditOrigin per DOCTRINE I-5.
    let origin = || AuditOrigin::Event {
        event_id: EventId::new(event_seq),
        event_kind: event.kind().to_string(),
    };

    let mut deltas: Vec<FrameDelta> = Vec::new();

    match event {
        // --- Session lifecycle ---
        AgentEvent::SessionStarted { session_id, mode } => {
            state.open_session(session_id.clone(), *mode, event_seq);
        }
        AgentEvent::SessionCompleted { session_id, .. }
        | AgentEvent::SessionCommitted { session_id, .. } => {
            state.close_session(session_id);
        }

        // --- Participants ---
        AgentEvent::ParticipantJoined { agent_id, .. } => {
            let agent = state.ensure_agent(*agent_id);
            agent.set_state_flag(StateFlags::ACTIVE_HALO, true);
            agent.transition_to(AnimationState::Idle);
            // Bind to whichever session is currently bootstrapping
            // (if any). Multi-room theater uses this binding to
            // route deltas per §3.3.1 v1.6.
            state.bind_agent_to_current_session(*agent_id, event_seq);
            deltas.push(FrameDelta {
                delta_id: crate::audit::DeltaId::new(),
                origin: origin(),
                kind: FrameDeltaKind::AgentEntered,
            });
        }
        AgentEvent::ParticipantLeft { agent_id } => {
            if let Some(agent) = state.agent_mut(*agent_id) {
                agent.set_state_flag(StateFlags::ACTIVE_HALO, false);
            }
            state.agents.remove(agent_id);
            state.unbind_agent(*agent_id);
            deltas.push(FrameDelta {
                delta_id: crate::audit::DeltaId::new(),
                origin: origin(),
                kind: FrameDeltaKind::AgentLeft,
            });
        }

        // --- Message stream → Speak / Idle ---
        AgentEvent::MessageStarted { agent_id, .. } => {
            if let Some(agent) = state.agent_mut(*agent_id) {
                agent.transition_to(AnimationState::Speak);
                deltas.push(FrameDelta::for_event(event_seq, event));
            }
        }
        AgentEvent::MessageDelta { .. } => {
            // Frame advance only — no state transition, no
            // FrameDelta. The renderer interpolates frames
            // within the active state on its own clock.
        }
        AgentEvent::MessageCompleted { .. } => {
            // Caller (S5+) decides whether to fall back to Idle
            // or chain into another state. At S4 we leave the
            // last-known animation; explicit transition is the
            // graph theater's job.
        }

        // --- Thinking blocks (preserved per CLAUDE.md) ---
        AgentEvent::ThinkingStarted { agent_id, .. } => {
            if let Some(agent) = state.agent_mut(*agent_id) {
                agent.transition_to(AnimationState::Think);
                deltas.push(FrameDelta::for_event(event_seq, event));
            }
        }
        AgentEvent::ThinkingDelta { .. } | AgentEvent::ThinkingCompleted { .. } => {}

        // --- Tool calls → Tool state + held prop ---
        AgentEvent::ToolCallStarted {
            agent_id,
            tool_name,
            ..
        } => {
            if let Some(agent) = state.agent_mut(*agent_id) {
                agent.transition_to(AnimationState::Tool);
                agent.held_prop = Some(prop_for_tool(tool_name));
                deltas.push(FrameDelta {
                    delta_id: crate::audit::DeltaId::new(),
                    origin: origin(),
                    kind: FrameDeltaKind::AgentProp,
                });
                deltas.push(FrameDelta {
                    delta_id: crate::audit::DeltaId::new(),
                    origin: origin(),
                    kind: FrameDeltaKind::AgentAnimation,
                });
            }
        }
        AgentEvent::ToolCallCompleted { tool_call_id, .. }
        | AgentEvent::ToolCallFailed { tool_call_id, .. } => {
            let _ = tool_call_id;
            // S4 doesn't yet thread tool_call_id back to the
            // owning agent — S5+ adds the lookup table. For now
            // the agent state stays in Tool until a new event
            // transitions it.
        }
        AgentEvent::ToolCallDelta { .. } => {}

        // --- Memory + graph access ---
        AgentEvent::MemoryRetrieved { agent_id, .. } => {
            if let Some(agent) = state.agent_mut(*agent_id) {
                agent.transition_to(AnimationState::Retrieve);
                deltas.push(FrameDelta {
                    delta_id: crate::audit::DeltaId::new(),
                    origin: origin(),
                    kind: FrameDeltaKind::GraphPulse,
                });
                deltas.push(FrameDelta::for_event(event_seq, event));
            }
        }
        AgentEvent::GraphTraverseStarted { .. }
        | AgentEvent::GraphTraverseCompleted { .. }
        | AgentEvent::GraphNodeAccessed { .. }
        | AgentEvent::GraphNodeCreated { .. }
        | AgentEvent::GraphEdgeCreated { .. } => {
            deltas.push(FrameDelta {
                delta_id: crate::audit::DeltaId::new(),
                origin: origin(),
                kind: FrameDeltaKind::GraphPulse,
            });
        }

        // --- Approval gate ---
        AgentEvent::AwaitingApproval { agent_id, .. } => {
            if let Some(agent) = state.agent_mut(*agent_id) {
                agent.transition_to(AnimationState::Gate);
                agent.set_state_flag(StateFlags::GATE, true);
                deltas.push(FrameDelta {
                    delta_id: crate::audit::DeltaId::new(),
                    origin: origin(),
                    kind: FrameDeltaKind::ApprovalGate,
                });
            }
        }
        AgentEvent::ApprovalGranted { agent_id, .. }
        | AgentEvent::ApprovalDenied { agent_id, .. } => {
            if let Some(agent) = state.agent_mut(*agent_id) {
                agent.set_state_flag(StateFlags::GATE, false);
                agent.transition_to(AnimationState::Idle);
                deltas.push(FrameDelta {
                    delta_id: crate::audit::DeltaId::new(),
                    origin: origin(),
                    kind: FrameDeltaKind::ApprovalGate,
                });
            }
        }

        // --- Subagent lifecycle ---
        AgentEvent::SubagentSpawned {
            parent_id,
            child_id,
            count,
        } => {
            // Parent glow + N child entrance per DOCTRINE §4.5.
            if let Some(parent) = state.agent_mut(*parent_id) {
                parent.transition_to(AnimationState::Spawn);
            }
            deltas.push(FrameDelta {
                delta_id: crate::audit::DeltaId::new(),
                origin: origin(),
                kind: FrameDeltaKind::SubagentSpawn,
            });
            // S4 emits ONE entrance per call regardless of
            // `count`; S5+ will fan out to N children.
            let _ = count;
            state.ensure_agent(*child_id);
            // Subagents inherit their parent's session binding
            // — keeps the room cardinality at "one session = one
            // room" per §3.3.1 v1.6 (a Kimi-with-3-subagents is
            // 1 chip / 1 room with 4 companions, not 4 rooms).
            state.bind_child_to_parent_session(*parent_id, *child_id, event_seq);
            deltas.push(FrameDelta {
                delta_id: crate::audit::DeltaId::new(),
                origin: origin(),
                kind: FrameDeltaKind::AgentEntered,
            });
        }
        AgentEvent::SubagentCompleted { child_id, .. } => {
            state.agents.remove(child_id);
            state.unbind_agent(*child_id);
            deltas.push(FrameDelta {
                delta_id: crate::audit::DeltaId::new(),
                origin: origin(),
                kind: FrameDeltaKind::SubagentDespawn,
            });
        }

        // --- Handoffs ---
        AgentEvent::HandoffStarted { from_id, to_id, .. } => {
            if let Some(from) = state.agent_mut(*from_id) {
                from.transition_to(AnimationState::HandoffGive);
            }
            // The scroll travel is its own delta kind so the
            // renderer can position it between sender + receiver.
            deltas.push(FrameDelta {
                delta_id: crate::audit::DeltaId::new(),
                origin: origin(),
                kind: FrameDeltaKind::HandoffScroll,
            });
            // Receiver hasn't reacted yet at HandoffStarted —
            // they react on HandoffCompleted.
            let _ = to_id;
        }
        AgentEvent::HandoffCompleted { to_id, .. } => {
            if let Some(to) = state.agent_mut(*to_id) {
                to.transition_to(AnimationState::HandoffReceive);
            }
            deltas.push(FrameDelta {
                delta_id: crate::audit::DeltaId::new(),
                origin: origin(),
                kind: FrameDeltaKind::HandoffScroll,
            });
        }

        // --- Errors + recovery ---
        AgentEvent::Error { agent_id, .. } => {
            if let Some(agent) = state.agent_mut(*agent_id) {
                agent.transition_to(AnimationState::Error);
                agent.set_state_flag(StateFlags::ERROR, true);
                deltas.push(FrameDelta::for_event(event_seq, event));
            }
        }
        AgentEvent::RecoveryStarted { agent_id, .. } => {
            if let Some(agent) = state.agent_mut(*agent_id) {
                agent.transition_to(AnimationState::Recover);
                agent.set_state_flag(StateFlags::RECOVERY, true);
                deltas.push(FrameDelta::for_event(event_seq, event));
            }
        }
        AgentEvent::RecoveryCompleted {
            agent_id, success, ..
        } => {
            if let Some(agent) = state.agent_mut(*agent_id) {
                agent.set_state_flag(StateFlags::RECOVERY, false);
                agent.set_state_flag(StateFlags::ERROR, false);
                agent.transition_to(if *success {
                    AnimationState::Success
                } else {
                    AnimationState::Idle
                });
                deltas.push(FrameDelta::for_event(event_seq, event));
            }
        }

        // --- Companion lifecycle (registry-driven) ---
        AgentEvent::CompanionRegistered { companion_id, .. } => {
            state.ensure_agent(*companion_id);
            deltas.push(FrameDelta {
                delta_id: crate::audit::DeltaId::new(),
                origin: origin(),
                kind: FrameDeltaKind::AgentEntered,
            });
        }
        AgentEvent::CompanionUpdated { companion_id, .. } => {
            // S4 doesn't yet apply ConfigDiff to AgentVisualState
            // — S6/S8 wires that. We still emit a delta so the
            // audit ledger records the link.
            let _ = companion_id;
            deltas.push(FrameDelta::for_event(event_seq, event));
        }
        AgentEvent::CompanionArchived { companion_id } => {
            state.agents.remove(companion_id);
            state.unbind_agent(*companion_id);
            deltas.push(FrameDelta {
                delta_id: crate::audit::DeltaId::new(),
                origin: origin(),
                kind: FrameDeltaKind::AgentLeft,
            });
        }
        AgentEvent::CompanionActivityStateChanged { .. } => {
            // Activity tracker drives `state_transition` deltas
            // outside the reducer — see `ActivityTracker::tick`
            // in `crate::companions::activity`. The reducer
            // consumes the AgentEvent so the audit ledger has
            // the linkage; the delta_kind on FrameDelta::for_event
            // already marks ActivityState.
            deltas.push(FrameDelta::for_event(event_seq, event));
        }

        // --- Artifacts, tasks, gift boxes (S6/S8/S11) ---
        AgentEvent::ArtifactCreated { .. }
        | AgentEvent::TaskCreated { .. }
        | AgentEvent::TaskCompleted { .. }
        | AgentEvent::GiftBoxReceived { .. }
        | AgentEvent::GiftBoxUnwrapped { .. }
        | AgentEvent::WorkspaceFocused { .. } => {
            // S4 records the event in the audit ledger but
            // emits no visual delta. The owning slices wire
            // visuals later.
            deltas.push(FrameDelta::for_event(event_seq, event));
        }
    }

    // Bump the session's `last_event_seq` for any agent-scoped
    // event so the chip-row "working-state pulse" gate stays
    // current per DOCTRINE §3.3.1 v1.6 (≤ 30 s threshold).
    if let Some(agent_id) = event.primary_agent_id() {
        state.touch_session_for_agent(agent_id, event_seq);
    }

    deltas
}

/// Map a tool name to its prop kind (DOCTRINE §5.5 Category A).
/// Stable mapping — change-resistant against tool registry
/// reshuffles since matching is by prefix / substring.
fn prop_for_tool(tool_name: &str) -> PropKind {
    let lower = tool_name.to_ascii_lowercase();
    if lower.starts_with("code_")
        || lower == "git"
        || lower.contains("test")
        || lower.contains("build")
    {
        PropKind::Wrench
    } else if lower.contains("note") || lower.contains("doc") {
        PropKind::Scroll
    } else if lower.contains("search") || lower.contains("find") {
        PropKind::Magnifier
    } else if lower.starts_with("vault") || lower.contains("file") {
        PropKind::Folder
    } else if lower == "delegate"
        || lower.starts_with("route")
        || lower.contains("router")
    {
        PropKind::Baton
    } else {
        // Default for unknown tools — Lantern (deep-think /
        // generic).
        PropKind::Lantern
    }
}

/// Helper used by tests + by the Simulation bridge to advance
/// the `current_frame` cosmetic counter. Lives outside `reduce`
/// because it's driven by a wall-clock ambient timer, not by
/// AgentEvents — the corresponding deltas use AuditOrigin::CosmeticIdle.
#[allow(dead_code)]
pub(crate) fn cosmetic_frame_tick(state: &mut SimulationState) {
    for agent in state.agents.values_mut() {
        if agent.current_animation.loops() {
            agent.current_frame =
                (agent.current_frame + 1) % agent.current_animation.frame_count();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::companions::{ActivityState, ProviderRole};
    use crate::events::{
        ArtifactRef, ArtifactKind, ArtifactId, MessageId, NodeId, NodeKind, SessionId,
        SessionMode, ToolCallId,
    };

    fn cid() -> crate::companions::CompanionId {
        crate::companions::CompanionId::new_ulid()
    }

    #[test]
    fn participant_joined_inserts_agent_and_emits_entered() {
        let mut s = SimulationState::initial();
        let alice = cid();
        let deltas = reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::CodeWorker,
            },
            1,
        );
        assert_eq!(deltas.len(), 1);
        assert_eq!(deltas[0].kind, FrameDeltaKind::AgentEntered);
        assert!(s.agent(alice).is_some());
        let agent = s.agent(alice).unwrap();
        let f: StateFlags = agent.state_flags.into();
        assert!(f.contains(StateFlags::ACTIVE_HALO));
    }

    #[test]
    fn message_started_transitions_to_speak() {
        let mut s = SimulationState::initial();
        let alice = cid();
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::CodeWorker,
            },
            1,
        );
        let deltas = reduce(
            &mut s,
            &AgentEvent::MessageStarted {
                message_id: MessageId::new("m"),
                agent_id: alice,
            },
            2,
        );
        assert_eq!(deltas.len(), 1);
        assert_eq!(s.agent(alice).unwrap().current_animation, AnimationState::Speak);
    }

    #[test]
    fn tool_call_started_sets_held_prop_per_tool_name() {
        let mut s = SimulationState::initial();
        let alice = cid();
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::CodeWorker,
            },
            1,
        );
        let cases = [
            ("code_edit", PropKind::Wrench),
            ("git", PropKind::Wrench),
            ("graph.search_semantic", PropKind::Magnifier),
            ("vault_read", PropKind::Folder),
            ("delegate", PropKind::Baton),
            ("note_create", PropKind::Scroll),
            ("totally_unknown_tool", PropKind::Lantern),
        ];
        for (i, (name, expected)) in cases.iter().enumerate() {
            reduce(
                &mut s,
                &AgentEvent::ToolCallStarted {
                    tool_call_id: ToolCallId::new(format!("t{i}")),
                    agent_id: alice,
                    tool_name: name.to_string(),
                    input_hash: crate::events::Blake3Hash::of(b""),
                },
                10 + i as u64,
            );
            assert_eq!(
                s.agent(alice).unwrap().held_prop,
                Some(*expected),
                "tool {name} should map to {:?}",
                expected
            );
        }
    }

    #[test]
    fn awaiting_approval_transitions_to_gate_and_sets_flag() {
        let mut s = SimulationState::initial();
        let alice = cid();
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::CodeWorker,
            },
            1,
        );
        reduce(
            &mut s,
            &AgentEvent::AwaitingApproval {
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
            2,
        );
        let agent = s.agent(alice).unwrap();
        assert_eq!(agent.current_animation, AnimationState::Gate);
        let f: StateFlags = agent.state_flags.into();
        assert!(f.contains(StateFlags::GATE));
    }

    #[test]
    fn approval_granted_clears_gate_flag() {
        let mut s = SimulationState::initial();
        let alice = cid();
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::CodeWorker,
            },
            1,
        );
        reduce(
            &mut s,
            &AgentEvent::AwaitingApproval {
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
            2,
        );
        reduce(
            &mut s,
            &AgentEvent::ApprovalGranted {
                agent_id: alice,
                action_id: crate::events::ActionId::new("a"),
            },
            3,
        );
        let agent = s.agent(alice).unwrap();
        let f: StateFlags = agent.state_flags.into();
        assert!(!f.contains(StateFlags::GATE));
        assert_eq!(agent.current_animation, AnimationState::Idle);
    }

    #[test]
    fn participant_left_removes_agent() {
        let mut s = SimulationState::initial();
        let alice = cid();
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::CodeWorker,
            },
            1,
        );
        reduce(&mut s, &AgentEvent::ParticipantLeft { agent_id: alice }, 2);
        assert!(s.agent(alice).is_none());
    }

    #[test]
    fn subagent_spawned_inserts_child_and_transitions_parent() {
        let mut s = SimulationState::initial();
        let alice = cid();
        let bob = cid();
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::Orchestrator,
            },
            1,
        );
        let deltas = reduce(
            &mut s,
            &AgentEvent::SubagentSpawned {
                parent_id: alice,
                child_id: bob,
                count: 1,
            },
            2,
        );
        assert!(s.agent(bob).is_some());
        assert_eq!(s.agent(alice).unwrap().current_animation, AnimationState::Spawn);
        // Two deltas: SubagentSpawn + AgentEntered for child.
        assert_eq!(deltas.len(), 2);
        assert!(deltas
            .iter()
            .any(|d| d.kind == FrameDeltaKind::SubagentSpawn));
        assert!(deltas
            .iter()
            .any(|d| d.kind == FrameDeltaKind::AgentEntered));
    }

    #[test]
    fn handoff_started_transitions_source_only() {
        let mut s = SimulationState::initial();
        let alice = cid();
        let bob = cid();
        for id in [alice, bob] {
            reduce(
                &mut s,
                &AgentEvent::ParticipantJoined {
                    agent_id: id,
                    role: ProviderRole::Worker,
                },
                1,
            );
        }
        reduce(
            &mut s,
            &AgentEvent::HandoffStarted {
                from_id: alice,
                to_id: bob,
                payload_id: ArtifactRef {
                    id: ArtifactId::new("a"),
                    kind: ArtifactKind::Document,
                },
            },
            10,
        );
        assert_eq!(
            s.agent(alice).unwrap().current_animation,
            AnimationState::HandoffGive
        );
        // Bob hasn't transitioned yet — handoff in flight.
        assert_eq!(s.agent(bob).unwrap().current_animation, AnimationState::Idle);
    }

    #[test]
    fn graph_node_created_emits_pulse() {
        let mut s = SimulationState::initial();
        let alice = cid();
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::Faculty,
            },
            1,
        );
        let deltas = reduce(
            &mut s,
            &AgentEvent::GraphNodeCreated {
                agent_id: alice,
                node_id: NodeId::new("n1"),
                kind: NodeKind::Note,
            },
            2,
        );
        assert!(deltas
            .iter()
            .any(|d| d.kind == FrameDeltaKind::GraphPulse));
    }

    #[test]
    fn error_event_sets_error_flag_and_transitions() {
        let mut s = SimulationState::initial();
        let alice = cid();
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::Worker,
            },
            1,
        );
        reduce(
            &mut s,
            &AgentEvent::Error {
                agent_id: alice,
                code: "E1".to_string(),
                message: "oops".to_string(),
            },
            2,
        );
        let agent = s.agent(alice).unwrap();
        assert_eq!(agent.current_animation, AnimationState::Error);
        let f: StateFlags = agent.state_flags.into();
        assert!(f.contains(StateFlags::ERROR));
    }

    #[test]
    fn every_emitted_frame_delta_carries_event_origin() {
        // S3 contract: every FrameDelta the reducer emits has a
        // non-null AuditOrigin matching its triggering event_seq.
        let mut s = SimulationState::initial();
        let alice = cid();
        let stream = vec![
            (
                AgentEvent::ParticipantJoined {
                    agent_id: alice,
                    role: ProviderRole::Worker,
                },
                1u64,
            ),
            (
                AgentEvent::MessageStarted {
                    message_id: MessageId::new("m"),
                    agent_id: alice,
                },
                2,
            ),
            (
                AgentEvent::SubagentSpawned {
                    parent_id: alice,
                    child_id: cid(),
                    count: 1,
                },
                3,
            ),
        ];
        for (event, seq) in &stream {
            for delta in reduce(&mut s, event, *seq) {
                match delta.origin {
                    AuditOrigin::Event {
                        event_id,
                        ref event_kind,
                    } => {
                        assert_eq!(event_id.seq(), *seq);
                        assert_eq!(event_kind, event.kind());
                    }
                    other => panic!("expected Event origin, got {other:?}"),
                }
            }
        }
    }

    #[test]
    fn cosmetic_frame_tick_advances_loops_only() {
        let mut s = SimulationState::initial();
        let alice = cid();
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::Worker,
            },
            1,
        );
        // Idle is a looped state — frame should advance.
        cosmetic_frame_tick(&mut s);
        assert_eq!(s.agent(alice).unwrap().current_frame, 1);
        // Spawn isn't looped — frame should NOT advance.
        s.agent_mut(alice).unwrap().transition_to(AnimationState::Spawn);
        cosmetic_frame_tick(&mut s);
        assert_eq!(s.agent(alice).unwrap().current_frame, 0);
    }

    #[test]
    fn session_lifecycle_tracks_active_set() {
        let mut s = SimulationState::initial();
        let session = SessionId::new("s1");
        reduce(
            &mut s,
            &AgentEvent::SessionStarted {
                session_id: session.clone(),
                mode: SessionMode::Chat,
            },
            1,
        );
        assert!(s.active_sessions.contains(&session));
        // Multi-room theater (§3.3.1 v1.6): session_meta entry
        // exists while the session is open.
        assert!(s.session_meta.contains_key(&session));
        reduce(
            &mut s,
            &AgentEvent::SessionCompleted {
                session_id: session.clone(),
                summary: None,
            },
            2,
        );
        assert!(!s.active_sessions.contains(&session));
        assert!(!s.session_meta.contains_key(&session));
    }

    #[test]
    fn participant_joined_inside_session_binds_to_room() {
        // §3.3.1 v1.6: ParticipantJoined fired while a session
        // is bootstrapping should bind the agent to that
        // session — the chip row needs the binding to render
        // members and pick a lead mascot.
        let mut s = SimulationState::initial();
        let session = SessionId::new("s1");
        let alice = cid();
        reduce(
            &mut s,
            &AgentEvent::SessionStarted {
                session_id: session.clone(),
                mode: SessionMode::Chat,
            },
            1,
        );
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::Worker,
            },
            2,
        );
        assert_eq!(s.session_of(alice), Some(&session));
        let meta = s.session_meta.get(&session).unwrap();
        assert_eq!(meta.lead_agent, Some(alice));
        assert!(meta.members.contains(&alice));
    }

    #[test]
    fn participant_joined_without_open_session_skips_binding() {
        // Bootstrapping agents BEFORE SessionStarted (e.g. test
        // harness path that only injects participants) leaves
        // them unbound. They simply don't appear in any room.
        let mut s = SimulationState::initial();
        let alice = cid();
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::Worker,
            },
            1,
        );
        assert!(s.session_of(alice).is_none());
        assert!(s.rooms().is_empty());
    }

    #[test]
    fn subagents_inherit_parent_session_one_chip_per_session() {
        // §3.3.1 v1.6 cardinality: a Kimi-with-3-subagents is
        // 1 chip / 1 room with 4 members.
        let mut s = SimulationState::initial();
        let session = SessionId::new("kimi");
        let parent = cid();
        let c1 = cid();
        let c2 = cid();
        let c3 = cid();
        reduce(
            &mut s,
            &AgentEvent::SessionStarted {
                session_id: session.clone(),
                mode: SessionMode::Chat,
            },
            1,
        );
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: parent,
                role: ProviderRole::Orchestrator,
            },
            2,
        );
        for (i, child) in [c1, c2, c3].into_iter().enumerate() {
            reduce(
                &mut s,
                &AgentEvent::SubagentSpawned {
                    parent_id: parent,
                    child_id: child,
                    count: 1,
                },
                3 + i as u64,
            );
        }
        assert_eq!(s.rooms().len(), 1);
        let meta = s.rooms()[0];
        assert_eq!(meta.members.len(), 4);
        for id in [parent, c1, c2, c3] {
            assert_eq!(s.session_of(id), Some(&session));
        }
        // Lead agent is still the original parent — children
        // never replace the lead mascot.
        assert_eq!(meta.lead_agent, Some(parent));
    }

    #[test]
    fn parallel_sessions_are_separate_rooms() {
        // The user's vision: "1 Kimi-with-3-subagents +
        // 1 Claude Code session = 2 rooms". Verifies each
        // session bootstraps its own chip / room.
        let mut s = SimulationState::initial();
        let kimi = SessionId::new("kimi");
        let claude = SessionId::new("claude");
        let kimi_lead = cid();
        let kimi_child = cid();
        let claude_lead = cid();

        // Open Kimi session and join its lead.
        reduce(
            &mut s,
            &AgentEvent::SessionStarted {
                session_id: kimi.clone(),
                mode: SessionMode::Chat,
            },
            1,
        );
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: kimi_lead,
                role: ProviderRole::Orchestrator,
            },
            2,
        );
        reduce(
            &mut s,
            &AgentEvent::SubagentSpawned {
                parent_id: kimi_lead,
                child_id: kimi_child,
                count: 1,
            },
            3,
        );

        // Open Claude session and join its lead.
        reduce(
            &mut s,
            &AgentEvent::SessionStarted {
                session_id: claude.clone(),
                mode: SessionMode::Chat,
            },
            4,
        );
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: claude_lead,
                role: ProviderRole::Worker,
            },
            5,
        );

        let rooms = s.rooms();
        assert_eq!(rooms.len(), 2);
        // Order is by `started_seq` — Kimi (seq 1) then Claude
        // (seq 4).
        assert_eq!(rooms[0].session_id, kimi);
        assert_eq!(rooms[0].members.len(), 2);
        assert_eq!(rooms[1].session_id, claude);
        assert_eq!(rooms[1].members.len(), 1);
        // Sanity: a delta from kimi_child routes to the Kimi
        // session, not Claude.
        assert_eq!(s.session_of(kimi_child), Some(&kimi));
        assert_eq!(s.session_of(claude_lead), Some(&claude));
    }

    #[test]
    fn session_completed_drops_all_member_bindings() {
        let mut s = SimulationState::initial();
        let session = SessionId::new("s1");
        let alice = cid();
        reduce(
            &mut s,
            &AgentEvent::SessionStarted {
                session_id: session.clone(),
                mode: SessionMode::Chat,
            },
            1,
        );
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::Worker,
            },
            2,
        );
        assert!(s.session_of(alice).is_some());
        reduce(
            &mut s,
            &AgentEvent::SessionCompleted {
                session_id: session.clone(),
                summary: None,
            },
            3,
        );
        assert!(s.session_of(alice).is_none());
        assert!(s.rooms().is_empty());
    }

    #[test]
    fn touch_advances_last_event_seq_for_room_pulse() {
        // §3.3.1 v1.6: chip-row "working-state pulse" reads
        // `meta.last_event_seq` to decide if any event for this
        // session fired in the last 30 s. Per-event activity
        // should advance the watermark.
        let mut s = SimulationState::initial();
        let session = SessionId::new("s1");
        let alice = cid();
        reduce(
            &mut s,
            &AgentEvent::SessionStarted {
                session_id: session.clone(),
                mode: SessionMode::Chat,
            },
            1,
        );
        reduce(
            &mut s,
            &AgentEvent::ParticipantJoined {
                agent_id: alice,
                role: ProviderRole::Worker,
            },
            2,
        );
        let early = s.session_meta.get(&session).unwrap().last_event_seq;
        reduce(
            &mut s,
            &AgentEvent::MessageStarted {
                message_id: MessageId::new("m"),
                agent_id: alice,
            },
            10,
        );
        let late = s.session_meta.get(&session).unwrap().last_event_seq;
        assert!(late > early, "MessageStarted should bump last_event_seq");
        assert_eq!(late, 10);
    }

    #[test]
    fn activity_state_changed_produces_delta() {
        let mut s = SimulationState::initial();
        let alice = cid();
        let deltas = reduce(
            &mut s,
            &AgentEvent::CompanionActivityStateChanged {
                companion_id: alice,
                from: ActivityState::Active,
                to: ActivityState::Recent,
            },
            1,
        );
        assert_eq!(deltas.len(), 1);
        assert_eq!(deltas[0].kind, FrameDeltaKind::ActivityState);
    }
}
