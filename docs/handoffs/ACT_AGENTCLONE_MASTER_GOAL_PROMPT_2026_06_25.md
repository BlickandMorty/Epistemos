# Act/AgentClone Master Goal Prompt - 2026-06-25

Use this as the copy/paste goal prompt for the next Act/AgentClone integration loop. It is intentionally scoped to the
current Act chat lane: the hosted AgentClone surface, Epistemos foreground chrome, deleted Osaurus bridge boundary, and the
bridge from app entrypoints into the agent surface.

Owner's latest correction to preserve in every restart:
- Keep working in the Act/AgentClone lane until the owner explicitly says stop.
- Carry two tracks in parallel: code hardening inside the clone boundary, and deep research/documentation for the later
  app-context deepening pass.
- Harden the clone-contained backend/frontend path first. Only after that should graph, note, mini-session, and native app
  actions be deepened, and only after the owner lifts the current isolation.
- Do not delete or minimize away donor capability. Hide secondary detail behind the existing side panel, popovers, toggles,
  diagnostics, or settings fallbacks.
- Do not rename deep/runtime names just to make the foreground look branded. Rename or hide visible foreground text when it
  is safe; preserve imports, APIs, storage keys, env vars, bundle/keychain/helper identifiers, repo paths, provider ids, and
  other runtime contracts unless a migration is designed and proven.

Current proof baseline before the next loop:
- `swift build` passes in `LocalPackages/AgentClone`.
- `swift test` passes in `LocalPackages/AgentClone` with 6 no-model tests for
  `AgentCloneHostContext` normalization, vault+workspace summary, vault-first preferred project folder,
  current host-context storage for on-appear recovery, pending prompt draining order, and live-notification prompt
  consumption.
- Baseline full donor-contract run before the latest session-storage seam:
  `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed 69 tests, including the direct
  Act/AgentClone landing bridge guard, direct-route documentation guard, and `AgentChatState` streaming-support
  extraction guard. Latest targeted rerun after the storage/help/rail-label seam
  passed `testActLandingRoutesDirectlyToAgentCloneFoundationWithoutOsaurusBridge`,
  `testAgentCloneHelpResourcesUseEpistemosForegroundNames`, and the direct-route
  documentation guard.
- Current RootView mounts `AgentCloneChatHostSurface` for Chat/Act. That Epistemos-owned host shell embeds
  `AgentClone.ContentView()` as the protected Swift-agent foundation and injects Epistemos theme tokens through
  `AgentClone.AgentSkin.configure(...)`.
- Current LandingView submission selects `.act`, preserves the app-level `AgentChatState` session record, and in non-App
  Store builds calls `AgentCloneBridge.submitPrompt(trimmed)` so the visible AgentClone runner receives the prompt.
- `WorkspaceModeSelection.select(_:)` now posts `epistemos.workspace.mode.didSelect`, and `HomeRouter` listens for that
  event to update the mounted `workspaceMode`. This means landing/app entrypoints that select Act move the visible route
  immediately instead of only updating defaults for a future mount.
- `WorkspaceModeSelectionTests` now includes a behavior test proving selection writes the chosen raw mode and emits the
  live route notification with that mode payload. The test observes the same `UserDefaults` suite as the notification
  object so unrelated mode changes do not produce false positives.
- Current RootView builds an app-owned `AgentCloneAppContextSnapshot` with Epistemos app name, workspace root, active
  vault root, app-support root, mode label, and presentation. The Act host shell receives that plain context, and RootView
  derives `AgentCloneHostContext` from it for the clone bridge, including the
  presentation/surface label in the model-visible task-prefix summary.
- `AgentCloneAppContextSnapshot` now also exposes a deterministic model-visible summary and sorted-key JSON payload for
  future app-context resources. That payload intentionally omits the internal app-support path; app-support remains a
  storage/migration contract, not model-facing context.
- `EpistemosTests/AgentCloneAppContextSnapshotTests.swift` now proves the
  snapshot's normalization, deterministic model-visible JSON, app-support
  omission, and plain app-owned source boundary.
- AgentClone consumes that context through its existing `projectFolder` seam without renaming `agentProjectFolder` or
  `AGENT_PROJECT_FOLDER`, and it avoids overwriting a manual user-selected project folder.
- Current RootView also publishes an internal `appSupportRootPath` for
  `Application Support/Epistemos/AgentClone`. AgentClone uses it only for
  Epistemos-owned compatibility state: new JSONL session transcripts now write
  under `sessions/` there, while `~/Documents/AgentScript/sessions` remains a
  legacy import/read/delete fallback.
- AgentClone applies `AgentCloneBridge.currentHostContext` on `ContentView` appear before draining pending prompts, so a
  RootView context update posted before subscription still reaches the side-panel summary and prompt grounding.
- The AgentClone side panel includes a compact `Epistemos context` readout when the host context bridge is active, so the
  user can verify app grounding without a new surface or removed controls.
- AgentClone injects the host-context summary into its normal task prefix for main and tab tasks. This gives the model
  Epistemos app grounding while keeping execution inside the existing clone runner.
- Bridge-submitted prompts now call AgentClone's normal `run()` / `runTabTask(tab:)` paths, so app entrypoint prompts queue
  through the clone's existing main/tab queues when a task is already busy instead of being stranded in the input field.
- Bridge-submitted prompts now also carry a prompt id and remain in an AgentClone-owned pending buffer until consumed.
  Live notifications mark their id consumed; prompts posted before `ContentView` subscribes are drained on appear and run in
  submission order through the same main/tab execution path.
- The current context summary includes both `vault:` and `workspace:` when both are present. `preferredProjectFolder` still
  prioritizes the vault for cwd/tool rooting, so the deeper project-folder contract is not renamed or weakened.
- A foreground donor-name guard now scans the embedded AgentClone foreground directories for quoted UI literals containing
  `Agent!`, `AgentClone`, `Agent Question`, `User Agent`, `Background Agents`, `Daemon`, `OpenCode`, `Goose`, or `Osaurus`.
  It deliberately does not scan protected service/runtime sources, where some donor names are still required.
- A help-resource foreground guard now scans the bundled `Agent.help` HTML
  resources for stale donor product/helper labels. Help pages should say
  Epistemos/Epistemos Scripts/privileged helper, while code-spanned
  compatibility paths and helper ids may remain when they are real runtime
  facts.
- A reverse protected-name guard now verifies that prompt version headers,
  protected `AgentScript` script/tool roots, the legacy session import fallback,
  keychain service names, `agentProjectFolder`, `AGENT_PROJECT_FOLDER`, helper
  daemon implementation names, provider service type names, and
  `epistemos.agentclone.*` bridge notifications stay compatible.
- Current donor records classify ChatView2 route/panel/transcript work as rejected historical experiments. Do not restore
  `ChatRouteView` or the deleted Epistemos/Chat backend route to make Chat/Act look more Epistemos-native; rebuild visual
  language inside AgentClone instead.
- The Act settings pane has been removed by the concurrent surface deletion sweep. In this lane, do not restore deleted
  `ActCloneSettingsView`, Osaurus package files, or Osaurus compatibility notification names.
- `Epistemos/State/AgentStreamingSupport.swift` is an app-side compatibility extraction for generic streaming helpers that
  `AgentChatState` still needs after old `ChatState.swift` was deleted. Do not treat it as permission to restore old
  Chat/Note/Graph/MiniChat surfaces. This seam is guarded in both
  `EpistemosTests/ActSurfaceOsaurusUIDirectionGuardTests.swift` and the donor-contract package.
- Deferred MiniChat/Graph Chat/Note Chat/native-feature deepening is tracked in
  `docs/handoffs/ACT_AGENTCLONE_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md`. Do not implement those app-wide portals
  until the owner lifts the current isolation.
- Current clone-origin delta audit is saved in
  `docs/handoffs/ACT_AGENTCLONE_CLONE_DELTA_AUDIT_2026_06_25.md`.
- Full Xcode package resolution succeeds, but targeted Xcode test attempts still fail before running lane guards because
  of app-wide deletion/refactor blockers outside this lane. Observed blockers include missing Graph/Farm symbols
  (`DialogueNodeProfile`, `ContentPersonalitySignals`, `DialogueNodeInsight`, `DialogueMood`, `DialoguePortraitAsset`,
  `DialogueCareState`, `onSelectNode`/`onRevealNode`, UUID/String mismatches), a stale derived-data reference to deleted
  `Epistemos/Views/Chat/AgentRunTimelineView.swift`, and a current generated app target file list that still includes
  deleted `Epistemos/Views/Chat/AnswerPacketBadge.swift` and
  `Epistemos/Views/Chat/ChatBrainPickerMenu.swift`. Treat those as outside-lane unless explicitly reassigned.

```text
Continue the Epistemos Act / AgentClone integration loop in /Users/jojo/Downloads/Epistemos until I explicitly say stop.

Objective:
Make Act behave like a deeply integrated Epistemos chat/agent surface while preserving the underlying donor/runtime
contracts that must not be renamed. The visible surface should feel like Epistemos: flat, minimal, theme-aware, usable,
and connected to the app's graph, notes, vault context, settings shell, and app entrypoints. Do not remove capability to
make the foreground look cleaner; move details behind toggles, side panels, popovers, diagnostics, or settings fallbacks.
Every cycle has two objectives:
1. Harden one clone-contained integration gap that can be safely improved now.
2. Update the deepening research/docs for later graph/note/mini/native integration, without implementing those app-wide
   seams while isolation is active.
3. Re-audit foreground naming versus protected runtime naming before and after each rename or reskin pass.
4. Leave the goal active until the whole assigned Act/AgentClone integration is complete and verified, or until I say stop.

Scope:
This lane covers RootView/HomeRouter Act routing, hosted AgentClone embedding, AgentClone prompt receiver, foreground copy,
theme token injection, app entrypoint notifications, graph/note/landing Act prompt bridge, donor-contract guards,
foreground/deep-name classification, and the handoff/status docs for this lane.

Stay in lane:
- Do not delete, restore, or project-rewire the concurrent Osaurus deletion sweep unless the owner explicitly assigns that
  work to you.
- Do not touch unrelated Work/OpenGUI/Goose files except to read status or avoid collisions. Use the Work/OpenGUI master
  prompt for that lane.
- Do not rename package names, module names, imports, API contracts, notification names, storage keys, bundle ids, keychain
  names, shell/runtime identifiers, protocol strings, or donor repo paths unless there is exact source proof and tests for a
  migration.
- If the full app build fails because the Xcode project still references deleted OsaurusCore paths, record that as an
  outside-lane blocker. Do not silently restore or remove those project references from this lane.
- Apply the same rule to deleted old-chat project references such as
  `Epistemos/Views/Chat/AnswerPacketBadge.swift`,
  `Epistemos/Views/Chat/ChatBrainPickerMenu.swift`, or stale derived-data
  references such as `Epistemos/Views/Chat/AgentRunTimelineView.swift`; record
  them, but do not revive old chat files or edit project membership from this
  lane unless the owner explicitly reassigns that cleanup.

Read first:
1. docs/WORK_CANON_STATUS_2026_06_25.md
2. docs/donor-contracts/swift-chat/INDEX.md
3. docs/donor-contracts/swift-chat/agent-clone/provenance.json
4. LocalPackages/AgentClone/Sources/AgentClone/EpistemosAgentBridge.swift
5. LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/HostContext.swift
6. docs/handoffs/ACT_AGENTCLONE_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md
7. docs/handoffs/ACT_AGENTCLONE_CLONE_DELTA_AUDIT_2026_06_25.md
8. Epistemos/App/RootView.swift
9. Epistemos/App/EpistemosApp.swift
10. EpistemosTests/ActSurfaceOsaurusUIDirectionGuardTests.swift
11. EpistemosTests/AgentCloneAppContextSnapshotTests.swift
12. The current worktree and command outputs are authoritative. Inspect before editing.

Branding and naming law:
Foreground product text should say Epistemos, Act, chat, agent, tools, sessions, permissions, questions, recents,
history, runtime, or settings. Hide donor names in normal foreground copy when they are not the user's useful runtime
identity.
Foreground helper labels should use user/privileged helper wording; do not expose `Daemon` as normal app chrome unless a
diagnostic specifically needs the underlying LaunchDaemon identity.
Bundled help resources are foreground. Rebrand visible product/help text there
too, but keep exact tool names, env vars, and compatibility paths inside code
spans when they are still true.

Protected deep names stay:
AgentClone, AgentScript, AgentCloneBridge, package/module names, bundle ids, keychain service names, remote repo names,
runtime env vars, protocol strings, app tool names, and test/doc references that explain compatibility. Storage paths can
move only through explicit migration/import adapters; the current allowed move is JSONL session transcripts from
`Documents/AgentScript/sessions` into Epistemos app support with the donor path retained as fallback.
Deleted Osaurus bridge names must not return in app/root/landing source: `ActOsaurusPromptRequest`,
`submitActOsaurusPrompt`, `openActOsaurusSession`, `showActOsaurusSettings`, `LocalAgentLoop.shouldRouteActThroughOsaurus()`,
`forceActOsaurus`, and `OsaurusCore` imports.

Run a name-classification pass before every rename:
1. Foreground UI label: make it Epistemos/Act or neutral.
2. Picker/diagnostic/runtime identity: keep the real name if hiding it would make debugging or engine selection worse.
3. Donor/runtime/API/config/storage/protocol/import path: leave it named unless you have a migration and proof.
4. Compatibility symbol used by existing callers: preserve it and document why.

UI direction:
The target is flat, square, minimal, theme-aware, and close to the OpenCode-like reference screenshot: a calm main surface,
compact mode toggle, hidden/side details, no decorative nested cards, no fake placeholders that pretend to be live, and no
removed controls. Preserve AgentClone's side/navigation affordances where they carry real capability.

Integration direction:
- RootView/HomeRouter should keep `AgentCloneChatHostSurface` for Chat/Act, with that host shell embedding
  `AgentClone.ContentView()` as the protected foundation.
- Theme skin should flow from Epistemos tokens through `AgentClone.AgentSkin.configure(...)`.
- App context should flow through the app-owned `AgentCloneAppContextSnapshot` first, then into the bounded
  `AgentCloneHostContext` bridge. The snapshot can grow after isolation; the clone runtime contract should not be renamed
  just to expose more app context.
- Model-visible context summaries/resources must omit internal storage paths such as app support. Storage paths may remain
  in diagnostic/app-owned payloads only when they are needed for migration or compatibility proof.
- AgentClone's capability side panel should stay reachable from a left-side control rail; hide details behind that panel, do
  not delete them.
- Act entrypoints should route to the Act surface instead of silently falling through.
- Mode selection should be live, not just persisted. Keep the
  `WorkspaceModeSelection.didSelectNotification` route so Landing and future app entrypoints can switch a mounted
  `HomeRouter` to Act/Chat/Work. Keep the behavior test object-scoped to its
  `UserDefaults` suite so live notification proof stays deterministic.
- Landing submission should select `.act`, keep `AgentChatState` in sync, and in non-App Store builds call
  `AgentCloneBridge.submitPrompt(trimmed)` to drive the live AgentClone runner. Do not hide this bridge behind
  `isActSearchPage` unless that branch becomes a real route again.
- AgentClone should receive the bridge notification, write the prompt into the active tab or root task input, and run
  through its existing execution path rather than a parallel custom runner. Do not reintroduce the old busy-state behavior
  where bridge prompts were only staged into the input field; use `run()` / `runTabTask(tab:)` so existing queues remain
  authoritative.
- AgentClone should keep the prompt buffer backward-compatible: preserve
  `epistemos.agentclone.submitPrompt` and `promptUserInfoKey`, use the prompt id only as delivery metadata, mark live
  notifications consumed, and drain pending prompts on appear so pre-mount submissions are not lost.
- RootView should keep publishing bounded `AgentCloneHostContext` values when Chat/Act is active. AgentClone should adopt
  the active Epistemos vault/workspace through `projectFolder` only when doing so does not clobber a manual clone project
  folder. Keep the deep `agentProjectFolder` storage key and `AGENT_PROJECT_FOLDER` runtime env var named.
- RootView should keep publishing `appSupportRootPath` in `AgentCloneHostContext`
  for clone compatibility data that Epistemos can own now. `SessionStore` should
  write new JSONL transcripts under that app-support root and keep
  `Documents/AgentScript/sessions` as a legacy fallback. Do not bulk-rename
  script, skill, hook, prompt, memory, or tool roots without a separate
  migration adapter and proof.
- AgentClone should apply any already-published `currentHostContext` on view appear before draining pending prompts. This
  preserves app grounding when host context and a landing prompt are both posted before the clone surface subscribes.
- The host context summary should remain honest and complete for current safe fields: include both vault and workspace when
  both exist, while preserving the vault-first `preferredProjectFolder` behavior for runtime cwd/tool semantics.
- The existing control side panel should keep exposing the current Epistemos context summary when available. Do not put this
  in the main empty-state as explanatory chrome; keep it behind the side panel.
- Main-task and tab-task prompt construction should keep passing `epistemosHostContextSummary` into
  `TaskUtilities.newTaskPrefix(...)`, so model-visible app context and project-folder tooling stay aligned.
- Settings requests should not break when the deleted Act settings pane is absent. Use the existing Settings shell until
  the owner assigns a replacement settings surface; do not revive Osaurus settings notifications.
- ChatView2, old MessageBubble, and old ChatBrainPanel code paths are visual references only. The live route must remain
  an AgentClone-backed Epistemos host shell unless the owner explicitly reassigns the backend route work.
- MiniChat, Graph Chat, Note Chat, and richer native app actions should be reconceptualized as future AgentClone-backed
  portals after isolation, following the post-isolation deepening doc. Do not restore their deleted old chat backends from
  this lane.

Deepening research direction:
- Treat Work's `WorkAppContextSnapshot` plus `epistemos.context.snapshot` as the closest current pattern for later Act
  deepening, but do not import Work code into AgentClone from this lane.
- The next Act version after clone hardening should move from a display/prompt-only `AgentCloneHostContext` toward a
  bounded structured snapshot that can be read by the model and displayed in the side panel.
- Future MiniChat, Graph Chat, and Note Chat should become AgentClone-backed portals with typed context attachments and
  app-owned actions. They should not regain separate inference stacks.
- Every proposed app action needs an owner API, permission behavior, transcript-visible errors, and no-model tests before
  any real-model proof.

Work cycle:
1. Inspect `git status --short` and the scoped files before changing anything.
2. Reconfirm which changes are yours and which are concurrent deletion/Work changes. Never revert unrelated user or
   parallel-agent edits.
3. Harden one real gap at a time: routing, prompt bridge metadata, foreground copy, theme tokens, side-panel reachability,
   settings fallback, donor-contract guards, or stale tests/docs.
4. Add/update source guards when changing a contract. Prefer tight tests that protect behavior without requiring deleted
   files to exist.
5. Run focused verification after each meaningful group of edits.
6. Update `docs/WORK_CANON_STATUS_2026_06_25.md` with compact current truth, not a buried ledger.
7. Update `docs/handoffs/ACT_AGENTCLONE_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md` whenever a new safe future
   context/action seam is discovered.
8. Do not commit unless explicitly instructed.

Focused verification:
- `swift build` from `LocalPackages/AgentClone`.
- `swift test` from `LocalPackages/AgentClone`.
- `swift test --package-path LocalPackages/EpistemosChatDonorContracts`.
- Source scan for stale foreground donor labels in Act/AgentClone SwiftUI/AppKit surfaces.
- Directory-level foreground literal guard for embedded AgentClone foreground sources.
- Source scan for protected names to verify they remain where they are contracts.
- `jq empty Epistemos/Resources/Localizable.xcstrings` plus a donor-key/comment scan when string catalog changes.
- `git diff --check` over touched files.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -resolvePackageDependencies` as the package-graph check.
- Full `xcodebuild build` only to observe whether app-wide blockers moved; keep Work/Notes compile failures separated from
  Act/AgentClone lane work unless explicitly reassigned.
- `pgrep -fl "xcodebuild|swift-frontend|xctest|EpistemosTests|opencode serve|openwork-server|og-sidecar"` before closeout
  to avoid leaving processes behind.

Closeout requirements before claiming done:
- Act entrypoints post into a live receiver, not a dead notification.
- Landing prompts select Act and reach AgentClone through `AgentCloneBridge.submitPrompt(trimmed)`.
- Foreground copy avoids donor leakage while protected symbols remain named.
- Deepening docs identify what can become an AgentClone-backed portal later without requiring current isolation-breaking
  edits.
- Tests/docs reflect the current AgentClone-backed host route and do not require deleted Act settings/native chat files or old
  Osaurus bridge names.
- Full-app blockers are separated from lane-complete work and dated with exact failing commands.

Stop rule:
Keep the loop active until I explicitly say stop, or until the same external blocker repeats enough times that no
meaningful scoped progress remains possible. Do not redefine success around only the subset already finished.
```
