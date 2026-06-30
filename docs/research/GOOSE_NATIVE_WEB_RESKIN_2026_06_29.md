# Goose Native-Feel Web Reskin — LIVING RESEARCH (started 2026-06-29)

> 🎨 **OWNER DESIGN AMENDMENT 2026-06-30 (overrides the glass recipe here):** target is now **FLAT PIXEL-ART, theme-tinted surfaces** (crisp edges, no frosted/translucent glass), still inside the native frame, fully theme-aware of ALL Epistemos palettes incl. the user CUSTOM palette. Wherever this doc says "transparent-over-glass / NSVisualEffectView / Liquid Glass," reskin Goose's components **flat pixel-art** instead (still RESKIN-not-replace). Authority: the 🎨 amendment atop `EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`.

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

## MOTION + PERF FINDINGS (reconciled at R2 pivot — supersedes the R1 "add Motion" framing)
- **Motion engine = Goose's EXISTING framer-motion v12 (MIT)** — note framer-motion IS "Motion"'s React package
  (motiondivision/motion = motion.dev). So we do NOT add Motion's vanilla `animate()` or react-spring; we
  CALIBRATE the framer-motion already bundled in Goose to the verified SwiftUI springs (`.smooth {0.5,0}` ·
  `.snappy {0.5,0.15}` · `.bouncy {0.5,0.3}` · `.interactiveSpring {0.15,0.14}`). Hybrid WAAPI/GPU 120fps, real
  springs, interruptible — all native to framer-motion. (react-spring = reference-only; NOT adopted since
  framer-motion is already present.)
- **Pure CSS `linear()` springs** preferred where no JS interaction needed (cheaper) — Safari 17.2+ ✅ (R4).
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
10. ✅ CLOSED (R7) — exact retheme handoff found: edit `ui/desktop/src/theme/theme-tokens.ts` (typed token source) + `src/styles/main.css` :root/.dark. Set SF Pro font, body 16→17px, radius 0→11px (Goose ships SHARP corners today), Apple #0066cc palette. cssVariables:true → restyles all shadcn primitives at once. See "THEME RETHEME HANDOFF".
11. ✅ CLOSED (R8) — copy-ready macOS CSS for the 3 geometry-sensitive primitives (switch / segmented-tabs / popup-select), targeting Goose's real markup. See "PER-COMPONENT macOS CSS".
12. ✅ CLOSED (R9) — A/B pixel-diff harness SPECCED (WKWebView.takeSnapshot + SwiftUI ImageRenderer → pixelmatch/odiff → gate ≤~2% across light/dark/states; dev-only). See "A/B PIXEL-DIFF HARNESS — spec".
═══ ALL RESEARCH GAPS CLOSED ═══ The reskin research is functionally COMPLETE. Remaining = pure IMPLEMENTATION (owned by the Plan-1 build agent): apply the theme-tokens.ts retheme + per-component macOS CSS, build, run the harness to flip components to [VERIFIED]. The loop now shifts to a COMPLETENESS-CRITIC cadence: re-verify nothing drifted + extend the same recipe to the editor (Plan 2) / Plan-3 web bodies, until owner says stop.

## INTEGRATION NOTES
- Build-time vendor via `build-tiptap-bundle.sh` model → `Resources/` → served via `WKURLSchemeHandler`. No runtime npm.
- Theme tokens injected as CSS vars (same mechanism as the editor theme injection).
- Webview transparent over a native `NSVisualEffectView` glass layer (doctrine).

## ★ CODE TO LIFT — concrete, openable code (not just library names)
The build agent should OPEN these and copy/adapt. In-repo proven code FIRST, then vetted OSS (license noted).
### In-repo (Epistemos — already shipping, reuse verbatim)
- Non-opaque WKWebView: `Views/Epdoc/EpdocKaTeXPreview.swift:79` (`setValue(false, forKey:"drawsBackground")`); scroll variant `Views/Notes/CodeEditorView.swift:2888`.
- Native glass: `Theme/GlassModifiers.swift` (macOS-26 `glassEffect`), `Views/Shared/UnifiedFrostedGlass.swift`, `Theme/ToolbarGlass.swift`.
- Non-opaque Goose window: `Agent/AgentSurfaceWindowController.swift:37`.
- Build-time web bundle pipeline to clone: `build-tiptap-bundle.sh` → `Resources/` → `WKURLSchemeHandler`.
- Theme-token CSS-var injection pattern: the editor's existing theme injection (mirror it for Goose).
### Goose's own UI (retheme in place — `.research-clones/work/goose/ui/desktop/src`)
- shadcn primitives to retheme: `components/ui/{button,input,switch,tabs,dialog,sheet,dropdown-menu,Select,Tooltip,scroll-area,card,collapsible,separator,skeleton}.tsx`.
- Tailwind/theme entry points to edit: `tailwind.config.ts` + `src/styles/main.css` (`cssVariables:true`) + `components.json`.
- Chat/composer/hub: `components/{BaseChat,ChatInput,GooseMessage,ProgressiveMessageList,Hub,LauncherView}.tsx`.
- Motion already present: `framer-motion` v12 (set spring configs to the verified `{duration,bounce}` values).
### OSS to reference/lift (license-checked)
- shadcn/ui primitive sources (MIT) — ui.shadcn.com / github shadcn-ui/ui: copy the macOS-tuned variants.
- shadcn Apple Design System tokens (DESIGN.md values) — shadcn.io/design/apple (lift VALUES into our CSS vars).
- framer-motion spring docs/config (MIT) — motion.dev. CocoaSprings (MIT, MacPaw) — native spring constants ref.
- Apple SF Symbols → native chrome only (NSImage(systemSymbolName:)); web keeps lucide-react (ISC).
- ⏳ next rounds: pull the EXACT shadcn primitive source per component + the macOS-tuned CSS into the mapping table.

## ★ THEME RETHEME HANDOFF — exact files + token edits (copy-ready, R7)
Goose theming is driven by a TYPED token source-of-truth, NOT the classic shadcn `:root{--background}` HSL block.
The single highest-leverage lift (restyles EVERY shadcn primitive at once, since `components.json` has `cssVariables:true`):
- **`ui/desktop/src/theme/theme-tokens.ts`** — THE source of truth (typed DesignToken map; also merges MCP-app
  tokens via `@modelcontextprotocol/ext-apps/app-bridge` + `light-dark()`). Override here:
  - `--font-sans` → `-apple-system, BlinkMacSystemFont, 'SF Pro Text','SF Pro Display', system-ui, sans-serif`;
    `--font-mono` → `ui-monospace, 'SF Mono', Menlo, monospace`.
  - `--font-text-md-size` 1rem(16px) → **1.0625rem (17px)** (Apple body). Weights: keep 400/600/700; Apple skips 500.
  - `--border-radius-*` → Apple rounded scale (sm 8px · **md 11px base** · lg 14px · full 9999px). ⚠️ FINDING:
    Goose currently ships **SHARP corners** (`--radius:0` at main.css:1176; `border-radius:0` at 552/616/661/723/
    755/900) — the Apple look REQUIRES rounding these.
  - `--color-*` semantic palette (`--color-background-*` / `--color-text-*` / `--color-border-*` / primary) →
    Apple tokens: primary/accent **#0066cc** (focus #0071e3, dark #2997ff); ink #1d1d1f; canvas #fff / parchment
    #f5f5f7; dark tiles #272729/#2a2a2c.
- **`ui/desktop/src/styles/main.css`** `:root`/`.dark` (lines 325–373) — app-only aliases (sidebar/highlight/
  inline-code): re-point to the Apple tokens; flip the hard-coded `border-radius:0` instances to the radius scale.
- **`ui/desktop/components.json`** (`cssVariables:true`, style new-york, `tailwind.css = src/styles/main.css`) —
  confirms editing the tokens restyles button/input/select/switch/tabs/dialog/sheet/dropdown/… in one shot.
- ProvenanceGate: in-place edit of Goose's OWN vendored UI theme files (theming our embedded copy; license = Goose
  Apache-2.0 → fine). Build via the existing pnpm/stage-goose-web-ui pipeline (NO runtime npm).

## ★ PER-COMPONENT macOS CSS (copy-ready, R8) — for the primitives where Apple geometry ≠ shadcn defaults
Tokens (THEME RETHEME) cover ~90%; these 3 need geometry overrides. Target Goose's REAL markup (verified source).
### Switch — `ui/components/ui/switch.tsx` (Radix Switch Root=track, Thumb=knob)
Goose now: track `h-[16px] w-[28px] rounded-full border-2`, thumb `h-3 w-3`, checked `bg-background-primary`, `transition-transform`.
macOS-tune (NSSwitch ≈ accent-tinted track + near-full white knob + springy knob):
```
// switch.tsx className edits (Tailwind, keeps Radix data-state):
Root  : h-[22px] w-[38px] rounded-full border-0  +  data-[state=checked]:bg-[var(--color-accent,#0066cc)]  data-[state=unchecked]:bg-[var(--color-border-secondary)]
Thumb : h-[18px] w-[18px] rounded-full bg-white shadow-[0_1px_2px_rgba(0,0,0,.25)]  data-[state=unchecked]:translate-x-[2px] data-[state=checked]:translate-x-[18px]
```
Knob MOTION = the `.snappy` spring (NOT CSS `transition-transform`): drive the Thumb with framer-motion `{type:'spring',duration:0.5,bounce:0.15}` (Goose already ships framer-motion), or a CSS `linear()` spring easing var. ON tint follows the Apple accent token.
### Segmented control (Tabs) — `ui/components/ui/tabs.tsx` (Radix Tabs; List=track, Trigger=segment)
Goose now: List `rounded-[6px]`. macOS-tune: List = inset pill group on `--color-background-secondary`, radius 8px, 2px inset padding; active Trigger = white/elevated pill (`bg-[var(--color-background-primary)] shadow-sm rounded-[6px]`), inactive = transparent. The active-pill SLIDE = `.snappy` spring via framer-motion `layoutId` (shared-element) on the active indicator → the pill glides between segments (the macOS feel).
### Select / dropdown — `ui/components/ui/Select.tsx` + radix select
macOS popup-button: trigger = `rounded-[7px]` 1px border + a trailing up/down chevron (lucide `ChevronsUpDown`, sized ~13px) right-aligned; menu (Content) = vibrancy surface (transparent-over-glass), radius 9px, item highlight = accent (`bg-[var(--color-accent)] text-white`); present = `.snappy` spring (scale 0.96→1 + opacity). 
ProvenanceGate: all = in-place className/CSS edits to Goose's OWN primitives (no new lib). License = Goose (Apache-2.0).

## ★ A/B PIXEL-DIFF HARNESS — spec (R9, the perfect-blending gate; DEV-ONLY, not shipped)
Gates every component to `[VERIFIED]`: render the rethemed Goose control beside the native AppKit equivalent,
diff, pass only if indistinguishable. Concrete design (all in-repo APIs + MIT tooling):
- **CAPTURE (identical geometry/scale/theme/state):**
  - Native control → SwiftUI `ImageRenderer` (or `NSView.cacheDisplay(in:to:)` / `bitmapImageRepForCachingDisplay`)
    of the equivalent AppKit control (NSSwitch / NSSegmentedControl / NSButton / NSPopUpButton …).
  - Web control → **`WKWebView.takeSnapshot(with:completionHandler:)`** (returns an NSImage of the exact web region;
    native API, no extra dep) of the rethemed Goose primitive in isolation.
  - MATCH: same point size, same `backingScaleFactor` (2×), same light AND dark, same state (default/hover/
    pressed/checked/disabled/focused).
- **NORMALIZE:** crop to control bounds; identical pixel dims; same backdrop (both transparent over the same glass swatch).
- **DIFF:** **pixelmatch** (MIT, pure-JS, default) — swap to **odiff** (SIMD, ~6–8× faster, Node API; verify license)
  if speed bottlenecks. Emit a highlighted diff image + mismatch %.
- **GATE:** component flips to `[VERIFIED]` only when mismatch ≤ ~2% at matched geometry **across light+dark+all
  states**. HONESTY: WebKit-vs-native text antialiasing differs sub-pixel (the ~2% allowance covers it) — but
  geometry/color/spacing mismatch must be ≈0. Report PER-STATE so you see which state fails.
- **WHERE:** dev-only script / test target (NOT shipped); reuse the build-time bundle infra; never runtime npm in the app.
- Sources: WKWebView.takeSnapshot (Apple docs); pixelmatch (mapbox, MIT); odiff (dmtrKovalenko, SIMD).

## ★ EDITOR + CROSS-SURFACE TOKEN UNIFICATION (R10 — extends the recipe to Plan 2 web bodies)
The editor web bodies ALREADY have a theme-injection architecture — feed them the SAME Apple tokens (no new system):
- **`Epistemos/Theme/EpistemosTheme.swift` = the Swift-side token SOURCE** that the native chrome + every editor
  web body read. Make it carry the Apple values (SF Pro fonts, #0066cc palette, radius 11) → all native + editor
  surfaces inherit them. This is the native-side TWIN of Goose's `theme-tokens.ts`.
- **Epdoc (TipTap):** `EpdocEditorThemeStyle` (`Views/Epdoc/EpdocEditorChromeView.swift:582`) injects CSS vars from
  EpistemosTheme — `--epdoc-bg` is ALREADY `transparent` ✅ (transparent-over-glass already wired); `--epdoc-display-
  font` / `--epdoc-h*-font` ← `theme.epdoc*FontFamily`. Retheme = point those at SF Pro + the Apple palette/radius.
- **CoreEditor (code body):** `Views/Notes/MarkEditCoreEditorView.swift` takes `theme: EpistemosTheme` and injects
  (currently `themeName: github-dark/light` at :363). Map EpistemosTheme → CoreEditor CSS vars so it follows the APP
  theme (the owner's "it only takes MarkEdit's theme" fix), not just the two github presets.
- **HTML Workspace:** `Views/HTMLWorkspace/HTMLWorkspacePreviewView.swift:45` `themeGuardCSSOverride` is the seam →
  push the Apple tokens through it.
- ⇒ **THE UNIFICATION (concrete):** TWO token sources — `EpistemosTheme` (Swift, for native + editor-web) and
  Goose's `theme-tokens.ts` (Goose-web) — must hold IDENTICAL Apple values. Then AppKit + editor-web + Goose-web all
  render ONE look. Springs: same `{duration,bounce}` numbers everywhere (Goose = framer-motion; Epdoc/HTML-Workspace
  = CSS `linear()` springs or shared tokens). ProvenanceGate: in-place edits to Epistemos's own theme/injector code
  (Plan 2 owns the editor injectors; Plan 1 owns theme-tokens.ts; the doctrine keeps the VALUES identical).

## ★ GLOBAL macOS DETAILS — scrollbars + focus ring (R11, app-wide; affects EVERY component)
These aren't per-component — they're global tells that the token retheme misses. Apply to Goose AND the editor web bodies.
- **Scrollbars → use the NATIVE macOS overlay scrollbars.** [VERIFIED] macOS uses overlay scrollbars system-wide;
  WKWebView inherits them by DEFAULT, and custom `::-webkit-scrollbar` styling is largely ineffective in overlay
  mode (the OS manages the thumb). Goose currently OVERRIDES them — `main.css:583` `scrollbar-width:none !important`,
  `:587` `[data-radix-scroll-area-viewport]::-webkit-scrollbar`, and global `::-webkit-scrollbar{track,thumb}`
  (607–629) — which fights the OS + reads non-native. FIX: NEUTRALIZE the global custom scrollbar rules (607–629) +
  the blanket `scrollbar-width:none` so the native overlay scrollbars render; keep `scrollbar-width:none` ONLY where
  a scrollbar is deliberately hidden (a specific custom-scrolled container), never globally.
- **Focus ring → match macOS's ACCENT-colored ring**, not a thin neutral outline. Goose uses `outline:1px solid`
  (`:563-564`) + shadcn `--color-ring`. macOS focus = the accent glow. FIX: `:focus-visible { outline: 2px solid
  var(--color-accent,#0066cc); outline-offset: 2px; }` (or keep WebKit's UA-native ring; do NOT replace it with a
  1px neutral line). Drive the color from the unified accent token so it matches the native chrome's focus ring.
- ProvenanceGate: in-place CSS edits to Goose's own main.css + the editor CSS. WebKit-verified (overlay scrollbars
  are the system default on macOS 26). Sources: WebKit/Safari scrollbar overlay behavior; macOS HIG focus ring.

## CHANGELOG
- 2026-06-29 R11: completeness-critic — GLOBAL macOS details (apply to all web bodies). [VERIFIED] macOS overlay
  scrollbars are the system default in WKWebView; Goose OVERRIDES them (main.css:583/587/607-629) → neutralize the
  custom scrollbar CSS so native overlay scrollbars render. Focus ring: Goose's 1px neutral outline (:563) →
  accent-colored ring (var(--color-accent)) matching macOS. Both global, both for Goose + editor web bodies.
- 2026-06-29 R10: completeness-critic — extended the recipe to Plan 2 editor web bodies. Found the editor already
  has a theme-injection architecture: EpistemosTheme.swift (Swift token source) → EpdocEditorThemeStyle
  (EpdocEditorChromeView.swift:582; --epdoc-bg ALREADY transparent) + MarkEditCoreEditorView (theme param; github
  presets at :363 → make app-theme-aware) + HTMLWorkspacePreviewView.themeGuardCSSOverride. KEY UNIFICATION:
  EpistemosTheme (Swift) and Goose's theme-tokens.ts must hold IDENTICAL Apple token values → one unified look across
  AppKit + editor-web + Goose-web. Same spring {duration,bounce} numbers everywhere. (Editor injectors = Plan 2's.)
- 2026-06-29 R9: closed the LAST gate (#9/#12) — specced the A/B pixel-diff harness (capture via
  WKWebView.takeSnapshot + SwiftUI ImageRenderer; normalize; diff via pixelmatch/odiff; gate ≤~2% across
  light/dark/states, per-state report; dev-only). RESEARCH IS NOW FUNCTIONALLY COMPLETE — every gap closed with
  openable code/spec; remaining work is pure IMPLEMENTATION (apply the theme-tokens.ts retheme + per-component CSS,
  then run the harness to flip components to [VERIFIED]).
- 2026-06-29 R8: code-research — copy-ready macOS CSS for the 3 geometry-sensitive primitives, targeting Goose's
  REAL markup: Switch (switch.tsx: 16×28→22×38 track, 12→18px knob, accent ON, .snappy knob spring), Segmented/
  Tabs (tabs.tsx: inset pill group + framer-motion layoutId slide), Select (popup-button + chevron + vibrancy menu
  + present spring). All = in-place className edits to Goose's own primitives (no new lib). Updated mapping table.
- 2026-06-29 R7: code-research — found the EXACT retheme handoff (closed #10). Goose theming = typed
  `ui/desktop/src/theme/theme-tokens.ts` (source of truth) + `src/styles/main.css` :root/.dark; `cssVariables:true`
  so token edits restyle ALL shadcn primitives at once. Concrete findings: Goose ships SHARP corners
  (border-radius:0) → Apple needs 11px; body 16px → 17px; font → SF Pro stack. Reconciled the stale R1 "add
  Motion/react-spring" motion section (framer-motion IS Motion, already in Goose → calibrate in place). Added
  inline supersede marker for the native-Chat item in GOOSE_NATIVE_UI_DECISION. Next: per-component macOS CSS
  overrides (switch/tabs/select) + A/B pixel-diff harness.
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
