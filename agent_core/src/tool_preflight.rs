//! RAG preflight tool selection — Deterministic Schema Engine, P8.2 spec §B
//! (docs/DETERMINISTIC_SCHEMA_ENGINE_SPEC_2026_06_18.md).
//!
//! Founding thesis: local models work GREAT when the tool footprint stays TIGHT.
//! Instead of dumping the whole tool suite into Gemma 4's context (which dilutes focus
//! and invites logic loops), select only the ~3-5 tools relevant to THIS turn.
//!
//! This is the FIRST, deterministic slice: a lexical relevance scorer (query-term
//! overlap with each tool's name / keywords / description). It is honest — real
//! scoring, no fake gate, and an empty result genuinely means "no tool matched" (the
//! caller decides whether to fall back to a default core set). The semantic/embedding
//! preflight from the spec is the follow-on that replaces `score` without changing this
//! deterministic, side-effect-free contract.

use std::collections::BTreeSet;

/// A tool the preflight may select, reduced to the text the scorer reads.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ToolCandidate {
    pub name: String,
    pub description: String,
    pub keywords: Vec<String>,
}

impl ToolCandidate {
    pub fn new(name: impl Into<String>, description: impl Into<String>, keywords: Vec<String>) -> Self {
        Self {
            name: name.into(),
            description: description.into(),
            keywords,
        }
    }
}

/// Short filler words that should never drive a tool match.
const STOPWORDS: &[&str] = &[
    "the", "and", "for", "with", "you", "your", "can", "how", "what", "get", "got",
    "use", "this", "that", "from", "into", "are", "was", "his", "her", "its", "out",
    "all", "any", "but", "not", "let", "please", "would", "could", "should", "want",
    "need", "able", "via", "per",
];

/// Lowercase alphanumeric tokens of length ≥ 3, minus the stopwords.
fn tokenize(text: &str) -> BTreeSet<String> {
    text.split(|c: char| !c.is_alphanumeric())
        .filter(|t| t.len() >= 3)
        .map(|t| t.to_ascii_lowercase())
        .filter(|t| !STOPWORDS.contains(&t.as_str()))
        .collect()
}

/// Score a candidate against the query terms. Each query term contributes its BEST
/// weight once: a hit in the tool NAME = 3, in a KEYWORD = 2, in the DESCRIPTION = 1.
fn score(query_terms: &BTreeSet<String>, candidate: &ToolCandidate) -> u32 {
    let name = tokenize(&candidate.name);
    let keywords: BTreeSet<String> = candidate.keywords.iter().flat_map(|k| tokenize(k)).collect();
    let description = tokenize(&candidate.description);
    query_terms
        .iter()
        .map(|term| {
            if name.contains(term) {
                3
            } else if keywords.contains(term) {
                2
            } else if description.contains(term) {
                1
            } else {
                0
            }
        })
        .sum()
}

/// Select up to `max` tools most relevant to `query`, by deterministic lexical score.
/// Returns the tool NAMES, highest score first, ties broken alphabetically. Only tools
/// with a score > 0 are returned — an empty result honestly means "no tool matched".
pub fn select_tools(query: &str, candidates: &[ToolCandidate], max: usize) -> Vec<String> {
    let terms = tokenize(query);
    if terms.is_empty() || max == 0 {
        return Vec::new();
    }
    let mut scored: Vec<(u32, &str)> = candidates
        .iter()
        .map(|c| (score(&terms, c), c.name.as_str()))
        .filter(|(s, _)| *s > 0)
        .collect();
    // score DESC, then name ASC — a total order, so the result is fully deterministic.
    scored.sort_by(|a, b| b.0.cmp(&a.0).then_with(|| a.1.cmp(b.1)));
    scored.into_iter().take(max).map(|(_, n)| n.to_string()).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn catalog() -> Vec<ToolCandidate> {
        vec![
            ToolCandidate::new("read_file", "Read the contents of a file from disk", vec!["file".into(), "open".into()]),
            ToolCandidate::new("write_file", "Write or patch a file on disk", vec!["file".into(), "save".into()]),
            ToolCandidate::new("web_search", "Search the web for information", vec!["search".into(), "internet".into()]),
            ToolCandidate::new("vault_search", "Search the user's notes vault", vec!["notes".into(), "vault".into()]),
            ToolCandidate::new("run_python", "Execute a Python snippet", vec!["python".into(), "code".into()]),
        ]
    }

    #[test]
    fn selects_relevant_tools_for_a_file_query() {
        let picks = select_tools("please read my file from disk", &catalog(), 3);
        assert!(picks.contains(&"read_file".to_string()));
        assert!(picks.len() <= 3);
        // a web tool is irrelevant here → must not be selected.
        assert!(!picks.contains(&"web_search".to_string()));
    }

    #[test]
    fn respects_the_max_footprint() {
        let picks = select_tools("search the web and notes", &catalog(), 2);
        assert!(picks.len() <= 2);
    }

    #[test]
    fn name_match_outranks_description_match() {
        // "vault" is in vault_search's NAME and no other tool's name.
        let picks = select_tools("vault", &catalog(), 5);
        assert_eq!(picks.first(), Some(&"vault_search".to_string()));
    }

    #[test]
    fn no_match_returns_empty_honestly() {
        let picks = select_tools("xyzzy quux frobnicate", &catalog(), 5);
        assert!(picks.is_empty());
    }

    #[test]
    fn deterministic_tie_break_is_alphabetical() {
        // read_file + write_file both carry "file" in the NAME (score 3) → tie → alpha.
        let picks = select_tools("file", &catalog(), 5);
        assert_eq!(picks, vec!["read_file".to_string(), "write_file".to_string()]);
    }

    #[test]
    fn stopwords_do_not_match() {
        let picks = select_tools("the and for with you", &catalog(), 5);
        assert!(picks.is_empty());
    }

    #[test]
    fn zero_max_returns_empty() {
        assert!(select_tools("file", &catalog(), 0).is_empty());
    }
}
