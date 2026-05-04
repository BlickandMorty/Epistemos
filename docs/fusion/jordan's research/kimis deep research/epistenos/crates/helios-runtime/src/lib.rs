//! Helios Runtime — **Intent → Effect → State runtime**
//!
//! The `helios-runtime` crate is the cognitive operating system of Epistenos.
//! It implements:
//!
//! | Module | Responsibility |
//! |--------|---------------|
//! | [`types`] | Secure newtypes, `Intent`/`Effect`/`State`, pure `apply` kernel |
//! | [`gate`] | Resonance Gate — 8-field epistemic signature |
//! | [`scope_rex`] | SCOPE-Rex Omega — 8-vector event-sourced brain |
//! | [`self_tuning`] | TitansMAC + SEAL DoRA — self-evolving without destabilising base weights |
//! | [`ladder`] | Tool variant ladder — A→B→C→D with circuit breakers |
//! | [`agent`] | VaultGatedSwarm — biometric-gated, per-agent vaults |
//! | [`cli_adapter`] | Multi-CLI passthrough — Pro tier external-tool adapters |
//! | [`orchestrator`] | Multi-agent orchestrator — spawn, route, manage |
//! | [`events_v16`] | AgentEvent v1.6 forward variants — steering, summarization, vault lifecycle |
//! | [`auth_event`] | Sanitized OAuth token refresh audit event |
//!
//! ## Core philosophy
//!
//! The runtime follows a strict **Intent → Effect → State** pipeline:
//!
//! 1. **Intent** — what the user/agent *wants* (descriptive, not imperative)
//! 2. **Effect** — what *actually happened* (immutable, append-only, content-addressed)
//! 3. **State** — the observable result (reconstructible from effects)
//!
//! All state transitions are deterministic, pure, and auditable. The
//! [`BrainTimeMachine`](scope_rex::BrainTimeMachine) provides time-travel:
//! append, checkout, diff, and branch.
//!
//! ## Quick start
//!
//! ```rust,no_run
//! use helios_runtime::orchestrator::{Orchestrator, AgentDef};
//!
//! let mut orch = Orchestrator::new();
//! let def = AgentDef {
//!     agent_id: "planner-alpha".into(),
//!     role: "strategic_planner".into(),
//!     resonance_threshold: 0.85,
//!     vault_paths: vec!["/vault/plans".into()],
//!     tools: vec!["reason.plan".into()],
//! };
//! let id = orch.spawn_agent(&def).unwrap();
//! ```

pub mod agent;
pub mod auth_event;
pub mod cli_adapter;
pub mod events_v16;
pub mod gate;
pub mod ladder;
pub mod orchestrator;
pub mod scope_rex;
pub mod self_tuning;
pub mod types;

// Re-exports for convenience
pub use agent::*;
pub use auth_event::*;
pub use cli_adapter::*;
pub use events_v16::*;
pub use gate::*;
pub use ladder::*;
pub use orchestrator::*;
pub use scope_rex::*;
pub use self_tuning::*;
pub use types::*;
