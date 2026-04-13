//! Session Knowledge Graph — Post-session graph extraction.
//!
//! Generates a knowledge graph from session data using a two-pass approach:
//! - Pass 1 (Deterministic): Parse transcript.jsonl → extract tool nodes, file
//!   entity nodes, and structural edges (EXTRACTED confidence).
//! - Pass 2 (Semantic): Embed node labels → create similarity edges between
//!   related concepts (INFERRED confidence).
//!
//! Produces `graph.json` and `GRAPH_REPORT.md` per session.

use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::Path;

use serde::{Deserialize, Serialize};

use crate::storage::session_store::TranscriptTurn;
use crate::storage::vault::VaultError;

// ---------------------------------------------------------------------------
// Graph Types
// ---------------------------------------------------------------------------

/// Confidence level of an edge in the knowledge graph.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum EdgeConfidence {
    /// Found directly in source data (tool calls, file paths).
    Extracted,
    /// Inferred via semantic similarity (with confidence score).
    Inferred,
    /// Flagged for manual review.
    Ambiguous,
}

/// A node in the session knowledge graph.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphNode {
    pub id: String,
    pub label: String,
    /// "entity", "concept", "tool", "file", "session"
    pub node_type: String,
    #[serde(default, skip_serializing_if = "HashMap::is_empty")]
    pub properties: HashMap<String, String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub community_id: Option<u32>,
}

/// An edge in the session knowledge graph.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphEdge {
    pub source: String,
    pub target: String,
    pub relation: String,
    pub confidence: EdgeConfidence,
    pub score: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub session_id: Option<String>,
}

/// A complete session knowledge graph.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SessionGraph {
    pub nodes: Vec<GraphNode>,
    pub edges: Vec<GraphEdge>,
    pub metadata: GraphMetadata,
}

/// Metadata about the graph extraction.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GraphMetadata {
    pub session_id: String,
    pub extracted_at: String,
    pub node_count: usize,
    pub edge_count: usize,
    pub extraction_passes: Vec<String>,
}

// ---------------------------------------------------------------------------
// Graph Extraction
// ---------------------------------------------------------------------------

/// Extract a knowledge graph from a session's transcript and summary.
pub fn extract_session_graph(
    transcript_path: &Path,
    summary_path: &Path,
    session_id: &str,
) -> Result<SessionGraph, VaultError> {
    let mut nodes = Vec::new();
    let mut edges = Vec::new();
    let mut node_ids = HashSet::new();

    // Session root node
    let session_node_id = format!("session_{session_id}");
    nodes.push(GraphNode {
        id: session_node_id.clone(),
        label: session_id.to_string(),
        node_type: "session".to_string(),
        properties: HashMap::new(),
        community_id: None,
    });
    node_ids.insert(session_node_id.clone());

    // Pass 1: Deterministic extraction from transcript
    let mut passes = vec!["deterministic_transcript".to_string()];
    if transcript_path.exists() {
        let content = fs::read_to_string(transcript_path)?;
        extract_from_transcript(
            &content,
            &session_node_id,
            &mut nodes,
            &mut edges,
            &mut node_ids,
        );
    }

    // Pass 1b: Extract concepts from summary
    if summary_path.exists() {
        passes.push("summary_concepts".to_string());
        let summary = fs::read_to_string(summary_path)?;
        extract_from_summary(
            &summary,
            &session_node_id,
            &mut nodes,
            &mut edges,
            &mut node_ids,
        );
    }

    // Pass 2: Semantic similarity edges (lightweight, no LLM)
    passes.push("semantic_similarity".to_string());
    add_semantic_edges(&nodes, &mut edges);

    let metadata = GraphMetadata {
        session_id: session_id.to_string(),
        extracted_at: chrono::Utc::now().to_rfc3339(),
        node_count: nodes.len(),
        edge_count: edges.len(),
        extraction_passes: passes,
    };

    Ok(SessionGraph {
        nodes,
        edges,
        metadata,
    })
}

/// Generate a GRAPH_REPORT.md from a session graph.
pub fn generate_graph_report(graph: &SessionGraph) -> String {
    let mut report = String::new();
    report.push_str(&format!(
        "# Graph Report: {}\n\n",
        graph.metadata.session_id
    ));
    report.push_str(&format!(
        "- Extracted at: {}\n",
        graph.metadata.extracted_at
    ));
    report.push_str(&format!("- Nodes: {}\n", graph.metadata.node_count));
    report.push_str(&format!("- Edges: {}\n", graph.metadata.edge_count));
    report.push_str(&format!(
        "- Passes: {}\n\n",
        graph.metadata.extraction_passes.join(", ")
    ));

    // Node type breakdown
    let mut type_counts: HashMap<&str, usize> = HashMap::new();
    for node in &graph.nodes {
        *type_counts.entry(&node.node_type).or_default() += 1;
    }
    report.push_str("## Node Types\n\n");
    for (node_type, count) in &type_counts {
        report.push_str(&format!("- {node_type}: {count}\n"));
    }

    // Top connected nodes (by degree)
    let mut degree: HashMap<&str, usize> = HashMap::new();
    for edge in &graph.edges {
        *degree.entry(&edge.source).or_default() += 1;
        *degree.entry(&edge.target).or_default() += 1;
    }
    let mut sorted_degrees: Vec<(&&str, &usize)> = degree.iter().collect();
    sorted_degrees.sort_by(|a, b| b.1.cmp(a.1));

    report.push_str("\n## Most Connected Nodes (God Nodes)\n\n");
    for (node_id, deg) in sorted_degrees.iter().take(10) {
        let label = graph
            .nodes
            .iter()
            .find(|n| n.id == **node_id)
            .map(|n| n.label.as_str())
            .unwrap_or(*node_id);
        report.push_str(&format!("- **{label}** ({node_id}): {deg} connections\n"));
    }

    // Edge confidence breakdown
    let extracted = graph
        .edges
        .iter()
        .filter(|e| e.confidence == EdgeConfidence::Extracted)
        .count();
    let inferred = graph
        .edges
        .iter()
        .filter(|e| e.confidence == EdgeConfidence::Inferred)
        .count();
    let ambiguous = graph
        .edges
        .iter()
        .filter(|e| e.confidence == EdgeConfidence::Ambiguous)
        .count();
    report.push_str("\n## Edge Confidence\n\n");
    report.push_str(&format!("- Extracted: {extracted}\n"));
    report.push_str(&format!("- Inferred: {inferred}\n"));
    report.push_str(&format!("- Ambiguous: {ambiguous}\n"));

    report
}

// ---------------------------------------------------------------------------
// Pass 1: Deterministic Extraction
// ---------------------------------------------------------------------------

fn extract_from_transcript(
    content: &str,
    session_node_id: &str,
    nodes: &mut Vec<GraphNode>,
    edges: &mut Vec<GraphEdge>,
    node_ids: &mut HashSet<String>,
) {
    for line in content.lines() {
        if line.is_empty() {
            continue;
        }
        let turn: TranscriptTurn = match serde_json::from_str(line) {
            Ok(t) => t,
            Err(_) => continue,
        };

        // Extract tool nodes
        for tool_call in &turn.tool_calls {
            let tool_id = format!("tool_{}", tool_call.name);
            if node_ids.insert(tool_id.clone()) {
                nodes.push(GraphNode {
                    id: tool_id.clone(),
                    label: tool_call.name.clone(),
                    node_type: "tool".to_string(),
                    properties: HashMap::new(),
                    community_id: None,
                });
            }

            edges.push(GraphEdge {
                source: session_node_id.to_string(),
                target: tool_id.clone(),
                relation: "uses_tool".to_string(),
                confidence: EdgeConfidence::Extracted,
                score: 1.0,
                session_id: None,
            });

            // Extract file entities from tool input/output
            if let Some(ref input) = tool_call.input_summary {
                extract_file_entities(input, &tool_id, "modifies", nodes, edges, node_ids);
            }
            if let Some(ref output) = tool_call.result_summary {
                extract_file_entities(output, &tool_id, "reads", nodes, edges, node_ids);
            }
        }
    }
}

fn extract_file_entities(
    text: &str,
    source_node_id: &str,
    relation: &str,
    nodes: &mut Vec<GraphNode>,
    edges: &mut Vec<GraphEdge>,
    node_ids: &mut HashSet<String>,
) {
    // Simple heuristic: find path-like strings
    for word in text.split_whitespace() {
        let trimmed =
            word.trim_matches(|c: char| !c.is_alphanumeric() && c != '/' && c != '.' && c != '_');
        if looks_like_file_path(trimmed) {
            let file_id = format!("file_{}", trimmed.replace('/', "_"));
            if node_ids.insert(file_id.clone()) {
                nodes.push(GraphNode {
                    id: file_id.clone(),
                    label: trimmed.to_string(),
                    node_type: "file".to_string(),
                    properties: HashMap::new(),
                    community_id: None,
                });
            }
            edges.push(GraphEdge {
                source: source_node_id.to_string(),
                target: file_id,
                relation: relation.to_string(),
                confidence: EdgeConfidence::Extracted,
                score: 1.0,
                session_id: None,
            });
        }
    }
}

fn looks_like_file_path(text: &str) -> bool {
    if text.len() < 3 {
        return false;
    }
    let extensions = [
        ".rs", ".swift", ".md", ".json", ".toml", ".yaml", ".yml", ".py", ".ts", ".js",
    ];
    extensions.iter().any(|ext| text.ends_with(ext))
        || (text.contains('/') && !text.starts_with("http"))
}

// ---------------------------------------------------------------------------
// Pass 1b: Summary Concept Extraction
// ---------------------------------------------------------------------------

fn extract_from_summary(
    summary: &str,
    session_node_id: &str,
    nodes: &mut Vec<GraphNode>,
    edges: &mut Vec<GraphEdge>,
    node_ids: &mut HashSet<String>,
) {
    // Extract section headers as concept nodes
    for line in summary.lines() {
        if let Some(header) = line.strip_prefix("## ") {
            let concept_id = format!("concept_{}", header.replace(' ', "_").to_lowercase());
            if node_ids.insert(concept_id.clone()) {
                nodes.push(GraphNode {
                    id: concept_id.clone(),
                    label: header.to_string(),
                    node_type: "concept".to_string(),
                    properties: HashMap::new(),
                    community_id: None,
                });
                edges.push(GraphEdge {
                    source: session_node_id.to_string(),
                    target: concept_id,
                    relation: "discusses".to_string(),
                    confidence: EdgeConfidence::Extracted,
                    score: 0.8,
                    session_id: None,
                });
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Pass 2: Semantic Similarity Edges
// ---------------------------------------------------------------------------

fn add_semantic_edges(nodes: &[GraphNode], edges: &mut Vec<GraphEdge>) {
    // Use simple word overlap as a lightweight "semantic" signal
    // (full embedding-based similarity deferred to Phase 6 with LLM integration)
    let content_nodes: Vec<&GraphNode> =
        nodes.iter().filter(|n| n.node_type != "session").collect();

    for i in 0..content_nodes.len() {
        for j in (i + 1)..content_nodes.len() {
            let a = content_nodes[i];
            let b = content_nodes[j];
            let sim = word_overlap_similarity(&a.label, &b.label);
            if sim > 0.5 && a.node_type != b.node_type {
                edges.push(GraphEdge {
                    source: a.id.clone(),
                    target: b.id.clone(),
                    relation: "related_to".to_string(),
                    confidence: EdgeConfidence::Inferred,
                    score: sim,
                    session_id: None,
                });
            }
        }
    }
}

fn word_overlap_similarity(a: &str, b: &str) -> f64 {
    let a_lower = a.to_lowercase();
    let b_lower = b.to_lowercase();
    let a_words: HashSet<&str> = a_lower
        .split(|c: char| !c.is_alphanumeric())
        .filter(|s| !s.is_empty())
        .collect();
    let b_words: HashSet<&str> = b_lower
        .split(|c: char| !c.is_alphanumeric())
        .filter(|s| !s.is_empty())
        .collect();
    if a_words.is_empty() || b_words.is_empty() {
        return 0.0;
    }
    let overlap = a_words.intersection(&b_words).count();
    let max_len = a_words.len().max(b_words.len());
    overlap as f64 / max_len as f64
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn write_transcript(dir: &Path, turns: &[&str]) -> std::path::PathBuf {
        let path = dir.join("transcript.jsonl");
        let content = turns.join("\n");
        fs::write(&path, content).unwrap();
        path
    }

    #[test]
    fn extract_empty_transcript() {
        let tmp = TempDir::new().unwrap();
        let transcript = write_transcript(tmp.path(), &[]);
        let summary = tmp.path().join("summary.md");
        let graph = extract_session_graph(&transcript, &summary, "test1").unwrap();
        assert_eq!(graph.nodes.len(), 1); // just the session node
        assert!(graph.edges.is_empty());
    }

    #[test]
    fn extract_tool_nodes() {
        let tmp = TempDir::new().unwrap();
        let turn_json = serde_json::json!({
            "timestamp": "2026-04-08T00:00:00Z",
            "role": "assistant",
            "content": "Running bash",
            "tool_calls": [{
                "name": "bash",
                "tool_use_id": "tc_1",
                "input_summary": "ls src/main.rs",
                "result_summary": "file exists",
                "is_error": false
            }]
        });
        let transcript = write_transcript(tmp.path(), &[&turn_json.to_string()]);
        let summary = tmp.path().join("summary.md");

        let graph = extract_session_graph(&transcript, &summary, "test2").unwrap();

        // Should have: session node + tool node + file node
        assert!(graph.nodes.len() >= 2);
        assert!(graph
            .nodes
            .iter()
            .any(|n| n.node_type == "tool" && n.label == "bash"));

        // Should have: uses_tool edge
        assert!(graph.edges.iter().any(|e| e.relation == "uses_tool"));
    }

    #[test]
    fn extract_file_entities_from_paths() {
        let tmp = TempDir::new().unwrap();
        let turn_json = serde_json::json!({
            "timestamp": "2026-04-08T00:00:00Z",
            "role": "assistant",
            "content": "Editing file",
            "tool_calls": [{
                "name": "vault_write",
                "tool_use_id": "tc_2",
                "input_summary": "writing to memory/decisions.md",
                "result_summary": null,
                "is_error": false
            }]
        });
        let transcript = write_transcript(tmp.path(), &[&turn_json.to_string()]);
        let summary = tmp.path().join("summary.md");

        let graph = extract_session_graph(&transcript, &summary, "test3").unwrap();
        assert!(graph
            .nodes
            .iter()
            .any(|n| n.node_type == "file" && n.label.contains("decisions.md")));
    }

    #[test]
    fn extract_concepts_from_summary() {
        let tmp = TempDir::new().unwrap();
        let transcript = write_transcript(tmp.path(), &[]);
        let summary_path = tmp.path().join("summary.md");
        fs::write(
            &summary_path,
            "# Summary\n\n## Key Decisions\nSome decisions\n\n## Tool Usage\nSome tools\n",
        )
        .unwrap();

        let graph = extract_session_graph(&transcript, &summary_path, "test4").unwrap();
        assert!(graph
            .nodes
            .iter()
            .any(|n| n.node_type == "concept" && n.label == "Key Decisions"));
        assert!(graph
            .nodes
            .iter()
            .any(|n| n.node_type == "concept" && n.label == "Tool Usage"));
    }

    #[test]
    fn graph_report_generation() {
        let graph = SessionGraph {
            nodes: vec![
                GraphNode {
                    id: "s1".into(),
                    label: "session".into(),
                    node_type: "session".into(),
                    properties: HashMap::new(),
                    community_id: None,
                },
                GraphNode {
                    id: "t1".into(),
                    label: "bash".into(),
                    node_type: "tool".into(),
                    properties: HashMap::new(),
                    community_id: None,
                },
            ],
            edges: vec![GraphEdge {
                source: "s1".into(),
                target: "t1".into(),
                relation: "uses".into(),
                confidence: EdgeConfidence::Extracted,
                score: 1.0,
                session_id: None,
            }],
            metadata: GraphMetadata {
                session_id: "test5".into(),
                extracted_at: "2026-04-08".into(),
                node_count: 2,
                edge_count: 1,
                extraction_passes: vec!["deterministic".into()],
            },
        };

        let report = generate_graph_report(&graph);
        assert!(report.contains("# Graph Report: test5"));
        assert!(report.contains("Nodes: 2"));
        assert!(report.contains("Edges: 1"));
        assert!(report.contains("Extracted: 1"));
    }

    #[test]
    fn looks_like_file_path_tests() {
        assert!(looks_like_file_path("src/main.rs"));
        assert!(looks_like_file_path("memory/decisions.md"));
        assert!(looks_like_file_path("config.toml"));
        assert!(!looks_like_file_path("hello"));
        assert!(!looks_like_file_path("ab"));
        assert!(!looks_like_file_path("https://example.com/path"));
    }
}
