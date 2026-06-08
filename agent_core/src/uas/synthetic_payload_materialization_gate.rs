//! Synthetic payload materialization gate.
//!
//! This metadata-only gate hardens the bridge between the synthetic
//! materializer blueprint and any future owner-approved fixture writes. The
//! canonical witness refuses materialization, writes zero fixture files, opens
//! zero runtime/model/provider/cache/index bytes, and preserves the product
//! runtime cursor.

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{
    SyntheticMaterializerPrimitiveBlueprintWitness, SYNTHETIC_MATERIALIZER_APPROVAL_PHRASE,
    SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_CURSOR,
    SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_ID,
};
use serde::{Deserialize, Serialize};
use std::fmt;

pub const SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_ID: &str =
    "F-SyntheticPayloadMaterializationGateV0";
pub const SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_CURSOR: &str =
    "synthetic_payload_materialization_gate_v0";
pub const SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_NEXT_CURSOR: &str =
    "jcs_canonical_json_writer_parity_gate";

const FIXTURE_ROOT: &str = "fixtures/minimal_synthetic_fixture_pack_v0/";
const STAGING_ROOT_PREFIX: &str = "fixtures/.staging/minimal_synthetic_fixture_pack_v0.";
const INVENTORY_DIGEST: &str =
    "sha256:0b9e2a4c8f0b66bc7f4f0245d2bd56c91fc0b783a9f9e04c7d6cb217c9e9f4a8";
const ROLLBACK_REF: &str = "rollback:synthetic_payload_materialization_gate_v0";
const RUN_EVENT_LOG_REF: &str = "run_event_log:synthetic_payload_materialization_gate_v0";
const ANSWER_PACKET_REF: &str = "answer_packet:synthetic_payload_materialization_gate_v0";
const GUARD_PRODUCT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
// UAS: uas:synthetic-payload-materialization-gate:status
// Plane: Controller + Verification.
// Residency: metadata-only refusal; future writes stay owner-approved.
pub enum SyntheticPayloadMaterializationStatus {
    ApprovalAbsentRefusal,
    BlockedUntilJcsParity,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-payload-materialization-gate:approval
// Plane: Controller.
// Residency: explicit owner approval is absent in this witness.
pub struct SyntheticPayloadGateApproval {
    pub approval_phrase: String,
    pub owner_approval_required: bool,
    pub owner_approval_present: bool,
    pub approval_scope: String,
    pub approved_write_roots: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-payload-materialization-gate:path-policy
// Plane: State + Verification.
// Residency: repo-relative staging policy only; final root writes denied.
pub struct SyntheticPayloadGatePathPolicy {
    pub fixture_root: String,
    pub staging_root_prefix: String,
    pub final_root_write_allowed: bool,
    pub direct_final_write_allowed: bool,
    pub absolute_paths_allowed: bool,
    pub parent_segments_allowed: bool,
    pub undeclared_hidden_segments_allowed: bool,
    pub symlinks_allowed: bool,
    pub hardlinks_allowed: bool,
    pub case_collision_denied: bool,
    pub cross_device_rename_allowed: bool,
    pub pre_existing_final_collision_denied: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-payload-materialization-gate:inventory
// Plane: Verification.
// Residency: exact planned inventory; zero fixture file creation.
pub struct SyntheticPayloadGateInventoryPlan {
    pub fixture_pack_id: String,
    pub planned_manifest_count: u64,
    pub planned_descriptor_count: u64,
    pub planned_payload_count: u64,
    pub planned_verifier_count: u64,
    pub planned_scorer_count: u64,
    pub planned_schema_count: u64,
    pub planned_policy_count: u64,
    pub planned_template_count: u64,
    pub planned_review_count: u64,
    pub exact_inventory_digest: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-payload-materialization-gate:validation-plan
// Plane: Verification.
// Residency: schema/JCS/privacy/provenance/rollback proof requirements.
pub struct SyntheticPayloadGateValidationPlan {
    pub json_schema_draft: String,
    pub closed_fields_required: bool,
    pub duplicate_key_rejection_required: bool,
    pub invalid_unicode_rejection_required: bool,
    pub nan_infinity_rejection_required: bool,
    pub jcs_canonical_digest_required: bool,
    pub privacy_scan_required: bool,
    pub provenance_scan_required: bool,
    pub benchmark_scan_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-payload-materialization-gate:byte-ledger
// Plane: Verification.
// Residency: refusal witness keeps all byte and command counters at zero.
pub struct SyntheticPayloadGateByteLedger {
    pub staging_dirs_created: u64,
    pub final_files_promoted: u64,
    pub payload_files_written: u64,
    pub fixture_bytes_written: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub cache_index_bytes_opened: u64,
    pub commands_armed: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-payload-materialization-gate:spec
// Plane: Controller + Verification.
// Residency: metadata-only materialization refusal tied to the blueprint.
pub struct SyntheticPayloadMaterializationGate {
    pub upstream_falsifier_id: String,
    pub upstream_cursor: String,
    pub upstream_blueprint_address: String,
    pub approval: SyntheticPayloadGateApproval,
    pub path_policy: SyntheticPayloadGatePathPolicy,
    pub inventory_plan: SyntheticPayloadGateInventoryPlan,
    pub validation_plan: SyntheticPayloadGateValidationPlan,
    pub byte_ledger: SyntheticPayloadGateByteLedger,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub guard_owned_product_cursor: String,
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
    pub status: SyntheticPayloadMaterializationStatus,
}

impl SyntheticPayloadMaterializationGate {
    pub fn canonical() -> Result<Self, SyntheticPayloadMaterializationGateError> {
        let upstream = SyntheticMaterializerPrimitiveBlueprintWitness::new()
            .map_err(|_| SyntheticPayloadMaterializationGateError::UpstreamBlueprintBroken)?;
        upstream
            .validate()
            .map_err(|_| SyntheticPayloadMaterializationGateError::UpstreamBlueprintBroken)?;
        Ok(Self {
            upstream_falsifier_id: SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_ID.to_string(),
            upstream_cursor: SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_CURSOR.to_string(),
            upstream_blueprint_address: upstream.address,
            approval: SyntheticPayloadGateApproval {
                approval_phrase: SYNTHETIC_MATERIALIZER_APPROVAL_PHRASE.to_string(),
                owner_approval_required: true,
                owner_approval_present: false,
                approval_scope: "metadata_refusal_only".to_string(),
                approved_write_roots: 0,
            },
            path_policy: SyntheticPayloadGatePathPolicy {
                fixture_root: FIXTURE_ROOT.to_string(),
                staging_root_prefix: STAGING_ROOT_PREFIX.to_string(),
                final_root_write_allowed: false,
                direct_final_write_allowed: false,
                absolute_paths_allowed: false,
                parent_segments_allowed: false,
                undeclared_hidden_segments_allowed: false,
                symlinks_allowed: false,
                hardlinks_allowed: false,
                case_collision_denied: true,
                cross_device_rename_allowed: false,
                pre_existing_final_collision_denied: true,
            },
            inventory_plan: SyntheticPayloadGateInventoryPlan {
                fixture_pack_id: "minimal_synthetic_fixture_pack_v0".to_string(),
                planned_manifest_count: 1,
                planned_descriptor_count: 6,
                planned_payload_count: 6,
                planned_verifier_count: 6,
                planned_scorer_count: 1,
                planned_schema_count: 1,
                planned_policy_count: 1,
                planned_template_count: 2,
                planned_review_count: 4,
                exact_inventory_digest: INVENTORY_DIGEST.to_string(),
            },
            validation_plan: SyntheticPayloadGateValidationPlan {
                json_schema_draft: "2020-12".to_string(),
                closed_fields_required: true,
                duplicate_key_rejection_required: true,
                invalid_unicode_rejection_required: true,
                nan_infinity_rejection_required: true,
                jcs_canonical_digest_required: true,
                privacy_scan_required: true,
                provenance_scan_required: true,
                benchmark_scan_required: true,
                rollback_required: true,
                run_event_log_required: true,
                answer_packet_required: true,
            },
            byte_ledger: SyntheticPayloadGateByteLedger {
                staging_dirs_created: 0,
                final_files_promoted: 0,
                payload_files_written: 0,
                fixture_bytes_written: 0,
                model_runtime_bytes_loaded: 0,
                provider_calls_made: 0,
                cache_index_bytes_opened: 0,
                commands_armed: 0,
            },
            rollback_ref: ROLLBACK_REF.to_string(),
            run_event_log_ref: RUN_EVENT_LOG_REF.to_string(),
            answer_packet_ref: ANSWER_PACKET_REF.to_string(),
            guard_owned_product_cursor: GUARD_PRODUCT_CURSOR.to_string(),
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
            status: SyntheticPayloadMaterializationStatus::ApprovalAbsentRefusal,
        })
    }

    pub fn validate(&self) -> Result<(), SyntheticPayloadMaterializationGateError> {
        let upstream = SyntheticMaterializerPrimitiveBlueprintWitness::new()
            .map_err(|_| SyntheticPayloadMaterializationGateError::UpstreamBlueprintBroken)?;
        upstream
            .validate()
            .map_err(|_| SyntheticPayloadMaterializationGateError::UpstreamBlueprintBroken)?;
        validate_exact(
            "upstream_falsifier_id",
            &self.upstream_falsifier_id,
            SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_ID,
        )?;
        validate_exact(
            "upstream_cursor",
            &self.upstream_cursor,
            SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_CURSOR,
        )?;
        validate_exact(
            "upstream_blueprint_address",
            &self.upstream_blueprint_address,
            &upstream.address,
        )?;
        self.approval.validate()?;
        self.path_policy.validate()?;
        self.inventory_plan.validate()?;
        self.validation_plan.validate()?;
        self.byte_ledger.validate()?;
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
        if !self.metadata_only {
            return Err(SyntheticPayloadMaterializationGateError::MetadataBoundaryBroken);
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
            return Err(SyntheticPayloadMaterializationGateError::PromotionClaim);
        }
        if self.status != SyntheticPayloadMaterializationStatus::ApprovalAbsentRefusal {
            return Err(SyntheticPayloadMaterializationGateError::WrongStatus);
        }
        Ok(())
    }
}

impl SyntheticPayloadGateApproval {
    pub fn validate(&self) -> Result<(), SyntheticPayloadMaterializationGateError> {
        validate_exact(
            "approval_phrase",
            &self.approval_phrase,
            SYNTHETIC_MATERIALIZER_APPROVAL_PHRASE,
        )?;
        validate_exact(
            "approval_scope",
            &self.approval_scope,
            "metadata_refusal_only",
        )?;
        if !self.owner_approval_required
            || self.owner_approval_present
            || self.approved_write_roots != 0
        {
            return Err(SyntheticPayloadMaterializationGateError::ApprovalBoundaryBroken);
        }
        Ok(())
    }
}

impl SyntheticPayloadGatePathPolicy {
    pub fn validate(&self) -> Result<(), SyntheticPayloadMaterializationGateError> {
        validate_exact("fixture_root", &self.fixture_root, FIXTURE_ROOT)?;
        validate_exact(
            "staging_root_prefix",
            &self.staging_root_prefix,
            STAGING_ROOT_PREFIX,
        )?;
        if self.fixture_root.starts_with('/')
            || self.staging_root_prefix.starts_with('/')
            || self.fixture_root.contains("..")
            || self.staging_root_prefix.contains("..")
            || self.fixture_root.contains("//")
            || self.staging_root_prefix.contains("//")
        {
            return Err(SyntheticPayloadMaterializationGateError::PathPolicyBroken);
        }
        if self.final_root_write_allowed
            || self.direct_final_write_allowed
            || self.absolute_paths_allowed
            || self.parent_segments_allowed
            || self.undeclared_hidden_segments_allowed
            || self.symlinks_allowed
            || self.hardlinks_allowed
            || !self.case_collision_denied
            || self.cross_device_rename_allowed
            || !self.pre_existing_final_collision_denied
        {
            return Err(SyntheticPayloadMaterializationGateError::PathPolicyBroken);
        }
        Ok(())
    }
}

impl SyntheticPayloadGateInventoryPlan {
    pub fn validate(&self) -> Result<(), SyntheticPayloadMaterializationGateError> {
        validate_exact(
            "fixture_pack_id",
            &self.fixture_pack_id,
            "minimal_synthetic_fixture_pack_v0",
        )?;
        if self.planned_manifest_count != 1
            || self.planned_descriptor_count != 6
            || self.planned_payload_count != 6
            || self.planned_verifier_count != 6
            || self.planned_scorer_count != 1
            || self.planned_schema_count != 1
            || self.planned_policy_count != 1
            || self.planned_template_count != 2
            || self.planned_review_count != 4
        {
            return Err(SyntheticPayloadMaterializationGateError::InventoryPlanBroken);
        }
        validate_sha256("exact_inventory_digest", &self.exact_inventory_digest)?;
        validate_exact(
            "exact_inventory_digest",
            &self.exact_inventory_digest,
            INVENTORY_DIGEST,
        )?;
        Ok(())
    }
}

impl SyntheticPayloadGateValidationPlan {
    pub fn validate(&self) -> Result<(), SyntheticPayloadMaterializationGateError> {
        validate_exact("json_schema_draft", &self.json_schema_draft, "2020-12")?;
        if !self.closed_fields_required
            || !self.duplicate_key_rejection_required
            || !self.invalid_unicode_rejection_required
            || !self.nan_infinity_rejection_required
            || !self.jcs_canonical_digest_required
            || !self.privacy_scan_required
            || !self.provenance_scan_required
            || !self.benchmark_scan_required
            || !self.rollback_required
            || !self.run_event_log_required
            || !self.answer_packet_required
        {
            return Err(SyntheticPayloadMaterializationGateError::ValidationPlanBroken);
        }
        Ok(())
    }
}

impl SyntheticPayloadGateByteLedger {
    pub fn validate(&self) -> Result<(), SyntheticPayloadMaterializationGateError> {
        if self.staging_dirs_created != 0
            || self.final_files_promoted != 0
            || self.payload_files_written != 0
            || self.fixture_bytes_written != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.cache_index_bytes_opened != 0
            || self.commands_armed != 0
        {
            return Err(SyntheticPayloadMaterializationGateError::ByteOrCommandLeak);
        }
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-payload-materialization-gate:metrics
// Plane: Verification.
// Residency: materialization refusal counters.
pub struct SyntheticPayloadGateMetrics {
    pub planned_payload_count: u64,
    pub planned_descriptor_count: u64,
    pub planned_verifier_count: u64,
    pub planned_review_count: u64,
    pub staging_dirs_created: u64,
    pub final_files_promoted: u64,
    pub payload_files_written: u64,
    pub fixture_bytes_written: u64,
    pub runtime_model_provider_cache_index_bytes: u64,
    pub commands_armed: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-payload-materialization-gate:witness
// Plane: Verification + Controller.
// Residency: T1/L1 metadata-only side-ladder; no product route influence.
pub struct SyntheticPayloadMaterializationGateWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub spec: SyntheticPayloadMaterializationGate,
    pub metrics: SyntheticPayloadGateMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub product_promotion_blocked: bool,
}

impl SyntheticPayloadMaterializationGateWitness {
    pub fn new() -> Result<Self, SyntheticPayloadMaterializationGateError> {
        let spec = SyntheticPayloadMaterializationGate::canonical()?;
        spec.validate()?;
        let metrics = SyntheticPayloadGateMetrics {
            planned_payload_count: spec.inventory_plan.planned_payload_count,
            planned_descriptor_count: spec.inventory_plan.planned_descriptor_count,
            planned_verifier_count: spec.inventory_plan.planned_verifier_count,
            planned_review_count: spec.inventory_plan.planned_review_count,
            staging_dirs_created: spec.byte_ledger.staging_dirs_created,
            final_files_promoted: spec.byte_ledger.final_files_promoted,
            payload_files_written: spec.byte_ledger.payload_files_written,
            fixture_bytes_written: spec.byte_ledger.fixture_bytes_written,
            runtime_model_provider_cache_index_bytes: spec.byte_ledger.model_runtime_bytes_loaded
                + spec.byte_ledger.provider_calls_made
                + spec.byte_ledger.cache_index_bytes_opened,
            commands_armed: spec.byte_ledger.commands_armed,
        };
        let address = synthetic_payload_materialization_gate_address(&spec, &metrics);
        Ok(Self {
            falsifier_id: SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_ID.to_string(),
            cursor: SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_CURSOR.to_string(),
            next_cursor: SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_NEXT_CURSOR.to_string(),
            spec,
            metrics,
            address,
            metadata_only: true,
            product_promotion_blocked: true,
        })
    }

    pub fn validate(&self) -> Result<(), SyntheticPayloadMaterializationGateError> {
        if self.falsifier_id != SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_ID
            || self.cursor != SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_CURSOR
            || self.next_cursor != SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_NEXT_CURSOR
            || !self.metadata_only
            || !self.product_promotion_blocked
        {
            return Err(SyntheticPayloadMaterializationGateError::WitnessHeaderBroken);
        }
        self.spec.validate()?;
        let rebuilt = Self::new()?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(SyntheticPayloadMaterializationGateError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn synthetic_payload_materialization_gate_address(
    spec: &SyntheticPayloadMaterializationGate,
    metrics: &SyntheticPayloadGateMetrics,
) -> String {
    let payload = serde_json::json!({
        "id": SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_ID,
        "spec": spec,
        "metrics": metrics,
    });
    sha256_hex(payload.to_string().as_bytes())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:synthetic-payload-materialization-gate:error
// Plane: Verification.
// Residency: fail-closed materialization rejection taxonomy.
pub enum SyntheticPayloadMaterializationGateError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    WrongValue(&'static str),
    InvalidSha256(&'static str),
    UpstreamBlueprintBroken,
    ApprovalBoundaryBroken,
    MetadataBoundaryBroken,
    PromotionClaim,
    PathPolicyBroken,
    InventoryPlanBroken,
    ValidationPlanBroken,
    ByteOrCommandLeak,
    WrongStatus,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for SyntheticPayloadMaterializationGateError {
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
            Self::InvalidSha256(field) => write!(f, "invalid sha256 digest `{field}`"),
            Self::UpstreamBlueprintBroken => write!(f, "upstream blueprint broken"),
            Self::ApprovalBoundaryBroken => write!(f, "approval boundary broken"),
            Self::MetadataBoundaryBroken => write!(f, "metadata boundary broken"),
            Self::PromotionClaim => write!(f, "promotion claim attempted"),
            Self::PathPolicyBroken => write!(f, "path policy broken"),
            Self::InventoryPlanBroken => write!(f, "inventory plan broken"),
            Self::ValidationPlanBroken => write!(f, "validation plan broken"),
            Self::ByteOrCommandLeak => write!(f, "byte or command leak"),
            Self::WrongStatus => write!(f, "wrong materialization status"),
            Self::WitnessHeaderBroken => write!(f, "witness header broken"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for SyntheticPayloadMaterializationGateError {}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), SyntheticPayloadMaterializationGateError> {
    validate_token(field, value)?;
    if value != expected {
        return Err(SyntheticPayloadMaterializationGateError::WrongValue(field));
    }
    Ok(())
}

fn validate_sha256(
    field: &'static str,
    value: &str,
) -> Result<(), SyntheticPayloadMaterializationGateError> {
    validate_token(field, value)?;
    if !value.starts_with("sha256:")
        || value.len() != 71
        || !value["sha256:".len()..]
            .chars()
            .all(|char| char.is_ascii_hexdigit())
    {
        return Err(SyntheticPayloadMaterializationGateError::InvalidSha256(
            field,
        ));
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), SyntheticPayloadMaterializationGateError> {
    if value.is_empty() {
        return Err(SyntheticPayloadMaterializationGateError::MissingField(
            field,
        ));
    }
    if value.trim() != value {
        return Err(SyntheticPayloadMaterializationGateError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(SyntheticPayloadMaterializationGateError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_gate_validates() {
        SyntheticPayloadMaterializationGate::canonical()
            .expect("gate")
            .validate()
            .expect("canonical gate validates");
    }

    #[test]
    fn witness_is_deterministic() {
        let first = SyntheticPayloadMaterializationGateWitness::new().expect("first");
        let second = SyntheticPayloadMaterializationGateWitness::new().expect("second");
        assert_eq!(first.address, second.address);
        assert_eq!(first.metrics.planned_payload_count, 6);
        assert_eq!(first.metrics.payload_files_written, 0);
    }

    #[test]
    fn rejects_upstream_address_drift() {
        let mut gate = SyntheticPayloadMaterializationGate::canonical().expect("gate");
        gate.upstream_blueprint_address =
            "sha256:0000000000000000000000000000000000000000000000000000000000000000".to_string();
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticPayloadMaterializationGateError::WrongValue("upstream_blueprint_address")
        );
    }

    #[test]
    fn rejects_approval_smuggling() {
        let mut gate = SyntheticPayloadMaterializationGate::canonical().expect("gate");
        gate.approval.owner_approval_present = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticPayloadMaterializationGateError::ApprovalBoundaryBroken
        );
    }

    #[test]
    fn rejects_wrong_approval_phrase() {
        let mut gate = SyntheticPayloadMaterializationGate::canonical().expect("gate");
        gate.approval.approval_phrase = "APPROVE".to_string();
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticPayloadMaterializationGateError::WrongValue("approval_phrase")
        );
    }

    #[test]
    fn rejects_bad_path_policy() {
        let mut gate = SyntheticPayloadMaterializationGate::canonical().expect("gate");
        gate.path_policy.fixture_root = "/tmp/fixtures".to_string();
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticPayloadMaterializationGateError::WrongValue("fixture_root")
        );

        let mut symlink = SyntheticPayloadMaterializationGate::canonical().expect("gate");
        symlink.path_policy.symlinks_allowed = true;
        assert_eq!(
            symlink.validate().unwrap_err(),
            SyntheticPayloadMaterializationGateError::PathPolicyBroken
        );
    }

    #[test]
    fn rejects_inventory_drift() {
        let mut gate = SyntheticPayloadMaterializationGate::canonical().expect("gate");
        gate.inventory_plan.planned_payload_count = 7;
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticPayloadMaterializationGateError::InventoryPlanBroken
        );
    }

    #[test]
    fn rejects_validation_bypass() {
        let mut gate = SyntheticPayloadMaterializationGate::canonical().expect("gate");
        gate.validation_plan.jcs_canonical_digest_required = false;
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticPayloadMaterializationGateError::ValidationPlanBroken
        );
    }

    #[test]
    fn rejects_byte_or_command_leak() {
        let mut gate = SyntheticPayloadMaterializationGate::canonical().expect("gate");
        gate.byte_ledger.payload_files_written = 1;
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticPayloadMaterializationGateError::ByteOrCommandLeak
        );
    }

    #[test]
    fn rejects_promotion_claims() {
        let mut gate = SyntheticPayloadMaterializationGate::canonical().expect("gate");
        gate.l2_claimed = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticPayloadMaterializationGateError::PromotionClaim
        );
    }

    #[test]
    fn rejects_wrong_status() {
        let mut gate = SyntheticPayloadMaterializationGate::canonical().expect("gate");
        gate.status = SyntheticPayloadMaterializationStatus::BlockedUntilJcsParity;
        assert_eq!(
            gate.validate().unwrap_err(),
            SyntheticPayloadMaterializationGateError::WrongStatus
        );
    }
}
