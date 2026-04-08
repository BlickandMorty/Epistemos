//! C ABI for substrate-core.
//!
//! ## Law 4 caveat (per docs/UNIFIED_SUBSTRATE_RESEARCH.md)
//!
//! The unified substrate research says: *"UniFFI stays until profiling proves
//! otherwise. Keep UniFFI for everything, then replace the top 3 measured
//! hotspots with #[repr(C)]."*
//!
//! This module exposes a custom C ABI **anticipating** that entity reads are
//! on the render hot path. It is the eventual target, not the starting point.
//! Swift should prefer UniFFI bindings for cold-path mutations (create/update/
//! delete) and only reach for these raw C entry points when measurement
//! justifies it. Both can coexist on top of the same `Store`.
//!
//! ## Wire format
//!
//! `EntityId` crosses as `u64` (it's `#[repr(transparent)]`). No handle
//! translation, no wrapper allocation on the hot read path.
//!
//! Input strings are `*const c_char` (UTF-8, NUL-terminated). Output strings
//! are `*mut c_char`; callers free them with `substrate_string_free`.
//!
//! Error model: functions that can fail return a non-zero status code and
//! set a thread-local last-error string. Swift reads it with
//! `substrate_last_error`.

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use std::sync::OnceLock;

use parking_lot::Mutex;

use crate::action::AppAction;
use crate::entity::EntityId;
use crate::store::Store;

static LAST_ERROR: OnceLock<Mutex<Option<CString>>> = OnceLock::new();

fn set_last_error(msg: impl Into<String>) {
    let cell = LAST_ERROR.get_or_init(|| Mutex::new(None));
    *cell.lock() = CString::new(msg.into()).ok();
}

fn clear_last_error() {
    if let Some(cell) = LAST_ERROR.get() {
        *cell.lock() = None;
    }
}

/// Create a new store. Returns an opaque handle. Free with `substrate_store_free`.
///
/// # Safety
/// Always safe to call. The returned pointer must be freed exactly once via
/// `substrate_store_free`.
#[no_mangle]
pub extern "C" fn substrate_store_new() -> *mut Store {
    Box::into_raw(Box::new(Store::new()))
}

/// # Safety
/// `store` must be either null or a pointer returned by `substrate_store_new`
/// that has not yet been freed. Double-free is UB.
#[no_mangle]
pub unsafe extern "C" fn substrate_store_free(store: *mut Store) {
    if !store.is_null() {
        // SAFETY: contract above — caller guarantees exclusive ownership.
        drop(unsafe { Box::from_raw(store) });
    }
}

/// # Safety
/// `store` must be a valid pointer to a live `Store` (or null, which returns 0).
#[no_mangle]
pub unsafe extern "C" fn substrate_reserve_id(store: *const Store) -> u64 {
    if store.is_null() {
        return 0;
    }
    // SAFETY: null-checked; caller's contract guarantees pointer validity and
    // that no other thread is freeing the store concurrently.
    let store = unsafe { &*store };
    store.reserve_id().0
}

/// # Safety
/// `store`, `title`, `body` must each be valid or null. Strings must be
/// NUL-terminated UTF-8. See last_error on nonzero return.
#[no_mangle]
pub unsafe extern "C" fn substrate_create_note(
    store: *const Store,
    id: u64,
    title: *const c_char,
    body: *const c_char,
    at: i64,
) -> c_int {
    if store.is_null() || title.is_null() || body.is_null() {
        set_last_error("null pointer");
        return 1;
    }
    // SAFETY: null-checked above; caller guarantees NUL-terminated C strings.
    let title = match unsafe { CStr::from_ptr(title) }.to_str() {
        Ok(s) => s.to_string(),
        Err(e) => {
            set_last_error(format!("title utf8: {e}"));
            return 2;
        }
    };
    // SAFETY: null-checked above; caller guarantees NUL-terminated C strings.
    let body = match unsafe { CStr::from_ptr(body) }.to_str() {
        Ok(s) => s.to_string(),
        Err(e) => {
            set_last_error(format!("body utf8: {e}"));
            return 2;
        }
    };
    clear_last_error();
    // SAFETY: null-checked above; caller guarantees pointer validity.
    let store = unsafe { &*store };
    match store.apply(AppAction::CreateNote {
        id: EntityId(id),
        title,
        body,
        at,
    }) {
        Ok(()) => 0,
        Err(e) => {
            set_last_error(e.to_string());
            3
        }
    }
}

/// Read entity data as JSON. Caller MUST free with `substrate_string_free`.
///
/// # Safety
/// `store` must be valid or null. Returned pointer is owned by the caller.
#[no_mangle]
pub unsafe extern "C" fn substrate_get_json(store: *const Store, id: u64) -> *mut c_char {
    if store.is_null() {
        return std::ptr::null_mut();
    }
    // SAFETY: null-checked; caller guarantees pointer validity.
    let store = unsafe { &*store };
    let Some(data) = store.get(EntityId(id)) else {
        return std::ptr::null_mut();
    };
    let json = match serde_json::to_string(&data) {
        Ok(s) => s,
        Err(e) => {
            set_last_error(format!("serialize: {e}"));
            return std::ptr::null_mut();
        }
    };
    CString::new(json)
        .map(CString::into_raw)
        .unwrap_or(std::ptr::null_mut())
}

/// # Safety
/// `store` must be valid or null.
#[no_mangle]
pub unsafe extern "C" fn substrate_undo(store: *const Store) -> c_int {
    if store.is_null() {
        return 1;
    }
    // SAFETY: null-checked; caller guarantees pointer validity.
    let store = unsafe { &*store };
    match store.undo() {
        Ok(_) => 0,
        Err(e) => {
            set_last_error(e.to_string());
            3
        }
    }
}

/// # Safety
/// `store` must be valid or null.
#[no_mangle]
pub unsafe extern "C" fn substrate_redo(store: *const Store) -> c_int {
    if store.is_null() {
        return 1;
    }
    // SAFETY: null-checked; caller guarantees pointer validity.
    let store = unsafe { &*store };
    match store.redo() {
        Ok(_) => 0,
        Err(e) => {
            set_last_error(e.to_string());
            3
        }
    }
}

/// # Safety
/// `store` must be valid or null.
#[no_mangle]
pub unsafe extern "C" fn substrate_len(store: *const Store) -> u64 {
    if store.is_null() {
        return 0;
    }
    // SAFETY: null-checked; caller guarantees pointer validity.
    let store = unsafe { &*store };
    store.len() as u64
}

/// # Safety
/// `buf` must point to at least `cap` writable bytes, or be NULL.
/// If NULL, no writes occur and the required length is returned.
#[no_mangle]
pub unsafe extern "C" fn substrate_last_error(buf: *mut c_char, cap: usize) -> usize {
    let Some(cell) = LAST_ERROR.get() else {
        return 0;
    };
    let guard = cell.lock();
    let Some(ref msg) = *guard else { return 0 };
    let bytes = msg.as_bytes_with_nul();
    if buf.is_null() || cap == 0 {
        return bytes.len().saturating_sub(1);
    }
    let copy = bytes.len().min(cap);
    // SAFETY: caller guarantees `buf` points to `cap` writable bytes; `copy`
    // is bounded by both `bytes.len()` and `cap`.
    unsafe {
        std::ptr::copy_nonoverlapping(bytes.as_ptr() as *const c_char, buf, copy);
    }
    copy.saturating_sub(1)
}

/// # Safety
/// `s` must be either null or a pointer returned by a substrate-core function
/// that transferred ownership to the caller (e.g. `substrate_get_json`).
/// Double-free is UB.
#[no_mangle]
pub unsafe extern "C" fn substrate_string_free(s: *mut c_char) {
    if !s.is_null() {
        // SAFETY: caller guarantees exclusive ownership per contract above.
        drop(unsafe { CString::from_raw(s) });
    }
}
