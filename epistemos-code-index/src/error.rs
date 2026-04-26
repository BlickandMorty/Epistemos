//! Typed error surface for the workspace code indexer.
//!
//! The C ABI returns these as small negative integers so the Swift
//! caller can pattern-match. Discriminants are CONTRACTS — they
//! mirror epistemos-shadow's W8.1 numbering for cross-crate parity.

use thiserror::Error;

#[derive(Debug, Error)]
pub enum CodeIndexError {
    /// Malformed input — bad JSON, empty path, unknown kind. -1.
    #[error("invalid input: {detail}")]
    InvalidInput { detail: String },

    /// Document not found. -2.
    #[error("document not found: {vault_relative_path}")]
    NotFound { vault_relative_path: String },

    /// IO failure (sidecar read/write, mmap, etc.). -3.
    #[error("io error: {detail}")]
    Io { detail: String },

    /// Backend (Model2Vec / usearch / tree-sitter) failure. -4.
    #[error("backend error: {detail}")]
    Backend { detail: String },

    /// Caught a Rust panic at the FFI boundary. -99.
    #[error("rust panic at FFI boundary")]
    Panic,
}

impl CodeIndexError {
    pub fn as_code(&self) -> i32 {
        match self {
            CodeIndexError::InvalidInput { .. } => -1,
            CodeIndexError::NotFound { .. } => -2,
            CodeIndexError::Io { .. } => -3,
            CodeIndexError::Backend { .. } => -4,
            CodeIndexError::Panic => -99,
        }
    }
}
