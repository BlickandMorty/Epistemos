//! Adapter modules — wrap existing read-only parity infrastructure
//! behind v2's `Para` + `AgentRuntimeV2Capability` + `Sealer` surface.
//!
//! Each adapter:
//! - Implements `Para<P, A, B>` so the dispatcher can drive it
//!   uniformly.
//! - Verifies a `MacaroonCapability` before any side-effect.
//! - Debits the `BudgetGate` for the executor's resource use.
//! - Wraps mutations in `MutationEnvelope` and writes through `Sealer`.
//! - Preserves thinking blocks via `ParaOutput::thinking_digest`.
//! - Records `AgentEvent` rows into the caller's `RunEventLog`.
//!
//! Per W-46 absorb plan (doctrine §8), adapters land one per
//! `/loop` tick:
//!
//! - `local_agent` — `LocalAgentCapabilityRegistry` mirror (iter-17)
//! - `cloud_loop` — Anthropic / OpenAI provider absorbed (iter-27)
//!
//! The local-agent adapter now performs typed admission/provider planning;
//! live provider execution remains a System G responsibility.

pub mod local_agent;

pub use local_agent::{
    LocalAgentAdapter, LocalAgentCapabilityTier, LocalAgentDispatchError, LocalAgentDispatchPlan,
    LocalAgentDispatchRequest,
};
