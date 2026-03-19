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
    /// Sorted entry indices by lowercased label for duplicate-label lookup.
    sorted_label_indices: Vec<usize>,
    /// Parallel arrays for label→node mapping.
    entries: Vec<SearchEntry>,
}

struct SearchEntry {
    node_id: u32,
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
            sorted_label_indices: Vec::new(),
            entries: Vec::new(),
        }
    }

    /// Rebuild the index from current graph nodes.
    /// Call this after commit() completes.
    pub fn build(&mut self, nodes: &[crate::types::Node]) {
        self.entries.clear();
        self.sorted_label_indices.clear();
        self.entries.reserve(nodes.len());
        self.sorted_label_indices.reserve(nodes.len());

        // Collect entries from all visible nodes.
        for node in nodes {
            if !node.visible {
                continue;
            }
            let label_lower = node.label.to_lowercase();
            self.entries.push(SearchEntry {
                node_id: node.id,
                uuid: node.uuid.clone(),
                label: node.label.clone(),
                label_lower,
                node_type: node.node_type as u8,
            });
        }

        self.sorted_label_indices.extend(0..self.entries.len());
        self.sorted_label_indices.sort_unstable_by(|&a, &b| {
            self.entries[a]
                .label_lower
                .cmp(&self.entries[b].label_lower)
                .then(a.cmp(&b))
        });

        // Build FST set from deduplicated, sorted labels.
        let mut builder = SetBuilder::memory();
        let mut last_label: Option<&str> = None;
        for &entry_index in &self.sorted_label_indices {
            let label = self.entries[entry_index].label_lower.as_str();
            if last_label == Some(label) {
                continue;
            }
            let _ = builder.insert(label);
            last_label = Some(label);
        }

        self.fst_set = Some(builder.into_set());
    }

    fn entry_range_for_label(&self, label: &str) -> std::ops::Range<usize> {
        let start = self
            .sorted_label_indices
            .partition_point(|&entry_index| self.entries[entry_index].label_lower.as_str() < label);
        let end = self.sorted_label_indices.partition_point(|&entry_index| {
            self.entries[entry_index].label_lower.as_str() <= label
        });
        start..end
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
                    if let Ok(label) = std::str::from_utf8(key) {
                        for sorted_index in self.entry_range_for_label(label) {
                            let idx = self.sorted_label_indices[sorted_index];
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
            if let Some(&fst_bonus) = fst_hits.get(&i)
                && score == 0.0
            {
                score = fst_bonus;
            }

            if score > 0.0 {
                scored.push((i, score));
            }
        }

        // Sort by score descending.
        scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
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

    /// Collect UUIDs whose labels contain the query (case-insensitive).
    /// Preserves the legacy highlight semantics without re-lowercasing labels on every pass.
    pub fn collect_contains_match_uuids<'a>(&'a self, query: &str, out: &mut Vec<&'a str>) {
        out.clear();
        if query.is_empty() {
            return;
        }

        let query_lower = query.to_lowercase();
        for entry in &self.entries {
            if entry.label_lower.contains(&query_lower) {
                out.push(entry.uuid.as_str());
            }
        }
    }

    /// Collect node IDs whose labels contain the query (case-insensitive).
    /// This avoids UUID-to-ID hash lookups in the highlight path.
    pub fn collect_contains_match_node_ids(&self, query: &str, out: &mut Vec<u32>) {
        out.clear();
        if query.is_empty() {
            return;
        }

        let query_lower = query.to_lowercase();
        for entry in &self.entries {
            if entry.label_lower.contains(&query_lower) {
                out.push(entry.node_id);
            }
        }
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
        assert!(
            !results.is_empty(),
            "FST Levenshtein should match 'quantm' → 'quantum computing'"
        );
        assert_eq!(results[0].0, "a");
    }

    #[test]
    fn fst_levenshtein_edit_distance_2() {
        let mut idx = SearchIndex::new();
        idx.build(&[make_node("a", "reinforcement learning", 0)]);
        // "reinfrcement" has 2 edits from "reinforcement" — should match with longer query
        let results = idx.search("reinfrcement", 10);
        assert!(
            !results.is_empty(),
            "FST Levenshtein dist=2 should match longer queries"
        );
    }

    #[test]
    fn fst_prefix_still_works() {
        let mut idx = SearchIndex::new();
        idx.build(&[make_node("a", "Artificial Intelligence", 0)]);
        let results = idx.search("artif", 10);
        assert!(!results.is_empty());
        // Prefix match should still score 0.9
        assert!(results[0].3 >= 0.9);
    }

    #[test]
    fn exact_match_returns_all_duplicate_labels() {
        let mut idx = SearchIndex::new();
        idx.build(&[
            make_node("a", "Shared Label", 0),
            make_node("b", "Shared Label", 0),
            make_node("c", "Other", 0),
        ]);

        let results = idx.search("shared label", 10);
        let uuids: Vec<&str> = results
            .iter()
            .map(|(uuid, _, _, _)| uuid.as_str())
            .collect();

        assert_eq!(results.len(), 2);
        assert!(uuids.contains(&"a"));
        assert!(uuids.contains(&"b"));
    }

    #[test]
    fn typo_match_returns_all_duplicate_labels() {
        let mut idx = SearchIndex::new();
        idx.build(&[
            make_node("a", "Quantum Note", 0),
            make_node("b", "Quantum Note", 0),
            make_node("c", "Machine Learning", 0),
        ]);

        let results = idx.search("quantm note", 10);
        let uuids: Vec<&str> = results
            .iter()
            .map(|(uuid, _, _, _)| uuid.as_str())
            .collect();

        assert_eq!(results.len(), 2);
        assert!(uuids.contains(&"a"));
        assert!(uuids.contains(&"b"));
    }

    #[test]
    fn collect_contains_match_uuids_preserves_case_insensitive_contains_behavior() {
        let mut idx = SearchIndex::new();
        idx.build(&[
            make_node("a", "Alpha Cluster", 0),
            make_node("b", "beta topic", 0),
            make_node("c", "Gamma", 0),
        ]);

        let mut matches = Vec::new();
        idx.collect_contains_match_uuids("TOP", &mut matches);

        assert_eq!(matches, vec!["b"]);
    }

    #[test]
    fn collect_contains_match_uuids_returns_all_matching_entries() {
        let mut idx = SearchIndex::new();
        idx.build(&[
            make_node("a", "Source 7", 0),
            make_node("b", "Backup Source 7", 0),
            make_node("c", "Reference", 0),
        ]);

        let mut matches = Vec::new();
        idx.collect_contains_match_uuids("source 7", &mut matches);

        assert_eq!(matches, vec!["a", "b"]);
    }

    #[test]
    fn collect_contains_match_node_ids_preserves_case_insensitive_contains_behavior() {
        let mut idx = SearchIndex::new();
        let mut alpha = make_node("a", "Alpha Cluster", 0);
        alpha.id = 11;
        let mut beta = make_node("b", "beta topic", 0);
        beta.id = 29;
        let mut gamma = make_node("c", "Gamma", 0);
        gamma.id = 47;
        idx.build(&[alpha, beta, gamma]);

        let mut matches = Vec::new();
        idx.collect_contains_match_node_ids("TOP", &mut matches);

        assert_eq!(matches, vec![29]);
    }

    #[test]
    fn collect_contains_match_node_ids_returns_all_matching_entries() {
        let mut idx = SearchIndex::new();
        let mut source = make_node("a", "Source 7", 0);
        source.id = 3;
        let mut backup = make_node("b", "Backup Source 7", 0);
        backup.id = 9;
        let mut reference = make_node("c", "Reference", 0);
        reference.id = 21;
        idx.build(&[source, backup, reference]);

        let mut matches = Vec::new();
        idx.collect_contains_match_node_ids("source 7", &mut matches);

        assert_eq!(matches, vec![3, 9]);
    }
}
