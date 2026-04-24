//! Authored motion overlay — task 3+ of the v3 graph motion spec.
//!
//! The physics core owns the classical graph forces (springs, repulsion,
//! collision, center). This module layers on top with **authored** motion
//! primitives — visible ripple rings on release today, with curl-noise
//! ambient breathing and fluid-grid drag-current coupling landing in
//! subsequent commits. Each sub-module is self-contained and wires into
//! `Simulation::tick` at the insertion point described in
//! `docs/GRAPH_WAVES_PLAN.md` §3.

pub mod curl;
pub mod waves;
