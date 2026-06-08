//! JCS canonical JSON writer parity gate.
//!
//! This gate protects synthetic fixture materialization from false identity
//! proof. It binds the RFC 8785/JCS requirements that must be satisfied before
//! fixture bytes can be written, while honestly blocking promotion until the
//! number-serialization and UTF-16 property-sort oracle is implemented.

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{
    SyntheticPayloadMaterializationGateWitness, SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_CURSOR,
    SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_ID,
};
use serde::{Deserialize, Serialize};
use std::fmt;

pub const JCS_CANONICAL_JSON_WRITER_PARITY_GATE_ID: &str = "F-JcsCanonicalJsonWriterParityGate";
pub const JCS_CANONICAL_JSON_WRITER_PARITY_GATE_CURSOR: &str =
    "jcs_canonical_json_writer_parity_gate";
pub const JCS_CANONICAL_JSON_WRITER_PARITY_GATE_NEXT_CURSOR: &str =
    "jcs_number_and_utf16_sort_oracle_probe";

const RFC_8785_URL: &str = "https://www.rfc-editor.org/rfc/rfc8785";
const JSON_SCHEMA_URL: &str = "https://json-schema.org/specification";
const TRI_FUSION_WRITER_REF: &str = "agent_core/src/tri_fusion/mod.rs:1251";
const FALSIFIER_ARTIFACT_WRITER_REF: &str = "agent_core/src/falsifier_artifacts/mod.rs:256";
const ROLLBACK_REF: &str = "rollback:jcs_canonical_json_writer_parity_gate";
const RUN_EVENT_LOG_REF: &str = "run_event_log:jcs_canonical_json_writer_parity_gate";
const ANSWER_PACKET_REF: &str = "answer_packet:jcs_canonical_json_writer_parity_gate";
const GUARD_PRODUCT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
// UAS: uas:jcs-canonical-json-writer-parity:status
// Plane: Verification + Controller.
// Residency: metadata-only gate; fixture materialization remains blocked.
pub enum JcsCanonicalJsonWriterParityStatus {
    MaterializationBlockedUntilFullParity,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-canonical-json-writer-parity:source-card
// Plane: Verification.
// Residency: source references for the parity gate; no external code import.
pub struct JcsCanonicalJsonWriterSourceCard {
    pub rfc_8785_url: String,
    pub json_schema_url: String,
    pub tri_fusion_writer_ref: String,
    pub falsifier_artifact_writer_ref: String,
    pub source_disposition: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-canonical-json-writer-parity:policy
// Plane: Verification.
// Residency: required parity checks before synthetic fixture bytes can exist.
pub struct JcsCanonicalJsonWriterPolicy {
    pub i_json_required: bool,
    pub duplicate_key_rejection_required: bool,
    pub invalid_unicode_rejection_required: bool,
    pub nan_infinity_rejection_required: bool,
    pub no_whitespace_output_required: bool,
    pub recursive_object_sort_required: bool,
    pub array_order_preservation_required: bool,
    pub utf8_output_required: bool,
    pub utf16_property_sort_oracle_required: bool,
    pub ecmascript_number_oracle_required: bool,
    pub stable_sha256_digest_map_required: bool,
    pub draft_2020_12_schema_required: bool,
    pub serde_json_to_string_not_full_jcs: bool,
    pub tri_fusion_writer_not_fixture_authority: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-canonical-json-writer-parity:sample-matrix
// Plane: Verification.
// Residency: planned parity samples; no fixture files written.
pub struct JcsCanonicalJsonWriterSampleMatrix {
    pub literal_sample_count: u64,
    pub string_escape_sample_count: u64,
    pub recursive_object_sort_sample_count: u64,
    pub array_order_sample_count: u64,
    pub utf8_output_sample_count: u64,
    pub digest_map_sample_count: u64,
    pub duplicate_key_red_fixture_count: u64,
    pub invalid_unicode_red_fixture_count: u64,
    pub nan_infinity_red_fixture_count: u64,
    pub number_oracle_blocker_count: u64,
    pub utf16_sort_oracle_blocker_count: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-canonical-json-writer-parity:byte-ledger
// Plane: Verification.
// Residency: metadata-only; no fixture/model/runtime bytes.
pub struct JcsCanonicalJsonWriterByteLedger {
    pub fixture_files_written: u64,
    pub fixture_bytes_written: u64,
    pub schema_files_written: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub cache_index_bytes_opened: u64,
    pub commands_armed: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-canonical-json-writer-parity:spec
// Plane: Verification + Controller.
// Residency: parity gate consumed by the synthetic materializer side-ladder.
pub struct JcsCanonicalJsonWriterParityGate {
    pub upstream_falsifier_id: String,
    pub upstream_cursor: String,
    pub upstream_materialization_gate_address: String,
    pub source_card: JcsCanonicalJsonWriterSourceCard,
    pub policy: JcsCanonicalJsonWriterPolicy,
    pub sample_matrix: JcsCanonicalJsonWriterSampleMatrix,
    pub byte_ledger: JcsCanonicalJsonWriterByteLedger,
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
    pub status: JcsCanonicalJsonWriterParityStatus,
}

impl JcsCanonicalJsonWriterParityGate {
    pub fn canonical() -> Result<Self, JcsCanonicalJsonWriterParityError> {
        let upstream = SyntheticPayloadMaterializationGateWitness::new()
            .map_err(|_| JcsCanonicalJsonWriterParityError::UpstreamMaterializationGateBroken)?;
        upstream
            .validate()
            .map_err(|_| JcsCanonicalJsonWriterParityError::UpstreamMaterializationGateBroken)?;
        Ok(Self {
            upstream_falsifier_id: SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_ID.to_string(),
            upstream_cursor: SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_CURSOR.to_string(),
            upstream_materialization_gate_address: upstream.address,
            source_card: JcsCanonicalJsonWriterSourceCard {
                rfc_8785_url: RFC_8785_URL.to_string(),
                json_schema_url: JSON_SCHEMA_URL.to_string(),
                tri_fusion_writer_ref: TRI_FUSION_WRITER_REF.to_string(),
                falsifier_artifact_writer_ref: FALSIFIER_ARTIFACT_WRITER_REF.to_string(),
                source_disposition: "primary_sources_plus_local_writer_gap_card".to_string(),
            },
            policy: JcsCanonicalJsonWriterPolicy {
                i_json_required: true,
                duplicate_key_rejection_required: true,
                invalid_unicode_rejection_required: true,
                nan_infinity_rejection_required: true,
                no_whitespace_output_required: true,
                recursive_object_sort_required: true,
                array_order_preservation_required: true,
                utf8_output_required: true,
                utf16_property_sort_oracle_required: true,
                ecmascript_number_oracle_required: true,
                stable_sha256_digest_map_required: true,
                draft_2020_12_schema_required: true,
                serde_json_to_string_not_full_jcs: true,
                tri_fusion_writer_not_fixture_authority: true,
            },
            sample_matrix: JcsCanonicalJsonWriterSampleMatrix {
                literal_sample_count: 3,
                string_escape_sample_count: 4,
                recursive_object_sort_sample_count: 3,
                array_order_sample_count: 2,
                utf8_output_sample_count: 2,
                digest_map_sample_count: 2,
                duplicate_key_red_fixture_count: 2,
                invalid_unicode_red_fixture_count: 2,
                nan_infinity_red_fixture_count: 2,
                number_oracle_blocker_count: 1,
                utf16_sort_oracle_blocker_count: 1,
            },
            byte_ledger: JcsCanonicalJsonWriterByteLedger {
                fixture_files_written: 0,
                fixture_bytes_written: 0,
                schema_files_written: 0,
                model_runtime_bytes_loaded: 0,
                provider_calls_made: 0,
                cache_index_bytes_opened: 0,
                commands_armed: 0,
            },
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
            status: JcsCanonicalJsonWriterParityStatus::MaterializationBlockedUntilFullParity,
        })
    }

    pub fn validate(&self) -> Result<(), JcsCanonicalJsonWriterParityError> {
        let upstream = SyntheticPayloadMaterializationGateWitness::new()
            .map_err(|_| JcsCanonicalJsonWriterParityError::UpstreamMaterializationGateBroken)?;
        upstream
            .validate()
            .map_err(|_| JcsCanonicalJsonWriterParityError::UpstreamMaterializationGateBroken)?;
        validate_exact(
            "upstream_falsifier_id",
            &self.upstream_falsifier_id,
            SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_ID,
        )?;
        validate_exact(
            "upstream_cursor",
            &self.upstream_cursor,
            SYNTHETIC_PAYLOAD_MATERIALIZATION_GATE_CURSOR,
        )?;
        validate_exact(
            "upstream_materialization_gate_address",
            &self.upstream_materialization_gate_address,
            &upstream.address,
        )?;
        self.source_card.validate()?;
        self.policy.validate()?;
        self.sample_matrix.validate()?;
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
        if self.materialization_allowed || !self.metadata_only {
            return Err(JcsCanonicalJsonWriterParityError::MaterializationBoundaryBroken);
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
            return Err(JcsCanonicalJsonWriterParityError::PromotionClaim);
        }
        if self.status != JcsCanonicalJsonWriterParityStatus::MaterializationBlockedUntilFullParity
        {
            return Err(JcsCanonicalJsonWriterParityError::WrongStatus);
        }
        Ok(())
    }
}

impl JcsCanonicalJsonWriterSourceCard {
    pub fn validate(&self) -> Result<(), JcsCanonicalJsonWriterParityError> {
        validate_exact("rfc_8785_url", &self.rfc_8785_url, RFC_8785_URL)?;
        validate_exact("json_schema_url", &self.json_schema_url, JSON_SCHEMA_URL)?;
        validate_exact(
            "tri_fusion_writer_ref",
            &self.tri_fusion_writer_ref,
            TRI_FUSION_WRITER_REF,
        )?;
        validate_exact(
            "falsifier_artifact_writer_ref",
            &self.falsifier_artifact_writer_ref,
            FALSIFIER_ARTIFACT_WRITER_REF,
        )?;
        validate_exact(
            "source_disposition",
            &self.source_disposition,
            "primary_sources_plus_local_writer_gap_card",
        )?;
        Ok(())
    }
}

impl JcsCanonicalJsonWriterPolicy {
    pub fn validate(&self) -> Result<(), JcsCanonicalJsonWriterParityError> {
        if !self.i_json_required
            || !self.duplicate_key_rejection_required
            || !self.invalid_unicode_rejection_required
            || !self.nan_infinity_rejection_required
            || !self.no_whitespace_output_required
            || !self.recursive_object_sort_required
            || !self.array_order_preservation_required
            || !self.utf8_output_required
            || !self.utf16_property_sort_oracle_required
            || !self.ecmascript_number_oracle_required
            || !self.stable_sha256_digest_map_required
            || !self.draft_2020_12_schema_required
            || !self.serde_json_to_string_not_full_jcs
            || !self.tri_fusion_writer_not_fixture_authority
        {
            return Err(JcsCanonicalJsonWriterParityError::PolicyBroken);
        }
        Ok(())
    }
}

impl JcsCanonicalJsonWriterSampleMatrix {
    pub fn validate(&self) -> Result<(), JcsCanonicalJsonWriterParityError> {
        if self.literal_sample_count != 3
            || self.string_escape_sample_count != 4
            || self.recursive_object_sort_sample_count != 3
            || self.array_order_sample_count != 2
            || self.utf8_output_sample_count != 2
            || self.digest_map_sample_count != 2
            || self.duplicate_key_red_fixture_count != 2
            || self.invalid_unicode_red_fixture_count != 2
            || self.nan_infinity_red_fixture_count != 2
            || self.number_oracle_blocker_count != 1
            || self.utf16_sort_oracle_blocker_count != 1
        {
            return Err(JcsCanonicalJsonWriterParityError::SampleMatrixBroken);
        }
        Ok(())
    }
}

impl JcsCanonicalJsonWriterByteLedger {
    pub fn validate(&self) -> Result<(), JcsCanonicalJsonWriterParityError> {
        if self.fixture_files_written != 0
            || self.fixture_bytes_written != 0
            || self.schema_files_written != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.cache_index_bytes_opened != 0
            || self.commands_armed != 0
        {
            return Err(JcsCanonicalJsonWriterParityError::ByteOrCommandLeak);
        }
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-canonical-json-writer-parity:metrics
// Plane: Verification.
// Residency: metadata-only parity counters.
pub struct JcsCanonicalJsonWriterParityMetrics {
    pub positive_sample_count: u64,
    pub red_fixture_count: u64,
    pub blocker_count: u64,
    pub fixture_files_written: u64,
    pub fixture_bytes_written: u64,
    pub runtime_model_provider_cache_index_bytes: u64,
    pub commands_armed: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-canonical-json-writer-parity:witness
// Plane: Verification + Controller.
// Residency: L1/T1 side-ladder; no fixture materialization.
pub struct JcsCanonicalJsonWriterParityGateWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub spec: JcsCanonicalJsonWriterParityGate,
    pub metrics: JcsCanonicalJsonWriterParityMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub product_promotion_blocked: bool,
}

impl JcsCanonicalJsonWriterParityGateWitness {
    pub fn new() -> Result<Self, JcsCanonicalJsonWriterParityError> {
        let spec = JcsCanonicalJsonWriterParityGate::canonical()?;
        spec.validate()?;
        let metrics = JcsCanonicalJsonWriterParityMetrics {
            positive_sample_count: spec.sample_matrix.literal_sample_count
                + spec.sample_matrix.string_escape_sample_count
                + spec.sample_matrix.recursive_object_sort_sample_count
                + spec.sample_matrix.array_order_sample_count
                + spec.sample_matrix.utf8_output_sample_count
                + spec.sample_matrix.digest_map_sample_count,
            red_fixture_count: spec.sample_matrix.duplicate_key_red_fixture_count
                + spec.sample_matrix.invalid_unicode_red_fixture_count
                + spec.sample_matrix.nan_infinity_red_fixture_count,
            blocker_count: spec.sample_matrix.number_oracle_blocker_count
                + spec.sample_matrix.utf16_sort_oracle_blocker_count,
            fixture_files_written: spec.byte_ledger.fixture_files_written
                + spec.byte_ledger.schema_files_written,
            fixture_bytes_written: spec.byte_ledger.fixture_bytes_written,
            runtime_model_provider_cache_index_bytes: spec.byte_ledger.model_runtime_bytes_loaded
                + spec.byte_ledger.provider_calls_made
                + spec.byte_ledger.cache_index_bytes_opened,
            commands_armed: spec.byte_ledger.commands_armed,
        };
        let address = jcs_canonical_json_writer_parity_gate_address(&spec, &metrics);
        Ok(Self {
            falsifier_id: JCS_CANONICAL_JSON_WRITER_PARITY_GATE_ID.to_string(),
            cursor: JCS_CANONICAL_JSON_WRITER_PARITY_GATE_CURSOR.to_string(),
            next_cursor: JCS_CANONICAL_JSON_WRITER_PARITY_GATE_NEXT_CURSOR.to_string(),
            spec,
            metrics,
            address,
            metadata_only: true,
            product_promotion_blocked: true,
        })
    }

    pub fn validate(&self) -> Result<(), JcsCanonicalJsonWriterParityError> {
        if self.falsifier_id != JCS_CANONICAL_JSON_WRITER_PARITY_GATE_ID
            || self.cursor != JCS_CANONICAL_JSON_WRITER_PARITY_GATE_CURSOR
            || self.next_cursor != JCS_CANONICAL_JSON_WRITER_PARITY_GATE_NEXT_CURSOR
            || !self.metadata_only
            || !self.product_promotion_blocked
        {
            return Err(JcsCanonicalJsonWriterParityError::WitnessHeaderBroken);
        }
        self.spec.validate()?;
        let rebuilt = Self::new()?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(JcsCanonicalJsonWriterParityError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn jcs_canonical_json_writer_parity_gate_address(
    spec: &JcsCanonicalJsonWriterParityGate,
    metrics: &JcsCanonicalJsonWriterParityMetrics,
) -> String {
    let payload = serde_json::json!({
        "id": JCS_CANONICAL_JSON_WRITER_PARITY_GATE_ID,
        "spec": spec,
        "metrics": metrics,
    });
    sha256_hex(payload.to_string().as_bytes())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:jcs-canonical-json-writer-parity:error
// Plane: Verification.
// Residency: fail-closed parity rejection taxonomy.
pub enum JcsCanonicalJsonWriterParityError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    WrongValue(&'static str),
    UpstreamMaterializationGateBroken,
    PolicyBroken,
    SampleMatrixBroken,
    ByteOrCommandLeak,
    MaterializationBoundaryBroken,
    PromotionClaim,
    WrongStatus,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for JcsCanonicalJsonWriterParityError {
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
            Self::UpstreamMaterializationGateBroken => {
                write!(f, "upstream materialization gate broken")
            }
            Self::PolicyBroken => write!(f, "JCS parity policy broken"),
            Self::SampleMatrixBroken => write!(f, "JCS sample matrix broken"),
            Self::ByteOrCommandLeak => write!(f, "byte or command leak"),
            Self::MaterializationBoundaryBroken => write!(f, "materialization boundary broken"),
            Self::PromotionClaim => write!(f, "promotion claim attempted"),
            Self::WrongStatus => write!(f, "wrong JCS parity status"),
            Self::WitnessHeaderBroken => write!(f, "witness header broken"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for JcsCanonicalJsonWriterParityError {}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), JcsCanonicalJsonWriterParityError> {
    validate_token(field, value)?;
    if value != expected {
        return Err(JcsCanonicalJsonWriterParityError::WrongValue(field));
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), JcsCanonicalJsonWriterParityError> {
    if value.is_empty() {
        return Err(JcsCanonicalJsonWriterParityError::MissingField(field));
    }
    if value.trim() != value {
        return Err(JcsCanonicalJsonWriterParityError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(JcsCanonicalJsonWriterParityError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_gate_validates() {
        JcsCanonicalJsonWriterParityGate::canonical()
            .expect("gate")
            .validate()
            .expect("canonical validates");
    }

    #[test]
    fn witness_is_deterministic() {
        let first = JcsCanonicalJsonWriterParityGateWitness::new().expect("first");
        let second = JcsCanonicalJsonWriterParityGateWitness::new().expect("second");
        assert_eq!(first.address, second.address);
        assert_eq!(first.metrics.positive_sample_count, 16);
        assert_eq!(first.metrics.red_fixture_count, 6);
        assert_eq!(first.metrics.blocker_count, 2);
    }

    #[test]
    fn rejects_upstream_address_drift() {
        let mut gate = JcsCanonicalJsonWriterParityGate::canonical().expect("gate");
        gate.upstream_materialization_gate_address =
            "sha256:0000000000000000000000000000000000000000000000000000000000000000".to_string();
        assert_eq!(
            gate.validate().unwrap_err(),
            JcsCanonicalJsonWriterParityError::WrongValue("upstream_materialization_gate_address")
        );
    }

    #[test]
    fn rejects_missing_duplicate_key_requirement() {
        let mut gate = JcsCanonicalJsonWriterParityGate::canonical().expect("gate");
        gate.policy.duplicate_key_rejection_required = false;
        assert_eq!(
            gate.validate().unwrap_err(),
            JcsCanonicalJsonWriterParityError::PolicyBroken
        );
    }

    #[test]
    fn rejects_full_jcs_overclaim_for_serde_json() {
        let mut gate = JcsCanonicalJsonWriterParityGate::canonical().expect("gate");
        gate.policy.serde_json_to_string_not_full_jcs = false;
        assert_eq!(
            gate.validate().unwrap_err(),
            JcsCanonicalJsonWriterParityError::PolicyBroken
        );
    }

    #[test]
    fn rejects_trifusion_as_fixture_authority() {
        let mut gate = JcsCanonicalJsonWriterParityGate::canonical().expect("gate");
        gate.policy.tri_fusion_writer_not_fixture_authority = false;
        assert_eq!(
            gate.validate().unwrap_err(),
            JcsCanonicalJsonWriterParityError::PolicyBroken
        );
    }

    #[test]
    fn rejects_number_oracle_gap() {
        let mut gate = JcsCanonicalJsonWriterParityGate::canonical().expect("gate");
        gate.policy.ecmascript_number_oracle_required = false;
        assert_eq!(
            gate.validate().unwrap_err(),
            JcsCanonicalJsonWriterParityError::PolicyBroken
        );
    }

    #[test]
    fn rejects_utf16_sort_oracle_gap() {
        let mut gate = JcsCanonicalJsonWriterParityGate::canonical().expect("gate");
        gate.policy.utf16_property_sort_oracle_required = false;
        assert_eq!(
            gate.validate().unwrap_err(),
            JcsCanonicalJsonWriterParityError::PolicyBroken
        );
    }

    #[test]
    fn rejects_sample_matrix_drift() {
        let mut gate = JcsCanonicalJsonWriterParityGate::canonical().expect("gate");
        gate.sample_matrix.duplicate_key_red_fixture_count = 1;
        assert_eq!(
            gate.validate().unwrap_err(),
            JcsCanonicalJsonWriterParityError::SampleMatrixBroken
        );
    }

    #[test]
    fn rejects_byte_or_command_leak() {
        let mut gate = JcsCanonicalJsonWriterParityGate::canonical().expect("gate");
        gate.byte_ledger.fixture_files_written = 1;
        assert_eq!(
            gate.validate().unwrap_err(),
            JcsCanonicalJsonWriterParityError::ByteOrCommandLeak
        );
    }

    #[test]
    fn rejects_materialization_enablement() {
        let mut gate = JcsCanonicalJsonWriterParityGate::canonical().expect("gate");
        gate.materialization_allowed = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            JcsCanonicalJsonWriterParityError::MaterializationBoundaryBroken
        );
    }

    #[test]
    fn rejects_promotion_claim() {
        let mut gate = JcsCanonicalJsonWriterParityGate::canonical().expect("gate");
        gate.l2_claimed = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            JcsCanonicalJsonWriterParityError::PromotionClaim
        );
    }
}
