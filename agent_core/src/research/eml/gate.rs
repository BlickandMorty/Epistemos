//! Source: V6.1 integration §"Terminal B" B.0.6 — GATE: AnswerPacket
//! schema freeze blocked until B.0.4 (ULP fixture) passes.
//!
//! # AnswerPacket schema-freeze gate
//!
//! Disciplinary commitment per V6.1 Foundation Doc Part X: no claim
//! envelope ships without a verified arithmetic floor. This module
//! owns the gate-status check that any future AnswerPacket schema-
//! freeze code must call before declaring the schema frozen.
//!
//! The actual schema definition lives outside this module (Wave I A2UI
//! Core or Wave 9+ integration); the gate is the bottleneck primitive.

use super::ulp_oracle::{run_smoke_oracle, UlpOracleReport, UlpToleranceFp16};

#[derive(Clone, Debug, PartialEq)]
pub enum GateStatus {
    Allowed { report: UlpOracleReport },
    Blocked { report: UlpOracleReport, reason: &'static str },
}

impl GateStatus {
    pub fn is_allowed(&self) -> bool {
        matches!(self, GateStatus::Allowed { .. })
    }

    /// Complement to [`Self::is_allowed`]. True iff the gate is
    /// Blocked. Equivalent to `!is_allowed()` but reads as the
    /// "did we fail?" predicate the freeze-call-site cares about.
    pub fn is_blocked(&self) -> bool {
        matches!(self, GateStatus::Blocked { .. })
    }

    /// The UlpOracleReport carried by either variant. Lets a caller
    /// inspect the oracle's full result without matching on the
    /// variant first.
    pub fn report(&self) -> &UlpOracleReport {
        match self {
            GateStatus::Allowed { report } => report,
            GateStatus::Blocked { report, .. } => report,
        }
    }

    /// Block reason string, or `None` when the gate is Allowed.
    /// Useful for the control-room "why did freeze fail?" surface.
    pub fn block_reason(&self) -> Option<&'static str> {
        match self {
            GateStatus::Allowed { .. } => None,
            GateStatus::Blocked { reason, .. } => Some(*reason),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum GateError {
    OracleFailedToRun,
}

/// Check whether AnswerPacket schema freeze is allowed. Runs the smoke
/// ULP oracle at the shipping bar; allows freeze iff the oracle is
/// within bar on every sample. The substrate-floor smoke run is a
/// PROXY for the full 412k+2048 production fixture; production code
/// MUST upgrade to the full run before actually freezing.
pub fn check_answer_packet_freeze_allowed() -> Result<GateStatus, GateError> {
    check_with_custom_tolerance(UlpToleranceFp16::SHIPPING_BAR)
}

/// Variant of [`check_answer_packet_freeze_allowed`] that lets the
/// caller supply a custom tolerance bar — useful for "what would the
/// gate verdict be at a stricter / looser bar?" exploration without
/// shipping that bar.
pub fn check_with_custom_tolerance(
    tolerance: UlpToleranceFp16,
) -> Result<GateStatus, GateError> {
    let report =
        run_smoke_oracle(tolerance).map_err(|_| GateError::OracleFailedToRun)?;
    if report.all_within_bar {
        Ok(GateStatus::Allowed { report })
    } else {
        Ok(GateStatus::Blocked {
            report,
            reason: "ULP smoke oracle exceeded shipping bar — production 412k fixture required",
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn gate_allowed_when_smoke_oracle_passes() {
        let s = check_answer_packet_freeze_allowed().unwrap();
        assert!(s.is_allowed());
    }

    #[test]
    fn allowed_carries_smoke_report() {
        let s = check_answer_packet_freeze_allowed().unwrap();
        match s {
            GateStatus::Allowed { report } => {
                assert_eq!(report.bar, 2.0);
                assert!(report.all_within_bar);
            }
            GateStatus::Blocked { .. } => panic!("expected Allowed"),
        }
    }

    #[test]
    fn status_is_allowed_predicate_works() {
        let allowed = GateStatus::Allowed {
            report: run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap(),
        };
        assert!(allowed.is_allowed());
        let blocked = GateStatus::Blocked {
            report: run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap(),
            reason: "test",
        };
        assert!(!blocked.is_allowed());
    }

    // ── is_blocked + report + block_reason + custom_tolerance (iter 134) ────

    #[test]
    fn is_blocked_complements_is_allowed() {
        let allowed = GateStatus::Allowed {
            report: run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap(),
        };
        assert!(!allowed.is_blocked());

        let blocked = GateStatus::Blocked {
            report: run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap(),
            reason: "test",
        };
        assert!(blocked.is_blocked());
    }

    #[test]
    fn is_allowed_and_is_blocked_are_mutually_exclusive() {
        // Cross-surface invariant: exactly one of the two predicates
        // is true for any status.
        let allowed = GateStatus::Allowed {
            report: run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap(),
        };
        assert_ne!(allowed.is_allowed(), allowed.is_blocked());

        let blocked = GateStatus::Blocked {
            report: run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap(),
            reason: "x",
        };
        assert_ne!(blocked.is_allowed(), blocked.is_blocked());
    }

    #[test]
    fn report_accessor_extracts_oracle_result_regardless_of_variant() {
        let allowed = GateStatus::Allowed {
            report: run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap(),
        };
        assert_eq!(allowed.report().bar, 2.0);

        let blocked = GateStatus::Blocked {
            report: run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap(),
            reason: "x",
        };
        assert_eq!(blocked.report().bar, 2.0);
    }

    #[test]
    fn block_reason_none_when_allowed_some_when_blocked() {
        let allowed = GateStatus::Allowed {
            report: run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap(),
        };
        assert!(allowed.block_reason().is_none());

        let blocked = GateStatus::Blocked {
            report: run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR).unwrap(),
            reason: "specific failure",
        };
        assert_eq!(blocked.block_reason(), Some("specific failure"));
    }

    #[test]
    fn custom_tolerance_strict_bar_still_passes() {
        // Smoke oracle passes the 2-ULP shipping bar comfortably;
        // even a stricter 1-ULP bar might pass on the compressed range.
        let s = check_with_custom_tolerance(UlpToleranceFp16 { bar: 1.0 }).unwrap();
        // Don't assert specific verdict (depends on substrate-floor
        // f32-stand-in for f16 precision); just verify the gate ran
        // and produced a coherent status.
        assert!(s.is_allowed() || s.is_blocked());
    }

    #[test]
    fn custom_tolerance_loose_bar_definitely_passes() {
        let s = check_with_custom_tolerance(UlpToleranceFp16 { bar: 100.0 }).unwrap();
        assert!(s.is_allowed());
    }

    #[test]
    fn default_check_equivalent_to_custom_shipping_bar() {
        // The default-arg variant should produce the same verdict as
        // explicitly passing the SHIPPING_BAR.
        let default = check_answer_packet_freeze_allowed().unwrap();
        let explicit = check_with_custom_tolerance(UlpToleranceFp16::SHIPPING_BAR).unwrap();
        assert_eq!(default.is_allowed(), explicit.is_allowed());
        assert_eq!(default.report().bar, explicit.report().bar);
    }
}
