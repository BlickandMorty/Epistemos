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
- Use the shared mono display font for landing search and shortcuts.
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

Status: Open (`GRAPH-FROZEN`)
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

Status: Investigating (read-only process-memory diagnostics added; Instruments allocation profile still required)
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
