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
//! ## Tier behaviour (locked)
//!
//! - **MAS V1 (`AgentRuntimeV2Mode::Disabled`)** — v2 is gated off. The legacy
//!   `agent_runtime::` paths remain active for App Store submission. v2 is
//!   strictly opt-in and must never reintroduce a Hermes subprocess.
//! - **Pro V1.x (`AgentRuntimeV2Mode::IpcBounded`)** — bounded, in-process
//!   executor. Macaroon verification + WBO budget + `MutationEnvelope` all
//!   active. Pro CLI adapters live in this mode through hardened
//!   `Command::new` paths (see `agent_core/src/security.rs`).
//! - **Research (`AgentRuntimeV2Mode::Subprocess`)** — gated subprocess
//!   adapter path for Pro Research builds only. Must remain behind a Cargo
//!   feature; never compiled into the MAS bundle.

pub mod blueprint;
pub mod budget;
pub mod capability;
pub mod envelope;
pub mod event;
pub mod mission;
pub mod mode;
pub mod para;

pub use blueprint::{
    AgentBlueprint, AgentBlueprintId, BlueprintModeError, CliAdapter, ProviderPolicy,
};
pub use budget::{BudgetDebit, BudgetError, BudgetGate, BudgetLedger, BudgetSpec, BudgetTerm};
pub use capability::{AgentRuntimeV2Capability, CapabilityError, MacaroonCapability};
pub use envelope::{MutationEnvelope, MutationWriter, Sealer, SealError};
pub use event::{AgentEvent, AgentEventErrorKind};
pub use mission::{MissionPacket, ToolCall, ToolCallError};
pub use mode::AgentRuntimeV2Mode;
pub use para::{Para, ParaError, ParaFeedback, ParaOutput, StopReason};
