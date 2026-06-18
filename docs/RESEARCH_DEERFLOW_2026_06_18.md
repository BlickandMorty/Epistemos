# R-DEERFLOW verdict — ByteDance deer-flow vs Epistemos (2026-06-18)

**Verdict: PATTERNS-ONLY but a REAL GAP found (unlike R-JSONRENDER/R-LITELLM-CP
which were parity+). DeerFlow's multi-agent deep-research ORCHESTRATION (planner
→ parallel sub-agent fanout → synthesis) is a genuine capability Epistemos lacks.
BUILD IT NATIVELY IN RUST (agent_core), NOT a Python/LangGraph port (NO-SIDECAR).
This is a MAJOR workstream needing owner go-ahead — flagged, not greenfielded.**

## What DeerFlow is
ByteDance's deep-research agent. Stack: Python 3.12 + LangChain/LangGraph + React
+ Docker sandbox. Core loop: a LEAD agent DECOMPOSES a question into sub-questions
→ spawns task-specific SUB-AGENTS that run IN PARALLEL with isolated contexts →
each reports structured results → the lead SYNTHESIZES into a coherent,
citation-grounded output. Aggressive context offloading to filesystem +
summarization between phases. Tools: web search/crawl, file ops, bash, MCP,
SKILL.md skills, report/slide generation.

## Side-by-side vs Epistemos

| DeerFlow pattern | Epistemos today | Gap? |
|---|---|---|
| **Planner: decompose question → sub-questions** | agent_core loop is single-agent (one objective, sequential turns); RESEARCH PromptMode exists but no decomposition planner | ❌ **GAP** |
| **Parallel sub-agent fanout (isolated contexts)** | single-agent loop; no in-app sub-agent spawn/parallel-merge | ❌ **GAP** |
| **Lead synthesizes sub-agent results** | no synthesis-of-parallel-results stage | ❌ **GAP** |
| Summarization between phases | `compaction.rs` (proactive + reactive compaction) | ✅ matched (reusable) |
| Structured tool outputs validated before next model call | P8.1 schema gate validates tool INPUTS; OUTPUT validation is partial | ➖ partial (inputs ✅) |
| Filesystem-first artifacts | vault + ScratchVault + file tools | ✅ matched (reusable) |
| Persistent session memory | `session.rs` + procedural memory + vault 5-tier | ✅ matched (reusable) |
| Tools: web/crawl/file/bash/MCP/skills | all present (web_search, web_fetch, file_ops, bash, mcp, skills) | ✅ matched (reusable) |
| Report/slide generation skills | partial (notes/Epdoc; no slide gen) | ➖ minor |

## The real gap: multi-agent deep-research orchestration
Epistemos has EVERY supporting piece (tools, memory, compaction, schema gate,
skills, filesystem artifacts) but NOT the orchestration LAYER that turns them into
deep research: a planner that decomposes, parallel sub-agent execution with
isolated contexts, and a synthesis stage. The agent_core loop is single-agent.

This is the same capability the owner references as "the deep-research (DeerFlow)
stack" (ledger R-ASSISTANTS) and overlaps the deferred V2.7 multi-agent ACS.

## Native build path (NOT a port) — for owner go-ahead
Build a `deep_research` orchestration in agent_core (Rust), reusing the existing
substrate:
- **Planner**: one agent_core turn that emits a typed `ResearchPlan` (sub-questions
  + dependencies), validated by the P8.1 schema gate.
- **Parallel sub-agents**: run N agent_core loops concurrently (one per
  sub-question), each with its OWN isolated message history + the shared tool
  registry; cap concurrency (M2 Pro 16GB — small N).
- **Context offload + summarize**: each sub-agent's result is compacted
  (compaction.rs) + written as a filesystem artifact (vault/scratch) for
  citation grounding.
- **Synthesis**: a final lead turn reads the sub-agent artifacts + synthesizes
  with citations (Eidos closed-citation gate for grounding).
- Gate behind a flag + a Research/Work mode; single-agent stays the default.
- MAS/Pro: parallel sub-agents are in-process Rust (no sidecar) → MAS-safe;
  Docker sandbox = Pro-only (don't need it for the core loop).

## Why not port
Python/LangGraph/Docker + React. NO-SIDECAR forbids the Python runtime. The
orchestration is portable as a PATTERN — build it on agent_core's existing loop +
tools + compaction + schema gate + Eidos citations. No code lifted.

## Recommendation
1. Close R-DEERFLOW (researched; pattern understood).
2. The multi-agent deep-research orchestration is a REAL, owner-relevant gap —
   propose it as a scoped major workstream (native Rust, flag-gated, reuses the
   substrate above). Needs owner go-ahead before build (canon: no candidate
   build without sign-off). Pairs with the Osaurus (ACT) + Goose (WORK) imports
   as the third leg — deep research as a Research/Work capability.
