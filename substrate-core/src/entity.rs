//! Entity identity + data.
//!
//! `EntityId` wraps `slotmap::KeyData`. It is `#[repr(transparent)]` over `u64`
//! so it can cross the C ABI without conversion cost.

use serde::{Deserialize, Serialize};
use slotmap::{KeyData, new_key_type};

new_key_type! {
    /// Internal slotmap key. Not exposed — use `EntityId`.
    pub struct EntityKey;
}

/// Public entity handle. `u64` wire format = `KeyData::as_ffi()`.
///
/// Generational: a deleted entity's index can be reused, but the generation
/// counter bumps, so stale handles return `None` on lookup.
#[repr(transparent)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct EntityId(pub u64);

impl EntityId {
    pub const NIL: EntityId = EntityId(0);

    #[inline]
    pub fn from_key(key: EntityKey) -> Self {
        Self(key.0.as_ffi())
    }

    #[inline]
    pub fn to_key(self) -> EntityKey {
        EntityKey(KeyData::from_ffi(self.0))
    }

    #[inline]
    pub fn is_nil(self) -> bool {
        self.0 == 0
    }
}

/// Entity payload. Minimal for Sprint 1 — Note only.
/// Additional kinds (Chat, Idea, Folder, Link, Tag) land in Sprint 2+.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct EntityData {
    pub kind: crate::action::EntityKind,
    pub title: String,
    pub body: String,
    /// Seconds since UNIX epoch. Rust-owned; Swift reads through projection.
    pub created_at: i64,
    pub updated_at: i64,
}

impl EntityData {
    pub fn new_note(title: impl Into<String>, body: impl Into<String>, now: i64) -> Self {
        Self {
            kind: crate::action::EntityKind::Note,
            title: title.into(),
            body: body.into(),
            created_at: now,
            updated_at: now,
        }
    }
}
