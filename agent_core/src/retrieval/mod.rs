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
        !self.reasons.is_empty() && self.reasons.iter().any(|reason| !reason.trim().is_empty())
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
pub enum VaultContextViolation {
    FirstNSubstitution,
    InventoryUnknown,
    CandidatePoolTooSmall,
    LowConfidence,
    ProvenanceHidden,
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
}
