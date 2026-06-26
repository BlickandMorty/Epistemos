# Act/AgentClone Stopping Point Handoff - 2026-06-25

Purpose: clean stop point for the current Act/AgentClone lane so a new
directive can start without losing the integration state, naming policy, or
remaining work boundary.

## Current Lane Boundary

- Stay inside Act/AgentClone unless reassigned.
- Do not restore deleted Graph Chat, MiniChat, Note Chat, old ChatView, or
  Osaurus bridge files from this lane.
- Do not edit `Epistemos.xcodeproj` from this lane. The project uses
  file-system synchronized root groups for `Epistemos/` and `EpistemosTests/`.
- Do not rename package/module/import/API/env/storage/helper/keychain/runtime
  identifiers unless a migration and proof exist.
- Foreground copy may be Epistemos/Act/neutral. Deep donor/runtime names remain
  where they are contracts.

## Hardened Now

- `RootView` mounts `AgentCloneChatHostSurface` for Chat/Act and embeds
  `AgentClone.ContentView()` as the protected Swift-agent foundation.
- `RootView` configures `AgentClone.AgentSkin` from Epistemos theme tokens
  before mount.
- Landing/app entrypoints select `.act`, keep the app-side `AgentChatState`
  record, and send prompts through `AgentCloneBridge.submitPrompt(trimmed)`.
- `AgentCloneBridge` buffers missed prompts by id until `ContentView` drains
  them on appear, preserving pre-mount submissions.
- `AgentCloneBridge.currentHostContext` preserves pre-mount host context; the
  clone applies it on appear before draining pending prompts.
- `AgentCloneAppContextSnapshot` is the app-owned plain-value context boundary.
  It carries app name, workspace, vault, app-support root, mode, and
  presentation.
- `AgentCloneAppContextSnapshot.modelVisibleSummary` and `modelVisibleJSON`
  provide deterministic model-visible context and intentionally omit
  `appSupportPath`.
- `RootView` derives `AgentCloneHostContext` from that snapshot and publishes it
  only while Chat/Act is active.
- `AgentCloneHostContext` now carries app name, workspace, vault, app-support
  root, mode, and presentation. Its summary includes mode/surface/vault/workspace
  but does not include app-support storage.
- AgentClone adopts the Epistemos vault/workspace as `projectFolder` only when
  safe: empty, home, same host-applied folder, or same new folder. Manual clone
  project-folder selection remains authoritative.
- `SessionStore` writes new JSONL sessions under
  `Application Support/Epistemos/AgentClone/sessions` while retaining
  `~/Documents/AgentScript/sessions` as legacy import/read/delete fallback.
- The existing AgentClone side panel remains reachable. The Epistemos host
  wrapper keeps left/right rails and restore controls for hidden rails and
  compact overlays.
- The context rail shows the app snapshot summary without adding a new surface
  or deleting clone controls.
- Bundled help foreground pages use Epistemos/Epistemos Scripts/privileged
  helper wording while preserving exact compatibility paths/helper ids where
  they are real runtime facts.
- Source guards and donor-contract guards reject deleted Osaurus bridge names
  and old local-chat backend route revival.

## Proof Added In This Stop Cycle

- `EpistemosTests/AgentCloneAppContextSnapshotTests.swift` proves:
  - blank fields normalize to safe defaults or nil
  - `modelVisibleSummary` is stable
  - `modelVisibleJSON` includes app/mode/presentation/vault/workspace
  - `modelVisibleJSON` omits app-support storage
  - the snapshot source does not import AgentClone, GraphState, NoteChat,
    MiniChat, ChatState, or `AppBootstrap.shared`
- `LocalPackages/AgentClone/Tests/AgentCloneTests/AgentCloneHostContextTests.swift`
  proves the clone bridge summary includes `surface: main` and still preserves
  vault-first project-folder rooting.
- Donor-contract source paths now include the new snapshot behavior test.

## Verification At Stop

Use the current command output as authoritative for this stop:

- `swift test --package-path LocalPackages/AgentClone --filter AgentCloneHostContextTests`
  passed 6 tests.
- Swift parse checks passed for:
  - `Epistemos/Views/AgentFusion/AgentCloneAppContextSnapshot.swift`
  - `Epistemos/Views/AgentFusion/AgentCloneChatHostSurface.swift`
  - `EpistemosTests/SourceMirrorTestSupport.swift`
  - `EpistemosTests/ActSurfaceOsaurusUIDirectionGuardTests.swift`
  - `EpistemosTests/AgentCloneAppContextSnapshotTests.swift`
- Swift parse check passed for
  `LocalPackages/EpistemosChatDonorContracts/Tests/EpistemosChatDonorContractsTests/ChatDonorContractsTests.swift`.
- Targeted donor-contract guard passed:
  `swift test --package-path LocalPackages/EpistemosChatDonorContracts --filter testChatModeKeepsAgentCloneFoundationAndRejectsOldBackendRoute`.
- `jq empty docs/donor-contracts/swift-chat/agent-clone/provenance.json`
  passed.
- Scoped `git diff --check` over touched Act/AgentClone files and docs passed.
- Scoped foreground naming scans over Act/AgentClone foreground Swift and help
  resources were clean for stale donor labels such as `AgentClone foundation`,
  `AgentClone bridge`, `Agent!`, `Agent Question`, `User Agent`,
  `Background Agents`, `Privileged Daemon`, `OpenCode`, `Goose`, and `Osaurus`.

## Known Non-Completion

- Full app-native graph/note/mini/document/native-action tools are not
  implemented yet. They are documented in
  `ACT_AGENTCLONE_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md` and should wait
  until the owner lifts isolation.
- Full app Xcode testing remains outside this stop point because app-wide
  deletion/refactor blockers were previously observed outside the Act/AgentClone
  lane. Do not fix those from this lane unless explicitly reassigned.
- The Act host is deeply grounded into the app through prompt delivery, route
  selection, app context, project-folder adoption, task-prefix context, visible
  context rails, and Epistemos-owned session storage. It is not yet a complete
  graph/note/mini/native Epistemos action surface.

## Resume Prompt

Use `docs/handoffs/ACT_AGENTCLONE_MASTER_GOAL_PROMPT_2026_06_25.md` as the
master resume prompt for this lane. Start by reading this stopping-point
handoff, then the master prompt, then the current worktree. Continue only inside
the Act/AgentClone lane unless the owner gives a new directive that explicitly
changes scope.
