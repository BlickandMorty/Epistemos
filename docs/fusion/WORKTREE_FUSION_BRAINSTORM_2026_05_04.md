# Worktree Fusion Brainstorm - 2026-05-04

This note answers the user's clarification that the other worktrees are not
disposable. They are high-value research and prototype strata. The fusion move
is not "copy everything"; it is to preserve every durable idea, name the product
intent, then port code through current-main boundaries with tests and visible
user surfaces.

## Current Ground Truth

Already promoted or salvaged:

- `docs/fusion/simulation/` holds Simulation Mode v1.6 doctrine,
  implementation, and character DNA.
- `docs/fusion/salvage/` holds at-risk prototype code/docs from Simulation,
  Quick Capture, Hermes parity, and D-series audit work.
- `docs/fusion/CRITICAL_WORKTREE_SALVAGE_FINDINGS_2026_05_04.md` is the
  emergency salvage ledger.
- `docs/fusion/WORKTREE_PROTOTYPE_CANON_FUSION_QUEUE_2026_05_04.md` is the
  staged queue.

Bridge docs now promoted:

- `docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md`
- `docs/fusion/PLAN_V2_SECTIONS_23_27_RECOVERY_2026_05_04.md`
- `docs/fusion/AGENT_EVENT_VARIANTS_V16_2026_05_04.md`
- `docs/fusion/FIVE_LAWS_AND_PHASE_I_2026_05_04.md`
- `docs/fusion/CODE_EDITOR_FEATURE_TRUTH_2026_05_04.md`
- `docs/fusion/RESOURCE_RUNTIME_PHASE_R_BRIDGE_2026_05_04.md`
- `docs/fusion/PROMPT_TREE_LANE_A_BRIDGE_2026_05_04.md`
- `docs/fusion/RECIPE_CACHE_RECOVERY_BRIDGE_2026_05_04.md`
- `docs/fusion/RELEASE_STABILIZATION_BRANCH_BRIDGE_2026_05_04.md`

## Fusion Shape

The worktrees fall into four lanes:

| Lane | Sources | Fusion move |
|---|---|---|
| Doctrine already canonical | `simulation`, `_consolidated/00_canonical_authority`, Halo master plan | Keep in fusion/index; implement against them |
| Reference-salvaged prototype code | `Epistemos-laneA`, `vigorous-goldberg-3a2d35`, `agent-a0550f9c`, Simulation Hermes UI/reference code | Port/reconcile module-by-module with current-main tests |
| Audit/parity intelligence | `hermes-parity`, release-stabilization, quirky/inspiring docs | Convert to gaps, guard tests, and Stage F verification rules |
| Historical or duplicate branches | `practical-kapitsa-61a251`, already-merged inspiring work, superseded March release scope | Point at or retire only after salvage check |

## Port Order Brainstorm

Priority 0: stop loss of meaning.

- Keep all salvaged material version-controlled under `docs/fusion/salvage/`.
- Cross-link bridge docs from the master index and unification inventory.
- Treat every future implementation task as "check salvage first".

Priority 1: Quick Capture substrate becomes current substrate primitives.

- Start with `canon/` and `format/` because aliasing and JSON+Markdown
  envelopes are low-risk dependencies.
- Port `effect/receipt.rs` into the Sovereign Gate path only after signing,
  App Group storage, and user-visible provenance are planned.
- Port `route/` as the Resonance Gate placement classifier; keep Variant A/B/C/D
  thresholds from the capture-routing bridge.
- Port `heal/` as a fixture-driven Try-Heal-Retry loop; use the 30-case corpus
  as regression evidence, not a fake ship gate.
- Port `tools/v2_catalog/` only after the current `execute_v2` alias anchor
  stabilizes.

Priority 1A: Lane A prompt-as-data becomes a reconciled substrate path.

- Treat Lane A as a live worktree even though it is outside `.claude/worktrees/`.
- Keep `PROMPT_AS_DATA_SPEC.md` and `N1_prompt_tree.md` as the N1 authority.
- Compare lane deltas in `ChatCoordinator`, `agent_core::bridge`,
  `providers::claude`, and `session_insights` before any closure claim.
- Preserve the feature flag/Settings gate until `cached_tokens_share` is visible
  and the bake window evidence supports default-on.

Priority 2: D-series work hardens the FFI and audit spine.

- Keep honest-handle ownership as the Rust/Swift handle law.
- Reconcile the salvaged `CANONICAL_AUDIT_LOG.md` against current main before
  adding new blockers to `CANON_GAPS`.
- Treat OpLog BLAKE3/hash-chain work as T2 provenance, not as optional
  diagnostics.

Priority 3: Hermes parity becomes native Hermes, not generic Rust parity.

- Read `HERMES_PARITY_AUDIT_REPORT.md` before Stage B.1.
- Read `PHASE9_AUDIT.md` before claiming Hermes runtime completion.
- Use `SKILL_PORTING_GUIDE.md` for skill porting examples, but preserve
  MAS/Pro and XPC boundaries.

Priority 4: Simulation work becomes visible UI, not hidden assets.

- Integrate Hermes landing ritual UI as a T5/T11 surface after comparing it
  with main's current Hermes Expert Mode.
- Keep T6 Companion Farm focused on parameterized Tamagotchi-style bodies.
- Move Hermes Snake toward graph-faculty placement instead of treating it as
  a generic farm icon.

Priority 5: branch bridges become guardrails.

- Recipe cache is present in main; wire it only for idempotent read/search
  tools with cache-hit provenance.
- Release-stabilization contributes the Epistemos Release Audit skill and
  Stage F verification posture, not a revived March release scope.

## What Not To Do

- Do not bulk-copy worktree trees into current source.
- Do not re-author a module when a salvaged prototype already exists.
- Do not port code before checking current-main ownership boundaries.
- Do not let old branch scope override current Recovery A-F, V2, V3 sequencing.
- Do not let hidden code count as recovery: it must be wired, reachable,
  visible, and verified.

## Next Fusion Actions

1. Use this brainstorm as the decision map before any worktree port.
2. Reconcile `docs/fusion/salvage/from-agent-a0550f9c/CANONICAL_AUDIT_LOG.md`
   against current main and log only still-real gaps.
3. Reconcile `/Users/jojo/Downloads/Epistemos-laneA` against current main
   before any Prompt Tree, prompt-cache telemetry, or prompt-as-data claim.
4. Inspect `docs/fusion/salvage/from-hermes-parity/PHASE9_AUDIT.md` before the
   next Hermes runtime slice.
5. Inspect Simulation Hermes UI salvage before adding or changing Hermes
   landing surfaces.
