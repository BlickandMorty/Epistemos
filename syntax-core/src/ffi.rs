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

/// Resolve a `kind_id` (assigned by the per-document `TokenRegistry`)
/// back into the original capture name (e.g. `"comment"`, `"string"`,
/// `"function.def"`).
///
/// The capture name is written to `out_buf` as UTF-8 *without* a
/// null terminator. The caller MUST use the returned length, not
/// `strlen`.
///
/// # Safety
/// `doc` must point at a valid `SyntaxDocument` (or be null).
/// `out_buf` must point at `out_buf_cap` writable bytes (or be null
/// if `out_buf_cap == 0`).
///
/// # Returns
/// Number of bytes written. `0` on any of:
///   - null doc / null out_buf / zero capacity
///   - `kind_id` not registered for this document
///   - capture name longer than `out_buf_cap` (truncated to fit
///     would silently corrupt the read; we return 0 and let the
///     caller realloc)
///
/// `kind_id == 0` is the "unknown" sentinel and intentionally
/// returns the literal name `"unknown"` so the Swift side can tell
/// it apart from a missing registration.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn syntax_document_kind_name(
    doc: *const SyntaxDocument,
    kind_id: u16,
    out_buf: *mut u8,
    out_buf_cap: u32,
) -> u32 {
    ffi_catch!("syntax_document_kind_name", 0, {
        if doc.is_null() || out_buf.is_null() || out_buf_cap == 0 {
            return 0;
        }
        // SAFETY: caller guarantees `doc` points at a valid SyntaxDocument.
        let doc = unsafe { &*doc };
        let name = match doc.registry().name(kind_id) {
            Some(n) => n,
            None => return 0,
        };
        let bytes = name.as_bytes();
        if bytes.len() > out_buf_cap as usize {
            // Refuse to truncate — partial UTF-8 reads on the Swift
            // side would silently produce the wrong capture name.
            return 0;
        }
        // SAFETY: out_buf has at least bytes.len() <= out_buf_cap writable bytes.
        unsafe {
            std::ptr::copy_nonoverlapping(bytes.as_ptr(), out_buf, bytes.len());
        }
        bytes.len() as u32
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

    // syntax_document_kind_name — round-trip a populated registry.

    #[test]
    fn kind_name_resolves_after_tokens_for_viewport() {
        // Parse a Rust source that triggers comment / string / function
        // captures, drain it through tokens_for_viewport (the call that
        // actually populates the per-document TokenRegistry), then
        // assert that every non-zero kind_id resolves back to a name.
        let lang = CString::new("rust").unwrap();
        let src = "// hi\nfn add(a: i32, b: i32) -> i32 { let _x = \"s\"; a + b }";
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
            64
        ];
        let count = unsafe {
            syntax_document_tokens_for_viewport(
                doc,
                lang.as_ptr(),
                0,
                src.len() as u64,
                buf.as_mut_ptr(),
                64,
            )
        };
        assert!(count > 0);

        // Resolve every produced kind_id; collect the unique names.
        let mut name_buf = [0u8; 64];
        let mut seen: std::collections::BTreeSet<String> = std::collections::BTreeSet::new();
        for tok in &buf[..count as usize] {
            if tok.kind_id == 0 { continue; }
            let n = unsafe {
                syntax_document_kind_name(doc, tok.kind_id, name_buf.as_mut_ptr(), 64)
            };
            assert!(n > 0, "every produced kind_id MUST resolve to a name");
            let s = std::str::from_utf8(&name_buf[..n as usize]).unwrap().to_owned();
            seen.insert(s);
        }
        // We expect at least `comment` and `string` from the source above.
        assert!(seen.contains("comment"), "registry should hold 'comment'; saw {seen:?}");
        assert!(seen.contains("string"), "registry should hold 'string'; saw {seen:?}");

        // Sentinel: id 0 is always the "unknown" name (per TokenRegistry::new).
        let n0 = unsafe { syntax_document_kind_name(doc, 0, name_buf.as_mut_ptr(), 64) };
        assert!(n0 > 0);
        let s0 = std::str::from_utf8(&name_buf[..n0 as usize]).unwrap();
        assert_eq!(s0, "unknown");

        unsafe { syntax_document_free(doc) };
    }

    #[test]
    fn kind_name_unknown_id_returns_zero() {
        let lang = CString::new("rust").unwrap();
        let src = "fn main() {}";
        let doc = unsafe {
            syntax_document_create(1, lang.as_ptr(), src.as_ptr() as *const c_char, src.len() as u32)
        };
        assert!(!doc.is_null());

        let mut name_buf = [0u8; 32];
        let n = unsafe {
            syntax_document_kind_name(doc, u16::MAX, name_buf.as_mut_ptr(), 32)
        };
        assert_eq!(n, 0, "unregistered kind_id MUST return 0");

        unsafe { syntax_document_free(doc) };
    }

    #[test]
    fn kind_name_truncation_returns_zero_not_partial() {
        // If the caller's buffer is smaller than the name, we must NOT
        // write a truncated UTF-8 string — Swift's String(bytes:encoding:)
        // would silently produce the wrong capture.
        let lang = CString::new("rust").unwrap();
        let src = "// hi";
        let doc = unsafe {
            syntax_document_create(1, lang.as_ptr(), src.as_ptr() as *const c_char, src.len() as u32)
        };
        assert!(!doc.is_null());

        // Force the registry to hold "unknown" (always there) — its name
        // is 7 bytes. Pass a 3-byte buffer.
        let mut name_buf = [0u8; 3];
        let n = unsafe {
            syntax_document_kind_name(doc, 0, name_buf.as_mut_ptr(), 3)
        };
        assert_eq!(n, 0, "MUST refuse to truncate; caller realloc and retry");

        unsafe { syntax_document_free(doc) };
    }
}
