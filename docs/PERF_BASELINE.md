# Code Editor Performance Baseline

> **Index status**: CANONICAL-OPERATIONAL — Performance baseline (older but operational reference).
> Classified in [`docs/_INDEX.md §14`](_INDEX.md). Copy in `docs/_consolidated/30_canonical_operational/`.



## Date: 2026-04-07
## Engine: CodeEditSourceEditor v0.15.2 (CoreText + tree-sitter)

---

## Profiling Checklist

### Setup
1. `Product → Profile (⌘I)` in Xcode → build Release scheme
2. Select **Animation Hitches** template (combines Render Loop, Core Animation, Time Profiler)
3. Set recording mode to **Immediate** (not Deferred)

### Test Scenarios

| Scenario | File | Lines | Action | Duration |
|----------|------|-------|--------|----------|
| Small file typing | ~50 line file | 50 | Type 20 characters rapidly | 10s |
| Medium file typing | ~500 line file | 500 | Type 20 characters rapidly | 10s |
| Large file typing | AppBootstrap.swift | 1988 | Type 20 characters rapidly | 10s |
| Large file scrolling | AppBootstrap.swift | 1988 | Scroll top to bottom | 10s |
| Theme toggle | AppBootstrap.swift | 1988 | Toggle dark↔light | 5s |

### Metrics to Capture

- **Hitch time ratio** (ms/s): Good < 5, Noticeable 5-10, Severe > 10
- **Main thread occupancy** (%): during scroll and type
- **Frame budget usage**: out of 8.33ms (120fps) or 16.67ms (60fps)

### Symbols to Watch in Time Profiler

Filter: Main Thread only, Invert Call Tree, Hide System Libraries

| Symbol | Meaning |
|--------|---------|
| `TreeSitterClient` | Syntax parsing on main thread |
| `TreeSitterExecutor` | Async task scheduling overhead |
| `MinimapView.draw` / `MinimapLineFragmentView.draw` | Minimap CPU redraw |
| `Swift.String.==` / `NSString.isEqual` | O(n) string comparison |
| `setText` / `TextViewController.setText` | Full string replacement |
| `CATransaction.commit` | Layer commit overhead (budget: < 2ms) |
| `SourceEditor+Coordinator.textViewDidChangeText` | Binding writeback |

---

## Known Bottlenecks (Pre-Optimization)

### 1. SwiftUI Binding<String> Writeback
- **Severity:** HIGH
- **Mechanism:** CodeEditSourceEditor's internal Coordinator writes `textView.string` back to `$text: Binding<String>` on every keystroke. SwiftUI reconciles the full string.
- **Complexity:** O(n) per keystroke where n = file size
- **Fix:** Phase C — switch to `NSTextStorage` init variant

### 2. Minimap Redraw on Scroll
- **Severity:** HIGH
- **Mechanism:** MinimapView subscribes to `NSView.boundsDidChangeNotification` and redraws all visible line fragments on every scroll event.
- **Frequency:** Up to 120 redraws/second during scroll
- **Fix:** Phase F — set `layerContentsRedrawPolicy = .onSetNeedsDisplay`

### 3. Tree-Sitter Sync Threshold
- **Severity:** MEDIUM
- **Mechanism:** TreeSitterClient runs synchronously for files < 1MB. AppBootstrap.swift (76KB) is well below this threshold, so all tree-sitter work happens on the main thread.
- **Fix:** Phase D — verify and potentially reduce sync threshold

### 4. Configuration Recomputation
- **Severity:** LOW
- **Mechanism:** `editorConfiguration` and `editorTheme` are computed properties that rebuild on every SwiftUI body evaluation. However, `SourceEditorConfiguration: Equatable` means the upstream `paramsAreEqual` check catches most redundant updates.
- **Fix:** Already mitigated by upstream equality checks

---

## Performance Targets

| Metric | Current (Estimated) | Target |
|--------|-------------------|--------|
| Keystroke latency (1988-line file) | ~15-30ms | < 8ms |
| Scroll hitch ratio | > 10 ms/s | < 5 ms/s |
| Main thread % during scroll | ~80% | < 30% |
| Minimap CPU on scroll | ~5ms/frame | 0ms (GPU composited) |

---

## Instrumentation Points

`os_signpost` markers added to:
- `EpistemosEditorCoordinator.textViewDidChangeText` — measures coordinator overhead
- `EpistemosEditorCoordinator.textViewDidChangeSelection` — measures selection handling

Category: `app.epistemos.CodeEditor`
