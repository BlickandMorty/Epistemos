//! Phase C Week 3 LOD-aware renderer parameters.
//!
//! Per `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md` §"Phase C —
//! Cluster-first multilevel for 50k+ (4 weeks)" → §"Week 3: LOD-aware
//! renderer". The plan calls for:
//!
//!   - At full zoom-out: render cluster centroids only (per-cluster sprite at COM)
//!   - At mid zoom: render cluster centroids + leaf nodes in frustum
//!   - At zoom-in: render all leaf nodes in frustum (existing path)
//!   - Leaf positions ALWAYS valid (never lost when not rendered)
//!   - Smooth transition between LOD levels (alpha cross-fade over 200 ms)
//!
//! ## Pure-data contract
//!
//! This module owns the canonical zoom thresholds + the LOD-level enum
//! + the crossfade math. The renderer integration (which Metal pipeline
//! state to pick, what alpha to set on which draw call) lives Swift-side
//! and consumes these values via FFI.
//!
//! ## User report 2026-05-12 v5
//!
//! User reports "feels like large nodes just disappear and small ones
//! appear" at zoom-out, especially at high vault count. That's the
//! exact failure mode the canonical plan says smooth crossfade fixes.
//! The user also asks for "much further" zoom-out before the LOD
//! transition fires — the canonical thresholds in this module are
//! tunable via `LodThresholds::default()` vs `LodThresholds::far()`.

use serde::{Deserialize, Serialize};

/// Three canonical zoom levels per the canonical plan.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
#[repr(u8)]
pub enum LodLevel {
    /// Zoom-in: render all leaf nodes in frustum (canonical default).
    LeafOnly = 0,
    /// Mid zoom: render centroids + leaf nodes in frustum.
    Mixed = 1,
    /// Full zoom-out: render cluster centroids only.
    CentroidsOnly = 2,
}

impl LodLevel {
    pub fn name(self) -> &'static str {
        match self {
            Self::LeafOnly => "leaf_only",
            Self::Mixed => "mixed",
            Self::CentroidsOnly => "centroids_only",
        }
    }
}

/// Canonical LOD threshold configuration. The renderer picks an
/// `LodLevel` based on the camera zoom factor against these thresholds.
///
/// Zoom factor convention: `1.0` is identity zoom (each world unit
/// renders as 1 pixel). `<1.0` is zoomed-out (world appears smaller),
/// `>1.0` is zoomed-in. Lower zoom → higher LOD (more aggregation).
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct LodThresholds {
    /// Below this zoom factor → CentroidsOnly. Default 0.15 (15% of
    /// identity — corresponds to "very zoomed out").
    pub centroids_only_below: f32,
    /// Between `centroids_only_below` and this → Mixed. Above this → LeafOnly.
    /// Default 0.45.
    pub mixed_below: f32,
    /// Crossfade duration in seconds for the alpha-blend between LOD
    /// levels. Per canonical plan: 200 ms.
    pub crossfade_duration_seconds: f32,
}

impl Default for LodThresholds {
    /// Canonical-plan defaults.
    fn default() -> Self {
        Self {
            centroids_only_below: 0.15,
            mixed_below: 0.45,
            crossfade_duration_seconds: 0.200,
        }
    }
}

impl LodThresholds {
    /// "Zoom out further" preset (per user report 2026-05-12 v5).
    /// Pushes the centroid-only transition further out so users can
    /// scroll past more of the graph before clusters take over. Same
    /// crossfade duration.
    pub fn far() -> Self {
        Self {
            centroids_only_below: 0.05,   // 3× further out before centroids kick in
            mixed_below: 0.25,             // ~2× further out
            crossfade_duration_seconds: 0.200,
        }
    }

    /// Even further zoom-out. For users who want extreme overview.
    pub fn extreme_far() -> Self {
        Self {
            centroids_only_below: 0.02,
            mixed_below: 0.12,
            crossfade_duration_seconds: 0.250, // slightly longer fade for further transitions
        }
    }
}

/// Pick the active LOD level given a zoom factor + thresholds.
pub fn lod_level_for_zoom(zoom: f32, thresholds: &LodThresholds) -> LodLevel {
    // Non-finite zoom → defensive default to LeafOnly so nothing
    // disappears.
    if !zoom.is_finite() {
        return LodLevel::LeafOnly;
    }
    if zoom < thresholds.centroids_only_below {
        LodLevel::CentroidsOnly
    } else if zoom < thresholds.mixed_below {
        LodLevel::Mixed
    } else {
        LodLevel::LeafOnly
    }
}

/// LOD transition state. Tracks the in-progress crossfade between two
/// adjacent levels. The renderer reads `current_alpha` to draw the
/// "outgoing" level dimming + the "incoming" level brightening
/// simultaneously, instead of an abrupt pop.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct LodTransitionState {
    pub from: LodLevel,
    pub to: LodLevel,
    /// `[0, 1]` — 0 = fully `from`, 1 = fully `to`.
    pub progress: f32,
    pub thresholds: LodThresholds,
}

impl LodTransitionState {
    pub fn settled(level: LodLevel, thresholds: LodThresholds) -> Self {
        Self { from: level, to: level, progress: 1.0, thresholds }
    }

    pub fn is_settled(&self) -> bool {
        self.from == self.to || self.progress >= 1.0
    }

    /// Outgoing-level alpha. Caller multiplies its existing rendering
    /// alpha by this value when drawing the `from` level's content.
    pub fn outgoing_alpha(&self) -> f32 {
        if self.is_settled() { 0.0 } else { 1.0 - self.progress }
    }

    /// Incoming-level alpha. Caller multiplies its existing rendering
    /// alpha by this value when drawing the `to` level's content.
    pub fn incoming_alpha(&self) -> f32 {
        if self.is_settled() { 1.0 } else { self.progress }
    }

    /// Begin a transition to a new LOD level. If already at that level
    /// or already transitioning to it, this is a no-op.
    pub fn start_transition(&mut self, new_level: LodLevel) {
        if self.is_settled() && new_level == self.from {
            return;
        }
        if !self.is_settled() && new_level == self.to {
            return;
        }
        // If we're mid-crossfade, jump to the current effective level
        // before starting the new transition (avoids ping-pong).
        let current = if self.progress >= 0.5 { self.to } else { self.from };
        self.from = current;
        self.to = new_level;
        self.progress = 0.0;
    }

    /// Advance the transition by `dt` seconds.
    pub fn tick(&mut self, dt_seconds: f32) {
        if self.is_settled() {
            self.progress = 1.0;
            return;
        }
        let step = dt_seconds / self.thresholds.crossfade_duration_seconds.max(1e-6);
        self.progress = (self.progress + step).min(1.0);
        if self.progress >= 1.0 {
            self.from = self.to;
            self.progress = 1.0;
        }
    }
}

// ─── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lod_level_serializes_snake_case() {
        let level = LodLevel::CentroidsOnly;
        let j = serde_json::to_string(&level).unwrap();
        assert_eq!(j, "\"centroids_only\"");
    }

    #[test]
    fn default_thresholds_match_canonical_plan() {
        let t = LodThresholds::default();
        // Canonical-plan numbers
        assert!((t.centroids_only_below - 0.15).abs() < 1e-6);
        assert!((t.mixed_below - 0.45).abs() < 1e-6);
        // Canonical 200 ms crossfade
        assert!((t.crossfade_duration_seconds - 0.200).abs() < 1e-6);
    }

    #[test]
    fn far_threshold_pushes_centroid_transition_further_out() {
        let default = LodThresholds::default();
        let far = LodThresholds::far();
        assert!(far.centroids_only_below < default.centroids_only_below,
            "far must trigger centroids at LOWER zoom (further out)");
        assert!(far.mixed_below < default.mixed_below);
    }

    #[test]
    fn lod_level_for_zoom_at_canonical_breakpoints() {
        let t = LodThresholds::default();
        // Well above mixed_below = LeafOnly
        assert_eq!(lod_level_for_zoom(1.0, &t), LodLevel::LeafOnly);
        assert_eq!(lod_level_for_zoom(0.5, &t), LodLevel::LeafOnly);
        // Between centroids and mixed → Mixed
        assert_eq!(lod_level_for_zoom(0.30, &t), LodLevel::Mixed);
        // Below centroids → CentroidsOnly
        assert_eq!(lod_level_for_zoom(0.10, &t), LodLevel::CentroidsOnly);
        assert_eq!(lod_level_for_zoom(0.01, &t), LodLevel::CentroidsOnly);
    }

    #[test]
    fn lod_level_for_zoom_drops_nan_to_leaf_only() {
        let t = LodThresholds::default();
        assert_eq!(lod_level_for_zoom(f32::NAN, &t), LodLevel::LeafOnly);
        assert_eq!(lod_level_for_zoom(f32::INFINITY, &t), LodLevel::LeafOnly);
        assert_eq!(lod_level_for_zoom(f32::NEG_INFINITY, &t), LodLevel::LeafOnly);
    }

    #[test]
    fn settled_state_has_full_incoming_alpha() {
        let s = LodTransitionState::settled(LodLevel::LeafOnly, LodThresholds::default());
        assert!(s.is_settled());
        assert_eq!(s.outgoing_alpha(), 0.0);
        assert_eq!(s.incoming_alpha(), 1.0);
    }

    #[test]
    fn start_transition_advances_alpha_smoothly_over_200ms() {
        let mut s = LodTransitionState::settled(LodLevel::LeafOnly, LodThresholds::default());
        s.start_transition(LodLevel::Mixed);
        assert!(!s.is_settled());
        // At t=0, fully outgoing
        assert!((s.outgoing_alpha() - 1.0).abs() < 1e-3);
        assert!((s.incoming_alpha() - 0.0).abs() < 1e-3);
        // After 100ms (half the canonical 200ms), should be halfway
        s.tick(0.100);
        assert!((s.outgoing_alpha() - 0.5).abs() < 0.05,
            "after 100ms outgoing should be ~0.5, got {}", s.outgoing_alpha());
        assert!((s.incoming_alpha() - 0.5).abs() < 0.05);
        // After another 100ms, fully transitioned
        s.tick(0.100);
        assert!(s.is_settled());
        assert!((s.incoming_alpha() - 1.0).abs() < 1e-3);
    }

    #[test]
    fn start_transition_to_current_level_is_noop() {
        let mut s = LodTransitionState::settled(LodLevel::Mixed, LodThresholds::default());
        s.start_transition(LodLevel::Mixed);
        assert!(s.is_settled());
    }

    #[test]
    fn rapid_back_and_forth_doesnt_pingpong() {
        let mut s = LodTransitionState::settled(LodLevel::LeafOnly, LodThresholds::default());
        s.start_transition(LodLevel::Mixed);
        s.tick(0.050); // 25% through
        s.start_transition(LodLevel::LeafOnly); // change mind
        // Should restart from the closest current effective level (still LeafOnly at 25%)
        assert_eq!(s.from, LodLevel::LeafOnly);
        assert_eq!(s.to, LodLevel::LeafOnly);
        // Already at target → settled.
        assert!(s.is_settled());
    }

    #[test]
    fn tick_clamps_progress_to_one() {
        let mut s = LodTransitionState::settled(LodLevel::LeafOnly, LodThresholds::default());
        s.start_transition(LodLevel::Mixed);
        s.tick(10.0); // way more than 200ms
        assert!(s.is_settled());
        assert_eq!(s.progress, 1.0);
    }

    #[test]
    fn extreme_far_thresholds_push_even_further_out() {
        let far = LodThresholds::far();
        let extreme = LodThresholds::extreme_far();
        assert!(extreme.centroids_only_below < far.centroids_only_below);
        assert!(extreme.mixed_below < far.mixed_below);
    }

    #[test]
    fn ordering_outgoing_plus_incoming_always_sums_to_one_at_settled() {
        let s = LodTransitionState::settled(LodLevel::Mixed, LodThresholds::default());
        let sum = s.outgoing_alpha() + s.incoming_alpha();
        assert!((sum - 1.0).abs() < 1e-6);
    }

    #[test]
    fn ordering_outgoing_plus_incoming_always_sums_to_one_mid_transition() {
        let mut s = LodTransitionState::settled(LodLevel::LeafOnly, LodThresholds::default());
        s.start_transition(LodLevel::Mixed);
        for _ in 0..10 {
            s.tick(0.020); // 20ms ticks
            let sum = s.outgoing_alpha() + s.incoming_alpha();
            assert!((sum - 1.0).abs() < 1e-3,
                "outgoing + incoming should always sum to 1, got {} at progress {}",
                sum, s.progress);
        }
    }
}
