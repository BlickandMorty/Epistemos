> ⛔ SUPERSEDED 2026-06-26 — Goose is the SINGLE surface. The 3-engine federation (Chat=AgentClone / Work=OpenGUI) described here is RETIRED. Canonical plan: `docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md` (§0, §15). Do not follow the federation / OpenGUI directives below.

# Act/AgentClone Clone Delta Audit - 2026-06-25

Purpose: record the current read-only comparison between the upstream Agent
study clone and the Epistemos `LocalPackages/AgentClone` package. This is a
lane-local audit only; it does not authorize touching Work/OpenGUI/Goose or the
app-wide graph/chat/mini/note deletion work.

## Compared Sources

- Upstream study clone: `.research-clones/swift-act/agent-macos26`
- Upstream app root compared: `.research-clones/swift-act/agent-macos26/Agent`
- Local package compared: `LocalPackages/AgentClone/Sources/AgentClone`
- Provenance study commit: `fc07409a900ba4ed4ecbf851e93aa8f18d1dcd94`
- Commands run:
  - `find .research-clones/swift-act/agent-macos26/Agent -type f | wc -l`
  - `find LocalPackages/AgentClone/Sources/AgentClone -type f | wc -l`
  - `find ... -name '*.swift' -o -name '*.json' -o -name '*.plist' -o -name '*.entitlements' | wc -l`
  - `diff -qr --exclude=.git --exclude=.build --exclude=.swiftpm .research-clones/swift-act/agent-macos26/Agent LocalPackages/AgentClone/Sources/AgentClone`

## Current Inventory Result

- Upstream `Agent` file count: 251 files.
- Local `Sources/AgentClone` file count: 254 files.
- Upstream Swift/JSON/plist/entitlements count: 230 files.
- Local Swift/JSON/plist/entitlements count: 233 files.
- The local count increase is explained by Epistemos-owned additive package
  files rather than a missing donor surface:
  - `EpistemosAgentBridge.swift`
  - `EpistemosReskin.swift`
  - `AgentViewModel/Core/HostContext.swift`

## Expected Adapted Areas

The diff is intentionally not empty. The local package is not a pristine
submodule; it is the Epistemos-skinned, SwiftPM-hosted AgentClone package. The
current adapted areas are expected:

- SwiftPM packaging under `LocalPackages/AgentClone`.
- Epistemos theme-token injection via `AgentSkin.configure(...)`.
- Direct app prompt bridge through `AgentCloneBridge.submitPrompt(_:)`.
- Workspace mode selection notification through `WorkspaceModeSelection`, so
  app entrypoints that select Act update a mounted `HomeRouter` instead of only
  writing defaults for a future mount.
- App-owned context snapshot through
  `Epistemos/Views/AgentFusion/AgentCloneAppContextSnapshot.swift`. This file
  is outside the donor package and keeps app name, workspace, vault,
  app-support, mode, and presentation context plain and bounded before RootView
  projects it into the clone bridge. Its model-visible summary/JSON omit the
  internal app-support path.
- `EpistemosTests/AgentCloneAppContextSnapshotTests.swift` is the app-side
  no-model proof for that boundary: blank fields normalize, model-visible JSON
  stays deterministic, app-support storage does not leak, and deleted
  graph/note/mini/chat state is not imported.
- Host-context bridge through `AgentCloneHostContext` and
  `AgentViewModel.applyEpistemosHostContext(_:)`.
- Host-owned compatibility storage root in `AgentCloneHostContext`, currently
  used only for clone JSONL session transcripts. RootView passes
  `~/Library/Application Support/Epistemos/AgentClone` and AgentClone writes
  new sessions under its `sessions/` child while importing/reading legacy donor
  session files as fallback.
- On-appear host-context recovery through `AgentCloneBridge.currentHostContext`,
  so a context update posted before `ContentView` subscribes still reaches the
  side-panel summary and the next prompt run.
- Side-panel `Epistemos context` readout.
- Model-visible `[Epistemos context: ...]` task prefix for main and tab tasks.
- Bridge-submitted prompts now call AgentClone's normal `run()` /
  `runTabTask(tab:)` paths, so prompts posted while a main or tab task is busy
  enter the clone's existing queue instead of sitting inert in the input field.
- Bridge-submitted prompts are also buffered by id until consumed. If an app
  entrypoint posts just before `AgentClone.ContentView` mounts, the view drains
  those pending prompts on appear and runs them through the same main/tab path.
- Foreground copy changes from donor helper labels to Epistemos/user/privileged
  helper wording.
- Bundled help resources now use Epistemos foreground language for product,
  task, script, helper, provider, privacy, and troubleshooting pages. Technical
  compatibility paths such as `Documents/AgentScript` and helper service ids
  remain only where they are real runtime/debug identifiers.
- `AgentCloneChatHostSurface` rail labels now use foreground-neutral wording
  (`Swift agent foundation`, `Epistemos bridge`) instead of donor module names.
- `AgentCloneChatHostSurface` rail controls now preserve reachability: hidden
  desktop rails show restore buttons, and compact layouts use explicit overlay
  state for session/context panels rather than inert toggle buttons.
- Left-side control panel restoration for the embedded capability panel.
- Route guards and donor-contract docs that reject deleted Osaurus bridge names
  and old Epistemos chat backend routes.

## Protected Deep Contracts Preserved

The current hardening deliberately does not rename these runtime-sensitive
contracts:

- `AgentClone`
- `AgentCloneBridge`
- `AgentScript` script/tool/storage roots, except where a specific migrated
  app-owned fallback exists
- `agentProjectFolder`
- `AGENT_PROJECT_FOLDER`
- `AgentProjectPaths`
- provider service types such as `ClaudeService`, `CodexService`,
  `OpenAICompatibleService`, `OllamaService`, and `FoundationModelService`
- MCP service/config names
- keychain/bundle/helper implementation names
- donor repo/provenance paths and test references

## Current Integration Truth

- RootView mounts `AgentCloneChatHostSurface` for Chat/Act. That
  Epistemos-owned shell adds native session/context rails and embeds
  `AgentClone.ContentView()` as the protected Swift-agent foundation.
- RootView injects Epistemos theme tokens into `AgentSkin`.
- RootView builds `AgentCloneAppContextSnapshot` and passes it to
  `AgentCloneChatHostSurface`, so visible app context is owned by Epistemos
  without renaming clone internals.
- `AgentCloneChatHostSurface` shows the snapshot's model-visible summary in
  the context rail, keeping app grounding visible behind the existing side
  panel instead of adding or deleting surfaces.
- RootView derives `AgentCloneHostContext` from that snapshot and publishes it
  only while Chat/Act is active. The bridge now carries the presentation label
  into the existing side-panel/task-prefix context summary while keeping
  `appSupportRootPath` storage-only.
- RootView includes an internal `appSupportRootPath` in host context. This path
  is not added to the model-visible summary; it is used for Epistemos-owned
  compatibility state that should not live in donor-named user data folders.
- Landing still records the app-level `AgentChatState` turn and sends the
  prompt into the live clone through `AgentCloneBridge.submitPrompt(trimmed)`.
- `WorkspaceModeSelection.select(.act)` posts
  `epistemos.workspace.mode.didSelect`; `HomeRouter` listens for that event,
  updates `workspaceMode`, and syncs AgentClone host context when the selected
  mode is Chat/Act. This closes the defaults-only route gap for landing/app
  entrypoints.
- `WorkspaceModeSelection.select(_:)` posts the selected mode in
  `WorkspaceModeSelection.selectedModeUserInfoKey` and uses the `UserDefaults`
  instance as the notification object. This keeps production behavior simple
  while allowing tests to observe one defaults suite without picking up
  unrelated mode changes.
- AgentClone consumes prompt notifications through the active-tab/main-runner
  path, not through a parallel custom runner. If the selected runner is busy,
  the clone's existing main/tab prompt queue handles the new prompt.
- AgentClone keeps a small in-process pending-prompt queue behind
  `AgentCloneBridge`. Live notifications mark their prompt id consumed; missed
  notifications are drained on `ContentView` appear, preserving submission
  order without renaming the bridge notification.
- AgentClone adopts the Epistemos vault/workspace into `projectFolder` only
  when the current folder is empty, home, the same host-applied folder, or the
  new host folder.
- AgentClone applies any already-published host context on `ContentView` appear
  before draining pending prompts, so pre-mount host context and pre-mount
  prompts are recovered together.
- The Epistemos context summary now includes both `vault:` and `workspace:`
  when both are present. `preferredProjectFolder` still prioritizes the vault
  for cwd/tool rooting, preserving the existing project-folder contract.
- Manual clone project-folder selection remains authoritative.
- `SessionStore` now configures from `AgentCloneHostContext.appSupportRootPath`
  and writes new JSONL session transcripts under
  `Application Support/Epistemos/AgentClone/sessions`. It keeps
  `~/Documents/AgentScript/sessions` as a legacy import/read/delete fallback so
  existing sessions are not broken by the foreground appification. This is not a
  blanket rename of `AgentScript` script, skill, hook, memory, or tool roots.
- A small app-side `AgentStreamingSupport.swift` now carries the generic
  `DisplayPacedTextBuffer` and `StreamingReasoningTraceBuffer` helpers that
  `AgentChatState` still needs after the concurrent old-chat deletion removed
  their former home in `ChatState.swift`. This does not restore old Chat,
  Note Chat, Graph Chat, or MiniChat surfaces.

## Verification At This Audit Point

- `swift build` in `LocalPackages/AgentClone`: passed.
- `swift test` in `LocalPackages/AgentClone`: passed 6 tests for
  `AgentCloneHostContext` normalization, vault+workspace summary,
  vault-first preferred project folder, current host-context storage for
  on-appear recovery, pending prompt draining order, and live-notification
  prompt consumption.
- Baseline full donor-contract run before the session-storage seam:
  `swift test --package-path LocalPackages/EpistemosChatDonorContracts` passed
  69 tests, including the `AgentChatState` streaming-support extraction guard.
- Targeted donor-contract guards after the session-storage/help/rail-label
  seam:
  `swift test --package-path LocalPackages/EpistemosChatDonorContracts --filter 'testActLandingRoutesDirectlyToAgentCloneFoundationWithoutOsaurusBridge|testAgentCloneHelpResourcesUseEpistemosForegroundNames|testAgentCloneRouteDocumentationMatchesDirectRouteTruth'`
  passed. The route guard now verifies `appSupportRootPath`, Epistemos-owned
  session JSONL storage, donor-session fallback, and the
  `AgentCloneChatHostSurface` wrapper embedding `AgentClone.ContentView()`.
- Targeted rail-control parse passed:
  `xcrun swiftc -parse Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift EpistemosTests/SourceMirrorTestSupport.swift EpistemosTests/ActSurfaceOsaurusUIDirectionGuardTests.swift`.
- `jq empty docs/donor-contracts/swift-chat/agent-clone/provenance.json`:
  passed.
- Scoped `git diff --check`: passed.
- Foreground quoted-literal scan over AgentClone foreground directories:
  clean for stale donor/runtime labels.
- Protected runtime-contract guard: passed. It verifies the package still keeps
  donor-compatible prompt version headers, protected `AgentScript` script/tool
  roots, the legacy session import fallback,
  keychain service names, `agentProjectFolder`, `AGENT_PROJECT_FOLDER`,
  helper daemon implementation names, provider service type names, and
  `epistemos.agentclone.*` bridge notification names.
- Bridge queue/context guard: passed. It rejects the old notification path that
  skipped `run()`/`runTabTask(tab:)` while busy, and rejects the old context
  summary that hid `workspace:` whenever `vault:` existed.
- Missed-prompt guard: passed. It verifies `AgentClonePendingPrompt`,
  `promptIDUserInfoKey`, `markPromptConsumed(id:)`, `drainPendingPrompts()`,
  and `ContentView` pending-drain wiring remain present.
- Missed-context guard: passed. It verifies `ContentView` calls
  `applyCurrentHostContext()` before `drainPendingBridgePrompts()` on appear.
- Mode-selection guard: passed. It verifies `WorkspaceModeSelection.select(_:)`
  posts `epistemos.workspace.mode.didSelect` and `HomeRouter` consumes that
  event to update the mounted `workspaceMode`.
- App-level mode-selection behavior test added. `WorkspaceModeSelectionTests`
  now verifies selecting a mode writes the selected raw value and emits the live
  route notification with the same selected mode payload.
- App-level Act source guard extended. `ActSurfaceOsaurusUIDirectionGuardTests`
  now also verifies `AgentStreamingSupport.swift` owns the generic streaming
  helpers, `AgentChatState` uses them, and deleted old chat-state files stay
  absent.
- App-level Act source guard parse passed after wrapper/help updates:
  `xcrun swiftc -parse EpistemosTests/SourceMirrorTestSupport.swift EpistemosTests/ActSurfaceOsaurusUIDirectionGuardTests.swift`.
- App-level snapshot behavior proof added:
  `EpistemosTests/AgentCloneAppContextSnapshotTests.swift` verifies
  `AgentCloneAppContextSnapshot` normalization, model-visible summary/JSON,
  app-support omission, and plain app-owned source boundaries.
- Stale visible helper-name scan over scoped AgentClone files: clean.
- Help-resource foreground scan: clean for `Agent!`, `Agent Help`,
  `Agent Scripts`, `Privileged Daemon`, `Settings -> Daemon`,
  `Launch Daemon`, `User Agent`, `Background Agents`, `Agent Question`,
  `OpenCode`, `Goose`, and `Osaurus`.
- Targeted donor-contract help guard:
  `swift test --package-path LocalPackages/EpistemosChatDonorContracts --filter testAgentCloneHelpResourcesUseEpistemosForegroundNames`
  passed.
- Deleted Osaurus bridge-name scan over RootView/Landing/AgentClone: only
  negative guard assertions in tests.
- Targeted Xcode guard attempt:
  `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosActAgentCloneDD-20260625-1603 test -only-testing:EpistemosTests/ActSurfaceOsaurusUIDirectionGuardTests`
  reached the shared app target but failed before running the Act guard because
  unrelated Graph/Farm sources do not compile:
  `DialogueNodeProfile`, `ContentPersonalitySignals`,
  `DialogueNodeInsight`, `DialogueMood`, `DialoguePortraitAsset`,
  `DialogueCareState`, `onSelectNode`/`onRevealNode`, and UUID/String
  mismatches. This is outside the Act/AgentClone lane and was not repaired
  here.
- Targeted Xcode mode-selection attempt:
  `xcodebuild -quiet -project Epistemos.xcodeproj -scheme Epistemos -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/EpistemosActAgentCloneDD-20260625-mode-notify test -only-testing:EpistemosTests/WorkspaceModeSelectionTests`
  first exposed missing generic streaming helpers from `AgentChatState`
  (`DisplayPacedTextBuffer`, `StreamingReasoningTraceBuffer`) after the old
  chat-state deletion. Those helpers were extracted into
  `Epistemos/State/AgentStreamingSupport.swift`. The incremental rerun then
  hit a stale deleted-file reference to
  `Epistemos/Views/Chat/AgentRunTimelineView.swift`. A fresh derived-data rerun
  got past that stale reference, but the generated app target file list still
  includes deleted old-chat files
  `Epistemos/Views/Chat/AnswerPacketBadge.swift` and
  `Epistemos/Views/Chat/ChatBrainPickerMenu.swift`. That source-membership
  cleanup belongs to the concurrent deletion/refactor lane and was not repaired
  here.

## Remaining Delta Work

- Full-app Xcode guard runs are currently blocked by unrelated shared app
  compile failures in Graph/Farm code owned by the deletion/refactor lane.
- Full visual readback should be refreshed after app-wide build blockers clear.
- The post-isolation portal plan for MiniChat, Graph Chat, Note Chat, document
  context, graph context, and app-native actions lives in
  `docs/handoffs/ACT_AGENTCLONE_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md`.
