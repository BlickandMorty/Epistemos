# Osaurus → Act Connection Map (research, 2026-06-19)

Read-only research deliverable (subagent). Feeds R-OSAURUS / the Act 2-engine build.

## What Osaurus is
- Repo: **github.com/osaurus-ai/osaurus** (old `dinoki-ai/osaurus` archived). **License MIT → `direct_import` OK** (ProvenanceGate green; unlike AGPL R-FIELDTHEORY/Khoj).
- Native macOS Swift app (Swift ~63% / C ~35% MLX). macOS 15.5+ Apple Silicon.
- Serving: background HTTP on **localhost:1337** (SwiftNIO) — OpenAI/Anthropic/Ollama-compatible (`/v1/chat/completions`, etc.), OpenAI tools + tool_choice + tool_calls, SSE/NDJSON. Inference = MLX (`~/MLXModels`, HF org `OsaurusAI`).
- Agent: "every chat is an agent loop" — file/git tools, todo plan→execute→verify, memory, on-device privacy filter, MCP server+client (`/mcp/tools`, `/mcp/call`), 20+ JSON-recipe plugins.
- Sandbox: Linux VM via **Apple Containerization** (Alpine, VirtioFS `/workspace`, vsock). Needs virtualization entitlement + macOS 26-class.
- Structure: `App/` (SwiftUI UI) · **`Packages/OsaurusCore/`** (SPM lib = the substrate to link) · `OsaurusCLI/` · `OsaurusRepository/` (plugins).

## Current Epistemos seam (S4 of 6)
| Piece | File | Status |
|---|---|---|
| Act↔Osaurus protocol | `Epistemos/ActOsaurus/ActOsaurusBridge.swift` | `protocol ActOsaurusBridge` + `InertActOsaurusBridge` (default) + `OsaurusActBridge` (real, `#if !EPISTEMOS_APP_STORE`) + `ActOsaurusBridgeFactory.resolve()` |
| Flag gate | `Epistemos/ActOsaurus/ActOsaurusGateStatus.swift` | `EPISTEMOS_ACT_OSAURUS_V0` OFF default; always-compiled (MAS shows "Pro only") |
| Health row | `Epistemos/Views/Settings/ActOsaurusHealthRow.swift` | gate status + endpoint |
| Loopback server | `Epistemos/Engine/LocalModelServer.swift` | osaurus-pattern OpenAI server, `defaultPort=1337`, flag `EPISTEMOS_LOCAL_MODEL_SERVER_V0`, loopback-only |
| Vendored types | `Epistemos/Vendor/Osaurus/{ServerHealth,OsaurusChatMessage,OsaurusVendorLocalization,OsaurusVendorProvenance}.swift` | MIT direct_import + adapter_wrap for name collisions |
| Brain (the IP) | `Epistemos/LocalAgent/{LocalAgentLoop,LocalAgentPromptBuilder,LocalToolGrammar,LocalAgentGatewayPolicy}.swift` | canonical local-agent path |
| Router | `Epistemos/LocalAgent/RuntimeRouter.swift` | intra-local lane chooser (NOT the Act picker) |
| Picker precedent | `Epistemos/Work/WorkBackend.swift` | proven factory+flag engine-picker pattern to copy |
| Seam tests | `EpistemosTests/ActOsaurusSeamTests.swift` | ProvenanceGate + MAS/Pro boundary + honest gating |

OpenClaw note: no concrete OpenClaw Act-engine type yet; the "OpenClaw" engine = the existing cloud/CLI `AgentBackend`/`BackendRegistry` lane (`Epistemos/Engine/AgentHarness/AgentBackend.swift`) on the Rust `agent_core` loop.

## Layering (IP rides on top — confirms owner design)
```
Act UI (reskinned) — ChatCoordinator / Act view
  └ LocalAgent BRAIN (ALL IP in-process): LocalAgentLoop · PromptBuilder · LocalToolGrammar
      · Eidos closed-citation (Epistemos/Eidos/EidosBridge.swift,EidosWiring.swift)
      · vault/Knowledge-Core tools · cognitive DAG · provenance ledger · MCP routing
      · honesty gating (LocalAgentGatewayPolicy)
    └ ActOsaurusBridge.runTurn(model:messages:maxTokens:)  ← thin transport (POST to :1337)
      └ OSAURUS substrate (Pro-only via OsaurusCore link): MLX serving + Containerization VM + MCP + plugins
```
- **Rule:** Osaurus = engine (serve + sandboxed exec); LocalAgent = driver, KEEPS the IP. IP does NOT move into Osaurus.
- **Seam carrying IP into Act = `LocalAgentLoop`** (not the bridge): it builds the Eidos-cited prompt, enforces honesty, parses tools, runs DAG/provenance.
- **The one new wire:** swap `LocalAgentLoop`'s generation closure (`liveLoop`/`mlxGenerator` injection, ~LocalAgentLoop.swift:78–232) so when engine=`.osaurusLocal`, generation is served by `ActOsaurusBridge.runTurn` instead of in-process `MLXInferenceService`. Brain above stays untouched.
- Osaurus VM (S5) + plugins (S6) = additional `LocalAgentToolExecutor` executors the brain routes to (brain decides, Osaurus executes).

## Act 2-engine picker (one route, no third)
- `enum ActEngine { case openClaw, osaurusLocal }` (new `Epistemos/ActOsaurus/ActEngine.swift`).
- Single decision in `Epistemos/App/ChatCoordinator.swift` Act-turn dispatch (mirror `WorkBackendFactory.resolve()`):
  - `.openClaw` → existing cloud/CLI `AgentBackend` via `BackendRegistry.resolve` on `agent_core`.
  - `.osaurusLocal` → `LocalAgentLoop` brain with generator wired to `ActOsaurusBridgeFactory.resolve()` → `OsaurusActBridge.runTurn`.
- NO third route; no silent cloud fallback inside `.osaurusLocal` (bridge throws `ActOsaurusError`, not escalate).
- **RuntimeRouter ≠ Act picker.** RuntimeRouter picks intra-local serving lane *inside* the Osaurus-local brain. Don't collapse them or you create a 3rd route.

## MAS-safe vs Pro/dev-gated (honest split)
- Always-compiled (MAS): `ActOsaurusGateStatus` + `ActOsaurusHealthRow` (status only).
- In-process MAS-safe: the LocalAgent brain (Eidos/vault/DAG/provenance/honesty) — what MAS Act runs on (no Osaurus).
- Pro-gated `#if !EPISTEMOS_APP_STORE`: `ActOsaurusBridge`/`OsaurusActBridge` + vendored Osaurus + `LocalModelServer` (:1337 listener needs network.server) + OsaurusCore link + Containerization VM + plugins + relay.
- Honesty: `isLive=false` until OsaurusCore actually linked+live; `runTurn` throws rather than route to GPT (constraint #1). Never drop — Pro/dev-gate + honest "Pro only" health row.

## ProvenanceGate
- `osaurus-ai/osaurus`, **MIT**, posture **direct_import**; record in `Epistemos/Vendor/Osaurus/OsaurusVendorProvenance.swift` (sourceRepo/license/posture/importedDate). Full vendor (S2) keeps LICENSE at `LocalPackages/osaurus/LICENSE`.

## Next wires (plan order)
1. `ActEngine` type + the one branch in `ChatCoordinator` Act dispatch (mirror WorkBackendFactory).
2. Generator swap in `LocalAgentLoop` (engine=`.osaurusLocal` → `ActOsaurusBridge.runTurn`); IP stays in brain.
3. S2 vendor `LocalPackages/osaurus/` (MIT), xcodegen + lock-hash, CI both profiles, MAS-excludes-OsaurusCore guard test.
4. S3 link OsaurusCore (Pro); `isLive` reflects a live OsaurusCore service; RunEventLog + AnswerPacket.
5. S5 Containerization VM as a Pro/dev-gated `LocalAgentToolExecutor` tool; no-hidden-fallback proof + rollback.

Sources: github.com/osaurus-ai/osaurus · docs.osaurus.ai/security · in-repo docs/OSAURUS_P3_IMPORT_PLAN_2026_06_19.md.
