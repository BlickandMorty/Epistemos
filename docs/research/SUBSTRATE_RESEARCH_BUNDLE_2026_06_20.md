# SUBSTRATE RESEARCH BUNDLE — context-optimized entry point for the build loop (2026-06-20)

Owner: *"This is multi-level heavy backend, not a quick feature — enormous research. Package it 100% there but not too
overwhelming; optimize for context."* This is the loop's SINGLE entry point for the substrate build: a minimal ordered
reading path + the distilled essentials, so a build agent has 100% of the substrate spec WITHOUT loading all 136
`docs/fusion/*` docs. Read these 5 (≈<700 lines total), in order, on demand — not everything.

## ORDERED READING PATH (5 docs)
1. **`docs/research/SUBSTRATE_BUILD_SEQUENCE_2026_06_20.md`** — WHAT to build: Phases 0-7, the seam, EXCLUDED list, the
   named-falsifier phase gates. *The build order. Start here.*
2. **`docs/fusion/SESSION_CHECKPOINT_2026_06_20.md`** (~176 lines) — the resume capsule: two-brain picture (§1), built vs
   not (§4-5), M0 gate (§6), the 4 owner decisions (§8), git-safety (§9), honest-tier (§10).
3. **`docs/fusion/ARCHITECTURE_READOUT_2026_06_20.md` §8-§8.7 only** (~lines 222-321) — coherent architecture, the
   "policy-async not decision-sync" soundness key (§8.2), falsifier coverage (§8.6). *Skip §1-7 unless you need an organ's depth.*
4. **`docs/research/MASTER_SYNTHESIS_2026_06_19.md`** (~144 lines) — the "built-then-not-wired" diagnosis: most of the app's
   broken feel is WIRE/FLIP/DELETE, not rebuild. Directly informs Phases 1-6 (promotion, not greenfield).
5. **`docs/fusion/pasted/GEMINI_70B_COCKTAIL_EVALUATION_2026_06_20.md` §3-§4** — the dedup map (what already exists in the
   repo → what NOT to rebuild) + the merged build order. *Theoretical/70B context; for "don't rebuild" guidance only.*

## DISTILLED ESSENTIALS (carry these; skip the rest)
- **SEAM (freeze in Phase 0):** `LocalModelHandoff` (`agent_core/src/agent_runtime_v2/system_g_runtime.rs:81-90`) +
  `AnswerPacket.attention_mode` (`scope_rex/answer_packet.rs:255`, defaults `Unavailable`) + RuntimeRouter lanes. Build
  against these; the new model attaches later with ZERO consumer rework; nothing user-facing says "new model."
- **BUILD NOW (model-agnostic, no new model/70B):** RuntimeRouter live-promotion, AnswerPacket emit+persist, System G
  real-provider wiring, EML rerank reachable, W-51 shadow recall, ACS-admission, cognitive_dag (NOT companions), health rows
  + SS-SH, B1 systems wins (sliding-window/bundling/prefetch = T1 no-model-change).
- **DEFER (behind the seam, never advertised — theoretical/available, see PRESERVED doc):** M0 interrupt experiment,
  Mamba-3/B'MOJO spine, ternary/QAT, MoLKV/Engram-real, SpQt/ReLU² kernels, the 70B model.
- **GATES:** green = T4 (build-green + reachable + visible + verified + logged + rollback-bound + AnswerPacket-visible).
  Each phase binds a named falsifier from the ~50-index (see BUILD_SEQUENCE "ADD"). Honest "fixture" never fake-green.
- **GIT-SAFETY:** main-only; EXPLICIT-path commits, NEVER `git add -A` (another agent + the auto-commit loop are on main);
  do NOT edit the authority docs' CONTENT (Living Index, lattice-coordinate-explainer) — write-plans/pointers only.
- **UNBLOCKED:** the `docs_first` hold gates brain-1 (M0/M1) ONLY, not this brain-2 build.

## Pointers
- New-model/70B theoretical research (saved, available-to-build, not in app): `docs/research/NEW_MODEL_70B_THEORETICAL_PRESERVED_2026_06_20.md`.
- Cross-ref SS-SUB (decision + rationale), SS-SH, SS-VIS, SS-CLEAN, RESEARCH_FINALIZATION_INDEX. Online research cycle RETRY
  pending (web intermittently down; local fusion canon is authoritative meanwhile per CLAUDE.md).
