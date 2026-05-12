#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CloudProvider {
    ClaudeHaiku,
    ClaudeSonnet,
    ClaudeOpus,
    GeminiFlash,
    GeminiPro,
    Perplexity,
    OpenAI,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum LocalTask {
    GhostWrite,
    Classify,
    Embed,
    SimpleTool { max_tools: u8 },
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CloudConfig {
    pub effort: String,
    pub tools: Vec<String>,
    pub enable_web_search: bool,
    pub enable_code_execution: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RoutingDecision {
    Local(LocalTask),
    LocalWithFallback {
        local: LocalTask,
        fallback: CloudProvider,
    },
    Cloud(CloudProvider, CloudConfig),
}

#[derive(Debug, Clone, PartialEq)]
pub struct ClassificationResult {
    pub complexity: f32,
    pub tool_count_estimate: u8,
    pub requires_current_info: bool,
    pub privacy_sensitive: bool,
    pub shell_required: bool,
    pub research_related: bool,
}

#[derive(Debug, Clone, Copy, Default)]
pub struct HeuristicClassifier;

impl HeuristicClassifier {
    pub fn classify(&self, objective: &str) -> ClassificationResult {
        let normalized = objective.to_lowercase();
        let word_count = normalized.split_whitespace().count() as f32;
        let char_count = objective.len();

        // Base complexity from word count
        let mut complexity = (word_count / 40.0).clamp(0.05, 1.0);

        // Hermes-style message length signal:
        // Short messages (<160 chars) are likely simple → reduce complexity
        // Long messages (>400 chars) are likely complex → increase complexity
        if char_count < 160 {
            complexity = (complexity - 0.1).max(0.05);
        } else if char_count > 400 {
            complexity = (complexity + 0.1).min(1.0);
        }

        // Code detection: triple backticks or common code patterns → increase complexity
        if normalized.contains("```")
            || normalized.contains("fn ")
            || normalized.contains("func ")
            || normalized.contains("class ")
            || normalized.contains("impl ")
        {
            complexity = (complexity + 0.15).min(1.0);
        }

        let requires_current_info = contains_any(
            &normalized,
            &["today", "latest", "current", "recent", "news", "now"],
        ) || contains_url(&normalized); // URLs imply current info needed

        let privacy_sensitive = contains_any(
            &normalized,
            &[
                "private",
                "confidential",
                "personal",
                "vault only",
                "local only",
            ],
        );
        let shell_required = contains_any(
            &normalized,
            &[
                "shell", "bash", "command", "terminal", "script", "build", "compile",
            ],
        ) || normalized.contains("```"); // Code blocks often need execution

        let research_related = contains_any(
            &normalized,
            &[
                "research",
                "compare",
                "sources",
                "citations",
                "fact check",
                "web",
            ],
        );
        let tool_count_estimate = estimate_tool_count(&normalized);

        ClassificationResult {
            complexity,
            tool_count_estimate,
            requires_current_info,
            privacy_sensitive,
            shell_required,
            research_related,
        }
    }
}

#[derive(Debug, Clone, Copy, Default)]
pub struct ConfidenceRouter {
    classifier: HeuristicClassifier,
}

impl ConfidenceRouter {
    pub fn route(&self, objective: &str) -> RoutingDecision {
        let classified = self.classifier.classify(objective);

        if classified.privacy_sensitive {
            return RoutingDecision::Local(LocalTask::Classify);
        }

        if contains_any(
            &objective.to_lowercase(),
            &["draft", "rewrite", "continue writing"],
        ) {
            return RoutingDecision::Local(LocalTask::GhostWrite);
        }

        if classified.research_related || classified.requires_current_info {
            return RoutingDecision::Cloud(
                CloudProvider::Perplexity,
                CloudConfig {
                    effort: "high".to_string(),
                    tools: Vec::new(),
                    enable_web_search: true,
                    enable_code_execution: false,
                },
            );
        }

        if classified.shell_required {
            return RoutingDecision::Cloud(
                CloudProvider::OpenAI,
                CloudConfig {
                    effort: "medium".to_string(),
                    tools: vec!["shell".to_string(), "code_interpreter".to_string()],
                    enable_web_search: false,
                    enable_code_execution: true,
                },
            );
        }

        if classified.complexity < 0.4 && classified.tool_count_estimate <= 2 {
            return RoutingDecision::LocalWithFallback {
                local: LocalTask::SimpleTool { max_tools: 2 },
                fallback: CloudProvider::ClaudeSonnet,
            };
        }

        let provider = if classified.complexity > 0.9 {
            CloudProvider::ClaudeOpus
        } else if classified.complexity < 0.2 {
            CloudProvider::ClaudeHaiku
        } else {
            CloudProvider::ClaudeSonnet
        };

        RoutingDecision::Cloud(
            provider,
            CloudConfig {
                effort: effort_for_complexity(classified.complexity).to_string(),
                tools: default_tools_for_objective(objective),
                enable_web_search: classified.requires_current_info,
                enable_code_execution: classified.shell_required,
            },
        )
    }
}

pub(crate) fn contains_any(haystack: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| haystack.contains(needle))
}

/// Detect URLs in text — if present, likely needs current info / web access.
fn contains_url(text: &str) -> bool {
    text.contains("http://") || text.contains("https://") || text.contains("www.")
}

fn estimate_tool_count(objective: &str) -> u8 {
    let score = [
        "search",
        "read",
        "write",
        "compare",
        "summarize",
        "find",
        "open",
    ]
    .iter()
    .filter(|needle| objective.contains(**needle))
    .count();
    score.max(1) as u8
}

fn effort_for_complexity(complexity: f32) -> &'static str {
    if complexity > 0.85 {
        "max"
    } else if complexity > 0.55 {
        "high"
    } else if complexity > 0.25 {
        "medium"
    } else {
        "low"
    }
}

fn objective_mentions_local_context(normalized: &str) -> bool {
    contains_any(
        normalized,
        &[
            "my note",
            "my notes",
            "vault",
            "attached",
            "attachment",
            "file",
            "document",
            "pdf",
            "@",
        ],
    )
}

fn default_tools_for_objective(objective: &str) -> Vec<String> {
    let normalized = objective.to_lowercase();
    let research_first = contains_any(&normalized, &["web", "research", "current", "latest"])
        && !objective_mentions_local_context(&normalized);
    let mut tools = if research_first {
        vec!["web.search".to_string()]
    } else {
        vec!["vault.search".to_string(), "vault.read".to_string()]
    };

    if contains_any(&normalized, &["write", "create", "update", "note"]) {
        tools.push("vault.write".to_string());
    }
    if contains_any(&normalized, &["web", "research", "current", "latest"])
        && !tools.iter().any(|tool| tool == "web.search")
    {
        tools.push("web.search".to_string());
    }
    if objective_mentions_local_context(&normalized)
        && !tools.iter().any(|tool| tool == "vault.search")
    {
        tools.push("vault.search".to_string());
    }
    if objective_mentions_local_context(&normalized)
        && !tools.iter().any(|tool| tool == "vault.read")
    {
        tools.push("vault.read".to_string());
    }
    #[cfg(feature = "pro-build")]
    if contains_any(&normalized, &["bash", "shell", "command"]) {
        tools.push("action.bash".to_string());
    }

    tools
}

#[cfg(test)]
mod tests {
    use super::{contains_any, default_tools_for_objective};

    #[test]
    fn contains_any_matches_substrings_without_normalizing_case() {
        assert!(contains_any("latest vault research", &["vault", "web"]));
        assert!(!contains_any("Latest Vault Research", &["vault", "web"]));
        assert!(!contains_any("latest vault research", &[]));
    }

    #[test]
    fn research_queries_prefer_web_search_before_vault_tools() {
        let tools =
            default_tools_for_objective("research Gemini 2.5 and compare the current models");
        assert_eq!(tools.first().map(String::as_str), Some("web.search"));
        assert!(!tools.iter().any(|tool| tool == "vault.search"));
    }

    #[test]
    fn note_scoped_research_queries_keep_vault_tools_available() {
        let tools = default_tools_for_objective(
            "research my notes about Gemini and compare them to the latest release",
        );
        assert_eq!(tools.first().map(String::as_str), Some("vault.search"));
        assert!(tools.iter().any(|tool| tool == "vault.read"));
        assert!(tools.iter().any(|tool| tool == "web.search"));
    }
}
