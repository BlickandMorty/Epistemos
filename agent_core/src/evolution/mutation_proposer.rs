//! Mutation Proposer — Proposes skill file improvements based on trace patterns.
//!
//! Given a skill's content and its trace analysis, proposes targeted mutations:
//! - FrequentRetries → add explicit error handling/retry guidance
//! - SlowExecution → add timeout guidance
//! - ConsistentFailure → add fallback instructions
//!
//! All mutations pass through constraint gates:
//! - Size gate: new content ≤ 15KB
//! - Semantic preservation: cosine similarity of descriptions > 0.80
//!
//! Mutations are NEVER auto-applied. They're proposed to the user for review.

use serde::{Deserialize, Serialize};

use crate::evolution::trace_analyzer::{ImprovementSignal, TracePattern};
use crate::storage::memory_classifier;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// A proposed mutation to a skill file.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SkillMutation {
    pub skill_name: String,
    pub version: String,
    pub rationale: String,
    pub old_content: String,
    pub new_content: String,
    pub constraint_check: ConstraintCheck,
}

/// Results of constraint gate validation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConstraintCheck {
    /// New content is ≤ 15KB.
    pub size_ok: bool,
    /// Description embedding hasn't drifted > 0.20 from original.
    pub semantic_preserved: bool,
    /// All gates pass.
    pub all_gates_pass: bool,
}

const MAX_SKILL_SIZE: usize = 15_360; // 15KB

// ---------------------------------------------------------------------------
// Mutation Logic
// ---------------------------------------------------------------------------

/// Propose a mutation to a skill based on its trace pattern.
///
/// Returns `None` if no improvement signals are actionable.
pub fn propose_mutation(
    skill_content: &str,
    trace_pattern: &TracePattern,
) -> Option<SkillMutation> {
    if trace_pattern.improvement_signals.is_empty() {
        return None;
    }

    let mut additions = Vec::new();

    for signal in &trace_pattern.improvement_signals {
        match signal {
            ImprovementSignal::FrequentRetries {
                step,
                avg_retry_count,
                ..
            } => {
                additions.push(format!(
                    "\n## Error Handling: {step}\n\
                     This step is retried {avg_retry_count:.1}x on average. \
                     If the first attempt fails:\n\
                     1. Check the error message for actionable details\n\
                     2. Adjust parameters before retrying\n\
                     3. After 2 failures, try an alternative approach\n\
                     4. After 3 failures, report the issue and move on\n"
                ));
            }
            ImprovementSignal::SlowExecution {
                step,
                avg_ms,
                p95_ms,
            } => {
                additions.push(format!(
                    "\n## Performance: {step}\n\
                     Average duration: {avg_ms:.0}ms (p95: {p95_ms:.0}ms). \
                     To improve speed:\n\
                     1. Use a timeout of {}ms for this step\n\
                     2. If slow, check if the input can be chunked\n\
                     3. Consider caching results for repeated queries\n",
                    (*avg_ms * 2.0) as u64
                ));
            }
            ImprovementSignal::ConsistentFailure {
                step,
                error_pattern,
                occurrence_count,
            } => {
                additions.push(format!(
                    "\n## Fallback: {step}\n\
                     This step fails {occurrence_count}x with: \"{error_pattern}\"\n\
                     When this error occurs:\n\
                     1. Do NOT retry with the same parameters\n\
                     2. Try the fallback approach described below\n\
                     3. If fallback also fails, skip this step and continue\n"
                ));
            }
            ImprovementSignal::UnusedCapability { capability } => {
                additions.push(format!(
                    "\n## Note: Unused Capability\n\
                     The '{capability}' step has never been invoked. \
                     Consider removing it to reduce complexity.\n"
                ));
            }
        }
    }

    if additions.is_empty() {
        return None;
    }

    // Build the new content by appending improvements
    let new_content = format!(
        "{}\n\n---\n\n# Auto-Generated Improvements (v2)\n\
         _Based on analysis of {} sessions ({} successes, {} failures)_\n{}",
        skill_content.trim(),
        trace_pattern.sessions_analyzed,
        trace_pattern.success_count,
        trace_pattern.failure_count,
        additions.join("\n")
    );

    // Determine version
    let version = if skill_content.contains("v2") {
        "v3".to_string()
    } else {
        "v2".to_string()
    };

    // Run constraint gates
    let constraint_check = check_constraints(skill_content, &new_content);

    let rationale = format!(
        "Based on {} improvement signals from {} sessions: {}",
        trace_pattern.improvement_signals.len(),
        trace_pattern.sessions_analyzed,
        trace_pattern
            .improvement_signals
            .iter()
            .map(signal_summary)
            .collect::<Vec<_>>()
            .join(", ")
    );

    Some(SkillMutation {
        skill_name: trace_pattern.skill_name.clone(),
        version,
        rationale,
        old_content: skill_content.to_string(),
        new_content,
        constraint_check,
    })
}

fn signal_summary(signal: &ImprovementSignal) -> String {
    match signal {
        ImprovementSignal::FrequentRetries { step, .. } => format!("retries on {step}"),
        ImprovementSignal::SlowExecution { step, avg_ms, .. } => {
            format!("slow {step} ({avg_ms:.0}ms)")
        }
        ImprovementSignal::ConsistentFailure { step, .. } => format!("failures in {step}"),
        ImprovementSignal::UnusedCapability { capability } => format!("unused {capability}"),
    }
}

// ---------------------------------------------------------------------------
// Constraint Gates
// ---------------------------------------------------------------------------

fn check_constraints(old_content: &str, new_content: &str) -> ConstraintCheck {
    let size_ok = new_content.len() <= MAX_SKILL_SIZE;

    // Semantic preservation: compare embeddings of the first paragraph (description)
    let old_desc = extract_description(old_content);
    let new_desc = extract_description(new_content);
    let old_embedding = memory_classifier::embed_text_public(&old_desc);
    let new_embedding = memory_classifier::embed_text_public(&new_desc);
    let similarity = memory_classifier::cosine_similarity_public(&old_embedding, &new_embedding);
    let semantic_preserved = similarity > 0.80;

    ConstraintCheck {
        size_ok,
        semantic_preserved,
        all_gates_pass: size_ok && semantic_preserved,
    }
}

/// Extract the first meaningful paragraph as a description.
fn extract_description(content: &str) -> String {
    // Skip frontmatter
    let body = if content.starts_with("---") {
        content[3..]
            .find("---")
            .map(|idx| &content[idx + 6..])
            .unwrap_or(content)
    } else {
        content
    };

    // Take first non-empty paragraph
    body.split("\n\n")
        .find(|p| !p.trim().is_empty() && !p.starts_with('#'))
        .unwrap_or("")
        .to_string()
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;

    fn make_pattern(signals: Vec<ImprovementSignal>) -> TracePattern {
        TracePattern {
            skill_name: "vault-search".to_string(),
            sessions_analyzed: 5,
            success_count: 10,
            failure_count: 3,
            avg_duration_ms: 200.0,
            improvement_signals: signals,
        }
    }

    #[test]
    fn no_signals_returns_none() {
        let result = propose_mutation("some skill content", &make_pattern(Vec::new()));
        assert!(result.is_none());
    }

    #[test]
    fn frequent_retries_adds_error_handling() {
        let signals = vec![ImprovementSignal::FrequentRetries {
            step: "web_fetch".to_string(),
            avg_retry_count: 3.5,
            sessions_affected: 3,
        }];
        let result = propose_mutation(
            "# Vault Search\n\nSearches the vault.",
            &make_pattern(signals),
        );
        assert!(result.is_some());
        let mutation = result.unwrap();
        assert!(mutation.new_content.contains("Error Handling: web_fetch"));
        assert!(mutation.new_content.contains("3.5x on average"));
    }

    #[test]
    fn slow_execution_adds_timeout() {
        let signals = vec![ImprovementSignal::SlowExecution {
            step: "api_call".to_string(),
            avg_ms: 6000.0,
            p95_ms: 12000.0,
        }];
        let result = propose_mutation("# Skill\n\nDoes things.", &make_pattern(signals));
        let mutation = result.unwrap();
        assert!(mutation.new_content.contains("Performance: api_call"));
        assert!(mutation.new_content.contains("12000ms"));
    }

    #[test]
    fn consistent_failure_adds_fallback() {
        let signals = vec![ImprovementSignal::ConsistentFailure {
            step: "auth".to_string(),
            error_pattern: "401 unauthorized".to_string(),
            occurrence_count: 5,
        }];
        let result = propose_mutation("# Skill\n\nAuth flow.", &make_pattern(signals));
        let mutation = result.unwrap();
        assert!(mutation.new_content.contains("Fallback: auth"));
        assert!(mutation.new_content.contains("401 unauthorized"));
    }

    #[test]
    fn size_gate_rejects_oversized() {
        let huge_content = "x".repeat(15_000);
        let signals = vec![
            ImprovementSignal::FrequentRetries {
                step: "s1".to_string(),
                avg_retry_count: 5.0,
                sessions_affected: 3,
            },
            ImprovementSignal::SlowExecution {
                step: "s2".to_string(),
                avg_ms: 10000.0,
                p95_ms: 20000.0,
            },
        ];
        let result = propose_mutation(&huge_content, &make_pattern(signals));
        let mutation = result.unwrap();
        assert!(!mutation.constraint_check.size_ok);
        assert!(!mutation.constraint_check.all_gates_pass);
    }

    #[test]
    fn version_increments() {
        let signals = vec![ImprovementSignal::UnusedCapability {
            capability: "notify".to_string(),
        }];
        let result = propose_mutation("# Skill v1", &make_pattern(signals.clone()));
        assert_eq!(result.unwrap().version, "v2");

        let result2 = propose_mutation("# Skill v2", &make_pattern(signals));
        assert_eq!(result2.unwrap().version, "v3");
    }
}
