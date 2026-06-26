> ⛔ SUPERSEDED 2026-06-26 — Goose is the SINGLE surface. The 3-engine federation (Chat=AgentClone / Work=OpenGUI) described here is RETIRED. Canonical plan: `docs/research/SURFACE_EMBEDDING_WEBVIEW_VS_NATIVE_DECISION_2026_06_25.md` (§0, §15). Do not follow the federation / OpenGUI directives below.

# Act/AgentClone Post-Isolation Deepening Plan - 2026-06-25

Purpose: this is the living plan for deepening Epistemos Act after the current
graph/chat/mini-chat/note isolation is lifted. Until then, keep implementation
inside the Act/AgentClone lane: `LocalPackages/AgentClone`, the RootView mount
seam, guard tests, and docs. Do not restore deleted Graph Chat, MiniChat, Note
Chat, or old ChatView paths from this lane.

## Current Safe Boundary

- The live Act/Chat route mounts `AgentCloneChatHostSurface` from
  `HomeRouter.chatModeSurface`; that Epistemos-owned host shell embeds
  `AgentClone.ContentView()` as the protected Swift-agent foundation.
- Epistemos owns the visible skin through `AgentClone.AgentSkin.configure(...)`.
- AgentClone keeps its donor/runtime contracts named: package/module names,
  `AgentCloneBridge`, `agentProjectFolder`, `AGENT_PROJECT_FOLDER`, provider
  setup, helper services, project tools, storage keys, and MCP/runtime strings.
- The current app-to-clone bridge is intentionally small:
  - `AgentCloneAppContextSnapshot` is now the app-owned plain-data boundary
    that RootView builds before handing context to the Act host shell and the
    clone bridge. It carries app name, workspace root, vault root, app-support
    root, mode label, and presentation without importing graph/note/mini UI
    state into the clone.
  - The snapshot already has a deterministic model-visible summary and
    sorted-key JSON payload. That model-visible payload omits the internal
    app-support root so storage/migration paths do not leak into model context.
  - `EpistemosTests/AgentCloneAppContextSnapshotTests.swift` proves this
    normalization/JSON boundary directly, so future note/graph/mini fields
    should extend that test before they are surfaced to the clone.
  - `AgentCloneBridge.submitPrompt(_:)` posts prompts into the live clone.
  - `AgentCloneBridge` now buffers submitted prompts by id until the live clone
    consumes them. This covers the app-entrypoint/pre-mount timing gap without
    changing the bridge notification name or adding a separate runner.
  - `AgentCloneBridge.updateHostContext(_:)` publishes app context, including
    the current presentation/surface label as model-visible grounding.
  - `AgentViewModel.applyEpistemosHostContext(_:)` safely adopts the active
    Epistemos vault/workspace as AgentClone's `projectFolder` only when it will
    not overwrite a manual user-selected project folder.
  - `AgentCloneHostContext.appSupportRootPath` gives the clone an Epistemos
    app-owned compatibility data root without putting that path in the
    model-visible context summary.
  - `SessionStore` uses that root for JSONL session transcripts and keeps
    `~/Documents/AgentScript/sessions` as a legacy import/read/delete fallback.
    This is a controlled session-store migration, not a blanket rename of
    script, skill, hook, memory, or tool roots.
  - `ContentView` applies the latest `AgentCloneBridge.currentHostContext` on
    appear before draining pending prompts, so app grounding survives the same
    pre-mount timing window as prompt delivery.
  - The existing AgentClone side panel shows an `Epistemos context` summary when
    host context is present.
  - The same summary is injected into AgentClone's normal task prefix for main
    and tab tasks, so model-visible context and tool cwd stay aligned.
- `projectFolder` is the strongest existing seam. It already feeds provider
  prompts, shell cwd, file tools, Xcode/project checks, MCP gating, project
  indexing, subagents, script tabs, and native tool handlers.

## Do Not Do During Isolation

- Do not restore `ChatView`, `ChatSidebarView`, `MiniChatView`, `NoteChatState`,
  graph chat request types, or deleted Osaurus/native-agent files from this
  lane.
- Do not patch app-wide graph/note/mini internals just to make an Act guard
  greener while another agent owns deletion/refactor work there.
- Do not rename deep clone contracts to Epistemos. Surface branding is allowed;
  runtime identifiers, storage keys, imports, protocol strings, env vars, and
  donor API names stay stable unless there is a migration and proof.
- Do not minimize by deleting controls. The clone's side panel, services,
  tools, MCP, project folder, tabs, history, messages, accessibility, and
  advanced controls must remain reachable behind flat Epistemos chrome.

## Research Inputs Read In This Pass

- `docs/handoffs/ACT_AGENTCLONE_MASTER_GOAL_PROMPT_2026_06_25.md`
- `docs/handoffs/CLAUDE_IMPLEMENTATION_PROMPT_FULL_CLONE_INFUSION_2026_06_24.md`
- `docs/handoffs/CHAT_DELETION_INVENTORY_AND_NEW_ROUTE_PLAN_2026_06_24.md`
- `docs/research/PRIVATE_TRI_SURFACE_UNIFICATION_CONTROL_PLANE_2026_06_24.md`
- `docs/handoffs/WORK_POST_ISOLATION_DEEPENING_PLAN_2026_06_25.md`
- `LocalPackages/AgentClone/Sources/AgentClone/EpistemosAgentBridge.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/Core/AgentViewModel.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/AgentViewModel/TaskExecution/Setup.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/Services/SystemPromptService.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/Services/SessionStore.swift`
- `LocalPackages/AgentClone/Sources/AgentClone/Views/Input/ProjectFolderSectionView.swift`
- `Epistemos/App/RootView.swift`
- `Epistemos/State/AgentChatState.swift`
- `Epistemos/State/AgentStreamingSupport.swift`
- `Epistemos/State/ThreadState.swift`
- `Epistemos/Models/DocumentSurface.swift`
- `Epistemos/Sync/VaultSyncService.swift`
- `Epistemos/Work/WorkAppContextSnapshot.swift`
- `Epistemos/Work/WorkToolMCPCore.swift`
- Existing references to deleted or isolated surfaces in
  `CHAT_DELETION_INVENTORY_AND_NEW_ROUTE_PLAN_2026_06_24.md`.

## Local Source Findings To Carry Forward

- `WorkAppContextSnapshot` is the clearest current pattern for a bounded app
  context object. It is `Codable`, `Equatable`, and `Sendable`; normalizes
  blank fields; clamps counts; renders compact UI rows; and produces sorted
  JSON. Its current field set covers workspace, vault, skills count, native
  tools availability, app mode, engine/model/agent, work session id, queued
  prompts, active note title/path, graph focus summary, and selection preview.
- `AgentCloneAppContextSnapshot` is the first Act-side version of that pattern.
  It is intentionally smaller than Work's snapshot during isolation: app name,
  workspace root, vault root, app support root, mode label, and presentation.
  It now also owns a deterministic model-visible summary/JSON shape that can
  become the future Act `epistemos.context.snapshot` resource. Grow this value
  before touching clone internals or deleted graph/note/mini surfaces.
- `WorkToolMCPCore` exposes `epistemos.context.snapshot` only when an
  `appContextProvider` exists. That is the right later Act pattern: native app
  context stays app-owned, and the clone/donor sees it through a small
  resource/tool contract with honest absence output.
- `AgentChatState` currently gives the app-side Act/Landing record an
  `activeSessionId`, user messages, streaming/tool metadata, plan-document
  fields, and context-token counters. After isolation, treat this as an app
  session ledger and lineage source; do not mistake it for the clone execution
  backend.
- `AgentStreamingSupport` now owns only generic streaming helpers extracted
  from the deleted old chat state: frame-paced text flushing and reasoning-trace
  accumulation. This keeps the current Act/Landing app session record compiling
  without restoring the old chat surface or adding a second inference stack.
- `ThreadState` already has `loadedNoteIds`, `loadedNoteTitles`, and
  `contextAttachments` mutation helpers. After isolation, it can inform a
  read-only context snapshot, but the old thread/chat inference route must not
  be revived from this lane.
- `DocumentSurface` is already a serializable attachment shape with id, kind,
  title, file URL, current selection, capabilities, and content hash. This is a
  good candidate for the future Act document-context field because it is plain
  data and already expresses read/write/patch/export/preview/annotate
  capability.
- `VaultSyncService` exposes read seams such as `fetchNoteBodies(ids:)` and
  `findNotesByTitle(_:)`. Future AgentClone-backed note/vault tools should use
  these owner APIs first for read-only context, then require explicit note
  owner APIs and permission text for writes or patches.
- `SessionStore` is now the first storage seam moved into Epistemos ownership:
  active JSONL transcripts live under
  `Application Support/Epistemos/AgentClone/sessions`, while the donor
  `Documents/AgentScript/sessions` directory remains a compatibility import
  source. The same pattern should be used later for skills, memory, hooks,
  prompts, and script state only when each has a migration/import adapter and
  proof. Do not bulk-rename all `AgentScript` paths.

## Deep Research Ledger - Current Understanding

The current Act bridge is intentionally smaller than the Work bridge. Act now
has a live prompt receiver, an Epistemos host-context bridge, safe
project-folder adoption, a side-panel readout, and model-visible context in the
task prefix. Work already has the deeper pattern that Act should eventually
match after isolation: a bounded `WorkAppContextSnapshot`, a native context
panel, and a callable `epistemos.context.snapshot` MCP tool.

Do not copy Work code directly into AgentClone during the current isolation.
Use it as a design reference:

- Plain-data context snapshot, not direct imports of graph/note/chat UI types.
- Context visible to both user and model.
- Native actions exposed as tools only after the owning app service exists.
- Honest absence states when note, graph, selection, or native tools are not
  attached.
- Runtime names preserved at the deep layer, with Epistemos names at the
  foreground layer.

Current hardening-cycle result:

- Clone-contained source/package path remains the valid proof path while the
  full app target is blocked by unrelated Graph/Farm compile failures.
- The clone package now has no-model tests for the current context boundary:
  blank fields normalize out, workspace-only context summarizes honestly, and
  vault+workspace context shows both while preserving vault-first cwd rooting.
- The foreground naming policy is now guarded in two places: the app
  `ActSurfaceOsaurusUIDirectionGuardTests` source guard and the mirrored
  `EpistemosChatDonorContracts` package guard.
- The reverse naming policy is also guarded: protected deep contracts must stay
  donor-compatible where renaming would break storage, prompt migrations,
  keychain lookup, provider setup, scripts, helper processes, or shell/tool
  cwd propagation.
- The latest safe foreground scan covers AgentClone `Views`,
  `DependencyChecker`, and `AgentApp.swift` quoted literals for stale
  donor/runtime labels while preserving protected deep names such as
  `AgentClone`, provider types, MCP/runtime keys, storage keys, and env vars.
- The current route is useful but not yet deeply native: it builds an
  app-owned `AgentCloneAppContextSnapshot`, renders a deterministic
  model-visible summary/JSON payload, submits prompts, publishes
  vault/workspace/mode context, adopts safe project folders, queues bridge
  prompts through the clone's existing main/tab queues, buffers pre-mount prompt
  submissions until `ContentView` appears, applies pre-mount host context on
  appear, shows context in the side panel, injects context into the task prefix,
  and writes clone session JSONL into an Epistemos-owned app support path with
  legacy donor-session fallback. It does not yet expose note, graph,
  mini-session, document, or native app-action tools to the clone.
- Mode selection is now a live route seam, not just a stored preference:
  `WorkspaceModeSelection.select(_:)` posts `epistemos.workspace.mode.didSelect`
  with the selected raw mode, `HomeRouter` updates the mounted `workspaceMode`,
  and app-level tests verify the notification payload against a scoped defaults
  object. Future note/graph/mini entrypoints should reuse this event-style
  route handoff rather than writing defaults and expecting a remount.
- The shared app target still has deletion-lane build blockers outside this
  scope. After extracting generic `AgentChatState` streaming helpers, the
  targeted Xcode mode-selection rerun first hit a stale deleted
  `AgentRunTimelineView.swift` reference, then a fresh derived-data rerun showed
  the current generated app target file list still includes deleted old-chat
  files `Epistemos/Views/Chat/AnswerPacketBadge.swift` and
  `Epistemos/Views/Chat/ChatBrainPickerMenu.swift`. Do not repair that from
  this lane unless reassigned; the future portal work should not revive old chat
  files.

Current Act safe context fields:

- app name: `Epistemos`
- app mode: current `WorkspaceMode.defaultLabel`
- workspace root: `RootView.workWorkspaceURL`
- active vault root: `VaultSyncService.vaultURL`
- internal app support root:
  `Application Support/Epistemos/AgentClone` for clone compatibility state
  (not included in the model-visible context summary)
- adopted clone project folder: AgentClone `projectFolder`
- visible side-panel summary: `Epistemos context`, including surface, vault,
  and workspace when present
- model-visible summary: `[Epistemos context: ...]`, including surface, vault,
  and workspace when present

Future Act context fields after isolation:

- active note id, title, file path, visible excerpt, selected range
- active document surface id, kind, file URL, capability flags
- graph focus route, selected node ids, selected edge ids, neighborhood summary
- session lineage: parent session, child mini sessions, detached window state
- active app permission policy and model/tool profile
- available app-native tools, MCP health, and last native tool error
- current selection preview, redacted to a bounded length
- vault skills count and whether app-vault skills are available to the clone

## Existing Snapshot And Future Fields

`AgentCloneAppContextSnapshot` now exists as the small safe Act-side boundary.
Keep it app-owned and serializable. AgentClone should consume expanded context
through a bridge notification, a side-panel readout, a task-prefix summary, or a
future `epistemos.context.snapshot` style resource. Do not import SwiftUI
surfaces into `LocalPackages/AgentClone`.

```swift
struct AgentCloneAppContextSnapshot: Codable, Equatable, Sendable {
    var appName: String
    var workspacePath: String?
    var vaultPath: String?
    var appSupportPath: String?
    var modeLabel: String
    var modelVisibleSummary: String { get }
    var modelVisibleJSON: String { get }
    var activeActSessionID: String?
    var parentSessionID: String?
    var childSessionIDs: [String]
    var presentation: String // main, attached-mini, detached-mini, graph, note
    var selectedModelID: String?
    var selectedAgent: String?
    var permissionPolicy: String?
    var managedSkillsCount: Int
    var nativeToolsAvailable: Bool
    var activeNoteID: String?
    var activeNoteTitle: String?
    var activeNotePath: String?
    var activeDocumentSurface: DocumentSurface?
    var graphFocusSummary: String?
    var selectedGraphNodeIDs: [String]
    var selectedGraphEdgeIDs: [String]
    var currentSelectionPreview: String?
    var lastNativeToolError: String?
}
```

Normalization rules should mirror `WorkAppContextSnapshot`: trim blanks to nil,
clamp counts to zero or above, bound arrays, compact previews, and make absence
explicit in UI/resource output.

## Feature Deepening Map

| Area | Current safe state | Future AgentClone-backed shape | Required proof |
| --- | --- | --- | --- |
| Vault/workspace | `AgentCloneHostContext` adopts vault/workspace into `projectFolder` when safe. | Structured snapshot plus optional read-only context resource for vault metadata, skills, and active workspace. | No-model context propagation test, side-panel readout, task-prefix proof, manual-folder non-clobber proof. |
| Route selection | `WorkspaceModeSelection.select(_:)` persists the mode and posts a live route notification consumed by `HomeRouter`. | Future note/graph/mini entrypoints select or focus AgentClone-backed portals through typed app route events, not silent defaults writes. | Behavior test for payload/object, mounted-router source guard, and live proof after full-app blockers clear. |
| Session storage | JSONL session transcripts write under Epistemos app support with `Documents/AgentScript/sessions` kept as legacy fallback. | Epistemos recents/session ledger owns list/load/rename/delete/export while donor JSONL is only a compatibility codec/import path. | New session lands in Epistemos path, legacy session imports/loads, deletion removes active+legacy ids, recents UI reads one canonical ledger. |
| Native tools | AgentClone keeps its own MCP/tool stack; app-native tools are not imported during isolation. | App-owned native tool bridge or MCP resource surfaced to AgentClone, equivalent in spirit to Work's `epistemos.context.snapshot`. | `tools/list`/`tools/call` no-model proof, permission behavior, transcript-visible error path. |
| MiniChat | Deleted/isolated old mini-chat route must not be restored from this lane. | Compact or floating portal into an AgentClone-backed child session with inherited vault/tools/permissions. | Same child session focuses when reopened, parent lineage persists, detached window is presentation only. |
| Graph Chat | Deleted/isolated graph-chat backend must not be restored from this lane. | Graph-context portal into an AgentClone session, carrying selected nodes/edges and bounded neighborhood summaries. | Read-only graph context test first; graph mutation actions require permission cards and graph owner API proof. |
| Note Chat | Deleted/isolated note-chat backend must not be restored from this lane. | Note-context portal into an AgentClone session, with note-owned accept/discard UI for edits. | Current note context read, selected-text action test, no raw write without note owner approval. |
| Document surfaces | No direct app document-surface import inside AgentClone today. | Context attachment for active document id/kind/title/file URL and allowed actions. | Snapshot field test, visible absence state, owner live proof on one document. |
| Settings | Deleted Act settings pane stays deleted; clone controls remain inside AgentClone/settings shell. | Epistemos settings shell projects safe policy into clone settings without splitting storage contracts. | Settings source guard and no migration unless storage keys are mapped and tested. |
| Foreground naming | Visible bad donor names are scanned out of AgentClone foreground directories. | Continue classifying labels as foreground, diagnostic, or protected deep contract before every rename. | Directory-level foreground literal guard plus protected-name presence guard. |

## Future Native Action Matrix

These are research targets only until isolation lifts.

| Action | Owner API or source | Clone-facing shape | Required guard before implementation |
| --- | --- | --- | --- |
| Read active context | Future expanded `AgentCloneAppContextSnapshot` provider | `epistemos.context.snapshot` read-only tool/resource plus side-panel rows | Snapshot unit test, honest absence output, task-prefix parity check. |
| Find notes | `VaultSyncService.findNotesByTitle(_:)` | Read-only `epistemos.context.find_notes` or merged snapshot field | No-model result-shaping test and bounded result count. |
| Fetch note bodies | `VaultSyncService.fetchNoteBodies(ids:)` | Read-only `epistemos.context.current_note` / selected notes resource | Redaction/bounds test and no write path. |
| Patch note selection | Future note owner API, not raw file write | Permissioned app action with accept/discard UI | Owner API test, permission card text, transcript-visible failure. |
| Read document surface | `DocumentSurface` value from active owner | Snapshot field with id/kind/title/capabilities/hash | Codable test and stale-hash handling. |
| Patch document surface | Future document owner patch API | Permissioned app action using surface id + expected hash | Hash mismatch failure test and owner live proof. |
| Read graph focus | Graph owner after deletion/refactor lane settles | `epistemos.context.graph_neighborhood` read-only resource | Bounded neighborhood test and no mutation. |
| Mutate graph | Future graph owner API | Permissioned action such as connect/annotate | Permission card, undo/audit path, owner API test. |
| Create/focus mini session | Future unified session registry | AgentClone-backed child session with parent id | Same id focuses existing mini, detach is presentation-only. |
| Record session summary | App session owner / vault history owner | App-owned write action after run completion | Explicit destination, permission policy, failure transcript. |

## Immediate Clone-Hardening Order

1. Keep the direct bridge live.
   Landing and other app entrypoints should call `AgentCloneBridge.submitPrompt`
   in non-App Store builds, and AgentClone should run the prompt through its
   existing active-tab or main-tab execution path. The prompt-id pending buffer
   must stay in place so submissions made just before view subscription are
   drained on appear rather than dropped.

2. Keep host context clone-contained.
   RootView owns `AgentCloneAppContextSnapshot` and publishes a bounded
   `AgentCloneHostContext` with app name, workspace root, vault root, app
   support root, mode, and presentation. AgentClone can consume the folder
   fields through `projectFolder` and the presentation through its existing
   context summary. This gives the clone real app grounding without importing
   graph/note/mini UI types. `ContentView` must apply the latest
   `currentHostContext` on appear so the side-panel summary and prompt prefix
   do not depend on notification timing.

3. Preserve manual project-folder authority.
   If the user selected a custom folder in AgentClone, the app context bridge
   must not overwrite it. Adoption is safe only when the clone has no folder,
   is still on the previous host-applied folder, matches the new host folder,
   or is on the home default.

4. Keep the flat UI functional.
   The side panel should remain reachable from the left rail, while details
   stay behind panels/popovers. Visual simplification must not remove provider,
   project, history, MCP, services, tools, messages, or accessibility controls.

5. Guard foreground naming and protected naming separately.
   Tests should assert Epistemos-facing copy at the surface and assert that
   runtime-sensitive donor names still exist where they are contracts.

6. Keep documenting every clone-to-app seam before widening it.
   For each future deepening item, record the owner service, the plain-data
   payload, the clone read path, the user-visible disclosure, the permission
   behavior, and the no-model proof. Do not implement app-wide graph/note/mini
   changes until the owner lifts isolation.

## Post-Isolation Deepening Sequence

1. Define an app-context snapshot.
   Grow the existing typed snapshot that AgentClone can read without importing
   app UI: `AgentCloneAppContextSnapshot`. Keep it bounded, deterministic,
   redacted, and serializable.

2. Populate snapshot fields from stable app services.
   Candidate fields after isolation:
   - active vault root and vault display name
   - current workspace/project root
   - selected mode: chat, act, work, note, graph, mini
   - active note id/title/path and selected text range
   - active document surface id/kind/title/file URL/capabilities
   - graph focus node ids, visible neighborhood summary, and selected edge ids
   - current session id, parent session id, and child mini-session ids
   - active model/tool/permission policy chosen by Epistemos
   - available Epistemos native tools and MCP health

3. Expose context as clone-native resources.
   Prefer AgentClone-side tools/resources over app UI imports:
   - `epistemos.context.snapshot`
   - `epistemos.context.current_note`
   - `epistemos.context.document_surface`
   - `epistemos.context.graph_neighborhood`
   - `epistemos.context.session_lineage`
   - `epistemos.context.available_actions`
   These can be backed by Epistemos services later while preserving clone
   execution flow.

4. Rebuild MiniChat as an AgentClone portal.
   MiniChat should become a compact presentation of an AgentClone-backed
   session, not a separate inference backend. Required behavior:
   - attached mini session has `parentSessionID`
   - detached mini session is the same identity in a floating window
   - opening the same mini session focuses the existing surface
   - prompts run through AgentClone or a shared Act session runner
   - inherited vault/project/tools/permissions remain visible
   - recents distinguish parent sessions and child mini sessions

5. Rebuild Graph Chat as an AgentClone context portal.
   Graph Chat should not own a separate chat backend. It should create or focus
   an AgentClone-backed session with graph context attached:
   - selected node/edge ids and labels
   - visible neighborhood summary
   - graph search result provenance
   - allowed graph actions, such as search, connect, annotate, summarize
   - explicit permission behavior for graph mutations

6. Rebuild Note Chat as an AgentClone context portal.
   Note Chat should keep note-specific UX but share the clone-backed session
   and execution layer:
   - current note id/title/path
   - selected text range and visible excerpt
   - inline rewrite/summarize/extract actions routed through approved note APIs
   - accept/discard behavior remains note-owned
   - session persistence remains shared with app recents/vault history

7. Add app actions only behind stable APIs.
   After the owning surfaces settle, bridge actions through app services:
   create note, patch selected text, append citation, search vault, fetch graph
   neighborhood, connect graph nodes, create mini session, focus parent session,
   open document surface, and write session summary. Each action needs a
   permission rule, an honest error path, and a no-model test.

8. Add a context inspector panel.
   AgentClone should offer a flat side-panel section showing what Epistemos
   context is active: vault, project, note, document surface, graph focus,
   session lineage, native MCP status, skills count, and current permission
   policy. It should show absence honestly rather than imply hidden access.

9. Prove real app integration in tiers.
   First, source/parse/name guards. Second, no-model tests for context snapshot
   propagation and action dispatch. Third, owner live proof: ask the clone what
   context it has, call a note/vault tool, call a graph-context tool, create or
   focus a mini session, and verify visible transcript/errors.

## Deepening Research Backlog

- Define the Act equivalent of `WorkAppContextSnapshot` as a serializable,
  bounded, redacted value object. It should be owned by the app side and
  consumed by AgentClone through bridge notifications or a clone-native
  resource, not by importing SwiftUI surfaces.
- Map native feature owners before adding tools:
  `VaultSyncService` for vault roots and file-backed note state,
  note/document owners for selected ranges and patch acceptance, graph owners
  for selected nodes and read-only neighborhoods, and session owners for parent
  and child session identity.
- Decide how AgentClone should ask for context:
  side-panel readout, task-prefix summary, and a future
  `epistemos.context.snapshot` style tool/resource should all return the same
  bounded truth so the UI and model cannot diverge.
- Build mini/chat/graph/note portals as presentations over clone-backed
  sessions. They should focus existing sessions, preserve lineage, and inherit
  tool/permission policy instead of creating separate inference stacks.
- Add app-native actions only after the app owner service provides an explicit
  API. Each action needs permission text, an error transcript path, a no-model
  unit test, and a live proof script or checklist.
- Keep foreground appification separate from runtime compatibility. Visible
  names can say Epistemos/Act/user/tooling, but source/runtime identifiers that
  participate in imports, protocol strings, storage, provider setup, MCP,
  keychain, helper processes, or donor provenance stay donor-compatible until a
  migration exists.

## Reconceptualized Surfaces

- Main Act/Chat: full AgentClone surface, Epistemos-skinned, with project/vault
  context and all clone controls reachable.
- MiniChat: compact or floating portal into a clone-backed child session.
- Graph Chat: graph-context portal into a clone-backed session, not a graph
  private chat engine.
- Note Chat: note-context portal into a clone-backed session, with note-owned
  inline accept/discard UI.
- Landing/search: prompt entrypoints and mode selectors that submit into the
  live clone route without creating a detached backend path.
- Settings: keep clone settings isolated for now, but later project selected
  app policy into the clone through explicit read/write probes.

## Acceptance Checklist

- Asking the clone "what context do you have?" returns the active Epistemos
  vault/workspace and, after isolation, the current note/graph/document/session
  context when those surfaces are active.
- Manual AgentClone project-folder selection is not overwritten by app context.
- MiniChat, Graph Chat, and Note Chat no longer run separate inference stacks;
  they become portals into clone-backed sessions with typed context.
- App actions are mediated by Epistemos APIs with permission and error proof,
  not by ad hoc string prompts or revived deleted backends.
- Foreground text says Epistemos/Act/chat/agent/tools while protected clone
  contracts stay named and test-guarded.
- Verification includes `swift build` for AgentClone, donor-contract tests,
  app source guards, no-model context/action tests, and owner live proof before
  deleting or replacing any fallback.
