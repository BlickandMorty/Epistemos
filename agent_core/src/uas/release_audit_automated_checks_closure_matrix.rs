use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};
use std::fmt;

use super::{ReleaseAuditFailureFamilySourceCard, RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_ID};

pub const RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_ID: &str =
    "F-ReleaseAuditAutomatedChecksClosureMatrix";
pub const RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_CURSOR: &str =
    "release_audit_automated_checks_closure_matrix";
pub const RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_NEXT_CURSOR: &str =
    "graph_filter_visibility_focused_repair_packet";
pub const RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_UPSTREAM_REF: &str =
    "artifact:falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/result.json#F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditAutomatedChecksProbe";
pub const RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_FAMILY_SOURCE_REF: &str =
    "artifact:falsifiers/release_audit_failure_family_source_card/result.json#F-ReleaseAuditFailureFamily-SourceCard";

const REQUIRED_CHECK_IDS: [&str; 5] = [
    "xcodebuild_build",
    "xcodebuild_test",
    "graph_engine_cargo_test",
    "omega_mcp_cargo_test",
    "omega_ax_cargo_test",
];

const REQUIRED_CLOSURE_STEPS: [&str; 6] = [
    "family_source_cards_bound",
    "focused_graph_filter_identifier_proof",
    "focused_graph_filter_test_repair",
    "focused_graph_filter_logs_pass",
    "full_xcodebuild_test_rerun_passes",
    "all_automated_checks_rerun_pass",
];

const TOP_FAMILY_SOURCE_REFS: [&str; 3] = [
    "Epistemos/Graph/FilterEngine.swift",
    "Epistemos/Models/GraphTypes.swift",
    "Epistemos/Graph/GraphState.swift",
];

const TOP_FAMILY_TEST_REFS: [&str; 3] = [
    "EpistemosTests/FilterEngineComprehensiveTests.swift",
    "EpistemosTests/ResourceExhaustionTests.swift",
    "EpistemosTests/ConcurrencyEdgeCaseTests.swift",
];

// UAS: uas:release-audit-automated-checks-closure-matrix:command-status
// Plane: Verification.
// Residency: retained automated-check command status only; no command rerun.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReleaseAuditClosureCommandStatus {
    PassedRetained,
    FailedRetained,
}

// UAS: uas:release-audit-automated-checks-closure-matrix:family-status
// Plane: Verification.
// Residency: repair queue status; not product readiness.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ReleaseAuditClosureFamilyStatus {
    SourceCarded,
    FocusedRepairNeeded,
}

// UAS: uas:release-audit-automated-checks-closure-matrix:command-row
// Plane: Verification.
// Residency: retained command ledger row; command output is not embedded.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReleaseAuditClosureCommandRow {
    pub check_id: String,
    pub status: ReleaseAuditClosureCommandStatus,
    pub issue_count: u64,
    pub log_ref: String,
}

impl ReleaseAuditClosureCommandRow {
    pub fn new(
        check_id: &str,
        status: ReleaseAuditClosureCommandStatus,
        issue_count: u64,
        log_ref: &str,
    ) -> Result<Self, ReleaseAuditClosureError> {
        validate_token("check_id", check_id)?;
        validate_token("log_ref", log_ref)?;
        if !REQUIRED_CHECK_IDS.contains(&check_id) {
            return Err(ReleaseAuditClosureError::UnknownCheck(check_id.to_string()));
        }
        if check_id == "xcodebuild_test"
            && status != ReleaseAuditClosureCommandStatus::FailedRetained
        {
            return Err(ReleaseAuditClosureError::XcodebuildTestNotRetainedRed);
        }
        if check_id != "xcodebuild_test"
            && status != ReleaseAuditClosureCommandStatus::PassedRetained
        {
            return Err(ReleaseAuditClosureError::UnexpectedFailedCheck(
                check_id.to_string(),
            ));
        }
        if status == ReleaseAuditClosureCommandStatus::FailedRetained && issue_count == 0 {
            return Err(ReleaseAuditClosureError::FailedCheckHasZeroIssues);
        }
        if status == ReleaseAuditClosureCommandStatus::PassedRetained && issue_count != 0 {
            return Err(ReleaseAuditClosureError::PassedCheckHasIssues(
                check_id.to_string(),
            ));
        }
        Ok(Self {
            check_id: check_id.to_string(),
            status,
            issue_count,
            log_ref: log_ref.to_string(),
        })
    }
}

// UAS: uas:release-audit-automated-checks-closure-matrix:family-row
// Plane: Controller + Verification.
// Residency: closure plan row sourced from the retained family source card.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReleaseAuditClosureFamilyRow {
    pub family_id: String,
    pub issue_count: u64,
    pub source_card_ref: String,
    pub focused_commands: Vec<String>,
    pub source_refs: Vec<String>,
    pub test_refs: Vec<String>,
    pub status: ReleaseAuditClosureFamilyStatus,
    pub repair_rank: u64,
    pub source_card_is_repair_proof: bool,
    pub focused_test_replaces_full_rerun: bool,
}

impl ReleaseAuditClosureFamilyRow {
    pub fn from_source_card(
        card: &ReleaseAuditFailureFamilySourceCard,
        rank: u64,
        top_family_id: &str,
    ) -> Result<Self, ReleaseAuditClosureError> {
        card.validate()
            .map_err(|error| ReleaseAuditClosureError::BadFamilyCard(error.to_string()))?;
        validate_token("family_id", &card.family_id)?;
        if card.issue_count == 0 {
            return Err(ReleaseAuditClosureError::ZeroIssueFamily(
                card.family_id.clone(),
            ));
        }
        if rank == 0 {
            return Err(ReleaseAuditClosureError::InvalidRepairRank);
        }
        let status = if card.family_id == top_family_id {
            ReleaseAuditClosureFamilyStatus::FocusedRepairNeeded
        } else {
            ReleaseAuditClosureFamilyStatus::SourceCarded
        };
        let test_refs = if card.family_id == top_family_id {
            TOP_FAMILY_TEST_REFS
                .iter()
                .map(|value| value.to_string())
                .collect()
        } else {
            Vec::new()
        };
        Ok(Self {
            family_id: card.family_id.clone(),
            issue_count: card.issue_count,
            source_card_ref: format!(
                "{RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_FAMILY_SOURCE_REF}#{}",
                card.family_id
            ),
            focused_commands: card.focused_commands.clone(),
            source_refs: card.source_refs.clone(),
            test_refs,
            status,
            repair_rank: rank,
            source_card_is_repair_proof: false,
            focused_test_replaces_full_rerun: false,
        })
    }

    pub fn validate(&self, top_family_id: &str) -> Result<(), ReleaseAuditClosureError> {
        validate_token("family_id", &self.family_id)?;
        validate_token("source_card_ref", &self.source_card_ref)?;
        if self.issue_count == 0 {
            return Err(ReleaseAuditClosureError::ZeroIssueFamily(
                self.family_id.clone(),
            ));
        }
        if self.focused_commands.is_empty()
            || self.focused_commands.len() > 8
            || self.source_refs.is_empty()
            || self.source_refs.len() > 8
        {
            return Err(ReleaseAuditClosureError::MissingRepairRefs(
                self.family_id.clone(),
            ));
        }
        for value in self
            .focused_commands
            .iter()
            .chain(self.source_refs.iter())
            .chain(self.test_refs.iter())
        {
            validate_text("repair_ref", value)?;
        }
        if self.family_id == top_family_id {
            validate_exact_string_set(
                "top_family_test_refs",
                &self.test_refs,
                &TOP_FAMILY_TEST_REFS,
            )?;
            if self.status != ReleaseAuditClosureFamilyStatus::FocusedRepairNeeded {
                return Err(ReleaseAuditClosureError::TopFamilyNotFocused);
            }
        }
        if self.source_card_is_repair_proof || self.focused_test_replaces_full_rerun {
            return Err(ReleaseAuditClosureError::RepairProofBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:release-audit-automated-checks-closure-matrix:proof-boundary
// Plane: Verification.
// Residency: release-audit proof requirements still outstanding.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReleaseAuditClosureProofBoundary {
    pub log_evidence_attempted: bool,
    pub manual_runtime_evidence_attempted: bool,
    pub distribution_evidence_attempted: bool,
    pub zero_fail_passes_claimed: u64,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub t4_green_claimed: bool,
    pub product_green_claimed: bool,
    pub ship_call_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub hidden_route_authority_claimed: bool,
    pub route_mutation_claimed: bool,
}

impl Default for ReleaseAuditClosureProofBoundary {
    fn default() -> Self {
        Self {
            log_evidence_attempted: false,
            manual_runtime_evidence_attempted: false,
            distribution_evidence_attempted: false,
            zero_fail_passes_claimed: 0,
            l2_green_claimed: false,
            l3_green_claimed: false,
            t4_green_claimed: false,
            product_green_claimed: false,
            ship_call_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            hidden_route_authority_claimed: false,
            route_mutation_claimed: false,
        }
    }
}

// UAS: uas:release-audit-automated-checks-closure-matrix:byte-ledger
// Plane: Verification.
// Residency: metadata/test-log refs only; no model/runtime/product bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReleaseAuditClosureByteLedger {
    pub retained_log_refs_read: u64,
    pub model_runtime_bytes_loaded: u64,
    pub product_runtime_bytes_loaded: u64,
    pub provider_bytes_loaded: u64,
    pub command_bytes_executed: u64,
}

impl Default for ReleaseAuditClosureByteLedger {
    fn default() -> Self {
        Self {
            retained_log_refs_read: 5,
            model_runtime_bytes_loaded: 0,
            product_runtime_bytes_loaded: 0,
            provider_bytes_loaded: 0,
            command_bytes_executed: 0,
        }
    }
}

// UAS: uas:release-audit-automated-checks-closure-matrix:metrics
// Plane: Verification.
// Residency: aggregate release-audit closure metrics.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReleaseAuditClosureMetrics {
    pub command_count: usize,
    pub passed_command_count: usize,
    pub failed_command_count: usize,
    pub total_issue_count: u64,
    pub unique_failure_count: u64,
    pub family_count: usize,
    pub top_family_id: String,
    pub top_family_issue_count: u64,
    pub closure_step_count: usize,
    pub focused_repair_family_count: usize,
    pub source_card_repair_proof_count: usize,
    pub focused_test_full_rerun_replacement_count: usize,
    pub model_runtime_bytes_loaded: u64,
    pub product_runtime_bytes_loaded: u64,
    pub provider_bytes_loaded: u64,
    pub command_bytes_executed: u64,
}

// UAS: uas:release-audit-automated-checks-closure-matrix:witness
// Plane: Controller + Verification.
// Residency: metadata-only closure matrix; no repair or release-ready claim.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReleaseAuditAutomatedChecksClosureMatrixWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_failed_check_count: u64,
    pub upstream_unique_failure_count: u64,
    pub upstream_top_family_id: String,
    pub command_rows: Vec<ReleaseAuditClosureCommandRow>,
    pub family_rows: Vec<ReleaseAuditClosureFamilyRow>,
    pub closure_steps: Vec<String>,
    pub proof_boundary: ReleaseAuditClosureProofBoundary,
    pub byte_ledger: ReleaseAuditClosureByteLedger,
    pub metrics: ReleaseAuditClosureMetrics,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl ReleaseAuditAutomatedChecksClosureMatrixWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_failed_check_count: u64,
        upstream_unique_failure_count: u64,
        upstream_top_family_id: &str,
        command_rows: Vec<ReleaseAuditClosureCommandRow>,
        family_cards: Vec<ReleaseAuditFailureFamilySourceCard>,
    ) -> Result<Self, ReleaseAuditClosureError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_top_family_id", upstream_top_family_id)?;
        if upstream_overall_pass
            || upstream_failed_check_count != 1
            || upstream_unique_failure_count != 84
            || upstream_top_family_id != "graph_filter_visibility"
        {
            return Err(ReleaseAuditClosureError::UpstreamRedLedgerMismatch);
        }
        validate_command_rows(&command_rows)?;
        let mut cards = family_cards;
        cards.sort_by(|left, right| left.family_id.cmp(&right.family_id));
        validate_family_cards(&cards)?;
        let mut ranked_cards = cards.clone();
        ranked_cards.sort_by(|left, right| {
            right
                .issue_count
                .cmp(&left.issue_count)
                .then_with(|| left.family_id.cmp(&right.family_id))
        });
        let mut rank_by_family = BTreeMap::new();
        for (index, card) in ranked_cards.iter().enumerate() {
            rank_by_family.insert(card.family_id.clone(), index as u64 + 1);
        }
        let mut family_rows = Vec::with_capacity(cards.len());
        for card in &cards {
            family_rows.push(ReleaseAuditClosureFamilyRow::from_source_card(
                card,
                *rank_by_family
                    .get(&card.family_id)
                    .ok_or(ReleaseAuditClosureError::InvalidRepairRank)?,
                upstream_top_family_id,
            )?);
        }
        let closure_steps = REQUIRED_CLOSURE_STEPS
            .iter()
            .map(|value| value.to_string())
            .collect::<Vec<_>>();
        let proof_boundary = ReleaseAuditClosureProofBoundary::default();
        let byte_ledger = ReleaseAuditClosureByteLedger::default();
        let metrics = metrics_for(
            &command_rows,
            &family_rows,
            &closure_steps,
            &proof_boundary,
            &byte_ledger,
            upstream_unique_failure_count,
            upstream_top_family_id,
        )?;
        let rollback_ref = "rollback:release_audit_automated_checks_closure_matrix".to_string();
        let run_event_log_ref =
            "run_event_log:release_audit_automated_checks_closure_matrix".to_string();
        let answer_packet_ref =
            "answer_packet:release_audit_automated_checks_closure_matrix".to_string();
        let address = closure_matrix_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_failed_check_count,
            upstream_unique_failure_count,
            upstream_top_family_id,
            &command_rows,
            &family_rows,
            &closure_steps,
            &metrics,
        );
        let witness = Self {
            falsifier_id: RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_ID.to_string(),
            cursor: RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_CURSOR.to_string(),
            next_cursor: RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_NEXT_CURSOR.to_string(),
            upstream_ref: upstream_ref.to_string(),
            family_source_ref: family_source_ref.to_string(),
            upstream_overall_pass,
            upstream_failed_check_count,
            upstream_unique_failure_count,
            upstream_top_family_id: upstream_top_family_id.to_string(),
            command_rows,
            family_rows,
            closure_steps,
            proof_boundary,
            byte_ledger,
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

    pub fn validate(&self) -> Result<(), ReleaseAuditClosureError> {
        if self.falsifier_id != RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_ID
            || self.cursor != RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_CURSOR
            || self.next_cursor != RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(ReleaseAuditClosureError::WitnessHeaderBroken);
        }
        validate_upstream_ref(&self.upstream_ref)?;
        validate_family_source_ref(&self.family_source_ref)?;
        validate_command_rows(&self.command_rows)?;
        validate_family_rows(&self.family_rows, &self.upstream_top_family_id)?;
        validate_exact_string_set(
            "closure_steps",
            &self.closure_steps,
            &REQUIRED_CLOSURE_STEPS,
        )?;
        for value in [
            &self.rollback_ref,
            &self.run_event_log_ref,
            &self.answer_packet_ref,
        ] {
            validate_token("proof_ref", value)?;
        }
        if self.proof_boundary.log_evidence_attempted
            || self.proof_boundary.manual_runtime_evidence_attempted
            || self.proof_boundary.distribution_evidence_attempted
            || self.proof_boundary.zero_fail_passes_claimed != 0
            || self.proof_boundary.l2_green_claimed
            || self.proof_boundary.l3_green_claimed
            || self.proof_boundary.t4_green_claimed
            || self.proof_boundary.product_green_claimed
            || self.proof_boundary.ship_call_claimed
            || self.proof_boundary.live_dense_70b_claimed
            || self.proof_boundary.ssd_as_ram_claimed
            || self.proof_boundary.hidden_route_authority_claimed
            || self.proof_boundary.route_mutation_claimed
        {
            return Err(ReleaseAuditClosureError::ProofBoundaryBroken);
        }
        if self.byte_ledger.model_runtime_bytes_loaded != 0
            || self.byte_ledger.product_runtime_bytes_loaded != 0
            || self.byte_ledger.provider_bytes_loaded != 0
            || self.byte_ledger.command_bytes_executed != 0
        {
            return Err(ReleaseAuditClosureError::ByteBoundaryBroken);
        }
        let rebuilt_metrics = metrics_for(
            &self.command_rows,
            &self.family_rows,
            &self.closure_steps,
            &self.proof_boundary,
            &self.byte_ledger,
            self.upstream_unique_failure_count,
            &self.upstream_top_family_id,
        )?;
        if rebuilt_metrics != self.metrics {
            return Err(ReleaseAuditClosureError::MetricsMismatch);
        }
        let rebuilt_address = closure_matrix_address(
            &self.upstream_ref,
            &self.family_source_ref,
            self.upstream_overall_pass,
            self.upstream_failed_check_count,
            self.upstream_unique_failure_count,
            &self.upstream_top_family_id,
            &self.command_rows,
            &self.family_rows,
            &self.closure_steps,
            &self.metrics,
        );
        if rebuilt_address != self.address {
            return Err(ReleaseAuditClosureError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_release_audit_closure_check_ids() -> &'static [&'static str] {
    &REQUIRED_CHECK_IDS
}

pub fn required_release_audit_closure_steps() -> &'static [&'static str] {
    &REQUIRED_CLOSURE_STEPS
}

pub fn required_release_audit_closure_top_family_source_refs() -> &'static [&'static str] {
    &TOP_FAMILY_SOURCE_REFS
}

pub fn required_release_audit_closure_top_family_test_refs() -> &'static [&'static str] {
    &TOP_FAMILY_TEST_REFS
}

fn metrics_for(
    command_rows: &[ReleaseAuditClosureCommandRow],
    family_rows: &[ReleaseAuditClosureFamilyRow],
    closure_steps: &[String],
    proof_boundary: &ReleaseAuditClosureProofBoundary,
    byte_ledger: &ReleaseAuditClosureByteLedger,
    unique_failure_count: u64,
    top_family_id: &str,
) -> Result<ReleaseAuditClosureMetrics, ReleaseAuditClosureError> {
    let passed_command_count = command_rows
        .iter()
        .filter(|row| row.status == ReleaseAuditClosureCommandStatus::PassedRetained)
        .count();
    let failed_command_count = command_rows
        .iter()
        .filter(|row| row.status == ReleaseAuditClosureCommandStatus::FailedRetained)
        .count();
    let total_issue_count = family_rows.iter().map(|row| row.issue_count).sum();
    let top = family_rows
        .iter()
        .find(|row| row.family_id == top_family_id)
        .ok_or_else(|| ReleaseAuditClosureError::MissingTopFamily(top_family_id.to_string()))?;
    Ok(ReleaseAuditClosureMetrics {
        command_count: command_rows.len(),
        passed_command_count,
        failed_command_count,
        total_issue_count,
        unique_failure_count,
        family_count: family_rows.len(),
        top_family_id: top.family_id.clone(),
        top_family_issue_count: top.issue_count,
        closure_step_count: closure_steps.len(),
        focused_repair_family_count: family_rows
            .iter()
            .filter(|row| row.status == ReleaseAuditClosureFamilyStatus::FocusedRepairNeeded)
            .count(),
        source_card_repair_proof_count: family_rows
            .iter()
            .filter(|row| row.source_card_is_repair_proof)
            .count(),
        focused_test_full_rerun_replacement_count: family_rows
            .iter()
            .filter(|row| row.focused_test_replaces_full_rerun)
            .count(),
        model_runtime_bytes_loaded: byte_ledger.model_runtime_bytes_loaded,
        product_runtime_bytes_loaded: byte_ledger.product_runtime_bytes_loaded,
        provider_bytes_loaded: byte_ledger.provider_bytes_loaded,
        command_bytes_executed: byte_ledger.command_bytes_executed,
    })
    .and_then(|metrics| {
        if proof_boundary.zero_fail_passes_claimed != 0
            || metrics.command_count != REQUIRED_CHECK_IDS.len()
            || metrics.passed_command_count != 4
            || metrics.failed_command_count != 1
            || metrics.total_issue_count != 161
            || metrics.unique_failure_count != 84
            || metrics.family_count != 15
            || metrics.top_family_id != "graph_filter_visibility"
            || metrics.top_family_issue_count != 34
            || metrics.closure_step_count != REQUIRED_CLOSURE_STEPS.len()
            || metrics.focused_repair_family_count != 1
            || metrics.source_card_repair_proof_count != 0
            || metrics.focused_test_full_rerun_replacement_count != 0
            || metrics.model_runtime_bytes_loaded != 0
            || metrics.product_runtime_bytes_loaded != 0
            || metrics.provider_bytes_loaded != 0
            || metrics.command_bytes_executed != 0
        {
            Err(ReleaseAuditClosureError::MetricsMismatch)
        } else {
            Ok(metrics)
        }
    })
}

fn validate_command_rows(
    rows: &[ReleaseAuditClosureCommandRow],
) -> Result<(), ReleaseAuditClosureError> {
    if rows.len() != REQUIRED_CHECK_IDS.len() {
        return Err(ReleaseAuditClosureError::BadCommandCount(rows.len()));
    }
    let mut seen = BTreeSet::new();
    for row in rows {
        row.clone().validate()?;
        if !seen.insert(row.check_id.as_str()) {
            return Err(ReleaseAuditClosureError::DuplicateCheck(
                row.check_id.clone(),
            ));
        }
    }
    let actual = rows
        .iter()
        .map(|row| row.check_id.as_str())
        .collect::<BTreeSet<_>>();
    let expected = REQUIRED_CHECK_IDS.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(ReleaseAuditClosureError::MissingRequiredCheck);
    }
    Ok(())
}

impl ReleaseAuditClosureCommandRow {
    fn validate(self) -> Result<(), ReleaseAuditClosureError> {
        Self::new(&self.check_id, self.status, self.issue_count, &self.log_ref).map(|_| ())
    }
}

fn validate_family_cards(
    cards: &[ReleaseAuditFailureFamilySourceCard],
) -> Result<(), ReleaseAuditClosureError> {
    if cards.len() != 15 {
        return Err(ReleaseAuditClosureError::BadFamilyCount(cards.len()));
    }
    let mut seen = BTreeSet::new();
    let mut total = 0_u64;
    for card in cards {
        card.validate()
            .map_err(|error| ReleaseAuditClosureError::BadFamilyCard(error.to_string()))?;
        if !seen.insert(card.family_id.as_str()) {
            return Err(ReleaseAuditClosureError::DuplicateFamily(
                card.family_id.clone(),
            ));
        }
        total = total.saturating_add(card.issue_count);
    }
    if total != 161 || !seen.contains("graph_filter_visibility") {
        return Err(ReleaseAuditClosureError::FamilyLedgerMismatch);
    }
    Ok(())
}

fn validate_family_rows(
    rows: &[ReleaseAuditClosureFamilyRow],
    top_family_id: &str,
) -> Result<(), ReleaseAuditClosureError> {
    if rows.len() != 15 {
        return Err(ReleaseAuditClosureError::BadFamilyCount(rows.len()));
    }
    let mut seen = BTreeSet::new();
    let mut rank_seen = BTreeSet::new();
    for row in rows {
        row.validate(top_family_id)?;
        if !seen.insert(row.family_id.as_str()) {
            return Err(ReleaseAuditClosureError::DuplicateFamily(
                row.family_id.clone(),
            ));
        }
        if !rank_seen.insert(row.repair_rank) {
            return Err(ReleaseAuditClosureError::DuplicateRepairRank(
                row.repair_rank,
            ));
        }
    }
    Ok(())
}

fn validate_exact_string_set(
    field: &'static str,
    values: &[String],
    required: &[&'static str],
) -> Result<(), ReleaseAuditClosureError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(ReleaseAuditClosureError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(ReleaseAuditClosureError::MissingRequiredSet {
            field,
            actual: values.len(),
            expected: required.len(),
        });
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), ReleaseAuditClosureError> {
    validate_token("upstream_ref", value)?;
    if value != RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_UPSTREAM_REF {
        return Err(ReleaseAuditClosureError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), ReleaseAuditClosureError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains(RELEASE_AUDIT_FAILURE_FAMILY_SOURCE_CARD_ID)
    {
        return Err(ReleaseAuditClosureError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), ReleaseAuditClosureError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(ReleaseAuditClosureError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), ReleaseAuditClosureError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(ReleaseAuditClosureError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn closure_matrix_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_failed_check_count: u64,
    upstream_unique_failure_count: u64,
    upstream_top_family_id: &str,
    command_rows: &[ReleaseAuditClosureCommandRow],
    family_rows: &[ReleaseAuditClosureFamilyRow],
    closure_steps: &[String],
    metrics: &ReleaseAuditClosureMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_ID);
    preimage.push_str(RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_CURSOR);
    preimage.push_str(RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_NEXT_CURSOR);
    preimage.push_str(upstream_ref);
    preimage.push_str(family_source_ref);
    preimage.push_str(&upstream_overall_pass.to_string());
    preimage.push_str(&upstream_failed_check_count.to_string());
    preimage.push_str(&upstream_unique_failure_count.to_string());
    preimage.push_str(upstream_top_family_id);
    preimage.push_str(&format!("{command_rows:?}"));
    preimage.push_str(&format!("{family_rows:?}"));
    preimage.push_str(&format!("{closure_steps:?}"));
    preimage.push_str(&format!("{metrics:?}"));
    sha256_hex(preimage.as_bytes())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:release-audit-automated-checks-closure-matrix:error
// Plane: Verification.
// Residency: fail-closed closure matrix validation errors.
pub enum ReleaseAuditClosureError {
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
    BadUpstreamRef,
    BadFamilySourceRef,
    UpstreamRedLedgerMismatch,
    UnknownCheck(String),
    BadCommandCount(usize),
    MissingRequiredCheck,
    DuplicateCheck(String),
    UnexpectedFailedCheck(String),
    XcodebuildTestNotRetainedRed,
    FailedCheckHasZeroIssues,
    PassedCheckHasIssues(String),
    BadFamilyCard(String),
    BadFamilyCount(usize),
    MissingTopFamily(String),
    TopFamilyNotFocused,
    ZeroIssueFamily(String),
    DuplicateFamily(String),
    DuplicateRepairRank(u64),
    FamilyLedgerMismatch,
    MissingRepairRefs(String),
    InvalidRepairRank,
    RepairProofBoundaryBroken,
    ProofBoundaryBroken,
    ByteBoundaryBroken,
    MetricsMismatch,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for ReleaseAuditClosureError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for ReleaseAuditClosureError {}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::uas::ReleaseAuditFailureFamilySourceCard;

    fn family_counts() -> BTreeMap<&'static str, u64> {
        BTreeMap::from([
            ("agent_route_policy", 21),
            ("body_read_checksum", 1),
            ("distribution_project_integrity", 18),
            ("editor_epdoc_surface", 14),
            ("graph_filter_visibility", 34),
            ("model_vault_catalog", 9),
            ("research_tool_catalog", 16),
            ("runtime_performance_policy", 3),
            ("search_index", 1),
            ("source_guard_drift", 3),
            ("theme_presentation", 19),
            ("tool_execution_surface", 2),
            ("ui_shell_source_guard", 14),
            ("visible_output_sanitization", 5),
            ("xpc_trust_configuration", 1),
        ])
    }

    fn cards() -> Vec<ReleaseAuditFailureFamilySourceCard> {
        family_counts()
            .iter()
            .map(|(family, count)| {
                ReleaseAuditFailureFamilySourceCard::new(family, *count).expect("valid source card")
            })
            .collect()
    }

    fn commands() -> Vec<ReleaseAuditClosureCommandRow> {
        REQUIRED_CHECK_IDS
            .iter()
            .map(|check| {
                let failed = *check == "xcodebuild_test";
                ReleaseAuditClosureCommandRow::new(
                    check,
                    if failed {
                        ReleaseAuditClosureCommandStatus::FailedRetained
                    } else {
                        ReleaseAuditClosureCommandStatus::PassedRetained
                    },
                    if failed { 161 } else { 0 },
                    &format!("artifact_log:{check}"),
                )
                .expect("valid command row")
            })
            .collect()
    }

    fn witness() -> ReleaseAuditAutomatedChecksClosureMatrixWitness {
        ReleaseAuditAutomatedChecksClosureMatrixWitness::new(
            RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_UPSTREAM_REF,
            RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_FAMILY_SOURCE_REF,
            false,
            1,
            84,
            "graph_filter_visibility",
            commands(),
            cards(),
        )
        .expect("valid closure matrix")
    }

    #[test]
    fn accepts_retained_red_automated_checks_closure_matrix() {
        let witness = witness();
        witness.validate().expect("witness validates");
        assert_eq!(witness.metrics.command_count, 5);
        assert_eq!(witness.metrics.failed_command_count, 1);
        assert_eq!(witness.metrics.total_issue_count, 161);
        assert_eq!(witness.metrics.top_family_id, "graph_filter_visibility");
        assert_eq!(witness.metrics.focused_repair_family_count, 1);
        assert!(witness.metadata_only);
        assert!(witness.no_product_promotion);
        assert!(witness.address.starts_with("sha256:"));
    }

    #[test]
    fn rejects_green_upstream_or_wrong_command_status() {
        assert_eq!(
            ReleaseAuditAutomatedChecksClosureMatrixWitness::new(
                RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_UPSTREAM_REF,
                RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_FAMILY_SOURCE_REF,
                true,
                0,
                0,
                "graph_filter_visibility",
                commands(),
                cards(),
            )
            .err(),
            Some(ReleaseAuditClosureError::UpstreamRedLedgerMismatch)
        );
        assert!(ReleaseAuditClosureCommandRow::new(
            "xcodebuild_test",
            ReleaseAuditClosureCommandStatus::PassedRetained,
            0,
            "artifact_log:xcodebuild_test",
        )
        .is_err());
        assert!(ReleaseAuditClosureCommandRow::new(
            "graph_engine_cargo_test",
            ReleaseAuditClosureCommandStatus::FailedRetained,
            1,
            "artifact_log:graph_engine_cargo_test",
        )
        .is_err());
    }

    #[test]
    fn rejects_missing_top_family_or_repair_proof_overclaim() {
        let mut cards = cards();
        cards.retain(|card| card.family_id != "graph_filter_visibility");
        assert!(ReleaseAuditAutomatedChecksClosureMatrixWitness::new(
            RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_UPSTREAM_REF,
            RELEASE_AUDIT_AUTOMATED_CHECKS_CLOSURE_MATRIX_FAMILY_SOURCE_REF,
            false,
            1,
            84,
            "graph_filter_visibility",
            commands(),
            cards,
        )
        .is_err());

        let mut witness = witness();
        let top = witness
            .family_rows
            .iter_mut()
            .find(|row| row.family_id == "graph_filter_visibility")
            .expect("top family");
        top.source_card_is_repair_proof = true;
        assert!(witness.validate().is_err());
    }

    #[test]
    fn rejects_product_promotion_and_byte_leaks() {
        let mut promoted = witness();
        promoted.proof_boundary.l3_green_claimed = true;
        assert!(promoted.validate().is_err());

        let mut large_model_overclaim = witness();
        large_model_overclaim.proof_boundary.live_dense_70b_claimed = true;
        assert!(large_model_overclaim.validate().is_err());

        let mut model_byte_leak = witness();
        model_byte_leak.byte_ledger.model_runtime_bytes_loaded = 1;
        assert!(model_byte_leak.validate().is_err());

        let mut command_byte_leak = witness();
        command_byte_leak.byte_ledger.command_bytes_executed = 1;
        assert!(command_byte_leak.validate().is_err());
    }
}
