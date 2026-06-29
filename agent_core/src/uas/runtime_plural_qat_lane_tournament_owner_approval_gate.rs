//! Runtime-plural QAT lane tournament owner-approval gate.
//!
//! Metadata-only T1/L1 successor to `runtime_plural_qat_lane_tournament_plan`.
//! Per Deep Research Pass 68 (docs/fusion/DEEP_RESEARCH_BREAKTHROUGH_SYNTHESIS_2026_06_06.md)
//! and docs/fusion/TURBOVEC_QAT_RUNTIME_AGNOSTIC_INTAKE_2026_06_06.md, this is a
//! **fail-closed owner-approval and command/package lease** before any tiny
//! same-fixture proof can run. It consumes the tournament plan, carries ONLY the
//! E2B GGUF direct-CLI candidate as the future probe lane, and keeps LiteRT-LM,
//! MLX Swift, MLX-LM, local endpoints, 12B, 31B, and 70B-class routes
//! denied/deferred/vaulted until their separate proof exists.
//!
//! The canonical witness models the safe default: owner approval ABSENT, so no
//! same-fixture proof is authorized. It requires (but never satisfies here) the
//! exact owner-approval phrase, a model-path proof, a command/package lease, a
//! timeout, a memory budget, cancellation, and a rollback envelope. It loads
//! zero bytes, runs no command, and promotes no runtime route to product.

use crate::uas::runtime_plural_qat_lane_tournament_plan::RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_PLAN_CURSOR;
use crate::uas::{ProStatus, UasAddress, UasKind};
use serde::{Deserialize, Serialize};
use std::fmt;

pub const RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_OWNER_APPROVAL_GATE_ID: &str =
    "F-RuntimePlural-QATLaneTournamentOwnerApprovalGate";
pub const RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_OWNER_APPROVAL_GATE_CURSOR: &str =
    "runtime_plural_qat_lane_tournament_owner_approval_gate";
/// The successor — the actual owner-approved one-token same-fixture runtime
/// probe — is the owner-gated frontier (needs real bytes + a signed run).
pub const RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_OWNER_APPROVAL_GATE_NEXT_CURSOR: &str =
    "runtime_plural_e2b_gguf_same_fixture_owner_gated_runtime_probe_frontier";

const APPROVAL_PHRASE: &str = "APPROVE_RUNTIME_PLURAL_E2B_GGUF_SAME_FIXTURE_PROBE_V0";
/// The single lane carried forward as a FUTURE probe candidate (not run here).
const CARRIED_CANDIDATE_LANE: &str = "gguf_llama_cpp_e2b_direct_cli";
/// Every other runtime route stays denied/deferred/vaulted until separate proof.
const DENIED_DEFERRED_VAULTED_ROUTES: [&str; 7] = [
    "litert_lm_swift",
    "mlx_swift_candidate",
    "mlx_lm_python_research",
    "local_openai_endpoint",
    "gemma4_12b_route",
    "gemma4_31b_route",
    "dense_70b_route",
];
const LEASE_REF: &str =
    "command_package_lease:runtime_plural_qat_lane_tournament_owner_approval_gate";
const MODEL_PATH_PROOF_REF: &str = "model_path_proof:google/gemma-4-E2B-it-qat-q4_0-gguf";
const CANCEL_REF: &str = "cancel:runtime_plural_qat_lane_tournament_owner_approval_gate";
const ROLLBACK_REF: &str = "rollback:runtime_plural_qat_lane_tournament_owner_approval_gate";
const RUN_EVENT_LOG_REF: &str =
    "run_event_log:runtime_plural_qat_lane_tournament_owner_approval_gate";
const ANSWER_PACKET_REF: &str =
    "answer_packet:runtime_plural_qat_lane_tournament_owner_approval_gate";
const GUARD_PRODUCT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";
/// Fixed so the canonical witness address is deterministic (the address hash is
/// over the preimage, not the timestamp; this keeps the stored value stable).
const FIXED_CREATED_AT_MS: u64 = 0;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
// UAS: uas:runtime-plural-qat-tournament-owner-approval:status
// Plane: Verification + Controller.
// Residency: metadata-only owner-approval gate; no probe runs, no bytes loaded.
pub enum RuntimePluralQatOwnerApprovalStatus {
    OwnerApprovalAbsentSameFixtureProbeBlocked,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:runtime-plural-qat-tournament-owner-approval:spec
// Plane: Verification + Controller.
// Residency: fail-closed owner-approval + lease contract for the future E2B GGUF probe.
pub struct RuntimePluralQatLaneTournamentOwnerApprovalGate {
    pub upstream_plan_cursor: String,
    pub owner_approval_phrase: String,
    /// The phrase actually presented. Empty = absent (canonical safe state).
    pub provided_approval_phrase: String,
    /// Derived: true iff `provided_approval_phrase` equals the exact phrase.
    pub owner_approval_present: bool,
    pub exact_phrase_required: bool,
    pub command_package_lease_ref: String,
    pub model_path_proof_ref: String,
    pub planned_timeout_ms: u64,
    pub planned_memory_budget_bytes: u64,
    pub cancellation_ref: String,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub carried_candidate_lane: String,
    pub denied_deferred_vaulted_routes: Vec<String>,
    pub pro_status: ProStatus,
    pub guard_owned_product_cursor: String,
    // Fail-closed proof requirements (all required, none satisfied here).
    pub same_fixture_required: bool,
    pub fixture_redacted_required: bool,
    pub byte_ledger_required: bool,
    pub memory_preflight_required: bool,
    pub cancellation_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub no_product_route_authority: bool,
    /// This gate never authorizes the probe; owner approval only unblocks the
    /// separate (still-gated) runtime probe. Canonical and every valid witness
    /// keep this false.
    pub same_fixture_probe_authorized: bool,
    // Zero ledger — must all stay zero.
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub package_resolved_count: u64,
    pub command_executions: u64,
    pub benchmark_runs: u64,
    pub product_files_copied: u64,
    pub filesystem_stat_calls: u64,
    // No-promotion claims — must all stay false.
    pub first_token_claimed: bool,
    pub speed_claimed: bool,
    pub quality_claimed: bool,
    pub mas_readiness_claimed: bool,
    pub l2_capability_claimed: bool,
    pub l3_wrv_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub litert_package_safe_claimed: bool,
    pub mlx_loader_support_claimed: bool,
    pub local_endpoint_safe_claimed: bool,
    pub server_sidecar_default_allowed: bool,
    pub hidden_route_authority_claimed: bool,
    pub metadata_only: bool,
    pub status: RuntimePluralQatOwnerApprovalStatus,
}

impl RuntimePluralQatLaneTournamentOwnerApprovalGate {
    pub fn canonical() -> Self {
        Self {
            upstream_plan_cursor: RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_PLAN_CURSOR.to_string(),
            owner_approval_phrase: APPROVAL_PHRASE.to_string(),
            provided_approval_phrase: String::new(),
            owner_approval_present: false,
            exact_phrase_required: true,
            command_package_lease_ref: LEASE_REF.to_string(),
            model_path_proof_ref: MODEL_PATH_PROOF_REF.to_string(),
            planned_timeout_ms: 30_000,
            planned_memory_budget_bytes: 6 * 1024 * 1024 * 1024,
            cancellation_ref: CANCEL_REF.to_string(),
            rollback_ref: ROLLBACK_REF.to_string(),
            run_event_log_ref: RUN_EVENT_LOG_REF.to_string(),
            answer_packet_ref: ANSWER_PACKET_REF.to_string(),
            carried_candidate_lane: CARRIED_CANDIDATE_LANE.to_string(),
            denied_deferred_vaulted_routes: DENIED_DEFERRED_VAULTED_ROUTES
                .iter()
                .map(|route| route.to_string())
                .collect(),
            pro_status: ProStatus::Gated,
            guard_owned_product_cursor: GUARD_PRODUCT_CURSOR.to_string(),
            same_fixture_required: true,
            fixture_redacted_required: true,
            byte_ledger_required: true,
            memory_preflight_required: true,
            cancellation_required: true,
            rollback_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            no_product_route_authority: true,
            same_fixture_probe_authorized: false,
            model_bytes_loaded: 0,
            runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            package_resolved_count: 0,
            command_executions: 0,
            benchmark_runs: 0,
            product_files_copied: 0,
            filesystem_stat_calls: 0,
            first_token_claimed: false,
            speed_claimed: false,
            quality_claimed: false,
            mas_readiness_claimed: false,
            l2_capability_claimed: false,
            l3_wrv_claimed: false,
            live_dense_70b_claimed: false,
            litert_package_safe_claimed: false,
            mlx_loader_support_claimed: false,
            local_endpoint_safe_claimed: false,
            server_sidecar_default_allowed: false,
            hidden_route_authority_claimed: false,
            metadata_only: true,
            status: RuntimePluralQatOwnerApprovalStatus::OwnerApprovalAbsentSameFixtureProbeBlocked,
        }
    }

    pub fn validate(&self) -> Result<(), RuntimePluralQatOwnerApprovalError> {
        validate_exact(
            "upstream_plan_cursor",
            &self.upstream_plan_cursor,
            RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_PLAN_CURSOR,
        )?;
        validate_exact(
            "owner_approval_phrase",
            &self.owner_approval_phrase,
            APPROVAL_PHRASE,
        )?;
        validate_exact(
            "command_package_lease_ref",
            &self.command_package_lease_ref,
            LEASE_REF,
        )?;
        validate_exact(
            "model_path_proof_ref",
            &self.model_path_proof_ref,
            MODEL_PATH_PROOF_REF,
        )?;
        validate_exact("cancellation_ref", &self.cancellation_ref, CANCEL_REF)?;
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
            "carried_candidate_lane",
            &self.carried_candidate_lane,
            CARRIED_CANDIDATE_LANE,
        )?;
        validate_exact(
            "guard_owned_product_cursor",
            &self.guard_owned_product_cursor,
            GUARD_PRODUCT_CURSOR,
        )?;

        self.validate_lane_policy()?;
        self.validate_consent()?;
        self.validate_proof_policy()?;
        self.validate_zero_ledger()?;

        if self.pro_status != ProStatus::Gated {
            return Err(RuntimePluralQatOwnerApprovalError::WrongProStatus);
        }
        if !self.metadata_only {
            return Err(RuntimePluralQatOwnerApprovalError::MetadataBoundaryBroken);
        }
        if self.first_token_claimed
            || self.speed_claimed
            || self.quality_claimed
            || self.mas_readiness_claimed
            || self.l2_capability_claimed
            || self.l3_wrv_claimed
            || self.live_dense_70b_claimed
            || self.litert_package_safe_claimed
            || self.mlx_loader_support_claimed
            || self.local_endpoint_safe_claimed
            || self.server_sidecar_default_allowed
            || self.hidden_route_authority_claimed
        {
            return Err(RuntimePluralQatOwnerApprovalError::PromotionClaim);
        }
        if self.status
            != RuntimePluralQatOwnerApprovalStatus::OwnerApprovalAbsentSameFixtureProbeBlocked
        {
            return Err(RuntimePluralQatOwnerApprovalError::WrongStatus);
        }
        Ok(())
    }

    fn validate_lane_policy(&self) -> Result<(), RuntimePluralQatOwnerApprovalError> {
        let expected: Vec<String> = DENIED_DEFERRED_VAULTED_ROUTES
            .iter()
            .map(|route| route.to_string())
            .collect();
        if self.denied_deferred_vaulted_routes != expected {
            return Err(RuntimePluralQatOwnerApprovalError::LanePolicyBroken);
        }
        // The carried lane must never appear in the denied set, and the denied
        // set must cover every non-GGUF route (no accidental promotion).
        if self
            .denied_deferred_vaulted_routes
            .iter()
            .any(|route| route == &self.carried_candidate_lane)
        {
            return Err(RuntimePluralQatOwnerApprovalError::LanePolicyBroken);
        }
        Ok(())
    }

    fn validate_consent(&self) -> Result<(), RuntimePluralQatOwnerApprovalError> {
        if !self.exact_phrase_required {
            return Err(RuntimePluralQatOwnerApprovalError::ConsentContractBroken);
        }
        if !self.provided_approval_phrase.is_empty()
            && self.provided_approval_phrase != APPROVAL_PHRASE
        {
            return Err(RuntimePluralQatOwnerApprovalError::WrongApprovalPhrase);
        }
        let derived_present = self.provided_approval_phrase == APPROVAL_PHRASE;
        if self.owner_approval_present != derived_present {
            return Err(RuntimePluralQatOwnerApprovalError::ConsentClaimMismatch);
        }
        // Even WITH consent, this gate never authorizes the probe — that is the
        // separate, still-gated runtime probe (the NEXT_CURSOR frontier).
        if self.same_fixture_probe_authorized {
            return Err(RuntimePluralQatOwnerApprovalError::ProbeAuthorizationLeak);
        }
        Ok(())
    }

    fn validate_proof_policy(&self) -> Result<(), RuntimePluralQatOwnerApprovalError> {
        if !self.same_fixture_required
            || !self.fixture_redacted_required
            || !self.byte_ledger_required
            || !self.memory_preflight_required
            || !self.cancellation_required
            || !self.rollback_required
            || !self.run_event_log_required
            || !self.answer_packet_required
            || !self.no_product_route_authority
        {
            return Err(RuntimePluralQatOwnerApprovalError::ProofPolicyBroken);
        }
        if self.planned_timeout_ms == 0 || self.planned_memory_budget_bytes == 0 {
            return Err(RuntimePluralQatOwnerApprovalError::ProofPolicyBroken);
        }
        Ok(())
    }

    fn validate_zero_ledger(&self) -> Result<(), RuntimePluralQatOwnerApprovalError> {
        if self.model_bytes_loaded != 0
            || self.runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.package_resolved_count != 0
            || self.command_executions != 0
            || self.benchmark_runs != 0
            || self.product_files_copied != 0
            || self.filesystem_stat_calls != 0
        {
            return Err(RuntimePluralQatOwnerApprovalError::ByteOrCommandLeak);
        }
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:runtime-plural-qat-tournament-owner-approval:metrics
// Plane: Verification.
// Residency: metadata-only owner-approval counters.
pub struct RuntimePluralQatOwnerApprovalMetrics {
    pub owner_approval_present: bool,
    pub denied_route_count: u64,
    pub proof_requirement_count: u64,
    pub model_bytes_loaded: u64,
    pub runtime_bytes_loaded: u64,
    pub command_executions: u64,
    pub promotion_claim_count: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:runtime-plural-qat-tournament-owner-approval:witness
// Plane: Verification + Controller.
// Residency: L1/T1 owner-approval gate; no probe runs, no bytes loaded.
pub struct RuntimePluralQatLaneTournamentOwnerApprovalWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub spec: RuntimePluralQatLaneTournamentOwnerApprovalGate,
    pub metrics: RuntimePluralQatOwnerApprovalMetrics,
    pub address: UasAddress,
    pub metadata_only: bool,
    pub product_promotion_blocked: bool,
}

impl RuntimePluralQatLaneTournamentOwnerApprovalWitness {
    pub fn new() -> Result<Self, RuntimePluralQatOwnerApprovalError> {
        let spec = RuntimePluralQatLaneTournamentOwnerApprovalGate::canonical();
        spec.validate()?;
        let metrics = RuntimePluralQatOwnerApprovalMetrics {
            owner_approval_present: spec.owner_approval_present,
            denied_route_count: spec.denied_deferred_vaulted_routes.len() as u64,
            proof_requirement_count: 9,
            model_bytes_loaded: spec.model_bytes_loaded,
            runtime_bytes_loaded: spec.runtime_bytes_loaded,
            command_executions: spec.command_executions,
            promotion_claim_count: 0,
        };
        let address = owner_approval_gate_address(&spec, &metrics);
        Ok(Self {
            falsifier_id: RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_OWNER_APPROVAL_GATE_ID.to_string(),
            cursor: RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_OWNER_APPROVAL_GATE_CURSOR.to_string(),
            next_cursor: RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_OWNER_APPROVAL_GATE_NEXT_CURSOR
                .to_string(),
            spec,
            metrics,
            address,
            metadata_only: true,
            product_promotion_blocked: true,
        })
    }

    pub fn validate(&self) -> Result<(), RuntimePluralQatOwnerApprovalError> {
        if self.falsifier_id != RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_OWNER_APPROVAL_GATE_ID
            || self.cursor != RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_OWNER_APPROVAL_GATE_CURSOR
            || self.next_cursor
                != RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_OWNER_APPROVAL_GATE_NEXT_CURSOR
            || !self.metadata_only
            || !self.product_promotion_blocked
        {
            return Err(RuntimePluralQatOwnerApprovalError::WitnessHeaderBroken);
        }
        self.spec.validate()?;
        let rebuilt = Self::new()?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(RuntimePluralQatOwnerApprovalError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn owner_approval_gate_address(
    spec: &RuntimePluralQatLaneTournamentOwnerApprovalGate,
    metrics: &RuntimePluralQatOwnerApprovalMetrics,
) -> UasAddress {
    let preimage = serde_json::json!({
        "id": RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_OWNER_APPROVAL_GATE_ID,
        "spec": spec,
        "metrics": metrics,
    })
    .to_string();
    UasAddress::new(
        UasKind::Other(RUNTIME_PLURAL_QAT_LANE_TOURNAMENT_OWNER_APPROVAL_GATE_CURSOR.to_string()),
        preimage.as_bytes(),
        FIXED_CREATED_AT_MS,
    )
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:runtime-plural-qat-tournament-owner-approval:error
// Plane: Verification.
// Residency: fail-closed owner-approval rejection taxonomy.
pub enum RuntimePluralQatOwnerApprovalError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    WrongValue(&'static str),
    LanePolicyBroken,
    ConsentContractBroken,
    WrongApprovalPhrase,
    ConsentClaimMismatch,
    ProbeAuthorizationLeak,
    ProofPolicyBroken,
    ByteOrCommandLeak,
    WrongProStatus,
    MetadataBoundaryBroken,
    PromotionClaim,
    WrongStatus,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for RuntimePluralQatOwnerApprovalError {
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
            Self::LanePolicyBroken => write!(f, "runtime lane denial policy broken"),
            Self::ConsentContractBroken => write!(f, "consent contract broken"),
            Self::WrongApprovalPhrase => write!(f, "wrong owner approval phrase"),
            Self::ConsentClaimMismatch => {
                write!(
                    f,
                    "owner_approval_present does not match the provided phrase"
                )
            }
            Self::ProbeAuthorizationLeak => {
                write!(
                    f,
                    "owner-approval gate must not authorize the runtime probe"
                )
            }
            Self::ProofPolicyBroken => write!(f, "proof/lease policy broken"),
            Self::ByteOrCommandLeak => write!(f, "byte or command leak"),
            Self::WrongProStatus => write!(f, "wrong pro status (must be Gated)"),
            Self::MetadataBoundaryBroken => write!(f, "metadata boundary broken"),
            Self::PromotionClaim => write!(f, "promotion claim attempted"),
            Self::WrongStatus => write!(f, "wrong owner approval status"),
            Self::WitnessHeaderBroken => write!(f, "witness header broken"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for RuntimePluralQatOwnerApprovalError {}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), RuntimePluralQatOwnerApprovalError> {
    validate_token(field, value)?;
    if value != expected {
        return Err(RuntimePluralQatOwnerApprovalError::WrongValue(field));
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), RuntimePluralQatOwnerApprovalError> {
    if value.is_empty() {
        return Err(RuntimePluralQatOwnerApprovalError::MissingField(field));
    }
    if value.trim() != value {
        return Err(RuntimePluralQatOwnerApprovalError::FieldHasSurroundingWhitespace(field));
    }
    if value.chars().any(char::is_control) {
        return Err(RuntimePluralQatOwnerApprovalError::FieldContainsControlCharacter(field));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_gate_validates() {
        RuntimePluralQatLaneTournamentOwnerApprovalGate::canonical()
            .validate()
            .expect("canonical validates");
    }

    #[test]
    fn witness_is_deterministic_and_approval_absent() {
        let first = RuntimePluralQatLaneTournamentOwnerApprovalWitness::new().expect("first");
        let second = RuntimePluralQatLaneTournamentOwnerApprovalWitness::new().expect("second");
        assert_eq!(first.address, second.address);
        assert!(!first.metrics.owner_approval_present);
        assert_eq!(first.metrics.denied_route_count, 7);
        assert_eq!(first.metrics.runtime_bytes_loaded, 0);
        assert_eq!(first.metrics.command_executions, 0);
    }

    #[test]
    fn witness_validates_end_to_end() {
        RuntimePluralQatLaneTournamentOwnerApprovalWitness::new()
            .expect("witness")
            .validate()
            .expect("witness validates");
    }

    #[test]
    fn rejects_wrong_upstream_plan_cursor() {
        let mut gate = RuntimePluralQatLaneTournamentOwnerApprovalGate::canonical();
        gate.upstream_plan_cursor = "some_other_plan".to_string();
        assert_eq!(
            gate.validate().unwrap_err(),
            RuntimePluralQatOwnerApprovalError::WrongValue("upstream_plan_cursor")
        );
    }

    #[test]
    fn rejects_wrong_provided_phrase() {
        let mut gate = RuntimePluralQatLaneTournamentOwnerApprovalGate::canonical();
        gate.provided_approval_phrase = "approve".to_string();
        assert_eq!(
            gate.validate().unwrap_err(),
            RuntimePluralQatOwnerApprovalError::WrongApprovalPhrase
        );
    }

    #[test]
    fn rejects_consent_claimed_without_phrase() {
        let mut gate = RuntimePluralQatLaneTournamentOwnerApprovalGate::canonical();
        gate.owner_approval_present = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            RuntimePluralQatOwnerApprovalError::ConsentClaimMismatch
        );
    }

    #[test]
    fn exact_phrase_implies_consent_but_no_probe() {
        let mut gate = RuntimePluralQatLaneTournamentOwnerApprovalGate::canonical();
        gate.provided_approval_phrase = APPROVAL_PHRASE.to_string();
        gate.owner_approval_present = true;
        gate.validate().expect("exact-phrase consent validates");
        assert!(!gate.same_fixture_probe_authorized);
        assert_eq!(gate.runtime_bytes_loaded, 0);
    }

    #[test]
    fn rejects_probe_authorization_leak() {
        let mut gate = RuntimePluralQatLaneTournamentOwnerApprovalGate::canonical();
        gate.same_fixture_probe_authorized = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            RuntimePluralQatOwnerApprovalError::ProbeAuthorizationLeak
        );
    }

    #[test]
    fn rejects_carried_lane_in_denied_set() {
        let mut gate = RuntimePluralQatLaneTournamentOwnerApprovalGate::canonical();
        gate.denied_deferred_vaulted_routes[0] = CARRIED_CANDIDATE_LANE.to_string();
        assert_eq!(
            gate.validate().unwrap_err(),
            RuntimePluralQatOwnerApprovalError::LanePolicyBroken
        );
    }

    #[test]
    fn rejects_dropped_denied_route() {
        let mut gate = RuntimePluralQatLaneTournamentOwnerApprovalGate::canonical();
        gate.denied_deferred_vaulted_routes.pop();
        assert_eq!(
            gate.validate().unwrap_err(),
            RuntimePluralQatOwnerApprovalError::LanePolicyBroken
        );
    }

    #[test]
    fn rejects_proof_policy_bypass() {
        let mut gate = RuntimePluralQatLaneTournamentOwnerApprovalGate::canonical();
        gate.answer_packet_required = false;
        assert_eq!(
            gate.validate().unwrap_err(),
            RuntimePluralQatOwnerApprovalError::ProofPolicyBroken
        );
    }

    #[test]
    fn rejects_zero_budget() {
        let mut gate = RuntimePluralQatLaneTournamentOwnerApprovalGate::canonical();
        gate.planned_memory_budget_bytes = 0;
        assert_eq!(
            gate.validate().unwrap_err(),
            RuntimePluralQatOwnerApprovalError::ProofPolicyBroken
        );
    }

    #[test]
    fn rejects_byte_or_command_leak() {
        let mut gate = RuntimePluralQatLaneTournamentOwnerApprovalGate::canonical();
        gate.runtime_bytes_loaded = 1;
        assert_eq!(
            gate.validate().unwrap_err(),
            RuntimePluralQatOwnerApprovalError::ByteOrCommandLeak
        );
    }

    #[test]
    fn rejects_non_gated_pro_status() {
        let mut gate = RuntimePluralQatLaneTournamentOwnerApprovalGate::canonical();
        gate.pro_status = ProStatus::Live;
        assert_eq!(
            gate.validate().unwrap_err(),
            RuntimePluralQatOwnerApprovalError::WrongProStatus
        );
    }

    #[test]
    fn rejects_promotion_claim() {
        let mut gate = RuntimePluralQatLaneTournamentOwnerApprovalGate::canonical();
        gate.live_dense_70b_claimed = true;
        assert_eq!(
            gate.validate().unwrap_err(),
            RuntimePluralQatOwnerApprovalError::PromotionClaim
        );
    }
}
