# B2-M5 Hardware Budget Alignment - User Decision Research

**Status:** COMPLETE_RESEARCH_READY
**Date:** 2026-05-16
**Terminal E scope:** user-decision preparation only; no implementation.

## Problem Statement

The user needs to decide whether the MAS V1 runtime should keep Swift's current conservative dual-model memory budget formula, or align it to HELIOS hardware-profile doctrine before release.

The conflict is small but release-sensitive:

- HELIOS doctrine says `M2Pro16Gb` has a realistic resident budget of 10.5 GB for weights plus KV.
- Swift `HardwareTierManager.computeDualModelBudget` uses a uniform 60% of detected tier memory, so `.base16` gets 9.6 GB.
- The research drift gate already records that this divergence is intentional and fail-loud.
- Aligning 16 GB from 9.6 GB to 10.5 GB is a roughly 900 MB loosening on the lowest V1 ship tier.
- The app already has memory-pressure handlers that unload models, release caches, and log relief metrics, which can supply post-V1 evidence.

The decision is therefore whether to keep V1 conservative and use production telemetry before loosening, or to align Swift to doctrine now.

## Options

### Option A - Keep Swift 60% formula for V1; align after telemetry

Ship MAS V1 with the current `tier.memoryGB * 0.60` formula. Keep the HELIOS drift table as the explicit record of divergence. Revisit V1.1/V1.x after real 16 GB memory-pressure telemetry or a user-run validation confirms 10.5 GB is stable.

**Pros**
- Matches current code.
- Lowest risk on the 16 GB V1 floor.
- Uses the already-shipped memory-pressure telemetry/relief path to make the next decision empirically.
- Avoids changing runtime budget behavior late in V1.
- Drift is already documented and guarded by test.

**Cons**
- Leaves about 900 MB of HELIOS-documented headroom unused on 16 GB rigs.
- May make local dual-model behavior more conservative than the doctrine intended.
- Requires a future alignment decision instead of closing the issue permanently now.

### Option B - Align Swift to HELIOS per-profile doctrine before V1

Replace the uniform Swift formula with a per-profile budget table or generated mapping matching `HardwareProfile::realistic_resident_budget_gb`, so 16 GB gets 10.5 GB.

**Pros**
- Makes Swift runtime and HELIOS doctrine agree.
- Gives 16 GB users the documented 10-11 GB sweet spot immediately.
- Reduces duplicated mental models between research doctrine and app runtime.

**Cons**
- Loosens the lowest supported runtime budget before production evidence exists.
- Could trigger more `.warning` or `.critical` memory-pressure events on 16 GB machines.
- Needs a Swift-side mapping/test and updates to the drift-gate expectations.
- Per-profile doctrine is a research crate concept; runtime tier buckets are not a perfect one-to-one mapping.

### Option C - Conservative per-profile clamp

Change Swift to `min(HELIOS profile budget, tier.memoryGB * 0.60)`.

**Pros**
- Never exceeds doctrine.
- Preserves the 9.6 GB cap for 16 GB rigs while clamping overly-large current `.ultra` budgets, for example 64 GB at 38.4 GB down toward the relevant HELIOS doctrine cap if mapped to `M2Max64Gb`.
- Reduces risk of large-tier runaway budgets without loosening the V1 floor.

**Cons**
- Does not resolve the 16 GB 10.5 vs 9.6 divergence.
- Could make high-memory Pro/Max/Ultra machines unnecessarily conservative if the runtime is allowed to exploit their headroom.
- Still needs a per-profile mapping and tests.

### Option D - Adaptive budget controller

Keep the 60% formula as the starting budget, but dynamically increase/decrease based on memory pressure, thermal state, active app state, and local-model history.

**Pros**
- Best long-term product behavior.
- Uses actual runtime conditions instead of static doctrine.
- Could gradually explore the 10.5 GB target only on machines that stay stable.

**Cons**
- More implementation than this decision needs.
- Requires careful persistence, rollback, and telemetry UX.
- Too much runtime-policy churn for MAS V1.

## Canonical Sources

### `docs/audits/HELIOS_SUBSTRATE_INVENTORY_2026_05_12.md`

- Lines 62-68: Tier S item names `hardware_profile.rs` -> PowerGuard / HardwareTierManager budget alignment, and identifies Swift `HardwareTierManager.computeDualModelBudget = totalBytes * 0.60` as the active analog of `realistic_resident_budget_gb`.
- Lines 69-75: Step 1 drift gate landed, documenting `M2Pro18Gb` match at 10.8 GB, `M2Pro16Gb` intentional divergence at 10.5 vs 9.6 GB, and `M2Max64Gb` divergence at 12.0 vs 38.4 GB.
- Lines 76-82: Step 2 remains the decision: align Swift to HELIOS doctrine or keep divergence documented as canonical; the 16 GB divergence is a release-quality decision.

### `docs/RESEARCH_COVERAGE_GAP_AUDIT_PASS2_2026_05_15.md`

- Lines 242-246: B2-M5 says HELIOS doctrine uses `M2Pro16Gb` at 10.5 GB while Swift uses 60%, producing 9.6 GB on 16 GB rigs; the current default is V1 keep divergence and V1.1 align after empirical telemetry.
- Lines 604-612: PASS 2 phase ledger includes B2-M5 in the remaining user-decision queue.

### `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md`

- Lines 285-288: master doctrine records hardware lock and the B2-M5 divergence note.
- Line 288: the hardware-profile divergence note states that V1 ships the divergence as canonical and V1.x decides alignment after 16 GB memory-pressure telemetry.

### `Epistemos/Omega/Inference/HardwareTierManager.swift`

- Lines 25-33: `dualModelMemoryBudget` is computed during hardware-tier initialization.
- Lines 58-85: detected memory tiers map 16 GB to `.base16`, 18 GB to `.pro18`, 24 GB to `.pro32`, 36 GB to `.max`, and 64 GB+ to `.ultra`.
- Lines 98-104: `computeDualModelBudget` reserves 40% for OS/app/graph and returns 60% of tier memory.
- Lines 122-145: comments map Swift `HardwareTier` buckets to HELIOS `HardwareProfile` entries and explicitly document intentional divergence plus the drift gate.
- Lines 146-164: `.base16` uses `memoryGB = 16`, `.pro18` uses `18`, `.max` uses `36`, and `.ultra` uses `64`.

### `epistemos-research/src/hardware_profile.rs`

- Lines 17-23: M2 Pro 16 GB budget is documented as roughly 10-11 GB for weights plus KV, with 4-bit 7-8B as the sweet spot.
- Lines 35-53: canonical profiles include `M2Pro16Gb`, `M2Pro18Gb`, `M2Max64Gb`, `M3Max36Gb`, and `M3Ultra256Gb`.
- Lines 68-79: `realistic_resident_budget_gb` returns 10.5, 10.8, 12.0, 24.0, and 192.0 GB for those profiles.
- Lines 106-114: both `M2Pro16Gb` and `M2Pro18Gb` count as actual user-target variants.
- Lines 139-148: `USER_ACTUAL_TARGET` remains `M2Pro16Gb`, while `M2Max64Gb` is the V6.1 reference profile.
- Lines 316-374: `helios_swift_dual_budget_alignment_table` records the doctrine/runtime parity table and breaks if either side silently drifts.

### `Epistemos/Engine/MLXInferenceService.swift`

- Lines 455-467: cache ceiling is capped by detected memory tier.
- Lines 468-485: inactive app and thermal states reduce memory/cache budgets; `.serious` thermal state applies `cacheLimit * 0.60`, and `.critical` applies `cacheLimit * 0.40`.
- Lines 1540-1544: memory-pressure listener turns warning/critical events into graceful unload instead of surprise termination.
- Lines 1572-1589: warning clears caches/KV, while critical unloads the active model.

### `Epistemos/App/EpistemosApp.swift`

- Lines 631-641: app-level `DispatchSourceMemoryPressure` listener observes normal, warning, and critical events.
- Lines 643-677: memory-pressure transitions record metadata and trigger relief work on entry.
- Lines 680-706: relief records Rust segments evicted, bytes freed, sessions pruned, search-index cache release, and critical local-model unload.

### `agent_core/src/bridge.rs`

- Lines 1031-1039: `MemoryPressureReliefFFI` returns `segments_evicted`, `segment_bytes_freed`, and `sessions_pruned`.
- Lines 1041-1054: Swift calls `respond_to_memory_pressure` on warning/critical pressure.
- Lines 1061-1083: warning evicts stale shared-memory segments and prunes old finished sessions; critical cleans all segments and prunes all finished sessions.

## Code Impact Estimate

### Option A - Keep Swift 60% formula for V1

Estimated implementation now: docs only.

Future implementation after telemetry:

- If alignment is later approved, update `HardwareTierManager.computeDualModelBudget` or add a Swift per-profile lookup.
- Update `helios_swift_dual_budget_alignment_table` to mark the new intended alignment.
- Add or update Swift tests for `.base16`, `.pro18`, `.max`, and `.ultra` budgets.

Tests now:

- Research crate drift-gate tests.
- No production code change.

### Option B - Align Swift to HELIOS per-profile doctrine before V1

Estimated implementation: 50-250 LOC.

Likely files:

- `Epistemos/Omega/Inference/HardwareTierManager.swift`
- Swift tests for budget mapping, if present for this module.
- `epistemos-research/src/hardware_profile.rs` drift table expectation changes.
- Possibly docs/MAS row update to mark the decision as aligned.

Risks:

- `.base16` increases from 9.6 GB to 10.5 GB.
- `.ultra` mapping must choose between `M2Max64Gb` doctrine 12.0 GB and larger Ultra doctrine 192.0 GB, because Swift `.ultra` buckets all 64 GB+ machines together.

### Option C - Conservative per-profile clamp

Estimated implementation: 80-300 LOC.

Likely files:

- Same as Option B.
- Additional mapping logic to avoid over-constraining actual 256 GB Ultra machines with a 64 GB Max doctrine cap.

Risks:

- May reduce high-tier budgets unexpectedly.
- Does not answer the 16 GB divergence, which is the core user decision.

### Option D - Adaptive budget controller

Estimated implementation: 500-1,500 LOC.

Likely work:

- Runtime budget state.
- Memory-pressure event counters and stability windows.
- Safe ramp-up/ramp-down policy.
- UI or diagnostics row for current learned budget.
- Rollback when pressure events spike.

Risks:

- Too much policy state for V1.
- Harder to reason about than a deterministic budget table.

## Recommendation

Recommend **Option A: keep Swift 60% formula for V1; align after telemetry**.

Recommended decision record:

> MAS V1 ships the current `HardwareTierManager` 60% dual-model budget formula. The 16 GB divergence from HELIOS doctrine is intentional: HELIOS says 10.5 GB, Swift ships 9.6 GB for the V1 floor. The drift-gate test remains the authority that prevents silent changes. V1.1 may align to HELIOS after real 16 GB memory-pressure telemetry or explicit user validation shows 10.5 GB is stable.

Reasoning:

- The current runtime posture is conservative on the smallest supported tier.
- The drift is already documented and guarded, so keeping it is not silent technical debt.
- Loosening the budget late in V1 is a memory-pressure risk, not a correctness fix.
- The app already records the relief metrics needed for a better V1.1 decision.
- A per-profile runtime table is still valuable later, but it should be done with telemetry and a clean mapping for Swift's coarse `.ultra` bucket.

## Acceptance Criteria

If the user chooses **Option A**:

- No production budget formula changes in V1.
- MAS plan and decision docs explicitly state 16 GB uses 9.6 GB even though HELIOS doctrine says 10.5 GB.
- The drift-gate test stays in place and must fail if either doctrine or Swift fraction changes silently.
- V1.1 decision uses at least one of: production memory-pressure counts, local 16 GB validation run, or explicit user override.
- Any future alignment updates both Swift runtime tests and research drift-gate expectations in the same commit.

If the user chooses **Option B**:

- Swift `.base16` budget becomes 10.5 GB or an equivalent per-profile value.
- Swift tests assert the new budget.
- Research drift-gate table is updated to mark the new intended alignment.
- Release validation includes memory-pressure monitoring on a 16 GB machine.

If the user chooses **Option C**:

- The clamp behavior is documented per tier.
- Tests cover `.base16`, `.pro18`, `.max`, and `.ultra`.
- The `.ultra` mapping does not accidentally apply a 64 GB Max cap to 256 GB Ultra machines unless that is explicitly intended.

If the user chooses **Option D**:

- Adaptive budget state is inspectable and resettable.
- The controller has safe upper/lower bounds.
- Memory-pressure spikes roll the budget back automatically.

## Decision-Ready Prompt

**B2-M5 Hardware budget decision:** Should Epistemos align Swift runtime budgets to HELIOS doctrine before MAS V1?

1. **Keep Swift 60% formula for V1; align after telemetry** - ship 9.6 GB on 16 GB rigs now, keep drift documented, revisit after memory-pressure evidence. **Recommended.**
2. **Align Swift to HELIOS per-profile doctrine before V1** - make 16 GB use 10.5 GB now and update tests.
3. **Use conservative per-profile clamp** - use `min(HELIOS, 60%)` to avoid exceeding doctrine, but keep 16 GB at 9.6 GB.
4. **Build adaptive budget controller** - dynamically tune memory budget from runtime pressure and telemetry.

Answer with one option label and constraints, for example: "Option 1, but align in V1.1 if 16 GB users see fewer than two warning events per hour."
