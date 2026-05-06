//! HELIOS V5 W17/W18/W19 + PCF-1..PCF-3 + PCF-7..PCF-8 — VPD substrate.
//!
//! Per `docs/HELIOS_V5_INTEGRATION_PLAN_v2_FINALIZE_2026_05_05.md` §B:
//!
//! - **PCF-1 ParamAnchor**: VPD extraction → frozen anchor library
//! - **PCF-2 QKEdgeAnchor**: attention edge per W_QK^h decomposition
//! - **PCF-3 ParamAttributionGraph**: graph over parameter components
//! - **PCF-4 ComponentRoute**: route inference through component subset
//! - **PCF-7 DualConnectomeTrace**: parameter-space + activation-space
//! - **PCF-8 Parameter Connectome Sheaf Consistency**
//!
//! All substrate types `state: implemented` until M2 Max falsifier
//! rig (W25) verifies recovery on the Goodfire SPD toy model. PCF-5
//! (Active Rank-One Runtime) and PCF-6 (ModelSurgery) and PCF-9
//! (Connectome Distillation) and PCF-10 (Interpretability-to-Runtime
//! Transfer) live in the [`epistemos-vault`] crate per §B Lane 5.

pub mod anchor;
pub mod attribution_graph;
pub mod component_route;
pub mod connectome_sheaf;
pub mod dual_trace;
pub mod extract;
pub mod qk_edge;
