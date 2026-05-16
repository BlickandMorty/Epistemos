//! Source:
//! - `docs/CLAUDE_AUTONOMOUS_LOOP_PROMPT_V3_TERMINAL_B_2026_05_16.md`
//!   §5 Phase B.6.12 — BiometricWriteGate + two-tier biometric cache:
//!   mount-tier + per-op-tier separation. `ternary kernel.md` doctrine
//!   (control-room safe-editing surface).
//!
//! # Wave J B.6.12 — BiometricWriteGate substrate
//!
//! Two-tier biometric authentication for high-stakes writes:
//!
//! 1. **Mount-tier** — long-duration auth granted at session unlock
//!    (e.g. Touch ID at app launch). Valid for the whole session
//!    until [`BiometricWriteGate::revoke_mount`] is called.
//! 2. **Per-op-tier** — per-write re-authentication with a short
//!    validity window (default 60s). Each successful per-op auth
//!    extends the window from the last auth timestamp.
//!
//! A write is admitted iff **both** tiers are valid. This gives the
//! control room two independent kill switches: revoke the mount to
//! invalidate every future write; let the per-op window expire to
//! force re-auth before the next write.

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum BiometricTier {
    Mount,
    PerOp,
}

impl BiometricTier {
    pub const fn code(self) -> &'static str {
        match self {
            BiometricTier::Mount => "mount",
            BiometricTier::PerOp => "per_op",
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum BiometricGateError {
    MountTierMissing,
    PerOpTierExpired { last_auth_at_unix_ms: u64, now_unix_ms: u64, window_ms: u64 },
    PerOpNeverAuthenticated,
    NonPositiveWindow { window_ms: u64 },
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct BiometricWriteGate {
    pub mount_authenticated: bool,
    pub last_per_op_unix_ms: Option<u64>,
    pub per_op_window_ms: u64,
}

impl BiometricWriteGate {
    /// `per_op_window_ms` is the validity duration of a per-op auth
    /// from the moment it was granted. Typical: 60_000 (60 seconds).
    pub fn new(per_op_window_ms: u64) -> Result<Self, BiometricGateError> {
        if per_op_window_ms == 0 {
            return Err(BiometricGateError::NonPositiveWindow {
                window_ms: per_op_window_ms,
            });
        }
        Ok(Self {
            mount_authenticated: false,
            last_per_op_unix_ms: None,
            per_op_window_ms,
        })
    }

    /// Grant mount-tier auth (session unlock).
    pub fn grant_mount(&mut self) {
        self.mount_authenticated = true;
    }

    /// Revoke mount-tier auth. Future writes denied until granted again.
    pub fn revoke_mount(&mut self) {
        self.mount_authenticated = false;
    }

    /// Grant a per-op auth at `now_unix_ms`. Each grant resets the
    /// validity window from this timestamp.
    pub fn grant_per_op(&mut self, now_unix_ms: u64) {
        self.last_per_op_unix_ms = Some(now_unix_ms);
    }

    /// Check whether a write may proceed at `now_unix_ms`. Both tiers
    /// must pass; returns the first failing tier's error.
    pub fn admit_write(&self, now_unix_ms: u64) -> Result<(), BiometricGateError> {
        if !self.mount_authenticated {
            return Err(BiometricGateError::MountTierMissing);
        }
        let last = self.last_per_op_unix_ms.ok_or(BiometricGateError::PerOpNeverAuthenticated)?;
        if now_unix_ms < last {
            return Err(BiometricGateError::PerOpTierExpired {
                last_auth_at_unix_ms: last,
                now_unix_ms,
                window_ms: self.per_op_window_ms,
            });
        }
        let elapsed = now_unix_ms - last;
        if elapsed > self.per_op_window_ms {
            return Err(BiometricGateError::PerOpTierExpired {
                last_auth_at_unix_ms: last,
                now_unix_ms,
                window_ms: self.per_op_window_ms,
            });
        }
        Ok(())
    }

    /// Remaining milliseconds before per-op auth expires. `None` if
    /// per-op has never been granted; `Some(0)` if already expired.
    pub fn remaining_per_op_ms(&self, now_unix_ms: u64) -> Option<u64> {
        let last = self.last_per_op_unix_ms?;
        if now_unix_ms < last {
            return Some(self.per_op_window_ms);
        }
        let elapsed = now_unix_ms - last;
        if elapsed >= self.per_op_window_ms {
            Some(0)
        } else {
            Some(self.per_op_window_ms - elapsed)
        }
    }

    /// Typed admission decision for control-room UIs. Same logic as
    /// [`admit_write`] but surfaces a `next_action` hint instead of
    /// returning a `Result` — better for rendering "what should the
    /// user do next?" without unwrapping an error.
    pub fn decide(&self, now_unix_ms: u64) -> AdmissionDecision {
        if !self.mount_authenticated {
            return AdmissionDecision::Deny {
                reason: DenyReason::MountTierMissing,
                next_action: NextAction::PromptForMount,
            };
        }
        match self.last_per_op_unix_ms {
            None => AdmissionDecision::Deny {
                reason: DenyReason::PerOpNeverAuthenticated,
                next_action: NextAction::PromptForPerOp,
            },
            Some(last) => {
                let elapsed = now_unix_ms.saturating_sub(last);
                if elapsed > self.per_op_window_ms {
                    AdmissionDecision::Deny {
                        reason: DenyReason::PerOpExpired,
                        next_action: NextAction::PromptForPerOp,
                    }
                } else {
                    let remaining_ms = self.per_op_window_ms - elapsed;
                    AdmissionDecision::Admit { remaining_per_op_ms: remaining_ms }
                }
            }
        }
    }
}

/// Reason a write was denied. Pairs with `NextAction` in
/// [`AdmissionDecision::Deny`] so the control room can render both
/// "why" and "what to do".
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum DenyReason {
    MountTierMissing,
    PerOpNeverAuthenticated,
    PerOpExpired,
}

/// Next-action hint for the UI. The control-room dispatcher consumes
/// this to decide whether to show a Touch-ID prompt, a session-unlock
/// flow, or nothing (when already admitted).
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum NextAction {
    PromptForMount,
    PromptForPerOp,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub enum AdmissionDecision {
    Admit { remaining_per_op_ms: u64 },
    Deny { reason: DenyReason, next_action: NextAction },
}

impl AdmissionDecision {
    pub fn is_admitted(&self) -> bool {
        matches!(self, AdmissionDecision::Admit { .. })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn two_distinct_tiers() {
        let s: std::collections::HashSet<_> =
            [BiometricTier::Mount, BiometricTier::PerOp].iter().copied().collect();
        assert_eq!(s.len(), 2);
    }

    #[test]
    fn tier_codes_stable() {
        assert_eq!(BiometricTier::Mount.code(), "mount");
        assert_eq!(BiometricTier::PerOp.code(), "per_op");
    }

    #[test]
    fn zero_window_rejected() {
        let err = BiometricWriteGate::new(0).unwrap_err();
        assert_eq!(err, BiometricGateError::NonPositiveWindow { window_ms: 0 });
    }

    #[test]
    fn fresh_gate_denies_writes() {
        let g = BiometricWriteGate::new(60_000).unwrap();
        let err = g.admit_write(0).unwrap_err();
        assert_eq!(err, BiometricGateError::MountTierMissing);
    }

    #[test]
    fn mount_alone_denies_per_op_missing() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        let err = g.admit_write(0).unwrap_err();
        assert_eq!(err, BiometricGateError::PerOpNeverAuthenticated);
    }

    #[test]
    fn mount_plus_per_op_admits_within_window() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        g.grant_per_op(0);
        assert!(g.admit_write(30_000).is_ok());
    }

    #[test]
    fn per_op_expires_after_window() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        g.grant_per_op(0);
        let err = g.admit_write(60_001).unwrap_err();
        assert!(matches!(err, BiometricGateError::PerOpTierExpired { .. }));
    }

    #[test]
    fn mount_revoke_invalidates_writes() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        g.grant_per_op(0);
        assert!(g.admit_write(100).is_ok());
        g.revoke_mount();
        let err = g.admit_write(200).unwrap_err();
        assert_eq!(err, BiometricGateError::MountTierMissing);
    }

    #[test]
    fn re_grant_per_op_extends_window() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        g.grant_per_op(0);
        // At t=50k still valid.
        assert!(g.admit_write(50_000).is_ok());
        // Re-grant at t=50k extends window to 110k.
        g.grant_per_op(50_000);
        assert!(g.admit_write(100_000).is_ok());
        assert!(g.admit_write(110_001).is_err());
    }

    #[test]
    fn time_going_backwards_rejected() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        g.grant_per_op(1_000);
        let err = g.admit_write(500).unwrap_err();
        assert!(matches!(err, BiometricGateError::PerOpTierExpired { .. }));
    }

    #[test]
    fn boundary_at_exactly_window_admits() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        g.grant_per_op(0);
        assert!(g.admit_write(60_000).is_ok());
    }

    #[test]
    fn boundary_at_window_plus_one_rejects() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        g.grant_per_op(0);
        assert!(g.admit_write(60_001).is_err());
    }

    #[test]
    fn gate_roundtrips_through_serde_json() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        g.grant_per_op(1_000);
        let json = serde_json::to_string(&g).unwrap();
        let back: BiometricWriteGate = serde_json::from_str(&json).unwrap();
        assert_eq!(g, back);
    }

    // ── AdmissionDecision + remaining_per_op_ms (iter 90) ───────────────────

    #[test]
    fn remaining_per_op_ms_none_before_first_grant() {
        let g = BiometricWriteGate::new(60_000).unwrap();
        assert_eq!(g.remaining_per_op_ms(0), None);
    }

    #[test]
    fn remaining_per_op_ms_full_window_at_grant_instant() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_per_op(1000);
        assert_eq!(g.remaining_per_op_ms(1000), Some(60_000));
    }

    #[test]
    fn remaining_per_op_ms_decreases_with_time() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_per_op(0);
        assert_eq!(g.remaining_per_op_ms(10_000), Some(50_000));
        assert_eq!(g.remaining_per_op_ms(59_999), Some(1));
    }

    #[test]
    fn remaining_per_op_ms_zero_at_expiry() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_per_op(0);
        assert_eq!(g.remaining_per_op_ms(60_000), Some(0));
        assert_eq!(g.remaining_per_op_ms(100_000), Some(0));
    }

    #[test]
    fn decide_no_mount_returns_prompt_for_mount() {
        let g = BiometricWriteGate::new(60_000).unwrap();
        let d = g.decide(0);
        assert_eq!(
            d,
            AdmissionDecision::Deny {
                reason: DenyReason::MountTierMissing,
                next_action: NextAction::PromptForMount,
            }
        );
        assert!(!d.is_admitted());
    }

    #[test]
    fn decide_mount_only_returns_prompt_for_per_op() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        let d = g.decide(0);
        assert_eq!(
            d,
            AdmissionDecision::Deny {
                reason: DenyReason::PerOpNeverAuthenticated,
                next_action: NextAction::PromptForPerOp,
            }
        );
    }

    #[test]
    fn decide_both_tiers_within_window_admits() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        g.grant_per_op(0);
        let d = g.decide(30_000);
        assert_eq!(
            d,
            AdmissionDecision::Admit { remaining_per_op_ms: 30_000 }
        );
        assert!(d.is_admitted());
    }

    #[test]
    fn decide_per_op_expired_prompts_re_auth() {
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        g.grant_per_op(0);
        let d = g.decide(60_001);
        assert_eq!(
            d,
            AdmissionDecision::Deny {
                reason: DenyReason::PerOpExpired,
                next_action: NextAction::PromptForPerOp,
            }
        );
    }

    #[test]
    fn decide_mount_takes_precedence_over_per_op_check() {
        // Per-op granted then mount revoked → deny should be
        // MountTierMissing, not PerOpExpired.
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        g.grant_per_op(1000);
        g.revoke_mount();
        let d = g.decide(2000);
        assert_eq!(
            d,
            AdmissionDecision::Deny {
                reason: DenyReason::MountTierMissing,
                next_action: NextAction::PromptForMount,
            }
        );
    }

    #[test]
    fn decision_roundtrips_through_serde_json() {
        let d = AdmissionDecision::Admit { remaining_per_op_ms: 12_345 };
        let json = serde_json::to_string(&d).unwrap();
        let back: AdmissionDecision = serde_json::from_str(&json).unwrap();
        assert_eq!(d, back);

        let d = AdmissionDecision::Deny {
            reason: DenyReason::PerOpExpired,
            next_action: NextAction::PromptForPerOp,
        };
        let json = serde_json::to_string(&d).unwrap();
        let back: AdmissionDecision = serde_json::from_str(&json).unwrap();
        assert_eq!(d, back);
    }
}
