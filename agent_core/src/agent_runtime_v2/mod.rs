//! Agent Runtime v2 — System G / Invader Agent.
//!
//! Canonical: System G / Invader Agent is the user-visible name. `Aegis` is
//! REJECTED — the name was explicitly rejected by user direction and must not
//! appear anywhere in code, docs, or comments. The neutral code namespace is
//! `agent_runtime_v2`.
//!
//! Doctrine doc: `docs/AGENT_RUNTIME_V2_SYSTEM_G_DOCTRINE_2026_05_18.md`.
//! Prior design extract: `docs/HERMES_AGENT_CORE_2_0_DESIGN_2026_05_15.md`
//! (read for design intent only — namespace renamed, Hermes subprocess stays
//! purged).
//!
//! ## Acceptance bar (from §4 T11)
//!
//! 1. `Para<P, A, B>` with `fwd` and `rev`.
//! 2. `AgentRuntimeV2Capability`, `AgentRuntimeV2Mode::{Disabled, IpcBounded,
//!    Subprocess}`, WBO budget check, macaroon verification, `MutationEnvelope`
//!    output wrapping.
//! 3. Canonical flow:
//!    `AgentBlueprint → MissionPacket → AgentEvent stream → approval →
//!     MutationEnvelope → RunEventLog → AnswerPacket`.
//! 4. Property tests: forged macaroon rejected, expired macaroon rejected,
//!    over-budget call rejected, reverse leg cannot mutate `stop_reason`,
//!    thinking blocks hash-identical.
//! 5. Tests: MAS cannot call CLI; malformed tool call rejected; denied
//!    mutation does not write; AnswerPacket emitted.
//!
//! ## Build/status behaviour (locked)
//!
//! - **MAS V1 (`AgentRuntimeV2Mode::Disabled`)** — v2 is gated off. The legacy
//!   `agent_runtime::` paths remain active for App Store submission. v2 is
//!   strictly opt-in and must never reintroduce a Hermes subprocess.
//! - **Pro V1.x (`AgentRuntimeV2Mode::IpcBounded`)** — bounded, in-process
//!   executor. Macaroon verification + WBO budget + `MutationEnvelope` all
//!   active. Pro CLI adapters live in this mode through hardened
//!   `Command::new` paths (see `agent_core/src/security.rs`).
//! - **Pro Research status (`AgentRuntimeV2Mode::Subprocess`)** — gated
//!   subprocess adapter path for Pro Research status only. Must remain behind
//!   a Cargo feature; never compiled into the MAS bundle.

pub mod acs_run_event_log_sink;
pub mod adapters;
pub mod answer;
pub mod blueprint;
pub mod budget;
pub mod capability;
pub mod compose;
pub mod dynamic_checkpoint;
pub mod envelope;
pub mod event;
pub mod fixtures;
pub mod mission;
pub mod mission_run;
pub mod mode;
pub mod naming_lint;
pub mod para;
pub mod run_event_log;
pub mod system_g_runtime;
pub mod trinity_async;
pub mod trinity_executor;
pub mod trinity_loop;
pub mod trinity_orchestrator;
pub mod trinity_provider;
pub mod trinity_routing;
pub mod trinity_trace;
pub mod variant_ladder;

pub use acs_run_event_log_sink::ACSRunEventLogSink;
pub use answer::{AnswerPacket, Citation};
pub use blueprint::{
    AgentBlueprint, AgentBlueprintId, BlueprintModeError, CliAdapter, ProviderPolicy,
};
pub use budget::{BudgetDebit, BudgetError, BudgetGate, BudgetLedger, BudgetSpec, BudgetTerm};
pub use capability::{AgentRuntimeV2Capability, CapabilityError, MacaroonCapability};
pub use compose::{ParaSeq, ParaSeqFeedback, ParaSeqOutput};
pub use dynamic_checkpoint::{
    DynamicComputeCheckpoint, DynamicComputeCheckpointError, DynamicComputeCheckpointKind,
    DYNAMIC_COMPUTE_CHECKPOINT_FALSIFIER_ID,
};
pub use envelope::{MutationEnvelope, MutationWriter, SealError, Sealer};
pub use event::{AgentEvent, AgentEventErrorKind};
pub use mission::{MissionPacket, MissionPromptError, ToolCall, ToolCallError};
pub use mission_run::{MissionRun, ToolCallAdmissionError, ToolCallAdmissionHandoff};
pub use mode::AgentRuntimeV2Mode;
pub use naming_lint::{
    count_hits, is_path_exempt, scan_text, text_contains_rejected_name, RejectedNameMatch,
    AEGIS_LINT_EXEMPT_DOCS, REJECTED_NAME_LOWERCASE,
};
pub use para::{Para, ParaError, ParaFeedback, ParaOutput, StopReason};
pub use run_event_log::{LogValidationError, RunEventEntry, RunEventLog};
pub use system_g_runtime::{SystemGAgentEvent, SystemGRuntimeError};
pub use variant_ladder::{VariantLadderError, VariantLadderSpec, VariantTier};
