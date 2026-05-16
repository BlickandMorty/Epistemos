//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md` §5
//!   Phase B.1 J9 row — "MLSys / NeurIPS papers extraction + landing".
//! - `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` — Epistemos's
//!   canonical concept-to-source map. This module is its programmatic
//!   counterpart: a structured registry future agents can query
//!   without parsing markdown.
//!
//! # Wave J9 — Paper-claim registry (completes Wave J substrate floor)
//!
//! Sibling modules (J1 ternary, J2 cognition_observatory, J3
//! continual_learning, J5 acs, J6 hyperdynamic_schemas, J7
//! sherry_lattice, J8 ane_direct) all carry `//! Source:` citations
//! to arXiv papers, journal articles, and Apple private-framework
//! references. J9 collects those citations into one Rust-side
//! structured surface so:
//!
//! - The control room UI can render "which papers does this substrate
//!   actually implement?" without scraping rustdoc.
//! - The §8 audit-of-audit can verify that every cited paper still
//!   resolves (arXiv ID format-check + cross-reference to local docs).
//! - Future iters can register new claims as MLSys / NeurIPS / ICLR /
//!   etc. papers land in the wider corpus.
//!
//! Substrate floor seeds the registry with the J1-J8 citations
//! already in tree.

pub mod claim;
pub mod seed;

pub use claim::{
    ClaimStatus, PaperClaim, PaperRegistry, RegistryError, Venue,
};
pub use seed::seed_wave_j_registry;
