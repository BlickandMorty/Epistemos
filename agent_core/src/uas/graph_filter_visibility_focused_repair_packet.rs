use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_ID: &str =
    "F-GraphFilterVisibilityFocusedRepairPacket";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_CURSOR: &str =
    "graph_filter_visibility_focused_repair_packet";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_NEXT_CURSOR: &str =
    "graph_filter_visibility_focused_identifier_proof";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_UPSTREAM_REF: &str = "artifact:falsifiers/release_audit_automated_checks_closure_matrix/result.json#F-ReleaseAuditAutomatedChecksClosureMatrix";

const REQUIRED_SOURCE_REFS: [&str; 4] = [
    "Epistemos/Models/GraphTypes.swift",
    "Epistemos/Graph/FilterEngine.swift",
    "docs/fusion/DEEP_RESEARCH_BREAKTHROUGH_SYNTHESIS_2026_06_06.md#pass-120",
    "artifacts/falsifiers/release_audit_automated_checks_closure_matrix/result.json",
];

const REQUIRED_TEST_REFS: [&str; 4] = [
    "EpistemosTests/FilterEngineComprehensiveTests.swift",
    "EpistemosTests/ResourceExhaustionTests.swift",
    "EpistemosTests/ConcurrencyEdgeCaseTests.swift",
    "EpistemosTests/VaultLifecycleResetTests.swift",
];

const REQUIRED_FOCUSED_COMMANDS: [&str; 4] = [
    "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/FilterEngineComprehensiveTests test",
    "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ResourceExhaustionTests test",
    "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/ConcurrencyEdgeCaseTests test",
    "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/VaultLifecycleResetTests test",
];

const REQUIRED_REPAIR_ANCHORS: [(&str, &str, &str); 7] = [
    (
        "filter_engine_comprehensive_is_node_visible_for_all_types",
        "EpistemosTests/FilterEngineComprehensiveTests.swift",
        "iterate defaultActiveCases, assert folder hidden by default, then opt in folder",
    ),
    (
        "filter_engine_comprehensive_all_seven_types_toggle",
        "EpistemosTests/FilterEngineComprehensiveTests.swift",
        "normalize each visible type to visible before off/on symmetry checks",
    ),
    (
        "filter_engine_comprehensive_visibility_for_each_type",
        "EpistemosTests/FilterEngineComprehensiveTests.swift",
        "use explicit Set(GraphNodeType.visibleCases) before per-type all-visible baseline",
    ),
    (
        "filter_engine_comprehensive_realistic_filtering",
        "EpistemosTests/FilterEngineComprehensiveTests.swift",
        "explicitly opt in folder before expecting folder visible",
    ),
    (
        "resource_exhaustion_filter_all_types_active",
        "EpistemosTests/ResourceExhaustionTests.swift",
        "separate default-active count from explicit all-visible baseline",
    ),
    (
        "concurrency_rapid_type_toggling",
        "EpistemosTests/ConcurrencyEdgeCaseTests.swift",
        "use visibleCases for upper bound and defaultActiveCases for default count",
    ),
    (
        "vault_lifecycle_reset",
        "EpistemosTests/VaultLifecycleResetTests.swift",
        "verify resetForVaultLifecycle restores defaultActiveCases and clears filters",
    ),
];

const REQUIRED_INVARIANTS: [&str; 10] = [
    "visible_cases_are_graph_visible_not_default_active",
    "default_active_cases_exclude_folder",
    "filter_engine_initializes_default_active_cases",
    "is_filtered_compares_default_active_cases",
    "show_all_types_restores_default_active_cases",
    "reset_for_vault_lifecycle_restores_default_active_cases",
    "folder_remains_explicit_opt_in",
    "focused_test_identifiers_required_before_repair_proof",
    "focused_tests_do_not_replace_full_xcodebuild_test",
    "graph_filter_repair_does_not_promote_model_capability",
];

// UAS: uas:graph-filter-visibility-focused-repair-packet:status
// Plane: Verification.
// Residency: metadata-only repair packet; no Swift command execution.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GraphFilterFocusedRepairStatus {
    FocusedRepairPacket,
}

// UAS: uas:graph-filter-visibility-focused-repair-packet:source-truth
// Plane: State + Verification.
// Residency: source text marker evidence; source is inspected, not mutated.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterFocusedRepairSourceTruth {
    pub visible_cases_excludes_block: bool,
    pub default_active_cases_excludes_folder: bool,
    pub filter_engine_initializes_default_active: bool,
    pub is_filtered_compares_default_active: bool,
    pub show_all_types_restores_default_active: bool,
    pub reset_for_vault_lifecycle_restores_default_active: bool,
    pub folder_opt_in_methods_present: bool,
    pub source_text_bytes_read: u64,
}

impl GraphFilterFocusedRepairSourceTruth {
    pub fn validate(&self) -> Result<(), GraphFilterFocusedRepairError> {
        if !self.visible_cases_excludes_block
            || !self.default_active_cases_excludes_folder
            || !self.filter_engine_initializes_default_active
            || !self.is_filtered_compares_default_active
            || !self.show_all_types_restores_default_active
            || !self.reset_for_vault_lifecycle_restores_default_active
            || !self.folder_opt_in_methods_present
            || self.source_text_bytes_read == 0
            || self.source_text_bytes_read > 1_000_000
        {
            return Err(GraphFilterFocusedRepairError::SourceTruthBroken);
        }
        Ok(())
    }
}

// UAS: uas:graph-filter-visibility-focused-repair-packet:repair-anchor
// Plane: Verification.
// Residency: retained failure-to-repair mapping; no source patch applied here.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterFocusedRepairAnchor {
    pub anchor_id: String,
    pub test_ref: String,
    pub repair_shape: String,
    pub product_source_patch_required: bool,
}

impl GraphFilterFocusedRepairAnchor {
    pub fn validate(&self) -> Result<(), GraphFilterFocusedRepairError> {
        validate_token("anchor_id", &self.anchor_id)?;
        validate_text("test_ref", &self.test_ref)?;
        validate_text("repair_shape", &self.repair_shape)?;
        if self.product_source_patch_required {
            return Err(GraphFilterFocusedRepairError::ProductSourcePatchClaimed);
        }
        Ok(())
    }
}

// UAS: uas:graph-filter-visibility-focused-repair-packet:proof-boundary
// Plane: Verification.
// Residency: blocked promotion fields for the repair packet.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterFocusedRepairProofBoundary {
    pub swift_tests_executed: bool,
    pub focused_identifier_proof_claimed: bool,
    pub focused_repair_proof_claimed: bool,
    pub full_xcodebuild_test_pass_claimed: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub t4_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub graph_filter_as_eidos_route_authority: bool,
    pub hidden_route_authority: bool,
    pub route_mutation_claimed: bool,
    pub source_card_as_repair_proof: bool,
    pub focused_tests_replace_full_rerun: bool,
}

impl Default for GraphFilterFocusedRepairProofBoundary {
    fn default() -> Self {
        Self {
            swift_tests_executed: false,
            focused_identifier_proof_claimed: false,
            focused_repair_proof_claimed: false,
            full_xcodebuild_test_pass_claimed: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            t4_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            graph_filter_as_eidos_route_authority: false,
            hidden_route_authority: false,
            route_mutation_claimed: false,
            source_card_as_repair_proof: false,
            focused_tests_replace_full_rerun: false,
        }
    }
}

// UAS: uas:graph-filter-visibility-focused-repair-packet:metrics
// Plane: Verification.
// Residency: aggregate focused-repair packet metrics.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterFocusedRepairMetrics {
    pub retained_issue_count: u64,
    pub source_ref_count: usize,
    pub test_ref_count: usize,
    pub focused_command_count: usize,
    pub repair_anchor_count: usize,
    pub invariant_count: usize,
    pub source_truth_marker_count: usize,
    pub swift_tests_executed_count: u64,
    pub model_runtime_bytes_loaded: u64,
    pub graph_runtime_bytes_loaded: u64,
    pub command_bytes_executed: u64,
}

// UAS: uas:graph-filter-visibility-focused-repair-packet:witness
// Plane: Controller + Verification.
// Residency: metadata-only packet mapping top family to safe focused repair.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct GraphFilterVisibilityFocusedRepairPacketWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub family_id: String,
    pub retained_issue_count: u64,
    pub repair_rank: u64,
    pub status: GraphFilterFocusedRepairStatus,
    pub source_refs: Vec<String>,
    pub test_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub repair_anchors: Vec<GraphFilterFocusedRepairAnchor>,
    pub required_invariants: Vec<String>,
    pub source_truth: GraphFilterFocusedRepairSourceTruth,
    pub proof_boundary: GraphFilterFocusedRepairProofBoundary,
    pub metrics: GraphFilterFocusedRepairMetrics,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl GraphFilterVisibilityFocusedRepairPacketWitness {
    pub fn new(
        upstream_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        retained_issue_count: u64,
        repair_rank: u64,
        source_truth: GraphFilterFocusedRepairSourceTruth,
    ) -> Result<Self, GraphFilterFocusedRepairError> {
        validate_upstream_ref(upstream_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        validate_token("family_id", family_id)?;
        if !upstream_overall_pass
            || upstream_next_cursor != GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_CURSOR
            || family_id != "graph_filter_visibility"
            || retained_issue_count != 34
            || repair_rank != 1
        {
            return Err(GraphFilterFocusedRepairError::UpstreamClosureMismatch);
        }
        source_truth.validate()?;
        let source_refs = REQUIRED_SOURCE_REFS
            .iter()
            .map(|value| value.to_string())
            .collect::<Vec<_>>();
        let test_refs = REQUIRED_TEST_REFS
            .iter()
            .map(|value| value.to_string())
            .collect::<Vec<_>>();
        let focused_commands = REQUIRED_FOCUSED_COMMANDS
            .iter()
            .map(|value| value.to_string())
            .collect::<Vec<_>>();
        let repair_anchors = REQUIRED_REPAIR_ANCHORS
            .iter()
            .map(
                |(anchor_id, test_ref, repair_shape)| GraphFilterFocusedRepairAnchor {
                    anchor_id: (*anchor_id).to_string(),
                    test_ref: (*test_ref).to_string(),
                    repair_shape: (*repair_shape).to_string(),
                    product_source_patch_required: false,
                },
            )
            .collect::<Vec<_>>();
        let required_invariants = REQUIRED_INVARIANTS
            .iter()
            .map(|value| value.to_string())
            .collect::<Vec<_>>();
        let proof_boundary = GraphFilterFocusedRepairProofBoundary::default();
        let metrics = GraphFilterFocusedRepairMetrics {
            retained_issue_count,
            source_ref_count: source_refs.len(),
            test_ref_count: test_refs.len(),
            focused_command_count: focused_commands.len(),
            repair_anchor_count: repair_anchors.len(),
            invariant_count: required_invariants.len(),
            source_truth_marker_count: 7,
            swift_tests_executed_count: 0,
            model_runtime_bytes_loaded: 0,
            graph_runtime_bytes_loaded: 0,
            command_bytes_executed: 0,
        };
        let rollback_ref = "rollback:graph_filter_visibility_focused_repair_packet".to_string();
        let run_event_log_ref =
            "run_event_log:graph_filter_visibility_focused_repair_packet".to_string();
        let answer_packet_ref =
            "answer_packet:graph_filter_visibility_focused_repair_packet".to_string();
        let address = focused_repair_packet_address(
            upstream_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            family_id,
            retained_issue_count,
            repair_rank,
            &source_refs,
            &test_refs,
            &focused_commands,
            &repair_anchors,
            &required_invariants,
            &source_truth,
            &metrics,
        );
        let witness = Self {
            falsifier_id: GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_ID.to_string(),
            cursor: GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_CURSOR.to_string(),
            next_cursor: GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_NEXT_CURSOR.to_string(),
            upstream_ref: upstream_ref.to_string(),
            upstream_overall_pass,
            upstream_next_cursor: upstream_next_cursor.to_string(),
            family_id: family_id.to_string(),
            retained_issue_count,
            repair_rank,
            status: GraphFilterFocusedRepairStatus::FocusedRepairPacket,
            source_refs,
            test_refs,
            focused_commands,
            repair_anchors,
            required_invariants,
            source_truth,
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

    pub fn validate(&self) -> Result<(), GraphFilterFocusedRepairError> {
        if self.falsifier_id != GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_ID
            || self.cursor != GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_CURSOR
            || self.next_cursor != GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_NEXT_CURSOR
            || self.family_id != "graph_filter_visibility"
            || self.retained_issue_count != 34
            || self.repair_rank != 1
            || self.status != GraphFilterFocusedRepairStatus::FocusedRepairPacket
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(GraphFilterFocusedRepairError::WitnessHeaderBroken);
        }
        validate_unique_exact_set("source_refs", &self.source_refs, &REQUIRED_SOURCE_REFS)?;
        validate_unique_exact_set("test_refs", &self.test_refs, &REQUIRED_TEST_REFS)?;
        validate_unique_exact_set(
            "focused_commands",
            &self.focused_commands,
            &REQUIRED_FOCUSED_COMMANDS,
        )?;
        validate_unique_exact_set(
            "required_invariants",
            &self.required_invariants,
            &REQUIRED_INVARIANTS,
        )?;
        validate_repair_anchors(&self.repair_anchors)?;
        self.source_truth.validate()?;
        if self.proof_boundary.swift_tests_executed
            || self.proof_boundary.focused_identifier_proof_claimed
            || self.proof_boundary.focused_repair_proof_claimed
            || self.proof_boundary.full_xcodebuild_test_pass_claimed
            || self.proof_boundary.l2_green_claimed
            || self.proof_boundary.l3_green_claimed
            || self.proof_boundary.t4_green_claimed
            || self.proof_boundary.product_green_claimed
            || self.proof_boundary.live_dense_70b_claimed
            || self.proof_boundary.graph_filter_as_eidos_route_authority
            || self.proof_boundary.hidden_route_authority
            || self.proof_boundary.route_mutation_claimed
            || self.proof_boundary.source_card_as_repair_proof
            || self.proof_boundary.focused_tests_replace_full_rerun
        {
            return Err(GraphFilterFocusedRepairError::ProofBoundaryBroken);
        }
        if self.metrics.retained_issue_count != 34
            || self.metrics.source_ref_count != REQUIRED_SOURCE_REFS.len()
            || self.metrics.test_ref_count != REQUIRED_TEST_REFS.len()
            || self.metrics.focused_command_count != REQUIRED_FOCUSED_COMMANDS.len()
            || self.metrics.repair_anchor_count != REQUIRED_REPAIR_ANCHORS.len()
            || self.metrics.invariant_count != REQUIRED_INVARIANTS.len()
            || self.metrics.source_truth_marker_count != 7
            || self.metrics.swift_tests_executed_count != 0
            || self.metrics.model_runtime_bytes_loaded != 0
            || self.metrics.graph_runtime_bytes_loaded != 0
            || self.metrics.command_bytes_executed != 0
        {
            return Err(GraphFilterFocusedRepairError::MetricsMismatch);
        }
        for value in [
            &self.rollback_ref,
            &self.run_event_log_ref,
            &self.answer_packet_ref,
        ] {
            validate_token("proof_ref", value)?;
        }
        let rebuilt_address = focused_repair_packet_address(
            &self.upstream_ref,
            self.upstream_overall_pass,
            &self.upstream_next_cursor,
            &self.family_id,
            self.retained_issue_count,
            self.repair_rank,
            &self.source_refs,
            &self.test_refs,
            &self.focused_commands,
            &self.repair_anchors,
            &self.required_invariants,
            &self.source_truth,
            &self.metrics,
        );
        if rebuilt_address != self.address {
            return Err(GraphFilterFocusedRepairError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_graph_filter_focused_repair_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_graph_filter_focused_repair_test_refs() -> &'static [&'static str] {
    &REQUIRED_TEST_REFS
}

pub fn required_graph_filter_focused_repair_commands() -> &'static [&'static str] {
    &REQUIRED_FOCUSED_COMMANDS
}

pub fn required_graph_filter_focused_repair_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn validate_repair_anchors(
    anchors: &[GraphFilterFocusedRepairAnchor],
) -> Result<(), GraphFilterFocusedRepairError> {
    if anchors.len() != REQUIRED_REPAIR_ANCHORS.len() {
        return Err(GraphFilterFocusedRepairError::BadRepairAnchorCount {
            actual: anchors.len(),
            expected: REQUIRED_REPAIR_ANCHORS.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for anchor in anchors {
        anchor.validate()?;
        if !seen.insert(anchor.anchor_id.as_str()) {
            return Err(GraphFilterFocusedRepairError::DuplicateValue {
                field: "repair_anchor",
                value: anchor.anchor_id.clone(),
            });
        }
    }
    let actual = anchors
        .iter()
        .map(|anchor| anchor.anchor_id.as_str())
        .collect::<BTreeSet<_>>();
    let expected = REQUIRED_REPAIR_ANCHORS
        .iter()
        .map(|(anchor, _, _)| *anchor)
        .collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(GraphFilterFocusedRepairError::MissingRequiredSet {
            field: "repair_anchors",
            actual: anchors.len(),
            expected: REQUIRED_REPAIR_ANCHORS.len(),
        });
    }
    Ok(())
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    required: &[&'static str],
) -> Result<(), GraphFilterFocusedRepairError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(GraphFilterFocusedRepairError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(GraphFilterFocusedRepairError::MissingRequiredSet {
            field,
            actual: values.len(),
            expected: required.len(),
        });
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), GraphFilterFocusedRepairError> {
    validate_token("upstream_ref", value)?;
    if value != GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_UPSTREAM_REF {
        return Err(GraphFilterFocusedRepairError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), GraphFilterFocusedRepairError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(GraphFilterFocusedRepairError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), GraphFilterFocusedRepairError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(GraphFilterFocusedRepairError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn focused_repair_packet_address(
    upstream_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    family_id: &str,
    retained_issue_count: u64,
    repair_rank: u64,
    source_refs: &[String],
    test_refs: &[String],
    focused_commands: &[String],
    repair_anchors: &[GraphFilterFocusedRepairAnchor],
    required_invariants: &[String],
    source_truth: &GraphFilterFocusedRepairSourceTruth,
    metrics: &GraphFilterFocusedRepairMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_ID);
    preimage.push_str(GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_CURSOR);
    preimage.push_str(GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_NEXT_CURSOR);
    preimage.push_str(upstream_ref);
    preimage.push_str(&upstream_overall_pass.to_string());
    preimage.push_str(upstream_next_cursor);
    preimage.push_str(family_id);
    preimage.push_str(&retained_issue_count.to_string());
    preimage.push_str(&repair_rank.to_string());
    preimage.push_str(&format!("{source_refs:?}"));
    preimage.push_str(&format!("{test_refs:?}"));
    preimage.push_str(&format!("{focused_commands:?}"));
    preimage.push_str(&format!("{repair_anchors:?}"));
    preimage.push_str(&format!("{required_invariants:?}"));
    preimage.push_str(&format!("{source_truth:?}"));
    preimage.push_str(&format!("{metrics:?}"));
    sha256_hex(preimage.as_bytes())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:graph-filter-visibility-focused-repair-packet:error
// Plane: Verification.
// Residency: fail-closed repair packet validation errors.
pub enum GraphFilterFocusedRepairError {
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
    BadRepairAnchorCount {
        actual: usize,
        expected: usize,
    },
    BadUpstreamRef,
    UpstreamClosureMismatch,
    SourceTruthBroken,
    ProductSourcePatchClaimed,
    ProofBoundaryBroken,
    MetricsMismatch,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for GraphFilterFocusedRepairError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for GraphFilterFocusedRepairError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn source_truth() -> GraphFilterFocusedRepairSourceTruth {
        GraphFilterFocusedRepairSourceTruth {
            visible_cases_excludes_block: true,
            default_active_cases_excludes_folder: true,
            filter_engine_initializes_default_active: true,
            is_filtered_compares_default_active: true,
            show_all_types_restores_default_active: true,
            reset_for_vault_lifecycle_restores_default_active: true,
            folder_opt_in_methods_present: true,
            source_text_bytes_read: 4096,
        }
    }

    fn witness() -> GraphFilterVisibilityFocusedRepairPacketWitness {
        GraphFilterVisibilityFocusedRepairPacketWitness::new(
            GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_UPSTREAM_REF,
            true,
            GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_CURSOR,
            "graph_filter_visibility",
            34,
            1,
            source_truth(),
        )
        .expect("valid focused repair packet")
    }

    #[test]
    fn accepts_focused_repair_packet() {
        let witness = witness();
        witness.validate().expect("witness validates");
        assert_eq!(witness.metrics.retained_issue_count, 34);
        assert_eq!(
            witness.metrics.repair_anchor_count,
            REQUIRED_REPAIR_ANCHORS.len()
        );
        assert_eq!(witness.metrics.swift_tests_executed_count, 0);
        assert!(witness.address.starts_with("sha256:"));
        assert!(witness.no_product_promotion);
    }

    #[test]
    fn rejects_bad_upstream_or_family() {
        assert!(GraphFilterVisibilityFocusedRepairPacketWitness::new(
            GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_UPSTREAM_REF,
            false,
            GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_CURSOR,
            "graph_filter_visibility",
            34,
            1,
            source_truth(),
        )
        .is_err());
        assert!(GraphFilterVisibilityFocusedRepairPacketWitness::new(
            GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_UPSTREAM_REF,
            true,
            "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe",
            "graph_filter_visibility",
            34,
            1,
            source_truth(),
        )
        .is_err());
        assert!(GraphFilterVisibilityFocusedRepairPacketWitness::new(
            GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_UPSTREAM_REF,
            true,
            GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_CURSOR,
            "agent_route_policy",
            21,
            2,
            source_truth(),
        )
        .is_err());
    }

    #[test]
    fn rejects_source_truth_and_anchor_overclaims() {
        let mut truth = source_truth();
        truth.default_active_cases_excludes_folder = false;
        assert!(GraphFilterVisibilityFocusedRepairPacketWitness::new(
            GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_UPSTREAM_REF,
            true,
            GRAPH_FILTER_VISIBILITY_FOCUSED_REPAIR_PACKET_CURSOR,
            "graph_filter_visibility",
            34,
            1,
            truth,
        )
        .is_err());

        let mut witness = witness();
        witness.repair_anchors[0].product_source_patch_required = true;
        assert!(witness.validate().is_err());
    }

    #[test]
    fn rejects_green_claims_and_byte_leaks() {
        let mut focused_replacement = witness();
        focused_replacement
            .proof_boundary
            .focused_tests_replace_full_rerun = true;
        assert!(focused_replacement.validate().is_err());

        let mut product_green = witness();
        product_green.proof_boundary.product_green_claimed = true;
        assert!(product_green.validate().is_err());

        let mut large_model_overclaim = witness();
        large_model_overclaim.proof_boundary.live_dense_70b_claimed = true;
        assert!(large_model_overclaim.validate().is_err());

        let mut command_byte_leak = witness();
        command_byte_leak.metrics.command_bytes_executed = 1;
        assert!(command_byte_leak.validate().is_err());
    }
}
