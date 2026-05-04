//! Canonical App Group container path layout for the Rust arena foundation.
//!
//! Rust does not query `NSFileManager` directly here. The Swift/AppKit layer
//! owns entitlement-aware App Group resolution in a later slice and can pass the
//! resolved base path into this module. Until then, the fallback stays local and
//! uses the canonical Epistemos spelling.

use std::io;
use std::path::{Path, PathBuf};

pub const APP_GROUP_ID: &str = "group.com.epistemos.shared";
pub const LEGACY_DIR: &str = "Epistemos";
pub const ARENA_FILE_NAME: &str = "arena.dat";

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct AppGroupContainer {
    base: PathBuf,
}

impl AppGroupContainer {
    pub fn from_base(base: impl Into<PathBuf>) -> Self {
        Self { base: base.into() }
    }

    pub fn from_env_or_legacy() -> Self {
        if let Some(base) = std::env::var_os("EPISTEMOS_APP_GROUP_CONTAINER") {
            return Self::from_base(PathBuf::from(base));
        }
        Self::from_base(legacy_base())
    }

    pub fn base(&self) -> &Path {
        &self.base
    }

    pub fn arena_path(&self) -> PathBuf {
        self.base.join(ARENA_FILE_NAME)
    }

    pub fn blobs_path(&self) -> PathBuf {
        self.base.join("blobs")
    }

    pub fn provenance_db_path(&self) -> PathBuf {
        self.base.join("provenance.sqlite")
    }

    pub fn vault_index_path(&self) -> PathBuf {
        self.base.join("vault_index.sqlite")
    }

    pub fn resonance_db_path(&self) -> PathBuf {
        self.base.join("resonance.sqlite")
    }

    pub fn ensure_layout(&self) -> io::Result<()> {
        for dir in [self.base.clone(), self.blobs_path()] {
            std::fs::create_dir_all(&dir)?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                std::fs::set_permissions(&dir, std::fs::Permissions::from_mode(0o700))?;
            }
        }
        Ok(())
    }
}

pub fn legacy_base() -> PathBuf {
    dirs::data_dir()
        .unwrap_or_else(std::env::temp_dir)
        .join(LEGACY_DIR)
}
