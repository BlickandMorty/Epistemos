# Gemini 70B Local Cocktail Blueprint — EVALUATION

> **Status:** NON-AUTHORITY working evaluation. Does not modify any authority doc and does not write to
> `docs/fusion/RESEARCH_LOOP_LEDGER_2026_06_20.md` (single-writer; owned by the concurrent loop worker).
> Honesty per the Architecture Tier Promotion Canon: T0=ambition/research, T1=L1 metadata proof,
> T2=admitted route, T3=WRV surface, T4=build-green, T5=full substrate. "Green" reserved for T4+.
> Verbatim source: `docs/fusion/pasted/GEMINI_70B_COCKTAIL_BLUEPRINT_2026_06_20.md`.
>
> All "already have it" claims below were grepped against the live repo on 2026-06-20.

---

## 1. DEDUP MAP — blueprint ideas already in Epistemos canon/code

Each row maps a blueprint idea to a **verified** repo artifact. Where the blueprint over-claims relative
to what actually exists, the "Honest gap" column says so.

| Blueprint idea | Existing artifact (verified path) | What actually exists | Honest gap |
|---|---|---|---|
| **InterruptScore `u_t` per token** | `epistemos-research/src/interrupt_score.rs`; `agent_core/src/research/interrupt_calibration.rs` (`INTERRUPT_DOCTRINE_AUROC_BAR=0.85`, Youden-J threshold) | Typed interrupt-score + calibration math + AUROC gate (F-Interrupt-Calibration, 30-task corpus) | Substrate-floor / research lane. NOT an always-on decode-loop micro-kernel yet. M0 (does it move loss at toy scale) is still open. |
| **Attention-as-interrupt / attention sinks** | `agent_core/src/research/attention_sinks.rs` (+ `research/koopman.rs`) | `AttentionSpectrum`, `detect_sinks`, `sink_strength`; Koopman-spectral characterization (Xiao 2309.17453, Cancedda 2402.09221) | Math + verdict surface only; not wired to a live attention Metal kernel. |
| **Active Assembly (which mechanisms fire)** | `agent_core/src/research/active_assembly/{mod,packet,selector}.rs` | `Packet`, `PacketGraph`, `MarginAnchoredGreedyPull` selector; F-ActiveAssembly-Minimal | Synthetic-packet substrate; not bound to real weight/expert residency yet. |
| **Residency Governor / ColdStream (SSD→RAM prefetch, page-level, no copy)** | `agent_core/src/helios/{mod,packet_router,ssd_block_scan,page_gather,controller_pack,local_recall_island,long_context_harness}.rs`; `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md` | ColdStream serial-transport stance, page-gather, SSD block scan, controller pack | This is the strongest overlap. The blueprint's "Residency Governor (Rust/UAS)" ≈ Helios + ColdStream already. |
| **UAS zero-copy pointer transfer (KV page / weight block / note share a coordinate)** | `agent_core/src/uas/*`; `docs/falsifiers/F-UAS-CopyCount_2026_05_24.md` (+ `F_UAS_COPY_COUNT`, slab_arena_copy_count, mmap_residency_fence_copy_count falsifiers + result.json artifacts) | UAS coordinate canon + copy-count falsifiers with passing artifacts | Directly matches the blueprint's "(4) Unified Address Space" item — already canon, already falsified. |
| **Packet router (1-bit dispatch)** | `agent_core/src/helios/packet_router.rs`; `Epistemos/Shaders/PacketRouter1bit.metal`; `F-PacketRouter1bit-Dispatch_2026_05_17.md` | Rust router + Metal 1-bit dispatch kernel + falsifier | Maps to blueprint "pre-attention routing" intent partially (router exists; the *predictive L→L+1 prefetch* part is NOT built — see §2e). |
| **Mamba-2 / SSM selective scan spine** | `agent_core/src/research/mamba3.rs`; `agent_core/src/research/koopman.rs`; Lean `Scan.lean` | SSM research substrate + Koopman lift | Blueprint Week-1 (`SelectiveScan.metal` bit-exact vs PyTorch) is NOT done; no shipped Metal selective-scan kernel verified bit-exact. |
| **Deliberation / HeavySkill (K parallel trajectories, MutationEnvelope, verify, write-back)** | `agent_core/src/cognitive_dag/{node,edge,resonance,dispatch,companions,...}.rs`; variant/companion ladder | Cognitive-DAG (10 NodeKind/10 EdgeKind), resonance propagation, dispatch | "K parallel reasoning trajectories + sequential deliberation" is an *agentic* pattern partly expressible via cognitive_dag + skills, but the specific "halt fast decode → spawn K → synthesize → inject state back" loop is NOT a single built mechanism. |
| **Lean / SCOPE-Rex verification** | `lean/Epistemos/Epistemos/*.lean` (40+ modules); SCOPE-Rex canon | Real Lean project + SovereignGate/SCOPE-Rex admission | Verify lane exists. The specific open obligation the owner names — InterruptInvariant / Bauer-Fike `sorry` — is the M1 gate (Bauer-Fike referenced in `MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §B2-M8; Lean `sorry`s live in PCF_8/H11 and others). |
| **Engram = decoupled factual memory, O(1) lookup** | `epistemos-research/src/engram.rs` (HELIOS V5, Lane 3 RESEARCH-ONLY) | Hash-table **type surface** only (insert/lookup/capacity), `RECOMMENDED_STATIC_FRACTION` 20-25% flagged as *heuristic not theorem*; explicit caveat that O(1) "ignores hash collision + cache effects" | **Partial.** The Engram *concept + typed surface* exists. The blueprint's specific MoLKV mechanism and the SSD-resident vocabulary-indexed table are NOT built (see §2a, §2g). |
| **Three sparsities framing; 16GB UMA page-thrash constraint** | Living Index, `LOCAL_FRONTIER_PLAYBOOK_16GB`, `FRONTIER_LOCAL_REASONING_16GB_ARCHITECTURE`, M2-Pro Verified Floor Handbook | Memory-bandwidth-bound reality (~200 GB/s theoretical, ~100 GB/s measured contiguous Metal per helios v6.2 §1.4 drift note) | Framing is canon. Blueprint's "4-bit 70B = 35-40GB" is consistent with `F-MoEActiveParamsMemoryTruth` (active-params ≠ memory-fit). |

**Honesty correction on one prompt assumption:** the task said the SpQt warning is "already noted in
`GPT 6.md`." I could not find any file named `GPT 6.md`, nor any `SpQt`/`zigzag` warning anywhere in
canon (grep across the whole repo: SpQt appears only in vendored `llama.cpp/stb_image.h` and an unrelated
research note — neither is an SpQt-layout warning). **SpQt is therefore treated as genuinely-new below
(§2c), not pre-noted.**

---

## 2. GENUINELY NEW / BENEFICIAL — items not yet in canon worth adopting

For each: what it is · primary source (verifiability) · side (model / brain(app) / both) · honest tier ·
smallest M2-Pro-16GB falsifier.

### (a) Engram **O(1) lookup tables made real** + **MoLKV** (decouple static facts from compute)
- **What:** Move static, retrieval-like knowledge (facts, signatures, API contracts) out of FFN compute
  into token-ID-indexed **Key-Value lookup experts on SSD**. MoLKV = "Mixture of Lookup KV Experts":
  token ID selects an expert (activation ratio as low as 1/100000), the current hidden state is the
  *dynamic Query* against the cached KV, producing a context-modulated output **without a dense FFN step**.
- **vs canon:** Engram *type surface* exists (`engram.rs`, Lane 3) but only as a hash table; MoLKV and the
  "hidden-state-as-query against cached KV expert" mechanism are absent.
- **Primary source:** DeepSeek "Engram" lookup-table memory + MoLKV — **needs primary-source verification**
  (the captured text attributes it to DeepSeek; the repo's own `engram.rs` caveat already warns the
  "Sparsity Allocation Law" is heuristic). Treat the 1/100000 activation ratio as an unverified claim.
- **Side:** both (model exposes the lookup layer at intermediate depths e.g. 2 & 15; app/UAS owns the
  SSD-resident table + zero-copy fetch).
- **Tier:** **T0→T1.** Concept is canon-adjacent; a typed MoLKV surface + falsifier would be T1.
- **Smallest falsifier (M2 Pro 16GB):** `F-MoLKV-LookupEquivalence` — on a toy model, replace one early
  FFN block with a frozen LUT/KV-expert table; assert (i) output parity within ε vs the dense FFN on a
  held-out probe set, and (ii) per-token lookup overhead < 3% wall-clock on CPU, with the table mmap'd
  (copy-count = 0 via the existing F-UAS-CopyCount harness).

### (b) **ReLU / ReLU² activation-sparsity spine** (PowerInfer / SmallThinker)
- **What:** Use ReLU or ReLU² FFN activations instead of SwiGLU. SwiGLU has ~0 activation sparsity; ReLU
  FFNs induce >90% activation sparsity, which is the *enabler* for predictive prefetch and skip-decode.
- **vs canon:** No activation-sparsity spine in code (only vendored llama.cpp + doc mentions). Genuinely new.
- **Primary source:** PowerInfer (Song et al., SJTU) and SmallThinker — **verifiable on arXiv/GitHub**;
  ReLU-sparsity lineage also "ReLU Strikes Back" (Mirzadeh et al., Apple). Worth a targeted web pass.
- **Side:** model (architectural activation choice) — but the *exploitation* is app/brain (the governor
  prefetches only the predicted-active neurons).
- **Tier:** **T0** (architectural research; requires training/finetune to realize sparsity honestly).
- **Smallest falsifier:** `F-ReLU-ActivationSparsity` — train/finetune a toy FFN with ReLU² and measure
  measured activation-sparsity ≥ 90% on held-out tokens *and* downstream loss not worse than SwiGLU
  baseline by > X. Sparsity that costs quality is not a win — measure both.

### (c) **SpQt zigzag weight layout** (skip-friendly sparse decode)
- **What:** Post-quantization, group weights column-wise *within quant groups* in a zigzag layout so GPU
  threadgroups can skip contiguous zeroed chunks (turns activation sparsity into actual skipped work).
- **vs canon:** Absent (see honesty correction §1). Genuinely new.
- **Primary source:** "SpQt"/SpQR-adjacent sparse-quant layout work — **source needs verification**; the
  exact name "SpQt" is uncertain and may be a Gemini paraphrase of SpQR (Dettmers et al.) or a sparse
  Marlin-style kernel. Flag the name as unverified.
- **Side:** model+kernel (the weight layout is a co-design between quantizer and the Metal decode kernel).
- **Tier:** **T0** (kernel research, downstream of M0/M1 per §3).
- **Smallest falsifier:** `F-SpQt-SkipDecode` — Metal kernel decodes a zigzag-laid quant block, bit-exact
  vs a dense-decode reference, AND demonstrates ≥ N% fewer threadgroup multiply-adds when the activation
  mask is sparse. Bit-exactness is the gate; speedup is the payoff.

### (d) **Sliding-window FFN weight cache** (temporal locality, ~98% I/O cut)
- **What:** Keep the union of active params for the past few tokens resident; only stream the *delta*.
  Claimed to cut weight I/O up to 98% because token-to-token active-set overlap is high.
- **vs canon:** ColdStream/Helios does page-level transport but there is **no temporal active-set cache**
  with delta-streaming. Genuinely new and a natural add to Helios.
- **Primary source:** PowerInfer-2 / LLM-in-a-Flash (Apple, "LLM in a flash", Alizadeh et al.) — the
  windowing + selective-load idea is **verifiable**. The 98% figure is workload-dependent; treat as claim.
- **Side:** brain(app) — pure Residency Governor policy on top of the existing transport.
- **Tier:** **T1** (buildable on existing Helios substrate; no model change required).
- **Smallest falsifier:** `F-SlidingWindowFFNCache` — replay a real decode trace; measure bytes streamed
  with vs without the window cache. Win = ≥ K% I/O reduction with **zero** correctness change (same logits).

### (e) **Pre-attention low-rank router that prefetches L+1 experts during L**
- **What:** A small low-rank predictor before attention of layer L predicts which experts/neurons layer
  L+1 will need, so the governor asynchronously prefetches NVMe→UMA *while L computes* — hiding latency.
- **vs canon:** `packet_router.rs` exists (1-bit dispatch) but the **predictive lookahead-prefetch** is
  not built. This is the highest-leverage *new* systems idea for the 16GB box.
- **Primary source:** PowerInfer predictor + DejaVu (Liu et al., contextual sparsity prediction) —
  **verifiable**. DejaVu is the canonical "predict-then-prefetch contextual sparsity" reference.
- **Side:** both (model exposes a cheap predictor head; app does the async prefetch + residency).
- **Tier:** **T1** (predictor can be a tiny linear probe; prefetch rides existing Helios).
- **Smallest falsifier:** `F-PreAttentionPrefetch` — predictor top-k recall ≥ R against the true active set
  on held-out tokens, AND end-to-end the prefetch hides ≥ M% of the SSD stall (GPU-bubble reduction
  measured via Metal counters). Recall without latency-hiding is not a win.

### (f) **Row-Column weight bundling** for sequential SSD reads
- **What:** Store up- and down-projection weights for a unit *contiguously* on SSD so one expert fetch is a
  single large sequential read (SSDs are fast sequential, slow on fine-grained random I/O → GPU bubbles).
- **vs canon:** No explicit on-disk bundling layout in canon. Genuinely new; complements ColdStream.
- **Primary source:** LLM-in-a-flash "bundling"/"row-column bundling" (Apple) — **verifiable**.
- **Side:** brain(app) — on-disk artifact layout owned by UAS/Residency Governor.
- **Tier:** **T1** (artifact-layout change, no model change).
- **Smallest falsifier:** `F-RowColBundling` — measured read throughput (MB/s) and IOPS for bundled vs
  unbundled expert fetch on the owner's NVMe; win = ≥ T× throughput with identical bytes returned.

### (g) **The "Engram / Lookup Plane" as a third plane** (alongside State + Episodic)
- **What:** Formalize three planes: high-speed local **State Plane** (semantic spine), disk-resident
  **Episodic Plane**, and a new **Lookup/Engram Plane** (computation-free, token-ID-indexed).
- **vs canon:** Canon has UAS/ACS planes and `epistemos-research/src/five_planes.rs` (five-plane model).
  A *dedicated computation-free Lookup plane* is not separately first-classed. Mostly a **framing** add.
- **Primary source:** synthesis of DeepSeek Engram + the blueprint; **internal architecture decision**,
  not an external claim to verify.
- **Side:** both (plane spans model layer hooks + app-side table).
- **Tier:** **T0** (taxonomy/framing; cheap to adopt as canon language once MoLKV §2a has a falsifier).
- **Smallest falsifier:** N/A as a pure framing item — it earns its keep only via §2a's `F-MoLKV-*`.
  Do NOT promote the plane to T1+ on framing alone; bind it to the MoLKV equivalence proof.

**Net new-and-beneficial ranking (highest leverage first on a 16GB box):**
1. **(e) pre-attention predictive prefetch** (DejaVu/PowerInfer) — biggest latency win, rides Helios.
2. **(d) sliding-window FFN cache** — biggest I/O win, pure app policy.
3. **(f) row-column bundling** — removes random-I/O bubbles, layout-only.
4. **(a) MoLKV/Engram-real** — biggest *capability* win (decouple facts) but needs model co-design + sources.
5. **(b) ReLU² sparsity spine** — the enabler for 1-3, but requires training to be honest.
6. **(c) SpQt zigzag** — converts sparsity to skipped FLOPs; kernel work, latest in order.
7. **(g) Lookup Plane framing** — adopt only once (a) has a falsifier.

---

## 3. RECONCILE THE 6-WEEK PLAN with repo discipline

**The tension (named honestly):** the blueprint front-loads **Metal kernels in Week 1**
(`SemiseparableBlockScan.metal` + `SelectiveScan.metal`, bit-exact vs Mamba-2). Epistemos canon says the
single gate before any heavy kernel / ternary / cold lane is:

- **M0** — *does the interrupt mechanism even move the loss at toy scale?* CPU-canonical, tiny model.
  (Echoed verbatim in `RESEARCH_INTENT_AND_QUERY_LOG_2026_06_20.md` Q1: "whether the mechanism even
  moves the loss at toy scale", and Q10b: "hold M0/M1 crafting".)
- **M1** — *close the `InterruptInvariant` / Bauer-Fike Lean `sorry`* (the spectral-perturbation bound on
  quantizing the SSM A-matrix; Bauer-Fike applied to the Babai bound, per
  `MASTER_FUSION_NO_COMPROMISE_2026_05_13.md` §B2-M8).

Letting a 6-week kernel plan run before M0/M1 would invert the tier-promotion gate (kernels are T2/T3
build work; M0/M1 are the T0→T1 proof that the *one new variable* — the interrupt — earns the rest).
**Keep every blueprint idea; re-order under the gate.** No idea is discarded; the sequencing changes.

### Merged, honest build order

| Phase | Gate / work | Tier | Maps to blueprint | Discipline note |
|---|---|---|---|---|
| **M0** | Interrupt-moves-loss at toy scale, **CPU-canonical**. Tiny model, interrupt as the *only* new variable; show measurable loss/quality delta vs no-interrupt baseline. | T0→T1 | (precondition for blueprint Step 3 / Week 2-3) | **Must pass first.** If the interrupt doesn't move loss at toy scale, nothing downstream is justified. |
| **M1** | Close `InterruptInvariant` / Bauer-Fike Lean `sorry`. Spectral-perturbation bound under quantization. | T1 | (formal backing for Step 3 gating + any ternary quant) | Lean obligation, not a kernel. Unblocks ternary/quant lanes honestly. |
| **B1** | Sliding-window FFN cache **(§2d)** + row-column bundling **(§2f)** on existing Helios/ColdStream. App-only, no model change. | T1 | Step 1 "Sliding Window Caching"; Step 4 "Row-Column Bundling" | Safe early win — rides existing transport + UAS copy-count harness. Independent of M0/M1 correctness (pure I/O), so may proceed in parallel as a *systems* track, but stays research until M0 justifies the model. |
| **B2** | Pre-attention predictive prefetch **(§2e)** — tiny low-rank predictor + async Helios prefetch. | T1 | Step 4 "Pre-Attention Routing" | Extends `packet_router.rs`. Falsifier-gated (recall + latency-hiding). |
| **B3** | Sparse selective-scan / SSM Metal kernel — **only now** does `SelectiveScan.metal` bit-exact-vs-Mamba-2 happen (blueprint Week 1). | T2 | Week 1 kernels | Re-ordered to *after* M0/M1. Bit-exactness gate unchanged. |
| **B4** | ReLU² activation-sparsity spine **(§2b)** + SpQt zigzag layout **(§2c)**. | T0→T2 | Step 1 PowerInfer/SmallThinker + SpQt | Requires training/finetune; sparsity must not cost quality. Kernel (SpQt) after spine exists. |
| **B5** | MoLKV / Engram-real **(§2a)** + first-class Lookup Plane **(§2g)** — re-parameterize early FFN experts into SSD LUTs (blueprint Week 5). | T0→T1 | Step 2 + Week 5 | Build on `engram.rs` typed surface; `F-MoLKV-LookupEquivalence` gate. Verify DeepSeek/MoLKV primary sources first. |
| **B6** | HeavySkill heavy-thinking loop (halt → K trajectories → deliberate/verify via SCOPE-Rex/Lean → inject state → resume) as an **offline skill**. | T2→T3 | Step 3 / Week 6 | Build on `cognitive_dag/*` + skills + ColdAssemblyPlan/ComputeResumeLease contract. |

**One-line rule:** *M0 then M1, then app-side systems wins (B1/B2) that need no model change, then kernels
(B3), then the model architecture changes (B4/B5), then the deliberation loop (B6).* The blueprint's
Week-1 kernels move to B3; nothing is lost, the gate is respected.

---

## 4. LEDGER INTEGRATION BLOCK (for the loop worker to paste — do NOT write to the ledger here)

> The block below is pre-formatted for the single-writer to paste into
> `docs/fusion/RESEARCH_LOOP_LEDGER_2026_06_20.md` on its next pass. It is intentionally NOT written there
> by this evaluation to preserve single-writer integrity.

```markdown
## Pass N — Gemini 70B Local Cocktail blueprint intake (external, T0 unverified)

**Source preserved:** docs/fusion/pasted/GEMINI_70B_COCKTAIL_BLUEPRINT_2026_06_20.md (verbatim).
**Evaluation:** docs/fusion/pasted/GEMINI_70B_COCKTAIL_EVALUATION_2026_06_20.md.

**Already-canon (dedup, verified paths):** InterruptScore=interrupt_score.rs+interrupt_calibration.rs ·
attention-interrupt=attention_sinks.rs · active assembly=research/active_assembly/* ·
Residency Governor/ColdStream=helios/* + COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01 ·
UAS zero-copy=uas/* + F-UAS-CopyCount · packet router=helios/packet_router.rs + PacketRouter1bit.metal ·
SSM/Mamba=research/mamba3.rs+koopman.rs · deliberation=cognitive_dag/* · verify=lean/* + SCOPE-Rex ·
Engram concept=epistemos-research/src/engram.rs (Lane 3, type surface only).
**Correction:** no "GPT 6.md" / SpQt warning found in canon — SpQt treated as NEW.

**New + beneficial (tiers + falsifier names):**
- (e) Pre-attention predictive prefetch [T1] — DejaVu/PowerInfer — F-PreAttentionPrefetch.
- (d) Sliding-window FFN weight cache [T1] — LLM-in-a-flash — F-SlidingWindowFFNCache.
- (f) Row-column on-disk bundling [T1] — LLM-in-a-flash — F-RowColBundling.
- (a) MoLKV/Engram-real, hidden-state-as-query KV experts [T0→T1] — DeepSeek Engram/MoLKV (verify) — F-MoLKV-LookupEquivalence.
- (b) ReLU²/ReLU activation-sparsity spine [T0] — PowerInfer/SmallThinker/ReLU-Strikes-Back — F-ReLU-ActivationSparsity.
- (c) SpQt zigzag skip-decode layout [T0] — name unverified (SpQR-adjacent) — F-SpQt-SkipDecode.
- (g) First-class Lookup/Engram plane [T0 framing] — bind to F-MoLKV-* only.

**Build-order reconciliation:** M0 (interrupt-moves-loss, CPU toy) → M1 (close InterruptInvariant/
Bauer-Fike Lean sorry) → B1 sliding-window+bundling (app-only) → B2 pre-attention prefetch →
B3 SelectiveScan.metal bit-exact (blueprint Week-1 kernels MOVED here) → B4 ReLU²+SpQt →
B5 MoLKV/Engram-real → B6 HeavySkill deliberation loop. Blueprint's Week-1-kernels-first sequence is
explicitly re-ordered behind M0/M1; no idea dropped.

**Owner decisions still pending:** (1) verify DeepSeek Engram + MoLKV primary sources; (2) confirm "SpQt"
real name; (3) green-light B1 as a parallel app-systems track vs strict-serial-after-M0.
```

---

*End of evaluation.*
