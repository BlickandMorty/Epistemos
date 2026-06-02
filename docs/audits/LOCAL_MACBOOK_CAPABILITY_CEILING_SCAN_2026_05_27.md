# Local MacBook Capability Ceiling Scan - 2026-05-27

Status: canon-refresh and implementation ladder.
Scope: no-compromise large local models on the M2 Pro 16 GB floor.
Posture: preserve ambition, do not weaken gates, do not let dense MLX impersonate ACS/UAS.

## Read Order Used

1. `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`
2. `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
3. `docs/fusion/UAS_ACS_CANONICAL_ARCHITECTURE_2026_05_16.md`
4. `docs/fusion/ADDRESSABLE_NEURAL_SUBSTRATE_CANON_2026_05_24.md`
5. `docs/fusion/SHADOW_PROJECTION_AND_RESEARCH_CONSTRUCTION_2026_05_24.md`
6. `docs/fusion/PRIMITIVE_IR_STACK_DOCTRINE_2026_05_17.md`
7. `docs/HELIOS_V6_1_NEW_RESEARCH_INTEGRATION_2026_05_16.md`
8. `docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md`
9. `docs/audits/CAPABILITY_CEILING_MODEL_GATE_2026_05_27.md`
10. `docs/audits/CANONICAL_TIER_ALIGNMENT_METAL_ULP_2026_05_27.md`
11. `docs/audits/W50_RESIDENCY_TIER_RECONCILIATION_2026_05_26.md`
12. `docs/audits/ACS_ANCHOR_HARNESS_FULL_2026_05_27.md`
13. `docs/audits/ACS_ADMISSION_PRODUCTION_GATE_2026_05_24.md`
14. Current artifacts under `artifacts/falsifiers/`
15. Current code under `agent_core/src/helios/page_gather.rs`,
    `agent_core/src/bin/falsify_kv_direct_gate.rs`,
    `agent_core/src/bin/falsify_70b_local_cocktail_lite.rs`,
    `Epistemos/Engine/LocalModelInfrastructure.swift`, and
    `EpistemosTests/LocalModelInfrastructureTests.swift`.

## One-Sentence Truth

Epistemos is not at "70B running locally" yet; it is at the measured substrate-gates layer where the app can honestly say which pieces of the ACS/UAS 70B route are proven, which are red, and why dense MLX must stay gated separately.

## The Three Routes Must Stay Separate

| Route | What it is | Current posture |
|---|---|---|
| Current App local MLX | practical whole-model local inference, primarily 4B-8B on 16 GB, larger models gated by RAM | live |
| Dense 36B MLX | a large dense local model path that needs host RAM, not an SSD/RAM proof | 32 GB + explicit opt-in |
| ACS/UAS 70B Capability Ceiling | addressable neural substrate: SSD/RAM UAS, PageGather, KV-Direct, active assembly, ternary/lattice, EML/Geometry/Scan charts, speculation/cascade | canonical target, red preflight |

Power-user mode must not lower the dense 36B gate on a 16 GB Mac. The 16 GB / 70B-class route reopens only through a separate substrate execution route.

## Current Gate Snapshot

| Gate / artifact | Current result | Meaning |
|---|---|---|
| `F-VaultRecall-50` | primary witness pass | retrieval floor is real, paraphrase remains informational/lexical caveat |
| `F-ULP-Oracle` | primary Metal witness pass | arithmetic floor for Morph/EML Metal oracle is real |
| `F-ControllerKernelPack` | primary Metal witness pass | small controller kernels are real on Metal |
| `F-Eidos-Bridge-RoundTrip` | primary witness pass | citation bridge has real round-trip evidence |
| `F-ACS-Anchor-Addressing` | primary witness pass, N=1000 | ACS anchor projection/emission/audit/inversion is real |
| `F-UAS-CopyCount` | schema-normalized primary pass | copy-count floor exists; full production generation loop remains separately unmeasured |
| `F-UAS-ZeroCopy-Spine` | fallback witness pass | scoped zero-copy spine exists; several hot paths remain unmeasured |
| `F-PageGather-M2Pro` CPU | fallback witness pass | CPU reference correctness exists |
| `F-PageGather-M2Pro` Metal dense | failure report | correct values, but dense random scatter ratio is too slow |
| PageGather packetized scheduled probe | mitigation evidence | packet stream reaches 0.729x/0.752x measured STREAM at 256/512 MB with zero sampled violations; dense restore remains too slow |
| `F-PageGather-Packetized-Caller` | fallback witness pass | Vault retrieval trace consumes retained-score packets and defers dense restore; not a dense primary PageGather pass |
| `F-ActiveAssembly-Minimal` | primary synthetic runtime witness pass | selector fires only `0.0322` of packets at `0.0021` cost ratio with 0 output-bound violations on N=1024/Q=100 synthetic graph; live model packet routing remains future work |
| `F-Sparse-Runtime-Split` | primary synthetic runtime witness pass | sparse support reproduces dense/reference logits on 1000 synthetic prompts with `0.0` KL, `0.0176` active ratio, `0.0067` cost ratio, and EML/Geometry/Scan/Operator chart labels; live 70B sparse runtime remains future work |
| `F-KV-Direct-Gate` | red harness contract | Rust QK equality passes 1,000 traces; live Qwen3-8B 128K SSD-spill model/logit/metrics/spill inputs are defined; smoke MLX logits, file-backed prompt-cache reload, restartable prompt shards, merged full-suite input assembly, and a 100 one-prompt shard plan now work locally. The resolved local model identity is canonical (`Qwen/Qwen3-8B-MLX-4bit`), but its config declares only `40960` context tokens and no rope scaling, so the 128K run is blocked at the model-context axis before shard repair. A separate Qwen3-Coder-Next candidate plan exists for long-context runtime research and is explicitly noncanonical. `shard_000_000` failure evidence is preserved (`2048` prefill: Metal interactivity abort; `512` prefill: stopped after ~14 min with 0 rows), and the spill-trace parser rejects noncanonical routes; the full 128K residual-patched mmap/NF4 SSD-spill gate is still missing |
| `F-Qwen3-8B-128K-GGUF-Route` | red candidate/fallback route | separate `unsloth/Qwen3-8B-128K-GGUF` lane exists as a schema-valid failure report with next bottleneck `download_or_register_qwen3_8b_128k_gguf_model_file`; it can become a fallback witness only with local GGUF file, 128K metadata, runner, paired logits, and live metrics, and it never satisfies the canonical MLX KV gate |
| `F-70B-Local-Cocktail-Lite` | red preflight | row-root exists; model weights/reference/sparse runtime/chart coverage are red |
| `F-Capability-Ceiling-Evaluation-Kernel` | red route rollup | schema-valid aggregator exists; next bottleneck is resolving a canonical Qwen3-8B model asset/config with `>=128000` context support before feeding real model/logit/metrics/spill inputs into the KV-Direct contract |
| Architecture no-gap queue | pass | `measurements.ordered_build_queue` exists and `unmapped_architecture_gap_count=0`; human mirror: `docs/audits/ARCHITECTURE_NO_GAP_BUILD_ORDER_2026_05_28.md` |

## What "Primitives" Mean In This Layer

Do not use "primitive" as a generic good-sounding word. In this architecture, a primitive is a typed substrate object or transform that participates in:

- UAS address
- runtime plane
- residency tier
- WBO/error account when approximate
- witness surface
- falsifier gate
- rollback path

The important primitive families for local large models are:

1. UAS identity primitives: `UasAddress`, `UasKind`, `ResidencyLease`.
2. ACS coordinate primitives: `AcsAnchor`, plane projection, anchor registry, admission proof.
3. Retrieval/visibility primitives: Eidos, VaultRecall, AnswerPacket, ClaimLedger, RunEventLog.
4. Memory primitives: KV page, PageGather packet, residency plan, L3 SSD Oracle.
5. Active execution primitives: ActiveAssemblyPacket, PacketRouter1bit, sparse runtime split.
6. Kernel primitives: PageGather, ControllerKernelPack, Morph/ULP, Scan/SSD, LocalRecallIsland.
7. IR primitives: EML, Tropical, Scan, Operator, Info, Geometry.
8. Compression primitives: ternary, Sherry/Leech lattice VQ, NF4, residual islands.

If a patch touches local large models and cannot name its primitive row, it is not ready.

## Current LLM-Address Granularity

Current App:

- whole-model call: live
- output schema: live/partial
- KV page: substrate exists, live model harness red
- weight-bit layout: research/candidate
- adapter delta: research
- MoE expert: model-internal only
- active assembly: research target with shape proof
- attention head / SSM state: research target
- parameter anchor / circuit: research target

The no-compromise goal is row-by-row descent from whole-model routing toward active assembly and circuit-addressed execution. It is not achieved by simply lowering a RAM gate.

## The Real 16 GB / 70B Unlock Path

The unlock must be a new route class, not a mutation of `primaryAgentModelMinHostRAMGB`.

Required sequence:

0. Run the route kernel before every loop pass.
   - Command: `Tools/falsifiers/f_capability_ceiling_evaluation_kernel.sh`.
   - Artifact: `artifacts/falsifiers/capability_ceiling_evaluation_kernel/result.json`.
   - Current verdict: `vault_research_route_with_packetized_mitigation`.
   - Current next bottleneck: `resolve_qwen3_8b_128k_context_model_assets_for_kv_direct`.
   - Current ordered queue: `measurements.ordered_build_queue`.
   - Current unmapped gap count: `0`.

1. Normalize current artifact shapes. **Done on 2026-05-28.**
   - Convert legacy `F-UAS-CopyCount` and `F-ACS-AnchorLookup` artifacts into the shared falsifier schema.
   - Keep existing pass state, but make validators uniform.

2. Promote PageGather caller path, not just kernel path. **First fallback witness done on 2026-05-28.**
   - The dense restore bottleneck is real.
   - Product paths should consume `(logical_position, value)` PageGather packets through retrieval, ranking, and witness rendering.
   - Pay dense restore only at surfaces that truly require dense logical order.
   - Next green candidate is caller-path packet consumption plus measured end-to-end improvement.

3. Build the live KV-Direct harness. **Contract done; current next bottleneck is canonical Qwen3-8B 128K context support.**
   - Qwen3-8B MLX 4-bit.
   - 128K context.
   - Canonical prompt suite:
     `artifacts/falsifiers/kv_direct_gate/prompt_suite.json`, generated by
     `Tools/falsifiers/kv_direct_prompt_suite.sh`, with 100 prompts, 128K
     target context, 256 decode tokens, and balanced family coverage.
   - reference path: hot/full KV.
   - test path: mmap/NF4/residual or nearest available SSD-spill path.
   - measurements: D_KL, peak RSS, decode tok/s, wall clock, spill labeling.
   - `Tools/falsifiers/f_kv_direct_gate.sh` now accepts the model path,
     paired logits, metrics JSON, and spill trace via explicit env vars; current
     Rust equality does not prove the live gate.
   - `Tools/falsifiers/run_kv_direct_mlx_live.sh` now emits the MLX-side
     contract files. A smoke run loaded the local Qwen3-8B snapshot and wrote
     paired full-vocabulary logits for 1 prompt at 512 context tokens; this
     remains runner plumbing, not a KV-Direct pass.
   - The same runner now has a `prompt_cache_reload` route. It saves an MLX
     prompt cache to disk, reloads it, and emits test logits through the paired
     falsifier inputs. The current smoke cache file is about 75 MB. This proves
     the file-backed cache edge is reachable, but it does not prove the
     residual-patched mmap/NF4 SSD-spill route.
   - `--prompt-offset` plus
     `Tools/falsifiers/merge_kv_direct_mlx_shards.sh` now makes the 100-prompt
     suite restartable: run shards, then merge them into the single
     reference/test/metrics/spill bundle consumed by the falsifier.
   - `Tools/falsifiers/plan_kv_direct_mlx_shards.sh --shard-size 1 --prefill-step-size 512 --write-shell` now writes
     the full-suite run plan and executable shard script under
     `artifacts/falsifiers/kv_direct_gate/live_mlx_full_suite_plan/`.
     The plan is marked `falsifier_green_capable=false` because the current
     runner route is still `prompt_cache_reload`, not residual mmap/NF4
     SSD-spill. The planner also accepts explicit `--model-path`; the current
     `live_mlx_candidate_qwen3_coder_next_plan` is noncanonical candidate-tier
     evidence only. The first shard has failed before producing logits, but the
     current first repair target is the canonical 128K model/context contract.
   - `F-KV-Direct-Gate` now parses the spill trace semantically. Metrics
     `spill_labeling=true` is insufficient unless the trace itself names
     `residual_patched_mmap_nf4_ssd_spill`, proves residual patching,
     mmap-backed cold KV, NF4/equivalent storage, and positive cold bytes.

3A. Keep the GGUF candidate split separate. **Executable red route done on 2026-05-28.**
   - `Tools/falsifiers/f_qwen3_8b_128k_gguf_route.sh` emits
     `artifacts/falsifiers/qwen3_8b_128k_gguf_route/result.json`.
   - The route targets `unsloth/Qwen3-8B-128K-GGUF` and currently stops at
     `download_or_register_qwen3_8b_128k_gguf_model_file`.
   - A pass here is fallback/candidate evidence only. It does not retarget
     `F-KV-Direct-Gate`, lower dense MLX RAM gates, or prove the 70B cocktail.

4. Wire UAS copy-count beyond the scoped spine.
   - measure Swift shared buffer -> Rust slice -> Metal shared buffer -> MLX KV view -> HNSW vector view where possible.
   - record which path is hot, fallback, or unmeasured.

5. Finish `F-ActiveAssembly-Minimal` from shape proof to useful runtime gate. **Synthetic runtime witness done on 2026-05-28.**
   - selected support is small on the deterministic packet graph.
   - selected support preserves reference behavior within budget on the deterministic packet graph.
   - live model packet routing remains future work.

6. Add `F-Sparse-Runtime-Split`. **Synthetic substrate witness done on 2026-05-28.**
   - a sparse/active path reproduces dense/reference execution within bounded drift on the deterministic fixture.
   - this is where "dormant neurons wake only when needed" becomes measured rather than metaphor.
   - live 70B sparse runtime remains future work.

7. Add EML/Geometry/Scan/Operator chart coverage axes. **Synthetic labels done on 2026-05-28.**
   - 70B cannot remain a totally opaque blob and still wear the final substrate claim.
   - accepted opaque axes must remain red or explicitly waived.
   - live 70B chart coverage remains red until model-backed rows exist.

8. Run `F-70B-Local-Cocktail-Lite` with real inputs.
   - set `EPISTEMOS_70B_MODEL_PATH`
   - set `EPISTEMOS_70B_PROVIDER_REFERENCE`
   - replace sentinel values with prompt-level measurements.
   - pass/fail honestly.

## Practical Model Policy Right Now

On a 16 GB MacBook:

- Default practical local intelligence remains 4B-8B class MLX plus routing.
- Dense 30B-36B may be installable but must remain opt-in and RAM-gated.
- 70B is research/artifact-gated until the cocktail passes.
- Cloud or Pro/Developer ID executors can exist as separate provider lanes, but they do not prove local ACS/UAS.

On 32 GB+ hosts:

- Dense 36B can be allowed with explicit opt-in.
- It is still not the same as the SSD/RAM substrate route.

On 64 GB+ hosts:

- bigger dense/MoE model lanes become practical.
- Still keep ACS/UAS gates separate because the MacBook 16 GB ceiling is a different claim.

## External Validation Notes

Targeted external checks line up with the local architecture:

- MLX is Apple Silicon native, has Swift/C/C++ APIs, lazy computation, dynamic graphs, and shared unified-memory arrays. That supports using MLX as a native lane, but not as proof that 70B works.
- `mlx-lm` documents rotating KV cache and prompt caching. It also warns that models large relative to RAM can be slow and uses wired memory on macOS 15+ to help. That aligns with keeping dense large models RAM-gated.
- `llama.cpp` remains an important fallback/reference engine: Apple Silicon is first-class, Metal is supported, and quantization spans 1.5-bit through 8-bit. It is a lane, not the Epistemos architecture.
- Microsoft BitNet/bitnet.cpp is the primary external reference for native 1-bit/b1.58 inference. It validates the research direction for ternary/BitNet paths but not the 70B composition by itself.
- Current public KV-cache quantization work is active but still implementation-sensitive on Apple Silicon. Treat it as motif evidence until local falsifiers pass.

Sources:

- MLX: https://github.com/ml-explore/mlx
- MLX-LM: https://github.com/ml-explore/mlx-lm
- llama.cpp: https://github.com/ggml-org/llama.cpp
- BitNet: https://github.com/microsoft/BitNet
- Apple Metal storage modes: https://developer.apple.com/documentation/metal/choosing-a-resource-storage-mode-for-intel-and-amd-gpus

## Next Terminal Prompt

```text
You are in /Users/jojo/Downloads/Epistemos.

Read:
1. docs/audits/LOCAL_MACBOOK_CAPABILITY_CEILING_SCAN_2026_05_27.md
2. docs/audits/CAPABILITY_CEILING_EVALUATION_KERNEL_2026_05_28.md
3. docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md
4. docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md
5. docs/audits/CAPABILITY_CEILING_MODEL_GATE_2026_05_27.md
6. docs/fusion/ADDRESSABLE_NEURAL_SUBSTRATE_CANON_2026_05_24.md
7. agent_core/src/bin/capability_ceiling_evaluation_kernel.rs
8. agent_core/src/helios/page_gather.rs
9. agent_core/src/bin/falsify_kv_direct_gate.rs
10. agent_core/src/bin/falsify_70b_local_cocktail_lite.rs

Goal:
Advance the 16 GB / 70B Capability Ceiling without lowering dense MLX gates.

Rules:
- Do not lower primaryAgentModelMinHostRAMGB.
- Do not claim 70B local pass unless F-70B artifact passes with real measurements.
- Do not promote dense 36B as ACS/UAS.
- No broad refactors.
- No product UI green chip without a witness artifact.
- Add tests or artifact validation for every touched gate.

Preferred next slice:
1. Run the Capability Ceiling Evaluation Kernel and obey its `next_bottleneck`.
2. Resolve the canonical Qwen3-8B 128K model/context contradiction recorded in
   `docs/audits/KV_DIRECT_CANONICAL_MODEL_RESOLUTION_2026_05_28.md`: either
   find a canonical MLX asset/config that honestly supports `>=128000`, retarget
   the falsifier explicitly, continue the already-created separate GGUF route
   as fallback-only, or falsify a local rope/context extension. Do this before
   rerunning 128K shards.
3. After the context contract is green, start the live Qwen3-8B 128K KV-Direct
   runner that feeds paired 100-prompt reference/test logits, `>=128000`
   context-token metrics, `>=256` decode tokens per prompt, RSS/tok/s/wall-clock
   metrics, and spill trace into `Tools/falsifiers/f_kv_direct_gate.sh`.
4. Promote the next red queue row after KV: live sparse 70B runtime/chart
   coverage, while keeping current Active Assembly and Sparse Runtime Split
   synthetic witnesses separate from live-model proof.

Finish with:
- Motion / UAS / Plane / Residency / WBO / Witness / Falsifier / Tier / Rollback
- commands run
- artifacts changed
- red axes remaining
```

## Hard Acceptance Rule

The no-compromise ambition is preserved only if failures stay visible.

The right next result is not necessarily a green chip. The right next result is a measured artifact that turns one named red axis into either:

- a pass with local evidence, or
- a better failure with a narrower bottleneck.

That is how the 70B path becomes real instead of becoming a slogan.
