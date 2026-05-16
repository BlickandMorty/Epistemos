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
    let report = run_smoke_oracle(UlpToleranceFp16::SHIPPING_BAR)
        .map_err(|_| GateError::OracleFailedToRun)?;
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
}
