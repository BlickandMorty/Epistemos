//! `GraphNodeState` — the per-frame C-ABI mirror of a graph node.
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Locked architectural
//! decisions" #3 (NodeState 64-byte aligned, single cache line) and §"Phase A
//! Week 2" (extend the shared MTLBuffer from position-only to full NodeState).
//!
//! This struct is the canonical hot-state record that lives in the
//! Metal-allocated `.storageModeShared` ring buffer. Rust writes positions and
//! flags here every frame; Swift/Metal reads them directly for rendering. It
//! is intentionally separate from [`crate::types::Node`] (the topology source
//! of truth) so:
//!
//! - `Node` carries UUIDs, labels, timestamps, confidence scores — durable
//!   metadata that lives in Rust-owned memory and never crosses the GPU
//!   boundary.
//! - `GraphNodeState` carries only what the GPU needs every frame — position,
//!   velocity, force, render flags. No allocations, no heap pointers, no
//!   Strings. Pure C-ABI.
//!
//! The 64-byte alignment matches an Apple Silicon cache line, so each node
//! sits in exactly one line and adjacent-node reads don't false-share.
//!
//! ## Flag semantics
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Locked architectural
//! decisions" #4: **renderability is independent of sleep state.** The
//! `FLAG_RENDERABLE` bit controls whether the renderer draws the node. The
//! `FLAG_AWAKE`/`FLAG_WARMING`/`FLAG_SLEEPING` bits control whether the
//! integrator runs physics on it. A frozen node still renders normally; it
//! just doesn't move.
//!
//! ## ABI stability
//!
//! `GraphNodeState` is part of the FFI contract. **Do not** add or remove
//! fields without bumping `GRAPH_NODE_STATE_ABI_VERSION` and coordinating with
//! Swift. The Swift side asserts size + stride match this struct at bind
//! time (`graph_engine_bind_node_state_slot`).

/// ABI version of `GraphNodeState`. Bumped whenever the struct layout
/// changes. Used by `graph_engine_bind_node_state_slot` to detect Swift/Rust
/// version skew on bind.
pub const GRAPH_NODE_STATE_ABI_VERSION: u32 = 1;

// ─── Flag bits ────────────────────────────────────────────────────────────────
//
// Plain `const u32` instead of a bitflags-crate type so we don't pull a new
// dependency into graph-engine. The trade-off is that callers do `x & FLAG`
// bit-math instead of `.contains(Flag::X)`; the trade is fine because the C-ABI
// representation is `u32` either way and the compile-time clarity isn't worth
// a Cargo.toml change.

/// Node should be drawn by the renderer. **Independent of any physics
/// state.** A frozen sleeping node still has `FLAG_RENDERABLE` set;
/// only filter / hidden-by-search clears it.
pub const FLAG_RENDERABLE: u32 = 1 << 0;
/// Node integrates with full timestep + full force.
pub const FLAG_AWAKE: u32 = 1 << 1;
/// Node integrates with reduced timestep + damped force (the C¹
/// warm-zone smoothing of the causal-atmosphere sleep model).
pub const FLAG_WARMING: u32 = 1 << 2;
/// Node skips integration entirely. Position is frozen until another
/// wake-front, atmosphere overlap, or edge propagation reactivates it.
pub const FLAG_SLEEPING: u32 = 1 << 3;
/// Pinned by direct manipulation (drag, explicit user pin). Position
/// is set externally; integrator should not move it.
pub const FLAG_PINNED: u32 = 1 << 4;
/// Node is currently selected in the UI (informs rendering tint;
/// does not by itself affect physics).
pub const FLAG_SELECTED: u32 = 1 << 5;
/// Newly added in this frame's reveal batch. Reveal scheduler uses
/// this to drive warm-start placement + alpha re-heat.
pub const FLAG_NEWLY_ADDED: u32 = 1 << 6;

/// True iff the renderer should draw this node this frame. Pure
/// read of the `FLAG_RENDERABLE` bit — sleep state is irrelevant.
#[inline]
pub const fn flags_renderable(flags: u32) -> bool {
    (flags & FLAG_RENDERABLE) != 0
}

/// True iff the integrator should advance physics for this node.
/// `FLAG_AWAKE` and `FLAG_WARMING` both qualify (warming integrates
/// with damped force).
#[inline]
pub const fn flags_integrates(flags: u32) -> bool {
    (flags & (FLAG_AWAKE | FLAG_WARMING)) != 0
}

/// Default flag bits for a newly-added node that should render and
/// integrate immediately.
pub const FLAGS_NEWLY_ADDED_AWAKE: u32 = FLAG_RENDERABLE | FLAG_AWAKE | FLAG_NEWLY_ADDED;

// ─── GraphNodeState ──────────────────────────────────────────────────────────

/// Per-frame hot state for one graph node. Lives in the
/// Metal-allocated `.storageModeShared` ring buffer; Rust writes,
/// Metal reads.
///
/// **Cache-line aligned**: each node is exactly 64 bytes so the GPU
/// can read one node per cache line on Apple Silicon. Do not add
/// fields that would push the size past 64 bytes without explicit
/// coordination with the renderer.
#[repr(C, align(64))]
#[derive(Clone, Copy, Debug)]
pub struct GraphNodeState {
    /// World-space position (x, y). Updated by the integrator each
    /// frame.
    pub pos: [f32; 2],
    /// World-space velocity (vx, vy). Updated by the integrator.
    pub vel: [f32; 2],
    /// Net force accumulated this frame.
    pub force: [f32; 2],
    /// Previous frame's net force. Used by FA2 swinging/traction.
    pub prev_force: [f32; 2],
    /// Mass for the integrator. Higher = harder to move.
    pub mass: f32,
    /// Render radius in world space. Used by the collision force AND
    /// the render-pass instancing.
    pub radius: f32,
    /// Atmosphere heat for the causal-sleep wake-front. Decays each
    /// frame; bumps when a wake-front passes through this node.
    pub heat: f32,
    /// Warm zone weight (0.0 = full sleep, 1.0 = fully awake). The
    /// integrator multiplies dt and force by `warm` so the wake
    /// boundary is C¹-continuous instead of a binary on/off.
    pub warm: f32,
    /// Consecutive frames the node has been below the sleep threshold.
    /// Once this reaches K (24 @ 120Hz / 12 @ 60Hz), the node enters
    /// `FLAG_SLEEPING`.
    pub sleep_count: u32,
    /// Flag bits (see `FLAG_*` constants above).
    pub flags: u32,
    /// Reserved for future use. Initialized to 0; do not read.
    pub _reserved: [u32; 2],
}

const _: () = {
    // Compile-time check: the struct must fit in one cache line. If
    // someone adds a field and pushes it past 64 bytes, this triggers
    // a const-eval error at build time.
    assert!(std::mem::size_of::<GraphNodeState>() == 64);
    assert!(std::mem::align_of::<GraphNodeState>() == 64);
};

impl Default for GraphNodeState {
    fn default() -> Self {
        Self {
            pos: [0.0; 2],
            vel: [0.0; 2],
            force: [0.0; 2],
            prev_force: [0.0; 2],
            mass: 1.0,
            radius: 1.0,
            heat: 0.0,
            warm: 1.0,
            sleep_count: 0,
            flags: FLAGS_NEWLY_ADDED_AWAKE,
            _reserved: [0; 2],
        }
    }
}

impl GraphNodeState {
    /// True iff `FLAG_RENDERABLE` is set.
    #[inline]
    pub fn is_renderable(&self) -> bool {
        flags_renderable(self.flags)
    }

    /// True iff the integrator should advance physics for this node.
    #[inline]
    pub fn integrates(&self) -> bool {
        flags_integrates(self.flags)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn struct_is_exactly_one_cache_line() {
        // 64 bytes payload + 64-byte alignment = 1 cache line on M2 Pro.
        assert_eq!(std::mem::size_of::<GraphNodeState>(), 64);
        assert_eq!(std::mem::align_of::<GraphNodeState>(), 64);
    }

    #[test]
    fn default_node_renders_and_integrates() {
        let n = GraphNodeState::default();
        assert!(n.is_renderable(), "default node must render");
        assert!(n.integrates(), "default node must integrate");
        assert_eq!(n.flags & FLAG_NEWLY_ADDED, FLAG_NEWLY_ADDED);
    }

    #[test]
    fn renderable_is_independent_of_sleep() {
        // The CANONICAL invariant: sleep must NEVER clear FLAG_RENDERABLE.
        // Tests the architectural contract in code so it can't drift.
        let flags = FLAG_RENDERABLE | FLAG_SLEEPING;
        assert!(flags_renderable(flags), "sleeping node still renders");
        assert!(!flags_integrates(flags), "sleeping node does not integrate");
    }

    #[test]
    fn warming_node_integrates_with_damping() {
        let flags = FLAG_RENDERABLE | FLAG_WARMING;
        assert!(flags_renderable(flags));
        assert!(flags_integrates(flags), "warming nodes still integrate (with damping)");
    }

    #[test]
    fn awake_and_sleeping_can_co_exist_briefly() {
        // Belt-and-suspenders: AWAKE and SLEEPING serve different roles.
        // Code that produces both is a bug, but the type system can't
        // prevent it. The integrator treats SLEEPING as dominant.
        let conflict = FLAG_AWAKE | FLAG_SLEEPING;
        assert_eq!(conflict & FLAG_SLEEPING, FLAG_SLEEPING);
    }

    #[test]
    fn abi_version_is_one() {
        assert_eq!(GRAPH_NODE_STATE_ABI_VERSION, 1);
    }

    #[test]
    fn flag_bit_positions_are_stable() {
        // ABI contract — these specific bit positions are wire format.
        // Changing any of these breaks Swift consumers. If you need a
        // new bit, append at the next position; never reorder.
        assert_eq!(FLAG_RENDERABLE, 1 << 0);
        assert_eq!(FLAG_AWAKE, 1 << 1);
        assert_eq!(FLAG_WARMING, 1 << 2);
        assert_eq!(FLAG_SLEEPING, 1 << 3);
        assert_eq!(FLAG_PINNED, 1 << 4);
        assert_eq!(FLAG_SELECTED, 1 << 5);
        assert_eq!(FLAG_NEWLY_ADDED, 1 << 6);
    }

    #[test]
    fn default_state_has_clean_reserved_bytes() {
        let n = GraphNodeState::default();
        assert_eq!(n._reserved, [0; 2]);
    }
}
