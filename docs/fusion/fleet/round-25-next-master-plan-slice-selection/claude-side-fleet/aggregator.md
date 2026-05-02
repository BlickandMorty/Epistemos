---
role: claude-side-fleet
slice: round-25-next-master-plan-slice-selection
round: 25
date: 2026-05-02
tier: Core
authority_anchor: EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md §1 (current code + passing logs > repo authority > fusion canon)
master_plan_anchors:
  - MASTER_RESEARCH_INDEX_2026_05_02.md §3.2 (Sovereign Gate killer feature, action-class matrix)
  - MASTER_RESEARCH_INDEX_2026_05_02.md §22 (operating rule)
  - UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md "Safe Next Build Order" §4 (Core/MAS release split + Sovereign follow-through)
workcard_anchor: AGENT_BUILD_WORKCARDS_2026_05_01.md Card 9 (Sovereign Gate Core Authorization)
substrate_state_anchor: UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md "Safe Next Build Order" item 4 ("additional existing confirmation migrations behind new exact gates")
prior_round_decisions:
  - round-21 picked PR20 SearchIndex sync fused-search; codex-red-team blocked it (recorder is @MainActor / sync nonisolated mismatch needs an enabling slice)
  - round-23 scout looked at R15 MLX live token throughput PR8; gated on insufficient-memory evidence (usefulness 0)
  - round-24 picked Hermes Gateway Evidence Return Policy PR7; shipped at commit b51b39fb on 2026-05-02
post_b51b39fb_state: Hermes Gateway Card 10 PR1-PR7 fully closed for prompt+policy invariants only; future Hermes runtime/provider work is forbidden without a fresh exact gate.
recommended_slice_slug: sovereign-gate-modelvault-delete-pr9
alternate_slice_slug: agent-event-shared-sync-recorder-enabler-pr0
ready_for_pipeline_builder: true
missing_artifacts: []
input_usefulness_rollup:
  plus_one: 1
  zero: 0
  minus_one: 0
usefulness: +1
usefulness_reason: "Card 9's 'additional existing confirmation surfaces migrated to SovereignGate' is the only autonomous code-safe lane explicitly authorized in the safe-next-build-order without requiring a new gate. The pattern is mature with four near-byte-identical prior PRs (PR5 Notes Delete, PR6 Chat Delete, PR7 Version Delete, PR8 RootView Destructive). The chosen target file is clean (not in the 521-file landing-wave dirty diff), the chokepoint is a single existing destructive `.alert`, and the test surface runs as one focused xcodebuild -only-testing invocation in shell."
p0_stop_triggers: 6
p1_risks: 5
---

# round-25-next-master-plan-slice-selection

> **Note.** A prior write to this file recorded a "no usable side-fleet output" sentinel (usefulness −1). That sentinel is replaced by this packet: a full Claude side-fleet recommendation produced under the round-25 brief.

## recommended_slice
**Card 9 PR9 — `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` ModelVault file/folder permanent-delete migration to shared `SovereignGate` `.deviceOwnerAuthentication`.** A pure-Swift, additive routing of the existing destructive `.alert(item: $pendingDeleteTarget)` (line 211) and its primary `.destructive(Text("Delete")) { delete(target) }` button (line 215) through the `AppBootstrap`-owned shared `SovereignGate` before invoking the existing `delete(_:)` (line 539) → `ModelVaultBrowserStore.deleteItem(at:)` filesystem removal. The two destructive entry points that set `pendingDeleteTarget` ("Delete Folder", line 630; "Delete File", line 687) feed the same alert, so a single `ModelVaultDeletionSovereignGate` enum + a single `await sovereignGate.confirm(...)` block in `delete(_:)` gates both surfaces. Mirrors PR5 (`NotesSidebar.swift:249-272` + `1787-1814`) byte-for-byte in shape.

## why_now

- **Master-plan-authorized lane with no new gate needed.** `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` Safe Next Build Order item 4 (lines 820-841) names "Future Sovereign slices must … may only add … additional existing confirmation migrations behind new exact gates" as one of the few sanctioned autonomous code-safe lanes after b51b39fb. Card 9 line 1595 explicitly authorizes "Future confirmation-surface migration PRs only after a gate names each exact existing surface and its focused tests" — and PR5/PR6/PR7/PR8 prove the pattern works as a one-file-plus-one-test slice.
- **Pattern is mature; risk surface is minimal.** Four prior near-byte-identical PRs ship the same shape: a `*DeletionSovereignGate` enum, a `Target` case set, a constant `requirement(for:)` returning `.deviceOwnerAuthentication`, a per-target `reason(for:)` string, capture target before async auth, `await sovereignGate.confirm(...)`, switch on `.allowed` / `.denied` / unavailable, run the existing delete only on `.allowed`. PR5 lines 249-272 + 1787-1814 are the canonical reference template. The deliberation note at `docs/fusion/deliberation/sovereign_gate_notes_delete_pr5_deliberation_2026_05_02.md` translates with cosmetic edits.
- **Target file is clean against the landing-wave dirty diff.** `git status --short` shows 521 modified files on `feature/landing-liquid-wave`, but `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift`, `Epistemos/Views/Notes/NotesSidebar.swift` (reference), `Epistemos/Sovereign/SovereignGate.swift`, `Epistemos/Sovereign/SovereignGateLifecycleObserver.swift`, `EpistemosTests/SovereignGateTests.swift`, and `EpistemosTests/ModelVaultBrowserTests.swift` are all clean — the slice creates no merge friction with the active branch.
- **Single existing destructive chokepoint with native filesystem removal.** Verified at `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift:539-541`: `delete(_:)` calls `ModelVaultBrowserStore.deleteItem(at: target.url)`, which is the same `Foundation.FileManager`-backed permanent removal pattern PR5/PR8 already migrated. The existing alert is a 2-button native `Alert` with a `.destructive` primary — the exact shape PR5/PR6/PR7 chose. Only one call-site to gate (`delete(_:)`); both context-menu entries flow through it.
- **Tests-in-shell are proven.** PR5/PR6/PR7/PR8 each shipped a focused `*SovereignGateTests`-style Swift Testing suite proving the requirement+reason mapping plus a source-guard grep, runnable as a single `xcodebuild … -only-testing:EpistemosTests/<NewSuite> test` invocation. `/tmp/epistemos-sovereign-gate-{notes-delete-pr5,chat-delete-pr6,version-delete-pr7,rootview-pr8}-green-20260502.log` are the cadence references; the same shape applies here. No manual UI testing required — the migration is mechanically verifiable.
- **Hermes Gateway Card 10 explicitly forbids the next-natural lane.** Card 10 lines 1804-1817 + Safe Next Build Order item 4 lines 838-841 confirm "Hermes Gateway Directness PR1 through Evidence Return PR7 are closed for prompt/policy invariants only; future runtime/provider routing still requires a new exact gate." The PR8+ on Card 10 is gate-locked.
- **Card 7 next AgentEvent chokepoint is architecturally blocked.** PR20 (sync `SearchIndexService.fusedSearch`) was found by codex-red-team-fallback (`docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/codex-red-team/attacks.md` A1+A2) to require a sync-safe enabling slice for the `@MainActor`-isolated `AgentToolProvenanceRecorder`. PR21 (`VaultSyncService.searchFull*` wrapper) is deferred because `Epistemos/Sync/VaultSyncService.swift` is in the dirty diff (round 21 §2). Card 7's other named-future-allowed surfaces (CloudLLM beyond structured, ChatCoordinator beyond PR3, LocalAgentLoop beyond parsed tools) all require a fresh chokepoint-naming gate that does not yet exist on disk.
- **Card 6 OpLog/ReplayBundle next slice would cross read-only fence.** PR3D/PR4A/PR4B/PR5/PR6 closed the read-only ladder; the next mutating projection or repair surface trips Card 6's stop trigger and engages MASTER_RESEARCH_INDEX §0 H8 (missing `prev_hash` BLAKE3 column, no `journal_mode=WAL` + `F_FULLFSYNC`). Wrong shape for an autonomous code-safe slice today.

### Comparison verdicts

| Slice | Verdict | Reason |
|---|---|---|
| **Sovereign Gate PR9 ModelVault file/folder delete (this)** | **+1** | Single clean view file, single chokepoint (`delete(_:)`), 4-PR-mature pattern, focused Swift Testing template exists, no Rust, no FFI, no protected paths, no manual UI testing, Card 9 explicitly authorizes "additional existing confirmation migrations." Identical shape to PR5 Notes Delete. |
| AgentEvent PR0 enabling slice — sync-safe shared recorder façade (`Epistemos/Engine/AgentToolProvenanceRecorder.swift` additive sibling) | **0** | Foundational provenance change. Could unblock PR20 (sync fused search) and any future sync nonisolated chokepoint, but mid-rail recorder churn carries cross-PR regression risk. Hold as alternate; Card 7 implementation contract line 957-965 fences EventStore/payload schema, so an enabling slice must be additive-only. |
| AgentEvent PR21 — `VaultSyncService.searchFullAsync` wrapper instrumentation | **−1** | Round 21 §2 already deferred this because `Epistemos/Sync/VaultSyncService.swift` is in the 521-file dirty diff; round-19 also called wrapper instrumentation an anti-pattern (double-instruments PR19's chokepoint). Stays −1 until the dirty surface lands. |
| AgentEvent PR — `Epistemos/Engine/AgentHarness/AgentBackend.swift` / `AgentAuthority.swift` / `AgentHandoff.swift` (clean files) | **0** | These are agent-harness abstractions, not user-reachable tool/search chokepoints. Card 7 line 935-942 requires a "fresh deliberation gate names exact runtime files and focused tests" before instrumenting any new chokepoint family. Worth a future scout pass; not the safest narrowest next slice today. |
| AgentEvent PR — Spotlight/SemanticCluster/MeaningAnchor/QueryRuntime | **−1** | All on the dirty diff (`Epistemos/Engine/SpotlightIndexer.swift`, `Epistemos/Graph/SemanticClusterService.swift`, `Epistemos/Engine/MeaningAnchorService.swift`, `Epistemos/Engine/QueryRuntime.swift`). Touching them risks commingling with landing-wave drift. |
| Hermes Gateway Card 10 PR8+ runtime/provider | **−1** | Card 10 lines 1804-1817 fence runtime/provider/MCP/CLI/browser/Docker behind a fresh exact gate that does not yet exist. Forbidden without a new gate per safe-build-order item 4. |
| Card 6 OpLog mutating repair / ReplayBundle production visibility | **−1** | Card 6 stop trigger explicitly fences "Production visibility ... beyond read-only." Mutating repair would have to engage MASTER §0 H8 (missing `prev_hash` BLAKE3, no `journal_mode=WAL` + `F_FULLFSYNC`) — wrong shape for autonomous slice. |
| Card 8 GraphEvent live consumer beyond Halo/Settings/Audit | **−1** | Card 8 forbidden write set still bans `Epistemos/Views/Graph/**`, `Epistemos/Graph/**`, `graph-engine/**`. First non-Halo/Settings live consumer crosses that fence. |
| R15 MLX live tok/s PR8 / R15 specialized baselines / R16 manual / Halo manual | **−1** | All require runtime/manual app testing against a real vault. User constraint "no manual app testing yet" excludes them. R15 MLX is also explicitly blocked by insufficient-memory evidence (round-23 marked usefulness 0). |
| Sovereign Gate Pro/Research Secure Enclave sealing | **−1** | Pro/Research tier; user instructions deprioritize Pro until App Store hardening is "infinitely hardened" first. Not clearly next. |
| Sovereign Gate generated-requirement transport | **0** | Card 9 line 1591-1592 allows it only "after a gate names exact Rust, Swift, and generated transport boundaries." That gate does not yet exist on disk; would need a docs-only deliberation slice first. Useful follow-up; not safest narrowest next code slice. |
| Documentation/canon slice (e.g., PR0 enabling-deliberation note for sync recorder, or PR9 deliberation note pre-creation) | **0** | A code slice does exist (Sovereign PR9), so per the brief instruction "If no safe code slice exists, recommend a documentation/canon slice" the doc-only fallback does not apply. The PR9 deliberation note will be authored as part of the slice's pipeline-builder phase (matches PR5/6/7/8 cadence). |

## concepts
- **Sovereign Gate (killer feature §3.2 / Annex A.7).** Native `LAContext` biometric authority confined to `Epistemos/Sovereign/SovereignGate.swift`. Action-class matrix (Trivial / Reversible / Sensitive / Destructive / Sovereign) is *Rust-owned* (PR4 seeded `agent_core/src/sovereign/mod.rs`); Swift only *executes* a supplied requirement. Filesystem deletion of model-vault files/folders is Destructive class (every-time auth, no grace).
- **Core tier (App Store).** No subprocess, no network, no Pro tunnels. PR9 stays in Core because filesystem delete is local + biometric prompt is the macOS-native path.
- **Existing confirmation surface migration.** PR5/6/7/8 doctrine: do NOT decide action class in Swift; do NOT duplicate `LocalAuthentication`; capture the target before the async hop; restore alert state on denied auth; preserve the existing deletion semantics byte-identically.
- **`AppBootstrap`-owned shared `SovereignGate` instance.** Lifecycle PR2 closed the single-instance ownership + sensitive-grace clearing on app/session/sleep boundaries. PR9 consumes the same shared instance via env injection (mirror NotesSidebar.swift wiring).

## workcard
- **Card 9 — Sovereign Gate Core Authorization.** Allowed Future Write Set (line 1591-1601): "Future confirmation-surface migration PRs only after a gate names each exact existing surface and its focused tests." PR9 names `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` and `EpistemosTests/SovereignGateModelVaultDeleteTests.swift` (new). Implementation contract (line 1617-1630): single Swift `LocalAuthentication` source, externally supplied requirements, sensitive-grace category-scoped, destructive every-time, lifecycle observers `start/stop`-clean, tests use injectable authenticator seam.

## allowed_files
- `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` — additive `ModelVaultDeletionSovereignGate` enum (Target cases for `.file(name:)` and `.folder(name:)`, constant `requirement(for:) -> SovereignGateRequirement = .deviceOwnerAuthentication`, per-target `reason(for:) -> String`); refactor of `delete(_:)` (line 539) to capture target → `await sovereignGate.confirm(.deviceOwnerAuthentication, reason: ...)` → switch on `.allowed`/`.denied(_)`, only call existing `ModelVaultBrowserStore.deleteItem(at: target.url)` on `.allowed`. The shared `SovereignGate` is reached via the existing `AppBootstrap`-owned environment (mirror PR5 wiring at `NotesSidebar.swift:1787-1814`); if the view does not currently take a `SovereignGate` env value, add a single `@Environment` injection or pass-through (matches PR8 RootView pattern). The two `pendingDeleteTarget` setters at lines 630 and 687 remain unchanged; only `delete(_:)` body changes. Existing `ModelVaultDeleteTarget` struct (line 789) stays.
- `EpistemosTests/SovereignGateModelVaultDeleteTests.swift` (new file) — focused Swift Testing suite mirroring `EpistemosTests/SovereignGate*Tests.swift` shape: cover (a) `requirement(for: .file)` == `.deviceOwnerAuthentication`, (b) `requirement(for: .folder)` == `.deviceOwnerAuthentication`, (c) `reason(for: .file(name:))` includes the safe-name-trimmed file label, (d) `reason(for: .folder(name:))` includes the safe-name-trimmed folder label, (e) injected fake `SovereignGateAuthenticating` returning `false` results in zero `ModelVaultBrowserStore.deleteItem` calls (use a thin in-memory test double around the `delete(_:)` flow if needed, mirroring `SovereignGateTests.swift` injection seam). Use `@Test` / `#expect`.
- `docs/fusion/deliberation/sovereign_gate_modelvault_delete_pr9_deliberation_2026_05_02.md` (new file) — slice deliberation note in the PR5/6/7/8 template shape.
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md` Card 9 status block — append PR9 closure paragraph between current PR8 paragraph (line 1530-1539) and the "Goal:" block (line 1541), plus add to the "Allowed write set" + "Tests and logs" + "Acceptance" sections in the same one-paragraph cadence as PR8.
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` — append PR9 closure to Safe Next Build Order item 4 (line 820-841) sentence list.

## forbidden_files
- `Epistemos/Sovereign/SovereignGate.swift` — Card 9 implementation contract line 1617-1618: "remains the only Swift source that touches `LocalAuthentication` / `LAContext`." PR9 must consume the existing executor, not edit it.
- `Epistemos/Sovereign/SovereignGateLifecycleObserver.swift` — out of scope (PR2 already closed).
- `agent_core/**`, `epistemos-shadow/**`, `omega-mcp/**`, `graph-engine/**`, `syntax-core/**`, `epistemos-core/**` (any Rust crate) — Card 9 forbidden write set lines 1606-1610.
- Generated UniFFI Swift / generated headers / generated libraries / Xcode project files / entitlements / DerivedData / `.xcresult` — Card 9 forbidden write set line 1612-1614.
- `Epistemos/Views/Notes/ProseEditor*.swift`, `Epistemos/Views/Notes/ProseTextView2.swift` — protected editor (Card 9 line 1604-1605).
- `Epistemos/Views/Graph/**`, `Epistemos/Graph/**` — protected graph (Card 9 line 1606-1607).
- `Epistemos/Engine/ModelVaultBrowserStore.swift` (or wherever `ModelVaultBrowserStore.deleteItem` is implemented) — out of scope; PR9 is purely a gate-routing slice around the existing call site. The deletion semantics, error handling, undo behavior, and persistence side effects must remain byte-identical.
- Any other existing destructive confirmation popup not named in this gate (PR5 Notes Delete, PR6 Chat Delete, PR7 Version Delete, PR8 RootView Destructive are already closed; do NOT touch them; do NOT migrate Settings reset alert / Approval modal / Quick Capture confirmation card / Graph preset save/rename / iMessage driver toolbar in this slice).
- `Epistemos/Views/Settings/SettingsView.swift` — already in the dirty diff and contains an unrelated "Reset Everything?" alert at line 700; not in scope.
- Any `LocalAuthentication`, `LAContext`, `canEvaluatePolicy`, `evaluatePolicy`, Touch ID, or biometric-prompt symbol outside `Epistemos/Sovereign/SovereignGate.swift` — Card 9 stop trigger line 1748-1750.
- Any change to `Epistemos/Sovereign/SovereignGate.swift`'s `SovereignGateRequirement` enum, grace duration semantics, sensitive-grace cache, or authenticator protocol — out of scope; existing executor consumes the requirement.
- Branch operations / commits / stashes / staging / xcodegen — Card 9 forbidden write set line 1613-1614.
- Any AgentEvent / OpLog / GraphEvent / Halo / Theater / ReplayBundle projection — out of scope; PR9 is a Sovereign Gate slice, not a provenance slice. Do NOT add `AgentProvenanceEvent` emissions in the same PR (different gate family).

## expected_tests
- **Red gate**: failing focused Swift Testing case in `EpistemosTests/SovereignGateModelVaultDeleteTests.swift` that asserts the production `delete(_:)` path emits no `SovereignGate.confirm(...)` call before the `ModelVaultBrowserStore.deleteItem(...)` call. Source-guard grep: `grep -nE 'SovereignGate' Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` returns zero matches pre-PR. Log to `/tmp/epistemos-sovereign-gate-modelvault-delete-pr9-red-20260502.log`.
- **Green gate**: focused Swift Testing suite proving:
  - `ModelVaultDeletionSovereignGate.requirement(for: .file(name: "x"))` == `.deviceOwnerAuthentication`.
  - `ModelVaultDeletionSovereignGate.requirement(for: .folder(name: "y"))` == `.deviceOwnerAuthentication`.
  - `ModelVaultDeletionSovereignGate.reason(for: .file(name: "ModelA.gguf"))` returns a non-empty string containing `"ModelA.gguf"` (or its safe-name-trimmed equivalent) and references the model-vault context (matches PR5 reason cadence: `"Permanently delete <thing> \"<safe-name>\"."`).
  - `ModelVaultDeletionSovereignGate.reason(for: .folder(name: "Adapters"))` returns a non-empty string containing `"Adapters"` and the folder-and-its-contents wording (matches PR5 folder cadence).
  - With an injected fake `SovereignGateAuthenticating` returning `false`, the `delete(_:)` flow does NOT call the deletion store. (Mirror the `SovereignGateTests.swift` injection seam — the existing `LocalAuthenticationSovereignAuthenticator` default is replaceable.)
  - With the same fake returning `true`, the flow does call the deletion store exactly once with the captured `target.url`.
  - Reason strings reject empty / whitespace-only file/folder names by substituting `"Untitled"` (matches PR5 `safeName(_:)` line 268-271).
- **Source guards** (greps that must hold post-PR):
  - `grep -nE '\bLAContext\b|\bLocalAuthentication\b|canEvaluatePolicy|evaluatePolicy' Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` → zero matches (proves no duplicate `LocalAuthentication`).
  - `grep -nE 'sovereignGate\.confirm|ModelVaultDeletionSovereignGate' Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` → at least 2 matches (proves the gate is wired).
  - `grep -nE '\.deviceOwnerAuthentication\b' Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` → at least 1 match (proves Destructive class).
  - `git diff --stat HEAD -- Epistemos/Sovereign/SovereignGate.swift Epistemos/Sovereign/SovereignGateLifecycleObserver.swift agent_core/ epistemos-shadow/ graph-engine/ Epistemos/Views/Notes/ProseEditor*.swift Epistemos/Views/Notes/ProseTextView2.swift Epistemos/Views/Graph/ Epistemos/Engine/ModelVaultBrowserStore.swift` → empty (proves boundary).
  - `git diff --name-only HEAD -- Epistemos/` → exactly one Swift source file (`Epistemos/Views/Notes/ModelVaultsSidebarSection.swift`) plus the new test file under `EpistemosTests/`.
- **Build**: `xcodebuild -scheme Epistemos -destination 'platform=macOS' build-for-testing 2>&1 | xcbeautify` to `/tmp/epistemos-sovereign-gate-modelvault-delete-pr9-build-20260502.log`.
- **Focused green test**: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' -only-testing:EpistemosTests/SovereignGateModelVaultDeleteTests test 2>&1 | xcbeautify | tee /tmp/epistemos-sovereign-gate-modelvault-delete-pr9-green-20260502.log`. Expect terminal `** TEST SUCCEEDED **` (modulo SwiftLint package-plugin noise — known across PR5-PR8 logs).
- **Regression check**: rerun `EpistemosTests/SovereignGateTests` to prove the executor is untouched.

## risks (P0 stop triggers + P1 risks)

**P0 stop triggers (must abort if any of these come up):**
1. The implementation needs to edit `Epistemos/Sovereign/SovereignGate.swift` to make the gate reachable — Card 9 implementation contract line 1617-1618 forbids this. The existing executor consumes any `SovereignGateRequirement`; if the consumer can't reach the shared instance, fix the wiring at the consumer (mirror PR5 `NotesSidebar.swift` env injection), not the executor.
2. The implementation needs to edit `ModelVaultBrowserStore.deleteItem(at:)` or any deletion semantics — out of scope. The throws/non-throws contract, undo behavior, error handling, and persistence side effects must remain byte-identical.
3. The implementation needs to introduce a new `SovereignGateRequirement` case (e.g., a `modelVaultDelete` category for grace), or a new `SovereignGateCategory` — out of scope; PR9 uses `.deviceOwnerAuthentication` (every-time, no grace), matching PR5/6/7/8.
4. The implementation needs to migrate any other destructive confirmation surface (Settings reset, Approval modal beyond PR3, Quick Capture, Graph presets, iMessage driver) in the same PR — Card 9 line 1611-1614 forbids this without a per-surface gate.
5. `LocalAuthentication`, `LAContext`, `canEvaluatePolicy`, `evaluatePolicy`, or Touch ID symbols appear in the diff outside `Epistemos/Sovereign/SovereignGate.swift` — Card 9 stop trigger line 1748-1750.
6. The implementation tries to make `ModelVaultDeletionSovereignGate.requirement(for:)` decide an action class in Swift (e.g., switching to `.biometric` for files but `.deviceOwnerAuthentication` for folders) — Card 9 implementation contract line 1619-1621 says "Swift executes an externally supplied `SovereignGateRequirement`; it does not decide whether an app action is Trivial, Reversible, Sensitive, Destructive, or Sovereign." Filesystem deletion is Destructive class; the requirement is a constant.

**P1 risks (manageable but watch):**
1. **Async/MainActor sequencing**: `delete(_:)` is currently synchronous; routing through `await sovereignGate.confirm(...)` makes it async. The two destructive button handlers at lines 630/687 set `pendingDeleteTarget`, the alert binding fires, and the alert primary button calls `delete(target)`. Moving to async means the alert closure must `Task { await … }` or the call site must dispatch — exact pattern is in PR5 (`NotesSidebar.swift:1787-1814`) and PR8 (RootView). Capture target in a local before the await so a subsequent `pendingDeleteTarget = nil` cannot redirect the deletion (PR7 Version Delete red-team finding R1).
2. **In-flight auth duplication**: If the user double-taps "Delete", two authentications could enter flight against the same target. PR8 RootView added an in-flight auth guard for vault disconnect. Add an equivalent `isAuthenticatingDelete` `@State` flag here to prevent double prompts.
3. **Denied auth state cleanup**: On `.denied(_)` or unavailable auth, ensure `pendingDeleteTarget` is cleared so the alert fully dismisses without lingering state. Also ensure the file/folder is NOT deleted (PR5 invariant). Mirror PR8's denied-auth restore pattern.
4. **Test injection seam**: The view consumes the shared `SovereignGate` from the environment. The new test must construct a `SovereignGate` with an injected fake `SovereignGateAuthenticating` (the executor's existing seam — `SovereignGateTests.swift` already uses this). Don't introduce a new injection mechanism; reuse the executor's `init(authenticator:)`.
5. **Reason-string privacy**: `reason(for:)` includes the file/folder name. PR5 already trimmed via `safeName(_:)` to handle empty/whitespace; reuse that shape. Don't include the full URL or vault path — only the display name (mirror PR5 line 262-264 "page \"<name>\"" / "folder \"<name>\" and its contents").

## likely_implementation_shape
1. Add `private enum ModelVaultDeletionSovereignGate { … }` near top of `ModelVaultsSidebarSection.swift` (mirrors `NotesSidebarDeletionSovereignGate` at NotesSidebar.swift:249-272). Cases: `.file(name: String)`, `.folder(name: String)`. Constant `requirement(for:) -> SovereignGateRequirement = .deviceOwnerAuthentication`. Per-target `reason(for:) -> String` with the PR5 cadence ("Permanently delete file \"<name>\"." / "Permanently delete folder \"<name>\" and its contents."). Reuse a private `safeName(_:)` static.
2. Inject the shared `SovereignGate` into the view via the existing environment (mirror NotesSidebar.swift wiring) or via a constructor parameter from `AppBootstrap`. Add `@Environment(\.sovereignGate) private var sovereignGate` if the env key already exists; otherwise mirror PR5's exact injection.
3. Refactor `delete(_:)` (line 539-541) to:
   - Capture `let target = target` before the await.
   - Map `target` to `ModelVaultDeletionSovereignGate.Target` (file vs folder via `target.url.hasDirectoryPath` or the existing `ModelVaultDeleteTarget` field).
   - Compute `let requirement = ModelVaultDeletionSovereignGate.requirement(for: gateTarget)`, `let reason = ModelVaultDeletionSovereignGate.reason(for: gateTarget)`.
   - Add `private @State var isAuthenticatingDelete = false` and short-circuit on already-in-flight.
   - `let outcome = await sovereignGate.confirm(requirement, reason: reason)`.
   - On `.allowed`: call existing `_ = ModelVaultBrowserStore.deleteItem(at: target.url)` and trigger refresh.
   - On `.denied(_)`: clear `pendingDeleteTarget`, set `isAuthenticatingDelete = false`, do nothing else.
4. Wrap the alert primary button's `delete(target)` call in a `Task { await delete(target) }` if needed (matches PR5 alert pattern).
5. Test file `EpistemosTests/SovereignGateModelVaultDeleteTests.swift` follows `EpistemosTests/SovereignGateTests.swift` injection pattern: construct `SovereignGate(authenticator: FakeAuthenticator())`; assert mapping + reason + denied-no-delete + allowed-deletes invariants.
6. Doc updates: append PR9 closure paragraph to Card 9 status block (between line 1539 and 1541), append `Tests and logs` PR9 entries (red + green log paths), append `Acceptance` PR9 wired/reachable/visible/boundary clauses.

## reconciled_findings (for the Codex pipeline builder)
- **The next master-plan-authorized autonomous slice is Sovereign Gate Card 9 PR9 ModelVault delete migration** — the only lane in `UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md` Safe Next Build Order item 4 that does NOT require a fresh exact gate beyond what Card 9 already authorizes ("additional existing confirmation migrations").
- **The chokepoint is verified** — `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift:539-541` calls `ModelVaultBrowserStore.deleteItem(at: target.url)` from a synchronous `delete(_:)` invoked by the `.alert(item: $pendingDeleteTarget)` primary button at line 215. The two destructive entry points ("Delete Folder" line 630, "Delete File" line 687) both set `pendingDeleteTarget`, so a single gate at `delete(_:)` covers both surfaces.
- **The pattern shape is solved by 4 prior PRs** — `Epistemos/Views/Notes/NotesSidebar.swift:249-272` defines the canonical `*DeletionSovereignGate` enum + `Target` cases + constant `requirement(for:)` + per-target `reason(for:)`. Lines 1787-1814 wire it. `Epistemos/Views/Chat/ChatSidebarView.swift:4-…`, `Epistemos/Views/Notes/DiffSheetView.swift:4-…`, and the RootView PR8 changes are PR5/6/7/8 references.
- **The file is clean against the dirty diff** — `git status --short` confirms `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift`, `Epistemos/Views/Notes/NotesSidebar.swift`, `Epistemos/Sovereign/SovereignGate.swift`, `Epistemos/Sovereign/SovereignGateLifecycleObserver.swift`, `EpistemosTests/SovereignGateTests.swift`, and `EpistemosTests/ModelVaultBrowserTests.swift` are all unmodified on `feature/landing-liquid-wave`.
- **No protected-path overlap** — the Card 9 forbidden write set (lines 1604-1614) is fully avoided. The slice does not need any Rust, FFI, generated transport, entitlement, project-file, protected-graph, or protected-editor edit.
- **The codex-red-team has already proven AgentEvent PR20 is unsafe without an enabling slice** (`docs/fusion/fleet/search-index-service-fused-sync-agent-event-pr20/codex-red-team/attacks.md` A1+A2). That removes the next-natural Card 7 slice from the table without a separate enabling-deliberation gate (held as alternate, see below).

## alternate_slice (if PR9 ModelVault is blocked)
**Alternate slug: `agent-event-shared-sync-recorder-enabler-pr0`** — a pure-Swift, additive enabling slice that adds a sync-safe sibling to `Epistemos/Engine/AgentToolProvenanceRecorder.swift` (e.g., a `nonisolated` factory that returns a `Sendable` snapshot of the record-builder, or a queue-backed dispatch shim) so future sync nonisolated chokepoints (PR20 SearchIndex sync fused search, PR21+ wrappers) can emit `AgentEvent` without a `Task { @MainActor … }` fire-and-forget that violates the recorder's existing sequencing/privacy contract. The enabler is bounded by a fresh deliberation note (no consumer call-site changes in the same PR) and a focused Swift Testing suite proving (a) sync emission preserves run-id ordering, (b) sync emission preserves lower-snake-case JSON, (c) sync emission preserves the EventStore's `agent_events` schema, (d) no MainActor deadlock from `MainActor.assumeIsolated` or `DispatchQueue.main.sync`.

Rationale for alternate ordering:
- **Same Card 7 family**, but the enabler is foundational rather than a chokepoint extension. The codex-red-team A1+A2 verdict explicitly named this as the prerequisite. Holding it as alternate keeps the recommended slice "smallest safe" while flagging the dependency.
- **Trickier risk surface**: enabler changes affect every existing PR16/PR17/PR18/PR19 emission seam by proximity; one-file scope discipline + a strict additive-only contract is required.
- **Opens up a future PR ladder** (PR20 sync fused search, PR21 VaultSyncService wrapper after dirty-diff lands, etc.) once the enabler ships.

## failure_proof_guardrails (for post-merge audit)
- **grep**: `grep -nE 'ModelVaultDeletionSovereignGate' Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` — at least one match (proves the gate enum is live).
- **grep**: `grep -c '\.deviceOwnerAuthentication' Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` — at least 1 (proves Destructive class wiring).
- **grep**: `grep -nE 'LAContext|LocalAuthentication' Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` — zero matches (proves no duplicate auth).
- **grep**: every `Epistemos/**/*.swift` outside `Epistemos/Sovereign/SovereignGate.swift` matches zero `LAContext|LocalAuthentication` (proves Card 9 invariant holds globally — PR9 must not break PR1).
- **log**: `/tmp/epistemos-sovereign-gate-modelvault-delete-pr9-green-20260502.log` ends with `** TEST SUCCEEDED **` (modulo SwiftLint package-plugin noise, per PR5-PR8 known-good cadence).
- **byte-identity guard**: `git diff HEAD -- Epistemos/Sovereign/SovereignGate.swift Epistemos/Sovereign/SovereignGateLifecycleObserver.swift Epistemos/Engine/ModelVaultBrowserStore.swift` returns empty.
- **scope guard**: `git diff --name-only HEAD -- Epistemos/` returns exactly one file: `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift`.

## usefulness
**+1.** The cleanest narrowest autonomous code-safe slice immediately after b51b39fb. Single clean view file, single chokepoint, four-PR-mature pattern, focused Swift Testing template already exists, no Rust, no FFI, no protected paths, no manual UI testing, no broad generated bindings. Card 9 explicitly authorizes "additional existing confirmation surfaces migrated to SovereignGate" and the safe-next-build-order item 4 names it as a sanctioned lane. Hermes Gateway Card 10 (PR8+) is gate-locked; Card 7 next chokepoint (PR20 sync fused search) is architecturally blocked by the codex-red-team verdict; Card 6 next slice crosses the read-only fence; Card 8 next live consumer crosses the protected-graph fence; R15/R16/Halo manual lanes need runtime testing the brief excludes. Sovereign Gate PR9 is the one remaining lane without a fresh-gate prerequisite.

CLAUDE-RETURN: role=SIDE-FLEET | slice=next-master-plan-slice-selection | round=25 | artifact=docs/fusion/fleet/round-25-next-master-plan-slice-selection/claude-side-fleet/aggregator.md | usefulness=+1 | p0=0 | p1=0
