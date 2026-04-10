//! Graph Query Tool — Knowledge graph traversal for PKM
//!
//! Query the vault's knowledge graph: find backlinks, neighbors, orphan nodes,
//! tag-based clusters, and shortest paths between concepts.
//! This is a PKM-specific tool that no general-purpose agent framework provides.

use serde_json::{json, Value};
use std::collections::{HashMap, HashSet, VecDeque};
use std::sync::Arc;

use super::registry::{ToolError, ToolHandler};
use crate::storage::vault::VaultBackend;

pub struct GraphQueryTool {
    vault: Arc<dyn VaultBackend>,
}

impl GraphQueryTool {
    pub fn new(vault: Arc<dyn VaultBackend>) -> Self {
        Self { vault }
    }

    /// Parse wikilinks [[target]] and [[target|alias]] from note content.
    fn extract_links(content: &str) -> Vec<String> {
        let mut links = Vec::new();
        let mut pos = 0;
        let bytes = content.as_bytes();
        while pos + 3 < bytes.len() {
            if bytes[pos] == b'[' && bytes[pos + 1] == b'[' {
                if let Some(end) = content[pos + 2..].find("]]") {
                    let inner = &content[pos + 2..pos + 2 + end];
                    // Handle [[target|alias]] → take target
                    let target = inner.split('|').next().unwrap_or(inner).trim();
                    if !target.is_empty() {
                        links.push(target.to_string());
                    }
                    pos = pos + 2 + end + 2;
                } else {
                    pos += 1;
                }
            } else {
                pos += 1;
            }
        }
        links
    }

    /// Parse tags from frontmatter and inline #tags.
    fn extract_tags(content: &str) -> Vec<String> {
        let mut tags = Vec::new();
        for word in content.split_whitespace() {
            if word.starts_with('#') && word.len() > 1 {
                let tag = word.trim_matches(|c: char| !c.is_alphanumeric() && c != '-' && c != '_' && c != '/');
                if !tag.is_empty() {
                    tags.push(tag.to_string());
                }
            }
        }
        tags.sort();
        tags.dedup();
        tags
    }

    /// Build adjacency list from vault notes.
    fn build_graph(&self) -> Result<NoteGraph, ToolError> {
        let root = self.vault.root_path()
            .ok_or_else(|| ToolError::ExecutionFailed("vault has no root path".into()))?;

        let mut graph = NoteGraph::default();
        Self::scan_directory(&root, &root, &mut graph)?;
        Ok(graph)
    }

    fn scan_directory(root: &std::path::Path, dir: &std::path::Path, graph: &mut NoteGraph) -> Result<(), ToolError> {
        let entries = std::fs::read_dir(dir).map_err(|e| ToolError::ExecutionFailed(e.to_string()))?;
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                if path.file_name().map_or(false, |n| n.to_string_lossy().starts_with('.')) {
                    continue;
                }
                Self::scan_directory(root, &path, graph)?;
            } else if path.extension().map_or(false, |ext| ext == "md") {
                let rel_path = path.strip_prefix(root).unwrap_or(&path);
                let name = rel_path.to_string_lossy().to_string();
                let stem = path.file_stem()
                    .map(|s| s.to_string_lossy().to_string())
                    .unwrap_or_default();

                if let Ok(content) = std::fs::read_to_string(&path) {
                    let links = Self::extract_links(&content);
                    let tags = Self::extract_tags(&content);
                    let word_count = content.split_whitespace().count();

                    graph.nodes.insert(stem.clone(), NoteNode {
                        path: name,
                        stem: stem.clone(),
                        outgoing_links: links,
                        tags,
                        word_count,
                    });
                }
            }
        }
        Ok(())
    }
}

#[derive(Default)]
struct NoteGraph {
    nodes: HashMap<String, NoteNode>,
}

struct NoteNode {
    path: String,
    stem: String,
    outgoing_links: Vec<String>,
    tags: Vec<String>,
    word_count: usize,
}

impl NoteGraph {
    /// Find all notes that link TO the given note (backlinks).
    fn backlinks(&self, target: &str) -> Vec<String> {
        let target_lower = target.to_lowercase();
        self.nodes
            .values()
            .filter(|n| n.outgoing_links.iter().any(|l| l.to_lowercase() == target_lower))
            .map(|n| n.stem.clone())
            .collect()
    }

    /// Find notes with no incoming links (orphans).
    fn orphans(&self) -> Vec<String> {
        let all_targets: HashSet<String> = self.nodes
            .values()
            .flat_map(|n| n.outgoing_links.iter().map(|l| l.to_lowercase()))
            .collect();

        self.nodes
            .values()
            .filter(|n| !all_targets.contains(&n.stem.to_lowercase()))
            .map(|n| n.stem.clone())
            .collect()
    }

    /// Find notes with a specific tag.
    fn by_tag(&self, tag: &str) -> Vec<String> {
        let tag_clean = tag.strip_prefix('#').unwrap_or(tag);
        self.nodes
            .values()
            .filter(|n| n.tags.iter().any(|t| {
                let t_clean = t.strip_prefix('#').unwrap_or(t);
                t_clean == tag_clean
            }))
            .map(|n| n.stem.clone())
            .collect()
    }

    /// BFS shortest path between two notes.
    fn shortest_path(&self, from: &str, to: &str) -> Option<Vec<String>> {
        let from_lower = from.to_lowercase();
        let to_lower = to.to_lowercase();

        let mut visited = HashSet::new();
        let mut queue = VecDeque::new();
        queue.push_back(vec![from_lower.clone()]);
        visited.insert(from_lower);

        while let Some(path) = queue.pop_front() {
            let current = path.last().unwrap();
            if *current == to_lower {
                return Some(path);
            }
            if let Some(node) = self.nodes.values().find(|n| n.stem.to_lowercase() == *current) {
                for link in &node.outgoing_links {
                    let link_lower = link.to_lowercase();
                    if !visited.contains(&link_lower) {
                        visited.insert(link_lower.clone());
                        let mut new_path = path.clone();
                        new_path.push(link_lower);
                        queue.push_back(new_path);
                    }
                }
            }
        }
        None
    }

    /// Vault statistics.
    fn stats(&self) -> Value {
        let total_notes = self.nodes.len();
        let total_links: usize = self.nodes.values().map(|n| n.outgoing_links.len()).sum();
        let total_words: usize = self.nodes.values().map(|n| n.word_count).sum();
        let orphan_count = self.orphans().len();

        let mut tag_counts: HashMap<String, usize> = HashMap::new();
        for node in self.nodes.values() {
            for tag in &node.tags {
                *tag_counts.entry(tag.clone()).or_default() += 1;
            }
        }
        let mut top_tags: Vec<_> = tag_counts.into_iter().collect();
        top_tags.sort_by(|a, b| b.1.cmp(&a.1));
        top_tags.truncate(10);

        json!({
            "total_notes": total_notes,
            "total_links": total_links,
            "total_words": total_words,
            "orphan_notes": orphan_count,
            "top_tags": top_tags.into_iter().map(|(t, c)| json!({"tag": t, "count": c})).collect::<Vec<_>>(),
        })
    }
}

#[async_trait::async_trait]
impl ToolHandler for GraphQueryTool {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let action = input["action"].as_str().unwrap_or("stats");
        let graph = self.build_graph()?;

        match action {
            "backlinks" => {
                let target = input["note"].as_str()
                    .ok_or_else(|| ToolError::InvalidArguments("note required for backlinks".into()))?;
                let links = graph.backlinks(target);
                Ok(json!({"backlinks": links, "count": links.len()}).to_string())
            }
            "orphans" => {
                let orphans = graph.orphans();
                Ok(json!({"orphans": orphans, "count": orphans.len()}).to_string())
            }
            "by_tag" => {
                let tag = input["tag"].as_str()
                    .ok_or_else(|| ToolError::InvalidArguments("tag required".into()))?;
                let notes = graph.by_tag(tag);
                Ok(json!({"notes": notes, "count": notes.len()}).to_string())
            }
            "shortest_path" => {
                let from = input["from"].as_str()
                    .ok_or_else(|| ToolError::InvalidArguments("from required".into()))?;
                let to = input["to"].as_str()
                    .ok_or_else(|| ToolError::InvalidArguments("to required".into()))?;
                match graph.shortest_path(from, to) {
                    Some(path) => Ok(json!({"path": path, "hops": path.len() - 1}).to_string()),
                    None => Ok(json!({"path": null, "hops": -1, "message": "No path found"}).to_string()),
                }
            }
            "stats" => Ok(graph.stats().to_string()),
            _ => Ok(json!({"error": format!("Unknown action: {action}")}).to_string()),
        }
    }
}

pub fn graph_query_tool_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "graph_query".to_string(),
        description: "Query the knowledge graph: find backlinks, orphan notes, tag clusters, shortest paths between concepts, and vault statistics.".to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["backlinks", "orphans", "by_tag", "shortest_path", "stats"],
                    "description": "Query type"
                },
                "note": { "type": "string", "description": "Note name (for backlinks)" },
                "tag": { "type": "string", "description": "Tag to search (for by_tag)" },
                "from": { "type": "string", "description": "Source note (for shortest_path)" },
                "to": { "type": "string", "description": "Target note (for shortest_path)" }
            },
            "required": ["action"]
        }),
    }
}
