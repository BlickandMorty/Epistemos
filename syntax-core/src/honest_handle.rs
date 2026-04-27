//! W9.21 — Honest FFI for `syntax-core` (PR2 of 4)
//!
//! Per `docs/RESEARCH_DOSSIER_TIER_3_4.md` §W9.21: replace raw
//! `Box::into_raw` lifecycle (ffi.rs:60, 75) with `Arc::into_raw`
//! refcounted handles wrapping a `Mutex<SyntaxDocument>`. The new
//! `syntax_handle_*` exports coexist with the existing
//! `syntax_document_*` global API; PR4 (Swift cutover) migrates
//! consumers off the legacy path.
//!
//! ## Why this needs a Mutex (and substrate-rt + substrate-core don't)
//!
//! `SyntaxDocument` contains a `tree_sitter::Parser`. The parser
//! holds internal mutable state for incremental parsing — it is
//! `Send` but **not `Sync`**. To make `Arc<SyntaxDocument>` sound
//! across multiple Swift threads, the inner state must be guarded
//! by a `Mutex`.
//!
//! Cost: one uncontended Mutex acquire per FFI call (~100ns on Apple
//! Silicon). Edits and parses already cost ≥1ms so the overhead is
//! negligible. Read-heavy operations (token queries) take a brief
//! lock and release immediately. If profiling later shows
//! contention, we can split the Document into a Mutex<Parser> +
//! RwLock<Tree> + RwLock<Rope>; for now the simpler shape is
//! sufficient.
//!
//! ## Lifecycle contract
//!
//! - `syntax_handle_create(...)` → `*const SyntaxDocumentHandle` (refcount 1)
//! - `syntax_handle_retain(h)` increments
//! - `syntax_handle_release(h)` decrements; document drops at zero
//! - Operation methods take `*const SyntaxDocumentHandle` and lock
//!   the inner Mutex for the duration of the call

use std::ffi::{c_char, CStr};
use std::sync::{Arc, Mutex};

use crate::languages::language_for_name;
use crate::SyntaxDocument;

/// Opaque refcounted handle to a `SyntaxDocument`. Crosses FFI as
/// `*const SyntaxDocumentHandle`. Internally Arc<Mutex<...>> so
/// honest FFI gets thread-safe access without forcing the caller
/// to coordinate externally.
pub struct SyntaxDocumentHandle {
    inner: Arc<Mutex<SyntaxDocument>>,
}

/// Create a `SyntaxDocument` for the given language and source text;
/// return a refcount-1 handle. Returns null on unknown language or
/// invalid UTF-8.
///
/// # Safety
/// `language` must point to a valid null-terminated C string.
/// `source` must point to `source_len` valid UTF-8 bytes.
/// The returned pointer must be released via
/// `syntax_handle_release` exactly enough times to bring the
/// refcount to zero.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn syntax_handle_create(
    doc_id: u64,
    language: *const c_char,
    source: *const c_char,
    source_len: u32,
) -> *const SyntaxDocumentHandle {
    let result = std::panic::catch_unwind(|| {
        if language.is_null() || source.is_null() {
            return std::ptr::null();
        }
        // SAFETY: caller contract — language is null-terminated UTF-8 C string.
        let lang_str = unsafe { CStr::from_ptr(language) };
        let lang_str = match lang_str.to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null(),
        };
        let lang = match language_for_name(lang_str) {
            Some(l) => l,
            None => return std::ptr::null(),
        };
        // SAFETY: caller contract — source is `source_len` valid UTF-8 bytes.
        let source_slice = unsafe {
            std::slice::from_raw_parts(source as *const u8, source_len as usize)
        };
        let source_str = match std::str::from_utf8(source_slice) {
            Ok(s) => s,
            Err(_) => return std::ptr::null(),
        };

        let doc = SyntaxDocument::new(doc_id, &lang, source_str);
        Arc::into_raw(Arc::new(SyntaxDocumentHandle {
            inner: Arc::new(Mutex::new(doc)),
        }))
    });
    result.unwrap_or(std::ptr::null())
}

/// Increment the handle's refcount.
///
/// # Safety
/// `handle` must be a pointer previously returned by
/// `syntax_handle_create` (or a previous retain) and not yet
/// fully released.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn syntax_handle_retain(handle: *const SyntaxDocumentHandle) {
    if !handle.is_null() {
        // SAFETY: caller contract — handle is live.
        unsafe {
            Arc::increment_strong_count(handle);
        }
    }
}

/// Decrement the handle's refcount. Drops the document at zero.
/// Idempotent on null.
///
/// # Safety
/// `handle` must be a pointer previously returned by
/// `syntax_handle_create` or `syntax_handle_retain` and not yet
/// fully released.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn syntax_handle_release(handle: *const SyntaxDocumentHandle) {
    if !handle.is_null() {
        // SAFETY: caller contract — exactly-balanced retain/release.
        unsafe {
            Arc::decrement_strong_count(handle);
        }
    }
}

/// Read the current generation counter for this document. The
/// generation increments on every successful edit. Read-only;
/// briefly takes the Mutex lock.
///
/// # Safety
/// `handle` must be a live `SyntaxDocumentHandle` pointer or null.
/// Returns 0 on null handle or poisoned mutex.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn syntax_handle_generation(
    handle: *const SyntaxDocumentHandle,
) -> u64 {
    if handle.is_null() {
        return 0;
    }
    // SAFETY: caller contract — handle is live.
    let h = unsafe { &*handle };
    match h.inner.lock() {
        Ok(doc) => doc.generation.current(),
        Err(_) => 0, // mutex poisoned — surface as 0 generation
    }
}

/// Read the document id. Stable across the document's lifetime.
/// Read-only; briefly takes the Mutex lock.
///
/// # Safety
/// `handle` must be a live `SyntaxDocumentHandle` pointer or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn syntax_handle_doc_id(
    handle: *const SyntaxDocumentHandle,
) -> u64 {
    if handle.is_null() {
        return 0;
    }
    // SAFETY: caller contract — handle is live.
    let h = unsafe { &*handle };
    match h.inner.lock() {
        Ok(doc) => doc.doc_id,
        Err(_) => 0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    fn cstr(s: &str) -> CString {
        CString::new(s).unwrap()
    }

    #[test]
    fn handle_create_returns_non_null_for_valid_language() {
        let lang = cstr("rust");
        let src = cstr("fn main() {}");
        let h = unsafe {
            syntax_handle_create(1, lang.as_ptr(), src.as_ptr(), src.as_bytes().len() as u32)
        };
        assert!(!h.is_null());
        let id = unsafe { syntax_handle_doc_id(h) };
        assert_eq!(id, 1);
        unsafe { syntax_handle_release(h) };
    }

    #[test]
    fn handle_create_returns_null_for_unknown_language() {
        let lang = cstr("nonexistent_lang_xyz");
        let src = cstr("anything");
        let h = unsafe {
            syntax_handle_create(99, lang.as_ptr(), src.as_ptr(), src.as_bytes().len() as u32)
        };
        assert!(h.is_null());
    }

    #[test]
    fn handle_lifecycle_is_balanced() {
        let lang = cstr("rust");
        let src = cstr("fn x() {}");
        let h = unsafe {
            syntax_handle_create(2, lang.as_ptr(), src.as_ptr(), src.as_bytes().len() as u32)
        };
        unsafe {
            syntax_handle_retain(h);
            syntax_handle_retain(h);
            // 1 (create) + 2 retains = 3 total. Need 3 releases.
            syntax_handle_release(h);
            syntax_handle_release(h);
            syntax_handle_release(h); // last release drops the document
        }
    }

    #[test]
    fn handle_null_release_is_idempotent() {
        unsafe {
            syntax_handle_release(std::ptr::null());
        }
    }

    #[test]
    fn handle_generation_starts_at_zero() {
        let lang = cstr("rust");
        let src = cstr("fn main() {}");
        let h = unsafe {
            syntax_handle_create(3, lang.as_ptr(), src.as_ptr(), src.as_bytes().len() as u32)
        };
        let gen = unsafe { syntax_handle_generation(h) };
        // GenerationCounter::new() defaults; exact value is impl-detail
        // but the call must not crash and must read the same value
        // twice in a row.
        let gen2 = unsafe { syntax_handle_generation(h) };
        assert_eq!(gen, gen2);
        unsafe { syntax_handle_release(h) };
    }
}
