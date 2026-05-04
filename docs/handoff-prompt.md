# Epistemos: Execution Handoff Prompt

> **Index status**: TRANSIENT-CANDIDATE — Execution handoff for Time Machine bugs + workspace snapshot + session intelligence; superseded by APP_ISSUES_AUTO_FIX.
> **Superseded by / Phase**: APP_ISSUES_AUTO_FIX + SESSION_HANDOFF_2026-04-07.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



**Paste this entire prompt into a fresh Claude Code session.**

---

## Context

You are continuing work on **Epistemos**, a macOS-native knowledge management app (Swift + Metal + Rust FFI). Read `CLAUDE.md` first for architecture. A deep audit research paper exists at `~/Downloads/Epistemos_ Deep Audit and Redesign.md` — consult it whenever you need architectural guidance on FFI, concurrency, AI orchestration, or storage patterns.

The previous session implemented Workspaces, Session Intelligence, Time Machine, Activity Tracking, and a global overlay system across ~15 commits. There are critical bugs and incomplete features that need fixing before any new work.

---

## Phase 1: Critical Bug Fixes (do these first)

### Bug 1: Time Machine shows 703 "Notes Added" (over-counting)

**Root cause:** `TimeMachineService.computeDiff(from:)` (~line 152) compares `pastState.noteSnapshots` (which only contains notes that were *open in tabs* at snapshot time) against ALL notes in SwiftData via `FetchDescriptor<SDPage>()`. If you had 5 tabs open but 703 total notes in the vault, it reports 698 as "added."

**Fix:** The diff must compare vault-level counts, not tab-level. Two options:
- **Option A (minimal):** Store a `totalNoteCount: Int` in each `WorkspaceSnapshot` / `HistoricalState`. The diff becomes `current.count - past.totalNoteCount`. Only show truly new notes created after the snapshot date by checking `SDPage.createdAt > snapshotDate`.
- **Option B (accurate):** Store `Set<String>` of ALL page IDs (not just open tabs) in the snapshot. Diff against that set.

Go with Option A — it's minimal and correct.

### Bug 2: Time Machine shows 0 words for all "Notes Open at That Time"

**Root cause:** `TimeMachineService.reconstructState(at:)` (~line 86) fetches `SDPageVersion` records filtered by `createdAt <= targetDate`. If no `SDPageVersion` exists for that date, `body` falls back to `""`, giving 0 words.

**Fix:** When `SDPageVersion` fetch returns nil, fall back to the current `SDPage.body` (loaded via `page.loadBody()`). The word count won't be historically accurate but it's better than 0. Also: check that `WorkspaceService.captureSnapshot()` stores word counts from the actual note body at capture time in `NoteTabSnapshot`, and use those stored counts when displaying "Notes Open at That Time" instead of re-fetching versions.

### Bug 3: Session Intelligence can't create notes or navigate

**Root cause:** The `executeCommand()` function in `SessionIntelligenceOverlay.swift` uses prefix-matching (`text.hasPrefix("open note")`) to parse AI output. The AI generates natural language like "I'll create a note called X" instead of the exact command prefix.

**Fix per research paper (Section 5.15):** The ideal fix is Qwen tool-calling JSON schemas. But for now, the minimal fix is:
1. In the system prompt sent to the AI, add explicit instructions: "When you want to perform an action, output EXACTLY one of these commands on its own line: `[CREATE_NOTE: title]`, `[OPEN_NOTE: title]`, `[NAVIGATE_GRAPH: nodeId]`"
2. Parse AI output for these bracketed commands using a simple regex `\[(\w+):\s*(.+?)\]`
3. Execute the command AND show the AI's natural language response
4. **Critical SwiftData fix:** When creating a note, do `try modelContext.save()` BEFORE calling `NoteWindowManager.shared.open(pageId:)`. Add a small `try await Task.sleep(for: .milliseconds(100))` yield to let the main context merge. See research paper Section 8.2.

### Bug 4: ESC key doesn't close overlays

Check all overlay views (`SessionIntelligenceOverlay`, `WorkspaceSwitcherOverlay`, `TimeMachineOverlay`, `SaveWorkspaceOverlay`). Each must have:
```swift
.onKeyPress(.escape) {
    dismiss()
    return .handled
}
```
If `.onKeyPress` isn't firing, the overlay's focusable state might be wrong. Ensure the root VStack/ZStack has `.focusable()` and `.focused()` bound to a `@FocusState` that's set to `true` on appear.

### Bug 5: Light mode — overlays are dark

The overlay backgrounds use hardcoded dark colors (e.g., `Color.black.opacity(0.85)`). Fix by using semantic colors:
```swift
// Instead of:
Color.black.opacity(0.85)
// Use:
.ultraThinMaterial  // or .regularMaterial
```
Apply `.environment(\.colorScheme, colorScheme)` to ensure the material adapts. Check all four overlay files.

---

## Phase 2: Workspace Save UX Improvements

### Save Workspace dialog needs to be a chat-like experience

Current: just a name text field + "what I was working on" field.
Required: A conversational save flow:
1. Show current workspace name (if updating existing) with option to "Save as new" or "Update current"
2. Text field for session summary / notes
3. Auto-generated AI summary (use Apple Intelligence) shown as a suggestion the user can edit
4. Clear distinction: "Update [Current Workspace Name]" button vs "Save as New Workspace" button
5. On quit: same flow but with "Quit without saving" option

### The ⌃⌘S command on landing opens workspace switcher instead of save

Find the keyboard shortcut handler in `LandingView` or `RootView`. The `controlShiftS` binding is mapped to the wrong action. It should trigger `showSaveWorkspace = true`, not `showWorkspaces = true`.

---

## Phase 3: Session Intelligence Deep Integration

### Note creation must actually work
Per Bug 3 fix above, but also:
- After creating the note, the AI should insert its generated content into the note body
- Use `NoteFileStorage.writeBody(pageId:body:)` ONLY if the note is NOT open in a window
- If the note IS open, post content via `NSTextStorage.replaceCharacters` through the Coordinator pattern (see research paper Section 7.23)

### Model routing
- Summaries (Session Focus banner): Apple Intelligence
- Chat responses: Qwen 2B by default (user can change via model picker)
- The model picker already exists in the overlay — verify it actually switches the pipeline

### Export session to note
- The "export to note" command should create a new SDPage with the full session chat history formatted as markdown
- Include the Session Focus summary at the top, then each Q&A pair

---

## Phase 4: Quit Dialog as Global Overlay

The quit save dialog must appear above ALL windows (including note windows). Current implementation uses `GlobalOverlayController` with `NSPanel`. Verify:
- Panel level is `.modalPanel` (not arbitrary arithmetic like `.floating + 1`)
- Panel has `hidesOnDeactivate = false`
- Panel uses `.ultraThinMaterial` background (not transparent black)
- Panel has proper rounded corners (use `panel.styleMask.insert(.fullSizeContentView)` + `panel.titlebarAppearsTransparent = true` + corner radius on the hosting view)
- Text fields in the panel accept keyboard input (panel must override `canBecomeKey = true`)

---

## Phase 5: Workspace Auto-Save + Diff Section

### Auto-save
Workspaces should auto-save every 5 minutes (configurable). In `WorkspaceService`, add a timer:
```swift
private var autoSaveTimer: Timer?
func startAutoSave(interval: TimeInterval = 300) {
    autoSaveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
        Task { @MainActor in self?.autoSave() }
    }
}
```

### Workspace diff view
When selecting a workspace in the switcher, show a "Changes since last save" section:
- Notes added/removed since last save
- Word count deltas per note
- Chats started/messages sent
- Graph nodes added

Use `EventStore` to query events between `workspace.lastSavedAt` and now.

---

## Phase 6: Chat Session Summaries

Add ability to summarize all chats from a session/day:
1. Query `EventStore` for all `chat_message` events in the time range
2. Group by chat ID
3. Feed to AI with depth control:
   - **Brief**: One sentence per chat
   - **Detailed**: Key topics + decisions per chat
   - **Full**: Complete reconstruction with quotes
4. This should be accessible via Session Intelligence command: "summarize my chats today"

---

## Phase 7: Welcome-Back Summary on Launch

Per research paper Section 6.20, the welcome-back overlay should:
- NOT auto-dismiss (persist until user interacts)
- Show progressive disclosure: 2-sentence summary → hover for details → button to save as note
- Pull summary from the last saved workspace + events since last quit

Verify the current `WelcomeBackOverlay` in `LandingView` actually appears on launch and contains meaningful content (not empty or stale).

---

## Files to Read First

Before making any changes, read these files in order:

1. `CLAUDE.md` — architecture bible
2. `Epistemos/State/TimeMachineService.swift` — Bug 1 & 2
3. `Epistemos/Views/Landing/SessionIntelligenceOverlay.swift` — Bug 3 & Phase 3
4. `Epistemos/State/WorkspaceService.swift` — Phase 2 & 5
5. `Epistemos/State/EventStore.swift` — telemetry queries
6. `Epistemos/State/WorkspaceSummaryService.swift` — AI summary pipeline
7. `Epistemos/Views/Landing/QuitSavePanelController.swift` — Phase 4
8. `Epistemos/App/ChatCoordinator.swift` — workspace awareness injection
9. `Epistemos/Views/Landing/LandingView.swift` — keyboard shortcuts, greeting hints
10. `Epistemos/App/EpistemosApp.swift` — quit lifecycle

Also read the research paper: `~/Downloads/Epistemos_ Deep Audit and Redesign.md`

---

## Verification Checklist

After implementing, manually verify:

- [ ] Launch app → Welcome-back summary appears with real content (not empty)
- [ ] Time Machine → select a past session → "Notes Added" shows realistic count (not 703)
- [ ] Time Machine → "Notes Open" shows actual word counts (not all 0)
- [ ] Session Intelligence → type "create a note called Test Note" → note actually creates AND opens
- [ ] Session Intelligence → type "open note [existing name]" → note window opens
- [ ] ESC key closes each overlay: Workspaces, Save Workspace, Session Intelligence, Time Machine
- [ ] Switch to Light Mode → all overlays readable (not dark-on-dark)
- [ ] ⌃⌘S → opens Save Workspace (not workspace switcher)
- [ ] Save Workspace → can type in text fields, clear save/update distinction
- [ ] Quit app (⌘Q) → quit dialog appears even from note windows
- [ ] Quit dialog → can type workspace name and summary
- [ ] Auto-save fires after 5 min (check with shorter interval for testing)
- [ ] Workspace switcher → selecting a workspace shows diff/changes section
- [ ] Session Intelligence → "summarize my chats today" → produces chat summary
- [ ] Build succeeds: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' build`
- [ ] Tests pass: `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination 'platform=macOS' test`
- [ ] Rust tests pass: `cd graph-engine && cargo test`
