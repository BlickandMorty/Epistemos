//! Phase 0.5 — first-run bootstrap.
//!
//! Plan: docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md §11 Phase 0.5.
//!
//! Four sub-steps from the plan:
//!   1. Vault location (default ~/Documents/Epistemos)
//!   2. Background model download — descriptors live in `ROUTER_CANDIDATES`
//!      and `EMBEDDING_CANDIDATES`; the actual download is a Swift concern
//!      (HuggingFace Swift SDK via `ModelDownloadManager`)
//!   3. Initial folder scaffold (_inbox, _inbox/review, daily, notes)
//!   4. First-capture tooltip (Swift UI concern)
//!
//! This module owns (1)+(3) plus the metadata stamp at `.epistemos/vault.json`.
//! Idempotent by construction: re-running on an already-bootstrapped vault
//! returns `was_fresh = false` and preserves the original `created_at`.
//! Atomic writes per plan §6.9.

use std::io;
use std::path::{Path, PathBuf};

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
// `tempfile` import removed — atomic writes now go through
// `crate::util::atomic_write_json` per the Phase audit.


const VAULT_METADATA_REL: &str = ".epistemos/vault.json";
const SCHEMA_VERSION: u32 = 1;

const SCAFFOLD_FOLDERS: &[&str] = &["_inbox", "_inbox/review", "daily", "notes"];

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
pub struct VaultMetadata {
    pub schema_version: u32,
    pub created_at: DateTime<Utc>,
    pub embedding_model_pin: Option<String>,
    pub router_model_pin: Option<String>,
}

#[derive(Debug, Clone)]
pub struct BootstrapReceipt {
    pub vault_path: PathBuf,
    pub metadata_path: PathBuf,
    pub created_folders: Vec<PathBuf>,
    pub was_fresh: bool,
    pub metadata: VaultMetadata,
}

/// Default vault root — `~/Documents/Epistemos` per plan §11 Phase 0.5.
/// Falls back to `~/Epistemos` if Documents isn't resolvable, then to
/// `./Epistemos` as a last resort (keeps tests / sandboxed callers working).
pub fn default_vault_path() -> PathBuf {
    if let Some(docs) = dirs::document_dir() {
        return docs.join("Epistemos");
    }
    if let Some(home) = dirs::home_dir() {
        return home.join("Epistemos");
    }
    PathBuf::from("Epistemos")
}

/// True when the vault has not been bootstrapped (no metadata stamp present).
/// A directory that exists but lacks `.epistemos/vault.json` is fresh.
pub fn is_fresh(vault_path: &Path) -> bool {
    !vault_path.join(VAULT_METADATA_REL).exists()
}

/// Idempotent bootstrap: creates the scaffold folders + metadata stamp.
/// On a fresh vault: writes new metadata, reports every created folder.
/// On a bootstrapped vault: re-reads existing metadata, reports no creations.
pub fn bootstrap(vault_path: &Path) -> io::Result<BootstrapReceipt> {
    let was_fresh = is_fresh(vault_path);

    std::fs::create_dir_all(vault_path)?;

    let mut created = Vec::new();
    for rel in SCAFFOLD_FOLDERS {
        let abs = vault_path.join(rel);
        if !abs.exists() {
            std::fs::create_dir_all(&abs)?;
            created.push(abs);
        }
    }

    let metadata_dir = vault_path.join(".epistemos");
    std::fs::create_dir_all(&metadata_dir)?;
    let metadata_path = vault_path.join(VAULT_METADATA_REL);

    let metadata = if was_fresh {
        let m = VaultMetadata {
            schema_version: SCHEMA_VERSION,
            created_at: Utc::now(),
            embedding_model_pin: None,
            router_model_pin: None,
        };
        crate::util::atomic_write_json(&metadata_path, &m)?;
        m
    } else {
        read_metadata(&metadata_path)?
    };

    Ok(BootstrapReceipt {
        vault_path: vault_path.to_path_buf(),
        metadata_path,
        created_folders: created,
        was_fresh,
        metadata,
    })
}

pub fn read_metadata(path: &Path) -> io::Result<VaultMetadata> {
    let bytes = std::fs::read(path)?;
    serde_json::from_slice(&bytes)
        .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))
}

// Atomic write helper moved to `crate::util::atomic_write_json` (Phase
// audit: shared with `format::soul::SoulPair::write` per §6.9).

/// Phase-0.5 router-model candidates. Plan §6.6.1 anchors the default at
/// Qwen 2.5-1.5B (highest BFCL refusal-correctness in the calibrated set).
/// Qwen 3.5-0.8B / 2B are registered alongside because 2026-04 community
/// benchmarks (dev.to/thefalkonguy MLX install, blog.mean.ceo Qwen 3.5
/// release notes, betterstack.com Qwen 3.5 small-models guide) show 3.5-0.8B
/// reaching ~100% classification accuracy with 3 in-prompt exemplars (which
/// the plan mandates anyway), and 3.5-2B reaching ~100% zero-shot. Phase 6.5
/// per-model bench (PLAN §11) picks the empirical winner; until then the
/// plan default is canonical.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RouterCandidate {
    pub hf_id: &'static str,
    pub display: &'static str,
    pub resident_mb_4bit: u32,
    pub plan_default: bool,
}

pub const ROUTER_CANDIDATES: &[RouterCandidate] = &[
    RouterCandidate {
        hf_id: "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
        display: "Qwen 2.5 1.5B Instruct (4-bit)",
        resident_mb_4bit: 1024,
        plan_default: true,
    },
    RouterCandidate {
        hf_id: "mlx-community/Qwen3.5-0.8B-4bit",
        display: "Qwen 3.5 0.8B (4-bit)",
        resident_mb_4bit: 512,
        plan_default: false,
    },
    RouterCandidate {
        hf_id: "mlx-community/Qwen3.5-2B-4bit",
        display: "Qwen 3.5 2B (4-bit)",
        resident_mb_4bit: 1280,
        plan_default: false,
    },
];

pub fn default_router() -> &'static RouterCandidate {
    ROUTER_CANDIDATES
        .iter()
        .find(|c| c.plan_default)
        .expect("exactly one router candidate must be marked plan_default")
}

/// Embedding-model candidates per plan §6.6.7–§6.6.9. bge-small-en-v1.5 is
/// always-resident in the daily-driver path (Variant A runs every capture).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct EmbeddingCandidate {
    pub hf_id: &'static str,
    pub display: &'static str,
    pub dims: u32,
    pub resident_mb: u32,
    pub plan_default: bool,
}

pub const EMBEDDING_CANDIDATES: &[EmbeddingCandidate] = &[
    EmbeddingCandidate {
        hf_id: "mlx-community/bge-small-en-v1.5-mlx",
        display: "BGE Small EN v1.5",
        dims: 384,
        resident_mb: 50,
        plan_default: true,
    },
    EmbeddingCandidate {
        hf_id: "mlx-community/nomic-embed-text-v1.5-mlx",
        display: "Nomic Embed Text v1.5 (8k context)",
        dims: 768,
        resident_mb: 140,
        plan_default: false,
    },
    EmbeddingCandidate {
        hf_id: "mlx-community/bge-large-en-v1.5-mlx",
        display: "BGE Large EN v1.5",
        dims: 1024,
        resident_mb: 250,
        plan_default: false,
    },
];

pub fn default_embedding() -> &'static EmbeddingCandidate {
    EMBEDDING_CANDIDATES
        .iter()
        .find(|c| c.plan_default)
        .expect("exactly one embedding candidate must be marked plan_default")
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::tempdir;

    #[test]
    fn fresh_bootstrap_creates_all_scaffold_folders() {
        let dir = tempdir().unwrap();
        let receipt = bootstrap(dir.path()).unwrap();

        assert!(receipt.was_fresh);
        assert_eq!(receipt.created_folders.len(), SCAFFOLD_FOLDERS.len());
        for rel in SCAFFOLD_FOLDERS {
            assert!(
                dir.path().join(rel).is_dir(),
                "scaffold folder {} missing",
                rel
            );
        }
        assert!(receipt.metadata_path.exists());
        assert_eq!(receipt.metadata.schema_version, SCHEMA_VERSION);
        assert_eq!(receipt.metadata.embedding_model_pin, None);
        assert_eq!(receipt.metadata.router_model_pin, None);
    }

    #[test]
    fn bootstrap_is_idempotent_and_preserves_created_at() {
        let dir = tempdir().unwrap();
        let first = bootstrap(dir.path()).unwrap();
        // Sleep is not needed — created_at survives because the second call
        // re-reads the existing metadata rather than rewriting it.
        let second = bootstrap(dir.path()).unwrap();

        assert!(first.was_fresh);
        assert!(!second.was_fresh, "second call must not report fresh");
        assert!(
            second.created_folders.is_empty(),
            "no new folders on idempotent re-run, got {:?}",
            second.created_folders
        );
        assert_eq!(
            first.metadata.created_at, second.metadata.created_at,
            "created_at must survive idempotent re-run"
        );
    }

    #[test]
    fn metadata_round_trips_via_atomic_write() {
        let dir = tempdir().unwrap();
        let receipt = bootstrap(dir.path()).unwrap();
        let read = read_metadata(&receipt.metadata_path).unwrap();
        assert_eq!(read, receipt.metadata);
    }

    #[test]
    fn is_fresh_reports_correctly_before_and_after() {
        let dir = tempdir().unwrap();
        assert!(is_fresh(dir.path()), "empty dir must be fresh");
        bootstrap(dir.path()).unwrap();
        assert!(
            !is_fresh(dir.path()),
            "post-bootstrap must not be fresh"
        );
    }

    #[test]
    fn partial_scaffold_recovers_on_re_bootstrap() {
        // Simulates a crash mid-bootstrap: metadata absent, some folders present.
        let dir = tempdir().unwrap();
        fs::create_dir_all(dir.path().join("notes")).unwrap();
        // No .epistemos/vault.json yet — should still be fresh.
        assert!(is_fresh(dir.path()));
        let receipt = bootstrap(dir.path()).unwrap();
        assert!(receipt.was_fresh);
        // Created folders exclude the pre-existing `notes`.
        assert_eq!(receipt.created_folders.len(), SCAFFOLD_FOLDERS.len() - 1);
        for rel in SCAFFOLD_FOLDERS {
            assert!(dir.path().join(rel).is_dir());
        }
    }

    #[test]
    fn default_vault_path_ends_in_epistemos() {
        let p = default_vault_path();
        assert_eq!(p.file_name().and_then(|s| s.to_str()), Some("Epistemos"));
    }

    #[test]
    fn router_candidates_have_exactly_one_plan_default() {
        let count = ROUTER_CANDIDATES
            .iter()
            .filter(|c| c.plan_default)
            .count();
        assert_eq!(count, 1, "exactly one ROUTER_CANDIDATES.plan_default");

        let default = default_router();
        assert_eq!(
            default.hf_id, "mlx-community/Qwen2.5-1.5B-Instruct-4bit",
            "plan §6.6.1 anchors the default at Qwen 2.5-1.5B"
        );
    }

    #[test]
    fn embedding_candidates_have_exactly_one_plan_default() {
        let count = EMBEDDING_CANDIDATES
            .iter()
            .filter(|c| c.plan_default)
            .count();
        assert_eq!(count, 1, "exactly one EMBEDDING_CANDIDATES.plan_default");
        assert_eq!(default_embedding().dims, 384);
    }

    #[test]
    fn router_candidates_cover_all_three_plan_options() {
        let ids: Vec<&str> = ROUTER_CANDIDATES.iter().map(|c| c.hf_id).collect();
        assert!(ids.iter().any(|id| id.contains("Qwen2.5-1.5B")));
        assert!(ids.iter().any(|id| id.contains("Qwen3.5-0.8B")));
        assert!(ids.iter().any(|id| id.contains("Qwen3.5-2B")));
    }
}
