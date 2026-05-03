# Sovereign Gate Future Workcards — DRAFT — 2026-05-03

> **STATUS: DRAFT, NON-CANONICAL.** These cards are not approved for execution. They are derived from `SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md` §3 and §4 and follow the template in `AGENT_BUILD_WORKCARDS_2026_05_01.md`. Codex / user must approve each card before any agent picks it up. Until approved, do **not** stage to the canonical workcards file or open a deliberation slice from these.
>
> Doctrine §7 lane: Core killer-feature seed work — Sovereign Gate broader Core classes follow-through. Generated per `PARALLEL_WORK_MANIFEST.md` round-82 P2.

---

## How to read this draft

Each card below is a candidate Sovereign Gate slice extracted from the surface map. They are ordered by the recommended priority queue in `SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md` §5:

1. **SG-CARD-1** Adapter delete (S-1 from surface map) — HIGH risk, M effort
2. **SG-CARD-2** OAuth completion handler audit (S-5 from surface map) — read-only S effort
3. **SG-CARD-3** Keychain write site audit (S-6 from surface map) — read-only S effort
4. **SG-CARD-4** Block delete (S-3 from surface map) — MEDIUM risk, S–M effort, **coordination-required**
5. **SG-CARD-5** Lifecycle observer Sovereign-class extension (forward-looking) — L effort, depends on SG-CARD-1

Each card is a self-contained slice. The cards intentionally **do not chain** — any one can be picked up first, except SG-CARD-5 which must wait for SG-CARD-1 to ship.

---

## SG-CARD-1 — Knowledge Fusion adapter delete routes through Sovereign Gate

### Goal

Migrate the existing "Delete" button in `TrainingHistoryView.swift` from a fire-and-forget `vm.deleteAdapter(adapter)` call to a Sovereign-Gate-confirmed destructive action, mirroring the `ModelVaultDeletionSovereignGate` pattern that closed in PR9.

### Authority To Read First

- `docs/fusion/MASTER_RESEARCH_INDEX_2026_05_02.md` §3.2 (Sovereign Gate)
- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §4.2 + Annex A.7 (action-class matrix)
- `docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md` §3 S-1
- `Epistemos/Sovereign/SovereignGate.swift` (single-owner of LAContext)
- `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` lines around `requestDeleteAuthorization` (canonical pattern to mirror)
- `Epistemos/Views/Notes/ModelVaultsSidebarSection+SovereignGate.swift` if it exists, or the inline helper enum
- `Epistemos/KnowledgeFusion/UI/TrainingHistoryView.swift` lines 70–90 (current delete button)
- `EpistemosTests/SovereignGateTests.swift` test pattern for `modelVaultDeleteAlertRoutesThroughCapturedSovereignGateTarget`

### Allowed Write Set

- `Epistemos/KnowledgeFusion/UI/TrainingHistoryView.swift` (line 78 area only — replace `Task { await vm.deleteAdapter(adapter) }` body with `requestAdapterDeleteAuthorization(adapter)`)
- `Epistemos/KnowledgeFusion/UI/KnowledgeFusionAdapterDeletionSovereignGate.swift` (NEW — helper enum with `requirement(for:)` + `reason(for:)` mirroring `ModelVaultDeletionSovereignGate`)
- `EpistemosTests/KnowledgeFusionAdapterDeletionSovereignGateTests.swift` (NEW — tests requirement + reason + view-source-guard for `AppBootstrap.shared?.sovereignGate.confirm`)

### Forbidden Write Set

- `Epistemos/Sovereign/SovereignGate.swift`
- Any other file under `Epistemos/Sovereign/`
- `Epistemos/Views/Notes/ProseEditor*.swift`, `Epistemos/Views/Graph/MetalGraphView.swift`, `Epistemos/Views/Graph/HologramController.swift`
- `Epistemos/KnowledgeFusion/Service/*` (do not touch the actual training pipeline)
- Closed PR43 ClarifyPromptBridge files unless an approved future slice reopens them.
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`, `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md` (canon-in-flight)
- `Epistemos.xcodeproj/project.pbxproj`, `Cargo.toml`, `Package.swift`, build scripts (coordination-required)

### Implementation Contract

- The new helper enum `KnowledgeFusionAdapterDeletionSovereignGate` declares `case adapter(name: String)` and returns `.deviceOwnerAuthentication` from `requirement(for:)`.
- `reason(for:)` returns a human-readable string that names the adapter and includes the verb `permanently delete` (passes the doctrine §A.7 reason-text quality matrix).
- `TrainingHistoryView` adds a private `requestAdapterDeleteAuthorization(_:)` async method that calls `AppBootstrap.shared?.sovereignGate.confirm(...) ?? .denied(.authenticationFailed)` and only invokes `vm.deleteAdapter(adapter)` after `outcome == .allowed`.
- The button label and SwiftUI structure remain identical; only the action body changes.
- No new dependency on `LocalAuthentication` is introduced anywhere outside `Epistemos/Sovereign/`.

### Tests And Logs

- Red test command: `xcodebuild ... -only-testing:EpistemosTests/KnowledgeFusionAdapterDeletionSovereignGateTests` should fail before the helper enum exists.
- Focused test command after implementation: same as above; should pass.
- Source-guard test: assert `Epistemos/KnowledgeFusion/UI/TrainingHistoryView.swift` does not contain `LAContext`, `LocalAuthentication`, `canEvaluatePolicy`, or `evaluatePolicy` after the change.
- Existing `SovereignGateTests` regression: re-run `EpistemosTests/SovereignGateTests` to confirm no other helper regressed.
- Expected `/tmp/...log` names: `/tmp/epistemos-knowledge-fusion-adapter-sg-test-<timestamp>.log`.

### Acceptance

- New helper enum exists and matches the `ModelVaultDeletionSovereignGate` shape.
- New test file exists with at least: requirement-mapping test, reason-text quality test, source-scan test for no LAContext leakage in the view.
- `TrainingHistoryView.swift` line 78 area now routes through Sovereign Gate; the original `Task { await vm.deleteAdapter(adapter) }` invocation is gone from the button body.
- Focused test command passes.
- All existing `SovereignGateTests` still pass.

### Stop Triggers

- The helper would need to live outside `Epistemos/KnowledgeFusion/UI/` for any reason — escalate; the surface-map placement assumes co-location.
- A simpler "soft delete + 30-day undo" pattern surfaces during research and would obviate Sovereign routing — escalate.
- The training pipeline emits side effects (e.g., garbage-collected adapter caches) that would be left dangling by a denied delete — escalate; the contract above assumes deletion is atomic.

### Completion Report (template the agent must fill on close)

- Files changed
- Tests run
- Raw log paths
- WRV proof (visible Touch ID prompt + delete actually completes after Allow + denial path leaves the adapter intact)
- Remaining risks
- Rollback (`git revert <hash>`; the slice is purely additive aside from one button-body line)

---

## SG-CARD-2 — OAuth completion handler Sovereign Gate audit (research-only)

### Goal

Read-only audit: confirm whether the OAuth completion handler in `Epistemos/Engine/CloudProviderAuthService.swift` already routes through `SovereignGate.confirm`, and if not, name the smallest safe future PR slice to wire it.

### Authority To Read First

- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §A.7 (action-class matrix — OAuth scope grants are Sensitive)
- `docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md` §4 (sensitive non-destructive surfaces)
- `Epistemos/Engine/CloudProviderAuthService.swift` in full
- `Epistemos/Sovereign/SovereignGate.swift` for the available requirement shapes

### Allowed Write Set

- `docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_OAUTH_AUDIT_2026_05_03.md` (NEW — audit report only)

### Forbidden Write Set

- All Swift / Rust source files (research-only).
- `Epistemos/Sovereign/SovereignGate.swift` (single-owner; not in scope for this audit).
- Closed PR43 ClarifyPromptBridge files unless an approved future slice reopens them.
- Canon-in-flight docs.

### Implementation Contract

- The audit report names every OAuth completion site (callback URL handler, token exchange, scope confirmation alert).
- For each site, record: file:line, current Sovereign Gate routing (yes/no/partial), risk assessment, smallest future PR slice if a gap exists.
- If the audit finds zero gaps, say so explicitly and recommend closing the lane.

### Tests And Logs

- No tests; this is a research artifact.
- Expected `/tmp/...log` names: none.

### Acceptance

- New audit report exists.
- It cites at least one file:line per claim.
- It concludes either `gap-found-recommend-PR` (with named future slice) or `no-gap-close-lane`.

### Stop Triggers

- The audit reveals OAuth tokens are written to UserDefaults instead of Keychain — escalate as P0 security issue, do not record routinely.
- The audit reveals an unauthenticated callback URL handler — escalate as P0 security issue.

### Completion Report

- Files changed (one new doc only)
- Files read (full list)
- Verdict (gap or no-gap)
- Remaining risks

---

## SG-CARD-3 — Keychain write site audit (research-only)

### Goal

Read-only audit: per `CLAUDE.md` "API keys in macOS Keychain (SecItemAdd/SecItemCopyMatching), NEVER UserDefaults", verify every `SecItemAdd` / `SecItemUpdate` call site is biometric-gated (Sensitive class) or explicitly user-initiated through a Sovereign-routed UI.

### Authority To Read First

- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §A.7
- `docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md` §4
- `CLAUDE.md` Keychain rule
- All grep hits for `SecItemAdd`, `SecItemUpdate`, `SecItemCopyMatching`, `SecItemDelete` under `Epistemos/`

### Allowed Write Set

- `docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_KEYCHAIN_AUDIT_2026_05_03.md` (NEW — audit report only)

### Forbidden Write Set

- All Swift / Rust source files (research-only).
- Closed PR43 ClarifyPromptBridge files unless an approved future slice reopens them.
- Canon-in-flight docs.

### Implementation Contract

- The audit names every Keychain write/update/delete site with file:line.
- For each site, record: action (write/update/delete), data class (API key / OAuth token / vault credential / other), current Sovereign Gate routing, risk, smallest future PR slice if a gap exists.
- If a write goes to UserDefaults instead of Keychain, flag as P0.

### Tests And Logs

- No tests; this is a research artifact.

### Acceptance

- Audit report exists.
- Every Keychain write/update/delete site is enumerated.
- Report concludes either `gap-found-recommend-PR` (with named future slices) or `no-gap-close-lane`.

### Stop Triggers

- A Keychain credential is found being written via a non-Sovereign flow that the user did not explicitly initiate (e.g., background sync writes a new token) — escalate as P0.
- A credential write site uses UserDefaults instead of Keychain — escalate as P0 (CLAUDE.md violation).

### Completion Report

- Files read
- Sites found (count + per-site verdict)
- P0 escalations if any
- Recommended future PR slices

---

## SG-CARD-4 — Epdoc block delete Sovereign Gate routing (coordination-required)

### Goal

Add Sensitive-class (15-min grace) Sovereign Gate routing to the "Delete block" action in `EpdocBlockContextMenu.swift` line 139, matching the surface map S-3 recommendation. **Coordination-required**: confirm with Codex/user whether `Views/Epdoc/` is part of the protected `Views/Notes/ProseEditor*` family before any code edit.

### Authority To Read First

- `docs/fusion/fleet/sovereign-gate-surface-map/SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md` §3 S-3 (especially the coordination-required flag)
- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §6 protected-path list
- `docs/fusion/CODEX_FINAL_EXECUTION_PROMPT_2026_05_01.md` §7 protected-paths section
- `Epistemos/Views/Epdoc/EpdocBlockContextMenu.swift` in full
- `Epistemos/Views/Notes/ModelVaultsSidebarSection.swift` for the helper enum + view-side wiring pattern
- `Epistemos/Sovereign/SovereignGate.swift` for the `.biometric(category:graceDuration:)` shape

### Allowed Write Set

- (gated on coordination) `Epistemos/Views/Epdoc/EpdocBlockContextMenu.swift` (line 139 area only)
- `Epistemos/Views/Epdoc/EpdocBlockDeletionSovereignGate.swift` (NEW)
- `EpistemosTests/EpdocBlockDeletionSovereignGateTests.swift` (NEW)

### Forbidden Write Set

- `Epistemos/Views/Notes/ProseEditor*.swift` (always protected)
- `Epistemos/Views/Graph/MetalGraphView.swift`, `Epistemos/Views/Graph/HologramController.swift`
- `Epistemos/Sovereign/SovereignGate.swift`
- `Epistemos/Bridge/ClarifyPromptBridge.swift` (closed by Codex PR43; do not touch unless a future approved slice reopens it)
- Canon-in-flight docs
- All `Views/Epdoc/*.swift` files **other than** `EpdocBlockContextMenu.swift` until coordination confirms scope

### Implementation Contract

- New helper `EpdocBlockDeletionSovereignGate` returns `.biometric(category: SovereignGateCategory(rawValue: "epdoc-block-delete"), graceDuration: 15 * 60)` so a typing-flow user is not interrupted by Touch ID for every block delete within 15 minutes.
- The view's destructive button calls `requestBlockDeleteAuthorization { onDelete() }` instead of `onDelete()` directly.
- No new `LAContext` or `LocalAuthentication` import outside `Epistemos/Sovereign/`.

### Tests And Logs

- Red test command before implementation; focused test after.
- Source-guard tests: no LAContext leak in the view.
- `SovereignGateTests` regression.

### Acceptance

- Coordination confirmed BEFORE code edits.
- New helper exists with `.biometric` requirement.
- View edit complete; original `onDelete()` direct call gone.
- Tests pass.

### Stop Triggers

- Coordination check returns "yes, `Views/Epdoc/` IS protected" — stop; convert this card to a doc-only proposal for the user.
- The undo stack already covers block delete recovery and Touch ID feels like overkill — escalate to user for the action-class re-classification.

### Completion Report

- Coordination decision recorded
- Files changed
- Tests run
- Remaining risks
- Rollback

---

## SG-CARD-5 — Lifecycle observer Sovereign-class extension (forward-looking, depends on SG-CARD-1)

### Goal

Forward-looking design slice: extend `SovereignGateLifecycleObserver` to support a future Sovereign-class action (Secure Enclave seal release per doctrine §A.7) that survives lifecycle clearing within the same Sovereign session, while preserving today's Sensitive-class clearing on app/sleep boundaries.

### Authority To Read First

- `docs/fusion/EPISTEMOS_FINAL_DOCTRINE_2026_05_01.md` §A.7 + §4.2 (Sovereign vs Sensitive class distinction)
- `Epistemos/Sovereign/SovereignGateLifecycleObserver.swift`
- `Epistemos/Sovereign/SovereignGate.swift`
- `EpistemosTests/SovereignGateTests.swift` "Lifecycle observer clears sensitive grace" tests

### Allowed Write Set

- (PROPOSAL ONLY for first card iteration — do not edit code) `docs/fusion/deliberation/sovereign_gate_lifecycle_sovereign_class_extension_proposal_2026_MM_DD.md` (NEW)
- After deliberation gate: incremental code edits to `SovereignGateLifecycleObserver.swift` + new tests

### Forbidden Write Set

- `Epistemos/Sovereign/SovereignGate.swift` (the gate itself; Secure Enclave wiring is a separate slice)
- Canon-in-flight docs
- Closed PR43 ClarifyPromptBridge files unless an approved future slice reopens them

### Implementation Contract (proposal stage)

- Sovereign class survives `NSApplication.didResignActiveNotification` and `NSWorkspace.willSleepNotification` *only* within the same Touch ID-authenticated Sovereign session, and clears on `NSWorkspace.sessionDidBecomeActiveNotification` boundary changes.
- The proposal must explicitly note the Pro-tier dependency: Secure Enclave key release requires Pro entitlement (`cs.allow-jit` + `cs.allow-unsigned-executable-memory` per doctrine §3) and is not Core-buildable.

### Tests And Logs

- (proposal stage) None.
- (post-deliberation) New test in `EpistemosTests/SovereignGateLifecycleSovereignClassTests.swift`.

### Acceptance

- Proposal doc exists with: motivation, contract, tier impact, deliberation pre-reqs, named follow-up slices.
- Codex/user explicitly approve OR reject before code touches `SovereignGateLifecycleObserver.swift`.

### Stop Triggers

- SG-CARD-1 has not yet shipped — wait. Sovereign-class is a future Pro tier; without at least one Sovereign-routed Core surface, the lifecycle extension is premature.
- Pro entitlement bundle is not yet in the build matrix — defer.

### Completion Report (template)

- Proposal doc created (path)
- Decision recorded (approve / reject / revise)
- Follow-up slices named if approved

---

## Note on canonicality

Until Codex / user reviews this draft, none of these cards may be:

- Copied into `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- Used to open a `docs/fusion/deliberation/<slice>_deliberation_2026_05_03.md` slice
- Picked up by any parallel coding agent

When the user approves, the natural promotion path is: (a) move the approved card body into the canonical workcards file under a new "Card N — <title>" heading, (b) open a deliberation file per the standard process, (c) mark the corresponding row in `SOVEREIGN_GATE_SURFACE_MAP_2026_05_03.md` §5 with the assigned card number.

---

## Reservation respect

This draft was generated without editing any of:

- `Epistemos/Sovereign/SovereignGate.swift`
- `EpistemosTests/SovereignGateTests.swift`
- `Epistemos/Bridge/ClarifyPromptBridge.swift` (closed by Codex PR43)
- `EpistemosTests/ClarifyPromptBridgeAgentEventTests.swift` (closed by Codex PR43)
- `docs/fusion/UNIFIED_SUBSTRATE_CURRENT_STATE_2026_05_01.md`
- `docs/fusion/agent-build-scaffolding/AGENT_BUILD_WORKCARDS_2026_05_01.md`
- `docs/fusion/fleet/REGISTRY.md`
- Any current-slice deliberation file in `docs/fusion/deliberation/`
- Any current-round oversight file in `docs/fusion/oversight/`
- Protected paths: `ProseEditor*.swift`, `MetalGraphView.swift`, `HologramController.swift`, graph physics/render internals
- `project.pbxproj`, `Cargo.toml`, `Package.swift`, build scripts

No `xcodebuild` invocation. No code edit. No staging. No commit.
