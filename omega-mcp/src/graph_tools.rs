use crate::graph_search_backend::{GraphSearchBackend, ScoredHit};
use crate::types::{SafetyInfo, ToolDefinition, ToolResult};
use schemars::{schema_for, JsonSchema};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::collections::{BTreeMap, VecDeque};
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Instant;

const GRAPH_TOOL_NAMES: [&str; 8] = [
    "graph.search_semantic",
    "graph.search_fulltext",
    "graph.get_node",
    "graph.traverse",
    "graph.create_node",
    "graph.create_edge",
    "graph.commit_session",
    "graph.populate_from_vault",
];

/// Deterministic, idempotent node-id prefix for vault-sourced notes. Keyed by note BASENAME so
/// re-running `populate_from_vault` upserts the same node (no duplicates) and wikilink resolution
/// (also basename-based) lines up 1:1. Agent-created nodes use the random `node_<uuid>` form and are
/// never touched by a vault re-sync.
const VAULT_NODE_PREFIX: &str = "node_vault_";

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
    /// Edge direction to follow: `out` (default — outgoing edges, the historical behavior), `in` (incoming —
    /// walk BACKLINKS, e.g. notes that link TO this one), or `both`. Lets agents navigate the vault graph in
    /// either direction (§720 #2 "agents can traverse the graph"), not just downstream.
    #[serde(default = "default_direction")]
    direction: String,
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
struct PopulateFromVaultArgs {
    /// Graph session the synced note-nodes are registered under (for `commit_session` provenance).
    #[serde(default = "default_vault_session")]
    session_id: String,
    /// How many leading chars of each note become the node body (for fulltext/semantic search over
    /// the graph). Clamped to [0, 2000] — bounded so a 5000-note vault stays light.
    #[serde(default = "default_excerpt_chars")]
    excerpt_chars: usize,
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
            Some("graph.populate_from_vault") => {
                self.populate_from_vault(&mut store, tool_name, args)
            }
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

        // Score every node via the pluggable backend. Default backend
        // ships deterministic BM25-like + trigram-cosine scorers (see
        // graph_search_backend.rs); future Shadow backend routes through
        // epistemos-shadow's HNSW + Tantivy without changing this site.
        let backend = GraphSearchBackend::default();
        let mut scored: Vec<(ScoredHit, &GraphNode)> = Vec::with_capacity(store.nodes.len());
        if semantic {
            let scorer = backend.semantic_scorer();
            for node in store.nodes.values() {
                let haystack = format!("{} {}", node.title, node.body);
                if let Some(score) = scorer.score(query, &haystack) {
                    scored.push((
                        ScoredHit {
                            node_id: node.node_id.clone(),
                            score,
                        },
                        node,
                    ));
                }
            }
        } else {
            let scorer = backend.fulltext_scorer();
            for node in store.nodes.values() {
                let haystack = format!("{} {}", node.title, node.body);
                if let Some(score) = scorer.score(query, &haystack) {
                    scored.push((
                        ScoredHit {
                            node_id: node.node_id.clone(),
                            score,
                        },
                        node,
                    ));
                }
            }
        }

        // Sort descending by score; ties broken by ascending node_id so
        // iteration is replayable across runs (Swift HashMap iteration
        // and serde_json::Map ordering are randomized otherwise).
        scored.sort_by(|a, b| {
            b.0.score
                .partial_cmp(&a.0.score)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| a.0.node_id.cmp(&b.0.node_id))
        });
        scored.truncate(clamp_k(args.k));

        let mut results = Vec::with_capacity(scored.len());
        for (hit, node) in &scored {
            results.push(json!({
                "node_id": hit.node_id,
                "score": hit.score,
                "snippet": snippet_for(&node.body, query),
                "title": node.title,
                "kind": node.kind,
            }));
        }
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
        let (follow_out, follow_in) = match args.direction.as_str() {
            "out" => (true, false),
            "in" => (false, true),
            "both" => (true, true),
            other => return Err(format!("direction must be out|in|both (got {other})")),
        };

        let max_depth = args.max_depth.clamp(1, 8);
        let mut queue = VecDeque::from([(args.start.clone(), 0usize)]);
        let mut visited = BTreeMap::new();
        let mut rows = Vec::new();

        while let Some((node_id, depth)) = queue.pop_front() {
            if visited.insert(node_id.clone(), depth).is_some() || depth >= max_depth {
                continue;
            }
            for edge in store.edges.values() {
                if !args.edge_kinds.is_empty() && !args.edge_kinds.contains(&edge.kind) {
                    continue;
                }
                // `out`: this node → edge.to (downstream). `in`: this node ← edge.from (backlinks).
                let next = if follow_out && edge.from == node_id {
                    Some((&edge.to, "out"))
                } else if follow_in && edge.to == node_id {
                    Some((&edge.from, "in"))
                } else {
                    None
                };
                if let Some((neighbor, dir)) = next {
                    rows.push(json!({
                        "node_id": neighbor,
                        "edge_kind": edge.kind,
                        "direction": dir,
                        "depth": depth + 1,
                    }));
                    queue.push_back((neighbor.clone(), depth + 1));
                }
            }
        }

        Ok((
            json!({
                "start": args.start,
                "max_depth": max_depth,
                "direction": args.direction,
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

    /// VAULT-DEEP-INTEGRATION §720 (#2): populate the cognitive graph FROM the vault end-to-end — one
    /// `Note` node per markdown file + a `links_to` edge for every `[[wikilink]]` that resolves to another
    /// vault note. This is the "the vault's notes + links ARE the knowledge graph" piece (overtake Tolaria,
    /// whose graph is thin). REUSE not rebuild: walks `VaultExecutor::list_markdown_notes` and the SAME
    /// `parse_wikilinks`/`note_basename` the backlink/outlink tools use. IDEMPOTENT: a re-sync first drops all
    /// prior vault-sourced nodes/edges (agent-authored nodes untouched), so the graph always mirrors the
    /// current vault — no duplicates, no stale notes. HONEST: dangling links (no target note) are COUNTED,
    /// not turned into phantom nodes.
    fn populate_from_vault(
        &self,
        store: &mut GraphStore,
        tool_name: &str,
        args: Value,
    ) -> Result<(Value, Vec<Value>), String> {
        use crate::vault::VaultExecutor;
        use std::collections::{BTreeMap, HashSet};

        let args: PopulateFromVaultArgs =
            serde_json::from_value(args).map_err(|e| e.to_string())?;
        let excerpt_chars = args.excerpt_chars.min(2000);

        let root_str = self
            .root
            .to_str()
            .ok_or_else(|| "vault root path is not valid UTF-8".to_string())?;
        let vault = VaultExecutor::new(root_str)
            .ok_or_else(|| format!("vault root is not a directory: {}", self.root.display()))?;

        // Idempotent re-sync: remove prior vault-sourced nodes + any edge touching one + their session refs.
        store
            .nodes
            .retain(|id, _| !id.starts_with(VAULT_NODE_PREFIX));
        store.edges.retain(|_, e| {
            !e.from.starts_with(VAULT_NODE_PREFIX) && !e.to.starts_with(VAULT_NODE_PREFIX)
        });
        for ids in store.sessions.values_mut() {
            ids.retain(|id| !id.starts_with(VAULT_NODE_PREFIX));
        }

        // 1) one deterministic node per note (basename-keyed → matches the wikilink resolution model).
        let notes = vault.list_markdown_notes();
        let mut basename_to_id: BTreeMap<String, String> = BTreeMap::new();
        let mut note_sources: Vec<(String, String)> = Vec::with_capacity(notes.len()); // (node_id, content)
        for rel in &notes {
            let content = fs::read_to_string(self.root.join(rel)).unwrap_or_default();
            let basename = VaultExecutor::note_basename(rel);
            let node_id = vault_node_id(&basename);
            let body: String = content.chars().take(excerpt_chars).collect();
            store.nodes.insert(
                node_id.clone(),
                GraphNode {
                    node_id: node_id.clone(),
                    kind: "Note".to_string(),
                    title: note_title(rel),
                    body,
                    parent_refs: vec![],
                    metadata: json!({ "source": "vault", "path": rel }),
                },
            );
            // last-writer-wins on basename collision (same collapse the link model already does).
            basename_to_id.insert(basename, node_id.clone());
            note_sources.push((node_id, content));
        }
        let node_count = basename_to_id.len();

        // 2) a `links_to` edge for each wikilink that RESOLVES to a vault note; dangling links are counted.
        let mut edge_count = 0usize;
        let mut dangling_count = 0usize;
        let mut seen_edges: HashSet<(String, String)> = HashSet::new();
        for (from_id, content) in &note_sources {
            for link in VaultExecutor::parse_wikilinks(content) {
                let target = VaultExecutor::note_basename(&link);
                match basename_to_id.get(&target) {
                    Some(to_id) if to_id != from_id => {
                        if seen_edges.insert((from_id.clone(), to_id.clone())) {
                            self.insert_edge(
                                store,
                                from_id,
                                to_id,
                                "links_to",
                                json!({ "source": "vault" }),
                            );
                            edge_count += 1;
                        }
                    }
                    Some(_) => {} // self-link → no edge
                    None => dangling_count += 1,
                }
            }
        }

        // register synced notes under the session so `commit_session` can provenance-seal the sync.
        let session = store.sessions.entry(args.session_id.clone()).or_default();
        session.extend(basename_to_id.values().cloned());

        Ok((
            json!({
                "session_id": args.session_id,
                "notes_indexed": notes.len(),
                "nodes": node_count,
                "edges": edge_count,
                "dangling_links": dangling_count,
            }),
            vec![agent_event(
                "graph_vault_populated",
                tool_name,
                json!({
                    "nodes": node_count,
                    "edges": edge_count,
                    "dangling_links": dangling_count,
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
        // ATOMIC write: the store is fully rewritten on EVERY graph mutation, so a plain fs::write that's
        // interrupted (crash / kill) leaves a truncated mcp_graph.json — which load_store then silently resets
        // to an EMPTY graph (whole-graph loss). Write a temp sibling + rename (atomic on the same filesystem)
        // so the store on disk is always a complete, valid snapshot. (Matches VaultNoteEditor's atomic discipline.)
        let final_path = self.store_path();
        let tmp_path = final_path.with_extension("json.tmp");
        fs::write(&tmp_path, body).map_err(|e| e.to_string())?;
        fs::rename(&tmp_path, &final_path).map_err(|e| e.to_string())
    }

    fn append_events(&self, events: &[Value]) -> Result<(), String> {
        if events.is_empty() {
            return Ok(());
        }
        fs::create_dir_all(self.epistemos_dir()).map_err(|e| e.to_string())?;
        // BOUNDED (§506): append + trim via the SHARED helper, so the graph event log and the vault provenance
        // log are bounded identically (write-only telemetry; durable provenance is in the EventStore).
        let lines: Vec<String> = events
            .iter()
            .map(|e| serde_json::to_string(e).map_err(|err| err.to_string()))
            .collect::<Result<_, _>>()?;
        crate::vault::append_lines_bounded(&self.events_path(), &lines)
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
            "Traverse typed graph edges from a start node. direction: out (default), in (backlinks), or both.",
            r#"{"start":"node_...","max_depth":2,"edge_kinds":["links_to"],"direction":"both"}"#,
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
        graph_tool::<PopulateFromVaultArgs>(
            "graph.populate_from_vault",
            "Populate the cognitive graph from the vault: one Note node per markdown file + a links_to \
             edge per resolved [[wikilink]]. Idempotent re-sync; dangling links are reported, not faked.",
            r#"{"session_id":"vault","excerpt_chars":280}"#,
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

fn default_vault_session() -> String {
    "vault".to_string()
}

fn default_excerpt_chars() -> usize {
    280
}

/// Deterministic vault node id from a note basename (blake3-hashed → charset-safe + stable across runs).
fn vault_node_id(basename: &str) -> String {
    format!(
        "{VAULT_NODE_PREFIX}{}",
        &blake3_hex(basename.as_bytes())[..16]
    )
}

/// Human title for a note node = filename without the `.md` extension, original case preserved.
fn note_title(rel: &str) -> String {
    let no_ext = rel
        .strip_suffix(".md")
        .or_else(|| rel.strip_suffix(".MD"))
        .unwrap_or(rel);
    no_ext.rsplit('/').next().unwrap_or(no_ext).to_string()
}

fn default_depth() -> usize {
    1
}

fn default_direction() -> String {
    "out".to_string()
}

fn clamp_k(k: usize) -> usize {
    k.clamp(1, 100)
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
