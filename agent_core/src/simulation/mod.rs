//! Simulation Mode core (S4; DOCTRINE I-7 / IMPLEMENTATION §2.1).
//!
//! Per DOCTRINE I-7 Rust owns simulation state; Swift owns
//! rendering and lifecycle. This module is the Rust half:
//!
//!   - `state` holds `SimulationState` (per-companion FSM) and
//!     `AgentVisualState` (the visual record per agent the
//!     reducer mutates).
//!   - `reducer` is the pure `fn reduce(&mut state, &event,
//!     event_seq) -> Vec<FrameDelta>`. Single-threaded;
//!     deterministic per I-13.
//!   - `sim` is the `Simulation` UniFFI bridge — the boot-strap
//!     control surface Swift uses to obtain a raw `*const
//!     DeltaRing` handle for hot-path drains.
//!
//! The simulation never reads system clocks per I-13; time
//! comes from `LogEntry::ts` at log-write time and from
//! caller-supplied `Instant` for the activity tracker tick.

pub mod reducer;
pub mod sim;
pub mod state;

pub use reducer::reduce;
pub use sim::{
    epistemos_simulation_active_rooms, epistemos_simulation_create,
    epistemos_simulation_delta_ring_handle, epistemos_simulation_destroy,
    epistemos_simulation_inject_test_companions, epistemos_simulation_process_event_json,
    MemberFFI, RoomFFI, Simulation,
};
pub use state::{AgentVisualState, AnimationState, SessionMeta, SimulationState};
