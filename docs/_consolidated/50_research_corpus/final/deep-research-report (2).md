# Epistemos × Hermes Technical Dossier

## The highest-confidence conclusion

This can absolutely become a category-defining hackathon submission.

But the win condition is narrow.

**Do not try to replace Hermes.**
**Do not try to finish your in-repo Rust agent.**
**Do not try to migrate the entire app onto the new substrate in one push.**

The strongest architecture is: let Hermes upstream remain the agent, let Epistemos remain the native graph-and-rendering substrate, and connect them through a purpose-built Rust MCP seam that is tiny, brutally honest, and visually theatrical. That path matches what Hermes already supports today—dynamic MCP toolsets loaded from configured servers—and it matches your own repo’s stated target boundary where Rust owns orchestration and Swift owns rendering. citeturn1view4turn24view6turn6view0

The reason this is the right call is simple: your public repo already contains the ingredients for the **creative software** story—native SwiftUI, a Metal graph path, Rust crates for substrate and tooling, and a serious architecture narrative—but the current reality is still transitional. `substrate-core` is real but minimal; your own architecture docs say the Rust-owned agent runtime is a **target architecture, not yet fully implemented**; the Swift UI audit says the staged bridge is **not yet the production UI data path**; and your parity audit says the Rust `agent_core` still lacks browser automation, MCP servers, and other capabilities that upstream Hermes already ships. That means the winning move is integration, not replacement. citeturn6view0turn8view5turn8view4turn1view3turn24view5

## What your public repo actually supports right now

Your public entity["company","GitHub","developer platform"] repo already shows the right macro-shape: Swift app, `graph-engine`, `graph-engine-bridge`, `agent_core`, `omega-mcp`, `epistemos-core`, `substrate-core`, plus a large body of architecture and audit docs. That is not a toy codebase. It is structurally credible for a hackathon demo because the “hard aesthetic” part—the native graph surface—already exists in some form. citeturn4view4turn8view3

The important constraint is that `substrate-core` is still **Sprint-1 substrate**, not the final cognitive substrate you described. Its `Cargo.toml` uses `slotmap`, `rusqlite`, `serde`, and `parking_lot`; its store is a `DenseSlotMap` behind `RwLock`; `EntityId` is a generational `u64` wrapper over `slotmap::KeyData`; and the event log is persisted in SQLite with WAL plus `synchronous=FULL` and `fullfsync` commentary for macOS durability. That is a strong base for identity and auditability. But the current action grammar is still mostly **note-shaped**: `CreateNote`, `RenameNote`, `UpdateContent`, `DeleteNote`, and `LinkNotes`, with link storage explicitly deferred to a later sprint. The public `EntityKind` enum is still `Note`, `Folder`, `Chat`, `Idea`, and `Tag`, not `RawThought`, `Recall`, `Skill`, `LoopProfile`, or `Session`. citeturn9view0turn14view0turn14view2turn15view0turn13view0

That changes the implementation advice.

It means the shortest honest route is **not** “make the full manifesto literally true by May.”  
It is: **layer the hackathon node taxonomy on top of the current substrate with the smallest possible schema extension**, and keep the rest of the app’s existing graph/search/render machinery intact while you prove the new runtime story. Your own architecture map reinforces this: the live render path is still `SwiftData models -> GraphBuilder / GraphStore -> MetalGraphView batch builders -> GraphEngine.swift typed FFI wrapper -> Rust graph-engine -> Metal rendering`, while current persistence is still `SwiftData`, `GRDB/SQLite` search index, and vault markdown import/export. citeturn8view3turn7view2

Your in-repo `agent_core` is also farther along than most solo projects, but it is the wrong place to spend May-hackathon calories. The public parity audit compares your Rust implementation against Hermes Python and calls out strong progress in providers, error handling, and security, but it explicitly lists missing MCP server integration, browser automation, delegate subagents, RL training, and FTS5 session search. Your own `agent_core/src/mcp/client.rs` is telling: it discovers stdio servers, speaks JSON-RPC over stdio, fetches `tools/list`, and calls `tools/call`, but it appears to skip the full initialized-notification flow and reduces tool results to text extraction. That is useful as an experiment, but not the seam on which to hang the hackathon. citeturn8view4turn17view3

The hidden gift in your repo is `omega-mcp`. Its public crate description says it is an MCP tool registry, execution logger, and protocol types layer, separate from graph-rendering and training, and its dispatcher owns a registry plus execution logger. That suggests a good reuse path: **treat `omega-mcp` as internal telemetry / schema / logging infrastructure if helpful, but do not force it to be the public Hermes-facing MCP server if that slows you down.** The official Rust MCP SDK exists now; use that for the thin public server, and mine your existing crates only where they reduce labor instead of increasing coupling. citeturn17view4turn32view3turn24view0

## The architecture I would actually ship

The opinionated answer is this:

**Ship a three-plane system.**

**Plane one: Epistemos runtime plane.**  
This is your app’s authority over graph state, rendering, session overlays, and artifact views. It owns node persistence, edge persistence, graph focus state, hero animation, and the session camera behavior. It should also own the loop runtime later, because Hermes’s documented `execute_code` path is a Python child-process RPC surface meant to collapse multi-step workflows, not a trustworthy long-term programmable brain runtime for arbitrary graph-aware user code. The docs specifically describe `execute_code` as a child process connected over a Unix socket, with only the script’s `print()` output returning to the model context, and the documented in-script tool list is narrow. That is powerful, but it is not the right primitive for your “editable brain” vision. citeturn1view2

**Plane two: `epistemos-hermes-mcp` transport plane.**  
This is a standalone Rust binary, launched by Hermes as a stdio MCP server. Hermes already supports configured stdio MCP servers from `config.yaml`, generates `mcp-<server>` toolsets dynamically at runtime, and lets you immediately filter the exposed tools. That means your graph surface can stay small and exact. This binary should be open-source. This is the thing judges can star, clone, and understand. citeturn1view4turn24view2turn24view6

**Plane three: Hermes upstream agent plane.**  
Do not fork it for the demo unless you absolutely must. Hermes already has the agent loop, prompt assembly, session DB, skills, browser stack, code execution, and MCP loading. The docs explicitly put SQLite+FTS5 session storage in `~/.hermes/state.db`, expose MCP-backed tools dynamically, and describe skills as on-demand knowledge documents with slash-command integration and agent-managed creation/update flow. That is already enough for the narrative of “graph-aware agent with memory.” citeturn19search4turn24view3turn22search6turn26search4

That architecture gives you one clean story:

> Hermes uses a six-verb graph runtime over MCP.  
> Every graph touch emits an event.  
> The app renders those events live.  
> The graph is not a sidebar; it is the visible working memory.

That story is both technically honest and visually legible. citeturn24view2turn6view0

### The contenders

**Best contender for May:** separate stdio MCP binary.  
This is the best choice because it matches Hermes’s built-in configuration model, keeps the open-source surface small, and protects your native app from agent-lifecycle complexity. citeturn24view6turn1view4

**Second-best contender:** app-bundled subprocess MCP binary.  
Same interface, but packaged inside the app bundle and launched by your app for local testing while Hermes still connects via stdio. This keeps deployment tighter, but it is slightly more work because you now own bundle paths, process lifecycle, and local debugging ergonomics. The upside is that it becomes the post-hackathon path to a more integrated native distribution. This is an inference from Hermes’s stdio transport model and your current Swift/Rust app split. citeturn24view6turn6view0

**Do not choose for May:** in-process custom Hermes patch or full graph-backed skill system fork.  
Hermes today treats `~/.hermes/skills/` as source of truth, supports extra scanned external skill directories as read-only, and routes agent-created skills back to the local `~/.hermes/skills/` home. That means “skills as graph nodes only” is not a configuration problem; it is a lifecycle rewrite. Beautiful later. Wrong now. citeturn24view3turn25view0

## The crucial design calls

### The MCP surface should stay tiny

Your original instinct is correct: the graph surface should be small.

I would ship **seven** verbs, not six:

- `graph.search_semantic`
- `graph.search_fulltext`
- `graph.get_node`
- `graph.traverse`
- `graph.create_node`
- `graph.create_edge`
- `graph.commit_session`

The reason I keep `commit_session` is that Hermes already has its own session model and storage, but your demo needs a **graph-native** session boundary with a visible commit moment. Without that, the session subgraph story feels ornamental. With it, you get a real closing beat: “this research session became a permanent structure.” Hermes already persists its own sessions; your graph should persist a structurally distinct session artifact. citeturn19search4turn6view0

Do **not** expose raw SQL, generic graph mutations, bulk deletes, or arbitrary query DSLs for the demo. Hackathon judges are not evaluating abstraction purity. They are evaluating whether the architecture produces an undeniable artifact. Every extra verb lowers agent reliability and raises demo variance. Hermes itself recommends filtering MCP tool exposure early, especially for sensitive systems. citeturn24view2turn24view6

### Skills-as-nodes needs an overlay, not a revolution

Hermes skills are currently file-backed. The docs are explicit: all skills live in `~/.hermes/skills/`; external directories can also be scanned; and when the agent creates or edits a skill, it writes to the local Hermes skill directory, not to the external directories. That means your graph-native skill architecture should be implemented in two phases. citeturn24view3turn25view0

**Hackathon phase:** graph node is canonical in-app; filesystem mirror is canonical for Hermes.  
Concretely:

- Store `Skill` nodes in Epistemos with `slug`, `version`, `body_markdown`, `metadata_json`, `applies_to`, `parent_skill`, `source_session_id`.
- Materialize them deterministically to `~/.hermes/skills/epistemos/<slug>/SKILL.md`.
- On session end, if Hermes created or patched a skill through `skill_manage`, run a sync pass: ingest the resulting `SKILL.md`, diff it, update the graph node, create `refined-from` and `learned-in-session` edges, and emit a `GraphEvent::SkillSynced`. citeturn25view0turn24view3

That gives you the demo line you want without lying: “skills are graph nodes in Epistemos,” while Hermes compatibility is preserved by a mirror layer.

**Post-hackathon phase:** build a graph-backed skill provider or plugin.  
Hermes has a plugin system and already supports hooks, tools, data files, and bundled skills in plugins. That is the likely long-term place to migrate skill discovery away from local files if you truly want graph-first skill identity. But that is a second-system change, not a nine-day move. citeturn20search15turn24view3

### Loop profiles should not depend on `execute_code`

This is one of the biggest design traps in your vision.

It is tempting to say: “Hermes already has `execute_code`, so loop profiles can just be Python.”  
That is too shallow.

Hermes documents `execute_code` as a child Python process communicating with Hermes over a Unix domain socket, optimized for collapsing multi-step workflows into a single turn. The docs also explicitly enumerate the in-script tools they support in that pathway. That is not yet the same thing as “user-authored, durable, graph-native recurrent reasoning programs with versioned convergence semantics.” citeturn1view2

So the right split is:

**For May:** implement exactly one loop profile—`deepen-thought`—as a host-side runtime owned by Epistemos. Hermes invokes it via MCP or a materialized skill, but the runtime itself lives inside your app’s Rust boundary. That keeps permissions, graph reads/writes, event emission, and future sandboxing under your control. citeturn6view0turn1view2

**For later:** add a tiny DSL or hybrid manifest.  
My recommendation is **hybrid manifest + embedded Python blocks** only after the host-side runtime exists. Pure YAML/TOML becomes too weak too quickly. Pure Python becomes impossible to reason about or safely surface in UI. The hybrid shape gives you inspectable structure plus expressive steps.

### Schema-driven UI should be constrained, not universal

Your instinct is right. The name for what you want is basically **schema-driven rendering**.

But the hackathon-safe implementation is **not** “let arbitrary JSON invent my entire UI.”

That version becomes dreamy and fragile at the same time.

The right implementation is:

- closed set of artifact families for May,
- a typed envelope with `type`, `version`, `node_id`, `payload`,
- one renderer registry keyed by `type`,
- one generic fallback view for unknown future types.

That way you get the feeling of UI being “summoned,” but you do not create a rendering engine you cannot stabilize in nine days. This advice is driven by your repo’s own UI audit—where the staged bridge is not yet the production path and where the current app still has coarse invalidation and main-actor reevaluation pain—and by the fact that the demo only needs six or seven artifact shapes, not infinite ones. citeturn8view5turn7view8

My recommendation for the May artifact set is:

- `Session`
- `RawThought`
- `Recall`
- `Synthesis`
- `Skill`
- `ImplementationPlan`

Stub but do not rely on:

- `LoopProfile`

The reason to keep `ImplementationPlan` and not ship `LoopProfile` end-to-end is simple: `ImplementationPlan` is easy to make legible in the hero demo, while `LoopProfile` is a power-user feature whose value is harder to convey in 60 seconds.

### The embedded browser is not on the critical path

Hermes already ships a serious browser automation stack: Browserbase, Browser Use, Firecrawl, Camofox, Chrome CDP, and a local browser mode. It represents pages as accessibility-tree snapshots with element references and supports screenshot-plus-vision analysis. That is a mature browsing story today. citeturn24view5turn22search4

A native `WKWebView` browser inside Epistemos is still a strong part of the long vision.

But for the hackathon, you need to decide what problem it solves:

- If it solves **user experience**, you can build a basic native `BrowserView` and let the user browse inside the app.
- If it solves **agent capability**, it is a bad use of May-time, because Hermes already has that capability through its existing browser stack. citeturn24view5

So my advice is blunt:

**Use Hermes’s existing browser tooling for the demo.**
Build your native browser only if it is read-mostly or presentation-driven by May.
Do not put “Hermes controls `WKWebView` with a full custom MCP action server” on the critical path unless you finish the graph seam early and have slack.

## The code patterns I would start from

### The graph seam

```rust
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NodeKind {
    RawThought,
    ImplementationPlan,
    Recall,
    Skill,
    LoopProfile,
    Synthesis,
    Session,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeRecord {
    pub id: String,                  // opaque to Hermes
    pub kind: NodeKind,
    pub title: String,
    pub body: Option<String>,
    pub payload: Value,              // typed JSON payload for renderer
    pub session_id: Option<String>,
    pub source_model: Option<String>,
    pub created_at: i64,
    pub updated_at: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EdgeRecord {
    pub id: String,
    pub from: String,
    pub to: String,
    pub kind: String,                // "derived_from", "recalls", "cites", ...
    pub created_at: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "event", rename_all = "snake_case")]
pub enum GraphEvent {
    ToolCallStarted {
        tool: String,
        call_id: String,
        session_id: String,
        at: i64,
    },
    ToolCallFinished {
        tool: String,
        call_id: String,
        session_id: String,
        at: i64,
    },
    NodeRead {
        node_id: String,
        session_id: String,
        at: i64,
    },
    Traversal {
        seed_id: String,
        visited_node_ids: Vec<String>,
        traversed_edges: Vec<String>,
        session_id: String,
        at: i64,
    },
    NodeCreated {
        node_id: String,
        kind: NodeKind,
        session_id: String,
        at: i64,
    },
    EdgeCreated {
        edge_id: String,
        from: String,
        to: String,
        kind: String,
        session_id: String,
        at: i64,
    },
    SessionCommitted {
        session_id: String,
        pinned_node_count: usize,
        at: i64,
    },
}

pub trait GraphRuntime: Send + Sync + 'static {
    fn search_semantic(&self, query: &str, limit: usize, session_id: &str) -> anyhow::Result<Vec<NodeRecord>>;
    fn search_fulltext(&self, query: &str, limit: usize, session_id: &str) -> anyhow::Result<Vec<NodeRecord>>;
    fn get_node(&self, id: &str, session_id: &str) -> anyhow::Result<NodeRecord>;
    fn traverse(&self, seed_id: &str, hops: u8, edge_kinds: Option<Vec<String>>, session_id: &str)
        -> anyhow::Result<(Vec<NodeRecord>, Vec<EdgeRecord>)>;
    fn create_node(&self, node: NewNode, session_id: &str) -> anyhow::Result<NodeRecord>;
    fn create_edge(&self, edge: NewEdge, session_id: &str) -> anyhow::Result<EdgeRecord>;
    fn commit_session(&self, session_id: &str) -> anyhow::Result<CommitReceipt>;
    fn drain_events(&self, after_seq: u64) -> anyhow::Result<Vec<GraphEvent>>;
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NewNode {
    pub kind: NodeKind,
    pub title: String,
    pub body: Option<String>,
    pub payload: Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NewEdge {
    pub from: String,
    pub to: String,
    pub kind: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommitReceipt {
    pub session_id: String,
    pub committed_at: i64,
    pub node_count: usize,
    pub edge_count: usize,
}
```

This is the seam I would use because it respects the strongest truth in your repo: **Rust should own the real event surface**, and Swift should render events instead of inferring them. It also avoids leaking slotmap internals directly into Hermes while still letting you keep generational IDs inside the substrate if you want. The substrate can still use your current `EntityId(pub u64)` internally, but the MCP boundary should present Hermes with opaque strings so you can evolve storage later without breaking tool contracts. citeturn6view0turn14view0turn14view2

### The MCP schemas

```json
{
  "name": "graph.create_node",
  "description": "Create a typed node in the Epistemos graph and attach it to the current Hermes session.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "session_id": { "type": "string" },
      "kind": {
        "type": "string",
        "enum": [
          "raw_thought",
          "implementation_plan",
          "recall",
          "skill",
          "loop_profile",
          "synthesis",
          "session"
        ]
      },
      "title": { "type": "string" },
      "body": { "type": ["string", "null"] },
      "payload": { "type": "object", "additionalProperties": true }
    },
    "required": ["session_id", "kind", "title", "payload"]
  }
}
```

```json
{
  "name": "graph.traverse",
  "description": "Walk the graph outward from a seed node and return visited nodes and traversed edges.",
  "inputSchema": {
    "type": "object",
    "properties": {
      "session_id": { "type": "string" },
      "seed_id": { "type": "string" },
      "hops": { "type": "integer", "minimum": 1, "maximum": 4 },
      "edge_kinds": {
        "type": ["array", "null"],
        "items": { "type": "string" }
      }
    },
    "required": ["session_id", "seed_id", "hops"]
  }
}
```

Use **shallow, boring, explicit** schemas. Hermes supports dynamic MCP toolsets and filtering, but I did not directly verify the practical edge cases of deeply nested typed unions in the current client, so I would treat rich result polymorphism as **UNVERIFIED** until you run a real end-to-end probe. Keep result shapes flat for the demo. citeturn24view6turn1view4

### The skill overlay

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SkillNode {
    pub id: String,
    pub slug: String,
    pub category: String,
    pub version: String,
    pub markdown: String,            // full SKILL.md
    pub applies_to: Vec<String>,     // ["raw_thought", "synthesis"]
    pub source_session_id: Option<String>,
    pub parent_skill_id: Option<String>,
    pub created_at: i64,
    pub updated_at: i64,
}

pub fn materialize_skill_to_hermes_home(
    skill: &SkillNode,
    hermes_skills_root: &std::path::Path,
) -> std::io::Result<std::path::PathBuf> {
    let dir = hermes_skills_root.join("epistemos").join(&skill.slug);
    std::fs::create_dir_all(&dir)?;
    let skill_md = dir.join("SKILL.md");
    std::fs::write(&skill_md, &skill.markdown)?;
    Ok(skill_md)
}
```

The point is not elegance.  
The point is compatibility.

Hermes already knows how to discover `SKILL.md`, expose it as slash commands, and let the agent manage skills. Your job is to make graph identity and file identity converge without pretending file identity no longer exists. citeturn24view3turn25view0turn22search6

### The Swift artifact renderer

```swift
import SwiftUI

struct ArtifactEnvelope: Decodable, Identifiable {
    let id: String
    let type: String
    let version: Int
    let title: String
    let payload: Data
}

protocol ArtifactViewFactory {
    func makeView(for envelope: ArtifactEnvelope) -> AnyView
}

@MainActor
final class ViewRegistry: ObservableObject {
    private var factories: [String: ArtifactViewFactory] = [:]

    func register(_ type: String, factory: ArtifactViewFactory) {
        factories[type] = factory
    }

    func render(_ envelope: ArtifactEnvelope) -> AnyView {
        if let factory = factories[envelope.type] {
            return factory.makeView(for: envelope)
        } else {
            return AnyView(UnknownArtifactView(envelope: envelope))
        }
    }
}

struct UnknownArtifactView: View {
    let envelope: ArtifactEnvelope

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(envelope.title).font(.headline)
            Text("Unsupported artifact type: \(envelope.type)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
```

The trick here is restraint.

Keep `AnyView` at the **registry boundary only**. Inside each renderer, decode into strong types and render normally. That keeps your codebase maintainable while still giving you the dynamic effect. Given your own Swift UI audit and the current coarse invalidation/main-thread issues, this is much safer than building a runtime-generated view tree system from scratch right now. citeturn8view5turn7view8

### The event bridge

```swift
import Foundation

struct GraphEventDTO: Decodable, Sendable {
    let event: String
    let sessionID: String
    let nodeIDs: [String]?
    let edgeIDs: [String]?
    let timestamp: Int64
}

actor GraphEventStream {
    private var continuation: AsyncStream<GraphEventDTO>.Continuation?
    private(set) lazy var stream = AsyncStream<GraphEventDTO> { continuation in
        self.continuation = continuation
    }

    func push(_ event: GraphEventDTO) {
        continuation?.yield(event)
    }

    func finish() {
        continuation?.finish()
    }
}
```

The render rule should be strict:

- `graph.get_node` → node pulse
- `graph.traverse` → visited-node pulse + edge flash
- `graph.create_node` → phase-in + glare pass
- `graph.create_edge` → edge flash
- `graph.commit_session` → camera settle + opacity shift + session badge

Do not animate based on chat tokens.  
Animate based on graph semantics only.  
That is what makes the demo feel **true** rather than decorative. Your own target architecture doc already points in this direction by insisting that event surfaces come from Rust and not be inferred by Swift. citeturn6view0

## The hackathon path that actually gives you a chance to win

Public hackathon information is annoyingly inconsistent. One public source says submissions are due **end of day May 4, 2026** and describes the prize pool as **$25k total across cash prizes and Kimi credits**, while another public announcement copy says **end of day Sunday, May 3** and breaks judging down as **creativity, usefulness, and presentation**. Because of that conflict, you should act as if the real deadline is **May 3** and treat May 4 as disaster buffer only. citeturn29search0turn29search1turn30search6

That matters because it changes what “no compromise” means.

It does **not** mean “implement the whole manifesto now.”  
It means “show the load-bearing slice so clearly that the post-hackathon roadmap becomes obvious.”

The strongest 60–90 second demo is:

- black surface,
- double-click,
- Hermes intro animation,
- one real cross-vault research prompt,
- graph lights up during retrieval and traversal,
- a `Synthesis` node phases in,
- you click it and see a beautiful artifact with backlinks,
- then the payoff: **a new skill gets saved and visibly attached to the session**.

That sequence hits the public judging language directly: it is creative, useful, and visually presented. It also leverages what Hermes is already known for—memory, skills, MCP, browsing—without requiring the judges to understand your entire future architecture. citeturn29search1turn30search0turn24view3turn24view2

The best public Hermes-adjacent showcases do exactly this: they do not merely claim autonomy; they produce a distinctive artifact that proves a mechanism. `autonovel` is a good example of the pattern—its public positioning is “an autonomous novel-writing pipeline” and the public writeup emphasizes the artifact pipeline end-to-end. By contrast, the self-evolution project is conceptually relevant to your loop-profile ambitions, but the public repo and issues show it is still unstable enough that you should **borrow the idea, not put it on your critical path**. The README says Phase 1 skill optimization is implemented, but the public issue tracker currently includes open problems around mutated skill content, validation, stalled progress, scoring quality, and GEPA compatibility. citeturn31search0turn31search3turn33view0turn33view2turn33view3

So if I were steering this to maximize your odds, I would lock the May scope to this:

**Must ship**
- separate Rust MCP server
- real graph traversal tooling
- graph event → Metal binding
- node types: `Session`, `RawThought`, `Recall`, `Synthesis`, `Skill`
- graph-to-skill overlay sync
- one visibly beautiful synthesis artifact
- intro animation

**May exist as stub**
- `ImplementationPlan`
- `LoopProfile`
- built-in browser action server
- multi-model council UI
- graph-native skill loader fork

That is enough to make the architecture feel inevitable instead of incomplete.

## The hard truths

The first hard truth is that your manifesto is stronger than your current public implementation.

That is not a criticism.  
It is actually good news.

Your repo already contains the taste, language, and system boundary thinking needed to make the submission feel authored. But the public code still shows a mixed reality: current live graph paths are still tied to existing app infrastructure; the staged Swift bridge is not yet the real UI path; and the substrate is still note-centric. So the thing that wins is **not** “I finished my new architecture.” The thing that wins is **“I exposed the truth of my architecture through one terrifyingly clear seam.”** citeturn8view3turn8view5turn14view2turn15view0

The second hard truth is that a fully graph-native editable brain is a bigger project than the hackathon.

Hermes today already has agent-managed skills, external skill dirs, a prompt-assembly skills index, session storage, browser stacks, and `execute_code`. Those are serious systems. To make “loop profiles as in-app code that Hermes runs as first-class recurrent cognition” truly real, you need a stable runtime, not just clever prompting. That is why I am strongly recommending a host-side loop runtime owned by Epistemos, with Hermes as the invoker rather than the executor. citeturn24view3turn25view0turn1view2turn26search3

The third hard truth is about the official Rust MCP SDK: the crate is real and official, but the public documentation surfaces are clearly in motion. The current docs.rs entry describes `rmcp` as the official Rust SDK, while the repo README snippet still shows an older-looking version example. I would absolutely use it—but I would hide it behind your own trait boundary immediately and keep the adapter paper-thin until you cargo-check the exact pinned version you choose. citeturn24view0turn23search6turn24view1

## Open questions and limitations

I did not inspect every file in your repo. I weighted the scan toward the public crates and architecture/audit documents that most directly affect the Hermes integration path, plus Hermes’s official docs and public repos. Where I could not directly verify a behavior from public source, I avoided treating it as settled fact. citeturn4view4turn24view3turn26search4

**UNVERIFIED:** whether the current Hermes MCP client handles the exact nested union/result richness you may want for schema-driven artifacts. The docs confirm MCP loading, filtering, and config shape, but I did not directly verify edge-case schema handling from source. Recommendation: keep tool schemas shallow and artifact payloads explicit until you probe this locally with a throwaway server. citeturn24view2turn24view6

**UNVERIFIED:** whether your existing `omega-mcp` pieces are worth directly reusing in the public MCP server instead of treating them as internal support code. The crate clearly contains registry/dispatcher/server concepts, but I did not complete a full code-level compatibility audit between those abstractions and the current official RMCP surface. citeturn17view4turn32view3turn24view0

**Operational caution:** public deadline/prize-pool wording conflicts between sources. Safest move is to behave as though submission is due by **Sunday, May 3**, with May 4 treated only as a non-guaranteed grace day. citeturn29search0turn29search1turn30search11

## TL;DR

The cleanest winning strategy is this: **upstream Hermes untouched, Epistemos native and beautiful, one brutally small Rust MCP seam between them.** Ship the graph illumination, the session subgraph, the synthesis artifact, and the skill-save payoff; postpone graph-native skill loading, loop-profile execution, and full browser control until after the deadline. citeturn24view2turn24view3turn24view5turn6view0

If you keep one internal test in mind while coding, make it this: **does this change increase the amount of real cognition that becomes visible in the graph?** If not, it is probably post-hackathon.