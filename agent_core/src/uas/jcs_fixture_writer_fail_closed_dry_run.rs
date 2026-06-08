//! JCS fixture writer fail-closed dry-run.
//!
//! This metadata-only dry-run consumes the pinned RFC 8785 number and UTF-16
//! sort oracle, creates an in-memory byte-plan contract, and proves fixture
//! materialization remains blocked until an owner-approved staging gate exists.

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{
    JcsNumberAndUtf16SortOracleWitness, JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_CURSOR,
    JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_ID,
};
use serde::{Deserialize, Serialize};
use std::fmt;

pub const JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_ID: &str = "F-JcsFixtureWriterFailClosedDryRun";
pub const JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_CURSOR: &str =
    "jcs_fixture_writer_fail_closed_dry_run";
pub const JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_NEXT_CURSOR: &str =
    "synthetic_fixture_staging_manifest_preflight_gate";

const ROLLBACK_REF: &str = "rollback:jcs_fixture_writer_fail_closed_dry_run";
const RUN_EVENT_LOG_REF: &str = "run_event_log:jcs_fixture_writer_fail_closed_dry_run";
const ANSWER_PACKET_REF: &str = "answer_packet:jcs_fixture_writer_fail_closed_dry_run";
const GUARD_PRODUCT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
// UAS: uas:jcs-fixture-writer-dry-run:status
// Plane: Verification + Controller.
// Residency: metadata-only writer plan; no fixture bytes are written.
pub enum JcsFixtureWriterDryRunStatus {
    DryRunPlannedWriterStillBlocked,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-fixture-writer-dry-run:source-card
// Plane: Verification.
// Residency: upstream oracle proof plus local writer gap; no runtime import.
pub struct JcsFixtureWriterDryRunSourceCard {
    pub upstream_falsifier_id: String,
    pub upstream_cursor: String,
    pub upstream_oracle_address: String,
    pub rfc8785_number_oracle_consumed: bool,
    pub utf16_sort_oracle_consumed: bool,
    pub local_writer_implementation_claimed: bool,
    pub node_runtime_required: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-fixture-writer-dry-run:policy
// Plane: Verification + Controller.
// Residency: fail-closed write policy before owner-approved staging.
pub struct JcsFixtureWriterDryRunPolicy {
    pub in_memory_plan_only: bool,
    pub owner_approval_required_for_write: bool,
    pub staging_manifest_required_before_write: bool,
    pub direct_final_write_denied: bool,
    pub serde_json_not_fixture_authority: bool,
    pub trifusion_not_fixture_authority: bool,
    pub duplicate_key_rejection_required: bool,
    pub invalid_unicode_rejection_required: bool,
    pub nan_infinity_rejection_required: bool,
    pub utf16_sort_required: bool,
    pub number_oracle_required: bool,
    pub rollback_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-fixture-writer-dry-run:planned-fragment
// Plane: Verification.
// Residency: synthetic in-memory byte-plan fragment; no file materialization.
pub struct JcsFixtureWriterPlannedFragment {
    pub fragment_id: String,
    pub source_oracle: String,
    pub planned_json_fragment: String,
    pub planned_digest: String,
    pub writes_allowed: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-fixture-writer-dry-run:byte-ledger
// Plane: Verification.
// Residency: zero-byte ledger for fail-closed writer dry-run.
pub struct JcsFixtureWriterDryRunByteLedger {
    pub dry_run_fragments_planned: u64,
    pub fixture_files_written: u64,
    pub fixture_bytes_written: u64,
    pub staging_manifest_files_written: u64,
    pub final_files_written: u64,
    pub schema_files_written: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub cache_index_bytes_opened: u64,
    pub commands_armed: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-fixture-writer-dry-run:spec
// Plane: Verification + Controller.
// Residency: fail-closed byte-plan contract consumed by synthetic fixtures.
pub struct JcsFixtureWriterFailClosedDryRun {
    pub source_card: JcsFixtureWriterDryRunSourceCard,
    pub policy: JcsFixtureWriterDryRunPolicy,
    pub planned_fragments: Vec<JcsFixtureWriterPlannedFragment>,
    pub planned_fragment_digest: String,
    pub byte_ledger: JcsFixtureWriterDryRunByteLedger,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub guard_owned_product_cursor: String,
    pub owner_approval_granted: bool,
    pub materialization_allowed: bool,
    pub metadata_only: bool,
    pub l1_claimed: bool,
    pub l2_claimed: bool,
    pub l3_claimed: bool,
    pub t4_t5_claimed: bool,
    pub product_green_claimed: bool,
    pub release_ready_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub hidden_route_authority_claimed: bool,
    pub status: JcsFixtureWriterDryRunStatus,
}

impl JcsFixtureWriterFailClosedDryRun {
    pub fn canonical() -> Result<Self, JcsFixtureWriterDryRunError> {
        let upstream = JcsNumberAndUtf16SortOracleWitness::new()
            .map_err(|_| JcsFixtureWriterDryRunError::UpstreamOracleBroken)?;
        upstream
            .validate()
            .map_err(|_| JcsFixtureWriterDryRunError::UpstreamOracleBroken)?;
        let planned_fragments = planned_fragments(&upstream);
        Ok(Self {
            source_card: JcsFixtureWriterDryRunSourceCard {
                upstream_falsifier_id: JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_ID.to_string(),
                upstream_cursor: JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_CURSOR.to_string(),
                upstream_oracle_address: upstream.address,
                rfc8785_number_oracle_consumed: true,
                utf16_sort_oracle_consumed: true,
                local_writer_implementation_claimed: false,
                node_runtime_required: false,
            },
            policy: JcsFixtureWriterDryRunPolicy {
                in_memory_plan_only: true,
                owner_approval_required_for_write: true,
                staging_manifest_required_before_write: true,
                direct_final_write_denied: true,
                serde_json_not_fixture_authority: true,
                trifusion_not_fixture_authority: true,
                duplicate_key_rejection_required: true,
                invalid_unicode_rejection_required: true,
                nan_infinity_rejection_required: true,
                utf16_sort_required: true,
                number_oracle_required: true,
                rollback_required: true,
                run_event_log_required: true,
                answer_packet_required: true,
            },
            planned_fragment_digest: digest_json(&planned_fragments),
            planned_fragments,
            byte_ledger: JcsFixtureWriterDryRunByteLedger {
                dry_run_fragments_planned: 4,
                fixture_files_written: 0,
                fixture_bytes_written: 0,
                staging_manifest_files_written: 0,
                final_files_written: 0,
                schema_files_written: 0,
                model_runtime_bytes_loaded: 0,
                provider_calls_made: 0,
                cache_index_bytes_opened: 0,
                commands_armed: 0,
            },
            rollback_ref: ROLLBACK_REF.to_string(),
            run_event_log_ref: RUN_EVENT_LOG_REF.to_string(),
            answer_packet_ref: ANSWER_PACKET_REF.to_string(),
            guard_owned_product_cursor: GUARD_PRODUCT_CURSOR.to_string(),
            owner_approval_granted: false,
            materialization_allowed: false,
            metadata_only: true,
            l1_claimed: false,
            l2_claimed: false,
            l3_claimed: false,
            t4_t5_claimed: false,
            product_green_claimed: false,
            release_ready_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            hidden_route_authority_claimed: false,
            status: JcsFixtureWriterDryRunStatus::DryRunPlannedWriterStillBlocked,
        })
    }

    pub fn validate(&self) -> Result<(), JcsFixtureWriterDryRunError> {
        let upstream = JcsNumberAndUtf16SortOracleWitness::new()
            .map_err(|_| JcsFixtureWriterDryRunError::UpstreamOracleBroken)?;
        upstream
            .validate()
            .map_err(|_| JcsFixtureWriterDryRunError::UpstreamOracleBroken)?;
        self.source_card.validate(&upstream.address)?;
        self.policy.validate()?;
        validate_planned_fragments(&self.planned_fragments, &upstream)?;
        validate_exact(
            "planned_fragment_digest",
            &self.planned_fragment_digest,
            &digest_json(&self.planned_fragments),
        )?;
        self.byte_ledger.validate()?;
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
            "guard_owned_product_cursor",
            &self.guard_owned_product_cursor,
            GUARD_PRODUCT_CURSOR,
        )?;
        if self.owner_approval_granted || self.materialization_allowed || !self.metadata_only {
            return Err(JcsFixtureWriterDryRunError::MaterializationBoundaryBroken);
        }
        if self.l1_claimed
            || self.l2_claimed
            || self.l3_claimed
            || self.t4_t5_claimed
            || self.product_green_claimed
            || self.release_ready_claimed
            || self.live_dense_70b_claimed
            || self.ssd_as_ram_claimed
            || self.hidden_route_authority_claimed
        {
            return Err(JcsFixtureWriterDryRunError::PromotionClaim);
        }
        if self.status != JcsFixtureWriterDryRunStatus::DryRunPlannedWriterStillBlocked {
            return Err(JcsFixtureWriterDryRunError::WrongStatus);
        }
        Ok(())
    }
}

impl JcsFixtureWriterDryRunSourceCard {
    pub fn validate(&self, upstream_address: &str) -> Result<(), JcsFixtureWriterDryRunError> {
        validate_exact(
            "upstream_falsifier_id",
            &self.upstream_falsifier_id,
            JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_ID,
        )?;
        validate_exact(
            "upstream_cursor",
            &self.upstream_cursor,
            JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_CURSOR,
        )?;
        validate_exact(
            "upstream_oracle_address",
            &self.upstream_oracle_address,
            upstream_address,
        )?;
        if !self.rfc8785_number_oracle_consumed
            || !self.utf16_sort_oracle_consumed
            || self.local_writer_implementation_claimed
            || self.node_runtime_required
        {
            return Err(JcsFixtureWriterDryRunError::SourceCardBroken);
        }
        Ok(())
    }
}

impl JcsFixtureWriterDryRunPolicy {
    pub fn validate(&self) -> Result<(), JcsFixtureWriterDryRunError> {
        if !self.in_memory_plan_only
            || !self.owner_approval_required_for_write
            || !self.staging_manifest_required_before_write
            || !self.direct_final_write_denied
            || !self.serde_json_not_fixture_authority
            || !self.trifusion_not_fixture_authority
            || !self.duplicate_key_rejection_required
            || !self.invalid_unicode_rejection_required
            || !self.nan_infinity_rejection_required
            || !self.utf16_sort_required
            || !self.number_oracle_required
            || !self.rollback_required
            || !self.run_event_log_required
            || !self.answer_packet_required
        {
            return Err(JcsFixtureWriterDryRunError::PolicyBroken);
        }
        Ok(())
    }
}

impl JcsFixtureWriterDryRunByteLedger {
    pub fn validate(&self) -> Result<(), JcsFixtureWriterDryRunError> {
        if self.dry_run_fragments_planned != 4 {
            return Err(JcsFixtureWriterDryRunError::PlannedFragmentBroken);
        }
        if self.fixture_files_written != 0
            || self.fixture_bytes_written != 0
            || self.staging_manifest_files_written != 0
            || self.final_files_written != 0
            || self.schema_files_written != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.cache_index_bytes_opened != 0
            || self.commands_armed != 0
        {
            return Err(JcsFixtureWriterDryRunError::ByteOrCommandLeak);
        }
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-fixture-writer-dry-run:metrics
// Plane: Verification.
// Residency: metadata-only dry-run counters.
pub struct JcsFixtureWriterDryRunMetrics {
    pub planned_fragment_count: u64,
    pub number_fragment_count: u64,
    pub utf16_sort_fragment_count: u64,
    pub blocked_write_count: u64,
    pub fixture_files_written: u64,
    pub fixture_bytes_written: u64,
    pub runtime_model_provider_cache_index_bytes: u64,
    pub commands_armed: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-fixture-writer-dry-run:witness
// Plane: Verification + Controller.
// Residency: L1/T1 side-ladder; no fixture files are written.
pub struct JcsFixtureWriterFailClosedDryRunWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub spec: JcsFixtureWriterFailClosedDryRun,
    pub metrics: JcsFixtureWriterDryRunMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub product_promotion_blocked: bool,
}

impl JcsFixtureWriterFailClosedDryRunWitness {
    pub fn new() -> Result<Self, JcsFixtureWriterDryRunError> {
        let spec = JcsFixtureWriterFailClosedDryRun::canonical()?;
        spec.validate()?;
        let metrics = JcsFixtureWriterDryRunMetrics {
            planned_fragment_count: spec.planned_fragments.len() as u64,
            number_fragment_count: spec
                .planned_fragments
                .iter()
                .filter(|fragment| fragment.source_oracle == "rfc8785_number")
                .count() as u64,
            utf16_sort_fragment_count: spec
                .planned_fragments
                .iter()
                .filter(|fragment| fragment.source_oracle == "rfc8785_utf16_sort")
                .count() as u64,
            blocked_write_count: spec
                .planned_fragments
                .iter()
                .filter(|fragment| !fragment.writes_allowed)
                .count() as u64,
            fixture_files_written: spec.byte_ledger.fixture_files_written
                + spec.byte_ledger.staging_manifest_files_written
                + spec.byte_ledger.final_files_written
                + spec.byte_ledger.schema_files_written,
            fixture_bytes_written: spec.byte_ledger.fixture_bytes_written,
            runtime_model_provider_cache_index_bytes: spec.byte_ledger.model_runtime_bytes_loaded
                + spec.byte_ledger.provider_calls_made
                + spec.byte_ledger.cache_index_bytes_opened,
            commands_armed: spec.byte_ledger.commands_armed,
        };
        let address = jcs_fixture_writer_fail_closed_dry_run_address(&spec, &metrics);
        Ok(Self {
            falsifier_id: JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_ID.to_string(),
            cursor: JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_CURSOR.to_string(),
            next_cursor: JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_NEXT_CURSOR.to_string(),
            spec,
            metrics,
            address,
            metadata_only: true,
            product_promotion_blocked: true,
        })
    }

    pub fn validate(&self) -> Result<(), JcsFixtureWriterDryRunError> {
        if self.falsifier_id != JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_ID
            || self.cursor != JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_CURSOR
            || self.next_cursor != JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_NEXT_CURSOR
            || !self.metadata_only
            || !self.product_promotion_blocked
        {
            return Err(JcsFixtureWriterDryRunError::WitnessHeaderBroken);
        }
        self.spec.validate()?;
        let rebuilt = Self::new()?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(JcsFixtureWriterDryRunError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn jcs_fixture_writer_fail_closed_dry_run_address(
    spec: &JcsFixtureWriterFailClosedDryRun,
    metrics: &JcsFixtureWriterDryRunMetrics,
) -> String {
    let payload = serde_json::json!({
        "id": JCS_FIXTURE_WRITER_FAIL_CLOSED_DRY_RUN_ID,
        "spec": spec,
        "metrics": metrics,
    });
    sha256_hex(payload.to_string().as_bytes())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:jcs-fixture-writer-dry-run:error
// Plane: Verification.
// Residency: fail-closed dry-run rejection taxonomy.
pub enum JcsFixtureWriterDryRunError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    WrongValue(&'static str),
    UpstreamOracleBroken,
    SourceCardBroken,
    PolicyBroken,
    PlannedFragmentBroken,
    ByteOrCommandLeak,
    MaterializationBoundaryBroken,
    PromotionClaim,
    WrongStatus,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for JcsFixtureWriterDryRunError {
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
            Self::UpstreamOracleBroken => write!(f, "upstream JCS oracle broken"),
            Self::SourceCardBroken => write!(f, "source card broken"),
            Self::PolicyBroken => write!(f, "dry-run policy broken"),
            Self::PlannedFragmentBroken => write!(f, "planned fragment broken"),
            Self::ByteOrCommandLeak => write!(f, "byte or command leak"),
            Self::MaterializationBoundaryBroken => write!(f, "materialization boundary broken"),
            Self::PromotionClaim => write!(f, "promotion claim attempted"),
            Self::WrongStatus => write!(f, "wrong dry-run status"),
            Self::WitnessHeaderBroken => write!(f, "witness header broken"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for JcsFixtureWriterDryRunError {}

fn planned_fragments(
    upstream: &JcsNumberAndUtf16SortOracleWitness,
) -> Vec<JcsFixtureWriterPlannedFragment> {
    let number_digest = &upstream.spec.number_sample_digest;
    let utf16_digest = &upstream.spec.utf16_sort_digest;
    vec![
        fragment(
            "minus_zero_number_fragment",
            "rfc8785_number",
            "{\"hex\":\"8000000000000000\",\"json\":0}",
            number_digest,
        ),
        fragment(
            "exponent_threshold_fragment",
            "rfc8785_number",
            "{\"hex\":\"44b52d02c7e14af6\",\"json\":1e+23}",
            number_digest,
        ),
        fragment(
            "utf16_property_order_fragment",
            "rfc8785_utf16_sort",
            "{\"\\r\":0,\"1\":1,\"\\u0080\":2,\"\\u00f6\":3,\"\\u20ac\":4,\"\\ud83d\\ude00\":5,\"\\ufb33\":6}",
            utf16_digest,
        ),
        fragment(
            "nan_infinity_rejection_fragment",
            "rfc8785_number",
            "{\"rejected\":[\"7fffffffffffffff\",\"7ff0000000000000\"]}",
            number_digest,
        ),
    ]
}

fn fragment(
    fragment_id: &str,
    source_oracle: &str,
    planned_json_fragment: &str,
    oracle_digest: &str,
) -> JcsFixtureWriterPlannedFragment {
    let planned_digest = sha256_hex(
        format!("{fragment_id}\n{source_oracle}\n{planned_json_fragment}\n{oracle_digest}")
            .as_bytes(),
    );
    JcsFixtureWriterPlannedFragment {
        fragment_id: fragment_id.to_string(),
        source_oracle: source_oracle.to_string(),
        planned_json_fragment: planned_json_fragment.to_string(),
        planned_digest,
        writes_allowed: false,
    }
}

fn validate_planned_fragments(
    fragments: &[JcsFixtureWriterPlannedFragment],
    upstream: &JcsNumberAndUtf16SortOracleWitness,
) -> Result<(), JcsFixtureWriterDryRunError> {
    if fragments != planned_fragments(upstream) {
        return Err(JcsFixtureWriterDryRunError::PlannedFragmentBroken);
    }
    if fragments.len() != 4
        || fragments
            .iter()
            .filter(|fragment| !fragment.writes_allowed)
            .count()
            != 4
        || fragments
            .iter()
            .filter(|fragment| fragment.source_oracle == "rfc8785_number")
            .count()
            != 3
        || fragments
            .iter()
            .filter(|fragment| fragment.source_oracle == "rfc8785_utf16_sort")
            .count()
            != 1
    {
        return Err(JcsFixtureWriterDryRunError::PlannedFragmentBroken);
    }
    for fragment in fragments {
        validate_token("fragment_id", &fragment.fragment_id)?;
        validate_token("source_oracle", &fragment.source_oracle)?;
        validate_token("planned_json_fragment", &fragment.planned_json_fragment)?;
        if !fragment.planned_digest.starts_with("sha256:") {
            return Err(JcsFixtureWriterDryRunError::PlannedFragmentBroken);
        }
    }
    Ok(())
}

fn digest_json<T: Serialize>(value: &T) -> String {
    sha256_hex(
        serde_json::to_string(value)
            .expect("dry-run digest serializes")
            .as_bytes(),
    )
}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), JcsFixtureWriterDryRunError> {
    validate_token(field, value)?;
    if value != expected {
        return Err(JcsFixtureWriterDryRunError::WrongValue(field));
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), JcsFixtureWriterDryRunError> {
    if value.is_empty() {
        return Err(JcsFixtureWriterDryRunError::MissingField(field));
    }
    if value.trim() != value {
        return Err(JcsFixtureWriterDryRunError::FieldHasSurroundingWhitespace(
            field,
        ));
    }
    if value.chars().any(char::is_control) {
        return Err(JcsFixtureWriterDryRunError::FieldContainsControlCharacter(
            field,
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_dry_run_validates() {
        JcsFixtureWriterFailClosedDryRun::canonical()
            .expect("dry-run")
            .validate()
            .expect("canonical validates");
    }

    #[test]
    fn witness_is_deterministic() {
        let first = JcsFixtureWriterFailClosedDryRunWitness::new().expect("first");
        let second = JcsFixtureWriterFailClosedDryRunWitness::new().expect("second");
        assert_eq!(first.address, second.address);
        assert_eq!(first.metrics.planned_fragment_count, 4);
        assert_eq!(first.metrics.number_fragment_count, 3);
        assert_eq!(first.metrics.utf16_sort_fragment_count, 1);
        assert_eq!(first.metrics.blocked_write_count, 4);
    }

    #[test]
    fn rejects_upstream_address_drift() {
        let mut dry_run = JcsFixtureWriterFailClosedDryRun::canonical().expect("dry-run");
        dry_run.source_card.upstream_oracle_address =
            "sha256:0000000000000000000000000000000000000000000000000000000000000000".to_string();
        assert_eq!(
            dry_run.validate().unwrap_err(),
            JcsFixtureWriterDryRunError::WrongValue("upstream_oracle_address")
        );
    }

    #[test]
    fn rejects_local_writer_claim() {
        let mut dry_run = JcsFixtureWriterFailClosedDryRun::canonical().expect("dry-run");
        dry_run.source_card.local_writer_implementation_claimed = true;
        assert_eq!(
            dry_run.validate().unwrap_err(),
            JcsFixtureWriterDryRunError::SourceCardBroken
        );
    }

    #[test]
    fn rejects_node_runtime_requirement() {
        let mut dry_run = JcsFixtureWriterFailClosedDryRun::canonical().expect("dry-run");
        dry_run.source_card.node_runtime_required = true;
        assert_eq!(
            dry_run.validate().unwrap_err(),
            JcsFixtureWriterDryRunError::SourceCardBroken
        );
    }

    #[test]
    fn rejects_policy_bypass() {
        let mut dry_run = JcsFixtureWriterFailClosedDryRun::canonical().expect("dry-run");
        dry_run.policy.owner_approval_required_for_write = false;
        assert_eq!(
            dry_run.validate().unwrap_err(),
            JcsFixtureWriterDryRunError::PolicyBroken
        );
    }

    #[test]
    fn rejects_fragment_drift() {
        let mut dry_run = JcsFixtureWriterFailClosedDryRun::canonical().expect("dry-run");
        dry_run.planned_fragments[1].planned_json_fragment =
            "{\"hex\":\"44b52d02c7e14af6\",\"json\":100000000000000000000000}".to_string();
        assert_eq!(
            dry_run.validate().unwrap_err(),
            JcsFixtureWriterDryRunError::PlannedFragmentBroken
        );
    }

    #[test]
    fn rejects_fragment_write_enablement() {
        let mut dry_run = JcsFixtureWriterFailClosedDryRun::canonical().expect("dry-run");
        dry_run.planned_fragments[0].writes_allowed = true;
        assert_eq!(
            dry_run.validate().unwrap_err(),
            JcsFixtureWriterDryRunError::PlannedFragmentBroken
        );
    }

    #[test]
    fn rejects_byte_leak() {
        let mut dry_run = JcsFixtureWriterFailClosedDryRun::canonical().expect("dry-run");
        dry_run.byte_ledger.fixture_files_written = 1;
        assert_eq!(
            dry_run.validate().unwrap_err(),
            JcsFixtureWriterDryRunError::ByteOrCommandLeak
        );
    }

    #[test]
    fn rejects_materialization_enablement() {
        let mut dry_run = JcsFixtureWriterFailClosedDryRun::canonical().expect("dry-run");
        dry_run.materialization_allowed = true;
        assert_eq!(
            dry_run.validate().unwrap_err(),
            JcsFixtureWriterDryRunError::MaterializationBoundaryBroken
        );
    }

    #[test]
    fn rejects_owner_approval_enablement() {
        let mut dry_run = JcsFixtureWriterFailClosedDryRun::canonical().expect("dry-run");
        dry_run.owner_approval_granted = true;
        assert_eq!(
            dry_run.validate().unwrap_err(),
            JcsFixtureWriterDryRunError::MaterializationBoundaryBroken
        );
    }

    #[test]
    fn rejects_promotion_claim() {
        let mut dry_run = JcsFixtureWriterFailClosedDryRun::canonical().expect("dry-run");
        dry_run.product_green_claimed = true;
        assert_eq!(
            dry_run.validate().unwrap_err(),
            JcsFixtureWriterDryRunError::PromotionClaim
        );
    }
}
