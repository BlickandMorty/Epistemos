use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_ID: &str =
    "F-GraphFilterVisibilityFocusedProofRootCommandCard";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_CURSOR: &str =
    "graph_filter_visibility_focused_proof_root_command_card";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";
pub const GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_UPSTREAM_REF: &str = "artifact:falsifiers/graph_filter_visibility_focused_proof_root_manifest_gate/result.json#F-GraphFilterVisibilityFocusedProofRootManifestGate";

const REQUIRED_COMMAND_TEMPLATES: [&str; 3] = [
    "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS -derivedDataPath $PROOF_ROOT/DerivedData build-for-testing -resultBundlePath $PROOF_ROOT/build-for-testing.xcresult",
    "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS -derivedDataPath $PROOF_ROOT/DerivedData -xctestrun $SELECTED_TEST_PRODUCT -enumerate-tests > $PROOF_ROOT/enumerated-tests.json",
    "xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination platform=macOS -derivedDataPath $PROOF_ROOT/DerivedData -xctestrun $SELECTED_TEST_PRODUCT -only-testing:$FOCUSED_SELECTOR test-without-building -resultBundlePath $PROOF_ROOT/focused-graph-filter.xcresult",
];

const REQUIRED_PROOF_SURFACES: [&str; 9] = [
    "$PROOF_ROOT/focused-proof-root-manifest.json",
    "$PROOF_ROOT/build-for-testing.xcresult",
    "$PROOF_ROOT/enumerated-tests.json",
    "$PROOF_ROOT/focused-graph-filter.xcresult",
    "$PROOF_ROOT/pre-build-source-status.json",
    "$PROOF_ROOT/post-test-source-status.json",
    "$PROOF_ROOT/scheme-pre-action-ledger.json",
    "$PROOF_ROOT/run-event-log.json",
    "$PROOF_ROOT/answer-packet.json",
];

const REQUIRED_SAFETY_POLICIES: [&str; 12] = [
    "owner_approval_pending",
    "command_envelope_unarmed",
    "proof_root_scoped_derived_data",
    "selected_test_product_placeholder_required",
    "timeout_required",
    "cancellation_required",
    "teardown_required",
    "pre_and_post_source_status_required",
    "scheme_pre_action_accounting_required",
    "manifest_write_required",
    "full_automated_check_row_still_required",
    "focused_proof_cannot_replace_full_row",
];

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
// UAS: uas:graph-filter-visibility-focused-proof-root-command-card:status
// Plane: Controller + Verification.
// Residency: metadata-only unarmed command-card status.
pub enum GraphFilterFocusedProofRootCommandStatus {
    OwnerApprovalPendingUnarmed,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:graph-filter-visibility-focused-proof-root-command-card:spec
// Plane: Assembly + Controller + Verification.
// Residency: unarmed focused proof-root command templates; no Xcode execution.
pub struct GraphFilterFocusedProofRootCommandCard {
    pub proof_root_prefix: String,
    pub selected_test_product_placeholder: String,
    pub focused_selector_placeholder: String,
    pub required_command_templates: Vec<String>,
    pub required_proof_surfaces: Vec<String>,
    pub required_safety_policies: Vec<String>,
    pub seed_selector_count: u64,
    pub minimum_executed_test_count: u64,
    pub timeout_required: bool,
    pub cancellation_required: bool,
    pub teardown_required: bool,
    pub source_status_capture_required: bool,
    pub scheme_pre_action_accounting_required: bool,
    pub manifest_write_required: bool,
    pub full_automated_check_row_still_required: bool,
    pub focused_proof_replaces_full_row: bool,
    pub owner_approval_pending: bool,
    pub command_envelope_unarmed: bool,
    pub xcode_command_executed: bool,
    pub command_armed_count: u64,
    pub selected_test_product_bytes_opened: u64,
    pub xcode_result_bytes_opened: u64,
    pub app_runtime_bytes_loaded: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub product_code_changed: bool,
    pub raw_note_prompt_model_bytes_logged: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub release_ready_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
    pub status: GraphFilterFocusedProofRootCommandStatus,
}

impl GraphFilterFocusedProofRootCommandCard {
    pub fn canonical() -> Self {
        Self {
            proof_root_prefix: "artifacts/xcode/graph-filter-visibility-test-products/".to_string(),
            selected_test_product_placeholder: "$SELECTED_TEST_PRODUCT".to_string(),
            focused_selector_placeholder: "$FOCUSED_SELECTOR".to_string(),
            required_command_templates: REQUIRED_COMMAND_TEMPLATES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_proof_surfaces: REQUIRED_PROOF_SURFACES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            required_safety_policies: REQUIRED_SAFETY_POLICIES
                .iter()
                .map(|value| value.to_string())
                .collect(),
            seed_selector_count: 8,
            minimum_executed_test_count: 1,
            timeout_required: true,
            cancellation_required: true,
            teardown_required: true,
            source_status_capture_required: true,
            scheme_pre_action_accounting_required: true,
            manifest_write_required: true,
            full_automated_check_row_still_required: true,
            focused_proof_replaces_full_row: false,
            owner_approval_pending: true,
            command_envelope_unarmed: true,
            xcode_command_executed: false,
            command_armed_count: 0,
            selected_test_product_bytes_opened: 0,
            xcode_result_bytes_opened: 0,
            app_runtime_bytes_loaded: 0,
            model_runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            product_code_changed: false,
            raw_note_prompt_model_bytes_logged: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            release_ready_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            rollback_ref: "rollback:graph_filter_visibility_focused_proof_root_command_card"
                .to_string(),
            run_event_log_ref:
                "run_event_log:graph_filter_visibility_focused_proof_root_command_card".to_string(),
            answer_packet_ref:
                "answer_packet:graph_filter_visibility_focused_proof_root_command_card".to_string(),
            status: GraphFilterFocusedProofRootCommandStatus::OwnerApprovalPendingUnarmed,
        }
    }

    pub fn validate(&self) -> Result<(), GraphFilterFocusedProofRootCommandCardError> {
        if self
            .proof_root_prefix
            .contains("~/Library/Developer/Xcode/DerivedData")
            || self
                .proof_root_prefix
                .contains("/Library/Developer/Xcode/DerivedData")
        {
            return Err(GraphFilterFocusedProofRootCommandCardError::GlobalDerivedDataPath);
        }
        validate_prefix(
            "proof_root_prefix",
            &self.proof_root_prefix,
            "artifacts/xcode/graph-filter-visibility-test-products/",
        )?;
        validate_exact(
            "selected_test_product_placeholder",
            &self.selected_test_product_placeholder,
            "$SELECTED_TEST_PRODUCT",
        )?;
        validate_exact(
            "focused_selector_placeholder",
            &self.focused_selector_placeholder,
            "$FOCUSED_SELECTOR",
        )?;
        validate_unique_exact_set(
            "required_command_templates",
            &self.required_command_templates,
            &REQUIRED_COMMAND_TEMPLATES,
        )?;
        validate_unique_exact_set(
            "required_proof_surfaces",
            &self.required_proof_surfaces,
            &REQUIRED_PROOF_SURFACES,
        )?;
        validate_unique_exact_set(
            "required_safety_policies",
            &self.required_safety_policies,
            &REQUIRED_SAFETY_POLICIES,
        )?;
        if self.seed_selector_count != 8 || self.minimum_executed_test_count == 0 {
            return Err(GraphFilterFocusedProofRootCommandCardError::CommandPolicyBroken);
        }
        if !self.timeout_required
            || !self.cancellation_required
            || !self.teardown_required
            || !self.source_status_capture_required
            || !self.scheme_pre_action_accounting_required
            || !self.manifest_write_required
            || !self.full_automated_check_row_still_required
            || self.focused_proof_replaces_full_row
        {
            return Err(GraphFilterFocusedProofRootCommandCardError::ProofBoundaryBroken);
        }
        if !self.owner_approval_pending
            || !self.command_envelope_unarmed
            || self.xcode_command_executed
            || self.command_armed_count != 0
            || self.selected_test_product_bytes_opened != 0
            || self.xcode_result_bytes_opened != 0
            || self.app_runtime_bytes_loaded != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
            || self.product_code_changed
            || self.raw_note_prompt_model_bytes_logged
        {
            return Err(GraphFilterFocusedProofRootCommandCardError::ByteOrExecutionLeak);
        }
        if self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.release_ready_claimed
            || self.live_dense_70b_claimed
            || self.ssd_as_ram_claimed
        {
            return Err(GraphFilterFocusedProofRootCommandCardError::PromotionClaim);
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
// UAS: uas:graph-filter-visibility-focused-proof-root-command-card:metrics
// Plane: Verification.
// Residency: command-card counts and zero-byte ledger.
pub struct GraphFilterFocusedProofRootCommandCardMetrics {
    pub command_template_count: usize,
    pub proof_surface_count: usize,
    pub safety_policy_count: usize,
    pub seed_selector_count: u64,
    pub minimum_executed_test_count: u64,
    pub command_armed_count: u64,
    pub selected_test_product_bytes_opened: u64,
    pub xcode_result_bytes_opened: u64,
    pub app_runtime_bytes_loaded: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
// UAS: uas:graph-filter-visibility-focused-proof-root-command-card:witness
// Plane: Controller + Verification.
// Residency: metadata-only command card bound to the manifest gate.
pub struct GraphFilterVisibilityFocusedProofRootCommandCardWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_artifact_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_address: String,
    pub upstream_next_cursor: String,
    pub spec: GraphFilterFocusedProofRootCommandCard,
    pub metrics: GraphFilterFocusedProofRootCommandCardMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl GraphFilterVisibilityFocusedProofRootCommandCardWitness {
    pub fn new(
        upstream_overall_pass: bool,
        upstream_address: &str,
        upstream_next_cursor: &str,
    ) -> Result<Self, GraphFilterFocusedProofRootCommandCardError> {
        if !upstream_overall_pass {
            return Err(GraphFilterFocusedProofRootCommandCardError::UpstreamNotPassed);
        }
        validate_sha256_address("upstream_address", upstream_address)?;
        validate_exact(
            "upstream_next_cursor",
            upstream_next_cursor,
            GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_NEXT_CURSOR,
        )?;
        let spec = GraphFilterFocusedProofRootCommandCard::canonical();
        spec.validate()?;
        let metrics = GraphFilterFocusedProofRootCommandCardMetrics {
            command_template_count: spec.required_command_templates.len(),
            proof_surface_count: spec.required_proof_surfaces.len(),
            safety_policy_count: spec.required_safety_policies.len(),
            seed_selector_count: spec.seed_selector_count,
            minimum_executed_test_count: spec.minimum_executed_test_count,
            command_armed_count: spec.command_armed_count,
            selected_test_product_bytes_opened: spec.selected_test_product_bytes_opened,
            xcode_result_bytes_opened: spec.xcode_result_bytes_opened,
            app_runtime_bytes_loaded: spec.app_runtime_bytes_loaded,
            model_runtime_bytes_loaded: spec.model_runtime_bytes_loaded,
            provider_calls_made: spec.provider_calls_made,
        };
        let address = graph_filter_focused_proof_root_command_card_address(
            upstream_overall_pass,
            upstream_address,
            upstream_next_cursor,
            &spec,
            &metrics,
        );
        Ok(Self {
            falsifier_id: GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_ID.to_string(),
            cursor: GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_CURSOR.to_string(),
            next_cursor: GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_NEXT_CURSOR
                .to_string(),
            upstream_artifact_ref:
                GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_UPSTREAM_REF.to_string(),
            upstream_overall_pass,
            upstream_address: upstream_address.to_string(),
            upstream_next_cursor: upstream_next_cursor.to_string(),
            spec,
            metrics,
            address,
            metadata_only: true,
            no_product_promotion: true,
        })
    }

    pub fn validate(&self) -> Result<(), GraphFilterFocusedProofRootCommandCardError> {
        if self.falsifier_id != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_ID
            || self.cursor != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_CURSOR
            || self.next_cursor
                != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_NEXT_CURSOR
            || self.upstream_artifact_ref
                != GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_UPSTREAM_REF
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(GraphFilterFocusedProofRootCommandCardError::WitnessHeaderBroken);
        }
        let rebuilt = Self::new(
            self.upstream_overall_pass,
            &self.upstream_address,
            &self.upstream_next_cursor,
        )?;
        if rebuilt.address != self.address || rebuilt.metrics != self.metrics {
            return Err(GraphFilterFocusedProofRootCommandCardError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_graph_filter_focused_proof_root_command_templates() -> &'static [&'static str] {
    &REQUIRED_COMMAND_TEMPLATES
}

pub fn required_graph_filter_focused_proof_root_proof_surfaces() -> &'static [&'static str] {
    &REQUIRED_PROOF_SURFACES
}

pub fn required_graph_filter_focused_proof_root_safety_policies() -> &'static [&'static str] {
    &REQUIRED_SAFETY_POLICIES
}

fn graph_filter_focused_proof_root_command_card_address(
    upstream_overall_pass: bool,
    upstream_address: &str,
    upstream_next_cursor: &str,
    spec: &GraphFilterFocusedProofRootCommandCard,
    metrics: &GraphFilterFocusedProofRootCommandCardMetrics,
) -> String {
    let payload = serde_json::json!({
        "id": GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_ID,
        "upstream_overall_pass": upstream_overall_pass,
        "upstream_address": upstream_address,
        "upstream_next_cursor": upstream_next_cursor,
        "spec": spec,
        "metrics": metrics,
    });
    sha256_hex(payload.to_string().as_bytes())
}

#[derive(Clone, Debug, PartialEq, Eq)]
// UAS: uas:graph-filter-visibility-focused-proof-root-command-card:error
// Plane: Verification.
// Residency: fail-closed command-card rejection taxonomy.
pub enum GraphFilterFocusedProofRootCommandCardError {
    MissingField(&'static str),
    FieldHasSurroundingWhitespace(&'static str),
    FieldContainsControlCharacter(&'static str),
    WrongValue(&'static str),
    DuplicateField(String),
    MissingRequiredField(&'static str),
    GlobalDerivedDataPath,
    CommandPolicyBroken,
    ProofBoundaryBroken,
    ByteOrExecutionLeak,
    PromotionClaim,
    UpstreamNotPassed,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for GraphFilterFocusedProofRootCommandCardError {
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
            Self::GlobalDerivedDataPath => write!(f, "global DerivedData path used"),
            Self::CommandPolicyBroken => write!(f, "command policy broken"),
            Self::ProofBoundaryBroken => write!(f, "proof boundary broken"),
            Self::ByteOrExecutionLeak => write!(f, "byte or execution leak"),
            Self::PromotionClaim => write!(f, "promotion claim attempted"),
            Self::UpstreamNotPassed => write!(f, "upstream manifest gate not passed"),
            Self::WitnessHeaderBroken => write!(f, "witness header broken"),
            Self::WitnessDigestMismatch => write!(f, "witness digest mismatch"),
        }
    }
}

impl std::error::Error for GraphFilterFocusedProofRootCommandCardError {}

fn validate_exact(
    field: &'static str,
    value: &str,
    expected: &str,
) -> Result<(), GraphFilterFocusedProofRootCommandCardError> {
    validate_token(field, value)?;
    if value != expected {
        return Err(GraphFilterFocusedProofRootCommandCardError::WrongValue(
            field,
        ));
    }
    Ok(())
}

fn validate_prefix(
    field: &'static str,
    value: &str,
    prefix: &str,
) -> Result<(), GraphFilterFocusedProofRootCommandCardError> {
    validate_token(field, value)?;
    if !value.starts_with(prefix) {
        return Err(GraphFilterFocusedProofRootCommandCardError::WrongValue(
            field,
        ));
    }
    Ok(())
}

fn validate_sha256_address(
    field: &'static str,
    value: &str,
) -> Result<(), GraphFilterFocusedProofRootCommandCardError> {
    validate_token(field, value)?;
    if !value.starts_with("sha256:") || value.len() != 71 {
        return Err(GraphFilterFocusedProofRootCommandCardError::WrongValue(
            field,
        ));
    }
    Ok(())
}

fn validate_token(
    field: &'static str,
    value: &str,
) -> Result<(), GraphFilterFocusedProofRootCommandCardError> {
    if value.is_empty() {
        return Err(GraphFilterFocusedProofRootCommandCardError::MissingField(
            field,
        ));
    }
    if value.trim() != value {
        return Err(
            GraphFilterFocusedProofRootCommandCardError::FieldHasSurroundingWhitespace(field),
        );
    }
    if value.chars().any(char::is_control) {
        return Err(
            GraphFilterFocusedProofRootCommandCardError::FieldContainsControlCharacter(field),
        );
    }
    Ok(())
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    expected: &[&'static str],
) -> Result<(), GraphFilterFocusedProofRootCommandCardError> {
    if values.is_empty() {
        return Err(GraphFilterFocusedProofRootCommandCardError::MissingField(
            field,
        ));
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_token(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(GraphFilterFocusedProofRootCommandCardError::DuplicateField(
                value.clone(),
            ));
        }
    }
    for required in expected {
        if !seen.contains(required) {
            return Err(
                GraphFilterFocusedProofRootCommandCardError::MissingRequiredField(required),
            );
        }
    }
    if seen.len() != expected.len() {
        return Err(GraphFilterFocusedProofRootCommandCardError::WrongValue(
            field,
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    const UPSTREAM_ADDRESS: &str =
        "sha256:bef74a16a07327e94b3b4fa36c619bbbc80957072f43886390bf1a920fdbc05c";

    #[test]
    fn canonical_card_validates() {
        GraphFilterFocusedProofRootCommandCard::canonical()
            .validate()
            .expect("canonical command card should validate");
    }

    #[test]
    fn witness_is_deterministic() {
        let first = GraphFilterVisibilityFocusedProofRootCommandCardWitness::new(
            true,
            UPSTREAM_ADDRESS,
            GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_NEXT_CURSOR,
        )
        .expect("valid witness");
        let second = GraphFilterVisibilityFocusedProofRootCommandCardWitness::new(
            true,
            UPSTREAM_ADDRESS,
            GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_NEXT_CURSOR,
        )
        .expect("valid witness");
        assert_eq!(first.address, second.address);
        assert_eq!(first.metrics.command_template_count, 3);
        assert_eq!(first.metrics.proof_surface_count, 9);
        assert_eq!(first.metrics.safety_policy_count, 12);
    }

    #[test]
    fn rejects_global_derived_data_path() {
        let mut card = GraphFilterFocusedProofRootCommandCard::canonical();
        card.proof_root_prefix = "~/Library/Developer/Xcode/DerivedData/graph-filter/".to_string();
        assert_eq!(
            card.validate().unwrap_err(),
            GraphFilterFocusedProofRootCommandCardError::GlobalDerivedDataPath
        );
    }

    #[test]
    fn rejects_missing_command_template() {
        let mut card = GraphFilterFocusedProofRootCommandCard::canonical();
        card.required_command_templates.pop();
        assert_eq!(
            card.validate().unwrap_err(),
            GraphFilterFocusedProofRootCommandCardError::MissingRequiredField(
                REQUIRED_COMMAND_TEMPLATES[2]
            )
        );
    }

    #[test]
    fn rejects_armed_or_executed_commands() {
        let mut card = GraphFilterFocusedProofRootCommandCard::canonical();
        card.xcode_command_executed = true;
        assert_eq!(
            card.validate().unwrap_err(),
            GraphFilterFocusedProofRootCommandCardError::ByteOrExecutionLeak
        );
        let mut armed = GraphFilterFocusedProofRootCommandCard::canonical();
        armed.command_armed_count = 1;
        assert_eq!(
            armed.validate().unwrap_err(),
            GraphFilterFocusedProofRootCommandCardError::ByteOrExecutionLeak
        );
    }

    #[test]
    fn rejects_missing_timeout_cancellation_or_teardown() {
        for mutate in [
            |card: &mut GraphFilterFocusedProofRootCommandCard| card.timeout_required = false,
            |card: &mut GraphFilterFocusedProofRootCommandCard| card.cancellation_required = false,
            |card: &mut GraphFilterFocusedProofRootCommandCard| card.teardown_required = false,
        ] {
            let mut card = GraphFilterFocusedProofRootCommandCard::canonical();
            mutate(&mut card);
            assert_eq!(
                card.validate().unwrap_err(),
                GraphFilterFocusedProofRootCommandCardError::ProofBoundaryBroken
            );
        }
    }

    #[test]
    fn rejects_byte_and_provider_leaks() {
        let mut card = GraphFilterFocusedProofRootCommandCard::canonical();
        card.selected_test_product_bytes_opened = 1;
        assert_eq!(
            card.validate().unwrap_err(),
            GraphFilterFocusedProofRootCommandCardError::ByteOrExecutionLeak
        );
        let mut provider = GraphFilterFocusedProofRootCommandCard::canonical();
        provider.provider_calls_made = 1;
        assert_eq!(
            provider.validate().unwrap_err(),
            GraphFilterFocusedProofRootCommandCardError::ByteOrExecutionLeak
        );
    }

    #[test]
    fn rejects_release_and_large_model_claims() {
        let mut release = GraphFilterFocusedProofRootCommandCard::canonical();
        release.release_ready_claimed = true;
        assert_eq!(
            release.validate().unwrap_err(),
            GraphFilterFocusedProofRootCommandCardError::PromotionClaim
        );
        let mut large = GraphFilterFocusedProofRootCommandCard::canonical();
        large.live_dense_70b_claimed = true;
        assert_eq!(
            large.validate().unwrap_err(),
            GraphFilterFocusedProofRootCommandCardError::PromotionClaim
        );
    }

    #[test]
    fn rejects_bad_upstream() {
        assert_eq!(
            GraphFilterVisibilityFocusedProofRootCommandCardWitness::new(
                false,
                UPSTREAM_ADDRESS,
                GRAPH_FILTER_VISIBILITY_FOCUSED_PROOF_ROOT_COMMAND_CARD_NEXT_CURSOR,
            )
            .unwrap_err(),
            GraphFilterFocusedProofRootCommandCardError::UpstreamNotPassed
        );
    }
}
