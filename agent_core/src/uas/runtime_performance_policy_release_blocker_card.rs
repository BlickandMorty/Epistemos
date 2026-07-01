use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_ID: &str =
    "F-RuntimePerformancePolicy-ReleaseBlockerCard";
pub const RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_CURSOR: &str =
    "runtime_performance_policy_release_blocker_card";
pub const RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_NEXT_CURSOR: &str =
    "body_read_checksum_release_blocker_card";
pub const RUNTIME_PERFORMANCE_POLICY_UPSTREAM_REF: &str = "artifact:falsifiers/ui_shell_source_guard_release_blocker_card/result.json#F-UiShellSourceGuard-ReleaseBlockerCard";
pub const RUNTIME_PERFORMANCE_POLICY_FAMILY_SOURCE_REF: &str = "artifact:falsifiers/release_audit_failure_family_source_card/result.json#runtime_performance_policy";

const REQUIRED_SOURCE_REFS: [&str; 15] = [
    "Epistemos/Engine/BackendRuntimeContract.swift",
    "Epistemos/Engine/TriageService.swift",
    "Epistemos/Engine/AppleIntelligenceService.swift",
    "Epistemos/Engine/RuntimeExecutor.swift",
    "Epistemos/Engine/MetalRuntimeManager.swift",
    "Epistemos/State/ThermalGuard.swift",
    "Epistemos/State/ThermalMonitor.swift",
    "Epistemos/State/InferenceState.swift",
    "Epistemos/Engine/RuntimeExecutor.swift",
    "Epistemos/Views/Settings/PerformanceSettingsSection.swift",
    "EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests.swift",
    "EpistemosTests/PerfBudgetsTests.swift",
    "EpistemosTests/ResourceRuntimeRegressionTests.swift",
    "EpistemosTests/BackendRuntimeContractTests.swift",
    "EpistemosTests/Benchmarks/R15BenchmarkEvidenceLedgerTests.swift",
];

const REQUIRED_INVARIANTS: [&str; 12] = [
    "runtime_performance_policy_is_measurement_not_route_proof",
    "p95_p99_latency_budgets_must_be_visible",
    "thermal_pressure_defers_or_abstains_before_runtime_claim",
    "memory_pressure_blocks_large_model_auto_route",
    "timeouts_and_cancellation_required_for_live_lanes",
    "benchmark_baselines_do_not_replace_fresh_runtime_logs",
    "settings_performance_controls_do_not_unlock_routes",
    "runtime_router_perf_decisions_require_answer_packet",
    "mas_pro_runtime_budget_boundaries_remain_explicit",
    "stale_or_missing_benchmark_evidence_stays_red",
    "focused_performance_tests_required_before_wrv_promotion",
    "release_family_red_until_runtime_perf_failures_repaired",
];

// UAS: uas:runtime-performance-policy-release-blocker-card:organ
// Plane: Verification.
// Residency: metadata-only runtime performance policy source-card classification.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RuntimePerformancePolicyOrgan {
    RuntimePerformancePolicy,
    BackendRuntimeContract,
    ThermalPolicy,
    BenchmarkEvidence,
}

// UAS: uas:runtime-performance-policy-release-blocker-card:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RuntimePerformancePolicyStatus {
    RedReleaseBlocker,
}

// UAS: uas:runtime-performance-policy-release-blocker-card:card
// Plane: Verification.
// Residency: metadata-only source-card blocker; no benchmark/model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RuntimePerformancePolicyReleaseBlockerCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: RuntimePerformancePolicyOrgan,
    pub status: RuntimePerformancePolicyStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub mas_status: String,
    pub pro_status: String,
    pub performance_surface_as_capability_proof: bool,
    pub benchmark_as_runtime_proof: bool,
    pub stale_benchmark_baseline_accepted: bool,
    pub thermal_policy_bypassed: bool,
    pub memory_pressure_bypassed: bool,
    pub cancellation_timeout_missing: bool,
    pub runtime_lane_performance_unbounded: bool,
    pub settings_performance_unlocks_route: bool,
    pub answer_packet_caveat_hidden: bool,
    pub mas_pro_boundary_collapsed: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub benchmark_bytes_loaded: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl RuntimePerformancePolicyReleaseBlockerCard {
    pub fn from_family(
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, RuntimePerformancePolicyError> {
        validate_token("family_id", family_id)?;
        if family_id != "runtime_performance_policy" {
            return Err(RuntimePerformancePolicyError::WrongFamily(
                family_id.to_string(),
            ));
        }
        if issue_count == 0 {
            return Err(RuntimePerformancePolicyError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: RuntimePerformancePolicyOrgan::RuntimePerformancePolicy,
            status: RuntimePerformancePolicyStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild test -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/PerfBudgetsTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/ResourceRuntimeRegressionTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/BackendRuntimeContractTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/Benchmarks/R15BenchmarkEvidenceLedgerTests".to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            mas_status: "red_release_blocker".to_string(),
            pro_status: "gated_release_blocker".to_string(),
            performance_surface_as_capability_proof: false,
            benchmark_as_runtime_proof: false,
            stale_benchmark_baseline_accepted: false,
            thermal_policy_bypassed: false,
            memory_pressure_bypassed: false,
            cancellation_timeout_missing: false,
            runtime_lane_performance_unbounded: false,
            settings_performance_unlocks_route: false,
            answer_packet_caveat_hidden: false,
            mas_pro_boundary_collapsed: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            benchmark_bytes_loaded: 0,
            model_runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            rollback_ref: "rollback:runtime_performance_policy_release_blocker_card".to_string(),
            run_event_log_ref: "run_event_log:runtime_performance_policy_release_blocker_card"
                .to_string(),
            answer_packet_ref: "answer_packet:runtime_performance_policy_release_blocker_card"
                .to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), RuntimePerformancePolicyError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "runtime_performance_policy"
            || self.issue_count == 0
            || self.organ != RuntimePerformancePolicyOrgan::RuntimePerformancePolicy
            || self.status != RuntimePerformancePolicyStatus::RedReleaseBlocker
        {
            return Err(RuntimePerformancePolicyError::CardHeaderBroken);
        }
        validate_unique_exact_set("source_refs", &self.source_refs, &REQUIRED_SOURCE_REFS)?;
        validate_unique_exact_set(
            "required_invariants",
            &self.required_invariants,
            &REQUIRED_INVARIANTS,
        )?;
        validate_list("focused_commands", &self.focused_commands, 5, 8)?;
        for command in &self.focused_commands {
            if !(command.starts_with("xcodebuild test -only-testing:EpistemosTests/")
                && (command.contains("Runtime")
                    || command.contains("Perf")
                    || command.contains("BackendRuntime")
                    || command.contains("Benchmark")))
            {
                return Err(RuntimePerformancePolicyError::BadFocusedCommand);
            }
        }
        for value in [
            &self.mas_status,
            &self.pro_status,
            &self.rollback_ref,
            &self.run_event_log_ref,
            &self.answer_packet_ref,
        ] {
            validate_token("proof_ref", value)?;
        }
        if self.performance_surface_as_capability_proof
            || self.benchmark_as_runtime_proof
            || self.stale_benchmark_baseline_accepted
            || self.thermal_policy_bypassed
            || self.memory_pressure_bypassed
            || self.cancellation_timeout_missing
            || self.runtime_lane_performance_unbounded
            || self.settings_performance_unlocks_route
            || self.answer_packet_caveat_hidden
            || self.mas_pro_boundary_collapsed
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.live_dense_70b_claimed
            || self.benchmark_bytes_loaded != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(RuntimePerformancePolicyError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:runtime-performance-policy-release-blocker-card:metrics
// Plane: Verification.
// Residency: aggregate release-blocker metrics only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RuntimePerformancePolicyMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub benchmark_bytes_loaded: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

// UAS: uas:runtime-performance-policy-release-blocker-card:witness
// Plane: Verification.
// Residency: metadata-only runtime performance policy source-card witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct RuntimePerformancePolicyReleaseBlockerWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: RuntimePerformancePolicyReleaseBlockerCard,
    pub metrics: RuntimePerformancePolicyMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl RuntimePerformancePolicyReleaseBlockerWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, RuntimePerformancePolicyError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(RuntimePerformancePolicyError::UpstreamNotPassed);
        }
        if upstream_next_cursor != RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_CURSOR {
            return Err(RuntimePerformancePolicyError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card = RuntimePerformancePolicyReleaseBlockerCard::from_family(family_id, issue_count)?;
        card.validate()?;
        let metrics = RuntimePerformancePolicyMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            benchmark_bytes_loaded: card.benchmark_bytes_loaded,
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
            provider_calls_made: card.provider_calls_made,
        };
        let address = runtime_performance_policy_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_ID.to_string(),
            cursor: RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_CURSOR.to_string(),
            next_cursor: RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_NEXT_CURSOR.to_string(),
            upstream_ref: upstream_ref.to_string(),
            family_source_ref: family_source_ref.to_string(),
            upstream_overall_pass,
            upstream_next_cursor: upstream_next_cursor.to_string(),
            card,
            metrics,
            address,
            metadata_only: true,
            no_product_promotion: true,
        })
    }

    pub fn validate(&self) -> Result<(), RuntimePerformancePolicyError> {
        if self.falsifier_id != RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_ID
            || self.cursor != RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_CURSOR
            || self.next_cursor != RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(RuntimePerformancePolicyError::WitnessHeaderBroken);
        }
        let rebuilt = Self::new(
            &self.upstream_ref,
            &self.family_source_ref,
            self.upstream_overall_pass,
            &self.upstream_next_cursor,
            &self.card.family_id,
            self.card.issue_count,
        )?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(RuntimePerformancePolicyError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_runtime_performance_policy_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_runtime_performance_policy_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn runtime_performance_policy_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &RuntimePerformancePolicyReleaseBlockerCard,
    metrics: &RuntimePerformancePolicyMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_ID);
    preimage.push_str(RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_CURSOR);
    preimage.push_str(RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_NEXT_CURSOR);
    preimage.push_str(upstream_ref);
    preimage.push_str(family_source_ref);
    preimage.push_str(&upstream_overall_pass.to_string());
    preimage.push_str(upstream_next_cursor);
    preimage.push_str(&card.family_id);
    preimage.push_str(&card.issue_count.to_string());
    for source in &card.source_refs {
        preimage.push_str(source);
    }
    for invariant in &card.required_invariants {
        preimage.push_str(invariant);
    }
    preimage.push_str(&format!("{metrics:?}"));
    sha256_hex(preimage.as_bytes())
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    required: &[&'static str],
) -> Result<(), RuntimePerformancePolicyError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(RuntimePerformancePolicyError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(RuntimePerformancePolicyError::MissingRequiredSet {
            field,
            actual: values.len(),
            expected: required.len(),
        });
    }
    Ok(())
}

fn validate_list(
    field: &'static str,
    values: &[String],
    min: usize,
    max: usize,
) -> Result<(), RuntimePerformancePolicyError> {
    if values.len() < min || values.len() > max {
        return Err(RuntimePerformancePolicyError::BadListLength {
            field,
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(RuntimePerformancePolicyError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), RuntimePerformancePolicyError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/ui_shell_source_guard_release_blocker_card/")
        || !value.contains("/result.json#F-UiShellSourceGuard-ReleaseBlockerCard")
    {
        return Err(RuntimePerformancePolicyError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), RuntimePerformancePolicyError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#runtime_performance_policy")
    {
        return Err(RuntimePerformancePolicyError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), RuntimePerformancePolicyError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(RuntimePerformancePolicyError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), RuntimePerformancePolicyError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(RuntimePerformancePolicyError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:runtime-performance-policy-release-blocker-card:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RuntimePerformancePolicyError {
    InvalidToken {
        field: &'static str,
        value: String,
    },
    InvalidText {
        field: &'static str,
        value: String,
    },
    BadListLength {
        field: &'static str,
        actual: usize,
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
    BadFocusedCommand,
    BadUpstreamRef,
    BadFamilySourceRef,
    UpstreamNotPassed,
    WrongUpstreamCursor(String),
    WrongFamily(String),
    ZeroIssueCount,
    CardHeaderBroken,
    PromotionBoundaryBroken,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for RuntimePerformancePolicyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for RuntimePerformancePolicyError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn witness() -> RuntimePerformancePolicyReleaseBlockerWitness {
        RuntimePerformancePolicyReleaseBlockerWitness::new(
            RUNTIME_PERFORMANCE_POLICY_UPSTREAM_REF,
            RUNTIME_PERFORMANCE_POLICY_FAMILY_SOURCE_REF,
            true,
            RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_CURSOR,
            "runtime_performance_policy",
            3,
        )
        .expect("valid runtime performance policy blocker witness")
    }

    #[test]
    fn accepts_runtime_performance_policy_card() {
        let witness = witness();
        assert_eq!(witness.card.issue_count, 3);
        assert_eq!(witness.metrics.source_ref_count, REQUIRED_SOURCE_REFS.len());
        assert_eq!(witness.metrics.invariant_count, REQUIRED_INVARIANTS.len());
        assert!(witness.metadata_only);
        assert!(witness.no_product_promotion);
        assert!(witness.address.starts_with("sha256:"));
        witness.validate().expect("witness validates");
    }

    #[test]
    fn rejects_wrong_upstream_or_family() {
        assert!(RuntimePerformancePolicyReleaseBlockerWitness::new(
            RUNTIME_PERFORMANCE_POLICY_UPSTREAM_REF,
            RUNTIME_PERFORMANCE_POLICY_FAMILY_SOURCE_REF,
            false,
            RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_CURSOR,
            "runtime_performance_policy",
            14,
        )
        .is_err());
        assert!(RuntimePerformancePolicyReleaseBlockerWitness::new(
            RUNTIME_PERFORMANCE_POLICY_UPSTREAM_REF,
            RUNTIME_PERFORMANCE_POLICY_FAMILY_SOURCE_REF,
            true,
            "ui_shell_source_guard_release_blocker_card",
            "runtime_performance_policy",
            3,
        )
        .is_err());
        assert!(RuntimePerformancePolicyReleaseBlockerWitness::new(
            RUNTIME_PERFORMANCE_POLICY_UPSTREAM_REF,
            RUNTIME_PERFORMANCE_POLICY_FAMILY_SOURCE_REF,
            true,
            RUNTIME_PERFORMANCE_POLICY_RELEASE_BLOCKER_CARD_CURSOR,
            "ui_shell_source_guard",
            3,
        )
        .is_err());
    }

    #[test]
    fn rejects_performance_policy_promotion_and_byte_leaks() {
        let mut card = witness().card;
        card.benchmark_as_runtime_proof = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.thermal_policy_bypassed = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.product_green_claimed = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.benchmark_bytes_loaded = 1;
        assert!(card.validate().is_err());
    }
}
