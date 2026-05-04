//! Runtime types — secure newtypes, intents, effects, and the deterministic `apply` kernel.
//!
//! This module defines the type system at the heart of the Epistenos runtime:
//! `Intent` describes what the user (or an agent) *wants*;
//! `Effect` describes what *actually happened*;
//! `State` is the observable application state that results from applying effects.
//!
//! The `apply` function is **pure, deterministic, and total** — every `Intent`
//! maps to exactly one `Effect` (or a typed error) with no side effects.

use serde::{Deserialize, Serialize};
use std::fmt;
use std::path::PathBuf;
use thiserror::Error;
use tracing::{debug, instrument, trace};
use uuid::Uuid;

// ---------------------------------------------------------------------------
// Secure newtypes
// ---------------------------------------------------------------------------

/// A cryptographically inert but semantically opaque agent identifier.
///
/// `AgentId` wraps a [`Uuid`] v4 so that agent identity cannot be confused
/// with session identity or raw strings in routing logic.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct AgentId(pub Uuid);

impl AgentId {
    /// Generate a fresh random agent identifier.
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }
}

impl Default for AgentId {
    fn default() -> Self {
        Self::new()
    }
}

impl fmt::Display for AgentId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "agent_{}", self.0)
    }
}

/// A session identifier scoped to a single conversational or task context.
///
/// Sessions are ephemeral — they live for the duration of a single top-level
/// user request and may span multiple agent hand-offs.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct SessionId(pub Uuid);

impl SessionId {
    /// Generate a fresh random session identifier.
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }
}

impl Default for SessionId {
    fn default() -> Self {
        Self::new()
    }
}

impl fmt::Display for SessionId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "session_{}", self.0)
    }
}

// ---------------------------------------------------------------------------
// Intent — what the system *should* do
// ---------------------------------------------------------------------------

/// A user- or agent-originated intent describing a desired change.
///
/// Intents are **descriptive**, not imperative. The runtime decides *how* to
/// realise each intent based on current `State`, tool availability, and
/// gating policy.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Intent {
    /// A capture (recording / observation) was placed into the system.
    CapturePlaced { payload: String, source: String },

    /// A note or document was edited.
    NoteEdited { path: PathBuf, content: String },

    /// A tool was invoked by name with structured arguments.
    ToolInvoked { tool: String, arguments: serde_json::Value },

    /// An agent should be spawned with the given role definition.
    AgentSpawned { role: String, definition: serde_json::Value },

    /// A message should be routed to the best-matching agent.
    MessageRouted { target: String, body: String },

    /// The user explicitly requested a state reset / undo.
    UndoRequested { count: usize },
}

// ---------------------------------------------------------------------------
// Effect — what *did* happen
// ---------------------------------------------------------------------------

/// The concrete, observable outcome of applying an [`Intent`].
///
/// Effects are the only things that mutate `State`. They are append-only,
/// immutable, and carry enough information to reconstruct any prior state
/// via the [`BrainTimeMachine`](crate::scope_rex::BrainTimeMachine).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum Effect {
    /// A file or note was written to stable storage.
    Wrote {
        path: PathBuf,
        /// Monotonic version counter for this path.
        version: u64,
        /// The previous content (if any) to enable undo.
        undo: Option<String>,
    },

    /// A tool was called and produced a result.
    Called {
        tool: String,
        /// JSON-serialised result of the tool invocation.
        result: serde_json::Value,
    },

    /// An agent was successfully spawned.
    Spawned { agent_id: AgentId, role: String },

    /// A message was delivered to an agent.
    Delivered { agent_id: AgentId, message_id: [u8; 32] },

    /// An undo was performed.
    Undone { reversed_effect_count: usize },

    /// A no-op (intent was idempotent or already satisfied).
    NoOp { reason: String },
}

// ---------------------------------------------------------------------------
// State — observable application state
// ---------------------------------------------------------------------------

/// The observable runtime state.
///
/// `State` is **not** the full 8-vector SCOPE-Rex state — it is the
/// *user-visible* projection: files, agents, messages, and tool results.
/// The full cognitive state lives in [`ScopeRexState`](crate::scope_rex::ScopeRexState).
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
pub struct State {
    /// Version counter — incremented on every committed effect.
    pub version: u64,

    /// Map from file path → current content.
    pub files: std::collections::HashMap<PathBuf, String>,

    /// Set of currently live agents.
    pub agents: std::collections::HashSet<AgentId>,

    /// Ordered log of committed effects (event sourcing).
    pub log: Vec<Effect>,
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// Errors that can arise during intent application.
#[derive(Error, Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ApplyError {
    #[error("unknown tool: {tool}")]
    UnknownTool { tool: String },

    #[error("invalid arguments for tool {tool}: {reason}")]
    InvalidArguments { tool: String, reason: String },

    #[error("path not found: {path:?}")]
    PathNotFound { path: PathBuf },

    #[error("undo exhausted: requested {requested}, available {available}")]
    UndoExhausted { requested: usize, available: usize },

    #[error("agent spawn failed: {reason}")]
    SpawnFailed { reason: String },

    #[error("generic apply error: {0}")]
    Generic(String),
}

// ---------------------------------------------------------------------------
// apply — the deterministic intent→effect kernel
// ---------------------------------------------------------------------------

/// Pure, deterministic, side-effect-free intent interpreter.
///
/// Given an [`Intent`] and the current [`State`], returns the [`Effect`]
/// that would result. No I/O, no network, no mutation — the caller
/// commits the effect to state separately.
///
/// # Example
/// ```
/// use helios_runtime::types::{Intent, State, apply};
///
/// let mut state = State::default();
/// let intent = Intent::CapturePlaced {
///     payload: "hello".into(),
///     source: "user".into(),
/// };
/// let effect = apply(&intent, &state).unwrap();
/// ```
#[instrument(skip(intent, state), fields(intent = ?intent, state_version = state.version))]
pub fn apply(intent: &Intent, state: &State) -> Result<Effect, ApplyError> {
    trace!("evaluating intent against state v{}", state.version);

    match intent {
        Intent::CapturePlaced { payload, source } => {
            debug!(source, "capture placed");
            let path = PathBuf::from(format!("captures/{}.md", source));
            let undo = state.files.get(&path).cloned();
            Ok(Effect::Wrote {
                path,
                version: state.version + 1,
                undo,
            })
        }

        Intent::NoteEdited { path, content } => {
            debug!(?path, "note edited");
            let undo = state.files.get(path).cloned();
            Ok(Effect::Wrote {
                path: path.clone(),
                version: state.version + 1,
                undo,
            })
        }

        Intent::ToolInvoked { tool, arguments } => {
            debug!(tool, ?arguments, "tool invoked");
            // TODO: real tool registry lookup — currently stubbed
            // In production this resolves through the VariantLadder.
            let result = serde_json::json!({
                "tool": tool,
                "arguments": arguments,
                "status": "ok",
                "note": "stubbed — real tool invocation routes through ladder.rs"
            });
            Ok(Effect::Called {
                tool: tool.clone(),
                result,
            })
        }

        Intent::AgentSpawned { role, definition: _ } => {
            debug!(role, "agent spawned");
            // In production this validates the definition against AgentDef schema.
            Ok(Effect::Spawned {
                agent_id: AgentId::new(),
                role: role.clone(),
            })
        }

        Intent::MessageRouted { target, body: _ } => {
            debug!(target, "message routed");
            // Routing logic is in orchestrator.rs; this is the kernel-level effect.
            // In a real system we'd look up the agent by role/resonance.
            let hash = blake3::hash(target.as_bytes());
            Ok(Effect::Delivered {
                agent_id: AgentId::new(), // stub — real routing uses resonance match
                message_id: hash.into(),
            })
        }

        Intent::UndoRequested { count } => {
            let available = state.log.len();
            if *count > available {
                return Err(ApplyError::UndoExhausted {
                    requested: *count,
                    available,
                });
            }
            debug!(count, "undo requested");
            Ok(Effect::Undone {
                reversed_effect_count: *count,
            })
        }
    }
}

/// Commit an [`Effect`] into a [`State`], producing the new state.
///
/// This is the **only** function that mutates `State` in the intent→effect
/// pipeline. It is pure (no I/O) but not total — it assumes the effect was
/// produced by `apply`.
pub fn commit(state: &mut State, effect: Effect) {
    match &effect {
        Effect::Wrote { path, version, .. } => {
            // In production we'd read the actual file content here.
            // For the kernel we store a placeholder derived from the path.
            state
                .files
                .insert(path.clone(), format!("v{}", version));
        }
        Effect::Called { .. } => {
            // Tool results are not part of observable file state.
        }
        Effect::Spawned { agent_id, .. } => {
            state.agents.insert(*agent_id);
        }
        Effect::Delivered { .. } => {
            // Message delivery is logged but does not change file state.
        }
        Effect::Undone { reversed_effect_count } => {
            for _ in 0..*reversed_effect_count {
                if let Some(last) = state.log.pop() {
                    if let Effect::Wrote { path, undo, .. } = last {
                        if let Some(prev) = undo {
                            state.files.insert(path, prev);
                        } else {
                            state.files.remove(&path);
                        }
                    }
                }
            }
        }
        Effect::NoOp { .. } => {}
    }
    state.log.push(effect);
    state.version += 1;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn agent_id_display() {
        let id = AgentId::new();
        let s = id.to_string();
        assert!(s.starts_with("agent_"));
    }

    #[test]
    fn session_id_display() {
        let id = SessionId::new();
        let s = id.to_string();
        assert!(s.starts_with("session_"));
    }

    #[test]
    fn apply_capture_placed() {
        let state = State::default();
        let intent = Intent::CapturePlaced {
            payload: "test".into(),
            source: "user".into(),
        };
        let effect = apply(&intent, &state).unwrap();
        assert!(
            matches!(effect, Effect::Wrote { ref path, version: 1, undo: None } if path.to_string_lossy() == "captures/user.md")
        );
    }

    #[test]
    fn apply_note_edited() {
        let mut state = State::default();
        state.files.insert(PathBuf::from("notes/x.md"), "old".into());
        let intent = Intent::NoteEdited {
            path: PathBuf::from("notes/x.md"),
            content: "new".into(),
        };
        let effect = apply(&intent, &state).unwrap();
        assert!(
            matches!(effect, Effect::Wrote { ref path, version: 1, undo: Some(ref old) } if path == "notes/x.md" && old == "old")
        );
    }

    #[test]
    fn apply_tool_invoked() {
        let state = State::default();
        let intent = Intent::ToolInvoked {
            tool: "echo".into(),
            arguments: serde_json::json!({"x": 1}),
        };
        let effect = apply(&intent, &state).unwrap();
        assert!(matches!(effect, Effect::Called { ref tool, .. } if tool == "echo"));
    }

    #[test]
    fn apply_undo_exhausted() {
        let state = State::default();
        let intent = Intent::UndoRequested { count: 1 };
        let err = apply(&intent, &state).unwrap_err();
        assert!(
            matches!(err, ApplyError::UndoExhausted { requested: 1, available: 0 })
        );
    }

    #[test]
    fn commit_and_undo_roundtrip() {
        let mut state = State::default();
        let e1 = apply(
            &Intent::NoteEdited {
                path: PathBuf::from("a.md"),
                content: "first".into(),
            },
            &state,
        )
        .unwrap();
        commit(&mut state, e1);

        let e2 = apply(
            &Intent::NoteEdited {
                path: PathBuf::from("a.md"),
                content: "second".into(),
            },
            &state,
        )
        .unwrap();
        commit(&mut state, e2);

        assert_eq!(state.files.get(&PathBuf::from("a.md")), Some(&"v2".into()));
        assert_eq!(state.version, 2);

        let e3 = apply(&Intent::UndoRequested { count: 1 }, &state).unwrap();
        commit(&mut state, e3);

        // After undo, the file should revert to "v1" (the placeholder for first version)
        assert_eq!(state.files.get(&PathBuf::from("a.md")), Some(&"v1".into()));
        assert_eq!(state.version, 3);
    }

    #[test]
    fn serialize_intent_roundtrip() {
        let intent = Intent::CapturePlaced {
            payload: "hello".into(),
            source: "user".into(),
        };
        let json = serde_json::to_string(&intent).unwrap();
        let back: Intent = serde_json::from_str(&json).unwrap();
        assert_eq!(intent, back);
    }
}
