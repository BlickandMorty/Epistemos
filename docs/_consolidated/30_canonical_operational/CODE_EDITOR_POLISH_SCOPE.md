# Code Editor Polish Scope — 2026-04-23

> **Index status**: CANONICAL-OPERATIONAL — Phase S editor polish scope: 4 items ~2 days (line gutter/debouncing/outline cache/viewport-scoped highlighting) + 4 Pro-deferred items.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



**Source:** live-code audit of `Epistemos/Views/Notes/CodeEditorView.swift` + `EpistemosTheme.swift` + PLAN_V2 §22-25.
**User's ask:** *"truly polish the code editor with performance and add lines again but a line counter that does not interfere with my theme … I know there are so many things that can be done to upgrade performance and look of it."*

---

## TL;DR — 2 days of engineering closes the "alpha" gap

4 items land in Phase S (App Store polish) for a total of ~2 engineering days:

| Order | Item | Effort | Risk | User impact |
|---|---|---|---|---|
| 1 | Theme-aware **line gutter** | 6 hrs | Low | High — editors without line numbers feel unfinished |
| 2 | Binding\<String\> **debouncing** | 2 hrs | Low | Medium — eliminates keystroke frame hitches |
| 3 | Outline **cache + diff** | 4 hrs | Low | Medium — snappier symbol navigator |
| 4 | **Viewport-scoped highlighting** | 1 day | Medium | High — large files (>50KB) stop stuttering |

Items 5–8 are Pro features or deferred Rust work (minimap, semantic sidebar, incremental parsing via syntax-core crate). Not needed for App Store release.

---

## Ground truth — what's in `CodeEditorView.swift` RIGHT NOW

### What renders

- ✅ **Syntax highlighting** — via CodeEditSourceEditor 0.15.2 (MIT), using `flatLight()` / `flatDark()` theme functions.
- ✅ **Go-to-line** — state present at line 1272 (`goToLineNumber`).
- ✅ **Search bar** — toggleable via `showSearchBar` state (line 1273).
- ✅ **Outline navigator** — Xcode-style breadcrumb at line 1278-1279, populated by `OutlineParser.parse()`.
- ✅ **Indentation guides** — "VS Code-style" per comment at line 304.

### What does NOT render (despite docs claiming)

- ❌ **Line numbers** — absent despite gutter colors defined in theme.
- ❌ **Minimap** — explicitly removed (line 1262 comment: "Minimap removed — outline navigator replaces it").
- ❌ **Semantic sidebar** — disabled by policy flag at line 302: `CodeEditorReleasePolicy.semanticSidebarEnabled = false`.

### Why it feels "alpha"

1. **No line numbers** — the single biggest "looks unfinished" signal.
2. **Full-file syntax highlighting on every keystroke** — no viewport scoping.
3. **`Binding<String>` copies full text on every change** (O(n), explicitly documented at line 445 as acceptable only for <100KB files).
4. **Feature flags disable features** that exist in code but are turned off → visible as commented-out code paths.
5. **No incremental parsing** — tree-sitter reparses the whole file on every keystroke.
6. **CodeEditSourceEditor is a dependency, not a foundation** — can't easily add gutter/Metal overlays without forking. Historical note: custom NSTextStorage delegate path was reverted because `CodeEditSourceEditor`'s internal `MultiStorageDelegate` overwrites custom delegates (line 442).

---

## The good news — gutter is ready to ship

**Theme system already has everything needed:**

`EpistemosTheme.swift` lines 214-217, 239-242, 265-268 define:
- `gutterBackground` (dark: `#1F1F23`, light: `#F5F5F5`)
- `gutterForeground` (dark: `0.875 @ 0.33 opacity`, light: `#A6A6A6`)
- `gutterForegroundActive` (dark: `0.875 @ 1.0 opacity`, light: `#282828`) ← for current line
- `gutterSeparator` — subtle divider

`EpistemosTheme.ResolvedTheme` carries these as `ResolvedColorToken`. **The theme-aware line-counter the user wants is a rendering job, not a theme-system job.** Zero "theme interference" risk if implementation respects these tokens.

### Recommended gutter implementation

1. **Container:** `NSView` overlay beside the CodeEditSourceEditor scroll view (fixed-width left sidebar, ~40pt).
2. **Rendering:** `CATextLayer` per visible line number (not per-line-of-file — viewport only, reused).
3. **Theme integration:**
   ```swift
   let gutterColors = theme.resolvedTheme.gutterColors(isDark: theme.isDark)
   lineLayer.foregroundColor = gutterColors.foreground.cgColor       // inactive
   lineLayer.backgroundColor = gutterColors.background.cgColor
   // For the active line: gutterColors.foregroundActive.cgColor
   ```
4. **Scroll sync:** subscribe to `NSView.boundsDidChangeNotification` on the editor's scroll view; update visible line range.
5. **Active-line tracking:** read `NSTextView.selectedRange` via CodeEditSourceEditor's delegate, map to line index, highlight that row in `gutterForegroundActive`.
6. **Performance:** cache layers in a pool of size ≈ (viewport height / line height) + margin. Never allocate per-keystroke.

### Why this is low-risk

- Gutter colors already theme-resolved → no hardcoded grays, no light/dark mismatch.
- Overlay does NOT touch CodeEditSourceEditor internals → avoids the `MultiStorageDelegate` footgun.
- Performance bounded by viewport size, not document size.
- Tested in all 12 themes (6 light + 6 dark) during Phase S.1 polish.

---

## Performance bottleneck matrix

| # | Bottleneck | Where | Effort | Risk | User impact | Category |
|---|---|---|---|---|---|---|
| 1 | `Binding<String>` full-text sync on every keystroke | CodeEditorView L445 | 2 hrs | Low | Medium | **Phase S** (App Store polish) |
| 2 | Full-file syntax highlighting on every keystroke | CodeEditSourceEditor | 1 day | Medium | High | **Phase S** (App Store polish) |
| 3 | Outline refresh rescans whole file on every debounce window | OutlineParser.parse() | 4 hrs | Low | Medium | **Phase S** (App Store polish) |
| 4 | Line gutter absent | (new) | 6 hrs | Low | High | **Phase S** (App Store polish) |
| 5 | Semantic sidebar disabled by policy | CodeEditorView L302 | 1 day | Medium | Low | **Pro-only** |
| 6 | Minimap implementation | (removed per §23.2) | 1 day | Low | Low | **Pro-only** (Metal overlay path) |
| 7 | No incremental parsing / shadow rope | Rust syntax-core (not built) | 3 days | High | Highest for >500KB files | **Deferred** to Phase K+ |
| 8 | Semantic sidebar with vault grounding | CodeEditorView L302 | 1 day | Medium | Pro differentiator | **Pro-only, Phase K+** |

---

## Recommended fix order (execute in this sequence)

### 1. Theme-aware line gutter — 6 hours — ship first

**Why first:** gutter colors are already defined in the theme system, there's zero upstream dependency, and the user experience impact is outsized.

**Files touched:**
- NEW: `Epistemos/Views/Notes/CodeEditorGutterView.swift` — NSView subclass with CATextLayer pool.
- MODIFIED: `CodeEditorView.swift` — add left accessory using the gutter view.

**Verification:**
- Visual: all 12 themes render correctly, no color clashes.
- Active line highlights and follows caret movement.
- Scroll sync: line numbers stay aligned with rendered text.
- Large file (10K lines): no layer explosion; layer pool caps at viewport size.

### 2. Binding\<String\> debouncing — 2 hours

**Why second:** immediate responsiveness win; proven pattern already used in ProseEditor.

**Pattern:**
```swift
// Based on ProseEditor Coordinator2 (L1350-1359)
private var debounceTask: Task<Void, Never>?
func onContentChangeDebounced(_ text: String) {
    debounceTask?.cancel()
    debounceTask = Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        self.onContentChange?(text)  // only fires after quiet window
    }
}
```

**Files touched:** `CodeEditorView.swift` coordinator only.

**Verification:**
- Fast typing (10 cps) produces 1 binding update every 300ms, not 10.
- SwiftUI re-evaluation no longer fires per-keystroke.
- AI streaming (via `isFlushingTokens`) still flushes immediately — debounce is bypassed during programmatic writes.

### 3. Outline cache + diff — 4 hours

**Why third:** outline navigator gets smoother; complements gutter.

**Pattern:**
```swift
// In OutlineParser, cache previous parse result
private var lastParsedHash: Int = 0
private var lastOutline: [OutlineNode] = []
func parse(_ text: String) -> [OutlineNode] {
    let hash = text.hashValue
    if hash == lastParsedHash { return lastOutline }  // unchanged
    let newOutline = doParse(text)
    lastOutline = diffAndMerge(old: lastOutline, new: newOutline)
    lastParsedHash = hash
    return lastOutline
}
```

**Files touched:** `OutlineParser.swift` (or equivalent; tree-sitter-backed symbol extractor).

**Verification:**
- Unchanged file: second parse is O(1).
- Adding one symbol: diff only updates that node, not all nodes.
- Outline navigator view doesn't reflow unnecessarily.

### 4. Viewport-scoped syntax highlighting — 1 day

**Why fourth:** biggest performance win for large files.

**Approach A (recommended):** fork CodeEditSourceEditor's tokenizer, add viewport bounds parameter.
- Pro: full control.
- Con: maintenance burden, upstream drift.

**Approach B (defer):** wait for upstream CodeEditSourceEditor PR or contribute one.
- Pro: no fork.
- Con: out of our control; may never land.

**Approach C (parallel tokenizer):** use our own tree-sitter wrapper, ignore CodeEditSourceEditor's internal highlighting, apply our own NSAttributedString ranges on top.
- Pro: no fork needed; works around the MultiStorageDelegate issue.
- Con: double-tokenization cost (minor).

**Recommendation:** **Approach C** for App Store (parallel tokenizer with viewport scoping via tree-sitter `QueryCursor.set_byte_range()` — already available in `swift-tree-sitter` or via Rust FFI). This avoids the fork and the upstream wait.

**Files touched:**
- NEW: `Epistemos/Views/Notes/ViewportTokenizer.swift`.
- MODIFIED: `CodeEditorView.swift` — subscribe to scroll-range changes, request viewport tokenization.

**Verification:**
- 50K-line Swift file: first paint <500ms, scroll at 60fps / 120fps (ProMotion).
- Keystroke-to-highlight latency <16ms at 20KB files.

### 5. Pro feature — inspector panel (4 hours)

**When:** after App Store ships. Part of Pro build's editor polish.

**What:** floating panel showing current scope / function / class, all symbols at the current indentation level, click-to-jump.

**Dependencies:** reuses outline parser from item 3.

### 6. Pro feature — minimap via Metal overlay (1 day)

**When:** after App Store ships. Per PLAN_V2 §23.7, minimap is Metal-overlay territory, not SwiftUI.

**Approach:** separate `MTKView` sibling of the editor, renders scaled-down glyphs (2-3pt) with theme colors. Click to jump.

**Dependencies:** Metal pipeline; gutter rendering (item 1) should be ported to use the same Metal approach if feasible.

### 7. Deferred — incremental parsing via Rust `syntax-core` crate (3 days)

**When:** Phase K+, after App Store ships AND after Rust BoltFFI migration benchmarks justify the crate.

**Per PLAN_V2 §23.3-23.4:** ropey + tree-sitter shadow rope, viewport-scoped token requests, numeric token kind IDs, generation-counter stale-parse cancellation. This is "big-win for >500KB files" work.

**Dependencies:** the Rust `syntax-core` crate must exist; it does NOT today. Not blocking anything for App Store.

### 8. Deferred — semantic sidebar with vault grounding (1 day)

**When:** Pro build. Re-enable the `semanticSidebarEnabled` flag, wire to vault search, ship.

---

## Phase S / Pro split — what each build gets

**App Store build (Phase S includes items 1-4):**
- ✅ Theme-aware line gutter
- ✅ Binding\<String\> debouncing
- ✅ Outline cache + diff
- ✅ Viewport-scoped syntax highlighting
- ✅ Existing: syntax highlighting, outline navigator, go-to-line, search, indent guides
- ❌ No minimap (removed by policy)
- ❌ No semantic sidebar (policy-gated to Pro)
- ❌ No Rust-backed incremental parsing (deferred to Phase K+)

**Pro build adds (items 5-8):**
- ✅ Inspector panel (scope + symbols + click-to-jump)
- ✅ Minimap via Metal overlay
- ✅ Semantic sidebar with vault grounding
- ✅ Rust `syntax-core` crate integration (when built) → sub-16ms keystroke-to-highlight at any file size

---

## What NOT to do

- ❌ **Don't** re-enable `semanticSidebarEnabled` for App Store. It's disabled by policy because it wasn't production-ready. Wait for Pro.
- ❌ **Don't** try to override `CodeEditSourceEditor`'s `MultiStorageDelegate`. That path was reverted in prior work (line 442 comment is historical evidence). Use overlays or parallel tokenization instead.
- ❌ **Don't** build the Rust `syntax-core` crate as part of this scope. It's Phase K+ and requires BoltFFI migration benchmarks first.
- ❌ **Don't** add hardcoded gutter colors. Always pull from `theme.resolvedTheme.gutterColors()`.

---

## What the user specifically asked for — directly addressed

> *"truly polish the code editor with performance"*

→ Items 2, 3, 4 in the fix order above — debouncing, outline cache, viewport scoping. All Phase S work.

> *"add lines again but a line counter that does not interfere with my theme it did this last time"*

→ Item 1 — theme-aware line gutter rendered via overlay, consuming theme-resolved colors. Zero theme interference because the implementation:
- Uses `theme.resolvedTheme.gutterColors()` for all colors (no hardcoded grays).
- Sits as an overlay/accessory view, NOT inside CodeEditSourceEditor's text rendering (which was where the previous attempt collided with `MultiStorageDelegate`).
- Respects dark/light mode auto-switching via the existing resolved-cache mechanism.

> *"of course plus the pro version"*

→ Items 5, 6, 7, 8 — inspector panel, minimap, incremental parsing, semantic sidebar. All deferred to Pro / Phase K+.

---

## Executable session prompt for this scope (for Claude Code / Codex)

Paste this to execute Phase S code-editor polish:

```
Implement code editor polish for Phase S per docs/CODE_EDITOR_POLISH_SCOPE.md.

ORDER (one commit per item):

1. Theme-aware line gutter (~6 hrs)
   - Create Epistemos/Views/Notes/CodeEditorGutterView.swift
   - NSView overlay, ~40pt wide, left of CodeEditSourceEditor scroll view
   - CATextLayer pool, viewport-sized (not file-sized)
   - Pull colors from theme.resolvedTheme.gutterColors()
   - Highlight active line in gutterForegroundActive
   - Sync with NSView.boundsDidChangeNotification on scroll view
   - Test all 12 themes (6 light + 6 dark)
   - Commit.

2. Binding<String> debouncing (~2 hrs)
   - Port ProseEditor Coordinator2's debouncedBindingSync() pattern to
     CodeEditorView coordinator
   - 300ms quiet-window
   - Bypass during isFlushingTokens (AI streaming)
   - Commit.

3. Outline cache + diff (~4 hrs)
   - Modify OutlineParser.parse() to cache by text hashValue
   - On hit: O(1) return of cached outline
   - On miss: parse, diff-merge against previous, update cache
   - Commit.

4. Viewport-scoped syntax highlighting (~1 day)
   - Create Epistemos/Views/Notes/ViewportTokenizer.swift using
     tree-sitter via swift-tree-sitter (or Rust FFI if already linked)
   - Subscribe to scroll-range changes from CodeEditSourceEditor's
     scroll view
   - Tokenize only visible range + 50-line margin
   - Apply as NSAttributedString overlay on top of CodeEditSourceEditor's
     own highlighting (double-tokenization is fine for now)
   - Commit.

Verification at end of all four:
  - 50K-line Swift file opens in <500ms
  - Keystroke-to-highlight latency <16ms at 20KB files
  - All 12 themes render gutter correctly
  - Outline navigator feels instant on large files
  - No regressions in existing tests
  - xcodebuild clean; swift test passes

Do NOT:
  - Re-enable semanticSidebarEnabled (Pro-only)
  - Try to override CodeEditSourceEditor's MultiStorageDelegate
  - Build Rust syntax-core crate
  - Hardcode gutter colors
```
