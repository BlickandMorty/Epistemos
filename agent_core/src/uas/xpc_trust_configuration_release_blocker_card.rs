use crate::falsifier_artifacts::sha256_hex;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::error::Error;
use std::fmt;

pub const XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_ID: &str =
    "F-XpcTrustConfiguration-ReleaseBlockerCard";
pub const XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_CURSOR: &str =
    "xpc_trust_configuration_release_blocker_card";
pub const XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR: &str =
    "small_model_runtime_harness_fresh_product_runtime_l3_release_audit_automated_checks_probe";
pub const XPC_TRUST_CONFIGURATION_UPSTREAM_REF: &str = "artifact:falsifiers/tool_execution_surface_release_blocker_card/result.json#F-ToolExecutionSurface-ReleaseBlockerCard";
pub const XPC_TRUST_CONFIGURATION_FAMILY_SOURCE_REF: &str = "artifact:falsifiers/release_audit_failure_family_source_card/result.json#xpc_trust_configuration";

const REQUIRED_SOURCE_REFS: [&str; 12] = [
    "Epistemos/XPC/XPCTrust.swift",
    "Epistemos/XPC/AgentServiceProtocol.swift",
    "Epistemos/XPC/AgentServiceClient.swift",
    "Epistemos/XPC/ProviderServiceClient.swift",
    "XPCServices/AgentXPC/AgentService.swift",
    "XPCServices/ProviderXPC/ProviderService.swift",
    "XPCServices/AgentXPC/main.swift",
    "XPCServices/ProviderXPC/main.swift",
    "EpistemosTests/XPCSmokeTests.swift",
    "EpistemosTests/CapabilityBridgeTests.swift",
    "docs/fusion/XPC_RESEARCH_INTAKE_2026_05_04.md",
    "docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md",
];

const REQUIRED_INVARIANTS: [&str; 18] = [
    "upstream_tool_execution_surface_bound",
    "xpc_service_names_app_group_bound",
    "code_signing_requirement_before_resume_required",
    "anchor_apple_generic_required",
    "service_identifier_required",
    "team_ou_required",
    "development_team_drift_guard_required",
    "agent_client_trust_requirement_required",
    "provider_client_trust_requirement_required",
    "thin_service_delegate_required",
    "capability_bridge_subject_split_required",
    "no_process_identifier_trust",
    "no_unwhitelisted_payload_claim",
    "no_cloud_or_tool_execution_promotion",
    "no_hidden_provider_or_xpc_fallback",
    "no_product_green_from_xpc_trust",
    "zero_xpc_tool_model_provider_bytes",
    "rollback_run_event_answer_packet_required",
];

// UAS: uas:xpc-trust-configuration-release-blocker-card:organ
// Plane: Controller + Verification.
// Residency: metadata-only XPC trust source-card organ.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum XpcTrustConfigurationOrgan {
    XpcTrust,
    MasProBoundary,
    SovereignGate,
    RuntimeRouter,
    AnswerPacket,
}

// UAS: uas:xpc-trust-configuration-release-blocker-card:status
// Plane: Verification.
// Residency: retained release blocker classification only.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum XpcTrustConfigurationStatus {
    RedReleaseBlocker,
}

// UAS: uas:xpc-trust-configuration-release-blocker-card:surface
// Plane: State + Controller + Verification.
// Residency: XPC trust taxonomy; no service/model/runtime bytes opened.
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum XpcTrustSurface {
    XpcTrustRequirement,
    AgentServiceClient,
    ProviderServiceClient,
    AgentServiceProtocol,
    AgentXpcService,
    ProviderXpcService,
    XpcSmokeTests,
    CapabilityBridgeTests,
    XpcResearchCanon,
    XpcMasteryCanon,
}

// UAS: uas:xpc-trust-configuration-release-blocker-card:card
// Plane: Controller + Verification.
// Residency: metadata-only XPC trust blocker card.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct XpcTrustConfigurationReleaseBlockerCard {
    pub family_id: String,
    pub issue_count: u64,
    pub organ: XpcTrustConfigurationOrgan,
    pub status: XpcTrustConfigurationStatus,
    pub source_refs: Vec<String>,
    pub focused_commands: Vec<String>,
    pub required_invariants: Vec<String>,
    pub surfaces: Vec<XpcTrustSurface>,
    pub upstream_tool_execution_surface_required: bool,
    pub app_group_service_names_required: bool,
    pub code_signing_requirement_before_resume_required: bool,
    pub anchor_apple_generic_required: bool,
    pub service_identifier_required: bool,
    pub team_ou_required: bool,
    pub development_team_drift_guard_required: bool,
    pub agent_client_trust_requirement_required: bool,
    pub provider_client_trust_requirement_required: bool,
    pub thin_service_delegate_required: bool,
    pub capability_bridge_subject_split_required: bool,
    pub process_identifier_trust_allowed: bool,
    pub unwhitelisted_payload_claimed: bool,
    pub cloud_or_tool_execution_promoted: bool,
    pub hidden_provider_or_xpc_fallback_allowed: bool,
    pub l2_green_claimed: bool,
    pub l3_green_claimed: bool,
    pub product_green_claimed: bool,
    pub live_dense_70b_claimed: bool,
    pub ssd_as_ram_claimed: bool,
    pub xpc_connections_opened: u64,
    pub xpc_services_launched: u64,
    pub tool_commands_executed: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
    pub rollback_ref: String,
    pub run_event_log_ref: String,
    pub answer_packet_ref: String,
}

impl XpcTrustConfigurationReleaseBlockerCard {
    pub fn from_family(
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, XpcTrustConfigurationError> {
        validate_token("family_id", family_id)?;
        if family_id != "xpc_trust_configuration" {
            return Err(XpcTrustConfigurationError::WrongFamily(
                family_id.to_string(),
            ));
        }
        if issue_count == 0 {
            return Err(XpcTrustConfigurationError::ZeroIssueCount);
        }
        Ok(Self {
            family_id: family_id.to_string(),
            issue_count,
            organ: XpcTrustConfigurationOrgan::XpcTrust,
            status: XpcTrustConfigurationStatus::RedReleaseBlocker,
            source_refs: REQUIRED_SOURCE_REFS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            focused_commands: vec![
                "xcodebuild test -only-testing:EpistemosTests/XPCSmokeTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/CapabilityBridgeTests".to_string(),
                "xcodebuild test -only-testing:EpistemosTests/CoreMASBoundarySourceGuardTests"
                    .to_string(),
                "xcodebuild test -only-testing:EpistemosTests/UserFacingModelOutputTests"
                    .to_string(),
                "cargo test --manifest-path agent_core/Cargo.toml --bin falsify_tool_execution_surface_release_blocker_card"
                    .to_string(),
            ],
            required_invariants: REQUIRED_INVARIANTS
                .iter()
                .map(|value| value.to_string())
                .collect(),
            surfaces: vec![
                XpcTrustSurface::XpcTrustRequirement,
                XpcTrustSurface::AgentServiceClient,
                XpcTrustSurface::ProviderServiceClient,
                XpcTrustSurface::AgentServiceProtocol,
                XpcTrustSurface::AgentXpcService,
                XpcTrustSurface::ProviderXpcService,
                XpcTrustSurface::XpcSmokeTests,
                XpcTrustSurface::CapabilityBridgeTests,
                XpcTrustSurface::XpcResearchCanon,
                XpcTrustSurface::XpcMasteryCanon,
            ],
            upstream_tool_execution_surface_required: true,
            app_group_service_names_required: true,
            code_signing_requirement_before_resume_required: true,
            anchor_apple_generic_required: true,
            service_identifier_required: true,
            team_ou_required: true,
            development_team_drift_guard_required: true,
            agent_client_trust_requirement_required: true,
            provider_client_trust_requirement_required: true,
            thin_service_delegate_required: true,
            capability_bridge_subject_split_required: true,
            process_identifier_trust_allowed: false,
            unwhitelisted_payload_claimed: false,
            cloud_or_tool_execution_promoted: false,
            hidden_provider_or_xpc_fallback_allowed: false,
            l2_green_claimed: false,
            l3_green_claimed: false,
            product_green_claimed: false,
            live_dense_70b_claimed: false,
            ssd_as_ram_claimed: false,
            xpc_connections_opened: 0,
            xpc_services_launched: 0,
            tool_commands_executed: 0,
            model_runtime_bytes_loaded: 0,
            provider_calls_made: 0,
            rollback_ref: "rollback:xpc_trust_configuration_release_blocker_card".to_string(),
            run_event_log_ref: "run_event_log:xpc_trust_configuration_release_blocker_card"
                .to_string(),
            answer_packet_ref: "answer_packet:xpc_trust_configuration_release_blocker_card"
                .to_string(),
        })
    }

    pub fn validate(&self) -> Result<(), XpcTrustConfigurationError> {
        validate_token("family_id", &self.family_id)?;
        if self.family_id != "xpc_trust_configuration"
            || self.issue_count == 0
            || self.organ != XpcTrustConfigurationOrgan::XpcTrust
            || self.status != XpcTrustConfigurationStatus::RedReleaseBlocker
        {
            return Err(XpcTrustConfigurationError::CardHeaderBroken);
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
                XpcTrustSurface::XpcTrustRequirement,
                XpcTrustSurface::AgentServiceClient,
                XpcTrustSurface::ProviderServiceClient,
                XpcTrustSurface::AgentServiceProtocol,
                XpcTrustSurface::AgentXpcService,
                XpcTrustSurface::ProviderXpcService,
                XpcTrustSurface::XpcSmokeTests,
                XpcTrustSurface::CapabilityBridgeTests,
                XpcTrustSurface::XpcResearchCanon,
                XpcTrustSurface::XpcMasteryCanon,
            ],
        )?;
        for value in [
            &self.rollback_ref,
            &self.run_event_log_ref,
            &self.answer_packet_ref,
        ] {
            validate_token("proof_ref", value)?;
        }
        if !self.upstream_tool_execution_surface_required
            || !self.app_group_service_names_required
            || !self.code_signing_requirement_before_resume_required
            || !self.anchor_apple_generic_required
            || !self.service_identifier_required
            || !self.team_ou_required
            || !self.development_team_drift_guard_required
            || !self.agent_client_trust_requirement_required
            || !self.provider_client_trust_requirement_required
            || !self.thin_service_delegate_required
            || !self.capability_bridge_subject_split_required
            || self.process_identifier_trust_allowed
            || self.unwhitelisted_payload_claimed
            || self.cloud_or_tool_execution_promoted
            || self.hidden_provider_or_xpc_fallback_allowed
            || self.l2_green_claimed
            || self.l3_green_claimed
            || self.product_green_claimed
            || self.live_dense_70b_claimed
            || self.ssd_as_ram_claimed
            || self.xpc_connections_opened != 0
            || self.xpc_services_launched != 0
            || self.tool_commands_executed != 0
            || self.model_runtime_bytes_loaded != 0
            || self.provider_calls_made != 0
        {
            return Err(XpcTrustConfigurationError::PromotionBoundaryBroken);
        }
        Ok(())
    }
}

// UAS: uas:xpc-trust-configuration-release-blocker-card:metrics
// Plane: Verification.
// Residency: aggregate XPC trust metadata only.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct XpcTrustConfigurationMetrics {
    pub issue_count: u64,
    pub source_ref_count: usize,
    pub focused_command_count: usize,
    pub invariant_count: usize,
    pub surface_count: usize,
    pub xpc_connections_opened: u64,
    pub xpc_services_launched: u64,
    pub tool_commands_executed: u64,
    pub model_runtime_bytes_loaded: u64,
    pub provider_calls_made: u64,
}

// UAS: uas:xpc-trust-configuration-release-blocker-card:witness
// Plane: Controller + Verification.
// Residency: metadata-only XPC trust source-card witness.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct XpcTrustConfigurationReleaseBlockerWitness {
    pub falsifier_id: String,
    pub cursor: String,
    pub next_cursor: String,
    pub upstream_ref: String,
    pub family_source_ref: String,
    pub upstream_overall_pass: bool,
    pub upstream_next_cursor: String,
    pub card: XpcTrustConfigurationReleaseBlockerCard,
    pub metrics: XpcTrustConfigurationMetrics,
    pub address: String,
    pub metadata_only: bool,
    pub no_product_promotion: bool,
}

impl XpcTrustConfigurationReleaseBlockerWitness {
    pub fn new(
        upstream_ref: &str,
        family_source_ref: &str,
        upstream_overall_pass: bool,
        upstream_next_cursor: &str,
        family_id: &str,
        issue_count: u64,
    ) -> Result<Self, XpcTrustConfigurationError> {
        validate_upstream_ref(upstream_ref)?;
        validate_family_source_ref(family_source_ref)?;
        validate_token("upstream_next_cursor", upstream_next_cursor)?;
        if !upstream_overall_pass {
            return Err(XpcTrustConfigurationError::UpstreamNotPassed);
        }
        if upstream_next_cursor != XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_CURSOR {
            return Err(XpcTrustConfigurationError::WrongUpstreamCursor(
                upstream_next_cursor.to_string(),
            ));
        }
        let card = XpcTrustConfigurationReleaseBlockerCard::from_family(family_id, issue_count)?;
        card.validate()?;
        let metrics = XpcTrustConfigurationMetrics {
            issue_count: card.issue_count,
            source_ref_count: card.source_refs.len(),
            focused_command_count: card.focused_commands.len(),
            invariant_count: card.required_invariants.len(),
            surface_count: card.surfaces.len(),
            xpc_connections_opened: card.xpc_connections_opened,
            xpc_services_launched: card.xpc_services_launched,
            tool_commands_executed: card.tool_commands_executed,
            model_runtime_bytes_loaded: card.model_runtime_bytes_loaded,
            provider_calls_made: card.provider_calls_made,
        };
        let address = xpc_trust_configuration_address(
            upstream_ref,
            family_source_ref,
            upstream_overall_pass,
            upstream_next_cursor,
            &card,
            &metrics,
        );
        Ok(Self {
            falsifier_id: XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_ID.to_string(),
            cursor: XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_CURSOR.to_string(),
            next_cursor: XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR.to_string(),
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

    pub fn validate(&self) -> Result<(), XpcTrustConfigurationError> {
        if self.falsifier_id != XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_ID
            || self.cursor != XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_CURSOR
            || self.next_cursor != XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR
            || !self.metadata_only
            || !self.no_product_promotion
        {
            return Err(XpcTrustConfigurationError::WitnessHeaderBroken);
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
            return Err(XpcTrustConfigurationError::WitnessDigestMismatch);
        }
        Ok(())
    }
}

pub fn required_xpc_trust_configuration_source_refs() -> &'static [&'static str] {
    &REQUIRED_SOURCE_REFS
}

pub fn required_xpc_trust_configuration_invariants() -> &'static [&'static str] {
    &REQUIRED_INVARIANTS
}

fn xpc_trust_configuration_address(
    upstream_ref: &str,
    family_source_ref: &str,
    upstream_overall_pass: bool,
    upstream_next_cursor: &str,
    card: &XpcTrustConfigurationReleaseBlockerCard,
    metrics: &XpcTrustConfigurationMetrics,
) -> String {
    let mut preimage = String::new();
    preimage.push_str(XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_ID);
    preimage.push_str(XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_CURSOR);
    preimage.push_str(XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR);
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
) -> Result<(), XpcTrustConfigurationError> {
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text(field, value)?;
        if !seen.insert(value.as_str()) {
            return Err(XpcTrustConfigurationError::DuplicateValue {
                field,
                value: value.to_string(),
            });
        }
    }
    let actual = values.iter().map(String::as_str).collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected {
        return Err(XpcTrustConfigurationError::MissingRequiredSet {
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
) -> Result<(), XpcTrustConfigurationError>
where
    T: Copy + Ord + fmt::Debug,
{
    let actual = values.iter().copied().collect::<BTreeSet<_>>();
    let expected = required.iter().copied().collect::<BTreeSet<_>>();
    if actual != expected || values.len() != actual.len() {
        return Err(XpcTrustConfigurationError::BadEnumSet {
            field,
            actual: values.len(),
            expected: required.len(),
        });
    }
    Ok(())
}

fn validate_focused_commands(values: &[String]) -> Result<(), XpcTrustConfigurationError> {
    if values.len() < 4 || values.len() > 7 {
        return Err(XpcTrustConfigurationError::BadListLength {
            field: "focused_commands",
            actual: values.len(),
        });
    }
    let mut seen = BTreeSet::new();
    for value in values {
        validate_text("focused_commands", value)?;
        if !seen.insert(value.as_str()) {
            return Err(XpcTrustConfigurationError::DuplicateValue {
                field: "focused_commands",
                value: value.to_string(),
            });
        }
        let swift_ok = value.starts_with("xcodebuild test -only-testing:EpistemosTests/")
            && (value.contains("XPC")
                || value.contains("CapabilityBridge")
                || value.contains("MASBoundary")
                || value.contains("UserFacingModelOutput"));
        let rust_ok = value.starts_with("cargo test --manifest-path agent_core/Cargo.toml ")
            && value.contains("tool_execution_surface_release_blocker_card");
        if !(swift_ok || rust_ok) {
            return Err(XpcTrustConfigurationError::BadFocusedCommand);
        }
    }
    Ok(())
}

fn validate_upstream_ref(value: &str) -> Result<(), XpcTrustConfigurationError> {
    validate_token("upstream_ref", value)?;
    if !value.starts_with("artifact:falsifiers/tool_execution_surface_release_blocker_card/")
        || !value.contains("/result.json#F-ToolExecutionSurface-ReleaseBlockerCard")
    {
        return Err(XpcTrustConfigurationError::BadUpstreamRef);
    }
    Ok(())
}

fn validate_family_source_ref(value: &str) -> Result<(), XpcTrustConfigurationError> {
    validate_token("family_source_ref", value)?;
    if !value.starts_with("artifact:falsifiers/release_audit_failure_family_source_card/")
        || !value.contains("/result.json#xpc_trust_configuration")
    {
        return Err(XpcTrustConfigurationError::BadFamilySourceRef);
    }
    Ok(())
}

fn validate_token(field: &'static str, value: &str) -> Result<(), XpcTrustConfigurationError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() || c.is_whitespace())
    {
        return Err(XpcTrustConfigurationError::InvalidToken {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

fn validate_text(field: &'static str, value: &str) -> Result<(), XpcTrustConfigurationError> {
    if value.trim().is_empty()
        || value.len() > 512
        || value.chars().any(|c| c.is_control() && c != '\n')
    {
        return Err(XpcTrustConfigurationError::InvalidText {
            field,
            value: value.to_string(),
        });
    }
    Ok(())
}

// UAS: uas:xpc-trust-configuration-release-blocker-card:error
// Plane: Verification.
// Residency: fail-closed metadata validation errors.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum XpcTrustConfigurationError {
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

impl fmt::Display for XpcTrustConfigurationError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{self:?}")
    }
}

impl Error for XpcTrustConfigurationError {}

#[cfg(test)]
mod tests {
    use super::*;

    fn witness() -> XpcTrustConfigurationReleaseBlockerWitness {
        XpcTrustConfigurationReleaseBlockerWitness::new(
            XPC_TRUST_CONFIGURATION_UPSTREAM_REF,
            XPC_TRUST_CONFIGURATION_FAMILY_SOURCE_REF,
            true,
            XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_CURSOR,
            "xpc_trust_configuration",
            1,
        )
        .expect("valid xpc trust configuration witness")
    }

    #[test]
    fn valid_witness_is_metadata_only_and_stable() {
        let witness = witness();
        witness.validate().expect("valid witness");
        assert!(witness.metadata_only);
        assert!(witness.no_product_promotion);
        assert_eq!(witness.metrics.source_ref_count, REQUIRED_SOURCE_REFS.len());
        assert_eq!(witness.metrics.invariant_count, REQUIRED_INVARIANTS.len());
        assert_eq!(witness.metrics.xpc_connections_opened, 0);
        assert_eq!(witness.metrics.xpc_services_launched, 0);
        assert_eq!(witness.metrics.model_runtime_bytes_loaded, 0);
        assert_eq!(
            witness.next_cursor,
            XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_NEXT_CURSOR
        );
    }

    #[test]
    fn rejects_wrong_cursor_and_family() {
        assert!(XpcTrustConfigurationReleaseBlockerWitness::new(
            XPC_TRUST_CONFIGURATION_UPSTREAM_REF,
            XPC_TRUST_CONFIGURATION_FAMILY_SOURCE_REF,
            true,
            "tool_execution_surface_release_blocker_card",
            "xpc_trust_configuration",
            1,
        )
        .is_err());
        assert!(XpcTrustConfigurationReleaseBlockerWitness::new(
            XPC_TRUST_CONFIGURATION_UPSTREAM_REF,
            XPC_TRUST_CONFIGURATION_FAMILY_SOURCE_REF,
            true,
            XPC_TRUST_CONFIGURATION_RELEASE_BLOCKER_CARD_CURSOR,
            "tool_execution_surface",
            1,
        )
        .is_err());
    }

    #[test]
    fn rejects_authority_promotion_and_runtime_bytes() {
        let mut card = witness().card;
        card.process_identifier_trust_allowed = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.hidden_provider_or_xpc_fallback_allowed = true;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.xpc_connections_opened = 1;
        assert!(card.validate().is_err());

        let mut card = witness().card;
        card.product_green_claimed = true;
        assert!(card.validate().is_err());
    }
}
