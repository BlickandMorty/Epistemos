//! Automatically generated comprehensive search tests.
#[cfg(test)]
mod tests {
    use crate::search::SearchIndex;
    use crate::types::{Node, NodeType};

    fn make_test_node(id: usize, label: &str, visible: bool) -> Node {
        Node {
            id: 0,
            uuid: format!("uuid-{}", id),
            x: 0.0, y: 0.0, vx: 0.0, vy: 0.0, fx: None, fy: None,
            node_type: NodeType::from_u8(0),
            link_count: 1,
            radius: 8.0,
            label: label.to_string(),
            visible,
            created_at: 0.0, updated_at: 0.0, confidence: 0.0,
        }
    }

    #[test]
    fn test_search_0_simple_all_visible_exact_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_1_simple_all_visible_exact_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_2_simple_all_visible_exact_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_3_simple_all_visible_prefix_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_4_simple_all_visible_prefix_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_5_simple_all_visible_prefix_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_6_simple_all_visible_contains_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_7_simple_all_visible_contains_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_8_simple_all_visible_contains_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_9_simple_all_visible_subsequence_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_10_simple_all_visible_subsequence_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_11_simple_all_visible_subsequence_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_12_simple_all_visible_typo1_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_13_simple_all_visible_typo1_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_14_simple_all_visible_typo1_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_15_simple_all_visible_typo2_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_16_simple_all_visible_typo2_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_17_simple_all_visible_typo2_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_18_simple_all_visible_empty_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_19_simple_all_visible_empty_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_20_simple_all_visible_empty_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_21_simple_all_visible_miss_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_22_simple_all_visible_miss_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_23_simple_all_visible_miss_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_24_simple_mixed_visible_exact_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_25_simple_mixed_visible_exact_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_26_simple_mixed_visible_exact_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_27_simple_mixed_visible_prefix_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_28_simple_mixed_visible_prefix_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_29_simple_mixed_visible_prefix_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_30_simple_mixed_visible_contains_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_31_simple_mixed_visible_contains_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_32_simple_mixed_visible_contains_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_33_simple_mixed_visible_subsequence_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_34_simple_mixed_visible_subsequence_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_35_simple_mixed_visible_subsequence_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_36_simple_mixed_visible_typo1_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_37_simple_mixed_visible_typo1_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_38_simple_mixed_visible_typo1_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_39_simple_mixed_visible_typo2_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_40_simple_mixed_visible_typo2_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_41_simple_mixed_visible_typo2_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_42_simple_mixed_visible_empty_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_43_simple_mixed_visible_empty_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_44_simple_mixed_visible_empty_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_45_simple_mixed_visible_miss_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_46_simple_mixed_visible_miss_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_47_simple_mixed_visible_miss_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_48_simple_none_visible_exact_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_49_simple_none_visible_exact_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_50_simple_none_visible_exact_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_51_simple_none_visible_prefix_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_52_simple_none_visible_prefix_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_53_simple_none_visible_prefix_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_54_simple_none_visible_contains_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_55_simple_none_visible_contains_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_56_simple_none_visible_contains_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_57_simple_none_visible_subsequence_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_58_simple_none_visible_subsequence_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_59_simple_none_visible_subsequence_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_60_simple_none_visible_typo1_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_61_simple_none_visible_typo1_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_62_simple_none_visible_typo1_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_63_simple_none_visible_typo2_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_64_simple_none_visible_typo2_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_65_simple_none_visible_typo2_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_66_simple_none_visible_empty_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_67_simple_none_visible_empty_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_68_simple_none_visible_empty_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_69_simple_none_visible_miss_limit1() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_70_simple_none_visible_miss_limit5() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_71_simple_none_visible_miss_limit50() {
        let labels = ["apple", "banana", "cherry", "date"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_72_tech_all_visible_exact_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_73_tech_all_visible_exact_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_74_tech_all_visible_exact_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_75_tech_all_visible_prefix_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_76_tech_all_visible_prefix_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_77_tech_all_visible_prefix_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_78_tech_all_visible_contains_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_79_tech_all_visible_contains_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_80_tech_all_visible_contains_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_81_tech_all_visible_subsequence_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_82_tech_all_visible_subsequence_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_83_tech_all_visible_subsequence_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_84_tech_all_visible_typo1_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_85_tech_all_visible_typo1_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_86_tech_all_visible_typo1_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_87_tech_all_visible_typo2_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_88_tech_all_visible_typo2_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_89_tech_all_visible_typo2_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_90_tech_all_visible_empty_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_91_tech_all_visible_empty_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_92_tech_all_visible_empty_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_93_tech_all_visible_miss_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_94_tech_all_visible_miss_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_95_tech_all_visible_miss_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_96_tech_mixed_visible_exact_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_97_tech_mixed_visible_exact_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_98_tech_mixed_visible_exact_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_99_tech_mixed_visible_prefix_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_100_tech_mixed_visible_prefix_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_101_tech_mixed_visible_prefix_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_102_tech_mixed_visible_contains_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_103_tech_mixed_visible_contains_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_104_tech_mixed_visible_contains_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_105_tech_mixed_visible_subsequence_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_106_tech_mixed_visible_subsequence_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_107_tech_mixed_visible_subsequence_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_108_tech_mixed_visible_typo1_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_109_tech_mixed_visible_typo1_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_110_tech_mixed_visible_typo1_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_111_tech_mixed_visible_typo2_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_112_tech_mixed_visible_typo2_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_113_tech_mixed_visible_typo2_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_114_tech_mixed_visible_empty_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_115_tech_mixed_visible_empty_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_116_tech_mixed_visible_empty_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_117_tech_mixed_visible_miss_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_118_tech_mixed_visible_miss_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_119_tech_mixed_visible_miss_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_120_tech_none_visible_exact_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_121_tech_none_visible_exact_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_122_tech_none_visible_exact_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_123_tech_none_visible_prefix_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_124_tech_none_visible_prefix_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_125_tech_none_visible_prefix_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_126_tech_none_visible_contains_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_127_tech_none_visible_contains_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_128_tech_none_visible_contains_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_129_tech_none_visible_subsequence_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_130_tech_none_visible_subsequence_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_131_tech_none_visible_subsequence_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_132_tech_none_visible_typo1_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_133_tech_none_visible_typo1_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_134_tech_none_visible_typo1_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_135_tech_none_visible_typo2_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_136_tech_none_visible_typo2_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_137_tech_none_visible_typo2_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_138_tech_none_visible_empty_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_139_tech_none_visible_empty_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_140_tech_none_visible_empty_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_141_tech_none_visible_miss_limit1() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_142_tech_none_visible_miss_limit5() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_143_tech_none_visible_miss_limit50() {
        let labels = ["machine learning", "neural networks", "deep reinforcement learning", "quantum computing"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_144_similar_all_visible_exact_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_145_similar_all_visible_exact_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_146_similar_all_visible_exact_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_147_similar_all_visible_prefix_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_148_similar_all_visible_prefix_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_149_similar_all_visible_prefix_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_150_similar_all_visible_contains_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_151_similar_all_visible_contains_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_152_similar_all_visible_contains_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_153_similar_all_visible_subsequence_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_154_similar_all_visible_subsequence_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_155_similar_all_visible_subsequence_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_156_similar_all_visible_typo1_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_157_similar_all_visible_typo1_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_158_similar_all_visible_typo1_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_159_similar_all_visible_typo2_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_160_similar_all_visible_typo2_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_161_similar_all_visible_typo2_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_162_similar_all_visible_empty_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_163_similar_all_visible_empty_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_164_similar_all_visible_empty_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_165_similar_all_visible_miss_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_166_similar_all_visible_miss_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_167_similar_all_visible_miss_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_168_similar_mixed_visible_exact_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_169_similar_mixed_visible_exact_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_170_similar_mixed_visible_exact_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_171_similar_mixed_visible_prefix_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_172_similar_mixed_visible_prefix_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_173_similar_mixed_visible_prefix_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_174_similar_mixed_visible_contains_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_175_similar_mixed_visible_contains_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_176_similar_mixed_visible_contains_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_177_similar_mixed_visible_subsequence_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_178_similar_mixed_visible_subsequence_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_179_similar_mixed_visible_subsequence_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_180_similar_mixed_visible_typo1_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_181_similar_mixed_visible_typo1_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_182_similar_mixed_visible_typo1_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_183_similar_mixed_visible_typo2_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_184_similar_mixed_visible_typo2_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_185_similar_mixed_visible_typo2_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_186_similar_mixed_visible_empty_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_187_similar_mixed_visible_empty_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_188_similar_mixed_visible_empty_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_189_similar_mixed_visible_miss_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_190_similar_mixed_visible_miss_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_191_similar_mixed_visible_miss_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_192_similar_none_visible_exact_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_193_similar_none_visible_exact_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_194_similar_none_visible_exact_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_195_similar_none_visible_prefix_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_196_similar_none_visible_prefix_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_197_similar_none_visible_prefix_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_198_similar_none_visible_contains_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_199_similar_none_visible_contains_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_200_similar_none_visible_contains_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_201_similar_none_visible_subsequence_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_202_similar_none_visible_subsequence_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_203_similar_none_visible_subsequence_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_204_similar_none_visible_typo1_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_205_similar_none_visible_typo1_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_206_similar_none_visible_typo1_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_207_similar_none_visible_typo2_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_208_similar_none_visible_typo2_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_209_similar_none_visible_typo2_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_210_similar_none_visible_empty_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_211_similar_none_visible_empty_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_212_similar_none_visible_empty_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_213_similar_none_visible_miss_limit1() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_214_similar_none_visible_miss_limit5() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_215_similar_none_visible_miss_limit50() {
        let labels = ["test", "testing", "tester", "tested", "testament"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_216_mixed_case_all_visible_exact_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_217_mixed_case_all_visible_exact_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_218_mixed_case_all_visible_exact_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_219_mixed_case_all_visible_prefix_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_220_mixed_case_all_visible_prefix_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_221_mixed_case_all_visible_prefix_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_222_mixed_case_all_visible_contains_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_223_mixed_case_all_visible_contains_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_224_mixed_case_all_visible_contains_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_225_mixed_case_all_visible_subsequence_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_226_mixed_case_all_visible_subsequence_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_227_mixed_case_all_visible_subsequence_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_228_mixed_case_all_visible_typo1_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_229_mixed_case_all_visible_typo1_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_230_mixed_case_all_visible_typo1_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_231_mixed_case_all_visible_typo2_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_232_mixed_case_all_visible_typo2_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_233_mixed_case_all_visible_typo2_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_234_mixed_case_all_visible_empty_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_235_mixed_case_all_visible_empty_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_236_mixed_case_all_visible_empty_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_237_mixed_case_all_visible_miss_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_238_mixed_case_all_visible_miss_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_239_mixed_case_all_visible_miss_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_240_mixed_case_mixed_visible_exact_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_241_mixed_case_mixed_visible_exact_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_242_mixed_case_mixed_visible_exact_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_243_mixed_case_mixed_visible_prefix_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_244_mixed_case_mixed_visible_prefix_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_245_mixed_case_mixed_visible_prefix_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_246_mixed_case_mixed_visible_contains_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_247_mixed_case_mixed_visible_contains_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_248_mixed_case_mixed_visible_contains_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_249_mixed_case_mixed_visible_subsequence_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_250_mixed_case_mixed_visible_subsequence_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_251_mixed_case_mixed_visible_subsequence_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_252_mixed_case_mixed_visible_typo1_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_253_mixed_case_mixed_visible_typo1_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_254_mixed_case_mixed_visible_typo1_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_255_mixed_case_mixed_visible_typo2_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_256_mixed_case_mixed_visible_typo2_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_257_mixed_case_mixed_visible_typo2_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_258_mixed_case_mixed_visible_empty_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_259_mixed_case_mixed_visible_empty_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_260_mixed_case_mixed_visible_empty_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_261_mixed_case_mixed_visible_miss_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_262_mixed_case_mixed_visible_miss_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_263_mixed_case_mixed_visible_miss_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_264_mixed_case_none_visible_exact_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_265_mixed_case_none_visible_exact_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_266_mixed_case_none_visible_exact_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_267_mixed_case_none_visible_prefix_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_268_mixed_case_none_visible_prefix_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_269_mixed_case_none_visible_prefix_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_270_mixed_case_none_visible_contains_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_271_mixed_case_none_visible_contains_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_272_mixed_case_none_visible_contains_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_273_mixed_case_none_visible_subsequence_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_274_mixed_case_none_visible_subsequence_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_275_mixed_case_none_visible_subsequence_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_276_mixed_case_none_visible_typo1_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_277_mixed_case_none_visible_typo1_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_278_mixed_case_none_visible_typo1_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_279_mixed_case_none_visible_typo2_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_280_mixed_case_none_visible_typo2_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_281_mixed_case_none_visible_typo2_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_282_mixed_case_none_visible_empty_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_283_mixed_case_none_visible_empty_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_284_mixed_case_none_visible_empty_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_285_mixed_case_none_visible_miss_limit1() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_286_mixed_case_none_visible_miss_limit5() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_287_mixed_case_none_visible_miss_limit50() {
        let labels = ["JavaScript", "TYPESCRIPT", "rUsT", "GoLang"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_288_special_chars_all_visible_exact_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_289_special_chars_all_visible_exact_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_290_special_chars_all_visible_exact_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_291_special_chars_all_visible_prefix_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_292_special_chars_all_visible_prefix_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_293_special_chars_all_visible_prefix_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_294_special_chars_all_visible_contains_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_295_special_chars_all_visible_contains_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_296_special_chars_all_visible_contains_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_297_special_chars_all_visible_subsequence_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_298_special_chars_all_visible_subsequence_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_299_special_chars_all_visible_subsequence_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_300_special_chars_all_visible_typo1_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_301_special_chars_all_visible_typo1_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_302_special_chars_all_visible_typo1_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_303_special_chars_all_visible_typo2_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_304_special_chars_all_visible_typo2_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_305_special_chars_all_visible_typo2_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_306_special_chars_all_visible_empty_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_307_special_chars_all_visible_empty_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_308_special_chars_all_visible_empty_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_309_special_chars_all_visible_miss_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_310_special_chars_all_visible_miss_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_311_special_chars_all_visible_miss_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = true;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "all_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_312_special_chars_mixed_visible_exact_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_313_special_chars_mixed_visible_exact_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_314_special_chars_mixed_visible_exact_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_315_special_chars_mixed_visible_prefix_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_316_special_chars_mixed_visible_prefix_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_317_special_chars_mixed_visible_prefix_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_318_special_chars_mixed_visible_contains_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_319_special_chars_mixed_visible_contains_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_320_special_chars_mixed_visible_contains_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_321_special_chars_mixed_visible_subsequence_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_322_special_chars_mixed_visible_subsequence_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_323_special_chars_mixed_visible_subsequence_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_324_special_chars_mixed_visible_typo1_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_325_special_chars_mixed_visible_typo1_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_326_special_chars_mixed_visible_typo1_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_327_special_chars_mixed_visible_typo2_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_328_special_chars_mixed_visible_typo2_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_329_special_chars_mixed_visible_typo2_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_330_special_chars_mixed_visible_empty_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_331_special_chars_mixed_visible_empty_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_332_special_chars_mixed_visible_empty_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_333_special_chars_mixed_visible_miss_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_334_special_chars_mixed_visible_miss_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_335_special_chars_mixed_visible_miss_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = i % 2 == 0;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "mixed_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_336_special_chars_none_visible_exact_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_337_special_chars_none_visible_exact_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_338_special_chars_none_visible_exact_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "exact" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "exact" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "exact" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_339_special_chars_none_visible_prefix_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_340_special_chars_none_visible_prefix_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_341_special_chars_none_visible_prefix_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "prefix" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "prefix" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "prefix" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_342_special_chars_none_visible_contains_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_343_special_chars_none_visible_contains_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_344_special_chars_none_visible_contains_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "contains" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "contains" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "contains" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_345_special_chars_none_visible_subsequence_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_346_special_chars_none_visible_subsequence_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_347_special_chars_none_visible_subsequence_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "subsequence" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "subsequence" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "subsequence" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_348_special_chars_none_visible_typo1_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_349_special_chars_none_visible_typo1_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_350_special_chars_none_visible_typo1_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo1" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo1" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo1" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_351_special_chars_none_visible_typo2_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_352_special_chars_none_visible_typo2_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_353_special_chars_none_visible_typo2_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "typo2" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "typo2" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "typo2" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_354_special_chars_none_visible_empty_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_355_special_chars_none_visible_empty_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_356_special_chars_none_visible_empty_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "empty" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "empty" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "empty" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_357_special_chars_none_visible_miss_limit1() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 1);
        assert!(results.len() <= 1, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_358_special_chars_none_visible_miss_limit5() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 5);
        assert!(results.len() <= 5, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

    #[test]
    fn test_search_359_special_chars_none_visible_miss_limit50() {
        let labels = ["C++", "C#", "F#", "Objective-C", "HTML5"];
        let mut nodes = Vec::new();
        for (i, &l) in labels.iter().enumerate() {
            let visible = false;
            nodes.push(make_test_node(i, l, visible));
        }
        let mut idx = SearchIndex::new();
        idx.build(&nodes);
        let target = labels[0];
        let query = match "miss" {
            "exact" => target.to_string(),
            "prefix" => target.chars().take(3).collect(),
            "contains" => if target.len() > 3 { target.chars().skip(1).take(3).collect() } else { target.to_string() },
            "subsequence" => target.chars().step_by(2).collect(),
            "typo1" => { let mut q = target.to_string(); if !q.is_empty() { q.replace_range(0..1, "z"); } q },
            "typo2" => { let mut q = target.to_string(); if q.len() > 1 { q.replace_range(0..2, "zz"); } q },
            "empty" => String::new(),
            "miss" => "xyz_unlikely_match_123".to_string(),
            _ => String::new(),
        };
        let results = idx.search(&query, 50);
        assert!(results.len() <= 50, "Results exceeded limit");
        if "none_visible" == "none_visible" {
            assert!(results.is_empty(), "Hidden nodes should not be found");
        }
        if "miss" == "empty" {
            assert!(results.is_empty(), "Empty query should return nothing");
        }
        if "miss" == "miss" {
            assert!(results.is_empty(), "Unlikely query should return nothing");
        }
    }

}
