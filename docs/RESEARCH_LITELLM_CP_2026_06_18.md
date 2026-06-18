# R-LITELLM-CP verdict — LiteLLM Agent Control Plane vs Epistemos (2026-06-18)

**Verdict: PATTERNS-ONLY (NO-SIDECAR). Epistemos already implements the core
control-plane pattern at parity-or-better. No port. One hardening slice shipped;
one partial-gap maps onto the Osaurus plan.**

## What it is
`github.com/LiteLLM-Labs/litellm-agent-control-plane` — a unified orchestration
layer: "1 place to call all your agents" across heterogeneous agent runtimes
(Claude Managed Agents, Cursor Agents API, OpenCode, Deep Agents). It ABSTRACTS
and ROUTES agent execution to underlying runtime systems (not inference-level
routing). Stack: Rust (53%) + TS + Python + Docker Compose + Postgres.

## Side-by-side vs Epistemos

| LiteLLM-CP pattern | Epistemos today | Gap? |
|---|---|---|
| **Unified runtime adapter** ("1 place to call all agents") | `agent_core/src/tools/cli_passthrough.rs` — 9 `ToolHandler` impls (claude_code/codex/gemini/kimi/goose/aider/openhands/mini_swe_agent/opencode), all registered together (registry.rs:888) sharing the hardened `run_passthrough` | ✅ matched + EXCEEDED (9 runtimes vs their 4-5) |
| Control-plane / data-plane split (policy in service, inference in isolated runtime) | MAS/Pro split + RuntimeRouter (policy) vs the runtime handlers / providers (execution); subprocess hardening boundary | ✅ matched |
| Containerized runtime isolation | Containerization framework = Pro-only (per the Osaurus direction); CLI passthrough is hardened-subprocess (env_clear + denylist + process_group) | ✅ matched (Pro) |
| Session persistence across runs | `agent_core/src/session.rs` (GlobalSessions, SessionFolder, trace events) | ✅ matched |
| Cross-session memory | agent_runtime procedural memory + vault 5-tier + skills | ✅ matched |
| CRON scheduling | the `schedule` skill + CronCreate | ✅ matched |
| Credential vaulting (provider keys separate from agent config) | macOS Keychain (SecItemAdd, NEVER UserDefaults) | ✅ matched (stronger — OS keychain) |
| **Declarative UI-driven agent definition** (tools+skills+runtime selection in a UI) | Companion (agent creation) covers persona/instruction; a unified "bind runtime + tools + skills declaratively" surface is partial | ➖ **partial-gap → Osaurus** |
| Cost/budget limits, rate limiting, fallback chains | LiteLLM-CP itself: "notably absent" per its docs. Epistemos: `max_cost_usd` in AgentConfig + the route fallback (local-first → cloud escalation) | ✅ Epistemos ahead here |

## The one partial-gap: declarative agent definition
LiteLLM-CP's UI binds runtime + tools + skills into a named agent declaratively.
Epistemos has the pieces (Companion persona, the 9 runtime adapters, skills,
tool registry) but not one declarative "agent = {runtime, tools, skills,
persona}" surface. This is EXACTLY the **Osaurus Agent schema + Companion
agent-creation** workstream (owner's ACT-mode import; foundation 2f3ae4a5c). So
it's already on the plan — fold the declarative-agent-binding idea into the
Osaurus P3.0 plan, don't build a separate control-plane UI.

## Shipped this slice (cargo-verified, --features pro-build)
1. **Unblocked the pro-build test build** — my own P8.1 regression: the
   schema-gate test referenced a mas-only `StaticOkHandler`, breaking the whole
   pro-build compile. Un-gated it (commit cee830048).
2. **Locked the unified-adapter completeness** —
   `agent_tier_exposes_every_cli_passthrough_runtime` asserts all 9 runtime
   adapters stay registered/reachable (was only 4).

## Why not port
Python/Docker/TS + a Postgres-backed web service. NO-SIDECAR forbids the Python/
Docker runtime; a web service duplicates the Swift/Rust orchestration Epistemos
already has (typed, hardened, Keychain-backed). The only IDEA worth carrying —
declarative agent definition — is already the Osaurus workstream. No code lifted.

## Recommendation
1. Close R-LITELLM-CP: orchestration patterns matched-or-better; no port.
2. Carry "declarative agent = {runtime, tools, skills, persona}" into the
   Osaurus P3.0 plan (Companion-fronted).
