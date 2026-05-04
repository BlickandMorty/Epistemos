# Worktree Prototype Canon Fusion Queue — 2026-05-04

> Created in response to the user's clarification that the worktrees were
> high-value research and prototype branches, not disposable session debris.
> This queue sits beside `CANONICAL_UNIFICATION_INVENTORY_2026_05_04.md` and
> `WORKTREE_INSIGHT_SALVAGE_2026_05_02.md`.

## 0. Stance

The worktrees are **prototype canon candidates**. They are not bulk-copy
sources, but they are also not scratch. Each durable idea is fused by concern:

- **Name the product intent** in the user's language.
- **Point at the donor path** that proves the idea existed.
- **Promote a doctrine/brief** when the shape is stable.
- **Port code only in narrow slices** after reading current main.
- **Keep WRV visible**: wired, reachable, visible, verified.

Raw worktree merges remain rejected because several branches contain parallel
architectures. The recovery move is deliberate extraction.

## 1. Worktree Map

| Source | Prototype authority | Fusion treatment |
|---|---|---|
| `.claude/worktrees/simulation/` | Simulation Mode v1.6 doctrine, implementation, character-DNA, three placements, Hermes graph faculty, 16 invariants | Already promoted to `docs/fusion/simulation/`; implementation now audits T6 code against I-1 through I-16 |
| `/Users/jojo/Downloads/Epistemos-laneA` | N1 Prompt Tree / prompt-as-data substrate: JSPF, PTF, prompt cache hints, cost telemetry | Bridge promoted; reconcile deltas rather than claiming mostly merged |
| `.claude/worktrees/vigorous-goldberg-3a2d35/` | Quick Capture substrate: Tools V2, ExecutionReceipt, capture routing, heal loop, semantic cache, universal undo, skill discovery, BrowserEngine, NightBrain | Promote queue docs first; port live anchors in narrow slices starting with Tools V2 alias dispatch |
| `.claude/worktrees/agent-a0550f9c/` | Honest-handle FFI pattern, D-series audit log, Rust/Swift ownership discipline, local model admission control, message-continuity risks | Promote honest-handle doctrine and D-series audit references; port only after boundary tests exist |
| `.claude/worktrees/inspiring-heisenberg-ea9dc3/` | PLAN_V2 sections 23-27: editor truth, 16ms streaming coalescing, graph zero-copy gate, anti-pattern register, syntax-core scaffolding | Promote architectural-law brief; keep optimizations gated by benchmark evidence |
| `.claude/worktrees/practical-kapitsa-61a251/` | Mostly mirrors inspiring-heisenberg canonical docs | Consult for deltas only; do not duplicate promotions |
| `.claude/worktrees/hermes-parity/` | Hermes parity verification, provider/session persistence patterns, tool/runtime audit material | Consult for B.1 verification and Pro-tier session persistence; do not bulk-copy logs |
| `.claude/worktrees/quirky-pascal-135a98/` | Active architecture maps, implementation audits, code-editor and release-risk material | Consult as a comparison set; promote only unique canonical deltas |
| `codex/runtime-input-audit` branch | App Store input validation, vault write authorization, `CODE_EDITOR_FEATURE_AUDIT.md` | Bridge docs promoted; port only remaining current-main deltas |
| `codex/runtime-memory-hardening` branch | Five Laws, Phase I Rust agent migration, Markov-blanket sequencing | Doctrine bridge promoted; code deltas require current-main check |
| `codex/post-audit-feature-work` branch | `recipe_cache` only: SQLite-backed result cache with TTL and uncacheable tool list | Code already present in main; bridge doc now defines wiring/provenance gaps |
| `codex/release-stabilization-and-runtime-hardening` branch | Release audit workflow and historical hardening | Skill/docs already present in main; bridge doc now pins Stage F usage |

## 2. Recovery Add-Ons

These are attached to Recovery A-F, not deferred past it.

| Priority | Add-on | Track | Canon source | Output |
|---|---|---|---|---|
| P0 | Tools V2 migration anchor | T5 / T13 | `vigorous-goldberg-3a2d35/agent_core/src/tools/registry.rs`, `tools/mod.rs`, `tools/v2_catalog/` | `agent_core/docs/TOOL_MIGRATION_STATUS.md`; minimal live `execute_v2` alias dispatch in main |
| P0 | ExecutionReceipt doctrine mapping | T2 / Sovereign Gate | `vigorous-goldberg-3a2d35/agent_core/src/effect/receipt.rs` | `agent_core/docs/EXECUTION_RECEIPT_DOCTRINE_MAPPING.md`; later Ed25519 signing slice |
| P0 | Capture routing classifier preservation | T4 / Resonance Gate | `vigorous-goldberg-3a2d35/agent_core/src/route/`, `src/grammar/mod.rs`, `schemas/route_capture.*.json` | `agent_core/docs/CAPTURE_ROUTING_CLASSIFIER.md`; standalone grammar only after schema compiler read |
| P0 | Heal-loop fixture extraction | T4 / verification | `vigorous-goldberg-3a2d35/agent_core/src/bin/heal_eval.rs`, `src/heal/` | `agent_core/tests/heal_loop_fixtures.md` |
| P0 | Honest-handle FFI doctrine | T0 / Rust-FFI | `agent-a0550f9c/epistemos-shadow/src/honest_handle.rs`, `RustShadowFFIClient.swift` | `docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md` |
| P0 | PLAN_V2 sections 23-27 recovery | T9 / T10 / T13 | `inspiring-heisenberg-ea9dc3/docs/architecture/PLAN_V2.md` | `docs/fusion/PLAN_V2_SECTIONS_23_27_RECOVERY_2026_05_04.md` |
| P1 | AgentEvent v1.6 variants | T6 / event spine | `docs/fusion/simulation/DOCTRINE.md` §11 | `docs/fusion/AGENT_EVENT_VARIANTS_V16_2026_05_04.md`; later enum pre-registration |
| P1 | Prompt Tree Lane A bridge | T0 / T5 | `/Users/jojo/Downloads/Epistemos-laneA` branch `lane-A` | `docs/fusion/PROMPT_TREE_LANE_A_BRIDGE_2026_05_04.md`; reconcile current-main deltas before any Prompt Tree claim |
| P1 | Five Laws + Phase I | T0 / T5 | `codex/runtime-memory-hardening` commit family | `docs/fusion/FIVE_LAWS_AND_PHASE_I_2026_05_04.md` |
| P1 | Code-editor feature truth | T9 | `codex/runtime-input-audit` | `docs/fusion/CODE_EDITOR_FEATURE_TRUTH_2026_05_04.md`; remaining code deltas require current-main check |
| P1 | Recipe cache bridge | T5 / performance | `codex/post-audit-feature-work` commit `c217b266`; current `agent_core/src/storage/recipe_cache.rs` | `docs/fusion/RECIPE_CACHE_RECOVERY_BRIDGE_2026_05_04.md`; wire only after cache policy/provenance |
| P1 | Release-stabilization bridge | T12 / release | `codex/release-stabilization-and-runtime-hardening` commits `e5d0114a`, `d9cf9857` | `docs/fusion/RELEASE_STABILIZATION_BRANCH_BRIDGE_2026_05_04.md`; Stage F uses release-audit skill |

## 3. Current Live Checkpoint

Recovery already consumed aligned dirty work in:

- `Epistemos/Models/GenUI/GenUIPayload.swift`
- `Epistemos/Views/Approval/ApprovalModalView.swift`
- `Epistemos/Views/Landing/LandingView.swift`
- `EpistemosTests/GenUIDispatcherInvariantSourceGuardTests.swift`
- `agent_core/src/hermes/`
- `agent_core/tests/hermes_runtime.rs`
- `agent_core/tests/mas_pro_feature_gates.rs`

The open red edge is Tools V2: main has legacy registry behavior, while the
Quick Capture donor has the richer Tool trait and catalog. The immediate slice
is **not** a raw copy of `v2_catalog/`; it is a live alias/dispatch anchor plus
a migration-status doc. Native Tool trait migration remains a staged follow-up.

Two additional Quick Capture bridge docs are now promoted in `agent_core/docs/`
so the Sovereign Gate and Resonance Gate work does not have to rediscover donor
contracts:

- `agent_core/docs/EXECUTION_RECEIPT_DOCTRINE_MAPPING.md`
- `agent_core/docs/CAPTURE_ROUTING_CLASSIFIER.md`
- `agent_core/tests/heal_loop_fixtures.md`

The D-series honest-handle FFI doctrine is also promoted:

- `docs/fusion/HONEST_HANDLE_FFI_DOCTRINE_2026_05_04.md`
- `docs/fusion/PLAN_V2_SECTIONS_23_27_RECOVERY_2026_05_04.md`
- `docs/fusion/AGENT_EVENT_VARIANTS_V16_2026_05_04.md`
- `docs/fusion/PROMPT_TREE_LANE_A_BRIDGE_2026_05_04.md`
- `docs/fusion/FIVE_LAWS_AND_PHASE_I_2026_05_04.md`
- `docs/fusion/CODE_EDITOR_FEATURE_TRUTH_2026_05_04.md`
- `docs/fusion/RESOURCE_RUNTIME_PHASE_R_BRIDGE_2026_05_04.md`
- `docs/fusion/RECIPE_CACHE_RECOVERY_BRIDGE_2026_05_04.md`
- `docs/fusion/RELEASE_STABILIZATION_BRANCH_BRIDGE_2026_05_04.md`

The broader worktree-fusion brainstorming doc is now:

- `docs/fusion/WORKTREE_FUSION_BRAINSTORM_2026_05_04.md`

## 4. Worktree Fusion Rules

1. A donor file with a canonical name gets inventoried even when it is not
   promoted.
2. A donor implementation gets copied only when its dependencies, target tier,
   and current-main ownership boundary are understood.
3. Duplicated docs across worktrees are resolved by concern, not by newest file.
4. Session logs, one-off reports, benchmark output, and failed attempts stay
   pointed-at unless they contain unique doctrine.
5. Every promotion must name its Track and recovery stage.
6. If a donor prototype conflicts with XPC, MAS/Pro separation, or Simulation
   invariants, the fusion doc records the conflict before code moves.
7. User-facing recovery keeps WRV explicit; a hidden implementation is donor
   code until it is wired, reachable, visible, and verified.

## 5. Immediate Next Slices

1. Close the Tools V2 red guard with `LEGACY_TO_V2_ALIASES`,
   `v2_name_for_legacy`, `legacy_name_for_v2`, and `execute_v2`.
2. Write `agent_core/docs/TOOL_MIGRATION_STATUS.md` from the donor alias table
   and mark full native Tool trait/catalog migration as pending.
3. Use the promoted `ExecutionReceipt`, capture-routing, heal-loop fixture,
   honest-handle, PLAN_V2 sections 23-27, and AgentEvent v1.6 docs before any
   Sovereign Gate, Resonance Gate, Try-Heal-Retry, FFI ownership, editor,
   graph, streaming, event-spine, or substrate migration implementation
   re-derives those shapes.
4. Use the Prompt Tree Lane A bridge before any N1/prompt-cache/prompt-as-data
   implementation or closure claim.
5. Use the recipe-cache and release-stabilization bridges before any tool-cache
   wiring or Stage F ship-readiness work.
6. Keep Stage A.4 GenUI migration moving: Approval Modal, Daily Brief, Welcome
   Back are now on `GenUIPayload`; remaining Hermes renderers stay on the G.3
   list.
7. Keep T6 recovery honest: Companion Farm must converge to parameterized
   Tamagotchi-style bodies, while Hermes Snake moves to graph-faculty
   placement.

## 6. Acceptance Bar

- Worktree prototype queue exists in fusion and is linked from the master index.
- Tools V2 alias anchor compiles and focused tests pass.
- `CANON_GAPS_AND_ADDENDA_2026_05_02.md` records the queue and the remaining
  donor-to-main gaps.
- No bulk-copy of worktree contents occurs.
- No recovery-complete phrase is emitted until A-F are actually complete.
