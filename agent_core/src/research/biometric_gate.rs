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
    pub const ALL: [BiometricTier; 2] = [BiometricTier::Mount, BiometricTier::PerOp];

    pub const fn code(self) -> &'static str {
        match self {
            BiometricTier::Mount => "mount",
            BiometricTier::PerOp => "per_op",
        }
    }

    /// Reverse lookup for [`Self::code`]. `None` for unknown codes.
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|t| t.code() == code)
    }
}

impl BiometricGateError {
    /// Stable identifier for the failure cause.
    pub const fn cause(&self) -> &'static str {
        match self {
            BiometricGateError::MountTierMissing => "mount_tier_missing",
            BiometricGateError::PerOpTierExpired { .. } => "per_op_tier_expired",
            BiometricGateError::PerOpNeverAuthenticated => "per_op_never_authenticated",
            BiometricGateError::NonPositiveWindow { .. } => "non_positive_window",
        }
    }

    /// Predicate: the error pertains to the mount tier.
    pub const fn is_mount_tier(&self) -> bool {
        matches!(self, BiometricGateError::MountTierMissing)
    }

    /// Predicate: the error pertains to the per-op tier
    /// (PerOpTierExpired or PerOpNeverAuthenticated).
    pub const fn is_per_op_tier(&self) -> bool {
        matches!(
            self,
            BiometricGateError::PerOpTierExpired { .. }
                | BiometricGateError::PerOpNeverAuthenticated
        )
    }

    /// Predicate: the error pertains to constructor validation
    /// (NonPositiveWindow). Cross-surface invariant: exactly one of
    /// is_mount_tier / is_per_op_tier / is_config is true per variant.
    pub const fn is_config(&self) -> bool {
        matches!(self, BiometricGateError::NonPositiveWindow { .. })
    }
}

impl DenyReason {
    pub const ALL: [DenyReason; 3] = [
        DenyReason::MountTierMissing,
        DenyReason::PerOpNeverAuthenticated,
        DenyReason::PerOpExpired,
    ];

    pub const fn code(self) -> &'static str {
        match self {
            DenyReason::MountTierMissing => "mount_tier_missing",
            DenyReason::PerOpNeverAuthenticated => "per_op_never_authenticated",
            DenyReason::PerOpExpired => "per_op_expired",
        }
    }

    /// Reverse lookup for [`Self::code`].
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|r| r.code() == code)
    }
}

impl NextAction {
    pub const ALL: [NextAction; 2] = [NextAction::PromptForMount, NextAction::PromptForPerOp];

    pub const fn code(self) -> &'static str {
        match self {
            NextAction::PromptForMount => "prompt_for_mount",
            NextAction::PromptForPerOp => "prompt_for_per_op",
        }
    }

    /// Reverse lookup for [`Self::code`].
    pub fn from_code(code: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|a| a.code() == code)
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

    /// Complement to [`Self::is_admitted`]. Cross-surface invariant:
    /// `is_admitted XOR is_denied` for every AdmissionDecision.
    pub fn is_denied(&self) -> bool {
        matches!(self, AdmissionDecision::Deny { .. })
    }

    /// Extract the deny reason, or `None` if admitted.
    pub fn deny_reason(&self) -> Option<DenyReason> {
        match self {
            AdmissionDecision::Admit { .. } => None,
            AdmissionDecision::Deny { reason, .. } => Some(*reason),
        }
    }

    /// Extract the next action, or `None` if admitted.
    pub fn next_action(&self) -> Option<NextAction> {
        match self {
            AdmissionDecision::Admit { .. } => None,
            AdmissionDecision::Deny { next_action, .. } => Some(*next_action),
        }
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

    // ── diagnostic surface (iter 153) ────────────────────────────────────────

    #[test]
    fn tier_from_code_roundtrips() {
        for t in BiometricTier::ALL.iter().copied() {
            assert_eq!(BiometricTier::from_code(t.code()), Some(t));
        }
        assert_eq!(BiometricTier::from_code("Mount"), None); // case-sensitive
        assert_eq!(BiometricTier::from_code(""), None);
    }

    #[test]
    fn gate_error_cause_distinct_per_variant() {
        let variants = [
            BiometricGateError::MountTierMissing,
            BiometricGateError::PerOpTierExpired {
                last_auth_at_unix_ms: 0,
                now_unix_ms: 0,
                window_ms: 0,
            },
            BiometricGateError::PerOpNeverAuthenticated,
            BiometricGateError::NonPositiveWindow { window_ms: 0 },
        ];
        let causes: std::collections::HashSet<_> = variants.iter().map(|e| e.cause()).collect();
        assert_eq!(causes.len(), 4);
    }

    #[test]
    fn gate_error_classifiers_partition_variants() {
        let variants = [
            BiometricGateError::MountTierMissing,
            BiometricGateError::PerOpTierExpired {
                last_auth_at_unix_ms: 0,
                now_unix_ms: 0,
                window_ms: 0,
            },
            BiometricGateError::PerOpNeverAuthenticated,
            BiometricGateError::NonPositiveWindow { window_ms: 0 },
        ];
        for e in &variants {
            let trio = [e.is_mount_tier(), e.is_per_op_tier(), e.is_config()];
            assert_eq!(trio.iter().filter(|t| **t).count(), 1, "{:?}", e);
        }
    }

    #[test]
    fn deny_reason_from_code_roundtrips() {
        for r in DenyReason::ALL.iter().copied() {
            assert_eq!(DenyReason::from_code(r.code()), Some(r));
        }
        assert_eq!(DenyReason::from_code("unknown"), None);
    }

    #[test]
    fn next_action_from_code_roundtrips() {
        for a in NextAction::ALL.iter().copied() {
            assert_eq!(NextAction::from_code(a.code()), Some(a));
        }
        assert_eq!(NextAction::from_code("PromptForMount"), None); // case-sensitive
    }

    #[test]
    fn admit_xor_deny_partitions_decisions() {
        // Cross-surface invariant: every AdmissionDecision is exactly
        // one of admitted / denied.
        let admit = AdmissionDecision::Admit { remaining_per_op_ms: 100 };
        let deny = AdmissionDecision::Deny {
            reason: DenyReason::MountTierMissing,
            next_action: NextAction::PromptForMount,
        };
        for d in [admit, deny] {
            assert_ne!(d.is_admitted(), d.is_denied());
        }
    }

    #[test]
    fn deny_reason_and_next_action_extracted_when_denied() {
        let d = AdmissionDecision::Deny {
            reason: DenyReason::PerOpExpired,
            next_action: NextAction::PromptForPerOp,
        };
        assert_eq!(d.deny_reason(), Some(DenyReason::PerOpExpired));
        assert_eq!(d.next_action(), Some(NextAction::PromptForPerOp));

        let a = AdmissionDecision::Admit { remaining_per_op_ms: 1 };
        assert_eq!(a.deny_reason(), None);
        assert_eq!(a.next_action(), None);
    }

    #[test]
    fn decide_admit_aligns_with_admit_write_ok() {
        // Cross-surface invariant: decide().is_admitted() iff admit_write().is_ok().
        // Sweep across multiple gate states.
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        // Fresh gate: both deny.
        assert_eq!(g.decide(0).is_admitted(), g.admit_write(0).is_ok());
        // Mount only.
        g.grant_mount();
        assert_eq!(g.decide(0).is_admitted(), g.admit_write(0).is_ok());
        // Mount + per-op within window.
        g.grant_per_op(0);
        assert_eq!(g.decide(30_000).is_admitted(), g.admit_write(30_000).is_ok());
        // Expired.
        assert_eq!(g.decide(60_001).is_admitted(), g.admit_write(60_001).is_ok());
    }

    #[test]
    fn remaining_zero_aligns_with_admit_write_expired() {
        // Cross-surface invariant: remaining_per_op_ms == Some(0) implies
        // admit_write returns PerOpTierExpired (given mount is granted).
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        g.grant_per_op(0);
        assert_eq!(g.remaining_per_op_ms(60_000), Some(0));
        // 60_000 is the exact boundary — at-boundary admits (elapsed == window).
        assert!(g.admit_write(60_000).is_ok());
        // One ms past boundary: remaining still 0, admit fails.
        assert_eq!(g.remaining_per_op_ms(60_001), Some(0));
        assert!(g.admit_write(60_001).is_err());
    }

    #[test]
    fn decision_remaining_per_op_matches_remaining_per_op_ms() {
        // Cross-surface: when decide() admits, remaining_per_op_ms
        // in the Admit variant equals gate.remaining_per_op_ms(now).
        let mut g = BiometricWriteGate::new(60_000).unwrap();
        g.grant_mount();
        g.grant_per_op(0);
        let d = g.decide(20_000);
        match d {
            AdmissionDecision::Admit { remaining_per_op_ms } => {
                assert_eq!(Some(remaining_per_op_ms), g.remaining_per_op_ms(20_000));
            }
            _ => panic!("expected admit"),
        }
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
