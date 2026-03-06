//! Fuzzy search over node labels using Finite State Transducers (FST).
//! Built during commit(), queried via FFI for sub-1ms results.
//!
//! Two-phase search:
//!   1. FST Levenshtein automaton for typo-tolerant matching (O(|query|) in automaton size)
//!   2. Linear scan with 5-tier scoring for ranking (exact > prefix > word-start > contains > subsequence)
//!
//! FST hits get a bonus score boost to surface typo corrections.

use fst::automaton::Levenshtein;
use fst::{IntoStreamer, Set, SetBuilder, Streamer};
use rustc_hash::FxHashMap;

/// Search result returned via FFI.
#[repr(C)]
pub struct SearchResult {
    pub uuid: *const std::os::raw::c_char,
    pub label: *const std::os::raw::c_char,
    pub node_type: u8,
    pub score: f32,
}

/// Search index built from graph node labels.
pub struct SearchIndex {
    /// FST set of lowercased labels for Levenshtein automaton queries.
    fst_set: Option<Set<Vec<u8>>>,
    /// Reverse index: lowercased label → list of entry indices.
    label_to_entries: FxHashMap<String, Vec<usize>>,
    /// Parallel arrays for label→node mapping.
    entries: Vec<SearchEntry>,
}

struct SearchEntry {
    uuid: String,
    label: String,
    label_lower: String,
    node_type: u8,
}

impl Default for SearchIndex {
    fn default() -> Self {
        Self::new()
    }
}

impl SearchIndex {
    pub fn new() -> Self {
        Self {
            fst_set: None,
            label_to_entries: FxHashMap::default(),
            entries: Vec::new(),
        }
    }

    /// Rebuild the index from current graph nodes.
    /// Call this after commit() completes.
    pub fn build(&mut self, nodes: &[crate::types::Node]) {
        self.entries.clear();
        self.label_to_entries.clear();

        // Collect entries from all visible nodes.
        for node in nodes {
            if !node.visible {
                continue;
            }
            let label_lower = node.label.to_lowercase();
            let idx = self.entries.len();
            self.label_to_entries
                .entry(label_lower.clone())
                .or_default()
                .push(idx);
            self.entries.push(SearchEntry {
                uuid: node.uuid.clone(),
                label: node.label.clone(),
                label_lower,
                node_type: node.node_type as u8,
            });
        }

        // Build FST set from deduplicated, sorted labels.
        let mut labels: Vec<&str> = self.label_to_entries.keys().map(|s| s.as_str()).collect();
        labels.sort_unstable();

        let mut builder = SetBuilder::memory();
        for label in &labels {
            let _ = builder.insert(label);
        }

        self.fst_set = Some(builder.into_set());
    }

    /// Search for nodes matching the query. Returns up to `limit` results.
    /// Combines FST Levenshtein matching with 5-tier scoring.
    pub fn search(&self, query: &str, limit: usize) -> Vec<(String, String, u8, f32)> {
        if query.is_empty() {
            return Vec::new();
        }

        let query_lower = query.to_lowercase();

        // Phase 1: Collect FST Levenshtein hits for typo-tolerant matching.
        let mut fst_hits: FxHashMap<usize, f32> = FxHashMap::default();
        if let Some(ref fst) = self.fst_set {
            // Edit distance: 1 for short queries (≤4 chars), 2 for longer.
            let max_dist = if query_lower.len() <= 4 { 1u32 } else { 2 };
            if let Ok(lev) = Levenshtein::new(&query_lower, max_dist) {
                let mut stream = fst.search(&lev).into_stream();
                while let Some(key) = stream.next() {
                    if let Ok(label) = std::str::from_utf8(key)
                        && let Some(indices) = self.label_to_entries.get(label)
                    {
                        for &idx in indices {
                            // FST bonus: 0.25 for edit-distance matches not caught by linear scan.
                            fst_hits.insert(idx, 0.25);
                        }
                    }
                }
            }
        }

        // Phase 2: Linear scan with 5-tier scoring.
        let mut scored: Vec<(usize, f32)> = Vec::new();

        for (i, entry) in self.entries.iter().enumerate() {
            let mut score = Self::score_match(&entry.label_lower, &query_lower);

            // Boost from FST Levenshtein if not already matched by linear scoring.
            if let Some(&fst_bonus) = fst_hits.get(&i) && score == 0.0 {
                score = fst_bonus;
            }

            if score > 0.0 {
                scored.push((i, score));
            }
        }

        // Sort by score descending.
        scored.sort_by(|a, b| {
            b.1.partial_cmp(&a.1)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        scored.truncate(limit);

        scored
            .iter()
            .map(|(i, score)| {
                let entry = &self.entries[*i];
                (
                    entry.uuid.clone(),
                    entry.label.clone(),
                    entry.node_type,
                    *score,
                )
            })
            .collect()
    }

    /// Score a label against a query. Returns 0.0 for no match.
    /// Higher score = better match.
    fn score_match(label: &str, query: &str) -> f32 {
        // Exact match.
        if label == query {
            return 1.0;
        }

        // Prefix match (highest practical score).
        if label.starts_with(query) {
            return 0.9;
        }

        // Word-start match (e.g., "ml" matches "machine learning").
        let words: Vec<&str> = label.split_whitespace().collect();
        let query_chars: Vec<char> = query.chars().collect();
        if !query_chars.is_empty() {
            let mut qi = 0;
            for word in &words {
                if qi < query_chars.len()
                    && let Some(first) = word.chars().next()
                    && first == query_chars[qi]
                {
                    qi += 1;
                }
            }
            if qi == query_chars.len() && query_chars.len() >= 2 {
                return 0.8;
            }
        }

        // Contains match.
        if label.contains(query) {
            return 0.6;
        }

        // Subsequence match (fuzzy -- letters appear in order but not contiguous).
        if Self::is_subsequence(query, label) {
            return 0.3;
        }

        0.0
    }

    fn is_subsequence(needle: &str, haystack: &str) -> bool {
        let mut needle_chars = needle.chars();
        let mut current = needle_chars.next();
        for h in haystack.chars() {
            if let Some(n) = current {
                if h == n {
                    current = needle_chars.next();
                }
            } else {
                return true;
            }
        }
        current.is_none()
    }
}

// ── Tests ───────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::Node;

    fn make_node(uuid: &str, label: &str, node_type: u8) -> Node {
        Node {
            id: 0,
            uuid: uuid.to_string(),
            x: 0.0,
            y: 0.0,
            vx: 0.0,
            vy: 0.0,
            fx: None,
            fy: None,
            node_type: crate::types::NodeType::from_u8(node_type),
            link_count: 1,
            radius: 8.0,
            label: label.to_string(),
            visible: true,
            created_at: 0.0,
            updated_at: 0.0,
            confidence: 0.0,
            color_override: [0.0; 4],
        }
    }

    #[test]
    fn empty_query_returns_nothing() {
        let mut idx = SearchIndex::new();
        idx.build(&[make_node("a", "Hello", 0)]);
        assert!(idx.search("", 10).is_empty());
    }

    #[test]
    fn exact_match_scores_highest() {
        let mut idx = SearchIndex::new();
        idx.build(&[
            make_node("a", "Machine Learning", 0),
            make_node("b", "Deep Learning", 0),
        ]);
        let results = idx.search("machine learning", 10);
        assert!(!results.is_empty());
        assert_eq!(results[0].0, "a");
        assert!(results[0].3 > 0.9);
    }

    #[test]
    fn prefix_match_works() {
        let mut idx = SearchIndex::new();
        idx.build(&[
            make_node("a", "Quantum Computing", 0),
            make_node("b", "Classical Music", 0),
        ]);
        let results = idx.search("quant", 10);
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].0, "a");
    }

    #[test]
    fn substring_match_works() {
        let mut idx = SearchIndex::new();
        idx.build(&[make_node("a", "Deep Reinforcement Learning", 0)]);
        let results = idx.search("reinforcement", 10);
        assert_eq!(results.len(), 1);
    }

    #[test]
    fn fuzzy_subsequence_match_works() {
        let mut idx = SearchIndex::new();
        idx.build(&[make_node("a", "Machine Learning", 0)]);
        let results = idx.search("mchn", 10);
        assert_eq!(results.len(), 1);
        assert!(results[0].3 > 0.0);
    }

    #[test]
    fn invisible_nodes_excluded() {
        let mut node = make_node("a", "Hidden Note", 0);
        node.visible = false;
        let mut idx = SearchIndex::new();
        idx.build(&[node]);
        assert!(idx.search("hidden", 10).is_empty());
    }

    #[test]
    fn limit_respected() {
        let mut idx = SearchIndex::new();
        let nodes: Vec<Node> = (0..20)
            .map(|i| make_node(&format!("n{i}"), &format!("Note {i}"), 0))
            .collect();
        idx.build(&nodes);
        let results = idx.search("note", 5);
        assert_eq!(results.len(), 5);
    }

    #[test]
    fn word_start_match_works() {
        let mut idx = SearchIndex::new();
        idx.build(&[
            make_node("a", "machine learning", 2),
            make_node("b", "music library", 0),
        ]);
        let results = idx.search("ml", 10);
        // Both match word-start: "machine learning" and "music library"
        assert_eq!(results.len(), 2);
        assert!(results[0].3 >= 0.8);
    }

    #[test]
    fn score_ordering_correct() {
        let mut idx = SearchIndex::new();
        idx.build(&[
            make_node("exact", "rust", 0),
            make_node("prefix", "rust programming", 0),
            make_node("contains", "why rust matters", 0),
            make_node("subseq", "xrxuxsxt", 0),
        ]);
        let results = idx.search("rust", 10);
        assert!(results.len() >= 3);
        // Exact > prefix > contains > subsequence
        assert_eq!(results[0].0, "exact");
        assert_eq!(results[1].0, "prefix");
        assert_eq!(results[2].0, "contains");
        assert_eq!(results[3].0, "subseq");
    }

    #[test]
    fn fst_levenshtein_matches_typos() {
        let mut idx = SearchIndex::new();
        idx.build(&[
            make_node("a", "Quantum Computing", 0),
            make_node("b", "Machine Learning", 0),
            make_node("c", "Neural Networks", 0),
        ]);
        // "quantm" is edit distance 1 from "quantum" — FST should catch it
        let results = idx.search("quantm", 10);
        assert!(!results.is_empty(), "FST Levenshtein should match 'quantm' → 'quantum computing'");
        assert_eq!(results[0].0, "a");
    }

    #[test]
    fn fst_levenshtein_edit_distance_2() {
        let mut idx = SearchIndex::new();
        idx.build(&[
            make_node("a", "reinforcement learning", 0),
        ]);
        // "reinfrcement" has 2 edits from "reinforcement" — should match with longer query
        let results = idx.search("reinfrcement", 10);
        assert!(!results.is_empty(), "FST Levenshtein dist=2 should match longer queries");
    }

    #[test]
    fn fst_prefix_still_works() {
        let mut idx = SearchIndex::new();
        idx.build(&[
            make_node("a", "Artificial Intelligence", 0),
        ]);
        let results = idx.search("artif", 10);
        assert!(!results.is_empty());
        // Prefix match should still score 0.9
        assert!(results[0].3 >= 0.9);
    }
}
