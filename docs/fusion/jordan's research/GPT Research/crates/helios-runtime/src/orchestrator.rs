//! Task routing and budget enforcement.

use crate::agent::{Agent, AgentResult, AgentTask};
use crate::gate::RuntimeGate;
use helios_core::GateDecision;

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Budget {
    pub max_tokens: u32,
    pub max_wall_ms: u64,
    pub max_cloud_calls: u32,
}

impl Default for Budget {
    fn default() -> Self { Self { max_tokens: 4096, max_wall_ms: 30_000, max_cloud_calls: 0 } }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Orchestrator {
    pub budget: Budget,
    pub gate: RuntimeGate,
}

impl Default for Orchestrator {
    fn default() -> Self { Self { budget: Budget::default(), gate: RuntimeGate::default() } }
}

impl Orchestrator {
    pub fn dispatch<A: Agent>(&self, agent: &A, task: &AgentTask) -> Result<AgentResult, GateDecision> {
        match self.gate.verify(task.signature) {
            GateDecision::AcceptLocal => Ok(agent.handle(task)),
            decision => Err(decision),
        }
    }
}
