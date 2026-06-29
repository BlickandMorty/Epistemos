# Goose Native-Feel Web Reskin — LIVING RESEARCH (started 2026-06-29)

> FOREVER-LOOP research (cron `3856c0a4`, every 3m). Goal: reskin Goose's web UI so it is
> **indistinguishable from the native AppKit part** inside a WKWebView — fluid spring motion,
> hardened (no lag/jank/bug), every Goose component mapped to a native-feeling web alternative.
> This doc is updated IN PLACE each round (read-first · no-contradiction · preserve-nuance · break-nothing).
> Companion canon: `EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md` · `docs/handoffs/GOOSE_NATIVE_UI_DECISION_2026_06_29.md`
> (chat stays WebView reskinned — Option 1, native FRAME only; stop native-promotion after Models).

## Doctrine this serves (summary — full in the doctrine doc)
- Native shell = REAL Liquid Glass (`NSVisualEffectView` / macOS 26 APIs). Web body = TRANSPARENT
  (`drawsBackground=false`) over the real glass. Content themed: SF Pro (`-apple-system`) + Epistemos
  theme tokens + specular-edge fallback. **True refraction is Chromium-only → frost+specular in WebKit.**
- MIT/Apache/BSD/ISC only. NO runtime npm — vendor at BUILD time (build-tiptap-bundle.sh model →
  Resources → WKURLSchemeHandler). Real verified repos only; `[VERIFIED]` needs a real source + WebKit check.

## ★★ R2 PIVOTAL FINDING — Goose's stack = RETHEME, not REPLACE
Verified from the real Goose UI source (`.research-clones/work/goose/ui/desktop`):
- **React 19.2.4** + **shadcn/ui** (`components.json` `$schema=ui.shadcn.com`, style `new-york`, `cssVariables:true`,
  baseColor neutral) + **Radix UI** (accordion/avatar/dialog/popover/radio/scroll-area/select/slot/tabs/themes) +
  **Tailwind CSS v4.2.1** + **class-variance-authority** + clsx + tailwind-merge + **framer-motion v12.34.3** (= MIT
  "Motion", already verified R1) + **lucide-react** icons + tailwindcss-animate + tw-animate-css.
- shadcn primitives present in `src/components/ui/`: button, card, collapsible, dialog, dropdown-menu, input,
  scroll-area, separator, sheet, skeleton, switch, tabs, Select, Tooltip, Pill, BaseModal, ConfirmationModal, …
- ⇒ **THE STRATEGY: do NOT introduce a new component library. RETHEME Goose's EXISTING shadcn/Radix/Tailwind
  components via the Tailwind config + CSS variables (shadcn theming layer) + tune the EXISTING framer-motion
  springs to macOS curves.** Nothing is swapped → nothing breaks (safest possible path; honors "nothing lost").
- ⇒ **LiqUIdify / Framework7 / Konsta = research_only/reference** (adopting them would REPLACE Goose's components
  = risk). Lift HIG *patterns/values* only.
- ⇒ **shadcn Apple Design System tokens drop in NATIVELY** — it's a shadcn theme (SF Pro, Action Blue #0066cc,
  DESIGN.md token set) applied to the SAME shadcn primitives Goose already uses.
- ⇒ **Motion is already present** (framer-motion v12, MIT) — calibrate its spring values to macOS
  (CocoaSprings/Advance), don't add a lib. **lucide-react** is the icon set → map/retheme to feel native (SF
  Symbols licensing = open gap).

## RECOMMENDED STACK — R2 (retheme-the-existing-shadcn)
| Layer | Decision | License | Provenance | Status |
|---|---|---|---|---|
| **Component base** | Goose's EXISTING shadcn/ui + Radix (retheme, don't replace) | MIT (shadcn/Radix) | in-place retheme | ✅ [VERIFIED source] |
| **Theme** | shadcn **Apple Design System** tokens → Goose's Tailwind/CSS vars | verify terms | lift tokens | ⏳ pull DESIGN.md next round |
| **Motion** | Goose's EXISTING **framer-motion v12** (MIT) — tune springs to macOS | MIT | in-place calibrate | ✅ [VERIFIED source+repo] |
| Spring calibration ref | CocoaSprings / Advance (native feel-match values) | MIT | reference | ⏳ extract spring values |
| Pure-CSS motion | native CSS `linear()` springs where no JS needed | platform | direct | ⏳ confirm WebKit |
| Icons | Goose's **lucide-react** → retheme; map key glyphs to SF Symbols | MIT (lucide) | retheme | ⏳ SF Symbols licensing |
| Glass (native) | `NSVisualEffectView` / macOS 26 | Apple | platform | ✅ doctrine |
| Glass (web fallback) | frost+tint+specular CSS (NOT refraction) | n/a | clean-room CSS | ✅ refraction Chromium-only |
| ~~LiqUIdify / Framework7 / Konsta~~ | reference HIG patterns ONLY (do not adopt as base) | — | research_only | ✅ demoted (would replace Goose) |

## COMPONENT MAPPING TABLE — Goose's REAL components → RETHEME recipe (R2)
"Best web alt" = retheme Goose's OWN shadcn/Radix primitive (no replacement). Status: ✅ needs source+WebKit+A/B pixel-diff · ⏳ GAP.
| Goose component (file) | retheme target | macOS recipe | spring | status |
|---|---|---|---|---|
| `ui/button.tsx` | retheme | SF Pro, push/accent geometry (~22–28px h, 6px radius), Action Blue fill | press scale spring | ⏳ |
| `ui/input.tsx` | retheme | macOS text field, system-accent focus ring, 1px inset border | — | ⏳ |
| `ui/Select.tsx` + radix select | retheme | macOS popup-button + chevron, vibrancy menu | present spring | ⏳ |
| `ui/switch.tsx` | retheme | macOS switch geometry/colors | knob flip spring | ⏳ |
| `ui/tabs.tsx` | retheme | macOS segmented control | slide spring | ⏳ |
| `ui/dialog.tsx` · `ui/sheet.tsx` · `BaseModal` · `ConfirmationModal` | retheme | macOS sheet (slide-down) / centered modal, vibrancy | sheet present-dismiss spring | ⏳ |
| `ui/dropdown-menu.tsx` | retheme | macOS menu, vibrancy, item highlight = accent | present spring | ⏳ |
| `ui/Tooltip.tsx` | retheme | macOS tooltip (delay/style) | fade spring | ⏳ |
| `ui/scroll-area.tsx` (radix) | retheme | native momentum + overlay scrollbars | — | ⏳ |
| `ui/card.tsx` · `Pill.tsx` | retheme | vibrancy surface / macOS token pill | — | ⏳ |
| `ui/collapsible.tsx` · `Expand.tsx` | retheme | — | height/opacity spring | ⏳ |
| `ui/separator.tsx` | retheme | hairline divider (system) | — | ⏳ |
| `ui/skeleton.tsx` | retheme | macOS shimmer | shimmer | ⏳ |
| `BaseChat` · `GooseMessage` · `ProgressiveMessageList` · `MarkdownContent` · `ThinkingContent` | retheme + virtualize | chat bubbles, SF Pro, SF Mono code, virtualized transcript | message insert spring | ⏳ |
| `ChatInput` · `ChatInputCard` · `MentionPopover` | retheme | macOS composer, focus ring, mention popover vibrancy | — | ⏳ |
| `Hub.tsx` · `LauncherView.tsx` | retheme | hub/launcher on glass | route transition spring | ⏳ |
| `GooseSidebar/` · `Layout/` | retheme | sidebar vibrancy blend (matches native nav-rail) | — | ⏳ |
| `ElicitationRequest` · `ParameterInputModal` · `JsonSchemaForm` · `ExtensionInstallModal` | retheme | macOS form controls/sheets | sheet spring | ⏳ |
| `ChatSessionsContainer` · `SessionActionsHeader` · `SessionIndicators` | retheme | macOS list rows | reorder spring | ⏳ |
| toasts (`GroupedExtensionLoadingToast`) · `LoadingGoose/Epistemos` · `Spinner` | retheme | macOS toast/progress | slide+fade spring | ⏳ |
| `icons.tsx` / lucide-react | retheme | match SF Symbols weight/scale (or map key glyphs) | — | ⏳ (SF Symbols license) |
| Settings (`settings` routes) | calm/fluid blended (not native) | per doctrine — unseen = blended web | — | ⏳ |

## MOTION + PERF FINDINGS (Round 1)
- **Motion engine = Motion (MIT).** Vanilla `animate()` (framework-agnostic — works regardless of Goose's
  framework), real spring physics, "hybrid engine: JS + native browser APIs for 120fps GPU-accelerated."
  → primary for interactive/interruptible springs. Bundle size + explicit interruptibility = [GAP] next round.
- **react-spring (MIT, spring-first)** = the alt if Goose UI is React and we want hooks.
- **Pure CSS `linear()` springs** preferred where no JS interaction needed (cheaper) — confirm WebKit support.
- Perf budget (from doctrine): 60/120fps, animate transform/opacity ONLY (never layout props), virtualize the
  chat transcript + sessions list, bounded webview live-set + listener teardown. Instrument fps + input latency.

## ★ APPLE TOKENS + SPRING VALUES + GLASS RECIPE (R3 — concrete, build-ready)
### Theme tokens — shadcn Apple Design System [VERIFIED via shadcn.io/design/apple] → wire into Goose's Tailwind/CSS vars
- Accent / **Action Blue `#0066cc`** (focus `#0071e3`, on-dark `#2997ff`).
- Light: canvas `#ffffff` · parchment `#f5f5f7` · pearl `#fafafc` · ink `#1d1d1f` · hairline `#f0f0f0`/`#e0e0e0`.
- Dark: tiles `#272729`/`#2a2a2c`/`#252527` · black `#000` · text `#fff` · muted `#7a7a7a`/`#ccc`/`#333`.
- Type: **SF Pro** (Display+Text) via `-apple-system`; weights **300/400/600/700 (skip 500)**; **body 17px**; scale 10–56px.
- **Radius base 11px**; mixed (full-bleed tiles + pill interactive). 
- License: token VALUES are facts (safe to use); the **DESIGN.md file is Google Labs' open spec** — lift values into Epistemos's existing theme tokens, don't necessarily copy the file verbatim. ⏳ confirm spec license if copied.
### Spring values — match macOS; framer-motion is ALREADY in Goose (calibrate, don't add)
- Native ref [VERIFIED]: **CocoaSprings (MIT)** damped spring `angularFrequency ω=7.5, dampingRatio ζ=0.5`.
- Map → framer-motion `{type:"spring"}` (mass=1): `stiffness = ω² ≈ 56`, `damping = 2·ζ·ω ≈ 7.5` (ζ=0.5 = playful; good for hover/press).
- PREFERRED API: framer-motion `{type:"spring", duration, bounce}` ≈ SwiftUI `.spring(duration:bounce:)` (`bounce ≈ 1 − dampingFraction`). EXACT macOS presets [VERIFIED — Apple SwiftUI defaults]:
  - **default `.spring`** (response 0.55, dampingFraction 0.825) → `{duration:0.55, bounce:0.18}` — general settle.
  - **`.smooth`** (critically damped, NO overshoot) → `{duration:0.5, bounce:0}` — menus/sheets/most controls.
  - **`.snappy`** (slight overshoot) → `{duration:0.5, bounce:0.15}` — tabs/toggles/segments/buttons.
  - **`.bouncy`** (visible overshoot) → `{duration:0.5, bounce:0.3}` — toasts/hub/route transitions.
  - **`.interactiveSpring`** (drag/gesture-follow: response 0.15, dampingFraction 0.86) → `{duration:0.15, bounce:0.14}`.
  - Sources: Apple `spring(response:dampingFraction:)` docs; SwiftUI smooth/snappy/bouncy preset spec.

### Icons / SF Symbols licensing [VERIFIED R6 — App-Store-safe split]
- Apple's SF Symbols license = use ONLY in apps/artwork/mockups for **Apple platforms**; PROHIBITS redistributing
  the symbols or use on non-Apple platforms; SVG export is "personal use on Apple platforms only" — NOT a license
  to bundle SF Symbol glyphs (font/SVG) into a web asset set.
- VERDICT:
  - **Native chrome (AppKit/SwiftUI) → use REAL SF Symbols freely** (`Image(systemName:)` / `NSImage(systemSymbolName:)`) — fully licensed.
  - **Inside the Goose WKWebView → do NOT bundle SF Symbols.** Keep Goose's existing **lucide-react (ISC, App-Store-safe)** restyled to MATCH SF Symbols (weight / optical size / stroke / scale).
  - Net: real SF Symbols in the native frame; lucide-matched in the web content → zero license risk, consistent look.
- Sources: developer.apple.com/sf-symbols + Apple SF Symbols license (developer forums).
### Transparent-over-native-glass recipe (#8 — ✅ PROVEN in Epistemos's own code, R5)
Every piece ALREADY ships in-app — the Goose reskin just COMPOSES them (macOS target = 26.0, confirmed project.yml):
- **Non-opaque window:** `Agent/AgentSurfaceWindowController.swift:37` already sets `window.isOpaque = false` (the Goose surface window itself).
- **Native glass layer (reuse, don't reinvent):** `Theme/GlassModifiers.swift` (macOS 26 `glassEffect`), `Views/Shared/UnifiedFrostedGlass.swift`, `Theme/ToolbarGlass.swift`. NSVisualEffectView / Liquid Glass already powers 12+ surfaces (ShadowPanel, HologramOverlay, Settings, ToastOverlay, MetalGraphView…). Mount one BEHIND the Goose WKWebView.
- **Non-opaque WKWebView:** `webView.setValue(false, forKey:"drawsBackground")` — PROVEN at `Views/Epdoc/EpdocKaTeXPreview.swift:79` (also `CodeEditorView.swift:2888` for the scroll view). Reuse the exact pattern.
- **CSS:** `html,body{background:transparent}`; translucent content surfaces so the real glass shows through. Web fallback glass = frost+tint+specular (NOT refraction — Chromium-only).
- **Contrast guard on vibrancy:** adequate text contrast; `-apple-system`; no full-opacity content backgrounds where blend is wanted.

## WebKit / WKWebView COMPATIBILITY [VERIFIED R4 — stack is WebKit-safe on macOS 26]
- **Tailwind v4 → requires Safari 16.4+** (uses `@property`, cascade layers, `color-mix()`, oklch). macOS 26's
  WKWebView (Safari 26-class) fully supports → ✅ Goose's existing stack renders in our WKWebView. ⚠️ Tailwind v4
  CANNOT run on Safari < 16.4 — irrelevant (Epistemos targets current macOS); flag only if min-OS ever drops.
- **CSS `linear()` spring easing → Safari 17.2+** ✅ — usable for the cheap pure-CSS spring path (no JS).
- **`backdrop-filter` (web-side frost fallback) → works in WebKit**, but: (a) include BOTH `-webkit-backdrop-filter`
  + `backdrop-filter`; (b) **do NOT put CSS variables inside the backdrop-filter value** (Safari limitation, MDN compat).
- **Key mitigation:** the doctrine's PRIMARY glass is the native `NSVisualEffectView` behind a transparent webview,
  so `backdrop-filter` is only a *secondary* fallback for in-content frosted panels → the WebKit backdrop-filter
  gotchas are largely sidestepped.
- Radix UI + framer-motion = framework JS → engine-agnostic, work in WebKit by construction.
- Sources: tailwindcss.com/blog/tailwindcss-v4 (Safari 16.4+); MDN linear() (Safari 17.2+); MDN/caniuse backdrop-filter.

## VENDORING DECISIONS (ProvenanceGate — R2, pivoted)
- Component base → **IN-PLACE RETHEME** of Goose's existing shadcn/ui + Radix (no new lib, no vendoring — theme via Tailwind/CSS vars). Safest.
- Motion → **IN-PLACE CALIBRATE** Goose's existing framer-motion v12 (MIT, already bundled) — tune spring values to macOS; no new motion lib.
- shadcn Apple tokens → **lift** the DESIGN.md token values into Goose's Tailwind config + CSS vars (our theme).
- Liquid Glass web libs → **clean-room CSS** (frost+specular fallback; never the Chromium-only refraction).
- Native glass → platform (`NSVisualEffectView`/macOS 26) behind the transparent webview.
- LiqUIdify / Framework7 / Konsta → **research_only** (reference HIG patterns; adopting them would REPLACE Goose's components).
- lucide-react → **retheme in place**; SF Symbols mapping pending licensing.

## GAP LIST → next rounds
1. ✅ CLOSED (R2) — Goose inventory + framework = React 19 + shadcn/ui + Radix + Tailwind v4 + framer-motion v12 + lucide.
2. ✅ CLOSED (R2) — component base decided: RETHEME Goose's existing shadcn (LiqUIdify/Framework7/Konsta demoted to reference-only).
3. ✅ CLOSED (R3) — shadcn Apple token VALUES pulled (Action Blue #0066cc, SF Pro 300/400/600/700, body 17px, radius 11px, full palette). Next: actually wire them into Goose's Tailwind config + CSS vars.
4. ✅ CLOSED (R6) — EXACT SwiftUI spring defaults verified (.spring 0.55/0.825; .smooth/.snappy/.bouncy = bounce 0/0.15/0.3 @ dur 0.5; .interactiveSpring 0.15/0.86) → framer-motion duration/bounce presets locked.
5. ✅ CLOSED (R4) — WebKit-safe on macOS 26: Tailwind v4 (Safari 16.4+), CSS `linear()` (17.2+), backdrop-filter OK (prefix + no CSS-vars-inside); native glass sidesteps the backdrop-filter gotcha. See "WebKit COMPATIBILITY".
6. ✅ CLOSED (R6) — SF Symbols: real in NATIVE chrome (licensed); do NOT bundle into the webview; keep lucide (ISC) restyled to match SF Symbols in web content. Zero license risk.
7. Connect + use the **HIG / SF Symbols MCP servers** (apple-dev-mcp, SF Symbols MCP) for exact control metrics/symbols + the spring defaults (#4).
8. ✅ CLOSED (R5) — transparent-over-glass recipe PROVEN in Epistemos's own code (window isOpaque=false at AgentSurfaceWindowController.swift:37; glass via GlassModifiers/UnifiedFrostedGlass/ToolbarGlass; non-opaque WKWebView via setValue(false,"drawsBackground") at EpdocKaTeXPreview.swift:79). Reuse, don't reinvent. REMAINING: prototype the actual seam (no flicker) during build.
9. Build the **A/B pixel-diff harness** (native control vs rethemed Goose control) — gates every `[VERIFIED]`.
10. **Wire the Epistemos theme tokens** (R3 values) into Goose's `tailwind.config.ts` + `src/styles/main.css` CSS vars (the actual retheme implementation handoff).

## INTEGRATION NOTES
- Build-time vendor via `build-tiptap-bundle.sh` model → `Resources/` → served via `WKURLSchemeHandler`. No runtime npm.
- Theme tokens injected as CSS vars (same mechanism as the editor theme injection).
- Webview transparent over a native `NSVisualEffectView` glass layer (doctrine).

## CHANGELOG
- 2026-06-29 R1: created. Verified Motion + react-spring (MIT, spring, active). Stack skeleton + gap list seeded.
  Component base + Goose inventory deferred to R2. (Goose plan change owned by the Plan-1 agent — not edited here.)
- 2026-06-29 R2: ★ PIVOT. Verified from Goose source: React 19 + shadcn/ui (new-york, cssVariables) + Radix +
  Tailwind v4 + framer-motion v12 (MIT) + lucide. Strategy = RETHEME the existing shadcn (no replacement) +
  calibrate the existing framer-motion → safest, nothing breaks. LiqUIdify/Framework7/Konsta demoted to
  reference-only. Filled the component mapping table with Goose's REAL components → retheme recipes. Closed gaps
  #1 (inventory) + #2 (base decision). New gaps: pull shadcn Apple DESIGN.md tokens, extract macOS spring values,
  WebKit verify (linear()/Tailwind v4/Radix), SF Symbols licensing, transparent-over-glass recipe, A/B harness.
- 2026-06-29 R3: build-ready recipe landed. [VERIFIED] shadcn Apple token VALUES (Action Blue #0066cc, full
  palette, SF Pro 300/400/600/700 / body 17px, radius 11px) + CocoaSprings (MIT) native spring (ω=7.5, ζ=0.5)
  → framer-motion mapping (stiffness≈56/damping≈7.5 + duration/bounce presets for settle/snappy/playful) +
  transparent-over-glass recipe (NSVisualEffectView behind non-opaque WKWebView). Closed #3; drafted #4 + #8.
  New gaps: wire tokens into Goose tailwind.config/main.css, confirm SwiftUI spring defaults via HIG MCP,
  verify macOS-26 non-opaque WKWebView API, A/B harness.
- 2026-06-29 R4: closed #5 (WebKit-compat gate). [VERIFIED] the stack is WebKit-safe on macOS 26 — Tailwind v4
  (Safari 16.4+), CSS linear() springs (17.2+), backdrop-filter OK with `-webkit-` prefix + NO CSS-vars-inside;
  native NSVisualEffectView glass sidesteps the backdrop-filter limitation. Radix/framer-motion engine-agnostic.
  Remaining gaps: SwiftUI spring defaults via HIG MCP, macOS-26 non-opaque WKWebView API, SF Symbols licensing,
  A/B pixel-diff harness, token-wiring implementation handoff.
- 2026-06-29 R5: closed #8 — the transparent-over-glass recipe is PROVEN in Epistemos's OWN code, not
  theoretical. Verified locally: macOS target 26.0; AgentSurfaceWindowController.swift:37 window.isOpaque=false
  (the Goose surface window); macOS-26 glassEffect + UnifiedFrostedGlass/GlassModifiers/ToolbarGlass power 12+
  surfaces; non-opaque WKWebView via setValue(false,"drawsBackground") at EpdocKaTeXPreview.swift:79. The reskin
  COMPOSES existing pieces (reuse, don't reinvent). Remaining gaps: SwiftUI spring defaults via HIG MCP, SF
  Symbols licensing, A/B pixel-diff harness, token-wiring handoff.
- 2026-06-29 R6: closed #4 + #6. [VERIFIED] EXACT SwiftUI spring defaults (.spring 0.55/0.825; .smooth/.snappy/
  .bouncy = bounce 0/0.15/0.3 @ dur 0.5; .interactiveSpring 0.15/0.86) → framer-motion duration/bounce presets
  locked. [VERIFIED] SF Symbols license: real SF Symbols only in NATIVE chrome; web content keeps lucide (ISC)
  restyled to match — never bundle SF Symbols into the webview. Remaining: A/B pixel-diff harness (#9) + token-
  wiring implementation handoff (#10) + use HIG/SF-Symbols MCP for exact control metrics (#7).
