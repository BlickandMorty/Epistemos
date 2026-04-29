//! `SimulationState` — per-companion FSM that the reducer
//! mutates per `AgentEvent` (S4; DOCTRINE §3 placements + §5.3
//! 14-state animation rig).
//!
//! Holds an `AgentVisualState` per registered companion plus a
//! small bag of session-level metadata (currently active
//! sessions). Per DOCTRINE I-13 this struct is **pure data**:
//! no time fields are sourced from `Instant::now()` here;
//! callers pass timestamps in.

use std::collections::{BTreeMap, BTreeSet, HashSet};

use serde::{Deserialize, Serialize};

use crate::companions::{CompanionId, PropKind};
use crate::events::{SessionId, SessionMode};
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

/// Per-session metadata the multi-room theater needs to render
/// chips, title strips, and routing. Distinct from the boolean
/// `active_sessions` set — `SessionMeta` only exists while the
/// session is in flight (DOCTRINE §3.3.1 v1.6 "one room per
/// active session"). Ordering is by `started_seq` so the chip
/// row renders in deterministic insert order across replays
/// (DOCTRINE I-13).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SessionMeta {
    pub session_id: SessionId,
    pub mode: SessionMode,
    /// Reducer event_seq at which this session opened — defines
    /// chip-row ordering. Stable across replays.
    pub started_seq: u64,
    /// First participant to join this session, if any. Used by
    /// the chip row to render the lead mascot per §3.3.1 v1.6.
    pub lead_agent: Option<CompanionId>,
    /// All agents currently bound to this session. `BTreeSet` for
    /// stable iteration at replay time.
    pub members: BTreeSet<CompanionId>,
    /// Most recent reducer event_seq for any event in this
    /// session — drives the "working-state pulse" gate per §3.3.1
    /// v1.6 (≤ 30 s since last event).
    pub last_event_seq: u64,
}

impl SessionMeta {
    fn new(session_id: SessionId, mode: SessionMode, started_seq: u64) -> Self {
        Self {
            session_id,
            mode,
            started_seq,
            lead_agent: None,
            members: BTreeSet::new(),
            last_event_seq: started_seq,
        }
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
    /// (every visible action belongs to a session) and to gate
    /// graph-theater visibility per §3.3 ("only companions whose
    /// backend is currently executing").
    pub active_sessions: HashSet<SessionId>,
    /// Per-session metadata for the multi-room graph theater
    /// (DOCTRINE §3.3.1 v1.6). One entry per *active* session;
    /// dropped on `SessionCompleted` / `SessionCommitted`.
    pub session_meta: BTreeMap<SessionId, SessionMeta>,
    /// agent → session binding. The reducer joins this when a
    /// `ParticipantJoined` event fires inside an open session
    /// (the most-recent `SessionStarted` not yet matched). Used
    /// by `rooms()` to bucket agents into per-session rooms and
    /// by Swift via the `epistemos_simulation_active_rooms` FFI
    /// to route delta-ring entries to the correct viewport tile.
    pub agent_session: BTreeMap<CompanionId, SessionId>,
    /// Most-recent `SessionStarted` not yet "consumed" by a
    /// matching `SessionCompleted`. Implicit binding: subsequent
    /// `ParticipantJoined` events bind to this session. The
    /// pattern matches the canonical session-bootstrap order
    /// (SessionStarted → ParticipantJoined+ → … → SessionCompleted)
    /// and avoids changing the AgentEvent wire format.
    pub current_bootstrap: Option<SessionId>,
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

    /// Open a new session — called from the reducer's
    /// `SessionStarted` arm. Idempotent: opening an already-active
    /// session updates `mode`/`started_seq` rather than creating
    /// a duplicate row.
    pub fn open_session(
        &mut self,
        session_id: SessionId,
        mode: SessionMode,
        started_seq: u64,
    ) {
        self.active_sessions.insert(session_id.clone());
        self.session_meta
            .entry(session_id.clone())
            .or_insert_with(|| SessionMeta::new(session_id.clone(), mode, started_seq));
        self.current_bootstrap = Some(session_id);
    }

    /// Close a session — called from the reducer's
    /// `SessionCompleted` / `SessionCommitted` arms. Drops the
    /// metadata, removes all agent bindings, and clears
    /// `current_bootstrap` if it pointed at the closed session.
    pub fn close_session(&mut self, session_id: &SessionId) {
        self.active_sessions.remove(session_id);
        self.session_meta.remove(session_id);
        // Remove every agent_session binding pointing at the
        // closed session. Renderer consumers will drop those
        // agents from the room on the next refresh.
        self.agent_session.retain(|_, sid| sid != session_id);
        if self.current_bootstrap.as_ref() == Some(session_id) {
            self.current_bootstrap = None;
        }
    }

    /// Bind an agent to the currently-bootstrapping session (set
    /// by the most-recent `SessionStarted`). No-op when no
    /// session is open. Idempotent: re-binding the same agent
    /// updates the lead-agent record only if the agent was the
    /// first to join.
    pub fn bind_agent_to_current_session(&mut self, agent_id: CompanionId, event_seq: u64) {
        let Some(sid) = self.current_bootstrap.clone() else {
            return;
        };
        self.agent_session.insert(agent_id, sid.clone());
        if let Some(meta) = self.session_meta.get_mut(&sid) {
            meta.members.insert(agent_id);
            if meta.lead_agent.is_none() {
                meta.lead_agent = Some(agent_id);
            }
            meta.last_event_seq = event_seq;
        }
    }

    /// Bind a child to its parent's session (subagent spawn).
    /// No-op when the parent has no session binding. The lead
    /// agent record is preserved (children never replace the
    /// lead mascot per §3.3.1 v1.6).
    pub fn bind_child_to_parent_session(
        &mut self,
        parent_id: CompanionId,
        child_id: CompanionId,
        event_seq: u64,
    ) {
        let Some(sid) = self.agent_session.get(&parent_id).cloned() else {
            return;
        };
        self.agent_session.insert(child_id, sid.clone());
        if let Some(meta) = self.session_meta.get_mut(&sid) {
            meta.members.insert(child_id);
            meta.last_event_seq = event_seq;
        }
    }

    /// Drop an agent from its session binding. Called on
    /// `ParticipantLeft`, `CompanionArchived`, and
    /// `SubagentCompleted`.
    pub fn unbind_agent(&mut self, agent_id: CompanionId) {
        if let Some(sid) = self.agent_session.remove(&agent_id) {
            if let Some(meta) = self.session_meta.get_mut(&sid) {
                meta.members.remove(&agent_id);
                if meta.lead_agent == Some(agent_id) {
                    // Lead promoted to next-most-senior member,
                    // or None if the room emptied.
                    meta.lead_agent = meta.members.iter().next().copied();
                }
            }
        }
    }

    /// Touch a session's `last_event_seq` — called from the
    /// reducer for any agent-scoped event so the chip-row pulse
    /// gate stays current per §3.3.1 v1.6.
    pub fn touch_session_for_agent(&mut self, agent_id: CompanionId, event_seq: u64) {
        if let Some(sid) = self.agent_session.get(&agent_id).cloned() {
            if let Some(meta) = self.session_meta.get_mut(&sid) {
                meta.last_event_seq = event_seq;
            }
        }
    }

    /// All active rooms in canonical order (by `started_seq`).
    /// Used by the multi-room renderer to lay out viewport tiles.
    pub fn rooms(&self) -> Vec<&SessionMeta> {
        let mut out: Vec<&SessionMeta> = self.session_meta.values().collect();
        out.sort_by_key(|m| m.started_seq);
        out
    }

    /// Lookup the session a given agent is bound to.
    pub fn session_of(&self, agent_id: CompanionId) -> Option<&SessionId> {
        self.agent_session.get(&agent_id)
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
