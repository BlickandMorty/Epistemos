//! Proof-carrying lease envelopes for cold-byte wake proposals.
//!
//! This layer sits above the substrate `ResidencyLease`: the substrate lease
//! proves a bounded TTL commitment, while this envelope proves why a cold byte
//! may wake, what it costs, what proof/falsifier backs it, how it falls back,
//! and how it rolls back. It is metadata-only and performs no byte transport.

use serde::{Deserialize, Serialize};

use crate::uas::{ResidencyLease, ResidencyTier, UasAddress, UasKind};

const LEASE_UAS_KIND: &str = "proof_carrying_residency_lease";
const PROOF_PREFIXES: [&str; 2] = ["F-", "proof:"];
const FALLBACK_PREFIX: &str = "fallback:";
const ROLLBACK_PREFIX: &str = "rollback:";

// UAS: uas/research-construction/proof-carrying-residency-lease
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProofCarryingResidencyLease {
    pub lease_address: UasAddress,
    pub unit_id: String,
    pub uas_address: UasAddress,
    pub residency_lease: ResidencyLease,
    pub lease_reason: String,
    pub active_byte_cost: u64,
    pub expected_utility_bps: u16,
    pub proof_or_falsifier_ref: String,
    pub fallback_ref: String,
    pub rollback_ref: String,
}

impl ProofCarryingResidencyLease {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        unit_id: impl Into<String>,
        uas_address: UasAddress,
        lease_reason: impl Into<String>,
        active_byte_cost: u64,
        expected_utility_bps: u16,
        proof_or_falsifier_ref: impl Into<String>,
        fallback_ref: impl Into<String>,
        rollback_ref: impl Into<String>,
        granted_at_ms: u64,
        ttl_ms: u64,
    ) -> Result<Self, ProofCarryingResidencyLeaseError> {
        let unit_id = unit_id.into();
        let lease_reason = lease_reason.into();
        let proof_or_falsifier_ref = proof_or_falsifier_ref.into();
        let fallback_ref = fallback_ref.into();
        let rollback_ref = rollback_ref.into();

        validate_nonempty("unit_id", &unit_id)?;
        validate_nonempty("lease_reason", &lease_reason)?;
        validate_nonempty("proof_or_falsifier_ref", &proof_or_falsifier_ref)?;
        validate_nonempty("fallback_ref", &fallback_ref)?;
        validate_nonempty("rollback_ref", &rollback_ref)?;
        validate_positive_cost(active_byte_cost)?;
        validate_utility(expected_utility_bps)?;
        validate_ttl(ttl_ms)?;
        validate_proof_ref(&proof_or_falsifier_ref)?;
        validate_fallback_ref(&fallback_ref)?;
        validate_rollback_ref(&rollback_ref)?;

        let residency_lease = ResidencyLease::new(
            uas_address.clone(),
            ResidencyTier::CapabilityCeiling,
            granted_at_ms,
            ttl_ms,
        );
        let lease_address = lease_address(
            &unit_id,
            &uas_address,
            &residency_lease,
            &lease_reason,
            active_byte_cost,
            expected_utility_bps,
            &proof_or_falsifier_ref,
            &fallback_ref,
            &rollback_ref,
        );

        Ok(Self {
            lease_address,
            unit_id,
            uas_address,
            residency_lease,
            lease_reason,
            active_byte_cost,
            expected_utility_bps,
            proof_or_falsifier_ref,
            fallback_ref,
            rollback_ref,
        })
    }

    pub fn expires_at_ms(&self) -> u64 {
        self.residency_lease.expires_at_ms()
    }

    pub fn authorize_wake(
        &self,
        now_ms: u64,
        max_active_byte_cost: u64,
    ) -> Result<AuthorizedColdByteWake, ProofCarryingResidencyLeaseError> {
        self.validate_runtime_shape()?;
        if self.residency_lease.address != self.uas_address {
            return Err(ProofCarryingResidencyLeaseError::LeaseAddressDrift {
                unit_id: self.unit_id.clone(),
            });
        }
        if self.residency_lease.tier != ResidencyTier::CapabilityCeiling {
            return Err(ProofCarryingResidencyLeaseError::InvalidResidencyTier {
                unit_id: self.unit_id.clone(),
            });
        }
        if self.residency_lease.is_expired(now_ms) {
            return Err(ProofCarryingResidencyLeaseError::ExpiredLease {
                unit_id: self.unit_id.clone(),
            });
        }
        if self.active_byte_cost > max_active_byte_cost {
            return Err(ProofCarryingResidencyLeaseError::ActiveByteCostOverBudget {
                unit_id: self.unit_id.clone(),
                active_byte_cost: self.active_byte_cost,
                max_active_byte_cost,
            });
        }

        Ok(AuthorizedColdByteWake {
            unit_id: self.unit_id.clone(),
            uas_address: self.uas_address.clone(),
            lease_address: self.lease_address.clone(),
            active_byte_cost: self.active_byte_cost,
            expires_at_ms: self.expires_at_ms(),
            proof_or_falsifier_ref: self.proof_or_falsifier_ref.clone(),
            fallback_ref: self.fallback_ref.clone(),
            rollback_ref: self.rollback_ref.clone(),
        })
    }

    fn validate_runtime_shape(&self) -> Result<(), ProofCarryingResidencyLeaseError> {
        validate_nonempty("unit_id", &self.unit_id)?;
        validate_nonempty("lease_reason", &self.lease_reason)?;
        validate_nonempty("proof_or_falsifier_ref", &self.proof_or_falsifier_ref)?;
        validate_nonempty("fallback_ref", &self.fallback_ref)?;
        validate_nonempty("rollback_ref", &self.rollback_ref)?;
        validate_positive_cost(self.active_byte_cost)?;
        validate_utility(self.expected_utility_bps)?;
        validate_ttl(self.residency_lease.ttl_ms)?;
        validate_proof_ref(&self.proof_or_falsifier_ref)?;
        validate_fallback_ref(&self.fallback_ref)?;
        validate_rollback_ref(&self.rollback_ref)?;
        Ok(())
    }
}

pub fn authorize_cold_byte_wake(
    unit_id: &str,
    lease: Option<&ProofCarryingResidencyLease>,
    now_ms: u64,
    max_active_byte_cost: u64,
) -> Result<AuthorizedColdByteWake, ProofCarryingResidencyLeaseError> {
    validate_nonempty("unit_id", unit_id)?;
    let lease = lease.ok_or_else(|| ProofCarryingResidencyLeaseError::MissingLease {
        unit_id: unit_id.to_string(),
    })?;
    if lease.unit_id != unit_id {
        return Err(ProofCarryingResidencyLeaseError::UnitIdMismatch {
            requested_unit_id: unit_id.to_string(),
            lease_unit_id: lease.unit_id.clone(),
        });
    }
    lease.authorize_wake(now_ms, max_active_byte_cost)
}

// UAS: uas/research-construction/authorized-cold-byte-wake
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AuthorizedColdByteWake {
    pub unit_id: String,
    pub uas_address: UasAddress,
    pub lease_address: UasAddress,
    pub active_byte_cost: u64,
    pub expires_at_ms: u64,
    pub proof_or_falsifier_ref: String,
    pub fallback_ref: String,
    pub rollback_ref: String,
}

// UAS: uas/research-construction/proof-carrying-residency-lease-error
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ProofCarryingResidencyLeaseError {
    MissingUnitId,
    MissingLeaseReason,
    MissingProofOrFalsifierRef,
    MissingFallback,
    MissingRollback,
    MissingLease {
        unit_id: String,
    },
    UnitIdMismatch {
        requested_unit_id: String,
        lease_unit_id: String,
    },
    InvalidProofOrFalsifierRef {
        unit_id: String,
    },
    InvalidFallback {
        unit_id: String,
    },
    InvalidRollback {
        unit_id: String,
    },
    InvalidActiveByteCost,
    InvalidExpectedUtilityBps,
    InvalidTtlMs,
    InvalidResidencyTier {
        unit_id: String,
    },
    LeaseAddressDrift {
        unit_id: String,
    },
    ExpiredLease {
        unit_id: String,
    },
    ActiveByteCostOverBudget {
        unit_id: String,
        active_byte_cost: u64,
        max_active_byte_cost: u64,
    },
    FieldHasSurroundingWhitespace {
        field: &'static str,
    },
    FieldContainsControlCharacter {
        field: &'static str,
    },
}

impl std::fmt::Display for ProofCarryingResidencyLeaseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingUnitId => write!(f, "unit_id is required"),
            Self::MissingLeaseReason => write!(f, "lease_reason is required"),
            Self::MissingProofOrFalsifierRef => {
                write!(f, "proof_or_falsifier_ref is required")
            }
            Self::MissingFallback => write!(f, "fallback_ref is required"),
            Self::MissingRollback => write!(f, "rollback_ref is required"),
            Self::MissingLease { unit_id } => write!(f, "unit {unit_id} requires a lease"),
            Self::UnitIdMismatch {
                requested_unit_id,
                lease_unit_id,
            } => write!(
                f,
                "requested unit {requested_unit_id} does not match lease unit {lease_unit_id}"
            ),
            Self::InvalidProofOrFalsifierRef { unit_id } => {
                write!(f, "unit {unit_id} requires proof or falsifier reference")
            }
            Self::InvalidFallback { unit_id } => {
                write!(f, "unit {unit_id} requires a fallback reference")
            }
            Self::InvalidRollback { unit_id } => {
                write!(f, "unit {unit_id} requires a rollback reference")
            }
            Self::InvalidActiveByteCost => write!(f, "active_byte_cost must be nonzero"),
            Self::InvalidExpectedUtilityBps => {
                write!(f, "expected_utility_bps must be 1..=10000")
            }
            Self::InvalidTtlMs => write!(f, "ttl_ms must be nonzero"),
            Self::InvalidResidencyTier { unit_id } => {
                write!(f, "unit {unit_id} must use CapabilityCeiling residency")
            }
            Self::LeaseAddressDrift { unit_id } => {
                write!(f, "unit {unit_id} residency lease address drifted")
            }
            Self::ExpiredLease { unit_id } => write!(f, "unit {unit_id} lease expired"),
            Self::ActiveByteCostOverBudget {
                unit_id,
                active_byte_cost,
                max_active_byte_cost,
            } => write!(
                f,
                "unit {unit_id} active byte cost {active_byte_cost} exceeds {max_active_byte_cost}"
            ),
            Self::FieldHasSurroundingWhitespace { field } => {
                write!(f, "{field} must not contain leading or trailing whitespace")
            }
            Self::FieldContainsControlCharacter { field } => {
                write!(f, "{field} must not contain control characters")
            }
        }
    }
}

impl std::error::Error for ProofCarryingResidencyLeaseError {}

fn lease_address(
    unit_id: &str,
    uas_address: &UasAddress,
    residency_lease: &ResidencyLease,
    lease_reason: &str,
    active_byte_cost: u64,
    expected_utility_bps: u16,
    proof_or_falsifier_ref: &str,
    fallback_ref: &str,
    rollback_ref: &str,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str("proof_carrying_residency_lease_v1\n");
    push_preimage(&mut preimage, "unit_id", unit_id);
    push_preimage(&mut preimage, "uas_address", &uas_address.to_string());
    push_preimage(&mut preimage, "tier", residency_lease.tier.wire_tag());
    push_preimage(
        &mut preimage,
        "granted_at_ms",
        &residency_lease.granted_at_ms.to_string(),
    );
    push_preimage(&mut preimage, "ttl_ms", &residency_lease.ttl_ms.to_string());
    push_preimage(
        &mut preimage,
        "expires_at_ms",
        &residency_lease.expires_at_ms().to_string(),
    );
    push_preimage(&mut preimage, "lease_reason", lease_reason);
    push_preimage(
        &mut preimage,
        "active_byte_cost",
        &active_byte_cost.to_string(),
    );
    push_preimage(
        &mut preimage,
        "expected_utility_bps",
        &expected_utility_bps.to_string(),
    );
    push_preimage(
        &mut preimage,
        "proof_or_falsifier_ref",
        proof_or_falsifier_ref,
    );
    push_preimage(&mut preimage, "fallback_ref", fallback_ref);
    push_preimage(&mut preimage, "rollback_ref", rollback_ref);
    UasAddress::new(
        UasKind::Other(LEASE_UAS_KIND.to_string()),
        preimage.as_bytes(),
        residency_lease.granted_at_ms,
    )
}

fn push_preimage(preimage: &mut String, key: &str, value: &str) {
    preimage.push_str(key);
    preimage.push('=');
    preimage.push_str(value);
    preimage.push('\n');
}

fn validate_nonempty(
    field: &'static str,
    value: &str,
) -> Result<(), ProofCarryingResidencyLeaseError> {
    if value.trim().is_empty() {
        return match field {
            "unit_id" => Err(ProofCarryingResidencyLeaseError::MissingUnitId),
            "lease_reason" => Err(ProofCarryingResidencyLeaseError::MissingLeaseReason),
            "proof_or_falsifier_ref" => {
                Err(ProofCarryingResidencyLeaseError::MissingProofOrFalsifierRef)
            }
            "fallback_ref" => Err(ProofCarryingResidencyLeaseError::MissingFallback),
            "rollback_ref" => Err(ProofCarryingResidencyLeaseError::MissingRollback),
            _ => Err(ProofCarryingResidencyLeaseError::FieldContainsControlCharacter { field }),
        };
    }
    if value.trim() != value {
        return Err(ProofCarryingResidencyLeaseError::FieldHasSurroundingWhitespace { field });
    }
    if value.chars().any(char::is_control) {
        return Err(ProofCarryingResidencyLeaseError::FieldContainsControlCharacter { field });
    }
    Ok(())
}

fn validate_positive_cost(active_byte_cost: u64) -> Result<(), ProofCarryingResidencyLeaseError> {
    if active_byte_cost == 0 {
        Err(ProofCarryingResidencyLeaseError::InvalidActiveByteCost)
    } else {
        Ok(())
    }
}

fn validate_utility(expected_utility_bps: u16) -> Result<(), ProofCarryingResidencyLeaseError> {
    if expected_utility_bps == 0 || expected_utility_bps > 10_000 {
        Err(ProofCarryingResidencyLeaseError::InvalidExpectedUtilityBps)
    } else {
        Ok(())
    }
}

fn validate_ttl(ttl_ms: u64) -> Result<(), ProofCarryingResidencyLeaseError> {
    if ttl_ms == 0 {
        Err(ProofCarryingResidencyLeaseError::InvalidTtlMs)
    } else {
        Ok(())
    }
}

fn validate_proof_ref(value: &str) -> Result<(), ProofCarryingResidencyLeaseError> {
    if PROOF_PREFIXES
        .iter()
        .any(|prefix| value.starts_with(prefix))
    {
        Ok(())
    } else {
        Err(
            ProofCarryingResidencyLeaseError::InvalidProofOrFalsifierRef {
                unit_id: value.to_string(),
            },
        )
    }
}

fn validate_fallback_ref(value: &str) -> Result<(), ProofCarryingResidencyLeaseError> {
    if value.starts_with(FALLBACK_PREFIX) {
        Ok(())
    } else {
        Err(ProofCarryingResidencyLeaseError::InvalidFallback {
            unit_id: value.to_string(),
        })
    }
}

fn validate_rollback_ref(value: &str) -> Result<(), ProofCarryingResidencyLeaseError> {
    if value.starts_with(ROLLBACK_PREFIX) {
        Ok(())
    } else {
        Err(ProofCarryingResidencyLeaseError::InvalidRollback {
            unit_id: value.to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_100_000_000;

    fn sample_address() -> UasAddress {
        UasAddress::new(UasKind::KvPage, b"cold-kv-page", CREATED_AT_MS)
    }

    fn valid_lease() -> ProofCarryingResidencyLease {
        ProofCarryingResidencyLease::new(
            "unit:cold-evidence",
            sample_address(),
            "answer needs cold evidence bundle",
            32 * 1024,
            9_200,
            "F-CoactivationTile-Prefetch",
            "fallback:skip-cold-evidence",
            "rollback:restore-hot-only-route",
            CREATED_AT_MS,
            120_000,
        )
        .expect("valid lease")
    }

    #[test]
    fn proof_carrying_lease_authorizes_bounded_wake() {
        let lease = valid_lease();
        let wake = lease
            .authorize_wake(CREATED_AT_MS + 1_000, 64 * 1024)
            .expect("wake should authorize");

        assert_eq!(wake.unit_id, "unit:cold-evidence");
        assert_eq!(wake.active_byte_cost, 32 * 1024);
        assert_eq!(wake.expires_at_ms, CREATED_AT_MS + 120_000);
        assert_eq!(wake.rollback_ref, "rollback:restore-hot-only-route");
        assert_eq!(lease.residency_lease.tier, ResidencyTier::CapabilityCeiling);
    }

    #[test]
    fn proof_carrying_lease_address_is_deterministic() {
        let first = valid_lease();
        let second = valid_lease();

        assert_eq!(first.lease_address, second.lease_address);
        assert_eq!(first.expires_at_ms(), CREATED_AT_MS + 120_000);
    }

    #[test]
    fn proof_carrying_lease_rejects_missing_evidence() {
        let missing_proof = ProofCarryingResidencyLease::new(
            "unit:bad",
            sample_address(),
            "needs cold bytes",
            1,
            1,
            "",
            "fallback:skip",
            "rollback:hot-route",
            CREATED_AT_MS,
            1,
        )
        .expect_err("missing proof should reject");
        let missing_fallback = ProofCarryingResidencyLease::new(
            "unit:bad",
            sample_address(),
            "needs cold bytes",
            1,
            1,
            "F-CoactivationTile-Prefetch",
            "",
            "rollback:hot-route",
            CREATED_AT_MS,
            1,
        )
        .expect_err("missing fallback should reject");
        let missing_rollback = ProofCarryingResidencyLease::new(
            "unit:bad",
            sample_address(),
            "needs cold bytes",
            1,
            1,
            "F-CoactivationTile-Prefetch",
            "fallback:skip",
            "",
            CREATED_AT_MS,
            1,
        )
        .expect_err("missing rollback should reject");

        assert_eq!(
            missing_proof,
            ProofCarryingResidencyLeaseError::MissingProofOrFalsifierRef
        );
        assert_eq!(
            missing_fallback,
            ProofCarryingResidencyLeaseError::MissingFallback
        );
        assert_eq!(
            missing_rollback,
            ProofCarryingResidencyLeaseError::MissingRollback
        );
    }

    #[test]
    fn proof_carrying_lease_rejects_expired_or_over_budget_wake() {
        let lease = valid_lease();
        let expired = lease
            .authorize_wake(CREATED_AT_MS + 120_000, 64 * 1024)
            .expect_err("expired lease should reject");
        let over_budget = lease
            .authorize_wake(CREATED_AT_MS + 1_000, 16 * 1024)
            .expect_err("over-budget wake should reject");

        assert!(matches!(
            expired,
            ProofCarryingResidencyLeaseError::ExpiredLease { .. }
        ));
        assert!(matches!(
            over_budget,
            ProofCarryingResidencyLeaseError::ActiveByteCostOverBudget { .. }
        ));
    }

    #[test]
    fn cold_byte_wake_requires_matching_lease() {
        let lease = valid_lease();
        let missing =
            authorize_cold_byte_wake("unit:cold-evidence", None, CREATED_AT_MS + 1_000, 64 * 1024)
                .expect_err("missing lease should reject");
        let mismatch =
            authorize_cold_byte_wake("unit:other", Some(&lease), CREATED_AT_MS + 1_000, 64 * 1024)
                .expect_err("wrong lease should reject");

        assert!(matches!(
            missing,
            ProofCarryingResidencyLeaseError::MissingLease { .. }
        ));
        assert!(matches!(
            mismatch,
            ProofCarryingResidencyLeaseError::UnitIdMismatch { .. }
        ));
    }
}
