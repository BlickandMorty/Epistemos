//! Core traits shared across the Epistenos workspace.

/// Trait for types that can produce a Blake3 hash of their canonical form.
pub trait CanonicalHash {
    fn canonical_hash(&self) -> [u8; 32];
}

/// Trait for event-sourced append-only logs.
pub trait EventLog<E> {
    fn append(&mut self, event: E) -> Result<[u8; 32], crate::types::EventLogError>;
    fn len(&self) -> usize;
    fn is_empty(&self) -> bool;
}

#[derive(thiserror::Error, Debug)]
pub enum EventLogError {
    #[error("log full")]
    LogFull,
    #[error("serialization failed: {0}")]
    Serde(String),
}
