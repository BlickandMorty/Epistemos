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

use crate::grammar::{build_dispatch_grammar, GrammarError};
use llguidance::api::TopLevelGrammar;
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

/// Select up to `max` tools for the turn, ALWAYS including the `floor` core tools (by
/// name) even when the query doesn't lexically match them — so a local model never
/// loses its essential capabilities (vault search, think, …) on a terse or off-topic
/// prompt, while still keeping the footprint tight. Floor tools that exist in
/// `candidates` are guaranteed present (in floor order); the remaining slots go to the
/// top-scoring query matches. Deterministic; deduped; never exceeds `max`.
pub fn select_tools_with_floor(
    query: &str,
    candidates: &[ToolCandidate],
    max: usize,
    floor: &[&str],
) -> Vec<String> {
    if max == 0 {
        return Vec::new();
    }
    let names: BTreeSet<&str> = candidates.iter().map(|c| c.name.as_str()).collect();
    let mut result: Vec<String> = Vec::new();
    let mut seen: BTreeSet<String> = BTreeSet::new();

    // Floor first — the core tools are GUARANTEED present (if they exist in the catalog).
    for &f in floor {
        if result.len() >= max {
            break;
        }
        if names.contains(f) && seen.insert(f.to_string()) {
            result.push(f.to_string());
        }
    }
    // Then the query-relevant matches fill the remaining slots.
    for name in select_tools(query, candidates, max) {
        if result.len() >= max {
            break;
        }
        if seen.insert(name.clone()) {
            result.push(name);
        }
    }
    result
}

/// FFI input shape for a tool candidate (the Swift catalog serializes to this).
#[derive(serde::Deserialize)]
struct PreflightToolInput {
    name: String,
    #[serde(default)]
    description: String,
    #[serde(default)]
    keywords: Vec<String>,
}

/// FFI: RAG-preflight tool selection across the UniFFI boundary. Swift passes the query,
/// the tool catalog as JSON (`[{"name","description","keywords"}]`), and the max tight-
/// footprint size; gets back the selected tool NAMES as a JSON array. Pure — it does NOT
/// touch the live agent loop; the Swift side decides where to apply the selection (e.g.
/// surface "N tools selected for this turn" in the picker — the spec's "surface the
/// determinism visibly"). Honest empty `[]` on a parse error or no match.
#[uniffi::export]
pub fn schema_preflight_select_tools_json(query: String, candidates_json: String, max: u32) -> String {
    let inputs: Vec<PreflightToolInput> = serde_json::from_str(&candidates_json).unwrap_or_default();
    let candidates: Vec<ToolCandidate> = inputs
        .into_iter()
        .map(|i| ToolCandidate::new(i.name, i.description, i.keywords))
        .collect();
    let selected = select_tools(&query, &candidates, max as usize);
    serde_json::to_string(&selected).unwrap_or_else(|_| "[]".to_string())
}

/// A candidate tool paired with its declared parameter schema (a JSON object schema),
/// for the §C.1 preflight → dispatch-grammar pipeline.
pub struct PreflightTool<'a> {
    pub candidate: ToolCandidate,
    pub schema: &'a serde_json::Value,
}

/// The §C.1 pipeline ("RAG Preflight Filter → structured tool output"): select the
/// tools relevant to `query`, then build the GBNF dispatch grammar (via the existing
/// `grammar::build_dispatch_grammar`) for ONLY those tools — so a local model sees a
/// TIGHT, schema-CONSTRAINED tool set (high tool-call fidelity on the selected few, not
/// the whole suite). Returns the selected tool names + the dispatch grammar. Errors
/// `EmptyDispatch` when no tool matched (the caller falls back to a default core set)
/// or propagates a grammar build error. This COMPOSES the preflight with the existing
/// grammar engine — it does not reimplement json-schema→grammar conversion.
pub fn preflight_dispatch_grammar(
    query: &str,
    tools: &[PreflightTool<'_>],
    max: usize,
) -> Result<(Vec<String>, TopLevelGrammar), GrammarError> {
    let candidates: Vec<ToolCandidate> = tools.iter().map(|t| t.candidate.clone()).collect();
    let selected = select_tools(query, &candidates, max);
    if selected.is_empty() {
        return Err(GrammarError::EmptyDispatch);
    }
    let selected_set: BTreeSet<&str> = selected.iter().map(String::as_str).collect();
    let dispatch: Vec<(&str, &serde_json::Value)> = tools
        .iter()
        .filter(|t| selected_set.contains(t.candidate.name.as_str()))
        .map(|t| (t.candidate.name.as_str(), t.schema))
        .collect();
    let grammar = build_dispatch_grammar(&dispatch)?;
    Ok((selected, grammar))
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

    fn object_schema() -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": { "path": { "type": "string" } },
            "required": ["path"]
        })
    }

    #[test]
    fn preflight_dispatch_grammar_constrains_only_the_selected_tools() {
        let schema = object_schema();
        let tools = vec![
            PreflightTool { candidate: ToolCandidate::new("read_file", "Read a file from disk", vec!["file".into()]), schema: &schema },
            PreflightTool { candidate: ToolCandidate::new("web_search", "Search the web", vec!["search".into()]), schema: &schema },
        ];
        let (selected, _grammar) = preflight_dispatch_grammar("read my file", &tools, 5)
            .expect("a grammar should build for the selected tools");
        assert!(selected.contains(&"read_file".to_string()));
        assert!(!selected.contains(&"web_search".to_string())); // irrelevant → not constrained
    }

    #[test]
    fn preflight_dispatch_grammar_errors_when_nothing_matches() {
        let schema = object_schema();
        let tools = vec![PreflightTool {
            candidate: ToolCandidate::new("read_file", "Read a file", vec!["file".into()]),
            schema: &schema,
        }];
        assert!(matches!(
            preflight_dispatch_grammar("xyzzy quux", &tools, 5),
            Err(GrammarError::EmptyDispatch)
        ));
    }

    #[test]
    fn floor_tools_are_always_included() {
        // The query never mentions the vault, but vault_search is a floor (core) tool.
        let picks = select_tools_with_floor("please read my file", &catalog(), 3, &["vault_search"]);
        assert!(picks.contains(&"vault_search".to_string()));
        assert!(picks.contains(&"read_file".to_string())); // the relevant tool is still there
        assert!(picks.len() <= 3);
    }

    #[test]
    fn floor_skips_tools_not_in_the_catalog() {
        let picks = select_tools_with_floor("read a file", &catalog(), 5, &["nonexistent_tool"]);
        assert!(!picks.contains(&"nonexistent_tool".to_string()));
    }

    #[test]
    fn floor_respects_max_and_dedups_overlapping_tools() {
        // read_file is BOTH relevant and a floor tool → it appears once, within `max`.
        let picks = select_tools_with_floor("read my file", &catalog(), 2, &["read_file"]);
        assert!(picks.len() <= 2);
        assert_eq!(picks.iter().filter(|n| *n == "read_file").count(), 1);
    }

    #[test]
    fn select_tools_is_deterministic_regardless_of_input_order() {
        // The founding-thesis DETERMINISM claim: the selection must not depend on how
        // the catalog happens to be ordered.
        let forward = catalog();
        let mut reversed = catalog();
        reversed.reverse();
        let query = "read my file and search the notes";
        let a = select_tools(query, &forward, 4);
        let b = select_tools(query, &reversed, 4);
        assert_eq!(a, b, "tool selection must be order-independent");
        // ...and idempotent.
        assert_eq!(a, select_tools(query, &forward, 4));
    }

    #[test]
    fn ffi_select_tools_json_round_trips() {
        let catalog = serde_json::json!([
            {"name": "read_file", "description": "Read a file from disk", "keywords": ["file"]},
            {"name": "web_search", "description": "Search the web", "keywords": ["search"]}
        ])
        .to_string();
        let out = schema_preflight_select_tools_json("read my file".to_string(), catalog, 5);
        let picks: Vec<String> = serde_json::from_str(&out).expect("valid JSON array out");
        assert!(picks.contains(&"read_file".to_string()));
        assert!(!picks.contains(&"web_search".to_string()));
    }

    #[test]
    fn ffi_select_tools_json_is_honest_empty_on_bad_or_no_match() {
        // a parse error → honest empty array (never a crash, never a fake selection)
        assert_eq!(
            schema_preflight_select_tools_json("q".to_string(), "not json".to_string(), 5),
            "[]"
        );
        // a valid catalog with no match → empty array
        let catalog =
            serde_json::json!([{"name": "read_file", "description": "Read a file", "keywords": []}]).to_string();
        assert_eq!(
            schema_preflight_select_tools_json("xyzzy".to_string(), catalog, 5),
            "[]"
        );
    }
}
