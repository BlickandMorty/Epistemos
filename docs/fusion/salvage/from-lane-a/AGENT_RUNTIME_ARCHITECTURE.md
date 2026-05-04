# Epistemos Agent Runtime Architecture

Date: 2026-03-29
Status: Target architecture, not yet fully implemented

## Ownership Boundary

### Rust owns the mind

Rust is the single owner of:

- agent loop
- provider routing
- tool dispatch
- tool-result continuation
- session lifecycle
- transcript persistence
- memory retrieval orchestration
- summaries and scratch space
- subagent dispatch
- policy gating
- audit logging

### Swift owns the body

Swift is the single owner of:

- UI rendering
- `AsyncStream` event consumption
- approval presentation
- ScreenCaptureKit capture
- AXUIElement access where native APIs are cleaner
- CGEvent/XPC bridge hosting
- app-native vault/model services where direct Swift access is required

Swift must not be the hidden orchestrator.

## Target Module Layout

### Rust

Recommended `epistemos-core` runtime modules:

- `agent_runtime/mod.rs`
- `agent_runtime/session.rs`
- `agent_runtime/events.rs`
- `agent_runtime/provider_router.rs`
- `agent_runtime/providers/claude.rs`
- `agent_runtime/providers/perplexity.rs`
- `agent_runtime/providers/openai.rs`
- `agent_runtime/providers/google.rs`
- `agent_runtime/providers/local.rs`
- `agent_runtime/providers/request_blueprints.rs`
- `agent_runtime/tool_registry.rs`
- `agent_runtime/tool_executor.rs`
- `agent_runtime/session_store.rs`
- `agent_runtime/memory_store.rs`
- `agent_runtime/policy_gate.rs`
- `agent_runtime/subagent_pool.rs`
- `agent_runtime/computer_use.rs`
- `agent_runtime/mcp.rs`

### Swift

Recommended Swift-side surfaces:

- `AgentPanel.swift`
- `AgentPanelState.swift`
- `AgentRuntimeBridge.swift`
- `AgentApprovalController.swift`
- `ComputerUseBridge.swift`
- `VaultToolHost.swift`

## Session Flow

1. Swift submits user objective to Rust `AgentSession`.
2. Rust loads transcript, summary, scratch, and memory context.
3. Rust `ProviderRouter` selects a provider.
4. Provider streams thinking/text/tool events.
5. Rust forwards events immediately to Swift.
6. If tool use occurs:
   - Rust preserves assistant thinking/tool blocks
   - Rust executes independent tools in parallel
   - Rust appends bounded tool results
   - Rust continues the loop
7. Rust persists JSONL transcript throughout.
8. Swift only renders phases and approval affordances.

## Event Model

Minimum event surface:

- `thinking_delta`
- `text_delta`
- `tool_call_started`
- `tool_call_finished`
- `tool_call_failed`
- `subagent_spawned`
- `approval_requested`
- `session_summarized`
- `completed`
- `failed`

These events must come from Rust, not be inferred by Swift.

## Tool Model

`ToolRegistry` should support:

- vault tools
- notes tools
- shell tools
- browser tools
- memory tools
- computer-use tools
- remote MCP tools
- local stdio MCP hosts

Tool rules:

- schemas live in Rust
- validation lives in Rust
- execution policy lives in Rust
- Swift hosts only the native body-bound tool endpoints
- local stdio MCP stays host-managed; remote MCP is attached only where the provider/API actually supports it

## Memory Model

Canonical source of truth:

- `sessions/<id>/transcript.jsonl`

Associated runtime state:

- `sessions/<id>/summary.md`
- `sessions/<id>/scratch/`
- searchable index entries

Rules:

- transcript is canonical
- indexes are derived
- large tool results are bounded before persistence into prompt context
- memory search is callable as a tool, not bolted on as hidden preprompt stuffing

## Provider Router

Initial routing policy:

- Claude: primary orchestrator for reasoning, coding, multi-step tool use via `POST /v1/messages`
- Perplexity: grounded/current-info workflows via `POST https://api.perplexity.ai/v1/agent`
- OpenAI: bounded shell/recovery paths via `POST /v1/responses`
- local provider: privacy/offline/light transformations, plus policy-limited autonomous loops for capable local models

OpenAI or other providers should only land if they fit the same ownership model cleanly.

Local-provider rule:

- local models use the same session, event, and tool-loop contract as cloud providers
- small local models are bounded to short-loop or single-tool roles
- full autonomous local loops require a capability-gated policy and explicit turn limits

## Subagents

Required roles:

- researcher
- writer
- coder
- critic
- computer

Rules:

- isolated context
- isolated tool allowlists
- only top-level orchestrator spawns them
- results return to orchestrator as bounded summaries

## Computer Use Bridge

Correct design:

- AX-first action grounding
- screenshot fallback and verification
- approval gate for destructive actions
- post-action verification
- stale-frame protection

The bridge can be Swift/XPC hosted, but the decision to use it belongs to Rust.

## MCP Notes

- local vault/system MCP servers should use stdio and never write logs to stdout
- remote MCP servers should use transport-correct HTTP/SSE/streamable HTTP connectors
- Anthropic remote MCP attachment belongs in the runtime request builder; local stdio MCP does not get tunneled through Anthropic directly

## Cutover Notes

Temporary shims are acceptable for:

- `AppBootstrap` injection
- UI continuity
- mapping old settings into new runtime config

They are not acceptable as permanent control ownership.
