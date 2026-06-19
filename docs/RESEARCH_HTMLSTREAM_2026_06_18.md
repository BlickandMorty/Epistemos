# R-HTMLSTREAM verdict — Alphanimble/htmlstream (StreamHtml) (2026-06-18)

**Verdict: PORT via the WebKit-bundle path Epistemos ALREADY uses for Tiptap —
build StreamHtml's TS/React at DEV time, copy the bundle into the app, render it
in a WebKit WebView for the P7.2 HTML workspace / a rich chat-HTML render. MIT →
ProvenanceGate direct_import. The repair pipeline + DOMPurify sanitization are the
proven code to lift (don't hand-roll streaming-HTML repair). NO Node at runtime
(MAS sandbox forbids it — same rule as the Tiptap bundle). Pixel-art reskin. No
code lifted this slice (research-first).**

## What it is (primary source: the GitHub README)
`Alphanimble/htmlstream` (package "StreamHtml") — "a streaming-optimized HTML
renderer for AI responses — the HTML counterpart to Streamdown." Lets an LLM
stream rich HTML (dashboards, tables, styled diffs) instead of markdown, rendered
safely + incrementally as tokens arrive, with no layout jumps.
- **Stack:** TypeScript (97%) + CSS, React 18+ (also exports headless `rehtml()` /
  `sanitizeHtml()` for non-React). Build = tsup; test = Vitest.
- **License:** **MIT**.
- **Type:** a React **component library** (npm package) + headless functions.
- **The repair pipeline (the valuable core):** per streamed chunk — strip
  incomplete tags + auto-close open elements; split completed (frozen/memoized)
  blocks from the live tail; patch the DOM incrementally (append text + table
  rows, not full re-render); **sanitize via DOMPurify (XSS)**; optional
  collapsible reasoning panel + streaming caret.
- **Deps:** DOMPurify (sanitization), Vercel AI SDK `@ai-sdk/react` (chat
  integration, optional), OpenRouter (demo only).

## How it maps into Epistemos (native vs WebKit)
| StreamHtml piece | Epistemos today | Mapping |
|---|---|---|
| React HTML-stream renderer + repair pipeline | Chat renders **markdown**; the **Tiptap editor is a WebKit bundle** (`js-editor/`, built at dev time, copied to `Contents/Resources/Editor/`, never npm-at-runtime) | ✅ **WebKit bundle** — the EXACT Tiptap pattern. Build StreamHtml's TS/React into a bundle at dev time, copy into the app, render in a WKWebView. The streamed HTML is fed from the chat/agent token stream. |
| P7.2 HTML workspace + chat-drivable canvas / live viewer | the surface this PAIRS with (owner noted) | ✅ StreamHtml IS the live HTML viewer P7.2 wants — rich, incremental, safe. |
| DOMPurify XSS sanitization | none for arbitrary model HTML | ✅ LIFT — critical. Any model-streamed HTML must be sanitized; DOMPurify is the proven path. |
| incremental DOM patching (no layout jumps) | n/a | ✅ LIFT — the hard part; don't hand-roll streaming-HTML repair. |
| `@ai-sdk/react` / OpenRouter chat glue | Epistemos owns its chat + agent stream (Rust agent_core / MLX) | ⮕ DROP the AI-SDK/OpenRouter glue — feed StreamHtml from Epistemos's own stream. |

## The port (full, MAS-safe, pixel-art)
1. **Bundle it like Tiptap.** Add a `js-htmlstream/` (or fold into `js-editor/`)
   esbuild/tsup bundle of StreamHtml, content-hash-gated on the lockfile (mirror
   `build-tiptap-bundle.sh`). Output copied into `Contents/Resources/` at build
   time. **NEVER npm at runtime** (MAS sandbox + hardened runtime — CLAUDE.md).
   CI `npm ci` before the Xcode build keeps the lock-hash gate honest.
2. **Render surface.** A WKWebView (reuse `EpdocWebViewShared.processPool` +
   `.nonPersistent()` data store per the perf hardening) hosting the StreamHtml
   component, fed the agent/chat HTML token stream via the existing WKWebView
   message bridge.
3. **Wire to P7.2** (HTML workspace / live viewer) first; optionally a rich-HTML
   chat-render mode (gated, opt-in — markdown stays default).
4. **Pixel-art reskin** the StreamHtml CSS (fonts → the app's pixel/mono fonts,
   flat borders) — consistent with the app look.
5. **ProvenanceGate:** MIT → `direct_import` (vendor the TS source through the
   gate, like other third-party JS); keep DOMPurify pinned.

## Why WebKit, not a native Swift port
HTML rendering + incremental DOM patching natively is a large, low-value
re-implementation when WebKit is available + the Tiptap bundle precedent already
proves the dev-time-bundle / no-runtime-npm pattern is MAS-safe. The owner's brief
explicitly allows WebKit where the surface needs it; an HTML-stream renderer needs
it.

## Net
Small, clean, high-fit port: StreamHtml is exactly the incremental, sanitized
HTML-stream renderer the P7.2 HTML workspace wants, MIT, and it slots into the
proven Tiptap WebKit-bundle pipeline (dev-time build, no runtime Node). Lift the
repair pipeline + DOMPurify; drop the AI-SDK glue; pixel-art reskin. No code
lifted this slice (research-first verdict). Cross-ref: P7.2 HTML workspace, the
js-editor/ Tiptap bundle, EpdocEditorChromeView WKWebView hardening.
