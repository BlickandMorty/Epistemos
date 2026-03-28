# Epistemos — Competitive Position & Cloud LLM Transformation
**Date:** 2026-03-28
**Audience:** Owner reference. Not a marketing doc — this is a raw technical honest assessment.

---

## The Real Comparison Frame

Obsidian and Notion are not the same product. Notion is a collaborative workspace tool. Obsidian is a local markdown vault with a plugin ecosystem. Neither is what Epistemos is trying to be. But they are the two names a user will say when they are trying to describe what Epistemos does, so the comparison has to be answered head-on.

The frame that matters is not "features" — it is **what the app can do for you that only this app can do**, rooted in architecture that competitors cannot replicate without rebuilding from scratch.

---

## Obsidian

### What Obsidian actually is

A local markdown editor with a community plugin marketplace. The core app is an Electron shell around CodeMirror 6. The graph view is a D3.js force-directed simulation. Sync is a paid cloud service. Every AI capability is a third-party plugin calling external APIs.

### What it does well

- Interoperability. Plain `.md` files, no lock-in.
- Plugin breadth. 1,200+ community plugins.
- Customizability. CSS snippets, Dataview queries, Templater.
- It's been around since 2020. Battle-tested vault compatibility.

### Where it stops

**The graph is decoration.** D3.js in a browser container. No physics engine. No Rust. No per-frame allocation budget. It cannot run real physics because it cannot hit 60fps in an Electron sandbox without melting the CPU. Epistemos runs a compiled Rust physics engine with Metal rendering — the graph is a real-time simulation, not a static layout.

**AI is bolted on, not built in.** The "Smart Second Brain" plugin and every other AI plugin routes to an external API with your vault contents in the prompt. The plugin does not know about your graph topology, your backlink density, your cluster structure, or your writing patterns. It gets text. Epistemos AI gets the graph.

**No local inference.** Obsidian cannot run a model on your device because it is an Electron app in a renderer process. There is no path to MLX, Metal, or on-device inference from inside a Chromium sandbox.

**No computer use.** No accessibility API access, no Apple Events, no Terminal integration. Cannot automate macOS on your behalf.

**The editor is CodeMirror.** A web text editor. It is good. It is not NSTextView backed by `NSTextLayoutManager` with full TextKit 2. Obsidian cannot do what ProseTextView2 does — inline AI response with divider protection, streaming text insertion into NSTextStorage with undo support, wikilink rendering in the native text stack.

---

## Notion

### What Notion actually is

A block-based collaborative workspace. Cloud-first, team-oriented. The document model is a tree of blocks, not free prose. It is optimized for structured data: tables, databases, Kanban boards, project management.

### What it does well

- Real-time collaboration.
- Relational databases inside documents (filtered views, rollup properties).
- Templates and sharing across teams.
- Notion AI: GPT-4 integration, context-aware within a page.

### Where it stops

**Notion is not a notes app for thinking.** It is a structured data tool that handles prose as a block type. Freeform nonlinear thinking — the kind where you write a note and discover later that it is connected to three other notes you wrote six months ago — is not what Notion is designed for.

**No local storage, no local inference.** Everything is in the cloud. If Notion's servers are down, you have nothing. If you are on a plane, you have a read-only cache at best. Notion AI requires an internet connection and costs extra.

**No graph.** Notion has no knowledge graph. There is no way to visualize the topology of your thinking. Backlinks exist in a limited form but there is no graph-based discovery.

**No privacy guarantee.** Everything you write goes to Notion's servers. Their AI has access to your workspace data for feature improvement unless you opt out. Epistemos runs 100% on your device by default. Nothing leaves the machine unless you explicitly choose cloud routing.

---

## Where Epistemos Is Different — What Competitors Cannot Replicate

### 1. The graph is a real data structure, not a visual

The graph in Epistemos is a Rust-backed Int-indexed adjacency list with a trigram search index and an HNSW vector index. It supports O(1) adjacency lookup, semantic clustering, quote extraction, wikilink parsing, and live FFI updates from the Swift layer. The Metal renderer runs real physics.

Obsidian's graph is a D3 layout. You cannot build an agent that navigates Obsidian's graph programmatically. You can build one that navigates Epistemos's graph — `AgentGraphMemory` already does.

### 2. AI is part of the document, not adjacent to it

The AI response in the note editor streams directly into `NSTextStorage` below a divider, using the same undo stack as normal typing. Accept keeps it inline. Discard removes it atomically. The model sees your actual note text as context, not a copy of it. There is no modal dialog, no sidebar panel, no context switch.

This is architecturally impossible in Obsidian without replacing CodeMirror. It is not relevant to Notion's document model.

### 3. Local inference with 11 models, zero subscription

Qwen 3.5 in 0.8B through 35B-A3B, Devstral, Mistral Small 24B, Gemma 3 27B, Llama 4 Scout 17B. Fast/Thinking/Agent modes per model. All run on the M-series chip via MLX. No API key. No monthly fee. No data leaving the machine.

The routing layer (`TriageService`) picks Apple Intelligence for light operations, local MLX for everything else, and cloud only when the user explicitly selects a cloud model. The decision is transparent: the inference source badge is always visible.

### 4. Computer use: Omega agents

5 agents, 26 tools. Safari web search and page extraction. AX tree walking for screen understanding. Terminal command execution. File system access. Note creation and citation saving. All wired to a `ResearchOrchestrator` that tracks source confidence, detects contradictions, and asks the user before escalating.

No notes app has this. Obsidian plugins can open a browser. Epistemos can navigate it.

### 5. Knowledge Fusion: the model learns your vault

`QLoRATrainer` trains LoRA adapters on your vault contents via a Python subprocess communicating over stdin/stdout JSON. `MoLoRARouter` hot-swaps adapters per-token without fusing them into the base model (fusing collapses throughput from ~21 tok/s to ~7 tok/s on MLX). `AdapterRegistry` tracks adapters per base model with quality scores and atomic writes.

Obsidian has no training pipeline. Notion has no training pipeline. No consumer notes app trains on your data locally.

### 6. Privacy is the default, not a paid tier

The default state of Epistemos: everything local, no network calls for inference, no vault data transmitted, no analytics. Cloud is opt-in per model selection. This is not a marketing positioning — it is the architecture. There is no code path that sends your notes anywhere without an explicit user action.

---

## How Cloud LLM Transforms Epistemos Further

The routing layer for cloud inference is already built. `TriageService` has a `cloudLLMService: (any LLMClientProtocol)?` parameter. `selectedCloudModel()` returns non-nil when the user has a cloud model selected. The decision tree is: cloud model selected → route to cloud, no cloud model → route to Apple Intelligence or local MLX.

What this means in practice, once cloud models are properly wired:

### Context windows that dwarf local models

Qwen 3.5 4B at full context is approximately 32K tokens. Claude 3.7 Sonnet supports 200K tokens. Llama 4 Scout supports 10M tokens (via API). For research tasks that need to synthesize an entire vault, or for note sessions that have been running for hours, local context runs out. Cloud does not.

Epistemos's graph context can be serialized as a structured summary and injected into the cloud prompt. Your vault topology goes with you to the cloud model. Obsidian's AI plugins send raw text. Epistemos can send structured graph data — which nodes are connected, how densely, what the semantic clusters are — so the cloud model understands your knowledge structure, not just your words.

### Frontier reasoning for Omega research

The `ResearchOrchestrator` currently plans tasks using whatever local model is selected (Qwen 3.5 4B for most users). Planning quality is directly proportional to model capability. With a cloud frontier model (Claude Opus 4.6, GPT-4o, Gemini 2.5 Pro) doing the planning pass, Omega research tasks become qualitatively different — multi-step plans with genuine decomposition, not just keyword search sequences.

The tool architecture does not change. The same 26 tools execute the same way. The intelligence of the plan they are executing from goes up dramatically.

### Vision for note images

`NoteImageProcessor` exists. `Screen2AXService` exists with a placeholder for VLM integration. A cloud vision-capable model (Claude, GPT-4o, Gemini) can read images in your notes and reason about them. Local MLX models on most M-series chips cannot do this at production quality today.

### The hybrid model: why this is unique

Most apps are either cloud-only or local-only. Epistemos is neither. The routing layer makes the choice per-operation based on what the user configured:

- Write a quick note → Apple Intelligence (instant, private, free)
- Ask a complex question in the note editor → local Qwen (private, no cost, 2-5 seconds)
- Run a deep research task with 50 sources → cloud frontier model (user's choice, billed to their own API key)

The user owns the API key. Epistemos does not take a cut of inference costs. There is no "Epistemos Pro" tier gating cloud features. You bring your Anthropic or OpenAI key, the routing layer uses it, and every dollar goes to the model provider.

This is the position no competitor occupies: **the power of frontier cloud models combined with the privacy and speed of on-device inference, in a single app, on your terms, with your data never leaving without your consent.**

---

## The Honest Gaps

**Collaboration.** Zero. Epistemos is a single-user app. This is intentional and correct for v1 but it is a real limit compared to Notion.

**Mobile.** macOS only. No iOS. Obsidian has iOS. This matters to some users.

**Plugin ecosystem.** Obsidian has 1,200+ plugins. Epistemos has none. It will never have 1,200 plugins because it is not designed for plugin breadth — it is designed for deep native capability. But the absence of third-party extensibility is real.

**Maturity.** Obsidian has been in daily use by hundreds of thousands of people since 2020. Epistemos is v1. Edge cases in the vault sync, the TextKit2 editor, and the graph will surface in production that tests did not catch.

None of these gaps touch the core architectural advantages. They are honest constraints of a v1 native app built by one person.
