//! W9.21 — Honest FFI for `substrate-core` (PR2 of 4)
//!
//! Per `docs/RESEARCH_DOSSIER_TIER_3_4.md` §W9.21: replace raw
//! `Box::into_raw` lifecycle (ffi.rs:57, 67) with `Arc::into_raw`
//! refcounted handles. The new `substrate_store_handle_*` exports
//! coexist with the existing `substrate_store_*` global API; PR4
//! (Swift cutover) migrates consumers one call site at a time.
//!
//! ## Why honest matters here
//!
//! `substrate-core`'s `Store` is the canonical entity store. The
//! current API uses `*mut Store` with a Box single-owner contract.
//! Swift consumers commonly want to pass the Store handle into
//! multiple subsystems (UI, agent loop, MCP dispatcher) — each of
//! which conceptually shares ownership. Box semantics force ONE
//! owner and a runtime "don't free while in use" contract.
//!
//! With honest FFI: each subsystem retains its own Arc handle; the
//! Store drops only when ALL handles release. The refcount IS the
//! contract — no runtime invariant.
//!
//! `Store` is `Send + Sync` (inner state is `RwLock<...>` per
//! store.rs), so wrapping in `Arc` is sound.
//!
//! ## Lifecycle contract
//!
//! - `substrate_store_handle_new()` → `*const StoreHandle` (refcount 1)
//! - `substrate_store_handle_retain(h)` increments
//! - `substrate_store_handle_release(h)` decrements; drops at zero
//! - Operation methods take `*const StoreHandle` and act on
//!   `&handle.store` (no ownership transfer)

use std::sync::Arc;

use crate::store::Store;

/// Opaque refcounted handle to a `Store`. Crosses FFI as
/// `*const StoreHandle`. Rust never exposes the inner Store
/// directly to Swift.
pub struct StoreHandle {
    pub(crate) store: Arc<Store>,
}

/// Allocate a new Store and return a refcount-1 handle.
///
/// # Safety
/// Always safe to call. The returned pointer must be released via
/// `substrate_store_handle_release` exactly enough times to bring
/// the refcount to zero.
#[unsafe(no_mangle)]
pub extern "C" fn substrate_store_handle_new() -> *const StoreHandle {
    let store = Arc::new(Store::new());
    Arc::into_raw(Arc::new(StoreHandle { store }))
}

/// Increment the handle's refcount.
///
/// # Safety
/// `handle` must be a pointer previously returned by
/// `substrate_store_handle_new` (or a previous retain) and not yet
/// fully released.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn substrate_store_handle_retain(handle: *const StoreHandle) {
    if !handle.is_null() {
        // SAFETY: caller contract — handle is live.
        unsafe {
            Arc::increment_strong_count(handle);
        }
    }
}

/// Decrement the handle's refcount. Drops the underlying `Store`
/// at zero. Idempotent on null.
///
/// # Safety
/// `handle` must be a pointer previously returned by
/// `substrate_store_handle_new` or `substrate_store_handle_retain`
/// and not yet fully released.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn substrate_store_handle_release(handle: *const StoreHandle) {
    if !handle.is_null() {
        // SAFETY: caller contract — exactly-balanced retain/release.
        unsafe {
            Arc::decrement_strong_count(handle);
        }
    }
}

/// Reserve a fresh entity id from the handle's underlying store.
/// Mirrors `substrate_reserve_id` but takes a refcounted handle.
///
/// # Safety
/// `handle` must be a live `StoreHandle` pointer or null.
/// Returns 0 on null handle.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn substrate_store_handle_reserve_id(
    handle: *const StoreHandle,
) -> u64 {
    if handle.is_null() {
        return 0;
    }
    // SAFETY: caller contract — handle is live.
    let h = unsafe { &*handle };
    h.store.reserve_id().0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn handle_lifecycle_is_balanced() {
        let h = substrate_store_handle_new();
        assert!(!h.is_null());
        unsafe {
            substrate_store_handle_retain(h);
            substrate_store_handle_release(h); // counters retain
            substrate_store_handle_release(h); // counters _new
        }
    }

    #[test]
    fn handle_reserve_id_is_unique() {
        let h = substrate_store_handle_new();
        assert!(!h.is_null());
        let id1 = unsafe { substrate_store_handle_reserve_id(h) };
        let id2 = unsafe { substrate_store_handle_reserve_id(h) };
        assert_ne!(id1, 0);
        assert_ne!(id1, id2);
        unsafe { substrate_store_handle_release(h) };
    }

    #[test]
    fn handle_null_release_is_idempotent() {
        unsafe {
            substrate_store_handle_release(std::ptr::null());
        }
    }

    #[test]
    fn handle_shared_via_retain_lives_until_last_release() {
        // Retain n times, release n+1 times (n retains + 1 _new); the
        // store must survive every intermediate release. We verify by
        // reserving an id at each step — if the store dropped early,
        // the &*handle deref would UAF (TSan / miri would catch).
        let h = substrate_store_handle_new();
        unsafe {
            substrate_store_handle_retain(h);
            substrate_store_handle_retain(h);
            let _ = substrate_store_handle_reserve_id(h);
            substrate_store_handle_release(h);
            let _ = substrate_store_handle_reserve_id(h);
            substrate_store_handle_release(h);
            let _ = substrate_store_handle_reserve_id(h);
            substrate_store_handle_release(h); // final release; store drops here
        }
    }
}
