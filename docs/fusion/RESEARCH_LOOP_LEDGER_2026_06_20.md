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
- **Preservation duty (REINFORCED 2026-06-20):** at pass start, confirm
  `docs/fusion/RESEARCH_INTENT_AND_QUERY_LOG_2026_06_20.md` + this ledger exist & are intact. **ALL research
  goes to the ledger; ALL owner queries go to the intent log VERBATIM.** Append any owner query not yet
  logged (verbatim), and verify with read-back. Double-check every write (write → read-back → confirm).
  Failure mode to prevent: "research dropped because it wasn't saved." Nothing beneficial is ever lost.
- **Single-writer rule for the pasted Gemini 70B blueprint:** a separate worker ingests it into
  `docs/fusion/pasted/` and hands back a "ledger integration block." THIS ledger's writer (the loop) is
  the single integrator — on a LATER pass, once `docs/fusion/pasted/` is non-empty, fold its accepted
  items (Engram O(1) lookup / MoLKV, ReLU² activation sparsity, SpQt zigzag, sliding-window FFN cache,
  pre-attention prefetch router, the third "Lookup Plane") in here. Do NOT write concurrently.

**DEPTH RULE — "3 cycles deep per pass type" (owner brief 2026-06-20):** each research-pass TYPE
(Codex/Claude mining, primitive evaluation, source verification, design surface S-CONN/S-PANEL/S-HW,
M0/M1 specs) must run ~3 deepening cycles before being treated as done — don't skim one pass and move on.
Cycle 1 = enumerate/breadth; cycle 2 = specify/mechanism; cycle 3 = falsifiers/proof. Record cycle 1/2/3
progress per topic; a topic is "done" only after its 3rd cycle (or honestly marked partial with the next
cycle named).

**SPINE FRAMING — DUAL-BRAIN / SPLIT-BRAIN with RUST as the low-latency interrupt substrate (owner brief
2026-06-20):** this is the architecture's SPINE, not a wrapper. BOTH the model (kernel) and the app do
heavy lifting; **Rust is the fast layer that makes interrupting + co-working with the model cheap**
(`signal_bus.rs`, `interrupt_calibration`, the Helios organs). Every design pass respects: **model = one
brain (generation/spine), app = the other brain (authority/deliberation), Rust = the fast bus between
them.** S-SPLIT/S-CONN/S-PANEL/S-HW all serve this spine; "two-brain" (owner term, PASS-4) = this framing.

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

---

## PASS 4 — 2026-06-20 (Gemini-70B blueprint integration; June-1 Codex slice; orthogonal/RoPE; Tropical; cockpit D-IMPL)

**Preservation check (pass start):** ✅ intent log + this ledger intact. Appended Q19 verbatim to the
intent log (read-back confirmed). `docs/fusion/pasted/` now NON-EMPTY → blueprint integration runs THIS
pass (single-writer; I am the sole ledger writer, the ingestion worker only produced the eval block).

### 1. GEMINI-70B COCKTAIL BLUEPRINT — integrated (external, T0 unless noted)

**Sources (preserved, verbatim):** `docs/fusion/pasted/GEMINI_70B_COCKTAIL_BLUEPRINT_2026_06_20.md` +
evaluation `…_EVALUATION_2026_06_20.md` (dedup grepped against live repo 2026-06-20 by the ingestion worker).

**Already-canon (dedup — do NOT rebuild):** InterruptScore = `epistemos-research/src/interrupt_score.rs`
+ `research/interrupt_calibration.rs` · attention-interrupt = `research/attention_sinks.rs` · active
assembly = `research/active_assembly/*` · Residency Governor/ColdStream = `helios/*` +
COLDSTREAM_RESIDENCY_TRANSPORT · UAS zero-copy = `uas/*` + F-UAS-CopyCount · packet router =
`helios/packet_router.rs` + `Shaders/PacketRouter1bit.metal` · SSM/Mamba = `research/mamba3.rs` +
`koopman.rs` · deliberation = `cognitive_dag/*` · verify = `lean/*` + SCOPE-Rex · Engram concept =
`epistemos-research/src/engram.rs` (Lane-3, **type surface only**).
**Honesty corrections adopted:** (i) **SpQt is NEW** — no "GPT 6.md"/SpQt warning exists in canon (name
unverified, SpQR-adjacent). (ii) **Engram = Lane-3 hash-table type surface only**; **MoLKV absent**; the
1/100000 activation ratio is an UNVERIFIED claim. (iii) Blueprint "4-bit 70B = 35-40 GB" is consistent
with `F-MoEActiveParamsMemoryTruth` (active-params ≠ memory-fit).

**ACCEPTED new+beneficial items (side · tier · smallest falsifier):**
| Item | What | Side | Tier | Smallest falsifier |
|---|---|---|---|---|
| **(e) Pre-attention predictive prefetch** | low-rank predictor before layer L predicts L+1 active experts → async NVMe→UMA prefetch while L computes (DejaVu / PowerInfer) | both (model: cheap predictor head; app: async prefetch on Helios) | **T1** | `F-PreAttentionPrefetch`: top-k recall ≥ R on held-out tokens AND prefetch hides ≥ M% of SSD stall (Metal counters). Recall without latency-hiding ≠ win. |
| **(d) Sliding-window FFN weight cache** | keep union of recent-token active params resident, stream only the delta (~98% I/O cut, workload-dep.) (LLM-in-a-flash) | brain/app (Residency Governor policy on existing transport) | **T1** | `F-SlidingWindowFFNCache`: replay real decode trace; bytes-streamed with vs without window; win = ≥K% I/O cut with **zero** logit change. |
| **(f) Row-column on-disk bundling** | store up/down-proj of a unit contiguously on SSD → one large sequential read per expert (avoids random-I/O GPU bubbles) (LLM-in-a-flash) | brain/app (UAS on-disk artifact layout) | **T1** | `F-RowColBundling`: MB/s + IOPS bundled vs unbundled on owner NVMe; win = ≥T× throughput, identical bytes. |
| **(a) MoLKV / Engram-real** | move static facts out of FFN into token-ID-indexed KV lookup experts on SSD; hidden state = dynamic query vs cached KV (no dense FFN step) (DeepSeek Engram/MoLKV — **verify sources**) | both (model: lookup layer at depths e.g. 2 & 15; app/UAS: SSD table + zero-copy fetch) | **T0→T1** | `F-MoLKV-LookupEquivalence`: replace one early FFN with frozen LUT/KV-expert; (i) output parity within ε on held-out probe, (ii) per-token lookup overhead <3% wall-clock, table mmap'd (copy-count=0 via F-UAS-CopyCount). |
| **(b) ReLU²/ReLU activation-sparsity spine** | ReLU² FFN instead of SwiGLU → >90% activation sparsity = the ENABLER for (d)/(e)/skip-decode (PowerInfer/SmallThinker/ReLU-Strikes-Back) | model (arch choice); exploitation = app | **T0** (needs finetune to realize sparsity honestly) | `F-ReLU-ActivationSparsity`: measured sparsity ≥90% on held-out AND downstream loss not worse than SwiGLU by >X. Sparsity that costs quality ≠ win. |
| **(c) SpQt zigzag skip-decode layout** | column-wise zigzag weight grouping within quant groups so GPU threadgroups skip zeroed chunks (turns sparsity into skipped FLOPs) (name unverified, SpQR-adjacent) | model+kernel (quantizer↔Metal decode co-design) | **T0** (kernel, downstream of M0/M1) | `F-SpQt-SkipDecode`: Metal kernel decodes zigzag block **bit-exact** vs dense ref AND ≥N% fewer threadgroup MACs when mask is sparse. Bit-exactness gates; speedup is payoff. |
| **(g) First-class Lookup/Engram plane** | formalize 3rd plane (State + Episodic + computation-free **Lookup**) alongside `epistemos-research/src/five_planes.rs` | both (framing) | **T0 framing** | none alone — bind to `F-MoLKV-*`; do NOT promote on framing alone. |

**Leverage ranking on the 16 GB box (highest first):** (e) prefetch → (d) window cache → (f) bundling →
(a) MoLKV → (b) ReLU² spine → (c) SpQt → (g) plane framing.

**MERGED BUILD ORDER adopted (M0/M1 gate stays FIRST — blueprint's Week-1 kernels re-ordered, nothing dropped):**
`M0` interrupt-moves-loss at toy scale (CPU-canonical; the ONE new variable) → `M1` close
`InterruptInvariant`/Bauer-Fike Lean `sorry` (spectral-perturbation bound under quant) → `B1`
sliding-window cache + row-column bundling (app-only, rides Helios/UAS) → `B2` pre-attention prefetch
(extends `packet_router.rs`) → `B3` `SelectiveScan.metal` bit-exact-vs-Mamba-2 (**blueprint Week-1 kernel
MOVED here**) → `B4` ReLU² spine + SpQt → `B5` MoLKV/Engram-real + Lookup plane → `B6` HeavySkill
deliberation loop (halt→K trajectories→verify via SCOPE-Rex/Lean→inject→resume) on `cognitive_dag/*` +
ColdAssemblyPlan/ComputeResumeLease. **Rule:** M0→M1→app-systems(B1/B2)→kernels(B3)→model-arch(B4/B5)→
deliberation(B6). Letting a 6-week kernel plan precede M0/M1 would invert the tier gate.
**Owner decisions still pending:** (1) verify DeepSeek Engram + MoLKV primary sources; (2) confirm "SpQt"
real name; (3) green-light B1 as a PARALLEL app-systems track vs strict-serial-after-M0.

### 2. June-1 Codex slice mined (one slice — corroboration, honest)

`~/.codex/sessions/2026/06/01/` (59 files). Densest architecture file =
`rollout-2026-06-01T14-22-20-…019e84a3.jsonl` (1213 topic hits). Phrase histogram:
`cocktail` 1011 · `fast weights` 319 · `bitnet` 41 · `cold assembly` 40 · `two-brain` 8 ·
`model wrapper` 8 · `attention sinks` 7 · `ternary lane` 1 · `model+app` (several). **Honest read:** this
slice IS the lineage thread behind the 70B-cocktail + fast-weights + model/app split — it CORROBORATES
the ledger rather than adding dramatically new theory. Two surfaceable terms: **"two-brain"** (the owner's
own framing for the model↔app split — adopt as a synonym for S-SPLIT) and **"model wrapper"** (the app as
a wrapper around the model — consistent with S-CONN). Deeper line-level decision extraction from this
1011-"cocktail" file is queued for PASS 5 (don't get stuck this pass). No NEW dropped-theory item
surfaced from the histogram alone.

### 3. External source-card (rotating: ORTHOGONAL / unitary parameterization + RoPE-as-rotation)
Maps directly to the **Geometry-IR** primitive (§4) and the model spine.
- **"Rethinking RoPE: A Mathematical Blueprint for N-dim Positional Encoding"** (arXiv **2504.06308**):
  RoPE = rotation in the special-orthogonal Lie algebra 𝔰𝔬(n); ND-RoPE via maximal abelian subalgebra;
  cross-dim interactions via a change of basis = learning an orthogonal Q (Cayley / matrix-exp / Givens).
- **ComRoPE** (arXiv **2506.03737**): trainable **commuting angle matrices**; pairwise commutativity is
  the necessary+sufficient condition for offset-robust positional encoding — unifies RoPE variants.
- **Orthogonal-parameterization toolbox** (JMLR 22-0026 OCNN; Meunier 2022 Lipschitz; PyTorch
  `torch.nn.utils.parametrizations.orthogonal`): **Cayley** `Q=(I−A)⁻¹(I+A)` (param-efficient, n(n−1)/2
  params, but matrix-inversion instability), **Householder** (product of reflections, overparam for SO(n)),
  **Givens** (fine-grained plane rotations), **matrix-exp** (skew→orthogonal), and explicitly
  **Clifford-algebra rotors** — all condition-number-1 (preserve gradient norm; prevent exploding/vanishing).
- **MAP:** the repo's `geometry_ir/rotor.rs` (Clifford rotor sandwich) is *literally one of the listed
  orthogonal parameterizations*. So Geometry-IR is not exotic — it's a principled member of the
  RoPE/orthogonal family. **Design consequence:** RoPE, the orthogonal/unitary lane, and Geometry-IR
  UNIFY under SO(n); a rotor-based positional/transport op is a legitimate model-internal choice with
  free gradient-norm preservation (helps training stability on the 16 GB single-box). Revive: **YES** as
  the primary-source backing for treating Geometry-IR as the model-spine rotation primitive.

### 4. S-PRIM inventory (continued — Tropical evaluated; p-adic/Apollonian honestly deferred)

| Primitive | What it is | Lives in | Earns a role on | Honest tier | Smallest falsifier |
|---|---|---|---|---|---|
| **Tropical** | (max,+)/(min,+) semiring; Zhang-Naitzat-Lim 2018 (arXiv:1805.07091): **a feedforward ReLU net with rational weights computes exactly a tropical rational function** | `research/tropical.rs` + `tropical_ir/` | **both** — model-internal: the EXACT theory of the blueprint's ReLU²-sparsity spine (§1b) (tropical degree ↔ #linear regions ↔ activation pattern); app-side: (min,+) shortest-path/Viterbi scoring on the claim graph | T1 (semiring + affine-completeness substrate + F-Tropical-Side-Quest built) | tie to `F-ReLU-ActivationSparsity`: tropical region-count predicts measured activation-sparsity of the ReLU² spine; if it can't characterize the spine's sparsity it adds no design leverage |
| **Geometry-IR** *(re-confirmed §3)* | Clifford rotor = an orthogonal/SO(n) parameterization (RoPE family) | `research/geometry_ir/rotor.rs` | model-internal rotation/positional + app graph layout | T1 | rotor↔RoPE/Givens equivalence + condition-number-1 (gradient-norm) check |
| **ultrametric / p-adic (E2)** | owner-named theorem ("E2") for hierarchical/tree distance | **NOT a research module** (grep: no `padic`/`ultrametric` impl; only incidental mentions) | TBD — likely app-side hierarchical memory distance IF built | **T0 doc-tier only** (not implemented) | n/a yet — locate the "E2" doc first; do NOT force a role |
| **simplex / curvature / Apollonian (H14)** | owner-named theorem ("H14") | **NOT a research module** (grep: no Apollonian impl) | TBD | **T0 doc-tier only** (not implemented) | n/a yet — locate the "H14" doc first; do NOT force a role |

**Honest stance:** Tropical genuinely helps (it's the formal theory of the ReLU spine the blueprint wants
— a real cross-link, not decoration). p-adic (E2) and Apollonian (H14) are owner-named DOC theorems with
NO implementation in `research/` — they stay T0 doc-tier; next pass must locate the named docs
(`docs/fusion/` / lattice explainer §primitives) before asserting any role. No forced inclusion.

### 5. D-IMPL — wire the cockpit InterruptScore feed (concrete proposal)
*What to ADD:* the downlink half of S-CONN/S-PANEL — stream `InterruptScore` from the Rust decode loop to
the Swift "Model Cockpit" as a throttled sparkline, reusing the ProvenanceConsole projection pattern.
- *Rust producer:* `agent_core/src/research/interrupt_calibration.rs` already owns the score type;
  add a lock-free SPSC ring (e.g. `agent_core/src/research/signal_bus.rs`, new) that the decode loop
  pushes ONE f32/token into (non-blocking; drop-oldest `bufferingNewest`-style if full — never block decode).
- *FFI seam:* a plain C-ABI poll `signal_bus_drain_scores(handle, *mut f32, cap) -> count` returning the
  newest ≤cap scores (mirror the `shadow_handle_search` C-ABI style; NO tensor crosses it — scalars only,
  per the S-CONN hard rule). Swift reads via `@_silgen_name`, like `RustShadowFFIClient`.
- *Swift consumer:* an `InterruptScoreFeed` `@MainActor @Observable` (next to `InstantRecallService`'s
  metrics shape) polled by a `TimelineView(.periodic)` at ≤10 Hz (NOT per token — observability cost ≈ 0
  on the decode loop, per D2-PERF); rendered as an `InterruptScoreRow` in the cockpit, mirroring
  `EditorBundleHealthRow`/`SearchFusionHealthRow`. Orange "inert / T0" witness chip until the producer is live.
- *Flag:* `EPISTEMOS_SIGNAL_BUS_V0` (flag-OFF≠done; gated-visible with the witness chip until verified).
- *Smallest falsifier:* `falsify_signal_bus_overhead` (from PASS 3) — tokens/s with bus ON vs OFF, assert
  ≤1% delta + drain is allocation-free; plus `F-InterruptFeedOrdering` — scores arrive monotonically by
  token index, drop-oldest never reorders. *Tier:* T0/T1 write-plan; no decode loop exists in product yet,
  so this is the wiring spec, not a build.

### 6. Next pass should focus on X
**PASS 5:** (research) line-level mine the dense June-1 Codex file (`…14-22-20…019e84a3`, 1011 "cocktail"
hits) for actual DECISIONS/dropped theory — extract user+assistant content, dedupe vs ledger; then the
next date-slice (`2026/06/02` cluster). (S-PRIM) LOCATE the "E2" (p-adic) and "H14" (Apollonian) docs in
`docs/fusion/` + lattice explainer §primitives; evaluate or honestly mark absent. (external) verify the
DeepSeek Engram/MoLKV primary sources (blueprint owner-decision #1) + confirm the "SpQt" real name
(#2). (design) **S-PANEL uplink controls** — the WRITE half (τ slider, lease grant/revoke, abstain,
route/lane) binding to the signal bus; D-depth → **D1-COMMS** formal SPSC ordering/race proof. New keyword set.

### PASS 4 summary
Integrated the Gemini-70B cocktail blueprint as the single ledger writer: recorded the verified dedup
(InterruptScore/ColdStream/UAS/packet-router/Engram-concept already canon), adopted the ingestion worker's
honesty corrections (SpQt is NEW; Engram is a Lane-3 type surface only; MoLKV absent; 1/100000 ratio
unverified), folded the 7 accepted items (pre-attention prefetch, sliding-window FFN cache, row-column
bundling, MoLKV/Engram-real, ReLU² spine, SpQt zigzag, Lookup-plane framing) each with side/tier/falsifier,
and adopted the merged build order that keeps M0 (interrupt-moves-loss) → M1 (Bauer-Fike Lean sorry) FIRST
with the blueprint's Week-1 kernels re-ordered to B3 (nothing dropped). Mined one June-1 Codex slice
(corroborates the cocktail/fast-weights/two-brain thread; adopted "two-brain"/"model wrapper" as
S-SPLIT/S-CONN synonyms; deeper extraction queued). Added an orthogonal/RoPE source-card (arXiv 2504.06308
+ ComRoPE 2506.03737) proving Geometry-IR's Clifford rotor is a principled SO(n)/RoPE-family orthogonal
parameterization with free gradient-norm preservation. Advanced S-PRIM: Tropical evaluated (the exact
theory of the blueprint's ReLU spine — a real cross-link), p-adic (E2) + Apollonian (H14) honestly marked
T0 doc-tier (no implementation found; locate docs next pass). Produced a concrete cockpit InterruptScore
D-IMPL (SPSC ring in `signal_bus.rs` → scalar-only C-ABI drain → `@_silgen_name` → `InterruptScoreRow` at
≤10 Hz; `EPISTEMOS_SIGNAL_BUS_V0`; `falsify_signal_bus_overhead` + `F-InterruptFeedOrdering`). All T0/T1
write-plan; no authority docs edited.

---

## PASS 5 — 2026-06-20 (Codex decisions; E2/H14 located; Engram+SpQt verified/corrected; S-PANEL uplink design)

**Preservation check (pass start):** ✅ both ledgers intact. Appended Q20 verbatim to the intent log
(read-back confirmed). Writes below double-checked via read-back at pass end.

### 1. June-1 Codex line-level mining — concrete DECISIONS (new, not just corroboration)
From `~/.codex/sessions/2026/06/01/rollout-…14-22-20…019e84a3.jsonl` (bounded extraction). Verbatim
owner/assistant fragments that encode **architecture decisions** now folded into the ledger:
- **"all remain UAS-addressed substrate objects. The app owns route selection; the model does not
  silently choose its own hidden brain."** → the **no-hidden-authority** principle stated explicitly in
  the owner's own thread. Directly hardens **S-CONN authority** + **D1-COMMS**: route/lane selection is
  an APP (brain) prerogative; the model may emit signals/requests but cannot self-promote a lane. Adopt
  verbatim as the S-CONN authority axiom.
- **"the size of the model doesn't matter because it is directly tied to the SSD and based on the
  unified address [space]"** → confirms the **cold-assembly thesis**: model size is COLD material
  (SSD/UAS-addressed), not a live-RAM promise. Aligns with CLAUDE.md TurboVec/QAT canon ("model size is
  cold material, not a live-RAM promise") and the blueprint's residency governor. Reinforces S-HW.
- **"Epistemos, a local cognitive substrate. Do not reduce it to a chatbot, notes app, model wrapper,
  MLX demo, or EML-only system."** → the owner's OWN statement that the system is **not EML-only** —
  primary-source justification for the **S-PRIM** surface (Q14 / PASS 3). The spine is
  `Intent → MissionPacket → …`.
- Honest note: the dense file is dominated by "cocktail"/"fast weights" (PASS 4); this pass extracted the
  3 decision-bearing fragments above. The 2026-06-02 cluster (12+ files) is queued for PASS 6 — not mined
  here to avoid getting stuck.

### 2. S-PRIM — E2 / H14 LOCATED (corrects PASS 4's "not implemented")
Found in `docs/HELIOS_V5_DOC_6_THEOREM_CANON.md` + the theorem registry (they live in
`epistemos-research/src/theorems/`, NOT `agent_core/src/research/` — why PASS-4 grep missed them):

| Primitive | What it is | Lives in | Earns a role on | Honest tier | Smallest falsifier |
|---|---|---|---|---|---|
| **E2 — Ultrametric-Sheaf Gluing** | ultrametric/p-adic local-section gluing into a global section (sheaf condition over a hierarchical/tree distance) | `epistemos-research/src/theorems/e2_sheaf_gluing.rs` (theorem canon E2, tier L3→L1, deg ≤2) | **app-side deliberation** — hierarchical memory / claim-graph consistency: glue locally-consistent evidence sections into a globally-consistent answer; ultrametric distance = the vault's tree/namespace hierarchy | **T1** (implemented theorem, L3→L1) | `F-E2-SheafGlue`: locally consistent overlapping evidence sections that satisfy the gluing condition produce a unique global section; if local sections conflict (no gluing) the gate must ABSTAIN rather than fabricate a global claim (ties to Belnap `Neither`) |
| **H14 — Apollonian curvature constraint** | Descartes/Apollonian circle-packing curvature relation | theorem canon H14 (tier L3, "future Apollonian audit log" — **NOT implemented**) | **advisory fence ONLY** | **T0 advisory** — DO NOT promote | n/a — H14's own canon entry records the Apollonian **local-global conjecture is FALSE** (Haag-Kertzer-Rickards-Stange 2024); any Epistemos claim depending on Apollonian local-global must be refactored to the refined conjecture. H14 is a *cautionary falsifier protocol*, not a beneficial primitive |

**Honest outcome:** E2 is a genuine, implemented primitive → promoted with a real role (hierarchical
sheaf-gluing for evidence consistency + abstention). H14 is NOT a beneficial primitive — it is a
"don't depend on Apollonian local-global" fence; recording it honestly and **not forcing it in**.

### 3. Source verification / CORRECTIONS to PASS-4 integrations

**Engram — VERIFIED real, but PASS-4 claims CORRECTED.**
- ✅ **Verified:** DeepSeek "Conditional Memory via Scalable Lookup" (**arXiv:2601.07372**, Liang Wenfeng
  + Peking U). Engram = O(1) **hashed N-gram embedding lookup** as a *conditional-memory sparsity axis*
  complementing MoE; multi-head hashing for collision control; table offloaded to **host DRAM** (not GPU).
  **U-shaped Sparsity-Allocation law → 20–25% of sparse budget to Engram** (ρ≈75–80% MoE); scaled to 27B;
  real gains (MMLU +3.4, BBH +5.0, HumanEval +3.0, etc.).
- ❌ **CORRECTION 1 — "MoLKV / Mixture of Lookup KV Experts" + "hidden-state-as-query against cached KV":**
  this is a **Gemini conflation**, NOT the Engram paper's mechanism. Engram is N-gram-hash → embedding
  table → context-gated fusion; it is NOT "KV experts queried by the hidden state." Retract the MoLKV
  framing; keep the verifiable Engram mechanism. PASS-4 item (a) re-labeled **"Engram conditional-memory
  lookup (arXiv:2601.07372)"**; falsifier renamed `F-Engram-LookupEquivalence`.
- ❌ **CORRECTION 2 — "1/100000 activation ratio":** unsupported by the paper → **retracted**.
- ✅ **VALIDATION upgrade:** the repo's `engram.rs` `RECOMMENDED_STATIC_FRACTION` 20–25% (PASS-4 flagged
  "heuristic not theorem") now **matches the DeepSeek U-shaped empirical optimum** → upgrade its note from
  "heuristic" to "matches primary-source (arXiv:2601.07372) empirical optimum 20–25%." Still empirical, not
  a proven theorem, but no longer an unsourced guess.

**SpQt — VERIFIED real; PASS-4 "name unverified / SpQR-adjacent" CORRECTED (big S-HW win).**
- ✅ **Verified:** SpQt = "**Enabling Dynamic Sparsity in Quantized LLM Inference**" (**arXiv:2511.04477**,
  Rongxiang Wang, Kangyuan Shu, Felix Xiaozhu Lin). Real system, NOT merely SpQR-adjacent (SpQR =
  arXiv:2306.03078 is a *different* outlier-sparse-quant method). SpQt = **zigzag column-wise layout within
  quant groups + row-major superblock storage + specialized GEMV kernel + compact sparse-index runtime
  with dynamic load-balancing**. **Implemented on llama.cpp + Metal Shading Language for Apple Silicon;
  up to 1.55× faster decoding vs dense quantized, accuracy comparable.** Uses TEAL sparsity thresholds;
  dense kernels for prefill, sparse for decode.
- **S-HW consequence (major):** SpQt is *already Apple-Silicon/Metal/llama.cpp-native* — it is the most
  directly portable of the blueprint items to the owner's M2 Pro + the existing llama.cpp lane. Upgrade
  PASS-4 item (c) note: name CONFIRMED, source arXiv:2511.04477, **and it pairs with the ReLU² spine (b)**
  — SpQt is the *kernel that turns the spine's activation sparsity into actual skipped Metal work*.
  Falsifier `F-SpQt-SkipDecode` stands; add target "reproduce ≤1.55× decode speedup on M2 Pro at equal
  accuracy." Tier stays T0→T2 (downstream of M0/M1) but the *source risk is now resolved*.

### 4. S-PANEL UPLINK (write) controls — the steering half of the Model Cockpit (design)
Builds on PASS-4's downlink (`signal_bus.rs` SPSC ring → `InterruptScoreRow`). Uplink = a **single-writer
command channel** the cockpit writes and the decode/runtime loop reads at safe token boundaries. Shared
safety contract for EVERY control: (i) **no-hidden-authority** — the control only EXPRESSES owner intent;
the app's RuntimeRouter/SovereignGate still adjudicates (per the Codex axiom §1); (ii) **lease-gated** —
heavy/irreversible changes flow through `ComputeResumeLease` (grant/revoke), never a raw mutation;
(iii) **rollback** — each command snapshots prior state + emits a RunEventLog event (reversible);
(iv) **applied at next safe token boundary** (O(ns) atomic read, never mid-token); (v) **gated-visible**
with an orange witness chip until its Rust seam is live (flag-OFF≠done).

| Control | Writes | Rust/UAS seam | Safety bound | Smallest falsifier |
|---|---|---|---|---|
| **Interrupt threshold τ** | one f32 (0..1) | atomic `tau` cell read by the interrupt gate in `research/interrupt_calibration.rs` | clamped to calibrated range; AUROC≥0.85 calibration still owns the *score*, owner only moves the *threshold* | `F-Tau-Apply`: set τ → next-token gate uses new τ at the boundary; RunEventLog records old→new; out-of-range rejected |
| **Route / lane selection** | enum (lane id) | `RuntimeRouter` route request (NOT a direct route mutation) | router adjudicates; honest "no local → nil"; model cannot self-select (Codex axiom) | `F-Route-NoHiddenAuthority`: owner picks lane X → router either honors or emits a visible "denied/why" AnswerPacket; never a silent reroute |
| **Residency / cold-assembly budget** | byte budget (MB) | `helios` ColdStream / `ColdAssemblyPlan` budget field | bounded to physical UMA headroom (16 GB box); over-budget → abstain/spill, never OOM | `F-Residency-Budget`: set budget B → resident bytes ≤ B across a decode trace; breach triggers ColdPanicFallback, logged |
| **Ternary / quant lane toggle** | enum (fp16 / int4 / ternary) | quant-lane selector; Koopman/Bauer-Fike bound (PASS-3 §3) gates safety | ternary allowed only if the Bauer-Fike eigenvalue-shift bound (M1) holds for the model; else greyed-out with reason | `F-Quant-Lane-Safe`: ternary toggle enabled ⇔ `InterruptInvariant`/Bauer-Fike check passes; otherwise control is inert + explains why |
| **Fast-weight quarantine TTL** | duration (s) | fast-weight quarantine (ShmPool TTL / `evict_stale`) — LaCT ≥40% state caveat (PASS-1) | fast weights are quarantined research state; TTL bounds residency; revocation evicts | `F-FastWeight-TTL`: a fast-weight blob past TTL is evicted (copy-count/byte accounting); never promoted to durable truth |
| **Abstention policy** | enum (eager / balanced / never-wrong) | `LatticeAbstentionGate` policy + Belnap `Neither→defer` (PASS-3) | "defer beats wrong"; never-wrong = max abstention; policy is owner-set, model proposes | `F-Abstain-Policy`: under "never-wrong", a `Neither`/low-confidence token defers instead of guessing on the refusal/privacy task family |

**Bidirectional loop closed:** downlink (InterruptScore sparkline + AnswerPacket feed + RunEventLog tail,
PASS-4) + uplink (the 6 controls above) = the full **Model Cockpit**. Flag `EPISTEMOS_SIGNAL_BUS_V0`
covers both halves; the uplink command channel is a second SPSC ring (cockpit→runtime) mirroring the
downlink ring (runtime→cockpit). Tier: T0/T1 write-plan (no live decode loop in product yet).

### 5. Robustness dimensions (PASS-5 depth: D1-COMMS + D3-QUALITY via the controls)
- **D1-COMMS:** uplink is single-writer (cockpit) → runtime reads at boundary via atomic load (no lock,
  no mid-token apply); every command is reversible (RunEventLog snapshot) + lease-gated for heavy changes;
  the Codex axiom ("app owns route selection, model never silently chooses its hidden brain") is the
  formal authority rule — no command lets the model self-promote.
- **D3-QUALITY:** the abstention-policy + τ controls are the owner-facing knobs for "defer beats wrong";
  E2 sheaf-gluing (§2) gives evidence-consistency abstention (conflicting local sections → no fabricated
  global claim); these are measured on the refusal/privacy + research-citation task families.

### 6. Next pass should focus on X
**PASS 6:** (research) mine the **2026-06-02 Codex cluster** (next date-slice) for decisions; surface NEW
only. (S-PRIM) read `e2_sheaf_gluing.rs` to confirm the role + evaluate the remaining queued primitives
(Tropical done, E2 done; next: `info_ir`/`operator_ir`/`scan_ir` IR-stack + `acs/kuramoto` phase-sync).
(verify) confirm the **ReLU²/PowerInfer/DejaVu/LLM-in-a-flash** sources behind blueprint items (b)/(d)/(e)/(f)
(only Engram + SpQt verified so far). (design — KEY) draft the **first end-to-end M0 falsifier spec
`falsify_interrupt_moves_loss`**: tiny CPU-canonical model, interrupt as the ONLY new variable, measurable
loss/quality delta vs no-interrupt baseline — the gate that unblocks the whole build order. Rotate D-depth
→ **D2-PERF** (M0 must be CPU-canonical + cheap). New keyword set.

### PASS 5 summary
Preservation honored (both ledgers intact; Q20 appended verbatim; writes read-back-verified). Line-level
mined the dense June-1 Codex file and extracted 3 concrete DECISIONS now in canon: the no-hidden-authority
axiom ("the app owns route selection; the model does not silently choose its own hidden brain"), the
cold-assembly thesis ("model size doesn't matter — tied to SSD + unified address space"), and the owner's
own "not an EML-only system" statement (justifies S-PRIM). Located E2 + H14 in the theorem canon: **E2
(Ultrametric-Sheaf Gluing) promoted** to a real implemented primitive with an evidence-consistency/
abstention role + falsifier; **H14 (Apollonian) honestly kept as an advisory fence** (its local-global
conjecture is proven FALSE) — not forced in. Verified + corrected PASS-4 integrations: **Engram is real
(arXiv:2601.07372)** but the "MoLKV / hidden-state-as-KV-query" framing and the "1/100000 ratio" were
Gemini conflations → corrected/retracted, while the 20–25% allocation is now primary-source-validated;
**SpQt is real (arXiv:2511.04477), Apple-Silicon/Metal/llama.cpp-native, 1.55× decode speedup** → name
confirmed (distinct from SpQR), upgraded as the highest-portability S-HW item. Designed the full S-PANEL
**uplink** (6 controls: τ, route/lane, residency budget, ternary lane, fast-weight TTL, abstention policy)
each with write-target, Rust/UAS seam, safety bound (no-hidden-authority + lease-gated + rollback +
boundary-apply), and falsifier — closing the bidirectional Model Cockpit with PASS-4's downlink. All
T0/T1 write-plan; no authority docs edited.

---

## PASS 6 — 2026-06-20 (June-2 Codex slice; activation-sparsity stack verified; M0 falsifier SPEC drafted, docs-only)

**Preservation check (pass start):** ✅ both ledgers intact. Q21 appended verbatim to the intent log
(read-back confirmed). Writes below double-checked at pass end. **No code / no .rs files this pass**
(owner `docs_first`; M0/M1 crafting deferred) — §3 is a SPEC/write-plan only.

### 1. June-2 Codex slice — honest negative result
`~/.codex/sessions/2026/06/02/` (10 files). Densest file (`…15-27-02…`, 72k topic hits) is a long
**build/CI/Xcode session** (dominated by `TOOLCHAIN_VERSION`, `TREAT_MISSING_BASELINES_AS_TEST_FAILURES`,
base64 blobs) — not architecture. The smaller files (`…03-02-21…` etc.) are the agent **reading
CLAUDE.md/AGENTS.md** (rule/system-prompt material), not new decisions. **Honest outcome: the June-2
cluster surfaced NO new architecture decisions** — it is build + rule-reading work. Recording this so the
loop doesn't re-mine it. Redirect: PASS 7 → the **2026-06-09** slice (flagged dense in PASS 3's reachability
scan) and/or `2026/05/24` + `2026/05/06` (the most-recent-activity rollouts).

### 2. Activation-sparsity source stack — VERIFIED (with one decisive nuance)

| Source | Verified claim | Map to ledger item |
|---|---|---|
| **DejaVu** (Liu et al. 2023, ICML; OpenReview wIPIhHd00i) | Contextual sparsity is real + predictable on the fly: up to **80% attention-head + 95% MLP-neuron** sparsity (OPT-175B ≈85% total); predictor accuracy high; **2× e2e vs FasterTransformer, ~6× vs HF**; accuracy holds to ~75% sparsity | **(e) pre-attention prefetch** — DejaVu IS the canonical predict-then-skip; validates the predictor-recall bar |
| **PowerInfer** (arXiv:2312.12456) | **ReLU-family FFNs >90% sparse** → up to **11× speedup** on one consumer GPU via online predictors + hot/cold neuron split. **SwiGLU models only ~43–53%** (LLaMA2-13B 43%, Yi-34B 53%) | **(b) ReLU² spine** + **(e) prefetch** (hot/cold neuron residency) |
| **PowerInfer-2** (arXiv:2406.06282) | Smartphone; **neuron-cluster pipeline overlaps I/O with compute** (the bundling+pipeline that hides flash latency); FFN ≈80% of params | **(f) row-column bundling** + **(d) sliding-window** (I/O-compute overlap) |
| **Apple "LLM in a flash"** (Alizadeh et al. 2023) | Selective load of sparse params **flash→DRAM**; windowing + row-column bundling cut I/O | **(d) sliding-window FFN cache** + **(f) bundling** — confirmed primary source |
| **TurboSparse / dReLU** (arXiv:2406.05955) | **dReLU** (ReLU on gate AND up-proj) pushes sparsity to **~90%** with maintained quality, **2–5× speedup** | the ReLUfication recipe behind **(b)** |

**DECISIVE NUANCE (honesty correction / sharpening of PASS-4 item (b)):** the ">90% activation sparsity"
is REAL **only for ReLU-family or ReLU-fied models** — modern off-the-shelf SwiGLU models (LLaMA/Qwen/
Mistral) are only **~43–53%** sparse. Getting to >90% requires **ReLUfication / continued pre-training**
(TurboSparse, ProSparse, PowerInfer-2), which costs **hundreds of billions of tokens** — NOT feasible on
the owner's 16 GB M2 Pro single box (confirms PASS-2 S-HW training-honesty: needs distillation/adapters,
not on-box full retrain). The training-free alternative is **TEAL** (magnitude-threshold sparsity, used by
SpQt) — but TEAL can only *identify* active weights AFTER the activation is computed, so it can't drive
*predictive* prefetch ((e)) the way a trained predictor can. **Consequence for the build order:** items
(d)/(f) (I/O policy) are realizable on existing models NOW (TEAL-style or trace-driven); items (b)/(e)
(predictive sparsity) need either a ReLU-fied model or a trained predictor head — keep them T0 behind M0.
No claim retracted; the ">90%" is conditioned on ReLU-family, and that condition is now explicit.

### 3. M0 FALSIFIER SPEC — `falsify_interrupt_moves_loss` (write-plan; NOT built)

> **The gate that unblocks the whole build order.** Per `MASTER_SYNTHESIS` + intent-log Q1/Q10b: before
> ANY heavy kernel / ternary / cold lane, prove the interrupt — *the one new variable* — actually moves
> the loss at toy scale. CPU-canonical, tiny model. **Owner deferred crafting (`docs_first`); this is the
> build-ready spec to implement the moment crafting is green-lit.** Mirrors the artifact shape of
> `agent_core/src/bin/falsify_70b_local_cocktail_lite.rs`.

**Falsifier identity (proposed):**
- `FALSIFIER_ID = "F-Interrupt-Moves-Loss"` · `FIXTURE_ID = "interrupt_moves_loss_toy_v1"` ·
  `COMMAND = "Tools/falsifiers/f_interrupt_moves_loss.sh"` · placement
  `agent_core/src/bin/falsify_interrupt_moves_loss.rs` (feature-gated `research`, CPU-only, no Metal, no
  MLX, no model download).

**Setup (toy, CPU-canonical, deterministic seed):**
- **Backbone:** a tiny SSM (linear selective-scan, ~2 layers, d_model 64–128) — reuse the math substrate
  in `research/mamba3.rs` / `koopman.rs`; pure-Rust f64 reference, no kernel.
- **Interrupt gate:** the per-token classifier from `research/interrupt_calibration.rs` emitting
  `interrupt_score`; threshold τ via Youden-J; when score>τ the toy switches the next K tokens to an
  **exact full-attention** block (the "expensive" path).
- **The ONE new variable:** the interrupt gate. Everything else is held identical across arms.

**Three arms (held identical except the gate):**
1. **always-SSM** (baseline floor — never interrupts; cheap).
2. **always-attention** (baseline ceiling — full attention every token; expensive; the quality upper bound).
3. **interrupt-gated** (SSM default + full-attention only when score>τ) — the candidate.

**Synthetic "interrupt-needed" task:** a sequence task with deterministic spans that REQUIRE long-range
exact recall (e.g. copy/lookup/associative-recall at marked positions) interleaved with spans the linear
SSM handles fine. Ground-truth `interrupt_needed` label per token (the marked positions). 30-task corpus
shape reused from the F-Interrupt-Calibration doctrine (`INTERRUPT_DOCTRINE_AUROC_BAR = 0.85`).

**Measurements (held-out split; `Measurement` entries in the artifact):**
- `loss_always_ssm`, `loss_always_attention`, `loss_interrupt_gated` (held-out NLL).
- `loss_delta_vs_ssm = loss_always_ssm − loss_interrupt_gated` (must be **> 0** = interrupt helps).
- `loss_recovery_fraction = (loss_always_ssm − loss_interrupt_gated) / (loss_always_ssm − loss_always_attention)`
  (how much of the SSM→attention quality gap the gate recovers).
- `interrupt_auroc` (gate score vs ground-truth `interrupt_needed`, reuse `interrupt_calibration::auc_roc`).
- `attention_fire_rate` (fraction of tokens that triggered attention — the *cost*).
- **Ablation:** `loss_random_gate` — same fire-rate but RANDOM firing positions; the gate must beat random
  (`loss_interrupt_gated < loss_random_gate`) or it isn't *locating* interrupts, just spending compute.

**Pass/fail thresholds (axes → `overall_pass`):**
- `axis_moves_loss`: `loss_delta_vs_ssm > ε` (ε = small fixed margin, e.g. 2% relative) — **interrupt moves the loss**.
- `axis_beats_random`: `loss_interrupt_gated < loss_random_gate` at equal fire-rate — **locates, not spends**.
- `axis_calibrated`: `interrupt_auroc ≥ 0.85` — gate fires at the RIGHT tokens (doctrine bar).
- `axis_efficient`: `loss_recovery_fraction ≥ R` (e.g. 0.5) at `attention_fire_rate ≤ F` (e.g. 0.25) —
  recovers ≥half the quality gap while interrupting ≤quarter of tokens.
- `overall_pass = all four`. Fail on any → exit 1, artifact names the failing axis (failure-report harness,
  like the cocktail-lite preflight).

**result.json schema (mirror `falsifier_artifacts`):** `{ falsifier_id, fixture_id, command, created_utc
(now_utc_rfc3339), kind: ArtifactKind::…, overall_pass: bool, axes: { axis_moves_loss, axis_beats_random,
axis_calibrated, axis_efficient } (named booleans, checked via all_axes_true), measurements: [ {name,
value, unit, threshold: AcceptanceThreshold} … ], fallback_tier: FallbackTier::…, notes }`. Output path
`artifacts/falsifiers/interrupt_moves_loss/result.json`.

**Honesty bounds:** toy-scale only — a PASS proves the mechanism is worth carrying to M1/B-phases, NOT that
it works at model scale, NOT a route/default/quality claim. CPU-canonical + deterministic seed so it's
reproducible and cheap (D2-PERF: M0 must run in seconds, no GPU). This spec is **T0 write-plan**; building
it requires owner green-light to lift the `docs_first` hold.

### 4. Robustness dimensions (PASS-6 depth: D3-QUALITY + D2-PERF via M0)
- **D3-QUALITY:** M0 is the first *measurable* quality test of the whole thesis — `loss_recovery_fraction`
  + the `beats_random` ablation directly measure "the interrupt fires at the right tokens and improves the
  answer," the AUROC≥0.85 bar ties to interrupt placement, and the design refuses to credit compute spent
  in the wrong places. No overclaim: toy-scale, held-out, deterministic.
- **D2-PERF:** M0 is CPU-canonical and must complete in seconds (no Metal/MLX/download) — the cheapest
  possible gate, consistent with "prove the variable before paying for kernels."

### 5. Next pass should focus on X
**PASS 7:** (design — KEY) draft the **M1 Lean spec** — `InterruptInvariant` + the **Bauer-Fike** bound
(quantizing the SSM A-matrix shifts Koopman eigenvalues by ≤ κ(V)·‖ΔA‖); locate the open `sorry` (PCF_8/
H11 per the eval) and write the proof-obligation spec (docs-only, no Lean code) so ternary/quant lanes are
formally unblocked. (research) mine the **2026-06-09** Codex slice for decisions. (verify) confirm
**ReLU²/Primer "Squared ReLU"** (So et al.) + check Q-Sparse/ProSparse. (S-PRIM) evaluate `acs/kuramoto`
(phase-sync) + the `info_ir/operator_ir/scan_ir` IR stack. Rotate D-depth → **D1-COMMS** (the SPSC
ordering proof, outstanding from PASS 3/4). New keywords.

### PASS 6 summary
Preservation honored (both ledgers intact; Q21 verbatim; writes read-back-verified; no code written per
`docs_first`). Mined the June-2 Codex cluster — honest negative result: it's build/CI + rule-reading, NO
new architecture decisions (recorded so it isn't re-mined; redirected next pass to 06-09). Verified the
activation-sparsity stack against primary sources (DejaVu 80%/95%, PowerInfer >90% ReLU + 11×, PowerInfer-2
neuron-cluster I/O pipeline, Apple LLM-in-a-flash, TurboSparse dReLU 90%) and mapped each to blueprint items
(b)/(d)/(e)/(f), with the decisive nuance that >90% holds ONLY for ReLU-family — SwiGLU is ~43–53% and
ReLUfication costs 100s of B tokens (so (d)/(f) are buildable now, (b)/(e) stay behind M0). Drafted the full
**M0 falsifier SPEC** `F-Interrupt-Moves-Loss` (toy SSM + interrupt gate; 3 arms always-SSM/always-attention/
gated; synthetic interrupt-needed task; 4 pass/fail axes incl. a beats-random ablation + AUROC≥0.85; and a
result.json schema mirroring `falsify_70b_local_cocktail_lite.rs`) — build-ready the moment crafting is
green-lit. All T0/T1 write-plan; no authority docs edited; no code created.

---

## PASS 7 — 2026-06-20 (M1 Lean SPEC, docs-only; June-9 Codex slice; Kuramoto + IR-stack primitives)

**Preservation check (pass start):** ✅ both ledgers intact. Q22 appended verbatim to the intent log
(read-back confirmed). Writes double-checked at pass end. **No Lean code / no `sorry` discharged this
pass** (owner `docs_first`) — §1 is a SPEC/write-plan only.

### 1. M1 LEAN SPEC — the two proof obligations that unblock the ternary/quant lane (write-plan; NOT built)

Grounding facts found this pass: the in-repo Lean project is `lean/Epistemos/` (48 `.lean` files, Lakefile,
namespaces `Epistemos.<ID>`); the established pattern is `theorem … : True := by sorry` placeholders
(H1–H17, E1–E7, PCF_1–10). The Bauer-Fike sibling already has scaffolding in **`H4.lean`**
(`structure BabaiBound { ldl_trace }`, `weightDeltaUpperBound = 0.25·ldl_trace`, theorems
`babaiRoundTripBounded` + `layerWiseErrorBoundTight` = `sorry`; cites Chen et al. arXiv:2507.18553 v3,
GPTQ ≡ Babai nearest-plane, ‖Δw‖ ≤ ¼·trace(diag(LDL(H))), sorry-budget ≤4). The **InterruptInvariant** is
ALREADY a coded Rust predicate — `scope_rex/answer_packet.rs::attention_mode_claims_are_consistent()`
(StaticFallback ⟺ ∃ active `ClaimKind::StaticFallbackAcknowledged`; Dynamic/Unavailable ⟹ ¬∃). M1 lifts
these to sorry-free Lean.

**(a) `InterruptInvariant` — the emission-consistency theorem**
- *New file:* `lean/Epistemos/Epistemos/InterruptInvariant.lean`, `namespace Epistemos.InterruptInvariant`.
- *Model (mirror the Rust):* `inductive AttentionMode | dynamic | staticFallback | unavailable`;
  `structure AnswerPacket where (mode : AttentionMode) (hasStaticAck : Bool)` (abstract the claim list to
  the single decidable fact "carries an active StaticFallbackAcknowledged claim"); `def consistent (p) :
  Prop := match p.mode with | staticFallback => p.hasStaticAck = true | dynamic | unavailable =>
  p.hasStaticAck = false`.
- *Precise theorem to write (replaces `: True`):*
  `theorem interrupt_invariant (p : AnswerPacket) (h : WellFormedEmission p) : consistent p`
  where `WellFormedEmission` encodes the only sanctioned constructor (the emit path sets `hasStaticAck`
  exactly when `mode = staticFallback`). The stronger constructor-level form:
  `theorem emit_preserves_consistency (mode) : consistent (emit mode)` — `emit` attaches the ack iff
  `staticFallback`.
- *Proof strategy:* finite enumeration — `cases mode <;> simp [consistent, emit]` (decidable, **no sorry
  needed**; it's a structural tautology once `emit` is the only constructor). The real work is *modeling*
  the emission path faithfully, not the proof.
- *Lean↔Rust parity:* `consistent` must be definitionally equal to the Rust match in
  `attention_mode_claims_are_consistent`; a Rust property test asserts every emitted `AnswerPacket`
  satisfies it (the runtime half of the same invariant).

**(b) Bauer-Fike WBO-6 — the ternary-quant eigenvalue bound**
- *File target:* extend **`H4.lean`** (the LatticeCoder/Babai quant home) with the Koopman sibling, or a
  new `Koopman.lean`; `namespace Epistemos.H4` (keep co-located with the weight-quant bound).
- *Precise theorem to write:* for a diagonalizable SSM transition `A = V Λ V⁻¹` and quantized `Â = A + ΔA`,
  every eigenvalue `λ̂ ∈ spec(Â)` satisfies
  `∃ λ ∈ spec(A), |λ̂ − λ| ≤ κ(V) · ‖ΔA‖`  with `κ(V) = ‖V‖·‖V⁻¹‖` (condition number).
  Statement form: `theorem bauer_fike_eig_shift (A Â : Matrix n n ℂ) (hdiag : Diagonalizable A)
  (hpert : Â = A + ΔA) (λ̂ : ℂ) (hλ̂ : λ̂ ∈ spec Â) : ∃ λ ∈ spec A, ‖λ̂ − λ‖ ≤ condNumber V * ‖ΔA‖`.
- *Proof strategy:* classical Bauer-Fike (1960). If `λ̂ ∉ spec A`, `(Λ − λ̂ I)` is invertible; from
  `(A+ΔA)x = λ̂x` derive `1 ≤ ‖(Λ−λ̂I)⁻¹‖ · κ(V) · ‖ΔA‖`, and `‖(Λ−λ̂I)⁻¹‖ = 1/min_λ|λ−λ̂|` (diagonal).
  Two honest routes: (i) **port from mathlib** if a spectral-perturbation / `Matrix.IsDiag` operator-norm
  lemma exists (preferred); (ii) prove the **finite-dim diagonalizable case** directly using
  `Matrix.opNorm` + `spectrum`. Full generality is nontrivial in Lean (operator norm + eigendecomp);
  **sorry-budget ≤4** (matches H4's lock). Connects WBO-6 → the **ternary lane safety** (PASS-3 Koopman
  primitive): ternary toggle (S-PANEL §PASS-5) is enabled only if this bound holds for the model's A.
- *WBO numbering note:* `H1.lean` already holds `wbo7HoldsOperational`; WBO-6 is the eigenvalue-shift
  bound and belongs with the Babai/LatticeCoder family (H4) — verify the exact WBO index against
  `HELIOS_V5_DOC_6_THEOREM_CANON.md` before writing (don't collide with H1's WBO-7).

**`epistemos_doctrine_lint` binding (CI gate):** extend `agent_core/src/bin/epistemos_doctrine_lint.rs`
to assert: (i) `InterruptInvariant.lean` + the Bauer-Fike theorem are **sorry-free** (grep `:= by sorry`
absent for these named theorems) — fail CI if a placeholder remains; (ii) Lean↔Rust parity — the Rust
`attention_mode_claims_are_consistent` has a property test; (iii) the ternary/quant lane code references
the WBO-6 bound constant before enabling ternary. This makes M1 a *gated, witnessed* milestone, not a
silent doc. **All T0 write-plan** — building requires owner green-light to lift `docs_first`.

### 2. June-9 Codex slice — honest near-negative result
`~/.codex/sessions/2026/06/09/` has **1 file** (`…05-15-14…`). Its architecture content is the **Gemma
build-order canon** verbatim ("…model-family exploration. Preserve 70B-class/custom cold assembly for the
point where Gemma-class models become too large…") — i.e. the agent reading the CLAUDE.md/AGENTS.md Gemma
canon, NOT a new decision. **Honest outcome: no NEW architecture decision surfaced** (corroborates the
already-canon cold-assembly-for-70B build-order point). Redirect: PASS 8 → `2026/05/24` + `2026/05/06`
(the most-recent-activity rollouts from the PASS-3 scan), which predate the Gemma-canon-reading sessions
and may hold the original split/interrupt deliberations.

### 3. S-PRIM — Kuramoto + IR-stack evaluated

| Primitive | What it is | Lives in | Earns a role on | Honest tier | Smallest falsifier |
|---|---|---|---|---|---|
| **Kuramoto sync** | N phase oscillators, mean-field coupling; **order parameter `r∈[0,1]`** (0=incoherent, 1=synced); critical coupling `K_c=2/(π·g(0))` (Kuramoto 1975; Dörfler-Bullo 2014) | `research/acs/kuramoto.rs` (CPU substrate: state + Euler step + order parameter) | **app-side deliberation (candidate)** — `r` as a **consensus/coherence metric** over a claim-graph cluster or expert ensemble: low `r` (incoherent evidence) → ABSTAIN; high `r` → confident emit | **T1** (substrate built: forward-Euler + order param; role is **speculative**) | `F-Kuramoto-Consensus`: on the seven task families, `r` over the evidence/claim set correlates with answer correctness AND low-`r` abstention beats forcing an answer; **if `r` doesn't separate correct-from-wrong, it earns NO role** (honest — don't force it) |
| **scan_ir** | the **selective-scan IR** (SSM recurrence as a typed, lowerable IR with a certificate) | `research/scan_ir/{mod,lowering,evaluator,certificate,grammar}.rs` (+ Lean `Scan.lean`) | **model-internal** — the IR the M0 toy SSM + a future `SelectiveScan.metal` kernel (blueprint B3) compile FROM; certificate = bit-exactness witness | **T1** (IR + evaluator + Lean sample built) | `F-ScanIR-BitExact`: lowered scan_ir matches the f64 reference scan within ULP (the B3 kernel's correctness gate) — directly reusable by the M0 spec's SSM backbone |
| **info_ir / operator_ir** | typed IR + evaluator for information-theoretic / operator (Fourier-kernel) expressions, each with a certificate/oracle | `research/info_ir/*`, `research/operator_ir/*` | **app-side verification substrate** (evaluator + certificate), not a model layer | **T1** (built) | shares the IR-certificate pattern; earns a role only as the verification IR behind operator/info claims — no standalone model role asserted (honest) |

**Honest stance:** **scan_ir** clearly earns a model-internal role (it IS the SSM-scan IR the M0/B3 work
compiles from — a real cross-link). **Kuramoto** is a genuine substrate but its deliberation role is
*speculative* — recorded as a candidate with a falsifier that will KILL it if `r` doesn't predict
correctness; no forced inclusion. **info_ir/operator_ir** are verification IRs (certificate substrate),
not model spine — noted without overclaiming.

### 4. Robustness dimensions (PASS-7 depth: D3-QUALITY via M1 + Kuramoto)
- **D3-QUALITY:** M1(a) InterruptInvariant guarantees **honesty of the emission** — a static-fallback
  answer CANNOT be emitted without the acknowledgement claim (no silent degradation); M1(b) Bauer-Fike
  guarantees **ternary doesn't corrupt the SSM spectrum** beyond a provable bound (quality floor under
  quant). Kuramoto-`r` (if it survives its falsifier) is another abstention signal ("defer beats wrong").
- **D1-COMMS:** the InterruptInvariant is the formal backing for the S-CONN downlink — every AnswerPacket
  on the bus is provably mode-tagged and fallback-honest.

### 5. Next pass should focus on X
**PASS 8:** (research) mine `2026/05/24` + `2026/05/06` Codex rollouts (pre-Gemma-canon; likely original
split/interrupt deliberations). (design — KEY) **S-APP-FAST: the W-51 shadow-recall unification design** —
detail the `epistemos-shadow`-backed `VaultBackend` adapter (from PASS-2 D-IMPL) as a full write-plan:
trait surface, single-shadow-handle sharing, the Rust→Rust borrowed-`&str` path, `EPISTEMOS_SHADOW_RECALL_V1`
flag, `falsify_shadow_recall_parity`. (S-PRIM) evaluate the remaining queued: `belnap` cross-check (done
PASS-3), `continual_learning` (Titans/SEAL/EWC — fast-weights), `active_assembly`. Rotate D-depth →
**D1-COMMS** (the long-outstanding SPSC ordering/race proof). New keywords.

### PASS 7 summary
Preservation honored (both ledgers intact; Q22 verbatim; writes read-back-verified; no Lean code written
per `docs_first`). Drafted the full **M1 Lean SPEC**: (a) `InterruptInvariant` — found it's already a coded
Rust predicate (`attention_mode_claims_are_consistent`: StaticFallback ⟺ acknowledgement claim), specified
the new `InterruptInvariant.lean` (inductive AttentionMode + `consistent` predicate + `emit_preserves_
consistency`, provable sorry-free by case enumeration); (b) Bauer-Fike WBO-6 — found the scaffold in
`H4.lean` (Babai/LatticeCoder bound), specified the eigenvalue-shift theorem `|λ̂−λ| ≤ κ(V)·‖ΔA‖` with the
classical proof strategy (mathlib port or finite-dim diagonalizable case, sorry-budget ≤4) tying ternary-
lane safety to the Koopman primitive; plus the `epistemos_doctrine_lint` CI binding (sorry-free assertion
+ Lean↔Rust parity + ternary-references-WBO-6). Mined the June-9 Codex slice — honest near-negative
(1 file, echoes the Gemma build-order canon, no new decision; redirected to 05-24/05-06). Evaluated S-PRIM:
**scan_ir** promoted (model-internal SSM-scan IR, bit-exact cross-link to M0/B3); **Kuramoto** recorded as
a *speculative* consensus-`r` abstention candidate with a kill-switch falsifier (no forced inclusion);
**info_ir/operator_ir** noted as verification IRs, not model spine. All T0/T1 write-plan; no authority docs
edited; no code created.

---

## PASS 8 — 2026-06-20 (older Codex rollouts; S-APP-FAST W-51 shadow-recall unification D-IMPL; continual-learning primitive)

**Preservation check (pass start):** ✅ both ledgers intact. Q23 appended verbatim to the intent log
(read-back confirmed). Writes double-checked at pass end. No code written.

### 1. Older Codex rollouts (2026-05-24 + 2026-05-06) — honest result
Each date has **1 rollout file**. `2026-05-24` (`…00-28-50…`) is a **UI/debugging session**: the "split"
references are a *mini-graph AppKit panel layout* split + a main-thread-stall investigation + a Hermes
`HERMES_AGENT_CORE_2_0_DESIGN` decision-doc reference — NOT the model/app two-brain split. `2026-05-06`
(1 file) is similar ops/build content. **Honest outcome: the ORIGINAL model/app "two-brain" split
deliberation did NOT surface in these older Codex rollouts.** Cross-check: the "two-brain" framing was
already located in the **June-1** Codex file (PASS 4) + `META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md`
— so the split canon is **June-1-era**, and the older May rollouts are UI/agent-core ops work.
**Redirect:** the owner said *Claude is where research began*. PASS 9 should try **`~/.claude/history.jsonl`
+ `~/.claude/file-history/`** for the earliest split/interrupt deliberations (Codex date-slices are
yielding ops sessions, not architecture origin). Don't keep grinding Codex ops slices.

### 2. S-APP-FAST — W-51 shadow-recall unification (concrete D-IMPL build-plan; write-plan only)

**The gap (PASS-2, code-verified):** the local model's recall (`vault_recall`/`eidos.query` semantic) hits
a SEPARATE colder index (`VaultStore` tantivy + `InMemorySemanticIndex` cosine) while the sidebar hits the
warm `epistemos-shadow` BM25+HNSW+**RRF k=60** fusion. W-51 (`STATUS.md:71`) = NOT-STARTED.

**Surfaces found this pass (grounding):**
- `EidosRetriever` trait — 9 canonical modes; `Semantic` mode currently = `InMemorySemanticIndex`
  (cosine, fixed-dim, deterministic `(cosine desc, source_id asc)` ordering).
- **Production seam already exists:** `eidos/mod.rs::produce_eidos_context_packet[_json]<R: EidosRetriever>`
  — ANY production retriever routes through this ONE helper; closed-citation contract + byte-equal replay
  preserved. W-51 = implement a new retriever behind this seam (no new wire shape).
- **Key constraint:** Eidos does NOT embed text itself — callers supply a precomputed query vector via
  `EidosQuery::with_vector`; embedding lives upstream (shadow backend / MLX-Swift, same model that embedded
  the corpus). So the shadow-backed semantic index must receive (or trigger) the query embedding.
- `RRF_K_DEFAULT = 60` already matches the sidebar (cross-language drift-pinned to Swift `Phase3Fusion`).

**Build-plan:**
1. **New backend** `agent_core/src/eidos/shadow_semantic.rs` → `pub struct ShadowBackedSemanticIndex`
   implementing `EidosRetriever` (mode = `Semantic`), wrapping a shared `epistemos-shadow` handle. Returns
   `EidosHit`s with the same score-component shape so the closed-citation contract is unchanged. Register
   in the backend table (`STATUS.md` §"Mode→Backend", flips the W-51 row to RUST-LANDED when done).
2. **Shared single shadow handle** — open ONCE at bootstrap (`<vault>/.epcache/shadow`, the SAME handle the
   sidebar uses via `RustShadowFFIClient`); the agent recall path borrows it instead of opening a 2nd
   tantivy `MmapDirectory` in `VaultStore`. Kills the duplicate writer heap (~15 MB) + the 2nd mmap.
3. **FFI seam** — reuse `shadow_handle_search` (plain C-ABI `char*` JSON, `RustShadowFFIClient.swift:30-37`).
   **Honesty on "no JSON round-trip":** the round-trip is removed ONLY if `agent_core` links the
   `epistemos-shadow` Rust crate directly (path-dep) and calls its Rust API to get `Vec<ShadowHit>`
   borrowed `&str`. If it stays C-ABI-only (cdylib boundary, per CLAUDE.md), the win is **index
   unification, NOT JSON elimination** — record both options; default to the safe C-ABI path, treat the
   Rust path-dep as a follow-up optimization. (Do not overclaim zero-copy.)
4. **Route the model recall** — `tools/knowledge.rs:222,268` (`vault_recall`) + `tools/vault_search_ladder.rs`
   Tier-2/3 + `eidos.query` semantic → the new backend when the flag is on; **cloud models keep the JSON
   tool interface unchanged** (only the local BACKEND swaps). Provenance (`AgentToolProvenanceRecorder`)
   tagged `backend=shadow` vs `backend=in_memory` so the gap is observable (SS-UMA step 1).
5. **Flag + coexistence** — `EPISTEMOS_SHADOW_RECALL_V1` (mirror `EPISTEMOS_RRF_FUSION_V1`); flag-OFF keeps
   `InMemorySemanticIndex` (never-delete canon — `InMemorySemanticIndex` STAYS as the fixture/test backend
   and the flag-OFF fallback). Gated-visible in the cockpit (S-PANEL) with an orange witness chip until
   `falsify_shadow_recall_parity` passes. Migration = pure additive backend swap; no vault/graph/TK2 touch
   (recall reads the DERIVATIVE shadow index only, never source bytes or the editor).
6. **Embedding supply** — the shadow-backed semantic path needs the query vector; route it through the
   same shadow embed path the sidebar uses (or `EidosQuery::with_vector` from the MLX embedder). Note as
   the one real integration risk (embedding-model parity: index + query must use the SAME embedder).

**Smallest falsifier — `falsify_shadow_recall_parity`** (mirrors the falsifier-artifact shape):
- `axis_parity`: same query → top-K `doc_id`s from the model recall adapter **match** the sidebar shadow
  path (sidebar parity — the correctness win).
- `axis_one_handle`: the recall path opens **ZERO additional** tantivy `MmapDirectory` (one-handle
  invariant; mirrors `F-UAS-CopyCount` accounting).
- `axis_provenance`: every recall emits a provenance event carrying `backend=shadow`.
- `axis_contract`: the returned `EidosContextPacket` passes the closed-citation contract (no wire-shape
  regression) + byte-equal replay with a pinned clock.
- **Bench (not a pass/fail axis, a measurement):** p50/p95 model-recall latency before/after → PROVE
  retrieval reaches sidebar-class AND that **generation, not retrieval, is the floor** (no fake speedup).
- *Honest expected outcome:* the win is CORRECTNESS (sidebar-parity grounding) + MEMORY (one index not
  two), NOT a dramatic wall-clock speedup (generation dominates). Tier **T1** behind the flag; W-51 itself
  sits behind the Phase 0→3 gate — build on owner green-light.

### 3. S-PRIM — `continual_learning` ("Never Retrain" fast-weights stack) evaluated

| Primitive | What it is | Lives in | Earns a role on | Honest tier | Smallest falsifier |
|---|---|---|---|---|---|
| **continual_learning** | 7-layer "Never Retrain" stack: **EWC** (Fisher-weighted forgetting protection, arXiv:1612.00796), **OFTv2/QOFT** (orthogonal fine-tuning, arXiv:2506.19847 — 10× faster/3× less GPU), **DSC/DOC** (online-PCA drift tracking, arXiv:2509.23893, ~40% less forgetting), **Titans-MAC** (surprise-gradient inner-loop memory, arXiv:2501.00663), **SEAL-DoRA** (nightly self-edit → per-user DoRA adapter, arXiv:2506.10943), all under a typed `NeverRetrainStack` envelope with a `validate_submission` invariant | `research/continual_learning/{ewc,oftv2,dsc,titans_mac,seal_dora,stack}.rs` | **both** — model-internal: Titans-MAC = the **fast-weights / test-time update** mechanism (cross-links **LaCT** PASS-1 + **Koopman** "Titans=streaming DMD" PASS-3); OFTv2 = the **orthogonal** adaptation lane (cross-links PASS-4 orthogonal source-card / Geometry-IR SO(n)). app-side: EWC/DSC governance + the `NeverRetrainStack` envelope owns the **fast-weight quarantine** (PASS-5 S-PANEL fast-weight TTL control; PASS-1 LaCT ≥40%-state memory caveat) | **T1** (all 5 sub-features + envelope landed) | `F-NeverRetrain-Invariant`: an adaptation submission that degrades a held-out PRIOR task by >X% (catastrophic forgetting) is REJECTED by `validate_submission` (EWC protection); a fast-weight blob past its TTL is evicted, never promoted to durable truth |

**Single-box honesty (S-HW):** these are **adapter / online-update** methods (LoRA/DoRA/OFT + inner-loop
memory) — **feasible on the 16 GB M2 Pro** (unlike full retrain, per PASS-2). This is the concrete answer
to the owner's "fast weights / weights that auto-update every pass" (intent-log Q9): Titans-MAC is the
mechanism, gated behind the fast-weight quarantine + the `NeverRetrain` invariant so it never silently
corrupts base capability. **Honest:** powerful but quarantine-gated; cross-links three prior passes.

### 4. Robustness dimensions (PASS-8 depth: D2-PERF + D3-QUALITY via W-51)
- **D2-PERF:** W-51 saves MEMORY (one tantivy index, ~15 MB writer heap + a 2nd mmap eliminated) — not
  latency (retrieval is already sub-10 ms; generation dominates). The `one_handle` axis enforces the memory
  win; the bench proves the no-fake-speedup honesty.
- **D3-QUALITY:** the parity axis is the quality win — the model finally queries the warm RRF k=60 + HNSW
  fusion (sidebar grounding parity) instead of a colder in-memory cosine index → better citation grounding
  on the research-citation + note-synthesis task families.

### 5. Next pass should focus on X
**PASS 9:** (research) try **`~/.claude/history.jsonl` + `~/.claude/file-history/`** for the ORIGINAL
split/interrupt deliberations (Codex slices are yielding ops sessions; Claude is where research began per
the owner). (design — KEY) **S-CONN failure-mode / edge-case deep-dive (D1-COMMS)** — the long-outstanding
formal pass: enumerate + harden the bidirectional-bus failure modes (backpressure, mid-token abstain,
lease revocation, SPSC ordering/race proof, partial signals, teardown, no-hidden-authority) into a single
hardened-contract spec with a falsifier per mode. (S-PRIM) evaluate `active_assembly` + the `acs` family.
New keyword set.

### PASS 8 summary
Preservation honored (both ledgers intact; Q23 verbatim; writes read-back-verified; no code). Mined the
older 2026-05-24 + 2026-05-06 Codex rollouts — honest result: they're UI/debugging + agent-core ops
sessions (the "split" there is a graph-panel layout, not the model/app split); the original two-brain
deliberation is **June-1-era** (already captured PASS 4), so redirected PASS 9 to Claude's `history.jsonl`
where research began. Designed the **S-APP-FAST W-51 shadow-recall unification** as a concrete D-IMPL
build-plan: a new `ShadowBackedSemanticIndex: EidosRetriever` behind the existing
`produce_eidos_context_packet` seam, a shared single shadow handle (kills the duplicate tantivy index), the
`shadow_handle_search` FFI reuse (with honest "JSON round-trip removed ONLY with a Rust path-dep" caveat),
the `EPISTEMOS_SHADOW_RECALL_V1` flag + coexistence (InMemory stays as fallback/fixture), the
embedding-parity integration risk, and the `falsify_shadow_recall_parity` 4-axis falsifier (parity /
one-handle / provenance / contract) + a no-fake-speedup bench. Advanced S-PRIM: **continual_learning**
promoted — the "Never Retrain" fast-weights stack (EWC/OFTv2/DSC/Titans-MAC/SEAL-DoRA) that answers the
owner's "auto-updating weights" intent, cross-linking LaCT + Koopman + the orthogonal source-card, gated by
the fast-weight quarantine + NeverRetrain invariant, and feasible on the 16 GB box (adapters, not retrain).
All T0/T1 write-plan; no authority docs edited; no code created.

---

## PASS 9 — 2026-06-20 (header: 3-cycle depth + dual-brain spine + reinforced preservation; Claude mining; S-CONN D1-COMMS hardening spec, 3 cycles deep)

**Preservation check (pass start):** ✅ both ledgers intact. Q24 appended verbatim (incl. the 3-cycle-depth
+ dual-brain/Rust directives) to the intent log; read-back confirmed. Header updated with the 3 permanent
items (DEPTH RULE, SPINE FRAMING, reinforced PRESERVATION). Writes double-checked at pass end. No code.

### 1. Claude mining — FOUND a real dual-brain code surface (cycle 1+2; cycle 3 → next pass)
Claude IS reachable: `~/.claude/history.jsonl` (613 lines — mostly build-loop session prompts) + **10 full
transcripts** in `~/.claude/projects/-Users-jojo-Downloads-Epistemos/`. Densest (`c1f30a8e…`, 2026-06-13,
5245 split/interrupt hits) surfaced **actual code**, not just deliberation:
- **`Epistemos/Omega/Inference/DualBrainRouter.swift` EXISTS** (`@MainActor @Observable`), plus
  `HardwareTierManager.swift` + `HybridRouter.swift`. Its split is **Brain 1 (Reasoning, Metal GPU:
  planning/DAG/codegen) + Brain 2 (Device Action, ANE: AX-tree parse, click targeting, screenshot verify)**;
  `isDualBrainActive = deviceAgent.isReady && deviceAgent.isANEDedicated && hardwareTier.supportsDualModel`;
  Brain-2-unavailable falls back to Brain 1; routes by `AgentStep.assignedAgent`.
- **CRITICAL honest distinction:** this implemented "dual-brain" is a **model↔model** split (GPU reasoning
  model + ANE action model) — it is NOT the owner's S-SPLIT **model↔app** split (generation kernel vs app
  authority/deliberation, Rust bus). They are **complementary axes**: DualBrainRouter splits *which model*
  does a task; S-SPLIT splits *model vs app authority*. The loop's S-SPLIT/S-CONN target is the second axis;
  DualBrainRouter is prior art for the first. Do NOT conflate them — but the cockpit (S-PANEL) route/lane
  control can surface BOTH.
- **ANE honesty CORRECTION (PASS-2):** PASS-2 marked "ANE = Research-tier / MAS-forbidden." That's only
  true for *direct low-level ANE-compiler* exploitation. **Core ML/ANE-backed model execution is ALREADY
  used** — `DeviceAgentService.isANEDedicated` + Brain 2 run on ANE today. Correct the S-HW note: ANE is
  reachable via the public Core ML path (Brain 2 uses it); only private ANE interfaces are Research/MAS-forbidden.
- **S-HW surface:** `HardwareTierManager.supportsDualModel` is the bespoke-hardware gate (M2 Pro tier →
  dual-model capable). Real evidence the hardware-tier-aware routing the loop wants already has a home.
- *Cycle status:* Claude mining cycle 1 (reachability+densest) ✓, cycle 2 (the DualBrainRouter finding +
  distinction) ✓; **cycle 3 = line-level read of `c1f30a8e` + `HardwareTierManager.swift` for the original
  model↔app interrupt deliberation** → PASS 10.

### 2. S-CONN FAILURE-MODE / EDGE-CASE DEEP-DIVE (D1-COMMS) — the definitive hardening spec (3 cycles deep)

The bidirectional Model Cockpit bus = downlink (runtime→app: InterruptScore/AnswerPacket, PASS-4) +
uplink (app→runtime: τ/lease/abstain/route, PASS-5), both SPSC rings in shared memory via `signal_bus.rs`.
**Rust is the fast bus (spine framing).** This spec hardens it.

#### CYCLE 1 — enumerate every failure mode
| # | Failure mode | What goes wrong |
|---|---|---|
| F1 | **Backpressure** | app deliberates slower than the model decodes → uplink/downlink ring fills |
| F2 | **Mid-token abstain / wake-heavy** | app issues abstain/lane-change while a token is mid-decode |
| F3 | **Lease revocation** | `ComputeResumeLease` revoked while a heavy lane is resident/in-flight |
| F4 | **Ordering / races** | downlink scores vs uplink commands interleave; reader sees stale/torn state |
| F5 | **Cancellation / teardown** | generation cancelled (user stop, window close) mid-stream |
| F6 | **Partial / truncated signals** | an AnswerPacket or score is half-written when read |
| F7 | **No-hidden-authority breach** | model tries to self-promote a lane / app reroutes silently |
| F8 | **Bus-latency stall** | the bus itself adds latency to the decode loop (the cardinal sin) |
| F9 | **Ring overflow / drop** | downlink scores produced faster than consumed → which to drop? |
| F10 | **Clock/version skew** | uplink command references a τ/route from a stale model-state generation |

#### CYCLE 2 — how the hardened contract handles each (via `signal_bus.rs`)
- **F1 Backpressure:** downlink ring is **`bufferingNewest`-style drop-oldest** (scores are sampled telemetry
  — losing an old score is fine); uplink ring is **single-writer, bounded, never blocks the reader** — if
  full, the cockpit coalesces (latest τ wins). Decode loop NEVER awaits the app.
- **F2 Mid-token abstain:** commands apply **only at the next safe token boundary** (atomic read between
  tokens); the in-flight token completes; the boundary is recorded in RunEventLog. No partial-token discard.
- **F3 Lease revocation:** revoke flips an atomic `lease_state` cell; decode reads it at the boundary and
  **rolls back to the cheap lane deterministically** (ColdPanicFallback if heavy lane was resident); no
  half-woken lane left allocated.
- **F4 Ordering/races:** **SPSC discipline** — exactly one producer + one consumer per ring (downlink:
  runtime→app; uplink: app→runtime). Each entry carries a **monotonic seq + model-state generation id**;
  reader rejects out-of-generation commands (F10). Lock-free, no torn reads (entries are word-aligned /
  seqlock-versioned).
- **F5 Cancellation/teardown:** a `cancel` flag on the uplink ring; decode checks it at the boundary and
  tears down cleanly (flush AnswerPacket with `attention_mode` honest, free KV); the cockpit's
  `dismantleNSView`/feed-detach mirrors the existing WKWebView teardown discipline.
- **F6 Partial signals:** **seqlock / double-buffer** on AnswerPacket writes — reader retries if the version
  counter is odd (write in progress); scores are single-word atomic (never torn).
- **F7 No-hidden-authority:** the Codex axiom (PASS-5) — every route/lane change emits a RunEventLog event +
  AnswerPacket caveat; the model can only REQUEST a lane (downlink), the app's RuntimeRouter/SovereignGate
  ADJUDICATES; uplink commands are owner/app-originated only. No silent reroute path exists in the seam.
- **F8 Bus-latency stall:** **scalars/enums only cross the bus** (no tensors — data plane stays in unified
  memory, PASS-3/5); uplink read = one O(ns) atomic load at the boundary; downlink write = one atomic
  append. Target: bus adds <1% of per-token decode (PASS-3 budget).
- **F9 Ring overflow:** downlink = drop-oldest (telemetry); AnswerPacket ring = bounded, never dropped
  (back to F1: it's once-per-turn, low rate); uplink = coalesce (latest-wins per control).
- **F10 Clock/version skew:** every model-state has a **generation id**; uplink commands tagged with the
  generation they target; a command for a superseded generation is rejected + logged (not silently applied).

#### CYCLE 3 — falsifiers that PROVE each is handled (T1 write-plan; build on green-light)
| Mode | Falsifier | Pass condition |
|---|---|---|
| F1 | `F-Bus-Backpressure` | app deliberately stalls; decode tokens/s unchanged (≤1% delta); no decode-loop await observed |
| F2 | `F-Boundary-Apply` | abstain issued mid-token → applied at next boundary; in-flight token intact; RunEventLog records boundary |
| F3 | `F-Lease-Revoke-Rollback` | revoke mid-heavy-lane → deterministic rollback to cheap lane; zero residual heavy-lane bytes (copy/byte accounting) |
| F4 | `F-SPSC-Ordering` | concurrent producer/consumer fuzz; consumer sees strictly monotonic seq, never a torn/stale entry |
| F5 | `F-Cancel-Teardown` | cancel mid-stream → clean teardown, KV freed, final AnswerPacket has honest `attention_mode` |
| F6 | `F-Partial-Signal-Seqlock` | reader during an in-progress AnswerPacket write retries, never reads a half-written packet |
| F7 | `F-No-Hidden-Authority` | model lane-request without app adjudication is REJECTED + logged; no silent reroute reachable |
| F8 | `F-Signal-Bus-Overhead` (PASS-3) | tokens/s bus-ON vs bus-OFF ≤1%; interrupt-gate p99 ≤1% of per-token time; zero tensor crosses control plane |
| F9 | `F-Ring-Drop-Policy` | overflow drops OLDEST score (telemetry) but NEVER drops an AnswerPacket or a lease command |
| F10 | `F-Generation-Skew` | a command tagged with a superseded model-state generation is rejected, not applied |

**This is the definitive D1-COMMS hardening contract.** All 10 modes → mechanism → falsifier. Tier T1
write-plan; the `signal_bus.rs` seam (PASS-4/5) is where it lands on owner green-light. Spine framing
honored throughout: Rust is the fast bus; the app (brain 2) holds authority; the model (brain 1) signals
but cannot self-promote.

### 3. Robustness dimensions (PASS-9 depth: D1-COMMS exhausted to 3 cycles)
D1-COMMS is now specified end-to-end (enumerate→mechanism→falsifier). D2-PERF anchor: F8 keeps the bus off
the bandwidth budget (<1%). D3-QUALITY anchor: F2/F5/F7 keep emissions honest (no partial-token, honest
attention_mode on teardown, no silent reroute) — quality = honesty of the bus.

### 4. Next pass should focus on X
**PASS 10 (next deep cycles):** (research) **Claude mining cycle 3** — line-level read `c1f30a8e` +
`HardwareTierManager.swift` + `HybridRouter.swift` for the original **model↔app** interrupt deliberation
(distinct from the implemented model↔model DualBrainRouter); also try the other 9 transcripts. (design)
**S-PANEL uplink safety cycle 2/3** — take the 6 uplink controls (PASS-5) through mechanism (cycle 2) +
falsifiers (cycle 3) using this pass's SPSC/lease/boundary primitives. (S-PRIM) evaluate `active_assembly`
+ the `acs` family (3-cycle). Rotate external research → a NEW keyword set (e.g. Mamba-3 selective-scan /
attention-sinks, still un-pulled since PASS-1). Apply the 3-cycle depth rule to each.

### PASS 9 summary
Added the 3 permanent header items (3-cycle DEPTH RULE; DUAL-BRAIN/Rust-bus SPINE FRAMING; reinforced
PRESERVATION) and logged Q24 verbatim (incl. the multi-cycle + dual-brain directives) with read-back.
Claude mining FOUND real code: `DualBrainRouter.swift` (+ HardwareTierManager/HybridRouter) — but honestly
distinguished it as a **model↔model** split (GPU reasoning Brain 1 + ANE device-action Brain 2), DISTINCT
from the owner's **model↔app** S-SPLIT (the loop's target); corrected the PASS-2 ANE note (Core ML/ANE
model execution is already live via Brain 2; only private low-level ANE is forbidden); flagged
`HardwareTierManager.supportsDualModel` as the bespoke S-HW gate. Delivered the **definitive D1-COMMS
hardening spec** at full 3-cycle depth: 10 failure modes (backpressure, mid-token abstain, lease revocation,
ordering/races, cancel/teardown, partial signals, no-hidden-authority, bus-latency stall, ring overflow,
generation skew) → each with a hardened `signal_bus.rs` mechanism (drop-oldest telemetry, boundary-apply,
atomic lease rollback, SPSC+seq+generation-id, seqlock AnswerPacket, scalars-only control plane) → each
with a named falsifier (F-Bus-Backpressure … F-Generation-Skew). All T0/T1 write-plan; no authority docs
edited; no code created.

---

## PASS 10 — 2026-06-20 (Claude genesis cycle 3; S-PANEL uplink hardening cycles 2&3; active_assembly/acs; Mamba-3 + attention-sinks)

**Preservation check (pass start):** ✅ both ledgers intact. Q25 appended verbatim (read-back confirmed).
Writes double-checked at pass end. No code. 3-cycle depth + dual-brain spine framing applied throughout.

### 1. Claude mining CYCLE 3 — genesis found; thread CONCLUDED (honest)
Line-level read of the densest Claude transcript (`c1f30a8e`, 2026-06-13) + cross-file grep. The genesis
of the interrupt thesis is a **DOC, not a Claude chat**:
- **`Epistemos V6_1 — Final Synthesis Lock (Attention as Interrupt).pdf`** (May 6 2026; in `docs/fusion/`
  + iCloud). The five-lanes thesis: *"hybrid-SSM, parameter-connectome, Heavy-Thinking,
  vectorless-retrieval, brain-inspired, App-Store-native — and the floor never moves — and **attention is
  an interrupt**."* This is cited verbatim by `research/interrupt_calibration.rs` (V6.1) and is the origin
  of S-CONN's interrupt mechanism. The obscura/Hermes-era roots feed it.
- **Honest conclusion (3 cycles complete):** cycle 1 = Claude reachable (history + 10 transcripts); cycle 2
  = found `DualBrainRouter.swift` (model↔model split, PASS-9); cycle 3 = the **model↔app/interrupt genesis
  is the V6_1 "Attention as Interrupt" doc (May 2026)**, with the explicit *model↔app* S-SPLIT framing
  crystallizing in the June-1→this-loop era. The Claude transcripts are build/loop sessions that
  *reference* the doc, not the origin. **The Claude mining thread is now CONCLUDED** — the genesis is
  captured (a doc, already in canon + cited by code); further transcript grinding has diminishing returns.
  Future research effort redirects to design + the remaining primitives.

### 2. S-PANEL UPLINK HARDENING — cycles 2 (mechanism) + 3 (falsifier) — definitive spec
Building on PASS-5's 6 controls + PASS-9's SPSC/lease/boundary primitives. **Spine framing:** the cockpit
(app = brain 2) writes the uplink ring; the Rust runtime (model = brain 1) reads at token boundaries; Rust
is the fast bus. Shared invariant (all controls): single-writer uplink ring · O(ns) atomic read at next
safe token boundary · RunEventLog snapshot for rollback · no-hidden-authority (app/owner-originated only;
RuntimeRouter/SovereignGate adjudicates; model can only REQUEST).

| Control | CYCLE 2 — exact safety mechanism | CYCLE 3 — falsifier |
|---|---|---|
| **Interrupt τ** | atomic f32 cell clamped to the calibrated range; gate reads it at the boundary; AUROC-calibration owns the *score*, owner moves only the *threshold*; prior τ snapshotted for rollback | `F-Tau-Apply`: set τ → next-token gate uses it at the boundary; out-of-range clamped+logged; revert restores prior τ byte-equal |
| **Route / lane** | uplink writes a route *request* enum; **RuntimeRouter adjudicates** (never a direct mutation); honest "no local → nil"; emits RunEventLog + AnswerPacket caveat | `F-Route-NoHiddenAuthority`: owner picks lane X → router honors OR emits visible "denied + why"; **no silent reroute reachable**; model-originated request without adjudication rejected |
| **Residency / cold-assembly budget** | byte budget cell clamped to physical UMA headroom (16 GB); ColdStream reads at boundary; over-budget → spill/abstain via `ColdPanicFallback`, never OOM | `F-Residency-Budget`: set budget B → resident bytes ≤ B across a decode trace; breach → ColdPanicFallback fires + logged; revert restores prior budget |
| **Ternary / quant lane** | enum gated by the **Bauer-Fike WBO-6 bound (M1)**: ternary selectable only if `‖λ̂−λ‖ ≤ κ(V)·‖ΔA‖` holds for the model's A; else inert + reason; lease-gated (heavy switch) | `F-Quant-Lane-Safe`: ternary enabled ⇔ M1 bound passes; toggling with bound-failing model is inert + explains; switch flows through `ComputeResumeLease` |
| **Fast-weight quarantine TTL** | duration cell → ShmPool `evict_stale`; fast weights are quarantined research state (LaCT ≥40%-state caveat); revoke evicts; NeverRetrain invariant blocks promotion to base | `F-FastWeight-TTL`: blob past TTL evicted (byte accounting); never promoted to durable truth; revoke mid-life → deterministic eviction |
| **Abstention policy** | enum (eager/balanced/never-wrong) → `LatticeAbstentionGate` + Belnap `Neither→defer`; owner sets policy, model proposes; applied at boundary | `F-Abstain-Policy`: under "never-wrong", a `Neither`/low-confidence token defers (not guesses) on the refusal/privacy family; policy change applied at next boundary, logged |

**Model Cockpit now fully falsifier-covered:** downlink (PASS-9 F1–F10: `F-Bus-Backpressure` …
`F-Generation-Skew`) + uplink (the 6 above: `F-Tau-Apply` … `F-Abstain-Policy`). The bidirectional
contract is specified end-to-end with a falsifier per failure mode AND per control. Tier T1 write-plan;
lands on `signal_bus.rs` + the cockpit SwiftUI surface on owner green-light.

### 3. S-PRIM — active_assembly (AAR) + acs evaluated

| Primitive | What it is | Lives in | Earns a role on | Honest tier | Smallest falsifier |
|---|---|---|---|---|---|
| **active_assembly (AAR)** | the **"NERVOUS SYSTEM — decides which packets / components / model mechanisms FIRE for the current state"**; `Packet`/`PacketGraph` DAG + `MarginAnchoredGreedyPull` selector; two-sided constraint (output ≤4-bit Hamming AND cost-ratio <0.40 AND firing-ratio <0.50) | `research/active_assembly/{mod,packet,selector}.rs` | **app-side (core)** — THE mechanism-firing decider; this IS the layer that selects which model mechanisms/experts/cold-assembly units fire = the **interrupt + cold-assembly selection brain** (brain 2's executive). Cross-links the interrupt gate (what fires when) + ColdAssemblyPlan | **T1** (Packet/PacketGraph + selector + `F-ActiveAssembly-Minimal` landed) | `F-ActiveAssembly-Minimal` (exists): selector achieves output within 4-bit Hamming at cost-ratio <0.40 AND firing-ratio <0.50 — proves it fires the RIGHT minimal mechanism set, not everything |
| **acs (Autopoietic Cognitive Stack)** | recursive self-governance: 6 scales (transistor→cell→tissue→organ→organism→ecosystem), each cell = a SCOPE-Rex instance, cells sync via Kuramoto; sub-features Notch-Delta lateral inhibition, autopoietic-closure (Maturana-Varela), VSM (Stafford Beer), governance envelope | `research/acs/{mod,kuramoto,notch_delta,autopoiesis,vsm,governance}.rs` | **app-side governance META-layer (partial)** — the extractable beneficial pieces: the **recursive residency-governance envelope** (same residency contract at every scale) + the **autopoietic-closure self-consistency validator**; Kuramoto sync evaluated PASS-7 | **T1 substrate, but largely FRAMING** — honest: ACS is an ambitious governance doctrine, NOT a model mechanism. Beneficial as governance structure; do NOT promote as a model-spine organ | `F-ACS-AnchorLookup` (exists): substrate anchor lookups remain grounded in typed ACS/code evidence; the autopoietic-closure check rejects an organizationally-incomplete cell |

**Honest stance:** **active_assembly is a CORE app-side primitive** (the mechanism-firing executive — directly
the brain-2 decider that the interrupt + cold-assembly need; a real cross-link). **acs is mostly governance
FRAMING** — its Kuramoto + closure-validator + recursive-residency-envelope pieces are beneficial, but the
6-scale autopoietic doctrine is not a model organ; recorded honestly without overclaiming.

### 4. External source-cards (Mamba-3 + attention-sinks — both outstanding since PASS-1)
- **Mamba-3** (arXiv **2603.15569**, Tri Dao / Goomba Lab; code `state-spaces/mamba`; Triton/TileLang/CuTe
  kernels). **Inference-first** SSM (vs Mamba-2's train-first). Three innovations: (1) **exponential-
  trapezoidal discretization** (more expressive recurrence); (2) **complex-valued state** (richer state
  tracking); (3) **MIMO** (multi-input/output SSMs in parallel — more power, little decode-latency cost).
  Beats Mamba-2 / Gated DeltaNet / Llama-3.2-1B on prefill+decode latency at 1.5B; **Pareto front: comparable
  performance at HALF the state size**. SSM↔attention duality `C→Q, B→K, X→V`; Mamba-2 = lower-triangular
  1-semiseparable. **MAP (spine):** Mamba-3 is the updated **SSM spine candidate** — the M0 toy SSM + the
  B3 `SelectiveScan.metal` kernel should target Mamba-3's recurrence, not Mamba-2's. **(2) complex-valued
  state directly ties to the Koopman complex-eigenvalue / Bauer-Fike WBO-6 bound (M1)** — quantizing a
  complex-valued A is exactly the eigenvalue-shift the M1 theorem bounds. **MIMO + half-state-size ties to
  D2-PERF** (memory-bound decode on M2 Pro) + the **KV/residency budget** (S-PANEL control): half the state
  = half the residency cost.
- **Attention sinks / StreamingLLM** (Xiao et al., arXiv **2309.17453**): models dump attention onto the
  first ~4 tokens ("sinks" — softmax must sum to 1, so unused attention parks there); keeping the **4 sink
  tokens permanently + a sliding window** → stable 4M+ token generation (now in HF, TensorRT-LLM, OpenAI).
  **MAP (interrupt complement):** attention sinks are the **stability mechanism of the cheap/SSM-default
  lane between interrupts** — sink tokens + sliding window anchor the linear lane; the interrupt fires when
  exact recall is needed BEYOND the sink+window. Already partly canon: `research/attention_sinks.rs`
  (`detect_sinks`, `sink_strength`) + `koopman.rs` PASS-3 ("sink modes = eigenvector tails of the
  attention-Koopman operator", Cancedda arXiv:2402.09221). NEW nuance recorded: the StreamingLLM
  **4-sink + sliding-window** recipe is the concrete SSM-default stability contract; the interrupt is its
  escape hatch.

### 5. Robustness (PASS-10: D1-COMMS uplink completed; D2-PERF + D3-QUALITY via Mamba-3)
- **D1-COMMS:** the Model Cockpit is now end-to-end falsifier-covered (downlink F1–F10 + uplink 6 controls).
- **D2-PERF:** Mamba-3 half-state-size + MIMO = directly lower KV/residency cost on the memory-bound M2 Pro
  (the spine choice has a measurable bandwidth consequence).
- **D3-QUALITY:** Mamba-3 fixes the linear-model state-tracking weakness (the exact failure the interrupt
  was compensating for) — so a Mamba-3 spine may need the interrupt to fire LESS often (measurable on M0's
  `attention_fire_rate`); attention-sinks keep the between-interrupt lane stable.

### 6. Next pass should focus on X
**PASS 11:** (S-PRIM) evaluate the LAST queued primitives — the IR stack (`info_ir`/`operator_ir` already
noted; `eml_ir`/`scan_ir` done), `hybrid_memory`, `substrate_independence`, `belnap` (done) — then declare
the S-PRIM inventory COMPLETE (or name the honest remainder). (design — KEY) **first consolidated
"ARCHITECTURE READOUT" draft** — the single coherent picture: model (brain 1: Mamba-3 SSM spine + interrupt
+ attention sinks + ternary lane) ↔ Rust bus (signal_bus.rs, M0/M1 gates, D1-COMMS hardened) ↔ app (brain 2:
RuntimeRouter authority + active_assembly firing + AnswerPacket + cockpit + W-51 shadow recall), with the
honest tier of each segment (what's T1 spec vs T0 ambition vs already-coded like DualBrainRouter/InstantRecall).
The deep cycles are nearly exhausted — PASS 11 should begin the synthesis. New keyword set if research continues.

### PASS 10 summary
Preservation honored (both ledgers intact; Q25 verbatim; read-back-verified; no code). **Claude mining
CONCLUDED** at cycle 3: the model↔app/interrupt genesis is the **V6_1 "Attention as Interrupt" doc (May 6
2026)** (cited by `interrupt_calibration.rs`), not a Claude chat — the transcripts reference it; thread
closed honestly. Delivered the **definitive S-PANEL uplink hardening spec** (cycles 2+3): each of the 6
controls (τ, route/lane, residency budget, ternary lane, fast-weight TTL, abstention) → exact mechanism
(lease-gated / boundary-apply / atomic rollback / no-hidden-authority via the SPSC uplink ring) → named
falsifier (`F-Tau-Apply` … `F-Abstain-Policy`) — so the **Model Cockpit is now end-to-end falsifier-covered**
(downlink F1–F10 + uplink 6). S-PRIM: **active_assembly promoted as a CORE app-side primitive** (the
mechanism-firing "nervous system" = brain-2's executive for interrupt + cold-assembly); **acs recorded
honestly as mostly governance framing** (Kuramoto + closure-validator beneficial; the 6-scale doctrine is
not a model organ). Pulled the two outstanding source-cards: **Mamba-3** (arXiv:2603.15569 — inference-first
SSM, complex-valued state ↔ Koopman/Bauer-Fike M1, MIMO + half-state-size ↔ D2-PERF/KV budget; the updated
SSM SPINE candidate for M0/B3) and **attention sinks / StreamingLLM** (arXiv:2309.17453 — the 4-sink +
sliding-window stability contract for the SSM-default lane; the interrupt is its escape hatch). All T0/T1
write-plan; no authority docs edited; no code created.
