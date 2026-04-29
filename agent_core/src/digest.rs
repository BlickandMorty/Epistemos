//! `SimulationDigest` — minimal counter-style projection of an
//! event stream, used by `crate::replay` for byte-stable
//! integrity checks (S2 acceptance, DOCTRINE I-13).
//!
//! Distinct from `crate::simulation::state::SimulationState`,
//! which is the per-companion FSM the real reducer mutates and
//! that produces frame deltas. The digest exists only to give
//! `replay()` something deterministic to fold over so two runs
//! over the same event log produce byte-identical output —
//! useful for verifying the event log's integrity properties
//! without spinning up the full reducer + ring buffer.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

use crate::companions::CompanionId;
use crate::events::{AgentEvent, Blake3Hash};

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct SimulationDigest {
    pub agents_present: BTreeSet<CompanionId>,
    pub event_count: u64,
    pub message_count: u64,
    pub tool_call_count: u64,
    pub error_count: u64,
    pub graph_mutations: u64,
}

impl SimulationDigest {
    pub fn initial() -> Self {
        Self::default()
    }

    /// Apply one event to the digest. Pure — no I/O, no system
    /// clock. Per I-13 all randomness/time inputs come from the
    /// event itself; this projection touches only counters and
    /// agent presence so byte-stable ordering is automatic
    /// (`BTreeSet` iterates in key order, `serde_json::to_vec` is
    /// deterministic for these shapes).
    pub fn apply(&mut self, event: &AgentEvent) {
        self.event_count += 1;
        match event {
            AgentEvent::ParticipantJoined { agent_id, .. } => {
                self.agents_present.insert(*agent_id);
            }
            AgentEvent::ParticipantLeft { agent_id } => {
                self.agents_present.remove(agent_id);
            }
            AgentEvent::MessageStarted { .. } => {
                self.message_count += 1;
            }
            AgentEvent::ToolCallStarted { .. } => {
                self.tool_call_count += 1;
            }
            AgentEvent::Error { .. } => {
                self.error_count += 1;
            }
            AgentEvent::GraphNodeCreated { .. } | AgentEvent::GraphEdgeCreated { .. } => {
                self.graph_mutations += 1;
            }
            _ => {}
        }
    }

    pub fn hash(&self) -> Blake3Hash {
        let bytes =
            serde_json::to_vec(self).expect("SimulationDigest always serialisable");
        Blake3Hash::of(&bytes)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::companions::ProviderRole;
    use crate::events::{Blake3Hash, MessageId, ToolCallId};

    fn cid(label: &str) -> CompanionId {
        use std::hash::{DefaultHasher, Hash, Hasher};
        let mut h = DefaultHasher::new();
        label.hash(&mut h);
        CompanionId(ulid::Ulid::from_parts(0, h.finish() as u128))
    }

    #[test]
    fn apply_counts_event_categories() {
        let mut d = SimulationDigest::initial();
        let alice = cid("alice");
        d.apply(&AgentEvent::ParticipantJoined {
            agent_id: alice,
            role: ProviderRole::CodeWorker,
        });
        d.apply(&AgentEvent::MessageStarted {
            message_id: MessageId::new("m1"),
            agent_id: alice,
        });
        d.apply(&AgentEvent::ToolCallStarted {
            tool_call_id: ToolCallId::new("t1"),
            agent_id: alice,
            tool_name: "code_edit".to_string(),
            input_hash: Blake3Hash::of(b""),
        });
        d.apply(&AgentEvent::Error {
            agent_id: alice,
            code: "E1".to_string(),
            message: "bad".to_string(),
        });
        assert_eq!(d.event_count, 4);
        assert_eq!(d.message_count, 1);
        assert_eq!(d.tool_call_count, 1);
        assert_eq!(d.error_count, 1);
        assert!(d.agents_present.contains(&alice));
    }

    #[test]
    fn hash_is_deterministic() {
        let alice = cid("alice");
        let mut a = SimulationDigest::initial();
        let mut b = SimulationDigest::initial();
        for _ in 0..3 {
            a.apply(&AgentEvent::MessageStarted {
                message_id: MessageId::new("m"),
                agent_id: alice,
            });
            b.apply(&AgentEvent::MessageStarted {
                message_id: MessageId::new("m"),
                agent_id: alice,
            });
        }
        assert_eq!(a.hash(), b.hash());
    }
}
