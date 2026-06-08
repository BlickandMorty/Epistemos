//! JCS number and UTF-16 sort oracle probe.
//!
//! This metadata-only probe pins the RFC 8785 Appendix B number sample table
//! and proves the Section 3.2.3 UTF-16 property-order sample locally before
//! synthetic fixture materialization can advance toward real bytes.

use crate::falsifier_artifacts::sha256_hex;
use crate::uas::{
    JcsCanonicalJsonWriterParityGateWitness, JCS_CANONICAL_JSON_WRITER_PARITY_GATE_CURSOR,
    JCS_CANONICAL_JSON_WRITER_PARITY_GATE_ID,
};
use serde::{Deserialize, Serialize};
use std::fmt;

pub const JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_ID: &str = "F-JcsNumberAndUtf16SortOracleProbe";
pub const JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_CURSOR: &str =
    "jcs_number_and_utf16_sort_oracle_probe";
pub const JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_NEXT_CURSOR: &str =
    "jcs_fixture_writer_fail_closed_dry_run";

const RFC_8785_URL: &str = "https://www.rfc-editor.org/rfc/rfc8785";
const ROLLBACK_REF: &str = "rollback:jcs_number_and_utf16_sort_oracle_probe";
const RUN_EVENT_LOG_REF: &str = "run_event_log:jcs_number_and_utf16_sort_oracle_probe";
const ANSWER_PACKET_REF: &str = "answer_packet:jcs_number_and_utf16_sort_oracle_probe";
const GUARD_PRODUCT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
// UAS: uas:jcs-number-utf16-oracle:status
// Plane: Verification + Controller.
// Residency: metadata-only oracle; writer bytes remain blocked.
pub enum JcsNumberUtf16OracleStatus {
    OraclePinnedWriterStillBlocked,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-number-utf16-oracle:number-sample
// Plane: Verification.
// Residency: RFC 8785 Appendix B sample row, no file bytes.
pub struct JcsNumberOracleSample {
    pub ieee754_hex: String,
    pub expected_json: String,
    pub disposition: String,
    pub comment: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-number-utf16-oracle:utf16-sort-sample
// Plane: Verification.
// Residency: RFC 8785 Section 3.2.3 property-sort sample row.
pub struct JcsUtf16SortSample {
    pub property: String,
    pub label: String,
    pub expected_rank: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-number-utf16-oracle:source-card
// Plane: Verification.
// Residency: primary-source-only oracle table; no external code import.
pub struct JcsNumberUtf16OracleSourceCard {
    pub rfc_8785_url: String,
    pub appendix_b_number_table_bound: bool,
    pub section_3_2_3_utf16_sort_bound: bool,
    pub node_json_stringify_research_observed: bool,
    pub local_writer_implementation_claimed: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-number-utf16-oracle:policy
// Plane: Verification.
// Residency: blocks materialization until a later writer dry-run proves bytes.
pub struct JcsNumberUtf16OraclePolicy {
    pub ieee754_hex_required: bool,
    pub ecmascript_expected_json_required: bool,
    pub nan_infinity_rejection_required: bool,
    pub minus_zero_normalization_required: bool,
    pub utf16_code_unit_sort_required: bool,
    pub utf8_sort_not_authority: bool,
    pub locale_sort_not_authority: bool,
    pub materialization_blocked_until_writer_dry_run: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-number-utf16-oracle:byte-ledger
// Plane: Verification.
// Residency: metadata-only; no fixture/model/runtime bytes.
pub struct JcsNumberUtf16OracleByteLedger {
    pub fixture_files_written: u64,
    pub fixture_bytes_written: u64,
    pub schema_files_written: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub cache_index_bytes_opened: u64,
    pub commands_armed: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-number-utf16-oracle:spec
// Plane: Verification + Controller.
// Residency: pinned oracle consumed by the JCS writer parity side-ladder.
pub struct JcsNumberAndUtf16SortOracleProbe {
    pub upstream_falsifier_id: String,
    pub upstream_cursor: String,
    pub upstream_jcs_parity_address: String,
    pub source_card: JcsNumberUtf16OracleSourceCard,
    pub policy: JcsNumberUtf16OraclePolicy,
    pub number_samples: Vec<JcsNumberOracleSample>,
    pub utf16_sort_samples: Vec<JcsUtf16SortSample>,
    pub number_sample_digest: String,
    pub utf16_sort_digest: String,
    pub byte_ledger: JcsNumberUtf16OracleByteLedger,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub guard_owned_product_cursor: String,
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
    pub status: JcsNumberUtf16OracleStatus,
}

impl JcsNumberAndUtf16SortOracleProbe {
    pub fn canonical() -> Result<Self, JcsNumberUtf16OracleError> {
        let upstream = JcsCanonicalJsonWriterParityGateWitness::new()
            .map_err(|_| JcsNumberUtf16OracleError::UpstreamJcsParityGateBroken)?;
        upstream
            .validate()
            .map_err(|_| JcsNumberUtf16OracleError::UpstreamJcsParityGateBroken)?;
        let number_samples = rfc8785_number_samples();
        let utf16_sort_samples = rfc8785_utf16_sort_samples();
        Ok(Self {
            upstream_falsifier_id: JCS_CANONICAL_JSON_WRITER_PARITY_GATE_ID.to_string(),
            upstream_cursor: JCS_CANONICAL_JSON_WRITER_PARITY_GATE_CURSOR.to_string(),
            upstream_jcs_parity_address: upstream.address,
            source_card: JcsNumberUtf16OracleSourceCard {
                rfc_8785_url: RFC_8785_URL.to_string(),
                appendix_b_number_table_bound: true,
                section_3_2_3_utf16_sort_bound: true,
                node_json_stringify_research_observed: true,
                local_writer_implementation_claimed: false,
            },
            policy: JcsNumberUtf16OraclePolicy {
                ieee754_hex_required: true,
                ecmascript_expected_json_required: true,
                nan_infinity_rejection_required: true,
                minus_zero_normalization_required: true,
                utf16_code_unit_sort_required: true,
                utf8_sort_not_authority: true,
                locale_sort_not_authority: true,
                materialization_blocked_until_writer_dry_run: true,
            },
            number_sample_digest: digest_json(&number_samples),
            utf16_sort_digest: digest_json(&utf16_sort_samples),
            number_samples,
            utf16_sort_samples,
            byte_ledger: JcsNumberUtf16OracleByteLedger {
                fixture_files_written: 0,
                fixture_bytes_written: 0,
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
            status: JcsNumberUtf16OracleStatus::OraclePinnedWriterStillBlocked,
        })
    }

    pub fn validate(&self) -> Result<(), JcsNumberUtf16OracleError> {
        let upstream = JcsCanonicalJsonWriterParityGateWitness::new()
            .map_err(|_| JcsNumberUtf16OracleError::UpstreamJcsParityGateBroken)?;
        upstream
            .validate()
            .map_err(|_| JcsNumberUtf16OracleError::UpstreamJcsParityGateBroken)?;
        validate_exact(
            "upstream_falsifier_id",
            &self.upstream_falsifier_id,
            JCS_CANONICAL_JSON_WRITER_PARITY_GATE_ID,
        )?;
        validate_exact(
            "upstream_cursor",
            &self.upstream_cursor,
            JCS_CANONICAL_JSON_WRITER_PARITY_GATE_CURSOR,
        )?;
        validate_exact(
            "upstream_jcs_parity_address",
            &self.upstream_jcs_parity_address,
            &upstream.address,
        )?;
        self.source_card.validate()?;
        self.policy.validate()?;
        validate_number_samples(&self.number_samples)?;
        validate_utf16_sort_samples(&self.utf16_sort_samples)?;
        validate_exact(
            "number_sample_digest",
            &self.number_sample_digest,
            &digest_json(&self.number_samples),
        )?;
        validate_exact(
            "utf16_sort_digest",
            &self.utf16_sort_digest,
            &digest_json(&self.utf16_sort_samples),
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
        if self.materialization_allowed || !self.metadata_only {
            return Err(JcsNumberUtf16OracleError::MaterializationBoundaryBroken);
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
            return Err(JcsNumberUtf16OracleError::PromotionClaim);
        }
        if self.status != JcsNumberUtf16OracleStatus::OraclePinnedWriterStillBlocked {
            return Err(JcsNumberUtf16OracleError::WrongStatus);
        }
        Ok(())
    }
}

impl JcsNumberUtf16OracleSourceCard {
    pub fn validate(&self) -> Result<(), JcsNumberUtf16OracleError> {
        validate_exact("rfc_8785_url", &self.rfc_8785_url, RFC_8785_URL)?;
        if !self.appendix_b_number_table_bound
            || !self.section_3_2_3_utf16_sort_bound
            || !self.node_json_stringify_research_observed
            || self.local_writer_implementation_claimed
        {
            return Err(JcsNumberUtf16OracleError::SourceCardBroken);
        }
        Ok(())
    }
}

impl JcsNumberUtf16OraclePolicy {
    pub fn validate(&self) -> Result<(), JcsNumberUtf16OracleError> {
        if !self.ieee754_hex_required
            || !self.ecmascript_expected_json_required
            || !self.nan_infinity_rejection_required
            || !self.minus_zero_normalization_required
            || !self.utf16_code_unit_sort_required
            || !self.utf8_sort_not_authority
            || !self.locale_sort_not_authority
            || !self.materialization_blocked_until_writer_dry_run
        {
            return Err(JcsNumberUtf16OracleError::PolicyBroken);
        }
        Ok(())
    }
}

impl JcsNumberUtf16OracleByteLedger {
    pub fn validate(&self) -> Result<(), JcsNumberUtf16OracleError> {
        if self.fixture_files_written != 0
            || self.fixture_bytes_written != 0
            || self.schema_files_written != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.cache_index_bytes_opened != 0
            || self.commands_armed != 0
        {
            return Err(JcsNumberUtf16OracleError::ByteOrCommandLeak);
        }
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-number-utf16-oracle:metrics
// Plane: Verification.
// Residency: metadata-only oracle counters.
pub struct JcsNumberUtf16OracleMetrics {
    pub number_sample_count: u64,
    pub finite_number_sample_count: u64,
    pub rejected_number_sample_count: u64,
    pub utf16_sort_sample_count: u64,
    pub utf16_sort_match_count: u64,
    pub fixture_files_written: u64,
    pub fixture_bytes_written: u64,
    pub runtime_model_provider_cache_index_bytes: u64,
    pub commands_armed: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:jcs-number-utf16-oracle:witness
// Plane: Verification + Controller.
// Residency: L1/T1 side-ladder; no fixture materialization.
pub struct JcsNumberAndUtf16SortOracleWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub spec: JcsNumberAndUtf16SortOracleProbe,
    pub metrics: JcsNumberUtf16OracleMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub product_promotion_blocked: bool,
}

impl JcsNumberAndUtf16SortOracleWitness {
    pub fn new() -> Result<Self, JcsNumberUtf16OracleError> {
        let spec = JcsNumberAndUtf16SortOracleProbe::canonical()?;
        spec.validate()?;
        let metrics = JcsNumberUtf16OracleMetrics {
            number_sample_count: spec.number_samples.len() as u64,
            finite_number_sample_count: spec
                .number_samples
                .iter()
                .filter(|sample| sample.disposition == "finite")
                .count() as u64,
            rejected_number_sample_count: spec
                .number_samples
                .iter()
                .filter(|sample| sample.disposition == "rejected")
                .count() as u64,
            utf16_sort_sample_count: spec.utf16_sort_samples.len() as u64,
            utf16_sort_match_count: utf16_sort_match_count(&spec.utf16_sort_samples),
            fixture_files_written: spec.byte_ledger.fixture_files_written
                + spec.byte_ledger.schema_files_written,
            fixture_bytes_written: spec.byte_ledger.fixture_bytes_written,
            runtime_model_provider_cache_index_bytes: spec.byte_ledger.model_runtime_bytes_loaded
                + spec.byte_ledger.provider_calls_made
                + spec.byte_ledger.cache_index_bytes_opened,
            commands_armed: spec.byte_ledger.commands_armed,
        };
        let address = jcs_number_and_utf16_sort_oracle_address(&spec, &metrics);
        Ok(Self {
            falsifier_id: JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_ID.to_string(),
            cursor: JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_CURSOR.to_string(),
            next_cursor: JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_NEXT_CURSOR.to_string(),
            spec,
            metrics,
            address,
            metadata_only: true,
            product_promotion_blocked: true,
        })
    }

    pub fn validate(&self) -> Result<(), JcsNumberUtf16OracleError> {
        if self.falsifier_id != JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_ID
            || self.cursor != JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_CURSOR
            || self.next_cursor != JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_NEXT_CURSOR
            || !self.metadata_only
            || !self.product_promotion_blocked
        {
            return Err(JcsNumberUtf16OracleError::WitnessHeaderBroken);
        }
        self.spec.validate()?;
        let rebuilt = Self::new()?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(JcsNumberUtf16OracleError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn jcs_number_and_utf16_sort_oracle_address(
    spec: &JcsNumberAndUtf16SortOracleProbe,
    metrics: &JcsNumberUtf16OracleMetrics,
) -> String {
    let payload = serde_json::json!({
        "id": JCS_NUMBER_AND_UTF16_SORT_ORACLE_PROBE_ID,
        "spec": spec,
        "metrics": metrics,
    });
    sha256_hex(payload.to_string().as_bytes())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:jcs-number-utf16-oracle:error
// Plane: Verification.
// Residency: fail-closed oracle rejection taxonomy.
pub enum JcsNumberUtf16OracleError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    WrongValue(&'static str),
    UpstreamJcsParityGateBroken,
    SourceCardBroken,
    PolicyBroken,
    NumberSampleTableBroken,
    Utf16SortTableBroken,
    ByteOrCommandLeak,
    MaterializationBoundaryBroken,
    PromotionClaim,
    WrongStatus,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for JcsNumberUtf16OracleError {
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
            Self::UpstreamJcsParityGateBroken => write!(f, "upstream JCS parity gate broken"),
            Self::SourceCardBroken => write!(f, "source card broken"),
            Self::PolicyBroken => write!(f, "oracle policy broken"),
            Self::NumberSampleTableBroken => write!(f, "number sample table broken"),
            Self::Utf16SortTableBroken => write!(f, "UTF-16 sort table broken"),
            Self::ByteOrCommandLeak => write!(f, "byte or command leak"),
            Self::MaterializationBoundaryBroken => write!(f, "materialization boundary broken"),
            Self::PromotionClaim => write!(f, "promotion claim attempted"),
            Self::WrongStatus => write!(f, "wrong oracle status"),
            Self::WitnessHeaderBroken => write!(f, "witness header broken"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for JcsNumberUtf16OracleError {}

fn validate_number_samples(
    samples: &[JcsNumberOracleSample],
) -> Result<(), JcsNumberUtf16OracleError> {
    let canonical = rfc8785_number_samples();
    if samples != canonical {
        return Err(JcsNumberUtf16OracleError::NumberSampleTableBroken);
    }
    if samples.len() != 26
        || samples
            .iter()
            .filter(|sample| sample.disposition == "finite")
            .count()
            != 24
        || samples
            .iter()
            .filter(|sample| sample.disposition == "rejected")
            .count()
            != 2
    {
        return Err(JcsNumberUtf16OracleError::NumberSampleTableBroken);
    }
    Ok(())
}

fn validate_utf16_sort_samples(
    samples: &[JcsUtf16SortSample],
) -> Result<(), JcsNumberUtf16OracleError> {
    if samples != rfc8785_utf16_sort_samples() || utf16_sort_match_count(samples) != 7 {
        return Err(JcsNumberUtf16OracleError::Utf16SortTableBroken);
    }
    Ok(())
}

fn utf16_sort_match_count(samples: &[JcsUtf16SortSample]) -> u64 {
    let mut sorted = samples.to_vec();
    sorted.sort_by(|left, right| utf16_key(&left.property).cmp(&utf16_key(&right.property)));
    sorted
        .iter()
        .enumerate()
        .filter(|(index, sample)| sample.expected_rank as usize == index + 1)
        .count() as u64
}

fn utf16_key(value: &str) -> Vec<u16> {
    value.encode_utf16().collect()
}

fn rfc8785_number_samples() -> Vec<JcsNumberOracleSample> {
    vec![
        num("0000000000000000", "0", "finite", "zero"),
        num("8000000000000000", "0", "finite", "minus_zero"),
        num("0000000000000001", "5e-324", "finite", "min_pos_number"),
        num("8000000000000001", "-5e-324", "finite", "min_neg_number"),
        num(
            "7fefffffffffffff",
            "1.7976931348623157e+308",
            "finite",
            "max_pos_number",
        ),
        num(
            "ffefffffffffffff",
            "-1.7976931348623157e+308",
            "finite",
            "max_neg_number",
        ),
        num(
            "4340000000000000",
            "9007199254740992",
            "finite",
            "max_pos_int",
        ),
        num(
            "c340000000000000",
            "-9007199254740992",
            "finite",
            "max_neg_int",
        ),
        num(
            "4430000000000000",
            "295147905179352830000",
            "finite",
            "two_to_68",
        ),
        num("7fffffffffffffff", "", "rejected", "nan"),
        num("7ff0000000000000", "", "rejected", "infinity"),
        num(
            "44b52d02c7e14af5",
            "9.999999999999997e+22",
            "finite",
            "edge_1e23_low",
        ),
        num("44b52d02c7e14af6", "1e+23", "finite", "edge_1e23_exact"),
        num(
            "44b52d02c7e14af7",
            "1.0000000000000001e+23",
            "finite",
            "edge_1e23_high",
        ),
        num(
            "444b1ae4d6e2ef4e",
            "999999999999999700000",
            "finite",
            "edge_1e21_low",
        ),
        num(
            "444b1ae4d6e2ef4f",
            "999999999999999900000",
            "finite",
            "edge_1e21_mid",
        ),
        num("444b1ae4d6e2ef50", "1e+21", "finite", "edge_1e21_exact"),
        num(
            "3eb0c6f7a0b5ed8c",
            "9.999999999999997e-7",
            "finite",
            "edge_1e_minus_6_low",
        ),
        num(
            "3eb0c6f7a0b5ed8d",
            "0.000001",
            "finite",
            "edge_1e_minus_6_exact",
        ),
        num(
            "41b3de4355555553",
            "333333333.3333332",
            "finite",
            "third_low_1",
        ),
        num(
            "41b3de4355555554",
            "333333333.33333325",
            "finite",
            "third_low_2",
        ),
        num(
            "41b3de4355555555",
            "333333333.3333333",
            "finite",
            "third_mid",
        ),
        num(
            "41b3de4355555556",
            "333333333.3333334",
            "finite",
            "third_high_1",
        ),
        num(
            "41b3de4355555557",
            "333333333.33333343",
            "finite",
            "third_high_2",
        ),
        num(
            "becbf647612f3696",
            "-0.0000033333333333333333",
            "finite",
            "negative_small",
        ),
        num(
            "43143ff3c1cb0959",
            "1424953923781206.2",
            "finite",
            "round_to_even",
        ),
    ]
}

fn rfc8785_utf16_sort_samples() -> Vec<JcsUtf16SortSample> {
    vec![
        sort("\r", "carriage_return", 1),
        sort("1", "one", 2),
        sort("\u{0080}", "control", 3),
        sort("\u{00f6}", "latin_small_letter_o_with_diaeresis", 4),
        sort("\u{20ac}", "euro_sign", 5),
        sort("\u{1f600}", "emoji_grinning_face", 6),
        sort("\u{fb33}", "hebrew_letter_dalet_with_dagesh", 7),
    ]
}

fn num(hex: &str, expected: &str, disposition: &str, comment: &str) -> JcsNumberOracleSample {
    JcsNumberOracleSample {
        ieee754_hex: hex.to_string(),
        expected_json: expected.to_string(),
        disposition: disposition.to_string(),
        comment: comment.to_string(),
    }
}

fn sort(property: &str, label: &str, expected_rank: u64) -> JcsUtf16SortSample {
    JcsUtf16SortSample {
        property: property.to_string(),
        label: label.to_string(),
        expected_rank,
    }
}

fn digest_json<T: Serialize>(value: &T) -> String {
    sha256_hex(
        serde_json::to_string(value)
            .expect("oracle digest serializes")
            .as_bytes(),
    )
}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), JcsNumberUtf16OracleError> {
    validate_token(field, value)?;
    if value != expected {
        return Err(JcsNumberUtf16OracleError::WrongValue(field));
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), JcsNumberUtf16OracleError> {
    if value.is_empty() {
        return Err(JcsNumberUtf16OracleError::MissingField(field));
    }
    if value.trim() != value {
        return Err(JcsNumberUtf16OracleError::FieldHasSurroundingWhitespace(
            field,
        ));
    }
    if value.chars().any(char::is_control) && !matches!(field, "property") {
        return Err(JcsNumberUtf16OracleError::FieldContainsControlCharacter(
            field,
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canonical_probe_validates() {
        JcsNumberAndUtf16SortOracleProbe::canonical()
            .expect("probe")
            .validate()
            .expect("canonical validates");
    }

    #[test]
    fn witness_is_deterministic() {
        let first = JcsNumberAndUtf16SortOracleWitness::new().expect("first");
        let second = JcsNumberAndUtf16SortOracleWitness::new().expect("second");
        assert_eq!(first.address, second.address);
        assert_eq!(first.metrics.number_sample_count, 26);
        assert_eq!(first.metrics.finite_number_sample_count, 24);
        assert_eq!(first.metrics.rejected_number_sample_count, 2);
        assert_eq!(first.metrics.utf16_sort_match_count, 7);
    }

    #[test]
    fn rejects_upstream_address_drift() {
        let mut probe = JcsNumberAndUtf16SortOracleProbe::canonical().expect("probe");
        probe.upstream_jcs_parity_address =
            "sha256:0000000000000000000000000000000000000000000000000000000000000000".to_string();
        assert_eq!(
            probe.validate().unwrap_err(),
            JcsNumberUtf16OracleError::WrongValue("upstream_jcs_parity_address")
        );
    }

    #[test]
    fn rejects_number_table_drift() {
        let mut probe = JcsNumberAndUtf16SortOracleProbe::canonical().expect("probe");
        probe.number_samples[12].expected_json = "1e23".to_string();
        assert_eq!(
            probe.validate().unwrap_err(),
            JcsNumberUtf16OracleError::NumberSampleTableBroken
        );
    }

    #[test]
    fn rejects_utf16_sort_table_drift() {
        let mut probe = JcsNumberAndUtf16SortOracleProbe::canonical().expect("probe");
        probe.utf16_sort_samples.swap(0, 1);
        assert_eq!(
            probe.validate().unwrap_err(),
            JcsNumberUtf16OracleError::Utf16SortTableBroken
        );
    }

    #[test]
    fn rejects_policy_bypass() {
        let mut probe = JcsNumberAndUtf16SortOracleProbe::canonical().expect("probe");
        probe.policy.utf8_sort_not_authority = false;
        assert_eq!(
            probe.validate().unwrap_err(),
            JcsNumberUtf16OracleError::PolicyBroken
        );
    }

    #[test]
    fn rejects_local_writer_claim() {
        let mut probe = JcsNumberAndUtf16SortOracleProbe::canonical().expect("probe");
        probe.source_card.local_writer_implementation_claimed = true;
        assert_eq!(
            probe.validate().unwrap_err(),
            JcsNumberUtf16OracleError::SourceCardBroken
        );
    }

    #[test]
    fn rejects_byte_leak() {
        let mut probe = JcsNumberAndUtf16SortOracleProbe::canonical().expect("probe");
        probe.byte_ledger.fixture_files_written = 1;
        assert_eq!(
            probe.validate().unwrap_err(),
            JcsNumberUtf16OracleError::ByteOrCommandLeak
        );
    }

    #[test]
    fn rejects_materialization_enablement() {
        let mut probe = JcsNumberAndUtf16SortOracleProbe::canonical().expect("probe");
        probe.materialization_allowed = true;
        assert_eq!(
            probe.validate().unwrap_err(),
            JcsNumberUtf16OracleError::MaterializationBoundaryBroken
        );
    }

    #[test]
    fn rejects_promotion_claim() {
        let mut probe = JcsNumberAndUtf16SortOracleProbe::canonical().expect("probe");
        probe.l2_claimed = true;
        assert_eq!(
            probe.validate().unwrap_err(),
            JcsNumberUtf16OracleError::PromotionClaim
        );
    }
}
