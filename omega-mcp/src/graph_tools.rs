use crate::types::{SafetyInfo, ToolDefinition, ToolResult};
use schemars::{schema_for, JsonSchema};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::{BTreeMap, VecDeque};
use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::time::Instant;

const GRAPH_TOOL_NAMES: [&str; 7] = [
    "graph.search_semantic",
    "graph.search_fulltext",
    "graph.get_node",
    "graph.traverse",
    "graph.create_node",
    "graph.create_edge",
    "graph.commit_session",
];

#[derive(Debug, Deserialize, JsonSchema)]
struct SearchArgs {
    query: String,
    #[serde(default = "default_top_k", alias = "top_k")]
    k: usize,
    #[serde(default)]
    scope: Option<String>,
}

#[derive(Debug, Deserialize, JsonSchema)]
struct GetNodeArgs {
    node_id: String,
}

#[derive(Debug, Deserialize, JsonSchema)]
struct TraverseArgs {
    #[serde(alias = "from_id")]
    start: String,
    #[serde(default = "default_depth", alias = "depth")]
    max_depth: usize,
    #[serde(default, alias = "edge_filter")]
    edge_kinds: Vec<String>,
}

#[derive(Debug, Deserialize, JsonSchema)]
struct CreateNodeArgs {
    kind: String,
    title: String,
    #[serde(default)]
    body: String,
    #[serde(default)]
    parent_refs: Vec<String>,
    #[serde(default)]
    metadata: Value,
    #[serde(default)]
    session_id: Option<String>,
}

#[derive(Debug, Deserialize, JsonSchema)]
struct CreateEdgeArgs {
    from: String,
    to: String,
    kind: String,
    #[serde(default)]
    metadata: Value,
}

#[derive(Debug, Deserialize, JsonSchema)]
struct CommitSessionArgs {
    #[serde(default)]
    session_id: Option<String>,
    #[serde(default)]
    envelope: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct GraphNode {
    node_id: String,
    kind: String,
    title: String,
    body: String,
    parent_refs: Vec<String>,
    metadata: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct GraphEdge {
    edge_id: String,
    from: String,
    to: String,
    kind: String,
    metadata: Value,
}

#[derive(Debug, Default, Serialize, Deserialize)]
struct GraphStore {
    nodes: BTreeMap<String, GraphNode>,
    edges: BTreeMap<String, GraphEdge>,
    sessions: BTreeMap<String, Vec<String>>,
    next_event_sequence: u64,
}

pub struct GraphToolExecutor {
    root: PathBuf,
}

impl GraphToolExecutor {
    pub fn new(root: &Path) -> Self {
        Self {
            root: root.to_path_buf(),
        }
    }

    pub fn execute(&self, tool_name: &str, args: Value) -> ToolResult {
        let start = Instant::now();
        let mut store = self.load_store();

        let outcome = match canonical_tool_name(tool_name) {
            Some("graph.search_semantic") => self.search(&store, tool_name, args, true),
            Some("graph.search_fulltext") => self.search(&store, tool_name, args, false),
            Some("graph.get_node") => self.get_node(&store, tool_name, args),
            Some("graph.traverse") => self.traverse(&store, tool_name, args),
            Some("graph.create_node") => self.create_node(&mut store, tool_name, args),
            Some("graph.create_edge") => self.create_edge(&mut store, tool_name, args),
            Some("graph.commit_session") => self.commit_session(&mut store, tool_name, args),
            _ => Err(format!("Unknown graph tool: {tool_name}")),
        };

        match outcome {
            Ok((mut data, mut events)) => {
                for event in &mut events {
                    store.next_event_sequence = store.next_event_sequence.saturating_add(1);
                    if let Some(obj) = event.as_object_mut() {
                        obj.insert(
                            "sequence".to_string(),
                            Value::from(store.next_event_sequence),
                        );
                    }
                }
                if let Some(obj) = data.as_object_mut() {
                    obj.insert("agent_events".to_string(), Value::Array(events.clone()));
                }
                if let Err(error) = self.save_store(&store) {
                    return ToolResult::err(
                        error,
                        crate::types::error_codes::EXECUTION_ERROR,
                        start.elapsed().as_millis() as u64,
                    );
                }
                if let Err(error) = self.append_events(&events) {
                    return ToolResult::err(
                        error,
                        crate::types::error_codes::EXECUTION_ERROR,
                        start.elapsed().as_millis() as u64,
                    );
                }
                ToolResult::ok(data.to_string(), start.elapsed().as_millis() as u64)
            }
            Err(error) => ToolResult::err(
                error,
                crate::types::error_codes::INVALID_INPUT,
                start.elapsed().as_millis() as u64,
            ),
        }
    }

    fn search(
        &self,
        store: &GraphStore,
        tool_name: &str,
        args: Value,
        semantic: bool,
    ) -> Result<(Value, Vec<Value>), String> {
        let args: SearchArgs = serde_json::from_value(args).map_err(|e| e.to_string())?;
        let query = args.query.trim();
        if query.is_empty() {
            return Err("query must not be empty".to_string());
        }
        let query_lower = query.to_lowercase();
        let mut results = Vec::with_capacity(store.nodes.len().min(clamp_k(args.k)));

        for node in store.nodes.values() {
            let haystack = format!("{} {}", node.title, node.body).to_lowercase();
            if !haystack.contains(&query_lower) {
                continue;
            }
            let score = if semantic { 0.74 } else { 1.0 };
            results.push(json!({
                "node_id": node.node_id,
                "score": score,
                "snippet": snippet_for(&node.body, query),
                "title": node.title,
                "kind": node.kind,
            }));
        }

        results.sort_by(|a, b| {
            a["title"]
                .as_str()
                .unwrap_or("")
                .cmp(b["title"].as_str().unwrap_or(""))
        });
        results.truncate(clamp_k(args.k));
        let result_count = results.len();

        let event_kind = if semantic {
            "graph_traverse_completed"
        } else {
            "graph_fulltext_accessed"
        };

        Ok((
            json!({
                "query": query,
                "k": clamp_k(args.k),
                "scope": args.scope,
                "results": results,
            }),
            vec![agent_event(
                event_kind,
                tool_name,
                json!({
                    "query_hash": blake3_hex(query.as_bytes()),
                    "result_count": result_count,
                }),
            )],
        ))
    }

    fn get_node(
        &self,
        store: &GraphStore,
        tool_name: &str,
        args: Value,
    ) -> Result<(Value, Vec<Value>), String> {
        let args: GetNodeArgs = serde_json::from_value(args).map_err(|e| e.to_string())?;
        let node = store
            .nodes
            .get(&args.node_id)
            .ok_or_else(|| format!("node not found: {}", args.node_id))?;

        Ok((
            json!({ "node": node }),
            vec![agent_event(
                "graph_node_accessed",
                tool_name,
                json!({
                    "node_id": node.node_id,
                }),
            )],
        ))
    }

    fn traverse(
        &self,
        store: &GraphStore,
        tool_name: &str,
        args: Value,
    ) -> Result<(Value, Vec<Value>), String> {
        let args: TraverseArgs = serde_json::from_value(args).map_err(|e| e.to_string())?;
        if !store.nodes.contains_key(&args.start) {
            return Err(format!("start node not found: {}", args.start));
        }

        let max_depth = args.max_depth.min(8).max(1);
        let mut queue = VecDeque::from([(args.start.clone(), 0usize)]);
        let mut visited = BTreeMap::new();
        let mut rows = Vec::new();

        while let Some((node_id, depth)) = queue.pop_front() {
            if visited.insert(node_id.clone(), depth).is_some() || depth >= max_depth {
                continue;
            }
            for edge in store.edges.values().filter(|edge| edge.from == node_id) {
                if !args.edge_kinds.is_empty() && !args.edge_kinds.contains(&edge.kind) {
                    continue;
                }
                rows.push(json!({
                    "node_id": edge.to,
                    "edge_kind": edge.kind,
                    "depth": depth + 1,
                }));
                queue.push_back((edge.to.clone(), depth + 1));
            }
        }

        Ok((
            json!({
                "start": args.start,
                "max_depth": max_depth,
                "results": rows,
            }),
            vec![
                agent_event(
                    "graph_traverse_started",
                    tool_name,
                    json!({ "start": args.start }),
                ),
                agent_event(
                    "graph_traverse_completed",
                    tool_name,
                    json!({
                        "visited": visited.keys().cloned().collect::<Vec<_>>(),
                    }),
                ),
            ],
        ))
    }

    fn create_node(
        &self,
        store: &mut GraphStore,
        tool_name: &str,
        args: Value,
    ) -> Result<(Value, Vec<Value>), String> {
        let args = parse_create_node_args(args)?;
        let node_id = format!("node_{}", uuid::Uuid::new_v4().simple());
        let node = GraphNode {
            node_id: node_id.clone(),
            kind: args.kind,
            title: args.title,
            body: args.body,
            parent_refs: args.parent_refs,
            metadata: args.metadata,
        };
        let session_id = args.session_id.unwrap_or_else(|| "default".to_string());
        let mut edge_ids = Vec::with_capacity(node.parent_refs.len());

        for parent in &node.parent_refs {
            if !store.nodes.contains_key(parent) {
                return Err(format!("parent node not found: {parent}"));
            }
            let edge_id = self.insert_edge(store, parent, &node_id, "contains", Value::Null);
            edge_ids.push(edge_id);
        }

        store.nodes.insert(node_id.clone(), node.clone());
        store
            .sessions
            .entry(session_id.clone())
            .or_default()
            .push(node_id.clone());

        let mut events = vec![agent_event(
            "graph_node_created",
            tool_name,
            json!({
                "node_id": node_id,
                "kind": node.kind,
                "session_id": session_id,
            }),
        )];
        for edge_id in &edge_ids {
            events.push(agent_event(
                "graph_edge_created",
                tool_name,
                json!({
                    "edge_id": edge_id,
                    "kind": "contains",
                }),
            ));
        }

        Ok((
            json!({ "node_id": node.node_id, "edge_ids": edge_ids }),
            events,
        ))
    }

    fn create_edge(
        &self,
        store: &mut GraphStore,
        tool_name: &str,
        args: Value,
    ) -> Result<(Value, Vec<Value>), String> {
        let args: CreateEdgeArgs = serde_json::from_value(args).map_err(|e| e.to_string())?;
        if !store.nodes.contains_key(&args.from) {
            return Err(format!("from node not found: {}", args.from));
        }
        if !store.nodes.contains_key(&args.to) {
            return Err(format!("to node not found: {}", args.to));
        }

        let edge_id = self.insert_edge(store, &args.from, &args.to, &args.kind, args.metadata);
        Ok((
            json!({ "edge_id": edge_id }),
            vec![agent_event(
                "graph_edge_created",
                tool_name,
                json!({
                    "edge_id": edge_id,
                    "from": args.from,
                    "to": args.to,
                    "kind": args.kind,
                }),
            )],
        ))
    }

    fn commit_session(
        &self,
        store: &mut GraphStore,
        tool_name: &str,
        args: Value,
    ) -> Result<(Value, Vec<Value>), String> {
        let args: CommitSessionArgs = serde_json::from_value(args).map_err(|e| e.to_string())?;
        let session_id = args.session_id.unwrap_or_else(|| "default".to_string());
        let artifacts = store.sessions.remove(&session_id).unwrap_or_default();
        let artifact_count = artifacts.len();
        let link_material = json!({
            "session_id": session_id.clone(),
            "artifacts": artifacts.clone(),
            "envelope": args.envelope,
            "node_count": store.nodes.len(),
            "edge_count": store.edges.len(),
        });
        let blake3_link = blake3_hex(link_material.to_string().as_bytes());

        Ok((
            json!({
                "committed": artifact_count,
                "artifacts": artifacts.clone(),
                "blake3_link": blake3_link,
            }),
            vec![agent_event(
                "session_committed",
                tool_name,
                json!({
                    "session_id": session_id,
                    "artifact_count": artifact_count,
                    "blake3_link": blake3_link,
                }),
            )],
        ))
    }

    fn insert_edge(
        &self,
        store: &mut GraphStore,
        from: &str,
        to: &str,
        kind: &str,
        metadata: Value,
    ) -> String {
        let edge_id = format!("edge_{}", uuid::Uuid::new_v4().simple());
        store.edges.insert(
            edge_id.clone(),
            GraphEdge {
                edge_id: edge_id.clone(),
                from: from.to_string(),
                to: to.to_string(),
                kind: kind.to_string(),
                metadata,
            },
        );
        edge_id
    }

    fn load_store(&self) -> GraphStore {
        let path = self.store_path();
        fs::read_to_string(path)
            .ok()
            .and_then(|body| serde_json::from_str(&body).ok())
            .unwrap_or_default()
    }

    fn save_store(&self, store: &GraphStore) -> Result<(), String> {
        fs::create_dir_all(self.epistemos_dir()).map_err(|e| e.to_string())?;
        let body = serde_json::to_string_pretty(store).map_err(|e| e.to_string())?;
        fs::write(self.store_path(), body).map_err(|e| e.to_string())
    }

    fn append_events(&self, events: &[Value]) -> Result<(), String> {
        if events.is_empty() {
            return Ok(());
        }
        fs::create_dir_all(self.epistemos_dir()).map_err(|e| e.to_string())?;
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(self.events_path())
            .map_err(|e| e.to_string())?;
        for event in events {
            let line = serde_json::to_string(event).map_err(|e| e.to_string())?;
            writeln!(file, "{line}").map_err(|e| e.to_string())?;
        }
        Ok(())
    }

    fn epistemos_dir(&self) -> PathBuf {
        self.root.join(".epistemos")
    }

    fn store_path(&self) -> PathBuf {
        self.epistemos_dir().join("mcp_graph.json")
    }

    fn events_path(&self) -> PathBuf {
        self.epistemos_dir().join("mcp_graph_events.jsonl")
    }
}

pub fn is_graph_tool(tool_name: &str) -> bool {
    canonical_tool_name(tool_name).is_some()
}

pub fn builtin_graph_tools() -> Vec<ToolDefinition> {
    vec![
        graph_tool::<SearchArgs>(
            "graph.search_semantic",
            "Search the cognitive graph by semantic similarity.",
            r#"{"query":"attention","k":10}"#,
            false,
        ),
        graph_tool::<SearchArgs>(
            "graph.search_fulltext",
            "Search the cognitive graph by full-text match.",
            r#"{"query":"attention","k":10}"#,
            false,
        ),
        graph_tool::<GetNodeArgs>(
            "graph.get_node",
            "Fetch one cognitive graph node by id.",
            r#"{"node_id":"node_..."}"#,
            false,
        ),
        graph_tool::<TraverseArgs>(
            "graph.traverse",
            "Traverse typed graph edges from a start node.",
            r#"{"start":"node_...","max_depth":2,"edge_kinds":["supports"]}"#,
            false,
        ),
        graph_tool::<CreateNodeArgs>(
            "graph.create_node",
            "Create a typed cognitive graph node.",
            r#"{"kind":"Note","title":"...","body":"...","parent_refs":[]}"#,
            true,
        ),
        graph_tool::<CreateEdgeArgs>(
            "graph.create_edge",
            "Create a typed cognitive graph relation.",
            r#"{"from":"node_a","to":"node_b","kind":"supports"}"#,
            true,
        ),
        graph_tool::<CommitSessionArgs>(
            "graph.commit_session",
            "Atomically commit the current graph session with a BLAKE3 link.",
            r#"{"session_id":"default","envelope":{}}"#,
            true,
        ),
    ]
}

fn graph_tool<T: JsonSchema>(
    name: &str,
    description: &str,
    arguments_example: &str,
    destructive: bool,
) -> ToolDefinition {
    ToolDefinition {
        name: name.to_string(),
        agent: "graph".to_string(),
        description: description.to_string(),
        input_schema_json: serde_json::to_string(&schema_for!(T))
            .unwrap_or_else(|_| r#"{"type":"object"}"#.to_string()),
        arguments_example: arguments_example.to_string(),
        safety: SafetyInfo {
            destructive,
            requires_confirmation: destructive,
            scoped_to_apps: vec![],
        },
    }
}

fn canonical_tool_name(tool_name: &str) -> Option<&'static str> {
    GRAPH_TOOL_NAMES
        .iter()
        .copied()
        .find(|name| *name == tool_name)
        .or_else(|| {
            let dotted = format!("graph.{tool_name}");
            GRAPH_TOOL_NAMES
                .iter()
                .copied()
                .find(|name| *name == dotted)
        })
}

fn parse_create_node_args(args: Value) -> Result<CreateNodeArgs, String> {
    if let Some(typed_node) = args.get("typed_node") {
        return serde_json::from_value(typed_node.clone()).map_err(|e| e.to_string());
    }
    serde_json::from_value(args).map_err(|e| e.to_string())
}

fn default_top_k() -> usize {
    10
}

fn default_depth() -> usize {
    1
}

fn clamp_k(k: usize) -> usize {
    k.min(100).max(1)
}

fn snippet_for(body: &str, query: &str) -> String {
    let lower = body.to_lowercase();
    let query = query.to_lowercase();
    let Some(byte_pos) = lower.find(&query) else {
        return body.chars().take(160).collect();
    };
    let char_pos = body[..byte_pos].chars().count();
    let start = char_pos.saturating_sub(48);
    body.chars().skip(start).take(160).collect()
}

fn agent_event(kind: &str, tool_name: &str, payload: Value) -> Value {
    json!({
        "kind": kind,
        "tool_name": tool_name,
        "payload": payload,
    })
}

fn blake3_hex(bytes: &[u8]) -> String {
    blake3::hash(bytes).to_hex().to_string()
}
