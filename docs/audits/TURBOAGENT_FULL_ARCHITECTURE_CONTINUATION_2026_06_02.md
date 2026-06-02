---
state: continuation-checkpoint
created_on: 2026-06-02
repo: /Users/jojo/Downloads/Epistemos-main-integration-20260602
head_commit: 3c380159c8553debdd54bca6aa97f04dc3d68409
scope: full-architecture continuation checkpoint
write_scope: docs/audits/TURBOAGENT_FULL_ARCHITECTURE_CONTINUATION_2026_06_02.md only
status: actionable handoff; no source code edited
---

# TurboAgent Full Architecture Continuation - 2026-06-02

## Read Set

This checkpoint was written after reading the required current authority path:

- `AGENTS.md`
- `docs/audits/FULL_ARCHITECTURE_CONTINUATION_PROMPT_2026_05_31.md`
- `docs/audits/ARCHITECTURE_AUTOPILOT_PROMPT_2026_05_30.md`
- `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`
- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md`
- `docs/audits/CODEX_JUNE1_FULL_THREAD_CANON_REINTEGRATION_PROMPT_2026_06_01.md`
- `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`
- `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`
- `docs/audits/RESIDENCY_PATTERNBOOST_DRIFT_SWEEP_2026_06_01.md`
- `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`
- `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`
- `docs/fusion/MMAP_REPLACEMENT_AND_HOTPATH_CURE_ATLAS_2026_06_01.md`
- Companion falsifier bundles for Semantic Working Set, ColdStream, and
  Mmap/Hot-Path Cure.

Current repo observation:

- `HEAD` is `3c380159c855` on `main`, merge commit message
  `Merge current UI and June 1 architecture work`.
- No active `xcodebuild`, `cargo`, `swiftc`, `clang`, or `metal` build was
  observed beyond the process-table check itself.
- Final worktree verification showed only this new checkpoint file as
  untracked. If unrelated dirt such as `js-editor/package-lock.json` reappears,
  do not stage, revert, format, or repair it from this lane unless the owner
  explicitly resumes that work.

## Next Lane

Continue the full-architecture loop in this order:

1. **Primary lane: Semantic Working-Set Compiler dry-run artifacts.**
   Build the first schema-only and fixture-only path for
   `F-SourceSignalGraph-Intake`,
   `F-TaskWorkingSetQuery-Determinism`,
   `F-SemanticWorkingSetPlan-Budget`, and
   `F-ResidencyPageTable-Addressability`.
2. **Secondary lane: ColdStream manifest shape, not transport.**
   Only after a working-set plan exists, add a metadata-only
   `TransportRunManifest` completeness check. Do not benchmark, prefetch,
   mmap-stress, or touch MLX/Metal.
3. **Tertiary lane: Residency PatternBoost determinism/no-hidden-authority.**
   Use existing `agent_core/src/uas/pattern_boost.rs` records and
   `Tools/falsifiers/f_residency_patternboost_no_hidden_authority.sh`; do not
   let PatternBoost become live route authority.

Reason: the June 1 canon says PatternBoost sits above the Semantic Working-Set
Compiler, ColdStream, and Copy-Causal Geometry. The next useful implementation
is therefore not graph renderer work, not runtime inference, and not a new
architecture name. It is the smallest deterministic plan/witness surface that
names selected units, budgets bytes, rejects invalid plans before waking state,
and links to rollback and AnswerPacket visibility.

## Files Already In Main At 3c380159c8

Do not re-create or reopen these June 1 files as missing. Commit
`3c380159c855` already added the current full-thread and PatternBoost canon:

Audit/handoff originals:

- `docs/audits/CODEX_JUNE1_FULL_THREAD_CANON_REINTEGRATION_PROMPT_2026_06_01.md`
- `docs/audits/CODEX_PATTERNBOOST_DOC_SWEEP_VERIFICATION_HANDOFF_2026_06_01.md`
- `docs/audits/JUNE1_PATTERNBOOST_LOCK_CLOSEOUT_2026_06_01.md`
- `docs/audits/RESIDENCY_PATTERNBOOST_DRIFT_SWEEP_2026_06_01.md`

Fusion doctrine originals:

- `docs/fusion/CACHE_LINEAGE_AUTORESEARCH_PARADIGM_2026_06_01.md`
- `docs/fusion/COLDSTREAM_RESIDENCY_TRANSPORT_2026_06_01.md`
- `docs/fusion/CONSTRUCTIVE_RESIDENCY_PARADIGM_2026_06_01.md`
- `docs/fusion/ENGINEERING_LOGIC_ARCHITECTURE_INTAKE_2026_06_01.md`
- `docs/fusion/FORMAL_MATH_COMPANY_AND_LEAN_INTAKE_2026_06_01.md`
- `docs/fusion/MATH_AND_PORTABLE_NOTE_SYSTEMS_INTAKE_2026_06_01.md`
- `docs/fusion/META_BREAKTHROUGH_CONTROL_SURFACES_2026_06_01.md`
- `docs/fusion/MMAP_REPLACEMENT_AND_HOTPATH_CURE_ATLAS_2026_06_01.md`
- `docs/fusion/RESIDENCY_PATTERNBOOST_DISCOVERY_2026_06_01.md`
- `docs/fusion/SEMANTIC_WORKING_SET_COMPILER_2026_06_01.md`
- `docs/fusion/SUBSTRATE_TRACE_OBSERVATORY_2026_06_01.md`
- `docs/fusion/VERIFIER_CALIBRATED_SPARSE_ROUTE_COMPILER_2026_06_01.md`

Falsifier bundle originals:

- `docs/falsifiers/F-CACHE-LINEAGE-AUTORESEARCH-BUNDLE_2026_06_01.md`
- `docs/falsifiers/F-COLDSTREAM-RESIDENCY-TRANSPORT-BUNDLE_2026_06_01.md`
- `docs/falsifiers/F-CONSTRUCTIVE-RESIDENCY-BUNDLE_2026_06_01.md`
- `docs/falsifiers/F-ENGINEERING-LOGIC-ARCHITECTURE-BUNDLE_2026_06_01.md`
- `docs/falsifiers/F-MATH-NOTE-SYSTEMS-PORTABILITY-BUNDLE_2026_06_01.md`
- `docs/falsifiers/F-MMAP-REPLACEMENT-HOTPATH-CURE-BUNDLE_2026_06_01.md`
- `docs/falsifiers/F-RESIDENCY-PATTERNBOOST-BUNDLE_2026_06_01.md`
- `docs/falsifiers/F-SEMANTIC-WORKING-SET-COMPILER-BUNDLE_2026_06_01.md`
- `docs/falsifiers/F-SUBSTRATE-TRACE-OBSERVATORY-BUNDLE_2026_06_01.md`
- `docs/falsifiers/F-VERIFIER-CALIBRATED-SPARSE-ROUTE-BUNDLE_2026_06_01.md`

Duplicate recovery bundle:

- `docs/june 1/README.md`
- `docs/june 1/MANIFEST_2026_06_01.md`
- `docs/june 1/INLINE_CANON_SURFACES_2026_06_01.md`
- `docs/june 1/BRIDGE_PREFACE_LEDGER_2026_06_01.md`
- `docs/june 1/FINAL_NUANCE_CHECK_2026_06_01.md`
- `docs/june 1/artifacts/lattice-coordinate-explainer/index.html`
- `docs/june 1/audits/`
- `docs/june 1/falsifiers/`
- `docs/june 1/fusion/`
- `docs/june 1/authority-surfaces/`

The canonical originals under `docs/fusion/`, `docs/falsifiers/`, and
`docs/audits/` are authoritative if the duplicate recovery bundle differs.

## Protected Surfaces

Do not touch these in the next continuation lane:

- `src-tauri/`
- `~/Epistemos-RETRO/`
- `~/meta-analytical-pfc/`
- Graph renderer, camera, physics, and production visual internals, including
  `graph-engine/src/renderer.rs`, `graph-engine/src/engine.rs`,
  `graph-engine/src/forces.rs`, `graph-engine/src/simulation.rs`,
  `graph-engine/src/shared_buffers.rs`, `Views/Graph/`, and `Graph/`, unless a
  future owner explicitly opens the measured `GraphNodeState` ring lane.
- Heavy runtime paths: no 70B, 128K, full Metal witness, mmap/SSD stress,
  live MLX/GGUF heavy probe, or full-app Xcode test loop from this handoff.
- `artifacts/lattice-coordinate-explainer/index.html` unless lattice artifact
  work is explicitly resumed.
- Paused font/typography bundle and missing `ka1.ttf`.
- Any unrelated dirty file that appears during the next lane, especially
  `js-editor/package-lock.json`.

Also preserve the naming locks:

- Use `ColdStore` / AppColdStore for dormant residency. Do not use `ACS` as
  shorthand for Active Cold Storage.
- Keep `AcsAnchor` only for coordinate/provenance anchoring.
- SCOPE-Rex/SovereignGate own admission and verdicts.
- MAS and Pro are the only distributable builds; Research/Vault/Omega are Pro
  status bands, not separate app builds.
- Zero-copy is a compute/transport/proof discipline, not a ban on intentional
  editor, graph, undo, preview, snapshot, or artifact copies.

## Low-Risk Implementation Items

These can proceed without architecture bloat because they are schema-only,
fixture-only, or static negative checks:

1. Add a small `SemanticWorkingSetPlan` dry-run module under the existing Rust
   UAS substrate, reusing current types where possible:
   `agent_core/src/uas/weight_block.rs`,
   `agent_core/src/uas/app_cold_store.rs`,
   `agent_core/src/uas/construction_card.rs`, and
   `agent_core/src/uas/pattern_boost.rs`.
   It should emit selected evidence/KV/adapter/weight/verifier units, hot/warm
   cold/KV/adapter/evidence/verifier/scratch byte totals, rejected units,
   fallback, rollback, ProductBuild, ProStatus, and AnswerPacket visibility.
2. Add a source/query fixture bin or focused test for
   `F-SourceSignalGraph-Intake` and
   `F-TaskWorkingSetQuery-Determinism`. Use local docs/source paths and digest
   strings; do not scrape live web or import source code.
3. Add `F-ResidencyPageTable-Addressability` as a metadata-only fixture derived
   from existing `WeightBlockManifest` / `AppColdStoreRouteCard` fixtures.
   Required fields: UAS address, storage tier, byte range, codec, checksum,
   compatibility fence, lease/expiry, and prefetch priority.
4. Tighten existing non-executing gates before adding new mechanisms:
   `Tools/falsifiers/f_weight_block_range_hash_dry_run.sh`,
   `Tools/falsifiers/f_residency_plan_dry_run.sh`,
   `Tools/falsifiers/f_app_cold_store_layout.sh`, and
   `Tools/falsifiers/f_residency_patternboost_no_hidden_authority.sh`.
5. Add text/source guards for no-hidden-authority conditions:
   transport cannot wake bytes without `SemanticWorkingSetPlan`,
   SCOPE-Rex/SovereignGate admission, RuntimeRouter/System G execution,
   RunEventLog, AnswerPacket, and rollback; PatternBoost can only propose
   shadow route/layout features until held-out gates pass.

Keep these out of scope for the next easy-win cycle:

- Graph `GraphNodeState` ring promotion.
- GPU N-body copy/camera/physics changes.
- Long-note incremental parser surgery.
- Live KV/cache reuse.
- ColdStream p95/p99 benchmarks.
- 70B or 128K runtime probing.

## Verification And Falsifier Gates

For the doc-only checkpoint:

- Run `git diff --check`.
- Confirm the only new/modified file from this lane is
  `docs/audits/TURBOAGENT_FULL_ARCHITECTURE_CONTINUATION_2026_06_02.md`.

For the next implementation lane, run only lightweight verification:

- `git diff --check`
- Focused Rust tests for touched `agent_core` modules only. Avoid full app
  Xcode runs unless the user explicitly asks.
- Existing dry-run falsifiers:
  - `Tools/falsifiers/f_weight_block_range_hash_dry_run.sh`
  - `Tools/falsifiers/f_residency_plan_dry_run.sh`
  - `Tools/falsifiers/f_app_cold_store_layout.sh`
  - `Tools/falsifiers/f_residency_patternboost_no_hidden_authority.sh`
  - `Tools/falsifiers/f_uas_copy_count.sh` only if a copy-count surface is
    touched.

New gates to implement before promotion:

- `F-SourceSignalGraph-Intake`
- `F-TaskWorkingSetQuery-Determinism`
- `F-SemanticWorkingSetPlan-Budget`
- `F-ResidencyPageTable-Addressability`
- `F-MmapResidencyFence-CopyCount`
- `F-ColdStream-NoHiddenAuthority`
- `F-ResidencyPatternBoost-NoHiddenAuthority`

No claim should promote from Pro Research without:

- source path and caller/reachability proof;
- ProductBuild plus ProStatus/ResidencyStatus;
- active/hot/warm/cold/KV byte accounting;
- verifier/test/citation outcome;
- baseline or negative fixture;
- rollback reference;
- RunEventLog and AnswerPacket visibility; and
- an explicit anti-overclaim caveat when mmap, SSD, AppColdStore, KV, or 70B
  language is involved.
