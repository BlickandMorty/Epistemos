//! Synthetic fixture owner-approval write gate.
//!
//! Metadata-only successor to the staging-manifest preflight
//! (`synthetic_fixture_staging_manifest_preflight_gate`). It consumes the
//! manifest preflight, preserves the exact owner-approval phrase, and proves
//! that owner approval is **absent** — and therefore no synthetic fixture write
//! is authorized — unless the exact phrase is explicitly provided AND every
//! upstream address matches. The canonical witness models the safe default
//! (phrase absent → approval absent → write blocked); filesystem/byte counters
//! stay at zero. This gate records consent state, it does not perform the write
//! (the staged write remains the owner-gated frontier).
//!
//! See docs/fusion/DEEP_RESEARCH_BREAKTHROUGH_SYNTHESIS_2026_06_06.md and
//! docs/falsifiers/F-SyntheticFixtureStagingManifestPreflightGate_2026_06_08.md.

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::synthetic_fixture_staging_manifest_preflight_gate::{
    SyntheticFixtureStagingManifestPreflightWitness,
    SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_CURSOR,
    SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_ID,
};
use serde::{Deserialize, Serialize};
use std::fmt;

pub const SYNTHETIC_FIXTURE_OWNER_APPROVAL_WRITE_GATE_ID: &str =
    "F-SyntheticFixtureOwnerApprovalWriteGate";
pub const SYNTHETIC_FIXTURE_OWNER_APPROVAL_WRITE_GATE_CURSOR: &str =
    "synthetic_fixture_owner_approval_write_gate";
// The next side-ladder unit — the actual staged write — is the owner-gated
// frontier and is not yet authored (it needs owner-approved on-device bytes).
pub const SYNTHETIC_FIXTURE_OWNER_APPROVAL_WRITE_GATE_NEXT_CURSOR: &str =
    "synthetic_fixture_staged_write_owner_gated_frontier";

// Must stay byte-identical to the manifest preflight's phrase — this gate
// "preserves the exact approval phrase".
const APPROVAL_PHRASE: &str = "APPROVE_SYNTHETIC_FIXTURE_MATERIALIZATION_V0";
const ROLLBACK_REF: &str = "rollback:synthetic_fixture_owner_approval_write_gate";
const RUN_EVENT_LOG_REF: &str = "run_event_log:synthetic_fixture_owner_approval_write_gate";
const ANSWER_PACKET_REF: &str = "answer_packet:synthetic_fixture_owner_approval_write_gate";
const GUARD_PRODUCT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
// UAS: uas:synthetic-fixture-owner-approval-write:status
// Plane: Verification + Controller.
// Residency: metadata-only consent gate; no consent record or fixture is written.
pub enum SyntheticFixtureOwnerApprovalStatus {
    OwnerApprovalAbsentWritesStillBlocked,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-fixture-owner-approval-write:spec
// Plane: Verification + Controller.
// Residency: consent contract before owner-approved synthetic fixture writes.
pub struct SyntheticFixtureOwnerApprovalWriteGate {
    pub upstream_falsifier_id: String,
    pub upstream_cursor: String,
    pub upstream_manifest_preflight_address: String,
    pub owner_approval_phrase: String,
    /// The phrase actually presented. Empty = absent (the canonical safe state).
    pub provided_approval_phrase: String,
    /// Derived consent state: true iff `provided_approval_phrase` equals the
    /// exact `owner_approval_phrase`. Canonical witness keeps this false.
    pub owner_approval_present: bool,
    pub exact_phrase_required_for_write: bool,
    pub manifest_preflight_consumed: bool,
    pub repo_relative_paths_required: bool,
    pub absolute_paths_denied: bool,
    pub parent_segments_denied: bool,
    pub hidden_segments_denied: bool,
    pub symlink_follow_denied: bool,
    pub hardlink_denied: bool,
    pub direct_final_write_denied: bool,
    pub cross_device_rename_denied: bool,
    pub preexisting_final_collision_denied: bool,
    pub rollback_receipt_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub privacy_scan_required: bool,
    pub provenance_scan_required: bool,
    pub benchmark_contamination_scan_required: bool,
    pub no_product_route_authority: bool,
    /// This gate never authorizes a write; consent only unblocks the next
    /// (still-gated) staged-write unit. Canonical and every valid witness keep
    /// this false.
    pub write_authorized: bool,
    pub consent_records_written: u64,
    pub manifest_files_written: u64,
    pub staging_files_written: u64,
    pub final_files_written: u64,
    pub fixture_bytes_written: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub cache_index_bytes_opened: u64,
    pub filesystem_stat_calls: u64,
    pub commands_armed: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub guard_owned_product_cursor: String,
    pub materialization_allowed: bool,
    pub metadata_only: bool,
    pub l1_claimed: bool,
    pub l2_claimed: bool,
    pub l3_claimed: bool,
    pub t4_t5_claimed: bool,
    pub product_green_claimed: bool,
    pub release_ready_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub hidden_route_authority_claimed: bool,
    pub status: SyntheticFixtureOwnerApprovalStatus,
}

impl SyntheticFixtureOwnerApprovalWriteGate {
    pub fn canonical() -> Result<Self, SyntheticFixtureOwnerApprovalError> {
        let upstream = SyntheticFixtureStagingManifestPreflightWitness::new()
            .map_err(|_| SyntheticFixtureOwnerApprovalError::UpstreamManifestPreflightBroken)?;
        upstream
            .validate()
            .map_err(|_| SyntheticFixtureOwnerApprovalError::UpstreamManifestPreflightBroken)?;
        Ok(Self {
            upstream_falsifier_id: SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_ID.to_string(),
            upstream_cursor: SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_CURSOR.to_string(),
            upstream_manifest_preflight_address: upstream.address,
            owner_approval_phrase: APPROVAL_PHRASE.to_string(),
            provided_approval_phrase: String::new(),
            owner_approval_present: false,
            exact_phrase_required_for_write: true,
            manifest_preflight_consumed: true,
            repo_relative_paths_required: true,
            absolute_paths_denied: true,
            parent_segments_denied: true,
            hidden_segments_denied: true,
            symlink_follow_denied: true,
            hardlink_denied: true,
            direct_final_write_denied: true,
            cross_device_rename_denied: true,
            preexisting_final_collision_denied: true,
            rollback_receipt_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            privacy_scan_required: true,
            provenance_scan_required: true,
            benchmark_contamination_scan_required: true,
            no_product_route_authority: true,
            write_authorized: false,
            consent_records_written: 0,
            manifest_files_written: 0,
            staging_files_written: 0,
            final_files_written: 0,
            fixture_bytes_written: 0,
            model_runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            cache_index_bytes_opened: 0,
            filesystem_stat_calls: 0,
            commands_armed: 0,
            rollback_ref: ROLLBACK_REF.to_string(),
            run_event_log_ref: RUN_EVENT_LOG_REF.to_string(),
            answer_packet_ref: ANSWER_PACKET_REF.to_string(),
            guard_owned_product_cursor: GUARD_PRODUCT_CURSOR.to_string(),
            materialization_allowed: false,
            metadata_only: true,
            l1_claimed: false,
            l2_claimed: false,
            l3_claimed: false,
            t4_t5_claimed: false,
            product_green_claimed: false,
            release_ready_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            hidden_route_authority_claimed: false,
            status: SyntheticFixtureOwnerApprovalStatus::OwnerApprovalAbsentWritesStillBlocked,
        })
    }

    pub fn validate(&self) -> Result<(), SyntheticFixtureOwnerApprovalError> {
        let upstream = SyntheticFixtureStagingManifestPreflightWitness::new()
            .map_err(|_| SyntheticFixtureOwnerApprovalError::UpstreamManifestPreflightBroken)?;
        upstream
            .validate()
            .map_err(|_| SyntheticFixtureOwnerApprovalError::UpstreamManifestPreflightBroken)?;
        validate_exact(
            "upstream_falsifier_id",
            &self.upstream_falsifier_id,
            SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_ID,
        )?;
        validate_exact(
            "upstream_cursor",
            &self.upstream_cursor,
            SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_CURSOR,
        )?;
        validate_exact(
            "upstream_manifest_preflight_address",
            &self.upstream_manifest_preflight_address,
            &upstream.address,
        )?;
        validate_exact(
            "owner_approval_phrase",
            &self.owner_approval_phrase,
            APPROVAL_PHRASE,
        )?;
        self.validate_consent()?;
        self.validate_policy()?;
        self.validate_zero_ledger()?;
        validate_exact("rollback_ref", &self.rollback_ref, ROLLBACK_REF)?;
        validate_exact(
            "run_event_log_ref",
            &self.run_event_log_ref,
            RUN_EVENT_LOG_REF,
        )?;
        validate_exact(
            "answer_packet_ref",
            &self.answer_packet_ref,
            ANSWER_PACKET_REF,
        )?;
        validate_exact(
            "guard_owned_product_cursor",
            &self.guard_owned_product_cursor,
            GUARD_PRODUCT_CURSOR,
        )?;
        if self.materialization_allowed || !self.metadata_only {
            return Err(SyntheticFixtureOwnerApprovalError::MaterializationBoundaryBroken);
        }
        if self.l1_claimed
            || self.l2_claimed
            || self.l3_claimed
            || self.t4_t5_claimed
            || self.product_green_claimed
            || self.release_ready_claimed
            || self.live_dense_70b_claimed
            || self.ssd_as_ram_claimed
            || self.hidden_route_authority_claimed
        {
            return Err(SyntheticFixtureOwnerApprovalError::PromotionClaim);
        }
        if self.status != SyntheticFixtureOwnerApprovalStatus::OwnerApprovalAbsentWritesStillBlocked
        {
            return Err(SyntheticFixtureOwnerApprovalError::WrongStatus);
        }
        Ok(())
    }

    /// The heart of the gate: consent is derived ONLY from the exact phrase, and
    /// this gate never authorizes a write regardless of consent.
    fn validate_consent(&self) -> Result<(), SyntheticFixtureOwnerApprovalError> {
        if !self.exact_phrase_required_for_write || !self.manifest_preflight_consumed {
            return Err(SyntheticFixtureOwnerApprovalError::ConsentContractBroken);
        }
        // A non-empty provided phrase must match exactly; control chars/whitespace
        // are rejected by validate_token via validate_exact below when present.
        if !self.provided_approval_phrase.is_empty()
            && self.provided_approval_phrase != APPROVAL_PHRASE
        {
            return Err(SyntheticFixtureOwnerApprovalError::WrongApprovalPhrase);
        }
        // owner_approval_present must equal (exact phrase provided). It cannot be
        // claimed true without the exact phrase, nor false when the phrase is present.
        let derived_present = self.provided_approval_phrase == APPROVAL_PHRASE;
        if self.owner_approval_present != derived_present {
            return Err(SyntheticFixtureOwnerApprovalError::ConsentClaimMismatch);
        }
        // This gate records consent only; it never authorizes the write itself.
        if self.write_authorized {
            return Err(SyntheticFixtureOwnerApprovalError::WriteAuthorizationLeak);
        }
        Ok(())
    }

    fn validate_policy(&self) -> Result<(), SyntheticFixtureOwnerApprovalError> {
        if !self.repo_relative_paths_required
            || !self.absolute_paths_denied
            || !self.parent_segments_denied
            || !self.hidden_segments_denied
            || !self.symlink_follow_denied
            || !self.hardlink_denied
            || !self.direct_final_write_denied
            || !self.cross_device_rename_denied
            || !self.preexisting_final_collision_denied
        {
            return Err(SyntheticFixtureOwnerApprovalError::PathPolicyBroken);
        }
        if !self.rollback_receipt_required
            || !self.run_event_log_required
            || !self.answer_packet_required
            || !self.privacy_scan_required
            || !self.provenance_scan_required
            || !self.benchmark_contamination_scan_required
            || !self.no_product_route_authority
        {
            return Err(SyntheticFixtureOwnerApprovalError::ProofPolicyBroken);
        }
        Ok(())
    }

    fn validate_zero_ledger(&self) -> Result<(), SyntheticFixtureOwnerApprovalError> {
        if self.consent_records_written != 0
            || self.manifest_files_written != 0
            || self.staging_files_written != 0
            || self.final_files_written != 0
            || self.fixture_bytes_written != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.cache_index_bytes_opened != 0
            || self.filesystem_stat_calls != 0
            || self.commands_armed != 0
        {
            return Err(SyntheticFixtureOwnerApprovalError::ByteOrCommandLeak);
        }
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-fixture-owner-approval-write:metrics
// Plane: Verification.
// Residency: metadata-only consent counters.
pub struct SyntheticFixtureOwnerApprovalMetrics {
    pub owner_approval_present: bool,
    pub policy_bit_count: u64,
    pub consent_records_written: u64,
    pub fixture_files_written: u64,
    pub fixture_bytes_written: u64,
    pub runtime_model_provider_cache_index_bytes: u64,
    pub commands_armed: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-fixture-owner-approval-write:witness
// Plane: Verification + Controller.
// Residency: L1/T1 consent gate; no consent record or fixture files.
pub struct SyntheticFixtureOwnerApprovalWriteWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub spec: SyntheticFixtureOwnerApprovalWriteGate,
    pub metrics: SyntheticFixtureOwnerApprovalMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub product_promotion_blocked: bool,
}

impl SyntheticFixtureOwnerApprovalWriteWitness {
    pub fn new() -> Result<Self, SyntheticFixtureOwnerApprovalError> {
        let spec = SyntheticFixtureOwnerApprovalWriteGate::canonical()?;
        spec.validate()?;
        let metrics = SyntheticFixtureOwnerApprovalMetrics {
            owner_approval_present: spec.owner_approval_present,
            policy_bit_count: 16,
            consent_records_written: spec.consent_records_written,
            fixture_files_written: spec.staging_files_written + spec.final_files_written,
            fixture_bytes_written: spec.fixture_bytes_written,
            runtime_model_provider_cache_index_bytes: spec.model_runtime_bytes_loaded
                + spec.provider_calls_made
                + spec.cache_index_bytes_opened,
            commands_armed: spec.commands_armed,
        };
        let address = synthetic_fixture_owner_approval_write_address(&spec, &metrics);
        Ok(Self {
            falsifier_id: SYNTHETIC_FIXTURE_OWNER_APPROVAL_WRITE_GATE_ID.to_string(),
            cursor: SYNTHETIC_FIXTURE_OWNER_APPROVAL_WRITE_GATE_CURSOR.to_string(),
            next_cursor: SYNTHETIC_FIXTURE_OWNER_APPROVAL_WRITE_GATE_NEXT_CURSOR.to_string(),
            spec,
            metrics,
            address,
            metadata_only: true,
            product_promotion_blocked: true,
        })
    }

    pub fn validate(&self) -> Result<(), SyntheticFixtureOwnerApprovalError> {
        if self.falsifier_id != SYNTHETIC_FIXTURE_OWNER_APPROVAL_WRITE_GATE_ID
            || self.cursor != SYNTHETIC_FIXTURE_OWNER_APPROVAL_WRITE_GATE_CURSOR
            || self.next_cursor != SYNTHETIC_FIXTURE_OWNER_APPROVAL_WRITE_GATE_NEXT_CURSOR
            || !self.metadata_only
            || !self.product_promotion_blocked
        {
            return Err(SyntheticFixtureOwnerApprovalError::WitnessHeaderBroken);
        }
        self.spec.validate()?;
        let rebuilt = Self::new()?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(SyntheticFixtureOwnerApprovalError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn synthetic_fixture_owner_approval_write_address(
    spec: &SyntheticFixtureOwnerApprovalWriteGate,
    metrics: &SyntheticFixtureOwnerApprovalMetrics,
) -> String {
    let payload = serde_json::json!({
        "id": SYNTHETIC_FIXTURE_OWNER_APPROVAL_WRITE_GATE_ID,
        "spec": spec,
        "metrics": metrics,
    });
    sha256_hex(payload.to_string().as_bytes())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:synthetic-fixture-owner-approval-write:error
// Plane: Verification.
// Residency: fail-closed owner-approval rejection taxonomy.
pub enum SyntheticFixtureOwnerApprovalError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    WrongValue(&'static str),
    UpstreamManifestPreflightBroken,
    ConsentContractBroken,
    WrongApprovalPhrase,
    ConsentClaimMismatch,
    WriteAuthorizationLeak,
    PathPolicyBroken,
    ProofPolicyBroken,
    ByteOrCommandLeak,
    MaterializationBoundaryBroken,
    PromotionClaim,
    WrongStatus,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for SyntheticFixtureOwnerApprovalError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingField(field) => write!(f, "missing field `{field}`"),
            Self::FieldHasSurroundingWhitespace(field) => {
                write!(f, "field `{field}` has surrounding whitespace")
            }
            Self::FieldContainsControlCharacter(field) => {
                write!(f, "field `{field}` contains a control character")
            }
            Self::WrongValue(field) => write!(f, "wrong value for `{field}`"),
            Self::UpstreamManifestPreflightBroken => {
                write!(f, "upstream manifest preflight broken")
            }
            Self::ConsentContractBroken => write!(f, "consent contract broken"),
            Self::WrongApprovalPhrase => write!(f, "wrong owner approval phrase"),
            Self::ConsentClaimMismatch => {
                write!(
                    f,
                    "owner_approval_present does not match the provided phrase"
                )
            }
            Self::WriteAuthorizationLeak => {
                write!(f, "consent gate must not authorize a write")
            }
            Self::PathPolicyBroken => write!(f, "path policy broken"),
            Self::ProofPolicyBroken => write!(f, "proof policy broken"),
            Self::ByteOrCommandLeak => write!(f, "byte or command leak"),
            Self::MaterializationBoundaryBroken => write!(f, "materialization boundary broken"),
            Self::PromotionClaim => write!(f, "promotion claim attempted"),
            Self::WrongStatus => write!(f, "wrong owner approval status"),
            Self::WitnessHeaderBroken => write!(f, "witness header broken"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for SyntheticFixtureOwnerApprovalError {}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), SyntheticFixtureOwnerApprovalError> {
    validate_token(field, value)?;
    if value != expected {
        return Err(SyntheticFixtureOwnerApprovalError::WrongValue(field));
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), SyntheticFixtureOwnerApprovalError> {
    if value.is_empty() {
        return Err(SyntheticFixtureOwnerApprovalError::MissingField(field));
    }
    if value.trim() != value {
        return Err(SyntheticFixtureOwnerApprovalError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(SyntheticFixtureOwnerApprovalError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_consent_gate_validates() {
        SyntheticFixtureOwnerApprovalWriteGate::canonical()
            .expect("consent gate")
            .validate()
            .expect("canonical validates");
    }

    #[test]
    fn witness_is_deterministic_and_consent_absent() {
        let first = SyntheticFixtureOwnerApprovalWriteWitness::new().expect("first");
        let second = SyntheticFixtureOwnerApprovalWriteWitness::new().expect("second");
        assert_eq!(first.address, second.address);
        assert!(!first.metrics.owner_approval_present);
        assert_eq!(first.metrics.consent_records_written, 0);
        assert_eq!(first.metrics.fixture_files_written, 0);
        assert_eq!(first.metrics.fixture_bytes_written, 0);
    }

    #[test]
    fn rejects_upstream_address_drift() {
        let mut gate = SyntheticFixtureOwnerApprovalWriteGate::canonical().expect("gate");
        gate.upstream_manifest_preflight_address =
            "sha256:0000000000000000000000000000000000000000000000000000000000000000".to_string();
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticFixtureOwnerApprovalError::WrongValue("upstream_manifest_preflight_address")
        );
    }

    #[test]
    fn rejects_wrong_provided_phrase() {
        let mut gate = SyntheticFixtureOwnerApprovalWriteGate::canonical().expect("gate");
        gate.provided_approval_phrase = "approve please".to_string();
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticFixtureOwnerApprovalError::WrongApprovalPhrase
        );
    }

    #[test]
    fn rejects_consent_claimed_without_phrase() {
        let mut gate = SyntheticFixtureOwnerApprovalWriteGate::canonical().expect("gate");
        gate.owner_approval_present = true; // claimed present while phrase is empty
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticFixtureOwnerApprovalError::ConsentClaimMismatch
        );
    }

    #[test]
    fn exact_phrase_implies_consent_but_no_write() {
        // With the exact phrase provided, consent is present and still validates
        // — but the gate still authorizes no write and leaks no bytes.
        let mut gate = SyntheticFixtureOwnerApprovalWriteGate::canonical().expect("gate");
        gate.provided_approval_phrase = APPROVAL_PHRASE.to_string();
        gate.owner_approval_present = true;
        gate.validate().expect("exact-phrase consent validates");
        assert!(!gate.write_authorized);
        assert_eq!(gate.fixture_bytes_written, 0);
    }

    #[test]
    fn rejects_write_authorization_leak() {
        let mut gate = SyntheticFixtureOwnerApprovalWriteGate::canonical().expect("gate");
        gate.write_authorized = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticFixtureOwnerApprovalError::WriteAuthorizationLeak
        );
    }

    #[test]
    fn rejects_path_policy_bypass() {
        let mut gate = SyntheticFixtureOwnerApprovalWriteGate::canonical().expect("gate");
        gate.symlink_follow_denied = false;
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticFixtureOwnerApprovalError::PathPolicyBroken
        );
    }

    #[test]
    fn rejects_proof_policy_bypass() {
        let mut gate = SyntheticFixtureOwnerApprovalWriteGate::canonical().expect("gate");
        gate.answer_packet_required = false;
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticFixtureOwnerApprovalError::ProofPolicyBroken
        );
    }

    #[test]
    fn rejects_byte_or_command_leak() {
        let mut gate = SyntheticFixtureOwnerApprovalWriteGate::canonical().expect("gate");
        gate.fixture_bytes_written = 1;
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticFixtureOwnerApprovalError::ByteOrCommandLeak
        );
    }

    #[test]
    fn rejects_materialization_enablement() {
        let mut gate = SyntheticFixtureOwnerApprovalWriteGate::canonical().expect("gate");
        gate.materialization_allowed = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticFixtureOwnerApprovalError::MaterializationBoundaryBroken
        );
    }

    #[test]
    fn rejects_promotion_claim() {
        let mut gate = SyntheticFixtureOwnerApprovalWriteGate::canonical().expect("gate");
        gate.live_dense_70b_claimed = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticFixtureOwnerApprovalError::PromotionClaim
        );
    }

    #[test]
    fn witness_validates_end_to_end() {
        SyntheticFixtureOwnerApprovalWriteWitness::new()
            .expect("witness")
            .validate()
            .expect("witness validates");
    }
}
