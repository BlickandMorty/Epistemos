use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::fmt;

use crate::routing::{CloudProvider, LocalTask, RoutingDecision};

pub const MEMORY_SIMILARITY_THRESHOLD: f32 = 0.85;
const EMBEDDING_DIMENSION: usize = 384;
const STOP_WORDS: &[&str] = &[
    "a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "has", "have", "in", "is",
    "it", "of", "on", "or", "the", "to", "was", "were", "with",
];

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum MemoryOperation {
    Add,
    Update {
        target_file: String,
        target_section: String,
    },
    Delete {
        target_file: String,
        target_section: String,
        reason: String,
    },
    Noop {
        reason: String,
    },
}

impl fmt::Display for MemoryOperation {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Add => formatter.write_str("ADD"),
            Self::Update { .. } => formatter.write_str("UPDATE"),
            Self::Delete { .. } => formatter.write_str("DELETE"),
            Self::Noop { .. } => formatter.write_str("NOOP"),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct VaultFact {
    pub file_path: String,
    pub section: String,
    pub content: String,
    pub embedding: Vec<f32>,
    pub strength: f64,
    pub last_accessed: DateTime<Utc>,
}

impl VaultFact {
    pub fn new(
        file_path: impl Into<String>,
        section: impl Into<String>,
        content: impl Into<String>,
        strength: f64,
        last_accessed: DateTime<Utc>,
    ) -> Self {
        let content = content.into();
        Self {
            file_path: file_path.into(),
            section: section.into(),
            embedding: embed_text(&content),
            content,
            strength,
            last_accessed,
        }
    }

    fn effective_embedding(&self) -> Vec<f32> {
        if self.embedding.is_empty() {
            embed_text(&self.content)
        } else {
            self.embedding.clone()
        }
    }
}

trait MemoryClassificationBackend {
    fn classify(
        &self,
        prompt: &str,
        incoming: &str,
        existing: &VaultFact,
        similarity: f32,
    ) -> Option<FactRelationship>;
}

#[derive(Debug, Clone, Copy, Default)]
struct HeuristicMemoryClassifier;

impl MemoryClassificationBackend for HeuristicMemoryClassifier {
    fn classify(
        &self,
        prompt: &str,
        incoming: &str,
        existing: &VaultFact,
        similarity: f32,
    ) -> Option<FactRelationship> {
        let _ = prompt;
        Some(classify_relationship(incoming, existing, similarity))
    }
}

pub fn classify_memory_operation(incoming: &str, existing_facts: &[VaultFact]) -> MemoryOperation {
    classify_memory_operation_with_backend(incoming, existing_facts, &HeuristicMemoryClassifier)
}

pub fn plan_memory_operations(
    incoming: &str,
    existing_facts: &[VaultFact],
) -> Vec<MemoryOperation> {
    let operation = classify_memory_operation(incoming, existing_facts);
    match operation {
        MemoryOperation::Delete {
            target_file,
            target_section,
            reason,
        } => vec![
            MemoryOperation::Delete {
                target_file,
                target_section,
                reason,
            },
            MemoryOperation::Add,
        ],
        other => vec![other],
    }
}

fn classify_memory_operation_with_backend<B: MemoryClassificationBackend>(
    incoming: &str,
    existing_facts: &[VaultFact],
    backend: &B,
) -> MemoryOperation {
    let incoming_embedding = embed_text(incoming);
    let Some((fact, similarity)) = select_candidate_fact(&incoming_embedding, existing_facts)
    else {
        return MemoryOperation::Add;
    };

    let prompt = build_classification_prompt(incoming, fact);
    let relationship = backend
        .classify(&prompt, incoming, fact, similarity)
        .unwrap_or_else(|| classify_relationship(incoming, fact, similarity));

    match relationship {
        FactRelationship::Confirm => MemoryOperation::Noop {
            reason: "Incoming fact confirms existing memory.".to_string(),
        },
        FactRelationship::Update => MemoryOperation::Update {
            target_file: fact.file_path.clone(),
            target_section: fact.section.clone(),
        },
        FactRelationship::Contradict => MemoryOperation::Delete {
            target_file: fact.file_path.clone(),
            target_section: fact.section.clone(),
            reason: "Incoming fact contradicts the existing memory.".to_string(),
        },
        FactRelationship::Add => MemoryOperation::Add,
    }
}

pub fn build_classification_prompt(incoming: &str, existing: &VaultFact) -> String {
    let existing = truncate_for_prompt(&existing.content, 220);
    let incoming = truncate_for_prompt(incoming, 220);
    format!(
        "Classify incoming memory against existing memory. Reply with one label only: noop, update, contradict, add.\nRules: noop=same fact, update=same entity with newer or richer detail, contradict=incoming makes existing false, add=novel fact.\nExisting: {existing}\nIncoming: {incoming}"
    )
}

pub fn estimate_prompt_tokens(prompt: &str) -> usize {
    prompt.split_whitespace().count()
}

pub fn classification_dispatch() -> RoutingDecision {
    RoutingDecision::LocalWithFallback {
        local: LocalTask::Classify,
        fallback: CloudProvider::ClaudeHaiku,
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum FactRelationship {
    Confirm,
    Update,
    Contradict,
    Add,
}

fn select_candidate_fact<'a>(
    incoming_embedding: &[f32],
    existing_facts: &'a [VaultFact],
) -> Option<(&'a VaultFact, f32)> {
    existing_facts
        .iter()
        .map(|fact| {
            let similarity = cosine_similarity(incoming_embedding, &fact.effective_embedding());
            (fact, similarity)
        })
        .filter(|(_, similarity)| *similarity >= MEMORY_SIMILARITY_THRESHOLD)
        .max_by(
            |(left_fact, left_similarity), (right_fact, right_similarity)| {
                left_similarity
                    .total_cmp(right_similarity)
                    .then_with(|| left_fact.strength.total_cmp(&right_fact.strength))
            },
        )
}

fn classify_relationship(
    incoming: &str,
    existing: &VaultFact,
    similarity: f32,
) -> FactRelationship {
    let incoming_normalized = normalize_text(incoming);
    let existing_normalized = normalize_text(&existing.content);
    if incoming_normalized == existing_normalized {
        return FactRelationship::Confirm;
    }

    let incoming_tokens = content_tokens(&incoming_normalized);
    let existing_tokens = content_tokens(&existing_normalized);
    let token_overlap = token_overlap_ratio(&incoming_tokens, &existing_tokens);

    if token_overlap < 0.35 && similarity < MEMORY_SIMILARITY_THRESHOLD {
        return FactRelationship::Add;
    }

    if has_numeric_conflict(incoming, &existing.content)
        || has_boolean_conflict(incoming, &existing.content)
        || has_antonym_conflict(incoming, &existing.content)
    {
        return FactRelationship::Contradict;
    }

    if incoming_normalized.contains(&existing_normalized)
        || token_overlap >= 0.75 && incoming_tokens.len() > existing_tokens.len()
    {
        return FactRelationship::Update;
    }

    if existing_normalized.contains(&incoming_normalized) || similarity >= 0.97 {
        return FactRelationship::Confirm;
    }

    if token_overlap >= 0.55 {
        return FactRelationship::Update;
    }

    FactRelationship::Add
}

fn embed_text(text: &str) -> Vec<f32> {
    let normalized = normalize_text(text);
    if normalized.is_empty() {
        return vec![0.0; EMBEDDING_DIMENSION];
    }

    let mut embedding = vec![0.0f32; EMBEDDING_DIMENSION];
    for (index, token) in normalized.split_whitespace().enumerate() {
        if token.is_empty() {
            continue;
        }

        let contains_digit = token.chars().any(|character| character.is_ascii_digit());
        let base_weight = if contains_digit {
            0.25
        } else {
            2.5 / (1.0 + index as f32 * 0.35)
        };
        let primary_index = hash_str(token) as usize % EMBEDDING_DIMENSION;
        embedding[primary_index] += base_weight;

        let chars: Vec<char> = token.chars().collect();
        if chars.len() < 3 {
            let unigram_index = hash_str(&format!("u:{token}")) as usize % EMBEDDING_DIMENSION;
            embedding[unigram_index] += base_weight * 0.5;
            continue;
        }

        for window in chars.windows(3) {
            let trigram: String = window.iter().collect();
            let trigram_index = hash_str(&trigram) as usize % EMBEDDING_DIMENSION;
            embedding[trigram_index] += base_weight * 0.35;
        }
    }

    normalize_embedding(&mut embedding);
    embedding
}

fn normalize_embedding(embedding: &mut [f32]) {
    let magnitude = embedding
        .iter()
        .map(|value| value * value)
        .sum::<f32>()
        .sqrt();
    if magnitude == 0.0 {
        return;
    }

    for value in embedding {
        *value /= magnitude;
    }
}

/// Public wrapper for cross-module access (used by evolution::mutation_proposer).
pub fn embed_text_public(text: &str) -> Vec<f32> {
    embed_text(text)
}

/// Public wrapper for cross-module access (used by evolution::mutation_proposer).
pub fn cosine_similarity_public(left: &[f32], right: &[f32]) -> f32 {
    cosine_similarity(left, right)
}

fn cosine_similarity(left: &[f32], right: &[f32]) -> f32 {
    if left.is_empty() || right.is_empty() || left.len() != right.len() {
        return 0.0;
    }

    left.iter()
        .zip(right.iter())
        .map(|(left_value, right_value)| left_value * right_value)
        .sum()
}

fn normalize_text(text: &str) -> String {
    text.to_lowercase()
        .chars()
        .map(|character| {
            if character.is_alphanumeric() || matches!(character, '$' | '%' | '.' | ':' | '-') {
                character
            } else {
                ' '
            }
        })
        .collect::<String>()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

fn content_tokens(text: &str) -> Vec<String> {
    text.split_whitespace()
        .filter(|token| !STOP_WORDS.contains(token))
        .map(ToString::to_string)
        .collect()
}

fn token_overlap_ratio(left: &[String], right: &[String]) -> f32 {
    if left.is_empty() || right.is_empty() {
        return 0.0;
    }

    let left_set: BTreeSet<&str> = left.iter().map(String::as_str).collect();
    let right_set: BTreeSet<&str> = right.iter().map(String::as_str).collect();
    let intersection = left_set.intersection(&right_set).count() as f32;
    let baseline = left_set.len().min(right_set.len()) as f32;
    intersection / baseline
}

fn has_numeric_conflict(left: &str, right: &str) -> bool {
    let left_numbers = extract_numeric_tokens(left);
    let right_numbers = extract_numeric_tokens(right);
    !left_numbers.is_empty() && !right_numbers.is_empty() && left_numbers != right_numbers
}

fn has_boolean_conflict(left: &str, right: &str) -> bool {
    negation_state(left) != negation_state(right)
}

fn negation_state(text: &str) -> bool {
    let normalized = normalize_text(text);
    [
        " not ",
        " no ",
        " never ",
        " without ",
        " disabled ",
        " removed ",
        " false ",
    ]
    .iter()
    .any(|needle| format!(" {normalized} ").contains(needle))
}

fn has_antonym_conflict(left: &str, right: &str) -> bool {
    let normalized_left = normalize_text(left);
    let normalized_right = normalize_text(right);
    const ANTONYM_PAIRS: [(&str, &str); 6] = [
        ("enabled", "disabled"),
        ("online", "offline"),
        ("public", "private"),
        ("allow", "deny"),
        ("supports", "unsupported"),
        ("active", "inactive"),
    ];

    ANTONYM_PAIRS.iter().any(|(left_word, right_word)| {
        (normalized_left.contains(left_word) && normalized_right.contains(right_word))
            || (normalized_left.contains(right_word) && normalized_right.contains(left_word))
    })
}

fn extract_numeric_tokens(text: &str) -> Vec<String> {
    let mut tokens = Vec::new();
    let mut current = String::new();

    for character in text.chars() {
        if character.is_ascii_digit() || matches!(character, '.' | '$' | '%' | ',') {
            current.push(character);
        } else if !current.is_empty() {
            tokens.push(current.trim_matches(',').to_string());
            current.clear();
        }
    }

    if !current.is_empty() {
        tokens.push(current.trim_matches(',').to_string());
    }

    tokens
}

fn truncate_for_prompt(text: &str, max_chars: usize) -> String {
    let normalized = text.split_whitespace().collect::<Vec<_>>().join(" ");
    if normalized.chars().count() <= max_chars {
        normalized
    } else {
        normalized
            .chars()
            .take(max_chars.saturating_sub(1))
            .collect::<String>()
            + "…"
    }
}

fn hash_str(text: &str) -> u64 {
    let mut hash = 14695981039346656037_u64;
    for byte in text.bytes() {
        hash ^= byte as u64;
        hash = hash.wrapping_mul(1099511628211);
    }
    hash
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    fn fact(file_path: &str, section: &str, content: &str) -> VaultFact {
        VaultFact::new(
            file_path,
            section,
            content,
            1.0,
            Utc.with_ymd_and_hms(2026, 3, 30, 12, 0, 0).unwrap(),
        )
    }

    #[test]
    fn memory_classifier_identical_facts_return_noop() {
        let existing = [fact(
            "providers/claude.md",
            "pricing",
            "Claude costs $15 per month.",
        )];

        let result = classify_memory_operation("Claude costs $15 per month.", &existing);

        assert_eq!(
            result,
            MemoryOperation::Noop {
                reason: "Incoming fact confirms existing memory.".to_string(),
            }
        );
    }

    #[test]
    fn memory_classifier_contradictions_expand_to_delete_then_add() {
        let existing = [fact(
            "providers/claude.md",
            "pricing",
            "Claude costs $15 per month.",
        )];

        let result = plan_memory_operations("Claude costs $20 per month.", &existing);

        assert_eq!(
            result,
            vec![
                MemoryOperation::Delete {
                    target_file: "providers/claude.md".to_string(),
                    target_section: "pricing".to_string(),
                    reason: "Incoming fact contradicts the existing memory.".to_string(),
                },
                MemoryOperation::Add,
            ]
        );
    }

    #[test]
    fn memory_classifier_updates_refine_existing_fact() {
        let existing = [fact(
            "providers/claude.md",
            "pricing",
            "Claude costs $15 per month for the standard plan.",
        )];

        let result = classify_memory_operation(
            "Claude costs $15 per month for the standard plan and includes priority support.",
            &existing,
        );

        assert_eq!(
            result,
            MemoryOperation::Update {
                target_file: "providers/claude.md".to_string(),
                target_section: "pricing".to_string(),
            }
        );
    }

    #[test]
    fn memory_classifier_novel_facts_return_add() {
        let existing = [fact(
            "providers/claude.md",
            "pricing",
            "Claude costs $15 per month for the standard plan.",
        )];

        let result = classify_memory_operation(
            "Hermes runs as a Python subprocess managed by Epistemos.",
            &existing,
        );

        assert_eq!(result, MemoryOperation::Add);
    }

    #[test]
    fn memory_classifier_prompt_stays_under_two_hundred_tokens() {
        let existing = fact(
            "providers/claude.md",
            "pricing",
            "Claude costs $15 per month for the standard plan and includes priority support.",
        );

        let prompt = build_classification_prompt(
            "Claude costs $20 per month for the standard plan and includes priority support.",
            &existing,
        );

        assert!(estimate_prompt_tokens(&prompt) < 200);
    }

    #[test]
    fn memory_classifier_routes_local_with_haiku_fallback() {
        assert_eq!(
            classification_dispatch(),
            RoutingDecision::LocalWithFallback {
                local: LocalTask::Classify,
                fallback: CloudProvider::ClaudeHaiku,
            }
        );
    }
}
