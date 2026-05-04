# AI_STACK_FUSION.md — The Canonical AI-Stack Reference

> **Authored**: 2026-04-27 by consolidation pass (cluster fusion of 4 source docs).
> **Sources fused** (originals untouched in `docs/`):
>   - `ai_stack_decision_report.md` — what got removed (DeepSeek, prepared reasoner) and why
>   - `ai_stack_implementation_plan.md` — Phases 0 → 5 status with file refs
>   - `ai_stack_phase_audit_log.md` — phase-by-phase audit checkpoint log
>   - `ai_stack_risks.md` — 5-item risk register + rollout gate
> **Role**: single canonical reference for the AI stack — the live model contract, runtime map, phase status, and risk register. **No nuance lost** — every claim from source docs preserved, with attribution.

---

## §1 — The locked stack (current truth)

Epistemos's AI stack now consists of:

1. **Apple Intelligence** for the lightest native tasks (graph summaries, simple synthesis)
2. **One in-process Qwen local text lane** for chat, synthesis, routing-adjacent work
3. **Swift-owned query embeddings** feeding **Rust prepared retrieval store/search path**
4. **Rust similarity scoring** for prepared retrieval candidate rescoring
5. **In-process local serving** as the default boot path for Qwen

Source: `ai_stack_decision_report.md §"Current Truth"`.

---

## §2 — What was removed and why

The previous heavy-reasoner split (DeepSeek + Qwen + router) created the wrong tradeoff for the 16 GB / 18 GB unified-memory target. **DeepSeek is gone**, and **the prepared reasoner role is gone** from the live manifest. Reasons (per `ai_stack_decision_report §"Why DeepSeek Was Removed"`):

- too much unified-memory pressure
- unstable optional worker startup and health behavior
- extra routing complexity before deterministic orchestration existed
- more stale UI/state than product value

**The app is easier to stabilize with one real local text model than with a router-plus-reasoner split that was not operationally solid.**

---

## §3 — Five locked decisions (non-negotiable until new phase)

From `ai_stack_decision_report §"Decisions Locked"`:

1. **No DeepSeek runtime path.**
2. **No prepared reasoner role** in the live manifest.
3. **No UI** that implies a separate heavy reasoner exists.
4. **No fake router, reranker, or experimental MoE role** in the live prepared-model contract.
5. **No tool-calling contract** until a later phase explicitly introduces it.

---

## §4 — Current runtime map

```text
User
  -> SwiftUI views
  -> @Observable state
  -> PipelineService / TriageService
  -> Apple Intelligence OR local Qwen
  -> MLXInferenceService by default

Retrieval
  -> QueryRuntime / SearchIndexService / GraphState
  -> GRDB FTS + Rust graph search + prepared retrieval runtime
  -> Swift query embeddings + Rust cosine-similarity scoring
```

Source: `ai_stack_decision_report.md §"Current Runtime Map"`.

**Locked behaviors during Phase 4.5+:**
- Graph summaries try **Apple Intelligence first**, fall back to **local Qwen**
- Graph **semantic clustering stays off** on the prepared runtime until the semantic vector space is fully unified

**Live prepared model role**: only `retriever_primary` (BGE-M3 asset slot). All other live prepared roles removed.

---

## §5 — Phase status (live)

From `ai_stack_implementation_plan.md`:

| Phase | Status | Audited | Notes |
|---|---|---|---|
| 0 — Decision Reset | ✅ complete | ✓ | DeepSeek lane removed from live target |
| 1 — Artifact Inventory | ✅ complete | ✓ | Local Qwen + retrieval assets remain; reasoner artifacts no longer part of plan |
| 2 — Local Runtime Boundary | ✅ complete | ✓ | Live app routes local generation through one in-process Qwen lane |
| 3 — Retrieval Upgrade | 🟡 partial | ✓ | Retrieval seams + index prep exist; **Rust-native BGE execution still missing** |
| 4 — Swift Orchestration Refactor | 🟡 partial | ✓ | Note/graph/local-model orchestration cleaner; retrieval handoff + latency hardening still open |
| **4.5 — Pre-Phase-5 Stabilization** | ✅ complete (Option B) | ✓ | Hot-path cleanup, UI streaming, residency guard, Rust prepared search + similarity reranking all in. **Native BGE + cross-encoder explicitly DEFERRED to unblock Phase 5.** |
| 5 — Structured Local Contract | ✅ complete | ✓ | Prepared retrieval is now truthfully retriever-only; similarity scoring named honestly; docs/manifests/tests no longer advertise removed live roles |

**Mandatory rule**: Phase 5 stays blocked until Phase 4.5 is fully closed and audited.

---

## §6 — What Phase 4.5 closed (10 items)

From `ai_stack_implementation_plan §"What 4.5 Already Closed"`:

1. BTK query results no longer cross the FFI boundary as newline-split strings
2. QueryRuntime no longer uses worst full-universe allocation paths
3. Frame-paced UI token delivery exists
4. First residency/memory guard exists
5. Semantic retrieval no longer lies about fallback behavior
6. Plain chat auto-resolves clearly referenced note requests without `@` syntax (high title/search confidence)
7. DeepSeek/reasoner runtime routing removed
8. Optional sidecar/worker routing removed from live app
9. Qwen is the only live local text path; boots in-process by default
10. Graph inspector summaries prefer Apple Intelligence before local Qwen fallback

---

## §7 — 4.5E retrieval-runtime closure (Option B; deferred parts)

Primary files: `EmbeddingService.swift`, `GraphState.swift`, `QueryRuntime.swift`, `graph-engine/src/embedding.rs`, `graph-engine/src/lib.rs`.

**Deferred** (intentionally — prevents abandoning MLX Apple Silicon unified memory advantages + bloating graph-engine FFI with massive inference dependencies):
1. ~~BGE query runtime execution moves into Rust~~ — DEFERRED
2. ~~Reranking becomes a real cross-encoder runtime path~~ — DEFERRED

**Required outcomes (still active):**
3. Swift Apple embeddings remain fallback-only and never masquerade as prepared retrieval
4. Retrieval asset readiness and rebuild policy are explicit end-to-end

**Already landed in this slice (10 items):**
1. Built retrieval indexes load into Rust engine as a real runtime store
2. Prepared semantic search executes against that Rust store (not pending-runtime placeholder)
3. Prepared retrieval state reports `preparedIndexReady` instead of pretending runtime is missing
4. Prepared retrieval reranking scores candidate page IDs inside Rust (similarity-based rescoring, not final cross-encoder)
5. Xcode tracks `retrieval_index.rs` as a real Rust build input
6. Retrieval asset readiness exposes explicit failure states (`missing` / `invalid` / `stale` / `ready`)
7. Graph semantic clustering stays disabled on prepared runtime until vector space is unified
8. Prepared retrieval runtime configuration refreshes on app activation (no relaunch needed)
9. Prepared semantic search + similarity reranking reuse cached prepared-index load boundary
10. Prepared retrieval cache invalidation keys on manifest content (not just manifest path)

---

## §8 — 4.5F runtime hardening (complete)

Primary files: `LLMService.swift`, `MLXInferenceService.swift`, `AppBootstrap.swift`.

Outcomes:
1. Local Qwen path remains stable under repeated warm/cold transitions
2. Memory/residency policy is tightened for the 18 GB target

---

## §9 — Phase 5 (Structured Local Contract) — what closed

From `ai_stack_implementation_plan §"What Phase 5 Closed"`:

Primary files: `LocalModelInfrastructure.swift`, `QueryRuntime.swift`, `QueryEngine.swift`, `model_manifest.json`, `scripts/models/build_retrieval_index.py`.

**What landed:**
1. `PreparedModelRole` exposes only the live `retriever` role
2. Prepared retrieval configuration + execution mode are retriever-only
3. Query runtime talks about *scoring* (not pretending a reranker exists)
4. Prepared model manifest no longer carries router/reranker/experimental MoE entries
5. Retrieval build scripts no longer advertise a removed reranker model ID or router prep flow
6. Focused runtime/pipeline/infrastructure tests compile + pass against the stricter contract

**Exit criteria (all met):**
1. No live boot or query path references removed prepared roles
2. No docs/manifests/helper scripts advertise removed live roles
3. Tests pass without weakening assertions

---

## §10 — Exit criteria for Phase 4.5 (Option B Modified) — Phase 5 unlock gate

Phase 5 could start (and did) only when all true:

1. ✅ Retrieval runtime handles prepared index cleanly (query vector generation stays in Swift MLX)
2. ✅ Remaining local Qwen path is operationally stable
3. ✅ Streaming stays smooth under sustained local output
4. ✅ Docs/manifests/tests no longer advertise removed reasoner behavior

---

## §11 — Risk register (5 items; from `ai_stack_risks.md`)

| # | Risk | Severity | Why |
|---|---|---|---|
| 1 | **Future retrieval overreach** | Critical | Later phases could overclaim native Rust ML support before dependency/runtime story justified. Swift-owned query embeddings are an *intentional boundary*, not a bug. |
| 2 | **Single-lane local runtime pressure** | High | The remaining Qwen lane needs continued readiness + residency discipline. 18 GB target has little room for sloppy load/unload policy. |
| 3 | **Streaming smoothness regression** | High | Local generation is one of the heaviest visible app paths. Any per-token UI churn shows up immediately as hitching. |
| 4 | **Manifest/runtime drift** | Medium-high | Stale manifest claims were a major source of earlier routing confusion. Model registry truth must match real runtime behavior. |
| 5 | **Experimental scope creep** | Medium | MoE + advanced orchestration are tempting distractions. Retrieval/runtime closure is the real blocker. |

---

## §12 — Rollout gate (current rule, post-Phase-5)

From `ai_stack_risks.md §"Rollout Gate"`:

Phase 4.5 satisfied the gate before Phase 5 started:
1. ✅ Retrieval runtime closure is real
2. ✅ Runtime/model selection is honest
3. ✅ Remaining local text lane is operationally stable
4. ✅ Docs/manifests/tests all match live architecture

**Current rule** (binding): **Do not reintroduce removed prepared roles or hidden extra local lanes without a new explicit phase and audit.**

---

## §13 — What must NOT be built yet (binding from `ai_stack_implementation_plan §"What Must Not Be Built Yet"`)

- ❌ Strict tool-calling
- ❌ OpenClaw-style orchestration loops
- ❌ Another heavy local reasoner
- ❌ MoE auto-routing

These are gated to phases that haven't started.

---

## §14 — Cross-references

- **MASTER_FUSION.md §6.3 (Dual-Backend Inference)** — WS1 17-model expansion (Phase 2/3 deliverable; doesn't conflict with current 1-Qwen lane)
- **MASTER_FUSION.md §6.5 (Cloud Integration)** — WS3 cloud APIs (Anthropic/OpenAI) are separate from the local stack
- **PLAN_V2.md §17** — phase roadmap puts compute steering in Phase 2 (post AI stack stabilization)
- **EPISTEMOS_MOAT_AND_OPTIMIZATION_MASTER.md §2.18** — honest capability gating (this fusion's locked decisions #2-#5 are the gating discipline)

---

## §15 — Provenance

This fusion preserves every claim from the 4 source docs at:
- `docs/ai_stack_decision_report.md` (52 lines) — kept as original; banner CANONICAL-OPERATIONAL
- `docs/ai_stack_implementation_plan.md` (141 lines) — kept; banner CANONICAL-OPERATIONAL
- `docs/ai_stack_phase_audit_log.md` — kept; banner CANONICAL-OPERATIONAL
- `docs/ai_stack_risks.md` (65 lines) — kept; banner CANONICAL-OPERATIONAL

When this fusion and any source doc disagree: **the source wins**. This is a navigation layer.

---

**END OF AI_STACK_FUSION.md**
