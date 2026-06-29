# Epistemos App-Wide Nativeness Doctrine (2026-06-29)

> How every surface achieves "super-native feel." Owner goal: full/near-full AppKit feel; where a WebView
> is used it must be **indistinguishable from the native part** (the inverse of Codex/Claude/Paseo, which
> are 100% web-in-a-shell). Binding for Plan 1 (Goose) + Plan 2 (editor) + the app shell. Companion:
> `GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md` (the web-reskin stack research).

## The principle
**Native shell + native chrome + native FEEL everywhere. Web engines are contained islands where web is
genuinely the best tool — made to feel native via native chrome, transparency-over-real-glass, theme tokens,
spring motion, and latency discipline.** Native *feel*, not necessarily native *code*.

## The two sides
- **APP SIDE (real Apple-native + REAL Liquid Glass):** window/titlebar, nav-rail/sidebar/launcher, toolbars,
  permission/elicitation pop-ups, sheets/modals, floating panels (slash/bubble/KaTeX, Cmd+K, Halo), landing,
  graph, PDF viewer (PDFKit), QuickLook, Prose/TK2, the editor CHROME, and the native Goose Models picker.
  Real Liquid Glass via `NSVisualEffectView` / SwiftUI `Material` / macOS 26 Liquid Glass APIs.
- **WEB SIDE (blend into the native glass — can't do real Liquid Glass):** Goose chat + sessions + config
  (reskinned, permanent), the code editor (MarkEdit/CoreEditor) + note editor (Epdoc/TipTap) ENGINES, HTML
  Workspace, MCP-app guest UI. Recipe: **transparent WKWebView (`drawsBackground=false`) over a native glass
  layer** + **SF Pro (`-apple-system`)** + **Epistemos theme tokens** + **frost/tint/specular-edge fallback**
  (NOT refraction — `feDisplacementMap`/`backdrop-filter:url()` is **Chromium-only**, absent in WKWebView).

## The killer move
Don't fake glass in web. Make the **webview background transparent** and put **real `NSVisualEffectView`
Liquid Glass behind it** → the native glass shows through; the web content floats on real glass.

## Fluid motion (first-class)
Spring physics on every interaction, matched to macOS native curves (calibrate against CocoaSprings/Advance).
120fps; animate transform/opacity ONLY (never layout props); interruptible; honor `prefers-reduced-motion`.
Engine = **Motion (MIT)** / react-spring (MIT) / native CSS `linear()` springs where no JS needed.

## Hardening budget (the native baseline is INSTANT — any hitch is glaring)
60/120fps, input→paint < one frame; no layout thrash / forced sync layout; virtualize long lists; heavy work
off main thread; bounded webview live-set + LRU discard + listener teardown (no leaks); ZERO UI bugs
(no FOUC, theme-flip flicker, scroll-jump, focus-loss, z-index/overlay/double-render). Test under load + theme switch.

## Acceptance bar — PERFECT BLENDING
At the seam, native and web must be indistinguishable: font rendering, control geometry/metrics/spacing, system
colors (light/dark/accent exact), materials/vibrancy, focus rings, selection, cursors, momentum scrollbars,
motion timing. A/B pixel-diff (web control vs native control); if a human/diff can tell, it's a FAIL.

## What stays web ON PURPOSE (not a failure)
Settings + rarely-seen surfaces (calm/fluid blended web UI); the rich editor engines (CodeMirror/TipTap); HTML
Workspace; MCP-app guest UI (third-party HTML by spec — the only truly irreducible web). Goose: **route
migration STOPS after Models** — chat/sessions stay WebView, reskinned. There is NO native chat (Option 1, 2026-06-29).

## Constraints
MIT/Apache/BSD/ISC only (App-Store-safe). NO runtime npm — build-time vendor (build-tiptap-bundle.sh →
Resources → WKURLSchemeHandler). SF Pro = system font (no bundling). SF Symbols = Apple-licensed (verify use).

## Sequencing (cheapest → most expensive)
1. Transparent webviews + native glass behind (Goose + both editors). 2. SF Pro + theme-token CSS in every web
body. 3. Calm/fluid web UI for unseen surfaces (Settings). 4. Native window/titlebar Liquid Glass. 5. Native
toolbars/sidebars/launcher. 6. Native floating panels. 7. Native permission pop-ups/sheets. 8. macOS 26 material
on already-native surfaces. 9. Native editor chrome (nested-box/title/file-logos/lens toggle — already native).
10–11. Goose chat/pickers = WEB + Apple-reskin (NOT native — per Option 1).
