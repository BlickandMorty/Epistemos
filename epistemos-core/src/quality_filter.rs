#![allow(clippy::needless_range_loop)]

// Quality filter for synthetic training pairs.
// MinHash-based near-duplicate detection + text quality scoring.
// Used by QualityCurator.swift to complement its SHA-256 exact dedup.

use std::collections::HashSet;
use std::hash::{Hash, Hasher};

/// Result of deduplicating a batch of texts.
#[derive(Debug, Clone)]
pub struct DedupResult {
    /// Indices of texts to KEEP (not duplicates).
    pub keep_indices_json: String,
    /// Number of duplicates found.
    pub duplicate_count: u32,
    /// Number of unique texts.
    pub unique_count: u32,
}

/// Quality score for a single training pair.
#[derive(Debug, Clone)]
pub struct QualityScore {
    /// Overall score 0.0-1.0.
    pub score: f64,
    /// Whether the pair passes the quality threshold.
    pub passes: bool,
    /// Reason for failure (empty if passes).
    pub reason: String,
}

// ── MinHash Near-Duplicate Detection ──────────────────────────────────────────

const NUM_HASHES: usize = 128;
const SHINGLE_SIZE: usize = 3; // word-level 3-grams

/// Compute MinHash signature for a text.
fn minhash_signature(text: &str) -> Vec<u64> {
    let words: Vec<&str> = text.split_whitespace().collect();
    if words.len() < SHINGLE_SIZE {
        // Too short for shingling — use direct word hashes
        let mut sig = vec![u64::MAX; NUM_HASHES];
        for word in &words {
            for i in 0..NUM_HASHES {
                let h = hash_with_seed(word.as_bytes(), i as u64);
                sig[i] = sig[i].min(h);
            }
        }
        return sig;
    }

    let mut sig = vec![u64::MAX; NUM_HASHES];

    // Generate word-level shingles
    for window in words.windows(SHINGLE_SIZE) {
        let shingle = window.join(" ");
        for i in 0..NUM_HASHES {
            let h = hash_with_seed(shingle.as_bytes(), i as u64);
            sig[i] = sig[i].min(h);
        }
    }

    sig
}

/// Estimate Jaccard similarity from two MinHash signatures.
fn jaccard_similarity(sig_a: &[u64], sig_b: &[u64]) -> f64 {
    let matches = sig_a
        .iter()
        .zip(sig_b.iter())
        .filter(|(a, b)| a == b)
        .count();
    matches as f64 / sig_a.len() as f64
}

/// Hash bytes with a seed using FNV-1a variant.
fn hash_with_seed(data: &[u8], seed: u64) -> u64 {
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    seed.hash(&mut hasher);
    data.hash(&mut hasher);
    hasher.finish()
}

/// Deduplicate a list of texts using MinHash.
/// Returns indices of texts to keep (first occurrence of each near-duplicate group).
/// `threshold` is the Jaccard similarity above which two texts are considered duplicates (0.0-1.0).
pub fn minhash_dedup(texts: &[String], threshold: f64) -> DedupResult {
    let n = texts.len();
    if n == 0 {
        return DedupResult {
            keep_indices_json: "[]".to_string(),
            duplicate_count: 0,
            unique_count: 0,
        };
    }

    // Compute signatures
    let signatures: Vec<Vec<u64>> = texts
        .iter()
        .map(|t| minhash_signature(&t.to_lowercase()))
        .collect();

    // Mark duplicates (greedy: first occurrence wins)
    let mut is_dup = vec![false; n];

    for i in 0..n {
        if is_dup[i] {
            continue;
        }
        for j in (i + 1)..n {
            if is_dup[j] {
                continue;
            }
            let sim = jaccard_similarity(&signatures[i], &signatures[j]);
            if sim >= threshold {
                is_dup[j] = true;
            }
        }
    }

    let keep_indices: Vec<usize> = (0..n).filter(|&i| !is_dup[i]).collect();
    let dup_count = n - keep_indices.len();

    DedupResult {
        keep_indices_json: serde_json::to_string(&keep_indices)
            .unwrap_or_else(|_| "[]".to_string()),
        duplicate_count: dup_count as u32,
        unique_count: keep_indices.len() as u32,
    }
}

// ── Quality Scoring ──────────────────────────────────────────────────────────

/// Score a training pair's quality based on text characteristics.
/// Returns a score 0.0-1.0 and whether it passes the threshold.
pub fn score_quality(instruction: &str, response: &str, min_score: f64) -> QualityScore {
    let mut score: f64 = 1.0;
    let mut reasons: Vec<&str> = Vec::new();

    // Instruction checks
    let inst_words = instruction.split_whitespace().count();
    if inst_words < 3 {
        score -= 0.4;
        reasons.push("instruction_too_short");
    }

    // Response checks
    let resp_words = response.split_whitespace().count();
    if resp_words < 10 {
        score -= 0.3;
        reasons.push("response_too_short");
    }

    // Repetition detection: check for repeated sentences
    let sentences: Vec<&str> = response
        .split('.')
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .collect();
    if sentences.len() >= 3 {
        let unique_sentences: HashSet<&str> = sentences.iter().copied().collect();
        let repetition_ratio = 1.0 - (unique_sentences.len() as f64 / sentences.len() as f64);
        if repetition_ratio > 0.5 {
            score -= 0.3;
            reasons.push("high_repetition");
        }
    }

    // Response should be longer than instruction (typical for QA pairs)
    if resp_words > 0 && inst_words > 0 {
        let ratio = resp_words as f64 / inst_words as f64;
        if ratio < 0.5 {
            score -= 0.2;
            reasons.push("response_shorter_than_instruction");
        }
    }

    // Check for common failure patterns
    let resp_lower = response.to_lowercase();
    let failure_patterns = [
        "i cannot",
        "i can't",
        "i'm unable",
        "as an ai",
        "i don't have access",
        "error:",
        "exception:",
    ];
    for pattern in &failure_patterns {
        if resp_lower.contains(pattern) {
            score -= 0.3;
            reasons.push("failure_pattern");
            break;
        }
    }

    score = score.clamp(0.0, 1.0);

    QualityScore {
        score,
        passes: score >= min_score,
        reason: reasons.join(","),
    }
}

/// UniFFI-callable: deduplicate texts using MinHash.
pub fn dedup_texts(texts_json: &str, threshold: f64) -> DedupResult {
    let texts: Vec<String> = serde_json::from_str(texts_json).unwrap_or_default();
    minhash_dedup(&texts, threshold)
}

/// UniFFI-callable: score a training pair.
pub fn score_training_pair(instruction: &str, response: &str, min_score: f64) -> QualityScore {
    score_quality(instruction, response, min_score)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_minhash_identical() {
        let texts = vec![
            "The quick brown fox jumps over the lazy dog".to_string(),
            "The quick brown fox jumps over the lazy dog".to_string(),
        ];
        let result = minhash_dedup(&texts, 0.8);
        assert_eq!(result.duplicate_count, 1);
        assert_eq!(result.unique_count, 1);
    }

    #[test]
    fn test_minhash_near_duplicate() {
        let texts = vec![
            "The quick brown fox jumps over the lazy dog near the river bank".to_string(),
            "The quick brown fox jumps over the lazy dog near the river".to_string(),
        ];
        let result = minhash_dedup(&texts, 0.7);
        // Very similar — should detect as duplicate
        assert_eq!(result.duplicate_count, 1);
    }

    #[test]
    fn test_minhash_different() {
        let texts = vec![
            "Quantum computing uses superposition and entanglement to process information differently".to_string(),
            "Machine learning models are trained on large datasets using gradient descent optimization".to_string(),
        ];
        let result = minhash_dedup(&texts, 0.8);
        assert_eq!(result.duplicate_count, 0);
        assert_eq!(result.unique_count, 2);
    }

    #[test]
    fn test_minhash_empty() {
        let result = minhash_dedup(&[], 0.8);
        assert_eq!(result.duplicate_count, 0);
        assert_eq!(result.unique_count, 0);
    }

    #[test]
    fn test_minhash_single() {
        let texts = vec!["Hello world".to_string()];
        let result = minhash_dedup(&texts, 0.8);
        assert_eq!(result.unique_count, 1);
        assert_eq!(result.duplicate_count, 0);
    }

    #[test]
    fn test_minhash_three_with_dup() {
        let texts = vec![
            "Alpha beta gamma delta epsilon".to_string(),
            "Completely different text about something else entirely".to_string(),
            "Alpha beta gamma delta epsilon zeta".to_string(), // near-dup of first
        ];
        let result = minhash_dedup(&texts, 0.6);
        assert_eq!(result.unique_count, 2);
        assert_eq!(result.duplicate_count, 1);
    }

    #[test]
    fn test_quality_good_pair() {
        let score = score_quality(
            "What is quantum error correction and why is it important?",
            "Quantum error correction (QEC) protects quantum information from decoherence and noise. \
             The threshold theorem proves that computation can be made reliable if the error rate is \
             below a certain threshold. Surface codes are the most promising approach, requiring only \
             nearest-neighbor qubit interactions on a 2D lattice.",
            0.5,
        );
        assert!(score.passes);
        assert!(score.score > 0.7);
    }

    #[test]
    fn test_quality_too_short() {
        let score = score_quality("Q?", "Short.", 0.5);
        assert!(!score.passes);
        assert!(score.reason.contains("too_short"));
    }

    #[test]
    fn test_quality_repetitive() {
        let score = score_quality(
            "What is X?",
            "X is good. X is good. X is good. X is good. X is good.",
            0.5,
        );
        assert!(score.score < 0.8);
        assert!(score.reason.contains("repetition"));
    }

    #[test]
    fn test_quality_failure_pattern() {
        let score = score_quality(
            "What is the meaning of life?",
            "As an AI language model, I cannot provide personal opinions on philosophical matters.",
            0.5,
        );
        assert!(score.reason.contains("failure_pattern"));
    }

    #[test]
    fn test_dedup_texts_ffi() {
        let json = r#"["hello world foo","hello world bar","completely different text"]"#;
        let result = dedup_texts(json, 0.8);
        assert!(result.unique_count >= 2);
    }

    #[test]
    fn test_score_pair_ffi() {
        let result = score_training_pair(
            "How does photosynthesis work?",
            "Photosynthesis is the process by which plants convert sunlight into chemical energy. \
             Chlorophyll in plant cells absorbs light energy which is used to convert carbon dioxide \
             and water into glucose and oxygen.",
            0.5,
        );
        assert!(result.passes);
        assert!(result.score > 0.7);
    }

    #[test]
    fn test_jaccard_identical_sigs() {
        let sig = vec![1u64, 2, 3, 4, 5];
        assert!((jaccard_similarity(&sig, &sig) - 1.0).abs() < 1e-10);
    }

    #[test]
    fn test_jaccard_different_sigs() {
        let sig_a = vec![1u64, 2, 3, 4, 5];
        let sig_b = vec![6u64, 7, 8, 9, 10];
        assert!((jaccard_similarity(&sig_a, &sig_b) - 0.0).abs() < 1e-10);
    }
}
