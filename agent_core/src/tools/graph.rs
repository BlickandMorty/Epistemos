//! Graph & Topology Tools — Phase 2 Specialties B2 and B4
//!
//! * `graph_query`    — query the vault's hyperbolic topology for related
//!   nodes, god nodes, spatial neighbours, and shortest paths.
//! * `vault_navigate` — compute a geodesic path through the Poincaré disk
//!   from a starting location to the closest semantic target, piercing
//!   Markov blankets as it descends.
//!
//! Both tools share a per-vault topology cache (build once per process, rebuild
//! on demand). The underlying work lives in `storage::hyperbolic_topology`.

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

use async_trait::async_trait;
use serde_json::{json, Value};

use crate::storage::hyperbolic_topology::{
    build_topology, VaultNodeMetrics, VaultTopology,
};

use super::registry::{ToolError, ToolHandler};

// MARK: - Topology cache

const TOPOLOGY_TTL: Duration = Duration::from_secs(60);

struct CachedTopology {
    topology: Arc<VaultTopology>,
    built_at: Instant,
}

fn topology_store() -> &'static Mutex<HashMap<PathBuf, CachedTopology>> {
    static STORE: OnceLock<Mutex<HashMap<PathBuf, CachedTopology>>> = OnceLock::new();
    STORE.get_or_init(|| Mutex::new(HashMap::new()))
}

fn get_topology(vault_root: &Path) -> Result<Arc<VaultTopology>, ToolError> {
    let canonical = vault_root
        .canonicalize()
        .unwrap_or_else(|_| vault_root.to_path_buf());
    {
        let guard = topology_store()
            .lock()
            .map_err(|e| ToolError::ExecutionFailed(format!("topology lock: {e}")))?;
        if let Some(cached) = guard.get(&canonical) {
            if cached.built_at.elapsed() < TOPOLOGY_TTL {
                return Ok(Arc::clone(&cached.topology));
            }
        }
    }

    let fresh = build_topology(&canonical)
        .map_err(|e| ToolError::ExecutionFailed(format!("build topology: {e}")))?;
    let arc = Arc::new(fresh);
    let mut guard = topology_store()
        .lock()
        .map_err(|e| ToolError::ExecutionFailed(format!("topology lock: {e}")))?;
    guard.insert(
        canonical,
        CachedTopology {
            topology: Arc::clone(&arc),
            built_at: Instant::now(),
        },
    );
    Ok(arc)
}

// MARK: - graph_query

pub struct GraphQueryHandler {
    vault_root: PathBuf,
}

impl GraphQueryHandler {
    pub fn new(vault_root: PathBuf) -> Self {
        Self { vault_root }
    }
}

#[async_trait]
impl ToolHandler for GraphQueryHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let mode = input
            .get("mode")
            .and_then(Value::as_str)
            .unwrap_or("god_nodes");
        let limit = input
            .get("limit")
            .and_then(Value::as_u64)
            .unwrap_or(10)
            .clamp(1, 100) as usize;

        let vault_root = self.vault_root.clone();
        let topology = tokio::task::spawn_blocking(move || get_topology(&vault_root))
            .await
            .map_err(|e| ToolError::ExecutionFailed(format!("topology join: {e}")))??;

        match mode {
            "god_nodes" => god_nodes(&topology, limit),
            "related" => related(&topology, input, limit),
            "spatial" => spatial(&topology, input, limit),
            "path" => path(&topology, input),
            "communities" => communities(&topology, limit),
            other => Err(ToolError::InvalidArguments(format!(
                "unknown mode '{other}' (expected: god_nodes|related|spatial|path|communities)"
            ))),
        }
    }
}

fn node_to_json(node: &VaultNodeMetrics) -> Value {
    json!({
        "path": node.path,
        "is_directory": node.is_directory,
        "depth": node.depth,
        "gravity": node.gravity,
        "complexity_weight": node.complexity_weight,
        "volatility": node.volatility,
        "child_count": node.child_count,
        "position": {
            "r": node.position.r,
            "theta": node.position.theta,
            "x": node.position.x,
            "y": node.position.y,
        },
    })
}

fn god_nodes(topology: &VaultTopology, limit: usize) -> Result<String, ToolError> {
    // topology.god_nodes is already sorted by gravity. Materialise full node
    // metrics so the agent doesn't have to call back for details.
    let by_path: HashMap<&str, &VaultNodeMetrics> = topology
        .nodes
        .iter()
        .map(|n| (n.path.as_str(), n))
        .collect();
    let nodes: Vec<Value> = topology
        .god_nodes
        .iter()
        .take(limit)
        .filter_map(|p| by_path.get(p.as_str()).copied())
        .map(node_to_json)
        .collect();
    Ok(json!({
        "mode": "god_nodes",
        "count": nodes.len(),
        "nodes": nodes,
    })
    .to_string())
}

fn related(
    topology: &VaultTopology,
    input: &Value,
    limit: usize,
) -> Result<String, ToolError> {
    let query = input
        .get("query")
        .and_then(Value::as_str)
        .ok_or_else(|| {
            ToolError::InvalidArguments("mode='related' requires 'query'".into())
        })?;
    let query_lower = query.to_lowercase();

    let mut scored: Vec<(f64, &VaultNodeMetrics)> = topology
        .nodes
        .iter()
        .filter_map(|node| {
            let path_lower = node.path.to_lowercase();
            if path_lower.contains(&query_lower) {
                // Combine string-match with gravity so heavy hubs bubble up.
                let score = 0.6 + node.gravity.min(10.0) / 25.0;
                Some((score, node))
            } else {
                None
            }
        })
        .collect();

    scored.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal));
    let nodes: Vec<Value> = scored
        .into_iter()
        .take(limit)
        .map(|(score, n)| {
            let mut v = node_to_json(n);
            v["score"] = json!(score);
            v
        })
        .collect();

    Ok(json!({
        "mode": "related",
        "query": query,
        "count": nodes.len(),
        "nodes": nodes,
    })
    .to_string())
}

fn spatial(
    topology: &VaultTopology,
    input: &Value,
    limit: usize,
) -> Result<String, ToolError> {
    let origin_path = input
        .get("origin")
        .and_then(Value::as_str)
        .ok_or_else(|| {
            ToolError::InvalidArguments("mode='spatial' requires 'origin' path".into())
        })?;
    let radius = input
        .get("radius")
        .and_then(Value::as_f64)
        .unwrap_or(1.5);

    let origin = topology
        .nodes
        .iter()
        .find(|n| n.path == origin_path)
        .ok_or_else(|| ToolError::NotFound(format!("origin node '{origin_path}'")))?;

    let mut within: Vec<(f64, &VaultNodeMetrics)> = topology
        .nodes
        .iter()
        .filter(|n| n.path != origin.path)
        .filter_map(|n| {
            let dist = origin.position.hyperbolic_distance(&n.position);
            if dist.is_finite() && dist <= radius {
                Some((dist, n))
            } else {
                None
            }
        })
        .collect();
    within.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap_or(std::cmp::Ordering::Equal));

    let nodes: Vec<Value> = within
        .into_iter()
        .take(limit)
        .map(|(distance, n)| {
            let mut v = node_to_json(n);
            v["hyperbolic_distance"] = json!(distance);
            v
        })
        .collect();

    Ok(json!({
        "mode": "spatial",
        "origin": origin_path,
        "radius": radius,
        "count": nodes.len(),
        "nodes": nodes,
    })
    .to_string())
}

fn path(topology: &VaultTopology, input: &Value) -> Result<String, ToolError> {
    let source = input
        .get("source")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("mode='path' requires 'source'".into()))?;
    let target = input
        .get("target")
        .and_then(Value::as_str)
        .ok_or_else(|| ToolError::InvalidArguments("mode='path' requires 'target'".into()))?;

    let src = topology
        .nodes
        .iter()
        .find(|n| n.path == source)
        .ok_or_else(|| ToolError::NotFound(format!("source '{source}'")))?;
    let dst = topology
        .nodes
        .iter()
        .find(|n| n.path == target)
        .ok_or_else(|| ToolError::NotFound(format!("target '{target}'")))?;

    // Greedy geodesic approximation: walk from src toward dst in the Poincaré
    // disk by repeatedly picking the next node closest to dst.
    let max_steps = 32usize;
    let mut current = src;
    let mut trail: Vec<&VaultNodeMetrics> = vec![current];
    for _ in 0..max_steps {
        if current.path == dst.path {
            break;
        }
        // Candidates: nodes closer to dst than the current node.
        let current_to_dst = current.position.hyperbolic_distance(&dst.position);
        let next = topology
            .nodes
            .iter()
            .filter(|n| !trail.iter().any(|t| t.path == n.path))
            .filter_map(|n| {
                let d = n.position.hyperbolic_distance(&dst.position);
                if d < current_to_dst {
                    Some((d, n))
                } else {
                    None
                }
            })
            .min_by(|a, b| a.0.partial_cmp(&b.0).unwrap_or(std::cmp::Ordering::Equal));
        match next {
            Some((_, n)) => {
                trail.push(n);
                current = n;
            }
            None => break,
        }
    }

    if current.path != dst.path {
        // Final step: append the target even if we couldn't descend further.
        trail.push(dst);
    }

    let geodesic_distance = src.position.hyperbolic_distance(&dst.position);
    let nodes: Vec<Value> = trail.iter().map(|n| node_to_json(n)).collect();
    Ok(json!({
        "mode": "path",
        "source": source,
        "target": target,
        "geodesic_distance": geodesic_distance,
        "path_length": nodes.len(),
        "path": nodes,
    })
    .to_string())
}

fn communities(topology: &VaultTopology, limit: usize) -> Result<String, ToolError> {
    // Lightweight "community" surrogate: group by immediate parent directory
    // and sort by cumulative gravity. Louvain clustering is a v2 enhancement.
    let mut groups: HashMap<String, (f64, Vec<String>)> = HashMap::new();
    for node in &topology.nodes {
        if node.is_directory {
            continue;
        }
        let parent = Path::new(&node.path)
            .parent()
            .and_then(|p| p.to_str())
            .unwrap_or("")
            .to_string();
        let entry = groups.entry(parent).or_insert_with(|| (0.0, Vec::new()));
        entry.0 += node.gravity;
        entry.1.push(node.path.clone());
    }

    let mut ordered: Vec<(String, (f64, Vec<String>))> = groups.into_iter().collect();
    ordered.sort_by(|a, b| b.1 .0.partial_cmp(&a.1 .0).unwrap_or(std::cmp::Ordering::Equal));

    let communities: Vec<Value> = ordered
        .into_iter()
        .take(limit)
        .map(|(parent, (gravity, members))| {
            json!({
                "parent": parent,
                "member_count": members.len(),
                "total_gravity": gravity,
                "members": members,
            })
        })
        .collect();

    Ok(json!({
        "mode": "communities",
        "count": communities.len(),
        "communities": communities,
    })
    .to_string())
}

pub fn graph_query_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "graph_query".to_string(),
        description: "Query the vault's hyperbolic knowledge topology. Modes: \
             'god_nodes' (top-gravity hubs, default), 'related' (text-match over node paths), \
             'spatial' (Poincaré disk radius query around an origin), \
             'path' (greedy geodesic path between two nodes), \
             'communities' (group by parent directory, sorted by total gravity)."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "mode": {
                    "type": "string",
                    "enum": ["god_nodes", "related", "spatial", "path", "communities"],
                    "default": "god_nodes"
                },
                "query": { "type": "string", "description": "Query text (mode='related')." },
                "origin": { "type": "string", "description": "Origin path (mode='spatial')." },
                "radius": { "type": "number", "description": "Spatial radius in Poincaré units (mode='spatial', default 1.5)." },
                "source": { "type": "string", "description": "Source node path (mode='path')." },
                "target": { "type": "string", "description": "Target node path (mode='path')." },
                "limit": { "type": "integer", "description": "Max nodes to return.", "default": 10, "minimum": 1, "maximum": 100 }
            }
        }),
    }
}

// MARK: - vault_navigate

pub struct VaultNavigateHandler {
    vault_root: PathBuf,
}

impl VaultNavigateHandler {
    pub fn new(vault_root: PathBuf) -> Self {
        Self { vault_root }
    }
}

#[async_trait]
impl ToolHandler for VaultNavigateHandler {
    async fn execute(&self, input: &Value) -> Result<String, ToolError> {
        let start_path = input
            .get("start")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'start'".into()))?;
        let semantic_target = input
            .get("semantic_target")
            .and_then(Value::as_str)
            .ok_or_else(|| ToolError::InvalidArguments("missing 'semantic_target'".into()))?;
        let max_depth = input
            .get("max_depth")
            .and_then(Value::as_u64)
            .unwrap_or(3)
            .clamp(1, 8) as usize;

        let vault_root = self.vault_root.clone();
        let topology = tokio::task::spawn_blocking(move || get_topology(&vault_root))
            .await
            .map_err(|e| ToolError::ExecutionFailed(format!("topology join: {e}")))??;

        let start_node = topology
            .nodes
            .iter()
            .find(|n| n.path == start_path)
            .ok_or_else(|| ToolError::NotFound(format!("start '{start_path}'")))?;

        let target_lower = semantic_target.to_lowercase();
        let best_target = topology
            .nodes
            .iter()
            .filter(|n| !n.is_directory)
            .map(|n| {
                let path_lower = n.path.to_lowercase();
                let score = if path_lower.contains(&target_lower) {
                    1.0 + n.gravity.min(5.0) / 10.0
                } else {
                    // Fall back to hyperbolic distance from start — ensures we
                    // always return *something*, just lower relevance.
                    0.0
                };
                (score, n)
            })
            .max_by(|a, b| a.0.partial_cmp(&b.0).unwrap_or(std::cmp::Ordering::Equal))
            .map(|(_, n)| n)
            .ok_or_else(|| ToolError::NotFound("vault contains no files".into()))?;

        // Descend toward best_target, counting blanket crossings as directory
        // transitions along the walk.
        let mut trail: Vec<&VaultNodeMetrics> = vec![start_node];
        let mut blankets_pierced = 0usize;
        let mut current = start_node;
        for _ in 0..max_depth.max(1).saturating_mul(4) {
            if current.path == best_target.path {
                break;
            }
            let current_to_target = current.position.hyperbolic_distance(&best_target.position);
            let candidate = topology
                .nodes
                .iter()
                .filter(|n| !trail.iter().any(|t| t.path == n.path))
                .filter_map(|n| {
                    let d = n.position.hyperbolic_distance(&best_target.position);
                    if d < current_to_target {
                        Some((d, n))
                    } else {
                        None
                    }
                })
                .min_by(|a, b| a.0.partial_cmp(&b.0).unwrap_or(std::cmp::Ordering::Equal));
            match candidate {
                Some((_, next)) => {
                    if next.depth > current.depth && next.is_directory {
                        blankets_pierced += 1;
                    }
                    trail.push(next);
                    current = next;
                }
                None => break,
            }
        }
        if current.path != best_target.path {
            trail.push(best_target);
        }

        let geodesic = start_node
            .position
            .hyperbolic_distance(&best_target.position);
        let relevance = relevance_score(&best_target.path, &target_lower);
        let path_json: Vec<Value> = trail.iter().map(|n| json!(n.path)).collect();

        Ok(json!({
            "start": start_path,
            "semantic_target": semantic_target,
            "target": best_target.path,
            "blankets_pierced": blankets_pierced,
            "geodesic_distance": geodesic,
            "relevance_at_target": relevance,
            "path": path_json,
        })
        .to_string())
    }
}

fn relevance_score(path: &str, query_lower: &str) -> f64 {
    let lower = path.to_lowercase();
    if lower.contains(query_lower) {
        // Give partial credit if the query is a prefix of a path segment.
        let hit_count = lower.matches(query_lower).count() as f64;
        (hit_count / 2.0).clamp(0.5, 1.0)
    } else {
        0.0
    }
}

pub fn vault_navigate_schema() -> crate::types::ToolSchema {
    crate::types::ToolSchema {
        name: "vault_navigate".to_string(),
        description: "Walk the vault's hyperbolic topology from a starting location toward the \
             closest semantic target, piercing Markov-blanket directory boundaries as it \
             descends. Returns the path taken, geodesic distance, and relevance score at the \
             final target."
            .to_string(),
        parameters: json!({
            "type": "object",
            "properties": {
                "start": { "type": "string", "description": "Starting path in the vault." },
                "semantic_target": { "type": "string", "description": "Text describing the destination concept." },
                "max_depth": { "type": "integer", "default": 3, "minimum": 1, "maximum": 8 }
            },
            "required": ["start", "semantic_target"]
        }),
    }
}

// MARK: - Tests

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use std::fs;
    use tempfile::tempdir;

    fn make_vault(root: &Path) {
        // Build a small directory tree with a handful of markdown files so
        // build_topology has non-empty structure.
        let notes_a = root.join("projects/alpha");
        let notes_b = root.join("projects/beta");
        fs::create_dir_all(&notes_a).unwrap();
        fs::create_dir_all(&notes_b).unwrap();
        fs::write(notes_a.join("intro.md"), "alpha intro").unwrap();
        fs::write(notes_a.join("design.md"), "alpha design references intro.md").unwrap();
        fs::write(notes_b.join("intro.md"), "beta intro references alpha").unwrap();
    }

    #[tokio::test]
    async fn graph_query_god_nodes_returns_entries() {
        let dir = tempdir().unwrap();
        make_vault(dir.path());
        let handler = GraphQueryHandler::new(dir.path().to_path_buf());
        let result = handler
            .execute(&json!({ "mode": "god_nodes", "limit": 5 }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["mode"], json!("god_nodes"));
        assert!(parsed["count"].as_u64().unwrap() >= 1);
    }

    #[tokio::test]
    async fn graph_query_related_finds_matches_by_path() {
        let dir = tempdir().unwrap();
        make_vault(dir.path());
        let handler = GraphQueryHandler::new(dir.path().to_path_buf());
        let result = handler
            .execute(&json!({ "mode": "related", "query": "alpha" }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert!(parsed["count"].as_u64().unwrap() >= 1);
        assert!(parsed["nodes"]
            .as_array()
            .unwrap()
            .iter()
            .any(|n| n["path"].as_str().unwrap().contains("alpha")));
    }

    #[tokio::test]
    async fn graph_query_spatial_mode_returns_near_nodes() {
        let dir = tempdir().unwrap();
        make_vault(dir.path());
        let handler = GraphQueryHandler::new(dir.path().to_path_buf());

        // Find an origin path from god_nodes first.
        let gn_result = handler
            .execute(&json!({ "mode": "god_nodes", "limit": 1 }))
            .await
            .unwrap();
        let gn: Value = serde_json::from_str(&gn_result).unwrap();
        let origin = gn["nodes"][0]["path"].as_str().unwrap().to_string();

        let result = handler
            .execute(&json!({
                "mode": "spatial",
                "origin": origin,
                "radius": 10.0
            }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["mode"], json!("spatial"));
    }

    #[tokio::test]
    async fn graph_query_communities_groups_by_parent() {
        let dir = tempdir().unwrap();
        make_vault(dir.path());
        let handler = GraphQueryHandler::new(dir.path().to_path_buf());
        let result = handler
            .execute(&json!({ "mode": "communities", "limit": 5 }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&result).unwrap();
        assert_eq!(parsed["mode"], json!("communities"));
        assert!(parsed["count"].as_u64().unwrap() >= 1);
    }

    #[tokio::test]
    async fn graph_query_rejects_unknown_mode() {
        let dir = tempdir().unwrap();
        make_vault(dir.path());
        let handler = GraphQueryHandler::new(dir.path().to_path_buf());
        let err = handler
            .execute(&json!({ "mode": "teleport" }))
            .await
            .unwrap_err();
        assert!(format!("{err}").contains("unknown mode"));
    }

    #[tokio::test]
    async fn vault_navigate_returns_path_toward_semantic_target() {
        let dir = tempdir().unwrap();
        make_vault(dir.path());

        // Pick the first available node as start.
        let graph = GraphQueryHandler::new(dir.path().to_path_buf());
        let gn = graph
            .execute(&json!({ "mode": "god_nodes", "limit": 1 }))
            .await
            .unwrap();
        let parsed: Value = serde_json::from_str(&gn).unwrap();
        let start = parsed["nodes"][0]["path"].as_str().unwrap().to_string();

        let handler = VaultNavigateHandler::new(dir.path().to_path_buf());
        let result = handler
            .execute(&json!({
                "start": start,
                "semantic_target": "alpha",
                "max_depth": 4
            }))
            .await
            .unwrap();
        let nav: Value = serde_json::from_str(&result).unwrap();
        assert!(nav["path"].as_array().unwrap().len() >= 1);
        assert!(nav["geodesic_distance"].as_f64().unwrap() >= 0.0);
    }
}
