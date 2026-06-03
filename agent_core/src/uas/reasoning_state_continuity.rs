//! Reasoning-state continuity cards for constructive residency.
//!
//! This is a metadata-only continuity witness. It models resumable state as a
//! visible, privacy-scoped cache/summary contract that can improve continuity
//! and cache utility without exposing hidden reasoning or bypassing verification.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

use crate::uas::{UasAddress, UasKind};

const CARD_UAS_KIND: &str = "reasoning_state_continuity";
const CACHE_PREFIX: &str = "cache:";
const FENCE_PREFIX: &str = "compatibility_fence:";
const VERIFIER_PREFIX: &str = "verifier:";
const PURGE_PREFIX: &str = "purge:";
const RESUME_LEASE_PREFIX: &str = "compute_resume_lease:";
const FALLBACK_PREFIX: &str = "fallback:";
const ROLLBACK_PREFIX: &str = "rollback:";
const ANSWER_PACKET_PREFIX: &str = "answer_packet:";
const BASELINE_NAMES: [&str; 3] = ["no_state", "naive_cache", "static_summary"];

// UAS: uas/research-construction/reasoning-state-kind
// Plane: RuntimePlane::State
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PreservedStateKind {
    KvSummary,
    PromptCache,
    ReasoningSummary,
    ToolState,
}

impl PreservedStateKind {
    pub fn wire_tag(self) -> &'static str {
        match self {
            Self::KvSummary => "kv_summary",
            Self::PromptCache => "prompt_cache",
            Self::ReasoningSummary => "reasoning_summary",
            Self::ToolState => "tool_state",
        }
    }
}

// UAS: uas/research-construction/state-privacy-class
// Plane: RuntimePlane::State
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum StatePrivacyClass {
    Public,
    VaultPrivate,
    LocalSecret,
}

impl StatePrivacyClass {
    pub fn wire_tag(self) -> &'static str {
        match self {
            Self::Public => "public",
            Self::VaultPrivate => "vault_private",
            Self::LocalSecret => "local_secret",
        }
    }
}

// UAS: uas/research-construction/reasoning-state-baseline
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReasoningStateBaseline {
    pub name: String,
    pub continuity_bps: u16,
    pub cache_utility_bps: u16,
    pub verifier_bps: u16,
    pub latency_ms: u64,
    pub active_executed_bytes: u64,
    pub hidden_chain_exposed: bool,
    pub verifier_bypass: bool,
    pub stale_state_reused: bool,
}

impl ReasoningStateBaseline {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        name: impl Into<String>,
        continuity_bps: u16,
        cache_utility_bps: u16,
        verifier_bps: u16,
        latency_ms: u64,
        active_executed_bytes: u64,
        hidden_chain_exposed: bool,
        verifier_bypass: bool,
        stale_state_reused: bool,
    ) -> Result<Self, ReasoningStateContinuityError> {
        let name = name.into();
        validate_field("baseline_name", &name)?;
        validate_score("continuity_bps", continuity_bps)?;
        validate_score("cache_utility_bps", cache_utility_bps)?;
        validate_score("verifier_bps", verifier_bps)?;
        Ok(Self {
            name,
            continuity_bps,
            cache_utility_bps,
            verifier_bps,
            latency_ms,
            active_executed_bytes,
            hidden_chain_exposed,
            verifier_bypass,
            stale_state_reused,
        })
    }

    pub fn score_bps(&self) -> u16 {
        ((u32::from(self.continuity_bps)
            + u32::from(self.cache_utility_bps)
            + u32::from(self.verifier_bps))
            / 3) as u16
    }
}

// UAS: uas/research-construction/reasoning-state-continuity-card
// Plane: RuntimePlane::State
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ReasoningStateContinuityCard {
    pub card_address: UasAddress,
    pub session_id: String,
    pub model_id: String,
    pub source_card_ids: Vec<String>,
    pub task_signature: String,
    pub preserved_state_kind: PreservedStateKind,
    pub privacy_class: StatePrivacyClass,
    pub visible_summary: String,
    pub cache_key: String,
    pub restore_policy: String,
    pub compatibility_fence_ref: String,
    pub verifier_caveat: String,
    pub purge_policy: String,
    pub compute_resume_lease_ref: String,
    pub continuity_bps: u16,
    pub cache_utility_bps: u16,
    pub verifier_bps: u16,
    pub latency_ms: u64,
    pub active_executed_bytes: u64,
    pub stale_state_risk_bps: u16,
    pub privacy_risk_bps: u16,
    pub storage_wear_bps: u16,
    pub fallback_route: String,
    pub rollback_ref: String,
    pub answer_packet_ref: String,
    pub hidden_chain_exposed: bool,
    pub verifier_bypass: bool,
    pub stale_state_reused: bool,
    pub baselines: Vec<ReasoningStateBaseline>,
}

impl ReasoningStateContinuityCard {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        session_id: impl Into<String>,
        model_id: impl Into<String>,
        source_card_ids: Vec<String>,
        task_signature: impl Into<String>,
        preserved_state_kind: PreservedStateKind,
        privacy_class: StatePrivacyClass,
        visible_summary: impl Into<String>,
        cache_key: impl Into<String>,
        restore_policy: impl Into<String>,
        compatibility_fence_ref: impl Into<String>,
        verifier_caveat: impl Into<String>,
        purge_policy: impl Into<String>,
        compute_resume_lease_ref: impl Into<String>,
        continuity_bps: u16,
        cache_utility_bps: u16,
        verifier_bps: u16,
        latency_ms: u64,
        active_executed_bytes: u64,
        stale_state_risk_bps: u16,
        privacy_risk_bps: u16,
        storage_wear_bps: u16,
        fallback_route: impl Into<String>,
        rollback_ref: impl Into<String>,
        answer_packet_ref: impl Into<String>,
        hidden_chain_exposed: bool,
        verifier_bypass: bool,
        stale_state_reused: bool,
        baselines: Vec<ReasoningStateBaseline>,
        created_at_ms: u64,
    ) -> Result<Self, ReasoningStateContinuityError> {
        let session_id = session_id.into();
        let model_id = model_id.into();
        let task_signature = task_signature.into();
        let visible_summary = visible_summary.into();
        let cache_key = cache_key.into();
        let restore_policy = restore_policy.into();
        let compatibility_fence_ref = compatibility_fence_ref.into();
        let verifier_caveat = verifier_caveat.into();
        let purge_policy = purge_policy.into();
        let compute_resume_lease_ref = compute_resume_lease_ref.into();
        let fallback_route = fallback_route.into();
        let rollback_ref = rollback_ref.into();
        let answer_packet_ref = answer_packet_ref.into();

        validate_field("session_id", &session_id)?;
        validate_field("model_id", &model_id)?;
        validate_field("task_signature", &task_signature)?;
        validate_field("visible_summary", &visible_summary)?;
        validate_field("cache_key", &cache_key)?;
        validate_field("restore_policy", &restore_policy)?;
        validate_field("compatibility_fence_ref", &compatibility_fence_ref)?;
        validate_field("verifier_caveat", &verifier_caveat)?;
        validate_field("purge_policy", &purge_policy)?;
        validate_field("compute_resume_lease_ref", &compute_resume_lease_ref)?;
        validate_field("fallback_route", &fallback_route)?;
        validate_field("rollback_ref", &rollback_ref)?;
        validate_field("answer_packet_ref", &answer_packet_ref)?;
        validate_prefix(
            &cache_key,
            CACHE_PREFIX,
            ReasoningStateContinuityError::MissingCacheKey,
        )?;
        validate_prefix(
            &compatibility_fence_ref,
            FENCE_PREFIX,
            ReasoningStateContinuityError::MissingCompatibilityFence,
        )?;
        validate_prefix(
            &verifier_caveat,
            VERIFIER_PREFIX,
            ReasoningStateContinuityError::MissingVerifierCaveat,
        )?;
        validate_prefix(
            &purge_policy,
            PURGE_PREFIX,
            ReasoningStateContinuityError::MissingPurgePolicy,
        )?;
        validate_prefix(
            &compute_resume_lease_ref,
            RESUME_LEASE_PREFIX,
            ReasoningStateContinuityError::MissingComputeResumeLease,
        )?;
        validate_prefix(
            &fallback_route,
            FALLBACK_PREFIX,
            ReasoningStateContinuityError::InvalidFallbackRoute,
        )?;
        validate_prefix(
            &rollback_ref,
            ROLLBACK_PREFIX,
            ReasoningStateContinuityError::MissingRollback,
        )?;
        validate_prefix(
            &answer_packet_ref,
            ANSWER_PACKET_PREFIX,
            ReasoningStateContinuityError::MissingAnswerPacketRef,
        )?;
        if hidden_chain_exposed {
            return Err(ReasoningStateContinuityError::HiddenChainExposed);
        }
        if verifier_bypass {
            return Err(ReasoningStateContinuityError::VerifierBypass);
        }
        if stale_state_reused {
            return Err(ReasoningStateContinuityError::StaleStateReused);
        }
        validate_score("continuity_bps", continuity_bps)?;
        validate_score("cache_utility_bps", cache_utility_bps)?;
        validate_score("verifier_bps", verifier_bps)?;
        validate_score("stale_state_risk_bps", stale_state_risk_bps)?;
        validate_score("privacy_risk_bps", privacy_risk_bps)?;
        validate_score("storage_wear_bps", storage_wear_bps)?;

        let source_card_ids = canonicalize_source_cards(source_card_ids)?;
        let baselines = canonicalize_baselines(baselines)?;
        let card_address = card_address(
            &session_id,
            &model_id,
            &source_card_ids,
            &task_signature,
            preserved_state_kind,
            privacy_class,
            &visible_summary,
            &cache_key,
            &restore_policy,
            &compatibility_fence_ref,
            &verifier_caveat,
            &purge_policy,
            &compute_resume_lease_ref,
            continuity_bps,
            cache_utility_bps,
            verifier_bps,
            latency_ms,
            active_executed_bytes,
            stale_state_risk_bps,
            privacy_risk_bps,
            storage_wear_bps,
            &fallback_route,
            &rollback_ref,
            &answer_packet_ref,
            &baselines,
            created_at_ms,
        );
        let card = Self {
            card_address,
            session_id,
            model_id,
            source_card_ids,
            task_signature,
            preserved_state_kind,
            privacy_class,
            visible_summary,
            cache_key,
            restore_policy,
            compatibility_fence_ref,
            verifier_caveat,
            purge_policy,
            compute_resume_lease_ref,
            continuity_bps,
            cache_utility_bps,
            verifier_bps,
            latency_ms,
            active_executed_bytes,
            stale_state_risk_bps,
            privacy_risk_bps,
            storage_wear_bps,
            fallback_route,
            rollback_ref,
            answer_packet_ref,
            hidden_chain_exposed,
            verifier_bypass,
            stale_state_reused,
            baselines,
        };
        if !card.beats_all_baselines() {
            return Err(ReasoningStateContinuityError::BaselineNotBeaten);
        }
        Ok(card)
    }

    pub fn score_bps(&self) -> u16 {
        ((u32::from(self.continuity_bps)
            + u32::from(self.cache_utility_bps)
            + u32::from(self.verifier_bps))
            / 3) as u16
    }

    pub fn baseline(&self, name: &str) -> Option<&ReasoningStateBaseline> {
        self.baselines.iter().find(|baseline| baseline.name == name)
    }

    pub fn beats_all_baselines(&self) -> bool {
        self.baselines.iter().all(|baseline| {
            self.score_bps() > baseline.score_bps()
                && self.continuity_bps > baseline.continuity_bps
                && self.cache_utility_bps > baseline.cache_utility_bps
                && self.verifier_bps > baseline.verifier_bps
                && self.latency_ms < baseline.latency_ms
                && self.active_executed_bytes < baseline.active_executed_bytes
                && !baseline.hidden_chain_exposed
                && !baseline.verifier_bypass
                && !baseline.stale_state_reused
        })
    }
}

// UAS: uas/research-construction/reasoning-state-continuity-error
// Plane: RuntimePlane::Verification
// Residency: ResidencyTier::CapabilityCeiling
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ReasoningStateContinuityError {
    MissingSessionId,
    MissingModelId,
    MissingSourceCards,
    MissingTaskSignature,
    MissingVisibleSummary,
    MissingCacheKey,
    MissingRestorePolicy,
    MissingCompatibilityFence,
    MissingVerifierCaveat,
    MissingPurgePolicy,
    MissingComputeResumeLease,
    MissingFallbackRoute,
    InvalidFallbackRoute,
    MissingRollback,
    MissingAnswerPacketRef,
    MissingBaselineSet,
    InvalidBaselineSet,
    DuplicateSourceCard { source_card_id: String },
    DuplicateBaseline { name: String },
    HiddenChainExposed,
    VerifierBypass,
    StaleStateReused,
    BaselineNotBeaten,
    ScoreOutOfRange { field: &'static str },
    FieldHasSurroundingWhitespace { field: &'static str },
    FieldContainsControlCharacter { field: &'static str },
}

impl std::fmt::Display for ReasoningStateContinuityError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::MissingSessionId => write!(f, "missing session id"),
            Self::MissingModelId => write!(f, "missing model id"),
            Self::MissingSourceCards => write!(f, "missing source cards"),
            Self::MissingTaskSignature => write!(f, "missing task signature"),
            Self::MissingVisibleSummary => write!(f, "missing visible summary"),
            Self::MissingCacheKey => write!(f, "missing cache key"),
            Self::MissingRestorePolicy => write!(f, "missing restore policy"),
            Self::MissingCompatibilityFence => write!(f, "missing compatibility fence"),
            Self::MissingVerifierCaveat => write!(f, "missing verifier caveat"),
            Self::MissingPurgePolicy => write!(f, "missing purge policy"),
            Self::MissingComputeResumeLease => write!(f, "missing compute resume lease"),
            Self::MissingFallbackRoute => write!(f, "missing fallback route"),
            Self::InvalidFallbackRoute => write!(f, "fallback route must start with fallback:"),
            Self::MissingRollback => write!(f, "missing rollback"),
            Self::MissingAnswerPacketRef => write!(f, "missing AnswerPacket ref"),
            Self::MissingBaselineSet => write!(f, "missing baseline set"),
            Self::InvalidBaselineSet => write!(
                f,
                "baseline set must include no_state, naive_cache, and static_summary"
            ),
            Self::DuplicateSourceCard { source_card_id } => {
                write!(f, "duplicate source card {source_card_id}")
            }
            Self::DuplicateBaseline { name } => write!(f, "duplicate baseline {name}"),
            Self::HiddenChainExposed => write!(f, "hidden chain exposed"),
            Self::VerifierBypass => write!(f, "verifier bypass"),
            Self::StaleStateReused => write!(f, "stale state reused"),
            Self::BaselineNotBeaten => write!(f, "baseline not beaten"),
            Self::ScoreOutOfRange { field } => write!(f, "score out of range: {field}"),
            Self::FieldHasSurroundingWhitespace { field } => {
                write!(f, "field has surrounding whitespace: {field}")
            }
            Self::FieldContainsControlCharacter { field } => {
                write!(f, "field contains control character: {field}")
            }
        }
    }
}

impl std::error::Error for ReasoningStateContinuityError {}

#[allow(clippy::too_many_arguments)]
fn card_address(
    session_id: &str,
    model_id: &str,
    source_card_ids: &[String],
    task_signature: &str,
    preserved_state_kind: PreservedStateKind,
    privacy_class: StatePrivacyClass,
    visible_summary: &str,
    cache_key: &str,
    restore_policy: &str,
    compatibility_fence_ref: &str,
    verifier_caveat: &str,
    purge_policy: &str,
    compute_resume_lease_ref: &str,
    continuity_bps: u16,
    cache_utility_bps: u16,
    verifier_bps: u16,
    latency_ms: u64,
    active_executed_bytes: u64,
    stale_state_risk_bps: u16,
    privacy_risk_bps: u16,
    storage_wear_bps: u16,
    fallback_route: &str,
    rollback_ref: &str,
    answer_packet_ref: &str,
    baselines: &[ReasoningStateBaseline],
    created_at_ms: u64,
) -> UasAddress {
    let mut preimage = String::new();
    preimage.push_str("reasoning_state_continuity_v1\n");
    preimage.push_str(session_id);
    preimage.push('\n');
    preimage.push_str(model_id);
    preimage.push('\n');
    preimage.push_str(task_signature);
    preimage.push('\n');
    preimage.push_str(preserved_state_kind.wire_tag());
    preimage.push('\n');
    preimage.push_str(privacy_class.wire_tag());
    preimage.push('\n');
    for source_card_id in source_card_ids {
        preimage.push_str(source_card_id);
        preimage.push('\n');
    }
    preimage.push_str(visible_summary);
    preimage.push('\n');
    preimage.push_str(cache_key);
    preimage.push('\n');
    preimage.push_str(restore_policy);
    preimage.push('\n');
    preimage.push_str(compatibility_fence_ref);
    preimage.push('\n');
    preimage.push_str(verifier_caveat);
    preimage.push('\n');
    preimage.push_str(purge_policy);
    preimage.push('\n');
    preimage.push_str(compute_resume_lease_ref);
    preimage.push('\n');
    preimage.push_str(&format!(
        "{continuity_bps}|{cache_utility_bps}|{verifier_bps}|{latency_ms}|{active_executed_bytes}|{stale_state_risk_bps}|{privacy_risk_bps}|{storage_wear_bps}\n"
    ));
    preimage.push_str(fallback_route);
    preimage.push('\n');
    preimage.push_str(rollback_ref);
    preimage.push('\n');
    preimage.push_str(answer_packet_ref);
    preimage.push('\n');
    for baseline in baselines {
        preimage.push_str(&format!(
            "{}|{}|{}|{}|{}|{}|{}|{}|{}\n",
            baseline.name,
            baseline.continuity_bps,
            baseline.cache_utility_bps,
            baseline.verifier_bps,
            baseline.latency_ms,
            baseline.active_executed_bytes,
            baseline.hidden_chain_exposed,
            baseline.verifier_bypass,
            baseline.stale_state_reused
        ));
    }
    UasAddress::new(
        UasKind::Other(CARD_UAS_KIND.to_string()),
        preimage.as_bytes(),
        created_at_ms,
    )
}

fn validate_field(field: &'static str, value: &str) -> Result<(), ReasoningStateContinuityError> {
    if value.is_empty() {
        return match field {
            "session_id" => Err(ReasoningStateContinuityError::MissingSessionId),
            "model_id" => Err(ReasoningStateContinuityError::MissingModelId),
            "task_signature" => Err(ReasoningStateContinuityError::MissingTaskSignature),
            "visible_summary" => Err(ReasoningStateContinuityError::MissingVisibleSummary),
            "cache_key" => Err(ReasoningStateContinuityError::MissingCacheKey),
            "restore_policy" => Err(ReasoningStateContinuityError::MissingRestorePolicy),
            "compatibility_fence_ref" => {
                Err(ReasoningStateContinuityError::MissingCompatibilityFence)
            }
            "verifier_caveat" => Err(ReasoningStateContinuityError::MissingVerifierCaveat),
            "purge_policy" => Err(ReasoningStateContinuityError::MissingPurgePolicy),
            "compute_resume_lease_ref" => {
                Err(ReasoningStateContinuityError::MissingComputeResumeLease)
            }
            "fallback_route" => Err(ReasoningStateContinuityError::MissingFallbackRoute),
            "rollback_ref" => Err(ReasoningStateContinuityError::MissingRollback),
            "answer_packet_ref" => Err(ReasoningStateContinuityError::MissingAnswerPacketRef),
            _ => Err(ReasoningStateContinuityError::FieldContainsControlCharacter { field }),
        };
    }
    if value != value.trim() {
        return Err(ReasoningStateContinuityError::FieldHasSurroundingWhitespace { field });
    }
    if value.chars().any(char::is_control) {
        return Err(ReasoningStateContinuityError::FieldContainsControlCharacter { field });
    }
    Ok(())
}

fn validate_prefix(
    value: &str,
    prefix: &str,
    error: ReasoningStateContinuityError,
) -> Result<(), ReasoningStateContinuityError> {
    if value.starts_with(prefix) {
        Ok(())
    } else {
        Err(error)
    }
}

fn validate_score(field: &'static str, value: u16) -> Result<(), ReasoningStateContinuityError> {
    if value <= 10_000 {
        Ok(())
    } else {
        Err(ReasoningStateContinuityError::ScoreOutOfRange { field })
    }
}

fn canonicalize_source_cards(
    source_card_ids: Vec<String>,
) -> Result<Vec<String>, ReasoningStateContinuityError> {
    if source_card_ids.is_empty() {
        return Err(ReasoningStateContinuityError::MissingSourceCards);
    }
    let mut seen = BTreeSet::new();
    let mut out = Vec::with_capacity(source_card_ids.len());
    for source_card_id in source_card_ids {
        validate_field("source_card_id", &source_card_id)?;
        if !seen.insert(source_card_id.clone()) {
            return Err(ReasoningStateContinuityError::DuplicateSourceCard { source_card_id });
        }
        out.push(source_card_id);
    }
    out.sort();
    Ok(out)
}

fn canonicalize_baselines(
    baselines: Vec<ReasoningStateBaseline>,
) -> Result<Vec<ReasoningStateBaseline>, ReasoningStateContinuityError> {
    if baselines.is_empty() {
        return Err(ReasoningStateContinuityError::MissingBaselineSet);
    }
    let mut out = baselines;
    out.sort_by(|a, b| a.name.cmp(&b.name));
    let mut seen = BTreeSet::new();
    for baseline in &out {
        if !seen.insert(baseline.name.clone()) {
            return Err(ReasoningStateContinuityError::DuplicateBaseline {
                name: baseline.name.clone(),
            });
        }
    }
    if !BASELINE_NAMES.iter().all(|name| seen.contains(*name)) {
        return Err(ReasoningStateContinuityError::InvalidBaselineSet);
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    const CREATED_AT_MS: u64 = 1_779_400_100_000;

    fn baselines() -> Vec<ReasoningStateBaseline> {
        vec![
            ReasoningStateBaseline::new(
                "no_state", 5900, 3600, 6500, 980, 65_536, false, false, false,
            )
            .unwrap(),
            ReasoningStateBaseline::new(
                "naive_cache",
                6500,
                6900,
                6600,
                720,
                49_152,
                false,
                false,
                false,
            )
            .unwrap(),
            ReasoningStateBaseline::new(
                "static_summary",
                7000,
                6100,
                7100,
                760,
                57_344,
                false,
                false,
                false,
            )
            .unwrap(),
        ]
    }

    fn accepted_card() -> ReasoningStateContinuityCard {
        ReasoningStateContinuityCard::new(
            "session:adversarial-note-route",
            "model:local-mlx-controller",
            vec![
                "source:cache-lineage".to_string(),
                "source:constructive-residency".to_string(),
            ],
            "task:resume-cold-assembly-verification",
            PreservedStateKind::ReasoningSummary,
            StatePrivacyClass::VaultPrivate,
            "Visible summary: verifier lane checked the cold assembly plan and needs source replay.",
            "cache:reasoning-summary:cold-assembly-v1",
            "restore:summary-only-after-fence",
            "compatibility_fence:model-tokenizer-adapter-rope-system-digest-route",
            "verifier:state-is-context-not-proof",
            "purge:session-close-or-24h",
            "compute_resume_lease:cold-assembly-route:pause-verify-resume",
            8450,
            8120,
            8300,
            420,
            24_576,
            900,
            450,
            320,
            "fallback:no-state-rag-verified",
            "rollback:drop-continuity-card",
            "answer_packet:continuity-card-visible-note",
            false,
            false,
            false,
            baselines(),
            CREATED_AT_MS,
        )
        .unwrap()
    }

    #[test]
    fn continuity_card_beats_baselines() {
        let card = accepted_card();
        assert!(card.beats_all_baselines());
        assert_eq!(card.source_card_ids[0], "source:cache-lineage");
    }

    #[test]
    fn continuity_card_address_is_deterministic() {
        let first = accepted_card();
        let second = ReasoningStateContinuityCard::new(
            "session:adversarial-note-route",
            "model:local-mlx-controller",
            vec![
                "source:constructive-residency".to_string(),
                "source:cache-lineage".to_string(),
            ],
            "task:resume-cold-assembly-verification",
            PreservedStateKind::ReasoningSummary,
            StatePrivacyClass::VaultPrivate,
            first.visible_summary.clone(),
            first.cache_key.clone(),
            first.restore_policy.clone(),
            first.compatibility_fence_ref.clone(),
            first.verifier_caveat.clone(),
            first.purge_policy.clone(),
            first.compute_resume_lease_ref.clone(),
            first.continuity_bps,
            first.cache_utility_bps,
            first.verifier_bps,
            first.latency_ms,
            first.active_executed_bytes,
            first.stale_state_risk_bps,
            first.privacy_risk_bps,
            first.storage_wear_bps,
            first.fallback_route.clone(),
            first.rollback_ref.clone(),
            first.answer_packet_ref.clone(),
            false,
            false,
            false,
            first.baselines.clone(),
            CREATED_AT_MS,
        )
        .unwrap();
        assert_eq!(first.card_address, second.card_address);
    }

    #[test]
    fn continuity_card_rejects_hidden_chain() {
        let result = ReasoningStateContinuityCard::new(
            "session:x",
            "model:y",
            vec!["source:cache-lineage".to_string()],
            "task:z",
            PreservedStateKind::ReasoningSummary,
            StatePrivacyClass::VaultPrivate,
            "Visible summary",
            "cache:k",
            "restore:r",
            "compatibility_fence:f",
            "verifier:c",
            "purge:p",
            "compute_resume_lease:l",
            8000,
            8000,
            8000,
            1,
            1,
            1,
            1,
            1,
            "fallback:f",
            "rollback:r",
            "answer_packet:a",
            true,
            false,
            false,
            baselines(),
            CREATED_AT_MS,
        );
        assert!(matches!(
            result,
            Err(ReasoningStateContinuityError::HiddenChainExposed)
        ));
    }

    #[test]
    fn continuity_card_rejects_verifier_bypass() {
        let mut card = accepted_card();
        let result = ReasoningStateContinuityCard::new(
            card.session_id,
            card.model_id,
            card.source_card_ids,
            card.task_signature,
            card.preserved_state_kind,
            card.privacy_class,
            card.visible_summary,
            card.cache_key,
            card.restore_policy,
            card.compatibility_fence_ref,
            card.verifier_caveat,
            card.purge_policy,
            card.compute_resume_lease_ref,
            card.continuity_bps,
            card.cache_utility_bps,
            card.verifier_bps,
            card.latency_ms,
            card.active_executed_bytes,
            card.stale_state_risk_bps,
            card.privacy_risk_bps,
            card.storage_wear_bps,
            card.fallback_route,
            card.rollback_ref,
            card.answer_packet_ref,
            false,
            true,
            false,
            std::mem::take(&mut card.baselines),
            CREATED_AT_MS,
        );
        assert!(matches!(
            result,
            Err(ReasoningStateContinuityError::VerifierBypass)
        ));
    }

    #[test]
    fn continuity_card_rejects_unbeaten_naive_cache() {
        let mut baselines = baselines();
        baselines[1].continuity_bps = 9000;
        let result = ReasoningStateContinuityCard::new(
            "session:x",
            "model:y",
            vec!["source:cache-lineage".to_string()],
            "task:z",
            PreservedStateKind::ReasoningSummary,
            StatePrivacyClass::VaultPrivate,
            "Visible summary",
            "cache:k",
            "restore:r",
            "compatibility_fence:f",
            "verifier:c",
            "purge:p",
            "compute_resume_lease:l",
            8000,
            8000,
            8000,
            1,
            1,
            1,
            1,
            1,
            "fallback:f",
            "rollback:r",
            "answer_packet:a",
            false,
            false,
            false,
            baselines,
            CREATED_AT_MS,
        );
        assert!(matches!(
            result,
            Err(ReasoningStateContinuityError::BaselineNotBeaten)
        ));
    }
}
