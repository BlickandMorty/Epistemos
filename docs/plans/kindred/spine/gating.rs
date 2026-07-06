//! gating.rs — EPI-RP-05-KINDRED · D7 honest gating (BINDING).
//!
//! The exact authority boundary. A companion is NOT a tool with a friendly face that
//! silently escalates. It holds a small BOUND authority and must ask for everything else,
//! per turn. This is both the security model (prompt-injection defense-in-depth) and the
//! attachment model (the anti-Clippy: quiet, honest, disableable).

use serde::{Deserialize, Serialize};

/// Held WITHOUT per-turn approval. This is the whole of a companion's ambient authority.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum BoundAuthority {
    PersonaPreamble,
    VaultMcpRead { scope: String },   // persona-scoped READ over the vault, nothing more
    Chat,
}

/// REQUIRES per-turn user approval every time. Nothing here is ever ambient.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum GatedAction {
    ToolCall { name: String },
    FileWrite { path: String },       // agent edits ARE a destructive-op surface
    Network { host: String },
    Destructive { description: String },
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum ApprovalDecision {
    Approve,
    ApproveForTurn,
    Reject,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ApprovalRequest {
    pub turn_id: String,
    pub companion_id: String,
    pub action: GatedAction,
    pub rationale: Option<String>,    // shown to the user with the request
}

/// The gate. Every GatedAction crosses this and BLOCKS until the user answers. The UI
/// surfaces a capability chip distinguishing can-do (bound) from is-doing (this turn).
pub trait ApprovalGate: Send + Sync {
    fn request(&self, req: ApprovalRequest) -> ApprovalDecision;
    // TODO: block the agent turn until the user answers; wire to the 1Code approval UI.
    // NOTE: max_turns is a safety RAIL; the agent still decides stop_reason.
}

/// Prompt-injection posture (OWASP LLM01 defense-in-depth): vault/web content a companion
/// READS is untrusted and must never be routed into the persona/system channel, and can
/// never by itself authorize a GatedAction. Keep the trusted:untrusted context ratio bounded.
pub struct InjectionGuard;

impl InjectionGuard {
    /// True if this text may enter the trusted/persona channel. Untrusted reads may only
    /// enter the data channel, never the instruction channel.
    pub fn may_enter_trusted_channel(_text: &str) -> bool {
        // TODO: enforce quarantine — untrusted reads never carry instruction authority.
        false
    }
}
