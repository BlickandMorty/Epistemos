//! Canonical entity store.
//!
//! `DenseSlotMap` stores entity data contiguously — reads are pointer-bump,
//! writes don't invalidate other handles. This is the closest thing to an ECS
//! component array we need for Sprint 1.
//!
//! The store owns the entity data and the event log. All mutations flow
//! through `apply(action)`, which is the only way state changes. Undo/redo
//! walks the log and replays.

use parking_lot::RwLock;
use slotmap::DenseSlotMap;
use thiserror::Error;

use crate::action::{ActionError, AppAction};
use crate::entity::{EntityData, EntityId, EntityKey};

/// Thread-safe canonical store. Single writer lock; reads are fast.
pub struct Store {
    inner: RwLock<Inner>,
    /// Action log (in-memory mirror of the persistent log).
    log: RwLock<Vec<AppAction>>,
    /// Index into `log` for the next undo target. `cursor == log.len()` means
    /// nothing to undo. `cursor < log.len()` means redos are available.
    cursor: RwLock<usize>,
}

struct Inner {
    entities: DenseSlotMap<EntityKey, EntityData>,
}

#[derive(Debug, Error)]
pub enum StoreError {
    #[error(transparent)]
    Action(#[from] ActionError),
    #[error("nothing to undo")]
    NothingToUndo,
    #[error("nothing to redo")]
    NothingToRedo,
}

impl Store {
    pub fn new() -> Self {
        Self {
            inner: RwLock::new(Inner {
                entities: DenseSlotMap::with_key(),
            }),
            log: RwLock::new(Vec::new()),
            cursor: RwLock::new(0),
        }
    }

    /// Allocate a fresh entity id without committing data.
    ///
    /// Useful when the caller needs the id up-front (e.g. to embed in an
    /// action). The slot holds a placeholder until `apply` fills it.
    pub fn reserve_id(&self) -> EntityId {
        let mut inner = self.inner.write();
        let key = inner.entities.insert(EntityData {
            kind: crate::action::EntityKind::Note,
            title: String::new(),
            body: String::new(),
            created_at: 0,
            updated_at: 0,
        });
        EntityId::from_key(key)
    }

    /// Read an entity. Returns `None` if the id is stale (generational miss)
    /// or never existed.
    pub fn get(&self, id: EntityId) -> Option<EntityData> {
        let inner = self.inner.read();
        inner.entities.get(id.to_key()).cloned()
    }

    /// Number of live entities.
    pub fn len(&self) -> usize {
        self.inner.read().entities.len()
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    /// Apply an action: mutate state, append to log, truncate redo branch.
    ///
    /// This is the **only** mutation path. If the cursor is in the middle of
    /// the log (some actions undone but not yet redone), the redo tail is
    /// discarded — standard linear undo model.
    pub fn apply(&self, action: AppAction) -> Result<(), StoreError> {
        self.apply_forward(&action)?;
        let mut log = self.log.write();
        let mut cursor = self.cursor.write();
        log.truncate(*cursor);
        log.push(action);
        *cursor = log.len();
        Ok(())
    }

    /// Reverse the most recently applied action.
    pub fn undo(&self) -> Result<AppAction, StoreError> {
        let mut cursor = self.cursor.write();
        if *cursor == 0 {
            return Err(StoreError::NothingToUndo);
        }
        let log = self.log.read();
        let action = log[*cursor - 1].clone();
        self.apply_backward(&action)?;
        *cursor -= 1;
        Ok(action)
    }

    /// Re-apply the next undone action.
    pub fn redo(&self) -> Result<AppAction, StoreError> {
        let mut cursor = self.cursor.write();
        let log = self.log.read();
        if *cursor >= log.len() {
            return Err(StoreError::NothingToRedo);
        }
        let action = log[*cursor].clone();
        self.apply_forward(&action)?;
        *cursor += 1;
        Ok(action)
    }

    /// Rebuild the store from a sequence of actions. Used on startup to
    /// replay the persistent event log.
    pub fn replay(&self, actions: impl IntoIterator<Item = AppAction>) -> Result<(), StoreError> {
        for action in actions {
            self.apply_forward(&action)?;
            let mut log = self.log.write();
            log.push(action);
            let mut cursor = self.cursor.write();
            *cursor = log.len();
        }
        Ok(())
    }

    /// Snapshot of the log for persistence.
    pub fn log_snapshot(&self) -> Vec<AppAction> {
        self.log.read().clone()
    }

    // ── internals ────────────────────────────────────────────────────────

    fn apply_forward(&self, action: &AppAction) -> Result<(), ActionError> {
        let mut inner = self.inner.write();
        match action {
            AppAction::CreateNote { id, title, body, at } => {
                // Respect reserved slot if present; otherwise insert fresh at this key.
                let key = id.to_key();
                let data = EntityData::new_note(title.clone(), body.clone(), *at);
                if let Some(slot) = inner.entities.get_mut(key) {
                    *slot = data;
                } else {
                    // Key doesn't exist (e.g. replay from log on empty store).
                    // Insert and remap — callers should prefer reserve_id+apply.
                    inner.entities.insert(data);
                }
            }
            AppAction::RenameNote { id, old, new, at } => {
                let entity = inner
                    .entities
                    .get_mut(id.to_key())
                    .ok_or(ActionError::NotFound(*id))?;
                if entity.title != *old {
                    return Err(ActionError::StalePrecondition {
                        expected: old.clone(),
                        actual: entity.title.clone(),
                    });
                }
                entity.title = new.clone();
                entity.updated_at = *at;
            }
            AppAction::UpdateContent { id, old, new, at } => {
                let entity = inner
                    .entities
                    .get_mut(id.to_key())
                    .ok_or(ActionError::NotFound(*id))?;
                if entity.body != *old {
                    return Err(ActionError::StalePrecondition {
                        expected: old.clone(),
                        actual: entity.body.clone(),
                    });
                }
                entity.body = new.clone();
                entity.updated_at = *at;
            }
            AppAction::DeleteNote { id, .. } => {
                inner
                    .entities
                    .remove(id.to_key())
                    .ok_or(ActionError::NotFound(*id))?;
            }
            AppAction::LinkNotes { from, to, .. } => {
                // Link storage arrives in Sprint 2+ per UNIFIED_SUBSTRATE_RESEARCH.md.
                // For now we verify both endpoints exist and record the action
                // in the log; the link relation is reconstructable from replay.
                if inner.entities.get(from.to_key()).is_none() {
                    return Err(ActionError::NotFound(*from));
                }
                if inner.entities.get(to.to_key()).is_none() {
                    return Err(ActionError::NotFound(*to));
                }
            }
        }
        Ok(())
    }

    fn apply_backward(&self, action: &AppAction) -> Result<(), ActionError> {
        let mut inner = self.inner.write();
        match action {
            AppAction::CreateNote { id, .. } => {
                inner
                    .entities
                    .remove(id.to_key())
                    .ok_or(ActionError::NotFound(*id))?;
            }
            AppAction::RenameNote { id, old, at, .. } => {
                let entity = inner
                    .entities
                    .get_mut(id.to_key())
                    .ok_or(ActionError::NotFound(*id))?;
                entity.title = old.clone();
                entity.updated_at = *at;
            }
            AppAction::UpdateContent { id, old, at, .. } => {
                let entity = inner
                    .entities
                    .get_mut(id.to_key())
                    .ok_or(ActionError::NotFound(*id))?;
                entity.body = old.clone();
                entity.updated_at = *at;
            }
            AppAction::DeleteNote { snapshot, .. } => {
                // Restore into a fresh slot. Note: this mints a new EntityId.
                // Callers relying on id-stability across undo must track the
                // remapping via the returned action.
                inner.entities.insert(snapshot.clone());
            }
            AppAction::LinkNotes { .. } => {
                // No-op: link is log-only until Sprint 2+ adds link storage.
            }
        }
        Ok(())
    }
}

impl Default for Store {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::action::EntityKind;

    #[test]
    fn create_and_read_roundtrip() {
        let store = Store::new();
        let id = store.reserve_id();
        store
            .apply(AppAction::CreateNote {
                id,
                title: "Hello".into(),
                body: "World".into(),
                at: 1000,
            })
            .unwrap();

        let data = store.get(id).unwrap();
        assert_eq!(data.title, "Hello");
        assert_eq!(data.body, "World");
        assert_eq!(data.kind, EntityKind::Note);
        assert_eq!(store.len(), 1);
    }

    #[test]
    fn stale_handle_returns_none() {
        let store = Store::new();
        let id = store.reserve_id();
        store
            .apply(AppAction::CreateNote {
                id,
                title: "x".into(),
                body: "x".into(),
                at: 1,
            })
            .unwrap();
        store
            .apply(AppAction::DeleteNote {
                id,
                snapshot: store.get(id).unwrap(),
                at: 2,
            })
            .unwrap();
        assert!(store.get(id).is_none());
    }

    #[test]
    fn undo_redo_title() {
        let store = Store::new();
        let id = store.reserve_id();
        store
            .apply(AppAction::CreateNote {
                id,
                title: "A".into(),
                body: "".into(),
                at: 1,
            })
            .unwrap();
        store
            .apply(AppAction::RenameNote {
                id,
                old: "A".into(),
                new: "B".into(),
                at: 2,
            })
            .unwrap();
        assert_eq!(store.get(id).unwrap().title, "B");

        store.undo().unwrap();
        assert_eq!(store.get(id).unwrap().title, "A");

        store.redo().unwrap();
        assert_eq!(store.get(id).unwrap().title, "B");
    }

    #[test]
    fn stale_precondition_rejected() {
        let store = Store::new();
        let id = store.reserve_id();
        store
            .apply(AppAction::CreateNote {
                id,
                title: "A".into(),
                body: "".into(),
                at: 1,
            })
            .unwrap();
        let err = store
            .apply(AppAction::RenameNote {
                id,
                old: "WRONG".into(),
                new: "B".into(),
                at: 2,
            })
            .unwrap_err();
        assert!(matches!(err, StoreError::Action(ActionError::StalePrecondition { .. })));
    }

    #[test]
    fn new_apply_truncates_redo_branch() {
        let store = Store::new();
        let id = store.reserve_id();
        store
            .apply(AppAction::CreateNote {
                id,
                title: "A".into(),
                body: "".into(),
                at: 1,
            })
            .unwrap();
        store
            .apply(AppAction::RenameNote {
                id,
                old: "A".into(),
                new: "B".into(),
                at: 2,
            })
            .unwrap();
        store.undo().unwrap();
        // Now a new action should erase the redo tail.
        store
            .apply(AppAction::RenameNote {
                id,
                old: "A".into(),
                new: "C".into(),
                at: 3,
            })
            .unwrap();
        assert!(store.redo().is_err());
        assert_eq!(store.get(id).unwrap().title, "C");
    }
}
