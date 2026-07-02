---
id: 0192B26E-FCF4-4EBC-B026-6F77FA0EFC14
title: "SS-Y — Hyperdynamic determinism / deterministic schema: make LOCAL agents &gt; cloud (2026-06-19)"
---

# SS-Y — Hyperdynamic determinism / deterministic schema: make LOCAL agents &gt; cloud (2026-06-19)

Read-only research (subagent), code-grounded + web. Feeds the HYPERDYNAMIC-DETERMINISM ledger item. Owner:
*"make local agents MORE useful than cloud — a playground for making local models better via deterministic
schema + robust agent-loop upgrades."* Cross-refs SS-Z (per-model dialects), SS-H (skills/loop dropout), SS-W
(crash).

## Headline

**Local-beats-cloud is architecturally within reach but NOT yet wired on the live lane.** Epistemos already owns
the three hard pieces: (1) a real GBNF hard-masking path on the GGUF lane (`--json-schema` + `--seed 0` greedy =
guaranteed-valid + reproducible tool calls — which a raw cloud model CANNOT guarantee), (2) a bounded,
falsifier-proven deterministic repair engine (`HyperdynamicLoop`), (3) a robust local agent loop with multi-mode
self-correction. **The edge is real but unrealized because the two best levers are DARK:** on the *live MLX*  
*lane* constrained decoding only applies **soft EOS penalties (not hard masking)**, and the `HyperdynamicLoop`
engine has **no production callers** — both built-but-unwired. Fastest path to "local &gt; cloud" = wire the masked
logit processor the project ALREADY vendors + connect the repair loop's existing gate helpers.

## Determinism / constrained-decoding substrate today

Two lanes, asymmetric:

- **GGUF/llama.cpp (REAL hard masking, Pro-gated):** `GgufCliProvider` passes `--json-schema` for GBNF
grammar-constrained decoding that GUARANTEES structurally valid output (`gguf_cli.rs:111-159`); `temperature 0.0` greedy (`:131-134`) + `--seed 0` (`:255`) → reproducible. FFI `run_local_gguf_generation` json_schema
(`bridge.rs:1281-1359`). Strongest "deterministic schema" surface, but the whole GGUF runtime is
Pro-Gated/Research per CLAUDE.md until witnesses land. **(verified)**
- **MLX (live, but SOFT only — the keystone gap):** `LocalToolGrammar.buildToolCallingPlan`/`buildJsonOutputPlan`
build real MLXStructured `Grammar` objects (GBNF-equiv, `supportsTrueMasking:true`) wrapping each tool's
JSONSchema in `<tool_call>` triggers (`LocalToolGrammar.swift:163-269`). **BUT the live generator never applies
them as hard masks:** `MLXConstrainedGenerator.JSONSchemaLogitProcessor` "only applies soft EOS penalties …
does NOT perform true grammar-aware masking" (`MLXConstrainedGenerator.swift:16-18,106`). So
`ConstrainedDecodingService.isAvailable` is gated false unless a generator reports `isFullyConstraining` —
none does (`ConstrainedDecodingService.swift:10-12,34-55`). **On the live MLX path local models get soft
guidance, NOT guaranteed-valid tool calls.** **(verified)**
- **THE FIX IS ALREADY VENDORED:** `mlx-swift-structured` ships `GrammarMaskedLogitProcessor` — a real
`LogitProcessor` whose `process(logits:)→MLXArray` masks invalid tokens every step (`build/UserRun/.../ MLXStructured/GrammarMaskedLogitProcessor.swift:11-48`) + an `XGrammar.swift` backend. **NO Epistemos product
code references it** (grep zero hits). The hard-masking primitive is one import away. **(verified)**

## Hyperdynamic loop — built, tested, falsifier-proven, but ORPHANED

- Engine is real + good: `HyperdynamicLoop` trait + `run_loop` bounded-retry runner (`draft → check → Accept|RepairWith|Quarantine`), `RepairBudget::DEFAULT = min(3 retries, 5s, 1024 tokens)`, `LoopCounters`
(`agent_core/src/hyperdynamic_loop/mod.rs:95-307`). Three loops: `schema_repair` (research-gated),
`admission_repair`, `witness_repair` (`:21-29`). Dedicated falsifier proves bounded termination over a
100-prompt adversarial corpus (`bin/falsify_hyperdynamic_loop_bounded.rs`). **(verified)**
- **Orphaned at the integration seam:** `gate_admission_draft_through_loop` / `gate_witness_draft_through_loop`
(`agent_runtime_v2/mission_run.rs:331-382`) have **ZERO non-test callers** (the `:300-329` comment describes
adapters that "MUST call exactly one before the existing writers" — those call sites don't exist). **(verified)**
- **Orphaned at the UI seam (confirms SS-B):** `HyperdynamicLoopHealthRow` + `HyperdynamicLoopMetrics.ingest`
exist but `ingest` has **zero callers** (`HyperdynamicLoopHealthRow.swift:17-19,247` says "row reports 'no read
yet'"). **(verified)**
- **Why it's the engine for reliable local agents:** it's exactly the deterministic "draft → schema-check →
repair-or-quarantine → next layer" state machine the thesis needs, with provable bounded retries. Wiring its
`re_emit` closure to the local adapter (failed tool-call → re-prompt with missing-field hint, then HARD-MASKED
retry) turns "small model drops out of loop" (SS-H) into "small model is FORCED back into a valid call."

## Local agent loop robustness + gaps

`LocalAgentLoop.swift` (2,478 lines) is MORE self-correcting than naive ReAct: bounded turns (`maxTurns:8`
`:273`), invisible-turn detect+repair (`:65,344-348,426-432`), skipped-step repair (`:447-490`), invalid-tool
repair (`:519+`), a dedicated `repairGenerator` (`:76,100`), RAG preflight tool-narrowing (`SchemaPreflight ToolNarrowing.narrow`, flag `EPISTEMOS_SCHEMA_PREFLIGHT_V0` `:297-301`). Routing via `ConfidenceRouter`
(→`RuntimeRouter.defaultRouteProfiles`, `minimumConfidence` + `cloudFallback` `:91-100,142-144`) +
`OverseerComplexityRouter`. **(verified)**
**Gaps vs cloud:** (1) **no hard-masked decode on retry** — repairs re-prompt in natural language but don't
ENFORCE the grammar (masked processor unwired) = "ask nicely" vs "make invalid tokens impossible"; (2) repair is
~5 bespoke per-call-site builders, none routes through the proven `HyperdynamicLoop` runner (the exact
fragmentation the module was built to fix); (3) no verification/self-consistency pass; (4) no grammar-enforced
*final answer* schema (only tool calls get grammar).

## The local&gt;cloud levers mapped to code


| Lever                                                                                | Existing code                                                                                                                                | Gap                                                                                       |
| ------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| **(a) Guaranteed-valid tool calls** (cloud CAN emit invalid JSON; local+GBNF cannot) | GGUF `--json-schema` (`gguf_cli.rs:111-159`); MLX `Grammar` build (`LocalToolGrammar.swift:163-269`); vendored `GrammarMaskedLogitProcessor` | **[S]** wire the vendored masked processor into live MLX; flip `isFullyConstraining=true` |
| **(b) Determinism/reproducibility**                                                  | `--seed 0` + `temp 0.0` (`gguf_cli.rs:131-134,255`)                                                                                          | MLX seed/greedy parity (unverified)                                                       |
| **(c) Local context cloud can't see**                                                | `SchemaPreflightToolNarrowing` RAG (`:297-301`); Halo shadow RRF; agent_runtime skills                                                       | feed shadow hits + procedural memory into the repair hint                                 |
| **(d) Speed/privacy/no-rate-limit**                                                  | in-process MLX, no subprocess                                                                                                                | inherent — surface as UX claim                                                            |
| **(e) Self-correction vs smaller model**                                             | `HyperdynamicLoop` (`mod.rs:230-307`); LocalAgentLoop repairs                                                                                | **[M]** route repairs through `gate_*_through_loop`; add verify→retry                     |
| **(f) Per-model tool dialects (SS-Z)**                                               | `LocalToolGrammar.nativeGrammar(forModelID:)` 8 dialects `:27-124`                                                                           | bind each dialect's grammar to the MASKED decode                                          |


## Proven techniques to adopt (web)

- **XGrammar** = SOTA constrained decoding (&lt;40µs/token, ~3× faster JSON / 100× CFG; default in vLLM/SGLang/
TensorRT-LLM; handles recursive schemas Outlines FSMs can't) — **the vendored `mlx-swift-structured` already
ships `XGrammar.swift`** → adoptable on MLX. (arxiv 2411.15100)
- **MLX-Swift native structured gen** — `GrammarMaskedLogitProcessor.from(configuration:grammar:)` → `Token Iterator`, `Grammar.schema(generable:)` — the exact API to wire (Rudrank guide).
- **Trigger-gated constraints** — llama.cpp/MLX gate the grammar behind a tool-call trigger (matches
`TriggeredTagsFormat(triggers:["<tool_call>"])` already at `LocalToolGrammar.swift:191`).
- **CAVEAT — self-consistency is WEAK for small models** (gains decline with more samples); prefer
**self-certainty / confidence-weighted Best-of-N** (token-distribution divergence) over naive majority vote.
(arxiv 2502.18581, 2502.06233)
- **Pre³ deterministic pushdown automata** for faster structured gen if recursive tool schemas appear (2506.03887).

## Ordered plan

1. **[S] Wire the vendored `GrammarMaskedLogitProcessor` into the live MLX generator** — replace/augment
JSONSchemaLogitProcessor`(soft EOS) with real masking built from`ToolCallingPlan.grammar `(`LocalToolGrammar  .swift:182-205`); flip` isFullyConstraining→true`so`ConstrainedDecodingService.isAvailable` lights up.
*Makes local tool calls guaranteed-valid on the live lane = the core of the thesis. Highest leverage, lowest
isk (dep already vendored).**
2. **[S] Connect `HyperdynamicLoopMetrics.ingest` to a `LoopCounters` FFI snapshot** — de-orphans the SS-B health
ow, gives a repair-rate observability surface.
3. **[M] Route `LocalAgentLoop` repairs through `gate_admission/witness_draft_through_loop`** with the `re_emit`
losure re-prompting UNDER HARD MASK — unifies the 5 ad-hoc repair builders into the proven bounded runner;
urns SS-H's loop-dropout into a forced-valid retry.
4. **[M] Add confidence-weighted Best-of-N / self-certainty verification** on tool-call selection (NOT naive
ajority — small-model caveat) gated by `ConfidenceRouter` thresholds.
5. **[L] Evaluate the vendored `XGrammar.swift` backend** vs the current MLXStructured matcher for recursive
chemas + per-token latency on Apple Silicon; adopt if the &lt;40µs win holds.
6. **[L, Pro-gated] Promote the GGUF `--json-schema` + `--seed 0` lane** through the CLAUDE.md gate (RunEventLog/
nswerPacket/rollback/witnesses) for the strongest determinism guarantee as a selectable runtime.

## Unverified

MLX-lane seed/greedy reproducibility (only GGUF `--seed 0` confirmed); whether `schema_repair` (research-gated)
compiles in the default build; the XGrammar backend's integration status inside the vendored package (file
present, integration not traced).

Key files: `agent_core/src/providers/gguf_cli.rs:111-159,255` · `agent_core/src/bridge.rs:1281-1359` ·
`LocalAgent/LocalToolGrammar.swift:163-269,27-124` · `Omega/Inference/MLXConstrainedGenerator.swift:16-18,106`
(**the gap**) · `Omega/Inference/ConstrainedDecodingService.swift:10-12,34-55` · `build/UserRun/.../MLXStructured/ GrammarMaskedLogitProcessor.swift:11-48` + `Backends/XGrammar.swift` (**vendored, UNUSED — the fix**) ·
`agent_core/src/hyperdynamic_loop/mod.rs:95-307` · `agent_core/src/agent_runtime_v2/mission_run.rs:331-382`
(gate helpers, no callers) · `bin/falsify_hyperdynamic_loop_bounded.rs` · `Views/Settings/HyperdynamicLoop HealthRow.swift:17-19,247` (orphan) · `LocalAgent/LocalAgentLoop.swift:273,297-301,344-348,426-532` ·
`LocalAgent/ConfidenceRouter.swift:91-100,142-144`. Sources: arxiv 2411.15100 (XGrammar), 2501.10868, 2502.18581,
2502.06233, 2506.03887; llama.cpp grammar docs; Rudrank MLX-Swift structured-gen; aidancooper constrained-decoding.