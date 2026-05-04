# Epistemos Agent Migration Matrix

Date: 2026-03-29
Status legend: `KEEP`, `MIGRATE`, `REPLACE`, `DELETE`

| Component | Current Role | Status | Why | Replacement Target |
|---|---|---|---|---|
| `Epistemos/Omega/Orchestrator/OrchestratorState.swift` | True Swift-owned planner and executor | `REPLACE` | Violates Rust-owns-the-mind requirement | Rust `AgentRuntime` + thin Swift bridge |
| `Epistemos/Omega/Inference/OmegaPlanningService.swift` | Local-model JSON planner | `DELETE` | One-shot planning, no living loop | Rust provider loop |
| `Epistemos/Omega/Orchestrator/OmegaInferenceBridge.swift` | Swift bridge from planner to `TriageService` | `DELETE` | Keeps orchestration in Swift | Rust provider adapters |
| `Epistemos/Omega/Orchestrator/OmegaLiveRuntimeState.swift` | UI shim over scaffold runtime | `DELETE` | Transitional only, not the runtime | Swift `AgentPanelState` backed by Rust events |
| `Epistemos/Views/Omega/OmegaPanel.swift` | Agent UI shell | `MIGRATE` | UI is valuable, Omega naming/control is not | `AgentPanel` consuming `AsyncStream<AgentEvent>` |
| `Epistemos/Omega/Agents/OmegaAgent.swift` | Swift-side agent protocol | `DELETE` | Encodes the wrong control boundary | Rust `ToolRegistry` + Swift tool hosts |
| `Epistemos/Omega/Agents/FileAgent.swift` | Vault file tool implementation | `MIGRATE` | Tool logic is useful, agent wrapper is not | Vault tool adapter |
| `Epistemos/Omega/Agents/NotesAgent.swift` | Note tool implementation | `MIGRATE` | Tool logic is useful, agent wrapper is not | Notes/vault tool adapter |
| `Epistemos/Omega/Agents/SafariAgent.swift` | Safari/web tools | `MIGRATE` | Keep useful tool logic; remove Swift orchestration | Web/browser tool adapter |
| `Epistemos/Omega/Agents/TerminalAgent.swift` | Shell tool wrapper | `MIGRATE` | Allow-listing is useful, agent wrapper is not | Rust-owned shell tool with policy bounds |
| `Epistemos/Omega/Agents/AutomationAgent.swift` | Swift automation tool wrapper | `MIGRATE` | Useful host for native actions, wrong ownership today | `ComputerUseBridge` |
| `Epistemos/Omega/MCPBridge.swift` | Swift registry/logger bridge to Rust dispatcher | `REPLACE` | Current dispatch returns pending and Swift secretly executes | Rust-executable tool registry and MCP adapters |
| `omega-mcp/src/dispatcher.rs` | Tool registry, validation, JSON-RPC dispatch, logging | `MIGRATE` | Good primitive, wrong pending-only execution model | Core `ToolRegistry` and audit logger |
| `omega-mcp/src/orchestrator.rs` | Rust heuristic planner/task graph | `MIGRATE` | Some enums/utilities are useful; current planner is not the end state | `PolicyGate` pieces only |
| `omega-ax/src/ax_tree.rs` | Real AX tree primitive | `MIGRATE` | Valuable primitive, but Omega-branded crate | `computer_use::ax` |
| `omega-ax/src/input.rs` | Real CGEvent input primitive | `MIGRATE` | Valuable primitive, needs run-loop correctness review | `computer_use::input` |
| `Epistemos/Omega/Vision/ScreenCaptureService.swift` | ScreenCaptureKit capture | `KEEP` | Correct native body-layer responsibility | `ComputerUseBridge` dependency |
| `Epistemos/Omega/Vision/Screen2AXFusion.swift` | AX-first perception with OCR enrichment | `MIGRATE` | Good fallback design | `ComputerUseBridge` perception layer |
| `Epistemos/Omega/Vision/VisualVerifyLoop.swift` | Post-action verification | `MIGRATE` | Good concept, should be runtime-integrated | `ComputerUseBridge` verification layer |
| `Epistemos/Omega/Vision/Screen2AXService.swift` | Placeholder screenshot-to-AX VLM path | `DELETE` | Explicitly incomplete | Real screenshot fallback or none |
| `epistemos-core/src/agent_runtime.rs` | JSONL + scaffold loop | `REPLACE` | Good seed, not a production runtime | Real `AgentRuntime` modules |
| `epistemos-core/uniffi/epistemos_core.udl` | UniFFI surface for scaffold session | `MIGRATE` | Keep bridge approach, expand API | New runtime/session/event exports |
| `Epistemos/Engine/TriageService.swift` | Local/Apple routing for text tasks | `MIGRATE` | Routing knowledge is useful, but not agent routing | Local-provider adapter and heuristics |
| `Epistemos/Engine/LLMService.swift` | Cloud/local text clients and SSE parsing | `MIGRATE` | Provider client logic is reusable, but runtime ownership is wrong | Rust provider implementations or reference behavior |
| `Epistemos/Engine/LLMService.swift::CloudLLMClient` | Real Anthropic/OpenAI/Google request and stream behavior | `MIGRATE` | Valuable source of real API behavior that must move out of Swift | Rust cloud providers |
| `Epistemos/Omega/Inference/ReasoningLoopService.swift` | Internal self-critique loop | `DELETE` | Not a real tool-using agent runtime | Claude/tool loop in Rust |
| `Epistemos/Omega/Knowledge/AgentGraphMemory.swift` | Writes execution results into graph memory | `MIGRATE` | Optional long-term memory adapter, not canonical memory | Post-execution graph sink |
| `Epistemos/App/AppBootstrap.swift` | Wires Omega as agent subsystem | `MIGRATE` | Bootstrap stays, Omega wiring goes | Wire new runtime bridge |
| `Epistemos/Omega/**/*` overall namespace | Mixed planning, execution, vision, training, branding | `DELETE` after cutover | Namespace itself encodes the old architecture | New agent namespaces only |

## Summary

### Keep as-is

- `ScreenCaptureService.swift`

### Migrate into the new architecture

- tool implementations
- AX/input primitives
- verification/perception helpers
- some provider client logic, especially real cloud request/stream behavior
- UniFFI bridge strategy

### Replace entirely

- Swift orchestrator
- MCP pending-dispatch model
- scaffold runtime

### Delete after cutover

- Omega planner
- Omega inference bridge
- Omega agent protocol
- Omega live-runtime shim
- placeholder screenshot VLM path
- Omega namespace control paths
