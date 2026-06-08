//! Synthetic materializer primitive blueprint.
//!
//! This primitive is the first metadata-only Rust witness for the synthetic
//! fixture materializer. It proves the future materializer contract is
//! fail-closed before any fixture bytes are written.

use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::fmt;

pub const SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_ID: &str =
    "F-SyntheticMaterializerPrimitiveBlueprintV0";
pub const SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_CURSOR: &str =
    "synthetic_materializer_primitive_blueprint";
pub const SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_NEXT_CURSOR: &str =
    "synthetic_payload_materialization_gate_v0";
pub const SYNTHETIC_MATERIALIZER_APPROVAL_PHRASE: &str =
    "APPROVE_SYNTHETIC_FIXTURE_MATERIALIZATION_V0";

const FIXTURE_ROOT: &str = "fixtures/minimal_synthetic_fixture_pack_v0/";
const STAGING_ROOT: &str = "fixtures/.staging/minimal_synthetic_fixture_pack_v0.";
const INVENTORY_DIGEST: &str =
    "sha256:0b9e2a4c8f0b66bc7f4f0245d2bd56c91fc0b783a9f9e04c7d6cb217c9e9f4a8";
const ROLLBACK_REF: &str = "rollback:synthetic_materializer_primitive_blueprint";
const RUN_EVENT_LOG_REF: &str = "run_event_log:synthetic_materializer_primitive_blueprint";
const ANSWER_PACKET_REF: &str = "answer_packet:synthetic_materializer_primitive_blueprint";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
// UAS: uas:synthetic-materializer-primitive-blueprint:status
// Plane: Verification + Controller.
// Residency: blueprint-only; fixture materialization remains unapproved.
pub enum SyntheticMaterializerStatus {
    BlueprintOnly,
    BlockedUntilOwnerApproval,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-materializer-primitive-blueprint:path-policy
// Plane: State + Verification.
// Residency: planned repo-relative paths only; no filesystem writes.
pub struct SyntheticMaterializerPathPolicy {
    pub fixture_root: String,
    pub staging_root_prefix: String,
    pub final_root_write_allowed: bool,
    pub absolute_paths_allowed: bool,
    pub parent_segments_allowed: bool,
    pub hidden_segments_allowed: bool,
    pub symlinks_allowed: bool,
    pub hardlinks_allowed: bool,
    pub case_collision_denied: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-materializer-primitive-blueprint:inventory-plan
// Plane: Verification.
// Residency: exact planned fixture inventory; no file creation.
pub struct SyntheticMaterializerInventoryPlan {
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
// UAS: uas:synthetic-materializer-primitive-blueprint:byte-ledger
// Plane: Verification.
// Residency: zero-byte ledger for the first metadata-only witness.
pub struct SyntheticMaterializerByteLedger {
    pub payload_files_written: u64,
    pub fixture_bytes_written: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub cache_index_bytes_opened: u64,
    pub commands_armed: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-materializer-primitive-blueprint:spec
// Plane: Controller + Verification.
// Residency: metadata-only materializer blueprint; no materialization approval.
pub struct SyntheticMaterializerPrimitiveBlueprint {
    pub approval_phrase: String,
    pub owner_approval_required: bool,
    pub owner_approval_present: bool,
    pub schema_validation_required: bool,
    pub canonical_digest_required: bool,
    pub privacy_scan_required: bool,
    pub provenance_scan_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub promotion_boundary: String,
    pub l1_claimed: bool,
    pub l2_claimed: bool,
    pub l3_claimed: bool,
    pub t4_t5_claimed: bool,
    pub product_green_claimed: bool,
    pub release_ready_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub path_policy: SyntheticMaterializerPathPolicy,
    pub inventory_plan: SyntheticMaterializerInventoryPlan,
    pub byte_ledger: SyntheticMaterializerByteLedger,
    pub status: SyntheticMaterializerStatus,
}

impl SyntheticMaterializerPrimitiveBlueprint {
    pub fn canonical() -> Self {
        Self {
            approval_phrase: SYNTHETIC_MATERIALIZER_APPROVAL_PHRASE.to_string(),
            owner_approval_required: true,
            owner_approval_present: false,
            schema_validation_required: true,
            canonical_digest_required: true,
            privacy_scan_required: true,
            provenance_scan_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            promotion_boundary: "T0_only".to_string(),
            l1_claimed: false,
            l2_claimed: false,
            l3_claimed: false,
            t4_t5_claimed: false,
            product_green_claimed: false,
            release_ready_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            rollback_ref: ROLLBACK_REF.to_string(),
            run_event_log_ref: RUN_EVENT_LOG_REF.to_string(),
            answer_packet_ref: ANSWER_PACKET_REF.to_string(),
            path_policy: SyntheticMaterializerPathPolicy {
                fixture_root: FIXTURE_ROOT.to_string(),
                staging_root_prefix: STAGING_ROOT.to_string(),
                final_root_write_allowed: false,
                absolute_paths_allowed: false,
                parent_segments_allowed: false,
                hidden_segments_allowed: false,
                symlinks_allowed: false,
                hardlinks_allowed: false,
                case_collision_denied: true,
            },
            inventory_plan: SyntheticMaterializerInventoryPlan {
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
            byte_ledger: SyntheticMaterializerByteLedger {
                payload_files_written: 0,
                fixture_bytes_written: 0,
                model_runtime_bytes_loaded: 0,
                provider_calls_made: 0,
                cache_index_bytes_opened: 0,
                commands_armed: 0,
            },
            status: SyntheticMaterializerStatus::BlueprintOnly,
        }
    }

    pub fn validate(&self) -> Result<(), SyntheticMaterializerBlueprintError> {
        validate_exact(
            "approval_phrase",
            &self.approval_phrase,
            SYNTHETIC_MATERIALIZER_APPROVAL_PHRASE,
        )?;
        if !self.owner_approval_required
            || self.owner_approval_present
            || !self.schema_validation_required
            || !self.canonical_digest_required
            || !self.privacy_scan_required
            || !self.provenance_scan_required
            || !self.rollback_required
            || !self.run_event_log_required
            || !self.answer_packet_required
        {
            return Err(SyntheticMaterializerBlueprintError::ApprovalOrProofBoundaryBroken);
        }
        if self.promotion_boundary != "T0_only"
            || self.l1_claimed
            || self.l2_claimed
            || self.l3_claimed
            || self.t4_t5_claimed
            || self.product_green_claimed
            || self.release_ready_claimed
            || self.live_dense_70b_claimed
            || self.ssd_as_ram_claimed
        {
            return Err(SyntheticMaterializerBlueprintError::PromotionClaim);
        }
        self.path_policy.validate()?;
        self.inventory_plan.validate()?;
        self.byte_ledger.validate()?;
        validate_exact("rollback_ref", &self.rollback_ref, ROLLBACK_REF)?;
        validate_exact("run_event_log_ref", &self.run_event_log_ref, RUN_EVENT_LOG_REF)?;
        validate_exact("answer_packet_ref", &self.answer_packet_ref, ANSWER_PACKET_REF)?;
        if self.status != SyntheticMaterializerStatus::BlueprintOnly {
            return Err(SyntheticMaterializerBlueprintError::WrongStatus);
        }
        Ok(())
    }
}

impl SyntheticMaterializerPathPolicy {
    pub fn validate(&self) -> Result<(), SyntheticMaterializerBlueprintError> {
        validate_exact("fixture_root", &self.fixture_root, FIXTURE_ROOT)?;
        validate_exact("staging_root_prefix", &self.staging_root_prefix, STAGING_ROOT)?;
        if self.fixture_root.starts_with('/')
            || self.staging_root_prefix.starts_with('/')
            || self.fixture_root.contains("..")
            || self.staging_root_prefix.contains("..")
            || self.fixture_root.contains("//")
            || self.staging_root_prefix.contains("//")
        {
            return Err(SyntheticMaterializerBlueprintError::PathPolicyBroken);
        }
        if self.final_root_write_allowed
            || self.absolute_paths_allowed
            || self.parent_segments_allowed
            || self.hidden_segments_allowed
            || self.symlinks_allowed
            || self.hardlinks_allowed
            || !self.case_collision_denied
        {
            return Err(SyntheticMaterializerBlueprintError::PathPolicyBroken);
        }
        Ok(())
    }
}

impl SyntheticMaterializerInventoryPlan {
    pub fn validate(&self) -> Result<(), SyntheticMaterializerBlueprintError> {
        if self.planned_descriptor_count != 6
            || self.planned_payload_count != 6
            || self.planned_verifier_count != 6
            || self.planned_scorer_count != 1
            || self.planned_schema_count == 0
            || self.planned_policy_count == 0
            || self.planned_template_count == 0
            || self.planned_review_count == 0
        {
            return Err(SyntheticMaterializerBlueprintError::InventoryPlanBroken);
        }
        validate_sha256("exact_inventory_digest", &self.exact_inventory_digest)?;
        Ok(())
    }
}

impl SyntheticMaterializerByteLedger {
    pub fn validate(&self) -> Result<(), SyntheticMaterializerBlueprintError> {
        if self.payload_files_written != 0
            || self.fixture_bytes_written != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.cache_index_bytes_opened != 0
            || self.commands_armed != 0
        {
            return Err(SyntheticMaterializerBlueprintError::ByteOrCommandLeak);
        }
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-materializer-primitive-blueprint:metrics
// Plane: Verification.
// Residency: metadata-only counters for the blueprint witness.
pub struct SyntheticMaterializerBlueprintMetrics {
    pub planned_payload_count: u64,
    pub planned_descriptor_count: u64,
    pub planned_verifier_count: u64,
    pub planned_review_count: u64,
    pub payload_files_written: u64,
    pub fixture_bytes_written: u64,
    pub runtime_model_provider_cache_index_bytes: u64,
    pub commands_armed: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:synthetic-materializer-primitive-blueprint:witness
// Plane: Verification + Controller.
// Residency: T1/L1 metadata-only side-ladder; no product route influence.
pub struct SyntheticMaterializerPrimitiveBlueprintWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub spec: SyntheticMaterializerPrimitiveBlueprint,
    pub metrics: SyntheticMaterializerBlueprintMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub product_promotion_blocked: bool,
}

impl SyntheticMaterializerPrimitiveBlueprintWitness {
    pub fn new() -> Result<Self, SyntheticMaterializerBlueprintError> {
        let spec = SyntheticMaterializerPrimitiveBlueprint::canonical();
        spec.validate()?;
        let metrics = SyntheticMaterializerBlueprintMetrics {
            planned_payload_count: spec.inventory_plan.planned_payload_count,
            planned_descriptor_count: spec.inventory_plan.planned_descriptor_count,
            planned_verifier_count: spec.inventory_plan.planned_verifier_count,
            planned_review_count: spec.inventory_plan.planned_review_count,
            payload_files_written: spec.byte_ledger.payload_files_written,
            fixture_bytes_written: spec.byte_ledger.fixture_bytes_written,
            runtime_model_provider_cache_index_bytes: spec.byte_ledger.model_runtime_bytes_loaded
                + spec.byte_ledger.provider_calls_made
                + spec.byte_ledger.cache_index_bytes_opened,
            commands_armed: spec.byte_ledger.commands_armed,
        };
        let address = synthetic_materializer_blueprint_address(&spec, &metrics);
        Ok(Self {
            falsifier_id: SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_ID.to_string(),
            cursor: SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_CURSOR.to_string(),
            next_cursor: SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_NEXT_CURSOR.to_string(),
            spec,
            metrics,
            address,
            metadata_only: true,
            product_promotion_blocked: true,
        })
    }

    pub fn validate(&self) -> Result<(), SyntheticMaterializerBlueprintError> {
        if self.falsifier_id != SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_ID
            || self.cursor != SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_CURSOR
            || self.next_cursor != SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_NEXT_CURSOR
            || !self.metadata_only
            || !self.product_promotion_blocked
        {
            return Err(SyntheticMaterializerBlueprintError::WitnessHeaderBroken);
        }
        self.spec.validate()?;
        let rebuilt = Self::new()?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(SyntheticMaterializerBlueprintError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn synthetic_materializer_blueprint_address(
    spec: &SyntheticMaterializerPrimitiveBlueprint,
    metrics: &SyntheticMaterializerBlueprintMetrics,
) -> String {
    let payload = serde_json::json!({
        "id": SYNTHETIC_MATERIALIZER_PRIMITIVE_BLUEPRINT_ID,
        "spec": spec,
        "metrics": metrics,
    });
    sha256_hex(payload.to_string().as_bytes())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:synthetic-materializer-primitive-blueprint:error
// Plane: Verification.
// Residency: fail-closed blueprint rejection taxonomy.
pub enum SyntheticMaterializerBlueprintError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    WrongValue(&'static str),
    InvalidSha256(&'static str),
    ApprovalOrProofBoundaryBroken,
    PromotionClaim,
    PathPolicyBroken,
    InventoryPlanBroken,
    ByteOrCommandLeak,
    WrongStatus,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for SyntheticMaterializerBlueprintError {
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
            Self::ApprovalOrProofBoundaryBroken => {
                write!(f, "approval or proof boundary broken")
            }
            Self::PromotionClaim => write!(f, "promotion claim attempted"),
            Self::PathPolicyBroken => write!(f, "path policy broken"),
            Self::InventoryPlanBroken => write!(f, "inventory plan broken"),
            Self::ByteOrCommandLeak => write!(f, "byte or command leak"),
            Self::WrongStatus => write!(f, "wrong materializer status"),
            Self::WitnessHeaderBroken => write!(f, "witness header broken"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for SyntheticMaterializerBlueprintError {}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), SyntheticMaterializerBlueprintError> {
    validate_token(field, value)?;
    if value != expected {
        return Err(SyntheticMaterializerBlueprintError::WrongValue(field));
    }
    Ok(())
}

fn validate_sha256(
    field: &'static str,
    value: &str,
) -> Result<(), SyntheticMaterializerBlueprintError> {
    validate_token(field, value)?;
    if !value.starts_with("sha256:")
        || value.len() != 71
        || !value["sha256:".len()..]
            .chars()
            .all(|char| char.is_ascii_hexdigit())
    {
        return Err(SyntheticMaterializerBlueprintError::InvalidSha256(field));
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), SyntheticMaterializerBlueprintError> {
    if value.is_empty() {
        return Err(SyntheticMaterializerBlueprintError::MissingField(field));
    }
    if value.trim() != value {
        return Err(SyntheticMaterializerBlueprintError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(SyntheticMaterializerBlueprintError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_blueprint_validates() {
        SyntheticMaterializerPrimitiveBlueprint::canonical()
            .validate()
            .expect("canonical blueprint validates");
    }

    #[test]
    fn witness_is_deterministic() {
        let first = SyntheticMaterializerPrimitiveBlueprintWitness::new().expect("witness");
        let second = SyntheticMaterializerPrimitiveBlueprintWitness::new().expect("witness");
        assert_eq!(first.address, second.address);
        assert_eq!(first.metrics.planned_payload_count, 6);
        assert_eq!(first.metrics.payload_files_written, 0);
    }

    #[test]
    fn rejects_approval_smuggling() {
        let mut spec = SyntheticMaterializerPrimitiveBlueprint::canonical();
        spec.owner_approval_present = true;
        assert_eq!(
            spec.validate().unwrap_err(),
            SyntheticMaterializerBlueprintError::ApprovalOrProofBoundaryBroken
        );
    }

    #[test]
    fn rejects_wrong_approval_phrase() {
        let mut spec = SyntheticMaterializerPrimitiveBlueprint::canonical();
        spec.approval_phrase = "APPROVE".to_string();
        assert_eq!(
            spec.validate().unwrap_err(),
            SyntheticMaterializerBlueprintError::WrongValue("approval_phrase")
        );
    }

    #[test]
    fn rejects_bad_path_policies() {
        let mut spec = SyntheticMaterializerPrimitiveBlueprint::canonical();
        spec.path_policy.fixture_root = "/tmp/fixtures".to_string();
        assert_eq!(
            spec.validate().unwrap_err(),
            SyntheticMaterializerBlueprintError::WrongValue("fixture_root")
        );

        let mut symlink = SyntheticMaterializerPrimitiveBlueprint::canonical();
        symlink.path_policy.symlinks_allowed = true;
        assert_eq!(
            symlink.validate().unwrap_err(),
            SyntheticMaterializerBlueprintError::PathPolicyBroken
        );
    }

    #[test]
    fn rejects_inventory_drift() {
        let mut spec = SyntheticMaterializerPrimitiveBlueprint::canonical();
        spec.inventory_plan.planned_payload_count = 5;
        assert_eq!(
            spec.validate().unwrap_err(),
            SyntheticMaterializerBlueprintError::InventoryPlanBroken
        );
    }

    #[test]
    fn rejects_invalid_digest() {
        let mut spec = SyntheticMaterializerPrimitiveBlueprint::canonical();
        spec.inventory_plan.exact_inventory_digest = "sha256:not-canonical".to_string();
        assert_eq!(
            spec.validate().unwrap_err(),
            SyntheticMaterializerBlueprintError::InvalidSha256("exact_inventory_digest")
        );
    }

    #[test]
    fn rejects_disabled_proof_surfaces() {
        let mut spec = SyntheticMaterializerPrimitiveBlueprint::canonical();
        spec.canonical_digest_required = false;
        assert_eq!(
            spec.validate().unwrap_err(),
            SyntheticMaterializerBlueprintError::ApprovalOrProofBoundaryBroken
        );
    }

    #[test]
    fn rejects_byte_or_command_leak() {
        let mut spec = SyntheticMaterializerPrimitiveBlueprint::canonical();
        spec.byte_ledger.payload_files_written = 1;
        assert_eq!(
            spec.validate().unwrap_err(),
            SyntheticMaterializerBlueprintError::ByteOrCommandLeak
        );
    }

    #[test]
    fn rejects_promotion_claims() {
        let mut spec = SyntheticMaterializerPrimitiveBlueprint::canonical();
        spec.l2_claimed = true;
        assert_eq!(
            spec.validate().unwrap_err(),
            SyntheticMaterializerBlueprintError::PromotionClaim
        );
    }
}
