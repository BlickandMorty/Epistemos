use std::ffi::{c_char, CStr};
use std::panic::catch_unwind;

use crate::highlight::tokens_for_byte_range;
use crate::languages::language_for_name;
use crate::{SyntaxDocument, SyntaxDocumentHandle, SyntaxEditDelta, SyntaxSnapshotStats, SyntaxTokenSpan};

macro_rules! ffi_catch {
    ($name:expr, $default:expr, $body:expr) => {
        match catch_unwind(std::panic::AssertUnwindSafe(|| $body)) {
            Ok(v) => v,
            Err(_) => {
                eprintln!("syntax-core FFI panic in {}", $name);
                $default
            }
        }
    };
}

/// Create a new `SyntaxDocument` for the given language and source text.
/// Returns a heap-allocated pointer, or null if the language is unknown.
///
/// # Safety
/// `language` must be a valid null-terminated C string.
/// `source` must point to `source_len` valid UTF-8 bytes.
/// Caller must eventually call `syntax_document_free` on the returned pointer.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn syntax_document_create(
    doc_id: u64,
    language: *const c_char,
    source: *const c_char,
    source_len: u32,
) -> *mut SyntaxDocument {
    ffi_catch!("syntax_document_create", std::ptr::null_mut(), {
        if language.is_null() || source.is_null() {
            return std::ptr::null_mut();
        }

        // SAFETY: caller guarantees `language` is a valid null-terminated C string.
        let lang_str = unsafe { CStr::from_ptr(language) };
        let lang_str = match lang_str.to_str() {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        };

        let lang = match language_for_name(lang_str) {
            Some(l) => l,
            None => return std::ptr::null_mut(),
        };

        // SAFETY: caller guarantees `source` points to `source_len` valid UTF-8 bytes.
        let source_slice =
            unsafe { std::slice::from_raw_parts(source as *const u8, source_len as usize) };
        let source_str = match std::str::from_utf8(source_slice) {
            Ok(s) => s,
            Err(_) => return std::ptr::null_mut(),
        };

        let doc = SyntaxDocument::new(doc_id, &lang, source_str);
        Box::into_raw(Box::new(doc))
    })
}

/// Free a `SyntaxDocument` previously created by `syntax_document_create`.
///
/// # Safety
/// `doc` must be a valid pointer returned by `syntax_document_create`, or null.
/// After this call, the pointer is dangling.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn syntax_document_free(doc: *mut SyntaxDocument) {
    ffi_catch!("syntax_document_free", (), {
        if !doc.is_null() {
            // SAFETY: caller guarantees `doc` was created by syntax_document_create.
            unsafe {
                drop(Box::from_raw(doc));
            }
        }
    })
}

/// Apply an edit to the document and trigger incremental reparse.
///
/// # Safety
/// `doc` must be a valid, non-null pointer from `syntax_document_create`.
/// `new_text` must point to `new_text_len` valid UTF-8 bytes.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn syntax_document_edit(
    doc: *mut SyntaxDocument,
    byte_start: u64,
    old_len: u64,
    new_text: *const c_char,
    new_text_len: u32,
) -> SyntaxEditDelta {
    let zero = SyntaxEditDelta {
        doc_id: 0,
        from_generation: 0,
        to_generation: 0,
        byte_offset: 0,
        old_len: 0,
        new_len: 0,
    };
    ffi_catch!("syntax_document_edit", zero, {
        if doc.is_null() || new_text.is_null() {
            return zero;
        }

        // SAFETY: caller guarantees `new_text` points to `new_text_len` valid UTF-8 bytes.
        let text_slice =
            unsafe { std::slice::from_raw_parts(new_text as *const u8, new_text_len as usize) };
        let text_str = match std::str::from_utf8(text_slice) {
            Ok(s) => s,
            Err(_) => return zero,
        };

        // SAFETY: caller guarantees `doc` is a valid pointer.
        let doc = unsafe { &mut *doc };
        doc.edit(byte_start as usize, old_len as usize, text_str)
    })
}

/// Get a snapshot of the document's current stats.
///
/// # Safety
/// `doc` must be a valid, non-null pointer from `syntax_document_create`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn syntax_document_stats(doc: *const SyntaxDocument) -> SyntaxSnapshotStats {
    let zero = SyntaxSnapshotStats {
        doc_id: 0,
        generation: 0,
        node_count: 0,
        error_count: 0,
        parse_time_us: 0,
    };
    ffi_catch!("syntax_document_stats", zero, {
        if doc.is_null() {
            return zero;
        }
        // SAFETY: caller guarantees `doc` is a valid pointer.
        let doc = unsafe { &*doc };
        doc.stats()
    })
}

/// Get the document's current handle (doc_id + generation).
///
/// # Safety
/// `doc` must be a valid, non-null pointer from `syntax_document_create`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn syntax_document_handle(
    doc: *const SyntaxDocument,
) -> SyntaxDocumentHandle {
    let zero = SyntaxDocumentHandle {
        doc_id: 0,
        generation: 0,
    };
    ffi_catch!("syntax_document_handle", zero, {
        if doc.is_null() {
            return zero;
        }
        // SAFETY: caller guarantees `doc` is a valid pointer.
        let doc = unsafe { &*doc };
        doc.handle()
    })
}

/// Get the document's current generation counter.
///
/// # Safety
/// `doc` must be a valid, non-null pointer from `syntax_document_create`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn syntax_document_generation(doc: *const SyntaxDocument) -> u64 {
    ffi_catch!("syntax_document_generation", 0, {
        if doc.is_null() {
            return 0;
        }
        // SAFETY: caller guarantees `doc` is a valid pointer.
        let doc = unsafe { &*doc };
        doc.generation()
    })
}

/// Produce syntax tokens for the visible viewport range.
///
/// Tokens are written into the caller-provided `out_buf` (up to `max_tokens`).
/// Returns the number of tokens written. UTF-16 offsets in the tokens
/// are document-global (not relative to the viewport).
///
/// `language` is needed because the highlight query depends on the grammar.
///
/// # Safety
/// - `doc` must be a valid, non-null pointer from `syntax_document_create`.
/// - `language` must be a valid null-terminated C string.
/// - `out_buf` must point to at least `max_tokens` `SyntaxTokenSpan` elements.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn syntax_document_tokens_for_viewport(
    doc: *mut SyntaxDocument,
    language: *const c_char,
    byte_start: u64,
    byte_end: u64,
    out_buf: *mut SyntaxTokenSpan,
    max_tokens: u32,
) -> u32 {
    ffi_catch!("syntax_document_tokens_for_viewport", 0, {
        if doc.is_null() || language.is_null() || out_buf.is_null() || max_tokens == 0 {
            return 0;
        }

        // SAFETY: caller guarantees `language` is a valid null-terminated C string.
        let lang_str = unsafe { CStr::from_ptr(language) };
        let lang_str = match lang_str.to_str() {
            Ok(s) => s,
            Err(_) => return 0,
        };

        let lang = match language_for_name(lang_str) {
            Some(l) => l,
            None => return 0,
        };

        // SAFETY: caller guarantees `doc` is a valid pointer.
        let doc = unsafe { &mut *doc };

        let tree = match doc.tree() {
            Some(t) => t,
            None => return 0,
        };

        // SAFETY: caller guarantees `out_buf` points to `max_tokens` elements.
        let out_slice =
            unsafe { std::slice::from_raw_parts_mut(out_buf, max_tokens as usize) };

        // Clone tree and rope snapshot to avoid overlapping borrows:
        // tokens_for_byte_range needs &Rope (immutable) and &mut TokenRegistry.
        let tree_clone = tree.clone();
        let rope_clone = doc.rope().clone();

        tokens_for_byte_range(
            &tree_clone,
            &lang,
            &rope_clone,
            doc.registry_mut(),
            byte_start as usize,
            byte_end as usize,
            out_slice,
        ) as u32
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::CString;

    #[test]
    fn create_and_free_document() {
        let lang = CString::new("rust").unwrap();
        let src = "fn main() {}";
        let doc = unsafe {
            syntax_document_create(1, lang.as_ptr(), src.as_ptr() as *const c_char, src.len() as u32)
        };
        assert!(!doc.is_null());
        let handle = unsafe { syntax_document_handle(doc) };
        assert_eq!(handle.doc_id, 1);
        unsafe { syntax_document_free(doc) };
    }

    #[test]
    fn null_language_returns_null() {
        let src = "fn main() {}";
        let doc = unsafe {
            syntax_document_create(1, std::ptr::null(), src.as_ptr() as *const c_char, src.len() as u32)
        };
        assert!(doc.is_null());
    }

    #[test]
    fn unknown_language_returns_null() {
        let lang = CString::new("cobol").unwrap();
        let src = "IDENTIFICATION DIVISION.";
        let doc = unsafe {
            syntax_document_create(1, lang.as_ptr(), src.as_ptr() as *const c_char, src.len() as u32)
        };
        assert!(doc.is_null());
    }

    #[test]
    fn edit_and_check_generation() {
        let lang = CString::new("rust").unwrap();
        let src = "fn main() { let x = 42; }";
        let doc = unsafe {
            syntax_document_create(1, lang.as_ptr(), src.as_ptr() as *const c_char, src.len() as u32)
        };
        assert!(!doc.is_null());

        let gen_before = unsafe { syntax_document_generation(doc) };
        let new_text = "99";
        let delta = unsafe {
            syntax_document_edit(
                doc,
                20,
                2,
                new_text.as_ptr() as *const c_char,
                new_text.len() as u32,
            )
        };
        assert!(delta.to_generation > gen_before);

        let gen_after = unsafe { syntax_document_generation(doc) };
        assert_eq!(gen_after, delta.to_generation);
        unsafe { syntax_document_free(doc) };
    }

    #[test]
    fn viewport_tokens_via_ffi() {
        let lang = CString::new("rust").unwrap();
        let src = "fn main() { let x = 42; }";
        let doc = unsafe {
            syntax_document_create(1, lang.as_ptr(), src.as_ptr() as *const c_char, src.len() as u32)
        };
        assert!(!doc.is_null());

        let mut buf = vec![
            SyntaxTokenSpan {
                utf16_start: 0,
                utf16_len: 0,
                kind_id: 0,
                flags: 0,
                _pad: [0; 3],
            };
            128
        ];

        let count = unsafe {
            syntax_document_tokens_for_viewport(
                doc,
                lang.as_ptr(),
                0,
                src.len() as u64,
                buf.as_mut_ptr(),
                128,
            )
        };
        assert!(count > 0, "should produce tokens for Rust source via FFI");
        unsafe { syntax_document_free(doc) };
    }
}
