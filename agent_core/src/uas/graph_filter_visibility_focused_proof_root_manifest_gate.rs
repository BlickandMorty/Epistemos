use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_ID: &str =
    "F-GraphFilterVisibilityFocusedProofRootManifestGate";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_CURSOR: &str =
    "graph_filter_visibility_focused_proof_root_manifest_gate";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_UPSTREAM_REF: &str =
    "artifact:falsifiers/automated_checks_fresh_test_products_evidence_envelope/result.json#F-AutomatedChecksFreshTestProductsEvidenceEnvelope";

const REQUIRED_MANIFEST_FIELDS: [&str; 13] = [
    "source_commit_sha",
    "pre_build_status_digest",
    "post_test_status_digest",
    "selected_test_product_path",
    "selected_test_product_kind",
    "selected_test_product_digest",
    "enumeration_json_digest",
    "seed_selector_digest",
    "enumerated_selector_digest",
    "focused_result_bundle_digest",
    "executed_test_count",
    "focused_result_bundle_status",
    "full_automated_check_row_status",
];

const SELECTED_TEST_PRODUCT_KINDS: [&str; 2] = ["xctestrun", "xctestproducts"];

const REQUIRED_REJECTION_POLICIES: [&str; 12] = [
    "proof_root_outside_artifacts",
    "global_derived_data",
    "different_commit_product",
    "stale_test_product",
    "missing_manifest_field",
    "missing_or_zero_executed_tests",
    "selector_digest_mismatch",
    "enumeration_json_stale_or_missing",
    "focused_xcresult_stale_or_missing",
    "scheme_pre_action_unaccounted",
    "focused_proof_replaces_full_row",
    "raw_note_prompt_model_byte_logging",
];

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
// UAS: uas:graph-filter-visibility-focused-proof-root-manifest-gate:status
// Plane: Verification.
// Residency: metadata-only proof-root manifest gate; no Xcode execution.
pub enum GraphFilterFocusedProofRootManifestStatus {
    ParserContractOnly,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:graph-filter-visibility-focused-proof-root-manifest-gate:spec
// Plane: Verification.
// Residency: future focused proof-root manifest contract.
pub struct GraphFilterFocusedProofRootManifestGate {
    pub proof_root_prefix: String,
    pub manifest_name: String,
    pub required_manifest_fields: Vec<String>,
    pub selected_test_product_kinds: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub minimum_executed_test_count: u64,
    pub source_status_digests_required: bool,
    pub selected_product_digest_required: bool,
    pub enumeration_digest_required: bool,
    pub focused_result_bundle_digest_required: bool,
    pub scheme_pre_action_accounting_required: bool,
    pub full_automated_check_row_still_required: bool,
    pub focused_proof_replaces_full_row: bool,
    pub metadata_only: bool,
    pub parser_dry_run_only: bool,
    pub xcode_command_executed: bool,
    pub product_code_changed: bool,
    pub selected_test_product_bytes_opened: u64,
    pub model_runtime_bytes_loaded: u64,
    pub app_runtime_bytes_loaded: u64,
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
    pub status: GraphFilterFocusedProofRootManifestStatus,
}

impl GraphFilterFocusedProofRootManifestGate {
    pub fn canonical() -> Self {
        Self {
            proof_root_prefix: "artifacts/xcode/graph-filter-visibility-test-products/".to_string(),
            manifest_name: "focused-proof-root-manifest.json".to_string(),
            required_manifest_fields: REQUIRED_MANIFEST_FIELDS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            selected_test_product_kinds: SELECTED_TEST_PRODUCT_KINDS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            minimum_executed_test_count: 1,
            source_status_digests_required: true,
            selected_product_digest_required: true,
            enumeration_digest_required: true,
            focused_result_bundle_digest_required: true,
            scheme_pre_action_accounting_required: true,
            full_automated_check_row_still_required: true,
            focused_proof_replaces_full_row: false,
            metadata_only: true,
            parser_dry_run_only: true,
            xcode_command_executed: false,
            product_code_changed: false,
            selected_test_product_bytes_opened: 0,
            model_runtime_bytes_loaded: 0,
            app_runtime_bytes_loaded: 0,
            raw_note_prompt_model_bytes_logged: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            release_ready_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            rollback_ref: "rollback:graph_filter_visibility_focused_proof_root_manifest_gate"
                .to_string(),
            run_event_log_ref:
                "run_event_log:graph_filter_visibility_focused_proof_root_manifest_gate".to_string(),
            answer_packet_ref:
                "answer_packet:graph_filter_visibility_focused_proof_root_manifest_gate".to_string(),
            status: GraphFilterFocusedProofRootManifestStatus::ParserContractOnly,
        }
    }

    pub fn validate(&self) -> Result<(), GraphFilterFocusedProofRootManifestGateError> {
        if self
            .proof_root_prefix
            .contains("~/Library/Developer/Xcode/DerivedData")
            || self
                .proof_root_prefix
                .contains("/Library/Developer/Xcode/DerivedData")
        {
            return Err(GraphFilterFocusedProofRootManifestGateError::GlobalDerivedDataPath);
        }
        validate_prefix(
            "proof_root_prefix",
            &self.proof_root_prefix,
            "artifacts/xcode/graph-filter-visibility-test-products/",
        )?;
        validate_exact(
            "manifest_name",
            &self.manifest_name,
            "focused-proof-root-manifest.json",
        )?;
        validate_unique_exact_set(
            "required_manifest_fields",
            &self.required_manifest_fields,
            &REQUIRED_MANIFEST_FIELDS,
        )?;
        validate_unique_exact_set(
            "selected_test_product_kinds",
            &self.selected_test_product_kinds,
            &SELECTED_TEST_PRODUCT_KINDS,
        )?;
        validate_unique_exact_set(
            "required_rejection_policies",
            &self.required_rejection_policies,
            &REQUIRED_REJECTION_POLICIES,
        )?;
        if self.minimum_executed_test_count == 0 {
            return Err(GraphFilterFocusedProofRootManifestGateError::ZeroExecutedTestPolicy);
        }
        if !self.source_status_digests_required
            || !self.selected_product_digest_required
            || !self.enumeration_digest_required
            || !self.focused_result_bundle_digest_required
            || !self.scheme_pre_action_accounting_required
            || !self.full_automated_check_row_still_required
            || self.focused_proof_replaces_full_row
        {
            return Err(GraphFilterFocusedProofRootManifestGateError::ProofBoundaryBroken);
        }
        if !self.metadata_only
            || !self.parser_dry_run_only
            || self.xcode_command_executed
            || self.product_code_changed
            || self.selected_test_product_bytes_opened != 0
            || self.model_runtime_bytes_loaded != 0
            || self.app_runtime_bytes_loaded != 0
            || self.raw_note_prompt_model_bytes_logged
        {
            return Err(GraphFilterFocusedProofRootManifestGateError::ByteOrMutationLeak);
        }
        if self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.release_ready_claimed
            || self.live_dense_70b_claimed
            || self.ssd_as_ram_claimed
        {
            return Err(GraphFilterFocusedProofRootManifestGateError::PromotionClaim);
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
// UAS: uas:graph-filter-visibility-focused-proof-root-manifest-gate:metrics
// Plane: Verification.
// Residency: gate counts and byte accounting.
pub struct GraphFilterFocusedProofRootManifestMetrics {
    pub required_manifest_field_count: usize,
    pub selected_test_product_kind_count: usize,
    pub required_rejection_policy_count: usize,
    pub minimum_executed_test_count: u64,
    pub selected_test_product_bytes_opened: u64,
    pub model_runtime_bytes_loaded: u64,
    pub app_runtime_bytes_loaded: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:graph-filter-visibility-focused-proof-root-manifest-gate:witness
// Plane: Verification + Controller.
// Residency: metadata-only manifest gate bound to the fresh evidence envelope.
pub struct GraphFilterVisibilityFocusedProofRootManifestGateWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_artifact_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_address: String,
    pub upstream_next_cursor: String,
    pub spec: GraphFilterFocusedProofRootManifestGate,
    pub metrics: GraphFilterFocusedProofRootManifestMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl GraphFilterVisibilityFocusedProofRootManifestGateWitness {
    pub fn new(
        upstream_overall_pass: bool,
        upstream_address: &str,
        upstream_next_cursor: &str,
    ) -> Result<Self, GraphFilterFocusedProofRootManifestGateError> {
        if !upstream_overall_pass {
            return Err(GraphFilterFocusedProofRootManifestGateError::UpstreamNotPassed);
        }
        validate_sha256_address("upstream_address", upstream_address)?;
        validate_exact(
            "upstream_next_cursor",
            upstream_next_cursor,
            GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_NEXT_CURSOR,
        )?;
        let spec = GraphFilterFocusedProofRootManifestGate::canonical();
        spec.validate()?;
        let metrics = GraphFilterFocusedProofRootManifestMetrics {
            required_manifest_field_count: spec.required_manifest_fields.len(),
            selected_test_product_kind_count: spec.selected_test_product_kinds.len(),
            required_rejection_policy_count: spec.required_rejection_policies.len(),
            minimum_executed_test_count: spec.minimum_executed_test_count,
            selected_test_product_bytes_opened: spec.selected_test_product_bytes_opened,
            model_runtime_bytes_loaded: spec.model_runtime_bytes_loaded,
            app_runtime_bytes_loaded: spec.app_runtime_bytes_loaded,
        };
        let address = graph_filter_focused_proof_root_manifest_gate_address(
            upstream_overall_pass,
            upstream_address,
            upstream_next_cursor,
            &spec,
            &metrics,
        );
        Ok(Self {
            falsifier_id: GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_ID.to_string(),
            cursor: GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_CURSOR.to_string(),
            next_cursor: GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_NEXT_CURSOR
                .to_string(),
            upstream_artifact_ref:
                GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_UPSTREAM_REF.to_string(),
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

    pub fn validate(&self) -> Result<(), GraphFilterFocusedProofRootManifestGateError> {
        if self.falsifier_id != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_ID
            || self.cursor != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_CURSOR
            || self.next_cursor
                != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_NEXT_CURSOR
            || self.upstream_artifact_ref
                != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_UPSTREAM_REF
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(GraphFilterFocusedProofRootManifestGateError::WitnessHeaderBroken);
        }
        let rebuilt = Self::new(
            self.upstream_overall_pass,
            &self.upstream_address,
            &self.upstream_next_cursor,
        )?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(GraphFilterFocusedProofRootManifestGateError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_graph_filter_focused_proof_root_manifest_fields() -> &'static [&'static str] {
    &REQUIRED_MANIFEST_FIELDS
}

pub fn required_graph_filter_focused_proof_root_selected_product_kinds() -> &'static [&'static str]
{
    &SELECTED_TEST_PRODUCT_KINDS
}

pub fn required_graph_filter_focused_proof_root_rejection_policies() -> &'static [&'static str] {
    &REQUIRED_REJECTION_POLICIES
}

fn graph_filter_focused_proof_root_manifest_gate_address(
    upstream_overall_pass: bool,
    upstream_address: &str,
    upstream_next_cursor: &str,
    spec: &GraphFilterFocusedProofRootManifestGate,
    metrics: &GraphFilterFocusedProofRootManifestMetrics,
) -> String {
    let payload = serde_json::json!({
        "id": GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_ID,
        "upstream_overall_pass": upstream_overall_pass,
        "upstream_address": upstream_address,
        "upstream_next_cursor": upstream_next_cursor,
        "spec": spec,
        "metrics": metrics,
    });
    sha256_hex(payload.to_string().as_bytes())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:graph-filter-visibility-focused-proof-root-manifest-gate:error
// Plane: Verification.
// Residency: fail-closed manifest-gate rejection taxonomy.
pub enum GraphFilterFocusedProofRootManifestGateError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    WrongValue(&'static str),
    DuplicateField(String),
    MissingRequiredField(&'static str),
    GlobalDerivedDataPath,
    ZeroExecutedTestPolicy,
    ProofBoundaryBroken,
    ByteOrMutationLeak,
    PromotionClaim,
    UpstreamNotPassed,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for GraphFilterFocusedProofRootManifestGateError {
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
            Self::ByteOrMutationLeak => write!(f, "byte or mutation leak"),
            Self::PromotionClaim => write!(f, "promotion claim attempted"),
            Self::UpstreamNotPassed => write!(f, "upstream evidence envelope not passed"),
            Self::WitnessHeaderBroken => write!(f, "witness header broken"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for GraphFilterFocusedProofRootManifestGateError {}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), GraphFilterFocusedProofRootManifestGateError> {
    validate_token(field, value)?;
    if value != expected {
        return Err(GraphFilterFocusedProofRootManifestGateError::WrongValue(
            field,
        ));
    }
    Ok(())
}

fn validate_prefix(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), GraphFilterFocusedProofRootManifestGateError> {
    validate_token(field, value)?;
    if !value.starts_with(prefix) {
        return Err(GraphFilterFocusedProofRootManifestGateError::WrongValue(
            field,
        ));
    }
    Ok(())
}

fn validate_sha256_address(
    field: &'static str,
    value: &str,
) -> Result<(), GraphFilterFocusedProofRootManifestGateError> {
    validate_token(field, value)?;
    if !value.starts_with("sha256:") || value.len() != 71 {
        return Err(GraphFilterFocusedProofRootManifestGateError::WrongValue(
            field,
        ));
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), GraphFilterFocusedProofRootManifestGateError> {
    if value.is_empty() {
        return Err(GraphFilterFocusedProofRootManifestGateError::MissingField(
            field,
        ));
    }
    if value.trim() != value {
        return Err(
            GraphFilterFocusedProofRootManifestGateError::FieldHasSurroundingWhitespace(field),
        );
    }
    if value.chars().any(char::is_control) {
        return Err(
            GraphFilterFocusedProofRootManifestGateError::FieldContainsControlCharacter(field),
        );
    }
    Ok(())
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    expected: &[&'static str],
) -> Result<(), GraphFilterFocusedProofRootManifestGateError> {
    if values.is_empty() {
        return Err(GraphFilterFocusedProofRootManifestGateError::MissingField(
            field,
        ));
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_token(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(
                GraphFilterFocusedProofRootManifestGateError::DuplicateField(value.clone()),
            );
        }
    }
    for required in expected {
        if !seen.contains(required) {
            return Err(
                GraphFilterFocusedProofRootManifestGateError::MissingRequiredField(required),
            );
        }
    }
    if seen.len() != expected.len() {
        return Err(GraphFilterFocusedProofRootManifestGateError::WrongValue(
            field,
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    const UPSTREAM_ADDRESS: &str =
        "sha256:5c24af9bc099863d5dba8398403175f2642caf45201e2ec8169042c2b26ac49f";

    #[test]
    fn canonical_gate_validates() {
        GraphFilterFocusedProofRootManifestGate::canonical()
            .validate()
            .expect("canonical gate should validate");
    }

    #[test]
    fn witness_is_deterministic() {
        let first = GraphFilterVisibilityFocusedProofRootManifestGateWitness::new(
            true,
            UPSTREAM_ADDRESS,
            GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_NEXT_CURSOR,
        )
        .expect("valid witness");
        let second = GraphFilterVisibilityFocusedProofRootManifestGateWitness::new(
            true,
            UPSTREAM_ADDRESS,
            GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_NEXT_CURSOR,
        )
        .expect("valid witness");
        assert_eq!(first.address, second.address);
        assert_eq!(first.metrics.required_manifest_field_count, 13);
        assert_eq!(first.metrics.minimum_executed_test_count, 1);
    }

    #[test]
    fn rejects_zero_executed_test_policy() {
        let mut gate = GraphFilterFocusedProofRootManifestGate::canonical();
        gate.minimum_executed_test_count = 0;
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootManifestGateError::ZeroExecutedTestPolicy
        );
    }

    #[test]
    fn rejects_global_derived_data_path() {
        let mut gate = GraphFilterFocusedProofRootManifestGate::canonical();
        gate.proof_root_prefix = "~/Library/Developer/Xcode/DerivedData/graph-filter/".to_string();
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootManifestGateError::GlobalDerivedDataPath
        );
    }

    #[test]
    fn rejects_focused_proof_as_full_row() {
        let mut gate = GraphFilterFocusedProofRootManifestGate::canonical();
        gate.focused_proof_replaces_full_row = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootManifestGateError::ProofBoundaryBroken
        );
    }

    #[test]
    fn rejects_byte_leaks() {
        let mut gate = GraphFilterFocusedProofRootManifestGate::canonical();
        gate.selected_test_product_bytes_opened = 1;
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootManifestGateError::ByteOrMutationLeak
        );
    }

    #[test]
    fn rejects_release_claims() {
        let mut gate = GraphFilterFocusedProofRootManifestGate::canonical();
        gate.release_ready_claimed = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootManifestGateError::PromotionClaim
        );
    }

    #[test]
    fn rejects_bad_upstream() {
        assert_eq!(
            GraphFilterVisibilityFocusedProofRootManifestGateWitness::new(
                false,
                UPSTREAM_ADDRESS,
                GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_MANIFEST_GATE_NEXT_CURSOR,
            )
            .unwrap_err(),
            GraphFilterFocusedProofRootManifestGateError::UpstreamNotPassed
        );
    }
}
