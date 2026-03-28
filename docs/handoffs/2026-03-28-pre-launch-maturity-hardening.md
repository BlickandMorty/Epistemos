# Pre-Launch Maturity Hardening Plan
**Date:** 2026-03-28
**Purpose:** Specifically address the three systems most likely to produce user-visible failures in the first week of real-world use: vault sync, TextKit2 editor, and the graph. These are not test gaps — tests pass. These are the edge cases that only surface when real people use the app with real vaults, real keyboards, and real file systems.

---

## How to Use This Document

Work through each section in order. For every scenario: do it manually with Console.app open (`log stream --predicate 'process == "Epistemos"' --level debug`), watch for errors, crashes, or silent data corruption. Fix what you find. Do not mark a scenario done until you have run it and seen clean logs.

This is not a feature test. You are looking for data loss, hangs, and crashes.

---

## Part 1: Vault Sync

Vault sync is the highest-stakes system. A note editor that loses data once will never be trusted again. The failure modes here are not in normal use — they are in transitions: attach vault, detach vault, OS revokes permission, rename file externally, import while low on disk, migrate to new Mac.

### 1.1 Bookmark resurrection after permission reset

**What can go wrong:** macOS revokes security-scoped bookmarks when the app is sandboxed-adjacent, after OS updates, or when the user moves the vault folder. The bookmark exists in UserDefaults but `startAccessingSecurityScopedResource()` fails silently and the app behaves as if it has access when it does not.

**Test script:**
1. Attach a vault. Confirm sync works. Quit the app.
2. In Finder, move the vault folder to a different location (e.g. Desktop → Documents).
3. Relaunch the app.
4. Expected: app shows a recovery UI or vault-attachment prompt. Console shows `VaultSync` log with the failure reason.
5. Worst case: app silently operates on a ghost vault path and loses all saves.

**What to verify in code:** `VaultSyncService.shouldRestoreVaultFromBookmark` + bookmark restoration path. Check that every path where `startAccessingSecurityScopedResource()` returns false surfaces a user-facing error — not just a log.

---

### 1.2 Large vault initial import performance

**What can go wrong:** A 500-note vault import blocks the main thread or takes so long the user thinks the app is frozen. The import task exists (`importTask`) but if it does not yield progress updates frequently, the landing page loading indicator hangs for minutes with no feedback.

**Test script:**
1. Create a test vault with 300+ markdown files (use `for i in $(seq 1 300); do echo "# Note $i\n\nBody text for note $i [[Link to Note $((i-1))]]" > "$VAULT/Note $i.md"; done`).
2. Attach vault. Watch the landing page.
3. Expected: progress is visible, UI remains responsive (can scroll, click), notes appear incrementally.
4. Failure: spinner with no progress, beachball, or "App Not Responding".

**What to verify:** Import batching logic. `isIndexing` flag drives the landing page indicator. If the import loop does not call `await Task.yield()` periodically, the main actor starves.

---

### 1.3 External rename/move while watching

**What can go wrong:** User renames a note in Finder while the app is open. The app still has the old path in `VaultIndexActor`. On next save, it writes to the old path (now nonexistent) and the note is silently lost. Or worse, the file is at the new path but the app creates a second file at the old path.

**Test script:**
1. Open a note. Make an edit. Do NOT save yet.
2. In Finder, rename the `.md` file corresponding to that note.
3. Save (Cmd+S).
4. Check: does the file get written to the old name (creating a new file) or does the app detect the rename?
5. Check: is the note body preserved?

**Note:** `VaultSyncService` comment says "No live file watching — VaultFilePresenter has been removed." This means the app will not detect the rename. This is known and acceptable *if* the save path handles "file not found" gracefully and does not silently drop the write.

---

### 1.4 Disk-full mid-write

**What can go wrong:** `NoteFileStorage` uses atomic writes (temp file + rename). If the disk is full, the temp file write fails. The question is whether the failure is caught and surfaced or silently swallowed.

**Test script:**
1. On a disk image or external drive, create a vault. Fill the drive to within ~10MB.
2. Open a large note and make edits. Save.
3. Expected: error alert. No data loss (original file still intact because atomic write never completed).
4. Failure: silent failure, spinner stuck, or corrupt file.

**What to verify:** `NoteFileStorage` write path. Every `try` must have a `catch` that goes somewhere — not `try?` that discards the error.

---

### 1.5 Vault with adversarial file names

Real user vaults contain: notes with emoji in the name, notes with `/` in the title (illegal path component), notes with leading dots (hidden files on macOS), notes with the same name in different cases (`meeting.md` and `Meeting.md`), and Windows-created files with `\r\n` line endings.

**Test script — run each variant:**
```bash
# In your test vault:
touch "Note with emoji 🧠.md"
touch ".hidden note.md"
mkdir -p "Subfolder" && touch "Subfolder/nested note.md"
echo -e "# Windows Note\r\nBody with CRLF\r\n" > "windows_crlf.md"
touch "Dup.md" && touch "dup.md"  # case collision on case-insensitive HFS+
echo "# UTF-16 note" | iconv -f UTF-8 -t UTF-16 > "utf16.md"
```

Attach vault. Open each note. Save each. Verify body is preserved. Verify no crash.

**The case collision is the highest risk:** On a case-insensitive HFS+ volume, `Dup.md` and `dup.md` are the same file. `VaultHealthSnapshot.duplicateTrackedPathCount` tracks this — verify it fires an alert rather than silently deduplicating in a destructive way.

---

### 1.6 Conflict resolution does not destroy data

**What can go wrong:** User edits note in app. External editor also edits same `.md` file. User clicks "Sync from Vault." The conflict dialog shows. User clicks "Keep App Version." The on-disk version is overwritten. Fine. But if the user accidentally clicks the wrong button, or if the conflict resolution path has a bug, data from one side is destroyed with no recovery path.

**Test script:**
1. Attach vault. Open a note. Change the body in app. Do NOT save.
2. In an external editor (BBEdit, vim), change the same `.md` file differently.
3. In app: trigger "Sync from Vault."
4. Expected: conflict dialog with both versions visible. Each button does exactly what it says.
5. Verify: after resolution, run `VaultHealthSnapshot`. No duplicate tracked paths, no orphaned body files.

**Critical:** The `VaultSyncConflict` struct has `appBody` and `diskBody`. Verify the UI actually shows both bodies, not just the titles.

---

## Part 2: TextKit2 Editor

TextKit2 on macOS is newer and less battle-tested than TextKit 1. AppKit text views have decades of edge cases. The ones below are the highest-frequency failure patterns for custom `NSTextView` subclasses.

### 2.1 Paste from external rich-text sources

**What can go wrong:** User copies text from Safari, Notion, Word, or a PDF. The pasteboard contains `NSRTFDPboardType` or `NSRTFPboardType` with embedded attachments, tables, or unusual Unicode. A plain-text editor that processes only `NSStringPboardType` handles this wrong — it either crashes, inserts garbage, or pastes nothing.

**Test script — run each:**
1. Copy a paragraph from a Safari webpage (contains HTML). Paste into a note.
2. Copy a table from Numbers. Paste into a note.
3. Copy text from a PDF (often has ligatures and unusual whitespace). Paste.
4. Copy an image from Preview. Paste.
5. Copy text containing CJK characters and emoji mixed: `Hello 世界 🌍`. Paste.

Expected for all: plain text is extracted cleanly, no crashes, no invisible Unicode garbage.

**What to verify:** `ProseTextView2` overrides `readSelection(from:type:)` or `paste(_:)`. Confirm pasteboard handling prefers `NSStringPboardType` and sanitizes the result. Emoji and CJK must survive.

---

### 2.2 AI divider survival across app lifecycle events

**What can go wrong:** AI streaming starts. User force-quits the app (Cmd+Option+Esc). On relaunch, the note body contains the raw divider `---` and partial AI text — neither accepted nor discarded. The editor loads this as part of the note body. The user has no way to discard the orphaned AI zone without manually editing it.

**Test script:**
1. Open a note. Type a query. Start AI streaming.
2. While streaming, force-quit: `kill -9 $(pgrep Epistemos)` in Terminal.
3. Relaunch. Open the same note.
4. Expected: divider and partial AI text are stripped on load (the `stripUnacceptedAIResponse()` call should fire on page load, not just on page swap).
5. Failure: user sees raw `---` and partial response inline with their note text.

**What to verify:** `stripUnacceptedAIResponse()` is called not just on page swap/dismantle/sync but also during initial page load when a divider is detected in the stored body.

---

### 2.3 Rapid page switching during streaming

**What can go wrong:** AI is streaming tokens into Note A. User clicks Note B. Coordinator2 dismantles Note A's view. Token flush callbacks continue firing for Note A into Note B's storage, because the async stream is still running.

**Test script:**
1. Open a long-form note. Submit a query that will produce a long response.
2. While tokens are actively streaming, click a different note 3 times rapidly.
3. Expected: streaming stops cleanly. No tokens appear in the wrong note. No crash.
4. Check Console.app for any `NSTextStorage` mutation errors.

---

### 2.4 Undo through AI accept/discard

**What can go wrong:** User accepts an AI response (divider stripped, AI text inline). User immediately presses Cmd+Z. Expected behavior depends on undo semantics: does undo restore the pre-accept state (text before AI query), or just the last typing change?

**Test script:**
1. Type "Hello world" in a note.
2. Submit an AI query. Accept the response.
3. Press Cmd+Z multiple times.
4. Expected: undo steps back through the AI insertion, then back through "Hello world" typing. The undo stack is coherent.
5. Failure: undo crashes, undo does nothing, or undo produces a state that never existed (text jumbled).

**Also test:** Undo after Discard. Undo should restore the pre-query state.

---

### 2.5 Very large notes

TextKit2 with custom `MarkdownContentStorage` runs paragraph classification on every edit. For large notes, this can cause visible lag.

**Test script:**
1. Create a note with 50,000+ characters (paste Lorem Ipsum 50 times, or use a real large markdown file).
2. Type at the end. Watch for lag.
3. Scroll rapidly from top to bottom. Watch for layout flicker or blank paragraphs.
4. Apply a heading via the context menu. Watch for delay.
5. Acceptable: up to 100ms for paragraph reclassification. Failure: visible stutter, beachball, blank layout areas.

---

### 2.6 CJK input method (IME) composition + wikilink

**What can go wrong:** User with a Japanese/Chinese input method types a wikilink target using IME composition. During composition, the text is in a provisional "marked" state. The wikilink autocomplete fires on marked text, causing a conflict between IME candidate selection and wikilink selection.

**Test script (requires Japanese or Chinese keyboard input configured in System Settings):**
1. Enable Hiragana input. Type `[[`.
2. Type `か` using IME (producing candidates).
3. Select an IME candidate.
4. Expected: IME composition completes, then wikilink autocomplete activates on the finalized text.
5. Failure: crash, double-insertion, or wikilink dialog opens over an IME candidate window.

---

### 2.7 Multi-monitor + display scaling

TextKit2 layout is DPI-aware but custom Metal rendering (if any overlay intersects the editor) is not guaranteed to scale correctly on 1x external displays when the main screen is 2x Retina.

**Test script (requires external monitor):**
1. Open the app on your main Retina display. Open a note.
2. Drag the window to an external 1080p (1x) monitor.
3. Type. Scroll. Check that text rendering, cursor positioning, and selection highlights are correct.
4. Move back to Retina display. Verify no rendering artifacts.

---

## Part 3: Graph

Graph failures tend to be silent — wrong edges, missing nodes, stale references — rather than crashes. The Rust FFI crashes are the exception: those crash loudly.

### 3.1 Nil engine handle guard

The codebase requirement says "all FFI calls must have nil engine handle guards." Verify this is actually true.

**Test script:**
1. Launch the app with a fresh empty vault (no notes).
2. Open the graph view.
3. Expected: empty graph, no crash.
4. The engine handle may be nil if no nodes have been added yet. Verify the render loop handles this.

**Then test:** Open graph. Quit. Relaunch. Graph should restore to its previous state (or rebuild cleanly) without a use-after-free on a stale handle from the previous session.

---

### 3.2 Stale graph nodes after note deletion

**What can go wrong:** User creates Note A. Graph builds a node for Note A. User deletes Note A (from the sidebar or Finder). Graph node for Note A remains. Any wikilinks pointing to Note A are now dangling. The graph edge exists but the target node has no corresponding note.

**Test script:**
1. Create 3 notes: A, B, C. Add `[[B]]` to A's body. Save.
2. Verify graph shows A→B edge.
3. Delete note B from the app.
4. Reopen graph.
5. Expected: A→B edge is gone, or shown as a dangling reference (visually distinct). No crash.
6. Failure: crash when clicking the stale node, or the node persists indefinitely as a ghost.

---

### 3.3 Wikilinks with spaces and special characters

Obsidian-compatible vaults use wikilinks like `[[My Long Note Title]]`, `[[Notes/Subfolder/Note]]`, and `[[Note Title#Heading]]`. The wikilink parser must handle all of these.

**Test script:**
1. Create a note titled "My Long Note Title". Create another note with body `[[My Long Note Title]]`. Save both.
2. Verify graph shows the edge.
3. Repeat with `[[Notes/Subfolder/Note]]` where the note is in a subfolder.
4. Repeat with `[[Note Title#Heading Section]]` (heading anchor). Verify edge exists even if heading is ignored.
5. Repeat with `[[Note with emoji 🧠]]`.
6. Repeat with `[[note title]]` (lowercase, mismatching case of the actual note title).

**Expected:** All produce graph edges. Case-insensitive matching should work on HFS+.

---

### 3.4 Performance with 500+ nodes

**What can go wrong:** Physics simulation with 500 nodes at default settings is too expensive for the render loop. The frame rate drops below 30fps, causing visible stuttering. The `windowOccluded` gate should stop the simulation when the graph is hidden, but may not fire correctly in all cases.

**Test script:**
1. Import the 300-note test vault from Part 1.2.
2. Open the global graph view.
3. Check frame rate using Activity Monitor (GPU History) or Instruments → Metal System Trace.
4. Expected: 60fps when idle. Physics can drop during interaction but must recover.
5. Close the graph overlay. Verify CPU/GPU usage returns to baseline (physics simulation stopped).
6. Run `log stream --predicate 'process == "Epistemos"' --level debug` and look for `windowOccluded` log entries confirming the gate fires.

---

### 3.5 Two notes with identical titles

`VaultHealthSnapshot.duplicateTrackedPathCount` catches duplicate *paths* (same file path tracked twice). But two different files with the same title (e.g., `Meeting Notes.md` in root and `Meeting Notes.md` in a subfolder) produce two nodes with what might appear to be identical display names in the graph.

**Test script:**
1. Create `vault/Meeting Notes.md` and `vault/Subfolder/Meeting Notes.md` with different body content.
2. Import vault. Open global graph.
3. Expected: two distinct nodes, distinguishable (perhaps by path prefix in the label or on hover).
4. Add `[[Meeting Notes]]` to a third note. Verify the wikilink resolves to one of them (the correct one), not both or neither.

---

## Part 4: Cross-Cutting Failure Modes

These apply to all three systems and are the class of bugs that cause the worst user experience.

### 4.1 Cold start after update

**What can go wrong:** A new binary is installed but the SwiftData schema has changed. SwiftData's automatic lightweight migration silently fails on incompatible changes, opening the store in a readonly fallback mode. The user's notes appear to be gone.

**Test script:**
1. Install the current build. Create 5 notes. Quit.
2. Simulate a schema change: add a non-optional property to `SDPage` without a default.
3. Build and run the new version.
4. Expected: schema migration is handled (either automatic lightweight migration or an explicit migration plan). Notes are intact.
5. The real test: before shipping any update, explicitly verify the SwiftData store from the *previous* build opens cleanly in the new build.

---

### 4.2 Console.app monitoring protocol

For every manual test above, run this command before starting and leave it open:

```bash
log stream \
  --predicate 'process == "Epistemos"' \
  --level debug \
  2>&1 | tee ~/Desktop/epistemos-test-$(date +%Y%m%d-%H%M%S).log
```

Categories to watch in the logs:
- `VaultSync` — any `error` or `fault` level is a bug
- `NoteFileStorage` — any write failure must be surfaced to user, not swallowed
- `GraphBuilder` — any `fetch` error during build is a potential data loss
- `omega_mcp` / `graph-engine` — Rust panics print to stderr, not os_log; check Terminal output separately
- Any `NSTextStorage` exception trace — indicates an illegal mutation

After each test session, grep the log:
```bash
grep -E "(error|fault|crash|exception|assertion|EXC_BAD_ACCESS)" ~/Desktop/epistemos-test-*.log
```

Zero results is the target.

---

### 4.3 Beta release strategy (the real maturity fix)

No amount of solo testing catches what 20 users catch in 48 hours. The most effective pre-launch hardening is a structured private beta.

**Recommended approach:**
1. **10 users, 2 weeks, real vaults.** Recruit from your network. Ideally: 3 Obsidian users (large vaults, complex wikilinks), 3 Notion users (will paste rich content), 2 power users (will stress test everything), 2 casual users (will reveal onboarding failures).
2. **Crash reporting on from day 1.** Integrate MetricKit (already available on macOS, no third-party SDK needed). `MXCrashDiagnosticPayload` gives you stack traces for crashes. Wire it to log to a file in `~/Library/Application Support/Epistemos/crash_reports/` that users can attach to feedback.
3. **One Slack/Discord channel.** Every bug report goes there. You triage daily. Fix critical bugs within 24h of the report.
4. **Explicit vault size tiers:** ask beta users to report their vault size (notes count, largest note in KB). You want at least one user with 500+ notes and at least one with a note > 50KB.
5. **macOS version spread:** macOS 14 (Sonoma), macOS 15 (Sequoia), macOS 26 (Tahoe). TextKit2 behavior differs across these. SwiftData schema behavior differs.

**The one question beta answers that no test can:** "What does a user do in the first 5 minutes?" Onboarding failures — "I don't know how to attach a vault," "I attached it and nothing happened," "I closed the app and it forgot my vault" — are invisible in testing because you already know how to use the app.

---

### 4.4 Minimum viable crash recovery

Before launch, the app needs one thing that Obsidian took two years to add and Notion still doesn't have well: **you cannot lose a note body due to an app bug, period.**

The current protections are:
- Atomic writes in `NoteFileStorage`
- `stripUnacceptedAIResponse()` on page transitions
- Mutation queue serialization

What is missing for v1:
1. **A "recover from last save" action.** If the user's note body in SwiftData is corrupted or blank, the app should offer to restore from the last `.md` file written to the vault. This requires the vault file to always be one save behind — which it is, because SwiftData is the source of truth. Make this recovery path accessible from the UI (Settings → Advanced → Recover Notes from Vault).

2. **A startup integrity check.** On every launch, sample 10 random `SDPage` records and verify their body files exist and are non-empty. If `VaultHealthSnapshot.requiresRecovery` returns true, surface the recovery UI *before* the user can do anything, not as a background warning.

3. **Log the last-written path on every save.** `NoteFileStorage` already logs; ensure the log line includes the full path and byte count so that in a support conversation, you can tell a user exactly where their file was saved and how large it was.