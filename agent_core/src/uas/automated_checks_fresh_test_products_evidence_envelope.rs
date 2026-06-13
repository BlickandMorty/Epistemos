use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_ID: &str =
    "F-AutomatedChecksFreshTestProductsEvidenceEnvelope";
pub const AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_CURSOR: &str =
    "automated_checks_fresh_test_products_evidence_envelope";
pub const AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";
pub const COMMAND_SPEC_REF: &str = "artifact:falsifiers/graph_filter_visibility_test_products_command_spec/result.json#F-GraphFilterVisibilityTestProductsCommandSpec";
pub const AUTOMATED_CHECKS_REF: &str = "artifact:falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/result.json#F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditAutomatedChecksProbe";

const REQUIRED_DIGEST_FIELDS: [&str; 8] = [
    "source_commit_sha",
    "pre_build_status_digest",
    "post_test_status_digest",
    "selected_test_product_digest",
    "enumeration_json_digest",
    "seed_selector_digest",
    "enumerated_selector_digest",
    "focused_result_bundle_digest",
];

const REQUIRED_REJECTION_POLICIES: [&str; 14] = [
    "missing_command_spec_artifact",
    "failed_command_spec_artifact",
    "proof_root_outside_artifacts",
    "global_derived_data",
    "different_commit_product",
    "missing_selected_product_digest",
    "missing_or_stale_enumeration_json",
    "missing_or_stale_focused_result_bundle",
    "selector_digest_mismatch",
    "filename_selector_or_display_name_laundering",
    "zero_executed_tests",
    "unaccounted_pre_action_mutation",
    "focused_proof_replaces_full_automated_checks",
    "raw_note_prompt_model_byte_logging",
];

const REQUIRED_PROOF_SURFACES: [&str; 3] = ["rollback", "run_event_log", "answer_packet"];

const SELECTED_TEST_PRODUCT_KINDS: [&str; 2] = ["xctestrun", "xctestproducts"];

// UAS: uas:automated-checks-fresh-test-products-evidence-envelope:organ
// Plane: Verification.
// Residency: metadata-only release-audit evidence envelope.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AutomatedChecksFreshTestProductsOrgan {
    ReleaseAuditEvidenceEnvelope,
}

// UAS: uas:automated-checks-fresh-test-products-evidence-envelope:status
// Plane: Verification.
// Residency: metadata contract only; no Xcode or runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AutomatedChecksFreshTestProductsStatus {
    MetadataEnvelopeSpecOnly,
}

// UAS: uas:automated-checks-fresh-test-products-evidence-envelope:spec
// Plane: Verification.
// Residency: future proof-root contract; no test product opened.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AutomatedChecksFreshTestProductsEvidenceEnvelope {
    pub command_spec_artifact_ref: String,
    pub automated_checks_artifact_ref: String,
    pub proof_root_prefix: String,
    pub selected_test_product_kinds: Vec<String>,
    pub required_digest_fields: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub required_proof_surfaces: Vec<String>,
    pub scheme_pre_action_title: String,
    pub scheme_pre_action_script: String,
    pub required_before_family: String,
    pub required_after_family_status: String,
    pub minimum_executed_test_count: u64,
    pub full_automated_check_row_still_required: bool,
    pub focused_proof_replaces_full_automated_checks: bool,
    pub metadata_only: bool,
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
    pub organ: AutomatedChecksFreshTestProductsOrgan,
    pub status: AutomatedChecksFreshTestProductsStatus,
}

impl AutomatedChecksFreshTestProductsEvidenceEnvelope {
    pub fn canonical() -> Self {
        Self {
            command_spec_artifact_ref: COMMAND_SPEC_REF.to_string(),
            automated_checks_artifact_ref: AUTOMATED_CHECKS_REF.to_string(),
            proof_root_prefix: "artifacts/xcode/graph-filter-visibility-test-products/".to_string(),
            selected_test_product_kinds: SELECTED_TEST_PRODUCT_KINDS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_digest_fields: REQUIRED_DIGEST_FIELDS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_proof_surfaces: REQUIRED_PROOF_SURFACES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            scheme_pre_action_title: "Patch MLX Metal Warning".to_string(),
            scheme_pre_action_script: "scripts/patch_mlx_metal_warnings.sh".to_string(),
            required_before_family: "graph_filter_visibility".to_string(),
            required_after_family_status: "pending_fresh_proof".to_string(),
            minimum_executed_test_count: 1,
            full_automated_check_row_still_required: true,
            focused_proof_replaces_full_automated_checks: false,
            metadata_only: true,
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
            rollback_ref: "rollback:automated_checks_fresh_test_products_evidence_envelope"
                .to_string(),
            run_event_log_ref:
                "run_event_log:automated_checks_fresh_test_products_evidence_envelope".to_string(),
            answer_packet_ref:
                "answer_packet:automated_checks_fresh_test_products_evidence_envelope".to_string(),
            organ: AutomatedChecksFreshTestProductsOrgan::ReleaseAuditEvidenceEnvelope,
            status: AutomatedChecksFreshTestProductsStatus::MetadataEnvelopeSpecOnly,
        }
    }

    pub fn validate(&self) -> Result<(), AutomatedChecksFreshTestProductsError> {
        validate_ref(
            "command_spec_artifact_ref",
            &self.command_spec_artifact_ref,
            "artifact:falsifiers/graph_filter_visibility_test_products_command_spec/",
            "#F-GraphFilterVisibilityTestProductsCommandSpec",
        )?;
        validate_ref(
            "automated_checks_artifact_ref",
            &self.automated_checks_artifact_ref,
            "artifact:falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/",
            "#F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditAutomatedChecksProbe",
        )?;
        if self
            .proof_root_prefix
            .contains("~/Library/Developer/Xcode/DerivedData")
            || self
                .proof_root_prefix
                .contains("/Library/Developer/Xcode/DerivedData")
        {
            return Err(AutomatedChecksFreshTestProductsError::GlobalDerivedDataPath);
        }
        validate_prefix(
            "proof_root_prefix",
            &self.proof_root_prefix,
            "artifacts/xcode/graph-filter-visibility-test-products/",
        )?;
        validate_unique_exact_set(
            "selected_test_product_kinds",
            &self.selected_test_product_kinds,
            &SELECTED_TEST_PRODUCT_KINDS,
        )?;
        validate_unique_exact_set(
            "required_digest_fields",
            &self.required_digest_fields,
            &REQUIRED_DIGEST_FIELDS,
        )?;
        validate_unique_exact_set(
            "required_rejection_policies",
            &self.required_rejection_policies,
            &REQUIRED_REJECTION_POLICIES,
        )?;
        validate_unique_exact_set(
            "required_proof_surfaces",
            &self.required_proof_surfaces,
            &REQUIRED_PROOF_SURFACES,
        )?;
        validate_exact(
            "scheme_pre_action_title",
            &self.scheme_pre_action_title,
            "Patch MLX Metal Warning",
        )?;
        validate_exact(
            "scheme_pre_action_script",
            &self.scheme_pre_action_script,
            "scripts/patch_mlx_metal_warnings.sh",
        )?;
        validate_exact(
            "required_before_family",
            &self.required_before_family,
            "graph_filter_visibility",
        )?;
        validate_exact(
            "required_after_family_status",
            &self.required_after_family_status,
            "pending_fresh_proof",
        )?;
        if self.minimum_executed_test_count == 0 {
            return Err(AutomatedChecksFreshTestProductsError::ZeroExecutedTestsAllowed);
        }
        if !self.full_automated_check_row_still_required
            || self.focused_proof_replaces_full_automated_checks
        {
            return Err(AutomatedChecksFreshTestProductsError::AutomatedRowBoundaryBroken);
        }
        if self.organ != AutomatedChecksFreshTestProductsOrgan::ReleaseAuditEvidenceEnvelope
            || self.status != AutomatedChecksFreshTestProductsStatus::MetadataEnvelopeSpecOnly
            || !self.metadata_only
            || self.xcode_command_executed
            || self.product_code_changed
            || self.selected_test_product_bytes_opened != 0
            || self.model_runtime_bytes_loaded != 0
            || self.app_runtime_bytes_loaded != 0
        {
            return Err(AutomatedChecksFreshTestProductsError::ExecutionBoundaryBroken);
        }
        if self.raw_note_prompt_model_bytes_logged
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.release_ready_claimed
            || self.live_dense_70b_claimed
            || self.ssd_as_ram_claimed
        {
            return Err(AutomatedChecksFreshTestProductsError::PromotionBoundaryBroken);
        }
        for value in [
            &self.rollback_ref,
            &self.run_event_log_ref,
            &self.answer_packet_ref,
        ] {
            validate_token("proof_ref", value)?;
        }
        Ok(())
    }
}

// UAS: uas:automated-checks-fresh-test-products-evidence-envelope:metrics
// Plane: Verification.
// Residency: metadata counts for the envelope contract.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AutomatedChecksFreshTestProductsMetrics {
    pub selected_test_product_kind_count: usize,
    pub required_digest_field_count: usize,
    pub required_rejection_policy_count: usize,
    pub required_proof_surface_count: usize,
    pub minimum_executed_test_count: u64,
    pub selected_test_product_bytes_opened: u64,
    pub model_runtime_bytes_loaded: u64,
    pub app_runtime_bytes_loaded: u64,
}

// UAS: uas:automated-checks-fresh-test-products-evidence-envelope:witness
// Plane: Verification.
// Residency: metadata-only witness for future fresh proof-root evidence.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub command_spec_artifact_ref: String,
    pub command_spec_overall_pass: bool,
    pub command_spec_address: String,
    pub command_spec_seed_selector_count: u64,
    pub command_spec_command_template_count: u64,
    pub automated_checks_artifact_ref: String,
    pub automated_checks_overall_pass: bool,
    pub automated_checks_next_bottleneck: String,
    pub automated_checks_top_failure_family: String,
    pub automated_checks_xcodebuild_test_passed: bool,
    pub spec: AutomatedChecksFreshTestProductsEvidenceEnvelope,
    pub metrics: AutomatedChecksFreshTestProductsMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness {
    pub fn new(
        command_spec_overall_pass: bool,
        command_spec_address: &str,
        command_spec_seed_selector_count: u64,
        command_spec_command_template_count: u64,
        automated_checks_overall_pass: bool,
        automated_checks_next_bottleneck: &str,
        automated_checks_top_failure_family: &str,
        automated_checks_xcodebuild_test_passed: bool,
    ) -> Result<Self, AutomatedChecksFreshTestProductsError> {
        if !command_spec_overall_pass {
            return Err(AutomatedChecksFreshTestProductsError::CommandSpecNotPassed);
        }
        validate_token("command_spec_address", command_spec_address)?;
        if !command_spec_address.starts_with("sha256:")
            || command_spec_address.len() != 71
            || command_spec_seed_selector_count != 8
            || command_spec_command_template_count != 3
        {
            return Err(AutomatedChecksFreshTestProductsError::CommandSpecArtifactUnbound);
        }
        if automated_checks_overall_pass || automated_checks_xcodebuild_test_passed {
            return Err(AutomatedChecksFreshTestProductsError::AutomatedChecksNotRed);
        }
        validate_exact(
            "automated_checks_next_bottleneck",
            automated_checks_next_bottleneck,
            AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR,
        )?;
        validate_exact(
            "automated_checks_top_failure_family",
            automated_checks_top_failure_family,
            "graph_filter_visibility",
        )?;
        let spec = AutomatedChecksFreshTestProductsEvidenceEnvelope::canonical();
        spec.validate()?;
        let metrics = AutomatedChecksFreshTestProductsMetrics {
            selected_test_product_kind_count: spec.selected_test_product_kinds.len(),
            required_digest_field_count: spec.required_digest_fields.len(),
            required_rejection_policy_count: spec.required_rejection_policies.len(),
            required_proof_surface_count: spec.required_proof_surfaces.len(),
            minimum_executed_test_count: spec.minimum_executed_test_count,
            selected_test_product_bytes_opened: spec.selected_test_product_bytes_opened,
            model_runtime_bytes_loaded: spec.model_runtime_bytes_loaded,
            app_runtime_bytes_loaded: spec.app_runtime_bytes_loaded,
        };
        let address = automated_checks_fresh_test_products_address(
            command_spec_overall_pass,
            command_spec_address,
            command_spec_seed_selector_count,
            command_spec_command_template_count,
            automated_checks_overall_pass,
            automated_checks_next_bottleneck,
            automated_checks_top_failure_family,
            automated_checks_xcodebuild_test_passed,
            &spec,
            &metrics,
        );
        Ok(Self {
            falsifier_id: AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_ID.to_string(),
            cursor: AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_CURSOR.to_string(),
            next_cursor: AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR
                .to_string(),
            command_spec_artifact_ref: COMMAND_SPEC_REF.to_string(),
            command_spec_overall_pass,
            command_spec_address: command_spec_address.to_string(),
            command_spec_seed_selector_count,
            command_spec_command_template_count,
            automated_checks_artifact_ref: AUTOMATED_CHECKS_REF.to_string(),
            automated_checks_overall_pass,
            automated_checks_next_bottleneck: automated_checks_next_bottleneck.to_string(),
            automated_checks_top_failure_family: automated_checks_top_failure_family.to_string(),
            automated_checks_xcodebuild_test_passed,
            spec,
            metrics,
            address,
            metadata_only: true,
            no_product_promotion: true,
        })
    }

    pub fn validate(&self) -> Result<(), AutomatedChecksFreshTestProductsError> {
        if self.falsifier_id != AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_ID
            || self.cursor != AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_CURSOR
            || self.next_cursor
                != AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR
            || self.command_spec_artifact_ref != COMMAND_SPEC_REF
            || self.automated_checks_artifact_ref != AUTOMATED_CHECKS_REF
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(AutomatedChecksFreshTestProductsError::WitnessHeaderBroken);
        }
        let rebuilt = Self::new(
            self.command_spec_overall_pass,
            &self.command_spec_address,
            self.command_spec_seed_selector_count,
            self.command_spec_command_template_count,
            self.automated_checks_overall_pass,
            &self.automated_checks_next_bottleneck,
            &self.automated_checks_top_failure_family,
            self.automated_checks_xcodebuild_test_passed,
        )?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(AutomatedChecksFreshTestProductsError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_automated_checks_fresh_test_products_digest_fields() -> &'static [&'static str] {
    &REQUIRED_DIGEST_FIELDS
}

pub fn required_automated_checks_fresh_test_products_rejection_policies() -> &'static [&'static str]
{
    &REQUIRED_REJECTION_POLICIES
}

pub fn required_automated_checks_fresh_test_products_proof_surfaces() -> &'static [&'static str] {
    &REQUIRED_PROOF_SURFACES
}

fn automated_checks_fresh_test_products_address(
    command_spec_overall_pass: bool,
    command_spec_address: &str,
    command_spec_seed_selector_count: u64,
    command_spec_command_template_count: u64,
    automated_checks_overall_pass: bool,
    automated_checks_next_bottleneck: &str,
    automated_checks_top_failure_family: &str,
    automated_checks_xcodebuild_test_passed: bool,
    spec: &AutomatedChecksFreshTestProductsEvidenceEnvelope,
    metrics: &AutomatedChecksFreshTestProductsMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_ID);
    preimage.push_str(AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_CURSOR);
    preimage.push_str(AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR);
    preimage.push_str(&command_spec_overall_pass.to_string());
    preimage.push_str(command_spec_address);
    preimage.push_str(&command_spec_seed_selector_count.to_string());
    preimage.push_str(&command_spec_command_template_count.to_string());
    preimage.push_str(&automated_checks_overall_pass.to_string());
    preimage.push_str(automated_checks_next_bottleneck);
    preimage.push_str(automated_checks_top_failure_family);
    preimage.push_str(&automated_checks_xcodebuild_test_passed.to_string());
    preimage.push_str(&spec.proof_root_prefix);
    for field in &spec.required_digest_fields {
        preimage.push_str(field);
    }
    for policy in &spec.required_rejection_policies {
        preimage.push_str(policy);
    }
    for surface in &spec.required_proof_surfaces {
        preimage.push_str(surface);
    }
    preimage.push_str(&format!("{metrics:?}"));
    sha256_hex(preimage.as_bytes())
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    required: &[&'static str],
) -> Result<(), AutomatedChecksFreshTestProductsError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(AutomatedChecksFreshTestProductsError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(AutomatedChecksFreshTestProductsError::MissingRequiredSet {
            field,
            actual: values.len(),
            expected: required.len(),
        });
    }
    Ok(())
}

fn validate_ref(
    field: &'static str,
    value: &str,
    prefix: &str,
    suffix: &str,
) -> Result<(), AutomatedChecksFreshTestProductsError> {
    validate_token(field, value)?;
    if !value.starts_with(prefix) || !value.ends_with(suffix) || !value.contains("/result.json#") {
        return Err(AutomatedChecksFreshTestProductsError::BadArtifactRef {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), AutomatedChecksFreshTestProductsError> {
    validate_text(field, value)?;
    if value != expected {
        return Err(AutomatedChecksFreshTestProductsError::UnexpectedValue {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_prefix(
    field: &'static str,
    value: &str,
    expected_prefix: &str,
) -> Result<(), AutomatedChecksFreshTestProductsError> {
    validate_text(field, value)?;
    if !value.starts_with(expected_prefix) {
        return Err(AutomatedChecksFreshTestProductsError::UnexpectedValue {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), AutomatedChecksFreshTestProductsError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(AutomatedChecksFreshTestProductsError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(
    field: &'static str,
    value: &str,
) -> Result<(), AutomatedChecksFreshTestProductsError> {
    if value.trim().is_empty()
        || value.len() > 768
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(AutomatedChecksFreshTestProductsError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: F-AutomatedChecksFreshTestProductsEvidenceEnvelope validation error taxonomy.
// Plane: Verification.
// Residency: metadata-only validation contract; no product/test bytes are loaded.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum AutomatedChecksFreshTestProductsError {
    InvalidToken {
        field: &'static str,
        value: String,
    },
    InvalidText {
        field: &'static str,
        value: String,
    },
    UnexpectedValue {
        field: &'static str,
        value: String,
    },
    DuplicateValue {
        field: &'static str,
        value: String,
    },
    MissingRequiredSet {
        field: &'static str,
        actual: usize,
        expected: usize,
    },
    BadArtifactRef {
        field: &'static str,
        value: String,
    },
    GlobalDerivedDataPath,
    ZeroExecutedTestsAllowed,
    AutomatedRowBoundaryBroken,
    ExecutionBoundaryBroken,
    PromotionBoundaryBroken,
    CommandSpecNotPassed,
    CommandSpecArtifactUnbound,
    AutomatedChecksNotRed,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for AutomatedChecksFreshTestProductsError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidToken { field, value } => {
                write!(formatter, "invalid token {field}: {value}")
            }
            Self::InvalidText { field, value } => {
                write!(formatter, "invalid text {field}: {value}")
            }
            Self::UnexpectedValue { field, value } => {
                write!(formatter, "unexpected value {field}: {value}")
            }
            Self::DuplicateValue { field, value } => {
                write!(formatter, "duplicate value {field}: {value}")
            }
            Self::MissingRequiredSet {
                field,
                actual,
                expected,
            } => write!(
                formatter,
                "missing required set {field}: actual {actual}, expected {expected}"
            ),
            Self::BadArtifactRef { field, value } => {
                write!(formatter, "bad artifact ref {field}: {value}")
            }
            Self::GlobalDerivedDataPath => write!(formatter, "global DerivedData path rejected"),
            Self::ZeroExecutedTestsAllowed => write!(formatter, "zero executed tests allowed"),
            Self::AutomatedRowBoundaryBroken => {
                write!(formatter, "automated-check row boundary broken")
            }
            Self::ExecutionBoundaryBroken => write!(formatter, "execution boundary broken"),
            Self::PromotionBoundaryBroken => write!(formatter, "promotion boundary broken"),
            Self::CommandSpecNotPassed => write!(formatter, "command spec artifact not passed"),
            Self::CommandSpecArtifactUnbound => {
                write!(
                    formatter,
                    "command spec artifact address/counts are unbound"
                )
            }
            Self::AutomatedChecksNotRed => write!(formatter, "automated checks artifact not red"),
            Self::WitnessHeaderBroken => write!(formatter, "witness header broken"),
            Self::WitnessDigestMismatch => write!(formatter, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for AutomatedChecksFreshTestProductsError {}

#[cfg(test)]
mod tests {
    use super::*;

    const TEST_COMMAND_SPEC_ADDRESS: &str =
        "sha256:564e14b81e59faf790c4da0e8f93792a4a5a1ba68c89f8d51153a2c595bd94f9";

    #[test]
    fn canonical_envelope_validates() {
        let spec = AutomatedChecksFreshTestProductsEvidenceEnvelope::canonical();
        assert!(spec.validate().is_ok());
        assert_eq!(
            spec.required_digest_fields.len(),
            REQUIRED_DIGEST_FIELDS.len()
        );
        assert_eq!(
            spec.required_rejection_policies.len(),
            REQUIRED_REJECTION_POLICIES.len()
        );
    }

    #[test]
    fn rejects_global_derived_data() {
        let mut spec = AutomatedChecksFreshTestProductsEvidenceEnvelope::canonical();
        spec.proof_root_prefix = "~/Library/Developer/Xcode/DerivedData/Epistemos".to_string();
        assert_eq!(
            spec.validate(),
            Err(AutomatedChecksFreshTestProductsError::GlobalDerivedDataPath)
        );
    }

    #[test]
    fn rejects_missing_digest_field() {
        let mut spec = AutomatedChecksFreshTestProductsEvidenceEnvelope::canonical();
        spec.required_digest_fields.pop();
        assert!(matches!(
            spec.validate(),
            Err(AutomatedChecksFreshTestProductsError::MissingRequiredSet { .. })
        ));
    }

    #[test]
    fn rejects_zero_tests_and_full_row_replacement() {
        let mut spec = AutomatedChecksFreshTestProductsEvidenceEnvelope::canonical();
        spec.minimum_executed_test_count = 0;
        assert_eq!(
            spec.validate(),
            Err(AutomatedChecksFreshTestProductsError::ZeroExecutedTestsAllowed)
        );

        let mut spec = AutomatedChecksFreshTestProductsEvidenceEnvelope::canonical();
        spec.focused_proof_replaces_full_automated_checks = true;
        assert_eq!(
            spec.validate(),
            Err(AutomatedChecksFreshTestProductsError::AutomatedRowBoundaryBroken)
        );
    }

    #[test]
    fn rejects_execution_or_promotion_claims() {
        let mut spec = AutomatedChecksFreshTestProductsEvidenceEnvelope::canonical();
        spec.xcode_command_executed = true;
        assert_eq!(
            spec.validate(),
            Err(AutomatedChecksFreshTestProductsError::ExecutionBoundaryBroken)
        );

        let mut spec = AutomatedChecksFreshTestProductsEvidenceEnvelope::canonical();
        spec.release_ready_claimed = true;
        assert_eq!(
            spec.validate(),
            Err(AutomatedChecksFreshTestProductsError::PromotionBoundaryBroken)
        );
    }

    #[test]
    fn witness_requires_red_automated_checks_and_is_deterministic() {
        let witness = AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness::new(
            true,
            TEST_COMMAND_SPEC_ADDRESS,
            8,
            3,
            false,
            AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR,
            "graph_filter_visibility",
            false,
        )
        .unwrap();
        assert!(witness.validate().is_ok());

        let rebuilt = AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness::new(
            true,
            TEST_COMMAND_SPEC_ADDRESS,
            8,
            3,
            false,
            AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR,
            "graph_filter_visibility",
            false,
        )
        .unwrap();
        assert_eq!(witness.address, rebuilt.address);

        assert_eq!(
            AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness::new(
                false,
                TEST_COMMAND_SPEC_ADDRESS,
                8,
                3,
                false,
                AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR,
                "graph_filter_visibility",
                false,
            ),
            Err(AutomatedChecksFreshTestProductsError::CommandSpecNotPassed)
        );
        assert_eq!(
            AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness::new(
                true,
                TEST_COMMAND_SPEC_ADDRESS,
                8,
                3,
                true,
                AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR,
                "graph_filter_visibility",
                false,
            ),
            Err(AutomatedChecksFreshTestProductsError::AutomatedChecksNotRed)
        );
        assert_eq!(
            AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness::new(
                true,
                "",
                8,
                3,
                false,
                AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR,
                "graph_filter_visibility",
                false,
            ),
            Err(AutomatedChecksFreshTestProductsError::InvalidToken {
                field: "command_spec_address",
                value: String::new(),
            })
        );
        assert_eq!(
            AutomatedChecksFreshTestProductsEvidenceEnvelopeWitness::new(
                true,
                TEST_COMMAND_SPEC_ADDRESS,
                7,
                3,
                false,
                AUTOMATED_CHECKS_FRESH_TEST_PRODUCTS_EVIDENCE_ENVELOPE_NEXT_CURSOR,
                "graph_filter_visibility",
                false,
            ),
            Err(AutomatedChecksFreshTestProductsError::CommandSpecArtifactUnbound)
        );
    }
}
