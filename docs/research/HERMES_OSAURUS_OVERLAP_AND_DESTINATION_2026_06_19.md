# Hermes ↔ Osaurus Overlap + Destination Map (deep research, 2026-06-19)

Read-only research (two parallel subagents, repo-grounded + web). Answers the owner's
two questions: (1) does Hermes overlap Osaurus? (2) where does the lifted logic go —
Osaurus or another part? Sharpens R-HERMES. Licenses: Hermes MIT, Osaurus MIT.

## Headline (the surprise): the real port is only **4 items**, and **none of it lives on Osaurus**

Of ~13 Hermes capabilities, **9 are already covered** (by Epistemos or Osaurus) and a
large block is **redundant/conflicting with Osaurus** and must be EXCLUDED. Only **4**
are genuinely unique-to-Hermes and worth lifting — all small clean-room *algorithm*
lifts, no process/network/UI. The lifted logic fuses into the **in-process LocalAgent
brain** (Rust `agent_core::agent_runtime` + Swift `LocalAgentLoop`), **NOT onto Osaurus**
(the `:1337` server stays the inert engine room; the only Osaurus wire is the generation-
closure swap, which replaces token serving, never brain logic).

## The 4 things to actually port (UNIQUE TO HERMES)

| # | Capability | Destination | Swift/Rust | Why it's the gap |
|---|---|---|---|---|
| 1 | **Session search → summarize-then-answer** (strongest) | new `session.search` tool: schema/handler in Rust `session.rs`+registry, index query dispatches to Swift `SearchIndexService.fusedSearch` over `epistemos-shadow` | both | pieces exist (per-session summary `session.rs:339`, vault FTS, tantivy+usearch) but the closed "search prior sessions→summarize→answer" flow is NOT wired |
| 2 | **Swift-side context compaction (summarize middle turns)** | Swift `LocalAgentLoop` — new summarizing compactor beside `trimHistory:1356` | Swift | Rust already summarizes (`compaction.rs::compact_messages`, proactive `agent_loop.rs:296`) but the cloud loop HARD-REJECTS local providers (`agent_loop.rs:147 LocalProviderNotAllowed`), so the local loop can't reach it; today Swift only TRUNCATES |
| 3 | **Named prompt-tier model (stable/context/volatile)** | Rust `agent_runtime::prompt_format::build_system_prompt` + Swift `LocalAgentPromptBuilder.systemPrompt` mirror | both | Epistemos has cache-aware ordering + Anthropic breakpoints but no formal 3-tier data model; one structure should drive both MLX prefix-cache + Anthropic breakpoints |
| 4 | **Richer auto-skill triggers** | Rust `agent_runtime::self_evolution.rs::propose_repeated_success_skill` | Rust | Epistemos detects repeated N-step sequences; Hermes also proposes on errors/dead-ends, user-correction, and discovered novel workflows — add those trigger signals (promotion stays Sovereign-gated) |

## Already covered — do NOT re-port (B = in Epistemos)

ReAct loop (`agent_loop.rs:151` + `LocalAgentLoop.swift:270`) · tool registry+dispatch
(`tools/registry.rs:548`) · **tool-call grammar already Hermes-3-compatible**
(`function_call.rs` + `prompt_format.rs:66` + `LocalToolGrammar.swift`) · provider/
transport abstraction (`provider.rs:55`, `routing.rs`, Swift `RuntimeRouter`) · todo
(`tools/todo.rs` + `LocalAgentTodoCommand.swift`) · ReAct termination/tool-discipline ·
MEMORY.md/USER.md curation+budget (`tools/memory.rs:89` — *more* explicit than Hermes) ·
skills format + progressive disclosure (`tools/skills.rs` = agentskills.io Level-0/1) ·
delegation/sub-agents (`tools/delegate_task.rs:49` — runs on a Tokio task, NOT a process,
depth≤2).

## EXCLUDE — overlaps/conflicts with Osaurus or violates no-sidecar (D)

This is the owner's "don't overlap Osaurus" answer — these Hermes parts are NOT cloned:
- **Code/shell execution** (`execute_code` child-proc + Docker/SSH/Modal/Daytona/Singularity backends) → **Osaurus OWNS sandboxed exec** via its Apple Containerization Linux VM; would duplicate/conflict + violate no-subprocess. Code-exec = an Osaurus-VM `LocalAgentToolExecutor`, not a Hermes port.
- **MCP server/client** → **Osaurus is already a full MCP server+client** (OAuth2.1+DCR, ~25 providers); Epistemos also has `omega-mcp`+`MCPBridge.swift`. Pure duplication.
- **Gateway server** (Telegram/Discord/Slack/WhatsApp/Signal/Email ~20 platforms) → network/server surface; in-process doctrine; drive `LocalAgentLoop.run` directly.
- **`hermes_cli` TUI + Electron desktop** → UI bridge (the past failure); Act emits `AgentEvent` streams.
- **`cronjob` daemon** → Osaurus ships Schedules+Watchers; Epistemos has in-process scheduling.
- **Honcho dialectic user-modeling + network memory (Modal/Daytona)** → networked; the local vault + `epistemos-shadow` own memory. (The `USER.md` *file* is fine; the network *service* is not.)
- **Provider/transport layer** (`runtime_provider.py`, transports/) → two-way redundant (Epistemos `provider.rs`/`routing.rs` AND Osaurus's provider matrix).
- **Batch trajectory gen/compression for training** → out of agent-runtime scope.

## The Rust vs Swift split (crisp)

- **Rust `agent_core` (shared — both local brain + cloud loop):** skills, self-evolution, prompt-tier format, memory curation, session store + search tool (server side), provider routing, delegate subagent, todo.
- **Swift `LocalAgentLoop`/`LocalAgentPromptBuilder` (local orchestration only):** the turn loop + reflex streaming + MLX generation closure, the **summarizing compactor** (#2 — must be Swift; Rust's lives in the cloud-only loop), the prompt-builder mirror (#3 local half), thin tool-surfacing.
- **Forcing fact:** `agent_loop.rs:147 LocalProviderNotAllowed` rejects local providers → the rich Rust loop is cloud-only; local loop control stays Swift; Hermes *algorithms* go into `agent_runtime` (provider-agnostic, callable by both).

## Nothing on the Osaurus server lane — confirmed

`ActOsaurusGateStatus.swift`: MAS "Act stays on the in-process local-agent path"; `:1337`
inert until it clears no-hidden-fallback. Only Osaurus wire = `LocalAgentLoop` generation-
closure swap (`mlxGenerator`/`liveLoop`, ~`:111–238`) — replaces token serving, never the
brain. Every lifted capability attaches to brain modules ABOVE that closure. Honors the
ENGINE-ISOLATION DOCTRINE (connect via shared memory + capability registry, never shared
cross-engine logic).

## Ambiguities resolved (owner's "not sure if Osaurus or another part")

1. **Compaction (#2): Swift, not Rust** — local loop owns its history/budget and can't reach the cloud `agent_loop`; a Rust port needs a new provider-agnostic entry + per-turn FFI. Revisit a shared `summarize_window` only if cloud+local must produce identical summaries.
2. **session.search (#1): Rust handler, Swift index query** — schema/handler register in the Rust registry; the query dispatches to Swift `SearchIndexService.fusedSearch` (brain decides, Swift-owned tantivy/usearch executes). Don't duplicate a Rust search backend.
3. **RuntimeRouter ≠ Act picker** (collision risk): keep Hermes provider/transport inside `RuntimeRouter` (intra-local lane choice); the `.openClaw` vs `.osaurusLocal` decision stays in the Act dispatch (`ChatCoordinator`), or you create a forbidden 3rd route.

## Provenance
Record each of the 4 lifts as `HermesVendorProvenance { sourceRepo, license="MIT",
posture=clean_room, importedDate }` (mirror `OsaurusVendorProvenance`). **Quarantine
separately** (own licenses, must clear ProvenanceGate before any code enters product):
the agentskills.io SKILL.md spec + sibling repos `NousResearch/autonovel`,
`NousResearch/hermes-agent-self-evolution` (relevant to #1, #4).

Sources: github.com/NousResearch/hermes-agent (+ docs) · github.com/osaurus-ai/osaurus (+ docs.osaurus.ai). Supersedes the scope section of HERMES_ACT_FUSION_MAP_2026_06_19.md (which listed ~10 lifts before the Osaurus-overlap filter; the real set is these 4).
