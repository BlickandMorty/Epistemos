//! Companion activity-state hysteresis machine (S1; DOCTRINE §3.2 table,
//! §3.5 cross-placement sync rules).
//!
//! ActivityTracker is a pure state machine over event observations
//! and tick wakeups. It accepts time as an input (`Instant`) so the
//! reducer / tests can inject monotonic time and remain deterministic
//! per I-13. The tracker itself never calls `Instant::now()` —
//! callers are responsible for the time source.
//!
//! State transitions (DOCTRINE §3.2):
//!   Active     — currently running (event within `hysteresis_window`)
//!   Recent     — event within `recent_window` (default 30s after
//!                Active hysteresis ends; default `recent_window` =
//!                60s, with Active occupying the first 30s)
//!   Dormant    — idle > `recent_window`, ≤ `parked_after`
//!                (default 7 days)
//!   Parked     — idle > `parked_after`
//!   JustAcquired — set explicitly by the registry when a companion
//!                  is first created or unwrapped from a gift-box;
//!                  reverts to Active on the next observed event.
//!
//! Per DOCTRINE §3.5, transitions must propagate to all three
//! placements within one frame (≤16ms at 60Hz). The ActivityTracker
//! returns `Vec<ActivityTransition>` from each `tick`/`observe_event`
//! call so the caller (S5/S6/S7 placement view-models) can fan them
//! out to subscribers.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::{Duration, Instant};

use super::CompanionId;

/// Activity state per DOCTRINE §3.2 table.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ActivityState {
    Active,
    Recent,
    Dormant,
    Parked,
    JustAcquired,
}

impl ActivityState {
    pub fn as_str(self) -> &'static str {
        match self {
            ActivityState::Active => "Active",
            ActivityState::Recent => "Recent",
            ActivityState::Dormant => "Dormant",
            ActivityState::Parked => "Parked",
            ActivityState::JustAcquired => "JustAcquired",
        }
    }
}

/// One observed transition. Returned in batch from `tick` and singly
/// from `observe_event` so the registry observer pipeline can emit a
/// `companion_activity_state_changed` event for each transition.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ActivityTransition {
    pub companion_id: CompanionId,
    pub from: ActivityState,
    pub to: ActivityState,
}

/// Hysteresis windows — defaults match DOCTRINE §3.2 ("active within
/// last 30s for hysteresis tail" / "Parked = no run in 7d"). Tests
/// can shrink them to drive transitions on simulated time.
#[derive(Debug, Clone, Copy)]
pub struct ActivityWindows {
    /// Time after the most recent event during which the companion
    /// is `Active`. Default: 30 seconds.
    pub active_window: Duration,
    /// Total idle window before the companion drops below `Recent`.
    /// `Recent` occupies the slice between `active_window` and
    /// `recent_window`. Default: 60 seconds.
    pub recent_window: Duration,
    /// Idle threshold above which the companion is `Parked`.
    /// Default: 7 days.
    pub parked_after: Duration,
}

impl Default for ActivityWindows {
    fn default() -> Self {
        Self {
            active_window: Duration::from_secs(30),
            recent_window: Duration::from_secs(60),
            parked_after: Duration::from_secs(60 * 60 * 24 * 7),
        }
    }
}

/// State machine that tracks activity per companion. Pure: no I/O,
/// no system clock — caller injects the `Instant`.
pub struct ActivityTracker {
    windows: ActivityWindows,
    state: HashMap<CompanionId, ActivityState>,
    last_event_at: HashMap<CompanionId, Instant>,
}

impl ActivityTracker {
    pub fn new() -> Self {
        Self::with_windows(ActivityWindows::default())
    }

    pub fn with_windows(windows: ActivityWindows) -> Self {
        Self {
            windows,
            state: HashMap::new(),
            last_event_at: HashMap::new(),
        }
    }

    pub fn windows(&self) -> ActivityWindows {
        self.windows
    }

    /// Registers a *newly-created* companion in the tracker.
    /// Initial state is `JustAcquired` — the rainbow-flash
    /// entrance per DOCTRINE §3.5 is bound to this state. The
    /// next observed event flips it to `Active`. No-op if the
    /// companion already exists.
    pub fn register(&mut self, id: CompanionId) -> Option<ActivityTransition> {
        if self.state.contains_key(&id) {
            return None;
        }
        self.state.insert(id, ActivityState::JustAcquired);
        // No prior event time — leave `last_event_at` unset so
        // the companion stays in `JustAcquired` until the first
        // event.
        None
    }

    /// Registers a companion that already existed before this
    /// process started — used by `CompanionRegistry::open()` to
    /// restore state across restarts (audit Finding #4 from the
    /// post-S2 review). The seeded state is `Dormant` — the
    /// conservative reading of DOCTRINE §3.2 "Dormant ≠ deleted":
    /// across a restart the companion hasn't run *in this
    /// session*, so `Dormant` correctly conveys "alive but
    /// inactive" without falsely advertising a fresh
    /// `JustAcquired` rainbow entrance on every launch.
    ///
    /// V14 polish may upgrade this to RFC3339-audit-log archaeology
    /// (parse last-event timestamp, compute elapsed, seed an
    /// appropriate state from the §3.2 windows) but `Dormant` is
    /// load-bearing-correct for V0/V1.
    ///
    /// Returns `None` always — restoration emits no observable
    /// transition because the consumer (placement view-models)
    /// is rendering its first frame with this state, not
    /// reacting to a change.
    pub fn register_existing(&mut self, id: CompanionId) -> Option<ActivityTransition> {
        if self.state.contains_key(&id) {
            return None;
        }
        self.state.insert(id, ActivityState::Dormant);
        None
    }

    /// Removes a companion from the tracker (archival). Returns the
    /// final state (if any) so the caller can emit a final
    /// transition for downstream observers.
    pub fn unregister(&mut self, id: CompanionId) -> Option<ActivityState> {
        self.last_event_at.remove(&id);
        self.state.remove(&id)
    }

    /// Records that `id` produced a runtime event at `now`. Returns
    /// `Some(transition)` if this caused the activity state to
    /// change, else `None`.
    pub fn observe_event(
        &mut self,
        id: CompanionId,
        now: Instant,
    ) -> Option<ActivityTransition> {
        let prev = self.state.get(&id).copied().unwrap_or(ActivityState::JustAcquired);
        self.last_event_at.insert(id, now);
        let next = ActivityState::Active;
        if prev != next {
            self.state.insert(id, next);
            Some(ActivityTransition {
                companion_id: id,
                from: prev,
                to: next,
            })
        } else {
            None
        }
    }

    /// Wakeup tick. Re-evaluates every tracked companion's state
    /// against the current `Instant` and returns any transitions.
    /// Companions that have never observed an event (still
    /// `JustAcquired` with no `last_event_at`) are skipped — they
    /// retain `JustAcquired` until something happens to them.
    pub fn tick(&mut self, now: Instant) -> Vec<ActivityTransition> {
        let mut transitions = Vec::new();
        // Snapshot the iteration target so we can safely mutate
        // `self.state` inside the loop.
        let entries: Vec<(CompanionId, Instant, ActivityState)> = self
            .last_event_at
            .iter()
            .filter_map(|(id, t)| {
                self.state
                    .get(id)
                    .copied()
                    .map(|s| (*id, *t, s))
            })
            .collect();
        for (id, last, prev) in entries {
            let elapsed = now.saturating_duration_since(last);
            let next = if elapsed < self.windows.active_window {
                ActivityState::Active
            } else if elapsed < self.windows.recent_window {
                ActivityState::Recent
            } else if elapsed < self.windows.parked_after {
                ActivityState::Dormant
            } else {
                ActivityState::Parked
            };
            if prev != next {
                self.state.insert(id, next);
                transitions.push(ActivityTransition {
                    companion_id: id,
                    from: prev,
                    to: next,
                });
            }
        }
        transitions
    }

    /// Current state for `id`, or `None` if not registered.
    pub fn state(&self, id: CompanionId) -> Option<ActivityState> {
        self.state.get(&id).copied()
    }

    pub fn iter(&self) -> impl Iterator<Item = (CompanionId, ActivityState)> + '_ {
        self.state.iter().map(|(id, st)| (*id, *st))
    }
}

impl Default for ActivityTracker {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn id() -> CompanionId {
        CompanionId::new_ulid()
    }

    fn fast_windows() -> ActivityWindows {
        ActivityWindows {
            active_window: Duration::from_millis(100),
            recent_window: Duration::from_millis(200),
            parked_after: Duration::from_millis(500),
        }
    }

    #[test]
    fn register_seeds_just_acquired_state() {
        let mut t = ActivityTracker::new();
        let c = id();
        let trans = t.register(c);
        assert!(trans.is_none(), "register itself emits no transition");
        assert_eq!(t.state(c), Some(ActivityState::JustAcquired));
    }

    #[test]
    fn register_existing_seeds_dormant_for_restart_restoration() {
        // Post-S2 audit Finding #4: across a restart, a
        // pre-existing companion must NOT show as JustAcquired
        // (rainbow flash on every launch is wrong per
        // DOCTRINE §3.2 "Dormant ≠ deleted").
        let mut t = ActivityTracker::new();
        let c = id();
        let trans = t.register_existing(c);
        assert!(trans.is_none());
        assert_eq!(t.state(c), Some(ActivityState::Dormant));
    }

    #[test]
    fn register_existing_is_no_op_if_already_present() {
        let mut t = ActivityTracker::new();
        let c = id();
        t.register(c);
        // Now hint that this companion existed before — should
        // NOT downgrade JustAcquired → Dormant.
        let trans = t.register_existing(c);
        assert!(trans.is_none());
        assert_eq!(t.state(c), Some(ActivityState::JustAcquired));
    }

    #[test]
    fn restored_dormant_companion_observes_event_to_active() {
        // After restart restoration: companion is Dormant, then
        // an event fires → state must transition to Active.
        let mut t = ActivityTracker::new();
        let c = id();
        t.register_existing(c);
        let tr = t.observe_event(c, Instant::now()).unwrap();
        assert_eq!(tr.from, ActivityState::Dormant);
        assert_eq!(tr.to, ActivityState::Active);
    }

    #[test]
    fn observe_event_flips_just_acquired_to_active() {
        let mut t = ActivityTracker::new();
        let c = id();
        t.register(c);
        let now = Instant::now();
        let tr = t.observe_event(c, now).expect("transition expected");
        assert_eq!(tr.from, ActivityState::JustAcquired);
        assert_eq!(tr.to, ActivityState::Active);
        assert_eq!(t.state(c), Some(ActivityState::Active));
    }

    #[test]
    fn full_active_recent_dormant_parked_progression() {
        let mut t = ActivityTracker::with_windows(fast_windows());
        let c = id();
        t.register(c);
        let t0 = Instant::now();
        t.observe_event(c, t0);
        assert_eq!(t.state(c), Some(ActivityState::Active));

        // Inside active_window — still Active, no transition.
        let trans = t.tick(t0 + Duration::from_millis(50));
        assert!(trans.is_empty(), "no transition before active_window expires");

        // Past active_window, before recent_window — Recent.
        let trans = t.tick(t0 + Duration::from_millis(150));
        assert_eq!(trans.len(), 1);
        assert_eq!(trans[0].from, ActivityState::Active);
        assert_eq!(trans[0].to, ActivityState::Recent);

        // Past recent_window, before parked_after — Dormant.
        let trans = t.tick(t0 + Duration::from_millis(300));
        assert_eq!(trans.len(), 1);
        assert_eq!(trans[0].from, ActivityState::Recent);
        assert_eq!(trans[0].to, ActivityState::Dormant);

        // Past parked_after — Parked.
        let trans = t.tick(t0 + Duration::from_millis(700));
        assert_eq!(trans.len(), 1);
        assert_eq!(trans[0].from, ActivityState::Dormant);
        assert_eq!(trans[0].to, ActivityState::Parked);

        // Tick again at the same time — no further transition.
        let trans = t.tick(t0 + Duration::from_millis(700));
        assert!(trans.is_empty());
    }

    #[test]
    fn re_observation_returns_to_active_from_any_state() {
        let mut t = ActivityTracker::with_windows(fast_windows());
        let c = id();
        t.register(c);
        let t0 = Instant::now();
        t.observe_event(c, t0);
        // Drive to Parked.
        t.tick(t0 + Duration::from_millis(700));
        assert_eq!(t.state(c), Some(ActivityState::Parked));
        // New event → Active.
        let tr = t
            .observe_event(c, t0 + Duration::from_millis(800))
            .expect("transition Parked → Active");
        assert_eq!(tr.from, ActivityState::Parked);
        assert_eq!(tr.to, ActivityState::Active);
    }

    #[test]
    fn never_observed_companion_stays_just_acquired_through_ticks() {
        let mut t = ActivityTracker::with_windows(fast_windows());
        let c = id();
        t.register(c);
        // Multiple ticks at increasing times — should NOT transition
        // because no event has been observed yet.
        let t0 = Instant::now();
        let trans = t.tick(t0 + Duration::from_millis(100));
        assert!(trans.is_empty());
        let trans = t.tick(t0 + Duration::from_millis(1000));
        assert!(trans.is_empty());
        assert_eq!(t.state(c), Some(ActivityState::JustAcquired));
    }

    #[test]
    fn unregister_clears_state_and_returns_final() {
        let mut t = ActivityTracker::new();
        let c = id();
        t.register(c);
        t.observe_event(c, Instant::now());
        let final_state = t.unregister(c);
        assert_eq!(final_state, Some(ActivityState::Active));
        assert_eq!(t.state(c), None);
    }

    #[test]
    fn multiple_companions_track_independently() {
        let mut t = ActivityTracker::with_windows(fast_windows());
        let a = id();
        let b = id();
        t.register(a);
        t.register(b);
        let t0 = Instant::now();
        t.observe_event(a, t0);
        // Don't observe b — leave it in JustAcquired.
        let trans = t.tick(t0 + Duration::from_millis(150));
        // Only `a` transitions Active → Recent.
        assert_eq!(trans.len(), 1);
        assert_eq!(trans[0].companion_id, a);
        assert_eq!(t.state(b), Some(ActivityState::JustAcquired));
    }
}
