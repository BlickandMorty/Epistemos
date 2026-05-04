# Deep Research on Integrating Claude Managed Agents and Rowboat into a Swift/Rust PKM

## Why this is a hard integration decision

You’re choosing between two “centers of gravity” for your app:

One center is **your current local agent engine** (your loop, tools, state, scheduling, permissions), where you can support multiple models/providers and keep user data local.

The other center is **Claude Managed Agents**, which externalizes much of that machinery into a hosted runtime: long-running sessions, sandboxed execution, event streaming, tool orchestration, and production operations. citeturn21view2turn16search3turn13view4

The tension is real:

- If you **replace your whole agent infrastructure**, you inherit Claude Managed Agents’ strengths—but also accept that it’s **purpose-built for Claude**, plus beta / research-preview constraints. citeturn21view2turn13view6turn11search2  
- If you **bolt it on**, you preserve your multi-provider architecture, but you need a clean “adapter layer” so Claude Managed Agents feels native in your UX and your tool/memory abstractions don’t fragment.

A useful mental model: **treat Claude Managed Agents like a new runtime backend**, not like a “feature toggle.” That framing keeps your PKM’s memory/tool layers stable while letting you exploit Claude’s hosted orchestration where it actually helps.

## What Claude Managed Agents actually provides

Claude Managed Agents is not “just tool calling.” It’s a full stateful agent runtime with explicit APIs for durable resources.

### Core primitives and event-driven control plane

Claude Managed Agents organizes work around:

- **Agent**: versioned configuration (model, system prompt, tools, MCP servers, skills). citeturn13view6turn14search8  
- **Environment**: a reusable cloud container template (packages, outbound network policy). citeturn13view5turn14search8  
- **Session**: a running instance of an agent inside an environment, with a persistent event history and a state machine (`running`, `idle`, etc.). citeturn13view4turn16search6turn16search14  
- **Events**: the primary integration surface; your app sends user events and receives agent/session/span events for streaming, observability, interruption, and tool confirmation. citeturn13view4turn11search19  

Two integration consequences fall out of this:

1) Your UI should treat Claude Managed Agents as **session/event streaming**, not request/response chat. citeturn13view4turn11search5  
2) Your internal agent interface should converge on **“session + event log + tool calls”** even for your local engine, because that shape maps cleanly to both Rowboat-style background agents and Claude Managed Agents.

### What “managed” means in practice

The launch post positions Managed Agents as replacing months of infrastructure work: sandboxed code execution, checkpointing, credential management, scoped permissions, and tracing—plus long-running sessions whose progress persists even if the client disconnects. citeturn21view2

The docs match that intent: Managed Agents is for long-running execution, “secure containers,” minimal infrastructure, and stateful sessions. citeturn16search3turn11search2

A key constraint: Managed Agents is **purpose-built for Claude** (it’s not a generic multi-model agent runtime). citeturn21view2turn13view6  
So your “replace everything” option is only sensible if you’re comfortable choosing Claude as the orchestration brain for most workloads.

### Tools, permissions, and “don’t run my laptop” design

Managed Agents supports:

- A built-in agent toolset (including shell and file operations inside the container, plus browsing/search tools). citeturn11search2turn16search9  
- MCP toolsets (remote MCP servers over streamable HTTP transport). citeturn13view0turn10view2  
- **Custom tools** where your app executes the tool and returns results via events. citeturn13view4turn16search9  

The event stream spec is especially important for a desktop PKM: when the agent invokes a custom tool, the session pauses with `stop_reason: requires_action`, and you resume it by sending `user.custom_tool_result` events. citeturn13view4

Permissions are configurable at the toolset level, and you can even override individual tools (e.g., allow everything but require confirmation for `bash`). citeturn15view4turn13view4  
This maps directly onto a desktop safety pattern: **always-ask for state-changing actions**, auto-allow for read-only retrieval, and maintain a visible audit trail.

### Files as an integration primitive (this matters for PKM)

Managed Agents can accept **uploaded files** and mount them read-only inside the session container via `resources`, and you can list/download session-scoped files via the Files API. citeturn17view0turn16search1  
This gives you a low-friction alternative to exposing a local tool server over the internet:

- You can “snapshot” a subset of the vault (or a zip) → upload → mount → agent processes → download outputs → you merge locally.

For a privacy-first PKM, this is often the best default because you can strictly control what leaves the machine.

### Pricing and operational budgeting

Managed Agents is billed by **tokens + session runtime**, where runtime accrues only while the session status is `running` (not while idle/waiting for approvals). citeturn13view7turn13view4  
The public pricing page specifies $0.08 per session-hour in `running` status, plus standard token pricing and web search pricing when used. citeturn13view7  

This cost model is important for “agentic PKM,” because background/autonomous tasks can quietly become “always-on” unless you rate-limit and gate them with explicit schedules and budgets.

### Vaults (credential isolation) and why you probably don’t want to emulate them

For MCP auth, Managed Agents uses **vaults** to store per-user credentials and reference them at session creation via `vault_ids`, with secret fields being write-only and never returned. citeturn21view0turn13view0  

Anthropic’s engineering write-up explains the deeper design goal: keep tokens unreachable from the sandbox that runs model-generated code, and decouple harness/session logging so recovery doesn’t depend on a single container staying alive. citeturn21view1  

That’s the “mechanism” behind managed infrastructure—and it’s why copying the full system for other models is expensive: it’s not just looping tool calls; it’s **durable event logs, isolation boundaries, credential proxying, recovery semantics, and tracing**.

image_group{"layout":"carousel","aspect_ratio":"16:9","query":["Claude Managed Agents architecture diagram","Rowboat knowledge graph markdown vault screenshot","Model Context Protocol MCP diagram"],"num_per_query":1}

## What Rowboat contributes that Claude Managed Agents does not

The Rowboat project is best understood as a **local-first memory substrate + agent runtime patterns** rather than “a better agent loop.”

### Local-first knowledge graph as inspectable working memory

Rowboat’s core design is a local Markdown knowledge graph (Obsidian-compatible) stored under a predictable workspace directory and organized into entity-focused folders (people, projects, organizations, topics). citeturn10view0turn10view4turn10view1  

Rowboat emphasizes that memory “compounds”: new artifacts enrich existing entity notes rather than redoing retrieval from scratch each session. citeturn10view0turn10view6  

This is exactly the missing layer in many agentic PKMs: without an explicit, inspectable memory format, you get either:
- opaque vector-store “memory,” or  
- huge context dumps that degrade over time.

Rowboat’s “transparent working memory” approach makes it easier to debug, correct, and version changes. citeturn10view0turn10view4  

### Background agents and scheduling as a first-class product primitive

Rowboat supports autonomous scheduled agents configured via an on-disk schedule file, with a background runner that polls and executes on cron/window/once schedules, tracking state in a separate state file. citeturn19view1turn18search5  

For PKM, that translates into a crucial capability upgrade: “agents that *keep memory current*,” not just agents that answer questions.

Rowboat also stores background agent outputs/state per agent directory, and it maintains automatic version control for knowledge graph edits via git history. citeturn19view2turn10view4  

Those are implementation details you can directly lift as patterns into Rust.

### Agent runtime architecture patterns worth copying

Rowboat documents an agent runtime that includes:

- run locking (prevent concurrent execution),
- abort management,
- event streaming to a bus,
- state persistence to a runs repository,  
framed behind a single `trigger(runId)` interface. citeturn19view0  

This is almost exactly the internal shape you want if you plan to support both:
- your **local** agent engine (multi-provider), and  
- a **remote** managed-agent runner (Claude Managed Agents).

Unifying on that mental model reduces the “two agent systems in one app” problem.

### Skills as modular, on-demand context

Rowboat’s skill system is explicitly used to avoid bloating base instructions; skills are markdown modules with workflows, tool catalogs, best practices, and examples. citeturn15view1turn15view0  

Claude Managed Agents has the same *conceptual* capability: skills are reusable resources that load on demand and don’t always hit the context window. citeturn15view3turn15view4  

This convergence suggests a strong architectural move for your PKM:

Define **skills as files** in your own repo/vault (or as versioned bundles), and treat them as a portable, provider-agnostic concept. That way, “skills” exist locally even if the execution brain changes.

### MCP integration, but with important differences

Rowboat supports MCP connections through a local config file and can use both local process transports and remote HTTP/SSE servers. citeturn10view2turn9search6  

Claude Managed Agents’ MCP connector supports **remote MCP servers over streamable HTTP transport** and explicitly separates declaring servers on the agent from providing auth via vaults at session creation. citeturn13view0turn21view0  

Implication: if you want your PKM’s tools to be callable via MCP by both Rowboat and Managed Agents, you’ll need to support a remote-accessible MCP endpoint (or a relay). But you may not need MCP at all to integrate your own vault operations into Managed Agents—custom tools via events are often simpler.

## Recommended architecture for your Swift/Rust PKM

### Core principle: stabilize the memory and tool layers, treat runtimes as plugins

The highest-leverage choice is:

**Do not replace your entire agent infrastructure.**  
Replace your *agent runtime interface* (the abstraction), then add Claude Managed Agents as a backend runtime.

Why? Because Managed Agents is Claude-specific. citeturn21view2turn13view6  
If you “rip and replace,” you end up with either:
- a Claude-only app, or  
- a fragmented codebase with duplicated orchestration.

Instead, aim for three stable layers:

**Memory Layer (local, inspectable)**  
A Markdown knowledge graph with YAML frontmatter + backlinks, plus local indexing (full-text, optional embeddings). Rowboat’s directory conventions are a good starting point because they’re human-editable and Obsidian-compatible. citeturn10view1turn10view3turn10view4  

**Tool Layer (provider-agnostic contract)**  
Define a tool contract that matches what agents actually need to do in a PKM:
- search notes
- read note
- create/update note (structured patch, not blind overwrite)
- list backlinks / outgoing links
- create “artifact packs” (zip exports, bibliographies, outlines)
- propose changes as “diffs” with metadata

You can implement this contract:
- locally (your existing tool executor), and  
- remotely (Managed Agents via custom tool calls + event responses). citeturn13view4turn16search9  

**Runtime Layer (pluggable orchestration engines)**  
- Local runtime: your current multi-provider agent loop, upgraded to match the session/event abstraction.
- Managed runtime: Claude Managed Agents sessions (agent+environment+session+events). citeturn16search3turn13view4  

### Two practical integration patterns with Claude Managed Agents

#### Snapshot and merge (best default for privacy-first PKM)

Mechanism:
1) User selects scope (folder/tag/project/time range).  
2) App exports a **read-only snapshot** (zip or a curated file list).  
3) Upload + mount into session container via `resources`. citeturn17view0turn13view5  
4) Agent produces outputs (new notes, updated summaries, research reports) inside container.  
5) App downloads outputs via Files API and merges locally (show diffs). citeturn17view0turn16search1  

This pattern is compatible with:
- long-running “deep research” tasks,
- rewriting/refactoring notes,
- generating structured artifacts (outlines, bibliographies, study guides),
- minimizing the chance an agent can “wander” across your entire vault.

#### Live tool calls (best for interactive workflows)

Mechanism:
- You define your PKM operations as **custom tools** in the agent configuration.
- When Claude calls a custom tool, your app receives `agent.custom_tool_use`, executes locally, and responds with `user.custom_tool_result`. citeturn13view4turn16search9  

This avoids exposing any inbound service from the user’s machine. Your app just needs to stay connected (or intermittently reconnect) to process outstanding “requires_action” events. citeturn13view4  

This is the cleanest way to unify UX: it feels like local agents, but Claude does the orchestration.

### How Rowboat patterns map directly onto your Rust backend

Rowboat’s runtime and background agent scheduling imply a strong blueprint for your Rust core:

- Represent “runs” with IDs, persisted state, and an append-only event log. citeturn19view0turn13view4  
- Implement abort/stop semantics and a message bus for streaming UI updates. citeturn19view0turn13view4  
- Implement background schedules via a config file (cron/window/once), plus a state file that the runner owns. citeturn19view1  
- Store per-agent outputs and states in a predictable directory (so users can inspect). citeturn19view2turn10view4  
- Consider automatic versioning of knowledge graph edits (Rowboat uses git). citeturn19view2turn10view4  

Resolution: your “wrist agent loop” doesn’t need to disappear. It needs to evolve from “loop logic entangled with tools/memory” into “one runtime behind a stable interface.”

## Implementation roadmap that minimizes rewrites

### Foundation refactor: converge on session/event semantics

Goal: make local agents and managed agents look the same in your UI.

- Model: `Session { id, runtime_type, status, events[], tool_requests[] }`.  
- Streaming: UI subscribes to an event stream; local runtime publishes events just like Claude’s event stream does. citeturn13view4turn19view0  

This is the pivot that unlocks everything else.

### Memory upgrade: adopt an inspectable knowledge graph format

Implement:
- a vault directory with entity-style folders (people/projects/orgs/topics) and backlinks, Obsidian-compatible. citeturn10view1turn10view3  
- YAML frontmatter for stable fields (ids, aliases, timestamps, provenance). citeturn10view3turn15view0  
- indexing: at minimum full-text + metadata; embeddings optional.

The key is not “graph visualization.” It’s **stable, rewrite-safe canonical notes** that agents can update incrementally.

### Background agents: make “memory upkeep” automatic

Implement schedules (cron/window/once) and a runner that:
- polls on a fixed cadence,
- triggers runs,
- persists state, failures, and outputs. citeturn19view1turn19view2  

This is where PKM becomes “alive.”

### Add Claude Managed Agents as a runtime backend

Start with a narrow set of workflows that benefit from managed infrastructure:

- Deep research sessions (web browsing, long tool chains)  
- Large refactors of note structure  
- Artifact generation that benefits from sandboxed execution (e.g., scripts that transform data)  

Managed Agents requires a beta header and uses explicit `/v1/agents`, `/v1/environments`, `/v1/sessions` resources. citeturn13view6turn13view5turn13view4  

Treat this as an adapter:
- Create/maintain agent definitions as versioned resources. citeturn13view6  
- Use strict environment networking (start limited unless you truly need unrestricted). citeturn13view5  
- Prefer snapshot+merge for privacy; fall back to custom tools for interactive tasks. citeturn17view0turn13view4  

### Optional “advanced” Managed Agents features (only if they align)

These are compelling but should not be hard dependencies because they’re research preview / gated:

- Multi-agent sessions (parallel sub-agents with isolated context threads). citeturn13view2turn13view6  
- Outcomes (grader/rubric loop with separate context window for evaluation). citeturn13view3turn21view2  
- Agent memory stores (persistent cross-session memory with versioning). citeturn13view1  

If your main value proposition is a local-first PKM memory graph, you may not need Agent Memory at all—your vault is the durable memory.

## Risks, tradeoffs, and the “should I copy it for other models?” question

### Vendor lock-in vs capability density

Claude Managed Agents is explicitly “purpose-built for Claude.” citeturn21view2turn13view6  
So an architecture that *requires* it will bias you toward Claude-only orchestration over time.

The counterweight is to keep:
- memory local and portable (Markdown vault), and  
- tools defined in your own contract.

That keeps your PKM’s “brain substrate” independent even if you swap runtimes.

### Security: tool-calling agents are inherently risky if over-privileged

Anthropic’s own engineering rationale emphasizes keeping creds out of sandboxes and using vault/proxy patterns so the harness never sees tokens. citeturn21view1turn21view0  

On the research side, there is growing literature showing why least-privilege authorization for tool-calling agents matters and why agents tend to overreach without strong confinement. citeturn14academia41  

For your PKM, the practical stance is:

**CRITICAL WARNING:** never let an agent have blanket write access to the whole vault without a review step.

Rowboat’s patterns (stored outputs, versioning, inspectable files, explicit schedules) are aligned with containment-by-design. citeturn19view2turn19view1turn10view4  

### Cost creep and “always-on” background autonomy

Managed Agents charges session runtime while running plus tokens, and web search has its own metered pricing. citeturn13view7turn13view4  
Background autonomy can explode costs without guardrails—so you want local scheduling + quotas + explicit scopes regardless of runtime.

### Can you realistically “engineer a copy” for other models?

You can emulate *parts* of Managed Agents with open-source building blocks, but copying the whole system means recreating:

- durable session logs and replay semantics,
- sandbox isolation boundaries,
- credential proxy/vault mechanics,
- permissioning policies and approval UX,
- end-to-end tracing and recovery behavior. citeturn21view2turn21view1turn13view4  

The pragmatic alternative is:  
build a **local-first “agent harness”** (Rowboat-inspired) that works with many models, and optionally outsource “hard mode” sessions to Claude Managed Agents when users opt in.

This gives you the best of both:

- local-first PKM as the canonical memory,  
- managed cloud runtime as an accelerant, not a dependency.

**TL;DR:** Don’t replace your whole agent engine. Stabilize your memory + tool interfaces, adopt Rowboat’s local-first knowledge graph + background scheduling patterns, and integrate Claude Managed Agents as an additional runtime backend using either snapshot+merge (privacy-first) or custom tools via events (interactive). citeturn21view2turn13view4turn10view0turn19view1

Check for understanding: in your app today, do your agents already execute “tools” through a single registry/interface (even if it’s internal), or are tool calls tightly coupled to your current loop implementation?