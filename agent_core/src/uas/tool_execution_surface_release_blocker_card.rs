use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::error::Error;
use std::fmt;

pub const TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_ID: &str =
    "F-ToolExecutionSurface-ReleaseBlockerCard";
pub const TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_CURSOR: &str =
    "tool_execution_surface_release_blocker_card";
pub const TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR: &str =
    "xpc_trust_configuration_release_blocker_card";
pub const TOOL_EXECUTION_SURFACE_UPSTREAM_REF: &str = "artifact:falsifiers/source_guard_drift_release_blocker_card/result.json#F-SourceGuardDrift-ReleaseBlockerCard";
pub const TOOL_EXECUTION_SURFACE_FAMILY_SOURCE_REF: &str = "artifact:falsifiers/release_audit_failure_family_source_card/result.json#tool_execution_surface";

const REQUIRED_SOURCE_REFS: [&str; 12] = [
    "Epistemos/LocalAgent/LocalAgentLoop.swift",
    "Epistemos/LocalAgent/LocalAgentCommandDispatcher.swift",
    "Epistemos/LocalAgent/LocalToolGrammar.swift",
    "Epistemos/LocalAgent/RuntimeRouter.swift",
    "Epistemos/State/AgentCommandCenterState.swift",
    "Epistemos/Engine/TriageService.swift",
    "agent_core/src/tools/registry.rs",
    "agent_core/src/security.rs",
    "agent_core/src/bin/falsify_local_tool_use.rs",
    "agent_core/tests/runtime_router_policy_order_source_guard.rs",
    "docs/MAS_PRO_SOURCE_GUARD_2026_05_05.md",
    "docs/fusion/DEEP_RESEARCH_BREAKTHROUGH_SYNTHESIS_2026_06_06.md",
];

const REQUIRED_INVARIANTS: [&str; 17] = [
    "upstream_source_guard_drift_bound",
    "tool_surface_source_refs_bound",
    "tool_schema_digest_required",
    "tool_policy_admission_required",
    "mas_forbidden_tool_denial_required",
    "pro_tool_owner_approval_required",
    "mutating_tool_confirmation_required",
    "subprocess_hardening_required",
    "tool_output_sanitization_required",
    "run_event_log_required",
    "answer_packet_required",
    "rollback_or_abstention_required",
    "runtime_router_no_hidden_tool_authority",
    "eidos_patternboost_lattice_no_tool_authority",
    "no_hidden_cloud_or_provider_fallback",
    "no_product_green_from_tool_surface",
    "zero_tool_model_runtime_provider_bytes",
];

// UAS: uas:tool-execution-surface-release-blocker-card:organ
// Plane: Controller + Verification.
// Residency: metadata-only tool execution source-card.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ToolExecutionSurfaceOrgan {
    ToolExecutionSurface,
    SovereignGate,
    RuntimeRouter,
    MasProBoundary,
    AnswerPacket,
}

// UAS: uas:tool-execution-surface-release-blocker-card:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ToolExecutionSurfaceStatus {
    RedReleaseBlocker,
}

// UAS: uas:tool-execution-surface-release-blocker-card:surface
// Plane: State + Controller + Verification.
// Residency: tool-surface taxonomy; no tool/model/runtime bytes opened.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ToolExecutionSurface {
    SwiftLocalAgentLoop,
    SwiftCommandDispatcher,
    SwiftToolGrammar,
    SwiftRuntimeRouter,
    SwiftCommandCenter,
    RustToolRegistry,
    RustSecurityHardening,
    LocalToolUseWitness,
    MasProCanon,
    DeepResearchCanon,
}

// UAS: uas:tool-execution-surface-release-blocker-card:card
// Plane: Controller + Verification.
// Residency: metadata-only tool execution blocker card.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolExecutionSurfaceReleaseBlockerCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: ToolExecutionSurfaceOrgan,
    pub status: ToolExecutionSurfaceStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub surfaces: Vec<ToolExecutionSurface>,
    pub upstream_source_guard_drift_required: bool,
    pub tool_schema_digest_required: bool,
    pub sovereign_admission_required: bool,
    pub mas_forbidden_tool_denial_required: bool,
    pub pro_tool_owner_approval_required: bool,
    pub mutating_tool_confirmation_required: bool,
    pub subprocess_hardening_required: bool,
    pub tool_output_sanitization_required: bool,
    pub run_event_log_required: bool,
    pub answer_packet_required: bool,
    pub rollback_or_abstention_required: bool,
    pub runtime_router_hidden_tool_authority_allowed: bool,
    pub eidos_patternboost_lattice_tool_authority_allowed: bool,
    pub hidden_cloud_or_provider_fallback_allowed: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub tool_execution_bytes_opened: u64,
    pub tool_commands_executed: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl ToolExecutionSurfaceReleaseBlockerCard {
    pub fn from_family(
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, ToolExecutionSurfaceError> {
        validate_token("family_id", family_id)?;
        if family_id != "tool_execution_surface" {
            return Err(ToolExecutionSurfaceError::WrongFamily(
                family_id.to_string(),
            ));
        }
        if issue_count == 0 {
            return Err(ToolExecutionSurfaceError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: ToolExecutionSurfaceOrgan::ToolExecutionSurface,
            status: ToolExecutionSurfaceStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild test -only-testing:EpistemosTests/FLocalToolUseTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/RuntimeRouterTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/CoreMASBoundarySourceGuardTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/UserFacingModelOutputTests"
                    .to_string(),
                "cargo test --manifest-path agent_core/Cargo.toml runtime_router_policy_order_source_guard"
                    .to_string(),
                "cargo test --manifest-path agent_core/Cargo.toml --bin falsify_local_tool_use"
                    .to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            surfaces: vec![
                ToolExecutionSurface::SwiftLocalAgentLoop,
                ToolExecutionSurface::SwiftCommandDispatcher,
                ToolExecutionSurface::SwiftToolGrammar,
                ToolExecutionSurface::SwiftRuntimeRouter,
                ToolExecutionSurface::SwiftCommandCenter,
                ToolExecutionSurface::RustToolRegistry,
                ToolExecutionSurface::RustSecurityHardening,
                ToolExecutionSurface::LocalToolUseWitness,
                ToolExecutionSurface::MasProCanon,
                ToolExecutionSurface::DeepResearchCanon,
            ],
            upstream_source_guard_drift_required: true,
            tool_schema_digest_required: true,
            sovereign_admission_required: true,
            mas_forbidden_tool_denial_required: true,
            pro_tool_owner_approval_required: true,
            mutating_tool_confirmation_required: true,
            subprocess_hardening_required: true,
            tool_output_sanitization_required: true,
            run_event_log_required: true,
            answer_packet_required: true,
            rollback_or_abstention_required: true,
            runtime_router_hidden_tool_authority_allowed: false,
            eidos_patternboost_lattice_tool_authority_allowed: false,
            hidden_cloud_or_provider_fallback_allowed: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            tool_execution_bytes_opened: 0,
            tool_commands_executed: 0,
            model_runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            rollback_ref: "rollback:tool_execution_surface_release_blocker_card".to_string(),
            run_event_log_ref: "run_event_log:tool_execution_surface_release_blocker_card"
                .to_string(),
            answer_packet_ref: "answer_packet:tool_execution_surface_release_blocker_card"
                .to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), ToolExecutionSurfaceError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "tool_execution_surface"
            || self.issue_count == 0
            || self.organ != ToolExecutionSurfaceOrgan::ToolExecutionSurface
            || self.status != ToolExecutionSurfaceStatus::RedReleaseBlocker
        {
            return Err(ToolExecutionSurfaceError::CardHeaderBroken);
        }
        validate_unique_exact_set("source_refs", &self.source_refs, &REQUIRED_SOURCE_REFS)?;
        validate_unique_exact_set(
            "required_invariants",
            &self.required_invariants,
            &REQUIRED_INVARIANTS,
        )?;
        validate_focused_commands(&self.focused_commands)?;
        validate_exact_enum_set(
            "surfaces",
            &self.surfaces,
            &[
                ToolExecutionSurface::SwiftLocalAgentLoop,
                ToolExecutionSurface::SwiftCommandDispatcher,
                ToolExecutionSurface::SwiftToolGrammar,
                ToolExecutionSurface::SwiftRuntimeRouter,
                ToolExecutionSurface::SwiftCommandCenter,
                ToolExecutionSurface::RustToolRegistry,
                ToolExecutionSurface::RustSecurityHardening,
                ToolExecutionSurface::LocalToolUseWitness,
                ToolExecutionSurface::MasProCanon,
                ToolExecutionSurface::DeepResearchCanon,
            ],
        )?;
        for value in [
            &self.rollback_ref,
            &self.run_event_log_ref,
            &self.answer_packet_ref,
        ] {
            validate_token("proof_ref", value)?;
        }
        if !self.upstream_source_guard_drift_required
            || !self.tool_schema_digest_required
            || !self.sovereign_admission_required
            || !self.mas_forbidden_tool_denial_required
            || !self.pro_tool_owner_approval_required
            || !self.mutating_tool_confirmation_required
            || !self.subprocess_hardening_required
            || !self.tool_output_sanitization_required
            || !self.run_event_log_required
            || !self.answer_packet_required
            || !self.rollback_or_abstention_required
            || self.runtime_router_hidden_tool_authority_allowed
            || self.eidos_patternboost_lattice_tool_authority_allowed
            || self.hidden_cloud_or_provider_fallback_allowed
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.live_dense_70b_claimed
            || self.ssd_as_ram_claimed
            || self.tool_execution_bytes_opened != 0
            || self.tool_commands_executed != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(ToolExecutionSurfaceError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:tool-execution-surface-release-blocker-card:metrics
// Plane: Verification.
// Residency: aggregate tool-surface metadata only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolExecutionSurfaceMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub surface_count: usize,
    pub tool_execution_bytes_opened: u64,
    pub tool_commands_executed: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

// UAS: uas:tool-execution-surface-release-blocker-card:witness
// Plane: Controller + Verification.
// Residency: metadata-only tool execution source-card witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolExecutionSurfaceReleaseBlockerWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: ToolExecutionSurfaceReleaseBlockerCard,
    pub metrics: ToolExecutionSurfaceMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl ToolExecutionSurfaceReleaseBlockerWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, ToolExecutionSurfaceError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(ToolExecutionSurfaceError::UpstreamNotPassed);
        }
        if upstream_next_cursor != TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_CURSOR {
            return Err(ToolExecutionSurfaceError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card = ToolExecutionSurfaceReleaseBlockerCard::from_family(family_id, issue_count)?;
        card.validate()?;
        let metrics = ToolExecutionSurfaceMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            surface_count: card.surfaces.len(),
            tool_execution_bytes_opened: card.tool_execution_bytes_opened,
            tool_commands_executed: card.tool_commands_executed,
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
            provider_calls_made: card.provider_calls_made,
        };
        let address = tool_execution_surface_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_ID.to_string(),
            cursor: TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_CURSOR.to_string(),
            next_cursor: TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR.to_string(),
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

    pub fn validate(&self) -> Result<(), ToolExecutionSurfaceError> {
        if self.falsifier_id != TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_ID
            || self.cursor != TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_CURSOR
            || self.next_cursor != TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(ToolExecutionSurfaceError::WitnessHeaderBroken);
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
            return Err(ToolExecutionSurfaceError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_tool_execution_surface_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_tool_execution_surface_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn tool_execution_surface_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &ToolExecutionSurfaceReleaseBlockerCard,
    metrics: &ToolExecutionSurfaceMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_ID);
    preimage.push_str(TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_CURSOR);
    preimage.push_str(TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_NEXT_CURSOR);
    preimage.push_str(upstream_ref);
    preimage.push_str(family_source_ref);
    preimage.push_str(&upstream_overall_pass.to_string());
    preimage.push_str(upstream_next_cursor);
    preimage.push_str(&format!("{card:?}"));
    preimage.push_str(&format!("{metrics:?}"));
    sha256_hex(preimage.as_bytes())
}

fn validate_unique_exact_set(
    field: &'static str,
    values: &[String],
    required: &[&'static str],
) -> Result<(), ToolExecutionSurfaceError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(ToolExecutionSurfaceError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(ToolExecutionSurfaceError::MissingRequiredSet {
            field,
            actual: values.len(),
            expected: required.len(),
        });
    }
    Ok(())
}

fn validate_exact_enum_set<T>(
    field: &'static str,
    values: &[T],
    required: &[T],
) -> Result<(), ToolExecutionSurfaceError>
where
    T: Copy + Ord + fmt::Debug,
{
    let actual = values.iter().copied().collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected || values.len() != actual.len() {
        return Err(ToolExecutionSurfaceError::BadEnumSet {
            field,
            actual: values.len(),
            expected: required.len(),
        });
    }
    Ok(())
}

fn validate_focused_commands(values: &[String]) -> Result<(), ToolExecutionSurfaceError> {
    if values.len() < 5 || values.len() > 8 {
        return Err(ToolExecutionSurfaceError::BadListLength {
            field: "focused_commands",
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text("focused_commands", value)?;
        if !seen.insert(value.as_str()) {
            return Err(ToolExecutionSurfaceError::DuplicateValue {
                field: "focused_commands",
                value: value.to_string(),
            });
        }
        let swift_ok = value.starts_with("xcodebuild test -only-testing:EpistemosTests/")
            && (value.contains("Tool")
                || value.contains("RuntimeRouter")
                || value.contains("MASBoundary")
                || value.contains("UserFacingModelOutput"));
        let rust_ok = value.starts_with("cargo test --manifest-path agent_core/Cargo.toml ")
            && (value.contains("tool") || value.contains("source_guard"));
        if !(swift_ok || rust_ok) {
            return Err(ToolExecutionSurfaceError::BadFocusedCommand);
        }
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), ToolExecutionSurfaceError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/source_guard_drift_release_blocker_card/")
        || !value.contains("/result.json#F-SourceGuardDrift-ReleaseBlockerCard")
    {
        return Err(ToolExecutionSurfaceError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), ToolExecutionSurfaceError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#tool_execution_surface")
    {
        return Err(ToolExecutionSurfaceError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), ToolExecutionSurfaceError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(ToolExecutionSurfaceError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), ToolExecutionSurfaceError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(ToolExecutionSurfaceError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:tool-execution-surface-release-blocker-card:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ToolExecutionSurfaceError {
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
    BadEnumSet {
        field: &'static str,
        actual: usize,
        expected: usize,
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
    WrongFamily(String),
    ZeroIssueCount,
    CardHeaderBroken,
    PromotionBoundaryBroken,
    UpstreamNotPassed,
    WrongUpstreamCursor(String),
    WitnessHeaderBroken,
    WitnessDigestMismatch,
}

impl fmt::Display for ToolExecutionSurfaceError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl Error for ToolExecutionSurfaceError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn witness() -> ToolExecutionSurfaceReleaseBlockerWitness {
        ToolExecutionSurfaceReleaseBlockerWitness::new(
            TOOL_EXECUTION_SURFACE_UPSTREAM_REF,
            TOOL_EXECUTION_SURFACE_FAMILY_SOURCE_REF,
            true,
            TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_CURSOR,
            "tool_execution_surface",
            2,
        )
        .expect("valid tool execution surface witness")
    }

    #[test]
    fn valid_witness_is_metadata_only_and_stable() {
        let witness = witness();
        assert!(witness.validate().is_ok());
        assert_eq!(witness.card.tool_execution_bytes_opened, 0);
        assert_eq!(witness.card.tool_commands_executed, 0);
        assert_eq!(witness.card.model_runtime_bytes_loaded, 0);
        assert_eq!(witness.card.provider_calls_made, 0);
        assert!(witness.metadata_only);
        assert!(witness.no_product_promotion);
        assert_eq!(
            witness.metrics.source_ref_count,
            required_tool_execution_surface_source_refs().len()
        );
    }

    #[test]
    fn rejects_wrong_family_zero_issues_and_wrong_cursor() {
        assert!(ToolExecutionSurfaceReleaseBlockerWitness::new(
            TOOL_EXECUTION_SURFACE_UPSTREAM_REF,
            TOOL_EXECUTION_SURFACE_FAMILY_SOURCE_REF,
            true,
            TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_CURSOR,
            "source_guard_drift",
            2,
        )
        .is_err());
        assert!(ToolExecutionSurfaceReleaseBlockerWitness::new(
            TOOL_EXECUTION_SURFACE_UPSTREAM_REF,
            TOOL_EXECUTION_SURFACE_FAMILY_SOURCE_REF,
            true,
            TOOL_EXECUTION_SURFACE_RELEASE_BLOCKER_CARD_CURSOR,
            "tool_execution_surface",
            0,
        )
        .is_err());
        assert!(ToolExecutionSurfaceReleaseBlockerWitness::new(
            TOOL_EXECUTION_SURFACE_UPSTREAM_REF,
            TOOL_EXECUTION_SURFACE_FAMILY_SOURCE_REF,
            true,
            "source_guard_drift_release_blocker_card",
            "tool_execution_surface",
            2,
        )
        .is_err());
    }

    #[test]
    fn rejects_missing_sources_invariants_and_broad_commands() {
        let mut card = witness().card;
        card.source_refs
            .retain(|value| value != "Epistemos/LocalAgent/LocalToolGrammar.swift");
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.required_invariants
            .retain(|value| value != "tool_schema_digest_required");
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.focused_commands[0] = "xcodebuild test -only-testing:EpistemosTests".to_string();
        assert!(card.validate().is_err());
    }

    #[test]
    fn rejects_hidden_authority_and_false_promotion() {
        let mut card = witness().card;
        card.runtime_router_hidden_tool_authority_allowed = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.eidos_patternboost_lattice_tool_authority_allowed = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.product_green_claimed = true;
        assert!(card.validate().is_err());
    }

    #[test]
    fn rejects_tool_bytes_commands_and_provider_leaks() {
        let mut card = witness().card;
        card.tool_execution_bytes_opened = 1;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.tool_commands_executed = 1;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.model_runtime_bytes_loaded = 1;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.provider_calls_made = 1;
        assert!(card.validate().is_err());
    }
}
