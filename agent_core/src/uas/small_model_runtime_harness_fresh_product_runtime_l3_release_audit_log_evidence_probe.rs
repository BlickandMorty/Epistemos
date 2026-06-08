use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_PROBE_ID: &str =
    "F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditLogEvidenceProbe";
pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_PROBE_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe";
pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_PROBE_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_manual_runtime_verification_probe";

pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_UPSTREAM_REF: &str =
    "artifact:falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/result.json#F-SmallModelRuntimeHarnessFreshProductRuntimeL3ReleaseAuditAutomatedChecksProbe";
pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_CHECKS_TSV: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/checks.tsv";
pub const SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_LOG_ROOT: &str =
    "artifacts/falsifiers/small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe/logs/";

const REQUIRED_CHECK_IDS: [&str; 5] = [
    "xcodebuild_build",
    "xcodebuild_test",
    "graph_engine_cargo_test",
    "omega_mcp_cargo_test",
    "omega_ax_cargo_test",
];

const REQUIRED_PHASES: [&str; 12] = [
    "upstream_automated_checks_red_bound",
    "checks_tsv_bound",
    "five_command_logs_digest_bound",
    "xcodebuild_test_failure_family_bound",
    "red_failure_counts_bound",
    "runtime_oslog_pending",
    "answer_packet_runtime_correlation_pending",
    "manual_runtime_verification_required",
    "distribution_compliance_required",
    "three_pass_zero_fail_required",
    "no_product_or_large_model_promotion",
    "next_manual_runtime_verification_queued",
];

const REQUIRED_REJECTION_POLICIES: [&str; 16] = [
    "missing_upstream_artifact",
    "upstream_green_laundering",
    "missing_checks_tsv",
    "missing_required_log",
    "bad_log_digest",
    "zero_xcodebuild_issue_count",
    "missing_top_failure_family",
    "runtime_oslog_claim",
    "answer_packet_runtime_claim",
    "manual_runtime_claim",
    "distribution_compliance_claim",
    "product_release_green_claim",
    "large_model_product_claim",
    "model_or_provider_byte_claim",
    "raw_prompt_or_answer_leak",
    "next_cursor_mismatch",
];

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-log-evidence-probe:log-digest
// Plane: Verification.
// Residency: retained automated-check log metadata; no raw log payload embedded.
pub struct SmallModelReleaseAuditLogDigest {
    pub check_id: String,
    pub log_ref: String,
    pub bytes: u64,
    pub sha256: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-log-evidence-probe
// Plane: Verification + Controller.
// Residency: metadata-only retained log evidence; runtime OSLog proof remains pending.
pub struct SmallModelReleaseAuditLogEvidenceProbe {
    pub upstream_artifact_ref: String,
    pub upstream_artifact_address: String,
    pub upstream_overall_pass: bool,
    pub checks_tsv_ref: String,
    pub log_root_ref: String,
    pub required_check_ids: Vec<String>,
    pub log_digests: Vec<SmallModelReleaseAuditLogDigest>,
    pub failed_check_count: u64,
    pub xcodebuild_test_issue_count: u64,
    pub xcodebuild_test_unique_failure_count: u64,
    pub top_xcodebuild_test_failure_family: String,
    pub runtime_oslog_entries_bound: u64,
    pub runtime_log_evidence_present: bool,
    pub answer_packet_runtime_correlation_present: bool,
    pub manual_runtime_evidence_present: bool,
    pub distribution_compliance_evidence_present: bool,
    pub zero_fail_pass_count: u64,
    pub product_green_claimed: bool,
    pub release_ready_claimed: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub long_context_shard_claimed: bool,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub raw_prompt_or_answer_bytes_embedded: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub phases: Vec<String>,
    pub rejection_policies: Vec<String>,
    pub next_cursor: String,
}

impl SmallModelReleaseAuditLogEvidenceProbe {
    pub fn canonical(
        upstream_artifact_address: impl Into<String>,
        log_digests: Vec<SmallModelReleaseAuditLogDigest>,
        failed_check_count: u64,
        xcodebuild_test_issue_count: u64,
        xcodebuild_test_unique_failure_count: u64,
        top_xcodebuild_test_failure_family: impl Into<String>,
    ) -> Self {
        Self {
            upstream_artifact_ref: SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_UPSTREAM_REF.to_string(),
            upstream_artifact_address: upstream_artifact_address.into(),
            upstream_overall_pass: false,
            checks_tsv_ref: SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_CHECKS_TSV.to_string(),
            log_root_ref: SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_LOG_ROOT.to_string(),
            required_check_ids: REQUIRED_CHECK_IDS.iter().map(|value| value.to_string()).collect(),
            log_digests,
            failed_check_count,
            xcodebuild_test_issue_count,
            xcodebuild_test_unique_failure_count,
            top_xcodebuild_test_failure_family: top_xcodebuild_test_failure_family.into(),
            runtime_oslog_entries_bound: 0,
            runtime_log_evidence_present: false,
            answer_packet_runtime_correlation_present: false,
            manual_runtime_evidence_present: false,
            distribution_compliance_evidence_present: false,
            zero_fail_pass_count: 0,
            product_green_claimed: false,
            release_ready_claimed: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            live_dense_70b_claimed: false,
            long_context_shard_claimed: false,
            model_runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            raw_prompt_or_answer_bytes_embedded: 0,
            rollback_ref: "rollback:small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe".to_string(),
            run_event_log_ref: "run_event_log:small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe".to_string(),
            answer_packet_ref: "answer_packet:small_model_runtime_harness_fresh_product_runtime_l3_release_audit_log_evidence_probe".to_string(),
            phases: REQUIRED_PHASES.iter().map(|value| value.to_string()).collect(),
            rejection_policies: REQUIRED_REJECTION_POLICIES.iter().map(|value| value.to_string()).collect(),
            next_cursor: SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_PROBE_NEXT_CURSOR.to_string(),
        }
    }

    pub fn validate(&self) -> Result<(), SmallModelReleaseAuditLogEvidenceError> {
        validate_exact(
            "upstream_artifact_ref",
            &self.upstream_artifact_ref,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_UPSTREAM_REF,
        )?;
        validate_sha("upstream_artifact_address", &self.upstream_artifact_address)?;
        if self.upstream_overall_pass {
            return Err(SmallModelReleaseAuditLogEvidenceError::UpstreamGreenLaundered);
        }
        validate_exact(
            "checks_tsv_ref",
            &self.checks_tsv_ref,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_CHECKS_TSV,
        )?;
        validate_exact(
            "log_root_ref",
            &self.log_root_ref,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_LOG_ROOT,
        )?;
        validate_unique_exact_set(
            "required_check_ids",
            &self.required_check_ids,
            &REQUIRED_CHECK_IDS,
        )?;
        validate_unique_exact_set("phases", &self.phases, &REQUIRED_PHASES)?;
        validate_unique_exact_set(
            "rejection_policies",
            &self.rejection_policies,
            &REQUIRED_REJECTION_POLICIES,
        )?;
        if self.log_digests.len() != REQUIRED_CHECK_IDS.len() {
            return Err(SmallModelReleaseAuditLogEvidenceError::MissingRequiredLog);
        }
        let mut seen = BTreeSet::new();
        for digest in &self.log_digests {
            validate_required_check_id(&digest.check_id)?;
            validate_prefixed("log_ref", &digest.log_ref, "artifacts/falsifiers/")?;
            validate_sha("log_sha256", &digest.sha256)?;
            if digest.bytes == 0 {
                return Err(SmallModelReleaseAuditLogEvidenceError::MissingRequiredLog);
            }
            if !seen.insert(digest.check_id.as_str()) {
                return Err(SmallModelReleaseAuditLogEvidenceError::DuplicateLog);
            }
        }
        for required in REQUIRED_CHECK_IDS {
            if !seen.contains(required) {
                return Err(SmallModelReleaseAuditLogEvidenceError::MissingRequiredLog);
            }
        }
        if self.failed_check_count != 1
            || self.xcodebuild_test_issue_count == 0
            || self.xcodebuild_test_unique_failure_count == 0
        {
            return Err(SmallModelReleaseAuditLogEvidenceError::FailureCountsInvalid);
        }
        validate_token(
            "top_xcodebuild_test_failure_family",
            &self.top_xcodebuild_test_failure_family,
        )?;
        if self.top_xcodebuild_test_failure_family != "graph_filter_visibility" {
            return Err(SmallModelReleaseAuditLogEvidenceError::FailureFamilyInvalid);
        }
        if self.runtime_oslog_entries_bound != 0
            || self.runtime_log_evidence_present
            || self.answer_packet_runtime_correlation_present
            || self.manual_runtime_evidence_present
            || self.distribution_compliance_evidence_present
            || self.zero_fail_pass_count != 0
        {
            return Err(SmallModelReleaseAuditLogEvidenceError::RuntimeEvidenceOverclaimed);
        }
        if self.product_green_claimed
            || self.release_ready_claimed
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.live_dense_70b_claimed
            || self.long_context_shard_claimed
        {
            return Err(SmallModelReleaseAuditLogEvidenceError::PromotionClaim);
        }
        if self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.raw_prompt_or_answer_bytes_embedded != 0
        {
            return Err(SmallModelReleaseAuditLogEvidenceError::ByteLeak);
        }
        validate_prefixed("rollback_ref", &self.rollback_ref, "rollback:")?;
        validate_prefixed(
            "run_event_log_ref",
            &self.run_event_log_ref,
            "run_event_log:",
        )?;
        validate_prefixed(
            "answer_packet_ref",
            &self.answer_packet_ref,
            "answer_packet:",
        )?;
        validate_exact(
            "next_cursor",
            &self.next_cursor,
            SMALL_MODEL_RUNTIME_HARNESS_FRESH_PRODUCT_RUNTIME_L3_RELEASE_AUDIT_LOG_EVIDENCE_PROBE_NEXT_CURSOR,
        )?;
        Ok(())
    }

    pub fn address(&self) -> String {
        let mut parts = vec![
            self.upstream_artifact_ref.clone(),
            self.upstream_artifact_address.clone(),
            self.checks_tsv_ref.clone(),
            self.log_root_ref.clone(),
            self.failed_check_count.to_string(),
            self.xcodebuild_test_issue_count.to_string(),
            self.xcodebuild_test_unique_failure_count.to_string(),
            self.top_xcodebuild_test_failure_family.clone(),
            self.next_cursor.clone(),
        ];
        for digest in &self.log_digests {
            parts.push(format!(
                "{}:{}:{}",
                digest.check_id, digest.bytes, digest.sha256
            ));
        }
        for phase in &self.phases {
            parts.push(phase.clone());
        }
        parts.sort();
        sha256_hex(parts.join("|").as_bytes())
    }
}

pub fn required_fresh_product_runtime_l3_release_audit_log_evidence_checks() -> [&'static str; 5] {
    REQUIRED_CHECK_IDS
}

pub fn required_fresh_product_runtime_l3_release_audit_log_evidence_phases() -> [&'static str; 12] {
    REQUIRED_PHASES
}

pub fn required_fresh_product_runtime_l3_release_audit_log_evidence_rejection_policies(
) -> [&'static str; 16] {
    REQUIRED_REJECTION_POLICIES
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:small-model-runtime-harness-fresh-product-runtime-l3-release-audit-log-evidence-probe:error
// Plane: Verification.
// Residency: validation-only enum; no runtime, log payload, prompt, or answer bytes.
pub enum SmallModelReleaseAuditLogEvidenceError {
    MissingField(&'static str),
    FieldMismatch(&'static str),
    FieldHasWhitespace(&'static str),
    FieldContainsControl(&'static str),
    DuplicateValue(&'static str),
    MissingValue(&'static str),
    InvalidSha(&'static str),
    InvalidPrefix(&'static str),
    InvalidCheckId(String),
    UpstreamGreenLaundered,
    MissingRequiredLog,
    DuplicateLog,
    FailureCountsInvalid,
    FailureFamilyInvalid,
    RuntimeEvidenceOverclaimed,
    PromotionClaim,
    ByteLeak,
}

impl fmt::Display for SmallModelReleaseAuditLogEvidenceError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for SmallModelReleaseAuditLogEvidenceError {}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelReleaseAuditLogEvidenceError> {
    if value.is_empty() {
        return Err(SmallModelReleaseAuditLogEvidenceError::MissingField(field));
    }
    if value.trim() != value {
        return Err(SmallModelReleaseAuditLogEvidenceError::FieldHasWhitespace(
            field,
        ));
    }
    if value.chars().any(char::is_control) {
        return Err(SmallModelReleaseAuditLogEvidenceError::FieldContainsControl(field));
    }
    Ok(())
}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), SmallModelReleaseAuditLogEvidenceError> {
    validate_token(field, value)?;
    if value != expected {
        return Err(SmallModelReleaseAuditLogEvidenceError::FieldMismatch(field));
    }
    Ok(())
}

fn validate_prefixed(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), SmallModelReleaseAuditLogEvidenceError> {
    validate_token(field, value)?;
    if !value.starts_with(prefix) {
        return Err(SmallModelReleaseAuditLogEvidenceError::InvalidPrefix(field));
    }
    Ok(())
}

fn validate_sha(
    field: &'static str,
    value: &str,
) -> Result<(), SmallModelReleaseAuditLogEvidenceError> {
    validate_prefixed(field, value, "sha256:")?;
    let hex = &value["sha256:".len()..];
    if hex.len() != 64 || !hex.chars().all(|ch| ch.is_ascii_hexdigit()) {
        return Err(SmallModelReleaseAuditLogEvidenceError::InvalidSha(field));
    }
    Ok(())
}

fn validate_required_check_id(
    check_id: &str,
) -> Result<(), SmallModelReleaseAuditLogEvidenceError> {
    validate_token("check_id", check_id)?;
    if !REQUIRED_CHECK_IDS.contains(&check_id) {
        return Err(SmallModelReleaseAuditLogEvidenceError::InvalidCheckId(
            check_id.to_string(),
        ));
    }
    Ok(())
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    expected: &[&str],
) -> Result<(), SmallModelReleaseAuditLogEvidenceError> {
    if values.len() != expected.len() {
        return Err(SmallModelReleaseAuditLogEvidenceError::MissingValue(field));
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_token(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(SmallModelReleaseAuditLogEvidenceError::DuplicateValue(
                field,
            ));
        }
    }
    for required in expected {
        if !seen.contains(required) {
            return Err(SmallModelReleaseAuditLogEvidenceError::MissingValue(field));
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn digest(id: &str) -> SmallModelReleaseAuditLogDigest {
        SmallModelReleaseAuditLogDigest {
            check_id: id.to_string(),
            log_ref: format!("artifacts/falsifiers/example/logs/{id}.log"),
            bytes: 1,
            sha256: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                .to_string(),
        }
    }

    fn canonical() -> SmallModelReleaseAuditLogEvidenceProbe {
        SmallModelReleaseAuditLogEvidenceProbe::canonical(
            "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            REQUIRED_CHECK_IDS.iter().map(|id| digest(id)).collect(),
            1,
            161,
            84,
            "graph_filter_visibility",
        )
    }

    #[test]
    fn canonical_probe_validates() {
        canonical().validate().unwrap();
    }

    #[test]
    fn address_is_deterministic() {
        assert_eq!(canonical().address(), canonical().address());
    }

    #[test]
    fn rejects_missing_required_log() {
        let mut probe = canonical();
        probe.log_digests.pop();
        assert!(probe.validate().is_err());
    }

    #[test]
    fn rejects_runtime_evidence_overclaim() {
        let mut probe = canonical();
        probe.runtime_log_evidence_present = true;
        assert!(probe.validate().is_err());
    }

    #[test]
    fn rejects_promotion_claims() {
        let mut probe = canonical();
        probe.l3_green_claimed = true;
        assert!(probe.validate().is_err());
    }

    #[test]
    fn rejects_byte_leaks() {
        let mut probe = canonical();
        probe.raw_prompt_or_answer_bytes_embedded = 1;
        assert!(probe.validate().is_err());
    }
}
