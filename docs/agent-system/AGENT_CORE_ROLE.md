# agent_core Rust Crate — Architecture Role

> **Index status**: CANONICAL-RESEARCH — Agent system architecture (cited from CLAUDE.md). Phase D / K reference.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/20_canonical_research/agent_system/`.



## Status: Future-Path Crate (Not Currently Compiled Into App)

The `agent_core/` Rust crate implements a full agentic runtime in Rust:
- Agent loop with multi-turn tool calling (`agent_loop.rs`, 553 lines)
- Claude API streaming with SSE parsing (`providers/claude.rs`, 595 lines)
- Tool registry and execution (`tools/registry.rs`, 506 lines)
- Prompt caching with 4-breakpoint system (`prompt_caching.rs`, 167 lines)
- 4-phase context compaction (`compaction.rs`, 563 lines)
- Security with credential redaction and threat scanning (`security.rs`, 483 lines)
- Session tracking (`session.rs`, 117 lines)
- Vault storage with hybrid search (`storage/vault.rs`, 432 lines)
- UniFFI bridge with callback interface (`bridge.rs`, 352 lines)

## Why It Exists But Is Not Wired

The Rust agent_core was built as a native-first agent runtime. However, the
Hermes integration strategy shifted to using the Python hermes-agent as a
managed subprocess (via `epistemos_bridge.py`), which provides:

1. **Immediate full Hermes parity** — all 60+ tools, skills, cron, MCP, gateway, session management
2. **Battle-tested code** — Hermes has 250K lines of production Python with 343 test files
3. **Faster iteration** — Python changes don't require recompilation of the app

The Rust crate is preserved as the **future-path** for:
- Fully native local agent execution without Python dependency
- Lower latency tool execution for on-device workflows
- Offline agent mode with no subprocess overhead

## Current Integration Evidence

In `Epistemos/Bridge/StreamingDelegate.swift`:
```swift
#if canImport(agent_core)
import agent_core
#endif

#if !canImport(agent_core)
// Stub protocol and types so Swift compiles without Rust FFI
protocol AgentStreamEventDelegate: AnyObject, Sendable { ... }
func runAgentSession(...) async throws -> AgentResultFFI {
    throw AgentRuntimeBridgeError.bindingsUnavailable
}
#endif
```

The `canImport(agent_core)` guard means:
- When the Rust crate IS compiled and linked, Swift uses the real FFI bindings
- When it is NOT compiled (current state), Swift uses stub types and the function throws `.bindingsUnavailable`

## Current Execution Paths

| Mode | Path | Runtime |
|------|------|---------|
| Cloud Agent | Swift UI -> HermesSubprocessManager -> epistemos_bridge.py -> Hermes AIAgent -> Cloud API | Python subprocess |
| Local Agent (capable model) | Swift UI -> HermesSubprocessManager -> epistemos_bridge.py -> LocalInferenceServer -> Swift MLX | Python subprocess + local HTTP |
| Local Chat (non-agent) | Swift UI -> LLMService -> MLX-Swift | Direct in-process |
| Apple Intelligence | Swift UI -> Apple Intelligence API | Direct in-process |

The Rust agent_core is not on any of these paths today. It will be activated when:
1. UniFFI bindings are generated and linked into the Xcode project
2. The `canImport(agent_core)` condition becomes true
3. A routing decision directs traffic to the Rust loop instead of the Python subprocess

## Relationship to epistemos-core

`agent_core/` is a **separate crate** from `epistemos-core/`. They share no code.

- `epistemos-core/` — the existing Rust crate for vault analysis, quality filtering, auto-tuning, scheduling. Already compiled into the app via UniFFI.
- `agent_core/` — the agentic runtime crate. NOT yet compiled into the app.
- `epistemos-core/src/agent_runtime/` — additional runtime modules (routing, provider API, cost tracking) that extend epistemos-core. These ARE compiled.

## Decision Log

- **2026-03-29**: Decided to keep agent_core as future-path rather than delete it. The code is real and tested; it just needs UniFFI binding generation to activate.
- **2026-03-30**: Hermes subprocess bridge confirmed as primary agent runtime. agent_core preserved for native-only future.
