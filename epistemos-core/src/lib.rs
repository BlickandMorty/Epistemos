// epistemos-core: Training-focused compute engine for Knowledge Fusion.
// Separate from graph-engine (which handles rendering/physics).
// Provides: vault analysis, auto-tuning, scheduling, BM25 retrieval, skill generation.

pub mod adaptation;
pub mod agent_runtime;
pub mod auto_tuner;
pub mod compute_steering;
pub mod inference_control;
pub mod instant_recall;
pub mod quality_filter;
pub mod recovery;
pub mod repo_analyzer;
pub mod retrieval;
pub mod runtime_contract;
pub mod scheduler;
pub mod skill_engine;
pub mod ssm_state;
pub mod training;
pub mod vault_analyzer;

// ── UniFFI Exports ──────────────────────────────────────────────────────────
// All types and functions referenced in the UDL must be in scope at crate root.

// Re-export types for UniFFI
pub use agent_runtime::{AgentEvent, AgentSession, AgentTurnResult};
pub use auto_tuner::hyperparams::AutoTuneConfig;
pub use inference_control::{
    SerialFallbackMode, SerialInferenceController, SerialInferenceSnapshot,
    SerialInferenceTransitionError,
};
pub use quality_filter::{DedupResult, QualityScore};
pub use recovery::{BinaryTextExtraction, BinaryTextRegion, CorruptionAnalysis, RepairCandidate};
pub use adaptation::{
    AdaptSessionConfig, AdaptSessionError, AdaptSessionSnapshot, AdaptUpdateResult,
    AdaptationSubsystem, SidecarSessionError, SidecarSessionSnapshot,
};
pub use compute_steering::{ComputeBudget, ComputeProfile, ExpertBudgetClass, KVPolicyKind};
pub use runtime_contract::{
    ExecutionMode, GenerationEventKind, ReasoningProfile, RuntimeCapabilities,
    RuntimeContractError, RuntimeControlPlane, RuntimeGenerationEvent,
    RuntimeGenerationRequest, RuntimeGenerationStreamOptions, RuntimeGenerationSummary,
    RuntimeHandshake, RuntimeHandshakeRequest, RuntimeKind, RuntimeModelHandle,
    RuntimeModelLoadRequest, RuntimeOperation, RuntimePolicy, RuntimeStats, RuntimeStatsTarget,
};
pub use scheduler::tier_scheduler::{TrainingDecision, TrainingTier};
pub use skill_engine::RoutingDecision;
pub use ssm_state::SSMStateError;
pub use vault_analyzer::boilerplate_filter::BoilerplateResult;
pub use vault_analyzer::chunker::ChunkDocumentResult;
pub use vault_analyzer::classifier::DocumentClassification;

// Re-export free functions for UniFFI scaffolding
pub use uniffi_exports::*;

mod uniffi_exports;

uniffi::include_scaffolding!("epistemos_core");
