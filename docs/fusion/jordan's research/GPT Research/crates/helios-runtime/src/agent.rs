//! Agent trait and core agent implementations.

use helios_core::ResonanceSignature;

pub type AgentId = u64;

#[derive(Clone, Debug, PartialEq)]
pub struct AgentTask {
    pub task_id: u64,
    pub prompt: String,
    pub signature: ResonanceSignature,
}

#[derive(Clone, Debug, PartialEq)]
pub struct AgentResult {
    pub task_id: u64,
    pub text: String,
    pub signature: ResonanceSignature,
}

#[derive(Clone, Debug, PartialEq)]
pub enum AgentEvent {
    Started { agent_id: AgentId, task_id: u64 },
    Completed { agent_id: AgentId, task_id: u64 },
    Failed { agent_id: AgentId, task_id: u64, reason: String },
    SteerRequested { agent_id: AgentId, feature: String },
    SummaryStarted { task_id: u64 },
    SummaryDelta { task_id: u64, bytes: usize },
    SummaryCompleted { task_id: u64 },
    VaultCreated { vault_id: u64 },
    VaultArchived { vault_id: u64 },
}

pub trait Agent {
    fn id(&self) -> AgentId;
    fn name(&self) -> &str;
    fn handle(&self, task: &AgentTask) -> AgentResult;
}

#[derive(Clone, Debug, PartialEq)]
pub struct CoreAgent {
    pub id: AgentId,
    pub name: String,
}

impl Agent for CoreAgent {
    fn id(&self) -> AgentId { self.id }
    fn name(&self) -> &str { &self.name }
    fn handle(&self, task: &AgentTask) -> AgentResult {
        AgentResult { task_id: task.task_id, text: format!("{} handled: {}", self.name, task.prompt), signature: task.signature }
    }
}
