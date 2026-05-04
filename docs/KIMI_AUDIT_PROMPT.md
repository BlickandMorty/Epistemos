# Kimi Audit Prompt — Code Editor Performance Review

> **Index status**: SUPERSEDED-HISTORICAL — Kimi audit prompt (predecessor to KIMI_AUDIT_REPORT).
> **Superseded by / Phase**: KIMI_AUDIT_REPORT.
> Classified in [`docs/_INDEX.md §14`](_INDEX.md).



## Context

Claude completed a multi-phase optimization of the Epistemos code editor. The goal is Xcode-grade 120fps ProMotion fluidity. Please audit all changes for correctness, find remaining performance opportunities, and verify nothing was missed from the research documents.

## Files to Read (in order)

1. **`Epistemos/Views/Notes/CodeEditorView.swift`** — The main implementation. Read EVERY line.
2. **`docs/PERF_BASELINE.md`** — Profiling checklist and known bottlenecks
3. **`docs/GPU_RENDERER_SEAM.md`** — Future Metal/Rope/MSDF architecture documentation
4. **`project.yml`** — Package dependencies (CodeEditSourceEditor version constraint)

## Research Documents (the source of truth)

Read these to verify the implementation matches:
- `opt4.md` — 120fps Optimization Playbook (profiling, NSTextStorage, tree-sitter actor, CADisplayLink, minimap caching)
- `opt5.md` — Detailed optimization with version upgrade info (87% CPU reduction in CESE v0.13.1)
- `opt6.md` — NSTextStorage bridge details (delegate pattern, O(1) line count, infinite loop guard, incremental tree-sitter routing)
- `opt.txt` — Full architecture analysis (SumTree/Rope, Metal pipeline, MSDF, CoreText shaping)
- `opt2.txt` — Engineering deep dive (CVDisplayLink, triple buffering, wait_until_scheduled)
- `opt3.txt` — Architectural transformation blueprint (three-phase highlighting, viewport-aware querying)

## What Was Implemented

### Phase A: Profiling Baseline
- `docs/PERF_BASELINE.md` with Instruments checklist, known bottlenecks, performance targets
- `os_signpost` markers on `textViewDidChangeText` and `textViewDidChangeSelection`

### Phase C: Replace Binding<String> with NSTextStorage
- `CodeEditorDocumentState` class holds `NSTextStorage` as reference type
- `NSTextStorageDelegate` with `didProcessEditing` for debounced save (500ms)
- `isApplyingExternalChange` flag to prevent infinite update loops
- Cached `lineCount` updated via delegate (not O(n) string scan per keystroke)
- `SourceEditor` receives `NSTextStorage` (not `Binding<String>`)
- Coordinator reads `documentState.lineCount` — O(1) instead of O(n)

### Phase F: Minimap Optimization
- `prepareCoordinator` walks view hierarchy to find MinimapView
- Sets `layerContentsRedrawPolicy = .onSetNeedsDisplay` to prevent CPU redraw on scroll

### Phase G: Future Architecture Docs
- `docs/GPU_RENDERER_SEAM.md` documenting:
  - Metal glyph atlas (alpha-only, 16 sub-pixel variants, etagere bin-packing)
  - MSDF fragment shader with median-filtering + fwidth() adaptive AA
  - Triple buffering with wait_until_scheduled vs wait_until_completed comparison
  - CADisplayLink keep-alive for ProMotion (1s window, preferredFrameRateRange)
  - Rope/SumTree (complexity table, B+ tree architecture, UniFFI integration path)
  - Three-phase highlighting (Rust FFI → tree-sitter → LSP)
  - Abstraction seam protocols (TextBufferProvider, TextRenderer, MinimapRenderer)
  - Implementation priority table with effort/impact/timing

### Version Upgrade
- `project.yml` bumped to `from: "0.13.1"` (resolves to 0.15.2, includes 87% CPU reduction)

## What You Should Check

### 1. Correctness Audit
- Does `CodeEditorDocumentState` correctly implement `NSTextStorageDelegate`?
- Is `textStorage.delegate = self` set in `init` AFTER `super.init()`?
- Does `isApplyingExternalChange` properly guard all external mutation paths?
- Is the `nonisolated` on the delegate method correct for Swift 6?
- Does the `Task { @MainActor }` inside the delegate correctly capture values across isolation?
- Is `@State` correct for `CodeEditorDocumentState?` (it's a non-ObservableObject class)?
- Does `makeCoordinator` correctly set `coord.documentState = docState`?
- Is `weak var documentState` safe (won't be deallocated while coordinator lives)?

### 2. Performance Audit
- Is there ANY remaining O(n) string copy on keystroke in the hot path?
- Is `lineCount` truly O(1) to read from the coordinator?
- Does the `lineCount` update in `didProcessEditing` still do `components(separatedBy:)` O(n)? If so, is this acceptable since it's in a debounced Task on MainActor?
- Is the minimap `layerContentsRedrawPolicy` actually being applied? (MinimapView class name must match the string check)
- Are there any other views that redraw on scroll that shouldn't?

### 3. Missing Items from Research
- **CADisplayLink keep-alive**: Is there any runtime code for ProMotion pacing? (Answer: NO, it's documentation-only in GPU_RENDERER_SEAM.md. Should it be added now?)
- **Three-phase highlighting**: Is the Rust FFI wired as Phase 1 fallback? (Answer: NO, documented for future session)
- **Tree-sitter background actor**: Is there a dedicated Swift actor wrapping TreeSitterClient? (Answer: NO, using upstream's built-in async executor)
- **NSTextStorage subclass**: opt6.md suggests a custom subclass for intercepting `replaceCharacters`. Is this needed, or is the delegate approach sufficient?
- **editedRange routing to tree-sitter**: The delegate receives `editedRange` + `delta`. Is this being forwarded to TreeSitterClient for incremental parsing?

### 4. Remaining Performance Opportunities
- The `lineCount` update inside `didProcessEditing` still calls `components(separatedBy:)` which is O(n). Could this be replaced with delta-based counting from `editedRange`?
- The `onContentChange` callback in the save debounce calls `self.textStorage.string` which is an O(n) copy. Is there a way to avoid this? (The vault sync needs the full string for disk write.)
- Could the coordinator's `textViewDidChangeSelection` be throttled? It fires on every cursor position change at 120fps.
- Is there scroll-linked re-highlighting that could be deferred?

### 5. Build Verification
```bash
xcodebuild -scheme Epistemos -destination 'platform=macOS' build -skipPackagePluginValidation -disableAutomaticPackageResolution
```
Must succeed with zero errors.

## Acceptance Criteria

- [ ] Cursor movement does NOT cause full-document rehighlight
- [ ] Editing is NOT driven by whole-file SwiftUI string diffing
- [ ] Coordinator's `textViewDidChangeText` does NOT call `controller.textView.string`
- [ ] NSTextStorageDelegate handles debounced save and line count
- [ ] isApplyingExternalChange prevents infinite loops
- [ ] Minimap does not CPU-redraw on scroll
- [ ] No regression to prose editor
- [ ] Build succeeds
- [ ] GPU_RENDERER_SEAM.md covers: Metal atlas, MSDF, triple buffering, CADisplayLink, Rope/SumTree, three-phase highlighting
- [ ] PERF_BASELINE.md has profiling checklist with specific symbols to watch

## Key File Paths

| File | Role |
|------|------|
| `Epistemos/Views/Notes/CodeEditorView.swift` | Main editor + document state + coordinator |
| `Epistemos/Theme/EpistemosTheme.swift` | XcodeCodeColors struct (~line 194-273) |
| `docs/PERF_BASELINE.md` | Profiling checklist |
| `docs/GPU_RENDERER_SEAM.md` | Future Metal/Rope architecture |
| `project.yml` | Package dependencies (line 137-139) |
| `graph-engine/src/code_highlight.rs` | Rust FFI tree-sitter (future Phase 1 fallback) |
