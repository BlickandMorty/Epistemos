//! W8.4.d stub — tantivy BM25 wrapper.
//!
//! Filled in by the W8.4.d commit. Schema mirrors
//! agent_core/src/storage/vault.rs:133-137:
//!
//!   doc_id  STRING | STORED
//!   domain  STRING | STORED
//!   title   TEXT   | STORED
//!   body    TEXT   | STORED
//!
//! V1 uses `RamDirectory` (in-memory only); W8.4.f adds
//! `MmapDirectory` persistence at
//! `<vault>/.epistemos/shadow/tantivy/` matching vault.rs:139-142.
//!
//! Reader uses `ReloadPolicy::OnCommitWithDelay` (mirrors vault.rs:144-147).
//! Each insert/remove commits immediately for V1; W8.4.f batches.
//!
//! Defensive query parsing — the QueryParser errors on operator-only
//! / unicode-corner inputs (`"!@#"`, `":"`, `"AND"`); the wrapper
//! catches `QueryParserError` and returns Ok(empty) so the Swift
//! caller never sees `-1 InvalidInput` for what looks like normal
//! typing.

#![allow(dead_code)]
