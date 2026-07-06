# Deterministic Substrate Infusion — proven primitives → the three agents (+ cloud-first, skill library)

**The core finding (from the miners):** the determinism the owner built is **real, tested, and merely
under-wired** into the three new agents. Infusing it is overwhelmingly *wiring proven Rust `agent_core`
code + its Swift mirrors/FFI into the surfaces* — not building anything new. A handful of items are
"materialize the one missing piece." Almost nothing here is speculative.

> Status: cycle in progress. Miners 1–3 (execution/provenance · schemas/contracts · cognitive substrate)
> are folded in below. Miners 4 (evolving kernel), 5 (EML/retrieval), 6 (proven-primitive inventory)
> append to §7 when they land.

## §0 Infusion principles (apply on every surface, every cycle)
1. **CLOUD FIRST, local second.** Default every surface to **cloud models (full agentic capability)**;
   local models are the secondary / privacy / offline lane. Honest capability still holds (cloud =
   agentic; local = chat/deterministic-tools where true) — but the *default and primary experience is
   cloud*. Never make local the default; never fake agentic capability on local.
2. **Wire, don't rebuild.** These primitives are built + tested. Reuse the Rust core + existing FFI +
   Swift mirror; add only the surface-side wiring. Rebuilding is the anti-pattern.
3. **Substrate-as-capabilities.** Expose each proven primitive to the agents as a composable **skill /
   tool / schema** (§5), so the agent *invokes* determinism rather than re-deriving it.
4. **Promote good skills to users (§6).** The forever-loop forges dev skills each cycle; the proven-good
   ones graduate into a **user-facing skill library** in the app, backed by the real evolution kernel.
5. **Don't ship research-gated layers.** The Addressable Neural Substrate is `canon-target, NOT
   production` — ship the *retrieval* half (Eidos + RRF, both real); keep neural-component routing
   falsifier-gated per the Architecture Promotion Canon (green = T4+). Same for any `state: canon-target`.

## §1 Verifiable provenance (built — mostly wiring)
| Primitive | Built (file:line) | Guarantee | Infuse |
|---|---|---|---|
| **AnswerPacket** (2 lineages — don't conflate) | v6.2 audit packet `Epistemos/Models/AnswerPacket.swift` + `bridge.rs:3738`, emitted `StreamingDelegate.swift:614`; v2 mission envelope `agent_runtime_v2/answer.rs:77` (replay root + thinking digest) | tamper-evident, honest VRM label (never "Verified" without a real ACS anchor) | **June + Experimental:** emit the v6.2 packet + VRM chip (copy `:614`). **Pro:** adopt the v2 mission packet (`run_event_log_root` + `thinking_digest`). |
| **RunEventLog** | `agent_runtime_v2/run_event_log.rs:84` (append-only, BLAKE3 root, ordinal density, capability-reuse detect) | deterministic, order-sensitive replay chain | **Experimental:** capture the opaque CLI tool-calls into a log → `root_hash()` (turns an Electron run auditable). **Pro:** drive it directly. |
| **ReplayBundle / epistemos-trace** | `provenance/replay.rs:228` + `bin/epistemos_trace.rs` (BLAKE3 integrity, typed exit codes) — **gap: no FFI export** | portable byte-equal replay + tamper detection | **⭐ ONE shared net-new: a `ReplayBundle` export FFI** → "Export `.epbundle`" on all three surfaces, verified by the shipped `epistemos-trace` CLI. Highest leverage. |
| **ClaimLedger** | `provenance/ledger.rs:11` (retraction propagation, read FFIs `bridge.rs:3470-3531`) | edited/deleted source → downstream claims auto-flip `AtRisk` | all three: register vault-cited claims → "stale answer" flags. |
| **Falsifier (closed-citation)** | `eidos/falsifier.rs:144` (fabricated citation provably rejected, byte-equal ×20) | the agent cannot cite a source that doesn't exist | run before any "Verified" chip on all three; Pro embeds the witness in the `.epbundle`. |
| **DeterministicSchemaGate** | `tools/registry.rs:49,882` (`EPISTEMOS_SCHEMA_GATE_V1`) + Swift mirror | no tool fires on malformed args (no side effect) | June/Pro: flip the flag on + surface the health row. Experimental: gate vault mutations reaching agent_core. |
| **SovereignGate** (biometric — NOT the determinism gate) | `Epistemos/Sovereign/SovereignGate.swift:50` | no sensitive action without a live presence proof | June/Pro: gate destructive vault/subprocess actions. |

## §2 Deterministic schemas + typed contracts (built — one flag-flip away on the biggest)
- **Grammar-constrained tool calls (hyper-deterministic schemas)** — engine `agent_core/src/grammar/`,
  FFI `grammar/ffi.rs:72`, Swift `RustGrammarMatcherClient.swift`, preflight `tool_preflight.rs`. **The
  MLX `LogitProcessor` that applies the mask is default-OFF with zero callers.** ⭐ **Flip it for June's
  on-device model** → guaranteed-valid local tool calls (the "local > cloud via determinism" thesis).
  Pro: same for its local lane. Experimental: a `vault:validate-tool-call` native reply handler runs
  emitted JSON through `dispatch_schema_for_tools` before execution.
- **Schema-First GenUI** — `GenUIPayload.swift:25` (closed 16-case schema) + `GenUIDispatcher.swift:37`
  (total function, crash-proof fallback), already `Codable` for a Rust emitter. ⭐ **Promote to the
  shared cross-runtime render contract** — `agent_core` emits `GenUIPayload` JSON; all three surfaces
  render agent output through one typed, replayable dispatcher (June native, Experimental via a tiny JS
  renderer of the same shape, Pro shared).
- **Theorems / AcsAnchor (E1–E7)** — `agent_core/src/uas/acs_anchor.rs:12` fails closed on unknown
  theorem ids / unacknowledged fallbacks. Reuse as the admission guard before a claim is shown "Verified".
- **Honest-Handle FFI + versioned envelopes** — doctrine + `RustGrammarMatcherClient` template. Every new
  Rust↔Swift seam refcounted+typed; the web↔native `epistemos` channel gets a versioned typed envelope.
- **`epistemos_doctrine_lint`** — `bin/epistemos_doctrine_lint.rs` (grep-gates, typed exit codes). Add
  per-surface CI gates: Experimental never edits `onecode-shim.js` / only reaches state via the channel;
  June's local model can't claim `agent`/`liveAgent`; Pro No-Orphan (UAS/Plane/Residency) on new decls.
- **ScopeRex** — prod slice `agent_core/src/scope_rex/` (answer_packet/btm_semantic/witnessed_state);
  research `BrainTimeMachine` (checkout/diff/branch) is a Pro "agent-run time-travel" target.

## §3 Cognitive substrate + capabilities (built — wire + two "materialize the missing piece")
- **Eidos closed-citation recall** — 10 modes shipped, live vault binding `EidosBridge.retrieve`, MCP
  `eidos.query` (`VaultMCPCore.swift:509`), closed-citation validator `Eidos.swift:515`. Gate every
  surface's citations on `enforceClosedCitationContract`; June's first grounded-recall path.
- **Cognitive DAG + resonance** — `cognitive_dag/resonance.rs` (Kleene-K3 truth, contradiction floats
  both claims to `Unknown`, stress-tested to 1000 nodes, auto-mirrored on every ledger write). Add a
  "contradicts prior note" ribbon on all three via `propagate_truth_change`.
- **Macaroon capabilities** — `cognitive_dag/macaroons.rs` (attenuation-only HMAC chain, wired into
  dispatch). Gate every tool call via `evaluate_caveats` (per-session scope+tool caveats). ⭐ **Highest
  authorization win: promote caveat enforcement from caller-side into the DAG store's `put_edge`** (a
  test at `dispatch.rs:516` is pre-positioned for it).
- **RuntimeRouter / System G** — the verdict/lane/packet types are built (`RuntimeExecutor.swift`,
  `RouteVerdict`), but ⭐ **`Epistemos/LocalAgent/RuntimeRouter.swift` is referenced by 4 Rust
  source-guard tests and does NOT exist on disk** — materializing it is the cleanest no-hidden-fallback
  routing win (June's cloud-first/local-second choice becomes a witnessed `RouteVerdict`).
- **Cognitive Kernel** — one loop / one ledger / one gate (largely realized). Forward all three surfaces'
  agent events into the one `AgentEvent` ring → one provenance console, three surfaces.

## §4 The highest-leverage build order (ranked, mostly reuse)
1. **`ReplayBundle` export FFI** (one shared net-new) → "Export `.epbundle`" on all three.
2. **Flip the grammar `LogitProcessor` flag** for June's (then Pro's) on-device model.
3. **Promote `GenUIPayload` to the shared render contract** (one Rust Codable emitter).
4. **Eidos closed-citation gating** + the falsifier before any "Verified" chip (all three).
5. **Materialize `RuntimeRouter.swift`** (cloud-first/local-second, witnessed).
6. **Macaroon `put_edge` caveat enforcement** (uncircumventable tool authorization).
7. **AnswerPacket VRM chips + ClaimLedger retraction ribbons** (honest, stale-aware answers).

## §5 Substrate-as-capabilities (expose the primitives as skills / tools / schemas)
The agent should *invoke* determinism. Package the proven primitives as composable units:
- **Tools** (agent-callable): `vault.cite-check` (Eidos closed-citation), `vault.claim-status`
  (resonance truth), `run.export-bundle` (ReplayBundle), `tool.validate` (grammar/schema gate),
  `answer.anchor` (AcsAnchor/theorem check).
- **Schemas** (typed contracts): the grammar tool-dispatch schema, the `GenUIPayload` render schema, the
  AnswerPacket envelope, the RouteVerdict record.
- **Skills** (methodologies): "ground-and-cite", "provenance-writeback", "contradiction-resolve",
  "export-verifiable-run" — each a SKILL.md the agent composes, and (if proven) a user-facing skill (§6).

## §6 The USER-FACING SKILL LIBRARY — promote only the good ones (the kernel is ALREADY BUILT + tested)
Miner 4 confirmed: the entire self-evolution loop is **compiled, `#[cfg(test)]`-passing, FFI-exposed, and
in three places already surfaced in the app.** The "user gets only the good skills" pipeline is NOT
net-new — it's *wiring the three surfaces into this proven kernel* instead of writing ad-hoc SKILL.md:
- **The library + review UI already exist:** `Epistemos/Vault/SkillEvolutionService.swift` (@Observable
  @MainActor — analyze/propose/approve/reject, writes versioned SKILL.md + diff to
  `<vault>/skills/<name>/versions/`). Surface a **"Skills" browser** in each agent that reads it. Nothing
  auto-applies — every promotion is user-reviewed (honest by construction).
- **The "only the good ones" quality gate already exists** as deterministic promotion gates:
  `skill_discovery/mod.rs` — novelty (tool-sequence SHA-256), latency budget (8s), user-acceptance
  (no-undo-24h), **frequency ≥4×**; `evolution/mutation_proposer.rs` — size ≤15KB + semantic cosine
  >0.80; `agent_runtime/self_evolution.rs` — `propose_repeated_success_skill` (repetition ≥ threshold). A
  skill graduates ONLY through these.
- **Selection/routing exists:** `skill_router.rs` (TF-IDF, loads `<vault>/skills/` + `<vault>/.agents/
  skills/`, FFI `dispatch_skill`/`list_registered_skills`; Goose already lists via ACP). Procedural
  memory + recall: `agent_runtime/procedural_memory.rs` (FFI `record_skill_outcome`/`recall_procedure`/
  `invoke_skill`). Self-heal → skill feedback: `heal/log.rs recurring_patterns` → the mutation proposer.
- **The unified loop (the real "forge a skill each cycle"):** `skill_router.route` → `invoke_skill` →
  `HealLoop.run` (bounded self-correct) → `record_skill_outcome` (durable) → `neocortex.absorb` (carry
  gist) → **[nightbrain idle scheduler]** → `analyze_traces` + `heal recurring_patterns` →
  `propose_repeated_success_skill` + `SkillDiscovery.observe` + `propose_mutation` (gated draft) →
  `SkillEvolutionService` review → versioned SKILL.md → `skill_router` reloads next cycle. Runs on the
  **shared vault**, so a workflow proven in one surface upgrades the SKILL.md all three read.
- **⭐ Exactly TWO wires are missing to make it fully real:** (1) a `#[uniffi::export] fn
  observe_composition(trace_json)` for `SkillDiscovery::observe` (`skill_discovery/` is the one primitive
  with no FFI); (2) fill the `skill_evolution_analysis` NightBrain NoOp body (`nightbrain/live.rs`) with
  analyze+propose. Land those two + a per-surface Skills browser and the loops' skills become
  user-accessible, quality-gated, and self-forging on the idle scheduler.
- **Per surface:** Experimental posts CLI-agent tool sequences over the `epistemos` channel →
  `record_skill_outcome`/`observe_composition`. June records on-device (the honest, sandbox-safe learning
  lane) + a Skills tab calling `SkillEvolutionService`. Pro/Goose already reads the router — extend to
  inject matched skill bodies + record cross-surface repetition; build the Skills browser as a shared
  component. All three register into the ONE nightbrain scheduler.
- **Turn the prompts' "write a SKILL.md each cycle" into "record the cycle's outcome + let the proven
  kernel gate/draft it, and promote to users only what passes the gates."**

## §7 Related proven loops (miner 4 — all built + tested)
- `hyperdynamic_loop/mod.rs` — bounded draft→check→repair→accept (`RepairBudget = min(3 retries, 5s, 1024
  tokens)`); wrap every surface's tool-call JSON parse so malformed output is repaired-or-quarantined, not
  dropped (highest payoff on June's local model). HealthRow exists; counter→Swift FFI still to wire.
- `heal/{mod,log}.rs` — bounded self-heal + a recurring-failure ledger that feeds §6's mutation proposer
  (self-heal and self-evolve become one loop).
- `nightbrain/{mod,live}.rs` — battery/thermal-safe idle scheduler = the real host for the forever loop.
- `neocortex.rs` — bounded rolling gist (absorb each cycle summary → query next cycle) = cross-cycle
  memory without reloading history. (Honest: text-rolling, not true SSM tensor state yet.)

## §9 The deterministic retrieval → rank → gate → select → anchor pipeline (miner 5 — tested, Rust↔Swift parity)
Through-line: **RRF retrieves → EML fuses/reranks → confidence-floor gates → VariantLadder selects/audits
→ ACS anchors the "Verified" label.** Each a tested pure function → the same pipeline backs all three surfaces.
- **RRF + Vault Recall Contract** — tantivy BM25 + usearch HNSW, k=60 (single-source
  `epistemos-shadow/src/backend/rrf.rs`); every retrieval MUST emit a `RetrievalTrace` (5 signals, MMR
  λ=0.72) → "first 7 irrelevant notes" is structurally un-hideable (`retrieval/mod.rs`, 82 tests).
- **EML rerank** — `eml(x,y)=exp(x)−ln(y)`; key `eml(-ln(bm25+ε), secondary+1)`, smaller=better;
  deterministic energy fusion of BM25 × a positive secondary (coverage/graph-proximity/recency). Pure,
  stable-sort, NaN-safe; `eml_rerank.rs` + `EmlRerank.swift` parity; wired `vault.rs:628` behind
  `EPISTEMOS_EML_RERANK_V1` (OFF). Flip on → agent sees fused-ranked notes, not raw BM25.
- **Confidence floor** (T1≥0.85/T2≥0.75/T3≥0.70; exactly one of accept/escalate/empty) —
  `confidence_floor.rs`, 6 tests. The honest "no confident answer in your vault" gate; escalation ONLY on
  explicit opt-in (no silent model fallback — aligns cloud-first-but-honest).
- **VariantLadder** (6 tiers Deterministic→…→Cloud; Tiers 4+ generative skipped unless policy is
  Always/OnEmpty; audit → `.epbundle`) — `variant_ladder/mod.rs`, 27 tests. **PROVEN but SCAFFOLD (0
  production routes)** — migrating `vault.search` onto it is the highest-ROI promotion.
- **ACS admission + VRM anchor** — `VrmLabel::Verified` structurally unforgeable (all-verifying claims +
  verification_score≥0.5 + a well-formed `AcsAnchor` bound to that packet; `validation.rs:161-203`,
  `AnswerPacket.swift:366`; wired `bridge.rs:4876`).
- **Corrections:** `arena`/`arenas` = shared-memory IPC rings (NOT competition); `tri_fusion` =
  content-format fusion (NOT retrieval).

## §10 Proven-primitive master inventory (miner 6) — 31 health rows = shipped + monitored
Top additions per surface:
- **Effect system** (`effect/mod.rs`, tagged effects w/ deterministic inverses) → route ALL agent vault
  mutations through effects so every action is reversible by construction (June + Pro).
- **tirith** (homograph URLs / pipe-to-interpreter / terminal-injection / cred-exfil gate) → run on every
  Work/Goose shell command before exec (Pro). **circuit_breaker** (<5ns) → provider back-off in the nav bar.
- **context_compiler** (budget-aware assembly + kv-cache breakpoints) → replace ad-hoc concatenation
  (June + Experimental). **cognitive_weight** (4-tier) → weight chunks before injection. **tool_preflight**
  → trim the tool list per turn. **canon** → dedup graph node names.
- **brain_export** (Merkle DAG root + ledger hash + model_id + vault hash) → portable/auditable snapshot.
  **reasoning_metrics** (Efficient/…/Stuck) → "reasoning health" chip + auto-compact when Stuck.
  **LiteParse** (PDF→md) → "drop PDF → vault" (Experimental). **tools_v2** (AppStoreSafe/ProOnly) →
  auto-hide ProOnly tools on MAS. **VaultSave** streak detector → block "done" when writes aren't landing.
  **tamagotchi** → mascot emotive state. **OpLog/undo** → "undo last agent action".
- **⚠️ Research-only / do-NOT-claim-green** (honor the Architecture Promotion Canon): `sketch` (no tests),
  `mutations` (type-only), `session_insights.compute_tool_breakdown` (schema gap), `neocortex` gist
  (MLX-tensor pending), `FUlp` oracle (research-feature-only), `GooseWorkBackend` (honest-refuse until
  block/goose vendored), `Arena` (substrate real, producer/consumer not wired), Obscura stealth +
  HTMLWorkspace builder + KnowledgeCore read/runtime (shadow/deferred).

## §8 Cycle log
- **Cycle 1 (2026-07-05):** owner requirements (cloud-first §0 · substrate-as-capabilities §5 · user
  skill library §6) + the finalization mandate on all three prompts.
- **Cycle 2 (2026-07-05):** all SIX miners folded in (§1–§10). **Verdict: the determinism is built +
  tested + under-wired** — infusion is ~90% wiring proven `agent_core` code + Swift mirrors/FFI, with a
  few "materialize one missing piece" items (ReplayBundle export FFI · `RuntimeRouter.swift` ·
  `SkillDiscovery::observe` FFI · nightbrain `skill_evolution_analysis` body · macaroon `put_edge` ·
  flip the grammar `LogitProcessor` flag). Research-only layers flagged (§10) — never shipped as green.
