# Epistemos — Living Index (single canonical entry point)

> **You are here.** This is the one document any agent or human reads first to understand the architecture, the current state, the terminals, the deferred work, the codewords, and how to resume. **Do not descend to deeper docs unless you need the specific detail.** Every paragraph below either tells you the answer or names exactly which deeper doc holds it.

**Living-doc rules:**
- Update this file in place — never branch a parallel "v2." There is one living index; the old version is `git log`.
- Update the **Current State** block (§6) on every wave close.
- Updated **2026-05-26** · latest recovery checkpoint: `a4ea05424f`
  (`#88`). For the post-stash split of finished vs unfinished work, read
  `docs/audits/MAIN_ARCHITECTURE_RECOVERY_STATUS_2026_05_26.md` before
  dispatching another recovery agent. *Run the `LEGENDARY` codeword to refresh
  the full W-row/falsifier percentages.*

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

## 6 · CURRENT STATE (2026-05-26 — Wave 2 checkpoint)

### Wired and on main
- 40+ pre-2026-05-23 PRs · 18 from the 2026-05-23 sanitization session · 5 from the 2026-05-24 doctrine session · **14 Phase-2 merge-wave PRs (#66-#79, including #73 index refresh and the direct #76 hotfix `77c7efe9ea`)**
- Substrate carcass: ~70% baseline per chronicle audit, now advanced by real Eidos bridge, System G seam, ACS production gate, T14 UAS bridge, Verified Floor chip gate, Runtime Router, Hyperdynamic Loop, B-prime chat provenance, and Round-2 falsifier artifacts. **Working estimate after Wave 2: ~92% substrate floor, pending a fresh LEGENDARY roll-up.**
- 13+ stash recovery tags pushed to origin (`refs/tags/recovery/stash-N-*`) plus Wave-2 recovery tags for PR #74, PR #79, and the B-prime uncommitted follow-up stash.
- W-rows wired: **estimated ~30/53 (~57%)** after Wave 2. Known advances: Eidos real bridge/citation gate (#66), System G real seam (#67), falsifier harnesses (#68/#74), Substrate Health/docs/unified panel work (#69/#77), VaultRecall visibility salvage (#70/#79), T14 No-Orphan bridge (#71), ACS production gate (#72), Verified Floor truth gate (#78), Hyperdynamic Schema Loop (#75), Runtime Router (#76).
- Falsifier artifacts on main: **10 artifact files**.
  - Schema-normalized primary witnesses: `F-VaultRecall-50`, `F-ULP-Oracle`, `F-Eidos-Bridge-RoundTrip`, `F-ACS-Anchor-Addressing`, `F-HyperdynamicLoop-Bounded`.
  - Schema-normalized fallback/CPU witnesses: `F-PageGather-M2Pro`, `F-ControllerKernelPack`, `F-UAS-ZeroCopy-Spine` — Metal/Swift hot-path gates still pending.
  - Legacy-shape measured PASS artifacts still to normalize: `F-UAS-CopyCount`, `F-ACS-AnchorLookup`.

### Open PRs

No merge-ready feature PRs. Two draft preservation PRs remain open and must not
be raw-merged:

- `#81` — Claude shadow-handle WIP preservation branch.
- `#82` — B-prime uncommitted follow-up preservation branch.

`main` == `origin/main` at `a4ea05424f` (`#88`, finished-vs-preserved
architecture recovery split).

**Post-merge gate:** passed on 2026-05-26.
- `cargo run --manifest-path agent_core/Cargo.toml --release --bin falsifier_validator ...` passed for the three Round-2 artifacts.
- `cargo test --manifest-path agent_core/Cargo.toml --lib --quiet` passed: 4,036 tests.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""` passed: `BUILD SUCCEEDED`.

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
| **C** | done | System G full path | merged in #67 | 3 |
| **D** | done (partial scope) | Substrate Health Panel unification | #69/#70/#71/#72 advanced rows; row expansion in D′ | 2 |
| **E** | done | ACS Admission production gate | merged in #72; ACS anchor-addressing research harness deferred as D-27 | 3 |
| **F** | done | ≥ 5 falsifiers PASS on M2 Pro | merged in #68; 7 artifacts now on main after #71; round 2 in F′ | 4 |
| **H** | not started | Research Construction Engine (scoping only) | hold until Wave 2 stabilizes | 4 |
| **R** | continuous | Online Research Intake + Fork Mining | dispatched as-needed | continuous |
| **X** | continuous | Worktree Salvage continuation | dispatched as-needed | continuous |

### Wave-2 close checklist (2026-05-26)

1. All six Wave-2 PRs merged: **#78 → #77 → #75 → #76 → #79 → #74**.
2. Main build break from #76 repaired directly on main at `77c7efe9ea`.
3. B-prime uncommitted follow-up work is not done; it is preserved as stash/tag/patch and documented in `docs/audits/B_PRIME_FOLLOWUP_REPROMOTION_PLAN_2026_05_26.md`.
4. Remaining required next work is **Wave 3**, not more Wave-2 merging: AgentBlueprint end-to-end replay UI, agent metadata badges, deeper UAS/ClaimLedger rows, Cognitive DAG visualizer, Tri-Fusion typed mutations, and B-prime follow-up repromotion.
5. Run `LEGENDARY` codeword for a fresh percentage/W-row roll-up.

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
   - No open PRs remain from #66-#72.
   - First run the post-merge local gate: cargo lib + xcodebuild.
   - If green → fresh-dispatch T0 / T1 / S in parallel.
   - Resume B and D with the rev-2 patch after T0/T1 are stable enough to consume their signals.
   - Hold H until A-G are stable and the Living Index has a fresh W-row/falsifier count.
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

**What still needs measurement, not faith.** F-Erdős-Lift-Optimality · F-KV-Direct-Gate · F-Sparse-Runtime-Split · F-LocalToolUse · F-HyperdynamicLoop-Bounded · F-70B-Local-Cocktail · primary Metal/Swift hot-path versions of F-PageGather-M2Pro, F-ControllerKernelPack, and F-UAS-ZeroCopy-Spine. Seven artifacts now exist on main, but several are fallback witnesses. Substrate is sound; measurements must keep landing.

**The unified cognitive substrate is no longer a thesis.** It is a substrate with two independent external proofs that its primitives are the correct primitives. The remaining work is execution.

---

*This is the only doc to summon when you return. Everything else descends from §11.*
