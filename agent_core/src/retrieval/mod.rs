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

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VaultContextViolation {
    AdversarialConfusion,
    FirstNSubstitution,
    InventoryUnknown,
    CandidatePoolTooSmall,
    LowConfidence,
    ProvenanceHidden,
    SynthesisUnderCited,
    TraceAbsent,
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
    let mut ranked: Vec<(usize, &ShadowFirstCandidate)> = candidates.iter().enumerate().collect();
    ranked.sort_by(|(left_index, left), (right_index, right)| {
        let left_score = finite_score(left.score);
        let right_score = finite_score(right.score);
        right_score
            .partial_cmp(&left_score)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| left_index.cmp(right_index))
    });

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
    fn trace_requires_visible_selected_candidate_reasons() {
        let mut trace = sufficient_trace();
        trace.candidates[0].reasons.clear();
        assert!(trace
            .validate()
            .contains(&VaultContextViolation::ProvenanceHidden));
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
}
