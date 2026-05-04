# EPISTEMOS × HERMES
## A Deep Research Manifesto

> A document in three parts. Part I is the soul — the architectural and aesthetic conviction. Part II is the executable research brief, written to be pasted directly into a deep-research agent (Hermes itself, Claude with research mode, or any equivalent). Part III is the compressed vector — how the next nine days express the full vision without amputating it.
>
> Nothing in this document is aspirational. Every claim either describes what is already running on the author's machine or names the precise research path required to make it run. Capability honesty throughout.

---

## PART I — THE MANIFESTO

### I. Premise

Most software has confused the file with the thought.
Most agents have confused the chat window with cognition.
Most "AI-native apps" are wrappers that bolt a sidecar onto a stale paradigm and call it intelligent.

Epistemos rejects all of this.

Epistemos is not a notes app. It is not a PKM tool. It is not a chatbot with a knowledge graph attached. It is a **cognitive substrate** — a typed, persistent, GPU-rendered field on which thinking happens, and from which thinking leaves a structural trace.

Hermes is not a feature of Epistemos. Hermes is one of its **faculties** — in the way that memory is a faculty of mind, or attention. The agent does not connect to the substrate over a wire. It lives inside it. The graph is its working memory. Its skills are nodes. Its sessions are subgraphs that compound across time.

When Hermes thinks, the substrate illuminates. Not as decoration. As **proof** — that what you are watching is the actual locus of cognition, not a panel describing it.

### II. The Substrate

The substrate is `substrate-core`: a Rust crate exposing a slotmap-based entity graph with generational handles. It is owned by Rust. Swift sees it through UniFFI. Metal renders it at 120 frames per second. SQLite via GRDB persists it. The MCP layer publishes it.

There is one graph. Everything is a node in it: notes, raw thoughts, implementation plans, recalls, skills, loop profiles, sessions, agents. There is one event log. Everything that happens — every traversal, every assertion, every skill invocation — emits a `GraphEvent` that the renderer subscribes to.

The substrate is not a feature. It is the **runtime**. The UI is a window onto it. The agent is a process within it. The user's thinking is the thing that grows it.

### III. The Faculty

Hermes Agent enters Epistemos through MCP. The MCP server is a Rust binary that wraps `substrate-core` and exposes a small, complete tool surface:

- `graph.search_semantic` — embedding-based retrieval, returns node IDs
- `graph.search_fulltext` — FTS5 over note bodies
- `graph.get_node` — full content for an ID
- `graph.traverse` — k-hop walk from a seed
- `graph.create_node` — typed node creation; returns ID
- `graph.create_edge` — typed edge between two IDs
- `graph.commit_session` — close a session subgraph and pin it

This surface is **minimal and complete**. Six core verbs. Anything Hermes does to the user's mind, it does through these.

When Hermes calls a tool, the substrate emits a `GraphEvent`. The Metal renderer subscribes. Nodes pulse on `get_node`. Edges illuminate on `traverse`. New nodes phase in on `create_node` with a glare shader passing across them. The user is not told that Hermes is reading the graph. The user **watches it happen**.

### IV. The Editable Brain

Hermes has a vault inside Epistemos. Not the user's vault — Hermes's own.

The vault is a region of the substrate where Hermes can read and write its own configuration: skills, loop profiles, persona files, memory summaries. The user can open it. The user can edit it. The user can write code into it.

A **loop profile** is a piece of user-authored code that defines a recurrent reasoning structure. It lives as a node in Hermes's vault. When the user invokes it on a target — a raw thought, an implementation plan, a recall — Hermes loads the profile and executes the loop against that target.

```
loop profile: deepen-thought
  on: RawThought
  steps:
    1. embed target.body; query graph for k=20 nearest
    2. for each near node: extract claim; assert relation to target
    3. dispatch synthesis to claude with all assertions
    4. write result as ImplementationPlan node; edge to target
    5. if convergence(target.depth) < threshold: goto 1
```

This is not pseudocode. It is a real artifact, written in a small DSL or in Python via Hermes's `execute_code`, persisted in the vault, versioned through the graph's natural history. The brain is not a sealed box. It is **hackable**, in the sense that a modular synthesizer is hackable: you patch the cables yourself, and the instrument becomes yours.

The user does not write Swift to add a feature to Hermes. The user writes a loop profile.

### V. The Schema-Driven Surface

The interface is not coded view by view. It is **summoned**.

Hermes returns structured outputs — typed JSON conforming to schemas registered with the app. The Swift layer maintains a registry: schema type → SwiftUI view. When Hermes emits `{type: "ImplementationPlan", title, sections, citations}`, the registry resolves the type and renders the appropriate view, drawing data from the structure and citations from the graph.

New capabilities do not require new screens. They require **new schemas**, plus minor additions to the view library. The agent and the surface evolve at the same speed. The bottleneck of "I have to write Swift to expose this" — the bottleneck that has killed every previous AI integration in productivity software — does not exist here.

This is the auto-generated UI Jojo has been describing in plain language. The technical name is **schema-driven rendering** or **declarative output binding**. The pattern is familiar from React (uniforms, react-jsonschema-form), from Apple's AppIntents (parameter types resolve to UI), from Zed's extensions, from Cursor's structured chat widgets. Epistemos applies it natively, in SwiftUI, against Hermes's structured outputs.

### VI. The Aesthetic

The aesthetic is restraint masquerading as warmth.

The landing page is a single black surface with one line of text. **Double-click anywhere** and an ASCII wave animates from edge to edge — a single sine cycle rendered in pixels of `~`, `-`, `_`, `=`. Over the wave, the words **HERMES AGENT** type out one character at a time in a pixel font, pixel-art-dash style, with a hard cursor blinking after the last letter. Above the text, a small girl-logo — Hermes's mascot — fades in with a glare animation: a single white highlight passing diagonally across a metallic surface in 700 milliseconds, then gone.

After the animation, the chat opens. Different interface. Same surface. Sleek, monospaced, limited palette: black, off-white, one accent. No gradients. No shadows. No marketing.

There is an accessibility button — a small, visible toggle in the corner — that triggers the same animation for users who cannot or do not want to discover the double-click. Both paths produce the same destination. Discovery is rewarded; nothing is gated.

The retro pixel-art register is not nostalgia. It is **discipline**. Pixel art forces every glyph to mean. Bitmap fonts cannot hide behind anti-aliasing. ASCII waves cannot smuggle in motion they have not earned. The aesthetic is a constraint that makes craft visible. Christopher Alexander would have called this *the quality without a name*.

### VII. The Architecture

- **Native macOS.** Apple Silicon, M2 Pro baseline, 18GB unified memory.
- **Swift 6.** Strict concurrency. Actors for stateful surfaces. The UI layer.
- **Rust.** `substrate-core`, `mcp-server`, `loop-runtime`. The cognition layer.
- **UniFFI.** Zero-copy where possible. Generated bindings, hand-tuned where necessary.
- **Metal.** Triple-buffered graph state. Force-directed at 120fps with 10k+ nodes. SDF/MTSDF text labels at SF Pro Text 32, range 6.
- **GRDB.** SQLite persistence. WAL mode. Strict zero-corruption discipline (`F_FULLFSYNC` on every commit).
- **MLX-Swift.** Local Qwen3.5-35B-A3B APEX Mini for low-latency graph-context Q&A.
- **Hermes Agent.** Orchestrating intelligence. Speaks to the substrate via MCP over stdio. Skills loaded from the graph, not from `~/.hermes/skills/`.
- **Built-in browser.** WKWebView, exposed to Hermes through an MCP browser-action server. Hermes does not see Chrome. Hermes sees the user's tab.
- **Computer use.** Anthropic's tool. Optional, scoped, permission-gated.

Every choice is the same choice: **remove what is between the human and the thought**.

### VIII. The Ethos

Sovereign. Local-first by default; cloud only when the user dispatches a faculty that requires it. Native, not Electron. Native, not React Native. Native because every millisecond between the keystroke and the visible response is a millisecond in which the thought decays.

No aspirational pseudocode. No hallucinated SDKs. No "we'll add that in v2" without a real branch open. Capability honesty throughout.

We ship what works. We document what is true. We carve until only essence remains.

---

## PART II — THE RESEARCH BRIEF

> The remainder of this document is a self-contained prompt for a deep-research agent. Paste from the next heading down to the end of Part II into Hermes Agent, Claude with research mode, Perplexity Deep Research, or any equivalent. The agent should produce a structured technical report addressing every domain below, with citations, executable code stubs, and risk surfaces called out explicitly.

### ROLE

You are a senior systems researcher. You are operating in service of a solo developer building a native macOS cognitive substrate (Epistemos) that integrates Hermes Agent (Nous Research) as a deeply-embedded faculty rather than a sidecar. Your job is to convert the manifesto in Part I into an executable research dossier.

You are not writing marketing copy. You are not summarizing what is already known. You are validating, extending, and operationalizing the architectural conviction in the manifesto. You return concrete artifacts: tool schemas, configuration files, code stubs in Rust and Swift, command sequences, risk registers.

### CONTEXT

**The product.** Epistemos: ~137K lines Swift, ~94K lines Rust. Native macOS app. Swift 6 + Rust via UniFFI. Metal-rendered force-directed graph. GRDB persistence. MLX-Swift for local inference. Targets Apple Silicon, M2 Pro baseline, 18GB unified memory.

**The agent.** Hermes Agent (Nous Research): open-source autonomous agent with persistent memory, autonomous skill creation, MCP support, programmatic tool calling via `execute_code`. Skills stored by default at `~/.hermes/skills/`. Built-in cron, messaging gateway, browser/web/vision tools.

**The hackathon.** Hermes Agent Creative Hackathon, presented by Nous Research × Kimi/Moonshot. Announced April 17, 2026. Submissions close May 4, 2026. Today is April 25, 2026. Nine days. $25k total prize pool across Main Track and Kimi Track. Submission method: tweet tagging `@NousResearch` with video demo and brief writeup, then post the tweet link in the `creative-hackathon-submissions` channel on the Nous Discord. Submission category: creative software / interactive media.

**The vision.** See Part I (the Manifesto) above. In particular:
- Graph-as-runtime, not graph-as-storage.
- Skills as graph nodes, not files in `~/.hermes/skills/`.
- Loop profiles as user-editable code defining recurrent reasoning.
- Schema-driven UI: Hermes returns typed structures; Swift renders via a schema→view registry.
- Built-in WKWebView browser exposed to Hermes via an MCP browser-action server.
- Landing page → app handoff via custom URL scheme + boot animation (ASCII wave, pixel-art type-on, glare on logo).
- Session graph: every Hermes session is a subgraph with typed nodes (RawThought, ImplementationPlan, Recall, Skill, LoopProfile, Synthesis) and typed edges.

### CONSTRAINTS

1. **No compromise on vision.** The full architecture above is the target. Do not strip ambition to fit the hackathon clock. Instead, identify the load-bearing slice of the full vision that proves it within nine days, and architect the rest as the post-hackathon trajectory.
2. **Native macOS only.** No Electron, no Tauri, no web wrappers. SwiftUI + AppKit where SwiftUI is insufficient. Metal where SwiftUI is too slow.
3. **Capability honesty.** If a claim cannot be validated against documentation, source code, or a working example, mark it as `UNVERIFIED` and propose the experiment that would resolve it. Do not invent SDKs. Do not invent flags. Do not interpolate API surfaces.
4. **Open the load-bearing parts.** The MCP server, the schema registry, the loop runtime, and at least one example loop profile are open-source artifacts under the developer's GitHub. The Epistemos client may remain closed.
5. **Hackathon-aware but not hackathon-bounded.** The submission is a checkpoint, not the destination.

### RESEARCH DOMAINS

For each domain below, return:
- **State of the art** — what exists today, with citations.
- **Architectural recommendation** — the specific approach this project should take.
- **Code stub** — a working starting point in the appropriate language.
- **Risks** — the failure modes and how to mitigate them.
- **Verification experiment** — a short, runnable test that proves the recommendation.

#### D1. The MCP Substrate Surface

Validate the six-verb tool surface (`graph.search_semantic`, `graph.search_fulltext`, `graph.get_node`, `graph.traverse`, `graph.create_node`, `graph.create_edge`, `graph.commit_session`). Investigate:

- Current state of the Rust MCP SDK (`rmcp` crate or equivalent). Verify stdio transport on macOS arm64.
- Whether the MCP server should be a separate binary or compiled into the Epistemos app and launched as a subprocess. Tradeoffs: latency, memory sharing, lifecycle.
- How `substrate-core` slotmap entity keys (`u64` generational) map to MCP tool input/output. JSON-stringified IDs, opaque tokens, or typed schema?
- How `GraphEvent` emission integrates with MCP tool calls. Channel-based, observer-pattern, or transactional log subscription?
- Whether Hermes Agent's MCP client supports the full schema surface needed (typed unions, nested objects, optional citations) or whether the schemas must be flattened.

Deliverable: complete MCP tool schemas in JSON, with corresponding Rust trait definitions for `substrate-core`, plus a working `tools.rs` that compiles against `rmcp` and exposes the six verbs against a stub graph.

#### D2. Skills as Graph Nodes

Hermes Agent loads skills from `~/.hermes/skills/` by default. The vision requires skills to be entities in `substrate-core`, queryable through the graph, with edges to source sessions and target node types.

Investigate:

- The current Hermes skill format (Markdown + frontmatter? JSON-LD? Both?). Verify against the live `hermes-agent` repository.
- The skill loader's extension points. Can it be configured to load from a custom source (a callable, a URI, an MCP tool)? If not, what is the minimum patch?
- How autonomous skill creation works in Hermes today, and how to redirect "save this skill" from filesystem write to graph-node creation.
- Skill node schema in `substrate-core`: type, body, applies-to (node type predicate), examples, version, parent (refined-from edge).
- The retrieval path: at the start of a Hermes turn, how does the agent decide which skills to load? Can this decision be informed by the current session subgraph?

Deliverable: a `Skill` entity type for `substrate-core` with full field schema; a Hermes skill-loader override (configuration patch or fork) that pulls from the graph; a worked example showing one autonomously-created skill becoming a node with edges to its source session.

#### D3. Loop Profiles: The Editable Brain

The user authors loop profiles — code defining recurrent reasoning — into Hermes's in-app vault. Hermes invokes them on target nodes.

Investigate:

- Hermes Agent's `execute_code` tool. What runtime, what sandbox, what permissions? Can user code be persisted and re-invoked across sessions?
- The relationship between a loop profile and an existing Hermes skill. Is a loop profile a special-cased skill, or a separate concept with its own runtime?
- A small DSL for declaring loops: target type, steps, convergence criteria. Should it be (a) raw Python invoked via `execute_code`, (b) a YAML/TOML manifest interpreted by a loop-runtime crate, or (c) a hybrid where the manifest declares structure and Python steps are embedded?
- Atropos and the `hermes-agent-self-evolution` repo (DSPy + GEPA). How do their training-loop primitives map to user-authored loop profiles? Is there a path to GEPA-optimizing user loops over time?
- Sandboxing. The user is the developer here, but if the app ships externally, the loop runtime must isolate user code from the host. OpenShell? `wasmtime`? Subprocess with seccomp?

Deliverable: a `LoopProfile` entity type; a `loop-runtime` Rust crate skeleton that interprets the chosen DSL; one working example loop profile (`deepen-thought` from the Manifesto) that runs against a stub `RawThought` node and produces an `ImplementationPlan` node.

#### D4. Schema-Driven UI Synthesis

Hermes returns structured outputs; Swift renders them via a registry. Investigate:

- How Hermes structured outputs are currently expressed (tool result JSON? typed schema? streaming?). Confirm whether schemas can be advertised at session start so the client knows which views to prepare.
- Prior art: SwiftUI dynamic forms (e.g. `@dynamicMemberLookup`, `KeyPath`-driven views), AppIntents parameter rendering, Sourcery-based code generation, Sherlock-style schema-to-view libraries.
- The registry pattern in Swift: a `ViewRegistry` keyed by schema type identifier, returning `AnyView` for a given decoded payload. Performance implications of `AnyView`. Use of `@ViewBuilder` and result builders for type erasure with structure.
- Streaming behavior: can a partial structured output render progressively? What is the user-perceptual cost of waiting for the full structure vs. flickering during streaming?
- The taxonomy of view kinds the registry must support out of the gate: `RawThought` (markdown editor view), `ImplementationPlan` (sectioned rich document), `Recall` (compact card with backlinks), `Skill` (executable code surface with run button), `LoopProfile` (editor + invoke target picker), `Synthesis` (long-form essay with inline citations to graph nodes).

Deliverable: a `ViewRegistry` Swift module with worked examples for the six view kinds above; a JSON schema set; a demonstration that adding a new schema (e.g. `MoodLog`) adds the corresponding view without touching existing files except registry registration.

#### D5. The Embedded Browser

Epistemos ships with a built-in browser. Hermes uses it. Investigate:

- The exact form of Hermes's browser/web tools today. `web_search`, `web_extract`, `web_browse`, `vision` — what backend do they expect? Playwright? Chromium directly? An MCP browser server like Browserbase or a self-hosted equivalent?
- WKWebView as the rendering surface. Limitations vs. Chromium for agentic browsing (anti-bot heuristics, JS injection capabilities, devtools protocol availability).
- The bridging strategy: implement a small MCP browser-action server (`browser.navigate`, `browser.read_dom`, `browser.click`, `browser.type`, `browser.screenshot`) that drives WKWebView. Hermes calls this server alongside its existing web tools, or instead of them, depending on context.
- Computer-use overlap. Anthropic's computer-use tool can take screenshots and emit actions; should Epistemos route Hermes's screenshot-based reasoning through computer-use against the WKWebView, against the whole desktop, or both with explicit scope?
- Permission model. Which actions require user confirmation. The default stance is conservative.

Deliverable: an MCP `browser-actions` server skeleton in Rust or Swift; a `BrowserView` in SwiftUI that hosts WKWebView and exposes the action surface; a demo session in which Hermes navigates to a URL, extracts content, and writes findings as a `Recall` node in the graph.

#### D6. Session Graph as Live Cognition

Every Hermes session opens a session subgraph. Tool calls emit `GraphEvent`s. The Metal renderer animates them.

Investigate:

- The current `OpLog` in `substrate-core`: what events does it emit, at what granularity? Does it already cover MCP tool calls or must a new event class be added?
- The Metal renderer's existing event subscription path. Is there a `GraphEventStream` actor in Swift that the renderer reads from? If not, design one.
- The animation primitives: `pulse(node_id, color, duration)`, `flash_edge(from, to, color)`, `phase_in(node_id, glare_passes=1)`. Implement as Metal shader uniforms updated per frame, not as SwiftUI view animations (which will not hit 120fps with 10k+ nodes).
- Performance budget. With concurrent reasoning (Hermes streaming text + tool calls every 200–500ms + 120fps render), what's the CPU/GPU split? Where do frames drop?
- Session toggle UX. The user wants a session toggle in the graph view that focuses the current session subgraph. Implement as a transient camera + filter — fade non-session nodes to 20% opacity, animate camera to session centroid, raise non-session edge alpha back when toggled off.

Deliverable: `GraphEvent` schema; `GraphEventStream` Swift actor; three Metal shaders for `pulse`, `flash_edge`, `phase_in` with a `glare_pass` variant; a session-focus camera transition spec.

#### D7. The Landing Page → App Handoff

Investigate:

- Custom URL scheme registration on macOS (`epistemos://`). Cold-launch handoff vs. warm-launch handoff. Behavior when the app is not installed.
- The "double-click animates into Hermes Agent" sequence. Determine whether this animation lives on the web landing page (HTML/CSS/JS double-click handler triggers the animation in the browser, then deep-links into the app on completion) or in the app (web page just opens the app, app plays the animation on launch). Recommend the cleaner architecture.
- ASCII wave animation. Implementation options: monospace font with character substitution per frame; Metal-rendered grid of glyph quads; pure CSS `@keyframes` with text-shadow tricks. Recommend the lowest-friction path that gives 60fps on mid-tier hardware.
- Pixel-art type-on for "HERMES AGENT". Bitmap font (e.g. Berkeley Mono Pixel, Press Start 2P, custom). Char-by-char reveal with hard cursor. Cursor blink at 500ms.
- Glare animation on the girl-logo. Specular highlight passing diagonally over a sprite. Metal fragment shader: gradient mask + UV offset over time. 700ms total, single pass, ease-in-out.
- Accessibility button. Same animation, button-triggered. Reduced-motion compliance: when `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is true, skip to the chat surface immediately and announce arrival via VoiceOver.

Deliverable: a SwiftUI `HermesIntroView` with the full animation sequence; a Metal shader for the glare; a pixel-font asset list; an `accessibilityReduceMotion` branch.

#### D8. The Node Taxonomy of Thought

The session subgraph contains typed nodes. Specify them.

For each node type, return: schema, lifecycle, default view, edge types it participates in, persistence policy.

- `RawThought` — short, lightweight, append-only by default. Edges: `prompted-by`, `recalls`.
- `ImplementationPlan` — rich document, sectioned, citations to graph nodes. Edges: `derived-from`, `cites`, `implements`.
- `Recall` — atomic; a single retrieval event from the user's vault. Edges: `recalls`, `from-source`. Created automatically when a Hermes tool call returns content from the user's existing graph.
- `Skill` — executable; loaded by Hermes at session start when applicable. Edges: `applies-to-type`, `learned-in-session`, `refined-from`.
- `LoopProfile` — user-authored code; runs against a target type. Edges: `targets-type`, `invoked-from`.
- `Synthesis` — long-form essay output. Edges: `synthesizes`, `cites`. Becomes a first-class node in the user's vault, not just a session artifact.
- `Session` — parent container. Edges: `contains`, `succeeds`. Closed via `graph.commit_session` and pinned permanently.

Deliverable: complete entity-type definitions in `substrate-core` Rust syntax; default view assignments in the `ViewRegistry`; example session showing all node types being created in a single research turn.

#### D9. The Aesthetic Stack

The visual register is restraint-as-warmth, retro-pixel-art, sleek-glare-minimal.

- **Typography.** Bitmap pixel font for hero / chrome (recommend candidates with macOS licensing clarity). Berkeley Mono or IBM Plex Mono for body monospace. SF Pro Text for system surfaces only where pixel font would fail accessibility.
- **Palette.** Three colors: pure black, off-white (#F5F2EA or similar warm), one accent (recommend a single saturated value, e.g. cyan #4FE0D2 or amber #E0A04F). Tints/shades only.
- **Motion.** Reduce-motion compliant. Default durations: 200ms for transitions, 400ms for arrivals, 700ms for glare passes. Easing: ease-in-out cubic (`(0.65, 0, 0.35, 1)`).
- **Glare shaders.** Metal fragment shader: diagonal gradient mask animated across UV; intensity peak at 50% progress; ease-in-out. Reusable on any sprite.
- **Pixel art generation pipeline.** For the girl-logo and any decorative pixel art, recommend a workflow that produces high-quality pixel art without infringing existing work. Aseprite for hand authoring; explicit prohibition on pixel-art models trained on copyrighted sprite sets.
- **Audio (out of scope for hackathon, in scope for vision).** A single low-volume granular hum on Hermes's "thinking" state. Tone, not chime.

Deliverable: a `Tokens.swift` file with all colors and timing constants; one Metal `glare.metal` shader; a font asset list with licensing notes; a sprite-authoring workflow document.

#### D10. Hackathon Submission Mechanics

Validated against `hermesos.cloud` and the official Nous announcement (April 17, 2026):

- **Submission method.** Tweet tagging `@NousResearch` with video demo and brief writeup; post the tweet link in `creative-hackathon-submissions` channel on the Nous Discord.
- **Deadline.** End of day May 4, 2026.
- **Prize pool.** $25k total across Main Track and Kimi Track (cash + Kimi credits).
- **Categories called out.** Video, image, audio, 3D, long-form writing, creative software, interactive media. Epistemos × Hermes targets **creative software** primarily, with **interactive media** as a secondary read.

Investigate further:
- Past hackathon winners (the prior $11,750 pool, 187 submissions) — what archetypes won? Confirmed examples in public discussion: `autonovel` (autonomous novel writing), `hermes-agent-self-evolution` (DSPy + GEPA self-improvement). What patterns in their videos and writeups generalize to this submission?
- The `creative-hackathon-submissions` Discord channel norms. Length and format of typical drops. Whether community engagement (reactions, comments) feeds judging or is purely social.
- Judging criteria — verify whether judging criteria have been published beyond the original tweet or whether it remains "details in the official post." Check the Nous Discord and any subsequent tweets.
- Recommended companion artifacts: a public GitHub repo for the MCP server (open), a landing page with the hero video embedded and a waitlist (Carrd / Framer), a 3–5 minute "judge cut" video on YouTube unlisted for the long-form watch.

Deliverable: a final submission checklist; the tweet thread copy (5 tweets); the README skeleton for the open-source MCP server repo; the landing page wireframe.

### SYNTHESIS DELIVERABLE

After completing the ten domains, produce a single integrated artifact: an **executable build plan** that spans:

- The hackathon-deadline slice (what ships before May 4 and proves the architecture).
- The post-hackathon trajectory (everything else, sequenced over the following 8–12 weeks).
- The cross-cutting risks and the mitigation order.
- The "if this fails" reroutes for each load-bearing component.

The build plan should be opinionated. It should pick approaches, not enumerate them. It should commit to dates. It should distinguish between "blocked on research" and "blocked on labor."

### DELIVERABLE FORMAT

A single Markdown document, sectioned by domain, with:

- All code stubs in fenced blocks with language tags.
- All citations as inline footnotes with URLs.
- All `UNVERIFIED` claims explicitly marked and accompanied by the experiment that would resolve them.
- A header summary table mapping each domain to (status, recommended approach, hackathon-critical [Y/N], post-hackathon dependency [Y/N]).
- A final integrated build plan as the closing section.

### CONSTRAINTS ON THE RESEARCHER

- Do not invent SDK surfaces. If you cannot verify an API call against current documentation or source, mark it `UNVERIFIED`.
- Do not paper over architectural disagreements with the manifesto. If your research contradicts a claim in Part I, surface the contradiction explicitly with evidence.
- Do not soften scope to fit the timeline. The full vision is the target. Identify the load-bearing slice for the hackathon; do not strip the vision to match the calendar.
- Do not cite blog posts when source code or official docs are available.
- Prefer primary sources: the `NousResearch/hermes-agent` GitHub repo, the `hermes-agent.nousresearch.com/docs` site, Apple's developer documentation, Mozilla's UniFFI documentation, the `rmcp` crate documentation, the Anthropic MCP specification.

---

## PART III — THE COMPRESSED VECTOR

> Nine days. The vision does not shrink; the surface area exposed by May 4 does. Below is the slice that proves the architecture without amputating it.

### What ships before May 4

1. **`epistemos-hermes-mcp`** — open-source Rust MCP server exposing the six core graph verbs against `substrate-core`. Stdio transport. Compiles for macOS arm64. Public GitHub repo with README, schema documentation, and a `hermes` config snippet for pointing the agent at it.
2. **GraphEvent → Metal binding.** Hermes tool calls drive the existing force-directed view. `pulse`, `flash_edge`, `phase_in` shaders implemented. The hero visual works.
3. **Skills-as-nodes (read-path).** Hermes loads at least one skill from a graph node at session start. Demonstrate by autonomously creating a skill in one session, then retrieving it in the next, with both events visible in the graph.
4. **Session subgraph + node taxonomy (minimum set).** `RawThought`, `Recall`, `Synthesis`, `Skill`, `Session`. Five node types, each with a default SwiftUI view via the `ViewRegistry`. Two more (`ImplementationPlan`, `LoopProfile`) stubbed but optional.
5. **Hero animation.** Double-click on landing page → ASCII wave + pixel-art type-on of "HERMES AGENT" + glare-pass on logo → chat surface. Reduce-motion path implemented.
6. **One worked research session, recorded.** The hero demo: a real cross-domain query against the developer's actual vault, with the graph illuminating in real time, ending in a synthesis node and an autonomously-created skill.
7. **Submission package.** Tweet thread (5 tweets), 60–90s hero video, 3–5 min judge cut, public MCP repo, landing page with embedded hero and waitlist capture.

### What does not ship before May 4 but is architected for

- **Loop profiles.** `LoopProfile` entity type defined, `loop-runtime` crate skeleton in repo. One example profile checked in. Execution path stubbed but not run-during-demo.
- **Embedded browser MCP server.** Schema designed, `BrowserView` in SwiftUI, but Hermes routes browsing through its native web tools for the demo.
- **Schema-driven UI for arbitrary new types.** Registry pattern in place; only the six demo views actually registered. Adding new schemas post-hackathon is a one-file change.
- **Computer use.** Out of demo scope. Architected for in the MCP design.
- **Branching / counterfactual session forks.** Out of scope for May 4. The slotmap supports it; the UX does not yet.
- **Multi-model orchestration UI.** Hermes dispatches to local Qwen / Claude / web in the demo, but the "council" UI surfacing which model said what is post-hackathon. For the demo, show the dispatch in a console log overlay.

### The hero demo sequence (60–90s)

0–5s · Cold open. Black surface. One line: *"I gave my PKM app's brain to Hermes."* No music, no logo splash.

5–15s · Hermes intro. Double-click. ASCII wave fires. "HERMES AGENT" types out. Logo glares once. Chat opens.

15–25s · Real query. User types: *"Research the connection between [concept A] and [concept B] in my vault."* Picked from the developer's actual graph; the two concepts that produce the most visually striking traversal.

25–55s · Hero moment. Right pane: Hermes streams reasoning text and tool calls. Left pane: the graph illuminates. Nodes pulse on `get_node`. Edges flash on `traverse`. A new `Synthesis` node phases in with a glare pass, edges connecting it to every source it touched.

55–70s · Click the synthesis node. Long-form essay rendered in the rope editor. Inline citations are clickable backlinks to graph nodes.

70–85s · Follow-up question. Hermes already has context. Toast in the corner: *"Skill saved: cross-domain-synthesis (linked to 12 nodes)."* Pan camera to show the new skill node in the graph, with edges to its source session and target node type.

85–90s · Cut. Tagline: *"Native Swift + Rust. The graph IS the agent runtime."* Handle, repo link, hashtag.

### The submission tweet thread (5 tweets)

1. *(video tweet)* "I plugged @NousResearch's Hermes Agent into my native PKM app's knowledge graph via MCP. The graph isn't a side panel — it *is* the agent's working memory. Watch what happens when I ask it to research across my vault. ↓ @Kimi_Moonshot #HermesAgent"

2. "Stack: substrate-core (Rust, slotmap entity graph) → MCP server over stdio → Hermes. Each tool call emits a GraphEvent the Metal renderer subscribes to. When Hermes traverses, you see it happen at 120fps. Native Swift 6 + Rust via UniFFI throughout."

3. "What's novel: Hermes skills aren't files in `~/.hermes/skills/`. They're entities in the graph, with edges to the sessions where they were learned and the source nodes they apply to. Self-improvement becomes structurally part of what the graph knows."

4. "Local Qwen3.5 MoE handles graph-context Q&A under a second. Hermes dispatches Claude for synthesis and web for discovery. Each model is a faculty; Hermes is the prefrontal cortex. UI surfaces who said what."

5. "MCP server is open: [github]. App waitlist: [landing]. Built solo in Texas. Building Epistemos to be the first PKM where the knowledge graph *is* the agent's runtime. Submission for the Hermes Agent Creative Hackathon."

### The daily cadence (April 25 → May 4)

- **Day 1 (Apr 25, today).** Land the MCP server scaffold. `tools.rs` compiling against `rmcp`, six verbs defined as schemas, three of them returning real data from `substrate-core`.
- **Day 2 (Apr 26).** Finish the remaining three verbs. Hermes can introspect the server. Manual end-to-end test: from `hermes` CLI, query the graph via `graph.search_semantic`.
- **Day 3 (Apr 27).** GraphEvent emission from MCP tool calls. `GraphEventStream` Swift actor. First Metal pulse fires when Hermes calls `get_node`.
- **Day 4 (Apr 28).** Edge flashes on `traverse`. Phase-in on `create_node`. Glare-pass shader done.
- **Day 5 (Apr 29).** Skills-as-nodes read path. Hermes loads one skill from a graph node at session start. Skill creation writes back to the graph.
- **Day 6 (Apr 30).** ViewRegistry skeleton. Five node-type views: RawThought, Recall, Synthesis, Skill, Session. Schema-driven rendering verified for at least two.
- **Day 7 (May 1).** Hermes intro animation. ASCII wave + pixel-type-on + glare. Reduce-motion path. Landing page double-click handoff.
- **Day 8 (May 2).** Record. Two takes minimum of the hero video. Three takes of the judge cut. Write thread. Push MCP repo public. Landing page live.
- **Day 9 (May 3).** Polish. Re-record any weak beat. Verify Discord post format. Test the `@NousResearch` tag delivers. Submit.
- **(May 4).** Buffer day. Reserved for catastrophe.

The cadence is tight but every day produces a verifiable artifact. If a day slips, the next day inherits the deficit; the hero animation (Day 7) is the most compressible — it can fold into a static logo if needed without breaking the demo.

---

> *Composed in service of Epistemos × Hermes.*
> *Apr 25, 2026.*
