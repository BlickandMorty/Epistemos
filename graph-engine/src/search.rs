//! Fuzzy search over node labels using Finite State Transducers (FST).
//! Built during commit(), queried via FFI for sub-1ms results.

use fst::{Set, SetBuilder};

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
    /// FST set of lowercased labels (for future inverted-index / automaton use).
    _fst_set: Option<Set<Vec<u8>>>,
    /// Parallel arrays for label->node mapping.
    entries: Vec<SearchEntry>,
}

struct SearchEntry {
    uuid: String,
    label: String,
    label_lower: String,
    node_type: u8,
}

impl SearchIndex {
    pub fn new() -> Self {
        Self {
            _fst_set: None,
            entries: Vec::new(),
        }
    }

    /// Rebuild the index from current graph nodes.
    /// Call this after commit() completes.
    pub fn build(&mut self, nodes: &[crate::types::Node]) {
        self.entries.clear();

        // Collect entries from all visible nodes.
        for node in nodes {
            if !node.visible {
                continue;
            }
            self.entries.push(SearchEntry {
                uuid: node.uuid.clone(),
                label: node.label.clone(),
                label_lower: node.label.to_lowercase(),
                node_type: node.node_type as u8,
            });
        }

        // Sort entries by lowercase label (FST requires sorted input).
        self.entries
            .sort_by(|a, b| a.label_lower.cmp(&b.label_lower));

        // Build FST set from deduplicated labels (FST is a set, not a map).
        let mut builder = SetBuilder::memory();
        let mut prev_label = String::new();
        for entry in &self.entries {
            if entry.label_lower != prev_label {
                let _ = builder.insert(&entry.label_lower);
                prev_label = entry.label_lower.clone();
            }
        }

        self._fst_set = Some(builder.into_set());
    }

    /// Search for nodes matching the query. Returns up to `limit` results.
    /// Uses a combination of:
    /// 1. Exact match (highest priority)
    /// 2. Prefix match
    /// 3. Word-start match (e.g., "ml" matches "machine learning")
    /// 4. Substring/contains match
    /// 5. Subsequence match (fuzzy -- letters appear in order but not contiguous)
    pub fn search(&self, query: &str, limit: usize) -> Vec<(String, String, u8, f32)> {
        if query.is_empty() {
            return Vec::new();
        }

        let query_lower = query.to_lowercase();
        let mut scored: Vec<(usize, f32)> = Vec::new();

        for (i, entry) in self.entries.iter().enumerate() {
            let score = Self::score_match(&entry.label_lower, &query_lower);
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
                if qi < query_chars.len() {
                    if let Some(first) = word.chars().next() {
                        if first == query_chars[qi] {
                            qi += 1;
                        }
                    }
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
}
