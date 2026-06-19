# DEEP-RESEARCH ENGINE — real vs planned (S15, 2026-06-19)

Read-only research (subagent), code-grounded. Feeds DEEP_PLAN_AUDIT_HUB. **Unlike most slices, this
one is genuinely WIRED end-to-end** — the keystone "built-not-wired" does NOT apply; the honesty
flags are narrower.

## What exists today (real, end-to-end)
**The deep-research button is REAL + fully wired (unbroken path):** `ChatInputBar.deepResearchButton:1560`
→ `submitDeepResearch:1573` → `ChatView:323` → `ChatCoordinator.runDeepResearch:3262` → `DeepResearchService.run`
→ FFI `runDeepResearchSession` (`DeepResearchBridge.swift:147`) → Rust `run_deep_research` (`deep_research/run.rs:107`).
Button renders only when `onDeepResearch != nil && DeepResearchGateStatus.isActive` (honestly hidden by default).
**MULTI-agent (not single):** a real 5-stage DeerFlow-shaped Rust pipeline — **Planner** (typed `ResearchPlan` +
`SubQuestion` `depends_on` DAG, `parse_plan` rejects malformed/cyclic) → **Orchestrator** (`execution_layers()`
dependency-ordered concurrent batches `futures::buffered(cap)`, `max_concurrency` default 3 for M2-Pro-16GB,
concurrency-tested) → **Researcher** = `LiveSubAgentResearcher` (REAL — each sub-question runs its OWN isolated
`agent_core` loop w/ fresh session, isolated history, shared registry, web on, reusing `delegate_task::SilentDelegate`;
injects ONLY `depends_on` prior findings) → **Reporter** (`run_synthesis` final lead turn over `findings_digest`,
web OFF, Effort::High). Live planner/researcher/synthesis `#[cfg(pro-build)]`; the substrate (plan/validation/
layering/prompts/digests) always-compiled + unit-tested (incl. MAS). **DeerFlow NOT ported — natively re-implemented
in Rust** (zero Python/LangGraph; verdict doc `RESEARCH_DEERFLOW_2026_06_18.md`). Surfaces: `DeepResearchHealthRow`
in SubstrateHealthPanel; gate/renderer/entry-point Swift-tested.

## DeerFlow (ByteDance, MIT)
Python 3.12 + LangChain/LangGraph + React + Docker. v2.0 (Mar-2026 rewrite, ~47k stars) = SuperAgent harness
(Coordinator/Planner/Researcher/Coder/Reporter + dynamic sub-agents + memory/fs/skills/sandbox). **ADOPT (done):**
the decompose→parallel-isolated-sub-agents→synthesize-with-citations pattern + filesystem-first artifacts + phase
summarization — correctly mapped onto Epistemos's own substrate. **DO NOT PORT (correctly avoided):** the Python/
LangGraph runtime + Docker sandbox + React UI (NO-HIDDEN-SIDECAR). App-native-by-embedding done right: capability
in-process Rust, none of DeerFlow's runtime crosses the boundary. (MIT → no ProvenanceGate quarantine needed.)

## Composition with the moats
- **Engine-isolation (S17): clean** — `runDeepResearch` is a SEPARATE path from `handleQuery`, never touches Act/Work;
  the FFI inner registry deliberately EXCLUDES `delegate_task` from sub-agents ("these ARE the sub-agents; nesting is
  intentionally off") — no recursive fan-out. The 3rd leg alongside Osaurus(Act)/Goose(Work).
- **Provenance moat (S19): ⚠️ HONESTY GAP.** Citations today are **`[sub-question-id]` references, NOT source-grounded
  claims.** The renderer's "Sources" lists sub-questions + raw findings — it does NOT query the ClaimLedger, emit Eidos
  closed-citations, or carry source URLs as structured provenance. The module header's "+ Eidos citations / RRF retrieval"
  is **ASPIRATIONAL** (grep: zero `ClaimLedger`/`eidos::`/`rrf` calls in `deep_research/`). Same synthetic-citation pattern
  S19 flagged for AnswerPacket: citation is prompt-enforced ("cite [id]"), not ledger-verified.

## Real-vs-aspirational
✅ REAL: button wired E2E + honestly gated; multi-agent planner→parallel→synthesis; `LiveSubAgentResearcher` (Pro);
parallel concurrency + DAG layering (tested); plan validation (cyclic/dup/unknown-dep, tested).
➖ PARTIAL: local-vault research — sub-agent registry is Agent-tier (vault tools present) but the path is WEB-FIRST
(`enable_web_search:true`), not RRF/Eidos-driven; no vault-only mode.
❌ ASPIRATIONAL/MISNOMER: "+ Eidos citations / closed-citation / RRF grounding" (comments claim it, code has none;
`[id]`≠verified claim; no source URLs in provenance). Filesystem artifact offload per sub-agent NOT built (`SubResult`
is in-memory `{id,findings}` only). `Views/Omega/ResearchRequestView` = ORPHANED STUB (`body{EmptyView()}`, "Retired",
0 callers — S6 confirmed, safe to prune).

## Gating + ordered plan
Gating (correct): TWO honest gates — `EPISTEMOS_DEEP_RESEARCH_V0=1` AND a recognized CLOUD provider (allowlist,
no hidden route), Pro-only (`#[cfg(pro-build)]`+`#if !EPISTEMOS_APP_STORE`). **Refinement:** the current gate conflates
"deep research" with "web/cloud." Honest split: a **local-vault research mode = MAS-eligible** (sub-agent restricted to
vault/RRF/Eidos retrieval, no web/cloud = a LOCAL capability); web research = Pro/network. Today only the latter exists.
1. **Fix the provenance misnomer (S19 alignment, ~M):** make `SubResult` carry structured sources (URLs/vault doc-ids),
   thread through `findings_digest`/renderer, resolve `[id]`→real `[source]`, wire synthesis into the ClaimLedger so
   "verified" is real not prompt-promised. **Highest-leverage honesty fix.**
2. **Prune `ResearchRequestView`** (in-pair per S6). Trivial.
3. **Local-vault research mode (MAS, ~L):** vault-only ToolConfig (web off, vault/RRF/Eidos on) so a sub-agent loop runs
   on a LOCAL model over the vault — makes deep-research MAS-eligible + delivers the local-agent-over-YOUR-vault moat (S5).
4. **Filesystem artifact offload (~M)** per the doc design (citation grounding + replay; feeds #1).
5. Optional: expose `deep_research` as an agent TOOL (not only an FFI session) so a chat can decide to invoke it (no
   `deep_research` tool in `tools/` today).
**Net:** the engine is DONE + shippable (flip the flag on a Pro build); remaining = provenance honesty (#1) + MAS local
mode (#3). Correct the module-header misnomers to match code or back them with #1.

Key files: `agent_core/src/deep_research/{mod,planner,orchestrator,researcher,reporter,run}.rs` · `bridge.rs:1067-1213` ·
`Bridge/DeepResearchBridge.swift` · `App/ChatCoordinator.swift:3262` · `Views/Chat/ChatInputBar.swift:1546-1576` ·
`Engine/{DeepResearchGateStatus,DeepResearchReport}.swift` · `Views/Omega/ResearchRequestView.swift` (orphan) ·
`docs/RESEARCH_DEERFLOW_2026_06_18.md`. Sources: github.com/bytedance/deer-flow (MIT), MarkTechPost, DeerFlow 2.0 coverage.
