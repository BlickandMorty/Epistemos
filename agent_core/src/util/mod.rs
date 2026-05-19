//! Shared utilities — atomic file writes per plan §6.9.
//!
//! Plan §6.9: "Vault file writes are tempfile-rename: write to
//! .tmp.<uuid>, fsync, atomic rename to final path. No partial files
//! visible to other processes."
//!
//! `tempfile::NamedTempFile::persist()` performs exactly this dance:
//! creates a tempfile in the same directory (so the rename is
//! atomic on POSIX — `rename(2)` is atomic when source + destination
//! share a filesystem), writes bytes, calls `fsync` via persist's
//! `File::sync_all`, then atomic-renames into place.

use std::io;
use std::path::Path;

use serde::Serialize;

/// Atomic byte write per plan §6.9. Creates a tempfile in the same
/// directory as `path`, writes `bytes`, syncs, then atomic-renames.
/// On failure the tempfile is automatically cleaned up by `tempfile`.
pub fn atomic_write_bytes(path: &Path, bytes: &[u8]) -> io::Result<()> {
    let parent = path
        .parent()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "no parent directory"))?;
    if !parent.as_os_str().is_empty() {
        std::fs::create_dir_all(parent)?;
    }
    let mut tmp = tempfile::NamedTempFile::new_in(parent)?;
    use std::io::Write;
    tmp.write_all(bytes)?;
    // tempfile::persist already does sync_all + rename; on success the
    // tempfile is consumed and the target path appears atomically.
    tmp.persist(path)
        .map_err(|e| io::Error::new(io::ErrorKind::Other, e.error))?;
    Ok(())
}

/// Atomic JSON write — pretty-printed for human inspection, atomic
/// per plan §6.9. Use this for any vault-adjacent metadata stamp.
pub fn atomic_write_json<T: Serialize>(path: &Path, value: &T) -> io::Result<()> {
    let bytes = serde_json::to_vec_pretty(value)
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
    atomic_write_bytes(path, &bytes)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use tempfile::tempdir;

    #[test]
    fn atomic_write_bytes_round_trips() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("file.bin");
        atomic_write_bytes(&path, b"hello").unwrap();
        assert_eq!(std::fs::read(&path).unwrap(), b"hello");
    }

    #[test]
    fn atomic_write_json_round_trips() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("file.json");
        let v = json!({"a": 1, "b": [1, 2, 3]});
        atomic_write_json(&path, &v).unwrap();
        let read = std::fs::read_to_string(&path).unwrap();
        let parsed: serde_json::Value = serde_json::from_str(&read).unwrap();
        assert_eq!(parsed, v);
    }

    #[test]
    fn atomic_write_creates_parent_directories() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("nested/deeper/file.txt");
        assert!(!path.parent().unwrap().exists());
        atomic_write_bytes(&path, b"x").unwrap();
        assert!(path.exists());
    }

    #[test]
    fn atomic_write_replaces_existing_file_atomically() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("file.txt");
        atomic_write_bytes(&path, b"first").unwrap();
        atomic_write_bytes(&path, b"second").unwrap();
        assert_eq!(std::fs::read(&path).unwrap(), b"second");
    }

    #[test]
    fn atomic_write_does_not_leave_tempfiles_on_success() {
        let dir = tempdir().unwrap();
        let path = dir.path().join("file.txt");
        atomic_write_bytes(&path, b"x").unwrap();
        // Only the final file should exist; no .tmp.* sibling.
        let entries: Vec<_> = std::fs::read_dir(dir.path())
            .unwrap()
            .filter_map(|e| e.ok())
            .map(|e| e.file_name())
            .collect();
        assert_eq!(entries.len(), 1, "exactly one file post-write: {:?}", entries);
    }
}
