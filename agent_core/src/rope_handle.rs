//! W9.26 — Rope FFI handle (PR2 of N)
//!
//! Per `docs/RESEARCH_DOSSIER_TIER_3_4.md` §W9.26: expose
//! `RopeDocument` (the crop-backed B-tree rope foundation in
//! `rope.rs`) over the FFI boundary so Swift can drive it from
//! `RopeFFIClient`. Follows the W9.21 honest-FFI pattern (PR1
//! shipped in `dcc5521f`, PR2 in `b2e4899d`):
//!
//!   - `Arc::into_raw` lifecycle — `*const RopeDocumentHandle` is
//!     refcounted; multiple Swift holders are sound
//!   - `*_retain` / `*_release` for explicit Arc strong-count
//!     management
//!   - `&self` operation methods on the inner `RopeDocument` (the
//!     `Mutex<crop::Rope>` makes this thread-safe)
//!
//! ## Why raw FFI instead of UniFFI
//!
//! agent_core has zero `#[derive(uniffi::Object)]` types today.
//! Introducing the first one requires uniffi.toml + bindgen
//! tooling validation that's outside the W9.26 PR2 scope. The raw
//! `@_silgen_name` / `extern "C"` pattern is already battle-tested
//! across `epistemos-shadow`, `substrate-rt`, `substrate-core`, and
//! `syntax-core` (the W9.21 series), so this stays in lane.
//!
//! ## FFI surface (8 entry points)
//!
//!   rope_handle_new           — empty rope, refcount 1
//!   rope_handle_from_str      — rope seeded with a string
//!   rope_handle_retain        — increment refcount
//!   rope_handle_release       — decrement refcount; drops at 0
//!   rope_handle_len_bytes     — UTF-8 byte length
//!   rope_handle_len_utf16     — UTF-16 code-unit length
//!   rope_handle_insert        — insert UTF-8 text at byte offset
//!   rope_handle_delete        — delete byte range [from, to)
//!   rope_handle_utf16_to_byte — convert UTF-16 → UTF-8 offset
//!   rope_handle_byte_to_utf16 — convert UTF-8 → UTF-16 offset
//!   rope_handle_snapshot      — full snapshot as *mut c_char
//!   rope_handle_free_string   — free a snapshot string
//!
//! The Swift `RopeFFIClient` + `~Copyable` handle wrapper lands
//! in the next PR (W9.26 PR3). NoteFileStorage migration is the
//! PR after that.

use std::ffi::{c_char, CStr, CString};
use std::sync::Arc;

use crate::rope::RopeDocument;

/// Opaque refcounted handle to a `RopeDocument`. Crosses FFI as
/// `*const RopeDocumentHandle`. The Rust side never exposes the
/// inner `RopeDocument` directly to Swift.
pub struct RopeDocumentHandle {
    pub(crate) inner: Arc<RopeDocument>,
}

/// Allocate an empty rope and return a refcount-1 handle.
///
/// # Safety
/// Always safe. Caller must release via `rope_handle_release`
/// exactly once for this initial refcount, plus once per matching
/// retain.
#[unsafe(no_mangle)]
pub extern "C" fn rope_handle_new() -> *const RopeDocumentHandle {
    let result = std::panic::catch_unwind(|| {
        let doc = Arc::new(RopeDocument::new());
        Arc::into_raw(Arc::new(RopeDocumentHandle { inner: doc }))
    });
    result.unwrap_or(std::ptr::null())
}

/// Allocate a rope seeded with `text` (UTF-8) and return a
/// refcount-1 handle.
///
/// # Safety
/// `text` must be a valid null-terminated UTF-8 C string, or null
/// (in which case an empty rope is returned).
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rope_handle_from_str(
    text: *const c_char,
) -> *const RopeDocumentHandle {
    let result = std::panic::catch_unwind(|| {
        if text.is_null() {
            let doc = Arc::new(RopeDocument::new());
            return Arc::into_raw(Arc::new(RopeDocumentHandle { inner: doc }));
        }
        // SAFETY: caller contract — text is null-terminated UTF-8.
        let s = unsafe { CStr::from_ptr(text) };
        match s.to_str() {
            Ok(s) => {
                let doc = Arc::new(RopeDocument::from_str(s));
                Arc::into_raw(Arc::new(RopeDocumentHandle { inner: doc }))
            }
            Err(_) => std::ptr::null(),
        }
    });
    result.unwrap_or(std::ptr::null())
}

/// Increment the handle's refcount.
///
/// # Safety
/// `handle` must be a live `RopeDocumentHandle` pointer.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rope_handle_retain(handle: *const RopeDocumentHandle) {
    if !handle.is_null() {
        // SAFETY: caller contract.
        unsafe {
            Arc::increment_strong_count(handle);
        }
    }
}

/// Decrement the handle's refcount. Drops the rope at zero.
/// Idempotent on null.
///
/// # Safety
/// `handle` must be a live `RopeDocumentHandle` pointer or null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rope_handle_release(handle: *const RopeDocumentHandle) {
    if !handle.is_null() {
        // SAFETY: caller contract — exactly-balanced retain/release.
        unsafe {
            Arc::decrement_strong_count(handle);
        }
    }
}

/// UTF-8 byte length of the rope.
///
/// # Safety
/// `handle` must be a live pointer or null. Returns 0 on null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rope_handle_len_bytes(
    handle: *const RopeDocumentHandle,
) -> usize {
    if handle.is_null() {
        return 0;
    }
    // SAFETY: caller contract.
    let h = unsafe { &*handle };
    h.inner.len_bytes()
}

/// UTF-16 code-unit length of the rope. Matches WKWebView's
/// `getSelection().getRangeAt(0)` semantics.
///
/// # Safety
/// `handle` must be a live pointer or null. Returns 0 on null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rope_handle_len_utf16(
    handle: *const RopeDocumentHandle,
) -> usize {
    if handle.is_null() {
        return 0;
    }
    // SAFETY: caller contract.
    let h = unsafe { &*handle };
    h.inner.len_utf16()
}

/// Insert UTF-8 `text` at `byte_offset`.
///
/// # Safety
/// `handle` must be live. `text` must be null-terminated UTF-8.
/// Returns false on any null input or invalid UTF-8.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rope_handle_insert(
    handle: *const RopeDocumentHandle,
    byte_offset: usize,
    text: *const c_char,
) -> bool {
    let result = std::panic::catch_unwind(|| {
        if handle.is_null() || text.is_null() {
            return false;
        }
        // SAFETY: caller contract.
        let h = unsafe { &*handle };
        let s = unsafe { CStr::from_ptr(text) };
        match s.to_str() {
            Ok(s) => {
                h.inner.insert(byte_offset, s);
                true
            }
            Err(_) => false,
        }
    });
    result.unwrap_or(false)
}

/// Delete the byte range `[from, to)`.
///
/// # Safety
/// `handle` must be live or null. Inverted ranges are no-ops
/// (matches the underlying `RopeDocument::delete` contract).
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rope_handle_delete(
    handle: *const RopeDocumentHandle,
    byte_from: usize,
    byte_to: usize,
) {
    if handle.is_null() {
        return;
    }
    let _ = std::panic::catch_unwind(|| {
        // SAFETY: caller contract.
        let h = unsafe { &*handle };
        h.inner.delete(byte_from, byte_to);
    });
}

/// Convert a UTF-16 offset to a UTF-8 byte offset.
///
/// # Safety
/// `handle` must be live or null. Returns 0 on null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rope_handle_utf16_to_byte(
    handle: *const RopeDocumentHandle,
    utf16_offset: usize,
) -> usize {
    if handle.is_null() {
        return 0;
    }
    // SAFETY: caller contract.
    let h = unsafe { &*handle };
    h.inner.utf16_to_byte(utf16_offset)
}

/// Convert a UTF-8 byte offset to a UTF-16 offset.
///
/// # Safety
/// `handle` must be live or null. Returns 0 on null.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rope_handle_byte_to_utf16(
    handle: *const RopeDocumentHandle,
    byte_offset: usize,
) -> usize {
    if handle.is_null() {
        return 0;
    }
    // SAFETY: caller contract.
    let h = unsafe { &*handle };
    h.inner.byte_to_utf16(byte_offset)
}

/// Snapshot the full document as a heap-allocated null-terminated
/// UTF-8 C string. Caller must free via `rope_handle_free_string`.
///
/// # Safety
/// `handle` must be live or null. Returns null on null handle.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rope_handle_snapshot(
    handle: *const RopeDocumentHandle,
) -> *mut c_char {
    if handle.is_null() {
        return std::ptr::null_mut();
    }
    let result = std::panic::catch_unwind(|| {
        // SAFETY: caller contract.
        let h = unsafe { &*handle };
        let s = h.inner.snapshot();
        match CString::new(s) {
            Ok(c) => c.into_raw(),
            Err(_) => std::ptr::null_mut(),
        }
    });
    result.unwrap_or(std::ptr::null_mut())
}

/// Free a string previously returned by `rope_handle_snapshot`.
/// Idempotent on null.
///
/// # Safety
/// `s` must be a pointer returned by `rope_handle_snapshot` and
/// not yet freed.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn rope_handle_free_string(s: *mut c_char) {
    if !s.is_null() {
        // SAFETY: caller contract.
        unsafe {
            drop(CString::from_raw(s));
        }
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
    fn handle_lifecycle_is_balanced() {
        let h = rope_handle_new();
        assert!(!h.is_null());
        unsafe {
            rope_handle_retain(h);
            rope_handle_retain(h);
            rope_handle_release(h);
            rope_handle_release(h);
            rope_handle_release(h); // last release drops the rope
        }
    }

    #[test]
    fn handle_from_str_seeds_correctly() {
        let s = cstr("Hello, world!");
        let h = unsafe { rope_handle_from_str(s.as_ptr()) };
        assert!(!h.is_null());
        assert_eq!(unsafe { rope_handle_len_bytes(h) }, 13);
        assert_eq!(unsafe { rope_handle_len_utf16(h) }, 13);
        unsafe { rope_handle_release(h) };
    }

    #[test]
    fn handle_insert_and_snapshot_roundtrip() {
        let h = rope_handle_new();
        let s = cstr("Hello, ");
        let ok1 = unsafe { rope_handle_insert(h, 0, s.as_ptr()) };
        assert!(ok1);
        let s2 = cstr("world!");
        let ok2 = unsafe { rope_handle_insert(h, 7, s2.as_ptr()) };
        assert!(ok2);

        let raw = unsafe { rope_handle_snapshot(h) };
        assert!(!raw.is_null());
        let snap = unsafe { CStr::from_ptr(raw) }.to_str().unwrap().to_string();
        assert_eq!(snap, "Hello, world!");
        unsafe { rope_handle_free_string(raw) };

        unsafe { rope_handle_release(h) };
    }

    #[test]
    fn handle_delete_inverted_range_noop() {
        let s = cstr("Hi");
        let h = unsafe { rope_handle_from_str(s.as_ptr()) };
        unsafe { rope_handle_delete(h, 2, 1) };
        let raw = unsafe { rope_handle_snapshot(h) };
        let snap = unsafe { CStr::from_ptr(raw) }.to_str().unwrap().to_string();
        assert_eq!(snap, "Hi");
        unsafe {
            rope_handle_free_string(raw);
            rope_handle_release(h);
        }
    }

    #[test]
    fn handle_utf16_metrics_match_underlying() {
        // BMP: ä is 2 UTF-8 bytes / 1 UTF-16 unit.
        let s = cstr("aäb");
        let h = unsafe { rope_handle_from_str(s.as_ptr()) };
        assert_eq!(unsafe { rope_handle_len_bytes(h) }, 4);
        assert_eq!(unsafe { rope_handle_len_utf16(h) }, 3);
        assert_eq!(unsafe { rope_handle_utf16_to_byte(h, 1) }, 1);
        assert_eq!(unsafe { rope_handle_utf16_to_byte(h, 2) }, 3);
        assert_eq!(unsafe { rope_handle_byte_to_utf16(h, 3) }, 2);
        unsafe { rope_handle_release(h) };
    }

    #[test]
    fn handle_null_inputs_are_safe() {
        // Every entry point must tolerate null handle/text without crashing.
        unsafe {
            rope_handle_retain(std::ptr::null());
            rope_handle_release(std::ptr::null());
            assert_eq!(rope_handle_len_bytes(std::ptr::null()), 0);
            assert_eq!(rope_handle_len_utf16(std::ptr::null()), 0);
            assert_eq!(
                rope_handle_insert(std::ptr::null(), 0, cstr("x").as_ptr()),
                false
            );
            rope_handle_delete(std::ptr::null(), 0, 0);
            assert_eq!(rope_handle_utf16_to_byte(std::ptr::null(), 0), 0);
            assert_eq!(rope_handle_byte_to_utf16(std::ptr::null(), 0), 0);
            assert!(rope_handle_snapshot(std::ptr::null()).is_null());
            rope_handle_free_string(std::ptr::null_mut());
        }
    }
}
