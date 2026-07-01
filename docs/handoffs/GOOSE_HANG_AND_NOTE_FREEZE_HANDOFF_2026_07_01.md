# Handoff: Goose transition hang + Note open/create freeze (UNSOLVED)

**Date:** 2026-07-01
**Branch:** `feat/goose-surface`  **HEAD at handoff:** `ff50b91db`
**Status:** TWO bugs still reproduce for the owner after ~10 fix attempts. **Do NOT trust the previous
agent's root-cause reasoning — it guessed from code 4+ times and was wrong each time.** Start by
CAPTURING A LIVE SAMPLE of the actual freeze (see §2). That is the single most important instruction here.

---

## 1. The two bugs (owner-confirmed, still reproducing on the latest build)

### BUG A — Goose surface takes ~5 seconds to transition in (perceived hang)
- Press Goose (landing button or ⌘3) → the embedded Goose page takes ~3–5s to appear. Owner: "still not instant."
- **Ruled OUT by testing (these did NOT fix it):**
  - Cold subprocess spawn — the prewarm DOES start a `goose serve` runtime at launch (verified live:
    `goose serve --host 127.0.0.1 --port 3284 --with-builtin developer`). Runtime is WARM before the user navigates.
  - Double runtime — collapsed to one (window controllers deleted).
  - `proc.run()` blocking @MainActor — moved off-main (commit 740b6cd0f).
  - The `git worktree list` affordance — the surface's DirSwitcher chip calls `listGitWorktreeDirs`; it was
    moved off-main (58dddfb0b) then **fully DISABLED** (ff50b91db, returns `[]` instantly). **Owner tested with it
    disabled and Goose STILL does not transition instantly.** → the git subprocess is NOT the cause.
- **Therefore the cause is still UNKNOWN.** It is something that runs when the embedded Goose surface becomes
  ACTIVE/visible on transition, not the spawn/connect. See §4 for the remaining suspects.

### BUG B — Opening ANY note, or creating a NEW note, freezes (and a bad fix made it blank)
- Owner: "creating a new note still hangs and crashes" and "opening a random note also has the same issue."
- "Crashes" = almost certainly a hang → beachball → force-quit (NO signal crash `.ips` was produced; the only
  Epistemos `.ips` is an old Jun-25 launch failure re: missing `Sparkle.framework` rpath — unrelated).
- **A previous fix attempt made notes open BLANK** ("0 words", content missing — owner screenshot). That was the
  empty-seed approach and it has been **REVERTED** (commit 3e33eb271). Notes now display content again but STILL freeze.
- Leading hypothesis (UNCONFIRMED by sample): `NoteFileStorage.readBody` (a `pendingBodyQueue.sync` +
  `Data(contentsOf:)`) is called synchronously on @MainActor during SwiftUI init/layout of the note editor.
  For a NEW note, creating it stages a write that holds the serial queue, so the immediate open's read blocks.

---

## 2. ⭐ DO THIS FIRST: capture the freeze with a live sample/spindump (the thing the last agent failed to do)

The previous agent kept reasoning about the code and guessing. **Stop. Get the actual blocked main-thread stack.**

**Option A — spindump (best; auto-captures hangs):**
```
# start a wide spindump right before reproducing, or let the OS auto-generate on the beachball
spindump Epistemos 10 -reportFile /tmp/epi_spin.txt   # then reproduce the freeze within 10s
# OR after a beachball, check for an auto hang report:
ls -t ~/Library/Logs/DiagnosticReports/*.{hang,spin,ips} 2>/dev/null | head
```

**Option B — sample, timed with reproduction:**
```
PID=$(pgrep -x Epistemos | head -1)
# Ask the owner to open a note / press Goose the INSTANT this starts, and HOLD during the beachball:
sample "$PID" 8 -mayDie -f /tmp/epi_sample.txt
# then read the MAIN THREAD stack (the "com.apple.main-thread" / "Main Thread" block):
grep -A60 -i "main-thread\|Main Thread" /tmp/epi_sample.txt | head -70
```

The main-thread stack captured DURING the freeze names the exact blocking call. Everything below is hypothesis;
that sample is fact. NOTE: the last agent's 45s sample caught the app IDLE (owner reproduced outside the window) —
so it only showed normal background waits (`GooseRuntimeSupervisor.waitForReady`→`read` on the goose pipe;
`agent_core` condvars; WebKit IPC `semaphore_wait`). Those are NOT the freeze. Time the capture to the reproduction.

**Launching the app for testing:** the owner's build is DerivedData
`Epistemos-ctkiyqxaarezsccbouumxcpfxvtl` (maps to `/Users/jojo/Downloads/Epistemos/Epistemos.xcodeproj`; the OTHER
DerivedData `Epistemos-gbjcdpcqg...` is a stale `/tmp/...` verify build — ignore it).
`open "<...>/Debug/Epistemos.app"`. Kill stale instances first (`pkill -x Epistemos; pkill -f "GooseRuntime/goose serve"`)
or `open` may re-activate an old instance. The app process has been observed EXITING shortly after launch several
times (owner-closed or a crash — investigate if it recurs; check for fresh `.ips`).

---

## 3. Everything tried this session (commits on `feat/goose-surface`)

| Commit | What | Bug | Outcome |
|---|---|---|---|
| `01d5a84ec` | Goose as pre-warmed kept-alive home page | A | prewarm mounts, but flag was latched once |
| `e5e3b6565` | prose-crash clamp, code-editor blank fix, Goose prewarm @State, DOM regex | — | fine |
| `b303972da` | Goose SINGLE runtime (⌘3 → embedded; delete window controllers) | A | good, not the hang |
| `740b6cd0f` | spawn `goosed` OFF @MainActor (GooseSpawnBox) + ALWAYS prewarm at launch | A | prewarm now real; did NOT fix transition |
| `c4515d186`/`217e6ae9c` | restore MarkEdit Source lens for note-backed notes | (C, a 3rd bug — see §6) | code-complete, unverified in-app |
| `ee99e67ae` | clamp `scrollToCharacterOffset` NSRange (open/heading-nav crash) | — | legit, keep |
| `58dddfb0b` | note-open off-main body hydrate + git-worktree off-main | A,B | **note part BLANKED notes → reverted**; git part superseded |
| `3e33eb271` | REVERT the note-freeze blank regression | B | notes display again (freeze remains) |
| `ff50b91db` | DISABLE `listGitWorktreeDirs` (return `[]`) | A | owner: Goose STILL slow → git worktree not the cause |

**Net for the two live bugs: still broken.** Keep the Source-lens (§6) and `scrollToCharacterOffset` fixes; they're
unrelated and correct. The Goose single-runtime + off-main-spawn + prewarm commits are architecturally good — keep them.

---

## 4. BUG A (Goose) — remaining suspects to check via the sample

Since git-worktree is ruled out, on transition-to-active the block is likely one of:
1. **WebView first paint / layer commit on reveal.** The idle sample showed the main thread in
   `WebKit RemoteLayerTreeDrawingAreaProxy::commitLayerTree`. The prewarmed `WKWebView` sits hidden
   (`opacity 0`, `zIndex -3`, `allowsHitTesting false` — `LandingView.swift` ~191-210). WebKit may occlusion-throttle
   a fully-hidden/zero-opacity web view and do a big synchronous relayout/first-paint when it's revealed. **Test:**
   try revealing it with a tiny non-zero on-screen frame (offscreen) instead of `opacity 0`, or re-parent one
   persistent `NSHostingView`. Confirm via sample whether the 5s is in WebKit on reveal.
2. **A synchronous context snapshot on activate.** `GooseAppContextSnapshot` / an `epistemos.context.snapshot`
   affordance may build a large vault snapshot on @MainActor when the surface becomes active. Grep the WebUI boot
   for affordances fired on load/activate (the bundle's `DirSwitcher.tsx`, boot shim). Check `GooseWebNativeAffordanceBridge`
   and `GooseAppContextSnapshot`.
3. **ACP handshake / health gate on reveal.** `GooseRuntimeSupervisor.waitForReady` + `GooseACPEventBridge` — verify
   the surface doesn't synchronously wait on a health/connect step when shown.
4. **Other blocking affordances** still on the synchronous `handleAffordance` path (readGitDiff/readGitStatus/
   readGitSingleLine/readGitHubCompareURL each `semaphore.wait(.now()+N)` on @MainActor — see
   `GooseWebNativeAffordanceBridge.swift`). Only `listGitWorktreeDirs` was addressed. If the WebUI fires any of these
   on activate, they block too. The clean fix is to route ALL Process()-spawning affordances off @MainActor (mirror the
   `getAllowedExtensions` async carve-out at ~line 171), OR disable them like `listGitWorktreeDirs`.

Files: `Epistemos/Goose/GooseWebNativeAffordanceBridge.swift`, `Epistemos/Goose/GooseWebSurfaceView.swift`,
`Epistemos/Goose/GooseRuntimeSupervisor.swift`, `Epistemos/Views/Landing/LandingView.swift` (~191-210 persistent layer).

---

## 5. BUG B (Note freeze) — the correct fix (do NOT repeat the blank mistake)

**Landmine:** `ProseEditorRepresentable2` (TextKit2) does NOT reactively re-render the `NSTextView` from an external
`@State bodyText` change after mount. So seeding `bodyText = ""` and updating it async = permanently BLANK editor.
That is exactly what the reverted `58dddfb0b` did. **Never seed the editor empty.**

**Correct approach — load-before-mount:** in `ProseEditorView` (`Epistemos/Views/Notes/ProseEditorView.swift`), do
the body read OFF the main thread and mount `ProseEditorRepresentable2` only AFTER the body is loaded (show a light
placeholder/spinner meanwhile). The editor then mounts WITH real content (displays correctly) and the read never
blocks @MainActor. Handle `page.id` changes (re-load on switch). Confirm the blocking read first via sample.

**Where the blocking read is:**
- `ProseEditorView.init` → `initialBodySnapshot` → `currentBody(for:)` → `NoteWindowManager.currentBody` →
  `NoteFileStorage.readBody(fast:true)` (`Epistemos/Sync/NoteFileStorage.swift` ~1045: `pendingBody()` does
  `pendingBodyQueue.sync`; then `Data(contentsOf:)`).
- `NoteDetailWorkspaceView.init` (`Epistemos/Views/Notes/NoteDetailWorkspaceView.swift`) ALSO reads the same body
  via `NoteWindowManager.currentBody` (feeds preview/metrics — safe to make async independently).
- The note body is DISK-canonical (`NoteFileStorage`); `page.body` (SwiftData) is "" for migrated notes — do NOT
  seed from `page.body`.

**Also confirm** whether the "freeze" is truly the body read or something else on the note-open path (TextKit2 layout,
a Rust `markdown_parse_structure` call, SwiftData fetch). The sample settles it.

---

## 6. A third fix that IS in but UNVERIFIED in-app: MarkEdit Source lens for note-backed notes

Owner earlier reported the Source (MarkEdit) lens toggle was missing on notes. Root cause: `availableNoteModes`
gated `.source` on a resolved on-disk `.md` `filePath`, and `SDPage.vaultRelativeNotePath` is DERIVED from `filePath`,
so plain notes (no filePath) could never get the toggle. Fix (commits c4515d186 + 217e6ae9c,
`NoteDetailWorkspaceView.swift`): a DISPLAY-ONLY note-backed `SourceEditorRoute(isNoteBacked:true)` mounted from the
note body; `saveMarkdownSourceContent`'s `noteBacked` branch never binds `page.filePath` to the synthesized path and
never writes a file directly — it persists the body via the note pipeline and calls `vaultSync.savePage` so
`VaultIndexActor.exportPage` assigns the real dedup'd path. **Needs in-app verification:** open a plain note → the
Source segment should appear; type in Source, switch away/back → content must round-trip and no spurious vault file
should be created. If it misbehaves, this is separable and can be reverted without touching A/B.

---

## 7. What to KEEP vs re-examine
- KEEP: single-runtime (`b303972db`), off-main spawn + always-prewarm (`740b6cd0f`), `scrollToCharacterOffset` clamp
  (`ee99e67ae`), Source-lens (§6). These are correct/architecturally good.
- RE-EXAMINE for BUG A: the WebView-reveal path (§4.1) and remaining synchronous affordances (§4.4). git-worktree is
  already disabled (`ff50b91db`); re-enable by restoring the invocation in `listGitWorktreeDirs`/`listGitWorktreeDirsOffMain`
  if you find it's not the problem and want the feature back.
- REDO for BUG B: load-before-mount (§5). The empty-seed approach is a known dead end (blanks notes).

## 8. Build / verify
- Build: `xcodebuild -scheme Epistemos -destination 'platform=macOS' -configuration Debug build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"`
  (ignore ~4 esbuild sourcemap "errors" — benign; ignore isolated SourceKit "cannot find type" cross-file noise).
- Module uses `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` — anything moved off-main needs `nonisolated` +
  `@unchecked Sendable` transfer boxes (see `GooseSpawnBox`, `GooseAffordanceResultBox`, `GooseAffordanceDataBox`).
- The tree is edited by concurrent agents (a "June UI" workstream). Stage ONLY the files you touch; never `git add -A`.

## 9. One-line summary for the next agent
Two main-thread hangs remain (Goose-on-transition ~5s; note-open/create). Every code-reasoned root cause so far was
wrong. **Capture a spindump/sample DURING the freeze (§2) to get the real blocking frame, then fix that** — for the
note, use load-before-mount (never seed the editor empty; it blanks — §5); for Goose, the git subprocess is already
ruled out, so check the WebView-reveal path and remaining synchronous affordances (§4).
