# May-16 Cycle Archeology — 2026-05-23

Read-only synthesis of the 9 May-16 tracks (`codex/t{1..9}-*-2026-05-16`)
against current `origin/main` HEAD `7d1cefcdcf` (post-Phase-B, includes
the May-18 substrate wave + Wirings #1-3).

**Method.** For each track:

```
git diff origin/main..origin/codex/t<N>-<name>-2026-05-16 --name-status |
  grep "^A" > /tmp/t<N>_truly_new_files.txt
```

Then filter the "truly new" list against `/tmp/audit/02_may16_cycle.md`
"what's actually implemented" claims, and against `ls` of current main
to drop fork-point drift (LandingWave / PixelSurface delta) and
content-overlapping paths (`research/eml/`, `research/acs/`,
`research/hyperdynamic_schemas/` — all on main via May-18 successors).

**Fork-point caveat (verbatim from `02_may16_cycle.md` line 5).** All 9
branches forked near `86f0ec84fd` (pre-Hermes-purge). The ~16-18k
deletions in `git diff` stats are not May-16 work — they're files
removed from main since the fork. Only added (`A`) files
under track-specific paths count for salvage.

---

## Recommendation table

| Track | Unique additive value vs current main | Action | Files to cherry-pick (truly-new + absent on main) |
|---|---|---|---|
| **T1** Tri-Fusion | `tri_fusion` crate (MD↔HTML↔JSON round-trips, 11 cargo tests) + Swift FFI client. NOT superseded by T12 (T12 is F-ULP oracle, distinct concern). | SALVAGE | `agent_core/src/tri_fusion/{mod,html,markdown}.rs` + `agent_core/tests/tri_fusion_*` + `Epistemos/Engine/RustTriFusionDocumentClient.swift` + `EpistemosTests/RustTriFusionDocumentClientTests.swift` |
| **T2** Agent / Blueprint | Swift `AgentBlueprint` + `LocalAgentDiagnostics` (UI surface for T11 runtime). T11 is the Rust runtime; T2 ships the missing Swift layer. **Complementary, not duplicate.** | SALVAGE | `Epistemos/LocalAgent/AgentBlueprint.swift` + `LocalAgentDiagnostics.swift` + `Epistemos/Views/Chat/AgentRunTimelineView.swift` + corresponding tests |
| **T3** UAS / ACS substrate | 7 `agent_core/src/uas/*` + 2 `research/acs/anchor*` + 3 `active_assembly/*` + 5 `page_gather/*`. **`research/acs/` already on main via T17B/T18B**, so cherry-pick the **`uas/`, `active_assembly/`, `page_gather/`** subtrees only. T17B + T18B sit on these primitives. | SALVAGE (subset) | `agent_core/src/uas/*` (7 files) + `research/active_assembly/{mod,packet,selector}.rs` + `research/page_gather/{mod,sketch_topk,residual_rescore,escalation_policy,helios_page}.rs` |
| **T4** Vault recall contract | `agent_core/src/retrieval/mod.rs` (2,742L Shadow-first contract). **T21 on main already ships `storage/retrieval_trace.rs` + `f_vault_recall_runner.rs`** — DIFFERENT path, same intent. Risk of two parallel retrieval contracts. | SKIP (superseded) | (none) — T21 is the production path; T4's `retrieval/` is a parallel design. Preserve as a tag, do not merge. |
| **T5** EML-IR | 5 IR substrates absent on main: `tropical_ir/`, `scan_ir/`, `operator_ir/`, `info_ir/`, `geometry_ir/`. **`research/eml/` is already on main** (via T12). Plus 12 `.lean` files + Phase-A closeout audits. | SPLIT — see `docs/T5-PR-SPLIT-PLAN-2026-05-23.md` | 5 per-IR PRs, sequenced per the split plan. Skip the `eml/` overlap. |
| **T6** UI / UX polish | Audiophile chain (`AmbientFrequencyLivePlayer.swift` upgrades), a11y on LiveActivityStrip / ContextWindowIndicator / ProcessDisclosure, Halo persistence, Provenance Console pagination. **MOST OF T6 IS MODIFICATIONS, not pure-additive.** `^A` files are mostly LandingWave fork-drift. | DEFER | The pure-additive yield is too small to justify a salvage branch; modifications would require manual conflict resolution against post-Hermes main. Audit docs preserve the work; let polish ride on a future UI refactor cycle. |
| **T7** Deep EML | 4 `agent_core/src/research/eml_integration/{mod,potential,observatory,diagnostic}.rs` + `tests/eml_observatory.rs` + CLI `bin/epistemos_eml.rs`. **Depends on T5's `research/eml/`** which is on main already → T7 is mergeable today against main. | SALVAGE | `agent_core/src/research/eml_integration/*.rs` + `agent_core/tests/eml_observatory.rs` + `agent_core/src/bin/epistemos_eml.rs` |
| **T8** Biometric | `docs/fusion/BIOMETRIC_LOCK_DOCTRINE_2026_05_17.md` (431L Phase-0 doctrine). Self-gated DONOR-ONLY — no code. Prerequisites (T11/T17B/T18B/T12) all met. | SALVAGE (doc-only) | `docs/fusion/BIOMETRIC_LOCK_DOCTRINE_2026_05_17.md` |
| **T9** Coordinator | 16 `docs/coordination/T9_*` files + 6 `T<N>_drift_*` files. Pure docs. **NAME COLLISION**: NOT to be confused with `codex/t09-product-architecture-ledger-2026-05-18` (already on main, different track). | SALVAGE (doc-only) | `docs/coordination/T9_FINAL_CLOSEOUT_2026_05_17.md`, `docs/coordination/T9_initial_inventory_2026_05_17.md`, `docs/coordination/T9_to_T{1..8}_2026_05_17.md`, `docs/coordination/T{1,2,3,4,6,7}_drift_2026_05_17.md` |

---

## Salvage sequence

1. **T8** + **T9** (doc-only, smallest risk) — single salvage PR each.
2. **T7** (Rust-only, 4 files + tests + 1 CLI bin, depends only on main `research/eml/`).
3. **T1** (5 files + tests; Swift FFI surface adds a new module).
4. **T2** (Swift Blueprint + Diagnostics; pairs with T11 Rust runtime on main).
5. **T3** subset (UAS + active_assembly + page_gather; skip `research/acs/` overlap).
6. **T5** per-IR, per `docs/T5-PR-SPLIT-PLAN-2026-05-23.md` — 5 sequential PRs.

T4 and T6 are explicitly skipped — T4's content overlaps T21 on main; T6's pure-additive yield is too thin to justify the conflict-resolution cost.

## What this archeology doc is NOT

- It is **not** the cherry-pick itself. Each salvage track gets its own
  branch `salvage/T<N>-additive-2026-05-23` and its own PR.
- It is **not** an authorization to merge anything ahead of the per-merge
  gate. Each salvage PR is independently verified (cargo + xcodebuild
  green) and merged with the CI bypass per the user's override.
- It does **not** retire the May-16 branches. Per the
  `docs/WORKTREE_PRESERVATION_2026_05_20.md` policy, branches stay
  preserved on origin until explicitly retired.

---

## Cross-references

- `/tmp/audit/01_canon_2026_05_20.md` — spine map + W-row inventory
- `/tmp/audit/02_may16_cycle.md` — per-track audit (this doc is the
  actionable salvage table on top of it)
- `docs/T5-PR-SPLIT-PLAN-2026-05-23.md` — T5 split strategy
- `docs/WORKTREE_PRESERVATION_2026_05_20.md` — preservation tags
