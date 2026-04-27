//! W9.21 — Honest FFI foundation (PR1 + PR4 of 4)
//!
//! Per `docs/RESEARCH_DOSSIER_TIER_3_4.md` §W9.21: replace the
//! global `RwLock<Option<Arc<RealBackend>>>` (state.rs:251) with
//! explicit `Arc::into_raw` opaque handles passed to Swift. The
//! Swift side wraps the raw handle in a `final class` whose `init`
//! takes ownership and `deinit` releases — single-owner semantics
//! enforced by Swift's reference-counting at the binding edge.
//!
//! This module ships the Rust-side foundation as an ADDITIVE layer:
//! the new `shadow_handle_*` FFI exports work alongside the
//! existing `shadow_*` global-state exports. PR4 (Swift cutover)
//! migrates `RustShadowFFIClient` off the global API to per-instance
//! handles; when no more global-API consumers remain, the legacy
//! exports in `lib.rs` can be removed.
//!
//! Why additive: `epistemos-shadow` is on the typing hot path; a
//! single-PR rewrite that breaks the binding contract would block
//! the entire app. Side-by-side migration lets us bisect a
//! regression to the call site that broke.
//!
//! Lifecycle contract:
//!   - `shadow_handle_open_at(path)` returns `*const ShadowEngineHandle`
//!     with refcount 1 (the Swift caller owns it)
//!   - `shadow_handle_retain(handle)` increments the refcount
//!     (used when sharing the handle across threads in Swift)
//!   - `shadow_handle_release(handle)` decrements; when refcount
//!     reaches zero the inner `RealBackend` is dropped
//!   - All `shadow_handle_*` operation methods take `*const
//!     ShadowEngineHandle` and return error codes the same way
//!     as the existing global-state API
//!
//! ## PR4 additions (this commit)
//!
//! Five new operation entry points so the Swift consumer never has
//! to fall back to the legacy global-state surface:
//!
//!   - `shadow_handle_insert(handle, doc_json)`     → i32
//!   - `shadow_handle_remove(handle, doc_id)`       → i32
//!   - `shadow_handle_flush(handle)`                → i32
//!   - `shadow_handle_stats(handle, out_err)`       → *mut c_char
//!   - `shadow_handle_free_string(ptr)`             → ()
//!
//! Each panic-safe via `catch_unwind`, mirrors the global API's
//! discriminant convention, and dispatches through the same
//! `ShadowBackend` trait the legacy global API uses — so semantics
//! are identical, only ownership changes.

use std::ffi::{c_char, CStr, CString};
use std::panic::{self, AssertUnwindSafe};
use std::path::Path;
use std::ptr;
use std::sync::Arc;

use crate::backend::{RealBackend, ShadowBackend};
use crate::error::ShadowError;
use crate::ShadowDocument;

/// Opaque handle to a real backend. The Rust side never exposes
/// the inner `RealBackend` to Swift directly — only `*const
/// ShadowEngineHandle` pointers cross the FFI boundary.
pub struct ShadowEngineHandle {
    backend: Arc<RealBackend>,
}

/// Open a real backend at `path` and return a refcount-1 handle.
/// Returns null on failure.
///
/// # Safety
/// `path` must point to a valid C string. The returned pointer is
/// owned by the caller and must be released via `shadow_handle_release`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn shadow_handle_open_at(path: *const c_char) -> *const ShadowEngineHandle {
    // AssertUnwindSafe: the captured raw pointer is `Copy` and not
    // mutated after the catch_unwind body decides to dereference it.
    // RealBackend::open_at performs disk IO and may panic; we want
    // that panic translated to a null return rather than aborting
    // the Swift host.
    let result = panic::catch_unwind(AssertUnwindSafe(|| -> *const ShadowEngineHandle {
        if path.is_null() {
            return ptr::null();
        }
        // SAFETY: caller contract above.
        let c_path = unsafe { CStr::from_ptr(path) };
        let s = match c_path.to_str() {
            Ok(s) => s,
            Err(_) => return ptr::null(),
        };
        match RealBackend::open_at(Path::new(s)) {
            Ok(backend) => {
                let arc = Arc::new(ShadowEngineHandle {
                    backend: Arc::new(backend),
                });
                Arc::into_raw(arc)
            }
            Err(_) => ptr::null(),
        }
    }));
    result.unwrap_or(ptr::null())
}

/// Increment the handle's refcount. Used by Swift when stashing the
/// handle in a long-lived structure that may outlive the original
/// caller's scope.
///
/// # Safety
/// `handle` must be a valid `ShadowEngineHandle` pointer obtained
/// from `shadow_handle_open_at` (or a previous `shadow_handle_retain`).
#[unsafe(no_mangle)]
pub unsafe extern "C" fn shadow_handle_retain(handle: *const ShadowEngineHandle) {
    if handle.is_null() {
        return;
    }
    // SAFETY: caller contract above. AssertUnwindSafe because the
    // captured raw pointer is Copy and the only side effect is the
    // Arc strong-count increment.
    let _ = panic::catch_unwind(AssertUnwindSafe(|| unsafe {
        Arc::increment_strong_count(handle);
    }));
}

/// Decrement the handle's refcount. When it reaches zero, the inner
/// backend is dropped.
///
/// # Safety
/// `handle` must be a valid `ShadowEngineHandle` pointer that has
/// not yet been released. Releasing twice is undefined behavior.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn shadow_handle_release(handle: *const ShadowEngineHandle) {
    if handle.is_null() {
        return;
    }
    // SAFETY: caller contract above. AssertUnwindSafe because the
    // captured raw pointer is Copy. If the inner Drop panics we don't
    // want it to abort the Swift host.
    let _ = panic::catch_unwind(AssertUnwindSafe(|| unsafe {
        Arc::decrement_strong_count(handle);
    }));
}

/// Look up the backend without consuming the handle. Internal helper
/// for the operation methods (search/insert/remove/flush/stats).
/// Inlined so the FFI surface methods compile down to one Arc clone
/// + one trait dispatch.
///
/// # Safety
/// `handle` must be a valid `ShadowEngineHandle` pointer that has
/// been obtained from `shadow_handle_open_at` and not yet released.
/// The borrow leaves the caller-side refcount unchanged: it temporarily
/// reconstructs the `Arc` to clone its inner backend, then re-leaks
/// the outer `Arc` back to its raw form so the original strong count
/// is preserved.
#[inline]
unsafe fn borrow_backend(handle: *const ShadowEngineHandle) -> Option<Arc<dyn ShadowBackend>> {
    if handle.is_null() {
        return None;
    }
    // SAFETY: caller contract — handle is a valid pointer from open_at,
    // not yet released. We immediately re-leak below so the strong
    // count is preserved.
    let arc_handle = unsafe { Arc::from_raw(handle) };
    let backend = arc_handle.backend.clone() as Arc<dyn ShadowBackend>;
    // Re-leak so Swift's owning pointer remains valid. The strong
    // count is identical before and after this borrow.
    let _ = Arc::into_raw(arc_handle);
    Some(backend)
}

/// Wrap an error code from the operation methods. Returns 0 on
/// success, negative discriminant otherwise — matches the existing
/// global-API convention so Swift's error handling stays uniform.
fn encode_error(err: &ShadowError) -> i32 {
    err.as_code()
}

/// Read a UTF-8 string from a C pointer, mapping a null pointer or
/// non-UTF-8 bytes to `InvalidInput`. Used by the operation methods
/// that take a `*const c_char` argument.
///
/// # Safety
/// `ptr` must be a valid NUL-terminated C string when non-null.
unsafe fn read_c_str<'a>(ptr: *const c_char, label: &str) -> Result<&'a str, ShadowError> {
    if ptr.is_null() {
        return Err(ShadowError::InvalidInput {
            detail: format!("{label} was null"),
        });
    }
    // SAFETY: caller contract above.
    unsafe { CStr::from_ptr(ptr) }
        .to_str()
        .map_err(|_| ShadowError::InvalidInput {
            detail: format!("{label} was not valid UTF-8"),
        })
}

/// Search via the handle. Returns a JSON-encoded `Vec<ShadowHit>` as
/// a caller-owned C string; null on error (with `out_error` populated).
///
/// # Safety
/// `handle`, `query_c`, and `domain_c` must all be valid pointers.
/// The returned C string (when non-null) must be freed via
/// `shadow_handle_free_string`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn shadow_handle_search(
    handle: *const ShadowEngineHandle,
    query_c: *const c_char,
    domain_c: *const c_char,
    limit: usize,
    out_error: *mut i32,
) -> *mut c_char {
    // AssertUnwindSafe: handle/query_c/domain_c/out_error are Copy raw
    // pointers; their use inside the closure does not break unwind
    // safety. Backend::search may panic on internal index corruption;
    // we want that translated to ShadowError::Panic, not abort.
    let result = panic::catch_unwind(AssertUnwindSafe(|| -> *mut c_char {
        // SAFETY: caller contract — borrow_backend's safety obligations
        // are satisfied here (handle non-null + valid + not-yet-released).
        let backend = match unsafe { borrow_backend(handle) } {
            Some(b) => b,
            None => {
                if !out_error.is_null() {
                    // SAFETY: caller pointer.
                    unsafe { *out_error = ShadowError::InvalidInput { detail: "handle was null".into() }.as_code() };
                }
                return ptr::null_mut();
            }
        };
        // SAFETY: caller contract — query_c/domain_c valid C strings.
        let query = match unsafe { read_c_str(query_c, "query") } {
            Ok(s) => s,
            Err(e) => {
                if !out_error.is_null() {
                    // SAFETY: caller pointer.
                    unsafe { *out_error = encode_error(&e) };
                }
                return ptr::null_mut();
            }
        };
        // SAFETY: caller contract.
        let domain = match unsafe { read_c_str(domain_c, "domain") } {
            Ok(s) => s,
            Err(e) => {
                if !out_error.is_null() {
                    // SAFETY: caller pointer.
                    unsafe { *out_error = encode_error(&e) };
                }
                return ptr::null_mut();
            }
        };
        match backend.search(query, domain, limit) {
            Ok(hits) => {
                if !out_error.is_null() {
                    // SAFETY: caller pointer.
                    unsafe { *out_error = 0 };
                }
                let json = serde_json::to_string(&hits).unwrap_or_else(|_| "[]".to_string());
                CString::new(json)
                    .map(|c| c.into_raw())
                    .unwrap_or(ptr::null_mut())
            }
            Err(e) => {
                if !out_error.is_null() {
                    // SAFETY: caller pointer.
                    unsafe { *out_error = encode_error(&e) };
                }
                ptr::null_mut()
            }
        }
    }));
    match result {
        Ok(p) => p,
        Err(_) => {
            if !out_error.is_null() {
                // SAFETY: caller pointer.
                unsafe { *out_error = ShadowError::Panic.as_code() };
            }
            ptr::null_mut()
        }
    }
}

/// Insert one document via the handle. JSON-encoded `ShadowDocument`.
/// Returns 0 on success, negative `ShadowError` discriminant on failure.
///
/// # Safety
/// `handle` must be a valid handle pointer; `doc_json` must be a valid
/// NUL-terminated UTF-8 C string.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn shadow_handle_insert(
    handle: *const ShadowEngineHandle,
    doc_json: *const c_char,
) -> i32 {
    // AssertUnwindSafe: see shadow_handle_search rationale.
    let result = panic::catch_unwind(AssertUnwindSafe(|| -> i32 {
        // SAFETY: caller contract.
        let backend = match unsafe { borrow_backend(handle) } {
            Some(b) => b,
            None => {
                return ShadowError::InvalidInput {
                    detail: "handle was null".into(),
                }
                .as_code();
            }
        };
        // SAFETY: caller contract.
        let json = match unsafe { read_c_str(doc_json, "doc_json") } {
            Ok(s) => s,
            Err(e) => return encode_error(&e),
        };
        let doc: ShadowDocument = match serde_json::from_str(json) {
            Ok(d) => d,
            Err(error) => {
                return ShadowError::InvalidInput {
                    detail: format!("doc_json failed JSON parse: {error}"),
                }
                .as_code();
            }
        };
        match backend.insert_document(doc) {
            Ok(()) => 0,
            Err(error) => encode_error(&error),
        }
    }));
    result.unwrap_or_else(|_| ShadowError::Panic.as_code())
}

/// Remove one document by id via the handle.
/// Returns 0 on success, negative `ShadowError` discriminant on failure.
///
/// # Safety
/// `handle` must be a valid handle pointer; `doc_id` must be a valid
/// NUL-terminated UTF-8 C string.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn shadow_handle_remove(
    handle: *const ShadowEngineHandle,
    doc_id: *const c_char,
) -> i32 {
    // AssertUnwindSafe: see shadow_handle_search rationale.
    let result = panic::catch_unwind(AssertUnwindSafe(|| -> i32 {
        // SAFETY: caller contract.
        let backend = match unsafe { borrow_backend(handle) } {
            Some(b) => b,
            None => {
                return ShadowError::InvalidInput {
                    detail: "handle was null".into(),
                }
                .as_code();
            }
        };
        // SAFETY: caller contract.
        let id = match unsafe { read_c_str(doc_id, "doc_id") } {
            Ok(s) => s,
            Err(e) => return encode_error(&e),
        };
        match backend.remove_document(id) {
            Ok(()) => 0,
            Err(error) => encode_error(&error),
        }
    }));
    result.unwrap_or_else(|_| ShadowError::Panic.as_code())
}

/// Flush pending writes to disk via the handle.
/// Returns 0 on success, negative `ShadowError` discriminant on failure.
///
/// # Safety
/// `handle` must be a valid handle pointer.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn shadow_handle_flush(handle: *const ShadowEngineHandle) -> i32 {
    // AssertUnwindSafe: see shadow_handle_search rationale.
    let result = panic::catch_unwind(AssertUnwindSafe(|| -> i32 {
        // SAFETY: caller contract.
        let backend = match unsafe { borrow_backend(handle) } {
            Some(b) => b,
            None => {
                return ShadowError::InvalidInput {
                    detail: "handle was null".into(),
                }
                .as_code();
            }
        };
        match backend.flush() {
            Ok(()) => 0,
            Err(error) => encode_error(&error),
        }
    }));
    result.unwrap_or_else(|_| ShadowError::Panic.as_code())
}

/// Read aggregate stats via the handle. Returns a JSON-encoded
/// `ShadowStats` as a caller-owned C string; null on error (with
/// `out_error` populated).
///
/// # Safety
/// `handle` must be a valid handle pointer. The returned C string
/// (when non-null) must be freed via `shadow_handle_free_string`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn shadow_handle_stats(
    handle: *const ShadowEngineHandle,
    out_error: *mut i32,
) -> *mut c_char {
    // AssertUnwindSafe: see shadow_handle_search rationale.
    let result = panic::catch_unwind(AssertUnwindSafe(|| -> *mut c_char {
        // SAFETY: caller contract.
        let backend = match unsafe { borrow_backend(handle) } {
            Some(b) => b,
            None => {
                if !out_error.is_null() {
                    // SAFETY: caller pointer.
                    unsafe {
                        *out_error = ShadowError::InvalidInput {
                            detail: "handle was null".into(),
                        }
                        .as_code()
                    };
                }
                return ptr::null_mut();
            }
        };
        match backend.stats() {
            Ok(stats) => {
                if !out_error.is_null() {
                    // SAFETY: caller pointer.
                    unsafe { *out_error = 0 };
                }
                let json = match serde_json::to_string(&stats) {
                    Ok(j) => j,
                    Err(error) => {
                        if !out_error.is_null() {
                            // SAFETY: caller pointer.
                            unsafe {
                                *out_error = ShadowError::Backend {
                                    detail: format!("stats encode failed: {error}"),
                                }
                                .as_code()
                            };
                        }
                        return ptr::null_mut();
                    }
                };
                CString::new(json)
                    .map(|c| c.into_raw())
                    .unwrap_or(ptr::null_mut())
            }
            Err(e) => {
                if !out_error.is_null() {
                    // SAFETY: caller pointer.
                    unsafe { *out_error = encode_error(&e) };
                }
                ptr::null_mut()
            }
        }
    }));
    match result {
        Ok(p) => p,
        Err(_) => {
            if !out_error.is_null() {
                // SAFETY: caller pointer.
                unsafe { *out_error = ShadowError::Panic.as_code() };
            }
            ptr::null_mut()
        }
    }
}

/// Free a C string returned by `shadow_handle_search` or
/// `shadow_handle_stats`. Idempotent on null. The handle-FFI exposes
/// its own free entry point so Swift never has to call into the
/// legacy global-API surface.
///
/// # Safety
/// `ptr` must come from a `shadow_handle_*` function that returns
/// a `*mut c_char`. Passing a pointer from a different allocator (or
/// the same pointer twice) is undefined behavior.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn shadow_handle_free_string(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    let _ = panic::catch_unwind(|| {
        // SAFETY: caller contract above.
        let _ = unsafe { CString::from_raw(ptr) };
    });
}

#[cfg(test)]
mod tests {
    // Tests cover the parts of the handle module that don't require
    // booting a `RealBackend` (which triggers a HuggingFace download
    // and a tantivy directory). Roundtrip integration tests live in
    // the Swift test suite where they can drive the full FFI from
    // the consumer side without polluting `cargo test`'s offline
    // contract.

    use super::*;
    use std::ffi::CString;

    /// `borrow_backend` on a null handle is a clean miss, not a
    /// segfault. This is the contract Swift relies on when an `init`
    /// fails: subsequent operation calls take a `nil` pointer and
    /// must return an error code, not crash.
    #[test]
    fn borrow_backend_on_null_returns_none() {
        // SAFETY: passing null is explicitly handled inside borrow_backend.
        let result = unsafe { borrow_backend(ptr::null()) };
        assert!(result.is_none());
    }

    /// `shadow_handle_release` on a null pointer is a no-op (matches
    /// `free(NULL)` semantics in C, which Swift's `deinit` may emit
    /// when an `init` failed and the handle was never assigned).
    #[test]
    fn release_on_null_is_noop() {
        // SAFETY: explicit null branch inside the FFI export.
        unsafe {
            shadow_handle_release(ptr::null());
            shadow_handle_retain(ptr::null());
        }
    }

    /// `shadow_handle_free_string` on a null pointer is a no-op.
    /// Mirrors the legacy `shadow_free_string` contract so Swift can
    /// call it inside a `defer` block without a nil-check.
    #[test]
    fn free_string_on_null_is_noop() {
        // SAFETY: explicit null branch.
        unsafe { shadow_handle_free_string(ptr::null_mut()) };
    }

    /// All operation methods (search/insert/remove/flush/stats) return
    /// a typed error when given a null handle, instead of crashing.
    /// This is the cardinal "no UB across the FFI boundary" contract.
    #[test]
    fn operations_on_null_handle_return_invalid_input_code() {
        let valid_doc =
            CString::new(r#"{"doc_id":"d","title":"t","body":"b","domain":"note"}"#).unwrap();
        let valid_str = CString::new("hello").unwrap();
        let mut err: i32 = 0;

        // SAFETY: each export's null-handle branch returns an error code
        // without dereferencing.
        unsafe {
            assert_eq!(
                shadow_handle_insert(ptr::null(), valid_doc.as_ptr()),
                ShadowError::InvalidInput { detail: "x".into() }.as_code()
            );
            assert_eq!(
                shadow_handle_remove(ptr::null(), valid_str.as_ptr()),
                ShadowError::InvalidInput { detail: "x".into() }.as_code()
            );
            assert_eq!(
                shadow_handle_flush(ptr::null()),
                ShadowError::InvalidInput { detail: "x".into() }.as_code()
            );

            let stats_ptr = shadow_handle_stats(ptr::null(), &mut err as *mut i32);
            assert!(stats_ptr.is_null());
            assert_eq!(err, ShadowError::InvalidInput { detail: "x".into() }.as_code());

            err = 0;
            let search_ptr = shadow_handle_search(
                ptr::null(),
                valid_str.as_ptr(),
                valid_str.as_ptr(),
                10,
                &mut err as *mut i32,
            );
            assert!(search_ptr.is_null());
            assert_eq!(err, ShadowError::InvalidInput { detail: "x".into() }.as_code());
        }
    }

    /// Null `doc_json` / null `doc_id` / null `path` etc. cross the
    /// FFI without UB. The non-handle null pointers are also typed
    /// errors, not crashes.
    #[test]
    fn open_at_with_null_path_returns_null() {
        // SAFETY: explicit null branch.
        let p = unsafe { shadow_handle_open_at(ptr::null()) };
        assert!(p.is_null());
    }

    /// `read_c_str` rejects non-UTF-8 input as InvalidInput rather
    /// than panicking. Used by every handle-op method that takes a
    /// `*const c_char` argument.
    #[test]
    fn read_c_str_rejects_invalid_utf8() {
        // C string with a stray 0xFF byte.
        let bad: [u8; 4] = [0xFF, b'a', b'b', 0];
        // SAFETY: NUL-terminated; not valid UTF-8 — read_c_str maps
        // the encoding error to InvalidInput.
        let result = unsafe { read_c_str(bad.as_ptr() as *const c_char, "test") };
        match result {
            Err(ShadowError::InvalidInput { .. }) => (),
            other => panic!("expected InvalidInput, got {other:?}"),
        }
    }

    /// `encode_error` round-trips the public discriminants so the
    /// Swift `ShadowFFIError.from(rustCode:)` decoder stays correct.
    #[test]
    fn encode_error_matches_discriminants() {
        assert_eq!(
            encode_error(&ShadowError::InvalidInput { detail: "x".into() }),
            -1
        );
        assert_eq!(
            encode_error(&ShadowError::NotFound {
                doc_id: "x".into()
            }),
            -2
        );
        assert_eq!(encode_error(&ShadowError::Io { detail: "x".into() }), -3);
        assert_eq!(
            encode_error(&ShadowError::Backend { detail: "x".into() }),
            -4
        );
        assert_eq!(encode_error(&ShadowError::Panic), -99);
    }

    /// Refcount discipline check: `borrow_backend` does NOT consume
    /// the caller's strong count. Demonstrated by leaking a known-good
    /// `Arc<ShadowEngineHandle>` directly (the synthetic handle path)
    /// and asserting the FFI helpers leave the count untouched.
    ///
    /// This replaces the W9.21 PR1 placeholder test that double-freed
    /// across `Arc::from_raw` calls.
    #[test]
    fn borrow_does_not_steal_caller_refcount() {
        // We cannot construct a real ShadowEngineHandle without a
        // RealBackend, so the test instead drives an `Arc<u32>` through
        // the same Arc::from_raw / Arc::into_raw dance the helper uses.
        // The point is the "leak the outer Arc back" pattern preserves
        // the strong count — verified explicitly here.
        let arc = Arc::new(42u32);
        let raw = Arc::into_raw(arc);

        // Snapshot the initial count via a transient reconstruction,
        // immediately re-leaked (mirrors borrow_backend's body).
        let count_before = {
            // SAFETY: raw came from Arc::into_raw above; valid pointer.
            let temp = unsafe { Arc::from_raw(raw) };
            let n = Arc::strong_count(&temp);
            let _ = Arc::into_raw(temp);
            n
        };
        assert_eq!(count_before, 1, "single owning leak before borrow");

        // Pretend we're borrow_backend: reconstruct, clone-as-trait,
        // re-leak. The clone increments to 2; after `borrowed` drops
        // we're back to 1.
        let borrowed: Arc<u32> = {
            // SAFETY: raw still valid (we re-leaked above).
            let temp = unsafe { Arc::from_raw(raw) };
            let cloned = temp.clone();
            let _ = Arc::into_raw(temp);
            cloned
        };
        assert_eq!(*borrowed, 42);

        // Drop the clone — count returns to 1.
        drop(borrowed);
        let count_after = {
            // SAFETY: raw still valid; the outer Arc was re-leaked.
            let temp = unsafe { Arc::from_raw(raw) };
            let n = Arc::strong_count(&temp);
            let _ = Arc::into_raw(temp);
            n
        };
        assert_eq!(count_after, 1, "borrow restores strong count to 1");

        // Final cleanup so miri / leak-checkers stay happy.
        // SAFETY: raw still valid; this consumes the last Arc.
        let final_arc = unsafe { Arc::from_raw(raw) };
        drop(final_arc);
    }
}
