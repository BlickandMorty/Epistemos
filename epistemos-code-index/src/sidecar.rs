//! Wave 9.7 sidecar path resolver — Rust counterpart of Swift's
//! `CodeSidecarPath` (`Epistemos/Models/CodeArtifactSidecar.swift`).
//!
//! Both sides MUST agree on the on-disk filename for a given
//! vault-relative source path or the indexer (Rust) and the editor
//! / chat surface (Swift) will read + write disjoint sidecars and
//! provenance lookups will silently miss.
//!
//! Canonical layout (mirrors Swift `CodeSidecarPath` exactly):
//!
//! ```text
//! <vault-root>/.epcache/code/<sha256-hex-of-vault-rel-path>.epcode.json
//! ```
//!
//! Swift uses `CryptoKit.SHA256.hash(data: vaultRelPath.utf8)` and
//! emits lowercase hex via `String(format: "%02x", $0)`. We mirror
//! that exactly here using the `sha2` crate.
//!
//! The hash is over the *vault-relative path*, NOT the file body.
//! Why: rename-detection. When the file moves inside the vault we
//! re-resolve via the new path-hash on the next index pass; the
//! sidecar isn't tied to a content snapshot.
//!
//! The path uses `/` separators on every platform. The Swift side
//! uses NSURL.appendingPathComponent which produces `/` on macOS,
//! and the indexer lives on macOS only. If we ever index on
//! Windows we'd have to canonicalise to forward-slashes here.

use std::path::PathBuf;

use sha2::{Digest, Sha256};

/// Subdirectory under the vault root that holds every code sidecar.
/// Mirrors Swift `CodeSidecarPath.cacheRoot`.
pub const CACHE_ROOT: &str = ".epcache";

/// Per-kind subdir keeps `code/`, future `notes/`, `chats/` etc.
/// cleanly partitioned. Mirrors Swift `CodeSidecarPath.codeSubdir`.
pub const CODE_SUBDIR: &str = "code";

/// Sidecar filename suffix. Mirrors Swift `CodeSidecarPath.suffix`.
pub const SIDECAR_SUFFIX: &str = ".epcode.json";

/// Lowercase-hex SHA-256 of a vault-relative path. Bit-for-bit
/// identical to Swift `CodeSidecarPath.pathHash(_:)`.
pub fn path_hash(vault_relative_path: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(vault_relative_path.as_bytes());
    hasher
        .finalize()
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
}

/// Absolute sidecar path for a vault root + vault-relative source
/// path. Bit-for-bit identical to the URL Swift's
/// `CodeSidecarPath.sidecarURL(forVaultRoot:vaultRelativePath:)`
/// produces.
pub fn sidecar_path(vault_root: &std::path::Path, vault_relative_path: &str) -> PathBuf {
    let hash = path_hash(vault_relative_path);
    vault_root
        .join(CACHE_ROOT)
        .join(CODE_SUBDIR)
        .join(format!("{hash}{SIDECAR_SUFFIX}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Canonical fixture computed via:
    ///   `printf "Sources/Foo.swift" | shasum -a 256`
    /// MUST match Swift's CryptoKit.SHA256.hash(data:Data("Sources/Foo.swift".utf8))
    /// → hex map { String(format: "%02x", $0) } join.
    #[test]
    fn path_hash_matches_swift_fixture_sources_foo_swift() {
        let actual = path_hash("Sources/Foo.swift");
        let expected = "39bc16e7a9d9b0de5235a376cc02378430c12fec14af81d93723904ffbe11580";
        assert_eq!(
            actual, expected,
            "Rust path_hash MUST equal Swift CodeSidecarPath.pathHash for the same input. \
             If this drifts, the indexer + editor will read + write disjoint sidecars."
        );
    }

    #[test]
    fn path_hash_is_deterministic_and_lowercase() {
        let h1 = path_hash("a/b/c.rs");
        let h2 = path_hash("a/b/c.rs");
        assert_eq!(h1, h2);
        assert_eq!(h1.len(), 64, "SHA-256 hex is 64 chars");
        assert!(
            h1.chars().all(|c| c.is_ascii_hexdigit() && !c.is_ascii_uppercase()),
            "hash MUST be lowercase hex; got {h1}"
        );
    }

    #[test]
    fn path_hash_differs_for_different_inputs() {
        // Sanity: trivial collision guard.
        let a = path_hash("Sources/Foo.swift");
        let b = path_hash("Sources/Bar.swift");
        assert_ne!(a, b);
    }

    #[test]
    fn path_hash_handles_empty_string() {
        // SHA-256 of empty string is a fixed value; Swift produces the
        // same digest for the empty path. Useful when callers index a
        // sentinel doc.
        let actual = path_hash("");
        let expected = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
        assert_eq!(actual, expected);
    }

    #[test]
    fn sidecar_path_assembles_full_url() {
        let vault = std::path::Path::new("/tmp/vault");
        let p = sidecar_path(vault, "Sources/Foo.swift");
        assert_eq!(
            p,
            std::path::PathBuf::from(
                "/tmp/vault/.epcache/code/39bc16e7a9d9b0de5235a376cc02378430c12fec14af81d93723904ffbe11580.epcode.json"
            )
        );
    }
}
