# Epistemos — Perpetual Research-Consolidation + Architecture-Design Loop Ledger

> **NON-AUTHORITY scratch/working doc.** Append-only. One dated/numbered section per loop pass.
> Does NOT modify authority docs (`docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`, the lattice
> explainer `index.html`, `MASTER_*` canon). Proposed authority-doc edits are recorded here as
> **write-plans** awaiting explicit owner green-light. Honesty per the Architecture Tier Promotion
> Canon (`docs/fusion/ARCHITECTURE_TIER_PROMOTION_CANON_2026_06_06.md`): T0=ambition/research,
> T1=L1 metadata proof, T2=admitted route, T3=WRV surface, T4=build-green, T5=full substrate.
> "Green" is reserved for T4+. Nothing beneficial is ever removed; goal is robust + honest.

---

## PERMANENT DIMENSIONS (owner standing brief 2026-06-20 — every pass MUST touch all of these)

Each pass advances **research discovery** + **three architecture surfaces** + **three robustness
dimensions**, rotating depth so every pass makes NEW progress:

**Architecture surfaces**
- **S-SPLIT** — the MODEL vs BRAIN(app) split: which mechanisms are model-internal, app-side, or both.
- **S-CONN** — the MASTER CONNECTION: the hardened bidirectional model↔app contract (model always
  signal-links to the app; the app cycles signals back to the model). Builds on the existing typed
  protocol: `AnswerPacket`, `InterruptScore`, `LatticeAbstentionGate`, `ComputeResumeLease`,
  `ColdAssemblyPlan`, `InterruptInvariant`, `RunEventLog`.
- **S-PANEL** — the new in-app CONTROL PANEL: a SwiftUI surface where the user controls the model
  (route/lane, interrupt thresholds, residency/cold-assembly budgets, ternary/quant lane,
  fast-weight quarantine, abstention policy) AND watches the model speak back (live signals,
  AnswerPackets, RunEventLog). Must bind to the Rust signal bus and flag T0-ambition vs implemented.
- **S-HW** — BESPOKE HARDWARE CO-DESIGN for the owner's exact machine (M2 Pro 14": 12-core CPU,
  19-core GPU, 16 GB UMA, ≈200 GB/s; Metal compute; ANE = Research-tier; thermal/power bounded).
  Engineer model + app to exploit THIS box in ways generic stacks can't: UMA/zero-copy, IOSurface/
  shared buffers, mmap-vs-ColdStream serial-transport stance, page cache, KV in unified memory; the
  model "instantly reads" Mac memory/cache via the app's substrate, not a generic API; honest
  single-box training feasibility (trainable here vs needs distillation/QAT/adapters).
- **S-APP-FAST** — the app's already-fast/accurate subsystems (InstantRecall, Eidos shadow search
  BM25+HNSW+RRF k=60, KV-Direct, Rust FFI hot paths) ARE the bespoke advantage; design the model to
  LEAN ON them rather than reimplement, and bespoke-engineer the app side for macOS/M2 Pro too.
- **S-PRIM** — PRIMITIVE FAMILY (NOT EML-only). Inventory ALL of the owner's primitives from the
  actual code/research (`agent_core/src/research/`, `bin/epistemos_eml.rs`, the lattice explainer
  §primitives, the PRIMITIVE_IR_STACK doctrine) and give EACH an evaluated role: what it is, where it
  lives, which side it earns a role on (model-internal operator / app-side deliberation / signal bus),
  honest tier, and the smallest falsifier proving it's beneficial. Only promote a primitive if it
  genuinely helps — no forced inclusion. Running inventory lives in each pass's S-PRIM section.

**Robustness dimensions (deep + edge cases, owner brief 2026-06-20)**
- **D1-COMMS** — model↔app communication HARD cases: backpressure (app deliberates slower than model
  decodes), cancellation/teardown mid-generation, partial/streaming signals, race/ordering on the
  bidirectional bus, mid-token "abstain/wake-heavy-lane", lease revocation, security/authority
  (no silent reroute, no hidden authority), failure/rollback, and the latency budget of the bus
  itself (must NOT stall the decode loop). Enumerate edge cases each pass + how the contract handles them.
- **D2-PERF** — optimization/perf/speed grounded in Apple Silicon memory-bandwidth-bound reality
  (M2 Pro 16GB ≈ 200 GB/s). Latency vs throughput, serial GPU→SSD→GPU transport, KV residency cost,
  ternary kernel speed, interrupt-gate overhead, control-panel observability cost. Every design
  choice ties to a perf consequence + a measurable target.
- **D3-QUALITY** — reasoning quality: abstention correctness ("defer beats wrong"), Cognitive-DAG
  verification, retrieval grounding, interrupt firing at the right tokens; measured via the seven
  task families + held-out scorers WITHOUT overclaiming.
- **D-IMPL** — IMPLEMENTATION GUIDANCE (not just research): every pass produces concrete "what to ADD"
  + "HOW to code it" proposals — file targets, crate/module placement, FFI seams, and the SMALLEST
  falsifier that proves it — grounded in existing code + no-compromise canon. Everything beneficial
  the owner or the loop identifies is captured 100% here as T0/T1 write-plan (no building ahead of the
  Phase 0→3 gate; no authority-doc edits without green-light).

**External research breadth (owner brief 2026-06-20):** each pass widens GitHub/HuggingFace/arXiv on
the BEST architectures relevant to this design, ESPECIALLY: **lattice methods** (lattice quantization/
coding, LatticeCoder/Babai, lattice attention), **Erdős/extremal & construction-search** (PatternBoost/
"Erdős-Lift" lineage), and **orthogonal math** (orthogonal/unitary parameterizations, Koopman/spectral,
RoPE-as-rotation, orthogonal init/regularization). Record source-cards with the S-SPLIT/S-CONN/S-HW map.

**STANDING OPS (every pass, owner brief 2026-06-20):**
- **Preservation duty:** at pass start, confirm `docs/fusion/RESEARCH_INTENT_AND_QUERY_LOG_2026_06_20.md`
  + this ledger exist & are intact; append any NEW owner queries to the intent log VERBATIM; double-check
  every write (write → read-back → confirm). Failure mode to prevent: "research dropped because it wasn't
  saved." Nothing beneficial is ever lost.
- **Single-writer rule for the pasted Gemini 70B blueprint:** a separate worker ingests it into
  `docs/fusion/pasted/` and hands back a "ledger integration block." THIS ledger's writer (the loop) is
  the single integrator — on a LATER pass, once `docs/fusion/pasted/` is non-empty, fold its accepted
  items (Engram O(1) lookup / MoLKV, ReLU² activation sparsity, SpQt zigzag, sliding-window FFN cache,
  pre-attention prefetch router, the third "Lookup Plane") in here. Do NOT write concurrently.

**Hard exclusions (never touch):** `~/Epistemos-RETRO/`, `src-tauri/`, `~/meta-analytical-pfc/`.

**Phase-∞ honesty note:** `MASTER_SYNTHESIS_2026_06_19.md` §4 sequences "Living Index + Lattice
Explainer / obscura-era-forward local-research mining" as **ABSOLUTELY LAST / INDEFINITE**. This loop
IS that Phase-∞ mining loop — it is research+design synthesis, NOT a license to start building ahead
of Phase 0→3. All design output here is T0/T1 (ambition + write-plan) until owner-promoted.

---

## PASS 1 — 2026-06-20 (baseline establishment)

### 1. New research found this pass + source + theme + revive/skip

**Local corpus survey (recency-ranked).** Most local research folders predate the 2026-06-19
consolidation sweep and are already captured by `MASTER_SYNTHESIS_2026_06_19.md` + the 37 `SS-*`
slices. Recency of the unconsolidated-looking phrase folders:

| Folder | mtime | Status vs corpus |
|---|---|---|
| `~/Downloads/master resarch here` | 2026-05-05 | most recent phrase folder — NOT yet skimmed; pass-2 target |
| `~/Downloads/GPT Research` / `kimis deep research` | 2026-05-03 | per-model drops; pass-3 target |
| `~/Downloads/latest research` | 2026-05-01 | **partially consolidated** (SCOPE-Rex doc → already in code as `scope_rex/`) |
| `~/Downloads/LivingBrain` | 2026-04-09 | obscura/Hermes-era; revive candidate (dropped theory) |
| `next batch of unsorted research`, `unsort3ed research`, `soaar and research mode`, `mass research folder` | 2026-03-27/28 | early-era; mostly swept; mine for DROPPED ideas only |

**Genuinely useful local find (partial-revive):** `~/Downloads/latest research/deep-research-report.md`
— "SCOPE-Rex Unified Cognitive Substrate" (2026-05-01). Theme: **capability residency architecture**;
"LLM as language cortex, NOT the whole brain" (cites that next-token models predict the human language
network for *comprehension* only — not memory governance/action safety). Already partly consolidated
(SCOPE-Rex exists in `agent_core/src/scope_rex/`), but two nuances are **under-consolidated and worth
reviving into the S-SPLIT design**:
  - **(a) Control-plane / data-plane FFI split** — UniFFI for control-plane objects/async callbacks;
    a narrow C ABI + stable handles + `makeBuffer(bytesNoCopy:)` shared memory for tensors/token
    buffers. Directly load-bearing for S-CONN latency budget (D1/D2).
  - **(b) "Selective decode-verify-rollback beats always-on determinism"** — always-on full
    determinism carries a double-digit perf tax; selective verify/rollback is the better default.
    Directly load-bearing for D2-PERF + D3-QUALITY (verify only when the interrupt fires).
  - Revive: **YES** (fold (a)+(b) into S-SPLIT/S-CONN; skip the "research-only" sparse-texture-KV /
    private-ANE pieces it explicitly marks non-Core).

**External validation (rotating: test-time training / fast weights).**
  - **LaCT — "Test-Time Training Done Right"** (arXiv **2505.23884**; MIT repo `a1600012888/LaCT`,
    MIT license, Triton fused-kernel update 2025-11-18, last push 2026-01-05). NEW nuance vs the
    corpus's generic "LaCT/Titans fast-weights" mention: fast weights updated on **large chunks
    (2K–1M tokens, tokens treated as an unordered set + window attention)** instead of per-16/64
    tokens; pushes GPU util from <5% → ~70% (A100) and scales **state-to-param ratio to ≥40%**
    (vs 0.1–5% prior). **Implication for Epistemos** (record, don't build): the **fast-weight
    quarantine lane** must treat that ≥40% state ratio as a hard *memory* budget on a 16GB M2 Pro
    (a 40%-of-params fast-weight state is a residency cost, not free), and the "large chunk" update
    granularity maps cleanly onto the app's "wake-heavy-lane / chunk-deliberate" cycle rather than
    a per-token update. Revive: **YES as a Pro-research/quarantine source-card only** — gate under
    `F-ProprietaryCompression-ProvenanceGate` + fast-weight quarantine; NOT a live route.

**Codex/Claude thread reachability:** NOT inspected this pass (deferred). Owner says Codex holds the
most-updated threads (past 2 weeks) and Claude is where research began. Pass-2 should check
`~/.codex`, `~/Library/Application Support/{Code,Claude,Cursor}`, and any exported `*.jsonl` thread
files, then surface-or-note-unreachable and move on.

### 2. Keyword set used THIS pass (future passes must diversify away from these)
`research|epist(en|em)os|kimi|gpt|claude|gemini|perplexity|last|old|latest|batch|unsorted|brain|
scaffold|fusion|master`; `AnswerPacket|InterruptScore|LatticeAbstentionGate|ComputeResumeLease|
ColdAssemblyPlan|InterruptInvariant`; `RunEventLog|SignalBus|signalBus`; `LaCT large chunk test-time
training fast weights`. **Next passes invent new sets** (e.g. Mamba-3 / SSM selective-scan; BitNet
I2_S / TL1 / TL2 ternary QAT; attention sinks / StreamingLLM; Koopman / DMD operator; Titans
neural-memory; MoE SSD-streaming / expert-offload; Mirror Speculative Decoding / ANE drafter).

### 3. Incremental design progress

#### S-SPLIT (model vs brain/app) — baseline table
The corpus's own metaphor (SCOPE-Rex doc + Living Index) resolves to:

| Mechanism | Model-internal | App-side (brain) | Both / contract |
|---|---|---|---|
| Next-token decode, SSM scan, attention | ✔ | | |
| Per-token **interrupt score** emission | ✔ (computes) | | signal-linked out via S-CONN |
| **Interrupt threshold τ** (when to switch to full-attn / wake heavy lane) | | ✔ (policy/calibration, `interrupt_calibration.rs`) | app sets τ, model honors it |
| KV cache / fast-weight **state** | ✔ (holds) | ✔ (budgets residency, quarantine) | residency lease (S-CONN) |
| **Abstention** ("defer beats wrong") | model can request | ✔ owns the gate (`LatticeAbstentionGate`) | model proposes, app decides |
| Cold-assembly / route / lane selection | | ✔ (`ColdAssemblyPlan`, RuntimeRouter) | app commands, model executes |
| Retrieval grounding / Cognitive-DAG verification | | ✔ (prefrontal/immune/hippocampus) | feeds back into model context |
| Ternary/quant lane choice | | ✔ | app commands |
| Provenance / RunEventLog | | ✔ (episodic ledger) | model emits events, app records |

Doctrine (from SCOPE-Rex, kept): **"language generation must never be the sovereign of execution."**
The model is the language cortex + a *signal source*; the app is prefrontal control + immune system +
episodic ledger and is the *authority*.

#### S-CONN (master connection) — baseline contract shape
Existing typed primitives already present in code: `AnswerPacket` (`scope_rex/answer_packet.rs`,
`state: implemented` — **no production caller yet**, promotes to `wired` when `StreamingDelegate`
emits one per reply), `InterruptScore`/calibration (AUROC≥0.85 bar, Youden's J threshold),
`LatticeAbstentionGate`, `ComputeResumeLease`, `ColdAssemblyPlan`, `RunEventLog`.
**Proposed two-plane shape (T0 write-plan):**
- **Downlink (model→app):** per-token `InterruptScore` (cheap scalar) + end-of-turn `AnswerPacket`
  (claims, residency signals, ui_label, witnessed-state ref). Streamed, never buffered.
- **Uplink (app→model):** `τ` threshold, `ComputeResumeLease` (grant/revoke heavy-lane compute),
  abstain command, route/lane/ternary selection, residency budget. Must be applied at safe token
  boundaries.
- **Plane separation:** control plane (scalars/commands, UniFFI/async) vs data plane (tensors/KV via
  narrow C ABI + `bytesNoCopy` shared memory) — from the SCOPE-Rex revive. Keeps the uplink off the
  tensor hot path.

#### S-PANEL (control panel) — baseline placement
**Read-half already exists:** `ProvenanceConsoleView.swift` is a read-only projection of
RunEventLog / MutationEnvelope / ClaimLedger / AgentEvent / GraphEvent (rendered via
`GenUIDispatcher`). **Write-half does NOT exist.** Proposed (T0): a new **"Model Cockpit"** surface
(SwiftUI, lives in `Epistemos/Views/Settings/` next to `ProvenanceConsoleView` + the existing
`*HealthRow` diagnostics; reachable from Settings → Diagnostics) that FUSES:
  - **Controls (uplink):** route/lane picker (wire to RuntimeRouter once it's live — note: MASTER
    SYNTHESIS keystone #1 says RuntimeRouter is currently DEAD/0-callers), interrupt-τ slider,
    residency/cold-assembly budget sliders, ternary/quant lane toggle, fast-weight quarantine
    switch, abstention-policy picker.
  - **Telemetry (downlink):** live InterruptScore sparkline, AnswerPacket feed (reuse
    ProvenanceConsole projection), ComputeResumeLease state, RunEventLog tail.
  - **Honesty:** every control shows an orange "inert / T0" witness chip until its Rust signal-bus
    binding is live; never silently no-ops.

### 4. Robustness dimensions (PASS-1 depth = enumerate baseline)

- **D1-COMMS edge cases (initial enumeration):**
  1. *Backpressure* — app deliberates slower than decode → uplink commands must be idempotent +
     timestamped; model keeps decoding under SSM default until a lease/τ change is acknowledged at a
     token boundary (no blocking the decode loop).
  2. *Mid-token abstain / wake-heavy* — applied only at the NEXT safe token boundary; partial token
     never discarded silently (RunEventLog records the boundary).
  3. *Lease revocation* — `ComputeResumeLease` revoke must roll back to the cheap lane deterministically;
     no half-woken heavy lane left resident (ties to D2 KV residency cost).
  4. *Ordering/races* — single-writer uplink queue; downlink is append-only; AnswerPacket carries
     witnessed-state ref so app can detect stale ordering.
  5. *Authority* — no silent reroute / no hidden authority: every route change emits a RunEventLog
     event + AnswerPacket caveat; model cannot self-promote a lane.
  6. *Bus latency budget* — control plane must be O(µs) scalar pass; tensors never cross the control
     plane. (PASS-2 should put a number on this.)
- **D2-PERF (baseline targets to refine):** M2 Pro 16GB ≈ 200 GB/s memory-bandwidth-bound; decode is
  bandwidth-bound so the interrupt gate must be a cheap scalar (target: interrupt-gate overhead <1%
  of per-token decode time). Fast-weight state (LaCT ≥40% finding) is a residency cost to budget, not
  free. Control-panel observability must be poll/throttled (ProvenanceConsole already snapshots at a
  limit, not per-token).
- **D3-QUALITY (baseline):** quality gain comes from (i) abstention correctness (defer beats wrong —
  measured by abstention precision on the refusal/privacy task family), (ii) interrupt firing at the
  right tokens (AUROC≥0.85 bar already in `interrupt_calibration.rs`), (iii) Cognitive-DAG
  verification + retrieval grounding feeding back via uplink. Measure on the **seven task families**
  (note synthesis, research-citation grounding, coding patch planning, writing style transform,
  structured tool JSON, refusal/privacy boundary, latency/abstention) with held-out deterministic
  scorers — no model-graded-primary, no hidden judge.

### 5. Next pass should focus on X
**PASS 2:** (research) skim `~/Downloads/master resarch here` (2026-05-05, newest phrase folder) +
attempt Codex/Claude thread reachability (`~/.codex`, App Support). (design) Deepen **S-CONN** —
put concrete latency numbers on the control-plane bus + define the safe-token-boundary apply protocol
for uplink commands; read `agent_core/src/research/attention_sinks.rs` + `mamba3.rs` to ground the
"switch to full-attention for K tokens" mechanism. Invent a NEW keyword set (Mamba-3 / attention
sinks / StreamingLLM). Rotate D-dimension depth → **D1-COMMS** (the apply-at-boundary + backpressure
protocol in detail).

### PASS 1 summary (see below; PASS 2 follows)
Established the append-only ledger with the permanent standing-brief dimensions header. Confirmed the
local corpus is heavily consolidated already (MASTER_SYNTHESIS 2026-06-19 + 37 SS-* slices); the
newest unconsolidated phrase folder (`master resarch here`, 2026-05-05) is deferred to pass 2. Revived
two under-consolidated nuances from the SCOPE-Rex doc (control/data-plane FFI split; selective
verify-rollback > always-on determinism) and added one fresh external source-card (LaCT, arXiv
2505.23884 — fast weights on 2K–1M-token chunks, ≥40% state-to-param ratio → a quarantine memory
budget, not a live route). Laid down baseline designs for S-SPLIT (model=language cortex/signal
source, app=authority), S-CONN (two-plane downlink/uplink contract over existing typed primitives),
and S-PANEL (a new "Model Cockpit" fusing controls + the existing read-only ProvenanceConsole), plus
a first enumeration of D1/D2/D3 edge cases and measurable targets. All output is T0/T1 write-plan —
no authority docs edited, nothing built ahead of Phase 0→3.

---

## PASS 2 — 2026-06-20 (S-HW + the model↔instant-recall seam; new surfaces S-HW/S-APP-FAST/D-IMPL folded in)

### 1. New research found this pass + source + theme + revive/skip

**Instant-recall code FOUND (the S-HW anchor).** The owner's "Instant Recall" is real, in-process,
and already hardened:
- `Epistemos/KnowledgeFusion/InstantRecallService.swift` — `@MainActor @Observable`, wraps
  `epistemos-core::instant_recall` (binary-quantized two-phase vector index) via `instantRecall*` FFI.
  **<3 ms target**, warns >10 ms (`:378`); FFI runs off-Main on a detached `.utility` task
  (`:507-629`); full provenance via `AgentToolProvenanceRecorder` on every search (requested/started/
  completed/failed). Prewarm path `prewarmForAmbientRecall()` (`:115`); async cancellation-aware
  `searchAsync` (`:507`).
- Companion surfaces: `KnowledgeFusion/RecallContextSnapshot.swift`, `State/ContextualShadowsState.swift`,
  `Views/Recall/ContextualShadowsPanel.swift`, plus the **already-consolidated** research slices
  `docs/research/SS-UMA_INSTANT_RECALL_ZEROCOPY_2026_06_20.md` and `SS-IR_..._POPUP_REDESIGN_...md`.

**THE GAP (from SS-UMA, code-verified — the single most important S-HW/S-APP-FAST finding):** the
local **model does NOT use the warm sidebar index.** Two separate retrieval stacks exist:
  - *Sidebar (warm, fast, accurate):* SQLite **FTS5 BM25** (`SearchIndexService`) + `epistemos-shadow`
    **tantivy BM25 + usearch HNSW + RRF k=60** cdylib (`RustShadowFFIClient`). In-process, mmap-backed,
    bounded heaps, sub-10 ms engines.
  - *Model (colder, duplicate):* `vault_recall`/`knowledge.recall` route through a SEPARATE `VaultStore`
    (its OWN tantivy `MmapDirectory`, `agent_core/src/storage/vault.rs:794-813`); `eidos.query` semantic
    tier is an `InMemorySemanticIndex` — the production HNSW-backed `VaultBackend` is **W-51 NOT-STARTED**
    (`eidos/STATUS.md:71`). So the model queries a colder, less-capable, duplicate index.

**UMA / zero-copy HONESTY (S-HW, do not overclaim):**
  - REAL + already exploited: MLX arrays live in unified memory → weights/KV need NO CPU↔GPU copy;
    `MLXInferenceService` sizes Metal/KV caches against UMA budgets.
  - NOT achievable today: literal zero-copy of retrieved TEXT into the model's KV/context — MLX-Swift's
    public surface is `prompt: String`→tokenizer→tokens; no borrowed-buffer / precomputed-KV API.
    `<related_notes>` is a String concat (`NoteChatState.swift:702`). **Never ship a fake "zero-copy
    KV" claim.**
  - The honest UMA win = **ENGINE UNIFICATION** (model + sidebar share ONE warm shadow handle; Rust→Rust
    returns `Vec<ShadowHit>` borrowed `&str` snippets, removing the JSON round-trip for the LOCAL path)
    — NOT tensor zero-copy into KV.
  - **Bottleneck honesty:** end-to-end model recall is dominated by token GENERATION (100s ms–s), not
    retrieval (already single-digit ms). So the defensible gain from unification is CORRECTNESS/QUALITY
    (model finally hits sidebar-parity RRF/HNSW) + MEMORY (one tantivy index not two: ~15 MB writer heap
    + a second mmap saved) — NOT a dramatic wall-clock speedup. Record as such; do not promise speed.

**External source-card (rotating: LATTICE methods — maps to ternary/quant lane + S-HW).** Ties directly
to the EXISTING repo code `agent_core/src/research/sherry_lattice/{e8.rs,codebook.rs}`:
  - **QuIP#** (Tseng et al. 2024, PMLR v235; repo `Cornell-RelaxML/quip-sharp`): randomized Hadamard
    incoherence + **E8-lattice** codebook (optimal 8-D ball packing) → first high-quality 2-bit LLMs,
    faster than scalar. *(Already partly mirrored by `sherry_lattice/e8.rs`.)*
  - **QTIP** (Tseng et al. 2024, Together AI blog): replaces VQ with **Trellis Coded Quantization** —
    LINEAR cost in dimension (vs VQ's exponential), lower distortion on Gaussian sources, scales to
    higher dims. **NEW vs corpus.**
  - **LLVQ — Leech Lattice VQ** (arXiv **2603.11021**, 2026): 24-D **Leech lattice** (optimal sphere
    packing in dim 24, Viazovska 2022 Fields Medal); beats QuIP#/QTIP at 2-bit on WikiText ppl / MMLU /
    CSR. **NEW, most recent.**
  - **GLVQ** (arXiv 2510.20984): adaptively LEARNS a per-group generation matrix instead of a fixed
    lattice. **NEW.**
  - **Critical D2-PERF caveat (LiftUQ, OpenReview giIsHqVQnF):** VQ decoding causes **irregular,
    inherently sequential memory accesses**; reported decode throughput is unstable and *sometimes
    slower than full-precision*. On a 200 GB/s bandwidth-bound M2 Pro GPU this is the decisive factor —
    a lattice codebook lookup that defeats coalesced/parallel access can LOSE to a simpler uniform/
    ternary kernel. **Map:** lattice VQ is a Pro-research COMPRESSION lane (S-HW), gated under
    `F-ProprietaryCompression-ProvenanceGate`; it must prove Metal-friendly decode (LUT-free or fused)
    before it beats the ternary lane. Revive **YES as source-cards / quarantine**, NOT a live route.

### 2. Keyword set used THIS pass
`instant.?recall|InstantRecall|ambient.?recall|RecallContextSnapshot|ContextualShadows`;
`epistemos-shadow|RustShadowFFIClient|RRF|HNSW|VaultStore|VaultBackend|eidos.query`;
`E8 lattice quantization|QuIP#|QTIP|Leech lattice|LLVQ|GLVQ|trellis coded quantization|LiftUQ`.
(PASS 1 used the corpus-survey + LaCT sets; future passes rotate to Erdős/PatternBoost + orthogonal/
Koopman, and to Mamba-3/attention-sinks per the PASS-1 pointer.)

### 3. Incremental design progress

#### S-HW (bespoke M2 Pro co-design) — baseline doctrine
- **What is genuinely bespoke (defensible):** (1) one warm in-process retrieval spine shared by sidebar
  + model (engine unification, kills the duplicate `VaultStore` tantivy index); (2) MLX weights/KV in
  unified memory (no CPU↔GPU copy) sized to a 16 GB budget; (3) Rust→Rust borrowed-`&str` recall handoff
  (no JSON round-trip on the local path). These need no new Apple API and are honest.
- **What is aspirational (flag T0):** literal zero-copy of retrieved text into MLX KV (no API);
  ANE direct exploitation (Research-tier, MAS-forbidden private API per SCOPE-Rex doc); sparse-texture
  KV virtualization.
- **Single-box training honesty (M2 Pro 16 GB):** full fine-tune of a Qwen/Gemma-class model is NOT
  feasible on 16 GB UMA. What IS feasible: LoRA/adapter training, QAT of small (E2B-class) models, and
  the offline PatternBoost/residency discovery loop. Larger capability must come via distillation/QAT/
  adapters, not on-box full training. (Consistent with the CLAUDE.md Gemma E2B/E4B/12B build-order canon.)

#### S-CONN — the model↔instant-recall seam (deepened)
Instant-recall results are exactly the "low-latency evidence over the signal bus" the brief wants.
Proposed downlink/uplink extension over the existing typed protocol:
- **Uplink (app→model):** when the interrupt fires (`InterruptScore > τ`) the app issues a `RecallLease`
  (a `ComputeResumeLease` variant): "you may spend N ms retrieving"; the brain runs the WARM shadow
  search and injects `Vec<ShadowHit>` as graded evidence.
- **Downlink (model→app):** each recall emits an `AgentToolProvenanceRecorder` event TODAY; promote those
  into the `AnswerPacket.residency_signals` so the cockpit (S-PANEL) shows live "what the model recalled
  + how fresh + which index (shadow vs in-memory)". A provenance tag distinguishing shadow-backed vs
  in-memory recall makes the W-51 gap observable (SS-UMA plan step 1).

#### S-PANEL — wire the recall telemetry
The cockpit's downlink feed (PASS 1) gains a concrete first signal: an **Instant-Recall row** showing
`lastSearchLatencyMs`, `averageSearchLatencyMs`, `maxSearchLatencyMs`, `documentCount`, and a
shadow-vs-in-memory backend chip (orange until W-51 lands). This mirrors the existing `*HealthRow`
pattern and reuses the already-published `InstantRecallService` metrics — zero new plumbing to observe it.

### 4. Robustness dimensions (PASS-2 depth: D-IMPL primary; D1/D2/D3 touched)

**D-IMPL — concrete proposal: the model↔instant-recall shared-spine seam (smallest viable slice).**
- *What to ADD:* an `epistemos-shadow`-backed `impl VaultBackend` (W-51) so `eidos.query` Tier-2/3 +
  `vault_recall` hit the SAME RRF k=60 + HNSW fusion as the sidebar, behind a flag.
- *HOW / file targets:*
  - Crate/module: new adapter in `agent_core/src/eidos/` (e.g. `shadow_backend.rs`) implementing the
    existing `VaultBackend` trait; route `tools/knowledge.rs:222,268` + `tools/vault_search_ladder.rs`
    through it when the flag is on. Keep `VaultStore` as the fallback (never-delete canon).
  - FFI seam: REUSE the existing `shadow_handle_search` C ABI (`RustShadowFFIClient.swift:30-37`,
    plain `char*` JSON) — but for the in-process Rust→Rust path call the shadow engine's Rust API
    directly to return `Vec<ShadowHit>` (borrowed `&str`), skipping the JSON parse. Share ONE shadow
    handle opened at bootstrap (`<vault>/.epcache/shadow`); do not open a 2nd `MmapDirectory`.
  - Flag: mirror `EPISTEMOS_RRF_FUSION_V1` (e.g. `EPISTEMOS_SHADOW_RECALL_V1`); flag-OFF≠done per §3.2
    of MASTER_SYNTHESIS — gated visible in the cockpit with an orange witness chip until verified.
  - Honesty firewall: cloud models keep the JSON tool interface unchanged (only the BACKEND swaps);
    provenance on both paths; vault/graph/TK2-Prose untouched (recall reads the DERIVATIVE shadow index
    only, never source bytes or the editor).
- *Smallest falsifier (T1):* `falsify_shadow_recall_parity` — feed the SAME query to the sidebar shadow
  path and the model recall adapter; assert (a) identical top-K doc_ids (parity), (b) recall path opens
  ZERO additional tantivy `MmapDirectory` (one-handle invariant), (c) provenance event carries
  `backend=shadow`. Bench p50/p95 sidebar-vs-model to PROVE retrieval parity AND that generation (not
  retrieval) is the floor — no fake speedup claim. (Mirrors `falsify_uas_zero_copy_spine.rs` shape.)
- *Tier honesty:* this is a T0/T1 write-plan; W-51 itself is NOT-STARTED and sits behind the Phase 0→3
  gate. Do not build until owner-promoted.

**D1-COMMS (recall edge cases):** recall is cancellation-aware already (`searchAsync` checks
`Task.isCancelled` pre- and post-FFI, `:550,573`) — good backpressure precedent. Edge cases to harden:
(1) a `RecallLease` revoked mid-search must drop results without mutating `@MainActor` metrics (the
async path already deliberately avoids cross-actor metric writes, `:496-506`); (2) recall failure classes
(`non_utf8_json`/`unexpected_json_shape`/`json_decode_failure`/`cancelled`) must surface to the cockpit,
not silently return `[]`; (3) recall must NOT block the decode loop — it runs on a detached utility task,
and the model proceeds on SSM-default until evidence arrives at a token boundary.

**D2-PERF:** retrieval is sub-10 ms (target <3 ms); unification saves MEMORY (~15 MB writer heap + a 2nd
mmap), not latency. The lattice-VQ caveat above is the sharp new perf note: irregular VQ decode can lose
to ternary on a 200 GB/s GPU — measurable target = lattice decode must sustain coalesced Metal access or
it stays research-only.

**D3-QUALITY:** the quality win is the model querying sidebar-parity RRF/HNSW instead of a colder
in-memory index → better grounding/citation on the research-citation + note-synthesis task families.
Measure via `falsify_shadow_recall_parity` top-K agreement + the seven-family held-out scorers; do not
claim a generation-quality jump beyond what grounding parity supports.

### 5. Next pass should focus on X
**PASS 3:** (research) attempt Codex/Claude thread reachability (`~/.codex`, `~/Library/Application
Support/{Claude,Code,Cursor}`, exported `*.jsonl`) and skim `~/Downloads/master resarch here`
(2026-05-05). (external) rotate to **Erdős/PatternBoost/construction-search** OR **orthogonal/Koopman/
RoPE-as-rotation** — pull one primary source and map to S-SPLIT/S-CONN. (design) Deepen **S-CONN**
latency numbers + the safe-token-boundary uplink-apply protocol (carried over from PASS 1), and ground
the "switch to full-attention for K tokens" mechanism by reading `research/attention_sinks.rs` +
`mamba3.rs`. Rotate D-depth → **D2-PERF** (put concrete µs/GB-s numbers on the control-plane bus + the
interrupt-gate overhead budget). New keyword set required.

### PASS 2 summary
Located the actual Instant-Recall implementation (`KnowledgeFusion/InstantRecallService.swift`, <3 ms
binary-quant vector index, fully provenanced, cancellation-aware) and the code-verified S-HW gap: the
local model queries a SEPARATE colder index (`VaultStore` + `InMemorySemanticIndex`) while the sidebar
hits the warm `epistemos-shadow` RRF k=60 + HNSW fusion (W-51 unification NOT-STARTED). Established the
S-HW doctrine with strict UMA honesty (engine unification + borrowed-`&str` handoff are the real wins;
literal zero-copy-into-KV has no MLX API; retrieval isn't the bottleneck — generation is). Added a
lattice-quantization source-card set (QuIP# E8 → QTIP trellis → 2026 Leech-lattice LLVQ → GLVQ) tied to
the repo's existing `sherry_lattice/e8.rs`, with the decisive D2-PERF caveat that irregular VQ decode can
lose to ternary on a 200 GB/s GPU. Produced a concrete D-IMPL proposal — the W-51 `epistemos-shadow`
`VaultBackend` adapter with file targets, the reuse-`shadow_handle_search` FFI seam, an
`EPISTEMOS_SHADOW_RECALL_V1` flag, and a `falsify_shadow_recall_parity` smallest-falsifier — all T0/T1
write-plan behind the Phase 0→3 gate. No authority docs edited.

---

## PASS 3 — 2026-06-20 (S-PRIM primitive inventory; Codex/Claude reachable; PatternBoost; control-bus latency)

**Preservation check (pass start):** ✅ both `RESEARCH_INTENT_AND_QUERY_LOG_2026_06_20.md` and this
ledger exist and are intact. Appended Q16/Q17/Q18 (the three typed standing-brief directives) VERBATIM
to the intent log; read-back confirmed. `docs/fusion/pasted/` is EMPTY → Gemini-70B blueprint integration
deferred (single-writer rule; nothing to fold yet).

### 1. New research found this pass + source + theme + revive/skip

**Codex/Claude threads ARE reachable on disk (major preservation win).**
- `~/.codex/sessions/` — **519 session files**, dir tree `2026/MM/DD/rollout-*.jsonl`; most-recent activity
  2026-06-20; dense cluster of 2026-06-01/02 + 2026-06-09 sessions matching
  `epistemos|epistenos|interrupt|ternary|lattice|70b|master connection`. Also `~/.codex/archived_sessions`.
- `~/.claude/` — `history.jsonl`, `file-history/`, `paste-cache/`, `downloads/` (Claude is where research
  began, per owner). App Support has `Claude`, `Claude-3p`, `Codex`, `com.openai.codex`,
  `com.google.GeminiMacOS`, `Cursor`.
- **Status: reachable, NOT yet mined.** Mining 519 jsonl rollouts is a multi-pass job; don't get stuck.
  **HOW to mine next passes (D-IMPL for the loop itself):** `rg -i "<keyword>" ~/.codex/sessions/2026/06`
  on rotating keywords, newest-first; extract the user/assistant `content` fields; dedupe against the
  ledger; surface only NEW theory (esp. dropped Obscura/Hermes-era ideas + the "Codex was iterating
  theorems then stopped" unfinished work the owner flagged in Q4/Q10). Revive: **YES, incrementally** —
  one date-slice per future pass, recent-first.

**External source-card (rotating: ERDŐS / construction-search — validates the corpus's OWN layer).**
- **PatternBoost** — "Constructions in Mathematics with a Little Help from AI", Charton, Ellenberg,
  Wagner, Williamson, **arXiv:2411.00566** (repo `zawagner22/transformers_math_experiments`, Python+Julia,
  MIT-ish). Alternates a **local classical search phase** (generate many candidate constructions) with a
  **global transformer phase** (train on the BEST candidates → sample new seeds → repeat). Found the best
  known solutions to several long-standing extremal-combinatorics problems incl. a **counterexample to a
  30-year-open conjecture**; follow-ons: hypercube bootstrap percolation (arXiv:2411.19734),
  no-3-in-line / no-5-in-sphere (arXiv:2512.11469). Lineage: Wagner 2021 "Constructions via neural
  networks" (arXiv:2104.14516, cross-entropy/RL) → PatternBoost (transformer replaces RL).
- **MAP (this is the primary source behind the corpus's already-invented layer):** the Living Index's
  **Residency PatternBoost** (`ResidencyPatternBoost`, `AssemblyCandidatePool`, `UASAssemblyGenome`,
  `ConstraintRepairKernel`, `SparseAssemblyFingerprint`, `EliteAssemblyArchive`,
  `ResidencyPatternDistiller`, gated by `LatticeAbstentionGate`/`ComputeResumeLease`) IS the PatternBoost
  loop applied to UAS residency assemblies. PatternBoost validates the design AND its honest fence: it is
  an **OFFLINE/idle DISCOVERY layer (app-side), never live route authority** — exactly the corpus's
  existing constraint. **Revive: YES** as the primary-source citation for the existing layer (no new
  build; strengthens the F-RESIDENCY-PATTERNBOOST bundle's provenance). The model side reuses the
  discovered route/layout MOTIFS; the search itself never runs on the decode hot path (D2-PERF).

### 2. Keyword set used THIS pass
`~/.codex/sessions|~/.claude|history.jsonl|rollout-*.jsonl|archived_sessions`;
`primitive|eml(x,y)|geometry_ir|rotor|Clifford|Koopman|Bauer-Fike|Belnap|FDE|bilattice|tropical`;
`PatternBoost|Erdos|extremal combinatorics|construction search|Wagner constructions|no-three-in-line`.
(Future passes rotate to: orthogonal/unitary parameterization + RoPE-as-rotation; Mamba-3/attention-sinks
(carried from PASS 1); ultrametric/p-adic (E2) + simplex/curvature/Apollonian (H14) primitives.)

### 3. S-PRIM — PRIMITIVE INVENTORY (running; this pass covers 4 of N)

> Honest stance: these are research-tier (`feature = "research"`, MAS/Pro do not compile them by
> default). Each earns a role ONLY where it genuinely helps; otherwise it stays a verifier/research organ.

| Primitive | What it is | Lives in | Earns a role on | Honest tier | Smallest falsifier (beneficial?) |
|---|---|---|---|---|---|
| **EML** | `eml(x,y)=exp(x)−ln(y)`; Liouvillian-universal on its solvable subdomain (arXiv:2603.21852), fenced by Smith's quintic counter-construction (arXiv:2605.01636 inexpressibility) | `research/eml/*`, `eml_ir/`, `bin/epistemos_eml.rs`, `Shaders/morph_eval_reduced.metal` | **app-side** = the ULP **arithmetic floor / oracle** that gates AnswerPacket (F-ULP-Oracle); NOT a model layer | T1 (substrate floor built; AnswerPacket schema-freeze GATED on ULP fixture) | `F-ULP-Oracle`: eml Metal intrinsic matches the f64 reference within target ULP on the 412k+2048 fixture; if it can't gate arithmetic honestly it adds nothing |
| **Geometry-IR** | Clifford-algebra **rotor sandwich** R v R̃ (Hestenes); orientation/rotation operator | `research/geometry_ir/{mod,rotor,evaluator,certificate}.rs` | **both** — model-internal (RoPE-as-rotation = a rotor on 2-blades; orthogonal/unitary transform lane) AND app-side geometric deliberation (graph layout) | T1 (rotor math + tests land; no model wiring) | rotor-vs-quaternion parity test (already shipped: e1→e2 under π/2) + a RoPE-equivalence check; beneficial iff it unifies RoPE + orthogonal params without extra FLOPs |
| **Koopman** | SSM A-matrix as discrete Koopman operator (MamKO, ICLR 2025); **Bauer-Fike** eigenvalue-perturbation bound | `research/koopman.rs` (+ `test_time_regression`, `continual_learning::titans_mac`) | **model-internal** — the spectral bridge that makes the **ternary/quant lane SAFE**: quantizing A shifts Koopman eigenvalues by ≤ κ(V)·‖ΔA‖ (WBO-6) | T1 (bound + verifier built) | `F-WBO-6`: measured eigenvalue shift under ternary A-matrix quant ≤ Bauer-Fike bound; if the bound doesn't hold, ternary-on-SSM is unsafe → don't ship it |
| **Belnap FDE** | 4-valued bilattice (True/False/**Both**/**Neither**) over the claim graph; truth-axis meet/join + info-axis join | `research/belnap.rs` | **app-side deliberation + signal bus** — claim-graph truth state; **Neither → abstain**, **Both → contradiction flag** feeding `LatticeAbstentionGate` | T1 (logic + ops built) | abstention-precision test: routing `Neither` to defer beats forcing a `True/False` guess on the refusal/privacy task family ("defer beats wrong") |

**Other primitives seen (queued for future-pass inventory, not yet evaluated):** Tropical / `tropical_ir`
(min,+ semiring — Viterbi/shortest-path scoring), `info_ir` / `operator_ir` / `scan_ir` (IR stack),
`sherry_lattice` E8/Leech (PASS 2 — quantization codebook), `acs/kuramoto` (phase-sync), `active_assembly`,
plus the owner-named **ultrametric/p-adic (E2)** and **simplex/curvature/Apollonian (H14)** — search those
named docs next pass before asserting a role.

### 4. S-CONN — concrete control-bus latency numbers (D2-PERF, M2 Pro 16GB ≈ 200 GB/s)

Grounding the bus budget in bandwidth-bound reality:
- **Per-token decode floor:** decode is memory-bandwidth-bound. A ~4B model at ~4-bit reads ≈2 GB of
  weights/token → ≈2 GB ÷ 200 GB/s ≈ **10 ms/token** hard floor; real local Qwen-4B ≈ 20–50 ms/token
  (20–50 tok/s). **This is the time budget the bus lives inside.**
- **Downlink — `InterruptScore`:** ONE f32/token from a cheap probe head. Target compute **< 1% of
  per-token decode** (< ~0.2–0.5 ms). Transport = append to a lock-free SPSC ring in shared (unified)
  memory; Swift cockpit consumes at **display rate (≤ 60 Hz, throttled), NOT per token** → observability
  cost ≈ 0 on the decode loop.
- **Downlink — `AnswerPacket`:** once per turn (not per token) → negligible.
- **Uplink — `τ` / `ComputeResumeLease` grant·revoke / abstain / route·lane·ternary:** scalar/enum
  commands. Writer = single-writer queue or atomic cell in shared memory; the decode loop **READS** it
  with an **O(ns) atomic load at each token boundary** (no syscall, no lock, no allocation). Apply latency
  ≤ 1 token-time (~20–50 ms worst case) is acceptable because commands take effect at the next safe
  boundary anyway (D1 PASS-1 rule).
- **HARD RULE (S-HW):** NO tensor/KV ever crosses the control plane. Control plane = scalars/enums only
  (UniFFI/atomic); data plane = KV/embeddings stay in unified memory via `bytesNoCopy` (no CPU↔GPU copy).
  This is what keeps the bus off the bandwidth budget.
- **Measurable target + falsifier:** `falsify_signal_bus_overhead` — measure tokens/s with the bus
  ENABLED vs DISABLED on a fixed prompt; **assert throughput delta ≤ 1%** and interrupt-gate p99 ≤ 1% of
  per-token time. If the bus can't stay under 1%, it stalls the decode loop and must be redesigned
  (e.g. batch the score, widen the boundary interval). Honest note: these are TARGETS — no bus exists in
  product yet (T0 design); the numbers are derived from the bandwidth model, not measured.

### 5. Robustness dimensions (PASS-3 depth: D2-PERF primary — see §4; D1/D3 touched)
- **D1-COMMS:** the atomic-load-at-boundary uplink (§4) is the concrete mechanism for PASS-1's
  "apply-at-safe-boundary" rule; lease revocation = flip the atomic cell, decode loop reads it next token
  and rolls back to the cheap lane (no half-woken heavy lane). Authority: every route/lane change still
  emits a RunEventLog event (no silent reroute).
- **D3-QUALITY:** Belnap `Neither→abstain` (§3) is the primitive-level mechanism for "defer beats wrong";
  Koopman/Bauer-Fike (§3) protects quality under ternary quant (no eigenvalue blow-up → no degenerate
  decode). PatternBoost motifs improve route/layout quality offline without risking live correctness.

### 6. Next pass should focus on X
**PASS 4:** (research) mine ONE recent Codex date-slice (start `~/.codex/sessions/2026/06/01` — densest
epistemos cluster) for dropped/unfinished theory; surface NEW items only. (external) rotate to
**orthogonal/unitary parameterization + RoPE-as-rotation** (ties to the Geometry-IR primitive) — one
primary source. (S-PRIM) evaluate Tropical (min,+) + the owner-named ultrametric/p-adic (E2) and
simplex/curvature/Apollonian (H14) — locate those docs first. (design) deepen **S-PANEL** wiring of the
InterruptScore sparkline + the signal-bus ring buffer to the cockpit. Rotate D-depth → **D1-COMMS**
(formal ordering/race proof for the SPSC ring). Check `docs/fusion/pasted/` — if non-empty, integrate the
Gemini-70B block (single-writer). New keyword set required.

### PASS 3 summary
Honored the preservation duty (both ledgers intact; appended Q16–Q18 verbatim to the intent log;
`pasted/` empty so blueprint deferred). Confirmed **Codex + Claude threads are reachable** (519 Codex
rollout sessions under `~/.codex/sessions/2026/`, Claude `history.jsonl`) and recorded a concrete
recent-first mining recipe for future passes (not mined this pass — too large to fit, don't get stuck).
Added the **PatternBoost** primary source (arXiv:2411.00566) and mapped it as the citation behind the
corpus's existing **Residency PatternBoost** offline-discovery layer (app-side, never live route
authority). Advanced **S-PRIM** with an evaluated 4-primitive inventory — EML (app-side ULP arithmetic
floor), Geometry-IR (model+app rotor / RoPE-as-rotation), Koopman/Bauer-Fike (model-internal ternary-quant
safety bound), Belnap FDE (app-side abstention via Neither) — each with role/side/tier/falsifier, plus a
queue of un-evaluated primitives. Put **concrete latency numbers** on the S-CONN control bus tied to the
200 GB/s bandwidth floor (interrupt score < 1% of a 10–50 ms/token budget; scalar-only control plane;
O(ns) atomic-load uplink; `falsify_signal_bus_overhead` ≤ 1% throughput target). All T0/T1 write-plan; no
authority docs edited.
