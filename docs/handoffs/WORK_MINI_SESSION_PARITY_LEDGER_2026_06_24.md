# Work Mini-Session Parity Ledger — 2026-06-24

> Read-only recon for authority hardening item #2 ("define + prove the Work session schema") and the
> Phase-2 "Mini Session Product Model" in
> `docs/handoffs/AUTHORITATIVE_FULL_CLONE_NATIVE_INFUSION_PLAN_2026_06_24.md` (§"Mini Session Model For
> Work", lines ~95-145). Grounded in current code on `main`. Companion to
> `ENTRY_POINT_ROUTING_INVENTORY_2026_06_24.md`. NO external clones used.

## Existing building blocks (audit-first — do NOT rebuild these)
- **Engine/stream is shared**: main act + mini chat both run `SharedActInference.actEventStreamIfArmed`
  → `ActTurnStreamCore.consume` (ChatState.swift:819, MiniChatView.swift:2502/2519). Tested invariant
  (`OntologyRefactorRegressionGuardTests.actSurfacesShareStreamingCore`).
- **Parent/child lineage primitive EXISTS**: `Epistemos/Vault/AgentSessionLineageStore.swift` maps
  `chatThreadID → parentSessionID` (UserDefaults key `agentSessionLineage.chatThreadParents`) and writes
  `parent_session_id`/`chat_thread_id` into `session.json`. Also `ConversationPersistence.parentID:UUID?`
  and `SessionBrowser.swift:156-161` parent/child browsing. **BUT** it is populated only by agent-session
  COMPLETION (`recordCompletedSession`), never by mini-chat-UI creation.
- **Mini-session UI state model**: `ThreadState` (ThreadState.swift) — `ChatThread{id, type:"miniChat",
  label, messages, pageId, loadedNoteIds, loadedNoteTitles, contextAttachments, createdAt}` + per-chatID
  streaming/thinking/tool maps. Keyed flat by `id` (the mini `chatID`). **No parent field**; `pageId` links
  a mini to a NOTE page, not to a parent session.
- **Duplicate-window prevention EXISTS**: `MiniChatWindowController` keeps `windows[chatID]`; `openChat`
  (MiniChatWindowController.swift:81-92) does `if let existing = windows[chatID] { existing
  .makeKeyAndOrderFront(nil); return }`. Opening the same mini session focuses the existing window. Mini
  windows also tab together (`addTabbedWindow`, :151). Window↔chatID rebind handles focus-existing (:182).
- **Recents**: `ChatSidebarView` (0.48b) splits ACT (non-worker) vs WORK (`SDChat.isWorkerSession`)
  sections, time-grouped; Work rows reopen the Work surface (:377). Mini chats persist as `SDChat`.
- **Shared access/permissions model**: `ComposerCurrentAccessPlan` is used by main + mini + settings
  (vault/permission visibility propagates to mini via the same model).

## Parity table — authority requirement vs current state

| Authority requirement (§Mini Session Model) | Current state | Gap → next work |
|---|---|---|
| **Main Work session = tab/root** owning workspace, vault/project, branch/worktree, OpenCode/OpenWork session identity, recents, model/tool/permission state, optional hidden TUI attach | Work main = the OpenCode runtime surface (WorkOpenCodeRuntime/WorkTerminalView). Act main = ChatState/SDChat. Mini chats today are **ACT** mini-chats, not children of a Work main session. | Define a Work **main session** identity object that owns these and can parent mini sessions. |
| **Attached mini session** w/ `parentSessionID`, inherits/references parent workspace + OpenCode context, runs compact turns without replacing main transcript | `ChatThread` has NO parent field; lineage primitive unused by mini UI; mini creation (`ensureMiniChatSession(id:)`) takes no parent | (1) thread a `parentSessionID` into mini creation; (2) persist via `AgentSessionLineageStore` (extend it to record on UI creation, not just agent completion); (3) add a parent field/accessor to the mini model |
| **Detached mini session** = same attached session shown floating (detach = presentation, not identity) | `MiniChatWindowController` floats mini by `chatID`; identity preserved across float | Identity OK; but there is no **attached (in-main) presentation** to detach FROM (see next row) |
| Open a mini **inside the main UI** as a compact pane/card/rail | NOT present — mini is always a separate NSWindow | Add an in-main attached-pane presentation that shares the same `chatID`/session |
| From the mini: **detach / reattach / open-or-focus parent** | Float exists; NO reattach action; NO open-parent action | Add reattach + focus-parent (needs the parentSessionID linkage above) |
| From Epistemos MiniChat: **create/resume a Work mini attached to a main Work session** | MiniChat creates ACT mini chats, not attached to a Work main | Add Work-mini creation bound to a parent Work session |
| Main GUI tabs are main sessions; minis live under parents; no masquerading unless promoted | Mini windows tab together but have no parent; no promote action | Add parent grouping + explicit promote-to-main |
| **Recents show main + attached mini clearly, parent visible** | ACT/WORK split done; mini chats appear as ACT rows; NO parent linkage shown | Add parent linkage display to recents rows |
| **Duplicate-window prevention** (focus existing, no ghost) | **DONE** (`windows[chatID]` focus-existing) | ✓ none |
| Mini preserves MCP/vault/skills visibility, permission prompts, model/tool state, busy/stop, streaming, persistence, recovery | Shared engine (`ActTurnStreamCore`) + shared `ComposerCurrentAccessPlan`; per-chatID streaming/tool state in `ThreadState`; persists to `SDChat`; `loadChat` recovery | Mostly present for ACT mini; **WORK** mini propagation (OpenCode/vault context inheritance) is the open piece |

## Summary
Today's "mini sessions" are **ACT mini-chats**: floating windows, shared streaming engine, per-chatID
state, SDChat persistence, duplicate-window prevention. The authority's **WORK mini-session ontology**
(minis that are first-class children of a main WORK/OpenCode session, with `parentSessionID`,
attach/detach/promote, an in-main attached pane, and parent-linked recents) is **largely unbuilt** — but
the primitives to build it on EXIST: `AgentSessionLineageStore` (parent/child), `MiniChatWindowController`
(window dedup/float), shared `ActTurnStreamCore` (engine), `ComposerCurrentAccessPlan` (access model),
`SDChat` (persistence). The smallest first build step (a later, owner-greenlit slice — it's a real
feature, not hardening): **add `parentSessionID` to the mini-session model + establish it on creation via
`AgentSessionLineageStore`**, then surface parent linkage in recents. The in-main attached-pane + Work
main-session identity are the larger follow-ons. None of this is "no-vault hardening"; it is Phase-2
product work and should be scheduled explicitly with the owner (and needs runtime/visual proof).

## Implementation log — parentSessionID bridge

### Sub-step 1 — creation-site recon (DONE) — 2026-06-24
Mapped every mini-session creation/open site:
- `MiniChatWindowController.openNewChat` (MiniChatWindowController.swift:51) → `openChat(UUID().uuidString,
  …)` — creates a brand-new mini with a fresh UUID and an optional CONTEXT attachment (HTML workspace /
  Epdoc / graph note / note), NOT a parent session. Callers: StatusBar:101, EpistemosApp:1489/1569/1593,
  RootView:1502, HTMLWorkspaceEditorView:675, MiniChatView:136 ("+"), MiniChatWindowController:18/30/301.
- `openChat(chatID)` opens/focuses an EXISTING mini (RootView:1497, WorkspaceService:762 restore,
  MiniChatView:464 recents row, :1396 search hit).
- `ThreadState.ensure/upsertMiniChatSession` are the model writers (MiniChatView:171/185/216/255).
KEY FINDING: mini chats are spawned **globally/standalone** — most sites have NO parent main-session in
scope. So wiring a real parent requires a per-site product decision (e.g., parent a "+"-from-a-mini to its
originating mini? parent an act-toolbar mini to the active main act session?) + runtime/visual proof. That
behavioral wiring is deferred to an owner-greenlit step.

### Sub-step 2 — parentSessionID schema foundation (DONE, statically verified) — 2026-06-24
Additive, default-nil, zero behavior change:
- `Epistemos/Models/ChatTypes.swift` `ChatThread`: added optional `var parentSessionID: String?` (+ init
  param defaulted nil + assignment). Codable-safe — a missing key decodes to nil for existing persisted
  threads.
- `Epistemos/State/ThreadState.swift`: `upsertMiniChatSession` + `ensureMiniChatSession` gained
  `parentSessionID: String? = nil`, threaded into both `ChatThread` constructions. Every existing caller
  (MiniChatView:171/185/216/255) is untouched (defaulted → nil).
- `EpistemosTests/ThreadStateTests.swift`: `miniChatSessionRecordsOptionalParentSessionID` — round-trips a
  parent id and asserts the standalone default is nil.
- Static verify: `xcrun swiftc -parse` exit 0 on all three files; grep confirms the field is wired through
  model + ensure/upsert + both constructions + test. (App-target compile of the prior batch proved the
  SourceKit "cannot find type" warnings are isolated-file noise.)
- Checkpoint test build #2 (`bsvz76vz3`, BACKGROUND, 2026-06-24): `xcodebuild test` limited to
  `ThreadStateTests` + `CurrentAccessParityTests` — compile-verifies the NEW app code (ChatThread +
  ThreadState mini-session edits) AND the test target, and RUNS the two new tests
  (`miniChatSessionRecordsOptionalParentSessionID`, `noActiveVaultSurfacesHonestRow`) for pass/fail
  evidence. RESULT: **TEST SUCCEEDED** (exit 0) — 9 tests in 2 suites PASSED, incl. both new tests
  (`miniChatSessionRecordsOptionalParentSessionID` ✔, `noActiveVaultSurfacesHonestRow` ✔). The app target
  (ChatThread + ThreadState mini-session edits) AND the full test target COMPILED. Sub-step 2 is now
  **compile + unit-run VERIFIED** — full verification for a schema field with no on-screen behavior yet.

### Sub-step 3a — parent SOURCE recon (DONE) + CORRECTION → AWAITING OWNER — 2026-06-24
A deeper read of the only "open mini from main act" site CORRECTS my earlier (incomplete) decision.
`RootView.openCurrentActInMiniChat()` (RootView.swift:1495-1504):
```
if let activeChatId = chat.activeChatId {
    MiniChatWindowController.shared.openChat(activeChatId, …)   // chatID == activeChatId → MIRRORS the
                                                               // SAME act session in a mini window (not a child)
} else {
    MiniChatWindowController.shared.openNewChat(…)             // fresh standalone mini (no active session)
}
```
So NEITHER branch creates a child-of-main mini: one re-opens the SAME session id (a detached mirror), the
other is standalone. Across ALL creation sites (StatusBar:101, EpistemosApp:1489/1569/1593, RootView:1497/
1502, HTMLWorkspaceEditorView:675, MiniChatView:136 "+") there is **no action that spawns a child
sub-session under a main session**. `ChatState.activeChatId` exists, but using it as a parent at these
sites would be wrong (the mirror site shares the id; the new-mini site has no active session).

**CONCLUSION — AWAITING OWNER (mini-session feature):** the `parentSessionID` schema foundation (sub-step 2,
done + compile/unit verified via build bsvz76vz3) is correct and forward-looking, but it has NO honest
wiring site today. Establishing real attached-mini parentage requires a NEW product/UX action —
"create an attached mini session UNDER this main session" (authority §Mini Session Model: open a mini
inside the main UI as a compact pane/rail; detach to float; recents show the parent link). That is a
design decision the owner must make, and it needs visual proof. Do NOT force a fake parent source.

### Owner decision needed to continue the mini-session feature
Pick ONE next direction (each is the owner's call; the loop will not guess):
- **(A) Design the attached-mini UX**: add a "new attached mini under this session" action (e.g., a button
  in the act/work surface) that creates a mini with `parentSessionID = <this main session id>` and a
  distinct chatID; then wire `AgentSessionLineageStore` + recents linkage. Needs owner UX intent + visual proof.
- **(B) Defer mini-sessions**; point the loop at another authority item (e.g., item #1 OpenCode integration
  verification — but that is runtime-gated, owner must run the app).
- **(C) Greenlight the OpenWork full-clone** (Phase 2 donor) — needs an explicit disk OK (large monorepo).

Until the owner picks, the safe-static autonomous backlog is EXHAUSTED (no-vault hardening done+verified;
mini-session schema foundation done+verified; recon ledgers for items #2/#4 done).
