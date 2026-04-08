//! `AppAction` — the one and only mutation grammar.
//!
//! Every state change is an action. The store applies actions and appends them
//! to the event log. Undo = reverse-apply. Redo = re-apply.
//!
//! Per UNIFIED_SUBSTRATE_RESEARCH.md: "This is where 'one truth' becomes real."

use serde::{Deserialize, Serialize};
use thiserror::Error;

use crate::entity::EntityId;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[repr(u8)]
pub enum EntityKind {
    Note = 0,
    Folder = 1,
    Chat = 2,
    Idea = 3,
    Tag = 4,
}

/// Canonical mutations. Serialized to the event log verbatim.
///
/// Each variant carries *enough to replay* and *enough to reverse*. For
/// example, `UpdateContent` records the old body so undo is a pure log op.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum AppAction {
    CreateNote {
        id: EntityId,
        title: String,
        body: String,
        at: i64,
    },
    RenameNote {
        id: EntityId,
        old: String,
        new: String,
        at: i64,
    },
    UpdateContent {
        id: EntityId,
        old: String,
        new: String,
        at: i64,
    },
    DeleteNote {
        id: EntityId,
        /// Snapshot for undo.
        snapshot: crate::entity::EntityData,
        at: i64,
    },
    /// Link two notes (directed edge). Stored as an action; link resolution
    /// lives in a follow-up sprint per UNIFIED_SUBSTRATE_RESEARCH.md.
    LinkNotes {
        from: EntityId,
        to: EntityId,
        at: i64,
    },
}

impl AppAction {
    /// Monotonic timestamp carried by the action. Used for ordering.
    pub fn timestamp(&self) -> i64 {
        match self {
            AppAction::CreateNote { at, .. }
            | AppAction::RenameNote { at, .. }
            | AppAction::UpdateContent { at, .. }
            | AppAction::DeleteNote { at, .. }
            | AppAction::LinkNotes { at, .. } => *at,
        }
    }

    /// The entity this action targets. Used for per-entity replay.
    pub fn target(&self) -> EntityId {
        match self {
            AppAction::CreateNote { id, .. }
            | AppAction::RenameNote { id, .. }
            | AppAction::UpdateContent { id, .. }
            | AppAction::DeleteNote { id, .. } => *id,
            AppAction::LinkNotes { from, .. } => *from,
        }
    }
}

#[derive(Debug, Error)]
pub enum ActionError {
    #[error("entity not found: {0:?}")]
    NotFound(EntityId),
    #[error("stale precondition: expected {expected:?}, found {actual:?}")]
    StalePrecondition { expected: String, actual: String },
    #[error("wrong entity kind: action targets {expected:?}, entity is {actual:?}")]
    WrongKind { expected: EntityKind, actual: EntityKind },
}
