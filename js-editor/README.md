# Epistemos Tiptap WKWebView Bundle (W7.17)

The browser-side editor that runs inside the `.epdoc` WKWebView. Built
with [Tiptap 3](https://tiptap.dev) + Webpack. Shipped to
`Epistemos.app/Contents/Resources/Editor/` and loaded via the custom
`epistemos-doc://editor.html` scheme handler at
[Epistemos/Engine/EpdocEditorBridge.swift](../Epistemos/Engine/EpdocEditorBridge.swift).

## Layout

```
js-editor/
├── package.json         # pinned deps (Tiptap 3.22.4, KaTeX 0.16.45)
├── webpack.config.js    # web target, copies KaTeX fonts to vendor/
├── tsconfig.json        # ES2022 + DOM, strict, isolatedModules
├── src/
│   ├── index.ts         # editor mount + extension list + bridge wiring
│   ├── editor.html      # WKWebView landing page (mounted by HtmlWebpackPlugin)
│   ├── editor.css       # base + Material-3-flavoured chrome
│   ├── extensions/
│   │   ├── legacy-diagram-node.ts # compatibility source node for old diagram blocks
│   │   ├── slash-menu.ts          # @tiptap/suggestion config (W7.17.b)
│   │   └── caret-rect-emitter.ts  # ProseMirror plugin emitting selection rect → Swift
│   ├── bridge/
│   │   ├── inbound.ts   # window.epistemos.* command receivers (Swift → JS)
│   │   └── outbound.ts  # postMessage helpers (JS → Swift)
│   └── types/
│       └── webkit.d.ts  # WKScriptMessage typings
└── dist/                # build output (gitignored) — webpack writes editor.{html,js,css}
```

## Build

```sh
cd js-editor
npm install                # pulls Tiptap + KaTeX
npm run build              # production build → dist/
npm run dev                # dev build with --watch (sourcemaps + HMR-ish)
npm run typecheck          # tsc --noEmit
```

The Xcode build also runs `build-tiptap-bundle.sh` (in the repo root) as
a `preBuildScript` so the bundle is rebuilt + staged on every Xcode
build. That script wraps `npm ci --no-audit --no-fund` (idempotent, uses
`package-lock.json`) and rsyncs `dist/` into
`Epistemos/Resources/Editor/`.

## Bridge contract

**JS → Swift** (via `window.webkit.messageHandlers.epdoc.postMessage`):

| Message              | Payload                                      | When                                    |
| -------------------- | -------------------------------------------- | --------------------------------------- |
| `editorReady`        | `{ type: 'editorReady' }`                    | Once after Tiptap mounts                |
| `contentDidChange`   | `{ json: '<ProseMirror JSON>' }`             | Every transaction (debounced Swift-side) |
| `caretChanged`       | `{ rect, selection }`                        | Every selection change (W7.17.a SwiftUI bridge) |
| `requestSlashMenu`   | `{ query, anchor }`                          | When `/` is typed                       |
| `requestBubbleMenu`  | `{ selection, anchor }`                      | On non-empty selection                  |

**Swift → JS** (via `WKWebView.evaluateJavaScript`):

```js
window.epistemos.setContent(json)
window.epistemos.focusStart()
window.epistemos.focusEnd()
window.epistemos.dismissSlashMenu()
window.epistemos.insertSlashChoice(blockType)
window.epistemos.dismissBubbleMenu()
window.epistemos.runCommand(commandName, ...args)  // generic Tiptap command dispatch
```

## Extension stack

The editor mounts:

- **Core** — StarterKit (paragraph / heading / lists / blockquote / code /
  history) + UniqueId for block identity preservation
- **Inline** — Bold / Italic / Strike / Code / Link / Highlight /
  Subscript / Superscript / TextAlign
- **Block** — Table (resizable) / TaskList / TaskItem / HorizontalRule
- **W7.7** — Mathematics (KaTeX) / Footnotes / Highlight (==text==)
- **HTML Workspace bridge** — new visual/DOM work opens a separate HTML Workspace
- **Legacy diagram source** — old diagram nodes remain loadable as inert source blocks
- **W7.17.b** — Suggestion-based slash menu / BubbleMenu / FloatingMenu /
  DragHandle (block-action gutter)
- **CharacterCount** — drives the W7.17 stats badge

## Open follow-ups

- Implement the slash menu's command catalog (~20 entries: heading 1-6 / bullet / numbered / task / quote / code / math / HTML Workspace / callout / table 3x3 / divider / image / link to doc / embed / template — see `EXTENDED_PROGRAM_PLAN_2026_04_25.md` row W7.17.b)
- Extend `EpdocBridgeMessage` (in `Epistemos/Engine/EpdocEditorBridge.swift`) with `caretChanged` / `requestSlashMenu` / `requestBubbleMenu` decode cases
