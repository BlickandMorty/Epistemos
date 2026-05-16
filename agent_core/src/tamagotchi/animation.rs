//! Source:
//! - `docs/fusion/simulation/DOCTRINE.md` (1982L) — 13-state animation
//!   machine canonical specification, 16 invariants.
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.3 G1 — Full 13-state animation machine.
//! - MASTER_FUSION §3.27: states = "idle / walk / think / speak / tool /
//!   spawn / handoff_give / handoff_receive / retrieve / error /
//!   recover / success / sleep".
//!
//! # Phase B.3 G1 — 13-state animation machine substrate
//!
//! Per-frame animation state of a companion (distinct from the
//! coarser [`super::CompanionState`] which captures biometric-driven
//! mood). Both are independent dimensions: a Focused companion can
//! still be in the `Speak` animation state.
//!
//! Substrate floor: the enum + transition table + per-state allowed-
//! next-states matrix. Sprite atlas + Metal rendering (G2) and
//! Tamagotchi specificity-recovery (G3) land in Swift / Metal layers
//! that this module hands off to.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum CompanionAnimation {
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
}

impl CompanionAnimation {
    pub const ALL: [CompanionAnimation; 13] = [
        CompanionAnimation::Idle,
        CompanionAnimation::Walk,
        CompanionAnimation::Think,
        CompanionAnimation::Speak,
        CompanionAnimation::Tool,
        CompanionAnimation::Spawn,
        CompanionAnimation::HandoffGive,
        CompanionAnimation::HandoffReceive,
        CompanionAnimation::Retrieve,
        CompanionAnimation::Error,
        CompanionAnimation::Recover,
        CompanionAnimation::Success,
        CompanionAnimation::Sleep,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            CompanionAnimation::Idle => "idle",
            CompanionAnimation::Walk => "walk",
            CompanionAnimation::Think => "think",
            CompanionAnimation::Speak => "speak",
            CompanionAnimation::Tool => "tool",
            CompanionAnimation::Spawn => "spawn",
            CompanionAnimation::HandoffGive => "handoff_give",
            CompanionAnimation::HandoffReceive => "handoff_receive",
            CompanionAnimation::Retrieve => "retrieve",
            CompanionAnimation::Error => "error",
            CompanionAnimation::Recover => "recover",
            CompanionAnimation::Success => "success",
            CompanionAnimation::Sleep => "sleep",
        }
    }

    /// Whether this is an "active" state (vs. resting Idle/Sleep).
    pub const fn is_active(self) -> bool {
        !matches!(
            self,
            CompanionAnimation::Idle | CompanionAnimation::Sleep
        )
    }

    /// Whether `next` is a doctrine-allowed next state from `self`.
    /// Default policy: every state can return to Idle; Spawn must
    /// transition to Idle or another active state; Sleep can only go
    /// to Idle; Error must go to Recover or Idle; Success → Idle.
    /// Other transitions follow generic rules.
    pub fn may_transition_to(self, next: CompanionAnimation) -> bool {
        if self == next {
            return true;
        }
        match (self, next) {
            (CompanionAnimation::Spawn, CompanionAnimation::Sleep) => false,
            (CompanionAnimation::Sleep, n) => n == CompanionAnimation::Idle,
            (CompanionAnimation::Error, n) => {
                matches!(n, CompanionAnimation::Recover | CompanionAnimation::Idle)
            }
            (CompanionAnimation::Success, n) => n == CompanionAnimation::Idle,
            (CompanionAnimation::HandoffGive, CompanionAnimation::HandoffReceive) => false,
            (CompanionAnimation::HandoffReceive, CompanionAnimation::HandoffGive) => false,
            _ => true,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn thirteen_distinct_states() {
        let s: std::collections::HashSet<_> = CompanionAnimation::ALL.iter().copied().collect();
        assert_eq!(s.len(), 13);
    }

    #[test]
    fn state_codes_stable_strings() {
        assert_eq!(CompanionAnimation::Idle.code(), "idle");
        assert_eq!(CompanionAnimation::Walk.code(), "walk");
        assert_eq!(CompanionAnimation::Think.code(), "think");
        assert_eq!(CompanionAnimation::Speak.code(), "speak");
        assert_eq!(CompanionAnimation::Tool.code(), "tool");
        assert_eq!(CompanionAnimation::Spawn.code(), "spawn");
        assert_eq!(CompanionAnimation::HandoffGive.code(), "handoff_give");
        assert_eq!(CompanionAnimation::HandoffReceive.code(), "handoff_receive");
        assert_eq!(CompanionAnimation::Retrieve.code(), "retrieve");
        assert_eq!(CompanionAnimation::Error.code(), "error");
        assert_eq!(CompanionAnimation::Recover.code(), "recover");
        assert_eq!(CompanionAnimation::Success.code(), "success");
        assert_eq!(CompanionAnimation::Sleep.code(), "sleep");
    }

    #[test]
    fn idle_and_sleep_are_not_active() {
        for &s in &CompanionAnimation::ALL {
            let expected = !matches!(s, CompanionAnimation::Idle | CompanionAnimation::Sleep);
            assert_eq!(s.is_active(), expected);
        }
    }

    #[test]
    fn every_state_may_self_transition() {
        for &s in &CompanionAnimation::ALL {
            assert!(s.may_transition_to(s));
        }
    }

    #[test]
    fn sleep_only_to_idle() {
        for &n in &CompanionAnimation::ALL {
            let expected = n == CompanionAnimation::Sleep || n == CompanionAnimation::Idle;
            assert_eq!(
                CompanionAnimation::Sleep.may_transition_to(n),
                expected,
                "from Sleep to {:?}",
                n
            );
        }
    }

    #[test]
    fn error_only_to_recover_or_idle() {
        assert!(CompanionAnimation::Error.may_transition_to(CompanionAnimation::Recover));
        assert!(CompanionAnimation::Error.may_transition_to(CompanionAnimation::Idle));
        assert!(!CompanionAnimation::Error.may_transition_to(CompanionAnimation::Walk));
        assert!(!CompanionAnimation::Error.may_transition_to(CompanionAnimation::Speak));
    }

    #[test]
    fn success_only_to_idle() {
        assert!(CompanionAnimation::Success.may_transition_to(CompanionAnimation::Idle));
        assert!(!CompanionAnimation::Success.may_transition_to(CompanionAnimation::Walk));
    }

    #[test]
    fn handoff_pair_cannot_self_dance() {
        assert!(!CompanionAnimation::HandoffGive
            .may_transition_to(CompanionAnimation::HandoffReceive));
        assert!(!CompanionAnimation::HandoffReceive
            .may_transition_to(CompanionAnimation::HandoffGive));
    }

    #[test]
    fn spawn_cannot_go_directly_to_sleep() {
        assert!(!CompanionAnimation::Spawn.may_transition_to(CompanionAnimation::Sleep));
    }

    #[test]
    fn idle_can_transition_to_any_active() {
        for &n in &CompanionAnimation::ALL {
            assert!(CompanionAnimation::Idle.may_transition_to(n));
        }
    }

    #[test]
    fn state_serializes_through_serde_json() {
        let s = CompanionAnimation::HandoffGive;
        let json = serde_json::to_string(&s).unwrap();
        let back: CompanionAnimation = serde_json::from_str(&json).unwrap();
        assert_eq!(s, back);
    }

    #[test]
    fn all_codes_distinct() {
        let codes: std::collections::HashSet<&'static str> =
            CompanionAnimation::ALL.iter().map(|s| s.code()).collect();
        assert_eq!(codes.len(), 13);
    }

    #[test]
    fn walk_to_idle_allowed() {
        assert!(CompanionAnimation::Walk.may_transition_to(CompanionAnimation::Idle));
    }
}
