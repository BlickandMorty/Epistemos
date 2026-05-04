# Epistemos Agent Replacement Plan

Date: 2026-03-29
Status: Phase 0 complete, replacement not yet complete

## Hard Requirement Update

The replacement is now explicitly constrained by these additional requirements:

- Rust must own real cloud-provider integrations, not just Swift wrappers:
  - Anthropic Messages API at `https://api.anthropic.com/v1/messages`
  - Perplexity Agent API at `https://api.perplexity.ai/v1/agent`
  - OpenAI Responses API at `https://api.openai.com/v1/responses`
- MCP must be first-class:
  - local stdio MCP servers stay app-hosted
  - remote MCP servers over HTTP/SSE/streamable HTTP are runtime-managed where the provider supports them
- local models must participate in the same runtime contract:
  - same session loop
  - same event model
  - same tool/result continuity
  - policy-limited autonomy based on model capability, not marketing language

## Purpose

This document is the phase-0 truth pass for the Epistemos agent-subsystem replacement.
It does not claim the runtime is already replaced.
It records:

- what the codebase actually does today
- what is real versus theatrical
- what will be retired
- what the replacement seam is
- the execution order for the full cutover

## Current Architecture Map

### Swift currently owns the agent control path

The active control flow today is:

`AppBootstrap`  
→ `OrchestratorState`  
→ `OmegaPlanningService`  
→ `OmegaInferenceBridge`  
→ `TriageService`  
→ Swift `OmegaAgent` implementations  
→ Rust helper crates for some primitives

Key consequences:

- planning is Swift-owned
- task graph execution is Swift-owned
- approval flow is Swift-owned
- retry logic is Swift-owned
- tool dispatch is Swift-owned
- research escalation is Swift-owned
- graph-memory writes are Swift-owned

### Rust currently owns only partial primitives

What Rust owns today:

- `omega-ax`: AX tree walking and CGEvent-style input primitives
- `omega-mcp`: tool registry, validation, JSON-RPC dispatch, execution logging, heuristic planning helpers
- `epistemos-core`: a scaffold `AgentSession` with JSONL transcript persistence and a toy loop

What Swift still owns that must move:

- real cloud API execution behavior currently embedded in `CloudLLMClient`
- provider selection still tied to UI/runtime state
- any local-model loop behavior that is not owned by the Rust session runtime

What Rust does not yet own:

- real provider routing
- real multi-provider orchestration
- real tool execution loop
- session resume/reload
- memory orchestration
- subagents
- policy gates as the single source of truth
- end-to-end computer-use orchestration

### Streaming exists, but not as a real agent runtime

Real streaming exists in:

- `TriageService`
- `LLMService`
- `MLXInferenceService`

But that streaming is for text generation surfaces, not a Rust-owned tool-using agent loop.

### Computer use is partially real, partially split

Real pieces:

- `omega-ax` AX tree walking
- `omega-ax` input primitives
- `ScreenCaptureService`
- `Screen2AXFusion`
- `VisualVerifyLoop`

Missing pieces:

- no single runtime owning action selection + execution + verification
- no XPC helper boundary for privileged automation
- no run-loop-pinned CGEvent execution contract
- no central policy gate for destructive UI actions

## Fake Vs Real Classification

### Real and worth keeping in some form

- cloud/local text streaming clients
- Rust AX tree and input primitives
- Rust MCP registry/logger primitives
- Swift screen capture and verification utilities
- JSONL transcript persistence scaffold in `epistemos-core`

### Partial and salvageable

- `OmegaPanel` phase UI direction
- `AgentGraphMemory` as optional graph-memory adapter
- `omega-mcp` logging and schema validation
- `omega-mcp` risk/confirmation enums

### Theatrical or structurally wrong for the end state

- `OrchestratorState` as the true agent runtime
- `OmegaPlanningService`
- `OmegaInferenceBridge`
- the Swift `OmegaAgent` layer as the primary dispatcher
- `MCPBridge` as a pending-only dispatcher with Swift secretly executing tools
- `ReasoningLoopService` as a substitute for a real multi-turn tool loop
- `OmegaLiveRuntimeState` as a UI shim over a scaffold runtime
- `Screen2AXService` placeholder VLM fallback

## Hard Replacement Decision

Omega is retired as a control abstraction.

Temporary migration shims are allowed only for:

- UI continuity during cutover
- dependency injection from `AppBootstrap`
- compatibility while new Rust runtime and Swift bridge land

Omega must not remain:

- the orchestrator
- the planner
- the runtime owner
- the lasting public architecture name

## Replacement Seam

The minimum safe seam is:

1. Keep the useful primitives.
2. Introduce a new Rust-owned runtime beside Omega.
3. Move orchestration ownership to Rust before deleting Swift orchestration.
4. Reuse Swift only as:
   - event consumer
   - approval presenter
   - computer-use primitive host
   - view layer

The new top-level names should be:

- `AgentSession`
- `AgentRuntime`
- `ProviderRouter`
- `ToolRegistry`
- `MemoryStore`
- `SessionStore`
- `SubagentPool`
- `ComputerUseBridge`
- `PolicyGate`
- `AgentEventDelegate`

## Target End State

The end-state control flow is:

SwiftUI
→ `AsyncStream<AgentEvent>`
→ UniFFI bridge
→ Rust `AgentRuntime`
→ `ProviderRouter`
→ `ToolRegistry`
→ `MemoryStore`
→ `SessionStore`
→ `SubagentPool`
→ Swift/XPC computer-use bridge only when native body access is required

## Execution Plan

### Phase 0

Done in this pass:

- current architecture mapped
- fake vs real classified
- migration matrix written
- target runtime architecture written
- test and benchmark plans written

### Phase 1

Introduce the replacement surface without deleting the app shell yet.

- add the new Rust runtime modules
- add a thin Swift `AgentRuntimeBridge`
- stop adding new behavior to Omega files
- rename UI language away from Omega where safe

### Phase 2

Build the real Rust loop.

- provider interface
- Claude primary provider via the Messages API
- Perplexity grounded-search provider via the Agent API
- OpenAI Responses provider for bounded fallback and shell-heavy paths
- streaming event model
- tool-use continuation
- bounded tool results
- JSONL session store
- real request blueprints for remote MCP-capable providers

### Phase 3

Move tool dispatch ownership into Rust.

- vault tools
- shell tools
- note tools
- MCP-backed tool adapters
- policy gates

### Phase 4

Move provider routing into Rust.

- Claude primary orchestration
- Perplexity grounded search routing
- local/private routing
- provider fallback and health
- local-agent autonomy policy based on capable model tiers

### Phase 5

Move session and memory ownership into Rust.

- summaries
- scratch directories
- memory search
- reload/resume

### Phase 6

Rebuild computer use around a real bridge.

- AX-first action path
- screenshot fallback
- verification
- approval gating
- permission and entitlement checks

### Phase 7

Add real subagents with scoped tools.

### Phase 8

Delete Omega control paths and leave only migration notes.

## Exit Criteria

The replacement is only done when:

- no Swift-owned orchestration remains
- no Omega-owned control path remains
- Rust owns loop, routing, tools, sessions, memory, and subagents
- transcripts are JSONL source of truth
- computer use is AX-first with verification
- cloud providers are called through real runtime-owned API clients
- MCP is real, transport-correct, and auditable
- local models share the runtime contract without pretending weak models can do unlimited orchestration
- required tests pass against the new runtime

Until then, status must be reported as partial.
