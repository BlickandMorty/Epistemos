//! Synthetic fixture staging manifest preflight gate.
//!
//! This metadata-only preflight consumes the JCS writer dry-run and binds the
//! manifest/path/digest/proof contract that must exist before fixture bytes.

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{
    JcsFixtureWriterFailClosedDryRunWitness, JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_CURSOR,
    JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_ID,
};
use serde::{Deserialize, Serialize};
use std::fmt;

pub const SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_ID: &str =
    "F-SyntheticFixtureStagingManifestPreflightGate";
pub const SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_CURSOR: &str =
    "synthetic_fixture_staging_manifest_preflight_gate";
pub const SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_NEXT_CURSOR: &str =
    "synthetic_fixture_owner_approval_write_gate";

const STAGING_ROOT: &str = "artifacts/falsifiers/synthetic_fixtures/staging/";
const FINAL_ROOT: &str = "artifacts/falsifiers/synthetic_fixtures/final/";
const APPROVAL_PHRASE: &str = "APPROVE_SYNTHETIC_FIXTURE_MATERIALIZATION_V0";
const ROLLBACK_REF: &str = "rollback:synthetic_fixture_staging_manifest_preflight_gate";
const RUN_EVENT_LOG_REF: &str = "run_event_log:synthetic_fixture_staging_manifest_preflight_gate";
const ANSWER_PACKET_REF: &str = "answer_packet:synthetic_fixture_staging_manifest_preflight_gate";
const GUARD_PRODUCT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
// UAS: uas:synthetic-fixture-staging-manifest:status
// Plane: Verification + Controller.
// Residency: metadata-only manifest preflight; no manifest file is written.
pub enum SyntheticFixtureStagingManifestStatus {
    ManifestPreflightBoundWritesStillBlocked,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-fixture-staging-manifest:field
// Plane: Verification.
// Residency: manifest field contract; no manifest file.
pub struct SyntheticFixtureStagingManifestField {
    pub name: String,
    pub required: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-fixture-staging-manifest:spec
// Plane: Verification + Controller.
// Residency: preflight-only manifest contract before owner-approved writes.
pub struct SyntheticFixtureStagingManifestPreflightGate {
    pub upstream_falsifier_id: String,
    pub upstream_cursor: String,
    pub upstream_writer_dry_run_address: String,
    pub staging_root: String,
    pub final_root: String,
    pub owner_approval_phrase: String,
    pub manifest_fields: Vec<SyntheticFixtureStagingManifestField>,
    pub manifest_field_digest: String,
    pub dry_run_fragments_consumed: bool,
    pub staging_manifest_file_claimed: bool,
    pub owner_approval_granted: bool,
    pub repo_relative_paths_required: bool,
    pub absolute_paths_denied: bool,
    pub parent_segments_denied: bool,
    pub hidden_segments_denied: bool,
    pub symlink_follow_denied: bool,
    pub hardlink_denied: bool,
    pub direct_final_write_denied: bool,
    pub cross_device_rename_denied: bool,
    pub preexisting_final_collision_denied: bool,
    pub jcs_canonical_digest_required: bool,
    pub sha256_required: bool,
    pub fragment_digest_required: bool,
    pub manifest_digest_required: bool,
    pub inventory_digest_required: bool,
    pub duplicate_path_rejection_required: bool,
    pub duplicate_digest_rejection_required: bool,
    pub rollback_receipt_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub privacy_scan_required: bool,
    pub provenance_scan_required: bool,
    pub benchmark_contamination_scan_required: bool,
    pub no_product_route_authority: bool,
    pub manifest_files_written: u64,
    pub staging_dirs_created: u64,
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
    pub status: SyntheticFixtureStagingManifestStatus,
}

impl SyntheticFixtureStagingManifestPreflightGate {
    pub fn canonical() -> Result<Self, SyntheticFixtureStagingManifestError> {
        let upstream = JcsFixtureWriterFailClosedDryRunWitness::new()
            .map_err(|_| SyntheticFixtureStagingManifestError::UpstreamDryRunBroken)?;
        upstream
            .validate()
            .map_err(|_| SyntheticFixtureStagingManifestError::UpstreamDryRunBroken)?;
        let manifest_fields = manifest_fields();
        Ok(Self {
            upstream_falsifier_id: JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_ID.to_string(),
            upstream_cursor: JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_CURSOR.to_string(),
            upstream_writer_dry_run_address: upstream.address,
            staging_root: STAGING_ROOT.to_string(),
            final_root: FINAL_ROOT.to_string(),
            owner_approval_phrase: APPROVAL_PHRASE.to_string(),
            manifest_field_digest: digest_json(&manifest_fields),
            manifest_fields,
            dry_run_fragments_consumed: true,
            staging_manifest_file_claimed: false,
            owner_approval_granted: false,
            repo_relative_paths_required: true,
            absolute_paths_denied: true,
            parent_segments_denied: true,
            hidden_segments_denied: true,
            symlink_follow_denied: true,
            hardlink_denied: true,
            direct_final_write_denied: true,
            cross_device_rename_denied: true,
            preexisting_final_collision_denied: true,
            jcs_canonical_digest_required: true,
            sha256_required: true,
            fragment_digest_required: true,
            manifest_digest_required: true,
            inventory_digest_required: true,
            duplicate_path_rejection_required: true,
            duplicate_digest_rejection_required: true,
            rollback_receipt_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            privacy_scan_required: true,
            provenance_scan_required: true,
            benchmark_contamination_scan_required: true,
            no_product_route_authority: true,
            manifest_files_written: 0,
            staging_dirs_created: 0,
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
            status: SyntheticFixtureStagingManifestStatus::ManifestPreflightBoundWritesStillBlocked,
        })
    }

    pub fn validate(&self) -> Result<(), SyntheticFixtureStagingManifestError> {
        let upstream = JcsFixtureWriterFailClosedDryRunWitness::new()
            .map_err(|_| SyntheticFixtureStagingManifestError::UpstreamDryRunBroken)?;
        upstream
            .validate()
            .map_err(|_| SyntheticFixtureStagingManifestError::UpstreamDryRunBroken)?;
        validate_exact(
            "upstream_falsifier_id",
            &self.upstream_falsifier_id,
            JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_ID,
        )?;
        validate_exact(
            "upstream_cursor",
            &self.upstream_cursor,
            JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_CURSOR,
        )?;
        validate_exact(
            "upstream_writer_dry_run_address",
            &self.upstream_writer_dry_run_address,
            &upstream.address,
        )?;
        validate_exact("staging_root", &self.staging_root, STAGING_ROOT)?;
        validate_exact("final_root", &self.final_root, FINAL_ROOT)?;
        validate_exact(
            "owner_approval_phrase",
            &self.owner_approval_phrase,
            APPROVAL_PHRASE,
        )?;
        validate_manifest_fields(&self.manifest_fields)?;
        validate_exact(
            "manifest_field_digest",
            &self.manifest_field_digest,
            &digest_json(&self.manifest_fields),
        )?;
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
            return Err(SyntheticFixtureStagingManifestError::MaterializationBoundaryBroken);
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
            return Err(SyntheticFixtureStagingManifestError::PromotionClaim);
        }
        if self.status
            != SyntheticFixtureStagingManifestStatus::ManifestPreflightBoundWritesStillBlocked
        {
            return Err(SyntheticFixtureStagingManifestError::WrongStatus);
        }
        Ok(())
    }

    fn validate_policy(&self) -> Result<(), SyntheticFixtureStagingManifestError> {
        if !self.dry_run_fragments_consumed
            || self.staging_manifest_file_claimed
            || self.owner_approval_granted
        {
            return Err(SyntheticFixtureStagingManifestError::SourceCardBroken);
        }
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
            return Err(SyntheticFixtureStagingManifestError::PathPolicyBroken);
        }
        if !self.jcs_canonical_digest_required
            || !self.sha256_required
            || !self.fragment_digest_required
            || !self.manifest_digest_required
            || !self.inventory_digest_required
            || !self.duplicate_path_rejection_required
            || !self.duplicate_digest_rejection_required
        {
            return Err(SyntheticFixtureStagingManifestError::DigestPolicyBroken);
        }
        if !self.rollback_receipt_required
            || !self.run_event_log_required
            || !self.answer_packet_required
            || !self.privacy_scan_required
            || !self.provenance_scan_required
            || !self.benchmark_contamination_scan_required
            || !self.no_product_route_authority
        {
            return Err(SyntheticFixtureStagingManifestError::ProofPolicyBroken);
        }
        Ok(())
    }

    fn validate_zero_ledger(&self) -> Result<(), SyntheticFixtureStagingManifestError> {
        if self.manifest_files_written != 0
            || self.staging_dirs_created != 0
            || self.staging_files_written != 0
            || self.final_files_written != 0
            || self.fixture_bytes_written != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.cache_index_bytes_opened != 0
            || self.filesystem_stat_calls != 0
            || self.commands_armed != 0
        {
            return Err(SyntheticFixtureStagingManifestError::ByteOrCommandLeak);
        }
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-fixture-staging-manifest:metrics
// Plane: Verification.
// Residency: metadata-only preflight counters.
pub struct SyntheticFixtureStagingManifestMetrics {
    pub manifest_field_count: u64,
    pub required_manifest_field_count: u64,
    pub policy_bit_count: u64,
    pub manifest_files_written: u64,
    pub fixture_files_written: u64,
    pub fixture_bytes_written: u64,
    pub runtime_model_provider_cache_index_bytes: u64,
    pub commands_armed: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-fixture-staging-manifest:witness
// Plane: Verification + Controller.
// Residency: L1/T1 manifest preflight; no manifest or fixture files.
pub struct SyntheticFixtureStagingManifestPreflightWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub spec: SyntheticFixtureStagingManifestPreflightGate,
    pub metrics: SyntheticFixtureStagingManifestMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub product_promotion_blocked: bool,
}

impl SyntheticFixtureStagingManifestPreflightWitness {
    pub fn new() -> Result<Self, SyntheticFixtureStagingManifestError> {
        let spec = SyntheticFixtureStagingManifestPreflightGate::canonical()?;
        spec.validate()?;
        let metrics = SyntheticFixtureStagingManifestMetrics {
            manifest_field_count: spec.manifest_fields.len() as u64,
            required_manifest_field_count: spec
                .manifest_fields
                .iter()
                .filter(|field| field.required)
                .count() as u64,
            policy_bit_count: 30,
            manifest_files_written: spec.manifest_files_written,
            fixture_files_written: spec.staging_files_written + spec.final_files_written,
            fixture_bytes_written: spec.fixture_bytes_written,
            runtime_model_provider_cache_index_bytes: spec.model_runtime_bytes_loaded
                + spec.provider_calls_made
                + spec.cache_index_bytes_opened,
            commands_armed: spec.commands_armed,
        };
        let address = synthetic_fixture_staging_manifest_preflight_address(&spec, &metrics);
        Ok(Self {
            falsifier_id: SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_ID.to_string(),
            cursor: SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_CURSOR.to_string(),
            next_cursor: SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_NEXT_CURSOR.to_string(),
            spec,
            metrics,
            address,
            metadata_only: true,
            product_promotion_blocked: true,
        })
    }

    pub fn validate(&self) -> Result<(), SyntheticFixtureStagingManifestError> {
        if self.falsifier_id != SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_ID
            || self.cursor != SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_CURSOR
            || self.next_cursor != SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_NEXT_CURSOR
            || !self.metadata_only
            || !self.product_promotion_blocked
        {
            return Err(SyntheticFixtureStagingManifestError::WitnessHeaderBroken);
        }
        self.spec.validate()?;
        let rebuilt = Self::new()?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(SyntheticFixtureStagingManifestError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn synthetic_fixture_staging_manifest_preflight_address(
    spec: &SyntheticFixtureStagingManifestPreflightGate,
    metrics: &SyntheticFixtureStagingManifestMetrics,
) -> String {
    let payload = serde_json::json!({
        "id": SYNTHETIC_FIXTURE_STAGING_MANIFEST_PREFLIGHT_GATE_ID,
        "spec": spec,
        "metrics": metrics,
    });
    sha256_hex(payload.to_string().as_bytes())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:synthetic-fixture-staging-manifest:error
// Plane: Verification.
// Residency: fail-closed staging manifest rejection taxonomy.
pub enum SyntheticFixtureStagingManifestError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    WrongValue(&'static str),
    UpstreamDryRunBroken,
    SourceCardBroken,
    PathPolicyBroken,
    DigestPolicyBroken,
    ProofPolicyBroken,
    ManifestFieldBroken,
    ByteOrCommandLeak,
    MaterializationBoundaryBroken,
    PromotionClaim,
    WrongStatus,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for SyntheticFixtureStagingManifestError {
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
            Self::UpstreamDryRunBroken => write!(f, "upstream writer dry-run broken"),
            Self::SourceCardBroken => write!(f, "source card broken"),
            Self::PathPolicyBroken => write!(f, "path policy broken"),
            Self::DigestPolicyBroken => write!(f, "digest policy broken"),
            Self::ProofPolicyBroken => write!(f, "proof policy broken"),
            Self::ManifestFieldBroken => write!(f, "manifest field contract broken"),
            Self::ByteOrCommandLeak => write!(f, "byte or command leak"),
            Self::MaterializationBoundaryBroken => write!(f, "materialization boundary broken"),
            Self::PromotionClaim => write!(f, "promotion claim attempted"),
            Self::WrongStatus => write!(f, "wrong staging manifest status"),
            Self::WitnessHeaderBroken => write!(f, "witness header broken"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for SyntheticFixtureStagingManifestError {}

fn manifest_fields() -> Vec<SyntheticFixtureStagingManifestField> {
    [
        "manifest_schema_version",
        "source_commit_sha",
        "upstream_writer_dry_run_address",
        "staging_root",
        "final_root",
        "planned_fragment_digest",
        "manifest_digest",
        "inventory_digest",
        "payload_rows",
        "privacy_scan_digest",
        "provenance_scan_digest",
        "benchmark_contamination_scan_digest",
        "rollback_receipt_digest",
        "run_event_log_ref",
        "answer_packet_ref",
        "owner_approval_phrase",
    ]
    .into_iter()
    .map(|name| SyntheticFixtureStagingManifestField {
        name: name.to_string(),
        required: true,
    })
    .collect()
}

fn validate_manifest_fields(
    fields: &[SyntheticFixtureStagingManifestField],
) -> Result<(), SyntheticFixtureStagingManifestError> {
    if fields != manifest_fields()
        || fields.len() != 16
        || fields.iter().filter(|field| field.required).count() != 16
    {
        return Err(SyntheticFixtureStagingManifestError::ManifestFieldBroken);
    }
    for field in fields {
        validate_token("manifest_field_name", &field.name)?;
    }
    Ok(())
}

fn digest_json<T: Serialize>(value: &T) -> String {
    sha256_hex(
        serde_json::to_string(value)
            .expect("manifest preflight digest serializes")
            .as_bytes(),
    )
}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), SyntheticFixtureStagingManifestError> {
    validate_token(field, value)?;
    if value != expected {
        return Err(SyntheticFixtureStagingManifestError::WrongValue(field));
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), SyntheticFixtureStagingManifestError> {
    if value.is_empty() {
        return Err(SyntheticFixtureStagingManifestError::MissingField(field));
    }
    if value.trim() != value {
        return Err(SyntheticFixtureStagingManifestError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(SyntheticFixtureStagingManifestError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_preflight_validates() {
        SyntheticFixtureStagingManifestPreflightGate::canonical()
            .expect("preflight")
            .validate()
            .expect("canonical validates");
    }

    #[test]
    fn witness_is_deterministic() {
        let first = SyntheticFixtureStagingManifestPreflightWitness::new().expect("first");
        let second = SyntheticFixtureStagingManifestPreflightWitness::new().expect("second");
        assert_eq!(first.address, second.address);
        assert_eq!(first.metrics.manifest_field_count, 16);
        assert_eq!(first.metrics.required_manifest_field_count, 16);
        assert_eq!(first.metrics.fixture_files_written, 0);
    }

    #[test]
    fn rejects_upstream_address_drift() {
        let mut preflight =
            SyntheticFixtureStagingManifestPreflightGate::canonical().expect("preflight");
        preflight.upstream_writer_dry_run_address =
            "sha256:0000000000000000000000000000000000000000000000000000000000000000".to_string();
        assert_eq!(
            preflight.validate().unwrap_err(),
            SyntheticFixtureStagingManifestError::WrongValue("upstream_writer_dry_run_address")
        );
    }

    #[test]
    fn rejects_manifest_file_claim() {
        let mut preflight =
            SyntheticFixtureStagingManifestPreflightGate::canonical().expect("preflight");
        preflight.staging_manifest_file_claimed = true;
        assert_eq!(
            preflight.validate().unwrap_err(),
            SyntheticFixtureStagingManifestError::SourceCardBroken
        );
    }

    #[test]
    fn rejects_path_policy_bypass() {
        let mut preflight =
            SyntheticFixtureStagingManifestPreflightGate::canonical().expect("preflight");
        preflight.parent_segments_denied = false;
        assert_eq!(
            preflight.validate().unwrap_err(),
            SyntheticFixtureStagingManifestError::PathPolicyBroken
        );
    }

    #[test]
    fn rejects_digest_policy_bypass() {
        let mut preflight =
            SyntheticFixtureStagingManifestPreflightGate::canonical().expect("preflight");
        preflight.manifest_digest_required = false;
        assert_eq!(
            preflight.validate().unwrap_err(),
            SyntheticFixtureStagingManifestError::DigestPolicyBroken
        );
    }

    #[test]
    fn rejects_proof_policy_bypass() {
        let mut preflight =
            SyntheticFixtureStagingManifestPreflightGate::canonical().expect("preflight");
        preflight.answer_packet_required = false;
        assert_eq!(
            preflight.validate().unwrap_err(),
            SyntheticFixtureStagingManifestError::ProofPolicyBroken
        );
    }

    #[test]
    fn rejects_manifest_field_drift() {
        let mut preflight =
            SyntheticFixtureStagingManifestPreflightGate::canonical().expect("preflight");
        preflight.manifest_fields[0].name = "schema_version".to_string();
        assert_eq!(
            preflight.validate().unwrap_err(),
            SyntheticFixtureStagingManifestError::ManifestFieldBroken
        );
    }

    #[test]
    fn rejects_manifest_digest_drift() {
        let mut preflight =
            SyntheticFixtureStagingManifestPreflightGate::canonical().expect("preflight");
        preflight.manifest_field_digest =
            "sha256:0000000000000000000000000000000000000000000000000000000000000000".to_string();
        assert_eq!(
            preflight.validate().unwrap_err(),
            SyntheticFixtureStagingManifestError::WrongValue("manifest_field_digest")
        );
    }

    #[test]
    fn rejects_byte_leak() {
        let mut preflight =
            SyntheticFixtureStagingManifestPreflightGate::canonical().expect("preflight");
        preflight.manifest_files_written = 1;
        assert_eq!(
            preflight.validate().unwrap_err(),
            SyntheticFixtureStagingManifestError::ByteOrCommandLeak
        );
    }

    #[test]
    fn rejects_materialization_enablement() {
        let mut preflight =
            SyntheticFixtureStagingManifestPreflightGate::canonical().expect("preflight");
        preflight.materialization_allowed = true;
        assert_eq!(
            preflight.validate().unwrap_err(),
            SyntheticFixtureStagingManifestError::MaterializationBoundaryBroken
        );
    }

    #[test]
    fn rejects_promotion_claim() {
        let mut preflight =
            SyntheticFixtureStagingManifestPreflightGate::canonical().expect("preflight");
        preflight.l2_claimed = true;
        assert_eq!(
            preflight.validate().unwrap_err(),
            SyntheticFixtureStagingManifestError::PromotionClaim
        );
    }
}
