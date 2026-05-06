---
state: canon
canon_promoted_on: 2026-05-04
frontmatter_added_on: 2026-05-06
covers: V2 sequence after recovery + V1 ship; V2.1-V2.7 priority order; explicit "RESUME SUBSTRATE V2" + "RESUME RESEARCH TIER" signals
---

# Post-Recovery Substrate V2 Plan — What's Next After Recovery + V1 Ship — 2026-05-04

> **Successor doctrine to `CANONICAL_RECOVERY_PLAN_2026_05_03.md`.**
> Recovery (Stages A → F) closes canon-debt and ships MAS V1. **This
> doc is the canonical answer to "what's next?"** — the V2 sequence,
> in priority order, with gating dependencies and the explicit user
> signal Codex waits for before resuming.
>
> **Codex DOES NOT auto-start V2 work** when recovery completes.
> Recovery's reply is *"RECOVERY PUSH COMPLETE — CANON RESTORED"* and
> then Codex **stops and waits** for the user to type the explicit
> phrase: ***"RESUME SUBSTRATE V2"***.
>
> When the user types that signal, Codex begins this plan from its
> first uncompleted item.

---

## 0. Why this exists

Without a post-recovery plan:

- Codex finishes recovery, replies COMPLETE, stops
- User has to research + write the next handoff to continue
- Coordination overhead. Multi-day stall between recovery and V2.

With this plan:

- Codex finishes recovery, replies COMPLETE, stops (correct — gives the user a
  green-light decision)
- When user types **"RESUME SUBSTRATE V2"**, Codex reads this plan and
  begins from item V2.1
- Continuity. No coordination overhead.

The wait-for-signal pattern matches what `CODEX_DAG_RADAR_HANDOFF` already
uses for its Phase 8 signal — same model, same discipline.

---

## 1. The V2 sequence (priority order; gating noted)

### V2.1 — Cognitive DAG Phase 8.A through 8.H (2-3 months)

**Doctrine:** `COGNITIVE_DAG_DOCTRINE_2026_05_03.md` §8

The deepest substrate-foundational work. Collapses the kernel's seven
subsystems into one typed content-addressed Merkle-rooted DAG. Sub-phases
8.A through 8.H per the doctrine §8.

**Why first:**
- Highest tier-impact in the Track Register
- Substrate-foundational — unlocks 7 things simultaneously (verifiable
  replay, cascading truth, KB-not-GB companions, git-portable skills,
  compositional capabilities, time-traveling cognition,
  audit-as-feature)
- All other V2 work composes more cleanly once DAG is stable

**Gating:** kernel doctrine Phases 1-7 must have shipped (Stage B.1 of
recovery) AND the §10 verification gates green for **two consecutive
weeks of CI** before Phase 8.A begins. This is doctrinal — never
shortcut.

**Estimated effort:** 6-10 weeks (per DAG doctrine §8 sub-phase
estimates: A=1 week, B=1 week, C=1 week, D=research spike (1-2 weeks),
E=3 weeks (subsystem migration), F=1 week (replay), G=1 week (linter),
H=1 week (ship + paper).

### V2.2 — Halo V1 stack (1-2 weeks)

**Canonical:** `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md` (PROMOTE to
`docs/fusion/halo/HALO_V1_STACK_DOCTRINE.md` as part of this work).

**Why second:**
- Highest user-visible feature impact after V1 ships
- Doctrine already exists — no spec authoring needed
- No deep substrate dependency — can start in parallel with DAG Phase
  8.E (subsystem migration), since Halo doesn't touch the agent loop

**Scope:**
- 6-state FSM
- Model2Vec retrieval
- usearch + Tantivy + RRF (already shipped per T8)
- Non-activating NSPanel (per `_consolidated/00_canonical_authority/ambient_V1_DECISION.md`)
- 25ms latency budget per Halo doctrine
- Wire into `Epistemos/Engine/HaloController.swift` (the canonical seat)

### V2.3 — LSP migration to in-process Rust (2-3 days)

**Why third:**
- Closes the LAST subprocess in the editor surface (per
  `PROCESSES_AND_RUNTIMES_AUDIT` §2.3 finding)
- Small focused work; high MAS hygiene win
- Already named in `COGNITIVE_KERNEL_DOCTRINE` as recommended Phase 4.5

**Scope:**
- Replace `Epistemos/Engine/LSPServerProcess.swift` (currently
  `Process()` subprocess) with in-process Rust LSP via `tower-lsp` +
  `tree-sitter` parsers
- Add to `agent_core/src/lsp/` module
- Move LSP from Pro to Core tier in the capability lattice

### V2.4 — XPC Mastery Phases X.1 through X.5 (2-4 weeks)

**Doctrine:** `XPC_MASTERY_DOCTRINE_2026_05_03.md` + `XPC_RESEARCH_INTAKE_2026_05_04.md`

**Gating:** **Requires paid Apple Developer Program** for cross-target
signing (per `MAS_FIRST_FOCUS_DOCTRINE` §4.5 TEMP-FREE-TIER + V1 Stage
F). Will not start without paid team.

**Why fourth (when unblocked):**
- Defense-in-depth posture for V2 ship
- Apple-grade least-privilege architecture (matches WebKit /
  Mail / Notes patterns per the doctrine §16)
- App Review fast-pass when each XPC service has minimum
  entitlements

**Sub-phases:**
- X.1: 5 XPC service skeletons (Main + Vault + Agent + Provider + WASM)
- X.2: Trust attestation (`SecStaticCodeCheckValidity` in every listener)
- X.3: Capability-token IPC
- X.4: Sandbox-within-sandbox for WASMExecXPC (`sandbox_init`)
- X.5: Audit trail across XPC + IOSurface streaming

### V2.5 — Simulation Mode v1.7+ (4-6 weeks)

**Doctrine:** `docs/fusion/simulation/DOCTRINE.md` (promoted today)

**Scope (remaining invariants from the 16):**
- I-2 Session is canonical runtime unit — wire SessionStore-as-source
- I-3 AgentEvent is the runtime bloodstream — live event stream wiring
- I-4 GraphEvent is the proof of mutation — link to MutationEnvelope
- I-7 Rust owns simulation state, Swift owns rendering and lifecycle —
  audit ownership boundary, fix any leakage
- I-8 FFI is zero-copy where measured to matter — IOSurface for hot
  paths, benchmark
- I-9 Three placements (Landing Farm + Graph Live Theater + Notes
  Sidebar Skin) — **Graph Live Theater is the third placement; build it**
- I-15 Production hot path constraints — already enforced by source
  guard tests; verify still met after V2 work

**Plus the canonical animation depth:**
- Per-companion 13-state machine from `character-dna/orb.md` etc.
- Sprite atlas + instanced Metal quads + texture array + IOSurface +
  bit-perfect (per `IMPLEMENTATION.md` §2.4)
- LoRA hot-swap for `CompanionAdapterView` (research spike from DAG §B.1)

### V2.6 — UX advanced + brand identity propagation (2-4 weeks)

**Scope:**
- HermesBrand token swap on every Hermes-aware surface
- Real NousResearch SVG art bundling (gated on user licensing decision —
  Stage E.0.5)
- Canonical NousResearch hex colors + bundled fonts already shipped
  (Stage E.0.4)
- Visual chain canon respected on every new surface (per
  memory `reference_visual_audit_chain`)
- Provenance Console UI polish (already shipped V1; deepen the GenUI
  payload set it consumes)

### V2.7 — Multi-Agent ACS tooling (ongoing)

Quality-of-life work for the development ecosystem. Codex / Claude /
Kimi / Gemini orchestration patterns.

---

## 2. The V3 / research tier (separate signal: "RESUME RESEARCH TIER")

These do NOT auto-start after V2.1-V2.7 complete. They require their
own explicit user signal: ***"RESUME RESEARCH TIER"***.

### V3.1 — Ternary substrate (Sherry 1.25-bit, KV-Direct, WBO-6)

**Track:** T14
**Gating:** Week-0 KV-Direct experiment must pass first (D_KL=0 +
token_match=100% + RAM≥8× lower per the runbook). If FAIL, audit
before any L1 work.

### V3.2 — ANE Direct Path / KV Implantation

**Track:** T15
**Gating:** Research only; Developer ID + private framework loading;
not in MAS path.

### V3.3 — V2/V3 paper drafts → MLSys / NeurIPS systems track

Per `COGNITIVE_DAG_DOCTRINE` §6 ("Verifiable replay" is publishable
systems work) and `COGNITIVE_KERNEL_DOCTRINE` §13 (single-sentence
intent). Substrate at V2.1 + V2.4 stable + V3.1 verified gives the
material for a publishable systems contribution.

---

## 3. The wait-for-signal protocol

When recovery completes:

```
Codex reply: "RECOVERY PUSH COMPLETE — CANON RESTORED"

[Codex stops. Does not start V2 work.]

User options:
  A. Type "RESUME SUBSTRATE V2" → Codex begins V2.1
  B. Pause indefinitely; review V1; bring on collaborators
  C. Type other instruction; Codex follows it
```

When V2 reaches its acceptance bar (V2.1-V2.7 complete; tests green;
two-week CI stable):

```
Codex reply: "SUBSTRATE V2 COMPLETE — DOOR TO RESEARCH OPEN"

[Codex stops. Does not start V3 work.]

User signal: "RESUME RESEARCH TIER" → Codex begins V3.1 (KV-Direct
experiment first, since it gates everything else in V3).
```

**Phrasing matters.** Codex matches the exact phrase. Prevents
ambiguous "should I be doing this?" decisions.

---

## 4. The five-question PR discipline (continues into V2/V3)

Per `CANONICAL_RECOVERY_PLAN_2026_05_03.md` §2, every PR through V2
and V3 declares:

```
Stage:        which V2.X / V3.X stage
GenUI route:  via dispatcher  |  GENUI-DEFER (with §9 row)  |  N/A
Sovereign:    canonical SovereignGate only  |  N/A
Pro impact:   no change  |  feature-gate (with restoration steps)  |  user-approved removal
TEMP-FREE-TIER: no change  |  added (with restoration row)
```

The discipline scales unchanged. V2 and V3 don't earn relaxation; if
anything they earn MORE strictness because the substrate carries more
weight.

---

## 5. Acceptance bar per V2 stage

Each V2.X stage closes when:

```
[ ] All sub-phases of the stage shipped per its canonical doctrine
[ ] All source-guard tests for new canonical surfaces ship alongside
    (the pattern Codex established during recovery)
[ ] All §10-equivalent verification gates from the relevant doctrine
    return green
[ ] Two consecutive weeks of CI green, no regressions on this stage's
    code paths
[ ] One row appended to CANON_GAPS_AND_ADDENDA_2026_05_02.md noting
    completion + any deferrals
```

The two-week CI window is the same discipline that gates DAG (Phase 8
prerequisites in `COGNITIVE_DAG_DOCTRINE` §10). Don't shortcut.

---

## 6. The Track Register stays the master backlog

Per `SUBSTRATE_TRACK_REGISTER_2026_05_03.md`, the 16 tracks across 4
zones are the eternal map. V2 and V3 are *moves through that map* —
not parallel maps.

**When in doubt about "what's next?", read the Track Register, find
the highest tier-impact × lowest blocker count Track that isn't done,
and that's the answer.** This plan codifies that for V2.1 → V2.7
because the priority order is non-obvious; V3 because it requires
explicit research-tier signal.

After V3, **the Substrate Track Register's done-state is "MAS V2
shipped + Halo V1 + DAG verified replay + XPC 5-service + Simulation
v1.7 + Research tier evaluated + paper drafted."** When all 16 Tracks
are at done-state, the plan opens up to whatever the user wants to
build next on top of the substrate (V3 paper, applications,
ecosystem, etc.).

---

## 7. The single sentence

> **After recovery completes Codex stops and replies "RECOVERY PUSH
> COMPLETE — CANON RESTORED"; the user types "RESUME SUBSTRATE V2" to
> begin V2.1 (Cognitive DAG Phase 8); Codex moves through V2.1 →
> V2.7 in canonical order with the same five-question PR discipline,
> stops at the V2 acceptance bar, and waits for "RESUME RESEARCH
> TIER" to begin V3.1 (KV-Direct gate experiment) — recovery is the
> door back into the master Substrate, and the Track Register is the
> eternal map.**

No compromises. No auto-continuation. Explicit signals only. Stay
canonical with the build docs.

---

## 8. Cross-references

```
docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md   ← this doc
docs/fusion/CANONICAL_RECOVERY_PLAN_2026_05_03.md           (predecessor; recovery sequence)
docs/fusion/CODEX_RECOVERY_HANDOFF_2026_05_04.md            (Codex recovery handoff; updated to point HERE on completion)
docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md          (eternal master backlog)
docs/fusion/COGNITIVE_DAG_DOCTRINE_2026_05_03.md            (V2.1)
docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md                     (V2.2 — promote to fusion when V2.2 begins)
docs/fusion/XPC_MASTERY_DOCTRINE_2026_05_03.md              (V2.4)
docs/fusion/XPC_RESEARCH_INTAKE_2026_05_04.md               (V2.4 supplement)
docs/fusion/simulation/DOCTRINE.md                          (V2.5)
docs/fusion/simulation/IMPLEMENTATION.md                    (V2.5)
docs/fusion/HERMES_BRAND_DOCTRINE_2026_05_04.md             (V2.6)
docs/fusion/MAS_FIRST_FOCUS_DOCTRINE_2026_05_03.md          (Pro deferral discipline; gates V2.4)
docs/fusion/CANON_GAPS_AND_ADDENDA_2026_05_02.md            (drift log; append on every stage close)
CLAUDE.md                                                   (NON-NEGOTIABLE constraints)
```
