# Plan 2 (Editor / HTML-Workspace / Notes) — Finalization Handoff (2026-07-01)

## TL;DR
The Plan-2 **code is done and build-validated clean** — a full `xcodebuild` reached and compiled every
file in my lane with zero errors. What remains is the **in-app proof layer** (flip `isLive`, runtime
proofs) plus a handful of **app-gated deferred items** — all hard-gated on the tree being green and the
app actually launching. The tree keeps flickering red on **out-of-lane** isolation-cascade errors (not
mine to fix). This doc is everything the next agent needs to finish.

## Lane / guardrails (unchanged, owner-locked)
- You OWN: Epdoc/code-editor/Prose, js-editor/ bundle, MarkEdit embed, HTML Workspace, wikilinks, web
  clipper, PDF *viewer*, the markdown/ontology/command-registry Swift.
- ⛔ Regenerate/workspace work must NOT touch/destabilize the code editor / Source lens
  (MarkEdit/CoreEditor/source panes). **L3 code-chrome (item 6) is the ONLY sanctioned editor work.**
- NO MAS-specific code; never introduce a subprocess (Pyodide stays WASM-in-WebView).
- Do NOT fix out-of-lane breaks (Bridge/BrowserUsePro/Theme/Goose/etc.) — paste them to the owner.
- Commit at every clean point; no unrequested refactoring; minimal tests.

## What shipped this session (10 real edge-case fixes, all committed + build-validated)
| Commit | Item | Fix |
|---|---|---|
| `f34f80949` | 1 regenerate | Streaming: `.bufferingNewest(256)` w/ loud `.chunkDropped`, 240s generation timeout, surfaced transport errors (was swallowed into "missing block"), gated per-chunk reparse on a closing fence to kill an O(n²) @MainActor scan |
| `2d85d41a4` | 1 regenerate | **Prompt-injection**: `bounded()` strips newlines so a vault snippet can't forge a fake `- record:`/provenance into the LLM grounding context; empty-field drop now verifies (was silently dropped) |
| `24e8734de` | 1 revert | Preserve the just-captured snapshot from bounded eviction |
| `dc900dbeb` | 1 revert/import | **HIGH**: made escape/decode of the `<script>` data island exact inverses (was corrupting data.json via mismatched entity-decode); closed the `<!--<script>` tokenizer hole; fixed `capturedAttribute` matching `data-id`/`data-type` |
| `9c7454e20` | 6 L3 chrome | **HIGH**: LSP hover/def + Outline were stranded in the never-mounted `breadcrumbBar` → grafted into the live `codeEditorTopBar` so the built-but-dark feature is reachable |
| `b27e190d9` | 6 editor | Copy cross-file definition target + Cmd-F; flattened a 0.5px note border per nativeness canon |
| `79cab2ae6` | 7 blank-editor | Terminal CoreEditor load-failure now always paints its diagnostic (was silently blank when the readiness poll exhausted mid-load) |
| `bb277f49e` | 7 crash recorder | fatal-signal log records the actual signal name (SIGSEGV vs SIGABRT…), async-signal-safe |
| `d7c4bf55c` | 1d context | Dedup note context by `pageId` (was risking duplicate SwiftUI ForEach IDs) |
| `404e1e077` | 1d drop | `nonisolated previewContextPayload` — fixed a Swift-6 data race (background `loadItem` completion passed non-Sendable `Any?` into a @MainActor func) |

Plus **3 adversarial bug-hunts** over the pure-logic core that converged (hunt-3 found 0). Verified clean:
`PatchRouter` (atomic apply + injection guards), `HTMLWorkspaceDocument`, `HTMLWorkspacePythonRuntime` +
the URL scheme handler (no path traversal), the DOM-inspector CSS rejection (`isSafeStyleDeclaration` +
`updateStyleRule` selector escaping), `DataFeedBinder`, `fencedBlocks`/`patchResponse`, all 8 context sources.

## REMAINING WORK — the "more to do after the other lanes are done"

### A. In-app finalization (do the moment the tree is green + app launches)
The app restores its vault from `UserDefaults com.epistemos.app epistemos.vaultBookmark` (already set → no
prompt). App product: `~/Library/Developer/Xcode/DerivedData/Epistemos-*/Build/Products/Debug/Epistemos.app`.

1. **Crash recorder (item 7b)** — after launch, confirm `<vault>/.epcache/diagnostics/crash-recorder-ready.json`
   exists + is fresh. (`VaultCrashRecorder.install` at `AppBootstrap.swift:1694`.)
2. **Blank-editor proof (item 7, P0)** — open a code file; confirm the MarkEdit CoreEditor **body** renders
   (highlighted CodeMirror), not just the chrome. If blank, root-cause `MarkEditCoreEditorChunkLoader`
   (`MarkEditCoreEditorRuntimeResources.swift`) + index.html load. (The always-paint failure fix is in `79cab2ae6`.)
3. **Dark/light toggle (item 7a)** — with an Epdoc + HTML Workspace + code file open, flip appearance
   rapidly; confirm no crash. (Guards already pervasive: `!isLoadingPreview/!isLoading/isDetached` in
   `HTMLWorkspacePreviewView` + `EpdocEditorChromeView` coalesces + queues `pendingTheme`.)
4. **The 5 caps** — flip `isLive→true` in `Epistemos/Engine/HTMLWorkspaceCapabilityStatus.swift:30-34`
   ONLY for each you actually witness. Open a workspace via
   `NSDocumentController.shared.createUntitledHTMLWorkspaceDocument(in: vaultURL)` (the "New HTML Workspace"
   action — `LandingView.swift:1319`, `GraphWorkspaceContainer.swift:424`). Cap probes are triggered at
   `HTMLWorkspaceEditorView.swift:1998-2027` (bump `appBridge/console/pythonProbeNonce`); results land in
   `HTMLWorkspaceConsolePanel`. Per-cap witness:
   - **Full-surface regenerate** — needs Goose ACP backend up (`GooseRuntimeSupervisor`). Type intent →
     Stream Preview streams live → Apply persists → Revert restores. All the plumbing/UX is built.
   - **App message-bridge** — run the app-bridge probe, witness a `roundtrip` event (request→`didReceive`→
     `dispatchAppBridgeResponse` with correlated `requestId`). `didReceive` is NOT empty (that note is stale).
   - **JS console/error capture** — trigger `console.error` + a window error; witness them in the console panel.
   - **DOM picker/style inspector** — toggle inspector, click-pick an element, apply a focused style edit.
   - **Pyodide** — set manifest `allowPythonRuntime=true`; confirm the built bundle has
     `Contents/Resources/Pyodide/`; run the python probe (`sum(range(10))==45`). WASM-in-WebView only.

### B. Deferred items (my analysis + reasons — tackle with the app + a live compiler)
- **#14 — L3 code CoreEditor custom/accent theme (LOW).** L3's core is DONE (nested-box, title, real
  per-language logos, light/dark theme map, LSP/Outline reachable). The gap: the code CoreEditor maps to
  one of 5 *coordinated* CodeMirror palettes; a naive `webBackgroundColor` override clashes with the canned
  syntax colors and looks worse. Proper fix = generate a full Epistemos→CodeMirror theme (bg + syntax) from
  the palette. Source-lens; needs app visual-verify. `MarkEditCoreEditorView.swift:356-371` (`epistemosSourceTheme`).
- **#7 — dark/light theme-flip keystroke-loss (MED, Source-lens).** A theme change makes
  `MarkEditCoreEditorState.requiresReload()` true → full `loadEditor` reload that re-embeds the last-synced
  `text`, so typing + toggling within ~250ms drops keystrokes + blank-flashes. Proper fix needs an in-place
  JS `setTheme` in the code CoreEditor bundle (the markdown path has `viewController.setTheme`; the code
  path doesn't). Narrow race; risky; needs app verify.
- **#6 — per-section native drop (MED, feature).** Drag-from-sidebar works but native `.onDrop` targets the
  whole surface, not the section under the cursor (per-section is only in the generated-surface JS via
  `contextState.sectionContextKeys`). Fix = `.onDrop(of:delegate:)` reading `DropInfo.location` → map to a
  DOM section. Needs app iteration on the coord→DOM mapping. `HTMLWorkspaceEditorView.swift:551`.
- **#5 — context fetch off @MainActor (perf, LOW-ish).** Clicking a standalone context shortcut fetches
  pages + reads bodies on @MainActor. NOTE: **over-estimated** — the cheap front-matter filter gates the
  body reads (`pdfNoteCandidate` reads `normalizedBodySnippet` only *after* `sourceKind=="pdf"`), so it's
  ~PDF-count reads, not 400. Proper fix = multi-file `nonisolated` SwiftData refactor touching shared
  `SDPage` (low ROI, `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` makes it fiddly).
- **Content-hash route/asset collision (LOW) — DELIBERATELY SKIPPED.** `HTMLWorkspacePackageContentHasher`
  frames routes and assets identically, so a route + asset with same name+bytes collide. I did NOT fix it:
  changing the hasher makes every existing on-disk `.source.json` snapshot fail its `computedContentHash ==
  contentHash` integrity check → revert silently degrades to the rendered-HTML fallback. Only fix with a
  versioned hash if ever prioritized.

## Current build blocker (out-of-lane — paste to the owner, do NOT fix)
The module uses `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`; agents keep marking things `nonisolated`
without propagating it to their deps, so the tree flickers red one isolation error at a time. Latest:
```
Theme/EpistemosTheme.swift:1618 — main actor-isolated `epistemosCustomThemeDidChange`
  referenced from a nonisolated context   (Plan-1 Goose custom-palette work, commit f57142532)
```
**Green-the-build prompt for the file-owner agent:** run `xcodebuild -scheme Epistemos -destination
'platform=macOS' build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"`, fix EVERY isolation error by
propagating `nonisolated` (the referenced constant/init/property must also be `nonisolated`), and repeat
until `** BUILD SUCCEEDED **`. Do NOT touch the editor / HTML-Workspace / Notes lane (already clean).

## Verification commands
- My-lane compiles clean: the last full build reached + passed all `Epistemos/Views/HTMLWorkspace/*`,
  `Epistemos/Views/Notes/*`, `MarkEditCoreEditor*`, `HTMLWorkspace*` files with zero errors.
- Source guard (owner-locked): `HTMLWorkspaceEditorView.swift` must contain `MarkEditCodeEditorRepresentable(`
  and must NOT contain `HTMLWorkspaceCodeEditor(` or `TextEditor(` for source panes.
