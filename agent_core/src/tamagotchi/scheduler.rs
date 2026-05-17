//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.3 G3 — Tamagotchi specificity-recovery (50 sprites /
//!   24 emotes / 60 FPS / deterministic idle-walk / reduce-motion
//!   static pose).
//! - `CANON_COMPLETENESS_AUDIT_2026_05_04.md` — completeness audit
//!   the G3 caps come from.
//! - Companion to [`super::animation`] (G1) + [`super::sprite_atlas`]
//!   (G2). G3 wires them with a frame-budget scheduler.
//!
//! # Phase B.3 G3 — Specificity-recovery substrate
//!
//! Three caps + one mode switch:
//!
//! - [`MAX_SPRITES`] = 50 — per-scene sprite-count cap.
//! - [`MAX_EMOTES`] = 24 — emote-vocabulary cap.
//! - [`FRAME_BUDGET_NS`] = 16_666_667 — 60 FPS = 16.67ms / frame.
//! - [`ReduceMotion`] flag — when `On`, idle-walk falls back to a
//!   single static pose regardless of frame_index.
//!
//! [`pick_frame_index`] is the deterministic idle-walk seed: same
//! `(state, frame_index, reduce_motion)` always picks the same atlas
//! cell. Makes regression testing trivial — no time-flake.

use serde::{Deserialize, Serialize};

pub const MAX_SPRITES: u32 = 50;
pub const MAX_EMOTES: u32 = 24;
pub const FRAME_BUDGET_NS: u64 = 16_666_667;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ReduceMotion {
    Off,
    On,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum AnimationMode {
    Idle,
    Walk,
    Other,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum SchedulerError {
    SpriteCapExceeded { requested: u32 },
    EmoteCapExceeded { requested: u32 },
    ZeroFrameCount,
}

pub fn admit_sprite_count(n: u32) -> Result<(), SchedulerError> {
    if n > MAX_SPRITES {
        return Err(SchedulerError::SpriteCapExceeded { requested: n });
    }
    Ok(())
}

pub fn admit_emote_count(n: u32) -> Result<(), SchedulerError> {
    if n > MAX_EMOTES {
        return Err(SchedulerError::EmoteCapExceeded { requested: n });
    }
    Ok(())
}

/// Remaining sprite headroom: `Some(MAX_SPRITES - n)` when `n` would
/// be admitted, `None` when `n` would be rejected. The "how many more
/// can I fit?" diagnostic for scene composition. By construction
/// `sprite_headroom(n).is_some() iff admit_sprite_count(n).is_ok()`.
pub const fn sprite_headroom(n: u32) -> Option<u32> {
    if n > MAX_SPRITES {
        None
    } else {
        Some(MAX_SPRITES - n)
    }
}

/// Remaining emote headroom: `Some(MAX_EMOTES - n)` when `n` would
/// be admitted, `None` when `n` would be rejected. Mirror of
/// [`sprite_headroom`] for the emote-vocabulary cap.
pub const fn emote_headroom(n: u32) -> Option<u32> {
    if n > MAX_EMOTES {
        None
    } else {
        Some(MAX_EMOTES - n)
    }
}

impl SchedulerError {
    /// Predicate: this error is a SpriteCapExceeded variant.
    pub const fn is_sprite_cap_exceeded(&self) -> bool {
        matches!(self, SchedulerError::SpriteCapExceeded { .. })
    }

    /// Predicate: this error is an EmoteCapExceeded variant.
    pub const fn is_emote_cap_exceeded(&self) -> bool {
        matches!(self, SchedulerError::EmoteCapExceeded { .. })
    }

    /// Predicate: this error is a ZeroFrameCount variant.
    pub const fn is_zero_frame_count(&self) -> bool {
        matches!(self, SchedulerError::ZeroFrameCount)
    }

    /// How many units over the cap the rejected request was, or
    /// `None` for non-cap errors (currently only ZeroFrameCount).
    /// E.g., a SpriteCapExceeded{requested:53} returns Some(3).
    pub const fn cap_overage(&self) -> Option<u32> {
        match self {
            SchedulerError::SpriteCapExceeded { requested } => {
                Some(*requested - MAX_SPRITES)
            }
            SchedulerError::EmoteCapExceeded { requested } => {
                Some(*requested - MAX_EMOTES)
            }
            SchedulerError::ZeroFrameCount => None,
        }
    }
}

/// Deterministic idle-walk frame selector. Returns `(0)` under
/// reduce-motion regardless of `frame_index`; otherwise cycles
/// through `frame_count` cells modulo current frame.
pub fn pick_frame_index(
    mode: AnimationMode,
    frame_index: u64,
    frame_count: u32,
    reduce_motion: ReduceMotion,
) -> Result<u32, SchedulerError> {
    if frame_count == 0 {
        return Err(SchedulerError::ZeroFrameCount);
    }
    if reduce_motion == ReduceMotion::On {
        return Ok(0);
    }
    if mode == AnimationMode::Other {
        return Ok((frame_index as u32) % frame_count);
    }
    Ok((frame_index as u32) % frame_count)
}

/// Per-frame wall-clock budget in ns at 60 FPS.
pub const fn frame_budget_ns() -> u64 {
    FRAME_BUDGET_NS
}

/// Exact implied FPS from FRAME_BUDGET_NS: `1e9 / FRAME_BUDGET_NS`.
/// Returns a value within (59.9, 60.0] — the 1ns rounding-up gives
/// the strict 60 FPS cap. Distinct from the integer-div `59` returned
/// by `1_000_000_000 / frame_budget_ns()`.
pub fn frame_budget_fps_exact() -> f64 {
    1.0e9 / (FRAME_BUDGET_NS as f64)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn caps_match_doctrine() {
        assert_eq!(MAX_SPRITES, 50);
        assert_eq!(MAX_EMOTES, 24);
        assert_eq!(FRAME_BUDGET_NS, 16_666_667);
    }

    #[test]
    fn at_sprite_cap_admits() {
        assert!(admit_sprite_count(50).is_ok());
    }

    #[test]
    fn over_sprite_cap_rejects() {
        let err = admit_sprite_count(51).unwrap_err();
        assert_eq!(err, SchedulerError::SpriteCapExceeded { requested: 51 });
    }

    #[test]
    fn at_emote_cap_admits() {
        assert!(admit_emote_count(24).is_ok());
    }

    #[test]
    fn over_emote_cap_rejects() {
        let err = admit_emote_count(25).unwrap_err();
        assert_eq!(err, SchedulerError::EmoteCapExceeded { requested: 25 });
    }

    #[test]
    fn pick_frame_index_zero_count_rejects() {
        let err = pick_frame_index(AnimationMode::Idle, 5, 0, ReduceMotion::Off).unwrap_err();
        assert_eq!(err, SchedulerError::ZeroFrameCount);
    }

    #[test]
    fn pick_frame_index_reduce_motion_returns_zero() {
        for &m in &[AnimationMode::Idle, AnimationMode::Walk, AnimationMode::Other] {
            for &f in &[0_u64, 1, 99, 12345] {
                let r = pick_frame_index(m, f, 8, ReduceMotion::On).unwrap();
                assert_eq!(r, 0, "mode={:?} frame={}", m, f);
            }
        }
    }

    #[test]
    fn pick_frame_index_cycles_modulo_frame_count() {
        let count = 4;
        let r0 = pick_frame_index(AnimationMode::Idle, 0, count, ReduceMotion::Off).unwrap();
        let r1 = pick_frame_index(AnimationMode::Idle, 1, count, ReduceMotion::Off).unwrap();
        let r4 = pick_frame_index(AnimationMode::Idle, 4, count, ReduceMotion::Off).unwrap();
        let r5 = pick_frame_index(AnimationMode::Idle, 5, count, ReduceMotion::Off).unwrap();
        assert_eq!(r0, 0);
        assert_eq!(r1, 1);
        assert_eq!(r4, 0);
        assert_eq!(r5, 1);
    }

    #[test]
    fn pick_frame_index_deterministic_across_calls() {
        let a = pick_frame_index(AnimationMode::Walk, 999, 7, ReduceMotion::Off).unwrap();
        let b = pick_frame_index(AnimationMode::Walk, 999, 7, ReduceMotion::Off).unwrap();
        assert_eq!(a, b);
    }

    #[test]
    fn frame_budget_ns_is_60_fps_approx() {
        // 1e9 / 16_666_667 = 59 (integer div); the budget rounds UP
        // from 16_666_666.667 to give a strict-enough cap.
        let fps_implied = 1_000_000_000_u64 / frame_budget_ns();
        assert_eq!(fps_implied, 59);
    }

    #[test]
    fn reduce_motion_two_distinct_states() {
        assert_ne!(ReduceMotion::Off, ReduceMotion::On);
    }

    #[test]
    fn animation_mode_three_distinct() {
        let s: std::collections::HashSet<_> =
            [AnimationMode::Idle, AnimationMode::Walk, AnimationMode::Other].iter().copied().collect();
        assert_eq!(s.len(), 3);
    }

    #[test]
    fn reduce_motion_serializes_through_serde_json() {
        let r = ReduceMotion::On;
        let json = serde_json::to_string(&r).unwrap();
        let back: ReduceMotion = serde_json::from_str(&json).unwrap();
        assert_eq!(r, back);
    }

    #[test]
    fn zero_sprites_admits() {
        assert!(admit_sprite_count(0).is_ok());
    }

    // ── headroom + error predicates + fps exact (iter 136) ──────────────────

    #[test]
    fn sprite_headroom_at_zero_is_full_cap() {
        assert_eq!(sprite_headroom(0), Some(MAX_SPRITES));
    }

    #[test]
    fn sprite_headroom_at_cap_is_zero() {
        assert_eq!(sprite_headroom(MAX_SPRITES), Some(0));
    }

    #[test]
    fn sprite_headroom_over_cap_is_none() {
        assert_eq!(sprite_headroom(MAX_SPRITES + 1), None);
        assert_eq!(sprite_headroom(1000), None);
    }

    #[test]
    fn emote_headroom_at_zero_is_full_cap() {
        assert_eq!(emote_headroom(0), Some(MAX_EMOTES));
    }

    #[test]
    fn emote_headroom_at_cap_is_zero() {
        assert_eq!(emote_headroom(MAX_EMOTES), Some(0));
    }

    #[test]
    fn emote_headroom_over_cap_is_none() {
        assert_eq!(emote_headroom(MAX_EMOTES + 1), None);
    }

    #[test]
    fn sprite_headroom_admit_invariant() {
        // Cross-surface invariant: admit_sprite_count(n).is_ok()
        // iff sprite_headroom(n).is_some(). Exhaustive over a sweep
        // straddling the cap boundary.
        for n in 0..=(MAX_SPRITES + 5) {
            assert_eq!(
                admit_sprite_count(n).is_ok(),
                sprite_headroom(n).is_some(),
                "mismatch at n={}", n
            );
        }
    }

    #[test]
    fn emote_headroom_admit_invariant() {
        for n in 0..=(MAX_EMOTES + 5) {
            assert_eq!(
                admit_emote_count(n).is_ok(),
                emote_headroom(n).is_some(),
                "mismatch at n={}", n
            );
        }
    }

    #[test]
    fn error_predicates_partition_variants() {
        let s = SchedulerError::SpriteCapExceeded { requested: 99 };
        let e = SchedulerError::EmoteCapExceeded { requested: 99 };
        let z = SchedulerError::ZeroFrameCount;
        // Each predicate is true for exactly one variant.
        assert!(s.is_sprite_cap_exceeded() && !s.is_emote_cap_exceeded() && !s.is_zero_frame_count());
        assert!(!e.is_sprite_cap_exceeded() && e.is_emote_cap_exceeded() && !e.is_zero_frame_count());
        assert!(!z.is_sprite_cap_exceeded() && !z.is_emote_cap_exceeded() && z.is_zero_frame_count());
    }

    #[test]
    fn cap_overage_matches_request_minus_cap() {
        assert_eq!(
            SchedulerError::SpriteCapExceeded { requested: 53 }.cap_overage(),
            Some(3),
        );
        assert_eq!(
            SchedulerError::EmoteCapExceeded { requested: 30 }.cap_overage(),
            Some(6),
        );
        assert_eq!(SchedulerError::ZeroFrameCount.cap_overage(), None);
    }

    #[test]
    fn cap_overage_propagates_admit_rejection_size() {
        // Cross-surface: the over-by amount reported by the error
        // returned from admit_sprite_count(n) equals n - MAX_SPRITES.
        let n = 73;
        let err = admit_sprite_count(n).unwrap_err();
        assert_eq!(err.cap_overage(), Some(n - MAX_SPRITES));
    }

    #[test]
    fn frame_budget_fps_exact_close_to_60() {
        let fps = frame_budget_fps_exact();
        assert!(fps > 59.9 && fps <= 60.0, "fps was {}", fps);
    }

    #[test]
    fn frame_budget_fps_exact_distinct_from_integer_div() {
        let exact = frame_budget_fps_exact();
        let truncated = 1_000_000_000_u64 / FRAME_BUDGET_NS;
        // Exact is ≥ 59.99... and truncated is exactly 59.
        assert!(exact - (truncated as f64) > 0.99);
    }
}
