# Epistemos Agent Source Synthesis

Date: 2026-03-29
Status: Canonical pre-build synthesis for the full agent replacement

## Purpose

This document is the source-convergence pass across the referenced agent architecture documents.
It exists to keep the next implementation steps anchored to the strongest shared guidance instead of drifting toward whichever document is most recent or most forceful.

It is not a completion claim.
It is a decision document for the next safe replacement boundary.

## Sources Read

The following source documents were read and cross-compared for recurring architecture rules, implementation patterns, and constraints:

- `release/new agents/EPISTEMOS_REAL_AGENTS.md`
- `release/new agents/Production-Grade AI Agents in a Native Swift Rust macOS PKM App.md`
- `release/new agents/The Complete Native macOS AI Agent System — Swift 6 · Rust · UniFFI · PKM.md`
- `release/new agents/Architecting Autonomous Native macOS AI Agents_ A Blueprint for High-Performance Personal Knowledge Management Systems.md`
- `release/new agents/and i want my computer use e to be transformed by.md`
- `release/new agents/here/EPISTEMOS_AGENT_ARCHITECTURE_v1.md`
- `release/new agents/here/EPISTEMOS_AGENT_ARCHITECTURE_v1.1_ADDENDUM.md`
- `release/new agents/here/EPISTEMOS_MASTER_BUILD_SPEC.md`

## Shared Consensus

Across the document set, the strongest recurring decisions are:

1. The agent must be a real multi-turn loop, not a request-response pipeline with theatrical UI.
2. Rust must own the loop, provider HTTP execution, storage, routing, tools, policy, and audit state.
3. Swift must own rendering, approval UX, and native macOS body access such as AX, ScreenCaptureKit, and CGEvent hosting.
4. Claude is the primary orchestrator for complex reasoning and tool-using work.
5. Thinking continuity is critical. Thinking blocks must be preserved across tool turns without lossy conversion.
6. Streaming is mandatory. Thinking, visible text, tool input, tool start, tool result, and completion must be emitted live.
7. Independent tools must run in parallel.
8. JSONL transcripts on disk are the canonical session record.
9. Memory search is a first-class runtime feature, not a hidden prompt trick.
10. MCP is a core architecture layer, not an optional bolt-on.
11. Computer use must be AX-first with screenshot and vision fallback.
12. Local models are useful, but only with hard capability boundaries and honest routing.

## Consensus Architecture

The strongest cross-document architecture is:

SwiftUI
→ `AsyncStream` or callback-driven event consumption
→ UniFFI bridge
→ Rust `AgentRuntime`
→ `ProviderRouter`
→ `ToolRegistry`
→ `MemoryStore`
→ `SessionStore`
→ `SubagentPool`
→ Swift/XPC-hosted native body tools only when platform access is required

This means:

- Swift is never the hidden orchestrator.
- Rust is never just a utility library.
- Provider execution and tool continuation are never split across both languages.

## Non-Negotiable Runtime Rules

The next implementation stages must preserve these rules:

### 1. Signed thinking continuity

The runtime message model must support:

- assistant text blocks
- tool use blocks
- thinking blocks with provider integrity signatures when required

For Anthropic-class providers, the full assistant content array must round-trip into the next turn exactly enough to preserve reasoning continuity.

### 2. Real loop semantics

The runtime must:

- assemble context
- stream provider output
- collect completed content blocks
- execute tools
- append assistant blocks
- append tool results as user content
- continue until the provider ends the turn
- compact context when needed
- stop on cancellation or safety rails

### 3. Typed live events

The event model must include, at minimum:

- thinking delta
- text delta
- tool input delta
- tool started
- tool completed
- approval requested
- turn started
- completion
- failure

Swift should render these.
Swift should not infer them after the fact.

### 4. Transcript-first persistence

Canonical state should live under a session directory:

- `transcript.jsonl`
- `summary.md`
- `scratch/`
- optional recipe and metric records

Indexes are derived.
They are not the source of truth.

### 5. Bounded tool results

Tool outputs must be typed and size-limited before they re-enter model context.
Large reads must be chunked or paginated.

## Provider Strategy

The provider strategy supported by the strongest doc consensus is:

### Primary

- Claude Messages API for the main orchestrator and serious multi-step work

### Secondary

- Perplexity Agent or Sonar path for current-info and grounded research
- OpenAI Responses for hosted shell, bounded recovery paths, and tool surfaces that fit OpenAI better

### Optional later

- Gemini deep research or background research agent

### Local

- Apple Foundation Models for private classification, tagging, light summarization, and offline tasks
- Ollama or MLX-hosted Qwen or Hermes for constrained local specialist loops

## Local Agent Decision

The documents agree on an important nuance:

- small local models should not be treated as a drop-in replacement for Claude-class orchestration
- local models can still be useful as real agents when heavily constrained

The synthesis decision is:

1. Local models are allowed to run short, capability-gated loops.
2. Those loops must use grammar-constrained tool calling or schema-constrained output.
3. They should be routed to specialist work:
   - classification
   - tagging
   - ghost-writing
   - embeddings
   - short single-tool or very short multi-tool tasks
4. They must not be marketed or wired as the default full orchestrator until they prove reliable at that level.

This resolves the apparent document tension:

- the cloud-orchestrated system remains the primary architecture
- local specialist loops are real, but bounded

## MCP Decision

The correct MCP stance is:

- MCP is first-class in the runtime
- Rust owns tool schemas, routing, policy, and execution orchestration
- Swift and XPC may host native tool endpoints
- local stdio MCP servers must never log to stdout
- remote MCP attachment should be used directly where the provider supports it

The current pending-only MCP bridge is not the target architecture.

## Computer Use Decision

The strongest shared computer-use strategy is:

1. Query AX first.
2. Act semantically when possible.
3. Fall back to screenshot plus vision only when AX is sparse or absent.
4. Verify after every action.
5. Run CGEvent posting on the main run loop of the helper process.
6. Prefer latest-frame strategies over stale buffered frames.
7. Keep destructive actions behind policy gates and explicit approval.

The target hosting model is:

- sandboxed main app
- privileged XPC helper for automation and capture
- local system MCP surface over that helper boundary

## Memory and Context Decision

The strongest shared memory rules are:

1. Bootstrap with runtime instructions plus recent transcript plus memory search.
2. Use memory search as the first tool path for multi-turn work.
3. Summarize long sessions instead of flooding the context window.
4. Use the file system as working memory through session scratch space.
5. Keep tool results bounded.
6. Preserve thinking blocks during compaction.

## Tool Arsenal Decision

The documents are unusually consistent here:

- `fd` over `find`
- `rg` over `grep`
- `ast-grep` for structural code search
- `comby` for structural rewrites
- `jq` and `gron` for JSON
- `yq` for YAML and frontmatter
- `difftastic` and `delta` for readable diffs
- `fq` for binary inspection
- `watchexec` for file-watch flows
- `git-absorb` and `git-branchless` for agent-safe git workflows
- `hyperfine`, `shellcheck`, `swiftlint`, `xcbeautify`, `bacon`, and similar tools as verification primitives

This tool set should be treated as part of the runtime environment contract, not as random optional extras.

## FFI Decision

Several documents argue that BoltFFI is the eventual higher-performance bridge.
That may be true for very high-frequency, structured event traffic.

The synthesis decision for the next phase is:

- do not switch FFI technologies before the real runtime contract exists
- keep UniFFI for the next cutover because the app already uses it and the replacement risk is much lower
- add throughput and latency measurement to the event bridge
- revisit BoltFFI only if live runtime measurements prove UniFFI is the bottleneck

This avoids architecture theater.

## The Next Safe Cutover Boundary

The next safe replacement boundary is not full MCP migration, not full computer-use migration, and not deleting every Omega file immediately.

The next safe boundary is:

### Cut A — Runtime Contract Replacement

This cut should deliver:

1. A real Rust message model with:
   - typed assistant content blocks
   - thinking signatures where required
   - typed tool uses
   - typed tool results

2. A real async provider trait with streaming semantics:
   - `MessageStream`
   - typed `StreamEvent`
   - provider-owned SSE parsing
   - compaction support

3. A real Rust loop entrypoint:
   - multi-turn continuation
   - cancellation
   - context threshold checks
   - tool-result feedback
   - transcript persistence throughout

4. A real callback-based UniFFI bridge:
   - callback interface
   - async session entrypoint
   - no post-hoc event polling

5. A thin Swift consumer:
   - event bridge
   - phase rendering
   - approval UI
   - no hidden orchestration

### Why this is the right stopping point

Once Cut A lands, the architecture stops being fake at the core boundary.
From there, MCP, memory, computer use, subagents, and local specialists can plug into a real session contract instead of piling onto mixed ownership.

Without Cut A, every later feature risks being bolted onto the wrong foundation.

## What Should Not Happen Before Cut A

The next implementation tasks should avoid these until the runtime contract is in place:

- large Swift-side UI rewrites beyond what the new event bridge needs
- final Omega namespace deletion
- broad MCP transport expansion
- recipe cache work
- full subagent orchestration
- deep computer-use rewiring
- FFI replacement experiments

Those all become cleaner after the runtime contract is real.

## Working Rule For Next Tasks

If a proposed task makes Swift smarter as an orchestrator, it is moving in the wrong direction.

If a proposed task makes Rust more authoritative over:

- session state
- streaming
- provider continuation
- tool dispatch
- policy
- transcripts

it is probably aligned.

## Good Stopping Point Reached

This document marks the current stopping point:

- the reference documents have been read and synthesized
- the recurring architecture decisions are now explicit
- the major conflicts have been resolved into one implementation stance
- the next safe cutover boundary is defined as `Cut A — Runtime Contract Replacement`

The next structured build tasks should start from this boundary.
