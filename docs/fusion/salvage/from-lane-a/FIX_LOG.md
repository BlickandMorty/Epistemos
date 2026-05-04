# Fix Log — Notes UI, Mini Chat, Agent Window, Cloud Attachments

## DISCOVERY REPORT

### A. Notes Toolbar / Ask Bar — 3 Nested Bars

**Root cause:** `NoteDetailWorkspaceView.swift` has a `noteToolbarSurface()` function (line 1015) that wraps content in a Capsule with `.thinMaterial` fill + TWO overlay strokes (primary border + white inner highlight). Then `toolbarChatField()` (line 1546) applies its OWN Capsule background + Capsule stroke overlay + siriGlow overlay on top. Result: outer surface capsule + inner ask capsule + glow border = 3 visible nested rounded layers.

**Fix:** Remove `noteToolbarSurface` wrapper entirely. The ask field should be the single pill element inside the native toolbar. The toolbar's own titlebar chrome is the base layer — no extra capsule needed around the ask content.

### B. Notes Toolbar Buttons — Not Matching Main Chat

**Root cause:** Notes uses custom `NoteToolbarIcon` (line 527) with hardcoded `font(.system(size: 13))` and `frame(width: 14, height: 14)` icon + `frame(width: 28, height: 28)` button area. Main chat uses `NativeToolbarButtonStyle` from `NativeButtonStyles.swift` (line 282) which has hover effects, scale, shadow, and 6pt corner radius chrome. Notes buttons are plain with no hover state.

**Fix:** Replace `toolbarIconButton` + `NoteToolbarIcon` with standard `Button` + `.buttonStyle(NativeToolbarButtonStyle())` from main chat.

### C. Auto Outline Bug

**Root cause:** `ProseEditorRepresentable2.swift` line 818-819 in `textDidChange()`:
```swift
if tv.markdownDelegate.hasActiveFolds() {
    clearAllFolds()  // Nukes ALL fold state on every keystroke
}
```
Every text change unconditionally clears all folds. This was meant as an optimization ("avoid re-enumeration when nothing is folded") but destroys user fold state on any typing.

**Fix:** Remove the `clearAllFolds()` call from `textDidChange()`. Fold state should only change via explicit user toggle or mode switch, not on text mutation.

### D. Agent Window Resize

**Root cause:** `UtilityWindowManager.swift` creates the omega panel as `NSPanel` with:
- `.resizable` in styleMask (line 263) — OK
- `minSize = NSSize(width: 560, height: 400)` (line 272) — OK but high
- `panel.center()` on creation (line 278)
- `applyOmegaChrome()` (line 155) sets `.fullSizeContentView`, `.titleVisibility = .hidden`, `.titlebarAppearsTransparent = true`, `.isMovableByWindowBackground = true`

The panel IS technically resizable but the content view uses `AgentSessionPanel` which has `.padding(18)` and `VStack(spacing: 16)` with no explicit frame constraints. The issue is likely that `NSHostingView` with SwiftUI content that uses `.ignoresSafeArea()` (the backdrop gradient) fights with the panel's safe area, and `isMovableByWindowBackground = true` may intercept drag events near edges. Also, initial `center()` + 760x700 default may push below screen on smaller displays.

**Fix:** Lower minimum size to 420x350. Ensure the content view has proper `frame(maxWidth: .infinity, maxHeight: .infinity)` and remove `.ignoresSafeArea()` from the gradient backdrop (replace with `.frame(maxWidth: .infinity, maxHeight: .infinity)` + clip). Check that the window is positioned within visible screen bounds after creation.

### E. Cloud Note/Chat Attachment Pipeline

**Root cause chain:**
1. `SDMessage.swift` lines 66-80: `decodedAttachments()` and `decodedContextAttachments()` use `try?` — silently returns [] on any decode error.
2. `SDMessage.swift` lines 122-124: `updatePresentationSnapshot()` uses `try?` for encoding — silently drops data on encode error.
3. `ChatCoordinator.swift` line 1256: `fileAttachmentSection()` only processes `.text` and `.csv` types — images/PDFs silently ignored.
4. `ChatCoordinator.swift` line 1302: `readTextAttachment()` uses `try?` for FileHandle — silently fails.
5. Note context from toolbar ask bar DOES work (NoteChatState.swift line 316-317 reads noteBody).
6. Context attachments (notes/chats) flow through `buildContextAttachments()` → `resolveAttachedContext()` which properly fetches and merges. The "correct format" error likely comes from the SDMessage JSON decode path when loading persisted messages.

**Fix:** Replace all `try?` in SDMessage with do-catch + logging. Add image/PDF support in fileAttachmentSection by reading binary data and including as base64 content blocks. Fix FileHandle usage with proper error handling.

---

### F. Note Chat Prompt Framing (found during validation)

**Root cause:** `NoteChatState.buildPrompt()` concatenated raw note content + conversation history + user query with no system prompt and no structural delimiters. The model saw a wall of unmarked text and defaulted to summarization behavior. The "fragmented list of unrelated chat logs" was the conversation history being dumped as raw text.

**Fix:** Added `noteAskSystemPrompt` instructing the model to answer questions (not summarize). Wrapped note content in `<note>` tags, history in `<conversation_history>` tags, and prefixed the query with `Question:`.

---

## IMPLEMENTATION LOG

### Phase 1 — Notes Toolbar / Ask Bar Rebuild
- [x] Removed `noteToolbarSurface()` wrapper (eliminated outer Capsule + 2 stroke overlays)
- [x] `noteToolbarAskItem` now directly returns `toolbarChatField()` — single pill, no nesting

### Phase 2 — Notes Toolbar Button Parity
- [x] Replaced `toolbarIconButton` + `NoteToolbarIcon` with standard `Button` + `Label` (same as main chat)
- [x] Removed `.buttonStyle(.plain)` so buttons inherit native macOS toolbar chrome
- [x] Updated `moreMenu` label to use standard `Label` instead of `NoteToolbarIcon`
- [x] Updated `NoteEditorLayoutTests` to match new source structure

### Phase 3 — Auto Outline Bug Fix
- [x] Removed `clearAllFolds()` call from `textDidChange()` in `ProseEditorRepresentable2.swift`
- [x] Fold state now only changes via explicit user toggle or outline mode switch

### Phase 4 — Mini Chat + Agent Window
- [x] Mini chat default size: 480x560 (was 720x760), min: 320x340 (was 420x520)
- [x] Agent window default: 680x560 (was 760x700), min: 420x320 (was 560x400)
- [x] Added screen bounds clamping to `getOrCreateWindow` — window stays within visible area
- [x] Replaced `.ignoresSafeArea()` on agent backdrop with `.frame(maxWidth/maxHeight: .infinity)`
- [x] Enhanced mini chat landing view with clearer empty state

### Phase 5 — Cloud Attachment Pipeline
- [x] Replaced all `try?` in `SDMessage.swift` decode/encode with do-catch + Logger
- [x] Replaced `try?` in `ChatCoordinator.readTextAttachment()` with do-catch + Logger
- [x] Replaced `try?` in `LLMService.swift` request body serialization (3 sites) with do-catch
- [x] Extended `fileAttachmentSection()` to handle `.pdf`, `.image`, `.other` types (was only `.text`/`.csv`)
- [x] Replaced `try?` in `MiniChatView.persistMiniChatSession()` with do-catch + Logger

### Phase 6 — Note Chat Prompt Fix + Validation
- [x] Added `noteAskSystemPrompt` to `NoteChatState` for proper model instruction framing
- [x] Structured prompt with XML tags (`<note>`, `<related_notes>`, `<conversation_history>`)
- [x] Build verified: BUILD SUCCEEDED
- [x] App relaunched with all changes active
