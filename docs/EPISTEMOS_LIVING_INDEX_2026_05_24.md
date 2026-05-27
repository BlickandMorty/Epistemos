# Epistemos — Living Index (single canonical entry point)

> **You are here.** This is the one document any agent or human reads first to understand the architecture, the current state, the terminals, the deferred work, the codewords, and how to resume. **Do not descend to deeper docs unless you need the specific detail.** Every paragraph below either tells you the answer or names exactly which deeper doc holds it.

**Living-doc rules:**
- Update this file in place — never branch a parallel "v2." There is one living index; the old version is `git log`.
- Update the **Current State** block (§6) on every wave close.
- Updated **2026-05-27** · Wave 4 checkpoint: PRs `#121`-`#127` are on
  `main`, including typed UAS retrieval/claims, PageGather escalation traces,
  Cognitive DAG visualizer, Tri-Fusion typed note mutations, and the System G
  test-isolation/focused-warning fixes. Post-Wave-4 closeouts also retired
  W-49/W-53 ship hardening and Agent Capability Truth. The provenance/residency
  detail slice closes the compact AnswerPacket UAS / ACS anchor / plane /
  residency UI gap. `RESUME ACS ANCHOR HARNESS` is now complete as a full
  N=1000 four-stage witness, and `F-ULP-Oracle` now has a full Metal
  `morphOracleFp16` primary hardware artifact. For the current W-row/falsifier recount and next codeword
  prompts, read
  `docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md`. For the post-stash
  split of finished vs unfinished work, read
  `docs/audits/MAIN_ARCHITECTURE_RECOVERY_STATUS_2026_05_26.md` before
  dispatching another recovery agent.

---

## 1 · What Epistemos is (one paragraph)

Epistemos is a **local cognitive substrate**, not "an app that runs a local model." The local model is the *mouth*; the substrate is everything that decides what part of memory, which runtime, what evidence, what schema, what proof, and what permission path the model is allowed to use before anything becomes an answer or an action. **MLX is one runtime lane**, not the architecture — it can be enabled, disabled, replaced, or paired with GGUF / llama.cpp / cloud / Apple Intelligence. The substrate is the routing, residency, schemas, admission gates, proofs, and visible verification *around* those executors.

## 2 · The architecture in one rule (the Substrate Motion Invariant)

Every meaningful Epistemos object is **one substrate object** carrying:
1. `UasAddress` — stable identity
2. `RuntimePlane` — State · Episodic · Assembly · Controller · Verification
3. `ResidencyTier` — CurrentApp · VerifiedFloor · CapabilityCeiling
4. `LatticeBudget` — WBO error account (if approximate)
5. **Witness** — `RunEventLog` / `AnswerPacket` / `ClaimGraph` / `WboLedgerEntry` / falsifier artifact / Lean proof

Every operation is exactly one of **three motions**:

| Motion | Direction | Meaning | Witness required |
|---|---|---|---|
| **Lift / Ingest** | surface → substrate | put raw material in (note bytes, pixels, prompts, model output, traces) | UAS + source hash + plane |
| **Project / Compress / Recall** | substrate → surface | make object cheaper, smaller, or visible (vault recall, citation, UI row) | ShadowProjection + WBO + citation/proof |
| **Mutate / Promote** | substrate → substrate | change durable state or promote candidate to authority | MutationEnvelope + ACS verdict + rollback |

There is no fourth motion. "Activate a model slice" is a Lift at finer granularity (see §3).

## 3 · LLM-address granularity ladder (what your app calls the LLM as)

10 rows, finest at bottom. Every PR must answer *"which row does this touch?"* Overclaim = reframe.

| Row | What is addressed | Status today | Tier |
|---|---|---|---|
| 1 | Whole-model call | LIVE | T1 |
| 2 | Output schema (grammar, JSONSchema, AnswerPacket) | LIVE partial | T1 |
| 3 | KV cache page (zero-copy across Swift/Rust/MLX/Metal) | substrate shipped, harness pending | T1 gate |
| 4 | Weight-bit layout (Sherry/Leech VQ, ternary, NF4) | research / promotion candidate | T2/3 |
| 5 | Adapter delta (LoRA / DoRA / Titans-MAC / L_SE) | research | T3 |
| 6 | MoE expert | model-internal; substrate observes/chooses lane | T1 when model provides |
| 7 | Active assembly (model + KV + context + adapter + tool + kernel cross-cut) | research target | T3 |
| 8 | Attention head / **SSM state (the language router gate)** | research target | T3 |
| 9 | Parameter anchor (rank-one component address) | research target | T3 |
| 10 | Cross-layer attribution circuit | research target | T3 / Vault |

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

## 6 · CURRENT STATE (2026-05-27 — Wave 4 checkpoint + closeouts)

### Wired and on main
- 40+ pre-2026-05-23 PRs · 18 from the 2026-05-23 sanitization session · 5 from the 2026-05-24 doctrine session · **14 Phase-2 merge-wave PRs (#66-#79, including #73 index refresh and the direct #76 hotfix `77c7efe9ea`)** · **Wave 3/4 substrate PRs #121-#127**.
- Substrate carcass: ~70% baseline per chronicle audit, advanced by real Eidos bridge, System G seam, ACS production gate, T14 UAS bridge, Verified Floor chip gate, Runtime Router, Hyperdynamic Loop, B-prime chat provenance, Round-2 falsifier artifacts, typed UAS retrieval/claims, PageGather escalation traces, Cognitive DAG visualizer, Tri-Fusion typed note mutations, focused test-warning cleanup, W-49/W-53 hardener closeout, Agent Capability Truth closeout, and the compact AnswerPacket provenance/residency detail path. **Post-Wave-4 LEGENDARY estimate: ~42/53 strictly wired, ~49/53 strict+meaningful partial, ~96% substrate floor.** Full recount: `docs/audits/LEGENDARY_POST_WAVE4_ROLLUP_2026_05_27.md`.
- 13+ stash recovery tags pushed to origin (`refs/tags/recovery/stash-N-*`) plus Wave-2 recovery tags for PR #74, PR #79, and the B-prime uncommitted follow-up stash.
- W-rows wired: **about 42/53 strict, about 49/53 strict+partial** after Wave 4 plus W-49/W-53, Agent Capability Truth, and Provenance / Residency Detail closeouts. Known advances: Eidos real bridge/citation gate (#66), System G real seam (#67), falsifier harnesses (#68/#74), Substrate Health/docs/unified panel work (#69/#77), VaultRecall visibility salvage (#70/#79), T14 No-Orphan bridge (#71), ACS production gate (#72), Verified Floor truth gate (#78), Hyperdynamic Schema Loop (#75), Runtime Router (#76), typed UAS retrieval and ClaimLedger addresses (#121), PageGather vault escalation trace (#122), Cognitive DAG visualizer (#123), Tri-Fusion typed note mutations (#124), test-isolation/warning cleanup (#125/#127), W-49/W-53 source guards (`docs/audits/POST_WAVE4_W49_W53_HARDENER_CLOSEOUT_2026_05_27.md`), Agent Capability Truth source guards (`docs/audits/POST_WAVE4_AGENT_CAPABILITY_TRUTH_CLOSEOUT_2026_05_27.md`), and AnswerPacket substrate detail guards (`docs/audits/POST_WAVE4_PROVENANCE_RESIDENCY_DETAIL_2026_05_27.md`).
- Falsifier artifacts on main: **10 artifact files**.
  - Schema-normalized primary witnesses: `F-VaultRecall-50`, `F-ULP-Oracle`, `F-Eidos-Bridge-RoundTrip`, `F-ACS-Anchor-Addressing` (full N=1000 four-stage harness), `F-HyperdynamicLoop-Bounded`.
  - Schema-normalized fallback/CPU witnesses: `F-PageGather-M2Pro`, `F-ControllerKernelPack`, `F-UAS-ZeroCopy-Spine` — PageGather and ControllerKernelPack Metal/Swift hot-path throughput gates still pending. `F-PageGather-M2Pro` and `F-ControllerKernelPack` have a 2026-05-27 Metal preflight dispatch/equivalence guard; `F-ULP-Oracle` has advanced from preflight to a full Metal primary artifact.
  - Legacy-shape measured PASS artifacts still to normalize: `F-UAS-CopyCount`, `F-ACS-AnchorLookup`.

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
- `cargo test --manifest-path agent_core/Cargo.toml --lib --quiet` passed: 4,044 tests after the Metal preflight slice.
- `Tools/metal-shader-compile/metal-shader-compile.sh` passed: 26 shaders compile, with honest deferred warnings for PageGather / ControllerKernelPack / PacketRouter1bit.
- `swift Tools/metal-witness-gates/fulp-metal-oracle-artifact.swift --write-artifact` passed and emitted a primary `F-ULP-Oracle` Metal artifact.
- `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosTriFusionTypedMutationGate build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""` passed for the Wave-4 checkpoint; rerun a fresh build after this artifact slice before tagging.
- Focused graph/editor guard passed after the lost-work restoration: `GraphPerformanceTests`, `GraphPhysicsSettingsAuditTests`, and `HTMLWorkspaceSourceGuardTests` all passed.
- Latest pushed checkpoint before this artifact slice: `checkpoint/post-wave4-metal-witness-preflight-2026-05-27`.

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
| **E** | done | ACS Admission production gate | merged in #72; ACS anchor-addressing D-27 full harness completed by `docs/audits/ACS_ANCHOR_HARNESS_FULL_2026_05_27.md` | 3 |
| **F** | done | ≥ 5 falsifiers PASS on M2 Pro | merged in #68; 7 artifacts now on main after #71; round 2 in F′ | 4 |
| **UAS-Typed** | done | Typed UAS retrieval + ClaimLedger/ACS anchor address fields | merged in #121 | 4 |
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
7. `stash@{17}` Landing Wave / Session Intelligence recovery is closed by `docs/audits/STASH17_LANDING_WAVE_CLOSEOUT_2026_05_26.md`; current `main` keeps the newer fused landing/chat/ambient route.
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

**What still needs measurement, not faith.** F-Erdős-Lift-Optimality · F-KV-Direct-Gate · F-Sparse-Runtime-Split · F-LocalToolUse · F-HyperdynamicLoop-Bounded · F-70B-Local-Cocktail · primary Metal/Swift hot-path versions of F-PageGather-M2Pro, F-ControllerKernelPack, and F-UAS-ZeroCopy-Spine. A Metal witness preflight now exists for PageGather and ControllerKernelPack, while F-ULP has a full Metal primary artifact. PageGather throughput and ControllerKernelPack latency artifacts remain pending. Ten falsifier artifact files now exist on main after Wave 2, but several are fallback witnesses. Substrate is sound; measurements must keep landing.

**The unified cognitive substrate is no longer a thesis.** It is a substrate with two independent external proofs that its primitives are the correct primitives. The remaining work is execution.

---

*This is the only doc to summon when you return. Everything else descends from §11.*
