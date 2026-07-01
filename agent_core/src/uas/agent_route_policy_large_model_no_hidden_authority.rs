use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

pub const AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_ID: &str =
    "F-AgentRoutePolicy-LargeModelNoHiddenAuthority";
pub const AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_CURSOR: &str =
    "agent_route_policy_large_model_no_hidden_authority";
pub const AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_NEXT_CURSOR: &str =
    "visible_output_sanitization_release_blocker_card";
pub const AGENT_ROUTE_POLICY_UPSTREAM_REF: &str = "artifact:falsifiers/model_vault_catalog_release_blocker_card/result.json#F-ModelVaultCatalog-ReleaseBlockerCard";
pub const AGENT_ROUTE_POLICY_FAMILY_SOURCE_REF: &str =
    "artifact:falsifiers/release_audit_failure_family_source_card/result.json#agent_route_policy";

const REQUIRED_SOURCE_REFS: [&str; 10] = [
    "Epistemos/Engine/TriageService.swift",
    "Epistemos/Engine/PipelineService.swift",
    "Epistemos/State/AgentCommandCenterState.swift",
    "Epistemos/State/InferenceState.swift",
    "Epistemos/Engine/RuntimeExecutor.swift",
    "agent_core/src/agent_loop.rs",
    "agent_core/src/dispatcher.rs",
    "agent_core/src/agent_runtime_v2/system_g_runtime.rs",
    "agent_core/src/command_center.rs",
    "agent_core/src/routing.rs",
];

const REQUIRED_INVARIANTS: [&str; 12] = [
    "local_only_fast_paths_do_not_inherit_tool_authority",
    "model_vault_rows_are_not_route_authority",
    "large_model_candidates_require_catalog_loader_byte_runtime_proof",
    "mas_forbidden_tools_remain_denied",
    "pro_agent_tools_require_explicit_status_and_approval",
    "runtime_router_profile_is_visible_not_hidden",
    "system_g_run_requires_answer_packet",
    "system_g_run_requires_run_event_log",
    "cloud_fallback_never_hidden",
    "patternboost_eidos_lattice_not_live_authority",
    "rollback_required_before_route_mutation",
    "release_audit_family_remains_red_until_focused_tests_pass",
];

// UAS: uas:agent-route-policy-large-model-no-hidden-authority:organ
// Plane: Controller + Verification.
// Residency: metadata-only route authority classification.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentRoutePolicyOrgan {
    RuntimeRouter,
    SovereignGate,
    SystemG,
    Eidos,
    PatternBoost,
    LatticeController,
    RunEventLog,
    AnswerPacket,
}

// UAS: uas:agent-route-policy-large-model-no-hidden-authority:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AgentRoutePolicyStatus {
    RedReleaseBlocker,
}

// UAS: uas:agent-route-policy-large-model-no-hidden-authority:card
// Plane: Controller + Verification.
// Residency: metadata-only source-card blocker; no model/runtime bytes.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentRoutePolicyLargeModelNoHiddenAuthorityCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: AgentRoutePolicyOrgan,
    pub status: AgentRoutePolicyStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub mas_status: String,
    pub pro_status: String,
    pub hidden_route_authority: bool,
    pub hidden_tool_authority: bool,
    pub hidden_cloud_fallback: bool,
    pub model_vault_row_as_route_authority: bool,
    pub large_model_candidate_auto_route: bool,
    pub patternboost_live_authority: bool,
    pub eidos_live_router: bool,
    pub lattice_live_router: bool,
    pub mas_forbidden_tool_enabled: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub model_runtime_bytes_loaded: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl AgentRoutePolicyLargeModelNoHiddenAuthorityCard {
    pub fn from_family(family_id: &str, issue_count: u64) -> Result<Self, AgentRoutePolicyError> {
        validate_token("family_id", family_id)?;
        if family_id != "agent_route_policy" {
            return Err(AgentRoutePolicyError::WrongFamily(family_id.to_string()));
        }
        if issue_count == 0 {
            return Err(AgentRoutePolicyError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: AgentRoutePolicyOrgan::RuntimeRouter,
            status: AgentRoutePolicyStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild test -only-testing:EpistemosTests/TriageServiceTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/PipelineServiceTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/AgentCommandCenterStateTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/AgentAuthorityPersistenceTests"
                    .to_string(),
                "cargo test --manifest-path agent_core/Cargo.toml command_center".to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            mas_status: "red_release_blocker".to_string(),
            pro_status: "gated_release_blocker".to_string(),
            hidden_route_authority: false,
            hidden_tool_authority: false,
            hidden_cloud_fallback: false,
            model_vault_row_as_route_authority: false,
            large_model_candidate_auto_route: false,
            patternboost_live_authority: false,
            eidos_live_router: false,
            lattice_live_router: false,
            mas_forbidden_tool_enabled: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            model_runtime_bytes_loaded: 0,
            rollback_ref: "rollback:agent_route_policy_large_model_no_hidden_authority".to_string(),
            run_event_log_ref: "run_event_log:agent_route_policy_large_model_no_hidden_authority"
                .to_string(),
            answer_packet_ref: "answer_packet:agent_route_policy_large_model_no_hidden_authority"
                .to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), AgentRoutePolicyError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "agent_route_policy"
            || self.issue_count == 0
            || self.organ != AgentRoutePolicyOrgan::RuntimeRouter
            || self.status != AgentRoutePolicyStatus::RedReleaseBlocker
        {
            return Err(AgentRoutePolicyError::CardHeaderBroken);
        }
        validate_unique_exact_set("source_refs", &self.source_refs, &REQUIRED_SOURCE_REFS)?;
        validate_unique_exact_set(
            "required_invariants",
            &self.required_invariants,
            &REQUIRED_INVARIANTS,
        )?;
        validate_list("focused_commands", &self.focused_commands, 4, 8)?;
        let has_swift_test = self
            .focused_commands
            .iter()
            .any(|command| command.starts_with("xcodebuild test -only-testing:EpistemosTests/"));
        let has_rust_test = self
            .focused_commands
            .iter()
            .any(|command| command.starts_with("cargo test --manifest-path agent_core/Cargo.toml"));
        if !has_swift_test || !has_rust_test {
            return Err(AgentRoutePolicyError::BadFocusedCommand);
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
        if self.hidden_route_authority
            || self.hidden_tool_authority
            || self.hidden_cloud_fallback
            || self.model_vault_row_as_route_authority
            || self.large_model_candidate_auto_route
            || self.patternboost_live_authority
            || self.eidos_live_router
            || self.lattice_live_router
            || self.mas_forbidden_tool_enabled
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.live_dense_70b_claimed
            || self.model_runtime_bytes_loaded != 0
        {
            return Err(AgentRoutePolicyError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:agent-route-policy-large-model-no-hidden-authority:metrics
// Plane: Verification.
// Residency: aggregate release-blocker metrics only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentRoutePolicyMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub model_runtime_bytes_loaded: u64,
}

// UAS: uas:agent-route-policy-large-model-no-hidden-authority:witness
// Plane: Verification.
// Residency: metadata-only route-policy witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentRoutePolicyLargeModelNoHiddenAuthorityWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: AgentRoutePolicyLargeModelNoHiddenAuthorityCard,
    pub metrics: AgentRoutePolicyMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl AgentRoutePolicyLargeModelNoHiddenAuthorityWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, AgentRoutePolicyError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(AgentRoutePolicyError::UpstreamNotPassed);
        }
        if upstream_next_cursor != AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_CURSOR {
            return Err(AgentRoutePolicyError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card =
            AgentRoutePolicyLargeModelNoHiddenAuthorityCard::from_family(family_id, issue_count)?;
        card.validate()?;
        let metrics = AgentRoutePolicyMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
        };
        let address = route_policy_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_ID.to_string(),
            cursor: AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_CURSOR.to_string(),
            next_cursor: AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_NEXT_CURSOR.to_string(),
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

    pub fn validate(&self) -> Result<(), AgentRoutePolicyError> {
        if self.falsifier_id != AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_ID
            || self.cursor != AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_CURSOR
            || self.next_cursor != AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(AgentRoutePolicyError::WitnessHeaderBroken);
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
            return Err(AgentRoutePolicyError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_agent_route_policy_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_agent_route_policy_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn route_policy_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &AgentRoutePolicyLargeModelNoHiddenAuthorityCard,
    metrics: &AgentRoutePolicyMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_ID);
    preimage.push_str(AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_CURSOR);
    preimage.push_str(AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_NEXT_CURSOR);
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
) -> Result<(), AgentRoutePolicyError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(AgentRoutePolicyError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(AgentRoutePolicyError::MissingRequiredSet {
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
) -> Result<(), AgentRoutePolicyError> {
    if values.len() < min || values.len() > max {
        return Err(AgentRoutePolicyError::BadListLength {
            field,
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(AgentRoutePolicyError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), AgentRoutePolicyError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/model_vault_catalog_release_blocker_card/")
        || !value.contains("/result.json#F-ModelVaultCatalog-ReleaseBlockerCard")
    {
        return Err(AgentRoutePolicyError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), AgentRoutePolicyError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#agent_route_policy")
    {
        return Err(AgentRoutePolicyError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), AgentRoutePolicyError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(AgentRoutePolicyError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), AgentRoutePolicyError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(AgentRoutePolicyError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:agent-route-policy-large-model-no-hidden-authority:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum AgentRoutePolicyError {
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
    BadUpstreamRef,
    BadFamilySourceRef,
    UpstreamNotPassed,
    WrongUpstreamCursor(String),
    WrongFamily(String),
    ZeroIssueCount,
    CardHeaderBroken,
    BadFocusedCommand,
    PromotionBoundaryBroken,
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for AgentRoutePolicyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidToken { field, value } => {
                write!(f, "invalid token in {field}: {value:?}")
            }
            Self::InvalidText { field, value } => write!(f, "invalid text in {field}: {value:?}"),
            Self::BadListLength { field, actual } => {
                write!(f, "bad list length for {field}: {actual}")
            }
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
            Self::BadUpstreamRef => write!(f, "bad upstream model-vault blocker ref"),
            Self::BadFamilySourceRef => write!(f, "bad agent-route family source ref"),
            Self::UpstreamNotPassed => write!(f, "upstream model-vault blocker did not pass"),
            Self::WrongUpstreamCursor(cursor) => write!(f, "wrong upstream cursor: {cursor}"),
            Self::WrongFamily(family) => write!(f, "wrong release-audit family: {family}"),
            Self::ZeroIssueCount => write!(f, "agent-route issue count is zero"),
            Self::CardHeaderBroken => write!(f, "agent-route policy card header is broken"),
            Self::BadFocusedCommand => write!(f, "focused command set is incomplete"),
            Self::PromotionBoundaryBroken => {
                write!(f, "agent-route policy promotion boundary is broken")
            }
            Self::WitnessHeaderBroken => write!(f, "agent-route policy witness header is broken"),
            Self::WitnessDigestMismatch => write!(f, "agent-route policy witness digest mismatch"),
        }
    }
}

impl std::error::Error for AgentRoutePolicyError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accepts_agent_route_policy_blocker() {
        let witness = AgentRoutePolicyLargeModelNoHiddenAuthorityWitness::new(
            AGENT_ROUTE_POLICY_UPSTREAM_REF,
            AGENT_ROUTE_POLICY_FAMILY_SOURCE_REF,
            true,
            AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_CURSOR,
            "agent_route_policy",
            21,
        )
        .expect("valid route-policy blocker");
        witness.validate().expect("witness validates");
        assert_eq!(witness.metrics.source_ref_count, REQUIRED_SOURCE_REFS.len());
        assert_eq!(witness.metrics.invariant_count, REQUIRED_INVARIANTS.len());
        assert_eq!(witness.card.model_runtime_bytes_loaded, 0);
    }

    #[test]
    fn rejects_wrong_upstream_or_family() {
        assert!(AgentRoutePolicyLargeModelNoHiddenAuthorityWitness::new(
            AGENT_ROUTE_POLICY_UPSTREAM_REF,
            AGENT_ROUTE_POLICY_FAMILY_SOURCE_REF,
            false,
            AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_CURSOR,
            "agent_route_policy",
            21,
        )
        .is_err());
        assert!(AgentRoutePolicyLargeModelNoHiddenAuthorityWitness::new(
            AGENT_ROUTE_POLICY_UPSTREAM_REF,
            AGENT_ROUTE_POLICY_FAMILY_SOURCE_REF,
            true,
            "other_cursor",
            "agent_route_policy",
            21,
        )
        .is_err());
        assert!(AgentRoutePolicyLargeModelNoHiddenAuthorityWitness::new(
            AGENT_ROUTE_POLICY_UPSTREAM_REF,
            AGENT_ROUTE_POLICY_FAMILY_SOURCE_REF,
            true,
            AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_CURSOR,
            "model_vault_catalog",
            9,
        )
        .is_err());
    }

    #[test]
    fn rejects_hidden_authority_and_promotion() {
        let witness = AgentRoutePolicyLargeModelNoHiddenAuthorityWitness::new(
            AGENT_ROUTE_POLICY_UPSTREAM_REF,
            AGENT_ROUTE_POLICY_FAMILY_SOURCE_REF,
            true,
            AGENT_ROUTE_POLICY_LARGE_MODEL_NO_HIDDEN_AUTHORITY_CURSOR,
            "agent_route_policy",
            21,
        )
        .expect("valid route-policy blocker");
        let mut missing_source = witness.card.clone();
        missing_source
            .source_refs
            .retain(|value| value != "Epistemos/Engine/RuntimeExecutor.swift");
        assert!(missing_source.validate().is_err());

        let mut hidden = witness.card.clone();
        hidden.hidden_tool_authority = true;
        assert!(hidden.validate().is_err());

        let mut byte_leak = witness.card.clone();
        byte_leak.model_runtime_bytes_loaded = 1;
        assert!(byte_leak.validate().is_err());
    }

    #[test]
    fn required_source_refs_resolve_to_real_files() {
        // Hardening: the gate's safety claim is that these are THE route-authority
        // surface. The other tests only check the strings are present in the list;
        // if a referenced file is renamed or deleted the claim silently becomes
        // fiction while the gate still passes. Pin every ref to a real on-disk
        // file so a rename trips here instead of going unnoticed.
        let repo_root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
            .parent()
            .expect("agent_core has a parent (the repo root)");
        for source_ref in REQUIRED_SOURCE_REFS {
            let path = repo_root.join(source_ref);
            assert!(
                path.exists(),
                "no-hidden-authority gate references a missing source file: {source_ref}"
            );
        }
    }

    #[test]
    fn required_refs_and_invariants_are_unique_and_nonempty() {
        let refs: BTreeSet<&str> = REQUIRED_SOURCE_REFS.iter().copied().collect();
        assert_eq!(
            refs.len(),
            REQUIRED_SOURCE_REFS.len(),
            "duplicate entry in REQUIRED_SOURCE_REFS"
        );
        assert!(REQUIRED_SOURCE_REFS.iter().all(|s| !s.is_empty()));

        let invariants: BTreeSet<&str> = REQUIRED_INVARIANTS.iter().copied().collect();
        assert_eq!(
            invariants.len(),
            REQUIRED_INVARIANTS.len(),
            "duplicate entry in REQUIRED_INVARIANTS"
        );
        assert!(REQUIRED_INVARIANTS.iter().all(|s| !s.is_empty()));
    }
}
