//! Canonical `AgentEvent` enum (S2; DOCTRINE §11) + support types.
//!
//! Per DOCTRINE I-3 every provider stream — Anthropic SSE, OpenAI
//! deltas, Kimi (OpenAI-compatible), Hermes Agent JSON-RPC, local
//! MLX inference — normalises into this single enum at the
//! `crate::normalize::*` boundary. The simulation reducer (S2/S4)
//! and the FFI delta ring (S4) read ONLY this. Provider-specific
//! payloads are erased here.
//!
//! Per DOCTRINE I-13 events themselves do not carry timestamps —
//! time is attached at log-append time by `crate::event_log` and
//! consumed by the reducer from the persisted log entry. This keeps
//! the reducer free of system-clock leaks.
//!
//! Per DOCTRINE I-4 the graph subset (`GraphNodeAccessed`,
//! `GraphNodeCreated`, `GraphEdgeCreated`, `GraphTraverseStarted` /
//! `Completed`) constitutes the proof that any animated mutation
//! actually happened. Animations triggered without a backing event
//! in this enum are a defect (DOCTRINE I-5).

use serde::{Deserialize, Serialize};

use crate::companions::{ActivityState, CompanionId, HeadShape, ProviderRole};

// =============================================================================
// Strongly-typed identifier wrappers. All serialise as transparent
// strings so the JSONL event log is human-readable.
// =============================================================================

macro_rules! id_wrapper {
    ($(#[$meta:meta])* $name:ident) => {
        $(#[$meta])*
        #[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
        #[serde(transparent)]
        pub struct $name(pub String);

        impl $name {
            pub fn new(s: impl Into<String>) -> Self { Self(s.into()) }
            pub fn as_str(&self) -> &str { &self.0 }
        }

        impl std::fmt::Display for $name {
            fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
                f.write_str(&self.0)
            }
        }

        impl From<&str> for $name {
            fn from(s: &str) -> Self { Self(s.to_string()) }
        }

        impl From<String> for $name {
            fn from(s: String) -> Self { Self(s) }
        }
    };
}

id_wrapper!(
    /// Session identifier. ULIDs preferred but provider-supplied
    /// strings (e.g. `msg_*`, `chatcmpl-*`) are accepted verbatim.
    SessionId
);
id_wrapper!(MessageId);
id_wrapper!(ToolCallId);
id_wrapper!(NodeId);
id_wrapper!(EdgeId);
id_wrapper!(ArtifactId);
id_wrapper!(RunId);
id_wrapper!(TaskId);
id_wrapper!(ActionId);
id_wrapper!(ErrorId);

// =============================================================================
// Blake3 32-byte hash with hex serde. Used for input_hash on
// `ToolCallStarted` (so reducers can de-duplicate tool calls without
// re-hashing) and for the event log's content-chain integrity check.
// =============================================================================

#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub struct Blake3Hash([u8; 32]);

impl Blake3Hash {
    pub const ZERO: Self = Self([0u8; 32]);

    pub fn of(data: &[u8]) -> Self {
        Self(*blake3::hash(data).as_bytes())
    }

    pub fn bytes(&self) -> &[u8; 32] {
        &self.0
    }

    pub fn to_hex(&self) -> String {
        let mut s = String::with_capacity(64);
        for b in self.0 {
            s.push_str(&format!("{:02x}", b));
        }
        s
    }

    pub fn from_hex(hex: &str) -> Option<Self> {
        if hex.len() != 64 {
            return None;
        }
        let mut out = [0u8; 32];
        for (i, byte) in out.iter_mut().enumerate() {
            *byte = u8::from_str_radix(&hex[i * 2..i * 2 + 2], 16).ok()?;
        }
        Some(Self(out))
    }
}

impl std::fmt::Debug for Blake3Hash {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Blake3Hash({})", &self.to_hex()[..16])
    }
}

impl Serialize for Blake3Hash {
    fn serialize<S: serde::Serializer>(&self, s: S) -> Result<S::Ok, S::Error> {
        s.serialize_str(&self.to_hex())
    }
}

impl<'de> Deserialize<'de> for Blake3Hash {
    fn deserialize<D: serde::Deserializer<'de>>(d: D) -> Result<Self, D::Error> {
        let hex = String::deserialize(d)?;
        Blake3Hash::from_hex(&hex)
            .ok_or_else(|| serde::de::Error::custom(format!("invalid blake3 hex '{hex}'")))
    }
}

// =============================================================================
// Support enums.
// =============================================================================

/// Session mode per DOCTRINE §3.6 / §4.8 (Deep Deliberation lives in
/// V3; the enum carries V0/V1 modes plus forward-references).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SessionMode {
    Chat,
    ResearchJury,
    DeepDeliberation,
    Hermes,
    Custom,
}

/// Graph node kinds — mirrors the Swift-side `Node*` enum in
/// `Models/GraphTypes.swift`. Stable ordering for FFI parity.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum NodeKind {
    Note,
    Chat,
    Idea,
    Source,
    Folder,
    Quote,
    Tag,
    Block,
}

/// Graph edge kinds — 12 total per DOCTRINE / CLAUDE.md FFI ABI.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum EdgeKind {
    Reference,
    Citation,
    Mention,
    DerivesFrom,
    Contradicts,
    Supports,
    Continues,
    Summarises,
    Tags,
    Authors,
    GeneratedBy,
    Questions,
}

/// Artifact kinds — bodies, summaries, tool outputs, etc.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ArtifactKind {
    MessageBody,
    ThinkingSummary,
    ToolOutput,
    Plan,
    Document,
    Custom,
}

/// Reference to an artifact body in the artifact store. Used by
/// `MessageCompleted` so the event log doesn't carry full message
/// text inline.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ArtifactRef {
    pub id: ArtifactId,
    pub kind: ArtifactKind,
}

/// Pending action awaiting approval (DOCTRINE §4.4 + §11
/// `AwaitingApproval`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PendingAction {
    pub action_id: ActionId,
    pub kind: PendingActionKind,
    pub description: String,
    pub tool_name: Option<String>,
    /// Action input as JSON. Serialised as a `Value` so the reducer
    /// can render summaries without coupling to specific tool
    /// schemas.
    pub input: serde_json::Value,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum PendingActionKind {
    ToolCall,
    FileWrite,
    Subprocess,
    NetworkRequest,
    GraphMutation,
}

/// Outcome of a task or sub-agent. Used by `TaskCompleted`,
/// `SubagentCompleted`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "outcome", rename_all = "snake_case")]
pub enum TaskResult {
    Success { summary: Option<String> },
    Failed { error: String },
    Cancelled { reason: Option<String> },
}

impl TaskResult {
    pub fn is_success(&self) -> bool {
        matches!(self, TaskResult::Success { .. })
    }
}

/// One change inside a `ConfigDiff`. Pairs the JSON before / after
/// values with a category label so the audit ledger can mark each
/// change as Config (real config knob) or Cosmetic (DOCTRINE §5.5).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FieldChange {
    pub field: String,
    pub from: serde_json::Value,
    pub to: serde_json::Value,
    pub category: ChangeCategory,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ChangeCategory {
    /// Maps to a real `ModelProfile` config knob per DOCTRINE §5.5
    /// Category A — counts toward audit ledger.
    Config,
    /// Pure visual change per Category B. Logged but not
    /// load-bearing.
    Cosmetic,
}

/// Compact diff used by `CompanionUpdated` and `GiftBoxUnwrapped`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ConfigDiff {
    pub field_changes: Vec<FieldChange>,
}

impl ConfigDiff {
    pub fn empty() -> Self {
        Self { field_changes: Vec::new() }
    }
}

// =============================================================================
// AgentEvent — the canonical enum (DOCTRINE §11, all 38 variants).
// =============================================================================

/// Every visible companion / session action. Per DOCTRINE I-3 all
/// providers normalize into this enum at `crate::normalize`; the
/// simulation reducer reads ONLY this.
///
/// Variant grouping (mostly cosmetic — JSON tag is `type`, payload
/// is `payload`):
///   - Session lifecycle: SessionStarted / Completed / Committed
///   - Participants: ParticipantJoined / Left
///   - Message stream: MessageStarted / Delta / Completed
///   - Thinking blocks (preserved per CLAUDE.md): ThinkingStarted /
///     Delta / Completed
///   - Tool calls: ToolCallStarted / Delta / Completed / Failed
///   - Memory + graph (DOCTRINE §11 + I-4 mutation proof):
///     MemoryRetrieved, GraphTraverseStarted / Completed,
///     GraphNodeAccessed / Created, GraphEdgeCreated
///   - Artifacts + tasks: ArtifactCreated, TaskCreated / Completed
///   - Subagents: SubagentSpawned / Completed
///   - Handoffs: HandoffStarted / Completed
///   - Approval gates: AwaitingApproval, ApprovalGranted / Denied
///   - Errors / recovery: Error, RecoveryStarted / Completed
///   - Companion lifecycle (registry-driven): CompanionRegistered /
///     Updated / Archived / ActivityStateChanged
///   - Gift boxes (S11): GiftBoxReceived / Unwrapped
///   - Workspace selection (S6): WorkspaceFocused
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", content = "payload", rename_all = "snake_case")]
pub enum AgentEvent {
    SessionStarted {
        session_id: SessionId,
        mode: SessionMode,
    },
    SessionCompleted {
        session_id: SessionId,
        summary: Option<String>,
    },
    SessionCommitted {
        session_id: SessionId,
        artifacts: Vec<NodeId>,
    },

    ParticipantJoined {
        agent_id: CompanionId,
        role: ProviderRole,
    },
    ParticipantLeft {
        agent_id: CompanionId,
    },

    MessageStarted {
        message_id: MessageId,
        agent_id: CompanionId,
    },
    MessageDelta {
        message_id: MessageId,
        delta: String,
    },
    MessageCompleted {
        message_id: MessageId,
        full_text_ref: ArtifactRef,
    },

    ThinkingStarted {
        agent_id: CompanionId,
        message_id: MessageId,
    },
    ThinkingDelta {
        message_id: MessageId,
        token_count: u32,
    },
    ThinkingCompleted {
        message_id: MessageId,
        summary_ref: Option<ArtifactRef>,
    },

    ToolCallStarted {
        tool_call_id: ToolCallId,
        agent_id: CompanionId,
        tool_name: String,
        input_hash: Blake3Hash,
    },
    ToolCallDelta {
        tool_call_id: ToolCallId,
        partial: serde_json::Value,
    },
    ToolCallCompleted {
        tool_call_id: ToolCallId,
        output_ref: ArtifactRef,
    },
    ToolCallFailed {
        tool_call_id: ToolCallId,
        error: String,
    },

    MemoryRetrieved {
        agent_id: CompanionId,
        node_id: NodeId,
        score: f32,
    },
    GraphTraverseStarted {
        agent_id: CompanionId,
        start: NodeId,
        max_depth: u32,
    },
    GraphTraverseCompleted {
        agent_id: CompanionId,
        visited: Vec<NodeId>,
    },
    GraphNodeAccessed {
        agent_id: CompanionId,
        node_id: NodeId,
    },
    GraphNodeCreated {
        agent_id: CompanionId,
        node_id: NodeId,
        kind: NodeKind,
    },
    GraphEdgeCreated {
        agent_id: CompanionId,
        edge_id: EdgeId,
        from: NodeId,
        to: NodeId,
        kind: EdgeKind,
    },

    ArtifactCreated {
        artifact_id: ArtifactId,
        kind: ArtifactKind,
        generated_by_run: RunId,
    },
    TaskCreated {
        task_id: TaskId,
        agent_id: CompanionId,
        description: String,
    },
    TaskCompleted {
        task_id: TaskId,
        result: TaskResult,
    },

    SubagentSpawned {
        parent_id: CompanionId,
        child_id: CompanionId,
        count: u8,
    },
    SubagentCompleted {
        child_id: CompanionId,
        result: TaskResult,
    },

    HandoffStarted {
        from_id: CompanionId,
        to_id: CompanionId,
        payload_id: ArtifactRef,
    },
    HandoffCompleted {
        from_id: CompanionId,
        to_id: CompanionId,
        payload_id: ArtifactRef,
    },

    AwaitingApproval {
        agent_id: CompanionId,
        action: PendingAction,
        deadline_ms: u64,
    },
    ApprovalGranted {
        agent_id: CompanionId,
        action_id: ActionId,
    },
    ApprovalDenied {
        agent_id: CompanionId,
        action_id: ActionId,
        reason: Option<String>,
    },

    Error {
        agent_id: CompanionId,
        code: String,
        message: String,
    },
    RecoveryStarted {
        agent_id: CompanionId,
        error_id: ErrorId,
    },
    RecoveryCompleted {
        agent_id: CompanionId,
        error_id: ErrorId,
        success: bool,
    },

    CompanionRegistered {
        companion_id: CompanionId,
        name: String,
        head_shape: HeadShape,
        role: ProviderRole,
        base_model: String,
    },
    CompanionUpdated {
        companion_id: CompanionId,
        diff: ConfigDiff,
    },
    CompanionArchived {
        companion_id: CompanionId,
    },
    CompanionActivityStateChanged {
        companion_id: CompanionId,
        from: ActivityState,
        to: ActivityState,
    },

    GiftBoxReceived {
        companion_id: CompanionId,
        epbox_id: String,
    },
    GiftBoxUnwrapped {
        companion_id: CompanionId,
        epbox_id: String,
        applied_diff: ConfigDiff,
    },

    WorkspaceFocused {
        companion_id: Option<CompanionId>,
    },
}

impl AgentEvent {
    /// Stable discriminator string per variant. Matches the JSON
    /// tag (snake_case via serde rename_all).
    pub fn kind(&self) -> &'static str {
        match self {
            AgentEvent::SessionStarted { .. } => "session_started",
            AgentEvent::SessionCompleted { .. } => "session_completed",
            AgentEvent::SessionCommitted { .. } => "session_committed",
            AgentEvent::ParticipantJoined { .. } => "participant_joined",
            AgentEvent::ParticipantLeft { .. } => "participant_left",
            AgentEvent::MessageStarted { .. } => "message_started",
            AgentEvent::MessageDelta { .. } => "message_delta",
            AgentEvent::MessageCompleted { .. } => "message_completed",
            AgentEvent::ThinkingStarted { .. } => "thinking_started",
            AgentEvent::ThinkingDelta { .. } => "thinking_delta",
            AgentEvent::ThinkingCompleted { .. } => "thinking_completed",
            AgentEvent::ToolCallStarted { .. } => "tool_call_started",
            AgentEvent::ToolCallDelta { .. } => "tool_call_delta",
            AgentEvent::ToolCallCompleted { .. } => "tool_call_completed",
            AgentEvent::ToolCallFailed { .. } => "tool_call_failed",
            AgentEvent::MemoryRetrieved { .. } => "memory_retrieved",
            AgentEvent::GraphTraverseStarted { .. } => "graph_traverse_started",
            AgentEvent::GraphTraverseCompleted { .. } => "graph_traverse_completed",
            AgentEvent::GraphNodeAccessed { .. } => "graph_node_accessed",
            AgentEvent::GraphNodeCreated { .. } => "graph_node_created",
            AgentEvent::GraphEdgeCreated { .. } => "graph_edge_created",
            AgentEvent::ArtifactCreated { .. } => "artifact_created",
            AgentEvent::TaskCreated { .. } => "task_created",
            AgentEvent::TaskCompleted { .. } => "task_completed",
            AgentEvent::SubagentSpawned { .. } => "subagent_spawned",
            AgentEvent::SubagentCompleted { .. } => "subagent_completed",
            AgentEvent::HandoffStarted { .. } => "handoff_started",
            AgentEvent::HandoffCompleted { .. } => "handoff_completed",
            AgentEvent::AwaitingApproval { .. } => "awaiting_approval",
            AgentEvent::ApprovalGranted { .. } => "approval_granted",
            AgentEvent::ApprovalDenied { .. } => "approval_denied",
            AgentEvent::Error { .. } => "error",
            AgentEvent::RecoveryStarted { .. } => "recovery_started",
            AgentEvent::RecoveryCompleted { .. } => "recovery_completed",
            AgentEvent::CompanionRegistered { .. } => "companion_registered",
            AgentEvent::CompanionUpdated { .. } => "companion_updated",
            AgentEvent::CompanionArchived { .. } => "companion_archived",
            AgentEvent::CompanionActivityStateChanged { .. } => "companion_activity_state_changed",
            AgentEvent::GiftBoxReceived { .. } => "gift_box_received",
            AgentEvent::GiftBoxUnwrapped { .. } => "gift_box_unwrapped",
            AgentEvent::WorkspaceFocused { .. } => "workspace_focused",
        }
    }

    /// The companion id this event is "about", if a single owning
    /// companion exists. Used by the activity tracker integration.
    pub fn primary_agent_id(&self) -> Option<CompanionId> {
        match self {
            AgentEvent::ParticipantJoined { agent_id, .. }
            | AgentEvent::ParticipantLeft { agent_id }
            | AgentEvent::MessageStarted { agent_id, .. }
            | AgentEvent::ThinkingStarted { agent_id, .. }
            | AgentEvent::ToolCallStarted { agent_id, .. }
            | AgentEvent::MemoryRetrieved { agent_id, .. }
            | AgentEvent::GraphTraverseStarted { agent_id, .. }
            | AgentEvent::GraphTraverseCompleted { agent_id, .. }
            | AgentEvent::GraphNodeAccessed { agent_id, .. }
            | AgentEvent::GraphNodeCreated { agent_id, .. }
            | AgentEvent::GraphEdgeCreated { agent_id, .. }
            | AgentEvent::TaskCreated { agent_id, .. }
            | AgentEvent::AwaitingApproval { agent_id, .. }
            | AgentEvent::ApprovalGranted { agent_id, .. }
            | AgentEvent::ApprovalDenied { agent_id, .. }
            | AgentEvent::Error { agent_id, .. }
            | AgentEvent::RecoveryStarted { agent_id, .. }
            | AgentEvent::RecoveryCompleted { agent_id, .. } => Some(*agent_id),
            AgentEvent::CompanionRegistered { companion_id, .. }
            | AgentEvent::CompanionUpdated { companion_id, .. }
            | AgentEvent::CompanionArchived { companion_id }
            | AgentEvent::CompanionActivityStateChanged { companion_id, .. }
            | AgentEvent::GiftBoxReceived { companion_id, .. }
            | AgentEvent::GiftBoxUnwrapped { companion_id, .. } => Some(*companion_id),
            AgentEvent::WorkspaceFocused { companion_id } => *companion_id,
            AgentEvent::SubagentSpawned { parent_id, .. } => Some(*parent_id),
            AgentEvent::SubagentCompleted { child_id, .. } => Some(*child_id),
            AgentEvent::HandoffStarted { from_id, .. }
            | AgentEvent::HandoffCompleted { from_id, .. } => Some(*from_id),
            // Session and message-completion events carry no
            // single owning companion; the reducer joins them
            // against the active session participants.
            AgentEvent::SessionStarted { .. }
            | AgentEvent::SessionCompleted { .. }
            | AgentEvent::SessionCommitted { .. }
            | AgentEvent::MessageDelta { .. }
            | AgentEvent::MessageCompleted { .. }
            | AgentEvent::ThinkingDelta { .. }
            | AgentEvent::ThinkingCompleted { .. }
            | AgentEvent::ToolCallDelta { .. }
            | AgentEvent::ToolCallCompleted { .. }
            | AgentEvent::ToolCallFailed { .. }
            | AgentEvent::ArtifactCreated { .. }
            | AgentEvent::TaskCompleted { .. } => None,
        }
    }
}

// SimulationState moved to `crate::simulation::state` (S4) where
// the per-companion FSM lives. The lighter counter-style projection
// used by S2 `replay()` round-trip integrity tests now lives at
// `crate::digest::SimulationDigest` — a different concern.

#[cfg(test)]
mod tests {
    use super::*;

    fn cid(label: &str) -> CompanionId {
        // Deterministic test ids — derive a ULID from a hash of the
        // label so two test invocations produce identical ids.
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};
        let mut h = DefaultHasher::new();
        label.hash(&mut h);
        let n = h.finish();
        // Construct a ULID by composing a stable timestamp with the
        // hashed bytes.
        let ulid = ulid::Ulid::from_parts(0, n as u128);
        CompanionId(ulid)
    }

    #[test]
    fn agent_event_serde_round_trip() {
        let evt = AgentEvent::MessageStarted {
            message_id: MessageId::new("msg_abc"),
            agent_id: cid("alice"),
        };
        let json = serde_json::to_string(&evt).unwrap();
        let decoded: AgentEvent = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded, evt);
        // Tag follows snake_case rename_all.
        assert!(json.contains("\"type\":\"message_started\""));
    }

    #[test]
    fn kind_matches_serde_tag() {
        let cases = [
            AgentEvent::SessionStarted {
                session_id: SessionId::new("s1"),
                mode: SessionMode::Chat,
            },
            AgentEvent::ToolCallStarted {
                tool_call_id: ToolCallId::new("t1"),
                agent_id: cid("alice"),
                tool_name: "code_edit".to_string(),
                input_hash: Blake3Hash::of(b"input"),
            },
            AgentEvent::CompanionActivityStateChanged {
                companion_id: cid("alice"),
                from: ActivityState::Active,
                to: ActivityState::Recent,
            },
        ];
        for evt in cases {
            let kind = evt.kind();
            let json = serde_json::to_value(&evt).unwrap();
            assert_eq!(json["type"].as_str(), Some(kind));
        }
    }

    #[test]
    fn primary_agent_id_for_companion_events() {
        let alice = cid("alice");
        let bob = cid("bob");

        let participant = AgentEvent::ParticipantJoined {
            agent_id: alice,
            role: ProviderRole::CodeWorker,
        };
        assert_eq!(participant.primary_agent_id(), Some(alice));

        let handoff = AgentEvent::HandoffStarted {
            from_id: alice,
            to_id: bob,
            payload_id: ArtifactRef {
                id: ArtifactId::new("a1"),
                kind: ArtifactKind::Document,
            },
        };
        assert_eq!(handoff.primary_agent_id(), Some(alice));

        let session = AgentEvent::SessionStarted {
            session_id: SessionId::new("s1"),
            mode: SessionMode::Chat,
        };
        assert_eq!(session.primary_agent_id(), None);
    }

    #[test]
    fn blake3_hex_round_trip() {
        let h = Blake3Hash::of(b"hello world");
        let hex = h.to_hex();
        assert_eq!(hex.len(), 64);
        let decoded = Blake3Hash::from_hex(&hex).unwrap();
        assert_eq!(decoded, h);
    }

    #[test]
    fn blake3_serde_uses_hex() {
        let h = Blake3Hash::of(b"hello");
        let json = serde_json::to_string(&h).unwrap();
        let s: String = serde_json::from_str(&json).unwrap();
        assert_eq!(s.len(), 64);
        let decoded: Blake3Hash = serde_json::from_str(&json).unwrap();
        assert_eq!(decoded, h);
    }

    // SimulationState tests moved to `crate::digest` alongside the
    // `SimulationDigest` they cover.
}
