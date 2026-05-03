# mcpbridge-tools-call-denial-provenance-pr35 deliberation - 2026-05-03

Slice:          MCPBridge Core tools/call denial AgentEvent provenance
Tier:           Core
Files touched:
- `Epistemos/Omega/MCPBridge.swift`
- `EpistemosTests/MCPBridgeAgentEventTests.swift`
- Round 72 fleet, registry, preflight, current-state, workcard, and guard docs
Protected paths: `agent_core`, `omega-mcp`, generated UniFFI bindings, provider adapters, subprocess launchers, ChatCoordinator, PipelineService, UI, graph, EventStore schema, Sovereign, ANE/private APIs
Gate:           SovereignGate touchpoint? none
Risks:          P0 if raw MCP arguments, paths, result payloads, or arbitrary messages are persisted; P0 if Core starts surfacing/executing hidden gateway tools; P1 if Pro/Research fallthrough behavior changes.
Verification:   focused Swift Testing suite plus source greps; log under `/tmp/epistemos-mcpbridge-tools-call-denial-provenance-pr35-green-20260503.log`
Rollback:       remove the recorder injection, denial event helper, and focused tests; no schema migration is involved.
Stop triggers:
- Any patch edits Rust MCP/agent code, generated bindings, provider adapters, subprocess launchers, ChatCoordinator, PipelineService, UI, graph, EventStore schema, Sovereign, or ANE/private API surfaces.
- Any patch records completed/failed execution events for policy-denied calls; this slice records requested/denied only.
- Any patch persists raw JSON-RPC request bodies, `params.arguments`, filesystem paths, command strings, result payloads, localized descriptions, or arbitrary denial text in AgentEvent payloads.

## Intent

Close the next safest AgentEvent hardening gap by making an already-closed Core
MCP policy denial auditable in durable provenance, without widening MCP
execution or changing the visible Core/App Store contract.

## Canon Anchors

- `MASTER_RESEARCH_INDEX_2026_05_02.md §6`
- `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md:1116`
- `AGENT_BUILD_WORKCARDS_2026_05_01.md:2521`

## Workcard Match

- `AGENT_BUILD_WORKCARDS_2026_05_01.md` card: Card 7 AgentEvent Tool Provenance plus Core/MAS Tool Surface Policy follow-on state.
- Deviation: This is a denial-provenance hardening slice, not a new MCP execution slice. It intentionally leaves Rust dispatcher registration and tool execution untouched.

## Acceptance

- Core/App Store denied `tools/call` for a hidden gateway tool still returns JSON-RPC `-32601` "Tool not found".
- The denied path records exactly two AgentEvents: `.toolCallRequested` and `.toolCallDenied`.
- Persisted denied-path AgentEvents use synthetic run/tool-call identity, bounded metadata, sanitized arguments JSON, nil result JSON, and a generic denial error.
- Raw JSON-RPC body, `params.arguments`, command strings, filesystem paths, result payloads, localized descriptions, and arbitrary denial text are not persisted.
- Core-safe `read_file` calls and Pro/Research `run_command` calls do not emit policy-denial provenance.
- No Rust, generated binding, provider, subprocess, UI, graph, EventStore schema, Sovereign, or ANE/private API files change.

## Failure-Proof Guardrails (post-merge)

- grep: `rg -n 'recordToolCallPolicyDenial|mcp_bridge_policy_gate|policy_gate' Epistemos/Omega/MCPBridge.swift EpistemosTests/MCPBridgeAgentEventTests.swift`
- grep: `rg -n 'argumentsJSON: requestJson|resultJSON: gateResponse|params\\[\"arguments\"\\]' Epistemos/Omega/MCPBridge.swift`
- log: `Test Suite 'Selected tests' passed`
- test: `EpistemosTests/MCPBridgeAgentEventTests`

## Fleet Evidence Packet

- `docs/fusion/fleet/mcpbridge-tools-call-denial-provenance-pr35/aggregator.md`
- `docs/fusion/fleet/mcpbridge-tools-call-denial-provenance-pr35/claude-red-team/attacks.md`

## Usefulness

usefulness: +1
usefulness_reason: Adds durable, sanitized audit evidence to an existing Core denial gate without enabling new MCP execution.
