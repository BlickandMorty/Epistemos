//! Multi-agent orchestrator — spawn, route, and manage agent swarms.
//!
//! The `Orchestrator` is the central nervous system of the Epistenos
//! runtime. It maintains a registry of agents, routes messages to the
//! best-matching agent via the Resonance Gate, and spawns new agents
//! from Markdown frontmatter definitions.
//!
//! ## Architecture
//!
//! ```text
//! ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
//! │   Message    │────▶│ Orchestrator │────▶│   Resonance  │
//! │     Bus      │     │              │     │     Gate     │
//! └──────────────┘     └──────────────┘     └──────────────┘
//!                             │
//!                             ▼
//!                      ┌──────────────┐
//!                      │   Agent A    │
//!                      │   Agent B    │
//!                      │   Agent C    │
//!                      └──────────────┘
//! ```
//!
//! Messages arrive on an async `mpsc` channel. The orchestrator evaluates
//! each message against every agent's resonance profile and routes to the
//! highest-scoring match.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use thiserror::Error;
use tokio::sync::mpsc;
use tracing::{debug, error, info, instrument, warn};
use hex;

use crate::agent::{AuthToken, VaultPermissions};
use crate::gate::{Claim, Context, ResonanceGate, Residency};
use crate::scope_rex::ScopeRexState;
use crate::types::AgentId;

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

#[derive(Error, Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum OrchestratorError {
    #[error("agent not found: {0}")]
    AgentNotFound(AgentId),

    #[error("spawn failed: {0}")]
    SpawnFailed(String),

    #[error("invalid agent definition: {0}")]
    InvalidDefinition(String),

    #[error("no route found for message: {msg_id}")]
    NoRoute { msg_id: String },

    #[error("resonance computation failed: {0}")]
    ResonanceFailed(String),

    #[error("send error: {0}")]
    SendError(String),
}

// ---------------------------------------------------------------------------
// AgentMessage — inter-agent communication envelope
// ---------------------------------------------------------------------------

/// A message sent between agents or from the user to an agent.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AgentMessage {
    /// Unique message identifier (Blake3 hash).
    pub id: [u8; 32],
    /// Sender agent ID (or system/user).
    pub from: Option<AgentId>,
    /// Target agent ID (None = route dynamically).
    pub to: Option<AgentId>,
    /// Message kind.
    pub kind: MessageKind,
    /// Message payload.
    pub payload: String,
    /// Timestamp.
    pub timestamp: chrono::DateTime<chrono::Utc>,
    /// Optional auth token for vault operations.
    pub auth_token: Option<AuthToken>,
}

/// Kinds of inter-agent messages.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MessageKind {
    /// User query or command.
    UserQuery,
    /// Agent-to-agent request.
    AgentRequest,
    /// Agent-to-agent response.
    AgentResponse,
    /// Tool result delivery.
    ToolResult,
    /// Resonance gate decision notification.
    GateDecision,
    /// Lifecycle event (spawn, terminate, heartbeat).
    Lifecycle,
}

// ---------------------------------------------------------------------------
// Agent — an orchestrated agent instance
// ---------------------------------------------------------------------------

/// A live agent in the orchestrator's registry.
///
/// Each agent combines a `ResonanceGate` (for epistemic evaluation),
/// a `ScopeRexState` (for cognitive state), and `VaultPermissions`
/// (for security boundaries).
#[derive(Clone, Debug)]
pub struct Agent {
    pub id: AgentId,
    pub role: String,
    pub resonance: ResonanceGate,
    pub scope: ScopeRexState,
    pub vault_access: VaultPermissions,
    /// Sender handle for delivering messages to this agent.
    pub mailbox: Option<mpsc::UnboundedSender<AgentMessage>>,
}

impl Agent {
    /// Compute the resonance score of this agent for a given message.
    ///
    /// Returns the composite scalar from the Resonance Signature.
    pub fn resonance_score(&mut self, message: &AgentMessage) -> f32 {
        // Construct a claim from the message
        let mut claim_id = [0u8; 32];
        claim_id.copy_from_slice(&message.id[..32]);
        let claim = Claim {
            id: claim_id,
            proposition: message.payload.clone(),
            confidence: 0.8,
            evidence_count: 1,
            is_observed: true,
            source_residency: Residency::L2,
        };
        let context = Context {
            active_claims: vec![],
            feature_vector: vec![0.5; 64], // simplified feature vector
            current_residency: Residency::L2,
            learning_mode: crate::gate::LearningMode::Sgd,
        };
        let (sig, _action) = self.resonance.evaluate(&claim, &context);
        sig.composite_scalar()
    }
}

// ---------------------------------------------------------------------------
// AgentDef — parsed from Markdown frontmatter
// ---------------------------------------------------------------------------

/// An agent definition parsed from Markdown YAML frontmatter.
///
/// Expected format:
/// ```markdown
/// ---
/// agent_id: planner-alpha
/// role: strategic_planner
/// resonance_threshold: 0.85
/// vault_paths: ["/vault/plans"]
/// tools: [reason.plan, vault.search]
/// ---
/// ```
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AgentDef {
    pub agent_id: String,
    pub role: String,
    #[serde(default = "default_resonance_threshold")]
    pub resonance_threshold: f32,
    #[serde(default)]
    pub vault_paths: Vec<String>,
    #[serde(default)]
    pub tools: Vec<String>,
}

fn default_resonance_threshold() -> f32 {
    0.75
}

impl AgentDef {
    /// Parse an `AgentDef` from a Markdown string with YAML frontmatter.
    pub fn from_markdown(md: &str) -> Result<Self, OrchestratorError> {
        let parts: Vec<&str> = md.splitn(3, "---").collect();
        if parts.len() < 3 {
            return Err(OrchestratorError::InvalidDefinition(
                "missing frontmatter delimiters".into(),
            ));
        }
        let yaml_str = parts[1].trim();
        let def: AgentDef = serde_yaml::from_str(yaml_str).map_err(|e| {
            OrchestratorError::InvalidDefinition(format!("yaml parse: {e}"))
        })?;
        Ok(def)
    }
}

// ---------------------------------------------------------------------------
// Orchestrator — the central nervous system
// ---------------------------------------------------------------------------

/// The orchestrator manages the agent swarm, message bus, and routing.
///
/// It is the single owner of:
/// - the agent registry (`agents`)
/// - the broadcast message bus (`message_bus`)
/// - the spawn/routing logic
#[derive(Debug)]
pub struct Orchestrator {
    pub agents: HashMap<AgentId, Agent>,
    /// Broadcast channel for system-wide messages.
    pub message_bus: (mpsc::UnboundedSender<AgentMessage>, mpsc::UnboundedReceiver<AgentMessage>),
    /// Next agent ID counter (for deterministic generation when needed).
    next_counter: u64,
}

impl Orchestrator {
    /// Create a new empty orchestrator.
    pub fn new() -> Self {
        let (tx, rx) = mpsc::unbounded_channel();
        Self {
            agents: HashMap::new(),
            message_bus: (tx, rx),
            next_counter: 0,
        }
    }

    /// Spawn a new agent from an [`AgentDef`].
    ///
    /// 1. Parse the definition (from Markdown frontmatter)
    /// 2. Create `VaultPermissions` from `vault_paths` and `tools`
    /// 3. Create a `ResonanceGate` with the given threshold
    /// 4. Register the agent in the swarm
    /// 5. Return the assigned `AgentId`
    #[instrument(skip(self, def), fields(role = %def.role))]
    pub fn spawn_agent(&mut self, def: &AgentDef) -> Result<AgentId, OrchestratorError> {
        let id = self.generate_agent_id(&def.agent_id);

        let mut permissions = VaultPermissions::new();
        for path in &def.vault_paths {
            permissions.read_paths.insert(path.clone());
            permissions.write_paths.insert(path.clone());
        }
        for tool in &def.tools {
            permissions.tools.insert(tool.clone());
        }

        let thresholds = crate::gate::GateThresholds {
            promote_min: def.resonance_threshold,
            ..Default::default()
        };
        let resonance = ResonanceGate::new(thresholds);

        // Create a minimal scope state
        let scope = ScopeRexState {
            h_t: crate::scope_rex::ModelState {
                state_hash: [0u8; 32],
                seq_pos: 0,
                layer: 0,
            },
            z_t: crate::scope_rex::SparseFeatures {
                indices: vec![],
                dictionary_size: 0,
            },
            g_t: crate::scope_rex::ClaimGraph::new(),
            p_t: crate::scope_rex::ProofTree { obligations: vec![] },
            m_t: crate::scope_rex::MemoryRoot {
                root: [0u8; 32],
                entry_count: 0,
            },
            w_t: crate::scope_rex::ToolLedger { invocations: vec![] },
            l_t: crate::scope_rex::LossLedger {
                entries: vec![],
                moving_average: 0.0,
            },
            u_t: crate::scope_rex::AuthState::Unauthenticated,
        };

        let (tx, _rx) = mpsc::unbounded_channel();
        let agent = Agent {
            id,
            role: def.role.clone(),
            resonance,
            scope,
            vault_access: permissions,
            mailbox: Some(tx),
        };

        self.agents.insert(id, agent);
        info!(agent_id = %id, role = %def.role, "agent spawned");
        Ok(id)
    }

    /// Generate a deterministic `AgentId` from a string seed.
    fn generate_agent_id(&mut self, seed: &str) -> AgentId {
        let mut hasher = blake3::Hasher::new();
        hasher.update(seed.as_bytes());
        hasher.update(&self.next_counter.to_le_bytes());
        self.next_counter += 1;
        let hash: [u8; 32] = hasher.finalize().into();
        // Take first 16 bytes as UUID
        let mut uuid_bytes = [0u8; 16];
        uuid_bytes.copy_from_slice(&hash[..16]);
        AgentId(uuid::Uuid::from_bytes(uuid_bytes))
    }

    /// Route a message to the best-matching agent.
    ///
    /// If `message.to` is `Some`, route directly. Otherwise, evaluate
    /// every agent's resonance score against the message and pick the
    /// highest scorer. Returns the target agent's ID.
    #[instrument(skip(self, msg), fields(msg_id = hex::encode(&msg.id)))]
    pub fn route_message(&mut self, msg: AgentMessage) -> Result<AgentId, OrchestratorError> {
        // Direct routing
        if let Some(target) = msg.to {
            if self.agents.contains_key(&target) {
                debug!(target = %target, "direct routing");
                if let Some(agent) = self.agents.get(&target) {
                    if let Some(ref tx) = agent.mailbox {
                        let _ = tx.send(msg.clone());
                    }
                }
                return Ok(target);
            } else {
                return Err(OrchestratorError::AgentNotFound(target));
            }
        }

        // Resonance-based routing
        let mut best_agent: Option<AgentId> = None;
        let mut best_score: f32 = -1.0;

        for (id, agent) in self.agents.iter_mut() {
            let score = agent.resonance_score(&msg);
            debug!(agent_id = %id, score, "resonance score computed");
            if score > best_score {
                best_score = score;
                best_agent = Some(*id);
            }
        }

        match best_agent {
            Some(id) => {
                info!(agent_id = %id, score = best_score, "message routed by resonance");
                if let Some(agent) = self.agents.get(&id) {
                    if let Some(ref tx) = agent.mailbox {
                        let _ = tx.send(msg);
                    }
                }
                Ok(id)
            }
            None => Err(OrchestratorError::NoRoute {
                msg_id: hex::encode(&msg.id),
            }),
        }
    }

    /// Broadcast a message to all agents.
    pub fn broadcast(&self, msg: AgentMessage) -> usize {
        let mut delivered = 0;
        for agent in self.agents.values() {
            if let Some(ref tx) = agent.mailbox {
                if tx.send(msg.clone()).is_ok() {
                    delivered += 1;
                }
            }
        }
        delivered
    }

    /// Terminate an agent by ID.
    pub fn terminate_agent(&mut self, id: AgentId) -> Result<(), OrchestratorError> {
        self.agents
            .remove(&id)
            .ok_or(OrchestratorError::AgentNotFound(id))?;
        info!(agent_id = %id, "agent terminated");
        Ok(())
    }

    /// Number of live agents.
    pub fn agent_count(&self) -> usize {
        self.agents.len()
    }

    /// Get a reference to an agent.
    pub fn agent(&self, id: AgentId) -> Option<&Agent> {
        self.agents.get(&id)
    }

    /// Get a mutable reference to an agent.
    pub fn agent_mut(&mut self, id: AgentId) -> Option<&mut Agent> {
        self.agents.get_mut(&id)
    }
}

impl Default for Orchestrator {
    fn default() -> Self {
        Self::new()
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::gate::{GateThresholds, ResonanceGate};

    fn sample_agent_def() -> AgentDef {
        AgentDef {
            agent_id: "planner-alpha".into(),
            role: "strategic_planner".into(),
            resonance_threshold: 0.85,
            vault_paths: vec!["/vault/plans".into()],
            tools: vec!["reason.plan".into(), "vault.search".into()],
        }
    }

    #[test]
    fn agent_def_from_markdown() {
        let md = r#"---
agent_id: planner-alpha
role: strategic_planner
resonance_threshold: 0.85
vault_paths: ["/vault/plans"]
tools: [reason.plan, vault.search]
---

# Agent: planner-alpha
This agent handles strategic planning.
"#;
        let def = AgentDef::from_markdown(md).unwrap();
        assert_eq!(def.agent_id, "planner-alpha");
        assert_eq!(def.role, "strategic_planner");
        assert!((def.resonance_threshold - 0.85).abs() < 0.01);
        assert_eq!(def.vault_paths, vec!["/vault/plans"]);
        assert_eq!(def.tools, vec!["reason.plan", "vault.search"]);
    }

    #[test]
    fn agent_def_from_markdown_default_threshold() {
        let md = r#"---
agent_id: simple-beta
role: echo
---
"#;
        let def = AgentDef::from_markdown(md).unwrap();
        assert!((def.resonance_threshold - 0.75).abs() < 0.01);
    }

    #[test]
    fn agent_def_invalid_markdown() {
        let md = "no frontmatter here";
        let err = AgentDef::from_markdown(md).unwrap_err();
        assert!(matches!(err, OrchestratorError::InvalidDefinition(_)));
    }

    #[test]
    fn orchestrator_spawn_agent() {
        let mut orch = Orchestrator::new();
        let def = sample_agent_def();
        let id = orch.spawn_agent(&def).unwrap();
        assert_eq!(orch.agent_count(), 1);

        let agent = orch.agent(id).unwrap();
        assert_eq!(agent.role, "strategic_planner");
        assert!(agent.vault_access.can_read("/vault/plans"));
        assert!(agent.vault_access.can_use_tool("reason.plan"));
    }

    #[test]
    fn orchestrator_terminate_agent() {
        let mut orch = Orchestrator::new();
        let def = sample_agent_def();
        let id = orch.spawn_agent(&def).unwrap();
        assert_eq!(orch.agent_count(), 1);

        orch.terminate_agent(id).unwrap();
        assert_eq!(orch.agent_count(), 0);

        let err = orch.terminate_agent(id).unwrap_err();
        assert!(matches!(err, OrchestratorError::AgentNotFound(_)));
    }

    #[test]
    fn orchestrator_direct_routing() {
        let mut orch = Orchestrator::new();
        let def1 = AgentDef {
            agent_id: "agent-a".into(),
            role: "alpha".into(),
            resonance_threshold: 0.5,
            vault_paths: vec![],
            tools: vec![],
        };
        let def2 = AgentDef {
            agent_id: "agent-b".into(),
            role: "beta".into(),
            resonance_threshold: 0.5,
            vault_paths: vec![],
            tools: vec![],
        };
        let id_a = orch.spawn_agent(&def1).unwrap();
        let id_b = orch.spawn_agent(&def2).unwrap();

        let msg = AgentMessage {
            id: [1u8; 32],
            from: None,
            to: Some(id_b),
            kind: MessageKind::UserQuery,
            payload: "hello beta".into(),
            timestamp: chrono::Utc::now(),
            auth_token: None,
        };

        let routed = orch.route_message(msg).unwrap();
        assert_eq!(routed, id_b);
    }

    #[test]
    fn orchestrator_resonance_routing() {
        let mut orch = Orchestrator::new();
        let def1 = AgentDef {
            agent_id: "high-res".into(),
            role: "specialist".into(),
            resonance_threshold: 0.3, // low threshold → high promotion rate
            vault_paths: vec![],
            tools: vec![],
        };
        let def2 = AgentDef {
            agent_id: "low-res".into(),
            role: "generalist".into(),
            resonance_threshold: 0.9, // high threshold → low promotion rate
            vault_paths: vec![],
            tools: vec![],
        };
        orch.spawn_agent(&def1).unwrap();
        orch.spawn_agent(&def2).unwrap();

        let msg = AgentMessage {
            id: [2u8; 32],
            from: None,
            to: None, // no target → resonance routing
            kind: MessageKind::UserQuery,
            payload: "plan something".into(),
            timestamp: chrono::Utc::now(),
            auth_token: None,
        };

        let routed = orch.route_message(msg).unwrap();
        // The high-res agent should score higher
        let agent = orch.agent(routed).unwrap();
        assert_eq!(agent.role, "specialist");
    }

    #[test]
    fn orchestrator_broadcast() {
        let mut orch = Orchestrator::new();
        let def1 = AgentDef {
            agent_id: "a1".into(),
            role: "r1".into(),
            resonance_threshold: 0.5,
            vault_paths: vec![],
            tools: vec![],
        };
        let def2 = AgentDef {
            agent_id: "a2".into(),
            role: "r2".into(),
            resonance_threshold: 0.5,
            vault_paths: vec![],
            tools: vec![],
        };
        orch.spawn_agent(&def1).unwrap();
        orch.spawn_agent(&def2).unwrap();

        let msg = AgentMessage {
            id: [3u8; 32],
            from: None,
            to: None,
            kind: MessageKind::Lifecycle,
            payload: "heartbeat".into(),
            timestamp: chrono::Utc::now(),
            auth_token: None,
        };

        let delivered = orch.broadcast(msg);
        assert_eq!(delivered, 2);
    }

    #[test]
    fn agent_resonance_score_range() {
        let mut agent = Agent {
            id: AgentId::new(),
            role: "test".into(),
            resonance: ResonanceGate::new(GateThresholds::default()),
            scope: ScopeRexState {
                h_t: crate::scope_rex::ModelState {
                    state_hash: [0u8; 32],
                    seq_pos: 0,
                    layer: 0,
                },
                z_t: crate::scope_rex::SparseFeatures {
                    indices: vec![],
                    dictionary_size: 0,
                },
                g_t: crate::scope_rex::ClaimGraph::new(),
                p_t: crate::scope_rex::ProofTree { obligations: vec![] },
                m_t: crate::scope_rex::MemoryRoot {
                    root: [0u8; 32],
                    entry_count: 0,
                },
                w_t: crate::scope_rex::ToolLedger { invocations: vec![] },
                l_t: crate::scope_rex::LossLedger {
                    entries: vec![],
                    moving_average: 0.0,
                },
                u_t: crate::scope_rex::AuthState::Unauthenticated,
            },
            vault_access: VaultPermissions::new(),
            mailbox: None,
        };

        let msg = AgentMessage {
            id: [4u8; 32],
            from: None,
            to: None,
            kind: MessageKind::UserQuery,
            payload: "test message".into(),
            timestamp: chrono::Utc::now(),
            auth_token: None,
        };

        let score = agent.resonance_score(&msg);
        assert!(score >= 0.0 && score <= 1.0);
    }
}
