# V1 Deep Interaction Audit — 2026-05-08

Scope: long-running Computer Use QA loop for Epistemos v1 hardening after the
pre-HELIOS release audit. HELIOS remains frozen as research, doctrine, and
guardrails only. Graph rendering visuals are frozen for this pass: graph
renderer/physics/visual-mode bugs are logged as `GRAPH-FROZEN` and not fixed
here unless the issue is non-renderer data plumbing.

## Phase 0 State

- Branch/worktree: `feature/landing-liquid-wave`, dirty at session start.
- `git diff --check`: passed before this ledger was created.
- Staged generated artifact cleanup: `syntax-core/target/aarch64-apple-darwin/debug/libsyntax_core.rlib` is staged for index removal only; local ignored build output remains on disk.
- Intentional source/docs/tests currently dirty by subsystem:
  - App bootstrap/runtime: `AppBootstrap`, `AppEnvironment`, `ChatCoordinator`, `RootView`, `ActivityTracker`, `AppSupervisor`, `InferenceState`, `NightBrain*`.
  - Landing/agents/search/wave: `LandingView`, `Landing/Farm/*`, `Landing/Wave/*`, `CompanionState`, `CompanionModel`.
  - Notes/prose/code editor: `NoteDetailWorkspaceView`, `ProseTextView2`, `CodeEditorView`, gutters, Markdown layout/transclusion/autocomplete, note window/sidebar.
  - Epdoc/editor: `EpdocDocument`, `EpdocGraphProjector`, `EpdocGraphPersistence`, bundled `editor.js.br`, JS editor markdown/image rules.
  - Shadow/Halo/search/diagnostics: `Shadow*`, `HaloState`, `AgentGrepService`, settings health rows.
  - Graph prior work: `GraphState`, graph controls/panels/overlay, `graph-engine` engine/lib/embedding/renderer, SDF label atlas/resources. These are frozen for further visual edits in this pass.
  - Knowledge Fusion/model routing: adapters, MoLoRA, Python env/training/transcription.
  - Tooling/agent_core: Pro/MAS tool hardening across CLI, MCP, browser, terminal, web, filesystem, communication, media, memory, scheduling, skills, and related docs.
  - Tests: focused Swift and Rust source/behavior guards across the edited surfaces.
  - Docs/audit: `docs/APP_ISSUES_AUTO_FIX.md`, `docs/audits/V1_RELEASE_AUDIT_2026_05_07.md`, specialty/tool-tier docs.
- Untracked source/test support files:
  - `Epistemos/Views/Settings/ArenaHealthRow.swift`
  - `Epistemos/Views/Settings/ProcessMemoryHealthRow.swift`
  - `Epistemos/Views/Settings/ShadowSearchHealthRow.swift`
  - `js-editor/scripts/check-markdown-input-rules.mjs`
- Build artifacts/caches: no untracked build cache files were listed by `git ls-files --others --exclude-standard`; the tracked rlib cleanup is the known generated artifact issue.
- Unknown risky changes: none classified yet, but the dirty tree is broad. Future commits must be small and path-scoped.

## Issue Format

`ID · Surface · Severity · Repro · Expected · Actual · Root cause · Fix · Tests · Status`

Computer Use findings use:

`CU-### · Surface · Severity · Exact clicks/keys · Expected · Actual · Screenshot/log evidence · Suspected source area · Status`

Severity:
- `P0`: crash, data loss, privacy/TCC prompt on passive launch, hang, destructive tier leak.
- `P1`: broken advertised interaction, fake UI, silent failure, hidden hot loop, save/reopen integrity risk.
- `P2`: confusing/degraded behavior with a workaround.
- `P3`: cosmetic/accessibility polish.

## Computer Use Passes

### Pass 1 — Broad Discovery

Status: Discovery batch complete enough to start first fix batch. Covered
landing, agents/add-agent, landing slash/mention, main chat, Mini Chat,
attachment picker, model picker, Notes sidebar, Epdoc rich input/Copilot/image
picker, Graph open/query/search/close, and Settings diagnostics/tiering rows.
Clean-post-fix counter: 0/3.

Planned sweep: landing page, landing input, `/` and `@`, main chat, mini chat,
agent/tool mode, file picker, model picker, notes/prose, Epdoc, Epdoc
graph/visualizer, rich paste/media/table/code, graph open/close/pan/zoom/search
and inspect (verification only), Halo/Shadow, Settings diagnostics, and visible
MAS/Pro gated surfaces.

## CU Findings

CU-001 · Landing mention picker · P1 · Click `Click to search`, type
`hello @`, press `Down`, press `Return` while the picker search field is
focused · Expected: the highlighted note/chat row moves or inserts the selected
reference into the landing composer, with Escape dismissing the picker · Actual:
the picker opened with real notes/chats/files, but `Down` and `Return` left
focus in the picker search field and did not insert or move selection during the
Computer Use smoke · Screenshot/log evidence: Computer Use state for
`com.epistemos.audit` pid 30539 showed popover rows `All Notes`, recent chats,
and files, focused element `30 text field Search notes, chats, tags, folders,
and snippets`; visual screenshot showed `hello @` in the landing input with the
popover still open after Down/Return · Suspected source area:
landing `@` reference picker keyboard handling / shared mention picker focus
routing · Fix: shared picker search field now owns arrow/Return/Escape command
handling, and the active inline landing search renders selected references as
visible removable chips · Tests:
`EpistemosTests/ThemePairTests.referencePopoverSearchFieldOwnsKeyboardSelectionCommands`
and
`EpistemosTests/ThemePairTests.landingInlineMentionAttachmentsStayVisibleAfterKeyboardSelection`
· Status: Verified Fixed

CU-002 · Landing slash command palette · P1 · Click `Click to search`, type
`/`, press `Down`, then `Return` · Expected: keyboard selection should move
through slash commands and insert or execute the selected command without
submitting a raw slash prompt · Actual: the command palette rendered real
commands, but `Return` left the landing surface and created a main-chat turn
with user prompt `/`; the local model answered with the generic assistant
fallback · Screenshot/log evidence: Computer Use state showed slash palette
rows `/ask`, `/notes`, `/code`, `/plan`, `/summarize`, then the next state
showed main chat message `/` and answer `I am the local Epistemos assistant...`
· Suspected source area: landing composer slash palette keyboard handling /
submit gating for command-trigger text · Fix: composer submit now confirms the
open slash overlay before routing a prompt; Return from `/` no longer submits a
raw slash turn · Tests:
`EpistemosTests/ThemePairTests.composerOverlaysOwnArrowReturnAndEscapeWhileVisible`
· Status: Verified Fixed

CU-003 · Main chat mention picker · P1 · In the main chat composer, type
`@pro`, press `Down`, press `Return`, then click the first result · Expected:
keyboard navigation should select/insert a result and mouse click should do the
same · Actual: mouse click attached the chat context correctly, but
`Down`/`Return` did not move selection or insert from the focused picker search
field · Screenshot/log evidence: Computer Use state showed `Search Notes and
Chats`, focused picker field `pro`, four chat rows, and unchanged composer
`@pro` after Down/Return; clicking row `summarize this note` attached a context
chip and cleared the composer · Suspected source area: shared mention picker
keyboard event routing and focus model · Fix: the shared picker search field
maps arrow/Return/Escape through `ChatComposerKeyHandling.overlayCommand` and
calls the same `onSelect` path mouse clicks use · Tests:
`EpistemosTests/ThemePairTests.referencePopoverSearchFieldOwnsKeyboardSelectionCommands`
· Status: Verified Fixed

CU-004 · Model picker · P2 · In main chat click the current model chip
`Gemma3 4B` · Expected: installed models and installable catalog entries are
clearly separated without duplicate-looking rows for the same model identity ·
Actual: picker reports `Local Models 8 installed • 8 available` and then shows
installed rows such as `Gemma 3 4B` plus lower `Available to install` rows with
the same visible names, including `Gemma 3 4B` and repeated `Qwen 3` labels ·
Screenshot/log evidence: Computer Use state element 29 popover listed selected
`Gemma 3 4B` and also `Gemma 3 4B, Available to install`; visual screenshot
showed duplicate-looking rows · Suspected source area:
`LocalModelToolbarMenu` / catalog ID display names / installed-vs-available
deduplication · Status: Open

CU-005 · Workspace auto-save during Mini Chat local prompt · P0 · From main chat click `Open in Mini Chat`,
type `reply with mini-ok`, press `Return`, wait through `Loading Gemma 3 4B...`
· Expected: Mini Chat should either stream a local answer, return an honest
model-unavailable error, or remain cancellable without crashing · Actual: Mini
Chat remained in a loading/writing state with high CPU, Computer Use then timed
out, `ps` no longer found the original app PID 30539, and the audit app
reappeared under a new PID 31866 · Screenshot/log evidence: Computer Use state
showed mini-chat window `reply with mini-ok`, `Loading Gemma 3 4B...`, busy
indicator and stop button; `ps -p 30539 -o pid,etime,%cpu,rss,comm` reported
118.4% CPU / 1.1 GB RSS before the process disappeared; subsequent process list
showed new `EpistemosAudit.app` PID 31866 and `ReportCrash` activity; crash
report `/Users/jojo/Library/Logs/DiagnosticReports/Epistemos-2026-05-08-131653.ips`
records `EXC_BREAKPOINT/SIGTRAP` on the main thread in
`Dictionary.init(uniqueKeysWithValues:)` from
`WorkspaceService.captureSnapshot()` line 146 during
`WorkspaceService.autoSave()` / `startAutoSave()` · Suspected source area:
workspace auto-save snapshot assumes unique `SDPage.id` values when building
`wordCountsByPageId`; duplicate page IDs or repeated SwiftData rows crash the
whole app during auto-save while Mini Chat/model load makes the timer path hot ·
Fix: workspace snapshot word counts now use a duplicate-tolerant fold with
first-writer-wins semantics and duplicate diagnostics instead of
`Dictionary(uniqueKeysWithValues:)` · Tests:
`EpistemosTests/WorkspaceSnapshotTests` and
`EpistemosTests/WorkspaceServicePersistenceTests`; live Mini Chat retry did not
relaunch/crash · Status: Verified Fixed

CU-006 · Vault/Notes/Graph active-vault state · P1 · Open `Notes`, click
`New Page`, then inspect `Settings → Vault` and graph query/search · Expected:
if notes and graph show vault content, the Vault settings row should identify
the connected vault, new note creation should create a note in that vault, and
graph/search diagnostics should report the same active vault/index source; if
no vault is connected, note creation and graph-backed content should be clearly
disabled or labeled as imported/cache-only · Actual: Notes listed many folders
and files, Graph showed a large note graph, and graph query found note rows, but
clicking `New Page` opened a native folder picker titled `Choose a folder for
your Epistemos vault`; `Settings → Vault` reported `No vault connected`; the
General diagnostics also reported `Background indexing No active vault
selected` · Screenshot/log evidence: Computer Use state for Notes listed
folders such as `EpistemosVault`, `recent adds`, and `non-work`; Graph query
listed note/folder matches; Settings Vault row showed only `Select Vault
Folder` · Suspected source area: vault connection state, SwiftData page cache,
graph bootstrap, and search/index diagnostics are not using one canonical
active-vault source · Fix: after a successful initial vault import/recovery with
no recovery issue, `VaultSyncService.schedulePostImportMaintenance` now
publishes `.vaultChanged` through the canonical event bus before manifest,
cleanup, Shadow/R3 observers, and graph/search refreshes fan out · Tests:
`EpistemosTests/VaultSyncServiceAuditTests.initialVaultImportPublishesVaultChangedAfterImport`
· Status: Verified Fixed for the disconnected-cache failure mode; the
restored-vault event path is patched with focused coverage, and launched
audit-app verification now labels cached Notes/Graph rows as disconnected local
cache while create/save affordances require selecting a vault. A normal
connected-vault note-to-graph smoke remains tracked separately before RC.

CU-007 · Epdoc typed Markdown/rich blocks · P1 · Create `New Doc`, paste a
Markdown fixture containing headings, list items, a task item, a table, fenced
Swift code, image URL markdown, and `[[Graph Sync]]` · Expected: pasted
Markdown should become rich blocks where supported: headings, clean list items,
structured table, a closed syntax-highlighted code block, safe image node or
honest blocked image state, and wikilink mark · Actual before patch: headings
converted, but typed multiline injection flattened line breaks, the table stayed
raw pipe text and the complexity meter reported `Tables 0`, the code block
displayed the closing fence inside the block, and the image stayed Markdown/link
text while the meter reported `Visuals 0` · Screenshot/log evidence before
patch: Computer Use state for `Untitled` Epdoc showed `Words 36 · Headings 2 /
H2 · Code 1 · Visuals 0 · Tables 0 · Lists 2`; visible editor showed raw
`| Surface | Status |` rows, trailing ``` inside the code block, and
`![Tiny image](https://example.com/image.png)` as text · Root cause: the
typed/paste smoke had two real gaps: table input/paste recognition was too
strict, and code-block Enter could leave a closing fence inside the block;
Computer Use `type_text` also flattened multiline Markdown, so true paste needed
separate verification · Fix: JS input rules now parse multiline Markdown tables
through the structured paste parser; code block nodes detect an Enter on the
closing fence line and exit the block; the editor bundle was rebuilt · Tests:
`npm run check:markdown-input-rules`, `npm run check:markdown-paste`,
`npm run check:code-block`, `npm run typecheck`, and
`./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/EpdocVisibilitySourceGuardTests`
passed; result bundle
`build/xcode-results/2026-05-08-150352-41020.xcresult` · Runtime verification:
Computer Use real paste, after focusing the WebKit editor and pressing
Command-A/Command-V from a multiline clipboard, rendered H1/H2 headings, bullet
list, task checkbox, structured table, syntax-highlighted Swift code block,
image node for `Pixel sample`, and `Graph Sync` wikilink; complexity row
reported `Code 1`, `Tables 1`, `Links 1`, `Embeds 1`. The remote image URL in
the fixture produced an image node but a broken remote preview icon, so a valid
reachable-image smoke remains a lower-priority media check · Status: Verified
Fixed for paste/rich-block conversion

CU-008 · Epdoc Visualize document · P1 · Open Epdoc Copilot and click
`Visualize document` on the live document · Expected: insert a valid document
graph/diagram derived from headings/claims/links without exposing parser errors
to the document body · Actual: Copilot inserted a Mermaid diagram block that
failed to parse, with visible `Error: Parse error on line 19` text inside the
document · Screenshot/log evidence: Computer Use state showed Copilot message
`Inserted a graph derived from the live document structure` followed by a
visible red Mermaid parse error and `Syntax error in text mermaid version
11.14.0` · Root cause: graph-generation labels could include table separators,
raw Markdown image/link syntax, code fences, pipes, braces, and angle brackets
that are unsafe inside Mermaid labels · Fix: document graph extraction now skips
Markdown table separator rows, normalizes table/image/link/wikilink/code labels,
escapes Mermaid label punctuation, and emits compact class definitions without
the semicolon form that triggered the parser path · Tests:
`npm run check:document-graph`, `npm run typecheck`, and the focused
`EpdocVisibilitySourceGuardTests` run above passed · Runtime verification:
Computer Use clicked `Ask Epdoc` then `Visualize document`; Copilot inserted a
rendered `Research diagram` with no Mermaid parse error. The diagram included
meaningful nodes derived from `Paste Graph Check`, `Evidence`, `Alpha claim`,
`Confirm sync`, table values, `Code: let answer = 42`, `Pixel sample`, and
`Graph Sync` · Status: Verified Fixed

CU-009 · Graph/Notes duplicate note rows · P2 · Open Graph, switch to Query,
search `recent`, and compare with Notes sidebar · Expected: note/folder search
results should be deduplicated by canonical file/page identity · Actual: both
Graph query and Notes sidebar showed duplicate-looking note rows such as
`A Recentering.txt` twice · Screenshot/log evidence: Computer Use graph query
state showed `3 MATCHES` with two `A Recentering.txt` note rows and `recent
adds`; Notes sidebar also listed repeated file names · Suspected source area:
vault import/page identity canonicalization or multiple historical vault roots
feeding the same graph/search surface · Status: Open

CU-010 · Settings Shadow/Halo/index diagnostics · P1 · After opening Graph and
searching/querying nodes, open `Settings → General` diagnostics · Expected:
Shadow/Halo/search diagnostics should identify the live backend path or a clear
degraded/cache-only state, and should not say uninitialized after graph/search
surfaces are visibly using data · Actual: diagnostics reported `Halo backend
Not opened yet — call shadow_open_at(path) at bootstrap`, `Shadow backend No
Shadow searches observed this launch`, `Background indexing No active vault
selected`, and `RRF Fusion flag ... unset` while the app had already shown
Notes and Graph content · Screenshot/log evidence: Computer Use Settings state
captured these rows with process RSS and graph/projection rows populated ·
Suspected source area: ShadowSearchService/AppBootstrap active-vault bootstrap,
diagnostics source selection, and search fusion flag status · Fix: same
post-import `.vaultChanged` event as CU-006, which lets the already-wired
`AppBootstrap.wireR3VaultSwitchObserver` call `initializeShadowBackendIfReady()`
after async vault restore/import instead of only during the initial no-vault
bootstrap frame · Tests:
`EpistemosTests/VaultSyncServiceAuditTests.initialVaultImportPublishesVaultChangedAfterImport`
· Status: Verified Fixed for the disconnected-cache failure mode; launched
audit-app verification shows `Halo backend No active vault selected -
Shadow/Halo closed`, `Background indexing No active vault selected - cached
local note/graph data only`, and no stale Shadow path while cached local rows
are visible.

CU-011 · Active vault note-to-graph sync · P1 · Select a real vault, create or
import a new note, then open Graph/query and Shadow diagnostics · Expected: the
new note appears in Notes, Graph query/search, and Search/Shadow diagnostics
under the same active vault path without relaunch · Actual: user reports a
new-vault session where Graph showed none of the new notes; this has not yet
been re-run with a connected real vault during this Computer Use loop ·
Screenshot/log evidence: pending connected-vault pass; disconnected audit-app
state verified separately in CU-006/CU-010 · Suspected source area:
VaultSyncService `.vaultChanged` fan-out, graph import refresh, Shadow/R3
observer timing, and duplicate/cached SwiftData rows · Fix: restored/initial
import now publishes `.vaultChanged`, and every local vault mutation now marks
`AppBootstrap.shared?.graphState.needsRefresh = true` before emitting the
mutation event so graph/search observers cannot see a clean graph after
create/save/move/delete changes; connected-vault live smoke still required
before closure · Tests:
`EpistemosTests/VaultSyncServiceAuditTests.initialVaultImportPublishesVaultChangedAfterImport`,
`EpistemosTests/VaultSyncServiceAuditTests.vaultMutationEventsMarkGraphDirtyBeforeObserversRun`
· Status: Patched

CU-012 · Passive launch TCC/document restoration · P1 · Launch fresh audit app,
collect fresh unified logs before user action · Expected: passive launch should
open the landing page, should not restore old Epdoc windows, and should not
trigger app-owned Contacts/Calendar/Reminders/Accessibility prompts;
unavoidable system preflights should be classified with attribution evidence ·
Actual: first relaunch after disabling untitled-window creation still restored
an old `Untitled` Epdoc window; second relaunch after document-controller gating
opened the landing page directly. Current pid 54172 still emitted a
`kTCCServiceListenEvent` preflight attributed to `com.epistemos.audit`, plus
DeveloperTool/FullDisk/Downloads preflights from syspolicyd/sandboxd because
the audit app is ad-hoc signed and launched from `Downloads`; no current-pid
AddressBook/Calendar/Reminders request was found · Screenshot/log evidence:
Computer Use state for pid 54172 showed the landing page with compact top-right
`AGENTS` dock and no restored document window; `ps -p 54172 -o pid,ppid,%cpu,%mem,rss,etime,command`
showed 0.0% CPU after launch; `/usr/bin/log show --last 2m ...` captured
`service=kTCCServiceListenEvent` with `requesting={identifier=com.epistemos.audit,
pid=54172}`, while AddressBook noise in the same broad log came from system
Contacts helpers, not the Epistemos process · Suspected source area: no
remaining app-owned `CGEventSource`, `NSEvent.add*Monitor`, or eager AX source
path was found in production Swift; remaining ListenEvent preflight appears to
come from launch/AppKit/SkyLight or a linked dependency before app code can
attribute it further · Fix: `EpistemosApp` disables untitled window creation,
and `EpistemosDocumentController.reopenDocument` suppresses saved-state document
reopen when the launch policy purges saved app state; passive idle probes in
`ActivityTracker`, `NightBrainService`, and `TrainingScheduler` remain replaced
by app-local quiescence · Tests:
`EpistemosTests/EpistemosDocumentControllerTests.restorableDocumentReopenFollowsSavedStatePurgePolicy`
and `EpistemosTests/RuntimeValidationTests` · Status: Patched for document
restoration and app-owned idle/AddressBook probes; residual ListenEvent preflight
remains Investigating.

CU-013 · Landing agent idle animation · P1 · Relaunch audit app to landing,
do not interact, inspect the agent dock, then sample CPU after idle · Expected:
the top-right agents are compact, chrome-free, landing-only, and do not run a
hidden render loop while idle · Actual before patch: live audit showed the app
idling around 13-19% CPU with samples pointing at `CompanionAvatarGlyph` and
`CompanionRoamingField`; source inspection showed an idle `CompanionRoamingField`
path could still pass `nil` dates into `CompanionView`, causing each glyph to
create its own `TimelineView` · Screenshot/log evidence: Computer Use state for
pid 54172 shows small pixel agents under `AGENTS` with a `+` add button and no
large companion box/orb/graph companion; `ps -p 54172 -o pid,ppid,%cpu,%mem,rss,etime,command`
reported 0.0% CPU at 13 seconds and again after 71 seconds idle, RSS about
221-223 MB · Root cause: the static shelf still fell through to child breathing
timelines, and Landing passed animation-active state from window visibility even
when the product direction is "agents sit and chill" · Fix:
`LandingView` now mounts `LandingFarmView(isAnimationActive: false)`;
`CompanionRoamingField` has a deterministic `staticSampleDate` path and always
passes a concrete sampled date into child `CompanionView`s, keeping the shelf
clockless while idle · Tests:
`EpistemosTests/CompanionAvatarGrammarSourceGuardTests` · Status: Verified Fixed.

CU-014 · Landing search cursor/font/warp · P1 · Relaunch audit app, click
`Click to search`, type `ask`, then replace it with `@` and click `slash` ·
Expected: the focused search should be a real native input, the placeholder
should not overlap the caret, the caret should sit after the last typed
character, the search text should use a crisp mono display face, and `/` / `@`
affordances should still open real pickers · Actual before patch: user-provided
screenshot showed the caret stuck in the middle of `Ask Epistemos...`, the
focus transition jumped/zoomed, and the field felt like projected text rather
than a real input · Screenshot/log evidence after patch: Computer Use state for
`com.epistemos.audit` pid 44275 showed `Landing search input` with value `ask`,
visually rendered as `ask|`; typing `@` opened `Browse Notes and Chats`, and
clicking `slash` opened the real command list. `ps -p 44275 -o pid,etime,%cpu,rss,comm`
showed 0.1% CPU / 290,304 KiB RSS after the targeted pass · Root cause:
the large prompt text and the edit field placeholder/caret were sharing the
same transition/scaled projection path; the wave click choreography also used
too-wide, too-fast splash radii for the desired dense ASCII black-hole feel ·
Fix: the landing search is now an empty native `TextField` with a separate
placeholder overlay that hides while focused, uses the shared high-quality mono
display font, keeps the bottom command shortcuts on the native system UI font,
switches focus with opacity instead of scale/zoom, and the landing wave
choreography uses a denser, slower, tighter ASCII warp/ripple ·
Tests: targeted suite result bundle
`build/xcode-results/2026-05-08-163706-20577.xcresult` · Status: Verified
Fixed.

CU-015 · Epdoc embedded chat dock · P1 · Open `New Doc`, inspect the bottom
Epdoc dock, then press `⌘3` from the Epdoc window · Expected: Epdoc should keep
document actions only (`Visualize document`, `Add frontmatter`) and should not
mount a second embedded chat surface; Mini Chat should be the chat route for
Epdoc context · Actual before patch: the Epdoc dock included an embedded
free-form `Ask Epdoc` chat path, duplicating Mini Chat and making the document
surface feel like another half-chat · Screenshot/log evidence after patch:
Computer Use state for `Untitled` Epdoc showed only buttons `Visualize document`
and `Add frontmatter` with AX id `epdoc-document-actions`; pressing `⌘3` opened
the Mini Chat window. The live smoke used an unsaved Epdoc, so no file-context
chip was expected; source coverage verifies saved active Epdocs attach through
Mini Chat · Root cause: `EpdocCopilotDockView` carried both document-command
buttons and a free-form embedded chat transcript/input · Fix: the dock now
renders only compact document actions, preserves command plumbing for
programmatic transforms, and `MiniChatWindowController.openNewChat(attaching:)`
falls back to the active saved Epdoc file before active note context · Tests:
targeted suite result bundle
`build/xcode-results/2026-05-08-163706-20577.xcresult` · Status: Verified
Fixed for the UI removal and saved-file context route; live saved-Epdoc
attachment smoke remains a non-blocking RC check.

CU-016 · Notes utility window sizing · P2 · Press `⌘2` from the running app and
inspect the Notes utility panel · Expected: Notes should open as a compact,
resizable utility window and should not be forced into an overly tall/wide
sidebar surface by SwiftUI content sizing · Actual before patch: user reported
the Notes sidebar/window was extremely long and could not be resized
comfortably · Screenshot/log evidence after patch: Computer Use opened a
compact `Notes` dialog with the `Disconnected Local Cache` banner and visible
bottom action row, instead of a huge forced panel. The same smoke also verified
the no-vault create actions are labeled `Select Vault...` / `No Vault Connected`
instead of pretending writes are available · Root cause:
`UtilityWindowManager` let the hosted SwiftUI Notes content drive the panel's
sizing constraints and used a large minimum/default size · Fix: Notes now uses
a smaller default/minimum size and disables host sizing options for that utility
surface so AppKit resizing is not captured by SwiftUI intrinsic content ·
Tests: targeted suite result bundle
`build/xcode-results/2026-05-08-163706-20577.xcresult` · Status: Verified
Fixed for panel sizing; connected-vault note creation remains covered by
CU-011.

CU-017 · Local model install visibility · P2 · Inspect the local model hub and
run the local model infrastructure tests after the user installed all local
models · Expected: usable hub snapshots should be detected as installed, hidden
or quarantined snapshots should not be advertised as runnable, and the unified
Qwen 3 picker should engage when the pair is present · Actual: no live
inference run was attempted for every installed model in this targeted slice,
but the local hub contains Qwen, Gemma, Llama, Falcon, DeepSeek, and Ternary
Bonsai directories; detection coverage still needed to be rerun after the
current install state · Screenshot/log evidence: shell inspection listed the
installed hub directories and the focused test suite passed 76 tests including
usable hub snapshots, hidden/quarantined model guards, prepared runtime
metadata, and Qwen 3 unified picker behavior · Root cause: historical
model-picker regressions came from catalog-ID/manifest-only detection gaps ·
Fix: no new code change in this slice; reran the existing detection gate
against the current local model layout · Tests:
`./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/LocalModelInfrastructureTests`
passed 76 Swift Testing tests in 1 suite; result bundle
`build/xcode-results/2026-05-08-164053-25519.xcresult` · Status: Verified for
install detection; full inference smoke for every installed model remains
manual/long-running.

CU-018 · Graph full-screen performance regression · P1 `GRAPH-FROZEN` · User
reported graph full-screen performance regressed after the pixel-node work ·
Expected: full-screen graph should stay fluid, but this pass must not change
graph renderer/shader/visual-mode code under the explicit graph-rendering
freeze · Actual: no graph renderer fix was attempted in this targeted pass ·
Screenshot/log evidence: pending Time Profiler / Animation Hitches capture with
a real graph and full-screen window; current targeted pass did not collect a
graph full-screen sample · Suspected source area: graph renderer full-screen
drawable sizing, node-label atlas/pixel-node LOD, or non-renderer overlay work;
not safe to patch without a graph-authorized profiling slice · Status: Open
(`GRAPH-FROZEN`, manual verification and profiling required).

## Verification Ledger

- 2026-05-08: `git diff --check` passed before creating this ledger.
- 2026-05-08: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/WorkspaceSnapshotTests -only-testing:EpistemosTests/WorkspaceServicePersistenceTests` passed 7 Swift Testing tests in 2 suites; result bundle `build/xcode-results/2026-05-08-133755-34678.xcresult`. Runtime retest submitted Mini Chat `reply with mini-ok` without the previous auto-save crash/relaunch.
- 2026-05-08: `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/ThemePairTests` passed 111 Swift Testing tests in 1 suite; result bundle `build/xcode-results/2026-05-08-141614-77732.xcresult`. Runtime retest verified landing slash selection, landing mention selection, and main-chat mention selection with Computer Use.
- 2026-05-08: `git diff --check` passed before the vault-sync patch. `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/VaultSyncServiceAuditTests` passed 45 Swift Testing tests in 1 suite; result bundle `build/xcode-results/2026-05-08-142656-89037.xcresult`. This covers the restored-vault `.vaultChanged` event needed by Shadow/R3/graph/search observers.
- 2026-05-08: Launched audit-app verification after the vault-sync event patch did not close CU-006/CU-010. `scripts/launch_audit_app.sh` intentionally clears audit vault defaults and injects `EPISTEMOS_SKIP_VAULT_RESTORE=1`; Settings still reported `No vault connected` and `Background indexing No active vault selected` while cached local Notes/Graph rows were visible. The next patch therefore targets cache-only labeling and stale Halo/index diagnostic clearing, not graph rendering.
- 2026-05-08: `git diff --check` passed before the disconnected cache-only truthfulness patch. The first focused diagnostics test run failed at compile because the Notes cache banner referenced a non-existent `EpistemosTheme.primaryText`; after switching to `theme.resolved.foreground.color`, `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/SettingsCategoryTests` passed 11 Swift Testing tests in 1 suite; result bundle `build/xcode-results/2026-05-08-144026-7322.xcresult`. Launched-app verification is still required before promoting CU-006/CU-010.
- 2026-05-08: Launched audit app after the disconnected cache-only truthfulness patch. Computer Use verified Settings `General` now reports `Halo backend No active vault selected - Shadow/Halo closed` and `Background indexing No active vault selected - cached local note/graph data only`; Settings `Vault` now explicitly warns cached local notes/graph rows may still be visible while disconnected; Notes now renders a `Disconnected Local Cache` banner and create/save controls are labeled `Select Vault...` / `No Vault Connected`. `ps -p 16033 -o pid,etime,%cpu,rss,comm` showed 1.4% CPU and 289,968 KiB RSS after the pass. Fresh logs still show a current-pid `kTCCServiceListenEvent` preflight through `ThemeWidgetControlViewService`, tracked as CU-012.
- 2026-05-08: `git diff --check` passed before the connected-vault graph-sync patch. `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/VaultSyncServiceAuditTests` passed 46 Swift Testing tests in 1 suite; result bundle `build/xcode-results/2026-05-08-152126-68387.xcresult`. This verifies restored/imported vaults emit `.vaultChanged`, and local vault mutation events mark `graphState.needsRefresh` before event-bus observers run. A connected-vault Computer Use smoke is still required before CU-011 can be marked verified fixed.
- 2026-05-08: `git diff --check` passed before the saved-state document restore patch. `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/EpistemosDocumentControllerTests` passed 20 Swift Testing tests in 1 suite; result bundle `build/xcode-results/2026-05-08-154443-14996.xcresult`. A launched audit-app smoke confirmed the fresh app now opens Landing instead of restoring the stale `Untitled` Epdoc window.
- 2026-05-08: `git diff --check` passed before the landing-agent static shelf patch. `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/CompanionAvatarGrammarSourceGuardTests` passed 7 Swift Testing tests in 1 suite; result bundle `build/xcode-results/2026-05-08-155559-42983.xcresult`. Launched audit-app verification against pid 54172 showed the compact top-right `AGENTS` shelf and `ps` reported 0.0% CPU after launch and after a longer idle sample.
- 2026-05-08: Targeted landing/Epdoc/Mini Chat/Notes fix verification passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/LandingWaveChoreographyTests -only-testing:EpistemosTests/EpdocCopilotSurfaceTests -only-testing:EpistemosTests/MiniChatViewAuditTests -only-testing:EpistemosTests/RuntimeValidationTests/landingSearchUsesLiquidWaveOverlay -only-testing:EpistemosTests/NoteWindowManagerTests -only-testing:EpistemosTests/SettingsWindowPresentationTests`
  passed 59 Swift Testing tests in 6 suites; result bundle
  `build/xcode-results/2026-05-08-163706-20577.xcresult`.
- 2026-05-08: Local model install-detection gate after the user's model install
  passed:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/LocalModelInfrastructureTests`
  (76 Swift Testing tests in 1 suite; result bundle
  `build/xcode-results/2026-05-08-164053-25519.xcresult`). This verifies
  installed hub snapshot detection, not full inference for every model.
- 2026-05-08: Targeted Computer Use smoke on pid 44275 verified the landing
  search caret now follows typed text, `@` opens the notes/chats picker, `slash`
  opens the command palette, Epdoc opens with only `Visualize document` and
  `Add frontmatter`, `⌘3` opens Mini Chat from Epdoc, and `⌘2` opens a compact
  Notes panel. `ps -p 44275 -o pid,etime,%cpu,rss,comm` showed 0.1% CPU /
  290,304 KiB RSS after the smoke. Fresh logs during the Epdoc/Mini Chat path
  still show WebKit/TCC accessibility preflights and AppKit
  `Internal inconsistency in menus`; these remain tracked under CU-012 /
  launch-runtime log follow-up and were not claimed fixed in this targeted
  stop.
- 2026-05-08: Source-only follow-up per user request, with no Computer Use:
  bottom landing command shortcuts were returned to the native system UI font;
  external vault file-watcher imports now publish canonical `.vaultChanged`
  instead of only bumping the idle mutation epoch; and the AppKit graph menu
  fallback now retargets existing SwiftUI-owned menu items without inserting
  `NSMenuItem`s. Verification:
  `./scripts/xcodebuild_epistemos.sh -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test -only-testing:EpistemosTests/NoteWindowManagerTests -only-testing:EpistemosTests/VaultSyncServiceAuditTests -only-testing:EpistemosTests/RuntimeValidationTests`
  passed 339 Swift Testing tests in 3 suites; result bundle
  `build/xcode-results/2026-05-08-171538-68569.xcresult`. `git diff --check`
  passed.
