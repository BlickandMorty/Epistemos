// R16 — Phase 13 ETL crawler foundation
//
// Per docs/RESEARCH_DOSSIER_TIER_3_4.md §R16: background ETL job
// that walks the user's vault, hashes files with xxh3, queues
// changed files in a SQLite-backed apalis queue, and triggers
// Apple Foundation Models @Generable sidecar generation in the
// Swift host process via a UniFFI callback.
//
// FOUNDATION (this commit ships):
//   - the `walker` module (gitignore-aware traversal via `ignore`)
//   - the `hash` module (xxh3-based content fingerprinting)
//   - the public `crawl_vault(root) -> Vec<VaultEntry>` entry point
// FOLLOW-UPS (per the dossier's PR plan):
//   - PR2: apalis-sql Monitor + WorkerBuilder (queue + crash recovery)
//   - PR3: AFM @Generable sidecar generation + Swift FFI exports
//          + ShadowVaultBootstrapper migration
//
// Crate state pinned per the dossier:
//   ignore = "0.4.25"
//   xxhash-rust = "0.8.15" (xxh3 feature)
//   apalis = "=1.0.0-rc.7"  (PR2)
//   apalis-sql = "0.7.3"    (PR2)

pub mod hash;
pub mod walker;

pub use hash::xxh3_64;
pub use walker::{crawl_vault, VaultEntry};
