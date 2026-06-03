# LEGENDARY Post-Wave-4 Roll-Up - 2026-05-27

> **2026-06-01 current canon bridge (JUNE1-PATTERNBOOST-LOCK):** This file is preserved as a legacy, planning, research, or witness artifact. For active architecture, route Helios/UAS/ACS/mmap/KV-Direct/70B/NeuralImportance claims through `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`, `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`, `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`, and `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`. Legacy claims remain historical until promoted by falsifiers, AnswerPacket evidence, LatticeAbstentionGate, ComputeResumeLease, rollback, and the intentional-copy/zero-copy caveat.

Status: ground-truth checkpoint after Wave 4 and the post-merge audit pass.

Base commit before the F-ULP Metal artifact slice: `c8c4b50f15`
(`test(metal): add witness gate preflight (#133)`).

Latest checkpoint tag before the F-ULP Metal artifact slice:
`checkpoint/post-wave4-metal-witness-preflight-2026-05-27`.

This document is the post-Wave-4 answer to: "What is done, what is preserved
only, what is still partial, and what terminals should run next?"

## Evidence Gates

These passed after PRs `#121` through `#127` landed:

- `cargo test --manifest-path agent_core/Cargo.toml --lib --quiet`
  - 4,042 tests passed.
- `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosTriFusionTypedMutationGate build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`
  - build passed.
- `rustup run stable-aarch64-apple-darwin cargo test` in `graph-engine`
  - 2,777 lib tests plus integration/doc tests passed.
- `npm run typecheck` in `js-editor`
  - passed.
- Focused graph/editor guard:
  - `GraphPerformanceTests`
  - `GraphPhysicsSettingsAuditTests`
  - `HTMLWorkspaceSourceGuardTests`
  - passed, 65 tests / 3 suites.

Performance guard highlights from the focused run:

- 100 graph nodes loaded in 0.006s.
- 500 graph nodes loaded in 0.028s.
- 1,000 graph nodes loaded in 0.057s.
- 5,000 graph nodes loaded in 0.268s.
- 5,000-node fuzzy graph search completed in 0.352s.
- Gravity Well / snappy defaults and HTML Workspace source guards passed.

No stash was popped, dropped, bulk-applied, or checked out from during this
checkpoint.

Additional 2026-05-27 Metal witness evidence after the preflight slice:

- `Tools/metal-shader-compile/metal-shader-compile.sh`
  - passed; 26 shaders compile, with deferred warnings still emitted for
    SemiseparableBlockScan / PageGather / PacketRouter1bit.
- `swift Tools/metal-witness-gates/fulp-metal-oracle-artifact.swift --write-artifact`
  - passed; emitted `artifacts/falsifiers/ulp_oracle/result.json` as a full
    Metal `morphOracleFp16` primary witness.
- `cargo run --manifest-path agent_core/Cargo.toml --release --bin falsifier_validator -- artifacts/falsifiers/ulp_oracle/result.json`
  - passed.
- `swift Tools/metal-witness-gates/controller-kernel-pack-artifact.swift --write-artifact`
  - passed; emitted `artifacts/falsifiers/controller_kernel_pack/result.json`
    as a full Metal `ControllerKernelPack` primary witness.
  - Zero correctness violations; empty `maxReduce` returns `NaN`; empty
    `argmaxReduce` returns `UInt32.max`; worst p99 is `20.06510408136819 us`;
    100-cycle wall is `2.745417 ms`.
- `cargo run --manifest-path agent_core/Cargo.toml --release --bin falsifier_validator -- artifacts/falsifiers/controller_kernel_pack/result.json`
  - passed.
- `./scripts/xcodebuild_epistemos.sh ... test -only-testing:EpistemosTests/MetalWitnessGatesTests`
  - passed; 3 Swift Testing tests in the Metal witness suite.
- `cargo test --manifest-path agent_core/Cargo.toml --lib --quiet`
  - passed; 4,052 tests.
- `swift Tools/metal-witness-gates/page-gather-metal-artifact.swift --working-sets-mb 256 --window-seconds 5 --trials 3 --warmup-iterations 3 --write-artifact`
  - failed honestly; wrote `artifacts/falsifiers/page_gather/metal_failure_result.json`.
  - The shader produced correct values but random scatter reached only about
    `0.064x` measured STREAM, so `F-PageGather-M2Pro` remains orange/pending.
- `swift Tools/metal-witness-gates/page-gather-metal-artifact.swift --probe-locality --working-sets-mb 256 --window-seconds 5 --trials 3 --warmup-iterations 3 --write-artifact`
  - wrote `artifacts/falsifiers/page_gather/locality_probe_result.json`.
  - Local-window scatter reached about `1.08x` measured STREAM and
    block-sorted read-local scatter reached about `0.734x` measured STREAM with zero
    sampled correctness violations. This is a mitigation lead, not a full
    `F-PageGather-M2Pro` pass.
- `agent_core::helios::block_sorted_schedule` + `gather_block_sorted`
  - now provide the scheduler-side block-sorted execution contract and restore
    logical output order. Vault Recall traces surface the schedule as
    deferred evidence, while the chip remains orange/pending.
- `pageGatherScatterScheduled`
  - now provides the Metal destination-position contract. A tiny noncanonical
    smoke probe showed `0` correctness violations but only `0.3556x` STREAM at
    16 MB, so the real scheduled path still needs optimization before any green
    promotion.
- `pageGatherPacketizeScheduled`
  - now provides the lean witness-coordinate packet contract. The 256/512 MB
    diagnostic artifact at `artifacts/falsifiers/page_gather/locality_probe_result.json`
    shows packetized scheduled PageGather at `0.729x` / `0.752x` measured
    STREAM with `0` sampled violations. Dense restore remains too slow
    (`0.092x` / `0.058x`), so this is mitigation evidence, not a dense green.
- Capability Ceiling model gate hardening
  - `docs/audits/CAPABILITY_CEILING_MODEL_GATE_2026_05_27.md` preserves the
    70B / ACS / UAS / SSD+RAM northstar while preventing dense 36B MLX
    power-user mode from pretending the cocktail has passed. Dense 36B remains
    a 32 GB + explicit opt-in path until `F-70B-Local-Cocktail` or an
    equivalent SSD/RAM composition artifact passes. EML-everything is preserved
    as the rule that eligible weights, layers, kernels, and transforms expose
    EML / Geometry / Scan / Operator charts rather than opaque blobs.
- 70B cocktail preflight row-root
  - `Tools/falsifiers/f_70b_local_cocktail_lite.sh` now writes and validates
    `artifacts/falsifiers/70b_local_cocktail_lite/result.json` as an
    intentional red failure report. The artifact records sentinel D_KL /
    decode / TTFT / RSS failures plus a named bottleneck, so future work has a
    concrete axis to turn green without weakening the dense MLX gate.
- KV-Direct preflight row-root
  - `Tools/falsifiers/kv_direct_prompt_suite.sh` now writes the canonical
    100-prompt / 128K / 256-decode prompt suite at
    `artifacts/falsifiers/kv_direct_gate/prompt_suite.json`.
  - `Tools/falsifiers/run_kv_direct_mlx_live.sh` now loads the local Qwen3-8B
    MLX snapshot and emits MLX runner contract files under
    `artifacts/falsifiers/kv_direct_gate/live_mlx/`; the first smoke run is
    intentionally undersized and non-SSD. The runner now also has a
    `prompt_cache_reload` route that saves an MLX prompt cache to disk,
    reloads it, and emits test logits. The smoke cache-reload run produced a
    75 MB cache file with low D_KL, but it is still a file-backed reload
    witness, not the residual-patched mmap/NF4 SSD-spill oracle.
  - The same runner now accepts `--prompt-offset`, and
    `Tools/falsifiers/merge_kv_direct_mlx_shards.sh` merges restartable shard
    directories into one paired-logit / metrics / spill-trace bundle for the
    falsifier. This makes the real 100-prompt run resumable without weakening
    the SSD-spill axis.
  - `Tools/falsifiers/plan_kv_direct_mlx_shards.sh --shard-size 1 --prefill-step-size 512 --write-shell` now writes
    the 100 one-prompt shard full-suite execution plan at
    `artifacts/falsifiers/kv_direct_gate/live_mlx_full_suite_plan/full_suite_run_plan.json`
    plus `run_all_shards.sh`. The Capability Ceiling kernel consumes this as
    `kv_direct_full_suite_run_plan_available=true`, while the plan stays
    `falsifier_green_capable=false` for the current `prompt_cache_reload`
    development route. The planner also accepts explicit `--model-path` and
    records model identity; the separate
    `live_mlx_candidate_qwen3_coder_next_plan` is marked
    `model_identity_matches_canonical=false` and stays candidate-tier.
  - The first planned 128K shard, `shard_000_000`, now has failure evidence:
    `prefill_step_size=2048` hit a Metal interactivity command-buffer abort,
    and `prefill_step_size=512` was stopped after about 14 minutes with zero
    completed prompt rows. That failure remains preserved, but the KV gate now
    separately guards model identity and context. The resolved model identity is
    canonical (`Qwen/Qwen3-8B-MLX-4bit`), while the local config declares only
    `40960` context tokens with no rope scaling. The pending-work guard therefore names
    `resolve_qwen3_8b_128k_context_model_assets_for_kv_direct` as the next
    cursor.
  - `Tools/falsifiers/f_kv_direct_gate.sh` now writes and validates
    `artifacts/falsifiers/kv_direct_gate/result.json` as an intentional red
    failure report. The artifact records zero Tier-1 Rust QK equality
    violations over 1,000 traces and a passing prompt-suite shape, then keeps
    the live Qwen3-8B / 128K / SSD-spill metrics red until a canonical
    128K-capable model/config and actual MLX measurement land.
  - The KV spill trace is now semantic, not just present. A green path must
    name `residual_patched_mmap_nf4_ssd_spill`, set residual patching and
    mmap-backed cold KV evidence, label NF4/equivalent storage, and report
    positive cold-KV bytes. Prompt-cache reload cannot satisfy this axis.
- Optional non-MLX long-context candidate split
  - Removed from the active architecture queue on 2026-06-03 at user request.
    It does not satisfy the canonical MLX `F-KV-Direct-Gate`, and future work
    should not recreate this split unless canon explicitly retargets the gate.

## Main / PR State

- `main` equals `origin/main` at the base commit above.
- Open PRs are only preservation references:
  - `#81` - Claude shadow-handle WIP preservation.
  - `#82` - B-prime uncommitted follow-up stash preservation.
- Those PRs are not merge-ready product work. Do not raw-merge them unless a
  separate synthesis pass promotes a focused slice.

## W-Row Recount

The old `~34/53+` count was intentionally conservative before Wave 4 closed.
The honest post-Wave-4 accounting is:

- Strictly wired / product-visible enough to count: about `42/53`.
- Meaningfully advanced but still honest-orange or partial: about `7/53`.
- Still open / Pro Research backlog: about `4/53`.

Percentages:

- Strict wired floor: about 79%.
- Strict + meaningful partial: about 92%.
- Substrate floor estimate: about 96%, because the remaining gaps are mostly
  visible truth, provenance-detail, and hardware/research gates
  rather than missing substrate skeleton.

Rows closed or materially advanced by Wave 4:

| Row | Current state | Evidence |
|---|---|---|
| W-01 | wired | Vault retrieval projects typed `UasAddress` values (#121). |
| W-02 | wired | Agent traces expose typed `UasKind::AgentTrace` addresses (#121). |
| W-03 | wired | ClaimLedger claims can carry `UasAddress` and `AcsAnchor` (#121). |
| W-04 | partial/product trace live | PageGather escalation is trace-visible and LIMIT-first-note fallback is removed (#122); full Metal/PageGather gate remains future. |
| W-06 | partial/product path live | One safe model-authored note edit travels as typed reversible `MutationEnvelope` (#124). |
| W-12 | wired/guarded | Per-model agent badges derive `HONEST` / `EXPERIMENTAL` / `OFF` from RuntimeRouter + F-LocalToolUse and surface in Settings, picker rows, ActiveConstellation, and AgentBlueprint. See `docs/audits/POST_WAVE4_AGENT_CAPABILITY_TRUTH_CLOSEOUT_2026_05_27.md`. |
| W-19 | wired | Chat/Vault retrieval uses provenance instead of hidden LIMIT-first-note context. |
| W-20 | wired | Provenance cards and citation surfaces are live after B-prime recovery. |
| W-21 | wired with caveat | VaultRecall metrics have measured artifacts; paraphrase metric remains lexical/informational. |
| W-22 | wired | Retrieval returns typed addresses (#121). |
| W-23 | wired | Vault Context Contract gate exists and passed in Wave 4 validation. |
| W-24 | wired | DAG/claim rows carry UAS/anchor/plane/residency metadata from T14 + #121. |
| W-25 | wired/guarded | ACS anchor data exists and the chat AnswerPacket badge now opens a compact UAS / ACS anchor / plane / residency detail popover. See `docs/audits/POST_WAVE4_PROVENANCE_RESIDENCY_DETAIL_2026_05_27.md`. |
| W-26 | wired | Cognitive DAG visualizer merged (#123). |
| W-27 | wired | AnswerPacket badge/provenance row surface is live from B-prime. |
| W-28 | partial/product visible | Residency types/guards exist and AnswerPacket detail now shows residency tier/signals; broader all-surface residency indicators remain a future polish slice. |
| W-29 | wired | Substrate Health panel is live. |
| W-30 | partial | Cognitive Weight badges exist in Settings; broader weight/residency display can still improve. |
| W-49 | wired/guarded | App Store guard for `IMessageDriverService` is already live; see `docs/audits/POST_WAVE4_W49_W53_HARDENER_CLOSEOUT_2026_05_27.md`. |
| W-53 | wired/guarded | `ModelDownloadManager` SHA256/LFS verification is already live; see `docs/audits/POST_WAVE4_W49_W53_HARDENER_CLOSEOUT_2026_05_27.md`. |

This recount does not delete the older 53-row audit. It gives a current
execution map from actual merged code and tests.

## Falsifier Recount

There are 10 `artifacts/falsifiers/*/result.json` files on main:

| Artifact | Status | Honest interpretation |
|---|---|---|
| `acs_anchor_lookup` | PASS | Product-relevant O(1)-style anchor lookup witness. |
| `uas_copy_count` | PASS | Product-relevant zero-copy/copy-count witness. |
| `vault_recall_50` | measured true | Current run passes exact-title and adversarial reject; paraphrase remains lexical/informational. |
| `eidos_bridge_round_trip` | measured true | Real Eidos bridge round-trip witness; Swift side covered by production bridge tests. |
| `hyperdynamic_loop_bounded` | measured true | Bounded repair loop witness. |
| `acs_anchor_addressing` | full measured true | N=1000 full harness with agent runtime emission, lookup, audit canonicalization, and five-plane projection inversion. See `docs/audits/ACS_ANCHOR_HARNESS_FULL_2026_05_27.md`. |
| `ulp_oracle` | measured true | Full Metal `morphOracleFp16` primary witness over 414,048 points / 1,242,144 evaluations; max ULP axes pass the <=2 budget. |
| `uas_zero_copy_spine` | measured true | Zero tracked copies in scoped spine; broader hot path can still be expanded. |
| `page_gather` | measured true + Metal failure/locality reports + scheduler/destination/packetized contracts | CPU scatter/PageGather artifact remains the fallback witness; 256 MB Metal STREAM-style run failed the dense primary ratio and is recorded at `artifacts/falsifiers/page_gather/metal_failure_result.json`. `artifacts/falsifiers/page_gather/locality_probe_result.json` now records the 256/512 MB M2 Pro packetized scheduled mitigation: `0.729x` / `0.752x` measured STREAM with `0` sampled violations. `block_sorted_schedule` gives the product path a real execution contract, `pageGatherScatterScheduled` restores dense logical output positions, and `pageGatherPacketizeScheduled` emits compact `(logical_position, value)` packets. Dense restore remains too slow, so the full primary gate remains pending. |
| `controller_kernel_pack` | primary Metal measured true | Full Metal primary witness at `artifacts/falsifiers/controller_kernel_pack/result.json`: 7-size x 100-seed correctness, empty-input contracts, p50/p99 latency budget, and 100-cycle sequence budget all pass. |

The `>=7 measured witnesses` objective is satisfied. The verified floor must
still keep hardware-caveat artifacts orange until their full production/hot-path
gate exists.

## Stashes And Preserved Work

The stash/recovery state is demystified as of this checkpoint:

- Product-recovered stash slices are already on main and documented.
- Preservation-only PRs `#81` and `#82` remain open as references, not product
  branches.
- The stash ledger remains the canonical map for old stash material:
  `docs/audits/STASH_RECOVERY_LEDGER_2026_05_26.md`.
- The broad substrate/research stash queue is closed for current product
  recovery by:
  `docs/audits/STASH_SUBSTRATE_RESEARCH_QUEUE_CLOSEOUT_2026_05_26.md`.
- The current rule remains: no stash pop/drop/bulk apply, and no raw restoration
  of legacy shells that current tests intentionally forbid.

## Seven Laws / No-Orphan Check

Wave 4 satisfies the No-Orphan check at the current floor:

- Motion: retrieval/claim work is Project/Recall; PageGather trace is
  Project/Recall; Tri-Fusion edits are Mutate/Promote.
- UAS: typed addresses are now present in retrieval, traces, claims, and ACS
  anchor boundaries.
- Plane: five-plane metadata is carried through T14 and used by DAG/claim
  surfaces.
- Residency: typed residency exists and has anti-drift guard docs/tests.
- WBO/error: approximation-heavy hardware witnesses remain caveated instead of
  green.
- Witness: RunEventLog, AnswerPacket, ClaimLedger, falsifier artifacts, and
  audit docs exist for the live motions.
- Falsifier: 10 artifacts exist; 7+ are measured.
- Tier: current-app vs verified-floor vs Pro Research claims are separated.
- Rollback: Tri-Fusion typed mutation path includes deterministic rollback for
  its first product operation.

Remaining No-Orphan risks are not lost work; they are the next focused slices:

1. Broader all-surface residency polish outside the AnswerPacket/detail rows.
2. Full hardware research gate for PageGather.
   A 2026-05-27 Metal preflight now dispatches the source kernels. `F-ULP-Oracle`
   and `F-ControllerKernelPack` have advanced to full Metal primary witnesses;
   PageGather remains pending instead of green.

## Next Terminals

The product-floor terminals below are retired or complete. Next work should be
codeword-triggered research/hardware slices, not another broad product merge wave.

### Retired Terminal - Agent Capability Truth

Do not dispatch. Current source already closes W-12. Evidence lives in
`docs/audits/POST_WAVE4_AGENT_CAPABILITY_TRUTH_CLOSEOUT_2026_05_27.md`.

### Retired Terminal - Provenance / Residency Detail

Do not dispatch after this slice merges. The product-floor visibility gap is
closed by `docs/audits/POST_WAVE4_PROVENANCE_RESIDENCY_DETAIL_2026_05_27.md`.

Branch used:

```text
codex/post-wave4-provenance-residency-detail-2026-05-27
```

Historical prompt:

```text
You are Post-Wave-4 Terminal 2: Provenance / Residency Detail.

cd /Users/jojo/Downloads/Epistemos
git fetch origin
git checkout -b codex/post-wave4-provenance-residency-detail-2026-05-27 origin/main

Read first:
1. docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md
2. docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md
3. docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md

Goal:
Close the visible detail gap around ACS anchors, residency, and cognitive
weight without mutating retrieval or graph hot paths.

Scope:
1. Add a clickable ACS anchor/detail path in existing provenance surfaces.
2. Show residency tier and runtime plane consistently where a user inspects a
   claim, AnswerPacket, graph DAG count, or health row.
3. Keep the UI compact and non-blocking.
4. Add tests/source guards proving no green chip appears without a witness.

Rules:
- Do not mutate retrieval ranking, graph physics, or editor hot paths.
- No stash pop/drop/bulk apply.
- No git checkout from stash.
- No git add -A.
- PR must include Motion, UAS, Plane, Residency, WBO/error, Witness,
  Falsifier, Tier, Rollback.

Gates:
git diff --check
cargo test --manifest-path agent_core/Cargo.toml --lib
xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

Stop after opening the PR. Do not merge yourself.
```

### Retired Terminal - Ship Hardening W-49/W-53

Do not dispatch. Current source already closes W-49 and W-53. Evidence lives in
`docs/audits/POST_WAVE4_W49_W53_HARDENER_CLOSEOUT_2026_05_27.md`.

## Later Terminals

Run these only after the product-floor closeout PRs are merged and the local
gate is green:

1. `RESUME ACS ANCHOR HARNESS`
   - Completed by `docs/audits/ACS_ANCHOR_HARNESS_FULL_2026_05_27.md`.
2. `RESUME METAL WITNESS GATES`
   - Preflight slice: `docs/audits/METAL_WITNESS_GATES_PREFLIGHT_2026_05_27.md`.
   - `F-ULP-Oracle` full Metal artifact: `artifacts/falsifiers/ulp_oracle/result.json`.
   - `F-PageGather-M2Pro` now has a real 256 MB dense failure report, a
     256/512 MB packetized mitigation artifact, a scheduler contract, and Metal
     dense + packetized contracts; next step is caller-path packet consumption
     or dense kernel optimization, not green promotion.
   - `F-ControllerKernelPack` now has a full Metal primary artifact with all
     correctness, empty-contract, p50/p99, and sequence axes passing.
   - Still remaining: full Metal/PageGather pass artifact. Keep it Pro Research
     until real hardware measurements pass.
3. `RESEARCH CONSTRUCTION`
   - Candidate-only research construction engine. Do not affect live product
     behavior.
4. `FORK V3`
   - Second-repo endgame only after post-v2.0 tag.

## Current Best Next Move

Do not dispatch another broad product-floor wave. Main is now at the point where
the remaining work should be summoned by codeword:

1. `RESUME METAL WITNESS GATES`
2. `RESEARCH CONSTRUCTION`
3. `FORK V3` only after the post-v2.0 tag

Then rerun the local ground-truth gate after any future codeword slice:

```text
git diff --check
cargo test --manifest-path agent_core/Cargo.toml --lib --quiet
xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosPostWave4NextGate build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```
