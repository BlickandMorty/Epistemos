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
        let decision = self.route_inner(objective);
        // V6.2 §1.4 substrate hook (2026-05-12): record every routing
        // decision into the process-global stats accumulator so the
        // Swift-side ConnectomeAlarmSubstrateObserver can compute the
        // per-turn route-change delta and feed it into InterruptScore.
        // The observer reads via `routing_stats_json` (cheap O(1) FFI).
        RoutingStatsAccumulator::shared().record(&decision);
        decision
    }

    /// Internal route-computation (the original `route` body). Kept
    /// pure so unit tests of the heuristic itself don't perturb the
    /// process-global stats accumulator. `route` wraps this with
    /// recording for the production path.
    fn route_inner(&self, objective: &str) -> RoutingDecision {
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

// ── RoutingStatsAccumulator (V6.2 §1.4 substrate hook 2026-05-12) ────
//
// Process-global accumulator of routing decisions. Each call to
// `ConfidenceRouter::route` records into this accumulator; the Swift-
// side `ConnectomeAlarmSubstrateObserver` polls via FFI to compute the
// per-turn route-change delta and feed it into InterruptScore.
//
// "Route divergence" is intentionally interpreted narrowly here: two
// adjacent decisions for different providers count as one change. The
// signal is conservative — true route stability under similar load
// reads as low connectomeAlarm; unstable routing patterns drive the
// signal up. This is honest under the V6.1 canon-hardening protocol:
// we don't pretend to have a "planned vs actual" comparison the
// routing layer hasn't shipped yet; we surface the closest measurable
// proxy and document the gap.

use std::sync::OnceLock;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Mutex;

/// Compact signature of the last routing decision. Two decisions
/// with identical signatures are considered "same route." The cloud-
/// provider variant captures the provider; local variants capture the
/// task tag. Stored as u32 so atomic ops stay cheap.
fn route_signature(decision: &RoutingDecision) -> u32 {
    match decision {
        RoutingDecision::Local(task) => match task {
            LocalTask::GhostWrite => 0x0001,
            LocalTask::Classify => 0x0002,
            LocalTask::Embed => 0x0003,
            LocalTask::SimpleTool { max_tools: _ } => 0x0004,
        },
        RoutingDecision::LocalWithFallback { fallback, .. } => 0x1000 | provider_tag(fallback),
        RoutingDecision::Cloud(provider, _) => 0x2000 | provider_tag(provider),
    }
}

fn provider_tag(provider: &CloudProvider) -> u32 {
    match provider {
        CloudProvider::ClaudeHaiku => 1,
        CloudProvider::ClaudeSonnet => 2,
        CloudProvider::ClaudeOpus => 3,
        CloudProvider::GeminiFlash => 4,
        CloudProvider::GeminiPro => 5,
        CloudProvider::Perplexity => 6,
        CloudProvider::OpenAI => 7,
    }
}

/// Process-global routing-decision accumulator. Cheap atomic counters
/// + a Mutex around the last-signature slot (writes happen at most
/// once per routing call, never on the render hot path).
pub struct RoutingStatsAccumulator {
    total_decisions: AtomicU64,
    total_route_changes: AtomicU64,
    last_signature: Mutex<Option<u32>>,
}

impl RoutingStatsAccumulator {
    /// Fresh accumulator. Tests use this; production code uses
    /// `shared()` which returns the process-global instance.
    pub fn new() -> Self {
        RoutingStatsAccumulator {
            total_decisions: AtomicU64::new(0),
            total_route_changes: AtomicU64::new(0),
            last_signature: Mutex::new(None),
        }
    }

    pub fn shared() -> &'static RoutingStatsAccumulator {
        static INSTANCE: OnceLock<RoutingStatsAccumulator> = OnceLock::new();
        INSTANCE.get_or_init(Self::new)
    }

    pub fn record(&self, decision: &RoutingDecision) {
        let sig = route_signature(decision);
        self.total_decisions.fetch_add(1, Ordering::Relaxed);
        // Lock-poisoning is non-fatal here: we'd rather miss one
        // change-count update than crash the agent runtime. Fall back
        // to inner-most value.
        let mut slot = match self.last_signature.lock() {
            Ok(g) => g,
            Err(poisoned) => poisoned.into_inner(),
        };
        if let Some(prev) = *slot {
            if prev != sig {
                self.total_route_changes.fetch_add(1, Ordering::Relaxed);
            }
        }
        *slot = Some(sig);
    }

    pub fn total_decisions(&self) -> u64 {
        self.total_decisions.load(Ordering::Relaxed)
    }

    pub fn total_route_changes(&self) -> u64 {
        self.total_route_changes.load(Ordering::Relaxed)
    }

    /// Test-only reset. Lets unit tests observe deterministic counter
    /// behavior without leaking state across cases.
    pub fn reset_for_testing(&self) {
        self.total_decisions.store(0, Ordering::Relaxed);
        self.total_route_changes.store(0, Ordering::Relaxed);
        let mut slot = match self.last_signature.lock() {
            Ok(g) => g,
            Err(poisoned) => poisoned.into_inner(),
        };
        *slot = None;
    }
}

#[cfg(test)]
mod stats_tests {
    use super::*;

    // Tests use fresh per-test accumulators rather than the global
    // `shared()` instance so cargo-test's parallel runner can't race
    // between unrelated cases. Production code still routes through
    // `RoutingStatsAccumulator::shared()` for one process-global view.

    #[test]
    fn record_increments_decisions_count() {
        let acc = RoutingStatsAccumulator::new();
        let d = RoutingDecision::Cloud(
            CloudProvider::ClaudeSonnet,
            CloudConfig {
                effort: "low".to_string(),
                tools: vec![],
                enable_web_search: false,
                enable_code_execution: false,
            },
        );
        acc.record(&d);
        acc.record(&d);
        acc.record(&d);
        assert_eq!(acc.total_decisions(), 3);
        // Same route 3x → 0 changes.
        assert_eq!(acc.total_route_changes(), 0);
    }

    #[test]
    fn record_increments_route_changes_on_provider_swap() {
        let acc = RoutingStatsAccumulator::new();
        let sonnet = RoutingDecision::Cloud(
            CloudProvider::ClaudeSonnet,
            CloudConfig {
                effort: "low".to_string(),
                tools: vec![],
                enable_web_search: false,
                enable_code_execution: false,
            },
        );
        let opus = RoutingDecision::Cloud(
            CloudProvider::ClaudeOpus,
            CloudConfig {
                effort: "high".to_string(),
                tools: vec![],
                enable_web_search: false,
                enable_code_execution: false,
            },
        );
        acc.record(&sonnet);
        acc.record(&opus);
        acc.record(&sonnet);
        // 3 decisions, 2 swaps (sonnet→opus, opus→sonnet).
        assert_eq!(acc.total_decisions(), 3);
        assert_eq!(acc.total_route_changes(), 2);
    }

    #[test]
    fn cloud_and_local_with_fallback_have_distinct_signatures() {
        // Even if the underlying provider matches, the LocalWithFallback
        // variant should not be conflated with a Cloud decision.
        let cloud_haiku = RoutingDecision::Cloud(
            CloudProvider::ClaudeHaiku,
            CloudConfig {
                effort: "low".to_string(),
                tools: vec![],
                enable_web_search: false,
                enable_code_execution: false,
            },
        );
        let local_haiku_fallback = RoutingDecision::LocalWithFallback {
            local: LocalTask::Classify,
            fallback: CloudProvider::ClaudeHaiku,
        };
        let s1 = route_signature(&cloud_haiku);
        let s2 = route_signature(&local_haiku_fallback);
        assert_ne!(s1, s2,
            "Cloud(Haiku) and LocalWithFallback(_, Haiku) must produce distinct route signatures");
    }
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
