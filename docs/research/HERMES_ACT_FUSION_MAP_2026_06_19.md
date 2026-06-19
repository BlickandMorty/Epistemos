# Hermes → LocalAgent Fusion Map (research, 2026-06-19)

Read-only research deliverable (subagent). Feeds R-HERMES (fuse INTO LocalAgent; one routing lane; NO subprocess/UI-bridge).

## What Hermes is
- Repo: **github.com/NousResearch/hermes-agent** ("self-improving AI agent"). Python ~82% (TS/JS = website/gateway glue). **License MIT** (Copyright 2025 Nous Research) → App-Store compatible.
- **Liftable pure logic:** ReAct loop (`agent/run_agent.py`), tool registry+dispatch (`model_tools.py`), prompt tiering + compaction (`prompt_builder.py`, `context_compressor.py`), provider/transport abstraction (`runtime_provider.py`, `transports/`), memory curation (`memory_manager.py`), skills format + progressive-disclosure loader + auto-skill heuristic, delegation (`delegate_tool.py`).
- **Do NOT lift (subprocess/UI-bridge temptations):** `gateway/` server + Hermes-UI, `hermes_cli/` TUI, `execute_code` (child proc + UDS JSON-RPC), terminal/browser backends, `cronjob` daemon, Honcho + network memory providers, Modal/Daytona.
- **KEY:** Hermes's tool-call wire format (`<tools>`/`<tool_call>{name,arguments}`/`<tool_response>`) is the SAME Hermes-3 grammar Epistemos already speaks (`agent_core/src/agent_runtime/prompt_format.rs:61-105`, `function_call.rs`) → format-compatible, low-friction.

## The brain seam (where to fuse)
- In-process brain = **`LocalAgentLoop.run(...)`** (`Epistemos/LocalAgent/LocalAgentLoop.swift:270`), instantiated via `DeviceAgentService.makeLocalAgentLoopIfAvailable()` (`Omega/Inference/DeviceAgentService.swift:371`). `ActOsaurusGateStatus.swift:27` doctrine: "Act stays on the in-process local-agent path"; Osaurus :1337 server is Pro/inert. **Fuse Hermes into the in-process LocalAgentLoop / `agent_core::agent_runtime`, NOT the ActOsaurus server lane.**
- Rust `agent_core/src/agent_loop.rs::run_agent_loop` has richer machinery (compaction:296, 5-tier context:226) but HARD-REJECTS local providers (line 166, `LocalProviderNotAllowed`) — cloud-only by doctrine. So: Hermes *algorithms* → Rust `agent_runtime` (callable by both); local *orchestration* stays Swift `LocalAgentLoop`.
- Parity gaps (the targets), per `docs/_archive/hermes-removal-2026-05-05/HERMES_PARITY_REPORT.md:38-46`: LocalAgent mode has NO prompt caching, NO context compression, NO memory, NO skills, NO approvals/security, NO session persistence.

## Capability → seam map
| # | Hermes capability | Fuse INTO | Posture |
|---|---|---|---|
| 1 | Progressive-disclosure Skills + SKILL.md format | `agent_core/src/agent_runtime/skills.rs` + `procedural_memory.rs`; surface tool in `LocalToolGrammar` | adapter_wrap |
| 2 | Auto-skill heuristic (5+ tool successes → propose skill) | `agent_runtime/self_evolution.rs::propose_repeated_success_skill` | clean_room |
| 3 | Context compaction (summarize middle turns) | Swift `LocalAgentLoop` compactor beside `trimHistory:355` (mirror `agent_loop.rs:296`) | clean_room |
| 4 | Tiered prompt (stable/context/volatile → cache prefix) | `agent_runtime/prompt_format.rs::build_system_prompt` + Swift `LocalAgentPromptBuilder.systemPrompt` | adapter_wrap |
| 5 | MEMORY.md/USER.md curation + budget | new `agent_runtime/memory_curation` → `agent_loop.rs:226` + Swift `additionalSystemPrompt`; storage = vault | clean_room |
| 6 | Session search + summarize-then-answer | route to `epistemos-shadow` (tantivy+usearch) via `SearchIndexService`; `session.search` tool | adapter_wrap |
| 7 | Provider/transport abstraction (provider+model+base_url) | `agent_core/src/routing.rs` + Swift `RuntimeRouter`/`ConfidenceRouter` | adapter_wrap |
| 8 | `delegate_task` subagent (isolated ctx, restricted tools) | new `agent_runtime` module + `delegate` tool; subagent = another in-process loop, NEVER a process | clean_room |
| 9 | ReAct termination + tool discipline | already present both loops; reinforce + per-turn tool-call cap | direct_import (conceptual) |
| 10 | `todo` self-plan tool | Epistemos `/todo` already exists (`LocalAgentTodoCommand.swift`); expose to model in local loop | adapter_wrap |

**Priority (closes most parity gaps fastest):** #4→#3→#5 (prompt tiering→caching→compaction→memory) + #1+#2 (skills+auto-evolution). All clean_room/adapter_wrap, all land in `agent_runtime` (Rust) or Swift `LocalAgentLoop`; none add process/network surface.

## Act connection (in-process chain, already exists)
```
Act surface (RootView/CoworkChatMode)
  → AgentQueryEngine.submitMessage/.runTurn (Engine/AgentHarness/AgentQueryEngine.swift:158/171)
      → BackendRegistry.resolve (:194)        ← executor seam (= design doc AgentExecutor trait)
  ──Osaurus-local device path──
  → DeviceAgentService.makeLocalAgentLoopIfAvailable() (:371)
      → LocalAgentLoop.run(objective,tools,...) (LocalAgentLoop.swift:270)   ← THE BRAIN
```
- `AgentBlueprint`/`AgentMissionPacket` (`LocalAgent/AgentBlueprint.swift:281`) = identity layer (design doc §3 "single source of truth"); Hermes caps attach here as policies → same blueprint runs local-Hermes-fused or cloud ("provider replaceable, identity not").

## Subprocess/UI-bridge temptations → in-process answers
- Hermes gateway server / UI → drive `LocalAgentLoop.run` directly; no Hermes port.
- `execute_code` child proc → tools stay native Swift/Rust in `LocalToolGrammar` + `tools/registry.rs`; `code_execution` already Pro/approval-gated + `harden_cli_subprocess`.
- cron daemon → Epistemos in-process scheduling, no agent daemon.
- network memory → vault + `epistemos-shadow`.
- delegate "terminal sessions" → in-process loop instances.
- hermes_cli TUI → Act surface only; brain emits `AgentEvent` streams, never terminal.
Guardrails in place: `LocalAgentCapability.requiresSubprocess/requiresNetwork`, `harden_cli_subprocess` (security.rs), symbol-leak audits, `EPISTEMOS_ACT_OSAURUS_V0` gate.

## ProvenanceGate
- Hermes core = MIT → clean_room/adapter_wrap with MIT attribution (Python→Swift/Rust, so literal direct_import rare). Record `HermesVendorProvenance { sourceRepo; license="MIT"; posture; importedDate }` (mirror OsaurusVendorProvenance).
- CAUTION: `agentskills.io` SKILL.md spec + sibling repos `NousResearch/autonovel`, `NousResearch/hermes-agent-self-evolution` carry their OWN licenses — quarantine + verify each before its code enters product. (Hermes core is NOT AGPL → clears MAS bar.)

Sources: github.com/NousResearch/hermes-agent · hermes-agent.nousresearch.com/docs · agentskills.io/specification.
