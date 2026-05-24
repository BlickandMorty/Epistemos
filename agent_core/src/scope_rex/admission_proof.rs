//! SCOPE-Rex admission proof boundary for ACS-admitted handoffs.
//!
//! The lower ACS admission module signs the full record binding
//! `(verdict, operation, record_id)`. The cross-lane handoff shape
//! intentionally exposes only the verdict, record id, and capability
//! signature; verification rehydrates the operation from the audited
//! record before accepting the proof.

use serde::{Deserialize, Serialize};

use crate::{
    acs_admission::{
        resolve_acs_audit_record, ACSAdmissionProofError, ACSAdmissionVerdict, ACSAuditRecord,
        AuditRecordId, CapabilitySignature, SCOPERexAdmissionProofVerificationError,
    },
    effect::receipt::SigningKey,
    oplog::OpLog,
};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SCOPERexAdmissionProof {
    pub verdict: ACSAdmissionVerdict,
    pub record_id: AuditRecordId,
    pub capability_signature: CapabilitySignature,
}

impl SCOPERexAdmissionProof {
    pub fn signed_from_record<K: SigningKey>(
        record: &ACSAuditRecord,
        key: &K,
    ) -> Result<Self, ACSAdmissionProofError> {
        let proof = crate::acs_admission::SCOPERexAdmissionProof::signed_from_record(record, key)?;
        Ok(Self::from_acs_proof(proof))
    }

    pub fn verify_against_record<K: SigningKey>(
        &self,
        record: &ACSAuditRecord,
        key: &K,
    ) -> Result<(), ACSAdmissionProofError> {
        let proof = crate::acs_admission::SCOPERexAdmissionProof::new(
            self.verdict,
            record.operation,
            self.record_id.clone(),
            self.capability_signature.clone(),
        )?;
        proof.verify_against_record(record, key)
    }

    pub fn verify_against_run_event_log<K: SigningKey>(
        &self,
        run_event_log: &OpLog,
        key: &K,
    ) -> Result<ACSAuditRecord, SCOPERexAdmissionProofVerificationError> {
        let record = resolve_acs_audit_record(run_event_log, &self.record_id).map_err(|error| {
            let needs_fallback_record_id = error.record_id().is_none();
            SCOPERexAdmissionProofVerificationError::Lookup {
                error,
                record_id: needs_fallback_record_id.then(|| self.record_id.0.clone()),
            }
        })?;
        self.verify_against_record(&record, key).map_err(|error| {
            SCOPERexAdmissionProofVerificationError::Proof {
                error,
                record_id: self.record_id.0.clone(),
            }
        })?;
        Ok(record)
    }

    pub fn from_acs_proof(proof: crate::acs_admission::SCOPERexAdmissionProof) -> Self {
        Self {
            verdict: proof.verdict,
            record_id: proof.record_id,
            capability_signature: proof.signature,
        }
    }
}
