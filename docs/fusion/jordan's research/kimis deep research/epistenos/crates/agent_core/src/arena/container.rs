//! App Group container path resolution for macOS App Sandbox.
//!
//! This module queries the `NSFileManager` for the security-scoped App Group
//! container URL and derives all shared-state paths from it.  If the App Group
//! is not available (e.g. old install without entitlements), every method falls
//! back to a legacy path under `~/Library/Application Support/Epistenos/`.

use std::ffi::{c_char, CStr, OsStr};
use std::io;
use std::os::unix::ffi::OsStrExt;
use std::path::{Path, PathBuf};

use objc2::rc::Retained;
use objc2_foundation::{
    NSFileManager, NSString, NSURL,
};
use tracing::{info, warn};

/// The App Group identifier shared between the main app and its XPC helpers.
pub const APP_GROUP_ID: &str = "group.com.epistenos.shared";

/// Legacy fallback directory name.
pub const LEGACY_DIR: &str = "Epistenos";

// ---------------------------------------------------------------------------
// AppGroupContainer
// ---------------------------------------------------------------------------

/// Resolves paths inside the App Group container (or legacy fallback).
///
/// All methods are stateless; the struct carries no fields so that it can be
/// used freely from any thread.
pub struct AppGroupContainer;

impl AppGroupContainer {
    /// Query `NSFileManager` for the container URL of the App Group.
    ///
    /// Returns `None` if the App Group is not configured in entitlements or
    /// if the sandbox does not grant access.
    pub fn group_url() -> Option<PathBuf> {
        // SAFETY: NSFileManager::defaultManager returns a singleton that is
        // valid for the lifetime of the process.  The NSString is autoreleased
        // but we Retain it to be safe across the message-send boundary.
        let fm = unsafe { NSFileManager::defaultManager() };
        let group_id = NSString::from_str(APP_GROUP_ID);
        let url: Option<Retained<NSURL>> = unsafe {
            fm.containerURLForSecurityApplicationGroupIdentifier(&group_id)
        };

        url.map(|u| {
            // SAFETY: NSURL::fileSystemRepresentation returns a valid UTF-8
            // C string for file-system paths (macOS guarantees this for
            // App Group containers).
            let bytes = unsafe {
                let ptr = u.fileSystemRepresentation();
                CStr::from_ptr(ptr).to_bytes()
            };
            let os_str = OsStr::from_bytes(bytes);
            PathBuf::from(os_str)
        })
    }

    /// Return the path to the mmap arena backing file.
    pub fn arena_path() -> PathBuf {
        Self::resolve_or_legacy("arena", "epistenos.arena")
    }

    /// Return the path to the blob store directory.
    pub fn blobs_path() -> PathBuf {
        Self::resolve_or_legacy_dir("blobs")
    }

    /// Return the path to the provenance SQLite database.
    pub fn provenance_db_path() -> PathBuf {
        Self::resolve_or_legacy("provenance", "provenance.db")
    }

    /// Return the path to the vault index SQLite database.
    pub fn vault_index_path() -> PathBuf {
        Self::resolve_or_legacy("vaults", "vault_index.db")
    }

    /// Return the path to the resonance SQLite database.
    pub fn resonance_db_path() -> PathBuf {
        Self::resolve_or_legacy("resonance", "resonance.db")
    }

    /// Ensure that every required subdirectory exists inside the App Group
    /// container (or legacy fallback).
    ///
    /// Creates directories with `0o700` permissions (user-only) for defence in
    /// depth inside the shared container.
    pub fn ensure_layout() -> io::Result<()> {
        let dirs = [
            Self::blobs_path(),
            Self::resolve_or_legacy_dir("provenance"),
            Self::resolve_or_legacy_dir("vaults"),
            Self::resolve_or_legacy_dir("resonance"),
            Self::resolve_or_legacy_dir("tmp"),
            Self::resolve_or_legacy_dir("logs"),
        ];

        for d in &dirs {
            if !d.exists() {
                info!(dir = ?d, "creating App Group subdirectory");
                std::fs::create_dir_all(d)?;
                #[cfg(target_os = "macos")]
                {
                    use std::os::unix::fs::PermissionsExt;
                    std::fs::set_permissions(d, std::fs::Permissions::from_mode(0o700))?;
                }
            }
        }

        Ok(())
    }

    // -----------------------------------------------------------------------
    // Internal helpers
    // -----------------------------------------------------------------------

    /// Resolve `subdir/filename` inside the App Group, falling back to the
    /// legacy Application Support path.
    fn resolve_or_legacy(subdir: &str, filename: &str) -> PathBuf {
        match Self::group_url() {
            Some(base) => {
                let mut p = base;
                p.push(subdir);
                p.push(filename);
                p
            }
            None => {
                let mut p = Self::legacy_base();
                p.push(subdir);
                p.push(filename);
                warn!("App Group not available — using legacy path: {}", p.display());
                p
            }
        }
    }

    /// Resolve `subdir` inside the App Group, falling back to legacy.
    fn resolve_or_legacy_dir(subdir: &str) -> PathBuf {
        match Self::group_url() {
            Some(mut base) => {
                base.push(subdir);
                base
            }
            None => {
                let mut p = Self::legacy_base();
                p.push(subdir);
                warn!("App Group not available — using legacy dir: {}", p.display());
                p
            }
        }
    }

    /// Legacy base: `~/Library/Application Support/Epistenos/`
    fn legacy_base() -> PathBuf {
        dirs::data_dir()
            .unwrap_or_else(|| std::env::temp_dir())
            .join(LEGACY_DIR)
    }
}

// ---------------------------------------------------------------------------
// Standalone helper for FFI (C string out)
// ---------------------------------------------------------------------------

/// Write the UTF-8 path of the arena file into `out_buf`.
///
/// Returns the number of bytes written (excluding NUL).  If the buffer is
/// too small, returns `-1`.  This is the C-ABI boundary used by UniFFI.
///
/// # Safety
/// `out_buf` must be valid for at least `out_cap` bytes.
#[no_mangle]
pub unsafe extern "C" fn epistenos_arena_path(out_buf: *mut c_char, out_cap: usize) -> isize {
    if out_buf.is_null() || out_cap == 0 {
        return -1;
    }
    let path = AppGroupContainer::arena_path();
    let bytes = path.as_os_str().as_encoded_bytes();
    if bytes.len() + 1 > out_cap {
        return -1;
    }
    // SAFETY: We checked the capacity above.
    unsafe {
        core::ptr::copy_nonoverlapping(bytes.as_ptr().cast(), out_buf, bytes.len());
        out_buf.add(bytes.len()).write(0);
    }
    bytes.len() as isize
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn legacy_base_is_sane() {
        let base = AppGroupContainer::legacy_base();
        assert!(base.to_string_lossy().contains(LEGACY_DIR));
    }

    #[test]
    fn arena_path_contains_arena() {
        let p = AppGroupContainer::arena_path();
        let s = p.to_string_lossy();
        assert!(s.contains("arena") || s.contains("Epistenos"));
    }

    #[test]
    fn ensure_layout_idempotent() {
        // This test runs on the legacy path in CI (no App Group there).
        AppGroupContainer::ensure_layout().unwrap();
        // Second call should be a no-op.
        AppGroupContainer::ensure_layout().unwrap();
    }
}
