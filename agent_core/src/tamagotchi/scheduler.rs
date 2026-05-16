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
}
