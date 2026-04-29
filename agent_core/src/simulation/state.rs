//! `SimulationState` — per-companion FSM that the reducer
//! mutates per `AgentEvent` (S4; DOCTRINE §3 placements + §5.3
//! 14-state animation rig).
//!
//! Holds an `AgentVisualState` per registered companion plus a
//! small bag of session-level metadata (currently active
//! sessions). Per DOCTRINE I-13 this struct is **pure data**:
//! no time fields are sourced from `Instant::now()` here;
//! callers pass timestamps in.

use std::collections::{BTreeMap, HashSet};

use serde::{Deserialize, Serialize};

use crate::companions::{CompanionId, PropKind};
use crate::events::SessionId;
use crate::ffi::{PerInstanceData, StateFlags};

/// 14-state animation rig per DOCTRINE §5.3. The reducer maps
/// `AgentEvent` variants onto these states; the Metal renderer
/// (S4 Swift side) uses `frame_index` within each state to drive
/// the per-frame atlas slice.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AnimationState {
    Idle,
    Walk,
    Think,
    Speak,
    Tool,
    Spawn,
    HandoffGive,
    HandoffReceive,
    Retrieve,
    Error,
    Recover,
    Success,
    Sleep,
    Gate,
}

impl AnimationState {
    /// Frame count per state per DOCTRINE §5.3 table. Used by
    /// the reducer to advance `frame_index` within bounds when
    /// emitting per-frame deltas. (S4 ships placeholder
    /// rectangles, so frame counts don't yet drive atlas
    /// sampling; S10 wires the real atlas.)
    pub fn frame_count(self) -> u32 {
        match self {
            AnimationState::Idle => 4,
            AnimationState::Walk => 8,
            AnimationState::Think => 6,
            AnimationState::Speak => 4,
            AnimationState::Tool => 6,
            AnimationState::Spawn => 5,
            AnimationState::HandoffGive => 8,
            AnimationState::HandoffReceive => 6,
            AnimationState::Retrieve => 6,
            AnimationState::Error => 4,
            AnimationState::Recover => 6,
            AnimationState::Success => 4,
            AnimationState::Sleep => 4,
            AnimationState::Gate => 2,
        }
    }

    /// Loop or single-shot per DOCTRINE §5.3. Loops continue
    /// until a state transition; single-shots advance to `Idle`
    /// after one playthrough.
    pub fn loops(self) -> bool {
        matches!(
            self,
            AnimationState::Idle
                | AnimationState::Walk
                | AnimationState::Think
                | AnimationState::Speak
                | AnimationState::Tool
                | AnimationState::Recover
                | AnimationState::Sleep
                | AnimationState::Gate
        )
    }

    /// Atlas-index hint. The Metal renderer pre-builds atlases
    /// per head shape; this lookup helps the reducer suggest
    /// which row in the atlas to sample. S4 placeholder uses 0.
    pub fn atlas_row(self) -> u32 {
        match self {
            AnimationState::Idle => 0,
            AnimationState::Walk => 1,
            AnimationState::Think => 2,
            AnimationState::Speak => 3,
            AnimationState::Tool => 4,
            AnimationState::Spawn => 5,
            AnimationState::HandoffGive => 6,
            AnimationState::HandoffReceive => 7,
            AnimationState::Retrieve => 8,
            AnimationState::Error => 9,
            AnimationState::Recover => 10,
            AnimationState::Success => 11,
            AnimationState::Sleep => 12,
            AnimationState::Gate => 13,
        }
    }
}

/// One companion's mutable render record. The reducer transitions
/// this on each `AgentEvent` and emits a `FrameDelta` so the
/// renderer (Swift) refreshes that companion's instance data.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AgentVisualState {
    pub id: CompanionId,
    /// Scene-space position (floats here; integer-snap happens
    /// in the vertex shader per I-16).
    pub position: [f32; 2],
    /// Sprite scale — restricted to integer multiples 1..=4 per
    /// I-16. The reducer asserts in debug builds; production
    /// clamps to `round()` before pushing to the ring.
    pub scale: f32,
    pub palette_id: u32,
    pub tint: [f32; 4],
    pub atlas_index: u32,
    pub current_animation: AnimationState,
    pub current_frame: u32,
    pub held_prop: Option<PropKind>,
    pub state_flags: u32,
}

impl AgentVisualState {
    /// Initial state for a freshly-joined companion. Position
    /// defaults to origin; the placement view-models (S5/S7)
    /// drive layout at the visual layer.
    pub fn initial_for(id: CompanionId) -> Self {
        Self {
            id,
            position: [0.0, 0.0],
            scale: 1.0,
            palette_id: 0,
            tint: [1.0, 1.0, 1.0, 1.0],
            atlas_index: 0,
            current_animation: AnimationState::Idle,
            current_frame: 0,
            held_prop: None,
            state_flags: 0,
        }
    }

    /// Transition into a new animation state. Resets
    /// `current_frame` to 0 only when actually changing state —
    /// idempotent transitions don't reset (avoids per-event
    /// frame jitter).
    pub fn transition_to(&mut self, next: AnimationState) {
        if self.current_animation != next {
            self.current_animation = next;
            self.current_frame = 0;
            self.atlas_index = next.atlas_row();
        }
    }

    /// Snapshot for FFI ring push. Clamps scale to integer per
    /// I-16; production callers `debug_assert!` upstream so the
    /// clamp is a safety net, not the canonical enforcement.
    pub fn snapshot_for_render(&self) -> PerInstanceData {
        debug_assert!(
            (self.scale - self.scale.round()).abs() < 1e-6,
            "fractional sprite scale {}: violates I-16",
            self.scale
        );
        let s = self.scale.round().clamp(1.0, 4.0);
        let mut data = PerInstanceData::new(self.id);
        data.position = self.position;
        data.scale = [s, s];
        data.atlas_index = self.atlas_index;
        data.frame_index = self.current_frame;
        data.palette_id = self.palette_id;
        data.tint = self.tint;
        data.state_flags = self.state_flags;
        data
    }

    pub fn set_state_flag(&mut self, flag: StateFlags, on: bool) {
        let mut f: StateFlags = self.state_flags.into();
        if on {
            f.insert(flag);
        } else {
            f.remove(flag);
        }
        self.state_flags = f.into();
    }
}

/// The simulation's full per-companion state. Mutated by the
/// reducer; never accessed concurrently from multiple threads
/// (single-writer per IMPLEMENTATION §2.1).
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct SimulationState {
    /// All known companions, keyed by id. `BTreeMap` for stable
    /// ordering at serialisation / replay-digest time.
    pub agents: BTreeMap<CompanionId, AgentVisualState>,
    /// Currently-running sessions. Used to enforce DOCTRINE I-2
    /// (every visible action belongs to a session) at S4+ —
    /// today we just track membership.
    pub active_sessions: HashSet<SessionId>,
    /// Total events applied. Diagnostics + audit cross-check.
    pub event_count: u64,
}

impl SimulationState {
    pub fn initial() -> Self {
        Self::default()
    }

    pub fn agent(&self, id: CompanionId) -> Option<&AgentVisualState> {
        self.agents.get(&id)
    }

    pub fn agent_mut(&mut self, id: CompanionId) -> Option<&mut AgentVisualState> {
        self.agents.get_mut(&id)
    }

    /// Insert (or no-op if already present) a companion at its
    /// initial state.
    pub fn ensure_agent(&mut self, id: CompanionId) -> &mut AgentVisualState {
        self.agents
            .entry(id)
            .or_insert_with(|| AgentVisualState::initial_for(id))
    }

    pub fn agent_count(&self) -> usize {
        self.agents.len()
    }

    pub fn snapshot_all(&self) -> Vec<PerInstanceData> {
        self.agents.values().map(|a| a.snapshot_for_render()).collect()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ffi::StateFlags;

    fn cid() -> CompanionId {
        CompanionId::new_ulid()
    }

    #[test]
    fn ensure_agent_inserts_on_first_call_only() {
        let mut s = SimulationState::initial();
        let alice = cid();
        s.ensure_agent(alice).position = [10.0, 5.0];
        assert_eq!(s.agent_count(), 1);
        // Second call returns existing without resetting.
        s.ensure_agent(alice);
        assert_eq!(s.agent_count(), 1);
        assert_eq!(s.agent(alice).unwrap().position, [10.0, 5.0]);
    }

    #[test]
    fn transition_to_resets_frame_only_on_change() {
        let mut a = AgentVisualState::initial_for(cid());
        a.current_frame = 3;
        a.transition_to(AnimationState::Idle); // same state — no reset
        assert_eq!(a.current_frame, 3);
        a.transition_to(AnimationState::Walk); // different state — reset
        assert_eq!(a.current_frame, 0);
        assert_eq!(a.current_animation, AnimationState::Walk);
        // Atlas index follows.
        assert_eq!(a.atlas_index, AnimationState::Walk.atlas_row());
    }

    #[test]
    fn snapshot_for_render_clamps_scale_to_integer() {
        let mut a = AgentVisualState::initial_for(cid());
        a.scale = 2.0;
        let snap = a.snapshot_for_render();
        assert_eq!(snap.scale, [2.0, 2.0]);
    }

    #[test]
    #[cfg(debug_assertions)]
    #[should_panic(expected = "violates I-16")]
    fn snapshot_panics_in_debug_for_fractional_scale() {
        let mut a = AgentVisualState::initial_for(cid());
        a.scale = 1.5;
        let _ = a.snapshot_for_render();
    }

    #[test]
    fn set_state_flag_round_trips() {
        let mut a = AgentVisualState::initial_for(cid());
        a.set_state_flag(StateFlags::ACTIVE_HALO, true);
        let f: StateFlags = a.state_flags.into();
        assert!(f.contains(StateFlags::ACTIVE_HALO));
        a.set_state_flag(StateFlags::ACTIVE_HALO, false);
        let f: StateFlags = a.state_flags.into();
        assert!(!f.contains(StateFlags::ACTIVE_HALO));
    }

    #[test]
    fn animation_state_frame_counts_match_doctrine() {
        // Spot-check a few — DOCTRINE §5.3 14-state table.
        assert_eq!(AnimationState::Idle.frame_count(), 4);
        assert_eq!(AnimationState::Walk.frame_count(), 8);
        assert_eq!(AnimationState::Think.frame_count(), 6);
        assert_eq!(AnimationState::Spawn.frame_count(), 5);
        assert_eq!(AnimationState::Gate.frame_count(), 2);
    }

    #[test]
    fn animation_state_loop_table_matches_doctrine() {
        // §5.3: loops include Idle/Walk/Think/Speak/Tool/Recover/
        // Sleep/Gate. Single-shot for everything else.
        assert!(AnimationState::Idle.loops());
        assert!(AnimationState::Recover.loops());
        assert!(!AnimationState::Spawn.loops());
        assert!(!AnimationState::HandoffGive.loops());
        assert!(!AnimationState::Success.loops());
    }

    #[test]
    fn snapshot_all_returns_per_companion_data() {
        let mut s = SimulationState::initial();
        let a = cid();
        let b = cid();
        s.ensure_agent(a);
        s.ensure_agent(b);
        let snaps = s.snapshot_all();
        assert_eq!(snaps.len(), 2);
        // BTreeMap iteration order is by key; both ids are
        // present.
        let ids: Vec<_> = snaps.iter().map(|d| d.agent_id()).collect();
        assert!(ids.contains(&a));
        assert!(ids.contains(&b));
    }
}
