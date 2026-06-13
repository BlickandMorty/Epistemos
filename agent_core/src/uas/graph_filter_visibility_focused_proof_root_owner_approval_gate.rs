use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_ID: &str =
    "F-GraphFilterVisibilityFocusedProofRootOwnerApprovalGate";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_CURSOR: &str =
    "graph_filter_visibility_focused_proof_root_owner_approval_gate";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_COMMAND_CARD_REF: &str = "artifact:falsifiers/graph_filter_visibility_focused_proof_root_command_card/result.json#F-GraphFilterVisibilityFocusedProofRootCommandCard";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_EXECUTION_GATE_REF: &str = "artifact:falsifiers/graph_filter_visibility_focused_proof_root_execution_artifact_gate/result.json#F-GraphFilterVisibilityFocusedProofRootExecutionArtifactGate";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_RUNBOOK_PATH: &str =
    "docs/audits/FOCUSED_PROOF_ROOT_OWNER_APPROVAL_RUNBOOK_2026_06_08.md";

const REQUIRED_APPROVAL_PRECONDITIONS: [&str; 10] = [
    "one_worktree_main",
    "status_recorded_before_run",
    "command_card_passes",
    "execution_artifact_gate_passes",
    "proof_root_scoped_derived_data",
    "selected_product_digest_required",
    "focused_xcresult_digest_required",
    "nonzero_executed_tests_required",
    "run_event_log_answer_packet_rollback_required",
    "full_automated_check_row_preserved",
];

const REQUIRED_CONSENT_CLAUSES: [&str; 7] = [
    "explicit_owner_approval_required",
    "scope_names_focused_graph_filter_run",
    "current_command_card_named",
    "execution_artifact_parser_named",
    "full_release_audit_separate_approval",
    "no_xcode_without_approval",
    "no_product_or_large_model_promotion",
];

const REQUIRED_REJECTION_POLICIES: [&str; 14] = [
    "approval_missing_blocks_xcode",
    "approval_wording_scope_missing",
    "full_release_audit_requested_by_ambiguous_approval",
    "command_armed_without_approval",
    "xcode_executed_without_approval",
    "selected_product_opened_without_approval",
    "xcresult_opened_without_approval",
    "runbook_missing",
    "command_card_missing_or_failed",
    "execution_artifact_gate_missing_or_failed",
    "full_row_replacement_claim",
    "product_or_release_green_claim",
    "live_dense_70b_claim",
    "ssd_as_ram_claim",
];

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
// UAS: uas:graph-filter-visibility-focused-proof-root-owner-approval-gate:status
// Plane: Controller + Verification.
// Residency: owner approval absent; focused proof-root commands remain unarmed.
pub enum GraphFilterFocusedProofRootOwnerApprovalStatus {
    PendingOwnerApproval,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:graph-filter-visibility-focused-proof-root-owner-approval-gate:spec
// Plane: Controller + Verification.
// Residency: metadata-only owner-approval boundary; no command execution.
pub struct GraphFilterFocusedProofRootOwnerApprovalGate {
    pub runbook_path: String,
    pub approval_phrase: String,
    pub required_preconditions: Vec<String>,
    pub required_consent_clauses: Vec<String>,
    pub required_rejection_policies: Vec<String>,
    pub owner_approval_required: bool,
    pub owner_approval_present: bool,
    pub command_card_required: bool,
    pub execution_artifact_gate_required: bool,
    pub command_envelope_armed: bool,
    pub xcode_command_executed: bool,
    pub selected_test_product_bytes_opened: u64,
    pub xcode_result_bytes_opened: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_code_changed: bool,
    pub full_release_audit_requested: bool,
    pub full_automated_check_row_replaced: bool,
    pub product_green_claimed: bool,
    pub release_ready_claimed: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub status: GraphFilterFocusedProofRootOwnerApprovalStatus,
}

impl GraphFilterFocusedProofRootOwnerApprovalGate {
    pub fn canonical() -> Self {
        Self {
            runbook_path:
                GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_RUNBOOK_PATH.to_string(),
            approval_phrase: "I approve one focused graph-filter proof-root Xcode run using the current proof-root command card and execution-artifact parser gate. Do not run the full release audit unless I approve it separately.".to_string(),
            required_preconditions: REQUIRED_APPROVAL_PRECONDITIONS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_consent_clauses: REQUIRED_CONSENT_CLAUSES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_rejection_policies: REQUIRED_REJECTION_POLICIES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            owner_approval_required: true,
            owner_approval_present: false,
            command_card_required: true,
            execution_artifact_gate_required: true,
            command_envelope_armed: false,
            xcode_command_executed: false,
            selected_test_product_bytes_opened: 0,
            xcode_result_bytes_opened: 0,
            model_runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            product_code_changed: false,
            full_release_audit_requested: false,
            full_automated_check_row_replaced: false,
            product_green_claimed: false,
            release_ready_claimed: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            rollback_ref: "rollback:graph_filter_visibility_focused_proof_root_owner_approval_gate"
                .to_string(),
            run_event_log_ref:
                "run_event_log:graph_filter_visibility_focused_proof_root_owner_approval_gate"
                    .to_string(),
            answer_packet_ref:
                "answer_packet:graph_filter_visibility_focused_proof_root_owner_approval_gate"
                    .to_string(),
            status: GraphFilterFocusedProofRootOwnerApprovalStatus::PendingOwnerApproval,
        }
    }

    pub fn validate(&self) -> Result<(), GraphFilterFocusedProofRootOwnerApprovalGateError> {
        validate_exact(
            "runbook_path",
            &self.runbook_path,
            GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_RUNBOOK_PATH,
        )?;
        validate_token("approval_phrase", &self.approval_phrase)?;
        if !self
            .approval_phrase
            .contains("focused graph-filter proof-root Xcode run")
            || !self.approval_phrase.contains("command card")
            || !self
                .approval_phrase
                .contains("execution-artifact parser gate")
            || !self
                .approval_phrase
                .contains("Do not run the full release audit")
        {
            return Err(GraphFilterFocusedProofRootOwnerApprovalGateError::ApprovalPhraseTooBroad);
        }
        validate_unique_exact_set(
            "required_preconditions",
            &self.required_preconditions,
            &REQUIRED_APPROVAL_PRECONDITIONS,
        )?;
        validate_unique_exact_set(
            "required_consent_clauses",
            &self.required_consent_clauses,
            &REQUIRED_CONSENT_CLAUSES,
        )?;
        validate_unique_exact_set(
            "required_rejection_policies",
            &self.required_rejection_policies,
            &REQUIRED_REJECTION_POLICIES,
        )?;
        if !self.owner_approval_required
            || self.owner_approval_present
            || !self.command_card_required
            || !self.execution_artifact_gate_required
            || self.full_release_audit_requested
            || self.full_automated_check_row_replaced
        {
            return Err(GraphFilterFocusedProofRootOwnerApprovalGateError::ApprovalBoundaryBroken);
        }
        if self.command_envelope_armed
            || self.xcode_command_executed
            || self.selected_test_product_bytes_opened != 0
            || self.xcode_result_bytes_opened != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.product_code_changed
        {
            return Err(GraphFilterFocusedProofRootOwnerApprovalGateError::ExecutionLeak);
        }
        if self.product_green_claimed
            || self.release_ready_claimed
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.live_dense_70b_claimed
            || self.ssd_as_ram_claimed
        {
            return Err(GraphFilterFocusedProofRootOwnerApprovalGateError::PromotionClaim);
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
// UAS: uas:graph-filter-visibility-focused-proof-root-owner-approval-gate:metrics
// Plane: Verification.
// Residency: metadata-only approval-boundary counts and zero-byte ledger.
pub struct GraphFilterFocusedProofRootOwnerApprovalMetrics {
    pub required_precondition_count: usize,
    pub required_consent_clause_count: usize,
    pub required_rejection_policy_count: usize,
    pub command_execution_count: u64,
    pub selected_test_product_bytes_opened: u64,
    pub xcode_result_bytes_opened: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:graph-filter-visibility-focused-proof-root-owner-approval-gate:witness
// Plane: Controller + Verification.
// Residency: command/parser/runbook approval boundary; no Xcode command runs.
pub struct GraphFilterVisibilityFocusedProofRootOwnerApprovalGateWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub command_card_ref: String,
    pub command_card_pass: bool,
    pub command_card_address: String,
    pub execution_artifact_gate_ref: String,
    pub execution_artifact_gate_pass: bool,
    pub execution_artifact_gate_address: String,
    pub runbook_path: String,
    pub runbook_present: bool,
    pub spec: GraphFilterFocusedProofRootOwnerApprovalGate,
    pub metrics: GraphFilterFocusedProofRootOwnerApprovalMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl GraphFilterVisibilityFocusedProofRootOwnerApprovalGateWitness {
    pub fn new(
        command_card_pass: bool,
        command_card_address: &str,
        execution_artifact_gate_pass: bool,
        execution_artifact_gate_address: &str,
        runbook_present: bool,
    ) -> Result<Self, GraphFilterFocusedProofRootOwnerApprovalGateError> {
        if !command_card_pass {
            return Err(GraphFilterFocusedProofRootOwnerApprovalGateError::CommandCardNotPassed);
        }
        if !execution_artifact_gate_pass {
            return Err(
                GraphFilterFocusedProofRootOwnerApprovalGateError::ExecutionArtifactGateNotPassed,
            );
        }
        if !runbook_present {
            return Err(GraphFilterFocusedProofRootOwnerApprovalGateError::RunbookMissing);
        }
        validate_sha256_address("command_card_address", command_card_address)?;
        validate_sha256_address(
            "execution_artifact_gate_address",
            execution_artifact_gate_address,
        )?;
        let spec = GraphFilterFocusedProofRootOwnerApprovalGate::canonical();
        spec.validate()?;
        let metrics = GraphFilterFocusedProofRootOwnerApprovalMetrics {
            required_precondition_count: spec.required_preconditions.len(),
            required_consent_clause_count: spec.required_consent_clauses.len(),
            required_rejection_policy_count: spec.required_rejection_policies.len(),
            command_execution_count: u64::from(spec.xcode_command_executed),
            selected_test_product_bytes_opened: spec.selected_test_product_bytes_opened,
            xcode_result_bytes_opened: spec.xcode_result_bytes_opened,
            model_runtime_bytes_loaded: spec.model_runtime_bytes_loaded,
            provider_calls_made: spec.provider_calls_made,
        };
        let address = graph_filter_focused_proof_root_owner_approval_gate_address(
            command_card_address,
            execution_artifact_gate_address,
            runbook_present,
            &spec,
            &metrics,
        );
        Ok(Self {
            falsifier_id: GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_ID
                .to_string(),
            cursor: GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_CURSOR
                .to_string(),
            next_cursor: GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_NEXT_CURSOR
                .to_string(),
            command_card_ref:
                GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_COMMAND_CARD_REF
                    .to_string(),
            command_card_pass,
            command_card_address: command_card_address.to_string(),
            execution_artifact_gate_ref:
                GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_EXECUTION_GATE_REF
                    .to_string(),
            execution_artifact_gate_pass,
            execution_artifact_gate_address: execution_artifact_gate_address.to_string(),
            runbook_path: GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_RUNBOOK_PATH
                .to_string(),
            runbook_present,
            spec,
            metrics,
            address,
            metadata_only: true,
            no_product_promotion: true,
        })
    }

    pub fn validate(&self) -> Result<(), GraphFilterFocusedProofRootOwnerApprovalGateError> {
        if self.falsifier_id != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_ID
            || self.cursor != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_CURSOR
            || self.next_cursor
                != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_NEXT_CURSOR
            || self.command_card_ref
                != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_COMMAND_CARD_REF
            || self.execution_artifact_gate_ref
                != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_EXECUTION_GATE_REF
            || self.runbook_path
                != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_RUNBOOK_PATH
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(GraphFilterFocusedProofRootOwnerApprovalGateError::WitnessHeaderBroken);
        }
        let rebuilt = Self::new(
            self.command_card_pass,
            &self.command_card_address,
            self.execution_artifact_gate_pass,
            &self.execution_artifact_gate_address,
            self.runbook_present,
        )?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(GraphFilterFocusedProofRootOwnerApprovalGateError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_graph_filter_focused_proof_root_owner_approval_preconditions(
) -> &'static [&'static str] {
    &REQUIRED_APPROVAL_PRECONDITIONS
}

pub fn required_graph_filter_focused_proof_root_owner_approval_consent_clauses(
) -> &'static [&'static str] {
    &REQUIRED_CONSENT_CLAUSES
}

pub fn required_graph_filter_focused_proof_root_owner_approval_rejection_policies(
) -> &'static [&'static str] {
    &REQUIRED_REJECTION_POLICIES
}

fn graph_filter_focused_proof_root_owner_approval_gate_address(
    command_card_address: &str,
    execution_artifact_gate_address: &str,
    runbook_present: bool,
    spec: &GraphFilterFocusedProofRootOwnerApprovalGate,
    metrics: &GraphFilterFocusedProofRootOwnerApprovalMetrics,
) -> String {
    let payload = serde_json::json!({
        "id": GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_OWNER_APPROVAL_GATE_ID,
        "command_card_address": command_card_address,
        "execution_artifact_gate_address": execution_artifact_gate_address,
        "runbook_present": runbook_present,
        "spec": spec,
        "metrics": metrics,
    });
    sha256_hex(payload.to_string().as_bytes())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:graph-filter-visibility-focused-proof-root-owner-approval-gate:error
// Plane: Controller + Verification.
// Residency: fail-closed approval-boundary rejection taxonomy.
pub enum GraphFilterFocusedProofRootOwnerApprovalGateError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    WrongValue(&'static str),
    DuplicateField(String),
    MissingRequiredField(&'static str),
    ApprovalPhraseTooBroad,
    ApprovalBoundaryBroken,
    ExecutionLeak,
    PromotionClaim,
    CommandCardNotPassed,
    ExecutionArtifactGateNotPassed,
    RunbookMissing,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for GraphFilterFocusedProofRootOwnerApprovalGateError {
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
            Self::ApprovalPhraseTooBroad => write!(f, "approval phrase is too broad"),
            Self::ApprovalBoundaryBroken => write!(f, "owner approval boundary broken"),
            Self::ExecutionLeak => write!(f, "execution or byte leak"),
            Self::PromotionClaim => write!(f, "promotion claim attempted"),
            Self::CommandCardNotPassed => write!(f, "command-card witness not passed"),
            Self::ExecutionArtifactGateNotPassed => {
                write!(f, "execution-artifact gate witness not passed")
            }
            Self::RunbookMissing => write!(f, "focused proof-root runbook missing"),
            Self::WitnessHeaderBroken => write!(f, "witness header broken"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for GraphFilterFocusedProofRootOwnerApprovalGateError {}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), GraphFilterFocusedProofRootOwnerApprovalGateError> {
    validate_token(field, value)?;
    if value != expected {
        return Err(GraphFilterFocusedProofRootOwnerApprovalGateError::WrongValue(field));
    }
    Ok(())
}

fn validate_prefix(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), GraphFilterFocusedProofRootOwnerApprovalGateError> {
    validate_token(field, value)?;
    if !value.starts_with(prefix) {
        return Err(GraphFilterFocusedProofRootOwnerApprovalGateError::WrongValue(field));
    }
    Ok(())
}

fn validate_sha256_address(
    field: &'static str,
    value: &str,
) -> Result<(), GraphFilterFocusedProofRootOwnerApprovalGateError> {
    validate_token(field, value)?;
    if !value.starts_with("sha256:") || value.len() != 71 {
        return Err(GraphFilterFocusedProofRootOwnerApprovalGateError::WrongValue(field));
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), GraphFilterFocusedProofRootOwnerApprovalGateError> {
    if value.is_empty() {
        return Err(GraphFilterFocusedProofRootOwnerApprovalGateError::MissingField(field));
    }
    if value.trim() != value {
        return Err(
            GraphFilterFocusedProofRootOwnerApprovalGateError::FieldHasSurroundingWhitespace(field),
        );
    }
    if value.chars().any(char::is_control) {
        return Err(
            GraphFilterFocusedProofRootOwnerApprovalGateError::FieldContainsControlCharacter(field),
        );
    }
    Ok(())
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    expected: &[&'static str],
) -> Result<(), GraphFilterFocusedProofRootOwnerApprovalGateError> {
    if values.is_empty() {
        return Err(GraphFilterFocusedProofRootOwnerApprovalGateError::MissingField(field));
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_token(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(
                GraphFilterFocusedProofRootOwnerApprovalGateError::DuplicateField(value.clone()),
            );
        }
    }
    for required in expected {
        if !seen.contains(required) {
            return Err(
                GraphFilterFocusedProofRootOwnerApprovalGateError::MissingRequiredField(required),
            );
        }
    }
    if seen.len() != expected.len() {
        return Err(GraphFilterFocusedProofRootOwnerApprovalGateError::WrongValue(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    const COMMAND_CARD_ADDRESS: &str =
        "sha256:e7095c8391930693cd93aa9d4e69ce36f45e2b9d178cf7c95a16b81a06aad743";
    const EXECUTION_GATE_ADDRESS: &str =
        "sha256:ddaf0208e07b6d4528bb507dc6d7561cbd1c4f254c3e35ece1a4cc64ed844a99";

    #[test]
    fn canonical_gate_validates() {
        GraphFilterFocusedProofRootOwnerApprovalGate::canonical()
            .validate()
            .expect("canonical owner approval gate should validate");
    }

    #[test]
    fn witness_is_deterministic() {
        let first = GraphFilterVisibilityFocusedProofRootOwnerApprovalGateWitness::new(
            true,
            COMMAND_CARD_ADDRESS,
            true,
            EXECUTION_GATE_ADDRESS,
            true,
        )
        .expect("valid witness");
        let second = GraphFilterVisibilityFocusedProofRootOwnerApprovalGateWitness::new(
            true,
            COMMAND_CARD_ADDRESS,
            true,
            EXECUTION_GATE_ADDRESS,
            true,
        )
        .expect("valid witness");
        assert_eq!(first.address, second.address);
        assert_eq!(first.metrics.required_precondition_count, 10);
        assert_eq!(first.metrics.required_consent_clause_count, 7);
        assert_eq!(first.metrics.required_rejection_policy_count, 14);
    }

    #[test]
    fn rejects_missing_precise_approval_phrase() {
        let mut gate = GraphFilterFocusedProofRootOwnerApprovalGate::canonical();
        gate.approval_phrase = "I approve tests".to_string();
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootOwnerApprovalGateError::ApprovalPhraseTooBroad
        );
    }

    #[test]
    fn rejects_owner_approval_leak() {
        let mut gate = GraphFilterFocusedProofRootOwnerApprovalGate::canonical();
        gate.owner_approval_present = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootOwnerApprovalGateError::ApprovalBoundaryBroken
        );
    }

    #[test]
    fn rejects_execution_and_byte_leaks() {
        let mut gate = GraphFilterFocusedProofRootOwnerApprovalGate::canonical();
        gate.command_envelope_armed = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootOwnerApprovalGateError::ExecutionLeak
        );
        let mut result = GraphFilterFocusedProofRootOwnerApprovalGate::canonical();
        result.xcode_result_bytes_opened = 1;
        assert_eq!(
            result.validate().unwrap_err(),
            GraphFilterFocusedProofRootOwnerApprovalGateError::ExecutionLeak
        );
    }

    #[test]
    fn rejects_promotion_claims() {
        let mut gate = GraphFilterFocusedProofRootOwnerApprovalGate::canonical();
        gate.release_ready_claimed = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootOwnerApprovalGateError::PromotionClaim
        );
        let mut large = GraphFilterFocusedProofRootOwnerApprovalGate::canonical();
        large.live_dense_70b_claimed = true;
        assert_eq!(
            large.validate().unwrap_err(),
            GraphFilterFocusedProofRootOwnerApprovalGateError::PromotionClaim
        );
    }

    #[test]
    fn rejects_missing_upstream_or_runbook() {
        assert_eq!(
            GraphFilterVisibilityFocusedProofRootOwnerApprovalGateWitness::new(
                false,
                COMMAND_CARD_ADDRESS,
                true,
                EXECUTION_GATE_ADDRESS,
                true,
            )
            .unwrap_err(),
            GraphFilterFocusedProofRootOwnerApprovalGateError::CommandCardNotPassed
        );
        assert_eq!(
            GraphFilterVisibilityFocusedProofRootOwnerApprovalGateWitness::new(
                true,
                COMMAND_CARD_ADDRESS,
                true,
                EXECUTION_GATE_ADDRESS,
                false,
            )
            .unwrap_err(),
            GraphFilterFocusedProofRootOwnerApprovalGateError::RunbookMissing
        );
    }

    #[test]
    fn rejects_missing_required_policy() {
        let mut gate = GraphFilterFocusedProofRootOwnerApprovalGate::canonical();
        gate.required_rejection_policies
            .retain(|policy| policy != "xcode_executed_without_approval");
        assert_eq!(
            gate.validate().unwrap_err(),
            GraphFilterFocusedProofRootOwnerApprovalGateError::MissingRequiredField(
                "xcode_executed_without_approval"
            )
        );
    }
}
