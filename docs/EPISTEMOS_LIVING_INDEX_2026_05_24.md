# Epistemos — Living Index (single canonical entry point)

> **You are here.** This is the one document any agent or human reads first to understand the architecture, the current state, the terminals, the deferred work, the codewords, and how to resume. **Do not descend to deeper docs unless you need the specific detail.** Every paragraph below either tells you the answer or names exactly which deeper doc holds it.

**Living-doc rules:**
- Update this file in place — never branch a parallel "v2." There is one living index; the old version is `git log`.
- Update the **Current State** block (§6) on every wave close.
- Updated **2026-05-31** · Two-build lock: Epistemos has exactly two
  distributable builds, **MAS** and **Pro**. MAS is the App Store-safe public
  floor. Pro is the direct-distribution power build containing internal status
  bands: Pro Live, Pro Gated, Pro Research, Pro Vault-Preserved, and Pro
  Omega. Research, Vault, Omega, heavy runtime, and future substrate work are
  Pro statuses, not separate app builds.
- Updated **2026-05-31** · Namespace checkpoint: `ACS` is no longer a
  shorthand for Active Cold Storage. Use `ColdStore` / `Cold Residency Layer`
  for dormant SSD/mmap/KV/weight/note residency; keep `AcsAnchor` for the
  existing anchored coordinate/provenance object; call admission/verdict
  behavior `SCOPE-Rex Admission`, `SovereignGate`, or `AdmissionGate`; and
  translate Helios as lineage, not as a product-spine step. Current authority:
  `docs/audits/ACS_NAMESPACE_RECONCILIATION_2026_05_30.md` and
  `docs/audits/AGENT_MANAGEABLE_ARCHITECTURE_CANON_2026_05_30.md`. Final
  active-doc audit:
  `docs/audits/NAMESPACE_AND_ARCHITECTURE_CLARITY_AUDIT_2026_05_31.md`.
- Updated **2026-05-27** · Wave 4 checkpoint: PRs `#121`-`#127` are on
  `main`, including typed UAS retrieval/claims, PageGather escalation traces,
  Cognitive DAG visualizer, Tri-Fusion typed note mutations, and the System G
  test-isolation/focused-warning fixes. Post-Wave-4 closeouts also retired
  W-49/W-53 ship hardening and Agent Capability Truth. The provenance/residency
  detail slice closes the compact AnswerPacket UAS / AcsAnchor / plane /
  residency UI gap. `RESUME ACS ANCHOR HARNESS` is now complete as a full
  N=1000 four-stage witness, `F-ULP-Oracle` now has a full Metal
  `morphOracleFp16` primary hardware artifact, `F-ControllerKernelPack` now has
  a full Metal primary hardware artifact, and `F-PageGather-M2Pro` now has an
  honest 256 MB Metal failure report plus locality, scheduler-side
  block-sorted, dense-restore, and packetized scheduled mitigation witnesses,
  not a false green. Capability Ceiling model gating was hardened on
  2026-05-27: power-user mode now preserves the 70B / ColdStore / UAS research
  posture but does not lower the dense 36B MLX memory gate before
  `F-70B-Local-Cocktail` or an equivalent SSD/RAM composition artifact passes.
  See `docs/audits/CAPABILITY_CEILING_MODEL_GATE_2026_05_27.md`.
  For the current W-row/falsifier recount and next codeword
  prompts, read
  `docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md`. For the post-stash
  split of finished vs unfinished work, read
  `docs/audits/MAIN_ARCHITECTURE_RECOVERY_STATUS_2026_05_26.md` before
  dispatching another recovery agent.
- Capability Ceiling route kernel added on 2026-05-28:
  `F-Capability-Ceiling-Evaluation-Kernel` emits
  `artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json` and
  currently reports `vault_research_route_with_packetized_mitigation` with
  next bottleneck `repair_qwen3_8b_128k_gguf_metal_stall`.
  `F-UAS-CopyCount` and `F-ACS-AnchorLookup` are now schema-normalized primary
  witnesses. `F-UAS-ACS-MmapResidency` is now a primary witness for a 16 MiB
  file-backed mmap KV-page slice with UAS address round-trip, AcsAnchor projection
  lookup, residency lease round-trip, checksum proof, invalid-offset rejection,
  and zero tracked hot-path copies; it is not a live MLX, KV-Direct, or 70B
  proof. `F-PageGather-Packetized-Caller` is a fallback witness proving Vault
  retrieval can consume PageGather packets before dense restore.
  `F-KV-Direct-Gate` now has the live harness contract for model/logit/metrics
  and spill-trace inputs, auto-detects the local Qwen3-8B MLX snapshot, and has
  a canonical 100-prompt / 128K / 256-decode prompt-suite manifest at
  `artifacts/falsifiers/kv_direct_gate/prompt_suite.json`. The MLX side now
  supports restartable prompt shards and a shard merger, but the paired live
  logits and live SSD-spill metrics remain red; the resolved local model also
  fails the new model-context axis at `40960 < 128000`. The spill trace now has a
  semantic gate: only a `residual_patched_mmap_nf4_ssd_spill` trace with
  residual patching, mmap-backed cold KV, NF4/equivalent storage, and positive
  cold bytes can satisfy the final spill axis. `F-Qwen3-8B-128K-GGUF-Route`
  now exists as a separate schema-valid red candidate/fallback lane targeting
  `unsloth/Qwen3-8B-128K-GGUF`; it does not satisfy the canonical MLX
  `F-KV-Direct-Gate`, ingests a non-executing 128K dry-run preview, and
  currently waits on `repair_qwen3_8b_128k_gguf_metal_stall`.
  `F-Agent-Local-Model-Runtime-Bridge` now exists as a schema-valid primary
  witness for the guarded local-model bridge slice: the local model catalog,
  MLX client, GGUF client, `ProviderPolicy::LocalMlx`, System G event seam,
  LocalAgent adapter dispatch, Rust-to-Swift local-model handoff, registered
  local-client consumption, retained live prompt-suite artifact, and
  AnswerPacket local-model provenance are present. This keeps the
  agent/local-model core feature explicit instead of hiding it behind catalog
  metadata, while 128K KV and 70B capability routes remain separately red.
  `F-ActiveAssembly-Minimal` now has a primary synthetic runtime
  witness, flipping `active_assembly_runtime_artifact_pass=true` in the route
  kernel. `F-Sparse-Runtime-Split` now has a primary synthetic sparse/reference
  witness and synthetic EML/Geometry/Scan/Operator chart coverage, but live 70B
  sparse runtime and live 70B chart coverage remain red. The route artifact now
  contains `measurements.ordered_build_queue` and
  `unmapped_architecture_gap_count=0`; the human mirror is
  `docs/audits/ARCHITECTURE_NO_GAP_BUILD_ORDER_2026_05_28.md`. Read
  `docs/audits/CAPABILITY_CEILING_EVALUATION_KERNEL_2026_05_28.md` before any
  70B / ColdStore / UAS runtime loop.

---

## 1 · What Epistemos is (one paragraph)

Epistemos is a **local cognitive substrate**, not "an app that runs a local model." The local model is the *mouth*; the substrate is everything that decides what part of memory, which runtime, what evidence, what schema, what proof, and what permission path the model is allowed to use before anything becomes an answer or an action. **MLX is one runtime lane**, not the architecture — it can be enabled, disabled, replaced, or paired with GGUF / llama.cpp / cloud / Apple Intelligence. The substrate is the routing, residency, schemas, admission gates, proofs, and visible verification *around* those executors.

Required architecture sentence: **Epistemos is a local cognitive substrate
where every meaningful object has an address, plane, budget, status, and
witness; MAS ships the safe floor, Pro contains the gated/research/vault/omega
ladder, and no claim promotes without visible proof.**

### Original Hope / Genesis Architecture

The early grand-unification, kernel, lattice, EML, and physics-style language
is preserved as the founding intuition: data should not be dead files,
intelligence should not be a chatbot wrapper, memory should not be a pile of
unrelated documents, and the computer should behave like a governed cognitive
organism. The current architecture perfects that ambition by translating it
into buildable organs: UAS/OAS, ColdStore, ActiveAssembly, Eidos,
SCOPE-Rex/SovereignGate, RuntimeRouter/System G, WBO/LatticeBudget,
AnswerPacket, ClaimGraph, RunEventLog, MutationEnvelope, and
Lean/schema/falsifier witnesses. Physics language remains inspiration or
VaultPreserved research lineage unless a local proof, falsifier, or measured
implementation promotes the claim.

## 2 · The architecture in one rule (the Substrate Motion Invariant)

Every meaningful Epistemos object is **one substrate object** carrying:
1. `UasAddress` — stable identity
2. `ProductBuild` — MAS · Pro
3. `ProStatus` / `ResidencyStatus` — Live · Gated · ResearchCandidate ·
   VaultPreserved · Omega · Blocked · TargetOnly · Superseded, plus
   CurrentApp · VerifiedFloor · CapabilityCeiling where the question is
   residency/proof maturity rather than distribution
4. `RuntimePlane` — State · Episodic · Assembly · Controller · Verification
5. `LatticeBudget` — WBO error account (if approximate)
6. **Witness** — `RunEventLog` / `AnswerPacket` / `ClaimGraph` / `WboLedgerEntry` / falsifier artifact / Lean proof

Every operation is exactly one of **three motions**:

| Motion | Direction | Meaning | Witness required |
|---|---|---|---|
| **Lift / Ingest** | surface → substrate | put raw material in (note bytes, pixels, prompts, model output, traces) | UAS + source hash + plane |
| **Project / Compress / Recall** | substrate → surface | make object cheaper, smaller, or visible (vault recall, citation, UI row) | ShadowProjection + WBO + citation/proof |
| **Mutate / Promote** | substrate → substrate | change durable state or promote candidate to authority | MutationEnvelope + SCOPE-Rex/SovereignGate verdict + rollback |

There is no fourth motion. "Activate a model slice" is a Lift at finer granularity (see §3).

## 3 · LLM-address granularity ladder (what your app calls the LLM as)

10 rows, finest at bottom. Every PR must answer *"which row does this touch?"* Overclaim = reframe.

| Row | What is addressed | Status today | Build/status |
|---|---|---|---|
| 1 | Whole-model call | LIVE | MAS / Pro Live |
| 2 | Output schema (grammar, JSONSchema, AnswerPacket) | LIVE partial | MAS / Pro Live |
| 3 | KV cache page (zero-copy across Swift/Rust/MLX/Metal) | substrate shipped, harness pending | Pro Gated |
| 4 | Weight-bit layout (Sherry/Leech VQ, ternary, NF4) | research / promotion candidate | Pro Research |
| 5 | Adapter delta (LoRA / DoRA / Titans-MAC / L_SE) | research | Pro Research; Pro Gated only after rollback/eval gate |
| 6 | MoE expert | model-internal; substrate observes/chooses lane | MAS or Pro Live only when provider/runtime exposes it honestly |
| 7 | Active assembly (model + KV + context + adapter + tool + kernel cross-cut) | research target | Pro Research |
| 8 | Attention head / **SSM state (the language router gate)** | research target | Pro Research |
| 9 | Parameter anchor (rank-one component address) | research target | Pro Vault-Preserved / Pro Research |
| 10 | Cross-layer attribution circuit | research target | Pro Vault-Preserved / Pro Omega |

Endgame: substrate addresses **cognitive circuits**, not whole models. Each release pushes granularity one row finer. Full canon: `docs/fusion/ADDRESSABLE_NEURAL_SUBSTRATE_CANON_2026_05_24.md` + `docs/fusion/SHADOW_PROJECTION_AND_RESEARCH_CONSTRUCTION_2026_05_24.md` §12.

## 4 · Seven laws + one candidate

| # | Law | Statement |
|---|---|---|
| 1 | Density | Morph/EML approximates compact controller policies where the formal domain permits |
| 2 | Address | Every cognitive object has a stable UAS address independent of residency |
| 3 | Active-support | Only the relevant slice wakes |
| 4 | Lattice-error | Every approximation pays into WBO |
| 5 | Glue | Local context must cohere before becoming global |
| 6 | Duplex | Hard-compact and soft-page-backed branches both allowed, error accounted |
| 7 | Witness | Every meaningful action is typed, permissioned, logged, replayable, visible |
| **8 (candidate)** | **Shadow Projection** | Every projection preserves source coordinate, accounts WBO, is reversible up to budget |

## 5 · Theorems (E1–E7 + H1–H17 + PCF-1..10 + 2 candidates)

- **E1–E7** Foundational Seven (Epistemos Core) — see `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md`
- **H1–H17** Helios Operational claims
- **PCF-1..10** Parameter Connectome Family (Goodfire VPD/SPD lineage)
- **E8 (candidate)** Erdős Lift-and-Project Optimality
- **E9 (candidate)** Shadow-Witness Closure

### Letter and status grammar

| Prefix / label | Meaning |
|---|---|
| `E` | Foundational theorem or theorem candidate. |
| `H` | Helios operational claim; translate to concrete organs before product work. |
| `PCF` | Parameter Connectome Family claim/candidate. |
| `F` | Falsifier, witness, benchmark, or proof artifact. |
| `W` | Wiring row: product-visible work that must become reachable and visible. |
| `L` | Law or invariant. |
| `D` | Deferred direct-distribution capability. |

| Status | Meaning |
|---|---|
| Live | Implemented, reachable, visible, and tested enough for its declared build. |
| Partial | Real substrate exists, but caller chain, visibility, or verification is incomplete. |
| Gated | Implemented or partial, but blocked by explicit opt-in, rollback, warning, policy, or falsifier gate. |
| Candidate / ResearchCandidate | Accepted shape awaiting falsifier or product caller proof. |
| VaultPreserved | Preserved ambition, branch, theorem, or mechanism with no runtime authority. |
| Blocked | Known blocker prevents promotion. |
| TargetOnly | Architecture target only; no shipped behavior claim. |
| Superseded | Old name/mechanism replaced by a cleaner current organ. |
| Deprecated | Old path should not receive new work except compatibility removal/migration. |

## 6 · CURRENT STATE (2026-05-27 — Wave 4 checkpoint + closeouts)

### Wired and on main
- 40+ pre-2026-05-23 PRs · 18 from the 2026-05-23 sanitization session · 5 from the 2026-05-24 doctrine session · **14 Phase-2 merge-wave PRs (#66-#79, including #73 index refresh and the direct #76 hotfix `77c7efe9ea`)** · **Wave 3/4 substrate PRs #121-#127**.
- Substrate carcass: ~70% baseline per chronicle audit, advanced by real Eidos bridge, System G seam, SCOPE-Rex/SovereignGate production gate, T14 UAS bridge, Verified Floor chip gate, Runtime Router, Hyperdynamic Loop, B-prime chat provenance, Round-2 falsifier artifacts, typed UAS retrieval/claims, PageGather escalation traces, Cognitive DAG visualizer, Tri-Fusion typed note mutations, focused test-warning cleanup, W-49/W-53 hardener closeout, Agent Capability Truth closeout, and the compact AnswerPacket provenance/residency detail path. **Post-Wave-4 LEGENDARY estimate: ~42/53 strictly wired, ~49/53 strict+meaningful partial, ~96% substrate floor.** Full recount: `docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md`.
- 13+ stash recovery tags pushed to origin (`refs/tags/recovery/stash-N-*`) plus Wave-2 recovery tags for PR #74, PR #79, and the B-prime uncommitted follow-up stash.
- W-rows wired: **about 42/53 strict, about 49/53 strict+partial** after Wave 4 plus W-49/W-53, Agent Capability Truth, and Provenance / Residency Detail closeouts. Known advances: Eidos real bridge/citation gate (#66), System G real seam (#67), falsifier harnesses (#68/#74), Substrate Health/docs/unified panel work (#69/#77), VaultRecall visibility salvage (#70/#79), T14 No-Orphan bridge (#71), SCOPE-Rex/SovereignGate production gate (#72; legacy module name `acs_admission`), Verified Floor truth gate (#78), Hyperdynamic Schema Loop (#75), Runtime Router (#76), typed UAS retrieval and ClaimLedger addresses (#121), PageGather vault escalation trace (#122), Cognitive DAG visualizer (#123), Tri-Fusion typed note mutations (#124), test-isolation/warning cleanup (#125/#127), W-49/W-53 source guards (`docs/audits/POST_WAVE4_W49_W53_HARDENER_CLOSEOUT_2026_05_27.md`), Agent Capability Truth source guards (`docs/audits/POST_WAVE4_AGENT_CAPABILITY_TRUTH_CLOSEOUT_2026_05_27.md`), and AnswerPacket substrate detail guards (`docs/audits/POST_WAVE4_PROVENANCE_RESIDENCY_DETAIL_2026_05_27.md`).
- Falsifier artifacts on main: **10 normalized witness artifact files** plus
  PageGather Metal side reports (`metal_failure_result.json` and
  `locality_probe_result.json`).
  - Schema-normalized primary witnesses: `F-VaultRecall-50`, `F-ULP-Oracle`, `F-Eidos-Bridge-RoundTrip`, `F-ACS-Anchor-Addressing` (full N=1000 four-stage harness), `F-HyperdynamicLoop-Bounded`.
  - Schema-normalized fallback/CPU witnesses: `F-PageGather-M2Pro`, `F-UAS-ZeroCopy-Spine` — PageGather's Metal/Swift hot-path dense throughput gate is still pending. `F-ControllerKernelPack` has advanced from preflight to a full Metal primary artifact. `F-PageGather-M2Pro` has a 2026-05-27 Metal preflight dispatch/equivalence guard, a 256 MB Metal failure report proving the current dense shader is correct but too slow, a locality probe, a Rust/Swift trace contract for the block-sorted schedule, a Metal dense destination-position contract, and a new packetized scheduled witness showing `(logical_position, value)` packet output at `0.729x` STREAM for 256 MB and `0.752x` STREAM for 512 MB with `0` sampled violations; dense restore remains too slow (`0.092x` / `0.058x` STREAM) and is not green. `F-ULP-Oracle` has also advanced from preflight to a full Metal primary artifact.
  - Former legacy-shape measured PASS artifacts now schema-normalized primary witnesses: `F-UAS-CopyCount`, `F-ACS-AnchorLookup`.
  - New file-backed residency primary witness: `F-UAS-ACS-MmapResidency` proves a deterministic 16 MiB mmap-backed KV-page slice can be addressed by UAS, leased through `ResidencyLease`, and recovered through AcsAnchor projection lookup with zero tracked hot-path copies. It does not green-light live MLX generation, residual-patched KV spill, or 70B local inference.
  - New caller-path fallback witness: `F-PageGather-Packetized-Caller` proves `VaultStore::hybrid_search_with_trace` consumes packetized retained-score PageGather output and defers dense restore; dense `F-PageGather-M2Pro` remains red.
  - New candidate/fallback route: `F-Qwen3-8B-128K-GGUF-Route` tracks the separate `unsloth/Qwen3-8B-128K-GGUF` lane as a schema-valid failure report; it can become a fallback witness only after local GGUF file, 128K metadata, runner, paired logits, and live metrics exist, and it never flips the canonical MLX KV gate.
  - New runtime witness: `F-ActiveAssembly-Minimal` is a schema-normalized primary synthetic packet-graph artifact (`N=1024`, `Q=100`) with `0` output-bound violations, `0.0021` cost ratio, `0.0322` firing ratio, and `117.709 us` p99 wall time; live model packet routing remains separately unmeasured.

### Open PRs

No merge-ready feature PRs. Two draft preservation PRs remain open and must not
be raw-merged:

- `#81` — Claude shadow-handle WIP preservation branch. The honest-handle
  product slice is closed on main; see
  `docs/audits/CLAUDE_SHADOW_HANDLE_CLOSEOUT_2026_05_26.md`.
- `#82` — B-prime uncommitted follow-up preservation branch. Current product
  recovery is closed on main; see
  `docs/audits/B_PRIME_FOLLOWUP_CLOSEOUT_2026_05_26.md`.

`main` and `origin/main` were aligned at `c8c4b50f15` before the F-ULP Metal
artifact slice. The
finished-vs-preserved architecture recovery split lives in
`docs/audits/MAIN_ARCHITECTURE_RECOVERY_STATUS_2026_05_26.md`; use `git log -1`
for the exact current commit.

**Post-merge gate:** passed on 2026-05-27.
- `cargo run --manifest-path agent_core/Cargo.toml --release --bin falsifier_validator ...` passed for the three Round-2 artifacts.
- `cargo test --manifest-path agent_core/Cargo.toml --lib --quiet` passed: 4,052 tests after the ControllerKernelPack primary artifact slice.
- `Tools/metal-shader-compile/metal-shader-compile.sh` passed: 26 shaders compile, with honest deferred warnings for SemiseparableBlockScan / PageGather / PacketRouter1bit.
- `swift Tools/metal-witness-gates/fulp-metal-oracle-artifact.swift --write-artifact` passed and emitted a primary `F-ULP-Oracle` Metal artifact.
- `swift Tools/metal-witness-gates/controller-kernel-pack-artifact.swift --write-artifact` passed and emitted a primary `F-ControllerKernelPack` Metal artifact; `cargo run --manifest-path agent_core/Cargo.toml --release --bin falsifier_validator -- artifacts/falsifiers/controller_kernel_pack/result.json` passed.
- `swift Tools/metal-witness-gates/page-gather-metal-artifact.swift --working-sets-mb 256 --window-seconds 5 --trials 3 --warmup-iterations 3 --write-artifact` failed honestly and emitted `artifacts/falsifiers/page_gather/metal_failure_result.json`; no PageGather green promotion.
- `swift Tools/metal-witness-gates/page-gather-metal-artifact.swift --probe-locality --working-sets-mb 256 --window-seconds 5 --trials 3 --warmup-iterations 3 --write-artifact` emitted `artifacts/falsifiers/page_gather/locality_probe_result.json`; block-sorted read-local scatter crossed `0.70x` at 256 MB.
- `swift Tools/metal-witness-gates/page-gather-metal-artifact.swift --probe-locality --working-sets-mb 16 --window-seconds 0.1 --trials 1 --warmup-iterations 0` exercised the new destination-position contract: `0` correctness violations, `0.3556x` STREAM, expected exit `2` because it is noncanonical and too slow. The canonical 256/512/1024 MB gate remains pending.
- `swift Tools/metal-witness-gates/page-gather-metal-artifact.swift --probe-locality --working-sets-mb 256,512 --window-seconds 2 --trials 2 --warmup-iterations 1 --write-artifact` updated `artifacts/falsifiers/page_gather/locality_probe_result.json`: packetized scheduled PageGather cleared `0.70x` at 256/512 MB (`0.729x` / `0.752x`, `0` sampled violations), while dense scheduled restore stayed pending (`0.092x` / `0.058x`). This is mitigation evidence, not a dense green promotion.
- `Tools/falsifiers/kv_direct_prompt_suite.sh` now emits `artifacts/falsifiers/kv_direct_gate/prompt_suite.json`: the canonical 100-prompt / 128K / 256-decode input manifest for the live Qwen3-8B KV run.
- `Tools/falsifiers/run_kv_direct_mlx_live.sh` now loads the local Qwen3-8B MLX snapshot and emits MLX runner outputs under `artifacts/falsifiers/kv_direct_gate/live_mlx/`. The 2026-05-28 smoke runs produced paired full-vocabulary logit rows and a `prompt_cache_reload` file-backed cache witness; the prompt-cache smoke wrote a 75 MB cache file and had low D_KL, but it used only 1 prompt / 512 context / 1 decode token with `spill_labeling=false`. The runner also accepts `--prompt-offset`, and `Tools/falsifiers/merge_kv_direct_mlx_shards.sh` merges restartable shards into the canonical falsifier input bundle. This is plumbing evidence only, not a green KV-Direct witness.
- `Tools/falsifiers/plan_kv_direct_mlx_shards.sh --shard-size 1 --prefill-step-size 512 --write-shell` now writes `artifacts/falsifiers/kv_direct_gate/live_mlx_full_suite_plan/full_suite_run_plan.json` plus `run_all_shards.sh`: a 100-shard, one-prompt-per-shard 128K / 256-decode execution map. The Capability Ceiling kernel reads this as `kv_direct_full_suite_run_plan_available=true`, while preserving `falsifier_green_capable=false` for the current `prompt_cache_reload` development route. The planner now records model identity and supports explicit `--model-path`; the separate candidate plan at `artifacts/falsifiers/kv_direct_gate/live_mlx_candidate_qwen3_coder_next_plan/full_suite_run_plan.json` targets `mlx-community/Qwen3-Coder-Next-4bit` and is marked `model_identity_matches_canonical=false`, so it is runtime research evidence only.
- `Tools/falsifiers/f_architecture_pending_work_guard.sh` now emits `artifacts/falsifiers/architecture_pending_work_guard/result.json`: the de-dup cursor for recursive loops. Current cursor is `repair_qwen3_8b_128k_gguf_metal_stall`: the canonical Qwen3-8B MLX snapshot still declares only `40960` context tokens with no rope scaling, so it remains red, but the separate GGUF split has advanced through local Q4_K_M model download, `131072` context metadata, llama.cpp runner installation, smoke bench metrics, smoke f16-KV-vs-q4_0-KV KL evidence, a 128K flash-attention stall witness, and a non-executing dry-run preview. The preserved MLX `shard_000_000` failure still proves the first 128K prompt emitted zero rows (`2048` prefill: Metal interactivity abort; `512` prefill: stopped after about 14 minutes), but agents must not rerun or recreate that shard work until the GGUF backend/cache-policy stall or canonical model-context contract is resolved.
- `Tools/audits/kv_direct_model_context_inventory.sh` now emits `docs/audits/KV_DIRECT_MODEL_CONTEXT_INVENTORY_2026_05_28.json`: a read-only local model-config inventory for the KV-Direct context floor. It confirms the canonical Qwen3-8B local asset is not 128K-capable, while local alternate long-context development candidates exist (`mlx-community/Qwen3-Coder-Next-4bit` at `262144` tokens is the current best text-generation candidate). Alternates are development evidence only unless canon explicitly changes the F-KV-Direct-Gate model.
- `docs/audits/KV_DIRECT_CANONICAL_MODEL_RESOLUTION_2026_05_28.md` records the model-contract conclusion from the local inventory plus Hugging Face primary repo checks: the canonical Qwen/Qwen3-8B-MLX-4bit target is present and identity-correct but context-red; 128K alternatives found so far are GGUF/derivative or noncanonical MLX candidates. The next work is resolving that exact contract or explicitly retargeting the falsifier, not recreating runner scaffolding.
- `Tools/falsifiers/f_qwen3_8b_128k_gguf_route.sh` now emits and validates `artifacts/falsifiers/qwen3_8b_128k_gguf_route/result.json` as a schema-valid red candidate/fallback route for `unsloth/Qwen3-8B-128K-GGUF`. The local route now has the Q4_K_M GGUF file, config metadata at `131072` context tokens, llama.cpp 9370, a 1-prompt / 32768-context / 256-decode f16-KV bench point (`9.26873779296875` GB peak RSS, `32.445546` decode tok/s), a smoke KL witness (`average_d_kl_nats=0.000402`), the 2026-05-29 probe ladder, and a dry-run preview manifest with `not_executed=true` / `falsifier_green_capable=false`. Current next bottleneck is `repair_qwen3_8b_128k_gguf_metal_stall`; this lane stays separate from the canonical MLX `F-KV-Direct-Gate`.
- `Tools/audits/epistemos_worktree_inventory.sh` now emits `docs/audits/LOCAL_EPISTEMOS_WORKTREE_INVENTORY_2026_05_28.json`: a read-only inventory of Epistemos-looking Downloads folders/worktrees. Current scan found 40 candidates, 34 sibling worktrees, and 24 high duplicate-risk dirty surfaces; preserve/inspect them before creating more terminal folders.
- `Tools/falsifiers/f_kv_direct_gate.sh` now emits and validates `artifacts/falsifiers/kv_direct_gate/result.json` as a schema-valid red harness contract: Tier-1 Rust direct/reference QK equality passes over 1,000 traces, the prompt-suite manifest passes shape checks, and the gate now accepts real model/logit/metrics/spill inputs through explicit env vars. It also guards model identity separately from context: current identity is canonical (`Qwen/Qwen3-8B-MLX-4bit`), but model-context support is red at `40960 < 128000`, so live Qwen3-8B / 128K / SSD-spill axes remain red until both a canonical 128K-capable model/config and the measurement artifacts exist locally.
- The KV spill trace parser now rejects noncanonical route labels. Prompt-cache reload remains useful plumbing evidence, but cannot flip `F-KV-Direct-Gate` even with low D_KL unless the trace proves the residual-patched mmap/NF4 SSD-spill oracle.
- `Tools/falsifiers/f_sparse_runtime_split.sh` now emits and validates `artifacts/falsifiers/sparse_runtime_split/result.json` as a schema-valid primary synthetic sparse/runtime witness: `0.0` average KL over 1000 prompts, `0.0176` active assembly ratio, `0.0067` cost ratio, and EML/Geometry/Scan/Operator chart labels. This is substrate evidence, not a live 70B sparse runtime.
- `Tools/falsifiers/f_70b_local_cocktail_lite.sh` now emits and validates `artifacts/falsifiers/70b_local_cocktail_lite/result.json` as a schema-valid red preflight. Expected exit is non-zero while sentinel quality/latency axes fail; the artifact names the current 70B bottleneck instead of allowing dense MLX to impersonate the ColdStore/UAS cocktail.
- `Tools/falsifiers/f_agent_local_model_runtime_bridge.sh` now emits and validates `artifacts/falsifiers/agent_local_model_runtime_bridge/result.json` as a schema-valid primary witness for the guarded local-model bridge slice. It proves the local catalog/runtime surfaces exist, the Rust LocalAgent adapter can produce a typed local MLX dispatch plan, Rust System G emits a local-model handoff for provider-aware LocalMlx runs, Swift consumes that handoff through the registered local client, and the retained live prompt-suite artifact records local-model AnswerPacket provenance. Its current bottleneck is `ready_for_capability_ceiling_recheck`; 128K KV and 70B/UAS routes remain separately gated.
- `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosTriFusionTypedMutationGate build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""` passed for the Wave-4 checkpoint; rerun a fresh build after this artifact slice before tagging.
- Focused Metal witness test passed after the ControllerKernelPack artifact slice: `./scripts/xcodebuild_epistemos.sh ... test -only-testing:EpistemosTests/MetalWitnessGatesTests` ran 3 Swift Testing tests successfully.
- Focused graph/editor guard passed after the lost-work restoration: `GraphPerformanceTests`, `GraphPhysicsSettingsAuditTests`, and `HTMLWorkspaceSourceGuardTests` all passed.
- Latest pushed checkpoint before this artifact slice: `checkpoint/post-wave4-metal-witness-preflight-2026-05-27`.

**Capability Ceiling note:** Dense MLX and ColdStore/UAS are separate routes. Dense
36B remains gated at 32 GB + explicit opt-in. The desired 16 GB / 70B-class
path is not deleted; it is gated by `F-70B-Local-Cocktail`,
`F-KV-Direct-Gate`, `F-UAS-CopyCount`, PageGather caller-path packet
consumption, `F-Agent-Local-Model-Runtime-Bridge`, active assembly, sparse
runtime split, and EML/Geometry/Scan IR lowering evidence.
The first 70B row-root now exists as a red preflight artifact; it is a map to
the ceiling, not a claim that the ceiling has been reached.
The Capability Ceiling Evaluation Kernel now rolls these artifacts into one
schema-valid route verdict and must be rerun before promotion.

## 7 · The 13-terminal dispatch deck (status grid)

Full prompts: `docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md`. **Wave 1 = foundations.** Resume patch (rev 2) lives in that doc.

| Terminal | Owner | Scope | Status | Wave |
|---|---|---|---|---|
| **T0** | done | Verified Floor / Settings Truth + T25 lint + W-13 + W-32 | merged in #78 | 2 |
| **T1** | done | Runtime Router (MLX one lane among ≥4) + RuntimeExecutor abstraction + F-LocalToolUse scaffold | merged in #76; direct build hotfix `77c7efe9ea` | 2 |
| **S** | done | Hyperdynamic Schema Loop primitive + 3 loop impls + F-HyperdynamicLoop-Bounded | merged in #75 | 2 |
| **B′** | done | Chat citation UI integration (wire badge + provenance card into rows) + W-19/20/27 closure | merged in #79; uncommitted follow-up preserved and documented | 2 |
| **D′** | done | Substrate Health Panel row expansion (5 missing rows + W-30 Cognitive Weight badges) | merged in #77 | 2 |
| **F′** | done | Falsifier round 2 — get to ≥ 7 MEASURED PASS on M2 Pro | merged in #74 | 2 |
| **G** | done | T14 Five-Plane wiring + No-Orphan + F-UAS-CopyCount + F-ACS-AnchorLookup | merged in #71 | 1 |
| **A** | done | Eidos real vault binding | merged in #66 | 2 |
| **B** | done (partial scope) | Vault Recall trace + chat citation files | #70 salvaged badges/cards/blocker docs; UI integration in B′ | 2 |
| **C** | done | System G full path | merged in #67; test-isolation fix in #125 | 3 |
| **D** | done (partial scope) | Substrate Health Panel unification | #69/#70/#71/#72 advanced rows; row expansion in D′ | 2 |
| **E** | done | SCOPE-Rex/SovereignGate admission production gate | merged in #72; ACS anchor-addressing D-27 full harness completed by `docs/audits/ACS_ANCHOR_HARNESS_FULL_2026_05_27.md`; legacy module name remains `acs_admission` | 3 |
| **F** | done | ≥ 5 falsifiers PASS on M2 Pro | merged in #68; 7 artifacts now on main after #71; round 2 in F′ | 4 |
| **UAS-Typed** | done | Typed UAS retrieval + ClaimLedger/AcsAnchor address fields | merged in #121 | 4 |
| **PageGather** | done | Vault escalation trace + no LIMIT-first-note fallback | merged in #122 | 4 |
| **Cognitive DAG** | done | Live Graph panel for NodeKind/EdgeKind counts without render-loop work | merged in #123 | 4 |
| **Tri-Fusion** | done | Model-authored note edits as typed reversible `MutationEnvelope` operations | merged in #124 | 4 |
| **H** | not started | Research Construction Engine (scoping only) | hold until Wave 2 stabilizes | 4 |
| **R** | continuous | Online Research Intake + Fork Mining | dispatched as-needed | continuous |
| **X** | continuous | Worktree Salvage continuation | dispatched as-needed | continuous |

### Wave-2 close checklist (2026-05-26)

1. All six Wave-2 PRs merged: **#78 → #77 → #75 → #76 → #79 → #74**.
2. Main build break from #76 repaired directly on main at `77c7efe9ea`.
3. B-prime uncommitted follow-up work is closed for current product recovery; it remains preserved as stash/tag/patch and documented by `docs/audits/B_PRIME_FOLLOWUP_CLOSEOUT_2026_05_26.md` until the user approves retiring old recovery refs.
4. `stash@{15}` graph/filter recovery is closed for current product work by `docs/audits/STASH15_SELECTED_NEIGHBOR_EXPANSION_2026_05_26.md` and `docs/audits/STASH15_GRAPH_CLOSEOUT_2026_05_26.md`; keep it only as a preserved graph/performance donor reference.
5. VaultRecall/Eidos visibility from `stash@{3}` and the chat/VaultRecall slice of `stash@{6}` is closed for current product work by `docs/audits/VAULT_RECALL_EIDOS_STASH_CLOSEOUT_2026_05_26.md`; keep `stash@{3}` as preservation-only.
6. The remaining non-chat docs/lattice-coordinate explainer donor slice of `stash@{6}` is closed by `docs/audits/STASH6_NONCHAT_DONOR_CLOSEOUT_2026_05_26.md`; current `main` keeps the newer explainer and ports the Phase 2 / Legendary / Master Research Index addenda.
7. `stash@{17}` Landing Wave / Session Intelligence recovery is closed by `docs/audits/STASH17_LANDING_WAVE_CLOSEOUT_2026_05_26.md`; current `main` keeps the newer fused landing/chat/ambient route. Landing Wave source family is retired from live product source; Session Intelligence remains.
8. `stash@{16}` honest-handle + approval UI donor recovery is closed for current product work by `docs/audits/CLAUDE_SHADOW_HANDLE_CLOSEOUT_2026_05_26.md` and `docs/audits/STASH16_APPROVAL_UI_DONOR_CLOSEOUT_2026_05_26.md`.
9. `stash@{16}` / `stash@{19}` editor donor recovery is closed by `docs/audits/STASH16_19_EDITOR_DONOR_CLOSEOUT_2026_05_26.md`; current `main` keeps the compressed editor bundle, KaTeX `.woff2` resources, Xcode-style code colors, and live `CodeEditSourceEditor` route.
10. `stash@{2}`, `stash@{5}`, `stash@{7}`, `stash@{8}`, `stash@{9}`, `stash@{13}`, `stash@{14}`, and the remaining `stash@{18}` donor queue are closed for current product recovery by `docs/audits/STASH_SUBSTRATE_RESEARCH_QUEUE_CLOSEOUT_2026_05_26.md`; no active product-recovery stash rows remain.
11. The lattice coordinate explainer is preserved and checkpointed at `artifacts/lattice-coordinate-explainer/index.html`; it keeps the ambition map but now carries the post-Wave-2 overlay so old "pending Terminal G" rows do not override current main.
12. Wave 3/4 closure through `#125` is on `main`: typed UAS retrieval/ClaimLedger rows, PageGather escalation traces, Cognitive DAG visualizer, and Tri-Fusion typed mutations are no longer pending.
13. Fresh roll-up / dispatch map: `docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md`.
14. Historical Wave 3/4 terminal deck: `docs/audits/WAVE3_WAVE4_TERMINAL_DISPATCH_2026_05_26.md`.

## 8 · Deferred-work ledger (26 items, anti-loss)

Full register: `docs/DEFERRED_WORK_GUARANTEE_2026_05_23.md`. One-liners:

| ID | Item | Re-promotion trigger |
|---|---|---|
| D-01 | T6 UI/UX polish | Phase 3 UI cycle |
| D-02 | T8 Biometric Lock code | T1+T2+T6 land |
| D-03 | XPC Mastery 5-service | `RESUME XPC MASTERY` |
| D-04 | F-KV-Direct-Gate harness | Terminal F dispatch |
| D-05 | T20 Variant Ladder | `RESUME T20` |
| D-06 | T26 L_SE Self-Evolving | `RESUME L_SE RESEARCH` |
| D-07 | Schema-First GenUI G.1-G.6 | every new UI component |
| D-08 | 5 V6.1 Metal kernels | Phase 3 Research |
| D-09 | F-70B-Local-Cocktail | `RESUME F-70B` |
| D-10 | Per-IR Lean proofs (28 sorries → 0) | `RESUME LEAN PROOFS` |
| D-11 | Simulation Mode v1.7+ | Phase 3 polish |
| D-12 | Quick Capture Pro tools | `RESUME PRO TOOLS` |
| D-13 | NightBrain 4 eligibility + 6 task bodies | V1.x post-Floor |
| D-14 | Custom local model | Post-v2.0 tag |
| D-15..D-26 | T10B / T15 / T16 / T17 / T18 / T19 / T24 / W-09 / W-18 / W-30 / W-31 / W-51 | see ledger doc |

**The promise:** no deferred item ages out of memory. Every item has a build target + codeword.

## 9 · Codeword index (summon-by-word)

| Codeword | What it triggers |
|---|---|
| **`LEGENDARY`** | Full no-compromise check + dispatch the deck. Spec: `docs/LEGENDARY_CODEWORD_2026_05_23.md`. **Default summon for "I'm back, what's the state?"** |
| `RESUME SUBSTRATE V2` | Continue V2.1–V2.7 post-recovery plan |
| `RESUME RESEARCH TIER` | V3 research-tier work |
| `RESUME XPC MASTERY` | 5-service decomposition (D-03) |
| `RESUME T20` | Variant Ladder (D-05) |
| `RESUME L_SE RESEARCH` | Self-Evolving Adapter (D-06) |
| `RESUME F-70B` | 70B Local Cocktail study (D-09) |
| `RESUME LEAN PROOFS` | Per-IR Lean proofs (D-10) |
| `RESUME PRO TOOLS` | Quick Capture Pro tools (D-12) |
| `RESUME LIVE FILE COMPILER` | T16 (D-17) |
| `RESUME LEAN AUTHORITY` | T24 (D-21) |
| `FORK V3` | Second-repo end-game from post-v2.0 main |
| `RESEARCH CONSTRUCTION` | Run conjecture-mode against open falsifier / W-row |

## 10 · How to resume work — flat protocol (no abstraction layers)

**If you just want to resume:**

```text
1. Open this file (you're already here).
2. Read §6 CURRENT STATE — know what's wired vs pending.
3. Read §7 terminal grid — find what's stopped, what's done, what's next.
4. If reading as an agent:
   - Pick your terminal (from §7).
   - Read your row in §7 for scope.
   - Read your terminal's full prompt in docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md.
   - Paste the rev-2 Resume patch from that doc into your session.
   - Continue your loop: Audit → Build → Verify → Harden → Report.
5. If reading as the user:
   - Current checkpoint before this artifact slice: `checkpoint/post-wave4-metal-witness-preflight-2026-05-27`.
   - No open merge-ready feature PRs remain; only preservation draft PRs `#81` and `#82` are open.
   - First run the post-merge local gate: cargo lib + xcodebuild.
   - If green → use the codeword queue in `docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md`; the product-floor terminals are retired or complete.
6. Every PR carries the No-Orphan check:
   Motion · UAS · Plane · Residency · WBO/error · Witness · Falsifier · Tier · Rollback.
7. NEVER `git checkout <stash> -- file`. Use `git apply` patches. PR #59 → #60 lesson.
```

**That's the entire protocol.** No further indirection.

## 11 · Cross-references (only descend when you need specific detail)

Read these only when this index doesn't already answer your question.

### Architecture canon
- `docs/fusion/UNIFIED_ACTIVE_SUBSTRATE_CANON_2026_05_16.md` — UAS-ACS as one substrate (the original canon)
- `docs/fusion/ADDRESSABLE_NEURAL_SUBSTRATE_CANON_2026_05_24.md` — SSM-router + neuron-cluster target (your original no-compromise idea, locked in canon)
- `docs/fusion/SHADOW_PROJECTION_AND_RESEARCH_CONSTRUCTION_2026_05_24.md` — Erdős + Parameter Golf doctrine + substrate-vs-LLM ladder + Substrate Motion Invariant
- `docs/fusion/ONLINE_RESEARCH_INTAKE_SHADOW_PROJECTION_2026_05_24.md` — credibility ladder for arXiv / forks / forums
- `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` — E1-E7 + H1-H17 + PCF-1..10 formal canon

### Registers + audits
- `docs/CANONICAL_CHRONICLE_2026_05_23.md` — every name, T-track, W-row, doctrine, falsifier (the deep audit)
- `docs/LEGENDARY_ARCHITECTURE_NO_COMPROMISE_AUDIT_2026_05_23.md` — preservation matrix · 53 W-rows mapped to terminals · 26 deferred items · tier promotions
- `docs/audits/CROSS_TERMINAL_WIRING_BACKLOG_2026_05_17.md` — 53 W-rows source
- `docs/audits/MODEL_GATING_MATRIX_2026_05_23.md` — model-gating audit (Issue-2026-05-16-015)

### Operational
- `docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md` — all 13 terminal prompts + rev-2 Resume patch
- `docs/LEGENDARY_CODEWORD_2026_05_23.md` — LEGENDARY codeword spec
- `docs/DEFERRED_WORK_GUARANTEE_2026_05_23.md` — D-01..D-26 ledger
- `docs/SANITIZATION_LOOP_TRACKER_2026_05_23.md` — sanitization-loop record (stashes, branches, worktrees triaged)
- `docs/WHATS_LEFT_2026_05_23.md` — end-of-session what's-open report
- `docs/APP_ISSUES_AUTO_FIX.md` — runtime issue register for opportunistic fixes

### User-facing
- `README.md` — public pitch
- `artifacts/lattice-coordinate-explainer/index.html` — paper-style architecture synthesis (with ChonkyPixels headers)

### Memory
- `~/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/MEMORY.md` — persistent agent memory index
- `~/.claude/projects/-Users-jojo-Downloads-Epistemos/memory/reference_legendary_codeword.md` — codeword memory entry

---

## 12 · Honest summary (always end on this)

**What is empirically defensible.** The substrate Epistemos has been building — lift to a typed higher-dim lattice, operate in compressed-and-active form, project to a surface with a witness, account error in WBO — is validated externally by Erdős unit-distance (lift-and-project finds new constructions) and Parameter Golf (compressed-and-active models beat uncompressed dense models per byte).

**What still needs measurement, not faith.** F-Erdős-Lift-Optimality · F-KV-Direct-Gate prompt-level 128K run · live model-backed F-Sparse-Runtime-Split · F-LocalToolUse · F-HyperdynamicLoop-Bounded · F-70B-Local-Cocktail prompt-level run · primary Metal/Swift hot-path versions of F-PageGather-M2Pro and F-UAS-ZeroCopy-Spine. F-ULP and F-ControllerKernelPack now have full Metal primary artifacts, PageGather has packetized mitigation evidence plus a dense-restore failure, Active Assembly and Sparse Runtime Split have primary synthetic runtime witnesses, KV-Direct has a red harness contract proving Tier-1 equality and ready to consume real Qwen/MLX logits and metrics but not the live SSD-spill gate, the agent local-model bridge has a schema-valid primary witness for the guarded local bridge slice, and the 70B cocktail now has a schema-valid red preflight row-root. Substrate is sound; measurements must keep landing.

**The unified cognitive substrate is no longer a thesis.** It is a substrate with two independent external proofs that its primitives are the correct primitives. The remaining work is execution.

---

*This is the only doc to summon when you return. Everything else descends from §11.*
