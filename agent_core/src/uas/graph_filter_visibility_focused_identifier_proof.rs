use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_ID: &str =
    "F-GraphFilterVisibilityFocusedIdentifierProof";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_CURSOR: &str =
    "graph_filter_visibility_focused_identifier_proof";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_NEXT_CURSOR: &str =
    "graph_filter_visibility_test_products_command_spec";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_REF: &str =
    "artifact:falsifiers/graph_filter_visibility_focused_repair_packet/result.json#F-GraphFilterVisibilityFocusedRepairPacket";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_NEXT_CURSOR: &str =
    "graph_filter_visibility_focused_identifier_proof";

const REQUIRED_SOURCE_REFS: [&str; 6] = [
    "EpistemosTests/FilterEngineComprehensiveTests.swift",
    "EpistemosTests/ResourceExhaustionTests.swift",
    "EpistemosTests/ConcurrencyEdgeCaseTests.swift",
    "EpistemosTests/VaultLifecycleResetTests.swift",
    "docs/fusion/DEEP_RESEARCH_BREAKTHROUGH_SYNTHESIS_2026_06_06.md#pass-122",
    "artifacts/falsifiers/graph_filter_visibility_focused_repair_packet/result.json",
];

const REQUIRED_SUITE_IDENTIFIERS: [&str; 8] = [
    "EpistemosTests/FilterEngineNodeVisibilityTests",
    "EpistemosTests/FilterEngineTypeFilterSpecificTests",
    "EpistemosTests/FilterEngineComplexScenarioTests",
    "EpistemosTests/ResourceEdgeCaseTests",
    "EpistemosTests/ConcurrencyFilterEngineTests",
    "EpistemosTests/VaultLifecycleResetTests",
    "EpistemosTests/FilterEngineCombinedFilterTests",
    "EpistemosTests/FilterEngineAdditionalTypeTests",
];

const REQUIRED_FUNCTION_IDENTIFIERS: [&str; 8] = [
    "EpistemosTests/FilterEngineNodeVisibilityTests/isNodeVisibleForAllTypes",
    "EpistemosTests/FilterEngineTypeFilterSpecificTests/allSevenTypesCanBeToggled",
    "EpistemosTests/FilterEngineTypeFilterSpecificTests/visibilityForEachType",
    "EpistemosTests/FilterEngineComplexScenarioTests/realisticFilteringScenario",
    "EpistemosTests/ResourceEdgeCaseTests/filterAllTypesActive",
    "EpistemosTests/ConcurrencyFilterEngineTests/rapidTypeToggling",
    "EpistemosTests/ConcurrencyFilterEngineTests/allTypesVisibleByDefault",
    "EpistemosTests/VaultLifecycleResetTests/graphLifecycleResetClearsVisibleStoreAndQueues",
];

const REQUIRED_BUILD_COST_PHASES: [&str; 4] = [
    "package_resolution_observed",
    "scheme_pre_action_observed",
    "dependency_swiftlint_plugin_observed",
    "build_graph_entered_before_stop",
];

const REQUIRED_COMMAND_CANDIDATES: [&str; 3] = [
    "xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:<function-identifiers> -resultBundlePath $PROOF_ROOT/focused-identifiers.xcresult",
    "xcodebuild test -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -enumerate-tests -test-enumeration-format json -test-enumeration-output-path $PROOF_ROOT/enumerated-tests.json",
    "xcodebuild test-without-building -xctestrun $SELECTED_TEST_PRODUCT -destination platform=macOS -only-testing:<function-identifiers> -resultBundlePath $PROOF_ROOT/focused-graph-filter.xcresult",
];

// UAS: uas:graph-filter-visibility-focused-identifier-proof:status
// Plane: Verification.
// Residency: metadata-only Swift Testing identifier proof; no Xcode execution.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GraphFilterFocusedIdentifierStatus {
    SourceDerivedIdentifierPreflight,
}

// UAS: uas:graph-filter-visibility-focused-identifier-proof:source-markers
// Plane: Verification.
// Residency: source text marker evidence; no product mutation.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterFocusedIdentifierSourceMarkers {
    pub filter_engine_node_visibility_suite: bool,
    pub filter_engine_type_filter_specific_suite: bool,
    pub filter_engine_complex_scenario_suite: bool,
    pub resource_edge_case_suite: bool,
    pub concurrency_filter_engine_suite: bool,
    pub vault_lifecycle_reset_suite: bool,
    pub required_functions_present: usize,
    pub source_text_bytes_read: u64,
}

impl GraphFilterFocusedIdentifierSourceMarkers {
    pub fn validate(&self) -> Result<(), GraphFilterFocusedIdentifierError> {
        if !self.filter_engine_node_visibility_suite
            || !self.filter_engine_type_filter_specific_suite
            || !self.filter_engine_complex_scenario_suite
            || !self.resource_edge_case_suite
            || !self.concurrency_filter_engine_suite
            || !self.vault_lifecycle_reset_suite
            || self.required_functions_present != REQUIRED_FUNCTION_IDENTIFIERS.len()
            || self.source_text_bytes_read == 0
            || self.source_text_bytes_read > 2_000_000
        {
            return Err(GraphFilterFocusedIdentifierError::SourceMarkersBroken);
        }
        Ok(())
    }
}

// UAS: uas:graph-filter-visibility-focused-identifier-proof:enumeration
// Plane: Verification.
// Residency: stopped enumeration caveat; no completed enumeration claim.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterFocusedEnumerationCaveat {
    pub enumeration_command_recorded: bool,
    pub enumeration_completed: bool,
    pub enumerated_test_count: u64,
    pub enumerated_identifier_digest: Option<String>,
    pub incomplete_enumeration_used_as_proof: bool,
    pub build_cost_phases_observed: Vec<String>,
}

impl GraphFilterFocusedEnumerationCaveat {
    pub fn canonical() -> Self {
        Self {
            enumeration_command_recorded: true,
            enumeration_completed: false,
            enumerated_test_count: 0,
            enumerated_identifier_digest: None,
            incomplete_enumeration_used_as_proof: false,
            build_cost_phases_observed: REQUIRED_BUILD_COST_PHASES
                .iter()
                .map(|value| value.to_string())
                .collect(),
        }
    }

    pub fn validate(&self) -> Result<(), GraphFilterFocusedIdentifierError> {
        if !self.enumeration_command_recorded
            || self.enumeration_completed
            || self.enumerated_test_count != 0
            || self.enumerated_identifier_digest.is_some()
            || self.incomplete_enumeration_used_as_proof
        {
            return Err(GraphFilterFocusedIdentifierError::EnumerationBoundaryBroken);
        }
        validate_unique_exact_set(
            "build_cost_phases_observed",
            &self.build_cost_phases_observed,
            &REQUIRED_BUILD_COST_PHASES,
        )?;
        Ok(())
    }
}

// UAS: uas:graph-filter-visibility-focused-identifier-proof:result-policy
// Plane: Verification.
// Residency: metadata-only policy for future focused result bundles.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterFocusedResultBundlePolicy {
    pub result_bundle_path_required: bool,
    pub fresh_result_bundle_required: bool,
    pub stale_xcresult_rejected: bool,
    pub zero_executed_tests_rejected: bool,
    pub filename_selector_rejected: bool,
    pub function_identifier_required: bool,
    pub focused_pass_replaces_full_row: bool,
}

impl Default for GraphFilterFocusedResultBundlePolicy {
    fn default() -> Self {
        Self {
            result_bundle_path_required: true,
            fresh_result_bundle_required: true,
            stale_xcresult_rejected: true,
            zero_executed_tests_rejected: true,
            filename_selector_rejected: true,
            function_identifier_required: true,
            focused_pass_replaces_full_row: false,
        }
    }
}

impl GraphFilterFocusedResultBundlePolicy {
    pub fn validate(&self) -> Result<(), GraphFilterFocusedIdentifierError> {
        if !self.result_bundle_path_required
            || !self.fresh_result_bundle_required
            || !self.stale_xcresult_rejected
            || !self.zero_executed_tests_rejected
            || !self.filename_selector_rejected
            || !self.function_identifier_required
            || self.focused_pass_replaces_full_row
        {
            return Err(GraphFilterFocusedIdentifierError::ResultBundlePolicyBroken);
        }
        Ok(())
    }
}

// UAS: uas:graph-filter-visibility-focused-identifier-proof:proof-boundary
// Plane: Verification.
// Residency: blocked proof/promotion fields.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterFocusedIdentifierProofBoundary {
    pub xcode_command_executed: bool,
    pub swift_tests_executed: bool,
    pub focused_repair_proof_claimed: bool,
    pub full_xcodebuild_test_pass_claimed: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub t4_green_claimed: bool,
    pub product_green_claimed: bool,
    pub release_ready_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub raw_user_note_prompt_or_model_bytes_logged: bool,
    pub hidden_route_authority: bool,
    pub route_mutation_claimed: bool,
}

impl Default for GraphFilterFocusedIdentifierProofBoundary {
    fn default() -> Self {
        Self {
            xcode_command_executed: false,
            swift_tests_executed: false,
            focused_repair_proof_claimed: false,
            full_xcodebuild_test_pass_claimed: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            t4_green_claimed: false,
            product_green_claimed: false,
            release_ready_claimed: false,
            live_dense_70b_claimed: false,
            raw_user_note_prompt_or_model_bytes_logged: false,
            hidden_route_authority: false,
            route_mutation_claimed: false,
        }
    }
}

// UAS: uas:graph-filter-visibility-focused-identifier-proof:metrics
// Plane: Verification.
// Residency: aggregate identifier proof counts.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterFocusedIdentifierMetrics {
    pub source_ref_count: usize,
    pub suite_identifier_count: usize,
    pub function_identifier_count: usize,
    pub command_candidate_count: usize,
    pub build_cost_phase_count: usize,
    pub source_text_bytes_read: u64,
    pub xcode_command_bytes_executed: u64,
    pub model_runtime_bytes_loaded: u64,
    pub app_runtime_bytes_loaded: u64,
}

// UAS: uas:graph-filter-visibility-focused-identifier-proof:witness
// Plane: Verification.
// Residency: metadata-only proof of exact focused Swift Testing identifiers.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterVisibilityFocusedIdentifierProofWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub test_target: String,
    pub source_refs: Vec<String>,
    pub suite_identifiers: Vec<String>,
    pub function_identifiers: Vec<String>,
    pub command_candidates: Vec<String>,
    pub status: GraphFilterFocusedIdentifierStatus,
    pub source_markers: GraphFilterFocusedIdentifierSourceMarkers,
    pub enumeration_caveat: GraphFilterFocusedEnumerationCaveat,
    pub result_bundle_policy: GraphFilterFocusedResultBundlePolicy,
    pub proof_boundary: GraphFilterFocusedIdentifierProofBoundary,
    pub metrics: GraphFilterFocusedIdentifierMetrics,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl GraphFilterVisibilityFocusedIdentifierProofWitness {
    pub fn new(
        upstream_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        source_markers: GraphFilterFocusedIdentifierSourceMarkers,
    ) -> Result<Self, GraphFilterFocusedIdentifierError> {
        validate_upstream_ref(upstream_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass
            || upstream_next_cursor
                != GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_NEXT_CURSOR
        {
            return Err(GraphFilterFocusedIdentifierError::UpstreamMismatch);
        }
        source_markers.validate()?;
        let source_refs = REQUIRED_SOURCE_REFS
            .iter()
            .map(|value| value.to_string())
            .collect::<Vec<_>>();
        let suite_identifiers = REQUIRED_SUITE_IDENTIFIERS
            .iter()
            .map(|value| value.to_string())
            .collect::<Vec<_>>();
        let function_identifiers = REQUIRED_FUNCTION_IDENTIFIERS
            .iter()
            .map(|value| value.to_string())
            .collect::<Vec<_>>();
        let command_candidates = REQUIRED_COMMAND_CANDIDATES
            .iter()
            .map(|value| value.to_string())
            .collect::<Vec<_>>();
        validate_identifier_sets(&suite_identifiers, &function_identifiers)?;
        let enumeration_caveat = GraphFilterFocusedEnumerationCaveat::canonical();
        enumeration_caveat.validate()?;
        let result_bundle_policy = GraphFilterFocusedResultBundlePolicy::default();
        result_bundle_policy.validate()?;
        let proof_boundary = GraphFilterFocusedIdentifierProofBoundary::default();
        let metrics = GraphFilterFocusedIdentifierMetrics {
            source_ref_count: source_refs.len(),
            suite_identifier_count: suite_identifiers.len(),
            function_identifier_count: function_identifiers.len(),
            command_candidate_count: command_candidates.len(),
            build_cost_phase_count: enumeration_caveat.build_cost_phases_observed.len(),
            source_text_bytes_read: source_markers.source_text_bytes_read,
            xcode_command_bytes_executed: 0,
            model_runtime_bytes_loaded: 0,
            app_runtime_bytes_loaded: 0,
        };
        let rollback_ref = "rollback:graph_filter_visibility_focused_identifier_proof".to_string();
        let run_event_log_ref =
            "run_event_log:graph_filter_visibility_focused_identifier_proof".to_string();
        let answer_packet_ref =
            "answer_packet:graph_filter_visibility_focused_identifier_proof".to_string();
        let address = focused_identifier_address(
            upstream_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &source_refs,
            &suite_identifiers,
            &function_identifiers,
            &command_candidates,
            &source_markers,
            &enumeration_caveat,
            &result_bundle_policy,
            &metrics,
        );
        let witness = Self {
            falsifier_id: GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_ID.to_string(),
            cursor: GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_CURSOR.to_string(),
            next_cursor: GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_NEXT_CURSOR.to_string(),
            upstream_ref: upstream_ref.to_string(),
            upstream_overall_pass,
            upstream_next_cursor: upstream_next_cursor.to_string(),
            test_target: "EpistemosTests".to_string(),
            source_refs,
            suite_identifiers,
            function_identifiers,
            command_candidates,
            status: GraphFilterFocusedIdentifierStatus::SourceDerivedIdentifierPreflight,
            source_markers,
            enumeration_caveat,
            result_bundle_policy,
            proof_boundary,
            metrics,
            rollback_ref,
            run_event_log_ref,
            answer_packet_ref,
            address,
            metadata_only: true,
            no_product_promotion: true,
        };
        witness.validate()?;
        Ok(witness)
    }

    pub fn validate(&self) -> Result<(), GraphFilterFocusedIdentifierError> {
        if self.falsifier_id != GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_ID
            || self.cursor != GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_CURSOR
            || self.next_cursor != GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_NEXT_CURSOR
            || self.test_target != "EpistemosTests"
            || self.status != GraphFilterFocusedIdentifierStatus::SourceDerivedIdentifierPreflight
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(GraphFilterFocusedIdentifierError::WitnessHeaderBroken);
        }
        validate_unique_exact_set("source_refs", &self.source_refs, &REQUIRED_SOURCE_REFS)?;
        validate_unique_exact_set(
            "suite_identifiers",
            &self.suite_identifiers,
            &REQUIRED_SUITE_IDENTIFIERS,
        )?;
        validate_unique_exact_set(
            "function_identifiers",
            &self.function_identifiers,
            &REQUIRED_FUNCTION_IDENTIFIERS,
        )?;
        validate_unique_exact_set(
            "command_candidates",
            &self.command_candidates,
            &REQUIRED_COMMAND_CANDIDATES,
        )?;
        validate_identifier_sets(&self.suite_identifiers, &self.function_identifiers)?;
        self.source_markers.validate()?;
        self.enumeration_caveat.validate()?;
        self.result_bundle_policy.validate()?;
        if self.proof_boundary.xcode_command_executed
            || self.proof_boundary.swift_tests_executed
            || self.proof_boundary.focused_repair_proof_claimed
            || self.proof_boundary.full_xcodebuild_test_pass_claimed
            || self.proof_boundary.l2_green_claimed
            || self.proof_boundary.l3_green_claimed
            || self.proof_boundary.t4_green_claimed
            || self.proof_boundary.product_green_claimed
            || self.proof_boundary.release_ready_claimed
            || self.proof_boundary.live_dense_70b_claimed
            || self
                .proof_boundary
                .raw_user_note_prompt_or_model_bytes_logged
            || self.proof_boundary.hidden_route_authority
            || self.proof_boundary.route_mutation_claimed
        {
            return Err(GraphFilterFocusedIdentifierError::ProofBoundaryBroken);
        }
        if self.metrics.source_ref_count != REQUIRED_SOURCE_REFS.len()
            || self.metrics.suite_identifier_count != REQUIRED_SUITE_IDENTIFIERS.len()
            || self.metrics.function_identifier_count != REQUIRED_FUNCTION_IDENTIFIERS.len()
            || self.metrics.command_candidate_count != REQUIRED_COMMAND_CANDIDATES.len()
            || self.metrics.build_cost_phase_count != REQUIRED_BUILD_COST_PHASES.len()
            || self.metrics.source_text_bytes_read != self.source_markers.source_text_bytes_read
            || self.metrics.xcode_command_bytes_executed != 0
            || self.metrics.model_runtime_bytes_loaded != 0
            || self.metrics.app_runtime_bytes_loaded != 0
        {
            return Err(GraphFilterFocusedIdentifierError::MetricsMismatch);
        }
        for value in [
            &self.rollback_ref,
            &self.run_event_log_ref,
            &self.answer_packet_ref,
        ] {
            validate_token("proof_ref", value)?;
        }
        let rebuilt = focused_identifier_address(
            &self.upstream_ref,
            self.upstream_overall_pass,
            &self.upstream_next_cursor,
            &self.source_refs,
            &self.suite_identifiers,
            &self.function_identifiers,
            &self.command_candidates,
            &self.source_markers,
            &self.enumeration_caveat,
            &self.result_bundle_policy,
            &self.metrics,
        );
        if rebuilt != self.address {
            return Err(GraphFilterFocusedIdentifierError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_graph_filter_focused_identifier_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_graph_filter_focused_identifier_suite_identifiers() -> &'static [&'static str] {
    &REQUIRED_SUITE_IDENTIFIERS
}

pub fn required_graph_filter_focused_identifier_function_identifiers() -> &'static [&'static str] {
    &REQUIRED_FUNCTION_IDENTIFIERS
}

pub fn required_graph_filter_focused_identifier_command_candidates() -> &'static [&'static str] {
    &REQUIRED_COMMAND_CANDIDATES
}

fn focused_identifier_address(
    upstream_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    source_refs: &[String],
    suite_identifiers: &[String],
    function_identifiers: &[String],
    command_candidates: &[String],
    source_markers: &GraphFilterFocusedIdentifierSourceMarkers,
    enumeration_caveat: &GraphFilterFocusedEnumerationCaveat,
    result_bundle_policy: &GraphFilterFocusedResultBundlePolicy,
    metrics: &GraphFilterFocusedIdentifierMetrics,
) -> String {
    let mut preimage = String::new();
    for value in [
        GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_ID,
        GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_CURSOR,
        GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_NEXT_CURSOR,
        upstream_ref,
        upstream_next_cursor,
    ] {
        preimage.push_str(value);
    }
    preimage.push_str(&upstream_overall_pass.to_string());
    for set in [
        source_refs,
        suite_identifiers,
        function_identifiers,
        command_candidates,
    ] {
        for value in set {
            preimage.push_str(value);
        }
    }
    preimage.push_str(&format!(
        "{source_markers:?}{enumeration_caveat:?}{result_bundle_policy:?}{metrics:?}"
    ));
    sha256_hex(preimage.as_bytes())
}

fn validate_identifier_sets(
    suite_identifiers: &[String],
    function_identifiers: &[String],
) -> Result<(), GraphFilterFocusedIdentifierError> {
    let suite_set = suite_identifiers
        .iter()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    for suite in suite_identifiers {
        validate_selector("suite_identifier", suite, 2)?;
    }
    for identifier in function_identifiers {
        validate_selector("function_identifier", identifier, 3)?;
        let suite_prefix = identifier
            .rsplit_once('/')
            .map(|(prefix, _)| prefix)
            .ok_or_else(|| GraphFilterFocusedIdentifierError::BadSelector(identifier.clone()))?;
        if !suite_set.contains(suite_prefix) {
            return Err(GraphFilterFocusedIdentifierError::FunctionWithoutSuite(
                identifier.clone(),
            ));
        }
    }
    Ok(())
}

fn validate_selector(
    field: &'static str,
    value: &str,
    expected_parts: usize,
) -> Result<(), GraphFilterFocusedIdentifierError> {
    validate_token(field, value)?;
    if value.ends_with(".swift")
        || value.contains(':')
        || value.contains('\\')
        || value.split('/').count() != expected_parts
        || !value.starts_with("EpistemosTests/")
    {
        return Err(GraphFilterFocusedIdentifierError::BadSelector(
            value.to_string(),
        ));
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), GraphFilterFocusedIdentifierError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/graph_filter_visibility_focused_repair_packet/")
        || !value.contains("/result.json#F-GraphFilterVisibilityFocusedRepairPacket")
    {
        return Err(GraphFilterFocusedIdentifierError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    required: &[&'static str],
) -> Result<(), GraphFilterFocusedIdentifierError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(GraphFilterFocusedIdentifierError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(GraphFilterFocusedIdentifierError::MissingRequiredSet {
            field,
            actual: values.len(),
            expected: required.len(),
        });
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), GraphFilterFocusedIdentifierError> {
    if value.trim().is_empty()
        || value.len() > 768
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(GraphFilterFocusedIdentifierError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(
    field: &'static str,
    value: &str,
) -> Result<(), GraphFilterFocusedIdentifierError> {
    if value.trim().is_empty()
        || value.len() > 1024
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(GraphFilterFocusedIdentifierError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:graph-filter-visibility-focused-identifier-proof:error
// Plane: Verification.
// Residency: fail-closed identifier proof errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum GraphFilterFocusedIdentifierError {
    InvalidToken {
        field: &'static str,
        value: String,
    },
    InvalidText {
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
    FunctionWithoutSuite(String),
    BadUpstreamRef,
    UpstreamMismatch,
    SourceMarkersBroken,
    EnumerationBoundaryBroken,
    ResultBundlePolicyBroken,
    ProofBoundaryBroken,
    MetricsMismatch,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for GraphFilterFocusedIdentifierError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidToken { field, value } => {
                write!(f, "invalid token in {field}: {value:?}")
            }
            Self::InvalidText { field, value } => write!(f, "invalid text in {field}: {value:?}"),
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
            Self::FunctionWithoutSuite(identifier) => {
                write!(f, "function identifier has no matching suite: {identifier}")
            }
            Self::BadUpstreamRef => write!(f, "bad focused repair upstream ref"),
            Self::UpstreamMismatch => write!(f, "focused repair upstream mismatch"),
            Self::SourceMarkersBroken => write!(f, "source markers are incomplete"),
            Self::EnumerationBoundaryBroken => write!(f, "enumeration boundary broken"),
            Self::ResultBundlePolicyBroken => write!(f, "result bundle policy broken"),
            Self::ProofBoundaryBroken => write!(f, "proof boundary broken"),
            Self::MetricsMismatch => write!(f, "metrics mismatch"),
            Self::WitnessHeaderBroken => write!(f, "witness header is invalid"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for GraphFilterFocusedIdentifierError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn markers() -> GraphFilterFocusedIdentifierSourceMarkers {
        GraphFilterFocusedIdentifierSourceMarkers {
            filter_engine_node_visibility_suite: true,
            filter_engine_type_filter_specific_suite: true,
            filter_engine_complex_scenario_suite: true,
            resource_edge_case_suite: true,
            concurrency_filter_engine_suite: true,
            vault_lifecycle_reset_suite: true,
            required_functions_present: REQUIRED_FUNCTION_IDENTIFIERS.len(),
            source_text_bytes_read: 1234,
        }
    }

    fn witness() -> GraphFilterVisibilityFocusedIdentifierProofWitness {
        GraphFilterVisibilityFocusedIdentifierProofWitness::new(
            GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_REF,
            true,
            GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_NEXT_CURSOR,
            markers(),
        )
        .unwrap()
    }

    #[test]
    fn accepts_source_derived_identifier_proof() {
        let witness = witness();
        assert_eq!(witness.function_identifiers.len(), 8);
        assert!(witness.validate().is_ok());
    }

    #[test]
    fn rejects_bad_upstream_and_source_markers() {
        assert!(matches!(
            GraphFilterVisibilityFocusedIdentifierProofWitness::new(
                GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_REF,
                false,
                GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_NEXT_CURSOR,
                markers(),
            ),
            Err(GraphFilterFocusedIdentifierError::UpstreamMismatch)
        ));

        let mut bad = markers();
        bad.required_functions_present = 0;
        assert!(matches!(
            GraphFilterVisibilityFocusedIdentifierProofWitness::new(
                GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_REF,
                true,
                GRAPH_FILTER_VISIBILITY_FOCUSED_IDENTIFIER_PROOF_UPSTREAM_NEXT_CURSOR,
                bad,
            ),
            Err(GraphFilterFocusedIdentifierError::SourceMarkersBroken)
        ));
    }

    #[test]
    fn rejects_filename_selectors_and_unmatched_functions() {
        let mut filename_fixture = witness();
        filename_fixture.function_identifiers[0] =
            "EpistemosTests/FilterEngineComprehensiveTests.swift".to_string();
        assert!(matches!(
            filename_fixture.validate(),
            Err(GraphFilterFocusedIdentifierError::MissingRequiredSet { .. })
                | Err(GraphFilterFocusedIdentifierError::BadSelector(_))
        ));

        let mut missing_suite_fixture = witness();
        missing_suite_fixture.function_identifiers[0] =
            "EpistemosTests/MissingSuite/isNodeVisibleForAllTypes".to_string();
        assert!(matches!(
            missing_suite_fixture.validate(),
            Err(GraphFilterFocusedIdentifierError::MissingRequiredSet { .. })
                | Err(GraphFilterFocusedIdentifierError::FunctionWithoutSuite(_))
        ));
    }

    #[test]
    fn rejects_execution_enumeration_and_promotion_claims() {
        let mut enumeration_fixture = witness();
        enumeration_fixture.enumeration_caveat.enumeration_completed = true;
        assert!(matches!(
            enumeration_fixture.validate(),
            Err(GraphFilterFocusedIdentifierError::EnumerationBoundaryBroken)
        ));

        let mut result_bundle_fixture = witness();
        result_bundle_fixture
            .result_bundle_policy
            .focused_pass_replaces_full_row = true;
        assert!(matches!(
            result_bundle_fixture.validate(),
            Err(GraphFilterFocusedIdentifierError::ResultBundlePolicyBroken)
        ));

        let mut promotion_fixture = witness();
        promotion_fixture.proof_boundary.live_dense_70b_claimed = true;
        assert!(matches!(
            promotion_fixture.validate(),
            Err(GraphFilterFocusedIdentifierError::ProofBoundaryBroken)
        ));
    }
}
