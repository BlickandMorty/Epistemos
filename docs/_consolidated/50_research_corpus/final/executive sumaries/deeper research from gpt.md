# Epistemos and Hermes Final Integration Doctrine

## Executive verdict

The deepest conclusion is simple.

**Do not build Hermes as “just another chat provider inside your app.”**  
Build **Hermes** as the **graph-native faculty** of Epistemos, and treat **Claude Code**, **Codex**, **Gemini CLI**, and optionally **Qwen Code / Qwen-Agent** as **delegated specialist runtimes** that Hermes or your internal router can call when the task is implementation-heavy rather than memory-heavy. If you flatten all of them into equal peers, you lose the very thing that makes your app defensible: the graph as runtime, the session as structure, and the visual proof that reasoning is altering substrate state in real time. The official Hermes docs and repo support that strategy: Hermes already has profiles, skills, MCP, browser automation, memory providers, cron, plugins, and code execution; it is designed to grow capabilities over time rather than sit behind a single prompt box. citeturn25search10turn27search0turn27search1turn27search2turn27search5turn27search18turn27search20

Your own public code strongly supports this direction **but also forces capability honesty**. The public Epistemos repo on entity["company","GitHub","developer platform"] already contains a Rust-owned `substrate-core`, a transparent generational `EntityId` over `u64`, an append-only action log persisted to SQLite, and an `omega-mcp` crate with JSON-RPC / stdio transport scaffolding. But the same repo also shows that the public `substrate-core` is still **minimal and Note-centric**, and `omega-mcp` explicitly says its JSON-RPC layer is “not a full server yet.” Your architecture docs also say one important live path still has “no automatic live Swift consumer in the main UI today.” So the right move is **not** to pretend the whole thought-graph runtime is already complete. The right move is to wire the **live event plane**, the **actual MCP bridge**, and the **typed UI registry** on top of what is already true. citeturn5view0turn8view0turn10view0turn10view1turn10view2turn11view0turn11view1turn4view6

There is one more truth-first correction. Your manifesto keeps saying **“six verbs”**, but the actual surface you list is **seven**: `search_semantic`, `search_fulltext`, `get_node`, `traverse`, `create_node`, `create_edge`, `commit_session`. That is not a problem. It is a naming problem. Treat `commit_session` as a **lifecycle verb**, not part of the core cognition surface. Then the architecture stays clean: **six graph verbs + one session-finalization verb**. That distinction matters because session commit belongs to narration, persistence, and replay, not to ordinary reasoning.

The most important product conclusion is this: **the path to “100% Hermes coverage” is not to let the model invent arbitrary SwiftUI at runtime.** The path is a **three-layer rendering stack**:  
first, a universal **event stream** that makes every tool call, thought step, stdout burst, and graph mutation visible;  
second, a **typed schema registry** for high-value semantic surfaces like `RawThought`, `Recall`, `Skill`, `LoopProfile`, `ImplementationPlan`, and `Synthesis`;  
third, a **generic fallback renderer** for everything else—JSON trees, tables, key-value objects, markdown, diffs, media, and links. That is how you get both determinism and coverage. Anything else either collapses into hand-coded mapping hell or into unreliable “AI-generated UI” theater. The provider ecosystems all point in this direction: Claude’s Agent SDK streams typed messages; Codex formalizes skills and subagents; Gemini documents JSON and NDJSON-like stream output; Qwen Code has recent extension and MCP management layers. citeturn31view3turn31view4turn32view3turn32view4turn33view0turn33view2turn34view1turn34view3turn34view4

## What the codebases already support

On the Epistemos side, the public substrate is real enough to build on. `substrate-core` is described as the canonical Rust-owned entity store plus AppAction event log; `EntityId` is a transparent generational `u64`; the store uses `DenseSlotMap`, a log mirror, and a single `apply(action)` mutation path; the SQLite `EventLog` persists serialized actions in `action_log`; and the current public entity/action model still centers on `Note`, `Folder`, `Chat`, `Idea`, and `Tag`, with links still reconstructable from replay rather than fully stored as first-class graph edges. In plain terms: you already have **identity**, **mutation grammar**, **replay**, and **durability**; what you do **not** yet publicly have is the richer typed thought taxonomy you want for the Hermes demo. That means the hackathon bridge should sit **above** the current substrate and not force a deep substrate rewrite first. citeturn5view0turn8view0turn10view0turn10view1turn10view2

`omega-mcp` is also telling. The crate already depends on UniFFI plus JSON, SQLite, `nix`, and `memmap2`, and its transport layer already enforces newline-delimited JSON-RPC over stdio. But `server.rs` still says “wire protocol parsing — not a full server yet.” That is exactly the right kind of unfinished: you already proved you can own the transport, but you should now stop inventing your own MCP dialect and put a real MCP surface on top, keeping domain code and transport code separated. citeturn7view0turn11view0turn11view1

The public architecture docs reinforce the same diagnosis. Your live query path exists. Your Swift → Rust → transaction → subscription wiring exists. A staged knowledge-core mutation path exists. But the docs also explicitly say the main UI still lacks an automatic live Swift consumer for one of the Rust mutation paths. That is why the app can feel “dead” during autonomous work even when serious logic is happening underneath. The fix is not a cosmetic animation pass. The fix is a first-class **event bus** from provider output and graph mutations into the renderer. citeturn4view6

On the Hermes side, the current surface is unusually favorable for your vision. Hermes exposes an MCP client with stdio and HTTP transport support and dynamic refresh when servers emit `tools/list_changed`. Its skills system is file-backed and uses `SKILL.md` plus YAML frontmatter, supporting local skill roots, external skill directories, and profile isolation through `HERMES_HOME`. It has a plugin hook system with `pre_tool_call`, `post_tool_call`, `pre_llm_call`, `post_llm_call`, and session lifecycle hooks. It also has a code execution sandbox that is POSIX-only and, by default, only allows seven tools inside the sandbox: `web_search`, `web_extract`, `read_file`, `write_file`, `search_files`, `patch`, and `terminal`, with a default timeout of 300 seconds and a default ceiling of 50 tool calls. That is enough to implement loop execution and graph-aware work without inventing new machinery on day one. citeturn18view0turn18view1turn18view2turn18view3turn18view4turn18view5turn27search1turn27search2turn27search5turn27search7

There are also current Hermes edge cases you should design around rather than discover late. Public issue discussion shows that `skill_manage` has recently had trouble editing skills loaded from `external_dirs`, and another fresh issue argues that newly created skills may not become visible in the current session until the cached system prompt is invalidated. Those are not reasons to abandon graph-backed skills. They are reasons to **avoid relying on `external_dirs` for the load-bearing path** and to **own the refresh/invalidation mechanics yourself**. citeturn16search2turn17search0

## Architecture decisions you should make now

### Make Hermes privileged

The clean architecture is:

**Epistemos** owns truth.  
**Hermes** owns graph-native deliberation over that truth.  
**Other coding agents** are workers.

That means Hermes gets the **privileged substrate contract**: session graph, recall nodes, skill nodes, loop profiles, session commit, and visual graph instrumentation. Claude Code, Codex, Gemini CLI, and Qwen Code do **not** get that same privileged surface. They get normalized provider adapters and worktree-scoped execution contexts. Their outputs can become nodes, but they do not become the mind of the app.

That distinction is the moat.  
Without it, you have a router.  
With it, you have a cognitive substrate.

### Use a three-plane runtime

The strongest technical shape is a **three-plane runtime**.

The **graph plane** is your Rust truth layer: nodes, edges, sessions, recalls, syntheses, skills, loop profiles, and event persistence. Your public repo already has the core store/log story; extend rather than replace it. citeturn10view0turn10view1turn10view2

The **event plane** is the missing aliveness layer. Every provider adapter and every graph mutation emits typed `AgentEvent`s. This is where tool start/finish, reasoning deltas, model dispatch, browser actions, skill loads, recalls, and node creation get unified. Claude’s Agent SDK streaming model, Gemini’s `stream-json`, and Hermes’ plugin/MCP surfaces all make this feasible if you put the adapter boundary in Rust and treat the UI as a subscriber rather than a parser. citeturn31view3turn31view4turn18view2turn33view0turn33view2

The **view plane** is SwiftUI plus Metal. SwiftUI should own semantic panels and inspectors. Metal should own live graph cognition effects—pulse, flash-edge, phase-in, glare-pass, camera focus. Do **not** ask SwiftUI to fake high-frequency graph activity. Your own architecture docs already separate live query and staged mutation paths in a way that fits this split. citeturn4view6

### Prefer bounded synthesis over unconstrained UI generation

Your intuition about “auto-generated schema UI” is directionally right, but the implementation has to be disciplined.

The disciplined version is:

- **Known semantic payload** → dedicated SwiftUI view via schema registry.  
- **Unknown object payload** → generic renderer.  
- **Everything that happens over time** → event cards / live timeline.

This gives you nearly total coverage **without** requiring the model to author arbitrary interface structure on the fly. It also means pressing `@` can remain deterministic: the mention resolver can insert known node references, resources, skills, sessions, and model workers without special-casing every future Hermes capability.

## Multi-provider stack without losing the plot

You asked for **no compromises** and **maximum moat**. The way to do that is not “pick one model.” The way is to assign each runtime a role it is uniquely good at.

### Hermes as the cognitive faculty

Hermes is the one that should speak the Epistemos graph natively. It already has the right primitives: profiles, MCP, skills, plugin hooks, code execution, browser automation, memory providers, and cron. That makes it the right home for the app’s dedicated “Hermes mode,” the session subgraph, vault recall, skill capture, and self-improvement surface. citeturn25search10turn27search0turn27search1turn27search2turn27search5turn27search18turn27search20

### Claude Code as the premium implementation worker

**Top contender when the task is deep code modification with strong orchestration.**  
entity["company","Anthropic","ai company"]’s docs show three things that matter here: the Agent SDK gives you the same tools, loop, and context management as Claude Code; it streams messages programmatically; and Claude Code has hook points plus subagents. That makes Claude the best outside worker when you want high-trust repo exploration, controlled approvals, or long implementation runs that should still surface structured progress back into Epistemos. My recommendation is **not** to embed Claude Code as the primary in-app faculty. Use it as a delegated worker launched from a helper process or service boundary, with its stream normalized into your `AgentEvent` bus. citeturn31view3turn31view4turn31view2turn31view6turn31view0turn31view1

### Codex as the cleanest MCP-native coding worker

**Top contender when you want clean interoperability and an MCP-first coding lane.**  
entity["company","OpenAI","ai company"]’s current docs show that Codex is open source and Rust-based, uses project-scoped `.codex/config.toml`, supports skills and custom agents, and can itself be launched as an MCP server exposing a persistent coding conversation through `codex()` / `codex-reply()`. That is strategically huge for you. It means Codex does **not** have to be scraped through a brittle pseudo-TTY or manual log parser. It can sit inside your architecture as an MCP-addressable specialist runtime. Among the external coding agents, this is the cleanest fit with your desire for everything “speaking MCP.” citeturn32view0turn32view2turn32view3turn32view4turn32view5turn32view6turn28search2turn28search9

### Gemini CLI as the best scripting and streaming worker

**Top contender when you want headless automation with well-documented structured output.**  
The official repo for entity["company","Google","technology company"]’s Gemini CLI documents non-interactive `-p`, `--output-format json`, and `--output-format stream-json`. It also has a detailed MCP integration guide, including tool/resource discovery, three transport types, and `@server://resource/path` references. That makes Gemini the best worker when you want deterministic, parseable scripted runs that Epistemos can mirror in a native view without a lot of glue code. If you want one provider whose CLI surface screams “event adapter,” Gemini is it. citeturn33view0turn33view1turn33view2

### Qwen Code and Qwen-Agent as the interoperability wildcard

**Top contender when you want openness, extension import, and a path toward more local or self-hosted control.**  
Qwen’s current docs show MCP support, a recent move toward auto-memory and session persistence, and an extension system that can package prompts, MCP servers, subagents, skills, and commands—and even ingest extensions from the Claude marketplace and Gemini gallery. Qwen-Agent also explicitly supports MCP and recommends Qwen-native tool parsing for Qwen3-class models. I would not make Qwen the first load-bearing lane for the hackathon unless you already have it running smoothly, but I **would** architect the provider router so Qwen can be dropped in later as either a coding worker or a more open agentic framework for experiments. citeturn34view0turn34view1turn34view2turn34view3turn34view4turn34view5turn21search3turn29search12

### Local Qwen on MLX as the recall tier

Your local model should do **ambient recall, reranking, cheap synthesis primitives, schema filling, and low-latency question answering over the current session context**—not every glamorous task. The current MLX Swift project explicitly supports language-model work through `mlx-swift-lm`, and Qwen docs keep pointing toward MCP-aware agent use for tool calling. So the winning pattern is: **local Qwen handles the “always-on cognition” layer**, while Hermes plus cloud-grade specialists handle expensive synthesis and execution. That is how you get the “instant ambient recall” feel without turning the whole stack into a latency tax. citeturn29search1turn29search0turn21search3turn34view5

## Concrete implementation blueprint

### Build the event bus first

This is the load-bearing change.

Without it, the app stays conceptually impressive but experientially dead.  
With it, everything starts to feel alive.

I would define a normalized Rust event model that every provider adapter, MCP bridge, and graph mutation publisher can emit. Then bridge **that** to Swift through UniFFI. This is where your “full coverage” comes from.

```rust
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum AgentEvent {
    SessionStarted {
        provider: String,
        session_id: String,
    },
    MessageDelta {
        text: String,
    },
    ThinkingDelta {
        text: String,
    },
    ToolCallStarted {
        provider: String,
        call_id: String,
        tool_name: String,
        args: Value,
    },
    ToolCallDelta {
        call_id: String,
        chunk: String,
    },
    ToolCallFinished {
        call_id: String,
        ok: bool,
        result: Value,
    },
    GraphMutation {
        op: String,
        node_ids: Vec<String>,
        edge_ids: Vec<String>,
    },
    ArtifactReady {
        schema: String,
        payload: Value,
    },
    SkillLoaded {
        skill_name: String,
        node_id: Option<String>,
    },
    SkillSaved {
        skill_name: String,
        node_id: String,
    },
    Error {
        message: String,
        recoverable: bool,
    },
}
```

The key design rule is this: **do not let providers talk to Swift directly**.  
Every provider emits `AgentEvent`.  
Swift renders `AgentEvent`.  
The graph reacts to `AgentEvent`.  
That one decision keeps the system composable.

### Replace ad-hoc MCP wire code with a real façade + adapter split

The public Epistemos repo already proves you understand JSON-RPC and stdio, but the official Rust MCP SDK now exists and explicitly supports building clients and servers. Hermes’ MCP client also supports stdio and streamable HTTP and can refresh tools dynamically when a server emits `tools/list_changed`. So the right architectural boundary is:

- a **domain façade** that knows nothing about MCP;
- an **MCP adapter crate** that exposes the façade over rmcp;
- an **event publisher** that emits `GraphMutation` / `GraphEvent` whenever a tool executes. citeturn23search0turn23search1turn18view4turn18view5

Because your public `EntityId` is a `u64`, I recommend exposing node IDs to MCP as **strings**, not JSON numbers. That is an inference from the public type shape and common client interoperability constraints: it preserves exact identity across JavaScript-heavy clients without ambiguity. The façade should remain transport-agnostic.

```rust
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeRef {
    pub id: String,      // decimal or base36 string
    pub kind: String,
    pub title: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetNodeResult {
    pub id: String,
    pub kind: String,
    pub title: String,
    pub body: String,
    pub metadata: serde_json::Value,
    pub backlinks: Vec<NodeRef>,
}

pub trait GraphFacade: Send + Sync {
    fn search_semantic(&self, query: &str, limit: usize) -> anyhow::Result<Vec<NodeRef>>;
    fn search_fulltext(&self, query: &str, limit: usize) -> anyhow::Result<Vec<NodeRef>>;
    fn get_node(&self, id: &str) -> anyhow::Result<GetNodeResult>;
    fn traverse(&self, seed_id: &str, hops: u8, limit: usize) -> anyhow::Result<Vec<NodeRef>>;
    fn create_node(&self, kind: &str, title: &str, body: &str, metadata: serde_json::Value)
        -> anyhow::Result<NodeRef>;
    fn create_edge(&self, from: &str, to: &str, edge_kind: &str) -> anyhow::Result<()>;
    fn commit_session(&self, session_id: &str, summary: Option<&str>) -> anyhow::Result<()>;
}
```

This is also where you should resolve the public/private mismatch in your current codebase. The public substrate is still note-first. So for the hackathon, `RawThought`, `Recall`, `Synthesis`, `Skill`, and `Session` can exist first as **higher-level graph kinds in the façade**, even if they are projected onto the current storage model underneath.

### Use skill projection now, graph-native skill loading later

This is the most important “top contender” decision in the whole report.

**Contender A — projection layer from graph → SKILL.md files.**  
This is the best hackathon path. Hermes currently expects file-backed skills with `SKILL.md`, YAML frontmatter, and optional references/assets. It also already knows how to discover them. So let Epistemos remain the source of truth, but **materialize** `Skill` nodes into a profile-scoped skill directory that Hermes reads natively. When Hermes edits or creates a skill, your projection service writes the diff back into the graph and republishes. This keeps routing behavior intact because the skill still enters Hermes through the mechanism it already understands. citeturn18view0turn18view1turn19search0turn27search2

**Contender B — patch Hermes skill loading to read the graph directly.**  
This is the post-hackathon truth. It is the purest expression of your architecture, but it is more invasive because it touches discovery, skill viewing, skill management, prompt building, and probably session cache invalidation. The current public issue traffic around `external_dirs` and refresh behavior is a warning sign that the skill lifecycle path is still evolving. citeturn16search2turn17search0

**Contender C — make skills just another MCP tool.**  
This is insufficient. A management tool can create and edit skills, but it will not replace the fact that skills matter **before** ordinary tool calls, because they affect routing and prompt construction.

So my recommendation is decisive:

**Hackathon:** projection layer.  
**Afterward:** graph-native loader fork or upstream patch.

```rust
pub struct SkillMaterializer {
    pub skill_root: std::path::PathBuf,
}

impl SkillMaterializer {
    pub fn materialize(&self, node: &SkillNode) -> anyhow::Result<std::path::PathBuf> {
        let dir = self.skill_root.join(&node.slug);
        std::fs::create_dir_all(dir.join("references"))?;

        let frontmatter = format!(
            "---\nname: {}\ndescription: {}\nversion: {}\n---\n\n",
            node.name, node.description, node.version
        );

        std::fs::write(dir.join("SKILL.md"), format!("{frontmatter}{}", node.instructions))?;

        for reference in &node.references {
            std::fs::write(dir.join("references").join(&reference.file_name), &reference.body)?;
        }

        Ok(dir)
    }
}
```

One crucial detail: because Hermes currently treats local skill roots and external skill roots differently in some edge cases, I would prefer a **profile-scoped managed HERMES_HOME** that Epistemos owns, rather than relying on `external_dirs`, until you intentionally patch that path. citeturn18view1turn16search2turn27search5

### Make loop profiles a hybrid manifest, not just raw Python

Hermes’ code execution tool is already strong enough to act as a backend for loop execution: POSIX support, a bounded tool allowlist, Unix-domain-socket or file-based RPC, and resource limits are all already there. But that does **not** mean your loop profile format should just be “whatever Python the user typed.” The right design is a **hybrid manifest**:

- typed frontmatter expressing target kind, inputs, allowed models, convergence policy, side effects, and view schema;
- body sections that can be either built-in steps or Python snippets executed through Hermes / a helper sandbox;
- graph-native persistence and versioning in Epistemos. citeturn18view3

That gives you auditability, portability, and schema-driven invocation. It also means a loop profile is not “a trick.” It becomes a first-class thought primitive.

A good minimal format is:

```yaml
kind: LoopProfile
name: deepen-thought
targets: [RawThought]
engine: hermes_execute_code
max_rounds: 4
stop_when:
  convergence_at_least: 0.86
steps:
  - kind: semantic_neighbors
    k: 20
  - kind: assert_relations
  - kind: dispatch_synthesis
    provider: claude_code
    output_schema: ImplementationPlan
  - kind: write_node
    node_kind: ImplementationPlan
```

Then let one or more steps call a Python backend when truly needed.  
That keeps the **editable brain** real without making it ungovernable.

### Use a schema registry plus a guaranteed fallback renderer

This is the other half of full coverage.

The registry should map `schema_id -> decoder -> SwiftUI view`.  
But the absolutely essential piece is the fallback.  
If the schema is unknown, the object still renders.

```swift
import SwiftUI

protocol SchemaRenderable: Decodable {
    static var schemaID: String { get }
}

struct RegisteredRenderer {
    let schemaID: String
    let render: (Data) throws -> AnyView
}

@MainActor
final class ViewRegistry: ObservableObject {
    private var renderers: [String: RegisteredRenderer] = [:]

    func register<T: SchemaRenderable, V: View>(
        _ type: T.Type,
        @ViewBuilder makeView: @escaping (T) -> V
    ) {
        renderers[T.schemaID] = RegisteredRenderer(schemaID: T.schemaID) { data in
            let value = try JSONDecoder().decode(T.self, from: data)
            return AnyView(makeView(value))
        }
    }

    func view(for schemaID: String, payload: Data) -> AnyView {
        do {
            if let renderer = renderers[schemaID] {
                return try renderer.render(payload)
            } else {
                let object = (try? JSONSerialization.jsonObject(with: payload)) ?? [:]
                return AnyView(GenericObjectInspector(schemaID: schemaID, object: object))
            }
        } catch {
            return AnyView(RenderErrorView(schemaID: schemaID, error: String(describing: error)))
        }
    }
}
```

That one file is the bridge between “Hermes can return arbitrary structured artifacts” and “the app still stays native, stable, and debuggable.”

My specific recommendation is to pre-register only six load-bearing semantic panels for the hackathon:

- `RawThought`
- `Recall`
- `Synthesis`
- `Skill`
- `Session`
- `ImplementationPlan`

Then keep `LoopProfile` and browser/task artifacts supported by the fallback inspector until their bespoke views are worth the effort.

### Browser strategy

Here the truth is uncomfortable but useful.

Hermes already ships with browser automation backends—Browserbase cloud, Browser Use cloud, local Chrome via CDP, and local Chromium. That means the fastest path to a compelling demo is **not** to re-implement full browser control from scratch before the deadline. The fastest path is to let Hermes use its native browser toolchain while Epistemos mirrors the resulting activity and stores excerpts/findings into the graph. After the hackathon, you can formalize a `browser-actions` MCP server for a native `WKWebView` surface if you still want the “Hermes sees my tab” model. citeturn27search0

So the decision is:

**Hackathon:** Hermes browser tools drive web work; Epistemos visualizes and stores the result.  
**Afterward:** native browser control bridge.

That is not compromise.  
That is sequencing the real dependencies in the correct order.

### Native macOS packaging doctrine

Because you are building native on macOS, the packaging decision is not decorative.

entity["company","Apple","technology company"]’s documentation is clear on two points that matter here: sandboxed child processes inherit the parent app’s sandbox, and `Process` documentation recommends XPC services rather than arbitrary spawned helpers for many sandboxed situations; meanwhile notarization requires hardened runtime, and that affects hosted plug-ins and helpers too. The practical consequence is straightforward: if you want to bundle or launch helper binaries for Hermes, Codex, Gemini CLI, local model workers, or custom loop runtimes, the safest hackathon-friendly target is **Developer ID outside the Mac App Store**, with signed and notarized helper components. If one day you want App Store distribution, plan on moving privileged helpers behind XPC and treating arbitrary spawned CLIs as a product constraint, not a footnote. citeturn24search3turn24search12turn24search2turn24search17

## Hackathon-winning slice

The slice that wins is **not** “all features.”  
It is the smallest slice that makes the whole architecture undeniable.

That slice is:

**one real Hermes research session against your actual graph**  
**with live graph activity**  
**ending in a first-class synthesis node**  
**and a saved skill node that shows learning crossed the substrate boundary.**

Everything else should orbit that.

My recommended demo spine is:

- Launch / Hermes handoff.
- Ask a real cross-domain query against your own vault.
- Hermes uses MCP graph tools.
- Graph pulses, flashes edges, phases in a new node.
- You click the new `Synthesis` node and it opens in a native panel with backlinks.
- Hermes saves or patches a skill, and you show that the skill is now visible as a graph entity for the next session.

That one clip proves:

- graph-as-runtime,
- Hermes-as-faculty,
- structural recall,
- self-improvement,
- native UI,
- and aesthetic craft.

It also maps directly to what the official Hermes surfaces already make possible. Hermes’ MCP tooling is real; its skill system is real; browser automation is real; profiles and memory isolation are real. You do **not** need to fake any of it. citeturn25search10turn27search1turn27search2turn27search5turn27search20

The hackathon logistics themselves need one explicit caution. Public sources are slightly inconsistent. The launch post says the creative hackathon started April 17 with 16 days and a $25k pool; HermesOS says submissions are due end of day May 4; a Reddit/community mirror phrases the deadline as EOD Sunday May 3 and breaks out the track pools; and a later reminder post mentions a **$26,000** prize pool. Treat the submission mechanics as real but the exact final cutoff/prize framing as **operationally unstable until you verify in the Nous Discord submission channel**. The stable public requirement across sources is the same: post a demo video on X tagging entity["organization","Nous Research","ai company"], then submit the post link in the Discord submissions channel; the event is presented with entity["company","Moonshot AI","kimi company"] / Kimi. citeturn25search0turn25search1turn25search5turn25search8

If you want the ruthless nine-day implementation order, it is this:

First, land the **real MCP server** and the **event bus**.  
Second, land **graph instrumentation** and **session subgraph focus**.  
Third, land **skill projection** and one **skill save/reload** loop.  
Fourth, land the **schema registry** with the six load-bearing views.  
Fifth, land the **hero animation** and polish.  

Not because the animation is unimportant.  
Because the animation without the event plane is costume.

## Open questions and limitations

A few things remain genuinely unresolved and should stay marked as such.

**UNVERIFIED:** the exact best insertion point for graph-native skill writes inside Hermes without carrying a long-lived fork. The current public evidence strongly suggests projection is the right near-term move, but I did not point to a single official extension point that already replaces native skill storage end-to-end. The repo and issues show enough to judge the risk surface, not enough to claim a zero-patch direct path. citeturn18view1turn16search2turn17search0

**UNVERIFIED:** the exact current structured event surface of Hermes CLI output that you can rely on without patching or wrapping. Hermes clearly has plugin hooks, browser tooling, code execution, and MCP; what is less clearly documented publicly is the cleanest official way to get a rich per-token / per-step event stream into your own native UI without either reading CLI output or adding a small source patch. citeturn18view2turn18view3turn27search1

**UNVERIFIED:** whether your private or local Epistemos code is already meaningfully ahead of the public repo in typed graph support. The public repo proves a strong substrate, but it does not yet prove the complete `RawThought` / `ImplementationPlan` / `Recall` / `Skill` / `LoopProfile` / `Synthesis` runtime. If your local branch already has more, great. If not, the façade-layer strategy above is the honest way to bridge the gap. citeturn10view0turn10view1turn10view2turn4view6

**UNVERIFIED:** what you meant by “chemical code.” I did not find a current coding-agent product that cleanly maps to that phrase in this context, so I treated the meaningful third/fourth provider lane as **Gemini CLI** and **Qwen Code / Qwen-Agent**, because those are the current documented contenders that make technical sense beside Claude Code, Codex, Hermes, and local MLX/Qwen.

## TL;DR

Build **one living system**, not five parallel gimmicks.

**Hermes should become the native, graph-privileged faculty of Epistemos.**  
**Claude Code, Codex, Gemini CLI, and Qwen Code should become delegated workers behind a normalized event bus.**  
**Your UI should render events first, schemas second, and generic fallbacks always.**  
**Your hackathon win comes from proving that the graph is the runtime—not from pretending every future subsystem is already finished.**