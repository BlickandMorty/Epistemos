//! Context Loader — 5-Tier Memory Injection for Agent Sessions
//!
//! Assembles a structured "wake-up context" injected at session start:
//! - L4 Identity: SOUL.md (model persona, always injected)
//! - L3 Facts: memory/decisions.md + knowledge.md (accumulated knowledge)
//! - L2 Patterns: skill descriptions from skills_registry (lazy-loaded)
//! - L1 Episodes: semantically relevant prior session summaries
//! - L0 Working: live conversation (managed by the agent loop, not here)
//!
//! Budget allocation ensures local models with small context windows are
//! never overwhelmed: L1 is truncated first, then L2, L3, and L4 last.

use std::path::Path;

use crate::skill_router::SkillRouter;
use crate::storage::hyperbolic_topology::{
    build_topology, should_pierce_blanket, VaultNodeMetrics,
};
use crate::storage::vault::VaultBackend;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// A single layer of injected context.
#[derive(Debug, Clone)]
pub struct ContextLayer {
    /// Label for the layer (e.g., "L4:identity", "L3:facts")
    pub label: String,
    /// The actual content to inject into the system prompt.
    pub content: String,
    /// Estimated token count (word-based heuristic).
    pub token_estimate: usize,
}

/// The assembled session context ready for system prompt injection.
#[derive(Debug, Clone)]
pub struct SessionContext {
    pub layers: Vec<ContextLayer>,
    pub total_token_estimate: usize,
}

impl SessionContext {
    /// Format all layers as an XML block for system prompt injection.
    pub fn to_xml(&self) -> String {
        if self.layers.is_empty() {
            return String::new();
        }

        let mut parts = Vec::with_capacity(self.layers.len() + 2);
        parts.push("<session-context>".to_string());

        for layer in &self.layers {
            if layer.content.is_empty() {
                continue;
            }
            let tag = layer.label.replace(':', "_").replace(' ', "_");
            parts.push(format!("<{tag}>\n{}\n</{tag}>", layer.content.trim()));
        }

        parts.push("</session-context>".to_string());
        parts.join("\n")
    }
}

// ---------------------------------------------------------------------------
// Token Estimation
// ---------------------------------------------------------------------------

/// Rough token estimate: ~1.3 tokens per whitespace-separated word.
fn estimate_tokens(text: &str) -> usize {
    let words = text.split_whitespace().count();
    (words as f64 * 1.3) as usize
}

/// Truncate content to fit within a token budget.
/// Uses the same heuristic as `estimate_tokens` (1.3 tokens per word) for consistency.
fn truncate_to_budget(content: &str, max_tokens: usize) -> String {
    if estimate_tokens(content) <= max_tokens {
        return content.to_string();
    }

    // Truncate at word boundaries using consistent 1.3 tokens/word heuristic
    let max_words = (max_tokens as f64 / 1.3) as usize;
    let result: String = content
        .split_whitespace()
        .take(max_words)
        .collect::<Vec<_>>()
        .join(" ");

    if result.len() < content.len() {
        format!("{result}\n\n[...truncated to fit context budget]")
    } else {
        result
    }
}

// ---------------------------------------------------------------------------
// Context Loading
// ---------------------------------------------------------------------------

/// Default token budgets per tier (within a max_context_tokens envelope).
struct TierBudgets {
    l4_identity: usize,
    l3_facts: usize,
    l2_skills: usize,
    l1_episodes: usize,
}

impl TierBudgets {
    fn for_max_tokens(max_context_tokens: usize) -> Self {
        // Use at most 3% of total context for injected memory.
        // For 128K context: ~3800 tokens. For 4K context: ~120 tokens.
        // This prevents small local models from being overwhelmed.
        let budget = (max_context_tokens * 3 / 100).min(4200);

        if budget < 200 {
            // Tiny context (< ~7K) — inject only identity, skip everything else
            return Self {
                l4_identity: budget.min(50),
                l3_facts: 0,
                l2_skills: 0,
                l1_episodes: 0,
            };
        }

        Self {
            l4_identity: budget * 5 / 100,  // ~5%
            l3_facts: budget * 48 / 100,    // ~48%
            l2_skills: budget * 12 / 100,   // ~12%
            l1_episodes: budget * 35 / 100, // ~35%
        }
    }
}

/// Load the full 5-tier session context from the vault.
///
/// This is called once at session start, before the first API call.
pub async fn load_session_context(
    vault: &dyn VaultBackend,
    vault_root: &Path,
    objective: &str,
    max_context_tokens: usize,
) -> SessionContext {
    let budgets = TierBudgets::for_max_tokens(max_context_tokens);
    let mut layers = Vec::with_capacity(4);

    // L4: Identity (SOUL.md)
    let l4 = load_identity(vault, &budgets).await;
    if !l4.content.is_empty() {
        layers.push(l4);
    }

    // L3.5: Neocortex Gist (fluid awareness from SSM — everything beyond KV cache)
    let neocortex_gist = crate::neocortex::global_neocortex().generate_gist(200);
    if let Some(gist) = neocortex_gist {
        layers.push(ContextLayer {
            label: "L3_5_neocortex".to_string(),
            content: format!(
                "### Neocortex Awareness (from {} absorbed contexts)\n{}",
                gist.based_on_absorptions, gist.content
            ),
            token_estimate: estimate_tokens(&gist.content),
        });
    }

    // L3.25: Working Memory (resume from prior session if available)
    // Check for .epistemos/sessions/*/working-memory.md with status: running
    let wm_dir = vault_root.join(".epistemos/sessions");
    if wm_dir.exists() {
        if let Ok(entries) = std::fs::read_dir(&wm_dir) {
            for entry in entries.flatten() {
                let wm_path = entry.path().join("working-memory.md");
                if wm_path.exists() {
                    if let Ok(content) = std::fs::read_to_string(&wm_path) {
                        if content.contains("status: running") {
                            let truncated = truncate_to_budget(&content, budgets.l3_facts / 3);
                            let token_estimate = estimate_tokens(&truncated);
                            layers.push(ContextLayer {
                                label: "L3_25_working_memory".to_string(),
                                content: format!("### Active Working Memory (resuming prior session)\n{truncated}"),
                                token_estimate,
                            });
                            break; // only inject the most recent running session
                        }
                    }
                }
            }
        }
    }

    // L3: Facts (memory/decisions.md + knowledge.md)
    let l3 = load_facts(vault, &budgets).await;
    if !l3.content.is_empty() {
        layers.push(l3);
    }

    // L2.5: Spatial awareness (only pierce blankets that match the objective)
    let topology = load_topology_awareness(vault_root, objective, &budgets);
    if !topology.content.is_empty() {
        layers.push(topology);
    }

    // L2: Patterns (skill descriptions)
    let l2 = load_skill_descriptions(vault_root, objective, &budgets);
    if !l2.content.is_empty() {
        layers.push(l2);
    }

    // L1: Episodes (relevant prior session summaries)
    let l1 = load_episodes(vault, objective, &budgets).await;
    if !l1.content.is_empty() {
        layers.push(l1);
    }

    let total_token_estimate = layers.iter().map(|l| l.token_estimate).sum();

    SessionContext {
        layers,
        total_token_estimate,
    }
}

/// L4: Load SOUL.md (model identity/persona).
async fn load_identity(vault: &dyn VaultBackend, budgets: &TierBudgets) -> ContextLayer {
    let content = vault.read("SOUL.md").await.unwrap_or_default();
    let truncated = truncate_to_budget(&content, budgets.l4_identity);
    let token_estimate = estimate_tokens(&truncated);
    ContextLayer {
        label: "L4_identity".to_string(),
        content: truncated,
        token_estimate,
    }
}

/// L3: Load accumulated facts from memory/decisions.md and memory/knowledge.md.
async fn load_facts(vault: &dyn VaultBackend, budgets: &TierBudgets) -> ContextLayer {
    let decisions = vault.read("memory/decisions.md").await.unwrap_or_default();
    let knowledge = vault.read("memory/knowledge.md").await.unwrap_or_default();

    let combined = if decisions.is_empty() && knowledge.is_empty() {
        String::new()
    } else {
        let mut parts = Vec::new();
        if !decisions.is_empty() {
            parts.push(format!("### Key Decisions\n{decisions}"));
        }
        if !knowledge.is_empty() {
            parts.push(format!("### Accumulated Knowledge\n{knowledge}"));
        }
        parts.join("\n\n")
    };

    let truncated = truncate_to_budget(&combined, budgets.l3_facts);
    let token_estimate = estimate_tokens(&truncated);
    ContextLayer {
        label: "L3_facts".to_string(),
        content: truncated,
        token_estimate,
    }
}

/// L2.5: Load the small set of directories whose Markov Blankets should be pierced.
fn load_topology_awareness(
    vault_root: &Path,
    objective: &str,
    budgets: &TierBudgets,
) -> ContextLayer {
    let topology = match build_topology(vault_root) {
        Ok(topology) => topology,
        Err(_) => {
            return ContextLayer {
                label: "L2_5_topology".to_string(),
                content: String::new(),
                token_estimate: 0,
            };
        }
    };

    let mut candidates: Vec<(&VaultNodeMetrics, f64)> = topology
        .nodes
        .iter()
        .filter(|node| node.is_directory)
        .filter_map(|node| {
            let (should_pierce, confidence) = should_pierce_blanket(objective, node);
            should_pierce.then_some((node, confidence))
        })
        .collect();

    if candidates.is_empty() {
        return ContextLayer {
            label: "L2_5_topology".to_string(),
            content: String::new(),
            token_estimate: 0,
        };
    }

    candidates.sort_by(|(lhs, lhs_conf), (rhs, rhs_conf)| {
        rhs_conf
            .partial_cmp(lhs_conf)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| {
                rhs.gravity
                    .partial_cmp(&lhs.gravity)
                    .unwrap_or(std::cmp::Ordering::Equal)
            })
    });

    let lines: Vec<String> = candidates
        .iter()
        .take(6)
        .map(|(node, confidence)| {
            format!(
                "- {} ({:.0}% pierce confidence): {}",
                node.path,
                confidence * 100.0,
                node.blanket_summary.as_deref().unwrap_or("(no summary)")
            )
        })
        .collect();

    let content = format!("### Relevant Vault Regions\n{}", lines.join("\n"));
    let truncated = truncate_to_budget(&content, budgets.l2_skills);
    let token_estimate = estimate_tokens(&truncated);
    ContextLayer {
        label: "L2_5_topology".to_string(),
        content: truncated,
        token_estimate,
    }
}

/// L2: Load skill descriptions (lazy — descriptions only, not full bodies).
fn load_skill_descriptions(
    vault_root: &Path,
    objective: &str,
    budgets: &TierBudgets,
) -> ContextLayer {
    let router = SkillRouter::load(vault_root);
    let matches = router.route(objective, 5);

    if matches.is_empty() {
        return ContextLayer {
            label: "L2_skills".to_string(),
            content: String::new(),
            token_estimate: 0,
        };
    }

    // Inject full body for top match (highest relevance), descriptions for rest.
    // This ensures the agent actually follows the best-matching skill's procedure.
    let mut parts = Vec::with_capacity(matches.len());
    for (i, m) in matches.iter().enumerate() {
        if i == 0 && m.score > 0.3 && !m.skill.body.is_empty() {
            // Top match with high confidence: inject full skill body
            parts.push(format!(
                "<skill name=\"{}\" relevance=\"{:.0}%\">\n{}\n</skill>",
                m.skill.name,
                m.score * 100.0,
                m.skill.body
            ));
        } else {
            // Lower matches: description only (save tokens)
            parts.push(format!(
                "- **{}** (relevance: {:.0}%): {}",
                m.skill.name,
                m.score * 100.0,
                m.skill.description
            ));
        }
    }

    let content = format!("### Available Skills\n{}", parts.join("\n"));
    let truncated = truncate_to_budget(&content, budgets.l2_skills);
    let token_estimate = estimate_tokens(&truncated);
    ContextLayer {
        label: "L2_skills".to_string(),
        content: truncated,
        token_estimate,
    }
}

/// L1: Load semantically relevant prior session summaries.
async fn load_episodes(
    vault: &dyn VaultBackend,
    objective: &str,
    budgets: &TierBudgets,
) -> ContextLayer {
    // Search for relevant session summaries
    let results = vault
        .hybrid_search(objective, 3, &[])
        .await
        .unwrap_or_default();

    // Filter to only summary.md files from sessions
    let summaries: Vec<&crate::storage::vault::SearchResult> = results
        .iter()
        .filter(|r| r.path.contains("sessions/") && r.path.ends_with("summary.md"))
        .collect();

    if summaries.is_empty() {
        return ContextLayer {
            label: "L1_episodes".to_string(),
            content: String::new(),
            token_estimate: 0,
        };
    }

    let episodes: Vec<String> = summaries
        .iter()
        .map(|s| {
            format!(
                "#### Prior Session: {}\n(relevance: {:.0}%)\n{}",
                s.path,
                s.score * 100.0,
                s.excerpt
            )
        })
        .collect();

    let content = format!("### Relevant Prior Sessions\n{}", episodes.join("\n\n"));
    let truncated = truncate_to_budget(&content, budgets.l1_episodes);
    let token_estimate = estimate_tokens(&truncated);
    ContextLayer {
        label: "L1_episodes".to_string(),
        content: truncated,
        token_estimate,
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use async_trait::async_trait;
    use tempfile::TempDir;

    use crate::storage::vault::SearchResult;

    #[test]
    fn estimate_tokens_basic() {
        assert_eq!(estimate_tokens("hello world"), 2); // 2 words * 1.3 = 2.6 → 2
        assert_eq!(estimate_tokens(""), 0);
        let long = "word ".repeat(100);
        assert!(estimate_tokens(&long) >= 100);
    }

    #[test]
    fn truncate_to_budget_short() {
        let content = "short text";
        let result = truncate_to_budget(content, 100);
        assert_eq!(result, "short text");
    }

    #[test]
    fn truncate_to_budget_overflow() {
        let content = "word ".repeat(1000);
        let result = truncate_to_budget(&content, 10);
        // The truncation marker adds a few tokens; core content should be ≤ budget
        let core = result.split("[...truncated").next().unwrap_or(&result);
        assert!(
            estimate_tokens(core) <= 10,
            "truncation overshot: {}",
            estimate_tokens(core)
        );
        assert!(result.contains("[...truncated"));
    }

    #[test]
    fn session_context_to_xml_empty() {
        let ctx = SessionContext {
            layers: Vec::new(),
            total_token_estimate: 0,
        };
        assert_eq!(ctx.to_xml(), "");
    }

    #[test]
    fn session_context_to_xml_with_layers() {
        let ctx = SessionContext {
            layers: vec![
                ContextLayer {
                    label: "L4_identity".to_string(),
                    content: "I am Epistemos.".to_string(),
                    token_estimate: 4,
                },
                ContextLayer {
                    label: "L3_facts".to_string(),
                    content: "User prefers concise answers.".to_string(),
                    token_estimate: 5,
                },
            ],
            total_token_estimate: 9,
        };
        let xml = ctx.to_xml();
        assert!(xml.contains("<session-context>"));
        assert!(xml.contains("<L4_identity>"));
        assert!(xml.contains("I am Epistemos."));
        assert!(xml.contains("<L3_facts>"));
        assert!(xml.contains("</session-context>"));
    }

    #[test]
    fn tier_budgets_large_context() {
        // 128K context → 3% = ~3840 tokens budget
        let budgets = TierBudgets::for_max_tokens(128_000);
        let total =
            budgets.l4_identity + budgets.l3_facts + budgets.l2_skills + budgets.l1_episodes;
        assert!(total <= 4200, "total={total} exceeds 4200");
        assert!(budgets.l4_identity > 0);
        assert!(budgets.l3_facts > 0);
    }

    #[test]
    fn tier_budgets_small_context_minimal() {
        // 4K context → 3% = ~120 tokens → tiny budget, identity only
        let budgets = TierBudgets::for_max_tokens(4000);
        assert!(budgets.l4_identity <= 50);
        // Small context: facts/skills/episodes should be zero
        assert_eq!(budgets.l3_facts, 0);
        assert_eq!(budgets.l2_skills, 0);
        assert_eq!(budgets.l1_episodes, 0);
    }

    #[test]
    fn tier_budgets_medium_context() {
        // 32K context → 3% = 960 tokens → moderate budget
        let budgets = TierBudgets::for_max_tokens(32_000);
        let total =
            budgets.l4_identity + budgets.l3_facts + budgets.l2_skills + budgets.l1_episodes;
        assert!(total > 0 && total <= 1000);
        assert!(budgets.l3_facts > budgets.l4_identity); // facts gets the largest share
    }

    #[test]
    fn topology_awareness_prefers_matching_blankets() {
        let tmp = TempDir::new().unwrap();
        let project_dir = tmp.path().join("ProjectAlpha");
        std::fs::create_dir_all(&project_dir).unwrap();
        std::fs::write(project_dir.join("alpha.md"), "# alpha").unwrap();
        std::fs::write(project_dir.join("notes.md"), "# notes").unwrap();

        let budgets = TierBudgets::for_max_tokens(8_000);
        let layer = load_topology_awareness(tmp.path(), "alpha.md", &budgets);

        assert!(layer.content.contains("ProjectAlpha"));
        assert!(layer.content.contains("pierce confidence"));
    }

    struct EmptyVault;

    #[async_trait]
    impl VaultBackend for EmptyVault {
        async fn hybrid_search(
            &self,
            _query: &str,
            _limit: usize,
            _tag_filter: &[String],
        ) -> Result<Vec<SearchResult>, crate::storage::vault::VaultError> {
            Ok(Vec::new())
        }

        async fn read(&self, _path: &str) -> Result<String, crate::storage::vault::VaultError> {
            Ok(String::new())
        }

        async fn write(
            &self,
            _path: &str,
            _content: &str,
            _tags: Option<&[String]>,
            _append: bool,
        ) -> Result<(), crate::storage::vault::VaultError> {
            Ok(())
        }

        async fn list(
            &self,
            _path_prefix: &str,
        ) -> Result<Vec<String>, crate::storage::vault::VaultError> {
            Ok(Vec::new())
        }

        async fn exists(&self, _path: &str) -> Result<bool, crate::storage::vault::VaultError> {
            Ok(false)
        }

        async fn delete(&self, _path: &str) -> Result<bool, crate::storage::vault::VaultError> {
            Ok(false)
        }
    }

    #[tokio::test]
    async fn session_context_includes_topology_layer_when_blanket_matches() {
        let tmp = TempDir::new().unwrap();
        let project_dir = tmp.path().join("ProjectAlpha");
        std::fs::create_dir_all(&project_dir).unwrap();
        std::fs::write(project_dir.join("alpha.md"), "# alpha").unwrap();

        let vault = EmptyVault;
        let context = load_session_context(&vault, tmp.path(), "alpha.md", 8_000).await;
        let xml = context.to_xml();

        assert!(xml.contains("Relevant Vault Regions"));
        assert!(xml.contains("ProjectAlpha"));
    }
}
