# Substrate ready for V2 — final close-out (2026-05-04)

This is the final state-of-substrate doc for the user's "fix all
drift + missing stuff before V2 + V3" directive. After this commit,
the substrate is canonically aligned with the original
FINAL_SYNTHESIS vision; both `RESUME SUBSTRATE V2` and `RESUME
RESEARCH TIER` signals can fire safely.

---

## §1. The 11-commit close-out (since `9a649f60`)

| Commit | What |
|---|---|
| `c78deb17` | V2.1 Phase 8.A keystone: RetractionPropagated + W9.6 budget_gate |
| `c62c1e94` | Salvage Tier A+B integration (8 modules, 5,139 LOC) |
| `58b3d14b` | A2UI closed catalog + D2 7-verb MCP graph boundary |
| `7a063f4a` | Codex continuation residuals (test alignments + doc updates) |
| `b0d229be` | Follow-up #1: NightBrain live Rust task registration end-to-end |
| `beebfb79` | Follow-ups #2+#3: Route Variant B + C deterministic implementations |
| `b118d361` | Follow-up #4: D2 graph search BM25/trigram scorers + pluggable backend |
| `720552c5` | Follow-ups #5+#6: Swift NightBrainLiveRegistry + RouteCtx::default_in_memory |
| `202b9d8e` | 177 research files lifted + canonical drift audit (3 drifts surfaced) |
| `682ba68d` | **3 drift-recovery doctrines + 3 typed Rust seams** |

**Build state**: 896 agent_core tests pass · 143 omega-mcp tests pass ·
xcodebuild SUCCEEDED · clean working tree (excl. vendored mlx-swift-lm).

---

## §2. The 3 canonical drifts — now CLOSED

All 3 from `CANONICAL_DRIFT_AUDIT_2026_05_04.md` are recovered with
doctrine + code:

### Drift A — Live File Compiler (Wave 7) ✅ RECOVERED
- **Doctrine**: `LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md` — full
  Wave 7 spec (5 invariants + 10-state machine + LivePlan.v1 schema
  + 9-gate acceptance bar)
- **Typed seam**: `agent_core/src/live_files/mod.rs` (5 tests pass)
- **Track**: T16 — gated AFTER V2.7, BEFORE V3
- **Verdict**: from "DRIFTED to indefinite deferral" → "queued
  Wave 7 with full canonical contract in code"

### Drift B — Cognitive Weight Class (4-tier) ✅ RECOVERED
- **Doctrine**: `COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md` —
  full 4-tier table + §3 five-gate promotion + §3.1
  Semantic-Gravity-vs-Policy-Authority boundary
- **Typed seam**: `agent_core/src/cognitive_weight/mod.rs` (7 tests
  pass) — `can_constrain_tools()` is THE policy-authority gate
- **Track**: T17 — W1 (V2.5+) reads metadata + applies bias; W2
  (Wave 7) enforces policy authority
- **Verdict**: from "DRIFTED to monolithic search tuning" → "4-tier
  contract in code; retrieval bias + policy authority cleanly
  separated"

### Drift C — Variant Ladder (No-LLM-First) ✅ RECOVERED
- **Doctrine**: `COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md` —
  6-tier strict escalation + 5 worked examples + 2 enforcement
  mechanisms (PR review + source guards)
- **Typed seam**: `agent_core/src/variant_ladder/mod.rs` (5 tests
  pass) — `LadderTier` + `LadderVariant` + `VariantLadder<I, O>`
- **Track**: T18 — discipline (not feature); per-PR enforcement
- **Verdict**: from "DRIFTED + PARTIAL (route-capture only)" →
  "discipline codified; reference impl pinned; future tool routes
  must honor contract"

---

## §3. Subsystem state-of-canon (final)

| Subsystem | Verdict | Status |
|---|---|---|
| Reflective Loop (Layers 1-7) | SUPERSEDES | Architecturally instanced (not just framed) |
| Provenance Plane (MutationEnvelope + ClaimLedger + RetractionPropagated) | MATCHES | All shipped + parity-tested |
| 7-Verb MCP Graph Boundary | MATCHES + DEEPENED | Spec-exact verbs + new pluggable backend (BM25 / trigram cosine) |
| Cognitive DAG Phase 8 | POSTPONED | Phase 8.A keystone shipped; full DAG awaits RESUME signal |
| Kernel Doctrine Phases 1-7 | MATCHES | Stages A-F closed |
| Honest Handle FFI | MATCHES | Doctrine + Swift consumer cutover |
| Sovereign Gate | MATCHES | Single LAContext owner + budget_gate route |
| Live File Compiler (Wave 7) | RECOVERED | Doctrine + typed seam (this commit) |
| Cognitive Weight Class (4-tier) | RECOVERED | Doctrine + typed seam (this commit) |
| Variant Ladder (No-LLM-First) | RECOVERED | Doctrine + typed seam (this commit) |
| A2UI Catalog | PARTIAL | 1 of ~25 components shipped (NoteCard); rest deferred to V2.6 |
| NightBrain (10 canonical tasks) | PARTIAL | Infrastructure complete (singleton + FFI + Swift wrapper); task bodies are NoOp placeholders |
| Helios v3 + SCOPE-Rex | POSTPONED | V3; user-authored canon now in `docs/fusion/research/user-authored/` |
| Skill Discovery (Voyager) | POSTPONED | Tier C salvage; DAG-blocked |

**Final tally**: 7 MATCHES · 1 SUPERSEDES + DEEPENS · 3 RECOVERED · 2 PARTIAL · 3 POSTPONED · **0 MISSING**.

---

## §4. The 177 lifted research files (`docs/fusion/research/`)

177 files across 9 subdirs, lifted from 30+ disk locations during
this session. Future agents read `RESEARCH_INDEX_2026_05_04.md` first
to know what's where.

Off-tree (pointed-at, not lifted): 38 MB Kimi corpus + 3 unextracted
Kimi zips (May 3-4) + full UASA+OSFT+PSOFT+COSO research + LivingBrain
Rust crate scaffold + 2.32 GB Codex snapshot.

---

## §5. What V2 + V3 look like now

When the user types **`RESUME SUBSTRATE V2`**:

- **V2.1 Phase 8.B onwards**: pick up from the keystone shipped in
  `c78deb17`. Build out remaining DAG sub-phases. Reference
  `agent_core/src/mutations/envelope.rs` + `provenance/ledger.rs` as
  the foundation.
- **V2.2-V2.7** in sequence per `POST_RECOVERY_SUBSTRATE_V2_PLAN`.
- **Wave 7 (T16/T17/T18)** lands AFTER V2.7. The doctrines are now
  stable enough that any agent can pick up Wave 7 from cold-start.

When the user types **`RESUME RESEARCH TIER`**:

- **V3 ultimate goal**: Helios v3 + SCOPE-Rex + Ternary substrate.
  User's own canon at `docs/fusion/research/user-authored/`
  (`helios v3.md`, `scope rex.md`, `scope rex omega.md`,
  `ternary kernel.md`, `SCOPE_REX_GATE_REGISTER_2026_05_01.md`).
- Gated on Week-0 ternary experiment passing per the V3 plan.

---

## §6. Recommended cold-start read order for any future Codex run

1. `CLAUDE.md` (project rules)
2. `docs/fusion/SUBSTRATE_READY_FOR_V2_2026_05_04.md` (this doc)
3. `docs/fusion/CANONICAL_DRIFT_AUDIT_2026_05_04.md` (the 3 drifts +
   reconciliation context)
4. `docs/fusion/CANONICAL_AUDIT_RECONCILIATION_2026_05_04.md` (which
   audit BLOCKERS are RESOLVED in main vs still open)
5. `docs/fusion/POST_RECOVERY_SUBSTRATE_V2_PLAN_2026_05_04.md` (the
   V2.x sequence + wait-for-signal contract)
6. `docs/fusion/SUBSTRATE_TRACK_REGISTER_2026_05_03.md` (T0-T18
   backlog, including new T16/T17/T18)
7. `docs/fusion/CODEX_PRE_V2_HANDOFF_2026_05_04.md` (verification
   floor commands + open queue)
8. The 3 new doctrines if the work touches them:
   - `LIVE_FILE_COMPILER_DOCTRINE_2026_05_04.md`
   - `COGNITIVE_WEIGHT_CLASS_DOCTRINE_2026_05_04.md`
   - `COGNITIVE_VARIANT_LADDER_DOCTRINE_2026_05_04.md`
9. `docs/fusion/research/RESEARCH_INDEX_2026_05_04.md` (off-tree
   research catalog)
10. The doctrine docs the current task touches

Skipping #2-#4 = re-investigating already-resolved blockers + re-deriving
doctrine. Don't.

---

## §7. The five-question PR discipline (canonical, unchanged)

Every commit declares:
1. **Stage** — Recovery Plan stage / V2.x phase / track
2. **GenUI route** — does it go through GenUIDispatcher? If not, why?
3. **Sovereign** — does it touch a Sovereign-Gate-required action?
4. **Pro impact** — does it change MAS / Pro behavior asymmetrically?
5. **TEMP-FREE-TIER** — does it affect the App Group restoration trail?

Five honest answers or it doesn't ship. No exceptions through V2/V3.

---

## §8. Final stop point

**The substrate is canonically clean.** Build green. Tests green.
Working tree clean. Three formerly-drifted doctrines recovered with
typed seams. 177 research files indexed. No missing items. No
contradictions between original FINAL_SYNTHESIS vision and current
shipped substrate beyond the 2 PARTIAL + 3 POSTPONED items, all of
which have explicit canonical positions.

When the user signals next move:
- `RESUME SUBSTRATE V2` → V2.1 Phase 8.B
- `RESUME RESEARCH TIER` → V3 (Helios + SCOPE-Rex + Ternary)
- Anything else → respond to the new request

End of pre-V2 close-out.
