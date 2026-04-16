# Phase 7 Codex Audit Handoff

Date: 2026-04-15
Audience: Codex (or a fresh continuation agent) auditing Claude's Phase 7 work
Status: ready for independent review
Authority: `docs/architecture/PLAN_V2.md` §18, §19, §20, §22 + the
`docs/architecture/PHASE_6_5_CLAUDE_STARTUP_HANDOFF_2026_04_15.md` scope

## 0. Top-Level Instruction For Codex

You are auditing the Phase 7 graph workspace, settings simplification,
and BoltFFI audit work landed on `main` between commit `beba8ee8` and
commit `ae4c22d0` (inclusive). Claude implemented everything; your job
is to independently verify it and flag any drift from `PLAN_V2.md` or
the Phase 7 handoff.

**Ground rules:**

- Do NOT edit `PLAN_V2.md`. If you believe the plan is wrong, stop and
  ask the operator.
- Do NOT claim Phase 6 / 6.5 / 7 formal closure. Manual runtime
  verification remains intentionally deferred by the operator. Your
  audit deliverable is a findings report, not a closure statement.
- Do NOT "fix" findings by editing code unless a defect is blatant
  (crash, dead code that shouldn't exist, test reporting success
  while actually skipping). For anything subtler, report and let the
  operator decide.
- If you find a real regression, write up the finding and stop before
  reverting anything.

## 1. Required Reading Order

Read these before reviewing a single diff, in this order:

1. `AGENTS.md`
2. `docs/architecture/PLAN_V2.md` — especially §18, §19, §20, §22
3. `docs/architecture/CODEX_CONTEXT_PACK.md`
4. `docs/architecture/PHASE_6_5_CLAUDE_STARTUP_HANDOFF_2026_04_15.md`
5. `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md` (the Step 8 deliverable)
6. **This file.**

If you haven't read those, your audit lacks anchor points.

## 2. What Was Shipped (9 Commits)

In chronological order on `main`:

| # | SHA | Title | Scope |
|---|-----|-------|-------|
| 1 | `beba8ee8` | Phase 6.5: Commit capture slice (QuickCapture, audio, trace inspector) | Disentangled from Phase 7 worktree; 10 files, +832 lines |
| 2 | `7af6a9f8` | Phase 7: Commit Graph Workspace routing foundation (Step 2 partial) | As-staged before Claude touched it; 6 files, +238 lines |
| 3 | `6c3906e2` | WIP: Agent Command Center landing hero | Unrelated ACC UX; preserved as own commit; 2 files, +280 lines |
| 4 | `20788ab6` | Phase 7 Step 2a: Finder-style route history + hit-test fix + tests | Real work starts here; 6 files, +381 lines |
| 5 | `e796cb9f` | Phase 7 Step 4: Graph note page with real TextKit 2 editor | 5 files, +113 lines |
| 6 | `9bc76f50` | Phase 7 Step 5: Graph folder page (list view) + openNode sourceId fix | 5 files, +321 lines |
| 7 | `c1900a7d` | Phase 7 Step 6: Graph Chat bridge — typed intent event | 5 files, +216 lines |
| 8 | `9d1ef82b` | Phase 7 Step 7: Simplify settings sidebar into 6 calm categories | 3 files, +218 lines |
| 9 | `ae4c22d0` | Phase 7 Step 8: BoltFFI hot-path migration audit (inventory only) | 1 docs file, +241 lines |

Step 3 was Claude's arch fix for the Step 2 staging — the handoff called
it out as "Step 2a" because Claude never produced a "Step 3" commit.
Steps 5–8 are all post-checkpoint work from the `"continue with the
rest"` turn.

## 3. Critical Gotchas You Need To Know About

These are subtle things that bit Claude during implementation. If the
operator re-runs the work or you reproduce it, you'll hit them.

### 3.1 Swift 6 data-race cascade poisons adjacent test macros

While writing Step 6, Claude added a NotificationCenter observer in
`EpistemosTests/GraphWorkspaceGraphChatBridgeTests.swift` that captured
a `var captured: GraphChatRequest?` from a `@Sendable` closure reading
`note.userInfo`. That produced:

```
GraphWorkspaceGraphChatBridgeTests.swift:69:51:
error: sending 'note' risks causing data races
note: task-isolated 'note' is captured by a main actor-isolated closure
```

**Critically, Swift Testing's `@Suite`/`@Test` macro expansion in the
same compilation batch cascaded ~50 `@const`/`@section` errors into
`KTOAlignmentTests.swift` and `HarnessSubsystemTests.swift`.** These
other files were NOT broken — the compile-batch poisoning made it
*look* like they were.

**If you ever see a flood of `'@const' value should be initialized
with a compile-time value` and `global variable must be a compile-time
constant to use @section attribute` errors in test files you haven't
touched, the real problem is almost certainly a data race in the file
you just edited.** Fix the data race first; the cascade errors
disappear.

Claude's fix in the final version of
`EpistemosTests/GraphWorkspaceGraphChatBridgeTests.swift`: drop the
observer subscription entirely. `GraphState.askGraphChat(nodeId:)` is
`@discardableResult` and returns the same `GraphChatRequest` it posts,
so tests assert on the return value. Verifying NotificationCenter's
delivery contract is NotificationCenter's job, not ours.

### 3.2 HologramOverlay observer needs `MainActor.assumeIsolated`

The Step 2a `graphRouteDidChange` observer in
`Epistemos/Views/Graph/HologramOverlay.swift:1458-1473` looks like a
regular `.main`-queue NotificationCenter callback but actually needs:

```swift
} { [weak self] _ in
    MainActor.assumeIsolated {
        guard let self else { return }
        self.routeHostView?.isHidden = self.graphState.currentRoute.isCanvas
    }
}
```

Without the `MainActor.assumeIsolated { ... }` wrapper, Swift 6 strict
concurrency flags 25 warnings about touching MainActor-isolated state
from a `@Sendable` closure. Delivery is on `.main` so the cast is
safe. If you refactor this observer, preserve the wrapper.

### 3.3 `GraphState.openNode` folder branch regression

Before Step 5, `openNode` was passing the graph node UUID to
`openFolder` instead of `node.sourceId`. Since `GraphBuilder` sets
`sourceId: folder.id` on every folder node, the graph folder page's
`@Query<SDFolder> { $0.id == folderId }` would silently never match.
Fixed in Step 5, now covered by five tests in
`GraphWorkspaceRouteOpenNodeDispatchTests`. If you change the dispatch
logic, make those tests still pass.

## 4. Files To Audit

Grouped by commit. Grep / read each before signing off.

### Step 2a (`20788ab6`) — routing foundation

- `Epistemos/Graph/Workspace/GraphWorkspaceRoute.swift` — enum +
  `isCanvas` helper + `Notification.Name.graphRouteDidChange`
- `Epistemos/Graph/GraphState.swift:392-490` — `routeHistory`,
  `routeCursor`, `currentRoute`, `canGoBack`, `canGoForward`,
  `openNode`, `openNote`, `openFolder`, `returnToCanvas`, `goBack`,
  `goForward`, private `pushRoute`, and `askGraphChat` (Step 6
  extension). The whole block lives in one place.
- `Epistemos/Views/Graph/HologramOverlay.swift:194` —
  `routeObserver: Any?` property
- `Epistemos/Views/Graph/HologramOverlay.swift:1437-1475` — route host
  view setup + observer registration (with the `assumeIsolated`
  wrapper from §3.2)
- `Epistemos/Views/Graph/HologramOverlay.swift:~1348` — observer
  teardown (grep for `routeObserver = nil`)
- `Epistemos/Views/Graph/GraphWorkspaceContainer.swift` — Back/Forward/
  Graph nav strip + switch over `graphState.currentRoute`
- `Epistemos/Views/Graph/MetalGraphView.swift:~1456` — `mouseDown`
  double-click → `graphState?.openNode(uuid)`
- `Epistemos/Views/Graph/MetalGraphView.swift:~1493` — right-click
  context menu with Go/Reveal/Ask (Ask rewritten in Step 6)
- `EpistemosTests/GraphWorkspaceRouteTests.swift` — 16 tests across 5
  suites (InitialState, Push/Pop, Back/Forward, OpenNodeDispatch,
  ChangeNotification). **Note: the ChangeNotification suite still
  uses `var receivedObject: AnyObject?` inside a closure and passes
  clean. That's because it touches `note.object` (main-thread-safe
  `Any?`), not `note.userInfo` (untyped dictionary that Swift 6
  considers task-isolated). Don't "fix" it to match §3.1 — it's
  correct.**

### Step 4 (`e796cb9f`) — graph note page

- `Epistemos/Views/Graph/GraphNotePage.swift` — whole file. Verify it
  uses `@Query<SDPage>`, `@State NoteChatState(pageId: sourceId)` in
  `init`, and `ProseEditorView(page:).environment(noteChatState)`.
- `Epistemos/Views/Graph/GraphWorkspaceContainer.swift` — `.note(let
  id)` case embeds `GraphNotePage(sourceId: id).id(id)`. The `.id(id)`
  identity modifier is load-bearing: it forces SwiftUI to re-init
  `GraphNotePage` on route change so each note gets a fresh
  `NoteChatState`. If you remove it, stale chat state leaks across
  notes.
- `Epistemos/Views/Graph/HologramOverlay.swift:~1463` — the
  `MainActor.assumeIsolated` wrapper from §3.2 lives here.

### Step 5 (`9bc76f50`) — graph folder page + openNode bug fix

- `Epistemos/Graph/GraphState.swift:398-420` — the fixed `openNode`
  dispatch. `resolvedId = node.sourceId?.isEmpty == false ?
  node.sourceId! : id`. If you refactor, don't lose the empty-string
  fallback.
- `Epistemos/Views/Graph/GraphFolderPage.swift` — whole file. Verify:
  - `@Query<SDFolder> { $0.id == folderId }`
  - subfolder click calls `graphState.openFolder(child.id)` (pushes
    new folder route onto back stack)
  - note click calls `graphState.openNote(page.id)`
  - archived pages filtered via `!$0.isArchived`
  - no lazy-load / eager-load bug (pages listed by title only)
  - no parallel folder store
- `Epistemos/Views/Graph/GraphWorkspaceContainer.swift` — `.folder`
  case embeds `GraphFolderPage(folderId: id).id(id)`

### Step 6 (`c1900a7d`) — graph chat bridge

- `Epistemos/Graph/Workspace/GraphChatRequest.swift` — whole file.
  `Sendable` struct + `Notification.Name.graphChatRequested` +
  `fromNotification(_:)` decoder.
- `Epistemos/Graph/GraphState.swift:~460` — `askGraphChat(nodeId:)`.
  Verify it builds the request, posts the notification, and returns
  the dispatched value. `@discardableResult`.
- `Epistemos/Views/Graph/MetalGraphView.swift:~1536` —
  `contextMenuAskGraphChat` now calls `graphState?.askGraphChat(nodeId:
  id)` instead of logging a no-op line.
- `EpistemosTests/GraphWorkspaceGraphChatBridgeTests.swift` — 5 tests.
  Read §3.1 before touching this file.

**Known deferral:** no receiver is wired for `.graphChatRequested`
yet. Searching for `addObserver.*graphChatRequested` in Swift code
should return zero results in the non-test tree. That's intentional.
The Agent Command Center or a future `GraphChatState` will subscribe
in a later slice.

### Step 7 (`9d1ef82b`) — settings simplification

- `Epistemos/Views/Settings/SettingsView.swift` — only this one view
  file changed. Verify:
  - New nested enum `SettingsCategory` with 6 cases:
    `capture`, `models`, `graph`, `automation`, `privacyStore`,
    `advanced`. Ordered via `orderedCases`.
  - `SettingsSection` is unchanged except for two new computed
    properties: `category` (non-optional, total switch) and
    `rowDescription` (one-line caption).
  - The sidebar `List` now iterates `orderedCases`, wraps each group
    in a `Section(category.rawValue)`, and filters
    `visibleSections` by `category`.
  - `SettingsSidebarRow` helper renders `icon` + name + caption.
  - **Every existing detail view is still reachable.** The
    `settingsDetail` switch was not modified. Every case still
    dispatches to the original `*DetailView` / `*SettingsView`.
- `EpistemosTests/SettingsCategoryTests.swift` — 6 tests:
  - 6 categories in expected order
  - every section has a category (total switch)
  - spec-matching category map
  - no empty category
  - every row description non-empty, ≤120 chars
  - 12 sections still in `visibleSections`

If you find a section that lost its detail view or a category that
gained/lost a section without a corresponding test update, that's a
drift finding.

### Step 8 (`ae4c22d0`) — BoltFFI audit doc

- `docs/architecture/BOLTFFI_AUDIT_2026_04_15.md` — whole file.
  Verify:
  - Every `graph_engine.h` section divider (28 sections) has a
    classification row.
  - The 5 `boltffi_priority` sections are: Graph Data Loading,
    Queries, Search, Markdown Parser, SDF Label Rendering.
  - First migration candidate: Graph Data Loading + Queries + Search
    (matches PLAN_V2 §22.4 explicit priority).
  - Exit criteria in §9 match `PLAN_V2.md` §22.7.
  - No code is touched. If your `git show ae4c22d0 --stat` shows any
    `.swift` or `.rs` or `.h` file, something went wrong.

## 5. Verification Commands

Run these in order. Report any unexpected output.

```bash
cd /Users/jojo/Downloads/Epistemos

# 1. Clean worktree check (should only show build_log.txt untracked).
git status --short

# 2. Commit range.
git log --oneline beba8ee8^..ae4c22d0

# 3. Regenerate pbxproj from project.yml and confirm it's stable.
/opt/homebrew/bin/xcodegen generate
git diff --stat Epistemos.xcodeproj/project.pbxproj

# 4. Build the app target.
./scripts/xcodebuild_epistemos.sh \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -destination 'platform=macOS' \
  build CODE_SIGNING_ALLOWED=NO

# 5. Run all nine Phase 7 test suites together.
./scripts/xcodebuild_epistemos.sh \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -destination 'platform=macOS' \
  test \
  -only-testing:EpistemosTests/GraphWorkspaceRouteInitialStateTests \
  -only-testing:EpistemosTests/GraphWorkspaceRoutePushTests \
  -only-testing:EpistemosTests/GraphWorkspaceRouteBackForwardTests \
  -only-testing:EpistemosTests/GraphWorkspaceRouteOpenNodeDispatchTests \
  -only-testing:EpistemosTests/GraphWorkspaceRouteNotificationTests \
  -only-testing:EpistemosTests/GraphWorkspaceNotePageCompositionTests \
  -only-testing:EpistemosTests/GraphWorkspaceFolderPageCompositionTests \
  -only-testing:EpistemosTests/GraphWorkspaceGraphChatBridgeTests \
  -only-testing:EpistemosTests/SettingsCategoryTests \
  CODE_SIGNING_ALLOWED=NO

# 6. Expected: "Test run with 36 tests in 9 suites passed".
#    If you see @const / @section errors, re-read §3.1 of this handoff.

# 7. Spot-check the Step 5 regression guard (openNode sourceId).
#    Run just that suite in isolation to confirm it's not cached.
./scripts/xcodebuild_epistemos.sh \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -destination 'platform=macOS' \
  test \
  -only-testing:EpistemosTests/GraphWorkspaceRouteOpenNodeDispatchTests \
  CODE_SIGNING_ALLOWED=NO

# 8. Confirm ThemePairTests still pass (they were unaffected by Phase 7
#    but sanity check the wider test bundle health).
./scripts/xcodebuild_epistemos.sh \
  -project Epistemos.xcodeproj \
  -scheme Epistemos \
  -destination 'platform=macOS' \
  test \
  -only-testing:EpistemosTests/ThemePairTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected results:

| Command | Expected |
|---|---|
| 1 | `?? build_log.txt` (only) |
| 2 | 9 commits from `beba8ee8` → `ae4c22d0` |
| 3 | `0 insertions, 0 deletions` after regen (pbxproj stable) |
| 4 | `** BUILD SUCCEEDED **` |
| 5 | `Test run with 36 tests in 9 suites passed` |
| 6 | `** TEST SUCCEEDED **` |
| 7 | 5 tests pass |
| 8 | ThemePairTests pass |

**If step 3 shows any diff after xcodegen regen**, flag it — it means
Claude's xcodegen regen during the session drifted from what
`project.yml` specifies.

## 6. Known Deferrals (NOT Drift)

These are deliberate — do not flag them as regressions:

- **Graph Chat receiver** — `.graphChatRequested` is dispatched but no
  non-test code subscribes yet. See Step 6 §4 above.
- **Folder page thumbnail grid** — Step 5 is list-only by operator
  scope choice.
- **Folder page dedicated TOC pane** — implicit in the list today.
- **Graph/home selection sync** (matrix row 13) — not started.
- **NoteChatState sharing across graph page and home tab** — each
  graph note page gets its own `NoteChatState`. Sharing is a tracked
  later slice.
- **BoltFFI benchmark harness + first migration** — Step 8 is
  inventory-only. No benchmark harness, no typed buffer layout, no
  migration.
- **Manual runtime verification** — operator intentionally deferred.
  Phase 6 / 6.5 / 7 are NOT formally closed.
- **Settings row "Recommended" badges + progressive disclosure** —
  Step 7 is category + caption only.

## 7. What To Flag

Report a finding if you observe any of the following:

1. A Phase 7 test fails or silently skips.
2. `xcodegen generate` produces a non-zero pbxproj diff (means
   `project.yml` is out of sync).
3. A file in `Epistemos/Views/Graph/` references a placeholder view
   that was supposed to be replaced (`Graph Note Page Placeholder` or
   `Graph Folder Page Placeholder`).
4. `openNode` ever calls `openFolder(id)` or `openNote(id)` without
   resolving `node.sourceId`.
5. `GraphWorkspaceContainer` switches over `currentRoute` without an
   `.id(id)` modifier on `GraphNotePage` / `GraphFolderPage`.
6. The `HologramOverlay` route observer lacks the
   `MainActor.assumeIsolated { ... }` wrapper.
7. `askGraphChat` is ever called with a raw graph node id that doesn't
   exist in `store.nodes` without a guard (crash risk).
8. A `SettingsSection` case has no `category` mapping, empty
   `rowDescription`, or an absent detail-view dispatch in
   `settingsDetail`.
9. `PLAN_V2.md` diff (there should be none).
10. Any `.swift`/`.rs`/`.h` file in the `ae4c22d0` commit (Step 8 is
    docs-only).
11. Any new `print(...)`, `try!`, or `!`-force-unwrap in the Phase 7
    code (violates AGENTS.md).
12. Claims in a commit message that aren't backed by test evidence.

## 8. Final Deliverables From Codex

Your audit response should include:

- Docs read (confirm §1 list)
- Each verification command's exact exit code + last-line summary
- A findings list (may be empty — that's a fine outcome)
- Explicit statement that `PLAN_V2.md` was not edited
- Explicit statement that no code was edited unless a §7 flag was hit,
  and if so, which one and what was done
- Direct verdict: `Phase 7 steps 2a / 4 / 5 / 6 / 7 / 8 audit PASS`
  or `Phase 7 audit FAIL: <list of findings>`
- Explicit statement that manual runtime verification remains deferred
  and formal Phase 6 / 6.5 / 7 closure is not claimed by this audit

Do not write "Phase 7 complete." Phase 7 is not complete — several
deliverables are explicitly deferred (see §6).

## 9. Copy-Paste Startup Prompt For Codex

```text
Read /Users/jojo/Downloads/Epistemos/AGENTS.md first, then read the
Phase 7 audit bundle in this order:

1. docs/architecture/PLAN_V2.md
2. docs/architecture/CODEX_CONTEXT_PACK.md
3. docs/architecture/PHASE_6_5_CLAUDE_STARTUP_HANDOFF_2026_04_15.md
4. docs/architecture/BOLTFFI_AUDIT_2026_04_15.md
5. docs/architecture/PHASE_7_CODEX_AUDIT_HANDOFF_2026_04_15.md (THIS FILE)

Audit Claude's Phase 7 work from commits beba8ee8 through ae4c22d0
against PLAN_V2.md and the Phase 7 handoff. Run every verification
command in §5 of the audit handoff. Report findings per §7 and §8.

Do not edit PLAN_V2.md. Do not claim Phase 6 / 6.5 / 7 closure. Do not
fix findings unless they match one of the §7 flags and even then report
before reverting.

If you hit a flood of @const / @section errors in KTOAlignmentTests or
HarnessSubsystemTests, stop and re-read §3.1 — those are almost
certainly cascade errors from a data race in a test file Claude
touched, not real errors in those test files.

Final deliverable: docs read list, verification command results,
findings list, explicit no-plan-edits / no-closure statements, and a
direct verdict: `Phase 7 audit PASS` or `Phase 7 audit FAIL: <list>`.
```
