//! Plan-canonical path: `agent_core/src/heal/breaker.rs` per §11 Phase 4.
//! The CircuitBreaker type itself lives at `tools/breaker.rs` (Phase 2C
//! shipped it for the variant runner per §5.3 + §3.2 — same state
//! machine, two consumers). This module re-exports so callers using
//! the plan-literal path get the canonical type without duplication.

pub use crate::tools::breaker::{BreakerError, BreakerState, CircuitBreaker};
