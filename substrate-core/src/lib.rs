//! # substrate-core
//!
//! Canonical entity storage for Epistemos. Rust owns the truth.
//!
//! ## Design (per docs/UNIFIED_SUBSTRATE_RESEARCH.md Sprint 1)
//!
//! - `EntityID` is a `slotmap::KeyData` round-tripped as `u64` for C ABI.
//!   Generational → reuse-safe, dense → cache-friendly, zero pointer chasing.
//! - Mutations go through `AppAction`. All state change is a replayable event.
//! - Event log is append-only, persisted to SQLite. Undo = pop-and-replay.
//! - Zero-copy on the hot path: `slotmap::DenseSlotMap` stores entity data
//!   contiguously; callers read by key, no allocation.
//!
//! ## Law 2 (UNIFIED_SUBSTRATE_RESEARCH)
//! This is a NEW crate. Old Swift/Rust identity code keeps running. Migration
//! happens one entity type at a time.

pub mod action;
pub mod entity;
pub mod event_log;
pub mod ffi;
pub mod store;

pub use action::{ActionError, AppAction, EntityKind};
pub use entity::{EntityData, EntityId};
pub use event_log::{EventLog, EventLogError};
pub use store::{Store, StoreError};
