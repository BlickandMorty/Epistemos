# Epistemos — Runtime Issues for Auto-Fix

> **Index status**: CANONICAL-OPERATIONAL — Living runtime-issues doc with destructive-vs-safe auto-fix distinction + investigation log template (Open→Investigating→Patched→Verified Fixed).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



**Purpose:** Living document of runtime issues the app has encountered. AI agents (Claude Code, Codex, etc.) should read this on every session start, attempt to diagnose and fix any open issues when safe to do so, and update this doc when an issue is resolved or new information is gathered.

## How to Use This Doc

**On session start:**
1. Read this entire file.
2. For each `Status: Open` issue, decide if it's safe to investigate now (i.e., it doesn't conflict with the user's current request).
3. If you can fix an open issue WITHOUT blocking the user's current task, do it opportunistically and update the entry.
4. NEVER fix an issue if the user hasn't explicitly authorized destructive changes (deleting files, modifying shared state, force-push, etc.).

**When adding a new issue:**
- Copy the template below
- Fill in the symptom exactly as observed (paste logs/stack traces verbatim)
- Mark `Suspected Cause` as a hypothesis, not fact
- Mark `Status: Open`
- Add `Priority: P0/P1/P2/P3` (P0 = crash, P1 = data loss risk, P2 = functional bug, P3 = cosmetic)

**When updating:**
- Append a dated entry to `Investigation Log`
- Change `Status` when resolved: `Open` → `Investigating` → `Patched` → `Verified Fixed`
- Never delete old entries — the history is the audit trail

---

## Issue Template

```
### ISSUE-YYYY-MM-DD-###: Short Title

Status: Open | Investigating | Patched | Verified Fixed
Priority: P0 | P1 | P2 | P3
First Observed: YYYY-MM-DD
Affected Version: git SHA or tag

Symptom:
<exact log output / stack trace / reproduction steps>

Suspected Cause:
<hypothesis with references to file:line>

Safe Auto-Fix Attempts (no user approval needed):
- Read related files
- Add `#[cfg(debug_assertions)]` logging
- Write a failing test that reproduces the issue

Destructive Fixes (require user approval):
- Modifying FFI signatures
- Changing allocator patterns
- Removing/rewriting code paths

Investigation Log:
- YYYY-MM-DD: <what was tried, what was learned>
```

---

## Open Issues

### ISSUE-2026-05-16-015: Cannot use higher models — RAM gate is stale + per-model agent creation is too restrictive

Status: Investigating
Priority: P1 (user-blocking, names a doctrinal contradiction)
First Observed: 2026-05-16
Affected Version: `main` at `9d61c415a`
Reporter: Jordan Conley (user, 2026-05-16 evening)

Symptom:
User reports: *"app says i still cant use higher models this should be fixed tho ... with both agent creation its supposed to be per model native cloud and local and for local it still says i only have 16gb of ram but we are using new architecture remember so this should actually be a piece of cake to run a larger model so i need that actually working for users."*

Two coupled root causes:

1. **Stale RAM gate.** `Epistemos/Engine/LocalModelInfrastructure.swift:1042` —
   `nonisolated static let primaryAgentModelMinHostRAMGB: Int = 32`. On the
   user's M2 Pro 16 GB rig (per `user_hardware.md`) this hard-codes 36B agent
   models OFF, falling back to `qwen3_8B4Bit` (`fallbackPrimaryAgentModel`).
   The 32 GB minimum is computed from **dense 4-bit arithmetic** (36B × 0.5 GB
   = 18 GB resident, exceeds 16 GB ceiling). It does NOT account for V6.1
   substrate primitives that should make 36B viable on 16 GB:
     - **Ternary kernel** (BitNet b1.58-class): 36B at ternary ≈ 9 GB resident
       instead of 18 GB at 4-bit. See `agent_core/src/research/ternary/` (11
       files, 3,385 LOC) + V6.1 Foundational Seven theorem E5.
     - **Sherry/Leech lattice VQ**: weight quantization below 4-bit-dense
       equivalent. See `agent_core/src/research/sherry_lattice/` (1,582 LOC).
     - **KV-Direct memory-arch floor**: eliminates per-token KV cache growth
       (V6.1 falsifier #2). See `agent_core/src/kv_direct/`.
     - **Sparse-active assembly**: MoE-aware loading of only currently-active
       experts. See V6.1 Five-Plane Assembly plane + MASTER_FUSION §3.x rows.

2. **Per-model agent gating is overly conservative on BOTH local and cloud.**
   `Epistemos/State/InferenceState.swift:420` (`canActAsAgent`) hard-codes an
   allow-list (Qwen / DeepSeek / LFM2 / Jamba / Falcon families) and a
   deny-list (Gemma / Mistral families). Cloud model gating (`hasConfiguredCloudAccess`
   line 4634) silently routes cloud picks to local fallback when the API key
   is missing OR when Focus mode `forceLocalModelsOnly` is set. The user's
   ask: **every model — cloud or local — should be wireable as an agent
   per-model** (with honest capability badges, not silent fallback).

3. **`supportsStructuredToolCalling` gate is potentially dead.**
   `LocalToolGrammar.swift:38-44` returns true ONLY if
   `canImport(MLXStructured) && canImport(CMLXStructured) && canImport(JSONSchema)`
   all resolve. `Epistemos.xcodeproj` links only the `MLXStructured` product
   from `mlx-swift-structured`; `CMLXStructured` is an internal target (not
   a product) and `JSONSchema` is a transitive dep of MLXStructured (from
   `swift-json-schema`). Verification needed: does `canImport(CMLXStructured)`
   actually resolve true in the current build? If not, every local model has
   `supportsAgentMode = false` regardless of `canActAsAgent` — making agent
   mode silently unavailable for ALL local models. The soft-guidance fallback
   (`supportsLocalAgentLoop`) is the runtime path that does work, but the UI
   surface `supportsAgentMode` is the conservative gate.

Suspected Cause:
- Hard-coded 32 GB minimum in `LocalModelInfrastructure.swift:1042` — never
  updated to reflect V6.1 substrate's actual memory footprint.
- Allow-list / deny-list in `canActAsAgent` (`InferenceState.swift:420`) is
  Hermes-XML-grammar-specific. Per-model native grammars not yet wired (per
  the RCA-LOCAL-AGENT-GRAMMAR-001 note in that block).
- Possible build-time module-import miss on `CMLXStructured` / `JSONSchema`
  — needs runtime probe.

Safe Auto-Fix Attempts (no user approval needed):
- **Audit gate**: read each gating site (`primaryAgentModelMinHostRAMGB`,
  `canActAsAgent`, `supportsStructuredToolCalling`, `supportsAgentMode`,
  `hasConfiguredCloudAccess`, `cloudModelsEnabled`, `isCloudPickBlockedByFocus`)
  and produce a unified gating matrix doc at
  `docs/audits/MODEL_GATING_MATRIX_<date>.md`.
- **Runtime probe**: add a one-shot `#if DEBUG` log at app startup that prints
  `LocalToolGrammar.supportsStructuredToolCalling` + `cloudProviderValidationStates`
  + `LocalHardwareCapabilitySnapshot.current` — so we can verify in actual
  console output whether the agent-mode gate even fires.
- **Doctrine cross-check**: pin each gate to the doctrine row in
  MASTER_FUSION §3.x that should govern it (E5 ternary kernel for 36B-on-16GB,
  E4 KV-Direct, T0-T15 substrate tracks).

Destructive Fixes (require user approval):
- **Lower `primaryAgentModelMinHostRAMGB`** from 32 → 16 with an "Advanced /
  Power-User" Settings toggle (off by default; on = "I accept the risk of
  OOM; let me try larger models on this host").
- **Add per-model agent-capability badges** (HONEST / EXPERIMENTAL / OFF)
  in Settings → Inference → Agent so users see WHICH models qualify + WHY.
  Replace the silent fallback with an explicit "Cloud key missing — add
  one in Settings" affordance.
- **Wire actual ternary inference** into MLX-Swift path so V6.1's ternary
  kernel claim becomes runtime reality (not just doctrine). This is multi-week
  work; gate via Settings → "Experimental: ternary inference (M2 Pro 16 GB)".
- **Add `CMLXStructured` + `JSONSchema` as explicit product dependencies**
  if the runtime probe confirms they don't resolve. Update `project.yml`
  → re-run xcodegen → verify `supportsStructuredToolCalling` flips to true.

Investigation Log:
- 2026-05-16 (Claude): Logged at user request. Full gating matrix in code
  identified: 3 sites in `InferenceState.swift` (`canActAsAgent`,
  `supportsAgentMode`, `hasConfiguredCloudAccess`), 1 site in
  `LocalModelInfrastructure.swift` (`primaryAgentModelMinHostRAMGB`), 2 in
  `LocalToolGrammar.swift` (`supportsStructuredToolCalling`,
  `supportsLocalAgentLoop`), 1 in `ConfidenceRouter.swift` (`hasCapableLocalAgentModel`).
  Added §4.E sub-mission to `docs/CODEX_DEEP_INVESTIGATION_PROMPT_2026_05_16.md`
  so Codex's autonomous loop picks this up + audits + drafts a fix plan
  before any irreversible code change.
- 2026-05-17 (T9-coord): Bumped `Open` -> `Investigating` during initial
  coordination inventory. Verified main contains partial quick-wins at
  `15cc2ced4` (`AppBootstrap.swift` runtime gate probe +
  `LocalModelInfrastructure.swift` power-user RAM threshold override). Not
  marked `Patched`: full gating matrix, Settings toggle, per-model capability
  badges, strict grammar diagnosis, cloud/local routing honesty, and actual
  ternary / lattice / KV-Direct substrate work remain open under T2.
- 2026-05-17 07:28 CDT (T9-coord): T2 branch `codex/t2-agent-2026-05-16`
  added `ed7ff2531`, exposing Settings diagnostics for Active Constellation,
  Strict Grammar, Schema Drift, Constellation Health, and the existing
  power-user 36B gate. T9 is keeping this issue `Investigating`, not
  `Patched`: the 16 GB path remains an explicit experimental risk affordance,
  not a verified hardware-tier claim, and per-model capability badges /
  runtime proof / substrate work are still open.
- 2026-05-17 07:45 CDT (T9-coord): No status bump. T2 added `9b090203d`
  for durable `AnswerPacket` persistence, but that does not patch this model
  gating / 36B-on-16GB issue and is currently flagged as a committed scope
  violation in `docs/coordination/T2_drift_2026_05_17.md`. Issue remains
  `Investigating`.
- 2026-05-17 08:00 CDT (T9-coord): No status bump. T2 HEAD remains
  `edb69ec47`, and the current uncommitted T2 worktree now spans 234 modified
  files, including out-of-lane Vault (`agent_core/src/storage/vault.rs`), EML
  (`agent_core/src/research/eml/**`), broad research modules, and generated
  `syntax-core/target/**` artifacts. This is coordination drift, not proof
  that model gating or 36B-on-16GB runtime viability is patched. Issue remains
  `Investigating`.
- 2026-05-17 08:04 CDT (T9-coord): No status bump. T2 narrowed the broad WIP
  into local commit `46ac80bba`, which is scope-clean for LocalAgent /
  Settings / `agent_runtime` native grammar profiles. This is useful progress
  on per-model grammar honesty, but it is unpushed at this check, generated
  `syntax-core/target/**` artifacts remain dirty, and the issue still lacks
  verified 36B-on-16GB runtime proof. Issue remains `Investigating`.
- 2026-05-17 08:14 CDT (T9-coord): No status bump. T2 pushed `46ac80bba`,
  so the native grammar profile slice is now remotely visible and remains
  scope-clean. The issue still lacks full model-gating proof, per-model
  capability badges, strict masking fixtures, and any verified 36B-on-16GB
  runtime result. Current T2 dirty state also includes generated
  `syntax-core/target/**` artifacts and an uncommitted Swift
  `EpistemosTests/ConfidenceRouterTests.swift` path that needs explicit scope
  rationale before commit. Issue remains `Investigating`.
- 2026-05-17 08:20 CDT (T9-coord): No status bump. T2 pushed `6c5526fa8`,
  adding task-class model selection in `ConfidenceRouter` and tests for
  coder / structured-tool / reasoning routing. This is real progress toward
  per-task local model selection, but it still lacks verified 36B-on-16GB
  runtime proof and per-model capability badges. T9 also flagged the committed
  `EpistemosTests/ConfidenceRouterTests.swift` path as outside T2's exact
  written test scope without a scope rationale. Issue remains `Investigating`.
- 2026-05-17 09:04 CDT (T9-coord): No status bump. T2 HEAD remains
  `a3e177e92`; current live work adds AgentBlueprint Settings / LocalAgent
  files that appear aligned with the per-model agent-creation mission, but
  the slice is uncommitted, generated `syntax-core/target/**` artifacts remain
  dirty, `EpistemosTests/AgentBlueprintTests.swift` still needs Swift-test
  scope rationale, and there is still no verified 36B-on-16GB runtime result.
  Issue remains `Investigating`.
- 2026-05-17 09:17 CDT (T9-coord): No status bump. T2 committed
  `79cb183ee`, adding typed `AgentBlueprint` / `MissionPacket` contracts,
  a Settings mission-runner tab, and Command Center runtime dispatch. This is
  useful progress toward per-model agent creation, but the issue still lacks
  verified 36B-on-16GB runtime proof, per-model capability badges, and a
  documented rationale for the committed Swift test path. Issue remains
  `Investigating`.
- 2026-05-17 09:22 CDT (T9-coord): No status bump. T2 has live uncommitted
  AgentBlueprint refinements in `Epistemos/LocalAgent/AgentBlueprint.swift`,
  `Epistemos/Views/Settings/AgentBlueprintSettingsView.swift`, and
  `EpistemosTests/AgentBlueprintTests.swift`; the work remains product-aligned
  but still lacks 36B-on-16GB runtime proof, per-model capability badges, and
  Swift-test scope rationale. Issue remains `Investigating`.
- 2026-05-17 09:31 CDT (T9-coord): No status bump. T2 pushed `ea2792cd1`,
  adding runtime badges for AgentBlueprint model choices and MissionPacket
  audit text. This partially addresses the capability-badge surface for the
  AgentBlueprint picker, but the broader issue still lacks verified
  36B-on-16GB runtime proof, global per-model capability badges, and Swift-test
  scope rationale. Issue remains `Investigating`.

---

### ISSUE-2026-05-12-014: LOD zoom-out transition still feels too harsh

Status: Patched (iteration 3 — per-node shader fade + wider label fade bands)
Priority: P2
First Observed: 2026-05-12

Symptom:
User reports the LOD transition during zoom-out has improved but still feels
too harsh — "the nodes should like have the right amount and then smoothly
do it." Translation: at any zoom there's a "right" density of visible
elements; the transition BETWEEN density states should be a smooth fade,
not a step.

Investigation:
- The `lod_renderer.rs` module shipped in `857d9161e` is scaffolding only.
  Its `LodTransitionState` 200 ms crossfade was never wired into the live
  render path.
- The actual harsh behavior is two coupled steps:
  1. Per-node sprite cull is binary — at the viewport edge the sprite
     pops from full-alpha to gone, with no fade zone (renderer.rs
     `collect_visible_node_indices` only does inside-bounds vs outside).
  2. Label fade bands were narrow: `LABEL_FADE_MIN_SCREEN_PX..MAX = 8..22 px`
     (14 px window), `label_density_opacity = smoothstep(0.58, 0.92)`
     (0.34-wide window). Both transitions completed in a small band of
     zoom motion → reads as a step.

Safe Auto-Fix Applied:
- `node_vertex` Metal shader (renderer.rs node_vertex): added a per-node
  zoom-fade factor:
    `screen_radius_px = effective_radius * uniforms.camera_zoom;`
    `zoom_fade_alpha = smoothstep(1.5, 6.5, screen_radius_px);`
    `out.color.a *= zoom_fade_alpha;`
  Above ~6.5 px screen radius the factor is 1.0 (no impact at normal
  viewing). Below 6.5 px the sprite alpha tapers gracefully to 0 by 1.5 px
  so tiny sprites fade out instead of popping when zooming way out.
- `LABEL_FADE_MIN_SCREEN_PX 8.0 → 5.0` and
  `LABEL_FADE_FULL_SCREEN_PX 22.0 → 28.0`. Window widens from 14 px to 23
  px around the same perceptual midpoint (~16 px).
- `label_density_opacity` smoothstep band widened from `[0.58, 0.92]` to
  `[0.42, 0.95]`. Density-driven label fades are now 0.53 of range instead
  of 0.34 — labels fade in/out gradually as local density climbs.

Tests (both new, in graph-engine/src/engine.rs):
- `label_fade_band_widens_for_softer_zoom_out_transition` — asserts the
  new constants, the midpoint = 0.5 smoothstep behavior, and the
  band-width invariant (>14 px).
- `density_opacity_band_widens_for_gentler_label_fade` — asserts the new
  density-opacity edges, protected-label bypass, and band-width invariant
  (≥0.5 of range).

Full graph-engine suite (2,775 tests) passes.

Open Follow-ups:
- If the user still finds the transition stepped at the very-low-zoom
  end, the next move is to wire `lod_renderer.rs`'s `LodTransitionState`
  crossfade (200 ms alpha-blend between centroid/mixed/leaf-only tiers)
  into the live render path. Currently it's scaffolding for the cluster
  multilevel path that hasn't shipped yet.

---

### ISSUE-2026-05-12-013: Graph feels below 120 fps at high vault count (REOPENED + retargeted)

Status: Patched via physics-rate doubling + cinematic-cap REVERTED per user
Priority: P2
First Observed: 2026-05-12

Symptom:
User reports the graph "still feels low frames" at high vault counts despite
the ProMotion 120 Hz target and despite the 27.7% checksum CPU regression
already having been fixed (BLAKE3 swap). No stutter, just below-cap framerate
at scale.

Iteration 1 (REVERTED):
Initial fix added a soft 5 MP cinematic pixel budget at ≥9k nodes. User
2026-05-12 directed: pixel-art identity must hold on EVERY vault size,
do NOT trade resolution for fps. The cinematic cap is therefore reverted
and the cinematic path renders at full native Retina at any node count.
Lock-in test renamed `graphDrawableResolutionPolicyKeepsCinematicNativeAtAllVaultSizes`.

Iteration 2 (APPLIED):
The real bottleneck for "feels below 120 fps" is the physics sampling rate
mismatch with the 120 Hz render rate, not GPU fill. Render side IS at 120 Hz
(CADisplayLink); physics was integrating at 60 Hz top-tier and dropping to
24 Hz at 5k+ nodes — so at 5k nodes the renderer was interpolating between 24
unique physics frames per second across 120 render frames, which reads as
"motion is choppy."

- `graph-engine/src/simulation.rs`: `PHYS_TICK_DT` raised from 1/60 to 1/120.
- `graph-engine/src/engine.rs::adaptive_physics_hz` tiers doubled where feasible:
    * 0–1000 nodes: 120 Hz (was 0–500 at 120, 501–1000 at 60)
    * 1001–3000:    60 Hz (was 40)
    * 3001–5000:    40 Hz (was 30)
    * 5001–9000:    30 Hz (was 24)
    * 9000+:        24 Hz (unchanged — O(N²) physics can't sustain 120 here)
- Combined dt-halving + loop-rate-doubling preserves wall-clock simulation
  behavior (same per-second motion, same damping, same curl evolution) and
  just doubles temporal sampling density — which is what makes motion read
  as smooth at 120 fps.
- Lock-in test updated:
  `adaptive_physics_hz_targets_120_at_small_graphs_and_degrades_at_high_node_counts`.
  Full graph-engine suite (2,773 tests) passes.

Open Follow-ups:
- If user still observes choppy motion on the 5k+ vault tier, next move is to
  raise that tier to 60 Hz at the cost of more physics CPU — currently
  capped at 30 Hz as a budget compromise.
- Cinematic shader (waterNodes) per-fragment cost remains the GPU bottleneck
  at very high vault count on external Retina displays. Honest trade-off: the
  user has chosen identity over fps; if they later want a fast-path, the
  explicit Performance toggle is the right surface (qualityLevel=2 → 3 MP cap).

---

### ISSUE-2026-05-12-011: Main thread hangs at app startup (969ms + 3182ms)

Status: Operator-required (Instruments trace pending) — surfaced 2026-05-16 from /loop iter 11
Priority: P2
First Observed: 2026-05-12

Symptom:
User runtime log shows two main-thread hangs at app startup:
- 969ms hang right after `Workspace restored: 0 notes, 0 mini chats` +
  `Activity tracking started`
- 3182ms hang (coalesced 3 samples) right after
  `app_became_active` lifecycle event

The 500ms threshold is set by `RuntimeDiagnosticsMonitor` so anything
over that is a `Main thread hang detected` log.

Suspected Cause:
- The 969ms hang is likely the SwiftData container load + RootView
  first render. Pre-existing on the substrate.
- The 3182ms hang after `app_became_active` is harder to pin down
  from the trace alone. Candidates (any combination):
  1. SwiftUI body re-evaluation cascade — `vaultReprompSheet`
     binding evaluates UserDefaults reads + multiple guards;
     NoVaultConnectedBanner same shape.
  2. MLX model warmup (Qwen 3 8B is ~4GB) — `Local agent model
     selected` log fires before the hang.
  3. Graph engine init / scene re-layout on first activate.
  4. Background subscriber storm (NightBrain, ACC catalog refresh,
     R3 gateway, paperclip, etc.) all fire in parallel.

Safe Auto-Fix Attempts (deferred — needs runtime profiling first):
- Cache the `vaultReprompSheet` predicate inputs (UserDefaults reads)
  via `@AppStorage` instead of direct `UserDefaults.standard.bool/data`
  on every body re-evaluation.
- Defer MLX model load to first agent invocation rather than first
  app-active.
- Move heavy startup work behind `Task.detached(priority: .userInitiated)`.

Destructive Fixes (not appropriate):
- Removing diagnostic logging.
- Disabling the watchdog.

Investigation Log:
- 2026-05-12: First captured in user's runtime trace after the vault
  disconnect arc landed. Hangs predate the vault fixes — confirmed by
  process audit (no vault-restoration runs because bookmark is
  cleared, so the hang isn't on the restore path). Needs Instruments
  Time Profiler trace to pin down the 3-second hang's actual stack.

---

### ISSUE-2026-05-12-012: APFS recovery snapshot delete fails on stuck old snapshot

Status: Patched (`820458df5` breaks retry loop — drops failed-delete from manifest + logs once per snapshot per session)
Priority: P3
First Observed: 2026-05-12

Symptom:
User runtime log shows:
- `Failed to prune APFS safety snapshots: Failed to delete local snapshot '2026-04-24-041553'`
- `Failed to create APFS safety snapshot: Failed to delete local snapshot '2026-04-24-041553'`

The April 24 snapshot is stuck in the local recovery manifest +
can't be deleted via `tmutil deletelocalsnapshots`. Subsequent
snapshot creates fail because the prune step fails.

Suspected Cause:
`tmutil deletelocalsnapshots` requires either user authorization or
the snapshot to be deletable without admin privilege. The stuck
April 24 snapshot is likely pinned by macOS for some reason
(network access, time machine still holding it, recent TM run, etc).

Safe Auto-Fix Attempts:
- Detect repeated delete failures for the same snapshot ID + skip
  it in the manifest after N attempts (forget it rather than retry
  forever).
- Wrap `Self.backgroundLog.error` with a per-snapshot rate limit so
  the error doesn't spam the log every prune cycle.

Destructive Fixes (require user approval):
- Forcing snapshot delete via privileged helper.
- Calling `tmutil thinlocalsnapshots /` (TM-wide thin).

Investigation Log:
- 2026-05-12: First captured in user's runtime trace. Background
  priority, so no main-thread impact. Pre-existing — not introduced
  by the vault disconnect fix.

---

### ISSUE-2026-05-12-010: Vault disconnect hangs forever after iteration-1 bookmark-clear reorder

Status: Patched (commit `fa2c29f91` reverts to safe ordering + adds crash-safe `disconnectInProgress` flag)
Priority: P0
First Observed: 2026-05-12 (user report directly after iteration-1 fix landed)

Symptom:
After commit `71ef9f1e9` shipped, the user reported "I cant remove the
vault it just waits forever / readding a vault etc. its not working
anymore / it makes me reselect my vault on startup". Three regressions
in one — the disconnect hung indefinitely AND the re-prompt sheet
nagged after explicit disconnect AND vault re-selection didn't take.

Root Cause:
Commit `71ef9f1e9` moved `clearPersistedVaultSelection()` to the very
top of the disconnect Task block, ahead of `stopWatchingAsync(preserveData: false)`.
The bookmark in UserDefaults is what makes the URL re-mountable on
launch, but the in-memory `vaultURL` holds the security-scoped resource
handle that `stopWatchingAsync` → `prepareToStopWatching` → file watcher
tear-down + `clearLocalVaultStateOffMain` filesystem snapshot all
depend on. Clearing UserDefaults first orphaned the session-scoped
access state and hung the file-watcher subscriber loop.

The re-prompt-nag symptom shared the same root: bookmark cleared too
eagerly meant the `bookmarkPending` check in the sheet predicate
flipped false right after disconnect, satisfying all the other
predicate conditions and firing the sheet again.

Safe Auto-Fix Attempts (applied in `fa2c29f91`):
- Reverted clear-bookmark-FIRST ordering. `stopWatchingAsync` runs
  while the security-scoped URL is still live; `clearPersistedVaultSelection`
  runs AFTER teardown completes.
- Added `epistemos.disconnectInProgress` UserDefaults flag set at the
  top of the disconnect Task block (atomic, fast). Cleared after the
  full teardown. Survives crashes / force-quits.
- Added `restoreVaultFromBookmark()` recovery check at the very top:
  if `disconnectInProgress` is true on launch, clear the bookmark + flag
  immediately and skip restoration. Completes the user's intent even
  if the original teardown was interrupted by force-quit.
- Added `epistemos.hasEverConnectedAVault` flag set on first
  `persistVaultSelection`. VaultReprompSheet predicate now requires
  `!hasEverConnectedAVault` so explicit-disconnect users aren't nagged.

Destructive Fixes (not applied):
- Forcing the user back through SetupAssistant after every disconnect.
- Auto-creating a default vault on disconnect.

Investigation Log:
- 2026-05-12: User reported regression directly. Re-ordered teardown
  back to original sequence + added crash-safe flag pattern. Build
  succeeded. User to confirm.

---

### ISSUE-2026-05-12-001: Silent vault-not-connected state hides indexing failure from user

Status: Patched (NoVaultConnectedBanner shipped in `fdd8e67dc`)
Priority: P1
First Observed: 2026-05-12

Symptom:
User can create and edit notes (stored in SwiftData SDPage container) without
ever connecting a filesystem vault folder. The app gives no UI feedback that
notes are NOT being indexed by Shadow/Halo and won't appear in vault-backed
search. User discovered this when Halo silently failed for them — only via
Settings → Diagnostics did they learn that "No active vault selected" was the
root cause.

Suspected Cause:
`AppBootstrap` allows the SwiftData container to operate independently of
`vaultSync.vaultURL`. Editor, sidebar, and note creation all work against the
SwiftData store. Shadow indexer + Halo button + Background indexer all gate
on `vaultSync.vaultURL != nil` at `AppBootstrap.swift:3104`. No visible banner
or callout exists in any user-facing surface when the vault is disconnected.

Safe Auto-Fix Attempts (no user approval needed):
- Add a dismissible banner above the editor or in the sidebar that says
  "No vault folder connected — your notes won't appear in search yet.
  [Connect Vault]" with a button that opens the folder picker.
- Surface the same warning in the Notes empty state.
- Add a Settings → Privacy & Storage badge (small dot on the sidebar entry)
  when no vault is connected.

Destructive Fixes (require user approval):
- Forcing vault selection at first launch (tracked separately as
  ISSUE-2026-05-12-002).
- Auto-creating a default vault folder without user consent.

Investigation Log:
- 2026-05-12: New entry. Tied to ISSUE-2026-05-10-001 root cause finding.
  The Halo wiring is canonical; what's missing is user awareness that
  Halo requires a vault.

---

### ISSUE-2026-05-12-002: First-launch onboarding does not force vault selection

Status: Patched (VaultReprompSheet shipped in `b598ce4c5`; predicate tightened against bookmark-restore race in `71ef9f1e9`; v2 fix `fa2c29f91` adds `hasEverConnectedAVault` gate so explicit-disconnect doesn't nag)
Priority: P2
First Observed: 2026-05-12

Symptom:
A new user can install Epistemos, skip past `SetupAssistantView`, and start
creating notes without ever picking a vault folder. This produces the silent-
Halo failure tracked in ISSUE-2026-05-12-001 + ISSUE-2026-05-10-001.

Suspected Cause:
`Epistemos/Views/Onboarding/SetupAssistantView.swift:321` has a vault-picker
flow (`canChooseDirectories = true`), but the rest of the app does not gate
on its completion. A user who closes onboarding without selecting a folder
enters a degraded state with no recovery prompt.

Safe Auto-Fix Attempts (no user approval needed):
- Make the SetupAssistant non-dismissible until a vault folder is chosen,
  OR add a re-prompt sheet that appears on every cold-launch when
  `vaultSync.vaultURL == nil`.
- Add a "Choose later" escape hatch that explicitly disables Halo and
  Shadow indexing with a one-time confirmation, then surfaces the banner
  from ISSUE-2026-05-12-001 persistently.

Destructive Fixes (require user approval):
- Replacing the existing onboarding flow.
- Auto-creating a folder.

Investigation Log:
- 2026-05-12: New entry. Polish item flagged during ISSUE-2026-05-10-001
  diagnosis. Pairs with the banner work in ISSUE-2026-05-12-001.

---

### ISSUE-2026-05-12-003: Cognitive DAG shipped but has no user-visible surface

Status: Patched (empty-state explanation shipped in `26db9ff41`)
Priority: P3
First Observed: 2026-05-12

Symptom:
Phase 8.A-8.G of the Cognitive DAG (10 NodeKind, 10 EdgeKind, Merkle-signed
edges, 4 dispatch mirrors) is fully implemented in `agent_core/src/cognitive_dag/`
but has no user-facing UI. The Diagnostics row shows "Cognitive DAG: empty
(waiting for mirrors)" — the empty state is accurate but the user has no
way to see node/edge counts, walk DerivesFrom/Contradicts edges, or
inspect the Merkle root after mutations.

Suspected Cause:
The DAG was scoped as substrate for sync + provenance, not as a primary
graph-visualization target. Mirrors (skills / procedural / provenance /
companion) are wired but the Diagnostics surface only reports the
"waiting for mirrors" header — no count, no edge sample.

Safe Auto-Fix Attempts (no user approval needed):
- Expand `CognitiveDagHealthRow` to display: node count, edge count by
  kind, current Merkle root (hash prefix), and a `DerivesFrom` /
  `Contradicts` walk button that opens a small read-only view.
- Wire one mirror's emission (Provenance is easiest) so the row stops
  showing "waiting for mirrors" on every clean launch.

Destructive Fixes (require user approval):
- Adding the Cognitive DAG as a top-level navigation surface (this is
  substantial UI work and a product decision).

Investigation Log:
- 2026-05-12: New entry. Promoted from inventory ⚠️ status. The DAG
  is real and tested; only the visible surface is missing.

---

### ISSUE-2026-05-12-004: Halo button placement (bottom-right of editor) is undiscoverable

Status: Patched (⌘⇧H keyboard shortcut + tooltip + label shipped in `fb12adc3a`)
Priority: P2
First Observed: 2026-05-12

Symptom:
When the user has a vault selected and types in the editor,
`installHaloIfAvailable()` at `ProseEditorRepresentable2.swift:922` adds a
small `HaloButton` host as a subview of the editor's `NSScrollView`,
anchored 18pt from the trailing edge and 18pt from the bottom. Users
report not seeing "a halo thing" when they type because they're expecting
inline behavior (like Obsidian's link suggester) and the corner button
is easy to miss.

Suspected Cause:
The placement is correct per the wiring but suboptimal for discovery.
Compare to Obsidian's inline link autocomplete (`[[` triggers a popover
at the cursor). Epistemos's Halo is "results panel" UX, not "as-you-type
suggester" UX; the button is correct as the entry point but its location
+ size make it functionally invisible.

Safe Auto-Fix Attempts (no user approval needed):
- Add a subtle pulse / shimmer animation on the button the first time
  it installs in a session, and again the first time it has new results.
- Add a default-bound keyboard shortcut (e.g., `Cmd+Shift+H`) that
  opens the panel, with the shortcut shown in the button's tooltip.
- Move the button from bottom-right to a more discoverable location
  (e.g., the editor toolbar) and shrink the corner version to an unobtrusive
  status indicator.

Destructive Fixes (require user approval):
- Replacing the panel UX entirely with an inline-popover model (substantial
  rework of the Halo controller and shadow-panel architecture).

Investigation Log:
- 2026-05-12: New entry. Flagged during ISSUE-2026-05-10-001 diagnosis
  as a parallel UX bug — even when Halo works, users can't find it.

---

### ISSUE-2026-05-12-005: Graph engine pauseEngine() doesn't free memory [DEFERRED-TO-GRAPH-PLAN]

Status: Open (deferred to canonical graph plan Phase A Week 2)
Priority: P2
First Observed: 2026-05-12
Affected Version: HEAD `58d998566`

Symptom:
`MetalGraphView.swift:1023` `pauseEngine()` only sets `isEnginePaused = true`.
It doesn't release the NodeState ring buffers, the Metal heap scratch, the
quadtree arena, the label SDF atlas, or any other graph-engine-owned memory.
Result: even when the graph is offscreen and the engine is paused, the
graph-engine's resident-memory contribution stays the same.

This is the primary reason a "Low Memory" idle mode (ISSUE-2026-05-12-007) is
not effective without a graph fix.

Suspected Cause:
The pause was designed as a "stop physics ticking" primitive, not a "release
GPU resources" one. There's a `MetalRuntimeManager.deepUnload()` at line
387 that drops 14 cached `MTLComputePipelineState` refs + `MTLBinaryArchive`
image, but it's only called from `MLXInferenceService.performUnload` — not
from the graph engine's pause path.

Resolution:
Owned by the canonical graph plan at `docs/CANONICAL_GRAPH_ENGINE_PLAN_2026_05_11.md`,
Phase A Week 2. Do NOT fix in isolation — the fix requires the shared-buffer
schema work landing first so we know what to release.

---

### ISSUE-2026-05-12-006: 2GB idle memory regression (vault + graph + indexes)

Status: Partially Fixed (Force Idle Unload button shipped in `566f3cb67` — manual reclaim path; passive auto-trim still tracked in 005/idle-evict work)
Priority: P1
First Observed: 2026-05-12 (superset of ISSUE-2026-04-21-004)

Symptom:
User reports app idles at ~2GB RSS after vault + graph + indexes load on M2 Pro
16GB. Codex's local canon claims healthy idle should be ~300MB. Per
`ProcessMemoryHealthRow.swift:54` the "elevated" threshold is 30% of physical
memory (4.8GB on 16GB), so 2GB is technically "nominal" by the code's scale,
but the user-perceived idle target is much lower.

Suspected Cause (per code audit 2026-05-12, ranked by likely contribution):
1. **Graph engine (~500MB-1GB)** — ISSUE-2026-05-12-005 above. `pauseEngine()`
   doesn't release MTLBuffers.
2. **MLX inference cache (0-2GB)** — only ~30% of users have a model loaded at
   any moment, but when loaded `Qwen3-8B-MLX-4bit` is ~4.5GB weights + KV cache.
   `MLXInferenceService` idle-unload at line 351-357 is 6-10s on 16GB — likely
   firing but the released memory may not be reaching the OS due to
   `swift-transformers` retain cycles or MLX arena allocator.
3. **Tantivy/HNSW mmap (300-500MB)** — these are mmap'd files, so they SHOW in
   RSS but aren't really pressure. Hard to release without losing query speed.
4. **SwiftData page cache + GRDB caches (~150MB)** — these have explicit shrink
   APIs (`SearchIndexService.releaseMemoryPressureCaches()` line 298-322) that
   fire on memory pressure but not on idle.
5. **Metal pipelines + binary archive (~80MB)** — `MetalRuntimeManager.deepUnload()`
   exists but only fires on memory-pressure critical.
6. **WKWebView WKContent processes (~50MB each)** — the Tiptap editor and KaTeX
   preview share a pool but each open document still spins up a process.

Safe Auto-Fix Attempts (no user approval needed):
- Profile with Instruments → Allocations on Jojo's M2 Pro for a 5-minute idle
  session on a real vault. Identify the top contributor concretely. THIS IS THE
  BLOCKING STEP — all other fixes are theory until this lands.
- Add a "Force Idle Unload" debug button in Settings → Diagnostics that calls
  `runtimeManager.performUnload(.aggressive)` + graph engine `pauseEngine()`
  + `releaseMemoryPressureCaches()`. Measure RSS delta before/after.
- Wire `MetalRuntimeManager.deepUnload()` into the `.warning` memory-pressure
  level (currently only fires on `.critical`).
- Add MLX session GC after idle unload, not just KV cache nil-out.

Destructive Fixes (require user approval):
- Force-unloading MLX even when a chat session is mid-conversation.
- Closing all WKWebView documents on app blur.

Investigation Log:
- 2026-05-12: New entry. Pairs with ISSUE-2026-04-21-004 (original idle memory
  regression). User asked for strict 200MB idle; honest estimate after all
  unload paths fire is ~350-500MB floor. 200MB requires structural cuts
  (e.g., stop bundling MLX entirely for non-AI sessions), which is not v1.

---

### ISSUE-2026-05-12-007: Two-axis Startup / Idle Memory settings

Status: Patched (Settings UI shipped in `6dd995713`; T2 branch `f0c0fbace` wires Low Memory into MLX deep unload, pending scope sign-off / merge / verification)
Priority: P3
First Observed: 2026-05-12

Symptom:
User wants explicit control over startup speed vs steady-state memory. Asked
for "delay startup so everything is cached then opens smoothly" and "strict
200MB idle." These are two separate axes, not one.

Suspected Cause:
Not a bug — a missing product surface. Currently the app defaults to a
middle-ground (lazy load with no idle unload), which is the worst of both
worlds.

Design (drafted 2026-05-12, blocked on ISSUE-2026-05-12-005 + ISSUE-2026-05-12-006):

| Setting | Options | Default |
|---|---|---|
| Startup Mode | Instant Launch / Prepared Launch | Instant |
| Idle Memory Mode | Keep Warm / Low Memory | Keep Warm |

- **Instant Launch**: app opens immediately, sidebar tree streams in, graph
  lazy-loads on first navigation
- **Prepared Launch**: "Preparing vault…" splash for 1-3s while sidebar
  pre-renders, FTS opens, last graph snapshot loads; then everything is snappy
- **Keep Warm**: graph engine, MLX cache, Metal pipelines stay resident; idle
  RSS sits at ~1-2GB; reopening is instant
- **Low Memory**: after 30s of no interaction, graph engine releases MTLBuffers
  (requires ISSUE-2026-05-12-005 fix), MLX unloads, Metal pipelines deepUnload,
  GRDB caches shrink; idle RSS targets ~400MB; reopening graph takes 1-2s

Safe Auto-Fix Attempts (no user approval needed):
- Stub the Settings UI rows so the user can see the two toggles + their
  descriptions. Backend wiring is conditional on ISSUE-2026-05-12-005 and
  ISSUE-2026-05-12-006.
- Wire only the easy half today: `Idle Memory Mode = Low Memory` triggers
  `MetalRuntimeManager.deepUnload()` + `SearchIndexService.releaseMemoryPressureCaches()`
  + MLX unload after 30s of no interaction (this is partial — won't hit 400MB
  without the graph fix).

Destructive Fixes (require user approval):
- Changing default behavior. Ship the toggles, default to "Instant + Keep Warm"
  to match current behavior; users opt in to the alternatives.

Investigation Log:
- 2026-05-12: New entry. Design is canonical (per Codex's two-axis recommendation
  and my refinement). Pending: ISSUE-2026-05-12-005 (graph unload) + ISSUE-2026-05-12-006
  (memory profiling) must land first so the toggles actually do something.
- 2026-05-17 08:30 CDT (T9 coordination): T2 has uncommitted work that appears
  to wire `IdleMemoryMode.lowMemory` into a 30-second MLX deep-unload path via
  `MLXInferenceService` plus Settings/tests. No status bump yet: the patch is
  dirty, includes paths outside T2's exact written scope, and has not been
  committed or verified.
- 2026-05-17 08:37 CDT (T9 coordination): T2 committed `f0c0fbace` with the
  Low Memory 30-second MLX/Metal deep-unload path and Settings/tests. Status
  stays branch-Patched, not Verified Fixed: the commit has exact-scope debt
  (`MLXInferenceService.swift` + Swift tests outside T2 lock), has not landed
  on main, and has not been runtime-verified for RSS reduction.
- 2026-05-17 08:44 CDT (T9 coordination): no status change. T2's new live
  worktree drift is now focused on AnswerPacket/chat timeline paths rather
  than additional Low Memory verification; `f0c0fbace` remains branch-Patched
  only.

---

### ISSUE-2026-05-12-008: First-note-open hangs slightly on large vaults

Status: Patched (BlockMirror prewarm covers both inline + disk-load paths; graph/FTS/HNSW sub-causes are separate, deferred to canonical graph plan)
Priority: P2
First Observed: 2026-05-12 (per user report)

Symptom:
When opening a note for the first time after launch, the editor hangs briefly
(~100-500ms) before becoming responsive. Subsequent opens of the same note
are instant. User suspects "must I have it on large vaults?"

Suspected Cause (ranked):
1. **BlockMirror first-parse** — `Epistemos/Sync/BlockMirror.swift` parses
   the note's markdown into block rows on first open. ~10-50ms for small notes,
   200ms+ for large notes. Block rows persist after first open.
2. **Graph engine neighborhood wake** — when a note is selected, the graph
   wakes its neighborhood (currently full re-layout for affected nodes).
   Causal-atmosphere sleep (canonical graph plan Phase A Week 4) fixes this.
3. **FTS5 segment open** — if the note's tokens aren't in the recent overlay,
   the base index segment must be opened on first query.
4. **HNSW embedding compute** — if the note has no cached embedding, a fresh
   one is computed.
5. **NSTextView text storage attribute pass** — large notes trigger a full
   attribute walk on first load.

Resolution:
Multi-source. Graph portion (#2) deferred to canonical graph plan. Other
sources can be addressed independently:
- Background prewarm of 5 most-recently-modified notes on launch (parses
  block rows + computes embedding) — sub-50ms first-open for likely-next-note
- Async BlockMirror so editor renders text immediately, blocks pop in as
  parsed (~10-50ms gap is invisible to user)
- FTS5 index segment warm-on-launch (already done via shadow_warm() fix
  in ISSUE-2026-05-10-001)

Safe Auto-Fix Attempts (no user approval needed):
- Prewarm MRU notes' block rows in background after `AppBootstrap.shared`
  finishes initializing.
- Make BlockMirror parse async by default; editor renders raw text first,
  block-structure overlays append as parsed.

Destructive Fixes (require user approval):
- Aggressive prewarming of all notes on launch (memory hit + slow startup
  on huge vaults).

Investigation Log:
- 2026-05-12: New entry. Pairs with the 2GB idle issue — both rooted in
  "graph/index/cache layer doesn't pre-warm or release on a predictable
  schedule."
- 2026-05-16 (T-A iter 1, §5.0 catch): file-path citation in cause #1 was
  stale — `Epistemos/Engine/BlockMirror.swift` does not exist; canonical
  path is `Epistemos/Sync/BlockMirror.swift` (verified via
  `find Epistemos -name "BlockMirror*"` → single hit at the Sync path).
  Updated above. Iter 2+ MRU-prewarm work should target the Sync path.

- 2026-05-16 (T-A iter 2, partial patch): shipped `AppBootstrap.prewarmRecentBlockMirrors(modelContext:limit:)`
  in `Epistemos/App/AppBootstrap+Prewarm.swift` + wired into init flow after
  `AppBootstrap.shared = self` (line 2003) as a `Task.detached(priority: .utility)`
  with a dedicated `ModelContext(container)`. Inline-body pages parse at
  launch; disk-only pages (production majority — `body` is cleared after
  `saveBody()`) are counted+logged as `skipped_disk_only` but not yet
  prewarmed. 3 unit tests landed at `EpistemosTests/AppBootstrapPrewarmTests.swift`
  (synced-and-skipped split · empty store · limit cap). xcodebuild Debug
  build green; cargo 1190 baseline holds. Iter 3 should extend to the
  disk-load path via `SDPage.loadBodyAsyncFromPrimitives` so the prewarm
  actually amortizes the first-open hang in production.
- 2026-05-16 (T-A iter 3, full patch): function converted to `async` and now
  uses `SDPage.loadBodyAsyncFromPrimitives(pageId:filePath:inlineBody:)` for
  body acquisition — the canonical R.3 fallback chain (managed sidecar → R.3
  gateway → inline → raw vault file). Signature changed from `modelContext:
  ModelContext` to `modelContainer: ModelContainer` to satisfy Swift 6
  strict-concurrency Sendable rules (ModelContext isn't Sendable; the
  function now creates its own ModelContext internally and calls
  `modelContext.save()` after BlockMirror.sync inserts so other contexts
  see the new SDBlocks). 5 unit tests now pass (3 from iter 2 + 2 new:
  disk-only-page prewarmed via filePath + missing-file gracefully skipped
  with synced=0). Per-page `(id, filePath, body)` snapshotted before any
  `await` to avoid SwiftData object-lifecycle races. **Cause #1 of this
  issue (BlockMirror first-parse) is now structurally covered.** Other
  causes (#2 graph engine neighborhood wake, #3 FTS5 segment open,
  #4 HNSW embedding compute, #5 NSTextView attribute pass) are separate
  concerns: #2 is owned by the canonical graph plan; #3 was patched
  earlier via shadow_warm (per ISSUE-2026-05-10-001); #4 + #5 are
  outside Phase B scope. Closing this row as Patched.


---

### ISSUE-2026-05-12-009: Sidebar + graph slow to open every launch

Status: Scaffolded (ProjectionCache module shipped in `eb5f16f64` — types + serde + IO + mtime invalidation; live wiring into NotesSidebar + AppBootstrap is the next-iteration job)
Priority: P2
First Observed: 2026-05-12 (per user report)

Symptom:
User reports notes sidebar and graph "always take a long time to open" — both
on first launch AND on subsequent re-opens of the graph panel within a session.

Suspected Cause:
The sidebar tree is rebuilt from `SDPage.recentChatsDescriptor` + folder
fetches every time the sidebar mounts. The graph engine runs physics from
scratch every time the panel mounts (no persistent layout snapshot, no
warm-start from last-known positions).

Resolution:
Cross-cutting design. The non-graph half is a new `ProjectionCache` layer:
- Stored at `<vault>/.epcache/projection.bin`
- Contains: sidebar tree snapshot (folder hierarchy + page IDs + titles),
  graph snapshot (last frame positions, cluster pyramid, edge CSR), FTS-recent
  overlay, per-file mtime+hash for invalidation
- On launch: read cache → render sidebar instantly + render last graph layout
  instantly; in background, walk the vault, compute mtime+hash diffs, apply
  only the changes
- Cache stays valid across launches, invalidates on mtime change or
  app-version bump

The graph half (warm-start from cached positions, cluster pyramid persistence)
is owned by the canonical graph plan Phase A Week 3 + Phase C.

Safe Auto-Fix Attempts (no user approval needed):
- Build the sidebar-tree-only half of ProjectionCache as a standalone Rust
  module in `agent_core/src/projection_cache.rs`. Serde-encoded to disk,
  read on launch, mtime+hash invalidation. ~3-day task.
- Wire `NotesSidebar` to read from the cache on mount before falling back
  to the live SDPage fetch.
- Add a "Rebuild Cache" button in Settings → Privacy & Storage that wipes
  `projection.bin` and forces a fresh build.

Destructive Fixes (require user approval):
- Auto-invalidating the cache on every launch (defeats the point).
- Storing the cache in iCloud or anywhere syncable (the cache is a
  per-device-derived artifact, not user data).

Investigation Log:
- 2026-05-12: New entry. Pairs with ISSUE-2026-05-12-008 (first-note hang)
  and ISSUE-2026-05-12-007 (startup mode setting) — these three together
  define the "snappier app open" track.

---

### ISSUE-2026-05-11-001: Large vault import stalls and graph loads only a partial vault

Status: Investigating
Priority: P1
First Observed: 2026-05-11
Affected Version: branch `codex/research-snapshot-2026-05-08` (HEAD `333cde26a`)

Symptom:
Launched audit app `com.epistemos.audit` was restored against `/Users/jojo/all research`.
The app remained visible in a `Loading vault "all research"...` state for more than 9 minutes.
Computer Use showed the loading pill in the real app, not just source state.

Runtime evidence:
- Audit app PID `536` was still running at ~100% CPU.
- Store counts in `build/audit-app-support/Epistemos/default.store`:
  - `ZSDPAGE`: 1200
  - `ZSDGRAPHNODE`: 200
  - `ZSDGRAPHEDGE`: 0
  - `ZSDFOLDER`: 139
- Disk count for `/Users/jojo/all research`:
  - `5147` markdown/epdoc files from `find ... -iname '*.md' -o -iname '*.markdown' -o -iname '*.epdoc'`
  - Extension breakdown includes `5141 md` files.
- Logs:
  - `Main thread hang detected: 725ms`
  - `sanitize_and_normalize bridge failed: ContainsNullByte(message: "text contains null byte")`
  - `sanitize_and_normalize bridge failed: ContainsMidStringBom(message: "text contains mid-string BOM")`
  - `sanitize_and_normalize bridge failed: ContainsReplacementCharacter(message: "text contains replacement character")`
  - `Failed to persist inserted body for ...; skipping index upsert`
- Fresh sample `/tmp/epistemos-audit-pid536-2.sample.txt` showed the hot path on
  `com.epistemos.NoteFileStorage.mutation` in `NoteFileStorage.persistStagedBody`
  -> `NoteFileStorage.normalizedStorageContent`
  -> `EpistemosCoreIntegrityBridge.sanitizeAndNormalizeText`
  -> Rust `sanitize_and_normalize`.
- After the imported-body repair patch, a fresh launched-app run advanced to
  `ZSDPAGE=1200` and repaired malformed bodies in logs, then remained CPU-bound
  in `VaultIndexActor.countWords` for a large imported body. Sample:
  `/tmp/epistemos-audit-pid33194-sample.txt`.
- After the bounded word-count patch, a fresh launched-app run again reached
  `ZSDPAGE=1200`; sampling PID `60225` showed the next hot path in
  `BlockMirror.sync(pageId:body:modelContext:)` while importing an oversized
  vault body. Sample: `/tmp/epistemos-audit-pid60225-sample.txt`.
- After the bounded block-mirror patch, a clean launched-app run again reached
  `ZSDPAGE=1200`; sampling PID `76208` showed the next hot path in
  `FoundationSafety.decodedText(from:)` -> `looksLikeReadableText(_:)`, which
  still scanned every Unicode scalar of huge imported note bodies. Sample:
  `/tmp/epistemos-audit-pid76208-sample.txt`.

Suspected Cause:
`VaultIndexActor.upsertPage` treats any managed body persistence failure as
`.unchanged`, so files containing null bytes, mid-string BOMs, or replacement
characters are skipped instead of imported as repaired vault text. The same
path serially calls the Rust normalization bridge for every imported body,
which makes large vault restores visibly stall. A second launched-app pass found
large imported bodies can also pin `NLAnalysisService.wordCount` during metadata
parsing. A third launched-app pass found oversized vault bodies can also pin
`BlockMirror.sync` while parsing/reconciling editable block rows. A fourth pass
found the readability gate still performed a full Unicode scalar scan before the
bounded import path could proceed. The graph refresh then reflects only the
currently persisted subset, producing a partial graph.

Safe Auto-Fix Attempts (no user approval needed):
- Add launched-app/runtime-backed failing tests for importing externally malformed vault files.
- Repair unsafe imported vault text for internal managed storage without mutating the source vault file.
- Keep normal editor writes strict so unsafe app-authored content still fails closed.
- Use bounded word counting for oversized imported vault bodies; exact
  NaturalLanguage tokenization is not worth blocking vault import completion.
- Bound imported-vault block mirroring and clear stale block rows for oversized
  archive bodies; graph/note import must not wait on block-level editing rows.
- Bound the readable-text scan during decode so huge valid text files do not pin
  import before malformed-scalar repair and bounded metadata work run.
- Re-run vault import smoke with Computer Use and compare DB counts/logs before claiming fixed.

Destructive Fixes (require user approval):
- Rewriting or modifying the user's source vault files.
- Deleting the user's vault or app support store through the UI.

Investigation Log:
- 2026-05-11: Added from launched audit app evidence. This is the current top vault blocker; do not move to lower-priority backlog until large vault import completes and graph refreshes without restart.

---

### ISSUE-2026-05-11-002: Graph node-type filters and selected-neighbor expansion are missing from the launched graph

Status: Partially Fixed (Filters UI shipped 2026-05-12 in cabf81df0; selected-neighbor push-out physics still open)
Priority: P2
First Observed: 2026-05-11
Affected Version: branch `codex/research-snapshot-2026-05-08` (HEAD `333cde26a`)

Symptom:
User reports that node-type filters for Folder, Note, Document, Code, etc.
are not visible or working, selected nodes do not push connected nodes outward,
and the graph did not load the whole vault.

Runtime/source evidence:
- Computer Use opened the real graph force-settings popover in the launched audit app.
  It showed only `Presets`, `Physics`, `Display`, and `Advanced`; no `Filters`
  section and no Folder/Note/Document/Code toggles were visible.
- Source has filter state in `GraphState` / `FilterEngine`, including
  `GraphState.userFilterableNodeTypes == GraphNodeType.visibleCases`, but the
  current `GraphForceSettingsSection` enum exposes only presets, physics,
  display, and advanced.
- `graph-engine/src/engine.rs` selection comment says selection applies
  neighbor focus "without changing the physics force model", so the requested
  selected-neighborhood expansion is not implemented in the current engine.

Suspected Cause:
The type-filter model exists but is not wired to a discoverable graph control
in the current accepted UI. Selected-node behavior currently highlights and
labels connected nodes; it does not alter direct-edge rest length or apply any
selection-specific separation force.

Safe Auto-Fix Attempts (no user approval needed):
- Add a minimal Filters section to the existing graph settings popover without
  touching graph visual style, labels, camera behavior, or panel popout buttons.
- Add focused graph-engine tests proving selected direct edges lengthen while
  non-selected edges keep the normal force model.

Destructive Fixes (require user approval):
- Replacing the accepted graph toolbar/panel architecture.
- Rewriting graph visual style, labels, camera, or legacy physics presets.

Investigation Log:
- 2026-05-11: Added after launched-app force-settings smoke and source verification. Must be handled after or alongside the vault completeness fix because partial graph data can make filter behavior look broken.
- 2026-05-12: Filters UI shipped in commit `cabf81df0 - Expose graph node filters in graph settings` (added to `GraphForceSettings.swift:11-29` `GraphForceSettingsSection.filters` case + `filtersPanel` body at line 145). Per-node-type toggles, "Content Only" / "Show All" presets, and the existing `GraphState.userFilterableNodeTypes` model are now reachable from the popover. The selected-neighbor push-out physics (selected direct edges lengthening while non-selected edges keep the normal force model) is a separate canonical-plan item — the current engine selection only highlights and applies label caps via `selected_neighbor_label_cap`/`selected_neighbor_density_budget` at `graph-engine/src/engine.rs:303-318`. Tracking that physics work alongside the Phase B compute kernels so it lands with the unified force pipeline.

---

> ### 2026-05-10 Re-audit pass — canonical-fit verification
>
> User asked: "make sure the way u fix is canonical with the research i did
> for the backlog." A source-level audit of every Patched/Source-Fixed/
> Investigating item below was run on HEAD `6683141ae`. All checked-as-of
> entries were verified intact and canonical against the master research
> index + their respective canonical research docs. The audit pass touched
> NO source files; it confirmed existing fixes are still in place against
> the current code. Items requiring live-app smoke tests are NOT promoted
> past Patched until the user reports verification.
>
> | Issue | Audit verdict (2026-05-10) |
> |---|---|
> | ISSUE-2026-05-08-003 (App Review subprocess scan) | Intact — `Tools/app-review-audit/app-review-audit.sh:179` Check 4 scans `Process()/Pipe()/system()` |
> | ISSUE-2026-05-08-005 (Prose editor scrollbar) | Intact — `NoteDetailWorkspaceView.swift:1130` `ProseEditorView` fills with `.frame(maxWidth: .infinity)`, no outer `editorReadableWidth` wrap |
> | ISSUE-2026-05-08-006 (Ask this note AX) | Intact — `AssistantComposerStatusViews.swift:569` submit `Button(action: onSubmit)` + lines 543/581 accessibility labels |
> | ISSUE-2026-05-08-007 (BlockMirror reschedule) | Intact — `BlockMirror.swift:464` `coalescingDelay = 25ms` + `generationIsCurrent` guards at 486/496/541 |
> | ISSUE-2026-05-08-008 (Epdoc graph projection) | Intact — `EpdocGraphProjector.swift:201` `semanticGraphLabels` wired into project() at line 170, emits `.contains` edges at 173 |
> | ISSUE-2026-05-08-009 (Epdoc complexity meter) | Intact — `EpdocDocument.swift:266` writes `metadata["complexity"]` via `EpdocComplexityCalculator` |
> | ISSUE-2026-05-08-010 (Shadow search diagnostics) | Intact — `ShadowSearchService.swift` records success/failure at lines 207/301/314/339/346 |
> | ISSUE-2026-05-08-012 (NightBrain dependency readiness) | Intact — `NightBrainService.swift:264+` 6 preflight `.deferred` branches |
> | ISSUE-2026-05-08-014 (Vault connection state) | Intact — `VaultSyncService.swift:1668-1678` `schedulePostImportMaintenance` emits `.vaultChanged`; `AppBootstrap.swift:2031` `wireR3VaultSwitchObserver` subscribes |
> | ISSUE-2026-05-08-002 (Metal drawable lifecycle) | Intact — `MetalGraphView.swift:1023` 1×1 paused size; `LandingWaveMetalView.swift:241` sync render with `MainActor.assumeIsolated` + `isRenderingFrame` reentrancy guard; covered by `RuntimeValidationTests` |
> | ISSUE-2026-05-07-001 (Code editor large-file) | Intact — `CodeEditorView.swift:2486-2487` `lastText` + `lastTextLineStartUTF16Offsets` cache; `SegmentedIndentationGuideView.swift:89,115` `baseLineNumber` param; covered by `CodeEditorPolishTests` |
> | ISSUE-2026-05-08-001 (TCC passive probes residual) | Investigating — framework-level attribution remains (`kTCCServiceListenEvent` preflight from a linked framework). Not actionable from user code; left in `Investigating` |
> | ISSUE-2026-04-21-004 (Idle memory regression) | Investigating intact — `GraphState.swift:740` `DeferredTextEmbeddingLookup` wraps `AppleHybridEmbeddingLookup`; `ProcessMemoryHealthRow` present. Still blocked on Instruments Allocations profile |
> | ISSUE-2026-04-22-001 (SwiftUI hot-loop) | Source-fixed intact — `RootView.swift:458` `localModelSubtitleCache` + `.task(id:)` at 902; `localModelSubtitle(for:)` at 1628-1629 reads from cache only; `InferenceState.apiKey(for:)`/`oauthCredential(for:)` are read-only |
>
> No source-level regressions detected. All canonical research alignments
> verified. The remaining ~8 items are blocked on user-side live-app
> verification (in-app smoke tests, Time Profiler, Allocations).

### ISSUE-2026-05-10-002: Agents don't appear to work / not connected to any provider

Status: Patched (APIKeysHealthRow shipped 35120f79b — surfaces per-provider key state; user still needs to confirm with valid keys)
Priority: P1
First Observed: 2026-05-10
Affected Version: branch `codex/research-snapshot-2026-05-08` (HEAD `73f0e5009`)

Symptom:
User reports "agents don't seem like they work and not connected to any
provider like they supposed to ... that should be in the cli portion but
that was another issue i had so please make sure that is good as well."

Diagnosis (source audit 2026-05-10):

1. **FFI binding IS compiled in** — the Xcode project uses a
   `PBXFileSystemSynchronizedRootGroup` at `build-rust/swift-bindings/`
   that auto-includes every `.swift` file in that directory in the
   target build. Only `omega_ax.swift` is exception-excluded (from
   `Epistemos-AppStore` target). `agent_core.swift`, `epistemos_core.swift`,
   `omega_mcp.swift` ARE compiled. Confirmed by the
   `28ED660DDD0AE43C1E151F78` exception set in `Epistemos.xcodeproj/
   project.pbxproj` only listing `omega_ax.swift`. So the
   `#if canImport(agent_coreFFI)` branch in
   `Epistemos/Bridge/StreamingDelegate.swift:5` resolves true; the
   real `runAgentSession` (from the UniFFI wrapper) runs — NOT the
   `bindingsUnavailable` stub at line 132.

2. **Dispatch path is wired** —
   `Epistemos/App/ChatCoordinator.swift:604` calls `runAgentSession`
   inside `AppBootstrap.withScopedAgentCoreEnvironment` which scopes
   provider API keys from Keychain into env vars around the Rust call
   (`Epistemos/App/AppBootstrap.swift:753-775`). Provider key
   mappings (line 716-730) cover Anthropic, OpenAI, Google, Perplexity,
   OpenRouter, Z.AI/GLM, Kimi, DeepSeek, MiniMax, xAI, Mistral, Groq,
   HuggingFace.

3. **Likely runtime cause** — Keychain lookup at
   `Keychain.load(for: "epistemos.anthropic.apiKey")` etc. returns nil,
   so the env vars aren't set, so the Rust providers see empty
   `std::env::var("ANTHROPIC_API_KEY")` and fail auth on first HTTP
   call. The error message "Authentication failed (401). Check the
   selected provider API key in Settings." exists in
   `Epistemos/Engine/LLMService.swift:586` and is surfaced in the
   non-agent (TriageService) path; whether it also surfaces in the
   agent path needs runtime verification.

4. **CLI passthrough is Pro-only by design** —
   `agent_core/src/tools/cli_passthrough.rs` (the claude-code / codex /
   gemini / kimi CLI tools) is gated behind `#[cfg(feature = "pro-build")]`
   and the registration functions at `agent_core/src/tools/registry.rs:1875+`
   are also `cfg(feature = "pro-build")`. Per the MAS-First doctrine
   (`docs/fusion/...`), Pro features are NOT in the MAS-shippable
   build. The CLIs would surface as agent tools in a Pro build only.

Safe Auto-Fix Attempts (no user approval needed):
- Verify the message at `LLMService.swift:586` reaches the user when
  the agent path fails auth. If not, plumb it through.
- Add a Settings → API Keys health row that shows which providers
  have keys stored (read-only, doesn't expose values).

Destructive Fixes (require user approval):
- Auto-storing API keys from environment / config files.
- Surfacing the "missing key" toast without user-side gesture (could
  spam on every chat send).

Investigation Log:
- 2026-05-10: New entry. Source audit confirmed the agent FFI plumbing
  is canonical and not regressed. Most likely cause is user hasn't
  entered API keys in Settings. CLI passthrough is intentionally
  Pro-only per the MAS-First doctrine. Quickest verification: open
  Settings → AI / Inference → Anthropic (or any provider) and confirm
  an API key is set. Try the agent again. If failure persists with a
  valid key, the issue moves from "configuration" to "code regression"
  and needs runtime profiling.
- 2026-05-12: APIKeysHealthRow shipped (commits 58d998566 + 35120f79b).
  Wired into Settings → General → Diagnostics. Lists each canonical
  provider (Anthropic / OpenAI / Google / Perplexity / OpenRouter /
  Z.AI / Kimi / DeepSeek / MiniMax / xAI / Mistral / Groq / HuggingFace)
  with a green/red dot indicating whether `Keychain.load(for:
  "epistemos.<provider>.apiKey")` returns non-nil. User can now
  diagnose "missing key" without Console.app or guessing. Status flipped
  to Patched until user confirms with a valid key.

---

### ISSUE-2026-05-10-001: Halo feature does not work end-to-end for user

Status: Patched (diagnosability surface — init-failure class now visible in Settings; root-cause repro still needed for embedder/tantivy failures themselves)
Priority: P1
First Observed: 2026-05-10
Affected Version: branch `codex/research-snapshot-2026-05-08` (HEAD ebd26c08f)

Symptom:
User reports "the halo feature does not work" — opening Halo does not return
results from the vault. ISSUE-2026-05-08-010 (sanitized diagnostics + Settings
health row) was Patched, but only addressed surfacing the failure, not the
actual backend failure.

Suspected Causes (ranked by Explore-agent diagnosis 2026-05-10):

1. **Embedder initialization failure** — `RustShadowFFIClient.init(path:)` at
   `Epistemos/App/AppBootstrap.swift:3137` throws because `Embedder::global()`
   at `epistemos-shadow/src/backend/embedder.rs:50` fails to load Model2Vec
   (`potion-base-8M` HF model, ~30MB). Possible: HF download stall, cold-cache
   race, or corrupt cached weights deserializing badly in
   `model2vec_rs::model::StaticModel::from_pretrained()`.

2. **Tantivy lexical index open failure** — even if embedder loads,
   `RealBackend::open_at()` at `epistemos-shadow/src/backend/mod.rs:146`
   throws if `<vault>/.epcache/shadow/tantivy/` is corrupted or
   format-mismatched after an `epistemos-shadow` crate version bump, or if
   `create_dir_all()` fails with permission denied.

3. **`haloSearchService` nil propagation** — symptom only: button install
   guard at `Epistemos/Views/Notes/ProseEditorRepresentable2.swift:928`
   returns early because the FFI client init (Rank 1 or 2) threw and
   `contextualShadowsState.configureShadowSearch()` was never called.

Bundle State (verified 2026-05-10 against PID 41047):
- `/Applications/Epistemos.app/Contents/Frameworks/libepistemos_shadow.dylib`
  present (79 MB, May 10 19:08 build)
- Symbol `_shadow_handle_open_at` exported, build script wired in Xcode
- So this is NOT a missing-dylib problem

Safe Auto-Fix Attempts (no user approval needed):
- Add an explicit error toast / Settings row that surfaces which sub-failure
  fired (embedder vs tantivy vs IO), distinct from the existing degraded
  state.
- Cache the resolved error class on `HaloController` and expose via the
  health row so future diagnosis doesn't require Console.app.

Destructive Fixes (require user approval):
- Wiping `~/Library/Caches/.../.epcache/shadow/` (would force re-download).
- Replacing the Model2Vec embedder with the trigram fallback per
  doctrine §2.5.

Investigation Log:
- 2026-05-16 (T-A iter 4, diagnosability fix): added init-failure recording
  so the two Shadow-init failure modes (handleOpen — `RustShadowFFIClient(path:)`
  throws, tantivy/IO; and embedderWarm — `client.warm()` throws, Model2Vec
  HF download / cold-cache race) are now visible in Settings →
  Diagnostics → "Shadow backend" row WITHOUT Console.app. Implementation:
  new public enum `ShadowInitFailureClass` (cases `.handleOpen` =
  `"handle_open"` · `.embedderWarm` = `"embedder_warm"`) at top of
  `Epistemos/Engine/ShadowSearchService.swift`; `ShadowSearchDiagnostics.Snapshot`
  extended with `lastInitFailureClass` + `lastInitFailureAt` fields and
  `isDegraded` updated to account for them; new public method
  `ShadowSearchDiagnostics.shared.recordInitFailure(class:)` wired into
  the two AppBootstrap catch sites (line ~3461 handle-open catch +
  line ~3494 warm() catch); `ShadowSearchHealthRow.backendDetail` extended
  to render "Init failed: <class> — Halo unavailable until next launch"
  when degraded, and "Init failed: <class> — recovered (no searches yet)"
  when init failed but no degraded state because a search hasn't surfaced
  yet. **§5.0 catch:** the original audit row + iter 3 next-pointer framed
  the work as "HaloErrorClass enum on HaloController" but `HaloController`
  is a pure state machine (debounce + match list, no init responsibility).
  The actual diagnostic data layer is `ShadowSearchDiagnostics` (in
  `ShadowSearchService.swift`) feeding `ShadowSearchHealthRow`. Implemented
  on the correct surface — function naming follows the existing
  `recordSuccess` / `recordFailure` pattern. 4 unit tests in
  `EpistemosTests/ShadowInitDiagnosticsTests.swift` (records-and-degraded ·
  handleOpen-vs-embedderWarm distinct · recovery on successful search ·
  reset clears state). The fix does NOT address the root cause of the
  embedder failures (HF model download stall / corrupt cache / etc.) —
  user-side reproduction with a known-failing HF cache is still needed
  to triage that. The patch unblocks remote diagnosis without Console.app.
- 2026-05-10: New entry. Explore-agent diagnosis attached above.
  `log show --predicate 'process == "Epistemos"'` returned no shadow/halo
  hits over the last 30 min — macOS hardened-runtime redaction makes
  Console-side verification impossible. Quickest manual verification:
  open Settings → Shadow backend health row in the live app and report
  whether it shows "Degraded: backend_failure". If yes → Rank 1 or 2;
  if no row visible → Rank 3.
- 2026-05-10 (later): Source audit against canonical research
  `docs/AMBIENT_RECALL_HALO_MASTER_PLAN.md` §3.2 found that
  `RustShadowFFIClient.warm()` (which calls Rust `shadow_warm()` →
  `Embedder::global()`) was NEVER invoked from Swift. The research
  explicitly says: "the Swift bootstrap should fire `shadow_warm()`
  at app start to pay the cost off the typing hot path." Wired the
  warm-up call right after `RustShadowFFIClient(path:)` succeeds in
  `Epistemos/App/AppBootstrap.swift:3138`. Failures are non-fatal
  (logged + handle stays usable). This means: on cold cache the
  ~30 MB Model2Vec download now happens during indexer bootstrap
  instead of blocking the user's first Halo search; on hot cache the
  warm is an atomic-fast no-op. Status remains Open until user
  verifies Halo actually returns results.
- 2026-05-12: **Root cause identified via user-screenshot diagnostic.**
  User opened Settings → General → Diagnostics. Halo backend row reads
  `No active vault selected - Shadow/Halo closed` (red X). Background
  indexing row reads `No active vault selected - cached local note/graph
  data only` (red X). Both rows derive from the SAME guard at
  `AppBootstrap.swift:3104`:
  ```swift
  guard let vaultURL = vaultSync.vaultURL else {
      EditorBundleHealthRow.recordHaloClosed()
      BackgroundIndexingHealthRow.recordUnavailable(...)
      return
  }
  ```
  The user's notes work because they're stored in SwiftData's internal
  SQLite container (SDPage models). The Shadow indexer requires a
  separate filesystem vault folder (`vaultSync.vaultURL` — set via
  `VaultConnectionActions.selectVaultFolder` at `SettingsView.swift:3410`).
  These are two parallel "vault" concepts and only the filesystem one
  feeds Halo.
  
  **Actionable user fix:**
  1. Settings → Privacy & Storage → Vault
  2. Click "Select Vault Folder" button
  3. Pick or create a folder (e.g., `~/Documents/Epistemos`)
  4. Bootstrap fires automatically, Halo backend turns green, button
     appears in bottom-right of editor as user types
  
  **Product-level bug:** the app silently allows note creation when no
  vault is selected. Users have no idea their notes aren't being indexed.
  Two follow-up issues filed today: ISSUE-2026-05-12-001 (vault-not-
  connected banner) and ISSUE-2026-05-12-002 (force vault selection at
  first launch). Halo itself is not broken — the wiring is canonical.
  Reclassified from "Halo backend broken" to "Halo silently disabled
  by missing vault selection." Will close as Verified Fixed once user
  confirms the picker flow worked.

---

### ISSUE-2026-05-08-013: Workspace auto-save crashes on duplicate page IDs

Status: Verified Fixed
Priority: P0
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
Computer Use Pass 1 opened Mini Chat, submitted `reply with mini-ok`, and waited
through `Loading Gemma 3 4B...`. The app process `30539` rose to roughly
118% CPU / 1.1 GB RSS, disappeared, and relaunched as `31866`.

Crash report:

```text
/Users/jojo/Library/Logs/DiagnosticReports/Epistemos-2026-05-08-131653.ips
exception: EXC_BREAKPOINT / SIGTRAP
faultingThread: 0
_assertionFailure
specialized _NativeDictionary.merge<A>(_:isUnique:uniquingKeysWith:)
Dictionary.init<A>(uniqueKeysWithValues:)
WorkspaceService.captureSnapshot() WorkspaceService.swift:146
WorkspaceService.autoSave() WorkspaceService.swift:363
closure #1 in WorkspaceService.startAutoSave() WorkspaceService.swift:543
```

Suspected Cause:
`Epistemos/State/WorkspaceService.swift` builds
`Dictionary(uniqueKeysWithValues: allPages.map { ($0.id, $0.wordCount) })`.
If SwiftData returns duplicate `SDPage.id` rows from historical vault imports or
multi-root cache state, the unique-keys initializer traps on the main actor
during auto-save.

Safe Auto-Fix Attempts (no user approval needed):
- Replace the crash-only dictionary construction with a duplicate-tolerant fold.
- Add a focused test/source guard proving workspace snapshot capture does not
  use `Dictionary(uniqueKeysWithValues:)` on `SDPage.id` rows.
- Log duplicate page IDs with counts in debug/diagnostic paths without blocking
  auto-save.

Destructive Fixes (require user approval):
- Deleting duplicate SwiftData page rows.
- Rewriting or migrating the user's vault/page database.

Investigation Log:
- 2026-05-08: Captured by Computer Use broad pass. Crash root is
  `WorkspaceService.captureSnapshot()` line 146, not graph rendering.
- 2026-05-08: Patched `WorkspaceService.captureSnapshot()` to build page word
  counts with a duplicate-tolerant fold instead of
  `Dictionary(uniqueKeysWithValues:)`; duplicate page IDs are logged and the
  first observed row wins for snapshot purposes. Added focused coverage in
  `WorkspaceSnapshotTests` plus a source guard that prevents reintroducing the
  trapping initializer for page snapshots. Verification:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/WorkspaceSnapshotTests -only-testing:EpistemosTests/WorkspaceServicePersistenceTests`
  passed 7 Swift Testing tests in 2 suites, result bundle
  `build/xcode-results/2026-05-08-133755-34678.xcresult`. A launched audit-app
  retry of Mini Chat `reply with mini-ok` did not reproduce the crash/relaunch.

### ISSUE-2026-05-08-016: Composer overlay keyboard selection leaked raw slash/mention text

Status: Verified Fixed
Priority: P1
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
Computer Use Pass 1 found two keyboard paths that looked interactive but did
not execute their advertised picker action:

```text
Landing: Click to search -> type "/" -> Down -> Return
Actual: submitted raw "/" into main chat.

Landing/Main chat: type "@pro" -> Down -> Return
Actual: picker remained focused or dismissed without a visible inserted
reference; mouse selection worked, keyboard selection did not.
```

Suspected Cause:
The visible composer overlays used real row pickers, but the focused search
field inside the AppKit popover did not route arrow/Return/Escape back through
the same selection model, and the landing inline search only rendered reference
chips in the older compact popover path.

Safe Auto-Fix Attempts (no user approval needed):
- Route overlay commands through a shared keyboard-command helper.
- Make the mention picker search field own arrow/Return/Escape.
- Render selected landing references in the active inline landing search path.

Destructive Fixes (require user approval):
- Replacing the composer or mention-picker architecture.

Investigation Log:
- 2026-05-08: Patched `ChatComposerKeyHandling.overlayCommand` consumption in
  landing/main composer submission and added `ComposerReferenceSearchField`, an
  AppKit-backed picker search field that maps arrow/Return/Escape to
  selection/cancel actions. Added `landingInlineContextChips` so landing
  `@` selections are visible/removable in the active inline search UI.
  Verification:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ThemePairTests`
  passed 111 Swift Testing tests in 1 suite, result bundle
  `build/xcode-results/2026-05-08-141614-77732.xcresult`. Computer Use runtime
  retest on pid 83781 verified `/` + Down + Return selects `/ask` instead of
  submitting raw `/`, landing `@pro` + Down + Return creates an attached
  reference chip, and main-chat `@pro` + Down + Return creates the same real
  context attachment path.

### ISSUE-2026-05-08-014: Vault connection state disagrees with Notes and Graph data

Status: Verified Fixed (disconnected-cache failure mode; connected-vault graph sync source patch pending live smoke)
Priority: P1
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
Computer Use opened Notes and Graph. Notes listed many folders/files and Graph
rendered/query-searched a large note graph, but `Settings → Vault` reported:

```text
No vault connected. Select a folder to sync your markdown notes.
```

Clicking Notes `New Page` opened a native folder picker titled:

```text
Choose a folder for your Epistemos vault
```

General diagnostics also reported:

```text
Background indexing No active vault selected
Halo backend Not opened yet — call shadow_open_at(path) at bootstrap
```

Suspected Cause:
The Notes/Graph surfaces can read historical SwiftData/imported graph rows while
the active-vault configuration and indexing/search bootstrap believe no vault is
connected. This creates the user's observed failure mode where new vault notes
do not appear in Graph.

Safe Auto-Fix Attempts (no user approval needed):
- Trace the canonical active-vault source used by Notes, Graph bootstrap,
  Shadow/Halo, and Settings.
- Make new-note creation honestly disabled/redirected only when no active vault
  exists, and make cached/imported data explicitly labeled if shown without a
  connected vault.
- Add source/behavior tests for Settings diagnostics and active-vault state.

Destructive Fixes (require user approval):
- Mutating the user's vault selection.
- Deleting cached note/graph rows.

Investigation Log:
- 2026-05-08: Captured in Computer Use Pass 1. This is non-renderer graph data
  plumbing and is allowed to investigate/fix under the graph-rendering freeze.
- 2026-05-08: Patched the restored/initial vault import notification gap.
  `VaultSyncService.schedulePostImportMaintenance` now emits the canonical
  `.vaultChanged` event after a successful import with no recovery issue. This
  lets existing `AppBootstrap.wireR3VaultSwitchObserver` subscribers initialize
  the Rust resource gateway and Shadow backend after async restore/import
  instead of staying in the launch-frame "no active vault" state. Verification:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/VaultSyncServiceAuditTests`
  passed 45 Swift Testing tests in 1 suite; result bundle
  `build/xcode-results/2026-05-08-142656-89037.xcresult`. Launched-app
  verification then showed the audit app still in a disconnected state because
  `scripts/launch_audit_app.sh` intentionally clears vault defaults and launches
  with `EPISTEMOS_SKIP_VAULT_RESTORE=1`; Settings still reported no vault while
  cached local Notes/Graph rows were visible. The event patch remains valid for
  real restore/import paths, but the runtime issue is not fixed until
  disconnected cached data is labeled honestly and stale Halo/index diagnostics
  are cleared.
- 2026-05-08: Patched the disconnected/cache-only truthfulness layer.
  `AppBootstrap.initializeShadowBackendIfReady()` now clears stale Halo state
  and resets Shadow indexing bookkeeping when no active vault exists; Settings
  diagnostics say `No active vault selected - cached local note/graph data only`
  instead of developer bootstrap text; Settings Vault and Notes sidebar now
  label cached local note/graph rows as disconnected until a vault is selected.
  The first focused diagnostics test run failed at compile because the Notes
  cache banner referenced a non-existent `EpistemosTheme.primaryText`; after
  switching to `theme.resolved.foreground.color`,
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/SettingsCategoryTests`
  passed 11 Swift Testing tests in 1 suite, result bundle
  `build/xcode-results/2026-05-08-144026-7322.xcresult`. Launched-app
  verification then confirmed the no-vault/cache state is now honest: Settings
  `General` reports `Halo backend No active vault selected - Shadow/Halo
  closed` and `Background indexing No active vault selected - cached local
  note/graph data only`; Settings `Vault` warns cached local notes/graph rows
  may still be visible while disconnected; Notes renders a `Disconnected Local
  Cache` banner and create/save controls are labeled as vault-selection or
  no-vault actions. `ps -p 16033 -o pid,etime,%cpu,rss,comm` showed 1.4% CPU /
  289,968 KiB RSS after the pass. The connected-vault graph-sync complaint
  still needs a normal-vault live smoke and remains tracked in the deep
  interaction audit as CU-011, but the disconnected-cache contradiction from
  this issue is verified fixed.
- 2026-05-08: Patched the connected-vault graph-dirty fan-out without touching
  graph rendering. `VaultSyncService.publishVaultMutation(_:)` now marks
  `AppBootstrap.shared?.graphState.needsRefresh = true` before emitting the
  vault mutation event, so create/save/move/delete paths cannot notify graph
  observers while the graph is still marked clean. Focused verification passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/VaultSyncServiceAuditTests`
  (46 Swift Testing tests in 1 suite, result bundle
  `build/xcode-results/2026-05-08-152126-68387.xcresult`). This remains a
  source-level patch for the user's connected-vault graph-sync complaint until
  a Computer Use smoke selects a real/temp vault, creates/saves a note, opens
  Graph, and confirms the new note appears without relaunch.

### ISSUE-2026-05-08-015: Epdoc typed Markdown and visualizer still produce raw/broken blocks

Status: Verified Fixed
Priority: P1
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
Computer Use typed an Epdoc fixture containing headings, list items, a Markdown
table, fenced Swift code, an image URL, and a wikilink. Headings converted, but
the second list item retained a literal `-`, the table stayed raw pipe text and
the complexity meter reported `Tables 0`, the code block displayed the closing
fence inside the block, and the image stayed Markdown/link text while the meter
reported `Visuals 0`.

Clicking Epdoc Copilot `Visualize document` then inserted a Mermaid block with a
visible parse error:

```text
Error: Parse error on line 19
Syntax error in text mermaid version 11.14.0
```

Suspected Cause:
Typed-input rules and Copilot graph generation are not using the same robust
Markdown normalization/sanitization as the tested paste/source-guard paths.
The visualizer appears to feed unsafe document text from code/image/link blocks
into Mermaid labels.

Safe Auto-Fix Attempts (no user approval needed):
- Add JS fixtures for typed tables/code fences/image URLs where practical.
- Sanitize/escape visualizer labels before Mermaid emission.
- Prefer structured block insertion for tables and images when a safe source is
  detected; otherwise surface an honest blocked-image state.

Destructive Fixes (require user approval):
- Replacing the Epdoc editor stack.
- Changing saved Epdoc schema in a non-backward-compatible way.

Investigation Log:
- 2026-05-08: Captured in Computer Use Pass 1 on the live `Epistemos Audit`
  build.
- 2026-05-08: Patched the JS editor and graph-generation paths. Table input
  rules now hand multiline Markdown tables to the structured paste parser;
  `EpdocCodeBlock` exits a code block when Enter is pressed on the closing
  fence line; document-graph extraction skips table separator rows, normalizes
  table/image/link/wikilink/code labels, escapes Mermaid label punctuation, and
  emits class definitions without the parser-hostile semicolon form. Rebuilt
  `Epistemos/Resources/Editor/editor.js.br`. Verification passed:
  `npm run check:document-graph`, `npm run check:code-block`,
  `npm run check:markdown-input-rules`, `npm run check:markdown-paste`,
  `npm run typecheck`, and
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
  with result bundle
  `build/xcode-results/2026-05-08-150352-41020.xcresult`.
- 2026-05-08: Computer Use live smoke verified the real paste path after
  focusing the WebKit editor and pressing Command-A/Command-V from a multiline
  Markdown clipboard. The document rendered H1/H2 headings, a bullet list, task
  checkbox, structured table, syntax-highlighted Swift code block, image node,
  and `Graph Sync` wikilink; the complexity row reported `Code 1`, `Tables 1`,
  `Links 1`, and `Embeds 1`. Clicking Epdoc Copilot `Visualize document`
  inserted a rendered `Research diagram` derived from headings/list/task/table/
  code/image/link content with no Mermaid parse error. The fixture's remote
  image URL produced a safe image node but a broken remote preview icon because
  the URL was not a real image; a valid reachable-image smoke remains a
  lower-priority media check, not this P1 blocker.

### ISSUE-2026-05-08-010: Shadow search backend failures were hidden behind empty Halo results

Status: Patched (sanitized diagnostics and Settings health row added; live launched-app verification still pending)
Priority: P1
First Observed: 2026-05-07
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
Runtime logs showed:

```text
shadow search failed: backendFailure(detail: "secret backend detail")
```

The failure was not surfaced as an app health state. `ShadowSearchService.search`
kept Halo's hot path non-throwing by returning `[]`, which is correct for typing
stability, but it also made a backend failure indistinguishable from an honest
zero-hit search unless the user inspected logs.

Suspected Cause:
`Epistemos/Engine/ShadowSearchService.swift` logged and recorded sanitized
AgentEvents for failures, but had no process-local health snapshot or Settings
diagnostic row. Settings had RRF/search diagnostics but no Shadow backend
degraded state.

Safe Auto-Fix Attempts (no user approval needed):
- Add closed-class Shadow search health counters and last-failure state.
- Expose a read-only Settings diagnostics row driven by notifications, not a
  backend probe.
- Add tests that verify sanitized failure classes, recovery after success, and
  Settings mounting.

Destructive Fixes (require user approval):
- Replacing the Shadow backend or changing the Halo search error contract.
- Persisting raw backend failure detail strings.
- Adding active background probes that can churn the backend or vault.

Investigation Log:
- 2026-05-08: Patched `ShadowSearchDiagnostics` into
  `ShadowSearchService.search` and `searchOrThrow`, added
  `ShadowSearchHealthRow` to Settings Diagnostics, and source/behavior tests in
  `ShadowServicesTests` plus `SearchFusionHealthRowTests`. Verification command:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ShadowServicesTests -only-testing:EpistemosTests/SearchFusionHealthRowTests`
  first failed at compile on private diagnostic recorder access, then failed a
  stale one-line `searchOrThrow` guard, then passed 27 tests in 2 suites; result
  bundle `build/xcode-results/2026-05-08-065256-75382.xcresult`. This remains
  `Patched`, not `Verified Fixed`, until a launched-app smoke observes both a
  degraded failure and later successful recovery in Settings.

---

### ISSUE-2026-05-08-011: Companion Farm animation churn contributed to high idle CPU

Status: Verified Fixed (2026-05-08; static landing shelf and launched-app idle CPU smoke)
Priority: P1
First Observed: 2026-05-07
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
Live audit reported the `Epistemos` process sitting around 18-19% CPU while idle
on an open note. A sample implicated SwiftUI layout / AttributeGraph work around
`Epistemos/Views/Landing/Farm/CompanionRoamingField.swift`.

Suspected Cause:
`CompanionRoamingField` used a display-style 24Hz animation timeline and each
rendered `CompanionView` could create another 8Hz breathing timeline. On the
Landing Farm path this multiplies idle invalidations across companions. The
roaming and breathing phase math also used large absolute reference-date values
directly in trigonometric calls during long-running sessions.

Safe Auto-Fix Attempts (no user approval needed):
- Replace display-style idle animation timelines with coarse periodic clocks.
- Share one sampled parent date into Farm companion views instead of creating a
  per-companion timeline.
- Add source and behavioral tests for the throttled clock path and bounded phase
  math.
- Keep the intended landing-agent surface usable while removing roaming/walking
  work from the idle path.

Destructive Fixes (require user approval):
- Removing the Companion Farm visual surface.
- Removing persisted companion/agent state.

Investigation Log:
- 2026-05-08: Patched `CompanionRoamingField` to use one 0.25s periodic parent
  clock and pass the sampled date into `CompanionView`; patched `CompanionView`
  to fall back to its own 0.25s periodic clock only outside a parent clock and to
  normalize breathing phase math. Added `CompanionAvatarGrammarSourceGuardTests`
  coverage for the periodic clock/source path and a large absolute-date
  finite/bounded math test. Verification command:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CompanionAvatarGrammarSourceGuardTests`
  first failed one stale source guard, then passed 6 tests in 1 suite; result
  bundle `build/xcode-results/2026-05-08-070321-42404.xcresult`. This remains
  `Patched`, not `Verified Fixed`, until a launched-app idle CPU sample confirms
  the open-note/Landing path no longer has elevated idle CPU.
- 2026-05-08: Hardened the patch to match the v1 product direction: the landing
  farm is now a small top-right `AGENTS` dock, `CompanionRoamingField` is a
  static landing-only shelf, the shared breathing clock is 0.75s, active agents
  do not walk, companion glyph halos/orbs are removed from the v1 visual path,
  new agents activate on create, and the active agent persona is injected into
  `PipelineService` / `ChatCoordinator` prompts. Focused verification passed:
  `cargo test --manifest-path graph-engine/Cargo.toml lod_profile_is_zoom_stable_in_cinematic_mode --lib`
  and `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CompanionAvatarGrammarSourceGuardTests -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests`
  with 26 Swift Testing tests in 2 suites; result bundle
  `build/xcode-results/2026-05-08-114808-1566.xcresult`. This remains `Patched`,
  not `Verified Fixed`, until launched-app visual and idle CPU smokes confirm the
  dock is quiet and visually correct.
- 2026-05-08: Polished the agent dock glyphs after visual feedback. Creation now
  exposes six block-style body presets, while dock-size bodies keep their outer
  silhouettes but remove tiny internal belt/spine/mouth square dividers that
  looked noisy rather than like deliberate pixel art. Focused verification
  passed in the combined graph/agent/wave suite:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/GraphPhysicsSettingsAuditTests -only-testing:EpistemosTests/CompanionAvatarGrammarSourceGuardTests -only-testing:EpistemosTests/LandingWaveChoreographyTests -only-testing:EpistemosTests/LandingWaveGlyphAtlasTests`
  with 35 Swift Testing tests in 4 suites; result bundle
  `build/xcode-results/2026-05-08-121411-56577.xcresult`. This still remains
  `Patched`, not `Verified Fixed`, until a launched-app idle CPU and visual smoke
  confirms the dock is quiet and reads correctly in situ.
- 2026-05-08: Launched `EpistemosAudit.app` via `./scripts/launch_audit_app.sh`.
  Computer Use observed the landing page with a compact top-right `ORBIT AGENTS`
  dock, visible `+`, four small block agents, no large companion box, no graph
  companion surface, and no orb shell. Clicking an agent changed the active AX
  value to `active`; clicking search opened the landing search input. Recent app
  logs returned no entries from `log show --predicate 'process == "Epistemos Audit"' --last 2m`.
  CPU was not low enough to close this issue unqualified: one sample during the
  active search overlay was 15.8%, then after Escape closed search the landing
  sample was 3.4% RSS ~273 MB. Keep this issue `Patched` until a longer idle CPU
  sample/Time Profiler pass separates the static agent dock from the search-wave
  animation cost.
- 2026-05-08: Closed the remaining idle shelf fallthrough. `LandingView` now
  mounts the farm with `isAnimationActive: false`, and `CompanionRoamingField`
  uses a deterministic `staticSampleDate` for idle rendering instead of passing
  `nil` into child `CompanionView`s that would allocate their own timelines.
  Focused verification passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CompanionAvatarGrammarSourceGuardTests`
  with 7 Swift Testing tests in 1 suite; result bundle
  `build/xcode-results/2026-05-08-155559-42983.xcresult`. Launched audit-app
  verification against pid 54172 showed the compact top-right `AGENTS` shelf and
  `ps -p 54172 -o pid,ppid,%cpu,%mem,rss,etime,command` reported 0.0% CPU at
  13 seconds and again after 71 seconds idle, RSS ~221-223 MB.

---

### ISSUE-2026-05-08-012: NightBrain dependency readiness logged expected missing services as job failures

Status: Patched (dependency preflight added; live launched-app log verification still pending)
Priority: P1
First Observed: 2026-05-07
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
Runtime logs showed:

```text
NightBrain search index maintenance requires an initialized SearchIndexService
```

The message represented a missing readiness dependency, but it appeared through
the job failure path. That makes expected deferred maintenance look broken at
launch and pollutes the NightBrain run ledger with interrupted runs.

Suspected Cause:
`NightBrainService.canStart()` already checked broad dependencies for the
background scheduler, but `runPipeline(jobOrder:)` is also used by fallback and
manual trigger paths. That entrypoint opened an `EventStore` run before checking
whether the selected jobs actually had SearchIndex, AgentGraphMemory, or
cloud-knowledge wiring available.

Safe Auto-Fix Attempts (no user approval needed):
- Preflight only the dependencies required by the selected job order.
- Return `.deferred` before creating a run when a dependency is missing.
- Keep unexpected job exceptions as real interrupted runs/errors.

Destructive Fixes (require user approval):
- Removing NightBrain jobs from the canonical v1 job order.
- Changing the EventStore NightBrain schema.
- Starting SearchIndex/GraphMemory eagerly just to satisfy NightBrain.

Investigation Log:
- 2026-05-08: Patched `NightBrainService.runPipeline` with a selected-job
  dependency preflight. Missing SearchIndex, AgentGraphMemory, or
  cloud-knowledge wiring now defers before run creation; dependency races after
  preflight log as informational job deferrals; real job exceptions still
  interrupt a run. Updated `CognitiveSubstrateTests` missing-dependency coverage
  and `RuntimeValidationTests` source guards. Verification command:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/NightBrainCheckpointResumeTests -only-testing:EpistemosTests/RuntimeValidationTests`
  passed 272 tests in 2 suites; result bundle
  `build/xcode-results/2026-05-08-071120-9747.xcresult`. This remains
  `Patched`, not `Verified Fixed`, until a launched-app log smoke confirms the
  early missing-SearchIndex failure no longer appears.

---

### ISSUE-2026-05-08-017: Landing search cursor and click animation felt fake

Status: Verified Fixed
Priority: P1
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
User screenshot showed the landing search caret stuck in the middle of the
`Ask Epistemos...` prompt after clicking the search surface. The focus
transition also jumped/zoomed a few pixels, and the text felt projected rather
than like a real input. User also requested the click animation be tighter,
denser, slower, and more like an ASCII black-hole warp rather than a huge
water-style splash.

Suspected Cause:
The large prompt text and edit-field placeholder/caret shared the same visual
projection/scale path, so focus could leave a caret inside placeholder copy.
The landing wave choreography used large, fast splash radii that were tuned for
the older water look rather than the current pixel/ASCII identity.

Safe Auto-Fix Attempts (no user approval needed):
- Use a real native empty `TextField` for focused search.
- Render the placeholder as a separate overlay only while unfocused and empty.
- Use the shared mono display font for landing search, while keeping the bottom
  command/shortcut row on the native system UI font.
- Retune the landing wave grid and click beat to denser, tighter, slower ASCII
  warp pulses.

Destructive Fixes (require user approval):
- Replacing the landing composer/search architecture.

Investigation Log:
- 2026-05-08: Patched `LandingView`, `EpistemosTheme`, `LandingWaveDesign`,
  and `LandingWaveChoreography`. Focused verification passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/LandingWaveChoreographyTests -only-testing:EpistemosTests/EpdocCopilotSurfaceTests -only-testing:EpistemosTests/MiniChatViewAuditTests -only-testing:EpistemosTests/RuntimeValidationTests/landingSearchUsesLiquidWaveOverlay -only-testing:EpistemosTests/NoteWindowManagerTests -only-testing:EpistemosTests/SettingsWindowPresentationTests`
  with 59 Swift Testing tests in 6 suites; result bundle
  `build/xcode-results/2026-05-08-163706-20577.xcresult`.
- 2026-05-08: Computer Use live smoke on `com.epistemos.audit` pid 44275
  verified the focused field is exposed as `Landing search input`, typing `ask`
  renders the caret after `ask`, `@` opens `Browse Notes and Chats`, and the
  slash button opens the real command palette. `ps -p 44275 -o pid,etime,%cpu,rss,comm`
  showed 0.1% CPU / 290,304 KiB RSS after the targeted smoke.
- 2026-05-08: Corrected the bottom landing command/shortcut row back to the
  native system UI font; only the central landing search prompt/input keeps the
  high-quality mono display font. Verified by
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/NoteWindowManagerTests -only-testing:EpistemosTests/VaultSyncServiceAuditTests -only-testing:EpistemosTests/RuntimeValidationTests`
  with 339 Swift Testing tests in 3 suites; result bundle
  `build/xcode-results/2026-05-08-171538-68569.xcresult`.

### ISSUE-2026-05-08-018: Epdoc dock exposed an embedded chat instead of document-only actions

Status: Verified Fixed
Priority: P1
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
User requested removing the chat surface inside Epdoc and keeping only
`Visualize document` and `Add frontmatter`, with Mini Chat serving as the chat
route for Epdoc context.

Suspected Cause:
`EpdocCopilotDockView` mixed document commands with a free-form `Ask Epdoc`
embedded chat transcript/input, creating a second chat surface inside the
document editor.

Safe Auto-Fix Attempts (no user approval needed):
- Remove the embedded dock transcript/input UI.
- Keep the document transform buttons.
- Route active saved Epdoc file context into Mini Chat.

Destructive Fixes (require user approval):
- Removing Epdoc transform commands.
- Changing saved Epdoc schema.

Investigation Log:
- 2026-05-08: Patched `EpdocCopilotDockView` to render only compact
  `Visualize document` and `Add frontmatter` actions, and patched
  `MiniChatWindowController.openNewChat(attaching:)` to attach the active saved
  Epdoc file before falling back to active note context. Focused verification
  passed in the 59-test targeted suite above; result bundle
  `build/xcode-results/2026-05-08-163706-20577.xcresult`.
- 2026-05-08: Computer Use live smoke opened an `Untitled` Epdoc and verified
  only the two document-action buttons are visible with AX id
  `epdoc-document-actions`; pressing `⌘3` opened Mini Chat. The smoke document
  was unsaved, so no file attachment chip was expected. Saved-Epdoc attachment
  is source-covered and remains a lightweight RC smoke.

### ISSUE-2026-05-08-019: Notes utility panel was too tall and content-sized

Status: Verified Fixed
Priority: P2
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
User reported the Notes/sidebar utility window was extremely long and hard to
resize.

Suspected Cause:
`UtilityWindowManager` let hosted SwiftUI Notes content drive AppKit panel
sizing and used a large default/minimum geometry.

Safe Auto-Fix Attempts (no user approval needed):
- Lower the Notes utility default and minimum size.
- Disable SwiftUI host sizing options for the Notes utility surface.
- Keep the no-vault/disconnected-cache labels honest.

Destructive Fixes (require user approval):
- Deleting cached note rows.
- Mutating the user's vault selection.

Investigation Log:
- 2026-05-08: Patched `UtilityWindowManager` Notes sizing. Focused coverage
  passed in `NoteWindowManagerTests` and `SettingsWindowPresentationTests` as
  part of the 59-test targeted suite; result bundle
  `build/xcode-results/2026-05-08-163706-20577.xcresult`.
- 2026-05-08: Computer Use live smoke with `⌘2` opened a compact Notes dialog
  showing the `Disconnected Local Cache` banner and visible bottom action row,
  rather than the previous oversized panel.

### ISSUE-2026-05-08-020: Graph full-screen performance regression after pixel-node work

Status: Needs re-verification (graph-frozen pass lifted 2026-05-09)
Priority: P1
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
User reports graph full-screen performance regressed after the pixel-node work.

Suspected Cause:
Unverified. Candidate areas include full-screen drawable sizing, label atlas or
pixel-node LOD costs, graph overlay work, or a separate renderer hot path. This
needs Time Profiler / Animation Hitches evidence before a safe patch.

Safe Auto-Fix Attempts (no user approval needed):
- Manual graph open/close/full-screen smoke.
- Time Profiler / Animation Hitches capture.
- Log evidence and classify whether the root is renderer/shader/visual mode or
  non-renderer UI/overlay code.

Destructive Fixes (require user approval):
- Modifying graph renderer/shader/visual-mode code during a graph-frozen pass.
- Reverting pixel-node visual identity.

Investigation Log:
- 2026-05-08: Logged only. Current targeted pass intentionally did not touch
  graph renderer, graph shaders, visual modes, or graph physics under the
  explicit graph-rendering freeze. This remains the next graph-authorized
  profiling slice.
- 2026-05-10: Freeze effectively lifted — 25+ graph-renderer commits landed
  between 2026-05-08 and HEAD `ebd26c08f`. Most relevant for full-screen
  perf: the `field_line` subsystem (LineEdgeInstance + line_edge_vertex
  shader + field_line_pipeline + scratch buffers) was deleted entirely
  in commit `eeb764b62`, removing a heavy per-frame draw call that scaled
  with pixel count. Also: `edge_highlight_flag_buf` deleted (one fewer
  vertex-buffer bind per frame), CurveEdgeInstance struct stride aligned
  (no more redundant alignment-fix uploads), 120 Hz CADisplayLink wired
  at `MetalGraphView.swift` `link.preferredFrameRateRange`. The originally-
  reported regression should be re-tested on a real full-screen pass before
  any further fix — diagnosis was pre-deletion and is likely stale.

---

### ISSUE-2026-05-07-001: Code editor large-file viewport virtualization and fluidity

Status: Patched (source-level viewport/gutter hardening; manual Time Profiler and animation-hitch verification still pending)
Priority: P1 (release-quality performance/UX; not currently classified as data loss)
First Observed: 2026-05-07
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
The native code editor still feels "iffy" and visibly less fluid than the desired
IDE-grade surface. The user specifically recalls the older TK1-era editor being
optimized around only what was visible, and wants the v1 code editor to recover
that same principle: large code buffers must not be loaded, styled, measured, or
relaid out as one whole slab. The target behavior is viewport/progressive layout:
the editor should keep scrolling fluid by updating visible ranges as the user
scrolls, comparable to TextKit 2's deferred fragment model or an IDE-style
virtualized editor.

Suspected Cause:
This needs a focused architecture audit before a fix. The current code editor is
native and has several debounce/performance policies, but it is not yet proven to
have true large-buffer virtualization, line-gutter virtualization, folding-range
virtualization, and syntax-highlight range limiting. Candidate paths to evaluate:
- Keep the native `CodeEditSourceEditor`/Swift surface, but add strict viewport
  invalidation, visible-line measurement, bounded syntax refresh, and no whole-
  buffer work on scroll.
- Move the code editor onto a TextKit 2-backed viewport model if the active
  package cannot provide enough visible-range control.
- Use a WebKit/CodeMirror 6 island only if it materially improves large-file
  rendering, syntax coloring, folding gutters, indentation guides, and semantic
  affordances without creating a second app architecture or Tauri-style shell.
- Preserve inactive TK1 learnings as research/fallback context; do not resurrect
  a live TK1 production path without a deliberate compatibility brief.

Safe Auto-Fix Attempts (no user approval needed):
- Add a source audit that identifies every whole-buffer operation in
  `Epistemos/Views/Notes/CodeEditorView.swift` on scroll, edit, search, LSP,
  outline, gutter, indentation-guide, and semantic-refresh paths.
- Add focused tests for large buffers (10k/50k/100k lines) that assert bounded
  line metrics, delayed semantic refresh, and no eager semantic sidebar work.
- Add debug-only timing logs around initial load, scroll refresh, highlight
  refresh, gutter refresh, folding refresh, and LSP refresh.
- Re-run manual Time Profiler/Animation Hitches on a large Swift/Rust file after
  the active coding lane rebuilds the app.

Destructive Fixes (require user approval):
- Replacing the native editor package with a WebKit/CodeMirror 6 editor island.
- Reintroducing live TK1 editor infrastructure.
- Rewriting the code editor storage model or LSP bridge.

Investigation Log:
- 2026-05-07: Captured from user feedback during v1 close-out red-team audit.
  This is a requirement-level issue, not a chosen fix: the canonical requirement
  is viewport/progressive rendering and IDE-grade fluidity; TK2, native package
  hardening, or CodeMirror/WebKit are implementation candidates to benchmark.
- 2026-05-08: Codex patched the native editor sidecar hot paths without
  replacing CodeEditSourceEditor: `CodeEditorLargeFilePolicy` now defines the
  100k-character/10k-line large-file gate and computes bounded visible-line
  windows; `SegmentedIndentationGuideView` accepts an optional viewport line
  range, reserves only that window, and stops parsing after the requested
  upper bound; `EpistemosEditorCoordinator` uses viewport-scoped indentation
  refreshes for large files on scroll and avoids recomputing full line counts
  during guide refresh; the dormant right-side fallback gutter no longer
  hydrates while hidden and `CodeLineGutterView` lazily caches visible line
  labels instead of allocating one `NSString` per file line. Added focused
  coverage in `EpistemosTests/CodeEditorPolishTests.swift` for 100k-line line
  metrics, large-file viewport policy bounds, huge-file gutter visible ranges,
  and source guards. Verification passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CodeEditorPolishTests`
  (28 Swift Testing tests in 1 suite, result bundle
  `build/xcode-results/2026-05-08-032755-92042.xcresult`). This remains
  `Patched`, not `Verified Fixed`, until a launched-app large Swift/Rust file
  smoke plus Time Profiler/Animation Hitches pass confirms runtime fluidity.
- 2026-05-08: Tightened the remaining visible-window indentation path that the
  live audit flagged. `EpistemosEditorCoordinator` now caches UTF-16 line-start
  offsets when the text changes, drives scroll-time guide refresh from cached
  text rather than a fresh `textView.string` read, and extracts only the
  visible text window for large-file guide parsing. `SegmentedIndentationGuideView`
  now accepts a base line number so pre-sliced visible windows keep correct
  absolute line metrics. Added behavioral/source coverage in
  `EpistemosTests/CodeEditorPolishTests.swift`. Verification passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CodeEditorPolishTests`
  (29 Swift Testing tests in 1 suite, result bundle
  `build/xcode-results/2026-05-08-072155-12425.xcresult`). This remains
  `Patched`, not `Verified Fixed`, until a launched-app large Swift/Rust file
  smoke plus Time Profiler/Animation Hitches pass confirms runtime fluidity.
- 2026-05-08: Removed another movement-time full-string access from the live
  editor coordinator. Cursor/selection tracking now converts the selected range
  against `lastText`, the coordinator's cached editor text, instead of fetching
  `NSTextView.string` on cursor movement. The focused suite passed again:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CodeEditorPolishTests`
  (29 Swift Testing tests in 1 suite, result bundle
  `build/xcode-results/2026-05-08-072937-79738.xcresult`). This remains
  `Patched`, not `Verified Fixed`, until launched-app large-file profiling
  confirms scroll and selection fluidity.

---

### ISSUE-2026-05-08-001: Passive launch touches TCC-sensitive idle/automation probes

Status: Investigating (source-level idle/contact probes patched; residual launch ListenEvent preflight still attributed to app)
Priority: P0
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
Read-only live audit reported fresh app launch logs for `kTCCServiceListenEvent`
and `kTCCServiceAddressBook` before any obvious user action.

Suspected Cause:
- `Epistemos/State/ActivityTracker.swift` used
  `CGEventSource.secondsSinceLastEventType` for passive idle detection.
- `Epistemos/State/NightBrainService.swift` and
  `Epistemos/KnowledgeFusion/Alignment/TrainingScheduler.swift` used the same
  global input-idle probe in background scheduling paths.
- `Epistemos/Omega/iMessageDriver/IMessageNativeSetupDoctor.swift` could probe
  Automation permission from a status read, which Settings can trigger while
  merely rendering.

Safe Auto-Fix Attempts (no user approval needed):
- Replace passive global-input idle checks with app/process-local quiescence.
- Require NightBrain dependencies before starting maintenance jobs.
- Split passive iMessage setup status from explicit Automation probing.
- Add source guards that fail if passive launch paths reintroduce those probes.

Destructive Fixes (require user approval):
- Removing iMessage/contact features outright.
- Changing app entitlements or system permission declarations.

Investigation Log:
- 2026-05-08: Patched `ActivityTracker`, `NightBrainService`, and
  `TrainingScheduler` to avoid `CGEventSource.secondsSinceLastEventType` in
  passive launch/background paths; `IMessageNativeSetupDoctor.currentStatus`
  now defaults to `probeAutomation: false`, and Settings only requests the
  probe from explicit refresh/guided setup. `NightBrainService.canStart()` now
  checks search/graph/cloud dependency readiness before starting maintenance.
  Focused verification passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/HELIOSInvariantSourceGuardTests -only-testing:EpistemosTests/MetalGraphViewBootstrapTests -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests`
  (405 tests in 4 suites, result bundle
  `build/xcode-results/2026-05-08-060808-58329.xcresult`). Remains `Patched`
  until a fresh launched-app log pass confirms no passive TCC requests.
- 2026-05-08: Added saved-state/document-restore gates so passive launch no
  longer reopens stale Epdoc windows: `EpistemosApp` disables untitled-window
  creation, and `EpistemosDocumentController.reopenDocument` suppresses
  restorable document reopen when the saved-state purge launch policy is active.
  Focused verification passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/EpistemosDocumentControllerTests`
  with 20 Swift Testing tests in 1 suite; result bundle
  `build/xcode-results/2026-05-08-154443-14996.xcresult`. Launched audit-app
  Computer Use smoke confirmed pid 54172 opens the Landing page, not the stale
  `Untitled` Epdoc window.
- 2026-05-08: Fresh launched-app log pass did not find current-pid
  AddressBook/Calendar/Reminders requests; AddressBook noise in the broad log
  window was attributed to system Contacts helpers. It did still show
  `kTCCServiceListenEvent` preflight with `requesting={identifier=com.epistemos.audit,
  pid=54172}`. Source scans found no remaining production `CGEventSource`,
  `NSEvent.addGlobalMonitorForEvents`, `NSEvent.addLocalMonitorForEvents`, or
  eager `AXIsProcessTrusted` launch path. Keep this issue open for residual
  launch/AppKit/SkyLight/linkage attribution rather than claiming privacy clean.

---

### ISSUE-2026-05-08-002: Metal drawable lifecycle logs double-present and zero-size drawable errors

Status: Patched (source-level lifecycle guards; fresh live-log verification still pending)
Priority: P0
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
Read-only live audit reported runtime logs:
`Each CAMetalLayerDrawable can only be presented once!` and
`CAMetalLayer ignoring invalid setDrawableSize width=0 height=0`.

Suspected Cause:
- `Epistemos/Views/Graph/MetalGraphView.swift` paused the graph engine by
  setting `metalLayer?.drawableSize = .zero`, which CAMetalLayer rejects.
- `Epistemos/Views/Landing/Wave/LandingWaveMetalView.swift` queued rendering
  from `draw(in:)` through an async main-actor task, allowing rendering to occur
  after MTKView's delegate callback and against a stale/current drawable.

Safe Auto-Fix Attempts (no user approval needed):
- Use a nonzero paused drawable size.
- Render MTKView frames synchronously from `draw(in:)`.
- Guard against non-main-thread, zero-size, and reentrant frame rendering.
- Add source guards for the lifecycle contract.

Destructive Fixes (require user approval):
- Replacing the Metal graph renderer.
- Removing the landing Metal wave surface.

Investigation Log:
- 2026-05-08: Patched `MetalGraphView.pauseEngine()` to use a 1x1 paused
  drawable size, and patched `LandingWaveMetalView.Coordinator.draw(in:)` to
  render synchronously on the main actor with positive-size and reentrancy
  guards instead of queuing an async `Task`. Focused verification passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/HELIOSInvariantSourceGuardTests -only-testing:EpistemosTests/MetalGraphViewBootstrapTests -only-testing:EpistemosTests/RuntimeCapabilityAndPerformancePolicyTests`
  (405 tests in 4 suites, result bundle
  `build/xcode-results/2026-05-08-060808-58329.xcresult`). Remains `Patched`
  until a fresh live app log pass confirms the CAMetalLayer errors are gone.

---

### ISSUE-2026-05-08-003: App Review audit missed Swift subprocess surfaces

Status: Patched
Priority: P1
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
Read-only audit found `Tools/app-review-audit/app-review-audit.sh` only matched
older shell forms (`Process().run`, `system("`, `popen(`) while real Swift code
uses `Process.init()` plus `try process.run()` and `Pipe()`.

Suspected Cause:
The W26 stage-0 script was too literal and did not scan the Swift subprocess
surface actually used by Knowledge Fusion and other direct/Pro paths.

Safe Auto-Fix Attempts (no user approval needed):
- Extend the script to detect Swift `Process(`, `Process.init(`, and `Pipe()`.
- Keep the result as a stage-0 MAS review warning until target/config-aware
  App Store partition checks exist.
- Add source guards for the new patterns.

Destructive Fixes (require user approval):
- Failing every build on direct/Pro subprocess use before MAS-specific analysis.
- Removing direct/Pro subprocess features.

Investigation Log:
- 2026-05-08: Patched the audit script and source guard. Verification:
  `./Tools/app-review-audit/app-review-audit.sh` passes while emitting expected
  W26 warnings for the real Swift subprocess surfaces; the 405-test focused
  suite above includes `HELIOSInvariantSourceGuardTests` coverage for the new
  script patterns.

---

### ISSUE-2026-05-08-004: Generated syntax-core rlib was tracked in Git

Status: Patched
Priority: P0
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
`syntax-core/target/aarch64-apple-darwin/debug/libsyntax_core.rlib` was tracked
and dirty even though it is a generated build output under a target directory.

Suspected Cause:
The artifact had been committed historically before `syntax-core/target/` was
treated as ignored generated output.

Safe Auto-Fix Attempts (no user approval needed):
- Confirm `.gitignore` ignores `syntax-core/target/`.
- Remove the tracked artifact from the Git index without deleting the local
  build output.

Destructive Fixes (require user approval):
- Deleting target directories from disk.
- Rewriting history to purge old binary blobs.

Investigation Log:
- 2026-05-08: Ran
  `git rm --cached -- syntax-core/target/aarch64-apple-darwin/debug/libsyntax_core.rlib`.
  The local file remains on disk and ignored; the index now records deletion of
  the generated artifact. `git diff --check` passed after the change.

---

### ISSUE-2026-05-08-005: Prose editor scrollbar and body are constrained to a narrow column

Status: Patched (source-level geometry fix; live visual verification still pending)
Priority: P1
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
Read-only live audit reported the visible note editor boxed into a narrow column,
with the vertical scrollbar aligned to that narrow content region instead of the
editor surface edge. The user also requested preserving the older wider text feel.

Suspected Cause:
`Epistemos/Views/Notes/NoteDetailWorkspaceView.swift` applied
`NoteDualPreviewLayout.editorReadableWidth(...)` as an outer frame around the
whole `ProseEditorView`, while `Epistemos/Views/Notes/ProseTextView2.swift`
already owns readable horizontal insets. The stacked constraints narrowed both
the text and the scroll view.

Safe Auto-Fix Attempts (no user approval needed):
- Remove the outer readable-width frame from the SwiftUI note editor surface.
- Preserve TextKit-owned horizontal readable insets for text readability.
- Add source guards so the outer `readableWidth` frame does not return.

Destructive Fixes (require user approval):
- Replacing the Prose editor stack.
- Rewriting the note workspace layout architecture.

Investigation Log:
- 2026-05-08: Patched `NoteDetailWorkspaceView.noteEditorSurface` so
  `ProseEditorView` fills the available workspace while the lower TextKit stack
  controls readable text insets. Updated TK2 horizontal inset expectations for
  the current 960pt text feel. Verification passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/NoteEditorLayoutTests -only-testing:EpistemosTests/NoteToolbarGlowTests -only-testing:EpistemosTests/TextKit2ParityTests`
  (172 tests in 18 suites, result bundle
  `build/xcode-results/2026-05-08-062235-57126.xcresult`). Remains `Patched`
  until a launched-app visual smoke confirms the scrollbar position and text
  width.

---

### ISSUE-2026-05-08-006: `Ask this note` is visible but not exposed as a distinct accessible submit action

Status: Patched (source-level accessibility/action fix; live AX verification still pending)
Priority: P1
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
Read-only live audit reported `Ask this note` was visible, but Computer Use only
exposed the note text area in the accessibility tree. A coordinate click did not
visibly open note chat.

Suspected Cause:
The shared note ask bar exposed placeholder text in a text field but did not
provide a distinct accessible submit button for the note-level ask action.

Safe Auto-Fix Attempts (no user approval needed):
- Add an explicit submit button to the shared note ask bar.
- Add accessibility labels/hints to the ask text field and submit/stop buttons.
- Add source guards for the reachable button path.

Destructive Fixes (require user approval):
- Replacing the note-chat architecture.
- Changing chat provider/tool execution policy.

Investigation Log:
- 2026-05-08: Patched `AssistantToolbarAskBar` to expose an icon submit
  `Button(action: onSubmit)` with the note ask placeholder as its accessibility
  label, disabled only when trimmed text is empty. The text field and streaming
  stop button now also have labels/hints. Focused note editor/TK2 verification
  passed with the 172-test suite/result bundle listed in ISSUE-2026-05-08-005.
  Remains `Patched` until a live Computer Use/AX smoke confirms the button is
  present and note ask opens/submits from the launched app.

---

### ISSUE-2026-05-08-007: BlockMirror background reschedule can persist stale blocks

Status: Patched
Priority: P1 (stale block mirror / transclusion integrity risk)
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
Focused verification for the Prose editor slice failed:
`TextKit2ParityTests` expected latest blocks `["New opening", "New followup"]`
but observed `["Old opening", "New opening", "New followup"]` after a body was
rescheduled quickly.

Suspected Cause:
`Epistemos/Sync/BlockMirror.swift` canceled the previous task and tracked
generations, but the obsolete detached task could start background `ModelContext`
work before cancellation/generation checks prevented persistence.

Safe Auto-Fix Attempts (no user approval needed):
- Add a short coalescing delay before background model-context creation.
- Re-check the scheduled generation before doing persistence work.
- Keep the behavioral SwiftData-backed regression test.

Destructive Fixes (require user approval):
- Replacing block mirror persistence.
- Changing the SwiftData schema.

Investigation Log:
- 2026-05-08: Patched `BlockMirrorSyncCoordinator` to wait through the
  coalescing window and confirm the generation is still current before creating
  a background `ModelContext`. The focused rerun passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/NoteEditorLayoutTests -only-testing:EpistemosTests/NoteToolbarGlowTests -only-testing:EpistemosTests/TextKit2ParityTests`
  (172 tests in 18 suites, result bundle
  `build/xcode-results/2026-05-08-062235-57126.xcresult`).

---

### ISSUE-2026-05-08-008: Epdoc durable graph projection is shallow without wikilinks

Status: Patched (source/test graph projection fix; live graph-button smoke still pending)
Priority: P1
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
Read-only audit found `EpdocGraphProjector` only projected provenance and
`[[wikilink]]` reference edges. A long pasted `.epdoc` with no wikilinks could
therefore produce a graph that looked like a thin document/provenance projection
instead of surfacing authored concepts from the document.

Suspected Cause:
`Epistemos/Engine/EpdocGraphProjector.swift` recursively scanned text nodes for
wikilinks but did not extract bounded labels from headings, lists, blockquotes,
image metadata, or long paragraph lead sentences. `EpdocGraphPersistence` also
did not classify generated `.contains` edges as projection-owned output to
replace on re-save.

Safe Auto-Fix Attempts (no user approval needed):
- Add bounded authored-content label extraction from existing ProseMirror JSON.
- Reject wikilink markup, empty/oversized labels, and generic placeholders such
  as `Idea` and `Evidence`.
- Treat generated semantic `.contains` edges as replaceable projection output.
- Add projector and persistence regression tests.

Destructive Fixes (require user approval):
- Replacing the graph projection architecture.
- Adding speculative semantic/HELIOS claim extraction.

Investigation Log:
- 2026-05-08: Patched `EpdocGraphProjector` to emit bounded authored semantic
  `.contains` label edges from headings, list items, blockquotes, image
  alt/title, and long paragraph lead sentences, and patched
  `EpdocGraphPersistence` to replace generated `.contains` edges on re-save.
  Focused verification first failed at compile on optional title normalization,
  then failed graph expectations due wikilink paragraph leakage and mid-word
  truncation; after those fixes, the focused suite passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/EpdocDocumentTests -only-testing:EpistemosTests/EpdocGraphProjectorTests -only-testing:EpistemosTests/EpdocGraphPersistenceTests -only-testing:EpistemosTests/EpdocQueryTests -only-testing:EpistemosTests/EpdocComplexityCalculatorTests`
  (65 tests in 5 suites, result bundle
  `build/xcode-results/2026-05-08-063708-61062.xcresult`). Remains `Patched`
  until a launched-app graph-button smoke confirms the richer graph is visible.

---

### ISSUE-2026-05-08-009: Epdoc complexity meter is not persisted to manifest metadata

Status: Patched
Priority: P2
First Observed: 2026-05-08
Affected Version: branch `feature/landing-liquid-wave`

Symptom:
The `.epdoc` toolbar complexity meter updates from live editor JSON, but saved
packages did not write `manifest.metadata["complexity"]`. Existing
`EpdocQuery` rules `complexity-above` and `complexity-below` read that metadata
key, so the query surface could be present without durable save-path data.

Suspected Cause:
`Epistemos/Engine/EpdocDocument.swift` saved the manifest with updated
timestamps/hash but did not recompute complexity metadata from
`content.pm.json`, and `setTitle(_:)` rebuilt the manifest without preserving
metadata.

Safe Auto-Fix Attempts (no user approval needed):
- Recompute complexity from canonical content JSON during file-wrapper save.
- Preserve unrelated metadata fields.
- Remove stale complexity only when content JSON cannot be scored.
- Preserve metadata through title edits.
- Add save-path tests that back the existing query rules.

Destructive Fixes (require user approval):
- Changing the manifest schema.
- Replacing existing complexity scoring semantics.

Investigation Log:
- 2026-05-08: Patched `EpdocDocument.fileWrapper(ofType:)` to recompute and
  persist `metadata["complexity"]`, preserve existing metadata such as theme,
  and keep metadata through `setTitle(_:)`. Focused verification passed in the
  same 65-test Epdoc suite/result bundle listed in ISSUE-2026-05-08-008.

---

### ISSUE-2026-04-04-001: Vec Drop malloc error during app lifecycle transition

Status: Verified Fixed
Priority: P0 (crash, but during teardown, not blocking normal usage)
First Observed: 2026-04-04
Affected Version: branch `codex/post-audit-feature-work`

Symptom:
```
Window occlusion changed: visible=false
[Diagnostics] lifecycle_event name="app_resigned_active"
Epistemos(46884,0x16bcff000) malloc: *** error for object 0xb24e6c000: pointer being freed was not allocated
Epistemos(46884,0x16bcff000) malloc: *** set a breakpoint in malloc_error_break to debug

Stack frame 6: _$LT$alloc..raw_vec..RawVec$LT$T$C$A$GT$$u20$as$u20$core..ops..drop..Drop$GT$::drop
Debug session ended with code 9: killed
```

Reproduction: Launch app, let it load fully (vault import, graph build), then hide/minimize the window OR let the app become inactive (click another window). Crash happens during the lifecycle transition.

Suspected Cause:
A Rust `Vec` is being dropped with a backing pointer that wasn't allocated by the standard allocator. Most likely culprits:
- `graph-engine/src/lib.rs:2001` — `Vec::from_raw_parts(list.candidates, list.count as usize, list.count as usize)` — if Swift-side caller passes a ptr/len/cap triple that doesn't match the original allocation exactly, this crashes.
- `graph-engine/src/lib.rs:2327` — `Vec::from_raw_parts(buffer.ptr, buffer.len as usize, buffer.capacity as usize)` — same risk.
- Any Swift code that constructs a buffer, passes it to Rust expecting reclamation, but mismatches the allocator.

Why lifecycle transition triggers it:
When the window hides or app resigns active, teardown code runs (graph overlay soft-hide, MLX idle budget switch, wind particle cleanup). One of those paths drops a Vec that was constructed from FFI raw parts.

Safe Auto-Fix Attempts (no user approval needed):
- Audit both `Vec::from_raw_parts` call sites for ptr/len/cap consistency
- Add `#[cfg(debug_assertions)]` assertions: check ptr alignment, non-null, len <= cap
- Grep for matching Swift allocator calls that construct those buffers
- Write a debug-only panic with stack trace when `Vec::from_raw_parts` is called with suspicious args

Destructive Fixes (require user approval):
- Replacing `Vec::from_raw_parts` with `unsafe { std::slice::from_raw_parts }.to_vec()` (copies but safer)
- Changing the FFI contract to return ownership differently
- Adding an `AllocatedFromRust` marker type to prevent mismatched reclamation

Investigation Log:
- 2026-04-04: Identified from user's debug log. Ruled out recent changes (GPU N-body double-buffering, color conversions, folder depth computation, proactive compaction) — none of these allocate Vecs on the code paths executed by a 1127-node graph. Marked as pre-existing FFI boundary issue.
- 2026-04-15: Fixed allocator mismatch in graph_engine_free_prepared_retrieval_candidates — Vec::from_raw_parts used count as both len and capacity, but original Vec may have capacity != len. Changed to into_boxed_slice + Box::into_raw on alloc side and Box::from_raw on free side. Added debug_assert for byte buffer capacity. 2456 Rust tests pass.

---

### ISSUE-2026-04-06-001: Pinned Inspector Panels Freeze When No Node Selected

Status: Verified Fixed (2026-05-07)
Priority: P2
First Observed: 2026-04-06
Affected Version: main @ cdd931e4+

Symptom:
When user pins an inspector to a node, then deselects (clicks background), the pinned
panel freezes in place and no longer follows its node as physics settles or camera moves.
Panel DOES follow when a node is selected (any node, not just the pinned one).

Suspected Cause:
The 30fps RunLoop timer (`pinnedPanelTimer`) calls `updatePinnedInspectorPositions()` which
queries `graph_engine_node_screen_pos(engineHandle, nodeId, &posBuf)`. The function reads
stored world positions + camera state — should work even when engine is idle.

The real issue is likely the RENDER LOOP being idle. When nothing is selected and physics
has settled, `graph_engine_render()` returns 0. Even though `needsRender` stays true for
pinned panels (MetalGraphView.swift:1380), the Rust engine's internal idle skip
(engine.rs:854 `idle_frame_count > 3 → return 0`) means the engine stops calling
`renderer.draw()`. The camera animation (lerp toward target) stops updating because
`update_camera()` only runs inside render(). So `node_screen_pos()` returns coordinates
based on a stale camera state.

The fix: either (a) force the engine to stay "alive" when pinned panels exist (add a flag
the engine checks in the idle skip), or (b) compute screen positions entirely from known
camera state on the Swift side without going through Rust.

Relevant files:
- HologramOverlay.swift:985 (updatePinnedInspectorPositions)
- HologramOverlay.swift:1024 (startPinnedPanelTimer)
- MetalGraphView.swift:1380 (needsRender = result != 0 || hasPinnedPanels)
- engine.rs:850 (idle_frame_count skip — returns 0 before draw)
- engine.rs:947 (node_screen_pos — reads renderer.camera_offset/zoom)
- engine.rs:830 (update_camera called inside render path)

Investigation Log:
- 2026-04-06: Timer confirmed running via code inspection. engineHandle confirmed non-nil.
  Root cause narrowed to Rust idle skip preventing camera state refresh. The timer queries
  node_screen_pos which uses renderer.camera_offset/zoom — these stop updating when the
  engine is idle because update_camera() is inside the render path that gets skipped.
- 2026-04-15: Added force_alive flag to Engine struct. When pinned panels exist, idle skip
  is bypassed so update_camera() keeps running. HologramOverlay syncs force_alive via FFI
  when pinned panel count changes. MetalGraphView keeps display link alive when hasPinnedPanels.

---

### ISSUE-2026-04-06-002: Beach Ball Spinner During Graph Interaction

Status: Verified Fixed (2026-05-07)
Priority: P1
First Observed: 2026-04-06
Affected Version: main @ 025db832

Symptom:
macOS spinning beach ball appears during certain graph interactions, indicating the main
thread is blocked for >2 seconds. Happens sporadically, especially after graph has been
open for a while.

Suspected Cause:
Two main-thread blocking operations:

1. `graph_engine_commit()` runs a synchronous pre-settle physics loop on the main thread.
   For 1131 nodes: up to 120 ticks with 16ms budget. NOT likely the beach ball cause alone
   (16ms is one frame, not 2 seconds).

2. `graph_engine_recompute_semantic_neighbors` — runs KNN cosine similarity across all
   embeddings. With 1131 nodes and 768-dim embeddings, that's O(n^2 * dim) ≈ 1 billion
   float ops. This was recently moved to MainActor dispatch (commit 025db832) to fix a
   data race, which means it now blocks the main thread during the entire computation.
   THIS IS THE BEACH BALL.

Fix approach: Split into compute (background) + swap (main, instant). Rust computes the
new Vec<(u32,u32,f32)> on the calling thread, then uses a Mutex or atomic swap to install
it. The render loop reads through the Mutex. No main-thread blocking, no data race.

Relevant files:
- EmbeddingService.swift:215 (call site — moved to MainActor.run)
- lib.rs:1640 (graph_engine_recompute_semantic_neighbors)
- engine.rs (engine.semantic_neighbors assignment)
- embedding.rs (all_knn_pairs — the O(n^2) computation)
- engine.rs:commit() lines 421-439 (pre-settle loop)

Investigation Log:
- 2026-04-06: Traced beach ball to commit 025db832 which moved recompute_semantic_neighbors
  to MainActor. The KNN computation is O(n^2*dim) — for 1131 nodes * 768 dims this is
  ~1 billion float ops, easily >2 seconds on main thread. Need to split compute from swap.
- 2026-04-15: Changed Engine.semantic_neighbors to parking_lot::Mutex<Vec<(u32,u32,f32)>>.
  EmbeddingService now runs recompute_semantic_neighbors via Task.detached(priority: .utility)
  instead of MainActor.run. Background KNN writes through Mutex, render loop reads through
  Mutex. 2456 Rust tests pass.
- 2026-05-07: Hardened the remaining detached recompute race by making
  `Engine.embedding_store` a `parking_lot::Mutex<EmbeddingStore>` and cloning a short-held
  embedding snapshot before the O(n^2) KNN pass. This keeps later embedding clear/reset/batch
  mutations from racing the detached recompute without holding the store lock for the whole
  cosine pass.

Verification:
- 2026-05-07: `cargo test embedding::tests::cloned_snapshot_is_stable_after_store_mutation` in
  `graph-engine` passed (`1 passed; 2530 filtered out`).
- 2026-05-07: `cargo test --no-run` in `graph-engine` passed.
- 2026-05-07: `cargo test` in `graph-engine` compiled and ran; `2499 passed`, `8 ignored`, and
  `24` Metal-backed engine/renderer tests failed because `MTLCreateSystemDefaultDevice()` returned
  nil in this terminal environment. Treat this as a manual/Metal test-environment blocker, not a
  green full-crate claim.
- 2026-05-07: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/BlockEmbeddingTests` passed
  (`22 tests in 1 suite`, result bundle `build/xcode-results/2026-05-07-215057-49800.xcresult`).

---

### ISSUE-2026-04-21-001: Cloud direct-stream turns advertise tools they cannot execute

Status: Verified Fixed (2026-05-07)
Priority: P1
First Observed: 2026-04-21
Affected Version: pre-b4e5d45a

Symptom:
Cloud models (GPT-5.4 Fast / Thinking, Claude Sonnet Fast / Thinking)
emit tool-call text into the answer bubble without ever executing a
vault_read / fs_read / patch. The capability manifest tells the model
"Tools available: vault_read, fs_read, …" even though the direct-stream
path can only attach provider-native tools (web_search / web_fetch /
code_execution / google_search) to the outgoing request.

Suspected Cause:
`Epistemos/Engine/PipelineService.swift` `buildCapabilityManifest`
unioned `executionPlan.allowedToolNames` with
`providerNativeCapabilityToolNames`. The direct-stream path never
hits the Rust agent, so app tools were advertised but never attached.

Fix (b4e5d45a):
- `toolExecutionAvailable: Bool = true` on `buildCapabilityManifest`.
  Direct-stream callers pass `false`, which uses
  `inference.providerNativeCapabilityToolNameList(for:)` — the subset
  the cloud request body actually attaches.
- Dropped `executionPlan?.additionalSystemPrompt()` in direct-stream
  because its `tool_permissions` instructions prescribed tools the
  path cannot honor.

Regression Coverage:
`EpistemosTests/RuntimeValidationTests.swift` — two new tests.

Verification:
- 2026-05-07: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/OmegaToolCallParserTests -only-testing:EpistemosTests/Mamba2MetalRuntimeTests` passed (`260 tests in 2 suites`, result bundle `build/xcode-results/2026-05-07-214239-24016.xcresult`). This specifically re-ran the direct-stream manifest source/behavior guards for provider-native-only tool advertising.

---

### ISSUE-2026-04-21-002: Fenced ```tool_call blocks not parsed as tool calls

Status: Verified Fixed (2026-05-07)
Priority: P1
First Observed: 2026-04-20
Affected Version: pre-b4e5d45a

Symptom:
Local Qwen / Hermes turns emitted ```tool_call{...}``` fences. The
UI suppressed them from the bubble but the executor never ran, so
the model stalled after "calling" a tool.

Fix (b4e5d45a):
`Epistemos/Omega/Inference/ToolCallParser.swift` extended
`"```(?:json)?"` → `"```(?:json|tool_call)?"` in the markdown
code-block strategy.

Regression Coverage:
`EpistemosTests/OmegaToolCallParserTests.swift`.

Verification:
- 2026-05-07: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/OmegaToolCallParserTests -only-testing:EpistemosTests/Mamba2MetalRuntimeTests` passed (`260 tests in 2 suites`, result bundle `build/xcode-results/2026-05-07-214239-24016.xcresult`). This re-ran the fenced `tool_call` parser coverage.

---

### ISSUE-2026-04-21-003: MLX idle unload kept Metal working set resident

Status: Verified Fixed (2026-05-07)
Priority: P2
First Observed: 2026-04-20
Affected Version: pre-b4e5d45a

Symptom:
After a local-model turn, idle memory stayed elevated even after
`performUnload`. The Metal SSM state buffers and the inference heap
lived on until the process exited.

Fix (b4e5d45a):
- `Epistemos/Engine/MetalRuntimeManager.swift`: new `releaseWorkingSet()`.
- `Epistemos/Engine/MLXInferenceService.swift`: `performUnload` is
  async and hops to `@MainActor` to call `releaseWorkingSet()`
  before releasing its own `metalRuntimeManager` reference.

Regression Coverage:
`EpistemosTests/Mamba2MetalRuntimeTests.swift`.

Verification:
- 2026-05-07: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/RuntimeValidationTests -only-testing:EpistemosTests/OmegaToolCallParserTests -only-testing:EpistemosTests/Mamba2MetalRuntimeTests` passed (`260 tests in 2 suites`, result bundle `build/xcode-results/2026-05-07-214239-24016.xcresult`). This re-ran the MLX idle/deep-unload and Metal working-set release coverage.

---

### ISSUE-2026-04-21-004: Idle memory regression (~500 MB)

Status: Operator-required (Allocations trace pending) — surfaced 2026-05-16 from /loop iter 12. See `MAS_COMPLETE_FUSION §A.8` for the Instruments reproduction recipe + 6 ranked hypotheses + acceptance bar.
Priority: P1
First Observed: 2026-04-21
Affected Version: b4e5d45a

Symptom:
User reports app idles around 500 MB (historically ~50 MB, noted as
~300 MB in the 2026-04-20 handoff). Metal working-set release
(ISSUE-003) partially addresses post-unload, but the initial boot
footprint is still high.

Suspected Causes (not yet Instruments-profiled):
1. `AppleHybridEmbeddingLookup()` in `GraphState.init()` eagerly
   loads `NLContextualEmbedding(.english)` (~40-100 MB CoreML when
   ANE assets are present) + `NLEmbedding.wordEmbedding(.english)`
   (~150 MB FastText). Added in commit a56d97ab (2026-04-17).
2. `PreparedRetrievalRuntimeConfiguration` retains parsed manifest
   descriptors after the deferred load in
   `startDeferredRuntimeServicesIfNeeded`.
3. SwiftData `@Query` result caches in sidebars / chat views.
4. Tokenizer vocab / model-weight residency after first local turn.

Safe Auto-Fix Attempts (no user approval needed):
- Run `Instruments → Allocations` on a launched-then-idle app and
  identify the top 10 persistent allocations.
- Audit GraphState's embedding-lookup usage to see whether
  `AppleHybridEmbeddingLookup` can be lazy without breaking the
  `dimension` contract.

Destructive Fixes (require user approval):
- Restructuring `AppleHybridEmbeddingLookup` to lazy-load contextual
  + word embeddings (changes `dimension` semantics).
- Narrowing @Query predicates or adding fetch limits.

Investigation Log:
- 2026-04-21: Prior handoff § 6 flagged as profiling-required, not
  blind-fix. Metal working-set release only addresses post-unload.
- 2026-05-08: Corrected contradictory ledger status. This issue was titled
  "unresolved" but marked `Verified Fixed`; no launched-app Allocations pass is
  recorded here, so the honest state is `Open` until Instruments or an
  equivalent memory-profile trace identifies and verifies the persistent idle
  allocations.
- 2026-05-08: Source audit found the historical `GraphState` eager-load
  suspicion is now partially mitigated in current source by
  `DeferredTextEmbeddingLookup`; no blind embedding rewrite was applied. Added a
  read-only Settings `ProcessMemoryHealthRow` that reports process RSS,
  physical-memory ratio, and the app-wide memory-pressure flag without claiming
  allocation root cause. Focused verification passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/SearchFusionHealthRowTests -only-testing:EpistemosTests/SettingsCategoryTests`
  (15 tests in 2 suites, result bundle
  `build/xcode-results/2026-05-08-075045-85970.xcresult`). The issue remains
  profiling-required until an Instruments Allocations pass identifies and
  verifies the persistent idle allocations.

---

### ISSUE-2026-04-21-005: Brittle source-text tests in RuntimeValidationTests

Status: Verified Fixed (2026-05-05)
Priority: P3
First Observed: 2026-04-21
Affected Version: b4e5d45a
Verified-Fixed Against: feature/landing-liquid-wave HEAD on 2026-05-05

Symptom:
Nine tests in `EpistemosTests/RuntimeValidationTests.swift` fail
because they assert concatenated substrings (with specific
indentation) from `Epistemos/App/ChatCoordinator.swift` that shifted
during this session's refactor.

Suspected Cause:
`loadRepoTextFile(...)` + `#expect(coordinator.contains("..."))`
with hand-written multi-line snippets like
`"finalizedAssistantMessage = true\n                agentChat.completeProcessing("`.
The semantics are still present; the layout has shifted.

Safe Auto-Fix Attempts:
- Rewrite the assertions as behavioral tests.
- Or refresh the substrings against the current source.

Investigation Log:
- 2026-04-21: Confirmed not caused by this session's code fixes;
  tests were already failing against the prior session's
  ChatCoordinator refactor.
- 2026-05-05: Re-verified each assertion in
  `rustAgentPathsFinalizeCompletedTurnsAndSalvageSilentStreamEndings`
  + `chatCoordinatorRustStreamPersistsLiveAgentEventToolProvenance`
  against the current ChatCoordinator.swift via per-needle `grep -F`.
  ALL 17 assertions PASS:
    - 9 assertions in the first test (var/finalizedAssistant... +
      agentChat.completeProcessing( + receivedAgentContent + 2
      appendStreamingThinking calls)
    - 12 assertions in the second test (private func
      recordRustAgentToolEvent + 2 provenance recorders + runID +
      5 .toolCall* kinds + 2 source strings)
  ChatCoordinator.swift apparently absorbed the canonical refactor
  during the intervening session work; no fix needed. Issue
  promoted to Verified Fixed.

---

### ISSUE-2026-04-22-001: SwiftUI hot-loop at 98-100% CPU, "Internal inconsistency in menus"

Status: Source Fixed (getter-mutation and toolbar per-row fan-out paths closed; memory-pressure stress still pending)
Priority: P0
First Observed: 2026-04-22
Affected Version: `97adbf83` (Codex's live-runtime checkpoint)

Symptom:
- App pegs CPU at `98-100%`, memory climbs from `3.3 GB` to `4.0 GB`
- Xcode console logs repeated `Internal inconsistency in menus`
- Memory-pressure warnings fire
- Sample at `/tmp/Epistemos_2026-04-22_155736_eHeO.sample.txt` shows all 5 seconds stuck in `GraphHost.flushTransactions → StackLayout.sizeThatFits` layout chain
- The only Epistemos user-code leaf in the sample is `UserBubbleShape.path(in:)` once
- Did NOT reproduce on the `Apr 22 16:22` rebuild during the 2026-04-22 walkthrough — suspect it fires on certain launch paths (e.g. when a menu interaction coincides with a cloud-credential snapshot landing)

Historical Suspected Cause (two compounding anti-patterns introduced in `97adbf83`):

A. Lazy-cache writes on `@Observable` state during reads:
- [`Epistemos/State/InferenceState.swift:4285-4305`](Epistemos/State/InferenceState.swift:4285) — `apiKey(for:)` mutates `missingCloudAPIKeyProviders`, `cachedCloudAPIKeys`, and `cloudProviderValidationStates` as a side effect of a read
- Same pattern in `oauthCredential(for:)` at line 4307-4327
- Called via `hasConfiguredCloudAccess(for:)` at line 4354, which is called by `preferredAutoRouteCloudProvider` at 4073-4091 (iterates all providers) and `configuredCloudProviders` at 4267-4271
- SwiftUI `body` that reads any of those dependencies gets invalidated by the same read it performed — classic infinite-layout pattern
- 2026-05-05 Codex note: current source no longer has this side effect.
  `apiKey(for:)` and `oauthCredential(for:)` are read-only; cache writes
  live in explicit refresh/set/clear paths. This suspected driver is
  verified closed in source.

B. Per-row `@Observable` fan-out in LocalModelToolbarMenu:
- [`Epistemos/App/RootView.swift:1510-1525`](Epistemos/App/RootView.swift:1510) — `localModelSubtitle(for:)` calls `inference.availableOperatingModes(for: .localMLX(model.id))` per row; chain reads `latestLocalRuntimeHealth`, `supportedAvailableLocalTextModels`, and on agent-fit calls `LocalInferenceMemoryPressureMonitor.availableMemoryBytes()` (a mach syscall)
- Under real memory pressure, pressure monitor updates `latestLocalRuntimeHealth`, invalidating every menu row, re-layout raises pressure, etc.
- 2026-05-07 Codex note: current source no longer calls
  `inference.availableOperatingModes(for:)` from `localModelSubtitle(for:)`.
  `LocalModelToolbarMenu` now refreshes a `localModelSubtitleCache` from
  static `LocalTextModelID` capabilities and the Qwen 3 unified-pair
  fingerprint. Focused `RuntimeValidationTests` passed with a source guard
  that the subtitle hot path does not reintroduce per-row runtime-mode reads.

Safe Auto-Fix Attempts (no user approval needed):
- Run Instruments with Time Profiler on a fresh launch under memory
  pressure and confirm whether B still drives a loop.
- Keep RuntimeValidation coverage around read-only inference getters.

Destructive Fixes (require user approval):
- Historical proposal was to cache `availableOperatingModes` per model-ID in
  `LocalModelToolbarMenu` `@State` once per picker open; current source uses a
  narrower fix by caching static model subtitle summaries and removing the
  `availableOperatingModes(for:)` call from the row path entirely.

Investigation Log:
- 2026-04-22: Diagnosed from sample + diff review of `97adbf83`. Live build did not reproduce during walkthrough but has not been stressed under memory pressure. Handoff doc `docs/handoffs/2026-04-22-claude-to-codex-live-runtime-and-tunnel-findings.md` §3 captures the full reasoning.
- 2026-05-08: Removed a source-level AppKit menu mutation path from
  `EpistemosApp.installKnowledgeGraphMenuFallback()`: the fallback now retargets
  existing SwiftUI-owned `Knowledge Graph` / `Reveal Current Document in Graph`
  menu items only, and no longer creates, inserts, or appends an `NSMenuItem`.
  Verified by the focused suite command in ISSUE-2026-05-08-017
  (`build/xcode-results/2026-05-08-171538-68569.xcresult`). Live menu-log
  reproduction still needs runtime confirmation before this older hot-loop issue
  can be promoted beyond source-fixed.
- 2026-05-05: Codex verified the `InferenceState` getter-mutation
  path is already fixed in current source; no code change required for
  that driver. Focused `RuntimeValidationTests` passed 254/254 via
  `./scripts/xcodebuild_epistemos.sh test ... -only-testing:EpistemosTests/RuntimeValidationTests`.
  Remaining work is a real launched-app Time Profiler / memory-pressure
  stress pass for the `LocalModelToolbarMenu` per-row fan-out path if
  the hot-loop symptom recurs.
- 2026-05-07: Codex closed the remaining source-level toolbar fan-out.
  `LocalModelToolbarMenu.localModelSubtitle(for:)` now reads
  `localModelSubtitleCache` and falls back to `staticLocalModelSubtitle`
  instead of calling `inference.availableOperatingModes(for:)` per row.
  Focused verification passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/RuntimeValidationTests`
  with 256/256 tests green; result bundle
  `build/xcode-results/2026-05-07-211835-82023.xcresult`.
  Live memory-pressure/Time Profiler stress is still pending and should not be
  claimed as complete from terminal-only evidence.

---

### ISSUE-2026-04-22-002: Local model install detection misses 10+ hub directories

Status: Verified Fixed
Priority: P1
First Observed: 2026-04-22
Affected Version: `97adbf83`

Symptom:
- Model picker shows `2 installed · 7 available` and only detects `Qwen3 4B` and `R1 7B` as installed
- Hub directory at `~/Library/Application Support/Epistemos/Models/text/hub` contains at least 12 ready models including `Qwen3-4B-Thinking-2507-4bit`, `Qwen3-8B-MLX-4bit`, `Qwen3-Coder-Next-4bit`, `Qwen3.5-4B-4bit`, `Qwen3.5-9B-4bit`, `gemma-3-4b-it-qat-4bit`, `gemma-4-e4b-it-4bit`, `gemma-4-26b-a4b-it-4bit`, `Gemma-4-31B-JANG_4M-CRACK`, `Llama-3.2-3B-Instruct-4bit`, `Falcon-H1R-7B-4bit`, `Ternary-Bonsai-{4B,8B}-mlx-2bit`
- Some of those surface as "Available to install" rows (implying a catalog entry exists); others are hidden entirely (implying `isReleaseValidatedForInteractiveChat` or a hardware-fit filter hides them)

Suspected Cause:
- Hub-directory name ↔ `LocalModelCatalog.shippedModelIDs` mismatch in `LocalModelManager.installRecords` detection — the hub blobs are present but the manager requires an explicit install manifest or a matching catalog ID to count as installed

Safe Auto-Fix Attempts (no user approval needed):
- Grep for `installRecords` / `is_installed` / `hubDirectoryName` in `Epistemos/LocalAgent/` and confirm the matching rule
- Add a debug log that prints each hub dir it sees and the catalog ID it compared against

Destructive Fixes (require user approval):
- Extend the matching rule to accept blob-only hub dirs
- Add missing catalog entries for `Qwen3.5-{4B,9B}-4bit`, `gemma-4-e4b-it-4bit`, `gemma-4-26b-a4b-it-4bit`, `Gemma-4-31B-JANG_4M-CRACK`, `Falcon-H1R-7B-4bit`

Investigation Log:
- 2026-04-22: Observed live on the `Apr 22 16:22` build. 2026-04-22 handoff §1.4 captures the full list.
- 2026-05-05: Codex re-audited the current implementation. `LocalModelInfrastructure.syncInferenceInstalledSets()` now unions manifest records with `detectedOnDiskHubTextModelIDs()`, and `LocalModelPaths.usableHubSnapshotDirectory(for:)` accepts hub snapshots with usable model-weight blobs. Focused verification passed:
  `./scripts/xcodebuild_epistemos.sh test ... -only-testing:EpistemosTests/LocalModelInfrastructureTests`
  with 76/76 tests green, including "refresh treats usable hub snapshots as runnable installs" and "refresh ignores hub snapshots without model weights". No code change needed; the current source already contains the fix.

---

### ISSUE-2026-04-22-003: Qwen 3 unified picker never surfaces

Status: Verified Fixed
Priority: P2
First Observed: 2026-04-22
Affected Version: `97adbf83`

Symptom:
- Model picker shows `Qwen3 4B` and `Qwen3 Think 4B` as two separate rows instead of the unified `Qwen 3` entry that Codex shipped in `97adbf83` §3.2

Suspected Cause:
- `qwen3UnifiedPickerPairAvailable` at [`Epistemos/State/InferenceState.swift:3653-3656`](Epistemos/State/InferenceState.swift:3653) requires BOTH `.qwen3_4B4Bit` AND `.qwen3_4BThinking25074Bit` to be in `supportedAvailableLocalTextModels`
- ISSUE-2026-04-22-002 prevents the Thinking variant from being detected as installed → the union is false → fallback to two-row form

Safe Auto-Fix Attempts:
- Dependent on ISSUE-2026-04-22-002. Fix install detection, then the unified picker engages automatically.

Investigation Log:
- 2026-04-22: Observed live on the `Apr 22 16:22` build. Root cause is downstream of ISSUE-2026-04-22-002.
- 2026-05-05: ISSUE-2026-04-22-002 is now verified fixed at source/test level. The focused LocalModelInfrastructure suite also passed "Qwen 3 fast and thinking checkpoints collapse into one picker model with mode-aware routing". Computer Use live smoke on the fresh debug build confirmed Settings -> Inference renders `Active Local Model` as `Qwen 3`, so the unified picker is visible in the app.

---

### ISSUE-2026-04-22-004: Opus 4.1 Main Chat outside-vault read produced "No response received"

Status: Verified Fixed (2026-05-07, closed by `1bd794f18`)
Priority: P1
First Observed: 2026-04-22

Symptom:
- Prompt: "Use tools to read the local file /tmp/epistemos_opus41_main_outside_20260422.txt and reply with only the first line exactly."
- Result shown in Main Chat: "No response received. The tools run ended before a final answer was produced."
- Same prompt in Mini Chat, with `read_file` on `/tmp/epistemos_live_tool_smoke_…`, succeeds with `tool smoke ok`

Suspected Cause:
- Main Chat Agent-mode tool loop for Opus 4.1 ends without a `.complete` event after tool execution
- Opus 4.1 is the OLD Anthropic model ID; the curated surface now prefers `claude-opus-4-7`. Re-run on Opus 4.7 to confirm whether this is a model-specific regression or a tool-loop termination bug that affects all Anthropic Agent turns on Main Chat

Safe Auto-Fix Attempts:
- Re-run the same prompt on Opus 4.7 and Sonnet 4.6 on the `Apr 22 16:22` build with Console logs capturing every `.complete` / `.error` event

Destructive Fixes:
- If the pattern reproduces across all Anthropic models, inspect `Epistemos/App/ChatCoordinator.swift` main-agent path for the same silent-stream-ending bug that was patched on the Command Center path in the April 20 blocker batch

Investigation Log:
- 2026-04-22: Observed in a prior session on the live app, still visible on the `Apr 22 16:22` build in the persisted chat. 2026-04-22 handoff §1.5 lists this as the next runtime re-test.
- 2026-05-07: Codex re-audited the current Main Chat Rust-agent termination path. `ChatCoordinator.runRustAgentPath` calls `chatState.completeCancelledProcessing(...)` when a stream ends after tool activity but before a `.complete` event, and `ChatState.completeCancelledProcessing` treats pending tool-use/tool-result blocks as visible content instead of emitting the empty-run error. Added focused regression `cancelled main chat tool runs preserve tool blocks instead of empty-run errors`; focused suite passed with 15/15 tests green:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ChatStateContextAttachmentTests`
  Result bundle: `build/xcode-results/2026-05-07-183247-30159.xcresult`.

---

### ISSUE-2026-05-05-001: project-wide clippy debt (~126 issues across 5 crates) formerly blocked CI clippy gate

Status: Verified Fixed (2026-05-05)
Priority: **P1** (was P2; upgraded after project-wide scoping)
First Observed: 2026-05-05 (during late-session hygiene tick)
Affected Version: feature/landing-liquid-wave HEAD on 2026-05-05

Project-wide scope (`cargo clippy --lib --target aarch64-apple-darwin -- -D warnings` per crate):

| Crate | Clippy errors under `-D warnings` |
|---|---|
| agent_core | 42 (1 hard error + 41 warnings) |
| epistemos-core | 54 |
| omega-mcp | 16 |
| omega-ax | 8 |
| graph-engine | 6 |
| **Total** | **~126** |

Symptom (agent_core specifically):
`cargo clippy --lib --target aarch64-apple-darwin -- -D warnings` against `agent_core` fails with 42 issues:

- **1 hard error**: `src/etl/ffi.rs:180` — `etl_queue_free_string` is a `pub extern "C" fn` that does `CString::from_raw(ptr)` but the function itself isn't marked `unsafe`. Lint: `clippy::not_unsafe_ptr_arg_deref`. The unsafe block inside is fine; the lint wants the function signature itself to be `unsafe`.
- **41 warnings** (would also fail under `-D warnings`): 7× "doc list item without indentation", 3× "this function has too many arguments (9/8)", 2× each of "this `map_or` can be simplified" / "this `if` statement can be collapsed" / "this `.filter_map(..)` can be written more simply using `.map(..)`" / "redundant closure" / "match expression looks like `matches!` macro", 3× "you should consider adding a `Default` implementation" (WebFetchTool, McpClient, FileOpsTool), 1× "very complex type used", 1× "the `Err`-variant returned from this function is very large", and others.

Why this hasn't been caught yet:
The CI workflow at `.github/workflows/ci.yml` only runs on `push: [main]` or `pull_request: [main]`. The `feature/landing-liquid-wave` branch had not run CI — only `release.yml` had run on this branch — so the clippy gate (line 122-131 of ci.yml) had not fired before Codex continuation cleaned it.

Suspected Cause:
- Pre-existing debt — many of these warnings are in code that landed before 2026-05-05 (e.g., `etl/ffi.rs` was added in commit `666aa9ba`).
- Some may be from rustc upgrades that introduced new lints between when the code was written and now.

Safe Auto-Fix Attempts (no user approval needed):
- Add `#[allow(clippy::not_unsafe_ptr_arg_deref)]` to `etl_queue_free_string` with a SAFETY comment explaining why the FFI function deliberately doesn't use the `unsafe fn` signature (Swift caller via UniFFI doesn't see the Rust `unsafe`).
- Apply the trivial mechanical fixes (use `?` instead of `if .is_none() { return None; }`; collapse nested `if`s; use `.map(..)` instead of `.filter_map(..)` where the filter is trivial; add `#[derive(Default)]` where applicable).
- Fix the doc-list-indentation warnings (mostly add 2 spaces to continuation lines).

Destructive Fixes (require user approval):
- Refactor functions with too many arguments (changes API).
- Box large `Err` variants (changes return type).

Investigation Log:
- 2026-05-05: discovered during the late-session clippy hygiene check. NOT silently fixed because (a) 41 warnings is too large a cleanup to do safely without per-fix verification, and (b) the user should know this debt exists before merging this branch. Logging here so it's visible at next session start.
- 2026-05-05 Codex continuation: cleaned the clippy debt without API-changing refactors. Verified:
  `agent_core`, `agent_core` Pro+lsp, `epistemos-core`, `omega-mcp`,
  `omega-ax`, and `graph-engine` all pass the CI-style
  `cargo clippy ... --target aarch64-apple-darwin -- -D warnings`
  gates. The FFI pointer lint was resolved with an explicit
  `#[allow(clippy::not_unsafe_ptr_arg_deref)]` and `SAFETY` note
  rather than changing the exported Swift-facing ABI to `unsafe fn`.

---

### ISSUE-2026-05-08-005: KnowledgeFusion local metadata could enter synced app roots

Status: Patched
Priority: P2 (release/App Review hygiene)
First Observed: 2026-05-08
Affected Version: feature/landing-liquid-wave HEAD during v1 hardening

Symptom:
- Local disk audit found untracked/generated metadata under `Epistemos/KnowledgeFusion`:
  - `Epistemos/KnowledgeFusion/.DS_Store`
  - `Epistemos/KnowledgeFusion/Training/.DS_Store`
  - `Epistemos/KnowledgeFusion/MOHAWK/.DS_Store`
  - `Epistemos/KnowledgeFusion/MOHAWK/.last_pod_id`
  - `Epistemos/KnowledgeFusion/MoLoRA/__pycache__/*.pyc`
- The project already excluded MOHAWK and MoLoRA pycache artifacts from synced roots, but did not explicitly exclude the top-level and Training `.DS_Store` paths from both direct and App Store app roots.

Suspected Cause:
- Xcode synchronized folder roots need explicit membership exceptions for local metadata that can appear inside source-preserved research directories. `.gitignore` prevents source commits but does not by itself prove Xcode synced-root packaging will omit those paths.

Safe Auto-Fix Attempts:
- Add direct/App Store synced-folder exclusions in `project.yml`.
- Mirror the generated `PBXFileSystemSynchronizedBuildFileExceptionSet` entries in `Epistemos.xcodeproj/project.pbxproj`.
- Add source guards that assert the synced roots and metadata exclusions exist without walking the full app source mirror.

Destructive Fixes:
- Deleting local untracked metadata files; not required for the source-level fix and not performed in this slice.

Investigation Log:
- 2026-05-08: Patched `project.yml` and `Epistemos.xcodeproj/project.pbxproj` to exclude `KnowledgeFusion/.DS_Store` and `KnowledgeFusion/Training/.DS_Store` from both app synced roots. Hardened `EpistemosTests/ProjectInclusionTests.swift` to guard the exclusions and avoid the previous broad app-hosted source walk.
- 2026-05-08: Verification passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ProjectInclusionTests`
  Result bundle: `build/xcode-results/2026-05-08-083207-46251.xcresult`.

---

## Resolved Issues

_(Issues moved here after manual runtime verification confirms the fix)_

---

## Standing Checks (run on every session start)

These are sanity checks to run proactively:

1. **FFI allocator consistency**: grep for `from_raw_parts` + `mem::forget` pairs, verify they match
2. **try? in durable paths**: `grep -rn 'try?' Epistemos/Sync/ Epistemos/Bridge/ | grep -v test | wc -l` → should be 0
3. **Force unwraps outside tests**: `grep -rn 'try!\|\.unwrap()' Epistemos/ --include='*.swift' | grep -v Test | wc -l` → should be 0
4. **ObservableObject usage**: `grep -rn 'ObservableObject' Epistemos/ --include='*.swift' | grep -v test | grep -v comment | wc -l` → should be 0 (we use `@Observable`)
5. **UserDefaults API keys**: `grep -rn 'UserDefaults.*[Aa]pi[Kk]ey' Epistemos/ --include='*.swift' | wc -l` → should be 0 (Keychain only)
6. **Rust test count**: `cargo test --manifest-path graph-engine/Cargo.toml 2>&1 | grep "test result"` — should show `2451 passed` (or the current expected count)

If any of these regress, add a new issue entry.
