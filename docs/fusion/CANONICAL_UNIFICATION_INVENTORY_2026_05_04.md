# Canonical Unification Inventory — Worktrees + Non-Fusion Promoted to Fusion — 2026-05-04

> **Comprehensive map of every canonical artifact that previously lived
> OUTSIDE `docs/fusion/`** — across the seven git worktrees, the
> `docs/_consolidated/` cluster system, top-level `docs/`, and the
> external research roots in `/Users/jojo/Downloads/`.
>
> Per the user's 2026-05-04 instruction:
> *"scan all worktrees and all things not in fusion folder and try to
> unify it all and copy to fusion folder and let codex know of all the
> new findings i want to make sure it actually builds because it was
> supposed to look at the worktrees and take stuff from them still
> building canonical."*
>
> **Today's promotions:** Simulation worktree canonical doctrine +
> implementation + character-DNA assets copied into
> `docs/fusion/simulation/`. Other canonical artifacts are POINTED-AT
> here rather than blindly copied (most worktree files are session
> ephemera; copying them all would pollute fusion).

---

## 0. Headline finding

The user has **substantially more canonical material on disk than
`docs/fusion/` reflects today.** Specifically:

1. **Simulation worktree** has 1982-line DOCTRINE + 2597-line
   IMPLEMENTATION + 5 character-DNA files — **PROMOTED today**.
2. **`docs/_consolidated/00_canonical_authority/`** holds **23 files
   classified as TOP CANON** that have never been promoted to
   `docs/fusion/`. These are the master plans, the doctrine docs, the
   build matrix — the foundational layer fusion sits on top of.
3. **`docs/_consolidated/30_canonical_operational/`** holds **20+
   operational docs** (handoffs, audits, integration plans).
4. **Five "Hermes parity" related worktrees** carry a shared set of
   ~15 agent-architecture docs each, plus their own deltas. Most are
   session ephemera; the canonical-named ones are pointed at here.
5. **External research roots** in `/Users/jojo/Downloads/` carry
   long-form research docs (the "Cognitive Exoskeleton Research
   Blueprint" series, "Architecture Hardening", "Custom Metal
   Mamba-2 Implementation", `EPISTEMOS-CODEX-PLAN.md`,
   `EPISTEMOS-FEATURE-SPEC.md`, `EPISTEMOS-PLUGIN-PORTING-SPEC.md`,
   etc.).

**Net:** the user's canon is real and substantial. The job for Codex
is not to author from scratch — it's to read the canon that already
exists, pick the best specs per concern, and build to them.

---

## 1. PROMOTED today (now in `docs/fusion/`)

### 1.1 Simulation Mode v1.6 canon (T6 substrate-foundational)

| Source | Destination | What |
|---|---|---|
| `.claude/worktrees/simulation/docs/simulation-mode/DOCTRINE.md` | `docs/fusion/simulation/DOCTRINE.md` | **1,982-line canonical doctrine.** 16 invariants (I-1 through I-16). Three-placement system (Landing Farm, Graph Live Theater, Notes Sidebar). Body grammar. Reducer ownership. AgentEvent ↔ animation mapping. **THE source of truth for Simulation Mode.** |
| `.claude/worktrees/simulation/docs/simulation-mode/IMPLEMENTATION.md` | `docs/fusion/simulation/IMPLEMENTATION.md` | **2,597-line implementation plan.** Slice-by-slice S0-Sn, FFI three-tier strategy, Metal rendering (instanced quads + texture array + IOSurface + bit-perfect), reducer architecture, sprite atlas strategy. |
| `.claude/worktrees/simulation/docs/simulation-mode/SESSION_KICKOFF.md` | `docs/fusion/simulation/SESSION_KICKOFF.md` | Session-start protocol for Simulation work. |
| `.claude/worktrees/simulation/docs/simulation-mode/character-dna/` | `docs/fusion/simulation/character-dna/` | Five Character DNA files specifying per-frame animation states for each body grammar: `block_compact.md`, `block_wide.md`, `orb.md`, `sage.md`, `hermes_snake.md`. **Pixel-precise specs** ("1-pixel ambient motion in idle", 13-state machine: idle/walk/think/speak/tool/spawn/handoff_give/handoff_receive/retrieve/error/recover/success/sleep). |

**Effect on the recovery plan:** Stage E.1 was "author SIMULATION_ASSETS_DOCTRINE" — that doctrine **already exists** as the promoted simulation canon. Stage E.1 collapses to zero work; Stage E.2 (implement custom-drawn body renderers) gets the full detailed spec it needs.

---

## 2. POINTED-AT (canonical, lives outside fusion, not promoted today)

### 2.1 `docs/_consolidated/00_canonical_authority/` — 23 TOP CANON files

These are classified `_canonical_authority` in the existing cluster
system. They are the master plans + doctrines fusion was built ON TOP
OF, but they were never promoted INTO fusion. **Codex should read the
relevant ones for Stage B.1 + Stage E.2 work.**

| File | Likely scope (verify on read) |
|---|---|
| `00_AUTHORITY_AND_ANTI_DRIFT.md` | Authority order + anti-drift discipline |
| `01_DOCTRINE.md` | Project-wide doctrine |
| `02_BUILD_MATRIX.md` | Build matrix (per scheme, per profile) |
| `03_EXECUTION_MAP.md` | Execution map (D1-D20 work tracker) |
| `04_PHASES.md` | Phase definitions (likely the source for Phase 1/2/3 etc.) |
| `05_RESEARCH_INDEX.md` | Research index (predecessor to MASTER_RESEARCH_INDEX) |
| `ANTI_DRIFT_SYSTEM.md` | Anti-drift system spec |
| `CLAUDE.md` | Repo-rules canon (also at repo root) |
| `CODEX_VERIFIED_STATE_2026_04_25.md` | Codex's verified state snapshot |
| `CONCEPT_DOOR_N2.md` | N2 concept-door framework |
| `EDITOR_VERDICT_TIPTAP_VS_APPFLOWY.md` | Editor decision: Tiptap vs AppFlowy verdict |
| `EXPLORATION_SPECTRUM_N3.md` | N3 exploration framework |
| `IMPLEMENTATION_PLAN_FROM_ADVICE.md` | Four-Model Advice Council synthesis (per memory) |
| `KNOWN_ISSUES_REGISTER.md` | 19 bug register (per memory) |
| `LOCAL_ANALYSIS_MODE_N4.md` | N4 local-analysis-mode framework |
| `MASTER_BUILD_PLAN.md` | Master build plan |
| `MASTER_FUSION.md` | Master fusion doc (predecessor to fusion-folder strategy) |
| `MASTER_HARDENING_AND_HARNESS_PLAN.md` | Hardening + harness master plan |
| `NEXT_SESSION_BOOTSTRAP.md` | Session bootstrap protocol |
| `PHASE_I_IMPLEMENTATION_GUIDE.md` | Phase I implementation guide |
| `PLAN_TREE_README.md` | Plan-tree convention README |
| `PLAN_V2.md` | Master plan V2 (likely the §1.6, §1.7 referenced in memory) |
| `RESEARCH_INDEX_BY_FEATURE.md` | Research index keyed by feature |
| `RESEARCH_TO_APP_TRACEABILITY.md` | Research → app traceability matrix |
| `SKILL_IMPLEMENTATION_PLAN.md` | Skill implementation plan (relevant to Stage B.1 hermes::skills) |
| `WAVE_13_MASTER_IMPLEMENTATION_PLAN.md` | Wave 13 master implementation |
| `WAVE_9_POLISH_AND_NATIVE.md` | Wave 9 polish + native pass |
| `_INDEX.md` | Index for this canonical-authority cluster |
| `ambient_V1_DECISION.md` | Ambient V1 decision (Halo V1 stack reference) |

### 2.2 `docs/_consolidated/30_canonical_operational/` — operational canon

Handoffs, audits, integration session plans, deep verification manuals,
release status, anti-drift artifacts. **Not foundational** — these are
records of canonical operational work. Codex consults when it needs
historical context (e.g., "when did Hermes parity stabilize?").

### 2.3 `docs/_consolidated/40_canonical_prompts/` — canonical prompts

| File | Purpose |
|---|---|
| `N1_prompt_tree.md` | N1 Prompt Tree spec (Lane A 601 unmerged commits per H1) |
| `W9.25_grammar_masking.md` | W9.25 grammar masking |
| `auditor_loop.md` | Auditor loop pattern |
| `full_session_orchestrator.md` | Full-session orchestrator pattern |
| `perf_*` (3 files) | Performance kickoff + addendum + context essentials |
| `phase0_ship_blockers.md` | Phase 0 ship blockers |

### 2.4 Top-level `docs/` — high-value canonical files NOT yet promoted

| File | Promotion candidate? |
|---|---|
| `AGENT_DEEP_VERIFICATION_MANUAL.md` | YES — for Codex audit work |
| `AMBIENT_RECALL_HALO_MASTER_PLAN.md` | YES — Halo V1 stack canon (T8) |
| `EPISTEMOS_FUSED_v3.md` | YES — long-form spec referenced from CLAUDE.md |
| `HERMES_INTEGRATION_RESEARCH.md` | already pointed-at from Codex Recovery Handoff |
| `HERMES_PARITY_REPORT.md` | already pointed-at from Codex Recovery Handoff |
| `IMPLEMENTATION_PLAN_FROM_ADVICE.md` | YES — Four-Model Advice Council synthesis |
| `KNOWN_ISSUES_REGISTER.md` | YES — ongoing bug register |
| `BACKEND_INTERFACE_SPEC_v1.md` | for B.1 reference |
| `CONTROL_PLANE_RESEARCH.md` | for kernel doctrine reference |
| `CLOUD_KNOWLEDGE_DISTILLATION_SPEC.md` | for B.2 FoundationModels integration |

### 2.5 Worktrees other than simulation

| Worktree | What to read | Worth promoting? |
|---|---|---|
| `agent-a0550f9c` | `docs/CANONICAL_AUDIT_LOG.md` (D-series doctrine work — D1 Merkle, D3 A2UI, D11 epistemos-trace per H8) | partial — only the canonical-audit-log file |
| `hermes-parity` | extensive perf + audit work; relevant for Stage B.1 verification | session ephemera; consult only |
| `inspiring-heisenberg-ea9dc3` | `docs/UNIFIED_SUBSTRATE_RESEARCH.md`, `docs/MASTER_HARDENING_AND_HARNESS_PLAN.md`, `docs/INSTANT_RECALL_ARCHITECTURE.md` | YES (these three) |
| `practical-kapitsa-61a251` | duplicate of inspiring-heisenberg's set | no |
| `quirky-pascal-135a98` | architecture maps + implementation audits | session-specific, consult only |
| `vigorous-goldberg-3a2d35` | **Quick Capture / Substrate Runtime** — `docs/QUICK_CAPTURE_IMPLEMENTATION_PLAN.md`, `docs/UNIFIED_SUBSTRATE_RESEARCH.md`, `docs/MASTER_SESSION_PROMPT_v2.md`, `docs/CODEX_MASTER_PROMPT.md`, `docs/FINAL_VERIFICATION_CHECKLIST.md` | YES (these five) — Quick Capture is its own substrate per master index §4 |

### 2.6 External research roots in `/Users/jojo/Downloads/`

Substantial long-form research that the canon already references. Not
promoted because copying user's home-directory research into the repo
risks license issues + bloats fusion. Pointed at instead.

| File / family | Status |
|---|---|
| `EPISTEMOS-HERMES-PARITY-PLAN.md` | **Already pointed-at from Codex Recovery Handoff §0** — this is THE canonical Hermes parity plan |
| `EPISTEMOS-CODEX-PLAN.md` (62KB) | Codex implementation plan; companion to the recovery sequence |
| `EPISTEMOS-FEATURE-SPEC.md` (115KB) | Feature spec; long-form |
| `EPISTEMOS-PLUGIN-PORTING-SPEC.md` (119KB) | Plugin porting spec |
| `Cognitive Exoskeleton Research Blueprint` (multiple versions) | Long-form research; consult |
| `Custom Metal Mamba-2 Implementation` (two versions) | Mamba-2 spec for T7 |
| `Architecture Hardening` (two versions) | Architecture hardening reference |
| `Advanced Agent Harness & Orchestration Reference` | Harness reference |
| `Kimi_Agent_Deterministic AI Deep Dive (2)/SIMULATION_MODE_V16_SUMMARY.md` | Simulation v1.6 summary (already covered by promoted DOCTRINE.md) |
| `kimis deep research/SIMULATION_MODE_V16_SUMMARY.md` | duplicate of above |

---

## 3. Updated recovery plan estimates (with the canon now visible)

The Canonical Recovery Plan estimates were based on assuming several
docs needed to be authored. With the discovered canon, several stages
collapse:

| Stage | Old estimate | New estimate (canon found) | Why |
|---|---|---|---|
| E.1 Author Simulation Assets Doctrine | 1-2 days | **0 days — promoted today** | DOCTRINE + IMPLEMENTATION + character-dna already canonical and now in fusion |
| E.2 Implement custom-drawn body renderers | 2-3 weeks | **3-5 weeks** | Spec is richer than estimated (instanced Metal quads + texture array + IOSurface + bit-perfect + 13-state animation per companion + sprite atlas strategy per IMPLEMENTATION.md §2.4 + §2.6) |
| B.1 Hermes-in-Rust | 2-4 weeks | **2-4 weeks** | EPISTEMOS-HERMES-PARITY-PLAN already canonical (5 phases, exact file paths + line numbers); guides the port |
| Halo V1 stack (T8 next phase) | not in plan | **1-2 weeks** | `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md` is canonical; promote to fusion + implement |
| Provenance Console UI (T2 closure) | 1-2 weeks | **1-2 weeks** (no doctrine found; needs author) | Genuinely missing — Codex follow-up to write doctrine doc + implement |
| GenUIDispatcher I-15 compliance fix | not in plan | **1-2 days** | DOCTRINE I-15 prohibits `AnyView` in production hot path; my dispatcher uses it; needs typed-render variant or hot-path carve-out |

---

## 4. Critical doctrinal violations / corrections discovered

### 4.1 GenUIDispatcher uses `AnyView` (Simulation DOCTRINE §I-15 violation)

DOCTRINE.md §I-15 verbatim:
> "No production hot path may use string-keyed dispatch, **`AnyView`**,
> allocation in render frames, or main-thread Metal pipeline compilation."

`Engine/GenUIDispatcher.swift` returns `AnyView` from its registered
factories. This is canon-incompatible with the Simulation hot path.

**Fix:** add a typed-render variant for Simulation surfaces (no
`AnyView`); doctrinally classify the AnyView dispatcher as
cold-path-only (Hermes Expert Mode terminal). Codex slot.

### 4.2 Body grammar is parameterized, not enum

DOCTRINE.md §5.1 + character-DNA show body grammars are
**parameterized** (e.g., Block has `block_compact` + `block_wide`
variants); my `CompanionBodyKind` enum is fixed 4-case. Needs
refactor to support parameterization.

### 4.3 Hermes Snake is the graph faculty (not a Companion Farm citizen)

DOCTRINE.md §8.1: Hermes Snake is rendered above the graph plane
(z+1 per §4.1), hovers/drifts/slithers between graph nodes. My
current implementation puts it in `CompanionBodyKind.hermesSnake`
on the Landing Farm. Doctrinal placement is graph-faculty.

### 4.4 Invariant count was 15; actually 16

DOCTRINE.md has I-1 through **I-16**. I-16 is "Bit-perfect pixel
rendering — for pixel-art assets only. No smoothing. Ever." This
constrains the Metal sampler choice + Canvas drawing in §2.4.1.

### 4.5 Hermes UI references "canonical NousResearch SVG art"

`character-dna/hermes_snake.md`: explicit reference to
*"canonical NousResearch SVG art (or Epistemos-fallback per §8.2.1
substitution allowance — see `Epistemos/Hermes/`)"*. The
HERMES_BRAND_DOCTRINE I authored 2026-05-04 is the right place to
slot the licensing decision; this reference confirms the user's
intent (NousResearch identity is canonical, with explicit
substitution allowance for Epistemos-fallback art when licensing
isn't settled).

---

## 5. Codex briefing — what's new on your radar

Per the user 2026-05-04: *"let codex know of all the new findings i
want to make sure it actually builds because it was supposed to look
at the worktrees and take stuff from them still building canonical."*

### 5.1 Read first (≤ 30 min, in order)

1. **`docs/fusion/simulation/DOCTRINE.md`** ← TODAY'S PROMOTION; the canonical 16-invariant Simulation Mode v1.6 doctrine
2. **`docs/fusion/simulation/IMPLEMENTATION.md`** ← TODAY'S PROMOTION; slice-by-slice build plan with FFI + Metal rendering specs
3. **`docs/fusion/simulation/character-dna/`** ← TODAY'S PROMOTION; per-body-grammar visual specs
4. **`docs/fusion/CANONICAL_UNIFICATION_INVENTORY_2026_05_04.md`** ← THIS DOC; map of all canon outside fusion
5. **`docs/fusion/CODEX_RECOVERY_HANDOFF_2026_05_04.md`** ← my prior handoff; recovery sequence
6. **`docs/_consolidated/00_canonical_authority/_INDEX.md`** ← top-canon map (read this BEFORE you treat any §2.1 file as authoritative)
7. **`docs/_consolidated/00_canonical_authority/PLAN_V2.md`** ← master plan V2

### 5.2 Updated recovery work (in priority order)

1. **Re-baseline against the promoted Simulation canon.** Read DOCTRINE
   in full. Audit `Epistemos/Models/Companion/CompanionModel.swift` +
   `Views/Landing/Farm/*.swift` against the 16 invariants. Surface
   every divergence into the deferral list.
2. **Fix GenUIDispatcher I-15 violation.** Add typed-render variant;
   classify AnyView path as cold-path-only.
3. **Refactor `CompanionBodyKind`** to parameterized form (Block has
   compact + wide variants per §5.1).
4. **Move Hermes Snake** to graph-faculty placement per §8.1; remove
   from `CompanionBodyKind` enum (it's a different placement, not a
   Companion variant).
5. **Continue Stage A.4 priority 2** (six remaining Hermes Expert Mode
   renderer migrations).
6. **Continue Stage E.0.4** (bundle Inter + JetBrains Mono fonts).
7. **Begin Stage B.1** Hermes-in-Rust per
   `EPISTEMOS-HERMES-PARITY-PLAN.md` PHASE 1 (register the 5
   already-implemented but unregistered tools — 30-min unlock).
8. **Promote selected `_consolidated/00_canonical_authority/` docs** to
   fusion as needed: `IMPLEMENTATION_PLAN_FROM_ADVICE.md`,
   `KNOWN_ISSUES_REGISTER.md`, `MASTER_BUILD_PLAN.md`, `PLAN_V2.md`,
   `MASTER_HARDENING_AND_HARNESS_PLAN.md`, `SKILL_IMPLEMENTATION_PLAN.md`,
   `ambient_V1_DECISION.md` (Halo V1 stack reference).
9. **Promote selected vigorous-goldberg-3a2d35/docs/** files for
   Quick Capture context: `QUICK_CAPTURE_IMPLEMENTATION_PLAN.md`,
   `UNIFIED_SUBSTRATE_RESEARCH.md`, `FINAL_VERIFICATION_CHECKLIST.md`.

### 5.3 Anti-patterns specific to today's findings

- **DO NOT re-author the Simulation doctrine.** It exists. Read it.
- **DO NOT delete `Epistemos/Views/Landing/Farm/*` to start over.** The
  hackathon Companion Farm work is salvageable; refactor against the
  canonical DOCTRINE rather than rewriting.
- **DO NOT bulk-copy worktree contents into fusion.** Most worktree
  files are session ephemera. Use this inventory + the per-worktree
  file maps in §2.5 to pull only canonical-named docs.
- **DO NOT treat `AGENT_RUNTIME_ARCHITECTURE.md` from one worktree as
  authoritative without comparing across worktrees.** All five
  hermes-parity-class worktrees carry the same file; deltas matter.
- **DO NOT skip the Halo V1 stack doc** when working on T8 — it's
  canonical at `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md` and gets a
  promotion later.

### 5.4 Acceptance bar (after this unification pass)

```
[ ] xcodebuild -scheme Epistemos green
[ ] xcodebuild -scheme Epistemos-AppStore green
[ ] cargo test --manifest-path agent_core/Cargo.toml --no-default-features --features mas-build green
[ ] All Sim canon promotions land at docs/fusion/simulation/
[ ] CANONICAL_UNIFICATION_INVENTORY committed
[ ] CompanionModel.swift audit against DOCTRINE 16 invariants logged
    (deferrals appended to CANON_GAPS_AND_ADDENDA_2026_05_02.md)
[ ] GenUIDispatcher I-15 fix or explicit cold-path-only classification
    landed
[ ] Updated recovery plan estimates land in CANONICAL_RECOVERY_PLAN
    addendum
```

When done, append one line to `CANON_GAPS_AND_ADDENDA_2026_05_02.md`:
```
2026-05-XX — Codex unification pass complete. Sim canon promoted.
GenUIDispatcher I-15 [fixed | gated cold-path-only]. Body grammar
[refactored | scheduled]. Hermes Snake placement [moved | scheduled].
N issues fixed, M deferred.
```

Then reply: **"UNIFICATION PASS COMPLETE — CANON LIVES IN FUSION"**

---

## 6. Cross-references

```
docs/fusion/CANONICAL_UNIFICATION_INVENTORY_2026_05_04.md   ← this doc
docs/fusion/simulation/DOCTRINE.md                          ← TODAY (promoted)
docs/fusion/simulation/IMPLEMENTATION.md                    ← TODAY (promoted)
docs/fusion/simulation/SESSION_KICKOFF.md                   ← TODAY (promoted)
docs/fusion/simulation/character-dna/{block_compact,block_wide,hermes_snake,orb,sage}.md  ← TODAY (promoted)
docs/fusion/CODEX_RECOVERY_HANDOFF_2026_05_04.md            ← prior recovery handoff
docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md           ← master sequence
docs/fusion/HERMES_BRAND_DOCTRINE_2026_05_04.md             ← brand identity
docs/fusion/COGNITIVE_KERNEL_AUDIT_2026_05_04.md            ← kernel fragmentation map
docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md             ← will gain §28 pointing here

docs/_consolidated/00_canonical_authority/                  ← top-canon (23 files; pointed-at)
docs/_consolidated/30_canonical_operational/                ← operational canon (pointed-at)
docs/_consolidated/40_canonical_prompts/                    ← canonical prompts (pointed-at)

.claude/worktrees/simulation/                                ← source of TODAY's promotion
.claude/worktrees/{agent-a0550f9c, hermes-parity, inspiring-heisenberg-ea9dc3, practical-kapitsa-61a251, quirky-pascal-135a98, vigorous-goldberg-3a2d35}/  ← per-worktree maps in §2.5

/Users/jojo/Downloads/EPISTEMOS-HERMES-PARITY-PLAN.md       ← canonical Hermes parity ref
/Users/jojo/Downloads/EPISTEMOS-CODEX-PLAN.md (62KB)
/Users/jojo/Downloads/EPISTEMOS-FEATURE-SPEC.md (115KB)
/Users/jojo/Downloads/Cognitive Exoskeleton Research Blueprint*  ← long-form research
/Users/jojo/Downloads/Architecture Hardening *               ← architecture hardening ref
/Users/jojo/Downloads/Custom Metal Mamba-2 Implementation*   ← T7 / Mamba-2 ref

CLAUDE.md                                                    (NON-NEGOTIABLE constraints)
```
