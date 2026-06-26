# Hardening Ledger — Honest No-Vault Handling (2026-06-24)

> Implementation ledger for the FIRST small hardening slice of the
> full-clone native infusion cycle. Authority:
> `docs/handoffs/AUTHORITATIVE_FULL_CLONE_NATIVE_INFUSION_PLAN_2026_06_24.md` (#1),
> `docs/ACT_IP_PRESERVATION_2026_06_24.md`. This slice is Hardening-Cycle item #5
> ("make the no-vault state honest") and the direct follow-up to diag commit
> `8af17c841`.

## Why this slice first

The big clone/infusion cycle (OpenWork full port, native Act engine) must be
preceded by ONE hardening cycle. The lowest-risk, highest-leverage item is the
one the most recent commit literally just diagnosed:

- Diag `8af17c841`: Work shows **0 vault resources** not because of an MCP/fusion
  bug, but because **no active vault is selected**. `vaultSync.vaultURL` is nil →
  code silently falls back to the empty default `~/Documents/Epistemos` → OpenCode
  roots there → 0 resources, no `skills/`. MCP plumbing verified correct
  (initialize + tools/list = 23 tools; resources/list walks the vault root).
- `epistemos.backgroundIndexing.error = "No active vault selected"`,
  `hasEverConnectedAVault = 1` (so a vault WAS connected before, but is not active
  after rebuild → bookmark-restore suspect).

Fixing this unblocks every downstream proof in Phase 5
("prove no-vault state vs real MCP failure separately") and stops the whole
clone cycle from being debugged against a false "MCP broken" signal.

## Scope of this slice (intentionally narrow)

1. **Honest rooting**: when no vault is active, do NOT silently root OpenCode/MCP
   at the empty `~/Documents/Epistemos` default. Treat "no active vault" as a
   distinct, named state — not an MCP failure and not a fake-empty vault.
2. **Honest logging**: the diagnostic/log layer must clearly say "no active vault
   connected" vs. "MCP failure".
3. **Visible + actionable**: the Work status surface must show an honest
   "No active vault selected — connect a vault" call-to-action.
4. **Investigate bookmark restore** (read-only this slice): why a previously
   connected vault (`hasEverConnectedAVault=1`) is not active after rebuild.
   Document findings; only fix if low-risk and in-scope.

Out of scope for this slice: OpenWork port, native Act engine, Osaurus removal,
mini-session ontology. Those follow after the hardening cycle.

## Guardrails (from operator prompt + memory)

- Read every file before modifying. Use rg. Never `git add -A`.
- Narrowly scoped commits ONLY if explicitly requested (default: do not commit).
- CODE MORE BUILD LESS: fast gate first; heavy xcodebuild only at checkpoints;
  never idle-block on builds. User is at disk capacity.
- Do not mark anything done without code evidence + runtime evidence.
- Preserve Act IP; do not touch Osaurus removal preconditions.
- Do not touch the pre-existing dirty files (two `Localizable.xcstrings`).

## Recon (in flight — workflow `work-no-vault-honesty-recon`)

Four parallel read-only investigators mapping:
- A: OpenCode/Work vault rooting + the `~/Documents/Epistemos` fallback branch.
- B: active-vault state + security-scoped bookmark save/restore on launch.
- C: user-visible Work status surfaces (where to show the honest CTA).
- D: fusion/background-indexing "No active vault" error + log layer.

### Findings (recon `wf_84fd9b6b-759`, 4 read-only agents)

**A — the silent fallback (the core bug).** `WorkOpenCodeRuntime.swift:253` (pre-fix):
`let fusionVaultRoot = (epistemosVaultRoot ?? FirstRunBootstrap.defaultVaultURL()).path`.
When no vault is active, `vaultSync.vaultURL` is nil (RootView.swift:3887 passes it;
VaultSyncService.swift:401 owns it) → coalesces to the empty `~/Documents/Epistemos`
(FirstRunBootstrap.swift:60) → written into the fusion MCP config + `EPISTEMOS_VAULT_ROOT`
→ `omega_mcp_stdio` roots at an empty-but-existing dir → resources/list = 0, no `skills/`.
The Rust side is ALREADY honest (`omega_mcp_stdio.rs:19-21`: empty env → `set_vault_root`
skipped → `vault_root=None` → empty list truthfully = "no vault"); the Swift fallback was
defeating that honesty. History: the fallback was a deliberate 0.49b choice
(`STRICT_RECERT_LOG_2026_06_22.md` iter56) to avoid rooting at `~`/home — but the
2026-06-24 authority (#1 lines 276-278, "make the no-vault state honest") supersedes it.

**B — "no vault after rebuild" ROOT CAUSE (runtime-confirmed).** Dual preference domains:
- `com.epistemos.app` (Debug, the locally-rebuilt app): `hasEverConnectedAVault=1`,
  but `lastVaultPath` ABSENT and `vaultBookmark` ABSENT.
- `com.epistemos.appstore` (App Store, sandboxed): `hasEverConnectedAVault=1`,
  `lastVaultPath=/Users/jojo/Downloads/openclaw-main`, `vaultBookmark` PRESENT (84 bytes,
  security-scoped).

The vault is connected under the **App Store sandboxed build**; the **Debug rebuild** runs
under a different bundle id → different UserDefaults domain + sandbox container → no bookmark
to restore → `vaultURL` stays nil. The legacy-suite migration (VaultSyncService.swift:2160-2182)
bridges only `Brainiac.epistemos`/`com.lucid.app`, NOT `com.epistemos.app`↔`com.epistemos.appstore`.
NOT a bookmark-revocation bug. The app-group `group.com.epistemos.shared` (entitled in both
targets) holds NO vault keys today — the bookmark lives in per-bundle `UserDefaults.standard`.

**C — status UI (for the next slice).** `ComposerCurrentAccessPlan.swift` is the shared
chokepoint behind all 3 composer surfaces (ChatInputBar / MiniChatView / AgentControlSettingsView);
today no-vault silently collapses to "Local chat". `EidosRetrievedSection.swift:58-62` shows a
misleading "No evidence query has run yet" that reads like a broken MCP. Reusable CTA assets:
`VaultReprompSheet.swift` ("Connect a Vault Folder"), `VaultConnectionActions.selectVaultFolder`
(VaultSyncService.swift:4291), copy precedent "Connect a vault first…" (LiteParsePDFImportButton.swift:43).

**D — logging.** The shadow/indexing path ALREADY no-ops cleanly with no vault
(AppBootstrap.swift:3801-3816, no default rooting). The remaining default-dir rooting is
`VaultSyncService.resolvedRecoveryVaultURL` (1033-1045) returning `defaultRecoveryVaultURL`
(~/My mind) as last resort. `ShadowSearchDiagnostics` already has the honest
vaultPresent/serviceInstalled split (ShadowSearchHealthRow.swift:81-92) that the
BackgroundIndexing row should mirror.

## Implementation log

### Slice 1 — honest fusion rooting (DONE, statically verified) — 2026-06-24
- `Epistemos/Work/WorkOpenCodeRuntime.swift` (BundledWorkOpenCodeShell.launchSpec): replaced the
  silent `(epistemosVaultRoot ?? FirstRunBootstrap.defaultVaultURL()).path` fallback with a guard
  `if let vaultURL = epistemosVaultRoot, let serverURL = …bundledMcpServerURL()` →
  `fusionVaultRoot = vaultURL.path`. When no vault is active, fusion is OMITTED entirely
  (no `OPENCODE_CONFIG`, no `EPISTEMOS_VAULT_ROOT`) so `omega_mcp_stdio` honestly reports no vault.
  Confirmed the app never exports `EPISTEMOS_VAULT_ROOT` into its own process env (AppBootstrap
  setenv/unsetenv are the subprocess-hardening allowlist only), so the PTY inherits nothing stray.
- `Epistemos/Work/WorkOpenCodeShell.swift`: updated protocol + convenience-overload doc-comments
  (nil → omit fusion, never silent default).
- Source-guard tests updated in lockstep: `WorkOpenCodeRuntimeTests.swift` (launchSpecWiresFusion)
  and `OntologyRefactorRegressionGuardTests.swift` (workFusionRootsAtAppVault) now assert
  `if let vaultURL = epistemosVaultRoot` + `!contains("FirstRunBootstrap.defaultVaultURL()")`
  (no silent empty-default), keeping `vaultRoot: fusionVaultRoot` + `writeMergedFusionConfig(`.

### Bookmark restore (INVESTIGATED, documented — fix deferred) — 2026-06-24
Root cause = dual-domain (finding B). Fix options for a later security-sensitive slice:
(a) store/mirror vault selection in the app-group `group.com.epistemos.shared` so both targets
share it — BUT a sandboxed-build security-scoped bookmark may not resolve in the non-sandboxed
Debug build (scope semantics differ), so this needs care; (b) extend the legacy-suite migration
to bridge `com.epistemos.app`↔`com.epistemos.appstore`; (c) owner simply connects the vault once
in the Debug build (the honest no-vault CTA — Slice 3 below — makes that discoverable).
Decision needed from owner: SHOULD Debug and AppStore share a vault? Until then, honest no-vault
is the correct behavior.

### Slice 2a — honest no-vault grant row in the shared composer model (DONE, statically verified) — 2026-06-24
- `Epistemos/Views/Chat/ComposerCurrentAccessPlan.swift`: when `vaultURL == nil`, APPEND a synthetic
  non-revocable `ComposerResourceGrantRow` (id `vault:none`, "No active vault" / "Connect a vault to
  enable Read + Search + Halo recall", icon `externaldrive.badge.plus`). This is the shared model
  behind all three composer surfaces (ChatInputBar / MiniChatView / AgentControlSettingsView), so the
  "Stored Resource Grants" popover now honestly names the absence everywhere instead of silently
  collapsing to "Local chat".
- DESIGN for zero existing-test breakage: appended LAST (preserves every `rows.first` assertion in
  CurrentAccessParityTests, which use attachments) and `summaryText` left UNTOUCHED (preserves the exact
  `summaryText == "Web search"` parity test + the `segments.append("Local chat")` source-guard in
  ProductionHardeningTests). Verified the chip text is unchanged; only the popover gains the row.
- New positive test `CurrentAccessParityTests.noActiveVaultSurfacesHonestRow` (nil → row present with
  exact title/detail/non-revocable; non-nil → no `vault:none` row, real vault grant shown).
- Static verify: `xcrun swiftc -parse` exit 0 (model + test); grep gate confirms the new row + that
  `segments.append("Local chat")` is retained + the new test is present.
- STILL PENDING (Slice 2b, needs visual proof): make the row interactive — a "Connect Vault Folder"
  button calling `VaultConnectionActions.selectVaultFolder` (needs notesUI+vaultSync env in the popover);
  fix `EidosRetrievedSection.swift:58-62` misleading empty-state (needs threading vaultURL from
  ChatBrainPanelView, which today only reads UIState); optional chip-summary lead.

### Slice 2b (part 1) — interactive "Connect…" button on the no-vault row (DONE, statically verified) — 2026-06-24
- `Epistemos/Views/Chat/ChatInputBar.swift`: added `@Environment(NotesUIState.self) private var notesUI`
  and, in the "Stored Resource Grants" popover, a trailing `Button("Connect…")` on the `vault:none` row
  (`else if row.id == "vault:none"`) that dismisses the popover then calls the proven
  `VaultConnectionActions.selectVaultFolder(notesUI:vaultSync:)` (same helper used by Settings / Notes /
  RootView). So the no-vault row is now actionable, not just descriptive.
- ENV SAFETY proven statically: `AppEnvironment.swift:17` does `.environment(bootstrap.notesUI)` at the top
  of the tree (RootView consumes `@Environment(NotesUIState.self)` and works), so ChatInputBar (a RootView
  descendant via ChatView.swift:363) is guaranteed to have NotesUIState — no runtime-trap risk.
- Static verify: `xcrun swiftc -parse` exit 0; grep gate confirms the env line + the `vault:none` button +
  the dismiss-then-connect call. (SourceKit live "cannot find type" noise is the known isolated-file cascade.)
- STILL PENDING (Slice 2b part 2, needs visual proof): `EidosRetrievedSection.swift:58-62` misleading
  "No evidence query has run yet" empty-state — make it vault-aware (needs threading vaultURL from
  ChatBrainPanelView, which today only reads UIState). Deferred to a fire where a launch can verify it.

### Slice 3a — honest recovery-vault resolution (DONE, statically verified) — 2026-06-24
- `Epistemos/Sync/VaultSyncService.swift` `resolvedRecoveryVaultURL(from:)`: dropped the final
  `return Self.defaultRecoveryVaultURL` (fabricated `~/My mind`) → `return nil`. With no candidate, no
  active vault, and no last-path hint there is genuinely no recovery target; fabricating `~/My mind` made
  health snapshots root at a non-existent/empty default that read like a real (empty) vault.
- KEPT the last-path-hint branch (the safety net for a temporarily-unresolved bookmark) — only the very
  last fabricated default was removed (per recon D.2).
- SAFE: both call sites (`buildVaultHealthSnapshot:939`, `currentVaultHealthSnapshot:985`) already treat
  the result as Optional (`.map`/`if let`/nil-safe `comparableVaultCounts` guard); the function signature
  was already `-> URL?`. `defaultRecoveryVaultURL` stays defined (still used at :3110 as a cosmetic
  display-name `.lastPathComponent` fallback — not a real root).
- No test churn: no test asserts the recovery-URL default ("My mind" test hits are unrelated). Static
  verify: `xcrun swiftc -parse` exit 0; grep confirms `return nil` + no `.defaultRecoveryVaultURL` in the
  resolver.
- Slice 3b (the BackgroundIndexing honest-split) was AUDITED and found ALREADY SATISFIED — see the
  Slice 3b audit entry below.

### Slice 3b — AUDIT: already honest, NO code change (audit-first per memory) — 2026-06-24
Recon recommended "mirror the ShadowSearchDiagnostics vaultPresent/serviceInstalled split into the
BackgroundIndexing row so it stops conflating no-vault with MCP/FFI failure." On reading the actual code,
the split ALREADY EXISTS — recon's recommendation was based on a shallower read. The diagnostic layer
distinguishes THREE honest states:
- **No active vault** (`AppBootstrap.swift:3802-3815`): `BackgroundIndexingHealthRow.recordUnavailable`
  → phase `.unavailable`; `Log.app.info("…no active vault URL yet")` (info, NOT error);
  `ShadowSearchDiagnostics.recordInstall(vaultPresent:false, serviceInstalled:false)`.
- **Vault lifecycle cleared / disconnect / reset** (`AppBootstrap.swift:3438-3440`, inside
  `clearVaultLifecycleRuntimeState(reason:)`): `recordUnavailable(reason:)` with the real teardown reason
  + `Log.pipeline.info`. Legitimate, not a failure.
- **FFI / MCP failure** (`AppBootstrap.swift:3846-3864`): `recordFailed` → phase `.failed`;
  `Log.app.error`; `recordInstall(vaultPresent:true, serviceInstalled:false)`.
Distinct phases (`.unavailable` vs `.failed`), distinct copy, distinct log levels, distinct diagnostic
flags — no-vault is NOT conflated with MCP failure. `ShadowSearchHealthRow.swift:81-92` already renders
the honest two-state split. The strings are locked by `SettingsCategoryTests` (`:176-184`,
`backgroundIndexingUnavailableDetailPreservesCacheOnlyReason`). CONCLUSION: Slice 3b needs no change;
forcing one would be churn against locked tests with zero honesty gain. (Authority hardening item #5
"do not diagnose [no vault] as MCP failure" is therefore already met at the diagnostic layer.)

### Checkpoint build #1 (Slices 1 + 2a + 2b-1 + 3a) — kicked in BACKGROUND 2026-06-24
Incremental `xcodebuild -scheme Epistemos -destination 'platform=macOS' build` (114 GiB free; reuses the
19 G DerivedData). RESULT: **BUILD SUCCEEDED** (exit 0; log line 8784; no `error:` in any edited file;
`.app` registered with LaunchServices). All four slices compile cleanly together — the SourceKit
"cannot find type" warnings were confirmed spurious (isolated-file indexer). CAVEAT: `xcodebuild build`
compiles the APP target only — the TEST target (the two source-guard updates + the new
`CurrentAccessParityTests.noActiveVaultSurfacesHonestRow`) is NOT compiled by this build; those remain
`swiftc -parse` + grep verified. Run `xcodebuild test`/build-for-testing to compile-verify the tests.

## Verification

- [x] **Source-guard gate (fast, primary per CLAUDE.md):** all assertions the two updated tests
  check pass against the edited source (`if let vaultURL = epistemosVaultRoot` present;
  `FirstRunBootstrap.defaultVaultURL()` absent in WorkOpenCodeRuntime.swift; `vaultRoot:
  fusionVaultRoot` + `writeMergedFusionConfig(` + `bundledMcpServerURL()` + `OPENCODE_CONFIG` present).
- [x] **Syntax:** `xcrun swiftc -parse` on both edited Work files = exit 0.
- [x] **No dangling reference:** `defaultVaultURL()` still has a legit caller
  (SetupAssistantView.swift:360, onboarding) — not orphaned; only the dishonest Work fallback removed.
- [x] **Bookmark root cause:** runtime-confirmed via `defaults read` across both domains (finding B).
- [x] **Full app-target compile (xcodebuild) — DONE** (checkpoint build `bjb9co0oe`: BUILD SUCCEEDED,
  exit 0, no errors in any edited file). Covers Slices 1 / 2a / 2b-1 / 3a. CAVEAT: app target only —
  the TEST target is not built by `xcodebuild build`; test edits remain `swiftc -parse` + grep verified.
- [x] **Test target compile + run — DONE** (checkpoint build `bsvz76vz3`: `xcodebuild test` = TEST
  SUCCEEDED). The FULL test target compiled (incl. the source-guard files WorkOpenCodeRuntimeTests +
  OntologyRefactorRegressionGuardTests). `CurrentAccessParityTests` RAN + passed, incl. the new
  `noActiveVaultSurfacesHonestRow` ✔ (Slice 2a model behavior). The two source-guard suites were compiled
  but not run this pass (string-asserts, already grep-verified) — they're covered by compile + grep.
- [ ] **Runtime/visual proof — OWED.** Needs a vendored OpenCode runtime + a build+launch:
  confirm (1) no-vault Work launches WITHOUT fusion and `omega_mcp_stdio` honestly reports no vault,
  (2) connecting a vault enables fusion + skills. Cannot screenshot without build.

## Recon artifacts (read-only, no code change)
- `docs/handoffs/ENTRY_POINT_ROUTING_INVENTORY_2026_06_24.md` (2026-06-24) — authority item #4 entry-point
  routing inventory (main/mini/graph/note chat + landing/click-anywhere) + a head-start on item #2.
  KEY: engine drift already resolved (main+mini share `ActTurnStreamCore.consume`); graph/note escalate
  to main; remaining is STATE/RENDER drift. Item #2's `parentSessionID` primitive ALREADY EXISTS in
  `AgentSessionLineageStore`/`ConversationPersistence`/`SessionBrowser` but the mini-chat UI
  (`ThreadState.miniChatSession`, flat by chatID) doesn't consume it — bridge that, don't rebuild.
- `docs/handoffs/WORK_MINI_SESSION_PARITY_LEDGER_2026_06_24.md` (2026-06-24) — authority item #2 Work
  mini-session parity ledger. AUDIT WINS: engine shared, duplicate-window prevention DONE
  (`MiniChatWindowController.windows[chatID]` focus-existing), lineage primitive EXISTS
  (`AgentSessionLineageStore`). GAP: mini-chat UI never establishes/surfaces parentage; no in-main
  attached pane; recents show ACT/WORK split but no parent linkage. Smallest first build step =
  `parentSessionID` bridge.

## Owner decisions (resolved 2026-06-24 — owner delegated "choose the best")
- **Slice 4 (cross-domain vault): WON'T-DO (safe choice).** Do NOT auto-bridge the vault across the
  Debug (`com.epistemos.app`) and App Store (`com.epistemos.appstore`) sandbox/UserDefaults domains: a
  sandboxed-build security-scoped bookmark often won't resolve in the non-sandboxed Debug build, and
  cross-domain/app-group bookmark bridging is fragile + hard to reverse. The honest no-vault "Connect…"
  CTA (Slices 1/2a/2b-1, shipped) lets the owner connect the vault per build — the correct low-risk fix.
- **Runtime/visual proof: NOT a loop blocker.** Static verification proceeds; visual proof is confirmed
  whenever the owner next launches the app. The loop will not stall waiting on it.

## Remaining queue (next loop iterations)

1. **Slice 2b part 2 — EidosRetrievedSection empty-state (UI):** Slice 2a (synthetic row) + Slice 2b
   part 1 (interactive "Connect…" button in the ChatInputBar popover) are DONE. Remaining: make
   `EidosRetrievedSection.swift:58-62` vault-aware (thread vaultURL from ChatBrainPanelView, which today
   only reads UIState) so the brain panel's EVIDENCE INTAKE stops reading like a broken MCP when there's
   simply no vault. Needs visual proof.
2. **Slice 3b — DONE via audit** (already-honest; see the Slice 3b audit entry above). No code change.
3. **Slice 4 — RESOLVED: won't-do** (safe choice; see "Owner decisions" above). The per-build "Connect…"
   CTA is the fix.
4. **Phase-2 build (owner-delegated): mini-session `parentSessionID` bridge** — IN PROGRESS, see
   `WORK_MINI_SESSION_PARITY_LEDGER` §Implementation log. DONE: sub-step 1 (creation-site recon — minis
   are spawned standalone, no parent in scope at most sites) + sub-step 2 (optional `parentSessionID`
   schema foundation in `ChatThread` + `ThreadState` ensure/upsert + unit test, statically verified).
   REMAINING (owner-greenlit / runtime-proof needed): decide the parent SOURCE per creation site + wire it
   via `AgentSessionLineageStore`, surface parent linkage in recents, then in-main attached pane. These
   need a UX decision + visual proof — the loop will flag 'awaiting owner' rather than guess.
5. **Checkpoint build** after batching, then owner-driven runtime/visual proof.
