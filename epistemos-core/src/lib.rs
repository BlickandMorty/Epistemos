// epistemos-core: Training-focused compute engine for Knowledge Fusion.
// Separate from graph-engine (which handles rendering/physics).
// Provides: vault analysis, auto-tuning, scheduling, BM25 retrieval, skill generation.

pub mod vault_analyzer;
pub mod auto_tuner;
pub mod scheduler;
pub mod skill_engine;
pub mod retrieval;
pub mod repo_analyzer;
pub mod training;

// ── UniFFI Exports ──────────────────────────────────────────────────────────
// All types and functions referenced in the UDL must be in scope at crate root.

// Re-export types for UniFFI
pub use auto_tuner::hyperparams::AutoTuneConfig;
pub use scheduler::tier_scheduler::{TrainingDecision, TrainingTier};
pub use vault_analyzer::classifier::DocumentClassification;
pub use vault_analyzer::boilerplate_filter::BoilerplateResult;

// Re-export free functions for UniFFI scaffolding
pub use uniffi_exports::*;

mod uniffi_exports;

uniffi::include_scaffolding!("epistemos_core");
