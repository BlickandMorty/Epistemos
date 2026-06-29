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
3. Pull the **shadcn Apple Design System DESIGN.md token values** (colors/type/spacing) → wire into Goose's Tailwind config + CSS vars (`cssVariables:true`, baseColor neutral).
4. Extract **macOS native spring values** from CocoaSprings/Advance → calibrate Goose's framer-motion springs (press/sheet/menu/toast/transition).
5. Verify **CSS `linear()` spring** + Tailwind v4 + Radix behavior in **WebKit/WKWebView**.
6. **SF Symbols licensing** path (Apple-restricted) + lucide↔SF-Symbols glyph mapping for native feel.
7. Connect + use the **HIG / SF Symbols MCP servers** (apple-dev-mcp, SF Symbols MCP) for exact control metrics/symbols.
8. **Transparent-webview-over-glass** WebKit recipe: `drawsBackground=false` + native `NSVisualEffectView` behind — verify + prototype the seam.
9. Build the **A/B pixel-diff harness** (native control vs rethemed Goose control) — gates every `[VERIFIED]`.

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
