# Session Handoff Report — 2026-04-07

> **Index status**: TRANSIENT-CANDIDATE — Session handoff for code editor syntax color + cloud routing; debugging continues.
> **Superseded by / Phase**: CODE_EDITOR_DEBUG + SESSION_REPORT_2026-04-06.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



## For: Next Agent (Kimi, Claude, or other)

This report covers all outstanding issues from the April 6-7 sessions. Read this before making changes.

---

## Current State of the Codebase

### What's Working (Committed)
- Build succeeds with zero errors
- Xcode color palette (`XcodeCodeColors` struct) is in `EpistemosTheme.swift` and `nsColorForTokenType` uses it
- Tahoe visibility fixes are applied in `CodeEditorView.swift` (clipsToBounds, allowsNonContiguousLayout, layer timing, sRGB normalization, ensureLayout, typingAttributes order)
- Cloud routing: manual mode default, GPT-5.4 model resolution, OpenAI `instructions` field + `store: false`

### What's NOT Working

#### 1. Code Editor: Text May Still Be Invisible
The Tahoe fixes were applied but the user reports still not seeing text. The root cause analysis (from multiple deep-research documents) identified these remaining issues:

**Most likely remaining cause: `updateNSView` re-highlights on every SwiftUI redraw.**

Current code at line ~353:
```swift
func updateNSView(_ nsView: NSView, context: Context) {
    context.coordinator.textView?.highlightSyntax(theme: theme)
}
```

This runs `beginEditing/endEditing` on **every SwiftUI state change** — including when `cursorLine`/`cursorCol` `@State` bindings update (every keystroke/click). Each call invalidates the entire text storage layout. Fix by adding a theme-change guard:

```swift
func updateNSView(_ nsView: NSView, context: Context) {
    guard context.coordinator.lastAppliedTheme != theme else { return }
    context.coordinator.lastAppliedTheme = theme
    context.coordinator.textView?.highlightSyntax(theme: theme)
}
```

Add to Coordinator:
```swift
var lastAppliedTheme: EpistemosTheme?
```

#### 2. Code Editor: Colors May Be Wrong
The `XcodeCodeColors` struct in `EpistemosTheme.swift` uses `NSColor(srgbRed:...)` which is correct. BUT `makeNSView` at line ~192 uses force-unwrapped sRGB conversion:
```swift
let fgColor: NSColor = (theme.isDark ? NSColor.white : NSColor.black).usingColorSpace(.sRGB)!
```
This bypasses the Xcode colors entirely. The editor background/foreground should come from `theme.xcodeColors` but currently uses hardcoded white/black. To fix:
```swift
let xc = theme.xcodeColors
let fgColor = xc.editorForeground
let bgColor = xc.editorBackground
```

#### 3. Cloud Models Not Working
The user reports cloud models still don't work despite three committed fixes. Possible remaining issues:
- API keys not set or expired in Keychain
- Manual mode is on by default — user sees errors instead of fallback
- Network/firewall blocking API calls
- Need to check HTTP response codes in `LLMService.swift`

See `docs/SESSION_REPORT_2026-04-06.md` for full cloud debugging guide.

---

## Performance Upgrades (NOT YET APPLIED — Were Reverted)

These changes were implemented in the Claude session, then Kimi reverted CodeEditorView.swift to apply Tahoe visibility fixes. The performance work should be re-applied AFTER text visibility is confirmed working:

### Upgrade 1: Temporary Attributes for Syntax Highlighting
**Current (slow):** `textStorage.beginEditing()` → `addAttribute(.foregroundColor)` per token → `endEditing()`. Triggers `processEditing` → full layout invalidation → O(document) per keystroke.

**Target (fast):** `layoutManager.addTemporaryAttribute(.foregroundColor)` per token. No `beginEditing/endEditing`. No layout invalidation. 2-5x faster.

**Why it was reverted:** Temporary attributes may get cleared by layout passes before they're visible. The textStorage approach is slower but more reliable.

**How to re-apply safely:** Use a hybrid approach — apply colors to BOTH textStorage (permanent, survives layout) AND temporary attributes (for fast scroll updates). The textStorage pass runs on text change; the temporary attribute pass runs on scroll.

### Upgrade 2: CALayer Current Line Highlight
**Current:** Drawn in `drawBackground(in:)` via `.fill()` — forces CPU redraw on every cursor move.
**Target:** Private `CALayer` sublayer, frame updated via `CATransaction`. Zero CPU draw cost on cursor move.

### Upgrade 3: Dirty Rect Optimization
**Current:** `drawBackground` builds and strokes a full-document indent guide path on every draw call.
**Target:** Only enumerate/stroke guides for lines within the dirty rect via `glyphRange(forBoundingRectWithoutAdditionalLayout:)`.

### Upgrade 4: Visible-Range-Only Highlighting
**Current:** All 16,384 tokens colored on every edit.
**Target:** Cache tokens from FFI, apply colors only for visible range + 50% scroll buffer.

---

## New Feature Specs (Ready for Implementation)

### Feature: Symbol TOC Strip (Right Edge)
Full spec in `docs/FEATURE_SPEC_TOC_AND_FOLDING.md`.

**Summary:** A narrow vertical strip on the far-right showing document symbols (MARK comments, functions, classes). Click to scroll. Active section highlighted. Requires:
- New Rust FFI function `code_parse_symbols()` in `code_highlight.rs`
- New `CodeSymbol` C-repr struct in `graph_engine.h`
- New `SymbolTOCView` NSView class in `CodeEditorView.swift`
- Wire into Coordinator's `textDidChange` and `scrollDidChange`

### Feature: Code Folding (Gutter Area)
Full spec in `docs/FEATURE_SPEC_TOC_AND_FOLDING.md`.

**Summary:** Fold chevrons in the gutter next to foldable blocks. Click to collapse/expand. Requires:
- New Rust FFI function `code_parse_fold_ranges()` in `code_highlight.rs`
- New `CodeFoldRange` C-repr struct in `graph_engine.h`
- Fold state management in `CodeTextView`
- Chevron drawing in `LineNumberGutter`

---

## File Map (Current State)

### Modified Files

| File | Status | Notes |
|------|--------|-------|
| `Epistemos/Theme/EpistemosTheme.swift` | XcodeCodeColors added, nsColorForTokenType rewritten | Working correctly |
| `Epistemos/Views/Notes/CodeEditorView.swift` | Tahoe fixes applied, performance work reverted | Text visibility may still be broken |

### Key Files for Debugging

| File | What to Check |
|------|--------------|
| `Epistemos/Views/Notes/CodeEditorView.swift:155-351` | `makeNSView` — the entire setup flow |
| `Epistemos/Views/Notes/CodeEditorView.swift:353-356` | `updateNSView` — re-highlights on EVERY SwiftUI update (bug) |
| `Epistemos/Views/Notes/CodeEditorView.swift:568-640` | `highlightSyntax` — textStorage attribute application |
| `Epistemos/Theme/EpistemosTheme.swift:194-273` | `XcodeCodeColors` struct and `xcodeColors` property |
| `Epistemos/Theme/EpistemosTheme.swift:906-924` | `nsColorForTokenType` dispatch |
| `Epistemos/Engine/LLMService.swift` | Cloud API HTTP calls |
| `Epistemos/Engine/TriageService.swift:1524-1580` | Cloud routing manual/auto mode |

### Documentation Files

| File | Contents |
|------|----------|
| `docs/SESSION_REPORT_2026-04-06.md` | Full issue report for code editor + cloud models |
| `docs/CODE_EDITOR_DEBUG.md` | Debug logging code and diagnostic steps |
| `docs/FEATURE_SPEC_TOC_AND_FOLDING.md` | Symbol TOC + Code Folding implementation spec |
| `TAHOE_TEXT_VISIBILITY_FIXES.md` | macOS 26 Tahoe rendering fix documentation |
| `RESEARCH_PROMPT.md` / `RESEARCH_PROMPT_SHORT.md` | Research context for the invisible text issue |

---

## Priority Order for Next Agent

1. **Fix `updateNSView`** — add theme-change guard to stop re-highlighting on every cursor blink
2. **Verify text is visible** — if still invisible after #1, add the debug logging from `docs/CODE_EDITOR_DEBUG.md`
3. **Switch to `xcodeColors`** — replace hardcoded sRGB white/black in `makeNSView` with `theme.xcodeColors`
4. **Debug cloud models** — add HTTP response logging in `LLMService.swift`, verify API keys in Keychain
5. **Re-apply performance work** — CALayer highlight, temporary attributes, dirty rect (ONLY after visibility confirmed)
6. **Implement TOC strip** — follow spec in `docs/FEATURE_SPEC_TOC_AND_FOLDING.md`
7. **Implement code folding** — follow spec in `docs/FEATURE_SPEC_TOC_AND_FOLDING.md`
