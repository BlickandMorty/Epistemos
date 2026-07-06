// ═══ AUDIT AMENDMENT (2026-07-06, repo-juxtaposed — BINDING; overrides body where they conflict) ═══
// PLACEMENT AMENDMENT — DEFERRED TO SCHEMA REFERENCE. agent_core has ZERO connection to the 1Code
// backend (grep: no 1code/trpc hits; ExperimentalAgent/*.swift has zero agent_core references).
// For the 1Code-only companion, run-state events ORIGINATE IN THE NODE BACKEND (claude-agent-sdk
// events inside claude.ts: thinking_delta / tool_use / stop_reason / error_max_turns) — NOT here.
// v1 flow: Node backend (electron-shim) → `/host` ws frame {kind:"presence:state"} →
// ExperimentalHostBridge.handle(kind:) (ONE new case) → Swift hub. This file's enums remain the
// WIRE SCHEMA both sides mirror (TS + Swift), and become live Rust code only if June/agent_core
// ever feeds presence (companions are 1Code-only today, so that is future-optional).
// ════════════════════════════════════════════════════════════════════════════════════════════════
//! run_state.rs — EPI-RP-05-KINDRED (BINDING: skin over real state).
//!
//! The mascot's emotes are a SKIN over THIS. Every variant is produced by a REAL event
//! from the claude-agent-sdk stream (thinking_delta, tool_use, ResultMessage.stop_reason,
//! error_max_turns). There is no synthetic state. If the agent is not in a state, the
//! mascot may not show it. This is the anti-Clippy, anti-fake-animation guarantee.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum RunState {
    Idle,
    Thinking,          // thinking_delta events
    Reading,           // Read/Grep tool start
    Searching,         // WebSearch tool start
    Editing,           // a suggestion transaction was applied to the doc
    ToolRunning,       // any other tool_use in flight
    AwaitingApproval,  // a per-turn approval gate is open
    Done,              // stop_reason: end_turn
    Blocked,           // stop_reason: refusal, or a denied approval
    Error,             // error_max_turns and friends
}

/// The real event source. `agent_core` translates claude-agent-sdk stream items into these.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub enum RunEvent {
    ThinkingDelta { turn_id: String },
    ToolStart { turn_id: String, tool: String },
    SuggestionApplied { turn_id: String, suggestion_id: String },
    ApprovalRequested { turn_id: String, tool: String },
    TurnEnded { turn_id: String, stop_reason: String },
    Errored { turn_id: String, kind: String },
}

impl RunEvent {
    /// The ONLY place a RunState is derived. No caller may fabricate a state off-stream.
    pub fn to_state(&self) -> RunState {
        match self {
            RunEvent::ThinkingDelta { .. } => RunState::Thinking,
            RunEvent::ToolStart { tool, .. } => match tool.as_str() {
                "Read" | "Grep" => RunState::Reading,
                "WebSearch" => RunState::Searching,
                "Edit" | "Write" => RunState::Editing,
                _ => RunState::ToolRunning,
            },
            RunEvent::SuggestionApplied { .. } => RunState::Editing,
            RunEvent::ApprovalRequested { .. } => RunState::AwaitingApproval,
            RunEvent::TurnEnded { stop_reason, .. } => match stop_reason.as_str() {
                "refusal" => RunState::Blocked,
                _ => RunState::Done,
            },
            RunEvent::Errored { .. } => RunState::Error,
        }
    }
}
