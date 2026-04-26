//! # `epistemos-code-index`
//!
//! Workspace code indexer per Wave 9.7 of the Extended Program Plan
//! (cross-ref `epistemos_code_verdict.md` + brain dump 2026-04-26).
//!
//! Per the layered architecture in `epistemos_code_verdict.md`:
//!   - **Swift** owns the live editing UI surface (TextKit 2 +
//!     SwiftTreeSitter direct C bindings; live syntax stays in Swift
//!     to avoid the UTF-16/UTF-8 cross-FFI mapping stutter)
//!   - **Rust here** owns project-wide background indexing: chunking
//!     source into RAG-friendly windows, computing Model2Vec
//!     embeddings, building a per-vault usearch HNSW index for the
//!     agent-grep API (W9.9), populating each file's
//!     `<vault>/.epcache/code/<sha256-hex-of-vault-rel-path>.epcode.json`
//!     sidecar — bit-for-bit compatible with Swift's
//!     `CodeSidecarPath.sidecarURL(forVaultRoot:vaultRelativePath:)`.
//!     The hash is over the *vault-relative path* (so a file rename
//!     re-binds on the next index pass), NOT the file body. The
//!     reference implementation lives in `sidecar.rs` with a fixture
//!     test pinning the exact hex digest Swift produces.
//!
//! ## W9.7 base scope
//!
//! This commit ships the FFI surface + module skeleton + an
//! in-memory stub indexer so the Swift side can wire the agent-grep
//! API + the AgentGrepService against a real crate today. The actual
//! Model2Vec + usearch + tree-sitter pipeline is the W9.7 follow-up.

pub mod error;
pub mod sidecar;
pub mod state;

pub use error::CodeIndexError;
pub use sidecar::{path_hash, sidecar_path, CACHE_ROOT, CODE_SUBDIR, SIDECAR_SUFFIX};

use std::ffi::{c_char, CStr, CString};
use std::ptr;

// ---------------------------------------------------------------------------
// Public domain types
// ---------------------------------------------------------------------------

/// Document the indexer keeps track of. The Swift CodeFileService
/// (Wave 9.5) writes the canonical sidecar; this crate reads source
/// content + writes derived columns (symbols, embeddings).
#[derive(Clone, Debug, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct CodeIndexDocument {
    /// Vault-relative path, e.g. `"Sources/Foo.swift"`.
    pub vault_relative_path: String,
    /// CodeArtifactKind raw value, e.g. `"swift"`.
    pub kind: String,
    /// Full source text. Pre-trimmed of any BOM by the Swift caller.
    pub body: String,
    /// SHA-256 hex digest the caller computed for `body`. Kept in
    /// the index so a stale cache lookup can detect divergence.
    pub content_hash: String,
}

/// One match returned by the agent-grep API. Mirrors the Swift
/// `AgentGrepHit` shape so the FFI round-trip is field-for-field.
#[derive(Clone, Debug, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct CodeIndexHit {
    pub vault_relative_path: String,
    pub kind: String,
    pub score: f32,
    /// Pre-truncated snippet (~200 chars) centered on the hit.
    pub snippet: String,
    /// Optional symbol name when the hit aligned with an extracted
    /// symbol from the W9.7 follow-up symbol pass.
    pub symbol: Option<String>,
    /// Source signal: "lexical", "dense", "rrf", "stub-substring"
    /// during W9.7 base.
    pub source: String,
}

/// Index counters surfaced to the developer panel + the agent
/// "what do you know" probe.
#[derive(Clone, Debug, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct CodeIndexStats {
    pub document_count: u64,
    /// Per-kind counts encoded as a JSON object so the FFI surface
    /// stays a single string and adding a new kind is a non-breaking
    /// change.
    pub per_kind_counts_json: String,
    pub total_body_bytes: u64,
}

// ---------------------------------------------------------------------------
// C ABI surface
// ---------------------------------------------------------------------------
//
// Pattern matches epistemos-shadow's W8.1 surface:
//   - Each entry wraps the body in std::panic::catch_unwind
//   - JSON-string-in / JSON-string-out for the document type
//   - Returns 0 on success, negative CodeIndexError discriminant on failure
//   - Pointers handed back via *_json must be released via codeindex_free_string

/// Insert (or replace) a document. JSON-encoded `CodeIndexDocument`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn codeindex_upsert_json(doc_json: *const c_char) -> i32 {
    let result = std::panic::catch_unwind(|| {
        if doc_json.is_null() {
            return CodeIndexError::InvalidInput {
                detail: "doc_json was null".into(),
            }
            .as_code();
        }
        let cstr = unsafe { CStr::from_ptr(doc_json) };
        let json = match cstr.to_str() {
            Ok(s) => s,
            Err(_) => return CodeIndexError::InvalidInput {
                detail: "doc_json was not valid UTF-8".into(),
            }
            .as_code(),
        };
        let doc: CodeIndexDocument = match serde_json::from_str(json) {
            Ok(d) => d,
            Err(error) => return CodeIndexError::InvalidInput {
                detail: format!("doc_json failed JSON parse: {error}"),
            }
            .as_code(),
        };
        match state::code_index_state().upsert(doc) {
            Ok(()) => 0,
            Err(error) => error.as_code(),
        }
    });
    result.unwrap_or(CodeIndexError::Panic.as_code())
}

/// Remove a document by vault-relative path. SAFETY: caller contract
/// for valid NUL-terminated UTF-8.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn codeindex_remove_json(vault_relative_path: *const c_char) -> i32 {
    let result = std::panic::catch_unwind(|| {
        if vault_relative_path.is_null() {
            return CodeIndexError::InvalidInput {
                detail: "vault_relative_path was null".into(),
            }
            .as_code();
        }
        let cstr = unsafe { CStr::from_ptr(vault_relative_path) };
        let path = match cstr.to_str() {
            Ok(s) => s,
            Err(_) => return CodeIndexError::InvalidInput {
                detail: "vault_relative_path was not valid UTF-8".into(),
            }
            .as_code(),
        };
        match state::code_index_state().remove(path) {
            Ok(()) => 0,
            Err(error) => error.as_code(),
        }
    });
    result.unwrap_or(CodeIndexError::Panic.as_code())
}

/// Search for code matching the query. Returns a JSON-encoded
/// `Vec<CodeIndexHit>` as a caller-owned C string. Null on error.
///
/// `kind_filter` is the CodeArtifactKind raw value (e.g. "swift") to
/// restrict results, or empty string for "all kinds".
///
/// SAFETY: `query` and `kind_filter` must be NUL-terminated UTF-8.
/// Caller MUST release the returned pointer via `codeindex_free_string`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn codeindex_search_json(
    query: *const c_char,
    kind_filter: *const c_char,
    limit: u32,
) -> *mut c_char {
    let result = std::panic::catch_unwind(|| -> Option<CString> {
        if query.is_null() {
            return None;
        }
        let q = unsafe { CStr::from_ptr(query) }.to_str().ok()?;
        let kind_str = if kind_filter.is_null() {
            ""
        } else {
            unsafe { CStr::from_ptr(kind_filter) }.to_str().unwrap_or("")
        };
        let filter = if kind_str.is_empty() { None } else { Some(kind_str) };
        let hits = state::code_index_state()
            .search(q, filter, limit as usize)
            .ok()?;
        let json = serde_json::to_string(&hits).ok()?;
        CString::new(json).ok()
    });
    match result {
        Ok(Some(cstring)) => cstring.into_raw(),
        _ => ptr::null_mut(),
    }
}

/// Aggregate stats. Returns JSON-encoded `CodeIndexStats` as a
/// caller-owned C string; null on error.
#[unsafe(no_mangle)]
pub extern "C" fn codeindex_stats_json() -> *mut c_char {
    let result = std::panic::catch_unwind(|| -> Option<CString> {
        let stats = state::code_index_state().stats().ok()?;
        let json = serde_json::to_string(&stats).ok()?;
        CString::new(json).ok()
    });
    match result {
        Ok(Some(cstring)) => cstring.into_raw(),
        _ => ptr::null_mut(),
    }
}

/// Free a C string returned by a *_json function.
/// SAFETY: pointer must come from this crate's *_json calls.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn codeindex_free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    let _ = std::panic::catch_unwind(|| {
        let _ = unsafe { CString::from_raw(ptr) };
    });
}
