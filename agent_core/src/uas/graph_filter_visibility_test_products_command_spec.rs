use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_ID: &str =
    "F-GraphFilterVisibilityTestProductsCommandSpec";
pub const GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_CURSOR: &str =
    "graph_filter_visibility_test_products_command_spec";
pub const GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";
pub const GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_UPSTREAM_REF: &str = "artifact:falsifiers/graph_filter_visibility_focused_identifier_proof/result.json#F-GraphFilterVisibilityFocusedIdentifierProof";
pub const GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_UPSTREAM_NEXT_CURSOR: &str =
    "graph_filter_visibility_test_products_command_spec";

const REQUIRED_SOURCE_REFS: [&str; 5] = [
    "Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme",
    "EpistemosTests/FilterEngineComprehensiveTests.swift",
    "EpistemosTests/ResourceExhaustionTests.swift",
    "EpistemosTests/ConcurrencyEdgeCaseTests.swift",
    "EpistemosTests/VaultLifecycleResetTests.swift",
];

const REQUIRED_SEED_SELECTORS: [&str; 8] = [
    "EpistemosTests/FilterEngineNodeVisibilityTests/isNodeVisibleForAllTypes",
    "EpistemosTests/FilterEngineTypeFilterSpecificTests/allSevenTypesCanBeToggled",
    "EpistemosTests/FilterEngineTypeFilterSpecificTests/visibilityForEachType",
    "EpistemosTests/FilterEngineComplexScenarioTests/realisticFilteringScenario",
    "EpistemosTests/ResourceEdgeCaseTests/filterAllTypesActive",
    "EpistemosTests/ConcurrencyFilterEngineTests/rapidTypeToggling",
    "EpistemosTests/ConcurrencyFilterEngineTests/allTypesVisibleByDefault",
    "EpistemosTests/VaultLifecycleResetTests/graphLifecycleResetClearsVisibleStoreAndQueues",
];

const REQUIRED_COMMAND_TEMPLATES: [&str; 3] = [
    "xcodebuild build-for-testing -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination platform=macOS -derivedDataPath $PROOF_ROOT/DerivedData -resultBundlePath $PROOF_ROOT/build-for-testing.xcresult",
    "xcodebuild test-without-building -xctestrun $SELECTED_TEST_PRODUCT -destination platform=macOS -enumerate-tests -test-enumeration-format json -test-enumeration-output-path $PROOF_ROOT/enumerated-tests.json",
    "xcodebuild test-without-building -xctestrun $SELECTED_TEST_PRODUCT -destination platform=macOS -only-testing:<seed-selectors> -resultBundlePath $PROOF_ROOT/focused-graph-filter.xcresult",
];

// UAS: uas:graph-filter-visibility-test-products-command-spec:organ
// Plane: Verification.
// Residency: metadata-only test-products proof command specification.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GraphFilterTestProductsOrgan {
    ReleaseAuditVerification,
}

// UAS: uas:graph-filter-visibility-test-products-command-spec:status
// Plane: Verification.
// Residency: command spec only; no Xcode products or runtime bytes.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GraphFilterTestProductsStatus {
    MetadataCommandSpecOnly,
}

// UAS: uas:graph-filter-visibility-test-products-command-spec:spec
// Plane: Verification.
// Residency: metadata-only command/source card; no Xcode execution.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterVisibilityTestProductsCommandSpec {
    pub scheme_path: String,
    pub scheme_name: String,
    pub configuration: String,
    pub destination: String,
    pub testable_name: String,
    pub proof_root_template: String,
    pub derived_data_path_template: String,
    pub build_result_bundle_name: String,
    pub enumeration_json_name: String,
    pub focused_result_bundle_name: String,
    pub scheme_pre_action_title: String,
    pub scheme_pre_action_script: String,
    pub source_refs: Vec<String>,
    pub seed_selectors: Vec<String>,
    pub command_templates: Vec<String>,
    pub organ: GraphFilterTestProductsOrgan,
    pub status: GraphFilterTestProductsStatus,
    pub metadata_only: bool,
    pub xcode_command_executed: bool,
    pub product_code_changed: bool,
    pub selected_test_product_bytes_opened: u64,
    pub model_runtime_bytes_loaded: u64,
    pub app_runtime_bytes_loaded: u64,
    pub rejects_global_derived_data: bool,
    pub rejects_different_commit_products: bool,
    pub rejects_stale_result_bundle: bool,
    pub rejects_selector_mismatch: bool,
    pub rejects_filename_selector: bool,
    pub rejects_enumeration_only_pass: bool,
    pub rejects_zero_executed_tests: bool,
    pub rejects_pre_action_mutation: bool,
    pub full_automated_check_row_still_required: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub release_ready_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub raw_note_prompt_model_bytes_logged: bool,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl GraphFilterVisibilityTestProductsCommandSpec {
    pub fn canonical() -> Self {
        Self {
            scheme_path: "Epistemos.xcodeproj/xcshareddata/xcschemes/Epistemos.xcscheme"
                .to_string(),
            scheme_name: "Epistemos".to_string(),
            configuration: "Debug".to_string(),
            destination: "platform=macOS".to_string(),
            testable_name: "EpistemosTests.xctest".to_string(),
            proof_root_template: "artifacts/xcode/graph-filter-visibility-test-products/$STAMP"
                .to_string(),
            derived_data_path_template: "$PROOF_ROOT/DerivedData".to_string(),
            build_result_bundle_name: "build-for-testing.xcresult".to_string(),
            enumeration_json_name: "enumerated-tests.json".to_string(),
            focused_result_bundle_name: "focused-graph-filter.xcresult".to_string(),
            scheme_pre_action_title: "Patch MLX Metal Warning".to_string(),
            scheme_pre_action_script: "scripts/patch_mlx_metal_warnings.sh".to_string(),
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            seed_selectors: REQUIRED_SEED_SELECTORS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            command_templates: REQUIRED_COMMAND_TEMPLATES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            organ: GraphFilterTestProductsOrgan::ReleaseAuditVerification,
            status: GraphFilterTestProductsStatus::MetadataCommandSpecOnly,
            metadata_only: true,
            xcode_command_executed: false,
            product_code_changed: false,
            selected_test_product_bytes_opened: 0,
            model_runtime_bytes_loaded: 0,
            app_runtime_bytes_loaded: 0,
            rejects_global_derived_data: true,
            rejects_different_commit_products: true,
            rejects_stale_result_bundle: true,
            rejects_selector_mismatch: true,
            rejects_filename_selector: true,
            rejects_enumeration_only_pass: true,
            rejects_zero_executed_tests: true,
            rejects_pre_action_mutation: true,
            full_automated_check_row_still_required: true,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            release_ready_claimed: false,
            live_dense_70b_claimed: false,
            raw_note_prompt_model_bytes_logged: false,
            rollback_ref: "rollback:graph_filter_visibility_test_products_command_spec".to_string(),
            run_event_log_ref: "run_event_log:graph_filter_visibility_test_products_command_spec"
                .to_string(),
            answer_packet_ref: "answer_packet:graph_filter_visibility_test_products_command_spec"
                .to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), GraphFilterTestProductsError> {
        validate_exact("scheme_path", &self.scheme_path, REQUIRED_SOURCE_REFS[0])?;
        validate_exact("scheme_name", &self.scheme_name, "Epistemos")?;
        validate_exact("configuration", &self.configuration, "Debug")?;
        validate_exact("destination", &self.destination, "platform=macOS")?;
        validate_exact(
            "testable_name",
            &self.testable_name,
            "EpistemosTests.xctest",
        )?;
        validate_prefix(
            "proof_root_template",
            &self.proof_root_template,
            "artifacts/xcode/graph-filter-visibility-test-products/",
        )?;
        if self
            .proof_root_template
            .contains("~/Library/Developer/Xcode/DerivedData")
            || self
                .proof_root_template
                .contains("/Library/Developer/Xcode/DerivedData")
        {
            return Err(GraphFilterTestProductsError::GlobalDerivedDataPath);
        }
        validate_exact(
            "derived_data_path_template",
            &self.derived_data_path_template,
            "$PROOF_ROOT/DerivedData",
        )?;
        validate_exact(
            "build_result_bundle_name",
            &self.build_result_bundle_name,
            "build-for-testing.xcresult",
        )?;
        validate_exact(
            "enumeration_json_name",
            &self.enumeration_json_name,
            "enumerated-tests.json",
        )?;
        validate_exact(
            "focused_result_bundle_name",
            &self.focused_result_bundle_name,
            "focused-graph-filter.xcresult",
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
        validate_unique_exact_set("source_refs", &self.source_refs, &REQUIRED_SOURCE_REFS)?;
        validate_unique_exact_set(
            "seed_selectors",
            &self.seed_selectors,
            &REQUIRED_SEED_SELECTORS,
        )?;
        validate_unique_exact_set(
            "command_templates",
            &self.command_templates,
            &REQUIRED_COMMAND_TEMPLATES,
        )?;
        for selector in &self.seed_selectors {
            if selector.ends_with(".swift")
                || selector.contains("EpistemosTests/")
                    && selector
                        .split('/')
                        .nth(1)
                        .map(|value| value.ends_with(".swift"))
                        .unwrap_or(false)
                || selector.chars().any(char::is_whitespace)
            {
                return Err(GraphFilterTestProductsError::BadSelector(selector.clone()));
            }
        }
        if self.organ != GraphFilterTestProductsOrgan::ReleaseAuditVerification
            || self.status != GraphFilterTestProductsStatus::MetadataCommandSpecOnly
            || !self.metadata_only
            || self.xcode_command_executed
            || self.product_code_changed
            || self.selected_test_product_bytes_opened != 0
            || self.model_runtime_bytes_loaded != 0
            || self.app_runtime_bytes_loaded != 0
        {
            return Err(GraphFilterTestProductsError::ExecutionBoundaryBroken);
        }
        if !self.rejects_global_derived_data
            || !self.rejects_different_commit_products
            || !self.rejects_stale_result_bundle
            || !self.rejects_selector_mismatch
            || !self.rejects_filename_selector
            || !self.rejects_enumeration_only_pass
            || !self.rejects_zero_executed_tests
            || !self.rejects_pre_action_mutation
            || !self.full_automated_check_row_still_required
        {
            return Err(GraphFilterTestProductsError::RejectionPolicyBroken);
        }
        if self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.release_ready_claimed
            || self.live_dense_70b_claimed
            || self.raw_note_prompt_model_bytes_logged
        {
            return Err(GraphFilterTestProductsError::PromotionBoundaryBroken);
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

// UAS: uas:graph-filter-visibility-test-products-command-spec:metrics
// Plane: Verification.
// Residency: counts for command-spec proof only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterVisibilityTestProductsMetrics {
    pub source_ref_count: usize,
    pub seed_selector_count: usize,
    pub command_template_count: usize,
    pub selected_test_product_bytes_opened: u64,
    pub model_runtime_bytes_loaded: u64,
    pub app_runtime_bytes_loaded: u64,
}

// UAS: uas:graph-filter-visibility-test-products-command-spec:witness
// Plane: Verification.
// Residency: metadata-only proof that the Xcode command spec is safe to attempt.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterVisibilityTestProductsCommandSpecWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub spec: GraphFilterVisibilityTestProductsCommandSpec,
    pub metrics: GraphFilterVisibilityTestProductsMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl GraphFilterVisibilityTestProductsCommandSpecWitness {
    pub fn new(
        upstream_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
    ) -> Result<Self, GraphFilterTestProductsError> {
        validate_upstream_ref(upstream_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(GraphFilterTestProductsError::UpstreamNotPassed);
        }
        if upstream_next_cursor
            != GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_UPSTREAM_NEXT_CURSOR
        {
            return Err(GraphFilterTestProductsError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let spec = GraphFilterVisibilityTestProductsCommandSpec::canonical();
        spec.validate()?;
        let metrics = GraphFilterVisibilityTestProductsMetrics {
            source_ref_count: spec.source_refs.len(),
            seed_selector_count: spec.seed_selectors.len(),
            command_template_count: spec.command_templates.len(),
            selected_test_product_bytes_opened: spec.selected_test_product_bytes_opened,
            model_runtime_bytes_loaded: spec.model_runtime_bytes_loaded,
            app_runtime_bytes_loaded: spec.app_runtime_bytes_loaded,
        };
        let address = graph_filter_test_products_address(
            upstream_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &spec,
            &metrics,
        );
        Ok(Self {
            falsifier_id: GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_ID.to_string(),
            cursor: GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_CURSOR.to_string(),
            next_cursor: GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_NEXT_CURSOR.to_string(),
            upstream_ref: upstream_ref.to_string(),
            upstream_overall_pass,
            upstream_next_cursor: upstream_next_cursor.to_string(),
            spec,
            metrics,
            address,
            metadata_only: true,
            no_product_promotion: true,
        })
    }

    pub fn validate(&self) -> Result<(), GraphFilterTestProductsError> {
        if self.falsifier_id != GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_ID
            || self.cursor != GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_CURSOR
            || self.next_cursor != GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(GraphFilterTestProductsError::WitnessHeaderBroken);
        }
        let rebuilt = Self::new(
            &self.upstream_ref,
            self.upstream_overall_pass,
            &self.upstream_next_cursor,
        )?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(GraphFilterTestProductsError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_graph_filter_test_products_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_graph_filter_test_products_seed_selectors() -> &'static [&'static str] {
    &REQUIRED_SEED_SELECTORS
}

pub fn required_graph_filter_test_products_command_templates() -> &'static [&'static str] {
    &REQUIRED_COMMAND_TEMPLATES
}

fn graph_filter_test_products_address(
    upstream_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    spec: &GraphFilterVisibilityTestProductsCommandSpec,
    metrics: &GraphFilterVisibilityTestProductsMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_ID);
    preimage.push_str(GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_CURSOR);
    preimage.push_str(GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_NEXT_CURSOR);
    preimage.push_str(upstream_ref);
    preimage.push_str(&upstream_overall_pass.to_string());
    preimage.push_str(upstream_next_cursor);
    preimage.push_str(&spec.scheme_path);
    preimage.push_str(&spec.scheme_name);
    preimage.push_str(&spec.testable_name);
    for source in &spec.source_refs {
        preimage.push_str(source);
    }
    for selector in &spec.seed_selectors {
        preimage.push_str(selector);
    }
    for command in &spec.command_templates {
        preimage.push_str(command);
    }
    preimage.push_str(&format!("{metrics:?}"));
    sha256_hex(preimage.as_bytes())
}

fn validate_upstream_ref(value: &str) -> Result<(), GraphFilterTestProductsError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/graph_filter_visibility_focused_identifier_proof/")
        || !value.contains("/result.json#F-GraphFilterVisibilityFocusedIdentifierProof")
    {
        return Err(GraphFilterTestProductsError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    required: &[&'static str],
) -> Result<(), GraphFilterTestProductsError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(GraphFilterTestProductsError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(GraphFilterTestProductsError::MissingRequiredSet {
            field,
            actual: values.len(),
            expected: required.len(),
        });
    }
    Ok(())
}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), GraphFilterTestProductsError> {
    validate_text(field, value)?;
    if value != expected {
        return Err(GraphFilterTestProductsError::UnexpectedValue {
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
) -> Result<(), GraphFilterTestProductsError> {
    validate_text(field, value)?;
    if !value.starts_with(expected_prefix) {
        return Err(GraphFilterTestProductsError::UnexpectedValue {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), GraphFilterTestProductsError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(GraphFilterTestProductsError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), GraphFilterTestProductsError> {
    if value.trim().is_empty()
        || value.len() > 768
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(GraphFilterTestProductsError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:graph-filter-visibility-test-products-command-spec:error
// Plane: Verification.
// Residency: fail-closed command-spec validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GraphFilterTestProductsError {
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
    BadSelector(String),
    BadUpstreamRef,
    GlobalDerivedDataPath,
    UpstreamNotPassed,
    WrongUpstreamCursor(String),
    ExecutionBoundaryBroken,
    RejectionPolicyBroken,
    PromotionBoundaryBroken,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for GraphFilterTestProductsError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidToken { field, value } => {
                write!(f, "invalid token in {field}: {value:?}")
            }
            Self::InvalidText { field, value } => write!(f, "invalid text in {field}: {value:?}"),
            Self::UnexpectedValue { field, value } => {
                write!(f, "unexpected value in {field}: {value:?}")
            }
            Self::DuplicateValue { field, value } => {
                write!(f, "duplicate value in {field}: {value}")
            }
            Self::MissingRequiredSet {
                field,
                actual,
                expected,
            } => write!(
                f,
                "missing required set values for {field}: actual={actual} expected={expected}"
            ),
            Self::BadSelector(selector) => write!(f, "bad Swift Testing selector: {selector}"),
            Self::BadUpstreamRef => {
                write!(f, "bad graph-filter focused-identifier upstream ref")
            }
            Self::GlobalDerivedDataPath => write!(f, "global DerivedData path is forbidden"),
            Self::UpstreamNotPassed => {
                write!(f, "upstream graph-filter identifier proof did not pass")
            }
            Self::WrongUpstreamCursor(cursor) => write!(f, "wrong upstream cursor: {cursor}"),
            Self::ExecutionBoundaryBroken => write!(f, "metadata-only execution boundary broken"),
            Self::RejectionPolicyBroken => write!(f, "required rejection policy is missing"),
            Self::PromotionBoundaryBroken => write!(f, "promotion boundary broken"),
            Self::WitnessHeaderBroken => write!(f, "witness header is invalid"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for GraphFilterTestProductsError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_spec_validates() {
        let spec = GraphFilterVisibilityTestProductsCommandSpec::canonical();
        assert!(spec.validate().is_ok());
        assert_eq!(spec.seed_selectors.len(), 8);
        assert_eq!(spec.command_templates.len(), 3);
    }

    #[test]
    fn rejects_filename_selector() {
        let mut spec = GraphFilterVisibilityTestProductsCommandSpec::canonical();
        spec.seed_selectors[0] = "EpistemosTests/FilterEngineComprehensiveTests.swift".to_string();
        assert!(matches!(
            spec.validate(),
            Err(GraphFilterTestProductsError::MissingRequiredSet { .. })
                | Err(GraphFilterTestProductsError::BadSelector(_))
        ));
    }

    #[test]
    fn rejects_global_derived_data() {
        let mut spec = GraphFilterVisibilityTestProductsCommandSpec::canonical();
        spec.proof_root_template = "~/Library/Developer/Xcode/DerivedData/Epistemos".to_string();
        assert!(matches!(
            spec.validate(),
            Err(GraphFilterTestProductsError::UnexpectedValue { .. })
                | Err(GraphFilterTestProductsError::GlobalDerivedDataPath)
        ));
    }

    #[test]
    fn rejects_execution_or_promotion_claims() {
        let mut spec = GraphFilterVisibilityTestProductsCommandSpec::canonical();
        spec.xcode_command_executed = true;
        assert!(matches!(
            spec.validate(),
            Err(GraphFilterTestProductsError::ExecutionBoundaryBroken)
        ));

        let mut spec = GraphFilterVisibilityTestProductsCommandSpec::canonical();
        spec.l3_green_claimed = true;
        assert!(matches!(
            spec.validate(),
            Err(GraphFilterTestProductsError::PromotionBoundaryBroken)
        ));
    }

    #[test]
    fn witness_is_deterministic() {
        let left = GraphFilterVisibilityTestProductsCommandSpecWitness::new(
            GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_UPSTREAM_REF,
            true,
            GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_UPSTREAM_NEXT_CURSOR,
        )
        .unwrap();
        let right = GraphFilterVisibilityTestProductsCommandSpecWitness::new(
            GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_UPSTREAM_REF,
            true,
            GRAPH_FILTER_VISIBILITY_TEST_PRODUCTS_COMMAND_SPEC_UPSTREAM_NEXT_CURSOR,
        )
        .unwrap();
        assert_eq!(left.address, right.address);
        assert!(left.validate().is_ok());
    }
}
