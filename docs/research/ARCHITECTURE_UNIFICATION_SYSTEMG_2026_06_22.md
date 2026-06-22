# Architecture Unification — System G / agent_loop / agent_runtime / brain (2026-06-22)

**Question (owner):** Are these five things — (1) **System G** (`agent_core/src/agent_runtime_v2/`),
(2) the **agent loop** (`agent_core/src/agent_loop.rs`), (3) **agent_runtime** (`agent_core/src/agent_runtime/`,
renamed-from-hermes), (4) **agent_core** as a whole, (5) the owner's **IP brain** (Eidos/recall, cognitive_dag,
provenance, honesty gating, LocalAgent/* prompt builder + loop, RuntimeRouter) — overlapping/duplicated, and
should they be UNIFIED into one architecture, or kept separate?

**Scope authority:** PLAN_V2 is authority; fix code to match plan, never the reverse. This is a research/spec
artifact. Do NOT commit. Anti-hallucination: every claim below is grounded in code read this session and labeled
**[V]** VERIFIED (read the file:line) or **[I]** INFERRED (reasoned from verified facts).

---

## 0. TL;DR verdict

**Mostly UNIFY — but they are LAYERS, not duplicates.** The confusion is real but the components are not five
competing copies of the same thing. There are exactly **two legitimate "loops" plus one orchestrator-in-progress**,
**one runtime library**, and **one brain that is currently fragmented across 4 disconnected attach points**.

- **MERGE / converge:** the orchestration story → **System G (`agent_runtime_v2`) is the orchestrator of record**;
  the **TRINITY loop** (`trinity_loop.rs`, born today) is its native coordinator core; **RuntimeRouter** (Swift,
  observe-only) becomes System G's per-subtask model-selection policy. These three are one thing being built in
  slices — converge them, don't keep them parallel.
- **KEEP SEPARATE (by design):** `agent_loop.rs` (the **cloud streaming engine**, local-rejecting) and the Swift
  `LocalAgentLoop` (the **local reflex engine**) are two legitimately-different *execution engines* — cloud SSE vs
  local MLX grammar-tool-calling. They should become **two swappable lanes UNDER the one System G orchestrator**,
  not two top-level orchestrators. `agent_runtime/` is a **shared support library** (prompt-format/tool-parse/
  skills/procedural-memory) that both lanes use — keep it, it's not a loop.
- **UNIFY the brain (the real prize):** the IP brain (Eidos / cognitive_dag / provenance / honesty) is built and
  tested but **NOT wired into the live decision path** — it is split across 4 disconnected paths (see §3). The
  unification win is **one brain attach point on top of the one orchestrator**, replacing the current fragmentation.
- **DELETE / fix dead code:** `confidence_floor.rs` is **fully orphaned (zero consumers)** [V]; `ConfidenceRouter.swift`
  is **test-only legacy** [V]; the `eidos.query` agent tool **bypasses the `eidos/` module entirely** [V] (brain-in-
  name-only). These are the concrete "muddiness" to clean up.

**One-line answer to the owner:** *Unify the ORCHESTRATION (System G + TRINITY + RuntimeRouter = one brain-on-top)
and unify the BRAIN onto it; keep the cloud engine and the local engine as two swappable lanes under it; the
"five things" are really `agent_core` (the crate) ⊃ {one orchestrator, two engine-lanes, one support lib, one brain}
— a layered stack, not five rivals.*

---

## 1. What each component actually is (per-component map, cited)

### 1.1 `agent_core` (the crate) — the container, not a peer
- **[V]** `agent_core/src/lib.rs:3-80` declares all of these as sibling modules of ONE crate: `agent_loop` (`:3`),
  `agent_runtime` (`:4`), `agent_runtime_v2` (`:5`), `cognitive_dag` (`:22`), `command_center` (`:24`),
  `confidence_floor` (`:26`), `eidos` (`:32`), `provenance` (`:59`), `research` (`:69`), `routing` (`:80`).
- **So "agent_core vs System G vs agent_loop" is a category error:** agent_core is the Rust crate; the other four
  are modules *inside* it. The unification question is really about the modules' relationships, not agent_core.

### 1.2 `agent_loop.rs` — the CLOUD streaming engine (LIVE, primary today)
- **[V]** `pub async fn run_agent_loop(session_id, objective, provider, tool_registry, delegate, config, cancel)
  -> Result<AgentResult, AgentError>` — `agent_loop.rs:151`. Real SSE streaming, parallel/sequential tool
  execution (`:803`/`:829`), `SmartApproval` (`:204`), budget gating (`:449`/`:1241`), `DEFAULT_AGENT_MAX_TURNS=25`
  (`:62`). Loop body `:276`, `provider.stream_message(...)` `:326`.
- **[V] Cloud-only by hard guard:** `AgentError::LocalProviderNotAllowed` (`:147-148`); the guard at `:166-171`
  returns it whenever `provider.runtime() == ProviderRuntime::Local`. Only `GgufCliProvider` is `Local`
  (`gguf_cli.rs:470-472`); all of Claude/Perplexity/Gemini/OpenAI-compat pass (`provider.rs:73-74` defaults Cloud).
- **Status: LIVE.** Callers **[V]**: FFI `run_agent_session` (`bridge.rs:938→1069` via `run_agent_session_inner`
  `:986` + `resolve_provider_for_session` `:599-662`); `tools/delegate_task.rs:173`; `deep_research/*`.
- **Responsibility:** the cloud agentic execution engine. NOT an orchestrator-of-models — it runs ONE provider.

### 1.3 `agent_runtime_v2/` — System G / Invader Agent — the ORCHESTRATOR of record (WIRED, V1-stub, MAS-gated)
- **[V]** `mod.rs:1-39`: "System G / Invader Agent" (name `Aegis` REJECTED). Canonical flow:
  `AgentBlueprint → MissionPacket → AgentEvent stream → approval → MutationEnvelope → RunEventLog → AnswerPacket`
  (`mod.rs:19-21`). Doctrine: `docs/AGENT_RUNTIME_V2_SYSTEM_G_DOCTRINE_2026_05_18.md` (exists [V]).
- **[V]** `system_g_runtime.rs` public API: `start_run(mission_json)` (`:447`),
  `start_run_with_provider_policy(...)` (`:464`), `drain_events(run_id)` (`:486`), registry stats (`:504`/`:518`).
  `execute_v1_dispatch` (`:219`) builds a `MissionRun`, debits a `BudgetSpec`, calls `run.finalize(...) -> AnswerPacket`.
- **[V] It is a run REGISTRY + deterministic V1 event synthesizer, not yet a real streaming loop:** the V1 path
  emits a 3-event turn (plan_start → token_chunk → complete); the comment at `:213-218` says real streaming
  "swaps the middle event." **[I]** Real provider streaming + approval/MutationEnvelope are not yet wired into V1.
- **[V] Gating:** `AgentRuntimeV2Mode::mas_default()=Disabled`, `pro_default()=IpcBounded` (`mode.rs:56-63`);
  `Disabled.allows_execution()==false`. FFI `system_g_runtime_status_json` (`bridge.rs:4925`) picks mode by build
  feature. NOTE **[V]**: the `start_run`/`drain_events` FFIs (`bridge.rs:4952`/`:4988`) do NOT themselves check
  the mode gate — mode is a status read; the dispatch is V1-deterministic.
- **[V]** `ProviderPolicy` (`blueprint.rs:39`): `LocalMlx` (`:40`), `LocalGguf` (`:43`), `AnthropicMessages`
  (`:46`), `OpenAICompatible{base_url,model}` (`:52`) — already the "team of models" binding surface. Cloud
  policies currently fail closed (`provider_not_bound`).
- **[V]** `trinity_loop.rs` (NEW, today): `run_trinity_loop(objective, max_rounds, exec)` (`:96`), flat ≤5-round
  Thinker→Worker→Verifier over an injected `TrinityRoleExecutor` (`:84`), JSONL trace events (`:58`), role indices
  `0=Worker,1=Thinker,2=Verifier` (`:26`) matching the trinity_coordinator reference.
  **Status: DEFINED + unit-tested, NOT invoked anywhere** [V] — grep finds only `pub mod trinity_loop;` (`mod.rs:59`);
  no caller, no FFI, no `TrinityRoleExecutor` impl in product code. Slice 1 of the planned native port.
- **Swift seam [V]:** `Epistemos/SystemG/{SystemGRunSeam,RealSystemGRunSeam,SystemGWiring}.swift`.
- **Responsibility:** the orchestrator — plan a mission, fan out across a provider pool, emit a provenance-carrying
  AnswerPacket. This is where TRINITY + RuntimeRouter + the brain are MEANT to converge.

### 1.4 `agent_runtime/` — the in-process support LIBRARY (LIVE, not a loop)
- **[V]** `mod.rs:1-14`: renamed from `hermes` 2026-05-05; "owns prompt formatting, function-call parsing, skills,
  procedural memory, self-evolution." Submodules: `prompt_format.rs` (`build_system_prompt`, Hermes-3 grammar),
  `function_call.rs` (`parse_tool_calls`), `skills.rs`, `procedural_memory.rs`, `self_evolution.rs`.
- **Status: LIVE support lib (not orphaned).** Callers **[V]**: `bridge.rs` skills FFIs + `prompt_format::
  build_system_prompt` (`:2761`) + `function_call::parse_tool_calls` (`:2774`) + `procedural_memory` (`:3134`);
  `dispatcher.rs`, `context_loader.rs`, `tools/registry.rs:1646/1663`, `cognitive_dag/dispatch.rs:246`.
- **Responsibility:** shared primitives both the cloud lane and the local lane consume. **It is NOT a loop** — it
  is the toolbox the loops call. (`self_evolution` is the least-exercised submodule — **[I]** internal/low-traffic.)

### 1.5 The IP brain — built, tested, FRAGMENTED across 4 paths (see §3 for full detail)
- **[V]** `eidos/` = closed-citation retrieval organ (`retriever.rs:35-51` `EidosRetriever` trait, 9 modes, RRF k=60).
- **[V]** `cognitive_dag/` = content-addressed typed graph (10 NodeKind/10 EdgeKind, Merkle, macaroons, resonance).
- **[V]** `provenance/` = `ClaimLedger` (retraction propagation, depth ≤16) + `ReplayBundle` (.epbundle).
- **[V]** `confidence_floor.rs` = tiered confidence-floor kernel (`decide_floor` T1≥0.85/T2≥0.75/T3≥0.70).
- **[V]** Swift: `LocalAgent/LocalAgentPromptBuilder.swift` (canonical local prompt) + `LocalAgentLoop.swift`
  (local reflex loop) + `RuntimeRouter.swift` (observe-only lane chooser).

### 1.6 Swift local engine — `LocalAgentLoop` (LIVE) + routing layers
- **[V]** `LocalAgentLoop.liveLoop(...)` (`LocalAgentLoop.swift:225`) is the production local reflex tool-calling
  loop, driving MLX via `LocalConfigurableLLMClient`. Live callers: `ChatCoordinator.swift:1174` (main chat),
  `PipelineService.swift:748`, `IMessageDriverService.swift:1296`, `DeviceAgentService.swift:394`.
- **[V] Two parallel LOCAL chokepoints** (prior research confirmed): (1) `LocalAgentLoop.liveLoop` (main/Mini/
  Pipeline/iMessage) and (2) `TriageService.localStreamOrFallback`/`localGenerateOrFallback` (Note + Graph chat,
  `TriageService.swift:1253/1448/1505`); the split is named at `TriageService.swift:2328`. They are unified for
  the act=Osaurus swap by `SharedActInference` (`SharedActInference.swift:3-9`).
- **[V] Terminal engine:** `MLXInferenceService.generate/stream` (`MLXInferenceService.swift:1625/1751`) — the
  actual local MLX engine both chokepoints drive.

---

## 2. Overlap / divergence analysis

### 2.1 Are there 2+ parallel orchestration/loop paths? YES — and that is the core of the muddiness.

| # | Path | What | Status | Invoked from |
|---|------|------|--------|--------------|
| 1 | **`run_agent_loop`** (`agent_loop.rs:151`) | Cloud SSE streaming engine, 1 provider, cloud-only | **LIVE** | FFI `run_agent_session` `bridge.rs:1069`; delegate_task; deep_research |
| 2 | **System G `start_run`** (`system_g_runtime.rs:447`) | Orchestrator run-registry, V1 deterministic events | **WIRED to FFI, V1-stub, MAS-Disabled** | FFI `bridge.rs:4952/4968` |
| 3 | **`run_trinity_loop`** (`trinity_loop.rs:96`) | Flat ≤5-round T/W/V coordinator core | **DEFINED, NOT invoked (slice 1)** | nowhere yet |
| 4 | **`LocalAgentLoop.liveLoop`** (Swift `:225`) | Local MLX reflex tool-calling loop | **LIVE** | ChatCoordinator/Pipeline/iMessage/DeviceAgent |
| 5 | **`TriageService.localStream…`** (Swift) | 2nd local chokepoint (Note/Graph chat) | **LIVE** | Note + Graph chat surfaces |
| — | `compile_command_center_request` (`bridge.rs:1641`→`command_center.rs`) | request/catalog COMPILER, NOT a loop | LIVE (compiler) | feeds path #1/#4 |

**Routing-decision layers (3, Swift) [V]:** (a) Rust `compileCommandCenterRequest` FFI = the LIVE brain/lane/
tool-permission resolver (`CommandCenterRequestCompiler.swift:87/119`); (b) `TriageService.InferencePolicyEngine.
shouldAutoRouteToCloud` (`TriageService.swift:531`) = LIVE local-vs-cloud gate; (c) `RuntimeRouter.route`
(`RuntimeRouter.swift:600`) = **OBSERVE-ONLY shadow** of (a), gated `EPISTEMOS_RUNTIMEROUTER_LIVE_V0` default OFF,
zero live callers (`RuntimeRouterShadow.swift:3-9,31-33`). `ConfidenceRouter.route` = **test-only legacy**
(`ConfidenceRouter.swift:198-205`, its own comment).

### 2.2 Where each diverges (the legitimate vs illegitimate splits)

- **LEGITIMATE split — cloud vs local execution engine (#1 vs #4):** `agent_loop.rs` *cannot* run local (hard
  `LocalProviderNotAllowed` guard) and `LocalAgentLoop` is MLX-grammar-tool-calling that the cloud loop doesn't
  do. These are genuinely different execution mechanics. **Keep both — but as lanes under one orchestrator.**
- **ILLEGITIMATE divergence — two LOCAL chokepoints (#4 vs #5):** `LocalAgentLoop.liveLoop` and
  `TriageService.localStream…` are two code paths doing the same job for different chat surfaces. Prior research
  already flagged this; `SharedActInference` partially bridges the act-swap. **This should converge to one local
  lane** behind the orchestrator.
- **ILLEGITIMATE divergence — three routing layers (a/b/c):** the LIVE decision is split between the Rust
  command-center compiler (a) and the Swift Triage cloud-gate (b), while the purpose-built `RuntimeRouter` (c) is
  observe-only and dead. **This is the clearest "two parallel chokepoints" the owner intuited.** Converge to one
  router (promote RuntimeRouter to authority, fed by the Rust compile output).
- **NOT a divergence — System G (#2) vs agent_loop (#1):** these are at different altitudes. System G is the
  *orchestrator* (mission → fan-out → AnswerPacket); agent_loop is one *engine* it could call. The reason they
  *look* parallel today is System G's V1 path is a stub that doesn't yet call `run_agent_loop` for its cloud legs.
  **[I]** The convergence is: System G's `ProviderPolicy::OpenAICompatible/AnthropicMessages` legs execute *via*
  `run_agent_loop`, and its `LocalMlx` legs execute *via* the local lane.

### 2.3 Naming/doc drift found (worth correcting in CLAUDE.md)
- **[V]** CLAUDE.md says cognitive_dag macaroons are "orphan until Phase 8.H" and dispatch registers caps "on
  first use." **Both are STALE:** `dispatch::cognitive_dag_store()` eagerly registers 6 capability hashes at init
  (`dispatch.rs:66-71`), and macaroons are heavily consumed by `agent_runtime_v2/capability.rs:15` +
  `envelope.rs:29` (module-level, non-test). The DAG auto-mirrors on every legacy write
  (`provenance/ledger.rs:581/646`, `skill_router.rs:81`, `agent_runtime/procedural_memory.rs:93`).

---

## 3. Where the IP brain attaches — and why it is NOT unified

**The brain is built and tested but fragmented across FOUR disconnected paths. None of them is the live agent
decision path.** This is the single biggest unification opportunity.

| # | Brain path | What it is | Status [V] | Where |
|---|-----------|-----------|-----------|-------|
| 1 | `eidos/` module | the real closed-citation retriever + falsifier | **gated FFI scaffold, fixture-seeded** | FFI `eidos_*_json` `bridge.rs:3823-3979`; Swift `EidosBridge` flag-gated `EPISTEMOS_EIDOS_V0` **default OFF** (`ChatCoordinator.swift:4506`); citation gate `ChatCoordinator+EidosCitationGate.swift:62` has **ZERO callers** |
| 2 | `eidos.query` agent TOOL | what the model actually calls for recall | **LIVE — but BYPASSES the `eidos/` module** | `tools/knowledge.rs:244-296` calls `self.vault.hybrid_search_with_trace(...)` (VaultBackend/shadow index), tags `"backend":"vault_recall_trace"`. **Eidos-in-name-only.** |
| 3 | `cognitive_dag/` | typed provenance graph | **LIVE auto-mirror inside Rust; OBSERVE-ONLY from Swift** | mirror-writes on every legacy commit; FFI `cognitive_dag_stats_json` `bridge.rs:3677` is read-only; Swift `RustCognitiveDagClient` = health rows only |
| 4 | `provenance/` ledger | ClaimLedger + retraction propagation | **CLI-live (replay) + Swift observe-only; global ledger never written by a loop** | `epistemos_trace.rs:43`; FFI `provenance_ledger()` `bridge.rs:3446` is `.read()`-only (`:3463/3499/3528`); no loop calls `commit_*`/`retract_*` on the global ledger |
| 5 | `confidence_floor.rs` | tiered confidence kernel | **FULLY ORPHANED — zero consumers** | only `lib.rs:26` + its own tests; live "honesty gating" is the *separate* provider-capability refusal in `bridge.rs:625/1324/1340` + `provider.rs:44` |

**Headline [V]:** the agent's *actual* live recall is `VaultBackend.hybrid_search_with_trace` behind the
`eidos.query` tool — **not** the owner's signature `EidosRetriever`. The closed-citation contract, the
retraction-propagating ledger, and the confidence ladder are all built + falsifier-tested but **gated, observe-only,
or orphaned**. The brain is **DUPLICATED/fragmented, not unified.** Unifying it = wiring the *real* `eidos/`
retriever + ledger + (resurrected) confidence gate into the ONE orchestrator's decision path, and retiring the
shadow `eidos.query→VaultBackend` shortcut (or making it the eidos/ module's lexical backend).

---

## 4. THE UNIFICATION VERDICT (merge / keep-separate / delete + target architecture)

### 4.1 MERGE (converge into one)
1. **Orchestration → System G is the single orchestrator of record.** TRINITY (`trinity_loop.rs`) is its native
   coordinator core; wire `run_trinity_loop` into System G's executor (slice 2 per the port spec) so a mission
   runs Thinker/Worker/Verifier over the provider pool. *(Consistent with FUGU §6 + TRINITY_COORDINATOR_PORT_SPEC.)*
2. **Routing → one router.** Promote `RuntimeRouter` from observe-only to System G's per-subtask model-selection
   policy (staged gate `EPISTEMOS_RUNTIMEROUTER_LIVE_V0` → Stage-2 readiness ≥50 samples/≥98% parity, already
   built in `RuntimeRouterStage2Readiness.swift`). Retire the duplication between the Rust command-center compiler
   and the Swift Triage cloud-gate by making the compiler feed the one router.
3. **Local chokepoints → one local lane.** Converge `LocalAgentLoop.liveLoop` and `TriageService.localStream…`
   onto one local execution lane that the orchestrator calls (extend the `SharedActInference` seam into a full
   shared local-lane entry).
4. **Brain → one attach point.** Wire the real `eidos/` retriever + `provenance` ledger + (resurrected)
   `confidence_floor` into the one orchestrator as the layer that gates/cites/records every run — replacing the
   4-way fragmentation in §3.

### 4.2 KEEP SEPARATE (legitimate boundaries — do NOT collapse)
1. **Cloud engine (`agent_loop.rs`) vs local engine (`LocalAgentLoop`)** stay as **two swappable lanes UNDER**
   System G. They have genuinely different mechanics (SSE cloud vs MLX grammar local) and the honest-capability-
   gating rule depends on the split (`LocalProviderNotAllowed`). Unify the *orchestration above them*, not the
   engines themselves.
2. **`agent_runtime/` support library** stays a shared toolbox (prompt-format/tool-parse/skills/procedural-memory)
   that both lanes call. It is not a loop and should not be folded into one.
3. **System G MAS-Disabled / Pro-IpcBounded gating** stays — it is the correct safety posture; convergence happens
   behind the existing mode gate, never arming the gated 70B/subprocess path.

### 4.3 DELETE / FIX (the dead/muddy code)
1. **`confidence_floor.rs`** — either wire it into the brain attach point (§4.1.4) or delete it. Today it is
   compiled-but-dead. (Recommend: resurrect as the honesty-gate scalar, not delete — it is owner IP.)
2. **`ConfidenceRouter.swift`** — test-only legacy; once RuntimeRouter is live, delete or fold its diagnostics.
3. **`eidos.query → VaultBackend` shortcut** (`tools/knowledge.rs:244`) — either route it *through* the `eidos/`
   module (make VaultBackend the eidos/ lexical backend) or rename it honestly so it isn't "Eidos in name only."
4. **`ChatCoordinator+EidosCitationGate.swift:62`** — orphaned (zero callers); wire it into the run or remove it.
5. **CLAUDE.md staleness** — correct the "macaroons orphan / dispatch first-use" wording (§2.3).

### 4.4 Target unified architecture (diagram)

```
                          ┌────────────────────────────────────────────────┐
                          │            SYSTEM G  (agent_runtime_v2)          │
                          │              the ORCHESTRATOR of record          │
                          │   Blueprint → MissionPacket → AgentEvent →       │
                          │     approval → MutationEnvelope → RunEventLog →  │
                          │              AnswerPacket                        │
                          │                                                  │
                          │   ┌──────────────┐      ┌────────────────────┐  │
                          │   │ TRINITY loop │◄────►│  RuntimeRouter      │  │
                          │   │ (T/W/V core) │      │ (per-subtask model  │  │
                          │   │ trinity_loop │      │  selection, LIVE)   │  │
                          │   └──────┬───────┘      └────────────────────┘  │
                          └──────────┼─────────────────────────────────────┘
                                     │ fans out across the provider pool (ProviderPolicy)
              ┌──────────────────────┼───────────────────────────────┐
              ▼                      ▼                                ▼
      ┌───────────────┐      ┌────────────────┐              ┌────────────────┐
      │  CLOUD LANE   │      │   LOCAL LANE   │              │  GUEST LANES   │
      │ run_agent_loop│      │ LocalAgentLoop │              │ Osaurus(act),  │
      │ (SSE, cloud-  │      │ + MLX engine   │              │ OpenCode(work),│
      │  only)        │      │ (one chokepoint)│             │ Fugu(opt cloud)│
      └───────┬───────┘      └───────┬────────┘              └────────────────┘
              │                      │
              └──────────┬───────────┘  both call the shared support lib:
                         ▼
                ┌──────────────────────┐
                │   agent_runtime/      │  prompt_format · function_call ·
                │  (support library)    │  skills · procedural_memory · self_evolution
                └──────────────────────┘

   ╔══════════════════════════════════════════════════════════════════════════╗
   ║                THE BRAIN — ONE attach point on the orchestrator            ║
   ║  Eidos (closed-citation recall) · cognitive_dag (provenance graph) ·       ║
   ║  provenance ledger (retraction) · confidence_floor (honesty gate) ·        ║
   ║  prompts/persona — gates inputs, cites sources, records every run          ║
   ╚══════════════════════════════════════════════════════════════════════════╝
                         all of the above live INSIDE the `agent_core` crate
```

**This matches the existing plan directives:** ONE inference/orchestration chokepoint (System G), one brain on
top + swappable engines (cloud/local/guest lanes), TRINITY orchestrator as the coordinator — exactly the FUGU §6
"be our own Fugu, local-first" play and the ADOPT-vs-IP map (adopt engines, layer the brain).

---

## 5. PLAN ADDITIONS (paste-ready)

```
[UNIFY-0] DOCTRINE: agent_core = the crate; inside it = ONE orchestrator (System G),
  TWO swappable engine-lanes (cloud=agent_loop.rs, local=LocalAgentLoop), ONE shared
  support lib (agent_runtime/), ONE brain attach point. "Five things" is a layered
  stack, not five rivals. agent_loop.rs and LocalAgentLoop STAY SEPARATE as lanes;
  everything else converges onto System G.

[UNIFY-1] Wire run_trinity_loop (trinity_loop.rs:96) into System G's executor
  (TRINITY port slice 2): System G missions run Thinker/Worker/Verifier over the
  ProviderPolicy pool; cloud legs execute via run_agent_loop, local legs via the local
  lane. Behind the existing AgentRuntimeV2Mode gate (MAS Disabled / Pro IpcBounded).
  Accept: a multi-step System G run emits an AnswerPacket with a JSONL T/W/V trace.

[UNIFY-2] Promote RuntimeRouter to System G's per-subtask model-selection policy
  (staged: EPISTEMOS_RUNTIMEROUTER_LIVE_V0 → Stage-2 readiness ≥50 samples / ≥98%
  parity). Retire the Rust-compiler vs Swift-Triage routing duplication: the
  command-center compiler FEEDS the one router; TriageService.shouldAutoRouteToCloud
  becomes a RuntimeRouter lane rule, not a parallel decision.

[UNIFY-3] Converge the two LOCAL chokepoints (LocalAgentLoop.liveLoop +
  TriageService.localStream…) onto one shared local lane (extend SharedActInference
  into a full shared local-lane entry). Note/Graph/Mini/main chat all enter the same lane.

[UNIFY-4] Wire the REAL brain into the one orchestrator's decision path:
  - eidos/ retriever (not the VaultBackend shortcut) supplies closed-citation context;
  - provenance ClaimLedger.commit_*/retract_* is driven BY the run (not just CLI replay);
  - confidence_floor.decide_floor gates the answer (resurrect from orphan);
  - the "Retrieved by Eidos" panel + citation gate (ChatCoordinator+EidosCitationGate)
    get real callers.
  Accept: a live run produces an AnswerPacket whose citations are eidos source_ids,
  whose claims are in the ledger, and whose confidence passes the floor.

[UNIFY-5 / CLEANUP] (a) eidos.query tool routes THROUGH the eidos/ module (VaultBackend
  becomes the eidos/ lexical backend) or is renamed honestly. (b) confidence_floor.rs:
  wire (UNIFY-4) or delete. (c) ConfidenceRouter.swift: delete/fold once RuntimeRouter
  is live. (d) Fix CLAUDE.md stale "macaroons orphan / dispatch first-use" wording.

[UNIFY-6] DOC FIX: CLAUDE.md FILE MAP — note that agent_loop.rs is the CLOUD lane
  (local-rejecting) and System G is the orchestrator above it, so future agents don't
  read them as rival loops.
```

---

## 6. Sequencing (careful, additive/safe, AFTER current priorities)

This is a refactor of LIVE code — sequence it conservatively, behind the gates that already exist, after the
current P0 chat/model-selection priorities in the master queue.

1. **Now / cheap / safe (docs + dead code):** UNIFY-0, UNIFY-6 (doctrine + CLAUDE.md fixes), UNIFY-5d (stale
   wording). Zero behavior change.
2. **Already in flight:** UNIFY-1 (TRINITY slice 2) — `trinity_loop.rs` slice 1 just landed; this is the next
   slice, behind the MAS-Disabled gate. No live-path risk (System G is gated off on MAS).
3. **Staged + reversible:** UNIFY-2 (RuntimeRouter promotion) — the staging gate + parity readiness check are
   already built; flip only after ≥98% observed parity. Pure observe→authoritative promotion, reversible by flag.
4. **Medium refactor:** UNIFY-3 (local-chokepoint convergence) — extend SharedActInference; regression-test
   Note/Graph/Mini/main chat parity (this is the riskiest because both chokepoints are LIVE).
5. **The prize, gated:** UNIFY-4 (brain attach) — wire eidos/ledger/confidence into the run; do it behind the
   existing `EPISTEMOS_EIDOS_V0` flag first (observe), then enforce. UNIFY-5a/b/c cleanup follows once the real
   paths are live.

**Guardrails:** zero test regressions vs the 2,679-test suite; never arm the gated 70B/subprocess path; every step
behind an existing flag/mode; `cargo test --lib` as the fast gate, heavy xcodebuild at checkpoints only.

---

## 7. Open questions (owner decision)

1. **eidos.query backend:** make VaultBackend the eidos/ module's lexical backend (one retriever, two backends),
   or keep them separate and just rename the tool honestly? (Recommend: merge — one retriever.)
2. **confidence_floor:** resurrect as the live honesty-gate scalar (owner IP), or delete? (Recommend: resurrect.)
3. **RuntimeRouter vs command-center compiler authority:** which is the source of truth for routing once unified —
   the Rust compiler computing a verdict the Swift RuntimeRouter executes, or RuntimeRouter computing directly?
   (FUGU §6 implies RuntimeRouter is the policy; the compiler feeds it.)
4. **System G V1-stub → real:** is wiring `run_agent_loop` (cloud) + local lane into System G's executor in scope
   now, or does System G stay V1-deterministic until Pro arms it? (Sequencing assumes behind-the-gate now.)
5. **Fugu as a pool node (FUGU-A5) vs guest-lane only:** does Fugu ever become a node *inside* the orchestrator,
   or stay a single opt-in lane? (Prior recommendation: guest-lane only — don't rent the routing brain.)
6. **TriageService local-vs-cloud gate:** fold fully into RuntimeRouter (UNIFY-2), or keep as a coarse pre-filter?

---

## 8. Component status table (one-glance)

| Component | What | Status | Verdict |
|-----------|------|--------|---------|
| `agent_core` crate | container of all below | n/a | not a peer — the crate |
| `agent_loop.rs` | cloud SSE engine (local-rejecting) | **LIVE** | KEEP as cloud lane under System G |
| System G `agent_runtime_v2` | orchestrator (V1-stub, MAS-Disabled) | **WIRED/gated** | MAKE the one orchestrator |
| `trinity_loop.rs` | T/W/V coordinator core | **DEFINED, not invoked** | WIRE into System G (slice 2) |
| `agent_runtime/` | prompt/tool/skills support lib | **LIVE** | KEEP as shared lib |
| `LocalAgentLoop` (Swift) | local MLX reflex loop | **LIVE** | KEEP as local lane; converge with Triage |
| `RuntimeRouter` (Swift) | lane chooser | **observe-only, dead** | PROMOTE to the one router |
| `ConfidenceRouter` (Swift) | legacy router | **test-only** | DELETE/fold |
| `TriageService` local path | 2nd local chokepoint | **LIVE** | CONVERGE into local lane |
| `eidos/` module | closed-citation recall | **gated/fixture** | WIRE the real one into the run |
| `eidos.query` tool | VaultBackend shortcut | **LIVE (bypasses eidos/)** | ROUTE through eidos/ or rename |
| `cognitive_dag/` | provenance graph | **live mirror / observe-only Swift** | KEEP; surface in run |
| `provenance/` ledger | ClaimLedger + replay | **CLI-live / observe-only** | DRIVE from the run |
| `confidence_floor.rs` | honesty kernel | **ORPHANED** | RESURRECT into brain or delete |

---

*Grounded against code read 2026-06-22. Key files: `agent_core/src/lib.rs`, `agent_core/src/agent_loop.rs`,
`agent_core/src/agent_runtime_v2/{mod,system_g_runtime,trinity_loop,blueprint,mode}.rs`,
`agent_core/src/agent_runtime/mod.rs`, `agent_core/src/{eidos,cognitive_dag,provenance}/`,
`agent_core/src/confidence_floor.rs`, `agent_core/src/bridge.rs`, `agent_core/src/command_center.rs`,
`agent_core/src/tools/knowledge.rs`, `Epistemos/LocalAgent/{LocalAgentLoop,LocalAgentPromptBuilder,RuntimeRouter,
RuntimeRouterShadow,ConfidenceRouter,SharedActInference}.swift`, `Epistemos/Engine/{TriageService,
CommandCenterRequestCompiler,MLXInferenceService}.swift`, `Epistemos/SystemG/*.swift`. Cross-ref:
docs/research/{FUGU_ORCHESTRATION_INTEGRATION,TRINITY_COORDINATOR_PORT_SPEC,ADOPT_VS_IP_LAYER_MAP,
AGENT_STACK_CONVERGENCE_RESEARCH,CONNECTION_MAP}_2026_06_*.md; docs/AGENT_RUNTIME_V2_SYSTEM_G_DOCTRINE_2026_05_18.md.*
