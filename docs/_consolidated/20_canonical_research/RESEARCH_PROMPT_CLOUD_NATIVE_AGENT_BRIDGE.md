# Research Prompt: Cloud-Native Agent Bridge — Surgical Wins for Epistemos v1

> **Index status**: CANONICAL-RESEARCH — 2026-04-06 cloud AI surgical wins (structured output + artifact extraction + graph context + cloud-locked chat); Part 1 audit + Part 2 infrastructure extraction.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/`.



**For:** Claude Code / Deep Research / Perplexity Pro
**Date:** 2026-04-06
**Context:** Epistemos is shipping v1 as a PKM-first app with cloud AI (OpenAI, Anthropic, Google). Agents are deferred (behind ShipGate). But the agent infrastructure (Hermes, Omega, Goose research, agent_core, MCP) contains surgical wins that should be extracted and applied to the shipping cloud chat to make it feel beyond-native.

---

## Part 1: Audit What We Just Built

We added a cloud artifact pipeline in this session. Audit it against best practices and identify gaps:

### What exists now:
1. **Structured output**: `generateStructured<T>` on `CloudConfigurableLLMClient` — OpenAI uses `json_schema` response format, Anthropic uses forced `tool_use`. Returns `StructuredGenerationResult<T>` (decoded value + raw JSON).
2. **Artifact extraction**: `ArtifactExtractor.extract(from:)` scans response text for fenced code blocks + markdown tables. Returns `[Artifact]`.
3. **Artifact persistence**: `SDMessage.artifactsData: Data?` stored in SwiftData.
4. **Artifact UI**: `ArtifactBlockView` — interactive cards with copy/export, kind-specific rendering (JSON, YAML, CSV, code, table, markdown).
5. **Graph context injection**: `<knowledge_graph>` section in prompts with up to 20 connected nodes.
6. **Chat locked to one provider** per conversation (like ChatGPT/Claude.ai).

### Audit questions:
- Is the structured output implementation using the latest API patterns for each provider?
- Is graph context injection effective? What format produces the best results from each provider?
- How do ChatGPT Artifacts, Claude Artifacts, and Google AI Studio handle artifact lifecycle (versioning, editing, forking)?
- What are we missing that makes those feel "native"?
- How should we handle streaming structured output (OpenAI supports streaming json_schema)?

---

## Part 2: What to Extract from Agent Infrastructure

### Source codebases to examine:

**1. Goose (Apache-2.0, Block/Square)**
- Repository: https://github.com/block/goose
- Key files: `crates/goose/src/providers/`, `crates/goose/src/agents/agent.rs`, `crates/goose/src/message.rs`
- What to extract for cloud chat (NOT agents):
  - **Provider trait pattern** — clean abstraction for stream/generate across providers. Compare with our `CloudConfigurableLLMClient`. Is Goose's better?
  - **Message types** — Goose's `Message` struct handles tool_use, thinking blocks, multi-part content natively. Our `ChatMessage` is flat `content: String`. Should we adopt structured message content?
  - **Context compaction** — Goose compacts conversation history when it exceeds the context window. We don't do this yet. How does Goose's `truncate` strategy work and can we adopt it for cloud chat?
  - **Streaming architecture** — Goose uses `Pin<Box<dyn Stream<Item = Result<MessageStream>>>>`. How does this compare to our `AsyncThrowingStream<String, Error>`?

**2. Hermes (our hermes-agent submodule)**
- Key files: `hermes-agent/hermes/`, `hermes-agent/skills/`
- What to extract:
  - **Skills system** — Hermes has a skills directory with reusable prompt templates for specific tasks. Can we extract the best prompts for summarization, analysis, research, etc. and use them as system prompts for cloud calls?
  - **Procedural memory** — Hermes remembers what worked. Can we add a lightweight preference tracker to the cloud chat (which prompts got good feedback, which providers performed best for which tasks)?

**3. Our agent_core crate**
- Key files: `agent_core/src/agent_loop.rs`, `agent_core/src/providers/claude.rs`, `agent_core/src/compaction.rs`, `agent_core/src/prompt_caching.rs`
- What to extract:
  - **Prompt caching** — agent_core has a prompt caching layer. Can this be applied to cloud chat to reduce API costs?
  - **Compaction** — agent_core compacts context. Reusable for long cloud conversations?
  - **Security** — agent_core has a security module. Any patterns applicable to cloud tool_use?

**4. Our omega-mcp crate**
- Key files: `omega-mcp/src/dispatcher.rs`, `omega-mcp/src/catalog.rs`
- What to extract:
  - **Tool catalog** — MCP tool definitions that could become cloud function-calling tool definitions
  - **Vault operations** — note/graph mutations that could be exposed as cloud tool_use functions

### The surgical extraction pattern:
For each item, answer:
1. What is it? (one sentence)
2. How does the source implement it? (key function/struct)
3. Can it work WITHOUT the agent loop? (yes/no)
4. What's the minimal code to add it to the cloud chat?
5. Does it make the app feel more "native" or more "agent-y"? (native = keep, agent-y = defer)

---

## Part 3: The "Just Works" Cloud Chat Upgrade

Based on the audit and extraction, propose a concrete upgrade plan that:

### Must feel like:
- **OpenAI chat**: like ChatGPT but with your knowledge graph powering it
- **Anthropic chat**: like Claude.ai but artifacts are graph nodes and your notes are context
- **Google chat**: like AI Studio but grounded in your personal knowledge base

### Specific capabilities to evaluate:
1. **Multi-turn artifact refinement** — "update the JSON to add a field" should modify the existing artifact, not create a new one
2. **Tool use for note operations** — model can create notes, link nodes, search the vault (extracted from omega-mcp tool catalog, exposed as cloud tool_use functions)
3. **Context compaction** — when conversation exceeds provider's context window, intelligently compress history while preserving graph context
4. **Streaming JSON** — for structured output, can we stream the JSON and update the artifact card live as tokens arrive?
5. **Provider-specific optimizations**:
   - OpenAI: web search + code interpreter tools alongside our structured output
   - Anthropic: extended thinking → visible reasoning trail in the chat
   - Google: grounding with citations → citation nodes in the graph
6. **Preference learning** — track which model/provider the user prefers for which task type, auto-route

### Anti-patterns (do NOT propose):
- Don't propose an "agent loop" — this is cloud chat, not agents
- Don't propose shipping Goose as a runtime — we extract patterns only
- Don't propose new subprocesses or sidecars
- Don't propose features that require the agent ShipGate to be enabled
- Don't propose anything that breaks the "one model per chat" rule

---

## Part 4: Hide Agent UI

List every Swift view, menu item, toolbar button, and settings entry that references agents, Hermes, Omega, or MCP. For each, specify whether to:
- **Remove entirely** (dead code that confuses users)
- **Gate behind ShipGate.agentsEnabled** (useful for development)
- **Repurpose for cloud chat** (the UI pattern is good, just rewire the backend)

---

## Deliverables

1. **Audit report** on the current cloud artifact pipeline (gaps + improvements)
2. **Extraction matrix** — what to take from Goose, Hermes, agent_core, omega-mcp
3. **"Just Works" upgrade plan** — ordered by impact, with exact files to modify
4. **Agent UI hide list** — every view/entry with disposition (remove/gate/repurpose)
5. **Goose Provider trait comparison** — side-by-side with our CloudConfigurableLLMClient

---

## How to Use This Prompt

### For Claude Code:
Paste this as the session prompt. Read the referenced files in the codebase, clone goose if needed (`git clone https://github.com/block/goose /tmp/goose`), and produce the deliverables.

### For Perplexity Pro / Deep Research:
Focus on Parts 1 and 3 — audit the cloud artifact pattern against current best practices from OpenAI, Anthropic, and Google's latest API documentation. Compare our approach with how Cursor, Windsurf, and Bolt handle structured output and artifact rendering.

### For Google AI Studio:
Focus on Part 2 — analyze the Goose source code on GitHub and identify the specific functions/traits that can be surgically extracted for cloud-only use without the agent loop.
