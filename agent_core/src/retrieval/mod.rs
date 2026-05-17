//! Vault Search 2.0 contract types.
//!
//! This module is intentionally data-shaped first. The legacy `vault.search`
//! path can keep returning the existing payload while newer callers attach this
//! trace to prove candidate-pool breadth, signal health, confidence, MMR
//! diversity, and user-visible provenance.

use serde::{Deserialize, Serialize};

pub const VAULT_CONTEXT_MIN_CANDIDATE_POOL: usize = 50;
pub const VAULT_CONTEXT_MAX_CANDIDATE_POOL: usize = 200;
pub const VAULT_CONTEXT_POOL_MULTIPLIER: usize = 8;
pub const VAULT_CONTEXT_MMR_LAMBDA: f64 = 0.72;
pub const VAULT_CONTEXT_RECENCY_HALF_LIFE_SECONDS: f64 = 2_592_000.0;
pub const SHADOW_FIRST_MIN_RRF_SCORE: f64 = 1.0 / 61.0;
pub const SHADOW_FIRST_MIN_TOP_MARGIN: f64 = 0.002;
pub const SHADOW_RESIDUAL_DECODE_TARGET_LIMIT: usize = 16;
pub const SHADOW_EXACT_ESCALATION_TARGET_LIMIT: usize = 8;
pub const SHADOW_EXACT_ESCALATION_QUERY_CHAR_LIMIT: usize = 160;
pub const SHADOW_EXACT_ESCALATION_SNIPPET_CHAR_LIMIT: usize = 240;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VaultInventorySnapshot {
    pub note_count: Option<usize>,
    pub manifest_hash: Option<String>,
    pub newest_modified_unix: Option<i64>,
    pub index_fresh: Option<bool>,
}

impl VaultInventorySnapshot {
    pub fn unknown() -> Self {
        Self {
            note_count: None,
            manifest_hash: None,
            newest_modified_unix: None,
            index_fresh: None,
        }
    }

    pub fn is_complete(&self) -> bool {
        self.note_count.is_some()
            && self
                .manifest_hash
                .as_ref()
                .is_some_and(|hash| !hash.is_empty())
            && self.newest_modified_unix.is_some()
            && self.index_fresh == Some(true)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VaultRetrievalMode {
    FullSearch,
    DegradedSearch,
    ShadowFirst,
    IndexOrderEnumeration,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VaultSignalKind {
    LexicalBm25,
    DenseSketch,
    GraphProximity,
    RecencyDecay,
    UserPriority,
    CognitiveResonance,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize, Default)]
pub struct VaultSignalScores {
    pub lexical_bm25: Option<f64>,
    pub dense_sketch: Option<f64>,
    pub graph_proximity: Option<f64>,
    pub recency_decay: Option<f64>,
    pub user_priority: Option<f64>,
    pub cognitive_resonance: Option<f64>,
}

impl VaultSignalScores {
    pub fn available_signals(&self) -> Vec<VaultSignalKind> {
        let mut signals = Vec::new();
        if self.lexical_bm25.is_some() {
            signals.push(VaultSignalKind::LexicalBm25);
        }
        if self.dense_sketch.is_some() {
            signals.push(VaultSignalKind::DenseSketch);
        }
        if self.graph_proximity.is_some() {
            signals.push(VaultSignalKind::GraphProximity);
        }
        if self.recency_decay.is_some() {
            signals.push(VaultSignalKind::RecencyDecay);
        }
        if self.user_priority.is_some() {
            signals.push(VaultSignalKind::UserPriority);
        }
        if self.cognitive_resonance.is_some() {
            signals.push(VaultSignalKind::CognitiveResonance);
        }
        signals
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VaultDegradedSignal {
    pub signal: VaultSignalKind,
    pub reason: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VaultConfidenceBand {
    Low,
    Medium,
    High,
}

impl VaultConfidenceBand {
    pub fn from_score(score: f64) -> Self {
        if !score.is_finite() {
            return Self::Low;
        }
        if score >= 0.82 {
            Self::High
        } else if score >= 0.55 {
            Self::Medium
        } else {
            Self::Low
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct VaultCandidateTrace {
    pub path: String,
    pub title: String,
    pub rank: usize,
    pub fused_score: f64,
    pub signals: VaultSignalScores,
    pub reasons: Vec<String>,
    pub selected: bool,
}

impl VaultCandidateTrace {
    pub fn has_visible_reason(&self) -> bool {
        self.has_non_rank_reason()
    }

    pub fn has_non_rank_reason(&self) -> bool {
        self.reasons
            .iter()
            .any(|reason| !is_rank_only_reason(reason))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
pub struct VaultConfidenceCounts {
    pub contract_sufficient: usize,
    pub high: usize,
    pub medium: usize,
    pub low: usize,
}

impl VaultConfidenceCounts {
    fn record_candidate(&mut self, candidate: &VaultCandidateTrace) {
        let band = VaultConfidenceBand::from_score(candidate.fused_score);
        match band {
            VaultConfidenceBand::High => self.high += 1,
            VaultConfidenceBand::Medium => self.medium += 1,
            VaultConfidenceBand::Low => self.low += 1,
        }
        if band != VaultConfidenceBand::Low && candidate.has_non_rank_reason() {
            self.contract_sufficient += 1;
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct VaultMmrDecision {
    pub path: String,
    pub selected: bool,
    pub relevance_score: f64,
    pub diversity_penalty: f64,
    pub final_score: f64,
    pub reason: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct VaultMmrSelection {
    pub index: usize,
    pub relevance_score: f64,
    pub diversity_penalty: f64,
    pub final_score: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ShadowFirstSource {
    Rrf,
    Dense,
    Lexical,
    Unknown,
}

impl ShadowFirstSource {
    pub fn from_wire(source: &str) -> Self {
        match source.trim().to_ascii_lowercase().as_str() {
            "rrf" => Self::Rrf,
            "dense" => Self::Dense,
            "lexical" | "bm25" => Self::Lexical,
            _ => Self::Unknown,
        }
    }

    pub fn has_exact_signal(self) -> bool {
        matches!(self, Self::Rrf | Self::Lexical)
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ShadowFirstCandidate {
    pub doc_id: String,
    pub title: String,
    pub score: f64,
    pub source: ShadowFirstSource,
    pub snippet: Option<String>,
}

impl ShadowFirstCandidate {
    pub fn has_visible_evidence(&self) -> bool {
        !self.title.trim().is_empty()
            || self
                .snippet
                .as_ref()
                .is_some_and(|snippet| !snippet.trim().is_empty())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ShadowExactEscalationReason {
    NoHits,
    DenseOnly,
    LowScore,
    AmbiguousTopMargin,
    MissingVisibleEvidence,
    ExactEscalationUnavailable,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ShadowFirstDecision {
    pub answer_allowed: bool,
    pub exact_escalation_required: bool,
    pub confidence: VaultConfidenceBand,
    pub reasons: Vec<ShadowExactEscalationReason>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ShadowExactEscalationTarget {
    pub doc_id: String,
    pub title: String,
    pub source: ShadowFirstSource,
    pub score: f64,
    pub snippet: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ShadowExactEscalationRequest {
    pub query: String,
    pub reasons: Vec<ShadowExactEscalationReason>,
    pub targets: Vec<ShadowExactEscalationTarget>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ShadowResidualDecodeRequest {
    pub query: String,
    pub reasons: Vec<ShadowExactEscalationReason>,
    pub targets: Vec<ShadowExactEscalationTarget>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ShadowResidualDecodeHit {
    pub doc_id: String,
    pub title: String,
    pub summary: Option<String>,
}

impl ShadowExactEscalationRequest {
    pub fn exact_queries(&self) -> Vec<String> {
        exact_queries_from_shadow_targets(&self.query, &self.targets)
    }
}

impl ShadowResidualDecodeRequest {
    pub fn exact_queries(&self) -> Vec<String> {
        exact_queries_from_shadow_targets(&self.query, &self.targets)
    }
}

impl ShadowResidualDecodeHit {
    pub fn has_visible_summary(&self) -> bool {
        self.summary
            .as_ref()
            .is_some_and(|summary| !summary.trim().is_empty())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ShadowResidualDecodeOutcome {
    pub request: ShadowResidualDecodeRequest,
    pub hits: Vec<ShadowResidualDecodeHit>,
}

impl ShadowResidualDecodeOutcome {
    pub fn exact_escalation_request(&self) -> ShadowExactEscalationRequest {
        let targets = self
            .request
            .targets
            .iter()
            .take(SHADOW_EXACT_ESCALATION_TARGET_LIMIT)
            .map(|target| {
                let mut target = target.clone();
                if let Some(summary) = self
                    .matching_hits_for_target(&target)
                    .into_iter()
                    .filter(|hit| hit.has_visible_summary())
                    .find_map(|hit| hit.summary.as_deref())
                    .map(bounded_exact_snippet)
                    .filter(|summary| !summary.is_empty())
                {
                    target.snippet = Some(summary);
                }
                target
            })
            .collect();

        ShadowExactEscalationRequest {
            query: self.request.query.clone(),
            reasons: self.request.reasons.clone(),
            targets,
        }
    }

    pub fn exact_verification_outcome(
        &self,
        hits: Vec<ShadowExactVerificationHit>,
    ) -> ShadowExactVerificationOutcome {
        ShadowExactVerificationOutcome {
            request: self.exact_escalation_request(),
            hits,
        }
    }

    pub fn validate_after_exact_verification(
        &self,
        hits: Vec<ShadowExactVerificationHit>,
    ) -> Vec<VaultContextViolation> {
        self.exact_verification_outcome(hits).validate()
    }

    pub fn answer_allowed_after_exact_verification(
        &self,
        hits: Vec<ShadowExactVerificationHit>,
    ) -> bool {
        self.validate_after_exact_verification(hits).is_empty()
    }

    fn matching_hits_for_target(
        &self,
        target: &ShadowExactEscalationTarget,
    ) -> Vec<&ShadowResidualDecodeHit> {
        self.hits
            .iter()
            .filter(|hit| shadow_residual_hit_matches_target(hit, target))
            .collect()
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ShadowExactVerificationHit {
    pub query: String,
    pub doc_id: String,
    pub title: String,
    pub snippet: Option<String>,
    pub score: Option<f64>,
}

impl ShadowExactVerificationHit {
    pub fn has_visible_evidence(&self) -> bool {
        !self.title.trim().is_empty()
            || self
                .snippet
                .as_ref()
                .is_some_and(|snippet| !snippet.trim().is_empty())
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ShadowExactVerificationOutcome {
    pub request: ShadowExactEscalationRequest,
    pub hits: Vec<ShadowExactVerificationHit>,
}

impl ShadowExactVerificationOutcome {
    pub fn answer_allowed(&self) -> bool {
        self.validate().is_empty()
    }

    pub fn validate(&self) -> Vec<VaultContextViolation> {
        let mut violations = Vec::new();
        if self.request.query.trim().is_empty() {
            violations.push(VaultContextViolation::TraceAbsent);
        }
        if self
            .request
            .reasons
            .contains(&ShadowExactEscalationReason::ExactEscalationUnavailable)
        {
            violations.push(VaultContextViolation::ShadowExactEscalationRequired);
        }

        let matching_hits = self.matching_hits();
        if matching_hits.is_empty() {
            violations.push(VaultContextViolation::ShadowExactEscalationRequired);
        } else if !matching_hits.iter().any(|hit| hit.has_visible_evidence()) {
            violations.push(VaultContextViolation::ProvenanceHidden);
            violations.push(VaultContextViolation::ShadowExactEscalationRequired);
        }

        dedupe_violations(violations)
    }

    pub fn matching_hits(&self) -> Vec<&ShadowExactVerificationHit> {
        if self.request.targets.is_empty() {
            return self.hits.iter().collect();
        }

        self.hits
            .iter()
            .filter(|hit| {
                self.request
                    .targets
                    .iter()
                    .any(|target| shadow_exact_hit_matches_target(hit, target))
            })
            .collect()
    }

    pub fn visible_matching_hits(&self) -> Vec<&ShadowExactVerificationHit> {
        self.matching_hits()
            .into_iter()
            .filter(|hit| hit.has_visible_evidence())
            .collect()
    }

    pub fn citable_visible_hits(&self) -> Vec<&ShadowExactVerificationHit> {
        if self.answer_allowed() {
            self.visible_matching_hits()
        } else {
            Vec::new()
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ShadowAnswerabilitySummary {
    pub answer_allowed: bool,
    pub exact_escalation_required: bool,
    pub confidence: VaultConfidenceBand,
    pub reasons: Vec<ShadowExactEscalationReason>,
    pub violations: Vec<VaultContextViolation>,
    pub candidate_count: usize,
    pub visible_evidence_count: usize,
    pub exact_escalation_target_count: usize,
    pub exact_escalation_query_count: usize,
    pub top_score_margin: Option<f64>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ShadowFirstTrace {
    pub query: String,
    pub candidates: Vec<ShadowFirstCandidate>,
    pub exact_escalation_available: bool,
    pub decision: ShadowFirstDecision,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VaultContextViolation {
    AdversarialConfusion,
    FirstNSubstitution,
    InventoryUnknown,
    CandidatePoolTooSmall,
    LowConfidence,
    ProvenanceHidden,
    SelectedCountMismatch,
    ShadowExactEscalationRequired,
    SynthesisUnderCited,
    TraceAbsent,
}

impl ShadowFirstDecision {
    pub fn context_violations(&self) -> Vec<VaultContextViolation> {
        let mut violations = Vec::new();
        if self.exact_escalation_required {
            violations.push(VaultContextViolation::ShadowExactEscalationRequired);
        }
        if self.confidence == VaultConfidenceBand::Low {
            violations.push(VaultContextViolation::LowConfidence);
        }
        dedupe_violations(violations)
    }
}

impl ShadowFirstTrace {
    pub fn new(
        query: impl Into<String>,
        candidates: Vec<ShadowFirstCandidate>,
        exact_escalation_available: bool,
    ) -> Self {
        let decision = shadow_first_decision(&candidates, exact_escalation_available);
        Self {
            query: query.into(),
            candidates,
            exact_escalation_available,
            decision,
        }
    }

    pub fn validate(&self) -> Vec<VaultContextViolation> {
        let mut violations = self.decision.context_violations();
        if self.query.trim().is_empty() {
            violations.push(VaultContextViolation::TraceAbsent);
        }
        dedupe_violations(violations)
    }

    pub fn answer_allowed(&self) -> bool {
        self.decision.answer_allowed && self.validate().is_empty()
    }

    pub fn top_score_margin(&self) -> Option<f64> {
        shadow_first_top_score_margin(&self.candidates)
    }

    pub fn answerability_summary(&self) -> ShadowAnswerabilitySummary {
        let exact_request = self.exact_escalation_request();
        let exact_escalation_target_count = exact_request
            .as_ref()
            .map(|request| request.targets.len())
            .unwrap_or(0);
        let exact_escalation_query_count = exact_request
            .as_ref()
            .map(|request| request.exact_queries().len())
            .unwrap_or(0);

        ShadowAnswerabilitySummary {
            answer_allowed: self.answer_allowed(),
            exact_escalation_required: self.decision.exact_escalation_required,
            confidence: self.decision.confidence,
            reasons: self.decision.reasons.clone(),
            violations: self.validate(),
            candidate_count: self.candidates.len(),
            visible_evidence_count: self
                .candidates
                .iter()
                .filter(|candidate| candidate.has_visible_evidence())
                .count(),
            exact_escalation_target_count,
            exact_escalation_query_count,
            top_score_margin: self.top_score_margin(),
        }
    }

    pub fn exact_escalation_request(&self) -> Option<ShadowExactEscalationRequest> {
        if !self.decision.exact_escalation_required {
            return None;
        }

        Some(ShadowExactEscalationRequest {
            query: self.query.trim().to_string(),
            reasons: self.decision.reasons.clone(),
            targets: self.escalation_targets(SHADOW_EXACT_ESCALATION_TARGET_LIMIT),
        })
    }

    pub fn residual_decode_request(&self) -> Option<ShadowResidualDecodeRequest> {
        if !self.decision.exact_escalation_required || self.candidates.is_empty() {
            return None;
        }

        Some(ShadowResidualDecodeRequest {
            query: self.query.trim().to_string(),
            reasons: self.decision.reasons.clone(),
            targets: self.escalation_targets(SHADOW_RESIDUAL_DECODE_TARGET_LIMIT),
        })
    }

    fn escalation_targets(&self, limit: usize) -> Vec<ShadowExactEscalationTarget> {
        ranked_shadow_candidates(&self.candidates)
            .into_iter()
            .take(limit)
            .map(|(_, candidate)| ShadowExactEscalationTarget {
                doc_id: candidate.doc_id.trim().to_string(),
                title: candidate.title.trim().to_string(),
                source: candidate.source,
                score: finite_score(candidate.score),
                snippet: candidate
                    .snippet
                    .as_deref()
                    .map(bounded_exact_snippet)
                    .filter(|snippet| !snippet.is_empty()),
            })
            .collect()
    }

    pub fn exact_verification_outcome(
        &self,
        hits: Vec<ShadowExactVerificationHit>,
    ) -> Option<ShadowExactVerificationOutcome> {
        self.exact_escalation_request()
            .map(|request| ShadowExactVerificationOutcome { request, hits })
    }

    pub fn validate_after_exact_verification(
        &self,
        hits: Vec<ShadowExactVerificationHit>,
    ) -> Vec<VaultContextViolation> {
        let trace_violations = self.validate();
        if trace_violations.is_empty() {
            return Vec::new();
        }
        self.exact_verification_outcome(hits)
            .map(|outcome| outcome.validate())
            .unwrap_or(trace_violations)
    }

    pub fn answer_allowed_after_exact_verification(
        &self,
        hits: Vec<ShadowExactVerificationHit>,
    ) -> bool {
        self.validate_after_exact_verification(hits).is_empty()
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct VaultContextTrace {
    pub query: String,
    pub inventory: VaultInventorySnapshot,
    pub retrieval_mode: VaultRetrievalMode,
    pub requested_result_limit: usize,
    pub candidate_count: usize,
    pub selected_count: usize,
    pub confidence: VaultConfidenceBand,
    pub degraded_signals: Vec<VaultDegradedSignal>,
    pub candidates: Vec<VaultCandidateTrace>,
    pub mmr_decisions: Vec<VaultMmrDecision>,
    pub provenance_visible: bool,
}

impl VaultContextTrace {
    pub fn validate(&self) -> Vec<VaultContextViolation> {
        let mut violations = Vec::new();

        if self.query.trim().is_empty() || self.selected_count == 0 {
            violations.push(VaultContextViolation::TraceAbsent);
        }

        if self.selected_count != self.actual_selected_count()
            || self.selected_count > self.candidate_count
        {
            violations.push(VaultContextViolation::SelectedCountMismatch);
        }

        if self.retrieval_mode == VaultRetrievalMode::IndexOrderEnumeration {
            violations.push(VaultContextViolation::FirstNSubstitution);
        }

        if !self.inventory.is_complete() {
            violations.push(VaultContextViolation::InventoryUnknown);
        }

        let required_pool =
            required_candidate_pool(self.requested_result_limit, self.inventory.note_count);
        if self.candidate_count < required_pool {
            violations.push(VaultContextViolation::CandidatePoolTooSmall);
        }

        if self.confidence == VaultConfidenceBand::Low {
            violations.push(VaultContextViolation::LowConfidence);
        }

        let selected_scores_valid = self
            .candidates
            .iter()
            .filter(|candidate| candidate.selected)
            .all(|candidate| candidate.fused_score.is_finite() && candidate.fused_score >= 0.0);
        if !selected_scores_valid {
            violations.push(VaultContextViolation::LowConfidence);
        }
        let selected_scores_non_low = self
            .candidates
            .iter()
            .filter(|candidate| candidate.selected)
            .all(|candidate| {
                VaultConfidenceBand::from_score(candidate.fused_score) != VaultConfidenceBand::Low
            });
        if !selected_scores_non_low {
            violations.push(VaultContextViolation::LowConfidence);
        }

        let selected_reasons_visible = self
            .candidates
            .iter()
            .filter(|candidate| candidate.selected)
            .all(VaultCandidateTrace::has_visible_reason);
        if !self.provenance_visible || !selected_reasons_visible {
            violations.push(VaultContextViolation::ProvenanceHidden);
        }

        dedupe_violations(violations)
    }

    pub fn is_contract_sufficient(&self) -> bool {
        self.validate().is_empty()
    }

    pub fn actual_selected_count(&self) -> usize {
        self.candidates
            .iter()
            .filter(|candidate| candidate.selected)
            .count()
    }

    pub fn confidence_counts(&self) -> VaultConfidenceCounts {
        let mut counts = VaultConfidenceCounts::default();
        for candidate in &self.candidates {
            counts.record_candidate(candidate);
        }
        counts
    }

    pub fn selected_confidence_counts(&self) -> VaultConfidenceCounts {
        let mut counts = VaultConfidenceCounts::default();
        for candidate in self
            .candidates
            .iter()
            .filter(|candidate| candidate.selected)
        {
            counts.record_candidate(candidate);
        }
        counts
    }

    pub fn selected_distinct_note_count(&self) -> usize {
        let mut distinct = std::collections::BTreeSet::new();
        for candidate in self
            .candidates
            .iter()
            .filter(|candidate| candidate.selected)
        {
            let note_id = candidate.path.trim();
            if !note_id.is_empty() {
                distinct.insert(note_id);
                continue;
            }

            let title = candidate.title.trim();
            if !title.is_empty() {
                distinct.insert(title);
            }
        }
        distinct.len()
    }

    pub fn validate_synthesis_min_distinct_notes(
        &self,
        minimum: usize,
    ) -> Vec<VaultContextViolation> {
        let mut violations = self.validate();
        if minimum > 0 && self.selected_distinct_note_count() < minimum {
            violations.push(VaultContextViolation::SynthesisUnderCited);
        }
        dedupe_violations(violations)
    }

    pub fn top_score_margin(&self) -> Option<f64> {
        let mut ranked: Vec<(usize, f64, usize)> = self
            .candidates
            .iter()
            .enumerate()
            .map(|(index, candidate)| (index, finite_score(candidate.fused_score), candidate.rank))
            .collect();
        if ranked.len() < 2 {
            return None;
        }

        ranked.sort_by(
            |(left_index, left_score, left_rank), (right_index, right_score, right_rank)| {
                right_score
                    .partial_cmp(left_score)
                    .unwrap_or(std::cmp::Ordering::Equal)
                    .then_with(|| left_rank.cmp(right_rank))
                    .then_with(|| left_index.cmp(right_index))
            },
        );

        Some((ranked[0].1 - ranked[1].1).max(0.0))
    }

    pub fn validate_adversarial_margin(&self, minimum_margin: f64) -> Vec<VaultContextViolation> {
        let mut violations = self.validate();
        if minimum_margin.is_finite()
            && minimum_margin > 0.0
            && self
                .top_score_margin()
                .is_some_and(|margin| margin < minimum_margin)
        {
            violations.push(VaultContextViolation::AdversarialConfusion);
        }
        dedupe_violations(violations)
    }
}

pub fn required_candidate_pool(result_limit: usize, inventory_count: Option<usize>) -> usize {
    let requested = result_limit
        .max(1)
        .saturating_mul(VAULT_CONTEXT_POOL_MULTIPLIER)
        .clamp(
            VAULT_CONTEXT_MIN_CANDIDATE_POOL,
            VAULT_CONTEXT_MAX_CANDIDATE_POOL,
        );
    match inventory_count {
        Some(count) => requested.min(count),
        None => requested,
    }
}

pub fn recency_half_life_decay(age_seconds: f64, half_life_seconds: f64) -> Option<f64> {
    if !age_seconds.is_finite() || !half_life_seconds.is_finite() || half_life_seconds <= 0.0 {
        return None;
    }
    let clamped_age = age_seconds.max(0.0);
    Some((-std::f64::consts::LN_2 * clamped_age / half_life_seconds).exp())
}

pub fn shadow_first_decision(
    candidates: &[ShadowFirstCandidate],
    exact_escalation_available: bool,
) -> ShadowFirstDecision {
    let ranked = ranked_shadow_candidates(candidates);
    let mut reasons = Vec::new();
    let Some((_, top)) = ranked.first().copied() else {
        reasons.push(ShadowExactEscalationReason::NoHits);
        if !exact_escalation_available {
            reasons.push(ShadowExactEscalationReason::ExactEscalationUnavailable);
        }
        return ShadowFirstDecision {
            answer_allowed: false,
            exact_escalation_required: true,
            confidence: VaultConfidenceBand::Low,
            reasons,
        };
    };

    let top_score = finite_score(top.score);
    if !top.source.has_exact_signal() {
        reasons.push(ShadowExactEscalationReason::DenseOnly);
    }
    if top_score < SHADOW_FIRST_MIN_RRF_SCORE {
        reasons.push(ShadowExactEscalationReason::LowScore);
    }
    if !top.has_visible_evidence() {
        reasons.push(ShadowExactEscalationReason::MissingVisibleEvidence);
    }
    if let Some((_, runner_up)) = ranked.get(1).copied() {
        let margin = top_score - finite_score(runner_up.score);
        if margin < SHADOW_FIRST_MIN_TOP_MARGIN {
            reasons.push(ShadowExactEscalationReason::AmbiguousTopMargin);
        }
    }

    let answer_allowed = reasons.is_empty();
    if !answer_allowed && !exact_escalation_available {
        reasons.push(ShadowExactEscalationReason::ExactEscalationUnavailable);
    }
    let confidence = if answer_allowed {
        VaultConfidenceBand::High
    } else if top.source.has_exact_signal()
        && top.has_visible_evidence()
        && top_score >= SHADOW_FIRST_MIN_RRF_SCORE
    {
        VaultConfidenceBand::Medium
    } else {
        VaultConfidenceBand::Low
    };

    ShadowFirstDecision {
        answer_allowed,
        exact_escalation_required: !answer_allowed,
        confidence,
        reasons: dedupe_escalation_reasons(reasons),
    }
}

pub fn shadow_first_top_score_margin(candidates: &[ShadowFirstCandidate]) -> Option<f64> {
    let ranked = ranked_shadow_candidates(candidates);
    if ranked.len() < 2 {
        return None;
    }

    Some((finite_score(ranked[0].1.score) - finite_score(ranked[1].1.score)).max(0.0))
}

pub fn mmr_select_indices<F>(
    relevance_scores: &[f64],
    limit: usize,
    lambda: f64,
    similarity: F,
) -> Vec<VaultMmrSelection>
where
    F: Fn(usize, usize) -> f64,
{
    if relevance_scores.is_empty() || limit == 0 {
        return Vec::new();
    }

    let lambda = if lambda.is_finite() {
        lambda.clamp(0.0, 1.0)
    } else {
        VAULT_CONTEXT_MMR_LAMBDA
    };
    let mut selected = vec![false; relevance_scores.len()];
    let mut selected_indices = Vec::new();
    let mut selections = Vec::new();

    while selections.len() < limit.min(relevance_scores.len()) {
        let mut best: Option<VaultMmrSelection> = None;

        for (index, relevance_score) in relevance_scores.iter().copied().enumerate() {
            if selected[index] {
                continue;
            }

            let relevance_score = if relevance_score.is_finite() {
                relevance_score.max(0.0)
            } else {
                0.0
            };
            let diversity_penalty = selected_indices
                .iter()
                .map(|selected_index| {
                    let similarity = similarity(index, *selected_index);
                    if similarity.is_finite() {
                        similarity.clamp(0.0, 1.0)
                    } else {
                        0.0
                    }
                })
                .fold(0.0_f64, f64::max);
            let final_score = lambda.mul_add(relevance_score, -(1.0 - lambda) * diversity_penalty);
            let candidate = VaultMmrSelection {
                index,
                relevance_score,
                diversity_penalty,
                final_score,
            };

            let replace = match best.as_ref() {
                None => true,
                Some(current) => {
                    candidate.final_score > current.final_score
                        || ((candidate.final_score - current.final_score).abs() < f64::EPSILON
                            && (candidate.relevance_score > current.relevance_score
                                || ((candidate.relevance_score - current.relevance_score).abs()
                                    < f64::EPSILON
                                    && candidate.index < current.index)))
                }
            };
            if replace {
                best = Some(candidate);
            }
        }

        let Some(best) = best else {
            break;
        };
        selected[best.index] = true;
        selected_indices.push(best.index);
        selections.push(best);
    }

    selections
}

fn dedupe_violations(violations: Vec<VaultContextViolation>) -> Vec<VaultContextViolation> {
    let mut deduped = Vec::new();
    for violation in violations {
        if !deduped.contains(&violation) {
            deduped.push(violation);
        }
    }
    deduped
}

fn dedupe_escalation_reasons(
    reasons: Vec<ShadowExactEscalationReason>,
) -> Vec<ShadowExactEscalationReason> {
    let mut deduped = Vec::new();
    for reason in reasons {
        if !deduped.contains(&reason) {
            deduped.push(reason);
        }
    }
    deduped
}

fn ranked_shadow_candidates(
    candidates: &[ShadowFirstCandidate],
) -> Vec<(usize, &ShadowFirstCandidate)> {
    let mut ranked: Vec<(usize, &ShadowFirstCandidate)> = candidates.iter().enumerate().collect();
    ranked.sort_by(|(left_index, left), (right_index, right)| {
        let left_score = finite_score(left.score);
        let right_score = finite_score(right.score);
        right_score
            .partial_cmp(&left_score)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| left_index.cmp(right_index))
    });
    ranked
}

fn push_non_empty_unique(values: &mut Vec<String>, value: &str) {
    let value = value.trim();
    if value.is_empty()
        || values
            .iter()
            .any(|existing| existing.eq_ignore_ascii_case(value))
    {
        return;
    }
    values.push(value.to_string());
}

fn exact_queries_from_shadow_targets(
    query: &str,
    targets: &[ShadowExactEscalationTarget],
) -> Vec<String> {
    let mut queries = Vec::new();
    push_non_empty_unique(&mut queries, &bounded_exact_query(query));
    for target in targets {
        push_non_empty_unique(&mut queries, &bounded_exact_query(&target.title));
        push_non_empty_unique(&mut queries, &bounded_exact_query(&target.doc_id));
        if let Some(snippet) = &target.snippet {
            push_non_empty_unique(&mut queries, &bounded_exact_query(snippet));
        }
    }
    queries
}

fn bounded_exact_query(value: &str) -> String {
    normalized_exact_text(value)
        .chars()
        .take(SHADOW_EXACT_ESCALATION_QUERY_CHAR_LIMIT)
        .collect()
}

fn bounded_exact_snippet(value: &str) -> String {
    normalized_exact_text(value)
        .chars()
        .take(SHADOW_EXACT_ESCALATION_SNIPPET_CHAR_LIMIT)
        .collect()
}

fn normalized_exact_text(value: &str) -> String {
    let normalized = value
        .replace("<b>", "")
        .replace("</b>", "")
        .replace('\u{2026}', " ");
    normalized
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

fn shadow_exact_hit_matches_target(
    hit: &ShadowExactVerificationHit,
    target: &ShadowExactEscalationTarget,
) -> bool {
    shadow_exact_identity_matches(&hit.doc_id, &target.doc_id)
        || shadow_exact_identity_matches(&hit.doc_id, &target.title)
        || shadow_exact_identity_matches(&hit.title, &target.doc_id)
        || shadow_exact_identity_matches(&hit.title, &target.title)
}

fn shadow_residual_hit_matches_target(
    hit: &ShadowResidualDecodeHit,
    target: &ShadowExactEscalationTarget,
) -> bool {
    shadow_exact_identity_matches(&hit.doc_id, &target.doc_id)
        || shadow_exact_identity_matches(&hit.doc_id, &target.title)
        || shadow_exact_identity_matches(&hit.title, &target.doc_id)
        || shadow_exact_identity_matches(&hit.title, &target.title)
}

fn shadow_exact_identity_matches(left: &str, right: &str) -> bool {
    let left = normalized_exact_text(left);
    let right = normalized_exact_text(right);
    !left.is_empty() && !right.is_empty() && left.eq_ignore_ascii_case(&right)
}

fn finite_score(score: f64) -> f64 {
    if score.is_finite() {
        score.max(0.0)
    } else {
        0.0
    }
}

fn is_rank_only_reason(reason: &str) -> bool {
    let normalized = reason.trim().to_ascii_lowercase();
    normalized.is_empty()
        || normalized == "top ranked candidate"
        || normalized == "source rank"
        || normalized.starts_with("source rank #")
        || normalized.starts_with("best source rank #")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn complete_inventory(note_count: usize) -> VaultInventorySnapshot {
        VaultInventorySnapshot {
            note_count: Some(note_count),
            manifest_hash: Some("manifest-hash".to_string()),
            newest_modified_unix: Some(1_760_000_000),
            index_fresh: Some(true),
        }
    }

    fn selected_candidate() -> VaultCandidateTrace {
        VaultCandidateTrace {
            path: "Research/Vault Recall Alpha.md".to_string(),
            title: "Vault Recall Alpha".to_string(),
            rank: 1,
            fused_score: 0.91,
            signals: VaultSignalScores {
                lexical_bm25: Some(8.0),
                dense_sketch: Some(0.72),
                graph_proximity: None,
                recency_decay: Some(0.9),
                user_priority: None,
                cognitive_resonance: None,
            },
            reasons: vec!["Title match".to_string(), "Recency boost".to_string()],
            selected: true,
        }
    }

    fn shadow_candidate(
        doc_id: &str,
        score: f64,
        source: ShadowFirstSource,
    ) -> ShadowFirstCandidate {
        ShadowFirstCandidate {
            doc_id: doc_id.to_string(),
            title: "Vault Recall Alpha".to_string(),
            score,
            source,
            snippet: Some("Vault recall alpha exact snippet.".to_string()),
        }
    }

    fn shadow_exact_request_with_target() -> ShadowExactEscalationRequest {
        ShadowExactEscalationRequest {
            query: "vault recall alpha".to_string(),
            reasons: vec![ShadowExactEscalationReason::DenseOnly],
            targets: vec![ShadowExactEscalationTarget {
                doc_id: "dense-alpha".to_string(),
                title: "Vault Recall Alpha".to_string(),
                source: ShadowFirstSource::Dense,
                score: 0.04,
                snippet: Some("Vault recall alpha exact snippet.".to_string()),
            }],
        }
    }

    fn shadow_exact_hit(
        doc_id: &str,
        title: &str,
        snippet: Option<&str>,
    ) -> ShadowExactVerificationHit {
        ShadowExactVerificationHit {
            query: "vault recall alpha".to_string(),
            doc_id: doc_id.to_string(),
            title: title.to_string(),
            snippet: snippet.map(str::to_string),
            score: Some(1.0),
        }
    }

    fn shadow_residual_hit(
        doc_id: &str,
        title: &str,
        summary: Option<&str>,
    ) -> ShadowResidualDecodeHit {
        ShadowResidualDecodeHit {
            doc_id: doc_id.to_string(),
            title: title.to_string(),
            summary: summary.map(str::to_string),
        }
    }

    fn sufficient_trace() -> VaultContextTrace {
        VaultContextTrace {
            query: "vault recall alpha".to_string(),
            inventory: complete_inventory(500),
            retrieval_mode: VaultRetrievalMode::FullSearch,
            requested_result_limit: 5,
            candidate_count: 50,
            selected_count: 1,
            confidence: VaultConfidenceBand::High,
            degraded_signals: Vec::new(),
            candidates: vec![selected_candidate()],
            mmr_decisions: vec![VaultMmrDecision {
                path: "Research/Vault Recall Alpha.md".to_string(),
                selected: true,
                relevance_score: 0.91,
                diversity_penalty: 0.0,
                final_score: 0.91,
                reason: "highest relevance and no duplicate crowding".to_string(),
            }],
            provenance_visible: true,
        }
    }

    #[test]
    fn required_candidate_pool_uses_contract_window() {
        assert_eq!(required_candidate_pool(1, None), 50);
        assert_eq!(required_candidate_pool(5, None), 50);
        assert_eq!(required_candidate_pool(10, None), 80);
        assert_eq!(required_candidate_pool(30, None), 200);
        assert_eq!(required_candidate_pool(10, Some(30)), 30);
        assert_eq!(required_candidate_pool(10, Some(500)), 80);
        assert_eq!(required_candidate_pool(10, Some(0)), 0);
    }

    #[test]
    fn recency_half_life_decay_returns_half_at_half_life() {
        let decay = recency_half_life_decay(86_400.0, 86_400.0).expect("finite decay");
        assert!((decay - 0.5).abs() < 1e-12);
        assert_eq!(recency_half_life_decay(1.0, 0.0), None);
    }

    #[test]
    fn confidence_band_thresholds_are_stable() {
        assert_eq!(
            VaultConfidenceBand::from_score(0.90),
            VaultConfidenceBand::High
        );
        assert_eq!(
            VaultConfidenceBand::from_score(0.60),
            VaultConfidenceBand::Medium
        );
        assert_eq!(
            VaultConfidenceBand::from_score(0.20),
            VaultConfidenceBand::Low
        );
        assert_eq!(
            VaultConfidenceBand::from_score(f64::NAN),
            VaultConfidenceBand::Low
        );
    }

    #[test]
    fn complete_trace_is_contract_sufficient() {
        let trace = sufficient_trace();
        assert!(trace.is_contract_sufficient());
    }

    #[test]
    fn trace_rejects_first_n_index_order_enumeration() {
        let mut trace = sufficient_trace();
        trace.retrieval_mode = VaultRetrievalMode::IndexOrderEnumeration;
        assert!(trace
            .validate()
            .contains(&VaultContextViolation::FirstNSubstitution));
    }

    #[test]
    fn trace_requires_candidate_pool_floor_when_inventory_supports_it() {
        let mut trace = sufficient_trace();
        trace.candidate_count = 7;
        assert!(trace
            .validate()
            .contains(&VaultContextViolation::CandidatePoolTooSmall));
    }

    #[test]
    fn trace_requires_inventory_completeness() {
        let mut trace = sufficient_trace();
        trace.inventory.manifest_hash = None;
        assert!(trace
            .validate()
            .contains(&VaultContextViolation::InventoryUnknown));
    }

    #[test]
    fn trace_requires_non_low_confidence() {
        let mut trace = sufficient_trace();
        trace.confidence = VaultConfidenceBand::Low;
        assert!(trace
            .validate()
            .contains(&VaultContextViolation::LowConfidence));
    }

    #[test]
    fn trace_rejects_nonfinite_or_negative_selected_scores() {
        for bad_score in [f64::NAN, f64::INFINITY, -0.01] {
            let mut trace = sufficient_trace();
            trace.candidates[0].fused_score = bad_score;

            assert!(trace
                .validate()
                .contains(&VaultContextViolation::LowConfidence));
        }
    }

    #[test]
    fn trace_rejects_low_scoring_selected_candidates() {
        let mut trace = sufficient_trace();
        trace.candidates[0].fused_score = 0.20;
        trace.confidence = VaultConfidenceBand::High;

        assert_eq!(trace.confidence_counts().low, 1);
        assert!(trace
            .validate()
            .contains(&VaultContextViolation::LowConfidence));
    }

    #[test]
    fn confidence_counts_bucket_candidates_and_contract_sufficient_hits() {
        let mut trace = sufficient_trace();
        let mut medium = selected_candidate();
        medium.path = "Research/Vault Recall Medium.md".to_string();
        medium.rank = 2;
        medium.fused_score = 0.60;
        medium.reasons = vec!["Lexical candidate".to_string()];
        medium.selected = false;
        let mut low_rank_only = selected_candidate();
        low_rank_only.path = "Research/Vault Recall Low.md".to_string();
        low_rank_only.rank = 3;
        low_rank_only.fused_score = 0.10;
        low_rank_only.reasons = vec!["Source rank #3".to_string()];
        low_rank_only.selected = false;
        trace.candidates.extend([medium, low_rank_only]);

        assert_eq!(
            trace.confidence_counts(),
            VaultConfidenceCounts {
                contract_sufficient: 2,
                high: 1,
                medium: 1,
                low: 1,
            }
        );
    }

    #[test]
    fn selected_confidence_counts_only_bucket_selected_context() {
        let mut trace = sufficient_trace();
        let mut selected_medium = selected_candidate();
        selected_medium.path = "Research/Vault Recall Medium.md".to_string();
        selected_medium.rank = 2;
        selected_medium.fused_score = 0.60;
        selected_medium.reasons = vec!["Lexical candidate".to_string()];
        let mut unselected_high = selected_candidate();
        unselected_high.path = "Research/Vault Recall Unselected.md".to_string();
        unselected_high.rank = 3;
        unselected_high.fused_score = 0.95;
        unselected_high.selected = false;
        trace.candidates.extend([selected_medium, unselected_high]);
        trace.selected_count = 2;

        assert_eq!(
            trace.selected_confidence_counts(),
            VaultConfidenceCounts {
                contract_sufficient: 2,
                high: 1,
                medium: 1,
                low: 0,
            }
        );
    }

    #[test]
    fn trace_requires_visible_selected_candidate_reasons() {
        let mut trace = sufficient_trace();
        trace.candidates[0].reasons.clear();
        assert!(trace
            .validate()
            .contains(&VaultContextViolation::ProvenanceHidden));
    }

    #[test]
    fn trace_requires_selected_count_to_match_selected_candidates() {
        let mut trace = sufficient_trace();
        trace.candidates[0].selected = false;

        assert_eq!(trace.selected_count, 1);
        assert_eq!(trace.actual_selected_count(), 0);
        assert!(trace
            .validate()
            .contains(&VaultContextViolation::SelectedCountMismatch));
    }

    #[test]
    fn trace_rejects_selected_count_larger_than_candidate_pool() {
        let mut trace = sufficient_trace();
        trace.candidate_count = 0;

        assert!(trace.selected_count > trace.candidate_count);
        assert!(trace
            .validate()
            .contains(&VaultContextViolation::SelectedCountMismatch));
    }

    #[test]
    fn trace_rejects_rank_only_selected_candidate_reasons() {
        let mut trace = sufficient_trace();
        trace.candidates[0].reasons = vec![
            "Top ranked candidate".to_string(),
            "Best source rank #1".to_string(),
        ];
        assert!(trace
            .validate()
            .contains(&VaultContextViolation::ProvenanceHidden));
    }

    #[test]
    fn trace_accepts_rank_reason_when_non_rank_evidence_is_present() {
        let mut trace = sufficient_trace();
        trace.candidates[0].reasons = vec![
            "Top ranked candidate".to_string(),
            "Lexical candidate".to_string(),
        ];
        assert!(trace.is_contract_sufficient());
    }

    #[test]
    fn synthesis_validation_requires_two_distinct_selected_notes() {
        let mut trace = sufficient_trace();
        assert_eq!(trace.selected_distinct_note_count(), 1);
        assert!(trace
            .validate_synthesis_min_distinct_notes(2)
            .contains(&VaultContextViolation::SynthesisUnderCited));

        let mut second = selected_candidate();
        second.path = "Research/Vault Recall Beta.md".to_string();
        second.title = "Vault Recall Beta".to_string();
        second.rank = 2;
        trace.candidates.push(second);
        trace.selected_count = 2;

        assert_eq!(trace.selected_distinct_note_count(), 2);
        assert!(!trace
            .validate_synthesis_min_distinct_notes(2)
            .contains(&VaultContextViolation::SynthesisUnderCited));
    }

    #[test]
    fn synthesis_validation_dedupes_repeated_selected_note_paths() {
        let mut trace = sufficient_trace();
        let mut duplicate = selected_candidate();
        duplicate.rank = 2;
        trace.candidates.push(duplicate);
        trace.selected_count = 2;

        assert_eq!(trace.selected_distinct_note_count(), 1);
        assert!(trace
            .validate_synthesis_min_distinct_notes(2)
            .contains(&VaultContextViolation::SynthesisUnderCited));
    }

    #[test]
    fn adversarial_margin_validation_flags_ambiguous_top_candidates() {
        let mut trace = sufficient_trace();
        let mut distractor = selected_candidate();
        distractor.path = "Research/Vault Recall Alpha Recent Distractor.md".to_string();
        distractor.title = "Vault Recall Alpha Recent Distractor".to_string();
        distractor.rank = 2;
        distractor.fused_score = 0.909;
        distractor.selected = false;
        trace.candidates.push(distractor);

        let margin = trace.top_score_margin().expect("top score margin");
        assert!((margin - 0.001).abs() < 1e-12);
        assert!(trace
            .validate_adversarial_margin(0.01)
            .contains(&VaultContextViolation::AdversarialConfusion));
    }

    #[test]
    fn adversarial_margin_validation_accepts_clear_top_candidate() {
        let mut trace = sufficient_trace();
        let mut runner_up = selected_candidate();
        runner_up.path = "Research/Vault Recall Beta.md".to_string();
        runner_up.title = "Vault Recall Beta".to_string();
        runner_up.rank = 2;
        runner_up.fused_score = 0.60;
        runner_up.selected = false;
        trace.candidates.push(runner_up);

        let margin = trace.top_score_margin().expect("top score margin");
        assert!((margin - 0.31).abs() < 1e-12);
        assert!(!trace
            .validate_adversarial_margin(0.01)
            .contains(&VaultContextViolation::AdversarialConfusion));
    }

    #[test]
    fn available_signals_preserve_contract_order() {
        let signals = selected_candidate().signals.available_signals();
        assert_eq!(
            signals,
            vec![
                VaultSignalKind::LexicalBm25,
                VaultSignalKind::DenseSketch,
                VaultSignalKind::RecencyDecay,
            ]
        );
    }

    #[test]
    fn mmr_selects_diverse_candidate_over_near_duplicate() {
        let relevance_scores = vec![1.0, 0.98, 0.90];
        let selections = mmr_select_indices(&relevance_scores, 2, 0.55, |left, right| {
            match (left, right) {
                (0, 1) | (1, 0) => 0.95,
                _ => 0.05,
            }
        });

        assert_eq!(
            selections
                .iter()
                .map(|selection| selection.index)
                .collect::<Vec<_>>(),
            vec![0, 2]
        );
        assert!(selections[1].diversity_penalty < 0.10);
    }

    #[test]
    fn mmr_handles_empty_zero_limit_and_nonfinite_scores() {
        assert!(mmr_select_indices(&[], 3, VAULT_CONTEXT_MMR_LAMBDA, |_, _| 0.0).is_empty());
        assert!(
            mmr_select_indices(&[1.0, 0.5], 0, VAULT_CONTEXT_MMR_LAMBDA, |_, _| 0.0).is_empty()
        );

        let selections = mmr_select_indices(&[f64::NAN, 0.4], 2, f64::NAN, |_, _| f64::NAN);
        assert_eq!(selections.len(), 2);
        assert_eq!(selections[0].index, 1);
        assert_eq!(selections[1].relevance_score, 0.0);
        assert_eq!(selections[1].diversity_penalty, 0.0);
    }

    #[test]
    fn shadow_first_source_parses_backend_wire_values() {
        assert_eq!(ShadowFirstSource::from_wire("rrf"), ShadowFirstSource::Rrf);
        assert_eq!(
            ShadowFirstSource::from_wire("dense"),
            ShadowFirstSource::Dense
        );
        assert_eq!(
            ShadowFirstSource::from_wire("BM25"),
            ShadowFirstSource::Lexical
        );
        assert_eq!(ShadowFirstSource::from_wire(""), ShadowFirstSource::Unknown);
    }

    #[test]
    fn shadow_first_allows_rrf_hit_with_visible_exact_evidence() {
        let decision = shadow_first_decision(
            &[shadow_candidate("alpha", 0.033, ShadowFirstSource::Rrf)],
            true,
        );

        assert!(decision.answer_allowed);
        assert!(!decision.exact_escalation_required);
        assert_eq!(decision.confidence, VaultConfidenceBand::High);
        assert!(decision.reasons.is_empty());
        assert!(decision.context_violations().is_empty());
    }

    #[test]
    fn shadow_first_dense_only_hit_requires_exact_escalation() {
        let decision = shadow_first_decision(
            &[shadow_candidate("alpha", 0.040, ShadowFirstSource::Dense)],
            true,
        );

        assert!(!decision.answer_allowed);
        assert!(decision.exact_escalation_required);
        assert_eq!(decision.confidence, VaultConfidenceBand::Low);
        assert!(decision
            .reasons
            .contains(&ShadowExactEscalationReason::DenseOnly));
        assert!(decision
            .context_violations()
            .contains(&VaultContextViolation::ShadowExactEscalationRequired));
    }

    #[test]
    fn shadow_first_ambiguous_top_margin_requires_exact_escalation() {
        let decision = shadow_first_decision(
            &[
                shadow_candidate("alpha", 0.0330, ShadowFirstSource::Rrf),
                shadow_candidate("distractor", 0.0325, ShadowFirstSource::Rrf),
            ],
            true,
        );

        assert!(!decision.answer_allowed);
        assert!(decision.exact_escalation_required);
        assert_eq!(decision.confidence, VaultConfidenceBand::Medium);
        assert!(decision
            .reasons
            .contains(&ShadowExactEscalationReason::AmbiguousTopMargin));
        assert_eq!(
            decision.context_violations(),
            vec![VaultContextViolation::ShadowExactEscalationRequired]
        );
    }

    #[test]
    fn shadow_first_no_hits_requires_exact_escalation_without_answer() {
        let decision = shadow_first_decision(&[], true);

        assert!(!decision.answer_allowed);
        assert!(decision.exact_escalation_required);
        assert_eq!(decision.confidence, VaultConfidenceBand::Low);
        assert_eq!(decision.reasons, vec![ShadowExactEscalationReason::NoHits]);
    }

    #[test]
    fn shadow_first_records_when_exact_escalation_is_unavailable() {
        let mut candidate = shadow_candidate("alpha", 0.040, ShadowFirstSource::Dense);
        candidate.snippet = None;
        candidate.title.clear();
        let decision = shadow_first_decision(&[candidate], false);

        assert!(!decision.answer_allowed);
        assert!(decision.exact_escalation_required);
        assert!(decision
            .reasons
            .contains(&ShadowExactEscalationReason::DenseOnly));
        assert!(decision
            .reasons
            .contains(&ShadowExactEscalationReason::MissingVisibleEvidence));
        assert!(decision
            .reasons
            .contains(&ShadowExactEscalationReason::ExactEscalationUnavailable));
    }

    #[test]
    fn shadow_first_trace_carries_decision_and_violations() {
        let candidate = shadow_candidate("dense-alpha", 0.90, ShadowFirstSource::Dense);
        let trace = ShadowFirstTrace::new("vault recall alpha", vec![candidate], false);

        assert!(!trace.answer_allowed());
        assert!(trace
            .decision
            .reasons
            .contains(&ShadowExactEscalationReason::DenseOnly));
        assert!(trace
            .decision
            .reasons
            .contains(&ShadowExactEscalationReason::ExactEscalationUnavailable));
        assert!(trace
            .validate()
            .contains(&VaultContextViolation::ShadowExactEscalationRequired));
        assert!(trace
            .validate()
            .contains(&VaultContextViolation::LowConfidence));
    }

    #[test]
    fn shadow_first_trace_blocks_empty_query_even_when_hit_allows_answer() {
        let candidate = shadow_candidate("rrf-alpha", 0.05, ShadowFirstSource::Rrf);
        let trace = ShadowFirstTrace::new("  ", vec![candidate], true);

        assert!(trace.decision.answer_allowed);
        assert!(!trace.answer_allowed());
        assert!(trace
            .validate()
            .contains(&VaultContextViolation::TraceAbsent));
    }

    #[test]
    fn shadow_first_trace_exposes_top_score_margin() {
        let trace = ShadowFirstTrace::new(
            "vault recall alpha",
            vec![
                shadow_candidate("rrf-alpha", 0.0330, ShadowFirstSource::Rrf),
                shadow_candidate("rrf-distractor", 0.0325, ShadowFirstSource::Rrf),
            ],
            true,
        );

        let margin = trace.top_score_margin().expect("shadow top margin");
        assert!((margin - 0.0005).abs() < 1e-12);
        assert_eq!(shadow_first_top_score_margin(&[]), None);
    }

    #[test]
    fn shadow_first_trace_emits_answerability_summary() {
        let trace = ShadowFirstTrace::new(
            "vault recall alpha",
            vec![shadow_candidate(
                "dense-alpha",
                0.040,
                ShadowFirstSource::Dense,
            )],
            true,
        );

        let summary = trace.answerability_summary();
        assert!(!summary.answer_allowed);
        assert!(summary.exact_escalation_required);
        assert_eq!(summary.confidence, VaultConfidenceBand::Low);
        assert_eq!(summary.candidate_count, 1);
        assert_eq!(summary.visible_evidence_count, 1);
        assert_eq!(summary.exact_escalation_target_count, 1);
        assert!(summary.exact_escalation_query_count >= 2);
        assert!(summary
            .reasons
            .contains(&ShadowExactEscalationReason::DenseOnly));
        assert!(summary
            .violations
            .contains(&VaultContextViolation::ShadowExactEscalationRequired));
    }

    #[test]
    fn shadow_first_trace_summary_omits_exact_counts_when_answerable() {
        let trace = ShadowFirstTrace::new(
            "vault recall alpha",
            vec![shadow_candidate("rrf-alpha", 0.050, ShadowFirstSource::Rrf)],
            true,
        );

        let summary = trace.answerability_summary();
        assert!(summary.answer_allowed);
        assert!(!summary.exact_escalation_required);
        assert_eq!(summary.exact_escalation_target_count, 0);
        assert_eq!(summary.exact_escalation_query_count, 0);
        assert!(summary.reasons.is_empty());
        assert!(summary.violations.is_empty());
    }

    #[test]
    fn shadow_first_trace_builds_exact_escalation_request() {
        let mut dense = shadow_candidate("dense-alpha", 0.040, ShadowFirstSource::Dense);
        dense.title = "  Vault Recall Alpha  ".to_string();
        let trace = ShadowFirstTrace::new(" vault recall alpha ", vec![dense], true);

        let request = trace
            .exact_escalation_request()
            .expect("exact escalation request");
        assert_eq!(request.query, "vault recall alpha");
        assert!(request
            .reasons
            .contains(&ShadowExactEscalationReason::DenseOnly));
        assert_eq!(request.targets.len(), 1);
        assert_eq!(request.targets[0].doc_id, "dense-alpha");
        assert_eq!(request.targets[0].title, "Vault Recall Alpha");
        assert_eq!(
            request.targets[0].snippet.as_deref(),
            Some("Vault recall alpha exact snippet.")
        );
        assert_eq!(
            request.exact_queries(),
            vec![
                "vault recall alpha".to_string(),
                "dense-alpha".to_string(),
                "Vault recall alpha exact snippet.".to_string(),
            ]
        );
    }

    #[test]
    fn shadow_first_exact_queries_dedupe_case_insensitively_and_bound_snippets() {
        let long_snippet = "A".repeat(SHADOW_EXACT_ESCALATION_QUERY_CHAR_LIMIT + 20);
        let request = ShadowExactEscalationRequest {
            query: " Vault Recall Alpha ".to_string(),
            reasons: vec![ShadowExactEscalationReason::DenseOnly],
            targets: vec![ShadowExactEscalationTarget {
                doc_id: "vault recall alpha".to_string(),
                title: "vault recall alpha".to_string(),
                source: ShadowFirstSource::Dense,
                score: 0.04,
                snippet: Some(long_snippet),
            }],
        };

        let queries = request.exact_queries();
        assert_eq!(queries.len(), 2);
        assert_eq!(queries[0], "Vault Recall Alpha");
        assert_eq!(
            queries[1].chars().count(),
            SHADOW_EXACT_ESCALATION_QUERY_CHAR_LIMIT
        );
    }

    #[test]
    fn shadow_first_exact_queries_strip_snippet_markup_and_whitespace_noise() {
        let request = ShadowExactEscalationRequest {
            query: " Vault   Recall Alpha ".to_string(),
            reasons: vec![ShadowExactEscalationReason::DenseOnly],
            targets: vec![ShadowExactEscalationTarget {
                doc_id: "dense-alpha".to_string(),
                title: "Vault Recall Alpha".to_string(),
                source: ShadowFirstSource::Dense,
                score: 0.04,
                snippet: Some(" <b>Needle</b>\n\u{2026}   exact body evidence ".to_string()),
            }],
        };

        assert_eq!(
            request.exact_queries(),
            vec![
                "Vault Recall Alpha".to_string(),
                "dense-alpha".to_string(),
                "Needle exact body evidence".to_string(),
            ]
        );
    }

    #[test]
    fn shadow_exact_verification_allows_matching_visible_hit() {
        let outcome = ShadowExactVerificationOutcome {
            request: shadow_exact_request_with_target(),
            hits: vec![shadow_exact_hit(
                "dense-alpha",
                "Vault Recall Alpha",
                Some("Exact body evidence."),
            )],
        };

        assert!(outcome.answer_allowed());
        assert!(outcome.validate().is_empty());
        assert_eq!(outcome.matching_hits().len(), 1);
        assert_eq!(outcome.visible_matching_hits().len(), 1);
        assert_eq!(outcome.citable_visible_hits().len(), 1);
    }

    #[test]
    fn shadow_exact_verification_exposes_only_visible_matching_hits() {
        let outcome = ShadowExactVerificationOutcome {
            request: shadow_exact_request_with_target(),
            hits: vec![
                shadow_exact_hit("dense-alpha", "  ", None),
                shadow_exact_hit(
                    "dense-alpha",
                    "Vault Recall Alpha",
                    Some("Exact body evidence."),
                ),
            ],
        };

        let visible_hits = outcome.visible_matching_hits();
        assert_eq!(outcome.matching_hits().len(), 2);
        assert_eq!(visible_hits.len(), 1);
        assert_eq!(visible_hits[0].title, "Vault Recall Alpha");
    }

    #[test]
    fn shadow_exact_verification_requires_target_match_when_targets_exist() {
        let outcome = ShadowExactVerificationOutcome {
            request: shadow_exact_request_with_target(),
            hits: vec![shadow_exact_hit(
                "different-doc",
                "Different Note",
                Some("Exact body evidence."),
            )],
        };

        assert!(!outcome.answer_allowed());
        assert_eq!(outcome.matching_hits().len(), 0);
        assert!(outcome
            .validate()
            .contains(&VaultContextViolation::ShadowExactEscalationRequired));
    }

    #[test]
    fn shadow_exact_verification_normalizes_identity_matches() {
        let mut request = shadow_exact_request_with_target();
        request.targets[0].title = " <b>Vault</b>   Recall\u{2026}Alpha ".to_string();
        let outcome = ShadowExactVerificationOutcome {
            request,
            hits: vec![shadow_exact_hit(
                "different-doc",
                "vault recall alpha",
                Some("Exact body evidence."),
            )],
        };

        assert!(outcome.answer_allowed());
        assert_eq!(outcome.matching_hits().len(), 1);
        assert_eq!(outcome.citable_visible_hits().len(), 1);
    }

    #[test]
    fn shadow_exact_verification_allows_query_only_recovery_without_targets() {
        let outcome = ShadowExactVerificationOutcome {
            request: ShadowExactEscalationRequest {
                query: "vault recall alpha".to_string(),
                reasons: vec![ShadowExactEscalationReason::NoHits],
                targets: Vec::new(),
            },
            hits: vec![shadow_exact_hit(
                "lexical-alpha",
                "Vault Recall Alpha",
                Some("Exact lexical evidence."),
            )],
        };

        assert!(outcome.answer_allowed());
        assert_eq!(outcome.matching_hits().len(), 1);
    }

    #[test]
    fn shadow_exact_verification_rejects_hidden_matching_evidence() {
        let outcome = ShadowExactVerificationOutcome {
            request: shadow_exact_request_with_target(),
            hits: vec![shadow_exact_hit("dense-alpha", "  ", None)],
        };

        let violations = outcome.validate();
        assert!(!outcome.answer_allowed());
        assert!(violations.contains(&VaultContextViolation::ProvenanceHidden));
        assert!(violations.contains(&VaultContextViolation::ShadowExactEscalationRequired));
    }

    #[test]
    fn shadow_exact_verification_stays_blocked_when_escalation_unavailable() {
        let mut request = shadow_exact_request_with_target();
        request
            .reasons
            .push(ShadowExactEscalationReason::ExactEscalationUnavailable);
        let outcome = ShadowExactVerificationOutcome {
            request,
            hits: vec![shadow_exact_hit(
                "dense-alpha",
                "Vault Recall Alpha",
                Some("Exact body evidence."),
            )],
        };

        assert!(!outcome.answer_allowed());
        assert!(outcome
            .validate()
            .contains(&VaultContextViolation::ShadowExactEscalationRequired));
    }

    #[test]
    fn shadow_exact_verification_citable_hits_require_valid_outcome() {
        let mut request = shadow_exact_request_with_target();
        request
            .reasons
            .push(ShadowExactEscalationReason::ExactEscalationUnavailable);
        let outcome = ShadowExactVerificationOutcome {
            request,
            hits: vec![shadow_exact_hit(
                "dense-alpha",
                "Vault Recall Alpha",
                Some("Exact body evidence."),
            )],
        };

        assert_eq!(outcome.visible_matching_hits().len(), 1);
        assert!(outcome.citable_visible_hits().is_empty());
    }

    #[test]
    fn shadow_first_trace_skips_escalation_request_when_answerable() {
        let trace = ShadowFirstTrace::new(
            "vault recall alpha",
            vec![shadow_candidate("rrf-alpha", 0.050, ShadowFirstSource::Rrf)],
            true,
        );

        assert!(trace.answer_allowed());
        assert_eq!(trace.exact_escalation_request(), None);
    }

    #[test]
    fn shadow_first_trace_builds_exact_verification_outcome() {
        let trace = ShadowFirstTrace::new(
            "vault recall alpha",
            vec![shadow_candidate(
                "dense-alpha",
                0.040,
                ShadowFirstSource::Dense,
            )],
            true,
        );

        let outcome = trace
            .exact_verification_outcome(vec![shadow_exact_hit(
                "dense-alpha",
                "Vault Recall Alpha",
                Some("Exact body evidence."),
            )])
            .expect("exact verification outcome");

        assert!(outcome.answer_allowed());
        assert!(outcome
            .request
            .reasons
            .contains(&ShadowExactEscalationReason::DenseOnly));
    }

    #[test]
    fn shadow_first_trace_allows_answer_after_visible_exact_verification() {
        let trace = ShadowFirstTrace::new(
            "vault recall alpha",
            vec![shadow_candidate(
                "dense-alpha",
                0.040,
                ShadowFirstSource::Dense,
            )],
            true,
        );

        assert!(!trace.answer_allowed());
        assert!(trace.answer_allowed_after_exact_verification(vec![shadow_exact_hit(
            "dense-alpha",
            "Vault Recall Alpha",
            Some("Exact body evidence."),
        )]));
        assert!(trace
            .validate_after_exact_verification(vec![shadow_exact_hit(
                "dense-alpha",
                "Vault Recall Alpha",
                Some("Exact body evidence."),
            )])
            .is_empty());
    }

    #[test]
    fn shadow_first_trace_stays_blocked_after_hidden_exact_verification() {
        let trace = ShadowFirstTrace::new(
            "vault recall alpha",
            vec![shadow_candidate(
                "dense-alpha",
                0.040,
                ShadowFirstSource::Dense,
            )],
            true,
        );

        let violations = trace.validate_after_exact_verification(vec![shadow_exact_hit(
            "dense-alpha",
            "  ",
            None,
        )]);

        assert!(!trace.answer_allowed_after_exact_verification(vec![shadow_exact_hit(
            "dense-alpha",
            "  ",
            None,
        )]));
        assert!(violations.contains(&VaultContextViolation::ProvenanceHidden));
        assert!(violations.contains(&VaultContextViolation::ShadowExactEscalationRequired));
    }

    #[test]
    fn shadow_first_trace_keeps_direct_answerability_without_exact_hits() {
        let trace = ShadowFirstTrace::new(
            "vault recall alpha",
            vec![shadow_candidate("rrf-alpha", 0.050, ShadowFirstSource::Rrf)],
            true,
        );

        assert!(trace.answer_allowed());
        assert!(trace.answer_allowed_after_exact_verification(Vec::new()));
        assert!(trace
            .validate_after_exact_verification(Vec::new())
            .is_empty());
    }

    #[test]
    fn shadow_first_trace_skips_exact_verification_outcome_when_answerable() {
        let trace = ShadowFirstTrace::new(
            "vault recall alpha",
            vec![shadow_candidate("rrf-alpha", 0.050, ShadowFirstSource::Rrf)],
            true,
        );

        assert!(trace.answer_allowed());
        assert_eq!(trace.exact_verification_outcome(Vec::new()), None);
        assert_eq!(trace.residual_decode_request(), None);
    }

    #[test]
    fn shadow_first_trace_omits_blank_escalation_snippets() {
        let mut candidate = shadow_candidate("dense-alpha", 0.040, ShadowFirstSource::Dense);
        candidate.snippet = Some("  ".to_string());
        let trace = ShadowFirstTrace::new("vault recall alpha", vec![candidate], true);

        let request = trace
            .exact_escalation_request()
            .expect("exact escalation request");

        assert_eq!(request.targets.len(), 1);
        assert_eq!(request.targets[0].snippet, None);
    }

    #[test]
    fn shadow_first_trace_bounds_and_normalizes_escalation_snippets() {
        let mut candidate = shadow_candidate("dense-alpha", 0.040, ShadowFirstSource::Dense);
        candidate.snippet = Some(format!(
            " <b>Needle</b>\n\u{2026} {} ",
            "A".repeat(SHADOW_EXACT_ESCALATION_SNIPPET_CHAR_LIMIT + 20)
        ));
        let trace = ShadowFirstTrace::new("vault recall alpha", vec![candidate], true);

        let request = trace
            .exact_escalation_request()
            .expect("exact escalation request");
        let snippet = request.targets[0]
            .snippet
            .as_deref()
            .expect("bounded snippet");

        assert!(snippet.starts_with("Needle "));
        assert!(!snippet.contains("<b>"));
        assert_eq!(
            snippet.chars().count(),
            SHADOW_EXACT_ESCALATION_SNIPPET_CHAR_LIMIT
        );
    }

    #[test]
    fn shadow_first_trace_bounds_escalation_targets_by_rank() {
        let candidates: Vec<_> = (0..12)
            .map(|index| {
                shadow_candidate(
                    &format!("dense-{index}"),
                    0.080 - f64::from(index) * 0.003,
                    ShadowFirstSource::Dense,
                )
            })
            .collect();
        let trace = ShadowFirstTrace::new("vault recall alpha", candidates, true);

        let request = trace
            .exact_escalation_request()
            .expect("exact escalation request");

        assert_eq!(request.targets.len(), SHADOW_EXACT_ESCALATION_TARGET_LIMIT);
        assert_eq!(request.targets[0].doc_id, "dense-0");
        assert_eq!(request.targets[7].doc_id, "dense-7");
        assert!(!request
            .targets
            .iter()
            .any(|target| target.doc_id == "dense-8"));
    }

    #[test]
    fn shadow_first_trace_builds_residual_decode_request_before_exact_limit() {
        let candidates: Vec<_> = (0..20)
            .map(|index| {
                shadow_candidate(
                    &format!("dense-{index}"),
                    0.120 - f64::from(index) * 0.003,
                    ShadowFirstSource::Dense,
                )
            })
            .collect();
        let trace = ShadowFirstTrace::new(" vault recall alpha ", candidates, true);

        let residual = trace
            .residual_decode_request()
            .expect("residual decode request");
        let exact = trace
            .exact_escalation_request()
            .expect("exact escalation request");

        assert_eq!(residual.query, "vault recall alpha");
        assert!(residual
            .reasons
            .contains(&ShadowExactEscalationReason::DenseOnly));
        assert_eq!(residual.targets.len(), SHADOW_RESIDUAL_DECODE_TARGET_LIMIT);
        assert_eq!(exact.targets.len(), SHADOW_EXACT_ESCALATION_TARGET_LIMIT);
        assert_eq!(residual.targets[0].doc_id, "dense-0");
        assert_eq!(residual.targets[15].doc_id, "dense-15");
        let queries = residual.exact_queries();
        assert!(queries.contains(&"vault recall alpha".to_string()));
        assert!(queries.contains(&"dense-0".to_string()));
        assert!(queries.contains(&"Vault recall alpha exact snippet.".to_string()));
        assert!(!residual
            .targets
            .iter()
            .any(|target| target.doc_id == "dense-16"));
    }

    #[test]
    fn shadow_residual_decode_outcome_enriches_exact_escalation_snippets() {
        let residual = ShadowResidualDecodeRequest {
            query: "vault recall alpha".to_string(),
            reasons: vec![ShadowExactEscalationReason::DenseOnly],
            targets: vec![ShadowExactEscalationTarget {
                doc_id: "dense-alpha".to_string(),
                title: "Vault Recall Alpha".to_string(),
                source: ShadowFirstSource::Dense,
                score: 0.04,
                snippet: Some("sketch snippet".to_string()),
            }],
        };
        let outcome = ShadowResidualDecodeOutcome {
            request: residual,
            hits: vec![shadow_residual_hit(
                "dense-alpha",
                "Vault Recall Alpha",
                Some(" <b>Residual</b>\n\u{2026} compressed body summary "),
            )],
        };

        let exact = outcome.exact_escalation_request();

        assert_eq!(exact.targets.len(), 1);
        assert_eq!(
            exact.targets[0].snippet.as_deref(),
            Some("Residual compressed body summary")
        );
        assert!(exact
            .exact_queries()
            .contains(&"Residual compressed body summary".to_string()));
    }

    #[test]
    fn shadow_residual_decode_outcome_keeps_sketch_snippet_without_visible_summary() {
        let residual = ShadowResidualDecodeRequest {
            query: "vault recall alpha".to_string(),
            reasons: vec![ShadowExactEscalationReason::DenseOnly],
            targets: vec![ShadowExactEscalationTarget {
                doc_id: "dense-alpha".to_string(),
                title: "Vault Recall Alpha".to_string(),
                source: ShadowFirstSource::Dense,
                score: 0.04,
                snippet: Some("sketch snippet".to_string()),
            }],
        };
        let outcome = ShadowResidualDecodeOutcome {
            request: residual,
            hits: vec![shadow_residual_hit("dense-alpha", "Vault Recall Alpha", None)],
        };

        let exact = outcome.exact_escalation_request();

        assert_eq!(exact.targets[0].snippet.as_deref(), Some("sketch snippet"));
    }

    #[test]
    fn shadow_residual_decode_outcome_skips_blank_matching_summaries() {
        let residual = ShadowResidualDecodeRequest {
            query: "vault recall alpha".to_string(),
            reasons: vec![ShadowExactEscalationReason::DenseOnly],
            targets: vec![ShadowExactEscalationTarget {
                doc_id: "dense-alpha".to_string(),
                title: "Vault Recall Alpha".to_string(),
                source: ShadowFirstSource::Dense,
                score: 0.04,
                snippet: Some("sketch snippet".to_string()),
            }],
        };
        let outcome = ShadowResidualDecodeOutcome {
            request: residual,
            hits: vec![
                shadow_residual_hit("dense-alpha", "Vault Recall Alpha", Some("   ")),
                shadow_residual_hit(
                    "Dense Alpha",
                    "Vault Recall Alpha",
                    Some("later visible residual summary"),
                ),
            ],
        };

        let exact = outcome.exact_escalation_request();

        assert_eq!(
            exact.targets[0].snippet.as_deref(),
            Some("later visible residual summary")
        );
    }

    #[test]
    fn shadow_residual_decode_outcome_ignores_unmatched_visible_summaries() {
        let residual = ShadowResidualDecodeRequest {
            query: "vault recall alpha".to_string(),
            reasons: vec![ShadowExactEscalationReason::DenseOnly],
            targets: vec![ShadowExactEscalationTarget {
                doc_id: "dense-alpha".to_string(),
                title: "Vault Recall Alpha".to_string(),
                source: ShadowFirstSource::Dense,
                score: 0.04,
                snippet: Some("sketch snippet".to_string()),
            }],
        };
        let outcome = ShadowResidualDecodeOutcome {
            request: residual,
            hits: vec![shadow_residual_hit(
                "dense-beta",
                "Vault Recall Beta",
                Some("unrelated residual summary"),
            )],
        };

        let exact = outcome.exact_escalation_request();

        assert_eq!(exact.targets[0].snippet.as_deref(), Some("sketch snippet"));
        assert!(!exact
            .exact_queries()
            .contains(&"unrelated residual summary".to_string()));
    }

    #[test]
    fn shadow_residual_decode_outcome_bridges_enriched_exact_verification() {
        let residual = ShadowResidualDecodeRequest {
            query: "vault recall alpha".to_string(),
            reasons: vec![ShadowExactEscalationReason::DenseOnly],
            targets: vec![ShadowExactEscalationTarget {
                doc_id: "dense-alpha".to_string(),
                title: "Vault Recall Alpha".to_string(),
                source: ShadowFirstSource::Dense,
                score: 0.04,
                snippet: Some("sketch snippet".to_string()),
            }],
        };
        let outcome = ShadowResidualDecodeOutcome {
            request: residual,
            hits: vec![shadow_residual_hit(
                "dense-alpha",
                "Vault Recall Alpha",
                Some("residual body verification phrase"),
            )],
        };

        let exact = outcome.exact_verification_outcome(vec![shadow_exact_hit(
            "dense-alpha",
            "Vault Recall Alpha",
            Some("verified body evidence"),
        )]);

        assert!(exact.answer_allowed());
        assert_eq!(
            exact.request.targets[0].snippet.as_deref(),
            Some("residual body verification phrase")
        );
        assert_eq!(exact.citable_visible_hits().len(), 1);
        assert!(outcome.answer_allowed_after_exact_verification(vec![shadow_exact_hit(
            "dense-alpha",
            "Vault Recall Alpha",
            Some("verified body evidence"),
        )]));
    }

    #[test]
    fn shadow_residual_decode_outcome_still_rejects_unmatched_exact_hits() {
        let residual = ShadowResidualDecodeRequest {
            query: "vault recall alpha".to_string(),
            reasons: vec![ShadowExactEscalationReason::DenseOnly],
            targets: vec![ShadowExactEscalationTarget {
                doc_id: "dense-alpha".to_string(),
                title: "Vault Recall Alpha".to_string(),
                source: ShadowFirstSource::Dense,
                score: 0.04,
                snippet: Some("sketch snippet".to_string()),
            }],
        };
        let outcome = ShadowResidualDecodeOutcome {
            request: residual,
            hits: vec![shadow_residual_hit(
                "dense-alpha",
                "Vault Recall Alpha",
                Some("residual body verification phrase"),
            )],
        };

        let violations = outcome.validate_after_exact_verification(vec![shadow_exact_hit(
            "dense-beta",
            "Vault Recall Beta",
            Some("verified but unrelated body evidence"),
        )]);

        assert!(violations.contains(&VaultContextViolation::ShadowExactEscalationRequired));
    }
}
