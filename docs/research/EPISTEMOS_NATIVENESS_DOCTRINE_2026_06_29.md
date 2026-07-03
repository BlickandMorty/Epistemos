# Epistemos App-Wide Nativeness Doctrine (2026-06-29)

> 🟡 **PARTIAL-SUPERSEDE 2026-07-02 (OpenChamber pivot).** The flat/minimal/theme-aware LOOK principles + the verified Apple tokens/springs/glass recipe here are STILL CANON (apply to June + OpenChamber + the MAS-June surface). STALE: any "apply this by RESKINNING GOOSE's web UI / Option 1 / Goose is the surface" framing — the agent surface is now OpenChamber (Pro) / June+goose-in-process (MAS). Canon: memory `project_ui_base_pivot_openchamber_2026_07_02`.


> ⚡ **OWNER REFINEMENT — 2026-06-30 (after seeing the live app; SUPERSEDES the surface-material details below where they conflict):** the look is **HIGH-QUALITY FLAT · MINIMAL · THEME-AWARE · OPTIMIZED.** KEEP the native FRAME (rounded-corner window + vibrancy + traffic-lights + springs — the curved-white window the owner likes). **SURFACES are FLAT + BORDERLESS** — NO thick outlines / hard box borders / 1px rules; differentiate by subtle tint + spacing + soft shadow only. NOT old thick-outline pixel-art, NOT translucent-glass on every surface. **For GOOSE: NO native nav rail** — it duplicated Goose's own web sidebar and lagged; native = the window FRAME only, Goose's reskinned web UI is the whole surface + nav.

> ✅ **OWNER REFINEMENT LOCKED 2026-06-30 — flat/minimal + slight pixel twist is the active Goose visual direction.**
> The full NUANCED unification doctrine below STANDS as supporting authority — the convergence of native + editor-web + Goose-web
> into ONE Apple-native language via shared tokens · the canonical springs · macOS-26 Liquid Glass · transparency-over-real-glass ·
> and the per-substrate recipes. **Do NOT reduce it to a one-word label** ("pixel-art" / "flat" / even just "Apple-native"): the
> nuance — per-surface treatment so the seams vanish — IS the plan. Read the whole doctrine, don't shortcut it.
> **RETAINED:** **TOTAL THEME-AWARENESS** — every surface (native + editor-web + Goose-web)
> reads the Epistemos tokens and re-tints live for ALL palettes: the 9 built-ins **AND the user CUSTOM palette** (which currently
> does NOT propagate everywhere = a BUG to fix; no hardcoded color; two-token-sources). radius 11 + Liquid Glass + springs all stand.
> **PRECISE GOOSE SCOPE (owner 2026-06-30):** Claude-desktop-style clean flat UI, borderless surfaces, no blue focus ring, no hard boxes, and a slight pixel twist on headings/labels/companions only. Goose has **NO native nav rail and NO native Models route**; Goose's own web UI is the whole navigation surface inside a clean rounded native window.

> How every surface achieves "super-native feel." Owner goal: full/near-full AppKit feel; where a WebView
> is used it must be **indistinguishable from the native part** (the inverse of Codex/Claude/Paseo, which
> are 100% web-in-a-shell). **BINDING FOR ALL THREE PLANS — Plan 1 (Goose), Plan 2 (editor), Plan 3
> (capabilities) — + the app shell.** Companion: `GOOSE_NATIVE_WEB_RESKIN_2026_06_29.md` (web-reskin stack +
> verified tokens/springs/glass recipe/code refs).

## ★ THE UNIFIED LOOK (the convergence — this IS the plan)
Three rendering substrates — **AppKit/SwiftUI/Metal (native)** + **WKWebView (web engines)** + **the Goose web
surface** — all CONVERGE into ONE Apple-native design language, drawn from MULTIPLE sources unified by shared
tokens: SF Pro (`-apple-system`), the shadcn Apple token palette (Action Blue #0066cc, etc.), macOS HIG control
geometry, the macOS-26 Liquid Glass material, and the exact SwiftUI spring values. The user must never perceive
"native part vs web part" — one app, one look. Every surface (native or web) pulls from the SAME token + motion +
glass vocabulary so the seams vanish.
**Two token SOURCES, identical values:** `Epistemos/Theme/EpistemosTheme.swift` (Swift — feeds the native chrome +
the editor web bodies via their injectors: `EpdocEditorThemeStyle`, `MarkEditCoreEditorView`'s theme param,
`HTMLWorkspacePreviewView.themeGuardCSSOverride`) and Goose's `ui/desktop/src/theme/theme-tokens.ts` (Goose-web).
Both MUST hold the SAME Apple values (SF Pro · #0066cc palette · radius 11 · the spring `{duration,bounce}` set) →
AppKit + editor-web + Goose-web all render one look. Keep them in lock-step (no-contradiction across the two sources).

## Graph = ALREADY full AppKit/Metal — DO NOT TOUCH
The graph is the native REFERENCE for the feel (Metal + AppKit), not a reskin target. Match its instant,
ProMotion feel; never modify it. (Same for other already-native Metal/AppKit surfaces unless explicitly scoped.)

## The principle
**Native shell + native chrome + native FEEL everywhere. Web engines are contained islands where web is
genuinely the best tool — made to feel native via native chrome, transparency-over-real-glass, theme tokens,
spring motion, and latency discipline.** Native *feel*, not necessarily native *code*.

## The two sides
- **APP SIDE (real Apple-native + REAL Liquid Glass):** window/titlebar, app-owned sidebars/launchers/toolbars outside
  the Goose window, permission/elicitation pop-ups, sheets/modals, floating panels (slash/bubble/KaTeX, Cmd+K, Halo),
  landing, graph, PDF viewer (PDFKit), QuickLook, Prose/TK2, and the editor CHROME.
  **Goose exception:** its window keeps only the bare rounded native frame + native permission/elicitation pop-ups.
  Goose's own web sidebar/navigation and models/providers/settings remain web.
  Real Liquid Glass via `NSVisualEffectView` / SwiftUI `Material` / macOS 26 Liquid Glass APIs.
- **WEB SIDE (blend into the native glass — can't do real Liquid Glass):** Goose chat + sessions + config
  (reskinned, permanent), the code editor (MarkEdit/CoreEditor) + note editor (Epdoc/TipTap) ENGINES, HTML
  Workspace, MCP-app guest UI. Recipe: **transparent WKWebView (`drawsBackground=false`) over a native glass
  layer** + **SF Pro (`-apple-system`)** + **Epistemos theme tokens** + **frost/tint/specular-edge fallback**
  (NOT refraction — `feDisplacementMap`/`backdrop-filter:url()` is **Chromium-only**, absent in WKWebView).

## The killer move
Don't fake glass in web. Make the **webview background transparent** and put **real `NSVisualEffectView`
Liquid Glass behind it** → the native glass shows through; the web content floats on real glass.

## Fluid motion (first-class) — DEEPLY fluid, ProMotion, minimal
Spring physics on EVERY interaction, matched to macOS native curves. **Target 120fps ProMotion**, deeply fluid yet
**minimal** (motion serves clarity, never decoration — small, fast, purposeful springs; nothing bouncy-for-its-
own-sake). Animate transform/opacity ONLY (never layout props); interruptible (re-targets mid-flight); honor
`prefers-reduced-motion`. Engine = Goose's EXISTING framer-motion (MIT) — calibrate to the VERIFIED SwiftUI
spring values (`.smooth` {0.5,0} controls/sheets · `.snappy` {0.5,0.15} tabs/toggles/buttons · `.bouncy` {0.5,0.3}
toasts/transitions · `.interactiveSpring` {0.15,0.14} drag). Pure CSS `linear()` springs where no JS needed.

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
10–11. Goose chat + sessions + settings + models/providers pickers = WEB + owner-approved flat Claude-like pixel reskin (NOT native). There is no native Goose route promotion.

## ★ PER-PLAN NATIVE vs WEB SPLIT (apply this doctrine to ALL three plans)
**Plan 1 — Goose:** NATIVE = bare rounded window frame + native permission/elicitation pop-ups only. WEB-reskinned
(permanent) = Goose's own sidebar/nav, chat, sessions, settings, models/providers, recipes, skills, scheduler, MCP-app.
Treatment = retheme Goose's existing shadcn/Radix/Tailwind + tune its framer-motion + theme tokens + the approved
flat Claude-like pixel twist. (See GOOSE_NATIVE_WEB_RESKIN + GOOSE_FLAT_PIXEL_RESKIN_SPEC.)
**Plan 2 — Editor:** NATIVE = all chrome (code nested-box/title/file-logos/lens toggle; note chrome), Prose/TK2,
PDF viewer (PDFKit), Cmd+K, floating panels. WEB engines (blend, don't replace) = MarkEdit/CoreEditor (code) +
Epdoc/TipTap (note) + HTML Workspace. Same recipe: transparent-over-glass + SF Pro + theme tokens + spring motion
on the web bodies; real Liquid Glass on the chrome. The editors already are web engines in native chrome — apply
the SAME unified tokens + glass + springs so they match Goose + the shell pixel-for-pixel.
**Plan 3 — Capabilities:** NATIVE = Apple-native shared views (QuickLook/VisionKit/thumbnails), landing-feature
buttons, the lite Browser tab chrome, arXiv/meeting/voice UI, provenance views, and PDF affordances that hand a
resolved `source_pdf` URL to Plan 2's PDFKit viewer (Plan 3 does not implement a second viewer).
WEB = browser-use's Chromium UI (Pro, its own surface — reskin its hosted web UI with the same tokens where
feasible; honest that CDP-Chromium ≠ WKWebView). Everything Plan 3 renders natively uses the macOS-26 glass +
SF Pro + the unified tokens + the spring values; any web panel it hosts gets the transparent-over-glass treatment.
**Graph (any plan): DO NOT TOUCH — already full AppKit/Metal.**

## ★ CODE-RESEARCH MANDATE (actual code to look at + copy from, not just library names)
Every recommendation must be backed by REAL, READABLE CODE — not just a library name. For each adopted thing,
the canon records: the repo + the specific file/path (and where possible the exact lines/snippet) to LOOK AT and
LIFT from, the license, and the ProvenanceGate verdict (direct_import / lift-specific-code / adapter / clean-room).
Pull concrete code: shadcn primitive sources (button/select/switch/sheet/dropdown), framer-motion spring configs,
the Apple token CSS-var set, the macOS spring constants, the transparent-webview Swift (already in-repo:
EpdocKaTeXPreview.swift:79, AgentSurfaceWindowController.swift:37, GlassModifiers.swift, UnifiedFrostedGlass.swift).
Prefer in-repo proven code first, then vetted OSS. The build agent should be able to OPEN the cited code and copy.

## ★ RESEARCH-BETWEEN-IMPLEMENTATION discipline (exhaustive; tokens are NOT a constraint)
Owner directive: be exhaustive — research is cheap, lost nuance + bugs are expensive. BETWEEN every implementation
step the agent RESEARCHES (local docs + the repo + online primary sources) and READS before editing as much as it
can. Loop = research → read the exact file(s) → implement small slice → verify → research the next gap → repeat.
NO-CONTRADICTION + PRESERVE-NUANCE + BREAK-NOTHING on every edit. Close gaps proactively; never guess where a
source can confirm. Use as many tokens as needed — exhaustive research + verified execution > speed.
