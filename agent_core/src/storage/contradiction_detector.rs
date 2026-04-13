//! Contradiction Detector — Surfaces conflicts between new and existing facts.
//!
//! Extracts contradiction detection logic from memory_classifier into a standalone
//! module that returns ALL contradictions (not just the strongest), along with
//! conflict type and confidence scores.
//!
//! Used by the vault write pipeline to surface "conflict cards" to the user
//! when new facts contradict existing knowledge.

use serde::{Deserialize, Serialize};

use super::memory_classifier::VaultFact;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Type of contradiction detected between two facts.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum ConflictType {
    /// Numeric values differ (e.g., "costs $15" vs "costs $20")
    Numeric,
    /// Boolean/negation conflict (e.g., "enabled" vs "not enabled")
    Boolean,
    /// Antonym conflict (e.g., "online" vs "offline")
    Antonym,
    /// Semantic reversal detected via embedding divergence
    SemanticReversal,
}

/// A detected contradiction between an incoming fact and an existing one.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Contradiction {
    pub incoming_fact: String,
    pub existing_fact: ExistingFactRef,
    pub conflict_type: ConflictType,
    /// Confidence score (0.0 to 1.0). Higher = more certain conflict.
    pub confidence: f64,
}

/// Reference to the existing fact that conflicts.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExistingFactRef {
    pub file_path: String,
    pub section: String,
    pub content: String,
}

// ---------------------------------------------------------------------------
// Detection Logic
// ---------------------------------------------------------------------------

/// Detect all contradictions between an incoming fact and a set of existing facts.
///
/// Returns an empty vec if no contradictions are found. Each contradiction
/// includes the conflict type and a confidence score.
pub fn detect_contradictions(incoming: &str, existing_facts: &[VaultFact]) -> Vec<Contradiction> {
    let incoming_normalized = normalize(incoming);
    if incoming_normalized.is_empty() {
        return Vec::new();
    }

    let mut contradictions = Vec::new();

    for fact in existing_facts {
        let existing_normalized = normalize(&fact.content);
        if existing_normalized.is_empty() {
            continue;
        }

        // Skip if facts are about completely different topics (low overlap)
        if !topics_overlap(&incoming_normalized, &existing_normalized) {
            continue;
        }

        // Check each conflict type
        if has_numeric_conflict(incoming, &fact.content) {
            contradictions.push(Contradiction {
                incoming_fact: incoming.to_string(),
                existing_fact: ExistingFactRef {
                    file_path: fact.file_path.clone(),
                    section: fact.section.clone(),
                    content: fact.content.clone(),
                },
                conflict_type: ConflictType::Numeric,
                confidence: 0.9,
            });
        } else if has_boolean_conflict(incoming, &fact.content) {
            contradictions.push(Contradiction {
                incoming_fact: incoming.to_string(),
                existing_fact: ExistingFactRef {
                    file_path: fact.file_path.clone(),
                    section: fact.section.clone(),
                    content: fact.content.clone(),
                },
                conflict_type: ConflictType::Boolean,
                confidence: 0.85,
            });
        } else if has_antonym_conflict(incoming, &fact.content) {
            contradictions.push(Contradiction {
                incoming_fact: incoming.to_string(),
                existing_fact: ExistingFactRef {
                    file_path: fact.file_path.clone(),
                    section: fact.section.clone(),
                    content: fact.content.clone(),
                },
                conflict_type: ConflictType::Antonym,
                confidence: 0.8,
            });
        }
    }

    // Sort by confidence descending
    contradictions.sort_by(|a, b| {
        b.confidence
            .partial_cmp(&a.confidence)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    contradictions
}

// ---------------------------------------------------------------------------
// Conflict Detection Helpers (reimplemented to avoid circular dependency)
// ---------------------------------------------------------------------------

fn normalize(text: &str) -> String {
    text.to_lowercase()
        .chars()
        .filter(|c| c.is_alphanumeric() || c.is_whitespace())
        .collect::<String>()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

/// Check if two normalized texts share enough words to be about the same topic.
fn topics_overlap(left: &str, right: &str) -> bool {
    let left_words: std::collections::HashSet<&str> = left.split_whitespace().collect();
    let right_words: std::collections::HashSet<&str> = right.split_whitespace().collect();
    let overlap = left_words.intersection(&right_words).count();
    let min_len = left_words.len().min(right_words.len()).max(1);
    // Require at least 30% word overlap
    (overlap as f64 / min_len as f64) >= 0.3
}

fn extract_numeric_tokens(text: &str) -> Vec<String> {
    text.split_whitespace()
        .filter(|word| {
            let stripped = word
                .trim_start_matches('$')
                .trim_end_matches('%')
                .trim_end_matches(',');
            stripped.parse::<f64>().is_ok()
        })
        .map(|word| word.to_string())
        .collect()
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
    let normalized = normalize(text);
    let negation_words = [
        "not", "no", "never", "none", "neither", "without", "cannot", "cant", "dont", "doesnt",
        "isnt", "arent",
    ];
    negation_words.iter().any(|word| normalized.contains(word))
}

fn has_antonym_conflict(left: &str, right: &str) -> bool {
    let left_norm = normalize(left);
    let right_norm = normalize(right);
    const ANTONYM_PAIRS: [(&str, &str); 8] = [
        ("enabled", "disabled"),
        ("online", "offline"),
        ("active", "inactive"),
        ("true", "false"),
        ("yes", "no"),
        ("allow", "deny"),
        ("accept", "reject"),
        ("include", "exclude"),
    ];

    for (a, b) in &ANTONYM_PAIRS {
        let left_has_a = left_norm.contains(a);
        let left_has_b = left_norm.contains(b);
        let right_has_a = right_norm.contains(a);
        let right_has_b = right_norm.contains(b);

        if (left_has_a && right_has_b) || (left_has_b && right_has_a) {
            return true;
        }
    }
    false
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn make_fact(content: &str) -> VaultFact {
        VaultFact::new(
            "test.md".to_string(),
            "section".to_string(),
            content.to_string(),
            1.0,
            chrono::Utc::now(),
        )
    }

    #[test]
    fn detect_numeric_contradiction() {
        let facts = vec![make_fact("The API costs $15 per month")];
        let contradictions = detect_contradictions("The API costs $20 per month", &facts);
        assert_eq!(contradictions.len(), 1);
        assert_eq!(contradictions[0].conflict_type, ConflictType::Numeric);
        assert!(contradictions[0].confidence >= 0.8);
    }

    #[test]
    fn detect_boolean_contradiction() {
        let facts = vec![make_fact("Caching is not enabled for this endpoint")];
        let contradictions = detect_contradictions("Caching is enabled for this endpoint", &facts);
        assert_eq!(contradictions.len(), 1);
        assert_eq!(contradictions[0].conflict_type, ConflictType::Boolean);
    }

    #[test]
    fn detect_antonym_contradiction() {
        let facts = vec![make_fact("The service is currently online")];
        let contradictions = detect_contradictions("The service is currently offline", &facts);
        assert_eq!(contradictions.len(), 1);
        assert_eq!(contradictions[0].conflict_type, ConflictType::Antonym);
    }

    #[test]
    fn no_contradiction_unrelated_facts() {
        let facts = vec![make_fact("The sky is blue")];
        let contradictions = detect_contradictions("Rust uses ownership for memory safety", &facts);
        assert!(contradictions.is_empty());
    }

    #[test]
    fn no_contradiction_same_fact() {
        let facts = vec![make_fact("The API costs $15 per month")];
        let contradictions = detect_contradictions("The API costs $15 per month", &facts);
        assert!(contradictions.is_empty());
    }

    #[test]
    fn multiple_contradictions_sorted_by_confidence() {
        let facts = vec![
            make_fact("The service is online and costs $10"),
            make_fact("Caching is not enabled"),
        ];
        let contradictions = detect_contradictions(
            "The service is offline and costs $20 and caching is enabled",
            &facts,
        );
        assert!(contradictions.len() >= 1);
        // Should be sorted by confidence (highest first)
        for window in contradictions.windows(2) {
            assert!(window[0].confidence >= window[1].confidence);
        }
    }

    #[test]
    fn empty_incoming_returns_empty() {
        let facts = vec![make_fact("Some fact")];
        assert!(detect_contradictions("", &facts).is_empty());
    }

    #[test]
    fn empty_existing_returns_empty() {
        assert!(detect_contradictions("Some fact", &[]).is_empty());
    }
}
