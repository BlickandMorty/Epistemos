//! TRACED-inspired reasoning trajectory metrics.
//!
//! Reference: TRACED (arXiv:2603.10384) — validates displacement and curvature
//! metrics for distinguishing correct reasoning from hallucination.
//!
//! Applied to agent tool call sequences (not model internals):
//! - High displacement + low curvature = efficient reasoning
//! - Low displacement + high curvature = hesitation loop
//! - High displacement + high curvature = exploration
//! - Low displacement + low curvature = stuck

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReasoningTrajectoryMetrics {
    /// Semantic distance from first tool call to final result (Jaccard proxy).
    pub displacement: f32,
    /// Total semantic distance traveled across all consecutive tool call pairs.
    pub path_length: f32,
    /// path_length / displacement. >4.0 = hesitation loop.
    pub curvature_ratio: f32,
    /// Number of repeated tool+args hash pairs.
    pub loop_count: u32,
    /// Number of tool calls that returned errors.
    pub error_count: u32,
    /// Total tool calls in session.
    pub total_calls: u32,
    /// displacement / total_calls — higher is more efficient.
    pub efficiency: f32,
    /// Overall quality classification.
    pub classification: TrajectoryClassification,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TrajectoryClassification {
    /// curvature < 2.0 AND loop_count == 0
    Efficient,
    /// curvature 2.0–4.0 AND displacement > 0.3
    Exploratory,
    /// curvature > 4.0 OR loop_count >= 3
    Hesitating,
    /// displacement < 0.1 AND total_calls > 3
    Stuck,
    /// error_count > total_calls / 2
    Failed,
}

impl TrajectoryClassification {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Efficient => "efficient",
            Self::Exploratory => "exploratory",
            Self::Hesitating => "hesitating",
            Self::Stuck => "stuck",
            Self::Failed => "failed",
        }
    }
}

/// Compute trajectory metrics from a completed agent session's tool call log.
///
/// Each tool call is a tuple of (name, args_json, result_text, is_error).
/// Distance proxy: bag-of-words Jaccard distance between consecutive result strings.
pub fn compute_trajectory_metrics(
    tool_calls: &[(String, String, String, bool)],
) -> ReasoningTrajectoryMetrics {
    let total_calls = tool_calls.len() as u32;

    if tool_calls.is_empty() {
        return ReasoningTrajectoryMetrics {
            displacement: 0.0,
            path_length: 0.0,
            curvature_ratio: 0.0,
            loop_count: 0,
            error_count: 0,
            total_calls: 0,
            efficiency: 0.0,
            classification: TrajectoryClassification::Stuck,
        };
    }

    // Loop detection: hash(name + args)
    let mut call_hashes: HashMap<u64, u32> = HashMap::new();
    for (name, args, _, _) in tool_calls {
        let hash = simple_hash(&format!("{name}:{args}"));
        *call_hashes.entry(hash).or_insert(0) += 1;
    }
    let loop_count: u32 = call_hashes
        .values()
        .filter(|&&count| count >= 2)
        .map(|c| c - 1)
        .sum();

    // Error count
    let error_count = tool_calls.iter().filter(|(_, _, _, err)| *err).count() as u32;

    // Compute pairwise Jaccard distances between consecutive result texts
    let mut path_length: f32 = 0.0;
    for i in 1..tool_calls.len() {
        let dist = jaccard_distance(&tool_calls[i - 1].2, &tool_calls[i].2);
        path_length += dist;
    }

    // Displacement: distance between first and last
    let displacement = if tool_calls.len() >= 2 {
        jaccard_distance(&tool_calls[0].2, &tool_calls[tool_calls.len() - 1].2)
    } else {
        0.5 // single call — assume moderate displacement
    };

    let curvature_ratio = if displacement > 0.001 {
        path_length / displacement
    } else {
        f32::MAX
    };

    let efficiency = if total_calls > 0 {
        displacement / total_calls as f32
    } else {
        0.0
    };

    // Classify — order matters: check loops before stuck (loops = hesitating, not stuck)
    let classification = if error_count > total_calls / 2 {
        TrajectoryClassification::Failed
    } else if curvature_ratio > 4.0 || loop_count >= 3 {
        TrajectoryClassification::Hesitating
    } else if displacement < 0.1 && total_calls > 3 {
        TrajectoryClassification::Stuck
    } else if curvature_ratio > 2.0 && displacement > 0.3 {
        TrajectoryClassification::Exploratory
    } else {
        TrajectoryClassification::Efficient
    };

    ReasoningTrajectoryMetrics {
        displacement,
        path_length,
        curvature_ratio,
        loop_count,
        error_count,
        total_calls,
        efficiency,
        classification,
    }
}

/// Simple bag-of-words Jaccard distance between two texts.
/// Returns 0.0 for identical texts, 1.0 for completely disjoint.
fn jaccard_distance(a: &str, b: &str) -> f32 {
    let words_a: std::collections::HashSet<&str> = a.split_whitespace().collect();
    let words_b: std::collections::HashSet<&str> = b.split_whitespace().collect();

    if words_a.is_empty() && words_b.is_empty() {
        return 0.0;
    }

    let intersection = words_a.intersection(&words_b).count();
    let union = words_a.union(&words_b).count();

    if union == 0 {
        return 0.0;
    }

    1.0 - (intersection as f32 / union as f32)
}

/// Simple non-cryptographic hash for loop detection.
fn simple_hash(s: &str) -> u64 {
    let mut hash: u64 = 5381;
    for byte in s.bytes() {
        hash = hash.wrapping_mul(33).wrapping_add(byte as u64);
    }
    hash
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_calls_classify_as_stuck() {
        let metrics = compute_trajectory_metrics(&[]);
        assert_eq!(metrics.classification, TrajectoryClassification::Stuck);
        assert_eq!(metrics.total_calls, 0);
    }

    #[test]
    fn single_successful_call_is_efficient() {
        let calls = vec![(
            "vault_search".into(),
            "query".into(),
            "found 3 results about MOHAWK".into(),
            false,
        )];
        let metrics = compute_trajectory_metrics(&calls);
        assert_eq!(metrics.classification, TrajectoryClassification::Efficient);
    }

    #[test]
    fn repeated_identical_calls_detect_loops() {
        let calls = vec![
            (
                "vault_search".into(),
                "query".into(),
                "result A".into(),
                false,
            ),
            (
                "vault_search".into(),
                "query".into(),
                "result A".into(),
                false,
            ),
            (
                "vault_search".into(),
                "query".into(),
                "result A".into(),
                false,
            ),
            (
                "vault_search".into(),
                "query".into(),
                "result A".into(),
                false,
            ),
        ];
        let metrics = compute_trajectory_metrics(&calls);
        assert!(metrics.loop_count >= 3);
        assert_eq!(metrics.classification, TrajectoryClassification::Hesitating);
    }

    #[test]
    fn diverse_calls_with_progress_are_efficient() {
        let calls = vec![
            (
                "vault_search".into(),
                "MOHAWK".into(),
                "found training pipeline documentation".into(),
                false,
            ),
            (
                "vault_read".into(),
                "MOHAWK/README.md".into(),
                "full content of training pipeline with 15 categories".into(),
                false,
            ),
            (
                "vault_read".into(),
                "MOHAWK/eval.jsonl".into(),
                "evaluation results showing 92% accuracy on benchmark".into(),
                false,
            ),
        ];
        let metrics = compute_trajectory_metrics(&calls);
        assert_eq!(metrics.loop_count, 0);
        assert!(metrics.displacement > 0.3);
        // Should be Efficient or Exploratory
        assert!(
            metrics.classification == TrajectoryClassification::Efficient
                || metrics.classification == TrajectoryClassification::Exploratory,
            "expected efficient/exploratory, got {:?}",
            metrics.classification
        );
    }

    #[test]
    fn mostly_errors_classify_as_failed() {
        let calls = vec![
            ("bash".into(), "ls".into(), "error".into(), true),
            ("bash".into(), "cat".into(), "error".into(), true),
            ("bash".into(), "pwd".into(), "error".into(), true),
            ("vault_search".into(), "q".into(), "ok".into(), false),
        ];
        let metrics = compute_trajectory_metrics(&calls);
        assert_eq!(metrics.classification, TrajectoryClassification::Failed);
    }
}
