use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_ID: &str =
    "F-GraphFilterVisibilityFocusedProofRootExecutionArtifactGate";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_CURSOR: &str =
    "graph_filter_visibility_focused_proof_root_execution_artifact_gate";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/graph_filter_visibility_focused_proof_root_command_card/result.json#F-GraphFilterVisibilityFocusedProofRootCommandCard";

const REQUIRED_EXECUTION_MANIFEST_FIELDS: [&str; 18] = [
    "source_commit_sha",
    "pre_build_source_status_digest",
    "post_test_source_status_digest",
    "scheme_pre_action_ledger_digest",
    "selected_test_product_path",
    "selected_test_product_kind",
    "selected_test_product_digest",
    "selected_test_product_commit_sha",
    "enumeration_json_digest",
    "focused_selector_digest",
    "focused_result_bundle_path",
    "focused_result_bundle_digest",
    "focused_result_bundle_status",
    "executed_test_count",
    "full_automated_check_row_status",
    "run_event_log_digest",
    "answer_packet_digest",
    "rollback_digest",
];

const REQUIRED_REJECTION_POLICIES: [&str; 14] = [
    "missing_selected_product_digest",
    "missing_xcresult_digest",
    "zero_executed_tests",
    "source_status_drift_unaccounted",
    "scheme_pre_action_unaccounted",
    "full_row_replaced_by_focused_proof",
    "wrong_source_commit",
    "global_derived_data",
    "stale_or_external_test_product",
    "raw_note_prompt_model_bytes",
    "product_or_release_green_claim",
    "l2_l3_green_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
// UAS: uas:graph-filter-visibility-focused-proof-root-execution-artifact-gate:status
// Plane: Verification.
// Residency: metadata-only execution-artifact parser contract.
pub enum GraphFilterFocusedProofRootExecutionArtifactStatus {
    ParserContractOnly,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:graph-filter-visibility-focused-proof-root-execution-artifact-gate:spec
// Plane: Verification + Controller.
// Residency: post-run manifest parser contract; no Xcode/result bytes opened.
pub struct GraphFilterFocusedProofRootExecutionArtifactGate {
    pub proof_root_prefix: String,
    pub manifest_name: String,
    pub required_execution_manifest_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub minimum_executed_test_count: u64,
    pub selected_test_product_digest_required: bool,
    pub selected_test_product_commit_required: bool,
    pub enumeration_digest_required: bool,
    pub focused_selector_digest_required: bool,
    pub focused_result_bundle_digest_required: bool,
    pub source_status_digests_required: bool,
    pub scheme_pre_action_ledger_required: bool,
    pub run_event_log_digest_required: bool,
    pub answer_packet_digest_required: bool,
    pub rollback_digest_required: bool,
    pub full_automated_check_row_still_required: bool,
    pub focused_proof_replaces_full_row: bool,
    pub parser_dry_run_only: bool,
    pub metadata_only: bool,
    pub xcode_command_executed: bool,
    pub selected_test_product_bytes_opened: u64,
    pub xcode_result_bytes_opened: u64,
    pub app_runtime_bytes_loaded: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_code_changed: bool,
    pub raw_note_prompt_model_bytes_logged: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub release_ready_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub status: GraphFilterFocusedProofRootExecutionArtifactStatus,
}

impl GraphFilterFocusedProofRootExecutionArtifactGate {
    pub fn canonical() -> Self {
        Self {
            proof_root_prefix: "artifacts/xcode/graph-filter-visibility-test-products/".to_string(),
            manifest_name: "focused-proof-root-execution-artifact.json".to_string(),
            required_execution_manifest_fields: REQUIRED_EXECUTION_MANIFEST_FIELDS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            minimum_executed_test_count: 1,
            selected_test_product_digest_required: true,
            selected_test_product_commit_required: true,
            enumeration_digest_required: true,
            focused_selector_digest_required: true,
            focused_result_bundle_digest_required: true,
            source_status_digests_required: true,
            scheme_pre_action_ledger_required: true,
            run_event_log_digest_required: true,
            answer_packet_digest_required: true,
            rollback_digest_required: true,
            full_automated_check_row_still_required: true,
            focused_proof_replaces_full_row: false,
            parser_dry_run_only: true,
            metadata_only: true,
            xcode_command_executed: false,
            selected_test_product_bytes_opened: 0,
            xcode_result_bytes_opened: 0,
            app_runtime_bytes_loaded: 0,
            model_runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            product_code_changed: false,
            raw_note_prompt_model_bytes_logged: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            release_ready_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            rollback_ref:
                "rollback:graph_filter_visibility_focused_proof_root_execution_artifact_gate"
                    .to_string(),
            run_event_log_ref:
                "run_event_log:graph_filter_visibility_focused_proof_root_execution_artifact_gate"
                    .to_string(),
            answer_packet_ref:
                "answer_packet:graph_filter_visibility_focused_proof_root_execution_artifact_gate"
                    .to_string(),
            status: GraphFilterFocusedProofRootExecutionArtifactStatus::ParserContractOnly,
        }
    }

    pub fn validate(&self) -> Result<(), GraphFilterFocusedProofRootExecutionArtifactGateError> {
        if self
            .proof_root_prefix
            .contains("~/Library/Developer/Xcode/DerivedData")
            || self
                .proof_root_prefix
                .contains("/Library/Developer/Xcode/DerivedData")
        {
            return Err(
                GraphFilterFocusedProofRootExecutionArtifactGateError::GlobalDerivedDataPath,
            );
        }
        validate_prefix(
            "proof_root_prefix",
            &self.proof_root_prefix,
            "artifacts/xcode/graph-filter-visibility-test-products/",
        )?;
        validate_exact(
            "manifest_name",
            &self.manifest_name,
            "focused-proof-root-execution-artifact.json",
        )?;
        validate_unique_exact_set(
            "required_execution_manifest_fields",
            &self.required_execution_manifest_fields,
            &REQUIRED_EXECUTION_MANIFEST_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_rejection_policies",
            &self.required_rejection_policies,
            &REQUIRED_REJECTION_POLICIES,
        )?;
        if self.minimum_executed_test_count == 0 {
            return Err(
                GraphFilterFocusedProofRootExecutionArtifactGateError::ZeroExecutedTestPolicy,
            );
        }
        if !self.selected_test_product_digest_required
            || !self.selected_test_product_commit_required
            || !self.enumeration_digest_required
            || !self.focused_selector_digest_required
            || !self.focused_result_bundle_digest_required
            || !self.source_status_digests_required
            || !self.scheme_pre_action_ledger_required
            || !self.run_event_log_digest_required
            || !self.answer_packet_digest_required
            || !self.rollback_digest_required
            || !self.full_automated_check_row_still_required
            || self.focused_proof_replaces_full_row
        {
            return Err(GraphFilterFocusedProofRootExecutionArtifactGateError::ProofBoundaryBroken);
        }
        if !self.parser_dry_run_only
            || !self.metadata_only
            || self.xcode_command_executed
            || self.selected_test_product_bytes_opened != 0
            || self.xcode_result_bytes_opened != 0
            || self.app_runtime_bytes_loaded != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.product_code_changed
            || self.raw_note_prompt_model_bytes_logged
        {
            return Err(GraphFilterFocusedProofRootExecutionArtifactGateError::ByteOrExecutionLeak);
        }
        if self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.release_ready_claimed
            || self.live_dense_70b_claimed
            || self.ssd_as_ram_claimed
        {
            return Err(GraphFilterFocusedProofRootExecutionArtifactGateError::PromotionClaim);
        }
        validate_prefix("rollback_ref", &self.rollback_ref, "rollback:")?;
        validate_prefix(
            "run_event_log_ref",
            &self.run_event_log_ref,
            "run_event_log:",
        )?;
        validate_prefix(
            "answer_packet_ref",
            &self.answer_packet_ref,
            "answer_packet:",
        )?;
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:graph-filter-visibility-focused-proof-root-execution-artifact-gate:metrics
// Plane: Verification.
// Residency: parser contract counts and zero-byte ledger.
pub struct GraphFilterFocusedProofRootExecutionArtifactMetrics {
    pub required_manifest_field_count: usize,
    pub required_rejection_policy_count: usize,
    pub minimum_executed_test_count: u64,
    pub selected_test_product_bytes_opened: u64,
    pub xcode_result_bytes_opened: u64,
    pub app_runtime_bytes_loaded: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:graph-filter-visibility-focused-proof-root-execution-artifact-gate:witness
// Plane: Verification + Controller.
// Residency: metadata-only parser gate bound to the command-card witness.
pub struct GraphFilterVisibilityFocusedProofRootExecutionArtifactGateWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_artifact_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_address: String,
    pub upstream_next_cursor: String,
    pub spec: GraphFilterFocusedProofRootExecutionArtifactGate,
    pub metrics: GraphFilterFocusedProofRootExecutionArtifactMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl GraphFilterVisibilityFocusedProofRootExecutionArtifactGateWitness {
    pub fn new(
        upstream_overall_pass: bool,
        upstream_address: &str,
        upstream_next_cursor: &str,
    ) -> Result<Self, GraphFilterFocusedProofRootExecutionArtifactGateError> {
        if !upstream_overall_pass {
            return Err(GraphFilterFocusedProofRootExecutionArtifactGateError::UpstreamNotPassed);
        }
        validate_sha256_address("upstream_address", upstream_address)?;
        validate_exact(
            "upstream_next_cursor",
            upstream_next_cursor,
            GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR,
        )?;
        let spec = GraphFilterFocusedProofRootExecutionArtifactGate::canonical();
        spec.validate()?;
        let metrics = GraphFilterFocusedProofRootExecutionArtifactMetrics {
            required_manifest_field_count: spec.required_execution_manifest_fields.len(),
            required_rejection_policy_count: spec.required_rejection_policies.len(),
            minimum_executed_test_count: spec.minimum_executed_test_count,
            selected_test_product_bytes_opened: spec.selected_test_product_bytes_opened,
            xcode_result_bytes_opened: spec.xcode_result_bytes_opened,
            app_runtime_bytes_loaded: spec.app_runtime_bytes_loaded,
            model_runtime_bytes_loaded: spec.model_runtime_bytes_loaded,
            provider_calls_made: spec.provider_calls_made,
        };
        let address = graph_filter_focused_proof_root_execution_artifact_gate_address(
            upstream_overall_pass,
            upstream_address,
            upstream_next_cursor,
            &spec,
            &metrics,
        );
        Ok(Self {
            falsifier_id: GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_ID
                .to_string(),
            cursor: GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_CURSOR
                .to_string(),
            next_cursor:
                GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR
                    .to_string(),
            upstream_artifact_ref:
                GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF
                    .to_string(),
            upstream_overall_pass,
            upstream_address: upstream_address.to_string(),
            upstream_next_cursor: upstream_next_cursor.to_string(),
            spec,
            metrics,
            address,
            metadata_only: true,
            no_product_promotion: true,
        })
    }

    pub fn validate(&self) -> Result<(), GraphFilterFocusedProofRootExecutionArtifactGateError> {
        if self.falsifier_id
            != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_ID
            || self.cursor
                != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_CURSOR
            || self.next_cursor
                != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR
            || self.upstream_artifact_ref
                != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_UPSTREAM_REF
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(GraphFilterFocusedProofRootExecutionArtifactGateError::WitnessHeaderBroken);
        }
        let rebuilt = Self::new(
            self.upstream_overall_pass,
            &self.upstream_address,
            &self.upstream_next_cursor,
        )?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(
                GraphFilterFocusedProofRootExecutionArtifactGateError::WitnessDigestMismatch,
            );
        }
        Ok(())
    }
}

pub fn required_graph_filter_focused_proof_root_execution_manifest_fields(
) -> &'static [&'static str] {
    &REQUIRED_EXECUTION_MANIFEST_FIELDS
}

pub fn required_graph_filter_focused_proof_root_execution_rejection_policies(
) -> &'static [&'static str] {
    &REQUIRED_REJECTION_POLICIES
}

fn graph_filter_focused_proof_root_execution_artifact_gate_address(
    upstream_overall_pass: bool,
    upstream_address: &str,
    upstream_next_cursor: &str,
    spec: &GraphFilterFocusedProofRootExecutionArtifactGate,
    metrics: &GraphFilterFocusedProofRootExecutionArtifactMetrics,
) -> String {
    let payload = serde_json::json!({
        "id": GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_ID,
        "upstream_overall_pass": upstream_overall_pass,
        "upstream_address": upstream_address,
        "upstream_next_cursor": upstream_next_cursor,
        "spec": spec,
        "metrics": metrics,
    });
    sha256_hex(payload.to_string().as_bytes())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:graph-filter-visibility-focused-proof-root-execution-artifact-gate:error
// Plane: Verification.
// Residency: fail-closed execution-artifact rejection taxonomy.
pub enum GraphFilterFocusedProofRootExecutionArtifactGateError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    WrongValue(&'static str),
    DuplicateField(String),
    MissingRequiredField(&'static str),
    GlobalDerivedDataPath,
    ZeroExecutedTestPolicy,
    ProofBoundaryBroken,
    ByteOrExecutionLeak,
    PromotionClaim,
    UpstreamNotPassed,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for GraphFilterFocusedProofRootExecutionArtifactGateError {
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
            Self::DuplicateField(field) => write!(f, "duplicate field `{field}`"),
            Self::MissingRequiredField(field) => write!(f, "missing required field `{field}`"),
            Self::GlobalDerivedDataPath => write!(f, "global DerivedData path used"),
            Self::ZeroExecutedTestPolicy => write!(f, "zero executed tests accepted"),
            Self::ProofBoundaryBroken => write!(f, "proof boundary broken"),
            Self::ByteOrExecutionLeak => write!(f, "byte or execution leak"),
            Self::PromotionClaim => write!(f, "promotion claim attempted"),
            Self::UpstreamNotPassed => write!(f, "upstream command card not passed"),
            Self::WitnessHeaderBroken => write!(f, "witness header broken"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for GraphFilterFocusedProofRootExecutionArtifactGateError {}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), GraphFilterFocusedProofRootExecutionArtifactGateError> {
    validate_token(field, value)?;
    if value != expected {
        return Err(GraphFilterFocusedProofRootExecutionArtifactGateError::WrongValue(field));
    }
    Ok(())
}

fn validate_prefix(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), GraphFilterFocusedProofRootExecutionArtifactGateError> {
    validate_token(field, value)?;
    if !value.starts_with(prefix) {
        return Err(GraphFilterFocusedProofRootExecutionArtifactGateError::WrongValue(field));
    }
    Ok(())
}

fn validate_sha256_address(
    field: &'static str,
    value: &str,
) -> Result<(), GraphFilterFocusedProofRootExecutionArtifactGateError> {
    validate_token(field, value)?;
    if !value.starts_with("sha256:") || value.len() != 71 {
        return Err(GraphFilterFocusedProofRootExecutionArtifactGateError::WrongValue(field));
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), GraphFilterFocusedProofRootExecutionArtifactGateError> {
    if value.is_empty() {
        return Err(GraphFilterFocusedProofRootExecutionArtifactGateError::MissingField(field));
    }
    if value.trim() != value {
        return Err(
            GraphFilterFocusedProofRootExecutionArtifactGateError::FieldHasSurroundingWhitespace(
                field,
            ),
        );
    }
    if value.chars().any(char::is_control) {
        return Err(
            GraphFilterFocusedProofRootExecutionArtifactGateError::FieldContainsControlCharacter(
                field,
            ),
        );
    }
    Ok(())
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    expected: &[&'static str],
) -> Result<(), GraphFilterFocusedProofRootExecutionArtifactGateError> {
    if values.is_empty() {
        return Err(GraphFilterFocusedProofRootExecutionArtifactGateError::MissingField(field));
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_token(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(
                GraphFilterFocusedProofRootExecutionArtifactGateError::DuplicateField(
                    value.clone(),
                ),
            );
        }
    }
    for required in expected {
        if !seen.contains(required) {
            return Err(
                GraphFilterFocusedProofRootExecutionArtifactGateError::MissingRequiredField(
                    required,
                ),
            );
        }
    }
    if seen.len() != expected.len() {
        return Err(GraphFilterFocusedProofRootExecutionArtifactGateError::WrongValue(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    const UPSTREAM_ADDRESS: &str =
        "sha256:e7095c8391930693cd93aa9d4e69ce36f45e2b9d178cf7c95a16b81a06aad743";

    #[test]
    fn canonical_gate_validates() {
        GraphFilterFocusedProofRootExecutionArtifactGate::canonical()
            .validate()
            .expect("canonical execution artifact gate should validate");
    }

    #[test]
    fn witness_is_deterministic() {
        let first = GraphFilterVisibilityFocusedProofRootExecutionArtifactGateWitness::new(
            true,
            UPSTREAM_ADDRESS,
            GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR,
        )
        .expect("valid witness");
        let second = GraphFilterVisibilityFocusedProofRootExecutionArtifactGateWitness::new(
            true,
            UPSTREAM_ADDRESS,
            GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR,
        )
        .expect("valid witness");
        assert_eq!(first.address, second.address);
        assert_eq!(first.metrics.required_manifest_field_count, 18);
        assert_eq!(first.metrics.required_rejection_policy_count, 14);
    }

    #[test]
    fn rejects_global_derived_data_path() {
        let mut gate = GraphFilterFocusedProofRootExecutionArtifactGate::canonical();
        gate.proof_root_prefix = "~/Library/Developer/Xcode/DerivedData/graph-filter/".to_string();
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootExecutionArtifactGateError::GlobalDerivedDataPath
        );
    }

    #[test]
    fn rejects_missing_manifest_field() {
        let mut gate = GraphFilterFocusedProofRootExecutionArtifactGate::canonical();
        gate.required_execution_manifest_fields
            .retain(|field| field != "focused_result_bundle_digest");
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootExecutionArtifactGateError::MissingRequiredField(
                "focused_result_bundle_digest"
            )
        );
    }

    #[test]
    fn rejects_zero_executed_test_policy() {
        let mut gate = GraphFilterFocusedProofRootExecutionArtifactGate::canonical();
        gate.minimum_executed_test_count = 0;
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootExecutionArtifactGateError::ZeroExecutedTestPolicy
        );
    }

    #[test]
    fn rejects_missing_required_digests() {
        let mut gate = GraphFilterFocusedProofRootExecutionArtifactGate::canonical();
        gate.focused_result_bundle_digest_required = false;
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootExecutionArtifactGateError::ProofBoundaryBroken
        );
        let mut packet = GraphFilterFocusedProofRootExecutionArtifactGate::canonical();
        packet.answer_packet_digest_required = false;
        assert_eq!(
            packet.validate().unwrap_err(),
            GraphFilterFocusedProofRootExecutionArtifactGateError::ProofBoundaryBroken
        );
    }

    #[test]
    fn rejects_byte_or_execution_leaks() {
        let mut gate = GraphFilterFocusedProofRootExecutionArtifactGate::canonical();
        gate.xcode_command_executed = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootExecutionArtifactGateError::ByteOrExecutionLeak
        );
        let mut result = GraphFilterFocusedProofRootExecutionArtifactGate::canonical();
        result.xcode_result_bytes_opened = 1;
        assert_eq!(
            result.validate().unwrap_err(),
            GraphFilterFocusedProofRootExecutionArtifactGateError::ByteOrExecutionLeak
        );
    }

    #[test]
    fn rejects_release_and_large_model_claims() {
        let mut release = GraphFilterFocusedProofRootExecutionArtifactGate::canonical();
        release.release_ready_claimed = true;
        assert_eq!(
            release.validate().unwrap_err(),
            GraphFilterFocusedProofRootExecutionArtifactGateError::PromotionClaim
        );
        let mut large = GraphFilterFocusedProofRootExecutionArtifactGate::canonical();
        large.live_dense_70b_claimed = true;
        assert_eq!(
            large.validate().unwrap_err(),
            GraphFilterFocusedProofRootExecutionArtifactGateError::PromotionClaim
        );
    }

    #[test]
    fn rejects_bad_upstream() {
        assert_eq!(
            GraphFilterVisibilityFocusedProofRootExecutionArtifactGateWitness::new(
                false,
                UPSTREAM_ADDRESS,
                GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_EXECUTION_ARTIFACT_GATE_NEXT_CURSOR,
            )
            .unwrap_err(),
            GraphFilterFocusedProofRootExecutionArtifactGateError::UpstreamNotPassed
        );
    }
}
